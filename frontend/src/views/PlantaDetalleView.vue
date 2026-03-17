<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPlant, updatePlant, deletePlant, listLotes } from '../lib/api.js'
import { useQRCode } from '../composables/useQRCode.js'
import { useAuthStore } from '../stores/auth.js'
import PlantActivitiesTimeline from '../components/plants/PlantActivitiesTimeline.vue'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const { generateQR, downloadQR } = useQRCode()

const plant   = ref(null)
const loading = ref(true)
const error   = ref(null)
const updating = ref(false)
const deleting = ref(false)
const qrDataUrl = ref(null)

const showEditModal    = ref(false)
const showDeleteModal  = ref(false)

const canEdit = computed(() => ['admin','agricultor'].includes(auth.role))

// ── Helpers ───────────────────────────────────────────────────────────
const STATE_META = {
  germinacion: { label: 'Germinación', color: 'primary',   icon: '🌰' },
  vegetativo:  { label: 'Vegetativo',  color: 'success',   icon: '🌱' },
  floracion:   { label: 'Floración',   color: 'warning',   icon: '🌸' },
  secado:      { label: 'Secado',      color: 'secondary', icon: '🍂' },
  cosechado:   { label: 'Cosechado',   color: 'purple',    icon: '✂️'  },
}
function sm(s)         { return STATE_META[s] || { label: s||'—', color:'secondary', icon:'•' } }
function stateLabel(s) { return sm(s).label }
function stateColor(s) { return sm(s).color }
function stateIcon(s)  { return sm(s).icon }

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { year:'numeric', month:'long', day:'numeric' })
}

// Estados disponibles para cambiar (todos excepto el actual)
const availableStates = computed(() =>
    Object.entries(STATE_META)
        .filter(([k]) => k !== plant.value?.state)
        .map(([value, meta]) => ({ value, ...meta }))
)

// ── Carga ─────────────────────────────────────────────────────────────
async function loadPlant() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await getPlant(route.params.id)
    plant.value = data
    if (data.codigo_qr) {
      qrDataUrl.value = await generateQR(data.codigo_qr)
    }
  } catch (e) {
    error.value = 'No se pudo cargar la planta'
    console.error(e)
  } finally {
    loading.value = false
  }
}

// ── Cambio de estado rápido ───────────────────────────────────────────
async function changeState(newState) {
  updating.value = true
  try {
    const payload = { state: newState }
    if (newState === 'vegetativo' && !plant.value.fecha_vegetativo)
      payload.fecha_vegetativo = new Date().toISOString().split('T')[0]
    if (newState === 'floracion' && !plant.value.fecha_floracion)
      payload.fecha_floracion = new Date().toISOString().split('T')[0]
    if (newState === 'cosechado' && !plant.value.fecha_cosecha)
      payload.fecha_cosecha = new Date().toISOString().split('T')[0]

    await updatePlant(plant.value.id, payload)
    await loadPlant()
  } catch (e) {
    console.error('Error cambiando estado:', e)
  } finally {
    updating.value = false
  }
}

// ── Eliminar ──────────────────────────────────────────────────────────
async function handleDelete() {
  deleting.value = true
  try {
    await deletePlant(plant.value.id)
    router.push('/plantas')
  } catch (e) {
    console.error('Error eliminando planta:', e)
  } finally {
    deleting.value = false
  }
}

// ── Editar ────────────────────────────────────────────────────────────
const editForm = ref({})

watch(showEditModal, (val) => {
  if (val && plant.value) {
    editForm.value = {
      nombre:           plant.value.nombre            || '',
      state:            plant.value.state             || 'vegetativo',
      genetica_id:      plant.value.genetica?.id      || '',
      fecha_germinacion: plant.value.fecha_germinacion || '',
      fecha_vegetativo:  plant.value.fecha_vegetativo  || '',
      fecha_floracion:   plant.value.fecha_floracion   || '',
      fecha_cosecha:     plant.value.fecha_cosecha     || '',
      peso_seco:         plant.value.peso_seco         ?? '',
      notas:             plant.value.notas             || '',
    }
  }
})

async function handleUpdate() {
  updating.value = true
  try {
    const payload = { ...editForm.value }
    // limpiar vacíos para no pisar valores existentes
    Object.keys(payload).forEach(k => {
      if (payload[k] === '' || payload[k] === null) delete payload[k]
    })
    await updatePlant(plant.value.id, payload)
    await loadPlant()
    showEditModal.value = false
  } catch (e) {
    console.error('Error actualizando planta:', e)
  } finally {
    updating.value = false
  }
}

// ── QR download ───────────────────────────────────────────────────────
async function handleDownloadQR() {
  if (plant.value?.codigo_qr) {
    await downloadQR(plant.value.codigo_qr, `planta-${plant.value.nombre || plant.value.id}-qr.png`)
  }
}

onMounted(loadPlant)
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Breadcrumb -->
    <nav aria-label="breadcrumb" class="mb-3">
      <ol class="breadcrumb small">
        <li class="breadcrumb-item"><RouterLink to="/plantas">Plantas</RouterLink></li>
        <li v-if="plant?.lote?.sala" class="breadcrumb-item">
          <RouterLink :to="{ name:'sala-detail', params:{ id: plant.lote.sala.id } }">
            {{ plant.lote.sala.nombre }}
          </RouterLink>
        </li>
        <li v-if="plant?.lote" class="breadcrumb-item">
          <RouterLink :to="{ name:'lote-detail', params:{ id: plant.lote.id } }">
            {{ plant.lote.codigo }}
          </RouterLink>
        </li>
        <li class="breadcrumb-item active">{{ plant?.nombre || `#${route.params.id}` }}</li>
      </ol>
    </nav>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>

    <template v-else-if="plant">
      <!-- Header -->
      <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
        <div>
          <div class="d-flex align-items-center gap-2 mb-1">
            <span class="fs-3">{{ stateIcon(plant.state) }}</span>
            <h1 class="h3 fw-bold mb-0">{{ plant.nombre || `Planta #${plant.id}` }}</h1>
            <span class="badge fs-6" :class="`text-bg-${stateColor(plant.state)}`">
              {{ stateLabel(plant.state) }}
            </span>
          </div>
          <p class="text-muted small mb-0">
            <span class="font-monospace me-2">{{ plant.codigo_qr }}</span>
            <span v-if="plant.genetica">· {{ plant.genetica.nombre }}</span>
          </p>
        </div>
        <div v-if="canEdit" class="d-flex gap-2">
          <button class="btn btn-outline-primary btn-sm" @click="showEditModal=true">
            <i class="bi bi-pencil me-1"></i>Editar
          </button>
          <button class="btn btn-outline-danger btn-sm" @click="showDeleteModal=true">
            <i class="bi bi-trash me-1"></i>Eliminar
          </button>
        </div>
      </div>

      <div class="row g-4">

        <!-- ── Columna principal ── -->
        <div class="col-12 col-lg-8">

          <!-- Timeline de crecimiento -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-header bg-transparent border-0 pt-3 pb-0">
              <strong>📅 Timeline de crecimiento</strong>
            </div>
            <div class="card-body">
              <div class="grow-timeline">
                <div
                    v-for="(etapa, key) in STATE_META"
                    :key="key"
                    class="grow-step"
                    :class="{
                    'grow-step--done':    plant[`fecha_${key}`] && key !== plant.state,
                    'grow-step--current': key === plant.state,
                    'grow-step--pending': !plant[`fecha_${key}`] && key !== plant.state
                  }"
                >
                  <div class="grow-step__icon">{{ etapa.icon }}</div>
                  <div class="grow-step__label">{{ etapa.label }}</div>
                  <div class="grow-step__date small text-muted">
                    {{ plant[`fecha_${key}`] ? new Date(plant[`fecha_${key}`]).toLocaleDateString('es-AR', { day:'numeric', month:'short' }) : '—' }}
                  </div>
                </div>
              </div>

              <div v-if="plant.dias_desde_germinacion" class="text-center small text-muted mt-3">
                Día <strong>{{ plant.dias_desde_germinacion }}</strong> desde germinación
              </div>
            </div>
          </div>

          <!-- Actividades -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent border-0 pt-3 pb-0">
              <strong>📋 Historial de actividades</strong>
            </div>
            <div class="card-body pt-2">
              <PlantActivitiesTimeline :plant-id="plant.id" />
            </div>
          </div>

        </div>

        <!-- ── Columna lateral ── -->
        <div class="col-12 col-lg-4">

          <!-- Cambiar estado rápido -->
          <div v-if="canEdit" class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent border-0 pt-3 pb-0">
              <strong>⚡ Cambiar estado</strong>
            </div>
            <div class="card-body d-grid gap-2">
              <button
                  v-for="s in availableStates" :key="s.value"
                  class="btn btn-sm btn-outline-secondary text-start"
                  :disabled="updating"
                  @click="changeState(s.value)"
              >
                {{ s.icon }} {{ s.label }}
              </button>
            </div>
          </div>

          <!-- Info técnica -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent border-0 pt-3 pb-0">
              <strong>ℹ️ Información</strong>
            </div>
            <div class="card-body small">
              <dl class="row mb-0 g-1">
                <dt class="col-5 fw-normal text-muted">Lote</dt>
                <dd class="col-7">
                  <RouterLink :to="{ name:'lote-detail', params:{ id: plant.lote.id } }" class="text-decoration-none">
                    {{ plant.lote.codigo }}
                  </RouterLink>
                </dd>

                <dt class="col-5 fw-normal text-muted">Sala</dt>
                <dd class="col-7">
                  <RouterLink v-if="plant.lote.sala" :to="{ name:'sala-detail', params:{ id: plant.lote.sala.id } }" class="text-decoration-none">
                    {{ plant.lote.sala.nombre }}
                  </RouterLink>
                  <span v-else>—</span>
                </dd>

                <template v-if="plant.genetica">
                  <dt class="col-5 fw-normal text-muted">Genética</dt>
                  <dd class="col-7">{{ plant.genetica.nombre }}</dd>

                  <dt class="col-5 fw-normal text-muted">Tipo</dt>
                  <dd class="col-7 text-capitalize">{{ plant.genetica.tipo || '—' }}</dd>

                  <template v-if="plant.genetica.thc">
                    <dt class="col-5 fw-normal text-muted">THC</dt>
                    <dd class="col-7">{{ plant.genetica.thc }}%</dd>
                  </template>

                  <template v-if="plant.genetica.cbd">
                    <dt class="col-5 fw-normal text-muted">CBD</dt>
                    <dd class="col-7">{{ plant.genetica.cbd }}%</dd>
                  </template>
                </template>

                <template v-if="plant.dias_en_vegetativo">
                  <dt class="col-5 fw-normal text-muted">Vegetativo</dt>
                  <dd class="col-7">{{ plant.dias_en_vegetativo }} días</dd>
                </template>

                <template v-if="plant.dias_en_floracion">
                  <dt class="col-5 fw-normal text-muted">Floración</dt>
                  <dd class="col-7">{{ plant.dias_en_floracion }} días</dd>
                </template>

                <template v-if="plant.peso_seco">
                  <dt class="col-5 fw-normal text-muted">Peso seco</dt>
                  <dd class="col-7 fw-semibold text-success">{{ plant.peso_seco }}g</dd>
                </template>

                <dt class="col-5 fw-normal text-muted">Creada</dt>
                <dd class="col-7 mb-0">{{ formatDate(plant.created_at) }}</dd>
              </dl>
            </div>
          </div>

          <!-- QR -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent border-0 pt-3 pb-0">
              <strong>📱 Código QR</strong>
            </div>
            <div class="card-body text-center">
              <img v-if="qrDataUrl" :src="qrDataUrl" class="img-fluid rounded mb-2" style="max-width:160px" alt="QR" />
              <div v-else class="py-3 text-muted">
                <i class="bi bi-qr-code fs-1"></i>
                <div class="small mt-1">Sin código QR</div>
              </div>
              <div class="font-monospace small text-muted mb-2">{{ plant.codigo_qr }}</div>
              <button v-if="qrDataUrl" class="btn btn-sm btn-outline-secondary" @click="handleDownloadQR">
                <i class="bi bi-download me-1"></i>Descargar QR
              </button>
            </div>
          </div>

          <!-- Notas -->
          <div v-if="plant.notas" class="card border-0 shadow-sm">
            <div class="card-header bg-transparent border-0 pt-3 pb-0">
              <strong>📋 Notas</strong>
            </div>
            <div class="card-body small">{{ plant.notas }}</div>
          </div>

        </div>
      </div>
    </template>

    <!-- ===== MODAL EDITAR ===== -->
    <div v-if="showEditModal" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Editar planta</h5>
            <button class="btn-close" @click="showEditModal=false"></button>
          </div>
          <div class="modal-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Nombre</label>
                <input v-model.trim="editForm.nombre" class="form-control" placeholder="Nombre de la planta" />
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Estado</label>
                <select v-model="editForm.state" class="form-select">
                  <option v-for="(meta, key) in STATE_META" :key="key" :value="key">
                    {{ meta.icon }} {{ meta.label }}
                  </option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Fecha germinación</label>
                <input v-model="editForm.fecha_germinacion" type="date" class="form-control" />
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Fecha vegetativo</label>
                <input v-model="editForm.fecha_vegetativo" type="date" class="form-control" />
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Fecha floración</label>
                <input v-model="editForm.fecha_floracion" type="date" class="form-control" />
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Fecha cosecha</label>
                <input v-model="editForm.fecha_cosecha" type="date" class="form-control" />
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Peso seco (g)</label>
                <input v-model.number="editForm.peso_seco" type="number" step="0.1" min="0" class="form-control" placeholder="0.0" />
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Notas</label>
                <textarea v-model.trim="editForm.notas" class="form-control" rows="3" placeholder="Observaciones…"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="updating" @click="showEditModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="updating" @click="handleUpdate">
              <span v-if="updating" class="spinner-border spinner-border-sm me-2"></span>
              Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showEditModal" class="modal-backdrop fade show" @click="showEditModal=false"></div>

    <!-- ===== MODAL ELIMINAR ===== -->
    <div v-if="showDeleteModal" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0">
            <h5 class="modal-title text-danger">⚠️ Eliminar planta</h5>
            <button class="btn-close" @click="showDeleteModal=false"></button>
          </div>
          <div class="modal-body">
            <p>¿Seguro que querés eliminar <strong>{{ plant?.nombre }}</strong>?</p>
            <p class="text-danger small mb-0">Esta acción no se puede deshacer y se perderá todo el historial de actividades.</p>
          </div>
          <div class="modal-footer border-0">
            <button class="btn btn-outline-secondary" :disabled="deleting" @click="showDeleteModal=false">Cancelar</button>
            <button class="btn btn-danger" :disabled="deleting" @click="handleDelete">
              <span v-if="deleting" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showDeleteModal" class="modal-backdrop fade show" @click="showDeleteModal=false"></div>

  </div>
</template>

<style scoped>
/* Timeline de crecimiento */
.grow-timeline {
  display: flex;
  align-items: flex-start;
  gap: 0;
  overflow-x: auto;
}
.grow-step {
  flex: 1;
  text-align: center;
  padding: .5rem .25rem;
  border-radius: 8px;
  min-width: 64px;
  transition: background .15s;
}
.grow-step--done    { background: rgba(25,135,84,.1); color: #198754; }
.grow-step--current { background: rgba(13,110,253,.12); color: #0d6efd; font-weight: 700; box-shadow: 0 0 0 2px #0d6efd44; }
.grow-step--pending { opacity: .4; }
.grow-step__icon  { font-size: 1.4rem; }
.grow-step__label { font-size: .72rem; font-weight: 600; margin-top: .2rem; }
.grow-step__date  { font-size: .68rem; }

/* badge cosechado */
.text-bg-purple { background: #6f42c1 !important; color: white !important; }
</style>

