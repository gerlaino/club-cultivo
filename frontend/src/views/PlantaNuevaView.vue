<template>
  <div class="container py-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
      <div>
        <h2 class="mb-1">Nueva Planta</h2>
        <p class="text-muted mb-0">Agregar planta al sistema de trazabilidad</p>
      </div>
      <button @click="$router.back()" class="btn btn-outline-secondary">
        <i class="bi bi-arrow-left me-2"></i>
        Volver
      </button>
    </div>

    <div class="row">
      <div class="col-lg-8">
        <div class="card">
          <div class="card-body">
            <form @submit.prevent="handleSubmit">
              <!-- Datos básicos -->
              <div class="mb-4">
                <h5 class="border-bottom pb-2 mb-3">Datos Básicos</h5>

                <div class="mb-3">
                  <label class="form-label">Nombre de la planta *</label>
                  <input
                    v-model="form.nombre"
                    type="text"
                    class="form-control"
                    :class="{ 'is-invalid': errors.nombre }"
                    placeholder="Ej: Planta #001"
                    required
                  >
                  <div v-if="errors.nombre" class="invalid-feedback">{{ errors.nombre }}</div>
                </div>

                <div class="mb-3">
                  <label class="form-label">Lote *</label>
                  <select
                    v-model="form.lote_id"
                    class="form-select"
                    :class="{ 'is-invalid': errors.lote_id }"
                    required
                  >
                    <option value="">Seleccionar lote...</option>
                    <option v-for="lote in lotes" :key="lote.id" :value="lote.id">
                      {{ lote.code }} - {{ lote.sala?.name || 'Sin sala' }}
                    </option>
                  </select>
                  <div v-if="errors.lote_id" class="invalid-feedback">{{ errors.lote_id }}</div>
                </div>

                <div class="mb-3">
                  <label class="form-label">Genética</label>
                  <select
                    v-model="form.genetica_id"
                    class="form-select"
                  >
                    <option value="">Sin genética asignada</option>
                    <option v-for="gen in geneticas" :key="gen.id" :value="gen.id">
                      {{ gen.nombre }} ({{ gen.tipo }})
                    </option>
                  </select>
                </div>

                <div class="mb-3">
                  <label class="form-label">Estado inicial *</label>
                  <select
                    v-model="form.state"
                    class="form-select"
                    required
                  >
                    <option value="germinacion">Germinación</option>
                    <option value="vegetativo">Vegetativo</option>
                    <option value="floracion">Floración</option>
                    <option value="secado">Secado</option>
                    <option value="cosechado">Cosechado</option>
                  </select>
                </div>
              </div>

              <!-- Fechas -->
              <div class="mb-4">
                <h5 class="border-bottom pb-2 mb-3">Timeline</h5>

                <div class="mb-3">
                  <label class="form-label">Fecha de germinación</label>
                  <input
                    v-model="form.fecha_germinacion"
                    type="date"
                    class="form-control"
                    :max="today"
                  >
                  <small class="text-muted">Si la planta ya germinó, indicá cuándo fue</small>
                </div>

                <div class="mb-3" v-if="form.state !== 'germinacion'">
                  <label class="form-label">Fecha inicio vegetativo</label>
                  <input
                    v-model="form.fecha_vegetativo"
                    type="date"
                    class="form-control"
                    :max="today"
                  >
                </div>

                <div class="mb-3" v-if="['floracion', 'secado', 'cosechado'].includes(form.state)">
                  <label class="form-label">Fecha inicio floración</label>
                  <input
                    v-model="form.fecha_floracion"
                    type="date"
                    class="form-control"
                    :max="today"
                  >
                </div>

                <div class="mb-3" v-if="form.state === 'cosechado'">
                  <label class="form-label">Fecha de cosecha</label>
                  <input
                    v-model="form.fecha_cosecha"
                    type="date"
                    class="form-control"
                    :max="today"
                  >
                </div>

                <div class="mb-3" v-if="form.state === 'cosechado'">
                  <label class="form-label">Peso seco (gramos)</label>
                  <input
                    v-model.number="form.peso_seco"
                    type="number"
                    step="0.1"
                    class="form-control"
                    placeholder="0.0"
                  >
                </div>
              </div>

              <!-- Notas -->
              <div class="mb-4">
                <label class="form-label">Notas</label>
                <textarea
                  v-model="form.notas"
                  class="form-control"
                  rows="4"
                  placeholder="Observaciones, particularidades, etc."
                ></textarea>
              </div>

              <!-- Error general -->
              <div v-if="errors.general" class="alert alert-danger">
                {{ errors.general }}
              </div>

              <!-- Botones -->
              <div class="d-flex gap-2">
                <button
                  type="submit"
                  class="btn btn-success"
                  :disabled="saving"
                >
                  <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
                  <i v-else class="bi bi-check-circle me-2"></i>
                  Crear Planta
                </button>
                <button
                  type="button"
                  class="btn btn-outline-secondary"
                  @click="$router.back()"
                  :disabled="saving"
                >
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <!-- Info lateral -->
      <div class="col-lg-4">
        <div class="card bg-light">
          <div class="card-body">
            <h6 class="card-title">
              <i class="bi bi-info-circle me-2"></i>
              Información
            </h6>
            <ul class="small mb-0">
              <li class="mb-2">El <strong>código QR</strong> se genera automáticamente al crear la planta</li>
              <li class="mb-2">El <strong>estado</strong> define en qué etapa del ciclo está la planta</li>
              <li class="mb-2">Las <strong>fechas</strong> permiten calcular tiempos de cada etapa</li>
              <li>El <strong>lote</strong> agrupa plantas que comparten condiciones de cultivo</li>
            </ul>
          </div>
        </div>

        <!-- Preview del estado -->
        <div class="card mt-3" v-if="form.state">
          <div class="card-body">
            <h6 class="card-title">Preview</h6>
            <div class="d-flex align-items-center gap-2">
              <span class="badge" :class="stateBadgeClass">
                {{ stateLabel }}
              </span>
              <span v-if="diasDesdeGerminacion" class="text-muted small">
                {{ diasDesdeGerminacion }} días desde germinación
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { createPlant, listLotes } from '../lib/api.js'
import api from '../lib/api.js'

const router = useRouter()

const form = ref({
  nombre: '',
  lote_id: '',
  genetica_id: '',
  state: 'germinacion',
  fecha_germinacion: '',
  fecha_vegetativo: '',
  fecha_floracion: '',
  fecha_cosecha: '',
  peso_seco: null,
  notas: ''
})

const lotes = ref([])
const geneticas = ref([])
const errors = ref({})
const saving = ref(false)

const today = computed(() => new Date().toISOString().split('T')[0])

const stateLabel = computed(() => {
  const labels = {
    germinacion: 'Germinación',
    vegetativo: 'Vegetativo',
    floracion: 'Floración',
    secado: 'Secado',
    cosechado: 'Cosechado'
  }
  return labels[form.value.state]
})

const stateBadgeClass = computed(() => {
  const classes = {
    germinacion: 'bg-primary',
    vegetativo: 'bg-success',
    floracion: 'bg-warning',
    secado: 'bg-info',
    cosechado: 'bg-secondary'
  }
  return classes[form.value.state]
})

const diasDesdeGerminacion = computed(() => {
  if (!form.value.fecha_germinacion) return null
  const inicio = new Date(form.value.fecha_germinacion)
  const hoy = new Date()
  const diff = Math.floor((hoy - inicio) / (1000 * 60 * 60 * 24))
  return diff >= 0 ? diff : null
})

const loadLotes = async () => {
  try {
    const { data } = await listLotes()
    lotes.value = data
  } catch (error) {
    console.error('Error cargando lotes:', error)
  }
}

const loadGeneticas = async () => {
  try {
    const { data } = await api.get('/geneticas')
    geneticas.value = data
  } catch (error) {
    console.error('Error cargando genéticas:', error)
  }
}

const handleSubmit = async () => {
  errors.value = {}
  saving.value = true

  try {
    // Limpiar valores null/vacíos
    const payload = {}
    Object.keys(form.value).forEach(key => {
      const val = form.value[key]
      if (val !== '' && val !== null) {
        payload[key] = val
      }
    })

    await createPlant(payload)
    router.push('/plantas')
  } catch (error) {
    console.error('Error creando planta:', error)
    if (error.response?.data?.errors) {
      errors.value.general = error.response.data.errors.join(', ')
    } else {
      errors.value.general = 'Error al crear la planta'
    }
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  await Promise.all([loadLotes(), loadGeneticas()])
})
</script>

<style scoped>
.form-label {
  font-weight: 500;
  margin-bottom: 0.5rem;
}

.card {
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}
</style>
