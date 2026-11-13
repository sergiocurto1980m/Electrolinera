import { createRouter, createWebHistory } from '@ionic/vue-router'
import type { RouteRecordRaw } from 'vue-router'
import AccountPage from '@/views/AccountPage.vue'
import HomePage from '@/views/HomePage.vue'
import LoginPage from '@/views/LoginPage.vue'
import RegisterPage from '@/views/RegisterPage.vue'
import { useAuth } from '@/composables/useAuth'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/home',
  },
  {
    path: '/login',
    name: 'login',
    component: LoginPage,
    meta: { public: true, authPage: true },
  },
  {
    path: '/registro',
    name: 'registro',
    component: RegisterPage,
    meta: { public: true, authPage: true },
  },
  {
    path: '/home',
    name: 'home',
    component: HomePage,
    meta: { public: true },
  },
  {
    path: '/cuenta',
    name: 'cuenta',
    component: AccountPage,
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/home',
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

router.beforeEach(async (to) => {
  const { initAuth, isAuthenticated } = useAuth()
  await initAuth()

  /*
   * Las páginas de acceso son las únicas que redirigen a un usuario ya
   * autenticado. La Home es pública y se puede ver con o sin sesión.
   */
  if (to.meta.authPage) {
    if (!isAuthenticated.value) return true

    const redirect =
      typeof to.query.redirect === 'string' &&
      to.query.redirect.startsWith('/') &&
      !to.query.redirect.startsWith('//')
        ? to.query.redirect
        : '/home'

    if (redirect.startsWith('/login') || redirect.startsWith('/registro')) {
      return '/home'
    }

    return redirect
  }

  if (to.meta.public) {
    return true
  }

  if (!isAuthenticated.value) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  return true
})

export default router
