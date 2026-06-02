<template>
  <div class="sdv">
    <div class="sdv__toolbar">
      <h1 class="sdv__title">Stock</h1>
      <div class="sdv__filters">
        <select v-model="filtroForma" class="sdv__select">
          <option value="">Todos los productos</option>
          <option v-for="f in FORMAS" :key="f.value" :value="f.value">{{ f.label }}</option>
        </select>
      </div>
    </div>

    <div v-if="loading" class="sdv__skel-list">
      <div class="sdv__skel" v-for="n in 6" :key="n" />
    </div>

    <div v-else-if="!stocksFiltrados.length" class="sdv__empty">Sin stock disponible.</div>

    <div v-else class="sdv__table-wrap">
      <table class="sdv__table">
        <thead>
          <tr>
            <th>Producto</th>
            <th>Cepa</th>
            <th>Lote</th>
            <th>Sede</th>
            <th class="sdv__th-num">Disponible</th>
            <th class="sdv__th-num">P. sugerido</th>
            <th>Origen</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="s in stocksFiltrados" :key="s.id">
            <td class="sdv__td-forma">{{ formaLabel(s.forma_producto) }}</td>
            <td class="sdv__td-cepa">{{ s.genetica?.nombre ?? s.lote?.genetica?.nombre ?? '—' }}</td>
            <td class="sdv__td-mono">{{ s.lote_codigo ?? s.lote?.codigo ?? '—' }}</td>
            <td>{{ s.sede?.nombre ?? '—' }}</td>
            <td class="sdv__td-num" :class="{ 'sdv__td-bajo': s.cantidad < 5 }">
              {{ s.cantidad }}{{ s.unidad }}
            </td>
            <td class="sdv__td-num">{{ formatARS(s.precio_sugerido_ars) }}/{{ s.unidad }}</td>
            <td>{{ s.origen ?? '—' }}</td>
            <td class="sdv__td-etiqueta">
              <RouterLink :to="{ name: 'stock-etiqueta', params: { id: s.id } }" class="sdv__etiqueta-link" title="Ver etiqueta">🏷️</RouterLink>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { listStocks } from '../lib/api.js'
import { formaLabel, formatARS } from '../lib/formatters.js'

const FORMAS = [
  { value: 'flor_seca',  label: 'Flor seca' },
  { value: 'hash',       label: 'Hash' },
  { value: 'aceite',     label: 'Aceite' },
  { value: 'tintura',    label: 'Tintura' },
  { value: 'crema',      label: 'Crema' },
  { value: 'capsulas',   label: 'Cápsulas' },
  { value: 'comestible', label: 'Comestible' },
  { value: 'prensado',   label: 'Prensado' },
  { value: 'externo',    label: 'Externo' },
  { value: 'otro',       label: 'Otro' },
]

const loading     = ref(true)
const stocks      = ref([])
const filtroForma = ref('')

const stocksFiltrados = computed(() => {
  let s = stocks.value.filter(x => x.cantidad > 0 && x.estado !== 'pendiente_asignacion')
  if (filtroForma.value) s = s.filter(x => x.forma_producto === filtroForma.value)
  return s
})

onMounted(async () => {
  try {
    const { data } = await listStocks()
    stocks.value = data.stocks ?? data ?? []
  } catch {
    stocks.value = []
  } finally {
    loading.value = false
  }
})

</script>

<style scoped>
.sdv { padding: var(--sp-6) var(--sp-8); }

.sdv__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-5);
  flex-wrap: wrap;
}
.sdv__title { font-family: var(--font-display); font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); margin: 0; }

.sdv__select {
  padding: .5rem var(--sp-3);
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  color: var(--c-ink-900);
  background: #fff;
  cursor: pointer;
}
.sdv__select:focus { outline: none; border-color: var(--c-role-dispensador); }

.sdv__table-wrap { overflow-x: auto; }
.sdv__table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-14);
  background: #fff;
  border: 1px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  overflow: hidden;
}
.sdv__table th {
  text-align: left;
  font-size: var(--fs-12);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .04em;
  color: var(--c-ink-500);
  padding: var(--sp-3);
  background: var(--c-ink-100);
  border-bottom: 2px solid var(--c-ink-300);
}
.sdv__table td { padding: var(--sp-3); border-bottom: 1px solid var(--c-ink-100); color: var(--c-ink-900); }
.sdv__table tr:last-child td { border-bottom: none; }
.sdv__table tr:hover td { background: var(--c-leaf-50); }
.sdv__th-num, .sdv__td-num { text-align: right; }
.sdv__td-forma { font-weight: 600; }
.sdv__td-cepa  { font-size: var(--fs-13); color: var(--c-ink-600); font-style: italic; }
.sdv__td-mono  { font-family: var(--font-mono); font-size: var(--fs-13); color: var(--c-ink-700); }
.sdv__td-bajo  { color: var(--c-rust-600); font-weight: 700; }

.sdv__empty { font-size: var(--fs-14); color: var(--c-ink-500); padding: var(--sp-4) 0; }

.sdv__skel-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.sdv__skel { height: 44px; background: var(--c-ink-100); border-radius: var(--r-md); animation: pulse 1.4s ease-in-out infinite; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.5} }

@media (max-width: 767px) { .sdv { padding: var(--sp-4); } }
.sdv__td-etiqueta { width: 36px; text-align: center; }
.sdv__etiqueta-link { font-size: 1rem; text-decoration: none; cursor: pointer; }
</style>
