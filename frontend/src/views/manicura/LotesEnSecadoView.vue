<template>
  <div class="lv">

    <div class="lv__header">
      <div class="lv__header-left">
        <div class="lv__eyebrow">
          <Wind :size="14" :stroke-width="2" />
          Post-cosecha
        </div>
        <h1 class="lv__title">Lotes en Manicura</h1>
        <p class="lv__sub">Registrá pesadas y avanzá los lotes a curado cuando estén listos.</p>
      </div>
    </div>

    <div v-if="loading" class="lv__loading">
      <DsSpinner />
    </div>

    <div v-else-if="!lotes.length" class="lv__empty">
      <div class="lv__empty-ico"><Wind :size="40" :stroke-width="1.25" /></div>
      <p class="lv__empty-title">Sin lotes en manicura</p>
      <p class="lv__empty-sub">Los lotes en cosecha aparecerán aquí una vez iniciado el secado.</p>
    </div>

    <div v-else class="lv__cards">
      <div v-for="lote in paginados" :key="lote.id" class="lv__card">
        <div class="lv__card-stripe lv__card-stripe--secado"></div>
        <div class="lv__card-body">
          <div class="lv__card-head">
            <span class="lv__card-codigo">{{ lote.codigo }}</span>
            <span class="lv__badge lv__badge--secado">Manicura</span>
          </div>
          <div class="lv__card-meta">
            <span v-if="lote.genetica"><Leaf :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}</span>
            <span><MapPin :size="13" :stroke-width="2" /> {{ lote.sala?.nombre }}</span>
            <span><Package :size="13" :stroke-width="2" /> {{ lote.plants_count }} plantas</span>
          </div>
        </div>
        <div class="lv__card-actions">
          <RouterLink :to="`/lotes/${lote.id}`" class="lv__btn-secondary">
            <Eye :size="14" :stroke-width="2" /> Ver lote
          </RouterLink>
          <button class="lv__btn-accent" @click="abrirPesada(lote)">
            <Scale :size="14" :stroke-width="2" /> Registrar pesada
          </button>
          <button class="lv__btn-primary" :disabled="avanzando === lote.id" @click="avanzarACurado(lote)">
            <DsSpinner v-if="avanzando === lote.id" :size="13" />
            <Container v-else :size="14" :stroke-width="2" />
            Pasar a curado
          </button>
        </div>
      </div>
    </div>

    <div v-if="totalPages > 1" class="lv__pager">
      <button class="lv__pager-btn" :disabled="page <= 1" @click="page--">«</button>
      <span class="lv__pager-info">{{ page }} / {{ totalPages }}</span>
      <button class="lv__pager-btn" :disabled="page >= totalPages" @click="page++">»</button>
    </div>

    <ModalPesada
      v-model="showModal"
      :lote="loteSeleccionado"
      tipo-inicial="secado_final"
      @saved="onPesadaGuardada"
    />

  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { Wind, Leaf, MapPin, Package, Scale, Eye, Container } from 'lucide-vue-next'
import { listLotes, avanzarFaseLote } from '../../lib/api.js'
import ModalPesada from '../../components/manicura/ModalPesada.vue'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const lotes = ref([])
const loading = ref(true)
const showModal = ref(false)
const loteSeleccionado = ref(null)
const avanzando = ref(null)

const PER_PAGE   = 10
const page       = ref(1)
const paginados  = computed(() => lotes.value.slice((page.value - 1) * PER_PAGE, page.value * PER_PAGE))
const totalPages = computed(() => Math.max(1, Math.ceil(lotes.value.length / PER_PAGE)))
watch(lotes, () => { page.value = 1 })

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ estado: 'secado' })
    lotes.value = data
  } catch {
    lotes.value = []
  } finally {
    loading.value = false
  }
}

function abrirPesada(lote) {
  loteSeleccionado.value = lote
  showModal.value = true
}

function onPesadaGuardada() {
  toast.success('Pesada registrada correctamente')
  cargar()
}

async function avanzarACurado(lote) {
  avanzando.value = lote.id
  try {
    await avanzarFaseLote(lote.id)
    toast.success(`Lote ${lote.codigo} pasado a curado`)
    cargar()
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al avanzar fase')
  } finally {
    avanzando.value = null
  }
}

onMounted(cargar)
</script>

<style scoped>
.lv { padding: 2rem 1.75rem 3rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .lv { padding: 1.25rem 1rem 2rem; } }

.lv__header { margin-bottom: 2rem; }
.lv__eyebrow {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: var(--fs-12); font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: #6B4FBE; margin-bottom: .4rem;
}
.lv__title { font-size: 1.75rem; font-weight: 800; color: var(--c-ink-900); margin: 0 0 .2rem; letter-spacing: -.03em; }
.lv__sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.lv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

.lv__empty { text-align: center; padding: 4rem 2rem; }
.lv__empty-ico { color: var(--c-ink-300); margin-bottom: 1rem; display: flex; justify-content: center; }
.lv__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin: 0 0 .4rem; }
.lv__empty-sub { font-size: var(--fs-14); color: var(--c-ink-400); margin: 0; }

.lv__cards { display: flex; flex-direction: column; gap: .75rem; }
.lv__card {
  display: flex; align-items: stretch;
  background: var(--c-paper);
  border: 1px solid var(--c-ink-200);
  border-radius: var(--r-xl);
  overflow: hidden;
  transition: box-shadow var(--t-fast);
}
.lv__card:hover { box-shadow: 0 4px 20px rgba(0,0,0,.07); }

.lv__card-stripe { width: 4px; flex-shrink: 0; }
.lv__card-stripe--secado { background: #64748b; }

.lv__card-body { flex: 1; padding: 1rem 1.25rem; min-width: 0; }
.lv__card-head { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.lv__card-codigo { font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); font-family: var(--font-mono); }

.lv__badge { font-size: 11px; font-weight: 700; padding: 2px 10px; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; }
.lv__badge--secado { background: #f8fafc; color: #475569; border: 1px solid #e2e8f0; }

.lv__card-meta { display: flex; flex-wrap: wrap; gap: .5rem 1.25rem; font-size: var(--fs-13); color: var(--c-ink-500); }
.lv__card-meta span { display: inline-flex; align-items: center; gap: .3rem; }

.lv__card-actions {
  display: flex; flex-direction: column; gap: .5rem;
  justify-content: center; padding: 1rem 1.25rem;
  border-left: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}
@media (max-width: 600px) {
  .lv__card { flex-direction: column; }
  .lv__card-stripe { width: 100%; height: 4px; }
  .lv__card-actions { border-left: none; border-top: 1px solid var(--c-ink-100); flex-direction: row; flex-wrap: wrap; }
}

.lv__btn-primary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #15803d; color: #fff;
  border: none; padding: .5rem .875rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap;
  transition: opacity var(--t-fast);
}
.lv__btn-primary:hover:not(:disabled) { opacity: .88; }
.lv__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.lv__btn-accent {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #6B4FBE; color: #fff;
  border: none; padding: .5rem .875rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap;
  transition: opacity var(--t-fast);
}
.lv__btn-accent:hover { opacity: .88; }
.lv__btn-secondary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: transparent; color: var(--c-ink-600);
  border: 1.5px solid var(--c-ink-200);
  padding: .5rem .875rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13); font-weight: 500;
  cursor: pointer; white-space: nowrap;
  transition: all var(--t-fast);
  text-decoration: none;
}
.lv__btn-secondary:hover { background: var(--c-ink-50); border-color: var(--c-ink-300); color: var(--c-ink-900); }

.lv__pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 1.25rem 0 .5rem; }
.lv__pager-btn { background: #fff; border: 1.5px solid var(--c-ink-200); color: var(--c-ink-700); padding: .35rem .75rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.lv__pager-btn:hover:not(:disabled) { border-color: #6B4FBE; color: #6B4FBE; }
.lv__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.lv__pager-info { font-size: .82rem; color: var(--c-ink-500); font-weight: 600; min-width: 50px; text-align: center; }
</style>
