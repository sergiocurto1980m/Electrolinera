<template>
  <ion-page>
    <ion-header class="ion-no-border home-header">
      <ion-toolbar>
        <ion-buttons slot="start">
          <ion-menu-button
            v-if="isAuthenticated"
            menu="main-menu"
          />
        </ion-buttons>

        <ion-title>Electrolinera</ion-title>

        <ion-buttons slot="end" class="home-header__actions">
          <connection-badge :status="connectionStatus" />
          <header-user />
        </ion-buttons>
      </ion-toolbar>
    </ion-header>

    <ion-content class="home-content">
      <ion-refresher slot="fixed" @ion-refresh="refresh">
        <ion-refresher-content />
      </ion-refresher>

      <main class="home">
        <section class="hero">
          <div class="hero__copy">
            <span class="hero__eyebrow">
              <span class="hero__pulse" aria-hidden="true" />
              {{ isAuthenticated ? 'Panel de control' : 'Red de carga' }}
            </span>
            <h1>
              {{ isAuthenticated ? 'Estado de la red' : 'Red de estaciones' }}
            </h1>
            <p>{{ subtitle }}</p>
          </div>

          <button
            class="refresh-btn"
            type="button"
            :disabled="refreshing"
            @click="refresh()"
          >
            <ion-icon
              :icon="refreshOutline"
              :class="{ spinning: refreshing }"
              aria-hidden="true"
            />
            <span>{{ refreshing ? 'Actualizando…' : 'Actualizar' }}</span>
          </button>
        </section>

        <div v-if="error" class="alert" role="alert">
          <ion-icon :icon="warningOutline" aria-hidden="true" />
          <div class="alert__body">
            <strong>No se pudieron cargar los datos</strong>
            <p>{{ error }}</p>
          </div>
          <button class="alert__action" type="button" @click="refresh()">
            Reintentar
          </button>
        </div>

        <div v-if="isPreview" class="preview">
          <ion-icon :icon="flashOutline" aria-hidden="true" />
          <span>
            Vista previa local con datos de ejemplo. Abre la app sin
            <code>?preview=1</code> para usar Supabase.
          </span>
        </div>

        <section
          v-if="!isAuthenticated"
          class="login-cta"
          aria-labelledby="login-cta-title"
        >
          <span class="login-cta__icon" aria-hidden="true">
            <ion-icon :icon="lockClosedOutline" />
          </span>

          <div class="login-cta__copy">
            <h2 id="login-cta-title">¿Quieres ver qué puestos están libres?</h2>
            <p>
              El estado de cada estación está reservado a usuarios registrados.
              Crea una cuenta para consultarlo en tiempo real.
            </p>
          </div>

          <div class="login-cta__actions">
            <router-link class="login-cta__primary" :to="{ name: 'registro' }">
              Crear cuenta
            </router-link>
            <router-link class="login-cta__secondary" :to="{ name: 'login' }">
              Ya tengo cuenta
            </router-link>
          </div>
        </section>

        <section v-if="isAuthenticated && miEstacion" class="active-session">
          <span class="active-session__icon" aria-hidden="true">
            <ion-icon :icon="flashOutline" />
          </span>

          <div class="active-session__copy">
            <p class="active-session__eyebrow">Tu puesto</p>
            <h2>
              {{ miEstacion.tipo_estacion }} · Poste
              {{ miEstacion.tipo_poste }} · Toma {{ miEstacion.tipo_toma }}
            </h2>
            <p>
              Mientras estés enganchado solo puedes desengancharte de este
              puesto.
            </p>
          </div>

          <button
            class="active-session__action"
            type="button"
            :disabled="accionando"
            @click="onDesengancharse(miEstacion)"
          >
            <unplug-icon />
            <span>{{ accionando ? 'Desenganchando…' : 'Desengancharse' }}</span>
          </button>
        </section>

        <section
          v-if="loading"
          class="type-summary-grid"
          aria-label="Resumen por tipo de estación"
        >
          <div
            v-for="n in 3"
            :key="`summary-skeleton-${n}`"
            class="skeleton summary-skeleton"
          />
        </section>

        <section
          v-else-if="grupos.length"
          class="type-summary-grid"
          aria-label="Resumen por tipo de estación"
        >
          <type-summary-card
            v-for="grupo in grupos"
            :key="grupo.tipoId"
            :grupo="grupo"
            :show-status="isAuthenticated"
          />
        </section>

        <section class="groups" aria-labelledby="puestos-title">
          <header class="groups__head">
            <div>
              <h2 id="puestos-title">Puestos por tipo</h2>
              <p>{{ estaciones.length }} estaciones monitorizadas</p>
            </div>
          </header>

          <div v-if="loading" class="groups__skeletons">
            <div
              v-for="n in 2"
              :key="`group-skeleton-${n}`"
              class="skeleton group-skeleton"
            />
          </div>

          <div v-else-if="estaciones.length === 0 && !error" class="empty">
            <span class="empty__icon" aria-hidden="true">
              <ion-icon :icon="flashOutline" />
            </span>
            <h3>Aún no hay estaciones</h3>
            <p v-if="isAuthenticated">
              Cuando insertes estaciones y situaciones en Supabase aparecerán
              aquí automáticamente en tiempo real.
            </p>
            <p v-else>
              En cuanto haya estaciones disponibles aparecerán aquí. El estado
              en tiempo real se muestra al iniciar sesión.
            </p>
            <button class="empty__action" type="button" @click="refresh()">
              Volver a comprobar
            </button>
          </div>

          <div v-else class="group-list">
            <station-group
              v-for="grupo in grupos"
              :key="grupo.tipoId"
              :grupo="grupo"
              :show-status="isAuthenticated"
              :mi-estacion-id="miEstacion?.id ?? null"
              :usuario-en-cola="usuarioEnCola"
              :accionando="accionando"
              @engancharse="onEngancharse"
              @desengancharse="onDesengancharse"
              @entrar-en-cola="onEntrarEnCola"
              @salir-de-cola="onSalirDeCola"
            />
          </div>
        </section>

        <avisos-panel
          v-if="isAuthenticated"
          :avisos="avisos"
          :loading="loading"
        />

        <footer class="home-footer">
          <span>Electrolinera · v0.1.0</span>
          <span v-if="lastSync">Sync {{ formatHora(lastSync) }}</span>
        </footer>
      </main>

      <ion-toast
        :key="toast?.id ?? 0"
        :is-open="toast !== null"
        :message="toast?.message ?? ''"
        :duration="4500"
        position="top"
        color="success"
        @did-dismiss="dismissToast"
      />

      <ion-toast
        :key="actionToast?.id ?? 0"
        :is-open="actionToast !== null"
        :message="actionToast?.message ?? ''"
        :duration="4200"
        position="bottom"
        :color="actionToast?.color ?? 'success'"
        @did-dismiss="actionToast = null"
      />
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import {
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonMenuButton,
  IonPage,
  IonRefresher,
  IonRefresherContent,
  IonTitle,
  IonToast,
  IonToolbar,
} from '@ionic/vue'
import {
  flashOutline,
  lockClosedOutline,
  refreshOutline,
  warningOutline,
} from 'ionicons/icons'
import AvisosPanel from '@/components/AvisosPanel.vue'
import ConnectionBadge from '@/components/ConnectionBadge.vue'
import HeaderUser from '@/components/HeaderUser.vue'
import StationGroup from '@/components/StationGroup.vue'
import TypeSummaryCard from '@/components/TypeSummaryCard.vue'
import UnplugIcon from '@/components/icons/UnplugIcon.vue'
import { useAuth } from '@/composables/useAuth'
import { useHomeLive } from '@/composables/useHomeLive'
import {
  desengancharse,
  engancharse,
  entrarEnCola,
  salirDeCola,
} from '@/services/estacion.service'
import { formatHora } from '@/utils/format'
import type {
  HomeEstacion,
  HomeGrupoEstacion,
  LiveStatus,
} from '@/types/home'

const {
  estaciones,
  avisos,
  loading,
  refreshing,
  error,
  status,
  lastSync,
  toast,
  isPreview,
  refresh,
  dismissToast,
} = useHomeLive()

const { isAuthenticated } = useAuth()

const accionando = ref(false)
const actionToast = ref<{
  id: number
  message: string
  color: 'success' | 'danger'
} | null>(null)

const miEstacion = computed(
  () => estaciones.value.find((estacion) => estacion.es_mio) ?? null,
)

function getActionError(cause: unknown): string {
  if (cause instanceof Error) {
    return cause.message
  }

  if (typeof cause === 'object' && cause !== null && 'message' in cause) {
    const message = (cause as { message?: unknown }).message
    if (typeof message === 'string' && message.length > 0) {
      return message
    }
  }

  return 'No se pudo completar la acción.'
}

async function runAction(
  accion: () => Promise<unknown>,
  successMessage: string,
): Promise<void> {
  if (accionando.value) return

  if (isPreview) {
    actionToast.value = {
      id: Date.now(),
      message: 'Vista previa local: las acciones no se guardan.',
      color: 'success',
    }
    return
  }

  accionando.value = true

  try {
    await accion()
    actionToast.value = {
      id: Date.now(),
      message: successMessage,
      color: 'success',
    }
    await refresh()
  } catch (cause) {
    actionToast.value = {
      id: Date.now(),
      message: getActionError(cause),
      color: 'danger',
    }
  } finally {
    accionando.value = false
  }
}

function onEngancharse(estacion: HomeEstacion): void {
  void runAction(
    () => engancharse(estacion.id),
    `Te has enganchado al Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma}.`,
  )
}

function onDesengancharse(estacion: HomeEstacion): void {
  void runAction(
    () => desengancharse(estacion.id),
    'Te has desenganchado. El puesto queda libre.',
  )
}

function onEntrarEnCola(grupo: HomeGrupoEstacion): void {
  void runAction(
    () => entrarEnCola(grupo.tipoId),
    `Estás en la cola de ${grupo.tipo}.`,
  )
}

function onSalirDeCola(grupo: HomeGrupoEstacion): void {
  void runAction(
    () => salirDeCola(grupo.tipoId),
    `Has salido de la cola de ${grupo.tipo}.`,
  )
}

const subtitle = computed(() => {
  if (isPreview) {
    return isAuthenticated.value
      ? 'Vista previa local · datos de ejemplo'
      : 'Vista previa local · inicia sesión para ver el estado'
  }
  if (!isAuthenticated.value) {
    return 'Consulta qué estaciones hay. El estado en tiempo real se muestra al iniciar sesión.'
  }
  if (loading.value) return 'Sincronizando con Supabase…'
  if (lastSync.value) {
    return `Última sincronización a las ${formatHora(lastSync.value)}`
  }
  return 'Todavía sin datos de Supabase'
})

const connectionStatus = computed<LiveStatus>(() =>
  error.value ? 'error' : status.value,
)

const grupos = computed<HomeGrupoEstacion[]>(() => {
  const mapa = new Map<number, HomeGrupoEstacion>()

  for (const estacion of estaciones.value) {
    let grupo = mapa.get(estacion.tipo_estacion_id)

    if (!grupo) {
      grupo = {
        tipoId: estacion.tipo_estacion_id,
        tipo: estacion.tipo_estacion,
        total: 0,
        libres: [],
        ocupadas: [],
        sinEstado: [],
        enCola: estacion.en_cola_tipo,
        miEnCola: estacion.mi_en_cola,
        completo: false,
      }
      mapa.set(estacion.tipo_estacion_id, grupo)
    }

    grupo.total += 1
    grupo.enCola = Math.max(grupo.enCola, estacion.en_cola_tipo)
    grupo.miEnCola = grupo.miEnCola || estacion.mi_en_cola

    if (estacion.estado === 'Libre') {
      grupo.libres.push(estacion)
    } else if (estacion.estado === 'Ocupado') {
      grupo.ocupadas.push(estacion)
    } else {
      grupo.sinEstado.push(estacion)
    }
  }

  const porPoste = (a: HomeEstacion, b: HomeEstacion) =>
    Number(a.tipo_poste) - Number(b.tipo_poste) ||
    Number(a.tipo_toma) - Number(b.tipo_toma) ||
    a.id - b.id

  for (const grupo of mapa.values()) {
    grupo.libres.sort(porPoste)
    grupo.ocupadas.sort(porPoste)
    grupo.sinEstado.sort(porPoste)
    grupo.completo = grupo.ocupadas.length === grupo.total
  }

  return [...mapa.values()]
})

const usuarioEnCola = computed(() =>
  grupos.value.some((grupo) => grupo.miEnCola),
)
</script>

<style scoped>
.home-header {
  background: rgba(7, 12, 11, 0.72);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  border-bottom: 1px solid var(--app-border);
}

.home-header ion-toolbar {
  --background: transparent;
  --border-width: 0;
  --min-height: 60px;
  --color: var(--app-text);
}

.home-header ion-title {
  font-size: 0.96rem;
  font-weight: 650;
  letter-spacing: -0.01em;
}

.home-header ion-menu-button {
  --color: var(--app-text);
}

.home-header__actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.home-content {
  --padding-bottom: 0;
}

.home {
  width: min(100%, 1280px);
  margin: 0 auto;
  padding: 26px 28px 40px;
  display: flex;
  flex-direction: column;
  gap: 22px;
  overflow-x: clip;
}

.hero {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 20px;
  padding: 6px 2px 2px;
}

.hero__eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--app-green);
}

.hero__pulse {
  width: 7px;
  height: 7px;
  border-radius: 999px;
  background: var(--app-green);
  animation: app-pulse 2.2s ease-in-out infinite;
}

.hero h1 {
  margin: 8px 0 4px;
  font-size: clamp(1.75rem, 3.2vw, 2.35rem);
  line-height: 1.08;
  letter-spacing: -0.035em;
  font-weight: 700;
  color: var(--app-text);
}

.hero p {
  margin: 0;
  font-size: 0.84rem;
  color: var(--app-muted);
}

.refresh-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 15px;
  border-radius: 12px;
  border: 1px solid var(--app-border);
  background: var(--app-surface-soft);
  color: var(--app-text);
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition:
    border-color 160ms ease,
    color 160ms ease,
    background 160ms ease;
}

.refresh-btn ion-icon {
  font-size: 17px;
}

.refresh-btn:hover:not(:disabled) {
  border-color: var(--app-border-strong);
  color: var(--app-green);
  background: rgba(43, 229, 156, 0.06);
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: progress;
}

.alert {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  border-radius: 14px;
  border: 1px solid rgba(255, 82, 82, 0.3);
  background: rgba(255, 82, 82, 0.06);
}

.alert > ion-icon {
  flex: none;
  margin-top: 2px;
  font-size: 21px;
  color: var(--app-red);
}

.alert__body {
  min-width: 0;
}

.alert__body strong {
  display: block;
  font-size: 0.86rem;
  color: var(--app-text);
}

.alert__body p {
  margin: 3px 0 0;
  font-size: 0.78rem;
  line-height: 1.45;
  color: var(--app-muted);
  overflow-wrap: anywhere;
}

.alert__action {
  margin-left: auto;
  flex: none;
  padding: 8px 12px;
  border-radius: 10px;
  border: 1px solid rgba(255, 82, 82, 0.35);
  background: transparent;
  color: var(--app-red);
  font-size: 0.76rem;
  font-weight: 650;
  cursor: pointer;
}

.preview {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 11px 14px;
  border-radius: 12px;
  border: 1px dashed rgba(34, 211, 238, 0.32);
  background: rgba(34, 211, 238, 0.05);
  font-size: 0.78rem;
  color: var(--app-muted);
}

.preview ion-icon {
  flex: none;
  color: var(--app-cyan);
  font-size: 18px;
}

.preview code {
  padding: 1px 5px;
  border-radius: 5px;
  background: rgba(34, 211, 238, 0.12);
  color: var(--app-cyan);
  font-size: 0.74rem;
}

.login-cta {
  position: relative;
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 18px 20px;
  border-radius: var(--app-radius);
  border: 1px solid rgba(43, 229, 156, 0.28);
  background:
    radial-gradient(
      520px 180px at 0% 0%,
      rgba(43, 229, 156, 0.14),
      transparent 70%
    ),
    linear-gradient(135deg, rgba(19, 31, 27, 0.96), rgba(10, 16, 14, 0.9));
  box-shadow: var(--app-shadow);
  overflow: hidden;
}

.login-cta::before {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 2px;
  background: linear-gradient(
    90deg,
    transparent,
    rgba(43, 229, 156, 0.65),
    transparent
  );
}

.login-cta__icon {
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  flex: none;
  border-radius: 14px;
  color: var(--app-green);
  background: rgba(43, 229, 156, 0.12);
  border: 1px solid rgba(43, 229, 156, 0.3);
  box-shadow: var(--app-glow);
}

.login-cta__icon ion-icon {
  font-size: 22px;
}

.login-cta__copy {
  flex: 1;
  min-width: 0;
}

.login-cta__copy h2 {
  margin: 0;
  font-size: 1rem;
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.login-cta__copy p {
  margin: 4px 0 0;
  max-width: 620px;
  font-size: 0.8rem;
  line-height: 1.5;
  color: var(--app-muted);
}

.login-cta__actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: none;
}

.login-cta__primary,
.login-cta__secondary {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 9px 14px;
  border-radius: 10px;
  font-size: 0.78rem;
  font-weight: 650;
  text-decoration: none;
  white-space: nowrap;
  transition:
    filter 160ms ease,
    border-color 160ms ease,
    background 160ms ease;
}

.login-cta__primary {
  background: linear-gradient(135deg, #3cf0a8, #16b97b);
  color: #04120d;
  box-shadow: 0 12px 26px -14px rgba(43, 229, 156, 0.9);
}

.login-cta__primary:hover {
  filter: brightness(1.05);
}

.login-cta__secondary {
  border: 1px solid var(--app-border);
  background: transparent;
  color: var(--app-text);
}

.login-cta__secondary:hover {
  border-color: var(--app-border-strong);
  background: rgba(148, 190, 175, 0.06);
}

.active-session {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 18px;
  border-radius: var(--app-radius);
  border: 1px solid rgba(43, 229, 156, 0.35);
  background:
    radial-gradient(
      460px 160px at 0% 0%,
      rgba(43, 229, 156, 0.16),
      transparent 70%
    ),
    linear-gradient(135deg, rgba(19, 31, 27, 0.96), rgba(10, 16, 14, 0.9));
  box-shadow:
    var(--app-shadow),
    inset 0 0 0 1px rgba(43, 229, 156, 0.06);
}

.active-session__icon {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  flex: none;
  border-radius: 13px;
  color: #04120d;
  background: linear-gradient(145deg, #3cf0a8, #16b97b);
  box-shadow:
    0 12px 26px -14px rgba(43, 229, 156, 0.9),
    inset 0 1px 0 rgba(255, 255, 255, 0.4);
}

.active-session__icon ion-icon {
  font-size: 22px;
}

.active-session__copy {
  flex: 1;
  min-width: 0;
}

.active-session__eyebrow {
  margin: 0;
  font-size: 0.64rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--app-green);
}

.active-session__copy h2 {
  margin: 3px 0 0;
  font-size: 1rem;
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.active-session__copy p {
  margin: 3px 0 0;
  font-size: 0.78rem;
  color: var(--app-muted);
}

.active-session__action {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  flex: none;
  padding: 9px 13px;
  border-radius: 10px;
  border: 1px solid rgba(255, 176, 32, 0.38);
  background: rgba(255, 176, 32, 0.09);
  color: var(--app-amber);
  font-size: 0.78rem;
  font-weight: 650;
  cursor: pointer;
}

.active-session__action:hover:not(:disabled) {
  border-color: rgba(255, 176, 32, 0.6);
  background: rgba(255, 176, 32, 0.16);
}

.active-session__action:disabled {
  opacity: 0.6;
  cursor: progress;
}

.active-session__action svg {
  width: 17px;
  height: 17px;
}

.type-summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.summary-skeleton {
  height: 146px;
}

.groups {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.groups__head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
}

.groups__head h2 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.groups__head p {
  margin: 3px 0 0;
  font-size: 0.76rem;
  color: var(--app-muted);
}

.groups__skeletons {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.group-skeleton {
  height: 210px;
}

.group-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 7px;
  padding: 38px 16px 42px;
  border-radius: var(--app-radius);
  border: 1px solid var(--app-border);
  background: linear-gradient(
    180deg,
    rgba(15, 23, 21, 0.8),
    rgba(9, 15, 13, 0.72)
  );
  box-shadow: var(--app-shadow);
}

.empty__icon {
  display: grid;
  place-items: center;
  width: 56px;
  height: 56px;
  margin-bottom: 4px;
  border-radius: 18px;
  color: var(--app-green);
  background: rgba(43, 229, 156, 0.09);
  border: 1px solid rgba(43, 229, 156, 0.24);
  box-shadow: var(--app-glow);
}

.empty__icon ion-icon {
  font-size: 27px;
}

.empty h3 {
  margin: 0;
  font-size: 1rem;
  font-weight: 650;
  color: var(--app-text);
}

.empty p {
  margin: 0;
  max-width: 430px;
  font-size: 0.83rem;
  line-height: 1.5;
  color: var(--app-muted);
}

.empty__action {
  margin-top: 10px;
  padding: 9px 14px;
  border-radius: 10px;
  border: 1px solid var(--app-border-strong);
  background: rgba(43, 229, 156, 0.08);
  color: var(--app-green);
  font-size: 0.78rem;
  font-weight: 650;
  cursor: pointer;
}

.home-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 2px 2px 0;
  font-size: 0.7rem;
  color: var(--app-dim);
}

@media (max-width: 820px) {
  .home {
    padding: 20px 16px 34px;
    gap: 18px;
  }

  .hero {
    flex-direction: column;
    align-items: stretch;
  }

  .hero .refresh-btn {
    justify-content: center;
  }

  .alert {
    flex-wrap: wrap;
  }

  .alert__action {
    margin-left: 33px;
  }

  .login-cta {
    flex-direction: column;
    align-items: flex-start;
    padding: 16px;
  }

  .login-cta__actions {
    width: 100%;
  }

  .login-cta__primary,
  .login-cta__secondary {
    flex: 1;
  }

  .active-session {
    flex-wrap: wrap;
    padding: 14px;
  }

  .active-session__action {
    width: 100%;
    justify-content: center;
  }

  .empty {
    padding: 30px 14px 34px;
  }
}

@media (max-width: 760px) {
  .type-summary-grid {
    grid-template-columns: 1fr;
  }
}

@media (min-width: 992px) {
  ion-menu-button {
    display: none;
  }
}
</style>
