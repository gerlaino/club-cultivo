import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching'
import { clientsClaim } from 'workbox-core'
import { registerRoute } from 'workbox-routing'
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

precacheAndRoute(self.__WB_MANIFEST)
cleanupOutdatedCaches()

// Network-first para la API.
// VITE_API_URL puede ser absoluta (https://api…) o relativa (/api, mismo origen).
// Si es relativa, new URL() tiraría error → API_ORIGIN null y matcheamos por pathname.
const API_ORIGIN = (() => {
  const v = import.meta.env.VITE_API_URL
  if (!v) return null
  try { return new URL(v).origin } catch { return null }
})()

registerRoute(
  ({ url, request }) => {
    if (request.method !== 'GET') return false
    return API_ORIGIN
      ? url.origin === API_ORIGIN
      : url.pathname.startsWith('/api/')
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
