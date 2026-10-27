// Sentry en el navegador: qué error le saltó a quién en qué pantalla, con el detalle para arreglarlo.
//
// Queda APAGADO si el build no trae VITE_SENTRY_DSN: desarrollo, tests y cualquier build sin la
// variable no mandan nada y ni siquiera bajan la librería (se importa recién si hay DSN). En Render
// el DSN lo pasa `bin/render-build.sh` desde SENTRY_DSN_FRONTEND, o desde SENTRY_DSN si no hay uno
// propio del front: con cargar SENTRY_DSN una vez quedan los dos lados (ver docs/INFRA.md).
//
// Datos de salud: NUNCA se manda nada de la persona. Mismo criterio que
// `backend/config/initializers/sentry.rb`: sin `sendDefaultPii`, sin grabación de pantalla, y lo que
// identifica (DNI, mails, la parte `?…` de las direcciones, lo que se escribió en la consola) se
// borra antes de salir.

const DNI = /\b\d{1,2}\.?\d{3}\.?\d{3}\b/g
const MAIL = /[^\s@"'<>]+@[^\s@"'<>]+\.[a-z]{2,}/gi

// Las direcciones viajan sin `?…` ni `#…`: un buscador por DNI o por nombre deja ahí lo que se buscó.
export function sinConsulta(url) {
  if (typeof url !== 'string') return url
  return url.replace(/[?#].*$/, '')
}

export function sinDatosPersonales(texto) {
  if (typeof texto !== 'string') return texto
  return texto.replace(MAIL, '[mail]').replace(DNI, '[número]')
}

export function limpiarMiga(miga) {
  // Lo que se imprimió en la consola puede ser cualquier objeto de la API: no sale.
  if (miga.category === 'console') return null
  if (miga.data) {
    for (const k of ['url', 'from', 'to']) if (miga.data[k]) miga.data[k] = sinConsulta(miga.data[k])
  }
  if (miga.message) miga.message = sinDatosPersonales(miga.message)
  return miga
}

export function limpiarEvento(evento) {
  delete evento.user
  if (evento.request) {
    evento.request.url = sinConsulta(evento.request.url)
    delete evento.request.query_string
    delete evento.request.cookies
    delete evento.request.data
    // El navegador agrega `Referer` con la dirección de antes, consulta incluida.
    if (evento.request.headers) {
      for (const h of Object.keys(evento.request.headers)) if (/^referer$/i.test(h)) delete evento.request.headers[h]
    }
  }
  // Las mediciones de rendimiento traen la dirección de cada pedido en sus tramos.
  for (const tramo of evento.spans || []) {
    if (!tramo.data) continue
    for (const k of ['url', 'http.url', 'url.full', 'http.query']) {
      if (typeof tramo.data[k] === 'string') tramo.data[k] = k === 'http.query' ? undefined : sinConsulta(tramo.data[k])
    }
    if (tramo.description) tramo.description = sinConsulta(tramo.description)
  }
  if (evento.message) evento.message = sinDatosPersonales(evento.message)
  for (const ex of evento.exception?.values || []) ex.value = sinDatosPersonales(ex.value)
  for (const m of evento.breadcrumbs || []) limpiarMiga(m)
  evento.breadcrumbs = (evento.breadcrumbs || []).filter(m => m.category !== 'console')
  return evento
}

export function iniciarSentry(app, router, env = import.meta.env) {
  const dsn = env.VITE_SENTRY_DSN
  if (!dsn) return Promise.resolve(false)
  return import('@sentry/vue').then((Sentry) => {
    Sentry.init({
      app,
      dsn,
      environment: env.VITE_SENTRY_ENVIRONMENT || env.MODE,
      release: env.VITE_SENTRY_RELEASE || undefined,
      sendDefaultPii: false,
      // Las pantallas se nombran por la ruta («/socios/:id»), no por la dirección con el número.
      integrations: [Sentry.browserTracingIntegration({ router })],
      tracesSampleRate: Number(env.VITE_SENTRY_TRACES_SAMPLE_RATE || 0.1),
      // Extensiones del navegador y el «unload» que meten algunas: no son nuestros errores.
      denyUrls: [/^chrome-extension:\/\//, /^moz-extension:\/\//, /^safari-web-extension:\/\//],
      beforeBreadcrumb: limpiarMiga,
      beforeSend: limpiarEvento,
      beforeSendTransaction: limpiarEvento,
    })
    return true
  }).catch(() => false)
}
