import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Capacitor } from '@capacitor/core'
import { PushNotifications } from '@capacitor/push-notifications'
import { toastController } from '@ionic/vue'
import { useAuth } from '@/composables/useAuth'
import {
  activatePushNotifications,
  deactivatePushNotifications,
  getPushPermissionState,
  hasStoredPushToken,
  isPushSupported,
  notificationUrl,
  syncPushToken,
  type PushPermission,
} from '@/services/push.service'

const permission = ref<PushPermission>('unsupported')
const registered = ref(false)
const busy = ref(false)
const error = ref<string | null>(null)

let initialized = false
let nativeListenersBound = false
let nativePromptAttempted = false

export function usePushNotifications() {
  const router = useRouter()
  const { session } = useAuth()

  const userId = computed(() => session.value?.user.id ?? null)
  const supported = computed(() => isPushSupported())
  const enabled = computed(
    () => permission.value === 'granted' && registered.value,
  )

  async function refresh(): Promise<void> {
    permission.value = await getPushPermissionState()
    registered.value =
      permission.value === 'granted' && hasStoredPushToken()
  }

  async function initialize(): Promise<void> {
    if (initialized) return
    initialized = true

    /*
     * El watcher se registra una sola vez, aquí, y no en cada componente que
     * consuma el composable. Así Mi cuenta y App comparten el mismo estado.
     */
    watch(
      userId,
      async (id, previous) => {
        if (id === previous) return

        if (!id) {
          registered.value = false
          await deactivatePushNotifications()
          return
        }

        await refresh()

        if (permission.value === 'granted') {
          await registerForUser()
          return
        }

        /*
         * En Android se pide permiso la primera vez que hay sesión. En web se
         * deja al botón de Mi cuenta porque Chrome exige un gesto del usuario.
         */
        if (
          permission.value === 'prompt' &&
          Capacitor.isNativePlatform() &&
          !nativePromptAttempted
        ) {
          nativePromptAttempted = true
          await activate()
        }
      },
      { immediate: true },
    )

    if (Capacitor.isNativePlatform() && !nativeListenersBound) {
      nativeListenersBound = true

      try {
        await PushNotifications.addListener(
          'pushNotificationActionPerformed',
          (action) => {
            void router.push(notificationUrl(action.notification?.data))
          },
        )

        /*
         * En la Home, Realtime ya muestra el toast del aviso. En el resto de
         * pantallas mostramos un toast global para no perder la notificación.
         */
        await PushNotifications.addListener(
          'pushNotificationReceived',
          async (notification) => {
            if (router.currentRoute.value.path === '/home') return

            try {
              const toast = await toastController.create({
                message:
                  notification.body?.trim() ||
                  notification.title?.trim() ||
                  'Nuevo aviso recibido',
                duration: 3500,
                position: 'top',
                color: 'success',
              })
              await toast.present()
            } catch {
              // El toast es informativo; nunca debe romper la recepción.
            }
          },
        )
      } catch {
        // Plugin no disponible: la app sigue funcionando sin push.
      }
    }

    /*
     * En web, el service worker avisa al hacer clic en la notificación. Se
     * navega dentro del SPA en vez de recargar la página.
     */
    if (
      !Capacitor.isNativePlatform() &&
      typeof navigator !== 'undefined' &&
      'serviceWorker' in navigator
    ) {
      navigator.serviceWorker.addEventListener('message', (event) => {
        const data = event.data as { type?: unknown; url?: unknown } | null

        if (data?.type === 'push:navigate') {
          void router.push(notificationUrl(data))
        }
      })
    }
  }

  async function activate(): Promise<void> {
    if (busy.value) return

    busy.value = true
    error.value = null

    try {
      await activatePushNotifications()
      permission.value = 'granted'
      registered.value = true
    } catch (cause) {
      error.value =
        cause instanceof Error
          ? cause.message
          : 'No se pudieron activar las notificaciones.'
      await refresh()
    } finally {
      busy.value = false
    }
  }

  async function deactivate(): Promise<void> {
    if (busy.value) return

    busy.value = true
    error.value = null

    try {
      await deactivatePushNotifications()
    } finally {
      registered.value = false
      permission.value = await getPushPermissionState()
      busy.value = false
    }
  }

  async function registerForUser(): Promise<void> {
    try {
      await syncPushToken()
      registered.value = true
    } catch {
      /*
       * Un fallo de red o de configuración no debe romper la sesión: el usuario
       * puede reintentarlo desde Mi cuenta.
       */
      registered.value = false
    }
  }

  return {
    permission,
    registered,
    busy,
    error,
    supported,
    enabled,
    initialize,
    refresh,
    activate,
    deactivate,
  }
}
