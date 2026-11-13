<template>
  <section class="avisos panel" aria-labelledby="avisos-title">
    <header class="avisos__head">
      <div class="avisos__title">
        <span class="avisos__icon" aria-hidden="true">
          <ion-icon :icon="notificationsOutline" />
        </span>
        <div>
          <h2 id="avisos-title">Avisos</h2>
          <p>Últimos mensajes de la lista de espera</p>
        </div>
      </div>
      <span class="avisos__count">{{ avisos.length }}</span>
    </header>

    <div v-if="loading" class="avisos__skeletons">
      <div v-for="n in 3" :key="`aviso-skeleton-${n}`" class="skeleton aviso-skeleton" />
    </div>

    <p v-else-if="avisos.length === 0" class="avisos__empty">
      Todavía no hay avisos registrados.
    </p>

    <ol v-else class="avisos__list">
      <li v-for="aviso in avisos" :key="aviso.id" class="aviso">
        <span class="aviso__dot" aria-hidden="true" />
        <div class="aviso__body">
          <p class="aviso__text">{{ aviso.aviso }}</p>
          <p class="aviso__meta">
            {{ aviso.tipo_estacion }}
            <template v-if="aviso.tipo_poste && aviso.tipo_toma">
              · Poste {{ aviso.tipo_poste }} · Toma {{ aviso.tipo_toma }}
            </template>
            <span aria-hidden="true"> · </span>
            <time :datetime="aviso.fecha_hora">{{ formatFechaHora(aviso.fecha_hora) }}</time>
          </p>
        </div>
      </li>
    </ol>
  </section>
</template>

<script setup lang="ts">
import { IonIcon } from '@ionic/vue'
import { notificationsOutline } from 'ionicons/icons'
import { formatFechaHora } from '@/utils/format'
import type { HomeAviso } from '@/types/home'

defineProps<{
  avisos: HomeAviso[]
  loading?: boolean
}>()
</script>

<style scoped>
.avisos {
  padding: 18px;
}

.avisos__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
}

.avisos__title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.avisos__icon {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  flex: none;
  border-radius: 12px;
  color: var(--app-cyan);
  background: rgba(34, 211, 238, 0.1);
  box-shadow: inset 0 0 0 1px rgba(34, 211, 238, 0.22);
}

.avisos__icon ion-icon {
  font-size: 20px;
}

.avisos h2 {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 650;
  color: var(--app-text);
}

.avisos p {
  margin: 2px 0 0;
  font-size: 0.78rem;
  color: var(--app-muted);
}

.avisos__count {
  display: inline-grid;
  place-items: center;
  min-width: 28px;
  height: 24px;
  padding: 0 8px;
  border-radius: 999px;
  font-size: 0.74rem;
  font-weight: 700;
  color: var(--app-cyan);
  background: rgba(34, 211, 238, 0.1);
  border: 1px solid rgba(34, 211, 238, 0.22);
}

.avisos__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
}

.aviso {
  display: flex;
  gap: 12px;
  padding: 12px 0;
  border-top: 1px solid var(--app-border);
}

.aviso:first-child {
  border-top: 0;
  padding-top: 2px;
}

.aviso__dot {
  width: 7px;
  height: 7px;
  margin-top: 7px;
  border-radius: 999px;
  flex: none;
  background: var(--app-cyan);
  box-shadow: 0 0 0 4px rgba(34, 211, 238, 0.1);
}

.aviso__body {
  min-width: 0;
}

.aviso__text {
  margin: 0;
  font-size: 0.88rem;
  line-height: 1.45;
  color: var(--app-text);
}

.aviso__meta {
  margin: 3px 0 0;
  font-size: 0.72rem;
  color: var(--app-dim);
}

.aviso__meta span {
  margin: 0 4px;
}

.avisos__empty {
  padding: 8px 0 4px;
  font-size: 0.86rem;
}

.avisos__skeletons {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.aviso-skeleton {
  height: 46px;
  width: 100%;
}
</style>
