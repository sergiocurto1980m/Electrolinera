<template>
  <ion-page>
    <ion-content class="auth-content" :fullscreen="true">
      <auth-shell
        title="Inicia sesión"
        subtitle="Accede al panel de control de tu red de carga."
      >
        <form class="form-stack" novalidate @submit.prevent="onSubmit">
          <div v-if="notice" class="form-notice" role="status">
            <ion-icon :icon="checkmarkCircleOutline" aria-hidden="true" />
            <span>{{ notice }}</span>
          </div>

          <div v-if="linkError && !notice" class="form-error" role="alert">
            {{ linkError }}
          </div>

          <div v-if="error" class="form-error" role="alert">
            {{ error }}
          </div>

          <ion-input
            v-model="email"
            class="app-input"
            label="Email"
            label-placement="stacked"
            type="email"
            fill="outline"
            autocomplete="email"
            inputmode="email"
            placeholder="tu@email.com"
            :disabled="loading"
            autofocus
          />

          <ion-input
            v-model="password"
            class="app-input"
            label="Contraseña"
            label-placement="stacked"
            type="password"
            fill="outline"
            autocomplete="current-password"
            placeholder="Tu contraseña"
            :disabled="loading"
          >
            <ion-input-password-toggle slot="end" />
          </ion-input>

          <button class="app-submit" type="submit" :disabled="loading">
            <ion-spinner v-if="loading" name="crescent" aria-hidden="true" />
            <span>{{ loading ? 'Entrando…' : 'Entrar' }}</span>
          </button>
        </form>

        <template #footer>
          ¿No tienes cuenta?
          <router-link to="/registro">Crear una cuenta</router-link>
        </template>
      </auth-shell>
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  IonContent,
  IonIcon,
  IonInput,
  IonInputPasswordToggle,
  IonPage,
  IonSpinner,
} from '@ionic/vue'
import { checkmarkCircleOutline } from 'ionicons/icons'
import AuthShell from '@/components/AuthShell.vue'
import { useAuth } from '@/composables/useAuth'
import { mapAuthError } from '@/utils/authErrors'

const route = useRoute()
const router = useRouter()
const { signIn, isAuthenticated, notice, clearNotice } = useAuth()

const email = ref('')
const password = ref('')
const error = ref<string | null>(null)
const loading = ref(false)

const linkError = computed(() => {
  if (
    typeof route.query.error_description === 'string' ||
    typeof route.query.error === 'string'
  ) {
    return 'El enlace de confirmación no es válido o ha caducado. Vuelve a solicitar el correo.'
  }
  return null
})

const redirectTarget = computed(() => {
  const redirect = route.query.redirect

  if (
    typeof redirect === 'string' &&
    redirect.startsWith('/') &&
    !redirect.startsWith('//') &&
    !redirect.startsWith('/login') &&
    !redirect.startsWith('/registro')
  ) {
    return redirect
  }

  return '/home'
})

async function afterLogin(): Promise<void> {
  await router.replace(redirectTarget.value)
}

watch(
  isAuthenticated,
  (authenticated) => {
    if (authenticated) {
      void afterLogin()
    }
  },
  { immediate: true },
)

async function onSubmit(): Promise<void> {
  error.value = null

  const emailValue = email.value.trim()

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailValue)) {
    error.value = 'Introduce un email válido.'
    return
  }

  if (!password.value) {
    error.value = 'Introduce tu contraseña.'
    return
  }

  loading.value = true

  try {
    await signIn(emailValue, password.value)
    clearNotice()
    await afterLogin()
  } catch (cause) {
    error.value = mapAuthError(cause)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth-content {
  --background: transparent;
  --padding-bottom: 0;
}
</style>
