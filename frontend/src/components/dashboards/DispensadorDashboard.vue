<template>
  <div class="dd">
    <!-- Header -->
    <div class="dd__header">
      <div class="dd__greeting">
        <h1 class="dd__title">Bienvenido, {{ auth.user?.first_name || auth.displayName }}</h1>
        <p class="dd__subtitle">{{ fechaHoy }}</p>
      </div>
      <RouterLink to="/dispensar" class="dd__cta">
        <PackagePlus :size="16" :stroke-width="1.75" />
        Nueva dispensación
      </RouterLink>
    </div>

    <!-- KPIs -->
    <div class="dd__kpis">
      <div class="dd__kpi-card">
        <DsStat label="Dispensaciones hoy" :value="loading ? '…' : kpis.dispensacionesHoy" />
      </div>
      <div class="dd__kpi-card">
        <DsStat
          label="Aporte socios hoy"
          :value="loading ? '…' : formatARS(kpis.aporteHoy)"
          tone="role-dispensador"
        />
      </div>
      <div class="dd__kpi-card">
        <DsStat label="Productos disponibles" :value="loading ? '…' : kpis.productosDisponibles" />
      </div>
      <div class="dd__kpi-card">
        <DsStat label="Pacientes activos" :value="loading ? '…' : kpis.pacientesActivos" />
      </div>
    </div>

    <!-- Última actividad -->
    <div class="dd__section">
      <h2 class="dd__section-title">Última actividad</h2>

      <div v-if="loading" class="dd__table-wrap">
        <div class="dd__skeleton" v-for="n in 5" :key="n" />
      </div>

      <div v-else-if="!dispensaciones.length" class="dd__empty">
        Sin dispensaciones hoy.
      </div>

      <div v-else class="dd__table-wrap">
        <table class="dd__table">
          <thead>
            <tr>
              <th>Hora</th>
              <th>Paciente</th>
              <th>Producto</th>
              <th class="dd__th-num">Cantidad</th>
              <th class="dd__th-num">Total</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="d in dispensaciones.slice(0, 10)" :key="d.id">
              <td class="dd__td-mono">{{ formatHora(d.created_at) }}</td>
              <td>{{ d.paciente_nombre }}</td>
              <td>{{ d.stock?.forma_producto ?? '—' }}</td>
              <td class="dd__td-num">{{ d.cantidad }}{{ d.stock?.unidad ?? '' }}</td>
              <td class="dd__td-num dd__td-monto">{{ formatARS(d.aporte_socio_ars) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth.js'
import { listDispensacionesFecha, listPacientes, listStocks } from '../../lib/api.js'
import DsStat from '../../design-system/components/Stat.vue'
import { PackagePlus } from 'lucide-vue-next'

const auth = useAuthStore()

const loading        = ref(true)
const dispensaciones = ref([])
const totalPacientes = ref(0)
const totalStocks    = ref(0)

const hoy = new Date()
const fechaHoy = (() => { const s = hoy.toLocaleDateString('es-AR', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }); return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() })()
const fechaParam = hoy.toISOString().slice(0, 10)

const kpis = computed(() => {
  const d = dispensaciones.value
  return {
    dispensacionesHoy:   d.length,
    aporteHoy:           d.reduce((s, x) => s + (x.aporte_socio_ars ?? 0), 0),
    productosDisponibles: totalStocks.value,
    pacientesActivos:    totalPacientes.value,
  }
})

function formatARS(n) {
  if (n == null) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n)
}

function formatHora(ts) {
  if (!ts) return '—'
  return new Date(ts).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  try {
    const [dRes, pRes, sRes] = await Promise.all([
      listDispensacionesFecha({ fecha: fechaParam }),
      listPacientes({ limite: 1 }),
      listStocks(),
    ])
    dispensaciones.value = dRes.data.dispensaciones ?? []
    totalPacientes.value = pRes.data?.meta?.total ?? pRes.data?.data?.length ?? 0
    totalStocks.value    = (Array.isArray(sRes.data) ? sRes.data : []).filter(s => s.cantidad > 0).length
  } catch {
    // silenciar — los KPIs mostrarán 0
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.dd {
  padding: var(--sp-6) var(--sp-8);
  max-width: 960px;
}

/* Header */
.dd__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-6);
}
.dd__title {
  font-family: var(--font-display);
  font-size: var(--fs-24);
  font-weight: 600;
  color: var(--c-ink-900);
  margin: 0;
}
.dd__subtitle {
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  margin: var(--sp-1) 0 0;
  text-transform: capitalize;
}
.dd__cta {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-role-dispensador);
  color: #fff;
  border: none;
  padding: .55rem 1.1rem;
  border-radius: 8px;
  font-size: var(--fs-14);
  font-weight: 600;
  cursor: pointer;
  text-decoration: none;
  white-space: nowrap;
  transition: opacity .15s;
}
.dd__cta:hover { opacity: .88; }

/* KPIs */
.dd__kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--sp-4);
  margin-bottom: var(--sp-6);
}
.dd__kpi-card {
  background: #fff;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  padding: var(--sp-5);
}

/* Section */
.dd__section-title {
  font-size: var(--fs-15);
  font-weight: 700;
  color: var(--c-ink-900);
  margin: 0 0 var(--sp-4);
}

/* Table */
.dd__table-wrap { overflow-x: auto; }
.dd__table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-14);
}
.dd__table th {
  text-align: left;
  font-size: var(--fs-12);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--c-ink-500);
  padding: var(--sp-2) var(--sp-3);
  border-bottom: 2px solid var(--c-ink-300);
}
.dd__table td {
  padding: var(--sp-3);
  border-bottom: 1px solid var(--c-ink-100);
  color: var(--c-ink-900);
}
.dd__table tr:last-child td { border-bottom: none; }
.dd__table tr:hover td { background: var(--c-leaf-50); }
.dd__td-mono { font-family: var(--font-mono); font-size: var(--fs-13); }
.dd__th-num, .dd__td-num { text-align: right; }
.dd__td-monto { font-weight: 600; color: var(--c-role-dispensador); }

/* Empty */
.dd__empty { font-size: var(--fs-14); color: var(--c-ink-500); padding: var(--sp-4) 0; }

/* Skeleton */
.dd__skeleton {
  height: 44px;
  background: var(--c-ink-100);
  border-radius: var(--r-md);
  margin-bottom: var(--sp-2);
  animation: pulse 1.4s ease-in-out infinite;
}
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

/* Responsive */
@media (max-width: 767px) {
  .dd { padding: var(--sp-4); }
  .dd__kpis { grid-template-columns: repeat(2, 1fr); }
  .dd__header { flex-direction: column; }
}
</style>
