<template>
  <div class="activities-timeline">
    <!-- Formulario agregar actividad -->
    <div class="card mb-3">
      <div class="card-body">
        <h6 class="mb-3">Agregar Actividad</h6>
        <form @submit.prevent="handleSubmit">
          <div class="row g-2">
            <div class="col-md-4">
              <select v-model="form.activity_type" class="form-select form-select-sm" required>
                <option value="">Tipo de actividad...</option>
                <option value="watering">Riego</option>
                <option value="fertilization">Fertilización</option>
                <option value="pruning">Poda</option>
                <option value="measurement">Medición</option>
                <option value="note">Nota</option>
                <option value="other">Otro</option>
              </select>
            </div>
            <div class="col-md-6">
              <input
                v-model="form.description"
                type="text"
                class="form-control form-control-sm"
                placeholder="Descripción..."
                required
              >
            </div>
            <div class="col-md-2">
              <button
                type="submit"
                class="btn btn-success btn-sm w-100"
                :disabled="saving"
              >
                <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
                <i v-else class="bi bi-plus-circle me-1"></i>
                Agregar
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>

    <!-- Timeline -->
    <div v-if="loading" class="text-center py-4">
      <div class="spinner-border spinner-border-sm text-success"></div>
    </div>

    <div v-else-if="activities.length === 0" class="text-center py-4 text-muted">
      <i class="bi bi-calendar-x display-6"></i>
      <p class="mt-2 mb-0 small">No hay actividades registradas</p>
    </div>

    <div v-else class="timeline">
      <div
        v-for="activity in activities"
        :key="activity.id"
        class="timeline-item"
      >
        <div class="timeline-marker" :class="`marker-${activity.activity_type}`">
          <i :class="getIcon(activity.activity_type)"></i>
        </div>
        <div class="timeline-content">
          <div class="d-flex justify-content-between align-items-start mb-1">
            <div>
              <span class="badge" :class="getBadgeClass(activity.activity_type)">
                {{ activity.activity_label }}
              </span>
              <span class="ms-2 small text-muted">
                {{ formatDate(activity.occurred_at) }}
              </span>
            </div>
            <button
              @click="handleDelete(activity.id)"
              class="btn btn-sm btn-link text-danger p-0"
              :disabled="deleting === activity.id"
            >
              <i class="bi bi-trash"></i>
            </button>
          </div>
          <p class="mb-1">{{ activity.description }}</p>
          <small class="text-muted">
            <i class="bi bi-person"></i>
            {{ activity.user.name }}
          </small>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listPlantActivities, createPlantActivity, deletePlantActivity } from '../../lib/api.js'

const props = defineProps({
  plantId: {
    type: Number,
    required: true
  }
})

const activities = ref([])
const loading = ref(true)
const saving = ref(false)
const deleting = ref(null)

const form = ref({
  activity_type: '',
  description: ''
})

const getIcon = (type) => {
  const icons = {
    state_change: 'bi bi-arrow-repeat',
    watering: 'bi bi-droplet-fill',
    fertilization: 'bi bi-flask',
    pruning: 'bi bi-scissors',
    transplant: 'bi bi-box-arrow-right',
    harvest: 'bi bi-basket',
    measurement: 'bi bi-rulers',
    note: 'bi bi-pencil',
    photo: 'bi bi-camera',
    other: 'bi bi-three-dots'
  }
  return icons[type] || 'bi bi-circle'
}

const getBadgeClass = (type) => {
  const classes = {
    state_change: 'bg-primary',
    watering: 'bg-info',
    fertilization: 'bg-success',
    pruning: 'bg-warning',
    transplant: 'bg-secondary',
    harvest: 'bg-danger',
    measurement: 'bg-dark',
    note: 'bg-light text-dark',
    photo: 'bg-purple',
    other: 'bg-secondary'
  }
  return classes[type] || 'bg-secondary'
}

const formatDate = (date) => {
  const d = new Date(date)
  const now = new Date()
  const diffMs = now - d
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return 'Hace un momento'
  if (diffMins < 60) return `Hace ${diffMins} min`
  if (diffHours < 24) return `Hace ${diffHours} hrs`
  if (diffDays < 7) return `Hace ${diffDays} días`

  return d.toLocaleDateString('es-AR', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const loadActivities = async () => {
  try {
    loading.value = true
    const { data } = await listPlantActivities(props.plantId)
    activities.value = data
  } catch (error) {
    console.error('Error cargando actividades:', error)
  } finally {
    loading.value = false
  }
}

const handleSubmit = async () => {
  try {
    saving.value = true
    await createPlantActivity(props.plantId, form.value)
    form.value = { activity_type: '', description: '' }
    await loadActivities()
  } catch (error) {
    console.error('Error creando actividad:', error)
    alert('Error al crear la actividad')
  } finally {
    saving.value = false
  }
}

const handleDelete = async (id) => {
  if (!confirm('¿Eliminar esta actividad?')) return

  try {
    deleting.value = id
    await deletePlantActivity(props.plantId, id)
    await loadActivities()
  } catch (error) {
    console.error('Error eliminando actividad:', error)
    alert('Error al eliminar la actividad')
  } finally {
    deleting.value = null
  }
}

onMounted(loadActivities)
</script>

<style scoped>
.timeline {
  position: relative;
  padding-left: 2.5rem;
}

.timeline::before {
  content: '';
  position: absolute;
  left: 12px;
  top: 0;
  bottom: 0;
  width: 2px;
  background: #e9ecef;
}

.timeline-item {
  position: relative;
  padding-bottom: 1.5rem;
}

.timeline-item:last-child {
  padding-bottom: 0;
}

.timeline-marker {
  position: absolute;
  left: -2.5rem;
  top: 0;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: white;
  border: 2px solid #198754;
  z-index: 1;
  font-size: 12px;
  color: #198754;
}

.marker-state_change {
  border-color: #0d6efd;
  color: #0d6efd;
}

.marker-watering {
  border-color: #0dcaf0;
  color: #0dcaf0;
}

.marker-fertilization {
  border-color: #198754;
  color: #198754;
}

.marker-pruning {
  border-color: #ffc107;
  color: #ffc107;
}

.marker-harvest {
  border-color: #dc3545;
  color: #dc3545;
}

.timeline-content {
  background: #f8f9fa;
  border-radius: 8px;
  padding: 1rem;
  border-left: 3px solid #198754;
}

.bg-purple {
  background: #6f42c1;
  color: white;
}
</style>
