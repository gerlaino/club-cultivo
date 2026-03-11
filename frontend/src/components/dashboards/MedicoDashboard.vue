<template>
  <div class="medico-dashboard">
    <!-- Métricas médicas -->
    <div class="row g-3 mb-4">
      <div class="col-md-4">
        <div class="stat-card bg-primary text-white">
          <div class="stat-icon">
            <i class="bi bi-people-fill"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.pacientes || 0 }}</div>
            <div class="stat-label">Pacientes Activos</div>
          </div>
        </div>
      </div>

      <div class="col-md-4">
        <div class="stat-card bg-warning text-white">
          <div class="stat-icon">
            <i class="bi bi-exclamation-triangle-fill"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.vencimientos || 0 }}</div>
            <div class="stat-label">Vencen este mes</div>
          </div>
        </div>
      </div>

      <div class="col-md-4">
        <div class="stat-card bg-success text-white">
          <div class="stat-icon">
            <i class="bi bi-file-text-fill"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.indicaciones || 0 }}</div>
            <div class="stat-label">Indicaciones este mes</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Accesos rápidos -->
    <div class="row g-3 mb-4">
      <div class="col-12">
        <h4 class="mb-3">Accesos Rápidos</h4>
      </div>

      <div class="col-md-6">
        <RouterLink to="/pacientes/nuevo" class="quick-action-card">
          <i class="bi bi-person-plus-fill"></i>
          <span>Nuevo Paciente</span>
        </RouterLink>
      </div>

      <div class="col-md-6">
        <RouterLink to="/indicaciones/nueva" class="quick-action-card">
          <i class="bi bi-file-earmark-medical"></i>
          <span>Nueva Indicación</span>
        </RouterLink>
      </div>
    </div>

    <!-- Alertas -->
    <div class="row">
      <div class="col-12">
        <div class="card border-warning">
          <div class="card-header bg-warning bg-opacity-10">
            <h5 class="mb-0">
              <i class="bi bi-exclamation-triangle text-warning"></i>
              Autorizaciones por Vencer
            </h5>
          </div>
          <div class="card-body">
            <div class="alert-list">
              <div class="alert-item">
                <div class="alert-icon text-warning">
                  <i class="bi bi-clock-fill"></i>
                </div>
                <div class="alert-content">
                  <div class="alert-text">
                    <strong>Juan Pérez</strong> - Vence en 15 días
                  </div>
                  <div class="text-muted small">REPROCANN #12345</div>
                </div>
                <RouterLink to="/pacientes/1" class="btn btn-sm btn-outline-primary">
                  Ver
                </RouterLink>
              </div>
              <!-- Más alertas aquí -->
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getStats } from '../../lib/api.js'

const stats = ref({})

onMounted(async () => {
  try {
    const {data} = await getStats()
    stats.value = data
  } catch (error) {
    console.error('Error cargando stats:', error)
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

.alert-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.alert-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  border-radius: 8px;
  background: #f8f9fa;
}

.alert-icon {
  font-size: 1.5rem;
}

.alert-content {
  flex: 1;
}
</style>
