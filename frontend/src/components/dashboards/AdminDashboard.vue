<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import Chart from 'chart.js/auto'
import { listSedes, getContableDashboard, listLotes, getAnalyticsDispensador, listStocksPendientes } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import { useStatsStore } from '../../stores/stats.js'
import { useTareasStore } from '../../stores/tareas.js'
import OnboardingWizard from '../OnboardingWizard.vue'
import DsSpinner       from '../../design-system/components/Spinner.vue'

const router     = useRouter()
const auth       = useAuthStore()
const club       = useClubStore()
const statsStore = useStatsStore()
const tareasStore = useTareasStore()

const sedes                  = ref([])
const contable               = ref(null)
const lotesManicuraPendiente = ref([])
const stocksPendientes       = ref([])
const analyticsDisp          = ref(null)
const lotesEnFloracion       = ref([])
const loading                = ref(true)

const chartCanvas = ref(null)
let   chartInstance = null

const stats           = computed(() => statsStore.data ?? {})
const mostrarOnboarding = computed(() => !loading.value && sedes.value.length === 0)

// Greeting
const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const _hoy   = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const hoy    = _hoy.charAt(0).toUpperCase() + _hoy.slice(1)

// Formatters
function fmtCompacto(n) {
  if (n == null) return '—'
  const abs = Math.abs(n)
  if (abs >= 1_000_000) return (n < 0 ? '-' : '') + '$' + (abs / 1_000_000).toFixed(1) + 'M'
  if (abs >= 1_000)     return (n < 0 ? '-' : '') + '$' + (abs / 1_000).toFixed(0) + 'k'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(n)
}

function timeAgo(ts) {
  if (!ts) return ''
  const diff = Math.floor((Date.now() - new Date(ts)) / 1000)
  if (diff < 60)    return 'hace un momento'
  if (diff < 3600)  return `hace ${Math.floor(diff / 60)}min`
  if (diff < 86400) return `hace ${Math.floor(diff / 3600)}h`
  return `hace ${Math.floor(diff / 86400)}d`
}

function prioLabel(p) { return { alta: 'Alta', normal: 'Normal', baja: 'Baja' }[p] || p }

function isVencida(t) {
  if (!t.fecha_programada) return false
  return new Date(t.fecha_programada + 'T00:00:00') < new Date(new Date().toDateString())
}

// ── ZONA 2: KPIs operativos ────────────────────────────────────────────────

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

const stockAlertaLabel = computed(() => ({
  critico:   '⚠️ Crítico — reposición urgente',
  bajo:      '⚡ Stock bajo',
  normal:    'Disponible ✓',
  sin_datos: '—',
})[stockAlerta.value])

const deltaBalance = computed(() => {
  const actual   = contable.value?.mes_actual?.balance
  const anterior = contable.value?.mes_anterior?.balance
  if (actual == null || anterior == null) return null
  return actual - anterior
})

const pacientesNecesitanAtencion = computed(() =>
  (stats.value?.reprocann_vencidos || 0) + (stats.value?.reprocann_por_vencer || 0) > 0
)

// ── ZONA 3: Producción ────────────────────────────────────────────────────

const proximaCosechaDias = computed(() => {
  const hoy = Date.now()
  const candidatos = lotesEnFloracion.value
    .filter(l => l.fecha_cosecha_estimada)
    .map(l => ({
      diff: Math.ceil((new Date(l.fecha_cosecha_estimada).getTime() - hoy) / 86400000)
    }))
    .filter(l => l.diff >= 0)
    .sort((a, b) => a.diff - b.diff)
  return candidatos[0]?.diff ?? null
})

const proximaCosechaLabel = computed(() =>
  proximaCosechaDias.value !== null ? 'lote más próximo' : 'Sin cosechas programadas'
)

// ── ZONA 4: Pendientes ───────────────────────────────────────────────────

const tareasHoy = computed(() => {
  const vencidas = tareasStore.dashboard?.vencidas || []
  const hoy      = tareasStore.dashboard?.hoy      || []
  return [...vencidas, ...hoy].filter(t => t.estado !== 'completada')
})

function sedeDot(sede) {
  return (sede.salas_count || 0) > 0 ? '#16a34a' : '#f59e0b'
}

const TIPO_LABEL = { produccion: 'Producción', social: 'Dispensario', mixta: 'Mixta' }
function tipoLabel(t) { return TIPO_LABEL[t] || t }

const actividadReciente = computed(() =>
  (contable.value?.ultimos_movimientos || []).slice(0, 5)
)

// ── Chart.js ─────────────────────────────────────────────────────────────

function initChart(porDia) {
  if (!chartCanvas.value) return
  if (chartInstance) { chartInstance.destroy(); chartInstance = null }
  chartInstance = new Chart(chartCanvas.value, {
    type: 'bar',
    data: {
      labels: porDia.map(d => d.fecha),
      datasets: [{
        data:            porDia.map(d => d.count),
        backgroundColor: '#16a34a',
        hoverBackgroundColor: '#15803d',
        borderRadius:    5,
        barThickness:    28,
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: { label: (ctx) => `${ctx.raw} dispensación${ctx.raw !== 1 ? 'es' : ''}` }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: { stepSize: 1, color: '#94a3b8', font: { size: 11 } },
          grid:  { color: '#f1f5f9' },
        },
        x: {
          ticks: { color: '#94a3b8', font: { size: 11 } },
          grid:  { display: false },
        }
      }
    }
  })
}

watch(() => analyticsDisp.value?.por_dia, (data) => {
  if (data?.length) initChart(data)
})

onMounted(async () => {
  try {
    const [sedesRes, contableRes, manicuraRes, dispRes, stocksRes, floracionRes] = await Promise.allSettled([
      listSedes(),
      getContableDashboard(),
      listLotes({ estado: 'manicura_pendiente' }),
      getAnalyticsDispensador(),
      listStocksPendientes(),
      listLotes({ estado: 'floracion', limit: 20 }),
    ])
    await Promise.allSettled([statsStore.fetchAll(), tareasStore.fetchDashboard()])

    if (sedesRes.status      === 'fulfilled') sedes.value                  = sedesRes.value.data   || []
    if (contableRes.status   === 'fulfilled') contable.value               = contableRes.value.data
    if (manicuraRes.status   === 'fulfilled') lotesManicuraPendiente.value = manicuraRes.value.data || []
    if (dispRes.status       === 'fulfilled') analyticsDisp.value          = dispRes.value.data
    if (stocksRes.status     === 'fulfilled') stocksPendientes.value       = stocksRes.value.data  || []
    if (floracionRes.status  === 'fulfilled') lotesEnFloracion.value       = floracionRes.value.data || []

    if (analyticsDisp.value?.por_dia?.length) initChart(analyticsDisp.value.por_dia)
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
    <OnboardingWizard v-if="mostrarOnboarding" @completado="onOnboardingCompletado" />

    <div v-if="loading" class="ad__loading">
      <DsSpinner />
    </div>

    <template v-else-if="!mostrarOnboarding">

      <!-- ── ZONA 1: Header ──────────────────────────────────────────────── -->
      <div class="ad__header">
        <div>
          <h1 class="ad__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
          <p class="ad__fecha">{{ hoy }}</p>
        </div>
        <div class="ad__header-actions">
          <RouterLink to="/tareas" class="ad__btn-quick">+ Nueva tarea</RouterLink>
          <RouterLink to="/lotes"  class="ad__btn-quick ad__btn-quick--primary">+ Nuevo lote</RouterLink>
        </div>
      </div>

      <!-- ── ZONA 2: KPIs operativos (4 cards) ──────────────────────────── -->
      <div class="ad__kpis">

        <div class="ad__kpi">
          <span class="ad__kpi-label">Dispensaciones hoy</span>
          <div class="ad__kpi-num">{{ analyticsDisp?.resumen?.dispensaciones_hoy ?? 0 }}</div>
          <div class="ad__kpi-sub">{{ analyticsDisp?.resumen?.gramos_hoy != null ? analyticsDisp.resumen.gramos_hoy + ' g dispensados' : '—' }}</div>
        </div>

        <div class="ad__kpi" :class="{ 'ad__kpi--critico': stockAlerta === 'critico', 'ad__kpi--bajo': stockAlerta === 'bajo' }">
          <span class="ad__kpi-label">Stock disponible</span>
          <div class="ad__kpi-num">{{ stockTotalG != null ? stockTotalG.toFixed(0) + ' g' : '0 g' }}</div>
          <div class="ad__kpi-sub">{{ stockAlertaLabel }}</div>
        </div>

        <div class="ad__kpi">
          <span class="ad__kpi-label">Aprobaciones pendientes</span>
          <div class="ad__kpi-num">{{ lotesManicuraPendiente.length }}</div>
          <div class="ad__kpi-sub">
            <RouterLink v-if="lotesManicuraPendiente.length > 0" to="/aprobaciones" class="ad__kpi-link">Ver todas →</RouterLink>
            <span v-else>Todo al día ✓</span>
          </div>
        </div>

        <div class="ad__kpi">
          <span class="ad__kpi-label">Balance del mes</span>
          <div class="ad__kpi-num" :style="{ color: balancePositivo ? '#16a34a' : '#dc2626' }">{{ fmtCompacto(balanceMes) }}</div>
          <div class="ad__kpi-sub">
            <span v-if="deltaBalance !== null" :class="deltaBalance >= 0 ? 'ad__delta--pos' : 'ad__delta--neg'">
              {{ deltaBalance >= 0 ? '↑' : '↓' }} vs. mes anterior
            </span>
          </div>
        </div>

      </div>

      <!-- ── ZONA 3: Estado de producción (3 cards compactas) ───────────── -->
      <div class="ad__prod">

        <div class="ad__prod-card">
          <span class="ad__prod-label">Plantas en ciclo</span>
          <span class="ad__prod-num">{{ plantasEnCiclo }}</span>
          <span class="ad__prod-sub">{{ stats?.vegetativo ?? 0 }} veg · {{ stats?.floracion ?? 0 }} flor</span>
        </div>

        <div class="ad__prod-card">
          <span class="ad__prod-label">Lotes activos</span>
          <span class="ad__prod-num">{{ statsStore.totalLotes }}</span>
          <span class="ad__prod-sub">en cultivo</span>
        </div>

        <div class="ad__prod-card">
          <span class="ad__prod-label">Próxima cosecha</span>
          <span class="ad__prod-num" v-if="proximaCosechaDias !== null">{{ proximaCosechaDias }}d</span>
          <span class="ad__prod-sub">{{ proximaCosechaLabel }}</span>
        </div>

      </div>

      <!-- ── ZONA 4: Pendientes accionables (2 columnas) ────────────────── -->
      <div class="ad__body">

        <!-- Columna izquierda -->
        <div class="ad__col">

          <div class="ad__widget">
            <div class="ad__widget-hdr">
              <span class="ad__widget-title">Tareas de hoy</span>
              <span v-if="tareasHoy.length" class="ad__badge">{{ tareasHoy.length }}</span>
            </div>
            <template v-if="tareasHoy.length">
              <RouterLink
                v-for="t in tareasHoy.slice(0, 5)"
                :key="t.id"
                to="/tareas"
                class="ad__item"
              >
                <span class="ad__task-prio" :class="'ad__task-prio--' + t.prioridad">{{ prioLabel(t.prioridad) }}</span>
                <span class="ad__item-text">{{ t.titulo }}</span>
                <span v-if="isVencida(t)" class="ad__item-tag ad__item-tag--rojo">Vencida</span>
                <i class="bi bi-arrow-right ad__item-arrow"></i>
              </RouterLink>
              <p v-if="tareasHoy.length > 5" class="ad__item-more">y {{ tareasHoy.length - 5 }} más...</p>
            </template>
            <p v-else class="ad__empty">Sin tareas para hoy ✓</p>
            <RouterLink to="/tareas" class="ad__widget-cta">+ Nueva tarea</RouterLink>
          </div>

          <div class="ad__widget ad__widget--mt">
            <div class="ad__widget-hdr">
              <span class="ad__widget-title">Pacientes con atención</span>
              <span v-if="pacientesNecesitanAtencion" class="ad__badge ad__badge--amber">
                {{ (stats?.reprocann_vencidos || 0) + (stats?.reprocann_por_vencer || 0) }}
              </span>
            </div>
            <div v-if="stats?.reprocann_vencidos > 0" class="ad__item">
              <i class="bi bi-exclamation-triangle" style="color:#dc2626;font-size:.875rem;flex-shrink:0"></i>
              <span class="ad__item-text">{{ stats.reprocann_vencidos }} con REPROCANN vencido</span>
              <RouterLink to="/pacientes?reprocann=vencidos" class="ad__item-arrow"><i class="bi bi-arrow-right"></i></RouterLink>
            </div>
            <div v-if="stats?.reprocann_por_vencer > 0" class="ad__item">
              <i class="bi bi-clock" style="color:#d97706;font-size:.875rem;flex-shrink:0"></i>
              <span class="ad__item-text">{{ stats.reprocann_por_vencer }} por vencer (30 días)</span>
              <RouterLink to="/pacientes?reprocann=proximos" class="ad__item-arrow"><i class="bi bi-arrow-right"></i></RouterLink>
            </div>
            <p v-if="!pacientesNecesitanAtencion" class="ad__empty">Sin alertas de REPROCANN ✓</p>
          </div>

        </div>

        <!-- Columna derecha -->
        <div class="ad__col">

          <div class="ad__widget">
            <div class="ad__widget-hdr">
              <span class="ad__widget-title">Stocks para asignar</span>
              <span v-if="stocksPendientes.length" class="ad__badge">{{ stocksPendientes.length }}</span>
            </div>
            <template v-if="stocksPendientes.length">
              <RouterLink
                v-for="s in stocksPendientes.slice(0, 4)"
                :key="s.id"
                to="/admin/stocks/pendientes"
                class="ad__item"
              >
                <span class="ad__item-text">{{ s.forma_producto }} · {{ s.cantidad }}g</span>
                <span class="ad__item-meta">{{ s.lote?.codigo || `Lote #${s.lote_id}` }}</span>
                <i class="bi bi-arrow-right ad__item-arrow"></i>
              </RouterLink>
            </template>
            <p v-else class="ad__empty">Todo el stock está asignado ✓</p>
            <RouterLink to="/admin/stocks/pendientes" class="ad__widget-cta">Ver stock →</RouterLink>
          </div>

          <div class="ad__widget ad__widget--mt">
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
              <span class="ad__sede-nombre">{{ sede.nombre }}</span>
              <span class="ad__sede-tipo">{{ tipoLabel(sede.tipo) }}</span>
              <span class="ad__sede-info">
                <template v-if="(sede.salas_count || 0) > 0">{{ sede.salas_count }} sala{{ sede.salas_count !== 1 ? 's' : '' }}</template>
                <span v-else class="ad__sede-config">Configurar salas →</span>
              </span>
            </RouterLink>
            <p v-if="!sedes.length" class="ad__empty">Sin sedes configuradas</p>
          </div>

        </div>
      </div>

      <!-- ── ZONA 5: Gráfico + Actividad reciente ───────────────────────── -->
      <div class="ad__bottom">

        <div class="ad__chart-widget">
          <div class="ad__widget-hdr">
            <span class="ad__widget-title">Dispensaciones — últimos 7 días</span>
          </div>
          <div class="ad__chart-wrap">
            <canvas ref="chartCanvas" />
          </div>
        </div>

        <div class="ad__widget">
          <div class="ad__widget-hdr">
            <span class="ad__widget-title">Actividad reciente</span>
            <RouterLink to="/contabilidad" class="ad__widget-link">Ver libro →</RouterLink>
          </div>
          <template v-if="actividadReciente.length">
            <div v-for="m in actividadReciente" :key="m.id" class="ad__feed-item">
              <span class="ad__feed-ico">{{ m.tipo === 'ingreso' ? '💰' : '💸' }}</span>
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

    </template>
  </div>
</template>

<style scoped>
.ad {
  padding: 2rem;
  max-width: 1280px;
  margin: 0 auto;
}

.ad__loading {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: calc(100vh - 56px);
}

/* ── ZONA 1: Header ─────────────────────────────────────────────────────── */
.ad__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
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
  margin: .25rem 0 0;
}

.ad__header-actions {
  display: flex;
  gap: .625rem;
  align-items: center;
  flex-shrink: 0;
  padding-top: .25rem;
}

.ad__btn-quick {
  display: inline-flex;
  align-items: center;
  gap: .375rem;
  padding: .5rem .875rem;
  font-size: .8rem;
  font-weight: 600;
  border-radius: 8px;
  text-decoration: none;
  border: 1px solid #e2e8f0;
  color: #374151;
  background: #fff;
  transition: background .12s, border-color .12s;
}
.ad__btn-quick:hover { background: #f8fafc; border-color: #cbd5e1; }
.ad__btn-quick--primary {
  background: #16a34a;
  color: #fff;
  border-color: #16a34a;
}
.ad__btn-quick--primary:hover { background: #15803d; border-color: #15803d; }

/* ── ZONA 2: KPIs operativos ─────────────────────────────────────────────── */
.ad__kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
  margin-bottom: 1rem;
}

.ad__kpi {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 1.25rem 1.25rem 1rem;
  min-height: 110px;
  display: flex;
  flex-direction: column;
  gap: .35rem;
  transition: box-shadow .15s;
}
.ad__kpi:hover { box-shadow: 0 4px 16px rgba(0,0,0,.07); }
.ad__kpi--critico { border-color: #fca5a5; background: #fff5f5; }
.ad__kpi--bajo    { border-color: #fde68a; background: #fffbeb; }

.ad__kpi-label {
  font-size: .625rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #94a3b8;
}

.ad__kpi-num {
  font-size: 1.875rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1;
  font-family: var(--font-display);
}

.ad__kpi-sub {
  font-size: .75rem;
  color: #64748b;
  margin-top: .125rem;
}

.ad__kpi-link {
  color: #2563eb;
  text-decoration: none;
  font-size: .75rem;
}
.ad__kpi-link:hover { text-decoration: underline; }

.ad__delta--pos { color: #16a34a; font-weight: 600; }
.ad__delta--neg { color: #dc2626; font-weight: 600; }

/* ── ZONA 3: Producción ──────────────────────────────────────────────────── */
.ad__prod {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  margin-bottom: 1.75rem;
}

.ad__prod-card {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: .875rem 1rem;
  display: flex;
  flex-direction: column;
  gap: .2rem;
}

.ad__prod-label {
  font-size: .625rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #94a3b8;
}

.ad__prod-num {
  font-size: 1.5rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1.1;
  font-family: var(--font-display);
}
.ad__prod-num--empty { color: #cbd5e1; }

.ad__prod-sub {
  font-size: .72rem;
  color: #64748b;
}

/* ── ZONA 4: Pendientes ──────────────────────────────────────────────────── */
.ad__body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
  margin-bottom: 1.25rem;
}

.ad__col {
  display: flex;
  flex-direction: column;
}

.ad__widget {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
  flex: 1;
}

.ad__widget--mt { margin-top: 1rem; }

.ad__widget-hdr {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .875rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}

.ad__widget-title {
  font-size: .8rem;
  font-weight: 700;
  color: #374151;
  flex: 1;
}

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
  background: #fef2f2;
  color: #dc2626;
  border-radius: 99px;
  padding: .15em .5em;
}
.ad__badge--amber {
  background: #fffbeb;
  color: #d97706;
}

.ad__item {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .5rem 1rem;
  font-size: .8rem;
  color: #374151;
  text-decoration: none;
  transition: background .1s;
}
.ad__item:hover { background: #f8fafc; }

.ad__item-text {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ad__item-meta {
  font-size: .72rem;
  color: #94a3b8;
  flex-shrink: 0;
}

.ad__item-tag {
  font-size: .6rem;
  font-weight: 700;
  padding: .15em .45em;
  border-radius: 4px;
  flex-shrink: 0;
}
.ad__item-tag--rojo { background: #fef2f2; color: #dc2626; }

.ad__item-arrow {
  color: #cbd5e1;
  font-size: .75rem;
  flex-shrink: 0;
  text-decoration: none;
}

.ad__item-more {
  font-size: .75rem;
  color: #94a3b8;
  padding: .25rem 1rem;
  margin: 0;
}

.ad__task-prio {
  font-size: .6rem;
  font-weight: 700;
  padding: .15em .45em;
  border-radius: 4px;
  flex-shrink: 0;
}
.ad__task-prio--alta   { background: #fef2f2; color: #dc2626; }
.ad__task-prio--normal { background: #eff6ff; color: #2563eb; }
.ad__task-prio--baja   { background: #f8fafc; color: #64748b; }

.ad__empty {
  font-size: .8rem;
  color: #94a3b8;
  padding: .625rem 1rem;
  margin: 0;
}
.ad__empty--pad { padding: 1rem; }

/* Sedes */
.ad__sede-row {
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .5rem 1rem;
  text-decoration: none;
  color: inherit;
  border-bottom: 1px solid #f8fafc;
  transition: background .1s;
}
.ad__sede-row:last-child { border-bottom: none; }
.ad__sede-row:hover { background: #f8fafc; }

.ad__sede-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.ad__sede-nombre { font-size: .825rem; font-weight: 600; color: #0f172a; flex: 1; }
.ad__sede-tipo   { font-size: .7rem; color: #94a3b8; }
.ad__sede-info   { font-size: .75rem; color: #64748b; }
.ad__sede-config { color: #2563eb; font-size: .72rem; }

/* ── ZONA 5: Gráfico + Actividad ─────────────────────────────────────────── */
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
  height: 200px;
  padding: 1rem 1rem .75rem;
  position: relative;
}

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
.ad__feed-meta { display: block; font-size: .72rem; color: #94a3b8; margin-top: .1rem; }

/* ── Responsive ──────────────────────────────────────────────────────────── */
@media (max-width: 1200px) {
  .ad__bottom { grid-template-columns: 1fr; }
}

@media (max-width: 1023px) {
  .ad__kpis  { grid-template-columns: repeat(2, 1fr); }
  .ad__prod  { grid-template-columns: repeat(2, 1fr); }
  .ad__body  { grid-template-columns: 1fr; }
}

@media (max-width: 640px) {
  .ad          { padding: 1rem; }
  .ad__kpis    { grid-template-columns: repeat(2, 1fr); }
  .ad__prod    { grid-template-columns: repeat(2, 1fr); }
  .ad__kpi-num { font-size: 1.5rem; }
  .ad__header  { flex-direction: column; }
}
</style>
