<template>
  <details class="group" :aria-label="`Puestos de ${grupo.tipo}`">
    <summary class="group__summary">
      <header class="group__head">
        <div class="group__title">
          <h3>{{ grupo.tipo }}</h3>
          <p>{{ pluralizar(grupo.total, 'puesto', 'puestos') }}</p>
        </div>

        <div v-if="showStatus" class="group__chips">
          <span class="chip chip--green">
            {{ pluralizar(grupo.libres.length, 'libre', 'libres') }}
          </span>
          <span class="chip chip--amber">
            {{ pluralizar(grupo.ocupadas.length, 'ocupado', 'ocupados') }}
          </span>
          <span class="chip chip--cyan">
            {{ pluralizar(grupo.enCola, 'en cola', 'en cola') }}
          </span>
        </div>
      </header>

      <ion-icon
        class="group__chevron"
        :icon="chevronDownOutline"
        aria-hidden="true"
      />
    </summary>

    <div class="group__body" :class="{ 'group__body--queued': showStatus }">
      <section class="group__section" :aria-label="`${grupo.tipo}: tomas`">
        <header class="group__section-head">
          <h4>Tomas</h4>
          <span class="group__section-count">{{ grupo.total }}</span>
        </header>

        <div class="toma-list">
          <station-row
            v-for="estacion in puestos"
            :key="estacion.id"
            :estacion="estacion"
            :show-status="showStatus"
            :es-mio="estacion.es_mio"
            :marcada-por-mi="estacion.marcada_por_mi"
            :ocupada-por-otro="estacion.ocupada_por_otro"
            :puede-enganchar="puedeEnganchar(estacion)"
            :puede-marcar-por-otro="puedeMarcarPorOtro(estacion)"
            :accionando="accionando"
            @engancharse="emit('engancharse', estacion)"
            @desengancharse="emit('desengancharse', estacion)"
            @marcar-por-otro="emit('marcarPorOtro', estacion)"
          />
        </div>
      </section>

      <section
        v-if="showStatus"
        class="group__section group__section--queue"
        :aria-label="`${grupo.tipo}: cola actual`"
      >
        <header class="group__section-head">
          <h4>Cola actual</h4>
          <span
            class="group__section-count"
            :class="{ 'group__section-count--active': grupo.cola.length > 0 }"
          >
            {{ grupo.cola.length }}
          </span>
        </header>

        <ol v-if="grupo.cola.length" class="queue-list">
          <li
            v-for="item in grupo.cola"
            :key="`${item.posicion}-${item.fecha_hora}`"
            class="queue-item"
            :class="{ 'queue-item--mine': item.es_mio }"
          >
            <span class="queue-item__pos">{{ item.posicion }}</span>
            <span class="queue-item__name">{{ item.es_mio ? 'Tú' : item.nombre }}</span>
            <time class="queue-item__time" :datetime="item.fecha_hora">
              {{ formatHora(item.fecha_hora) }}
            </time>
          </li>
        </ol>
        <p v-else class="queue-empty">No hay nadie en la cola.</p>

        <div
          v-if="grupo.miEnCola || puedeEntrarEnCola"
          class="queue-actions"
        >
          <template v-if="grupo.miEnCola">
            <span class="queue-actions__note">Estás en la cola</span>
            <button
              class="group__queue-btn group__queue-btn--leave"
              type="button"
              :disabled="accionando"
              @click="emit('salirDeCola', grupo)"
            >
              Salir de la cola
            </button>
          </template>

          <template v-else-if="puedeEntrarEnCola">
            <span class="queue-actions__note">
              {{
                grupo.completo
                  ? 'Todos los puestos están ocupados.'
                  : 'Hay una cola activa. Ponte en la cola para engancharte.'
              }}
            </span>
            <button
              class="group__queue-btn"
              type="button"
              :disabled="accionando"
              @click="emit('entrarEnCola', grupo)"
            >
              Ponerse en la cola
            </button>
          </template>
        </div>
      </section>
    </div>
  </details>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { IonIcon } from '@ionic/vue'
import { chevronDownOutline } from 'ionicons/icons'
import StationRow from '@/components/StationRow.vue'
import { formatHora, pluralizar } from '@/utils/format'
import type { HomeEstacion, HomeGrupoEstacion } from '@/types/home'

const props = withDefaults(
  defineProps<{
    grupo: HomeGrupoEstacion
    showStatus?: boolean
    miEstacionId?: number | null
    accionando?: boolean
  }>(),
  {
    showStatus: true,
    miEstacionId: null,
    accionando: false,
  },
)

const emit = defineEmits<{
  engancharse: [estacion: HomeEstacion]
  desengancharse: [estacion: HomeEstacion]
  marcarPorOtro: [estacion: HomeEstacion]
  entrarEnCola: [grupo: HomeGrupoEstacion]
  salirDeCola: [grupo: HomeGrupoEstacion]
}>()

const porPoste = (a: HomeEstacion, b: HomeEstacion) =>
  Number(a.tipo_poste) - Number(b.tipo_poste) ||
  Number(a.tipo_toma) - Number(b.tipo_toma) ||
  a.id - b.id

const puestos = computed<HomeEstacion[]>(() =>
  [
    ...props.grupo.libres,
    ...props.grupo.ocupadas,
    ...props.grupo.sinEstado,
  ].sort(porPoste),
)

/*
 * Estar cargando en otro tipo no impide apuntarse a esta cola. Solo se oculta
 * en el tipo en el que el usuario ya ocupa un puesto.
 *
 * Se puede entrar en la cola cuando el tipo está completo o cuando ya hay una
 * cola activa, aunque se haya liberado algún puesto. Así un usuario que se
 * desconecta puede volver a apuntarse y después engancharse.
 */
const puedeEntrarEnCola = computed(
  () =>
    props.showStatus &&
    !props.grupo.miEnCola &&
    (props.grupo.completo || props.grupo.enCola > 0) &&
    !props.grupo.ocupadas.some((estacion) => estacion.es_mio),
)

function puedeEnganchar(estacion: HomeEstacion): boolean {
  if (!props.showStatus || props.miEstacionId !== null) return false
  if (estacion.estado === 'Ocupado') return false
  if (props.grupo.enCola > 0 && !props.grupo.miEnCola) return false
  return true
}

/*
 * Marcar una toma para otra persona refleja la realidad física de la
 * estación. No exige estar en la cola ni impide hacerlo mientras el usuario
 * ocupa otro puesto.
 */
function puedeMarcarPorOtro(estacion: HomeEstacion): boolean {
  if (!props.showStatus) return false
  return estacion.estado !== 'Ocupado'
}
</script>

<style scoped>
.group {
  min-width: 0;
  scroll-margin-top: 12px;
  padding: 18px;
  border-radius: var(--app-radius);
  border: 1px solid var(--app-border);
  background: linear-gradient(
    180deg,
    rgba(15, 23, 21, 0.84),
    rgba(9, 15, 13, 0.76)
  );
  box-shadow: var(--app-shadow);
}

.group__summary {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 2px;
  border-radius: 10px;
  cursor: pointer;
  list-style: none;
}

.group__summary::-webkit-details-marker {
  display: none;
}

.group__summary::marker {
  content: '';
}

.group__summary:focus-visible {
  outline: 2px solid var(--app-green);
  outline-offset: 4px;
}

.group__head {
  flex: 1;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
  min-width: 0;
}

.group__chevron {
  flex: none;
  font-size: 18px;
  color: var(--app-muted);
  transition:
    transform 180ms ease,
    color 180ms ease;
}

.group[open] .group__chevron {
  transform: rotate(180deg);
  color: var(--app-green);
}

.group__title {
  min-width: 0;
}

.group__title h3 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.group__title p {
  margin: 2px 0 0;
  font-size: 0.74rem;
  color: var(--app-muted);
}

.group__chips {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 6px;
}

.chip {
  padding: 4px 9px;
  border-radius: 999px;
  font-size: 0.68rem;
  font-weight: 650;
  white-space: nowrap;
}

.chip--green {
  color: var(--app-green);
  background: rgba(43, 229, 156, 0.1);
  border: 1px solid rgba(43, 229, 156, 0.25);
}

.chip--amber {
  color: var(--app-amber);
  background: rgba(255, 176, 32, 0.09);
  border: 1px solid rgba(255, 176, 32, 0.24);
}

.chip--cyan {
  color: var(--app-cyan);
  background: rgba(34, 211, 238, 0.1);
  border: 1px solid rgba(34, 211, 238, 0.25);
}

.group__body {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  align-items: start;
  gap: 16px;
  margin-top: 14px;
}

.group__body--queued {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.group__section {
  min-width: 0;
}

.group__section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
  padding: 0 2px;
}

.group__section-head h4 {
  margin: 0;
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--app-muted);
}

.group__section--queue .group__section-head h4 {
  color: var(--app-cyan);
}

.group__section-count {
  display: inline-grid;
  place-items: center;
  min-width: 20px;
  height: 18px;
  padding: 0 6px;
  border-radius: 999px;
  font-size: 0.66rem;
  font-weight: 700;
  color: var(--app-muted);
  background: rgba(148, 190, 175, 0.1);
}

.group__section-count--active {
  color: var(--app-cyan);
  background: rgba(34, 211, 238, 0.1);
}

.toma-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.queue-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.queue-item {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  padding: 8px 10px;
  border-radius: 10px;
  border: 1px solid var(--app-border);
  background: rgba(7, 12, 11, 0.35);
}

.queue-item--mine {
  border-color: rgba(34, 211, 238, 0.32);
  background: rgba(34, 211, 238, 0.06);
}

.queue-item__pos {
  display: inline-grid;
  place-items: center;
  width: 22px;
  height: 22px;
  flex: none;
  border-radius: 999px;
  font-size: 0.66rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--app-cyan);
  background: rgba(34, 211, 238, 0.1);
  border: 1px solid rgba(34, 211, 238, 0.22);
}

.queue-item__name {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--app-text);
}

.queue-item--mine .queue-item__name {
  color: var(--app-cyan);
}

.queue-item__time {
  flex: none;
  font-size: 0.68rem;
  color: var(--app-dim);
}

.queue-empty {
  margin: 0;
  padding: 12px 6px;
  border: 1px dashed var(--app-border);
  border-radius: 9px;
  text-align: center;
  font-size: 0.7rem;
  color: var(--app-dim);
}

.queue-actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}

.queue-actions__note {
  font-size: 0.72rem;
  color: var(--app-muted);
}

.group__queue-btn {
  margin-left: auto;
  padding: 6px 10px;
  border-radius: 8px;
  border: 1px solid rgba(43, 229, 156, 0.3);
  background: rgba(43, 229, 156, 0.08);
  color: var(--app-green);
  font-size: 0.7rem;
  font-weight: 650;
  cursor: pointer;
}

.group__queue-btn:hover:not(:disabled) {
  border-color: rgba(43, 229, 156, 0.5);
  background: rgba(43, 229, 156, 0.14);
}

.group__queue-btn--leave {
  color: var(--app-amber);
  border-color: rgba(255, 176, 32, 0.3);
  background: rgba(255, 176, 32, 0.08);
}

.group__queue-btn--leave:hover:not(:disabled) {
  border-color: rgba(255, 176, 32, 0.5);
  background: rgba(255, 176, 32, 0.14);
}

.group__queue-btn:disabled {
  opacity: 0.55;
  cursor: progress;
}

@media (max-width: 820px) {
  .group {
    padding: 14px;
  }

  .group__summary {
    align-items: flex-start;
  }

  .group__head {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

  .group__chips {
    justify-content: flex-start;
  }

  .group__body--queued {
    grid-template-columns: minmax(0, 1fr);
  }

  .group__queue-btn {
    margin-left: 0;
  }
}
</style>
