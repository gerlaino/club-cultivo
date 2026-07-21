<script setup>
// Depósito — módulo operativo de inventario valorizado. Todo se resuelve acá, sin saltar a
// Contabilidad: Entrada (compra → genera el asiento), Consumir (imputa costo a lote/sala o gasto),
// Reconteo (ajusta al conteo físico: corrección de dato o merma), Editar, Desactivar/Eliminar,
// Historial (con reversión de compra). El Salón (bar, vendible) vive en su propio componente.
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useInsumosStore } from '../../stores/insumos.js'
import { useSedeStore } from '../../stores/sede.js'
import { listLotes, listSalas, listCategoriasContables, getInsumo } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'
import DepositoSalon from './DepositoSalon.vue'

const store = useInsumosStore()
const sede  = useSedeStore()
const toast = useToast()
const { confirm } = useConfirm()

const UNIDADES = ['unidad', 'litro', 'mililitro', 'kilogramo', 'gramo', 'bolsa', 'metro', 'otro']
const lotes = ref([])
const salas = ref([])
const categorias = ref([])          // árbol contable (para el alta y las etiquetas de grupo)
const mostrarInactivos = ref(false)  // los insumos desactivados quedan ocultos por defecto

const hoyISO = () => new Date().toISOString().slice(0, 10)
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

// ── Familia de depósito (Cultivo / General / Salón) ───────────────────────────
const COMP_DE_TAB = { cultivo: ['insumo'], general: ['insumo_general'] }
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

// El depósito vive por sede. Filtro LOCAL (default null = todo el club).
const sedeFiltro = ref(null)
const sedeActualObj = computed(() => sede.sedes.find(s => s.id === sedeFiltro.value) || null)
const multiSede = computed(() => sede.sedes.length > 1)
const otrasSedes = computed(() => sede.sedes.filter(s => s.id !== sedeFiltro.value))

const currentTipo = computed(() => sedeActualObj.value?.tipo)
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

watch(TABS, (tabs) => {
  if (!tabs.some(t => t.tipo === tipoActivo.value)) tipoActivo.value = tabs[0]?.tipo || 'cultivo'
})

// Insumos visibles (según toggle de inactivos) agrupados por categoría, como el árbol contable.
const itemsVisibles = computed(() => store.items.filter(i => mostrarInactivos.value || i.activo))
const hayInactivos  = computed(() => store.items.some(i => !i.activo))
const grupos = computed(() => {
  const map = {}
  for (const i of itemsVisibles.value) {
    const c = i.categoria
    const label = c ? (c.sub_nombre ? `${c.madre_nombre} › ${c.sub_nombre}` : c.madre_nombre) : 'Sin categoría'
    ;(map[label] ||= []).push(i)
  }
  return Object.entries(map)
    .map(([label, items]) => ({ label, items, valorizado: items.reduce((a, i) => a + (i.valorizado_ars || 0), 0) }))
    .sort((a, b) => (a.label === 'Sin categoría' ? 1 : b.label === 'Sin categoría' ? -1 : a.label.localeCompare(b.label)))
})

async function recargar() {
  if (esSalon.value) return
  await store.fetch({ sede_id: sedeFiltro.value ?? undefined, tipo: tipoActivo.value })
}

onMounted(async () => {
  if (!sede.loaded) await sede.fetchSedes()
  await recargar()
  listLotes({ estado: 'activos' }).then(r => { lotes.value = r.data?.lotes || r.data || [] }).catch(() => {})
  listSalas().then(r => { salas.value = r.data || [] }).catch(() => {})
  listCategoriasContables().then(r => { categorias.value = r.data || [] }).catch(() => {})
  window.addEventListener('click', cerrarMenu)
})
onUnmounted(() => window.removeEventListener('click', cerrarMenu))
watch([sedeFiltro, tipoActivo], recargar)

function stockPct(i) {
  if (!i.stock_minimo) return i.stock_actual > 0 ? 100 : 0
  return Math.min(100, Math.round((i.stock_actual / (i.stock_minimo * 2)) * 100))
}

// ── Menú de acciones por ítem (kebab) ─────────────────────────
const menuId = ref(null)
function toggleMenu(id, ev) { ev.stopPropagation(); menuId.value = menuId.value === id ? null : id }
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
  }
}
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
        categoria_contable_id: f.categoria_contable_id, tipo: tipoActivo.value, sede_id: f.sede_id,
      })
      id = nuevo.id
    }
    await store.comprar(id, {
      cantidad: f.cantidad, costo_total_ars: f.costo_total_ars,
      proveedor: f.proveedor?.trim() || undefined, fecha: f.fecha,
      sede_id: f.sede_id ?? undefined, generar_egreso: true,
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

// ── Transferir a otra sede ────────────────────────────────────
const transferForm = ref(null)
function abrirTransfer(i) { cerrarMenu(); transferForm.value = { insumo: i, sede_destino_id: otrasSedes.value[0]?.id ?? null, cantidad: null } }
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
        <p class="dp__sub">{{ tabActual?.hint }}</p>
      </div>
      <div class="dp__head-right">
        <select v-if="multiSede" v-model="sedeFiltro" class="dp__sede-filtro">
          <option :value="null">🏢 Todo el club</option>
          <option v-for="s in sede.sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <template v-if="!esSalon">
          <div class="dp__stat">
            <span class="dp__stat-label">Valorizado</span>
            <span class="dp__stat-val">{{ fmt(store.valorizadoTotal) }}</span>
          </div>
          <button class="btn btn--primary" @click="abrirEntrada()">＋ Entrada</button>
        </template>
      </div>
    </header>

    <div class="dp__tabs">
      <button v-for="t in TABS" :key="t.tipo" class="dp__tab" :class="{ 'is-on': tipoActivo === t.tipo }" @click="tipoActivo = t.tipo">
        {{ t.label }}
      </button>
    </div>

    <DepositoSalon v-if="esSalon" :sede-id="sedeFiltro" />

    <template v-else>
    <div v-if="store.loading" class="dp__empty">Cargando depósito…</div>
    <div v-else-if="!store.items.length" class="dp__empty dp__empty--box">
      Todavía no hay insumos en esta familia. Cargalos con
      <a href="#" class="dp__link" @click.prevent="abrirEntrada()">＋ Entrada</a>
      (poniendo su costo, se genera el egreso contable), o desde
      <RouterLink :to="{ name: 'contabilidad' }" class="dp__link">Contabilidad → Nuevo movimiento</RouterLink>.
    </div>

    <template v-else>
      <div v-if="hayInactivos" class="dp__toolbar">
        <label class="dp__chk"><input type="checkbox" v-model="mostrarInactivos" /> Ver desactivados</label>
      </div>

      <div class="dp__groups">
        <section v-for="g in grupos" :key="g.label" class="dp__group">
          <div class="dp__group-head">
            <span class="dp__group-name">{{ g.label }}</span>
            <span class="dp__group-val">{{ fmt(g.valorizado) }}</span>
          </div>
          <ul class="dp__list">
            <li v-for="i in g.items" :key="i.id" class="dp__item" :class="{ 'dp__item--low': i.stock_bajo && i.activo, 'dp__item--off': !i.activo }">
              <div class="dp__item-main">
                <div class="dp__item-top">
                  <span class="dp__name">{{ i.nombre }}</span>
                  <span v-if="!i.activo" class="dp__pill dp__pill--off">Desactivado</span>
                  <span v-if="multiSede" class="dp__sede">{{ i.sede_nombre || 'Sin sede' }}</span>
                  <span v-if="i.stock_bajo && i.activo" class="dp__pill">Reponer</span>
                </div>
                <div class="dp__meter"><i :style="{ width: stockPct(i) + '%' }" :class="i.stock_bajo ? 'is-low' : 'is-ok'"></i></div>
              </div>
              <div class="dp__stats">
                <span class="dp__stock num" :class="{ low: i.stock_bajo }">{{ i.stock_actual }} <small>{{ i.unidad_medida }}</small></span>
                <span class="dp__meta num">{{ fmt(i.costo_promedio_ars) }}/u · {{ fmt(i.valorizado_ars) }}</span>
              </div>
              <div class="dp__actions">
                <button class="btn btn--sm btn--primary" @click="abrirConsumo(i)" :disabled="i.stock_actual <= 0 || !i.activo">Consumir</button>
                <div class="dp__menu-wrap">
                  <button class="btn btn--sm btn--icon" @click="toggleMenu(i.id, $event)" title="Más acciones">⋯</button>
                  <div v-if="menuId === i.id" class="dp__menu" @click.stop>
                    <button class="dp__menu-item" @click="abrirEntrada(i)">Reponer (entrada)</button>
                    <button class="dp__menu-item" @click="abrirReconteo(i)">Reconteo</button>
                    <button v-if="multiSede && otrasSedes.length" class="dp__menu-item" @click="abrirTransfer(i)" :disabled="i.stock_actual <= 0">Transferir a otra sede</button>
                    <button class="dp__menu-item" @click="abrirHistorial(i)">Historial</button>
                    <button class="dp__menu-item" @click="editarInsumo(i)">Editar</button>
                    <div class="dp__menu-sep"></div>
                    <button class="dp__menu-item" @click="toggleActivo(i)">{{ i.activo ? 'Desactivar' : 'Reactivar' }}</button>
                    <button class="dp__menu-item dp__menu-item--danger" @click="eliminarInsumo(i)">Eliminar</button>
                  </div>
                </div>
              </div>
            </li>
          </ul>
        </section>
      </div>
    </template>
    </template>

    <!-- Modal ENTRADA (compra con costo → egreso) -->
    <div v-if="entradaForm" class="ov" @click.self="entradaForm = null">
      <div class="modal modal--wide">
        <h3 class="modal__title">Registrar entrada</h3>
        <p class="modal__hint">Cargás mercadería con su costo. Se suma al depósito y se genera el <b>egreso contable</b> automáticamente — no hace falta ir a Contabilidad.</p>

        <div class="dp__seg">
          <button class="dp__seg-btn" :class="{ 'is-on': entradaForm.modo === 'existente' }" :disabled="!store.items.length" @click="entradaForm.modo = 'existente'">Reponer existente</button>
          <button class="dp__seg-btn" :class="{ 'is-on': entradaForm.modo === 'nuevo' }" @click="entradaForm.modo = 'nuevo'">Insumo nuevo</button>
        </div>

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
        <label v-if="multiSede" class="fld">Sede
          <select v-model="entradaForm.sede_id" class="inp">
            <option :value="null">🏢 Pool del club</option>
            <option v-for="s in sede.sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
        </label>

        <div class="modal__actions"><button class="btn" @click="entradaForm = null">Cancelar</button><button class="btn btn--primary" :disabled="store.saving" @click="confirmarEntrada">Registrar entrada</button></div>
      </div>
    </div>

    <!-- Modal RECONTEO -->
    <div v-if="reconteoForm" class="ov" @click.self="reconteoForm = null">
      <div class="modal">
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
      <div class="modal modal--wide">
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
      <div class="modal">
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

    <!-- Modal CONSUMIR -->
    <div v-if="consumoForm" class="ov" @click.self="consumoForm = null">
      <div class="modal modal--wide">
        <h3 class="modal__title">Registrar consumo — {{ consumoForm.insumo.nombre }}</h3>
        <p class="modal__hint">
          Disponible {{ consumoForm.insumo.stock_actual }} {{ consumoForm.insumo.unidad_medida }}.
          {{ esGeneral ? 'Se descuenta del depósito como gasto general del club.' : 'Se imputa el costo a los lotes elegidos.' }}
        </p>
        <label class="fld">Cantidad usada<input v-model.number="consumoForm.cantidad" type="number" min="0" step="any" class="inp" /></label>

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
.dp__sede-filtro { border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .5rem .7rem; font-size: .84rem; font-weight: 600; color: #334155; background: #fff; cursor: pointer; }
.dp__sede-filtro:focus { border-color: #1b5e20; outline: none; }
.dp__tabs { display: inline-flex; gap: .25rem; background: #f1f5f9; border-radius: 10px; padding: .25rem; margin-bottom: 1.25rem; }
.dp__tab { border: none; background: transparent; color: #64748b; font-size: .84rem; font-weight: 600; padding: .45rem 1rem; border-radius: 8px; cursor: pointer; transition: background .12s, color .12s; }
.dp__tab:hover { color: #334155; }
.dp__tab.is-on { background: #fff; color: #1b5e20; box-shadow: 0 1px 2px rgb(15 23 42 / .08); }
.dp__sede { font-size: .66rem; font-weight: 600; letter-spacing: .02em; color: #475569; background: #f1f5f9; padding: 2px 8px; border-radius: 999px; }
.dp__sub { color: #64748b; font-size: .84rem; margin: 0; max-width: 52ch; line-height: 1.5; }
.dp__link { color: #1b5e20; font-weight: 600; text-decoration: none; }
.dp__link:hover { text-decoration: underline; }
.dp__head-right { display: flex; align-items: center; gap: 1.25rem; }
.dp__stat { text-align: right; }
.dp__stat-label { display: block; font-size: .66rem; text-transform: uppercase; letter-spacing: .08em; color: #94a3b8; font-weight: 600; }
.dp__stat-val { display: block; font-size: 1.5rem; font-weight: 800; letter-spacing: -.03em; color: #0f172a; font-variant-numeric: tabular-nums; }

.dp__toolbar { display: flex; justify-content: flex-end; margin-bottom: .75rem; }
.dp__chk { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; color: #64748b; cursor: pointer; }
.dp__chk input { accent-color: #1b5e20; }

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
.dp__item--off { opacity: .6; }
.dp__item-main { min-width: 0; }
.dp__item-top { display: flex; align-items: center; gap: .6rem; }
.dp__name { font-weight: 650; color: #0f172a; font-size: .96rem; letter-spacing: -.01em; }
.dp__pill { font-size: .64rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #b45309; background: #fef3c7; padding: 2px 8px; border-radius: 999px; }
.dp__pill--off { color: #64748b; background: #f1f5f9; }
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
.dp__actions { display: flex; gap: .4rem; align-items: center; }

.dp__menu-wrap { position: relative; }
.dp__menu { position: absolute; right: 0; top: calc(100% + .3rem); z-index: 50; min-width: 210px; background: #fff; border: 1px solid #e8edf2; border-radius: 11px; box-shadow: 0 12px 32px rgb(15 23 42 / .16); padding: .35rem; display: flex; flex-direction: column; }
.dp__menu-item { text-align: left; border: none; background: transparent; color: #334155; font-size: .84rem; font-weight: 500; padding: .5rem .65rem; border-radius: 7px; cursor: pointer; }
.dp__menu-item:hover { background: #f5f8f6; }
.dp__menu-item:disabled { opacity: .4; cursor: default; }
.dp__menu-item--danger { color: #dc2626; }
.dp__menu-item--danger:hover { background: #fef2f2; }
.dp__menu-sep { height: 1px; background: #eef2f6; margin: .3rem 0; }

.ov { position: fixed; inset: 0; background: rgb(15 23 42 / .5); backdrop-filter: blur(2px); display: grid; place-items: center; z-index: 1000; padding: 1rem; }
.modal { background: #fff; border-radius: 16px; padding: 1.5rem; width: 100%; max-width: 380px; box-shadow: 0 20px 50px rgb(15 23 42 / .25), 0 2px 8px rgb(15 23 42 / .1); max-height: 90vh; overflow-y: auto; }
.modal--wide { max-width: 460px; }
.modal__title { margin: 0 0 .25rem; font-size: 1.1rem; font-weight: 750; letter-spacing: -.02em; color: #0f172a; }
.modal__hint { color: #64748b; font-size: .82rem; margin: 0 0 1.1rem; line-height: 1.45; }
.modal__note { font-size: .76rem; color: #94a3b8; margin: -.3rem 0 .9rem; }
.dp__grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.dp__hintline { font-size: .78rem; color: #1b5e20; margin: -.4rem 0 .9rem; font-weight: 600; }
.dp__hintline--neg { color: #dc2626; }
.fld { display: flex; flex-direction: column; gap: .35rem; font-size: .82rem; color: #475569; margin-bottom: .9rem; }
.mut { color: #94a3b8; }
.modal__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .5rem; }

.dp__seg { display: inline-flex; gap: .25rem; background: #f1f5f9; border-radius: 9px; padding: .2rem; margin-bottom: 1rem; }
.dp__seg-btn { border: none; background: transparent; color: #64748b; font-size: .8rem; font-weight: 600; padding: .4rem .9rem; border-radius: 7px; cursor: pointer; }
.dp__seg-btn.is-on { background: #fff; color: #1b5e20; box-shadow: 0 1px 2px rgb(15 23 42 / .08); }
.dp__seg-btn:disabled { opacity: .4; cursor: default; }

.dp__reasons { display: flex; flex-direction: column; gap: .5rem; margin-bottom: .9rem; }
.dp__reason { display: flex; gap: .6rem; align-items: flex-start; padding: .7rem .8rem; border: 1.5px solid #e2e8f0; border-radius: 10px; cursor: pointer; }
.dp__reason.is-on { border-color: #1b5e20; background: rgb(27 94 32 / .05); }
.dp__reason input { accent-color: #1b5e20; margin-top: .15rem; }
.dp__reason span { display: flex; flex-direction: column; gap: .15rem; font-size: .84rem; color: #0f172a; }
.dp__reason small { color: #64748b; font-size: .76rem; line-height: 1.4; }

.dp__h4 { font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; color: #94a3b8; font-weight: 700; margin: 1rem 0 .5rem; }
.dp__hist { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .4rem; }
.dp__hrow { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .5rem .7rem; background: #f8fafc; border: 1px solid #eef2f6; border-radius: 9px; }
.dp__hqty { font-weight: 700; color: #0f172a; font-size: .9rem; margin-right: .5rem; }
.dp__hmeta { color: #64748b; font-size: .78rem; }
.dp__hempty { font-size: .82rem; margin: .2rem 0 0; }

.dp__lotes { display: flex; flex-wrap: wrap; gap: .4rem; }
.dp__lote { display: inline-flex; align-items: center; gap: .35rem; padding: .35rem .65rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .8rem; color: #475569; cursor: pointer; user-select: none; }
.dp__lote.is-on { border-color: #1b5e20; background: rgb(27 94 32 / .06); color: #1b5e20; font-weight: 600; }
.dp__lote input { accent-color: #1b5e20; }
.dp__reparto { font-size: .78rem; color: #1b5e20; margin: .5rem 0 0; font-weight: 500; }

.inp { padding: .55rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 9px; font-size: .86rem; background: #fff; color: #0f172a; }
.inp:focus { border-color: #1b5e20; outline: none; }
.btn { border: 1.5px solid #e2e8f0; background: #fff; color: #334155; border-radius: 9px; padding: .55rem .95rem; font-size: .83rem; font-weight: 600; cursor: pointer; transition: border-color .12s, background .12s; }
.btn:hover { border-color: #cbd5e1; }
.btn--sm { padding: .45rem .8rem; font-size: .8rem; }
.btn--icon { padding: .45rem .6rem; line-height: 1; font-size: 1.1rem; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.btn--primary:hover { background: #144a18; border-color: #144a18; }
.btn--danger { color: #dc2626; border-color: #f4c9c9; }
.btn--danger:hover { border-color: #dc2626; background: #fef2f2; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
