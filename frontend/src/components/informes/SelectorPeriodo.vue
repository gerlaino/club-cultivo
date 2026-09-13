<template>
  <div class="spe">
    <select v-model="modo" class="spe__select" @change="emitir">
      <!-- «Todo el historial» sólo donde tiene sentido: la analítica compara y necesita muchos
           lotes. En un informe de período no se ofrece. -->
      <option v-if="conTodo" value="todo">Todo el historial</option>
      <option value="mes_actual">Mes actual</option>
      <option value="mes_anterior">Mes anterior</option>
      <option value="trimestre">Trimestre</option>
      <option value="anio">Año</option>
      <option value="rango">Del… al…</option>
    </select>
    <!-- «Del 1 al 15» es lo que pide un auditor: el rango a elección vale para todos los informes
         que pasan por `periodo_rango`. Se pide recién cuando las dos fechas están. -->
    <template v-if="modo === 'rango'">
      <input v-model="desde" type="date" class="spe__fecha" :max="hasta || hoy" @change="emitir" />
      <span class="spe__al">al</span>
      <input v-model="hasta" type="date" class="spe__fecha" :min="desde" :max="hoy" @change="emitir" />
    </template>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { hoyISO } from '../../utils/dates.js'

// Un solo selector de período para todos los informes. Emite los PARÁMETROS que van a la API
// —`{ periodo }` o `{ desde, hasta }`—, que son los mismos que después lleva la descarga: la
// pantalla y el archivo tienen que pedir exactamente lo mismo, y antes el PDF bajaba siempre
// «mes actual» aunque en pantalla estuviera el trimestre.
const emit = defineEmits(['change'])
// `inicial`: con qué período arranca. Casi todos en el mes actual; el INASE en el año, porque
// nadie declara variedades por mes.
const props = defineProps({ inicial: { type: String, default: 'mes_actual' }, conTodo: { type: Boolean, default: false } })

const modo  = ref(props.inicial)
const desde = ref('')
const hasta = ref('')
const hoy   = hoyISO()

function params () {
  if (modo.value === 'rango') return desde.value && hasta.value ? { desde: desde.value, hasta: hasta.value } : null
  return { periodo: modo.value }
}

function emitir () {
  const p = params()
  if (p) emit('change', p)
}

defineExpose({ params })
</script>

<style scoped>
.spe { display: inline-flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.spe__select, .spe__fecha { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); font-family: inherit; }
.spe__al { font-size: var(--fs-13); color: var(--c-ink-500); }
</style>
