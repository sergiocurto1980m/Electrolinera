import { Capacitor } from '@capacitor/core'
import { PushNotifications } from '@capacitor/push-notifications'
import type { PermissionState } from '@capacitor/core'
import {
  getWebMessaging,
  getWebPushRegistration,
  isWebPushAvailable,
  isWebPushConfigured,
  vapidKey,
} from './firebase'
import { supabase } from './supabase'

export type PushPlatform = 'web' | 'android'
export type PushPermission = 'unsupported' | 'prompt' | 'granted' | 'denied'

export type StoredPushToken = {
  token: string
  plataforma: PushPlatform
}

const STORAGE_KEY = 'electrolinera.push.token'
const CHANNEL_ID = 'avisos'
const LOGOUT_TIMEOUT_MS = 3_000

let channelPromise: Promise<void> | null = null

/**
 * El cierre de sesión no puede quedarse esperando a la red. Si la RPC tarda
 * más de lo razonable, se limpia el token local y el servidor lo invalidará
 * cuando FCM rechace el token huérfano.
 */
function withTimeout<T>(promise: PromiseLike<T>, ms: number): Promise<T | null> {
  return new Promise((resolve) => {
    let settled = false

    const timer = setTimeout(() => {
      if (settled) return
      settled = true
      resolve(null)
    }, ms)

    Promise.resolve(promise).then(
      (value) => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        resolve(value)
      },
      () => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        resolve(null)
      },
    )
  })
}

function isNative(): boolean {
  return Capacitor.isNativePlatform()
}

function currentPlatform(): PushPlatform | null {
  if (isNative()) {
    return Capacitor.getPlatform() === 'android' ? 'android' : null
  }

  return 'web'
}

function readStoredToken(): StoredPushToken | null {
  if (typeof localStorage === 'undefined') return null

  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return null

    const parsed = JSON.parse(raw) as Partial<StoredPushToken>

    if (
      typeof parsed.token !== 'string' ||
      !parsed.token ||
      (parsed.plataforma !== 'web' && parsed.plataforma !== 'android')
    ) {
      return null
    }

    return { token: parsed.token, plataforma: parsed.plataforma }
  } catch {
    return null
  }
}

function saveStoredToken(value: StoredPushToken): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(value))
  } catch {
    // Almacenamiento no disponible: el token se registrará igualmente en BD.
  }
}

function clearStoredToken(): void {
  try {
    localStorage.removeItem(STORAGE_KEY)
  } catch {
    // Sin almacenamiento no hay nada que limpiar.
  }
}

function mapNativePermission(state: PermissionState): PushPermission {
  if (state === 'granted') return 'granted'
  if (state === 'denied') return 'denied'
  if (state === 'prompt' || state === 'prompt-with-rationale') return 'prompt'
  return 'unsupported'
}

function deviceLabel(): string | null {
  if (typeof navigator === 'undefined') return null
  return navigator.userAgent.slice(0, 255) || null
}

export function isPushSupported(): boolean {
  if (isNative()) {
    return Capacitor.getPlatform() === 'android'
  }

  return isWebPushConfigured && isWebPushAvailable()
}

export function hasStoredPushToken(): boolean {
  return readStoredToken() !== null
}

export async function getPushPermissionState(): Promise<PushPermission> {
  if (!isPushSupported()) {
    return 'unsupported'
  }

  try {
    if (isNative()) {
      const status = await PushNotifications.checkPermissions()
      return mapNativePermission(status.receive)
    }

    if (typeof Notification === 'undefined') {
      return 'unsupported'
    }

    if (Notification.permission === 'granted') return 'granted'
    if (Notification.permission === 'denied') return 'denied'
    return 'prompt'
  } catch {
    return 'unsupported'
  }
}

/**
 * El canal debe existir antes de recibir un push con `channel_id`. Se crea al
 * arrancar la app, que es cuando también se registra el token.
 */
function ensureNativeChannel(): Promise<void> {
  if (!isNative()) {
    return Promise.resolve()
  }

  if (!channelPromise) {
    channelPromise = PushNotifications.createChannel({
      id: CHANNEL_ID,
      name: 'Avisos',
      description: 'Avisos de cola y puestos libres',
      importance: 4,
      visibility: 1,
      vibration: true,
      lights: true,
      lightColor: '#22c55e',
    }).catch(() => undefined)
  }

  return channelPromise
}

async function getNativeToken(): Promise<string> {
  await ensureNativeChannel()

  return new Promise<string>((resolve, reject) => {
    const handles: Array<{ remove: () => Promise<void> }> = []
    let settled = false

    const finish = (action: () => void): void => {
      if (settled) return
      settled = true
      clearTimeout(timer)
      void Promise.all(handles.map((handle) => handle.remove().catch(() => undefined)))
      action()
    }

    const timer = setTimeout(() => {
      finish(() => reject(new Error('El dispositivo no devolvió el token de FCM a tiempo.')))
    }, 15_000)

    void (async () => {
      try {
        handles.push(
          await PushNotifications.addListener('registration', (token) => {
            finish(() => resolve(token.value))
          }),
        )
        handles.push(
          await PushNotifications.addListener('registrationError', (error) => {
            finish(() => reject(new Error(error.error || 'Error al registrar el dispositivo.')))
          }),
        )

        await PushNotifications.register()
      } catch (cause) {
        finish(() =>
          reject(cause instanceof Error ? cause : new Error('Error al registrar el dispositivo.')),
        )
      }
    })()
  })
}

async function getWebToken(): Promise<string> {
  const messaging = await getWebMessaging()

  if (!messaging) {
    throw new Error(
      'Firebase no está configurado en la web. Revisa VITE_FIREBASE_* y VITE_FIREBASE_VAPID_KEY.',
    )
  }

  const registration = await getWebPushRegistration()

  if (!registration.active) {
    await navigator.serviceWorker.ready
  }

  const { getToken } = await import('firebase/messaging')

  const token = await getToken(messaging, {
    vapidKey,
    serviceWorkerRegistration: registration,
  })

  if (!token) {
    throw new Error('Firebase no devolvió un token de notificaciones.')
  }

  return token
}

/**
 * Obtiene el token de FCM del dispositivo actual y lo guarda en Supabase.
 * Debe existir una sesión: la RPC usa auth.uid().
 */
export async function syncPushToken(): Promise<void> {
  if (!supabase) {
    throw new Error('Supabase no está configurado.')
  }

  const plataforma = currentPlatform()

  if (!plataforma) {
    throw new Error('Las notificaciones push no están disponibles en esta plataforma.')
  }

  const token = plataforma === 'android' ? await getNativeToken() : await getWebToken()

  const { error } = await supabase.rpc('registrar_dispositivo_push', {
    p_token: token,
    p_plataforma: plataforma,
    p_user_agent: deviceLabel(),
  })

  if (error) {
    throw new Error(error.message)
  }

  saveStoredToken({ token, plataforma })
}

/**
 * Pide permiso y registra el token. En web debe llamarse desde un gesto del
 * usuario (clic) para que Chrome muestre el diálogo.
 */
export async function activatePushNotifications(): Promise<void> {
  if (!isPushSupported()) {
    throw new Error(
      isNative()
        ? 'Las notificaciones push solo están disponibles en la app Android.'
        : 'Este navegador no admite notificaciones push o falta configurar Firebase.',
    )
  }

  if (isNative()) {
    await ensureNativeChannel()
    const status = await PushNotifications.requestPermissions()

    if (status.receive !== 'granted') {
      throw new Error('No se ha concedido el permiso de notificaciones.')
    }
  } else {
    if (typeof Notification === 'undefined') {
      throw new Error('Este navegador no admite notificaciones.')
    }

    const result = await Notification.requestPermission()

    if (result !== 'granted') {
      throw new Error('No se ha concedido el permiso de notificaciones.')
    }
  }

  await syncPushToken()
}

/**
 * Borra el token del dispositivo en Supabase y desuscribe FCM. Pensado para
 * logout y para el botón de desactivar. Nunca lanza: el cierre de sesión no
 * debe depender de la red.
 */
export async function deactivatePushNotifications(): Promise<void> {
  const stored = readStoredToken()

  if (stored && supabase) {
    await withTimeout(
      supabase.rpc('eliminar_dispositivo_push', { p_token: stored.token }),
      LOGOUT_TIMEOUT_MS,
    )
  }

  try {
    if (isNative()) {
      /*
       * En Android se invalida el token FCM aunque no quede constancia local.
       * Al volver a iniciar sesión se registrará uno nuevo.
       */
      await PushNotifications.unregister()
    } else if (stored?.plataforma === 'web' && isWebPushAvailable()) {
      /*
       * Se cancela la suscripción del navegador aunque Firebase no tenga ya
       * la instancia activa en esta carga de página.
       */
      const registration = await navigator.serviceWorker.getRegistration('/')
      const subscription = await registration?.pushManager.getSubscription()

      if (subscription) {
        await subscription.unsubscribe()
      }

      const messaging = await getWebMessaging()

      if (messaging) {
        const { deleteToken } = await import('firebase/messaging')
        await deleteToken(messaging).catch(() => undefined)
      }
    }
  } catch {
    // Desregistrar es best-effort.
  }

  clearStoredToken()
}

/**
 * Extrae una ruta interna segura de los datos del push, para el deep link.
 */
export function notificationUrl(data: unknown): string {
  if (data && typeof data === 'object' && 'url' in data) {
    const url = (data as { url?: unknown }).url

    if (typeof url === 'string' && url.startsWith('/') && !url.startsWith('//')) {
      return url
    }
  }

  return '/home'
}
