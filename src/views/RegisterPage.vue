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

          <p v-if="!emailVerificationRequired" class="form-hint">
            La configuración de Supabase no ha permitido el alta inmediata.
            Revisa la opción «Confirm email» en Authentication.
          </p>

          <router-link class="app-submit register-success__link" to="/login">
            Ir a iniciar sesión
          </router-link>
        </div>

        <form v-else class="form-stack" novalidate @submit.prevent="onSubmit">
          <div v-if="error" class="form-error" role="alert">
            {{ error }}
          </div>

          <div v-if="settingsLoading" class="register-mode">
            <ion-spinner name="dots" aria-hidden="true" />
            <span>Comprobando la configuración de registro…</span>
          </div>

          <div v-else-if="settingsError" class="register-mode register-mode--warning">
            <ion-icon :icon="alertCircleOutline" aria-hidden="true" />
            <span>
              No se pudo comprobar la configuración. El resultado del alta
              dependerá de Supabase.
            </span>
          </div>

          <div v-else-if="!signupsEnabled" class="register-mode register-mode--disabled">
            <ion-icon :icon="alertCircleOutline" aria-hidden="true" />
            <span>
              El registro está deshabilitado temporalmente. Contacta con el
              administrador.
            </span>
          </div>

          <div v-else class="register-mode">
            <ion-icon
              :icon="emailVerificationRequired ? mailOutline : flashOutline"
              aria-hidden="true"
            />
            <span>
              {{
                emailVerificationRequired
                  ? 'Te enviaremos un correo para confirmar la cuenta.'
                  : 'La cuenta se activará inmediatamente al crearla.'
              }}
            </span>
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
            :disabled="loading || !signupsEnabled"
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
            :disabled="loading || !signupsEnabled"
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
            :disabled="loading || !signupsEnabled"
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
            :disabled="loading || !signupsEnabled"
          >
            <ion-input-password-toggle slot="end" />
          </ion-input>

          <button
            class="app-submit"
            type="submit"
            :disabled="loading || settingsLoading || !signupsEnabled"
          >
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
  onIonViewWillEnter,
} from '@ionic/vue'
import {
  alertCircleOutline,
  checkmarkCircleOutline,
  flashOutline,
  mailOutline,
} from 'ionicons/icons'
import AuthShell from '@/components/AuthShell.vue'
import { useAuth } from '@/composables/useAuth'
import { fetchAuthSettings } from '@/services/authSettings.service'
import type { AuthSettings } from '@/services/authSettings.service'
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

const authSettings = ref<AuthSettings | null>(null)
const settingsLoading = ref(true)
const settingsError = ref<string | null>(null)

const emailVerificationRequired = computed(
  () => authSettings.value?.emailVerificationRequired ?? true,
)

const signupsEnabled = computed(
  () => authSettings.value?.signupsEnabled ?? true,
)

async function loadAuthSettings(): Promise<void> {
  settingsLoading.value = true
  settingsError.value = null

  try {
    authSettings.value = await fetchAuthSettings()
  } catch {
    authSettings.value = null
    settingsError.value = 'No se pudo comprobar la configuración de registro.'
  } finally {
    settingsLoading.value = false
  }
}

onIonViewWillEnter(() => {
  void loadAuthSettings()
})

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

  if (settingsLoading.value) {
    return
  }

  if (!signupsEnabled.value) {
    error.value = 'El registro está deshabilitado temporalmente.'
    return
  }

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

.register-mode {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 10px 12px;
  border-radius: 10px;
  border: 1px solid var(--app-border);
  background: rgba(148, 190, 175, 0.04);
  color: var(--app-muted);
  font-size: 0.76rem;
  line-height: 1.45;
}

.register-mode ion-icon {
  flex: none;
  margin-top: 1px;
  font-size: 16px;
  color: var(--app-green);
}

.register-mode ion-spinner {
  flex: none;
  width: 15px;
  height: 15px;
  margin-top: 1px;
}

.register-mode--warning {
  border-color: rgba(255, 176, 32, 0.25);
  background: rgba(255, 176, 32, 0.05);
  color: var(--app-amber);
}

.register-mode--warning ion-icon {
  color: var(--app-amber);
}

.register-mode--disabled {
  border-color: rgba(255, 82, 82, 0.25);
  background: rgba(255, 82, 82, 0.05);
  color: #ffb3b3;
}

.register-mode--disabled ion-icon {
  color: #ffb3b3;
}
</style>
