import 'vue-router'

declare module 'vue-router' {
  interface RouteMeta {
    public?: boolean
    authPage?: boolean
    adminOnly?: boolean
  }
}
