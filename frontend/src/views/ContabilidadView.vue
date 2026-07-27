<script setup>
import { ref, computed, onMounted, nextTick, watch } from "vue"
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { useContabilidadStore } from "../stores/contabilidad"
import { useAuthStore }         from "../stores/auth"
import { listSedes, listLotes, listPacientes, cerrarPeriodoContable, reabrirPeriodoContable, createCompraCuotas, listComprasCuotas, listUnidadesNegocio, listInsumos, listBares, listCategoriasContables, listDepositos } from "../lib/api"
import { useConfirm }           from "../composables/useConfirm.js"
import { useToast }             from "../composables/useToast.js"
import ModalNuevoMovimiento from "../components/contabilidad/ModalNuevoMovimiento.vue"
import EditarCompraCuotasModal from "../components/contabilidad/EditarCompraCuotasModal.vue"
import DsSpinner from '../design-system/components/Spinner.vue'
// Categorías integradas como sección de Contabilidad (config del hub contable)
import FinanzasCatalogoView from './admin/FinanzasCatalogoView.vue'

const store   = useContabilidadStore()
const auth    = useAuthStore()
const sedes   = ref([])
const unidades = ref([])
const insumos  = ref([])
const bares    = ref([])
const categorias = ref([])
const depositos  = ref([])
// Solo admin: el backend rechaza escritura de cualquier otro rol (abogado incluido)
const canEdit = computed(() => ["admin","super_admin"].includes(auth.role))

// Los movimientos generados por dispensaciones no se editan ni borran a mano:
// se corrigen desde la dispensación para que libro, stock y CC queden consistentes
const esAutomatico = (m) => !!m.dispensacion_id
// Movimientos de períodos cerrados: inmutables (corrección = contra-asiento)
const esCerrado    = (m) => !!m.cerrado

// ── Cierre de período ──────────────────────────────────────────
const cerrandoPeriodo = ref(false)
const cierreActual    = computed(() => store.dashboard?.contabilidad_cerrada_hasta || null)
const finMesAnterior  = computed(() => {
  const d = new Date()
  return new Date(d.getFullYear(), d.getMonth(), 0)  // último día del mes pasado
})
const puedeCerrarMesAnterior = computed(() => {
  if (!cierreActual.value) return true
  return new Date(cierreActual.value) < finMesAnterior.value
})

function fmtFechaCorta(d) {
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' })
}

async function cerrarMesAnterior() {
  const hasta = finMesAnterior.value.toISOString().slice(0, 10)
  const ok = await confirm({
    title:       'Cerrar período contable',
    message:     `Se congela el libro hasta el ${fmtFechaCorta(hasta)} inclusive: ningún movimiento anterior a esa fecha se podrá crear, editar ni eliminar. Las correcciones futuras serán por contra-asiento o reapertura.`,
    confirmText: 'Cerrar período',
    variant:     'danger',
  })
  if (!ok) return
  cerrandoPeriodo.value = true
  try {
    await cerrarPeriodoContable(hasta)
    toast.success(`Período cerrado hasta el ${fmtFechaCorta(hasta)}`)
    await store.fetchDashboard(dashboardSede.value)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo cerrar el período')
  } finally {
    cerrandoPeriodo.value = false
  }
}

async function reabrirPeriodo() {
  const ok = await confirm({
    title:       'Reabrir período contable',
    message:     'Se levanta el cierre: los movimientos vuelven a ser editables. La reapertura queda registrada en la auditoría con tu usuario.',
    confirmText: 'Reabrir',
    variant:     'danger',
  })
  if (!ok) return
  try {
    await reabrirPeriodoContable(null)
    toast.success('Período reabierto')
    await store.fetchDashboard(dashboardSede.value)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo reabrir')
  }
}
const { confirm } = useConfirm()
const toast = useToast()

const vistaActiva    = ref("dashboard")
const dashboardSede  = ref(null) // filtro de sede LOCAL del dashboard (null = todo el club)
const unidadAbierta  = ref(new Set()) // áreas expandidas para ver su desglose por sede
function toggleUnidad(id) {
  const k = id ?? 'sin'
  const s = new Set(unidadAbierta.value)
  s.has(k) ? s.delete(k) : s.add(k)
  unidadAbierta.value = s
}
const todosLotes     = ref([])
const loadingLotes   = ref(false)
const pacientes      = ref([])
const generandoPDF   = ref(false)
const plContainerRef = ref(null)

const plSubTab = ref('lotes') // 'lotes' | 'cepas'

const lotesConCosto = computed(() =>
  todosLotes.value
    .filter(l => l.tiene_costo)
    .sort((a, b) => (a.costo_por_gramo || Infinity) - (b.costo_por_gramo || Infinity))
)

const plPorCepa = computed(() => {
  const map = {}
  for (const l of todosLotes.value) {
    if (!l.tiene_costo || !l.costo_por_gramo) continue
    const key   = l.genetica_id || 'sin_cepa'
    const label = l.genetica?.nombre || l.strain || 'Sin genética'
    if (!map[key]) map[key] = { genetica_id: key, nombre: label, lotes: [] }
    map[key].lotes.push(l)
  }
  return Object.values(map).map(g => {
    const cpgs = g.lotes.map(l => l.costo_por_gramo).filter(Boolean)
    const totalGramos = g.lotes.reduce((s, l) => s + (l.gramos_producidos || 0), 0)
    const totalCosto  = g.lotes.reduce((s, l) => s + (l.costo_total || 0), 0)
    return {
      ...g,
      n_lotes:      g.lotes.length,
      cpg_promedio: cpgs.length ? cpgs.reduce((a, b) => a + b, 0) / cpgs.length : null,
      cpg_min:      cpgs.length ? Math.min(...cpgs) : null,
      cpg_max:      cpgs.length ? Math.max(...cpgs) : null,
      total_gramos: totalGramos,
      total_costo:  totalCosto,
    }
  }).sort((a, b) => (a.cpg_promedio || Infinity) - (b.cpg_promedio || Infinity))
})

async function irAPL() {
  vistaActiva.value = 'pl'
  if (!todosLotes.value.length) {
    loadingLotes.value = true
    try { const { data } = await listLotes(); todosLotes.value = data || [] }
    finally { loadingLotes.value = false }
  }
}

async function exportarPDF() {
  generandoPDF.value = true
  await nextTick()
  const el = plContainerRef.value
  if (!el) { generandoPDF.value = false; return }
  const subTab = plSubTab.value === 'lotes' ? 'por-lote' : 'por-cepa'
  const fecha  = new Date().toISOString().slice(0, 10)
  const opt = {
    margin:      [12, 10, 12, 10],
    filename:    `PL_produccion_${subTab}_${fecha}.pdf`,
    image:       { type: 'jpeg', quality: 0.95 },
    html2canvas: { scale: 2, useCORS: true },
    jsPDF:       { unit: 'mm', format: 'a4', orientation: 'landscape' },
    pagebreak:   { mode: ['avoid-all', 'css', 'legacy'] },
  }
  try {
    const { default: html2pdf } = await import('html2pdf.js')
    await html2pdf().set(opt).from(el).save()
  } finally {
    generandoPDF.value = false
  }
}

async function cambiarSedeDashboard(sede_id) {
  dashboardSede.value = sede_id || null
  await store.fetchDashboard(sede_id || null)
}

const fmt = (n) => new Intl.NumberFormat("es-AR", {
  style: "currency", currency: "ARS",
  minimumFractionDigits: 0, maximumFractionDigits: 0
}).format(n || 0)

function balanceColor(n) { return n >= 0 ? "#15803d" : "#dc2626" }
function balanceBg(n)    { return n >= 0 ? "rgba(21,128,61,.08)" : "rgba(220,38,38,.08)" }

function tipoMeta(tipo) {
  return {
    egreso:         { label: "Egreso",   color: "#dc2626", bg: "rgba(220,38,38,.1)"   },
    ingreso:        { label: "Ingreso",  color: "#15803d", bg: "rgba(21,128,61,.1)"   },
    recupero_costo: { label: "Recupero", color: "#0369a1", bg: "rgba(3,105,161,.1)"   },
    ajuste:         { label: "Ajuste",   color: "#64748b", bg: "rgba(100,116,139,.1)" },
  }[tipo] || { label: tipo, color: "#64748b", bg: "rgba(100,116,139,.1)" }
}

function sedeTipoIcon(tipo) {
  return tipo === 'social' ? 'bi-shop' : tipo === 'mixta' ? 'bi-arrow-left-right' : 'bi-flower2'
}
function sedeTipoColor(tipo) {
  return tipo === 'social' ? '#0369a1' : tipo === 'mixta' ? '#7c3aed' : '#15803d'
}
function sedeTipoBg(tipo) {
  return tipo === 'social' ? 'rgba(3,105,161,.1)' : tipo === 'mixta' ? 'rgba(124,58,237,.1)' : 'rgba(21,128,61,.1)'
}
function sedeTipoLabel(tipo) {
  return { produccion: 'Producción', social: 'Dispensario', mixta: 'Mixta' }[tipo] || '—'
}

const MESES_ES = ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
const MESES_EN = { january:"Enero", february:"Febrero", march:"Marzo", april:"Abril", may:"Mayo", june:"Junio", july:"Julio", august:"Agosto", september:"Septiembre", october:"Octubre", november:"Noviembre", december:"Diciembre" }
function mesLabel(m) {
  if (!m) return "—"
  const num = parseInt(m)
  if (!isNaN(num) && num >= 1 && num <= 12) return MESES_ES[num - 1]
  if (/^\d{4}-\d{2}$/.test(String(m))) return MESES_ES[parseInt(m.split("-")[1]) - 1] || m
  const en = MESES_EN[String(m).toLowerCase()]
  if (en) return en
  return m
}

const CATEGORIAS = [
  { value: "insumo",        label: "Insumo / Materia prima",   tipo: "egreso"  },
  { value: "electricidad",  label: "Electricidad",             tipo: "egreso"  },
  { value: "agua",          label: "Agua",                     tipo: "egreso"  },
  { value: "alquiler",      label: "Alquiler",                 tipo: "egreso"  },
  { value: "sueldo",        label: "Sueldo / Staff",           tipo: "egreso"  },
  { value: "mantenimiento", label: "Mantenimiento",            tipo: "egreso"  },
  { value: "honorario",     label: "Honorario profesional",    tipo: "egreso"  },
  { value: "seguro",        label: "Seguro",                   tipo: "egreso"  },
  { value: "admin",         label: "Gasto administrativo",     tipo: "egreso"  },
  { value: "aporte_socio",  label: "Aporte socio",             tipo: "ingreso" },
  { value: "dispensacion",  label: "Recupero dispensación",    tipo: "ingreso" },
  { value: "subvencion",    label: "Subvención / Donación",    tipo: "ingreso" },
  { value: "bar",           label: "Bar / Salón",              tipo: "ambos"   },
  { value: "otro",          label: "Otro",                     tipo: "ambos"   },
]
function catLabel(cat) { return CATEGORIAS.find(c => c.value === cat)?.label || cat || "—" }

// Detalle de un movimiento (modal informativo): qué, quién, cuándo, dónde, y link al bar si aplica.
const detalleMov = ref(null)
function abrirDetalle(m) { detalleMov.value = m }
// (estilos del modal: ver bloque cv__dlg en <style>)

const ESTADO_COLORS = {
  germinacion:       { color: '#7c3aed', bg: 'rgba(124,58,237,.1)'  },
  vegetativo:        { color: '#15803d', bg: 'rgba(21,128,61,.1)'   },
  floracion:         { color: '#d97706', bg: 'rgba(217,119,6,.1)'   },
  cosecha:           { color: '#0369a1', bg: 'rgba(3,105,161,.1)'   },
  curado:            { color: '#065f46', bg: 'rgba(6,95,70,.1)'     },
  finalizado:        { color: '#1e293b', bg: 'rgba(30,41,59,.1)'    },
}
function estadoStyle(estado) {
  const m = ESTADO_COLORS[estado] || { color: '#64748b', bg: 'rgba(100,116,139,.1)' }
  return { color: m.color, background: m.bg }
}

const busquedaDash = ref("")
const ultimosFiltrados = computed(() => {
  const list = store.dashboard?.ultimos_movimientos || []
  const q = busquedaDash.value.trim().toLowerCase()
  const filtered = q
    ? list.filter(m =>
      m.descripcion?.toLowerCase().includes(q) ||
      catLabel(m.categoria).toLowerCase().includes(q) ||
      m.tipo?.toLowerCase().includes(q)
    )
    : list
  return filtered.slice(0, 10)
})

const filtroQ         = ref("")
const filtroTipo      = ref("")
const filtroCategoria = ref("")
const filtroSede      = ref("")
const filtroDesde     = ref("")
const filtroHasta     = ref("")

const itemsFiltrados = computed(() => {
  const q = filtroQ.value.trim().toLowerCase()
  return (store.items || []).filter(m => {
    if (q && !m.descripcion?.toLowerCase().includes(q) &&
      !catLabel(m.categoria).toLowerCase().includes(q) &&
      !m.proveedor?.toLowerCase().includes(q)) return false
    return true
  })
})

async function aplicarFiltros() {
  store.setFiltro("tipo",      filtroTipo.value)
  store.setFiltro("categoria", filtroCategoria.value)
  store.setFiltro("sede_id",   filtroSede.value)
  store.setFiltro("desde",     filtroDesde.value)
  store.setFiltro("hasta",     filtroHasta.value)
  await store.fetch()
}
function limpiarFiltros() {
  filtroQ.value = filtroTipo.value = filtroCategoria.value = filtroSede.value = ""
  filtroDesde.value = filtroHasta.value = ""
  store.resetFiltros()
  store.fetch()
}

const hayFiltros = computed(() =>
  filtroTipo.value || filtroCategoria.value || filtroSede.value || filtroDesde.value || filtroHasta.value
)

const showModal        = ref(false)
const editingMovimiento = ref(null)
const showEditarCuotas = ref(false)
const compraEditar     = ref(null)

async function onCompraCuotasEditada() {
  if (vistaActiva.value === 'dashboard') await store.fetchDashboard(dashboardSede.value)
  else await store.fetch()
}

async function openCreate() {
  editingMovimiento.value = null
  showModal.value = true
  if (!pacientes.value.length) {
    const { data } = await listPacientes({ per_page: 500 })
    const arr = Array.isArray(data) ? data : (Array.isArray(data.data) ? data.data : [])
    pacientes.value = arr.map(p => ({
      id: p.id,
      label: `${p.apellido}, ${p.nombre} — DNI ${p.dni || '—'}`,
    }))
  }
}

async function openEdit(m) {
  // Si es una cuota de una compra financiada, se edita la COMPRA entera (total + nº de cuotas
  // → regenera), no la cuota suelta.
  if (m.compra_cuotas_id) {
    try {
      const { data } = await listComprasCuotas()
      const compra = (data || []).find(c => c.id === m.compra_cuotas_id)
      if (!compra) { toast.error('No se encontró la compra en cuotas'); return }
      compraEditar.value = compra
      showEditarCuotas.value = true
    } catch {
      toast.error('No se pudo cargar la compra en cuotas')
    }
    return
  }
  editingMovimiento.value = m
  showModal.value = true
  if (!pacientes.value.length) {
    const { data } = await listPacientes({ per_page: 500 })
    const arr = Array.isArray(data) ? data : (Array.isArray(data.data) ? data.data : [])
    pacientes.value = arr.map(p => ({
      id: p.id,
      label: `${p.apellido}, ${p.nombre} — DNI ${p.dni || '—'}`,
    }))
  }
}

async function onMovimientoGuardado(payload) {
  try {
    if (payload.medio_pago === 'en_cuotas') {
      // Compra financiada: genera N egresos mensuales (una por cuota).
      await createCompraCuotas({
        sede_id:             payload.sede_id || sedes.value[0]?.id,
        descripcion:         payload.descripcion,
        categoria:           payload.categoria,
        monto_total_ars:     payload.monto_ars,
        cuotas_total:        payload.cuotas_total,
        fecha_primera_cuota: payload.fecha,
        responsable:         payload.responsable || null,
        proveedor:           payload.proveedor || null,
        notas:               payload.notas || null,
      })
      await store.fetch()
    } else if (editingMovimiento.value) {
      await store.update(editingMovimiento.value.id, payload)
    } else {
      await store.create(payload)
    }
    showModal.value = false
    if (vistaActiva.value === "dashboard") await store.fetchDashboard(dashboardSede.value)
  } catch { /* el store ya expone el error; no rompemos el flujo del modal */ }
}

async function confirmDelete(m) {
  const esCuota = !!m.compra_cuotas_id
  const ok = await confirm({
    title:   esCuota ? '¿Eliminar la compra en cuotas?' : '¿Eliminar movimiento?',
    message: esCuota
      ? `"${m.descripcion}" es una cuota de una compra financiada. Al eliminar se borran TODAS las cuotas de esa compra, no solo esta.`
      : `${m.descripcion} · ${fmt(m.monto_ars)} · ${m.fecha}`,
    confirmText: esCuota ? 'Eliminar la compra completa' : 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  try {
    await store.remove(m.id)
    toast.success(esCuota ? 'Compra en cuotas eliminada' : 'Movimiento eliminado')
  } catch {
    toast.error(store.removeError || 'No se pudo eliminar el movimiento')
  }
  // Refrescar totales/KPIs y listas: el borrado afecta ingresos, balance y por_cobrar
  if (vistaActiva.value === 'dashboard') await store.fetchDashboard(dashboardSede.value)
  else await store.fetch()
}

async function goToPage(p) {
  store.setFiltro("page", p); await store.fetch()
  window.scrollTo({ top: 0, behavior: "smooth" })
}

async function exportar() {
  const params = {}
  if (filtroDesde.value) params.desde = filtroDesde.value
  if (filtroHasta.value) params.hasta = filtroHasta.value
  if (dashboardSede.value && vistaActiva.value === "dashboard") params.sede_id = dashboardSede.value
  await store.exportCSV(params)
}

function irALibro() {
  vistaActiva.value = "libro"; store.fetch()
}

onMounted(async () => {
  await Promise.all([
    store.fetchDashboard(dashboardSede.value),
    store.fetch(),
    listSedes().then(r => { sedes.value = r.data || [] }),
    listUnidadesNegocio().then(r => { unidades.value = r.data || [] }).catch(() => {}),
    listInsumos({ activos: 'true' }).then(r => { insumos.value = r.data?.insumos || [] }).catch(() => {}),
    listBares().then(r => { bares.value = r.data || [] }).catch(() => {}),
    listCategoriasContables().then(r => { categorias.value = r.data || [] }).catch(() => {}),
    listDepositos().then(r => { depositos.value = r.data?.depositos || r.data || [] }).catch(() => {}),
  ])
})
</script>

<template>
  <div class="cv">

    <!-- Header -->
    <div class="cv__header">
      <div class="cv__header-left">
        <h1 class="cv__title">Contabilidad</h1>
        <p class="cv__sub">Libro diario · Ingresos · Egresos · Balance</p>
      </div>
      <div class="cv__header-right">
        <button class="cv__btn-ghost" @click="exportar">
          <i class="bi bi-download"></i> Exportar CSV
        </button>
        <button v-if="canEdit" class="cv__btn-primary" @click="openCreate">
          <i class="bi bi-plus-lg"></i> Nuevo movimiento
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="cv__tabs">
      <button class="cv__tab" :class="{ 'cv__tab--active': vistaActiva === 'dashboard' }" @click="vistaActiva = 'dashboard'">
        <i class="bi bi-grid-1x2"></i> Dashboard
      </button>
      <button class="cv__tab" :class="{ 'cv__tab--active': vistaActiva === 'libro' }" @click="irALibro">
        <i class="bi bi-journal-text"></i> Libro diario
      </button>
      <button class="cv__tab" :class="{ 'cv__tab--active': vistaActiva === 'pl' }" @click="irAPL">
        <i class="bi bi-bar-chart-line"></i> P&amp;L por lote
      </button>
      <button class="cv__tab" :class="{ 'cv__tab--active': vistaActiva === 'categorias' }" @click="vistaActiva = 'categorias'">
        <i class="bi bi-tags"></i> Categorías
      </button>
    </div>

    <!-- Categorías: configuración contable integrada al hub -->
    <div v-if="vistaActiva === 'categorias'" class="cv__embed"><FinanzasCatalogoView /></div>

    <!-- ══════════════ DASHBOARD ══════════════ -->
    <div v-if="vistaActiva === 'dashboard'">

      <div v-if="store.loadingDashboard" class="cv__loading">
        <DsSpinner />
      </div>

      <template v-else-if="store.dashboard">

        <!-- Selector de sede -->
        <div class="cv__sede-selector">
          <button
            class="cv__sede-btn"
            :class="{ 'cv__sede-btn--active': dashboardSede === null }"
            @click="cambiarSedeDashboard(null)"
          >
            <i class="bi bi-building"></i> Club completo
          </button>
          <button
            v-for="s in sedes"
            :key="s.id"
            class="cv__sede-btn"
            :class="{ 'cv__sede-btn--active': dashboardSede === s.id }"
            @click="cambiarSedeDashboard(s.id)"
          >
            <i class="bi" :class="sedeTipoIcon(s.tipo)"></i>
            {{ s.nombre }}
          </button>
        </div>

        <!-- Contexto de sede activa -->
        <div v-if="dashboardSede" class="cv__dash-context">
          <i class="bi bi-funnel-fill" style="color:#0369a1"></i>
          Mostrando datos de
          <strong>{{ sedes.find(s => s.id === dashboardSede)?.nombre }}</strong>
          <button class="cv__dash-context-clear" @click="cambiarSedeDashboard(null)">
            Ver todo el club <i class="bi bi-x"></i>
          </button>
        </div>

        <!-- Cierre de período -->
        <div v-if="canEdit" class="cv__cierre">
          <div class="cv__cierre-info">
            <i class="bi" :class="cierreActual ? 'bi-lock-fill' : 'bi-unlock'"></i>
            <span v-if="cierreActual">Libro cerrado hasta el <strong>{{ fmtFechaCorta(cierreActual) }}</strong> — los movimientos anteriores son inmutables.</span>
            <span v-else>Sin cierre de período: todos los movimientos son editables.</span>
          </div>
          <div class="cv__cierre-actions">
            <button v-if="puedeCerrarMesAnterior" class="cv__cierre-btn" :disabled="cerrandoPeriodo" @click="cerrarMesAnterior">
              <i class="bi bi-lock"></i> Cerrar hasta {{ fmtFechaCorta(finMesAnterior) }}
            </button>
            <button v-if="cierreActual" class="cv__cierre-btn cv__cierre-btn--ghost" @click="reabrirPeriodo">
              Reabrir
            </button>
          </div>
        </div>

        <!-- KPIs -->
        <div class="cv__kpis">
          <div class="cv__kpi">
            <div class="cv__kpi-label">Ingresos este mes</div>
            <div class="cv__kpi-val cv__kpi-val--green">{{ fmt(store.dashboard.mes_actual.ingresos) }}</div>
            <div class="cv__kpi-bar cv__kpi-bar--green"></div>
          </div>
          <div class="cv__kpi">
            <div class="cv__kpi-label">Egresos este mes</div>
            <div class="cv__kpi-val" :class="store.dashboard.mes_actual.egresos > 0 ? 'cv__kpi-val--red' : ''">{{ fmt(store.dashboard.mes_actual.egresos) }}</div>
            <div class="cv__kpi-bar" :class="store.dashboard.mes_actual.egresos > 0 ? 'cv__kpi-bar--red' : 'cv__kpi-bar--neutral'"></div>
          </div>
          <div class="cv__kpi">
            <div class="cv__kpi-label">Balance del mes</div>
            <div class="cv__kpi-val" :style="{ color: balanceColor(store.dashboard.mes_actual.balance) }">
              {{ fmt(store.dashboard.mes_actual.balance) }}
            </div>
            <div class="cv__kpi-bar" :style="{ background: balanceColor(store.dashboard.mes_actual.balance) }"></div>
          </div>
          <div v-if="store.dashboard.por_cobrar > 0" class="cv__kpi">
            <div class="cv__kpi-label">Por cobrar (deuda de socios)</div>
            <div class="cv__kpi-val cv__kpi-val--amber">{{ fmt(store.dashboard.por_cobrar) }}</div>
            <div class="cv__kpi-bar cv__kpi-bar--amber"></div>
          </div>
          <div class="cv__kpi cv__kpi--highlight">
            <div class="cv__kpi-label">Balance del año</div>
            <div class="cv__kpi-val" :style="{ color: balanceColor(store.dashboard.anio_actual.balance) }">
              {{ fmt(store.dashboard.anio_actual.balance) }}
            </div>
            <div class="cv__kpi-bar" :style="{ background: balanceColor(store.dashboard.anio_actual.balance) }"></div>
          </div>
        </div>

        <!-- Evolución + Por categoría -->
        <div class="cv__row2">
          <div class="cv__card cv__card--main">
            <div class="cv__card-header">
              <span class="cv__card-title">Evolución mensual {{ new Date().getFullYear() }}</span>
            </div>
            <div v-if="!store.dashboard.anio_actual.por_mes?.length" class="cv__empty-sm">
              Sin datos para el año
            </div>
            <div v-else class="cv__table-wrap">
              <table class="cv__table">
                <thead>
                <tr>
                  <th>Mes</th>
                  <th class="cv__th-right cv__th-green">Ingresos</th>
                  <th class="cv__th-right cv__th-red">Egresos</th>
                  <th class="cv__th-right">Balance</th>
                </tr>
                </thead>
                <tbody>
                <tr v-for="m in store.dashboard.anio_actual.por_mes" :key="m.mes">
                  <td class="cv__td-mes">{{ mesLabel(m.mes_label || m.mes) }}</td>
                  <td class="cv__td-right cv__td-green">{{ fmt(m.ingresos) }}</td>
                  <td class="cv__td-right" :class="m.egresos > 0 ? 'cv__td-red' : ''">{{ fmt(m.egresos) }}</td>
                  <td class="cv__td-right cv__td-bold" :style="{ color: balanceColor(m.balance) }">{{ fmt(m.balance) }}</td>
                </tr>
                </tbody>
                <tfoot>
                <tr>
                  <td class="cv__td-bold">Total año</td>
                  <td class="cv__td-right cv__td-green cv__td-bold">{{ fmt(store.dashboard.anio_actual.ingresos) }}</td>
                  <td class="cv__td-right cv__td-bold" :class="store.dashboard.anio_actual.egresos > 0 ? 'cv__td-red' : ''">{{ fmt(store.dashboard.anio_actual.egresos) }}</td>
                  <td class="cv__td-right cv__td-bold" :style="{ color: balanceColor(store.dashboard.anio_actual.balance) }">{{ fmt(store.dashboard.anio_actual.balance) }}</td>
                </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div class="cv__card">
            <div class="cv__card-header">
              <span class="cv__card-title">Por categoría (mes actual)</span>
            </div>
            <div v-if="!store.dashboard.mes_actual.por_categoria?.length" class="cv__empty-sm">
              Sin movimientos este mes
            </div>
            <div v-else class="cv__cat-list">
              <div v-for="c in store.dashboard.mes_actual.por_categoria" :key="c.categoria + c.tipo" class="cv__cat-item">
                <div class="cv__cat-left">
                  <span class="cv__tipo-pill" :style="{ background: tipoMeta(c.tipo).bg, color: tipoMeta(c.tipo).color }">
                    {{ tipoMeta(c.tipo).label }}
                  </span>
                  <span class="cv__cat-name">{{ catLabel(c.categoria) }}</span>
                </div>
                <span class="cv__cat-monto" :style="{ color: tipoMeta(c.tipo).color }">{{ fmt(c.total) }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Resultado por unidad de negocio (mes actual) -->
        <div v-if="store.dashboard?.por_unidad?.length" class="cv__card cv__card--mt">
          <div class="cv__card-header">
            <span class="cv__card-title">
              <i class="bi bi-diagram-3" style="margin-right:6px;color:#2f6b3d;font-size:.9rem"></i>
              Resultado por unidad de negocio — mes actual
            </span>
          </div>
          <div class="cv__unidad-list">
            <template v-for="u in store.dashboard.por_unidad" :key="u.id ?? 'sin-unidad'">
              <div
                class="cv__unidad-row"
                :class="{ 'cv__unidad-row--exp': !dashboardSede && u.sedes?.length > 1 }"
                @click="!dashboardSede && u.sedes?.length > 1 && toggleUnidad(u.id)"
              >
                <span class="cv__unidad-name">
                  <i
                    v-if="!dashboardSede && u.sedes?.length > 1"
                    class="bi cv__unidad-caret"
                    :class="unidadAbierta.has(u.id ?? 'sin') ? 'bi-caret-down-fill' : 'bi-caret-right-fill'"
                  ></i>
                  {{ u.nombre }}
                  <span v-if="!dashboardSede && u.sedes?.length > 1" class="cv__unidad-sedes-badge">{{ u.sedes.length }} sedes</span>
                </span>
                <span class="cv__unidad-nums">
                  <span class="cv__unidad-in">+{{ fmt(u.ingresos) }}</span>
                  <span class="cv__unidad-out">−{{ fmt(u.egresos) }}</span>
                  <strong class="cv__unidad-bal" :class="u.balance >= 0 ? 'is-pos' : 'is-neg'">{{ fmt(u.balance) }}</strong>
                </span>
              </div>
              <div v-if="!dashboardSede && u.sedes?.length > 1 && unidadAbierta.has(u.id ?? 'sin')" class="cv__unidad-sedes">
                <div v-for="s in u.sedes" :key="s.id ?? 'sin-sede'" class="cv__unidad-subrow">
                  <span class="cv__unidad-subname"><i class="bi bi-geo-alt-fill"></i> {{ s.nombre }}</span>
                  <span class="cv__unidad-nums">
                    <span class="cv__unidad-in">+{{ fmt(s.ingresos) }}</span>
                    <span class="cv__unidad-out">−{{ fmt(s.egresos) }}</span>
                    <strong class="cv__unidad-bal" :class="s.balance >= 0 ? 'is-pos' : 'is-neg'">{{ fmt(s.balance) }}</strong>
                  </span>
                </div>
              </div>
            </template>
          </div>
        </div>

        <!-- Balance por sede (solo vista consolidada del club) -->
        <div v-if="!dashboardSede && store.dashboard?.por_sede?.length" class="cv__card cv__card--mt">
          <div class="cv__card-header">
            <span class="cv__card-title">
              <i class="bi bi-building" style="margin-right:6px;color:#0369a1;font-size:.9rem"></i>
              Balance por sede — mes actual
            </span>
            <span class="cv__card-sub">
              {{ new Date().toLocaleDateString('es-AR', { month: 'long', year: 'numeric' }) }}
            </span>
          </div>
          <div class="cv__sede-breakdown">
            <div
              v-for="sede in store.dashboard.por_sede"
              :key="sede.id ?? 'sin-sede'"
              class="cv__sede-card"
              :class="{ 'cv__sede-card--clickable': sede.id }"
              @click="sede.id && cambiarSedeDashboard(sede.id)"
            >
              <div class="cv__sede-card-header">
                <div
                  class="cv__sede-card-icon"
                  :style="{
                    background: sede.id ? sedeTipoBg(sede.tipo) : 'rgba(100,116,139,.1)',
                    color:      sede.id ? sedeTipoColor(sede.tipo) : '#64748b',
                  }"
                >
                  <i class="bi" :class="sede.id ? sedeTipoIcon(sede.tipo) : 'bi-dash-circle'"></i>
                </div>
                <div class="cv__sede-card-info">
                  <div class="cv__sede-card-nombre">{{ sede.nombre }}</div>
                  <div v-if="sede.tipo" class="cv__sede-card-tipo">{{ sedeTipoLabel(sede.tipo) }}</div>
                </div>
                <i v-if="sede.id" class="bi bi-arrow-right cv__sede-card-arrow"></i>
              </div>

              <div class="cv__sede-card-stats">
                <div class="cv__sede-stat cv__sede-stat--green">
                  <span class="cv__sede-stat-lbl">Ingresos</span>
                  <span class="cv__sede-stat-val">{{ fmt(sede.ingresos) }}</span>
                </div>
                <div class="cv__sede-stat cv__sede-stat--red">
                  <span class="cv__sede-stat-lbl">Egresos</span>
                  <span class="cv__sede-stat-val">{{ fmt(sede.egresos) }}</span>
                </div>
                <div class="cv__sede-stat">
                  <span class="cv__sede-stat-lbl">Balance</span>
                  <span class="cv__sede-stat-val" :style="{ color: balanceColor(sede.balance) }">{{ fmt(sede.balance) }}</span>
                </div>
              </div>

              <div v-if="sede.ingresos + sede.egresos > 0" class="cv__sede-bar-wrap">
                <div
                  class="cv__sede-bar-fill"
                  :style="{ width: `${Math.min(100, (sede.ingresos / (sede.ingresos + sede.egresos)) * 100)}%` }"
                ></div>
              </div>
              <div v-if="sede.ingresos + sede.egresos > 0" class="cv__sede-bar-labels">
                <span>Ing.</span><span>Egr.</span>
              </div>

              <div class="cv__sede-anio">
                <span class="cv__sede-anio-lbl">Año {{ new Date().getFullYear() }}</span>
                <span class="cv__sede-anio-val" :style="{ color: balanceColor(sede.anio.balance) }">
                  {{ fmt(sede.anio.balance) }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Últimos movimientos -->
        <div class="cv__card cv__card--mt">
          <div class="cv__card-header">
            <span class="cv__card-title">Últimos movimientos</span>
            <div class="cv__card-header-right">
              <div class="cv__search-inline">
                <i class="bi bi-search cv__search-icon-sm"></i>
                <input v-model="busquedaDash" class="cv__search-sm" placeholder="Buscar…" />
                <span v-if="busquedaDash" class="cv__search-x" @click="busquedaDash = ''"><i class="bi bi-x"></i></span>
              </div>
              <button class="cv__btn-link" @click="irALibro">Ver todos →</button>
            </div>
          </div>
          <div v-if="!ultimosFiltrados.length" class="cv__empty-sm">
            {{ busquedaDash ? 'Sin resultados para "' + busquedaDash + '"' : 'Sin movimientos todavía' }}
          </div>
          <div v-else class="cv__movs">
            <div v-for="m in ultimosFiltrados" :key="m.id" class="cv__mov">
              <div class="cv__mov-fecha">{{ m.fecha }}</div>
              <div class="cv__mov-tipo">
                <span class="cv__tipo-pill" :style="{ background: tipoMeta(m.tipo).bg, color: tipoMeta(m.tipo).color }">
                  {{ tipoMeta(m.tipo).label }}
                </span>
              </div>
              <div class="cv__mov-desc cv__mov-desc--link" @click="abrirDetalle(m)" title="Ver detalle">{{ m.descripcion }}<i class="bi bi-info-circle cv__mov-info"></i></div>
              <div class="cv__mov-cat">{{ catLabel(m.categoria) }}</div>
              <div class="cv__mov-monto" :style="{ color: tipoMeta(m.tipo).color }">{{ fmt(m.monto_ars) }}</div>
              <div class="cv__mov-actions">
                <template v-if="canEdit && !esAutomatico(m) && !esCerrado(m)">
                  <button class="cv__icon-btn" @click="openEdit(m)" title="Editar">
                    <i class="bi bi-pencil"></i>
                  </button>
                  <button class="cv__icon-btn cv__icon-btn--danger" @click="confirmDelete(m)" title="Eliminar">
                    <i class="bi bi-trash"></i>
                  </button>
                </template>
                <i v-else-if="esCerrado(m)" class="bi bi-lock-fill cv__auto-icon" title="Período cerrado — movimiento inmutable"></i>
                <i v-else-if="esAutomatico(m)" class="bi bi-link-45deg cv__auto-icon" title="Generado por una dispensación — se corrige desde la dispensación"></i>
              </div>
            </div>
          </div>
        </div>

      </template>
    </div>

    <!-- ══════════════ LIBRO DIARIO ══════════════ -->
    <div v-else-if="vistaActiva === 'libro'">
      <div class="cv__filtros">
        <div class="cv__filtro-search">
          <i class="bi bi-search cv__search-icon"></i>
          <input v-model="filtroQ" class="cv__filtro-input cv__filtro-input--wide" placeholder="Buscar descripción, categoría, proveedor…" />
          <span v-if="filtroQ" class="cv__search-x cv__search-x--in" @click="filtroQ = ''"><i class="bi bi-x"></i></span>
        </div>
        <select class="cv__filtro-input" v-model="filtroTipo" @change="aplicarFiltros">
          <option value="">Todos los tipos</option>
          <option value="ingreso">Ingreso</option>
          <option value="egreso">Egreso</option>
          <option value="recupero_costo">Recupero</option>
          <option value="ajuste">Ajuste</option>
        </select>
        <select class="cv__filtro-input" v-model="filtroCategoria" @change="aplicarFiltros">
          <option value="">Todas las categorías</option>
          <option v-for="c in CATEGORIAS" :key="c.value" :value="c.value">{{ c.label }}</option>
        </select>
        <select class="cv__filtro-input" v-model="filtroSede" @change="aplicarFiltros">
          <option value="">Todas las sedes</option>
          <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <div class="cv__filtro-fechas">
          <AppDatePicker v-model="filtroDesde" @update:model-value="aplicarFiltros" />
          <span class="cv__filtro-sep">—</span>
          <AppDatePicker v-model="filtroHasta" @update:model-value="aplicarFiltros" />
        </div>
        <button v-if="hayFiltros" class="cv__btn-clear" @click="limpiarFiltros">
          <i class="bi bi-x-circle"></i> Limpiar
        </button>
      </div>

      <div class="cv__totales">
        <div class="cv__total cv__total--green">
          <div class="cv__total-label">Ingresos del período</div>
          <div class="cv__total-val">{{ fmt(store.totales.ingresos) }}</div>
        </div>
        <div class="cv__total" :class="store.totales.egresos > 0 ? 'cv__total--red' : ''">
          <div class="cv__total-label">Egresos del período</div>
          <div class="cv__total-val">{{ fmt(store.totales.egresos) }}</div>
        </div>
        <div class="cv__total" :style="{ background: balanceBg(store.totales.balance), borderColor: balanceColor(store.totales.balance) + '40' }">
          <div class="cv__total-label">Balance</div>
          <div class="cv__total-val" :style="{ color: balanceColor(store.totales.balance) }">{{ fmt(store.totales.balance) }}</div>
        </div>
      </div>

      <div class="cv__card">
        <div v-if="store.loading" class="cv__loading"><DsSpinner :size="60" /></div>
        <div v-else-if="!itemsFiltrados.length" class="cv__empty">
          <div class="cv__empty-icon"><i class="bi bi-journal-text"></i></div>
          <div class="cv__empty-title">Sin movimientos</div>
          <p class="cv__empty-desc">{{ filtroQ || hayFiltros ? 'Probá ajustando los filtros.' : 'Registrá el primer movimiento.' }}</p>
          <button v-if="canEdit && !filtroQ && !hayFiltros" class="cv__btn-primary" @click="openCreate">
            <i class="bi bi-plus-lg"></i> Nuevo movimiento
          </button>
        </div>
        <div v-else class="cv__table-wrap">
          <table class="cv__table">
            <thead>
            <tr>
              <th>Fecha</th>
              <th>Descripción</th>
              <th>Categoría</th>
              <th>Sede</th>
              <th class="cv__th-right">Monto ARS</th>
              <th>Estado</th>
              <th v-if="canEdit"></th>
            </tr>
            </thead>
            <tbody>
            <tr v-for="m in itemsFiltrados" :key="m.id" class="cv__tr">
              <td class="cv__td-fecha">{{ m.fecha }}</td>
              <td>
                <div class="cv__desc-cell">
                    <span class="cv__tipo-pill cv__tipo-pill--sm" :style="{ background: tipoMeta(m.tipo).bg, color: tipoMeta(m.tipo).color }">
                      {{ tipoMeta(m.tipo).label }}
                    </span>
                  <span class="cv__desc-text">{{ m.descripcion }}</span>
                </div>
              </td>
              <td class="cv__td-muted">{{ catLabel(m.categoria) }}</td>
              <td class="cv__td-muted">{{ m.sede?.nombre || '—' }}</td>
              <td class="cv__td-right cv__td-bold" :style="{ color: tipoMeta(m.tipo).color }">{{ fmt(m.monto_ars) }}</td>
              <td>
                  <span class="cv__pagado-pill" :class="m.pagado ? 'cv__pagado-pill--ok' : 'cv__pagado-pill--pend'">
                    {{ m.pagado ? '✓ Pagado' : (['ingreso','recupero_costo'].includes(m.tipo) ? 'A crédito' : 'Pendiente') }}
                  </span>
              </td>
              <td v-if="canEdit">
                <div class="cv__row-actions">
                  <template v-if="!esAutomatico(m) && !esCerrado(m)">
                    <button class="cv__icon-btn" @click="openEdit(m)"><i class="bi bi-pencil"></i></button>
                    <button class="cv__icon-btn cv__icon-btn--danger" @click="confirmDelete(m)"><i class="bi bi-trash"></i></button>
                  </template>
                  <i v-else-if="esCerrado(m)" class="bi bi-lock-fill cv__auto-icon" title="Período cerrado — movimiento inmutable"></i>
                  <i v-else class="bi bi-link-45deg cv__auto-icon" title="Generado por una dispensación — se corrige desde la dispensación"></i>
                </div>
              </td>
            </tr>
            </tbody>
          </table>
        </div>
        <div v-if="store.pagination.total_pages > 1" class="cv__pagination">
          <button class="cv__page-btn" :disabled="store.pagination.page <= 1" @click="goToPage(store.pagination.page - 1)">
            <i class="bi bi-chevron-left"></i>
          </button>
          <button
            v-for="p in store.pagination.total_pages" :key="p"
            class="cv__page-btn" :class="{ 'cv__page-btn--active': p === store.pagination.page }"
            @click="goToPage(p)"
          >{{ p }}</button>
          <button class="cv__page-btn" :disabled="store.pagination.page >= store.pagination.total_pages" @click="goToPage(store.pagination.page + 1)">
            <i class="bi bi-chevron-right"></i>
          </button>
          <span class="cv__page-info">Página {{ store.pagination.page }} de {{ store.pagination.total_pages }}</span>
        </div>
      </div>
    </div>

    <!-- ══════════════ MODAL CREAR/EDITAR ══════════════ -->
    <ModalNuevoMovimiento
      v-model="showModal"
      :balance-actual="store.dashboard?.mes_actual?.balance || 0"
      :pacientes="pacientes"
      :sedes="sedes"
      :unidades="unidades"
      :categorias="categorias"
      :insumos="insumos"
      :depositos="depositos"
      :bares="bares"
      :movimiento-editar="editingMovimiento"
      @guardado="onMovimientoGuardado"
    />

    <EditarCompraCuotasModal
      v-model="showEditarCuotas"
      :compra="compraEditar"
      :sedes="sedes"
      @saved="onCompraCuotasEditada"
    />

    <!-- Detalle informativo de un movimiento -->
    <div v-if="detalleMov" class="cv__ov" @click.self="detalleMov = null">
      <div class="cv__dlg">
        <div class="cv__dlg-head">
          <span class="cv__tipo-pill" :style="{ background: tipoMeta(detalleMov.tipo).bg, color: tipoMeta(detalleMov.tipo).color }">{{ tipoMeta(detalleMov.tipo).label }}</span>
          <span class="cv__dlg-monto" :style="{ color: tipoMeta(detalleMov.tipo).color }">{{ fmt(detalleMov.monto_ars) }}</span>
          <button class="cv__dlg-x" @click="detalleMov = null" aria-label="Cerrar">×</button>
        </div>
        <p class="cv__dlg-desc">{{ detalleMov.descripcion }}</p>
        <dl class="cv__dlg-dl">
          <dt>Categoría</dt><dd>{{ detalleMov.categoria_label || catLabel(detalleMov.categoria) }}</dd>
          <dt v-if="detalleMov.unidad_negocio">Unidad</dt><dd v-if="detalleMov.unidad_negocio">{{ detalleMov.unidad_negocio.nombre }}</dd>
          <dt v-if="detalleMov.sede">Sede</dt><dd v-if="detalleMov.sede">{{ detalleMov.sede.nombre }}</dd>
          <dt>Fecha</dt><dd>{{ detalleMov.fecha }}</dd>
          <dt v-if="detalleMov.proveedor">Proveedor</dt><dd v-if="detalleMov.proveedor">{{ detalleMov.proveedor }}</dd>
          <dt v-if="detalleMov.medio_pago">Medio de pago</dt><dd v-if="detalleMov.medio_pago">{{ detalleMov.medio_pago }}</dd>
          <dt v-if="detalleMov.created_by">Cargado por</dt><dd v-if="detalleMov.created_by">{{ detalleMov.created_by }}</dd>
        </dl>
        <RouterLink v-if="detalleMov.es_bar && detalleMov.bar_id" :to="`/bar/${detalleMov.bar_id}/panel`" class="cv__dlg-link" @click="detalleMov = null">
          <i class="bi bi-box-arrow-up-right"></i> Entrar al salón
        </RouterLink>
      </div>
    </div>

    <!-- ══════════════ P&L POR LOTE ══════════════ -->
    <div v-if="vistaActiva === 'pl'" ref="plContainerRef">
      <div v-if="loadingLotes" class="cv__loading"><DsSpinner /></div>
      <template v-else>

        <!-- Sub-tabs + PDF export -->
        <div class="cv__pl-subtabs">
          <button class="cv__pl-subtab" :class="{ 'cv__pl-subtab--active': plSubTab === 'lotes' }" @click="plSubTab = 'lotes'">
            Por lote
          </button>
          <button class="cv__pl-subtab" :class="{ 'cv__pl-subtab--active': plSubTab === 'cepas' }" @click="plSubTab = 'cepas'">
            Por genética
          </button>
          <button class="cv__btn-ghost cv__pl-pdf" :disabled="generandoPDF" @click="exportarPDF">
            <DsSpinner v-if="generandoPDF" :size="11" />
            <i v-else class="bi bi-file-earmark-pdf"></i>
            {{ generandoPDF ? 'Generando…' : 'Exportar PDF' }}
          </button>
        </div>

        <!-- ── Sub-tab Lotes ── -->
        <div v-if="plSubTab === 'lotes'">
        <div class="cv__pl-header">
          <div>
            <h2 class="cv__pl-title">P&amp;L por lote de producción</h2>
            <p class="cv__pl-sub">Lotes con costos cargados · ordenados por eficiencia (costo/g)</p>
          </div>
          <span class="cv__pl-count">{{ lotesConCosto.length }} lote{{ lotesConCosto.length !== 1 ? 's' : '' }}</span>
        </div>

        <div v-if="!lotesConCosto.length" class="cv__pl-empty">
          <i class="bi bi-calculator" style="font-size:2rem;color:#cbd5e1"></i>
          <p>Ningún lote tiene costos cargados aún.</p>
          <p style="font-size:.8rem;color:#94a3b8">Abrí un lote y cargá sus costos de producción.</p>
        </div>

        <div v-else class="cv__pl-table">
          <div class="cv__pl-thead">
            <span>Lote</span>
            <span>Genética</span>
            <span>Estado</span>
            <span class="cv__pl-num">Costo total</span>
            <span class="cv__pl-num">Gramos</span>
            <span class="cv__pl-num">$/g</span>
            <span></span>
          </div>
          <RouterLink
            v-for="l in lotesConCosto"
            :key="l.id"
            :to="`/salas/${l.sala_id}/lotes/${l.id}`"
            class="cv__pl-row"
          >
            <span class="cv__pl-codigo">{{ l.codigo }}</span>
            <span class="cv__pl-cepa">{{ l.genetica?.nombre || l.strain || '—' }}</span>
            <span>
              <span class="cv__pl-estado" :style="estadoStyle(l.estado)">{{ l.estado }}</span>
            </span>
            <span class="cv__pl-num cv__pl-monto">{{ l.costo_total ? fmt(l.costo_total) : '—' }}</span>
            <span class="cv__pl-num">{{ l.gramos_producidos ? l.gramos_producidos + 'g' : '—' }}</span>
            <span class="cv__pl-num cv__pl-cpg" :class="{ 'cv__pl-cpg--ok': l.costo_por_gramo && l.costo_por_gramo < 2000 }">
              {{ l.costo_por_gramo ? fmt(l.costo_por_gramo) : '—' }}
            </span>
            <span class="cv__pl-arrow"><i class="bi bi-chevron-right"></i></span>
          </RouterLink>
        </div>

        <div v-if="todosLotes.length > 0 && !lotesConCosto.length" class="cv__pl-hint">
          <i class="bi bi-info-circle"></i>
          Hay {{ todosLotes.length }} lotes en el sistema. Cargá costos desde el detalle de cada lote.
        </div>
        </div><!-- /sub-tab lotes -->

        <!-- ── Sub-tab Cepas ── -->
        <div v-if="plSubTab === 'cepas'">
          <div class="cv__pl-header">
            <div>
              <h2 class="cv__pl-title">Eficiencia por genética</h2>
              <p class="cv__pl-sub">Promedio de costo/g agrupado por genética · menor es mejor</p>
            </div>
            <span class="cv__pl-count">{{ plPorCepa.length }} genética{{ plPorCepa.length !== 1 ? 's' : '' }}</span>
          </div>

          <div v-if="!plPorCepa.length" class="cv__pl-empty">
            <i class="bi bi-bar-chart" style="font-size:2rem;color:#cbd5e1"></i>
            <p>No hay datos de costo por genética aún.</p>
          </div>

          <div v-else class="cv__pl-table">
            <div class="cv__pl-thead" style="grid-template-columns:1.5fr 1fr 1fr 1fr 1fr 1fr">
              <span>Genética</span>
              <span class="cv__pl-num">Lotes</span>
              <span class="cv__pl-num">$/g promedio</span>
              <span class="cv__pl-num">$/g mínimo</span>
              <span class="cv__pl-num">$/g máximo</span>
              <span class="cv__pl-num">Gramos total</span>
            </div>
            <div
              v-for="g in plPorCepa"
              :key="g.genetica_id"
              class="cv__pl-row"
              style="grid-template-columns:1.5fr 1fr 1fr 1fr 1fr 1fr"
            >
              <span class="cv__pl-cepa" style="font-weight:700;color:#1e293b">{{ g.nombre }}</span>
              <span class="cv__pl-num">{{ g.n_lotes }}</span>
              <span class="cv__pl-num cv__pl-cpg" :class="{ 'cv__pl-cpg--ok': g.cpg_promedio && g.cpg_promedio < 2000 }">
                {{ g.cpg_promedio ? fmt(g.cpg_promedio) : '—' }}
              </span>
              <span class="cv__pl-num" style="color:#15803d;font-family:monospace">{{ g.cpg_min ? fmt(g.cpg_min) : '—' }}</span>
              <span class="cv__pl-num" style="color:#dc2626;font-family:monospace">{{ g.cpg_max ? fmt(g.cpg_max) : '—' }}</span>
              <span class="cv__pl-num" style="font-family:monospace">{{ g.total_gramos ? g.total_gramos.toFixed(0) + 'g' : '—' }}</span>
            </div>
          </div>
        </div><!-- /sub-tab cepas -->

      </template>
    </div>

  </div>
</template>

<style scoped>
.cv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .cv { padding: 1.25rem 1rem 2rem; } }

.cv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.cv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.cv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.cv__header-right { display: flex; gap: .65rem; align-items: center; flex-wrap: wrap; }

.cv__tabs { display: flex; gap: .25rem; border-bottom: 2px solid #e2e8f0; margin-bottom: 1.75rem; }
.cv__tab { display: flex; align-items: center; gap: .4rem; padding: .65rem 1.1rem; font-size: .875rem; font-weight: 600; color: #64748b; background: none; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; cursor: pointer; transition: all .15s; }
.cv__tab:hover { color: #0f172a; }
.cv__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }

/* Paneles embebidos (reporte/depósito/categorías): se anula su chrome de página para que
   se integren como una sección más del hub, sin doble padding ni ancho propio. */
.cv__embed :deep(.cat-view) { padding: 0; max-width: none; margin: 0; }

.cv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.5rem; }
@media (max-width: 900px) { .cv__kpis { grid-template-columns: 1fr 1fr; } }
@media (max-width: 480px) { .cv__kpis { grid-template-columns: 1fr; } }
.cv__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; position: relative; overflow: hidden; }
.cv__kpi--highlight { border-color: #d4e6d4; background: #f9fdf9; }
.cv__kpi-label { font-size: .72rem; color: #64748b; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .5rem; }
.cv__kpi-val { font-size: 1.4rem; font-weight: 800; letter-spacing: -.03em; }
.cv__kpi-val--green { color: #15803d; }
.cv__kpi-val--amber { color: #b45309; }
.cv__kpi-val--red   { color: #dc2626; }
.cv__kpi-bar { position: absolute; bottom: 0; left: 0; right: 0; height: 3px; }
.cv__kpi-bar--green   { background: #15803d; }
.cv__kpi-bar--amber   { background: #f59e0b; }
.cv__auto-icon { color: #94a3b8; font-size: 1rem; cursor: help; }

/* Cierre de período */
.cv__cierre { display: flex; align-items: center; justify-content: space-between; gap: 1rem; flex-wrap: wrap; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: .7rem 1rem; margin-bottom: 1rem; }
.cv__cierre-info { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: #475569; }
.cv__cierre-info i { color: #64748b; }
.cv__cierre-actions { display: flex; gap: .5rem; }
.cv__cierre-btn { display: inline-flex; align-items: center; gap: .35rem; background: #0f172a; color: #fff; border: none; border-radius: 8px; padding: .45rem .85rem; font-size: .78rem; font-weight: 700; cursor: pointer; }
.cv__cierre-btn:hover { opacity: .9; }
.cv__cierre-btn:disabled { opacity: .5; cursor: wait; }
.cv__cierre-btn--ghost { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; }
.cv__cierre-btn--ghost:hover { color: #0f172a; border-color: #94a3b8; opacity: 1; }
.cv__kpi-bar--red     { background: #dc2626; }
.cv__kpi-bar--neutral { background: #e2e8f0; }

.cv__row2 { display: grid; grid-template-columns: 1fr 320px; gap: 1rem; margin-bottom: 1.5rem; }
@media (max-width: 1000px) { .cv__row2 { grid-template-columns: 1fr; } }

.cv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.cv__card--main { flex: 1; }
.cv__card--mt { margin-top: 1.25rem; }
.cv__card-header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; flex-wrap: wrap; gap: .5rem; }
.cv__card-title { font-size: .9rem; font-weight: 700; color: #0f172a; }
.cv__card-sub { font-size: .78rem; color: #94a3b8; }
.cv__card-header-right { display: flex; align-items: center; gap: .65rem; flex-wrap: wrap; }

.cv__search-inline { position: relative; display: flex; align-items: center; }
.cv__search-icon-sm { position: absolute; left: .6rem; font-size: .75rem; color: #94a3b8; pointer-events: none; }
.cv__search-sm { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .4rem .65rem .4rem 1.75rem; font-size: .78rem; width: 160px; outline: none; transition: border-color .15s; }
.cv__search-sm:focus { border-color: #1b5e20; }
.cv__search-x { position: absolute; right: .5rem; color: #94a3b8; cursor: pointer; font-size: .9rem; display: flex; align-items: center; }
.cv__search-x:hover { color: #0f172a; }

.cv__movs { display: flex; flex-direction: column; }
.cv__mov { display: grid; grid-template-columns: 90px 80px 1fr 140px 110px 36px; align-items: center; gap: .5rem; padding: .75rem 1.25rem; border-bottom: 1px solid #f8fafc; transition: background .1s; }
.cv__mov:last-child { border-bottom: none; }
.cv__mov:hover { background: #fafbfc; }
@media (max-width: 900px) { .cv__mov { grid-template-columns: 1fr; } }
.cv__mov-fecha { font-size: .72rem; color: #94a3b8; font-family: monospace; }
.cv__mov-desc { font-size: .82rem; color: #0f172a; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__mov-desc--link { cursor: pointer; }
.cv__mov-desc--link:hover { color: #1b5e20; text-decoration: underline; }
.cv__mov-info { margin-left: .35rem; color: #cbd5e1; font-size: .78rem; }
.cv__mov-desc--link:hover .cv__mov-info { color: #1b5e20; }

/* Modal detalle de movimiento */
.cv__ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1100; padding: 1rem; }
.cv__dlg { background: #fff; border-radius: 16px; padding: 1.4rem 1.5rem; width: 100%; max-width: 420px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.cv__dlg-head { display: flex; align-items: center; gap: .6rem; margin-bottom: .8rem; }
.cv__dlg-monto { font-size: 1.3rem; font-weight: 800; letter-spacing: -.02em; font-variant-numeric: tabular-nums; }
.cv__dlg-x { margin-left: auto; background: none; border: none; font-size: 1.5rem; line-height: 1; color: #94a3b8; cursor: pointer; }
.cv__dlg-x:hover { color: #334155; }
.cv__dlg-desc { font-size: .95rem; font-weight: 650; color: #0f172a; margin: 0 0 1rem; line-height: 1.4; }
.cv__dlg-dl { display: grid; grid-template-columns: auto 1fr; gap: .45rem .9rem; margin: 0 0 1rem; }
.cv__dlg-dl dt { font-size: .72rem; color: #94a3b8; font-weight: 600; text-transform: uppercase; letter-spacing: .03em; }
.cv__dlg-dl dd { font-size: .84rem; color: #0f172a; font-weight: 600; margin: 0; text-align: right; text-transform: capitalize; }
.cv__dlg-link { display: inline-flex; align-items: center; gap: .4rem; background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; border-radius: 9px; padding: .55rem .9rem; font-size: .84rem; font-weight: 700; text-decoration: none; }
.cv__dlg-link:hover { background: #dcfce7; }
.cv__mov-cat { font-size: .75rem; color: #64748b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__mov-monto { font-size: .875rem; font-weight: 700; text-align: right; letter-spacing: -.02em; }
.cv__mov-actions { display: flex; justify-content: flex-end; }

.cv__cat-list { display: flex; flex-direction: column; }
.cv__cat-item { display: flex; align-items: center; justify-content: space-between; padding: .65rem 1.25rem; border-bottom: 1px solid #f8fafc; }
.cv__cat-item:last-child { border-bottom: none; }
.cv__cat-left { display: flex; align-items: center; gap: .6rem; min-width: 0; }
.cv__cat-name { font-size: .8rem; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__cat-monto { font-size: .82rem; font-weight: 700; flex-shrink: 0; }

.cv__tipo-pill { display: inline-flex; align-items: center; font-size: .68rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; white-space: nowrap; }
.cv__tipo-pill--sm { font-size: .64rem; }

.cv__filtros { display: flex; align-items: center; gap: .65rem; margin-bottom: 1.1rem; flex-wrap: wrap; }
.cv__filtro-search { position: relative; display: flex; align-items: center; flex: 1; min-width: 200px; }
.cv__search-icon { position: absolute; left: .75rem; color: #94a3b8; font-size: .8rem; pointer-events: none; }
.cv__filtro-input { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; color: #0f172a; outline: none; transition: border-color .15s; }
.cv__filtro-input--wide { padding-left: 2.25rem; width: 100%; }
.cv__filtro-input--date { width: 140px; }
.cv__filtro-input:focus { border-color: #1b5e20; }
.cv__search-x--in { position: absolute; right: .6rem; color: #94a3b8; cursor: pointer; font-size: .9rem; display: flex; }
.cv__search-x--in:hover { color: #0f172a; }
.cv__filtro-fechas { display: flex; align-items: center; gap: .4rem; }
.cv__filtro-sep { color: #94a3b8; font-size: .8rem; }
.cv__btn-clear { display: inline-flex; align-items: center; gap: .3rem; background: none; border: 1.5px solid #e2e8f0; color: #64748b; padding: .55rem .875rem; border-radius: 9px; font-size: .8rem; font-weight: 500; cursor: pointer; white-space: nowrap; transition: all .15s; }
.cv__btn-clear:hover { border-color: #dc2626; color: #dc2626; background: #fef2f2; }

.cv__totales { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: .875rem; margin-bottom: 1.1rem; }
@media (max-width: 640px) { .cv__totales { grid-template-columns: 1fr; } }
.cv__total { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: 1rem 1.25rem; }
.cv__total--green { background: rgba(21,128,61,.06); border-color: rgba(21,128,61,.2); }
.cv__total--red   { background: rgba(220,38,38,.06); border-color: rgba(220,38,38,.2); }
.cv__total-label { font-size: .72rem; color: #64748b; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .3rem; }
.cv__total-val { font-size: 1.2rem; font-weight: 800; letter-spacing: -.03em; }
.cv__total--green .cv__total-val { color: #15803d; }
.cv__total--red   .cv__total-val { color: #dc2626; }

.cv__table-wrap { overflow-x: auto; }
.cv__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.cv__table th { padding: .75rem 1rem; font-size: .7rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1.5px solid #f1f5f9; background: #fafbfc; white-space: nowrap; }
.cv__table td { padding: .75rem 1rem; border-bottom: 1px solid #f8fafc; vertical-align: middle; }
.cv__table tfoot td { padding: .75rem 1rem; border-top: 2px solid #e2e8f0; font-weight: 700; background: #fafbfc; }
.cv__table tbody tr:last-child td { border-bottom: none; }
.cv__table tbody tr:hover td { background: #fafbfc; }
.cv__th-right { text-align: right; }
.cv__th-green  { color: #15803d !important; }
.cv__th-red    { color: #dc2626 !important; }
.cv__td-right  { text-align: right; }
.cv__td-green  { color: #15803d; }
.cv__td-red    { color: #dc2626; }
.cv__td-bold   { font-weight: 700; }
.cv__td-muted  { color: #64748b; font-size: .78rem; }
.cv__td-fecha  { color: #94a3b8; font-size: .75rem; font-family: monospace; white-space: nowrap; }
.cv__td-mes    { font-weight: 500; color: #0f172a; }
.cv__desc-cell { display: flex; align-items: center; gap: .5rem; }
.cv__desc-text { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 280px; }

.cv__pagado-pill { font-size: .68rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; white-space: nowrap; }
.cv__pagado-pill--ok   { background: rgba(21,128,61,.1); color: #15803d; }
.cv__pagado-pill--pend { background: rgba(180,83,9,.1);  color: #b45309; }

.cv__row-actions { display: flex; gap: .35rem; justify-content: flex-end; }

.cv__icon-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .75rem; transition: all .15s; }
.cv__icon-btn:hover { background: #e2e8f0; color: #0f172a; }
.cv__icon-btn--danger:hover { background: #fef2f2; border-color: #fecaca; color: #dc2626; }

.cv__empty { text-align: center; padding: 3.5rem 1rem; color: #94a3b8; }
.cv__empty-sm { text-align: center; padding: 2rem 1rem; color: #94a3b8; font-size: .85rem; }
.cv__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; opacity: .4; }
.cv__empty-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin-bottom: .5rem; }
.cv__empty-desc { font-size: .875rem; margin-bottom: 1.25rem; }

.cv__pagination { display: flex; align-items: center; gap: .35rem; padding: 1rem 1.25rem; border-top: 1px solid #f1f5f9; }
.cv__page-btn { width: 32px; height: 32px; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #fff; color: #64748b; font-size: .8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .15s; }
.cv__page-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.cv__page-btn--active { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.cv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.cv__page-info { font-size: .75rem; color: #94a3b8; margin-left: .5rem; }

.cv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.cv__btn-primary:hover:not(:disabled) { background: #144a18; }
.cv__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.cv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .65rem 1.1rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; white-space: nowrap; }
.cv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.cv__btn-danger { display: inline-flex; align-items: center; gap: .35rem; background: #dc2626; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.cv__btn-danger:hover:not(:disabled) { background: #b91c1c; }
.cv__btn-danger:disabled { opacity: .55; cursor: not-allowed; }
.cv__btn-link { background: none; border: none; color: #1b5e20; font-size: .8rem; font-weight: 600; cursor: pointer; padding: 0; white-space: nowrap; }
.cv__btn-link:hover { text-decoration: underline; }

.cv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }


/* ══ Selector de sede en dashboard ══════════════════════ */
.cv__sede-selector {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 1.25rem;
}
.cv__sede-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 14px;
  border: 1.5px solid #e2e8f0;
  border-radius: 8px;
  background: #f8fafc;
  font-size: 13px;
  color: #64748b;
  cursor: pointer;
  transition: all .15s;
  font-weight: 500;
}
.cv__sede-btn:hover { border-color: #94a3b8; color: #0f172a; }
.cv__sede-btn--active { border-color: #1b5e20; background: rgba(27,94,32,.07); color: #1b5e20; }

.cv__dash-context {
  display: flex;
  align-items: center;
  gap: 8px;
  background: rgba(3,105,161,.05);
  border: 1px solid rgba(3,105,161,.18);
  border-radius: 9px;
  padding: 9px 14px;
  font-size: 13px;
  color: #0f172a;
  margin-bottom: 1.25rem;
}
.cv__dash-context-clear {
  margin-left: auto;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 12px;
  color: #0369a1;
  display: flex;
  align-items: center;
  gap: 4px;
  font-weight: 500;
}
.cv__dash-context-clear:hover { text-decoration: underline; }

/* ══ NUEVO: Breakdown por sede ════════════════════════════════ */
.cv__sede-breakdown {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 14px;
  padding: 16px;
}

.cv__sede-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 11px;
  transition: box-shadow .15s, border-color .15s;
}
.cv__sede-card--clickable { cursor: pointer; }
.cv__sede-card--clickable:hover { box-shadow: 0 2px 12px rgba(0,0,0,.08); border-color: #1b5e20; }

.cv__sede-card-header { display: flex; align-items: center; gap: 10px; }
.cv__sede-card-icon {
  width: 34px; height: 34px; border-radius: 9px;
  display: flex; align-items: center; justify-content: center;
  font-size: 15px; flex-shrink: 0;
}
.cv__sede-card-info { flex: 1; min-width: 0; }
.cv__sede-card-nombre { font-size: 14px; font-weight: 700; color: #0f172a; }
.cv__sede-card-tipo { font-size: 11px; color: #94a3b8; margin-top: 1px; }
.cv__sede-card-arrow { color: #cbd5e1; font-size: 13px; transition: transform .15s, color .15s; margin-left: auto; }
.cv__sede-card--clickable:hover .cv__sede-card-arrow { color: #1b5e20; transform: translateX(3px); }

.cv__sede-card-stats { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6px; }
.cv__sede-stat {
  background: white; border: 1px solid #f1f5f9;
  border-radius: 8px; padding: 7px 6px; text-align: center;
}
.cv__sede-stat--green { border-color: rgba(21,128,61,.15); background: rgba(21,128,61,.03); }
.cv__sede-stat--red   { border-color: rgba(220,38,38,.15); background: rgba(220,38,38,.03); }
.cv__sede-stat-lbl { display: block; font-size: 10px; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; margin-bottom: 3px; }
.cv__sede-stat-val { display: block; font-size: 11px; font-weight: 700; color: #0f172a; }
.cv__sede-stat--green .cv__sede-stat-val { color: #15803d; }
.cv__sede-stat--red   .cv__sede-stat-val { color: #dc2626; }

.cv__sede-bar-wrap { height: 5px; background: rgba(220,38,38,.18); border-radius: 999px; overflow: hidden; }
.cv__sede-bar-fill { height: 100%; background: #15803d; border-radius: 999px; transition: width .4s; }
.cv__sede-bar-labels { display: flex; justify-content: space-between; font-size: 10px; color: #94a3b8; margin-top: 1px; }

.cv__sede-anio {
  display: flex; justify-content: space-between; align-items: center;
  padding-top: 10px; border-top: 1px solid #f1f5f9;
}
.cv__sede-anio-lbl { font-size: 11px; color: #94a3b8; }
.cv__sede-anio-val { font-size: 13px; font-weight: 700; }

/* ── P&L sub-tabs ── */
.cv__pl-subtabs { display: flex; align-items: center; gap: .25rem; margin-bottom: 1.5rem; border-bottom: 2px solid #e2e8f0; }
.cv__pl-subtab { background: none; border: none; padding: .6rem 1rem; font-size: .875rem; font-weight: 600; color: #64748b; cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -2px; transition: color .15s, border-color .15s; }
.cv__pl-subtab:hover { color: #0f172a; }
.cv__pl-subtab--active { color: #15803d; border-bottom-color: #15803d; }
.cv__pl-pdf { margin-left: auto; margin-bottom: 2px; display: flex; align-items: center; gap: .4rem; font-size: .8rem; padding: .4rem .85rem; }

/* ── P&L por lote ── */
.cv__pl-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.cv__pl-title  { font-size: 1.2rem; font-weight: 700; margin: 0 0 .2rem; color: #0f172a; }
.cv__pl-sub    { font-size: .8rem; color: #64748b; margin: 0; }
.cv__pl-count  { font-family: monospace; font-size: .85rem; font-weight: 700; background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; padding: .25rem .75rem; border-radius: 999px; white-space: nowrap; }

.cv__pl-empty { text-align: center; padding: 4rem 1rem; color: #64748b; display: flex; flex-direction: column; align-items: center; gap: .5rem; }
.cv__pl-hint  { text-align: center; padding: 1.5rem; font-size: .82rem; color: #94a3b8; display: flex; align-items: center; justify-content: center; gap: .5rem; }

.cv__pl-table { border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; }
.cv__pl-thead {
  display: grid;
  grid-template-columns: 1fr 1.2fr 1fr 1fr 1fr 1fr 28px;
  gap: .5rem;
  padding: .65rem 1.1rem;
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
  font-size: .72rem;
  font-weight: 700;
  color: #64748b;
  letter-spacing: .04em;
  text-transform: uppercase;
}
.cv__pl-row {
  display: grid;
  grid-template-columns: 1fr 1.2fr 1fr 1fr 1fr 1fr 28px;
  gap: .5rem;
  padding: .8rem 1.1rem;
  align-items: center;
  border-bottom: 1px solid #f1f5f9;
  text-decoration: none;
  color: inherit;
  transition: background .12s;
  font-size: .85rem;
}
.cv__pl-row:last-child { border-bottom: none; }
.cv__pl-row:hover { background: #f8fafc; }
.cv__pl-codigo { font-family: monospace; font-size: .8rem; font-weight: 700; color: #1e293b; }
.cv__pl-cepa   { font-size: .82rem; color: #475569; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__pl-estado { font-size: .72rem; font-weight: 600; padding: .2rem .55rem; border-radius: 999px; white-space: nowrap; }
.cv__pl-num    { text-align: right; font-family: monospace; }
.cv__pl-monto  { color: #475569; font-size: .8rem; }
.cv__pl-cpg    { font-weight: 700; font-size: .85rem; color: #1e293b; }
.cv__pl-cpg--ok { color: #15803d; }
.cv__pl-arrow  { color: #cbd5e1; font-size: .8rem; text-align: right; }
.cv__pl-row:hover .cv__pl-arrow { color: #64748b; }

@media (max-width: 768px) {
  .cv__pl-thead { display: none; }
  .cv__pl-row   { grid-template-columns: 1fr 1fr 28px; }
  .cv__pl-cepa, .cv__pl-monto, .cv__pl-num:nth-child(5) { display: none; }
}

/* Resultado por unidad de negocio */
.cv__unidad-list { display: flex; flex-direction: column; }
.cv__unidad-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 2px; border-bottom: 1px solid #eef1ec; gap: 12px;
}
.cv__unidad-row:last-child { border-bottom: none; }
.cv__unidad-name { font-weight: 550; color: #1f2a24; font-size: .9rem; }
.cv__unidad-nums { display: flex; align-items: baseline; gap: 14px; font-variant-numeric: tabular-nums; }
.cv__unidad-in  { color: #2f6b3d; font-size: .82rem; }
.cv__unidad-out { color: #b23b2e; font-size: .82rem; }
.cv__unidad-bal { font-size: .95rem; min-width: 90px; text-align: right; }
.cv__unidad-bal.is-pos { color: #2f6b3d; }
.cv__unidad-bal.is-neg { color: #b23b2e; }
.cv__unidad-row--exp { cursor: pointer; }
.cv__unidad-row--exp:hover { background: #f6f8f5; }
.cv__unidad-caret { font-size: .7rem; color: #94a3b8; margin-right: 5px; }
.cv__unidad-sedes-badge { margin-left: 8px; font-size: .68rem; font-weight: 600; color: #64748b; background: #eef1ec; border-radius: 6px; padding: 1px 7px; }
.cv__unidad-sedes { display: flex; flex-direction: column; background: #fafbf9; border-bottom: 1px solid #eef1ec; }
.cv__unidad-subrow { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 7px 2px 7px 22px; }
.cv__unidad-subrow + .cv__unidad-subrow { border-top: 1px dashed #eef1ec; }
.cv__unidad-subname { font-size: .82rem; color: #5b6b60; display: flex; align-items: center; gap: 5px; }
.cv__unidad-subname .bi { font-size: .72rem; color: #94a3b8; }
</style>
