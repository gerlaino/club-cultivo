<template>
  <!-- El formulario de un gasto: qué, cuánto, de qué tipo, cuándo, cómo. Lo usan el teléfono
       (dentro de una hoja) y el escritorio (dentro de un modal): mismos campos, misma oración
       final que dice qué va a pasar. -->
  <form class="gf" @submit.prevent="$emit('guardar')">
    <label class="gf__field">
      <span class="gf__label">Qué compraste</span>
      <input v-model.trim="f.descripcion" type="text" class="gf__input" placeholder="Sustrato 50 L" maxlength="120" required />
    </label>
    <label class="gf__field">
      <span class="gf__label">Cuánto</span>
      <span class="gf__input-row">
        <span class="gf__input-u">$</span>
        <input v-model.number="f.monto_ars" type="number" inputmode="decimal" step="0.01" min="0.01" class="gf__input gf__input--num" placeholder="0" required />
      </span>
    </label>
    <label class="gf__field">
      <span class="gf__label">De qué tipo</span>
      <select v-model="f.categoria_contable_id" class="gf__input" required>
        <option value="" disabled>Elegí…</option>
        <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nombre }}</option>
      </select>
    </label>
    <div class="gf__row-2">
      <label class="gf__field">
        <span class="gf__label">Cuándo</span>
        <input v-model="f.fecha" type="date" class="gf__input" :max="hoy" required />
      </label>
      <label class="gf__field">
        <span class="gf__label">Cómo pagaste</span>
        <select v-model="f.medio_pago" class="gf__input">
          <option value="efectivo">Efectivo</option>
          <option value="transferencia">Transferencia</option>
          <option value="mercado_pago">Mercado Pago</option>
        </select>
      </label>
    </div>
    <label class="gf__field">
      <span class="gf__label">Para un lote <span class="gf__opt">(opcional)</span></span>
      <select v-model="f.lote_id" class="gf__input">
        <option :value="null">Del cultivo en general</option>
        <option v-for="l in lotes" :key="l.id" :value="l.id">{{ l.codigo }} · {{ l.genetica?.nombre || l.strain || '' }}</option>
      </select>
    </label>
    <p v-if="error" class="gf__error">{{ error }}</p>
    <p v-if="f.monto_ars > 0 && f.descripcion" class="gf__resumen">
      Salen <b>{{ ars(f.monto_ars) }}</b> por {{ f.descripcion }}<template v-if="loteElegido">, a cuenta del lote {{ loteElegido.codigo }}</template>.
      <template v-if="loteElegido"> Entra en su costo por gramo.</template>
    </p>
    <div class="gf__actions">
      <button type="button" class="gf__btn gf__btn--ghost" @click="$emit('cancelar')">Cancelar</button>
      <button type="submit" class="gf__btn gf__btn--primary" :disabled="guardando || !f.categoria_contable_id">
        {{ guardando ? 'Guardando…' : (f.id ? 'Guardar' : 'Anotar') }}
      </button>
    </div>
  </form>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  form:       { type: Object,  required: true },
  categorias: { type: Array,   default: () => [] },
  lotes:      { type: Array,   default: () => [] },
  hoy:        { type: String,  required: true },
  error:      { type: String,  default: null },
  guardando:  { type: Boolean, default: false },
})
defineEmits(['guardar', 'cancelar'])

// El formulario ES el estado del composable (un `reactive` que el padre le presta): se escribe
// acá a propósito, para que el teléfono y el escritorio editen el mismo objeto.
const f = props.form
const loteElegido = computed(() => props.lotes.find(l => l.id === f.lote_id))
function ars(n) { return '$' + Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 0 }) }
</script>

<style scoped>
.gf { display: flex; flex-direction: column; gap: .8rem; padding-bottom: .5rem; }
.gf__field { display: flex; flex-direction: column; gap: .3rem; min-width: 0; }
.gf__row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.gf__label { font-size: .76rem; font-weight: 700; color: var(--c-slate-600); text-transform: uppercase; letter-spacing: .04em; }
.gf__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
.gf__input { width: 100%; padding: .7rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; font: inherit; font-size: 1rem; background: #fff; min-width: 0; }
.gf__input:focus { outline: none; border-color: var(--c-leaf-500, #5A8A72); }
.gf__input-row { display: flex; align-items: center; gap: .5rem; }
.gf__input--num { font-size: 1.5rem; font-weight: 700; }
.gf__input-u { font-size: 1.1rem; font-weight: 700; color: var(--c-slate-500); }
.gf__error { margin: 0; font-size: .82rem; color: #b91c1c; }
.gf__resumen { margin: 0; font-size: .85rem; color: var(--c-slate-700); }
.gf__actions { display: flex; gap: .5rem; }
.gf__btn { flex: 1; padding: .8rem; border-radius: 12px; font-size: .95rem; font-weight: 700; border: none; cursor: pointer; }
.gf__btn--ghost { background: var(--c-slate-100); color: var(--c-slate-700); }
.gf__btn--primary { background: var(--c-leaf-800, #1A3D2E); color: #fff; }
.gf__btn--primary:disabled { opacity: .5; }
</style>
