import { supabase } from './supabase'
import { appUrl } from '@/utils/url'
import type { UsuarioPerfil } from '@/types/auth'

const PERFIL_COLUMNS = 'id, nombre, email, borrado, created_at'

function requireClient() {
  if (!supabase) {
    throw new Error(
      'Supabase no está configurado. Revisa VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en .env.local.',
    )
  }
  return supabase
}

export async function fetchPerfil(
  userId: string,
): Promise<UsuarioPerfil | null> {
  const client = requireClient()

  const { data, error } = await client
    .from('usuarios')
    .select(PERFIL_COLUMNS)
    .eq('id', userId)
    .maybeSingle()

  if (error) throw error

  return (data as UsuarioPerfil | null) ?? null
}

export async function login(email: string, password: string) {
  const client = requireClient()

  const { data, error } = await client.auth.signInWithPassword({
    email: email.trim().toLowerCase(),
    password,
  })

  if (error) throw error

  return data
}

export async function register(
  nombre: string,
  email: string,
  password: string,
) {
  const client = requireClient()

  const { data, error } = await client.auth.signUp({
    email: email.trim().toLowerCase(),
    password,
    options: {
      data: { nombre: nombre.trim() },
      emailRedirectTo: appUrl('/login'),
    },
  })

  if (error) throw error

  /*
   * Supabase evita revelar si un email existe: cuando ya está registrado
   * devuelve un usuario sin identidades en lugar de un error.
   */
  if (
    data.user &&
    Array.isArray(data.user.identities) &&
    data.user.identities.length === 0
  ) {
    throw new Error('Ya existe una cuenta con ese email.')
  }

  return data
}

export async function logout(): Promise<void> {
  const client = requireClient()
  const { error } = await client.auth.signOut()
  if (error) throw error
}

export async function updateNombre(
  userId: string,
  nombre: string,
): Promise<UsuarioPerfil> {
  const client = requireClient()

  const { data, error } = await client
    .from('usuarios')
    .update({ nombre: nombre.trim() })
    .eq('id', userId)
    .select(PERFIL_COLUMNS)
    .single()

  if (error) throw error

  return data as UsuarioPerfil
}

export async function cambiarEmail(email: string) {
  const client = requireClient()

  const { data, error } = await client.auth.updateUser(
    { email: email.trim().toLowerCase() },
    { emailRedirectTo: appUrl('/cuenta') },
  )

  if (error) throw error

  return data
}

export async function darDeBaja(userId: string): Promise<void> {
  const client = requireClient()

  const { data, error } = await client
    .from('usuarios')
    .update({ borrado: true })
    .eq('id', userId)
    .select('id')

  if (error) throw error

  if (!data?.length) {
    throw new Error('No se pudo dar de baja la cuenta.')
  }
}
