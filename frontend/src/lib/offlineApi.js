/**
 * Escrituras que sobreviven a quedarse sin señal.
 *
 * No todo entra acá, y la lista es una decisión de DOMINIO, no de implementación:
 *
 *   SÍ  · Registro de ambiente (lectura de sala o de lote). No mueve stock ni plata: si se duplica
 *         o llega tarde, es un dato más en una serie temporal.
 *   SÍ  · Pesaje del manicura enviado a confirmar. Está parado frente a la balanza y ya pesó;
 *         perder el número significa volver a pesar todo. **No genera stock**: queda esperando que
 *         el admin lo confirme, y esa confirmación es la red que atrapa cualquier duplicado.
 *   NO  · Dispensar. Descontaba stock contra una caché local que puede estar vieja, así que dos
 *         dispensadores sin señal entregaban el mismo gramo y el sobregiro aparecía recién al
 *         reconectar. Sin conexión no se dispensa: se avisa y se espera.
 *   NO  · `registrar_directo` del manicura (el atajo de admin/supervisor), que sí genera stock en
 *         el acto. Mismo motivo que dispensar.
 *
 * Las entregas del repartidor tienen su propia cola aparte (`useEntregasOffline`): ahí lo que se
 * pierde es la FIRMA del paciente, que no se puede volver a pedir porque la persona ya se fue.
 */
import { useSyncQueueStore } from '../stores/syncQueue.js'
import { createRegistroAmbiental, createLecturaAmbiental, createPesajeManicura } from './api.js'

// ── Helpers ────────────────────────────────────────────────
function esErrorDeRed(e) {
  // axios: si no hay response, es error de red (timeout, sin conexión, CORS)
  return !e.response
}

/**
 * OJO con la URL que se encola: va SIN el prefijo `/api`.
 *
 * La instancia de axios ya lo trae en `baseURL`, así que guardarla como `/api/lotes/...` hacía que
 * el reintento pegara a `/api/api/lotes/...` y volviera 404. Y un 404 tiene `response`, así que la
 * cola lo tomaba como error de validación y lo marcaba FALLIDO en vez de reintentarlo: lo que se
 * guardaba sin señal no llegaba nunca, y el usuario sólo veía "no pudo sincronizarse".
 */
function encolar(queue, tipo, { url, method = 'POST', payload }) {
  if (url.startsWith('/api/')) throw new Error(`offlineApi: la URL encolada no lleva /api (${url})`)
  queue.encolar(tipo, { url, method, payload })
}

// ── Lectura ambiental offline-aware ───────────────────────
// loteId + payload → createRegistroAmbiental (registro completo)
// salaId + tipo/valor/unidad → createLecturaAmbiental (lectura individual)
export async function registrarLecturaOffline({ salaId, loteId, payload, tipo, valor, unidad, medido_at }) {
  try {
    if (loteId) {
      return await createRegistroAmbiental(loteId, payload)
    } else {
      return await createLecturaAmbiental(salaId, { tipo, valor, unidad, medido_at, fuente: 'manual' })
    }
  } catch (e) {
    if (esErrorDeRed(e)) {
      const queue = useSyncQueueStore()
      if (loteId) {
        encolar(queue, 'registro_ambiental', {
          url:     `/lotes/${loteId}/registros_ambientales`,
          payload: { registro_ambiental: payload },
        })
      } else {
        encolar(queue, 'lectura_ambiental', {
          url:     `/salas/${salaId}/lecturas_ambientales`,
          payload: { lectura_ambiental: { tipo, valor, unidad, medido_at, fuente: 'manual' } },
        })
      }
      return { offline: true, queued: true }
    }
    throw e
  }
}

// ── Pesaje del manicura offline-aware ─────────────────────
/**
 * El pesaje que la manicura manda a confirmar. Es el caso más parecido al del repartidor: está
 * frente a la balanza, ya pesó, y sin cola el número se pierde —el modal no se cierra al fallar,
 * así que lo único que lo salvaba era no tocar nada hasta recuperar la señal—.
 *
 * `force_new: true` en el reintento, a propósito: si al reconectar hay otra jornada enviada sin
 * confirmar, el backend contesta 409 `needs_choice` para que el front pregunte "¿seguir la anterior
 * o empezar una nueva?". Esa pregunta no se le puede hacer a nadie desde una cola que corre sola, y
 * un 409 la marcaría FALLIDA y perdería el pesaje. Abrir una jornada nueva es la salida sin
 * pérdida: el admin confirma dos en vez de una.
 */
export async function registrarPesajeManicuraOffline(loteId, payload) {
  try {
    return await createPesajeManicura(loteId, payload)
  } catch (e) {
    if (esErrorDeRed(e)) {
      const queue = useSyncQueueStore()
      encolar(queue, 'pesaje_manicura', {
        url:     `/lotes/${loteId}/pesajes_manicura`,
        payload: { ...payload, force_new: true },
      })
      return { offline: true, queued: true }
    }
    throw e
  }
}
