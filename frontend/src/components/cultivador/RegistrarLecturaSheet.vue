<template>
  <SheetBottom v-model="open" title="Registrar lectura ambiental">

    <!-- Sala selector -->
    <div class="rls__field">
      <label class="rls__label">Sala</label>
      <select class="rls__select" v-model="salaId" @change="onSalaChange">
        <option value="" disabled>Seleccioná una sala</option>
        <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
      </select>
    </div>

    <!-- Lote selector (solo si hay más de uno) -->
    <div v-if="lotesEnSala.length > 1" class="rls__field">
      <label class="rls__label">Lote</label>
      <select class="rls__select" v-model="loteId">
        <option value="" disabled>Seleccioná un lote</option>
        <option v-for="l in lotesEnSala" :key="l.id" :value="l.id">{{ l.codigo }}</option>
      </select>
    </div>
    <div v-else-if="salaId && lotesEnSala.length === 0" class="rls__empty">
      Esta sala no tiene lotes activos.
    </div>

    <!-- Inputs de lectura -->
    <div v-if="loteId" class="rls__grid">
      <div class="rls__field">
        <label class="rls__label">Temperatura (°C)</label>
        <input class="rls__input" type="number" step="0.1" v-model="form.temperatura" placeholder="23.5" inputmode="decimal" />
      </div>
      <div class="rls__field">
        <label class="rls__label">Humedad (%)</label>
        <input class="rls__input" type="number" step="0.1" v-model="form.humedad" placeholder="60" inputmode="decimal" />
      </div>
      <div class="rls__field">
        <label class="rls__label">CO₂ (ppm)</label>
        <input class="rls__input" type="number" step="1" v-model="form.co2" placeholder="1100" inputmode="numeric" />
      </div>
      <div class="rls__field">
        <label class="rls__label">Luz / PPFD (μmol)</label>
        <input class="rls__input" type="number" step="1" v-model="form.ppfd" placeholder="600" inputmode="numeric" />
      </div>
    </div>

    <!-- Footer -->
    <div class="rls__footer">
      <button class="rls__cancel" @click="open = false">Cancelar</button>
      <button class="rls__submit" :disabled="!canSubmit || guardando" @click="guardar">
        <DsSpinner v-if="guardando" style="width:16px;height:16px" />
        <span>{{ guardando ? 'Guardando…' : 'Guardar lectura' }}</span>
      </button>
    </div>

  </SheetBottom>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import SheetBottom from './SheetBottom.vue'
import DsSpinner   from '../../design-system/components/Spinner.vue'
import { useSalasStore } from '../../stores/salas.js'
import { useLotesStore } from '../../stores/lotes.js'
import { createRegistroAmbiental } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({ modelValue: { type: Boolean, required: true } })
const emit  = defineEmits(['update:modelValue'])

const open = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
})

const salasStore = useSalasStore()
const lotesStore = useLotesStore()
const toast      = useToast()

const salaId  = ref('')
const loteId  = ref('')
const guardando = ref(false)
const form = ref({ temperatura: '', humedad: '', co2: '', ppfd: '' })

const salas = computed(() => salasStore.items.filter(s => s.state === 'activa'))

const lotesEnSala = computed(() =>
  lotesStore.items.filter(l =>
    String(l.sala_id) === String(salaId.value) &&
    ['vegetativo', 'floracion', 'secado'].includes(l.estado)
  )
)

function onSalaChange() {
  loteId.value = ''
  // Cargar lotes si no están
  if (!lotesStore.items.length) lotesStore.fetch()
  // Auto-seleccionar el único lote si hay solo uno
  if (lotesEnSala.value.length === 1) loteId.value = lotesEnSala.value[0].id
}

watch(lotesEnSala, (lotes) => {
  if (lotes.length === 1) loteId.value = lotes[0].id
})

const canSubmit = computed(() =>
  loteId.value &&
  (form.value.temperatura || form.value.humedad || form.value.co2 || form.value.ppfd)
)

async function guardar() {
  if (!canSubmit.value) return
  guardando.value = true
  try {
    const payload = {}
    if (form.value.temperatura) payload.temperatura = parseFloat(form.value.temperatura)
    if (form.value.humedad)     payload.humedad     = parseFloat(form.value.humedad)
    if (form.value.co2)         payload.co2         = parseFloat(form.value.co2)
    if (form.value.ppfd)        payload.ppfd        = parseFloat(form.value.ppfd)
    await createRegistroAmbiental(loteId.value, payload)
    const salaNombre = salas.value.find(s => String(s.id) === String(salaId.value))?.nombre || 'la sala'
    toast.success(`Lectura registrada en ${salaNombre}`)
    open.value = false
    resetForm()
  } catch (e) {
    toast.error(e?.response?.data?.errors?.[0] || 'Error al guardar')
  } finally {
    guardando.value = false
  }
}

function resetForm() {
  form.value = { temperatura: '', humedad: '', co2: '', ppfd: '' }
  salaId.value = ''
  loteId.value = ''
}

// Cargar salas cuando el sheet se abre
watch(() => props.modelValue, (open) => {
  if (open && !salasStore.items.length) salasStore.fetch()
})
</script>

<style scoped>
.rls__field { margin-bottom: var(--sp-4); }
.rls__label {
  display: block;
  font-size: var(--fs-12);
  font-weight: 600;
  color: var(--c-ink-700);
  margin-bottom: var(--sp-2);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
.rls__select,
.rls__input {
  width: 100%;
  height: 56px;
  padding: 0 var(--sp-4);
  background: var(--c-leaf-50);
  border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  font-family: var(--font-mono);
  font-size: var(--fs-16);
  color: var(--c-ink-900);
  box-sizing: border-box;
  transition: border-color var(--t-fast);
  -webkit-appearance: none;
  appearance: none;
}
.rls__select:focus,
.rls__input:focus { outline: none; border-color: var(--c-role-cultivador); background: #fff; }

.rls__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sp-3);
}

.rls__empty {
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  padding: var(--sp-3);
  background: var(--c-ink-100);
  border-radius: var(--r-md);
  margin-bottom: var(--sp-4);
}

.rls__footer {
  display: flex;
  gap: var(--sp-3);
  margin-top: var(--sp-2);
  padding-bottom: env(safe-area-inset-bottom, 0px);
}
.rls__cancel {
  flex: 1;
  height: 52px;
  border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  background: transparent;
  font-size: var(--fs-14);
  font-weight: 500;
  color: var(--c-ink-700);
  cursor: pointer;
  transition: background var(--t-fast);
}
.rls__cancel:hover { background: var(--c-ink-100); }
.rls__submit {
  flex: 2;
  height: 52px;
  border: none;
  border-radius: var(--r-lg);
  background: var(--c-role-cultivador);
  color: #fff;
  font-size: var(--fs-14);
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--sp-2);
  transition: opacity var(--t-fast);
}
.rls__submit:disabled { opacity: 0.55; cursor: not-allowed; }
.rls__submit:not(:disabled):hover { opacity: 0.9; }
</style>
