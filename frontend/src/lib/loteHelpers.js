export const ESTADO_META = {
  semilla:            { label: 'Germinación',        color: '#64748b', bg: '#f1f5f9', emoji: '🌱' },
  esqueje:            { label: 'Esqueje',             color: '#0891b2', bg: '#e0f2fe', emoji: '🪴' },
  vegetativo:         { label: 'Vegetativo',          color: '#16a34a', bg: '#dcfce7', emoji: '🍃' },
  floracion:          { label: 'Floración',          color: '#d97706', bg: '#fef3c7', emoji: '🌸' },
  cosecha:            { label: 'Cosecha',            color: '#059669', bg: '#d1fae5', emoji: '🌿' },
  en_manicura:        { label: 'En manicura',        color: '#7c3aed', bg: '#ede9fe', emoji: '✂️'  },
  curado:             { label: 'Curado',             color: '#2563eb', bg: '#dbeafe', emoji: '🫙' },
  finalizado:         { label: 'Finalizado',         color: '#1b5e20', bg: '#dcfce7', emoji: '✅' },
}

export const PLANT_STATE_META = {
  semilla:    { label: 'Semilla',    color: '#64748b', emoji: '🌰' },
  germinacion:{ label: 'Germinación',color: '#16a34a', emoji: '🌱' },
  esqueje:    { label: 'Esqueje',    color: '#0891b2', emoji: '🌿' },
  vegetativo: { label: 'Vegetativo', color: '#16a34a', emoji: '🍃' },
  floracion:  { label: 'Floración',  color: '#d97706', emoji: '🌸' },
  cosechado:  { label: 'Cosechada',  color: '#2563eb', emoji: '✅' },
  descartada: { label: 'Descartada', color: '#dc2626', emoji: '❌' },
}

export const ESTADO_SALUD_META = {
  excelente: { color: '#16a34a', emoji: '🟢' },
  bueno:     { color: '#65a30d', emoji: '🟡' },
  regular:   { color: '#d97706', emoji: '🟠' },
  malo:      { color: '#dc2626', emoji: '🔴' },
  critico:   { color: '#991b1b', emoji: '🚨' },
}

export const PLAGAS_META = {
  ninguna:  { color: '#16a34a', emoji: '✅' },
  leve:     { color: '#d97706', emoji: '⚠️' },
  moderada: { color: '#ea580c', emoji: '🐛' },
  severa:   { color: '#dc2626', emoji: '🚨' },
}

export const MACETA_LABELS = {
  '0.5': 'Vaso (0.5L)', '1': '1 litro', '3': '3 litros', '5': '5 litros',
  '7': '7 litros', '10': '10 litros', '12': '12 litros', '15': '15 litros', 'otro': 'Otro',
}

export const TAREAS_LOTE = [
  { key: 'riego',                label: 'Riego',               emoji: '💧' },
  { key: 'nutricion',            label: 'Nutrición',           emoji: '🧪' },
  { key: 'poda',                 label: 'Poda',                emoji: '✂️'  },
  { key: 'defoliacion',          label: 'Defoliación',         emoji: '🍃' },
  { key: 'scrog_lst',            label: 'SCROG/LST',           emoji: '🪢' },
  { key: 'revision_plagas',      label: 'Revisión plagas',     emoji: '🔍' },
  { key: 'limpieza_sala',        label: 'Limpieza sala',       emoji: '🧹' },
  { key: 'ajuste_luz',           label: 'Ajuste de luz',       emoji: '💡' },
  { key: 'registro_ambiental',   label: 'Registro ambiental',  emoji: '🌡️' },
]

export const CICLO_BASE = ['vegetativo', 'floracion', 'cosecha', 'curado']

export const FASE_LABELS = {
  vegetativo: 'Vegetativo', floracion: 'Floración', curado: 'Curado', cosecha: 'Cosecha', semilla: 'Germinación',
  manicura: 'Manicura', cerrado: 'Cerrado',
}

export const STATE_MAP = {
  semilla: 'germinacion', esqueje: 'esqueje', vegetativo: 'vegetativo',
  floracion: 'floracion', cosecha: 'cosechado',
  curado: 'cosechado', finalizado: 'cosechado',
}

export const POST_HARVEST_ESTADOS = ['cosecha', 'en_manicura', 'curado', 'finalizado']

export function em(e)  { return ESTADO_META[e]       || { label: e || '—', color: '#64748b', bg: '#f1f5f9', emoji: '•' } }
export function pm(s)  { return PLANT_STATE_META[s]  || { label: s || '—', color: '#64748b', emoji: '🌿' } }
export function sm(s)  { return ESTADO_SALUD_META[s] || { color: '#94a3b8', emoji: '⚪' } }
export function pgm(p) { return PLAGAS_META[p]       || { color: '#94a3b8', emoji: '—' } }

export function growLabel(g)  { return { sustrato: 'Sustrato', hidroponia: 'Hidroponia', aeroponia: 'Aeroponia' }[g] || g || '—' }
export function lightLabel(l) { return { led: 'LED', hps: 'HPS', cmh: 'CMH', natural: 'Natural', mixta: 'Mixta' }[l] || l || '—' }
export function macetaLabel(m) {
  if (m == null || m === '') return '—'
  const key = String(parseFloat(m))   // "15.0" -> "15", "0.5" -> "0.5"
  return MACETA_LABELS[key] || `${m}L`
}

// Fotoperíodo (horas luz/oscuridad). Usa el valor cargado si existe; si no, lo
// deriva del estado: vegetativo/germinación/esqueje = 18/6, floración = 12/12.
export function fotoperiodoLabel(estado, stored) {
  if (stored) return stored
  if (['semilla', 'esqueje', 'vegetativo'].includes(estado)) return '18/6'
  if (estado === 'floracion') return '12/12'
  return '—'
}

export function parseDate(d) {
  if (!d) return null
  if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return new Date(d + 'T00:00:00')
  return new Date(d)
}

export function formatDate(d) {
  if (!d) return '—'
  const date = parseDate(d)
  return !date || isNaN(date.getTime()) ? '—' : date.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

export function formatDateTime(d) {
  if (!d) return '—'
  const date = parseDate(d)
  return !date || isNaN(date.getTime()) ? '—' : date.toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

export function capitalizarFase(f) { return FASE_LABELS[f] || (f ? f.charAt(0).toUpperCase() + f.slice(1) : '') }

export function phaseBannerMsg(estado) {
  if (estado === 'cosecha') return 'Lote cosechado. Manicura toma desde acá.'
  if (estado === 'semilla') return 'Plantas en germinación. El sistema avanzará automáticamente cuando estén listas.'
  if (estado === 'finalizado') return 'Lote finalizado. Stock confirmado y disponible para dispensar.'
  if (['en_manicura', 'manicura', 'curado', 'cerrado'].includes(estado)) return 'Este lote pasó tu turno. Otro rol toma desde acá.'
  return null
}
