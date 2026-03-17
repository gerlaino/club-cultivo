<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">{{ saludo }}, {{ auth.displayName }}</h1>
        <p class="text-muted small mb-0 text-capitalize">{{ hoy }}</p>
      </div>
      <RouterLink to="/preferencias" class="btn btn-sm btn-outline-secondary">
        <i class="bi bi-gear me-1"></i>Preferencias
      </RouterLink>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.12)">🌱</div>
            <div class="kpi-value">{{ stats.vegetativo || 0 }}</div>
            <div class="kpi-label">Plantas vegetativo</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(255,193,7,.15)">🌸</div>
            <div class="kpi-value">{{ stats.floracion || 0 }}</div>
            <div class="kpi-label">Plantas floración</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(13,110,253,.1)">👥</div>
            <div class="kpi-value">{{ stats.socios || 0 }}</div>
            <div class="kpi-label">Socios activos</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(108,117,125,.1)">📦</div>
            <div class="kpi-value">{{ stats.lotes || 0 }}</div>
            <div class="kpi-label">Lotes activos</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Accesos rápidos -->
    <div class="row g-3 mb-4">
      <div class="col-12">
        <p class="fw-semibold text-muted small text-uppercase mb-2" style="letter-spacing:.05em">Accesos rápidos</p>
      </div>
      <div class="col-6 col-md-3">
        <RouterLink to="/salas" class="quick-card text-decoration-none">
          <span class="quick-icon">🏠</span>
          <span class="quick-label">Salas</span>
        </RouterLink>
      </div>
      <div class="col-6 col-md-3">
        <RouterLink to="/lotes" class="quick-card text-decoration-none">
          <span class="quick-icon">📦</span>
          <span class="quick-label">Lotes</span>
        </RouterLink>
      </div>
      <div class="col-6 col-md-3">
        <RouterLink to="/socios" class="quick-card text-decoration-none">
          <span class="quick-icon">👥</span>
          <span class="quick-label">Pacientes</span>
        </RouterLink>
      </div>
      <div class="col-6 col-md-3">
        <RouterLink to="/usuarios" class="quick-card text-decoration-none">
          <span class="quick-icon">🔑</span>
          <span class="quick-label">Usuarios</span>
        </RouterLink>
      </div>
    </div>

    <!-- Gráficos -->
    <div class="row g-3 mb-4">
      <div class="col-12 col-lg-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>Distribución de plantas por estado</strong>
          </div>
          <div class="card-body">
            <div v-if="loading" class="text-center py-4 text-muted">
              <div class="spinner-border spinner-border-sm"></div>
            </div>
            <PlantDistributionChart v-else :data="stats" />
          </div>
        </div>
      </div>

      <div class="col-12 col-lg-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>Plantas por genética</strong>
          </div>
          <div class="card-body">
            <div v-if="loading" class="text-center py-4 text-muted">
              <div class="spinner-border spinner-border-sm"></div>
            </div>
            <div v-else-if="!plantasPorGenetica.length" class="text-center py-4 text-muted">
              <div class="fs-2 mb-2">🌿</div>
              <div class="small">Sin datos de genéticas todavía</div>
            </div>
            <PlantsByGeneticaChart v-else :data="plantasPorGenetica" />
          </div>
        </div>
      </div>
    </div>

    <!-- Alertas + resumen -->
    <div class="row g-3">
      <div class="col-12 col-lg-6">
        <div class="card border-0 shadow-sm">
          <div class="card-header bg-transparent border-0 pt-3 pb-0 d-flex align-items-center justify-content-between">
            <strong>⚠️ Reprocann por vencer</strong>
            <span class="badge" :class="stats.vencimientos > 0 ? 'text-bg-warning' : 'text-bg-success'">
              {{ stats.vencimientos || 0 }}
            </span>
          </div>
          <div class="card-body">
            <div v-if="!stats.vencimientos" class="text-center py-3 text-muted small">
              <i class="bi bi-check-circle text-success fs-4 d-block mb-1"></i>
              Sin vencimientos próximos
            </div>
            <div v-else class="small text-muted">
              <span class="text-warning fw-semibold">{{ stats.vencimientos }}</span>
              {{ stats.vencimientos === 1 ? 'socio tiene' : 'socios tienen' }}
              Reprocann venciendo en los próximos 30 días.
              <RouterLink to="/socios" class="ms-1 text-decoration-none">Ver socios →</RouterLink>
            </div>
          </div>
        </div>
      </div>

      <div class="col-12 col-lg-6">
        <div class="card border-0 shadow-sm">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>📊 Resumen general</strong>
          </div>
          <div class="card-body small">
            <dl class="row mb-0">
              <dt class="col-7 fw-normal text-muted">Total plantas activas</dt>
              <dd class="col-5 fw-semibold">{{ stats.plantas || 0 }}</dd>
              <dt class="col-7 fw-normal text-muted">Total salas</dt>
              <dd class="col-5 fw-semibold">{{ stats.salas || 0 }}</dd>
              <dt class="col-7 fw-normal text-muted">Plantas en secado</dt>
              <dd class="col-5 fw-semibold">{{ stats.secado || 0 }}</dd>
              <dt class="col-7 fw-normal text-muted">Socios totales</dt>
              <dd class="col-5 fw-semibold mb-0">{{ stats.socios || 0 }}</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import api from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import PlantDistributionChart from '../charts/PlantDistributionChart.vue'
import PlantsByGeneticaChart from '../charts/PlantsByGeneticaChart.vue'

const auth    = useAuthStore()
const stats   = ref({})
const loading = ref(true)

const plantasPorGenetica = computed(() => stats.value.plantas_por_genetica || [])

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })

onMounted(async () => {
  try {
    const { data } = await api.get('/stats')
    stats.value = data
  } catch (e) {
    console.error('Error cargando stats:', e)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.kpi .card-body { padding: 1.25rem 1.5rem; }
.kpi-icon {
  width: 44px; height: 44px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.4rem;
}
.kpi-value { font-size: 2rem; font-weight: 700; line-height: 1; color: #1f2937; }
.kpi-label { font-size: .85rem; color: #6b7280; margin-top: .2rem; }

.quick-card {
  display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: .5rem; padding: 1.5rem 1rem;
  background: white; border: 1.5px solid rgba(0,0,0,.06);
  border-radius: 1rem; color: #374151; transition: all .15s;
}
.quick-card:hover {
  border-color: var(--brand-primary, #1b5e20);
  color: var(--brand-primary, #1b5e20);
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(27,94,32,.12);
}
.quick-icon { font-size: 2rem; }
.quick-label { font-size: .9rem; font-weight: 600; }
</style>
