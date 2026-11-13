import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { App } from '@capacitor/app'
import { Capacitor } from '@capacitor/core'
import type { RealtimeChannel } from '@supabase/supabase-js'
import { fetchHomeSnapshot, isMissingSchemaError } from '@/services/home.service'
import { isSupabaseConfigured, supabase } from '@/services/supabase'
import { previewAvisos, previewEstaciones } from '@/data/preview'
import { useAuth } from '@/composables/useAuth'
import type {
  HomeAviso,
  HomeEstacion,
  HomeKpis,
  HomeToast,
  LiveStatus,
} from '@/types/home'

const COALESCE_MS = 400

/**
 * Estado de la Home + suscripción Realtime.
 *
 * - Una sola consulta inicial (2 peticiones en paralelo, una por vista).
 * - Un único canal WebSocket para las 4 tablas implicadas.
 * - Los eventos se agrupan durante 400 ms para evitar ráfagas de renders.
 * - Al ocultar la app o la pestaña se cierra el canal; al volver se
 *   resuscribe y se hace un único resync.
 */
export function useHomeLive() {
  const isPreview =
    typeof window !== 'undefined' &&
    new URLSearchParams(window.location.search).has('preview')

  const { isAuthenticated } = useAuth()

  const estaciones = ref<HomeEstacion[]>([])
  const avisos = ref<HomeAviso[]>([])
  const loading = ref(true)
  const refreshing = ref(false)
  const error = ref<string | null>(null)
  const status = ref<LiveStatus>(isPreview ? 'live' : 'connecting')
  const lastSync = ref<Date | null>(null)
  const toast = ref<HomeToast | null>(null)

  const kpis = computed<HomeKpis>(() => {
    const total = estaciones.value.length
    const libres = estaciones.value.filter((item) => item.estado === 'Libre').length
    const ocupadas = estaciones.value.filter((item) => item.estado === 'Ocupado').length

    return {
      total,
      libres,
      ocupadas,
      sinEstado: estaciones.value.filter((item) => !item.estado).length,
      enCola: estaciones.value.reduce((sum, item) => sum + (item.en_cola ?? 0), 0),
      cargando: estaciones.value.reduce((sum, item) => sum + (item.cargando ?? 0), 0),
    }
  })

  const hasData = computed(
    () => estaciones.value.length > 0 || avisos.value.length > 0,
  )

  let channel: RealtimeChannel | null = null
  let channelSeq = 0
  let refreshTimer: ReturnType<typeof setTimeout> | null = null
  let loadVersion = 0
  let mounted = false
  let paused = false
  let appListener: { remove: () => Promise<void> } | null = null

  function getErrorMessage(cause: unknown): string {
    if (cause instanceof Error) {
      return cause.message
    }

    if (typeof cause === 'object' && cause !== null && 'message' in cause) {
      const message = (cause as { message?: unknown }).message
      if (typeof message === 'string' && message.length > 0) {
        return message
      }
    }

    return String(cause)
  }

  async function load(silent = false): Promise<void> {
    if (isPreview) {
      loading.value = false
      refreshing.value = false
      return
    }

    if (!supabase) {
      loading.value = false
      refreshing.value = false
      error.value =
        'Falta configurar VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en .env.local.'
      status.value = 'error'
      return
    }

    if (!silent) {
      loading.value = true
    }
    refreshing.value = true

    const version = ++loadVersion

    try {
      const snapshot = await fetchHomeSnapshot(isAuthenticated.value)

      if (version !== loadVersion) return

      estaciones.value = snapshot.estaciones
      avisos.value = snapshot.avisos
      lastSync.value = new Date()
      error.value = null
    } catch (cause) {
      if (version !== loadVersion) return

      const message = getErrorMessage(cause)
      error.value = isMissingSchemaError(message)
        ? 'Falta crear las vistas de la Home. Ejecuta supabase/migrations/0001_home.sql y 0003_home_public.sql en el SQL Editor de Supabase.'
        : message
    } finally {
      if (version === loadVersion) {
        loading.value = false
        refreshing.value = false
      }
    }
  }

  function scheduleRefresh(): void {
    if (isPreview || paused) return

    if (refreshTimer) {
      clearTimeout(refreshTimer)
    }

    refreshTimer = setTimeout(() => {
      refreshTimer = null
      void load(true)
    }, COALESCE_MS)
  }

  function subscribe(): void {
    if (!supabase || isPreview || channel) return

    status.value = 'connecting'

    let next = supabase
      .channel(`home-live-${++channelSeq}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'estaciones' },
        () => scheduleRefresh(),
      )

    /*
     * El catálogo de estaciones se actualiza para todos. El estado, la cola y
     * los avisos solo se escuchan con sesión: las políticas RLS de Supabase
     * también impiden que un invitado reciba esos eventos.
     */
    if (isAuthenticated.value) {
      next = next
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'situacion_estacion' },
          () => scheduleRefresh(),
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'lista_espera_estacion' },
          () => scheduleRefresh(),
        )
        .on(
          'postgres_changes',
          { event: 'INSERT', schema: 'public', table: 'avisos' },
          (payload) => {
            const row = payload.new as { aviso?: string } | null
            toast.value = {
              id: Date.now(),
              message: row?.aviso?.trim() || 'Nuevo aviso recibido',
            }
            scheduleRefresh()
          },
        )
    }

    channel = next.subscribe((state) => {
      if (state === 'SUBSCRIBED') {
        status.value = 'live'
      } else if (state === 'CHANNEL_ERROR' || state === 'TIMED_OUT') {
        status.value = 'offline'
      } else if (state === 'CLOSED') {
        status.value = paused ? 'paused' : 'offline'
      }
    })
  }

  function unsubscribe(nextStatus: LiveStatus = 'paused'): void {
    if (refreshTimer) {
      clearTimeout(refreshTimer)
      refreshTimer = null
    }

    if (channel) {
      void supabase?.removeChannel(channel)
      channel = null
    }

    status.value = nextStatus
  }

  function pause(): void {
    if (isPreview || paused) return
    paused = true
    unsubscribe('paused')
  }

  async function resume(): Promise<void> {
    if (isPreview || !mounted || !paused) return
    paused = false
    subscribe()
    await load(true)
  }

  function onVisibilityChange(): void {
    if (document.hidden) {
      pause()
    } else {
      void resume()
    }
  }

  async function refresh(event?: CustomEvent): Promise<void> {
    await load(true)
    const target = event?.target as { complete?: () => void } | null
    target?.complete?.()
  }

  function dismissToast(): void {
    toast.value = null
  }

  onMounted(async () => {
    mounted = true

    if (isPreview) {
      estaciones.value = previewEstaciones
      avisos.value = previewAvisos
      lastSync.value = new Date()
      loading.value = false
      return
    }

    await load()
    subscribe()

    document.addEventListener('visibilitychange', onVisibilityChange)

    if (Capacitor.isNativePlatform()) {
      appListener = await App.addListener('appStateChange', ({ isActive }) => {
        if (isActive) {
          void resume()
        } else {
          pause()
        }
      })
    }
  })

  onBeforeUnmount(() => {
    mounted = false
    paused = true
    document.removeEventListener('visibilitychange', onVisibilityChange)
    void appListener?.remove()
    appListener = null
    unsubscribe('offline')
  })

  /*
   * Si la sesión cambia mientras la Home sigue montada, recargamos con la
   * vista que corresponda y reconstruimos el canal Realtime.
   */
  watch(isAuthenticated, async (authenticated) => {
    if (!authenticated) {
      avisos.value = []
      toast.value = null
    }

    if (isPreview || !mounted || paused) return

    unsubscribe('connecting')
    await load()
    subscribe()
  })

  return {
    estaciones,
    avisos,
    loading,
    refreshing,
    error,
    status,
    lastSync,
    toast,
    kpis,
    hasData,
    isPreview,
    isSupabaseConfigured,
    refresh,
    dismissToast,
  }
}
