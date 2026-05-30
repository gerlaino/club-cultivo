<template>
  <div class="clf__wrap">
    <div class="clf__field">
      <label class="clf__label">Tipo de limpieza</label>
      <div class="clf__radios">
        <button v-for="t in TIPOS" :key="t.value" type="button"
                class="clf__radio-btn" :class="{ 'clf__radio-btn--sel': f.tipo === t.value }"
                @click="f.tipo = t.value">
          {{ t.emoji }} {{ t.label }}
        </button>
      </div>
    </div>
    <div class="clf__field">
      <label class="clf__label">Producto usado <span class="clf__optional">opcional</span></label>
      <input type="text" class="clf__input" v-model.trim="f.producto_usado" placeholder="Ej: H₂O₂ 3%, alcohol 70%…" />
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({ modelValue: { type: Object, default: () => ({}) } })
const emit  = defineEmits(['update:modelValue'])
const f = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v),
})

const TIPOS = [
  { value: 'rutinaria',    label: 'Rutinaria',     emoji: '🧹' },
  { value: 'desinfeccion', label: 'Desinfección',  emoji: '🧪' },
  { value: 'post_cosecha', label: 'Post-cosecha',  emoji: '✨' },
]
</script>

<style scoped>
.clf__wrap { display: flex; flex-direction: column; gap: var(--sp-3); }
.clf__field { display: flex; flex-direction: column; gap: .3rem; }
.clf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; }
.clf__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.clf__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; }
.clf__input:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.clf__radios { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.clf__radio-btn { display: inline-flex; align-items: center; gap: var(--sp-2); padding: .4rem .85rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.clf__radio-btn--sel { background: var(--c-leaf-50); border-color: var(--brand-primary); color: var(--brand-primary); font-weight: 700; }
</style>
