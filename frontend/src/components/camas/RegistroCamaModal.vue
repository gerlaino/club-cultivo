<template>
  <CamaModalBase :titulo="titulo" :sub="sub" :icono="ICONO_REGISTRO[tipo] || 'bi-basket'"
                 :error="error" :guardando="guardando" :deshabilitado="!puedeGuardar"
                 texto-guardar="Registrar" @close="$emit('close')" @guardar="guardar">
    <div v-if="camas.length > 1 && !camaFija" class="cm-field">
      <span class="cm-label">Cama</span>
      <select v-model.number="camaId" class="cm-input">
        <option v-for="c in camas" :key="c.id" :value="c.id">{{ c.nombre }}{{ c.sala_nombre ? ` · ${c.sala_nombre}` : '' }}</option>
      </select>
    </div>

    <div class="cm-field">
      <span class="cm-label">¿Qué le hiciste?</span>
      <div class="cm-chips">
        <button v-for="t in TIPOS" :key="t" type="button" class="cm-chip" :class="{ 'cm-chip--on': tipo === t }" @click="elegirTipo(t)">
          <i :class="['bi', ICONO_REGISTRO[t]]"></i> {{ etiqueta(t) }}
        </button>
      </div>
    </div>

    <div class="cm-grid">
      <label class="cm-field">
        <span class="cm-label">Fecha</span>
        <input v-model="fecha" type="date" :max="hoy" class="cm-input" />
      </label>
      <label v-if="['cobertura', 'mulch', 'inoculacion'].includes(tipo)" class="cm-field">
        <span class="cm-label">{{ tipo === 'cobertura' ? 'Qué sembraste' : tipo === 'mulch' ? 'Qué pusiste' : 'Qué inoculaste' }}</span>
        <input v-model="detalle" class="cm-input" :placeholder="PLACEHOLDER[tipo]" maxlength="120" />
      </label>
      <label v-if="tipo === 'te'" class="cm-field">
        <span class="cm-label">Litros <span class="cm-opt">de té</span></span>
        <input v-model.number="litros" type="number" min="0" step="0.5" inputmode="decimal" class="cm-input" placeholder="10" />
      </label>
    </div>

    <label v-if="tipo === 'top_dress'" class="cm-check">
      <input v-model="recarga" type="checkbox" /> Es la recarga entre cosechas
    </label>

    <div v-if="tipo === 'medicion'" class="cm-grid">
      <label class="cm-field">
        <span class="cm-label">Humedad del suelo <span class="cm-opt">%</span></span>
        <input v-model.number="humedad" type="number" min="0" max="100" step="1" inputmode="numeric" class="cm-input" />
      </label>
      <label class="cm-field">
        <span class="cm-label">Temperatura del suelo <span class="cm-opt">°C</span></span>
        <input v-model.number="temperatura" type="number" step="0.1" inputmode="decimal" class="cm-input" />
      </label>
    </div>

    <template v-if="CON_PRODUCTOS.includes(tipo)">
      <p class="cm-seccion">Productos</p>
      <InsumosAplicados :key="`${tipo}-${camaId}`" v-model="insumos" :uso="usoDeReceta"
                        :base-default="baseDefault" :base-ayuda="baseAyuda" @nutricion="n => (nutricion = n)" />
      <p v-if="tipo === 'top_dress' && !cama?.m2" class="cm-hint">Sin medidas de la cama no hay m² contra qué calcular la receta: cargá los m² alimentados o productos sueltos.</p>
    </template>

    <label class="cm-field">
      <span class="cm-label">Observaciones <span class="cm-opt">opcional</span></span>
      <textarea v-model="observaciones" class="cm-input" rows="2" :placeholder="tipo === 'nota' ? 'Lo que viste en la cama…' : 'Cómo estaba la tierra, lombrices, hongos…'"></textarea>
    </label>
  </CamaModalBase>
</template>

<script setup>
// Lo que se le hace al suelo de una cama: alimentarla (top dress), un té al suelo, sembrar
// cobertura, mulch, inocular, medirla, anotar. El riego va por «Regar la cama» (con plantas,
// queda en cada lote). Descuenta y cuesta el backend (`Camas::Registrar`).
import { ref, computed, watch } from 'vue'
import CamaModalBase from './CamaModalBase.vue'
import InsumosAplicados from './InsumosAplicados.vue'
import { createRegistroCama } from '../../lib/api.js'
import { ICONO_REGISTRO, reglasSueloVivo } from '../../lib/camas.js'
import { hoyISO } from '../../utils/dates.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  camas:       { type: Array, required: true },   // resúmenes de cama (una o varias)
  camaId:      { type: Number, default: null },   // cuál viene elegida
  camaFija:    { type: Boolean, default: false },
  tipoInicial: { type: String, default: 'top_dress' },
})
const emit = defineEmits(['close', 'guardado'])
const toast = useToast()
const reglas = reglasSueloVivo()

const TIPOS = ['top_dress', 'te', 'cobertura', 'mulch', 'inoculacion', 'medicion', 'nota']
const CON_PRODUCTOS = ['top_dress', 'te', 'cobertura', 'mulch', 'inoculacion']
const USO = { top_dress: 'top_dress', te: 'riego' }
const PLACEHOLDER = { cobertura: 'Trébol blanco, alfalfa…', mulch: 'Paja de alfalfa, hojas…', inoculacion: 'Micorrizas, lombrices, colémbolos…' }
const etiqueta = (t) => (t === 'top_dress' ? 'Alimentar (top dress)' : reglas.tipos_registro_labels[t] || t)

const hoy = hoyISO()
const camaId = ref(props.camaId || props.camas[0]?.id || null)
const tipo = ref(TIPOS.includes(props.tipoInicial) ? props.tipoInicial : 'top_dress')
const fecha = ref(hoy)
const detalle = ref('')
const litros = ref(null)
const recarga = ref(false)
const humedad = ref(null)
const temperatura = ref(null)
const observaciones = ref('')
const insumos = ref({})
const nutricion = ref(null)
const guardando = ref(false)
const error = ref(null)

const cama = computed(() => props.camas.find(c => c.id === camaId.value) || null)
// Recarga: si la cama está vacía (descansa), el top dress es la recarga entre cosechas.
watch(cama, (c) => { if (c) recarga.value = tipo.value === 'top_dress' && c.estado !== 'en_uso' }, { immediate: true })
const titulo = computed(() => (tipo.value === 'top_dress' ? 'Alimentar la cama' : etiqueta(tipo.value)))
const sub = computed(() => cama.value ? `${cama.value.nombre}${cama.value.m2 ? ` · ${String(cama.value.m2).replace('.', ',')} m²` : ''}${cama.value.lotes?.length ? ` · ${cama.value.lotes.length} ${cama.value.lotes.length === 1 ? 'lote' : 'lotes'}` : ' · sin plantas'}` : null)
const usoDeReceta = computed(() => USO[tipo.value] || null)
const baseDefault = computed(() => (tipo.value === 'top_dress' ? cama.value?.m2 ?? null : tipo.value === 'te' ? (litros.value || null) : null))
const baseAyuda = computed(() => (tipo.value === 'top_dress' ? 'Toda la cama, salvo que hayas alimentado una parte.' : null))
const puedeGuardar = computed(() => !!cama.value && !!fecha.value && (tipo.value !== 'medicion' || humedad.value != null || temperatura.value != null))

function elegirTipo(t) {
  tipo.value = t
  insumos.value = {}
  nutricion.value = null
  recarga.value = t === 'top_dress' && cama.value?.estado !== 'en_uso'
}

async function guardar() {
  error.value = null
  guardando.value = true
  const registro = {
    tipo: tipo.value,
    registrado_en: fecha.value === hoy ? undefined : `${fecha.value}T12:00:00`,
    detalle: detalle.value || undefined,
    litros: tipo.value === 'te' ? (litros.value || undefined) : undefined,
    recarga: tipo.value === 'top_dress' ? recarga.value : undefined,
    humedad_suelo: tipo.value === 'medicion' ? humedad.value : undefined,
    temperatura_suelo: tipo.value === 'medicion' ? temperatura.value : undefined,
    observaciones: observaciones.value || undefined,
  }
  try {
    const { data } = await createRegistroCama(camaId.value, registro, CON_PRODUCTOS.includes(tipo.value) ? nutricion.value : null)
    const falt = data.faltantes || []
    if (falt.length) toast.warning(`Registrado. Faltó en el stock: ${falt.map(f => f.nombre).join(', ')}`)
    else toast.success(`${etiqueta(tipo.value)} registrado en la ${cama.value.nombre}`)
    emit('guardado', data)
  } catch (e) {
    error.value = e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudo registrar'
  } finally {
    guardando.value = false
  }
}
</script>
