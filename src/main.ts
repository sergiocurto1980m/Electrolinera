import { createApp } from 'vue'
import { IonicVue } from '@ionic/vue'
import { Capacitor } from '@capacitor/core'
import { StatusBar, Style } from '@capacitor/status-bar'
import { addIcons } from 'ionicons'
import {
  alertCircleOutline,
  batteryChargingOutline,
  checkmarkCircleOutline,
  chevronDownOutline,
  cloudOfflineOutline,
  flash,
  flashOutline,
  homeOutline,
  listOutline,
  lockClosedOutline,
  logInOutline,
  logOutOutline,
  menuOutline,
  notificationsOutline,
  pauseCircleOutline,
  peopleOutline,
  personCircleOutline,
  pulseOutline,
  radioOutline,
  refreshOutline,
  settingsOutline,
  timeOutline,
  warningOutline,
} from 'ionicons/icons'

import App from './App.vue'
import router from './router'

/* Core Ionic CSS */
import '@ionic/vue/css/core.css'
import '@ionic/vue/css/normalize.css'
import '@ionic/vue/css/structure.css'
import '@ionic/vue/css/typography.css'
import '@ionic/vue/css/padding.css'
import '@ionic/vue/css/float-elements.css'
import '@ionic/vue/css/text-alignment.css'
import '@ionic/vue/css/text-transformation.css'
import '@ionic/vue/css/flex-utils.css'
import '@ionic/vue/css/display.css'

/* Tema oscuro permanente de Ionic (luego lo sobreescribimos) */
import '@ionic/vue/css/palettes/dark.always.css'

/* Tipografía y estilos propios */
import '@fontsource-variable/inter'
import './theme/variables.css'
import './styles/global.css'
import './styles/forms.css'

addIcons({
  alertCircleOutline,
  batteryChargingOutline,
  checkmarkCircleOutline,
  chevronDownOutline,
  cloudOfflineOutline,
  flash,
  flashOutline,
  homeOutline,
  listOutline,
  lockClosedOutline,
  logInOutline,
  logOutOutline,
  menuOutline,
  notificationsOutline,
  pauseCircleOutline,
  peopleOutline,
  personCircleOutline,
  pulseOutline,
  radioOutline,
  refreshOutline,
  settingsOutline,
  timeOutline,
  warningOutline,
})

const app = createApp(App).use(IonicVue).use(router)

if (Capacitor.isNativePlatform()) {
  void StatusBar.setStyle({ style: Style.Light })
  void StatusBar.setBackgroundColor({ color: '#070c0b' })
}

router.isReady().then(() => {
  app.mount('#app')
})
