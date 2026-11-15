<template>
  <ion-menu
    menu-id="main-menu"
    content-id="main-content"
    type="overlay"
    class="app-menu"
  >
    <ion-header class="ion-no-border app-menu__header">
      <ion-toolbar>
        <div class="brand">
          <span class="brand__mark" aria-hidden="true">
            <ion-icon :icon="flash" />
          </span>
          <div class="brand__copy">
            <p class="brand__name">Electrolinera</p>
            <p class="brand__tag">Gestión de carga</p>
          </div>
        </div>
      </ion-toolbar>
    </ion-header>

    <ion-content class="app-menu__content">
      <div v-if="perfil" class="user-card">
        <span class="user-card__avatar" aria-hidden="true">{{ initials }}</span>
        <div class="user-card__body">
          <p class="user-card__name">{{ perfil.nombre }}</p>
          <p class="user-card__email">{{ perfil.email }}</p>
        </div>
      </div>

      <nav class="menu-nav" aria-label="Principal">
        <p class="menu-nav__label">Principal</p>

        <ion-item
          router-link="/home"
          router-direction="root"
          :detail="false"
          lines="none"
          class="menu-link"
          :class="{ 'menu-link--active': isHome }"
          @click="closeMenu"
        >
          <ion-icon slot="start" :icon="homeOutline" aria-hidden="true" />
          <ion-label>Inicio</ion-label>
          <span v-if="isHome" slot="end" class="menu-link__active-dot" aria-hidden="true" />
        </ion-item>

        <p class="menu-nav__label">Gestión</p>

        <ion-item disabled lines="none" :detail="false" class="menu-link">
          <ion-icon slot="start" :icon="flashOutline" aria-hidden="true" />
          <ion-label>Estaciones</ion-label>
          <span slot="end" class="menu-link__soon">Pronto</span>
        </ion-item>

        <ion-item disabled lines="none" :detail="false" class="menu-link">
          <ion-icon slot="start" :icon="listOutline" aria-hidden="true" />
          <ion-label>Lista de espera</ion-label>
          <span slot="end" class="menu-link__soon">Pronto</span>
        </ion-item>

        <ion-item disabled lines="none" :detail="false" class="menu-link">
          <ion-icon slot="start" :icon="peopleOutline" aria-hidden="true" />
          <ion-label>Usuarios</ion-label>
          <span slot="end" class="menu-link__soon">Pronto</span>
        </ion-item>

        <ion-item disabled lines="none" :detail="false" class="menu-link">
          <ion-icon slot="start" :icon="notificationsOutline" aria-hidden="true" />
          <ion-label>Avisos</ion-label>
          <span slot="end" class="menu-link__soon">Pronto</span>
        </ion-item>

        <p class="menu-nav__label">Sistema</p>

        <ion-item
          router-link="/cuenta"
          router-direction="forward"
          :detail="false"
          lines="none"
          class="menu-link"
          :class="{ 'menu-link--active': isAccount }"
          @click="closeMenu"
        >
          <ion-icon slot="start" :icon="personCircleOutline" aria-hidden="true" />
          <ion-label>Mi cuenta</ion-label>
          <span
            v-if="isAccount"
            slot="end"
            class="menu-link__active-dot"
            aria-hidden="true"
          />
        </ion-item>

        <ion-item
          v-if="perfil?.es_admin"
          router-link="/ajustes"
          router-direction="forward"
          :detail="false"
          lines="none"
          class="menu-link"
          :class="{ 'menu-link--active': isSettings }"
          @click="closeMenu"
        >
          <ion-icon slot="start" :icon="settingsOutline" aria-hidden="true" />
          <ion-label>Configuración</ion-label>
          <span
            v-if="isSettings"
            slot="end"
            class="menu-link__active-dot"
            aria-hidden="true"
          />
        </ion-item>

        <ion-item
          v-if="!esNativo"
          router-link="/descargar"
          router-direction="forward"
          :detail="false"
          lines="none"
          class="menu-link"
          @click="closeMenu"
        >
          <ion-icon slot="start" :icon="downloadOutline" aria-hidden="true" />
          <ion-label>Descargar Android</ion-label>
        </ion-item>
      </nav>
    </ion-content>

    <ion-footer class="app-menu__footer">
      <div class="menu-footer">
        <button class="menu-logout" type="button" @click="handleSignOut">
          <ion-icon :icon="logOutOutline" aria-hidden="true" />
          <span>Cerrar sesión</span>
        </button>
        <span class="menu-footer__version">v0.1.0</span>
      </div>
    </ion-footer>
  </ion-menu>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  IonContent,
  IonFooter,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonMenu,
  IonToolbar,
  menuController,
} from '@ionic/vue'
import {
  downloadOutline,
  flash,
  flashOutline,
  homeOutline,
  listOutline,
  logOutOutline,
  notificationsOutline,
  peopleOutline,
  personCircleOutline,
  settingsOutline,
} from 'ionicons/icons'
import { Capacitor } from '@capacitor/core'
import { useAuth } from '@/composables/useAuth'

const route = useRoute()
const router = useRouter()
const { perfil, initials, signOut } = useAuth()

const esNativo = Capacitor.isNativePlatform()

const isHome = computed(() => route.path === '/home')
const isAccount = computed(() => route.path === '/cuenta')
const isSettings = computed(() => route.path === '/ajustes')

async function closeMenu(): Promise<void> {
  try {
    await menuController.close('main-menu')
  } catch {
    // El menú ya puede estar cerrado o desmontado.
  }
}

async function handleSignOut(): Promise<void> {
  try {
    await signOut()
  } catch {
    // La sesión local se limpia igualmente en useAuth.signOut().
  }

  await closeMenu()
  await router.replace({ name: 'home' })
}
</script>

<style scoped>
.app-menu {
  --width: 288px;
  --max-width: 320px;
}

.app-menu::part(container) {
  background:
    radial-gradient(420px 260px at 20% 0%, rgba(43, 229, 156, 0.12), transparent 70%),
    linear-gradient(180deg, #0b1311 0%, #080e0c 100%);
  border-right: 1px solid var(--app-border);
}

.app-menu__header {
  background: transparent;
}

.app-menu__header ion-toolbar {
  --background: transparent;
  --border-width: 0;
  --min-height: 84px;
  padding: 8px 8px 0;
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 8px;
}

.brand__mark {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  flex: none;
  border-radius: 14px;
  color: #04120d;
  background: linear-gradient(145deg, #3cf0a8, #16b97b);
  box-shadow:
    0 10px 26px -12px rgba(43, 229, 156, 0.85),
    inset 0 1px 0 rgba(255, 255, 255, 0.4);
}

.brand__mark ion-icon {
  font-size: 24px;
}

.brand__copy {
  min-width: 0;
}

.brand__name {
  margin: 0;
  font-size: 1.02rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--app-text);
}

.brand__tag {
  margin: 1px 0 0;
  font-size: 0.72rem;
  color: var(--app-muted);
}

.app-menu__content {
  --background: transparent;
  --padding-top: 8px;
  --padding-bottom: 12px;
}

.user-card {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 4px 16px 2px;
  padding: 10px 12px;
  border-radius: 14px;
  border: 1px solid var(--app-border);
  background: rgba(19, 31, 27, 0.55);
}

.user-card__avatar {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  flex: none;
  border-radius: 11px;
  color: #04120d;
  font-size: 0.78rem;
  font-weight: 700;
  background: linear-gradient(145deg, #3cf0a8, #16b97b);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.35);
}

.user-card__body {
  min-width: 0;
}

.user-card__name {
  margin: 0;
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--app-text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.user-card__email {
  margin: 1px 0 0;
  font-size: 0.68rem;
  color: var(--app-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.menu-nav {
  padding: 4px 0 8px;
}

.menu-nav__label {
  margin: 16px 22px 6px;
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--app-dim);
}

.menu-link {
  --background: transparent;
  --color: var(--app-muted);
  --min-height: 44px;
  --padding-start: 14px;
  --inner-padding-end: 14px;
  --border-radius: 12px;
  margin: 2px 12px;
  font-size: 0.9rem;
  font-weight: 550;
}

.menu-link ion-icon {
  color: inherit;
  font-size: 19px;
  margin-inline-end: 12px;
}

.menu-link--active {
  --background: rgba(43, 229, 156, 0.11);
  --color: var(--app-green);
  box-shadow: inset 0 0 0 1px rgba(43, 229, 156, 0.22);
}

.menu-link--active ion-icon {
  color: var(--app-green);
}

.menu-link__active-dot {
  width: 7px;
  height: 7px;
  border-radius: 999px;
  background: var(--app-green);
  box-shadow: 0 0 10px rgba(43, 229, 156, 0.7);
}

.menu-link__soon {
  padding: 2px 7px;
  border-radius: 999px;
  border: 1px solid var(--app-border);
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--app-dim);
}

ion-item[disabled] {
  opacity: 0.52;
}

.app-menu__footer {
  background: transparent;
}

.menu-footer {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0 16px 12px;
  padding: 12px 0 0;
  border-top: 1px solid var(--app-border);
}

.menu-logout {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 9px 10px;
  border: 1px solid var(--app-border);
  border-radius: 10px;
  background: transparent;
  color: var(--app-muted);
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
  transition:
    color 160ms ease,
    border-color 160ms ease,
    background 160ms ease;
}

.menu-logout:hover {
  color: var(--app-red);
  border-color: rgba(255, 82, 82, 0.35);
  background: rgba(255, 82, 82, 0.05);
}

.menu-logout ion-icon {
  font-size: 16px;
}

.menu-footer__version {
  align-self: flex-end;
  font-size: 0.68rem;
  color: var(--app-dim);
  font-variant-numeric: tabular-nums;
}
</style>
