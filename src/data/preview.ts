import type { HomeAviso, HomeEstacion } from '@/types/home'

/**
 * Datos de vista previa local.
 *
 * Solo se usan abriendo la Home con `?preview=1`. No tocan la base de datos:
 * sirven para revisar el diseño y los estados sin depender de Supabase.
 */
export const previewEstaciones: HomeEstacion[] = [
  {
    id: 1,
    tipo_estacion: 'Transportes',
    tipo_poste: '1',
    tipo_toma: '1',
    estado: 'Ocupado',
    estado_desde: new Date(Date.now() - 26 * 60_000).toISOString(),
    en_cola: 2,
    cargando: 1,
  },
  {
    id: 2,
    tipo_estacion: 'Transportes',
    tipo_poste: '1',
    tipo_toma: '2',
    estado: 'Libre',
    estado_desde: new Date(Date.now() - 8 * 60_000).toISOString(),
    en_cola: 0,
    cargando: 0,
  },
  {
    id: 3,
    tipo_estacion: 'Transportes',
    tipo_poste: '2',
    tipo_toma: '1',
    estado: 'Ocupado',
    estado_desde: new Date(Date.now() - 2 * 60 * 60_000).toISOString(),
    en_cola: 1,
    cargando: 1,
  },
  {
    id: 4,
    tipo_estacion: 'OOAA',
    tipo_poste: '3',
    tipo_toma: '1',
    estado: 'Libre',
    estado_desde: new Date(Date.now() - 45 * 60_000).toISOString(),
    en_cola: 0,
    cargando: 0,
  },
  {
    id: 5,
    tipo_estacion: 'OOAA',
    tipo_poste: '3',
    tipo_toma: '2',
    estado: 'Ocupado',
    estado_desde: new Date(Date.now() - 12 * 60_000).toISOString(),
    en_cola: 3,
    cargando: 1,
  },
  {
    id: 6,
    tipo_estacion: 'OOAA',
    tipo_poste: '4',
    tipo_toma: '1',
    estado: null,
    estado_desde: null,
    en_cola: 0,
    cargando: 0,
  },
  {
    id: 7,
    tipo_estacion: 'Trabajo',
    tipo_poste: '5',
    tipo_toma: '1',
    estado: 'Libre',
    estado_desde: new Date(Date.now() - 3 * 60 * 60_000).toISOString(),
    en_cola: 0,
    cargando: 0,
  },
  {
    id: 8,
    tipo_estacion: 'Trabajo',
    tipo_poste: '6',
    tipo_toma: '2',
    estado: 'Ocupado',
    estado_desde: new Date(Date.now() - 5 * 60_000).toISOString(),
    en_cola: 1,
    cargando: 1,
  },
]

export const previewAvisos: HomeAviso[] = [
  {
    id: 104,
    aviso: 'La carga ha finalizado. El usuario puede desenchufar.',
    fecha_hora: new Date(Date.now() - 4 * 60_000).toISOString(),
    estacion_id: 1,
    tipo_estacion: 'Transportes',
    tipo_poste: '1',
    tipo_toma: '1',
  },
  {
    id: 103,
    aviso: 'Bajo a desenchufar en 5 minutos.',
    fecha_hora: new Date(Date.now() - 18 * 60_000).toISOString(),
    estacion_id: 5,
    tipo_estacion: 'OOAA',
    tipo_poste: '3',
    tipo_toma: '2',
  },
  {
    id: 102,
    aviso: 'Hay dos personas en lista de espera.',
    fecha_hora: new Date(Date.now() - 52 * 60_000).toISOString(),
    estacion_id: 1,
    tipo_estacion: 'Transportes',
    tipo_poste: '1',
    tipo_toma: '1',
  },
  {
    id: 101,
    aviso: 'El puesto vuelve a estar libre.',
    fecha_hora: new Date(Date.now() - 2 * 60 * 60_000).toISOString(),
    estacion_id: 2,
    tipo_estacion: 'Transportes',
    tipo_poste: '1',
    tipo_toma: '2',
  },
]
