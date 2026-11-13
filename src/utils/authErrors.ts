function getMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message
  }

  if (typeof error === 'object' && error !== null && 'message' in error) {
    const message = (error as { message?: unknown }).message
    if (typeof message === 'string' && message.length > 0) {
      return message
    }
  }

  return String(error)
}

export function mapAuthError(error: unknown): string {
  const message = getMessage(error)
  const normalized = message.toLowerCase()

  if (normalized.includes('invalid login credentials')) {
    return 'Email o contraseña incorrectos.'
  }

  if (normalized.includes('email not confirmed')) {
    return 'Debes confirmar tu correo antes de iniciar sesión.'
  }

  if (
    normalized.includes('already registered') ||
    normalized.includes('already been registered') ||
    normalized.includes('user already registered')
  ) {
    return 'Ya existe una cuenta con ese email.'
  }

  if (
    normalized.includes('email address is invalid') ||
    normalized.includes('unable to validate email')
  ) {
    return 'El email no es válido.'
  }

  if (normalized.includes('password should be at least')) {
    return 'La contraseña no cumple los requisitos mínimos de seguridad.'
  }

  if (
    normalized.includes('for security purposes') ||
    normalized.includes('rate limit')
  ) {
    return 'Demasiados intentos. Espera unos minutos y vuelve a intentarlo.'
  }

  if (normalized.includes('new email address should be different')) {
    return 'El nuevo email debe ser diferente al actual.'
  }

  if (
    normalized.includes('failed to fetch') ||
    normalized.includes('networkerror')
  ) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión.'
  }

  return message || 'Ha ocurrido un error inesperado.'
}
