<script setup>
import { ref, computed, watch, nextTick, onUnmounted } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { useModalEscape } from '../../composables/useModalEscape.js'

const props = defineProps({
  modelValue:       { type: Boolean, default: false },
  balanceActual:    { type: Number,  default: 0 },
  pacientes:        { type: Array,   default: () => [] },
  sedes:            { type: Array,   default: () => [] },
  movimientoEditar: { type: Object,  default: null },
})
const emit = defineEmits(['update:modelValue', 'guardado'])

// ─── TIPOS ────────────────────────────────────────────────
const TIPO_META = {
  ingreso: { label: 'Ingreso', color: '#16A34A', bg: '#F0FDF4', ring: 'rgba(22,163,74,0.1)' },
  egreso:  { label: 'Egreso',  color: '#DC2626', bg: '#FEF2F2', ring: 'rgba(220,38,38,0.1)' },
}
const TIPOS = [
  { value: 'ingreso' },
  { value: 'egreso' },
]

// ─── CATEGORÍAS ───────────────────────────────────────────
const ALL_CATS = [
  { value: 'insumo',        label: 'Insumos',               tipos: ['egreso'] },
  { value: 'electricidad',  label: 'Electricidad',          tipos: ['egreso'] },
  { value: 'agua',          label: 'Agua',                  tipos: ['egreso'] },
  { value: 'alquiler',      label: 'Alquiler',              tipos: ['egreso'] },
  { value: 'sueldo',        label: 'Sueldos',               tipos: ['egreso'] },
  { value: 'mantenimiento', label: 'Mantenimiento',         tipos: ['egreso'] },
  { value: 'honorario',     label: 'Honorarios',            tipos: ['egreso'] },
  { value: 'seguro',        label: 'Seguros',               tipos: ['egreso'] },
  { value: 'admin',         label: 'Administrativo',        tipos: ['egreso'] },
  { value: 'aporte_socio',  label: 'Aporte socio',          tipos: ['ingreso'], requiresPaciente: true },
  { value: 'dispensacion',  label: 'Recupero dispensación', tipos: ['ingreso'], allowsPaciente: true },
  { value: 'subvencion',    label: 'Subvención',            tipos: ['ingreso'] },
  { value: 'otro',          label: 'Otros',                 tipos: ['egreso','ingreso'] },
]

const MEDIOS_PAGO = [
  { value: 'efectivo',      label: 'Efectivo' },
  { value: 'transferencia', label: 'Transferencia' },
  { value: 'mercado_pago',  label: 'Mercado Pago' },
]

const COMPROBANTE_TIPOS = [
  { value: 'sin_comprobante', label: 'Sin comprobante' },
  { value: 'factura_a',       label: 'Factura A' },
  { value: 'factura_b',       label: 'Factura B' },
  { value: 'recibo',          label: 'Recibo' },
  { value: 'ticket',          label: 'Ticket' },
]

const PLACEHOLDERS = {
  insumo:        'Ej: Sustrato y fertilizantes cultivo sala B',
  electricidad:  'Ej: Factura Edenor marzo',
  agua:          'Ej: Factura AYSA marzo',
  alquiler:      'Ej: Alquiler sede Palermo',
  sueldo:        'Ej: Sueldo cultivador marzo',
  mantenimiento: 'Ej: Reparación sistema de ventilación',
  honorario:     'Ej: Honorario contadora trimestral',
  seguro:        'Ej: Póliza seguro anual',
  admin:         'Ej: Papelería y gastos de oficina',
  aporte_socio:  'Ej: Cuota marzo — Juan García',
  dispensacion:  'Ej: Recupero dispensaciones semana 12',
  subvencion:    'Ej: Donación socio fundador',
}

// ─── FORM ─────────────────────────────────────────────────
function emptyForm() {
  return {
    tipo: 'ingreso',
    categoria: '',
    descripcion: '',
    monto_ars: null,
    fecha: new Date().toISOString().slice(0, 10),
    sede_id: null,
    lote_id: null,
    paciente_id: null,
    comprobante_numero: '',
    comprobante_tipo: 'sin_comprobante',
    proveedor: '',
    pagado: false,
    medio_pago: 'efectivo',
    cuotas_total: 6,
    notas: '',
  }
}

const form   = ref(emptyForm())
const errors = ref({})
const saving = ref(false)

// Fallback a 'egreso' para tipos legacy (recupero_costo, ajuste) que puedan venir de datos viejos
const tipoMeta = computed(() => TIPO_META[form.value.tipo] || TIPO_META.egreso)
const tipoNorm = computed(() => TIPO_META[form.value.tipo] ? form.value.tipo : 'egreso')

// Pago en cuotas: solo para egresos NUEVOS. El monto pasa a ser el total y se generan N
// movimientos mensuales (una compra financiada). No aplica al editar un movimiento existente.
const esCuotas = computed(() => form.value.medio_pago === 'en_cuotas')
const mediosDisponibles = computed(() =>
  (tipoNorm.value === 'egreso' && !props.movimientoEditar)
    ? [...MEDIOS_PAGO, { value: 'en_cuotas', label: 'En cuotas' }]
    : MEDIOS_PAGO
)
// Si se cambia a ingreso con "en cuotas" activo, se vuelve a efectivo.
watch(tipoNorm, (t) => { if (t !== 'egreso' && esCuotas.value) form.value.medio_pago = 'efectivo' })

// ─── MONTO ────────────────────────────────────────────────
const montoDisplay  = ref('')
const montoInputRef = ref(null)

function fmtMiles(n) {
  if (!n && n !== 0) return ''
  return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')
}

function fmtARS(n) {
  return new Intl.NumberFormat('es-AR', {
    style: 'currency', currency: 'ARS', maximumFractionDigits: 0,
  }).format(n || 0)
}

function onMontoInput(e) {
  const raw = e.target.value.replace(/\./g, '').replace(/[^0-9]/g, '')
  const num = raw ? parseInt(raw, 10) : null
  form.value.monto_ars = num
  const fmt = fmtMiles(num)
  montoDisplay.value = fmt
  nextTick(() => {
    if (montoInputRef.value) montoInputRef.value.setSelectionRange(fmt.length, fmt.length)
  })
}

const balanceProyectado = computed(() => {
  const m = form.value.monto_ars
  if (!m || m <= 0) return null
  const base = props.balanceActual || 0
  return form.value.tipo === 'egreso' ? base - m : base + m
})

const deltaLabel = computed(() => {
  const m = form.value.monto_ars
  if (!m) return null
  const sign = form.value.tipo === 'egreso' ? '−' : '+'
  return `${sign}${fmtARS(m)}`
})

// ─── CATEGORÍAS COMBOBOX ──────────────────────────────────
const catQuery = ref('')
const catOpen  = ref(false)
const catHL    = ref(-1)
const catRef   = ref(null)
const catInput = ref(null)

const catsFiltradas = computed(() => {
  const tipo = form.value.tipo
  let base = ALL_CATS.filter(c => c.tipos.includes(tipo))
  const q = catQuery.value.trim().toLowerCase()
  return q ? base.filter(c => c.label.toLowerCase().includes(q)) : base
})

const catActual     = computed(() => ALL_CATS.find(c => c.value === form.value.categoria) || null)
const needsPaciente = computed(() => catActual.value?.requiresPaciente || false)
// Categorías que muestran el selector de paciente (obligatorio en aporte_socio,
// opcional en recupero dispensación para poder atribuirlo a un socio).
const showsPaciente = computed(() => catActual.value?.requiresPaciente || catActual.value?.allowsPaciente || false)
const descPH        = computed(() => PLACEHOLDERS[form.value.categoria] || 'Describí brevemente el movimiento')

function openCat()   { catOpen.value = true; catHL.value = -1; catQuery.value = ''; nextTick(() => catInput.value?.focus()) }
function closeCat()  { catOpen.value = false; catQuery.value = '' }
function pickCat(c)  {
  form.value.categoria = c.value
  if (!c.requiresPaciente && !c.allowsPaciente) form.value.paciente_id = null
  delete errors.value.categoria
  closeCat()
}
function onCatKey(e) {
  const opts = catsFiltradas.value
  if      (e.key === 'ArrowDown')                { e.preventDefault(); catHL.value = Math.min(catHL.value + 1, opts.length - 1) }
  else if (e.key === 'ArrowUp')                  { e.preventDefault(); catHL.value = Math.max(catHL.value - 1, 0) }
  else if (e.key === 'Enter' && catHL.value >= 0){ e.preventDefault(); pickCat(opts[catHL.value]) }
  else if (e.key === 'Escape')                   { closeCat() }
}

// ─── PACIENTES COMBOBOX ───────────────────────────────────
const pacQuery = ref('')
const pacOpen  = ref(false)
const pacHL    = ref(-1)
const pacRef   = ref(null)
const pacInput = ref(null)

const pacsFiltrados = computed(() => {
  const q = pacQuery.value.trim().toLowerCase()
  if (!q) return props.pacientes.slice(0, 30)
  return props.pacientes.filter(p => p.label?.toLowerCase().includes(q)).slice(0, 30)
})

const pacActual = computed(() => props.pacientes.find(p => p.id === form.value.paciente_id) || null)

function openPac()  { pacOpen.value = true; pacHL.value = -1; pacQuery.value = ''; nextTick(() => pacInput.value?.focus()) }
function closePac() { pacOpen.value = false; pacQuery.value = '' }
function pickPac(p) { form.value.paciente_id = p.id; delete errors.value.paciente_id; closePac() }
function clearPac() { form.value.paciente_id = null; openPac() }
function onPacKey(e) {
  const opts = pacsFiltrados.value
  if      (e.key === 'ArrowDown')                { e.preventDefault(); pacHL.value = Math.min(pacHL.value + 1, opts.length - 1) }
  else if (e.key === 'ArrowUp')                  { e.preventDefault(); pacHL.value = Math.max(pacHL.value - 1, 0) }
  else if (e.key === 'Enter' && pacHL.value >= 0){ e.preventDefault(); pickPac(opts[pacHL.value]) }
  else if (e.key === 'Escape')                   { closePac() }
}

// ─── CLICK OUTSIDE ────────────────────────────────────────
function onDocClick(e) {
  if (catRef.value && !catRef.value.contains(e.target)) closeCat()
  if (pacRef.value && !pacRef.value.contains(e.target)) closePac()
}

// ─── ACORDEONES ───────────────────────────────────────────
const acPago   = ref(false)
const acExtras = ref(false)

function acBeforeEnter(el) {
  el.style.height = '0'
  el.style.overflow = 'hidden'
}
function acEnter(el, done) {
  requestAnimationFrame(() => {
    el.style.transition = 'height 0.22s ease'
    el.style.height = el.scrollHeight + 'px'
    el.addEventListener('transitionend', () => {
      el.style.height = 'auto'; el.style.overflow = ''; el.style.transition = ''; done()
    }, { once: true })
  })
}
function acLeave(el, done) {
  el.style.height = el.scrollHeight + 'px'
  el.style.overflow = 'hidden'
  el.getBoundingClientRect()
  el.style.transition = 'height 0.22s ease'
  el.style.height = '0'
  el.addEventListener('transitionend', done, { once: true })
}

// ─── FECHA ────────────────────────────────────────────────
function setHoy()  { form.value.fecha = new Date().toISOString().slice(0, 10) }
function setAyer() { const d = new Date(); d.setDate(d.getDate() - 1); form.value.fecha = d.toISOString().slice(0, 10) }

// ─── WATCHERS ─────────────────────────────────────────────
watch(() => form.value.tipo, (t) => {
  const cat = ALL_CATS.find(c => c.value === form.value.categoria)
  if (cat && !cat.tipos.includes(t)) { form.value.categoria = ''; form.value.paciente_id = null }
  acPago.value = (t === 'egreso')
})

watch(() => form.value.categoria, (v) => {
  const c = ALL_CATS.find(c => c.value === v)
  if (!c?.requiresPaciente && !c?.allowsPaciente) form.value.paciente_id = null
})

watch(() => props.modelValue, (val) => {
  if (val) {
    if (props.movimientoEditar) {
      const m = props.movimientoEditar
      const tipoValido = TIPO_META[m.tipo] ? m.tipo : 'egreso'
      form.value = {
        tipo:               tipoValido,
        categoria:          m.categoria          || '',
        descripcion:        m.descripcion        || '',
        monto_ars:          m.monto_ars          || null,
        fecha:              m.fecha              || new Date().toISOString().slice(0, 10),
        sede_id:            m.sede?.id           || null,
        lote_id:            m.lote?.id           || null,
        paciente_id:        m.paciente_id        || null,
        comprobante_numero: m.comprobante_numero || '',
        comprobante_tipo:   m.comprobante_tipo   || 'sin_comprobante',
        proveedor:          m.proveedor          || '',
        pagado:             !!m.pagado,
        medio_pago:         m.medio_pago         || 'efectivo',
        notas:              m.notas              || '',
      }
      montoDisplay.value = fmtMiles(m.monto_ars)
      acPago.value   = true
      acExtras.value = !!(m.comprobante_numero || m.proveedor || m.notas || m.sede_id)
    } else {
      form.value         = emptyForm()
      montoDisplay.value = ''
      acPago.value       = false
      acExtras.value     = false
    }
    errors.value = {}
    document.addEventListener('click', onDocClick, true)
  } else {
    closeCat(); closePac()
    document.removeEventListener('click', onDocClick, true)
  }
})

onUnmounted(() => document.removeEventListener('click', onDocClick, true))

useModalEscape(() => close())

function close() { emit('update:modelValue', false) }

// ─── VALIDACIÓN ───────────────────────────────────────────
function validate() {
  const e = {}, f = form.value
  if (!f.tipo)                        e.tipo        = 'Requerido'
  if (!f.categoria)                   e.categoria   = 'Seleccioná una categoría'
  if (!f.descripcion?.trim())         e.descripcion = 'Requerido'
  if (!f.monto_ars || f.monto_ars <= 0) e.monto_ars = 'Ingresá un monto'
  if (!f.fecha)                       e.fecha       = 'Requerido'
  if (needsPaciente.value && !f.paciente_id) e.paciente_id = 'Seleccioná el paciente'
  if (esCuotas.value && !(Number(f.cuotas_total) >= 2)) e.cuotas_total = 'Mínimo 2 cuotas'
  errors.value = e
  return !Object.keys(e).length
}

const formValid = computed(() => {
  const f = form.value
  return !!(f.tipo && f.categoria && f.descripcion?.trim() &&
    f.monto_ars > 0 && f.fecha && (!needsPaciente.value || f.paciente_id))
})

async function submit() {
  if (!validate()) return
  saving.value = true
  try { emit('guardado', { ...form.value }) }
  finally { saving.value = false }
}
</script>

<template>
  <Teleport to="body">
    <Transition name="nm-fade">
      <div
        v-if="modelValue"
        class="nm-overlay"
      >
        <div
          class="nm-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="nm-title"
          :style="{
            '--tc': tipoMeta.color,
            '--tb': tipoMeta.bg,
            '--tr': tipoMeta.ring,
          }"
        >

          <!-- ─── HEADER ─── -->
          <div class="nm-header">
            <span class="nm-header-title" id="nm-title">
              {{ movimientoEditar ? 'Editar movimiento' : 'Nuevo movimiento' }}
            </span>
            <button type="button" class="nm-header-close" @click="close" aria-label="Cerrar">
              <i class="bi bi-x-lg"></i>
            </button>
          </div>

          <!-- ─── BODY ─── -->
          <div class="nm-body">

            <!-- TIPO TAB BAR -->
            <div class="nm-tabs-wrap">
              <div class="nm-tabs-bar">
                <button
                  v-for="t in TIPOS"
                  :key="t.value"
                  type="button"
                  class="nm-tab"
                  :class="{ 'nm-tab--active': form.tipo === t.value }"
                  :style="form.tipo === t.value ? {
                    color: TIPO_META[t.value].color,
                    '--ac': TIPO_META[t.value].color,
                  } : {}"
                  @click="form.tipo = t.value"
                >{{ TIPO_META[t.value].label }}</button>
              </div>
            </div>

            <!-- MONTO HERO -->
            <div class="nm-monto-section">
              <span class="nm-monto-eyebrow">MONTO</span>
              <div class="nm-monto-row">
                <span class="nm-monto-prefix" :style="{ color: tipoMeta.color }">$</span>
                <input
                  ref="montoInputRef"
                  type="text"
                  inputmode="numeric"
                  class="nm-monto-input"
                  :class="{ 'nm-monto-input--err': errors.monto_ars }"
                  :style="{ color: tipoMeta.color }"
                  :value="montoDisplay"
                  placeholder="0"
                  @input="onMontoInput"
                />
              </div>
              <div class="nm-monto-bar" :style="{ borderColor: tipoMeta.color }"></div>
              <div class="nm-monto-projection">
                <template v-if="balanceProyectado !== null">
                  <span class="nm-proj-base">Balance: {{ fmtARS(props.balanceActual) }}</span>
                  <span class="nm-proj-sep"> → </span>
                  <span class="nm-proj-next">{{ fmtARS(balanceProyectado) }}</span>
                  <span class="nm-proj-delta" :style="{ color: tipoMeta.color }"> ({{ deltaLabel }})</span>
                </template>
                <span v-else class="nm-proj-empty">Ingresá un monto para ver la proyección</span>
              </div>
              <span v-if="errors.monto_ars" class="nm-monto-err">{{ errors.monto_ars }}</span>
            </div>

            <!-- CAMPOS PRINCIPALES -->
            <div class="nm-fields">

              <!-- Categoría -->
              <div class="nm-field" ref="catRef">
                <label class="nm-label">Categoría <span class="nm-req">*</span></label>
                <div
                  class="nm-combo"
                  :class="{ 'nm-combo--err': errors.categoria, 'nm-combo--open': catOpen }"
                  tabindex="0"
                  role="combobox"
                  :aria-expanded="catOpen"
                  @click="catOpen ? closeCat() : openCat()"
                  @keydown.enter.prevent="catOpen ? closeCat() : openCat()"
                  @keydown.space.prevent="catOpen ? closeCat() : openCat()"
                >
                  <span v-if="catActual" class="nm-combo-val">{{ catActual.label }}</span>
                  <span v-else           class="nm-combo-ph">Seleccioná una categoría</span>
                  <i class="bi bi-chevron-down nm-combo-chev" :class="{ 'nm-combo-chev--up': catOpen }"></i>
                </div>
                <Transition name="nm-drop">
                  <div v-if="catOpen" class="nm-dropdown" role="listbox">
                    <div class="nm-drop-search">
                      <i class="bi bi-search nm-drop-ico"></i>
                      <input ref="catInput" type="text" class="nm-drop-input" v-model="catQuery"
                             placeholder="Buscar..." autocomplete="off" @keydown="onCatKey" />
                    </div>
                    <div class="nm-drop-list">
                      <button
                        v-for="(c, i) in catsFiltradas" :key="c.value"
                        type="button" class="nm-drop-opt"
                        :class="{ 'nm-drop-opt--sel': form.categoria === c.value, 'nm-drop-opt--hl': catHL === i }"
                        @click="pickCat(c)" @mouseenter="catHL = i"
                      >{{ c.label }}</button>
                      <div v-if="!catsFiltradas.length" class="nm-drop-empty">Sin resultados</div>
                    </div>
                  </div>
                </Transition>
                <span v-if="errors.categoria" class="nm-err">{{ errors.categoria }}</span>
              </div>

              <!-- Descripción -->
              <div class="nm-field">
                <label class="nm-label">Descripción <span class="nm-req">*</span></label>
                <input type="text" class="nm-input" :class="{ 'nm-input--err': errors.descripcion }"
                       v-model.trim="form.descripcion" :placeholder="descPH" />
                <span v-if="errors.descripcion" class="nm-err">{{ errors.descripcion }}</span>
              </div>

              <!-- Fecha -->
              <div class="nm-field">
                <label class="nm-label">Fecha <span class="nm-req">*</span></label>
                <AppDatePicker v-model="form.fecha" />
                <span v-if="errors.fecha" class="nm-err">{{ errors.fecha }}</span>
              </div>

              <!-- Paciente (condicional) -->
              <Transition name="field-slide">
                <div v-if="showsPaciente" class="nm-field" ref="pacRef">
                  <label class="nm-label">Socio / Paciente <span v-if="needsPaciente" class="nm-req">*</span><span v-else class="nm-opt">(opcional)</span></label>
                  <template v-if="pacActual && !pacOpen">
                    <div class="nm-combo nm-combo--sel" @click="openPac">
                      <span class="nm-combo-val">{{ pacActual.label }}</span>
                      <button type="button" class="nm-combo-clear" @click.stop="clearPac" aria-label="Cambiar">
                        <i class="bi bi-x"></i>
                      </button>
                    </div>
                  </template>
                  <template v-else>
                    <div class="nm-combo"
                         :class="{ 'nm-combo--err': errors.paciente_id, 'nm-combo--open': pacOpen }"
                         tabindex="0" role="combobox" :aria-expanded="pacOpen"
                         @click="pacOpen ? closePac() : openPac()">
                      <span class="nm-combo-ph">Buscar socio...</span>
                      <i class="bi bi-chevron-down nm-combo-chev" :class="{ 'nm-combo-chev--up': pacOpen }"></i>
                    </div>
                  </template>
                  <Transition name="nm-drop">
                    <div v-if="pacOpen" class="nm-dropdown" role="listbox">
                      <div class="nm-drop-search">
                        <i class="bi bi-search nm-drop-ico"></i>
                        <input ref="pacInput" type="text" class="nm-drop-input" v-model="pacQuery"
                               placeholder="Nombre o DNI..." autocomplete="off" @keydown="onPacKey" />
                      </div>
                      <div class="nm-drop-list">
                        <button
                          v-for="(p, i) in pacsFiltrados" :key="p.id"
                          type="button" class="nm-drop-opt"
                          :class="{ 'nm-drop-opt--sel': form.paciente_id === p.id, 'nm-drop-opt--hl': pacHL === i }"
                          @click="pickPac(p)" @mouseenter="pacHL = i"
                        >{{ p.label }}</button>
                        <div v-if="!pacsFiltrados.length" class="nm-drop-empty">
                          {{ pacQuery ? 'Sin resultados' : 'No hay socios disponibles' }}
                        </div>
                      </div>
                    </div>
                  </Transition>
                  <span v-if="errors.paciente_id" class="nm-err">{{ errors.paciente_id }}</span>
                  <p v-if="pacActual && needsPaciente" class="nm-pac-hint">
                    Al guardar se acreditará en la cuenta corriente de
                    <strong>{{ pacActual.label.split('—')[0].trim() }}</strong>.
                  </p>
                  <p v-else-if="pacActual" class="nm-pac-hint">
                    Se atribuye el ingreso a <strong>{{ pacActual.label.split('—')[0].trim() }}</strong> (no afecta su cuenta corriente).
                  </p>
                </div>
              </Transition>

            </div>

            <!-- SEPARADOR -->
            <hr class="nm-hr" />

            <!-- ACORDEÓN: Detalle de pago -->
            <div class="nm-ac">
              <button type="button" class="nm-ac-hdr" :aria-expanded="acPago" @click="acPago = !acPago">
                <span class="nm-ac-title">Detalle de pago</span>
                <i class="bi bi-chevron-down nm-ac-chev" :class="{ 'nm-ac-chev--open': acPago }"></i>
              </button>
              <Transition @before-enter="acBeforeEnter" @enter="acEnter" @leave="acLeave">
                <div v-if="acPago" class="nm-ac-body">
                  <div class="nm-field">
                    <label class="nm-label">Medio de pago <span class="nm-opt">(opcional)</span></label>
                    <div class="nm-seg">
                      <button v-for="mp in mediosDisponibles" :key="mp.value" type="button"
                              class="nm-seg-btn" :class="{ 'nm-seg-btn--active': form.medio_pago === mp.value }"
                              :style="form.medio_pago === mp.value ? { borderColor: tipoMeta.color, background: tipoMeta.bg, color: tipoMeta.color } : {}"
                              @click="form.medio_pago = mp.value"
                      >{{ mp.label }}</button>
                    </div>
                  </div>

                  <!-- Pago en cuotas: el monto de arriba es el TOTAL; se generan N egresos mensuales -->
                  <div v-if="esCuotas" class="nm-field">
                    <label class="nm-label">Cantidad de cuotas</label>
                    <input v-model.number="form.cuotas_total" type="number" min="2" max="120" step="1"
                           class="nm-input" :class="{ 'nm-input--err': errors.cuotas_total }" />
                    <span v-if="errors.cuotas_total" class="nm-monto-err">{{ errors.cuotas_total }}</span>
                    <span class="nm-cuotas-hint">
                      El monto de arriba es el <strong>total</strong>: se divide en {{ form.cuotas_total || 0 }} cuotas
                      mensuales desde la fecha elegida. Poné un mes anterior para cuadrar cuotas ya vencidas.
                    </span>
                  </div>

                  <div v-if="!esCuotas" class="nm-field">
                    <label class="nm-label">Estado <span class="nm-opt">(opcional)</span></label>
                    <div class="nm-seg">
                      <button type="button" class="nm-seg-btn" :class="{ 'nm-seg-btn--active': form.pagado }"
                              :style="form.pagado ? { borderColor: '#16A34A', background: '#F0FDF4', color: '#16A34A' } : {}"
                              @click="form.pagado = true">Cobrado</button>
                      <button type="button" class="nm-seg-btn" :class="{ 'nm-seg-btn--active': !form.pagado }"
                              :style="!form.pagado ? { borderColor: '#D97706', background: '#FFFBEB', color: '#D97706' } : {}"
                              @click="form.pagado = false">Pendiente</button>
                    </div>
                  </div>
                </div>
              </Transition>
            </div>

            <hr class="nm-hr" />

            <!-- ACORDEÓN: Comprobante y extras -->
            <div class="nm-ac">
              <button type="button" class="nm-ac-hdr" :aria-expanded="acExtras" @click="acExtras = !acExtras">
                <span class="nm-ac-title">Comprobante y extras</span>
                <i class="bi bi-chevron-down nm-ac-chev" :class="{ 'nm-ac-chev--open': acExtras }"></i>
              </button>
              <Transition @before-enter="acBeforeEnter" @enter="acEnter" @leave="acLeave">
                <div v-if="acExtras" class="nm-ac-body">
                  <div class="nm-grid2">
                    <div class="nm-field">
                      <label class="nm-label">Sede <span class="nm-opt">(opcional)</span></label>
                      <select class="nm-input" v-model="form.sede_id">
                        <option :value="null">— Sin sede —</option>
                        <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                      </select>
                    </div>
                    <div class="nm-field">
                      <label class="nm-label">Proveedor / Origen <span class="nm-opt">(opcional)</span></label>
                      <input type="text" class="nm-input" v-model.trim="form.proveedor"
                             placeholder="Edenor, farmacia, etc." />
                    </div>
                  </div>
                  <div class="nm-grid2">
                    <div class="nm-field">
                      <label class="nm-label">Comprobante <span class="nm-opt">(opcional)</span></label>
                      <select class="nm-input" v-model="form.comprobante_tipo">
                        <option v-for="c in COMPROBANTE_TIPOS" :key="c.value" :value="c.value">{{ c.label }}</option>
                      </select>
                    </div>
                    <div class="nm-field">
                      <label class="nm-label">N° comprobante <span class="nm-opt">(opcional)</span></label>
                      <input type="text" class="nm-input" v-model.trim="form.comprobante_numero"
                             placeholder="0001-00001234" />
                    </div>
                  </div>
                  <div class="nm-field">
                    <label class="nm-label">Notas <span class="nm-opt">(opcional)</span></label>
                    <textarea class="nm-input nm-textarea" v-model.trim="form.notas"
                              placeholder="Notas adicionales..." rows="2"></textarea>
                  </div>
                </div>
              </Transition>
            </div>

            <div class="nm-body-end"></div>
          </div>

          <!-- ─── FOOTER ─── -->
          <div class="nm-footer">
            <button type="button" class="nm-btn-cancel" @click="close">Cancelar</button>
            <button
              type="button"
              class="nm-btn-primary"
              :disabled="saving || !formValid"
              @click="submit"
            >
              {{ saving ? 'Guardando...' : (movimientoEditar ? 'Guardar cambios' : 'Registrar movimiento') }}
            </button>
          </div>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* ─── OVERLAY ───────────────────────────────────────── */
.nm-overlay {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(15, 15, 15, 0.45);
  backdrop-filter: blur(3px);
  -webkit-backdrop-filter: blur(3px);
  z-index: 1000;
  padding: 16px;
}

/* ─── OVERLAY FADE TRANSITION ───────────────────────── */
.nm-fade-enter-active { transition: opacity 0.18s ease; }
.nm-fade-leave-active { transition: opacity 0.14s ease; }
.nm-fade-enter-from,
.nm-fade-leave-to     { opacity: 0; }

.nm-fade-enter-active .nm-dialog {
  transition: transform 0.24s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.2s ease;
}
.nm-fade-enter-from .nm-dialog {
  transform: translateY(16px) scale(0.98);
  opacity: 0;
}

/* ─── DIALOG ─────────────────────────────────────────── */
.nm-dialog {
  width: 680px;
  max-width: 100%;
  max-height: 85vh;
  background: #FFFFFF;
  border-radius: 12px;
  box-shadow: 0 8px 40px rgba(0,0,0,0.12), 0 1px 3px rgba(0,0,0,0.08);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* ─── HEADER ─────────────────────────────────────────── */
.nm-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  height: 56px;
  border-bottom: 1px solid #E5E7EB;
  flex-shrink: 0;
  background: #FFFFFF;
}
.nm-header-title {
  font-size: 15px;
  font-weight: 600;
  color: #111827;
}
.nm-header-close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: #6B7280;
  cursor: pointer;
  font-size: 16px;
  transition: background 0.12s, color 0.12s;
}
.nm-header-close:hover { background: #F3F4F6; color: #111827; }

/* ─── BODY ───────────────────────────────────────────── */
.nm-body {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
}
.nm-body-end { height: 8px; }

/* ─── TIPO TABS ──────────────────────────────────────── */
.nm-tabs-wrap { padding: 16px 24px 0; }
.nm-tabs-bar {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  background: #F9FAFB;
  border-radius: 8px;
  padding: 3px;
  gap: 2px;
}
.nm-tab {
  height: 34px;
  border: none;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  color: #6B7280;
  background: transparent;
  cursor: pointer;
  transition: all 0.15s ease;
  position: relative;
  font-family: inherit;
}
.nm-tab:hover:not(.nm-tab--active) {
  color: #374151;
  background: rgba(255,255,255,0.6);
}
.nm-tab--active {
  background: #FFFFFF;
  box-shadow: 0 1px 3px rgba(0,0,0,0.10);
}
.nm-tab--active::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 16px;
  right: 16px;
  height: 2px;
  background: var(--ac, #16A34A);
  border-radius: 1px 1px 0 0;
}

/* ─── MONTO HERO ─────────────────────────────────────── */
.nm-monto-section { padding: 24px 24px 0; }
.nm-monto-eyebrow {
  display: block;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.07em;
  color: #9CA3AF;
  text-transform: uppercase;
  margin-bottom: 8px;
}
.nm-monto-row {
  display: flex;
  align-items: baseline;
  gap: 2px;
}
.nm-monto-prefix {
  font-size: 38px;
  font-weight: 700;
  font-family: 'Geist Mono', 'JetBrains Mono', 'Fira Code', ui-monospace, monospace;
  line-height: 1;
  transition: color 0.15s;
  flex-shrink: 0;
}
.nm-monto-input {
  flex: 1;
  border: none;
  outline: none;
  background: transparent;
  font-size: 42px;
  font-weight: 700;
  font-family: 'Geist Mono', 'JetBrains Mono', 'Fira Code', ui-monospace, monospace;
  line-height: 1;
  width: 100%;
  min-width: 0;
  transition: color 0.15s;
}
.nm-monto-input::placeholder { color: #E5E7EB; }
.nm-monto-input--err + .nm-monto-bar { border-color: #DC2626 !important; }

.nm-monto-bar {
  height: 0;
  border-bottom: 1.5px solid #E5E7EB;
  margin-top: 10px;
  transition: border-color 0.15s;
}
.nm-monto-projection {
  margin-top: 8px;
  font-size: 12px;
  min-height: 18px;
}
.nm-proj-base  { color: #9CA3AF; }
.nm-proj-sep   { color: #9CA3AF; }
.nm-proj-next  { color: #374151; font-weight: 500; }
.nm-proj-delta { font-weight: 600; }
.nm-proj-empty { color: #9CA3AF; font-style: italic; }
.nm-monto-err  { display: block; font-size: 11px; color: #DC2626; margin-top: 4px; }

/* ─── CAMPOS PRINCIPALES ─────────────────────────────── */
.nm-fields {
  padding: 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.nm-field { position: relative; }
.nm-label {
  display: block;
  font-size: 12px;
  font-weight: 500;
  color: #374151;
  margin-bottom: 6px;
}
.nm-req { color: #DC2626; margin-left: 2px; }
.nm-opt { font-size: 11px; font-weight: 400; color: #9CA3AF; margin-left: 4px; }

.nm-input {
  display: block;
  width: 100%;
  height: 38px;
  padding: 0 12px;
  font-size: 14px;
  color: #111827;
  background: #FFFFFF;
  border: 1px solid #E5E7EB;
  border-radius: 8px;
  outline: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  box-sizing: border-box;
  font-family: inherit;
}
.nm-input:focus {
  border-color: var(--tc, #16A34A);
  box-shadow: 0 0 0 3px var(--tr, rgba(22,163,74,0.1));
}
.nm-input--err { border-color: #DC2626; }
.nm-cuotas-hint { display: block; margin-top: .3rem; font-size: .72rem; line-height: 1.4; color: #64748b; }
.nm-cuotas-hint strong { color: #15803d; }
.nm-input--err:focus {
  border-color: #DC2626;
  box-shadow: 0 0 0 3px rgba(220,38,38,0.1);
}
.nm-input--date { cursor: pointer; }
.nm-textarea {
  height: auto;
  padding: 10px 12px;
  resize: vertical;
  min-height: 64px;
}
select.nm-input {
  cursor: pointer;
  appearance: none;
  -webkit-appearance: none;
  background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
  background-repeat: no-repeat;
  background-position: right 10px center;
  background-size: 16px;
  padding-right: 32px;
}
.nm-err {
  display: block;
  font-size: 11px;
  color: #DC2626;
  margin-top: 4px;
}


/* COMBOBOX */
.nm-combo {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 38px;
  padding: 0 12px;
  background: #FFFFFF;
  border: 1px solid #E5E7EB;
  border-radius: 8px;
  cursor: pointer;
  gap: 8px;
  transition: border-color 0.15s, box-shadow 0.15s;
  user-select: none;
}
.nm-combo:hover:not(.nm-combo--open) { border-color: #D1D5DB; }
.nm-combo--open {
  border-color: var(--tc, #16A34A);
  box-shadow: 0 0 0 3px var(--tr, rgba(22,163,74,0.1));
}
.nm-combo--err { border-color: #DC2626; }
.nm-combo--sel { cursor: pointer; }

.nm-combo-val {
  flex: 1;
  font-size: 14px;
  color: #111827;
  text-align: left;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.nm-combo-ph {
  flex: 1;
  font-size: 14px;
  color: #9CA3AF;
  text-align: left;
}
.nm-combo-chev {
  font-size: 12px;
  color: #9CA3AF;
  transition: transform 0.18s ease;
  flex-shrink: 0;
}
.nm-combo-chev--up { transform: rotate(180deg); }

.nm-combo-clear {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 4px;
  border: none;
  background: transparent;
  color: #9CA3AF;
  cursor: pointer;
  font-size: 15px;
  transition: background 0.1s, color 0.1s;
  flex-shrink: 0;
}
.nm-combo-clear:hover { background: #F3F4F6; color: #374151; }

/* DROPDOWN */
.nm-dropdown {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  background: #FFFFFF;
  border: 1px solid #E5E7EB;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.08), 0 1px 3px rgba(0,0,0,0.06);
  z-index: 200;
  overflow: hidden;
}
.nm-drop-search {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border-bottom: 1px solid #F3F4F6;
}
.nm-drop-ico  { font-size: 12px; color: #9CA3AF; flex-shrink: 0; }
.nm-drop-input {
  flex: 1;
  border: none;
  outline: none;
  font-size: 13px;
  color: #111827;
  background: transparent;
  font-family: inherit;
}
.nm-drop-input::placeholder { color: #9CA3AF; }
.nm-drop-list {
  max-height: 200px;
  overflow-y: auto;
  padding: 4px;
}
.nm-drop-opt {
  display: block;
  width: 100%;
  height: 36px;
  padding: 0 12px;
  font-size: 14px;
  color: #374151;
  background: transparent;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  text-align: left;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-family: inherit;
  transition: background 0.08s;
}
.nm-drop-opt:hover,
.nm-drop-opt--hl  { background: #F9FAFB; }
.nm-drop-opt--sel { background: #F0FDF4; color: #16A34A; font-weight: 500; }
.nm-drop-empty    { padding: 12px; font-size: 13px; color: #9CA3AF; text-align: center; }

/* DROPDOWN TRANSITION */
.nm-drop-enter-active { transition: opacity 0.12s ease, transform 0.12s ease; }
.nm-drop-leave-active { transition: opacity 0.08s ease; }
.nm-drop-enter-from   { opacity: 0; transform: translateY(-4px); }
.nm-drop-leave-to     { opacity: 0; }

/* PACIENTE HINT */
.nm-pac-hint {
  margin-top: 6px;
  font-size: 11px;
  color: #6B7280;
  line-height: 1.4;
}

/* FIELD SLIDE */
.field-slide-enter-active { transition: all 0.2s ease; }
.field-slide-leave-active { transition: all 0.15s ease; }
.field-slide-enter-from,
.field-slide-leave-to     { opacity: 0; transform: translateY(-8px); }

/* ─── SEPARADOR ──────────────────────────────────────── */
.nm-hr {
  margin: 0 24px;
  border: none;
  border-top: 1px solid #F3F4F6;
}

/* ─── ACORDEÓN ───────────────────────────────────────── */
.nm-ac-hdr {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 14px 24px;
  background: transparent;
  border: none;
  cursor: pointer;
  text-align: left;
  font-family: inherit;
  transition: background 0.1s;
}
.nm-ac-hdr:hover { background: #FAFAFA; }
.nm-ac-title {
  font-size: 13px;
  font-weight: 500;
  color: #374151;
}
.nm-ac-chev {
  font-size: 14px;
  color: #9CA3AF;
  transition: transform 0.2s ease;
}
.nm-ac-chev--open { transform: rotate(180deg); }
.nm-ac-body {
  padding: 0 24px 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

/* ─── SEGMENTED ──────────────────────────────────────── */
.nm-seg { display: flex; flex-wrap: wrap; gap: 8px; }
.nm-seg-btn {
  height: 34px;
  padding: 0 16px;
  font-size: 13px;
  font-weight: 500;
  color: #374151;
  background: #FFFFFF;
  border: 1px solid #E5E7EB;
  border-radius: 6px;
  cursor: pointer;
  font-family: inherit;
  transition: all 0.12s;
  white-space: nowrap;
}
.nm-seg-btn:hover:not(.nm-seg-btn--active) { background: #F9FAFB; border-color: #D1D5DB; }

/* ─── GRID ───────────────────────────────────────────── */
.nm-grid2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

/* ─── FOOTER ─────────────────────────────────────────── */
.nm-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  padding: 0 24px;
  height: 64px;
  border-top: 1px solid #E5E7EB;
  background: #FFFFFF;
  flex-shrink: 0;
}
.nm-btn-cancel {
  height: 38px;
  padding: 0 18px;
  font-size: 14px;
  font-weight: 500;
  color: #374151;
  background: #FFFFFF;
  border: 1px solid #E5E7EB;
  border-radius: 8px;
  cursor: pointer;
  font-family: inherit;
  transition: background 0.12s;
}
.nm-btn-cancel:hover { background: #F9FAFB; }

.nm-btn-primary {
  height: 38px;
  padding: 0 20px;
  font-size: 14px;
  font-weight: 600;
  color: #FFFFFF;
  background: #166534;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-family: inherit;
  transition: opacity 0.12s, filter 0.12s;
  white-space: nowrap;
}
.nm-btn-primary:hover:not(:disabled) { filter: brightness(0.92); }
.nm-btn-primary:disabled { opacity: 0.4; cursor: not-allowed; }

/* ─── RESPONSIVE ─────────────────────────────────────── */
@media (max-width: 720px) {
  .nm-overlay { padding: 0; align-items: flex-end; }
  .nm-dialog  { width: 100%; max-width: 100%; max-height: 92vh; border-radius: 16px 16px 0 0; }
  .nm-grid2   { grid-template-columns: 1fr; }
  .nm-tabs-bar { gap: 1px; }
  .nm-tab     { font-size: 12px; }
  .nm-monto-input { font-size: 34px; }
  .nm-monto-prefix { font-size: 30px; }
}
</style>
