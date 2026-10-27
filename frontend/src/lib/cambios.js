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

// Qué canal se escucha: el de la organización (`ClubChannel`) o, para el paciente, el suyo
// (`PacienteChannel`, 27-oct-2026): el de la organización le contaba lo que hacía el equipo.
let canal = 'ClubChannel'
export function usarCanal(nombre) { canal = nombre }

const handlers = new Map()   // recurso → Set<fn>
const recargas = new Set()   // las recargas de `alCambiarAgrupado`: lo que se re-pide al volver
let subscription = null
let ultimoEvento = null
let conecto = false
let ocultaDesde = null

// LO QUE PASÓ MIENTRAS NO ESCUCHABA (16-oct-2026, Javi: «devolví el pesaje y no actualizó en
// manicura»). En el teléfono, con la pantalla apagada o la app atrás, el WebSocket se corta; los
// avisos de ese rato no llegan nunca y la pantalla queda con lo viejo hasta recargar a mano. Al
// reconectar, o al volver a la app después de un rato, cada pantalla abierta re-pide lo suyo.
const VOLVER_TRAS_MS = 3000
const RESINCRONIZAR = { recurso: '*', accion: 'resincronizar' }

export function resincronizar() {
  ultimoEvento = RESINCRONIZAR
  for (const correr of [...recargas]) {
    try { correr() } catch (e) { console.warn('[cambios] resincronizar', e) }
  }
}

function alVolverALaApp() {
  if (document.visibilityState === 'hidden') { ocultaDesde = Date.now(); return }
  if (ocultaDesde && Date.now() - ocultaDesde >= VOLVER_TRAS_MS) resincronizar()
  ocultaDesde = null
}

function asegurarSuscripcion() {
  if (subscription) return
  try {
    subscription = consumidorCable().subscriptions.create(canal, {
      // La primera conexión no: la pantalla recién cargó. Las siguientes son un corte que terminó.
      connected() {
        if (conecto) resincronizar()
        conecto = true
      },
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
  if (typeof document !== 'undefined') document.addEventListener('visibilitychange', alVolverALaApp)
}

// Le avisa algo al backend por el mismo canal (hoy: «está escribiendo» en el chat).
export function avisarAlCanal(accion, datos = {}) {
  asegurarSuscripcion()
  try { subscription?.perform(accion, datos) } catch { /* sin cable: no es grave, es un aviso */ }
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
  const soltar = alCambiar(recursos, (evento) => {
    if (filtro && !filtro(evento)) return
    clearTimeout(timer)
    timer = setTimeout(correr, espera)
  })
  recargas.add(correr)
  return () => { soltar(); recargas.delete(correr); clearTimeout(timer) }
}

// Al cerrar sesión: nada de lo anotado vale para el próximo usuario.
export function olvidarCambios() {
  handlers.clear()
  recargas.clear()
  try { subscription?.unsubscribe() } catch {}
  subscription = null
  conecto = false
  ocultaDesde = null
  if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', alVolverALaApp)
}

// Para tests.
export const _interno = { handlers, recargas, get subscription() { return subscription } }
