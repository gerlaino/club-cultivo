<template>
  <!-- El formulario de un gasto. Lo usan el teléfono (dentro de una hoja) y el escritorio
       (dentro de un modal): mismos campos, misma oración final que dice qué va a pasar.
       Lo de todos los días arriba (qué, cuánto, tipo, cuándo); lo que hace que el gasto sirva
       después —cuánto salió el litro, a quién se lo compró, el comprobante— plegado abajo. -->
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

    <!-- El tipo: se elige, y si no está se crea acá mismo. Mandarlo al catálogo del escritorio
         para agregar «Nutrientes» es perder el gasto que estaba anotando. -->
    <div class="gf__field">
      <span class="gf__label">De qué tipo</span>
      <template v-if="!creandoTipo">
        <span class="gf__input-row">
          <select v-model="f.categoria_contable_id" class="gf__input" required>
            <option value="" disabled>Elegí…</option>
            <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nombre }}</option>
          </select>
          <button type="button" class="gf__mini" @click="creandoTipo = true; nuevoTipo = ''">+ Nuevo</button>
        </span>
      </template>
      <template v-else>
        <span class="gf__input-row">
          <input v-model.trim="nuevoTipo" type="text" class="gf__input" placeholder="Nutrientes, Luz, Carpa…" maxlength="60" @keydown.enter.prevent="confirmarTipo" />
          <button type="button" class="gf__mini gf__mini--ok" :disabled="!nuevoTipo || creando" @click="confirmarTipo">{{ creando ? '…' : 'Crear' }}</button>
          <button type="button" class="gf__mini" @click="creandoTipo = false">Cancelar</button>
        </span>
        <span v-if="errorTipo" class="gf__error">{{ errorTipo }}</span>
      </template>
    </div>

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

    <!-- Es un nutriente: el gasto además carga la cantidad en Cultivo → Nutrientes y recetas,
         para que al regar con receta se descuente y avise cuando quede poco. -->
    <label class="gf__check">
      <input v-model="f.es_insumo" type="checkbox" />
      <span>Es un nutriente o insumo del cultivo <span class="gf__opt">(se suma a lo que tenés)</span></span>
    </label>
    <div v-if="f.es_insumo" class="gf__insumo">
      <label class="gf__field">
        <span class="gf__label">¿Cuál?</span>
        <select v-model="f.insumo_id" class="gf__input">
          <option :value="null">Uno nuevo…</option>
          <option v-for="i in insumos" :key="i.id" :value="i.id">{{ i.nombre }} · quedan {{ Number(i.stock_actual).toLocaleString('es-AR') }} {{ ({ mililitro: 'ml', gramo: 'g' })[i.unidad_medida] || i.unidad_medida }}</option>
        </select>
      </label>
      <div v-if="!f.insumo_id" class="gf__row-2">
        <label class="gf__field">
          <span class="gf__label">Nombre</span>
          <input v-model.trim="f.insumo_nombre" type="text" class="gf__input" :placeholder="f.descripcion || 'Bio-Grow'" maxlength="80" />
        </label>
        <label class="gf__field">
          <span class="gf__label">Se mide en</span>
          <select v-model="f.insumo_unidad" class="gf__input">
            <option value="mililitro">mililitros</option>
            <option value="gramo">gramos</option>
          </select>
        </label>
      </div>
      <label class="gf__field">
        <span class="gf__label">Cantidad que compraste ({{ unidadInsumo }})</span>
        <input v-model.number="f.cantidad" type="number" inputmode="decimal" step="1" min="0" class="gf__input" placeholder="1000" required />
        <span v-if="unitario" class="gf__hint">{{ unitario }}</span>
      </label>
    </div>

    <button type="button" class="gf__mas" @click="masDetalles = !masDetalles">
      <i class="bi" :class="masDetalles ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
      {{ masDetalles ? 'Menos detalles' : 'Más detalles' }}
      <span v-if="!masDetalles && resumenDetalles" class="gf__mas-hint">· {{ resumenDetalles }}</span>
    </button>
    <div v-if="masDetalles" class="gf__detalles">
      <div class="gf__row-2">
        <label class="gf__field">
          <span class="gf__label">Cantidad <span class="gf__opt">(para el precio unitario)</span></span>
          <span class="gf__input-row">
            <input v-model.number="f.cantidad" type="number" inputmode="decimal" step="0.01" min="0" class="gf__input" placeholder="50" />
            <input v-model.trim="f.unidad" type="text" class="gf__input gf__input--corto" placeholder="L, kg, un" maxlength="10" />
          </span>
          <span v-if="unitario" class="gf__hint">{{ unitario }}</span>
        </label>
        <label class="gf__field">
          <span class="gf__label">A quién <span class="gf__opt">(proveedor)</span></span>
          <input v-model.trim="f.proveedor" type="text" class="gf__input" placeholder="Grow shop del barrio" maxlength="120" />
        </label>
      </div>
      <div class="gf__row-2">
        <label class="gf__field">
          <span class="gf__label">Comprobante</span>
          <select v-model="f.comprobante_tipo" class="gf__input">
            <option value="">Sin comprobante</option>
            <option value="ticket">Ticket</option>
            <option value="factura_b">Factura B</option>
            <option value="factura_a">Factura A</option>
            <option value="recibo">Recibo</option>
          </select>
        </label>
        <label class="gf__field">
          <span class="gf__label">Número</span>
          <input v-model.trim="f.comprobante_numero" type="text" class="gf__input" placeholder="0001-00001234" maxlength="40" :disabled="!f.comprobante_tipo" />
        </label>
      </div>
      <label class="gf__field">
        <span class="gf__label">Nota</span>
        <input v-model.trim="f.notas" type="text" class="gf__input" placeholder="Lo que quieras acordarte" maxlength="200" />
      </label>
    </div>

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
import { ref, computed } from 'vue'

const props = defineProps({
  form:       { type: Object,   required: true },
  categorias: { type: Array,    default: () => [] },
  lotes:      { type: Array,    default: () => [] },
  insumos:    { type: Array,    default: () => [] },
  hoy:        { type: String,   required: true },
  error:      { type: String,   default: null },
  guardando:  { type: Boolean,  default: false },
  // Crea un tipo nuevo y devuelve la categoría; la provee el composable.
  crearTipo:  { type: Function, default: null },
})
defineEmits(['guardar', 'cancelar'])

// El formulario ES el estado del composable (un `reactive` que el padre le presta): se escribe
// acá a propósito, para que el teléfono y el escritorio editen el mismo objeto.
const f = props.form
const loteElegido = computed(() => props.lotes.find(l => l.id === f.lote_id))
const unidadInsumo = computed(() => {
  const u = f.insumo_id ? props.insumos.find(i => i.id === f.insumo_id)?.unidad_medida : f.insumo_unidad
  return u === 'gramo' ? 'g' : (u === 'mililitro' ? 'ml' : (u || ''))
})
function ars(n) { return '$' + Number(n || 0).toLocaleString('es-AR', { maximumFractionDigits: 0 }) }

// ── Tipo nuevo, sin salir del gasto ──
const creandoTipo = ref(false)
const nuevoTipo   = ref('')
const creando     = ref(false)
const errorTipo   = ref(null)
async function confirmarTipo() {
  if (!nuevoTipo.value || !props.crearTipo) return
  creando.value = true
  errorTipo.value = null
  try {
    const cat = await props.crearTipo(nuevoTipo.value)
    f.categoria_contable_id = cat.id
    creandoTipo.value = false
  } catch (e) {
    errorTipo.value = e?.response?.data?.errors?.join(', ') || e?.response?.data?.error || 'No se pudo crear'
  } finally { creando.value = false }
}

// ── Más detalles ──
// Abierto de entrada si al editar ya había algo cargado ahí: esconderlo sería esconder datos.
const masDetalles = ref(!!(f.proveedor || f.cantidad || f.comprobante_tipo || f.notas))
const unitario = computed(() => {
  if (!(f.cantidad > 0) || !(f.monto_ars > 0)) return ''
  return `${ars(f.monto_ars / f.cantidad)} por ${f.unidad || 'unidad'}`
})
const resumenDetalles = computed(() => [
  f.cantidad > 0 ? `${f.cantidad} ${f.unidad || ''}`.trim() : null,
  f.proveedor || null,
  f.comprobante_tipo || null,
].filter(Boolean).join(' · '))
</script>

<style scoped>
.gf { display: flex; flex-direction: column; gap: .8rem; padding-bottom: .5rem; }
.gf__field { display: flex; flex-direction: column; gap: .3rem; min-width: 0; }
.gf__row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.gf__label { font-size: .76rem; font-weight: 700; color: var(--c-slate-600); text-transform: uppercase; letter-spacing: .04em; }
.gf__opt { font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--c-slate-400); }
.gf__input { width: 100%; padding: .7rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; font: inherit; font-size: 1rem; background: #fff; min-width: 0; }
.gf__input:focus { outline: none; border-color: var(--c-leaf-500, #5A8A72); }
.gf__input:disabled { background: var(--c-slate-50, #f8fafc); color: var(--c-slate-400); }
.gf__input--corto { flex: 0 0 6.5rem; }
.gf__input-row { display: flex; align-items: center; gap: .5rem; }
.gf__input--num { font-size: 1.5rem; font-weight: 700; }
.gf__input-u { font-size: 1.1rem; font-weight: 700; color: var(--c-slate-500); }
.gf__mini { flex-shrink: 0; padding: .55rem .7rem; border-radius: 9px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); font-size: .8rem; font-weight: 700; cursor: pointer; white-space: nowrap; }
.gf__mini--ok { background: var(--c-leaf-800, #1A3D2E); color: #fff; border-color: transparent; }
.gf__mini:disabled { opacity: .5; }
.gf__hint { font-size: .78rem; color: var(--c-slate-500); }
.gf__mas { align-self: flex-start; display: inline-flex; align-items: center; gap: .35rem; background: none; border: none; padding: 0; color: var(--c-leaf-700, #2D7D46); font: inherit; font-size: .84rem; font-weight: 700; cursor: pointer; }
.gf__mas-hint { font-weight: 500; color: var(--c-slate-500); }
.gf__detalles { display: flex; flex-direction: column; gap: .8rem; padding: .8rem; background: var(--c-slate-50, #f8fafc); border-radius: 12px; }
.gf__error { margin: 0; font-size: .82rem; color: #b91c1c; }
.gf__resumen { margin: 0; font-size: .85rem; color: var(--c-slate-700); }
.gf__actions { display: flex; gap: .5rem; }
.gf__btn { flex: 1; padding: .8rem; border-radius: 12px; font-size: .95rem; font-weight: 700; border: none; cursor: pointer; }
.gf__btn--ghost { background: var(--c-slate-100); color: var(--c-slate-700); }
.gf__btn--primary { background: var(--c-leaf-800, #1A3D2E); color: #fff; }
.gf__btn--primary:disabled { opacity: .5; }
.gf__check { display: flex; align-items: center; gap: .5rem; font-size: .88rem; font-weight: 600; cursor: pointer; }
.gf__check input { width: 18px; height: 18px; accent-color: var(--c-leaf-600, #3F6452); }
.gf__insumo { display: flex; flex-direction: column; gap: .6rem; padding: .7rem .8rem; border: 1px dashed var(--c-ink-300, #d1d5db); border-radius: 10px; background: var(--c-leaf-50, #F4F8F5); }
</style>
