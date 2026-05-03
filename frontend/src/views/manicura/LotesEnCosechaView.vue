<template>
  <div class="lv">

    <div class="lv__header">
      <div class="lv__header-left">
        <div class="lv__eyebrow">
          <Scissors :size="14" :stroke-width="2" />
          Post-cosecha
        </div>
        <h1 class="lv__title">Lotes en Cosecha</h1>
        <p class="lv__sub">Lotes listos para iniciar el secado. Registrá la primera pesada para avanzar.</p>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="lv__loading">
      <div class="lv__ring"></div>
      <span>Cargando lotes…</span>
    </div>

    <!-- Empty -->
    <div v-else-if="!lotes.length" class="lv__empty">
      <div class="lv__empty-ico"><Scissors :size="40" :stroke-width="1.25" /></div>
      <p class="lv__empty-title">Sin lotes en cosecha</p>
      <p class="lv__empty-sub">Cuando un cultivador avance un lote a cosecha aparecerá aquí.</p>
    </div>

    <!-- Lote cards -->
    <div v-else class="lv__cards">
      <div v-for="lote in lotes" :key="lote.id" class="lv__card">
        <div class="lv__card-stripe lv__card-stripe--cosecha"></div>
        <div class="lv__card-body">
          <div class="lv__card-head">
            <span class="lv__card-codigo">{{ lote.codigo }}</span>
            <span class="lv__badge lv__badge--cosecha">Cosecha</span>
          </div>
          <div class="lv__card-meta">
            <span v-if="lote.genetica"><Leaf :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}</span>
            <span><MapPin :size="13" :stroke-width="2" /> {{ lote.sala?.nombre }}</span>
            <span><Package :size="13" :stroke-width="2" /> {{ lote.plants_count }} plantas</span>
            <span><Calendar :size="13" :stroke-width="2" /> Día {{ lote.dias_desde_inicio }}</span>
          </div>
        </div>
        <div class="lv__card-actions">
          <RouterLink :to="`/lotes/${lote.id}`" class="lv__btn-secondary">
            <Eye :size="14" :stroke-width="2" /> Ver lote
          </RouterLink>
          <button class="lv__btn-primary" @click="abrirPesada(lote)">
            <Scale :size="14" :stroke-width="2" /> Pesada de secado
          </button>
        </div>
      </div>
    </div>

    <!-- Modal pesada -->
    <ModalPesada
      v-model="showModal"
      :lote="loteSeleccionado"
      tipo-inicial="secado_inicio"
      @saved="onPesadaGuardada"
    />

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Scissors, Leaf, MapPin, Package, Calendar, Scale, Eye } from 'lucide-vue-next'
import { listLotes } from '../../lib/api.js'
import ModalPesada from '../../components/manicura/ModalPesada.vue'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const lotes = ref([])
const loading = ref(true)
const showModal = ref(false)
const loteSeleccionado = ref(null)

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ estado: 'cosecha' })
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

.lv__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem; justify-content: center; color: var(--c-ink-400); }
.lv__ring { width: 20px; height: 20px; border: 2px solid var(--c-ink-200); border-top-color: #6B4FBE; border-radius: 50%; animation: lv-spin .7s linear infinite; }
@keyframes lv-spin { to { transform: rotate(360deg); } }

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
.lv__card-stripe--cosecha { background: #f59e0b; }

.lv__card-body { flex: 1; padding: 1rem 1.25rem; min-width: 0; }
.lv__card-head { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.lv__card-codigo { font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); font-family: var(--font-mono); }

.lv__badge { font-size: 11px; font-weight: 700; padding: 2px 10px; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; }
.lv__badge--cosecha { background: #fffbeb; color: #b45309; border: 1px solid #fde68a; }

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
  .lv__card-actions { border-left: none; border-top: 1px solid var(--c-ink-100); flex-direction: row; }
}

.lv__btn-primary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #6B4FBE; color: #fff;
  border: none; padding: .5rem .875rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; white-space: nowrap;
  transition: opacity var(--t-fast);
  text-decoration: none;
}
.lv__btn-primary:hover { opacity: .88; }
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
</style>
