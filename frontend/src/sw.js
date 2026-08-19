import { precacheAndRoute, cleanupOutdatedCaches, createHandlerBoundToURL } from 'workbox-precaching'
import { clientsClaim } from 'workbox-core'
import { registerRoute, NavigationRoute } from 'workbox-routing'
import { NetworkFirst } from 'workbox-strategies'
import { ExpirationPlugin } from 'workbox-expiration'
import { CacheableResponsePlugin } from 'workbox-cacheable-response'

// Modo "prompt": el SW nuevo queda en waiting hasta que el usuario acepte
// actualizar desde el banner (main.js le manda SKIP_WAITING). Si activara
// solo (skipWaiting incondicional), la página se recargaría en medio de
// un formulario.
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') self.skipWaiting()
})
clientsClaim()

// El MANIFEST de la PWA NO se precachea. Con `registerType: 'prompt'` el service worker nuevo queda
// esperando a que el usuario acepte actualizar, así que el viejo sigue sirviendo lo que tiene
// guardado —incluido el manifest—. Consecuencia: se cambia el nombre de la app, se deploya, y
// Chrome sigue proponiendo el anterior al instalar, a veces por días. Dejándolo afuera, el
// navegador siempre lo pide a la red y el nombre cambia en el mismo deploy.
precacheAndRoute(self.__WB_MANIFEST.filter((e) => !/manifest\.webmanifest$/.test(e.url)))
cleanupOutdatedCaches()

// ── Navegación: el shell sale del caché ───────────────────────────────────────
//
// Sin esto la PWA instalada NO ABRÍA sin internet. El motivo: `precacheAndRoute` guarda
// `index.html`, pero una navegación a /m, /lotes o /mnc/pendientes no matchea esa entrada —
// workbox prueba `/m.html` y `/m/index.html`, que no existen— así que salía a la red y moría en la
// pantalla de error del navegador. Y `start_url` del manifest es `/m`: abrir la app instalada sin
// señal mostraba el dinosaurio de Chrome, ni siquiera la app diciendo que no hay conexión.
//
// En producción esto lo resuelve el servidor (`get '*path' => spa_fallback` en routes.rb). Offline
// no hay servidor, y es justamente cuando hace falta.
//
// El denylist son las rutas que NO sirve la SPA: la API, los adjuntos de ActiveStorage —abrir un
// PDF de prescripción es una navegación—, el panel de Sidekiq, el cable y el health check. Sin
// excluirlas, offline se les devolvería el HTML de la app en vez de fallar, que es peor: parece
// que anduvo.
registerRoute(new NavigationRoute(createHandlerBoundToURL('index.html'), {
  denylist: [/^\/api\//, /^\/rails\//, /^\/sidekiq/, /^\/cable/, /^\/up$/],
}))

// Network-first para la API.
// VITE_API_URL puede ser absoluta (https://api…) o relativa (/api, mismo origen).
// Si es relativa, new URL() tiraría error → API_ORIGIN null y matcheamos por pathname.
const API_ORIGIN = (() => {
  const v = import.meta.env.VITE_API_URL
  if (!v) return null
  try { return new URL(v).origin } catch { return null }
})()

// Endpoints sensibles a la sesión: NUNCA se cachean. Si /me se sirviera del
// caché, tras un logout el SW devolvería el usuario viejo y parecería que la
// sesión sigue abierta (pasaba en mobile/PWA, donde la red lenta hace que
// NetworkFirst caiga al caché). Estos van siempre a la red.
const AUTH_BYPASS = ['/me', '/users/sign_in', '/users/sign_out', '/users/sign_up']

registerRoute(
  ({ url, request }) => {
    if (request.method !== 'GET') return false
    const isApi = API_ORIGIN ? url.origin === API_ORIGIN : url.pathname.startsWith('/api/')
    if (!isApi) return false
    if (AUTH_BYPASS.some(p => url.pathname.endsWith(p))) return false
    return true
  },
  new NetworkFirst({
    cacheName: 'api-cache',
    plugins: [
      new ExpirationPlugin({ maxEntries: 100, maxAgeSeconds: 60 * 60 * 24 }),
      new CacheableResponsePlugin({ statuses: [0, 200] }),
    ],
    networkTimeoutSeconds: 10,
  })
)

// ── Push notifications ────────────────────────────────────────
self.addEventListener('push', (event) => {
  if (!event.data) return

  let data
  try { data = event.data.json() } catch { return }

  event.waitUntil(
    self.registration.showNotification(data.title || 'Cultivo Espacial', {
      body:    data.body  || '',
      icon:    '/logo-ce-redondo.png',
      badge:   '/logo-ce-redondo.png',
      data:    { url: data.url || '/' },
      vibrate: [100, 50, 100],
      tag:     data.tag || 'ce-notif',
    })
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = event.notification.data?.url || '/'

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((windowClients) => {
        const match = windowClients.find(c => c.focused || c.url.includes(url))
        if (match) return match.focus()
        return clients.openWindow(url)
      })
  )
})
