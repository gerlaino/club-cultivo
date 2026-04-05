<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useContabilidadStore } from "../stores/contabilidad"
import { useAuthStore }         from "../stores/auth"
import { listSedes }            from "../lib/api"

const store   = useContabilidadStore()
const auth    = useAuthStore()
const sedes   = ref([])
const canEdit = computed(() => ["admin","abogado"].includes(auth.role))

const vistaActiva = ref("dashboard")

// ── Formato ───────────────────────────────────────────────────────────────────
const fmt = (n) => new Intl.NumberFormat("es-AR", {
  style: "currency", currency: "ARS",
  minimumFractionDigits: 0, maximumFractionDigits: 0
}).format(n || 0)

function balanceColor(n) { return n >= 0 ? "#15803d" : "#dc2626" }
function balanceBg(n)    { return n >= 0 ? "rgba(21,128,61,.08)" : "rgba(220,38,38,.08)" }

function tipoMeta(tipo) {
  return {
    egreso:         { label: "Egreso",   color: "#dc2626", bg: "rgba(220,38,38,.1)"  },
    ingreso:        { label: "Ingreso",  color: "#15803d", bg: "rgba(21,128,61,.1)"  },
    recupero_costo: { label: "Recupero", color: "#0369a1", bg: "rgba(3,105,161,.1)"  },
    ajuste:         { label: "Ajuste",   color: "#64748b", bg: "rgba(100,116,139,.1)" },
  }[tipo] || { label: tipo, color: "#64748b", bg: "rgba(100,116,139,.1)" }
}

const MESES_ES = ["Enero","Febrero","Marzo","Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
const MESES_EN = { january:"Enero", february:"Febrero", march:"Marzo", april:"Abril", may:"Mayo", june:"Junio", july:"Julio", august:"Agosto", september:"Septiembre", october:"Octubre", november:"Noviembre", december:"Diciembre" }
function mesLabel(m) {
  if (!m) return "—"
  const num = parseInt(m)
  if (!isNaN(num) && num >= 1 && num <= 12) return MESES_ES[num - 1]
  if (/^\d{4}-\d{2}$/.test(String(m))) return MESES_ES[parseInt(m.split("-")[1]) - 1] || m
  const en = MESES_EN[String(m).toLowerCase()]
  if (en) return en
  return m
}

const CATEGORIAS = [
  { value: "insumo",        label: "Insumo / Materia prima",   tipo: "egreso"  },
  { value: "electricidad",  label: "Electricidad",             tipo: "egreso"  },
  { value: "agua",          label: "Agua",                     tipo: "egreso"  },
  { value: "alquiler",      label: "Alquiler",                 tipo: "egreso"  },
  { value: "sueldo",        label: "Sueldo / Staff",           tipo: "egreso"  },
  { value: "mantenimiento", label: "Mantenimiento",            tipo: "egreso"  },
  { value: "honorario",     label: "Honorario profesional",    tipo: "egreso"  },
  { value: "seguro",        label: "Seguro",                   tipo: "egreso"  },
  { value: "admin",         label: "Gasto administrativo",     tipo: "egreso"  },
  { value: "aporte_socio",  label: "Aporte socio",             tipo: "ingreso" },
  { value: "dispensacion",  label: "Recupero dispensación",    tipo: "ingreso" },
  { value: "subvencion",    label: "Subvención / Donación",    tipo: "ingreso" },
  { value: "otro",          label: "Otro",                     tipo: "ambos"   },
]
function catLabel(cat) { return CATEGORIAS.find(c => c.value === cat)?.label || cat || "—" }

// ── Búsqueda dashboard (últimos movimientos) ──────────────────────────────────
const busquedaDash = ref("")
const ultimosFiltrados = computed(() => {
  const list = store.dashboard?.ultimos_movimientos || []
  const q = busquedaDash.value.trim().toLowerCase()
  const filtered = q
    ? list.filter(m =>
      m.descripcion?.toLowerCase().includes(q) ||
      catLabel(m.categoria).toLowerCase().includes(q) ||
      m.tipo?.toLowerCase().includes(q)
    )
    : list
  return filtered.slice(0, 10)
})

// ── Filtros libro diario ──────────────────────────────────────────────────────
const filtroQ         = ref("")
const filtroTipo      = ref("")
const filtroCategoria = ref("")
const filtroSede      = ref("")
const filtroDesde     = ref("")
const filtroHasta     = ref("")

const itemsFiltrados = computed(() => {
  const q = filtroQ.value.trim().toLowerCase()
  return (store.items || []).filter(m => {
    if (q && !m.descripcion?.toLowerCase().includes(q) &&
      !catLabel(m.categoria).toLowerCase().includes(q) &&
      !m.proveedor?.toLowerCase().includes(q)) return false
    return true
  })
})

async function aplicarFiltros() {
  store.setFiltro("tipo",      filtroTipo.value)
  store.setFiltro("categoria", filtroCategoria.value)
  store.setFiltro("sede_id",   filtroSede.value)
  store.setFiltro("desde",     filtroDesde.value)
  store.setFiltro("hasta",     filtroHasta.value)
  await store.fetch()
}
function limpiarFiltros() {
  filtroQ.value = filtroTipo.value = filtroCategoria.value = filtroSede.value = ""
  filtroDesde.value = filtroHasta.value = ""
  store.resetFiltros()
  store.fetch()
}

const hayFiltros = computed(() =>
  filtroTipo.value || filtroCategoria.value || filtroSede.value || filtroDesde.value || filtroHasta.value
)

// ── Categorías del form filtradas por tipo ────────────────────────────────────
const categoriasForm = computed(() => {
  const t = form.value.tipo
  if (t === "egreso")  return CATEGORIAS.filter(c => c.tipo === "egreso"  || c.tipo === "ambos")
  if (t === "ingreso" || t === "recupero_costo") return CATEGORIAS.filter(c => c.tipo === "ingreso" || c.tipo === "ambos")
  return CATEGORIAS
})

// ── Modal crear/editar ────────────────────────────────────────────────────────
const showModal  = ref(false)
const editingId  = ref(null)
const formErrors = ref({})

function emptyForm() {
  return {
    tipo: "egreso", categoria: "", descripcion: "",
    monto_ars: null, fecha: new Date().toISOString().slice(0, 10),
    sede_id: null, lote_id: null,
    comprobante_numero: "", comprobante_tipo: "sin_comprobante",
    proveedor: "", pagado: false, medio_pago: "efectivo", notas: "",
  }
}
const form = ref(emptyForm())
watch(() => form.value.tipo, () => { form.value.categoria = "" })

function openCreate() {
  editingId.value = null; form.value = emptyForm(); formErrors.value = {}; showModal.value = true
}
function openEdit(m) {
  editingId.value = m.id
  form.value = {
    tipo: m.tipo, categoria: m.categoria, descripcion: m.descripcion,
    monto_ars: m.monto_ars, fecha: m.fecha,
    sede_id: m.sede?.id || null, lote_id: m.lote?.id || null,
    comprobante_numero: m.comprobante_numero || "", comprobante_tipo: m.comprobante_tipo || "sin_comprobante",
    proveedor: m.proveedor || "", pagado: m.pagado || false, medio_pago: m.medio_pago || "efectivo", notas: m.notas || "",
  }
  formErrors.value = {}; showModal.value = true
}
function validate(f) {
  const e = {}
  if (!f.tipo)               e.tipo        = "Requerido"
  if (!f.categoria)          e.categoria   = "Requerido"
  if (!f.descripcion?.trim()) e.descripcion = "Requerido"
  if (!f.monto_ars || f.monto_ars <= 0) e.monto_ars = "Debe ser mayor a 0"
  if (!f.fecha)              e.fecha       = "Requerido"
  return e
}
async function submitForm() {
  const e = validate(form.value); formErrors.value = e
  if (Object.keys(e).length) return
  try {
    if (editingId.value) await store.update(editingId.value, form.value)
    else await store.create(form.value)
    showModal.value = false
    if (vistaActiva.value === "dashboard") await store.fetchDashboard()
  } catch {}
}

// ── Modal eliminar ────────────────────────────────────────────────────────────
const showDelete = ref(false)
const toDelete   = ref(null)
function confirmDelete(m) { toDelete.value = m; showDelete.value = true }
async function doDelete() {
  if (!toDelete.value) return
  await store.remove(toDelete.value.id)
  showDelete.value = false; toDelete.value = null
}

// ── Paginación ────────────────────────────────────────────────────────────────
async function goToPage(p) {
  store.setFiltro("page", p); await store.fetch()
  window.scrollTo({ top: 0, behavior: "smooth" })
}

// ── Export CSV ────────────────────────────────────────────────────────────────
async function exportar() {
  const params = {}
  if (filtroDesde.value) params.desde = filtroDesde.value
  if (filtroHasta.value) params.hasta = filtroHasta.value
  await store.exportCSV(params)
}

function irALibro() {
  vistaActiva.value = "libro"; store.fetch()
}

onMounted(async () => {
  await Promise.all([
    store.fetchDashboard(),
    store.fetch(),
    listSedes().then(r => { sedes.value = r.data || [] }),
  ])
})
</script>

<template>
  <div class="cv">

    <!-- Header -->
    <div class="cv__header">
      <div class="cv__header-left">
        <h1 class="cv__title">Contabilidad</h1>
        <p class="cv__sub">Libro diario · Ingresos · Egresos · Balance</p>
      </div>
      <div class="cv__header-right">
        <button class="cv__btn-ghost" @click="exportar">
          <i class="bi bi-download"></i> Exportar CSV
        </button>
        <button v-if="canEdit" class="cv__btn-primary" @click="openCreate">
          <i class="bi bi-plus-lg"></i> Nuevo movimiento
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="cv__tabs">
      <button class="cv__tab" :class="{ 'cv__tab--active': vistaActiva === 'dashboard' }" @click="vistaActiva = 'dashboard'">
        <i class="bi bi-grid-1x2"></i> Dashboard
      </button>
      <button class="cv__tab" :class="{ 'cv__tab--active': vistaActiva === 'libro' }" @click="irALibro">
        <i class="bi bi-journal-text"></i> Libro diario
      </button>
    </div>

    <!-- ══════════════ DASHBOARD ══════════════ -->
    <div v-if="vistaActiva === 'dashboard'">

      <div v-if="store.loadingDashboard" class="cv__loading">
        <div class="cv__ring"></div><span>Cargando…</span>
      </div>

      <template v-else-if="store.dashboard">

        <!-- KPIs -->
        <div class="cv__kpis">
          <div class="cv__kpi">
            <div class="cv__kpi-label">Ingresos este mes</div>
            <div class="cv__kpi-val cv__kpi-val--green">{{ fmt(store.dashboard.mes_actual.ingresos) }}</div>
            <div class="cv__kpi-bar cv__kpi-bar--green"></div>
          </div>
          <div class="cv__kpi">
            <div class="cv__kpi-label">Egresos este mes</div>
            <div class="cv__kpi-val cv__kpi-val--red">{{ fmt(store.dashboard.mes_actual.egresos) }}</div>
            <div class="cv__kpi-bar cv__kpi-bar--red"></div>
          </div>
          <div class="cv__kpi">
            <div class="cv__kpi-label">Balance del mes</div>
            <div class="cv__kpi-val" :style="{ color: balanceColor(store.dashboard.mes_actual.balance) }">
              {{ fmt(store.dashboard.mes_actual.balance) }}
            </div>
            <div class="cv__kpi-bar" :style="{ background: balanceColor(store.dashboard.mes_actual.balance) }"></div>
          </div>
          <div class="cv__kpi cv__kpi--highlight">
            <div class="cv__kpi-label">Balance del año</div>
            <div class="cv__kpi-val" :style="{ color: balanceColor(store.dashboard.anio_actual.balance) }">
              {{ fmt(store.dashboard.anio_actual.balance) }}
            </div>
            <div class="cv__kpi-bar" :style="{ background: balanceColor(store.dashboard.anio_actual.balance) }"></div>
          </div>
        </div>

        <!-- Evolución + Por categoría -->
        <div class="cv__row2">

          <!-- Evolución mensual -->
          <div class="cv__card cv__card--main">
            <div class="cv__card-header">
              <span class="cv__card-title">Evolución mensual {{ new Date().getFullYear() }}</span>
            </div>
            <div v-if="!store.dashboard.anio_actual.por_mes?.length" class="cv__empty-sm">
              Sin datos para el año
            </div>
            <div v-else class="cv__table-wrap">
              <table class="cv__table">
                <thead>
                <tr>
                  <th>Mes</th>
                  <th class="cv__th-right cv__th-green">Ingresos</th>
                  <th class="cv__th-right cv__th-red">Egresos</th>
                  <th class="cv__th-right">Balance</th>
                </tr>
                </thead>
                <tbody>
                <tr v-for="m in store.dashboard.anio_actual.por_mes" :key="m.mes">
                  <td class="cv__td-mes">{{ mesLabel(m.mes_label || m.mes) }}</td>
                  <td class="cv__td-right cv__td-green">{{ fmt(m.ingresos) }}</td>
                  <td class="cv__td-right cv__td-red">{{ fmt(m.egresos) }}</td>
                  <td class="cv__td-right cv__td-bold" :style="{ color: balanceColor(m.balance) }">{{ fmt(m.balance) }}</td>
                </tr>
                </tbody>
                <tfoot>
                <tr>
                  <td class="cv__td-bold">Total año</td>
                  <td class="cv__td-right cv__td-green cv__td-bold">{{ fmt(store.dashboard.anio_actual.ingresos) }}</td>
                  <td class="cv__td-right cv__td-red cv__td-bold">{{ fmt(store.dashboard.anio_actual.egresos) }}</td>
                  <td class="cv__td-right cv__td-bold" :style="{ color: balanceColor(store.dashboard.anio_actual.balance) }">{{ fmt(store.dashboard.anio_actual.balance) }}</td>
                </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <!-- Por categoría -->
          <div class="cv__card">
            <div class="cv__card-header">
              <span class="cv__card-title">Por categoría (mes actual)</span>
            </div>
            <div v-if="!store.dashboard.mes_actual.por_categoria?.length" class="cv__empty-sm">
              Sin movimientos este mes
            </div>
            <div v-else class="cv__cat-list">
              <div v-for="c in store.dashboard.mes_actual.por_categoria" :key="c.categoria + c.tipo" class="cv__cat-item">
                <div class="cv__cat-left">
                  <span class="cv__tipo-pill" :style="{ background: tipoMeta(c.tipo).bg, color: tipoMeta(c.tipo).color }">
                    {{ tipoMeta(c.tipo).label }}
                  </span>
                  <span class="cv__cat-name">{{ catLabel(c.categoria) }}</span>
                </div>
                <span class="cv__cat-monto" :style="{ color: tipoMeta(c.tipo).color }">{{ fmt(c.total) }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Últimos movimientos -->
        <div class="cv__card cv__card--mt">
          <div class="cv__card-header">
            <span class="cv__card-title">Últimos movimientos</span>
            <div class="cv__card-header-right">
              <div class="cv__search-inline">
                <i class="bi bi-search cv__search-icon-sm"></i>
                <input v-model="busquedaDash" class="cv__search-sm" placeholder="Buscar…" />
                <span v-if="busquedaDash" class="cv__search-x" @click="busquedaDash = ''"><i class="bi bi-x"></i></span>
              </div>
              <button class="cv__btn-link" @click="irALibro">Ver todos →</button>
            </div>
          </div>

          <div v-if="!ultimosFiltrados.length" class="cv__empty-sm">
            {{ busquedaDash ? 'Sin resultados para "' + busquedaDash + '"' : 'Sin movimientos todavía' }}
          </div>
          <div v-else class="cv__movs">
            <div v-for="m in ultimosFiltrados" :key="m.id" class="cv__mov">
              <div class="cv__mov-fecha">{{ m.fecha }}</div>
              <div class="cv__mov-tipo">
                <span class="cv__tipo-pill" :style="{ background: tipoMeta(m.tipo).bg, color: tipoMeta(m.tipo).color }">
                  {{ tipoMeta(m.tipo).label }}
                </span>
              </div>
              <div class="cv__mov-desc">{{ m.descripcion }}</div>
              <div class="cv__mov-cat">{{ catLabel(m.categoria) }}</div>
              <div class="cv__mov-monto" :style="{ color: tipoMeta(m.tipo).color }">{{ fmt(m.monto_ars) }}</div>
              <div class="cv__mov-actions">
                <button v-if="canEdit" class="cv__icon-btn" @click="openEdit(m)" title="Editar">
                  <i class="bi bi-pencil"></i>
                </button>
              </div>
            </div>
          </div>
        </div>

      </template>
    </div>

    <!-- ══════════════ LIBRO DIARIO ══════════════ -->
    <div v-else-if="vistaActiva === 'libro'">

      <!-- Filtros -->
      <div class="cv__filtros">
        <div class="cv__filtro-search">
          <i class="bi bi-search cv__search-icon"></i>
          <input v-model="filtroQ" class="cv__filtro-input cv__filtro-input--wide" placeholder="Buscar descripción, categoría, proveedor…" />
          <span v-if="filtroQ" class="cv__search-x cv__search-x--in" @click="filtroQ = ''"><i class="bi bi-x"></i></span>
        </div>
        <select class="cv__filtro-input" v-model="filtroTipo" @change="aplicarFiltros">
          <option value="">Todos los tipos</option>
          <option value="ingreso">Ingreso</option>
          <option value="egreso">Egreso</option>
          <option value="recupero_costo">Recupero</option>
          <option value="ajuste">Ajuste</option>
        </select>
        <select class="cv__filtro-input" v-model="filtroCategoria" @change="aplicarFiltros">
          <option value="">Todas las categorías</option>
          <option v-for="c in CATEGORIAS" :key="c.value" :value="c.value">{{ c.label }}</option>
        </select>
        <select class="cv__filtro-input" v-model="filtroSede" @change="aplicarFiltros">
          <option value="">Todas las sedes</option>
          <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
        </select>
        <div class="cv__filtro-fechas">
          <input type="date" class="cv__filtro-input cv__filtro-input--date" v-model="filtroDesde" placeholder="Desde" @change="aplicarFiltros" />
          <span class="cv__filtro-sep">—</span>
          <input type="date" class="cv__filtro-input cv__filtro-input--date" v-model="filtroHasta" placeholder="Hasta" @change="aplicarFiltros" />
        </div>
        <button v-if="hayFiltros" class="cv__btn-clear" @click="limpiarFiltros">
          <i class="bi bi-x-circle"></i> Limpiar
        </button>
      </div>

      <!-- Totales período -->
      <div class="cv__totales">
        <div class="cv__total cv__total--green">
          <div class="cv__total-label">Ingresos del período</div>
          <div class="cv__total-val">{{ fmt(store.totales.ingresos) }}</div>
        </div>
        <div class="cv__total cv__total--red">
          <div class="cv__total-label">Egresos del período</div>
          <div class="cv__total-val">{{ fmt(store.totales.egresos) }}</div>
        </div>
        <div class="cv__total" :style="{ background: balanceBg(store.totales.balance), borderColor: balanceColor(store.totales.balance) + '40' }">
          <div class="cv__total-label">Balance</div>
          <div class="cv__total-val" :style="{ color: balanceColor(store.totales.balance) }">{{ fmt(store.totales.balance) }}</div>
        </div>
      </div>

      <!-- Tabla -->
      <div class="cv__card">
        <div v-if="store.loading" class="cv__loading"><div class="cv__ring"></div><span>Cargando…</span></div>
        <div v-else-if="!itemsFiltrados.length" class="cv__empty">
          <div class="cv__empty-icon"><i class="bi bi-journal-text"></i></div>
          <div class="cv__empty-title">Sin movimientos</div>
          <p class="cv__empty-desc">{{ filtroQ || hayFiltros ? 'Probá ajustando los filtros.' : 'Registrá el primer movimiento.' }}</p>
          <button v-if="canEdit && !filtroQ && !hayFiltros" class="cv__btn-primary" @click="openCreate">
            <i class="bi bi-plus-lg"></i> Nuevo movimiento
          </button>
        </div>
        <div v-else class="cv__table-wrap">
          <table class="cv__table">
            <thead>
            <tr>
              <th>Fecha</th>
              <th>Descripción</th>
              <th>Categoría</th>
              <th>Sede</th>
              <th class="cv__th-right">Monto ARS</th>
              <th>Estado</th>
              <th v-if="canEdit"></th>
            </tr>
            </thead>
            <tbody>
            <tr v-for="m in itemsFiltrados" :key="m.id" class="cv__tr">
              <td class="cv__td-fecha">{{ m.fecha }}</td>
              <td>
                <div class="cv__desc-cell">
                    <span class="cv__tipo-pill cv__tipo-pill--sm" :style="{ background: tipoMeta(m.tipo).bg, color: tipoMeta(m.tipo).color }">
                      {{ tipoMeta(m.tipo).label }}
                    </span>
                  <span class="cv__desc-text">{{ m.descripcion }}</span>
                </div>
              </td>
              <td class="cv__td-muted">{{ catLabel(m.categoria) }}</td>
              <td class="cv__td-muted">{{ m.sede?.nombre || '—' }}</td>
              <td class="cv__td-right cv__td-bold" :style="{ color: tipoMeta(m.tipo).color }">{{ fmt(m.monto_ars) }}</td>
              <td>
                  <span class="cv__pagado-pill" :class="m.pagado ? 'cv__pagado-pill--ok' : 'cv__pagado-pill--pend'">
                    {{ m.pagado ? '✓ Pagado' : 'Pendiente' }}
                  </span>
              </td>
              <td v-if="canEdit">
                <div class="cv__row-actions">
                  <button class="cv__icon-btn" @click="openEdit(m)"><i class="bi bi-pencil"></i></button>
                  <button class="cv__icon-btn cv__icon-btn--danger" @click="confirmDelete(m)"><i class="bi bi-trash"></i></button>
                </div>
              </td>
            </tr>
            </tbody>
          </table>
        </div>

        <!-- Paginación -->
        <div v-if="store.pagination.total_pages > 1" class="cv__pagination">
          <button class="cv__page-btn" :disabled="store.pagination.page <= 1" @click="goToPage(store.pagination.page - 1)">
            <i class="bi bi-chevron-left"></i>
          </button>
          <button
            v-for="p in store.pagination.total_pages" :key="p"
            class="cv__page-btn" :class="{ 'cv__page-btn--active': p === store.pagination.page }"
            @click="goToPage(p)"
          >{{ p }}</button>
          <button class="cv__page-btn" :disabled="store.pagination.page >= store.pagination.total_pages" @click="goToPage(store.pagination.page + 1)">
            <i class="bi bi-chevron-right"></i>
          </button>
          <span class="cv__page-info">Página {{ store.pagination.page }} de {{ store.pagination.total_pages }}</span>
        </div>
      </div>
    </div>

    <!-- ══════════════ MODAL CREAR/EDITAR ══════════════ -->
    <Teleport to="body">
      <div v-if="showModal" class="cv__overlay" @click.self="showModal = false">
        <div class="cv__modal">
          <div class="cv__modal-header">
            <div>
              <h3 class="cv__modal-title">{{ editingId ? 'Editar movimiento' : 'Nuevo movimiento' }}</h3>
              <p class="cv__modal-sub">{{ editingId ? 'Modificá los datos del movimiento' : 'Registrá un ingreso o egreso en el libro diario' }}</p>
            </div>
            <button class="cv__modal-close" @click="showModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="cv__modal-body">

            <div v-if="store.createError || store.updateError" class="cv__alert">
              {{ store.createError || store.updateError }}
            </div>

            <!-- Tipo selector visual -->
            <div class="cv__mfield cv__mfield--full">
              <label class="cv__mlabel">Tipo <span class="cv__req">*</span></label>
              <div class="cv__tipo-btns">
                <button v-for="t in [
                  { value:'ingreso',        label:'Ingreso',   color:'#15803d' },
                  { value:'egreso',         label:'Egreso',    color:'#dc2626' },
                  { value:'recupero_costo', label:'Recupero',  color:'#0369a1' },
                  { value:'ajuste',         label:'Ajuste',    color:'#64748b' },
                ]" :key="t.value"
                        type="button" class="cv__tipo-btn"
                        :class="{ 'cv__tipo-btn--active': form.tipo === t.value }"
                        :style="form.tipo === t.value ? { background: t.color + '15', borderColor: t.color, color: t.color } : {}"
                        @click="form.tipo = t.value"
                >{{ t.label }}</button>
              </div>
            </div>

            <div class="cv__mgrid">

              <div class="cv__mfield">
                <label class="cv__mlabel">Categoría <span class="cv__req">*</span></label>
                <select class="cv__minput" v-model="form.categoria" :class="{ 'cv__minput--err': formErrors.categoria }">
                  <option value="">Seleccioná…</option>
                  <option v-for="c in categoriasForm" :key="c.value" :value="c.value">{{ c.label }}</option>
                </select>
                <span v-if="formErrors.categoria" class="cv__merr">{{ formErrors.categoria }}</span>
              </div>

              <div class="cv__mfield">
                <label class="cv__mlabel">Fecha <span class="cv__req">*</span></label>
                <input type="date" class="cv__minput" v-model="form.fecha" :class="{ 'cv__minput--err': formErrors.fecha }" />
                <span v-if="formErrors.fecha" class="cv__merr">{{ formErrors.fecha }}</span>
              </div>

              <div class="cv__mfield cv__mfield--full">
                <label class="cv__mlabel">Descripción <span class="cv__req">*</span></label>
                <input type="text" class="cv__minput" v-model.trim="form.descripcion"
                       :class="{ 'cv__minput--err': formErrors.descripcion }"
                       placeholder="Ej: Factura electricidad Sede Avellaneda marzo" />
                <span v-if="formErrors.descripcion" class="cv__merr">{{ formErrors.descripcion }}</span>
              </div>

              <div class="cv__mfield">
                <label class="cv__mlabel">Monto ARS <span class="cv__req">*</span></label>
                <div class="cv__minput-prefix-wrap">
                  <span class="cv__minput-prefix">$</span>
                  <input type="number" min="0.01" step="0.01" class="cv__minput cv__minput--prefixed"
                         v-model.number="form.monto_ars" :class="{ 'cv__minput--err': formErrors.monto_ars }" />
                </div>
                <span v-if="formErrors.monto_ars" class="cv__merr">{{ formErrors.monto_ars }}</span>
              </div>

              <div class="cv__mfield">
                <label class="cv__mlabel">Medio de pago</label>
                <select class="cv__minput" v-model="form.medio_pago">
                  <option value="efectivo">Efectivo</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="mercado_pago">Mercado Pago</option>
                  <option value="debito">Débito</option>
                  <option value="cheque">Cheque</option>
                </select>
              </div>

              <div class="cv__mfield">
                <label class="cv__mlabel">Sede <span class="cv__mopt">opcional</span></label>
                <select class="cv__minput" v-model="form.sede_id">
                  <option :value="null">Sin sede específica</option>
                  <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>

              <div class="cv__mfield">
                <label class="cv__mlabel">Proveedor / Origen <span class="cv__mopt">opcional</span></label>
                <input type="text" class="cv__minput" v-model.trim="form.proveedor" placeholder="Edenor, AYSA, Proveedor S.A.…" />
              </div>

              <div class="cv__mfield">
                <label class="cv__mlabel">Tipo comprobante</label>
                <select class="cv__minput" v-model="form.comprobante_tipo">
                  <option value="sin_comprobante">Sin comprobante</option>
                  <option value="factura_a">Factura A</option>
                  <option value="factura_b">Factura B</option>
                  <option value="recibo">Recibo</option>
                  <option value="ticket">Ticket</option>
                </select>
              </div>

              <div class="cv__mfield">
                <label class="cv__mlabel">N° comprobante <span class="cv__mopt">opcional</span></label>
                <input type="text" class="cv__minput" v-model.trim="form.comprobante_numero" placeholder="0001-00001234" />
              </div>

              <div class="cv__mfield cv__mfield--full">
                <label class="cv__toggle-wrap">
                  <input type="checkbox" class="cv__toggle-chk" v-model="form.pagado" />
                  <div class="cv__toggle-track"><div class="cv__toggle-thumb"></div></div>
                  <span class="cv__toggle-label">Pagado / Cobrado</span>
                </label>
              </div>

              <div class="cv__mfield cv__mfield--full">
                <label class="cv__mlabel">Notas <span class="cv__mopt">opcional</span></label>
                <textarea class="cv__minput cv__mtextarea" rows="2" v-model.trim="form.notas" placeholder="Observaciones…"></textarea>
              </div>

            </div>
          </div>
          <div class="cv__modal-footer">
            <button class="cv__btn-ghost" :disabled="store.creating || store.updating" @click="showModal = false">Cancelar</button>
            <button class="cv__btn-primary" :disabled="store.creating || store.updating" @click="submitForm">
              <div v-if="store.creating || store.updating" class="cv__spin"></div>
              <i v-else class="bi bi-check-lg"></i>
              {{ editingId ? 'Guardar cambios' : 'Crear movimiento' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══════════════ MODAL ELIMINAR ══════════════ -->
    <Teleport to="body">
      <div v-if="showDelete" class="cv__overlay" @click.self="showDelete = false">
        <div class="cv__modal cv__modal--sm">
          <div class="cv__delete-icon"><i class="bi bi-exclamation-triangle-fill"></i></div>
          <h3 class="cv__delete-title">¿Eliminar movimiento?</h3>
          <p class="cv__delete-desc">
            <strong>{{ toDelete?.descripcion }}</strong><br>
            {{ fmt(toDelete?.monto_ars) }} · {{ toDelete?.fecha }}
          </p>
          <div v-if="store.removeError" class="cv__alert">{{ store.removeError }}</div>
          <div class="cv__delete-actions">
            <button class="cv__btn-ghost" @click="showDelete = false">Cancelar</button>
            <button class="cv__btn-danger" :disabled="store.removing" @click="doDelete">
              <div v-if="store.removing" class="cv__spin cv__spin--white"></div>
              <i v-else class="bi bi-trash"></i> Eliminar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.cv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .cv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.cv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.cv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.cv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.cv__header-right { display: flex; gap: .65rem; align-items: center; flex-wrap: wrap; }

/* Tabs */
.cv__tabs { display: flex; gap: .25rem; border-bottom: 2px solid #e2e8f0; margin-bottom: 1.75rem; }
.cv__tab { display: flex; align-items: center; gap: .4rem; padding: .65rem 1.1rem; font-size: .875rem; font-weight: 600; color: #64748b; background: none; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; cursor: pointer; transition: all .15s; }
.cv__tab:hover { color: #0f172a; }
.cv__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }

/* KPIs */
.cv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.5rem; }
@media (max-width: 900px) { .cv__kpis { grid-template-columns: 1fr 1fr; } }
@media (max-width: 480px) { .cv__kpis { grid-template-columns: 1fr; } }
.cv__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; position: relative; overflow: hidden; }
.cv__kpi--highlight { border-color: #d4e6d4; background: #f9fdf9; }
.cv__kpi-label { font-size: .72rem; color: #64748b; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .5rem; }
.cv__kpi-val { font-size: 1.4rem; font-weight: 800; letter-spacing: -.03em; }
.cv__kpi-val--green { color: #15803d; }
.cv__kpi-val--red   { color: #dc2626; }
.cv__kpi-bar { position: absolute; bottom: 0; left: 0; right: 0; height: 3px; }
.cv__kpi-bar--green { background: #15803d; }
.cv__kpi-bar--red   { background: #dc2626; }

/* Row 2 */
.cv__row2 { display: grid; grid-template-columns: 1fr 320px; gap: 1rem; margin-bottom: 1.5rem; }
@media (max-width: 1000px) { .cv__row2 { grid-template-columns: 1fr; } }

/* Cards */
.cv__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.cv__card--main { flex: 1; }
.cv__card--mt { margin-top: 1.25rem; }
.cv__card-header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; flex-wrap: wrap; gap: .5rem; }
.cv__card-title { font-size: .9rem; font-weight: 700; color: #0f172a; }
.cv__card-header-right { display: flex; align-items: center; gap: .65rem; flex-wrap: wrap; }

/* Search inline */
.cv__search-inline { position: relative; display: flex; align-items: center; }
.cv__search-icon-sm { position: absolute; left: .6rem; font-size: .75rem; color: #94a3b8; pointer-events: none; }
.cv__search-sm { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .4rem .65rem .4rem 1.75rem; font-size: .78rem; width: 160px; outline: none; transition: border-color .15s; }
.cv__search-sm:focus { border-color: #1b5e20; }
.cv__search-x { position: absolute; right: .5rem; color: #94a3b8; cursor: pointer; font-size: .9rem; display: flex; align-items: center; }
.cv__search-x:hover { color: #0f172a; }

/* Últimos movimientos */
.cv__movs { display: flex; flex-direction: column; }
.cv__mov { display: grid; grid-template-columns: 90px 80px 1fr 140px 110px 36px; align-items: center; gap: .5rem; padding: .75rem 1.25rem; border-bottom: 1px solid #f8fafc; transition: background .1s; }
.cv__mov:last-child { border-bottom: none; }
.cv__mov:hover { background: #fafbfc; }
@media (max-width: 900px) { .cv__mov { grid-template-columns: 1fr; } }
.cv__mov-fecha { font-size: .72rem; color: #94a3b8; font-family: monospace; }
.cv__mov-tipo { }
.cv__mov-desc { font-size: .82rem; color: #0f172a; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__mov-cat { font-size: .75rem; color: #64748b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__mov-monto { font-size: .875rem; font-weight: 700; text-align: right; letter-spacing: -.02em; }
.cv__mov-actions { display: flex; justify-content: flex-end; }

/* Por categoría */
.cv__cat-list { display: flex; flex-direction: column; }
.cv__cat-item { display: flex; align-items: center; justify-content: space-between; padding: .65rem 1.25rem; border-bottom: 1px solid #f8fafc; }
.cv__cat-item:last-child { border-bottom: none; }
.cv__cat-left { display: flex; align-items: center; gap: .6rem; min-width: 0; }
.cv__cat-name { font-size: .8rem; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cv__cat-monto { font-size: .82rem; font-weight: 700; flex-shrink: 0; }

/* Tipo pill */
.cv__tipo-pill { display: inline-flex; align-items: center; font-size: .68rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; white-space: nowrap; }
.cv__tipo-pill--sm { font-size: .64rem; }

/* Filtros */
.cv__filtros { display: flex; align-items: center; gap: .65rem; margin-bottom: 1.1rem; flex-wrap: wrap; }
.cv__filtro-search { position: relative; display: flex; align-items: center; flex: 1; min-width: 200px; }
.cv__search-icon { position: absolute; left: .75rem; color: #94a3b8; font-size: .8rem; pointer-events: none; }
.cv__filtro-input { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; color: #0f172a; outline: none; transition: border-color .15s; }
.cv__filtro-input--wide { padding-left: 2.25rem; width: 100%; }
.cv__filtro-input--date { width: 140px; }
.cv__filtro-input:focus { border-color: #1b5e20; }
.cv__search-x--in { position: absolute; right: .6rem; color: #94a3b8; cursor: pointer; font-size: .9rem; display: flex; }
.cv__search-x--in:hover { color: #0f172a; }
.cv__filtro-fechas { display: flex; align-items: center; gap: .4rem; }
.cv__filtro-sep { color: #94a3b8; font-size: .8rem; }
.cv__btn-clear { display: inline-flex; align-items: center; gap: .3rem; background: none; border: 1.5px solid #e2e8f0; color: #64748b; padding: .55rem .875rem; border-radius: 9px; font-size: .8rem; font-weight: 500; cursor: pointer; white-space: nowrap; transition: all .15s; }
.cv__btn-clear:hover { border-color: #dc2626; color: #dc2626; background: #fef2f2; }

/* Totales */
.cv__totales { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: .875rem; margin-bottom: 1.1rem; }
@media (max-width: 640px) { .cv__totales { grid-template-columns: 1fr; } }
.cv__total { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: 1rem 1.25rem; }
.cv__total--green { background: rgba(21,128,61,.06); border-color: rgba(21,128,61,.2); }
.cv__total--red   { background: rgba(220,38,38,.06); border-color: rgba(220,38,38,.2); }
.cv__total-label { font-size: .72rem; color: #64748b; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .3rem; }
.cv__total-val { font-size: 1.2rem; font-weight: 800; letter-spacing: -.03em; }
.cv__total--green .cv__total-val { color: #15803d; }
.cv__total--red   .cv__total-val { color: #dc2626; }

/* Tabla */
.cv__table-wrap { overflow-x: auto; }
.cv__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.cv__table th { padding: .75rem 1rem; font-size: .7rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1.5px solid #f1f5f9; background: #fafbfc; white-space: nowrap; }
.cv__table td { padding: .75rem 1rem; border-bottom: 1px solid #f8fafc; vertical-align: middle; }
.cv__table tfoot td { padding: .75rem 1rem; border-top: 2px solid #e2e8f0; font-weight: 700; background: #fafbfc; }
.cv__table tbody tr:last-child td { border-bottom: none; }
.cv__table tbody tr:hover td { background: #fafbfc; }
.cv__th-right { text-align: right; }
.cv__th-green  { color: #15803d !important; }
.cv__th-red    { color: #dc2626 !important; }
.cv__td-right  { text-align: right; }
.cv__td-green  { color: #15803d; }
.cv__td-red    { color: #dc2626; }
.cv__td-bold   { font-weight: 700; }
.cv__td-muted  { color: #64748b; font-size: .78rem; }
.cv__td-fecha  { color: #94a3b8; font-size: .75rem; font-family: monospace; white-space: nowrap; }
.cv__td-mes    { font-weight: 500; color: #0f172a; }
.cv__desc-cell { display: flex; align-items: center; gap: .5rem; }
.cv__desc-text { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 280px; }

/* Pagado pill */
.cv__pagado-pill { font-size: .68rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; white-space: nowrap; }
.cv__pagado-pill--ok   { background: rgba(21,128,61,.1); color: #15803d; }
.cv__pagado-pill--pend { background: rgba(180,83,9,.1);  color: #b45309; }

/* Row actions */
.cv__row-actions { display: flex; gap: .35rem; justify-content: flex-end; }

/* Icon buttons */
.cv__icon-btn { width: 28px; height: 28px; border-radius: 7px; border: 1px solid #e2e8f0; background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center; cursor: pointer; font-size: .75rem; transition: all .15s; }
.cv__icon-btn:hover { background: #e2e8f0; color: #0f172a; }
.cv__icon-btn--danger:hover { background: #fef2f2; border-color: #fecaca; color: #dc2626; }

/* Empty */
.cv__empty { text-align: center; padding: 3.5rem 1rem; color: #94a3b8; }
.cv__empty-sm { text-align: center; padding: 2rem 1rem; color: #94a3b8; font-size: .85rem; }
.cv__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; opacity: .4; }
.cv__empty-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin-bottom: .5rem; }
.cv__empty-desc { font-size: .875rem; margin-bottom: 1.25rem; }

/* Paginación */
.cv__pagination { display: flex; align-items: center; gap: .35rem; padding: 1rem 1.25rem; border-top: 1px solid #f1f5f9; }
.cv__page-btn { width: 32px; height: 32px; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #fff; color: #64748b; font-size: .8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all .15s; }
.cv__page-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.cv__page-btn--active { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.cv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.cv__page-info { font-size: .75rem; color: #94a3b8; margin-left: .5rem; }

/* Buttons */
.cv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.cv__btn-primary:hover:not(:disabled) { background: #144a18; }
.cv__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.cv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .65rem 1.1rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; white-space: nowrap; }
.cv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.cv__btn-danger { display: inline-flex; align-items: center; gap: .35rem; background: #dc2626; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.cv__btn-danger:hover:not(:disabled) { background: #b91c1c; }
.cv__btn-danger:disabled { opacity: .55; cursor: not-allowed; }
.cv__btn-link { background: none; border: none; color: #1b5e20; font-size: .8rem; font-weight: 600; cursor: pointer; padding: 0; white-space: nowrap; }
.cv__btn-link:hover { text-decoration: underline; }

/* Loading */
.cv__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 4rem; color: #94a3b8; }
.cv__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: cv-spin .7s linear infinite; }
@keyframes cv-spin { to { transform: rotate(360deg); } }

/* Modal */
.cv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.cv__modal { background: #fff; border-radius: 18px; width: 100%; max-width: 620px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(0,0,0,.15); display: flex; flex-direction: column; }
.cv__modal--sm { max-width: 420px; text-align: center; padding: 2.5rem 2rem; }
.cv__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.5rem 1.5rem 1.25rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.cv__modal-title { font-size: 1.05rem; font-weight: 700; color: #0f172a; margin: 0; }
.cv__modal-sub { font-size: .78rem; color: #64748b; margin: .2rem 0 0; }
.cv__modal-close { background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 9px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; }
.cv__modal-close:hover { background: #e2e8f0; }
.cv__modal-body { padding: 1.5rem; flex: 1; }
.cv__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1.1rem 1.5rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }

/* Form */
.cv__mgrid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 500px) { .cv__mgrid { grid-template-columns: 1fr; } }
.cv__mfield { display: flex; flex-direction: column; gap: .35rem; }
.cv__mfield--full { grid-column: 1 / -1; }
.cv__mlabel { font-size: .78rem; font-weight: 600; color: #374151; }
.cv__req { color: #ef4444; }
.cv__mopt { font-size: .7rem; font-weight: 400; color: #94a3b8; }
.cv__minput { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s; }
.cv__minput:focus { border-color: #1b5e20; background: #fff; }
.cv__minput--err { border-color: #ef4444; }
.cv__minput--prefixed { border-radius: 0 9px 9px 0; border-left: none; }
.cv__minput-prefix-wrap { display: flex; }
.cv__minput-prefix { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-right: none; border-radius: 9px 0 0 9px; padding: .65rem .75rem; font-size: .85rem; font-weight: 700; color: #1b5e20; }
.cv__mtextarea { resize: vertical; min-height: 65px; }
.cv__merr { font-size: .73rem; color: #dc2626; }

/* Tipo buttons */
.cv__tipo-btns { display: flex; gap: .5rem; flex-wrap: wrap; margin-bottom: .25rem; }
.cv__tipo-btn { padding: .45rem 1rem; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #f8fafc; font-size: .82rem; font-weight: 500; cursor: pointer; color: #475569; transition: all .15s; }
.cv__tipo-btn:hover { border-color: #cbd5e1; }
.cv__tipo-btn--active { font-weight: 700; }

/* Toggle */
.cv__toggle-wrap { display: flex; align-items: center; gap: .65rem; cursor: pointer; }
.cv__toggle-chk { display: none; }
.cv__toggle-track { width: 38px; height: 21px; background: #d1d5db; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.cv__toggle-chk:checked + .cv__toggle-track { background: #1b5e20; }
.cv__toggle-thumb { position: absolute; width: 15px; height: 15px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.cv__toggle-chk:checked + .cv__toggle-track .cv__toggle-thumb { left: 20px; }
.cv__toggle-label { font-size: .875rem; font-weight: 500; color: #0f172a; }

/* Alert */
.cv__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }

/* Delete modal */
.cv__delete-icon { width: 56px; height: 56px; border-radius: 50%; background: #fef2f2; color: #dc2626; font-size: 1.4rem; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.1rem; }
.cv__delete-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin: 0 0 .65rem; letter-spacing: -.03em; }
.cv__delete-desc { font-size: .875rem; color: #64748b; line-height: 1.6; margin: 0 0 1.5rem; }
.cv__delete-actions { display: flex; gap: .65rem; justify-content: center; }

/* Spinner */
.cv__spin { width: 14px; height: 14px; border: 2px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: cv-spin .6s linear infinite; }
.cv__spin--white { border-color: rgba(255,255,255,.3); border-top-color: #fff; }
</style>
