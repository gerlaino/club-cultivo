<template>
  <CamaModalBase titulo="Plantar en la cama" :sub="sub" icono="bi-flower1" :error="error" :guardando="guardando"
                 :deshabilitado="!camaId || cargando" texto-guardar="Plantar" @close="$emit('close')" @guardar="guardar">
    <p v-if="cargando" class="cm-hint">Buscando camas…</p>
    <p v-else-if="!camas.length" class="cm-aviso"><i class="bi bi-info-circle"></i>
      <span>No hay camas cargadas. Creá una desde la ficha del {{ salaTxt.corta }}.</span></p>
    <template v-else>
      <div class="cm-field">
        <span class="cm-label">¿En qué cama?</span>
        <div class="pec__camas">
          <button v-for="c in camas" :key="c.id" type="button" class="pec__cama" :class="{ 'pec__cama--on': camaId === c.id }" @click="camaId = c.id">
            <span class="pec__nombre">{{ c.nombre }}</span>
            <span class="pec__meta">{{ c.sala_nombre }} · {{ estadoCama(c.estado).label }}{{ c.m2 ? ` · ${fmtNum(c.m2)} m²` : '' }}</span>
          </button>
        </div>
      </div>
      <div v-if="aviso" class="cm-aviso"><i class="bi bi-exclamation-triangle"></i><span>{{ aviso }}</span></div>
      <label class="cm-field">
        <span class="cm-label">Fecha</span>
        <input v-model="fecha" type="date" :max="hoy" class="cm-input" />
      </label>
      <p class="cm-info"><i class="bi bi-info-circle"></i>
        <span v-if="lote.estado === 'enraizado'">Plantarlo en la cama lo prende: pasa a vegetativo ese día. Desde ahí no hay más trasplantes.</span>
        <span v-else>Es el último trasplante: desde ahí la tierra es la cama y no se trasplanta más.</span>
      </p>
    </template>
  </CamaModalBase>
</template>

<script setup>
// El último trasplante: de la bandeja o del vasito a una cama de suelo vivo. Si enraizaba, prende.
// Plantar en una cama que descansa o todavía se cocina NO se bloquea (Germán, 22-sep): se avisa.
import { ref, computed, onMounted } from 'vue'
import CamaModalBase from './CamaModalBase.vue'
import { listCamas, plantarEnCama } from '../../lib/api.js'
import { estadoCama, avisoAlPlantar, fmtNum } from '../../lib/camas.js'
import { hoyISO } from '../../utils/dates.js'
import { useToast } from '../../composables/useToast.js'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'

const props = defineProps({ lote: { type: Object, required: true } })
const emit = defineEmits(['close', 'plantado'])
const toast = useToast()
const { sala: salaTxt } = useUsoPersonal()
const hoy = hoyISO()

const camas = ref([])
const cargando = ref(true)
const camaId = ref(null)
const fecha = ref(hoy)
const guardando = ref(false)
const error = ref(null)

const cama = computed(() => camas.value.find(c => c.id === camaId.value) || null)
const aviso = computed(() => avisoAlPlantar(cama.value))
const sub = computed(() => `${props.lote.codigo}${props.lote.genetica?.nombre ? ` · ${props.lote.genetica.nombre}` : ''}`)

onMounted(async () => {
  try {
    const { data } = await listCamas()
    // Las de su espacio primero: es lo más común (la bandeja está en la misma carpa).
    const salaId = props.lote.sala_id || props.lote.sala?.id
    camas.value = (data || []).sort((a, b) => (b.sala_id === salaId) - (a.sala_id === salaId) || a.nombre.localeCompare(b.nombre))
    camaId.value = camas.value.find(c => c.sala_id === salaId && c.estado !== 'descansando' && c.estado !== 'cocinando')?.id || camas.value[0]?.id || null
  } catch { camas.value = [] } finally { cargando.value = false }
})

async function guardar() {
  error.value = null
  guardando.value = true
  try {
    const { data } = await plantarEnCama(props.lote.id, { cama_id: camaId.value, fecha: fecha.value })
    toast.success(`${props.lote.codigo} plantado en la ${cama.value.nombre}`)
    emit('plantado', data)
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo plantar'
  } finally {
    guardando.value = false
  }
}
</script>

<style scoped>
.pec__camas { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: .5rem; }
.pec__cama {
  text-align: left; border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md); background: var(--c-slate-50);
  padding: .6rem .75rem; cursor: pointer; display: flex; flex-direction: column; gap: .15rem;
}
.pec__cama--on { border-color: var(--c-leaf-700); background: var(--c-leaf-50); }
.pec__nombre { font-weight: 800; color: var(--c-slate-900); font-size: var(--fs-14); }
.pec__meta { font-size: var(--fs-12); color: var(--c-slate-500); }
</style>
