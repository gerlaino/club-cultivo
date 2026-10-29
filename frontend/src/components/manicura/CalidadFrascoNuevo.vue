<template>
  <div v-if="calidades.length" class="cfn">
    <label class="cfn__label" :for="idSelect">
      Calidad del frasco nuevo <span v-if="obligatoria" class="cfn__req">*</span>
    </label>
    <select :id="idSelect" class="cfn__input" :value="calidad" @change="emit('update:calidad', $event.target.value)">
      <option value="">— Elegir calidad —</option>
      <option v-for="c in calidades" :key="c.value" :value="c.value">{{ c.label }}</option>
    </select>
    <input v-if="calidad === 'otro'" class="cfn__input" type="text" maxlength="60" placeholder="¿Qué es? (recortes, restos de prerolls…)"
           aria-label="Qué es" :value="descripcion" @input="emit('update:descripcion', $event.target.value)" />
  </div>
</template>

<script setup>
// La calidad del frasco NUEVO que nace al confirmar una cosecha a un solo frasco (con reparto, cada
// fila de `RepartoFrascos` lleva la suya). Opciones y obligatoriedad: `useCalidadFlor` (/me).
import { useCalidadFlor } from '../../composables/useCalidadFlor.js'

defineProps({
  calidad:     { type: String, default: '' },
  descripcion: { type: String, default: '' },
})
const emit = defineEmits(['update:calidad', 'update:descripcion'])
const { calidades, obligatoria } = useCalidadFlor()
const idSelect = `cfn-${Math.random().toString(36).slice(2, 8)}`
</script>

<style scoped>
.cfn { display: flex; flex-direction: column; gap: .35rem; margin-top: .6rem; }
.cfn__label { font-size: .8rem; font-weight: 600; color: var(--c-ink-700); }
.cfn__req { color: var(--c-rust-600); }
.cfn__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .45rem .6rem; font-size: var(--fs-14); color: var(--c-ink-900); box-sizing: border-box; width: 100%; }
</style>
