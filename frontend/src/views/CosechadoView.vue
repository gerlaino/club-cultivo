<template>
  <div class="cosh">

    <!-- Header -->
    <div class="cosh__header">
      <div>
        <h1 class="cosh__title">Mi cosecha</h1>
        <p class="cosh__sub">Historial de producción personal</p>
      </div>
    </div>

    <!-- Stats -->
    <div v-if="loading" class="cosh__stats">
      <DsCard v-for="i in 3" :key="i" variant="elevated" class="cosh__stat-card">
        <DsSkeleton variant="line" :rows="2" />
      </DsCard>
    </div>
    <div v-else class="cosh__stats">
      <DsCard variant="elevated" class="cosh__stat-card">
        <div class="cosh__stat-ico">🌿</div>
        <DsStat label="Ciclos completados" :value="String(lotesCosechados.length)" />
      </DsCard>
      <DsCard variant="elevated" class="cosh__stat-card">
        <div class="cosh__stat-ico">⚖️</div>
        <DsStat label="Gramos producidos" :value="formatGramos(totalGramos)" />
        <div class="cosh__stat-sub">solo lotes finalizados</div>
      </DsCard>
      <DsCard variant="elevated" class="cosh__stat-card">
        <div class="cosh__stat-ico">🪴</div>
        <DsStat label="Plantas cosechadas" :value="String(totalPlantas)" />
      </DsCard>
    </div>

    <!-- Lista -->
    <div class="cosh__section">
      <div class="cosh__section-head">
        <h2 class="cosh__section-title">Lotes post-cosecha</h2>
        <DsBadge variant="leaf">{{ lotesCosechados.length }}</DsBadge>
      </div>

      <div v-if="loading" class="cosh__list">
        <DsCard v-for="i in 4" :key="i" variant="elevated" class="cosh__row-skeleton">
          <DsSkeleton variant="line" :rows="2" />
        </DsCard>
      </div>

      <DsEmpty
        v-else-if="!lotesCosechados.length"
        title="Sin cosechas registradas"
        description="Los lotes aparecen acá cuando avanzan a cosecha o finalización. Si no ves nada, pedile al admin que te asigne a una sala."
      />

      <div v-else class="cosh__list">
        <RouterLink
          v-for="lote in lotesCosechados"
          :key="lote.id"
          :to="{ name: 'lote-detail', params: { id: lote.id } }"
          class="cosh__row"
        >
          <div class="cosh__row-left">
            <span class="cosh__estado-dot" :class="'cosh__estado-dot--' + lote.estado"></span>
            <div class="cosh__row-info">
              <span class="cosh__row-codigo">{{ lote.codigo }}</span>
              <span class="cosh__row-cepa">{{ lote.genetica?.nombre || lote.strain || '—' }}</span>
            </div>
          </div>

          <div class="cosh__row-mid">
            <span class="cosh__row-sala">{{ lote.sala?.nombre || '—' }}</span>
            <span class="cosh__row-fecha">Inicio: {{ formatFecha(lote.start_date) }}</span>
          </div>

          <div class="cosh__row-right">
            <span class="cosh__badge" :class="'cosh__badge--' + lote.estado">
              {{ ESTADO_LABEL[lote.estado] || lote.estado }}
            </span>
            <span v-if="pesoLote(lote)" class="cosh__row-peso">
              {{ formatGramos(pesoLote(lote)) }}
            </span>
          </div>

          <ChevronRight :size="16" :stroke-width="1.75" class="cosh__row-arr" />
        </RouterLink>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listLotes } from '../lib/api.js'
import { ChevronRight } from 'lucide-vue-next'
import DsCard     from '../design-system/components/Card.vue'
import DsStat     from '../design-system/components/Stat.vue'
import DsBadge    from '../design-system/components/Badge.vue'
import DsEmpty    from '../design-system/components/EmptyState.vue'
import DsSkeleton from '../design-system/components/Skeleton.vue'

const ESTADOS_COSECHA = ['cosecha', 'secado', 'manicura_pendiente', 'curado', 'finalizado']

const ESTADO_LABEL = {
  cosecha:           'Cosechado',
  secado:            'Secando',
  manicura_pendiente:'En manicura',
  curado:            'Curando',
  finalizado:        'Finalizado',
}

const loading = ref(true)
const lotes   = ref([])

const lotesCosechados = computed(() =>
  lotes.value
    .filter(l => ESTADOS_COSECHA.includes(l.estado))
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
)

function pesoLote(lote) {
  return lote.gramos_producidos ||
         lote.peso_final_g ||
         lote.ultima_pesada_manicura?.peso_seco_g ||
         null
}

const totalGramos  = computed(() =>
  lotesCosechados.value.reduce((acc, l) => acc + (pesoLote(l) || 0), 0)
)
const totalPlantas = computed(() =>
  lotesCosechados.value.reduce((acc, l) => acc + (l.plants_count || 0), 0)
)

function formatGramos(g) {
  if (!g) return '—'
  if (g >= 1000) return (g / 1000).toFixed(2).replace('.', ',') + ' kg'
  return g.toFixed(0) + ' g'
}

function formatFecha(d) {
  if (!d) return '—'
  return new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

onMounted(async () => {
  try {
    const { data } = await listLotes()
    lotes.value = data || []
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.cosh {
  max-width: 900px;
  margin: 0 auto;
  padding: var(--sp-8);
  font-family: var(--font-ui);
}
@media (max-width: 767px) {
  .cosh { padding: var(--sp-4); padding-bottom: 80px; }
}

/* Header */
.cosh__header {
  margin-bottom: var(--sp-6);
}
.cosh__title {
  font-family: var(--font-display);
  font-size: var(--fs-32);
  font-weight: 500;
  color: var(--c-ink-900);
  margin: 0 0 var(--sp-1);
  line-height: var(--lh-tight);
}
@media (max-width: 767px) { .cosh__title { font-size: var(--fs-24); } }
.cosh__sub {
  font-family: var(--font-mono);
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  margin: 0;
}

/* Stats */
.cosh__stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--sp-4);
  margin-bottom: var(--sp-8);
}
@media (max-width: 600px) {
  .cosh__stats { grid-template-columns: 1fr; gap: var(--sp-3); }
}
.cosh__stat-card { padding: var(--sp-4) var(--sp-5); }
.cosh__stat-ico { font-size: 20px; margin-bottom: var(--sp-2); }
.cosh__stat-sub {
  font-size: var(--fs-11);
  color: var(--c-ink-400);
  margin-top: var(--sp-1);
  font-family: var(--font-mono);
}

/* Section */
.cosh__section-head {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
.cosh__section-title {
  font-family: var(--font-display);
  font-size: var(--fs-18);
  font-weight: 600;
  color: var(--c-ink-900);
  margin: 0;
}

/* List */
.cosh__list {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}
.cosh__row-skeleton { padding: var(--sp-4); }

/* Row */
.cosh__row {
  display: flex;
  align-items: center;
  gap: var(--sp-4);
  padding: var(--sp-4) var(--sp-5);
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-xl);
  text-decoration: none;
  color: inherit;
  transition: border-color var(--t-fast), box-shadow var(--t-fast);
  cursor: pointer;
}
.cosh__row:hover {
  border-color: var(--c-role-cultivador);
  box-shadow: 0 2px 8px rgba(45, 74, 62, 0.08);
}
@media (max-width: 600px) {
  .cosh__row { flex-wrap: wrap; gap: var(--sp-2); }
}

.cosh__row-left {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  flex: 1;
  min-width: 0;
}
.cosh__row-info {
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.cosh__row-codigo {
  font-family: var(--font-mono);
  font-size: var(--fs-15);
  font-weight: 700;
  color: var(--c-ink-900);
}
.cosh__row-cepa {
  font-size: var(--fs-12);
  color: var(--c-ink-500);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.cosh__row-mid {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 140px;
}
.cosh__row-sala {
  font-size: var(--fs-13);
  font-weight: 500;
  color: var(--c-ink-700);
}
.cosh__row-fecha {
  font-size: var(--fs-11);
  font-family: var(--font-mono);
  color: var(--c-ink-400);
}

.cosh__row-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: var(--sp-1);
  min-width: 110px;
}
.cosh__row-peso {
  font-family: var(--font-mono);
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-leaf-700);
}
.cosh__row-arr {
  color: var(--c-ink-300);
  flex-shrink: 0;
}

/* Estado dot */
.cosh__estado-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.cosh__estado-dot--cosecha           { background: var(--c-leaf-500); }
.cosh__estado-dot--secado            { background: #f59e0b; }
.cosh__estado-dot--manicura_pendiente{ background: #f97316; }
.cosh__estado-dot--curado            { background: #3b82f6; }
.cosh__estado-dot--finalizado        { background: var(--c-ink-400); }

/* Estado badge */
.cosh__badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: var(--fs-11);
  font-weight: 600;
  font-family: var(--font-mono);
  white-space: nowrap;
}
.cosh__badge--cosecha            { background: rgba(34,197,94,.12); color: #15803d; }
.cosh__badge--secado             { background: rgba(245,158,11,.12); color: #b45309; }
.cosh__badge--manicura_pendiente { background: rgba(249,115,22,.12); color: #c2410c; }
.cosh__badge--curado             { background: rgba(59,130,246,.12); color: #1d4ed8; }
.cosh__badge--finalizado         { background: var(--c-ink-100); color: var(--c-ink-600); }
</style>
