<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listPlants, listLotes } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'

const router = useRouter()
const auth   = useAuthStore()

const plants  = ref([])
const lotes   = ref([])
const loading = ref(true)
const error   = ref(null)

const filters = ref({ state: '', lote_id: '', search: '' })
const sortBy  = ref('created_at_desc')

// ── Helpers ───────────────────────────────────────────────────────────
const STATE_META = {
  germinacion: { label: 'Germinación', color: 'primary',   icon: '🌰' },
  vegetativo:  { label: 'Vegetativo',  color: 'success',   icon: '🌱' },
  floracion:   { label: 'Floración',   color: 'warning',   icon: '🌸' },
  secado:      { label: 'Secado',      color: 'secondary', icon: '🍂' },
  cosechado:   { label: 'Cosechado',   color: 'purple',    icon: '✂️'  },
}
function sm(state)       { return STATE_META[state] || { label: state || '—', color: 'secondary', icon: '•' } }
function stateLabel(s)   { return sm(s).label }
function stateColor(s)   { return sm(s).color }
function stateIcon(s)    { return sm(s).icon }

// ── KPIs ──────────────────────────────────────────────────────────────
const kpis = computed(() => ({
  total:       plants.value.length,
  vegetativo:  plants.value.filter(p => p.state === 'vegetativo').length,
  floracion:   plants.value.filter(p => p.state === 'floracion').length,
  cosechado:   plants.value.filter(p => p.state === 'cosechado').length,
}))

// ── Filtros + ordenamiento ────────────────────────────────────────────
const filtered = computed(() => {
  let list = [...plants.value]

  if (filters.value.search.trim()) {
    const q = filters.value.search.toLowerCase()
    list = list.filter(p =>
        p.nombre?.toLowerCase().includes(q) ||
        p.codigo_qr?.toLowerCase().includes(q) ||
        p.lote?.codigo?.toLowerCase().includes(q) ||
        p.genetica?.nombre?.toLowerCase().includes(q)
    )
  }
  if (filters.value.state)   list = list.filter(p => p.state === filters.value.state)
  if (filters.value.lote_id) list = list.filter(p => p.lote?.id === Number(filters.value.lote_id))

  switch (sortBy.value) {
    case 'nombre_asc':  list.sort((a,b) => (a.nombre||'').localeCompare(b.nombre||'')); break
    case 'dias_desc':   list.sort((a,b) => (b.dias_desde_germinacion||0) - (a.dias_desde_germinacion||0)); break
    case 'created_at_desc':
    default:
      list.sort((a,b) => new Date(b.created_at) - new Date(a.created_at))
  }
  return list
})

function clearFilters() {
  filters.value = { state: '', lote_id: '', search: '' }
  sortBy.value  = 'created_at_desc'
}

const hasFilters = computed(() =>
    filters.value.state || filters.value.lote_id || filters.value.search.trim()
)

// ── Carga ─────────────────────────────────────────────────────────────
async function loadPlants() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await listPlants()
    plants.value = data
  } catch (e) {
    error.value = 'No se pudieron cargar las plantas'
    console.error(e)
  } finally {
    loading.value = false
  }
}

async function loadLotes() {
  try {
    const { data } = await listLotes()
    lotes.value = data
  } catch (e) {
    console.error('Error cargando lotes:', e)
  }
}

onMounted(() => Promise.all([loadPlants(), loadLotes()]))
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">Plantas</h1>
        <p class="text-muted small mb-0">Trazabilidad seed-to-sale del cultivo</p>
      </div>
      <RouterLink to="/plantas/nueva" class="btn btn-success">
        <i class="bi bi-plus-circle me-1"></i> Nueva planta
      </RouterLink>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.1)">🌿</div>
            <div class="kpi-value">{{ kpis.total }}</div>
            <div class="kpi-label">Total plantas</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.1)">🌱</div>
            <div class="kpi-value">{{ kpis.vegetativo }}</div>
            <div class="kpi-label">Vegetativo</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(255,193,7,.12)">🌸</div>
            <div class="kpi-value">{{ kpis.floracion }}</div>
            <div class="kpi-label">Floración</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="kpi card border-0 h-100">
          <div class="card-body">
            <div class="kpi-icon mb-2" style="background:rgba(108,117,125,.1)">✂️</div>
            <div class="kpi-value">{{ kpis.cosechado }}</div>
            <div class="kpi-label">Cosechadas</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Filtros -->
    <div class="card border-0 shadow-sm mb-4">
      <div class="card-body">
        <div class="row g-3">
          <div class="col-12 col-md-4">
            <div class="input-group">
              <span class="input-group-text bg-transparent border-end-0">
                <i class="bi bi-search text-muted"></i>
              </span>
              <input
                  v-model="filters.search"
                  type="text"
                  class="form-control border-start-0"
                  placeholder="Buscar por nombre, QR, lote, genética…"
              />
            </div>
          </div>
          <div class="col-6 col-md-2">
            <select v-model="filters.state" class="form-select">
              <option value="">Todos los estados</option>
              <option v-for="(meta, key) in STATE_META" :key="key" :value="key">
                {{ meta.icon }} {{ meta.label }}
              </option>
            </select>
          </div>
          <div class="col-6 col-md-3">
            <select v-model="filters.lote_id" class="form-select">
              <option value="">Todos los lotes</option>
              <option v-for="l in lotes" :key="l.id" :value="l.id">{{ l.codigo }}</option>
            </select>
          </div>
          <div class="col-6 col-md-2">
            <select v-model="sortBy" class="form-select">
              <option value="created_at_desc">Más recientes</option>
              <option value="nombre_asc">Nombre A-Z</option>
              <option value="dias_desc">Más días</option>
            </select>
          </div>
          <div class="col-6 col-md-1 d-flex align-items-center">
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
      <h5>{{ hasFilters ? 'Sin resultados' : 'No hay plantas todavía' }}</h5>
      <p class="small mb-3">
        {{ hasFilters ? 'Probá ajustando los filtros' : 'Registrá tu primera planta para comenzar la trazabilidad' }}
      </p>
      <button v-if="hasFilters" class="btn btn-sm btn-outline-secondary me-2" @click="clearFilters">
        Limpiar filtros
      </button>
      <RouterLink v-else to="/plantas/nueva" class="btn btn-success btn-sm">
        Nueva planta
      </RouterLink>
    </div>

    <!-- Grid -->
    <div v-else class="row g-3">
      <div v-for="plant in filtered" :key="plant.id" class="col-12 col-sm-6 col-lg-4">
        <div class="plant-card" @click="router.push(`/plantas/${plant.id}`)">
          <!-- Barra de color superior -->
          <div class="plant-card__bar" :class="`bar-${plant.state}`"></div>

          <div class="plant-card__body">
            <div class="d-flex justify-content-between align-items-start mb-2">
              <span class="badge rounded-pill px-2" :class="`text-bg-${stateColor(plant.state)}`">
                {{ stateIcon(plant.state) }} {{ stateLabel(plant.state) }}
              </span>
              <span class="font-monospace text-muted" style="font-size:.72rem">
                {{ plant.codigo_qr || '—' }}
              </span>
            </div>

            <h6 class="fw-bold mb-1">{{ plant.nombre || `Planta #${plant.id}` }}</h6>

            <div class="plant-card__meta">
              <span><i class="bi bi-box-seam me-1"></i>{{ plant.lote?.codigo || '—' }}</span>
              <span v-if="plant.genetica"><i class="bi bi-diagram-3 me-1"></i>{{ plant.genetica.nombre }}</span>
              <span v-if="plant.dias_desde_germinacion">
                <i class="bi bi-calendar me-1"></i>{{ plant.dias_desde_germinacion }} días
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Contador -->
    <div v-if="!loading && filtered.length" class="text-center text-muted small mt-4">
      Mostrando {{ filtered.length }} de {{ plants.length }} plantas
    </div>

  </div>
</template>

<style scoped>
.kpi .card-body { padding: 1.25rem 1.5rem; }
.kpi-icon {
  width: 40px; height: 40px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.2rem;
}
.kpi-value { font-size: 1.8rem; font-weight: 700; line-height: 1; color: #1f2937; }
.kpi-label { font-size: .82rem; color: #6b7280; margin-top: .2rem; }

.plant-card {
  background: white;
  border-radius: 12px;
  border: 1.5px solid rgba(0,0,0,.06);
  overflow: hidden;
  cursor: pointer;
  transition: all .15s;
}
.plant-card:hover {
  transform: translateY(-3px);
  box-shadow: 0 6px 20px rgba(0,0,0,.1);
  border-color: var(--brand-primary, #1b5e20);
}
.plant-card__bar {
  height: 4px;
}
.bar-germinacion { background: #0d6efd; }
.bar-vegetativo  { background: #198754; }
.bar-floracion   { background: #ffc107; }
.bar-secado      { background: #6c757d; }
.bar-cosechado   { background: #6f42c1; }

.plant-card__body { padding: 1rem; }

.plant-card__meta {
  display: flex;
  flex-wrap: wrap;
  gap: .4rem .8rem;
  font-size: .8rem;
  color: #6b7280;
  margin-top: .5rem;
}

/* badge cosechado */
.text-bg-purple { background: #6f42c1 !important; color: white !important; }
</style>
