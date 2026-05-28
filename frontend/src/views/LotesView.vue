<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from "vue";
import { useLotesStore } from "../stores/lotes";
import { useSalasStore } from "../stores/salas";
import { useAuthStore }  from "../stores/auth";
import Paginator from '../components/ui/Paginator.vue';
import EmptyState from '../components/ui/EmptyState.vue';
import { useConfirm } from '../composables/useConfirm.js';
import { exportLotesCSV, getLoteProximoCodigo } from '../lib/api.js';
import DsSpinner from '../design-system/components/Spinner.vue'

const store = useLotesStore();
const salas = useSalasStore();
const auth  = useAuthStore();
const { confirm } = useConfirm();

function lotesEscapeHandler(e) {
  if (e.key === 'Escape') { showCreate.value = false; showEdit.value = false; }
}
onMounted(() => {
  store.fetch();
  if (!salas.items.length) salas.fetch();
  document.addEventListener('keydown', lotesEscapeHandler, true);
});
onUnmounted(() => document.removeEventListener('keydown', lotesEscapeHandler, true));

const canEdit = computed(() => ["admin","cultivador"].includes(auth.role));
const canExport = computed(() => ["admin","auditor","supervisor","cultivador"].includes(auth.role));

// ---------- Estado meta ----------
const ESTADOS = ["planificacion","vegetativo","floracion","secado","cosechado","finalizado"];

const ESTADO_META = {
  planificacion: { label:"Planificación", dot:"#0284C7", bg:"#E0F2FE", text:"#0369a1", bar:"#0284C7", icon:"📋" },
  vegetativo:    { label:"Vegetativo",    dot:"#3F6452", bg:"#E8F0EB", text:"#2D4A3E", bar:"#5A8A72", icon:"🌱" },
  floracion:     { label:"Floración",     dot:"#D97706", bg:"#FEF3C7", text:"#92400e", bar:"#D97706", icon:"🌸" },
  secado:        { label:"Manicura",       dot:"#6B7280", bg:"#F3F4F6", text:"#374151", bar:"#9CA3AF", icon:"✂️" },
  cosechado:     { label:"Cosechado",     dot:"#5A8A72", bg:"#F4F8F5", text:"#1A3D2E", bar:"#3F6452", icon:"✂️" },
  finalizado:    { label:"Finalizado",    dot:"#1A3D2E", bg:"#E8F0EB", text:"#0F2A1E", bar:"#1A3D2E", icon:"✅" },
};

function em(e)           { return ESTADO_META[e] || { label: e||"—", dot:"#94a3b8", bg:"#f1f5f9", text:"#64748b", bar:"#94a3b8", icon:"•" }; }
function estadoLabel(e)  { return em(e).label; }
function growLabel(g)    { return { sustrato:"Sustrato", hidroponia:"Hidroponia", aeroponia:"Aeroponia" }[g] || g || "—"; }
function lightLabel(l)   { return { led:"LED", hps:"HPS", cmh:"CMH", natural:"Natural", mixta:"Mixta" }[l] || l || "—"; }
function salaName(id)    { return salas.items.find(s => String(s.id) === String(id))?.nombre || `Sala #${id}`; }
function diasDesdeInicio(d) { return d ? Math.floor((Date.now() - new Date(d)) / 86_400_000) : null; }

// ---------- Stats ----------
const stats = computed(() => {
  const all = store.items;
  return {
    total:      all.length,
    enCiclo:    all.filter(l => ["vegetativo","floracion"].includes(l.estado)).length,
    plantas:    all.reduce((a,l) => a + Number(l.plants_count||0), 0),
    cosechados: all.filter(l => l.estado === "cosechado").length,
  };
});

// ---------- Filtros ----------
const q            = ref("");
const filterEstado = ref("");
const filterSala   = ref("");
const filterGrow   = ref("");
const sortBy       = ref("fecha_desc");
const page         = ref(1);
const perPage      = ref(50);

const filtered = computed(() => {
  const query = q.value.trim().toLowerCase();
  return store.items.filter(l => {
    const matchText  = !query || (l.codigo||"").toLowerCase().includes(query) || (l.strain||"").toLowerCase().includes(query);
    const matchEstado = !filterEstado.value || l.estado === filterEstado.value;
    const matchSala   = !filterSala.value   || String(l.sala_id) === filterSala.value;
    const matchGrow   = !filterGrow.value   || l.grow_type === filterGrow.value;
    return matchText && matchEstado && matchSala && matchGrow;
  });
});

const sorted = computed(() => {
  const arr = [...filtered.value];
  arr.sort((a,b) => {
    const cA = (a.codigo||"").toLowerCase(), cB = (b.codigo||"").toLowerCase();
    const fA = new Date(a.start_date||a.created_at||0), fB = new Date(b.start_date||b.created_at||0);
    const pA = Number(a.plants_count??0), pB = Number(b.plants_count??0);
    switch (sortBy.value) {
      case "codigo_asc":   return cA > cB ? 1 : -1;
      case "fecha_asc":    return fA - fB;
      case "plantas_desc": return pB - pA;
      case "estado":       return ESTADOS.indexOf(a.estado) - ESTADOS.indexOf(b.estado);
      default:             return fB - fA;
    }
  });
  return arr;
});

const totalItems = computed(() => sorted.value.length);
const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / perPage.value)));
const paginated  = computed(() => sorted.value.slice((page.value-1)*perPage.value, page.value*perPage.value));
watch([sorted, perPage], () => { if (page.value > totalPages.value) page.value = 1; });

// ---------- Form ----------
function emptyForm() {
  return {
    estado: "vegetativo", plants_count: 0,
    start_date: new Date().toISOString().slice(0,10),
    strain: "", grow_type: "sustrato", light_type: "", notes: "",
    sala_id: salas.items[0]?.id ?? "",
    tamanio_maceta: null,
  };
}

const showCreate      = ref(false);
const createForm      = ref(emptyForm());
const createErrors    = ref({});
const proximoCodigo   = ref('…');

async function openCreate() {
  createForm.value   = emptyForm();
  createErrors.value = {};
  proximoCodigo.value = '…';
  showCreate.value   = true;
  try {
    const res = await getLoteProximoCodigo();
    proximoCodigo.value = res.data.codigo;
  } catch {
    proximoCodigo.value = 'Auto';
  }
}

const showEdit   = ref(false);
const editForm   = ref({ id: null, ...emptyForm() });
const editErrors = ref({});

function validateForm(form) {
  const e = {};
  if (!ESTADOS.includes(form.estado))  e.estado = "Estado inválido";
  const n = Number(form.plants_count);
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser 0–5000";
  if (!form.sala_id) e.sala_id = "Seleccioná una sala";
  return e;
}

async function submitCreate() {
  const e = validateForm(createForm.value);
  createErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    const { sala_id, ...rest } = createForm.value;
    await store.createInSala(sala_id, rest);
    await store.fetch();
    showCreate.value = false;
  } catch {}
}

function startEdit(l) {
  editForm.value = {
    id: l.id, codigo: l.codigo||"", estado: l.estado||"vegetativo",
    plants_count: l.plants_count??0,
    start_date: l.start_date ? l.start_date.slice(0,10) : new Date().toISOString().slice(0,10),
    strain: l.strain||"", grow_type: l.grow_type||"sustrato", light_type: l.light_type||"",
    notes: l.notes||"", sala_id: l.sala_id||"",
    tamanio_maceta: l.tamanio_maceta ?? null,
  };
  editErrors.value = {};
  showEdit.value = true;
}

async function submitEdit() {
  const e = {};
  if (!ESTADOS.includes(editForm.value.estado)) e.estado = "Estado inválido";
  const n = Number(editForm.value.plants_count);
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser 0–5000";
  if (!editForm.value.sala_id) e.sala_id = "Seleccioná una sala";
  editErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    const { id, codigo, sala_id, ...payload } = editForm.value;
    await store.update(id, payload, sala_id);
    showEdit.value = false;
  } catch {}
}

async function confirmDelete(l) {
  const ok = await confirm({
    title: `¿Eliminar "${l.codigo}"?`,
    message: 'Esta acción no se puede deshacer.',
    confirmText: 'Eliminar',
    variant: 'danger',
  });
  if (!ok) return;
  try { await store.remove(l.id, l.sala_id); } catch {}
}

const exporting = ref(false);
async function exportarCSV() {
  if (exporting.value) return;
  exporting.value = true;
  try {
    const params = {};
    if (filterEstado.value) params.estado = filterEstado.value;
    const { data } = await exportLotesCSV(params);
    const url  = URL.createObjectURL(new Blob([data], { type: 'text/csv;charset=utf-8;' }));
    const link = document.createElement('a');
    link.href  = url;
    link.setAttribute('download', `lotes_${new Date().toISOString().slice(0,10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  } catch {
    alert('Error al exportar');
  } finally {
    exporting.value = false;
  }
}
</script>

<template>
  <div class="lv">

    <!-- Header -->
    <div class="lv__header">
      <div>
        <h1 class="lv__title">Lotes de cultivo</h1>
        <p class="lv__sub">Trazabilidad de ciclos productivos</p>
      </div>
      <div class="lv__header-actions">
        <button v-if="canExport" class="lv__btn-export" :disabled="exporting" @click="exportarCSV">
          <i class="bi bi-download"></i>
          {{ exporting ? 'Exportando…' : 'CSV' }}
        </button>
        <button v-if="canEdit" class="lv__btn-primary" @click="openCreate">
          <i class="bi bi-plus-lg"></i> Nuevo lote
        </button>
      </div>
    </div>

    <!-- KPIs -->
    <div class="lv__kpis">
      <button class="lv__kpi" :class="{ 'lv__kpi--active': filterEstado === '' }" @click="filterEstado = ''">
        <div class="lv__kpi-val">{{ stats.total }}</div>
        <div class="lv__kpi-lbl">Total</div>
      </button>
      <button class="lv__kpi lv__kpi--green" :class="{ 'lv__kpi--active': filterEstado === 'vegetativo' || filterEstado === 'floracion' }" @click="filterEstado = filterEstado === 'vegetativo' ? '' : 'vegetativo'">
        <div class="lv__kpi-val">{{ stats.enCiclo }}</div>
        <div class="lv__kpi-lbl">En ciclo activo</div>
      </button>
      <button class="lv__kpi lv__kpi--neutral" :class="{ 'lv__kpi--active-neutral': filterEstado === '' }" @click="filterEstado = ''">
        <div class="lv__kpi-val">{{ stats.plantas }}</div>
        <div class="lv__kpi-lbl">Plantas totales</div>
      </button>
      <button class="lv__kpi lv__kpi--amber" :class="{ 'lv__kpi--active': filterEstado === 'cosechado' }" @click="filterEstado = filterEstado === 'cosechado' ? '' : 'cosechado'">
        <div class="lv__kpi-val">{{ stats.cosechados }}</div>
        <div class="lv__kpi-lbl">Cosechados</div>
      </button>
    </div>

    <!-- Toolbar -->
    <div class="lv__toolbar">
      <div class="lv__search-wrap">
        <i class="bi bi-search lv__search-icon"></i>
        <input
          v-model.trim="q"
          type="search"
          class="lv__search"
          placeholder="Código, variedad…"
        />
        <span v-if="q" class="lv__search-count">{{ filtered.length }}</span>
      </div>
      <select class="lv__select" v-model="filterEstado">
        <option value="">Todos los estados</option>
        <option v-for="e in ESTADOS" :key="e" :value="e">{{ estadoLabel(e) }}</option>
      </select>
      <select class="lv__select" v-model="filterSala">
        <option value="">Todas las salas</option>
        <option v-for="s in salas.items" :key="s.id" :value="String(s.id)">{{ s.nombre }}</option>
      </select>
      <select class="lv__select lv__select--sm" v-model="filterGrow">
        <option value="">Todos los sistemas</option>
        <option value="sustrato">Sustrato</option>
        <option value="hidroponia">Hidroponia</option>
        <option value="aeroponia">Aeroponia</option>
      </select>
      <select class="lv__select lv__select--sm" v-model="sortBy">
        <option value="fecha_desc">Más recientes</option>
        <option value="fecha_asc">Más antiguos</option>
        <option value="estado">Por estado</option>
        <option value="codigo_asc">Código A→Z</option>
        <option value="plantas_desc">Más plantas</option>
      </select>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="lv__loading">
      <DsSpinner />
    </div>
    <div v-else-if="store.error" class="lv__alert">{{ store.error }}</div>
    <EmptyState v-else-if="!store.items.length" icon="🌱" title="No hay lotes todavía" message="Creá el primer lote para comenzar la trazabilidad" />
    <EmptyState v-else-if="!paginated.length" icon="🔍" title="Sin resultados" message="Probá ajustando los filtros" />

    <!-- Tabla -->
    <div v-else class="lv__table-wrap">
      <table class="lv-table">
        <thead>
          <tr>
            <th>Estado</th>
            <th class="lv-th--sort" @click="sortBy = sortBy === 'codigo_asc' ? 'fecha_desc' : 'codigo_asc'">
              Código <span class="lv-sort-icon">{{ sortBy === 'codigo_asc' ? '↑' : '↕' }}</span>
            </th>
            <th>Genética / Strain</th>
            <th>Sala</th>
            <th class="lv-th--sort" @click="sortBy = sortBy === 'plantas_desc' ? 'fecha_desc' : 'plantas_desc'">
              Plantas <span class="lv-sort-icon">{{ sortBy === 'plantas_desc' ? '↓' : '↕' }}</span>
            </th>
            <th>Maceta</th>
            <th class="lv-th--sort" @click="sortBy = sortBy === 'fecha_asc' ? 'fecha_desc' : 'fecha_asc'">
              Días <span class="lv-sort-icon">{{ sortBy.startsWith('fecha') ? (sortBy === 'fecha_asc' ? '↑' : '↓') : '↕' }}</span>
            </th>
            <th class="lv-th--hide-tablet">Progreso</th>
            <th v-if="canEdit"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="l in paginated"
            :key="l.id"
            class="lv-table__row"
            @click="$router.push({ name: 'lote-detail', params: { id: l.id } })"
          >
            <td data-label="Estado">
              <span class="lv-badge" :style="{ background: em(l.estado).bg, color: em(l.estado).text }">
                {{ em(l.estado).icon }} {{ estadoLabel(l.estado) }}
              </span>
            </td>
            <td data-label="Código">
              <span class="lv-codigo">{{ l.codigo }}</span>
            </td>
            <td data-label="Genética">
              <span v-if="l.genetica?.nombre" class="lv-genetica">{{ l.genetica.nombre }}</span>
              <span v-else-if="l.strain" class="lv-strain">{{ l.strain }}</span>
              <span v-else class="lv-empty">—</span>
            </td>
            <td data-label="Sala">
              <span class="lv-sala">{{ salaName(l.sala_id) }}</span>
            </td>
            <td data-label="Plantas">
              <span class="lv-num">{{ l.plants_count ?? 0 }}</span>
            </td>
            <td data-label="Maceta">
              <span v-if="l.tamanio_maceta" class="lv-num">{{ l.tamanio_maceta }}L</span>
              <span v-else class="lv-empty">—</span>
            </td>
            <td data-label="Días">
              <span v-if="diasDesdeInicio(l.start_date) !== null" class="lv-num">{{ diasDesdeInicio(l.start_date) }}d</span>
              <span v-else class="lv-empty">—</span>
            </td>
            <td data-label="Progreso" class="lv-th--hide-tablet">
              <template v-if="l.progreso_ciclo != null && ['vegetativo','floracion'].includes(l.estado)">
                <div class="lv-prog-wrap">
                  <div class="lv-prog-track">
                    <div class="lv-prog-bar" :style="{ width: l.progreso_ciclo + '%' }"></div>
                  </div>
                  <span class="lv-prog-pct">{{ l.progreso_ciclo }}%</span>
                </div>
              </template>
              <span v-else class="lv-empty">—</span>
            </td>
            <td v-if="canEdit" @click.stop>
              <div class="lv-actions">
                <button class="lv-action-btn" title="Editar" @click="startEdit(l)">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="lv-action-btn lv-action-btn--danger" title="Eliminar" @click="confirmDelete(l)">
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="lv__table-footer">
        <div class="lv__pagination" v-if="totalPages > 1">
          <button class="lv__page-btn" :disabled="page <= 1" @click="page--">«</button>
          <span class="lv__page-info">{{ page }} / {{ totalPages }}</span>
          <button class="lv__page-btn" :disabled="page >= totalPages" @click="page++">»</button>
        </div>
        <div class="lv__count">{{ filtered.length }} lotes</div>
      </div>
    </div>

    <!-- MODAL Crear -->
    <Teleport to="body">
      <div v-if="showCreate" class="lm-overlay" @click.self="showCreate = false">
        <div class="lm-modal">
          <div class="lm-modal__header">
            <div>
              <h2 class="lm-modal__title">Nuevo lote</h2>
              <p class="lm-modal__sub">Registrá un nuevo ciclo productivo</p>
            </div>
            <button class="lm-modal__close" @click="showCreate = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="lm-modal__body">
            <div v-if="store.createError" class="lm-alert">{{ store.createError }}</div>
            <div class="lm-grid">
              <div class="lm-field">
                <label class="lm-label">Código</label>
                <input class="lm-input" :value="proximoCodigo" disabled
                       style="opacity:.7;cursor:not-allowed;background:#f8fafc;font-family:monospace;font-size:.85rem" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Sala <span class="lm-req">*</span></label>
                <select class="lm-input" :class="{ 'lm-input--err': createErrors.sala_id }" v-model="createForm.sala_id">
                  <option value="" disabled>Seleccioná una sala…</option>
                  <option v-for="s in salas.items" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
                <span v-if="createErrors.sala_id" class="lm-err">{{ createErrors.sala_id }}</span>
              </div>
              <div class="lm-field">
                <label class="lm-label">Estado</label>
                <select class="lm-input" v-model="createForm.estado">
                  <option v-for="e in ESTADOS" :key="e" :value="e">{{ estadoLabel(e) }}</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" class="lm-input" :class="{ 'lm-input--err': createErrors.plants_count }"
                       v-model.number="createForm.plants_count" />
                <span v-if="createErrors.plants_count" class="lm-err">{{ createErrors.plants_count }}</span>
              </div>
              <div class="lm-field">
                <label class="lm-label">Fecha de inicio</label>
                <input type="date" class="lm-input" v-model="createForm.start_date" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Variedad / Strain</label>
                <input class="lm-input" v-model.trim="createForm.strain" placeholder="Ej: OG Kush" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Sistema de cultivo</label>
                <select class="lm-input" v-model="createForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Tipo de luz</label>
                <select class="lm-input" v-model="createForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="lm-field lm-field--full">
                <label class="lm-label">Notas</label>
                <textarea class="lm-input lm-textarea" rows="2" v-model.trim="createForm.notes"></textarea>
              </div>
            </div>
          </div>
          <div class="lm-modal__footer">
            <button class="lm-btn-ghost" @click="showCreate = false">Cancelar</button>
            <button class="lm-btn-primary" :disabled="store.creating" @click="submitCreate">
              <DsSpinner v-if="store.creating" :size="14" />
              Crear lote
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- MODAL Editar -->
    <Teleport to="body">
      <div v-if="showEdit" class="lm-overlay" @click.self="showEdit = false">
        <div class="lm-modal">
          <div class="lm-modal__header">
            <div>
              <h2 class="lm-modal__title">Editar lote</h2>
              <p class="lm-modal__sub lm-modal__sub--code">{{ editForm.codigo }}</p>
            </div>
            <button class="lm-modal__close" @click="showEdit = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="lm-modal__body">
            <div v-if="store.updateError" class="lm-alert">{{ store.updateError }}</div>
            <div class="lm-grid">
              <div class="lm-field">
                <label class="lm-label">Código</label>
                <input class="lm-input" :value="editForm.codigo" disabled style="opacity:.6;cursor:not-allowed;background:#f8fafc;font-family:monospace" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Sala</label>
                <select class="lm-input" v-model="editForm.sala_id">
                  <option v-for="s in salas.items" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Estado</label>
                <select class="lm-input" v-model="editForm.estado">
                  <option v-for="e in ESTADOS" :key="e" :value="e">{{ estadoLabel(e) }}</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" class="lm-input" :class="{ 'lm-input--err': editErrors.plants_count }"
                       v-model.number="editForm.plants_count" />
                <span v-if="editErrors.plants_count" class="lm-err">{{ editErrors.plants_count }}</span>
              </div>
              <div class="lm-field">
                <label class="lm-label">Fecha de inicio</label>
                <input type="date" class="lm-input" v-model="editForm.start_date" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Variedad / Strain</label>
                <input class="lm-input" v-model.trim="editForm.strain" />
              </div>
              <div class="lm-field">
                <label class="lm-label">Sistema de cultivo</label>
                <select class="lm-input" v-model="editForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Tipo de luz</label>
                <select class="lm-input" v-model="editForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="lm-field">
                <label class="lm-label">Maceta <span class="lm-unit">litros</span></label>
                <input type="number" step="0.5" min="0" class="lm-input" v-model.number="editForm.tamanio_maceta" placeholder="Ej: 11" />
              </div>
              <div class="lm-field lm-field--full">
                <label class="lm-label">Notas</label>
                <textarea class="lm-input lm-textarea" rows="2" v-model.trim="editForm.notes"></textarea>
              </div>
            </div>
          </div>
          <div class="lm-modal__footer">
            <button class="lm-btn-ghost" @click="showEdit = false">Cancelar</button>
            <button class="lm-btn-primary" :disabled="store.updating" @click="submitEdit">
              <DsSpinner v-if="store.updating" :size="14" />
              Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
/* ── Layout ──────────────────────────────────────────── */
.lv { padding: 2rem 1.5rem; max-width: 1100px; margin: 0 auto; }
@media (max-width: 768px) { .lv { padding: 1.25rem 1rem; overflow-x: hidden; } }

/* ── Header ──────────────────────────────────────────── */
.lv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.lv__title  { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.lv__sub    { font-size: .83rem; color: #94a3b8; margin: 0; }
.lv__header-actions { display: flex; gap: .5rem; align-items: center; }

.lv__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.25rem; border-radius: 9px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s, transform .1s; white-space: nowrap;
}
.lv__btn-primary:hover { background: #144a18; transform: translateY(-1px); }

.lv__btn-export {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .6rem .9rem; background: transparent; color: #475569;
  border: 1.5px solid #e2e8f0; border-radius: 9px;
  font-size: .84rem; font-weight: 600; cursor: pointer;
  transition: all .15s; white-space: nowrap;
}
.lv__btn-export:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.lv__btn-export:disabled { opacity: .5; cursor: default; }

/* ── KPIs ─────────────────────────────────────────────── */
.lv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.5rem; }
@media (max-width: 700px) { .lv__kpis { grid-template-columns: repeat(2, 1fr); } }

.lv__kpi {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px;
  padding: 1rem; text-align: left; cursor: pointer; transition: all .15s;
}
.lv__kpi:hover { border-color: #94a3b8; }
.lv__kpi--active { border-color: #1b5e20 !important; box-shadow: 0 0 0 1px #1b5e20; }
.lv__kpi--green .lv__kpi-val { color: #1b5e20; }
.lv__kpi--green.lv__kpi--active { border-color: #1b5e20 !important; box-shadow: 0 0 0 1px #1b5e20; }
.lv__kpi--amber .lv__kpi-val { color: #b45309; }
.lv__kpi--amber.lv__kpi--active { border-color: #b45309 !important; box-shadow: 0 0 0 1px #b45309; }
.lv__kpi--neutral .lv__kpi-val { color: #64748b; }

.lv__kpi-val { font-size: 1.8rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; margin-bottom: .2rem; }
.lv__kpi-lbl { font-size: .72rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; }

/* ── Toolbar ──────────────────────────────────────────── */
.lv__toolbar {
  display: flex; gap: .5rem; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap;
}
.lv__search-wrap { flex: 1; min-width: 180px; position: relative; display: flex; align-items: center; }
.lv__search-icon { position: absolute; left: .875rem; color: #94a3b8; font-size: .875rem; pointer-events: none; }
.lv__search {
  width: 100%; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: .65rem .875rem .65rem 2.4rem; font-size: .9rem; color: #0f172a;
  transition: border .15s, box-shadow .15s; box-sizing: border-box;
}
.lv__search:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.lv__search-count { position: absolute; right: .875rem; font-size: .72rem; font-weight: 600; color: #94a3b8; }

.lv__select {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px;
  padding: .62rem .85rem; font-size: .875rem; color: #0f172a; cursor: pointer;
  transition: border .15s; min-width: 140px;
}
.lv__select--sm { min-width: 120px; }
.lv__select:focus { outline: none; border-color: #1b5e20; }

@media (max-width: 640px) {
  .lv__toolbar { gap: .4rem; }
  .lv__search-wrap { flex: 1 1 100%; }
  .lv__select { flex: 1 1 calc(50% - .2rem); min-width: 0; font-size: .82rem; padding: .58rem .7rem; }
  .lv__select--sm { flex: 1 1 calc(50% - .2rem); }
}

/* ── Loading / Error ─────────────────────────────────── */
.lv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.lv__alert   { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .875rem 1rem; border-radius: 10px; font-size: .875rem; margin-bottom: 1rem; }

/* ── Tabla ───────────────────────────────────────────── */
.lv__table-wrap { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden; margin-bottom: 0; }
.lv-table { width: 100%; border-collapse: collapse; font-size: .875rem; }
.lv-table thead th { padding: 10px 12px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; white-space: nowrap; background: #fafafa; }
.lv-th--sort { cursor: pointer; user-select: none; }
.lv-th--sort:hover { color: #1b5e20; }
.lv-sort-icon { font-size: .75rem; color: #cbd5e1; margin-left: .2rem; }
.lv-table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; cursor: pointer; }
.lv-table tbody tr:last-child { border-bottom: none; }
.lv-table tbody tr:hover { background: #f8fafc; }
.lv-table td { padding: 10px 12px; vertical-align: middle; }

.lv-badge { display: inline-flex; align-items: center; gap: .25rem; padding: 3px 8px; border-radius: 5px; font-size: .75rem; font-weight: 700; white-space: nowrap; }
.lv-codigo { font-weight: 700; color: #0f172a; font-family: monospace; font-size: .85rem; }
.lv-genetica { font-weight: 600; color: #3F6452; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lv-strain { font-style: italic; color: #64748b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lv-sala { color: #64748b; font-size: .82rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.lv-num { font-weight: 600; color: #374151; }
.lv-empty { color: #cbd5e1; }

.lv-prog-wrap { display: flex; align-items: center; gap: .5rem; }
.lv-prog-track { flex: 1; min-width: 60px; height: 5px; background: #e8f0eb; border-radius: 99px; overflow: hidden; }
.lv-prog-bar { height: 100%; background: #3F6452; border-radius: 99px; transition: width .3s; }
.lv-prog-pct { font-size: .75rem; font-weight: 700; color: #1b5e20; white-space: nowrap; }

.lv-actions { display: flex; align-items: center; gap: .25rem; opacity: 0; transition: opacity .15s; }
.lv-table tbody tr:hover .lv-actions { opacity: 1; }
.lv-action-btn { background: none; border: none; cursor: pointer; padding: 5px 7px; border-radius: 6px; color: #6b7280; font-size: .875rem; transition: all .15s; }
.lv-action-btn:hover { background: #f1f5f9; color: #0f172a; }
.lv-action-btn--danger:hover { background: #fef2f2; color: #dc2626; }

.lv__table-footer { display: flex; align-items: center; justify-content: space-between; padding: .6rem 1rem; border-top: 1px solid #f1f5f9; }
.lv__pagination { display: flex; align-items: center; gap: .5rem; }
.lv__page-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 7px; padding: .3rem .65rem; font-size: .82rem; color: #374151; cursor: pointer; transition: all .15s; }
.lv__page-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.lv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.lv__page-info { font-size: .8rem; color: #64748b; font-weight: 600; }
.lv__count { font-size: .75rem; color: #94a3b8; }

/* ── Tablet: ocultar columna Progreso ────────────────── */
@media (max-width: 900px) {
  .lv-th--hide-tablet { display: none; }
}

/* ── Mobile: tabla → cards ───────────────────────────── */
@media (max-width: 640px) {
  .lv__table-wrap { background: transparent; border: none; border-radius: 0; overflow: visible; }
  .lv-table { display: block; }
  .lv-table thead { display: none; }
  .lv-table tbody { display: flex; flex-direction: column; gap: .6rem; }

  .lv-table tbody tr {
    display: block;
    background: #fff;
    border: 1px solid #e5e7eb !important;
    border-bottom: 1px solid #e5e7eb !important;
    border-radius: 12px;
    padding: .875rem 1rem .875rem 1rem;
    position: relative;
    transition: box-shadow .15s;
  }
  .lv-table tbody tr:hover { background: #fff; box-shadow: 0 2px 12px rgba(0,0,0,.07); }

  /* Todas las celdas: flex con label */
  .lv-table td {
    display: flex;
    align-items: center;
    gap: .4rem;
    padding: .18rem 0;
    border: none;
    font-size: .84rem;
    min-width: 0;
    width: 100%;
  }
  .lv-table td::before {
    content: attr(data-label);
    font-size: .65rem;
    font-weight: 700;
    color: #94a3b8;
    text-transform: uppercase;
    letter-spacing: .04em;
    min-width: 68px;
    flex-shrink: 0;
  }

  /* Estado: sin label, badge prominente */
  .lv-table td[data-label="Estado"] {
    padding-bottom: .45rem;
    margin-bottom: .1rem;
    border-bottom: 1px solid #f1f5f9;
  }
  .lv-table td[data-label="Estado"]::before { content: none; }

  /* Código: sin label, grande */
  .lv-table td[data-label="Código"]::before { content: none; }
  .lv-codigo { font-size: .95rem; }

  /* Acciones: posición absoluta top-right */
  .lv-table td:last-child {
    position: absolute;
    top: .75rem;
    right: .75rem;
    padding: 0;
    display: flex;
    align-items: center;
  }
  .lv-table td:last-child::before { content: none; }
  .lv-actions { opacity: 1; }

  /* Padding-right para que el contenido no choque con acciones */
  .lv-table td[data-label="Estado"],
  .lv-table td[data-label="Código"] { padding-right: 5rem; }

  .lv__table-footer { padding: .6rem .25rem; }
}

/* ── Modal ───────────────────────────────────────────── */
.lm-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1060; padding: 1rem; backdrop-filter: blur(3px);
}
.lm-modal {
  background: #fff; border-radius: 18px; width: 100%; max-width: 640px;
  max-height: 92vh; overflow-y: auto; display: flex; flex-direction: column;
  box-shadow: 0 24px 64px rgba(0,0,0,.15);
}
.lm-modal__header {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem;
  padding: 1.5rem 1.5rem 1.1rem; border-bottom: 1px solid #f1f5f9;
  position: sticky; top: 0; background: #fff; z-index: 1;
}
.lm-modal__title { font-size: 1.2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.02em; }
.lm-modal__sub   { font-size: .8rem; color: #64748b; margin: 0; }
.lm-modal__sub--code { font-family: monospace; color: #3F6452; font-weight: 700; }
.lm-modal__close {
  background: #f1f5f9; border: none; width: 32px; height: 32px;
  border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0; transition: all .15s;
}
.lm-modal__close:hover { background: #e2e8f0; color: #0f172a; }
.lm-modal__body   { padding: 1.4rem 1.5rem; flex: 1; }
.lm-modal__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem; border-top: 1px solid #f1f5f9;
  position: sticky; bottom: 0; background: #fff;
}

.lm-alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 9px; font-size: .85rem; margin-bottom: 1.25rem; }

.lm-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 520px) { .lm-grid { grid-template-columns: 1fr; } }

.lm-field        { display: flex; flex-direction: column; gap: .35rem; }
.lm-field--full  { grid-column: 1 / -1; }
.lm-label        { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.lm-req          { color: #dc2626; }
.lm-unit         { font-size: .68rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; margin-left: .2rem; }
.lm-input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .9rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s, box-shadow .15s;
}
.lm-input:focus     { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }
.lm-input--err      { border-color: #dc2626; }
.lm-textarea        { resize: vertical; min-height: 68px; }
.lm-err             { font-size: .72rem; color: #dc2626; font-weight: 600; }

.lm-btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.4rem; border-radius: 9px; font-size: .875rem; font-weight: 700;
  cursor: pointer; transition: background .15s;
}
.lm-btn-primary:hover:not(:disabled) { background: #144a18; }
.lm-btn-primary:disabled { opacity: .6; cursor: not-allowed; }

.lm-btn-ghost {
  background: transparent; color: #64748b; border: 1.5px solid #e2e8f0;
  padding: .65rem 1.2rem; border-radius: 9px; font-size: .875rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.lm-btn-ghost:hover { background: #f8fafc; color: #0f172a; }

</style>
