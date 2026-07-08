<script setup>
// Depósito de insumos (Bloque 2): stock valorizado + compra → consumo → costo por lote.
import { ref, computed, onMounted } from 'vue'
import { useInsumosStore } from '../../stores/insumos.js'
import { listLotes, listSalas } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const store = useInsumosStore()
const toast = useToast()
const { confirm } = useConfirm()

const UNIDADES = ['unidad', 'litro', 'mililitro', 'kilogramo', 'gramo', 'bolsa', 'metro', 'otro']
const lotes = ref([])
const salas = ref([])

onMounted(async () => {
  await store.fetch()
  listLotes({ estado: 'activos' }).then(r => { lotes.value = r.data?.lotes || r.data || [] }).catch(() => {})
  listSalas().then(r => { salas.value = r.data || [] }).catch(() => {})
})

// ── Nuevo insumo ──────────────────────────────────────────────
const nuevoForm = ref(null)
function nuevoInsumo() { nuevoForm.value = { nombre: '', unidad_medida: 'unidad', stock_minimo: 0 } }
async function guardarNuevo() {
  if (!nuevoForm.value.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  try {
    await store.crear({ ...nuevoForm.value, nombre: nuevoForm.value.nombre.trim() })
    toast.success('Insumo creado'); nuevoForm.value = null
  } catch { toast.error(store.saveError) }
}

// ── Comprar ───────────────────────────────────────────────────
const compraForm = ref(null) // { insumo, cantidad, costo_total_ars, proveedor }
function abrirCompra(i) { compraForm.value = { insumo: i, cantidad: null, costo_total_ars: null, proveedor: '' } }
async function confirmarCompra() {
  const f = compraForm.value
  if (!(f.cantidad > 0) || !(f.costo_total_ars > 0)) { toast.warning('Completá cantidad y costo'); return }
  try {
    await store.comprar(f.insumo.id, { cantidad: f.cantidad, costo_total_ars: f.costo_total_ars, proveedor: f.proveedor || null })
    toast.success('Compra registrada'); compraForm.value = null
  } catch { toast.error(store.saveError) }
}

// ── Consumir ──────────────────────────────────────────────────
const consumoForm = ref(null) // { insumo, cantidad, lote_id, sala_id }
function abrirConsumo(i) { consumoForm.value = { insumo: i, cantidad: null, lote_id: null, sala_id: null, notas: '' } }
async function confirmarConsumo() {
  const f = consumoForm.value
  if (!(f.cantidad > 0)) { toast.warning('Poné la cantidad usada'); return }
  if (f.cantidad > f.insumo.stock_actual) { toast.warning('No hay stock suficiente'); return }
  try {
    await store.consumir(f.insumo.id, { cantidad: f.cantidad, lote_id: f.lote_id, sala_id: f.sala_id, notas: f.notas || null })
    toast.success('Consumo imputado'); consumoForm.value = null
  } catch { toast.error(store.saveError) }
}

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
function stockPct(i) {
  if (!i.stock_minimo) return i.stock_actual > 0 ? 100 : 0
  return Math.min(100, Math.round((i.stock_actual / (i.stock_minimo * 2)) * 100))
}
</script>

<template>
  <div class="ins">
    <header class="ins__head">
      <div>
        <h1>Depósito de insumos</h1>
        <p>Comprá a granel; imputá el consumo al lote donde se usa. Así sale el costo real de producción.</p>
      </div>
      <div class="ins__head-right">
        <div class="ins__valor">
          <span>Valorizado</span>
          <strong>{{ fmt(store.valorizadoTotal) }}</strong>
        </div>
        <button class="btn btn--primary" @click="nuevoInsumo">+ Insumo</button>
      </div>
    </header>

    <form v-if="nuevoForm" class="ins__form" @submit.prevent="guardarNuevo">
      <input v-model.trim="nuevoForm.nombre" class="inp" placeholder="Nombre (ej: Fertilizante base)" maxlength="60" />
      <select v-model="nuevoForm.unidad_medida" class="inp">
        <option v-for="u in UNIDADES" :key="u" :value="u">{{ u }}</option>
      </select>
      <label class="ins__min">Stock mínimo <input v-model.number="nuevoForm.stock_minimo" type="number" min="0" step="any" class="inp inp--sm" /></label>
      <div class="ins__form-actions">
        <button type="button" class="btn" @click="nuevoForm = null">Cancelar</button>
        <button type="submit" class="btn btn--primary" :disabled="store.saving">Crear</button>
      </div>
    </form>

    <div v-if="store.loading" class="ins__loading">Cargando depósito…</div>
    <div v-else-if="!store.items.length" class="ins__empty">Todavía no hay insumos. Creá el primero con “+ Insumo”.</div>

    <ul v-else class="ins__list">
      <li v-for="i in store.items" :key="i.id" class="ins__item" :class="{ 'ins__item--low': i.stock_bajo }">
        <div class="ins__item-main">
          <span class="ins__name">{{ i.nombre }}</span>
          <div class="ins__meter"><i :style="{ width: stockPct(i) + '%', background: i.stock_bajo ? '#dc2626' : '#1b5e20' }"></i></div>
        </div>
        <div class="ins__stats">
          <span class="ins__stock" :class="{ low: i.stock_bajo }">{{ i.stock_actual }} {{ i.unidad_medida }}</span>
          <small>{{ fmt(i.costo_promedio_ars) }}/u · {{ fmt(i.valorizado_ars) }}</small>
        </div>
        <div class="ins__actions">
          <button class="btn btn--sm" @click="abrirCompra(i)">Comprar</button>
          <button class="btn btn--sm btn--primary" @click="abrirConsumo(i)" :disabled="i.stock_actual <= 0">Consumir</button>
        </div>
      </li>
    </ul>

    <!-- Modal comprar -->
    <div v-if="compraForm" class="ins__ov" @click.self="compraForm = null">
      <div class="ins__modal">
        <h3>Comprar — {{ compraForm.insumo.nombre }}</h3>
        <p class="ins__modal-hint">Entra al stock y recalcula el costo promedio. Genera el egreso en el libro.</p>
        <label class="fld">Cantidad ({{ compraForm.insumo.unidad_medida }})<input v-model.number="compraForm.cantidad" type="number" min="0" step="any" class="inp" /></label>
        <label class="fld">Costo total<input v-model.number="compraForm.costo_total_ars" type="number" min="0" step="any" class="inp" placeholder="$" /></label>
        <label class="fld">Proveedor (opcional)<input v-model.trim="compraForm.proveedor" class="inp" /></label>
        <div class="ins__form-actions">
          <button class="btn" @click="compraForm = null">Cancelar</button>
          <button class="btn btn--primary" :disabled="store.saving" @click="confirmarCompra">Registrar compra</button>
        </div>
      </div>
    </div>

    <!-- Modal consumir -->
    <div v-if="consumoForm" class="ins__ov" @click.self="consumoForm = null">
      <div class="ins__modal">
        <h3>Registrar consumo — {{ consumoForm.insumo.nombre }}</h3>
        <p class="ins__modal-hint">Disponible: {{ consumoForm.insumo.stock_actual }} {{ consumoForm.insumo.unidad_medida }}. Imputa el costo al lote/sala.</p>
        <label class="fld">Cantidad usada<input v-model.number="consumoForm.cantidad" type="number" min="0" step="any" class="inp" /></label>
        <label class="fld">Lote (opcional)
          <select v-model="consumoForm.lote_id" class="inp">
            <option :value="null">— Sin lote —</option>
            <option v-for="l in lotes" :key="l.id" :value="l.id">{{ l.codigo || ('Lote ' + l.id) }}</option>
          </select>
        </label>
        <label class="fld">Sala (opcional)
          <select v-model="consumoForm.sala_id" class="inp">
            <option :value="null">— Sin sala —</option>
            <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>
        <div class="ins__form-actions">
          <button class="btn" @click="consumoForm = null">Cancelar</button>
          <button class="btn btn--primary" :disabled="store.saving" @click="confirmarConsumo">Imputar consumo</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ins { padding: var(--sp-6, 24px); max-width: 900px; margin: 0 auto; }
.ins__head { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--sp-4, 16px); flex-wrap: wrap; }
.ins__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: #0f172a; margin: 0; }
.ins__head p { color: #64748b; margin: 4px 0 0; font-size: var(--fs-14, 14px); max-width: 52ch; }
.ins__head-right { display: flex; align-items: center; gap: var(--sp-3, 12px); }
.ins__valor { text-align: right; }
.ins__valor span { display: block; font-size: var(--fs-12, 12px); color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }
.ins__valor strong { font-size: var(--fs-20, 20px); color: #0f172a; }

.ins__form { display: flex; align-items: center; gap: var(--sp-2, 8px); background: #f8fafc; border: 1px solid #f1f5f9; border-radius: var(--r-md, 10px); padding: var(--sp-3, 12px); margin-top: var(--sp-4, 16px); flex-wrap: wrap; }
.ins__min { display: flex; align-items: center; gap: 6px; font-size: var(--fs-13, 13px); color: #475569; }
.ins__form-actions { display: flex; gap: var(--sp-2, 8px); margin-left: auto; }

.ins__loading, .ins__empty { color: #64748b; padding: var(--sp-8, 32px); text-align: center; }

.ins__list { list-style: none; margin: var(--sp-5, 20px) 0 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.ins__item { display: grid; grid-template-columns: 1fr auto auto; gap: var(--sp-4, 16px); align-items: center; background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-md, 10px); padding: var(--sp-3, 12px) var(--sp-4, 16px); }
.ins__item--low { border-color: #fecaca; }
.ins__item-main { min-width: 0; }
.ins__name { font-weight: 600; color: #0f172a; font-size: var(--fs-15, 15px); }
.ins__meter { height: 6px; background: #f1f5f9; border-radius: 4px; overflow: hidden; margin-top: 8px; }
.ins__meter i { display: block; height: 100%; border-radius: 4px; }
.ins__stats { text-align: right; }
.ins__stock { font-weight: 650; color: #0f172a; font-variant-numeric: tabular-nums; }
.ins__stock.low { color: #dc2626; }
.ins__stats small { display: block; color: #94a3b8; font-size: var(--fs-12, 12px); }
.ins__actions { display: flex; gap: 6px; }

.ins__ov { position: fixed; inset: 0; background: rgba(20,25,20,.45); display: grid; place-items: center; z-index: 1000; padding: 16px; }
.ins__modal { background: var(--c-paper, #fff); border-radius: var(--r-lg, 14px); padding: var(--sp-5, 20px); width: 100%; max-width: 380px; box-shadow: var(--sh-3, 0 20px 50px rgba(0,0,0,.25)); }
.ins__modal h3 { margin: 0 0 4px; font-size: var(--fs-18, 18px); color: #0f172a; }
.ins__modal-hint { color: #64748b; font-size: var(--fs-13, 13px); margin: 0 0 var(--sp-4, 16px); }
.fld { display: flex; flex-direction: column; gap: 4px; font-size: var(--fs-13, 13px); color: #475569; margin-bottom: var(--sp-3, 12px); }

.inp { padding: 8px 10px; border: 1px solid #e2e8f0; border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: #0f172a; }
.inp--sm { width: 90px; }
.btn { border: 1px solid #e2e8f0; background: var(--c-paper, #fff); color: #1e293b; border-radius: var(--r-sm, 8px); padding: 7px 13px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.btn--sm { padding: 5px 11px; font-size: var(--fs-12, 12px); }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
