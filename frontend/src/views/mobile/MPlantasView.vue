<template>
  <div class="mp">
    <div class="mp__header">
      <h1 class="mp__title">Plantas</h1>
      <button v-if="canCreate" class="mp__add-btn" @click="router.push('/plantas/nueva')">
        <i class="bi bi-plus-lg"></i>
      </button>
    </div>

    <div class="mp__filtros">
      <select v-model="filtroLote" class="mp__select" @change="pagina = 1">
        <option value="">Todos los lotes</option>
        <option v-for="l in lotesFiltro" :key="l.id" :value="l.id">{{ l.codigo }}</option>
      </select>
      <select v-model="filtroEstado" class="mp__select" @change="pagina = 1">
        <option value="">Todos los estados</option>
        <option v-for="e in ESTADOS" :key="e.value" :value="e.value">{{ e.label }}</option>
      </select>
    </div>

    <div v-if="loading" class="mp__loading">
      <i class="bi bi-arrow-repeat mp__spin"></i> Cargando…
    </div>
    <div v-else-if="!plantasFiltradas.length" class="mp__empty">
      <i class="bi bi-flower2 mp__empty-icon"></i>
      <p>Sin plantas</p>
    </div>

    <div v-else class="mp__list">
      <RouterLink
        v-for="p in pagePlants"
        :key="p.id"
        :to="`/m/planta/${p.id}`"
        class="mp__card"
      >
        <div class="mp__card-dot" :style="{ background: estadoColor(p.state) }"></div>
        <div class="mp__card-info">
          <div class="mp__card-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
          <div class="mp__card-meta">
            <span v-if="p.lote?.codigo" class="mp__lote-tag">{{ p.lote.codigo }}</span>
            <span v-if="p.genetica?.nombre" class="mp__gen">{{ p.genetica.nombre }}</span>
          </div>
        </div>
        <span class="mp__estado-label" :style="{ color: estadoColor(p.state) }">
          {{ estadoLabel(p.state) }}
        </span>
        <i class="bi bi-chevron-right mp__chevron"></i>
      </RouterLink>
    </div>

    <div v-if="totalPaginas > 1" class="mp__pager">
      <button :disabled="pagina <= 1" @click="pagina--" class="mp__pager-btn"><i class="bi bi-chevron-left"></i></button>
      <span class="mp__pager-info">{{ pagina }} / {{ totalPaginas }}</span>
      <button :disabled="pagina >= totalPaginas" @click="pagina++" class="mp__pager-btn"><i class="bi bi-chevron-right"></i></button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listPlants, listLotes } from '../../lib/api'
import { PLANT_STATES, pm } from '../../lib/loteHelpers'
import { useAuthStore } from '../../stores/auth'

const router = useRouter()
const auth   = useAuthStore()

const plantas  = ref([])
const lotesAll = ref([])
const loading  = ref(false)
const filtroLote   = ref('')
const filtroEstado = ref('')
const pagina   = ref(1)
const POR_PAG  = 15

const canCreate = computed(() => ['admin', 'supervisor', 'cultivador'].includes(auth.role))

// Filtra por estado de PLANTA (p.state), no de lote. Fuente: PLANT_STATES.
const ESTADOS = PLANT_STATES.map(s => ({ value: s, label: pm(s).label }))
const estadoColor = e => pm(e).color
const estadoLabel = e => pm(e).label

const lotesFiltro = computed(() => {
  const ids = new Set(plantas.value.map(p => p.lote_id || p.lote?.id).filter(Boolean))
  return lotesAll.value.filter(l => ids.has(l.id))
})

const plantasFiltradas = computed(() => {
  return plantas.value.filter(p => {
    const ml = !filtroLote.value   || (p.lote_id || p.lote?.id) === Number(filtroLote.value)
    const me = !filtroEstado.value || p.state === filtroEstado.value
    return ml && me
  })
})

const totalPaginas = computed(() => Math.max(1, Math.ceil(plantasFiltradas.value.length / POR_PAG)))
const pagePlants   = computed(() => {
  const s = (pagina.value - 1) * POR_PAG
  return plantasFiltradas.value.slice(s, s + POR_PAG)
})

onMounted(async () => {
  loading.value = true
  try {
    const [pr, lr] = await Promise.all([listPlants({ limite: 500 }), listLotes()])
    plantas.value  = pr.data?.data || pr.data || []
    lotesAll.value = lr.data || []
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.mp { padding: 0 0 1.5rem; }
.mp__header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1rem .5rem; }
.mp__title { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mp__add-btn { width: 36px; height: 36px; border-radius: 10px; background: #1b5e20; color: #fff; border: none; font-size: 1rem; display: flex; align-items: center; justify-content: center; cursor: pointer; }
.mp__filtros { display: flex; gap: .5rem; padding: 0 1rem .75rem; }
.mp__select { flex: 1; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .5rem .65rem; font-size: .78rem; color: #374151; outline: none; }
.mp__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.mp__spin { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.mp__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: var(--c-slate-400); font-size: .875rem; }
.mp__empty-icon { font-size: 2.5rem; }
.mp__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.mp__card { display: flex; align-items: center; gap: .75rem; background: #fff; border-radius: 14px; padding: .875rem; box-shadow: 0 1px 4px rgba(0,0,0,.07); text-decoration: none; -webkit-tap-highlight-color: transparent; }
.mp__card-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
.mp__card-info { flex: 1; min-width: 0; }
.mp__card-nombre { font-size: .9rem; font-weight: 700; color: var(--c-slate-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mp__card-meta { display: flex; align-items: center; gap: .4rem; margin-top: .15rem; }
.mp__lote-tag { font-family: monospace; font-size: .68rem; font-weight: 700; background: #f0fdf4; color: #15803d; padding: .1em .4em; border-radius: 4px; }
.mp__gen { font-size: .7rem; color: var(--c-slate-400); }
.mp__estado-label { font-size: .7rem; font-weight: 700; white-space: nowrap; flex-shrink: 0; }
.mp__chevron { color: #d1d5db; font-size: .8rem; flex-shrink: 0; }
.mp__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1rem; }
.mp__pager-btn { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; width: 38px; height: 38px; display: flex; align-items: center; justify-content: center; font-size: .9rem; color: #374151; cursor: pointer; }
.mp__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.mp__pager-info { font-size: .8rem; color: var(--c-slate-500); font-weight: 600; min-width: 50px; text-align: center; }
</style>
