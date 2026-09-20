// «Algo cambió en tu organización» — el lado que escucha.
//
// El backend avisa por `ClubChannel` cada vez que un registro de dominio se guarda o se borra
// (`Transmite`): `{ recurso, accion, id, sede_id, por, at }`. Acá hay UNA suscripción por
// pestaña y un registro de handlers por recurso: cada store se anota por lo suyo y re-pide lo
// que muestra; cada pantalla que pide directo a la API se anota con `useRecargaEnCambios`.
//
// Por qué re-pedir y no parchear con lo que viene en el aviso: lo que ve cada pantalla lo
// serializa el backend para ESA persona (tenant, permisos, campos calculados). Un payload
// armado a mano en el modelo se desactualiza a la segunda pantalla que lo lea distinto — es
// lo que pasó con los cuatro canales anteriores.
import { consumidorCable } from './cableConsumer.js'

const handlers = new Map()   // recurso → Set<fn>
let subscription = null
let ultimoEvento = null

function asegurarSuscripcion() {
  if (subscription) return
  try {
    subscription = consumidorCable().subscriptions.create('ClubChannel', {
      received(evento) {
        ultimoEvento = evento
        const lista = handlers.get(evento?.recurso)
        if (!lista) return
        for (const fn of [...lista]) {
          try { fn(evento) } catch (e) { console.warn('[cambios]', evento.recurso, e) }
        }
      },
    })
  } catch (e) {
    console.warn('[cambios] WebSocket no disponible', e?.message)
  }
}

// Anota un handler para uno o varios recursos. Devuelve la función para desanotarse.
export function alCambiar(recursos, fn) {
  const lista = Array.isArray(recursos) ? recursos : [recursos]
  for (const r of lista) {
    if (!handlers.has(r)) handlers.set(r, new Set())
    handlers.get(r).add(fn)
  }
  asegurarSuscripcion()
  return () => { for (const r of lista) handlers.get(r)?.delete(fn) }
}

// Lo mismo, pero agrupando: una tanda de cambios (una dispensa que toca cinco frascos) dispara
// UNA recarga, y nunca mientras la anterior está en vuelo — se encola una sola detrás.
export function alCambiarAgrupado(recursos, recargar, { espera = 300, filtro = null } = {}) {
  let timer = null
  let enVuelo = false
  let pendiente = false
  const correr = async () => {
    if (enVuelo) { pendiente = true; return }
    enVuelo = true
    try { await recargar(ultimoEvento) } catch {} finally {
      enVuelo = false
      if (pendiente) { pendiente = false; correr() }
    }
  }
  return alCambiar(recursos, (evento) => {
    if (filtro && !filtro(evento)) return
    clearTimeout(timer)
    timer = setTimeout(correr, espera)
  })
}

// Al cerrar sesión: nada de lo anotado vale para el próximo usuario.
export function olvidarCambios() {
  handlers.clear()
  try { subscription?.unsubscribe() } catch {}
  subscription = null
}

// Para tests.
export const _interno = { handlers, get subscription() { return subscription } }
