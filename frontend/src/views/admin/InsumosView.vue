<script setup>
// Depósito de insumos de cultivo (Producción): stock valorizado + compra → consumo imputado a
// lote(s)/sala + aviso de reposición. Consumo repartible entre varios lotes en partes iguales.
import { ref, computed, onMounted, watch } from 'vue'
import { useInsumosStore } from '../../stores/insumos.js'
import { useSedeStore } from '../../stores/sede.js'
import { listLotes, listSalas, listCategoriasContables } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import DepositoSalon from './DepositoSalon.vue'

const store = useInsumosStore()
const sede  = useSedeStore()
const toast = useToast()

const UNIDADES = ['unidad', 'litro', 'mililitro', 'kilogramo', 'gramo', 'bolsa', 'metro', 'otro']
const lotes = ref([])
const salas = ref([])
const categorias = ref([]) // árbol de categorías (para el alta y las etiquetas de grupo)

// Comportamiento contable que alimenta cada depósito (la categoría es la que manda).
const COMP_DE_TAB = { cultivo: ['insumo'], general: ['insumo_general'] }
// Subcategorías (u hojas madre) elegibles al crear un insumo en la familia activa.
const categoriasDelTab = computed(() => {
  const comps = COMP_DE_TAB[tipoActivo.value] || []
  const out = []
  for (const m of categorias.value) {
    const subs = m.subcategorias || []
    for (const s of subs) if (comps.includes(s.comportamiento_efectivo)) out.push({ id: s.id, label: `${m.nombre} › ${s.nombre}` })
    if (!subs.length && comps.includes(m.comportamiento_efectivo)) out.push({ id: m.id, label: m.nombre })
  }
  return out
})
// Insumos agrupados por categoría (madre › subcategoría), como el árbol contable.
const grupos = computed(() => {
  const map = {}
  for (const i of store.items) {
    const c = i.categoria
    const label = c ? (c.sub_nombre ? `${c.madre_nombre} › ${c.sub_nombre}` : c.madre_nombre) : 'Sin categoría'
    ;(map[label] ||= []).push(i)
  }
  return Object.entries(map)
    .map(([label, items]) => ({ label, items, valorizado: items.reduce((a, i) => a + (i.valorizado_ars || 0), 0) }))
    .sort((a, b) => (a.label === 'Sin categoría' ? 1 : b.label === 'Sin categoría' ? -1 : a.label.localeCompare(b.label)))
})

// El depósito vive por sede: cada ítem ocupa un espacio físico en una sede. Cuando hay ≥2 sedes
// mostramos el contexto (badge de sede, elección de sede en el alta, y transferencia entre sedes).
const multiSede = computed(() => sede.sedes.length > 1)
const otrasSedes = computed(() => sede.sedes.filter(s => s.id !== sede.sedeId))

// Solapas de depósito por sede. Cada tipo de sede tiene distintos depósitos:
//   producción → Cultivo + General   ·   social → General + Salón   ·   mixta → las 3
// El Salón (deposito_bar, vendible) es un módulo aparte (DepositoSalon). Consolidado = todas.
const currentTipo = computed(() => sede.sedeActual?.tipo) // undefined = consolidado (todas las sedes)
const TABS_ALL = [
  { tipo: 'cultivo', label: 'Cultivo', hint: 'Fertilizantes, sustrato… se consumen imputando el costo al lote.',       sedeTipos: ['produccion', 'mixta'] },
  { tipo: 'general', label: 'General', hint: 'Insumos del club (limpieza, administración). Se consumen como gasto.',    sedeTipos: ['produccion', 'social', 'mixta'] },
  { tipo: 'salon',   label: 'Salón',   hint: 'Mercadería del bar: stock con costo, valorizado y alertas de reposición.', sedeTipos: ['social', 'mixta'] },
]
const TABS = computed(() => {
  const t = currentTipo.value
  return t ? TABS_ALL.filter(tab => tab.sedeTipos.includes(t)) : TABS_ALL
})
const tipoActivo = ref('cultivo')
const tabActual  = computed(() => TABS.value.find(t => t.tipo === tipoActivo.value) || TABS.value[0])
const esGeneral  = computed(() => tipoActivo.value === 'general')
const esSalon    = computed(() => tipoActivo.value === 'salon')

// Si al cambiar de sede la solapa activa ya no existe, cae a la primera disponible.
watch(TABS, (tabs) => {
  if (!tabs.some(t => t.tipo === tipoActivo.value)) tipoActivo.value = tabs[0]?.tipo || 'cultivo'
})

async function recargar() {
  if (esSalon.value) return // el depósito del salón se carga en su propio componente
  await store.fetch({ sede_id: sede.sedeParam, tipo: tipoActivo.value })
}

onMounted(async () => {
  if (!sede.loaded) await sede.fetchSedes()
  await recargar()
  listLotes({ estado: 'activos' }).then(r => { lotes.value = r.data?.lotes || r.data || [] }).catch(() => {})
  listSalas().then(r => { salas.value = r.data || [] }).catch(() => {})
  listCategoriasContables().then(r => { categorias.value = r.data || [] }).catch(() => {})
})

// Al cambiar la sede o la familia activa, el depósito se re-filtra.
watch([() => sede.sedeId, tipoActivo], recargar)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
function stockPct(i) {
  if (!i.stock_minimo) return i.stock_actual > 0 ? 100 : 0
  return Math.min(100, Math.round((i.stock_actual / (i.stock_minimo * 2)) * 100))
}

// ── Nuevo insumo ──────────────────────────────────────────────
const nuevoForm = ref(null)
function nuevoInsumo() {
  nuevoForm.value = {
    nombre: '', unidad_medida: 'unidad', stock_minimo: 0, sede_id: sede.sedeId, tipo: tipoActivo.value,
    categoria_contable_id: categoriasDelTab.value[0]?.id ?? null,
  }
}
async function guardarNuevo() {
  if (!nuevoForm.value.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  try {
    await store.crear({ ...nuevoForm.value, nombre: nuevoForm.value.nombre.trim() })
    toast.success('Insumo creado'); nuevoForm.value = null
    await recargar()
  } catch { toast.error(store.saveError) }
}

// ── Comprar ───────────────────────────────────────────────────
const compraForm = ref(null)
function abrirCompra(i) { compraForm.value = { insumo: i, cantidad: null, costo_total_ars: null, proveedor: '' } }
async function confirmarCompra() {
  const f = compraForm.value
  if (!(f.cantidad > 0) || !(f.costo_total_ars > 0)) { toast.warning('Completá cantidad y costo'); return }
  try {
    // el egreso hereda la sede del insumo (el insumo ya está localizado en su sede)
    await store.comprar(f.insumo.id, { cantidad: f.cantidad, costo_total_ars: f.costo_total_ars, proveedor: f.proveedor || null, sede_id: f.insumo.sede_id })
    toast.success('Compra registrada'); compraForm.value = null
  } catch { toast.error(store.saveError) }
}

// ── Transferir a otra sede ────────────────────────────────────
const transferForm = ref(null) // { insumo, sede_destino_id, cantidad }
function abrirTransfer(i) { transferForm.value = { insumo: i, sede_destino_id: otrasSedes.value[0]?.id ?? null, cantidad: null } }
async function confirmarTransfer() {
  const f = transferForm.value
  if (!f.sede_destino_id) { toast.warning('Elegí la sede destino'); return }
  if (!(f.cantidad > 0)) { toast.warning('Poné la cantidad a transferir'); return }
  if (f.cantidad > f.insumo.stock_actual) { toast.warning('No hay stock suficiente'); return }
  try {
    await store.transferir(f.insumo.id, { sede_destino_id: f.sede_destino_id, cantidad: f.cantidad })
    toast.success('Transferencia registrada'); transferForm.value = null
    await recargar()
  } catch { toast.error(store.saveError) }
}

// ── Consumir (repartible entre varios lotes) ──────────────────
const consumoForm = ref(null) // { insumo, cantidad, lote_ids:[], sala_id }
function abrirConsumo(i) { consumoForm.value = { insumo: i, cantidad: null, lote_ids: [], sala_id: null } }
function toggleLote(id) {
  const arr = consumoForm.value.lote_ids
  const idx = arr.indexOf(id)
  if (idx === -1) arr.push(id); else arr.splice(idx, 1)
}
const porLote = computed(() => {
  const f = consumoForm.value
  if (!f?.cantidad || !f.lote_ids.length) return null
  return (f.cantidad / f.lote_ids.length)
})
async function confirmarConsumo() {
  const f = consumoForm.value
  if (!(f.cantidad > 0)) { toast.warning('Poné la cantidad usada'); return }
  if (f.cantidad > f.insumo.stock_actual) { toast.warning('No hay stock suficiente'); return }
  try {
    await store.consumir(f.insumo.id, { cantidad: f.cantidad, lote_ids: f.lote_ids, sala_id: f.sala_id })
    toast.success('Consumo imputado'); consumoForm.value = null
  } catch { toast.error(store.saveError) }
}
</script>

<template>
  <div class="dp">
    <header class="dp__head">
      <div>
        <h1 class="dp__title">
          Depósito
          <span v-if="multiSede" class="dp__ctx">{{ sede.esConsolidado ? 'Todas las sedes' : sede.sedeActual?.nombre }}</span>
        </h1>
        <p class="dp__sub">{{ tabActual?.hint }}</p>
      </div>
      <div v-if="!esSalon" class="dp__head-right">
        <div class="dp__stat">
          <span class="dp__stat-label">Valorizado</span>
          <span class="dp__stat-val">{{ fmt(store.valorizadoTotal) }}</span>
        </div>
        <button class="btn btn--primary" @click="nuevoInsumo">+ Insumo</button>
      </div>
    </header>

    <!-- Solapas por familia de depósito -->
    <div class="dp__tabs">
      <button v-for="t in TABS" :key="t.tipo" class="dp__tab" :class="{ 'is-on': tipoActivo === t.tipo }" @click="tipoActivo = t.tipo">
        {{ t.label }}
      </button>
    </div>

    <!-- Salón: depósito del bar (componente aparte) -->
    <DepositoSalon v-if="esSalon" :sede-id="sede.sedeId" />

    <template v-else>
    <div v-if="store.loading" class="dp__empty">Cargando depósito…</div>
    <div v-else-if="!store.items.length" class="dp__empty dp__empty--box">
      Todavía no hay insumos en esta familia. Se cargan al registrar la compra en
      <b>Contabilidad → Nuevo movimiento</b> (elegís la categoría y el sistema lo deriva acá), o con “+ Insumo”.
    </div>

    <!-- Agrupado por categoría → subcategoría (el mismo árbol contable) -->
    <div v-else class="dp__groups">
      <section v-for="g in grupos" :key="g.label" class="dp__group">
        <div class="dp__group-head">
          <span class="dp__group-name">{{ g.label }}</span>
          <span class="dp__group-val">{{ fmt(g.valorizado) }}</span>
        </div>
        <ul class="dp__list">
          <li v-for="i in g.items" :key="i.id" class="dp__item" :class="{ 'dp__item--low': i.stock_bajo }">
            <div class="dp__item-main">
              <div class="dp__item-top">
                <span class="dp__name">{{ i.nombre }}</span>
                <span v-if="multiSede" class="dp__sede">{{ i.sede_nombre || 'Sin sede' }}</span>
                <span v-if="i.stock_bajo" class="dp__pill">Reponer</span>
              </div>
              <div class="dp__meter"><i :style="{ width: stockPct(i) + '%' }" :class="i.stock_bajo ? 'is-low' : 'is-ok'"></i></div>
            </div>
            <div class="dp__stats">
              <span class="dp__stock num" :class="{ low: i.stock_bajo }">{{ i.stock_actual }} <small>{{ i.unidad_medida }}</small></span>
              <span class="dp__meta num">{{ fmt(i.costo_promedio_ars) }}/u · {{ fmt(i.valorizado_ars) }}</span>
            </div>
            <div class="dp__actions">
              <button class="btn btn--sm" @click="abrirCompra(i)">Comprar</button>
              <button v-if="multiSede && otrasSedes.length" class="btn btn--sm" @click="abrirTransfer(i)" :disabled="i.stock_actual <= 0" title="Transferir a otra sede">Transferir</button>
              <button class="btn btn--sm btn--primary" @click="abrirConsumo(i)" :disabled="i.stock_actual <= 0">Consumir</button>
            </div>
          </li>
        </ul>
      </section>
    </div>
    </template>

    <!-- Modal nuevo insumo -->
    <div v-if="nuevoForm" class="ov" @click.self="nuevoForm = null">
      <div class="modal">
        <h3 class="modal__title">Nuevo insumo</h3>
        <p class="modal__hint">Un ítem del depósito. Normalmente los insumos entran al registrar la compra en Nuevo movimiento; acá lo creás a mano y le cargás stock con “Comprar”.</p>
        <label class="fld">Nombre<input v-model.trim="nuevoForm.nombre" class="inp" placeholder="Ej: Fertilizante base" maxlength="60" /></label>
        <label class="fld">Categoría
          <select v-model="nuevoForm.categoria_contable_id" class="inp">
            <option :value="null">— Sin categoría —</option>
            <option v-for="c in categoriasDelTab" :key="c.id" :value="c.id">{{ c.label }}</option>
          </select>
        </label>
        <label v-if="multiSede" class="fld">Sede
          <select v-model="nuevoForm.sede_id" class="inp">
            <option :value="null">— Pool del club —</option>
            <option v-for="s in sede.sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>
        <div class="dp__grid2">
          <label class="fld">Unidad de medida<select v-model="nuevoForm.unidad_medida" class="inp"><option v-for="u in UNIDADES" :key="u" :value="u">{{ u }}</option></select></label>
          <label class="fld">Stock mínimo<input v-model.number="nuevoForm.stock_minimo" type="number" min="0" step="any" class="inp" /></label>
        </div>
        <p class="modal__note">Cuando el stock baje del mínimo, te avisamos para reponer.</p>
        <div class="modal__actions"><button class="btn" @click="nuevoForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="guardarNuevo">Crear insumo</button></div>
      </div>
    </div>

    <!-- Modal comprar -->
    <div v-if="compraForm" class="ov" @click.self="compraForm = null">
      <div class="modal">
        <h3 class="modal__title">Comprar — {{ compraForm.insumo.nombre }}</h3>
        <p class="modal__hint">Entra al stock y recalcula el costo promedio. Genera el egreso en el libro.</p>
        <label class="fld">Cantidad ({{ compraForm.insumo.unidad_medida }})<input v-model.number="compraForm.cantidad" type="number" min="0" step="any" class="inp" /></label>
        <label class="fld">Costo total<input v-model.number="compraForm.costo_total_ars" type="number" min="0" step="any" class="inp" placeholder="$" /></label>
        <label class="fld">Proveedor (opcional)<input v-model.trim="compraForm.proveedor" class="inp" /></label>
        <div class="modal__actions"><button class="btn" @click="compraForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarCompra">Registrar compra</button></div>
      </div>
    </div>

    <!-- Modal transferir a otra sede -->
    <div v-if="transferForm" class="ov" @click.self="transferForm = null">
      <div class="modal">
        <h3 class="modal__title">Transferir — {{ transferForm.insumo.nombre }}</h3>
        <p class="modal__hint">Mueve stock desde <b>{{ transferForm.insumo.sede_nombre || 'el pool' }}</b> a otra sede. El costo viaja con la mercadería; no genera un nuevo egreso.</p>
        <label class="fld">Sede destino
          <select v-model="transferForm.sede_destino_id" class="inp">
            <option v-for="s in otrasSedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>
        <label class="fld">Cantidad ({{ transferForm.insumo.unidad_medida }})
          <input v-model.number="transferForm.cantidad" type="number" min="0" :max="transferForm.insumo.stock_actual" step="any" class="inp" />
        </label>
        <p class="modal__note">Disponible: {{ transferForm.insumo.stock_actual }} {{ transferForm.insumo.unidad_medida }}.</p>
        <div class="modal__actions"><button class="btn" @click="transferForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarTransfer">Transferir</button></div>
      </div>
    </div>

    <!-- Modal consumir -->
    <div v-if="consumoForm" class="ov" @click.self="consumoForm = null">
      <div class="modal modal--wide">
        <h3 class="modal__title">Registrar consumo — {{ consumoForm.insumo.nombre }}</h3>
        <p class="modal__hint">
          Disponible {{ consumoForm.insumo.stock_actual }} {{ consumoForm.insumo.unidad_medida }}.
          {{ esGeneral ? 'Se descuenta del depósito como gasto general del club.' : 'Se imputa el costo a los lotes elegidos.' }}
        </p>
        <label class="fld">Cantidad usada<input v-model.number="consumoForm.cantidad" type="number" min="0" step="any" class="inp" /></label>

        <!-- Lotes/sala solo para insumos de cultivo. Los generales se consumen como gasto. -->
        <template v-if="!esGeneral">
          <div class="fld">
            <span>Lotes <small class="mut">(se reparte en partes iguales)</small></span>
            <div class="dp__lotes">
              <label v-for="l in lotes" :key="l.id" class="dp__lote" :class="{ 'is-on': consumoForm.lote_ids.includes(l.id) }">
                <input type="checkbox" :checked="consumoForm.lote_ids.includes(l.id)" @change="toggleLote(l.id)" />
                {{ l.codigo || ('Lote ' + l.id) }}
              </label>
              <span v-if="!lotes.length" class="mut" style="font-size:.8rem">Sin lotes activos.</span>
            </div>
            <p v-if="porLote" class="dp__reparto">{{ porLote.toFixed(2) }} {{ consumoForm.insumo.unidad_medida }} a cada uno de los {{ consumoForm.lote_ids.length }} lotes.</p>
          </div>

          <label class="fld">Sala (opcional)
            <select v-model="consumoForm.sala_id" class="inp"><option :value="null">— Sin sala —</option><option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option></select>
          </label>
        </template>

        <div class="modal__actions"><button class="btn" @click="consumoForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarConsumo">{{ esGeneral ? 'Registrar consumo' : 'Imputar consumo' }}</button></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dp { padding: 2rem 1.75rem 3rem; max-width: 920px; margin: 0 auto; color: #0f172a; }
.dp__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1.5rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
.dp__title { font-size: 1.6rem; font-weight: 800; letter-spacing: -.035em; margin: 0 0 .2rem; display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.dp__ctx { font-size: .74rem; font-weight: 600; letter-spacing: .01em; color: #1b5e20; background: rgb(27 94 32 / .08); border: 1px solid rgb(27 94 32 / .18); padding: .2rem .6rem; border-radius: 999px; }
.dp__tabs { display: inline-flex; gap: .25rem; background: #f1f5f9; border-radius: 10px; padding: .25rem; margin-bottom: 1.25rem; }
.dp__tab { border: none; background: transparent; color: #64748b; font-size: .84rem; font-weight: 600; padding: .45rem 1rem; border-radius: 8px; cursor: pointer; transition: background .12s, color .12s; }
.dp__tab:hover { color: #334155; }
.dp__tab.is-on { background: #fff; color: #1b5e20; box-shadow: 0 1px 2px rgb(15 23 42 / .08); }
.dp__sede { font-size: .66rem; font-weight: 600; letter-spacing: .02em; color: #475569; background: #f1f5f9; padding: 2px 8px; border-radius: 999px; }
.dp__sub { color: #64748b; font-size: .84rem; margin: 0; max-width: 52ch; line-height: 1.5; }
.dp__head-right { display: flex; align-items: center; gap: 1.25rem; }
.dp__stat { text-align: right; }
.dp__stat-label { display: block; font-size: .66rem; text-transform: uppercase; letter-spacing: .08em; color: #94a3b8; font-weight: 600; }
.dp__stat-val { display: block; font-size: 1.5rem; font-weight: 800; letter-spacing: -.03em; color: #0f172a; font-variant-numeric: tabular-nums; }

.dp__empty { color: #94a3b8; padding: 2.5rem; text-align: center; font-size: .9rem; }
.dp__empty--box { background: #fbfcfd; border: 1px dashed #e2e8f0; border-radius: 14px; }

.dp__groups { display: flex; flex-direction: column; gap: 1.5rem; }
.dp__group-head { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; padding: 0 .15rem .5rem; border-bottom: 1.5px solid #eef2f6; margin-bottom: .6rem; }
.dp__group-name { font-size: .82rem; font-weight: 700; color: #334155; letter-spacing: -.005em; }
.dp__group-val { font-size: .78rem; font-weight: 600; color: #94a3b8; font-variant-numeric: tabular-nums; }
.dp__list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .6rem; }
.dp__item { display: grid; grid-template-columns: 1fr auto auto; gap: 1.5rem; align-items: center; background: #fff; border: 1px solid #e8edf2; border-radius: 13px; padding: 1rem 1.25rem; box-shadow: 0 1px 2px rgb(15 23 42 / .04); transition: border-color .15s, box-shadow .15s; }
.dp__item:hover { border-color: #d7dee6; box-shadow: 0 2px 8px rgb(15 23 42 / .06); }
.dp__item--low { border-color: #f4d9b8; }
.dp__item-main { min-width: 0; }
.dp__item-top { display: flex; align-items: center; gap: .6rem; }
.dp__name { font-weight: 650; color: #0f172a; font-size: .96rem; letter-spacing: -.01em; }
.dp__pill { font-size: .64rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #b45309; background: #fef3c7; padding: 2px 8px; border-radius: 999px; }
.dp__meter { height: 6px; background: #f1f5f9; border-radius: 5px; overflow: hidden; margin-top: .55rem; }
.dp__meter i { display: block; height: 100%; border-radius: 5px; }
.dp__meter i.is-ok { background: linear-gradient(90deg, #1b5e20, #2e7d32); }
.dp__meter i.is-low { background: linear-gradient(90deg, #dc2626, #ef4444); }
.dp__stats { text-align: right; }
.num { font-variant-numeric: tabular-nums; }
.dp__stock { font-weight: 700; color: #0f172a; font-size: 1.05rem; }
.dp__stock small { font-weight: 500; color: #94a3b8; font-size: .78rem; }
.dp__stock.low { color: #dc2626; }
.dp__meta { display: block; color: #94a3b8; font-size: .76rem; margin-top: .1rem; }
.dp__actions { display: flex; gap: .4rem; }

.ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
.modal { background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 380px; box-shadow: 0 20px 50px rgb(15 23 42 / .25), 0 2px 8px rgb(15 23 42 / .1); }
.modal--wide { max-width: 440px; }
.modal__title { margin: 0 0 .25rem; font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; color: #0f172a; }
.modal__hint { color: #64748b; font-size: .82rem; margin: 0 0 1.1rem; line-height: 1.45; }
.modal__note { font-size: .76rem; color: #94a3b8; margin: -.3rem 0 .9rem; }
.dp__grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: #475569; margin-bottom: .9rem; }
.mut { color: #94a3b8; }
.modal__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; }

.dp__lotes { display: flex; flex-wrap: wrap; gap: .4rem; }
.dp__lote { display: inline-flex; align-items: center; gap: .35rem; padding: .35rem .65rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .8rem; color: #475569; cursor: pointer; user-select: none; }
.dp__lote.is-on { border-color: #1b5e20; background: rgb(27 94 32 / .06); color: #1b5e20; font-weight: 600; }
.dp__lote input { accent-color: #1b5e20; }
.dp__reparto { font-size: .78rem; color: #1b5e20; margin: .5rem 0 0; font-weight: 500; }

.inp { padding: .55rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 9px; font-size: .86rem; background: #fff; color: #0f172a; }
.inp:focus { border-color: #1b5e20; outline: none; }
.inp--sm { width: 92px; }
.btn { border: 1.5px solid #e2e8f0; background: #fff; color: #334155; border-radius: 9px; padding: .55rem .95rem; font-size: .83rem; font-weight: 600; cursor: pointer; transition: border-color .12s, background .12s; }
.btn:hover { border-color: #cbd5e1; }
.btn--sm { padding: .45rem .8rem; font-size: .8rem; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover { background: #144a18; border-color: #144a18; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
