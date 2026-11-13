const timeFormatter = new Intl.DateTimeFormat('es-ES', {
  hour: '2-digit',
  minute: '2-digit',
})

const dateTimeFormatter = new Intl.DateTimeFormat('es-ES', {
  day: '2-digit',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
})

const longDateFormatter = new Intl.DateTimeFormat('es-ES', {
  day: '2-digit',
  month: 'long',
  year: 'numeric',
})

function toDate(value: string | Date): Date | null {
  const date = value instanceof Date ? value : new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

export function formatHora(value: string | Date | null | undefined): string {
  if (!value) return '—'
  const date = toDate(value)
  return date ? timeFormatter.format(date) : '—'
}

export function formatFechaHora(value: string | Date | null | undefined): string {
  if (!value) return '—'
  const date = toDate(value)
  return date ? dateTimeFormatter.format(date) : '—'
}

export function formatFecha(value: string | Date | null | undefined): string {
  if (!value) return '—'
  const date = toDate(value)
  return date ? longDateFormatter.format(date) : '—'
}

export function formatDesde(value: string | Date | null | undefined): string {
  if (!value) return 'Sin registros'

  const date = toDate(value)
  if (!date) return 'Sin registros'

  const diff = Math.max(0, Date.now() - date.getTime())
  const minutes = Math.floor(diff / 60_000)

  if (minutes < 1) return 'ahora mismo'
  if (minutes < 60) return `hace ${minutes} min`

  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `hace ${hours} h`

  const days = Math.floor(hours / 24)
  if (days === 1) return `ayer ${formatHora(date)}`

  return dateTimeFormatter.format(date)
}

export function formatNumero(value: number): string {
  return new Intl.NumberFormat('es-ES').format(value)
}

export function pluralizar(
  cantidad: number,
  singular: string,
  plural: string,
): string {
  return `${cantidad} ${cantidad === 1 ? singular : plural}`
}
