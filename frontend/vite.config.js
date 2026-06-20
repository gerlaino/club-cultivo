import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import { VitePWA } from "vite-plugin-pwa"

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      strategies:    'injectManifest',
      srcDir:        'src',
      filename:      'sw.js',
      registerType:  'prompt',
      includeAssets: ['favicon.ico', 'logo-ce-redondo.png'],
      manifest: {
        name:             'Club Cultivo',
        short_name:       'Club Cultivo',
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
