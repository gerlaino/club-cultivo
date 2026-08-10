<script setup>
// Depósito — módulo operativo de inventario valorizado. Todo se resuelve acá, sin saltar a
// Contabilidad: Entrada (compra → genera el asiento), Consumir (imputa costo a lote/sala o gasto),
// Reconteo (ajusta al conteo físico: corrección de dato o merma), Editar, Desactivar/Eliminar,
// Historial (con reversión de compra). El Salón (bar, vendible) vive en su propio componente.
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useInsumosStore } from '../../stores/insumos.js'
import { useSedeStore } from '../../stores/sede.js'
import { listLotes, listSalas, listCategoriasContables, getInsumo, listDepositos, createDeposito, updateDeposito, deleteDeposito, listUnidadesNegocio } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import DepositoDispensacion from './DepositoDispensacion.vue'
import DepositoSalon from './DepositoSalon.vue'

const store = useInsumosStore()
const sede  = useSedeStore()
const toast = useToast()
const { confirm } = useConfirm()

// Foco programático (evita el warning "Autofocus processing was blocked" del atributo autofocus).
const vFocus = { mounted: (el) => el.focus() }

const UNIDADES = ['unidad', 'litro', 'mililitro', 'kilogramo', 'gramo', 'bolsa', 'metro', 'otro']
const lotes = ref([])
const salas = ref([])
const categorias = ref([])          // árbol contable (para el alta y las etiquetas de grupo)
const mostrarInactivos = ref(false)  // los insumos desactivados quedan ocultos por defecto

const hoyISO = () => new Date().toISOString().slice(0, 10)
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

// ── Depósitos (dinámicos: sistema + los que crea el admin) ────────────────────
const depositos = ref([])
const depositoActivoId = ref(null)
// El hub muestra TODOS los depósitos (panorama). Los que tienen otro dueño se ven read-only:
// Salón (se opera desde el bar) y Dispensación (su stock viene de cosecha/manicura).
// Multi-sede: los depósitos son por sede. Si hay una sede elegida, mostramos solo los suyos
// (+ los custom club-wide sin sede); con "Todo el club" se ven todos, con la sede en la etiqueta.
const TABS = computed(() => {
  if (sedeFiltro.value == null) return depositos.value
  return depositos.value.filter(d => d.sede_id === sedeFiltro.value || d.sede_id == null)
})
// Dos tabs no pueden leerse igual: si el mismo nombre aparece más de una vez (dos sedes, o un
// legacy sin sede que quedó sin migrar), se desambigua siempre con la sede. Sin esto los depósitos
// por sede se leían como duplicados sin explicación.
const nombreRepetido = (d) => TABS.value.filter(x => x.nombre === d.nombre).length > 1
const tabLabel = (d) => {
  const mostrarSede = nombreRepetido(d) || (sedeFiltro.value == null && multiSede.value && d.sede_nombre)
  return mostrarSede ? `${d.nombre} · ${d.sede_nombre || 'sin sede'}` : d.nombre
}
const depositoActivo = computed(() => TABS.value.find(d => d.id === depositoActivoId.value) || TABS.value[0] || null)
const esSalon        = computed(() => depositoActivo.value?.clave_sistema === 'salon')
const esDispensacion = computed(() => depositoActivo.value?.clave_sistema === 'dispensacion')
const esCultivo      = computed(() => depositoActivo.value?.familia === 'insumo')
// Read-only: se ven pero no se gestionan acá (tienen otro dueño en la app).
const esSoloLectura  = computed(() => esSalon.value || esDispensacion.value)
const HINTS = {
  insumo:         'Fertilizantes, sustrato… se consumen imputando el costo al lote.',
  insumo_general: 'Insumos del club (limpieza, administración). Se consumen como gasto.',
  mercaderia:     'Mercadería vendible: stock con costo, valorizado y alertas de reposición.',
}
const depositoHint = computed(() =>
  esDispensacion.value ? 'Flor seca y derivados listos para dispensar. Solo lectura: entra por cosecha/manicura, sale por dispensación.'
  : (HINTS[depositoActivo.value?.familia] || ''))

// Categorías (egreso) elegibles al dar de alta en el depósito activo: las del ÁREA del depósito.
// Si el depósito no tiene sector, se muestran todas (para no perder ninguna).
const categoriasDelTab = computed(() => {
  const areaId = depositoActivo.value?.unidad_negocio_id
  const areaDe = (c) => c.unidad_negocio?.id ?? c.unidad_negocio_id ?? null
  const coincide = (c, fallback = null) => !areaId || (areaDe(c) ?? fallback) === areaId
  const out = []
  for (const m of categorias.value) {
    if (m.tipo !== 'egreso') continue
    const subs = m.subcategorias || []
    if (subs.length) {
      for (const s of subs) if (coincide(s, areaDe(m))) out.push({ id: s.id, label: `${m.nombre} › ${s.nombre}` })
    } else if (coincide(m)) {
      out.push({ id: m.id, label: m.nombre })
    }
  }
  return out
})

// El depósito es transversal a la sede. Filtro LOCAL de productos por sede (null = todo el club).
const sedeFiltro = ref(null)
// Las sedes salen del store; si no llegaron (falló listSedes o el rol no las lista), se derivan de
// los propios depósitos. Sin esto el club se veía como mono-sede: sin filtro y con los tabs por
// sede sin etiqueta, o sea "duplicados".
const sedesOpciones = computed(() => {
  if (sede.sedes.length) return sede.sedes
  const m = new Map()
  for (const d of depositos.value) {
    if (d.sede_id && !m.has(d.sede_id)) m.set(d.sede_id, { id: d.sede_id, nombre: d.sede_nombre || `Sede ${d.sede_id}` })
  }
  return [...m.values()]
})
const multiSede = computed(() => sedesOpciones.value.length > 1)
const otrasSedes = computed(() => sedesOpciones.value.filter(s => s.id !== sedeFiltro.value))

watch(TABS, (tabs) => {
  if (!tabs.some(d => d.id === depositoActivoId.value)) depositoActivoId.value = tabs[0]?.id ?? null
})

async function cargarDepositos() {
  try { const { data } = await listDepositos(); depositos.value = data || [] }
  catch { depositos.value = [] }
  if (!depositoActivoId.value && TABS.value.length) depositoActivoId.value = TABS.value[0].id
}

// ── Crear depósito propio ─────────────────────────────────────
// Sectores (unidades de negocio) para vincular el depósito → el movimiento hereda el sector.
const areas = ref([])
async function cargarAreas() { try { areas.value = (await listUnidadesNegocio()).data || [] } catch { areas.value = [] } }
const depoForm = ref(null)
const savingDepo = ref(false)
function abrirNuevoDeposito() { depoForm.value = { nombre: '', unidad_negocio_id: null } }
async function confirmarNuevoDeposito() {
  if (!depoForm.value.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  savingDepo.value = true
  try {
    const { data } = await createDeposito({ nombre: depoForm.value.nombre.trim(), unidad_negocio_id: depoForm.value.unidad_negocio_id })
    await cargarDepositos()
    depositoActivoId.value = data.id
    depoForm.value = null
    toast.success('Depósito creado')
  } catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo crear') }
  finally { savingDepo.value = false }
}

// ── Gestionar depósito (renombrar / desactivar / eliminar) ────
const depoEdit = ref(null) // { id, nombre, es_sistema, activo }
function abrirEditarDeposito() {
  const d = depositoActivo.value
  if (!d) return
  depoEdit.value = { id: d.id, nombre: d.nombre, es_sistema: d.es_sistema, activo: d.activo, unidad_negocio_id: d.unidad_negocio_id }
}
async function guardarDeposito() {
  const d = depoEdit.value
  if (!d.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  savingDepo.value = true
  try {
    await updateDeposito(d.id, { nombre: d.nombre.trim(), activo: d.activo, unidad_negocio_id: d.unidad_negocio_id })
    await cargarDepositos()
    depoEdit.value = null
    toast.success('Depósito actualizado')
  } catch (e) { toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo guardar') }
  finally { savingDepo.value = false }
}
async function eliminarDeposito() {
  const d = depoEdit.value
  const ok = await confirm({
    title: `Eliminar depósito "${d.nombre}"`,
    message: 'Se elimina el depósito. Solo se puede si no tiene productos; si los tiene, movelos a otro depósito o desactivalo.',
    confirmText: 'Eliminar', variant: 'danger',
  })
  if (!ok) return
  savingDepo.value = true
  try {
    await deleteDeposito(d.id)
    depoEdit.value = null
    depositoActivoId.value = null
    await cargarDepositos()
    depositoActivoId.value = TABS.value[0]?.id ?? null
    await recargar()
    toast.success('Depósito eliminado')
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo eliminar') }
  finally { savingDepo.value = false }
}

// ── Tabla de productos: búsqueda + filtro por categoría del depósito ──────────
const busqueda = ref('')
const filtroCategoria = ref(null) // null = todas
function catLabel(i) {
  const c = i.categoria
  return c ? (c.sub_nombre ? `${c.madre_nombre} › ${c.sub_nombre}` : c.madre_nombre) : 'Sin categoría'
}
const itemsVisibles = computed(() => store.items.filter(i => mostrarInactivos.value || i.activo))
const hayInactivos  = computed(() => store.items.some(i => !i.activo))
// Categorías realmente presentes en este depósito (para las chips de filtro).
const categoriasDelDeposito = computed(() =>
  [...new Set(itemsVisibles.value.map(catLabel))]
    .sort((a, b) => (a === 'Sin categoría' ? 1 : b === 'Sin categoría' ? -1 : a.localeCompare(b))))
const itemsFiltrados = computed(() => {
  const q = busqueda.value.trim().toLowerCase()
  return itemsVisibles.value
    .filter(i => !filtroCategoria.value || catLabel(i) === filtroCategoria.value)
    .filter(i => !q || i.nombre.toLowerCase().includes(q))
    .sort((a, b) => catLabel(a).localeCompare(catLabel(b)) || a.nombre.localeCompare(b.nombre))
})
const valorizadoFiltrado = computed(() => itemsFiltrados.value.reduce((a, i) => a + (i.valorizado_ars || 0), 0))
// Al cambiar de depósito, limpiar los filtros.
watch(depositoActivoId, () => { filtroCategoria.value = null; busqueda.value = '' })

async function recargar() {
  if (esSoloLectura.value || !depositoActivoId.value) return
  await store.fetch({ sede_id: sedeFiltro.value ?? undefined, deposito_id: depositoActivoId.value })
}

onMounted(async () => {
  if (!sede.loaded) await sede.fetchSedes()
  await cargarDepositos()
  cargarAreas()
  await recargar()
  listLotes({ estado: 'activos' }).then(r => { lotes.value = r.data?.lotes || r.data || [] }).catch(() => {})
  listSalas().then(r => { salas.value = r.data || [] }).catch(() => {})
  listCategoriasContables().then(r => { categorias.value = r.data || [] }).catch(() => {})
  window.addEventListener('click', cerrarMenu)
})
onUnmounted(() => window.removeEventListener('click', cerrarMenu))
watch([sedeFiltro, depositoActivoId], recargar)

// Resumen EN VIVO del depósito (se recalcula al consumir/eliminar, no queda pegado al fetch).
const resumenDeposito = computed(() => {
  const act = store.items.filter(i => i.activo)
  return {
    valorizado: act.reduce((a, i) => a + (i.valorizado_ars || 0), 0),
    productos:  act.length,
    bajoStock:  act.filter(i => i.stock_bajo).length,
  }
})

// ── Menú de acciones por ítem (kebab) ─────────────────────────
const menuId = ref(null)
const menuPos = ref({ top: 0, left: 0 })
function toggleMenu(id, ev) {
  ev.stopPropagation()
  if (menuId.value === id) { menuId.value = null; return }
  const r = ev.currentTarget.getBoundingClientRect()
  // Menú posicionado (fixed) para que no lo recorte el overflow de la tabla.
  menuPos.value = { top: r.bottom + 4, left: Math.max(8, r.right - 210) }
  menuId.value = id
}
function cerrarMenu() { menuId.value = null }

// ── Entrada (compra con costo → genera el egreso contable) ────
// Modal estilo "Nuevo movimiento" pero scopeado al depósito activo.
const entradaForm = ref(null)
function abrirEntrada(insumo = null) {
  cerrarMenu()
  entradaForm.value = {
    modo: insumo ? 'existente' : (store.items.length ? 'existente' : 'nuevo'),
    insumo_id: insumo?.id ?? store.items[0]?.id ?? null,
    nombre: '', unidad_medida: 'unidad', categoria_contable_id: categoriasDelTab.value[0]?.id ?? null,
    cantidad: null, costo_total_ars: null, proveedor: '', fecha: hoyISO(),
    sede_id: insumo?.sede_id ?? sedeFiltro.value ?? null,
    medio_pago: 'efectivo', pagado: true,
  }
}
const MEDIOS_PAGO = [
  { v: 'efectivo', l: 'Efectivo' }, { v: 'transferencia', l: 'Transferencia' }, { v: 'mercado_pago', l: 'Mercado Pago' },
]
const entradaInsumoSel = computed(() => store.items.find(i => i.id === entradaForm.value?.insumo_id) || null)
const entradaUnidad = computed(() =>
  entradaForm.value?.modo === 'existente' ? (entradaInsumoSel.value?.unidad_medida || 'u') : entradaForm.value?.unidad_medida)
const entradaCostoUnit = computed(() => {
  const f = entradaForm.value
  return f?.cantidad > 0 && f?.costo_total_ars >= 0 ? f.costo_total_ars / f.cantidad : null
})
async function confirmarEntrada() {
  const f = entradaForm.value
  if (f.modo === 'nuevo' && !f.nombre.trim()) { toast.warning('Poné el nombre del insumo'); return }
  if (f.modo === 'existente' && !f.insumo_id) { toast.warning('Elegí el insumo'); return }
  if (!(f.cantidad > 0)) { toast.warning('Poné la cantidad'); return }
  if (!(f.costo_total_ars >= 0)) { toast.warning('Poné el costo total'); return }
  try {
    let id = f.insumo_id
    if (f.modo === 'nuevo') {
      const nuevo = await store.crear({
        nombre: f.nombre.trim(), unidad_medida: f.unidad_medida,
        categoria_contable_id: f.categoria_contable_id, sede_id: f.sede_id,
        deposito_id: depositoActivoId.value,
        tipo: esCultivo.value ? 'cultivo' : 'general', // compat con el enum viejo hasta unificar en Producto
      })
      id = nuevo.id
    }
    await store.comprar(id, {
      cantidad: f.cantidad, costo_total_ars: f.costo_total_ars,
      proveedor: f.proveedor?.trim() || undefined, fecha: f.fecha,
      sede_id: f.sede_id ?? undefined, generar_egreso: true,
      medio_pago: f.medio_pago, pagado: f.pagado,
    })
    toast.success('Entrada registrada · egreso contable generado')
    entradaForm.value = null
    await recargar()
  } catch { toast.error(store.saveError) }
}

// ── Consumir (repartible entre varios lotes) ──────────────────
const consumoForm = ref(null)
function abrirConsumo(i) { cerrarMenu(); consumoForm.value = { insumo: i, cantidad: null, lote_ids: [], sala_id: null } }
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

// ── Reconteo (ajuste al conteo físico) ────────────────────────
const reconteoForm = ref(null) // { insumo, contado, motivo, notas }
function abrirReconteo(i) { cerrarMenu(); reconteoForm.value = { insumo: i, contado: i.stock_actual, motivo: 'correccion', notas: '' } }
const reconteoDiff = computed(() => {
  const f = reconteoForm.value
  if (!f || f.contado === null || f.contado === '') return null
  return Number(f.contado) - f.insumo.stock_actual
})
async function confirmarReconteo() {
  const f = reconteoForm.value
  if (f.contado === null || f.contado === '' || Number(f.contado) < 0) { toast.warning('Poné el stock contado'); return }
  if (f.motivo === 'merma' && Number(f.contado) > f.insumo.stock_actual) {
    toast.warning('La merma solo baja el stock. Si contaste de más, es una corrección.'); return
  }
  try {
    await store.reconteo(f.insumo.id, { nuevo_stock: Number(f.contado), motivo: f.motivo, notas: f.notas?.trim() || undefined })
    toast.success('Inventario ajustado'); reconteoForm.value = null
  } catch { toast.error(store.saveError) }
}

// ── Editar (nombre, categoría, unidad, mínimo) ────────────────
const editForm = ref(null)
function editarInsumo(i) {
  cerrarMenu()
  editForm.value = {
    id: i.id, nombre: i.nombre,
    categoria_contable_id: i.categoria_contable_id ?? null,
    unidad_medida: i.unidad_medida, stock_minimo: i.stock_minimo ?? 0,
  }
}
async function guardarEdit() {
  const f = editForm.value
  if (!f.nombre?.trim()) { toast.warning('Poné un nombre'); return }
  try {
    await store.actualizar(f.id, {
      nombre: f.nombre.trim(), categoria_contable_id: f.categoria_contable_id,
      unidad_medida: f.unidad_medida, stock_minimo: f.stock_minimo,
    })
    toast.success('Insumo actualizado'); editForm.value = null
    await recargar()
  } catch { toast.error(store.saveError) }
}

// ── Desactivar / Activar / Eliminar ───────────────────────────
async function toggleActivo(i) {
  cerrarMenu()
  const activar = !i.activo
  try {
    await store.actualizar(i.id, { activo: activar })
    toast.success(activar ? 'Insumo reactivado' : 'Insumo desactivado')
  } catch { toast.error(store.saveError) }
}
async function eliminarInsumo(i) {
  cerrarMenu()
  const ok = await confirm({
    title: `Eliminar ${i.nombre}`,
    message: 'Se elimina el insumo por completo y se revierten los asientos de sus compras (la plata vuelve). Solo se puede si no tuvo consumos ni mermas; si los tuvo, desactivalo en su lugar.',
    confirmText: 'Eliminar', variant: 'danger',
  })
  if (!ok) return
  try {
    await store.eliminar(i.id)
    toast.success('Insumo eliminado')
  } catch { toast.error(store.saveError) }
}

// ── Transferir a otro depósito (reclasificación de stock, sin egreso) ─────────
// Destinos válidos: cualquier otro depósito de insumos (no flor/salón, familia 'mercaderia').
const depositosDestino = computed(() => depositos.value.filter(d => d.id !== depositoActivo.value?.id && d.familia !== 'mercaderia' && d.activo))
const depLabel = (d) => d.sede_nombre ? `${d.nombre} · 📍 ${d.sede_nombre}` : d.nombre
const transferForm = ref(null)
function abrirTransfer(i) { cerrarMenu(); transferForm.value = { insumo: i, deposito_destino_id: depositosDestino.value[0]?.id ?? null, cantidad: null } }
async function confirmarTransfer() {
  const f = transferForm.value
  if (!f.deposito_destino_id) { toast.warning('Elegí el depósito destino'); return }
  if (!(f.cantidad > 0)) { toast.warning('Poné la cantidad a transferir'); return }
  if (f.cantidad > f.insumo.stock_actual) { toast.warning('No hay stock suficiente'); return }
  try {
    await store.transferirDeposito(f.insumo.id, { deposito_destino_id: f.deposito_destino_id, cantidad: f.cantidad })
    toast.success('Transferencia registrada'); transferForm.value = null
    await recargar()
  } catch { toast.error(store.saveError) }
}

// ── Historial (compras + consumos) con reversión de compra ────
const hist = ref(null)
async function abrirHistorial(i) {
  cerrarMenu()
  hist.value = { insumo: i, compras: [], consumos: [], loading: true }
  try {
    const { data } = await getInsumo(i.id)
    if (hist.value) { hist.value.compras = data.compras || []; hist.value.consumos = data.consumos || [] }
  } catch { toast.error('No se pudo cargar el historial') }
  finally { if (hist.value) hist.value.loading = false }
}
async function revertirCompra(compra) {
  const ok = await confirm({
    title: 'Revertir compra',
    message: `Se descontará ${compra.cantidad} ${hist.value.insumo.unidad_medida} del depósito y se borrará el asiento contable asociado. Solo se puede si esa mercadería no fue consumida ni transferida.`,
    confirmText: 'Revertir', variant: 'danger',
  })
  if (!ok) return
  try {
    await store.revertirCompra(hist.value.insumo.id, compra.id)
    toast.success('Compra revertida')
    await abrirHistorial(store.items.find(i => i.id === hist.value.insumo.id) || hist.value.insumo)
    await recargar()
  } catch { toast.error(store.saveError) }
}
</script>

<template>
  <div class="dp">
    <header class="dp__head">
      <div>
        <h1 class="dp__title">Depósito</h1>
        <p class="dp__sub">{{ depositoHint }}</p>
      </div>
      <div class="dp__head-right">
        <select v-if="multiSede" v-model="sedeFiltro" class="dp__sede-filtro">
          <option :value="null">🏢 Todo el club</option>
          <option v-for="s in sedesOpciones" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <!-- Los productos NUEVOS entran por Contabilidad → Nuevo Movimiento (ahí elegís el depósito).
             Acá solo se gestiona lo que ya existe (reponer/editar/merma/eliminar). -->
        <RouterLink v-if="!esSoloLectura" :to="{ name: 'contabilidad', query: { nuevo: 'compra', deposito: depositoActivo?.id } }" class="btn btn--primary" title="Registrar la compra: el gasto y la entrada al depósito en un paso">＋ Comprar</RouterLink>
      </div>
    </header>

    <div class="dp__tabs">
      <button v-for="d in TABS" :key="d.id" class="dp__tab" :class="{ 'is-on': depositoActivo?.id === d.id }" @click="depositoActivoId = d.id">
        {{ tabLabel(d) }}
      </button>
      <button v-if="depositoActivo && !esSoloLectura && !depositoActivo.es_sistema" class="dp__tab dp__tab--add" title="Gestionar este depósito" @click="abrirEditarDeposito">⚙</button>
      <button class="dp__tab dp__tab--add" title="Crear un depósito" @click="abrirNuevoDeposito">＋</button>
    </div>

    <!-- Sector a la que pertenece este depósito (a dónde va su plata en el P&L) -->
    <p v-if="depositoActivo && !esSoloLectura" class="dp__area-line">
      <span class="dp__area-chip">🏷️ Sector: {{ depositoActivo.area_nombre || 'sin sector' }}</span>
    </p>

    <!-- Resumen en vivo del depósito activo -->
    <div v-if="!esSoloLectura && store.items.length" class="dp__summary">
      <div class="dp__kpi">
        <span class="dp__kpi-label">Valorizado</span>
        <span class="dp__kpi-val">{{ fmt(resumenDeposito.valorizado) }}</span>
      </div>
      <div class="dp__kpi">
        <span class="dp__kpi-label">Productos</span>
        <span class="dp__kpi-val">{{ resumenDeposito.productos }}</span>
      </div>
      <div class="dp__kpi" :class="{ 'dp__kpi--warn': resumenDeposito.bajoStock }">
        <span class="dp__kpi-label">Bajo stock</span>
        <span class="dp__kpi-val">{{ resumenDeposito.bajoStock }}</span>
      </div>
    </div>

    <DepositoSalon v-if="esSalon" :sede-id="depositoActivo?.sede_id ?? sedeFiltro" />
    <DepositoDispensacion v-else-if="esDispensacion" :sede-id="depositoActivo?.sede_id ?? sedeFiltro" />

    <template v-else>
    <div v-if="store.loading" class="dp__empty">Cargando depósito…</div>
    <div v-else-if="!store.items.length" class="dp__empty dp__empty--box">
      Todavía no hay productos en este depósito. Se cargan comprándolos desde
      <RouterLink :to="{ name: 'contabilidad' }" class="dp__link">Contabilidad → Nuevo movimiento</RouterLink>
      (ahí elegís el depósito destino y se genera el egreso). Después, acá los reponés y gestionás.
    </div>

    <template v-else>
      <!-- Toolbar: búsqueda + filtro por categoría del depósito -->
      <div class="dp__toolbar">
        <div class="dp__search">
          <i class="bi bi-search"></i>
          <input v-model.trim="busqueda" type="text" placeholder="Buscar producto…" />
        </div>
        <div v-if="categoriasDelDeposito.length > 1" class="dp__chips">
          <button class="dp__chip" :class="{ 'is-on': !filtroCategoria }" @click="filtroCategoria = null">Todas</button>
          <button v-for="c in categoriasDelDeposito" :key="c" class="dp__chip" :class="{ 'is-on': filtroCategoria === c }" @click="filtroCategoria = c">{{ c }}</button>
        </div>
        <label v-if="hayInactivos" class="dp__chk"><input type="checkbox" v-model="mostrarInactivos" /> Ver desactivados</label>
      </div>

      <div v-if="!itemsFiltrados.length" class="dp__empty dp__empty--box">
        No hay productos que coincidan con el filtro.
      </div>

      <!-- Tabla de productos -->
      <div v-else class="dp__table-wrap">
        <table class="dp__table">
          <thead>
            <tr>
              <th>Producto</th>
              <th>Categoría</th>
              <th v-if="multiSede">Sede</th>
              <th class="ta-r">Stock</th>
              <th class="ta-r">Costo/u</th>
              <th class="ta-r">Valorizado</th>
              <th class="ta-r">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="i in itemsFiltrados" :key="i.id" :class="{ 'is-off': !i.activo }">
              <td>
                <span class="dp__name">{{ i.nombre }}</span>
                <span v-if="!i.activo" class="dp__pill dp__pill--off">Desactivado</span>
                <span v-if="i.stock_bajo && i.activo" class="dp__pill">Reponer</span>
              </td>
              <td class="dp__cat">{{ catLabel(i) }}</td>
              <td v-if="multiSede" class="mut">{{ i.sede_nombre || '—' }}</td>
              <td class="ta-r num"><b :class="{ low: i.stock_bajo }">{{ i.stock_actual }}</b> <small class="mut">{{ i.unidad_medida }}</small></td>
              <td class="ta-r num mut">{{ fmt(i.costo_promedio_ars) }}</td>
              <td class="ta-r num">{{ fmt(i.valorizado_ars) }}</td>
              <td class="ta-r">
                <div class="dp__row-actions">
                  <button class="btn btn--sm btn--primary" @click="abrirConsumo(i)" :disabled="i.stock_actual <= 0 || !i.activo">Consumir</button>
                  <div class="dp__menu-wrap">
                    <button class="btn btn--sm btn--icon" @click="toggleMenu(i.id, $event)" title="Más acciones">⋯</button>
                    <div v-if="menuId === i.id" class="dp__menu" :style="{ top: menuPos.top + 'px', left: menuPos.left + 'px' }" @click.stop>
                      <button class="dp__menu-item" @click="abrirEntrada(i)">Reponer</button>
                      <button class="dp__menu-item" @click="abrirReconteo(i)">Reconteo / Merma</button>
                      <button v-if="depositosDestino.length" class="dp__menu-item" @click="abrirTransfer(i)" :disabled="i.stock_actual <= 0">Transferir a otro depósito</button>
                      <button class="dp__menu-item" @click="abrirHistorial(i)">Historial</button>
                      <button class="dp__menu-item" @click="editarInsumo(i)">Editar</button>
                      <div class="dp__menu-sep"></div>
                      <button class="dp__menu-item" @click="toggleActivo(i)">{{ i.activo ? 'Desactivar' : 'Reactivar' }}</button>
                      <button class="dp__menu-item dp__menu-item--danger" @click="eliminarInsumo(i)">Eliminar</button>
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr>
              <td :colspan="multiSede ? 5 : 4"></td>
              <td class="ta-r num dp__total">{{ fmt(valorizadoFiltrado) }}</td>
              <td></td>
            </tr>
          </tfoot>
        </table>
      </div>
    </template>
    </template>

    <!-- Modal ENTRADA (compra con costo → egreso) -->
    <div v-if="entradaForm" class="ov" @click.self="entradaForm = null">
      <div class="dpdlg dpdlg--wide">
        <h3 class="modal__title">Reponer stock</h3>
        <p class="modal__hint">Registrás una reposición con su costo. Se suma al depósito y genera el <b>egreso contable</b>. Para un producto <b>nuevo</b>, compralo desde Contabilidad → Nuevo movimiento.</p>

        <template v-if="entradaForm.modo === 'existente'">
          <label class="fld">Insumo
            <select v-model="entradaForm.insumo_id" class="inp">
              <option v-for="i in store.items" :key="i.id" :value="i.id">{{ i.nombre }}<template v-if="multiSede"> · {{ i.sede_nombre || 'pool' }}</template></option>
            </select>
          </label>
        </template>
        <template v-else>
          <label class="fld">Nombre<input v-model.trim="entradaForm.nombre" class="inp" maxlength="60" placeholder="Ej: Fertilizante base" /></label>
          <div class="dp__grid2">
            <label class="fld">Unidad<select v-model="entradaForm.unidad_medida" class="inp"><option v-for="u in UNIDADES" :key="u" :value="u">{{ u }}</option></select></label>
            <label class="fld">Categoría
              <select v-model="entradaForm.categoria_contable_id" class="inp">
                <option :value="null">— Sin categoría —</option>
                <option v-for="c in categoriasDelTab" :key="c.id" :value="c.id">{{ c.label }}</option>
              </select>
            </label>
          </div>
        </template>

        <div class="dp__grid2">
          <label class="fld">Cantidad ({{ entradaUnidad }})<input v-model.number="entradaForm.cantidad" type="number" min="0" step="any" class="inp" /></label>
          <label class="fld">Costo total ($)<input v-model.number="entradaForm.costo_total_ars" type="number" min="0" step="any" class="inp" /></label>
        </div>
        <p v-if="entradaCostoUnit !== null" class="dp__hintline">Costo unitario: <b>{{ fmt(entradaCostoUnit) }}</b> / {{ entradaUnidad }}</p>
        <div class="dp__grid2">
          <label class="fld">Proveedor (opcional)<input v-model.trim="entradaForm.proveedor" class="inp" maxlength="80" /></label>
          <label class="fld">Fecha<input v-model="entradaForm.fecha" type="date" class="inp" /></label>
        </div>
        <div class="dp__grid2">
          <label class="fld">Forma de pago
            <select v-model="entradaForm.medio_pago" class="inp"><option v-for="m in MEDIOS_PAGO" :key="m.v" :value="m.v">{{ m.l }}</option></select>
          </label>
          <label class="fld">Estado del pago
            <select v-model="entradaForm.pagado" class="inp"><option :value="true">Pagado</option><option :value="false">Pendiente de pago</option></select>
          </label>
        </div>
        <label v-if="multiSede" class="fld">Sede
          <select v-model="entradaForm.sede_id" class="inp">
            <option :value="null">🏢 Pool del club</option>
            <option v-for="s in sedesOpciones" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>

        <div class="modal__actions"><button class="btn" @click="entradaForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarEntrada">Registrar entrada</button></div>
      </div>
    </div>

    <!-- Modal RECONTEO -->
    <div v-if="reconteoForm" class="ov" @click.self="reconteoForm = null">
      <div class="dpdlg">
        <h3 class="modal__title">Reconteo — {{ reconteoForm.insumo.nombre }}</h3>
        <p class="modal__hint">El sistema tiene <b>{{ reconteoForm.insumo.stock_actual }} {{ reconteoForm.insumo.unidad_medida }}</b>. Poné cuánto contaste físicamente y elegí por qué no coincide.</p>

        <label class="fld">Stock contado ({{ reconteoForm.insumo.unidad_medida }})
          <input v-model.number="reconteoForm.contado" type="number" min="0" step="any" class="inp" />
        </label>
        <p v-if="reconteoDiff !== null && reconteoDiff !== 0" class="dp__hintline" :class="{ 'dp__hintline--neg': reconteoDiff < 0 }">
          Diferencia: {{ reconteoDiff > 0 ? '+' : '' }}{{ reconteoDiff }} {{ reconteoForm.insumo.unidad_medida }}
        </p>

        <div class="dp__reasons">
          <label class="dp__reason" :class="{ 'is-on': reconteoForm.motivo === 'correccion' }">
            <input type="radio" value="correccion" v-model="reconteoForm.motivo" />
            <span><b>Corrección de carga</b><small>Me equivoqué al cargar la cantidad. Solo corrige el dato, no toca la contabilidad.</small></span>
          </label>
          <label class="dp__reason" :class="{ 'is-on': reconteoForm.motivo === 'merma' }">
            <input type="radio" value="merma" v-model="reconteoForm.motivo" />
            <span><b>Merma / pérdida</b><small>Se rompió, venció o se perdió. Descuenta el faltante y queda registrado como merma.</small></span>
          </label>
        </div>

        <label class="fld">Nota (opcional)<input v-model.trim="reconteoForm.notas" class="inp" maxlength="120" placeholder="Ej: bolsa rota, humedad…" /></label>
        <div class="modal__actions"><button class="btn" @click="reconteoForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarReconteo">Ajustar inventario</button></div>
      </div>
    </div>

    <!-- Modal HISTORIAL -->
    <div v-if="hist" class="ov" @click.self="hist = null">
      <div class="dpdlg dpdlg--wide">
        <h3 class="modal__title">Historial — {{ hist.insumo.nombre }}</h3>
        <p class="modal__hint">Stock actual: <b>{{ hist.insumo.stock_actual }} {{ hist.insumo.unidad_medida }}</b>. Revertir una compra descuenta su stock y borra el asiento contable (solo si no se consumió/transfirió).</p>

        <div v-if="hist.loading" class="dp__empty">Cargando…</div>
        <template v-else>
          <h4 class="dp__h4">Entradas</h4>
          <ul v-if="hist.compras.length" class="dp__hist">
            <li v-for="c in hist.compras" :key="c.id" class="dp__hrow">
              <div>
                <span class="dp__hqty num">{{ c.cantidad }} {{ hist.insumo.unidad_medida }}</span>
                <span class="dp__hmeta">{{ fmt(c.costo_total_ars) }} · {{ c.fecha }}<template v-if="c.proveedor"> · {{ c.proveedor }}</template></span>
              </div>
              <button class="btn btn--sm btn--danger" :disabled="store.saving" @click="revertirCompra(c)">Revertir</button>
            </li>
          </ul>
          <p v-else class="mut dp__hempty">Sin entradas registradas.</p>

          <h4 class="dp__h4">Salidas (consumos y mermas)</h4>
          <ul v-if="hist.consumos.length" class="dp__hist">
            <li v-for="c in hist.consumos" :key="c.id" class="dp__hrow">
              <div>
                <span class="dp__hqty num">−{{ c.cantidad }} {{ hist.insumo.unidad_medida }}</span>
                <span class="dp__hmeta">{{ fmt(c.costo_imputado_ars) }} · {{ c.fecha }}<template v-if="c.lote"> · {{ c.lote.codigo }}</template><template v-else-if="c.sala"> · {{ c.sala.nombre }}</template><template v-else-if="c.notas"> · {{ c.notas }}</template></span>
              </div>
            </li>
          </ul>
          <p v-else class="mut dp__hempty">Sin salidas registradas.</p>
        </template>

        <div class="modal__actions"><button class="btn" @click="hist = null">Cerrar</button></div>
      </div>
    </div>

    <!-- Modal EDITAR -->
    <div v-if="editForm" class="ov" @click.self="editForm = null">
      <div class="dpdlg">
        <h3 class="modal__title">Editar insumo</h3>
        <p class="modal__hint">Cambiá el nombre, la categoría o el mínimo. El stock no se toca acá (para eso está Reconteo y Transferir).</p>
        <label class="fld">Nombre<input v-model.trim="editForm.nombre" class="inp" maxlength="60" /></label>
        <label class="fld">Categoría
          <select v-model="editForm.categoria_contable_id" class="inp">
            <option :value="null">— Sin categoría —</option>
            <option v-for="c in categoriasDelTab" :key="c.id" :value="c.id">{{ c.label }}</option>
          </select>
        </label>
        <div class="dp__grid2">
          <label class="fld">Unidad de medida<select v-model="editForm.unidad_medida" class="inp"><option v-for="u in UNIDADES" :key="u" :value="u">{{ u }}</option></select></label>
          <label class="fld">Stock mínimo<input v-model.number="editForm.stock_minimo" type="number" min="0" step="any" class="inp" /></label>
        </div>
        <div class="modal__actions"><button class="btn" @click="editForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="guardarEdit">Guardar</button></div>
      </div>
    </div>

    <!-- Modal TRANSFERIR -->
    <div v-if="transferForm" class="ov" @click.self="transferForm = null">
      <div class="dpdlg">
        <h3 class="modal__title">Transferir — {{ transferForm.insumo.nombre }}</h3>
        <p class="modal__hint">Reclasifica stock a otro depósito. El costo viaja con la mercadería; <b>no genera un nuevo egreso</b> (la plata ya salió al comprar).</p>
        <label class="fld">Depósito destino
          <select v-model="transferForm.deposito_destino_id" class="inp">
            <option v-for="d in depositosDestino" :key="d.id" :value="d.id">{{ depLabel(d) }}</option>
          </select>
        </label>
        <label class="fld">Cantidad ({{ transferForm.insumo.unidad_medida }})
          <input v-model.number="transferForm.cantidad" type="number" min="0" :max="transferForm.insumo.stock_actual" step="any" class="inp" />
        </label>
        <p class="modal__note">Disponible: {{ transferForm.insumo.stock_actual }} {{ transferForm.insumo.unidad_medida }}.</p>
        <div class="modal__actions"><button class="btn" @click="transferForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarTransfer">Transferir</button></div>
      </div>
    </div>

    <!-- Modal CONSUMIR -->
    <div v-if="consumoForm" class="ov" @click.self="consumoForm = null">
      <div class="dpdlg dpdlg--wide">
        <h3 class="modal__title">Registrar consumo — {{ consumoForm.insumo.nombre }}</h3>
        <p class="modal__hint">
          Disponible {{ consumoForm.insumo.stock_actual }} {{ consumoForm.insumo.unidad_medida }}.
          {{ esCultivo ? 'Se imputa el costo a los lotes elegidos.' : 'Se descuenta del depósito como gasto general del club.' }}
        </p>
        <label class="fld">Cantidad usada<input v-model.number="consumoForm.cantidad" type="number" min="0" step="any" class="inp" /></label>

        <template v-if="esCultivo">
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

        <div class="modal__actions"><button class="btn" @click="consumoForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarConsumo">{{ esCultivo ? 'Imputar consumo' : 'Registrar consumo' }}</button></div>
      </div>
    </div>

    <!-- Modal NUEVO DEPÓSITO -->
    <div v-if="depoForm" class="ov" @click.self="depoForm = null">
      <div class="dpdlg">
        <h3 class="modal__title">Nuevo depósito</h3>
        <p class="modal__hint">Un depósito propio para agrupar tu mercadería (ej: Merchandising, Insumos de oficina). Los productos que cargues acá se consumen como gasto general.</p>
        <label class="fld">Nombre<input v-model.trim="depoForm.nombre" class="inp" maxlength="40" placeholder="Ej: Merchandising" v-focus @keydown.enter.prevent="confirmarNuevoDeposito" /></label>
        <label class="fld">Sector <small class="mut">(a qué línea de negocio pertenece, para el P&L)</small>
          <select v-model="depoForm.unidad_negocio_id" class="inp">
            <option :value="null">— Sin sector —</option>
            <option v-for="a in areas" :key="a.id" :value="a.id">{{ a.nombre }}</option>
          </select>
        </label>
        <div class="modal__actions"><button class="btn" @click="depoForm = null">Cancelar</button><button class="btn btn--primary" :disabled="savingDepo" @click="confirmarNuevoDeposito">Crear</button></div>
      </div>
    </div>

    <!-- Modal GESTIONAR DEPÓSITO -->
    <div v-if="depoEdit" class="ov" @click.self="depoEdit = null">
      <div class="dpdlg">
        <h3 class="modal__title">Gestionar depósito</h3>
        <label class="fld">Nombre<input v-model.trim="depoEdit.nombre" class="inp" maxlength="40" v-focus @keydown.enter.prevent="guardarDeposito" /></label>
        <label class="fld">Sector <small class="mut">(para el P&L)</small>
          <select v-model="depoEdit.unidad_negocio_id" class="inp">
            <option :value="null">— Sin sector —</option>
            <option v-for="a in areas" :key="a.id" :value="a.id">{{ a.nombre }}</option>
          </select>
        </label>
        <label class="dp__chk" style="margin: .2rem 0 .4rem"><input type="checkbox" :checked="!depoEdit.activo" @change="depoEdit.activo = !depoEdit.activo" /> Desactivado (oculto del listado)</label>
        <p v-if="depoEdit.es_sistema" class="mut" style="font-size:.8rem; margin:.3rem 0 0; line-height:1.4">Es un depósito del sistema: podés renombrarlo o desactivarlo, pero no eliminarlo.</p>
        <div class="modal__actions" style="justify-content: space-between">
          <button v-if="!depoEdit.es_sistema" class="btn btn--danger" :disabled="savingDepo" @click="eliminarDeposito">Eliminar</button>
          <span v-else></span>
          <div style="display:flex; gap:.5rem">
            <button class="btn" @click="depoEdit = null">Cancelar</button>
            <button class="btn btn--primary" :disabled="savingDepo" @click="guardarDeposito">Guardar</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dp { padding: 2rem 1.75rem 3rem; max-width: 920px; margin: 0 auto; color: var(--c-slate-900); }
.dp__head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1.5rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
.dp__title { font-size: 1.6rem; font-weight: 800; letter-spacing: -.035em; margin: 0 0 .2rem; display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.dp__sede-filtro { border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .5rem .7rem; font-size: .84rem; font-weight: 600; color: var(--c-slate-700); background: #fff; cursor: pointer; }
.dp__sede-filtro:focus { border-color: #1b5e20; outline: none; }
.dp__tabs { display: inline-flex; gap: .25rem; background: var(--c-slate-100); border-radius: 10px; padding: .25rem; margin-bottom: 1.25rem; }
.dp__tab { border: none; background: transparent; color: var(--c-slate-500); font-size: .84rem; font-weight: 600; padding: .45rem 1rem; border-radius: 8px; cursor: pointer; transition: background .12s, color .12s; }
.dp__tab:hover { color: var(--c-slate-700); }
.dp__tab.is-on { background: #fff; color: #1b5e20; box-shadow: 0 1px 2px rgb(15 23 42 / .08); }
.dp__tab--add { font-weight: 700; color: var(--c-slate-400); padding-inline: .75rem; }
.dp__tab--add:hover { color: #1b5e20; }
.dp__sub { color: var(--c-slate-500); font-size: .84rem; margin: 0; max-width: 52ch; line-height: 1.5; }
.dp__link { color: #1b5e20; font-weight: 600; text-decoration: none; }
.dp__link:hover { text-decoration: underline; }
.dp__head-right { display: flex; align-items: center; gap: 1rem; }
.dp__area-line { margin: -.5rem 0 1rem; }
.dp__area-chip { display: inline-flex; align-items: center; gap: .3rem; font-size: .76rem; font-weight: 600; color: var(--c-slate-600); background: #eef2f6; border: 1px solid var(--c-slate-200); padding: .22rem .6rem; border-radius: 999px; }
.dp__summary { display: flex; gap: 2.5rem; background: #fff; border: 1px solid #e8edf2; border-radius: 13px; padding: 1rem 1.4rem; margin-bottom: 1.25rem; box-shadow: 0 1px 2px rgb(15 23 42 / .04); }
.dp__kpi { display: flex; flex-direction: column; gap: .15rem; }
.dp__kpi-label { font-size: .64rem; text-transform: uppercase; letter-spacing: .08em; color: var(--c-slate-400); font-weight: 700; }
.dp__kpi-val { font-size: 1.35rem; font-weight: 800; letter-spacing: -.03em; color: var(--c-slate-900); font-variant-numeric: tabular-nums; }
.dp__kpi--warn .dp__kpi-val { color: #b45309; }

.dp__toolbar { display: flex; align-items: center; gap: .75rem 1rem; flex-wrap: wrap; margin-bottom: 1rem; }
.dp__chk { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; color: var(--c-slate-500); cursor: pointer; margin-left: auto; white-space: nowrap; }
.dp__chk input { accent-color: #1b5e20; }
.dp__search { display: inline-flex; align-items: center; gap: .5rem; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .45rem .7rem; color: var(--c-slate-400); }
.dp__search:focus-within { border-color: #1b5e20; }
.dp__search input { border: none; outline: none; font-size: .86rem; color: var(--c-slate-900); width: 200px; background: transparent; }
.dp__chips { display: flex; flex-wrap: wrap; gap: .35rem; }
.dp__chip { border: 1.5px solid var(--c-slate-200); background: #fff; color: var(--c-slate-500); border-radius: 999px; padding: .3rem .75rem; font-size: .78rem; font-weight: 600; cursor: pointer; transition: border-color .12s, color .12s; }
.dp__chip:hover { border-color: var(--c-slate-300); }
.dp__chip.is-on { border-color: #1b5e20; background: rgb(27 94 32 / .07); color: #1b5e20; }

.dp__table-wrap { overflow-x: auto; border: 1px solid #e8edf2; border-radius: 13px; box-shadow: 0 1px 2px rgb(15 23 42 / .04); }
.dp__table { width: 100%; border-collapse: collapse; font-size: .88rem; background: #fff; }
.dp__table thead th { text-align: left; font-size: .68rem; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); font-weight: 700; padding: .7rem 1rem; border-bottom: 1.5px solid #eef2f6; white-space: nowrap; }
.dp__table td { padding: .7rem 1rem; border-bottom: 1px solid var(--c-slate-100); vertical-align: middle; }
.dp__table tbody tr:hover { background: var(--c-slate-50); }
.dp__table tbody tr.is-off { opacity: .55; }
.dp__table tbody tr:last-child td { border-bottom: none; }
.dp__table .ta-r { text-align: right; }
.dp__table .dp__name { font-weight: 650; color: var(--c-slate-900); }
.dp__cat { color: var(--c-slate-500); font-size: .82rem; }
.dp__table b.low { color: #dc2626; }
.dp__table tfoot td { padding: .65rem 1rem; border-top: 1.5px solid #eef2f6; }
.dp__total { font-weight: 800; color: var(--c-slate-900); font-size: .95rem; }
.dp__row-actions { display: inline-flex; gap: .4rem; align-items: center; justify-content: flex-end; }

.dp__empty { color: var(--c-slate-400); padding: 2.5rem; text-align: center; font-size: .9rem; }
.dp__empty--box { background: #fbfcfd; border: 1px dashed var(--c-slate-200); border-radius: 14px; }

.dp__name { font-weight: 650; color: var(--c-slate-900); letter-spacing: -.01em; margin-right: .5rem; }
.dp__pill { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #b45309; background: #fef3c7; padding: 2px 8px; border-radius: 999px; vertical-align: middle; }
.dp__pill--off { color: var(--c-slate-500); background: var(--c-slate-100); }
.num { font-variant-numeric: tabular-nums; }
.dp__actions { display: flex; gap: .4rem; align-items: center; }

.dp__menu-wrap { position: relative; }
.dp__menu { position: fixed; z-index: 1200; min-width: 210px; background: #fff; border: 1px solid #e8edf2; border-radius: 11px; box-shadow: 0 12px 32px rgb(15 23 42 / .16); padding: .35rem; display: flex; flex-direction: column; }
.dp__menu-item { text-align: left; border: none; background: transparent; color: var(--c-slate-700); font-size: .84rem; font-weight: 500; padding: .5rem .65rem; border-radius: 7px; cursor: pointer; }
.dp__menu-item:hover { background: #f5f8f6; }
.dp__menu-item:disabled { opacity: .4; cursor: default; }
.dp__menu-item--danger { color: #dc2626; }
.dp__menu-item--danger:hover { background: #fef2f2; }
.dp__menu-sep { height: 1px; background: #eef2f6; margin: .3rem 0; }

.ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
/* .dpdlg — NO usar la clase `.modal`: choca con Bootstrap (display:none) y el modal no se ve. */
.dpdlg { position: relative; display: block; background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 380px; box-shadow: 0 20px 50px rgb(15 23 42 / .25), 0 2px 8px rgb(15 23 42 / .1); max-height: 90vh; overflow-y: auto; }
.dpdlg--wide { max-width: 460px; }
.modal__title { margin: 0 0 .25rem; font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; color: var(--c-slate-900); }
.modal__hint { color: var(--c-slate-500); font-size: .82rem; margin: 0 0 1.1rem; line-height: 1.45; }
.modal__hint--warn { background: #fdf6ec; border: 1px solid #f4e0c3; border-radius: 9px; padding: .6rem .8rem; color: #92400e; }
.modal__hint--warn b { color: #7c2d12; }
.modal__note { font-size: .76rem; color: var(--c-slate-400); margin: -.3rem 0 .9rem; }
.dp__grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.dp__hintline { font-size: .78rem; color: #1b5e20; margin: -.4rem 0 .9rem; font-weight: 600; }
.dp__hintline--neg { color: #dc2626; }
.fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: var(--c-slate-600); margin-bottom: .9rem; }
.mut { color: var(--c-slate-400); }
.modal__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; }

.dp__seg { display: inline-flex; gap: .25rem; background: var(--c-slate-100); border-radius: 9px; padding: .2rem; margin-bottom: 1rem; }
.dp__seg-btn { border: none; background: transparent; color: var(--c-slate-500); font-size: .8rem; font-weight: 600; padding: .4rem .9rem; border-radius: 7px; cursor: pointer; }
.dp__seg-btn.is-on { background: #fff; color: #1b5e20; box-shadow: 0 1px 2px rgb(15 23 42 / .08); }
.dp__seg-btn:disabled { opacity: .4; cursor: default; }

.dp__reasons { display: flex; flex-direction: column; gap: .5rem; margin-bottom: .9rem; }
.dp__reason { display: flex; gap: .6rem; align-items: flex-start; padding: .7rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 10px; cursor: pointer; }
.dp__reason.is-on { border-color: #1b5e20; background: rgb(27 94 32 / .05); }
.dp__reason input { accent-color: #1b5e20; margin-top: .15rem; }
.dp__reason span { display: flex; flex-direction: column; gap: .15rem; font-size: .84rem; color: var(--c-slate-900); }
.dp__reason small { color: var(--c-slate-500); font-size: .76rem; line-height: 1.4; }

.dp__h4 { font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; color: var(--c-slate-400); font-weight: 700; margin: 1rem 0 .5rem; }
.dp__hist { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
.dp__hrow { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .5rem .7rem; background: var(--c-slate-50); border: 1px solid #eef2f6; border-radius: 9px; }
.dp__hqty { font-weight: 700; color: var(--c-slate-900); font-size: .9rem; margin-right: .5rem; }
.dp__hmeta { color: var(--c-slate-500); font-size: .78rem; }
.dp__hempty { font-size: .82rem; margin: .2rem 0 0; }

.dp__lotes { display: flex; flex-wrap: wrap; gap: .4rem; }
.dp__lote { display: inline-flex; align-items: center; gap: .35rem; padding: .35rem .65rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .8rem; color: var(--c-slate-600); cursor: pointer; user-select: none; }
.dp__lote.is-on { border-color: #1b5e20; background: rgb(27 94 32 / .06); color: #1b5e20; font-weight: 600; }
.dp__lote input { accent-color: #1b5e20; }
.dp__reparto { font-size: .78rem; color: #1b5e20; margin: .5rem 0 0; font-weight: 500; }

.inp { padding: .55rem .7rem; border: 1.5px solid var(--c-slate-200); border-radius: 9px; font-size: .86rem; background: #fff; color: var(--c-slate-900); }
.inp:focus { border-color: #1b5e20; outline: none; }
.btn { border: 1.5px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); border-radius: 9px; padding: .55rem .95rem; font-size: .83rem; font-weight: 600; cursor: pointer; transition: border-color .12s, background .12s; }
.btn:hover { border-color: var(--c-slate-300); }
.btn--sm { padding: .45rem .8rem; font-size: .8rem; }
.btn--icon { padding: .45rem .6rem; line-height: 1; font-size: 1.1rem; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover { background: #144a18; border-color: #144a18; }
.btn--danger { color: #dc2626; border-color: #f4c9c9; }
.btn--danger:hover { border-color: #dc2626; background: #fef2f2; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
