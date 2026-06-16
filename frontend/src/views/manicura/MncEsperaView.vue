<template>
  <div class="mne">

    <!-- Header -->
    <div class="mne__header">
      <h1 class="mne__title">En espera de aprobación</h1>
      <p class="mne__sub">Cosechas que ya manicuraste. El admin las revisará antes de pasarlas a curado.</p>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mne__loading">
      <DsSpinner />
    </div>

    <!-- Empty -->
    <div v-else-if="!lotes.length" class="mne__empty">
      <Clock :size="32" :stroke-width="1.25" />
      <p>Nada en espera</p>
      <span>Cuando registrés una manicura, la cosecha aparecerá aquí mientras el admin la revisa.</span>
    </div>

    <!-- List -->
    <div v-else class="mne__list">
      <RouterLink
        v-for="lote in paginados"
        :key="lote.id"
        :to="`/mnc/lotes/${lote.id}`"
        class="mne__row"
      >
        <div class="mne__row-av">
          <Clock :size="14" :stroke-width="2" />
        </div>
        <div class="mne__row-info">
          <span class="mne__row-codigo">{{ lote.codigo }}</span>
          <span class="mne__row-sep">·</span>
          <span class="mne__row-cepa">{{ lote.genetica?.nombre || '—' }}</span>
          <span class="mne__row-sep">·</span>
          <span class="mne__row-sala">{{ lote.sala?.nombre || '—' }}</span>
        </div>
        <div class="mne__row-right">
          <template v-if="lote.ultima_pesada_manicura">
            <span class="mne__row-peso">
              <Scale :size="12" :stroke-width="2" />
              {{ lote.ultima_pesada_manicura.peso_seco_g }}g
            </span>
          </template>
          <span class="mne__badge">Pdte. aprobación</span>
          <ChevronRight :size="15" class="mne__row-arrow" />
        </div>
      </RouterLink>
    </div>

    <div v-if="totalPages > 1" class="mne__pager">
      <button class="mne__pager-btn" :disabled="page <= 1" @click="page--">«</button>
      <span class="mne__pager-info">{{ page }} / {{ totalPages }}</span>
      <button class="mne__pager-btn" :disabled="page >= totalPages" @click="page++">»</button>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Clock, Scale, ChevronRight } from 'lucide-vue-next'
import { listLotes } from '../../lib/api.js'

const lotes   = ref([])
const loading = ref(true)

const PER_PAGE   = 10
const page       = ref(1)
const paginados  = computed(() => lotes.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE))
const totalPages = computed(() => Math.max(1, Math.ceil(lotes.value.length / PER_PAGE)))
watch(lotes, () => { page.value = 1 })

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ pesaje_enviado: true })
    lotes.value = Array.isArray(data) ? data : (data?.data || [])
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.mne { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }

.mne__header { margin-bottom: var(--sp-5); }
.mne__title  { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mne__sub    { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.mne__loading {
  display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px);
}

.mne__empty {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-2);
  padding: var(--sp-12) var(--sp-6); color: var(--c-ink-300); text-align: center;
}
.mne__empty p    { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-600); margin: 0; }
.mne__empty span { font-size: var(--fs-13); color: var(--c-ink-400); }

.mne__list { display: flex; flex-direction: column; gap: 2px; }
.mne__row {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  text-decoration: none; color: inherit;
  transition: border-color .15s, box-shadow .15s;
}
.mne__row:hover { border-color: #7c3aed; box-shadow: 0 1px 6px rgba(124,58,237,.08); }

.mne__row-av {
  width: 32px; height: 32px; border-radius: var(--r-sm);
  background: #ede9fe; color: #7c3aed;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mne__row-info {
  flex: 1; min-width: 0;
  display: flex; align-items: baseline; gap: var(--sp-2); overflow: hidden;
}
.mne__row-codigo {
  font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900);
  font-family: var(--font-mono, monospace); white-space: nowrap;
}
.mne__row-sep  { color: var(--c-ink-300); font-size: var(--fs-11); flex-shrink: 0; }
.mne__row-cepa { font-size: var(--fs-13); color: var(--c-ink-700); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mne__row-sala { font-size: var(--fs-12); color: var(--c-ink-400); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.mne__row-right {
  display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0;
}
.mne__row-peso {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: var(--fs-12); color: var(--c-ink-500);
}
.mne__badge {
  font-size: 12px; font-weight: 600; padding: .2em .65em;
  border-radius: 999px; background: #ede9fe; color: #7c3aed;
  text-transform: uppercase; letter-spacing: .04em;
}
.mne__row-arrow { color: var(--c-ink-300); }

.mne__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1.25rem 0 .5rem; }
.mne__pager-btn { background: #fff; border: 1.5px solid var(--c-ink-200); color: var(--c-ink-700); padding: .35rem .75rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.mne__pager-btn:hover:not(:disabled) { border-color: #7c3aed; color: #7c3aed; }
.mne__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.mne__pager-info { font-size: .82rem; color: var(--c-ink-500); font-weight: 600; min-width: 50px; text-align: center; }
</style>
