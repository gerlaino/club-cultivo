<template>
  <button
    :class="[
      'ds-btn',
      `ds-btn--${variant}`,
      `ds-btn--${size}`,
      { 'ds-btn--loading': loading },
    ]"
    :disabled="disabled || loading"
    v-bind="$attrs"
  >
    <Spinner v-if="loading" :size="spinnerSize" class="ds-btn__spinner" />
    <template v-else>
      <slot />
    </template>
  </button>
</template>

<script setup>
import { computed } from 'vue'
import Spinner from './Spinner.vue'

const props = defineProps({
  variant: { type: String, default: 'primary' },
  size:    { type: String, default: 'md' },
  loading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
})

const spinnerSize = computed(() => ({ sm: 12, md: 14, lg: 16 }[props.size] ?? 14))
</script>

<style scoped>
.ds-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--sp-2);
  border: none;
  border-radius: var(--r-md);
  font-family: var(--font-ui);
  font-weight: 500;
  cursor: pointer;
  transition: background var(--t-fast), color var(--t-fast), border-color var(--t-fast), opacity var(--t-fast);
  white-space: nowrap;
  text-decoration: none;
}

.ds-btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

/* Sizes */
.ds-btn--sm { padding: var(--sp-1) var(--sp-3); font-size: var(--fs-12); min-height: 28px; }
.ds-btn--md { padding: var(--sp-2) var(--sp-4); font-size: var(--fs-14); min-height: 36px; }
.ds-btn--lg { padding: var(--sp-3) var(--sp-6); font-size: var(--fs-16); min-height: 44px; }

/* Primary */
.ds-btn--primary {
  background: var(--c-leaf-700);
  color: #fff;
}
.ds-btn--primary:hover:not(:disabled) { background: var(--c-leaf-600); }
.ds-btn--primary:active:not(:disabled) { background: var(--c-leaf-800); }

/* Secondary */
.ds-btn--secondary {
  background: transparent;
  color: var(--c-leaf-700);
  border: 1.5px solid var(--c-leaf-700);
}
.ds-btn--secondary:hover:not(:disabled) { background: var(--c-leaf-50); }
.ds-btn--secondary:active:not(:disabled) { background: var(--c-leaf-100); }

/* Ghost */
.ds-btn--ghost {
  background: transparent;
  color: var(--c-leaf-700);
}
.ds-btn--ghost:hover:not(:disabled) { background: var(--c-leaf-100); }
.ds-btn--ghost:active:not(:disabled) { background: var(--c-leaf-300); }

/* Danger */
.ds-btn--danger {
  background: #b91c1c;
  color: #fff;
}
.ds-btn--danger:hover:not(:disabled) { background: #991b1b; }
.ds-btn--danger:active:not(:disabled) { background: #7f1d1d; }

/* Icon */
.ds-btn--icon {
  background: transparent;
  color: var(--c-ink-700);
  padding: var(--sp-2);
  border-radius: var(--r-md);
  aspect-ratio: 1;
}
.ds-btn--icon.ds-btn--sm { padding: var(--sp-1); }
.ds-btn--icon.ds-btn--lg { padding: var(--sp-3); }
.ds-btn--icon:hover:not(:disabled) { background: var(--c-ink-100); color: var(--c-ink-900); }

/* Loading */
.ds-btn--loading { cursor: wait; }
.ds-btn__spinner { flex-shrink: 0; }
</style>
