<template>
  <div class="ev">

    <div class="ev__header">
      <div class="ev__eyebrow">
        <Clock :size="14" :stroke-width="2" />
        Manicura
      </div>
      <h1 class="ev__title">En espera de aprobación</h1>
      <p class="ev__sub">Cosechas que ya manicuraste y esperan revisión del administrador antes de pasar a curado.</p>
    </div>

    <div v-if="loading" class="ev__loading">
      <div class="ev__ring"></div>
      <span>Cargando lotes…</span>
    </div>

    <div v-else-if="!lotes.length" class="ev__empty">
      <div class="ev__empty-ico"><Clock :size="40" :stroke-width="1.25" /></div>
      <p class="ev__empty-title">Nada en espera</p>
      <p class="ev__empty-sub">Cuando registres una manicura, la cosecha aparecerá aquí mientras el admin la revisa.</p>
    </div>

    <div v-else class="ev__cards">
      <div v-for="lote in lotes" :key="lote.id" class="ev__card">
        <div class="ev__card-stripe"></div>
        <div class="ev__card-body">
          <div class="ev__card-head">
            <span class="ev__card-codigo">{{ lote.codigo }}</span>
            <span class="ev__badge">
              <Clock :size="11" :stroke-width="2.5" />
              Pendiente aprobación
            </span>
          </div>
          <div class="ev__card-meta">
            <span v-if="lote.genetica"><Leaf :size="13" :stroke-width="2" /> {{ lote.genetica.nombre }}</span>
            <span><MapPin :size="13" :stroke-width="2" /> {{ lote.sala?.nombre }}</span>
            <span><Package :size="13" :stroke-width="2" /> {{ lote.plants_count }} plantas</span>
          </div>
          <div v-if="lote.ultima_pesada_manicura" class="ev__card-pesada">
            <Scale :size="13" :stroke-width="2" />
            <strong>{{ lote.ultima_pesada_manicura.peso_seco_g }}g</strong>
            <span v-if="lote.ultima_pesada_manicura.plantas_manicuradas">
              · {{ lote.ultima_pesada_manicura.plantas_manicuradas }} plantas manicuradas
            </span>
          </div>
          <div class="ev__card-info">
            El admin revisará esta cosecha antes de pasarla a curado. No se requiere acción de tu parte.
          </div>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Clock, Leaf, MapPin, Package, Scale } from 'lucide-vue-next'
import { listLotes } from '../../lib/api.js'

const lotes = ref([])
const loading = ref(true)

async function cargar() {
  loading.value = true
  try {
    const { data } = await listLotes({ estado: 'manicura_pendiente' })
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
.ev { padding: 2rem 1.75rem 3rem; max-width: 1000px; margin: 0 auto; }
@media (max-width: 768px) { .ev { padding: 1.25rem 1rem 2rem; } }

.ev__header { margin-bottom: 2rem; }
.ev__eyebrow {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: var(--fs-12); font-weight: 700; text-transform: uppercase; letter-spacing: .08em;
  color: var(--c-role-manicura); margin-bottom: .4rem;
}
.ev__title { font-size: 1.75rem; font-weight: 800; color: var(--c-ink-900); margin: 0 0 .2rem; letter-spacing: -.03em; }
.ev__sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.ev__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem; justify-content: center; color: var(--c-ink-500); }
.ev__ring {
  width: 20px; height: 20px;
  border: 2px solid var(--c-ink-200); border-top-color: var(--c-role-manicura);
  border-radius: 50%; animation: ev-spin .7s linear infinite;
}
@keyframes ev-spin { to { transform: rotate(360deg); } }

.ev__empty { text-align: center; padding: 4rem 2rem; }
.ev__empty-ico { color: var(--c-ink-300); margin-bottom: 1rem; display: flex; justify-content: center; }
.ev__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-700); margin: 0 0 .4rem; }
.ev__empty-sub { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

.ev__cards { display: flex; flex-direction: column; gap: .75rem; }
.ev__card {
  display: flex; align-items: stretch;
  background: var(--c-paper); border: 1px solid #d4dfc9;
  border-radius: var(--r-xl); overflow: hidden;
}

.ev__card-stripe { width: 4px; flex-shrink: 0; background: #b5c9a8; }

.ev__card-body { flex: 1; padding: 1rem 1.25rem; min-width: 0; }
.ev__card-head { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.ev__card-codigo { font-size: var(--fs-16); font-weight: 800; color: var(--c-ink-900); font-family: var(--font-mono); }

.ev__badge {
  display: inline-flex; align-items: center; gap: .3rem;
  font-size: 11px; font-weight: 700; padding: 2px 10px;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em;
  background: rgba(122,155,110,.12); color: var(--c-role-manicura); border: 1px solid rgba(122,155,110,.3);
}

.ev__card-meta { display: flex; flex-wrap: wrap; gap: .5rem 1.25rem; font-size: var(--fs-13); color: var(--c-ink-500); }
.ev__card-meta span { display: inline-flex; align-items: center; gap: .3rem; }

.ev__card-pesada {
  display: inline-flex; align-items: center; gap: .4rem;
  margin-top: .5rem; font-size: var(--fs-13); color: var(--c-ink-600);
  background: var(--c-ink-100); border-radius: var(--r-md); padding: .375rem .75rem;
}

.ev__card-info {
  margin-top: .5rem;
  font-size: var(--fs-13); color: var(--c-ink-500);
  background: var(--c-ink-100); border-radius: var(--r-md);
  padding: .5rem .75rem;
}
</style>
