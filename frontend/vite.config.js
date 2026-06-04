import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import { VitePWA } from "vite-plugin-pwa"

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon.ico", "logo-ce-redondo.png"],
      manifest: {
        name: "Cultivo Espacial",
        short_name: "Cultivo Espacial",
        description: "Gestión de clubes cannábicos medicinales — REPROCANN",
        theme_color: "#1a7a4a",
        background_color: "#1a7a4a",
        display: "standalone",
        orientation: "portrait",
        scope: "/",
        start_url: "/",
        icons: [
          { src: "logo-ce-redondo.png", sizes: "192x192", type: "image/png" },
          { src: "logo-ce-redondo.png", sizes: "512x512", type: "image/png" },
          { src: "logo-ce-redondo.png", sizes: "192x192", type: "image/png", purpose: "maskable" },
          { src: "logo-ce-redondo.png", sizes: "512x512", type: "image/png", purpose: "maskable" }
        ]
      },
      workbox: {
        // Cachear assets estáticos (JS, CSS, fuentes, íconos)
        globPatterns: ["**/*.{js,css,html,ico,png,svg,woff2}"],
        // Estrategia network-first para las llamadas a la API
        runtimeCaching: [
          {
            urlPattern: /^http:\/\/localhost:3001\/.*/i,
            handler: "NetworkFirst",
            options: {
              cacheName: "api-cache",
              expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 24 }, // 24hs
              networkTimeoutSeconds: 10,
              cacheableResponse: { statuses: [0, 200] }
            }
          }
        ]
      }
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
