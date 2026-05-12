<template>
  <div class="cv">

    <!-- Header -->
    <div class="cv__header">
      <div>
        <h1 class="cv__title">Cosecha</h1>
        <p class="cv__sub">Lotes post-cosecha de tus salas asignadas</p>
      </div>
    </div>

    <!-- Stats -->
    <div class="cv__kpis">
      <div class="cv__kpi">
        <div class="cv__kpi-val">{{ loading ? '—' : lotesCosechados.length }}</div>
        <div class="cv__kpi-label">Lotes</div>
      </div>
      <div class="cv__kpi">
        <div class="cv__kpi-val">{{ loading ? '—' : totalPlantas }}</div>
        <div class="cv__kpi-label">Plantas cosechadas</div>
      </div>
      <div class="cv__kpi">
        <div class="cv__kpi-val">{{ loading ? '—' : formatGramos(totalGramos) }}</div>
        <div class="cv__kpi-label">Producción total</div>
        <div class="cv__kpi-hint">solo lotes finalizados</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="cv__filters">
      <button
        v-for="f in FILTROS" :key="f.key"
        class="cv__chip"
        :class="{ 'cv__chip--active': filtro === f.key }"
        @click="filtro = f.key"
      >
        {{ f.label }}
        <span class="cv__chip-count">{{ contar(f.key) }}</span>
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="cv__loading">
      <div class="cv__spinner"></div>
      <span>Cargando lotes…</span>
    </div>

    <!-- Empty -->
    <div v-else-if="!lotesFiltrados.length" class="cv__empty">
      <Sprout :size="32" :stroke-width="1.25" />
      <p>Sin lotes en esta vista</p>
      <span v-if="filtro === 'todos'">
        Los lotes aparecen acá cuando avanzan a cosecha o finalización.
      </span>
      <span v-else>Cambiá el filtro para ver otros estados.</span>
    </div>

    <!-- List -->
    <div v-else class="cv__list">
      <RouterLink
        v-for="lote in lotesFiltrados"
        :key="lote.id"
        :to="{ name: 'lote-detail', params: { id: lote.id } }"
        class="cv__row"
      >
        <div class="cv__row-av" :class="`cv__av--${lote.estado}`">
          <Leaf :size="14" :stroke-width="2" />
        </div>

        <div class="cv__row-info">
          <span class="cv__row-codigo">{{ lote.codigo }}</span>
          <span class="cv__row-sep">·</span>
          <span class="cv__row-cepa">{{ lote.genetica?.nombre || '—' }}</span>
          <span class="cv__row-sep">·</span>
          <span class="cv__row-sala">{{ lote.sala?.nombre || '—' }}</span>
        </div>

        <div class="cv__row-right">
          <span v-if="pesoLote(lote)" class="cv__row-peso">
            {{ formatGramos(pesoLote(lote)) }}
          </span>
          <span class="cv__badge" :class="`cv__badge--${lote.estado}`">
            {{ ESTADO_LABEL[lote.estado] || lote.estado }}
          </span>
          <ChevronRight :size="15" class="cv__row-arrow" />
        </div>
      </RouterLink>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listLotes } from '../lib/api.js'
import { ChevronRight, Sprout, Leaf } from 'lucide-vue-next'

const ESTADOS_COSECHA = ['cosecha', 'en_manicura', 'manicura_pendiente', 'curado', 'finalizado']

const ESTADO_LABEL = {
  cosecha:            'Cosechado',
  en_manicura:        'En manicura',
  manicura_pendiente: 'Pdte. aprobación',
  curado:             'Curando',
  finalizado:         'Finalizado',
}

const FILTROS = [
  { key: 'todos',             label: 'Todos' },
  { key: 'cosecha',           label: 'Cosechado' },
  { key: 'en_manicura',       label: 'En manicura' },
  { key: 'manicura_pendiente',label: 'Pdte. aprobación' },
  { key: 'finalizado',        label: 'Finalizado' },
]

const loading = ref(true)
const lotes   = ref([])
const filtro  = ref('todos')

const lotesCosechados = computed(() =>
  lotes.value
    .filter(l => ESTADOS_COSECHA.includes(l.estado))
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
)

const lotesFiltrados = computed(() => {
  if (filtro.value === 'todos') return lotesCosechados.value
  return lotesCosechados.value.filter(l => l.estado === filtro.value)
})

function contar(key) {
  if (key === 'todos') return lotesCosechados.value.length
  return lotesCosechados.value.filter(l => l.estado === key).length
}

function pesoLote(lote) {
  return lote.gramos_producidos || lote.peso_final_g || lote.ultima_pesada_manicura?.peso_seco_g || null
}

const totalGramos = computed(() =>
  lotesCosechados.value
    .filter(l => l.estado === 'finalizado')
    .reduce((acc, l) => acc + (pesoLote(l) || 0), 0)
)
const totalPlantas = computed(() =>
  lotesCosechados.value.reduce((acc, l) => acc + (l.plants_count || 0), 0)
)

function formatGramos(g) {
  if (!g) return '—'
  if (g >= 1000) return (g / 1000).toFixed(2).replace('.', ',') + ' kg'
  return Math.round(g) + ' g'
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
.cv { padding: var(--sp-6); max-width: 900px; }

/* Header */
.cv__header { margin-bottom: var(--sp-5); }
.cv__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.cv__sub   { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

/* KPIs */
.cv__kpis {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--sp-3);
  margin-bottom: var(--sp-5);
}
@media (max-width: 600px) { .cv__kpis { grid-template-columns: 1fr 1fr; } }

.cv__kpi {
  background: var(--c-paper);
  border: 1px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-5);
}
.cv__kpi-val {
  font-size: var(--fs-24);
  font-weight: 800;
  color: var(--c-ink-900);
  letter-spacing: -.03em;
  margin-bottom: 2px;
  font-family: var(--font-mono);
}
.cv__kpi-label {
  font-size: var(--fs-12);
  font-weight: 600;
  color: var(--c-ink-500);
  text-transform: uppercase;
  letter-spacing: .04em;
}
.cv__kpi-hint {
  font-size: var(--fs-11);
  color: var(--c-ink-300);
  margin-top: 2px;
}

/* Filters */
.cv__filters { display: flex; gap: var(--sp-2); margin-bottom: var(--sp-5); flex-wrap: wrap; }
.cv__chip {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: var(--c-paper); border: 1px solid var(--c-ink-200);
  border-radius: 999px; padding: var(--sp-1) var(--sp-3);
  font-size: var(--fs-13); font-weight: 500; color: var(--c-ink-600);
  cursor: pointer; transition: all .15s;
}
.cv__chip:hover { border-color: var(--c-role-cultivador); color: var(--c-role-cultivador); }
.cv__chip--active { background: var(--c-role-cultivador); border-color: var(--c-role-cultivador); color: #fff; }
.cv__chip-count {
  font-size: var(--fs-11); font-weight: 700;
  background: rgba(255,255,255,.25); border-radius: 999px;
  padding: 1px 6px; line-height: 1.4;
}
.cv__chip:not(.cv__chip--active) .cv__chip-count { background: var(--c-ink-100); color: var(--c-ink-500); }

/* Loading */
.cv__loading {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-12) 0; justify-content: center;
  color: var(--c-ink-400); font-size: var(--fs-14);
}
.cv__spinner {
  width: 18px; height: 18px;
  border: 2px solid var(--c-ink-200); border-top-color: var(--c-role-cultivador);
  border-radius: 50%; animation: cv-spin .7s linear infinite;
}
@keyframes cv-spin { to { transform: rotate(360deg); } }

/* Empty */
.cv__empty {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-2);
  padding: var(--sp-12) var(--sp-6); color: var(--c-ink-300); text-align: center;
}
.cv__empty p    { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-600); margin: 0; }
.cv__empty span { font-size: var(--fs-13); color: var(--c-ink-400); max-width: 340px; }

/* List */
.cv__list { display: flex; flex-direction: column; gap: 2px; }

.cv__row {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  text-decoration: none; color: inherit;
  transition: border-color .15s, box-shadow .15s;
}
.cv__row:hover {
  border-color: var(--c-role-cultivador);
  box-shadow: 0 1px 6px rgba(8,145,178,.08);
}

.cv__row-av {
  width: 32px; height: 32px; border-radius: var(--r-sm);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.cv__av--cosecha            { background: #dcfce7; color: #15803d; }
.cv__av--en_manicura        { background: #ede9fe; color: #7c3aed; }
.cv__av--manicura_pendiente { background: #fff7ed; color: #c2410c; }
.cv__av--curado             { background: #eff6ff; color: #1d4ed8; }
.cv__av--finalizado         { background: var(--c-ink-100); color: var(--c-ink-500); }

.cv__row-info {
  flex: 1; min-width: 0;
  display: flex; align-items: baseline; gap: var(--sp-2); overflow: hidden;
}
.cv__row-codigo {
  font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900);
  font-family: var(--font-mono); white-space: nowrap; flex-shrink: 0;
}
.cv__row-sep   { color: var(--c-ink-300); font-size: var(--fs-11); flex-shrink: 0; }
.cv__row-cepa  { font-size: var(--fs-13); color: var(--c-ink-700); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__row-sala  { font-size: var(--fs-12); color: var(--c-ink-400); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.cv__row-right { display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0; }
.cv__row-peso {
  font-family: var(--font-mono); font-size: var(--fs-12);
  font-weight: 600; color: var(--c-leaf-700);
}
.cv__row-arrow { color: var(--c-ink-300); }

/* Badge estados */
.cv__badge {
  font-size: 11px; font-weight: 600; padding: .2em .65em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; white-space: nowrap;
}
.cv__badge--cosecha            { background: #dcfce7; color: #15803d; }
.cv__badge--en_manicura        { background: #ede9fe; color: #7c3aed; }
.cv__badge--manicura_pendiente { background: #fff7ed; color: #c2410c; }
.cv__badge--curado             { background: #eff6ff; color: #1d4ed8; }
.cv__badge--finalizado         { background: var(--c-ink-100); color: var(--c-ink-500); }
</style>
