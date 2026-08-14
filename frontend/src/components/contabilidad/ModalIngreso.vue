<script setup>
// Registrar un ingreso EXCEPCIONAL: una subvención, una donación, la venta de un bien.
//
// Es una puerta aparte de "Nuevo movimiento" a propósito. La plata que entra todos los días ya
// tiene la suya y se registra sola: el pago de un paciente en su cuenta corriente, el recupero
// en la dispensación, la venta del buffet en el mostrador. Cargar eso otra vez a mano lo contaría
// DOS VECES. Lo que queda afuera es lo excepcional, que sin este formulario no tiene dónde
// anotarse y deja el balance sin cuadrar contra el banco.
//
// Cinco campos y nada más. Un ingreso no entra a ningún inventario, no se compra por unidades y
// no se paga en cuotas: la mitad del formulario de egreso no le aplica.
import { ref, computed, watch } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { useModalEscape } from '../../composables/useModalEscape.js'
import { hoyLocal, fmtMiles, parseMonto } from './movimientoFlows.js'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  sedes:      { type: Array,  default: () => [] },
  unidades:   { type: Array,  default: () => [] },
  guardando:  { type: Boolean, default: false },
  error:      { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue', 'guardado'])

// De dónde vino. Cada origen ya sabe con qué categoría contable se guarda: la persona elige en
// castellano y no tiene que conocer el plan de cuentas.
const ORIGENES = [
  { value: 'subvencion', label: 'Subvención',      categoria: 'subvencion' },
  { value: 'donacion',   label: 'Donación',        categoria: 'subvencion' },
  { value: 'venta_bien', label: 'Venta de un bien', categoria: 'otro' },
  { value: 'otro',       label: 'Otro',            categoria: 'otro' },
]
const MEDIOS = [
  { value: 'transferencia', label: 'Transferencia' },
  { value: 'efectivo',      label: 'Efectivo' },
  { value: 'mercado_pago',  label: 'Mercado Pago' },
]

const vacio = () => ({
  origen: 'subvencion',
  monto_ars: null,
  descripcion: '',
  fecha: hoyLocal(),
  medio_pago: 'transferencia',
  sede_id: null,
  unidad_negocio_id: null,
})
const form       = ref(vacio())
const montoTexto = ref('')
const errores    = ref({})

const origenActual = computed(() => ORIGENES.find(o => o.value === form.value.origen))
const multiSede    = computed(() => props.sedes.length > 1)
const sectores     = computed(() => props.unidades.filter(u => u.disponible !== false && u.activa !== false))

function onMonto(e) {
  const { texto, monto } = parseMonto(e.target.value)
  montoTexto.value = texto
  form.value.monto_ars = monto
}

const erroresActuales = computed(() => {
  const e = {}
  if (!(Number(form.value.monto_ars) > 0)) e.monto_ars = 'Ingresá un monto'
  if (!form.value.descripcion?.trim())     e.descripcion = 'Contá de qué es'
  if (!form.value.fecha)                   e.fecha = 'Elegí la fecha'
  return e
})
const puedeGuardar = computed(() => Object.keys(erroresActuales.value).length === 0 && !props.guardando)

function guardar() {
  errores.value = erroresActuales.value
  if (Object.keys(errores.value).length) return

  emit('guardado', {
    tipo: 'ingreso',
    categoria: origenActual.value.categoria,
    descripcion: `${origenActual.value.label}: ${form.value.descripcion.trim()}`,
    monto_ars: form.value.monto_ars,
    fecha: form.value.fecha,
    medio_pago: form.value.medio_pago,
    pagado: true,                       // un ingreso excepcional se registra cuando ya entró
    sede_id: form.value.sede_id,
    unidad_negocio_id: form.value.unidad_negocio_id,
  })
}

function cerrar() { emit('update:modelValue', false) }
useModalEscape(() => { if (props.modelValue) cerrar() })

watch(() => props.modelValue, (abierto) => {
  if (!abierto) return
  form.value = vacio()
  montoTexto.value = ''
  errores.value = {}
})
</script>

<template>
  <Teleport to="body">
    <div v-if="modelValue" class="mi__overlay" @click.self="cerrar">
      <div class="mi__modal">
        <div class="mi__head">
          <h3 class="mi__title">Registrar ingreso</h3>
          <button class="mi__close" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="mi__body">
          <p class="mi__nota">
            Para lo excepcional: una subvención, una donación o la venta de un bien.
            El pago de un paciente se registra en su <strong>cuenta corriente</strong> y lo del
            buffet, en el mostrador — desde ahí entran solos.
          </p>

          <div v-if="error" class="mi__alert">{{ error }}</div>

          <label class="mi__fld">
            <span class="mi__lbl">De dónde vino</span>
            <select class="mi__inp" v-model="form.origen">
              <option v-for="o in ORIGENES" :key="o.value" :value="o.value">{{ o.label }}</option>
            </select>
          </label>

          <label class="mi__fld">
            <span class="mi__lbl">¿Cuánto?</span>
            <div class="mi__monto" :class="{ 'mi__monto--err': errores.monto_ars }">
              <span class="mi__monto-sig">+$</span>
              <input type="text" inputmode="decimal" class="mi__monto-inp"
                     :value="montoTexto" @input="onMonto" placeholder="0" />
            </div>
            <span v-if="errores.monto_ars" class="mi__err">{{ errores.monto_ars }}</span>
          </label>

          <label class="mi__fld">
            <span class="mi__lbl">Detalle</span>
            <input type="text" class="mi__inp" :class="{ 'mi__inp--err': errores.descripcion }"
                   v-model.trim="form.descripcion" placeholder="Ej: aporte municipal de agosto" />
            <span v-if="errores.descripcion" class="mi__err">{{ errores.descripcion }}</span>
          </label>

          <div class="mi__row">
            <label class="mi__fld mi__fld--sm">
              <span class="mi__lbl">Fecha</span>
              <AppDatePicker v-model="form.fecha" />
            </label>
            <label class="mi__fld mi__fld--sm">
              <span class="mi__lbl">Cómo entró</span>
              <select class="mi__inp" v-model="form.medio_pago">
                <option v-for="m in MEDIOS" :key="m.value" :value="m.value">{{ m.label }}</option>
              </select>
            </label>
          </div>

          <div class="mi__row">
            <label v-if="sectores.length" class="mi__fld mi__fld--sm">
              <span class="mi__lbl">Sector <span class="mi__opt">(opcional)</span></span>
              <select class="mi__inp" v-model="form.unidad_negocio_id">
                <option :value="null">— Sin sector —</option>
                <option v-for="u in sectores" :key="u.id" :value="u.id">{{ u.nombre }}</option>
              </select>
            </label>
            <label v-if="multiSede" class="mi__fld mi__fld--sm">
              <span class="mi__lbl">Sede <span class="mi__opt">(opcional)</span></span>
              <select class="mi__inp" v-model="form.sede_id">
                <option :value="null">— Sin sede —</option>
                <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
            </label>
          </div>
        </div>

        <div class="mi__foot">
          <button class="mi__btn-ghost" @click="cerrar">Cancelar</button>
          <button class="mi__btn" :disabled="!puedeGuardar" @click="guardar">
            {{ guardando ? 'Guardando…' : 'Registrar ingreso' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.mi__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 1050; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.mi__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 460px; max-height: 92vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.mi__head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.2rem; border-bottom: 1px solid var(--c-slate-100); }
.mi__title { font-size: 1rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mi__close { background: none; border: none; color: var(--c-slate-400); cursor: pointer; }
.mi__body { padding: 1.1rem 1.2rem; overflow-y: auto; display: flex; flex-direction: column; gap: .8rem; }
.mi__nota { margin: 0; font-size: .76rem; color: var(--c-slate-500); line-height: 1.45; background: var(--c-slate-50); border-radius: 9px; padding: .6rem .7rem; }
.mi__alert { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; border-radius: 8px; padding: .55rem .8rem; font-size: .82rem; }
.mi__fld { display: flex; flex-direction: column; gap: .28rem; }
.mi__fld--sm { flex: 1 1 150px; }
.mi__row { display: flex; gap: .7rem; flex-wrap: wrap; }
.mi__lbl { font-size: .74rem; font-weight: 700; color: var(--c-slate-500); }
.mi__opt { font-weight: 400; color: var(--c-slate-400); }
.mi__inp { width: 100%; box-sizing: border-box; padding: .5rem .65rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px; font-size: .86rem; color: var(--c-slate-900); font-family: inherit; }
.mi__inp:focus { outline: none; border-color: #15803d; }
.mi__inp--err { border-color: var(--c-rust-600); }
.mi__monto { display: flex; align-items: center; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .45rem .65rem; }
.mi__monto:focus-within { border-color: #15803d; }
.mi__monto--err { border-color: var(--c-rust-600); }
.mi__monto-sig { font-size: 1rem; font-weight: 700; color: #15803d; margin-right: 4px; }
.mi__monto-inp { border: none; outline: none; font-size: 1.15rem; font-weight: 700; color: var(--c-slate-900); width: 100%; font-family: inherit; }
.mi__err { font-size: .72rem; color: var(--c-rust-600); }
.mi__foot { display: flex; justify-content: flex-end; gap: .6rem; padding: .9rem 1.2rem; border-top: 1px solid var(--c-slate-100); }
.mi__btn-ghost { background: none; border: 1.5px solid var(--c-slate-300); color: var(--c-slate-500); border-radius: 9px; padding: .5rem 1rem; font-size: .85rem; font-weight: 700; cursor: pointer; }
.mi__btn { background: #15803d; color: #fff; border: none; border-radius: 9px; padding: .5rem 1.1rem; font-size: .85rem; font-weight: 700; cursor: pointer; }
.mi__btn:disabled { opacity: .55; cursor: not-allowed; }
</style>
