export type EstadoEstacion = 'Libre' | 'Ocupado'

export interface HomeEstacion {
  id: number
  tipo_estacion: string
  tipo_poste: string
  tipo_toma: string
  estado: EstadoEstacion | null
  estado_desde: string | null
  en_cola: number
  cargando: number
}

export interface HomeAviso {
  id: number
  aviso: string
  fecha_hora: string
  estacion_id: number
  tipo_estacion: string
  tipo_poste: string
  tipo_toma: string
}

export interface HomeSnapshot {
  estaciones: HomeEstacion[]
  avisos: HomeAviso[]
}

export interface HomeGrupoEstacion {
  tipo: string
  total: number
  libres: HomeEstacion[]
  ocupadas: HomeEstacion[]
  sinEstado: HomeEstacion[]
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
