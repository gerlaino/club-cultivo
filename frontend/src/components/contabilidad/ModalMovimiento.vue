<script setup>
// Alta/edición de un movimiento contable, ordenado como piensa un admin: primero QUÉ PASÓ, después
// el asiento. Reemplaza a ModalNuevoMovimiento, que estaba ordenado como la tabla (tipo → categoría
// → …) y dejaba lo importante —si la compra entra al inventario— enterrado entre dos acordeones.
//
// Estructura: pantalla de intención (5 accesos) → form del flujo elegido. Los flujos comparten los
// campos base y solo cambian bloques y copy: la config vive en movimientoFlows.js, no acá.
import { ref, computed, watch, nextTick, onUnmounted } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import DestinoStock from './DestinoStock.vue'
import MovimientosFijos from './MovimientosFijos.vue'
import { useModalEscape } from '../../composables/useModalEscape.js'
import {
  FLOWS, FLOWS_ORDEN, flowDe, hoyLocal, fmtARS, fmtMiles, parseMonto,
  destinoVacio, destinoEstado, destinoPayload, esDepositoSalon,
  validarMovimiento, esValido,
} from './movimientoFlows.js'

const props = defineProps({
  modelValue:       { type: Boolean, default: false },
  pacientes:        { type: Array,  default: () => [] },
  sedes:            { type: Array,  default: () => [] },
  unidades:         { type: Array,  default: () => [] },
  categorias:       { type: Array,  default: () => [] },  // árbol: madres con subcategorias
  insumos:          { type: Array,  default: () => [] },
  depositos:        { type: Array,  default: () => [] },
  bares:            { type: Array,  default: () => [] },
  movimientoEditar: { type: Object, default: null },
  flujoInicial:     { type: String, default: '' },        // abre directo un flujo (ej. desde Depósito)
  depositoInicial:  { type: [String, Number], default: null },
  guardando:        { type: Boolean, default: false },     // lo maneja el padre: es él quien await-ea
  errorGuardado:    { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue', 'guardado', 'guardado-varios'])

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

// ─── Estado ─────────────────────────────────────────────────────────────────────
const paso    = ref('intencion')   // 'intencion' | 'form' | 'fijos'
const flujo   = ref(null)          // objeto de FLOWS
const destino = ref(destinoVacio())
const montoTexto = ref('')
const errores = ref({})
const verAsiento  = ref(false)     // categoría + sede + unidad (colapsado: es consecuencia)
const verExtras   = ref(false)     // comprobante, proveedor, notas
const fijosRef = ref(null)

function formVacio(tipo = 'egreso') {
  return {
    tipo,
    categoria_contable_id: null,
    descripcion: '',
    monto_ars: null,
    fecha: hoyLocal(),           // local: en UTC, pasadas las 21hs, se guardaba con fecha de mañana
    sede_id: null,
    unidad_negocio_id: null,
    lote_id: null,
    paciente_id: null,
    comprobante_numero: '',
    comprobante_tipo: 'sin_comprobante',
    proveedor: '',
    pagado: true,                // se registra lo que YA pasó; "pendiente" es la excepción
    medio_pago: 'efectivo',
    plan: 'unico',               // 'unico' | 'cuotas' — plan de pago, NO medio de pago
    cuotas_total: 6,
    responsable: '',
    notas: '',
  }
}
const form = ref(formVacio())

const editando = computed(() => !!props.movimientoEditar)
const esCuotas = computed(() => form.value.plan === 'cuotas' && form.value.tipo === 'egreso' && !editando.value)

// ─── Categorías ─────────────────────────────────────────────────────────────────
// Lista plana desde el árbol: subcategorías (hoja) + madres sin hijas. `area` = unidad de negocio
// efectiva (la sub hereda la de la madre).
const catsSelectables = computed(() => {
  const out = []
  for (const m of props.categorias) {
    if (m.subcategorias?.length) {
      for (const s of m.subcategorias) {
        out.push({ id: s.id, label: `${m.nombre} › ${s.nombre}`, tipo: s.tipo, clave: s.clave_efectiva,
                   area: s.unidad_negocio?.id || m.unidad_negocio?.id || null })
      }
    } else {
      out.push({ id: m.id, label: m.nombre, tipo: m.tipo, clave: m.clave_efectiva,
                 area: m.unidad_negocio?.id || null })
    }
  }
  return out
})
const catsDelTipo = computed(() => catsSelectables.value.filter(c => c.tipo === form.value.tipo))
const catActual   = computed(() => catsSelectables.value.find(c => c.id === form.value.categoria_contable_id) || null)

// Combobox de categoría
const catOpen  = ref(false)
const catQuery = ref('')
const catInput = ref(null)
const catsFiltradas = computed(() => {
  const q = catQuery.value.trim().toLowerCase()
  return q ? catsDelTipo.value.filter(c => c.label.toLowerCase().includes(q)) : catsDelTipo.value
})
function abrirCat()  { catOpen.value = true; catQuery.value = ''; nextTick(() => catInput.value?.focus()) }
function elegirCat(c) {
  form.value.categoria_contable_id = c.id
  if (!['aporte_socio', 'dispensacion'].includes(c.clave)) form.value.paciente_id = null
  catOpen.value = false
  delete errores.value.categoria
}

// El paciente aparece cuando la categoría lo pide, o cuando el flujo es un aporte.
const pacienteObligatorio = computed(() => catActual.value?.clave === 'aporte_socio' || flujo.value?.pidePaciente)
const muestraPaciente     = computed(() => pacienteObligatorio.value || catActual.value?.clave === 'dispensacion')
const pacQuery = ref('')
const pacOpen  = ref(false)
const pacInput = ref(null)
const pacsFiltrados = computed(() => {
  const q = pacQuery.value.trim().toLowerCase()
  if (!q) return props.pacientes.slice(0, 30)
  return props.pacientes.filter(p => p.label?.toLowerCase().includes(q)).slice(0, 30)
})
const pacActual = computed(() => props.pacientes.find(p => p.id === form.value.paciente_id) || null)
function abrirPac()  { pacOpen.value = true; pacQuery.value = ''; nextTick(() => pacInput.value?.focus()) }
function elegirPac(p) { form.value.paciente_id = p.id; pacOpen.value = false; delete errores.value.paciente_id }

// ─── Depósito / destino ─────────────────────────────────────────────────────────
const depositoSel = computed(() =>
  props.depositos.find(d => String(d.id) === String(destino.value.deposito_id)) || null)

// El depósito manda: fija la sede del asiento (y el área, vía su unidad de negocio).
watch(depositoSel, (dep) => {
  if (!dep) return
  if (dep.sede_id) form.value.sede_id = dep.sede_id
  if (dep.unidad_negocio_id && !form.value.unidad_negocio_id) form.value.unidad_negocio_id = dep.unidad_negocio_id
})

// ─── Monto ──────────────────────────────────────────────────────────────────────
function onMonto(e) {
  const { texto, monto } = parseMonto(e.target.value)
  montoTexto.value = texto
  form.value.monto_ars = monto
  if (monto > 0) delete errores.value.monto_ars
}

// ─── Validez (una sola fuente para el botón y el submit) ────────────────────────
const ctxValidacion = computed(() => ({
  pacienteObligatorio: pacienteObligatorio.value,
  esCuotas: esCuotas.value,
  pideDestino: !!flujo.value?.pideDestino,
  destino: { ...destinoEstado(destino.value, depositoSel.value), cantidad: destino.value.cantidad },
}))
const erroresActuales = computed(() => validarMovimiento(form.value, ctxValidacion.value))
const puedeGuardar    = computed(() => esValido(erroresActuales.value) && !props.guardando)

// ─── Navegación ─────────────────────────────────────────────────────────────────
function elegirFlujo(key) {
  const f = flowDe(key)
  if (!f) return
  flujo.value = f
  if (f.pantalla === 'fijos') { paso.value = 'fijos'; return }

  form.value = formVacio(f.tipo)
  montoTexto.value = ''
  destino.value = destinoVacio()
  errores.value = {}
  verAsiento.value = false
  verExtras.value  = false

  // Categoría sugerida por el flujo (el aporte de socio tiene clave propia).
  if (f.clavePreferida) {
    const cat = catsSelectables.value.find(c => c.clave === f.clavePreferida && c.tipo === f.tipo)
    if (cat) form.value.categoria_contable_id = cat.id
  }
  // Si vino un depósito (ej. "＋ Comprar" desde el Depósito), arranca elegido.
  if (f.pideDestino && props.depositoInicial) {
    destino.value = { ...destinoVacio(), deposito_id: props.depositoInicial }
  }
  paso.value = 'form'
}

function volver() {
  if (editando.value) { cerrar(); return }
  paso.value = 'intencion'
  flujo.value = null
}

function cerrar() { emit('update:modelValue', false) }
useModalEscape(() => { if (props.modelValue) cerrar() })

// ─── Submit ─────────────────────────────────────────────────────────────────────
// El padre es quien await-ea la API: se le pasa el payload y él controla `guardando`/`errorGuardado`.
// Así el botón queda deshabilitado durante la request (antes el estado se reseteaba al instante y un
// doble click cargaba el movimiento dos veces).
function submit() {
  errores.value = erroresActuales.value
  if (!esValido(errores.value)) return

  const payload = {
    ...form.value,
    categoria: catActual.value?.clave || 'otro',
    medio_pago: esCuotas.value ? 'en_cuotas' : form.value.medio_pago,
  }
  delete payload.plan
  const dst = flujo.value?.pideDestino ? destinoPayload(destino.value, depositoSel.value) : null
  if (dst) payload.destino = dst
  emit('guardado', payload)
}

function cargarFijos(items) {
  emit('guardado-varios', {
    items,
    marcar: (id, estado) => fijosRef.value?.marcar(id, estado),
  })
}

// ─── Apertura ───────────────────────────────────────────────────────────────────
watch(() => props.modelValue, (abierto) => {
  if (!abierto) return
  errores.value = {}

  if (props.movimientoEditar) {
    const m = props.movimientoEditar
    flujo.value = FLOWS[m.tipo === 'ingreso' ? 'ingreso' : 'gasto']
    form.value = {
      ...formVacio(m.tipo === 'ingreso' ? 'ingreso' : 'egreso'),
      categoria_contable_id: m.categoria_contable_id || null,
      descripcion: m.descripcion || '',
      monto_ars:   m.monto_ars   || null,
      fecha:       m.fecha       || hoyLocal(),
      sede_id:     m.sede?.id ?? m.sede_id ?? null,
      unidad_negocio_id: m.unidad_negocio_id || null,
      paciente_id: m.paciente_id || null,
      comprobante_numero: m.comprobante_numero || '',
      comprobante_tipo:   m.comprobante_tipo   || 'sin_comprobante',
      proveedor:   m.proveedor || '',
      pagado:      !!m.pagado,
      medio_pago:  m.medio_pago || 'efectivo',
      notas:       m.notas || '',
    }
    montoTexto.value = fmtMiles(m.monto_ars)
    verAsiento.value = true   // al editar, el asiento SÍ es lo que se viene a tocar
    verExtras.value  = !!(m.comprobante_numero || m.proveedor || m.notas)
    paso.value = 'form'
    return
  }

  destino.value = destinoVacio()
  if (props.flujoInicial && flowDe(props.flujoInicial)) elegirFlujo(props.flujoInicial)
  else { paso.value = 'intencion'; flujo.value = null; form.value = formVacio(); montoTexto.value = '' }
})

// Cerrar los dropdowns al clickear afuera
function onDocClick(e) {
  if (!e.target.closest?.('.mv-combo-wrap')) { catOpen.value = false; pacOpen.value = false }
}
watch(() => props.modelValue, (v) => {
  if (v) document.addEventListener('click', onDocClick, true)
  else   document.removeEventListener('click', onDocClick, true)
})
onUnmounted(() => document.removeEventListener('click', onDocClick, true))

// ─── Presentación ───────────────────────────────────────────────────────────────
const esEgreso = computed(() => form.value.tipo === 'egreso')
const multiSede = computed(() => (props.sedes?.length || 0) > 1)
const sedeNombre = computed(() =>
  props.sedes.find(s => String(s.id) === String(form.value.sede_id))?.nombre || null)
const cuotaMonto = computed(() => {
  const n = Number(form.value.cuotas_total)
  return esCuotas.value && form.value.monto_ars > 0 && n >= 2 ? form.value.monto_ars / n : null
})
const titulo = computed(() => {
  if (editando.value) return 'Editar movimiento'
  if (paso.value === 'intencion') return 'Nuevo movimiento'
  return flujo.value?.titulo || 'Nuevo movimiento'
})
</script>

<template>
  <Teleport to="body">
    <Transition name="mv-fade">
      <div v-if="modelValue" class="mv-ov">
        <div class="mv-dlg" role="dialog" aria-modal="true" aria-labelledby="mv-title"
             :class="{ 'mv-dlg--out': esEgreso, 'mv-dlg--in': !esEgreso }">

          <!-- Header -->
          <header class="mv-hdr">
            <button v-if="paso !== 'intencion' && !editando" type="button" class="mv-hdr-back"
                    @click="volver" aria-label="Volver">
              <i class="bi bi-arrow-left"></i>
            </button>
            <h2 class="mv-hdr-title" id="mv-title">{{ titulo }}</h2>
            <span v-if="paso === 'form' && !editando" class="mv-hdr-tag">
              {{ esEgreso ? 'Egreso' : 'Ingreso' }}
            </span>
            <button type="button" class="mv-hdr-x" @click="cerrar" aria-label="Cerrar">
              <i class="bi bi-x-lg"></i>
            </button>
          </header>

          <!-- ① Intención -->
          <div v-if="paso === 'intencion'" class="mv-body">
            <p class="mv-ask">¿Qué pasó?</p>
            <div class="mv-tiles">
              <button v-for="key in FLOWS_ORDEN" :key="key" type="button" class="mv-tile"
                      :class="{ 'mv-tile--wide': FLOWS[key].pantalla === 'fijos' }"
                      @click="elegirFlujo(key)">
                <i class="mv-tile-ico bi" :class="FLOWS[key].icono"></i>
                <span class="mv-tile-tit">{{ FLOWS[key].titulo }}</span>
                <span class="mv-tile-sub">{{ FLOWS[key].resumen }}</span>
              </button>
            </div>
          </div>

          <!-- ② Fijos del mes -->
          <div v-else-if="paso === 'fijos'" class="mv-body">
            <MovimientosFijos ref="fijosRef" @cargar="cargarFijos" @volver="volver" />
          </div>

          <!-- ③ Form del flujo -->
          <div v-else class="mv-body">

            <!-- Qué / cuánto: la línea principal -->
            <div class="mv-main">
              <label class="mv-fld mv-fld--desc">
                <span class="mv-lbl">{{ flujo?.labelDescripcion || 'Descripción' }}</span>
                <input type="text" class="mv-inp mv-inp--lg" :class="{ 'mv-inp--err': errores.descripcion }"
                       v-model.trim="form.descripcion" :placeholder="flujo?.phDescripcion" />
                <span v-if="errores.descripcion" class="mv-err">{{ errores.descripcion }}</span>
              </label>

              <label class="mv-fld mv-fld--monto">
                <span class="mv-lbl">{{ flujo?.labelMonto || 'Monto' }}</span>
                <div class="mv-monto" :class="{ 'mv-monto--err': errores.monto_ars }">
                  <span class="mv-monto-sig">{{ esEgreso ? '−' : '+' }}$</span>
                  <input type="text" inputmode="decimal" class="mv-monto-inp"
                         :value="montoTexto" @input="onMonto" placeholder="0" />
                </div>
                <span v-if="errores.monto_ars" class="mv-err">{{ errores.monto_ars }}</span>
              </label>
            </div>

            <!-- Paciente (aportes) -->
            <div v-if="muestraPaciente" class="mv-fld mv-combo-wrap">
              <span class="mv-lbl">
                Paciente <span v-if="pacienteObligatorio" class="mv-req">*</span>
                <span v-else class="mv-opt">(opcional)</span>
              </span>
              <button type="button" class="mv-combo" :class="{ 'mv-combo--err': errores.paciente_id }"
                      @click="pacOpen ? pacOpen = false : abrirPac()">
                <span v-if="pacActual" class="mv-combo-val">{{ pacActual.label }}</span>
                <span v-else class="mv-combo-ph">Buscar por nombre o DNI…</span>
                <i class="bi bi-chevron-down"></i>
              </button>
              <div v-if="pacOpen" class="mv-drop">
                <input ref="pacInput" v-model="pacQuery" type="text" class="mv-drop-inp"
                       placeholder="Nombre o DNI…" autocomplete="off" />
                <div class="mv-drop-list">
                  <button v-for="p in pacsFiltrados" :key="p.id" type="button" class="mv-drop-opt"
                          :class="{ 'mv-drop-opt--on': form.paciente_id === p.id }" @click="elegirPac(p)">
                    {{ p.label }}
                  </button>
                  <p v-if="!pacsFiltrados.length" class="mv-drop-empty">Sin resultados</p>
                </div>
              </div>
              <span v-if="errores.paciente_id" class="mv-err">{{ errores.paciente_id }}</span>
              <p v-if="pacActual && pacienteObligatorio" class="mv-hint">
                Se acredita en la cuenta corriente de <strong>{{ pacActual.label.split('—')[0].trim() }}</strong>.
              </p>
            </div>

            <!-- Destino del stock (compras) -->
            <DestinoStock
              v-if="flujo?.pideDestino"
              v-model="destino"
              :depositos="depositos" :insumos="insumos" :bares="bares"
              :monto="form.monto_ars" :errores="errores"
            />
            <span v-if="errores.destino_item || errores.destino_cantidad" class="mv-err">
              {{ errores.destino_item || errores.destino_cantidad }}
            </span>

            <!-- Cuándo + estado de pago -->
            <div class="mv-row">
              <label class="mv-fld mv-fld--fecha">
                <span class="mv-lbl">¿Cuándo?</span>
                <AppDatePicker v-model="form.fecha" />
                <span v-if="errores.fecha" class="mv-err">{{ errores.fecha }}</span>
              </label>

              <div v-if="!esCuotas" class="mv-fld">
                <span class="mv-lbl">{{ esEgreso ? '¿Ya lo pagaste?' : '¿Ya lo cobraste?' }}</span>
                <div class="mv-seg">
                  <button type="button" class="mv-seg-b" :class="{ 'mv-seg-b--on': form.pagado }"
                          @click="form.pagado = true">Sí</button>
                  <button type="button" class="mv-seg-b" :class="{ 'mv-seg-b--on': !form.pagado }"
                          @click="form.pagado = false">Pendiente</button>
                </div>
              </div>

              <div class="mv-fld">
                <span class="mv-lbl">{{ esEgreso ? '¿Cómo pagaste?' : '¿Cómo entró?' }}</span>
                <select class="mv-inp" v-model="form.medio_pago">
                  <option v-for="mp in MEDIOS_PAGO" :key="mp.value" :value="mp.value">{{ mp.label }}</option>
                </select>
              </div>
            </div>

            <!-- Plan de pago: cuotas. Es un PLAN, no un medio de pago (antes convivían en el mismo
                 selector, así que pagar en cuotas te tapaba con qué pagabas). -->
            <div v-if="esEgreso && !editando" class="mv-plan">
              <div class="mv-seg mv-seg--plan">
                <button type="button" class="mv-seg-b" :class="{ 'mv-seg-b--on': form.plan === 'unico' }"
                        @click="form.plan = 'unico'">Pago único</button>
                <button type="button" class="mv-seg-b" :class="{ 'mv-seg-b--on': form.plan === 'cuotas' }"
                        @click="form.plan = 'cuotas'">En cuotas</button>
              </div>
              <div v-if="esCuotas" class="mv-cuotas">
                <label class="mv-fld mv-fld--sm">
                  <span class="mv-lbl">Cuotas</span>
                  <input type="number" min="2" max="120" step="1" class="mv-inp"
                         :class="{ 'mv-inp--err': errores.cuotas_total }" v-model.number="form.cuotas_total" />
                </label>
                <label class="mv-fld mv-fld--grow">
                  <span class="mv-lbl">Tarjeta / responsable <span class="mv-opt">(opcional)</span></span>
                  <input type="text" class="mv-inp" v-model.trim="form.responsable"
                         placeholder="Ej: Tarjeta del club" />
                </label>
                <p class="mv-hint mv-hint--full">
                  <template v-if="cuotaMonto">
                    {{ form.cuotas_total }} cuotas de <strong>{{ fmtARS(cuotaMonto) }}</strong>,
                    mensuales desde la fecha elegida. El monto de arriba es el total.
                  </template>
                  <template v-else>El monto de arriba es el <strong>total</strong>: se divide en cuotas mensuales.</template>
                </p>
              </div>
            </div>

            <!-- El asiento: consecuencia del hecho, no la puerta de entrada -->
            <div class="mv-acc">
              <button type="button" class="mv-acc-hdr" @click="verAsiento = !verAsiento" :aria-expanded="verAsiento">
                <i class="bi" :class="verAsiento ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
                <span class="mv-acc-tit">Clasificación contable</span>
                <span class="mv-acc-sum" :class="{ 'mv-acc-sum--err': errores.categoria }">
                  {{ catActual?.label || 'elegir categoría' }}<template v-if="sedeNombre"> · {{ sedeNombre }}</template>
                </span>
              </button>
              <div v-if="verAsiento" class="mv-acc-body">
                <div class="mv-fld mv-combo-wrap">
                  <span class="mv-lbl">Categoría <span class="mv-req">*</span></span>
                  <button type="button" class="mv-combo" :class="{ 'mv-combo--err': errores.categoria }"
                          @click="catOpen ? catOpen = false : abrirCat()">
                    <span v-if="catActual" class="mv-combo-val">{{ catActual.label }}</span>
                    <span v-else class="mv-combo-ph">Elegí una categoría</span>
                    <i class="bi bi-chevron-down"></i>
                  </button>
                  <div v-if="catOpen" class="mv-drop">
                    <input ref="catInput" v-model="catQuery" type="text" class="mv-drop-inp"
                           placeholder="Buscar…" autocomplete="off" />
                    <div class="mv-drop-list">
                      <button v-for="c in catsFiltradas" :key="c.id" type="button" class="mv-drop-opt"
                              :class="{ 'mv-drop-opt--on': form.categoria_contable_id === c.id }"
                              @click="elegirCat(c)">{{ c.label }}</button>
                      <p v-if="!catsFiltradas.length" class="mv-drop-empty">Sin resultados</p>
                    </div>
                  </div>
                  <span v-if="errores.categoria" class="mv-err">{{ errores.categoria }}</span>
                </div>

                <div class="mv-row">
                  <label v-if="multiSede" class="mv-fld mv-fld--grow">
                    <span class="mv-lbl">
                      Sede
                      <span v-if="depositoSel?.sede_id" class="mv-opt">(la fija el depósito)</span>
                    </span>
                    <select class="mv-inp" v-model="form.sede_id" :disabled="!!depositoSel?.sede_id">
                      <option :value="null">— Sin sede —</option>
                      <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                    </select>
                  </label>
                  <label v-if="unidades.length" class="mv-fld mv-fld--grow">
                    <span class="mv-lbl">Área <span class="mv-opt">(opcional)</span></span>
                    <select class="mv-inp" v-model="form.unidad_negocio_id">
                      <option :value="null">— Sin área —</option>
                      <option v-for="u in unidades" :key="u.id" :value="u.id">{{ u.nombre }}</option>
                    </select>
                  </label>
                </div>
              </div>
            </div>

            <!-- Comprobante y extras -->
            <div class="mv-acc">
              <button type="button" class="mv-acc-hdr" @click="verExtras = !verExtras" :aria-expanded="verExtras">
                <i class="bi" :class="verExtras ? 'bi-chevron-down' : 'bi-chevron-right'"></i>
                <span class="mv-acc-tit">Comprobante y notas</span>
                <span class="mv-acc-sum">{{ form.proveedor || 'opcional' }}</span>
              </button>
              <div v-if="verExtras" class="mv-acc-body">
                <div class="mv-row">
                  <label class="mv-fld mv-fld--grow">
                    <span class="mv-lbl">Proveedor / origen</span>
                    <input type="text" class="mv-inp" v-model.trim="form.proveedor" placeholder="Edenor, farmacia…" />
                  </label>
                  <label class="mv-fld mv-fld--sm2">
                    <span class="mv-lbl">Comprobante</span>
                    <select class="mv-inp" v-model="form.comprobante_tipo">
                      <option v-for="c in COMPROBANTE_TIPOS" :key="c.value" :value="c.value">{{ c.label }}</option>
                    </select>
                  </label>
                  <label class="mv-fld mv-fld--sm2">
                    <span class="mv-lbl">N°</span>
                    <input type="text" class="mv-inp" v-model.trim="form.comprobante_numero" placeholder="0001-00001234" />
                  </label>
                </div>
                <label class="mv-fld">
                  <span class="mv-lbl">Notas</span>
                  <textarea class="mv-inp mv-ta" v-model.trim="form.notas" rows="2" placeholder="Notas internas…"></textarea>
                </label>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <footer v-if="paso === 'form'" class="mv-ftr">
            <p v-if="errorGuardado" class="mv-ftr-err"><i class="bi bi-exclamation-triangle-fill"></i> {{ errorGuardado }}</p>
            <button type="button" class="mv-btn-ghost" @click="cerrar">Cancelar</button>
            <button type="button" class="mv-btn" :disabled="!puedeGuardar" @click="submit">
              {{ guardando ? 'Guardando…' : (editando ? 'Guardar cambios' : (flujo?.cta || 'Registrar')) }}
            </button>
          </footer>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* Tokens del design system: nada de hex sueltos, que era parte de por qué el form se veía a
   destono del resto de la app. */
.mv-ov {
  position: fixed; inset: 0; z-index: 1000;
  display: flex; align-items: center; justify-content: center; padding: var(--sp-4);
  background: rgb(15 20 17 / 0.45); backdrop-filter: blur(3px);
}
.mv-fade-enter-active, .mv-fade-leave-active { transition: opacity var(--t-base); }
.mv-fade-enter-from, .mv-fade-leave-to { opacity: 0; }
.mv-fade-enter-active .mv-dlg { transition: transform var(--t-base), opacity var(--t-base); }
.mv-fade-enter-from .mv-dlg { transform: translateY(12px) scale(.985); opacity: 0; }

.mv-dlg {
  width: 620px; max-width: 100%; max-height: 88vh;
  display: flex; flex-direction: column; overflow: hidden;
  background: #fff; border-radius: var(--r-xl); box-shadow: var(--sh-3), 0 12px 48px rgb(0 0 0 / .12);
  font-family: var(--font-ui);
  --acc: var(--c-leaf-700);
}
.mv-dlg--out { --acc: var(--c-rust-600); }
.mv-dlg--in  { --acc: var(--c-leaf-600); }

/* Header */
.mv-hdr {
  display: flex; align-items: center; gap: var(--sp-2);
  height: 56px; padding: 0 var(--sp-4) 0 var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0;
}
.mv-hdr-back, .mv-hdr-x {
  display: flex; align-items: center; justify-content: center;
  width: 32px; height: 32px; border: none; border-radius: var(--r-lg);
  background: transparent; color: var(--c-ink-500); cursor: pointer; transition: background var(--t-fast);
}
.mv-hdr-back { margin-left: calc(var(--sp-3) * -1); }
.mv-hdr-back:hover, .mv-hdr-x:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.mv-hdr-title { margin: 0; font-size: var(--fs-16); font-weight: 600; color: var(--c-ink-900); font-family: var(--font-display); }
.mv-hdr-tag {
  font-size: var(--fs-12); font-weight: 700; padding: 2px 8px; border-radius: var(--r-pill);
  color: var(--acc); background: color-mix(in srgb, var(--acc) 10%, transparent);
}
.mv-hdr-x { margin-left: auto; }

/* Body */
.mv-body { flex: 1; overflow-y: auto; padding: var(--sp-5); display: flex; flex-direction: column; gap: var(--sp-4); }

/* ① Intención */
.mv-ask { margin: 0; font-size: var(--fs-18); font-weight: 600; color: var(--c-ink-900); font-family: var(--font-display); }
.mv-tiles { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.mv-tile {
  display: flex; flex-direction: column; align-items: flex-start; gap: 2px;
  padding: var(--sp-4); text-align: left; cursor: pointer;
  background: #fff; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg);
  transition: border-color var(--t-fast), background var(--t-fast), transform var(--t-fast);
}
.mv-tile:hover { border-color: var(--c-leaf-500); background: var(--c-leaf-50); transform: translateY(-1px); }
.mv-tile--wide { grid-column: 1 / -1; }
.mv-tile-ico { font-size: var(--fs-20); color: var(--c-leaf-700); margin-bottom: var(--sp-1); }
.mv-tile-tit { font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.mv-tile-sub { font-size: var(--fs-12); color: var(--c-ink-500); line-height: var(--lh-base); }

/* ③ Form */
.mv-main { display: flex; gap: var(--sp-4); align-items: flex-start; flex-wrap: wrap; }
.mv-fld { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
.mv-fld--desc  { flex: 1 1 260px; }
.mv-fld--monto { flex: 0 0 190px; }
.mv-fld--fecha { flex: 0 0 170px; }
.mv-fld--grow  { flex: 1 1 180px; }
.mv-fld--sm    { flex: 0 0 90px; }
.mv-fld--sm2   { flex: 0 0 140px; }
.mv-row { display: flex; gap: var(--sp-4); flex-wrap: wrap; align-items: flex-start; }

.mv-lbl { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-500); }
.mv-req { color: var(--c-rust-600); }
.mv-opt { font-weight: 400; color: var(--c-ink-300); }
.mv-inp {
  height: 40px; padding: 0 12px; width: 100%;
  border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); background: #fff;
  font-size: var(--fs-14); font-family: var(--font-ui); color: var(--c-ink-900);
  outline: none; transition: border-color var(--t-fast);
}
.mv-inp:focus { border-color: var(--c-leaf-600); }
.mv-inp--lg { height: 44px; font-size: var(--fs-16); }
.mv-inp--err { border-color: var(--c-rust-600); }
.mv-ta { height: auto; padding: 10px 12px; resize: vertical; line-height: var(--lh-base); }

/* Monto */
.mv-monto {
  display: flex; align-items: center; height: 44px; padding: 0 12px;
  border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md);
  transition: border-color var(--t-fast);
}
.mv-monto:focus-within { border-color: var(--acc); }
.mv-monto--err { border-color: var(--c-rust-600); }
.mv-monto-sig { font-size: var(--fs-16); font-weight: 700; color: var(--acc); margin-right: 4px; }
.mv-monto-inp {
  flex: 1; min-width: 0; border: none; outline: none; background: none;
  font-family: var(--font-mono); font-size: var(--fs-20); font-weight: 600;
  color: var(--acc); text-align: right;
}

/* Segmentado */
.mv-seg { display: inline-flex; background: var(--c-ink-100); border-radius: var(--r-md); padding: 3px; gap: 2px; }
.mv-seg--plan { align-self: flex-start; }
.mv-seg-b {
  height: 32px; padding: 0 14px; border: none; border-radius: var(--r-sm); background: transparent;
  font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-500); cursor: pointer;
  transition: background var(--t-fast), color var(--t-fast);
}
.mv-seg-b--on { background: #fff; color: var(--c-ink-900); box-shadow: var(--sh-1); }

.mv-plan { display: flex; flex-direction: column; gap: var(--sp-3); }
.mv-cuotas { display: flex; gap: var(--sp-3); flex-wrap: wrap; align-items: flex-start; }

/* Combobox */
.mv-combo-wrap { position: relative; }
.mv-combo {
  display: flex; align-items: center; gap: var(--sp-2); width: 100%; height: 40px; padding: 0 12px;
  border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); background: #fff;
  font-size: var(--fs-14); font-family: var(--font-ui); color: var(--c-ink-900);
  cursor: pointer; text-align: left; transition: border-color var(--t-fast);
}
.mv-combo:hover { border-color: var(--c-leaf-500); }
.mv-combo--err { border-color: var(--c-rust-600); }
.mv-combo-val { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.mv-combo-ph  { flex: 1; color: var(--c-ink-300); }
.mv-drop {
  position: absolute; top: calc(100% + 4px); left: 0; right: 0; z-index: 20;
  background: #fff; border: 1px solid var(--c-ink-300); border-radius: var(--r-lg); box-shadow: var(--sh-3);
  overflow: hidden;
}
.mv-drop-inp {
  width: 100%; height: 38px; padding: 0 12px; border: none; border-bottom: 1px solid var(--c-ink-100);
  font-size: var(--fs-14); font-family: var(--font-ui); outline: none;
}
.mv-drop-list { max-height: 220px; overflow-y: auto; }
.mv-drop-opt {
  display: block; width: 100%; padding: 9px 12px; border: none; background: none; text-align: left;
  font-size: var(--fs-13); color: var(--c-ink-700); cursor: pointer;
}
.mv-drop-opt:hover { background: var(--c-leaf-50); }
.mv-drop-opt--on { background: var(--c-leaf-100); color: var(--c-leaf-900); font-weight: 600; }
.mv-drop-empty { margin: 0; padding: 12px; font-size: var(--fs-13); color: var(--c-ink-500); text-align: center; }

/* Acordeones */
.mv-acc { border-top: 1px solid var(--c-ink-100); padding-top: var(--sp-3); }
.mv-acc-hdr {
  display: flex; align-items: center; gap: var(--sp-2); width: 100%;
  background: none; border: none; padding: 2px 0; cursor: pointer; color: var(--c-ink-700);
}
.mv-acc-hdr i { font-size: var(--fs-12); color: var(--c-ink-500); }
.mv-acc-tit { font-size: var(--fs-13); font-weight: 600; }
.mv-acc-sum {
  margin-left: auto; font-size: var(--fs-12); color: var(--c-ink-500);
  max-width: 55%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.mv-acc-sum--err { color: var(--c-rust-600); font-weight: 600; }
.mv-acc-body { display: flex; flex-direction: column; gap: var(--sp-3); padding-top: var(--sp-3); }

.mv-hint { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); line-height: var(--lh-base); }
.mv-hint--full { flex: 1 1 100%; }
.mv-err { font-size: var(--fs-12); color: var(--c-rust-600); font-weight: 500; }

/* Footer */
.mv-ftr {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5); border-top: 1px solid var(--c-ink-100); flex-shrink: 0;
  background: var(--c-leaf-50);
}
.mv-ftr-err { margin: 0 auto 0 0; font-size: var(--fs-12); color: var(--c-rust-600); font-weight: 600; display: flex; align-items: center; gap: 5px; }
.mv-btn-ghost {
  margin-left: auto; background: none; border: none; color: var(--c-ink-500);
  font-size: var(--fs-14); font-weight: 600; cursor: pointer; padding: 8px 4px;
}
.mv-btn-ghost:hover { color: var(--c-ink-900); }
.mv-btn {
  height: 40px; padding: 0 20px; border: none; border-radius: var(--r-md);
  background: var(--c-leaf-800); color: #fff;
  font-size: var(--fs-14); font-weight: 600; cursor: pointer; transition: background var(--t-fast);
}
.mv-btn:hover:not(:disabled) { background: var(--c-leaf-900); }
.mv-btn:disabled { background: var(--c-ink-300); cursor: default; }

@media (max-width: 620px) {
  .mv-ov { padding: 0; }
  .mv-dlg { width: 100%; max-height: 100vh; height: 100%; border-radius: 0; }
  .mv-tiles { grid-template-columns: 1fr; }
  .mv-fld--monto, .mv-fld--fecha { flex: 1 1 100%; }
}
</style>
