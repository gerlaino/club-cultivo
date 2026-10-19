// EL FORMULARIO DEL PACIENTE, UNO SOLO (19-oct-2026). El alta (por pasos) y la edición (por
// solapas) usan las mismas secciones, los mismos campos y estas mismas validaciones: lo que se pide
// al crear es lo que se puede corregir después, con las mismas palabras.

// Cómo está su REPROCANN, dicho como lo cuenta quien lo carga. Cada opción guarda un estado; el
// estado que se MUESTRA (pendiente de entrevista, activo, vencido…) lo calcula el backend.
export const OPCIONES_VINCULADO = [
  { value: 'sin',      estado: 'sin_registro', label: 'Todavía no tiene',
    ayuda: 'Arranca pendiente de entrevista médica: la médica lo ve y, si corresponde, inicia el trámite.' },
  { value: 'tramite',  estado: 'pendiente',    label: 'Está en trámite',
    ayuda: 'Ya se pidió: queda pendiente de aprobación del Ministerio.' },
  { value: 'aprobado', estado: 'activo',       label: 'Lo tiene aprobado',
    ayuda: 'Con número y vencimiento. A 30 días de vencer, vuelve a pedir entrevista sola.' },
  { value: 'vencido',  estado: 'vencido',      label: 'Se le venció',
    ayuda: 'Queda vencido y pendiente de entrevista para renovarlo.' },
]

// El adherente: su estado se carga tal como figura en su organización (no lo tramitamos nosotros).
export const ESTADOS_ADHERENTE = [
  { value: 'activo',    label: 'Vigente' },
  { value: 'pendiente', label: 'Pendiente de aprobación' },
  { value: 'vencido',   label: 'Vencido' },
]

export const CERRADOS = ['no_indicado', 'rechazado']

export function formVacio() {
  return {
    nombre: '', apellido: '', apodo: '', dni: '', fecha_nacimiento: '', telefono: '', email: '',
    domicilio_calle: '', domicilio_altura: '', domicilio_piso: '', domicilio_depto: '',
    domicilio_barrio: '', domicilio_ciudad: '',
    envio_etiqueta: '', envio_calle: '', envio_altura: '', envio_piso: '', envio_depto: '',
    envio_barrio: '', envio_ciudad: '',
    reprocann_vinculo: 'organizacion', opcion_reprocann: 'sin',
    reprocann_estado: 'sin_registro', reprocann_numero: '', reprocann_vencimiento: '',
    es_paciente: true, descuento_porcentaje: 0,
  }
}

// De la ficha al formulario (edición).
export function desdePaciente(p) {
  const f = formVacio()
  for (const k of Object.keys(f)) {
    if (p?.[k] !== undefined && p?.[k] !== null) f[k] = p[k]
  }
  f.reprocann_vinculo = p?.reprocann_vinculo === 'otra_organizacion' ? 'otra_organizacion' : 'organizacion'
  f.reprocann_vencimiento = (p?.reprocann_vencimiento || '').toString().slice(0, 10)
  f.fecha_nacimiento = (p?.fecha_nacimiento || '').toString().slice(0, 10)
  f.opcion_reprocann = opcionDe(p)
  f._estado_original = p?.reprocann_estado
  return f
}

function opcionDe(p) {
  const e = p?.reprocann_estado
  if (e === 'pendiente') return 'tramite'
  if (e === 'vencido') return 'vencido'
  if (p?.reprocann_numero || p?.reprocann_vencimiento || e === 'activo') return 'aprobado'
  return 'sin'
}

export const esAdherente = (f) => f.reprocann_vinculo === 'otra_organizacion'
export const reprocannCerrado = (f) => CERRADOS.includes(f._estado_original)

// Qué viaja al backend. Lo que la opción elegida no usa se limpia: «todavía no tiene» con un número
// viejo cargado diría dos cosas a la vez.
export function aPayload(f, { campos = null } = {}) {
  const p = { ...f }
  delete p.opcion_reprocann
  delete p._estado_original
  if (!reprocannCerrado(f)) {
    if (esAdherente(f)) {
      p.reprocann_estado = f.reprocann_estado && ESTADOS_ADHERENTE.some(e => e.value === f.reprocann_estado)
        ? f.reprocann_estado : 'activo'
    } else {
      const op = OPCIONES_VINCULADO.find(o => o.value === f.opcion_reprocann) || OPCIONES_VINCULADO[0]
      p.reprocann_estado = op.estado
      if (op.value === 'sin' || op.value === 'tramite') {
        p.reprocann_numero = ''
        p.reprocann_vencimiento = ''
      }
    }
  } else {
    delete p.reprocann_estado // un cerrado se cambia desde la ficha, con su acción
  }
  if (campos) Object.keys(p).forEach(k => { if (!campos.includes(k)) delete p[k] })
  return p
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

// Validaciones por sección. Devuelven { campo: 'mensaje' }; vacío = todo bien.
export function validarPersona(f) {
  const e = {}
  if (!f.nombre?.trim())   e.nombre = 'Falta el nombre'
  if (!f.apellido?.trim()) e.apellido = 'Falta el apellido'
  const dni = (f.dni || '').replace(/\D/g, '')
  if (!dni) e.dni = 'Falta el DNI'
  else if (!/^\d{7,9}$/.test(dni)) e.dni = 'El DNI tiene 7 a 9 dígitos'
  if (!f.fecha_nacimiento) e.fecha_nacimiento = 'Falta la fecha de nacimiento'
  else if (f.fecha_nacimiento >= new Date().toLocaleDateString('en-CA')) e.fecha_nacimiento = 'Tiene que ser una fecha pasada'
  if (f.email && !EMAIL.test(f.email)) e.email = 'El mail no parece válido'
  return e
}

export function validarDomicilio() { return {} } // opcional: se anota con lo que hay

export function validarReprocann(f) {
  const e = {}
  if (reprocannCerrado(f)) return e
  if (!esAdherente(f) && f.opcion_reprocann === 'aprobado') {
    if (!f.reprocann_numero?.trim()) e.reprocann_numero = 'Falta el número'
    if (!f.reprocann_vencimiento)    e.reprocann_vencimiento = 'Falta el vencimiento'
  }
  return e
}

export function edad(fn) {
  if (!fn) return null
  const d = new Date(fn + 'T00:00:00')
  const hoy = new Date()
  let a = hoy.getFullYear() - d.getFullYear()
  if (hoy < new Date(hoy.getFullYear(), d.getMonth(), d.getDate())) a -= 1
  return a >= 0 ? a : null
}

// «30.111.222»: como se lee en el documento.
export const dniLegible = (dni) => String(dni || '').replace(/\D/g, '').replace(/\B(?=(\d{3})+(?!\d))/g, '.')
