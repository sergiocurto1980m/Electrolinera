<template>
  <article class="group" :aria-label="`Puestos de ${grupo.tipo}`">
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
          {{ pluralizar(grupo.ocupadas.length, 'ocupada', 'ocupadas') }}
        </span>
        <span v-if="grupo.sinEstado.length" class="chip chip--muted">
          {{ pluralizar(grupo.sinEstado.length, 'sin estado', 'sin estado') }}
        </span>
      </div>
    </header>

    <template v-if="showStatus">
      <div
        class="group__columns"
        :class="{ 'group__columns--three': grupo.sinEstado.length > 0 }"
      >
        <section class="column column--green" :aria-label="`${grupo.tipo}: puestos libres`">
          <header class="column__head">
            <h4>Libres</h4>
            <span class="column__count">{{ grupo.libres.length }}</span>
          </header>
          <div v-if="grupo.libres.length" class="column__rows">
            <station-row
              v-for="estacion in grupo.libres"
              :key="estacion.id"
              :estacion="estacion"
            />
          </div>
          <p v-else class="column__empty">No hay puestos libres</p>
        </section>

        <section class="column column--amber" :aria-label="`${grupo.tipo}: puestos ocupados`">
          <header class="column__head">
            <h4>Ocupadas</h4>
            <span class="column__count">{{ grupo.ocupadas.length }}</span>
          </header>
          <div v-if="grupo.ocupadas.length" class="column__rows">
            <station-row
              v-for="estacion in grupo.ocupadas"
              :key="estacion.id"
              :estacion="estacion"
            />
          </div>
          <p v-else class="column__empty">No hay puestos ocupados</p>
        </section>

        <section
          v-if="grupo.sinEstado.length"
          class="column column--muted"
          :aria-label="`${grupo.tipo}: puestos sin estado`"
        >
          <header class="column__head">
            <h4>Sin estado</h4>
            <span class="column__count">{{ grupo.sinEstado.length }}</span>
          </header>
          <div class="column__rows">
            <station-row
              v-for="estacion in grupo.sinEstado"
              :key="estacion.id"
              :estacion="estacion"
            />
          </div>
        </section>
      </div>
    </template>

    <div v-else class="group__columns group__columns--public">
      <section
        class="column column--public"
        :aria-label="`${grupo.tipo}: puestos disponibles`"
      >
        <header class="column__head">
          <h4>Puestos</h4>
          <span class="column__count">{{ grupo.total }}</span>
        </header>
        <div class="column__rows column__rows--public">
          <station-row
            v-for="estacion in puestos"
            :key="estacion.id"
            :estacion="estacion"
            :show-status="false"
          />
        </div>
      </section>
    </div>
  </article>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import StationRow from '@/components/StationRow.vue'
import { pluralizar } from '@/utils/format'
import type { HomeEstacion, HomeGrupoEstacion } from '@/types/home'

const props = withDefaults(
  defineProps<{
    grupo: HomeGrupoEstacion
    showStatus?: boolean
  }>(),
  { showStatus: true },
)

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
</script>

<style scoped>
.group {
  min-width: 0;
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

.group__head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
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

.chip--muted {
  color: var(--app-muted);
  background: rgba(148, 190, 175, 0.07);
  border: 1px solid var(--app-border);
}

.group__columns {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.group__columns--three {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.group__columns--public {
  grid-template-columns: 1fr;
}

.column {
  min-width: 0;
  padding: 10px;
  border-radius: 14px;
  border: 1px solid var(--app-border);
  background: rgba(7, 12, 11, 0.32);
}

.column--green {
  border-color: rgba(43, 229, 156, 0.16);
}

.column--amber {
  border-color: rgba(255, 176, 32, 0.16);
}

.column--muted {
  border-color: rgba(138, 163, 155, 0.14);
}

.column--public {
  border-color: rgba(138, 163, 155, 0.14);
}

.column__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
  padding: 0 2px;
}

.column__head h4 {
  margin: 0;
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--app-muted);
}

.column--green .column__head h4 {
  color: var(--app-green);
}

.column--amber .column__head h4 {
  color: var(--app-amber);
}

.column__count {
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

.column--green .column__count {
  color: var(--app-green);
  background: rgba(43, 229, 156, 0.1);
}

.column--amber .column__count {
  color: var(--app-amber);
  background: rgba(255, 176, 32, 0.1);
}

.column__rows {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.column__rows--public {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.column__empty {
  margin: 2px 0 0;
  padding: 12px 6px;
  border: 1px dashed var(--app-border);
  border-radius: 9px;
  text-align: center;
  font-size: 0.7rem;
  color: var(--app-dim);
}

@media (max-width: 820px) {
  .group {
    padding: 14px;
  }

  .group__head {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

  .group__chips {
    justify-content: flex-start;
  }

  .group__columns,
  .group__columns--three {
    grid-template-columns: 1fr;
  }

  .column__rows--public {
    grid-template-columns: 1fr;
  }
}
</style>
