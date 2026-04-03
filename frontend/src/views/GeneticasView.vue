<script setup>
import { ref, computed, onMounted } from 'vue'
import { listGeneticas, createGenetica, updateGenetica, deleteGenetica } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'

const auth    = useAuthStore()
const canEdit = computed(() => auth.role === 'admin')

// ── Estado ────────────────────────────────────────────────────────────
const geneticas    = ref([])
const loading      = ref(true)
const saving       = ref(false)
const deleting     = ref(false)
const error        = ref(null)
const showModal    = ref(false)
const showDelete   = ref(false)
const editingId    = ref(null)
const deleteTarget = ref(null)
const formError    = ref(null)

const search   = ref('')
const filterTipo = ref('')
const sortBy   = ref('nombre_asc')

// ── Helpers ───────────────────────────────────────────────────────────
const TIPO_META = {
  indica:    { label: 'Índica',    color: '#6f42c1', bg: 'rgba(111,66,193,.12)' },
  sativa:    { label: 'Sativa',    color: '#198754', bg: 'rgba(25,135,84,.12)'  },
  hibrida:   { label: 'Híbrida',   color: '#fd7e14', bg: 'rgba(253,126,20,.12)' },
  ruderalis: { label: 'Ruderalis', color: '#0dcaf0', bg: 'rgba(13,202,240,.12)' },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || { label: tipo || '—', color: '#6c757d', bg: 'rgba(108,117,125,.1)' } }

const DIFICULTAD_META = {
  facil:   { label: 'Fácil',   icon: '🟢' },
  media:   { label: 'Media',   icon: '🟡' },
  dificil: { label: 'Difícil', icon: '🔴' },
}
function difLabel(d) { return DIFICULTAD_META[d]?.label || '—' }
function difIcon(d)  { return DIFICULTAD_META[d]?.icon  || '' }

// ── KPIs ──────────────────────────────────────────────────────────────
const kpis = computed(() => ({
  total:     geneticas.value.length,
  indica:    geneticas.value.filter(g => g.tipo === 'indica').length,
  sativa:    geneticas.value.filter(g => g.tipo === 'sativa').length,
  hibrida:   geneticas.value.filter(g => g.tipo === 'hibrida').length,
  plantas:   geneticas.value.reduce((a, g) => a + (g.plantas_count || 0), 0),
}))

// ── Filtros ───────────────────────────────────────────────────────────
const filtered = computed(() => {
  let list = [...geneticas.value]

  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(g =>
      g.nombre?.toLowerCase().includes(q) ||
      g.origen?.toLowerCase().includes(q) ||
      g.descripcion?.toLowerCase().includes(q)
    )
  }
  if (filterTipo.value) list = list.filter(g => g.tipo === filterTipo.value)

  switch (sortBy.value) {
    case 'thc_desc':     list.sort((a,b) => (b.thc||0) - (a.thc||0)); break
    case 'plantas_desc': list.sort((a,b) => (b.plantas_count||0) - (a.plantas_count||0)); break
    case 'nombre_asc':
    default:             list.sort((a,b) => (a.nombre||'').localeCompare(b.nombre||''))
  }
  return list
})

const hasFilters = computed(() => search.value.trim() || filterTipo.value)
function clearFilters() { search.value = ''; filterTipo.value = ''; sortBy.value = 'nombre_asc' }

// ── Form ──────────────────────────────────────────────────────────────
function emptyForm() {
  return {
    nombre: '', tipo: '', thc: null, cbd: null,
    descripcion: '', origen: '',
    tiempo_floracion: null, rendimiento: null, altura: null,
    dificultad: '', disponible: true,
  }
}
const form       = ref(emptyForm())
const formErrors = ref({})

function validate() {
  const e = {}
  if (!form.value.nombre.trim()) e.nombre = 'El nombre es obligatorio'
  if (!form.value.tipo)          e.tipo   = 'Seleccioná un tipo'
  if (form.value.thc !== null && (form.value.thc < 0 || form.value.thc > 100))
    e.thc = 'Debe ser entre 0 y 100'
  if (form.value.cbd !== null && (form.value.cbd < 0 || form.value.cbd > 100))
    e.cbd = 'Debe ser entre 0 y 100'
  formErrors.value = e
  return !Object.keys(e).length
}

function openCreate() {
  editingId.value = null
  form.value      = emptyForm()
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function openEdit(gen) {
  editingId.value = gen.id
  form.value = {
    nombre:           gen.nombre           || '',
    tipo:             gen.tipo             || '',
    thc:              gen.thc              ?? null,
    cbd:              gen.cbd              ?? null,
    descripcion:      gen.descripcion      || '',
    origen:           gen.origen           || '',
    tiempo_floracion: gen.tiempo_floracion ?? null,
    rendimiento:      gen.rendimiento      ?? null,
    altura:           gen.altura           ?? null,
    dificultad:       gen.dificultad       || '',
    disponible:       gen.disponible       ?? true,
  }
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function openDelete(gen) {
  deleteTarget.value = gen
  showDelete.value   = true
}

// ── CRUD ──────────────────────────────────────────────────────────────
async function loadGeneticas() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await listGeneticas()
    geneticas.value = data
  } catch (e) {
    error.value = 'No se pudieron cargar las genéticas'
  } finally {
    loading.value = false
  }
}

async function handleSubmit() {
  if (!validate()) return
  saving.value    = true
  formError.value = null
  try {
    const payload = { ...form.value }
    Object.keys(payload).forEach(k => {
      if (payload[k] === '' || payload[k] === null) delete payload[k]
    })
    if (editingId.value) {
      const { data } = await updateGenetica(editingId.value, payload)
      const idx = geneticas.value.findIndex(g => g.id === editingId.value)
      if (idx !== -1) geneticas.value[idx] = data
    } else {
      const { data } = await createGenetica(payload)
      geneticas.value.unshift(data)
    }
    showModal.value = false
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally {
    saving.value = false
  }
}

async function handleDelete() {
  deleting.value = true
  try {
    await deleteGenetica(deleteTarget.value.id)
    geneticas.value = geneticas.value.filter(g => g.id !== deleteTarget.value.id)
    showDelete.value = false
  } catch (e) {
    console.error('Error eliminando:', e)
  } finally {
    deleting.value = false
  }
}

onMounted(loadGeneticas)
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">Genéticas</h1>
        <p class="text-muted small mb-0">Catálogo de cepas del club</p>
      </div>
      <button v-if="canEdit" class="btn btn-success" @click="openCreate">
        <i class="bi bi-plus-circle me-1"></i> Nueva genética
      </button>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.1)">🌿</div>
            <div class="kpi-value">{{ kpis.total }}</div>
            <div class="kpi-label">Total cepas</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(111,66,193,.1)">💜</div>
            <div class="kpi-value">{{ kpis.indica }}</div>
            <div class="kpi-label">Índica</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(25,135,84,.1)">💚</div>
            <div class="kpi-value">{{ kpis.sativa }}</div>
            <div class="kpi-label">Sativa</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(253,126,20,.1)">🧡</div>
            <div class="kpi-value">{{ kpis.hibrida }}</div>
            <div class="kpi-label">Híbrida</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(13,110,253,.1)">🪴</div>
            <div class="kpi-value">{{ kpis.plantas }}</div>
            <div class="kpi-label">Plantas activas</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Filtros -->
    <div class="card border-0 shadow-sm mb-4">
      <div class="card-body">
        <div class="row g-3">
          <div class="col-12 col-md-5">
            <div class="input-group">
              <span class="input-group-text bg-transparent border-end-0">
                <i class="bi bi-search text-muted"></i>
              </span>
              <input
                v-model="search"
                class="form-control border-start-0"
                placeholder="Buscar por nombre, origen, descripción…"
              />
            </div>
          </div>
          <div class="col-6 col-md-3">
            <select v-model="filterTipo" class="form-select">
              <option value="">Todos los tipos</option>
              <option v-for="(meta, key) in TIPO_META" :key="key" :value="key">
                {{ meta.label }}
              </option>
            </select>
          </div>
          <div class="col-6 col-md-3">
            <select v-model="sortBy" class="form-select">
              <option value="nombre_asc">Nombre A-Z</option>
              <option value="thc_desc">Mayor THC</option>
              <option value="plantas_desc">Más plantas</option>
            </select>
          </div>
          <div class="col-md-1 d-flex align-items-center">
            <button v-if="hasFilters" class="btn btn-sm btn-outline-secondary w-100" @click="clearFilters">
              <i class="bi bi-x-circle"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>

    <!-- Empty -->
    <div v-else-if="!filtered.length" class="text-center py-5 text-muted">
      <div class="fs-1 mb-3">🌿</div>
      <h5>{{ hasFilters ? 'Sin resultados' : 'No hay genéticas todavía' }}</h5>
      <p class="small mb-3">{{ hasFilters ? 'Probá ajustando los filtros' : 'Agregá la primera cepa al catálogo' }}</p>
      <button v-if="hasFilters" class="btn btn-sm btn-outline-secondary me-2" @click="clearFilters">Limpiar filtros</button>
      <button v-else-if="canEdit" class="btn btn-success btn-sm" @click="openCreate">Nueva genética</button>
    </div>

    <!-- Grid -->
    <div v-else class="row g-3">
      <div v-for="gen in filtered" :key="gen.id" class="col-12 col-sm-6 col-lg-4 col-xl-3">
        <div class="gen-card" :style="{ '--tipo-color': tipoMeta(gen.tipo).color, '--tipo-bg': tipoMeta(gen.tipo).bg }">

          <!-- Barra superior con color del tipo -->
          <div class="gen-card__bar"></div>

          <div class="gen-card__body">
            <!-- Header -->
            <div class="d-flex align-items-start justify-content-between gap-2 mb-3">
              <div class="flex-grow-1 min-w-0">
                <h6 class="fw-bold mb-0 text-truncate">{{ gen.nombre }}</h6>
                <span class="small fw-semibold" :style="{ color: tipoMeta(gen.tipo).color }">
                  {{ tipoMeta(gen.tipo).label }}
                </span>
              </div>
              <div class="d-flex gap-1 flex-shrink-0">
                <span v-if="!gen.disponible" class="badge text-bg-secondary" title="No disponible">
                  <i class="bi bi-pause-circle"></i>
                </span>
              </div>
            </div>

            <!-- THC / CBD -->
            <div class="d-flex gap-2 mb-3">
              <div class="thc-cbd-pill">
                <span class="label">THC</span>
                <span class="value">{{ gen.thc != null ? gen.thc + '%' : '—' }}</span>
              </div>
              <div class="thc-cbd-pill">
                <span class="label">CBD</span>
                <span class="value">{{ gen.cbd != null ? gen.cbd + '%' : '—' }}</span>
              </div>
            </div>

            <!-- Meta -->
            <div class="gen-meta small text-muted">
              <span v-if="gen.dificultad">{{ difIcon(gen.dificultad) }} {{ difLabel(gen.dificultad) }}</span>
              <span v-if="gen.plantas_count > 0">
                <i class="bi bi-flower2 me-1"></i>{{ gen.plantas_count }} plantas
              </span>
            </div>

            <!-- Acciones -->
            <div v-if="canEdit" class="gen-card__actions">
              <button class="btn btn-sm btn-outline-secondary flex-fill" @click.stop="openEdit(gen)">
                <i class="bi bi-pencil me-1"></i>Editar
              </button>
              <button class="btn btn-sm btn-outline-danger" @click.stop="openDelete(gen)" :disabled="gen.plantas_count > 0" :title="gen.plantas_count > 0 ? 'Tiene plantas activas' : 'Eliminar'">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Contador -->
    <div v-if="!loading && filtered.length" class="text-center text-muted small mt-4">
      Mostrando {{ filtered.length }} de {{ geneticas.length }} genéticas
    </div>

    <!-- ===== MODAL CREAR / EDITAR ===== -->
    <div v-if="showModal" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingId ? 'Editar genética' : 'Nueva genética' }}</h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">

            <div v-if="formError" class="alert alert-danger alert-dismissible d-flex align-items-center gap-2 mb-3">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ formError }}</span>
              <button class="btn-close" @click="formError=null"></button>
            </div>

            <div class="row g-3">

              <!-- Nombre -->
              <div class="col-12">
                <label class="form-label small fw-semibold">Nombre <span class="text-danger">*</span></label>
                <input
                  v-model.trim="form.nombre"
                  class="form-control"
                  :class="{ 'is-invalid': formErrors.nombre }"
                  placeholder="Ej: OG Kush, White Widow…"
                />
                <div class="invalid-feedback">{{ formErrors.nombre }}</div>
              </div>

              <!-- Tipo -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Tipo <span class="text-danger">*</span></label>
                <div class="d-flex flex-wrap gap-2">
                  <button
                    v-for="(meta, key) in TIPO_META" :key="key"
                    type="button"
                    class="btn btn-sm"
                    :class="form.tipo === key ? 'btn-dark' : 'btn-outline-secondary'"
                    :style="form.tipo === key ? { background: meta.color, borderColor: meta.color } : {}"
                    @click="form.tipo = key"
                  >
                    {{ meta.label }}
                  </button>
                </div>
                <div v-if="formErrors.tipo" class="text-danger small mt-1">{{ formErrors.tipo }}</div>
              </div>

              <!-- Dificultad -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Dificultad de cultivo</label>
                <div class="d-flex gap-2">
                  <button
                    v-for="(meta, key) in DIFICULTAD_META" :key="key"
                    type="button"
                    class="btn btn-sm flex-fill"
                    :class="form.dificultad === key ? 'btn-secondary' : 'btn-outline-secondary'"
                    @click="form.dificultad = form.dificultad === key ? '' : key"
                  >
                    {{ meta.icon }} {{ meta.label }}
                  </button>
                </div>
              </div>

              <!-- THC / CBD -->
              <div class="col-md-3">
                <label class="form-label small fw-semibold">THC (%)</label>
                <input
                  v-model.number="form.thc"
                  type="number" step="0.1" min="0" max="100"
                  class="form-control"
                  :class="{ 'is-invalid': formErrors.thc }"
                  placeholder="0.0"
                />
                <div class="invalid-feedback">{{ formErrors.thc }}</div>
              </div>
              <div class="col-md-3">
                <label class="form-label small fw-semibold">CBD (%)</label>
                <input
                  v-model.number="form.cbd"
                  type="number" step="0.1" min="0" max="100"
                  class="form-control"
                  :class="{ 'is-invalid': formErrors.cbd }"
                  placeholder="0.0"
                />
                <div class="invalid-feedback">{{ formErrors.cbd }}</div>
              </div>

              <!-- Tiempo floración / Rendimiento / Altura -->
              <div class="col-md-2">
                <label class="form-label small fw-semibold">Floración (días)</label>
                <input v-model.number="form.tiempo_floracion" type="number" min="1" class="form-control" placeholder="60" />
              </div>
              <div class="col-md-2">
                <label class="form-label small fw-semibold">Rendimiento (g)</label>
                <input v-model.number="form.rendimiento" type="number" min="0" class="form-control" placeholder="450" />
              </div>
              <div class="col-md-2">
                <label class="form-label small fw-semibold">Altura (cm)</label>
                <input v-model.number="form.altura" type="number" min="0" class="form-control" placeholder="120" />
              </div>

              <!-- Origen -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Origen</label>
                <input v-model.trim="form.origen" class="form-control" placeholder="Ej: California, Amsterdam…" />
              </div>

              <!-- Disponible -->
              <div class="col-md-6 d-flex align-items-end">
                <div class="form-check form-switch mb-1">
                  <input v-model="form.disponible" class="form-check-input" type="checkbox" id="chkDisponible" role="switch" />
                  <label class="form-check-label" for="chkDisponible">
                    Disponible para cultivo
                  </label>
                </div>
              </div>

              <!-- Descripción -->
              <div class="col-12">
                <label class="form-label small fw-semibold">Descripción</label>
                <textarea
                  v-model.trim="form.descripcion"
                  class="form-control"
                  rows="3"
                  placeholder="Características, efectos, sabor, aromas…"
                ></textarea>
              </div>

            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="btn btn-success px-4" :disabled="saving" @click="handleSubmit">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editingId ? 'Guardar cambios' : 'Crear genética' }}
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
            <h5 class="modal-title text-danger">⚠️ Eliminar genética</h5>
            <button class="btn-close" @click="showDelete=false"></button>
          </div>
          <div class="modal-body">
            <p>¿Seguro que querés eliminar <strong>{{ deleteTarget?.nombre }}</strong>?</p>
            <p class="text-muted small mb-0">Se marcará como inactiva. Las plantas que ya la tenían asignada no se verán afectadas.</p>
          </div>
          <div class="modal-footer border-0">
            <button class="btn btn-outline-secondary" :disabled="deleting" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger" :disabled="deleting" @click="handleDelete">
              <span v-if="deleting" class="spinner-border spinner-border-sm me-2"></span>
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
/* KPI */
.kpi .card-body { padding: 1.1rem 1.25rem; }
.kpi-icon {
  width: 38px; height: 38px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center; font-size: 1.1rem;
}
.kpi-value { font-size: 1.7rem; font-weight: 700; line-height: 1; color: #1f2937; }
.kpi-label { font-size: .8rem; color: #6b7280; margin-top: .15rem; }

/* Card genética */
.gen-card {
  background: white;
  border-radius: 14px;
  border: 1.5px solid rgba(0,0,0,.06);
  overflow: hidden;
  height: 100%;
  display: flex;
  flex-direction: column;
  transition: all .15s;
}
.gen-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 8px 24px rgba(0,0,0,.09);
  border-color: var(--tipo-color);
}
.gen-card__bar {
  height: 5px;
  background: var(--tipo-color);
}
.gen-card__body {
  padding: 1rem;
  flex: 1;
  display: flex;
  flex-direction: column;
}

/* THC/CBD pills */
.thc-cbd-pill {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: .5rem;
  border-radius: 8px;
  background: var(--tipo-bg);
}
.thc-cbd-pill .label {
  font-size: .65rem;
  font-weight: 700;
  text-transform: uppercase;
  color: var(--tipo-color);
  letter-spacing: .05em;
}
.thc-cbd-pill .value {
  font-size: 1.1rem;
  font-weight: 700;
  color: #1f2937;
}

/* Meta info */
.gen-meta {
  display: flex;
  flex-wrap: wrap;
  gap: .3rem .8rem;
  flex: 1;
  align-items: flex-end;
  margin-bottom: .75rem;
}

/* Acciones */
.gen-card__actions {
  display: flex;
  gap: .5rem;
  padding-top: .75rem;
  border-top: 1px solid rgba(0,0,0,.05);
}
</style>
