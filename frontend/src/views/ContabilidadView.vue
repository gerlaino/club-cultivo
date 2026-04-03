<script setup>
import { ref, computed, onMounted, watch } from "vue";
import { useContabilidadStore } from "../stores/contabilidad";
import { useAuthStore }         from "../stores/auth";
import { listSedes, listSalas } from "../lib/api";

const store = useContabilidadStore();
const auth  = useAuthStore();

const sedes = ref([]);
const lotes = ref([]);

const canEdit = computed(() => ["admin","abogado"].includes(auth.role));

// ── Vista activa ──────────────────────────────────────────────────────────────
const vistaActiva = ref("dashboard"); // "dashboard" | "libro"

// ── Helpers de formato ────────────────────────────────────────────────────────
const fmt = (n) => new Intl.NumberFormat("es-AR", { style: "currency", currency: "ARS",
  minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(n || 0);

function tipoBadge(tipo) {
  return { egreso: "danger", ingreso: "success", recupero_costo: "primary", ajuste: "secondary" }[tipo] || "secondary";
}
function tipoIcon(tipo) {
  return { egreso: "↑", ingreso: "↓", recupero_costo: "⇄", ajuste: "≈" }[tipo] || "•";
}
function balanceColor(n) {
  return n >= 0 ? "text-success" : "text-danger";
}

const CATEGORIAS = [
  { value: "insumo",        label: "Insumo / Materia prima",    tipo: "egreso"  },
  { value: "electricidad",  label: "Electricidad",              tipo: "egreso"  },
  { value: "agua",          label: "Agua",                      tipo: "egreso"  },
  { value: "alquiler",      label: "Alquiler",                  tipo: "egreso"  },
  { value: "sueldo",        label: "Sueldo / Staff",            tipo: "egreso"  },
  { value: "mantenimiento", label: "Mantenimiento",             tipo: "egreso"  },
  { value: "honorario",     label: "Honorario profesional",     tipo: "egreso"  },
  { value: "seguro",        label: "Seguro",                    tipo: "egreso"  },
  { value: "admin",         label: "Gasto administrativo",      tipo: "egreso"  },
  { value: "aporte_socio",  label: "Aporte socio",              tipo: "ingreso" },
  { value: "dispensacion",  label: "Recupero dispensación",     tipo: "ingreso" },
  { value: "subvencion",    label: "Subvención / Donación",     tipo: "ingreso" },
  { value: "otro",          label: "Otro",                      tipo: "ambos"   },
];
const CATEGORIAS_EGRESO  = CATEGORIAS.filter(c => c.tipo === "egreso");
const CATEGORIAS_INGRESO = CATEGORIAS.filter(c => c.tipo === "ingreso");

function catLabel(cat) {
  return CATEGORIAS.find(c => c.value === cat)?.label || cat || "—";
}

// ── Filtros ───────────────────────────────────────────────────────────────────
const filtroTipo      = ref("");
const filtroCategoria = ref("");
const filtroSede      = ref("");
const filtroDesde     = ref("");
const filtroHasta     = ref("");

async function aplicarFiltros() {
  store.setFiltro("tipo",      filtroTipo.value);
  store.setFiltro("categoria", filtroCategoria.value);
  store.setFiltro("sede_id",   filtroSede.value);
  store.setFiltro("desde",     filtroDesde.value);
  store.setFiltro("hasta",     filtroHasta.value);
  await store.fetch();
}
function limpiarFiltros() {
  filtroTipo.value = filtroCategoria.value = filtroSede.value = "";
  filtroDesde.value = filtroHasta.value = "";
  store.resetFiltros();
  store.fetch();
}

// ── Categorías filtradas por tipo seleccionado en form ────────────────────────
const categoriasForm = computed(() => {
  const t = form.value.tipo;
  if (t === "egreso")  return CATEGORIAS.filter(c => c.tipo === "egreso"  || c.tipo === "ambos");
  if (t === "ingreso" || t === "recupero_costo")
    return CATEGORIAS.filter(c => c.tipo === "ingreso" || c.tipo === "ambos");
  return CATEGORIAS;
});

// ── Modal Crear/Editar ────────────────────────────────────────────────────────
const showModal  = ref(false);
const editingId  = ref(null);
const formErrors = ref({});

function emptyForm() {
  return {
    tipo:               "egreso",
    categoria:          "",
    descripcion:        "",
    monto_ars:          null,
    fecha:              new Date().toISOString().slice(0, 10),
    sede_id:            null,
    lote_id:            null,
    comprobante_numero: "",
    comprobante_tipo:   "sin_comprobante",
    proveedor:          "",
    pagado:             false,
    medio_pago:         "efectivo",
    notas:              "",
  };
}
const form = ref(emptyForm());

// Al cambiar tipo, limpiar categoría incompatible
watch(() => form.value.tipo, () => { form.value.categoria = ""; });

function openCreate() {
  editingId.value  = null;
  form.value       = emptyForm();
  formErrors.value = {};
  showModal.value  = true;
}
function openEdit(m) {
  editingId.value = m.id;
  form.value = {
    tipo:               m.tipo,
    categoria:          m.categoria,
    descripcion:        m.descripcion,
    monto_ars:          m.monto_ars,
    fecha:              m.fecha,
    sede_id:            m.sede?.id || null,
    lote_id:            m.lote?.id || null,
    comprobante_numero: m.comprobante_numero || "",
    comprobante_tipo:   m.comprobante_tipo   || "sin_comprobante",
    proveedor:          m.proveedor          || "",
    pagado:             m.pagado             || false,
    medio_pago:         m.medio_pago         || "efectivo",
    notas:              m.notas              || "",
  };
  formErrors.value = {};
  showModal.value  = true;
}

function validate(f) {
  const e = {};
  if (!f.tipo)        e.tipo        = "Requerido";
  if (!f.categoria)   e.categoria   = "Requerido";
  if (!f.descripcion?.trim()) e.descripcion = "Requerido";
  if (!f.monto_ars || f.monto_ars <= 0) e.monto_ars = "Debe ser mayor a 0";
  if (!f.fecha)       e.fecha       = "Requerido";
  return e;
}

async function submitForm() {
  const e = validate(form.value);
  formErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    if (editingId.value) {
      await store.update(editingId.value, form.value);
    } else {
      await store.create(form.value);
    }
    showModal.value = false;
    if (vistaActiva.value === "dashboard") await store.fetchDashboard();
  } catch {}
}

// ── Modal Eliminar ────────────────────────────────────────────────────────────
const showDelete  = ref(false);
const toDelete    = ref(null);
function confirmDelete(m) { toDelete.value = m; showDelete.value = true; }
async function doDelete() {
  if (!toDelete.value) return;
  await store.remove(toDelete.value.id);
  showDelete.value = false;
  toDelete.value   = null;
}

// ── Paginación ────────────────────────────────────────────────────────────────
async function goToPage(p) {
  store.setFiltro("page", p);
  await store.fetch();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

// ── Export CSV ────────────────────────────────────────────────────────────────
async function exportar() {
  const params = {};
  if (filtroDesde.value) params.desde = filtroDesde.value;
  if (filtroHasta.value) params.hasta = filtroHasta.value;
  await store.exportCSV(params);
}

// ── Init ──────────────────────────────────────────────────────────────────────
onMounted(async () => {
  await Promise.all([
    store.fetchDashboard(),
    store.fetch(),
    listSedes().then(r => { sedes.value = r.data || []; }),
  ]);
});
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- ── Header ── -->
    <div class="d-flex justify-content-between align-items-start mb-4 flex-wrap gap-3">
      <div>
        <h1 class="h3 fw-bold mb-1">💰 Contabilidad</h1>
        <p class="text-muted small mb-0">Libro diario · Ingresos · Egresos · Balance</p>
      </div>
      <div class="d-flex gap-2 flex-wrap">
        <button class="btn btn-outline-secondary btn-sm" @click="exportar">
          ⬇ Exportar CSV
        </button>
        <button v-if="canEdit" class="btn btn-primary" @click="openCreate">
          ＋ Nuevo movimiento
        </button>
      </div>
    </div>

    <!-- ── Tabs ── -->
    <ul class="nav nav-tabs mb-4">
      <li class="nav-item">
        <button class="nav-link" :class="{ active: vistaActiva === 'dashboard' }"
                @click="vistaActiva = 'dashboard'">
          📊 Dashboard
        </button>
      </li>
      <li class="nav-item">
        <button class="nav-link" :class="{ active: vistaActiva === 'libro' }"
                @click="vistaActiva = 'libro'; store.fetch()">
          📒 Libro diario
        </button>
      </li>
    </ul>

    <!-- ════════════════════ DASHBOARD ════════════════════ -->
    <div v-if="vistaActiva === 'dashboard'">

      <div v-if="store.loadingDashboard" class="text-center py-5">
        <div class="spinner-border text-primary"></div>
      </div>

      <template v-else-if="store.dashboard">
        <!-- KPIs mes actual -->
        <div class="row g-3 mb-4">
          <div class="col-6 col-md-3">
            <div class="card border-0 bg-body-secondary h-100">
              <div class="card-body py-3">
                <div class="text-muted small">Ingresos este mes</div>
                <div class="h4 fw-bold mb-0 text-success">
                  {{ fmt(store.dashboard.mes_actual.ingresos) }}
                </div>
              </div>
            </div>
          </div>
          <div class="col-6 col-md-3">
            <div class="card border-0 bg-body-secondary h-100">
              <div class="card-body py-3">
                <div class="text-muted small">Egresos este mes</div>
                <div class="h4 fw-bold mb-0 text-danger">
                  {{ fmt(store.dashboard.mes_actual.egresos) }}
                </div>
              </div>
            </div>
          </div>
          <div class="col-6 col-md-3">
            <div class="card border-0 bg-body-secondary h-100">
              <div class="card-body py-3">
                <div class="text-muted small">Balance mes</div>
                <div class="h4 fw-bold mb-0" :class="balanceColor(store.dashboard.mes_actual.balance)">
                  {{ fmt(store.dashboard.mes_actual.balance) }}
                </div>
              </div>
            </div>
          </div>
          <div class="col-6 col-md-3">
            <div class="card border-0 bg-body-secondary h-100">
              <div class="card-body py-3">
                <div class="text-muted small">Balance año</div>
                <div class="h4 fw-bold mb-0" :class="balanceColor(store.dashboard.anio_actual.balance)">
                  {{ fmt(store.dashboard.anio_actual.balance) }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="row g-4 mb-4">
          <!-- Evolución mensual -->
          <div class="col-12 col-lg-8">
            <div class="card border-0 shadow-sm h-100">
              <div class="card-header bg-transparent">
                <strong>📈 Evolución mensual {{ new Date().getFullYear() }}</strong>
              </div>
              <div class="card-body p-0">
                <div v-if="!store.dashboard.anio_actual.por_mes?.length" class="p-4 text-center text-muted">
                  Sin datos para el año
                </div>
                <div v-else class="table-responsive">
                  <table class="table table-hover table-sm align-middle mb-0">
                    <thead class="table-light">
                    <tr>
                      <th>Mes</th>
                      <th class="text-end text-success">Ingresos</th>
                      <th class="text-end text-danger">Egresos</th>
                      <th class="text-end">Balance</th>
                    </tr>
                    </thead>
                    <tbody>
                    <tr v-for="m in store.dashboard.anio_actual.por_mes" :key="m.mes">
                      <td class="text-capitalize">{{ m.mes_label }}</td>
                      <td class="text-end text-success small">{{ fmt(m.ingresos) }}</td>
                      <td class="text-end text-danger small">{{ fmt(m.egresos) }}</td>
                      <td class="text-end small fw-semibold" :class="balanceColor(m.balance)">
                        {{ fmt(m.balance) }}
                      </td>
                    </tr>
                    </tbody>
                    <tfoot class="table-light">
                    <tr class="fw-bold">
                      <td>Total año</td>
                      <td class="text-end text-success">{{ fmt(store.dashboard.anio_actual.ingresos) }}</td>
                      <td class="text-end text-danger">{{ fmt(store.dashboard.anio_actual.egresos) }}</td>
                      <td class="text-end" :class="balanceColor(store.dashboard.anio_actual.balance)">
                        {{ fmt(store.dashboard.anio_actual.balance) }}
                      </td>
                    </tr>
                    </tfoot>
                  </table>
                </div>
              </div>
            </div>
          </div>

          <!-- Desglose por categoría -->
          <div class="col-12 col-lg-4">
            <div class="card border-0 shadow-sm h-100">
              <div class="card-header bg-transparent">
                <strong>📋 Por categoría (mes actual)</strong>
              </div>
              <div class="card-body p-0">
                <div v-if="!store.dashboard.mes_actual.por_categoria?.length"
                     class="p-4 text-center text-muted small">
                  Sin movimientos este mes
                </div>
                <div v-else class="list-group list-group-flush">
                  <div v-for="c in store.dashboard.mes_actual.por_categoria" :key="c.categoria + c.tipo"
                       class="list-group-item px-3 py-2 d-flex justify-content-between align-items-center">
                    <div>
                      <span class="badge me-2" :class="`text-bg-${tipoBadge(c.tipo)}`">
                        {{ tipoIcon(c.tipo) }}
                      </span>
                      <span class="small">{{ catLabel(c.categoria) }}</span>
                    </div>
                    <span class="small fw-semibold" :class="c.tipo === 'egreso' ? 'text-danger' : 'text-success'">
                      {{ fmt(c.total) }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Últimos movimientos -->
        <div class="card border-0 shadow-sm">
          <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
            <strong>🕐 Últimos movimientos</strong>
            <button class="btn btn-sm btn-outline-secondary"
                    @click="vistaActiva = 'libro'; store.fetch()">
              Ver todos →
            </button>
          </div>
          <div class="card-body p-0">
            <div v-if="!store.dashboard.ultimos_movimientos?.length"
                 class="p-4 text-center text-muted">Sin movimientos todavía.</div>
            <div v-else class="table-responsive">
              <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                <tr>
                  <th>Fecha</th>
                  <th>Descripción</th>
                  <th>Categoría</th>
                  <th class="text-end">Monto</th>
                  <th></th>
                </tr>
                </thead>
                <tbody>
                <tr v-for="m in store.dashboard.ultimos_movimientos" :key="m.id">
                  <td class="small text-muted">{{ m.fecha }}</td>
                  <td>
                    <div class="d-flex align-items-center gap-2">
                        <span class="badge" :class="`text-bg-${tipoBadge(m.tipo)}`">
                          {{ tipoIcon(m.tipo) }}
                        </span>
                      <span class="small">{{ m.descripcion }}</span>
                    </div>
                  </td>
                  <td class="small text-muted">{{ catLabel(m.categoria) }}</td>
                  <td class="text-end fw-semibold small"
                      :class="m.tipo === 'egreso' ? 'text-danger' : 'text-success'">
                    {{ fmt(m.monto_ars) }}
                  </td>
                  <td class="text-end">
                    <button v-if="canEdit" class="btn btn-sm btn-outline-secondary"
                            @click="openEdit(m)">✏️</button>
                  </td>
                </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- ════════════════════ LIBRO DIARIO ════════════════════ -->
    <div v-else-if="vistaActiva === 'libro'">

      <!-- Filtros -->
      <div class="card border-0 bg-body-secondary mb-4">
        <div class="card-body py-3">
          <div class="row g-2 align-items-end">
            <div class="col-6 col-md-2">
              <label class="form-label small mb-1">Tipo</label>
              <select class="form-select form-select-sm" v-model="filtroTipo">
                <option value="">Todos</option>
                <option value="egreso">Egreso</option>
                <option value="ingreso">Ingreso</option>
                <option value="recupero_costo">Recupero costo</option>
                <option value="ajuste">Ajuste</option>
              </select>
            </div>
            <div class="col-6 col-md-3">
              <label class="form-label small mb-1">Categoría</label>
              <select class="form-select form-select-sm" v-model="filtroCategoria">
                <option value="">Todas</option>
                <option v-for="c in CATEGORIAS" :key="c.value" :value="c.value">
                  {{ c.label }}
                </option>
              </select>
            </div>
            <div class="col-6 col-md-2">
              <label class="form-label small mb-1">Sede</label>
              <select class="form-select form-select-sm" v-model="filtroSede">
                <option value="">Todas</option>
                <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
            </div>
            <div class="col-6 col-md-2">
              <label class="form-label small mb-1">Desde</label>
              <input type="date" class="form-control form-control-sm" v-model="filtroDesde" />
            </div>
            <div class="col-6 col-md-2">
              <label class="form-label small mb-1">Hasta</label>
              <input type="date" class="form-control form-control-sm" v-model="filtroHasta" />
            </div>
            <div class="col-6 col-md-1 d-flex gap-1">
              <button class="btn btn-primary btn-sm flex-fill" @click="aplicarFiltros">▶</button>
              <button class="btn btn-outline-secondary btn-sm" @click="limpiarFiltros" title="Limpiar">✕</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Totales del período -->
      <div class="row g-3 mb-4">
        <div class="col-4">
          <div class="card border-0 bg-success bg-opacity-10 h-100">
            <div class="card-body py-2 text-center">
              <div class="text-muted small">Ingresos</div>
              <div class="fw-bold text-success">{{ fmt(store.totales.ingresos) }}</div>
            </div>
          </div>
        </div>
        <div class="col-4">
          <div class="card border-0 bg-danger bg-opacity-10 h-100">
            <div class="card-body py-2 text-center">
              <div class="text-muted small">Egresos</div>
              <div class="fw-bold text-danger">{{ fmt(store.totales.egresos) }}</div>
            </div>
          </div>
        </div>
        <div class="col-4">
          <div class="card border-0 bg-body-secondary h-100">
            <div class="card-body py-2 text-center">
              <div class="text-muted small">Balance</div>
              <div class="fw-bold" :class="balanceColor(store.totales.balance)">
                {{ fmt(store.totales.balance) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tabla -->
      <div class="card border-0 shadow-sm">
        <div class="card-body p-0">
          <div v-if="store.loading" class="text-center py-5">
            <div class="spinner-border text-primary"></div>
          </div>
          <div v-else-if="store.error" class="alert alert-danger m-3">{{ store.error }}</div>
          <div v-else-if="!store.items.length" class="text-center py-5 text-muted">
            <div class="fs-1 mb-2">📒</div>
            <div>Sin movimientos para el período seleccionado</div>
          </div>
          <div v-else class="table-responsive">
            <table class="table table-hover align-middle mb-0">
              <thead class="table-light">
              <tr>
                <th>Fecha</th>
                <th>Descripción</th>
                <th>Categoría</th>
                <th>Sede / Lote</th>
                <th>Comprobante</th>
                <th class="text-end">Monto ARS</th>
                <th>Pagado</th>
                <th v-if="canEdit"></th>
              </tr>
              </thead>
              <tbody>
              <tr v-for="m in store.items" :key="m.id">
                <td class="small text-muted text-nowrap">{{ m.fecha }}</td>
                <td>
                  <div class="d-flex align-items-center gap-2">
                      <span class="badge flex-shrink-0" :class="`text-bg-${tipoBadge(m.tipo)}`">
                        {{ tipoIcon(m.tipo) }} {{ m.tipo_label }}
                      </span>
                    <span class="small">{{ m.descripcion }}</span>
                  </div>
                </td>
                <td class="small text-muted">{{ m.categoria_label }}</td>
                <td class="small text-muted">
                  <div v-if="m.sede">🏢 {{ m.sede.nombre }}</div>
                  <div v-if="m.lote">📦 {{ m.lote.codigo }}</div>
                  <span v-if="!m.sede && !m.lote">—</span>
                </td>
                <td class="small text-muted">
                  <div v-if="m.comprobante_numero">{{ m.comprobante_numero }}</div>
                  <div v-if="m.comprobante_tipo && m.comprobante_tipo !== 'sin_comprobante'"
                       class="badge text-bg-light text-dark">{{ m.comprobante_tipo }}</div>
                  <span v-if="!m.comprobante_numero && (!m.comprobante_tipo || m.comprobante_tipo === 'sin_comprobante')"
                        class="text-muted">—</span>
                </td>
                <td class="text-end fw-semibold"
                    :class="m.tipo === 'egreso' ? 'text-danger' : 'text-success'">
                  {{ fmt(m.monto_ars) }}
                </td>
                <td>
                    <span class="badge" :class="m.pagado ? 'text-bg-success' : 'text-bg-warning'">
                      {{ m.pagado ? "✓ Sí" : "Pendiente" }}
                    </span>
                </td>
                <td v-if="canEdit" class="text-end">
                  <div class="d-flex gap-1 justify-content-end">
                    <button class="btn btn-sm btn-outline-secondary" @click="openEdit(m)">✏️</button>
                    <button class="btn btn-sm btn-outline-danger"    @click="confirmDelete(m)">🗑️</button>
                  </div>
                </td>
              </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Paginación -->
      <nav v-if="store.pagination.total_pages > 1" class="mt-3">
        <ul class="pagination mb-0">
          <li class="page-item" :class="{ disabled: store.pagination.page <= 1 }">
            <button class="page-link" @click="goToPage(store.pagination.page - 1)">‹</button>
          </li>
          <li v-for="p in store.pagination.total_pages" :key="p"
              class="page-item" :class="{ active: p === store.pagination.page }">
            <button class="page-link" @click="goToPage(p)">{{ p }}</button>
          </li>
          <li class="page-item" :class="{ disabled: store.pagination.page >= store.pagination.total_pages }">
            <button class="page-link" @click="goToPage(store.pagination.page + 1)">›</button>
          </li>
        </ul>
      </nav>
    </div>

    <!-- ═══════════════ MODAL CREAR / EDITAR ═══════════════ -->
    <div class="modal fade" :class="{ show: showModal }" :style="{ display: showModal ? 'block':'none' }"
         tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingId ? "Editar movimiento" : "Nuevo movimiento" }}</h5>
            <button class="btn-close" @click="showModal = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="store.createError || store.updateError" class="alert alert-danger">
              {{ store.createError || store.updateError }}
            </div>
            <div class="row g-3">

              <!-- Tipo -->
              <div class="col-md-6">
                <label class="form-label">Tipo <span class="text-danger">*</span></label>
                <select class="form-select" v-model="form.tipo"
                        :class="{ 'is-invalid': formErrors.tipo }">
                  <option value="egreso">Egreso</option>
                  <option value="ingreso">Ingreso</option>
                  <option value="recupero_costo">Recupero de costo</option>
                  <option value="ajuste">Ajuste</option>
                </select>
                <div class="invalid-feedback">{{ formErrors.tipo }}</div>
              </div>

              <!-- Categoría -->
              <div class="col-md-6">
                <label class="form-label">Categoría <span class="text-danger">*</span></label>
                <select class="form-select" v-model="form.categoria"
                        :class="{ 'is-invalid': formErrors.categoria }">
                  <option value="">Seleccioná una categoría</option>
                  <option v-for="c in categoriasForm" :key="c.value" :value="c.value">
                    {{ c.label }}
                  </option>
                </select>
                <div class="invalid-feedback">{{ formErrors.categoria }}</div>
              </div>

              <!-- Descripción -->
              <div class="col-12">
                <label class="form-label">Descripción <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="form.descripcion"
                       :class="{ 'is-invalid': formErrors.descripcion }"
                       placeholder="Ej: Factura electricidad Sede Norte marzo" />
                <div class="invalid-feedback">{{ formErrors.descripcion }}</div>
              </div>

              <!-- Monto -->
              <div class="col-md-4">
                <label class="form-label">Monto ARS <span class="text-danger">*</span></label>
                <div class="input-group">
                  <span class="input-group-text">$</span>
                  <input type="number" min="0.01" step="0.01" class="form-control"
                         v-model.number="form.monto_ars"
                         :class="{ 'is-invalid': formErrors.monto_ars }" />
                </div>
                <div class="invalid-feedback d-block">{{ formErrors.monto_ars }}</div>
              </div>

              <!-- Fecha -->
              <div class="col-md-4">
                <label class="form-label">Fecha <span class="text-danger">*</span></label>
                <input type="date" class="form-control" v-model="form.fecha"
                       :class="{ 'is-invalid': formErrors.fecha }" />
                <div class="invalid-feedback">{{ formErrors.fecha }}</div>
              </div>

              <!-- Medio de pago -->
              <div class="col-md-4">
                <label class="form-label">Medio de pago</label>
                <select class="form-select" v-model="form.medio_pago">
                  <option value="efectivo">Efectivo</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="mercado_pago">Mercado Pago</option>
                  <option value="cheque">Cheque</option>
                </select>
              </div>

              <!-- Sede -->
              <div class="col-md-6">
                <label class="form-label">Sede (opcional)</label>
                <select class="form-select" v-model="form.sede_id">
                  <option :value="null">Sin sede específica</option>
                  <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>

              <!-- Comprobante tipo -->
              <div class="col-md-3">
                <label class="form-label">Tipo comprobante</label>
                <select class="form-select" v-model="form.comprobante_tipo">
                  <option value="sin_comprobante">Sin comprobante</option>
                  <option value="factura_a">Factura A</option>
                  <option value="factura_b">Factura B</option>
                  <option value="recibo">Recibo</option>
                  <option value="ticket">Ticket</option>
                </select>
              </div>

              <!-- Comprobante número -->
              <div class="col-md-3">
                <label class="form-label">N° comprobante</label>
                <input type="text" class="form-control" v-model.trim="form.comprobante_numero"
                       placeholder="0001-00001234" />
              </div>

              <!-- Proveedor -->
              <div class="col-md-6">
                <label class="form-label">Proveedor / Origen</label>
                <input type="text" class="form-control" v-model.trim="form.proveedor"
                       placeholder="Edenor, AYSA, Proveedor S.A.…" />
              </div>

              <!-- Pagado -->
              <div class="col-md-6 d-flex align-items-end">
                <div class="form-check mb-1">
                  <input class="form-check-input" type="checkbox" id="pagado" v-model="form.pagado" />
                  <label class="form-check-label" for="pagado">Pagado / Cobrado</label>
                </div>
              </div>

              <!-- Notas -->
              <div class="col-12">
                <label class="form-label">Notas</label>
                <textarea class="form-control" rows="2" v-model.trim="form.notas"
                          placeholder="Observaciones opcionales…"></textarea>
              </div>

            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="store.creating || store.updating"
                    @click="showModal = false">Cancelar</button>
            <button class="btn btn-primary" :disabled="store.creating || store.updating"
                    @click="submitForm">
              <span v-if="store.creating || store.updating"
                    class="spinner-border spinner-border-sm me-2"></span>
              {{ editingId ? "Guardar cambios" : "Crear movimiento" }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showModal }" v-if="showModal"
         @click="showModal = false"></div>

    <!-- ═══════════════ MODAL ELIMINAR ═══════════════ -->
    <div class="modal fade" :class="{ show: showDelete }" :style="{ display: showDelete ? 'block':'none' }"
         tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0 pb-0">
            <button class="btn-close ms-auto" @click="showDelete = false"></button>
          </div>
          <div class="modal-body text-center py-2">
            <div class="display-4 mb-3">⚠️</div>
            <h5>¿Eliminar este movimiento?</h5>
            <p class="text-muted small">
              {{ toDelete?.descripcion }} · {{ fmt(toDelete?.monto_ars) }}
            </p>
            <div v-if="store.removeError" class="alert alert-danger">{{ store.removeError }}</div>
          </div>
          <div class="modal-footer justify-content-center border-0">
            <button class="btn btn-outline-secondary px-4" @click="showDelete = false">Cancelar</button>
            <button class="btn btn-danger px-4" :disabled="store.removing" @click="doDelete">
              <span v-if="store.removing" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showDelete }" v-if="showDelete"
         @click="showDelete = false"></div>

  </div>
</template>

<style scoped>
.modal { background: rgba(0,0,0,.01); }
</style>
