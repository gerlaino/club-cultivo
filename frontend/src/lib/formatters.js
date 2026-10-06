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
  preroll:    'Preroll',
  externo:    'Externo',
  otro:       'Otro',
}

export function formaLabel(f) {
  return FORMA_LABELS[f] || f || '—'
}

// En qué se cuenta cada forma de producto. Un preroll o una cápsula se cuentan por UNIDAD; un
// aceite o una tintura, en mililitros. El alta de stock mandaba siempre `g`, así que crear 100
// prerolls dejaba "100 g de preroll" — la lista tenía la opción y el registro salía inservible.
const UNIDAD_POR_FORMA = {
  preroll:    'un',
  capsula:    'un',
  capsulas:   'un',
  comestible: 'un',
  aceite:     'ml',
  tintura:    'ml',
}

export function unidadDe(forma) {
  return UNIDAD_POR_FORMA[forma] || 'g'
}

export function formatARS(n) {
  if (n == null) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
}

// Un precio de la lista de la plataforma (`Precios` en el backend). La moneda la dice el backend
// (`moneda` en el catálogo y en el desglose): desde el 6-oct-2026 la lista está en dólares.
export function formatPrecio(n, moneda = 'USD') {
  if (n == null) return '—'
  const num = new Intl.NumberFormat('es-AR', { maximumFractionDigits: 0 }).format(n)
  return moneda === 'USD' ? `US$ ${num}` : new Intl.NumberFormat('es-AR', { style: 'currency', currency: moneda, maximumFractionDigits: 0 }).format(n)
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
