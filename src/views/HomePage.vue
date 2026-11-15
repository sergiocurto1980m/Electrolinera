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
            v-if="!isNativeApp"
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

        <section
          v-if="isAuthenticated && !error"
          class="user-status"
          aria-live="polite"
        >
          <div
            v-if="loading"
            class="user-status__item user-status__item--comprobando"
          >
            <span class="user-status__icon" aria-hidden="true">
              <ion-icon :icon="estadoIcons.comprobando" />
            </span>
            <div class="user-status__body">
              <p class="user-status__label">Comprobando estado</p>
              <p class="user-status__detail">
                Consultando tu puesto y tus listas de espera…
              </p>
            </div>
          </div>

          <template v-else>
            <div
              v-if="miEstacion"
              class="user-status__item user-status__item--cargando"
            >
              <span class="user-status__icon" aria-hidden="true">
                <ion-icon :icon="estadoIcons.cargando" />
              </span>

              <div class="user-status__body">
                <p class="user-status__label">Estás cargando</p>
                <p class="user-status__detail">
                  Estación {{ miEstacion.tipo_estacion }} · Poste
                  {{ miEstacion.tipo_poste }} · Toma {{ miEstacion.tipo_toma }}
                </p>
                <p class="user-status__hint">
                  Mientras estés enganchado solo puedes desengancharte de este
                  puesto.
                </p>
              </div>

              <button
                class="user-status__action"
                type="button"
                :disabled="accionando"
                @click="desengancharDesdeIndicador"
              >
                <unplug-icon />
                <span>{{
                  accionando ? 'Desenganchando…' : 'Desengancharse'
                }}</span>
              </button>
            </div>

            <div
              v-for="cola in misColas"
              :key="`cola-${cola.tipoId}`"
              class="user-status__item user-status__item--cola"
            >
              <span class="user-status__icon" aria-hidden="true">
                <ion-icon :icon="estadoIcons.cola" />
              </span>

              <div class="user-status__body">
                <p class="user-status__label">En lista de espera</p>
                <p class="user-status__detail">{{ cola.detalle }}</p>
                <p class="user-status__hint">
                  Te avisaremos cuando se libere un puesto de este tipo.
                </p>
              </div>

              <button
                class="user-status__action"
                type="button"
                :disabled="accionando"
                @click="salirDeColaDesdeIndicador(cola.grupo)"
              >
                <span>{{ accionando ? 'Saliendo…' : 'Salir de la cola' }}</span>
              </button>
            </div>

            <div
              v-for="toma in tomasMarcadas"
              :key="`marcada-${toma.id}`"
              class="user-status__item user-status__item--marcada"
            >
              <span class="user-status__icon" aria-hidden="true">
                <ion-icon :icon="estadoIcons.marcada" />
              </span>

              <div class="user-status__body">
                <p class="user-status__label">Has marcado una toma</p>
                <p class="user-status__detail">
                  Estación {{ toma.tipo_estacion }} · Poste
                  {{ toma.tipo_poste }} · Toma {{ toma.tipo_toma }}
                </p>
                <p class="user-status__hint">
                  Ocupada por otra persona sin app. Puedes marcarla libre
                  cuando se desocupe.
                </p>
              </div>

              <button
                class="user-status__action"
                type="button"
                :disabled="accionando"
                @click="onDesengancharse(toma)"
              >
                <unplug-icon />
                <span>{{ accionando ? 'Liberando…' : 'Marcar libre' }}</span>
              </button>
            </div>

            <div
              v-if="
                !miEstacion &&
                misColas.length === 0 &&
                tomasMarcadas.length === 0
              "
              class="user-status__item user-status__item--libre"
            >
              <span class="user-status__icon" aria-hidden="true">
                <ion-icon :icon="estadoIcons.libre" />
              </span>

              <div class="user-status__body">
                <p class="user-status__label">Sin actividad</p>
                <p class="user-status__detail">
                  No estás cargando ni en ninguna lista de espera.
                </p>
              </div>
            </div>
          </template>
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
            :accionando="accionando"
            @ver-detalle="irAlDetalle"
            @entrar-en-cola="onEntrarEnCola"
            @salir-de-cola="onSalirDeCola"
          />
        </section>

        <section
          v-if="isAuthenticated"
          class="groups"
          aria-labelledby="puestos-title"
        >
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
              :id="`grupo-${grupo.tipoId}`"
              :key="grupo.tipoId"
              :grupo="grupo"
              :show-status="isAuthenticated"
              :mi-estacion-id="miEstacion?.id ?? null"
              :accionando="accionando"
              @engancharse="onEngancharse"
              @desengancharse="onDesengancharse"
              @marcar-por-otro="onMarcarPorOtro"
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
          <router-link
            v-if="!isNativeApp"
            class="home-footer__download"
            :to="{ name: 'descargar' }"
          >
            Descargar app Android
          </router-link>
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

      <ion-alert
        :is-open="pendingConfirm !== null"
        :header="pendingConfirm?.header ?? ''"
        :message="pendingConfirm?.message ?? ''"
        :buttons="confirmButtons"
        @did-dismiss="pendingConfirm = null"
      />
    </ion-content>
  </ion-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Capacitor } from '@capacitor/core'
import {
  IonAlert,
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
import type { AlertButton } from '@ionic/vue'
import {
  checkmarkCircleOutline,
  flashOutline,
  lockClosedOutline,
  personOutline,
  refreshOutline,
  timeOutline,
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
  marcarOcupadaPorOtro,
  salirDeCola,
} from '@/services/estacion.service'
import { formatHora } from '@/utils/format'
import type {
  HomeColaItem,
  HomeEstacion,
  HomeGrupoEstacion,
  LiveStatus,
} from '@/types/home'

const {
  estaciones,
  avisos,
  cola,
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

/*
 * En la app nativa el refresco manual se hace con el gesto de pull-to-refresh;
 * el botón solo tiene sentido en la web.
 */
const isNativeApp = Capacitor.isNativePlatform()

const accionando = ref(false)
const actionToast = ref<{
  id: number
  message: string
  color: 'success' | 'danger'
} | null>(null)

interface ConfirmAction {
  header: string
  message: string
  confirmText: string
  destructive?: boolean
  run: () => void
}

const pendingConfirm = ref<ConfirmAction | null>(null)

const confirmButtons = computed<AlertButton[]>(() => {
  const action = pendingConfirm.value

  return [
    { text: 'Cancelar', role: 'cancel' },
    {
      text: action?.confirmText ?? 'Confirmar',
      ...(action?.destructive ? { role: 'destructive' } : {}),
      handler: () => {
        pendingConfirm.value = null
        action?.run()
      },
    },
  ]
})

const miEstacion = computed(
  () => estaciones.value.find((estacion) => estacion.es_mio) ?? null,
)

/* Tomas ocupadas por personas sin app que este usuario ha registrado. */
const tomasMarcadas = computed(() =>
  estaciones.value.filter((estacion) => estacion.marcada_por_mi),
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
  /*
   * Al engancharse solo se cierra la cola de ese tipo. Las colas de otros
   * tipos se mantienen.
   */
  const colaDeEsteTipo = misColas.value.find(
    (cola) => cola.tipoId === estacion.tipo_estacion_id,
  )
  const avisoCola = colaDeEsteTipo
    ? ` Saldrás de la cola de ${colaDeEsteTipo.tipo}.`
    : ''

  pendingConfirm.value = {
    header: 'Engancharse al puesto',
    message: `Estación ${estacion.tipo_estacion}: vas a engancharte al Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma}.${avisoCola} ¿Quieres continuar?`,
    confirmText: 'Engancharme',
    run: () => {
      void runAction(
        () => engancharse(estacion.id),
        `Te has enganchado al Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma}.`,
      )
    },
  }
}

function onMarcarPorOtro(estacion: HomeEstacion): void {
  pendingConfirm.value = {
    header: 'Marcar toma ocupada',
    message: `Estación ${estacion.tipo_estacion}: vas a marcar el Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma} como ocupado por otra persona sin app. Tú no quedarás enganchado. ¿Quieres continuar?`,
    confirmText: 'Marcar ocupada',
    run: () => {
      void runAction(
        () => marcarOcupadaPorOtro(estacion.id),
        `Has marcado el Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma} como ocupado por otra persona.`,
      )
    },
  }
}

function onDesengancharse(estacion: HomeEstacion): void {
  const esOcupacionAjena = estacion.ocupada_por_otro && !estacion.es_mio

  if (esOcupacionAjena) {
    pendingConfirm.value = {
      header: 'Marcar toma libre',
      message: `Estación ${estacion.tipo_estacion}: vas a marcar el Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma} como libre. Estaba ocupado por otra persona sin app. ¿Quieres continuar?`,
      confirmText: 'Marcar libre',
      destructive: true,
      run: () => {
        void runAction(
          () => desengancharse(estacion.id),
          `Has marcado el Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma} como libre.`,
        )
      },
    }
    return
  }

  pendingConfirm.value = {
    header: 'Desengancharse del puesto',
    message: `Estación ${estacion.tipo_estacion}: vas a desengancharte del Poste ${estacion.tipo_poste} · Toma ${estacion.tipo_toma}. El puesto quedará libre y perderás tu sitio. ¿Quieres continuar?`,
    confirmText: 'Desengancharme',
    destructive: true,
    run: () => {
      void runAction(
        () => desengancharse(estacion.id),
        'Te has desenganchado. El puesto queda libre.',
      )
    },
  }
}

function onEntrarEnCola(grupo: HomeGrupoEstacion): void {
  pendingConfirm.value = {
    header: 'Ponerse en la cola',
    message: `Estación ${grupo.tipo}: no quedan puestos libres. Entrarás en la cola de espera para el próximo puesto que se libere. ¿Quieres continuar?`,
    confirmText: 'Ponerme en cola',
    run: () => {
      void runAction(
        () => entrarEnCola(grupo.tipoId),
        `Estás en la cola de ${grupo.tipo}.`,
      )
    },
  }
}

function onSalirDeCola(grupo: HomeGrupoEstacion): void {
  void runAction(
    () => salirDeCola(grupo.tipoId),
    `Has salido de la cola de ${grupo.tipo}.`,
  )
}

/* Desde el resumen de un tipo se abre su bloque de detalle y se salta a él. */
function irAlDetalle(grupo: HomeGrupoEstacion): void {
  const destino = document.getElementById(
    `grupo-${grupo.tipoId}`,
  ) as HTMLDetailsElement | null

  if (!destino) return

  destino.open = true

  requestAnimationFrame(() => {
    destino.scrollIntoView({ behavior: 'smooth', block: 'start' })
  })
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
  const colaPorTipo = new Map<number, HomeColaItem[]>()

  for (const item of cola.value) {
    const items = colaPorTipo.get(item.tipo_estacion_id)
    if (items) {
      items.push(item)
    } else {
      colaPorTipo.set(item.tipo_estacion_id, [item])
    }
  }

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
        cola: [],
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

    const colaTipo = colaPorTipo.get(grupo.tipoId)
    if (colaTipo) {
      grupo.cola = colaTipo.sort((a, b) => a.posicion - b.posicion)
      grupo.enCola = grupo.cola.length
      grupo.miEnCola =
        grupo.miEnCola || grupo.cola.some((item) => item.es_mio)
    }
  }

  return [...mapa.values()]
})

/*
 * El usuario puede estar cargando y, a la vez, en varias colas (una por tipo).
 * El indicador pinta una fila por cada situación.
 */
const misColas = computed(() =>
  grupos.value
    .filter((grupo) => grupo.miEnCola)
    .map((grupo) => {
      const posicion =
        grupo.cola.find((item) => item.es_mio)?.posicion ?? null

      return {
        tipoId: grupo.tipoId,
        tipo: grupo.tipo,
        posicion,
        grupo,
        detalle: `Estación ${grupo.tipo}${posicion ? ` · Posición ${posicion}` : ''}`,
      }
    }),
)

const estadoIcons = {
  cargando: flashOutline,
  cola: timeOutline,
  libre: checkmarkCircleOutline,
  comprobando: timeOutline,
  marcada: personOutline,
}

function desengancharDesdeIndicador(): void {
  const estacion = miEstacion.value
  if (estacion) {
    onDesengancharse(estacion)
  }
}

function salirDeColaDesdeIndicador(grupo: HomeGrupoEstacion): void {
  onSalirDeCola(grupo)
}
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

.user-status {
  display: flex;
  flex-direction: column;
  border-radius: var(--app-radius);
  border: 1px solid var(--app-border);
  background:
    radial-gradient(
      460px 160px at 0% 0%,
      rgba(148, 190, 175, 0.06),
      transparent 70%
    ),
    linear-gradient(135deg, rgba(19, 31, 27, 0.96), rgba(10, 16, 14, 0.9));
  box-shadow: var(--app-shadow);
  overflow: hidden;
}

.user-status__item {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 12px 16px;
}

.user-status__item + .user-status__item {
  border-top: 1px solid var(--app-border);
}

.user-status__item--cargando {
  background: linear-gradient(
    90deg,
    rgba(43, 229, 156, 0.09),
    transparent 65%
  );
}

.user-status__item--cola {
  background: linear-gradient(
    90deg,
    rgba(255, 176, 32, 0.08),
    transparent 65%
  );
}

.user-status__item--comprobando {
  background: linear-gradient(
    90deg,
    rgba(34, 211, 238, 0.07),
    transparent 65%
  );
}

.user-status__item--marcada {
  background: linear-gradient(
    90deg,
    rgba(34, 211, 238, 0.07),
    transparent 65%
  );
}

.user-status__icon {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  flex: none;
  border-radius: 12px;
  border: 1px solid var(--app-border);
  background: rgba(148, 190, 175, 0.08);
  color: var(--app-muted);
}

.user-status__icon ion-icon {
  font-size: 21px;
}

.user-status__body {
  flex: 1;
  min-width: 0;
}

.user-status__label {
  margin: 0;
  font-size: 0.64rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--app-muted);
}

.user-status__detail {
  margin: 3px 0 0;
  font-size: 0.92rem;
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.user-status__hint {
  margin: 3px 0 0;
  font-size: 0.76rem;
  color: var(--app-muted);
}

.user-status__item--cargando .user-status__icon {
  color: #04120d;
  border-color: transparent;
  background: linear-gradient(145deg, #3cf0a8, #16b97b);
  box-shadow:
    0 12px 26px -14px rgba(43, 229, 156, 0.9),
    inset 0 1px 0 rgba(255, 255, 255, 0.4);
}

.user-status__item--cargando .user-status__label {
  color: var(--app-green);
}

.user-status__item--cola .user-status__icon {
  color: var(--app-amber);
  border-color: rgba(255, 176, 32, 0.32);
  background: rgba(255, 176, 32, 0.1);
}

.user-status__item--cola .user-status__label {
  color: var(--app-amber);
}

.user-status__item--comprobando .user-status__icon {
  color: var(--app-cyan);
  border-color: rgba(34, 211, 238, 0.28);
  background: rgba(34, 211, 238, 0.08);
}

.user-status__item--comprobando .user-status__label {
  color: var(--app-cyan);
}

.user-status__item--marcada .user-status__icon {
  color: var(--app-cyan);
  border-color: rgba(34, 211, 238, 0.28);
  background: rgba(34, 211, 238, 0.08);
}

.user-status__item--marcada .user-status__label {
  color: var(--app-cyan);
}

.user-status__action {
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

.user-status__action:hover:not(:disabled) {
  border-color: rgba(255, 176, 32, 0.6);
  background: rgba(255, 176, 32, 0.16);
}

.user-status__action:disabled {
  opacity: 0.6;
  cursor: progress;
}

.user-status__action svg {
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
  flex-wrap: wrap;
  gap: 8px 12px;
  padding: 2px 2px 0;
  font-size: 0.7rem;
  color: var(--app-dim);
}

.home-footer__download {
  color: var(--app-green);
  font-weight: 600;
  text-decoration: none;
}

.home-footer__download:hover {
  text-decoration: underline;
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

  .user-status__item {
    flex-wrap: wrap;
    padding: 12px 14px;
  }

  .user-status__action {
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
