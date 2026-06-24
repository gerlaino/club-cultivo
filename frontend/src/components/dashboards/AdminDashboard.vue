<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import Chart from 'chart.js/auto'
import {
  listSedes, getContableDashboard, listLotes, listPesajesManicuraAdmin,
  getAnalyticsDispensador, listStocksPendientes,
  listDispensacionesFecha, getAnalyticsEjecutivo,
} from '../../lib/api.js'
import { useAuthStore }  from '../../stores/auth.js'
import { useClubStore }  from '../../stores/club.js'
import { useStatsStore } from '../../stores/stats.js'
import { useTareasStore } from '../../stores/tareas.js'
import OnboardingWizard  from '../OnboardingWizard.vue'
import DsSpinner         from '../../design-system/components/Spinner.vue'

const router      = useRouter()
const auth        = useAuthStore()
const club        = useClubStore()
const statsStore  = useStatsStore()
const tareasStore = useTareasStore()

// ── State ──────────────────────────────────────────────────────────────────

const sedes                  = ref([])
const contable               = ref(null)
const pesajesPorConfirmar    = ref([])
const stocksPendientes       = ref([])
const analyticsDisp          = ref(null)
const lotesEnFloracion       = ref([])
const lotesActivos           = ref([])
const dispensacionesHoy      = ref([])
const ejecutivo              = ref(null)
const loading                = ref(true)
const erroresCarga           = ref([])

const chartCanvas   = ref(null)
let   chartInstance = null

const stats = computed(() => statsStore.data ?? {})
// Solo después de cargar: durante la carga se muestra el spinner estándar,
// no el wizard (su modo "checking" pintaba la pantalla verde en cada visita)
const mostrarOnboarding = computed(() => !loading.value && sedes.value.length === 0)

// ── Greeting ───────────────────────────────────────────────────────────────

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const _hoy   = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const hoy    = _hoy.charAt(0).toUpperCase() + _hoy.slice(1)
const mesLabel = new Date().toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })
  .replace(/^\w/, c => c.toUpperCase())

// ── Formatters ─────────────────────────────────────────────────────────────

function fmtCompacto(n) {
  if (n == null) return '—'
  // Es plata: mostramos el monto exacto, sin abreviar (abreviar redondeaba 18.5k → 19k).
  return new Intl.NumberFormat('es-AR', {
    style: 'currency', currency: 'ARS',
    minimumFractionDigits: 0, maximumFractionDigits: 2,
  }).format(n)
}

function timeAgo(ts) {
  if (!ts) return ''
  const diff = Math.floor((Date.now() - new Date(ts)) / 1000)
  if (diff < 60)    return 'hace un momento'
  if (diff < 3600)  return `hace ${Math.floor(diff / 60)}min`
  if (diff < 86400) return `hace ${Math.floor(diff / 3600)}h`
  if (diff < 172800) return 'ayer'
  return `hace ${Math.floor(diff / 86400)}d`
}

function fmtHora(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

// ── KPIs principales ────────────────────────────────────────────────────────

const plantasEnCiclo = computed(() => (stats.value?.vegetativo || 0) + (stats.value?.floracion || 0))
const balanceMes     = computed(() => contable.value?.mes_actual?.balance || 0)
const balancePositivo = computed(() => balanceMes.value >= 0)

const stockTotalG = computed(() => {
  const ss = analyticsDisp.value?.stocks
  if (!ss?.length) return null
  return ss.reduce((acc, s) => acc + (s.cantidad_g || 0), 0)
})

const stockAlerta = computed(() => {
  const t = stockTotalG.value
  if (t == null) return 'sin_datos'
  if (t < 50)  return 'critico'
  if (t < 200) return 'bajo'
  return 'normal'
})

const deltaBalance = computed(() => {
  const actual   = contable.value?.mes_actual?.balance
  const anterior = contable.value?.mes_anterior?.balance
  if (actual == null || anterior == null) return null
  return actual - anterior
})

const pacientesActivos = computed(() => stats.value?.pacientes ?? null)

// ── Próxima cosecha ─────────────────────────────────────────────────────────

const proximaCosecha = computed(() => {
  const now = Date.now()
  const candidatos = lotesEnFloracion.value
    .filter(l => l.fecha_cosecha_estimada)
    .map(l => ({
      ...l,
      diff: Math.ceil((new Date(l.fecha_cosecha_estimada).getTime() - now) / 86400000),
    }))
    .filter(l => l.diff >= 0)
    .sort((a, b) => a.diff - b.diff)
  return candidatos[0] ?? null
})

// ── Reservas para preparar (desde el analytics del dispensador) ──────────────
const reservasHoy      = computed(() => analyticsDisp.value?.reservas?.hoy ?? 0)
const reservasVencidas = computed(() => analyticsDisp.value?.reservas?.vencidas ?? 0)
const reservasLista    = computed(() => analyticsDisp.value?.reservas?.lista ?? [])

const FORMA_LABEL_RES = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura',
  crema: 'Crema', capsula: 'Cápsula', comestible: 'Comestible', prensado: 'Prensado',
  preroll: 'Preroll', externo: 'Externo', otro: 'Otro',
}
function formaLabelRes(f) { return FORMA_LABEL_RES[f] || f || '—' }
function fmtFechaRes(f) {
  if (!f) return '—'
  return new Date(f + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: 'short' })
}
function fmtARSres(n) { return '$' + (Number(n) || 0).toLocaleString('es-AR') }

// ── ZONA 1: Alertas ─────────────────────────────────────────────────────────

const tareasVencidas = computed(() =>
  (tareasStore.dashboard?.vencidas || []).filter(t => t.estado !== 'completada')
)

const alertas = computed(() => {
  const list = []

  if (pesajesPorConfirmar.value.length > 0) {
    list.push({
      key:     'aprobaciones',
      icono:   '⏳',
      texto:   `${pesajesPorConfirmar.value.length} pesaje${pesajesPorConfirmar.value.length > 1 ? 's' : ''} de manicura esperando confirmación`,
      cta:     'Ir a confirmar',
      ruta:    '/admin/pesajes-manicura',
      nivel:   'amber',
    })
  }

  if (stocksPendientes.value.length > 0) {
    list.push({
      key:   'stock',
      icono: '📦',
      texto: `${stocksPendientes.value.length} stock${stocksPendientes.value.length > 1 ? 's' : ''} sin asignar a pacientes`,
      cta:   'Ver stock',
      ruta:  '/admin/stocks/pendientes',
      nivel: 'amber',
    })
  }

  const repVencidos = stats.value?.reprocann_vencidos || 0
  if (repVencidos > 0) {
    list.push({
      key:   'reprocann_vencidos',
      icono: '⚠️',
      texto: `${repVencidos} paciente${repVencidos > 1 ? 's' : ''} con REPROCANN vencido`,
      cta:   'Ver pacientes',
      ruta:  '/pacientes',
      nivel: 'rojo',
    })
  }

  const repPorVencer = stats.value?.reprocann_por_vencer || 0
  if (repPorVencer > 0) {
    list.push({
      key:   'reprocann_proximos',
      icono: '🕐',
      texto: `${repPorVencer} paciente${repPorVencer > 1 ? 's' : ''} con REPROCANN por vencer en 30 días`,
      cta:   'Ver pacientes',
      ruta:  '/pacientes',
      nivel: 'amber',
    })
  }

  if (tareasVencidas.value.length > 0) {
    list.push({
      key:   'tareas',
      icono: '📋',
      texto: `${tareasVencidas.value.length} tarea${tareasVencidas.value.length > 1 ? 's' : ''} vencida${tareasVencidas.value.length > 1 ? 's' : ''}`,
      cta:   'Ver tareas',
      ruta:  '/tareas',
      nivel: 'amber',
    })
  }

  if (reservasVencidas.value > 0) {
    list.push({
      key:   'reservas_vencidas',
      icono: '📦',
      texto: `${reservasVencidas.value} reserva${reservasVencidas.value > 1 ? 's' : ''} vencida${reservasVencidas.value > 1 ? 's' : ''} sin preparar`,
      cta:   'Ver reservas',
      ruta:  '/reservas',
      nivel: 'rojo',
    })
  } else if (reservasHoy.value > 0) {
    list.push({
      key:   'reservas_hoy',
      icono: '📦',
      texto: `${reservasHoy.value} reserva${reservasHoy.value > 1 ? 's' : ''} para preparar hoy`,
      cta:   'Ver reservas',
      ruta:  '/reservas',
      nivel: 'amber',
    })
  }

  if (proximaCosecha.value && proximaCosecha.value.diff <= 7) {
    const { diff, codigo, genetica } = proximaCosecha.value
    list.push({
      key:   'cosecha',
      icono: '🌾',
      texto: `Cosecha estimada en ${diff === 0 ? 'hoy' : diff + ' días'} — ${genetica?.nombre || ''} ${codigo}`,
      cta:   'Ver lote',
      ruta:  `/lotes/${proximaCosecha.value.id}`,
      nivel: 'verde',
    })
  }

  return list
})

// ── Pulse line (header) ────────────────────────────────────────────────────

const pulseLine = computed(() => {
  const partes = []
  if (plantasEnCiclo.value) partes.push(`${plantasEnCiclo.value} plantas en ciclo`)
  if (statsStore.totalLotes) partes.push(`${statsStore.totalLotes} lotes activos`)
  if (balanceMes.value) partes.push(`${fmtCompacto(balanceMes.value)} este mes`)
  return partes.join(' · ')
})

// ── Resumen anual ───────────────────────────────────────────────────────────

const añoActual = new Date().getFullYear()

const ejActual   = computed(() => ejecutivo.value?.actual   ?? null)
const ejAnterior = computed(() => ejecutivo.value?.anterior ?? null)

function deltaAnual(campo) {
  const a = ejActual.value?.[campo]
  const b = ejAnterior.value?.[campo]
  if (a == null || b == null || b === 0) return null
  return ((a - b) / Math.abs(b) * 100).toFixed(1)
}

function fmtG(v) { return v != null ? `${Number(v).toLocaleString('es-AR')} g` : '—' }

// ── Lotes activos (Zona 3) ─────────────────────────────────────────────────

const ESTADO_COLOR = {
  semilla:            '#64748b',
  esqueje:            '#0891b2',
  vegetativo:         '#16a34a',
  floracion:          '#9333ea',
  cosecha:            '#dc2626',
  en_manicura:        '#d97706',
  manicura_pendiente: '#f59e0b',
  secado:             '#78350f',
  curado:             '#2563eb',
  finalizado:         '#94a3b8',
}

const ESTADO_LABEL = {
  semilla: 'Semilla', esqueje: 'Esqueje', vegetativo: 'Vegetativo',
  floracion: 'Floración', cosecha: 'Cosecha', en_manicura: 'En manicura',
  manicura_pendiente: 'Pdte. aprobación', secado: 'Secado', curado: 'Curado',
  finalizado: 'Finalizado',
}

const lotesActivosFiltrados = computed(() =>
  lotesActivos.value
    .filter(l => l.estado !== 'finalizado')
    .slice(0, 5)
)

// ── Actividad reciente (Zona 4) ────────────────────────────────────────────

const actividadReciente = computed(() =>
  (contable.value?.ultimos_movimientos || []).slice(0, 8)
)

function movIco(m) {
  if (m.tipo === 'ingreso')        return '💰'
  if (m.tipo === 'recupero_costo') return '↩️'
  if (m.tipo === 'egreso')         return '💸'
  return '📝'
}

// ── Sedes ──────────────────────────────────────────────────────────────────

function sedeDot(sede) {
  return (sede.salas_count || 0) > 0 ? '#16a34a' : '#f59e0b'
}
const TIPO_LABEL = { produccion: 'Producción', social: 'Dispensario', mixta: 'Mixta' }
function tipoLabel(t) { return TIPO_LABEL[t] || t }

// ── Chart financiero (Zona 5) ──────────────────────────────────────────────

function initChart(semanas) {
  if (!chartCanvas.value || !semanas?.length) return
  if (chartInstance) { chartInstance.destroy(); chartInstance = null }
  chartInstance = new Chart(chartCanvas.value, {
    type: 'bar',
    data: {
      labels: semanas.map(s => s.label),
      datasets: [
        {
          label: 'Ingresos',
          data: semanas.map(s => s.ingresos),
          backgroundColor: 'rgba(22,163,74,.75)',
          borderColor: '#16a34a',
          borderWidth: 1,
          borderRadius: 4,
        },
        {
          label: 'Egresos',
          data: semanas.map(s => s.egresos),
          backgroundColor: 'rgba(220,38,38,.65)',
          borderColor: '#dc2626',
          borderWidth: 1,
          borderRadius: 4,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: true,
          position: 'bottom',
          labels: { color: '#64748b', font: { size: 11 }, boxWidth: 10, padding: 12 },
        },
        tooltip: {
          callbacks: { label: (ctx) => `${ctx.dataset.label}: ${fmtCompacto(ctx.raw)}` },
        },
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: { color: '#94a3b8', font: { size: 11 }, callback: (v) => fmtCompacto(v) },
          grid:  { color: '#f1f5f9' },
        },
        x: {
          ticks: { color: '#94a3b8', font: { size: 11 } },
          grid:  { display: false },
        },
      },
    },
  })
}

watch(() => contable.value?.mes_actual?.por_semana, (data) => {
  if (data?.length) initChart(data)
})

// ── Data loading ───────────────────────────────────────────────────────────

const todayISO = new Date().toISOString().slice(0, 10)

onMounted(async () => {
  try {
    const [sedesRes, contableRes, manicuraRes, dispRes, stocksRes, floracionRes, lotesRes, dispHoyRes, ejecutivoRes] =
      await Promise.allSettled([
        listSedes(),
        getContableDashboard(),
        listPesajesManicuraAdmin(),
        getAnalyticsDispensador(),
        listStocksPendientes(),
        listLotes({ estado: 'floracion', limit: 20 }),
        listLotes({ limit: 8 }),
        listDispensacionesFecha({ fecha: todayISO }),
        getAnalyticsEjecutivo(),
      ])
    await Promise.allSettled([statsStore.fetchAll(), tareasStore.fetchDashboard()])

    if (sedesRes.status      === 'fulfilled') sedes.value                  = sedesRes.value.data    || []
    if (contableRes.status   === 'fulfilled') contable.value               = contableRes.value.data
    if (manicuraRes.status   === 'fulfilled') pesajesPorConfirmar.value     = manicuraRes.value.data  || []
    if (dispRes.status       === 'fulfilled') analyticsDisp.value          = dispRes.value.data
    if (stocksRes.status     === 'fulfilled') stocksPendientes.value       = stocksRes.value.data   || []
    if (floracionRes.status  === 'fulfilled') lotesEnFloracion.value       = floracionRes.value.data || []
    if (lotesRes.status      === 'fulfilled') lotesActivos.value           = lotesRes.value.data    || []
    if (dispHoyRes.status    === 'fulfilled') dispensacionesHoy.value      = dispHoyRes.value.data  || []
    if (ejecutivoRes.status  === 'fulfilled') ejecutivo.value              = ejecutivoRes.value.data
    else erroresCarga.value.push('resumen anual')

    if (contable.value?.mes_actual?.por_semana?.length)
      initChart(contable.value.mes_actual.por_semana)
  } finally {
    loading.value = false
  }
})

onUnmounted(() => { if (chartInstance) chartInstance.destroy() })

async function onOnboardingCompletado() {
  const res = await listSedes()
  sedes.value = res.data || []
}
</script>

<template>
  <div class="ad">
    <div v-if="loading" class="ad__loading"><DsSpinner /></div>

    <OnboardingWizard v-else-if="mostrarOnboarding" @completado="onOnboardingCompletado" />

    <template v-if="!loading && !mostrarOnboarding">

      <!-- ── ERRORES DE CARGA ───────────────────────────────────────────── -->
      <div v-if="erroresCarga.length" class="ad__error-banner">
        Algunos datos no pudieron cargarse: {{ erroresCarga.join(', ') }}. Recargá la página si el problema persiste.
      </div>

      <!-- ── HEADER ──────────────────────────────────────────────────────── -->
      <div class="ad__header">
        <div>
          <h1 class="ad__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
          <p class="ad__fecha">{{ hoy }}</p>
          <p v-if="pulseLine" class="ad__pulse">{{ pulseLine }}</p>
        </div>
      </div>

      <!-- ── ZONA 1: ALERTAS ─────────────────────────────────────────────── -->
      <div v-if="alertas.length" class="ad__alertas">
        <div
          v-for="a in alertas"
          :key="a.key"
          class="ad__alerta"
          :class="`ad__alerta--${a.nivel}`"
        >
          <span class="ad__alerta-ico">{{ a.icono }}</span>
          <span class="ad__alerta-texto">{{ a.texto }}</span>
          <RouterLink :to="a.ruta" class="ad__alerta-cta">{{ a.cta }} →</RouterLink>
        </div>
      </div>

      <!-- ── ZONA 2: KPIs en dos columnas ───────────────────────────────── -->
      <div class="ad__kpi-cols">

        <!-- Cultivo -->
        <div class="ad__kpi-group">
          <div class="ad__kpi-group-label">Cultivo</div>
          <div class="ad__kpi-grid">

            <div class="ad__kpi">
              <span class="ad__kpi-label">Plantas en ciclo</span>
              <div class="ad__kpi-num">{{ plantasEnCiclo }}</div>
              <div class="ad__kpi-sub">{{ stats?.vegetativo ?? 0 }} veg · {{ stats?.floracion ?? 0 }} flor</div>
            </div>

            <div class="ad__kpi">
              <span class="ad__kpi-label">Lotes activos</span>
              <div class="ad__kpi-num">{{ statsStore.totalLotes }}</div>
              <div class="ad__kpi-sub">en cultivo</div>
            </div>

            <div class="ad__kpi">
              <span class="ad__kpi-label">Próxima cosecha</span>
              <div class="ad__kpi-num" v-if="proximaCosecha !== null">{{ proximaCosecha.diff }}d</div>
              <div class="ad__kpi-num ad__kpi-num--empty" v-else>—</div>
              <div class="ad__kpi-sub">
                <span v-if="proximaCosecha">{{ proximaCosecha.genetica?.nombre || 'Sin genética' }}</span>
                <span v-else>Sin cosechas programadas</span>
              </div>
            </div>

            <div class="ad__kpi">
              <span class="ad__kpi-label">Stock disponible</span>
              <div class="ad__kpi-num" :class="{ 'ad__kpi-num--alerta': stockAlerta === 'critico' }">
                {{ stockTotalG != null ? stockTotalG.toFixed(0) + ' g' : '0 g' }}
              </div>
              <div class="ad__kpi-sub">
                <span v-if="stockAlerta === 'critico'" style="color:#dc2626">⚠️ Reposición urgente</span>
                <span v-else-if="stockAlerta === 'bajo'" style="color:#d97706">⚡ Stock bajo</span>
                <span v-else>Disponible ✓</span>
              </div>
            </div>

          </div>
        </div>

        <!-- Negocio -->
        <div class="ad__kpi-group">
          <div class="ad__kpi-group-label">Negocio</div>
          <div class="ad__kpi-grid">

            <div class="ad__kpi">
              <span class="ad__kpi-label">Balance del mes</span>
              <div class="ad__kpi-num" :style="{ color: balancePositivo ? '#16a34a' : '#dc2626' }">
                {{ fmtCompacto(balanceMes) }}
              </div>
              <div class="ad__kpi-sub">
                <span v-if="deltaBalance !== null" :class="deltaBalance >= 0 ? 'ad__delta--pos' : 'ad__delta--neg'">
                  {{ deltaBalance >= 0 ? '↑' : '↓' }} vs. mes anterior
                </span>
              </div>
            </div>

            <div class="ad__kpi">
              <span class="ad__kpi-label">Dispensaciones hoy</span>
              <div class="ad__kpi-num">{{ analyticsDisp?.resumen?.dispensaciones_hoy ?? 0 }}</div>
              <div class="ad__kpi-sub">{{ analyticsDisp?.resumen?.gramos_hoy != null ? analyticsDisp.resumen.gramos_hoy + ' g dispensados' : '—' }}</div>
            </div>

            <div class="ad__kpi">
              <span class="ad__kpi-label">Pacientes activos</span>
              <div class="ad__kpi-num">{{ pacientesActivos ?? '—' }}</div>
              <div class="ad__kpi-sub">en tratamiento</div>
            </div>

            <div class="ad__kpi">
              <span class="ad__kpi-label">Ingresos del mes</span>
              <div class="ad__kpi-num" style="color:#16a34a">{{ fmtCompacto(contable?.mes_actual?.ingresos) }}</div>
              <div class="ad__kpi-sub">
                <span v-if="contable?.mes_actual?.egresos > 0" style="color:#dc2626">
                  - {{ fmtCompacto(contable.mes_actual.egresos) }} egresos
                </span>
                <span v-else>Sin egresos registrados</span>
              </div>
            </div>

          </div>
        </div>

      </div>

      <!-- ── Reservas para preparar ──────────────────────────────────────── -->
      <div class="ad__widget ad__widget--lotes ad__widget--reservas">
        <div class="ad__widget-hdr">
          <span class="ad__widget-title">📦 Reservas para preparar</span>
          <RouterLink to="/reservas" class="ad__widget-link">Ver todas →</RouterLink>
        </div>
        <div v-if="!reservasLista.length" class="ad__empty ad__empty--pad">
          No hay reservas para preparar hoy ·
          <RouterLink to="/reservas" style="color:#2563eb">Ver reservas →</RouterLink>
        </div>
        <div v-else class="ad__reservas">
          <RouterLink
            v-for="r in reservasLista.slice(0, 8)" :key="r.id"
            to="/reservas"
            class="ad__reserva"
            :class="{ 'ad__reserva--venc': r.vencida }"
          >
            <div class="ad__reserva-main">
              <span class="ad__reserva-nombre">{{ r.paciente }}</span>
              <span class="ad__reserva-prod">{{ fmtG(r.cantidad) }} · {{ formaLabelRes(r.forma_producto) }}</span>
            </div>
            <div class="ad__reserva-side">
              <span class="ad__reserva-fecha" :class="{ 'ad__reserva-fecha--venc': r.vencida }">
                <i v-if="r.vencida" class="bi bi-exclamation-circle"></i>
                {{ r.vencida ? 'Venció ' : '' }}{{ fmtFechaRes(r.fecha) }}
              </span>
              <span v-if="r.resta_ars > 0" class="ad__reserva-resta">Resta {{ fmtARSres(r.resta_ars) }}</span>
              <span v-else class="ad__reserva-sena">Señada ✓</span>
            </div>
          </RouterLink>
        </div>
      </div>

      <!-- ── ZONA 2.5: RESUMEN ANUAL ───────────────────────────────────────── -->
      <div v-if="ejActual" class="ad__anual">
        <div class="ad__anual-hdr">
          <span class="ad__anual-title">Resumen {{ añoActual }}</span>
          <RouterLink to="/analitica" class="ad__widget-link">Ver analítica →</RouterLink>
        </div>
        <div class="ad__anual-grid">

          <div class="ad__anual-kpi">
            <span class="ad__anual-lbl">Gramos producidos</span>
            <span class="ad__anual-val">{{ fmtG(ejActual.gramos_producidos) }}</span>
            <span v-if="deltaAnual('gramos_producidos')" class="ad__anual-delta"
                  :class="Number(deltaAnual('gramos_producidos')) >= 0 ? 'ad__anual-delta--pos' : 'ad__anual-delta--neg'">
              {{ Number(deltaAnual('gramos_producidos')) >= 0 ? '↑' : '↓' }} {{ Math.abs(deltaAnual('gramos_producidos')) }}% vs {{ añoActual - 1 }}
            </span>
          </div>

          <div class="ad__anual-kpi">
            <span class="ad__anual-lbl">Ingresos {{ añoActual }}</span>
            <span class="ad__anual-val" style="color:#16a34a">{{ fmtCompacto(ejActual.ingresos) }}</span>
            <span v-if="deltaAnual('ingresos')" class="ad__anual-delta"
                  :class="Number(deltaAnual('ingresos')) >= 0 ? 'ad__anual-delta--pos' : 'ad__anual-delta--neg'">
              {{ Number(deltaAnual('ingresos')) >= 0 ? '↑' : '↓' }} {{ Math.abs(deltaAnual('ingresos')) }}% vs {{ añoActual - 1 }}
            </span>
          </div>

          <div class="ad__anual-kpi">
            <span class="ad__anual-lbl">Margen</span>
            <span class="ad__anual-val" :style="{ color: ejActual.margen >= 0 ? '#16a34a' : '#dc2626' }">
              {{ fmtCompacto(ejActual.margen) }}
              <small v-if="ejActual.margen_pct != null" style="font-size:.65em;font-weight:600">
                ({{ ejActual.margen_pct }}%)
              </small>
            </span>
            <span v-if="deltaAnual('margen')" class="ad__anual-delta"
                  :class="Number(deltaAnual('margen')) >= 0 ? 'ad__anual-delta--pos' : 'ad__anual-delta--neg'">
              {{ Number(deltaAnual('margen')) >= 0 ? '↑' : '↓' }} {{ Math.abs(deltaAnual('margen')) }}% vs {{ añoActual - 1 }}
            </span>
          </div>

          <div class="ad__anual-kpi">
            <span class="ad__anual-lbl">Ciclos cerrados</span>
            <span class="ad__anual-val">{{ ejActual.ciclos_cerrados }}</span>
            <span v-if="ejAnterior" class="ad__anual-delta ad__anual-delta--neutral">
              {{ ejAnterior.ciclos_cerrados }} en {{ añoActual - 1 }}
            </span>
          </div>

        </div>
      </div>

      <!-- ── ZONA 3: LOTES ACTIVOS ───────────────────────────────────────── -->
      <div class="ad__widget ad__widget--lotes">
        <div class="ad__widget-hdr">
          <span class="ad__widget-title">Lotes activos</span>
          <RouterLink to="/lotes" class="ad__widget-link">Ver todos →</RouterLink>
        </div>

        <div v-if="lotesActivosFiltrados.length" class="ad__lotes-list">
          <RouterLink
            v-for="lote in lotesActivosFiltrados"
            :key="lote.id"
            :to="`/lotes/${lote.id}`"
            class="ad__lote-card"
          >
            <div class="ad__lote-stripe" :style="{ background: ESTADO_COLOR[lote.estado] || '#94a3b8' }"></div>
            <div class="ad__lote-body">
              <div class="ad__lote-top">
                <span class="ad__lote-codigo">{{ lote.codigo }}</span>
                <span
                  class="ad__lote-badge"
                  :style="{
                    background: (ESTADO_COLOR[lote.estado] || '#94a3b8') + '18',
                    color: ESTADO_COLOR[lote.estado] || '#94a3b8',
                  }"
                >
                  {{ ESTADO_LABEL[lote.estado] || lote.estado }}
                </span>
                <span v-if="lote.estado === 'manicura_pendiente'" class="ad__lote-urgente">⚡ Acción requerida</span>
              </div>
              <div class="ad__lote-meta">
                <span v-if="lote.genetica?.nombre">{{ lote.genetica.nombre }}</span>
                <span class="ad__lote-sep" v-if="lote.genetica?.nombre && lote.sala?.nombre">·</span>
                <span v-if="lote.sala?.nombre">{{ lote.sala.nombre }}</span>
                <span class="ad__lote-sep" v-if="lote.sala?.sede?.nombre">·</span>
                <span v-if="lote.sala?.sede?.nombre" style="color:#94a3b8">{{ lote.sala.sede.nombre }}</span>
              </div>
            </div>
            <div class="ad__lote-plantas">
              <span class="ad__lote-plantas-num">{{ lote.plants_count || 0 }}</span>
              <span class="ad__lote-plantas-lbl">pl.</span>
            </div>
            <i class="bi bi-chevron-right ad__lote-arr"></i>
          </RouterLink>
        </div>

        <div v-else class="ad__empty ad__empty--pad">
          Sin lotes activos ·
          <RouterLink to="/lotes" style="color:#2563eb">Ver lotes →</RouterLink>
        </div>
      </div>

      <!-- ── ZONA 4: Pacientes hoy + Actividad reciente ─────────────────── -->
      <div class="ad__body">

        <!-- Pacientes hoy -->
        <div class="ad__widget">
          <div class="ad__widget-hdr">
            <span class="ad__widget-title">Pacientes hoy</span>
            <span v-if="dispensacionesHoy.length" class="ad__badge ad__badge--green">
              {{ dispensacionesHoy.length }} disp.
            </span>
          </div>

          <template v-if="dispensacionesHoy.length">
            <div v-for="d in dispensacionesHoy.slice(0, 6)" :key="d.id" class="ad__disp-item">
              <div class="ad__disp-avatar">{{ (d.paciente_nombre || '?').charAt(0).toUpperCase() }}</div>
              <div class="ad__disp-body">
                <span class="ad__disp-nombre">{{ d.paciente_nombre }}</span>
                <span class="ad__disp-meta">
                  {{ d.cantidad }}g
                  <span v-if="d.stock?.forma_producto"> · {{ d.stock.forma_producto }}</span>
                </span>
              </div>
              <span class="ad__disp-hora">{{ fmtHora(d.created_at) }}</span>
            </div>
            <p v-if="dispensacionesHoy.length > 6" class="ad__item-more">
              y {{ dispensacionesHoy.length - 6 }} más hoy
            </p>
          </template>
          <p v-else class="ad__empty ad__empty--pad">Sin dispensaciones hoy</p>

          <RouterLink to="/historial" class="ad__widget-cta">Ver historial →</RouterLink>
        </div>

        <!-- Actividad reciente -->
        <div class="ad__widget">
          <div class="ad__widget-hdr">
            <span class="ad__widget-title">Actividad reciente</span>
            <RouterLink to="/contabilidad" class="ad__widget-link">Ver libro →</RouterLink>
          </div>

          <template v-if="actividadReciente.length">
            <div v-for="m in actividadReciente" :key="m.id" class="ad__feed-item">
              <span class="ad__feed-ico">{{ movIco(m) }}</span>
              <div class="ad__feed-body">
                <span class="ad__feed-desc">{{ m.descripcion || m.categoria }}</span>
                <span class="ad__feed-meta">{{ fmtCompacto(m.monto_ars) }} · {{ timeAgo(m.created_at) }}</span>
              </div>
            </div>
          </template>
          <p v-else class="ad__empty ad__empty--pad">
            Sin actividad registrada ·
            <RouterLink to="/contabilidad">Registrar →</RouterLink>
          </p>
        </div>

      </div>

      <!-- ── ZONA 5: Finanzas + Sedes ────────────────────────────────────── -->
      <div class="ad__bottom">

        <!-- Gráfico financiero del mes -->
        <div class="ad__chart-widget">
          <div class="ad__widget-hdr">
            <span class="ad__widget-title">{{ mesLabel }}</span>
            <RouterLink to="/contabilidad" class="ad__widget-link">Ver detalle →</RouterLink>
          </div>
          <div class="ad__chart-wrap">
            <canvas ref="chartCanvas" />
          </div>
          <div class="ad__chart-footer">
            <div class="ad__chart-stat">
              <span class="ad__chart-stat-lbl">Ingresos</span>
              <span class="ad__chart-stat-val" style="color:#16a34a">{{ fmtCompacto(contable?.mes_actual?.ingresos) }}</span>
            </div>
            <div class="ad__chart-divider"></div>
            <div class="ad__chart-stat">
              <span class="ad__chart-stat-lbl">Egresos</span>
              <span class="ad__chart-stat-val" style="color:#dc2626">{{ fmtCompacto(contable?.mes_actual?.egresos) }}</span>
            </div>
            <div class="ad__chart-divider"></div>
            <div class="ad__chart-stat">
              <span class="ad__chart-stat-lbl">Balance</span>
              <span class="ad__chart-stat-val" :style="{ color: balancePositivo ? '#16a34a' : '#dc2626' }">
                {{ fmtCompacto(balanceMes) }}
              </span>
            </div>
          </div>
        </div>

        <!-- Sedes en vivo -->
        <div class="ad__widget">
          <div class="ad__widget-hdr">
            <span class="ad__widget-title">Sedes en vivo</span>
            <RouterLink to="/sedes" class="ad__widget-link">Ver todas →</RouterLink>
          </div>
          <RouterLink
            v-for="sede in sedes"
            :key="sede.id"
            :to="`/sedes/${sede.id}`"
            class="ad__sede-row"
          >
            <span class="ad__sede-dot" :style="{ background: sedeDot(sede) }"></span>
            <div class="ad__sede-info">
              <span class="ad__sede-nombre">{{ sede.nombre }}</span>
              <span class="ad__sede-meta">
                {{ tipoLabel(sede.tipo) }}
                <template v-if="(sede.salas_count || 0) > 0">
                  · {{ sede.salas_count }} sala{{ sede.salas_count !== 1 ? 's' : '' }}
                </template>
              </span>
            </div>
            <span v-if="!(sede.salas_count || 0)" class="ad__sede-config">Configurar →</span>
          </RouterLink>
          <p v-if="!sedes.length" class="ad__empty ad__empty--pad">Sin sedes configuradas</p>
        </div>

      </div>

    </template>
  </div>
</template>

<style scoped>
.ad__loading { display: flex; justify-content: center; align-items: center; padding: 6rem 0; }

.ad {
  padding: 2rem;
  max-width: 1280px;
  margin: 0 auto;
}

/* ── Error banner ───────────────────────────────────────────────────────── */
.ad__error-banner {
  background: #fef3c7;
  border: 1px solid #d97706;
  color: #92400e;
  border-radius: 8px;
  padding: .65rem 1rem;
  font-size: .85rem;
  margin-bottom: 1rem;
}

/* ── Header ──────────────────────────────────────────────────────────────── */
.ad__header {
  margin-bottom: 1.25rem;
}
.ad__saludo {
  font-size: 1.75rem;
  font-weight: 800;
  color: #0f172a;
  margin: 0;
}
.ad__fecha {
  font-size: .875rem;
  color: #64748b;
  margin: .2rem 0 0;
}
.ad__pulse {
  font-size: .825rem;
  color: #475569;
  margin: .4rem 0 0;
  font-weight: 500;
}

/* ── Zona 1: Alertas ─────────────────────────────────────────────────────── */
.ad__alertas {
  display: flex;
  flex-direction: column;
  gap: .375rem;
  margin-bottom: 1.25rem;
  border-radius: 10px;
  overflow: hidden;
  border: 1px solid #fde68a;
  background: #fffbeb;
}
.ad__alerta {
  display: flex;
  align-items: center;
  gap: .625rem;
  padding: .625rem 1rem;
  font-size: .825rem;
  border-bottom: 1px solid rgba(0,0,0,.04);
}
.ad__alerta:last-child { border-bottom: none; }
.ad__alerta--rojo  { background: #fff5f5; }
.ad__alerta--amber { background: #fffbeb; }
.ad__alerta--verde { background: #f0fdf4; }
.ad__alerta-ico   { font-size: 1rem; flex-shrink: 0; }
.ad__alerta-texto { flex: 1; color: #374151; font-weight: 500; }
.ad__alerta-cta   {
  flex-shrink: 0;
  font-size: .775rem;
  font-weight: 600;
  color: #1d4ed8;
  text-decoration: none;
  padding: .25rem .625rem;
  background: rgba(29,78,216,.08);
  border-radius: 6px;
  white-space: nowrap;
}
.ad__alerta-cta:hover { background: rgba(29,78,216,.15); }

/* ── Zona 2: KPIs en columnas ────────────────────────────────────────────── */
.ad__kpi-cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
  margin-bottom: 1.25rem;
}
.ad__kpi-group {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
}
.ad__kpi-group-label {
  font-size: .6rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: .09em;
  color: #94a3b8;
  padding: .75rem 1.25rem .25rem;
  border-bottom: 1px solid #f1f5f9;
}
.ad__kpi-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0;
}
.ad__kpi {
  padding: 1rem 1.25rem;
  display: flex;
  flex-direction: column;
  gap: .2rem;
  border-right: 1px solid #f1f5f9;
  border-bottom: 1px solid #f1f5f9;
  min-height: 88px;
}
.ad__kpi:nth-child(2n) { border-right: none; }
.ad__kpi:nth-last-child(-n+2) { border-bottom: none; }

.ad__kpi-label {
  font-size: .6rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #94a3b8;
}
.ad__kpi-num {
  font-size: 1.625rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1;
  font-family: var(--font-display);
}
.ad__kpi-num--empty  { color: #cbd5e1; }
.ad__kpi-num--alerta { color: #dc2626; }
.ad__kpi-sub {
  font-size: .72rem;
  color: #64748b;
  margin-top: .1rem;
}
.ad__delta--pos { color: #16a34a; font-weight: 600; }
.ad__delta--neg { color: #dc2626; font-weight: 600; }

/* ── Widget base ─────────────────────────────────────────────────────────── */
.ad__widget {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
}
.ad__widget--lotes { margin-bottom: 1.25rem; }
.ad__widget-hdr {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .875rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}
.ad__widget-title { font-size: .8rem; font-weight: 700; color: #374151; flex: 1; }
.ad__widget-link {
  font-size: .73rem;
  color: #64748b;
  text-decoration: none;
}
.ad__widget-link:hover { color: #0f172a; text-decoration: underline; }
.ad__widget-cta {
  display: block;
  font-size: .75rem;
  color: #64748b;
  padding: .5rem 1rem;
  text-decoration: none;
  border-top: 1px solid #f8fafc;
}
.ad__widget-cta:hover { color: #0f172a; background: #f8fafc; }

.ad__badge {
  font-size: .6rem;
  font-weight: 700;
  border-radius: 99px;
  padding: .15em .5em;
  background: #fef2f2;
  color: #dc2626;
}
.ad__badge--green  { background: #f0fdf4; color: #16a34a; }
.ad__badge--amber  { background: #fffbeb; color: #d97706; }

.ad__empty {
  font-size: .8rem;
  color: #94a3b8;
  padding: .625rem 1rem;
  margin: 0;
}
.ad__empty--pad { padding: 1rem; }
.ad__item-more { font-size: .72rem; color: #94a3b8; padding: .25rem 1rem; margin: 0; }

/* ── Zona 3: Lotes activos ───────────────────────────────────────────────── */
.ad__lotes-list {
  display: flex;
  flex-direction: column;
}
.ad__lote-card {
  display: flex;
  align-items: center;
  text-decoration: none;
  border-bottom: 1px solid #f8fafc;
  transition: background .1s;
  overflow: hidden;
}
.ad__lote-card:last-child { border-bottom: none; }
.ad__lote-card:hover { background: #f8fafc; }

.ad__lote-stripe { width: 3px; align-self: stretch; flex-shrink: 0; }
.ad__lote-body   { flex: 1; padding: .75rem .875rem; min-width: 0; }
.ad__lote-top {
  display: flex;
  align-items: center;
  gap: .5rem;
  margin-bottom: .2rem;
  flex-wrap: wrap;
}
.ad__lote-codigo {
  font-size: .875rem;
  font-weight: 800;
  color: #0f172a;
  font-family: monospace;
}
.ad__lote-badge {
  font-size: .62rem;
  font-weight: 700;
  padding: .2em .55em;
  border-radius: 999px;
}
.ad__lote-urgente {
  font-size: .62rem;
  font-weight: 700;
  color: #b45309;
  background: #fef3c7;
  padding: .2em .55em;
  border-radius: 999px;
}
.ad__lote-meta {
  font-size: .72rem;
  color: #64748b;
  display: flex;
  gap: .3rem;
  flex-wrap: wrap;
  align-items: center;
}
.ad__lote-sep { color: #d1d5db; }
.ad__lote-plantas {
  display: flex;
  align-items: baseline;
  gap: .15rem;
  padding: 0 .5rem;
  flex-shrink: 0;
}
.ad__lote-plantas-num { font-size: 1rem; font-weight: 700; color: #0f172a; }
.ad__lote-plantas-lbl { font-size: .65rem; color: #94a3b8; }
.ad__lote-arr { color: #d1d5db; font-size: .75rem; padding-right: .875rem; flex-shrink: 0; }

/* ── Zona 4: 2 columnas ─────────────────────────────────────────────────── */
.ad__body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
  margin-bottom: 1.25rem;
}

/* Pacientes hoy */
/* Reservas para preparar */
.ad__widget--reservas { border-color: #bbf7d0; }
.ad__widget--reservas .ad__widget-hdr { background: #f0fdf4; }
.ad__reservas { display: flex; flex-direction: column; }
.ad__reserva {
  display: flex; align-items: center; justify-content: space-between; gap: .75rem;
  padding: .6rem 1rem; border-bottom: 1px solid #f1f5f9; text-decoration: none; color: inherit;
}
.ad__reserva:last-child { border-bottom: none; }
.ad__reserva:hover { background: #f8fafc; }
.ad__reserva--venc { border-left: 3px solid #ef4444; }
.ad__reserva-main { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.ad__reserva-nombre { font-weight: 700; color: #0f172a; font-size: .85rem; }
.ad__reserva-prod { font-size: .78rem; color: #64748b; }
.ad__reserva-side { text-align: right; white-space: nowrap; }
.ad__reserva-fecha { font-size: .8rem; font-weight: 600; color: #334155; }
.ad__reserva-fecha--venc { color: #dc2626; }
.ad__reserva-resta { display: block; font-size: .72rem; color: #b45309; }
.ad__reserva-sena { display: block; font-size: .72rem; color: #15803d; }

.ad__disp-item {
  display: flex;
  align-items: center;
  gap: .625rem;
  padding: .5rem 1rem;
  border-bottom: 1px solid #f8fafc;
  font-size: .8rem;
}
.ad__disp-item:last-of-type { border-bottom: none; }
.ad__disp-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #e0f2fe;
  color: #0369a1;
  font-size: .75rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.ad__disp-body { flex: 1; min-width: 0; }
.ad__disp-nombre { display: block; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ad__disp-meta   { display: block; font-size: .7rem; color: #64748b; }
.ad__disp-hora   { font-size: .7rem; color: #94a3b8; flex-shrink: 0; }

/* Actividad */
.ad__feed-item {
  display: flex;
  align-items: flex-start;
  gap: .75rem;
  padding: .5rem 1rem;
  border-bottom: 1px solid #f8fafc;
  font-size: .8rem;
}
.ad__feed-item:last-child { border-bottom: none; }
.ad__feed-ico  { flex-shrink: 0; font-size: 1rem; line-height: 1.5; }
.ad__feed-body { flex: 1; min-width: 0; }
.ad__feed-desc { display: block; color: #374151; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ad__feed-meta { display: block; font-size: .7rem; color: #94a3b8; margin-top: .1rem; }

/* ── Zona 5: Finanzas + Sedes ────────────────────────────────────────────── */
.ad__bottom {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 1.25rem;
}
.ad__chart-widget {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
}
.ad__chart-wrap {
  height: 180px;
  padding: .875rem 1rem .5rem;
  position: relative;
}
.ad__chart-footer {
  display: flex;
  align-items: center;
  padding: .625rem 1.25rem;
  border-top: 1px solid #f1f5f9;
  gap: 0;
}
.ad__chart-stat {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: .15rem;
  align-items: center;
}
.ad__chart-stat-lbl { font-size: .6rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; }
.ad__chart-stat-val { font-size: .875rem; font-weight: 800; }
.ad__chart-divider  { width: 1px; height: 28px; background: #f1f5f9; flex-shrink: 0; }

/* Sedes */
.ad__sede-row {
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .625rem 1rem;
  text-decoration: none;
  color: inherit;
  border-bottom: 1px solid #f8fafc;
  transition: background .1s;
}
.ad__sede-row:last-child { border-bottom: none; }
.ad__sede-row:hover { background: #f8fafc; }
.ad__sede-dot    { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.ad__sede-info   { flex: 1; min-width: 0; }
.ad__sede-nombre { display: block; font-size: .825rem; font-weight: 600; color: #0f172a; }
.ad__sede-meta   { display: block; font-size: .7rem; color: #94a3b8; margin-top: .1rem; }
.ad__sede-config { font-size: .72rem; color: #2563eb; flex-shrink: 0; }

/* ── Responsive ──────────────────────────────────────────────────────────── */
@media (max-width: 1200px) {
  .ad__bottom { grid-template-columns: 1fr; }
}

@media (max-width: 1023px) {
  .ad__kpi-cols { grid-template-columns: 1fr; }
  .ad__body     { grid-template-columns: 1fr; }
}

@media (max-width: 640px) {
  .ad          { padding: 1rem; }
  .ad__saludo  { font-size: 1.35rem; }
  .ad__kpi-num { font-size: 1.375rem; }
}

/* ── Resumen anual ────────────────────────────────────────────────────────── */
.ad__anual {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
  margin-bottom: 1.25rem;
}
.ad__anual-hdr {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: .75rem 1.25rem .375rem;
  border-bottom: 1px solid #f1f5f9;
}
.ad__anual-title {
  font-size: .6rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: .09em;
  color: #94a3b8;
}
.ad__anual-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
}
@media (max-width: 767px) { .ad__anual-grid { grid-template-columns: repeat(2, 1fr); } }
.ad__anual-kpi {
  padding: .875rem 1.25rem;
  display: flex;
  flex-direction: column;
  gap: .2rem;
  border-right: 1px solid #f1f5f9;
}
.ad__anual-kpi:last-child { border-right: none; }
.ad__anual-lbl  { font-size: .6rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: #94a3b8; }
.ad__anual-val  { font-size: 1.35rem; font-weight: 800; color: #0f172a; line-height: 1.15; letter-spacing: -.03em; }
.ad__anual-delta { font-size: .72rem; font-weight: 600; }
.ad__anual-delta--pos { color: #16a34a; }
.ad__anual-delta--neg { color: #dc2626; }
.ad__anual-delta--neutral { color: #94a3b8; }
</style>
