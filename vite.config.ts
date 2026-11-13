import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 8100,
    host: true,
    watch: {
      ignored: ['**/android/**', '**/dist/**', '**/.git/**'],
    },
  },
  preview: {
    port: 4173,
    host: true,
  },
  build: {
    target: 'es2022',
  },
})
