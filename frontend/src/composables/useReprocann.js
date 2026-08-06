// Fuente única de la clasificación REPROCANN en el frontend.
//
// Espeja `Paciente.reprocann_categoria` del backend (app/models/paciente.rb). La regla que
// se repetía mal en cinco vistas: **el ESTADO manda sobre la fecha**. Un trámite pendiente
// de aprobación todavía no tiene certificado, así que no tiene número ni vencimiento; si se
// pregunta primero por la fecha, un pendiente cae en "sin REPROCANN", que es justo lo contrario
// de lo que pasa (hay trámite en curso).

export function safeDate(d) {
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}

export function reprocannDias(p) {
  if (!p?.reprocann_vencimiento) return null
  return Math.floor((safeDate(p.reprocann_vencimiento) - new Date()) / 86400000)
}

// Las cinco categorías son mutuamente excluyentes y cubren todos los casos, así los
// contadores de los filtros suman el total.
export function reprocannCategoria(p) {
  const estado = p?.reprocann_estado_efectivo || p?.reprocann_estado
  if (estado === 'pendiente') return 'pendiente'
  if (!p?.reprocann_numero)   return 'sin_reprocann'
  const d = reprocannDias(p)
  if (d === null) return 'vigente' // certificado sin fecha cargada: existe igual
  if (d < 0)  return 'vencido'
  if (d <= 30) return 'por_vencer'
  return 'vigente'
}

const BADGES = {
  pendiente:     { label: 'En trámite', level: 'caution' },
  sin_reprocann: null,                  // sin nada que informar: la vista muestra "—"
  vencido:       { label: 'Vencido',    level: 'danger'  },
  por_vencer:    { label: null,         level: 'warning' }, // el label son los días restantes
  vigente:       { label: 'Vigente',    level: 'ok'      },
}

// Badge corto para listados.
export function reprocannBadge(p) {
  const cat  = reprocannCategoria(p)
  const days = reprocannDias(p)
  const base = BADGES[cat]
  if (!base) return null
  if (cat === 'por_vencer') return { label: `${days}d`, level: 'warning', days, cat }
  if (cat === 'vigente' && days !== null && days <= 90) {
    return { label: `${days}d`, level: 'caution', days, cat }
  }
  return { ...base, days, cat }
}
