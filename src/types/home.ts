export type EstadoEstacion = 'Libre' | 'Ocupado'

export interface HomeEstacion {
  id: number
  tipo_estacion_id: number
  tipo_estacion: string
  tipo_poste: string
  tipo_toma: string
  estado: EstadoEstacion | null
  estado_desde: string | null
  en_cola_tipo: number
  cargando: number
  es_mio: boolean
  mi_en_cola: boolean
}

export interface HomeAviso {
  id: number
  aviso: string
  fecha_hora: string
  estacion_id: number | null
  tipo_estacion: string
  tipo_poste: string | null
  tipo_toma: string | null
}

export interface HomeColaItem {
  tipo_estacion_id: number
  posicion: number
  nombre: string
  es_mio: boolean
  fecha_hora: string
}

export interface HomeSnapshot {
  estaciones: HomeEstacion[]
  avisos: HomeAviso[]
  cola: HomeColaItem[]
}

export interface HomeGrupoEstacion {
  tipoId: number
  tipo: string
  total: number
  libres: HomeEstacion[]
  ocupadas: HomeEstacion[]
  sinEstado: HomeEstacion[]
  cola: HomeColaItem[]
  enCola: number
  miEnCola: boolean
  completo: boolean
}

export interface HomeKpis {
  total: number
  libres: number
  ocupadas: number
  sinEstado: number
  enCola: number
  cargando: number
}

export interface HomeToast {
  id: number
  message: string
}

export type LiveStatus = 'connecting' | 'live' | 'paused' | 'offline' | 'error'
