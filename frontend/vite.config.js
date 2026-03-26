import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"
import { VitePWA } from "vite-plugin-pwa"

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon.ico", "icons/*.svg"],
      manifest: {
        name: "Club Cultivo",
        short_name: "Club Cultivo",
        description: "Gestión de clubes cannábicos medicinales — REPROCANN",
        theme_color: "#1a7a4a",
        background_color: "#ffffff",
        display: "standalone",
        orientation: "portrait",
        scope: "/",
        start_url: "/",
        icons: [
          { src: "icons/icon-72x72.svg",   sizes: "72x72",   type: "image/svg+xml" },
          { src: "icons/icon-96x96.svg",   sizes: "96x96",   type: "image/svg+xml" },
          { src: "icons/icon-128x128.svg", sizes: "128x128", type: "image/svg+xml" },
          { src: "icons/icon-144x144.svg", sizes: "144x144", type: "image/svg+xml" },
          { src: "icons/icon-152x152.svg", sizes: "152x152", type: "image/svg+xml" },
          { src: "icons/icon-192x192.svg", sizes: "192x192", type: "image/svg+xml" },
          { src: "icons/icon-384x384.svg", sizes: "384x384", type: "image/svg+xml" },
          { src: "icons/icon-512x512.svg", sizes: "512x512", type: "image/svg+xml" },
          { src: "icons/maskable-192x192.svg", sizes: "192x192", type: "image/svg+xml", purpose: "maskable" },
          { src: "icons/maskable-512x512.svg", sizes: "512x512", type: "image/svg+xml", purpose: "maskable" }
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
  server: {
    port: 5173,
    proxy: {
      "/users":  { target: "http://localhost:3001", changeOrigin: true },
      "/me":     { target: "http://localhost:3001", changeOrigin: true },
      "/salas":  { target: "http://localhost:3001", changeOrigin: true },
      "/lotes":  { target: "http://localhost:3001", changeOrigin: true },
      "/health": { target: "http://localhost:3001", changeOrigin: true },
    }
  }
})
