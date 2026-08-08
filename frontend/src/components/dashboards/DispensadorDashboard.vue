<template>
  <div class="dd">
    <!-- Header -->
    <div class="dd__header">
      <div class="dd__greeting">
        <h1 class="dd__title">{{ saludo }}, {{ auth.user?.first_name || auth.displayName }}</h1>
        <p class="dd__subtitle">{{ fechaHoy }}</p>
      </div>
      <!-- ?nueva=1: abre el flujo directo. Sin esto llevaba al historial y había que apretar
           "Nueva dispensación" otra vez — dos clicks para lo que este rol hace todo el día. -->
      <RouterLink to="/historial?nueva=1" class="dd__cta">
        <PackagePlus :size="16" :stroke-width="1.75" />
        Nueva dispensación
      </RouterLink>
    </div>

    <!-- Banner: reservas vencidas sin preparar -->
    <RouterLink v-if="!loading && reservasVencidas > 0" to="/reservas" class="dd__banner-alert">
      <i class="bi bi-exclamation-triangle-fill"></i>
      <span>Tenés <strong>{{ reservasVencidas }}</strong> reserva{{ reservasVencidas !== 1 ? 's' : '' }} vencida{{ reservasVencidas !== 1 ? 's' : '' }} sin preparar</span>
      <span class="dd__banner-arrow">Ir a reservas →</span>
    </RouterLink>

    <!-- KPIs periodo -->
    <div class="dd__kpis">
      <div class="dd__kpi-card">
        <div class="dd__kpi-label">Dispensaciones hoy</div>
        <div class="dd__kpi-val">{{ loading ? '…' : (analytics?.resumen?.dispensaciones_hoy ?? '—') }}</div>
        <div class="dd__kpi-sub">{{ loading ? '' : `${formatG(analytics?.resumen?.gramos_hoy)} dispensados` }}</div>
      </div>
      <div class="dd__kpi-card">
        <div class="dd__kpi-label">Esta semana</div>
        <div class="dd__kpi-val">{{ loading ? '…' : (analytics?.resumen?.dispensaciones_semana ?? '—') }}</div>
        <div class="dd__kpi-sub">{{ loading ? '' : `${formatG(analytics?.resumen?.gramos_semana)}` }}</div>
      </div>
      <div class="dd__kpi-card">
        <div class="dd__kpi-label">Este mes</div>
        <div class="dd__kpi-val">{{ loading ? '…' : (analytics?.resumen?.dispensaciones_mes ?? '—') }}</div>
        <div class="dd__kpi-sub">{{ loading ? '' : `${formatG(analytics?.resumen?.gramos_mes)}` }}</div>
      </div>
      <div class="dd__kpi-card" :class="{ 'dd__kpi-card--warn': reprocannAlerta }">
        <div class="dd__kpi-label">REPROCANN</div>
        <div class="dd__kpi-val">{{ loading ? '…' : ((analytics?.reprocann?.vencidos ?? 0) + (analytics?.reprocann?.por_vencer ?? 0)) }}</div>
        <div class="dd__kpi-sub dd__kpi-sub--warn" v-if="!loading && reprocannAlerta">
          {{ analytics.reprocann.vencidos }} vencidos · {{ analytics.reprocann.por_vencer }} por vencer
        </div>
        <div class="dd__kpi-sub" v-else-if="!loading">pacientes con atención requerida</div>
      </div>
      <div class="dd__kpi-card" :class="{ 'dd__kpi-card--warn': reservasVencidas > 0 }">
        <div class="dd__kpi-label">Reservas para hoy</div>
        <div class="dd__kpi-val">{{ loading ? '…' : reservasHoy }}</div>
        <div class="dd__kpi-sub dd__kpi-sub--warn" v-if="!loading && reservasVencidas > 0">+ {{ reservasVencidas }} vencida{{ reservasVencidas !== 1 ? 's' : '' }}</div>
        <div class="dd__kpi-sub" v-else-if="!loading">para preparar</div>
      </div>
    </div>

    <!-- Reservas para preparar -->
    <div v-if="!loading && reservasLista.length" class="dd__section">
      <div class="dd__section-head">
        <h2 class="dd__section-title">Reservas para preparar</h2>
        <RouterLink to="/reservas" class="dd__section-link">Ver todas →</RouterLink>
      </div>
      <div class="dd__reservas">
        <RouterLink
          v-for="r in reservasLista" :key="r.id"
          to="/reservas"
          class="dd__reserva"
          :class="{ 'dd__reserva--vencida': r.vencida }"
        >
          <div class="dd__reserva-main">
            <div class="dd__reserva-nombre">{{ r.paciente }}</div>
            <div class="dd__reserva-prod">{{ formatG(r.cantidad) }} · {{ formaLabel(r.forma_producto) }}</div>
          </div>
          <div class="dd__reserva-side">
            <div class="dd__reserva-fecha" :class="{ 'dd__reserva-fecha--vencida': r.vencida }">
              <i v-if="r.vencida" class="bi bi-exclamation-circle"></i>
              {{ r.vencida ? 'Venció ' : '' }}{{ fmtFechaReserva(r.fecha) }}
            </div>
            <div v-if="r.resta_ars > 0" class="dd__reserva-resta">Resta {{ fmtARS(r.resta_ars) }}</div>
            <div v-else class="dd__reserva-pago">Señada ✓</div>
          </div>
        </RouterLink>
      </div>
    </div>

    <!-- Stock por producto -->
    <div class="dd__section">
      <div class="dd__section-head">
        <h2 class="dd__section-title">Stock disponible</h2>
        <RouterLink to="/stock" class="dd__section-link">Ver detalle →</RouterLink>
      </div>
      <div v-if="loading" class="dd__stock-grid">
        <div class="dd__stock-card dd__skeleton" v-for="n in 4" :key="n" />
      </div>
      <div v-else-if="!analytics?.stocks?.length" class="dd__empty">Sin stock disponible en sedes.</div>
      <div v-else class="dd__stock-grid">
        <div
          v-for="s in analytics.stocks"
          :key="s.forma"
          class="dd__stock-card"
          :class="{ 'dd__stock-card--warn': s.alerta }"
        >
          <!-- El backend manda el enum crudo (`flor_seca`): se muestra con su etiqueta humana. -->
          <div class="dd__stock-forma">{{ formaLabel(s.forma) }}</div>
          <div class="dd__stock-cantidad">{{ formatG(s.cantidad_g) }}</div>
          <div v-if="s.alerta" class="dd__stock-alerta">⚠ Stock bajo</div>
        </div>
      </div>
    </div>

    <!-- Top pacientes del mes -->
    <div class="dd__section">
      <h2 class="dd__section-title">Top pacientes — mes actual</h2>
      <div v-if="loading" class="dd__table-wrap">
        <div class="dd__skeleton" v-for="n in 5" :key="n" style="height:36px;margin-bottom:4px;" />
      </div>
      <div v-else-if="!analytics?.top_pacientes?.length" class="dd__empty">Sin dispensaciones este mes.</div>
      <div v-else class="dd__table-wrap">
        <table class="dd__table">
          <thead>
            <tr>
              <th>#</th>
              <th>Paciente</th>
              <th>DNI</th>
              <th class="dd__th-r">Dispensaciones</th>
              <th class="dd__th-r">Total gramos</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(p, i) in analytics.top_pacientes" :key="i">
              <td class="dd__td-rank">{{ i + 1 }}</td>
              <td class="dd__td-name">{{ p.paciente || p.iniciales }}</td>
              <td class="dd__td-mono">…{{ p.dni_last4 }}</td>
              <td class="dd__td-r">{{ p.dispens_count }}</td>
              <td class="dd__td-r dd__td-bold">{{ formatG(p.total_g) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Última actividad -->
    <div class="dd__section">
      <div class="dd__section-head">
        <h2 class="dd__section-title">Última actividad (hoy)</h2>
        <RouterLink to="/historial" class="dd__section-link">Ver historial →</RouterLink>
      </div>
      <div v-if="loadingDisps" class="dd__empty">Cargando…</div>
      <div v-else-if="!dispensaciones.length" class="dd__empty">Sin dispensaciones hoy.</div>
      <div v-else class="dd__table-wrap">
        <table class="dd__table">
          <thead>
            <tr>
              <th>Hora</th>
              <th>Paciente</th>
              <th>Producto</th>
              <th class="dd__th-r">Cantidad</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in dispensaciones.slice(0, 8)" :key="d.id">
              <td class="dd__td-mono">{{ formatHora(d.created_at) }}</td>
              <td>{{ d.paciente_nombre }}</td>
              <td>{{ d.stock?.forma_producto ?? '—' }}</td>
              <td class="dd__td-r">{{ d.cantidad }}{{ d.stock?.unidad ?? '' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore }     from '../../stores/auth.js'
import { listDispensacionesFecha, getAnalyticsDispensador } from '../../lib/api.js'
import DsStat               from '../../design-system/components/Stat.vue'
import { PackagePlus }      from 'lucide-vue-next'

const auth = useAuthStore()

const loading      = ref(true)
const loadingDisps = ref(true)
const analytics    = ref(null)
const dispensaciones = ref([])

const hora    = new Date().getHours()
const saludo  = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy     = new Date()
const fechaHoy = (() => { const s = hoy.toLocaleDateString('es-AR', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }); return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() })()
const fechaParam = hoy.toISOString().slice(0, 10)

const reprocannAlerta = computed(() => {
  const r = analytics.value?.reprocann
  return r && (r.vencidos > 0 || r.por_vencer > 0)
})

function formatG(g) { return g != null ? `${Number(g).toLocaleString('es-AR')} g` : '—' }

// ── Reservas para preparar ────────────────────────────────────────────────
const reservasHoy      = computed(() => analytics.value?.reservas?.hoy ?? 0)
const reservasVencidas = computed(() => analytics.value?.reservas?.vencidas ?? 0)
const reservasLista    = computed(() => analytics.value?.reservas?.lista ?? [])

const FORMA_LABEL = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura',
  crema: 'Crema', capsula: 'Cápsula', comestible: 'Comestible', prensado: 'Prensado',
  preroll: 'Preroll', externo: 'Externo', otro: 'Otro',
}
function formaLabel(f) { return FORMA_LABEL[f] || f || '—' }
function fmtFechaReserva(f) {
  if (!f) return '—'
  return new Date(f + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: 'short' })
}
function fmtARS(n) { return '$' + (Number(n) || 0).toLocaleString('es-AR') }

function formatHora(ts) {
  if (!ts) return '—'
  return new Date(ts).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  try {
    const [aRes, dRes] = await Promise.all([
      getAnalyticsDispensador(),
      listDispensacionesFecha({ fecha: fechaParam }),
    ])
    analytics.value      = aRes.data
    dispensaciones.value = dRes.data.dispensaciones ?? []
  } catch {
    // silenciar
  } finally {
    loading.value      = false
    loadingDisps.value = false
  }
})
</script>

<style scoped>
.dd {
  padding: var(--sp-6) var(--sp-8);
  max-width: 960px;
}
@media (max-width: 767px) { .dd { padding: var(--sp-4); } }

/* Header */
.dd__header { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--sp-4); margin-bottom: var(--sp-6); flex-wrap: wrap; }
.dd__title { font-family: var(--font-display); font-size: var(--fs-24); font-weight: 600; color: var(--c-ink-900); margin: 0; }
.dd__subtitle { font-size: var(--fs-13); color: var(--c-ink-500); margin: var(--sp-1) 0 0; }
.dd__cta { display: inline-flex; align-items: center; gap: var(--sp-2); background: var(--c-role-dispensador); color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 8px; font-size: var(--fs-14); font-weight: 600; cursor: pointer; text-decoration: none; white-space: nowrap; transition: opacity .15s; }
.dd__cta:hover { opacity: .88; }

/* KPIs */
.dd__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: var(--sp-4); margin-bottom: var(--sp-6); }
@media (max-width: 900px) { .dd__kpis { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 480px) { .dd__kpis { grid-template-columns: 1fr 1fr; gap: var(--sp-3); } }
.dd__kpi-card { background: #fff; border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); }
.dd__kpi-card--warn { border-color: #fca5a5; background: #fff5f5; }
.dd__kpi-label { font-size: var(--fs-11); font-weight: 600; color: var(--c-ink-400); text-transform: uppercase; letter-spacing: .05em; margin-bottom: var(--sp-1); }
.dd__kpi-val { font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.dd__kpi-sub { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.dd__kpi-sub--warn { color: #dc2626; font-weight: 600; }

/* Sections */
.dd__section { margin-bottom: var(--sp-6); }
.dd__section-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-3); }
.dd__section-title { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.dd__section-link { font-size: var(--fs-13); color: var(--c-ink-500); text-decoration: none; }
.dd__section-link:hover { color: var(--c-ink-900); }

/* Banner reservas vencidas */
.dd__banner-alert {
  display: flex; align-items: center; gap: var(--sp-2); margin-bottom: var(--sp-4);
  padding: var(--sp-3) var(--sp-4); border-radius: var(--r-md);
  background: #fff5f5; border: 1.5px solid #fca5a5; color: #991b1b;
  font-size: var(--fs-14); text-decoration: none;
}
.dd__banner-alert:hover { background: #fef2f2; }
.dd__banner-arrow { margin-left: auto; font-weight: 700; white-space: nowrap; }

/* Reservas para preparar */
.dd__reservas { display: flex; flex-direction: column; gap: var(--sp-2); }
.dd__reserva {
  display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4); border-radius: var(--r-md);
  background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100, #e2e8f0);
  text-decoration: none; color: inherit; transition: border-color .15s, box-shadow .15s;
}
.dd__reserva:hover { border-color: var(--c-leaf-400, #86efac); box-shadow: 0 1px 6px rgba(0,0,0,.06); }
.dd__reserva--vencida { border-left: 3px solid #ef4444; }
.dd__reserva-nombre { font-weight: 700; color: var(--c-ink-900, #0f172a); font-size: var(--fs-14); }
.dd__reserva-prod { font-size: var(--fs-13); color: var(--c-ink-500, #64748b); margin-top: 1px; }
.dd__reserva-side { text-align: right; white-space: nowrap; }
.dd__reserva-fecha { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-700, #334155); }
.dd__reserva-fecha--vencida { color: #dc2626; }
.dd__reserva-resta { font-size: var(--fs-12); color: #b45309; margin-top: 1px; }
.dd__reserva-pago { font-size: var(--fs-12); color: #15803d; margin-top: 1px; }

/* Stock grid */
.dd__stock-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: var(--sp-3); }
.dd__stock-card { background: #fff; border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); }
.dd__stock-card--warn { border-color: #fca5a5; background: #fff5f5; }
.dd__stock-forma { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-500); text-transform: uppercase; letter-spacing: .04em; margin-bottom: var(--sp-1); }
.dd__stock-cantidad { font-size: var(--fs-22); font-weight: 800; color: var(--c-ink-900); }
.dd__stock-alerta { font-size: var(--fs-11); font-weight: 700; color: #dc2626; margin-top: var(--sp-1); }

/* Table */
.dd__empty { color: var(--c-ink-400); font-size: var(--fs-14); padding: var(--sp-4); background: var(--c-ink-50); border-radius: var(--r-md); }
.dd__table-wrap { overflow-x: auto; }
.dd__table { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.dd__table th { text-align: left; font-size: var(--fs-11); font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-400); padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-100); }
.dd__th-r { text-align: right; }
.dd__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.dd__td-r { text-align: right; }
.dd__td-bold { font-weight: 700; }
.dd__td-mono { font-family: monospace; font-size: var(--fs-12); }
.dd__td-rank { font-weight: 800; color: var(--c-ink-400); font-size: var(--fs-12); }
.dd__td-name { font-weight: 600; }
.dd__skeleton { background: var(--c-ink-100); border-radius: var(--r-md); animation: dd-pulse 1.2s ease infinite; }
@keyframes dd-pulse { 0%,100%{opacity:1} 50%{opacity:.4} }
</style>
