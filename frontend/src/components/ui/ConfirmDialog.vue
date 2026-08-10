<script setup>
import { onMounted, onUnmounted } from 'vue'
import { useConfirm } from '../../composables/useConfirm.js'

const { state, accept, cancel, neutral } = useConfirm()

const VARIANT_BTN = {
  danger:  'btn-danger',
  warning: 'btn-warning',
  success: 'btn-success',
  default: 'btn-primary',
}

function onKeydown(e) {
  if (!state.open) return
  if (e.key === 'Escape') cancel()
  if (e.key === 'Enter')  accept()
}

onMounted(()  => document.addEventListener('keydown', onKeydown))
onUnmounted(() => document.removeEventListener('keydown', onKeydown))
</script>

<template>
  <Teleport to="body">
    <Transition name="cd">
      <div v-if="state.open" class="cd-overlay" @click.self="cancel" role="dialog" aria-modal="true" :aria-labelledby="state.title ? 'cd-title' : undefined">
        <div class="cd-box" @keydown.esc="cancel">
          <div v-if="state.title" id="cd-title" class="cd-title">{{ state.title }}</div>
          <p v-if="state.message" class="cd-msg">{{ state.message }}</p>
          <div class="cd-actions">
            <button class="btn btn-sm" :class="state.neutralText ? 'cd-cancel-ghost' : 'btn-outline-secondary'" @click="cancel">{{ state.cancelText }}</button>
            <button v-if="state.neutralText" class="btn btn-sm btn-outline-secondary" @click="neutral">{{ state.neutralText }}</button>
            <button class="btn btn-sm" :class="VARIANT_BTN[state.variant] || 'btn-danger'" @click="accept" autofocus>
              {{ state.confirmText }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.cd-overlay {
  position: fixed; inset: 0; z-index: 9998;
  background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  padding: 1rem;
}
.cd-box {
  background: #fff;
  border-radius: 12px;
  padding: 1.5rem;
  min-width: 280px;
  max-width: 420px;
  width: 100%;
  box-shadow: 0 20px 60px rgba(0,0,0,.2);
}
.cd-title {
  font-size: 1rem;
  font-weight: 700;
  color: #1a2e1a;
  margin-bottom: .5rem;
}
.cd-msg {
  /* pre-line: los mensajes que enumeran consecuencias (ej. mover lotes, que lista lote por lote
     qué va a cambiar) traen saltos de línea y sin esto se leían como un párrafo apelmazado. */
  white-space: pre-line;
  font-size: .875rem;
  color: var(--c-slate-500);
  margin: 0 0 1.25rem;
  line-height: 1.5;
}
.cd-actions {
  display: flex;
  justify-content: flex-end;
  gap: .5rem;
  flex-wrap: wrap;
}
/* Con 3 opciones, "Cancelar" (volver) se separa a la izquierda y va como link tenue para no
   competir con las dos elecciones reales (Empezar una nueva / Seguir la anterior). */
.cd-cancel-ghost {
  margin-right: auto;
  border: none; background: none; box-shadow: none;
  color: var(--c-slate-400); text-decoration: underline; padding-left: 0; padding-right: 0;
}
.cd-cancel-ghost:hover { color: var(--c-slate-500); background: none; }
.cd-enter-active, .cd-leave-active { transition: opacity .15s ease, transform .15s ease; }
.cd-enter-from, .cd-leave-to { opacity: 0; pointer-events: none; }
.cd-enter-from .cd-box { transform: scale(.96); }
</style>
