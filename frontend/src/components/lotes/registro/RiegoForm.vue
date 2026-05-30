<template>
  <div class="rf__wrap">
    <div class="rf__grid">
      <div class="rf__field">
        <label class="rf__label">Volumen <span class="rf__unit">L</span></label>
        <input type="number" step="0.5" min="0" class="rf__input" v-model.number="f.volumen" placeholder="20" />
      </div>
      <div class="rf__field">
        <label class="rf__label">pH entrada</label>
        <input type="number" step="0.1" min="0" max="14" class="rf__input" v-model.number="f.ph" placeholder="6.2" />
      </div>
      <div class="rf__field">
        <label class="rf__label">pH runoff</label>
        <input type="number" step="0.1" min="0" max="14" class="rf__input" v-model.number="f.ph_runoff" placeholder="6.0" />
      </div>
      <div class="rf__field">
        <label class="rf__label">EC <span class="rf__unit">mS/cm</span></label>
        <input type="number" step="0.1" min="0" class="rf__input" v-model.number="f.ec" placeholder="1.8" />
      </div>
    </div>

    <label class="rf__toggle-row">
      <div class="rf__toggle-track" :class="{ 'rf__toggle-track--on': f.fertilizo }">
        <input type="checkbox" v-model="f.fertilizo" class="rf__toggle-input" />
        <div class="rf__toggle-thumb"></div>
      </div>
      <span class="rf__toggle-label">¿Se fertilizó?</span>
    </label>

    <div v-if="f.fertilizo" class="rf__fertilizacion">
      <div class="rf__grid">
        <div class="rf__field rf__field--full">
          <label class="rf__label">Producto</label>
          <input type="text" class="rf__input" v-model.trim="f.producto" placeholder="Ej: Base A + Base B" />
        </div>
        <div class="rf__field">
          <label class="rf__label">Dosis <span class="rf__unit">ml/L</span></label>
          <input type="number" step="0.1" min="0" class="rf__input" v-model.number="f.dosis" placeholder="10" />
        </div>
        <div class="rf__field">
          <label class="rf__label">Semana nutrición</label>
          <input type="number" step="1" min="1" class="rf__input" v-model.number="f.semana_nutricion" placeholder="3" />
        </div>
      </div>
    </div>

    <div class="rf__field rf__field--full">
      <label class="rf__label">Observaciones <span class="rf__optional">opcional</span></label>
      <textarea class="rf__textarea" rows="2" v-model.trim="f.observaciones" placeholder="Runoff con raíces, goteros limpios…"></textarea>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({ modelValue: { type: Object, default: () => ({}) } })
const emit  = defineEmits(['update:modelValue'])
const f     = computed({
  get: () => props.modelValue,
  set: v  => emit('update:modelValue', v),
})
</script>

<style scoped>
.rf__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); margin-bottom: var(--sp-3); }
.rf__field { display: flex; flex-direction: column; gap: .3rem; }
.rf__field--full { grid-column: 1 / -1; }
.rf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 4px; }
.rf__unit { font-size: .65rem; color: var(--c-ink-500); font-weight: 400; text-transform: none; letter-spacing: 0; }
.rf__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.rf__input { background: var(--c-ink-100, #F3F4F6); border: 1.5px solid var(--c-ink-300, #D1D5DB); border-radius: var(--r-md, 6px); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; transition: border .15s; }
.rf__input:focus { outline: none; border-color: var(--brand-primary, #1b5e20); background: #fff; }
.rf__textarea { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; resize: vertical; transition: border .15s; }
.rf__textarea:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.rf__toggle-row { display: flex; align-items: center; gap: var(--sp-3); cursor: pointer; margin-bottom: var(--sp-3); }
.rf__toggle-input { position: absolute; opacity: 0; width: 0; height: 0; }
.rf__toggle-track { position: relative; width: 40px; height: 22px; background: var(--c-ink-300); border-radius: 99px; transition: background .2s; flex-shrink: 0; }
.rf__toggle-track--on { background: var(--brand-primary, #1b5e20); }
.rf__toggle-thumb { position: absolute; top: 3px; left: 3px; width: 16px; height: 16px; background: #fff; border-radius: 50%; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.rf__toggle-track--on .rf__toggle-thumb { transform: translateX(18px); }
.rf__toggle-label { font-size: var(--fs-14); font-weight: 500; color: var(--c-ink-700); user-select: none; }
.rf__fertilizacion { background: var(--c-leaf-50, #F4F8F5); border: 1px solid var(--c-leaf-100, #E8F0EB); border-radius: var(--r-lg); padding: var(--sp-3); margin-bottom: var(--sp-3); }
</style>
