/*
 * Service worker de notificaciones push de Electrolinera.
 *
 * No importa el SDK de Firebase a propósito: el navegador ya descifra el
 * payload de FCM y aquí solo se muestra la notificación y se gestiona el clic.
 * Así no hay que duplicar la configuración de Firebase en un archivo estático.
 */

const DEFAULT_TITLE = 'Electrolinera'
const DEFAULT_URL = '/home'
const ICON = '/favicon.svg'

function parsePayload(event) {
  if (!event.data) return null

  try {
    return event.data.json()
  } catch {
    try {
      return { notification: { body: event.data.text() } }
    } catch {
      return null
    }
  }
}

function safeUrl(value) {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//')) {
    return DEFAULT_URL
  }

  return value
}

self.addEventListener('push', (event) => {
  const payload = parsePayload(event)

  if (!payload) return

  const notification = payload.notification || {}
  const data = payload.data || {}
  const title = notification.title || DEFAULT_TITLE
  const body = notification.body || data.mensaje || 'Tienes un nuevo aviso.'
  const url = safeUrl(data.url)

  event.waitUntil(
    (async () => {
      const clientList = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      })

      /*
       * Con la Home abierta y enfocada, Realtime ya muestra el aviso. En
       * cualquier otra pantalla sí interesa la notificación del sistema.
       */
      const homeFocused = clientList.some((client) => {
        if (!client.focused) return false

        try {
          return new URL(client.url).pathname === '/home'
        } catch {
          return false
        }
      })

      if (homeFocused) {
        return
      }

      await self.registration.showNotification(title, {
        body,
        icon: ICON,
        badge: ICON,
        data: { url, avisoId: data.aviso_id || null },
        tag: data.aviso_id ? `aviso-${data.aviso_id}` : undefined,
        renotify: Boolean(data.aviso_id),
      })
    })(),
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const target = safeUrl(event.notification.data && event.notification.data.url)

  event.waitUntil(
    (async () => {
      const clientList = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      })

      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin)) {
          client.postMessage({ type: 'push:navigate', url: target })
          await client.focus()
          return
        }
      }

      await self.clients.openWindow(target)
    })(),
  )
})
