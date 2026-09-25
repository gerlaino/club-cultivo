<template>
  <CamaModalBase :titulo="cama ? `Editar ${cama.nombre}` : 'Nueva cama'"
                 :sub="cama ? null : `En ${salaNombre}. Las medidas dicen cuánto ocupa y cuánta tierra lleva.`"
                 icono="bi-bricks" :error="error" :guardando="guardando" :deshabilitado="!form.nombre.trim() || noEntra"
                 :texto-guardar="cama ? 'Guardar' : 'Crear cama'" @close="$emit('close')" @guardar="guardar">
    <div class="cm-grid">
      <label class="cm-field cm-field--full">
        <span class="cm-label">Nombre</span>
        <input v-model="form.nombre" class="cm-input" maxlength="60" placeholder="Cama A" />
      </label>
      <label v-if="cama && salasDestino.length > 1" class="cm-field cm-field--full">
        <span class="cm-label">{{ salaTxt.Corta }}</span>
        <select v-model.number="form.sala_id" class="cm-input" :disabled="cama.estado === 'en_uso'">
          <option v-for="s in salasDestino" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <span v-if="cama.estado === 'en_uso'" class="cm-hint">Con plantas no se muda: las raíces están en la tierra.</span>
      </label>
    </div>

    <p class="cm-seccion">Medidas</p>
    <div class="cm-grid cm-grid--3">
      <label class="cm-field">
        <span class="cm-label">Largo <span class="cm-opt">m</span></span>
        <input v-model.number="form.largo_m" type="number" step="0.01" min="0" inputmode="decimal" class="cm-input" placeholder="1,20" />
      </label>
      <label class="cm-field">
        <span class="cm-label">Ancho <span class="cm-opt">m</span></span>
        <input v-model.number="form.ancho_m" type="number" step="0.01" min="0" inputmode="decimal" class="cm-input" placeholder="0,60" />
      </label>
      <label class="cm-field">
        <span class="cm-label">Profundidad <span class="cm-opt">cm</span></span>
        <input v-model.number="form.profundidad_cm" type="number" step="1" min="0" inputmode="numeric" class="cm-input" placeholder="30" />
      </label>
    </div>
    <div v-if="m2" class="cm-info">
      <i class="bi bi-rulers"></i>
      <span>{{ fmtNum(m2) }} m²<template v-if="litros"> · {{ fmtNum(litros, 0) }} litros de tierra</template><template v-if="libres != null"> · en {{ salaNombre }} quedan {{ fmtNum(libres) }} m² libres</template></span>
    </div>
    <div v-if="noEntra" class="cm-aviso"><i class="bi bi-exclamation-triangle"></i>
      <span>No entra: {{ salaNombre }} mide {{ fmtNum(sala?.m2) }} m² y quedan {{ fmtNum(libres) }} m² libres. Corregí las medidas de la cama o las del {{ salaTxt.corta }}.</span>
    </div>
    <p v-else-if="!m2" class="cm-hint">Sin medidas la cama se crea igual, pero no vas a poder comparar el rendimiento por m² ni calcular una receta de top dress.</p>

    <p class="cm-seccion">Tus tiempos <span class="cm-opt">(los decidís vos; vacío = sin reloj)</span></p>
    <div class="cm-grid">
      <label class="cm-field">
        <span class="cm-label">Armada el</span>
        <input v-model="form.armada_el" type="date" :max="hoy" class="cm-input" />
      </label>
      <label class="cm-field">
        <span class="cm-label">Semanas de cocción</span>
        <input v-model.number="form.semanas_coccion" type="number" min="1" step="1" inputmode="numeric" class="cm-input" placeholder="—" />
      </label>
      <label class="cm-field">
        <span class="cm-label">Días de descanso</span>
        <input v-model.number="form.dias_descanso" type="number" min="1" step="1" inputmode="numeric" class="cm-input" placeholder="—" />
        <span class="cm-hint">Al cosechar lo último, la cama descansa estos días (lo podés cambiar cada vez).</span>
      </label>
      <label class="cm-field">
        <span class="cm-label">Top dress cada <span class="cm-opt">días</span></span>
        <input v-model.number="form.frecuencia_top_dress_dias" type="number" min="1" step="1" inputmode="numeric" class="cm-input" placeholder="—" />
        <span class="cm-hint">Para que te avise cuándo toca.</span>
      </label>
    </div>

    <template v-if="!cama">
      <p class="cm-seccion">Con qué la armaste</p>
      <div class="cm-chips">
        <button type="button" class="cm-chip" :class="{ 'cm-chip--on': !yaArmada }" @click="yaArmada = false">La armo ahora</button>
        <button type="button" class="cm-chip" :class="{ 'cm-chip--on': yaArmada }" @click="yaArmada = true">Ya estaba armada</button>
      </div>
      <InsumosAplicados v-if="!yaArmada" v-model="mezcla" uso="mezcla" :base-default="litros"
                        base-ayuda="Litros de tierra de la cama: salen de las medidas."
                        @nutricion="n => (nutricion = n)" />
      <p v-else class="cm-hint">No se descuenta nada del {{ esPersonal ? 'stock' : 'depósito' }}. La historia de la cama empieza hoy.</p>
    </template>

    <label class="cm-field">
      <span class="cm-label">Notas <span class="cm-opt">opcional</span></span>
      <textarea v-model="form.notas" class="cm-input" rows="2" placeholder="Mezcla 1/3, lombrices californianas…"></textarea>
    </label>
  </CamaModalBase>
</template>

<script setup>
// Alta y edición de una cama de suelo vivo. Las medidas dan los m² (para la regla «las camas
// entran en el espacio» y el g/m²) y los litros de tierra (para la receta de mezcla). Los tiempos
// (cocción, descanso, top dress) los pone el cultivador: la app no trae números de fábrica
// (Germán, 25-sep). El backend valida que la cama entre; acá se avisa antes de guardar.
import { ref, computed } from 'vue'
import CamaModalBase from './CamaModalBase.vue'
import InsumosAplicados from './InsumosAplicados.vue'
import { createCama, updateCama } from '../../lib/api.js'
import { fmtNum } from '../../lib/camas.js'
import { hoyISO } from '../../utils/dates.js'
import { useUsoPersonal } from '../../composables/useUsoPersonal.js'

const props = defineProps({
  sala:  { type: Object, required: true },   // la sala de la cama (con m2 y m2_libres del backend)
  cama:  { type: Object, default: null },    // edición
  salas: { type: Array, default: () => [] }, // a dónde se puede mudar (edición, sin plantas)
})
const emit = defineEmits(['close', 'guardada'])
const { esPersonal, sala: salaTxt } = useUsoPersonal()
const hoy = hoyISO()

const c = props.cama
const form = ref({
  nombre: c?.nombre || '', sala_id: c?.sala_id || props.sala.id,
  largo_m: c?.largo_m ?? null, ancho_m: c?.ancho_m ?? null, profundidad_cm: c?.profundidad_cm ?? null,
  armada_el: c?.armada_el || (c ? '' : hoy), semanas_coccion: c?.semanas_coccion ?? null,
  dias_descanso: c?.dias_descanso ?? null, frecuencia_top_dress_dias: c?.frecuencia_top_dress_dias ?? null,
  notas: c?.notas || '',
})
const yaArmada  = ref(false)
const mezcla    = ref({})
const nutricion = ref(null)
const guardando = ref(false)
const error     = ref(null)

const salaNombre = computed(() => props.sala?.nombre || salaTxt.value.corta)
const salasDestino = computed(() => props.salas.length ? props.salas : [props.sala])
const m2 = computed(() => (form.value.largo_m > 0 && form.value.ancho_m > 0) ? +(form.value.largo_m * form.value.ancho_m).toFixed(2) : null)
const litros = computed(() => (m2.value && form.value.profundidad_cm > 0) ? Math.round(m2.value * form.value.profundidad_cm * 10) : null)
// Lo que queda libre en el espacio sin contar esta cama (en edición, sus metros de antes se liberan).
const libres = computed(() => {
  if (props.sala?.m2 == null || props.sala?.m2_libres == null) return null
  return +(Number(props.sala.m2_libres) + Number(c?.m2 || 0)).toFixed(2)
})
const noEntra = computed(() => m2.value != null && libres.value != null && m2.value > libres.value + 0.0001)

async function guardar() {
  error.value = null
  guardando.value = true
  const payload = { ...form.value }
  for (const k of ['largo_m', 'ancho_m', 'profundidad_cm', 'semanas_coccion', 'dias_descanso', 'frecuencia_top_dress_dias']) {
    if (payload[k] === '' || payload[k] == null) payload[k] = null
  }
  if (!payload.armada_el) payload.armada_el = null
  try {
    const { data } = props.cama
      ? await updateCama(props.cama.id, payload)
      : await createCama(payload, yaArmada.value ? null : nutricion.value)
    emit('guardada', data)
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo guardar la cama'
  } finally {
    guardando.value = false
  }
}
</script>
