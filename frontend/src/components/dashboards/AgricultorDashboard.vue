<template>
  <div class="agricultor-dashboard">
    <!-- Métricas de cultivo -->
    <div class="row g-3 mb-4">
      <div class="col-md-3">
        <div class="stat-card bg-success text-white">
          <div class="stat-icon">
            <i class="bi bi-seedling"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.vegetativo || 0 }}</div>
            <div class="stat-label">Vegetativo</div>
          </div>
        </div>
      </div>

      <div class="col-md-3">
        <div class="stat-card bg-warning text-white">
          <div class="stat-icon">
            <i class="bi bi-flower2"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.floracion || 0 }}</div>
            <div class="stat-label">Floración</div>
          </div>
        </div>
      </div>

      <div class="col-md-3">
        <div class="stat-card bg-info text-white">
          <div class="stat-icon">
            <i class="bi bi-archive"></i>
          </div>
          <div class="stat-content">
            <div class="stat-value">{{ stats.secado || 0 }}</div>
            <div class="stat-label">Secado</div>
          </div>
        </div>
      </div>

      <div class="col-md-3">
        <div class="stat-card bg-primary text-white">
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

    <!-- Accesos rápidos -->
    <div class="row g-3 mb-4">
      <div class="col-12">
        <h4 class="mb-3">Accesos Rápidos</h4>
      </div>

      <div class="col-md-4">
        <RouterLink to="/salas" class="quick-action-card">
          <i class="bi bi-building"></i>
          <span>Ver Salas</span>
        </RouterLink>
      </div>

      <div class="col-md-4">
        <RouterLink to="/lotes/nuevo" class="quick-action-card">
          <i class="bi bi-plus-circle"></i>
          <span>Nuevo Lote</span>
        </RouterLink>
      </div>

      <div class="col-md-4">
        <RouterLink to="/plantas" class="quick-action-card">
          <i class="bi bi-flower1"></i>
          <span>Ver Plantas</span>
        </RouterLink>
      </div>
    </div>

    <!-- Tareas del día -->
    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header bg-white">
            <h5 class="mb-0">Tareas de Hoy</h5>
          </div>
          <div class="card-body">
            <div class="task-list">
              <div class="task-item">
                <input type="checkbox" class="form-check-input" />
                <span>Riego Sala Norte - Lote L-001</span>
                <span class="badge bg-success">08:00</span>
              </div>
              <div class="task-item">
                <input type="checkbox" class="form-check-input" />
                <span>Fertilización Sala Sur - Lote L-003</span>
                <span class="badge bg-warning">14:00</span>
              </div>
              <div class="task-item">
                <input type="checkbox" class="form-check-input" />
                <span>Revisar pH Sala Este</span>
                <span class="badge bg-info">16:00</span>
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
import { getStats } from '../../lib/api.js'

const stats = ref({})

onMounted(async () => {
  try {
    const { data } = await getStats()
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

.task-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.task-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  border-radius: 8px;
  background: #f8f9fa;
}

.task-item span:first-of-type {
  flex: 1;
}
</style>
