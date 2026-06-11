<template>
  <div class="plf__wrap">
    <div class="plf__field">
      <label class="plf__label">Resultado</label>
      <div class="plf__radios">
        <button v-for="r in RESULTADOS" :key="r.value" type="button"
                class="plf__radio-btn" :class="{ 'plf__radio-btn--sel': f.resultado === r.value }"
                :style="f.resultado === r.value ? { borderColor: r.color, background: r.color + '18', color: r.color } : {}"
                @click="f.resultado = r.value">
          {{ r.emoji }} {{ r.label }}
        </button>
      </div>
    </div>

    <div v-if="f.resultado && f.resultado !== 'ninguna'" class="plf__field">
      <label class="plf__label">Tipo detectado</label>
      <div class="plf__chips">
        <button v-for="t in TIPOS_PLAGA" :key="t" type="button"
                class="plf__chip" :class="{ 'plf__chip--sel': f.tipos_detectados?.includes(t) }"
                @click="toggleTipo(t)">{{ t }}</button>
      </div>
    </div>

    <div class="plf__grid">
      <div class="plf__field">
        <label class="plf__label">Acción tomada</label>
        <select class="plf__select" v-model="f.accion_tomada">
          <option value="">Solo revisión</option>
          <option value="preventivo">Preventivo</option>
          <option value="tratamiento">Tratamiento activo</option>
        </select>
      </div>
      <div class="plf__field">
        <label class="plf__label">Plantas afectadas <span class="plf__optional">opc.</span></label>
        <input type="number" step="1" min="0" class="plf__input" v-model.number="f.plantas_afectadas" />
      </div>
    </div>

    <div v-if="f.accion_tomada && f.accion_tomada !== ''" class="plf__field">
      <label class="plf__label">Producto usado <span class="plf__optional">opcional</span></label>
      <input type="text" class="plf__input" v-model.trim="f.producto_usado" placeholder="Ej: Neem oil 2ml/L" />
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

const RESULTADOS = [
  { value: 'ninguna', label: 'Sin plagas', emoji: '✅', color: '#15803d' },
  { value: 'leve',    label: 'Leve',       emoji: '⚠️', color: '#d97706' },
  { value: 'moderada',label: 'Moderada',   emoji: '🐛', color: '#ea580c' },
  { value: 'severa',  label: 'Severa',     emoji: '🚨', color: '#dc2626' },
]
const TIPOS_PLAGA = ['Araña roja', 'Trips', 'Pulgón', 'Mosca blanca', 'Botrytis', 'Oídio', 'Fusarium', 'Otra']

function toggleTipo(t) {
  const cur = f.value.tipos_detectados || []
  const idx = cur.indexOf(t)
  emit('update:modelValue', { ...f.value, tipos_detectados: idx === -1 ? [...cur, t] : cur.filter(x => x !== t) })
}
</script>

<style scoped>
.plf__wrap { display: flex; flex-direction: column; gap: var(--sp-3); }
.plf__field { display: flex; flex-direction: column; gap: .3rem; }
.plf__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.plf__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; }
.plf__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.plf__input, .plf__select { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; }
.plf__input:focus, .plf__select:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.plf__radios { display: flex; gap: var(--sp-2); flex-wrap: wrap; }
.plf__radio-btn { display: inline-flex; align-items: center; gap: var(--sp-2); padding: .4rem .85rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-lg); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.plf__radio-btn--sel { font-weight: 700; }
.plf__chips { display: flex; flex-wrap: wrap; gap: var(--sp-2); }
.plf__chip { padding: .3rem .7rem; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-pill); font-size: var(--fs-13); color: var(--c-ink-700); background: #fff; cursor: pointer; transition: all .12s; font-weight: 500; }
.plf__chip:hover { border-color: var(--brand-primary); }
.plf__chip--sel { background: var(--c-leaf-50); border-color: var(--brand-primary); color: var(--brand-primary); font-weight: 700; }
</style>
