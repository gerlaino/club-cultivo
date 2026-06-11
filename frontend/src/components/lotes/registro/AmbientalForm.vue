<template>
  <div class="af__wrap">
    <div class="af__grid">
      <div class="af__field">
        <label class="af__label">Temp. aire <span class="af__unit">°C</span></label>
        <input type="number" step="0.1" class="af__input" v-model.number="f.temperatura" placeholder="24.5" />
      </div>
      <div class="af__field">
        <label class="af__label">Temp. sustrato <span class="af__unit">°C</span></label>
        <input type="number" step="0.1" class="af__input" v-model.number="f.temperatura_sustrato" placeholder="22.0" />
      </div>
      <div class="af__field">
        <label class="af__label">Humedad <span class="af__unit">%</span></label>
        <input type="number" step="0.1" min="0" max="100" class="af__input" v-model.number="f.humedad" placeholder="60" />
      </div>
      <div class="af__field">
        <label class="af__label">CO₂ <span class="af__unit">ppm</span></label>
        <input type="number" step="1" class="af__input" v-model.number="f.co2" placeholder="1200" />
      </div>
    </div>

    <div v-if="vpd" class="af__vpd-badge">
      💧 VPD estimado: <strong>{{ vpd }} kPa</strong>
      <span class="af__vpd-hint">{{ vpdStatus }}</span>
    </div>

    <div class="af__field">
      <label class="af__label">Subir CSV sensor <span class="af__optional">opcional (Bluelab, Apogee…)</span></label>
      <div class="af__csv-drop" @click="csvRef?.click()">
        <i class="bi bi-file-earmark-spreadsheet"></i>
        <span v-if="f.csvFile">{{ f.csvFile.name }}</span>
        <span v-else>Seleccionar archivo CSV</span>
      </div>
      <input ref="csvRef" type="file" accept=".csv,.txt" style="display:none" @change="handleCsv" />
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  modelValue:  { type: Object, default: () => ({}) },
  estadoLote:  { type: String, default: null },
})
const emit  = defineEmits(['update:modelValue'])
const f = computed({
  get: () => props.modelValue,
  set: v => emit('update:modelValue', v),
})

const csvRef = ref(null)

function handleCsv(e) {
  const file = e.target.files?.[0] || null
  emit('update:modelValue', { ...f.value, csvFile: file })
}

const vpd = computed(() => {
  const t = f.value.temperatura
  const h = f.value.humedad
  if (!t || !h) return null
  const svp = 0.6108 * Math.exp((17.27 * t) / (t + 237.3))
  const avp = svp * (h / 100)
  return (svp - avp).toFixed(2)
})

const vpdStatus = computed(() => {
  const v = parseFloat(vpd.value)
  if (!v) return ''
  if (v < 0.4) return '⚠️ Muy bajo'

  const estado = props.estadoLote
  // Rango óptimo según estadío
  if (['semilla', 'esqueje', 'germinacion'].includes(estado)) {
    if (v < 0.8) return '✅ Ideal para clones/semillas'
    if (v < 1.2) return '⚠️ Algo alto para esta etapa'
    return '🚨 Muy alto para esta etapa'
  }
  if (estado === 'vegetativo') {
    if (v < 0.8) return '⚠️ Bajo para vegetativo'
    if (v < 1.2) return '✅ Ideal para vegetativo'
    if (v < 1.6) return '⚠️ Estrés leve'
    return '🚨 Muy alto'
  }
  if (['floracion', 'cosecha'].includes(estado)) {
    if (v < 0.8) return '⚠️ Bajo para floración'
    if (v < 1.0) return '⚠️ Ideal vegetativo, algo bajo para floración'
    if (v < 1.6) return '✅ Ideal para floración'
    if (v < 2.0) return '⚠️ Estrés leve'
    return '🚨 Muy alto'
  }
  // Fallback sin estadío
  if (v < 0.8) return '✅ Rango clones/vege temprano'
  if (v < 1.2) return '✅ Rango vegetativo'
  if (v < 1.6) return '✅ Rango floración'
  if (v < 2.0) return '⚠️ Estrés leve'
  return '🚨 Muy alto'
})
</script>

<style scoped>
.af__wrap { display: flex; flex-direction: column; gap: var(--sp-3); }
.af__grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.af__field { display: flex; flex-direction: column; gap: .3rem; }
.af__label { font-size: .72rem; font-weight: 700; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 4px; }
.af__unit { font-size: .65rem; color: var(--c-ink-500); font-weight: 400; text-transform: none; letter-spacing: 0; }
.af__optional { font-size: .65rem; font-weight: 500; color: var(--c-ink-500); text-transform: none; letter-spacing: 0; }
.af__input { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: .5rem .75rem; font-size: var(--fs-14); color: var(--c-ink-900); width: 100%; box-sizing: border-box; }
.af__input:focus { outline: none; border-color: var(--brand-primary); background: #fff; }
.af__vpd-badge { display: inline-flex; align-items: center; gap: var(--sp-2); background: var(--c-sky-100, #E0F2FE); border: 1px solid #bae6fd; border-radius: var(--r-lg); padding: .5rem .85rem; font-size: var(--fs-13); color: #0369a1; flex-wrap: wrap; }
.af__vpd-hint { font-size: .72rem; color: var(--c-ink-500); margin-left: var(--sp-1); }
.af__csv-drop { display: flex; align-items: center; gap: var(--sp-2); background: var(--c-ink-100); border: 1.5px dashed var(--c-ink-300); border-radius: var(--r-lg); padding: .7rem 1rem; font-size: var(--fs-13); color: var(--c-ink-500); cursor: pointer; transition: all .12s; }
.af__csv-drop:hover { border-color: var(--brand-primary); color: var(--brand-primary); background: var(--c-leaf-50); }
</style>
