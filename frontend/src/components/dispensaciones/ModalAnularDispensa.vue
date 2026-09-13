<script setup>
// ANULAR UNA DISPENSA, DICIENDO POR QUÉ (Germán, 13-sep-2026).
//
// Reemplaza a «Eliminar», que soft-borraba la fila sin motivo: la dispensa desaparecía de las
// listas y nadie sabía si fue un dedazo o un paciente que devolvió el producto. Son hechos
// distintos y se deshacen distinto —la plata y el producto van a lugares distintos—, así que
// se pregunta primero, y el modal termina en una oración que dice exactamente qué va a pasar.
// La regla vive en el backend (`Dispensaciones::Cancelar`); acá sólo se la cuenta.
import { ref, computed, watch } from 'vue'

const props = defineProps({
  modelValue:   { type: Boolean, default: false },
  dispensacion: { type: Object,  default: null },
  guardando:    { type: Boolean, default: false },
  error:        { type: String,  default: '' },
})
const emit = defineEmits(['update:modelValue', 'anular'])

const MOTIVOS = [
  { value: 'error_carga',         label: 'Error de carga',
    desc: 'Se cargó mal: otro paciente, otra cantidad, dos veces. Nunca pasó.' },
  { value: 'devolucion',          label: 'El paciente lo devolvió',
    desc: 'Se arrepintió o no lo quiso. Trae el producto y se le devuelve la plata.' },
  { value: 'producto_defectuoso', label: 'Producto defectuoso',
    desc: 'Llegó roto o en mal estado. Se le devuelve la plata y el producto no se vuelve a entregar.' },
]

const MEDIO_LABEL = { efectivo: 'en efectivo', transferencia: 'por transferencia', mercado_pago: 'por Mercado Pago' }
const FORMA = { flor_seca: 'flor', preroll: 'prerolls', aceite: 'aceite', hash: 'hash', extracto: 'extracto', comestible: 'comestibles', prensado: 'prensado', capsula: 'cápsulas', crema: 'crema', tintura: 'tintura' }

const motivo    = ref('')
const nota      = ref('')
const descartar = ref(false)

const fmtARS = n => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n || 0)
const fmtCant = n => { const x = Number(n || 0); return Number.isInteger(x) ? String(x) : x.toFixed(2).replace(/\.?0+$/, '') }

const d = computed(() => props.dispensacion)
const conDevolucion = computed(() => ['devolucion', 'producto_defectuoso'].includes(motivo.value))
const seDescarta    = computed(() => motivo.value === 'producto_defectuoso' || (motivo.value === 'devolucion' && descartar.value))
const puedeGuardar  = computed(() => !!motivo.value && !props.guardando)

// Qué producto: «85 g de Critical Kush» / «2 prerolls de Northern Lights».
const producto = computed(() => {
  const items = d.value?.items?.length ? d.value.items : []
  if (!items.length) return 'el producto'
  const partes = items.map(it => {
    const u = it.stock?.unidad || 'g'
    const nombre = it.genetica_nombre || FORMA[it.stock?.forma_producto] || it.stock?.forma_producto || 'producto'
    return u === 'g' ? `${fmtCant(it.cantidad)} g de ${nombre}` : `${fmtCant(it.cantidad)} ${FORMA[it.stock?.forma_producto] || u} de ${nombre}`
  })
  return partes.length <= 2 ? partes.join(' y ') : `${partes.length} productos`
})

// Cómo se cobró, para decir cómo se devuelve. Los cobros son la verdad; si no hay (cuenta
// corriente, regalo), se mira el medio de la dispensa.
const cobrado = computed(() => {
  const cobros = (d.value?.cobros || []).filter(c => c.pagado !== false && Number(c.monto_ars) > 0)
  if (cobros.length) {
    const porMedio = {}
    cobros.forEach(c => { porMedio[c.medio] = (porMedio[c.medio] || 0) + Number(c.monto_ars) })
    return Object.entries(porMedio).map(([medio, monto]) => ({ medio, monto }))
  }
  const monto = Number(d.value?.aporte_socio_ars || 0)
  if (!monto || d.value?.es_regalo) return []
  return [{ medio: d.value?.medio_pago || 'efectivo', monto }]
})

const oracion = computed(() => {
  if (!d.value || !motivo.value) return ''
  const frases = []
  // El producto.
  if (seDescarta.value) {
    frases.push(`${producto.value} sale como merma: no vuelve a la mesa.`)
  } else {
    frases.push(`${producto.value} vuelve al stock —y a la mesa si hay alguien atendiendo—.`)
  }
  // La plata.
  if (conDevolucion.value) {
    const partes = cobrado.value.map(({ medio, monto }) => {
      if (medio === 'cuenta_corriente') return `se le reacreditan ${fmtARS(monto)} en su cuenta corriente`
      if (medio === 'efectivo') return `salen ${fmtARS(monto)} en efectivo de la caja`
      if (medio === 'no_abona' || medio === 'gramos') return null
      return `queda una devolución pendiente de ${fmtARS(monto)} ${MEDIO_LABEL[medio] || medio}, que se registra cuando se la devuelvan`
    }).filter(Boolean)
    if (partes.length) frases.push(`La venta queda registrada y ${partes.join('; ')}.`)
    else frases.push('No había plata que devolver.')
  } else {
    const total = cobrado.value.reduce((a, c) => a + c.monto, 0)
    frases.push(total > 0 ? `El ingreso de ${fmtARS(total)} se borra, como si no se hubiera cargado.` : 'No se cargó plata.')
  }
  frases.push('La dispensa queda en el historial como anulada, con tu nombre y el motivo.')
  return frases.map(f => f.charAt(0).toUpperCase() + f.slice(1)).join(' ')
})

watch(() => props.modelValue, (abierto) => {
  if (!abierto) return
  motivo.value = ''; nota.value = ''; descartar.value = false
})

function cerrar() { emit('update:modelValue', false) }
function anular() {
  if (!puedeGuardar.value) return
  emit('anular', { id: d.value.id, motivo: motivo.value, nota: nota.value.trim() || null, descartar_producto: seDescarta.value })
}
</script>

<template>
  <Teleport to="body">
    <div v-modal="{ cerrar, sucio: () => !!motivo || !!nota }" v-if="modelValue && dispensacion" class="ad__overlay" @click.self="cerrar">
      <div class="ad__modal" role="dialog" aria-modal="true" aria-labelledby="ad-titulo">
        <div class="ad__head">
          <h3 id="ad-titulo" class="ad__title">Anular dispensa</h3>
          <button class="ad__close" type="button" aria-label="Cerrar" @click="cerrar"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="ad__body">
          <div class="ad__que">
            <span class="ad__desc">{{ producto }}</span>
            <span class="ad__monto">{{ fmtARS(dispensacion.aporte_socio_ars) }}</span>
            <span class="ad__sub">{{ dispensacion.paciente_nombre }}<template v-if="dispensacion.sede?.nombre"> · {{ dispensacion.sede.nombre }}</template></span>
          </div>

          <div v-if="error" class="ad__alert">{{ error }}</div>

          <div class="ad__fld">
            <span class="ad__lbl">¿Qué pasó?</span>
            <div class="ad__motivos" role="radiogroup" aria-label="Motivo">
              <button v-for="m in MOTIVOS" :key="m.value" type="button" class="ad__motivo"
                      :class="{ 'ad__motivo--on': motivo === m.value }" role="radio" :aria-checked="motivo === m.value"
                      :id="`ad-motivo-${m.value}`" @click="motivo = m.value">
                <span class="ad__motivo-ico"><i :class="motivo === m.value ? 'bi bi-check-circle-fill' : 'bi bi-circle'"></i></span>
                <span class="ad__motivo-txt">
                  <span class="ad__motivo-lbl">{{ m.label }}</span>
                  <span class="ad__motivo-desc">{{ m.desc }}</span>
                </span>
              </button>
            </div>
          </div>

          <label v-if="motivo === 'devolucion'" class="ad__check">
            <input id="ad-descartar" type="checkbox" v-model="descartar" />
            <span>El producto no se puede volver a entregar (vino abierto, mojado…): sale como merma.</span>
          </label>

          <label class="ad__fld">
            <span class="ad__lbl">Nota <span class="ad__opt">(opcional)</span></span>
            <input id="ad-nota" class="ad__inp" v-model="nota" maxlength="200"
                   :placeholder="motivo === 'producto_defectuoso' ? 'Qué tenía: preroll roto, frasco abierto…' : 'Algo que quieras dejar anotado'" />
          </label>

          <p v-if="oracion" class="ad__oracion">{{ oracion }}</p>
        </div>

        <div class="ad__foot">
          <button class="ad__btn-ghost" type="button" @click="cerrar">Cancelar</button>
          <button class="ad__btn" type="button" :disabled="!puedeGuardar" @click="anular">
            {{ guardando ? 'Anulando…' : 'Anular dispensa' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.ad__overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 1050; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.ad__modal { background: var(--c-paper, #fff); border-radius: 14px; width: 100%; max-width: 500px; max-height: 92vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.ad__head { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.2rem; border-bottom: 1px solid var(--c-slate-100); }
.ad__title { font-size: 1rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.ad__close { background: none; border: none; color: var(--c-slate-400); cursor: pointer; }
.ad__body { padding: 1.1rem 1.2rem; overflow-y: auto; display: flex; flex-direction: column; gap: .85rem; }
.ad__que { display: grid; grid-template-columns: 1fr auto; gap: .1rem .8rem; align-items: baseline; background: var(--c-slate-50); border-radius: 9px; padding: .65rem .8rem; }
.ad__desc { font-weight: 700; color: var(--c-slate-900); font-size: .9rem; }
.ad__monto { font-weight: 800; color: var(--c-slate-900); font-variant-numeric: tabular-nums; }
.ad__sub { grid-column: 1 / -1; font-size: .76rem; color: var(--c-slate-500); }
.ad__alert { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; border-radius: 8px; padding: .55rem .8rem; font-size: .82rem; }
.ad__fld { display: flex; flex-direction: column; gap: .35rem; }
.ad__lbl { font-size: .74rem; font-weight: 700; color: var(--c-slate-500); }
.ad__opt { font-weight: 400; }
.ad__motivos { display: flex; flex-direction: column; gap: .4rem; }
.ad__motivo { display: flex; gap: .6rem; align-items: flex-start; text-align: left; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .6rem .75rem; cursor: pointer; font-family: inherit; transition: border-color .15s, background .15s; }
.ad__motivo:hover { border-color: var(--c-slate-300); }
.ad__motivo--on { border-color: var(--c-rust-600); background: var(--c-rust-100); }
.ad__motivo:focus-visible { outline: 2px solid var(--c-rust-600); outline-offset: 2px; }
.ad__motivo-ico { color: var(--c-slate-300); font-size: 1rem; line-height: 1.2; flex-shrink: 0; }
.ad__motivo--on .ad__motivo-ico { color: var(--c-rust-600); }
.ad__motivo-txt { display: flex; flex-direction: column; gap: .1rem; }
.ad__motivo-lbl { font-size: .86rem; font-weight: 700; color: var(--c-slate-900); }
.ad__motivo-desc { font-size: .76rem; color: var(--c-slate-500); line-height: 1.35; }
.ad__check { display: flex; gap: .5rem; align-items: flex-start; font-size: .8rem; color: var(--c-slate-700); line-height: 1.4; cursor: pointer; }
.ad__check input { margin-top: .2rem; }
.ad__inp { width: 100%; box-sizing: border-box; padding: .5rem .65rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px; font-size: .86rem; color: var(--c-slate-900); font-family: inherit; background: #fff; }
.ad__inp:focus { outline: none; border-color: var(--c-rust-600); }
.ad__oracion { margin: 0; font-size: .86rem; color: var(--c-slate-700); line-height: 1.5; border-left: 3px solid var(--c-rust-600); padding: .45rem .7rem; background: var(--c-rust-100); border-radius: 0 8px 8px 0; }
.ad__foot { display: flex; justify-content: flex-end; gap: .6rem; padding: .9rem 1.2rem; border-top: 1px solid var(--c-slate-100); }
.ad__btn { background: var(--c-rust-600); color: #fff; border: none; border-radius: 9px; padding: .6rem 1.1rem; font-weight: 700; font-size: .86rem; cursor: pointer; font-family: inherit; }
.ad__btn:disabled { opacity: .55; cursor: not-allowed; }
.ad__btn-ghost { background: none; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .6rem 1rem; font-weight: 600; font-size: .86rem; color: var(--c-slate-600); cursor: pointer; font-family: inherit; }
</style>
