/**
 * getSemestreRange(year, semestre) → { from: Date, to: Date }
 * 1er semestre = 1/1 al 30/6 | 2do semestre = 1/7 al 31/12
 */
export function getSemestreRange(year, semestre) {
  if (semestre === 1) {
    return { from: new Date(year, 0, 1), to: new Date(year, 5, 30) }
  }
  return { from: new Date(year, 6, 1), to: new Date(year, 11, 31) }
}

/**
 * formatFechaLarga(date, locale='es-AR') → "1 de enero de 2026"
 */
export function formatFechaLarga(date, locale = 'es-AR') {
  if (!date) return '—'
  let d = date instanceof Date ? date : (
    typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date)
      ? new Date(date + 'T00:00:00')
      : new Date(date)
  )
  if (isNaN(d)) return '—'
  return d.toLocaleDateString(locale, { day: 'numeric', month: 'long', year: 'numeric' })
}

/**
 * formatFechaCorta(date) → "1 ene 2026"
 */
export function formatFechaCorta(date, locale = 'es-AR') {
  if (!date) return '—'
  let d = date instanceof Date ? date : (
    typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date)
      ? new Date(date + 'T00:00:00')
      : new Date(date)
  )
  if (isNaN(d)) return '—'
  return d.toLocaleDateString(locale, { day: 'numeric', month: 'short', year: 'numeric' })
}

/**
 * formatFechaSemestre(year, semestre) → "1 de enero de 2026 al 30 de junio de 2026"
 */
export function formatFechaSemestre(year, semestre) {
  const { from, to } = getSemestreRange(year, semestre)
  return `${formatFechaLarga(from)} al ${formatFechaLarga(to)}`
}

/**
 * diasDesde(date) → número entero de días desde la fecha
 */
export function diasDesde(date) {
  if (!date) return null
  const d = date instanceof Date ? date : new Date(date)
  if (isNaN(d)) return null
  return Math.floor((Date.now() - d.getTime()) / 86400000)
}

/**
 * estaVencido(date) → true si la fecha ya pasó
 */
export function estaVencido(date) {
  if (!date) return false
  const d = date instanceof Date ? date : new Date(date)
  return d < new Date()
}

/**
 * venceEnDias(date, dias) → true si vence dentro de los próximos `dias` días
 */
export function venceEnDias(date, dias = 30) {
  if (!date) return false
  const d = date instanceof Date ? date : new Date(date)
  const hoy = new Date()
  const limite = new Date(hoy.getTime() + dias * 86400000)
  return d >= hoy && d <= limite
}

/**
 * semestreActual() → { year, semestre }
 */
export function semestreActual() {
  const hoy = new Date()
  return {
    year:     hoy.getFullYear(),
    semestre: hoy.getMonth() < 6 ? 1 : 2,
  }
}

/**
 * toISO(date) → "2026-01-01" (formato para inputs date)
 *
 * OJO: se arma con los componentes LOCALES, nunca con `toISOString()`, que devuelve UTC.
 * En Argentina (UTC−3) `new Date().toISOString().slice(0,10)` da el día SIGUIENTE desde las
 * 21:00 — y el backend valida contra `Time.zone.today` en Buenos Aires. Resultado: entre las
 * 21:00 y la medianoche, dispensar rebotaba con "la fecha no puede ser futura", justo en las
 * horas de más movimiento del dispensario.
 */
export function toISO(date) {
  if (!date) return ''
  const d = date instanceof Date ? date : new Date(date)
  if (isNaN(d)) return ''
  const mes = String(d.getMonth() + 1).padStart(2, '0')
  const dia = String(d.getDate()).padStart(2, '0')
  return `${d.getFullYear()}-${mes}-${dia}`
}

/**
 * hoyISO() → "2026-09-09" — el día de HOY según el reloj de quien usa la app.
 *
 * Es la única forma correcta de decir "hoy" para mandárselo al backend. Usala en vez de
 * `new Date().toISOString().slice(0, 10)`, que es UTC y adelanta un día cada noche.
 */
export function hoyISO() {
  return toISO(new Date())
}

/**
 * paraInputDatetime(date = new Date()) → "2026-09-09T23:30" (para <input type="datetime-local">)
 *
 * Mismo problema que `toISO` pero con la hora: `toISOString().slice(0, 16)` da la hora UTC, o sea
 * tres horas adelantada en Argentina. Un campo de fecha y hora que arranca tres horas en el
 * futuro es peor que uno vacío.
 */
export function paraInputDatetime(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date)
  if (isNaN(d)) return ''
  const hh = String(d.getHours()).padStart(2, '0')
  const mm = String(d.getMinutes()).padStart(2, '0')
  return `${toISO(d)}T${hh}:${mm}`
}

// ¿Una fecha (YYYY-MM-DD) y hora (HH:MM) LOCALES ya pasaron? Para no agendar ni reprogramar un
// turno en el pasado (12-oct-2026): el selector de fecha corta en hoy, pero la hora de hoy no.
// El backend valida lo mismo (`Turno#no_en_el_pasado`); esto es para avisar antes de mandar.
export function yaPaso(fecha, hora, ahora = new Date()) {
  if (!fecha || !hora) return false
  return new Date(`${fecha}T${hora}:00`) <= ahora
}

/**
 * Una fecha en castellano con las opciones dadas, y el AÑO cuando no es el de hoy. «2 dic» de hace
 * diez meses se leía como el que viene (20-oct-2026). Toda fecha corta («2 dic», «2 dic 14:00») pasa
 * por acá; las de un solo mes (chips de calendario) no lo necesitan.
 *   fechaLocal('2025-12-02T14:00', { day: 'numeric', month: 'short' }) → «2 dic 2025»
 */
export function fechaLocal(fecha, opciones) {
  const d = fecha instanceof Date ? fecha : new Date(fecha)
  if (isNaN(d.getTime())) return ''
  const opts = d.getFullYear() === new Date().getFullYear() ? opciones : { ...opciones, year: 'numeric' }
  return d.toLocaleString('es-AR', opts)
}
