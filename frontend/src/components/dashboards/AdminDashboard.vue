<template>
  <div class="admin-dashboard">
    <!-- Métricas principales -->
    <div class="row g-3 mb-4">
      <div class="col-md-3">
        <div class="stat-card bg-success text-white">
          <div class="stat-icon">
            <i class="bi bi-people-fill"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.socios || 0 }}</div>
            <div class="stat-label">Socios Activos</div>
          </div>
        </div>
      </div>

      <div class="col-md-3">
        <div class="stat-card bg-primary text-white">
          <div class="stat-icon">
            <i class="bi bi-flower2"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.plantas || 0 }}</div>
            <div class="stat-label">Plantas Activas</div>
          </div>
        </div>
      </div>

      <div class="col-md-3">
        <div class="stat-card bg-info text-white">
          <div class="stat-icon">
            <i class="bi bi-door-open"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.salas || 0 }}</div>
            <div class="stat-label">Salas</div>
          </div>
        </div>
      </div>

      <div class="col-md-3">
        <div class="stat-card bg-warning text-white">
          <div class="stat-icon">
            <i class="bi bi-box-seam"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.lotes || 0 }}</div>
            <div class="stat-label">Lotes Activos</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Gráficos -->
    <div class="row g-3 mt-2">
      <div class="col-lg-6">
        <div class="card h-100">
          <div class="card-header">
            <h6 class="mb-0">
              <i class="bi bi-pie-chart me-2"></i>
              Distribución de Plantas por Estado
            </h6>
          </div>
          <div class="card-body">
            <PlantDistributionChart :data="stats" />
          </div>
        </div>
      </div>

      <div class="col-lg-6">
        <div class="card h-100">
          <div class="card-header">
            <h6 class="mb-0">
              <i class="bi bi-activity me-2"></i>
              Actividad Reciente
            </h6>
          </div>
          <div class="card-body">
            <div v-if="actividad.length === 0" class="text-center text-muted py-4">
              <i class="bi bi-inbox display-4"></i>
              <p class="mt-2 mb-0">No hay actividad reciente</p>
            </div>
            <div v-else class="list-group list-group-flush">
              <div
                v-for="item in actividad"
                :key="item.id"
                class="list-group-item px-0"
              >
                <div class="d-flex align-items-start">
                  <i :class="item.icon" class="me-3 mt-1"></i>
                  <div class="flex-grow-1">
                    <div class="mb-0">{{ item.text }}</div>
                    <small class="text-muted">{{ item.time }}</small>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Accesos rápidos -->
    <div class="row g-3 mb-4">
      <div class="col-12">
        <h4 class="mb-3">Accesos Rápidos</h4>
      </div>

      <div class="col-md-4">
        <RouterLink to="/socios/nuevo" class="quick-action-card">
          <i class="bi bi-person-plus-fill"></i>
          <span>Nuevo Socio</span>
        </RouterLink>
      </div>

      <div class="col-md-4">
        <RouterLink to="/salas/nueva" class="quick-action-card">
          <i class="bi bi-building-add"></i>
          <span>Nueva Sala</span>
        </RouterLink>
      </div>

      <div class="col-md-4">
        <RouterLink to="/usuarios" class="quick-action-card">
          <i class="bi bi-people"></i>
          <span>Gestionar Usuarios</span>
        </RouterLink>
      </div>
    </div>

    <!-- Actividad reciente -->
    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header bg-white">
            <h5 class="mb-0">Actividad Reciente</h5>
          </div>
          <div class="card-body">
            <div v-if="loading" class="text-center py-4">
              <div class="spinner-border text-success"></div>
            </div>
            <div v-else-if="actividad.length === 0" class="text-center py-4 text-muted">
              <i class="bi bi-inbox display-4 d-block mb-2"></i>
              No hay actividad reciente
            </div>
            <div v-else class="activity-list">
              <div v-for="item in actividad" :key="item.id" class="activity-item">
                <div class="activity-icon">
                  <i :class="item.icon"></i>
                </div>
                <div class="activity-content">
                  <div class="activity-text">{{ item.text }}</div>
                  <div class="activity-time text-muted">{{ item.time }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../../lib/api.js'
import PlantDistributionChart from '../charts/PlantDistributionChart.vue'

const stats = ref({})
const actividad = ref([])
const loading = ref(true)

onMounted(async () => {
  try {
    const { data } = await api.get('stats')
    stats.value = data
    actividad.value = data.actividad || []
  } catch (error) {
    console.error('Error cargando stats:', error)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.stat-card {
  border-radius: 12px;
  padding: 1.5rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  transition: transform 0.2s;
}

.stat-card:hover {
  transform: translateY(-2px);
}

.stat-icon {
  font-size: 2.5rem;
  opacity: 0.9;
}

.stat-value {
  font-size: 2rem;
  font-weight: 700;
  line-height: 1;
  margin-bottom: 0.25rem;
}

.stat-label {
  font-size: 0.875rem;
  opacity: 0.9;
}

.quick-action-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem;
  background: white;
  border: 2px solid #e9ecef;
  border-radius: 12px;
  text-decoration: none;
  color: #495057;
  transition: all 0.2s;
  gap: 0.75rem;
}

.quick-action-card:hover {
  border-color: #198754;
  color: #198754;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(25, 135, 84, 0.15);
}

.quick-action-card i {
  font-size: 2.5rem;
}

.quick-action-card span {
  font-weight: 600;
}

.activity-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.activity-item {
  display: flex;
  gap: 1rem;
  padding: 1rem;
  border-radius: 8px;
  background: #f8f9fa;
}

.activity-icon {
  font-size: 1.5rem;
}

.activity-content {
  flex: 1;
}

.activity-text {
  font-weight: 500;
  margin-bottom: 0.25rem;
}

.activity-time {
  font-size: 0.875rem;
}
</style>
