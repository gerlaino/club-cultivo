<script setup>
// CÓMO SE LE DEVUELVE LA PLATA AL PACIENTE: el medio y, en efectivo, de qué caja sale.
//
// Lo usan administración al cancelar una entrega («devolver lo que pagó») y el botón «Devolver
// plata» de la cuenta corriente. La regla de verdad vive en el backend
// (`Devoluciones::CajaDeSalida`: la caja tiene que alcanzar); acá se dice ANTES de confirmar, para
// que el error no aparezca recién después del click.
import { computed, watch, onMounted } from 'vue'
import { useCajasAbiertas, SIN_CAJA } from '../../composables/useCajasAbiertas.js'

const props = defineProps({
  monto:  { type: Number, required: true },
  // La sede de la que viene la plata: su caja abierta es la que se propone.
  sedeId: { type: [Number, String, null], default: null },
})
const medio = defineModel('medio', { type: String, default: 'efectivo' })
const caja  = defineModel('caja',  { default: SIN_CAJA })
// El motivo por el que no se puede confirmar todavía ('' = se puede).
const emit = defineEmits(['update:error'])

const MEDIOS = [
  { value: 'efectivo',      label: 'Efectivo' },
  { value: 'transferencia', label: 'Transferencia' },
  { value: 'mercado_pago',  label: 'Mercado Pago' },
]

const { cajas, cargar, cajaDeSede } = useCajasAbiertas()
onMounted(async () => {
  await cargar()
  if (caja.value === SIN_CAJA) caja.value = cajaDeSede(props.sedeId)
})

const fmtARS = n => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n || 0)

const cajaSel = computed(() => cajas.value.find(c => c.id === caja.value) || null)
const error = computed(() => {
  if (medio.value === 'efectivo' && cajaSel.value && cajaSel.value.esperado < props.monto - 0.009) {
    return `En la caja de ${cajaSel.value.sede} hay ${fmtARS(cajaSel.value.esperado)} y hay que devolver ${fmtARS(props.monto)}. Devolvé por transferencia, o ingresá plata a la caja primero.`
  }
  return ''
})
watch(error, e => emit('update:error', e), { immediate: true })

// Lo que va a pasar, dicho en una oración.
const oracion = computed(() => {
  if (medio.value !== 'efectivo') {
    return `Queda una devolución pendiente de ${fmtARS(props.monto)} ${medio.value === 'transferencia' ? 'por transferencia' : 'por Mercado Pago'}: se marca como pagada en Contabilidad cuando se la transfieran.`
  }
  return cajaSel.value
    ? `Salen ${fmtARS(props.monto)} en efectivo de la caja de ${cajaSel.value.sede}.`
    : `Salen ${fmtARS(props.monto)} en efectivo de ninguna caja: no entra a ningún arqueo.`
})
</script>

<template>
  <div class="cdev">
    <div class="cdev__seg" role="radiogroup" aria-label="Cómo se devuelve">
      <button v-for="m in MEDIOS" :key="m.value" type="button" class="cdev__seg-b"
              :class="{ 'cdev__seg-b--on': medio === m.value }" :id="`cdev-${m.value}`"
              role="radio" :aria-checked="medio === m.value" @click="medio = m.value">{{ m.label }}</button>
    </div>
    <select v-if="medio === 'efectivo' && cajas.length" id="cdev-caja" class="cdev__inp" v-model="caja"
            aria-label="De qué caja sale">
      <option :value="null">De ninguna caja — la plata no sale de un mostrador</option>
      <option v-for="c in cajas" :key="c.id" :value="c.id">Caja de {{ c.sede }} · hay {{ fmtARS(c.esperado) }}</option>
    </select>
    <span v-if="error" class="cdev__err">{{ error }}</span>
    <span v-else class="cdev__oracion">{{ oracion }}</span>
  </div>
</template>

<style scoped>
.cdev { display: flex; flex-direction: column; gap: .45rem; }
/* Tres partes iguales a lo ancho: con el ancho de cada texto, «Mercado Pago» se salía del modal. */
.cdev__seg { display: grid; grid-template-columns: repeat(3, 1fr); border: 1.5px solid var(--c-slate-200); border-radius: 9px; overflow: hidden; }
.cdev__seg-b { background: #fff; border: none; padding: .5rem .4rem; font-size: .82rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; font-family: inherit; line-height: 1.2; }
.cdev__seg-b + .cdev__seg-b { border-left: 1.5px solid var(--c-slate-200); }
.cdev__seg-b--on { background: var(--c-slate-900); color: #fff; }
.cdev__seg-b:focus-visible { outline: 2px solid var(--c-slate-900); outline-offset: -2px; }
.cdev__inp { border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .5rem .6rem; font-size: .84rem; font-family: inherit; background: #fff; color: var(--c-slate-900); }
.cdev__err { font-size: .78rem; color: var(--c-rust-600); font-weight: 600; line-height: 1.4; }
.cdev__oracion { font-size: .78rem; color: var(--c-slate-500); line-height: 1.4; }
</style>
