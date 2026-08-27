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

/**
 * Días de CALENDARIO que faltan para el vencimiento. 0 = vence hoy; negativo = ya venció.
 *
 * Se cuenta de medianoche a medianoche y NO restando milisegundos. El vencimiento llega como
 * fecha sin hora (00:00) y `new Date()` trae la hora del día, así que la resta cruda perdía
 * siempre un día: a las 13:00 de hoy, algo que vencía MAÑANA daba 10 horas y `floor` lo
 * mostraba como "0d", y lo que vencía HOY daba -1 y se informaba como VENCIDO un día antes de
 * tiempo. El backend (`Paciente.reprocann_categoria`) compara fechas peladas y decía lo
 * contrario para el mismo paciente: la misma regla en dos lugares, corrida un día.
 */
export function reprocannDias(p, hoy = new Date()) {
  if (!p?.reprocann_vencimiento) return null
  const v     = safeDate(p.reprocann_vencimiento)
  const vence = new Date(v.getFullYear(), v.getMonth(), v.getDate())
  const desde = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())
  // `round` y no `floor`: entre dos medianoches puede haber 23 o 25 horas si en el medio cambia
  // el huso. Hoy en Argentina no pasa, pero la cuenta no tiene por qué depender de eso.
  return Math.round((vence - desde) / 86400000)
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
export function reprocannCategoria(p, hoy = new Date()) {
  const estado = p?.reprocann_estado_efectivo || p?.reprocann_estado
  if (estado === 'pendiente') return 'pendiente'
  if (!p?.reprocann_numero)   return 'sin_reprocann'
  const d = reprocannDias(p, hoy)
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
export function reprocannBadge(p, hoy = new Date()) {
  const cat  = reprocannCategoria(p, hoy)
  const days = reprocannDias(p, hoy)
  const base = BADGES[cat]
  if (!base) return null
  // "0d" no se lee como "vence hoy": se lee como "ya venció", que es lo contrario de lo que
  // dice la categoría. El último día del certificado se escribe con todas las letras.
  if (cat === 'por_vencer') return { label: days === 0 ? 'Hoy' : `${days}d`, level: 'warning', days, cat }
  if (cat === 'vigente' && days !== null && days <= 90) {
    return { label: `${days}d`, level: 'caution', days, cat }
  }
  return { ...base, days, cat }
}
