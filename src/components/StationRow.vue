<template>
  <article
    class="station-row"
    :class="[`station-row--${tone}`, { 'station-row--mine': esMio }]"
    :aria-label="ariaLabel"
  >
    <span class="station-row__marker" aria-hidden="true" />

    <div class="station-row__body">
      <p class="station-row__title">
        Poste {{ estacion.tipo_poste }}
        <span aria-hidden="true">·</span>
        Toma {{ estacion.tipo_toma }}
        <span v-if="esMio" class="station-row__mine">Tu puesto</span>
      </p>

      <p v-if="showStatus" class="station-row__meta">
        <span class="meta-item">
          <ion-icon :icon="timeOutline" aria-hidden="true" />
          {{ desde }}
        </span>

        <span v-if="estacion.cargando > 0" class="meta-item meta-item--cyan">
          <ion-icon :icon="batteryChargingOutline" aria-hidden="true" />
          {{ estacion.cargando }} cargando
        </span>
      </p>
    </div>

    <div v-if="showStatus && (esMio || puedeEnganchar)" class="station-row__actions">
      <button
        v-if="esMio"
        class="row-action row-action--unplug"
        type="button"
        data-tooltip="Desengancharse"
        aria-label="Desengancharse"
        :disabled="accionando"
        @click="emit('desengancharse')"
      >
        <unplug-icon />
      </button>

      <button
        v-else
        class="row-action row-action--plug"
        type="button"
        data-tooltip="Engancharse"
        aria-label="Engancharse"
        :disabled="accionando"
        @click="emit('engancharse')"
      >
        <plug-zap-icon />
      </button>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { IonIcon } from '@ionic/vue'
import { batteryChargingOutline, timeOutline } from 'ionicons/icons'
import PlugZapIcon from '@/components/icons/PlugZapIcon.vue'
import UnplugIcon from '@/components/icons/UnplugIcon.vue'
import { formatDesde } from '@/utils/format'
import type { HomeEstacion } from '@/types/home'

const props = withDefaults(
  defineProps<{
    estacion: HomeEstacion
    showStatus?: boolean
    esMio?: boolean
    puedeEnganchar?: boolean
    accionando?: boolean
  }>(),
  {
    showStatus: true,
    esMio: false,
    puedeEnganchar: false,
    accionando: false,
  },
)

const emit = defineEmits<{
  engancharse: []
  desengancharse: []
}>()

const tone = computed(() => {
  if (!props.showStatus) return 'public'
  if (props.esMio) return 'mine'
  if (props.estacion.estado === 'Libre') return 'libre'
  if (props.estacion.estado === 'Ocupado') return 'ocupado'
  return 'sin-estado'
})

const estadoLabel = computed(() => props.estacion.estado ?? 'sin estado')

const desde = computed(() =>
  props.estacion.estado_desde
    ? formatDesde(props.estacion.estado_desde)
    : 'Sin uso hoy',
)

const ariaLabel = computed(() => {
  if (!props.showStatus) {
    return `Poste ${props.estacion.tipo_poste}, toma ${props.estacion.tipo_toma}`
  }

  const estado = props.esMio ? 'tu puesto' : estadoLabel.value
  return `Poste ${props.estacion.tipo_poste}, toma ${props.estacion.tipo_toma}: ${estado}`
})
</script>

<style scoped>
.station-row {
  display: flex;
  gap: 10px;
  align-items: center;
  min-width: 0;
  padding: 9px 10px;
  border-radius: 10px;
  border: 1px solid var(--app-border);
  background: rgba(7, 12, 11, 0.35);
  transition:
    border-color 160ms ease,
    background 160ms ease;
}

.station-row:hover {
  border-color: var(--row-accent, var(--app-border));
  background: rgba(19, 31, 27, 0.5);
}

.station-row--libre {
  --row-accent: rgba(43, 229, 156, 0.5);
}

.station-row--ocupado {
  --row-accent: rgba(255, 176, 32, 0.5);
}

.station-row--sin-estado,
.station-row--public {
  --row-accent: rgba(138, 163, 155, 0.28);
}

.station-row--mine {
  --row-accent: rgba(43, 229, 156, 0.75);
  border-color: rgba(43, 229, 156, 0.38);
  background: rgba(43, 229, 156, 0.06);
}

.station-row__marker {
  width: 3px;
  align-self: stretch;
  flex: none;
  border-radius: 999px;
  background: var(--row-accent, var(--app-dim));
  opacity: 0.9;
}

.station-row__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  flex: 1;
}

.station-row__title {
  margin: 0;
  font-size: 0.83rem;
  font-weight: 600;
  color: var(--app-text);
}

.station-row__title > span[aria-hidden='true'] {
  margin: 0 2px;
  color: var(--app-dim);
}

.station-row__mine {
  display: inline-block;
  margin-left: 7px;
  padding: 1px 7px;
  border-radius: 999px;
  border: 1px solid rgba(43, 229, 156, 0.28);
  background: rgba(43, 229, 156, 0.1);
  color: var(--app-green);
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  vertical-align: 1px;
}

.station-row__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 2px 9px;
  margin: 0;
  font-size: 0.68rem;
  color: var(--app-muted);
}

.meta-item {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  white-space: nowrap;
}

.meta-item ion-icon {
  font-size: 12px;
  color: var(--app-dim);
}

.meta-item--cyan,
.meta-item--cyan ion-icon {
  color: var(--app-cyan);
}

.station-row__actions {
  display: flex;
  align-items: center;
  flex: none;
}

.row-action {
  position: relative;
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border-radius: 10px;
  border: 1px solid transparent;
  background: transparent;
  cursor: pointer;
  transition:
    background 160ms ease,
    border-color 160ms ease,
    color 160ms ease;
}

.row-action:disabled {
  opacity: 0.55;
  cursor: progress;
}

.row-action--plug {
  color: var(--app-green);
  border-color: rgba(43, 229, 156, 0.28);
  background: rgba(43, 229, 156, 0.08);
}

.row-action--plug:hover:not(:disabled) {
  border-color: rgba(43, 229, 156, 0.55);
  background: rgba(43, 229, 156, 0.16);
}

.row-action--unplug {
  color: var(--app-amber);
  border-color: rgba(255, 176, 32, 0.28);
  background: rgba(255, 176, 32, 0.08);
}

.row-action--unplug:hover:not(:disabled) {
  border-color: rgba(255, 176, 32, 0.55);
  background: rgba(255, 176, 32, 0.16);
}

.row-action::after {
  content: attr(data-tooltip);
  position: absolute;
  right: 0;
  bottom: calc(100% + 7px);
  z-index: 20;
  padding: 5px 8px;
  border-radius: 6px;
  border: 1px solid var(--app-border);
  background: #0b1311;
  color: var(--app-text);
  font-size: 0.66rem;
  font-weight: 600;
  line-height: 1.2;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  transform: translateY(3px);
  transition:
    opacity 150ms ease,
    transform 150ms ease;
  box-shadow: 0 10px 24px -12px rgba(0, 0, 0, 0.9);
}

.row-action:hover::after,
.row-action:focus-visible::after {
  opacity: 1;
  transform: translateY(0);
}
</style>
