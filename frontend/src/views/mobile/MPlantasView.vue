<template>
  <div class="mpl">
    <div class="mpl__topbar">
      <h1 class="mpl__title">Plantas</h1>
      <button v-if="canCreate" class="mpl__fab" @click="irNuevaPlanta">
        <i class="bi bi-plus-lg"></i>
      </button>
    </div>

    <!-- Filtro por lote -->
    <div class="mpl__filter">
      <select v-model="filterLote" class="mpl__select">
        <option value="">Todos los lotes</option>
        <option v-for="l in lotesActivos" :key="l.id" :value="l.id">{{ l.codigo }}</option>
      </select>
      <select v-model="filterEstado" class="mpl__select">
        <option value="">Todos los estados</option>
        <option v-for="e in ESTADOS" :key="e.value" :value="e.value">{{ e.label }}</option>
      </select>
    </div>

    <div v-if="loading" class="mpl__loading">Cargando…</div>
    <div v-else-if="!plantasMostradas.length" class="mpl__empty">
      <i class="bi bi-flower2"></i>
      <p>Sin plantas{{ filterLote ? ' en este lote' : '' }}</p>
    </div>

    <div v-else class="mpl__list">
      <RouterLink
        v-for="p in plantasMostradas"
        :key="p.id"
        :to="`/m/planta/${p.id}`"
        class="mpl__card"
      >
        <div class="mpl__card-dot" :style="{ background: estadoColor(p.state) }"></div>
        <div class="mpl__card-body">
          <div class="mpl__card-top">
            <span class="mpl__nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</span>
            <span class="mpl__badge" :style="{ background: estadoColor(p.state) + '20', color: estadoColor(p.state) }">
              {{ estadoLabel(p.state) }}
            </span>
          </div>
          <div class="mpl__card-meta">
            <span v-if="p.lote?.codigo" class="mpl__lote">📦 {{ p.lote.codigo }}</span>
            <span v-if="p.genetica?.nombre" class="mpl__meta-sep">·</span>
            <span v-if="p.genetica?.nombre">{{ p.genetica.nombre }}</span>
          </div>
        </div>
        <!-- Acceso rápido a registrar -->
        <div class="mpl__registrar-btn" @click.prevent="irRegistrar(p.id)">
          <i class="bi bi-pencil-square"></i>
        </div>
      </RouterLink>
    </div>

    <!-- Paginador simple -->
    <div v-if="totalPaginas > 1" class="mpl__paginador">
      <button class="mpl__pag-btn" :disabled="pagina <= 1" @click="pagina--">
        <i class="bi bi-chevron-left"></i>
      </button>
      <span class="mpl__pag-info">{{ pagina }} / {{ totalPaginas }}</span>
      <button class="mpl__pag-btn" :disabled="pagina >= totalPaginas" @click="pagina++">
        <i class="bi bi-chevron-right"></i>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { usePlantsStore } from '../../stores/plants'
import { useLotesStore }  from '../../stores/lotes'
import { useAuthStore }   from '../../stores/auth'
import { listPlants } from '../../lib/api'

const router     = useRouter()
const plantsStore = usePlantsStore()
const lotesStore  = useLotesStore()
const auth        = useAuthStore()

const filterLote   = ref('')
const filterEstado = ref('')
const pagina       = ref(1)
const porPagina    = 15
const loading      = ref(false)
const plantas      = ref([])

const canCreate = computed(() => ['admin', 'supervisor', 'cultivador'].includes(auth.role))

const ESTADOS = [
  { value: 'semilla',     label: 'Semilla' },
  { value: 'esqueje',     label: 'Esqueje' },
  { value: 'vegetativo',  label: 'Vegetativo' },
  { value: 'floracion',   label: 'Floración' },
  { value: 'cosecha',     label: 'Cosecha' },
  { value: 'en_manicura', label: 'Manicura' },
  { value: 'secado',      label: 'Secado' },
  { value: 'curado',      label: 'Curado' },
]

const ESTADO_COLORS = {
  semilla: '#64748b', esqueje: '#0891b2', vegetativo: '#16a34a',
  floracion: '#9333ea', cosecha: '#dc2626', en_manicura: '#d97706',
  secado: '#d97706', curado: '#2563eb',
}
function estadoColor(e) { return ESTADO_COLORS[e] || '#64748b' }
function estadoLabel(e)  { return ESTADOS.find(x => x.value === e)?.label || e || '—' }

const lotesActivos = computed(() => lotesStore.items.filter(l => l.estado !== 'finalizado'))

const plantasFiltradas = computed(() => {
  return plantas.value.filter(p => {
    const matchLote   = !filterLote.value   || p.lote?.id === filterLote.value || p.lote_id === filterLote.value
    const matchEstado = !filterEstado.value || p.state === filterEstado.value
    return matchLote && matchEstado
  })
})

const totalPaginas   = computed(() => Math.max(1, Math.ceil(plantasFiltradas.value.length / porPagina)))
const plantasMostradas = computed(() => {
  const start = (pagina.value - 1) * porPagina
  return plantasFiltradas.value.slice(start, start + porPagina)
})

function irNuevaPlanta() { router.push('/m/planta/nueva') }
function irRegistrar(id) { router.push(`/m/planta/${id}`) }

onMounted(async () => {
  loading.value = true
  try {
    const [plantasRes] = await Promise.all([
      listPlants({ limite: 500 }),
      lotesStore.fetchAll?.(),
    ])
    plantas.value = plantasRes.data?.data || plantasRes.data || []
  } catch {} finally {
    loading.value = false
  }
})
</script>

<style scoped>
.mpl { padding: 0 0 1rem; }

.mpl__topbar { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1rem .5rem; }
.mpl__title { font-size: 1.1rem; font-weight: 800; color: #0f2417; margin: 0; }
.mpl__fab { width: 38px; height: 38px; border-radius: 12px; background: #1b5e20; color: #fff; border: none; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; cursor: pointer; flex-shrink: 0; }

.mpl__filter { display: flex; gap: .5rem; padding: 0 1rem .75rem; }
.mpl__select { flex: 1; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .5rem .75rem; font-size: .8rem; color: #374151; outline: none; }

.mpl__loading, .mpl__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: #94a3b8; font-size: .875rem; }
.mpl__empty i { font-size: 2rem; }

.mpl__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.mpl__card { display: flex; align-items: center; background: #fff; border-radius: 14px; box-shadow: 0 1px 4px rgba(0,0,0,.07); text-decoration: none; overflow: hidden; -webkit-tap-highlight-color: transparent; }
.mpl__card-dot { width: 5px; align-self: stretch; flex-shrink: 0; }
.mpl__card-body { flex: 1; padding: .8rem .75rem; min-width: 0; }
.mpl__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .25rem; }
.mpl__nombre { font-size: .9rem; font-weight: 700; color: #0f172a; flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpl__badge { font-size: .62rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; white-space: nowrap; flex-shrink: 0; }
.mpl__card-meta { display: flex; align-items: center; gap: .35rem; font-size: .7rem; color: #64748b; }
.mpl__lote { font-family: monospace; font-weight: 600; }
.mpl__meta-sep { color: #cbd5e1; }

/* Botón registrar inline */
.mpl__registrar-btn {
  padding: .8rem 1rem; color: #1b5e20; font-size: 1.1rem;
  display: flex; align-items: center; flex-shrink: 0;
  border-left: 1px solid #f0fdf4;
  -webkit-tap-highlight-color: transparent;
}

/* Paginador */
.mpl__paginador { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1rem; }
.mpl__pag-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; width: 38px; height: 38px; display: flex; align-items: center; justify-content: center; font-size: .9rem; color: #374151; cursor: pointer; }
.mpl__pag-btn:disabled { opacity: .4; cursor: not-allowed; }
.mpl__pag-info { font-size: .8rem; color: #64748b; font-weight: 600; }
</style>
