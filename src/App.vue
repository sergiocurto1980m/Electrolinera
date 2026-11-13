<template>
  <ion-app>
    <ion-split-pane
      v-if="showAppLayout"
      content-id="main-content"
      when="lg"
    >
      <app-menu />
      <ion-router-outlet id="main-content" />
    </ion-split-pane>

    <ion-router-outlet v-else />
  </ion-app>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { IonApp, IonRouterOutlet, IonSplitPane } from '@ionic/vue'
import AppMenu from '@/components/AppMenu.vue'
import { useAuth } from '@/composables/useAuth'

const route = useRoute()
const router = useRouter()
const { initialized, isAuthenticated } = useAuth()

const isAuthPage = computed(() => route.meta.authPage === true)

/*
 * El menú lateral solo existe con sesión iniciada. La Home pública usa el
 * layout limpio (sin menú) y las páginas de acceso tampoco lo muestran.
 */
const showAppLayout = computed(
  () => !isAuthPage.value && isAuthenticated.value,
)

watch([initialized, isAuthenticated], ([ready, auth]) => {
  if (ready && !auth && !route.meta.public) {
    void router.replace({ name: 'home' })
  }
})
</script>
