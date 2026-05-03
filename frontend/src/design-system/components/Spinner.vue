<template>
  <span class="ds-spinner" :style="{ width: size + 'px', height: size + 'px' }" aria-hidden="true">
    <LeafSeal :size="size" class="ds-spinner__leaf" />
  </span>
</template>

<script setup>
import LeafSeal from '../icons/LeafSeal.vue'

defineProps({
  size: { type: [Number, String], default: 20 },
})
</script>

<style scoped>
.ds-spinner {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: currentColor;
}

.ds-spinner__leaf {
  animation: ds-spin 1s linear infinite, ds-pulse 1s ease-in-out infinite alternate;
}

@keyframes ds-spin {
  to { transform: rotate(360deg); }
}

@keyframes ds-pulse {
  from { opacity: 0.5; }
  to   { opacity: 1; }
}

@media (prefers-reduced-motion: reduce) {
  .ds-spinner__leaf { animation: none; opacity: 0.7; }
}
</style>
