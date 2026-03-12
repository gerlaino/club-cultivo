<template>
  <div class="container-fluid py-4">
    <!-- Header -->
    <div class="d-flex justify-content-between align-items-center mb-4">
      <div>
        <h2 class="mb-1">Genéticas</h2>
        <p class="text-muted mb-0">Catálogo de cepas disponibles</p>
      </div>
      <button @click="showModal = true; resetForm()" class="btn btn-success">
        <i class="bi bi-plus-circle me-2"></i>
        Nueva Genética
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <!-- Lista vacía -->
    <div v-else-if="geneticas.length === 0" class="text-center py-5">
      <i class="bi bi-flower1 display-1 text-muted"></i>
      <h4 class="mt-3">No hay genéticas</h4>
      <p class="text-muted">Agregá tu primera genética al catálogo</p>
    </div>

    <!-- Grid de genéticas -->
    <div v-else class="row g-3">
      <div v-for="gen in geneticas" :key="gen.id" class="col-md-4 col-lg-3">
        <div class="genetica-card" @click="editGenetica(gen)">
          <div class="genetica-header">
            <h5 class="genetica-nombre">{{ gen.nombre }}</h5>
            <span class="badge" :class="tipoBadgeClass(gen.tipo)">
              {{ gen.tipo }}
            </span>
          </div>

          <div class="genetica-stats">
            <div class="stat-item">
              <div class="stat-label">THC</div>
              <div class="stat-value">{{ gen.thc }}%</div>
            </div>
            <div class="stat-item">
              <div class="stat-label">CBD</div>
              <div class="stat-value">{{ gen.cbd }}%</div>
            </div>
          </div>

          <div class="genetica-footer">
            <button
              @click.stop="confirmDelete(gen)"
              class="btn btn-sm btn-outline-danger"
            >
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Crear/Editar -->
    <div v-if="showModal" class="modal show d-block" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              {{ editingId ? 'Editar' : 'Nueva' }} Genética
            </h5>
            <button @click="showModal = false" class="btn-close"></button>
          </div>
          <div class="modal-body">
            <form @submit.prevent="handleSubmit">
              <div class="mb-3">
                <label class="form-label">Nombre *</label>
                <input
                  v-model="form.nombre"
                  type="text"
                  class="form-control"
                  placeholder="Ej: OG Kush"
                  required
                >
              </div>

              <div class="mb-3">
                <label class="form-label">Tipo *</label>
                <select v-model="form.tipo" class="form-select" required>
                  <option value="">Seleccionar...</option>
                  <option value="indica">Indica</option>
                  <option value="sativa">Sativa</option>
                  <option value="hibrida">Híbrida</option>
                  <option value="ruderalis">Ruderalis</option>
                </select>
              </div>

              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">THC (%)</label>
                  <input
                    v-model.number="form.thc"
                    type="number"
                    step="0.1"
                    class="form-control"
                    placeholder="0.0"
                  >
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">CBD (%)</label>
                  <input
                    v-model.number="form.cbd"
                    type="number"
                    step="0.1"
                    class="form-control"
                    placeholder="0.0"
                  >
                </div>
              </div>

              <div class="mb-3">
                <label class="form-label">Descripción</label>
                <textarea
                  v-model="form.descripcion"
                  class="form-control"
                  rows="3"
                  placeholder="Características, efectos, sabor..."
                ></textarea>
              </div>

              <div class="mb-3">
                <label class="form-label">Origen</label>
                <input
                  v-model="form.origen"
                  type="text"
                  class="form-control"
                  placeholder="Ej: California, USA"
                >
              </div>

              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Tiempo floración (días)</label>
                  <input
                    v-model.number="form.tiempo_floracion"
                    type="number"
                    class="form-control"
                    placeholder="Ej: 60"
                  >
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">Rendimiento (g/planta)</label>
                  <input
                    v-model.number="form.rendimiento"
                    type="number"
                    class="form-control"
                    placeholder="Ej: 450"
                  >
                </div>
              </div>

              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Altura (cm)</label>
                  <input
                    v-model.number="form.altura"
                    type="number"
                    class="form-control"
                    placeholder="Ej: 120"
                  >
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">Dificultad</label>
                  <select v-model="form.dificultad" class="form-select">
                    <option value="">No especificada</option>
                    <option value="facil">Fácil</option>
                    <option value="media">Media</option>
                    <option value="dificil">Difícil</option>
                  </select>
                </div>
              </div>

              <div class="form-check">
                <input
                  v-model="form.disponible"
                  type="checkbox"
                  class="form-check-input"
                  id="disponible"
                >
                <label class="form-check-label" for="disponible">
                  Disponible para cultivo
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
            <p>¿Estás seguro de eliminar la genética <strong>{{ deleteConfirm.nombre }}</strong>?</p>
            <p class="text-muted small mb-0">Se marcará como inactiva pero no se eliminará del sistema.</p>
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
import { ref, onMounted } from 'vue'
import { listGeneticas, createGenetica, updateGenetica, deleteGenetica } from '../lib/api.js'

const geneticas = ref([])
const loading = ref(true)
const showModal = ref(false)
const editingId = ref(null)
const saving = ref(false)
const deleting = ref(false)
const deleteConfirm = ref(null)

const form = ref({
  nombre: '',
  tipo: '',
  thc: null,
  cbd: null,
  descripcion: '',
  origen: '',
  tiempo_floracion: null,
  rendimiento: null,
  altura: null,
  dificultad: '',
  disponible: true
})

const tipoBadgeClass = (tipo) => {
  const classes = {
    indica: 'bg-purple',
    sativa: 'bg-success',
    hibrida: 'bg-warning text-dark',
    ruderalis: 'bg-info'
  }
  return classes[tipo] || 'bg-secondary'
}

const loadGeneticas = async () => {
  try {
    loading.value = true
    const { data } = await listGeneticas()
    geneticas.value = data
  } catch (error) {
    console.error('Error cargando genéticas:', error)
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  editingId.value = null
  form.value = {
    nombre: '',
    tipo: '',
    thc: null,
    cbd: null,
    descripcion: '',
    origen: '',
    tiempo_floracion: null,
    rendimiento: null,
    altura: null,
    dificultad: '',
    disponible: true
  }
}

const editGenetica = (gen) => {
  editingId.value = gen.id
  form.value = {
    nombre: gen.nombre,
    tipo: gen.tipo,
    thc: gen.thc,
    cbd: gen.cbd,
    descripcion: gen.descripcion || '',
    origen: gen.origen || '',
    tiempo_floracion: gen.tiempo_floracion,
    rendimiento: gen.rendimiento,
    altura: gen.altura,
    dificultad: gen.dificultad || '',
    disponible: gen.disponible
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
      await updateGenetica(editingId.value, payload)
    } else {
      await createGenetica(payload)
    }

    await loadGeneticas()
    showModal.value = false
    resetForm()
  } catch (error) {
    console.error('Error guardando genética:', error)
    alert('Error al guardar la genética')
  } finally {
    saving.value = false
  }
}

const confirmDelete = (gen) => {
  deleteConfirm.value = gen
}

const handleDelete = async () => {
  try {
    deleting.value = true
    await deleteGenetica(deleteConfirm.value.id)
    await loadGeneticas()
    deleteConfirm.value = null
  } catch (error) {
    console.error('Error eliminando genética:', error)
    alert('Error al eliminar la genética')
  } finally {
    deleting.value = false
  }
}

onMounted(loadGeneticas)
</script>

<style scoped>
.genetica-card {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  cursor: pointer;
  transition: all 0.2s;
  border: 2px solid #e9ecef;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.genetica-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  border-color: #198754;
}

.genetica-header {
  display: flex;
  justify-content: space-between;
  align-items: start;
  margin-bottom: 1rem;
  gap: 0.5rem;
}

.genetica-nombre {
  font-size: 1.1rem;
  font-weight: 600;
  margin: 0;
  flex: 1;
}

.bg-purple {
  background: #6f42c1;
  color: white;
}

.genetica-stats {
  display: flex;
  gap: 1rem;
  margin-bottom: 1rem;
  flex: 1;
}

.stat-item {
  flex: 1;
  text-align: center;
  padding: 0.75rem;
  background: #f8f9fa;
  border-radius: 8px;
}

.stat-label {
  font-size: 0.75rem;
  color: #6c757d;
  text-transform: uppercase;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.stat-value {
  font-size: 1.25rem;
  font-weight: 700;
  color: #198754;
}

.genetica-footer {
  display: flex;
  justify-content: flex-end;
  padding-top: 0.5rem;
  border-top: 1px solid #e9ecef;
}

.modal.show {
  background: rgba(0,0,0,0.5);
}
</style>
