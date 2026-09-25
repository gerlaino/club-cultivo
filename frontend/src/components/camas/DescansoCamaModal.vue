<template>
  <CamaModalBase :titulo="cama.estado === 'descansando' ? `Descanso de la ${cama.nombre}` : `Poner a descansar la ${cama.nombre}`"
                 sub="Los días los decidís vos: lo que dice la teoría no es ley."
                 icono="bi-moon-stars" :error="error" :guardando="guardando" :deshabilitado="!valido"
                 texto-guardar="Guardar" @close="$emit('close')" @guardar="guardar">
    <div class="cm-chips">
      <button type="button" class="cm-chip" :class="{ 'cm-chip--on': modo === 'dias' }" @click="modo = 'dias'">Cantidad de días</button>
      <button type="button" class="cm-chip" :class="{ 'cm-chip--on': modo === 'hasta' }" @click="modo = 'hasta'">Hasta una fecha</button>
      <button type="button" class="cm-chip" :class="{ 'cm-chip--on': modo === 'sin' }" @click="modo = 'sin'">Sin fecha</button>
    </div>
    <label v-if="modo === 'dias'" class="cm-field">
      <span class="cm-label">Días de descanso <span class="cm-opt">desde {{ desdeTxt }}</span></span>
      <input v-model.number="dias" type="number" min="1" step="1" inputmode="numeric" class="cm-input" placeholder="—" />
      <span v-if="finPorDias" class="cm-hint">Termina el {{ finPorDias }}.</span>
    </label>
    <label v-else-if="modo === 'hasta'" class="cm-field">
      <span class="cm-label">Descansa hasta</span>
      <input v-model="hasta" type="date" :min="manana" class="cm-input" />
    </label>
    <p v-else class="cm-hint">Descansa hasta que toques «Terminar descanso» (o plantes: plantar corta el descanso).</p>
    <label v-if="modo === 'dias'" class="cm-check">
      <input v-model="recordar" type="checkbox" /> Usar estos días para los próximos descansos de esta cama
    </label>
  </CamaModalBase>
</template>

<script setup>
// Empezar o reprogramar el descanso de una cama. Los días los pone el cultivador cada vez
// (Germán, 25-sep): viene precargado con los que le puso a ESTA cama, y ningún número de fábrica.
import { ref, computed } from 'vue'
import CamaModalBase from './CamaModalBase.vue'
import { descansarCama, updateCama } from '../../lib/api.js'
import { fechaCorta } from '../../lib/camas.js'
import { hoyISO, toISO } from '../../utils/dates.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({ cama: { type: Object, required: true } })
const emit = defineEmits(['close', 'guardado'])
const toast = useToast()

const hoy = hoyISO()
const manana = toISO(new Date(Date.now() + 86400000))
const desde = props.cama.estado === 'descansando' && props.cama.descansa_desde ? props.cama.descansa_desde : hoy
const desdeTxt = desde === hoy ? 'hoy' : `el ${fechaCorta(desde)}`
const modo = ref(props.cama.estado === 'descansando' && props.cama.descansa_hasta ? 'hasta' : 'dias')
const dias = ref(props.cama.dias_descanso || null)
const hasta = ref(props.cama.descansa_hasta || '')
const recordar = ref(!props.cama.dias_descanso)
const guardando = ref(false)
const error = ref(null)

const finPorDias = computed(() => {
  if (!(dias.value > 0)) return null
  const [y, m, d] = desde.split('-').map(Number)
  return fechaCorta(toISO(new Date(y, m - 1, d + Number(dias.value))))
})
const valido = computed(() => modo.value === 'sin' || (modo.value === 'dias' && dias.value > 0) || (modo.value === 'hasta' && hasta.value > hoy))

async function guardar() {
  error.value = null
  guardando.value = true
  try {
    const payload = modo.value === 'sin' ? { sin_fecha: true } : modo.value === 'hasta' ? { hasta: hasta.value } : { dias: dias.value }
    if (modo.value === 'dias' && recordar.value && dias.value !== props.cama.dias_descanso) {
      await updateCama(props.cama.id, { dias_descanso: dias.value })
    }
    const { data } = await descansarCama(props.cama.id, payload)
    toast.success(`La ${props.cama.nombre} está descansando`)
    emit('guardado', data)
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo guardar el descanso'
  } finally {
    guardando.value = false
  }
}
</script>
