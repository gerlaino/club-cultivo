<template>
  <Teleport to="body">
    <Transition name="sb-backdrop">
      <div v-if="modelValue" class="sb__backdrop" @click="close" />
    </Transition>
    <Transition name="sb-sheet">
      <div
        v-if="modelValue"
        class="sb__sheet"
        role="dialog"
        :aria-label="title || 'Panel'"
        @touchstart="onTouchStart"
        @touchmove="onTouchMove"
        @touchend="onTouchEnd"
      >
        <div class="sb__handle-wrap" @click="close">
          <div class="sb__handle" />
        </div>
        <div v-if="title" class="sb__header">
          <span class="sb__title">{{ title }}</span>
          <button class="sb__close" @click="close" aria-label="Cerrar">
            <X :size="18" :stroke-width="1.75" />
          </button>
        </div>
        <div class="sb__body">
          <slot />
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { watch, ref } from 'vue'
import { X } from 'lucide-vue-next'

const props = defineProps({
  modelValue: { type: Boolean, required: true },
  title:      { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue'])

function close() { emit('update:modelValue', false) }

// Body scroll lock
watch(() => props.modelValue, (open) => {
  document.body.style.overflow = open ? 'hidden' : ''
})

// ESC key
function onKey(e) { if (e.key === 'Escape') close() }
watch(() => props.modelValue, (open) => {
  if (open) document.addEventListener('keydown', onKey)
  else      document.removeEventListener('keydown', onKey)
}, { immediate: true })

// Swipe-down to close
const touchStartY = ref(0)
const touchDeltaY = ref(0)
function onTouchStart(e) { touchStartY.value = e.touches[0].clientY }
function onTouchMove(e)  { touchDeltaY.value = e.touches[0].clientY - touchStartY.value }
function onTouchEnd()    { if (touchDeltaY.value > 80) close(); touchDeltaY.value = 0 }
</script>

<style scoped>
.sb__backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 500;
}
.sb__sheet {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--c-paper);
  border-radius: 20px 20px 0 0;
  max-height: 82vh;
  overflow-y: auto;
  overscroll-behavior: contain;
  z-index: 501;
  box-shadow: 0 -4px 32px rgba(0, 0, 0, 0.14);
}
.sb__handle-wrap {
  display: flex;
  justify-content: center;
  padding: var(--sp-3) 0 var(--sp-2);
  cursor: pointer;
}
.sb__handle {
  width: 40px;
  height: 4px;
  border-radius: var(--r-pill);
  background: var(--c-ink-300);
}
.sb__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-4) var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
}
.sb__title {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 600;
  color: var(--c-ink-900);
}
.sb__close {
  width: 32px;
  height: 32px;
  border-radius: var(--r-md);
  border: none;
  background: var(--c-ink-100);
  color: var(--c-ink-500);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background var(--t-fast);
}
.sb__close:hover { background: var(--c-ink-300); }
.sb__body { padding: var(--sp-4); }

/* Animations */
.sb-backdrop-enter-active { transition: opacity 150ms ease-out; }
.sb-backdrop-leave-active { transition: opacity 200ms ease-in; }
.sb-backdrop-enter-from,
.sb-backdrop-leave-to   { opacity: 0; }

.sb-sheet-enter-active { transition: transform 250ms cubic-bezier(0.16, 1, 0.3, 1); }
.sb-sheet-leave-active { transition: transform 200ms ease-in; }
.sb-sheet-enter-from,
.sb-sheet-leave-to   { transform: translateY(100%); }
</style>
