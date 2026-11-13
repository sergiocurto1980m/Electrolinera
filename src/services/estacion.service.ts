import { supabase } from './supabase'

function requireClient() {
  if (!supabase) {
    throw new Error(
      'Supabase no está configurado. Revisa VITE_SUPABASE_URL y VITE_SUPABASE_ANON_KEY en .env.local.',
    )
  }
  return supabase
}

export async function engancharse(estacionId: number) {
  const client = requireClient()
  const { data, error } = await client.rpc('engancharse', {
    p_estacion_id: estacionId,
  })

  if (error) throw error

  return data
}

export async function desengancharse(estacionId: number) {
  const client = requireClient()
  const { data, error } = await client.rpc('desengancharse', {
    p_estacion_id: estacionId,
  })

  if (error) throw error

  return data
}

export async function entrarEnCola(tipoEstacionId: number) {
  const client = requireClient()
  const { data, error } = await client.rpc('entrar_en_cola', {
    p_tipo_estacion_id: tipoEstacionId,
  })

  if (error) throw error

  return data
}

export async function salirDeCola(tipoEstacionId: number) {
  const client = requireClient()
  const { data, error } = await client.rpc('salir_de_cola', {
    p_tipo_estacion_id: tipoEstacionId,
  })

  if (error) throw error

  return data
}
