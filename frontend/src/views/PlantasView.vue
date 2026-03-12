<template>
  <div class="plantas-view">
    <div class="container-fluid py-4">
      <!-- Header -->
      <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
          <h2 class="mb-1">Plantas</h2>
          <p class="text-muted mb-0">Gestión de trazabilidad seed-to-sale</p>
        </div>
        <RouterLink to="/plantas/nueva" class="btn btn-success">
          <i class="bi bi-plus-circle me-2"></i>
          Nueva Planta
        </RouterLink>
      </div>

      <!-- Filtros -->
      <div class="card mb-4">
        <div class="card-body">
          <div class="row g-3">
            <div class="col-md-3">
              <label class="form-label">Estado</label>
              <select v-model="filters.state" class="form-select" @change="loadPlants">
                <option value="">Todos</option>
                <option value="germinacion">Germinación</option>
                <option value="vegetativo">Vegetativo</option>
                <option value="floracion">Floración</option>
                <option value="secado">Secado</option>
                <option value="cosechado">Cosechado</option>
              </select>
            </div>
            <div class="col-md-3">
              <label class="form-label">Lote</label>
              <select v-model="filters.lote_id" class="form-select" @change="loadPlants">
                <option value="">Todos</option>
                <option v-for="lote in lotes" :key="lote.id" :value="lote.id">
                  {{ lote.code }}
                </option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="text-center py-5">
        <div class="spinner-border text-success"></div>
      </div>

      <!-- Lista de plantas -->
      <div v-else-if="plants.length === 0" class="text-center py-5">
        <i class="bi bi-flower2 display-1 text-muted"></i>
        <h4 class="mt-3">No hay plantas</h4>
        <p class="text-muted">Agregá tu primera planta para comenzar la trazabilidad</p>
      </div>

      <div v-else class="row g-3">
        <div v-for="plant in plants" :key="plant.id" class="col-md-4">
          <div class="plant-card" @click="goToDetail(plant.id)">
            <div class="plant-header">
              <div class="plant-state" :class="`state-${plant.state}`">
                {{ stateLabel(plant.state) }}
              </div>
              <div class="plant-qr">
                <i class="bi bi-qr-code"></i>
                {{ plant.codigo_qr }}
              </div>
            </div>

            <h5 class="plant-name">{{ plant.nombre }}</h5>

            <div class="plant-info">
              <div class="info-item">
                <i class="bi bi-box"></i>
                <span>{{ plant.lote.code }}</span>
              </div>
              <div class="info-item" v-if="plant.genetica">
                <i class="bi bi-flower1"></i>
                <span>{{ plant.genetica.nombre }}</span>
              </div>
              <div class="info-item" v-if="plant.dias_desde_germinacion">
                <i class="bi bi-calendar"></i>
                <span>{{ plant.dias_desde_germinacion }} días</span>
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
import { useRouter } from 'vue-router'
import { listPlants, listLotes } from '../lib/api.js'

const router = useRouter()
const plants = ref([])
const lotes = ref([])
const loading = ref(true)
const filters = ref({
  state: '',
  lote_id: ''
})

const stateLabel = (state) => {
  const labels = {
    germinacion: 'Germinación',
    vegetativo: 'Vegetativo',
    floracion: 'Floración',
    secado: 'Secado',
    cosechado: 'Cosechado'
  }
  return labels[state] || state
}

const goToDetail = (id) => {
  router.push(`/plantas/${id}`)
}

const loadPlants = async () => {
  try {
    loading.value = true
    const params = {}
    if (filters.value.state) params.state = filters.value.state
    if (filters.value.lote_id) params.lote_id = filters.value.lote_id

    const { data } = await listPlants(params)
    plants.value = data
  } catch (error) {
    console.error('Error cargando plantas:', error)
  } finally {
    loading.value = false
  }
}

const loadLotes = async () => {
  try {
    const { data } = await listLotes()
    lotes.value = data
  } catch (error) {
    console.error('Error cargando lotes:', error)
  }
}

onMounted(async () => {
  await Promise.all([loadPlants(), loadLotes()])
})
</script>

<style scoped>
.plant-card {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  cursor: pointer;
  transition: all 0.2s;
  border: 2px solid #e9ecef;
}

.plant-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  border-color: #198754;
}

.plant-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.plant-state {
  padding: 0.25rem 0.75rem;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
}

.state-germinacion {
  background: #e3f2fd;
  color: #1976d2;
}

.state-vegetativo {
  background: #e8f5e9;
  color: #388e3c;
}

.state-floracion {
  background: #fff3e0;
  color: #f57c00;
}

.state-secado {
  background: #fce4ec;
  color: #c2185b;
}

.state-cosechado {
  background: #f3e5f5;
  color: #7b1fa2;
}

.plant-qr {
  font-family: monospace;
  font-size: 0.75rem;
  color: #6c757d;
}

.plant-name {
  font-weight: 600;
  margin-bottom: 1rem;
}

.plant-info {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.info-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #6c757d;
}

.info-item i {
  width: 20px;
}
</style>
