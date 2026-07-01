<template>
  <div class="hcv">

    <!-- Header -->
    <div class="hcv__header">
      <div>
        <h1 class="hcv__title">Historial</h1>
        <p class="hcv__sub">Todo lo que registraste: tareas completadas, cambios de estado, notas</p>
      </div>
      <div v-if="!loading && total" class="hcv__header-stat">
        <span class="hcv__stat-num">{{ total }}</span>
        <span class="hcv__stat-label">registro{{ total !== 1 ? 's' : '' }}</span>
      </div>
    </div>

    <!-- Filtros -->
    <div class="hcv__filters">
      <div class="hcv__search-wrap">
        <Search :size="14" class="hcv__search-ico" />
        <input
          v-model="searchInput"
          class="hcv__search"
          type="text"
          placeholder="Buscar por tarea, lote, sala…"
          @input="onSearch"
        />
        <button v-if="searchInput" class="hcv__search-clear" @click="clearSearch">
          <X :size="13" />
        </button>
      </div>
      <div class="hcv__tipo-tabs">
        <button
          v-for="tab in TIPO_TABS"
          :key="tab.value"
          class="hcv__tab"
          :class="{ 'hcv__tab--active': tipoFiltro === tab.value }"
          @click="setTipo(tab.value)"
        >{{ tab.label }}</button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="hcv__loading">
      <div v-for="i in 8" :key="i" class="hcv__skeleton"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!items.length" class="hcv__empty">
      <div class="hcv__empty-icon">📋</div>
      <p class="hcv__empty-title">Sin registros</p>
      <p class="hcv__empty-sub">{{ q || tipoFiltro !== 'todos' ? 'Ningún resultado para estos filtros.' : 'Todavía no hay actividad registrada.' }}</p>
    </div>

    <!-- Tabla -->
    <template v-else>
      <div class="hcv__table-wrap">
        <table class="hcv__table">
          <thead>
            <tr>
              <th class="hcv__th hcv__th--tipo">Tipo</th>
              <th class="hcv__th hcv__th--desc">Descripción</th>
              <th class="hcv__th hcv__th--lote">Lote</th>
              <th class="hcv__th hcv__th--sala">Sala</th>
              <th class="hcv__th hcv__th--estado">Estado</th>
              <th class="hcv__th hcv__th--fecha">Fecha</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in items" :key="item.id" class="hcv__tr" @click="onRowClick(item)">

              <!-- Tipo badge -->
              <td class="hcv__td hcv__td--tipo">
                <span class="hcv__tipo-badge" :class="`hcv__tipo-badge--${item.tipo}`">
                  <span class="hcv__tipo-emoji">{{ tipoEmoji(item) }}</span>
                  <span class="hcv__tipo-label">{{ tipoLabel(item) }}</span>
                </span>
              </td>

              <!-- Descripción -->
              <td class="hcv__td hcv__td--desc">
                <span class="hcv__desc">{{ item.titulo }}</span>
                <span v-if="item.descripcion" class="hcv__desc-sub">{{ item.descripcion }}</span>
              </td>

              <!-- Lote -->
              <td class="hcv__td hcv__td--lote">
                <span v-if="item.lote" class="hcv__lote-pill">{{ item.lote.codigo }}</span>
                <span v-else class="hcv__none">—</span>
              </td>

              <!-- Sala -->
              <td class="hcv__td hcv__td--sala">
                <span v-if="item.sala" class="hcv__sala">{{ item.sala.nombre }}</span>
                <span v-else class="hcv__none">—</span>
              </td>

              <!-- Estado (solo tareas) -->
              <td class="hcv__td hcv__td--estado">
                <span v-if="item.estado" class="hcv__estado-pill" :class="`hcv__estado-pill--${item.estado}`">
                  {{ estadoLabel(item.estado) }}
                </span>
                <span v-else class="hcv__none">—</span>
              </td>

              <!-- Fecha -->
              <td class="hcv__td hcv__td--fecha">
                <span class="hcv__fecha">{{ formatFecha(item.fecha) }}</span>
                <span class="hcv__hora">{{ formatHora(item.fecha) }}</span>
              </td>

            </tr>
          </tbody>
        </table>
      </div>

      <!-- Paginación -->
      <div v-if="totalPaginas > 1" class="hcv__pager">
        <button class="hcv__pager-btn" :disabled="page === 1" @click="goPage(page - 1)">
          <ChevronLeft :size="15" />
        </button>
        <div class="hcv__pager-pages">
          <button
            v-for="p in paginas"
            :key="p"
            class="hcv__pager-num"
            :class="{ 'hcv__pager-num--active': p === page, 'hcv__pager-num--ellipsis': p === '…' }"
            :disabled="p === '…'"
            @click="p !== '…' && goPage(p)"
          >{{ p }}</button>
        </div>
        <button class="hcv__pager-btn" :disabled="page === totalPaginas" @click="goPage(page + 1)">
          <ChevronRight :size="15" />
        </button>
        <span class="hcv__pager-info">{{ desde }}–{{ hasta }} de {{ total }}</span>
      </div>
    </template>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getHistorial } from '../lib/api.js'
import { ChevronLeft, ChevronRight, Search, X } from 'lucide-vue-next'

const router = useRouter()

const PER_PAGE = 30

const loading      = ref(true)
const items        = ref([])
const total        = ref(0)
const page         = ref(1)
const tipoFiltro   = ref('todos')
const q            = ref('')
const searchInput  = ref('')

let searchTimer = null

const TIPO_TABS = [
  { value: 'todos',       label: 'Todos' },
  { value: 'tarea',       label: 'Tareas' },
  { value: 'lote_evento', label: 'Eventos de lote' },
]

const TIPO_META_TAREA = {
  riego:       { emoji: '💧', label: 'Riego' },
  poda:        { emoji: '✂️', label: 'Poda' },
  medicion:    { emoji: '📏', label: 'Medición' },
  limpieza:    { emoji: '🧹', label: 'Limpieza' },
  cosecha:     { emoji: '🌿', label: 'Cosecha' },
  trasplante: { emoji: '🪴', label: 'Trasplante' },
  inspeccion:  { emoji: '🔍', label: 'Inspección' },
  otro:        { emoji: '📋', label: 'Tarea' },
}

const SUBTIPO_EVENTO = {
  cambio_estado:   { emoji: '🔄', label: 'Cambio estado' },
  movimiento_sala: { emoji: '📦', label: 'Movimiento' },
  nota:            { emoji: '📝', label: 'Nota' },
}

function tipoEmoji(item) {
  if (item.tipo === 'tarea') return TIPO_META_TAREA[item.subtipo]?.emoji || '📋'
  return SUBTIPO_EVENTO[item.subtipo]?.emoji || '🗒️'
}
function tipoLabel(item) {
  if (item.tipo === 'tarea') return TIPO_META_TAREA[item.subtipo]?.label || 'Tarea'
  return SUBTIPO_EVENTO[item.subtipo]?.label || 'Evento'
}

function estadoLabel(e) {
  return { completada: 'Completada', cancelada: 'Cancelada', en_progreso: 'En progreso', pendiente: 'Pendiente' }[e] || e
}

function formatFecha(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}
function formatHora(iso) {
  if (!iso) return ''
  return new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

const totalPaginas = computed(() => Math.ceil(total.value / PER_PAGE))
const desde        = computed(() => (page.value - 1) * PER_PAGE + 1)
const hasta        = computed(() => Math.min(page.value * PER_PAGE, total.value))

const paginas = computed(() => {
  const tot = totalPaginas.value
  const cur = page.value
  if (tot <= 7) return Array.from({ length: tot }, (_, i) => i + 1)
  const pages = new Set([1, tot, cur, cur - 1, cur + 1].filter(p => p >= 1 && p <= tot))
  const sorted = [...pages].sort((a, b) => a - b)
  const result = []
  for (let i = 0; i < sorted.length; i++) {
    if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.push('…')
    result.push(sorted[i])
  }
  return result
})

async function fetch() {
  loading.value = true
  try {
    const { data } = await getHistorial({ page: page.value, tipo: tipoFiltro.value, q: q.value || undefined })
    items.value = data.items || []
    total.value = data.total || 0
  } finally {
    loading.value = false
  }
}

function goPage(p) {
  page.value = p
  fetch()
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

function setTipo(t) {
  tipoFiltro.value = t
  page.value = 1
  fetch()
}

function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    q.value = searchInput.value
    page.value = 1
    fetch()
  }, 350)
}

function clearSearch() {
  searchInput.value = ''
  q.value = ''
  page.value = 1
  fetch()
}

function onRowClick(item) {
  if (item.lote?.id) router.push({ name: 'lote-detail', params: { id: item.lote.id } })
}

onMounted(fetch)
</script>

<style scoped>
.hcv { padding: 1.5rem 1.25rem; max-width: 1280px; margin: 0 auto; }
@media (max-width: 640px) { .hcv { padding: 1rem .75rem; } }

/* Header */
.hcv__header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 1.5rem; gap: 1rem; }
.hcv__title  { font-size: 1.5rem; font-weight: 700; color: #0f2611; margin: 0 0 .25rem; }
.hcv__sub    { font-size: .85rem; color: #60725d; margin: 0; }
.hcv__header-stat { display: flex; flex-direction: column; align-items: flex-end; flex-shrink: 0; padding-top: 2px; }
.hcv__stat-num   { font-size: 2rem; font-weight: 700; color: #1b5e20; line-height: 1; }
.hcv__stat-label { font-size: .72rem; color: #60725d; text-transform: uppercase; letter-spacing: .06em; font-weight: 600; }

/* Filters */
.hcv__filters { display: flex; align-items: center; gap: .75rem; margin-bottom: 1.25rem; flex-wrap: wrap; }

.hcv__search-wrap { position: relative; flex: 1; min-width: 220px; max-width: 360px; }
.hcv__search-ico  { position: absolute; left: .75rem; top: 50%; transform: translateY(-50%); color: #60725d; pointer-events: none; }
.hcv__search {
  width: 100%; box-sizing: border-box;
  padding: .6rem .75rem .6rem 2.25rem;
  background: #fff; border: 1.5px solid #e8f0e9; border-radius: 9px;
  font-size: .875rem; color: #0f2611;
  transition: border .15s, box-shadow .15s;
}
.hcv__search:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.hcv__search-clear {
  position: absolute; right: .6rem; top: 50%; transform: translateY(-50%);
  background: #e8f0e9; border: none; border-radius: 50%; width: 20px; height: 20px;
  display: flex; align-items: center; justify-content: center; cursor: pointer; color: #60725d;
}
.hcv__search-clear:hover { background: #c8e6c9; color: #0f2611; }

.hcv__tipo-tabs { display: flex; background: #f6faf6; border-radius: 9px; padding: 3px; border: 1px solid #e8f0e9; }
.hcv__tab { padding: .4rem .85rem; border-radius: 7px; border: none; background: none; font-size: .78rem; font-weight: 600; color: #60725d; cursor: pointer; transition: all .15s; white-space: nowrap; }
.hcv__tab--active { background: #fff; color: #1b5e20; box-shadow: 0 1px 3px rgba(0,0,0,.08); }

/* Loading */
.hcv__loading { display: flex; flex-direction: column; gap: .4rem; margin-top: .5rem; }
.hcv__skeleton { height: 52px; border-radius: 10px; background: linear-gradient(90deg, #f0f4f0 25%, #e4ebe4 50%, #f0f4f0 75%); background-size: 200% 100%; animation: hcv-shimmer 1.4s ease infinite; }
.hcv__skeleton:nth-child(n+3) { opacity: calc(1 - (var(--i, 0) * 0.12)); }
@keyframes hcv-shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }

/* Empty */
.hcv__empty { display: flex; flex-direction: column; align-items: center; gap: .75rem; padding: 4rem 1.5rem; text-align: center; }
.hcv__empty-icon  { font-size: 2.5rem; line-height: 1; }
.hcv__empty-title { font-size: 1rem; font-weight: 700; color: #0f2611; margin: 0; }
.hcv__empty-sub   { font-size: .85rem; color: #60725d; margin: 0; max-width: 360px; line-height: 1.6; }

/* Table */
.hcv__table-wrap { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; margin-bottom: 1.25rem; }
.hcv__table      { width: 100%; border-collapse: collapse; font-size: .85rem; }
.hcv__th {
  padding: .75rem 1rem; background: #f6faf6; font-weight: 600; color: #0f2611;
  text-align: left; border-bottom: 1px solid #e8f0e9; font-size: .78rem; white-space: nowrap;
}
.hcv__th--tipo   { width: 140px; }
.hcv__th--lote   { width: 110px; }
.hcv__th--sala   { width: 130px; }
.hcv__th--estado { width: 110px; }
.hcv__th--fecha  { width: 130px; }

.hcv__tr { cursor: pointer; border-bottom: 1px solid #f0f4f0; transition: background .12s; }
.hcv__tr:last-child { border-bottom: none; }
.hcv__tr:hover td { background: #f8fdf8; }

.hcv__td { padding: .75rem 1rem; vertical-align: middle; }

/* Tipo badge */
.hcv__tipo-badge { display: inline-flex; align-items: center; gap: .35rem; padding: .25em .65em; border-radius: 6px; font-size: .75rem; font-weight: 700; white-space: nowrap; }
.hcv__tipo-badge--tarea       { background: #f0fdf4; color: #15803d; }
.hcv__tipo-badge--lote_evento { background: #eff6ff; color: #1d4ed8; }
.hcv__tipo-emoji { font-size: .8rem; }
.hcv__tipo-label { }

/* Description */
.hcv__td--desc { max-width: 280px; }
.hcv__desc     { display: block; font-weight: 600; color: #0f2611; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.hcv__desc-sub { display: block; font-size: .75rem; color: #60725d; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 1px; }

/* Lote pill */
.hcv__lote-pill { display: inline-flex; align-items: center; height: 22px; background: #f0fdf4; border: 1px solid #c8e6c9; color: #1b5e20; font-size: .75rem; font-weight: 700; border-radius: 999px; padding: 0 .5rem; font-variant-numeric: tabular-nums; }

/* Sala */
.hcv__sala { color: #60725d; font-size: .82rem; }

/* Estado */
.hcv__estado-pill { display: inline-flex; align-items: center; padding: .2em .6em; border-radius: 6px; font-size: .72rem; font-weight: 700; }
.hcv__estado-pill--completada  { background: #f0fdf4; color: #15803d; }
.hcv__estado-pill--cancelada   { background: #fef2f2; color: #dc2626; }
.hcv__estado-pill--en_progreso { background: #fffbeb; color: #d97706; }

/* Fecha */
.hcv__fecha { display: block; color: #0f2611; font-weight: 500; font-size: .82rem; }
.hcv__hora  { display: block; color: #60725d; font-size: .72rem; margin-top: 1px; }

.hcv__none { color: #c8e6c9; }

/* Paginación */
.hcv__pager { display: flex; gap: .3rem; justify-content: center; margin-top: .75rem; align-items: center; flex-wrap: wrap; }
.hcv__pager-btn { min-width: 34px; height: 34px; padding: 0 .5rem; border: 1px solid #e8f0e9; border-radius: 8px; background: #fff; color: #60725d; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .15s; }
.hcv__pager-btn:hover:not(:disabled) { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; }
.hcv__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.hcv__pager-pages { display: flex; align-items: center; gap: .25rem; }
.hcv__pager-num { min-width: 34px; height: 34px; border: 1px solid transparent; border-radius: 8px; background: transparent; font-size: .85rem; font-weight: 600; color: #60725d; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .15s; padding: 0 .5rem; }
.hcv__pager-num:hover:not(:disabled):not(.hcv__pager-num--active) { background: #f0fdf4; border-color: #e8f0e9; }
.hcv__pager-num--active  { background: #1b5e20; border-color: #1b5e20; color: #fff; cursor: default; }
.hcv__pager-num--ellipsis { cursor: default; color: #c8e6c9; }
.hcv__pager-info { margin-left: .5rem; font-size: .78rem; color: #60725d; white-space: nowrap; }

/* Responsive */
@media (max-width: 768px) {
  .hcv__th--sala, .hcv__td--sala,
  .hcv__th--estado, .hcv__td--estado { display: none; }
}
@media (max-width: 520px) {
  .hcv__th--lote, .hcv__td--lote { display: none; }
}
</style>
