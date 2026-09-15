// Las líneas de una reserva, para cualquier pantalla que la muestre.
//
// Desde el 15-sep-2026 una reserva tiene carrito (`items`), como la dispensa. Las de antes
// llegan sin `items` —o con uno solo, que el backfill les armó— y la fila sigue diciendo lo
// que siempre dijo (`stock` + `cantidad`): acá se resuelve una sola vez, así ninguna vista
// vuelve a preguntarse cuál de los dos lados mirar.
import { formaLabel } from './formatters.js'

export function lineasDe(r) {
  if (!r) return []
  if (Array.isArray(r.items) && r.items.length) return r.items
  return [{
    id:             r.id,
    stock_id:       r.stock?.id ?? r.stock_id ?? null,
    cantidad:       r.cantidad,
    unidad:         r.stock?.unidad,
    forma_producto: r.stock?.forma_producto,
    genetica:       r.stock?.genetica,
    lote:           r.stock?.lote,
  }]
}

// «5g Critical Kush» — cuánto y de qué, que es con lo que se va a buscar el frasco. Sin
// variedad, la forma («5g Flor seca»).
export function textoLinea(ln) {
  const que = ln.genetica || formaLabel(ln.forma_producto) || '—'
  return `${ln.cantidad}${ln.unidad || 'g'} ${que}`
}

// Todas las líneas en un renglón: «5g Critical Kush · 2u OG Kush».
export function resumenLineas(r) {
  return lineasDe(r).map(textoLinea).join(' · ')
}
