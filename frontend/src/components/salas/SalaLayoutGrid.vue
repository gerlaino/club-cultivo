<script setup>
import { computed } from 'vue'

const props = defineProps({
  sala:         { type: Object, required: true },
  lotesActivos: { type: Array,  default: () => [] },
})

const COLORES = [
  { bg: '#dcfce7', border: '#16a34a', text: '#15803d' },
  { bg: '#dbeafe', border: '#2563eb', text: '#1d4ed8' },
  { bg: '#fef3c7', border: '#d97706', text: '#b45309' },
  { bg: '#ede9fe', border: '#7c3aed', text: '#6d28d9' },
  { bg: '#fee2e2', border: '#dc2626', text: '#b91c1c' },
  { bg: '#cffafe', border: '#0891b2', text: '#0e7490' },
  { bg: '#fce7f3', border: '#db2777', text: '#be185d' },
]

const totalPots = computed(() => Number(props.sala?.pots_count) || 0)

const cols = computed(() => {
  const n = totalPots.value
  if (n <= 0)  return 5
  if (n <= 6)  return n
  if (n <= 12) return 4
  if (n <= 30) return 5
  if (n <= 60) return 8
  return 10
})

const colorMap = computed(() => {
  const map = {}
  const sorted = [...props.lotesActivos].sort((a, b) => a.id - b.id)
  sorted.forEach((l, idx) => { map[l.id] = COLORES[idx % COLORES.length] })
  return map
})

const pots = computed(() => {
  const sorted = [...props.lotesActivos].sort((a, b) => a.id - b.id)
  const potToLote = {}
  let cursor = 0
  for (const l of sorted) {
    const n = Number(l.plants_count || 0)
    for (let i = 0; i < n && cursor < totalPots.value; i++, cursor++) {
      potToLote[cursor] = l
    }
  }
  return Array.from({ length: totalPots.value }, (_, i) => {
    const lote = potToLote[i] || null
    return { index: i + 1, lote, color: lote ? colorMap.value[lote.id] : null }
  })
})

const leyenda = computed(() =>
  [...props.lotesActivos].sort((a, b) => a.id - b.id).map((l, idx) => ({
    ...l, color: COLORES[idx % COLORES.length],
  }))
)

const ocupados = computed(() => pots.value.filter(p => p.lote).length)
const libres   = computed(() => totalPots.value - ocupados.value)
</script>

<template>
  <div class="slg">
    <div v-if="!totalPots" class="slg__empty">
      <div class="slg__empty-icon">🗺</div>
      <p class="slg__empty-title">Capacidad no configurada</p>
      <p class="slg__empty-sub">Editá la sala y configurá la cantidad de pots para ver el layout visual.</p>
    </div>

    <template v-else>
      <div class="slg__occ-bar">
        <div class="slg__occ-track">
          <div class="slg__occ-fill" :style="{ width: Math.min((ocupados / totalPots) * 100, 100) + '%' }"></div>
        </div>
        <span class="slg__occ-label">{{ ocupados }}/{{ totalPots }} pots · {{ libres }} libres</span>
      </div>

      <div class="slg__grid" :style="{ gridTemplateColumns: `repeat(${cols}, 1fr)` }">
        <div
          v-for="pot in pots"
          :key="pot.index"
          class="slg__pot"
          :class="{ 'slg__pot--libre': !pot.lote }"
          :style="pot.color ? { background: pot.color.bg, borderColor: pot.color.border } : {}"
          :title="pot.lote ? `${pot.lote.codigo} · ${pot.lote.estado}` : `Pot ${pot.index} — libre`"
        >
          <span class="slg__pot-n">{{ pot.index }}</span>
          <span v-if="pot.lote" class="slg__pot-dot" :style="{ background: pot.color.border }"></span>
        </div>
      </div>

      <div v-if="leyenda.length" class="slg__legend">
        <div v-for="l in leyenda" :key="l.id" class="slg__legend-item">
          <span class="slg__legend-dot" :style="{ background: l.color.border }"></span>
          <span class="slg__legend-codigo">{{ l.codigo }}</span>
          <span class="slg__legend-estado" :style="{ color: l.color.text }">{{ l.estado }}</span>
          <span class="slg__legend-cnt">{{ l.plants_count }} plants</span>
          <span v-if="l.genetica_nombre" class="slg__legend-gen">· {{ l.genetica_nombre }}</span>
        </div>
        <div v-if="libres > 0" class="slg__legend-item slg__legend-item--libre">
          <span class="slg__legend-dot slg__legend-dot--libre"></span>
          <span class="slg__legend-codigo">Libres</span>
          <span class="slg__legend-cnt">{{ libres }} pots</span>
        </div>
      </div>
      <div v-else class="slg__legend-empty">Sin lotes activos asignados a esta sala.</div>
    </template>
  </div>
</template>

<style scoped>
.slg { display: flex; flex-direction: column; gap: 1rem; }

.slg__empty { text-align: center; padding: 2.5rem 1rem; }
.slg__empty-icon { font-size: 2.5rem; margin-bottom: .5rem; }
.slg__empty-title { font-size: .95rem; font-weight: 700; color: #475569; margin: 0 0 .3rem; }
.slg__empty-sub { font-size: .8rem; color: #94a3b8; margin: 0; }

.slg__occ-bar { display: flex; align-items: center; gap: .75rem; }
.slg__occ-track { flex: 1; height: 8px; background: #e2e8f0; border-radius: 4px; overflow: hidden; }
.slg__occ-fill { height: 100%; background: #16a34a; border-radius: 4px; transition: width .3s; }
.slg__occ-label { font-size: .75rem; color: #64748b; white-space: nowrap; font-weight: 500; }

.slg__grid { display: grid; gap: 6px; }
.slg__pot {
  aspect-ratio: 1; border-radius: 8px; border: 1.5px solid #d4e6d4;
  background: #f0fdf4; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 2px;
  cursor: default; transition: transform .12s, box-shadow .12s;
  min-width: 0; min-height: 0;
}
.slg__pot:hover { transform: scale(1.1); box-shadow: 0 2px 8px rgba(0,0,0,.12); z-index: 1; }
.slg__pot--libre { background: #f8fafc; border-color: #e2e8f0; }
.slg__pot-n { font-size: .58rem; font-weight: 700; color: #94a3b8; line-height: 1; }
.slg__pot-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }

.slg__legend { display: flex; flex-wrap: wrap; gap: .4rem; }
.slg__legend-item {
  display: flex; align-items: center; gap: .3rem;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px;
  padding: .28rem .55rem; font-size: .73rem;
}
.slg__legend-item--libre { opacity: .65; }
.slg__legend-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; background: #e2e8f0; }
.slg__legend-dot--libre { background: #cbd5e1; }
.slg__legend-codigo { font-weight: 700; color: #1a1a1a; }
.slg__legend-estado { font-size: .68rem; text-transform: capitalize; }
.slg__legend-cnt { color: #64748b; font-size: .68rem; }
.slg__legend-gen { color: #15803d; font-size: .68rem; font-style: italic; }
.slg__legend-empty { font-size: .8rem; color: #94a3b8; text-align: center; padding: .75rem 0; }
</style>
