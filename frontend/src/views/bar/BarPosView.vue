<script setup>
// POS de un bar concreto (Capa 1) — cara operativa. Estilo alineado a ContabilidadView.
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useBarStore } from '../../stores/bar.js'
import { useAuthStore } from '../../stores/auth.js'
import { useToast } from '../../composables/useToast.js'
import { listEventosBar, listCategoriasProducto, listBarVentas, listVendiblesBar, deleteBarVenta } from '../../lib/api.js'
import { useConfirm } from '../../composables/useConfirm.js'
import BarNav from './BarNav.vue'
import BarcodeScanner from '../../components/BarcodeScanner.vue'
import TicketVenta from '../../components/bar/TicketVenta.vue'
import { useClubStore } from '../../stores/club.js'

const store  = useBarStore()
const auth   = useAuthStore()
const route  = useRoute()
const toast  = useToast()
const { confirm } = useConfirm()
const barId  = route.params.barId

// Categorías editables (reemplazan el enum hardcodeado). Solo las que tienen productos.
const categorias = ref([])
const catActiva  = ref(null) // null = todas
const CATS = computed(() => categorias.value.filter(c => store.activos.some(p => p.categoria_producto_id === c.id)))
const q = ref('') // buscador por nombre (primario; hueco para lector de código de barras)
const medioPago = ref('efectivo')
// Atribuir la venta a un evento en curso: descuenta lo reservado y suma al P&L del evento.
const eventos   = ref([])
const eventoSel = ref(null)
const esGestion = computed(() => ['admin', 'supervisor'].includes(auth.user?.role))

onMounted(async () => {
  // Cargar categorías primero (siembra + backfillea el categoria_producto_id de los productos).
  try { categorias.value = (await listCategoriasProducto()).data || [] } catch { categorias.value = [] }
  await store.fetchProductos(barId, { activos: 'true' })
  listEventosBar(barId)
    .then(r => { eventos.value = (r.data || []).filter(e => ['en_venta', 'en_curso'].includes(e.estado)) })
    .catch(() => {})
})

// Lista filtrada por buscador (nombre) + categoría opcional. La búsqueda es la vía primaria.
const productosFiltrados = computed(() => {
  const term = q.value.trim().toLowerCase()
  return store.activos.filter(p =>
    (catActiva.value == null || p.categoria_producto_id === catActiva.value) &&
    (!term || p.nombre.toLowerCase().includes(term))
  )
})
const catNombre = (p) => categorias.value.find(c => c.id === p.categoria_producto_id)?.nombre || '—'
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

// ── Otros depósitos: vender algo que no vive en el salón ──────────────────
// El mostrador puede cobrar un insumo (una remera del depósito General) sin duplicarlo como
// producto del bar: la línea descuenta de SU depósito. Lo del dispensario (flor, derivados y
// stock externo) NO se vende acá — sale por dispensación, que es lo que deja la trazabilidad.
const DEP_LBL = { salon: 'Buffet', cultivo: 'Cultivo', general: 'General' }
const otros = ref([])
const buscandoOtros = ref(false)
let otrosTimer = null
async function buscarOtros() {
  const term = q.value.trim()
  if (term.length < 2) { otros.value = []; return }
  buscandoOtros.value = true
  try {
    const { data } = await listVendiblesBar(barId, { q: term, otros_depositos: 1 })
    otros.value = data?.resultados || []
  } catch { otros.value = [] }
  finally { buscandoOtros.value = false }
}
function onBuscarInput() { clearTimeout(otrosTimer); otrosTimer = setTimeout(buscarOtros, 300) }

// Un ítem sin precio propio (un insumo) necesita precio a mano — solo gestión.
const precioForm = ref(null)
function agregarOtro(v) {
  if (v.disponible <= 0) { toast.warning(`${v.nombre} sin stock`); return }
  if (v.requiere_precio) {
    if (!esGestion.value) { toast.warning('Ese ítem no tiene precio cargado'); return }
    precioForm.value = { v, precio: null }
    return
  }
  store.agregar(v); toast.success(`${v.nombre} agregado`)
}
function confirmarPrecio() {
  const f = precioForm.value
  if (!(f.precio > 0)) { toast.warning('Poné el precio de venta'); return }
  store.agregar(f.v, { precio: f.precio })
  precioForm.value = null
}

// ── Código de barras: lector físico (Enter) + cámara + scan-to-create ─────
const escaneando = ref(false)
const esAdmin = computed(() => auth.user?.role === 'admin') // crear productos es solo admin
const pareceCodigo = (s) => /^\d{8,}$/.test(String(s || '').trim()) // EAN/UPC: 8+ dígitos
const buscarPorCodigo = (code) => {
  const c = String(code || '').trim()
  return c ? (store.activos.find(p => p.codigo_barras && String(p.codigo_barras) === c) || null) : null
}
// Agrega el producto del código; si no existe y sos admin, ofrece crearlo (scan-to-create).
function procesarCodigo(code, { ofrecerCrear = true } = {}) {
  const c = String(code || '').trim()
  if (!c) return false
  const prod = buscarPorCodigo(c)
  if (prod) {
    if (prod.stock <= 0) { toast.warning(`${prod.nombre} sin stock`); return false }
    store.agregar(prod); toast.success(`${prod.nombre} agregado`); return true
  }
  if (ofrecerCrear && esAdmin.value) { abrirCrear(c); return false }
  toast.warning(`El código ${c} no está asignado a ningún producto`)
  return false
}
// Enter en el buscador = lector físico (tipea el código + Enter). Distingue código de nombre:
// un término todo-dígitos se trata como código (agrega o, si no existe, ofrece crear).
function onEnterBuscar() {
  const term = q.value.trim()
  if (!term) return
  if (buscarPorCodigo(term) || pareceCodigo(term)) { procesarCodigo(term); q.value = ''; return }
  if (productosFiltrados.value.length === 1 && productosFiltrados.value[0].stock > 0) {
    store.agregar(productosFiltrados.value[0]); q.value = ''
  }
}
// Cámara: cada lectura agrega (o, si el código no existe, ofrece crear el producto).
function onCamaraDecoded(code) { procesarCodigo(code) }

// ── Scan-to-create: alta rápida del producto con el código ya cargado (admin) ──
const crearForm = ref(null)
function abrirCrear(code) {
  escaneando.value = false // cerramos la cámara si estaba abierta
  crearForm.value = { nombre: '', categoria_producto_id: categorias.value[0]?.id ?? null, precio_ars: null, cantidad: null, costo_total: null, codigo_barras: code }
}
async function guardarNuevo() {
  const f = crearForm.value
  if (!f.nombre?.trim() || !(f.precio_ars > 0)) { toast.warning('Nombre y precio son obligatorios'); return }
  const cat = categorias.value.find(c => c.id === f.categoria_producto_id)
  const payload = { nombre: f.nombre.trim(), categoria_producto_id: f.categoria_producto_id, categoria: cat?.clave_sistema || 'otro', precio_ars: f.precio_ars, codigo_barras: f.codigo_barras }
  // Carga inicial: si ponés cantidad, exige costo (entra con costo → genera el egreso del bar).
  let carga = null
  if (f.cantidad > 0) {
    if (!(f.costo_total > 0)) { toast.warning('Poné el costo total (o dejá la cantidad vacía)'); return }
    carga = { cantidad: f.cantidad, costo_total_ars: f.costo_total, proveedor: null }
  }
  try {
    const prod = await store.crearProducto(barId, payload, carga)
    toast.success(`${prod.nombre} creado`)
    if (prod.stock > 0) store.agregar(prod) // si cargaste stock, va directo al carrito
    crearForm.value = null; q.value = ''
  } catch { toast.error(store.saveError || 'No se pudo crear el producto') }
}

// Comprobante (no fiscal) de la venta
const clubStore = useClubStore()
const ticketVenta = ref(null)
const barNombre = computed(() => store.bares.find(b => String(b.id) === String(barId))?.nombre || store.barActual?.nombre || 'Buffet')

async function cobrar() {
  if (!store.carrito.length) return
  // Snapshot ANTES de cobrar (store.cobrar vacía el carrito) para poder imprimir el comprobante.
  const snapshot = {
    items: store.carrito.map(l => ({ nombre: l.nombre, cantidad: l.cantidad, precio: l.precio })),
    total: store.totalCarrito, medio: medioPago.value,
  }
  try {
    const venta = await store.cobrar(barId, medioPago.value, eventoSel.value)
    toast.success('Venta cobrada')
    ticketVenta.value = { ...snapshot, nro: venta?.id, fecha: new Date() }
  }
  catch { toast.error(store.saveError || 'No se pudo cobrar') }
}

// ── Historial de ventas: reimprimir el comprobante de una venta pasada ──────
const showHistorial = ref(false)
const ventas = ref([])
const loadingVentas = ref(false)
async function abrirHistorial() {
  showHistorial.value = true
  loadingVentas.value = true
  try { ventas.value = (await listBarVentas(barId)).data || [] }
  catch { ventas.value = [] }
  finally { loadingVentas.value = false }
}
// Eliminar una venta mal cargada. Es LA forma de deshacerla: devuelve la mercadería al depósito
// y saca el ingreso del libro (BarVenta#revertir_efectos). Borrar el asiento desde Contabilidad
// no devuelve el stock — por eso ese camino está bloqueado del lado del backend.
const borrandoVenta = ref(null)
async function eliminarVenta(v) {
  const ok = await confirm({
    title: `¿Eliminar la venta #${v.id}?`,
    message: `Vuelve el stock al depósito y se saca del libro el ingreso de ${fmt(v.total_ars)}. La venta queda en la papelera.`,
    confirmText: 'Eliminar venta',
  })
  if (!ok) return

  borrandoVenta.value = v.id
  try {
    await deleteBarVenta(barId, v.id)
    ventas.value = ventas.value.filter(x => x.id !== v.id)
    await store.fetchProductos(barId, { activos: 'true' })  // stock repuesto
    toast.success('Venta eliminada · stock devuelto')
  } catch (e) {
    toast.error(e.response?.data?.error || 'No se pudo eliminar la venta')
  } finally {
    borrandoVenta.value = null
  }
}

function reimprimir(v) {
  ticketVenta.value = {
    nro: v.id,
    items: (v.items || []).map(it => ({ nombre: it.nombre, cantidad: it.cantidad, precio: it.precio_unitario_ars })),
    total: v.total_ars, medio: v.medio_pago, fecha: v.created_at,
  }
  showHistorial.value = false
}
const fechaHora = (d) => {
  const dt = new Date(d)
  return dt.toLocaleDateString('es-AR') + ' ' + dt.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <div class="cv">
    <BarNav :bar-id="barId" active="vender" />

    <div class="cv__pos">
      <div class="cv__pos-catalog">
        <!-- Buscador (por nombre o lector físico: tipea el código + Enter) + escaneo con cámara -->
        <div class="cv__search">
          <span class="cv__search-ic">🔍</span>
          <input v-model="q" class="cv__search-inp" placeholder="Buscar por nombre o escaneá el código…" autocomplete="off" @input="onBuscarInput" @keyup.enter="onEnterBuscar" />
          <button v-if="q" class="cv__search-clear" type="button" @click="q = ''" aria-label="Limpiar">×</button>
          <button class="cv__scan" type="button" title="Escanear con la cámara" @click="escaneando = true">📷</button>
        </div>
        <div class="cv__pos-tabs">
          <button class="cv__sede-btn" :class="{ 'cv__sede-btn--active': catActiva == null }" @click="catActiva = null">Todas</button>
          <button v-for="c in CATS" :key="c.id" class="cv__sede-btn" :class="{ 'cv__sede-btn--active': catActiva === c.id }" @click="catActiva = c.id">{{ c.nombre }}</button>
        </div>
        <div v-if="store.loading" class="cv__empty-sm" style="padding:2rem 0;">Cargando…</div>
        <div v-else-if="!productosFiltrados.length" class="cv__empty-sm" style="padding:2rem 0;">
          {{ q ? `Sin resultados para “${q}”.` : 'Sin productos en esta categoría.' }}
        </div>
        <ul v-else class="cv__list">
          <li v-for="p in productosFiltrados" :key="p.id">
            <button class="cv__row" :class="{ 'cv__row--off': p.stock <= 0 }" :disabled="p.stock <= 0" @click="store.agregar(p)">
              <span class="cv__row-main">
                <span class="cv__row-name">{{ p.nombre }}</span>
                <span class="cv__row-cat">{{ catNombre(p) }}</span>
              </span>
              <span class="cv__row-price cv__num">{{ fmt(p.precio_ars) }}</span>
              <span class="cv__row-stock" :class="{ 'cv__td-red': p.stock_bajo }">{{ p.stock <= 0 ? 'sin stock' : `stock ${p.stock}` }}</span>
              <span class="cv__row-add">+</span>
            </button>
          </li>
        </ul>

        <!-- Mercadería que no vive en el salón: se vende igual y descuenta de su depósito -->
        <template v-if="q.trim().length >= 2">
          <div v-if="buscandoOtros" class="cv__otros-head">Buscando en otros depósitos…</div>
          <template v-else-if="otros.length">
            <div class="cv__otros-head">En otros depósitos</div>
            <ul class="cv__list">
              <li v-for="v in otros" :key="`${v.vendible_type}-${v.vendible_id}`">
                <button class="cv__row" :class="{ 'cv__row--off': v.disponible <= 0 }" :disabled="v.disponible <= 0" @click="agregarOtro(v)">
                  <span class="cv__row-main">
                    <span class="cv__row-name">{{ v.nombre }}</span>
                    <span class="cv__row-cat">{{ DEP_LBL[v.deposito] || v.deposito }}</span>
                  </span>
                  <span class="cv__row-price cv__num">{{ v.requiere_precio ? 'a definir' : fmt(v.precio_ars) }}</span>
                  <span class="cv__row-stock">{{ v.disponible <= 0 ? 'sin stock' : `stock ${v.disponible} ${v.unidad}` }}</span>
                  <span class="cv__row-add">+</span>
                </button>
              </li>
            </ul>
          </template>
        </template>
      </div>

      <aside class="cv__cart">
        <div class="cv__card-header">
          <span class="cv__card-title">Pedido</span>
          <button class="cv__hist-btn" type="button" title="Ver últimas ventas y reimprimir" @click="abrirHistorial">🧾 Ventas</button>
        </div>
        <div class="cv__cart-body">
          <div v-if="!store.carrito.length" class="cv__empty-sm">Tocá un producto para agregarlo.</div>
          <ul v-else class="cv__cart-list">
            <li v-for="l in store.carrito" :key="l.key" class="cv__ci">
              <button class="cv__ci-btn" @click="store.quitar(l.key)" aria-label="Quitar uno">−</button>
              <span class="cv__ci-qty">{{ l.cantidad }}</span>
              <span class="cv__ci-name">
                {{ l.nombre }}
                <small v-if="l.deposito !== 'salon'" class="cv__ci-dep">{{ DEP_LBL[l.deposito] || l.deposito }}</small>
              </span>
              <span class="cv__ci-sub cv__num">{{ fmt(l.precio * l.cantidad) }}</span>
              <button class="cv__ci-btn" @click="store.sumar(l.key)" aria-label="Agregar uno">+</button>
            </li>
          </ul>
          <div class="cv__cart-total"><span>Total</span><strong class="cv__num">{{ fmt(store.totalCarrito) }}</strong></div>
          <label v-if="eventos.length" class="cv__evento">
            <span class="cv__evento-lbl">🎉 Evento</span>
            <select v-model="eventoSel" class="cv__evento-sel">
              <option :value="null">Sin evento</option>
              <option v-for="ev in eventos" :key="ev.id" :value="ev.id">{{ ev.nombre }}</option>
            </select>
          </label>
          <div class="cv__pay">
            <button v-for="m in ['efectivo','transferencia','mercado_pago']" :key="m" class="cv__sede-btn" :class="{ 'cv__sede-btn--active': medioPago === m }" @click="medioPago = m">
              {{ m === 'mercado_pago' ? 'QR / MP' : (m === 'transferencia' ? 'Transfer' : 'Efectivo') }}
            </button>
          </div>
          <button class="cv__btn-primary cv__btn-block" :disabled="!store.carrito.length || store.saving" @click="cobrar">Cobrar {{ fmt(store.totalCarrito) }}</button>
          <button v-if="store.carrito.length" class="cv__link cv__link--center" @click="store.vaciar()">Vaciar</button>
        </div>
      </aside>
    </div>

    <BarcodeScanner v-if="escaneando" titulo="Escaneá para agregar al pedido" @decoded="onCamaraDecoded" @close="escaneando = false" />

    <!-- Comprobante (no válido como factura) tras cobrar -->
    <TicketVenta v-if="ticketVenta" :ticket="ticketVenta" :bar="barNombre" :club="clubStore.name" :logo="clubStore.logoUrl" @close="ticketVenta = null" />

    <!-- Historial de ventas: reimprimir comprobante -->
    <div v-if="showHistorial" class="cv__ov" @click.self="showHistorial = false">
      <div class="cv__hist">
        <div class="cv__hist-head">
          <h3>Últimas ventas</h3>
          <button class="cv__hist-x" @click="showHistorial = false" aria-label="Cerrar">×</button>
        </div>
        <div v-if="loadingVentas" class="cv__empty-sm" style="padding:2rem 0;">Cargando…</div>
        <div v-else-if="!ventas.length" class="cv__empty-sm" style="padding:2rem 0;">Todavía no hay ventas.</div>
        <ul v-else class="cv__hist-list">
          <li v-for="v in ventas" :key="v.id" class="cv__hist-row">
            <div class="cv__hist-main">
              <span class="cv__hist-fecha">{{ fechaHora(v.created_at) }}</span>
              <span class="cv__hist-items">{{ (v.items || []).length }} ítem{{ (v.items || []).length !== 1 ? 's' : '' }} · {{ v.medio_pago }}</span>
            </div>
            <span class="cv__hist-total cv__num">{{ fmt(v.total_ars) }}</span>
            <button class="cv__hist-print" @click="reimprimir(v)" title="Reimprimir comprobante">🖨️</button>
            <button
              v-if="esGestion"
              class="cv__hist-del"
              :disabled="borrandoVenta === v.id"
              title="Eliminar venta (devuelve el stock)"
              @click="eliminarVenta(v)"
            >{{ borrandoVenta === v.id ? '⏳' : '🗑️' }}</button>
          </li>
        </ul>
      </div>
    </div>

    <!-- Scan-to-create: producto nuevo con el código ya cargado (admin) -->
    <div v-if="crearForm" class="cv__ov" @click.self="crearForm = null">
      <div class="cv__modal">
        <h3 class="cv__modal-title">Producto nuevo</h3>
        <p class="cv__modal-hint">Ese código no estaba registrado. Cargalo una vez y queda para escanear siempre.</p>
        <div class="cv__code-tag">🏷️ {{ crearForm.codigo_barras }}</div>
        <label class="cv__fld">Nombre<input v-model.trim="crearForm.nombre" class="cv__inp" maxlength="60" placeholder="Ej: Coca Cola 500ml" autofocus /></label>
        <label class="cv__fld">Categoría
          <select v-model="crearForm.categoria_producto_id" class="cv__inp">
            <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nombre }}</option>
          </select>
        </label>
        <label class="cv__fld">Precio de venta<input v-model.number="crearForm.precio_ars" type="number" min="0" step="any" class="cv__inp" placeholder="$" /></label>
        <div class="cv__grid2">
          <label class="cv__fld">Cantidad <small>(opcional)</small><input v-model.number="crearForm.cantidad" type="number" min="0" step="any" class="cv__inp" placeholder="0" /></label>
          <label class="cv__fld">Costo total<input v-model.number="crearForm.costo_total" type="number" min="0" step="any" class="cv__inp" placeholder="$" /></label>
        </div>
        <div class="cv__modal-act">
          <button class="cv__btn-ghost2" @click="crearForm = null">Cancelar</button>
          <button class="cv__btn-primary" :disabled="store.saving" @click="guardarNuevo">Crear producto</button>
        </div>
      </div>
    </div>

    <!-- Precio de venta de un ítem de otro depósito que no lo tiene cargado (solo gestión) -->
    <div v-if="precioForm" class="cv__ov" @click.self="precioForm = null">
      <div class="cv__modal">
        <h3 class="cv__modal-title">Precio de venta</h3>
        <p class="cv__modal-hint">
          <b>{{ precioForm.v.nombre }}</b> está en el depósito {{ DEP_LBL[precioForm.v.deposito] || precioForm.v.deposito }}
          y no tiene precio cargado. Poné a cuánto se vende esta vez.
        </p>
        <label class="cv__fld">Precio por {{ precioForm.v.unidad }}<input v-model.number="precioForm.precio" type="number" min="0" step="any" class="cv__inp" placeholder="$" autofocus @keyup.enter="confirmarPrecio" /></label>
        <div class="cv__modal-act">
          <button class="cv__btn-ghost2" @click="precioForm = null">Cancelar</button>
          <button class="cv__btn-primary" @click="confirmarPrecio">Agregar al pedido</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; color: #0f172a; }
.cv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
.cv__title { font-size: 1.5rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.03em; }
.cv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.cv__header-right { display: flex; gap: .5rem; }
.cv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 10px; font-size: .84rem; font-weight: 500; cursor: pointer; text-decoration: none; }
.cv__btn-ghost:hover { border-color: #cbd5e1; color: #334155; }
.cv__btn-primary { background: #1b5e20; color: #fff; border: none; padding: .75rem 1.25rem; border-radius: 10px; font-size: .95rem; font-weight: 700; cursor: pointer; }
.cv__btn-primary:hover:not(:disabled) { background: #144a18; }
.cv__btn-primary:disabled { opacity: .5; cursor: default; }
.cv__btn-block { width: 100%; }

.cv__pos { display: grid; grid-template-columns: 1fr 320px; gap: 1rem; align-items: start; }
@media (max-width: 780px) { .cv__pos { grid-template-columns: 1fr; } }
.cv__pos-tabs { display: flex; gap: .4rem; margin-bottom: 1rem; flex-wrap: wrap; }
.cv__sede-btn { padding: 7px 14px; border: 1.5px solid #e2e8f0; border-radius: 8px; background: #fff; font-size: 13px; color: #64748b; font-weight: 500; cursor: pointer; }
.cv__sede-btn--active { border-color: #1b5e20; background: rgba(27,94,32,.07); color: #1b5e20; }

/* Buscador + hueco de escáner */
.cv__search { display: flex; align-items: center; gap: .5rem; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .1rem .6rem; margin-bottom: 1rem; }
.cv__search:focus-within { border-color: #1b5e20; }
.cv__search-ic { font-size: .9rem; opacity: .6; }
.cv__search-inp { flex: 1; border: none; outline: none; padding: .6rem .1rem; font-size: .92rem; color: #0f172a; background: transparent; }
.cv__search-clear { border: none; background: #f1f5f9; color: #64748b; width: 22px; height: 22px; border-radius: 50%; cursor: pointer; font-size: 1rem; line-height: 1; }
.cv__scan { border: 1.5px solid #e2e8f0; background: #fff; border-radius: 8px; padding: .35rem .6rem; font-size: 1rem; cursor: pointer; line-height: 1; }
.cv__scan:hover { border-color: #1b5e20; background: #f0fdf4; }

/* Lista de productos (reemplaza el grid) */
.cv__list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .35rem; }
.cv__row { display: grid; grid-template-columns: 1fr auto auto 30px; align-items: center; gap: .9rem; width: 100%; background: #fff; border: 1px solid #e2e8f0; border-radius: 11px; padding: .7rem .9rem; cursor: pointer; text-align: left; transition: border-color .12s; }
.cv__row:hover:not(:disabled) { border-color: #1b5e20; }
.cv__row--off { opacity: .5; cursor: not-allowed; }
.cv__row-main { display: flex; flex-direction: column; gap: .1rem; min-width: 0; }
.cv__row-name { font-weight: 600; color: #0f172a; font-size: .92rem; }
.cv__row-cat { font-size: .72rem; color: #94a3b8; text-transform: capitalize; }
.cv__otros-head { font-size: .68rem; text-transform: uppercase; letter-spacing: .06em; color: #9a5b34; font-weight: 700; margin: 1rem 0 .35rem; padding-top: .8rem; border-top: 1px dashed #e2e8f0; }
.cv__ci-dep { display: block; font-size: .66rem; color: #9a5b34; font-weight: 600; }
.cv__row-price { font-weight: 800; color: #1b5e20; font-size: .95rem; }
.cv__row-stock { font-size: .74rem; color: #94a3b8; white-space: nowrap; min-width: 62px; text-align: right; }
.cv__row-add { width: 30px; height: 30px; border-radius: 8px; background: #f0fdf4; color: #1b5e20; font-size: 1.2rem; font-weight: 700; display: grid; place-items: center; }
.cv__row:disabled .cv__row-add { background: #f1f5f9; color: #cbd5e1; }
.cv__td-red { color: #dc2626; }
.cv__empty-sm { color: #94a3b8; font-size: .82rem; text-align: center; padding: 1rem 0; }

.cv__cart { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; position: sticky; top: 1rem; }
.cv__card-header { padding: .9rem 1.1rem; border-bottom: 1px solid #f1f5f9; }
.cv__card-title { font-size: .9rem; font-weight: 700; color: #0f172a; }
.cv__cart-body { padding: 1rem 1.1rem 1.1rem; }
.cv__cart-list { list-style: none; margin: 0 0 .5rem; padding: 0; display: flex; flex-direction: column; gap: .5rem; }
.cv__ci { display: grid; grid-template-columns: 26px 22px 1fr auto 26px; align-items: center; gap: .5rem; font-size: .86rem; }
.cv__ci-btn { width: 26px; height: 26px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; cursor: pointer; font-weight: 700; color: #334155; line-height: 1; }
.cv__ci-qty { font-weight: 700; text-align: center; color: #0f172a; }
.cv__ci-name { color: #334155; }
.cv__ci-sub { font-weight: 600; color: #0f172a; }
.cv__num { font-variant-numeric: tabular-nums; }
.cv__cart-total { display: flex; justify-content: space-between; align-items: baseline; margin: 1rem 0; padding-top: .9rem; border-top: 1px solid #f1f5f9; }
.cv__cart-total strong { font-size: 1.5rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; }
.cv__evento { display: flex; align-items: center; gap: .5rem; margin-bottom: .6rem; }
.cv__evento-lbl { font-size: .74rem; font-weight: 600; color: #64748b; white-space: nowrap; }
.cv__evento-sel { flex: 1; padding: .4rem .55rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .82rem; background: #fff; color: #0f172a; }
.cv__evento-sel:focus { border-color: #1b5e20; outline: none; }
.cv__pay { display: flex; gap: .35rem; margin-bottom: .9rem; flex-wrap: wrap; }
.cv__pay .cv__sede-btn { flex: 1; padding: 7px 4px; font-size: 12px; text-align: center; }
.cv__link { background: none; border: none; color: #94a3b8; font-size: .82rem; font-weight: 500; cursor: pointer; }
.cv__link--center { display: block; width: 100%; text-align: center; margin-top: .5rem; }
.cv__link:hover { color: #64748b; }

/* Modal scan-to-create */
.cv__ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1100; padding: 1rem; }
.cv__modal { background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 400px; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.cv__modal-title { margin: 0 0 .25rem; font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; color: #0f172a; }
.cv__modal-hint { color: #64748b; font-size: .82rem; margin: 0 0 .9rem; line-height: 1.45; }
.cv__code-tag { display: inline-block; background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; border-radius: 8px; padding: .3rem .7rem; font-size: .82rem; font-weight: 700; font-variant-numeric: tabular-nums; margin-bottom: 1rem; }
.cv__fld { display: flex; flex-direction: column; gap: .3rem; font-size: .8rem; color: #475569; font-weight: 600; margin-bottom: .8rem; }
.cv__fld small { color: #94a3b8; font-weight: 400; }
.cv__grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: .7rem; }
.cv__inp { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .75rem; font-size: .9rem; color: #0f172a; outline: none; }
.cv__inp:focus { border-color: #1b5e20; }
.cv__modal-act { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; }
.cv__btn-ghost2 { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .55rem 1rem; border-radius: 9px; font-size: .85rem; font-weight: 600; cursor: pointer; }
.cv__btn-ghost2:hover { background: #f8fafc; }

/* Botón "Ventas" + historial */
.cv__card-header { display: flex; align-items: center; justify-content: space-between; }
.cv__hist-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .3rem .6rem; font-size: .76rem; font-weight: 600; color: #64748b; cursor: pointer; }
.cv__hist-btn:hover { border-color: #1b5e20; color: #1b5e20; }
.cv__hist { background: #fff; border-radius: 16px; padding: 1.2rem 1.3rem 1.3rem; width: 100%; max-width: 420px; max-height: 80vh; overflow-y: auto; box-shadow: 0 20px 50px rgb(15 23 42 / .25); }
.cv__hist-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: .8rem; }
.cv__hist-head h3 { margin: 0; font-size: 1.05rem; font-weight: 750; color: #0f172a; }
.cv__hist-x { background: none; border: none; font-size: 1.5rem; line-height: 1; color: #94a3b8; cursor: pointer; }
.cv__hist-x:hover { color: #334155; }
.cv__hist-list { list-style: none; margin: 0; padding: 0; }
.cv__hist-row { display: grid; grid-template-columns: 1fr auto auto; align-items: center; gap: .7rem; padding: .6rem 0; border-bottom: 1px solid #f1f5f9; }
.cv__hist-row:last-child { border-bottom: none; }
.cv__hist-main { display: flex; flex-direction: column; min-width: 0; }
.cv__hist-fecha { font-size: .84rem; color: #0f172a; font-weight: 550; }
.cv__hist-items { font-size: .72rem; color: #94a3b8; text-transform: capitalize; }
.cv__hist-total { font-weight: 700; color: #0f172a; }
.cv__hist-print { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: .35rem .55rem; font-size: 1rem; cursor: pointer; line-height: 1; }
.cv__hist-print:hover { background: #dcfce7; }
.cv__hist-del { background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; padding: .35rem .55rem; font-size: 1rem; cursor: pointer; line-height: 1; }
.cv__hist-del:hover:not(:disabled) { background: #fee2e2; }
.cv__hist-del:disabled { opacity: .6; cursor: default; }
</style>
