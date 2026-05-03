<script setup>
import { useToast } from '../../composables/useToast.js'
const { toasts, remove } = useToast()
</script>

<template>
  <Teleport to="body">
    <div class="toast-stack" aria-live="polite" aria-atomic="false">
      <TransitionGroup name="toast">
        <div
          v-for="t in toasts"
          :key="t.id"
          class="toast-item"
          :class="`toast-item--${t.type}`"
          role="alert"
          @click="remove(t.id)"
        >
          <i :class="`bi ${t.icon}`"></i>
          <span>{{ t.msg }}</span>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
.toast-stack {
  position: fixed;
  bottom: 5.5rem;
  left: 50%;
  transform: translateX(-50%);
  z-index: 10000;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: .5rem;
  pointer-events: none;
}
@media (min-width: 768px) {
  .toast-stack { bottom: 1.5rem; }
}

.toast-item {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .5rem 1.1rem;
  border-radius: 999px;
  font-size: .85rem;
  font-weight: 500;
  white-space: nowrap;
  max-width: 90vw;
  pointer-events: auto;
  cursor: pointer;
  box-shadow: 0 4px 16px rgba(0,0,0,.15);
}
.toast-item--success { background: #1a2e1a; color: #fff; }
.toast-item--error   { background: #7f1d1d; color: #fff; }
.toast-item--warning { background: #78350f; color: #fff; }
.toast-item--info    { background: #1e3a5f; color: #fff; }

/* Transition */
.toast-enter-active { transition: all .2s ease; }
.toast-leave-active { transition: all .2s ease; }
.toast-enter-from   { opacity: 0; transform: translateY(10px); }
.toast-leave-to     { opacity: 0; transform: translateY(-6px); }
</style>
