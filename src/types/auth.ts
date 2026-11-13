export interface UsuarioPerfil {
  id: string
  nombre: string
  email: string
  borrado: boolean
  created_at: string
}

export interface ResultadoCambioEmail {
  pending: boolean
  email: string
}
