import { computed, ref } from 'vue'
import type { Session } from '@supabase/supabase-js'
import {
  cambiarEmail,
  darDeBaja,
  fetchPerfil,
  login,
  logout,
  register,
  updateNombre,
} from '@/services/auth.service'
import { supabase } from '@/services/supabase'
import { deactivatePushNotifications } from '@/services/push.service'
import type { ResultadoCambioEmail, UsuarioPerfil } from '@/types/auth'

const session = ref<Session | null>(null)
const perfil = ref<UsuarioPerfil | null>(null)
const initialized = ref(false)
const loading = ref(true)
const notice = ref<string | null>(null)

let initPromise: Promise<void> | null = null
let listenerRegistered = false

export function useAuth() {
  const isAuthenticated = computed(() => Boolean(session.value))

  const initials = computed(() => {
    const source =
      perfil.value?.nombre?.trim() ||
      perfil.value?.email ||
      session.value?.user.email ||
      ''

    const parts = source.split(/\s+/).filter(Boolean)
    if (!parts.length) return '?'

    return parts
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase() ?? '')
      .join('')
  })

  async function syncPerfil(): Promise<void> {
    const userId = session.value?.user.id

    if (!supabase || !userId) {
      perfil.value = null
      return
    }

    try {
      const profile = await fetchPerfil(userId)

      if (!profile) {
        perfil.value = null
        notice.value =
          'No se pudo cargar tu perfil. Ejecuta supabase/migrations/0002_users.sql en Supabase.'
        await supabase.auth.signOut()
        return
      }

      if (profile.borrado) {
        perfil.value = null
        notice.value =
          'Tu cuenta está dada de baja. Contacta con el administrador si necesitas reactivarla.'
        await supabase.auth.signOut()
        return
      }

      perfil.value = profile
    } catch {
      /*
       * Error transitorio (red, RLS sin aplicar...). No cerramos la sesión
       * para no expulsar al usuario por un fallo puntual.
       */
      perfil.value = null
    }
  }

  function initAuth(): Promise<void> {
    if (initPromise) return initPromise

    initPromise = (async () => {
      if (!supabase) {
        initialized.value = true
        loading.value = false
        return
      }

      if (!listenerRegistered) {
        listenerRegistered = true

        supabase.auth.onAuthStateChange((event, newSession) => {
          session.value = newSession

          if (event === 'SIGNED_OUT' || !newSession) {
            perfil.value = null
            return
          }

          if (
            event === 'SIGNED_IN' ||
            event === 'TOKEN_REFRESHED' ||
            event === 'USER_UPDATED'
          ) {
            /*
             * Supabase recomienda no hacer llamadas al cliente dentro del
             * callback de auth; lo sacamos al siguiente tick.
             */
            setTimeout(() => {
              void syncPerfil()
            }, 0)
          }
        })
      }

      try {
        const { data } = await supabase.auth.getSession()
        session.value = data.session

        if (data.session) {
          await syncPerfil()
        }
      } finally {
        initialized.value = true
        loading.value = false
      }
    })()
    return initPromise
  }

  async function signIn(email: string, password: string): Promise<void> {
    const data = await login(email, password)
    session.value = data.session

    const profile = await fetchPerfil(data.user.id)

    if (!profile) {
      await supabase?.auth.signOut()
      session.value = null
      perfil.value = null
      throw new Error(
        'No se encontró el perfil de usuario. Ejecuta supabase/migrations/0002_users.sql o contacta con el administrador.',
      )
    }

    if (profile.borrado) {
      await supabase?.auth.signOut()
      session.value = null
      perfil.value = null
      throw new Error('Esta cuenta está dada de baja y no puede iniciar sesión.')
    }

    perfil.value = profile
    notice.value = null
  }

  async function signUp(nombre: string, email: string, password: string) {
    const data = await register(nombre, email, password)

    if (data.session) {
      session.value = data.session
      await syncPerfil()
    }

    return data
  }

  async function signOut(): Promise<void> {
    /*
     * Se borra el token de push antes de cerrar la sesión: la RPC necesita el
     * JWT para identificar al usuario.
     */
    await deactivatePushNotifications()

    try {
      await logout()
    } finally {
      session.value = null
      perfil.value = null
    }
  }

  async function actualizarNombre(nombre: string): Promise<void> {
    const userId = session.value?.user.id

    if (!userId) {
      throw new Error('No hay una sesión activa.')
    }

    perfil.value = await updateNombre(userId, nombre)
  }

  async function actualizarEmail(
    email: string,
  ): Promise<ResultadoCambioEmail> {
    if (!supabase || !session.value) {
      throw new Error('No hay una sesión activa.')
    }

    const nuevoEmail = email.trim().toLowerCase()
    const data = await cambiarEmail(nuevoEmail)
    const pending = Boolean(data.user?.new_email)

    const { data: current } = await supabase.auth.getSession()
    if (current.session) {
      session.value = current.session
    }

    if (!pending) {
      await syncPerfil()
    }

    return { pending, email: nuevoEmail }
  }

  async function darDeBajaCuenta(): Promise<void> {
    const userId = session.value?.user.id

    if (!userId) {
      throw new Error('No hay una sesión activa.')
    }

    await darDeBaja(userId)

    // El token se elimina mientras la sesión aún es válida.
    await deactivatePushNotifications()

    notice.value = 'Tu cuenta se ha dado de baja correctamente.'
    perfil.value = null
    session.value = null

    try {
      await logout()
    } catch {
      // La sesión local ya está limpia; no bloqueamos la baja por un fallo de red.
    }
  }

  async function refreshPerfil(): Promise<void> {
    await syncPerfil()
  }

  function setNotice(message: string | null): void {
    notice.value = message
  }

  function clearNotice(): void {
    notice.value = null
  }

  return {
    session,
    perfil,
    initialized,
    loading,
    notice,
    isAuthenticated,
    initials,
    initAuth,
    signIn,
    signUp,
    signOut,
    actualizarNombre,
    actualizarEmail,
    darDeBajaCuenta,
    refreshPerfil,
    setNotice,
    clearNotice,
  }
}
