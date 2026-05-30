<template>
  <div class="nf__wrap">
    <div class="nf__grid">
      <div class="nf__field nf__field--full">
        <label class="nf__label">Producto</label>
        <input type="text" class="nf__input" v-model.trim="f.producto" placeholder="Ej: Canna Coco A+B, BioBizz Bloom…" />
      </div>
      <div class="nf__field">
        <label class="nf__label">Dosis <span class="nf__unit">ml/g por L</span></label>
        <input type="number" step="0.1" min="0" class="nf__input" v-model.number="f.dosis" placeholder="5" />
      </div>
      <div class="nf__field">
        <label class="nf__label">Semana de programa</label>
        <input type="number" step="1" min="1" class="nf__input" v-model.number="f.semana_programa" placeholder="4" />
      </div>
    </div>

    <div class="nf__field">
      <label class="nf__label">Método</label>
      <div class="nf__radios">
        <button v-for="m in METODOS" :key="m.value" type="button"
                class="nf__radio-btn" :class="{ 'nf__radio-btn--sel': f.metodo === m.value }"
                @click="f.metodo = m.value">
          {{ m.emoji }} {{ m.label }}
        </button>
      </div>
    </div>

    <div class="nf__field nf__field--full">
      <label class="nf__label">Observaciones <span class="nf__optional">opcional</span></label>
      <textarea class="nf__textarea" rows="2" v-model.trim="f.observaciones" placeholder="Primera aplicación de bloom, cambio de programa…"></textarea>
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

const METODOS = [
  { value: 'foliar',     label: 'Foliar',      emoji: '🌿' },
  { value: 'suelo',      label: 'Suelo',        emoji: '🪱' },
  { value: 'hidroponico',label: 'Hidropónico',  emoji: '💧' },
]
</script>

<style scoped>
.nf__wrap { display: flex; flex-direction: column; gap: var(--sp-3); }
.nf__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.nf__field { display: flex; flex-direction: column; gap: .3rem; }
.nf__field--full { grid-column: 1 / -1; }
.nf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 4px; }
.nf__unit { font-size: .65rem; color: var(--c-ink-500); font-weight: 400; text-transform: none; letter-spacing: 0; }
.nf__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.nf__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; }
.nf__input:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.nf__textarea { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; }
.nf__textarea:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.nf__radios { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.nf__radio-btn { display: inline-flex; align-items: center; gap: var(--sp-2); padding: .4rem .85rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.nf__radio-btn--sel { background: var(--c-leaf-50); border-color: var(--brand-primary); color: var(--brand-primary); font-weight: 700; }
</style>
