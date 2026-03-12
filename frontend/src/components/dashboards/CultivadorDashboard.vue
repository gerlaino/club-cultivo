<template>
  <div>
    <h2 class="mb-1">Hola, {{ auth.displayName }} 👋</h2>
    <p class="text-muted mb-4">{{ greeting }} - {{ today }}</p>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <div v-else>
      <!-- Métricas rápidas -->
      <div class="row g-3 mb-4">
        <div class="col-md-3">
          <div class="card bg-success text-white h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between align-items-start">
                <div>
                  <div class="small opacity-75">Mis Plantas</div>
                  <h3 class="mb-0">{{ stats.total_plantas }}</h3>
                </div>
                <i class="bi bi-flower1 fs-1 opacity-50"></i>
              </div>
            </div>
          </div>
        </div>

        <div class="col-md-3">
          <div class="card bg-primary text-white h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between align-items-start">
                <div>
                  <div class="small opacity-75">Vegetativo</div>
                  <h3 class="mb-0">{{ stats.vegetativo }}</h3>
                </div>
                <i class="bi bi-droplet fs-1 opacity-50"></i>
              </div>
            </div>
          </div>
        </div>

        <div class="col-md-3">
          <div class="card bg-warning text-dark h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between align-items-start">
                <div>
                  <div class="small opacity-75">Floración</div>
                  <h3 class="mb-0">{{ stats.floracion }}</h3>
                </div>
                <i class="bi bi-brightness-high fs-1 opacity-50"></i>
              </div>
            </div>
          </div>
        </div>

        <div class="col-md-3">
          <div class="card bg-info text-white h-100">
            <div class="card-body">
              <div class="d-flex justify-content-between align-items-start">
                <div>
                  <div class="small opacity-75">Actividades Hoy</div>
                  <h3 class="mb-0">{{ stats.actividades_hoy }}</h3>
                </div>
                <i class="bi bi-clipboard-check fs-1 opacity-50"></i>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Acciones rápidas -->
      <div class="row g-3 mb-4">
        <div class="col-md-12">
          <div class="card">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-lightning-charge me-2"></i>
                Acciones Rápidas
              </h5>
            </div>
            <div class="card-body">
              <div class="row g-2">
                <div class="col-md-3">
                  <button @click="showQuickActivity = true" class="btn btn-outline-success w-100">
                    <i class="bi bi-droplet me-2"></i>
                    Registrar Riego
                  </button>
                </div>
                <div class="col-md-3">
                  <button @click="showQuickActivity = true" class="btn btn-outline-primary w-100">
                    <i class="bi bi-flask me-2"></i>
                    Fertilización
                  </button>
                </div>
                <div class="col-md-3">
                  <button @click="showQuickActivity = true" class="btn btn-outline-warning w-100">
                    <i class="bi bi-scissors me-2"></i>
                    Poda
                  </button>
                </div>
                <div class="col-md-3">
                  <RouterLink to="/plantas" class="btn btn-outline-secondary w-100">
                    <i class="bi bi-eye me-2"></i>
                    Ver Plantas
                  </RouterLink>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Grid: Mis plantas + Última actividad -->
      <div class="row g-3">
        <!-- Mis plantas recientes -->
        <div class="col-lg-8">
          <div class="card">
            <div class="card-header d-flex justify-content-between align-items-center">
              <h5 class="mb-0">
                <i class="bi bi-flower1 me-2"></i>
                Mis Plantas Activas
              </h5>
              <RouterLink to="/plantas" class="btn btn-sm btn-outline-primary">
                Ver todas
              </RouterLink>
            </div>
            <div class="card-body">
              <div v-if="plantas.length === 0" class="text-center text-muted py-4">
                <i class="bi bi-inbox display-4"></i>
                <p class="mt-2 mb-0">No hay plantas asignadas</p>
              </div>
              <div v-else class="row g-2">
                <div v-for="planta in plantas.slice(0, 6)" :key="planta.id" class="col-md-4">
                  <RouterLink :to="`/plantas/${planta.id}`" class="text-decoration-none">
                    <div class="planta-card">
                      <div class="d-flex justify-content-between align-items-start mb-2">
                        <h6 class="mb-0">{{ planta.nombre }}</h6>
                        <span class="badge" :class="getStateBadge(planta.state)">
                          {{ getStateLabel(planta.state) }}
                        </span>
                      </div>
                      <div class="small text-muted">
                        <div><i class="bi bi-box me-1"></i> {{ planta.lote?.code }}</div>
                        <div v-if="planta.dias_desde_germinacion">
                          <i class="bi bi-calendar me-1"></i> {{ planta.dias_desde_germinacion }} días
                        </div>
                      </div>
                    </div>
                  </RouterLink>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Última actividad -->
        <div class="col-lg-4">
          <div class="card h-100">
            <div class="card-header">
              <h5 class="mb-0">
                <i class="bi bi-clock-history me-2"></i>
                Actividad Reciente
              </h5>
            </div>
            <div class="card-body">
              <div v-if="actividades.length === 0" class="text-center text-muted py-4">
                <i class="bi bi-inbox display-6"></i>
                <p class="mt-2 mb-0 small">Sin actividad registrada</p>
              </div>
              <div v-else class="activity-list">
                <div v-for="act in actividades.slice(0, 5)" :key="act.id" class="activity-item">
                  <div class="d-flex gap-2">
                    <i :class="getActivityIcon(act.activity_type)" class="text-success mt-1"></i>
                    <div class="flex-grow-1">
                      <div class="small fw-semibold">{{ act.activity_label }}</div>
                      <div class="small text-muted">{{ act.description }}</div>
                      <div class="small text-muted">{{ formatTime(act.occurred_at) }}</div>
                    </div>
                  </div>
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
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import api from '../../lib/api.js'

const auth = useAuthStore()
const loading = ref(true)
const stats = ref({
  total_plantas: 0,
  vegetativo: 0,
  floracion: 0,
  actividades_hoy: 0
})
const plantas = ref([])
const actividades = ref([])
const showQuickActivity = ref(false)

const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return 'Buenos días'
  if (hour < 19) return 'Buenas tardes'
  return 'Buenas noches'
})

const today = computed(() => {
  return new Date().toLocaleDateString('es-AR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  })
})

const getStateBadge = (state) => {
  const badges = {
    germinacion: 'bg-primary',
    vegetativo: 'bg-success',
    floracion: 'bg-warning text-dark',
    secado: 'bg-info',
    cosechado: 'bg-secondary'
  }
  return badges[state] || 'bg-secondary'
}

const getStateLabel = (state) => {
  const labels = {
    germinacion: 'Germinación',
    vegetativo: 'Vegetativo',
    floracion: 'Floración',
    secado: 'Secado',
    cosechado: 'Cosechado'
  }
  return labels[state] || state
}

const getActivityIcon = (type) => {
  const icons = {
    watering: 'bi bi-droplet-fill',
    fertilization: 'bi bi-flask',
    pruning: 'bi bi-scissors',
    state_change: 'bi bi-arrow-repeat',
    measurement: 'bi bi-rulers',
    note: 'bi bi-pencil'
  }
  return icons[type] || 'bi bi-circle-fill'
}

const formatTime = (date) => {
  const d = new Date(date)
  const now = new Date()
  const diffMs = now - d
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)

  if (diffMins < 1) return 'Hace un momento'
  if (diffMins < 60) return `Hace ${diffMins} min`
  if (diffHours < 24) return `Hace ${diffHours} hrs`

  return d.toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}

const loadData = async () => {
  try {
    loading.value = true

    // Cargar plantas
    const { data: plantasData } = await api.get('/plants')
    plantas.value = plantasData

    // Calcular stats
    stats.value = {
      total_plantas: plantasData.length,
      vegetativo: plantasData.filter(p => p.state === 'vegetativo').length,
      floracion: plantasData.filter(p => p.state === 'floracion').length,
      actividades_hoy: 0 // TODO: implementar endpoint
    }

    // TODO: Cargar actividades recientes del cultivador
    // Por ahora vacío
    actividades.value = []

  } catch (error) {
    console.error('Error cargando datos:', error)
  } finally {
    loading.value = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.planta-card {
  background: #f8f9fa;
  border-radius: 8px;
  padding: 1rem;
  transition: all 0.2s;
  border: 2px solid transparent;
}

.planta-card:hover {
  background: white;
  border-color: #198754;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.activity-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.activity-item {
  padding-bottom: 1rem;
  border-bottom: 1px solid #e9ecef;
}

.activity-item:last-child {
  border-bottom: none;
  padding-bottom: 0;
}
</style>
