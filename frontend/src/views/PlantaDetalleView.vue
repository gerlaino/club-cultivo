<template>
  <div class="container py-4">
    <button @click="$router.back()" class="btn btn-outline-secondary btn-sm mb-3">
      <i class="bi bi-arrow-left me-2"></i>
      Volver
    </button>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="alert alert-danger">
      {{ error }}
    </div>

    <!-- Contenido -->
    <div v-else-if="plant" class="row g-4">
      <!-- Columna izquierda: Info principal -->
      <div class="col-lg-8">
        <!-- Header -->
        <div class="card mb-4">
          <div class="card-body">
            <div class="d-flex justify-content-between align-items-start mb-3">
              <div>
                <h2 class="mb-2">{{ plant.nombre }}</h2>
                <div class="d-flex gap-2 align-items-center">
                  <span class="badge" :class="stateBadgeClass">
                    {{ stateLabel }}
                  </span>
                  <span class="text-muted">
                    <i class="bi bi-qr-code me-1"></i>
                    {{ plant.codigo_qr }}
                  </span>
                </div>
              </div>
              <div class="d-flex gap-2">
                <button
                  @click="showEditModal = true"
                  class="btn btn-outline-primary btn-sm"
                >
                  <i class="bi bi-pencil me-1"></i>
                  Editar
                </button>
                <button
                  @click="showDeleteConfirm = true"
                  class="btn btn-outline-danger btn-sm"
                >
                  <i class="bi bi-trash me-1"></i>
                  Eliminar
                </button>
              </div>
            </div>

            <!-- Stats rápidas -->
            <div class="row g-3">
              <div class="col-md-3">
                <div class="text-muted small">Lote</div>
                <RouterLink
                  :to="`/lotes/${plant.lote.id}`"
                  class="fw-semibold text-decoration-none"
                >
                  {{ plant.lote.code }}
                </RouterLink>
              </div>
              <div class="col-md-3">
                <div class="text-muted small">Sala</div>
                <RouterLink
                  :to="`/salas/${plant.lote.sala.id}`"
                  class="fw-semibold text-decoration-none"
                >
                  {{ plant.lote.sala.name }}
                </RouterLink>
              </div>
              <div class="col-md-3" v-if="plant.genetica">
                <div class="text-muted small">Genética</div>
                <div class="fw-semibold">
                  {{ plant.genetica.nombre }}
                  <span class="badge bg-secondary ms-1">{{ plant.genetica.tipo }}</span>
                </div>
              </div>
              <div class="col-md-3" v-if="plant.dias_desde_germinacion">
                <div class="text-muted small">Edad</div>
                <div class="fw-semibold">{{ plant.dias_desde_germinacion }} días</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Timeline -->
        <div class="card mb-4">
          <div class="card-header">
            <h5 class="mb-0">
              <i class="bi bi-calendar-event me-2"></i>
              Timeline de Crecimiento
            </h5>
          </div>
          <div class="card-body">
            <div class="timeline">
              <!-- Germinación -->
              <div class="timeline-item" :class="{ active: plant.fecha_germinacion }">
                <div class="timeline-marker">
                  <i class="bi bi-circle-fill" v-if="plant.fecha_germinacion"></i>
                  <i class="bi bi-circle" v-else></i>
                </div>
                <div class="timeline-content">
                  <h6>Germinación</h6>
                  <div v-if="plant.fecha_germinacion" class="text-muted small">
                    {{ formatDate(plant.fecha_germinacion) }}
                    <span class="ms-2">({{ plant.dias_desde_germinacion }} días atrás)</span>
                  </div>
                  <div v-else class="text-muted small">Sin registrar</div>
                </div>
              </div>

              <!-- Vegetativo -->
              <div class="timeline-item" :class="{ active: plant.fecha_vegetativo }">
                <div class="timeline-marker">
                  <i class="bi bi-circle-fill" v-if="plant.fecha_vegetativo"></i>
                  <i class="bi bi-circle" v-else></i>
                </div>
                <div class="timeline-content">
                  <h6>Fase Vegetativa</h6>
                  <div v-if="plant.fecha_vegetativo" class="text-muted small">
                    {{ formatDate(plant.fecha_vegetativo) }}
                    <span v-if="plant.dias_en_vegetativo" class="ms-2">
                      ({{ plant.dias_en_vegetativo }} días)
                    </span>
                  </div>
                  <div v-else class="text-muted small">Sin registrar</div>
                </div>
              </div>

              <!-- Floración -->
              <div class="timeline-item" :class="{ active: plant.fecha_floracion }">
                <div class="timeline-marker">
                  <i class="bi bi-circle-fill" v-if="plant.fecha_floracion"></i>
                  <i class="bi bi-circle" v-else></i>
                </div>
                <div class="timeline-content">
                  <h6>Floración</h6>
                  <div v-if="plant.fecha_floracion" class="text-muted small">
                    {{ formatDate(plant.fecha_floracion) }}
                    <span v-if="plant.dias_en_floracion" class="ms-2">
                      ({{ plant.dias_en_floracion }} días)
                    </span>
                  </div>
                  <div v-else class="text-muted small">Sin registrar</div>
                </div>
              </div>

              <!-- Cosecha -->
              <div class="timeline-item" :class="{ active: plant.fecha_cosecha }">
                <div class="timeline-marker">
                  <i class="bi bi-circle-fill" v-if="plant.fecha_cosecha"></i>
                  <i class="bi bi-circle" v-else></i>
                </div>
                <div class="timeline-content">
                  <h6>Cosecha</h6>
                  <div v-if="plant.fecha_cosecha" class="text-muted small">
                    {{ formatDate(plant.fecha_cosecha) }}
                    <span v-if="plant.peso_seco" class="ms-2 text-success fw-semibold">
                      {{ plant.peso_seco }}g seco
                    </span>
                  </div>
                  <div v-else class="text-muted small">Sin registrar</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Genética (si existe) -->
        <div v-if="plant.genetica" class="card mb-4">
          <div class="card-header">
            <h5 class="mb-0">
              <i class="bi bi-flower1 me-2"></i>
              Información Genética
            </h5>
          </div>
          <div class="card-body">
            <div class="row">
              <div class="col-md-4">
                <div class="text-muted small">Nombre</div>
                <div class="fw-semibold">{{ plant.genetica.nombre }}</div>
              </div>
              <div class="col-md-4">
                <div class="text-muted small">Tipo</div>
                <div class="fw-semibold text-capitalize">{{ plant.genetica.tipo }}</div>
              </div>
              <div class="col-md-2">
                <div class="text-muted small">THC</div>
                <div class="fw-semibold">{{ plant.genetica.thc }}%</div>
              </div>
              <div class="col-md-2">
                <div class="text-muted small">CBD</div>
                <div class="fw-semibold">{{ plant.genetica.cbd }}%</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Notas -->
        <div class="card" v-if="plant.notas">
          <div class="card-header">
            <h5 class="mb-0">
              <i class="bi bi-journal-text me-2"></i>
              Notas
            </h5>
          </div>
          <div class="card-body">
            <p class="mb-0">{{ plant.notas }}</p>
          </div>
        </div>
      </div>

      <!-- Columna derecha: Acciones rápidas -->
      <div class="col-lg-4">
        <!-- Cambiar estado -->
        <div class="card mb-4">
          <div class="card-header">
            <h6 class="mb-0">Cambiar Estado</h6>
          </div>
          <div class="card-body">
            <div class="d-grid gap-2">
              <button
                v-for="state in availableStates"
                :key="state.value"
                @click="changeState(state.value)"
                class="btn btn-sm"
                :class="state.class"
                :disabled="updating"
              >
                {{ state.label }}
              </button>
            </div>
          </div>
        </div>

        <!-- QR Code -->
        <div class="card mb-4">
          <div class="card-header">
            <h6 class="mb-0">Código QR</h6>
          </div>
          <div class="card-body text-center">
            <div class="qr-placeholder bg-light p-4 rounded">
              <i class="bi bi-qr-code display-1 text-muted"></i>
              <div class="mt-2 small text-muted">{{ plant.codigo_qr }}</div>
            </div>
            <button class="btn btn-sm btn-outline-secondary mt-3">
              <i class="bi bi-download me-1"></i>
              Descargar QR
            </button>
          </div>
        </div>

        <!-- Metadata -->
        <div class="card">
          <div class="card-header">
            <h6 class="mb-0">Información del Sistema</h6>
          </div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-2">
              <span class="text-muted">ID</span>
              <span>{{ plant.id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-2">
              <span class="text-muted">Creado</span>
              <span>{{ formatDate(plant.created_at) }}</span>
            </div>
            <div class="d-flex justify-content-between py-2">
              <span class="text-muted">Actualizado</span>
              <span>{{ formatDate(plant.updated_at) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal confirmar eliminación -->
    <div v-if="showDeleteConfirm" class="modal show d-block" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Confirmar Eliminación</h5>
            <button @click="showDeleteConfirm = false" class="btn-close"></button>
          </div>
          <div class="modal-body">
            <p>¿Estás seguro de que querés eliminar <strong>{{ plant.nombre }}</strong>?</p>
            <p class="text-danger small mb-0">Esta acción no se puede deshacer.</p>
          </div>
          <div class="modal-footer">
            <button @click="showDeleteConfirm = false" class="btn btn-secondary">Cancelar</button>
            <button @click="handleDelete" class="btn btn-danger" :disabled="deleting">
              <span v-if="deleting" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showDeleteConfirm" class="modal-backdrop show"></div>
  </div>
  <!-- Modal Editar -->
  <div v-if="showEditModal" class="modal show d-block" tabindex="-1">
    <div class="modal-dialog modal-lg">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">Editar Planta</h5>
          <button @click="showEditModal = false" class="btn-close"></button>
        </div>
        <div class="modal-body">
          <form @submit.prevent="handleUpdate">
            <div class="mb-3">
              <label class="form-label">Nombre *</label>
              <input
                v-model="editForm.nombre"
                type="text"
                class="form-control"
                required
              >
            </div>

            <div class="mb-3">
              <label class="form-label">Estado</label>
              <select v-model="editForm.state" class="form-select">
                <option value="germinacion">Germinación</option>
                <option value="vegetativo">Vegetativo</option>
                <option value="floracion">Floración</option>
                <option value="secado">Secado</option>
                <option value="cosechado">Cosechado</option>
              </select>
            </div>

            <div class="row">
              <div class="col-md-6 mb-3">
                <label class="form-label">Fecha germinación</label>
                <input
                  v-model="editForm.fecha_germinacion"
                  type="date"
                  class="form-control"
                >
              </div>
              <div class="col-md-6 mb-3">
                <label class="form-label">Fecha vegetativo</label>
                <input
                  v-model="editForm.fecha_vegetativo"
                  type="date"
                  class="form-control"
                >
              </div>
            </div>

            <div class="row">
              <div class="col-md-6 mb-3">
                <label class="form-label">Fecha floración</label>
                <input
                  v-model="editForm.fecha_floracion"
                  type="date"
                  class="form-control"
                >
              </div>
              <div class="col-md-6 mb-3">
                <label class="form-label">Fecha cosecha</label>
                <input
                  v-model="editForm.fecha_cosecha"
                  type="date"
                  class="form-control"
                >
              </div>
            </div>

            <div class="mb-3">
              <label class="form-label">Peso seco (gramos)</label>
              <input
                v-model.number="editForm.peso_seco"
                type="number"
                step="0.1"
                class="form-control"
              >
            </div>

            <div class="mb-3">
              <label class="form-label">Notas</label>
              <textarea
                v-model="editForm.notas"
                class="form-control"
                rows="4"
              ></textarea>
            </div>
          </form>
        </div>
        <div class="modal-footer">
          <button @click="showEditModal = false" class="btn btn-secondary">Cancelar</button>
          <button @click="handleUpdate" class="btn btn-primary" :disabled="updating">
            <span v-if="updating" class="spinner-border spinner-border-sm me-2"></span>
            Guardar Cambios
          </button>
        </div>
      </div>
    </div>
  </div>
  <div v-if="showEditModal" class="modal-backdrop show"></div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPlant, updatePlant, deletePlant } from '../lib/api.js'
import { useQRCode } from '../composables/useQRCode.js'

const route = useRoute()
const router = useRouter()

const plant = ref(null)
const loading = ref(true)
const error = ref(null)
const updating = ref(false)
const deleting = ref(false)
const showEditModal = ref(false)
const showDeleteConfirm = ref(false)

// QR Code
const { generateQR, downloadQR } = useQRCode()
const qrDataUrl = ref(null)

const stateLabel = computed(() => {
  const labels = {
    germinacion: 'Germinación',
    vegetativo: 'Vegetativo',
    floracion: 'Floración',
    secado: 'Secado',
    cosechado: 'Cosechado'
  }
  return labels[plant.value?.state] || plant.value?.state
})

const stateBadgeClass = computed(() => {
  const classes = {
    germinacion: 'bg-primary',
    vegetativo: 'bg-success',
    floracion: 'bg-warning text-dark',
    secado: 'bg-info',
    cosechado: 'bg-secondary'
  }
  return classes[plant.value?.state] || 'bg-secondary'
})

const availableStates = computed(() => {
  const all = [
    { value: 'germinacion', label: 'Germinación', class: 'btn-outline-primary' },
    { value: 'vegetativo', label: 'Vegetativo', class: 'btn-outline-success' },
    { value: 'floracion', label: 'Floración', class: 'btn-outline-warning' },
    { value: 'secado', label: 'Secado', class: 'btn-outline-info' },
    { value: 'cosechado', label: 'Cosechado', class: 'btn-outline-secondary' }
  ]
  return all.filter(s => s.value !== plant.value?.state)
})

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleDateString('es-AR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

const loadPlant = async () => {
  try {
    loading.value = true
    const { data } = await getPlant(route.params.id)
    plant.value = data
  } catch (err) {
    console.error('Error cargando planta:', err)
    error.value = 'No se pudo cargar la planta'
  } finally {
    loading.value = false
  }
}

const loadQR = async () => {
  if (plant.value?.codigo_qr) {
    try {
      qrDataUrl.value = await generateQR(plant.value.codigo_qr)
    } catch (error) {
      console.error('Error generando QR:', error)
    }
  }
}

const handleDownloadQR = async () => {
  if (plant.value?.codigo_qr) {
    try {
      await downloadQR(plant.value.codigo_qr, `planta-${plant.value.nombre}-qr.png`)
    } catch (error) {
      alert('Error al descargar el QR')
    }
  }
}

const changeState = async (newState) => {
  if (!confirm(`¿Cambiar estado a ${newState}?`)) return

  try {
    updating.value = true
    const payload = { state: newState }

    if (newState === 'vegetativo' && !plant.value.fecha_vegetativo) {
      payload.fecha_vegetativo = new Date().toISOString().split('T')[0]
    }
    if (newState === 'floracion' && !plant.value.fecha_floracion) {
      payload.fecha_floracion = new Date().toISOString().split('T')[0]
    }
    if (newState === 'cosechado' && !plant.value.fecha_cosecha) {
      payload.fecha_cosecha = new Date().toISOString().split('T')[0]
    }

    await updatePlant(plant.value.id, payload)
    await loadPlant()
  } catch (err) {
    console.error('Error actualizando estado:', err)
    alert('Error al cambiar el estado')
  } finally {
    updating.value = false
  }
}

const handleDelete = async () => {
  try {
    deleting.value = true
    await deletePlant(plant.value.id)
    router.push('/plantas')
  } catch (err) {
    console.error('Error eliminando planta:', err)
    alert('Error al eliminar la planta')
  } finally {
    deleting.value = false
  }
}

const editForm = ref({
  nombre: '',
  state: '',
  fecha_germinacion: '',
  fecha_vegetativo: '',
  fecha_floracion: '',
  fecha_cosecha: '',
  peso_seco: null,
  notas: ''
})

watch(showEditModal, (val) => {
  if (val && plant.value) {
    editForm.value = {
      nombre: plant.value.nombre,
      state: plant.value.state,
      fecha_germinacion: plant.value.fecha_germinacion || '',
      fecha_vegetativo: plant.value.fecha_vegetativo || '',
      fecha_floracion: plant.value.fecha_floracion || '',
      fecha_cosecha: plant.value.fecha_cosecha || '',
      peso_seco: plant.value.peso_seco,
      notas: plant.value.notas || ''
    }
  }
})

const handleUpdate = async () => {
  try {
    updating.value = true
    const payload = { ...editForm.value }

    Object.keys(payload).forEach(key => {
      if (payload[key] === '' || payload[key] === null) {
        delete payload[key]
      }
    })

    await updatePlant(plant.value.id, payload)
    await loadPlant()
    showEditModal.value = false
  } catch (err) {
    console.error('Error actualizando planta:', err)
    alert('Error al guardar los cambios')
  } finally {
    updating.value = false
  }
}

onMounted(async () => {
  await loadPlant()
  await loadQR()
})
</script>

<style scoped>
.timeline {
  position: relative;
  padding-left: 2rem;
}

.timeline::before {
  content: '';
  position: absolute;
  left: 8px;
  top: 0;
  bottom: 0;
  width: 2px;
  background: #e9ecef;
}

.timeline-item {
  position: relative;
  padding-bottom: 2rem;
}

.timeline-item:last-child {
  padding-bottom: 0;
}

.timeline-marker {
  position: absolute;
  left: -2rem;
  top: 0;
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: white;
  z-index: 1;
}

.timeline-item.active .timeline-marker i {
  color: #198754;
  font-size: 12px;
}

.timeline-item:not(.active) .timeline-marker i {
  color: #dee2e6;
  font-size: 12px;
}

.timeline-content h6 {
  margin-bottom: 0.25rem;
  font-size: 0.95rem;
}

.timeline-item.active .timeline-content h6 {
  color: #198754;
  font-weight: 600;
}

.qr-placeholder {
  border: 2px dashed #dee2e6;
}

.modal.show {
  background: rgba(0,0,0,0.5);
}
</style>
