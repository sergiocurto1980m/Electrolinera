import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from 'npm:jose@5'

/*
 * send-push
 * ---------
 * Envía por FCM HTTP v1 los avisos que el trigger `on_aviso_push` acaba de
 * insertar en public.avisos. La llama pg_net, nunca el frontend.
 *
 * Secretos necesarios:
 *   · FCM_SERVICE_ACCOUNT_B64: JSON de la cuenta de servicio en base64.
 *   · PUSH_WEBHOOK_SECRET:    mismo valor que el secreto de Vault.
 *
 * SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los inyecta Supabase.
 */

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
const FCM_ENDPOINT = 'https://fcm.googleapis.com/v1/projects'
const MAX_BODY_LENGTH = 240

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-push-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
}

type AvisoPayload = {
  aviso_id?: string | number | null
  usuario_id?: string | null
  mensaje?: string | null
}

type PushToken = {
  id: string
  token: string
  plataforma: 'web' | 'android'
}

type SendResult = {
  tokenId: string
  ok: boolean
  dead: boolean
}

let cachedAccount: ServiceAccount | null = null
let cachedPrivateKey: CryptoKey | null = null
let cachedAccessToken: { value: string; expiresAt: number } | null = null

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

function errorMessage(cause: unknown): string {
  if (cause instanceof Error) return cause.message
  return String(cause)
}

function decodeServiceAccount(): ServiceAccount {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT_B64')

  if (!raw) {
    throw new Error('Falta el secreto FCM_SERVICE_ACCOUNT_B64.')
  }

  let parsed: unknown

  try {
    const jsonText = atob(raw.replace(/\s+/g, ''))
    parsed = JSON.parse(jsonText)
  } catch {
    throw new Error(
      'FCM_SERVICE_ACCOUNT_B64 no contiene un JSON de cuenta de servicio válido.',
    )
  }

  const account = parsed as Partial<ServiceAccount>

  if (!account.project_id || !account.client_email || !account.private_key) {
    throw new Error(
      'La cuenta de servicio debe incluir project_id, client_email y private_key.',
    )
  }

  return account as ServiceAccount
}

async function getAccessToken(): Promise<{
  accessToken: string
  projectId: string
}> {
  const now = Math.floor(Date.now() / 1000)

  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    const account = cachedAccount ?? decodeServiceAccount()
    return { accessToken: cachedAccessToken.value, projectId: account.project_id }
  }

  const account = cachedAccount ?? (cachedAccount = decodeServiceAccount())
  const privateKey =
    cachedPrivateKey ??
    (cachedPrivateKey = await importPKCS8(account.private_key, 'RS256'))

  const assertion = await new SignJWT({ scope: FCM_SCOPE })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setAudience(GOOGLE_TOKEN_URL)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey)

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })

  if (!response.ok) {
    const details = await response.text()
    throw new Error(
      `Google rechazó la cuenta de servicio (${response.status}): ${details}`,
    )
  }

  const data = (await response.json()) as {
    access_token?: string
    expires_in?: number
  }

  if (!data.access_token) {
    throw new Error('Google no devolvió un access_token.')
  }

  cachedAccessToken = {
    value: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  }

  return { accessToken: data.access_token, projectId: account.project_id }
}

function buildMessage(
  token: string,
  mensaje: string,
  avisoId: string,
): Record<string, unknown> {
  return {
    token,
    notification: {
      title: 'Electrolinera',
      body: mensaje,
    },
    data: {
      tipo: 'aviso',
      aviso_id: avisoId,
      url: '/home',
    },
    android: {
      priority: 'high',
      notification: {
        channel_id: 'avisos',
        sound: 'default',
        click_action: 'FCM_PLUGIN_ACTIVITY',
        color: '#22c55e',
      },
    },
    webpush: {
      headers: {
        Urgency: 'high',
        TTL: '86400',
      },
    },
  }
}

function isDeadToken(status: number, detail: string): boolean {
  if (status === 404) return true
  if (status !== 400) return false

  const normalized = detail.toLowerCase()

  return (
    normalized.includes('unregistered') ||
    normalized.includes('registration token') ||
    normalized.includes('not a valid fcm')
  )
}

async function sendToToken(
  projectId: string,
  accessToken: string,
  row: PushToken,
  mensaje: string,
  avisoId: string,
): Promise<SendResult> {
  try {
    const response = await fetch(
      `${FCM_ENDPOINT}/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: buildMessage(row.token, mensaje, avisoId),
        }),
      },
    )

    if (response.ok) {
      return { tokenId: row.id, ok: true, dead: false }
    }

    const detail = await response.text()
    const dead = isDeadToken(response.status, detail)

    console.error(
      `FCM ${row.plataforma} ${response.status}${dead ? ' (token inválido)' : ''}: ${detail}`,
    )

    return { tokenId: row.id, ok: false, dead }
  } catch (cause) {
    console.error(`FCM ${row.plataforma} error de red: ${errorMessage(cause)}`)
    return { tokenId: row.id, ok: false, dead: false }
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Método no permitido.' }, 405)
  }

  const expectedSecret = Deno.env.get('PUSH_WEBHOOK_SECRET')

  if (!expectedSecret) {
    return json(
      { error: 'Falta el secreto PUSH_WEBHOOK_SECRET en la función.' },
      500,
    )
  }

  if (req.headers.get('x-push-secret') !== expectedSecret) {
    return json({ error: 'No autorizado.' }, 401)
  }

  try {
    const body = (await req.json().catch(() => null)) as AvisoPayload | null
    const usuarioId =
      typeof body?.usuario_id === 'string' ? body.usuario_id.trim() : ''
    const avisoId = String(body?.aviso_id ?? '')
    const mensaje =
      typeof body?.mensaje === 'string'
        ? body.mensaje.trim().slice(0, MAX_BODY_LENGTH)
        : ''

    if (
      !usuarioId ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        usuarioId,
      )
    ) {
      return json({ error: 'El usuario_id no es válido.' }, 400)
    }

    if (!mensaje) {
      return json({ error: 'El aviso está vacío.' }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!supabaseUrl || !serviceRoleKey) {
      return json(
        {
          error:
            'Faltan SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en la función.',
        },
        500,
      )
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    })

    const { data: tokens, error: tokensError } = await supabase
      .from('dispositivos_push')
      .select('id, token, plataforma')
      .eq('usuario_id', usuarioId)
      .eq('activo', true)

    if (tokensError) {
      return json(
        { error: 'No se pudieron leer los dispositivos.', details: tokensError.message },
        500,
      )
    }

    const rows = (tokens ?? []) as PushToken[]

    if (rows.length === 0) {
      return json({ ok: true, sent: 0, failed: 0, removed: 0 })
    }

    const { accessToken, projectId } = await getAccessToken()

    const results = await Promise.all(
      rows.map((row) =>
        sendToToken(projectId, accessToken, row, mensaje, avisoId),
      ),
    )

    const deadIds = results.filter((item) => item.dead).map((item) => item.tokenId)

    if (deadIds.length > 0) {
      const { error: cleanupError } = await supabase
        .from('dispositivos_push')
        .update({ activo: false })
        .in('id', deadIds)

      if (cleanupError) {
        console.error(
          `No se pudieron desactivar los tokens inválidos: ${cleanupError.message}`,
        )
      }
    }

    return json({
      ok: true,
      sent: results.filter((item) => item.ok).length,
      failed: results.filter((item) => !item.ok).length,
      removed: deadIds.length,
    })
  } catch (cause) {
    console.error(`send-push error: ${errorMessage(cause)}`)

    return json(
      { error: errorMessage(cause) || 'Error inesperado al enviar el push.' },
      500,
    )
  }
})
