<template>
  <span :class="['ds-badge', `ds-badge--${variant}`, `ds-badge--${size}`]">
    <slot />
  </span>
</template>

<script setup>
defineProps({
  variant: { type: String, default: 'leaf' },
  size:    { type: String, default: 'md' },
})
</script>

<style scoped>
.ds-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-family: var(--font-ui);
  font-weight: 500;
  border-radius: var(--r-pill);
  white-space: nowrap;
}

.ds-badge--sm { font-size: var(--fs-12); padding: 1px var(--sp-2); }
.ds-badge--md { font-size: var(--fs-13); padding: 2px var(--sp-3); }
.ds-badge--lg { font-size: var(--fs-14); padding: var(--sp-1) var(--sp-4); }

.ds-badge--leaf  { background: var(--c-leaf-100);  color: var(--c-leaf-800); }
.ds-badge--amber { background: var(--c-amber-100); color: var(--c-amber-500); }
.ds-badge--rust  { background: var(--c-rust-100);  color: var(--c-rust-600); }
.ds-badge--gold  { background: #FEF3C7;            color: var(--c-gold-500); }
.ds-badge--sky   { background: var(--c-sky-100);   color: var(--c-sky-600); }
.ds-badge--ink   { background: var(--c-ink-100);   color: var(--c-ink-700); }
</style>
