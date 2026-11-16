<template>
  <article class="type-summary">
    <header class="type-summary__head">
      <component
        :is="showStatus ? 'a' : 'div'"
        class="type-summary__title"
        :href="showStatus ? `#grupo-${grupo.tipoId}` : undefined"
        :aria-label="showStatus ? `Ver el detalle de ${grupo.tipo}` : undefined"
        @click.prevent="onVerDetalle"
      >
        <h3>{{ grupo.tipo }}</h3>
        <p>
          {{ pluralizar(grupo.total, 'puesto', 'puestos') }}
          <span v-if="showStatus" class="type-summary__open">
            Ver detalle
            <ion-icon :icon="chevronDownOutline" aria-hidden="true" />
          </span>
        </p>
      </component>
      <span class="type-summary__icon" aria-hidden="true">
        <ion-icon :icon="showStatus ? flashOutline : lockClosedOutline" />
      </span>
    </header>

    <div v-if="showStatus" class="type-summary__metrics">
      <div class="metric metric--green">
        <strong>{{ grupo.libres.length }}</strong>
        <span>Libres</span>
      </div>
      <div class="metric metric--amber">
        <strong>{{ grupo.ocupadas.length }}</strong>
        <span>Ocupados</span>
      </div>
      <div class="metric metric--cyan">
        <strong>{{ grupo.enCola }}</strong>
        <span>En cola</span>
      </div>
    </div>

    <div v-else class="type-summary__locked">
      <ion-icon :icon="lockClosedOutline" aria-hidden="true" />
      <span>Inicia sesión para ver el estado</span>
    </div>

    <div v-if="showStatus" class="type-summary__bar" aria-hidden="true">
      <span
        v-if="grupo.libres.length"
        class="bar bar--green"
        :style="{ flexGrow: grupo.libres.length }"
      />
      <span
        v-if="grupo.ocupadas.length"
        class="bar bar--amber"
        :style="{ flexGrow: grupo.ocupadas.length }"
      />
    </div>

    <button
      v-if="puedeEntrarEnCola"
      class="type-summary__queue"
      type="button"
      :disabled="accionando"
      @click="emit('entrarEnCola', grupo)"
    >
      <ion-icon :icon="timeOutline" aria-hidden="true" />
      <span>{{ accionando ? 'Entrando…' : 'Ponerse en la cola' }}</span>
    </button>

    <button
      v-else-if="puedeSalirDeCola"
      class="type-summary__queue type-summary__queue--leave"
      type="button"
      :disabled="accionando"
      @click="emit('salirDeCola', grupo)"
    >
      <ion-icon :icon="timeOutline" aria-hidden="true" />
      <span>{{ accionando ? 'Saliendo…' : 'Salir de la cola' }}</span>
    </button>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { IonIcon } from '@ionic/vue'
import {
  chevronDownOutline,
  flashOutline,
  lockClosedOutline,
  timeOutline,
} from 'ionicons/icons'
import { pluralizar } from '@/utils/format'
import type { HomeGrupoEstacion } from '@/types/home'

const props = withDefaults(
  defineProps<{
    grupo: HomeGrupoEstacion
    showStatus?: boolean
    accionando?: boolean
  }>(),
  { showStatus: true, accionando: false },
)

const emit = defineEmits<{
  verDetalle: [grupo: HomeGrupoEstacion]
  entrarEnCola: [grupo: HomeGrupoEstacion]
  salirDeCola: [grupo: HomeGrupoEstacion]
}>()

/*
 * Se puede entrar en la cola cuando el tipo está completo o cuando ya hay una
 * cola activa, aunque se haya liberado algún puesto. Si ya se está apuntado,
 * el mismo botón permite salir y volver a entrar más tarde el mismo día.
 */
const puedeEntrarEnCola = computed(
  () =>
    props.showStatus &&
    (props.grupo.completo || props.grupo.enCola > 0) &&
    !props.grupo.miEnCola &&
    !props.grupo.ocupadas.some((estacion) => estacion.es_mio),
)

const puedeSalirDeCola = computed(
  () => props.showStatus && props.grupo.miEnCola,
)

/* Sin sesión no hay bloque de detalle al que navegar. */
function onVerDetalle(): void {
  if (props.showStatus) {
    emit('verDetalle', props.grupo)
  }
}
</script>

<style scoped>
.type-summary {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-width: 0;
  padding: 18px;
  border-radius: var(--app-radius);
  border: 1px solid var(--app-border);
  background: linear-gradient(
    160deg,
    rgba(19, 31, 27, 0.95),
    rgba(10, 16, 14, 0.86)
  );
  box-shadow: var(--app-shadow);
  overflow: hidden;
}

.type-summary::before {
  content: '';
  position: absolute;
  inset: 0 0 auto 0;
  height: 2px;
  background: linear-gradient(
    90deg,
    transparent,
    rgba(43, 229, 156, 0.55),
    transparent
  );
}

.type-summary__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 10px;
}

.type-summary__title {
  display: block;
  min-width: 0;
  border-radius: 8px;
  color: inherit;
  text-decoration: none;
}

.type-summary__title:focus-visible {
  outline: 2px solid var(--app-green);
  outline-offset: 3px;
}

a.type-summary__title:hover h3 {
  color: var(--app-green);
}

.type-summary__open {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  margin-left: 5px;
  color: var(--app-green);
  font-size: 0.7rem;
  font-weight: 650;
  white-space: nowrap;
}

.type-summary__open ion-icon {
  font-size: 13px;
}

.type-summary__title h3 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.type-summary__title p {
  margin: 2px 0 0;
  font-size: 0.74rem;
  color: var(--app-muted);
}

.type-summary__icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  flex: none;
  border-radius: 11px;
  color: var(--app-green);
  background: rgba(43, 229, 156, 0.1);
  box-shadow: inset 0 0 0 1px rgba(43, 229, 156, 0.22);
}

.type-summary__icon ion-icon {
  font-size: 19px;
}

.type-summary__metrics {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
}

.type-summary__locked {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border-radius: 10px;
  border: 1px dashed var(--app-border);
  background: rgba(148, 190, 175, 0.04);
  color: var(--app-muted);
  font-size: 0.74rem;
  font-weight: 550;
  line-height: 1.4;
}

.type-summary__locked ion-icon {
  flex: none;
  font-size: 16px;
  color: var(--app-dim);
}

.metric {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.metric strong {
  font-size: 1.5rem;
  line-height: 1;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.metric span {
  font-size: 0.64rem;
  font-weight: 650;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--app-muted);
  white-space: nowrap;
}

.metric--green strong {
  color: var(--app-green);
}

.metric--amber strong {
  color: var(--app-amber);
}

.metric--cyan strong {
  color: var(--app-cyan);
}

.metric--muted strong {
  color: var(--app-muted);
}

.type-summary__bar {
  display: flex;
  gap: 3px;
  height: 6px;
  border-radius: 999px;
  background: rgba(148, 190, 175, 0.12);
  overflow: hidden;
}

.bar {
  height: 100%;
  min-width: 4px;
  flex-basis: 0;
  border-radius: 999px;
}

.bar--green {
  background: var(--app-green);
}

.bar--amber {
  background: var(--app-amber);
}

.bar--muted {
  background: var(--app-dim);
}

.type-summary__queue {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  width: 100%;
  margin-top: -2px;
  padding: 9px 12px;
  border-radius: 10px;
  border: 1px solid rgba(43, 229, 156, 0.3);
  background: rgba(43, 229, 156, 0.08);
  color: var(--app-green);
  font-size: 0.76rem;
  font-weight: 650;
  white-space: nowrap;
  cursor: pointer;
  transition:
    border-color 160ms ease,
    background 160ms ease;
}

.type-summary__queue ion-icon {
  font-size: 16px;
}

.type-summary__queue:hover:not(:disabled) {
  border-color: rgba(43, 229, 156, 0.5);
  background: rgba(43, 229, 156, 0.14);
}

.type-summary__queue--leave {
  color: var(--app-amber);
  border-color: rgba(255, 176, 32, 0.3);
  background: rgba(255, 176, 32, 0.09);
}

.type-summary__queue--leave:hover:not(:disabled) {
  border-color: rgba(255, 176, 32, 0.5);
  background: rgba(255, 176, 32, 0.16);
}

.type-summary__queue:disabled {
  opacity: 0.55;
  cursor: progress;
}
</style>
