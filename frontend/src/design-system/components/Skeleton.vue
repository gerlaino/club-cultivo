<template>
  <div :class="['ds-skeleton', `ds-skeleton--${variant}`]" aria-hidden="true">
    <template v-if="variant === 'card'">
      <div class="ds-skeleton__block ds-skeleton__block--title" />
      <div class="ds-skeleton__block ds-skeleton__block--line" />
      <div class="ds-skeleton__block ds-skeleton__block--line ds-skeleton__block--short" />
    </template>
    <template v-else-if="variant === 'table'">
      <div v-for="i in rows" :key="i" class="ds-skeleton__row">
        <div v-for="j in cols" :key="j" class="ds-skeleton__block ds-skeleton__block--cell" />
      </div>
    </template>
    <template v-else>
      <div class="ds-skeleton__block ds-skeleton__block--line" />
    </template>
  </div>
</template>

<script setup>
defineProps({
  variant: { type: String, default: 'line' },
  rows:    { type: Number, default: 4 },
  cols:    { type: Number, default: 3 },
})
</script>

<style scoped>
@keyframes ds-shimmer {
  0%   { background-position: -400px 0; }
  100% { background-position:  400px 0; }
}

.ds-skeleton__block {
  border-radius: var(--r-sm);
  background: linear-gradient(90deg, var(--c-ink-100) 25%, #e8eaed 50%, var(--c-ink-100) 75%);
  background-size: 800px 100%;
  animation: ds-shimmer 1.6s infinite linear;
}

.ds-skeleton__block--title  { height: 20px; width: 55%; margin-bottom: var(--sp-3); }
.ds-skeleton__block--line   { height: 14px; width: 100%; margin-bottom: var(--sp-2); }
.ds-skeleton__block--short  { width: 65%; }
.ds-skeleton__block--cell   { height: 14px; flex: 1; }

.ds-skeleton--card  { padding: var(--sp-5); }
.ds-skeleton--table .ds-skeleton__row {
  display: flex;
  gap: var(--sp-4);
  margin-bottom: var(--sp-3);
}
</style>
