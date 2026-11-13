<template>
  <span
    class="connection"
    :class="`connection--${status}`"
    :title="detail"
    :aria-label="`${label}. ${detail}`"
    role="status"
  >
    <span class="connection__dot" aria-hidden="true" />
    <span class="connection__label">{{ label }}</span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { LiveStatus } from '@/types/home'

const props = defineProps<{ status: LiveStatus }>()

const labels: Record<LiveStatus, string> = {
  connecting: 'Conectando',
  live: 'En directo',
  paused: 'En pausa',
  offline: 'Sin conexión',
  error: 'Error',
}

const details: Record<LiveStatus, string> = {
  connecting: 'Estableciendo el canal Realtime con Supabase',
  live: 'Recibiendo cambios por WebSocket en tiempo real',
  paused: 'Suscripción pausada mientras la app está en segundo plano',
  offline: 'No se puede contactar con Supabase. Se reintentará al volver.',
  error: 'Error de configuración o de conexión con Supabase',
}

const label = computed(() => labels[props.status])
const detail = computed(() => details[props.status])
</script>

<style scoped>
.connection {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  margin-right: 8px;
  border-radius: 999px;
  border: 1px solid var(--app-border);
  background: rgba(19, 31, 27, 0.72);
  color: var(--app-muted);
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  white-space: nowrap;
}

.connection__dot {
  width: 7px;
  height: 7px;
  border-radius: 999px;
  background: var(--app-dim);
  flex: none;
}

.connection--live {
  color: var(--app-green);
  border-color: rgba(43, 229, 156, 0.3);
  background: rgba(43, 229, 156, 0.08);
}

.connection--live .connection__dot {
  background: var(--app-green);
  animation: app-pulse 2.2s ease-in-out infinite;
}

.connection--connecting {
  color: var(--app-cyan);
  border-color: rgba(34, 211, 238, 0.28);
}

.connection--connecting .connection__dot {
  background: var(--app-cyan);
  animation: app-pulse 1.4s ease-in-out infinite;
}

.connection--paused {
  color: var(--app-amber);
  border-color: rgba(255, 176, 32, 0.28);
}

.connection--paused .connection__dot {
  background: var(--app-amber);
}

.connection--offline,
.connection--error {
  color: var(--app-red);
  border-color: rgba(255, 82, 82, 0.3);
}

.connection--offline .connection__dot,
.connection--error .connection__dot {
  background: var(--app-red);
}

@media (max-width: 430px) {
  .connection__label {
    display: none;
  }

  .connection {
    padding: 8px;
  }
}
</style>
