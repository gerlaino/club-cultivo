<script setup>
import { ref, computed, onMounted } from 'vue'
import { logger } from '../utils/logger.js'
import { useRouter } from 'vue-router'
import { listPlants, listLotes } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import EmptyState from '../components/ui/EmptyState.vue'

const router = useRouter()
const auth   = useAuthStore()

const plants  = ref([])
const lotes   = ref([])
const loading = ref(true)
const error   = ref(null)

const filters = ref({ state: '', lote_id: '', search: '' })
const sortBy  = ref('created_at_desc')

const STATE_META = {
  germinacion: { label: 'Germinación', icon: '🌰', bg: '#E0F2FE', color: '#0369a1', bar: '#0284C7' },
  vegetativo:  { label: 'Vegetativo',  icon: '🌱', bg: '#E8F0EB', color: '#1A3D2E', bar: '#1b5e20' },
  floracion:   { label: 'Floración',   icon: '🌸', bg: '#FEF3C7', color: '#92400e', bar: '#D97706' },
  secado:      { label: 'Secado',      icon: '🍂', bg: '#F3F4F6', color: '#374151', bar: '#6B7280' },
  cosechado:   { label: 'Cosechado',   icon: '✂️',  bg: '#F4F8F5', color: '#1A3D2E', bar: '#3F6452' },
}

function sm(s) { return STATE_META[s] || { label: s || '—', icon: '•', bg: '#f3f4f6', color: '#374151', bar: '#94a3b8' } }
function stateLabel(s)      { return sm(s).label }
function stateIcon(s)       { return sm(s).icon }
function stateBadgeStyle(s) { const m = sm(s); return { background: m.bg, color: m.color } }
function stateBarStyle(s)   { return { background: sm(s).bar } }

const kpis = computed(() => ({
  total:      plants.value.length,
  vegetativo: plants.value.filter(p => p.state === 'vegetativo').length,
  floracion:  plants.value.filter(p => p.state === 'floracion').length,
  cosechado:  plants.value.filter(p => p.state === 'cosechado').length,
}))

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
    case 'nombre_asc': list.sort((a,b) => (a.nombre||'').localeCompare(b.nombre||'')); break
    case 'dias_desc':  list.sort((a,b) => (b.dias_desde_germinacion||0) - (a.dias_desde_germinacion||0)); break
    default:           list.sort((a,b) => new Date(b.created_at) - new Date(a.created_at))
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

async function loadPlants() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await listPlants()
    plants.value = data
  } catch (e) {
    error.value = 'No se pudieron cargar las plantas'
    logger.error(e)
  } finally {
    loading.value = false
  }
}

async function loadLotes() {
  try {
    const { data } = await listLotes()
    lotes.value = data
  } catch (e) {
    logger.error('Error cargando lotes:', e)
  }
}

onMounted(() => Promise.all([loadPlants(), loadLotes()]))
</script>

<template>
  <div class="ptv">

    <!-- Header -->
    <div class="ptv__header">
      <div>
        <h1 class="ptv__title">Plantas</h1>
        <p class="ptv__sub">Trazabilidad seed-to-sale del cultivo</p>
      </div>
      <RouterLink to="/plantas/nueva" class="ptv__btn-new">
        <i class="bi bi-plus-lg"></i> Nueva planta
      </RouterLink>
    </div>

    <!-- KPIs -->
    <div class="ptv__kpis">
      <div class="ptv__kpi">
        <div class="ptv__kpi-icon" style="background:rgba(27,94,32,.1)">🌿</div>
        <div class="ptv__kpi-value">{{ kpis.total }}</div>
        <div class="ptv__kpi-label">Total plantas</div>
      </div>
      <div class="ptv__kpi">
        <div class="ptv__kpi-icon" style="background:rgba(27,94,32,.1)">🌱</div>
        <div class="ptv__kpi-value">{{ kpis.vegetativo }}</div>
        <div class="ptv__kpi-label">Vegetativo</div>
      </div>
      <div class="ptv__kpi">
        <div class="ptv__kpi-icon" style="background:rgba(217,119,6,.12)">🌸</div>
        <div class="ptv__kpi-value">{{ kpis.floracion }}</div>
        <div class="ptv__kpi-label">Floración</div>
      </div>
      <div class="ptv__kpi">
        <div class="ptv__kpi-icon" style="background:rgba(107,114,128,.1)">✂️</div>
        <div class="ptv__kpi-value">{{ kpis.cosechado }}</div>
        <div class="ptv__kpi-label">Cosechadas</div>
      </div>
    </div>

    <!-- Filtros -->
    <div class="ptv__filters">
      <div class="ptv__search-wrap">
        <i class="bi bi-search ptv__search-icon"></i>
        <input
          v-model="filters.search"
          type="text"
          class="ptv__search"
          placeholder="Buscar por nombre, QR, lote, genética…"
        />
      </div>
      <select v-model="filters.state" class="ptv__select">
        <option value="">Todos los estados</option>
        <option v-for="(meta, key) in STATE_META" :key="key" :value="key">
          {{ meta.icon }} {{ meta.label }}
        </option>
      </select>
      <select v-model="filters.lote_id" class="ptv__select">
        <option value="">Todos los lotes</option>
        <option v-for="l in lotes" :key="l.id" :value="l.id">{{ l.codigo }}</option>
      </select>
      <select v-model="sortBy" class="ptv__select">
        <option value="created_at_desc">Más recientes</option>
        <option value="nombre_asc">Nombre A-Z</option>
        <option value="dias_desc">Más días</option>
      </select>
      <button v-if="hasFilters" class="ptv__clear" @click="clearFilters" title="Limpiar filtros">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="ptv__loading">
      <div class="ptv__spinner"></div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="ptv__error">{{ error }}</div>

    <!-- Empty -->
    <EmptyState
      v-else-if="!filtered.length"
      icon="🌿"
      :title="hasFilters ? 'Sin resultados' : 'No hay plantas todavía'"
      :message="hasFilters ? 'Probá ajustando los filtros' : 'Registrá tu primera planta para comenzar la trazabilidad'"
    >
      <template #actions>
        <button v-if="hasFilters" class="ptv__btn-ghost" @click="clearFilters">Limpiar filtros</button>
        <RouterLink v-else to="/plantas/nueva" class="ptv__btn-new">Nueva planta</RouterLink>
      </template>
    </EmptyState>

    <!-- Grid -->
    <div v-else class="ptv__grid">
      <div
        v-for="plant in filtered"
        :key="plant.id"
        class="plant-card"
        @click="router.push(`/plantas/${plant.id}`)"
      >
        <div class="plant-card__bar" :style="stateBarStyle(plant.state)"></div>
        <div class="plant-card__body">
          <div class="plant-card__top">
            <span class="plant-card__badge" :style="stateBadgeStyle(plant.state)">
              {{ stateIcon(plant.state) }} {{ stateLabel(plant.state) }}
            </span>
            <span class="plant-card__qr">{{ plant.codigo_qr || '—' }}</span>
          </div>
          <h6 class="plant-card__name">{{ plant.nombre || `Planta #${plant.id}` }}</h6>
          <div class="plant-card__meta">
            <span><i class="bi bi-box-seam"></i> {{ plant.lote?.codigo || '—' }}</span>
            <span v-if="plant.genetica"><i class="bi bi-diagram-3"></i> {{ plant.genetica.nombre }}</span>
            <span v-if="plant.dias_desde_germinacion">
              <i class="bi bi-calendar"></i> {{ plant.dias_desde_germinacion }} días
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Contador -->
    <div v-if="!loading && filtered.length" class="ptv__count">
      Mostrando {{ filtered.length }} de {{ plants.length }} plantas
    </div>

  </div>
</template>

<style scoped>
.ptv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; }
@media (max-width: 768px) { .ptv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.ptv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.ptv__title  { font-size: 1.5rem; font-weight: 700; color: #0f172a; margin: 0; }
.ptv__sub    { font-size: .82rem; color: #64748b; margin: .15rem 0 0; }

/* Buttons */
.ptv__btn-new  { display: inline-flex; align-items: center; gap: .4rem; background: #1a3d2e; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; text-decoration: none; transition: background .15s; white-space: nowrap; }
.ptv__btn-new:hover  { background: #0f2a1e; color: #fff; }
.ptv__btn-ghost { background: #fff; border: 1.5px solid #e2e8f0; color: #64748b; padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; cursor: pointer; }
.ptv__btn-ghost:hover { background: #f8fafc; }

/* KPIs */
.ptv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.5rem; }
@media (max-width: 640px) { .ptv__kpis { grid-template-columns: repeat(2, 1fr); } }
.ptv__kpi { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; }
.ptv__kpi-icon  { width: 40px; height: 40px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; margin-bottom: .6rem; }
.ptv__kpi-value { font-size: 1.8rem; font-weight: 800; color: #0f172a; line-height: 1; }
.ptv__kpi-label { font-size: .78rem; color: #64748b; margin-top: .25rem; }

/* Filtros */
.ptv__filters     { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: 1.5rem; align-items: center; }
.ptv__search-wrap { position: relative; flex: 1; min-width: 200px; }
.ptv__search-icon { position: absolute; left: .65rem; top: 50%; transform: translateY(-50%); color: #94a3b8; font-size: .85rem; pointer-events: none; }
.ptv__search      { width: 100%; padding: .55rem .75rem .55rem 2rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; box-sizing: border-box; }
.ptv__search:focus { border-color: #1a3d2e; }
.ptv__select      { padding: .5rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .82rem; color: #374151; background: #fff; cursor: pointer; outline: none; }
.ptv__select:focus { border-color: #1a3d2e; }
.ptv__clear       { background: none; border: none; color: #94a3b8; padding: .4rem .6rem; cursor: pointer; border-radius: 6px; font-size: .9rem; transition: all .15s; }
.ptv__clear:hover { background: #f1f5f9; color: #475569; }

/* Loading / Error */
.ptv__loading { display: flex; justify-content: center; padding: 3rem; }
.ptv__spinner { width: 28px; height: 28px; border: 3px solid #e2e8f0; border-top-color: #1a3d2e; border-radius: 50%; animation: ptv-spin .8s linear infinite; }
@keyframes ptv-spin { to { transform: rotate(360deg); } }
.ptv__error { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: .875rem 1rem; border-radius: 10px; margin-bottom: 1rem; }

/* Plant grid */
.ptv__grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }
@media (max-width: 900px) { .ptv__grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 560px) { .ptv__grid { grid-template-columns: 1fr; } }

/* Plant card */
.plant-card { background: #fff; border-radius: 12px; border: 1.5px solid #e2e8f0; overflow: hidden; cursor: pointer; transition: all .15s; }
.plant-card:hover { transform: translateY(-3px); box-shadow: 0 6px 20px rgba(0,0,0,.1); border-color: #1b5e20; }
.plant-card__bar  { height: 4px; }
.plant-card__body { padding: 1rem; }
.plant-card__top  { display: flex; justify-content: space-between; align-items: flex-start; gap: .5rem; margin-bottom: .5rem; }
.plant-card__badge { display: inline-flex; align-items: center; gap: .3rem; padding: .2rem .6rem; border-radius: 99px; font-size: .72rem; font-weight: 600; }
.plant-card__qr   { font-family: monospace; font-size: .68rem; color: #94a3b8; white-space: nowrap; }
.plant-card__name { font-size: .9rem; font-weight: 700; color: #0f172a; margin: 0 0 .5rem; }
.plant-card__meta { display: flex; flex-wrap: wrap; gap: .3rem .7rem; font-size: .78rem; color: #6b7280; }
.plant-card__meta i { margin-right: .15rem; }

/* Counter */
.ptv__count { text-align: center; color: #94a3b8; font-size: .78rem; margin-top: 1.5rem; }
</style>
