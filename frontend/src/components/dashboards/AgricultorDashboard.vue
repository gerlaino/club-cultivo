<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="mb-4">
      <h1 class="h3 fw-bold mb-0">Panel de cultivo</h1>
      <p class="text-muted small mb-0">Bienvenido, {{ auth.displayName }} · {{ hoy }}</p>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.12)">🌱</div>
            <div class="kpi-value">{{ stats.vegetativo || 0 }}</div>
            <div class="kpi-label">Vegetativo</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(255,193,7,.15)">🌸</div>
            <div class="kpi-value">{{ stats.floracion || 0 }}</div>
            <div class="kpi-label">Floración</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(23,162,184,.12)">🍂</div>
            <div class="kpi-value">{{ stats.secado || 0 }}</div>
            <div class="kpi-label">Secado</div>
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
        <RouterLink to="/plantas" class="quick-card text-decoration-none">
          <span class="quick-icon">🌿</span>
          <span class="quick-label">Plantas</span>
        </RouterLink>
      </div>
      <div class="col-6 col-md-3">
        <RouterLink to="/geneticas" class="quick-card text-decoration-none">
          <span class="quick-icon">🧬</span>
          <span class="quick-label">Genéticas</span>
        </RouterLink>
      </div>
    </div>

    <!-- Gráfico distribución -->
    <div class="row g-3">
      <div class="col-12 col-lg-6">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-0 pt-3 pb-0">
            <strong>Distribución de plantas</strong>
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
            <strong>📊 Resumen del cultivo</strong>
          </div>
          <div class="card-body small">
            <dl class="row mb-0">
              <dt class="col-7 fw-normal text-muted">Total plantas activas</dt>
              <dd class="col-5 fw-semibold">{{ (stats.vegetativo || 0) + (stats.floracion || 0) + (stats.secado || 0) }}</dd>

              <dt class="col-7 fw-normal text-muted">Salas disponibles</dt>
              <dd class="col-5 fw-semibold">{{ stats.salas || 0 }}</dd>

              <dt class="col-7 fw-normal text-muted">Plantas en floración</dt>
              <dd class="col-5 fw-semibold mb-0">{{ stats.floracion || 0 }}</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import PlantDistributionChart from '../charts/PlantDistributionChart.vue'

const auth    = useAuthStore()
const stats   = ref({})
const loading = ref(true)

const hoy = new Date().toLocaleDateString('es-AR', { weekday:'long', day:'numeric', month:'long' })

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
.kpi .card-body {
  padding: 1.25rem 1.5rem;
}
.kpi-icon {
  width: 44px; height: 44px;
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.4rem;
}
.kpi-value {
  font-size: 2rem;
  font-weight: 700;
  line-height: 1;
  color: #1f2937;
}
.kpi-label {
  font-size: .85rem;
  color: #6b7280;
  margin-top: .2rem;
}

.quick-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: .5rem;
  padding: 1.5rem 1rem;
  background: white;
  border: 1.5px solid rgba(0,0,0,.06);
  border-radius: 1rem;
  color: #374151;
  transition: all .15s;
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
