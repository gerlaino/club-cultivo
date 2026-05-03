<template>
  <span
    class="ds-av"
    :class="`ds-av--${size}`"
    :style="{ background: `var(--c-${tone})`, color: '#fff' }"
    :title="name"
  >{{ initials }}</span>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  name: { type: String, default: '' },
  tone: { type: String, default: 'ink-500' },
  size: { type: String, default: 'md' },
})

const initials = computed(() => {
  if (!props.name) return '?'
  const parts = props.name.trim().split(/\s+/)
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?'
})
</script>

<style scoped>
.ds-av {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  font-weight: 700;
  flex-shrink: 0;
  user-select: none;
  letter-spacing: -.01em;
}
.ds-av--sm { width: 28px; height: 28px; font-size: 11px; }
.ds-av--md { width: 36px; height: 36px; font-size: 14px; }
.ds-av--lg { width: 48px; height: 48px; font-size: 18px; }
</style>
