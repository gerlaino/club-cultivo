<script setup>
// REGISTRAR EL PAGO DE UN GASTO QUE QUEDÓ PENDIENTE (o de una cuota).
//
// Era un confirm de dos líneas que marcaba `pagado` y nada más: no decía con qué se pagó, ni
// cuándo, ni de dónde salió la plata. Un gasto de agosto pagado hoy salía de la caja en agosto, y
// pagado con el efectivo del cajón el arqueo de la noche daba faltante. Ahora pregunta las tres
// cosas y termina en una oración que dice qué va a pasar. La fecha del GASTO no se toca: el egreso
// se reconoce cuando se compró; acá se dice cuándo se pagó.
import { ref, computed, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { useCajasAbiertas, SIN_CAJA } from '../../composables/useCajasAbiertas.js'
import { hoyLocal, fmtARS } from './movimientoFlows.js'
import { formatFechaCorta } from '../../utils/dates.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  movimiento: { type: Object,  default: null },
  guardando:  { type: Boolean, default: false },
  error:      { type: String,  default: '' },
})
const emit = defineEmits(['update:modelValue', 'registrar'])

const MEDIOS = [
  { value: 'efectivo',      label: 'Efectivo' },
  { value: 'transferencia', label: 'Transferencia' },
  { value: 'mercado_pago',  label: 'Mercado Pago' },
]

const medio     = ref('efectivo')
const fechaPago = ref(hoyLocal())
const caja      = ref(SIN_CAJA)
const { cajas, cargar: cargarCajas, cajaDeSede, etiqueta } = useCajasAbiertas()

const esCuota   = computed(() => !!props.movimiento?.compra_cuotas_id)
const pideCaja  = computed(() => medio.value === 'efectivo' && cajas.value.length > 0)
const cajaSel   = computed(() => cajas.value.find(c => c.id === caja.value) || null)

// Una cuota se puede pagar antes de vencer: su fecha es cuándo vence, no cuándo se compró.
const minFecha  = computed(() => (esCuota.value ? null : props.movimiento?.fecha) || null)
const errorFecha = computed(() => {
  if (!fechaPago.value) return 'Elegí cuándo se pagó.'
  if (fechaPago.value > hoyLocal()) return 'No se puede registrar un pago futuro.'
  if (minFecha.value && fechaPago.value < minFecha.value) {
    return `El gasto es del ${formatFechaCorta(minFecha.value)}: no se pudo pagar antes.`
  }
  return ''
})
const puedeGuardar = computed(() => !errorFecha.value && !props.guardando)

// La oración final: lo que deja cargar bien a alguien que no sabe de contabilidad.
const oracion = computed(() => {
  const m = props.movimiento
  if (!m) return ''
  const como  = medio.value === 'efectivo' ? 'en efectivo' : `por ${MEDIOS.find(x => x.value === medio.value)?.label.toLowerCase()}`
  const de    = medio.value === 'efectivo' && cajaSel.value ? ` de la caja de ${cajaSel.value.sede}` : ''
  const cuando = fechaPago.value === hoyLocal() ? 'hoy' : `el ${formatFechaCorta(fechaPago.value)}`
  const sinCaja = medio.value === 'efectivo' && !cajaSel.value ? ' No entra al arqueo de ningún mostrador.' : ''
  return `Salen ${fmtARS(m.monto_ars)} ${como}${de}, ${cuando}. Deja de figurar como pendiente.${sinCaja}`
})

watch(() => props.modelValue, async (abierto) => {
  if (!abierto) return
  medio.value     = 'efectivo'
  fechaPago.value = hoyLocal()
  caja.value      = SIN_CAJA
  await cargarCajas()
  caja.value = cajaDeSede(props.movimiento?.sede?.id ?? props.movimiento?.sede_id)
})

function cerrar() { emit('update:modelValue', false) }
function registrar() {
  if (!puedeGuardar.value) return
  emit('registrar', {
    id:            props.movimiento.id,
    medio_pago:    medio.value,
    fecha_pago:    fechaPago.value,
    caja_turno_id: medio.value === 'efectivo' ? (caja.value ?? undefined) : undefined,
  })
}
</script>

<template>
  <Teleport to="body">
    <div v-modal="cerrar" v-if="modelValue && movimiento" class="rp__overlay" @click.self="cerrar">
      <div class="rp__modal" role="dialog" aria-modal="true" aria-labelledby="rp-titulo">
        <div class="rp__head">
          <h3 id="rp-titulo" class="rp__title">Registrar pago</h3>
          <button class="rp__close" type="button" aria-label="Cerrar" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="rp__body">
          <div class="rp__que">
            <span class="rp__desc">{{ movimiento.descripcion }}</span>
            <span class="rp__monto">{{ fmtARS(movimiento.monto_ars) }}</span>
            <span class="rp__sub">
              {{ esCuota ? `Cuota ${movimiento.cuota_numero} · vence el ${formatFechaCorta(movimiento.fecha)}` : `Gasto del ${formatFechaCorta(movimiento.fecha)}` }}
              <template v-if="movimiento.proveedor"> · {{ movimiento.proveedor }}</template>
            </span>
          </div>

          <div v-if="error" class="rp__alert">{{ error }}</div>

          <div class="rp__row">
            <div class="rp__fld">
              <span class="rp__lbl">Cómo se pagó</span>
              <div class="rp__seg" role="radiogroup" aria-label="Cómo se pagó">
                <button v-for="m in MEDIOS" :key="m.value" type="button" class="rp__seg-b"
                        :class="{ 'rp__seg-b--on': medio === m.value }" role="radio" :aria-checked="medio === m.value"
                        @click="medio = m.value">{{ m.label }}</button>
              </div>
            </div>
            <label class="rp__fld rp__fld--fecha">
              <span class="rp__lbl">Cuándo</span>
              <AppDatePicker v-model="fechaPago" :max="hoyLocal()" />
              <span v-if="errorFecha" class="rp__err">{{ errorFecha }}</span>
            </label>
          </div>

          <!-- Sólo en efectivo y sólo si hay alguna caja abierta: una transferencia no pasa por
               ningún cajón, y sin caja abierta no hay nada que elegir. -->
          <label v-if="pideCaja" class="rp__fld">
            <span class="rp__lbl">De qué caja sale</span>
            <select id="rp-caja" class="rp__inp" v-model="caja">
              <option :value="null">De ninguna — la plata no salió de un mostrador</option>
              <option v-for="c in cajas" :key="c.id" :value="c.id">{{ etiqueta(c) }}</option>
            </select>
            <span class="rp__hint">Si sale de una caja, el arqueo de esa noche la descuenta. Si no, el gasto se registra igual.</span>
          </label>

          <p class="rp__oracion">{{ oracion }}</p>
        </div>

        <div class="rp__foot">
          <button class="rp__btn-ghost" type="button" @click="cerrar">Cancelar</button>
          <button class="rp__btn" type="button" :disabled="!puedeGuardar" @click="registrar">
            {{ guardando ? 'Registrando…' : 'Registrar pago' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.rp__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 1050; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.rp__modal { background: var(--c-paper, #fff); border-radius: 14px; width: 100%; max-width: 480px; max-height: 92vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.rp__head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.2rem; border-bottom: 1px solid var(--c-slate-100); }
.rp__title { font-size: 1rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.rp__close { background: none; border: none; color: var(--c-slate-400); cursor: pointer; }
.rp__body { padding: 1.1rem 1.2rem; overflow-y: auto; display: flex; flex-direction: column; gap: .85rem; }
.rp__que { display: grid; grid-template-columns: 1fr auto; gap: .1rem .8rem; align-items: baseline; background: var(--c-slate-50); border-radius: 9px; padding: .65rem .8rem; }
.rp__desc { font-weight: 700; color: var(--c-slate-900); font-size: .9rem; }
.rp__monto { font-weight: 800; color: var(--c-slate-900); font-variant-numeric: tabular-nums; }
.rp__sub { grid-column: 1 / -1; font-size: .76rem; color: var(--c-slate-500); }
.rp__alert { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; border-radius: 8px; padding: .55rem .8rem; font-size: .82rem; }
.rp__row { display: flex; gap: .7rem; flex-wrap: wrap; align-items: flex-start; }
/* El `flex-basis` sólo dentro de la fila: en el cuerpo (columna) 200px serían de ALTO y dejaban
   un hueco de media pantalla entre la caja y la oración. */
.rp__fld { display: flex; flex-direction: column; gap: .28rem; }
.rp__row > .rp__fld { flex: 1 1 200px; }
.rp__row > .rp__fld--fecha { flex: 0 1 170px; }
.rp__lbl { font-size: .74rem; font-weight: 700; color: var(--c-slate-500); }
.rp__seg { display: inline-flex; border: 1.5px solid var(--c-slate-200); border-radius: 9px; overflow: hidden; }
.rp__seg-b { flex: 1; background: #fff; border: none; padding: .5rem .7rem; font-size: .82rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; font-family: inherit; white-space: nowrap; }
.rp__seg-b + .rp__seg-b { border-left: 1.5px solid var(--c-slate-200); }
.rp__seg-b--on { background: #15803d; color: #fff; }
.rp__seg-b:focus-visible { outline: 2px solid #15803d; outline-offset: -2px; }
.rp__inp { width: 100%; box-sizing: border-box; padding: .5rem .65rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px; font-size: .86rem; color: var(--c-slate-900); font-family: inherit; background: #fff; }
.rp__inp:focus { outline: none; border-color: #15803d; }
.rp__hint { font-size: .72rem; color: var(--c-slate-500); line-height: 1.4; }
.rp__err { font-size: .72rem; color: var(--c-rust-600, #b91c1c); }
.rp__oracion { margin: 0; font-size: .86rem; color: var(--c-slate-700); line-height: 1.5; border-left: 3px solid #15803d; padding: .45rem .7rem; background: rgba(21,128,61,.05); border-radius: 0 8px 8px 0; }
.rp__foot { display: flex; justify-content: flex-end; gap: .6rem; padding: .9rem 1.2rem; border-top: 1px solid var(--c-slate-100); }
.rp__btn { background: #15803d; color: #fff; border: none; border-radius: 9px; padding: .6rem 1.1rem; font-weight: 700; font-size: .86rem; cursor: pointer; font-family: inherit; }
.rp__btn:disabled { opacity: .55; cursor: not-allowed; }
.rp__btn-ghost { background: none; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .6rem 1rem; font-weight: 600; font-size: .86rem; color: var(--c-slate-600); cursor: pointer; font-family: inherit; }
</style>
