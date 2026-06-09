<script setup>
import { ref, watch, computed, onMounted } from 'vue'
import { listDispensacionesFecha, exportDispensacionesCSV, listPacientes, getPaciente, listSedes } from '../lib/api.js'
import { formaLabel, formatARS, formatFecha } from '../lib/formatters.js'
import { RouterLink } from 'vue-router'
import { Download, RefreshCw, Truck, Search, Plus, X, Filter } from 'lucide-vue-next'
import ModalNuevaDispensacion from '../components/pacientes/ModalNuevaDispensacion.vue'

// ── Modal: buscar paciente (para nueva dispensación O para filtrar) ─────────────
const showBuscarPaciente   = ref(false)
const modoModal            = ref('dispensar') // 'dispensar' | 'filtrar'
const buscaPaciente        = ref('')
const pacientesLista       = ref([])
const loadingPacientes     = ref(false)
const cargandoPaciente     = ref(false)

const showDispensarModal   = ref(false)
const pacienteSeleccionado = ref(null)

async function abrirNuevaDispensacion() {
  modoModal.value       = 'dispensar'
  buscaPaciente.value   = ''
  pacientesLista.value  = []
  showBuscarPaciente.value = true
  await buscarPacientes()
}

function abrirFiltrarSocio() {
  modoModal.value       = 'filtrar'
  buscaPaciente.value   = ''
  pacientesLista.value  = []
  showBuscarPaciente.value = true
  buscarPacientes()
}

async function buscarPacientes() {
  loadingPacientes.value = true
  try {
    const p = {}
    if (buscaPaciente.value.trim()) p.q = buscaPaciente.value.trim()
    const { data } = await listPacientes(p)
    pacientesLista.value = data.data ?? data.pacientes ?? []
  } catch { pacientesLista.value = [] }
  finally { loadingPacientes.value = false }
}

watch(buscaPaciente, () => buscarPacientes())

async function seleccionarPacienteModal(paciente) {
  if (modoModal.value === 'filtrar') {
    filtroSocio.value = { id: paciente.id, nombre: `${paciente.apellido}, ${paciente.nombre}` }
    showBuscarPaciente.value = false
    return
  }
  cargandoPaciente.value = true
  try {
    const { data } = await getPaciente(paciente.id)
    pacienteSeleccionado.value = data.data ?? data
    showBuscarPaciente.value   = false
    showDispensarModal.value   = true
  } catch {} finally { cargandoPaciente.value = false }
}

function onDispensacionGuardada() {
  showDispensarModal.value = false
  cargar()
}

// ── Fechas ─────────────────────────────────────────────────────────────────────
const hoy = new Date().toISOString().slice(0, 10)
const desdeDefault = () => {
  const d = new Date(); d.setDate(d.getDate() - 6); return d.toISOString().slice(0, 10)
}
const desde = ref(desdeDefault())
const hasta  = ref(hoy)

// ── Filtros server-side ────────────────────────────────────────────────────────
const filtroSede      = ref('')
const filtroMedioPago = ref('')
const filtroForma     = ref('')
const filtroSocio     = ref(null) // { id, nombre }

const sedes = ref([])
onMounted(async () => {
  try { const { data } = await listSedes(); sedes.value = data ?? [] } catch {}
})

const hayFiltrosActivos = computed(() =>
  filtroSede.value || filtroMedioPago.value || filtroForma.value || filtroSocio.value
)

function limpiarFiltros() {
  filtroSede.value      = ''
  filtroMedioPago.value = ''
  filtroForma.value     = ''
  filtroSocio.value     = null
}

function filtrarPorSocio(d) {
  filtroSocio.value = { id: d.paciente_id, nombre: d.paciente_nombre }
}

// ── Data ───────────────────────────────────────────────────────────────────────
const loading   = ref(false)
const exporting = ref(false)
const allDisps  = ref([])

const dispensaciones = computed(() => allDisps.value)

const totalRecaudado = computed(() => allDisps.value.reduce((s, d) => s + (d.aporte_socio_ars ?? 0), 0))
const totalGramos    = computed(() => allDisps.value.reduce((s, d) => s + (d.cantidad ?? 0), 0))
const totalConEnvio  = computed(() => allDisps.value.filter(d => d.con_envio).length)

const resumenPago = computed(() => {
  const map = {}
  for (const d of allDisps.value) {
    const k = d.medio_pago || 'otro'
    if (!map[k]) map[k] = { count: 0, total: 0 }
    map[k].count++
    map[k].total += d.aporte_socio_ars ?? 0
  }
  return Object.entries(map).map(([medio, v]) => ({ medio, ...v })).sort((a, b) => b.total - a.total)
})

function buildParams() {
  const p = {}
  if (desde.value)           p.desde        = desde.value
  if (hasta.value)           p.hasta        = hasta.value
  if (filtroSede.value)      p.sede_id      = filtroSede.value
  if (filtroMedioPago.value) p.medio_pago   = filtroMedioPago.value
  if (filtroForma.value)     p.forma_producto = filtroForma.value
  if (filtroSocio.value)     p.paciente_id  = filtroSocio.value.id
  return p
}

async function cargar() {
  if (!desde.value && !hasta.value) return
  loading.value = true
  try {
    const { data } = await listDispensacionesFecha(buildParams())
    allDisps.value = data.dispensaciones ?? []
  } catch { allDisps.value = [] }
  finally { loading.value = false }
}

watch([desde, hasta, filtroSede, filtroMedioPago, filtroForma, filtroSocio], () => {
  if (!desde.value || !hasta.value || desde.value > hasta.value) return
  cargar()
}, { immediate: true })

async function exportar() {
  exporting.value = true
  try {
    const { data } = await exportDispensacionesCSV(buildParams())
    const url = URL.createObjectURL(new Blob([data], { type: 'text/csv' }))
    const a   = document.createElement('a')
    a.href    = url
    a.download = `dispensaciones_${desde.value}_${hasta.value}.csv`
    a.click()
    URL.revokeObjectURL(url)
  } catch {} finally { exporting.value = false }
}

function setRango(dias) {
  const d = new Date(); d.setDate(d.getDate() - (dias - 1))
  desde.value = d.toISOString().slice(0, 10)
  hasta.value = hoy
}

function formatHora(ts) {
  if (!ts) return '—'
  return new Date(ts).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}
function medioPagoLabel(m) {
  const L = { efectivo: 'Efectivo', transferencia: 'Transf.', debito: 'Débito', credito: 'Crédito', cuenta_corriente: 'Cta. cte.', credito_gramos: 'Cred. g', no_abona: 'No abona' }
  return L[m] || m || '—'
}
function medioPagoClass(m) {
  const C = { efectivo: 'hd__pago--verde', transferencia: 'hd__pago--azul', debito: 'hd__pago--azul', credito: 'hd__pago--morado', cuenta_corriente: 'hd__pago--amber', credito_gramos: 'hd__pago--teal', no_abona: 'hd__pago--gris' }
  return C[m] || 'hd__pago--gris'
}
function descuentoPct(d) {
  const pu = d.precio_unitario_ars
  const ps = d.stock?.precio_sugerido_ars
  if (!pu || !ps || pu >= ps) return null
  return Math.round((1 - pu / ps) * 100)
}

const MEDIOS_PAGO = [
  { value: 'efectivo', label: 'Efectivo' }, { value: 'transferencia', label: 'Transferencia' },
  { value: 'debito', label: 'Débito' }, { value: 'credito', label: 'Crédito' },
  { value: 'cuenta_corriente', label: 'Cta. corriente' }, { value: 'credito_gramos', label: 'Crédito gramos' },
  { value: 'no_abona', label: 'No abona' },
]
const FORMAS = [
  { value: 'flor_seca', label: 'Flor seca' }, { value: 'hash', label: 'Hash' },
  { value: 'aceite', label: 'Aceite' }, { value: 'tintura', label: 'Tintura' },
  { value: 'crema', label: 'Crema' }, { value: 'capsula', label: 'Cápsula' },
  { value: 'comestible', label: 'Comestible' }, { value: 'prensado', label: 'Prensado' },
  { value: 'preroll', label: 'Preroll' }, { value: 'externo', label: 'Externo' },
  { value: 'otro', label: 'Otro' },
]
</script>

<template>
  <div class="hd">

    <!-- Header -->
    <div class="hd__top">
      <div>
        <h1 class="hd__title">Dispensaciones</h1>
        <p class="hd__sub">Consultá y exportá el historial del período seleccionado</p>
      </div>
      <div class="hd__top-actions">
        <button class="hd__btn-nueva" @click="abrirNuevaDispensacion">
          <Plus :size="14" :stroke-width="2.5" />
          Nueva dispensación
        </button>
        <button class="hd__btn-refresh" :disabled="loading" @click="cargar">
          <RefreshCw :size="14" :stroke-width="2" :class="{ 'hd__spin': loading }" />
        </button>
        <button class="hd__btn-export" :disabled="exporting || !dispensaciones.length" @click="exportar">
          <Download :size="14" :stroke-width="2" />
          {{ exporting ? 'Exportando…' : 'CSV' }}
        </button>
      </div>
    </div>

    <!-- Modal: buscar paciente (nueva dispensación o filtro) -->
    <Teleport to="body">
      <Transition name="hd-modal">
        <div v-if="showBuscarPaciente" class="hd__modal-overlay" @click.self="showBuscarPaciente = false">
          <div class="hd__modal-box hd__modal-box--narrow">
            <div class="hd__modal-header">
              <h2 class="hd__modal-title">
                {{ modoModal === 'filtrar' ? 'Filtrar por socio' : 'Seleccionar paciente' }}
              </h2>
              <button class="hd__modal-close" @click="showBuscarPaciente = false">
                <X :size="16" :stroke-width="2" />
              </button>
            </div>
            <div class="hd__modal-body hd__buscar-body">
              <div class="hd__buscar-search-wrap">
                <Search :size="14" :stroke-width="2" class="hd__search-ico" />
                <input
                  v-model="buscaPaciente"
                  type="search"
                  class="hd__buscar-search"
                  placeholder="Buscar por nombre, apellido o DNI…"
                  autofocus
                />
              </div>
              <div v-if="loadingPacientes || cargandoPaciente" class="hd__buscar-loading">
                <i class="bi bi-arrow-repeat hd__spin" style="font-size:1.2rem;color:#94a3b8"></i>
              </div>
              <div v-else-if="!pacientesLista.length" class="hd__buscar-empty">
                Sin resultados{{ buscaPaciente ? ` para "${buscaPaciente}"` : '' }}
              </div>
              <div v-else class="hd__buscar-lista">
                <button
                  v-for="p in pacientesLista"
                  :key="p.id"
                  class="hd__buscar-item"
                  @click="seleccionarPacienteModal(p)"
                >
                  <div class="hd__buscar-nombre">{{ p.apellido }}, {{ p.nombre }}</div>
                  <div v-if="p.dni" class="hd__buscar-dni">DNI {{ p.dni }}</div>
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Paso 2: modal dispensación (mismo que en SocioDetail) -->
    <ModalNuevaDispensacion
      v-if="pacienteSeleccionado"
      v-model="showDispensarModal"
      :socio-id="pacienteSeleccionado.id"
      :paciente-nombre="`${pacienteSeleccionado.apellido}, ${pacienteSeleccionado.nombre}`"
      :saldo-cc="pacienteSeleccionado.saldo_cc ?? null"
      :limite-cc="pacienteSeleccionado.limite_cc ?? null"
      :saldo-cc-g="pacienteSeleccionado.saldo_cc_g ?? null"
      :limite-cc-g="pacienteSeleccionado.limite_cc_g ?? null"
      :cc-gramos-activo="pacienteSeleccionado.cc_gramos_activo ?? false"
      :descuento-porcentaje="Number(pacienteSeleccionado.descuento_porcentaje ?? 0)"
      @saved="onDispensacionGuardada"
    />

    <!-- Filtros -->
    <div class="hd__filters">
      <!-- Fila 1: fechas -->
      <div class="hd__filters-row">
        <div class="hd__quick">
          <button class="hd__quick-btn" @click="setRango(1)">Hoy</button>
          <button class="hd__quick-btn" @click="setRango(7)">7d</button>
          <button class="hd__quick-btn" @click="setRango(30)">30d</button>
          <button class="hd__quick-btn" @click="setRango(90)">3m</button>
        </div>
        <div class="hd__dates">
          <div class="hd__date-group">
            <label class="hd__date-label">Desde</label>
            <input v-model="desde" type="date" class="hd__date-input" :max="hasta || hoy" />
          </div>
          <span class="hd__date-sep">→</span>
          <div class="hd__date-group">
            <label class="hd__date-label">Hasta</label>
            <input v-model="hasta" type="date" class="hd__date-input" :max="hoy" :min="desde" />
          </div>
        </div>
      </div>
      <!-- Fila 2: filtros adicionales -->
      <div class="hd__filters-row hd__filters-row--secondary">
        <select v-if="sedes.length > 1" v-model="filtroSede" class="hd__select">
          <option value="">Todas las sedes</option>
          <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <select v-model="filtroMedioPago" class="hd__select">
          <option value="">Todos los medios de pago</option>
          <option v-for="m in MEDIOS_PAGO" :key="m.value" :value="m.value">{{ m.label }}</option>
        </select>
        <select v-model="filtroForma" class="hd__select">
          <option value="">Todas las formas</option>
          <option v-for="f in FORMAS" :key="f.value" :value="f.value">{{ f.label }}</option>
        </select>
        <!-- Filtro por socio -->
        <button v-if="!filtroSocio" class="hd__btn-socio" @click="abrirFiltrarSocio">
          <Filter :size="13" :stroke-width="2" />
          Filtrar por socio
        </button>
        <span v-else class="hd__socio-chip">
          {{ filtroSocio.nombre }}
          <button class="hd__socio-chip-x" @click="filtroSocio = null" title="Quitar filtro">
            <X :size="12" :stroke-width="2.5" />
          </button>
        </span>
        <!-- Limpiar todos -->
        <button v-if="hayFiltrosActivos" class="hd__btn-limpiar" @click="limpiarFiltros">
          <X :size="12" :stroke-width="2.5" /> Limpiar filtros
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="hd__skel-list">
      <div class="hd__skel" v-for="n in 6" :key="n" />
    </div>

    <template v-else-if="allDisps.length">

      <!-- KPIs -->
      <div class="hd__kpis">
        <div class="hd__kpi">
          <span class="hd__kpi-val">{{ allDisps.length }}</span>
          <span class="hd__kpi-lbl">Dispensaciones</span>
        </div>
        <div class="hd__kpi">
          <span class="hd__kpi-val">{{ totalGramos.toFixed(1) }}<span class="hd__kpi-unit">g</span></span>
          <span class="hd__kpi-lbl">Total gramos</span>
        </div>
        <div class="hd__kpi hd__kpi--green">
          <span class="hd__kpi-val">{{ formatARS(totalRecaudado) }}</span>
          <span class="hd__kpi-lbl">Total recaudado</span>
        </div>
        <div v-if="totalConEnvio" class="hd__kpi hd__kpi--blue">
          <span class="hd__kpi-val">{{ totalConEnvio }}</span>
          <span class="hd__kpi-lbl">Con envío</span>
        </div>
      </div>

      <!-- Resumen por medio de pago -->
      <div class="hd__pago-strip">
        <span
          v-for="r in resumenPago"
          :key="r.medio"
          class="hd__pago-chip"
        >
          {{ medioPagoLabel(r.medio) }}: <strong>{{ r.count }}</strong>
          <span class="hd__pago-monto">({{ formatARS(r.total) }})</span>
        </span>
      </div>

      <!-- Tabla -->
      <div v-if="!dispensaciones.length" class="hd__empty">
        Sin resultados para los filtros aplicados.
      </div>
      <div v-else class="hd__table-wrap">
        <table class="hd__table">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Paciente</th>
              <th>Producto</th>
              <th class="hd__th-num">Cant.</th>
              <th class="hd__th-num">P. unit.</th>
              <th class="hd__th-num">Desc</th>
              <th class="hd__th-num">Total</th>
              <th>Pago</th>
              <th>Dispensador</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in dispensaciones" :key="d.id" class="hd__tr">
              <td class="hd__td-fecha">
                <span class="hd__fecha-day">{{ formatFecha(d.fecha_dispensacion, false) }}</span>
                <span class="hd__fecha-hora">{{ formatHora(d.created_at) }}</span>
              </td>
              <td class="hd__td-paciente">
                <RouterLink :to="{ name: 'paciente-detail', params: { id: d.paciente_id } }" class="hd__link-paciente">{{ d.paciente_nombre }}</RouterLink>
                <button class="hd__btn-filter-socio" @click="filtrarPorSocio(d)" title="Ver solo este socio">
                  <Filter :size="11" :stroke-width="2" />
                </button>
              </td>
              <td class="hd__td-producto">
                <span class="hd__forma-chip">{{ formaLabel(d.stock?.forma_producto) }}</span>
              </td>
              <td class="hd__td-num hd__td-qty">{{ d.cantidad }}{{ d.stock?.unidad ?? 'g' }}</td>
              <td class="hd__td-num hd__td-price">
                <span v-if="d.precio_unitario_ars">{{ formatARS(d.precio_unitario_ars) }}</span>
                <span v-else class="hd__dash">—</span>
              </td>
              <td class="hd__td-num">
                <span v-if="descuentoPct(d)" class="hd__desc-badge">-{{ descuentoPct(d) }}%</span>
                <span v-else class="hd__dash">—</span>
              </td>
              <td class="hd__td-num hd__td-monto">{{ formatARS(d.aporte_socio_ars) }}</td>
              <td class="hd__td-pago">
                <span class="hd__pago-badge" :class="medioPagoClass(d.medio_pago)">{{ medioPagoLabel(d.medio_pago) }}</span>
              </td>
              <td class="hd__td-user">{{ d.usuario?.nombre ?? '—' }}</td>
              <td class="hd__td-envio">
                <span v-if="d.con_envio" class="hd__envio-badge" :title="d.estado_envio">
                  <Truck :size="12" :stroke-width="2" />
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="hd__summary">
          <span class="hd__summary-count">{{ dispensaciones.length }} dispensaciones</span>
          <span class="hd__summary-total">
            {{ totalGramos.toFixed(1) }}g · <strong>{{ formatARS(totalRecaudado) }}</strong>
          </span>
        </div>
      </div>

    </template>

    <!-- Empty total -->
    <div v-else class="hd__empty-full">
      Sin dispensaciones en el período seleccionado.
    </div>

  </div>
</template>

<style scoped>
.hd {
  padding: var(--sp-6) var(--sp-8);
  max-width: 1200px;
}
@media (max-width: 767px) { .hd { padding: var(--sp-4); } }

/* Header */
.hd__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-5);
  flex-wrap: wrap;
}
.hd__title {
  font-size: var(--fs-20);
  font-weight: 700;
  color: var(--c-ink-900);
  margin: 0 0 2px;
}
.hd__sub { font-size: var(--fs-13); color: var(--c-ink-400); margin: 0; }
.hd__top-actions { display: flex; align-items: center; gap: var(--sp-2); }
.hd__btn-refresh {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .45rem .6rem;
  color: var(--c-ink-500);
  cursor: pointer;
  display: flex;
  align-items: center;
  transition: border-color .15s;
}
.hd__btn-refresh:hover:not(:disabled) { border-color: var(--c-ink-400); color: var(--c-ink-700); }
.hd__btn-refresh:disabled { opacity: .5; cursor: not-allowed; }
.hd__spin { animation: hd-spin .7s linear infinite; }
@keyframes hd-spin { to { transform: rotate(360deg); } }
.hd__btn-export {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: .5rem .9rem;
  background: #1b5e20;
  color: #fff;
  border: none;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  transition: background .15s;
}
.hd__btn-export:hover:not(:disabled) { background: #145218; }
.hd__btn-export:disabled { opacity: .55; cursor: default; }

.hd__btn-nueva {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .45rem .9rem; border-radius: 8px;
  font-size: var(--fs-13); font-weight: 600; cursor: pointer;
  transition: background .15s;
}
.hd__btn-nueva:hover { background: #145218; }

/* Modal buscar paciente */
.hd__modal-overlay {
  position: fixed; inset: 0; z-index: 200;
  background: rgba(0,0,0,.55);
  display: flex; align-items: center; justify-content: center;
  padding: 1.5rem;
}
.hd__modal-box {
  background: #fff; width: 100%; max-width: 540px;
  display: flex; flex-direction: column;
  box-shadow: 0 24px 80px rgba(0,0,0,.25);
  border-radius: 16px; max-height: 80vh;
}
.hd__modal-box--narrow { max-width: 460px; }
.hd__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.25rem; border-bottom: 1px solid #e8f0e9; flex-shrink: 0;
}
.hd__modal-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.hd__modal-close {
  background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px;
  cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b;
}
.hd__modal-close:hover { background: #e2e8f0; }
.hd__modal-body { flex: 1; overflow-y: auto; }
.hd__buscar-body { display: flex; flex-direction: column; gap: 0; }
.hd__buscar-search-wrap {
  display: flex; align-items: center; gap: .5rem;
  padding: .75rem 1.25rem; border-bottom: 1px solid #f1f5f9; flex-shrink: 0;
}
.hd__buscar-search {
  flex: 1; background: none; border: none; font-size: .9rem;
  color: var(--c-ink-900); outline: none;
}
.hd__buscar-loading { display: flex; align-items: center; justify-content: center; padding: 2rem; }
.hd__buscar-empty { text-align: center; padding: 2rem 1.25rem; color: #94a3b8; font-size: .875rem; }
.hd__buscar-lista { display: flex; flex-direction: column; overflow-y: auto; }
.hd__buscar-item {
  width: 100%; display: flex; flex-direction: column; gap: .15rem;
  padding: .75rem 1.25rem; border: none; background: none;
  text-align: left; cursor: pointer; border-bottom: 1px solid #f8fafc;
  transition: background .1s;
}
.hd__buscar-item:hover { background: #f0fdf4; }
.hd__buscar-item:last-child { border-bottom: none; }
.hd__buscar-nombre { font-size: .875rem; font-weight: 600; color: #0f172a; }
.hd__buscar-dni { font-size: .75rem; color: #94a3b8; font-family: monospace; }

.hd-modal-enter-active, .hd-modal-leave-active { transition: opacity .2s; }
.hd-modal-enter-from, .hd-modal-leave-to { opacity: 0; }

/* Filtros de fecha */
.hd__quick { display: flex; gap: var(--sp-1); }
.hd__quick-btn {
  background: none; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md);
  padding: .3rem .65rem; font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-600);
  cursor: pointer; transition: border-color .15s, background .15s;
}
.hd__quick-btn:hover { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.hd__dates { display: flex; align-items: center; gap: var(--sp-2); }
.hd__date-group { display: flex; flex-direction: column; gap: 2px; }
.hd__date-label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-ink-400); }
.hd__date-input {
  padding: .38rem var(--sp-3); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-13); color: var(--c-ink-900); background: var(--c-paper); cursor: pointer;
}
.hd__date-input:focus { outline: none; border-color: #1b5e20; }
.hd__date-sep { color: var(--c-ink-300); font-size: var(--fs-14); }

/* KPIs */
.hd__kpis {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
.hd__kpi {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  padding: var(--sp-3) var(--sp-4);
  display: flex;
  flex-direction: column;
  gap: 3px;
  min-width: 140px;
}
.hd__kpi--green { border-color: #bbf7d0; background: #f0fdf4; }
.hd__kpi--blue  { border-color: #bfdbfe; background: #eff6ff; }
.hd__kpi-val {
  font-size: var(--fs-22);
  font-weight: 800;
  color: var(--c-ink-900);
  line-height: 1;
}
.hd__kpi--green .hd__kpi-val { color: #15803d; }
.hd__kpi--blue  .hd__kpi-val { color: #1d4ed8; }
.hd__kpi-unit { font-size: var(--fs-14); font-weight: 600; }
.hd__kpi-lbl { font-size: 11px; font-weight: 600; color: var(--c-ink-500); text-transform: uppercase; letter-spacing: .05em; }

/* Pago strip */
.hd__pago-strip {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-2);
  margin-bottom: var(--sp-4);
}
.hd__pago-chip {
  background: var(--c-ink-50, #f8fafc);
  border: 1px solid var(--c-ink-200);
  border-radius: 999px;
  padding: .2em .75em;
  font-size: var(--fs-12);
  color: var(--c-ink-600);
}
.hd__pago-monto { color: var(--c-ink-400); margin-left: .2em; }

/* Tabla */
.hd__table-wrap {
  overflow-x: auto;
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-xl);
  background: #fff;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
}
.hd__table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-13);
}
.hd__table th {
  text-align: left;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--c-ink-400);
  padding: var(--sp-3) var(--sp-4);
  background: var(--c-ink-50, #f8fafc);
  border-bottom: 1.5px solid var(--c-ink-100);
  white-space: nowrap;
}
.hd__table th:first-child { border-radius: var(--r-lg) 0 0 0; }
.hd__table th:last-child  { border-radius: 0 var(--r-lg) 0 0; }
.hd__tr td {
  padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-50, #f8fafc);
  color: var(--c-ink-800);
  vertical-align: middle;
}
.hd__tr:last-child td { border-bottom: none; }
.hd__tr:hover td { background: #f8fdf8; }
.hd__th-num, .hd__td-num { text-align: right; }
.hd__td-fecha { white-space: nowrap; }
.hd__fecha-day { display: block; font-weight: 600; font-size: var(--fs-13); color: var(--c-ink-900); }
.hd__fecha-hora { display: block; font-size: 11px; color: var(--c-ink-400); font-family: var(--font-mono, monospace); margin-top: 1px; }
.hd__td-paciente { font-weight: 500; }
.hd__link-paciente { color: var(--c-ink-800); text-decoration: none; font-weight: 600; }
.hd__link-paciente:hover { color: #1b5e20; }
.hd__forma-chip {
  display: inline-block;
  background: #f0fdf4;
  color: #166534;
  border: 1px solid #bbf7d0;
  border-radius: var(--r-pill);
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 600;
  white-space: nowrap;
}
.hd__td-qty { font-family: var(--font-mono, monospace); font-weight: 600; color: var(--c-ink-700); }
.hd__td-price { font-family: var(--font-mono, monospace); color: var(--c-ink-500); }
.hd__td-monto { font-weight: 700; color: #15803d; font-family: var(--font-mono, monospace); font-size: var(--fs-14); }
.hd__dash { color: var(--c-ink-300); }
.hd__desc-badge {
  display: inline-block;
  background: #fff7ed;
  color: #c2410c;
  border: 1px solid #fed7aa;
  border-radius: var(--r-pill);
  padding: 2px 7px;
  font-size: 11px;
  font-weight: 700;
}
/* Badges de medio de pago */
.hd__pago-badge {
  display: inline-block;
  border-radius: var(--r-pill);
  padding: 2px 8px;
  font-size: 11px;
  font-weight: 600;
  white-space: nowrap;
}
.hd__pago--verde   { background: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; }
.hd__pago--azul    { background: #dbeafe; color: #1d4ed8; border: 1px solid #bfdbfe; }
.hd__pago--morado  { background: #ede9fe; color: #6d28d9; border: 1px solid #ddd6fe; }
.hd__pago--amber   { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }
.hd__pago--teal    { background: #ccfbf1; color: #0f766e; border: 1px solid #99f6e4; }
.hd__pago--gris    { background: var(--c-ink-100); color: var(--c-ink-600); border: 1px solid var(--c-ink-200); }
.hd__td-user { font-size: var(--fs-12); color: var(--c-ink-400); }
.hd__td-envio { width: 36px; }
.hd__envio-badge {
  display: inline-flex;
  align-items: center;
  background: #dbeafe;
  color: #1d4ed8;
  padding: 2px 6px;
  border-radius: var(--r-pill);
  font-size: 11px;
  gap: 3px;
}

/* Summary row */
.hd__summary {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--sp-3) var(--sp-4);
  background: var(--c-ink-50, #f8fafc);
  border-top: 1.5px solid var(--c-ink-100);
  font-size: var(--fs-13);
  color: var(--c-ink-600);
}
.hd__summary-count { }
.hd__summary-total { }

/* Empty / loading */
.hd__empty { color: var(--c-ink-500); font-size: var(--fs-14); padding: var(--sp-4) 0; }
.hd__empty-full { color: var(--c-ink-400); font-size: var(--fs-14); padding: var(--sp-10) 0; text-align: center; }
.hd__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); margin-bottom: var(--sp-4); }
.hd__skel { height: 44px; background: var(--c-ink-100); border-radius: var(--r-md); animation: hd-pulse 1.4s ease-in-out infinite; }
@keyframes hd-pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

/* Filtros — layout */
.hd__filters { display: flex; flex-direction: column; gap: var(--sp-2); margin-bottom: var(--sp-5); padding: var(--sp-3) var(--sp-4); background: var(--c-paper); border: 1.5px solid var(--c-ink-100); border-radius: var(--r-lg); }
.hd__filters-row { display: flex; align-items: center; flex-wrap: wrap; gap: var(--sp-2); }
.hd__filters-row--secondary { padding-top: var(--sp-2); border-top: 1px solid var(--c-ink-100); }

/* Selects */
.hd__select {
  padding: .38rem var(--sp-3); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-13); color: var(--c-ink-900); background: var(--c-paper); cursor: pointer;
}
.hd__select:focus { outline: none; border-color: #1b5e20; }

/* Botón filtrar por socio */
.hd__btn-socio {
  display: inline-flex; align-items: center; gap: .3rem;
  background: none; border: 1.5px dashed var(--c-ink-300); border-radius: var(--r-md);
  padding: .38rem .75rem; font-size: var(--fs-13); color: var(--c-ink-500);
  cursor: pointer; transition: border-color .15s, color .15s;
}
.hd__btn-socio:hover { border-color: #1b5e20; color: #1b5e20; }

/* Chip de socio activo */
.hd__socio-chip {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #f0fdf4; border: 1.5px solid #86efac; border-radius: 999px;
  padding: .25rem .65rem; font-size: var(--fs-13); font-weight: 600; color: #15803d;
}
.hd__socio-chip-x {
  background: none; border: none; padding: 0; cursor: pointer;
  color: #15803d; display: flex; align-items: center; opacity: .7;
}
.hd__socio-chip-x:hover { opacity: 1; }

/* Botón limpiar */
.hd__btn-limpiar {
  display: inline-flex; align-items: center; gap: .3rem; margin-left: auto;
  background: none; border: none; font-size: var(--fs-12); color: var(--c-ink-400);
  cursor: pointer; padding: .25rem .5rem; border-radius: var(--r-sm);
  transition: color .15s;
}
.hd__btn-limpiar:hover { color: #dc2626; }

/* Botón filtrar por socio inline en tabla */
.hd__btn-filter-socio {
  display: inline-flex; align-items: center; background: none; border: none;
  color: var(--c-ink-300); cursor: pointer; padding: 0 .25rem; vertical-align: middle;
  opacity: 0; transition: opacity .15s, color .15s;
}
.hd__table tr:hover .hd__btn-filter-socio { opacity: 1; }
.hd__btn-filter-socio:hover { color: #1b5e20; }
</style>
