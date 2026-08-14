// Lógica del alta de movimientos contables, fuera del componente: los flujos (qué pide cada uno),
// la validación (UNA sola fuente: el botón y el submit preguntan lo mismo) y el manejo de plata.
//
// El orden de la UI sale de acá y es a propósito el orden en que piensa un admin —"qué pasó" antes
// que "de qué tipo es el asiento"—. La categoría contable es consecuencia del hecho, no la puerta.

/** Hoy en horario LOCAL. `toISOString()` es UTC: en AR (UTC−3) pasadas las 21hs devuelve mañana. */
export function hoyLocal(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// ─── Plata ──────────────────────────────────────────────────────────────────────
// Se escribe como se escribe en Argentina: miles con punto, decimales con coma. `monto_ars` es
// decimal(12,2) en la base, así que los centavos existen y el form tiene que dejarlos entrar.

/** "1234567.5" → "1.234.567,5" (para mostrar mientras se tipea) */
export function fmtMiles(valor) {
  if (valor === null || valor === undefined || valor === '') return ''
  const [ent, dec] = String(valor).split('.')
  const conPuntos = ent.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
  return dec !== undefined ? `${conPuntos},${dec}` : conPuntos
}

/**
 * Normaliza lo tipeado a { texto, monto }: `texto` es lo que se muestra en el input y `monto` el
 * número que va al backend (null si está vacío). Tolera pegar "$ 1.234,56".
 */
export function parseMonto(input) {
  const limpio = String(input ?? '').replace(/[^\d,]/g, '')
  if (!limpio) return { texto: '', monto: null }

  const [entRaw, ...resto] = limpio.split(',')
  const ent = entRaw.replace(/^0+(?=\d)/, '') || '0'
  const hayComa = resto.length > 0
  const dec = resto.join('').slice(0, 2) // centavos, no más

  const texto = fmtMiles(ent) + (hayComa ? `,${dec}` : '')
  const monto = Number(`${ent}.${dec || 0}`)
  return { texto, monto: Number.isFinite(monto) ? monto : null }
}

export function fmtARS(n) {
  return new Intl.NumberFormat('es-AR', {
    style: 'currency', currency: 'ARS', maximumFractionDigits: 0,
  }).format(n || 0)
}

// ─── Flujos ─────────────────────────────────────────────────────────────────────
// Cada flujo es "qué pasó" en el club. Fija el tipo de asiento, qué campos pide y la copy. Los
// flujos comparten los mismos campos base (monto, fecha, descripción, categoría): solo cambian los
// bloques propios y los textos, así que no hay cinco formularios sino uno configurado.

export const FLOWS = {
  compra: {
    key: 'compra',
    icono: 'bi-cart3',
    titulo: 'Compré algo',
    resumen: 'Insumos, mercadería, algo que entra al club',
    tipo: 'egreso',
    // Con qué se clasifica el movimiento si no se elige categoría del catálogo (la columna
    // legacy `categoria` es NOT NULL y sólo acepta `MovimientoContable::CATEGORIAS`).
    claveLegacy: 'insumo',
    pideDestino: true,      // qué entró, cuánto y a qué depósito
    pidePaciente: false,
    labelDescripcion: 'Qué se compró',
    phDescripcion: 'Ej: 20 l de fertilizante base',
    labelMonto: 'Cuánto se pagó',
    cta: 'Registrar compra',
  },
  aporte: {
    key: 'aporte',
    icono: 'bi-cash-coin',
    titulo: 'Cobré un aporte',
    resumen: 'Aporte de un paciente: acredita su cuenta corriente',
    tipo: 'ingreso',
    claveLegacy: 'aporte_socio',
    pideDestino: false,
    pidePaciente: true,
    clavePreferida: 'aporte_socio', // preselecciona la categoría si existe
    labelDescripcion: 'Concepto',
    phDescripcion: 'Ej: Aporte de julio',
    labelMonto: 'Cuánto se cobró',
    cta: 'Registrar aporte',
  },
  gasto: {
    key: 'gasto',
    icono: 'bi-receipt',
    titulo: 'Pagué un gasto',
    resumen: 'Alquiler, servicios, impuestos, sueldos',
    tipo: 'egreso',
    claveLegacy: 'otro',
    pideDestino: false,
    pidePaciente: false,
    labelDescripcion: 'Qué se pagó',
    phDescripcion: 'Ej: Alquiler julio',
    labelMonto: 'Cuánto se pagó',
    cta: 'Registrar gasto',
  },
  ingreso: {
    key: 'ingreso',
    icono: 'bi-plus-circle',
    titulo: 'Otro ingreso',
    resumen: 'Cualquier plata que entra y no es un aporte',
    tipo: 'ingreso',
    claveLegacy: 'otro',
    pideDestino: false,
    pidePaciente: false,
    labelDescripcion: 'De qué es el ingreso',
    phDescripcion: 'Ej: Venta de merchandising',
    labelMonto: 'Cuánto entró',
    cta: 'Registrar ingreso',
  },
  fijos: {
    key: 'fijos',
    icono: 'bi-arrow-repeat',
    titulo: 'Fijos del mes',
    resumen: 'Cargá de una los que se repiten todos los meses',
    pantalla: 'fijos', // no es un form: es la lista de recurrentes detectados
  },
}

/** Orden en la pantalla de intención: lo más frecuente primero. */
export const FLOWS_ORDEN = ['compra', 'aporte', 'gasto', 'ingreso', 'fijos']

export function flowDe(key) {
  return FLOWS[key] || null
}

// ─── Destino de la mercadería ───────────────────────────────────────────────────
// Una compra puede ser puro gasto (la luz) o entrar al inventario (fertilizante, cerveza). El
// DEPÓSITO se elige primero porque manda: define la sede del asiento y filtra qué ítems pueden
// entrar. Antes se elegía último y se podía reponer un insumo de otro depósito → la plata quedaba
// en una sede y el stock en otra.

export function destinoVacio() {
  return {
    deposito_id: '',
    insumo_id: '',          // '' = insumo nuevo
    nombre: '',
    unidad_medida: 'unidad',
    cantidad: null,
    bar_id: '',             // salón
    bar_producto_id: '',    // '' = producto nuevo
    precio_ars: null,
    no_vender: false,
  }
}

export const UNIDADES_INSUMO = ['unidad', 'litro', 'mililitro', 'kilogramo', 'gramo', 'bolsa', 'metro', 'otro']

/**
 * Unidades del MOVIMIENTO (MovimientoContable::UNIDADES). Son las de inventario más las que sólo
 * tienen sentido para un gasto: se contratan 10 horas de electricista o 3 análisis de laboratorio,
 * y ninguno de los dos entra a un depósito, pero los dos tienen precio por unidad.
 */
export const UNIDADES = [...UNIDADES_INSUMO.filter(u => u !== 'otro'), 'hora', 'servicio', 'otro']

/** El depósito Salón guarda productos del bar (no insumos): otra entrada. */
export function esDepositoSalon(deposito) {
  return deposito?.clave_sistema === 'salon' || deposito?.familia === 'mercaderia'
}

/** Estado del destino, para validar y para saber si hay algo que mandar. */
export function destinoEstado(destino, deposito) {
  const iniciado = !!destino?.deposito_id
  const esSalon  = esDepositoSalon(deposito)
  const itemOk = !iniciado ? true
    : esSalon
      ? !!destino.bar_id && (!!destino.bar_producto_id || !!destino.nombre?.trim())
      : (!!destino.insumo_id || !!destino.nombre?.trim())
  return { iniciado, esSalon, itemOk, cantidad: destino?.cantidad }
}

/** Payload de `destino` para el backend. null = el movimiento no mueve stock. */
export function destinoPayload(destino, deposito) {
  const { iniciado, esSalon, itemOk } = destinoEstado(destino, deposito)
  if (!iniciado || !itemOk || !(Number(destino.cantidad) > 0)) return null

  if (esSalon) {
    const base = { tipo: 'salon', deposito_id: deposito.id, bar_id: destino.bar_id, cantidad: Number(destino.cantidad) }
    return destino.bar_producto_id
      ? { ...base, bar_producto_id: destino.bar_producto_id }
      : { ...base, nombre: destino.nombre.trim(), categoria: 'bebida', precio_ars: destino.precio_ars, no_vender: destino.no_vender }
  }

  const base = { tipo: 'deposito', deposito_id: deposito.id, cantidad: Number(destino.cantidad) }
  return destino.insumo_id
    ? { ...base, insumo_id: destino.insumo_id }
    : { ...base, nombre: destino.nombre.trim(), unidad_medida: destino.unidad_medida }
}

/** Costo unitario que se le va a imputar al ítem (feedback inmediato al cargar la compra). */
export function costoUnitario(monto, cantidad) {
  const m = Number(monto), c = Number(cantidad)
  if (!(m > 0) || !(c > 0)) return null
  return m / c
}

// ─── Validación ─────────────────────────────────────────────────────────────────

/**
 * Única fuente de verdad de "¿se puede guardar?". Devuelve un objeto de errores por campo (vacío =
 * válido) para que el botón y el submit no puedan discrepar, que era el bug del form anterior.
 *
 * ctx: { pacienteObligatorio, esCuotas, pideDestino, destinoIniciado }
 */
export function validarMovimiento(form, ctx = {}) {
  const e = {}

  // LA CATEGORÍA MANDA, así que es obligatoria. De ella salen el sector y si la compra entra a
  // un depósito (y a cuál): sin categoría, el formulario tendría que volver a preguntar las tres
  // cosas y el gasto terminaría sin sector, invisible en el resultado de toda área.
  //
  // Era opcional porque el catálogo arrancaba vacío. Ya no: la organización nace con una lista
  // de categorías sembrada, así que cargar es ELEGIR.
  if (!ctx.categoriaOpcional && !form.categoria_contable_id) e.categoria = 'Elegí una categoría'
  if (!form.descripcion?.trim())        e.descripcion = 'Poné una descripción'
  if (!(Number(form.monto_ars) > 0))    e.monto_ars   = 'Ingresá un monto'
  if (!form.fecha)                      e.fecha       = 'Elegí la fecha'
  if (ctx.pacienteObligatorio && !form.paciente_id) e.paciente_id = 'Elegí el paciente'
  // Opcional, pero si se carga tiene que ser positiva: un 0 hace explotar el costo unitario.
  if (form.cantidad !== null && form.cantidad !== undefined && form.cantidad !== '' && !(Number(form.cantidad) > 0)) {
    e.cantidad = 'La cantidad tiene que ser mayor a 0'
  }
  if (ctx.esCuotas && !(Number(form.cuotas_total) >= 2)) e.cuotas_total = 'Mínimo 2 cuotas'

  // El destino es opcional (una compra puede ser puro gasto), pero a medio llenar no: si eligió
  // depósito, tiene que decir qué entró y cuánto, o el asiento se guarda sin mover el stock —
  // que es justo el silencio que hacía perder mercadería.
  if (ctx.pideDestino && ctx.destino?.iniciado) {
    if (!ctx.destino.itemOk)              e.destino_item     = 'Elegí o nombrá qué entró'
    // La cantidad es la del movimiento (se carga arriba, con el monto). Si la compra entra a un
    // depósito deja de ser opcional: sin ella el asiento se guarda y el stock no se mueve.
    if (!(Number(ctx.destino.cantidad) > 0)) e.destino_cantidad = 'Indicá la cantidad para que entre al depósito'
  }

  return e
}

export function esValido(errores) {
  return Object.keys(errores).length === 0
}
