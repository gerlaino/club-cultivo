import { defineConfig } from "vite"
import { execSync } from "node:child_process"

// Identificador del build: qué commit está corriendo. Sin esto no hay forma de saber si lo que
// ves en pantalla es la última versión o una cacheada — y se pierde tiempo discutiendo si un
// cambio "se hizo" cuando en realidad no llegó al dispositivo.
const BUILD_ID = (() => {
  try { return execSync("git rev-parse --short HEAD").toString().trim() }
  catch { return "dev" }
})()
const BUILD_AT = new Date().toISOString().slice(0, 16).replace("T", " ")
import vue from "@vitejs/plugin-vue"
import { VitePWA } from "vite-plugin-pwa"

export default defineConfig({
  define: {
    __APP_BUILD__: JSON.stringify(BUILD_ID),
    __APP_BUILD_AT__: JSON.stringify(BUILD_AT),
  },
  plugins: [
    vue(),
    VitePWA({
      strategies:    'injectManifest',
      srcDir:        'src',
      filename:      'sw.js',
      registerType:  'prompt',
      includeAssets: ['favicon.ico', 'logo-ce-redondo.png'],
      manifest: {
        // El producto se llama Cultivo Espacial. "Club Cultivo" es el nombre del REPOSITORIO, y se
        // había colado acá: al instalar la PWA, el celular sugería ese nombre para el ícono.
        name:             'Cultivo Espacial',
        short_name:       'Cultivo Espacial',
        description:      'Gestión integral de clubes de cannabis — REPROCANN',
        lang:             'es',
        theme_color:      '#0F2A1E',
        background_color: '#0F2A1E',
        display:          'standalone',
        orientation:      'portrait',
        scope:            '/',
        start_url:        '/m',
        icons: [
          { src: 'icons/icon-72x72.svg',       sizes: '72x72',   type: 'image/svg+xml' },
          { src: 'icons/icon-96x96.svg',       sizes: '96x96',   type: 'image/svg+xml' },
          { src: 'icons/icon-128x128.svg',     sizes: '128x128', type: 'image/svg+xml' },
          { src: 'icons/icon-144x144.svg',     sizes: '144x144', type: 'image/svg+xml' },
          { src: 'icons/icon-152x152.svg',     sizes: '152x152', type: 'image/svg+xml' },
          { src: 'icons/icon-192x192.svg',     sizes: '192x192', type: 'image/svg+xml' },
          { src: 'icons/icon-384x384.svg',     sizes: '384x384', type: 'image/svg+xml' },
          { src: 'icons/icon-512x512.svg',     sizes: '512x512', type: 'image/svg+xml' },
          { src: 'icons/maskable-192x192.svg', sizes: '192x192', type: 'image/svg+xml', purpose: 'maskable' },
          { src: 'icons/maskable-512x512.svg', sizes: '512x512', type: 'image/svg+xml', purpose: 'maskable' },
        ],
      },
      injectManifest: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
      },

    })
  ],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-vue':    ['vue', 'vue-router', 'pinia'],
          'vendor-charts': ['chart.js'],
          'vendor-qr':     ['qrcode'],
        }
      }
    }
  },
  server: {
    port: 5173,
  }
})
