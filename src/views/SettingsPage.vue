<template>
  <ion-page>
    <ion-header class="ion-no-border settings-header">
      <ion-toolbar>
        <ion-buttons slot="start">
          <ion-menu-button menu="main-menu" />
        </ion-buttons>

        <ion-title>Configuración</ion-title>
      </ion-toolbar>
    </ion-header>

    <ion-content class="settings-content">
      <main v-if="perfil" class="settings">
        <section class="settings-panel">
          <header class="settings-panel__head">
            <p class="settings-panel__eyebrow">Administración</p>
            <h1>Registro de usuarios</h1>
            <p>Controla cómo se activan las cuentas nuevas en Electrolinera.</p>
          </header>

          <div v-if="loading" class="settings-loading">
            <ion-spinner name="crescent" aria-hidden="true" />
            <span>Cargando configuración…</span>
          </div>

          <template v-else>
            <div v-if="error" class="form-error" role="alert">
              {{ error }}
            </div>

            <div v-if="!settings" class="settings-actions">
              <button class="app-submit" type="button" @click="load">
                Reintentar
              </button>
            </div>

            <template v-else>
              <div class="setting-row">
                <div class="setting-row__copy">
                  <h2>Confirmar email en el registro</h2>
                  <p v-if="draft">
                    Los nuevos usuarios deberán confirmar su correo antes de
                    entrar.
                  </p>
                  <p v-else>
                    La cuenta se activará inmediatamente al crearla.
                  </p>
                </div>

                <ion-toggle
                  v-model="draft"
                  :disabled="saving"
                  aria-label="Confirmar email en el registro"
                />
              </div>

              <p class="settings-current">
                Estado actual:
                <strong>
                  {{ saved ? 'Confirmación activada' : 'Alta inmediata' }}
                </strong>
              </p>

              <div class="settings-note">
                <ion-icon :icon="informationCircleOutline" aria-hidden="true" />
                <p>
                  Este ajuste afecta a todos los nuevos registros. No activa
                  retroactivamente usuarios que ya estén pendientes de
                  confirmar.
                </p>
              </div>

              <div v-if="!signupsEnabled" class="form-notice">
                El registro está desactivado en Supabase. Este ajuste se
                aplicará cuando vuelvas a activarlo.
              </div>

              <div class="settings-actions">
                <button
                  class="app-submit"
                  type="button"
                  :disabled="saving || !hasChanges"
                  @click="onSave"
                >
                  <ion-spinner
                    v-if="saving"
                    name="crescent"
                    aria-hidden="true"
                  />
                  <span>{{ saving ? 'Guardando…' : 'Guardar cambios' }}</span>
                </button>
              </div>

              <p class="settings-hint">
                El interruptor usa la Edge Function
                <code>auth-settings</code> y el secreto
                <code>MANAGEMENT_ACCESS_TOKEN</code>.
              </p>
            </template>
          </template>
        </section>
      </main>

      <div v-else class="settings-loading">
        <ion-spinner name="crescent" aria-hidden="true" />
        <p>Cargando perfil…</p>
      </div>

      <ion-toast
        :key="toast?.id ?? 0"
        :is-open="toast !== null"
        :message="toast?.message ?? ''"
        :duration="4000"
        position="bottom"
        color="success"
        @did-dismiss="toast = null"
      />
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonMenuButton,
  IonPage,
  IonSpinner,
  IonTitle,
  IonToast,
  IonToggle,
  IonToolbar,
  onIonViewWillEnter,
} from '@ionic/vue'
import { informationCircleOutline } from 'ionicons/icons'
import { useAuth } from '@/composables/useAuth'
import {
  fetchAuthSettings,
  updateEmailVerificationRequired,
} from '@/services/authSettings.service'
import type { AuthSettings } from '@/services/authSettings.service'

const router = useRouter()
const { perfil } = useAuth()

const settings = ref<AuthSettings | null>(null)
const saved = ref(false)
const draft = ref(false)
const loading = ref(true)
const saving = ref(false)
const error = ref<string | null>(null)
const toast = ref<{ id: number; message: string } | null>(null)

const signupsEnabled = computed(
  () => settings.value?.signupsEnabled ?? true,
)

const hasChanges = computed(() => draft.value !== saved.value)

async function load(): Promise<void> {
  loading.value = true
  error.value = null

  try {
    const result = await fetchAuthSettings()
    settings.value = result
    saved.value = result.emailVerificationRequired
    draft.value = result.emailVerificationRequired
  } catch {
    error.value = 'No se pudo cargar la configuración actual.'
  } finally {
    loading.value = false
  }
}

onIonViewWillEnter(() => {
  if (perfil.value && !perfil.value.es_admin) {
    void router.replace({ name: 'home' })
    return
  }

  void load()
})

async function onSave(): Promise<void> {
  if (saving.value || !hasChanges.value) return

  saving.value = true
  error.value = null

  try {
    const result = await updateEmailVerificationRequired(draft.value)
    saved.value = result.emailVerificationRequired
    draft.value = result.emailVerificationRequired
    settings.value = settings.value
      ? {
          ...settings.value,
          emailVerificationRequired: result.emailVerificationRequired,
        }
      : settings.value
    toast.value = {
      id: Date.now(),
      message: 'Configuración actualizada.',
    }
  } catch (cause) {
    error.value =
      cause instanceof Error
        ? cause.message
        : 'No se pudo actualizar la configuración.'
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.settings-header {
  background: rgba(7, 12, 11, 0.72);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  border-bottom: 1px solid var(--app-border);
}

.settings-header ion-toolbar {
  --background: transparent;
  --border-width: 0;
  --min-height: 60px;
  --color: var(--app-text);
}

.settings-header ion-title {
  font-size: 0.96rem;
  font-weight: 650;
  letter-spacing: -0.01em;
}

.settings-header ion-menu-button {
  --color: var(--app-text);
}

.settings-content {
  --background: transparent;
  --padding-bottom: 0;
}

.settings {
  width: min(100%, 840px);
  margin: 0 auto;
  padding: 26px 28px 40px;
}

.settings-panel {
  padding: 22px;
  border-radius: var(--app-radius);
  border: 1px solid var(--app-border);
  background: linear-gradient(
    180deg,
    rgba(15, 23, 21, 0.9),
    rgba(9, 15, 13, 0.8)
  );
  box-shadow: var(--app-shadow);
}

.settings-panel__eyebrow {
  margin: 0;
  font-size: 0.64rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--app-green);
}

.settings-panel__head h1 {
  margin: 5px 0 0;
  font-size: 1.35rem;
  font-weight: 700;
  letter-spacing: -0.025em;
  color: var(--app-text);
}

.settings-panel__head > p:last-child {
  margin: 5px 0 0;
  font-size: 0.82rem;
  line-height: 1.5;
  color: var(--app-muted);
}

.settings-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 48px 16px;
  color: var(--app-muted);
  font-size: 0.82rem;
}

.setting-row {
  display: flex;
  align-items: center;
  gap: 18px;
  margin-top: 22px;
  padding: 16px;
  border-radius: 14px;
  border: 1px solid var(--app-border);
  background: rgba(7, 12, 11, 0.38);
}

.setting-row__copy {
  flex: 1;
  min-width: 0;
}

.setting-row__copy h2 {
  margin: 0;
  font-size: 0.92rem;
  font-weight: 650;
  color: var(--app-text);
}

.setting-row__copy p {
  margin: 4px 0 0;
  font-size: 0.76rem;
  line-height: 1.45;
  color: var(--app-muted);
}

.setting-row ion-toggle {
  --handle-background-checked: #16b97b;
  --track-background-checked: rgba(43, 229, 156, 0.35);
  flex: none;
}

.settings-current {
  margin: 12px 2px 0;
  font-size: 0.74rem;
  color: var(--app-muted);
}

.settings-current strong {
  color: var(--app-green);
  font-weight: 650;
}

.settings-note {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 14px;
  padding: 10px 12px;
  border-radius: 10px;
  border: 1px solid var(--app-border);
  background: rgba(148, 190, 175, 0.04);
  color: var(--app-muted);
  font-size: 0.74rem;
  line-height: 1.45;
}

.settings-note ion-icon {
  flex: none;
  margin-top: 1px;
  font-size: 16px;
  color: var(--app-cyan);
}

.settings-note p {
  margin: 0;
}

.settings-actions {
  margin-top: 20px;
}

.settings-actions .app-submit {
  width: auto;
  min-width: 190px;
}

.settings-hint {
  margin: 12px 2px 0;
  font-size: 0.68rem;
  line-height: 1.5;
  color: var(--app-dim);
}

.settings-hint code {
  padding: 1px 5px;
  border-radius: 5px;
  background: rgba(148, 190, 175, 0.08);
  color: var(--app-muted);
}

@media (max-width: 820px) {
  .settings {
    padding: 20px 16px 34px;
  }

  .settings-panel {
    padding: 18px;
  }

  .setting-row {
    align-items: flex-start;
  }

  .settings-actions .app-submit {
    width: 100%;
  }
}
</style>
