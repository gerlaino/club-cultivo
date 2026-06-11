<template>
  <Teleport to="body">
    <Transition name="bs">
      <div v-if="modelValue" class="bs__backdrop" @click.self="close">
        <div class="bs__sheet" :style="sheetStyle">
          <div class="bs__handle" />
          <div v-if="title" class="bs__header">
            <span class="bs__title">{{ title }}</span>
            <button class="bs__close" @click="close">✕</button>
          </div>
          <div class="bs__body">
            <slot />
          </div>
          <div v-if="$slots.footer" class="bs__footer">
            <slot name="footer" />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup>
const props = defineProps({
  modelValue: { type: Boolean, default: false },
  title:      { type: String,  default: '' },
  tall:       { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue'])

const sheetStyle = props.tall ? { maxHeight: '90vh' } : { maxHeight: '75vh' }

function close() { emit('update:modelValue', false) }
</script>

<style scoped>
.bs__backdrop {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.45);
  z-index: 200;
  display: flex; align-items: flex-end;
}
.bs__sheet {
  width: 100%;
  background: #fff;
  border-radius: 20px 20px 0 0;
  display: flex; flex-direction: column;
  padding-bottom: env(safe-area-inset-bottom, 0);
  overflow: hidden;
}
.bs__handle {
  width: 40px; height: 4px;
  background: #d4e6d4; border-radius: 999px;
  margin: .75rem auto .25rem; flex-shrink: 0;
}
.bs__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .25rem 1.25rem .75rem; flex-shrink: 0;
}
.bs__title { font-size: 1rem; font-weight: 700; color: var(--text); }
.bs__close {
  width: 32px; height: 32px; border-radius: 8px;
  background: var(--green-bg); color: var(--text-2);
  display: flex; align-items: center; justify-content: center; font-size: .85rem;
}
.bs__body {
  flex: 1; overflow-y: auto;
  padding: 0 1.25rem 1rem;
  -webkit-overflow-scrolling: touch;
}
.bs__footer {
  padding: .75rem 1.25rem;
  border-top: 1px solid var(--border);
  flex-shrink: 0;
  display: flex; flex-direction: column; gap: .5rem;
}

/* Transition */
.bs-enter-active, .bs-leave-active { transition: opacity .22s; }
.bs-enter-active .bs__sheet, .bs-leave-active .bs__sheet { transition: transform .22s cubic-bezier(.32,1,.42,1); }
.bs-enter-from, .bs-leave-to { opacity: 0; }
.bs-enter-from .bs__sheet, .bs-leave-to .bs__sheet { transform: translateY(100%); }
</style>
