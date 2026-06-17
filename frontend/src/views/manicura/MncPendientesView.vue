<template>
  <div class="mnp">

    <!-- Header -->
    <div class="mnp__header">
      <div>
        <h1 class="mnp__title">Cosechas pendientes</h1>
        <p class="mnp__sub">Cosechas en secado listas para manicurar y enviadas a aprobación.</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="mnp__filters">
      <button
        v-for="f in FILTROS" :key="f.key"
        class="mnp__chip"
        :class="{ 'mnp__chip--active': filtro === f.key }"
        @click="filtro = f.key"
      >
        {{ f.label }}
        <span class="mnp__chip-count">{{ contar(f.key) }}</span>
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mnp__loading">
      <DsSpinner />
    </div>

    <!-- Empty -->
    <div v-else-if="!lotesFiltrados.length" class="mnp__empty">
      <Wind :size="32" :stroke-width="1.25" />
      <p>Sin cosechas pendientes</p>
      <span>Cuando una cosecha complete el secado aparecerá aquí.</span>
    </div>

    <!-- List -->
    <div v-else class="mnp__list">
      <RouterLink
        v-for="lote in paginados"
        :key="lote.id"
        :to="`/mnc/lotes/${lote.id}`"
        class="mnp__row"
      >
        <div class="mnp__row-av" :class="lote.estado === 'secado' ? 'mnp__av--secado' : 'mnp__av--pendiente'">
          <Scissors :size="14" :stroke-width="2" />
        </div>
        <div class="mnp__row-info">
          <span class="mnp__row-codigo">{{ lote.codigo }}</span>
          <span class="mnp__row-sep">·</span>
          <span class="mnp__row-cepa">{{ lote.genetica?.nombre || '—' }}</span>
          <span class="mnp__row-sep">·</span>
          <span class="mnp__row-sala">{{ lote.sala?.nombre || '—' }}</span>
        </div>
        <div class="mnp__row-right">
          <span class="mnp__row-plants">
            <Package :size="12" :stroke-width="2" /> {{ lote.plants_count }}
          </span>
          <span class="mnp__badge" :class="{
            'mnp__badge--secado':   lote.estado === 'en_manicura' || lote.estado === 'secado',
            'mnp__badge--pendiente': lote.estado === 'manicura_pendiente'
          }">
            {{ lote.estado === 'manicura_pendiente' ? 'Pdte. aprobación' : 'Asignado' }}
          </span>
          <ChevronRight :size="15" class="mnp__row-arrow" />
        </div>
      </RouterLink>
    </div>

    <div v-if="totalPages > 1" class="mnp__pager">
      <button class="mnp__pager-btn" :disabled="page <= 1" @click="page--">«</button>
      <span class="mnp__pager-info">{{ page }} / {{ totalPages }}</span>
      <button class="mnp__pager-btn" :disabled="page >= totalPages" @click="page++">»</button>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Scissors, Wind, Package, ChevronRight } from 'lucide-vue-next'
import { listLotes } from '../../lib/api.js'

const FILTROS = [
  { key: 'todos',              label: 'Todos' },
  { key: 'en_manicura',        label: 'Asignados' },
  { key: 'manicura_pendiente', label: 'Pdte. aprobación' },
]

const loading = ref(true)
const lotes   = ref([])
const filtro  = ref('todos')

const lotesFiltrados = computed(() => {
  if (filtro.value === 'todos') return lotes.value
  return lotes.value.filter(l => l.estado === filtro.value)
})

const PER_PAGE   = 10
const page       = ref(1)
const paginados  = computed(() => lotesFiltrados.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE))
const totalPages = computed(() => Math.max(1, Math.ceil(lotesFiltrados.value.length / PER_PAGE)))
watch([lotesFiltrados], () => { page.value = 1 })

function contar(key) {
  if (key === 'todos') return lotes.value.length
  return lotes.value.filter(l => l.estado === key).length
}

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes()
    lotes.value = (data || []).filter(l => ['en_manicura', 'secado', 'manicura_pendiente'].includes(l.estado))
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.mnp { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }

/* Header */
.mnp__header { margin-bottom: var(--sp-5); }
.mnp__title  { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mnp__sub    { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

/* Filters */
.mnp__filters { display: flex; gap: var(--sp-2); margin-bottom: var(--sp-5); flex-wrap: wrap; }
.mnp__chip {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: var(--c-paper); border: 1px solid var(--c-ink-200);
  border-radius: 999px; padding: var(--sp-1) var(--sp-3);
  font-size: var(--fs-13); font-weight: 500; color: var(--c-ink-600);
  cursor: pointer; transition: all .15s;
}
.mnp__chip:hover { border-color: #5C7A4A; color: #5C7A4A; }
.mnp__chip--active {
  background: #5C7A4A; border-color: #5C7A4A; color: #fff;
}
.mnp__chip-count {
  font-size: var(--fs-11); font-weight: 700;
  background: rgba(255,255,255,.25); border-radius: 999px;
  padding: 1px 6px; line-height: 1.4;
}
.mnp__chip:not(.mnp__chip--active) .mnp__chip-count {
  background: var(--c-ink-100); color: var(--c-ink-500);
}

/* Loading */
.mnp__loading {
  display: flex; align-items: center; justify-content: center; padding: 2rem;
}

/* Empty */
.mnp__empty {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-2);
  padding: var(--sp-12) var(--sp-6); color: var(--c-ink-300); text-align: center;
}
.mnp__empty p    { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-600); margin: 0; }
.mnp__empty span { font-size: var(--fs-13); color: var(--c-ink-400); }

/* List */
.mnp__list { display: flex; flex-direction: column; gap: 2px; }
.mnp__row {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  text-decoration: none; color: inherit;
  transition: border-color .15s, box-shadow .15s;
}
.mnp__row:hover { border-color: #5C7A4A; box-shadow: 0 1px 6px rgba(92,122,74,.1); }

.mnp__row-av {
  width: 32px; height: 32px; border-radius: var(--r-sm);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mnp__av--secado    { background: #fffbeb; color: #b45309; }
.mnp__av--pendiente { background: var(--c-leaf-100); color: var(--c-leaf-700); }

.mnp__row-info {
  flex: 1; min-width: 0;
  display: flex; align-items: baseline; gap: var(--sp-2); overflow: hidden;
}
.mnp__row-codigo {
  font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900);
  white-space: nowrap;
}
.mnp__row-sep  { color: var(--c-ink-300); font-size: var(--fs-11); flex-shrink: 0; }
.mnp__row-cepa { font-size: var(--fs-13); color: var(--c-ink-700); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mnp__row-sala { font-size: var(--fs-12); color: var(--c-ink-400); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.mnp__row-right {
  display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0;
}
.mnp__row-plants {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: var(--fs-12); color: var(--c-ink-400);
}
.mnp__badge {
  font-size: 12px; font-weight: 600; padding: .2em .65em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em;
}
.mnp__badge--secado    { background: #fffbeb; color: #b45309; }
.mnp__badge--pendiente { background: var(--c-leaf-100); color: var(--c-leaf-700); }

.mnp__row-arrow { color: var(--c-ink-300); }

.mnp__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1.25rem 0 .5rem; }
.mnp__pager-btn { background: #fff; border: 1.5px solid var(--c-ink-200); color: var(--c-ink-700); padding: .35rem .75rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.mnp__pager-btn:hover:not(:disabled) { border-color: #5C7A4A; color: #5C7A4A; }
.mnp__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.mnp__pager-info { font-size: .82rem; color: var(--c-ink-500); font-weight: 600; min-width: 50px; text-align: center; }
</style>
