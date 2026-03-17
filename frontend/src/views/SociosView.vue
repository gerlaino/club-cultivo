<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useSociosStore } from '../stores/socios'
import { useAuthStore } from '../stores/auth'

const store = useSociosStore()
const auth  = useAuthStore()

const canEdit = computed(() => ['admin', 'medico'].includes(auth.role))

// ── Búsqueda y filtros ────────────────────────────────────────────────
const search     = ref('')
const searchTimer = ref(null)
const showModal  = ref(false)
const showDelete = ref(false)
const editing    = ref(false)
const deleteTarget = ref(null)
const formError  = ref(null)

// ── Form ──────────────────────────────────────────────────────────────
function emptyForm() {
  return {
    id: null, nombre: '', apellido: '', dni: '',
    email: '', telefono: '', fecha_nacimiento: '',
    reprocann_numero: '', reprocann_vencimiento: '',
    es_paciente: true,
  }
}
const form       = ref(emptyForm())
const formErrors = ref({})

function validate() {
  const e = {}
  if (!form.value.nombre.trim())    e.nombre   = 'El nombre es obligatorio'
  if (!form.value.apellido.trim())   e.apellido  = 'El apellido es obligatorio'
  if (!form.value.dni.trim())        e.dni       = 'El DNI es obligatorio'
  if (!form.value.fecha_nacimiento)  e.fecha_nacimiento = 'La fecha de nacimiento es obligatoria'
  if (form.value.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email))
    e.email = 'Email inválido'
  formErrors.value = e
  return !Object.keys(e).length
}

function openCreate() {
  editing.value  = false
  form.value     = emptyForm()
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function openEdit(s) {
  editing.value  = true
  form.value = {
    id:                    s.id,
    nombre:                s.nombre     || '',
    apellido:              s.apellido   || '',
    dni:                   s.dni        || '',
    email:                 s.email      || '',
    telefono:              s.telefono   || '',
    fecha_nacimiento:      s.fecha_nacimiento?.toString().slice(0, 10) || '',
    reprocann_numero:      s.reprocann_numero      || '',
    reprocann_vencimiento: s.reprocann_vencimiento?.toString().slice(0, 10) || '',
    es_paciente:           s.es_paciente ?? true,
  }
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function openDelete(s) {
  deleteTarget.value = s
  showDelete.value   = true
}

// ── CRUD ──────────────────────────────────────────────────────────────
async function doSearch() {
  await store.fetch({ query: search.value.trim() })
}

function onSearchInput() {
  clearTimeout(searchTimer.value)
  searchTimer.value = setTimeout(doSearch, 400)
}

async function save() {
  if (!validate()) return
  formError.value = null
  try {
    const payload = { ...form.value }
    delete payload.id
    Object.keys(payload).forEach(k => { if (payload[k] === '') delete payload[k] })

    if (editing.value) {
      await store.update(form.value.id, payload)
    } else {
      await store.create(payload)
    }
    showModal.value = false
  } catch (e) {
    formError.value = store.error || 'Error al guardar'
  }
}

async function doDelete() {
  try {
    await store.remove(deleteTarget.value.id)
    showDelete.value = false
  } catch (e) {
    showDelete.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────
function reprocannStatus(s) {
  if (!s.reprocann_vencimiento) return null
  const days = Math.floor((new Date(s.reprocann_vencimiento) - new Date()) / 86400000)
  if (days < 0)   return { label: 'Vencido',   color: 'danger',  days }
  if (days <= 30) return { label: `${days}d`,  color: 'warning', days }
  return { label: 'Vigente', color: 'success', days }
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function edad(fn) {
  if (!fn) return null
  const diff = Date.now() - new Date(fn).getTime()
  return Math.floor(diff / (1000 * 60 * 60 * 24 * 365.25))
}

// ── KPIs ──────────────────────────────────────────────────────────────
const kpis = computed(() => {
  const items = store.items
  const hoy   = new Date()
  const en30  = new Date(hoy.getTime() + 30 * 86400000)
  return {
    total:     items.length,
    activos:   items.filter(s => s.es_paciente).length,
    vencidos:  items.filter(s => s.reprocann_vencimiento && new Date(s.reprocann_vencimiento) < hoy).length,
    proximos:  items.filter(s => {
      if (!s.reprocann_vencimiento) return false
      const v = new Date(s.reprocann_vencimiento)
      return v >= hoy && v <= en30
    }).length,
  }
})

onMounted(() => store.fetch())
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">Pacientes</h1>
        <p class="text-muted small mb-0">Gestión de pacientes y trazabilidad Reprocann</p>
      </div>
      <button v-if="canEdit" class="btn btn-success" @click="openCreate">
        <i class="bi bi-person-plus me-1"></i> Nuevo paciente
      </button>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(13,110,253,.1)">👥</div>
            <div class="kpi-value">{{ kpis.total }}</div>
            <div class="kpi-label">Total pacientes</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.1)">✅</div>
            <div class="kpi-value">{{ kpis.activos }}</div>
            <div class="kpi-label">En tratamiento</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(255,193,7,.12)">⚠️</div>
            <div class="kpi-value">{{ kpis.proximos }}</div>
            <div class="kpi-label">Reprocann por vencer</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(220,53,69,.1)">❌</div>
            <div class="kpi-value">{{ kpis.vencidos }}</div>
            <div class="kpi-label">Reprocann vencido</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Búsqueda -->
    <div class="card border-0 shadow-sm mb-4">
      <div class="card-body">
        <div class="row g-3">
          <div class="col-12 col-md-6">
            <div class="input-group">
              <span class="input-group-text bg-transparent border-end-0">
                <i class="bi bi-search text-muted"></i>
              </span>
              <input
                v-model="search"
                @input="onSearchInput"
                class="form-control border-start-0"
                placeholder="Buscar por nombre, apellido, DNI o email…"
              />
            </div>
          </div>
          <div class="col-auto d-flex align-items-center">
            <span class="text-muted small">{{ store.items.length }} pacientes</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!store.items.length" class="text-center py-5 text-muted">
      <div class="fs-1 mb-3">👥</div>
      <h5>{{ search ? 'Sin resultados' : 'No hay pacientes todavía' }}</h5>
      <p class="small mb-3">{{ search ? 'Probá con otro término de búsqueda' : 'Registrá el primer paciente del club' }}</p>
      <button v-if="!search && canEdit" class="btn btn-success btn-sm" @click="openCreate">
        Nuevo paciente
      </button>
    </div>

    <!-- Tabla -->
    <div v-else class="card border-0 shadow-sm">
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0">
          <thead class="table-light">
          <tr>
            <th>Paciente</th>
            <th>DNI</th>
            <th>Contacto</th>
            <th>Reprocann</th>
            <th>Edad</th>
            <th></th>
          </tr>
          </thead>
          <tbody>
          <tr v-for="s in store.items" :key="s.id">
            <td>
              <RouterLink :to="`/socios/${s.id}`" class="fw-semibold text-decoration-none">
                {{ s.nombre }} {{ s.apellido }}
              </RouterLink>
              <div class="small text-muted" v-if="s.reprocann_numero">
                <i class="bi bi-card-text me-1"></i>{{ s.reprocann_numero }}
              </div>
            </td>
            <td class="font-monospace small">{{ s.dni || '—' }}</td>
            <td class="small">
              <div v-if="s.email">{{ s.email }}</div>
              <div v-if="s.telefono" class="text-muted">{{ s.telefono }}</div>
            </td>
            <td>
              <template v-if="s.reprocann_vencimiento">
                  <span
                    class="badge rounded-pill"
                    :class="`text-bg-${reprocannStatus(s)?.color}`"
                  >
                    {{ reprocannStatus(s)?.label }}
                  </span>
                <div class="small text-muted mt-1">{{ formatDate(s.reprocann_vencimiento) }}</div>
              </template>
              <span v-else class="text-muted small">Sin Reprocann</span>
            </td>
            <td class="small text-muted">
              {{ edad(s.fecha_nacimiento) ? edad(s.fecha_nacimiento) + ' años' : '—' }}
            </td>
            <td class="text-end">
              <RouterLink :to="`/socios/${s.id}`" class="btn btn-sm btn-outline-secondary me-1">
                <i class="bi bi-eye"></i>
              </RouterLink>
              <button v-if="canEdit" class="btn btn-sm btn-outline-primary me-1" @click="openEdit(s)">
                <i class="bi bi-pencil"></i>
              </button>
              <button v-if="canEdit" class="btn btn-sm btn-outline-danger" @click="openDelete(s)">
                <i class="bi bi-trash"></i>
              </button>
            </td>
          </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ===== MODAL CREAR / EDITAR ===== -->
    <div v-if="showModal" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editing ? 'Editar paciente' : 'Nuevo paciente' }}</h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">

            <div v-if="formError" class="alert alert-danger alert-dismissible d-flex align-items-center gap-2 mb-3">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ formError }}</span>
              <button class="btn-close" @click="formError=null"></button>
            </div>

            <!-- Datos personales -->
            <p class="fw-semibold small text-uppercase text-muted mb-2" style="letter-spacing:.05em">Datos personales</p>
            <div class="row g-3 mb-4">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Nombre <span class="text-danger">*</span></label>
                <input v-model.trim="form.nombre" class="form-control" :class="{'is-invalid':formErrors.nombre}" placeholder="Nombre" />
                <div class="invalid-feedback">{{ formErrors.nombre }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Apellido <span class="text-danger">*</span></label>
                <input v-model.trim="form.apellido" class="form-control" :class="{'is-invalid':formErrors.apellido}" placeholder="Apellido" />
                <div class="invalid-feedback">{{ formErrors.apellido }}</div>
              </div>
              <div class="col-md-4">
                <label class="form-label small fw-semibold">DNI <span class="text-danger">*</span></label>
                <input v-model.trim="form.dni" class="form-control" :class="{'is-invalid':formErrors.dni}" placeholder="Sin puntos" />
                <div class="invalid-feedback">{{ formErrors.dni }}</div>
              </div>
              <div class="col-md-4">
                <label class="form-label small fw-semibold">Fecha de nacimiento <span class="text-danger">*</span></label>
                <input v-model="form.fecha_nacimiento" type="date" class="form-control" :class="{'is-invalid':formErrors.fecha_nacimiento}" />
                <div class="invalid-feedback">{{ formErrors.fecha_nacimiento }}</div>
              </div>
              <div class="col-md-4">
                <label class="form-label small fw-semibold">Teléfono</label>
                <input v-model.trim="form.telefono" class="form-control" placeholder="+54 9 11..." />
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Email</label>
                <input v-model.trim="form.email" type="email" class="form-control" :class="{'is-invalid':formErrors.email}" placeholder="paciente@email.com" />
                <div class="invalid-feedback">{{ formErrors.email }}</div>
              </div>
            </div>

            <!-- Reprocann -->
            <p class="fw-semibold small text-uppercase text-muted mb-2" style="letter-spacing:.05em">Datos Reprocann</p>
            <div class="row g-3 mb-3">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Número Reprocann</label>
                <input v-model.trim="form.reprocann_numero" class="form-control" placeholder="Ej: REP-2024-001234" />
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Vencimiento Reprocann</label>
                <input v-model="form.reprocann_vencimiento" type="date" class="form-control" />
                <div class="form-text">El certificado tiene vigencia de 3 años (Res. 1780/2025)</div>
              </div>
            </div>

            <div class="form-check form-switch">
              <input v-model="form.es_paciente" class="form-check-input" type="checkbox" id="chkPaciente" role="switch" />
              <label class="form-check-label" for="chkPaciente">Paciente activo en tratamiento</label>
            </div>

          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="store.saving" @click="showModal=false">Cancelar</button>
            <button class="btn btn-success px-4" :disabled="store.saving" @click="save">
              <span v-if="store.saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editing ? 'Guardar cambios' : 'Crear paciente' }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showModal" class="modal-backdrop fade show" @click="showModal=false"></div>

    <!-- ===== MODAL ELIMINAR ===== -->
    <div v-if="showDelete" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0">
            <h5 class="modal-title text-danger">⚠️ Eliminar paciente</h5>
            <button class="btn-close" @click="showDelete=false"></button>
          </div>
          <div class="modal-body">
            <p>¿Seguro que querés eliminar a <strong>{{ deleteTarget?.nombre }} {{ deleteTarget?.apellido }}</strong>?</p>
            <p class="text-muted small mb-0">Se eliminará su historial de notas, indicaciones y dispensaciones.</p>
          </div>
          <div class="modal-footer border-0">
            <button class="btn btn-outline-secondary" :disabled="store.removing" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger" :disabled="store.removing" @click="doDelete">
              <span v-if="store.removing" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showDelete" class="modal-backdrop fade show" @click="showDelete=false"></div>

  </div>
</template>

<style scoped>
.kpi .card-body { padding: 1.25rem 1.5rem; }
.kpi-icon {
  width: 40px; height: 40px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center; font-size: 1.1rem;
}
.kpi-value { font-size: 1.8rem; font-weight: 700; line-height: 1; color: #1f2937; }
.kpi-label { font-size: .82rem; color: #6b7280; margin-top: .2rem; }
</style>
