import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.electrolinera.app',
  appName: 'Electrolinera',
  webDir: 'dist',
  backgroundColor: '#070c0b',
  android: {
    backgroundColor: '#070c0b',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1200,
      launchAutoHide: true,
      backgroundColor: '#070c0b',
      androidScaleType: 'CENTER_CROP',
      showSpinner: false,
      splashFullScreen: true,
      splashImmersive: true,
    },
    StatusBar: {
      style: 'LIGHT',
      backgroundColor: '#070c0b',
      overlaysWebView: false,
    },
  },
}

export default config
