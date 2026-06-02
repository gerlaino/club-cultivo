const FORMA_LABELS = {
  flor_seca:  'Flor seca',
  hash:       'Hash',
  aceite:     'Aceite',
  tintura:    'Tintura',
  crema:      'Crema',
  capsula:    'Cápsulas',
  capsulas:   'Cápsulas',
  comestible: 'Comestible',
  prensado:   'Prensado',
  externo:    'Externo',
  otro:       'Otro',
}

export function formaLabel(f) {
  return FORMA_LABELS[f] || f || '—'
}

export function formatARS(n) {
  if (n == null) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
}

export function formatG(g) {
  if (g == null) return '—'
  return `${Number(g).toLocaleString('es-AR', { maximumFractionDigits: 1 })} g`
}

// conAño=true incluye el año, false solo día y mes
export function formatFecha(d, conAño = true) {
  if (!d) return '—'
  // Anclar a medianoche local para evitar shifts de timezone en strings de solo fecha
  const str = /^\d{4}-\d{2}-\d{2}$/.test(d) ? d + 'T00:00:00' : d
  const opts = { day: 'numeric', month: 'short' }
  if (conAño) opts.year = 'numeric'
  return new Date(str).toLocaleDateString('es-AR', opts)
}
