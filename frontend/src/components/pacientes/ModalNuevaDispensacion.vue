<script setup>
import { ref, computed, watch } from 'vue'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import { useAuthStore } from '../../stores/auth.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { createReserva, entregarReserva, listStocks, listEntregadores } from '../../lib/api.js'
import { dispensarOffline } from '../../lib/offlineApi.js'

const props = defineProps({
  modelValue:     { type: Boolean, required: true },
  socioId:        { type: Number,  required: true },
  pacienteNombre: { type: String,  default: '' },
  saldoCc:        { type: Number,  default: null },
  limiteCc:       { type: Number,  default: null },
  descuentoPorcentaje: { type: Number,  default: 0 },
  // Si viene una reserva, el modal entra en modo "entregar reserva": convierte la
  // reserva en una dispensación (cobra el resto = total − seña).
  reserva:        { type: Object,  default: null },
  // Modo en el que se abre: 'dispensa' (carrito) o 'reserva'. Solo aplica si puede reservar.
  modoInicial:    { type: String,  default: 'dispensa' },
})

const modoReserva   = computed(() => !!props.reserva)
const restoReserva  = computed(() => Number(props.reserva?.aporte_restante_ars) || 0)
const senaReserva   = computed(() => Number(props.reserva?.sena_ars) || 0)

const emit = defineEmits(['update:modelValue', 'saved'])

const { confirm }     = useConfirm()
const toast           = useToast()
const auth            = useAuthStore()

// admin/supervisor: ven el descuento del paciente, el desglose de precio,
// pueden pisar el aporte a mano y ven siempre el crédito.
const esAdminoSup = computed(() =>
  ['admin', 'supervisor', 'super_admin'].includes(auth.user?.role)
)
const puedeVerCredito       = esAdminoSup
const puedeEditarAporte     = esAdminoSup
const puedeVerDescPaciente  = esAdminoSup
// Reservas: solo admin/supervisor. El dispensador no ve el toggle de reserva.
const puedeReservar         = esAdminoSup

// Carrito multi-item de la dispensa inmediata: cada línea es un stock + cantidad. El total
// es la suma y el descuento se aplica sobre ella. Las reservas siguen siendo de un producto.
const items = ref([])
const esDispensaInmediata = computed(() => !modoReserva.value && !form.value.es_reserva)

const stocks          = ref([])
const loadingStocks   = ref(false)
const saving          = ref(false)
const formError       = ref(null)
const deliveryUsers   = ref([])
const deliveryError   = ref(null)
const loadingDelivery = ref(false)

const today = new Date().toISOString().split('T')[0]
// Una reserva es apartar stock a FUTURO: la fecha mínima es mañana (hoy = dispensación directa).
const tomorrow = (() => { const d = new Date(); d.setDate(d.getDate() + 1); return d.toISOString().split('T')[0] })()

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  preroll: 'Preroll', crema: 'Crema', descarte: 'Descarte', otro: 'Otro',
}
// Genética + lote: lo que distingue dos stocks que comparten forma de producto.
function detalleStock(st) {
  if (!st) return ''
  const gen  = st.genetica?.nombre || st.lote?.genetica?.nombre
  const lote = st.lote?.codigo || st.numero_lote_producto
  return [gen, lote].filter(Boolean).join(' · ')
}

const FORMA_EMOJI = {
  flor_seca: '🌿', hash: '🟤', aceite: '🫙',
  preroll: '🚬', crema: '💊', descarte: '🗑️', otro: '📦',
}

// ── Primero la sede, después el stock de esa sede ────────────────────────────────
// Una organización con varias sedes mostraba todo el inventario junto en una sola lista, y quien
// dispensa tenía que acordarse de cuál era de su mostrador. Se elige la sede y la lista queda
// acotada. Con UNA sola sede el paso no aparece: no hay nada que elegir.
const conStock = computed(() => stocks.value.filter(s => s.cantidad > 0))

const sedesConStock = computed(() => {
  const mapa = new Map()
  for (const s of conStock.value) {
    const id = s.sede?.id ?? null
    if (!mapa.has(id)) mapa.set(id, { id, nombre: s.sede?.nombre || 'Sin sede (club)', items: 0 })
    mapa.get(id).items += 1
  }
  return [...mapa.values()].sort((a, b) => (a.id === null) - (b.id === null) || a.nombre.localeCompare(b.nombre))
})
const hayVariasSedes = computed(() => sedesConStock.value.length > 1)

const sedeElegida = ref(undefined)   // undefined = todavía no eligió
watch(sedesConStock, (lista) => {
  // Con una sola sede se elige sola: pedir que la confirmes sería un clic de peaje.
  if (lista.length === 1) sedeElegida.value = lista[0].id
  else if (sedeElegida.value !== undefined && !lista.some(x => x.id === sedeElegida.value)) {
    sedeElegida.value = undefined
  }
}, { immediate: true })

// Cambiar de sede limpia el stock elegido: si no, quedaba seleccionado uno que ya no se ve.
watch(sedeElegida, () => { form.value.stock_id = null })

const stocksDisponibles = computed(() =>
  sedeElegida.value === undefined && hayVariasSedes.value
    ? []
    : conStock.value.filter(s => sedeElegida.value === undefined || (s.sede?.id ?? null) === sedeElegida.value)
)

// ── Cuenta corriente ARS ───────────────────────────────────────────────────────
const tieneCc  = computed(() => props.limiteCc !== null && props.limiteCc > 0)
const ccMargen = computed(() => (props.saldoCc ?? 0) + (props.limiteCc ?? 0))

// El crédito solo aplica cuando el medio de pago consume crédito.
const esMedioCredito = computed(() => ['cuenta_corriente', 'no_abona'].includes(form.value.medio_pago))
const esCuentaCorriente = computed(() => form.value.medio_pago === 'cuenta_corriente')
const esNoAbona         = computed(() => form.value.medio_pago === 'no_abona')
// Sin cuenta corriente + pago cash: el aporte queda fijo al total (no se puede pagar de
// más/menos porque no hay dónde acreditar/debitar la diferencia).
const aporteBloqueado = computed(() => !tieneCc.value && !esMedioCredito.value)
// Panel de crédito: visible a quien dispensa cuando elige cuenta corriente; admin/sup siempre.
const mostrarPanelCredito = computed(() => !form.value.es_regalo && tieneCc.value && (esMedioCredito.value || puedeVerCredito.value))

const margenPos = computed(() => Math.max(0, ccMargen.value))
// Cuenta corriente: el crédito cubre lo que puede; la diferencia se cobra ahora.
const montoACredito = computed(() => {
  if (!esMedioCredito.value) return 0
  return Math.min(Number(form.value.aporte_socio_ars) || 0, margenPos.value)
})
const restoACobrar = computed(() => {
  if (!esCuentaCorriente.value) return 0
  return Math.max(0, (Number(form.value.aporte_socio_ars) || 0) - margenPos.value)
})

// Solo "no abona" se bloquea por crédito (no paga nada ahora → tiene que entrar entero).
const ccInsuficiente = computed(() => {
  if (!tieneCc.value || !esNoAbona.value) return false
  const aporte = Number(form.value.aporte_socio_ars)
  return aporte > 0 && aporte > ccMargen.value
})

const estadoCc = computed(() => {
  if (!tieneCc.value) return null
  if (ccInsuficiente.value)  return 'insuficiente'
  if (restoACobrar.value > 0) return 'critico'
  if (ccMargen.value <= 0)   return 'agotado'
  return 'ok'
})

const excederiaStock = computed(() => {
  if (!stockSeleccionado.value || !form.value.cantidad) return false
  // En el carrito ya puede haber líneas del mismo stock: descontalas del disponible.
  const yaEnCarrito = items.value
    .filter(it => it.stock.id === stockSeleccionado.value.id)
    .reduce((a, it) => a + it.cantidad, 0)
  return parseFloat(form.value.cantidad) + yaEnCarrito > stockSeleccionado.value.cantidad
})

const fmt = n => n == null ? '—' :
  new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)

const fmtFecha = (d) => {
  if (!d) return null
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d))
  return m ? `${m[3]}/${m[2]}/${m[1]}` : null
}

async function cargarStocks() {
  loadingStocks.value = true
  try {
    // Solo stock habilitado para dispensa (el backend filtra con este flag).
    const { data } = await listStocks({ para_dispensa: true })
    stocks.value = data || []
  } catch { stocks.value = [] }
  finally { loadingStocks.value = false }
}

// ── Carrito multi-item (dispensa inmediata) ──────────────────────────────────────
// Subtotal de una línea con el precio sugerido del stock (sin descuento; el descuento
// se muestra sobre el total). 0 si el stock no tiene precio configurado.
// Precio efectivo de la línea: el del stock, o el manual que carga el admin si el stock
// no tiene precio configurado.
const precioLinea = (it) => Number(it.stock.precio_sugerido_ars) > 0
  ? Number(it.stock.precio_sugerido_ars)
  : (Number(it.precioManual) || 0)
function subtotalItem(it) {
  return precioLinea(it) * it.cantidad
}

// Agrega la línea en edición (stock seleccionado + cantidad) al carrito.
function agregarItem() {
  const s = stockSeleccionado.value
  if (!s) { formError.value = 'Elegí un stock para agregar'; return }
  const cant = parseFloat(form.value.cantidad)
  if (!cant || cant <= 0) { formError.value = 'Ingresá una cantidad válida'; return }
  const yaEnCarrito = items.value.filter(it => it.stock.id === s.id).reduce((a, it) => a + it.cantidad, 0)
  if (cant + yaEnCarrito > s.cantidad) {
    formError.value = `Stock insuficiente: ${(s.cantidad - yaEnCarrito).toFixed(2)}${s.unidad || 'g'} disponibles`
    return
  }
  // El dispensador no puede dispensar stock sin precio (no fija precios).
  if (!(Number(s.precio_sugerido_ars) > 0) && !puedeEditarAporte.value) {
    formError.value = 'Ese stock no tiene precio configurado. Pedile al administrador que lo cargue.'
    return
  }
  // Las líneas del mismo stock solo se fusionan si salen del mismo lado (libre o evento):
  // si no, se perdería de qué evento salió cada parte.
  const existente = items.value.find(it => it.stock.id === s.id && (it.desdeEvento || null) === desdeEvento.value)
  if (existente) existente.cantidad = Number((existente.cantidad + cant).toFixed(3))
  else items.value.push({ stock: s, cantidad: cant, precioManual: null, guardarPrecio: false, desdeEvento: desdeEvento.value })
  form.value.stock_id = null
  form.value.cantidad = null
  formError.value = null
}

function quitarItem(i) { items.value.splice(i, 1) }

async function cargarDeliveryUsers() {
  if (deliveryUsers.value.length) return
  loadingDelivery.value = true
  deliveryError.value = null
  try {
    const { data } = await listEntregadores()
    deliveryUsers.value = data.data || data.usuarios || data || []
  } catch (e) {
    // Tragarse el error y mostrar "no hay delivery" es mentirle al usuario: puede haberlos
    // y ser un problema de permisos o de red.
    deliveryUsers.value = []
    deliveryError.value = e?.response?.status === 403
      ? 'No tenés permiso para ver la lista de entregadores. Avisale a un administrador.'
      : 'No se pudo cargar la lista de entregadores. Reintentá.'
  }
  finally { loadingDelivery.value = false }
}

function emptyForm() {
  return {
    stock_id: null, cantidad: null, descuento_pct: 0, aporte_socio_ars: null,
    fecha_dispensacion: today, observaciones: '', medio_pago: 'efectivo', es_regalo: false,
    con_envio: false, delivery_id: null, direccion_envio: '',
    contacto_nombre: '', contacto_telefono: '', notas_envio: '',
    // Dirección de entrega estructurada (o usar el domicilio registrado del paciente)
    usar_domicilio_paciente: true,
    envio_calle: '', envio_altura: '', envio_piso: '', envio_depto: '', envio_barrio: '', envio_ciudad: '',
    // Reserva: si es_reserva, no se entrega ahora — se aparta stock para una fecha futura.
    es_reserva: false, fecha_entrega_estimada: '', sena_ars: null,
  }
}

const form               = ref(emptyForm())
const precioUnitarioManual = ref(null)

// "Contra entrega" como medio de pago = el delivery cobra al entregar. Requiere envío.
const cobraDelivery = computed(() => form.value.medio_pago === 'contra_entrega')
watch(() => form.value.medio_pago, (val) => { if (val === 'contra_entrega') form.value.con_envio = true })
watch(() => form.value.con_envio, (val) => {
  if (val) cargarDeliveryUsers()
  else if (form.value.medio_pago === 'contra_entrega') form.value.medio_pago = 'efectivo'
})
watch(() => form.value.stock_id,  ()    => { precioUnitarioManual.value = null })
// La seña de una reserva solo se cobra en efectivo o transferencia.
watch(() => form.value.es_reserva, (val) => {
  if (val && !['efectivo', 'transferencia'].includes(form.value.medio_pago)) form.value.medio_pago = 'efectivo'
  if (val) form.value.es_regalo = false // una reserva no puede ser regalo
})
// Regalo: entrega gratis. Neutraliza el medio de pago (no cobra por ninguna vía).
watch(() => form.value.es_regalo, (val) => {
  if (val) { form.value.medio_pago = 'efectivo'; form.value.es_reserva = false }
})

const stockSeleccionado    = computed(() => stocks.value.find(s => s.id === form.value.stock_id) || null)

// ── Apartado de eventos en curso ────────────────────────────────────────────────
// Lo apartado para un evento que está sucediendo se puede dispensar, pero solo si el
// dispensador lo marca: así una dispensa de mostrador no se come lo reservado del evento.
const apartadosDelStock = computed(() => stockSeleccionado.value?.apartados_evento || [])
const desdeEvento = ref(null) // evento_bar_id del que sale la línea, o null = del stock libre
watch(() => form.value.stock_id, () => { desdeEvento.value = null })
const eventoDe = (id) => apartadosDelStock.value.find(a => a.evento_id === id) || null
const necesitaPrecioManual = computed(() => stockSeleccionado.value != null && !stockSeleccionado.value.precio_sugerido_ars)

const precioBase = computed(() => {
  // Dispensa inmediata: suma del carrito (cada línea por su precio sugerido).
  if (esDispensaInmediata.value) {
    if (!items.value.length) return null
    const total = items.value.reduce((a, it) => a + precioLinea(it) * it.cantidad, 0)
    return total > 0 ? total : null
  }
  // Reserva / entregar reserva: un solo producto (con precio manual si el stock no tiene).
  const s   = stockSeleccionado.value
  const cnt = parseFloat(form.value.cantidad) || 0
  if (!s || cnt <= 0) return null
  const ppu = s.precio_sugerido_ars
    ? parseFloat(s.precio_sugerido_ars)
    : (parseFloat(precioUnitarioManual.value) || 0)
  if (ppu <= 0) return null
  return ppu * cnt
})

// Descuento del paciente (de la ficha, privado) + descuento de la dispensa (puntual del modal),
// aditivos con tope 100%. El dispensador no ve el del paciente, pero igual se refleja en el total.
const descPacientePct = computed(() => Math.max(0, Math.min(100, Number(props.descuentoPorcentaje) || 0)))
const descDispensaPct = computed(() => Math.max(0, Math.min(100, Number(form.value.descuento_pct) || 0)))
const descTotalPct    = computed(() => Math.min(100, descPacientePct.value + descDispensaPct.value))

const precioFinal = computed(() => {
  if (precioBase.value == null) return null
  return precioBase.value * (1 - descTotalPct.value / 100)
})

watch(precioFinal, (val) => { if (val != null) form.value.aporte_socio_ars = Math.round(val) })
// Al quedar bloqueado (socio sin CC), forzar el aporte al total exacto.
watch(aporteBloqueado, (locked) => { if (locked && precioFinal.value != null) form.value.aporte_socio_ars = Math.round(precioFinal.value) })

watch(() => props.modelValue, (open) => {
  if (open) {
    form.value = emptyForm()
    items.value = []
    precioUnitarioManual.value = null
    formError.value = null
    deliveryUsers.value = []
    cargarStocks()
    // Modo entrega de reserva: pre-cargar producto/cantidad de la reserva.
    if (modoReserva.value) {
      form.value.es_reserva = false
      form.value.stock_id   = props.reserva.stock?.id ?? props.reserva.stock_id ?? null
      form.value.cantidad   = Number(props.reserva.cantidad) || null
      form.value.medio_pago = 'efectivo'
    } else if (props.modoInicial === 'reserva' && puedeReservar.value) {
      // Abierto desde el botón "Reservar" (admin/supervisor).
      form.value.es_reserva = true
    }
  }
}, { immediate: true })

function cerrar() { emit('update:modelValue', false) }

// Compone la dirección de entrega a partir de los campos estructurados (para reservas,
// que guardan texto). Si se usa el domicilio del paciente, lo resuelve el backend.
function composeDireccion() {
  if (form.value.usar_domicilio_paciente) return undefined
  const l1 = [form.value.envio_calle, form.value.envio_altura].filter(Boolean).join(' ')
  const pd = [
    form.value.envio_piso  && `Piso ${form.value.envio_piso}`,
    form.value.envio_depto && `Depto ${form.value.envio_depto}`,
  ].filter(Boolean).join(' ')
  return [l1, pd, form.value.envio_barrio, form.value.envio_ciudad].filter(Boolean).join(', ') || undefined
}

async function handleSubmit() {
  if (saving.value) return
  saving.value = true
  formError.value = null

  // Dispensa inmediata: validamos el carrito. Reserva / entregar reserva: un solo producto.
  if (esDispensaInmediata.value) {
    if (!items.value.length) { formError.value = 'Agregá al menos un producto al carrito'; saving.value = false; return }
  } else {
    if (!form.value.stock_id) { formError.value = 'Seleccioná un stock'; saving.value = false; return }
    if (!form.value.cantidad || form.value.cantidad <= 0) { formError.value = 'La cantidad debe ser > 0'; saving.value = false; return }
    // En modo reserva el backend libera el stock apartado de la propia reserva, así que
    // no aplicamos el chequeo de disponible local (mostraría de menos por su propio hold).
    if (!modoReserva.value && excederiaStock.value) {
      formError.value = `Stock insuficiente: solo hay ${stockSeleccionado.value.cantidad}${stockSeleccionado.value.unidad || 'g'} disponibles`
      saving.value = false; return
    }
  }

  // ── Rama ENTREGAR RESERVA: convierte la reserva en dispensación, cobra el resto ──
  if (modoReserva.value) {
    const cobrarDelivery = form.value.medio_pago === 'contra_entrega'
    if (!cobrarDelivery && form.value.medio_pago === 'cuenta_corriente' && !tieneCc.value) {
      formError.value = 'El paciente no tiene crédito configurado para cobrar por cuenta corriente'; saving.value = false; return
    }
    if (form.value.con_envio && !form.value.delivery_id) {
      formError.value = 'Seleccioná un delivery para asignar el envío'; saving.value = false; return
    }
    try {
      const payload = {
        cantidad:          form.value.cantidad,
        con_envio:         form.value.con_envio,
        cobrar_en_entrega: cobrarDelivery,
      }
      if (!cobrarDelivery && restoReserva.value > 0) {
        payload.cobros = [{ medio: form.value.medio_pago, monto: Number(restoReserva.value).toFixed(2) }]
      }
      if (form.value.con_envio) {
        payload.delivery_id             = form.value.delivery_id
        payload.usar_domicilio_paciente = form.value.usar_domicilio_paciente
        payload.envio_calle       = form.value.envio_calle || undefined
        payload.envio_altura      = form.value.envio_altura || undefined
        payload.envio_piso        = form.value.envio_piso || undefined
        payload.envio_depto       = form.value.envio_depto || undefined
        payload.envio_barrio      = form.value.envio_barrio || undefined
        payload.envio_ciudad      = form.value.envio_ciudad || undefined
        payload.contacto_nombre   = form.value.contacto_nombre || undefined
        payload.contacto_telefono = form.value.contacto_telefono || undefined
      }
      await entregarReserva(props.reserva.id, payload)
      cerrar()
      toast.success('Reserva entregada')
      emit('saved')
    } catch (e) {
      const msg = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al entregar la reserva'
      formError.value = msg; toast.error(msg)
    } finally { saving.value = false }
    return
  }

  // ── Rama RESERVA: aparta stock para una fecha futura, no se entrega ahora ──
  if (form.value.es_reserva) {
    if (!form.value.fecha_entrega_estimada) {
      formError.value = 'Indicá la fecha de entrega estimada'; saving.value = false; return
    }
    if (Number(form.value.sena_ars) > Number(form.value.aporte_socio_ars || 0)) {
      formError.value = 'La seña no puede superar el total estimado'; saving.value = false; return
    }
    try {
      // El envío (delivery/dirección) NO se define al reservar — se define al entregar.
      const payload = {
        stock_id: form.value.stock_id,
        cantidad: form.value.cantidad,
        fecha_entrega_estimada: form.value.fecha_entrega_estimada,
        medio_pago: form.value.medio_pago,
        notas: form.value.observaciones || undefined,
      }
      if (form.value.aporte_socio_ars) payload.aporte_estimado_ars = Number(form.value.aporte_socio_ars).toFixed(2)
      if (form.value.sena_ars)         payload.sena_ars = Number(form.value.sena_ars).toFixed(2)
      await createReserva(props.socioId, payload)
      cerrar()
      toast.success('Reserva creada')
      emit('saved')
    } catch (e) {
      const msg = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al crear la reserva'
      formError.value = msg
      toast.error(msg)
    } finally { saving.value = false }
    return
  }
  // Aporte obligatorio para todos los medios de pago
  // Un regalo es gratis: no valida aporte ni crédito (el stock igual se descuenta).
  if (!form.value.es_regalo) {
    if (!(Number(form.value.aporte_socio_ars) > 0)) {
      const sinPrecio = items.value.some(it => !(precioLinea(it) > 0))
      formError.value = sinPrecio
        ? (puedeEditarAporte.value
            ? 'Cargá el precio de los productos sin precio (campo $/u en el carrito).'
            : 'Hay un producto sin precio configurado. Pedile al administrador que lo cargue.')
        : 'El aporte del paciente debe ser mayor a $0.'
      saving.value = false; return
    }
    if (!cobraDelivery.value && form.value.medio_pago === 'cuenta_corriente' && !tieneCc.value) {
      formError.value = 'El paciente no tiene crédito configurado para cobrar por cuenta corriente'
      saving.value = false; return
    }
    if (!cobraDelivery.value && ccInsuficiente.value) {
      const msg = puedeVerCredito.value
        ? `Crédito insuficiente. Disponible: ${fmt(ccMargen.value)} — requerido: ${fmt(form.value.aporte_socio_ars)}`
        : 'Crédito insuficiente. Consultá con un administrador.'
      formError.value = msg
      saving.value = false; return
    }
    // Solo un socio con cuenta corriente puede pagar un monto ≠ al total: el excedente se le
    // acredita, el faltante queda a cuenta. Sin CC (y pagando en efectivo/transferencia), el
    // aporte debe ser exactamente el total.
    if (!cobraDelivery.value && !tieneCc.value && !esMedioCredito.value &&
        precioFinal.value != null &&
        Math.abs((Number(form.value.aporte_socio_ars) || 0) - Math.round(precioFinal.value)) > 0.01) {
      formError.value = 'El socio no tiene cuenta corriente: el monto debe ser igual al total. Solo con cuenta corriente se puede pagar de más (se acredita) o de menos (queda a cuenta).'
      saving.value = false; return
    }
  }


  if (form.value.con_envio) {
    if (!form.value.delivery_id) { formError.value = 'Seleccioná un delivery para asignar el envío'; saving.value = false; return }
    if (!form.value.usar_domicilio_paciente) {
      if (!form.value.envio_calle?.trim() || !form.value.envio_altura?.trim() || !form.value.envio_ciudad?.trim()) {
        formError.value = 'Completá calle, altura y ciudad de la dirección de entrega'; saving.value = false; return
      }
    }
  }

  try {
    const payload = {
      // Multi-item: una dispensa con varias líneas. El backend recalcula el precio de cada
      // línea (con el descuento del socio) y suma el total.
      items: items.value.map(it => {
        const l = { stock_id: it.stock.id, cantidad: it.cantidad }
        // La línea sale de lo apartado para un evento en curso (el backend imputa la cantidad
        // a la provisión, así el apartado se libera y no hay doble descuento).
        if (it.desdeEvento) l.evento_bar_id = it.desdeEvento
        // Precio manual solo cuando el stock no tiene precio configurado.
        if (!(Number(it.stock.precio_sugerido_ars) > 0) && Number(it.precioManual) > 0) {
          l.precio_manual_ars = Number(it.precioManual)
          l.guardar_precio    = !!it.guardarPrecio
        }
        return l
      }),
      fecha_dispensacion: form.value.fecha_dispensacion,
      observaciones: form.value.observaciones || undefined,
      medio_pago: (form.value.es_regalo || cobraDelivery.value) ? undefined : form.value.medio_pago, con_envio: form.value.con_envio,
      // Descuento de la dispensa (puntual). El del paciente lo aplica el server desde la ficha.
      descuento_dispensa_pct: descDispensaPct.value,
    }
    if (form.value.es_regalo) payload.es_regalo = true
    // El total lo calcula el server (descuento paciente + dispensa). Solo admin/supervisor
    // pueden pisar el aporte a mano (sobre el total del carrito); el dispensador no manda aporte.
    // En un regalo no se manda aporte (el server lo fuerza a 0).
    else if (puedeEditarAporte.value && form.value.aporte_socio_ars != null && form.value.aporte_socio_ars !== '')
      payload.aporte_socio_ars = Number(form.value.aporte_socio_ars).toFixed(2)
    if (form.value.con_envio) {
      payload.cobrar_en_entrega = cobraDelivery.value
      payload.delivery_id       = form.value.delivery_id
      payload.usar_domicilio_paciente = form.value.usar_domicilio_paciente
      payload.envio_calle       = form.value.envio_calle || undefined
      payload.envio_altura      = form.value.envio_altura || undefined
      payload.envio_piso        = form.value.envio_piso || undefined
      payload.envio_depto       = form.value.envio_depto || undefined
      payload.envio_barrio      = form.value.envio_barrio || undefined
      payload.envio_ciudad      = form.value.envio_ciudad || undefined
      payload.contacto_nombre   = form.value.contacto_nombre || undefined
      payload.contacto_telefono = form.value.contacto_telefono || undefined
      payload.notas_envio       = form.value.notas_envio || undefined
    }
    const res = await dispensarOffline(props.socioId, payload)
    cerrar()
    toast[res?.queued ? 'warning' : 'success'](
      res?.queued ? 'Dispensación guardada localmente — se enviará al reconectarse.' : 'Dispensación registrada'
    )
    emit('saved')
  } catch (e) {
    const msg = e.response?.data?.errors?.[0] || e.response?.data?.error || 'Error al guardar'
    formError.value = msg
    toast.error(msg)
  } finally { saving.value = false }
}
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue" class="mnd__overlay">
      <div class="mnd__modal">

        <div class="mnd__modal-header">
          <h3 class="mnd__modal-title">
            <template v-if="modoReserva">Entregar reserva<template v-if="props.pacienteNombre"> de <span class="mnd__modal-title-paciente">{{ props.pacienteNombre }}</span></template></template>
            <template v-else>Nueva dispensación<template v-if="props.pacienteNombre"> para <span class="mnd__modal-title-paciente">{{ props.pacienteNombre }}</span></template></template>
          </h3>
          <button class="mnd__modal-close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mnd__modal-body">
          <div v-if="formError" class="mnd__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>

          <!-- Seña / resto a cobrar (modo entrega de reserva) -->
          <div v-if="modoReserva" class="mnd__reserva-info">
            <i class="bi bi-bookmark-star"></i>
            <span>Convertís la reserva en dispensación.
              <template v-if="senaReserva > 0">Seña ya pagada <strong>{{ fmt(senaReserva) }}</strong> · </template>
              A cobrar ahora: <strong>{{ fmt(restoReserva) }}</strong>
            </span>
          </div>

          <!-- Tipo: entrega inmediata o reserva (reservas solo admin/supervisor) -->
          <div v-if="!modoReserva && puedeReservar" class="mnd__segmented">
            <button type="button" class="mnd__seg-btn" :class="{ 'mnd__seg-btn--active': !form.es_reserva }" @click="form.es_reserva = false">
              <i class="bi bi-bag-check"></i> Entrega inmediata
            </button>
            <button type="button" class="mnd__seg-btn" :class="{ 'mnd__seg-btn--active': form.es_reserva }" @click="form.es_reserva = true">
              <i class="bi bi-bookmark-star"></i> Reserva
            </button>
          </div>

          <!-- Stock de la reserva (solo lectura) -->
          <template v-if="modoReserva">
            <div class="mnd__section-label">Producto reservado</div>
            <div class="mnd__stock-row mnd__stock-row--active" style="cursor:default">
              <span class="mnd__stock-emoji">{{ FORMA_EMOJI[props.reserva.stock?.forma_producto] || '📦' }}</span>
              <span class="mnd__stock-info">
                <span class="mnd__stock-nombre">{{ FORMA_LABEL[props.reserva.stock?.forma_producto] || props.reserva.stock?.forma_producto || '—' }}</span>
                <span v-if="props.reserva.stock?.lote" class="mnd__stock-gen">Lote {{ props.reserva.stock.lote }}</span>
              </span>
              <span class="mnd__stock-right">
                <span class="mnd__stock-disp">{{ props.reserva.cantidad }}{{ props.reserva.stock?.unidad || 'g' }}</span>
              </span>
            </div>
          </template>

          <!-- Stock -->
          <div v-if="!modoReserva" class="mnd__section-label">{{ esDispensaInmediata ? 'Agregar producto' : 'Stock a reservar' }} <span class="mnd__req">*</span></div>
          <div v-if="modoReserva"></div>
          <!-- Paso 1: la sede. Sólo cuando hay más de una: si la organización tiene una sola, elegirla
               sería un clic de peaje y se selecciona sola. -->
          <div v-if="hayVariasSedes && !loadingStocks" class="mnd__sedes">
            <span class="mnd__sedes-lbl">¿De qué sede?</span>
            <div class="mnd__sedes-chips">
              <button
                v-for="sd in sedesConStock" :key="sd.id ?? 'pool'"
                type="button"
                class="mnd__sede-chip"
                :class="{ 'mnd__sede-chip--on': sedeElegida === sd.id }"
                @click="sedeElegida = sd.id"
              >
                {{ sd.nombre }}
                <span class="mnd__sede-n">{{ sd.items }}</span>
              </button>
            </div>
          </div>

          <div v-else-if="loadingStocks" class="mnd__loading-inline"><DsSpinner :size="13" /> Cargando stocks…</div>
          <div v-if="hayVariasSedes && sedeElegida === undefined" class="mnd__hint-box">
            <i class="bi bi-arrow-up"></i> Elegí una sede para ver su stock.
          </div>
          <div v-else-if="!loadingStocks && !stocksDisponibles.length" class="mnd__warn-box">
            <i class="bi bi-exclamation-triangle"></i> Sin stock disponible{{ hayVariasSedes ? ' en esta sede' : '' }}
          </div>
          <div v-else class="mnd__stock-list">
            <button
              v-for="s in stocksDisponibles" :key="s.id"
              type="button"
              class="mnd__stock-row"
              :class="{ 'mnd__stock-row--active': form.stock_id === s.id }"
              @click="form.stock_id = s.id"
            >
              <span class="mnd__stock-emoji">{{ FORMA_EMOJI[s.forma_producto] || '📦' }}</span>
              <span class="mnd__stock-info">
                <span class="mnd__stock-nombre">{{ FORMA_LABEL[s.forma_producto] || s.forma_producto }}</span>
                <span v-if="s.genetica?.nombre || s.lote?.genetica?.nombre" class="mnd__stock-gen">{{ s.genetica?.nombre || s.lote.genetica.nombre }}</span>
                <span v-if="fmtFecha(s.fecha_elaboracion || s.created_at)" class="mnd__stock-fecha">
                  {{ fmtFecha(s.fecha_elaboracion || s.created_at) }}
                </span>
              </span>
              <span class="mnd__stock-right">
                <span class="mnd__stock-disp">{{ s.cantidad }}{{ s.unidad }}</span>
                <span v-for="a in (s.apartados_evento || [])" :key="a.evento_id" class="mnd__stock-evento" :title="`Apartado para el evento ${a.evento_nombre}`">
                  🎉 {{ a.cantidad }}{{ s.unidad }}
                </span>
                <span v-if="s.precio_sugerido_ars" class="mnd__stock-precio">
                  {{ fmt(s.precio_sugerido_ars) }}/{{ s.unidad || 'g' }}
                </span>
              </span>
              <span class="mnd__stock-check" v-if="form.stock_id === s.id"><i class="bi bi-check-circle-fill"></i></span>
            </button>
          </div>

          <!-- Origen: stock libre o lo apartado para un evento EN CURSO -->
          <div v-if="!modoReserva && apartadosDelStock.length" class="mnd__evento-box">
            <div class="mnd__evento-title">
              <i class="bi bi-calendar-event"></i>
              Hay stock reservado para un evento en curso
            </div>
            <label v-for="a in apartadosDelStock" :key="a.evento_id" class="mnd__evento-opt">
              <input type="checkbox" :checked="desdeEvento === a.evento_id"
                     @change="desdeEvento = desdeEvento === a.evento_id ? null : a.evento_id" />
              <span>
                Dispensar desde lo reservado para <b>{{ a.evento_nombre }}</b>
                <small>{{ a.cantidad }}{{ stockSeleccionado?.unidad || 'g' }} apartados</small>
              </span>
            </label>
            <p class="mnd__evento-hint">
              Sin tildar, la entrega sale del stock libre y lo apartado del evento queda intacto.
            </p>
          </div>

          <!-- Precio manual (solo al reservar un stock sin precio) -->
          <div v-if="form.es_reserva && necesitaPrecioManual" class="mnd__field">
            <label class="mnd__label">
              Precio por {{ stockSeleccionado?.unidad || 'g' }}
              <span class="mnd__opt">solo para el cálculo — no se guarda</span>
            </label>
            <div class="mnd__input-suffix-wrap">
              <span class="mnd__input-prefix">$</span>
              <input v-model.number="precioUnitarioManual" type="number" min="0" step="1"
                     class="mnd__input mnd__input--with-prefix" placeholder="0" />
            </div>
          </div>

          <div v-if="!modoReserva" class="mnd__divider"></div>

          <!-- Cantidad: en dispensa inmediata se carga y se "Agrega" al carrito; en reserva es único -->
          <div v-if="!modoReserva" class="mnd__form-row">
            <div class="mnd__field">
              <label class="mnd__label">Cantidad <span class="mnd__req">*</span></label>
              <div class="mnd__input-suffix-wrap">
                <input v-model.number="form.cantidad" type="number" step="0.01" min="0.01"
                       class="mnd__input mnd__input--with-suffix"
                       :class="{ 'mnd__input--error': excederiaStock }"
                       placeholder="0"
                       @keyup.enter="esDispensaInmediata && agregarItem()" />
                <span class="mnd__input-suffix">{{ stockSeleccionado?.unidad || 'g' }}</span>
              </div>
              <span v-if="excederiaStock" class="mnd__field-error">
                Máximo {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }} disponibles
              </span>
              <span v-else-if="stockSeleccionado && form.cantidad" class="mnd__field-hint">
                Disponible: {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }}
              </span>
            </div>
            <!-- Inmediata: sumar la línea al carrito. Reserva: descuento al lado. -->
            <div v-if="esDispensaInmediata" class="mnd__field mnd__add-field">
              <label class="mnd__label">&nbsp;</label>
              <button type="button" class="mnd__add-item"
                      :disabled="!form.stock_id || !form.cantidad || excederiaStock" @click="agregarItem">
                <i class="bi bi-plus-lg"></i> Agregar item
              </button>
            </div>
            <div v-else class="mnd__field">
              <label class="mnd__label">Descuento <span class="mnd__opt">esta dispensa</span></label>
              <div class="mnd__input-suffix-wrap">
                <input v-model.number="form.descuento_pct" type="number" step="1" min="0" max="100"
                       class="mnd__input mnd__input--with-suffix" placeholder="0" />
                <span class="mnd__input-suffix">%</span>
              </div>
            </div>
          </div>

          <!-- Carrito de la dispensa (multi-item) -->
          <div v-if="esDispensaInmediata && items.length" class="mnd__cart">
            <div class="mnd__section-label">Carrito · {{ items.length }} {{ items.length === 1 ? 'producto' : 'productos' }}</div>
            <div v-for="(it, i) in items" :key="i" class="mnd__cart-item">
              <span class="mnd__cart-emoji">{{ FORMA_EMOJI[it.stock.forma_producto] || '📦' }}</span>
              <span class="mnd__cart-info">
                <span class="mnd__cart-nombre">
                  {{ FORMA_LABEL[it.stock.forma_producto] || it.stock.forma_producto }}
                  <span v-if="it.desdeEvento" class="mnd__cart-evento" :title="`Sale de lo reservado para ${eventoDe(it.desdeEvento)?.evento_nombre || 'el evento'}`">
                    🎉 {{ eventoDe(it.desdeEvento)?.evento_nombre || 'evento' }}
                  </span>
                </span>
                <!-- "Flor seca" sola no alcanza para saber QUÉ se puso en el carrito: hay
                     varios stocks de la misma forma. La genética y el lote lo desambiguan. -->
                <span v-if="detalleStock(it.stock)" class="mnd__cart-detalle">{{ detalleStock(it.stock) }}</span>
                <span class="mnd__cart-qty">{{ it.cantidad }}{{ it.stock.unidad || 'g' }}</span>
              </span>
              <span
                v-if="!(Number(it.stock.precio_sugerido_ars) > 0) && puedeEditarAporte"
                class="mnd__cart-precio"
              >
                <span class="mnd__cart-precio-sign">$</span>
                <input v-model.number="it.precioManual" type="number" min="0" step="1" placeholder="precio/u" class="mnd__cart-precio-input" />
                <label class="mnd__cart-guardar" title="Guardar este precio en el producto">
                  <input type="checkbox" v-model="it.guardarPrecio" /> guardar
                </label>
              </span>
              <span class="mnd__cart-sub">{{ subtotalItem(it) > 0 ? fmt(subtotalItem(it)) : 'sin precio' }}</span>
              <button type="button" class="mnd__cart-rm" @click="quitarItem(i)" title="Quitar"><i class="bi bi-x-lg"></i></button>
            </div>
          </div>

          <!-- Descuento global (dispensa inmediata): aplica a la suma del carrito -->
          <div v-if="esDispensaInmediata" class="mnd__field">
            <label class="mnd__label">Descuento <span class="mnd__opt">esta dispensa — sobre el total</span></label>
            <div class="mnd__input-suffix-wrap mnd__desc-input">
              <input v-model.number="form.descuento_pct" type="number" step="1" min="0" max="100"
                     class="mnd__input mnd__input--with-suffix" placeholder="0" />
              <span class="mnd__input-suffix">%</span>
            </div>
          </div>

          <!-- Precio + aporte -->
          <div v-if="!modoReserva" class="mnd__aporte-wrap">
            <div v-if="precioFinal != null" class="mnd__precio-box">
              <!-- Desglose completo: solo admin/supervisor -->
              <template v-if="puedeVerDescPaciente">
                <div class="mnd__precio-row"><span>Precio base</span><span>{{ fmt(precioBase) }}</span></div>
                <div v-if="descPacientePct > 0" class="mnd__precio-row mnd__precio-row--desc">
                  <span>Descuento paciente {{ descPacientePct }}%</span>
                  <span>- {{ fmt(precioBase * descPacientePct / 100) }}</span>
                </div>
                <div v-if="descDispensaPct > 0" class="mnd__precio-row mnd__precio-row--desc">
                  <span>Descuento esta dispensa {{ descDispensaPct }}%</span>
                  <span>- {{ fmt(precioBase * descDispensaPct / 100) }}</span>
                </div>
                <div class="mnd__precio-row mnd__precio-row--total"><span>Total</span><span>{{ fmt(precioFinal) }}</span></div>
              </template>
              <!-- Dispensador: solo el total final (sin desglose ni descuento del paciente) -->
              <div v-else class="mnd__precio-row mnd__precio-row--total"><span>Total a cobrar</span><span>{{ fmt(precioFinal) }}</span></div>
            </div>
            <!-- Override del aporte: solo admin/supervisor -->
            <div v-if="puedeEditarAporte" class="mnd__field">
              <label class="mnd__label">Aporte del paciente
                <span class="mnd__opt">{{ aporteBloqueado ? 'ARS — fijo al total (socio sin cuenta corriente)' : 'ARS — editable' }}</span>
              </label>
              <div class="mnd__input-suffix-wrap">
                <span class="mnd__input-prefix">$</span>
                <input v-model.number="form.aporte_socio_ars" type="number" min="0" step="1"
                       :readonly="aporteBloqueado"
                       class="mnd__input mnd__input--with-prefix" placeholder="0" />
              </div>
            </div>
          </div>

          <!-- Crédito: visible a quien dispensa al elegir cuenta corriente; admin/sup siempre -->
          <div v-if="mostrarPanelCredito" class="mnd__cc-panel" :class="`mnd__cc-panel--${estadoCc || 'ok'}`">
            <div class="mnd__cc-row">
              <span class="mnd__cc-label"><i class="bi bi-wallet2"></i> Crédito disponible</span>
              <span class="mnd__cc-saldo" :class="{ 'mnd__cc-saldo--bajo': ccMargen <= 0 }">{{ fmt(ccMargen) }}</span>
            </div>
            <!-- Cuenta corriente: cuánto cae al crédito y cuánto se cobra ahora -->
            <template v-if="esCuentaCorriente && Number(form.aporte_socio_ars) > 0">
              <div class="mnd__cc-tras">Se carga al crédito: <strong>{{ fmt(montoACredito) }}</strong></div>
              <div v-if="restoACobrar > 0" class="mnd__cc-warn">
                <i class="bi bi-cash-coin"></i>
                El crédito no alcanza — a cobrar ahora: <strong>{{ fmt(restoACobrar) }}</strong>
              </div>
              <div v-else class="mnd__cc-tras">Crédito restante luego: <strong>{{ fmt(ccMargen - montoACredito) }}</strong></div>
            </template>
            <!-- No abona: tiene que entrar entero en el crédito -->
            <div v-if="ccInsuficiente" class="mnd__cc-warn">
              <i class="bi bi-exclamation-triangle-fill"></i>
              Crédito insuficiente — disponible: {{ fmt(ccMargen) }}, requerido: {{ fmt(form.aporte_socio_ars) }}
            </div>
          </div>

          <!-- Fecha + pago -->
          <div class="mnd__form-row">
            <div class="mnd__field">
              <label class="mnd__label" v-if="form.es_reserva">Fecha de entrega estimada <span class="mnd__req">*</span></label>
              <label class="mnd__label" v-else>Fecha</label>
              <AppDatePicker v-if="form.es_reserva" v-model="form.fecha_entrega_estimada" :min="tomorrow" />
              <AppDatePicker v-else v-model="form.fecha_dispensacion" :max="today" />
            </div>
            <div v-if="!form.es_regalo" class="mnd__field">
              <label class="mnd__label">{{ modoReserva ? 'Medio de pago del resto' : (form.es_reserva ? 'Medio de pago de la seña' : 'Medio de pago') }}</label>
              <select v-model="form.medio_pago" class="mnd__input">
                <option value="efectivo">Efectivo</option>
                <option value="transferencia">Transferencia</option>
                <!-- Cuenta corriente y contra-entrega no aplican a la seña de una reserva -->
                <option v-if="!form.es_reserva" value="cuenta_corriente" :disabled="!tieneCc">Cuenta corriente{{ !tieneCc ? ' (sin límite configurado)' : '' }}</option>
                <option v-if="!form.es_reserva" value="contra_entrega">Contra entrega (cobra el delivery)</option>
              </select>
            </div>
          </div>

          <!-- Regalo: entrega gratis (solo admin/supervisor, dispensa inmediata) -->
          <label v-if="puedeEditarAporte && !form.es_reserva && !modoReserva" class="mnd__regalo">
            <input type="checkbox" v-model="form.es_regalo" />
            <span>
              🎁 Es un regalo <span class="mnd__opt">no cobra, no toca la cuenta corriente; el stock igual se descuenta</span>
            </span>
          </label>

          <!-- Seña (solo reserva) -->
          <div v-if="form.es_reserva" class="mnd__field">
            <label class="mnd__label">Seña <span class="mnd__opt">opcional — se cobra ahora, el resto al entregar</span></label>
            <div class="mnd__input-suffix-wrap">
              <span class="mnd__input-prefix">$</span>
              <input v-model.number="form.sena_ars" type="number" min="0" step="1"
                     class="mnd__input mnd__input--with-prefix" placeholder="0" />
            </div>
            <span v-if="form.sena_ars > 0 && form.aporte_socio_ars" class="mnd__field-hint">
              Resto a cobrar al entregar: {{ fmt(Math.max(0, Number(form.aporte_socio_ars) - Number(form.sena_ars))) }}
            </span>
          </div>

          <!-- Observaciones -->
          <div class="mnd__field">
            <label class="mnd__label">Observaciones <span class="mnd__opt">opcional</span></label>
            <textarea v-model.trim="form.observaciones" class="mnd__input mnd__textarea" rows="2"
                      placeholder="Notas adicionales…"></textarea>
          </div>

          <div class="mnd__divider"></div>

          <!-- Reserva: el envío se define al entregar, no al reservar -->
          <div v-if="form.es_reserva" class="mnd__warn-box" style="background:#eff6ff;border-color:#bfdbfe;color:#1e40af">
            <i class="bi bi-info-circle"></i> El delivery y la dirección se definen al momento de crear la dispensación en base a la reserva.
          </div>

          <!-- Delivery (solo entrega inmediata) -->
          <div v-if="!form.es_reserva" class="mnd__delivery-toggle" @click="form.con_envio = !form.con_envio">
            <div class="mnd__delivery-toggle-left">
              <i class="bi bi-bicycle" style="font-size:1rem;color:#1b5e20"></i>
              <div>
                <div class="mnd__delivery-toggle-title">Con envío a domicilio</div>
                <div class="mnd__delivery-toggle-sub">Asignar un delivery y datos de entrega</div>
              </div>
            </div>
            <div class="mnd__toggle-switch" :class="{ 'mnd__toggle-switch--on': form.con_envio }">
              <div class="mnd__toggle-knob"></div>
            </div>
          </div>

          <div v-if="form.con_envio" class="mnd__delivery-section">
            <div v-if="!form.es_reserva" class="mnd__field">
              <label class="mnd__label">Delivery asignado <span class="mnd__req">*</span></label>
              <div v-if="loadingDelivery" class="mnd__loading-inline"><DsSpinner :size="13" /> Cargando…</div>
              <div v-else-if="deliveryError" class="mnd__warn-box">
                <i class="bi bi-exclamation-triangle"></i> {{ deliveryError }}
                <button type="button" class="mnd__warn-retry" @click="cargarDeliveryUsers">Reintentar</button>
              </div>
              <div v-else-if="!deliveryUsers.length" class="mnd__warn-box">
                <i class="bi bi-exclamation-triangle"></i> No hay nadie con rol delivery, admin o supervisor para asignar
              </div>
              <select v-else v-model.number="form.delivery_id" class="mnd__input">
                <option :value="null" disabled>Seleccioná un delivery…</option>
                <option v-for="u in deliveryUsers" :key="u.id" :value="u.id">
                  {{ u.nombre || u.first_name || u.email }}<template v-if="u.role && u.role !== 'delivery'"> · {{ u.role }}</template>
                </option>
              </select>
            </div>
            <div v-else class="mnd__field-hint" style="margin-bottom:.5rem">
              El delivery se asigna al entregar la reserva.
            </div>

            <!-- Dirección de entrega: domicilio del paciente u otra -->
            <div class="mnd__field">
              <label class="mnd__label">Dirección de entrega</label>
              <div class="mnd__segmented mnd__segmented--sm">
                <button type="button" class="mnd__seg-btn" :class="{ 'mnd__seg-btn--active': form.usar_domicilio_paciente }" @click="form.usar_domicilio_paciente = true">
                  <i class="bi bi-house"></i> Domicilio del paciente
                </button>
                <button type="button" class="mnd__seg-btn" :class="{ 'mnd__seg-btn--active': !form.usar_domicilio_paciente }" @click="form.usar_domicilio_paciente = false">
                  <i class="bi bi-geo-alt"></i> Otra dirección
                </button>
              </div>
            </div>

            <div v-if="form.usar_domicilio_paciente" class="mnd__field-hint">
              Se enviará al domicilio registrado del paciente. Si no tiene uno cargado, elegí "Otra dirección".
            </div>

            <template v-else>
              <div class="mnd__form-row">
                <div class="mnd__field" style="flex:2">
                  <label class="mnd__label">Calle <span class="mnd__req">*</span></label>
                  <input v-model.trim="form.envio_calle" type="text" class="mnd__input" placeholder="Av. Siempreviva" />
                </div>
                <div class="mnd__field">
                  <label class="mnd__label">Altura <span class="mnd__req">*</span></label>
                  <input v-model.trim="form.envio_altura" type="text" class="mnd__input" placeholder="742" />
                </div>
              </div>
              <div class="mnd__form-row">
                <div class="mnd__field">
                  <label class="mnd__label">Piso <span class="mnd__opt">opc.</span></label>
                  <input v-model.trim="form.envio_piso" type="text" class="mnd__input" placeholder="3" />
                </div>
                <div class="mnd__field">
                  <label class="mnd__label">Depto <span class="mnd__opt">opc.</span></label>
                  <input v-model.trim="form.envio_depto" type="text" class="mnd__input" placeholder="B" />
                </div>
              </div>
              <div class="mnd__form-row">
                <div class="mnd__field">
                  <label class="mnd__label">Barrio <span class="mnd__opt">opc.</span></label>
                  <input v-model.trim="form.envio_barrio" type="text" class="mnd__input" placeholder="Palermo" />
                </div>
                <div class="mnd__field">
                  <label class="mnd__label">Ciudad <span class="mnd__req">*</span></label>
                  <input v-model.trim="form.envio_ciudad" type="text" class="mnd__input" placeholder="CABA" />
                </div>
              </div>
            </template>
            <div class="mnd__form-row">
              <div class="mnd__field">
                <label class="mnd__label">Contacto <span class="mnd__req">*</span></label>
                <input v-model.trim="form.contacto_nombre" type="text" class="mnd__input"
                       placeholder="Nombre de quien recibe" />
              </div>
              <div class="mnd__field">
                <label class="mnd__label">Teléfono <span class="mnd__opt">opcional</span></label>
                <input v-model.trim="form.contacto_telefono" type="tel" class="mnd__input" placeholder="+54 11 …" />
              </div>
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Notas de envío <span class="mnd__opt">opcional</span></label>
              <textarea v-model.trim="form.notas_envio" class="mnd__input mnd__textarea" rows="2"
                        placeholder="Instrucciones para el delivery…"></textarea>
            </div>
          </div>

        </div>

        <div class="mnd__modal-footer">
          <button class="mnd__btn-ghost" :disabled="saving" @click="cerrar">Cancelar</button>
          <button class="mnd__btn-primary" :disabled="saving || (esDispensaInmediata ? !items.length : !form.stock_id) || (esDispensaInmediata && ccInsuficiente)" @click="handleSubmit">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi" :class="form.es_reserva ? 'bi-bookmark-star' : 'bi-check-lg'"></i>
            {{ modoReserva ? 'Entregar reserva' : (form.es_reserva ? 'Crear reserva' : 'Registrar dispensación') }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mnd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.mnd__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 640px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }

.mnd__modal-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid var(--c-slate-100); position: sticky; top: 0; background: #fff; z-index: 1; }
.mnd__modal-title { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mnd__modal-title-paciente { color: #15803d; font-weight: 800; }
.mnd__modal-close { background: var(--c-slate-100); border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: var(--c-slate-500); }
.mnd__modal-close:hover { background: var(--c-slate-200); }

.mnd__modal-body { padding: 1.1rem 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .9rem; }

/* Segmented entrega / reserva */
.mnd__segmented { display: flex; gap: .35rem; background: var(--c-slate-100); padding: .25rem; border-radius: 10px; }
.mnd__seg-btn { flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: .4rem; border: none; background: transparent; color: var(--c-slate-500); font-size: .82rem; font-weight: 700; padding: .5rem .75rem; border-radius: 8px; cursor: pointer; transition: all .15s; }
.mnd__seg-btn--active { background: #fff; color: #15803d; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
.mnd__segmented--sm .mnd__seg-btn { font-size: .78rem; padding: .4rem .5rem; }
.mnd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .875rem 1.25rem; border-top: 1px solid var(--c-slate-100); position: sticky; bottom: 0; background: #fff; }

.mnd__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; display: flex; align-items: center; gap: .4rem; }


/* Stock */
.mnd__section-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.mnd__stock-list { display: flex; flex-direction: column; gap: .35rem; max-height: 220px; overflow-y: auto; }
.mnd__stock-row { display: flex; align-items: center; gap: .75rem; padding: .6rem .875rem; border-radius: 10px; border: 1.5px solid var(--c-slate-200); background: #fafbfc; cursor: pointer; text-align: left; transition: all .12s; width: 100%; }
.mnd__stock-row:hover { border-color: #86efac; background: #f0fdf4; }
.mnd__stock-row--active { border-color: #1b5e20; background: #f0fdf4; }
.mnd__stock-emoji { font-size: 1.1rem; flex-shrink: 0; }
.mnd__stock-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.mnd__stock-nombre { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.mnd__stock-gen { font-size: .72rem; color: var(--c-slate-500); font-style: italic; }
.mnd__stock-fecha { font-size: .68rem; color: var(--c-slate-400); display: flex; align-items: center; gap: .25rem; }
.mnd__stock-right { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; flex-shrink: 0; }
.mnd__stock-disp  { font-size: .8rem; font-weight: 700; color: #1b5e20; font-family: monospace; }
.mnd__stock-precio { font-size: .7rem; color: var(--c-slate-500); font-family: monospace; white-space: nowrap; }
.mnd__stock-evento { font-size: .66rem; color: #6d28d9; background: #ede9fe; border-radius: 999px; padding: 1px 7px; white-space: nowrap; font-weight: 700; }
.mnd__cart-evento { font-size: .62rem; color: #6d28d9; background: #ede9fe; border-radius: 999px; padding: 1px 6px; margin-left: .35rem; font-weight: 700; }
.mnd__evento-box { background: #faf5ff; border: 1.5px solid #e9d5ff; border-radius: 10px; padding: .7rem .85rem; margin: .7rem 0; }
.mnd__evento-title { font-size: .78rem; font-weight: 700; color: #6d28d9; display: flex; align-items: center; gap: .4rem; margin-bottom: .45rem; }
.mnd__evento-opt { display: flex; align-items: flex-start; gap: .5rem; font-size: .8rem; color: var(--c-slate-700); cursor: pointer; padding: .2rem 0; }
.mnd__evento-opt small { display: block; color: #7c3aed; font-size: .7rem; }
.mnd__evento-hint { font-size: .72rem; color: #7c6f8a; margin: .4rem 0 0; }
.mnd__stock-check { color: #1b5e20; font-size: .9rem; flex-shrink: 0; }
/* Paso "de qué sede": chips, no un select. Son pocas y conviene verlas todas de una. */
.mnd__sedes { display: flex; flex-direction: column; gap: .4rem; margin-bottom: .6rem; }
.mnd__sedes-lbl { font-size: .74rem; font-weight: 700; color: var(--c-slate-600); }
.mnd__sedes-chips { display: flex; flex-wrap: wrap; gap: .4rem; }
.mnd__sede-chip {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .35rem .7rem; border-radius: 999px; cursor: pointer;
  border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700);
  font-size: .8rem; font-weight: 600; transition: all .12s;
}
.mnd__sede-chip:hover { border-color: var(--c-slate-300); background: var(--c-slate-50); }
.mnd__sede-chip--on { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.mnd__sede-n { font-size: .68rem; font-weight: 700; opacity: .75; }
.mnd__hint-box { background: var(--c-slate-50); border: 1px dashed var(--c-slate-300); border-radius: 8px; padding: .55rem .75rem; font-size: .8rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .4rem; }
.mnd__warn-box { background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; color: #92400e; display: flex; align-items: center; gap: .4rem; }

/* Agregar item + carrito */
.mnd__add-field { justify-content: flex-start; }
.mnd__add-item { width: 100%; display: inline-flex; align-items: center; justify-content: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; border-radius: 9px; padding: .6rem .8rem; font-size: .82rem; font-weight: 700; cursor: pointer; transition: background .15s; white-space: nowrap; }
.mnd__add-item:hover:not(:disabled) { background: #144a18; }
.mnd__add-item:disabled { opacity: .45; cursor: not-allowed; }
.mnd__desc-input { max-width: 140px; }
.mnd__cart { display: flex; flex-direction: column; gap: .35rem; }
.mnd__cart-item { display: flex; align-items: center; gap: .6rem; padding: .5rem .7rem; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 9px; }
.mnd__cart-emoji { font-size: 1rem; flex-shrink: 0; }
.mnd__cart-info { flex: 1; min-width: 0; display: flex; align-items: baseline; gap: .5rem; flex-wrap: wrap; }
.mnd__cart-nombre { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.mnd__cart-precio { display: inline-flex; align-items: center; gap: .3rem; flex-shrink: 0; }
.mnd__cart-precio-sign { font-size: .8rem; color: var(--c-slate-500); }
.mnd__cart-precio-input { width: 72px; padding: .25rem .4rem; border: 1.5px solid #86efac; border-radius: 6px; font-size: .8rem; color: var(--c-slate-900); background: #fff; outline: none; }
.mnd__cart-precio-input:focus { border-color: #15803d; }
.mnd__cart-guardar { display: inline-flex; align-items: center; gap: .2rem; font-size: .68rem; color: #15803d; cursor: pointer; white-space: nowrap; }
.mnd__warn-retry { margin-left: .5rem; background: none; border: none; color: #b45309; font-weight: 700; font-size: .75rem; text-decoration: underline; cursor: pointer; padding: 0; }
.mnd__cart-detalle { font-size: .72rem; color: var(--c-slate-500); font-style: italic; }
.mnd__cart-qty { font-size: .75rem; font-family: monospace; color: #15803d; font-weight: 700; }
.mnd__cart-sub { font-size: .8rem; font-weight: 700; color: #166534; font-family: monospace; white-space: nowrap; }
.mnd__cart-rm { background: none; border: none; color: var(--c-slate-400); cursor: pointer; padding: 2px 4px; display: flex; border-radius: 5px; }
.mnd__cart-rm:hover { color: #dc2626; background: #fef2f2; }

/* Form */
.mnd__divider { height: 1px; background: var(--c-slate-100); }
.mnd__reserva-info { display: flex; align-items: flex-start; gap: .5rem; padding: .6rem .75rem; margin-bottom: .75rem; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 9px; font-size: .82rem; color: #166534; }
.mnd__reserva-info i { margin-top: 1px; }
.mnd__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 400px) { .mnd__form-row { grid-template-columns: 1fr; } }
.mnd__field { display: flex; flex-direction: column; gap: .3rem; }
.mnd__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.mnd__req { color: #ef4444; }
.mnd__opt { font-size: .67rem; font-weight: 400; color: var(--c-slate-400); text-transform: none; letter-spacing: 0; }
.mnd__input { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .6rem .8rem; font-size: .875rem; color: var(--c-slate-900); width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s; }
.mnd__input:focus { border-color: #1b5e20; background: #fff; }
.mnd__input--error { border-color: #ef4444 !important; background: #fef2f2; }
.mnd__field-error { font-size: .72rem; color: #dc2626; font-weight: 600; }
.mnd__field-hint  { font-size: .72rem; color: var(--c-slate-400); }
.mnd__textarea { resize: vertical; min-height: 58px; }
.mnd__regalo { display: flex; align-items: flex-start; gap: .55rem; margin-top: .9rem; padding: .7rem .85rem; background: #faf5ff; border: 1.5px solid #e9d5ff; border-radius: 10px; font-size: .84rem; font-weight: 600; color: #6b21a8; cursor: pointer; }
.mnd__regalo input { margin-top: .15rem; accent-color: #7c3aed; }
.mnd__regalo .mnd__opt { display: block; font-weight: 400; color: #a78bca; margin-top: .1rem; }
.mnd__input-suffix-wrap { display: flex; }
.mnd__input--with-suffix { border-radius: 9px 0 0 9px; flex: 1; }
.mnd__input-suffix { background: var(--c-slate-100); border: 1.5px solid var(--c-slate-200); border-left: none; border-radius: 0 9px 9px 0; padding: .6rem .7rem; font-size: .8rem; color: var(--c-slate-500); white-space: nowrap; display: flex; align-items: center; }
.mnd__input--with-prefix { border-radius: 0 9px 9px 0; flex: 1; }
.mnd__input-prefix { background: var(--c-slate-100); border: 1.5px solid var(--c-slate-200); border-right: none; border-radius: 9px 0 0 9px; padding: .6rem .7rem; font-size: .8rem; color: var(--c-slate-500); display: flex; align-items: center; }
.mnd__loading-inline { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: var(--c-slate-400); padding: .5rem 0; }

/* Precio */
.mnd__aporte-wrap { display: flex; flex-direction: column; gap: .75rem; }
.mnd__precio-box { background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 9px; padding: .6rem .875rem; display: flex; flex-direction: column; gap: .25rem; }
.mnd__precio-row { display: flex; justify-content: space-between; align-items: center; font-size: .8rem; color: #374151; }
.mnd__precio-row--desc { color: var(--c-slate-500); }
.mnd__precio-row--total { font-weight: 700; font-size: .875rem; color: var(--c-slate-900); border-top: 1px solid var(--c-slate-200); padding-top: .25rem; margin-top: .1rem; }

/* CC panels */
.mnd__cc-panel { border-radius: 10px; padding: .7rem .9rem; border: 1.5px solid var(--c-slate-200); display: flex; flex-direction: column; gap: .3rem; }
.mnd__cc-panel--ok           { background: #f0fdf4; border-color: #bbf7d0; }
.mnd__cc-panel--insuficiente { background: #fef2f2; border-color: #fecaca; }
.mnd__cc-panel--agotado      { background: #fef2f2; border-color: #fecaca; }
.mnd__cc-panel--critico      { background: #fffbeb; border-color: #fde68a; }
.mnd__cc-row { display: flex; align-items: center; justify-content: space-between; }
.mnd__cc-label { font-size: .75rem; font-weight: 700; color: #374151; display: flex; align-items: center; gap: .35rem; }
.mnd__cc-saldo { font-size: .9rem; font-weight: 800; color: #15803d; }
.mnd__cc-saldo--bajo { color: #dc2626; }
.mnd__cc-tras { font-size: .72rem; color: var(--c-slate-500); }
.mnd__cc-warn { font-size: .75rem; font-weight: 600; color: #dc2626; display: flex; align-items: center; gap: .3rem; }

/* Delivery */
.mnd__delivery-toggle { display: flex; align-items: center; justify-content: space-between; padding: .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; cursor: pointer; background: #fafbfc; transition: background .15s; gap: .75rem; }
.mnd__delivery-toggle:hover { background: #f0fdf4; border-color: #86efac; }
.mnd__delivery-toggle-left { display: flex; align-items: center; gap: .625rem; }
.mnd__delivery-toggle-title { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.mnd__delivery-toggle-sub { font-size: .72rem; color: var(--c-slate-400); margin-top: 1px; }
.mnd__toggle-switch { width: 36px; height: 20px; background: var(--c-slate-200); border-radius: 10px; position: relative; flex-shrink: 0; transition: background .2s; }
.mnd__toggle-switch--on { background: #1b5e20; }
.mnd__toggle-knob { position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.mnd__toggle-switch--on .mnd__toggle-knob { transform: translateX(16px); }
.mnd__delivery-section { display: flex; flex-direction: column; gap: .75rem; padding: .75rem; background: var(--c-slate-50); border-radius: 10px; border: 1px solid var(--c-slate-200); }

/* Buttons */
.mnd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.mnd__btn-primary:hover:not(:disabled) { background: #144a18; }
.mnd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.mnd__btn-ghost { background: #fff; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200); padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.mnd__btn-ghost:hover { background: var(--c-slate-50); }
</style>
