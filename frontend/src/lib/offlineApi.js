/**
 * Capa de API con soporte offline para dispensaciones y lecturas ambientales.
 * Si la request falla por red (sin response del servidor), encola para sync posterior.
 * Si falla por validación (response 4xx), relanza el error normalmente.
 */
import { useSyncQueueStore } from '../stores/syncQueue.js'
import { createDispensacion, createRegistroAmbiental, createLecturaAmbiental } from './api.js'

// ── Cache local (localStorage) ─────────────────────────────
const CACHE_KEYS = {
  stock:   'cc_cache_stock',
  socios:  'cc_cache_socios',
  salas:   'cc_cache_salas',
}

function guardarCache(key, data) {
  try { localStorage.setItem(key, JSON.stringify({ data, ts: Date.now() })) } catch {}
}
function leerCache(key, maxAgeMs = 24 * 60 * 60 * 1000) {
  try {
    const raw = JSON.parse(localStorage.getItem(key))
    if (!raw) return null
    if (Date.now() - raw.ts > maxAgeMs) return null
    return raw.data
  } catch { return null }
}

export const cacheStock  = (data) => guardarCache(CACHE_KEYS.stock,  data)
export const cacheSocios = (data) => guardarCache(CACHE_KEYS.socios, data)
export const cacheSalas  = (data) => guardarCache(CACHE_KEYS.salas,  data)

export const getCachedStock  = () => leerCache(CACHE_KEYS.stock)
export const getCachedSocios = () => leerCache(CACHE_KEYS.socios)
export const getCachedSalas  = () => leerCache(CACHE_KEYS.salas)

// ── Helpers ────────────────────────────────────────────────
function esErrorDeRed(e) {
  // axios: si no hay response, es error de red (timeout, sin conexión, CORS)
  return !e.response
}

// ── Dispensación offline-aware ─────────────────────────────
export async function dispensarOffline(pacienteId, payload) {
  try {
    return await createDispensacion(pacienteId, payload)
  } catch (e) {
    if (esErrorDeRed(e)) {
      const queue = useSyncQueueStore()
      queue.encolar('dispensacion', {
        url:     `/api/pacientes/${pacienteId}/dispensaciones`,
        method:  'POST',
        payload: { dispensacion: payload },
      })
      // Decrementar el stock en caché local para que la UI refleje la dispensación pendiente
      _decrementarStockCache(payload.stock_id, payload.cantidad)
      return { offline: true, queued: true }
    }
    throw e
  }
}

function _decrementarStockCache(stockId, cantidad) {
  try {
    const raw = JSON.parse(localStorage.getItem(CACHE_KEYS.stock))
    if (!raw?.data) return
    const stock = raw.data.find(s => s.id === stockId)
    if (stock) stock.cantidad = Math.max(0, (stock.cantidad || 0) - (cantidad || 0))
    localStorage.setItem(CACHE_KEYS.stock, JSON.stringify(raw))
  } catch {}
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
        queue.encolar('registro_ambiental', {
          url:     `/api/lotes/${loteId}/registros_ambientales`,
          method:  'POST',
          payload: { registro_ambiental: payload },
        })
      } else {
        queue.encolar('lectura_ambiental', {
          url:     `/api/salas/${salaId}/lecturas_ambientales`,
          method:  'POST',
          payload: { lectura_ambiental: { tipo, valor, unidad, medido_at, fuente: 'manual' } },
        })
      }
      return { offline: true, queued: true }
    }
    throw e
  }
}
