<template>
  <div class="ds-drop" ref="rootRef">
    <slot name="anchor" />
    <Transition name="ds-drop-fade">
      <div
        v-if="modelValue"
        class="ds-drop__panel"
        :class="`ds-drop__panel--${align}`"
        @click.stop
      >
        <slot name="panel" />
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

defineProps({
  modelValue: { type: Boolean, default: false },
  align:      { type: String, default: 'right' },
})
const emit = defineEmits(['update:modelValue'])

const rootRef = ref(null)

function onOutside(e) {
  if (rootRef.value && !rootRef.value.contains(e.target)) {
    emit('update:modelValue', false)
  }
}
function onKey(e) {
  if (e.key === 'Escape') emit('update:modelValue', false)
}

onMounted(() => {
  document.addEventListener('mousedown', onOutside)
  document.addEventListener('keydown', onKey)
})
onBeforeUnmount(() => {
  document.removeEventListener('mousedown', onOutside)
  document.removeEventListener('keydown', onKey)
})
</script>

<style scoped>
.ds-drop { position: relative; }

.ds-drop__panel {
  position: absolute;
  top: calc(100% + 6px);
  z-index: 1000;
  background: #fff;
  border-radius: var(--r-xl);
  box-shadow: var(--sh-3), 0 0 0 1px rgba(0,0,0,0.05);
  overflow: hidden;
}
.ds-drop__panel--right { right: 0; }
.ds-drop__panel--left  { left: 0;  }

.ds-drop-fade-enter-active { transition: opacity var(--t-fast), transform var(--t-fast); }
.ds-drop-fade-leave-active { transition: opacity 80ms ease-in, transform 80ms ease-in; }
.ds-drop-fade-enter-from,
.ds-drop-fade-leave-to     { opacity: 0; transform: translateY(-4px); }
</style>
