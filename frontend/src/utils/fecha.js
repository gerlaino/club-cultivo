/**
 * Helpers de fecha para formato argentino DD/MM/AAAA.
 * El backend SIEMPRE recibe/devuelve ISO (YYYY-MM-DD).
 * Estos helpers solo son para presentación visual.
 */

function parseDate(d) {
  if (!d) return null
  if (d instanceof Date) return isNaN(d.getTime()) ? null : d
  // ISO date string (YYYY-MM-DD) → avoid timezone shift
  if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return new Date(d + 'T00:00:00')
  const parsed = new Date(d)
  return isNaN(parsed.getTime()) ? null : parsed
}

/** DD/MM/AAAA  → "02/05/2026" */
export function formatFecha(d) {
  const date = parseDate(d)
  if (!date) return '—'
  return date.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

/** Corta para chips  → "2 may" */
export function formatFechaCorta(d) {
  const date = parseDate(d)
  if (!date) return '—'
  return date.toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}

/** Larga para títulos → "2 de mayo de 2026" */
export function formatFechaLarga(d) {
  const date = parseDate(d)
  if (!date) return '—'
  return date.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

/** Hoy como ISO YYYY-MM-DD */
export function hoyISO() {
  return new Date().toISOString().slice(0, 10)
}
