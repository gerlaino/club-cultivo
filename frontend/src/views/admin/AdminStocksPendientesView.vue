<template>
  <div class="asp">
    <div class="asp__header">
      <div>
        <h1 class="asp__title">Stocks pendientes de asignación</h1>
        <p class="asp__sub">Asignación de stock cosechado a sedes del club</p>
      </div>
      <RouterLink to="/" class="asp__back"><i class="bi bi-arrow-left"></i> Dashboard</RouterLink>
    </div>

    <div v-if="loading" class="asp__loading">
      <div class="asp__ring"></div> Cargando stocks…
    </div>

    <div v-else-if="!stocks.length" class="asp__empty">
      <i class="bi bi-check-circle-fill asp__empty-ico"></i>
      <div class="asp__empty-title">Sin stocks pendientes</div>
      <div class="asp__empty-sub">Todo el stock cosechado ya fue asignado a una sede.</div>
    </div>

    <div v-else class="asp__list">
      <div v-for="s in stocks" :key="s.id" class="asp__item">
        <div class="asp__item-info">
          <div class="asp__item-name">{{ formaLabel(s.forma_producto) }}</div>
          <div class="asp__item-meta">
            <span class="asp__chip">{{ s.cantidad }} g</span>
            <span class="asp__chip asp__chip--lote">
              <i class="bi bi-box me-1"></i>{{ s.lote?.codigo || `Lote #${s.lote_id}` }}
            </span>
            <span v-if="s.lote?.genetica" class="asp__chip asp__chip--gen">{{ s.lote.genetica.nombre }}</span>
          </div>
        </div>

        <div class="asp__item-action">
          <select v-model="asignaciones[s.id]" class="asp__select">
            <option value="">Pool del club (delivery)</option>
            <option v-for="sede in sedes" :key="sede.id" :value="sede.id">{{ sede.nombre }}</option>
          </select>
          <button
            class="asp__btn"
            :disabled="asignando === s.id"
            @click="asignar(s)"
          >
            <span v-if="asignando === s.id" class="asp__spinner"></span>
            <i v-else class="bi bi-check-lg"></i>
            Asignar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listStocksPendientes, asignarStock, listSedes } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast  = useToast()
const stocks = ref([])
const sedes  = ref([])
const loading   = ref(true)
const asignando = ref(null)
const asignaciones = ref({})

const FORMA_LABELS = {
  flor_seca:  'Flor seca',
  pre_roll:   'Pre-roll',
  extracto:   'Extracto',
  tintura:    'Tintura',
  comestible: 'Comestible',
  topico:     'Tópico',
  otro:       'Otro',
}
function formaLabel(f) { return FORMA_LABELS[f] || f || 'Stock' }

onMounted(async () => {
  try {
    const [resStocks, resSedes] = await Promise.all([listStocksPendientes(), listSedes()])
    stocks.value = resStocks.data || []
    sedes.value  = resSedes.data  || []
    stocks.value.forEach(s => { asignaciones.value[s.id] = '' })
  } catch (e) {
    toast.error('Error al cargar stocks')
  } finally {
    loading.value = false
  }
})

async function asignar(stock) {
  asignando.value = stock.id
  try {
    const sede_id = asignaciones.value[stock.id] || null
    await asignarStock(stock.id, { sede_id })
    stocks.value = stocks.value.filter(s => s.id !== stock.id)
    toast.success(`Stock asignado correctamente`)
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al asignar')
  } finally {
    asignando.value = null
  }
}
</script>

<style scoped>
.asp { padding: 2rem 1.75rem 3rem; max-width: 860px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 640px) { .asp { padding: 1.25rem 1rem 2rem; } }

.asp__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.asp__title { font-size: 1.5rem; font-weight: 800; letter-spacing: -.04em; margin: 0 0 .2rem; }
.asp__sub { font-size: .83rem; color: #64748b; margin: 0; }
.asp__back { display: inline-flex; align-items: center; gap: .4rem; color: #64748b; font-size: .82rem; font-weight: 500; text-decoration: none; padding: .45rem .875rem; border: 1.5px solid #e2e8f0; border-radius: 8px; transition: all .15s; }
.asp__back:hover { color: #0f172a; border-color: #cbd5e1; background: #f8fafc; }

.asp__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem; color: #94a3b8; justify-content: center; }
.asp__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: asp-spin .7s linear infinite; flex-shrink: 0; }
@keyframes asp-spin { to { transform: rotate(360deg); } }

.asp__empty { text-align: center; padding: 4rem 1rem; }
.asp__empty-ico { font-size: 3rem; color: #15803d; display: block; margin-bottom: 1rem; }
.asp__empty-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin-bottom: .35rem; }
.asp__empty-sub { font-size: .85rem; color: #64748b; }

.asp__list { display: flex; flex-direction: column; gap: .875rem; }
.asp__item {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 1.125rem 1.25rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.25rem;
  flex-wrap: wrap;
}
.asp__item-info { flex: 1; min-width: 0; }
.asp__item-name { font-size: .95rem; font-weight: 700; color: #0f172a; margin-bottom: .4rem; }
.asp__item-meta { display: flex; flex-wrap: wrap; gap: .4rem; }
.asp__chip { font-size: .72rem; font-weight: 600; padding: .2em .65em; border-radius: 5px; background: #f1f5f9; color: #475569; border: 1px solid #e2e8f0; }
.asp__chip--lote { background: rgba(8,145,178,.08); color: #0369a1; border-color: rgba(8,145,178,.2); }
.asp__chip--gen { background: rgba(21,128,61,.08); color: #15803d; border-color: rgba(21,128,61,.2); }

.asp__item-action { display: flex; align-items: center; gap: .6rem; flex-shrink: 0; }
.asp__select {
  padding: .45rem .75rem;
  border: 1.5px solid #e2e8f0;
  border-radius: 8px;
  font-size: .82rem;
  color: #0f172a;
  background: #fff;
  cursor: pointer;
  min-width: 180px;
}
.asp__select:focus { outline: none; border-color: #1b5e20; }
.asp__btn {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .5rem 1rem; border-radius: 8px;
  font-size: .82rem; font-weight: 600; cursor: pointer;
  transition: background .15s; white-space: nowrap;
}
.asp__btn:hover:not(:disabled) { background: #144a18; }
.asp__btn:disabled { opacity: .55; cursor: not-allowed; }
.asp__spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: asp-spin .6s linear infinite; }
</style>
