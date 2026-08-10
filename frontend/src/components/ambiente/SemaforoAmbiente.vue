<script setup>
import { computed } from 'vue'
import { formatValor } from '../../composables/useLecturaFormat.js'

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
    // Each item: { tipo, label, valor, unidad, min, max, ideal }
  },
})

const TIPO_META = {
  temperatura:         { icon: '🌡️', label: 'Temperatura' },
  humedad:             { icon: '💧', label: 'Humedad' },
  vpd:                 { icon: '🌫️', label: 'VPD' },
  co2:                 { icon: '🌬️', label: 'CO₂' },
  ppfd:                { icon: '💡', label: 'PPFD' },
  ec:                  { icon: '⚡', label: 'EC' },
  ph:                  { icon: '🧪', label: 'pH' },
  ph_runoff:           { icon: '🧫', label: 'pH runoff' },
  ec_runoff:           { icon: '⚗️', label: 'EC runoff' },
  temperatura_sustrato:{ icon: '🌱', label: 'Temp. sustrato' },
}

function colorClass(item) {
  const { valor, min, max } = item
  if (valor == null) return 'sem__pill--gray'
  if (min != null && max != null) {
    if (valor < min || valor > max) return 'sem__pill--red'
    const margen = (max - min) * 0.12
    if (valor < min + margen || valor > max - margen) return 'sem__pill--yellow'
  }
  return 'sem__pill--green'
}

const enriched = computed(() =>
  props.items.map(item => ({
    ...item,
    meta: TIPO_META[item.tipo] || { icon: '📊', label: item.tipo },
    colorClass: colorClass(item),
  }))
)
</script>

<template>
  <div class="sem">
    <div
      v-for="item in enriched"
      :key="item.tipo"
      class="sem__pill"
      :class="item.colorClass"
      :title="item.min != null ? `Rango: ${item.min}–${item.max} ${item.unidad || ''}` : ''"
    >
      <span class="sem__icon">{{ item.meta.icon }}</span>
      <div class="sem__body">
        <div class="sem__label">{{ item.label || item.meta.label }}</div>
        <div class="sem__valor">
          <span v-if="item.valor != null">
            {{ formatValor(item.valor, 1) }}
            <span class="sem__unidad">{{ item.unidad }}</span>
          </span>
          <span v-else class="sem__sin-dato">—</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sem {
  display: flex;
  flex-wrap: wrap;
  gap: .6rem;
}

.sem__pill {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .55rem .85rem;
  border-radius: 12px;
  border: 1.5px solid transparent;
  min-width: 130px;
  flex: 1;
  transition: box-shadow .15s;
}
.sem__pill:hover { box-shadow: 0 2px 8px rgba(0,0,0,.1); }

.sem__pill--green  { background: #f0fdf4; border-color: #86efac; color: #15803d; }
.sem__pill--yellow { background: #fffbeb; border-color: #fde68a; color: #b45309; }
.sem__pill--red    { background: #fef2f2; border-color: #fca5a5; color: #dc2626; }
.sem__pill--gray   { background: var(--c-slate-50); border-color: var(--c-slate-200); color: var(--c-slate-500); }

.sem__icon { font-size: 1.2rem; flex-shrink: 0; }
.sem__body { min-width: 0; }
.sem__label {
  font-size: .68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .05em;
  opacity: .8;
  margin-bottom: .1rem;
}
.sem__valor { font-size: 1.1rem; font-weight: 800; letter-spacing: -.02em; }
.sem__unidad { font-size: .72rem; font-weight: 500; margin-left: .15rem; }
.sem__sin-dato { font-size: .8rem; opacity: .5; font-weight: 400; }
</style>
