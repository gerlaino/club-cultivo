<template>
  <div class="lf__wrap">
    <div class="lf__grid">
      <div class="lf__field">
        <label class="lf__label">Horas de luz</label>
        <input type="number" step="0.5" min="0" max="24" class="lf__input" v-model.number="f.horas_luz" placeholder="18" />
      </div>
      <div class="lf__field">
        <label class="lf__label">Intensidad <span class="lf__unit">% o PPFD</span></label>
        <input type="number" step="1" min="0" class="lf__input" v-model.number="f.intensidad" placeholder="75" />
      </div>
    </div>

    <div class="lf__field">
      <label class="lf__label">Espectro</label>
      <div class="lf__radios">
        <button v-for="e in ESPECTROS" :key="e.value" type="button"
                class="lf__radio-btn" :class="{ 'lf__radio-btn--sel': f.espectro === e.value }"
                @click="f.espectro = e.value">
          {{ e.emoji }} {{ e.label }}
        </button>
      </div>
    </div>

    <label class="lf__toggle-row">
      <div class="lf__toggle-track" :class="{ 'lf__toggle-track--on': f.cambio_altura }">
        <input type="checkbox" v-model="f.cambio_altura" class="lf__toggle-input" />
        <div class="lf__toggle-thumb"></div>
      </div>
      <span class="lf__toggle-label">¿Cambió altura de luminaria?</span>
    </label>

    <div v-if="f.cambio_altura" class="lf__field">
      <label class="lf__label">Distancia nueva <span class="lf__unit">cm</span></label>
      <input type="number" step="1" min="0" class="lf__input" v-model.number="f.distancia" placeholder="45" />
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

const ESPECTROS = [
  { value: '',     label: 'Sin cambio',  emoji: '⚫' },
  { value: 'veg',  label: 'Vege (azul)', emoji: '🔵' },
  { value: 'bloom',label: 'Flora (rojo)',emoji: '🔴' },
  { value: 'auto', label: 'Automático',  emoji: '🌈' },
]
</script>

<style scoped>
.lf__wrap { display: flex; flex-direction: column; gap: var(--sp-3); }
.lf__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.lf__field { display: flex; flex-direction: column; gap: .3rem; }
.lf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 4px; }
.lf__unit { font-size: .65rem; color: var(--c-ink-500); font-weight: 400; text-transform: none; letter-spacing: 0; }
.lf__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; }
.lf__input:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.lf__radios { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.lf__radio-btn { display: inline-flex; align-items: center; gap: var(--sp-2); padding: .4rem .85rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.lf__radio-btn--sel { background: var(--c-leaf-50); border-color: var(--brand-primary); color: var(--brand-primary); font-weight: 700; }
.lf__toggle-row { display: flex; align-items: center; gap: var(--sp-3); cursor: pointer; }
.lf__toggle-input { position: absolute; opacity: 0; width: 0; height: 0; }
.lf__toggle-track { position: relative; width: 40px; height: 22px; background: var(--c-ink-300); border-radius: 99px; transition: background .2s; flex-shrink: 0; }
.lf__toggle-track--on { background: var(--brand-primary); }
.lf__toggle-thumb { position: absolute; top: 3px; left: 3px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; }
.lf__toggle-track--on .lf__toggle-thumb { transform: translateX(18px); }
.lf__toggle-label { font-size: var(--fs-14); font-weight: 500; color: var(--c-ink-700); user-select: none; }
</style>
