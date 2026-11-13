<template>
  <ion-page>
    <ion-header class="ion-no-border account-header">
      <ion-toolbar>
        <ion-buttons slot="start">
          <ion-menu-button menu="main-menu" />
        </ion-buttons>

        <ion-title>Mi cuenta</ion-title>
      </ion-toolbar>
    </ion-header>

    <ion-content class="account-content">
      <main v-if="perfil" class="account">
        <section class="profile-card">
          <span class="profile-card__avatar" aria-hidden="true">
            {{ initials }}
          </span>
          <div class="profile-card__body">
            <p class="profile-card__eyebrow">Cuenta</p>
            <h1>{{ perfil.nombre }}</h1>
            <p class="profile-card__email">{{ perfil.email }}</p>
            <p class="profile-card__meta">
              Miembro desde {{ formatFecha(perfil.created_at) }}
            </p>
          </div>
        </section>

        <section class="account-panel">
          <header class="account-panel__head">
            <h2>Datos personales</h2>
            <p>Actualiza tu nombre o cambia el email de acceso.</p>
          </header>

          <form class="form-stack" novalidate @submit.prevent="onSave">
            <div v-if="error" class="form-error" role="alert">
              {{ error }}
            </div>

            <div v-if="savedMessage" class="form-notice" role="status">
              {{ savedMessage }}
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
              :disabled="saving"
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
              :disabled="saving || Boolean(emailPendiente)"
            />

            <p v-if="emailPendiente" class="form-hint">
              Pendiente de confirmar: <strong>{{ emailPendiente }}</strong>.
              Revisa el correo enviado a esa dirección.
            </p>
            <p v-else class="form-hint">
              Si cambias el email, recibirás un enlace de confirmación. El
              cambio no se aplica hasta confirmarlo.
            </p>

            <button
              class="app-submit"
              type="submit"
              :disabled="saving || !hayCambios"
            >
              <ion-spinner v-if="saving" name="crescent" aria-hidden="true" />
              <span>{{ saving ? 'Guardando…' : 'Guardar cambios' }}</span>
            </button>
          </form>
        </section>

        <section class="account-panel account-panel--danger">
          <header class="account-panel__head">
            <h2>Dar de baja la cuenta</h2>
            <p>
              Tu perfil se marcará como inactivo y se cerrará la sesión. No
              podrás volver a acceder con esta cuenta.
            </p>
          </header>

          <button
            class="app-submit app-submit--danger"
            type="button"
            :disabled="deactivating"
            @click="showBajaAlert = true"
          >
            <ion-spinner
              v-if="deactivating"
              name="crescent"
              aria-hidden="true"
            />
            <span>
              {{ deactivating ? 'Dando de baja…' : 'Dar de baja mi cuenta' }}
            </span>
          </button>
        </section>
      </main>

      <div v-else class="account-loading">
        <ion-spinner name="crescent" aria-hidden="true" />
        <p>Cargando tu perfil…</p>
      </div>

      <ion-alert
        :is-open="showBajaAlert"
        header="Dar de baja la cuenta"
        message="Esta acción cerrará tu sesión y bloqueará el acceso. ¿Quieres continuar?"
        :buttons="bajaButtons"
        @did-dismiss="onBajaDismiss"
      />

      <ion-toast
        :is-open="toastOpen"
        :message="toastMessage"
        :color="toastColor"
        :duration="3500"
        position="top"
        @did-dismiss="toastOpen = false"
      />
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  IonAlert,
  IonButtons,
  IonContent,
  IonHeader,
  IonInput,
  IonMenuButton,
  IonPage,
  IonSpinner,
  IonTitle,
  IonToast,
  IonToolbar,
} from '@ionic/vue'
import type { AlertButton } from '@ionic/vue'
import { useAuth } from '@/composables/useAuth'
import { mapAuthError } from '@/utils/authErrors'
import { formatFecha } from '@/utils/format'

const router = useRouter()
const {
  perfil,
  session,
  initials,
  actualizarNombre,
  actualizarEmail,
  darDeBajaCuenta,
  refreshPerfil,
} = useAuth()

const nombre = ref('')
const email = ref('')
const error = ref<string | null>(null)
const savedMessage = ref<string | null>(null)
const saving = ref(false)
const deactivating = ref(false)
const showBajaAlert = ref(false)
const pendingBaja = ref(false)
const toastOpen = ref(false)
const toastMessage = ref('')
const toastColor = ref<'success' | 'danger'>('success')

const emailPendiente = computed(() => session.value?.user.new_email ?? null)

watch(
  perfil,
  (value) => {
    if (!value) return
    nombre.value = value.nombre
    email.value = value.email
  },
  { immediate: true },
)

const hayCambios = computed(() => {
  if (!perfil.value) return false

  return (
    nombre.value.trim() !== perfil.value.nombre ||
    email.value.trim().toLowerCase() !== perfil.value.email.toLowerCase()
  )
})

function showToast(
  message: string,
  color: 'success' | 'danger' = 'success',
): void {
  toastMessage.value = message
  toastColor.value = color
  toastOpen.value = true
}

async function onSave(): Promise<void> {
  error.value = null
  savedMessage.value = null

  const nombreValue = nombre.value.trim()
  const emailValue = email.value.trim().toLowerCase()

  if (nombreValue.length < 2) {
    error.value = 'El nombre debe tener al menos 2 caracteres.'
    return
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailValue)) {
    error.value = 'Introduce un email válido.'
    return
  }

  if (!perfil.value || !hayCambios.value) {
    savedMessage.value = 'No hay cambios que guardar.'
    return
  }

  saving.value = true

  try {
    const nombreCambiado = nombreValue !== perfil.value.nombre
    const emailCambiado =
      emailValue !== perfil.value.email.toLowerCase()

    if (nombreCambiado) {
      await actualizarNombre(nombreValue)
    }

    if (emailCambiado) {
      const result = await actualizarEmail(emailValue)

      if (result.pending) {
        savedMessage.value = `Te hemos enviado un correo a ${emailValue} para confirmar el cambio.`
        email.value = perfil.value?.email ?? emailValue
        showToast('Revisa tu correo para confirmar el nuevo email.')
      } else {
        await refreshPerfil()
        savedMessage.value = 'Datos actualizados correctamente.'
        showToast('Datos actualizados.')
      }
    } else {
      savedMessage.value = 'Nombre actualizado correctamente.'
      showToast('Nombre actualizado.')
    }
  } catch (cause) {
    error.value = mapAuthError(cause)
  } finally {
    saving.value = false
  }
}

const bajaButtons: AlertButton[] = [
  {
    text: 'Cancelar',
    role: 'cancel',
  },
  {
    text: 'Dar de baja',
    role: 'destructive',
    handler: () => {
      pendingBaja.value = true
    },
  },
]

async function onBajaDismiss(): Promise<void> {
  showBajaAlert.value = false

  if (!pendingBaja.value) return

  pendingBaja.value = false

  /*
   * Esperamos a que Ionic termine de retirar el overlay del DOM antes de
   * cerrar la sesión, que desmonta la página actual.
   */
  await new Promise((resolve) => setTimeout(resolve, 250))

  await confirmarBaja()
}

async function confirmarBaja(): Promise<void> {
  deactivating.value = true

  try {
    await darDeBajaCuenta()
    await router.replace({ name: 'login' })
  } catch (cause) {
    showToast(mapAuthError(cause), 'danger')
    deactivating.value = false
  }
}
</script>

<style scoped>
.account-header {
  background: rgba(7, 12, 11, 0.72);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  border-bottom: 1px solid var(--app-border);
}

.account-header ion-toolbar {
  --background: transparent;
  --border-width: 0;
  --min-height: 60px;
  --color: var(--app-text);
}

.account-header ion-title {
  font-size: 0.96rem;
  font-weight: 650;
  letter-spacing: -0.01em;
}

.account-header ion-menu-button {
  --color: var(--app-text);
}

.account-content {
  --background: transparent;
  --padding-bottom: 0;
}

.account {
  width: min(100%, 840px);
  margin: 0 auto;
  padding: 26px 28px 40px;
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.profile-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  border-radius: var(--app-radius);
  border: 1px solid var(--app-border);
  background: linear-gradient(
    160deg,
    rgba(19, 31, 27, 0.95),
    rgba(10, 16, 14, 0.86)
  );
  box-shadow: var(--app-shadow);
}

.profile-card__avatar {
  display: grid;
  place-items: center;
  width: 64px;
  height: 64px;
  flex: none;
  border-radius: 20px;
  color: #04120d;
  font-size: 1.3rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  background: linear-gradient(145deg, #3cf0a8, #16b97b);
  box-shadow:
    0 14px 30px -16px rgba(43, 229, 156, 0.85),
    inset 0 1px 0 rgba(255, 255, 255, 0.4);
}

.profile-card__body {
  min-width: 0;
}

.profile-card__eyebrow {
  margin: 0;
  font-size: 0.64rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--app-green);
}

.profile-card__body h1 {
  margin: 3px 0 0;
  font-size: 1.35rem;
  line-height: 1.2;
  letter-spacing: -0.02em;
  font-weight: 700;
  color: var(--app-text);
  overflow-wrap: anywhere;
}

.profile-card__email {
  margin: 2px 0 0;
  font-size: 0.83rem;
  color: var(--app-muted);
  overflow-wrap: anywhere;
}

.profile-card__meta {
  margin: 6px 0 0;
  font-size: 0.7rem;
  color: var(--app-dim);
}

.account-panel {
  min-width: 0;
  padding: 20px;
  border-radius: var(--app-radius);
  border: 1px solid var(--app-border);
  background: linear-gradient(
    180deg,
    rgba(15, 23, 21, 0.84),
    rgba(9, 15, 13, 0.76)
  );
  box-shadow: var(--app-shadow);
}

.account-panel__head {
  margin-bottom: 16px;
}

.account-panel__head h2 {
  margin: 0;
  font-size: 1.02rem;
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.account-panel__head p {
  margin: 4px 0 0;
  font-size: 0.78rem;
  line-height: 1.5;
  color: var(--app-muted);
}

.account-panel--danger {
  border-color: rgba(255, 82, 82, 0.22);
  background: linear-gradient(
    180deg,
    rgba(48, 18, 18, 0.45),
    rgba(15, 10, 10, 0.75)
  );
}

.account-panel--danger .account-panel__head h2 {
  color: #ffb3b3;
}

.account-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 80px 16px;
  color: var(--app-muted);
  font-size: 0.82rem;
}

@media (max-width: 820px) {
  .account {
    padding: 20px 16px 34px;
  }

  .profile-card {
    padding: 16px;
  }

  .profile-card__avatar {
    width: 54px;
    height: 54px;
    border-radius: 16px;
    font-size: 1.1rem;
  }

  .account-panel {
    padding: 16px;
  }
}
</style>
