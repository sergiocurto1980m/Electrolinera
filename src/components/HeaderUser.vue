<template>
  <router-link
    v-if="isAuthenticated"
    :to="{ name: 'cuenta' }"
    class="header-user"
    :title="userLabel"
    :aria-label="`Mi cuenta. ${userLabel}`"
  >
    <span class="header-user__avatar" aria-hidden="true">{{ initials }}</span>
    <span class="header-user__name">{{ displayName }}</span>
  </router-link>

  <router-link
    v-else
    :to="{ name: 'login' }"
    class="header-login"
    aria-label="Iniciar sesión"
  >
    <ion-icon :icon="logInOutline" aria-hidden="true" />
    <span>Entrar</span>
  </router-link>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { IonIcon } from '@ionic/vue'
import { logInOutline } from 'ionicons/icons'
import { useAuth } from '@/composables/useAuth'

const { isAuthenticated, perfil, initials } = useAuth()

const displayName = computed(
  () => perfil.value?.nombre || perfil.value?.email || 'Mi cuenta',
)

const userLabel = computed(() => {
  const parts = [perfil.value?.nombre, perfil.value?.email].filter(Boolean)
  return parts.length ? parts.join(' · ') : 'Mi cuenta'
})
</script>

<style scoped>
.header-user {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  max-width: 190px;
  padding: 3px 10px 3px 3px;
  border-radius: 999px;
  border: 1px solid var(--app-border);
  background: rgba(19, 31, 27, 0.55);
  color: var(--app-text);
  text-decoration: none;
  transition:
    border-color 160ms ease,
    background 160ms ease;
}

.header-user:hover {
  border-color: rgba(43, 229, 156, 0.35);
  background: rgba(43, 229, 156, 0.07);
}

.header-user__avatar {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  flex: none;
  border-radius: 999px;
  color: #04120d;
  background: linear-gradient(145deg, #3cf0a8, #16b97b);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.35);
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.header-user__name {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.76rem;
  font-weight: 600;
}

.header-login {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 11px;
  border-radius: 10px;
  border: 1px solid rgba(43, 229, 156, 0.3);
  background: rgba(43, 229, 156, 0.08);
  color: var(--app-green);
  font-size: 0.76rem;
  font-weight: 650;
  text-decoration: none;
  white-space: nowrap;
  transition:
    border-color 160ms ease,
    background 160ms ease;
}

.header-login:hover {
  border-color: rgba(43, 229, 156, 0.5);
  background: rgba(43, 229, 156, 0.14);
}

.header-login ion-icon {
  font-size: 15px;
}

@media (max-width: 720px) {
  .header-user {
    padding: 3px;
  }

  .header-user__name {
    display: none;
  }
}

@media (max-width: 380px) {
  .header-login {
    padding: 7px 8px;
  }

  .header-login span {
    display: none;
  }
}
</style>
