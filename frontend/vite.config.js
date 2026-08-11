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
        // Mismo encuadre que la landing: el producto es para toda organización que cultiva, y
        // REPROCANN es una salida de la data, no la identidad del producto.
        description:      'Gestión integral para organizaciones que cultivan cannabis',
        lang:             'es',
        theme_color:      '#0F2A1E',
        background_color: '#0F2A1E',
        display:          'standalone',
        orientation:      'portrait',
        scope:            '/',
        start_url:        '/m',
        // El logo REAL. Hasta acá el manifest apuntaba a `icons/*.svg`, que eran placeholders
        // generados en marzo por `icons/gen_icons.cjs`: un cuadrado verde con un emoji 🌿 como
        // texto. `index.html` ya usaba el logo bueno para el favicon y el apple-touch-icon, así
        // que la pestaña se veía bien y el ícono de la app instalada seguía siendo el provisorio
        // — que es justo el que se ve en el escritorio y en el cajón de aplicaciones.
        //
        // PNG y no SVG a propósito: Chrome de escritorio elige mal entre íconos SVG al instalar.
        //
        // Falta el `maskable` (Android le aplica una máscara y recorta): necesita el logo con
        // zona segura, o sea reencuadrado con margen sobre el fondo oscuro de marca. Sin esa
        // versión es mejor no declararlo que declarar uno que se vea cortado.
        icons: [
          { src: 'logo-ce-redondo.png', sizes: '500x500', type: 'image/png', purpose: 'any' },
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
