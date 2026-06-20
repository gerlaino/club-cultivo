<template>
  <Teleport to="body">
    <Transition name="msheet">
      <div v-if="modelValue" class="msheet" @click.self="close">
        <div class="msheet__panel" :class="{ 'msheet__panel--full': full }" role="dialog" aria-modal="true">
          <div class="msheet__grab" @click="close"></div>

          <header v-if="title || $slots.header" class="msheet__head">
            <slot name="header">
              <h2 class="msheet__title">{{ title }}</h2>
            </slot>
            <button class="msheet__close" @click="close" aria-label="Cerrar">
              <i class="bi bi-x-lg"></i>
            </button>
          </header>

          <div class="msheet__body" :class="{ 'msheet__body--flush': flush }">
            <slot />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
import { watch, onBeforeUnmount } from 'vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  title:      { type: String,  default: '' },
  full:       { type: Boolean, default: false }, // ocupa casi toda la altura (formularios largos)
  flush:      { type: Boolean, default: false }, // sin padding en el body
})
const emit = defineEmits(['update:modelValue'])

function close() { emit('update:modelValue', false) }

// Bloquea el scroll del fondo mientras la hoja está abierta.
watch(() => props.modelValue, (open) => {
  document.documentElement.style.overflow = open ? 'hidden' : ''
}, { immediate: true })
onBeforeUnmount(() => { document.documentElement.style.overflow = '' })
</script>

<style scoped>
.msheet {
  position: fixed; inset: 0;
  z-index: 1200;
  display: flex; align-items: flex-end; justify-content: center;
  background: rgba(15, 42, 30, .45);
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
}
.msheet__panel {
  width: 100%;
  max-width: 560px;
  max-height: 88dvh;
  background: var(--c-paper, #f4f8f5);
  border-radius: 22px 22px 0 0;
  box-shadow: 0 -10px 40px rgba(15, 42, 30, .28);
  display: flex; flex-direction: column;
  padding-bottom: env(safe-area-inset-bottom);
  overflow: hidden;
}
.msheet__panel--full { max-height: 94dvh; min-height: 70dvh; }

.msheet__grab {
  flex-shrink: 0;
  width: 44px; height: 5px;
  margin: 10px auto 4px;
  border-radius: 999px;
  background: var(--c-ink-300, #d1d5db);
  cursor: grab;
}
.msheet__head {
  flex-shrink: 0;
  display: flex; align-items: center; justify-content: space-between;
  gap: .75rem;
  padding: .35rem 1.1rem .75rem;
  border-bottom: 1px solid var(--c-leaf-100, #e8f0eb);
}
.msheet__title {
  margin: 0;
  font-family: var(--font-display, 'General Sans', sans-serif);
  font-size: 1.15rem; font-weight: 700;
  color: var(--c-ink-900, #1a1d1f);
}
.msheet__close {
  flex-shrink: 0;
  width: 34px; height: 34px; border-radius: 10px;
  border: none; background: var(--c-leaf-100, #e8f0eb);
  color: var(--c-leaf-700, #2d4a3e);
  display: flex; align-items: center; justify-content: center;
  font-size: .95rem; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  transition: background .15s;
}
.msheet__close:hover { background: var(--c-leaf-300, #a8c9b5); }

.msheet__body { overflow-y: auto; padding: 1rem 1.1rem 1.25rem; }
.msheet__body--flush { padding: 0; }

/* Transición: slide-up + fade del backdrop */
.msheet-enter-active, .msheet-leave-active { transition: opacity .26s ease; }
.msheet-enter-active .msheet__panel,
.msheet-leave-active .msheet__panel { transition: transform .3s cubic-bezier(.22,1,.36,1); }
.msheet-enter-from, .msheet-leave-to { opacity: 0; }
.msheet-enter-from .msheet__panel,
.msheet-leave-to  .msheet__panel { transform: translateY(100%); }
</style>
