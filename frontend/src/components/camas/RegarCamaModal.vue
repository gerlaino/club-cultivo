<template>
  <CamaModalBase :titulo="`Regar la ${cama?.nombre || 'cama'}`" :sub="sub" icono="bi-droplet"
                 :error="error" :guardando="guardando" :deshabilitado="!(litros > 0) || !camaId"
                 texto-guardar="Registrar riego" @close="$emit('close')" @guardar="guardar">
    <div v-if="camas.length > 1 && !camaFija" class="cm-field">
      <span class="cm-label">Cama</span>
      <select v-model.number="camaId" class="cm-input">
        <option v-for="c in camas" :key="c.id" :value="c.id">{{ c.nombre }}{{ c.sala_nombre ? ` · ${c.sala_nombre}` : '' }}</option>
      </select>
    </div>
    <div class="cm-grid">
      <label class="cm-field">
        <span class="cm-label">Litros <span class="cm-opt">en toda la cama</span></span>
        <input v-model.number="litros" type="number" min="0" step="0.5" inputmode="decimal" class="cm-input" placeholder="20" />
      </label>
      <label class="cm-field">
        <span class="cm-label">Fecha</span>
        <input v-model="fecha" type="date" :max="hoy" class="cm-input" />
      </label>
      <div class="cm-field cm-field--full">
        <span class="cm-label">Agua <span class="cm-opt">opcional</span></span>
        <div class="cm-chips">
          <button v-for="a in reglas.aguas" :key="a" type="button" class="cm-chip" :class="{ 'cm-chip--on': agua === a }" @click="agua = agua === a ? '' : a">{{ aguaLabel(a) }}</button>
        </div>
        <span v-if="agua === 'red'" class="cm-hint">El cloro de la red castiga la vida del suelo: dejarla reposar 24 h o filtrarla ayuda.</span>
      </div>
    </div>

    <label class="cm-check"><input v-model="conTe" type="checkbox" /> Le di té con el riego</label>
    <InsumosAplicados v-if="conTe" v-model="insumos" uso="riego" :base-default="litros || null"
                      base-ayuda="Litros de té preparados (si fue todo el riego, los mismos)." @nutricion="n => (nutricion = n)" />

    <p class="cm-hint">
      <template v-if="cama?.lotes?.length">El riego queda en la historia de {{ cama.lotes.length === 1 ? 'su lote' : `sus ${cama.lotes.length} lotes` }}. En suelo vivo no se corrige el pH ni la EC del agua.</template>
      <template v-else>La cama no tiene plantas: el riego queda en la cama (la cobertura también toma agua).</template>
    </p>

    <label class="cm-field">
      <span class="cm-label">Observaciones <span class="cm-opt">opcional</span></span>
      <textarea v-model="observaciones" class="cm-input" rows="2" placeholder="Drenó bien, la cobertura está verde…"></textarea>
    </label>
  </CamaModalBase>
</template>

<script setup>
// «Regar la cama A» (decisión D6: el riego es por cama, que es el gesto real). Con plantas, el
// backend deja un registro en cada lote de la cama —así cada lote sabe cuándo lo regaron— y el té
// se descuenta una vez; sin plantas, queda en la cama. Sin pH ni EC: en suelo vivo no se corrigen.
import { ref, computed } from 'vue'
import CamaModalBase from './CamaModalBase.vue'
import InsumosAplicados from './InsumosAplicados.vue'
import { regarCama } from '../../lib/api.js'
import { reglasSueloVivo, aguaLabel, ultimaAgua, recordarAgua } from '../../lib/camas.js'
import { hoyISO } from '../../utils/dates.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  camas:    { type: Array, required: true },
  camaId:   { type: Number, default: null },
  camaFija: { type: Boolean, default: false },
})
const emit = defineEmits(['close', 'guardado'])
const toast = useToast()
const reglas = reglasSueloVivo()
const hoy = hoyISO()

const camaId = ref(props.camaId || props.camas[0]?.id || null)
const litros = ref(null)
const fecha = ref(hoy)
const agua = ref(ultimaAgua())
const conTe = ref(false)
const insumos = ref({})
const nutricion = ref(null)
const observaciones = ref('')
const guardando = ref(false)
const error = ref(null)

const cama = computed(() => props.camas.find(c => c.id === camaId.value) || null)
const sub = computed(() => cama.value?.sala_nombre || null)

async function guardar() {
  error.value = null
  guardando.value = true
  try {
    const { data } = await regarCama(camaId.value, {
      litros: litros.value, agua: agua.value || undefined, observaciones: observaciones.value || undefined,
      registrado_en: fecha.value === hoy ? undefined : `${fecha.value}T12:00:00`,
      nutricion: conTe.value ? nutricion.value : undefined,
    })
    recordarAgua(agua.value)
    const falt = data.faltantes || []
    if (falt.length) toast.warning(`Riego registrado. Faltó en el stock: ${falt.map(f => f.nombre).join(', ')}`)
    else toast.success(`Riego registrado en la ${cama.value.nombre}`)
    emit('guardado', data)
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo registrar el riego'
  } finally {
    guardando.value = false
  }
}
</script>
