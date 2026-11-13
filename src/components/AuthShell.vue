<template>
  <div class="auth">
    <div class="auth__glow" aria-hidden="true" />

    <section class="auth__card">
      <header class="auth__head">
        <span class="auth__mark" aria-hidden="true">
          <ion-icon :icon="flash" />
        </span>
        <p class="auth__brand">Electrolinera</p>
        <h1>{{ title }}</h1>
        <p v-if="subtitle" class="auth__subtitle">{{ subtitle }}</p>
      </header>

      <div class="auth__body">
        <slot />
      </div>

      <footer v-if="$slots.footer" class="auth__footer">
        <slot name="footer" />
      </footer>
    </section>

    <p class="auth__version">Gestión de puestos de carga · v0.1.0</p>
  </div>
</template>

<script setup lang="ts">
import { IonIcon } from '@ionic/vue'
import { flash } from 'ionicons/icons'

defineProps<{
  title: string
  subtitle?: string
}>()
</script>

<style scoped>
.auth {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 18px;
  min-height: 100vh;
  min-height: 100dvh;
  padding: calc(28px + env(safe-area-inset-top)) 16px
    calc(24px + env(safe-area-inset-bottom));
}

.auth__glow {
  position: absolute;
  top: 8%;
  width: min(560px, 90vw);
  height: 360px;
  border-radius: 50%;
  background: radial-gradient(
    closest-side,
    rgba(43, 229, 156, 0.16),
    transparent 70%
  );
  filter: blur(10px);
  pointer-events: none;
}

.auth__card {
  position: relative;
  width: min(100%, 440px);
  padding: 30px;
  border-radius: 24px;
  border: 1px solid var(--app-border);
  background: linear-gradient(
    165deg,
    rgba(19, 31, 27, 0.96),
    rgba(8, 14, 12, 0.94)
  );
  box-shadow:
    0 30px 70px -36px rgba(0, 0, 0, 0.95),
    0 0 0 1px rgba(43, 229, 156, 0.03);
  backdrop-filter: blur(20px);
}

.auth__head {
  text-align: center;
}

.auth__mark {
  display: inline-grid;
  place-items: center;
  width: 52px;
  height: 52px;
  border-radius: 16px;
  color: #04120d;
  background: linear-gradient(145deg, #3cf0a8, #16b97b);
  box-shadow:
    0 14px 30px -14px rgba(43, 229, 156, 0.9),
    inset 0 1px 0 rgba(255, 255, 255, 0.4);
}

.auth__mark ion-icon {
  font-size: 28px;
}

.auth__brand {
  margin: 12px 0 0;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--app-green);
}

.auth__head h1 {
  margin: 8px 0 0;
  font-size: 1.6rem;
  line-height: 1.15;
  letter-spacing: -0.03em;
  font-weight: 700;
  color: var(--app-text);
}

.auth__subtitle {
  margin: 8px auto 0;
  max-width: 320px;
  font-size: 0.83rem;
  line-height: 1.5;
  color: var(--app-muted);
}

.auth__body {
  margin-top: 22px;
}

.auth__footer {
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid var(--app-border);
  text-align: center;
  font-size: 0.8rem;
  color: var(--app-muted);
}

.auth__footer :deep(a) {
  color: var(--app-green);
  font-weight: 600;
  text-decoration: none;
}

.auth__footer :deep(a:hover) {
  text-decoration: underline;
}

.auth__version {
  position: relative;
  margin: 0;
  font-size: 0.68rem;
  color: var(--app-dim);
  text-align: center;
}

@media (max-width: 480px) {
  .auth__card {
    padding: 24px 20px;
    border-radius: 20px;
  }

  .auth__head h1 {
    font-size: 1.42rem;
  }
}
</style>
