<script setup>
import { ref, computed, watch } from 'vue'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import { useAuthStore } from '../../stores/auth.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { createDispensacion, createReserva, listStocks, listEntregadores } from '../../lib/api.js'

const props = defineProps({
  modelValue:     { type: Boolean, required: true },
  socioId:        { type: Number,  required: true },
  pacienteNombre: { type: String,  default: '' },
  saldoCc:        { type: Number,  default: null },
  limiteCc:       { type: Number,  default: null },
  descuentoPorcentaje: { type: Number,  default: 0 },
})

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

const stocks          = ref([])
const loadingStocks   = ref(false)
const saving          = ref(false)
const formError       = ref(null)
const deliveryUsers   = ref([])
const loadingDelivery = ref(false)

const today = new Date().toISOString().split('T')[0]

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  preroll: 'Preroll', crema: 'Crema', descarte: 'Descarte', otro: 'Otro',
}
const FORMA_EMOJI = {
  flor_seca: '🌿', hash: '🟤', aceite: '🫙',
  preroll: '🚬', crema: '💊', descarte: '🗑️', otro: '📦',
}

const stocksDisponibles = computed(() => stocks.value.filter(s => s.cantidad > 0))

// ── Cuenta corriente ARS ───────────────────────────────────────────────────────
const tieneCc  = computed(() => props.limiteCc !== null && props.limiteCc > 0)
const ccMargen = computed(() => (props.saldoCc ?? 0) + (props.limiteCc ?? 0))

// El crédito solo aplica cuando el medio de pago consume crédito.
const esMedioCredito = computed(() => ['cuenta_corriente', 'no_abona'].includes(form.value.medio_pago))
const esCuentaCorriente = computed(() => form.value.medio_pago === 'cuenta_corriente')
const esNoAbona         = computed(() => form.value.medio_pago === 'no_abona')
// Panel de crédito: visible a quien dispensa cuando elige cuenta corriente; admin/sup siempre.
const mostrarPanelCredito = computed(() => tieneCc.value && (esMedioCredito.value || puedeVerCredito.value))

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
  return parseFloat(form.value.cantidad) > stockSeleccionado.value.cantidad
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
    const { data } = await listStocks()
    stocks.value = data || []
  } catch { stocks.value = [] }
  finally { loadingStocks.value = false }
}

async function cargarDeliveryUsers() {
  if (deliveryUsers.value.length) return
  loadingDelivery.value = true
  try {
    const { data } = await listEntregadores()
    deliveryUsers.value = data.data || data.usuarios || data || []
  } catch { deliveryUsers.value = [] }
  finally { loadingDelivery.value = false }
}

function emptyForm() {
  return {
    stock_id: null, cantidad: null, descuento_pct: 0, aporte_socio_ars: null,
    fecha_dispensacion: today, observaciones: '', medio_pago: 'efectivo',
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

const stockSeleccionado    = computed(() => stocks.value.find(s => s.id === form.value.stock_id) || null)
const necesitaPrecioManual = computed(() => stockSeleccionado.value != null && !stockSeleccionado.value.precio_sugerido_ars)

const precioBase = computed(() => {
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

watch(() => props.modelValue, (open) => {
  if (open) {
    form.value = emptyForm()
    precioUnitarioManual.value = null
    formError.value = null
    deliveryUsers.value = []
    cargarStocks()
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

  if (!form.value.stock_id) { formError.value = 'Seleccioná un stock'; saving.value = false; return }
  if (!form.value.cantidad || form.value.cantidad <= 0) { formError.value = 'La cantidad debe ser > 0'; saving.value = false; return }
  if (excederiaStock.value) {
    formError.value = `Stock insuficiente: solo hay ${stockSeleccionado.value.cantidad}${stockSeleccionado.value.unidad || 'g'} disponibles`
    saving.value = false; return
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
  if (!(Number(form.value.aporte_socio_ars) > 0)) {
    const sinPrecio = stockSeleccionado.value && !(stockSeleccionado.value.precio_sugerido_ars > 0)
    formError.value = sinPrecio
      ? 'El stock no tiene precio configurado. Pedile al administrador que lo configure.'
      : 'El aporte del socio debe ser mayor a $0.'
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
      stock_id: form.value.stock_id, cantidad: form.value.cantidad,
      fecha_dispensacion: form.value.fecha_dispensacion,
      observaciones: form.value.observaciones || undefined,
      medio_pago: cobraDelivery.value ? undefined : form.value.medio_pago, con_envio: form.value.con_envio,
      // Descuento de la dispensa (puntual). El del paciente lo aplica el server desde la ficha.
      descuento_dispensa_pct: descDispensaPct.value,
    }
    // El total lo calcula el server (descuento paciente + dispensa). Solo admin/supervisor
    // pueden pisar el aporte a mano; el dispensador no manda aporte.
    if (puedeEditarAporte.value && form.value.aporte_socio_ars != null && form.value.aporte_socio_ars !== '')
      payload.aporte_socio_ars = Number(form.value.aporte_socio_ars).toFixed(2)
    // Stock sin precio configurado: si admin cargó precio manual, lo mandamos como override.
    if (puedeEditarAporte.value && necesitaPrecioManual.value && precioUnitarioManual.value > 0) {
      payload.precio_unitario_ars = (parseFloat(precioUnitarioManual.value) * (1 - descTotalPct.value / 100)).toFixed(2)
    }
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
    await createDispensacion(props.socioId, payload)
    cerrar()
    toast.success('Dispensación registrada')
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
            Nueva dispensación<template v-if="props.pacienteNombre"> para <span class="mnd__modal-title-paciente">{{ props.pacienteNombre }}</span></template>
          </h3>
          <button class="mnd__modal-close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mnd__modal-body">
          <div v-if="formError" class="mnd__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ formError }}</div>

          <!-- Tipo: entrega inmediata o reserva -->
          <div class="mnd__segmented">
            <button type="button" class="mnd__seg-btn" :class="{ 'mnd__seg-btn--active': !form.es_reserva }" @click="form.es_reserva = false">
              <i class="bi bi-bag-check"></i> Entrega inmediata
            </button>
            <button type="button" class="mnd__seg-btn" :class="{ 'mnd__seg-btn--active': form.es_reserva }" @click="form.es_reserva = true">
              <i class="bi bi-bookmark-star"></i> Reserva
            </button>
          </div>

          <!-- Stock -->
          <div class="mnd__section-label">Stock a dispensar <span class="mnd__req">*</span></div>
          <div v-if="loadingStocks" class="mnd__loading-inline"><DsSpinner :size="13" /> Cargando stocks…</div>
          <div v-else-if="!stocksDisponibles.length" class="mnd__warn-box">
            <i class="bi bi-exclamation-triangle"></i> Sin stock disponible
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
                <span v-if="s.precio_sugerido_ars" class="mnd__stock-precio">
                  {{ fmt(s.precio_sugerido_ars) }}/{{ s.unidad || 'g' }}
                </span>
              </span>
              <span class="mnd__stock-check" v-if="form.stock_id === s.id"><i class="bi bi-check-circle-fill"></i></span>
            </button>
          </div>

          <!-- Precio manual -->
          <div v-if="necesitaPrecioManual" class="mnd__field">
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

          <div class="mnd__divider"></div>

          <!-- Cantidad + descuento -->
          <div class="mnd__form-row">
            <div class="mnd__field">
              <label class="mnd__label">Cantidad <span class="mnd__req">*</span></label>
              <div class="mnd__input-suffix-wrap">
                <input v-model.number="form.cantidad" type="number" step="0.01" min="0.01"
                       class="mnd__input mnd__input--with-suffix"
                       :class="{ 'mnd__input--error': excederiaStock }"
                       placeholder="0" />
                <span class="mnd__input-suffix">{{ stockSeleccionado?.unidad || 'g' }}</span>
              </div>
              <span v-if="excederiaStock" class="mnd__field-error">
                Máximo {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }} disponibles
              </span>
              <span v-else-if="stockSeleccionado && form.cantidad" class="mnd__field-hint">
                Disponible: {{ stockSeleccionado.cantidad }}{{ stockSeleccionado.unidad || 'g' }}
              </span>
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Descuento <span class="mnd__opt">esta dispensa</span></label>
              <div class="mnd__input-suffix-wrap">
                <input v-model.number="form.descuento_pct" type="number" step="1" min="0" max="100"
                       class="mnd__input mnd__input--with-suffix" placeholder="0" />
                <span class="mnd__input-suffix">%</span>
              </div>
            </div>
          </div>

          <!-- Precio + aporte -->
          <div class="mnd__aporte-wrap">
            <div v-if="precioFinal != null" class="mnd__precio-box">
              <!-- Desglose completo: solo admin/supervisor -->
              <template v-if="puedeVerDescPaciente">
                <div class="mnd__precio-row"><span>Precio base</span><span>{{ fmt(precioBase) }}</span></div>
                <div v-if="descPacientePct > 0" class="mnd__precio-row mnd__precio-row--desc">
                  <span>Descuento socio {{ descPacientePct }}%</span>
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
              <label class="mnd__label">Aporte del socio <span class="mnd__opt">ARS — editable</span></label>
              <div class="mnd__input-suffix-wrap">
                <span class="mnd__input-prefix">$</span>
                <input v-model.number="form.aporte_socio_ars" type="number" min="0" step="1"
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
              <AppDatePicker v-if="form.es_reserva" v-model="form.fecha_entrega_estimada" :min="today" />
              <AppDatePicker v-else v-model="form.fecha_dispensacion" :max="today" />
            </div>
            <div class="mnd__field">
              <label class="mnd__label">Medio de pago <span v-if="form.es_reserva" class="mnd__opt">previsto</span></label>
              <select v-model="form.medio_pago" class="mnd__input">
                <option value="efectivo">Efectivo</option>
                <option value="transferencia">Transferencia</option>
                <option value="cuenta_corriente" :disabled="!tieneCc">Cuenta corriente{{ !tieneCc ? ' (sin límite configurado)' : '' }}</option>
                <option v-if="!form.es_reserva" value="contra_entrega">Contra entrega (cobra el delivery)</option>
              </select>
            </div>
          </div>

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
            <i class="bi bi-info-circle"></i> El delivery y la dirección se definen al momento de entregar la reserva.
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
              <div v-else-if="!deliveryUsers.length" class="mnd__warn-box">
                <i class="bi bi-exclamation-triangle"></i> No hay usuarios delivery disponibles
              </div>
              <select v-else v-model.number="form.delivery_id" class="mnd__input">
                <option :value="null" disabled>Seleccioná un delivery…</option>
                <option v-for="u in deliveryUsers" :key="u.id" :value="u.id">
                  {{ u.first_name || u.nombre || u.email }}
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
          <button class="mnd__btn-primary" :disabled="saving || !form.stock_id || (!form.es_reserva && ccInsuficiente)" @click="handleSubmit">
            <DsSpinner v-if="saving" :size="14" />
            <i v-else class="bi" :class="form.es_reserva ? 'bi-bookmark-star' : 'bi-check-lg'"></i>
            {{ form.es_reserva ? 'Crear reserva' : 'Registrar dispensación' }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mnd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.mnd__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 640px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.18); display: flex; flex-direction: column; }

.mnd__modal-header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.25rem .9rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.mnd__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; margin: 0; }
.mnd__modal-title-paciente { color: #15803d; font-weight: 800; }
.mnd__modal-close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.mnd__modal-close:hover { background: #e2e8f0; }

.mnd__modal-body { padding: 1.1rem 1.25rem; flex: 1; display: flex; flex-direction: column; gap: .9rem; }

/* Segmented entrega / reserva */
.mnd__segmented { display: flex; gap: .35rem; background: #f1f5f9; padding: .25rem; border-radius: 10px; }
.mnd__seg-btn { flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: .4rem; border: none; background: transparent; color: #64748b; font-size: .82rem; font-weight: 700; padding: .5rem .75rem; border-radius: 8px; cursor: pointer; transition: all .15s; }
.mnd__seg-btn--active { background: #fff; color: #15803d; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
.mnd__segmented--sm .mnd__seg-btn { font-size: .78rem; padding: .4rem .5rem; }
.mnd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .875rem 1.25rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }

.mnd__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; display: flex; align-items: center; gap: .4rem; }


/* Stock */
.mnd__section-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.mnd__stock-list { display: flex; flex-direction: column; gap: .35rem; max-height: 220px; overflow-y: auto; }
.mnd__stock-row { display: flex; align-items: center; gap: .75rem; padding: .6rem .875rem; border-radius: 10px; border: 1.5px solid #e2e8f0; background: #fafbfc; cursor: pointer; text-align: left; transition: all .12s; width: 100%; }
.mnd__stock-row:hover { border-color: #86efac; background: #f0fdf4; }
.mnd__stock-row--active { border-color: #1b5e20; background: #f0fdf4; }
.mnd__stock-emoji { font-size: 1.1rem; flex-shrink: 0; }
.mnd__stock-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .1rem; }
.mnd__stock-nombre { font-size: .82rem; font-weight: 700; color: #0f172a; }
.mnd__stock-gen { font-size: .72rem; color: #64748b; font-style: italic; }
.mnd__stock-fecha { font-size: .68rem; color: #94a3b8; display: flex; align-items: center; gap: .25rem; }
.mnd__stock-right { display: flex; flex-direction: column; align-items: flex-end; gap: .1rem; flex-shrink: 0; }
.mnd__stock-disp  { font-size: .8rem; font-weight: 700; color: #1b5e20; font-family: monospace; }
.mnd__stock-precio { font-size: .7rem; color: #64748b; font-family: monospace; white-space: nowrap; }
.mnd__stock-check { color: #1b5e20; font-size: .9rem; flex-shrink: 0; }
.mnd__warn-box { background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; color: #92400e; display: flex; align-items: center; gap: .4rem; }

/* Form */
.mnd__divider { height: 1px; background: #f1f5f9; }
.mnd__form-row { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 400px) { .mnd__form-row { grid-template-columns: 1fr; } }
.mnd__field { display: flex; flex-direction: column; gap: .3rem; }
.mnd__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .05em; }
.mnd__req { color: #ef4444; }
.mnd__opt { font-size: .67rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.mnd__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .8rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s; }
.mnd__input:focus { border-color: #1b5e20; background: #fff; }
.mnd__input--error { border-color: #ef4444 !important; background: #fef2f2; }
.mnd__field-error { font-size: .72rem; color: #dc2626; font-weight: 600; }
.mnd__field-hint  { font-size: .72rem; color: #94a3b8; }
.mnd__textarea { resize: vertical; min-height: 58px; }
.mnd__input-suffix-wrap { display: flex; }
.mnd__input--with-suffix { border-radius: 9px 0 0 9px; flex: 1; }
.mnd__input-suffix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-left: none; border-radius: 0 9px 9px 0; padding: .6rem .7rem; font-size: .8rem; color: #64748b; white-space: nowrap; display: flex; align-items: center; }
.mnd__input--with-prefix { border-radius: 0 9px 9px 0; flex: 1; }
.mnd__input-prefix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-right: none; border-radius: 9px 0 0 9px; padding: .6rem .7rem; font-size: .8rem; color: #64748b; display: flex; align-items: center; }
.mnd__loading-inline { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: #94a3b8; padding: .5rem 0; }

/* Precio */
.mnd__aporte-wrap { display: flex; flex-direction: column; gap: .75rem; }
.mnd__precio-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; display: flex; flex-direction: column; gap: .25rem; }
.mnd__precio-row { display: flex; justify-content: space-between; align-items: center; font-size: .8rem; color: #374151; }
.mnd__precio-row--desc { color: #64748b; }
.mnd__precio-row--total { font-weight: 700; font-size: .875rem; color: #0f172a; border-top: 1px solid #e2e8f0; padding-top: .25rem; margin-top: .1rem; }

/* CC panels */
.mnd__cc-panel { border-radius: 10px; padding: .7rem .9rem; border: 1.5px solid #e2e8f0; display: flex; flex-direction: column; gap: .3rem; }
.mnd__cc-panel--ok           { background: #f0fdf4; border-color: #bbf7d0; }
.mnd__cc-panel--insuficiente { background: #fef2f2; border-color: #fecaca; }
.mnd__cc-panel--agotado      { background: #fef2f2; border-color: #fecaca; }
.mnd__cc-panel--critico      { background: #fffbeb; border-color: #fde68a; }
.mnd__cc-row { display: flex; align-items: center; justify-content: space-between; }
.mnd__cc-label { font-size: .75rem; font-weight: 700; color: #374151; display: flex; align-items: center; gap: .35rem; }
.mnd__cc-saldo { font-size: .9rem; font-weight: 800; color: #15803d; }
.mnd__cc-saldo--bajo { color: #dc2626; }
.mnd__cc-tras { font-size: .72rem; color: #64748b; }
.mnd__cc-warn { font-size: .75rem; font-weight: 600; color: #dc2626; display: flex; align-items: center; gap: .3rem; }

/* Delivery */
.mnd__delivery-toggle { display: flex; align-items: center; justify-content: space-between; padding: .75rem; border: 1.5px solid #e2e8f0; border-radius: 10px; cursor: pointer; background: #fafbfc; transition: background .15s; gap: .75rem; }
.mnd__delivery-toggle:hover { background: #f0fdf4; border-color: #86efac; }
.mnd__delivery-toggle-left { display: flex; align-items: center; gap: .625rem; }
.mnd__delivery-toggle-title { font-size: .82rem; font-weight: 700; color: #0f172a; }
.mnd__delivery-toggle-sub { font-size: .72rem; color: #94a3b8; margin-top: 1px; }
.mnd__toggle-switch { width: 36px; height: 20px; background: #e2e8f0; border-radius: 10px; position: relative; flex-shrink: 0; transition: background .2s; }
.mnd__toggle-switch--on { background: #1b5e20; }
.mnd__toggle-knob { position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.mnd__toggle-switch--on .mnd__toggle-knob { transform: translateX(16px); }
.mnd__delivery-section { display: flex; flex-direction: column; gap: .75rem; padding: .75rem; background: #f8fafc; border-radius: 10px; border: 1px solid #e2e8f0; }

/* Buttons */
.mnd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.mnd__btn-primary:hover:not(:disabled) { background: #144a18; }
.mnd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.mnd__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.mnd__btn-ghost:hover { background: #f8fafc; }
</style>
