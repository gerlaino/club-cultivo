<template>
  <div class="ds-stat">
    <span class="ds-stat__label">{{ label }}</span>
    <span class="ds-stat__value" :style="tone ? { color: `var(--c-${tone})` } : {}">{{ value }}</span>
    <span v-if="delta !== undefined" :class="['ds-stat__delta', deltaClass]">
      <span class="ds-stat__delta-arrow">{{ deltaArrow }}</span>
      {{ Math.abs(delta) }}{{ deltaUnit }}
    </span>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  label:     { type: String, required: true },
  value:     { type: [String, Number], required: true },
  delta:     { type: Number, default: undefined },
  deltaUnit: { type: String, default: '' },
  tone:      { type: String, default: '' },
})

const deltaClass  = computed(() => {
  if (props.delta === undefined || props.delta === 0) return 'ds-stat__delta--neutral'
  return props.delta > 0 ? 'ds-stat__delta--up' : 'ds-stat__delta--down'
})

const deltaArrow  = computed(() => {
  if (props.delta === undefined || props.delta === 0) return '·'
  return props.delta > 0 ? '↑' : '↓'
})
</script>

<style scoped>
.ds-stat {
  display: flex;
  flex-direction: column;
  gap: var(--sp-1);
}

.ds-stat__label {
  font-size: var(--fs-12);
  font-weight: 500;
  color: var(--c-ink-500);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.ds-stat__value {
  font-size: var(--fs-32);
  font-weight: 700;
  font-family: var(--font-display);
  color: var(--c-ink-900);
  line-height: var(--lh-tight);
}

.ds-stat__delta {
  font-size: var(--fs-12);
  font-weight: 500;
  display: inline-flex;
  align-items: center;
  gap: 2px;
}

.ds-stat__delta--up      { color: var(--c-leaf-600); }
.ds-stat__delta--down    { color: var(--c-rust-600); }
.ds-stat__delta--neutral { color: var(--c-ink-500); }
</style>
