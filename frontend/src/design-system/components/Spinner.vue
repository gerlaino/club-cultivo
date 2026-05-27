<template>
  <span class="ds-spinner" :style="{ width: size + 'px', height: size + 'px' }" aria-hidden="true">
    <img src="/logo-ce-icono.png" class="ds-spinner__logo" alt="" />
  </span>
</template>

<script setup>
defineProps({
  size: { type: [Number, String], default: 48 },
})
</script>

<style scoped>
.ds-spinner {
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.ds-spinner__logo {
  width: 100%;
  height: 100%;
  object-fit: contain;
  border-radius: 50%;
  animation: ds-pulse 1.2s ease-in-out infinite alternate;
}

@keyframes ds-pulse {
  from { opacity: 0.45; transform: scale(0.88); }
  to   { opacity: 1;    transform: scale(1); }
}

@media (prefers-reduced-motion: reduce) {
  .ds-spinner__logo { animation: none; opacity: 0.8; }
}
</style>
