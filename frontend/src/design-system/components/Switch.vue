<template>
  <button type="button" role="switch" class="ds-switch" :class="{ 'ds-switch--on': modelValue }"
          :aria-checked="modelValue ? 'true' : 'false'" :disabled="disabled"
          @click="$emit('update:modelValue', !modelValue)">
    <span class="ds-switch__thumb" aria-hidden="true"></span>
  </button>
</template>

<script setup>
// Un interruptor: prendido / apagado. Emite el valor nuevo; guardarlo es de quien lo usa (y lo hace
// al tocarlo: un interruptor que espera un «Guardar» al pie parece roto — 28-oct-2026, el portal).
defineProps({
  modelValue: { type: Boolean, default: false },
  disabled:   { type: Boolean, default: false },
})
defineEmits(['update:modelValue'])
</script>

<style scoped>
.ds-switch {
  position: relative; flex: 0 0 48px; width: 48px; height: 28px; padding: 0; border: none; border-radius: 999px;
  background: var(--c-slate-300); cursor: pointer; transition: background .15s;
}
.ds-switch::before { content: ''; position: absolute; inset: -8px; } /* área de toque de 44px */
.ds-switch--on { background: var(--c-leaf-800); }
.ds-switch:disabled { opacity: .55; cursor: wait; }
.ds-switch:focus-visible { outline: 3px solid var(--c-leaf-300); outline-offset: 2px; }
.ds-switch__thumb {
  position: absolute; top: 3px; left: 3px; width: 22px; height: 22px; border-radius: 50%;
  background: #fff; box-shadow: 0 1px 2px rgb(0 0 0 / .25); transition: left .15s;
}
.ds-switch--on .ds-switch__thumb { left: 23px; }
</style>
