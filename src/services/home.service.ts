import { supabase } from './supabase'
import type { HomeAviso, HomeEstacion, HomeSnapshot } from '@/types/home'

const AVISOS_LIMIT = 10

const ESTACION_COLUMNS =
  'id, tipo_estacion_id, tipo_estacion, tipo_poste, tipo_toma, estado, estado_desde, en_cola_tipo, cargando, es_mio, mi_en_cola'

const ESTACION_PUBLIC_COLUMNS =
  'id, tipo_estacion_id, tipo_estacion, tipo_poste, tipo_toma'

export function isMissingSchemaError(message: string): boolean {
  return (
    message.includes('v_home_estaciones') ||
    message.includes('v_home_estaciones_publica') ||
    message.includes('v_home_avisos') ||
    message.includes('PGRST205') ||
    message.includes('does not exist')
  )
}

export async function fetchEstaciones(
  includeStatus: boolean,
): Promise<HomeEstacion[]> {
  if (!supabase) {
    throw new Error('Supabase no está configurado')
  }

  /*
   * Invitados: vista pública sin estado ni cola.
   * Autenticados: vista completa con el estado en tiempo real.
   */
  const vista = includeStatus
    ? 'v_home_estaciones'
    : 'v_home_estaciones_publica'

  const columnas = includeStatus
    ? ESTACION_COLUMNS
    : ESTACION_PUBLIC_COLUMNS

  const { data, error } = await supabase
    .from(vista)
    .select(columnas)
    .order('id', { ascending: true })

  if (error) {
    throw error
  }

  type EstacionRow = Pick<
    HomeEstacion,
    'id' | 'tipo_estacion_id' | 'tipo_estacion' | 'tipo_poste' | 'tipo_toma'
  > &
    Partial<
      Pick<
        HomeEstacion,
        | 'estado'
        | 'estado_desde'
        | 'en_cola_tipo'
        | 'cargando'
        | 'es_mio'
        | 'mi_en_cola'
      >
    >

  return ((data ?? []) as unknown as EstacionRow[]).map((row) => ({
    id: row.id,
    tipo_estacion_id: row.tipo_estacion_id,
    tipo_estacion: row.tipo_estacion,
    tipo_poste: row.tipo_poste,
    tipo_toma: row.tipo_toma,
    estado: row.estado ?? null,
    estado_desde: row.estado_desde ?? null,
    en_cola_tipo: row.en_cola_tipo ?? 0,
    cargando: row.cargando ?? 0,
    es_mio: row.es_mio ?? false,
    mi_en_cola: row.mi_en_cola ?? false,
  }))
}

export async function fetchAvisos(
  includeStatus = true,
): Promise<HomeAviso[]> {
  if (!includeStatus) {
    return []
  }

  if (!supabase) {
    throw new Error('Supabase no está configurado')
  }

  const { data, error } = await supabase
    .from('v_home_avisos')
    .select(
      'id, aviso, fecha_hora, estacion_id, tipo_estacion, tipo_poste, tipo_toma',
    )
    .order('fecha_hora', { ascending: false })
    .limit(AVISOS_LIMIT)

  if (error) {
    throw error
  }

  return (data ?? []) as HomeAviso[]
}

export async function fetchHomeSnapshot(
  includeStatus: boolean,
): Promise<HomeSnapshot> {
  const [estaciones, avisos] = await Promise.all([
    fetchEstaciones(includeStatus),
    fetchAvisos(includeStatus),
  ])

  return { estaciones, avisos }
}
