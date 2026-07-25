<script setup>
// Stock del salón (B2 del rediseño): el ÚNICO lugar de la mercadería del bar. Fusiona la tabla de
// productos del Panel + la compra-con-costo. Todo el stock entra con costo (Comprar) → impacta el
// resultado y calcula el margen. Gating por rol: gestión edita; el dispensador solo consulta
// (nombre, categoría, precio, stock — sin costo, margen ni acciones).
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { listCategoriasProducto, comprarBarProducto, createCategoriaProducto, updateCategoriaProducto, deleteCategoriaProducto } from '../../lib/api.js'
import BarNav from './BarNav.vue'
import BarcodeScanner from '../../components/BarcodeScanner.vue'

const route = useRoute()
const barId = route.params.barId
const store = useBarStore()
const auth  = useAuthStore()
const toast = useToast()
const { confirm } = useConfirm()

const esGestion = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`
const margen = (p) => (p.precio_ars > 0 && p.costo_ars != null) ? Math.round((p.precio_ars - p.costo_ars) / p.precio_ars * 100) : null

const categorias = ref([])
const busqueda = ref('')

onMounted(async () => {
  if (!store.barActual || String(store.barActual.id) !== String(barId)) await store.fetchDashboard(barId)
  await store.fetchProductos(barId)
  try { categorias.value = (await listCategoriasProducto()).data || [] } catch { categorias.value = [] }
})

const productos = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  return store.productos
    .filter(p => !q || p.nombre.toLowerCase().includes(q))
    .sort((a, b) => (a.categoria_producto_nombre || '').localeCompare(b.categoria_producto_nombre || '') || a.nombre.localeCompare(b.nombre))
})
const valorizado = computed(() => store.productos.reduce((a, p) => a + (p.stock * (p.costo_ars || 0)), 0))

// ── Alta / edición de producto (sin stock inicial: el stock entra por Comprar, con costo) ──
const prodForm = ref(null)
const escaneandoProd = ref(false) // scan-to-fill del código de barras en el form
// carga: primera carga opcional (cantidad + costo → sube stock con costo y genera el egreso "Bar").
function nuevo() { prodForm.value = { nombre: '', categoria_producto_id: categorias.value[0]?.id ?? null, precio_ars: null, stock_minimo: 0, codigo_barras: '', carga: { cantidad: null, costo_total: null, proveedor: '' } } }
function editar(p) { prodForm.value = { id: p.id, nombre: p.nombre, categoria_producto_id: p.categoria_producto_id, precio_ars: p.precio_ars, stock_minimo: p.stock_minimo ?? 0, codigo_barras: p.codigo_barras || '' } }
function onCodigoDecoded(code) { if (prodForm.value) { prodForm.value.codigo_barras = String(code || '').trim(); toast.success('Código cargado') } }
const cargaCostoUnit = computed(() => {
  const c = prodForm.value?.carga
  return c?.cantidad > 0 && c?.costo_total > 0 ? c.costo_total / c.cantidad : null
})
async function guardarProd() {
  const f = prodForm.value
  if (!f.nombre?.trim() || !(f.precio_ars > 0)) { toast.warning('Nombre y precio son obligatorios'); return }
  const cat = categorias.value.find(c => c.id === f.categoria_producto_id)
  const payload = { nombre: f.nombre.trim(), categoria_producto_id: f.categoria_producto_id, categoria: cat?.clave_sistema || 'otro', precio_ars: f.precio_ars, stock_minimo: f.stock_minimo || 0, codigo_barras: f.codigo_barras?.trim() || null }
  // Carga inicial: si pusiste cantidad, exige costo (no hay stock sin costo).
  let carga = null
  if (!f.id && f.carga?.cantidad > 0) {
    if (!(f.carga.costo_total > 0)) { toast.warning('Poné el costo total de la carga inicial (o dejá la cantidad vacía)'); return }
    carga = { cantidad: f.carga.cantidad, costo_total_ars: f.carga.costo_total, proveedor: f.carga.proveedor || null }
  }
  try {
    if (f.id) await store.actualizarProducto(barId, f.id, payload)
    else      await store.crearProducto(barId, payload, carga)
    toast.success(carga ? 'Producto creado con su carga inicial' : 'Producto guardado'); prodForm.value = null
    await store.fetchProductos(barId)
  } catch { toast.error(store.saveError) }
}
async function borrar(p) {
  if (!(await confirm({ title: 'Eliminar producto', message: `¿Eliminar "${p.nombre}"? Se recupera desde la papelera.`, variant: 'danger' }))) return
  try { await store.eliminarProducto(barId, p.id); toast.success('Producto eliminado') }
  catch { toast.error('No se pudo eliminar') }
}

// ── Comprar (entra stock CON costo → egreso + costo promedio) ──
const compraForm = ref(null)
function abrirCompra(p) { compraForm.value = { prod: p, cantidad: null, costo_total_ars: null, proveedor: '' } }
const costoUnit = computed(() => {
  const f = compraForm.value
  return f?.cantidad > 0 && f?.costo_total_ars >= 0 ? f.costo_total_ars / f.cantidad : null
})
async function confirmarCompra() {
  const f = compraForm.value
  if (!(f.cantidad > 0) || !(f.costo_total_ars >= 0)) { toast.warning('Completá cantidad y costo'); return }
  try {
    await comprarBarProducto(barId, f.prod.id, { cantidad: f.cantidad, costo_total_ars: f.costo_total_ars, proveedor: f.proveedor || null })
    toast.success('Compra registrada · egreso generado'); compraForm.value = null
    await store.fetchProductos(barId)
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo comprar') }
}

// ── Categorías de producto (editables) ──
async function cargarCategorias() { try { categorias.value = (await listCategoriasProducto()).data || [] } catch { categorias.value = [] } }
const catMgr = ref(null)
function abrirCategorias() { catMgr.value = { nuevo: '' } }
async function agregarCat() {
  const n = catMgr.value.nuevo?.trim(); if (!n) return
  try { await createCategoriaProducto({ nombre: n }); catMgr.value.nuevo = ''; await cargarCategorias() }
  catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo crear') }
}
async function renombrarCat(c) {
  const n = prompt('Nuevo nombre de la categoría', c.nombre); if (!n?.trim() || n.trim() === c.nombre) return
  try { await updateCategoriaProducto(c.id, { nombre: n.trim() }); await cargarCategorias() } catch { toast.error('No se pudo renombrar') }
}
async function borrarCat(c) {
  if (!(await confirm({ title: `Eliminar "${c.nombre}"`, message: 'Solo se puede si no tiene productos; si los tiene, reasignalos primero.', variant: 'danger' }))) return
  try { await deleteCategoriaProducto(c.id); await cargarCategorias() } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
}
</script>

<template>
  <div class="bs">
    <BarNav :bar-id="barId" active="stock" />

    <div class="bs__head">
      <div>
        <h2 class="bs__title">Stock del salón</h2>
        <p class="bs__sub">{{ esGestion ? 'Todo el catálogo del bar, en un solo lugar.' : 'Consultá qué hay y a qué precio.' }}</p>
      </div>
      <div v-if="esGestion" class="bs__actions">
        <span class="bs__val">Valorizado <b>{{ fmt(valorizado) }}</b></span>
        <button class="btn" @click="abrirCategorias">Categorías</button>
        <button class="btn btn--brand" @click="nuevo">＋ Producto</button>
      </div>
    </div>

    <div v-if="esGestion" class="bs__note">🧾 Todo el stock entra con su <b>costo</b> (botón Comprar) → impacta el resultado y calcula el margen solo.</div>

    <div class="bs__search">
      <i class="bi bi-search"></i>
      <input v-model.trim="busqueda" type="text" placeholder="Buscar producto por nombre…" />
      <span class="bs__scan">⌗ código de barras (pronto)</span>
    </div>

    <!-- Form alta/edición -->
    <div v-if="prodForm" class="bs__form">
      <input v-model.trim="prodForm.nombre" class="inp" placeholder="Nombre" maxlength="60" />
      <select v-model="prodForm.categoria_producto_id" class="inp"><option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nombre }}</option></select>
      <input v-model.number="prodForm.precio_ars" type="number" min="0" step="any" class="inp inp--sm" placeholder="Precio" />
      <input v-model.number="prodForm.stock_minimo" type="number" min="0" step="any" class="inp inp--sm" placeholder="Mínimo" />
      <div class="bs__code">
        <input v-model.trim="prodForm.codigo_barras" class="inp inp--code" placeholder="Código de barras (opcional)" maxlength="60" />
        <button class="btn btn--icon" type="button" title="Escanear con la cámara" @click="escaneandoProd = true">📷</button>
      </div>
      <!-- Carga inicial (solo al crear): un paso de la nada a producto listo para vender -->
      <div v-if="!prodForm.id" class="bs__carga">
        <span class="bs__carga-lbl">Carga inicial <small>(opcional — entra con costo, genera el egreso)</small></span>
        <div class="bs__carga-row">
          <input v-model.number="prodForm.carga.cantidad" type="number" min="0" step="any" class="inp inp--sm" placeholder="Cantidad" />
          <input v-model.number="prodForm.carga.costo_total" type="number" min="0" step="any" class="inp inp--sm" placeholder="Costo total" />
          <input v-model.trim="prodForm.carga.proveedor" class="inp" placeholder="Proveedor (opcional)" maxlength="60" />
          <span v-if="cargaCostoUnit != null" class="bs__carga-unit">{{ fmt(cargaCostoUnit) }}/u</span>
        </div>
      </div>
      <div class="bs__form-act">
        <button class="btn" @click="prodForm = null">Cancelar</button>
        <button class="btn btn--brand" :disabled="store.saving" @click="guardarProd">Guardar</button>
      </div>
    </div>

    <div class="bs__tbl-wrap">
      <table class="bs__tbl">
        <thead>
          <tr>
            <th>Producto</th><th>Categoría</th><th class="r">Precio</th>
            <template v-if="esGestion"><th class="r">Costo</th><th class="r">Margen</th></template>
            <th class="r">Stock</th>
            <th v-if="esGestion"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in productos" :key="p.id" :class="{ off: !p.activo }">
            <td class="pname">{{ p.nombre }}</td>
            <td><span class="chip-cat">{{ p.categoria_producto_nombre || p.categoria }}</span></td>
            <td class="r num">{{ fmt(p.precio_ars) }}</td>
            <template v-if="esGestion">
              <td class="r num mut">{{ p.costo_ars != null ? fmt(p.costo_ars) : '—' }}</td>
              <td class="r"><span v-if="margen(p) != null" class="mg" :class="margen(p) >= 50 ? 'hi' : 'mid'">{{ margen(p) }}%</span><span v-else class="mut">—</span></td>
            </template>
            <td class="r num" :class="{ low: p.stock_bajo }">{{ p.stock }}</td>
            <td v-if="esGestion" class="r rowact">
              <button class="lnk" @click="abrirCompra(p)">Comprar</button>
              <button class="lnk" @click="editar(p)">Editar</button>
              <button class="lnk lnk--danger" @click="borrar(p)">Borrar</button>
            </td>
          </tr>
          <tr v-if="!productos.length"><td :colspan="esGestion ? 7 : 4" class="bs__empty">{{ busqueda ? 'Sin resultados.' : 'Sin productos. Creá el primero.' }}</td></tr>
        </tbody>
      </table>
    </div>

    <!-- Modal Comprar -->
    <div v-if="compraForm" class="ov" @click.self="compraForm = null">
      <div class="dlg">
        <h3 class="dlg__title">Comprar — {{ compraForm.prod.nombre }}</h3>
        <p class="dlg__hint">Suma stock al salón con su costo, recalcula el costo promedio y genera el <b>egreso contable</b>.</p>
        <label class="fld">Cantidad (unidades)<input v-model.number="compraForm.cantidad" type="number" min="0" step="any" class="inp" /></label>
        <label class="fld">Costo total ($)<input v-model.number="compraForm.costo_total_ars" type="number" min="0" step="any" class="inp" /></label>
        <p v-if="costoUnit !== null" class="dlg__line">Costo unitario: <b>{{ fmt(costoUnit) }}</b> / u</p>
        <label class="fld">Proveedor (opcional)<input v-model.trim="compraForm.proveedor" class="inp" maxlength="80" /></label>
        <div class="dlg__act"><button class="btn" @click="compraForm = null">Cancelar</button><button class="btn btn--brand" :disabled="store.saving" @click="confirmarCompra">Registrar compra</button></div>
      </div>
    </div>

    <!-- Modal Categorías -->
    <div v-if="catMgr" class="ov" @click.self="catMgr = null">
      <div class="dlg">
        <h3 class="dlg__title">Categorías de producto</h3>
        <p class="dlg__hint">Con estas se agrupan y filtran los productos del salón.</p>
        <ul class="bs__catlist">
          <li v-for="c in categorias" :key="c.id">
            <span>{{ c.nombre }} <small class="mut" v-if="c.es_sistema">· sistema</small> <small class="mut">· {{ c.productos_count }} prod.</small></span>
            <span class="bs__catacts">
              <button class="lnk" @click="renombrarCat(c)">Renombrar</button>
              <button v-if="!c.es_sistema" class="lnk lnk--danger" @click="borrarCat(c)">Eliminar</button>
            </span>
          </li>
        </ul>
        <div class="bs__form" style="margin-top:.8rem">
          <input v-model.trim="catMgr.nuevo" class="inp" placeholder="Nueva categoría (ej: Vapes)" maxlength="30" @keydown.enter.prevent="agregarCat" />
          <button class="btn btn--brand" @click="agregarCat">Agregar</button>
        </div>
        <div class="dlg__act"><button class="btn" @click="catMgr = null">Cerrar</button></div>
      </div>
    </div>

    <BarcodeScanner v-if="escaneandoProd" una-vez titulo="Escaneá el código del producto" @decoded="onCodigoDecoded" @close="escaneandoProd = false" />
  </div>
</template>

<style scoped>
.bs { padding: 2rem 1.75rem 3rem; max-width: 960px; margin: 0 auto; color: #0f172a; }
.bs__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: .5rem; }
.bs__title { font-size: 1.15rem; font-weight: 750; margin: 0; letter-spacing: -.01em; }
.bs__sub { font-size: .82rem; color: #64748b; margin: .15rem 0 0; }
.bs__actions { display: flex; align-items: center; gap: 1rem; }
.bs__val { font-size: .8rem; color: #64748b; } .bs__val b { color: #0f172a; font-weight: 750; }
.bs__note { display: flex; align-items: center; gap: .5rem; font-size: .8rem; color: #334155; background: #eaf3ea; border: 1px solid #cfe3d0; border-radius: 10px; padding: .55rem .8rem; margin: .9rem 0; }
.bs__search { display: flex; align-items: center; gap: .6rem; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 11px; padding: .6rem .85rem; margin-bottom: 1rem; color: #94a3b8; }
.bs__search:focus-within { border-color: #9a5b34; }
.bs__search input { flex: 1; border: none; outline: none; background: none; font-size: .9rem; color: #0f172a; min-width: 0; }
.bs__scan { font-size: .7rem; font-weight: 600; color: #94a3b8; background: #f7f9fb; border: 1px solid #e2e8f0; border-radius: 7px; padding: .25rem .5rem; white-space: nowrap; }

.bs__form { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; background: #f8fafc; border: 1px solid #eef2f6; border-radius: 11px; padding: .8rem; margin-bottom: 1rem; }
.bs__code { display: flex; gap: .4rem; align-items: center; }
.bs__carga { flex: 1 1 100%; border-top: 1px dashed #e2e8f0; padding-top: .7rem; margin-top: .2rem; }
.bs__carga-lbl { display: block; font-size: .78rem; font-weight: 700; color: #64748b; margin-bottom: .45rem; }
.bs__carga-lbl small { font-weight: 400; color: #94a3b8; }
.bs__carga-row { display: flex; gap: .5rem; flex-wrap: wrap; align-items: center; }
.bs__carga-unit { font-size: .78rem; color: #15803d; font-weight: 600; font-variant-numeric: tabular-nums; }
.bs__form-act { display: flex; gap: .5rem; margin-left: auto; }
.bs__code { display: flex; gap: .4rem; align-items: center; }
.inp--code { width: 220px; }
.btn--icon { padding: .4rem .6rem; font-size: 1rem; line-height: 1; }

.bs__tbl-wrap { border: 1px solid #e6ebf1; border-radius: 12px; overflow-x: auto; }
.bs__tbl { width: 100%; border-collapse: collapse; font-size: .87rem; background: #fff; }
.bs__tbl thead th { text-align: left; font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; font-weight: 700; padding: .7rem .9rem; border-bottom: 1px solid #eef2f6; white-space: nowrap; background: #f8fafc; }
.bs__tbl td { padding: .7rem .9rem; border-bottom: 1px solid #f1f5f9; white-space: nowrap; }
.bs__tbl tbody tr:last-child td { border-bottom: none; }
.bs__tbl tbody tr:hover td { background: #fafbfc; }
.bs__tbl tr.off td { opacity: .5; }
.r { text-align: right; } .num { font-variant-numeric: tabular-nums; } .mut { color: #94a3b8; }
.pname { font-weight: 650; color: #0f172a; }
.chip-cat { font-size: .7rem; font-weight: 600; color: #334155; background: #f1f5f9; border: 1px solid #e2e8f0; padding: 2px 9px; border-radius: 999px; }
.mg { display: inline-block; padding: 2px 9px; border-radius: 999px; font-size: .72rem; font-weight: 700; }
.mg.hi { background: #e8f6ec; color: #15803d; } .mg.mid { background: #fdf1dc; color: #b45309; }
.low { color: #dc2626; font-weight: 700; }
.rowact { white-space: nowrap; }
.lnk { background: none; border: none; color: #64748b; font-size: .8rem; font-weight: 600; cursor: pointer; padding: .1rem .35rem; }
.lnk:hover { color: #0f172a; } .lnk--danger:hover { color: #dc2626; }
.bs__empty { text-align: center; color: #94a3b8; padding: 1.8rem; }

.ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
.dlg { background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 400px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.dlg__title { margin: 0 0 .25rem; font-size: 1.1rem; font-weight: 750; }
.dlg__hint { color: #64748b; font-size: .82rem; margin: 0 0 1.1rem; line-height: 1.45; }
.dlg__line { font-size: .78rem; color: #15803d; margin: -.4rem 0 .9rem; font-weight: 600; }
.dlg__act { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; }
.bs__catlist { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; max-height: 40vh; overflow-y: auto; }
.bs__catlist li { display: flex; align-items: center; justify-content: space-between; gap: .75rem; padding: .5rem .7rem; background: #f8fafc; border: 1px solid #eef2f6; border-radius: 9px; font-size: .86rem; }
.bs__catacts { display: inline-flex; gap: .35rem; flex-shrink: 0; }
.fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: #475569; margin-bottom: .9rem; }
.inp { padding: .55rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 9px; font-size: .86rem; background: #fff; color: #0f172a; }
.inp:focus { border-color: #9a5b34; outline: none; }
.inp--sm { width: 100px; }
.btn { border: 1.5px solid #e2e8f0; background: #fff; color: #334155; border-radius: 9px; padding: .55rem .95rem; font-size: .83rem; font-weight: 600; cursor: pointer; }
.btn:hover { border-color: #cbd5e1; }
.btn--brand { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--brand:hover { background: #144a18; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
