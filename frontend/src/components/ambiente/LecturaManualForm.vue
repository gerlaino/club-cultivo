<script setup>
import { ref, computed } from 'vue'
import { registrarLecturaOffline } from '../../lib/offlineApi.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  loteId: { type: Number, required: true },
})

const emit = defineEmits(['guardado'])
const toast = useToast()

const form = ref({
  temperatura:          '',
  humedad:              '',
  co2:                  '',
  ppfd:                 '',
  ph:                   '',
  ec:                   '',
  ph_runoff:            '',
  ec_runoff:            '',
  temperatura_sustrato: '',
  notas:                '',
})

const guardando = ref(false)
const expanded  = ref(false)

const camposBase = [
  { key: 'temperatura',  label: 'Temperatura (°C)',  type: 'number', step: '0.1' },
  { key: 'humedad',      label: 'Humedad (%)',        type: 'number', step: '0.1' },
  { key: 'co2',          label: 'CO₂ (ppm)',          type: 'number', step: '1' },
  { key: 'ppfd',         label: 'PPFD (μmol)',        type: 'number', step: '1' },
]

const camposExtra = [
  { key: 'ph',                  label: 'pH solución',        type: 'number', step: '0.01' },
  { key: 'ec',                  label: 'EC (mS/cm)',         type: 'number', step: '0.01' },
  { key: 'ph_runoff',           label: 'pH runoff',          type: 'number', step: '0.01' },
  { key: 'ec_runoff',           label: 'EC runoff (mS/cm)',  type: 'number', step: '0.01' },
  { key: 'temperatura_sustrato',label: 'Temp. sustrato (°C)',type: 'number', step: '0.1' },
]

function toPayload() {
  const p = {}
  const allCampos = [...camposBase, ...camposExtra]
  for (const c of allCampos) {
    const v = form.value[c.key]
    if (v !== '' && v !== null) p[c.key] = parseFloat(v)
  }
  if (form.value.notas) p.notas = form.value.notas
  return p
}

async function guardar() {
  const payload = toPayload()
  if (!Object.keys(payload).filter(k => k !== 'notas').length) {
    toast.error('Ingresá al menos un valor')
    return
  }
  guardando.value = true
  try {
    const res = await registrarLecturaOffline({ loteId: props.loteId, payload })
    if (res?.queued) {
      toast.warning('Sin conexión — registro guardado localmente')
    } else {
      toast.success('Registro guardado')
    }
    resetForm()
    emit('guardado')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.[0] || 'Error al guardar')
  } finally {
    guardando.value = false
  }
}

function resetForm() {
  for (const k of Object.keys(form.value)) form.value[k] = ''
  expanded.value = false
}
</script>

<template>
  <div class="lmf">
    <div class="lmf__grid">
      <div v-for="campo in camposBase" :key="campo.key" class="lmf__field">
        <label class="lmf__label">{{ campo.label }}</label>
        <input
          :type="campo.type"
          :step="campo.step"
          class="lmf__input"
          v-model="form[campo.key]"
          placeholder="—"
        />
      </div>
    </div>

    <button class="lmf__toggle" @click="expanded = !expanded">
      <i :class="expanded ? 'bi bi-chevron-up' : 'bi bi-chevron-down'"></i>
      {{ expanded ? 'Menos campos' : 'Más campos (EC, pH, runoff…)' }}
    </button>

    <div v-show="expanded" class="lmf__grid lmf__grid--mt">
      <div v-for="campo in camposExtra" :key="campo.key" class="lmf__field">
        <label class="lmf__label">{{ campo.label }}</label>
        <input
          :type="campo.type"
          :step="campo.step"
          class="lmf__input"
          v-model="form[campo.key]"
          placeholder="—"
        />
      </div>
      <div class="lmf__field lmf__field--full">
        <label class="lmf__label">Notas</label>
        <input type="text" class="lmf__input" v-model="form.notas" placeholder="Observaciones…" />
      </div>
    </div>

    <div class="lmf__footer">
      <button class="lmf__btn" :disabled="guardando" @click="guardar">
        <i v-if="!guardando" class="bi bi-plus-lg"></i>
        <span v-if="guardando">Guardando…</span>
        <span v-else>Guardar registro</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.lmf {}
.lmf__grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: .75rem;
}
@media (max-width: 640px) { .lmf__grid { grid-template-columns: repeat(2, 1fr); } }
.lmf__grid--mt { margin-top: .75rem; }
.lmf__field { display: flex; flex-direction: column; gap: .3rem; }
.lmf__field--full { grid-column: 1 / -1; }
.lmf__label { font-size: .72rem; font-weight: 600; color: #374151; }
.lmf__input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 7px;
  padding: .5rem .7rem; font-size: .85rem; color: #1a1a1a;
  width: 100%; box-sizing: border-box;
}
.lmf__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.lmf__toggle {
  display: inline-flex; align-items: center; gap: .3rem;
  background: none; border: none; color: #60725d;
  font-size: .78rem; font-weight: 600; cursor: pointer;
  margin-top: .6rem; padding: 0;
}
.lmf__footer { margin-top: .9rem; display: flex; justify-content: flex-end; }
.lmf__btn {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .55rem 1.25rem; border-radius: 8px;
  font-size: .875rem; font-weight: 600; cursor: pointer;
}
.lmf__btn:hover:not(:disabled) { background: #104417; }
.lmf__btn:disabled { opacity: .5; cursor: not-allowed; }
</style>
