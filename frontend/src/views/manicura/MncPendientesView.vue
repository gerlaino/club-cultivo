<template>
  <div class="mnp">

    <!-- Header -->
    <div class="mnp__header">
      <div>
        <h1 class="mnp__title">{{ esGestor ? 'Lotes en manicura' : 'Cosechas asignadas' }}</h1>
        <p class="mnp__sub">{{ esGestor ? 'Todos los lotes en manicura y su responsable.' : 'Cosechas que el admin te asignó para manicurar.' }}</p>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mnp__loading">
      <DsSpinner />
    </div>

    <!-- Empty -->
    <div v-else-if="!lotes.length" class="mnp__empty">
      <Wind :size="32" :stroke-width="1.25" />
      <p>{{ esGestor ? 'No hay lotes en manicura' : 'Sin cosechas asignadas' }}</p>
      <span>{{ esGestor ? 'Cuando asignes una cosecha a manicura, va a aparecer acá con su responsable.' : 'El admin te asignará las cosechas cuando estén listas para manicurar.' }}</span>
    </div>

    <!-- List -->
    <div v-else class="mnp__list">
      <RouterLink
        v-for="lote in paginados"
        :key="lote.id"
        :to="`/mnc/lotes/${lote.id}`"
        class="mnp__row"
      >
        <div class="mnp__row-av mnp__av--pendiente">
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
          <span v-if="esGestor" class="mnp__badge" :class="lote.manicurador ? 'mnp__badge--resp' : 'mnp__badge--sin'">
            <User :size="11" :stroke-width="2" /> {{ lote.manicurador?.nombre || 'Sin asignar' }}
          </span>
          <span v-else class="mnp__badge mnp__badge--pendiente">Asignado</span>
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
import { Scissors, Wind, Package, ChevronRight, User } from 'lucide-vue-next'
import { listLotes } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth'

const auth     = useAuthStore()
// El admin ve el board completo con el responsable; el manicura ve su cola asignada.
const esGestor = computed(() => auth.user?.role === 'admin')
const loading  = ref(true)
const lotes    = ref([])

const PER_PAGE   = 10
const page       = ref(1)
const paginados  = computed(() => lotes.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE))
const totalPages = computed(() => Math.max(1, Math.ceil(lotes.value.length / PER_PAGE)))
watch(lotes, () => { page.value = 1 })

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes()
    lotes.value = (data || []).filter(l => l.estado === 'en_manicura')
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
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 12px; font-weight: 600; padding: .2em .65em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em;
}
.mnp__badge--pendiente { background: var(--c-leaf-100); color: var(--c-leaf-700); }
.mnp__badge--resp { background: var(--c-leaf-100); color: var(--c-leaf-700); text-transform: none; letter-spacing: 0; }
.mnp__badge--sin { background: #fef3c7; color: #b45309; text-transform: none; letter-spacing: 0; }

.mnp__row-arrow { color: var(--c-ink-300); }

.mnp__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1.25rem 0 .5rem; }
.mnp__pager-btn { background: #fff; border: 1.5px solid var(--c-ink-200); color: var(--c-ink-700); padding: .35rem .75rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.mnp__pager-btn:hover:not(:disabled) { border-color: #5C7A4A; color: #5C7A4A; }
.mnp__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.mnp__pager-info { font-size: .82rem; color: var(--c-ink-500); font-weight: 600; min-width: 50px; text-align: center; }
</style>
