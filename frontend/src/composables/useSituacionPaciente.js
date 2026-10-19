// LOS TRES ESTADOS DEL PACIENTE en pantalla (19-oct-2026). La regla vive en el backend
// (`Pacientes::Situacion`) y viaja en `paciente.situacion`; acá sólo se le pone nombre y color.
// La lista, la ficha, la del médico y el alta usan estas mismas palabras.

export const REPROCANN_SITUACION = {
  pendiente_entrevista: { label: 'Pendiente de entrevista', nivel: 'warn',
    ayuda: 'Hay que darle entrevista con la médica para pedir su REPROCANN.' },
  pendiente_aprobacion: { label: 'Pendiente de aprobación', nivel: 'info',
    ayuda: 'El trámite está iniciado: falta que lo apruebe el Ministerio.' },
  activo:               { label: 'Activo',                  nivel: 'ok',     ayuda: 'REPROCANN vigente.' },
  vencido:              { label: 'Vencido',                 nivel: 'danger', ayuda: 'El REPROCANN venció.' },
  no_indicado:          { label: 'No indicado',             nivel: 'off',
    ayuda: 'La médica decidió no pedirlo. El paciente quedó inactivo.' },
  rechazado:            { label: 'Rechazado',               nivel: 'danger',
    ayuda: 'El Ministerio rechazó el trámite. El paciente quedó inactivo.' },
  sin_dato:             { label: 'Sin dato',                nivel: 'off',
    ayuda: 'Adherente sin el estado de su REPROCANN cargado.' },
}

export const PACIENTE_SITUACION = {
  activo:      { label: 'Activo',      nivel: 'ok' },
  suspendido:  { label: 'Suspendido',  nivel: 'warn',
    ayuda: 'Suspendido por poco movimiento: hace más de 90 días que no retira. Puede retirar igual, y vuelve a activo solo cuando lo haga.' },
  inactivo:    { label: 'Inactivo',    nivel: 'off', ayuda: 'Dado de baja: no puede retirar.' },
  sin_aprobar: { label: 'Sin aprobar', nivel: 'warn',
    ayuda: 'Se cargó desde el mostrador: no retira hasta que administración apruebe el alta.' },
}

export const VINCULO_SITUACION = {
  vinculado: { label: 'Vinculado', ayuda: 'Su REPROCANN está (o va a estar) con la organización.' },
  adherente: { label: 'Adherente', ayuda: 'Tiene su REPROCANN vigente con otra organización.' },
}

// Lo que se puede hacer desde cada paso (el backend manda la lista en `situacion.acciones`).
export const ACCIONES = {
  dar_turno:            { label: 'Dar turno',                 icono: 'bi-calendar-plus' },
  iniciar_tramite:      { label: 'Inicié el trámite',         icono: 'bi-send' },
  no_indicado:          { label: 'No indicado',               icono: 'bi-x-circle', tono: 'quiet' },
  cargar_aprobado:      { label: 'Llegó aprobado',            icono: 'bi-patch-check' },
  rechazado:            { label: 'Rechazado',                 icono: 'bi-x-octagon', tono: 'quiet' },
  volver_a_entrevistar: { label: 'Volver a entrevistar',      icono: 'bi-arrow-counterclockwise' },
  vincular:             { label: 'Se vinculó con nosotros',   icono: 'bi-link-45deg' },
}

const fecha = (d) => {
  if (!d) return ''
  const x = /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
  return x.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' })
}
const hora = (d) => new Date(d).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })

/**
 * Los datos chicos que van al lado del estado: «vence en 12 días», «pendiente de entrevista»
 * (cuando además está vencido o por vencer), «turno el 22/10 10:30», «faltó al turno del 12/10»,
 * «turno pasado sin cerrar». Cada uno con un nivel para el color.
 */
export function datosChicos(sit) {
  if (!sit) return []
  const out = []
  if (sit.vence_en_dias != null) {
    out.push({ texto: sit.vence_en_dias === 0 ? 'Vence hoy' : `Vence en ${sit.vence_en_dias} ${sit.vence_en_dias === 1 ? 'día' : 'días'}`, nivel: 'warn' })
  }
  if (sit.pendiente_entrevista && sit.reprocann !== 'pendiente_entrevista') {
    out.push({ texto: 'Pendiente de entrevista', nivel: 'warn' })
  }
  if (sit.reprocann === 'pendiente_aprobacion' && sit.tramite_iniciado_el) {
    out.push({ texto: `Trámite del ${fecha(sit.tramite_iniciado_el)}`, nivel: 'info' })
  }
  if (sit.resultado_el) out.push({ texto: `Desde el ${fecha(sit.resultado_el)}`, nivel: 'off' })
  if (sit.proximo_turno_at) out.push({ texto: `Turno ${fecha(sit.proximo_turno_at)} ${hora(sit.proximo_turno_at)}`, nivel: 'info', icono: 'bi-calendar-event' })
  if (sit.falto_turno_el)   out.push({ texto: `Faltó al turno del ${fecha(sit.falto_turno_el)}`, nivel: 'off', icono: 'bi-calendar-x' })
  if (sit.turno_sin_cerrar) out.push({ texto: 'Turno pasado sin cerrar', nivel: 'warn', icono: 'bi-hourglass' })
  return out
}

export const reprocannSit = (sit) => (sit && REPROCANN_SITUACION[sit.reprocann]) || null
export const pacienteSit  = (sit) => (sit && PACIENTE_SITUACION[sit.paciente]) || null
export const vinculoSit   = (sit) => (sit && VINCULO_SITUACION[sit.vinculo]) || null

// Los filtros de la lista, sobre `situacion` (mismas cuentas que `meta.kpis` del backend).
export const FILTROS = {
  entrevista:  (p) => !!p.situacion?.pendiente_entrevista,
  pendientes:  (p) => p.situacion?.reprocann === 'pendiente_aprobacion',
  proximos:    (p) => p.situacion?.reprocann === 'activo' && p.situacion?.vence_en_dias != null,
  vencidos:    (p) => p.situacion?.reprocann === 'vencido',
  falto:       (p) => !!p.situacion?.falto_turno_el,
  adherentes:  (p) => p.situacion?.vinculo === 'adherente',
  inactivos:   (p) => p.situacion?.paciente === 'suspendido',
  pend_aprobacion: (p) => p.situacion?.paciente === 'sin_aprobar',
  cerrados:    (p) => ['no_indicado', 'rechazado'].includes(p.situacion?.reprocann),
}
