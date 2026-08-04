import { ref } from 'vue'
import { entregarPaquete, reportarFallo } from '../lib/api.js'

/**
 * Cola de entregas para cuando no hay señal.
 *
 * El repartidor entrega en un sótano, en un ascensor o en un barrio sin datos: el paciente firma,
 * el POST falla y la firma SE PIERDE. Volver a pedirla no es una opción —la persona ya se fue— y sin
 * ella no hay prueba de entrega.
 *
 * Así que la entrega se guarda primero en el dispositivo y se manda después. Al repartidor se le
 * confirma en el acto, porque para él la entrega YA OCURRIÓ: lo que falta es un detalle de red.
 *
 * Se reintenta al volver la conexión, al abrir la app y cada tanto. Nada se borra de la cola hasta
 * que el servidor lo confirma.
 */
const CLAVE = 'entregas_pendientes_v1'

const pendientes = ref(leer())
const sincronizando = ref(false)

function leer() {
  try { return JSON.parse(localStorage.getItem(CLAVE) || '[]') } catch { return [] }
}

function guardar(lista) {
  pendientes.value = lista
  try { localStorage.setItem(CLAVE, JSON.stringify(lista)) } catch {}
}

function encolar(item) {
  guardar([...pendientes.value, { ...item, id_local: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}` }])
}

/**
 * Entrega un paquete. Si la red falla, queda en cola y se reintenta solo.
 * Devuelve { ok, encolado } — `encolado: true` significa "guardado acá, todavía sin confirmar".
 */
export async function entregarConReintento(id, payload) {
  try {
    await entregarPaquete(id, payload)
    return { ok: true, encolado: false }
  } catch (e) {
    // Un 4xx es un rechazo del servidor (el paquete ya se entregó, no es tuyo, datos inválidos):
    // reintentarlo no lo va a arreglar y encolarlo escondería el error real.
    const status = e?.response?.status
    if (status && status >= 400 && status < 500) throw e

    encolar({ tipo: 'entrega', dispensacion_id: id, payload })
    return { ok: true, encolado: true }
  }
}

export async function fallaConReintento(id, motivo) {
  try {
    await reportarFallo(id, motivo)
    return { ok: true, encolado: false }
  } catch (e) {
    const status = e?.response?.status
    if (status && status >= 400 && status < 500) throw e

    encolar({ tipo: 'fallo', dispensacion_id: id, motivo })
    return { ok: true, encolado: true }
  }
}

/** Intenta mandar todo lo pendiente. Lo que sigue fallando por red se queda para la próxima. */
export async function sincronizar() {
  if (sincronizando.value || !pendientes.value.length) return
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return

  sincronizando.value = true
  const quedan = []
  for (const item of pendientes.value) {
    try {
      if (item.tipo === 'entrega') await entregarPaquete(item.dispensacion_id, item.payload)
      else                          await reportarFallo(item.dispensacion_id, item.motivo)
    } catch (e) {
      const status = e?.response?.status
      // Si el servidor lo rechaza, se descarta: reintentarlo para siempre dejaría la cola trabada.
      // Si es de red, se conserva.
      if (!status || status >= 500) quedan.push(item)
    }
  }
  guardar(quedan)
  sincronizando.value = false
}

let arrancado = false
export function useEntregasOffline() {
  if (!arrancado && typeof window !== 'undefined') {
    arrancado = true
    window.addEventListener('online', sincronizar)
    // Cada 30 s: `online` no siempre dispara al recuperar señal en un celular.
    setInterval(sincronizar, 30_000)
    sincronizar()
  }
  return { pendientes, sincronizando, entregarConReintento, fallaConReintento, sincronizar }
}
