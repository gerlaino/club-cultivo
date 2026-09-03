<template>
  <div class="cnt__back" @click.self="$emit('cerrar')">
    <div class="cnt__modal">
      <h3 class="cnt__title">{{ esCierre ? 'Cerrar caja' : 'Abrir caja' }}</h3>
      <p class="cnt__sub">
        {{ esCierre
           ? 'Contá lo que queda sobre la mesa y la plata del cajón. Después te muestro la comparación.'
           : 'Pesá lo que hay sobre la mesa y contá la plata. Si no coincide, poné lo que contaste: no te frena.' }}
      </p>

      <div v-if="!mesa.length && !esCierre" class="cnt__vacio">
        La mesa está vacía. Podés abrir igual y que administración la cargue después.
      </div>

      <div class="cnt__lista">
        <div v-for="c in conteos" :key="c.stock_id" class="cnt__row">
          <div class="cnt__prod">
            <span class="cnt__nombre">{{ formaLabel(c.forma) }}</span>
            <span class="cnt__meta">{{ c.genetica || c.numero }}</span>
          </div>
          <div class="cnt__cant">
            <input v-model.number="c.contado" type="number" min="0" step="0.1"
                   class="cnt__input" :aria-label="`Contado de ${formaLabel(c.forma)}`" />
            <span class="cnt__unidad">{{ c.unidad }}</span>
          </div>
        </div>
      </div>

      <label class="cnt__campo">
        <span class="cnt__campo-lbl">Efectivo contado</span>
        <span class="cnt__campo-input">
          <span class="cnt__signo">$</span>
          <input v-model.number="efectivo" type="number" min="0" step="100" class="cnt__input cnt__input--plata" />
        </span>
      </label>

      <!-- LA COMPARACIÓN, GRANDE Y CLARA. Y recién DESPUÉS de escribir lo contado: con el número
           esperado a la vista nadie pesa, se escribe ese, y toda la merma que se mide da cero. -->
      <div v-if="hayAlgoContado" class="cnt__comparacion">
        <div class="cnt__comp-hd">
          <span></span><span>Debería haber</span><span>Contaste</span><span>Diferencia</span>
        </div>
        <div class="cnt__comp-row">
          <span class="cnt__comp-lbl">Efectivo</span>
          <span class="cnt__comp-num">${{ fmt(esperadoEfectivo) }}</span>
          <span class="cnt__comp-num">${{ fmt(efectivo) }}</span>
          <span class="cnt__comp-dif" :class="clase(difEfectivo)">{{ signo(difEfectivo) }}${{ fmt(Math.abs(difEfectivo)) }}</span>
        </div>
        <div v-for="c in conDiferencia" :key="c.stock_id" class="cnt__comp-row">
          <span class="cnt__comp-lbl">{{ formaLabel(c.forma) }}<em v-if="c.genetica"> · {{ c.genetica }}</em></span>
          <span class="cnt__comp-num">{{ fmt(c.esperado) }} {{ c.unidad }}</span>
          <span class="cnt__comp-num">{{ fmt(c.contado) }} {{ c.unidad }}</span>
          <span class="cnt__comp-dif" :class="clase(c.contado - c.esperado)">
            {{ signo(c.contado - c.esperado) }}{{ fmt(Math.abs(c.contado - c.esperado)) }} {{ c.unidad }}
          </span>
        </div>
        <p v-if="!conDiferencia.length && difEfectivo === 0" class="cnt__cuadra">Cuadra todo.</p>
        <!-- La merma es inevitable y no es culpa de nadie: se anota, no se juzga. -->
        <p v-else class="cnt__nota">
          Queda anotado. No te frena: {{ esCierre ? 'la caja cierra igual' : 'podés abrir igual' }}.
        </p>
      </div>

      <label class="cnt__campo cnt__campo--obs">
        <span class="cnt__campo-lbl">Observaciones</span>
        <input v-model="notas" type="text" class="cnt__input"
               :placeholder="hayDiferencia ? 'Qué pasó' : 'Opcional'" />
      </label>

      <template v-if="esCierre">
        <label class="cnt__campo">
          <span class="cnt__campo-lbl">Dejo de fondo para el próximo</span>
          <span class="cnt__campo-input">
            <span class="cnt__signo">$</span>
            <input v-model.number="fondo" type="number" min="0" step="100" class="cnt__input cnt__input--plata" />
          </span>
        </label>
        <p v-if="aRetirar > 0" class="cnt__retiro">
          Se retiran <b>${{ fmt(aRetirar) }}</b>{{ puedeRetirar ? ' — quedan a tu nombre.' : '.' }}
          <span v-if="!puedeRetirar" class="cnt__nota">
            El retiro queda a nombre de administración: si no hay nadie, dejá todo como fondo.
          </span>
        </p>
      </template>

      <div class="cnt__acc">
        <button class="cnt__btn cnt__btn--ghost" @click="$emit('cerrar')">Cancelar</button>
        <button class="cnt__btn cnt__btn--primary" :disabled="guardando" @click="confirmar">
          {{ guardando ? 'Guardando…' : (esCierre ? 'Cerrar caja' : 'Abrir caja') }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
// CONTAR PARA ABRIR Y PARA CERRAR: el mismo gesto, con el mismo dibujo.
//
// Sirve igual para el arqueo del mediodía y para el cambio de turno: cierra uno, y el que sigue
// abre contando lo que dice que hay.
//
// NO BLOQUEA POR DIFERENCIA. Si lo que se cuenta no coincide, se anota y sigue: frenarlo dejaría
// el mostrador cerrado a las 8 de la mañana esperando a alguien que no está. La merma es
// inevitable y no es culpa de nadie — se mide para saber cuánta hay y dónde.
//
// Y LO ESPERADO NO SE MUESTRA HASTA QUE EL CONTEO ESTÁ ESCRITO: con el número a la vista nadie
// pesa, se escribe ése, y toda la merma que se mide da cero.
import { ref, computed } from 'vue'
import { formaLabel } from '../../lib/formatters.js'

const props = defineProps({
  mesa:     { type: Array,  default: () => [] },   // lo que hay sobre la mesa
  esCierre: { type: Boolean, default: false },
  esperadoEfectivo: { type: Number, default: 0 },
  puedeRetirar: { type: Boolean, default: false },
  guardando:    { type: Boolean, default: false },
})
const emit = defineEmits(['cerrar', 'confirmar'])

const conteos = ref(props.mesa.map(m => ({
  stock_id: m.stock_id, forma: m.forma, genetica: m.genetica, numero: m.numero,
  unidad: m.unidad, esperado: Number(m.mostrador || 0), contado: null,
})))
const efectivo = ref(null)
const fondo    = ref(null)
const notas    = ref('')

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })
const escrito = (v) => v !== null && v !== '' && !Number.isNaN(Number(v))

const hayAlgoContado = computed(() =>
  escrito(efectivo.value) || conteos.value.some(c => escrito(c.contado))
)
const difEfectivo = computed(() =>
  escrito(efectivo.value) ? Math.round((Number(efectivo.value) - props.esperadoEfectivo) * 100) / 100 : 0
)
const conDiferencia = computed(() =>
  conteos.value.filter(c => escrito(c.contado) && Number(c.contado) !== c.esperado)
)
const hayDiferencia = computed(() => conDiferencia.value.length > 0 || difEfectivo.value !== 0)
const aRetirar = computed(() => {
  if (!props.esCierre || !escrito(efectivo.value)) return 0
  return Math.max(Number(efectivo.value) - Number(fondo.value || 0), 0)
})

const signo = (n) => (n > 0 ? '+' : n < 0 ? '−' : '')
const clase = (n) => (n === 0 ? 'is-ok' : 'is-dif')

function confirmar () {
  emit('confirmar', {
    // Al CERRAR se manda todo (hay que contar todo); al ABRIR sólo lo que se escribió: lo que no
    // se tocó se toma como que coincide, y así confirmar es un click.
    conteos: conteos.value
      .filter(c => props.esCierre || escrito(c.contado))
      .map(c => ({ stock_id: c.stock_id, contado: escrito(c.contado) ? Number(c.contado) : c.esperado })),
    efectivo_contado_ars: escrito(efectivo.value) ? Number(efectivo.value) : null,
    fondo_siguiente_ars:  props.esCierre && escrito(fondo.value) ? Number(fondo.value) : null,
    notas: notas.value || undefined,
  })
}
</script>

<style scoped>
.cnt__back {
  position: fixed; inset: 0; background: rgba(15, 42, 30, .45);
  display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 1000;
}
.cnt__modal {
  background: #fff; border-radius: 14px; padding: 24px;
  width: 100%; max-width: 620px; max-height: 88vh; overflow-y: auto;
  display: flex; flex-direction: column; gap: 14px;
}
.cnt__title { font-family: var(--font-display); font-size: var(--fs-18); font-weight: 700; color: var(--c-leaf-900); margin: 0; }
.cnt__sub   { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }
.cnt__vacio { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }

.cnt__lista { display: flex; flex-direction: column; }
.cnt__row {
  display: flex; align-items: center; justify-content: space-between; gap: 12px;
  padding: 10px 0; border-top: 1px solid var(--c-slate-100);
}
.cnt__prod   { display: flex; flex-direction: column; min-width: 0; }
.cnt__nombre { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.cnt__meta   { font-size: var(--fs-12); color: var(--c-ink-500); }
.cnt__cant   { display: inline-flex; align-items: baseline; gap: 6px; }
.cnt__unidad { font-size: var(--fs-13); color: var(--c-ink-500); width: 22px; }

.cnt__input {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 9px 11px;
  font-size: var(--fs-14); font-family: var(--font-mono); width: 100%;
  background: #fff; color: var(--c-ink-900);
}
.cnt__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.cnt__input--plata { width: 150px; text-align: right; }
.cnt__cant .cnt__input { width: 96px; text-align: right; }

.cnt__campo { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.cnt__campo--obs { flex-direction: column; align-items: stretch; gap: 5px; }
.cnt__campo-lbl { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
.cnt__campo-input { display: inline-flex; align-items: center; gap: 6px; }
.cnt__signo { font-size: var(--fs-16); color: var(--c-ink-500); }

/* La comparación: es lo que la persona mira. Grande, alineada y en columnas. */
.cnt__comparacion {
  background: var(--c-leaf-50); border-radius: 11px; padding: 14px 16px;
  display: flex; flex-direction: column; gap: 6px;
}
.cnt__comp-hd, .cnt__comp-row {
  display: grid; grid-template-columns: 1fr auto auto auto; gap: 14px; align-items: baseline;
}
.cnt__comp-hd span { font-size: var(--fs-12); color: var(--c-ink-500); text-align: right; }
.cnt__comp-hd span:first-child { text-align: left; }
.cnt__comp-lbl { font-size: var(--fs-13); color: var(--c-ink-700); }
.cnt__comp-lbl em { font-style: normal; color: var(--c-ink-500); }
.cnt__comp-num { font-family: var(--font-mono); font-size: var(--fs-14); color: var(--c-ink-900); text-align: right; }
.cnt__comp-dif { font-family: var(--font-mono); font-size: var(--fs-14); font-weight: 700; text-align: right; }
.cnt__comp-dif.is-ok  { color: var(--c-leaf-600); }
/* Ámbar y no rojo: una diferencia es un dato que se anota, no una falta que alguien explica. */
.cnt__comp-dif.is-dif { color: var(--c-amber-500); }
.cnt__cuadra { margin: 0; font-size: var(--fs-13); font-weight: 600; color: var(--c-leaf-600); }
.cnt__nota   { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }
.cnt__retiro { margin: 0; font-size: var(--fs-13); color: var(--c-ink-700); }

.cnt__acc { display: flex; gap: 10px; justify-content: flex-end; }
.cnt__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.cnt__btn:disabled { opacity: .5; cursor: not-allowed; }
.cnt__btn--primary { background: var(--c-leaf-800); color: #fff; }
.cnt__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
</style>
