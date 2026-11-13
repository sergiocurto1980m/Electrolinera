import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Método no permitido.' }, 405)
  }

  try {
    const authHeader = req.headers.get('Authorization')

    if (!authHeader) {
      return json({ error: 'No autenticado.' }, 401)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const managementToken = Deno.env.get('MANAGEMENT_ACCESS_TOKEN')

    if (!supabaseUrl || !supabaseAnonKey) {
      return json(
        {
          error:
            'Faltan SUPABASE_URL o SUPABASE_ANON_KEY en la Edge Function.',
        },
        500,
      )
    }

    if (!managementToken) {
      return json(
        {
          error:
            'Falta el secreto MANAGEMENT_ACCESS_TOKEN. Configúralo con un personal access token de Supabase.',
        },
        500,
      )
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
      global: {
        headers: { Authorization: authHeader },
      },
    })

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser()

    if (userError || !user) {
      return json({ error: 'Sesión no válida.' }, 401)
    }

    const { data: perfil, error: perfilError } = await userClient
      .from('usuarios')
      .select('es_admin')
      .eq('id', user.id)
      .maybeSingle()

    if (perfilError) {
      return json({ error: 'No se pudo verificar el perfil.' }, 500)
    }

    if (!perfil?.es_admin) {
      return json(
        { error: 'Solo un administrador puede cambiar esta configuración.' },
        403,
      )
    }

    const body = (await req.json().catch(() => null)) as {
      emailVerificationRequired?: unknown
    } | null

    if (
      !body ||
      typeof body.emailVerificationRequired !== 'boolean'
    ) {
      return json(
        { error: 'El parámetro emailVerificationRequired no es válido.' },
        400,
      )
    }

    const projectRef = new URL(supabaseUrl).hostname.split('.')[0]
    const managementResponse = await fetch(
      `https://api.supabase.com/v1/projects/${projectRef}/config/auth`,
      {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${managementToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          mailer_autoconfirm: !body.emailVerificationRequired,
        }),
      },
    )

    if (!managementResponse.ok) {
      const details = await managementResponse.text()

      return json(
        {
          error: 'Supabase Management API rechazó el cambio.',
          details,
          status: managementResponse.status,
        },
        502,
      )
    }

    return json({
      ok: true,
      emailVerificationRequired: body.emailVerificationRequired,
      mailer_autoconfirm: !body.emailVerificationRequired,
    })
  } catch (cause) {
    return json(
      {
        error:
          cause instanceof Error
            ? cause.message
            : 'Error inesperado al cambiar la configuración.',
      },
      500,
    )
  }
})
