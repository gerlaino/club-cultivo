<template>
  <div class="cti__back" @click.self="$emit('cerrar')">
    <div class="cti__modal" role="dialog" aria-modal="true">
      <h3 class="cti__title">Contar {{ formaLabel(item.forma) }}</h3>
      <p class="cti__sub">
        {{ item.genetica || item.numero }} — pesá lo que hay ahora sobre la mesa. No hace falta
        cerrar la caja: se ajusta este producto y seguís atendiendo.
      </p>

      <label class="cti__campo">
        <span class="cti__campo-lbl">¿Cuánto hay?</span>
        <span class="cti__campo-input">
          <input ref="campo" v-model.number="contado" type="number" min="0" step="0.1"
                 class="cti__input" :aria-label="`Contado de ${formaLabel(item.forma)}`" />
          <span class="cti__unidad">{{ item.unidad }}</span>
        </span>
      </label>

      <!-- LO ESPERADO, RECIÉN DESPUÉS DE ESCRIBIR. Con el número a la vista nadie pesa: se
           escribe ése, el conteo es teatro y toda la merma que se mide da cero. -->
      <div v-if="escrito" class="cti__comparacion">
        <div class="cti__comp-row">
          <span class="cti__comp-lbl">Debería haber</span>
          <span class="cti__comp-num">{{ fmt(item.mostrador) }} {{ item.unidad }}</span>
        </div>
        <div class="cti__comp-row">
          <span class="cti__comp-lbl">Contaste</span>
          <span class="cti__comp-num">{{ fmt(contado) }} {{ item.unidad }}</span>
        </div>
        <div class="cti__comp-row cti__comp-row--dif">
          <span class="cti__comp-lbl">Diferencia</span>
          <span class="cti__comp-dif" :class="diferencia === 0 ? 'is-ok' : 'is-dif'">
            {{ signo }}{{ fmt(Math.abs(diferencia)) }} {{ item.unidad }}
          </span>
        </div>
        <p v-if="diferencia === 0" class="cti__cuadra">Cuadra. Se deja igual y seguís.</p>
      </div>

      <!-- A diferencia del conteo de APERTURA —que sólo corre el punto de partida, porque lo que
           falta puede estar en el depósito— acá el producto estaba sobre la mesa: la diferencia
           ajusta el inventario. Por eso el motivo es obligatorio. -->
      <label v-if="escrito && diferencia !== 0" class="cti__campo cti__campo--motivo">
        <span class="cti__campo-lbl">Qué pasó</span>
        <input v-model="motivo" type="text" class="cti__input cti__input--texto"
               placeholder="Ej: se fraccionó para prerolls" />
      </label>
      <p v-if="escrito && diferencia !== 0" class="cti__nota">
        Se ajusta el inventario y queda anotado con tu nombre. La merma es inevitable: se mide
        para saber cuánta hay y dónde, no para señalar a nadie.
      </p>

      <div class="cti__acc">
        <button class="cti__btn cti__btn--ghost" @click="$emit('cerrar')">Cancelar</button>
        <button class="cti__btn cti__btn--primary" :disabled="!puedeConfirmar" @click="confirmar">
          {{ guardando ? 'Guardando…' : 'Registrar conteo' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
// CONTAR UN PRODUCTO SIN CERRAR LA CAJA.
//
// Cerrar y reabrir sigue siendo el arqueo completo, pero con quince frascos son veinte minutos:
// un control que cuesta eso no se hace dos veces por día, y el que no se hace no controla nada.
//
// El servicio (`Mostradores::Contar`) existía desde el rediseño y NO TENÍA PANTALLA: el único
// camino para verificar un frasco era el arqueo entero. En el teléfono, que es donde más se
// atiende, eso es quince campos en un modal.
import { ref, computed, onMounted } from 'vue'
import { formaLabel } from '../../lib/formatters.js'

const props = defineProps({
  // Una fila de la mesa: { stock_id, forma, genetica, numero, unidad, mostrador }
  item:      { type: Object, required: true },
  guardando: { type: Boolean, default: false },
})
const emit = defineEmits(['cerrar', 'confirmar'])

const contado = ref(null)
const motivo  = ref('')
const campo   = ref(null)

const fmt = (n) => Number(n ?? 0).toLocaleString('es-AR', { maximumFractionDigits: 1 })

const escrito = computed(() =>
  contado.value !== null && contado.value !== '' && !Number.isNaN(Number(contado.value))
)
const diferencia = computed(() =>
  escrito.value ? Math.round((Number(contado.value) - Number(props.item.mostrador || 0)) * 100) / 100 : 0
)
const signo = computed(() => (diferencia.value > 0 ? '+' : diferencia.value < 0 ? '−' : ''))

// Con diferencia, el motivo es obligatorio: el backend lo rechaza igual, y ofrecer el botón para
// que rebote es el peor error posible.
const puedeConfirmar = computed(() =>
  !props.guardando && escrito.value && Number(contado.value) >= 0 &&
  (diferencia.value === 0 || motivo.value.trim().length > 0)
)

function confirmar () {
  emit('confirmar', {
    stock_id: props.item.stock_id,
    contado: Number(contado.value),
    motivo: motivo.value.trim() || undefined,
  })
}

onMounted(() => campo.value?.focus())
</script>

<style scoped>
.cti__back {
  position: fixed; inset: 0; background: rgba(15, 42, 30, .45);
  display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 1000;
}
.cti__modal {
  background: #fff; border-radius: 14px; padding: 24px;
  width: 100%; max-width: 420px; max-height: 88vh; overflow-y: auto;
  display: flex; flex-direction: column; gap: 14px;
}
.cti__title {
  font-family: var(--font-display); font-size: var(--fs-18); font-weight: 700;
  color: var(--c-leaf-900); margin: 0;
}
.cti__sub { margin: 0; font-size: var(--fs-13); color: var(--c-ink-500); }

.cti__campo { display: flex; flex-direction: column; gap: 6px; }
.cti__campo-lbl { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
.cti__campo-input { display: inline-flex; align-items: center; gap: 8px; }
/* El motivo se destaca porque hay que completarlo, no porque haya pasado algo malo. */
.cti__campo--motivo .cti__campo-lbl { color: var(--c-amber-500); }

.cti__input {
  border: 1px solid var(--c-slate-300); border-radius: 9px; padding: 11px 12px;
  font-size: var(--fs-18); font-family: var(--font-mono); width: 130px; text-align: right;
  background: #fff; color: var(--c-ink-900);
}
.cti__input:focus { outline: 2px solid var(--c-leaf-300); outline-offset: 1px; border-color: var(--c-leaf-500); }
.cti__input--texto { width: 100%; text-align: left; font-size: var(--fs-14); font-family: var(--font-ui); }
.cti__unidad { font-size: var(--fs-14); color: var(--c-ink-500); }

.cti__comparacion {
  background: var(--c-leaf-50); border-radius: 11px; padding: 13px 15px;
  display: flex; flex-direction: column; gap: 5px;
}
.cti__comp-row { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; }
.cti__comp-row--dif { border-top: 1px solid var(--c-leaf-300); padding-top: 8px; margin-top: 3px; }
.cti__comp-lbl { font-size: var(--fs-13); color: var(--c-ink-700); }
.cti__comp-num { font-family: var(--font-mono); font-size: var(--fs-14); color: var(--c-ink-900); }
.cti__comp-dif { font-family: var(--font-mono); font-size: var(--fs-16); font-weight: 700; }
.cti__comp-dif.is-ok  { color: var(--c-leaf-600); }
/* Ámbar y no rojo: una diferencia es un dato que se anota, no una falta que alguien explica. */
.cti__comp-dif.is-dif { color: var(--c-amber-500); }
.cti__cuadra { margin: 0; font-size: var(--fs-13); font-weight: 600; color: var(--c-leaf-600); }
.cti__nota   { margin: 0; font-size: var(--fs-12); color: var(--c-ink-500); }

.cti__acc { display: flex; gap: 10px; justify-content: flex-end; }
.cti__btn {
  border-radius: 9px; padding: 10px 18px; font-size: var(--fs-14); font-weight: 600;
  cursor: pointer; border: 1px solid transparent;
}
.cti__btn:disabled { opacity: .5; cursor: not-allowed; }
.cti__btn--primary { background: var(--c-leaf-800); color: #fff; }
.cti__btn--primary:not(:disabled):hover { background: var(--c-leaf-900); }
.cti__btn--ghost   { background: #fff; color: var(--c-ink-700); border-color: var(--c-slate-300); }
.cti__btn--ghost:not(:disabled):hover { background: var(--c-slate-50); }
</style>
