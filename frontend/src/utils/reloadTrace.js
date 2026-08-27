// Miga de pan: POR QUÉ se recargó sola la pantalla.
//
// Existe porque el síntoma no deja rastro. Hay cuatro caminos que hacen una navegación dura
// —el service worker nuevo tomando control (`main.js`), un 401 con la sesión vencida, un 403
// del módulo del rol apagado y el logout— y desde afuera los cuatro se ven igual: la app se
// refrescó y lo que estabas escribiendo no está. Para cuando alguien lo cuenta ya se recargó y
// no queda nada que mirar; esto sobrevive a la recarga.
//
// Se guardan las últimas 10 y no una sola: pasa cada muchas horas, así que el próximo evento
// pisaría al que interesa antes de que nadie lo lea.
//
// NO puede romper nada: todo va adentro de un try/catch. `localStorage` tira excepción en
// incógnito con cookies bloqueadas y cuando la cuota está llena, y esto corre justo antes de
// una navegación — si fallara, se llevaría puesta la recarga.

const CLAVE = 'ce_reload'
const MAX   = 10

export function anotarReload(motivo, extra = {}) {
  try {
    const previas = JSON.parse(localStorage.getItem(CLAVE) || '[]')
    const lista   = Array.isArray(previas) ? previas : []
    lista.unshift({
      motivo,
      ts:       new Date().toISOString(),
      pantalla: window.location.pathname + window.location.search,
      build:    typeof __APP_BUILD__ === 'string' ? __APP_BUILD__ : null,
      ...extra,
    })
    localStorage.setItem(CLAVE, JSON.stringify(lista.slice(0, MAX)))
  } catch { /* sin localStorage no hay miga, pero la navegación sigue */ }
}

// Para leerlas desde la consola: `window.ceReloads()`
export function leerReloads() {
  try { return JSON.parse(localStorage.getItem(CLAVE) || '[]') } catch { return [] }
}
