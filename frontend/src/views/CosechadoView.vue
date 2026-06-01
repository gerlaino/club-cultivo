<template>
  <div class="cv">

    <!-- Header -->
    <div class="cv__header">
      <div class="cv__header-left">
        <h1 class="cv__title">Mis cosechas</h1>
        <p class="cv__sub">Lotes que cosechaste y pasaron a post-producción</p>
      </div>
      <div v-if="!loading && lotesCosechados.length" class="cv__header-stat">
        <span class="cv__stat-num">{{ lotesCosechados.length }}</span>
        <span class="cv__stat-label">lote{{ lotesCosechados.length !== 1 ? 's' : '' }}</span>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="cv__loading">
      <div class="cv__skeleton" v-for="i in 5" :key="i"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!lotesCosechados.length" class="cv__empty">
      <div class="cv__empty-icon">🌿</div>
      <p class="cv__empty-title">Todavía no hay cosechas</p>
      <p class="cv__empty-sub">Los lotes aparecen acá cuando avanzás a cosecha desde el detalle del lote.</p>
    </div>

    <!-- Tabla -->
    <template v-else>
      <div class="cv__table-wrap">
        <table class="cv__table">
          <thead>
            <tr>
              <th class="cv__th cv__th--lote">Lote</th>
              <th class="cv__th cv__th--genetica">Genética</th>
              <th class="cv__th cv__th--sala">Sala</th>
              <th class="cv__th cv__th--plantas">Plantas</th>
              <th class="cv__th cv__th--estado">Estado</th>
              <th class="cv__th cv__th--cosecha">Fecha cosechado</th>
              <th class="cv__th cv__th--arrow"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="lote in paginados"
              :key="lote.id"
              class="cv__tr"
              @click="$router.push({ name: 'cosechado-detalle', params: { id: lote.id } })"
            >
              <td class="cv__td cv__td--lote">
                <div class="cv__lote-av">
                  <Leaf :size="13" :stroke-width="2" />
                </div>
                <span class="cv__lote-codigo">{{ lote.codigo }}</span>
              </td>
              <td class="cv__td cv__td--genetica">
                <span class="cv__genetica">{{ lote.genetica?.nombre || '—' }}</span>
              </td>
              <td class="cv__td cv__td--sala">
                <span class="cv__sala">{{ lote.sala?.nombre || '—' }}</span>
              </td>
              <td class="cv__td cv__td--plantas">
                <span class="cv__pill-plantas">{{ lote.plants_count ?? '—' }}</span>
              </td>
              <td class="cv__td cv__td--estado">
                <span class="cv__estado-pill" :class="`cv__estado-pill--${lote.estado}`">{{ ESTADO_LABEL[lote.estado] || lote.estado }}</span>
              </td>
              <td class="cv__td cv__td--cosecha">
                <span v-if="lote.fecha_cosechado" class="cv__fecha">{{ formatFecha(lote.fecha_cosechado) }}</span>
                <span v-else class="cv__fecha cv__fecha--none">—</span>
              </td>
              <td class="cv__td cv__td--arrow">
                <ChevronRight :size="14" class="cv__arrow" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Paginación -->
      <div v-if="totalPaginas > 1" class="cv__pager">
        <button class="cv__pager-btn" :disabled="pagina === 1" @click="pagina--">
          <ChevronLeft :size="15" />
        </button>
        <div class="cv__pager-pages">
          <button
            v-for="p in paginas"
            :key="p"
            class="cv__pager-num"
            :class="{ 'cv__pager-num--active': p === pagina, 'cv__pager-num--ellipsis': p === '…' }"
            :disabled="p === '…'"
            @click="p !== '…' && (pagina = p)"
          >{{ p }}</button>
        </div>
        <button class="cv__pager-btn" :disabled="pagina === totalPaginas" @click="pagina++">
          <ChevronRight :size="15" />
        </button>
        <span class="cv__pager-info">{{ desde }}–{{ hasta }} de {{ lotesCosechados.length }}</span>
      </div>
    </template>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listLotes } from '../lib/api.js'
import { ChevronRight, ChevronLeft, Leaf } from 'lucide-vue-next'

const PER_PAGE = 10

const loading = ref(true)
const lotes   = ref([])
const pagina  = ref(1)

const POST_HARVEST = ['cosecha', 'secado', 'manicura_pendiente', 'en_manicura', 'curado', 'finalizado']
const ESTADO_LABEL = {
  floracion:         'Cosecha parcial',
  cosecha:           'Cosecha',
  secado:            'Secado',
  manicura_pendiente:'Manicura pend.',
  en_manicura:       'En manicura',
  curado:            'Curado',
  finalizado:        'Finalizado',
}

const lotesCosechados = computed(() =>
  lotes.value
    .filter(l => POST_HARVEST.includes(l.estado) || (l.estado === 'floracion' && (l.plantas_cosechadas_count ?? 0) > 0))
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
)

const totalPaginas = computed(() => Math.ceil(lotesCosechados.value.length / PER_PAGE))
const desde        = computed(() => (pagina.value - 1) * PER_PAGE + 1)
const hasta        = computed(() => Math.min(pagina.value * PER_PAGE, lotesCosechados.value.length))
const paginados    = computed(() => lotesCosechados.value.slice(desde.value - 1, hasta.value))

const paginas = computed(() => {
  const total = totalPaginas.value
  const cur   = pagina.value
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
  const pages = new Set([1, total, cur, cur - 1, cur + 1].filter(p => p >= 1 && p <= total))
  const sorted = [...pages].sort((a, b) => a - b)
  const result = []
  for (let i = 0; i < sorted.length; i++) {
    if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.push('…')
    result.push(sorted[i])
  }
  return result
})

function formatFecha(d) {
  if (!d) return '—'
  return new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

onMounted(async () => {
  try {
    const { data } = await listLotes({ cosechados: true })
    lotes.value = data || []
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.cv { padding: 1.5rem 1.25rem; max-width: 1280px; margin: 0 auto; }
@media (max-width: 640px) { .cv { padding: 1rem .75rem; } }

/* Header */
.cv__header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 1.5rem; gap: 1rem; }
.cv__title { font-size: 1.5rem; font-weight: 700; color: #0f2611; margin: 0 0 .25rem; }
.cv__sub   { font-size: .85rem; color: #60725d; margin: 0; }
.cv__header-stat { display: flex; flex-direction: column; align-items: flex-end; flex-shrink: 0; padding-top: 2px; }
.cv__stat-num   { font-size: 2rem; font-weight: 700; color: #1b5e20; line-height: 1; }
.cv__stat-label { font-size: .72rem; color: #60725d; text-transform: uppercase; letter-spacing: .06em; font-weight: 600; }

/* Loading skeletons */
.cv__loading { display: flex; flex-direction: column; gap: .4rem; margin-top: .5rem; }
.cv__skeleton { height: 52px; border-radius: 10px; background: linear-gradient(90deg, #f0f4f0 25%, #e4ebe4 50%, #f0f4f0 75%); background-size: 200% 100%; animation: cv-shimmer 1.4s ease infinite; }
.cv__skeleton:nth-child(2) { opacity: .8; }
.cv__skeleton:nth-child(3) { opacity: .6; }
.cv__skeleton:nth-child(4) { opacity: .4; }
.cv__skeleton:nth-child(5) { opacity: .25; }
@keyframes cv-shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }

/* Empty */
.cv__empty { display: flex; flex-direction: column; align-items: center; gap: .75rem; padding: 4rem 1.5rem; text-align: center; }
.cv__empty-icon  { font-size: 2.5rem; line-height: 1; }
.cv__empty-title { font-size: 1rem; font-weight: 700; color: #0f2611; margin: 0; }
.cv__empty-sub   { font-size: .85rem; color: #60725d; margin: 0; max-width: 360px; line-height: 1.6; }

/* Table */
.cv__table-wrap { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; overflow: hidden; margin-bottom: 1.25rem; }
.cv__table      { width: 100%; border-collapse: collapse; font-size: .85rem; }
.cv__th { padding: .75rem 1rem; background: #f6faf6; font-weight: 600; color: #0f2611; text-align: left; border-bottom: 1px solid #e8f0e9; font-size: .78rem; white-space: nowrap; }
.cv__th--arrow   { width: 32px; }
.cv__th--plantas { width: 80px; text-align: center; }
.cv__th--estado  { width: 120px; }
.cv__th--cosecha { width: 120px; }

.cv__tr { cursor: pointer; border-bottom: 1px solid #f0f4f0; transition: background .12s; }
.cv__tr:last-child { border-bottom: none; }
.cv__tr:hover td { background: #f8fdf8; }

.cv__td { padding: .75rem 1rem; vertical-align: middle; }

/* Lote cell */
.cv__td--lote  { display: flex; align-items: center; gap: .6rem; }
.cv__lote-av   { width: 28px; height: 28px; flex-shrink: 0; border-radius: 7px; background: #dcfce7; color: #15803d; display: flex; align-items: center; justify-content: center; }
.cv__lote-codigo { font-weight: 700; color: #0f2611; font-size: .9rem; white-space: nowrap; }

/* Other cells */
.cv__genetica { color: #0f2611; font-weight: 500; display: -webkit-box; -webkit-line-clamp: 1; -webkit-box-orient: vertical; overflow: hidden; }
.cv__sala     { color: #60725d; }
.cv__td--plantas { text-align: center; }
.cv__pill-plantas { display: inline-flex; align-items: center; justify-content: center; min-width: 32px; height: 22px; background: #f0fdf4; border: 1px solid #c8e6c9; color: #1b5e20; font-size: .78rem; font-weight: 700; border-radius: 999px; padding: 0 .4rem; }
.cv__td--veg, .cv__td--flor { text-align: center; }
.cv__td--estado { vertical-align: middle; }
.cv__estado-pill { display: inline-flex; align-items: center; font-size: .72rem; font-weight: 600; padding: .2em .6em; border-radius: 999px; white-space: nowrap; }
.cv__estado-pill--floracion         { background: #fef3c7; color: #92400e; border: 1px dashed #fcd34d; }
.cv__estado-pill--cosecha           { background: #fef9c3; color: #854d0e; }
.cv__estado-pill--secado            { background: #e0f2fe; color: #0369a1; }
.cv__estado-pill--manicura_pendiente{ background: #fce7f3; color: #9d174d; }
.cv__estado-pill--en_manicura       { background: #ede9fe; color: #5b21b6; }
.cv__estado-pill--curado            { background: #dcfce7; color: #14532d; }
.cv__estado-pill--finalizado        { background: #f1f5f9; color: #475569; }
.cv__fecha     { color: #60725d; }
.cv__fecha--none { color: #c8e6c9; }
.cv__td--arrow { text-align: center; padding-right: .5rem; }
.cv__arrow     { color: #c8e6c9; transition: color .12s; }
.cv__tr:hover .cv__arrow { color: #1b5e20; }

/* Paginación */
.cv__pager { display: flex; gap: .3rem; justify-content: center; margin-top: .75rem; align-items: center; flex-wrap: wrap; }
.cv__pager-btn { min-width: 34px; height: 34px; padding: 0 .5rem; border: 1px solid #e8f0e9; border-radius: 8px; background: #fff; color: #60725d; font-size: .85rem; cursor: pointer; transition: all .15s; display: flex; align-items: center; justify-content: center; }
.cv__pager-btn:hover:not(:disabled) { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; }
.cv__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.cv__pager-pages { display: flex; align-items: center; gap: .25rem; }
.cv__pager-num { min-width: 34px; height: 34px; border: 1px solid transparent; border-radius: 8px; background: transparent; font-size: .85rem; font-weight: 600; color: #60725d; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .15s; padding: 0 .5rem; }
.cv__pager-num:hover:not(:disabled):not(.cv__pager-num--active) { background: #f0fdf4; border-color: #e8f0e9; }
.cv__pager-num--active  { background: #1b5e20; border-color: #1b5e20; color: #fff; cursor: default; }
.cv__pager-num--ellipsis { cursor: default; color: #c8e6c9; }
.cv__pager-info { margin-left: .5rem; font-size: .78rem; color: #60725d; white-space: nowrap; }

/* Responsive */
@media (max-width: 640px) {
  .cv__th--sala,   .cv__td--sala,
  .cv__th--estado, .cv__td--estado,
  .cv__th--cosecha,.cv__td--cosecha { display: none; }
}
</style>
