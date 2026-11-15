<template>
  <ion-page>
    <ion-content class="auth-content" :fullscreen="true">
      <auth-shell
        title="Descarga la app"
        subtitle="Instala Electrolinera en tu Android y llévala siempre contigo."
      >
        <div v-if="esNativo" class="download-state" role="status">
          <ion-icon :icon="checkmarkCircleOutline" aria-hidden="true" />
          <p>Ya estás usando la app de Android.</p>
        </div>

        <div v-else-if="cargando" class="download-state" role="status">
          <ion-spinner name="crescent" aria-hidden="true" />
          <p>Comprobando la última versión…</p>
        </div>

        <div v-else-if="info" class="download">
          <div class="download__summary">
            <span class="download__icon" aria-hidden="true">
              <ion-icon :icon="downloadOutline" />
            </span>
            <div class="download__meta">
              <p class="download__label">Versión</p>
              <p class="download__version">{{ info.version }}</p>
            </div>
          </div>

          <a
            class="app-submit download__action"
            href="/downloads/electrolinera.apk"
            download
          >
            <ion-icon :icon="downloadOutline" aria-hidden="true" />
            <span>Descargar APK</span>
          </a>

          <p class="download__hint">
            Compatible con Android 7 o superior. Tendrás que permitir la
            instalación desde orígenes desconocidos.
          </p>
        </div>

        <div v-else class="download-state">
          <p>La próxima versión estará disponible en breve.</p>
        </div>

        <template #footer>
          <router-link class="download-back" :to="{ name: 'home' }">
            Volver al inicio
          </router-link>
        </template>
      </auth-shell>
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { IonContent, IonIcon, IonPage, IonSpinner } from '@ionic/vue'
import { Capacitor } from '@capacitor/core'
import { checkmarkCircleOutline, downloadOutline } from 'ionicons/icons'
import AuthShell from '@/components/AuthShell.vue'

interface ApkInfo {
  version: string
  build: number
  date: string
  size: number
}

const esNativo = Capacitor.isNativePlatform()
const cargando = ref(!esNativo)
const info = ref<ApkInfo | null>(null)

onMounted(async () => {
  if (esNativo) return

  try {
    const response = await fetch('/downloads/latest.json', { cache: 'no-cache' })

    if (response.ok) {
      const data = (await response.json()) as Partial<ApkInfo>

      if (typeof data.version === 'string' && data.version.length > 0) {
        info.value = data as ApkInfo
      }
    }
  } catch {
    info.value = null
  } finally {
    cargando.value = false
  }
})
</script>

<style scoped>
.auth-content {
  --background: transparent;
  --padding-bottom: 0;
}

.download {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.download__summary {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 16px;
  border-radius: 14px;
  border: 1px solid var(--app-border);
  background: rgba(7, 12, 11, 0.45);
}

.download__icon {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  flex: none;
  border-radius: 13px;
  color: var(--app-green);
  background: rgba(43, 229, 156, 0.1);
  box-shadow: inset 0 0 0 1px rgba(43, 229, 156, 0.24);
}

.download__icon ion-icon {
  font-size: 22px;
}

.download__meta {
  min-width: 0;
}

.download__label {
  margin: 0;
  font-size: 0.64rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--app-muted);
}

.download__version {
  margin: 3px 0 0;
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--app-text);
  font-variant-numeric: tabular-nums;
}

.download__action {
  text-decoration: none;
}

.download__hint {
  margin: 0;
  font-size: 0.72rem;
  line-height: 1.45;
  color: var(--app-dim);
  text-align: center;
}

.download-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 22px 8px;
  text-align: center;
  color: var(--app-muted);
  font-size: 0.84rem;
}

.download-state ion-icon {
  font-size: 26px;
  color: var(--app-green);
}

.download-state ion-spinner {
  width: 24px;
  height: 24px;
  color: var(--app-green);
}

.download-state p {
  margin: 0;
}

.download-back {
  color: var(--app-green);
  font-weight: 600;
  text-decoration: none;
}

.download-back:hover {
  text-decoration: underline;
}
</style>
