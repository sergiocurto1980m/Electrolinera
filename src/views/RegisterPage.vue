<template>
  <ion-page>
    <ion-content class="auth-content" :fullscreen="true">
      <auth-shell :title="title" :subtitle="subtitle">
        <div v-if="success" class="register-success">
          <div class="form-notice" role="status">
            <ion-icon :icon="checkmarkCircleOutline" aria-hidden="true" />
            <span>
              Hemos enviado un enlace de confirmación a
              <strong>{{ registeredEmail }}</strong>. Revisa tu correo y pulsa
              el enlace para activar la cuenta.
            </span>
          </div>

          <router-link class="app-submit register-success__link" to="/login">
            Ir a iniciar sesión
          </router-link>
        </div>

        <form v-else class="form-stack" novalidate @submit.prevent="onSubmit">
          <div v-if="error" class="form-error" role="alert">
            {{ error }}
          </div>

          <ion-input
            v-model="nombre"
            class="app-input"
            label="Nombre"
            label-placement="stacked"
            type="text"
            fill="outline"
            autocomplete="name"
            placeholder="Tu nombre"
            :disabled="loading"
            autofocus
          />

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
          />

          <ion-input
            v-model="password"
            class="app-input"
            label="Contraseña"
            label-placement="stacked"
            type="password"
            fill="outline"
            autocomplete="new-password"
            placeholder="Mínimo 8 caracteres"
            :disabled="loading"
          >
            <ion-input-password-toggle slot="end" />
          </ion-input>

          <p class="form-hint">Mínimo 8 caracteres.</p>

          <ion-input
            v-model="confirmar"
            class="app-input"
            label="Repite la contraseña"
            label-placement="stacked"
            type="password"
            fill="outline"
            autocomplete="new-password"
            placeholder="Repite tu contraseña"
            :disabled="loading"
          >
            <ion-input-password-toggle slot="end" />
          </ion-input>

          <button class="app-submit" type="submit" :disabled="loading">
            <ion-spinner v-if="loading" name="crescent" aria-hidden="true" />
            <span>{{ loading ? 'Creando cuenta…' : 'Crear cuenta' }}</span>
          </button>
        </form>

        <template #footer>
          ¿Ya tienes cuenta?
          <router-link to="/login">Inicia sesión</router-link>
        </template>
      </auth-shell>
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
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

const router = useRouter()
const { signUp, isAuthenticated } = useAuth()

const nombre = ref('')
const email = ref('')
const password = ref('')
const confirmar = ref('')
const error = ref<string | null>(null)
const loading = ref(false)
const success = ref(false)
const registeredEmail = ref('')

const title = computed(() =>
  success.value ? 'Revisa tu correo' : 'Crea tu cuenta',
)

const subtitle = computed(() =>
  success.value
    ? 'Confirma tu email para activar el acceso.'
    : 'Registra tu acceso a Electrolinera.',
)

watch(isAuthenticated, (authenticated) => {
  if (authenticated) {
    void router.replace('/home')
  }
})

async function onSubmit(): Promise<void> {
  error.value = null

  const nombreValue = nombre.value.trim()
  const emailValue = email.value.trim()

  if (nombreValue.length < 2) {
    error.value = 'Introduce tu nombre.'
    return
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailValue)) {
    error.value = 'Introduce un email válido.'
    return
  }

  if (password.value.length < 8) {
    error.value = 'La contraseña debe tener al menos 8 caracteres.'
    return
  }

  if (password.value !== confirmar.value) {
    error.value = 'Las contraseñas no coinciden.'
    return
  }

  loading.value = true

  try {
    const data = await signUp(nombreValue, emailValue, password.value)

    if (data.session) {
      await router.replace('/home')
      return
    }

    registeredEmail.value = emailValue
    success.value = true
    password.value = ''
    confirmar.value = ''
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

.register-success {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.register-success .form-notice {
  align-items: flex-start;
}

.register-success .form-notice ion-icon {
  flex: none;
  margin-top: 1px;
  font-size: 16px;
}

.register-success__link {
  text-decoration: none;
}
</style>
