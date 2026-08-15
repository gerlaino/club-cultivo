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

/**
 * Cuánto falta, dicho como lo diría una persona: "2 años y 7 meses", "3 meses y 12 días",
 * "12 días". Antes se mostraba el total de días —"947 días restantes"— y nadie sabe cuánto es
 * eso sin hacer la cuenta.
 *
 * Se calcula con el CALENDARIO, no dividiendo días por 30: los meses no miden lo mismo, y un
 * vencimiento que cae el mismo día de otro mes tiene que decir "3 meses justos", no "3 meses
 * y 2 días".
 */
export function desglosarPlazo(desde, hasta) {
  let anios = hasta.getFullYear() - desde.getFullYear()
  let meses = hasta.getMonth() - desde.getMonth()
  let dias  = hasta.getDate() - desde.getDate()

  if (dias < 0) {
    // Pedirle días prestados al mes anterior al vencimiento (que es el que se está cursando).
    meses -= 1
    dias += new Date(hasta.getFullYear(), hasta.getMonth(), 0).getDate()
  }
  if (meses < 0) { anios -= 1; meses += 12 }

  return { anios, meses, dias }
}

/** "2 años y 7 meses" · "3 meses y 12 días" · "12 días" · "hoy". Omite lo que sea cero. */
export function formatearPlazo(desde, hasta) {
  const { anios, meses, dias } = desglosarPlazo(desde, hasta)
  const partes = []
  if (anios > 0) partes.push(`${anios} ${anios === 1 ? 'año' : 'años'}`)
  if (meses > 0) partes.push(`${meses} ${meses === 1 ? 'mes' : 'meses'}`)
  // Los días se omiten cuando ya hay años: "2 años, 7 meses y 3 días" es más ruido que dato.
  if (dias > 0 && anios === 0) partes.push(`${dias} ${dias === 1 ? 'día' : 'días'}`)

  if (!partes.length) return 'hoy'
  if (partes.length === 1) return partes[0]
  return `${partes.slice(0, -1).join(', ')} y ${partes[partes.length - 1]}`
}

/** Lo que falta para el vencimiento del REPROCANN de este paciente. */
export function reprocannPlazo(p, hoy = new Date()) {
  if (!p?.reprocann_vencimiento) return null
  return formatearPlazo(hoy, safeDate(p.reprocann_vencimiento))
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
