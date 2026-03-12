<template>
  <div class="indicaciones-medicas">
    <div class="d-flex justify-content-between align-items-center mb-3">
      <h5 class="mb-0">
        <i class="bi bi-file-medical me-2"></i>
        Indicaciones Médicas
      </h5>
      <button
        v-if="canCreate"
        @click="showModal = true; resetForm()"
        class="btn btn-sm btn-success"
      >
        <i class="bi bi-plus-circle me-1"></i>
        Nueva Indicación
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-4">
      <div class="spinner-border spinner-border-sm text-success"></div>
    </div>

    <!-- Lista vacía -->
    <div v-else-if="indicaciones.length === 0" class="text-center py-4 text-muted">
      <i class="bi bi-file-medical display-6"></i>
      <p class="mt-2 mb-0 small">No hay indicaciones médicas registradas</p>
    </div>

    <!-- Lista de indicaciones -->
    <div v-else class="indicaciones-list">
      <div
        v-for="ind in indicaciones"
        :key="ind.id"
        class="indicacion-card"
        :class="{
          'border-danger': ind.vencida,
          'border-warning': ind.por_vencer,
          'border-success': ind.activa && !ind.vencida && !ind.por_vencer
        }"
      >
        <div class="d-flex justify-content-between align-items-start mb-2">
          <div>
            <h6 class="mb-1">{{ ind.patologia }}</h6>
            <small class="text-muted">
              <i class="bi bi-person-badge me-1"></i>
              {{ ind.medico.nombre }}
            </small>
          </div>
          <div class="d-flex gap-1">
            <span
              v-if="ind.vencida"
              class="badge bg-danger"
            >
              Vencida
            </span>
            <span
              v-else-if="ind.por_vencer"
              class="badge bg-warning text-dark"
            >
              Por vencer ({{ ind.dias_hasta_vencimiento }} días)
            </span>
            <span
              v-else-if="ind.activa"
              class="badge bg-success"
            >
              Activa
            </span>
            <span
              v-else
              class="badge bg-secondary"
            >
              Inactiva
            </span>
          </div>
        </div>

        <div class="row g-2 mb-2">
          <div class="col-md-4">
            <small class="text-muted d-block">Dosificación</small>
            <div class="small">{{ ind.dosificacion }}</div>
          </div>
          <div class="col-md-4">
            <small class="text-muted d-block">Vía</small>
            <div class="small text-capitalize">{{ ind.via_administracion }}</div>
          </div>
          <div class="col-md-4">
            <small class="text-muted d-block">Emisión</small>
            <div class="small">{{ formatDate(ind.fecha_emision) }}</div>
          </div>
        </div>

        <div v-if="ind.fecha_vencimiento" class="small text-muted">
          <i class="bi bi-calendar-x me-1"></i>
          Vence: {{ formatDate(ind.fecha_vencimiento) }}
        </div>

        <div v-if="canEdit" class="mt-2 pt-2 border-top">
          <button
            @click="editIndicacion(ind)"
            class="btn btn-sm btn-outline-primary me-1"
          >
            <i class="bi bi-pencil"></i>
          </button>
          <button
            @click="confirmDelete(ind)"
            class="btn btn-sm btn-outline-danger"
          >
            <i class="bi bi-trash"></i>
          </button>
        </div>
      </div>
    </div>

    <!-- Modal Crear/Editar -->
    <div v-if="showModal" class="modal show d-block" tabindex="-1">
      <div class="modal-dialog modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              {{ editingId ? 'Editar' : 'Nueva' }} Indicación Médica
            </h5>
            <button @click="showModal = false" class="btn-close"></button>
          </div>
          <div class="modal-body">
            <form @submit.prevent="handleSubmit">
              <div class="mb-3">
                <label class="form-label">Patología / Diagnóstico *</label>
                <input
                  v-model="form.patologia"
                  type="text"
                  class="form-control"
                  placeholder="Ej: Dolor crónico, Ansiedad, Epilepsia refractaria..."
                  required
                >
              </div>

              <div class="mb-3">
                <label class="form-label">Dosificación *</label>
                <textarea
                  v-model="form.dosificacion"
                  class="form-control"
                  rows="3"
                  placeholder="Ej: 2 gotas sublinguales cada 8 horas, o 0.5g flores inhaladas según necesidad..."
                  required
                ></textarea>
              </div>

              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Vía de Administración *</label>
                  <select v-model="form.via_administracion" class="form-select" required>
                    <option value="">Seleccionar...</option>
                    <option value="oral">Oral</option>
                    <option value="sublingual">Sublingual</option>
                    <option value="inhalada">Inhalada</option>
                    <option value="topica">Tópica</option>
                    <option value="vaporizacion">Vaporización</option>
                  </select>
                </div>

                <div class="col-md-6 mb-3">
                  <label class="form-label">Duración (días)</label>
                  <input
                    v-model.number="form.duracion_dias"
                    type="number"
                    class="form-control"
                    placeholder="Ej: 90, 180..."
                  >
                  <small class="text-muted">Se calculará fecha de vencimiento automáticamente</small>
                </div>
              </div>

              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Fecha de Emisión *</label>
                  <input
                    v-model="form.fecha_emision"
                    type="date"
                    class="form-control"
                    required
                  >
                </div>

                <div class="col-md-6 mb-3">
                  <label class="form-label">Fecha de Vencimiento</label>
                  <input
                    v-model="form.fecha_vencimiento"
                    type="date"
                    class="form-control"
                  >
                  <small class="text-muted">Dejar vacío si no vence</small>
                </div>
              </div>

              <div class="mb-3">
                <label class="form-label">Observaciones</label>
                <textarea
                  v-model="form.observaciones"
                  class="form-control"
                  rows="3"
                  placeholder="Notas adicionales, contraindicaciones, seguimiento..."
                ></textarea>
              </div>

              <div class="form-check">
                <input
                  v-model="form.activa"
                  type="checkbox"
                  class="form-check-input"
                  id="activa"
                >
                <label class="form-check-label" for="activa">
                  Indicación activa
                </label>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button @click="showModal = false" class="btn btn-secondary">
              Cancelar
            </button>
            <button @click="handleSubmit" class="btn btn-success" :disabled="saving">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editingId ? 'Guardar' : 'Crear' }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showModal" class="modal-backdrop show"></div>

    <!-- Modal confirmar eliminación -->
    <div v-if="deleteConfirm" class="modal show d-block" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Confirmar Eliminación</h5>
            <button @click="deleteConfirm = null" class="btn-close"></button>
          </div>
          <div class="modal-body">
            <p>¿Desactivar la indicación para <strong>{{ deleteConfirm.patologia }}</strong>?</p>
            <p class="text-muted small mb-0">La indicación se marcará como inactiva.</p>
          </div>
          <div class="modal-footer">
            <button @click="deleteConfirm = null" class="btn btn-secondary">
              Cancelar
            </button>
            <button @click="handleDelete" class="btn btn-danger" :disabled="deleting">
              <span v-if="deleting" class="spinner-border spinner-border-sm me-2"></span>
              Desactivar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="deleteConfirm" class="modal-backdrop show"></div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import api, { listIndicaciones, createIndicacion, updateIndicacion, deleteIndicacion } from '../../lib/api.js'

const props = defineProps({
  socioId: {
    type: Number,
    required: true
  }
})

const auth = useAuthStore()
const indicaciones = ref([])
const loading = ref(true)
const showModal = ref(false)
const editingId = ref(null)
const saving = ref(false)
const deleting = ref(false)
const deleteConfirm = ref(null)

const canCreate = computed(() => auth.user?.role === 'admin' || auth.user?.role === 'medico')
const canEdit = computed(() => auth.user?.role === 'admin' || auth.user?.role === 'medico')

const form = ref({
  patologia: '',
  dosificacion: '',
  via_administracion: '',
  duracion_dias: null,
  fecha_emision: new Date().toISOString().split('T')[0],
  fecha_vencimiento: '',
  activa: true,
  observaciones: ''
})

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleDateString('es-AR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

const loadIndicaciones = async () => {
  try {
    loading.value = true
    const { data } = await listIndicaciones(props.socioId)
    indicaciones.value = data
  } catch (error) {
    console.error('Error cargando indicaciones:', error)
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  editingId.value = null
  form.value = {
    patologia: '',
    dosificacion: '',
    via_administracion: '',
    duracion_dias: null,
    fecha_emision: new Date().toISOString().split('T')[0],
    fecha_vencimiento: '',
    activa: true,
    observaciones: ''
  }
}

const editIndicacion = (ind) => {
  editingId.value = ind.id
  form.value = {
    patologia: ind.patologia,
    dosificacion: ind.dosificacion,
    via_administracion: ind.via_administracion,
    duracion_dias: ind.duracion_dias,
    fecha_emision: ind.fecha_emision,
    fecha_vencimiento: ind.fecha_vencimiento || '',
    activa: ind.activa,
    observaciones: ind.observaciones || ''
  }
  showModal.value = true
}

const handleSubmit = async () => {
  try {
    saving.value = true
    const payload = { ...form.value }

    // Limpiar valores vacíos
    Object.keys(payload).forEach(key => {
      if (payload[key] === '' || payload[key] === null) {
        delete payload[key]
      }
    })

    if (editingId.value) {
      await updateIndicacion(editingId.value, payload)
    } else {
      await createIndicacion(props.socioId, payload)
    }

    await loadIndicaciones()
    showModal.value = false
    resetForm()
  } catch (error) {
    console.error('Error guardando indicación:', error)
    alert('Error al guardar la indicación')
  } finally {
    saving.value = false
  }
}

const confirmDelete = (ind) => {
  deleteConfirm.value = ind
}

const handleDelete = async () => {
  try {
    deleting.value = true
    await deleteIndicacion(deleteConfirm.value.id)
    await loadIndicaciones()
    deleteConfirm.value = null
  } catch (error) {
    console.error('Error eliminando indicación:', error)
    alert('Error al desactivar la indicación')
  } finally {
    deleting.value = false
  }
}

onMounted(loadIndicaciones)
</script>

<style scoped>
.indicaciones-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.indicacion-card {
  background: white;
  border-radius: 8px;
  padding: 1rem;
  border-left: 4px solid;
  transition: all 0.2s;
}

.indicacion-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.modal.show {
  background: rgba(0,0,0,0.5);
}
</style>
