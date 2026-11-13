import { supabase } from './supabase'

export interface AuthSettings {
  emailVerificationRequired: boolean
  signupsEnabled: boolean
}

export interface UpdatedAuthSettings {
  emailVerificationRequired: boolean
  mailer_autoconfirm: boolean
}

/**
 * Lee la configuración pública de Supabase Auth.
 *
 * El ajuste real de verificación por email es `mailer_autoconfirm`:
 *   - false -> la creación exige confirmar el email.
 *   - true  -> la cuenta se activa al crearla.
 *
 * No se cachea: así un cambio en el dashboard de Supabase se refleja al
 * volver a entrar en la pantalla de registro.
 */
export async function fetchAuthSettings(): Promise<AuthSettings> {
  const url = import.meta.env.VITE_SUPABASE_URL?.trim()
  const key = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim()

  if (!url || !key) {
    throw new Error('Supabase no está configurado.')
  }

  const response = await fetch(
    `${url.replace(/\/+$/, '')}/auth/v1/settings`,
    {
      headers: { apikey: key },
      cache: 'no-store',
    },
  )

  if (!response.ok) {
    throw new Error(
      `No se pudo leer la configuración de Auth (${response.status}).`,
    )
  }

  const data = (await response.json()) as {
    mailer_autoconfirm?: boolean
    disable_signup?: boolean
  }

  return {
    emailVerificationRequired: data.mailer_autoconfirm !== true,
    signupsEnabled: data.disable_signup !== true,
  }
}

/**
 * Cambia el ajuste de confirmación de email.
 *
 * No se hace desde el frontend con la Management API: se invoca una Edge
 * Function que comprueba que el usuario es administrador y guarda el PAT de
 * Supabase en el servidor.
 */
export async function updateEmailVerificationRequired(
  required: boolean,
): Promise<UpdatedAuthSettings> {
  if (!supabase) {
    throw new Error('Supabase no está configurado.')
  }

  const { data, error } = await supabase.functions.invoke('auth-settings', {
    body: { emailVerificationRequired: required },
  })

  if (error) {
    let message = error.message
    const context = (error as { context?: Response }).context

    if (context) {
      try {
        const body = (await context.clone().json()) as { error?: string }
        if (body?.error) {
          message = body.error
        }
      } catch {
        // El cuerpo no era JSON; se mantiene el mensaje original.
      }
    }

    throw new Error(message || 'No se pudo actualizar la configuración.')
  }

  const result = data as Partial<UpdatedAuthSettings> | null

  return {
    emailVerificationRequired:
      result?.emailVerificationRequired ?? required,
    mailer_autoconfirm: result?.mailer_autoconfirm ?? !required,
  }
}
