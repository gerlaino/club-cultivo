<script setup>
import { ref, computed, watch, onMounted } from "vue";
import { useLotesStore } from "../stores/lotes";
import { useSalasStore } from "../stores/salas";
import { useAuthStore }  from "../stores/auth";

// Valores reales del modelo:
// estado:     planificacion | vegetativo | floracion | secado | cosechado | finalizado
// grow_type:  sustrato | hidroponia | aeroponia
// light_type: led | hps | cmh | natural | mixta

const store = useLotesStore();
const salas = useSalasStore();
const auth  = useAuthStore();

onMounted(() => {
  store.fetch();
  if (!salas.items.length) salas.fetch();
});

const canEdit = computed(() => ["admin","agricultor"].includes(auth.role));

// ---------- helpers ----------
const ESTADOS = ["planificacion","vegetativo","floracion","secado","cosechado","finalizado"];

const ESTADO_META = {
  planificacion: { label:"Planificación", color:"info",      icon:"📋" },
  vegetativo:    { label:"Vegetativo",    color:"success",   icon:"🌱" },
  floracion:     { label:"Floración",     color:"warning",   icon:"🌸" },
  secado:        { label:"Secado",        color:"secondary", icon:"🍂" },
  cosechado:     { label:"Cosechado",     color:"primary",   icon:"✂️"  },
  finalizado:    { label:"Finalizado",    color:"dark",      icon:"✅" },
};

function em(estado)         { return ESTADO_META[estado] || { label: estado||"—", color:"secondary", icon:"•" }; }
function estadoLabel(e)     { return em(e).label; }
function estadoBadge(e)     { return em(e).color; }
function estadoIcon(e)      { return em(e).icon; }
function growLabel(g)       { return { sustrato:"Sustrato", hidroponia:"Hidroponia", aeroponia:"Aeroponia" }[g] || g || "—"; }
function lightLabel(l)      { return { led:"LED", hps:"HPS", cmh:"CMH", natural:"Natural", mixta:"Mixta" }[l] || l || "—"; }
function salaName(sala_id)  { return salas.items.find(s => String(s.id) === String(sala_id))?.nombre || `Sala #${sala_id}`; }
function diasDesdeInicio(d) { return d ? Math.floor((Date.now() - new Date(d)) / 86_400_000) : null; }

// ---------- Stats globales ----------
const stats = computed(() => {
  const all = store.items;
  return {
    total:      all.length,
    enCiclo:    all.filter(l => ["vegetativo","floracion"].includes(l.estado)).length,
    plantas:    all.reduce((a,l) => a + Number(l.plants_count||0), 0),
    cosechados: all.filter(l => l.estado === "cosechado").length,
  };
});

// ---------- Filtros / Orden ----------
const q             = ref("");
const filterEstado  = ref("");
const filterSala    = ref("");
const filterGrow    = ref("");
const sortBy        = ref("fecha_desc");
const page          = ref(1);
const perPage       = ref(6);

const filtered = computed(() => {
  const query = q.value.trim().toLowerCase();
  return store.items.filter(l => {
    const matchText  = !query || (l.codigo||"").toLowerCase().includes(query) || (l.strain||"").toLowerCase().includes(query) || (l.notes||"").toLowerCase().includes(query);
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
      case "codigo_asc":    return cA > cB ? 1 : -1;
      case "codigo_desc":   return cA < cB ? 1 : -1;
      case "fecha_asc":     return fA - fB;
      case "plantas_desc":  return pB - pA;
      case "plantas_asc":   return pA - pB;
      case "estado":        return ESTADOS.indexOf(a.estado) - ESTADOS.indexOf(b.estado);
      default:              return fB - fA;
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
function resetCreate() { createForm.value = emptyForm(); createErrors.value = {}; }

const showEdit   = ref(false);
const editForm   = ref({ id: null, ...emptyForm() });
const editErrors = ref({});

const showDelete = ref(false);
const toDelete   = ref(null);

function validateForm(form) {
  const e = {};
  if (!form.codigo?.trim()) e.codigo = "El código es obligatorio";
  if (!ESTADOS.includes(form.estado)) e.estado = "Estado inválido";
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
    showCreate.value = false; resetCreate();
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

function confirmDelete(l) { toDelete.value = l; showDelete.value = true; }
async function doDelete() {
  if (!toDelete.value) return;
  try { await store.remove(toDelete.value.id, toDelete.value.sala_id); showDelete.value = false; toDelete.value = null; } catch {}
}
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex justify-content-between align-items-start mb-4">
      <div>
        <h1 class="h3 fw-bold mb-1">Lotes de cultivo</h1>
        <p class="text-muted small mb-0">Seguimiento de ciclos y trazabilidad</p>
      </div>
      <button v-if="canEdit" class="btn btn-success d-flex align-items-center gap-2" @click="showCreate=true">
        <span class="fs-5 lh-1">＋</span> Nuevo lote
      </button>
    </div>

    <!-- KPIs -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">Total lotes</div>
            <div class="h2 fw-bold mb-0">{{ stats.total }}</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">En ciclo activo</div>
            <div class="h2 fw-bold mb-0 text-success">{{ stats.enCiclo }}</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">Plantas totales</div>
            <div class="h2 fw-bold mb-0">{{ stats.plantas }}</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">Cosechados</div>
            <div class="h2 fw-bold mb-0 text-primary">{{ stats.cosechados }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- Toolbar -->
    <div class="card border-0 bg-body-secondary mb-4">
      <div class="card-body py-3">
        <div class="row g-2 align-items-end">
          <div class="col-12 col-md-3">
            <input type="search" class="form-control" placeholder="🔍  Código, strain, notas…" v-model.trim="q" />
          </div>
          <div class="col-6 col-md-2">
            <select class="form-select" v-model="filterEstado">
              <option value="">Todos los estados</option>
              <option v-for="e in ESTADOS" :key="e" :value="e">{{ estadoLabel(e) }}</option>
            </select>
          </div>
          <div class="col-6 col-md-2">
            <select class="form-select" v-model="filterSala">
              <option value="">Todas las salas</option>
              <option v-for="s in salas.items" :key="s.id" :value="String(s.id)">{{ s.nombre }}</option>
            </select>
          </div>
          <div class="col-6 col-md-2">
            <select class="form-select" v-model="filterGrow">
              <option value="">Todos los tipos</option>
              <option value="sustrato">Sustrato</option>
              <option value="hidroponia">Hidroponia</option>
              <option value="aeroponia">Aeroponia</option>
            </select>
          </div>
          <div class="col-6 col-md-2">
            <select class="form-select" v-model="sortBy">
              <option value="fecha_desc">Más recientes</option>
              <option value="fecha_asc">Más antiguos</option>
              <option value="estado">Por estado</option>
              <option value="codigo_asc">Código A→Z</option>
              <option value="plantas_desc">Más plantas</option>
            </select>
          </div>
          <div class="col-6 col-md-1">
            <select class="form-select" v-model.number="perPage">
              <option :value="6">6</option>
              <option :value="9">9</option>
              <option :value="12">12</option>
            </select>
          </div>
        </div>
        <div class="small text-muted mt-2">{{ paginated.length }} de {{ totalItems }} lote(s)</div>
      </div>
    </div>

    <!-- Loading / Empty -->
    <div v-if="store.loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
      <div class="mt-2 text-muted">Cargando lotes…</div>
    </div>
    <div v-else-if="store.error" class="alert alert-danger">{{ store.error }}</div>
    <div v-else-if="!store.items.length" class="text-center py-5 text-muted">
      <div class="display-4 mb-3">🌱</div>
      <h5>No hay lotes todavía</h5>
    </div>
    <div v-else-if="!paginated.length" class="text-center py-5 text-muted">
      <div class="display-4 mb-3">🔍</div>
      <h5>Sin resultados</h5>
    </div>

    <!-- Grid -->
    <div v-else class="row g-3">
      <div v-for="l in paginated" :key="l.id" class="col-12 col-sm-6 col-xl-4">
        <div class="card h-100 border-0 shadow-sm lote-card">
          <!-- barra de color por estado -->
          <div class="lote-card__bar" :class="`bg-${estadoBadge(l.estado)}`"></div>

          <div class="card-body d-flex flex-column gap-2 pt-3">

            <!-- Código + estado -->
            <div class="d-flex justify-content-between align-items-start gap-2">
              <h5 class="fw-bold mb-0 text-truncate" :title="l.codigo">
                {{ estadoIcon(l.estado) }} {{ l.codigo }}
              </h5>
              <span class="badge flex-shrink-0" :class="`text-bg-${estadoBadge(l.estado)}`">
                {{ estadoLabel(l.estado) }}
              </span>
            </div>

            <!-- Strain + sala -->
            <div class="small text-muted d-flex gap-2 flex-wrap">
              <span v-if="l.strain">🌿 <em>{{ l.strain }}</em></span>
              <span>📍 {{ salaName(l.sala_id) }}</span>
            </div>

            <!-- Métricas -->
            <div class="d-flex gap-3 small">
              <div class="text-center">
                <div class="fw-bold fs-5">{{ l.plants_count ?? 0 }}</div>
                <div class="text-muted">plantas</div>
              </div>
              <div v-if="diasDesdeInicio(l.start_date) !== null" class="text-center">
                <div class="fw-bold fs-5">{{ diasDesdeInicio(l.start_date) }}</div>
                <div class="text-muted">días</div>
              </div>
              <div v-if="l.grow_type" class="text-center">
                <div class="fw-bold fs-6">{{ growLabel(l.grow_type) }}</div>
                <div class="text-muted">cultivo</div>
              </div>
              <div v-if="l.light_type" class="text-center">
                <div class="fw-bold fs-6">{{ lightLabel(l.light_type) }}</div>
                <div class="text-muted">luz</div>
              </div>
            </div>

            <!-- Progreso ciclo si está en vegetativo/floracion -->
            <div v-if="l.progreso_ciclo != null && ['vegetativo','floracion'].includes(l.estado)">
              <div class="d-flex justify-content-between small mb-1">
                <span class="text-muted">Progreso ciclo</span>
                <span>{{ l.progreso_ciclo }}%</span>
              </div>
              <div class="progress" style="height:6px">
                <div class="progress-bar bg-success" :style="{ width: l.progreso_ciclo + '%' }"></div>
              </div>
            </div>

            <p class="small text-muted flex-grow-1 mb-0 lote-notes">{{ l.notes || "Sin notas." }}</p>

            <!-- Acciones -->
            <div class="d-flex gap-2 mt-auto pt-2 border-top">
              <RouterLink class="btn btn-sm btn-outline-success flex-fill" :to="{ name: 'lote-detail', params: { id: l.id } }">
                Ver detalle
              </RouterLink>
              <template v-if="canEdit">
                <button class="btn btn-sm btn-outline-secondary" @click="startEdit(l)" :disabled="store.updating && editForm.id===l.id">✏️</button>
                <button class="btn btn-sm btn-outline-danger" @click="confirmDelete(l)" :disabled="store.removing && toDelete?.id===l.id">🗑️</button>
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Paginación -->
    <nav v-if="totalPages > 1" class="mt-3">
      <ul class="pagination mb-0">
        <li class="page-item" :class="{ disabled: page<=1 }"><button class="page-link" @click="page--">‹</button></li>
        <li v-for="p in totalPages" :key="p" class="page-item" :class="{ active: p===page }">
          <button class="page-link" @click="page=p">{{ p }}</button>
        </li>
        <li class="page-item" :class="{ disabled: page>=totalPages }"><button class="page-link" @click="page++">›</button></li>
      </ul>
    </nav>

    <!-- MODAL Crear -->
    <div class="modal fade" :class="{ show: showCreate }" :style="{ display: showCreate?'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nuevo lote</h5>
            <button class="btn-close" @click="showCreate=false; resetCreate()"></button>
          </div>
          <div class="modal-body">
            <div v-if="store.createError" class="alert alert-danger">{{ store.createError }}</div>
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Código <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="createForm.codigo"
                       :class="{ 'is-invalid': createErrors.codigo }" placeholder="Ej: LOT-2026-001" />
                <div class="invalid-feedback">{{ createErrors.codigo }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Sala <span class="text-danger">*</span></label>
                <select class="form-select" v-model="createForm.sala_id" :class="{ 'is-invalid': createErrors.sala_id }">
                  <option value="" disabled>Seleccioná una sala…</option>
                  <option v-for="s in salas.items" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
                <div class="invalid-feedback">{{ createErrors.sala_id }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="createForm.estado">
                  <option v-for="e in ESTADOS" :key="e" :value="e">{{ estadoLabel(e) }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" step="1" class="form-control"
                       v-model.number="createForm.plants_count" :class="{ 'is-invalid': createErrors.plants_count }" />
                <div class="invalid-feedback">{{ createErrors.plants_count }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Fecha de inicio</label>
                <input type="date" class="form-control" v-model="createForm.start_date" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Strain / Variedad</label>
                <input type="text" class="form-control" v-model.trim="createForm.strain" placeholder="Ej: OG Kush" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Tipo de cultivo</label>
                <select class="form-select" v-model="createForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Tipo de luz</label>
                <select class="form-select" v-model="createForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Notas</label>
                <textarea class="form-control" rows="2" v-model.trim="createForm.notes"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="store.creating" @click="showCreate=false; resetCreate()">Cancelar</button>
            <button class="btn btn-success" :disabled="store.creating" @click="submitCreate">
              <span v-if="store.creating" class="spinner-border spinner-border-sm me-2"></span>Crear lote
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="showCreate=false; resetCreate()"></div>

    <!-- MODAL Editar -->
    <div class="modal fade" :class="{ show: showEdit }" :style="{ display: showEdit?'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Editar — <span class="text-muted fw-normal">{{ editForm.codigo }}</span></h5>
            <button class="btn-close" @click="showEdit=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="store.updateError" class="alert alert-danger">{{ store.updateError }}</div>
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Código <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="editForm.codigo" :class="{ 'is-invalid': editErrors.codigo }" />
                <div class="invalid-feedback">{{ editErrors.codigo }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Sala</label>
                <select class="form-select" v-model="editForm.sala_id">
                  <option v-for="s in salas.items" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="editForm.estado">
                  <option v-for="e in ESTADOS" :key="e" :value="e">{{ estadoLabel(e) }}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" step="1" class="form-control"
                       v-model.number="editForm.plants_count" :class="{ 'is-invalid': editErrors.plants_count }" />
                <div class="invalid-feedback">{{ editErrors.plants_count }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Fecha de inicio</label>
                <input type="date" class="form-control" v-model="editForm.start_date" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Strain / Variedad</label>
                <input type="text" class="form-control" v-model.trim="editForm.strain" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Tipo de cultivo</label>
                <select class="form-select" v-model="editForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Tipo de luz</label>
                <select class="form-select" v-model="editForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Notas</label>
                <textarea class="form-control" rows="2" v-model.trim="editForm.notes"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="store.updating" @click="showEdit=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="store.updating" @click="submitEdit">
              <span v-if="store.updating" class="spinner-border spinner-border-sm me-2"></span>Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showEdit }" v-if="showEdit" @click="showEdit=false"></div>

    <!-- MODAL Eliminar -->
    <div class="modal fade" :class="{ show: showDelete }" :style="{ display: showDelete?'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0 pb-0">
            <button class="btn-close ms-auto" @click="showDelete=false"></button>
          </div>
          <div class="modal-body text-center py-2">
            <div class="display-4 mb-3">⚠️</div>
            <h5>¿Eliminar "{{ toDelete?.codigo }}"?</h5>
            <p class="text-muted small">Esta acción no se puede deshacer.</p>
            <div v-if="store.removeError" class="alert alert-danger">{{ store.removeError }}</div>
          </div>
          <div class="modal-footer justify-content-center border-0">
            <button class="btn btn-outline-secondary px-4" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger px-4" :disabled="store.removing" @click="doDelete">
              <span v-if="store.removing" class="spinner-border spinner-border-sm me-2"></span>Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showDelete }" v-if="showDelete" @click="showDelete=false"></div>

  </div>
</template>

<style scoped>
.modal { background: rgba(0,0,0,.01); }
.lote-card { border-radius: .75rem; overflow: hidden; transition: transform .15s, box-shadow .15s; }
.lote-card:hover { transform: translateY(-2px); box-shadow: 0 .5rem 1.5rem rgba(0,0,0,.12) !important; }
.lote-card__bar { height: 4px; width: 100%; }
.lote-notes { display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
</style>



