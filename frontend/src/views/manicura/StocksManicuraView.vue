<template>
  <div class="sv">

    <div class="sv__header">
      <div class="sv__header-left">
        <div class="sv__eyebrow"><PackagePlus :size="14" :stroke-width="2" /> Inventario</div>
        <h1 class="sv__title">Stocks disponibles</h1>
        <p class="sv__sub">Stock regulatorio de todas las sedes del club.</p>
      </div>
    </div>

    <!-- Filtros -->
    <div class="sv__filters">
      <select v-model="filtroSede" class="sv__select">
        <option value="">Todas las sedes</option>
        <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
      </select>
      <select v-model="filtroForma" class="sv__select">
        <option value="">Todas las formas</option>
        <option value="flor_seca">Flor seca</option>
        <option value="hash">Hash</option>
        <option value="aceite">Aceite</option>
        <option value="tintura">Tintura</option>
        <option value="prensado">Prensado</option>
        <option value="otro">Otro</option>
      </select>
    </div>

    <div v-if="loading" class="sv__loading">
      <DsSpinner />
    </div>

    <div v-else-if="!stocksFiltrados.length" class="sv__empty">
      <div class="sv__empty-ico"><PackagePlus :size="40" :stroke-width="1.25" /></div>
      <p class="sv__empty-title">Sin stock disponible</p>
      <p class="sv__empty-sub">Los stocks se generan al cerrar el curado de un lote.</p>
    </div>

    <div v-else class="sv__table-wrap">
      <table class="sv__table">
        <thead>
          <tr>
            <th>Lote</th>
            <th>Sede</th>
            <th>Forma</th>
            <th class="sv__th-num">Cantidad</th>
            <th class="sv__th-num">Precio sugerido</th>
            <th>Fecha</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in stocksFiltrados" :key="s.id">
            <td>
              <span v-if="s.lote_id" class="sv__lote-codigo">{{ s.lote_codigo }}</span>
              <span v-else class="sv__ext">externo</span>
            </td>
            <td>{{ nombreSede(s.sede_id) }}</td>
            <td><span class="sv__forma">{{ formaLabel(s.forma_producto) }}</span></td>
            <td class="sv__td-num">
              <strong>{{ s.cantidad.toFixed(1) }}</strong> {{ s.unidad }}
            </td>
            <td class="sv__td-num">
              {{ s.precio_sugerido_ars ? `$${s.precio_sugerido_ars.toFixed(0)}` : '—' }}
            </td>
            <td class="sv__td-date">{{ fmtDate(s.created_at) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { PackagePlus } from 'lucide-vue-next'
import { listStocks, listSedes } from '../../lib/api.js'

const stocks = ref([])
const sedes  = ref([])
const loading = ref(true)
const filtroSede  = ref('')
const filtroForma = ref('')

const sedeMap = computed(() => Object.fromEntries(sedes.value.map(s => [s.id, s.nombre])))
function nombreSede(id) { return sedeMap.value[id] || '—' }

const FORMA_LABELS = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura',
  crema: 'Crema', capsula: 'Cápsula', comestible: 'Comestible', prensado: 'Prensado',
  otro: 'Otro', externo: 'Externo',
}
function formaLabel(f) { return FORMA_LABELS[f] || f }

function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

const stocksFiltrados = computed(() => {
  return stocks.value
    .filter(s => s.regulatorio)
    .filter(s => !filtroSede.value || s.sede_id == filtroSede.value)
    .filter(s => !filtroForma.value || s.forma_producto === filtroForma.value)
})

async function cargar() {
  loading.value = true
  try {
    const [stocksRes, sedesRes] = await Promise.all([
      listStocks({ canal: 'regulatorio' }),
      listSedes(),
    ])
    stocks.value = stocksRes.data
    sedes.value = sedesRes.data
  } catch {
    stocks.value = []
  } finally {
    loading.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.sv { padding: 2rem 1.75rem 3rem; max-width: 1100px; margin: 0 auto; }
@media (max-width: 768px) { .sv { padding: 1.25rem 1rem 2rem; } }

.sv__header { margin-bottom: 1.5rem; }
.sv__eyebrow {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: var(--fs-12); font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: #6B4FBE; margin-bottom: .4rem;
}
.sv__title { font-size: 1.75rem; font-weight: 800; color: var(--c-ink-900); margin: 0 0 .2rem; letter-spacing: -.03em; }
.sv__sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.sv__filters { display: flex; gap: var(--sp-3); margin-bottom: 1.25rem; flex-wrap: wrap; }
.sv__select {
  background: var(--c-paper); border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md); padding: 8px 12px;
  font-size: var(--fs-14); color: var(--c-ink-900);
  cursor: pointer;
}
.sv__select:focus { outline: none; border-color: #6B4FBE; }

.sv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

.sv__empty { text-align: center; padding: 4rem 2rem; }
.sv__empty-ico { color: var(--c-ink-300); margin-bottom: 1rem; display: flex; justify-content: center; }
.sv__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin: 0 0 .4rem; }
.sv__empty-sub { font-size: var(--fs-14); color: var(--c-ink-400); margin: 0; }

.sv__table-wrap { background: var(--c-paper); border: 1px solid var(--c-ink-200); border-radius: var(--r-xl); overflow-x: auto; }
.sv__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.sv__table th {
  font-size: var(--fs-12); font-weight: 700; text-transform: uppercase; letter-spacing: .05em;
  color: var(--c-ink-400); padding: .75rem 1rem;
  border-bottom: 1px solid var(--c-ink-100); text-align: left;
  white-space: nowrap; background: var(--c-ink-50);
}
.sv__table td { padding: .75rem 1rem; border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-700); vertical-align: middle; }
.sv__table tbody tr:last-child td { border-bottom: none; }
.sv__table tbody tr:hover td { background: var(--c-ink-50); }
.sv__th-num, .sv__td-num { text-align: right; }

.sv__lote-codigo { font-weight: 700; color: var(--c-ink-800); font-family: var(--font-mono); }
.sv__ext { font-size: var(--fs-12); color: var(--c-ink-400); font-style: italic; }
.sv__forma { font-size: var(--fs-12); background: var(--c-ink-100); color: var(--c-ink-600); padding: 2px 8px; border-radius: 999px; white-space: nowrap; }
.sv__td-date { white-space: nowrap; color: var(--c-ink-400); font-size: var(--fs-13); }
</style>
