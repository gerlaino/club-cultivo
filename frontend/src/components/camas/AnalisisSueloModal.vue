<template>
  <CamaModalBase :titulo="`Análisis de suelo · ${cama.nombre}`" sub="Cargá lo que dice el informe del laboratorio (o sólo el PDF)."
                 icono="bi-clipboard2-pulse" :error="error" :guardando="guardando" :deshabilitado="!valido"
                 texto-guardar="Guardar análisis" @close="$emit('close')" @guardar="guardar">
    <div class="cm-grid">
      <label class="cm-field">
        <span class="cm-label">Fecha</span>
        <input v-model="form.fecha" type="date" :max="hoy" class="cm-input" />
      </label>
      <label class="cm-field">
        <span class="cm-label">Laboratorio <span class="cm-opt">opcional</span></span>
        <input v-model="form.laboratorio" class="cm-input" placeholder="INTA, laboratorio privado…" />
      </label>
    </div>
    <p class="cm-seccion">Valores <span class="cm-opt">(los que tenga el informe)</span></p>
    <div class="cm-grid cm-grid--3">
      <label v-for="v in VALORES" :key="v.clave" class="cm-field">
        <span class="cm-label">{{ v.label }} <span class="cm-opt">{{ v.unidad }}</span></span>
        <input v-model.number="form[v.clave]" type="number" step="any" min="0" inputmode="decimal" class="cm-input" />
      </label>
    </div>
    <p class="cm-seccion">Metales pesados <span class="cm-opt">(ppm; el cannabis los acumula)</span></p>
    <div class="cm-grid">
      <label v-for="v in METALES" :key="v.clave" class="cm-field">
        <span class="cm-label">{{ v.label }}</span>
        <input v-model.number="form[v.clave]" type="number" step="any" min="0" inputmode="decimal" class="cm-input" />
      </label>
    </div>
    <label class="cm-field">
      <span class="cm-label">Informe en PDF o foto <span class="cm-opt">opcional</span></span>
      <input type="file" accept="application/pdf,image/*" class="cm-input" @change="archivo = $event.target.files?.[0] || null" />
    </label>
    <label class="cm-field">
      <span class="cm-label">Notas <span class="cm-opt">opcional</span></span>
      <textarea v-model="form.notas" class="cm-input" rows="2"></textarea>
    </label>
  </CamaModalBase>
</template>

<script setup>
// El análisis de laboratorio del suelo de una cama: para ver cómo evoluciona ciclo a ciclo. Al
// menos un valor o el PDF (lo valida el backend también).
import { ref, computed } from 'vue'
import CamaModalBase from './CamaModalBase.vue'
import { createAnalisisSuelo } from '../../lib/api.js'
import { hoyISO } from '../../utils/dates.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({ cama: { type: Object, required: true } })
const emit = defineEmits(['close', 'guardado'])
const toast = useToast()
const hoy = hoyISO()

const VALORES = [
  { clave: 'ph', label: 'pH', unidad: '' }, { clave: 'ce', label: 'CE', unidad: 'dS/m' },
  { clave: 'materia_organica_pct', label: 'Materia orgánica', unidad: '%' }, { clave: 'nitrogeno_pct', label: 'Nitrógeno', unidad: '%' },
  { clave: 'fosforo_ppm', label: 'Fósforo', unidad: 'ppm' }, { clave: 'potasio_ppm', label: 'Potasio', unidad: 'ppm' },
  { clave: 'calcio_ppm', label: 'Calcio', unidad: 'ppm' }, { clave: 'magnesio_ppm', label: 'Magnesio', unidad: 'ppm' },
  { clave: 'cic', label: 'CIC', unidad: 'cmol/kg' }, { clave: 'relacion_cn', label: 'Relación C/N', unidad: '' },
]
const METALES = [
  { clave: 'plomo_ppm', label: 'Plomo' }, { clave: 'cadmio_ppm', label: 'Cadmio' },
  { clave: 'arsenico_ppm', label: 'Arsénico' }, { clave: 'mercurio_ppm', label: 'Mercurio' },
]
const form = ref({ fecha: hoy, laboratorio: '', notas: '' })
const archivo = ref(null)
const guardando = ref(false)
const error = ref(null)

const valido = computed(() => !!form.value.fecha && (!!archivo.value || [...VALORES, ...METALES].some(v => form.value[v.clave] !== undefined && form.value[v.clave] !== '' && form.value[v.clave] !== null)))

async function guardar() {
  error.value = null
  guardando.value = true
  const fd = new FormData()
  Object.entries(form.value).forEach(([k, v]) => { if (v !== '' && v != null) fd.append(`analisis[${k}]`, v) })
  if (archivo.value) fd.append('archivo', archivo.value)
  try {
    const { data } = await createAnalisisSuelo(props.cama.id, fd)
    toast.success('Análisis guardado')
    emit('guardado', data)
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo guardar el análisis'
  } finally {
    guardando.value = false
  }
}
</script>
