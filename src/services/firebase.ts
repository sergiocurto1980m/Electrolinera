import type { Messaging } from 'firebase/messaging'
import { Capacitor } from '@capacitor/core'

/*
 * Configuración pública de la app Web de Firebase. La apiKey de Firebase no es
 * un secreto: la seguridad de FCM está en la cuenta de servicio del servidor.
 */
const firebaseConfig = {
  apiKey: (import.meta.env.VITE_FIREBASE_API_KEY ?? '').trim(),
  projectId: (import.meta.env.VITE_FIREBASE_PROJECT_ID ?? '').trim(),
  messagingSenderId: (
    import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? ''
  ).trim(),
  appId: (import.meta.env.VITE_FIREBASE_APP_ID ?? '').trim(),
}

export const vapidKey = (import.meta.env.VITE_FIREBASE_VAPID_KEY ?? '').trim()

export const isWebPushConfigured = Boolean(
  firebaseConfig.apiKey &&
    firebaseConfig.projectId &&
    firebaseConfig.messagingSenderId &&
    firebaseConfig.appId &&
    vapidKey,
)

export function isWebPushAvailable(): boolean {
  return (
    !Capacitor.isNativePlatform() &&
    typeof window !== 'undefined' &&
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    'Notification' in window
  )
}

let messagingPromise: Promise<Messaging | null> | null = null

/**
 * Devuelve la instancia web de Firebase Messaging solo cuando de verdad se va a
 * usar. Los imports son dinámicos para no cargar Firebase en Android.
 */
export async function getWebMessaging(): Promise<Messaging | null> {
  if (!isWebPushConfigured || !isWebPushAvailable()) {
    return null
  }

  if (!messagingPromise) {
    messagingPromise = (async () => {
      const [{ getApp, getApps, initializeApp }, { getMessaging, isSupported }] =
        await Promise.all([import('firebase/app'), import('firebase/messaging')])

      if (!(await isSupported())) {
        return null
      }

      const app = getApps().length ? getApp() : initializeApp(firebaseConfig)
      return getMessaging(app)
    })().catch(() => null)
  }

  return messagingPromise
}

/**
 * Registro del service worker propio que recibe los push en segundo plano.
 * Se pasa explícitamente a getToken() para no depender de
 * `firebase-messaging-sw.js` ni duplicar la configuración de Firebase.
 */
export async function getWebPushRegistration(): Promise<ServiceWorkerRegistration> {
  if (!isWebPushAvailable()) {
    throw new Error('Este navegador no admite notificaciones push.')
  }

  const existing = await navigator.serviceWorker.getRegistration('/')

  if (existing) {
    return existing
  }

  return navigator.serviceWorker.register('/push-sw.js', { scope: '/' })
}
