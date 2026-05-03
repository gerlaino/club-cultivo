<template>
  <div :class="['ds-banner', `ds-banner--${variant}`]">
    <i v-if="icon" :class="['bi', icon, 'ds-banner__icon']"></i>
    <div class="ds-banner__body"><slot /></div>
    <div v-if="$slots.action" class="ds-banner__action"><slot name="action" /></div>
  </div>
</template>

<script setup>
defineProps({
  variant: { type: String, default: 'amber' },
  icon:    { type: String, default: '' },
})
</script>

<style scoped>
.ds-banner {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  border-radius: var(--r-lg);
  font-size: var(--fs-14);
  font-weight: 500;
}
.ds-banner--amber { background: var(--c-amber-100); color: var(--c-amber-500); border: 1px solid #fde68a; }
.ds-banner--rust  { background: var(--c-rust-100);  color: var(--c-rust-600);  border: 1px solid #fecaca; }
.ds-banner--sky   { background: var(--c-sky-100);   color: var(--c-sky-600);   border: 1px solid #bae6fd; }
.ds-banner--leaf  { background: var(--c-leaf-100);  color: var(--c-leaf-700);  border: 1px solid var(--c-leaf-300); }

.ds-banner__icon { font-size: var(--fs-16); flex-shrink: 0; }
.ds-banner__body { flex: 1; }
.ds-banner__action { flex-shrink: 0; }
.ds-banner__action :deep(a),
.ds-banner__action :deep(button) {
  font-size: var(--fs-12);
  font-weight: 700;
  color: inherit;
  text-decoration: none;
  opacity: .85;
  cursor: pointer;
  background: none;
  border: none;
  padding: 0;
}
.ds-banner__action :deep(a:hover),
.ds-banner__action :deep(button:hover) { opacity: 1; text-decoration: underline; }
</style>
