<script setup>
import { ref, computed, reactive, onMounted, watch } from 'vue'
import { listSedes, getContableDashboard, listLotes } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import { useStatsStore } from '../../stores/stats.js'
import { useTareasStore } from '../../stores/tareas.js'
import OnboardingWizard from '../OnboardingWizard.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'

const auth       = useAuthStore()
const club       = useClubStore()
const statsStore = useStatsStore()
const tareasStore = useTareasStore()

const sedes = ref([])
const contable = ref(null)
const lotesManicuraPendiente = ref([])
const loading = ref(true)

const sections = reactive({ tareas: true, aprobaciones: true, pacientes: true })

const stats = computed(() => statsStore.data ?? {})
const mostrarOnboarding = computed(() => !loading.value && sedes.value.length === 0)

// Greeting
const hora = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const _hoy = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const hoy = _hoy.charAt(0).toUpperCase() + _hoy.slice(1)

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

// KPIs
const plantasEnCiclo = computed(() => (stats.value?.vegetativo || 0) + (stats.value?.floracion || 0))
const balanceMes = computed(() => contable.value?.mes_actual?.balance || 0)
const balancePositivo = computed(() => balanceMes.value >= 0)

// Sparkline
const sparklineData = computed(() => {
  const porMes = contable.value?.anio_actual?.por_mes
  if (!porMes?.length) return [0, 0, 0, 0, 0, 0]
  const last6 = [...porMes].slice(-6)
  while (last6.length < 6) last6.unshift({ balance: 0 })
  return last6.map(m => m.balance || 0)
})

function sparklinePath(values) {
  const W = 80, H = 28, P = 3
  const min = Math.min(...values)
  const max = Math.max(...values)
  const range = Math.max(max - min, 1)
  const n = values.length
  return values.map((v, i) => {
    const x = P + (i / (n - 1)) * (W - P * 2)
    const y = H - P - ((v - min) / range) * (H - P * 2)
    return `${i === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`
  }).join(' ')
}

// Zone 3 — usa tareasStore para reactividad en tiempo real cuando se completan tareas
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
  (contable.value?.ultimos_movimientos || []).slice(0, 8)
)

const pacientesNecesitanAtencion = computed(() =>
  (stats.value?.reprocann_vencidos || 0) + (stats.value?.reprocann_por_vencer || 0) > 0
)

onMounted(async () => {
  try {
    const [sedesRes, contableRes, manicuraRes] = await Promise.allSettled([
      listSedes(),
      getContableDashboard(),
      listLotes({ estado: 'manicura_pendiente' }),
    ])
    await Promise.allSettled([statsStore.fetchAll(), tareasStore.fetchDashboard()])
    if (sedesRes.status    === 'fulfilled') sedes.value                  = sedesRes.value.data   || []
    if (contableRes.status === 'fulfilled') contable.value               = contableRes.value.data
    if (manicuraRes.status === 'fulfilled') lotesManicuraPendiente.value = manicuraRes.value.data || []
  } finally {
    loading.value = false
  }
})

async function onOnboardingCompletado() {
  const res = await listSedes()
  sedes.value = res.data || []
}
</script>

<template>
  <div class="ad">
    <OnboardingWizard v-if="mostrarOnboarding" @completado="onOnboardingCompletado" />

    <!-- Loading -->
    <div v-if="loading" class="ad__loading">
      <DsSpinner />
    </div>

    <template v-else-if="!mostrarOnboarding">
      <!-- ZONA 1: Header -->
      <div class="ad__header">
        <div>
          <h1 class="ad__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
          <p class="ad__fecha">{{ hoy }}</p>
        </div>
      </div>

      <!-- ZONA 2: 5 KPI Cards -->
      <div class="ad__kpis">
        <!-- 1. Pacientes activos -->
        <div class="ad__kpi-card">
          <span class="ad__kpi-label">Pacientes activos</span>
          <div class="ad__kpi-num">{{ stats?.pacientes ?? 0 }}</div>
          <div class="ad__kpi-sub">{{ stats?.pacientes ?? 0 }} socios habilitados</div>
        </div>

        <!-- 2. Plantas en ciclo -->
        <div class="ad__kpi-card">
          <span class="ad__kpi-label">Plantas en ciclo</span>
          <div class="ad__kpi-num">{{ plantasEnCiclo }}</div>
          <div class="ad__kpi-sub">{{ stats?.vegetativo ?? 0 }} veg · {{ stats?.floracion ?? 0 }} flor</div>
        </div>

        <!-- 3. Sedes -->
        <div class="ad__kpi-card">
          <span class="ad__kpi-label">Sedes</span>
          <div class="ad__kpi-num">{{ sedes.length }}</div>
          <div class="ad__kpi-sub">
            <template v-for="sede in sedes" :key="sede.id">
              <span
                class="ad__kpi-dot"
                :style="{ background: sedeDot(sede) }"
                :title="sede.nombre"
              ></span>
            </template>
          </div>
        </div>

        <!-- 4. Dispensaciones hoy -->
        <!-- TODO: conectar endpoint /dispensaciones?fecha=hoy -->
        <div class="ad__kpi-card">
          <span class="ad__kpi-label">Dispensaciones hoy</span>
          <div class="ad__kpi-num">0</div>
          <div class="ad__kpi-sub">—</div>
        </div>

        <!-- 5. Balance del mes -->
        <div class="ad__kpi-card">
          <span class="ad__kpi-label">Balance del mes</span>
          <div class="ad__kpi-num" :style="{ color: balancePositivo ? '#16a34a' : '#dc2626' }">
            {{ fmtCompacto(balanceMes) }}
          </div>
          <div class="ad__kpi-sub">
            <svg width="80" height="28" viewBox="0 0 80 28" fill="none">
              <path
                :d="sparklinePath(sparklineData)"
                stroke="#16a34a"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </div>
        </div>
      </div>

      <!-- ZONA 3: Dos columnas -->
      <div class="ad__body">
        <!-- Col izquierda: Panel Mi día -->
        <div class="ad__col-left">
          <div class="ad__panel">
            <!-- Sección 1: Tareas de hoy -->
            <div class="ad__sec">
              <button class="ad__sec-hdr" @click="sections.tareas = !sections.tareas">
                <span class="ad__sec-title">Tareas de hoy</span>
                <span v-if="tareasHoy.length" class="ad__sec-badge">{{ tareasHoy.length }}</span>
                <i class="bi" :class="sections.tareas ? 'bi-chevron-up' : 'bi-chevron-down'" style="margin-left:auto;color:#94a3b8;font-size:.75rem"></i>
              </button>
              <div v-show="sections.tareas" class="ad__sec-body">
                <template v-if="tareasHoy.length">
                  <RouterLink
                    v-for="t in tareasHoy"
                    :key="t.id"
                    to="/tareas"
                    class="ad__task-item"
                  >
                    <span class="ad__task-prio" :class="'ad__task-prio--' + t.prioridad">{{ prioLabel(t.prioridad) }}</span>
                    <span class="ad__task-title">{{ t.titulo }}</span>
                    <span v-if="isVencida(t)" class="ad__task-vencida">Vencida</span>
                    <i class="bi bi-arrow-right ad__task-arrow"></i>
                  </RouterLink>
                </template>
                <p v-else class="ad__sec-empty">Sin tareas para hoy</p>
                <RouterLink to="/tareas" class="ad__sec-cta">+ Nueva tarea</RouterLink>
              </div>
            </div>

            <!-- Sección 2: Aprobaciones pendientes -->
            <div class="ad__sec">
              <button class="ad__sec-hdr" @click="sections.aprobaciones = !sections.aprobaciones">
                <span class="ad__sec-title">Aprobaciones pendientes</span>
                <span v-if="lotesManicuraPendiente.length" class="ad__sec-badge">{{ lotesManicuraPendiente.length }}</span>
                <i class="bi" :class="sections.aprobaciones ? 'bi-chevron-up' : 'bi-chevron-down'" style="margin-left:auto;color:#94a3b8;font-size:.75rem"></i>
              </button>
              <div v-show="sections.aprobaciones" class="ad__sec-body">
                <template v-if="lotesManicuraPendiente.length">
                  <RouterLink
                    v-for="l in lotesManicuraPendiente"
                    :key="l.id"
                    to="/aprobaciones"
                    class="ad__task-item"
                  >
                    <span>{{ l.codigo || l.cepa || 'Lote' }}</span>
                    <span class="ad__task-meta">Aprobación manicura</span>
                    <i class="bi bi-arrow-right ad__task-arrow"></i>
                  </RouterLink>
                </template>
                <p v-else class="ad__sec-empty">Todo al día ✓</p>
                <RouterLink to="/aprobaciones" class="ad__sec-cta ad__sec-cta--sm">Ver todas →</RouterLink>
              </div>
            </div>

            <!-- Sección 3: Pacientes con atención requerida -->
            <div class="ad__sec">
              <button class="ad__sec-hdr" @click="sections.pacientes = !sections.pacientes">
                <span class="ad__sec-title">Pacientes con atención</span>
                <span v-if="pacientesNecesitanAtencion" class="ad__sec-badge">
                  {{ (stats?.reprocann_vencidos || 0) + (stats?.reprocann_por_vencer || 0) }}
                </span>
                <i class="bi" :class="sections.pacientes ? 'bi-chevron-up' : 'bi-chevron-down'" style="margin-left:auto;color:#94a3b8;font-size:.75rem"></i>
              </button>
              <div v-show="sections.pacientes" class="ad__sec-body">
                <!-- TODO: conectar lista individual de pacientes con docs incompletas -->
                <div class="ad__task-item" v-if="stats?.reprocann_vencidos > 0">
                  <i class="bi bi-exclamation-triangle" style="color:#dc2626"></i>
                  <span>{{ stats.reprocann_vencidos }} con REPROCANN vencido</span>
                  <RouterLink to="/pacientes" class="ad__task-arrow-link"><i class="bi bi-arrow-right"></i></RouterLink>
                </div>
                <div class="ad__task-item" v-if="stats?.reprocann_por_vencer > 0">
                  <i class="bi bi-clock" style="color:#d97706"></i>
                  <span>{{ stats.reprocann_por_vencer }} con REPROCANN por vencer</span>
                  <RouterLink to="/pacientes" class="ad__task-arrow-link"><i class="bi bi-arrow-right"></i></RouterLink>
                </div>
                <p class="ad__sec-empty" v-if="!pacientesNecesitanAtencion">Sin pacientes pendientes ✓</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Col derecha: Sedes en vivo + Actividad reciente -->
        <div class="ad__col-right">
          <!-- Sedes en vivo -->
          <div class="ad__card ad__card--mb">
            <div class="ad__card-hdr">
              <span class="ad__card-title">Sedes en vivo</span>
              <RouterLink to="/sedes" class="ad__card-link">Ver todas →</RouterLink>
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
                <template v-if="(sede.salas_count || 0) > 0">
                  {{ sede.salas_count }} sala{{ sede.salas_count !== 1 ? 's' : '' }}
                </template>
                <span v-else class="ad__sede-config">Configurar salas →</span>
              </span>
            </RouterLink>
          </div>

          <!-- Actividad reciente -->
          <div class="ad__card ad__card--flex">
            <div class="ad__card-hdr">
              <span class="ad__card-title">Actividad reciente</span>
              <RouterLink to="/contabilidad" class="ad__card-link">Ver libro →</RouterLink>
            </div>

            <div v-if="actividadReciente.length" class="ad__feed">
              <div
                v-for="m in actividadReciente"
                :key="m.id"
                class="ad__feed-item"
              >
                <span class="ad__feed-ico">{{ m.tipo === 'ingreso' ? '💰' : '💸' }}</span>
                <div class="ad__feed-body">
                  <span class="ad__feed-desc">{{ m.descripcion || m.categoria }}</span>
                  <span class="ad__feed-meta">{{ fmtCompacto(m.monto_ars) }} · {{ timeAgo(m.created_at) }}</span>
                </div>
              </div>
            </div>

            <p v-else class="ad__feed-empty">
              Sin actividad registrada aún ·
              <RouterLink to="/contabilidad">Registrá el primer movimiento →</RouterLink>
            </p>
          </div>
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
  min-height: 200px;
}

/* Header */
.ad__header {
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
  text-transform: none;
}

/* KPIs */
.ad__kpis {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 1rem;
  margin-bottom: 1.75rem;
}

.ad__kpi-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 1.25rem 1.25rem 1rem;
  min-height: 120px;
  display: flex;
  flex-direction: column;
  gap: .375rem;
  transition: box-shadow .15s;
}

.ad__kpi-card:hover {
  box-shadow: 0 4px 16px rgba(0,0,0,.08);
}

.ad__kpi-label {
  font-size: .6rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #94a3b8;
}

.ad__kpi-num {
  font-size: 2rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1;
  font-family: var(--font-display);
}

.ad__kpi-sub {
  font-size: .75rem;
  color: #64748b;
  display: flex;
  align-items: center;
  gap: .5rem;
}

.ad__kpi-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
  flex-shrink: 0;
}

/* Body */
.ad__body {
  display: flex;
  gap: 1.25rem;
  align-items: flex-start;
}

.ad__col-left {
  flex: 0 0 40%;
  min-width: 0;
}

.ad__col-right {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* Panel Mi día */
.ad__panel {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
}

.ad__sec {
  border-bottom: 1px solid #f1f5f9;
}

.ad__sec:last-child {
  border-bottom: none;
}

.ad__sec-hdr {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .875rem 1rem;
  width: 100%;
  background: none;
  border: none;
  cursor: pointer;
  text-align: left;
}

.ad__sec-hdr:hover {
  background: #f8fafc;
}

.ad__sec-title {
  font-size: .8rem;
  font-weight: 700;
  color: #374151;
}

.ad__sec-badge {
  font-size: .6rem;
  font-weight: 700;
  background: #fef2f2;
  color: #dc2626;
  border-radius: 99px;
  padding: .1em .4em;
}

.ad__sec-body {
  padding: .5rem 0;
}

.ad__sec-empty {
  font-size: .8rem;
  color: #94a3b8;
  padding: .5rem 1rem;
}

.ad__sec-cta {
  display: block;
  font-size: .75rem;
  color: #64748b;
  padding: .5rem 1rem;
  text-decoration: none;
  border-top: 1px solid #f8fafc;
}

.ad__sec-cta--sm {
  font-size: .72rem;
}

/* Task items */
.ad__task-item {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .5rem 1rem;
  font-size: .8rem;
  color: #374151;
  text-decoration: none;
  border-radius: 0;
}

.ad__task-item:hover {
  background: #f8fafc;
}

.ad__task-prio {
  font-size: .6rem;
  font-weight: 700;
  padding: .15em .45em;
  border-radius: 4px;
  flex-shrink: 0;
}

.ad__task-prio--alta {
  background: #fef2f2;
  color: #dc2626;
}

.ad__task-prio--normal {
  background: #eff6ff;
  color: #2563eb;
}

.ad__task-prio--baja {
  background: #f8fafc;
  color: #64748b;
}

.ad__task-title {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ad__task-vencida {
  font-size: .7rem;
  color: #dc2626;
  font-weight: 600;
  flex-shrink: 0;
}

.ad__task-arrow,
.ad__task-arrow-link {
  color: #cbd5e1;
  font-size: .75rem;
  flex-shrink: 0;
}

.ad__task-meta {
  font-size: .72rem;
  color: #94a3b8;
  flex-shrink: 0;
}

/* Cards col derecha */
.ad__card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
}

.ad__card--mb {
  margin-bottom: 1rem;
}

.ad__card--flex {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.ad__card-hdr {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: .875rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}

.ad__card-title {
  font-size: .8rem;
  font-weight: 700;
  color: #374151;
}

.ad__card-link {
  font-size: .75rem;
  color: #64748b;
  text-decoration: none;
}

/* Sedes */
.ad__sede-row {
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .625rem 1rem;
  text-decoration: none;
  color: inherit;
  border-bottom: 1px solid #f8fafc;
}

.ad__sede-row:last-child {
  border-bottom: none;
}

.ad__sede-row:hover {
  background: #f8fafc;
}

.ad__sede-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.ad__sede-nombre {
  font-size: .825rem;
  font-weight: 600;
  color: #0f172a;
  flex: 1;
}

.ad__sede-tipo {
  font-size: .7rem;
  color: #94a3b8;
}

.ad__sede-info {
  font-size: .75rem;
  color: #64748b;
}

.ad__sede-config {
  color: #2563eb;
  font-size: .72rem;
}

/* Feed actividad */
.ad__feed {
  flex: 1;
  overflow-y: auto;
}

.ad__feed-item {
  display: flex;
  align-items: flex-start;
  gap: .75rem;
  padding: .625rem 1rem;
  border-bottom: 1px solid #f8fafc;
  font-size: .8rem;
}

.ad__feed-ico {
  flex-shrink: 0;
  font-size: 1rem;
  line-height: 1.5;
}

.ad__feed-body {
  flex: 1;
  min-width: 0;
}

.ad__feed-desc {
  display: block;
  color: #374151;
  font-weight: 500;
}

.ad__feed-meta {
  display: block;
  font-size: .72rem;
  color: #94a3b8;
  margin-top: .1rem;
}

.ad__feed-empty {
  font-size: .8rem;
  color: #94a3b8;
  padding: 1rem;
  margin: 0;
}

/* Responsive */
@media (max-width: 1023px) {
  .ad__kpis { grid-template-columns: repeat(3, 1fr); }
  .ad__body { flex-direction: column; }
  .ad__col-left { flex: none; width: 100%; }
}

@media (max-width: 640px) {
  .ad { padding: 1rem; }
  .ad__kpis { grid-template-columns: repeat(2, 1fr); }
  .ad__kpi-num { font-size: 1.5rem; }
}
</style>
