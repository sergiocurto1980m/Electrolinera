export function appUrl(path = ''): string {
  const base = (
    import.meta.env.VITE_APP_URL?.trim() || window.location.origin
  ).replace(/\/+$/, '')

  if (!path) return base

  return `${base}${path.startsWith('/') ? path : `/${path}`}`
}
