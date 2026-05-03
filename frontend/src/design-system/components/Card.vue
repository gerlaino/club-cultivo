<template>
  <div :class="['ds-card', `ds-card--${variant}`]" :style="paddingStyle">
    <slot />
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  variant: { type: String, default: 'default' },
  padding: { type: String, default: 'md' },
})

const PADDING_MAP = { none: '0', sm: 'var(--sp-3)', md: 'var(--sp-5)', lg: 'var(--sp-8)' }

const paddingStyle = computed(() => ({ padding: PADDING_MAP[props.padding] ?? props.padding }))
</script>

<style scoped>
.ds-card {
  background: #fff;
  border-radius: var(--r-xl);
}

.ds-card--default  { box-shadow: var(--sh-1); }
.ds-card--elevated { box-shadow: var(--sh-3); }
.ds-card--outlined { box-shadow: none; border: 1px solid var(--c-ink-300); }
</style>
