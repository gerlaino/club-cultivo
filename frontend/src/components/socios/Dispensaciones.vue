<template>
  <div class="dispensaciones">
    <div class="d-flex justify-content-between align-items-center mb-3">
      <h5 class="mb-0">
        <i class="bi bi-capsule me-2"></i>
        Dispensaciones
      </h5>
      <button
        v-if="canCreate"
        @click="showModal = true; resetForm()"
        class="btn btn-sm btn-success"
        :disabled="!cupoDisponible || cupoDisponible <= 0"
      >
        <i class="bi bi-plus-circle me-1"></i>
        Nueva Dispensación
      </button>
    </div>

    <!-- Cupo mensual -->
    <div class="card mb-3" :class="{
      'border-success': porcentajeCupo < 70,
      'border-warning': porcentajeCupo >= 70 && porcentajeCupo < 90,
      'border-danger': porcentajeCupo >= 90
    }">
      <div class="card-body">
        <div class="d-flex justify-content-between align-items-center mb-2">
          <small class="text-muted">Cupo Mensual</small>
          <small class="fw-bold">{{ totalDispensadoMes }}g / {{ cupoMensual }}g</small>
        </div>
        <div class="progress" style="height: 8px;">
          <div
            class="progress-bar"
            :class="{
              'bg-success': porcentajeCupo < 70,
              'bg-warning': porcentajeCupo >= 70 && porcentajeCupo < 90,
              'bg-danger': porcentajeCupo >= 90
            }"
            :style="{ width: porcentajeCupo + '%' }"
          ></div>
        </div>
        <small class="text-muted">Disponible: {{ cupoDisponible }}g</small>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-4">
      <div class="spinner-border spinner-border-sm text-success"></div>
    </div>

    <!-- Lista vacía -->
    <div v-else-if="dispensaciones.length === 0" class="text-center py-4 text-muted">
      <i class="bi bi-capsule display-6"></i>
      <p class="mt-2 mb-0 small">No hay dispensaciones registradas</p>
    </div>

    <!-- Lista de dispensaciones -->
    <div v-else class="table-responsive">
      <table class="table table-sm table-hover">
        <thead>
        <tr>
          <th>Fecha</th>
          <th>Tipo</th>
          <th>Cantidad</th>
          <th>Lote</th>
          <th>Dispensado por</th>
          <th class="text-end">Acciones</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="disp in dispensaciones" :key="disp.id">
          <td>{{ formatDate(disp.fecha_dispensacion) }}</td>
          <td>
            <span class="badge bg-secondary text-capitalize">{{ disp.tipo_producto }}</span>
          </td>
          <td class="fw-bold">{{ disp.cantidad_gramos }}g</td>
          <td>
            <span v-if="disp.lote" class="small">{{ disp.lote.codigo }}</span>
            <span v-else class="text-muted small">-</span>
          </td>
          <td class="small">{{ disp.usuario.nombre }}</td>
          <td class="text-end">
            <button
              v-if="canEdit"
              @click="editDispensacion(disp)"
              class="btn btn-sm btn-outline-primary me-1"
            >
              <i class="bi bi-pencil"></i>
            </button>
            <button
              v-if="canEdit"
              @click="confirmDelete(disp)"
              class="btn btn-sm btn-outline-danger"
            >
              <i class="bi bi-trash"></i>
            </button>
          </td>
        </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal Crear/Editar -->
    <div v-if="showModal" class="modal show d-block" tabindex="-1">
      <div class="modal-dialog modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              {{ editingId ? 'Editar' : 'Nueva' }} Dispensación
            </h5>
            <button @click="showModal = false" class="btn-close"></button>
          </div>
          <div class="modal-body">
            <form @submit.prevent="handleSubmit">
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Cantidad (gramos) *</label>
                  <input
                    v-model.number="form.cantidad_gramos"
                    type="number"
                    step="0.01"
                    class="form-control"
                    placeholder="Ej: 5, 10, 20..."
                    required
                  >
                  <small class="text-muted">Disponible: {{ cupoDisponible }}g</small>
                </div>

                <div class="col-md-6 mb-3">
                  <label class="form-label">Tipo de Producto *</label>
                  <select v-model="form.tipo_producto" class="form-select" required>
                    <option value="flores">Flores</option>
                    <option value="aceite">Aceite</option>
                    <option value="extracto">Extracto</option>
                    <option value="crema">Crema</option>
                  </select>
                </div>
              </div>

              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Fecha de Dispensación *</label>
                  <input
                    v-model="form.fecha_dispensacion"
                    type="date"
                    class="form-control"
                    :max="new Date().toISOString().split('T')[0]"
                    required
                  >
                </div>

                <div class="col-md-6 mb-3">
                  <label class="form-label">Lote (opcional)</label>
                  <select v-model="form.lote_id" class="form-select">
                    <option :value="null">Sin lote asignado</option>
                    <option v-for="lote in lotes" :key="lote.id" :value="lote.id">
                      {{ lote.codigo }}
                    </option>
                  </select>
                </div>
              </div>

              <div class="mb-3">
                <label class="form-label">Indicación Médica (opcional)</label>
                <select v-model="form.indicacion_medica_id" class="form-select">
                  <option :value="null">Sin indicación asociada</option>
                  <option v-for="ind in indicaciones" :key="ind.id" :value="ind.id">
                    {{ ind.patologia }}
                  </option>
                </select>
              </div>

              <div class="mb-3">
                <label class="form-label">Observaciones</label>
                <textarea
                  v-model="form.observaciones"
                  class="form-control"
                  rows="3"
                  placeholder="Notas adicionales..."
                ></textarea>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button @click="showModal = false" class="btn btn-secondary">
              Cancelar
            </button>
            <button @click="handleSubmit" class="btn btn-success" :disabled="saving">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editingId ? 'Guardar' : 'Dispensar' }}
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
            <p>¿Eliminar dispensación de <strong>{{ deleteConfirm.cantidad_gramos }}g</strong>?</p>
            <p class="text-muted small mb-0">Esta acción liberará el cupo nuevamente.</p>
          </div>
          <div class="modal-footer">
            <button @click="deleteConfirm = null" class="btn btn-secondary">
              Cancelar
            </button>
            <button @click="handleDelete" class="btn btn-danger" :disabled="deleting">
              <span v-if="deleting" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
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
import { listDispensaciones, createDispensacion, updateDispensacion, deleteDispensacion, listIndicaciones } from '../../lib/api.js'

const props = defineProps({
  socioId: {
    type: Number,
    required: true
  }
})

const auth = useAuthStore()
const dispensaciones = ref([])
const indicaciones = ref([])
const lotes = ref([])
const loading = ref(true)
const showModal = ref(false)
const editingId = ref(null)
const saving = ref(false)
const deleting = ref(false)
const deleteConfirm = ref(null)
const cupoMensual = ref(40)
const totalDispensadoMes = ref(0)
const cupoDisponible = ref(40)

const canCreate = computed(() => auth.user?.role === 'admin' || auth.user?.role === 'medico' || auth.user?.role === 'agricultor')
const canEdit = computed(() => auth.user?.role === 'admin' || auth.user?.role === 'medico' || auth.user?.role === 'agricultor')

const porcentajeCupo = computed(() => {
  if (!cupoMensual.value) return 0
  return Math.min(100, (totalDispensadoMes.value / cupoMensual.value) * 100)
})

const form = ref({
  cantidad_gramos: null,
  tipo_producto: 'flores',
  fecha_dispensacion: new Date().toISOString().split('T')[0],
  lote_id: null,
  indicacion_medica_id: null,
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

const loadDispensaciones = async () => {
  try {
    loading.value = true
    const { data } = await listDispensaciones(props.socioId)
    dispensaciones.value = data.dispensaciones || []
    cupoMensual.value = data.cupo_mensual || 40
    totalDispensadoMes.value = data.total_dispensado_mes || 0
    cupoDisponible.value = data.cupo_disponible || 40
  } catch (error) {
    console.error('Error cargando dispensaciones:', error)
  } finally {
    loading.value = false
  }
}

const loadIndicaciones = async () => {
  try {
    const { data } = await listIndicaciones(props.socioId)
    indicaciones.value = data.filter(ind => ind.activa)
  } catch (error) {
    console.error('Error cargando indicaciones:', error)
  }
}

const loadLotes = async () => {
  try {
    const { data } = await fetch('http://localhost:3001/lotes', {
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('jwt_token')}`,
        'Content-Type': 'application/json'
      }
    }).then(r => r.json())
    lotes.value = data || []
  } catch (error) {
    console.error('Error cargando lotes:', error)
  }
}

const resetForm = () => {
  editingId.value = null
  form.value = {
    cantidad_gramos: null,
    tipo_producto: 'flores',
    fecha_dispensacion: new Date().toISOString().split('T')[0],
    lote_id: null,
    indicacion_medica_id: null,
    observaciones: ''
  }
}

const editDispensacion = (disp) => {
  editingId.value = disp.id
  form.value = {
    cantidad_gramos: disp.cantidad_gramos,
    tipo_producto: disp.tipo_producto,
    fecha_dispensacion: disp.fecha_dispensacion,
    lote_id: disp.lote?.id || null,
    indicacion_medica_id: disp.indicacion_medica?.id || null,
    observaciones: disp.observaciones || ''
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
      await updateDispensacion(editingId.value, payload)
    } else {
      await createDispensacion(props.socioId, payload)
    }

    await loadDispensaciones()
    showModal.value = false
    resetForm()
  } catch (error) {
    console.error('Error guardando dispensación:', error)
    const errorMsg = error.response?.data?.errors?.[0] || 'Error al guardar la dispensación'
    alert(errorMsg)
  } finally {
    saving.value = false
  }
}

const confirmDelete = (disp) => {
  deleteConfirm.value = disp
}

const handleDelete = async () => {
  try {
    deleting.value = true
    await deleteDispensacion(deleteConfirm.value.id)
    await loadDispensaciones()
    deleteConfirm.value = null
  } catch (error) {
    console.error('Error eliminando dispensación:', error)
    alert('Error al eliminar la dispensación')
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  await Promise.all([
    loadDispensaciones(),
    loadIndicaciones(),
    loadLotes()
  ])
})
</script>

<style scoped>
.modal.show {
  background: rgba(0,0,0,0.5);
}
</style>
