<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from "vue";
import { useLotesStore } from "../stores/lotes";
import { useSalasStore } from "../stores/salas";
import { useAuthStore }  from "../stores/auth";
import Paginator from '../components/ui/Paginator.vue';
import EmptyState from '../components/ui/EmptyState.vue';
import { useConfirm } from '../composables/useConfirm.js';
import { exportLotesCSV } from '../lib/api.js';

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
const perPage      = ref(9);

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
    codigo: "", estado: "vegetativo", plants_count: 0,
    start_date: new Date().toISOString().slice(0,10),
    strain: "", grow_type: "sustrato", light_type: "", notes: "",
    sala_id: salas.items[0]?.id ?? "",
  };
}

const showCreate   = ref(false);
const createForm   = ref(emptyForm());
const createErrors = ref({});
function openCreate() { createForm.value = emptyForm(); createErrors.value = {}; showCreate.value = true; }

const showEdit   = ref(false);
const editForm   = ref({ id: null, ...emptyForm() });
const editErrors = ref({});

function validateForm(form) {
  const e = {};
  if (!form.codigo?.trim())            e.codigo = "El código es obligatorio";
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
  };
  editErrors.value = {};
  showEdit.value = true;
}

async function submitEdit() {
  const e = validateForm(editForm.value);
  editErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    const { id, sala_id, ...payload } = editForm.value;
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
      <div class="lv__ring"></div> Cargando lotes…
    </div>
    <div v-else-if="store.error" class="lv__alert">{{ store.error }}</div>
    <EmptyState v-else-if="!store.items.length" icon="🌱" title="No hay lotes todavía" message="Creá el primer lote para comenzar la trazabilidad" />
    <EmptyState v-else-if="!paginated.length" icon="🔍" title="Sin resultados" message="Probá ajustando los filtros" />

    <!-- Cards -->
    <div v-else class="lv__grid">
      <RouterLink
        v-for="l in paginated"
        :key="l.id"
        class="lv__card"
        :to="{ name: 'lote-detail', params: { id: l.id } }"
      >
        <!-- barra de estado -->
        <div class="lv__card-bar" :style="{ background: em(l.estado).bar }"></div>

        <div class="lv__card-body">

          <!-- Header card -->
          <div class="lv__card-head">
            <span class="lv__card-icon">{{ em(l.estado).icon }}</span>
            <span class="lv__card-codigo">{{ l.codigo }}</span>
            <span class="lv__badge" :style="{ background: em(l.estado).bg, color: em(l.estado).text }">
              {{ estadoLabel(l.estado) }}
            </span>
          </div>

          <!-- Strain + sala -->
          <div class="lv__card-meta">
            <span v-if="l.strain" class="lv__meta-item">🌿 <em>{{ l.strain }}</em></span>
            <span class="lv__meta-item lv__meta-item--sala">📍 {{ salaName(l.sala_id) }}</span>
          </div>

          <!-- Métricas -->
          <div class="lv__metrics">
            <div class="lv__metric">
              <span class="lv__metric-val">{{ l.plants_count ?? 0 }}</span>
              <span class="lv__metric-lbl">plantas</span>
            </div>
            <div v-if="diasDesdeInicio(l.start_date) !== null" class="lv__metric">
              <span class="lv__metric-val">{{ diasDesdeInicio(l.start_date) }}</span>
              <span class="lv__metric-lbl">días</span>
            </div>
            <div v-if="l.grow_type" class="lv__metric">
              <span class="lv__metric-val lv__metric-val--sm">{{ growLabel(l.grow_type) }}</span>
              <span class="lv__metric-lbl">sistema</span>
            </div>
            <div v-if="l.light_type" class="lv__metric">
              <span class="lv__metric-val lv__metric-val--sm">{{ lightLabel(l.light_type) }}</span>
              <span class="lv__metric-lbl">luz</span>
            </div>
          </div>

          <!-- Progreso ciclo -->
          <div v-if="l.progreso_ciclo != null && ['vegetativo','floracion'].includes(l.estado)" class="lv__progress-wrap">
            <div class="lv__progress-row">
              <span class="lv__progress-lbl">Progreso ciclo</span>
              <span class="lv__progress-pct">{{ l.progreso_ciclo }}%</span>
            </div>
            <div class="lv__progress-track">
              <div class="lv__progress-bar" :style="{ width: l.progreso_ciclo + '%' }"></div>
            </div>
          </div>

          <!-- Notas -->
          <p v-if="l.notes" class="lv__card-notes">{{ l.notes }}</p>

          <!-- Acciones -->
          <div v-if="canEdit" class="lv__card-actions" @click.prevent>
            <button class="lv__action-btn" title="Editar" @click.prevent="startEdit(l)">
              <i class="bi bi-pencil"></i>
            </button>
            <button class="lv__action-btn lv__action-btn--danger" title="Eliminar" @click.prevent="confirmDelete(l)">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </div>
      </RouterLink>
    </div>

    <Paginator
      v-model:page="page"
      v-model:perPage="perPage"
      :total="totalItems"
      :pageSizes="[9, 18, 36]"
    />

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
                <label class="lm-label">Código <span class="lm-req">*</span></label>
                <input class="lm-input" :class="{ 'lm-input--err': createErrors.codigo }"
                       v-model.trim="createForm.codigo" placeholder="Ej: LOT-2026-001" />
                <span v-if="createErrors.codigo" class="lm-err">{{ createErrors.codigo }}</span>
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
              <span v-if="store.creating" class="lm-spinner"></span>
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
                <label class="lm-label">Código <span class="lm-req">*</span></label>
                <input class="lm-input" :class="{ 'lm-input--err': editErrors.codigo }" v-model.trim="editForm.codigo" />
                <span v-if="editErrors.codigo" class="lm-err">{{ editErrors.codigo }}</span>
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
              <div class="lm-field lm-field--full">
                <label class="lm-label">Notas</label>
                <textarea class="lm-input lm-textarea" rows="2" v-model.trim="editForm.notes"></textarea>
              </div>
            </div>
          </div>
          <div class="lm-modal__footer">
            <button class="lm-btn-ghost" @click="showEdit = false">Cancelar</button>
            <button class="lm-btn-primary" :disabled="store.updating" @click="submitEdit">
              <span v-if="store.updating" class="lm-spinner"></span>
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
@media (max-width: 768px) { .lv { padding: 1.25rem 1rem; } }

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

/* ── Loading / Error ─────────────────────────────────── */
.lv__loading { display: flex; align-items: center; gap: .75rem; padding: 4rem; color: #94a3b8; font-size: .875rem; justify-content: center; }
.lv__ring    { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: lv-spin .7s linear infinite; flex-shrink: 0; }
@keyframes lv-spin { to { transform: rotate(360deg); } }
.lv__alert   { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .875rem 1rem; border-radius: 10px; font-size: .875rem; margin-bottom: 1rem; }

/* ── Grid de cards ───────────────────────────────────── */
.lv__grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  margin-bottom: 1.5rem;
}
@media (max-width: 960px)  { .lv__grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 600px)  { .lv__grid { grid-template-columns: 1fr; } }

/* ── Card ────────────────────────────────────────────── */
.lv__card {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 14px;
  overflow: hidden; text-decoration: none; color: inherit;
  display: flex; flex-direction: column;
  transition: border-color .15s, box-shadow .15s, transform .15s;
}
.lv__card:hover { border-color: #a8c9b5; box-shadow: 0 4px 16px rgba(27,94,32,.1); transform: translateY(-2px); }

.lv__card-bar { height: 4px; width: 100%; flex-shrink: 0; }

.lv__card-body { padding: 1rem; display: flex; flex-direction: column; gap: .6rem; flex: 1; }

.lv__card-head { display: flex; align-items: center; gap: .5rem; }
.lv__card-icon { font-size: 1rem; flex-shrink: 0; }
.lv__card-codigo {
  font-size: .9rem; font-weight: 800; color: #0f172a;
  flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  letter-spacing: -.01em;
}

.lv__badge {
  flex-shrink: 0; font-size: .68rem; font-weight: 800;
  padding: .2em .6em; border-radius: 6px; letter-spacing: .02em;
}

.lv__card-meta { display: flex; gap: .5rem; flex-wrap: wrap; }
.lv__meta-item { font-size: .78rem; color: #64748b; }
.lv__meta-item em { font-style: italic; color: #3F6452; font-weight: 600; }
.lv__meta-item--sala { color: #94a3b8; }

.lv__metrics { display: flex; gap: 1rem; }
.lv__metric  { display: flex; flex-direction: column; align-items: center; }
.lv__metric-val    { font-size: 1.25rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.02em; }
.lv__metric-val--sm { font-size: .95rem; }
.lv__metric-lbl    { font-size: .65rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; margin-top: .1rem; }

/* Progreso */
.lv__progress-wrap { }
.lv__progress-row  { display: flex; justify-content: space-between; margin-bottom: .3rem; }
.lv__progress-lbl  { font-size: .72rem; color: #94a3b8; }
.lv__progress-pct  { font-size: .72rem; font-weight: 700; color: #1b5e20; }
.lv__progress-track { height: 5px; background: #e8f0eb; border-radius: 99px; overflow: hidden; }
.lv__progress-bar   { height: 100%; background: #3F6452; border-radius: 99px; transition: width .3s; }

.lv__card-notes {
  font-size: .78rem; color: #94a3b8; margin: 0;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
  flex: 1;
}

.lv__card-actions {
  display: flex; gap: .35rem; justify-content: flex-end;
  opacity: 0; transition: opacity .15s;
  padding-top: .5rem; border-top: 1px solid #f1f5f9;
}
.lv__card:hover .lv__card-actions { opacity: 1; }

.lv__action-btn {
  width: 30px; height: 30px; border-radius: 7px; border: 1px solid #e2e8f0;
  background: #f8fafc; color: #64748b; display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: .8rem; transition: background .15s, color .15s;
}
.lv__action-btn:hover { background: #e2e8f0; color: #0f172a; }
.lv__action-btn--danger:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }

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

.lm-spinner {
  display: inline-block; width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,.3); border-top-color: #fff;
  border-radius: 50%; animation: lv-spin .7s linear infinite;
}
</style>
