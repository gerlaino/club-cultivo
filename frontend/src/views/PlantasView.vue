<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { logger } from '../utils/logger.js'
import { useRouter } from 'vue-router'
import { listPlants, listLotes } from '../lib/api.js'
import { em } from '../lib/loteHelpers.js'
import { useAuthStore } from '../stores/auth.js'
import EmptyState from '../components/ui/EmptyState.vue'
import DsSpinner from '../design-system/components/Spinner.vue'

const router = useRouter()
const auth   = useAuthStore()

const plants  = ref([])
const lotes   = ref([])
const loading = ref(true)
const error   = ref(null)

const filters = ref({ state: '', lote_id: '', search: '' })
const sortBy  = ref('created_at_desc')

const STATE_META = {
  germinacion:{ label: 'Germinación', icon: '🌰', bg: '#E0F2FE', color: '#0369a1', bar: '#0284C7', kpiIcon: '🌰', kpiBg: 'rgba(3,105,161,.1)' },
  esqueje:    { label: 'Esqueje',     icon: '✂️',  bg: '#F3E8FF', color: '#7c3aed', bar: '#8b5cf6', kpiIcon: '✂️',  kpiBg: 'rgba(124,58,237,.1)' },
  vegetativo: { label: 'Vegetativo',  icon: '🌱', bg: '#E8F0EB', color: '#1A3D2E', bar: '#1b5e20', kpiIcon: '🌱', kpiBg: 'rgba(27,94,32,.1)'   },
  floracion:  { label: 'Floración',   icon: '🌸', bg: '#FEF3C7', color: '#92400e', bar: '#D97706', kpiIcon: '🌸', kpiBg: 'rgba(217,119,6,.12)'  },
  secado:     { label: 'Secado',      icon: '🍂', bg: '#FFF7ED', color: '#c2410c', bar: '#ea580c', kpiIcon: '🍂', kpiBg: 'rgba(194,65,12,.1)'   },
  cosechado:  { label: 'Cosechada',   icon: '🌿', bg: '#F4F8F5', color: '#1A3D2E', bar: '#3F6452', kpiIcon: '🌿', kpiBg: 'rgba(63,100,82,.1)'   },
  descartada: { label: 'Descartada',  icon: '🗑️', bg: '#FEF2F2', color: '#b91c1c', bar: '#ef4444', kpiIcon: '🗑️', kpiBg: 'rgba(185,28,28,.1)'   },
}

function sm(s) { return STATE_META[s] || { label: s || '—', icon: '•', bg: '#f3f4f6', color: '#374151', bar: '#94a3b8' } }

// Post-manicura la planta queda congelada en 'cosechado' (Plant no tiene curado/
// en_manicura/finalizado). Para el display usamos el estado del LOTE, que refleja
// la realidad. Devuelve el mismo shape que STATE_META.
const POST_COSECHA_LOTE = ['en_manicura', 'curado', 'finalizado']
function plantaMeta(p) {
  if (p.state === 'cosechado' && POST_COSECHA_LOTE.includes(p.lote?.estado)) {
    const m = em(p.lote.estado)
    return { label: m.label, icon: m.emoji, bg: m.bg, color: m.color, bar: m.color }
  }
  return sm(p.state)
}

// Alineado a Plant::STATES (backend). Orden de aparición en KPIs.
const KPI_STATES = ['germinacion', 'esqueje', 'vegetativo', 'floracion', 'secado', 'cosechado', 'descartada']

const kpis = computed(() => {
  const counts = {}
  for (const s of KPI_STATES) {
    counts[s] = plants.value.filter(p => p.state === s).length
  }
  return {
    total: plants.value.length,
    byState: KPI_STATES
      .filter(s => counts[s] > 0)
      .map(s => ({ state: s, count: counts[s], ...STATE_META[s] })),
  }
})

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
    case 'nombre_asc':    list.sort((a,b) => (a.nombre||'').localeCompare(b.nombre||'')); break
    case 'nombre_desc':   list.sort((a,b) => (b.nombre||'').localeCompare(a.nombre||'')); break
    case 'lote_asc':      list.sort((a,b) => (a.lote?.codigo||'').localeCompare(b.lote?.codigo||'')); break
    case 'lote_desc':     list.sort((a,b) => (b.lote?.codigo||'').localeCompare(a.lote?.codigo||'')); break
    case 'genetica_asc':  list.sort((a,b) => (a.genetica?.nombre||'').localeCompare(b.genetica?.nombre||'')); break
    case 'genetica_desc': list.sort((a,b) => (b.genetica?.nombre||'').localeCompare(a.genetica?.nombre||'')); break
    case 'dias_asc':      list.sort((a,b) => (a.dias_en_fase||0) - (b.dias_en_fase||0)); break
    case 'dias_desc':     list.sort((a,b) => (b.dias_en_fase||0) - (a.dias_en_fase||0)); break
    case 'fecha_asc':     list.sort((a,b) => new Date(a.created_at) - new Date(b.created_at)); break
    case 'fecha_desc':    list.sort((a,b) => new Date(b.created_at) - new Date(a.created_at)); break
    default:              list.sort((a,b) => new Date(b.created_at) - new Date(a.created_at))
  }
  return list
})

function formatFecha(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit' })
}

function clearFilters() {
  filters.value = { state: '', lote_id: '', search: '' }
  sortBy.value  = 'created_at_desc'
}

const hasFilters = computed(() =>
  filters.value.state || filters.value.lote_id || filters.value.search.trim()
)

// Paginación
const page    = ref(1)
const perPage = 10

const paginated  = computed(() => filtered.value.slice((page.value - 1) * perPage, page.value * perPage))
const totalPages = computed(() => Math.max(1, Math.ceil(filtered.value.length / perPage)))

watch(filtered, () => { page.value = 1 })

function onSort(col) {
  if (sortBy.value === col + '_asc') sortBy.value = col + '_desc'
  else sortBy.value = col + '_asc'
}
function sortIcon(col) {
  if (sortBy.value.startsWith(col + '_asc'))  return '↑'
  if (sortBy.value.startsWith(col + '_desc')) return '↓'
  return '↕'
}

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
      <div class="ptv__kpi ptv__kpi--total">
        <div class="ptv__kpi-icon" style="background:rgba(27,94,32,.1)">🌿</div>
        <div class="ptv__kpi-value">{{ kpis.total }}</div>
        <div class="ptv__kpi-label">Total plantas</div>
      </div>
      <div v-for="k in kpis.byState" :key="k.state" class="ptv__kpi">
        <div class="ptv__kpi-icon" :style="{ background: k.kpiBg }">{{ k.kpiIcon }}</div>
        <div class="ptv__kpi-value">{{ k.count }}</div>
        <div class="ptv__kpi-label">{{ k.label }}</div>
      </div>
    </div>

    <!-- Toolbar -->
    <div class="ptv__toolbar">
      <div class="ptv__search-wrap">
        <i class="bi bi-search ptv__search-icon"></i>
        <input
          v-model="filters.search"
          type="text"
          class="ptv__search"
          placeholder="Buscar por nombre, QR, lote, genética…"
        />
      </div>
      <select v-model="filters.lote_id" class="ptv__select">
        <option value="">Todos los lotes</option>
        <option v-for="l in lotes" :key="l.id" :value="l.id">{{ l.codigo }}</option>
      </select>
      <button v-if="hasFilters" class="ptv__clear" @click="clearFilters" title="Limpiar filtros">
        <i class="bi bi-x-lg"></i>
      </button>
    </div>

    <!-- Pills de estado -->
    <div class="ptv__pills">
      <button
        class="ptv__pill"
        :class="{ 'ptv__pill--active': filters.state === '' }"
        @click="filters.state = ''"
      >
        Todos {{ plants.length }}
      </button>
      <template v-for="(meta, key) in STATE_META" :key="key">
        <button
          v-if="plants.filter(p => p.state === key).length > 0"
          class="ptv__pill"
          :class="{ 'ptv__pill--active': filters.state === key }"
          @click="filters.state = filters.state === key ? '' : key"
        >
          {{ meta.icon }} {{ meta.label }} {{ plants.filter(p => p.state === key).length }}
        </button>
      </template>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="ptv__loading">
      <DsSpinner />
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

    <!-- Tabla -->
    <div v-else class="ptv__table-wrap">
      <table class="pt-table">
        <thead>
          <tr>
            <th>Estado</th>
            <th class="pt-table__sortable" @click="onSort('nombre')">
              Nombre <span class="pt-sort-icon">{{ sortIcon('nombre') }}</span>
            </th>
            <th class="pt-table__sortable" @click="onSort('lote')">
              Lote <span class="pt-sort-icon">{{ sortIcon('lote') }}</span>
            </th>
            <th class="pt-table__sortable pt-col-genetica" @click="onSort('genetica')">
              Genética <span class="pt-sort-icon">{{ sortIcon('genetica') }}</span>
            </th>
            <th class="pt-table__sortable pt-col-fecha" @click="onSort('fecha')">
              Creación <span class="pt-sort-icon">{{ sortIcon('fecha') }}</span>
            </th>
            <th class="pt-table__sortable pt-col-dias" @click="onSort('dias')">
              Días en fase <span class="pt-sort-icon">{{ sortIcon('dias') }}</span>
            </th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="plant in paginated"
            :key="plant.id"
            class="pt-table__row"
            @click="router.push('/plantas/' + plant.id)"
          >
            <td>
              <span class="pt-badge" :style="{ background: plantaMeta(plant).bg, color: plantaMeta(plant).color }">
                {{ plantaMeta(plant).icon }} {{ plantaMeta(plant).label }}
              </span>
            </td>
            <td>
              <span class="pt-nombre">{{ plant.nombre || `Planta #${plant.id}` }}</span>
            </td>
            <td>
              <span class="pt-lote">{{ plant.lote?.codigo || '—' }}</span>
            </td>
            <td class="pt-col-genetica">
              <span class="pt-genetica">{{ plant.genetica?.nombre || '—' }}</span>
            </td>
            <td class="pt-col-fecha">
              <span class="pt-fecha">{{ formatFecha(plant.created_at) }}</span>
            </td>
            <td class="pt-col-dias">
              <span v-if="plant.dias_en_fase != null" class="pt-dias-badge" :style="{ background: plantaMeta(plant).bg, color: plantaMeta(plant).color }">
                {{ plant.dias_en_fase }}d
              </span>
              <span v-else class="pt-dias-empty">—</span>
            </td>
            <td>
              <span class="pt-arrow">→</span>
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Paginación -->
      <div v-if="totalPages > 1" class="ptv__pagination">
        <button class="ptv__page-btn" @click="page--" :disabled="page <= 1">«</button>
        <span class="ptv__page-info">{{ page }} / {{ totalPages }}</span>
        <button class="ptv__page-btn" @click="page++" :disabled="page >= totalPages">»</button>
      </div>

      <!-- Contador -->
      <div class="ptv__count">{{ paginated.length }} de {{ filtered.length }} plantas</div>
    </div>

  </div>
</template>

<style scoped>
.ptv { padding: 2rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
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
.ptv__kpis { display: flex; flex-wrap: wrap; gap: 1rem; margin-bottom: 1.5rem; }
.ptv__kpi  { flex: 1 1 140px; min-width: 130px; max-width: 220px; }
.ptv__kpi--total { flex: 1 1 160px; }
.ptv__kpi { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; }
.ptv__kpi-icon  { width: 40px; height: 40px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; margin-bottom: .6rem; }
.ptv__kpi-value { font-size: 1.8rem; font-weight: 800; color: #0f172a; line-height: 1; }
.ptv__kpi-label { font-size: .78rem; color: #64748b; margin-top: .25rem; }

/* Toolbar */
.ptv__toolbar { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: .75rem; align-items: center; }
.ptv__search-wrap { position: relative; flex: 1; min-width: 200px; }
.ptv__search-icon { position: absolute; left: .65rem; top: 50%; transform: translateY(-50%); color: #94a3b8; font-size: .85rem; pointer-events: none; }
.ptv__search      { width: 100%; padding: .55rem .75rem .55rem 2rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; box-sizing: border-box; }
.ptv__search:focus { border-color: #1a3d2e; }
.ptv__select      { padding: .5rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .82rem; color: #374151; background: #fff; cursor: pointer; outline: none; }
.ptv__select:focus { border-color: #1a3d2e; }
.ptv__clear       { background: none; border: none; color: #94a3b8; padding: .4rem .6rem; cursor: pointer; border-radius: 6px; font-size: .9rem; transition: all .15s; }
.ptv__clear:hover { background: #f1f5f9; color: #475569; }

/* Pills de estado */
.ptv__pills { display: flex; gap: .3rem; flex-wrap: wrap; margin-bottom: 1.25rem; }
.ptv__pill {
  background: none; border: 1.5px solid #e2e8f0; color: #6b7280;
  padding: .35rem .75rem; border-radius: 99px; font-size: .78rem; font-weight: 500;
  cursor: pointer; transition: all .15s; white-space: nowrap;
}
.ptv__pill:hover { border-color: #94a3b8; color: #1e293b; }
.ptv__pill--active { background: #1a3d2e; border-color: #1a3d2e; color: #fff; }

/* Loading / Error */
.ptv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.ptv__error { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: .875rem 1rem; border-radius: 10px; margin-bottom: 1rem; }

/* Table wrap */
.ptv__table-wrap { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden; }

/* Table */
.pt-table { width: 100%; border-collapse: collapse; font-size: .875rem; }
.pt-table thead th {
  padding: 10px 12px; text-align: left; font-weight: 600; color: #6b7280;
  border-bottom: 2px solid #e5e7eb; white-space: nowrap; background: #fafafa;
}
.pt-table__sortable { cursor: pointer; user-select: none; }
.pt-table__sortable:hover { color: #1e293b; }
.pt-sort-icon { font-size: .75rem; color: #94a3b8; margin-left: .2rem; }
.pt-table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; }
.pt-table tbody tr:last-child { border-bottom: none; }
.pt-table__row { cursor: pointer; }
.pt-table__row:hover { background: #f8fafc; }
.pt-table td { padding: 10px 12px; vertical-align: middle; }

/* Cell styles */
.pt-badge      { display: inline-flex; align-items: center; gap: .3rem; padding: .2rem .6rem; border-radius: 99px; font-size: .72rem; font-weight: 600; white-space: nowrap; }
.pt-nombre     { font-weight: 600; color: #1e293b; }
.pt-lote       { font-size: .82rem; color: #374151; font-weight: 500; }
.pt-genetica   { font-size: .82rem; color: #374151; }
.pt-fecha      { font-size: .8rem; color: #64748b; font-variant-numeric: tabular-nums; }
.pt-dias-badge { display: inline-flex; align-items: center; padding: .15rem .5rem; border-radius: 99px; font-size: .72rem; font-weight: 700; }
.pt-dias-empty { font-size: .82rem; color: #cbd5e1; }
.pt-arrow      { color: #cbd5e1; opacity: 0; transition: opacity .15s; font-size: .9rem; }
.pt-table__row:hover .pt-arrow { opacity: 1; color: #64748b; }

/* Pagination */
.ptv__pagination { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: .75rem 1rem; border-top: 1px solid #f1f5f9; }
.ptv__page-btn { background: #fff; border: 1.5px solid #e2e8f0; color: #374151; padding: .35rem .75rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.ptv__page-btn:hover:not(:disabled) { background: #f8fafc; border-color: #94a3b8; }
.ptv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.ptv__page-info { font-size: .82rem; color: #64748b; min-width: 60px; text-align: center; }

/* Counter */
.ptv__count { padding: .6rem 1rem; font-size: .75rem; color: #94a3b8; border-top: 1px solid #f1f5f9; text-align: right; }

/* Responsive */
@media (max-width: 640px) {
  .pt-col-genetica, .pt-col-fecha { display: none; }
  .pt-arrow { opacity: 1; }
}
</style>
