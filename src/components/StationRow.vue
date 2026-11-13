<template>
  <article
    class="station-row"
    :class="`station-row--${tone}`"
    :aria-label="ariaLabel"
  >
    <span class="station-row__marker" aria-hidden="true" />
    <div class="station-row__body">
      <p class="station-row__title">
        Poste {{ estacion.tipo_poste }}
        <span aria-hidden="true">·</span>
        Toma {{ estacion.tipo_toma }}
      </p>

      <p v-if="showStatus" class="station-row__meta">
        <span class="meta-item">
          <ion-icon :icon="timeOutline" aria-hidden="true" />
          {{ desde }}
        </span>

        <span
          v-if="estacion.cargando > 0"
          class="meta-item meta-item--cyan"
        >
          <ion-icon :icon="batteryChargingOutline" aria-hidden="true" />
          {{ estacion.cargando }} cargando
        </span>

        <span v-if="estacion.en_cola > 0" class="meta-item meta-item--amber">
          <ion-icon :icon="peopleOutline" aria-hidden="true" />
          {{ estacion.en_cola }} en cola
        </span>

        <span v-else class="meta-item">
          <ion-icon :icon="checkmarkCircleOutline" aria-hidden="true" />
          Sin cola
        </span>
      </p>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { IonIcon } from '@ionic/vue'
import {
  batteryChargingOutline,
  checkmarkCircleOutline,
  peopleOutline,
  timeOutline,
} from 'ionicons/icons'
import { formatDesde } from '@/utils/format'
import type { HomeEstacion } from '@/types/home'

const props = withDefaults(
  defineProps<{
    estacion: HomeEstacion
    showStatus?: boolean
  }>(),
  { showStatus: true },
)

const tone = computed(() => {
  if (!props.showStatus) return 'public'
  if (props.estacion.estado === 'Libre') return 'libre'
  if (props.estacion.estado === 'Ocupado') return 'ocupado'
  return 'sin-estado'
})

const estadoLabel = computed(() => props.estacion.estado ?? 'sin estado')

const desde = computed(() =>
  props.estacion.estado_desde
    ? formatDesde(props.estacion.estado_desde)
    : 'Sin registros',
)

const ariaLabel = computed(() =>
  props.showStatus
    ? `Poste ${props.estacion.tipo_poste}, toma ${props.estacion.tipo_toma}: ${estadoLabel.value}`
    : `Poste ${props.estacion.tipo_poste}, toma ${props.estacion.tipo_toma}`,
)
</script>

<style scoped>
.station-row {
  display: flex;
  gap: 10px;
  align-items: stretch;
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

.station-row--sin-estado {
  --row-accent: rgba(138, 163, 155, 0.28);
}

.station-row--public {
  --row-accent: rgba(138, 163, 155, 0.24);
}

.station-row__marker {
  width: 3px;
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
}

.station-row__title {
  margin: 0;
  font-size: 0.83rem;
  font-weight: 600;
  color: var(--app-text);
}

.station-row__title span {
  margin: 0 2px;
  color: var(--app-dim);
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

.meta-item--amber,
.meta-item--amber ion-icon {
  color: var(--app-amber);
}
</style>
