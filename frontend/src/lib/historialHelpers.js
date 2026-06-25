// Helpers compartidos del historial unificado del lote (sección inline + modal).

// Categorías de "Registrar actividad". El trasplante está acá (entrada unificada),
// pero internamente se guarda por planta + maceta vía el endpoint de trasplante.
export const CATEGORIAS = [
  { value: 'riego',         label: 'Riego',         emoji: '💧' },
  { value: 'fertilizacion', label: 'Fertilización', emoji: '🌿' },
  { value: 'poda',          label: 'Poda',          emoji: '✂️' },
  { value: 'defoliacion',   label: 'Defoliación',   emoji: '🍃' },
  { value: 'tratamiento',   label: 'Tratamiento',   emoji: '🧪' },
  { value: 'medicion',      label: 'Medición',      emoji: '📏' },
  { value: 'inspeccion',    label: 'Inspección',    emoji: '🔍' },
  { value: 'trasplante',    label: 'Trasplante',    emoji: '🪴' },
  { value: 'nota',          label: 'Nota',          emoji: '📝' },
  { value: 'otro',          label: 'Otro',          emoji: '•' },
]

// Tipos del historial unificado para los filtros del modal.
export const KINDS = [
  { value: 'fase',         label: 'Cambios de fase' },
  { value: 'actividad',    label: 'Actividades' },
  { value: 'registro',     label: 'Registros del lote' },
  { value: 'tarea',        label: 'Tareas' },
  { value: 'pesada',       label: 'Pesadas' },
  { value: 'stock',        label: 'Stocks' },
  { value: 'dispensacion', label: 'Dispensaciones' },
  { value: 'nota',         label: 'Notas' },
  { value: 'alerta',       label: 'Alertas' },
]

const CAT_COLOR = {
  riego: '#0891b2', fertilizacion: '#16a34a', poda: '#d97706', defoliacion: '#65a30d',
  tratamiento: '#9333ea', medicion: '#0ea5e9', inspeccion: '#64748b', trasplante: '#92400e',
  nota: '#64748b', otro: '#94a3b8',
}
const KIND_COLOR = {
  fase: '#1b5e20', registro: '#0891b2', tarea: '#16a34a', pesada: '#7c3aed',
  stock: '#0ea5e9', dispensacion: '#db2777', nota: '#64748b', alerta: '#dc2626',
}

export function dotColor(it) {
  if (it.kind === 'actividad') return CAT_COLOR[it.categoria] || '#64748b'
  return KIND_COLOR[it.kind] || '#64748b'
}

// Detalle compacto desde metadata (EC, volumen, producto).
export function metaDetalle(it) {
  const m = it.metadata || {}
  const parts = []
  if (m.producto)  parts.push(m.producto)
  if (m.ec != null)        parts.push(`EC ${m.ec}`)
  if (m.volumen_l != null) parts.push(`${m.volumen_l}L`)
  if (m.maceta_origen_l != null && m.maceta_destino_l != null) parts.push(`${m.maceta_origen_l ?? '?'}L → ${m.maceta_destino_l}L`)
  else if (m.maceta_destino_l != null) parts.push(`a ${m.maceta_destino_l}L`)
  if (m.plantas != null) parts.push(`${m.plantas} plantas`)
  return parts.join(' · ')
}

export function placeholderFor(categoria) {
  return {
    riego: 'Detalle (opcional)', fertilizacion: 'Detalle (opcional)',
    poda: '¿Qué podaste? (opcional)', defoliacion: 'Detalle (opcional)',
    tratamiento: 'Producto / plaga tratada', medicion: '¿Qué mediste?',
    inspeccion: 'Observaciones', nota: '¿Qué pasó?', otro: 'Describí la actividad',
  }[categoria] || 'Detalle'
}
