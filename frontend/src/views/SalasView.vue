<script setup>
import { ref, computed, watch, onMounted } from "vue";
import { useSalasStore } from "../stores/salas";
import { useAuthStore } from "../stores/auth";

const salas = useSalasStore();
const auth  = useAuthStore();

onMounted(() => {
  if (!salas.items.length) salas.fetch();
});

// ---------- permisos ----------
const canEdit = computed(() => ["admin","agricultor"].includes(auth.role));

// ---------- helpers ----------
function stateBadgeColor(state) {
  switch (state) {
    case "activa":        return "success";
    case "mantenimiento": return "warning";
    case "cerrada":       return "secondary";
    default:              return "secondary";
  }
}
function stateIcon(state) {
  switch (state) {
    case "activa":        return "🟢";
    case "mantenimiento": return "🟡";
    case "cerrada":       return "⚫";
    default:              return "⚪";
  }
}
function ocupacionColor(pct) {
  if (pct >= 90) return "danger";
  if (pct >= 70) return "warning";
  return "success";
}
function kindLabel(k) {
  const map = { vegetativo: "Vegetativo", floracion: "Floración", mixta: "Mixta", madre: "Madres", clon: "Clones" };
  return map[k] || k || "—";
}

// ---------- Filtros / Orden ----------
const q            = ref("");
const filterState  = ref("");
const filterKind   = ref("");
const sortBy       = ref("nombre_asc");
const viewMode     = ref("grid"); // "grid" | "list"

// ---------- Paginación ----------
const page    = ref(1);
const perPage = ref(6);

const filtered = computed(() => {
  const query = q.value.trim().toLowerCase();
  return salas.items.filter(s => {
    const matchesText  = !query || (s.nombre || "").toLowerCase().includes(query) || (s.notes || "").toLowerCase().includes(query);
    const matchesState = !filterState.value || s.state === filterState.value;
    const matchesKind  = !filterKind.value  || s.kind  === filterKind.value;
    return matchesText && matchesState && matchesKind;
  });
});

const sorted = computed(() => {
  const arr = [...filtered.value];
  arr.sort((a, b) => {
    const nA = (a.nombre || "").toLocaleLowerCase();
    const nB = (b.nombre || "").toLocaleLowerCase();
    const pA = Number(a.plantas_totales ?? 0);
    const pB = Number(b.plantas_totales ?? 0);
    const oA = Number(a.porcentaje_ocupacion ?? 0);
    const oB = Number(b.porcentaje_ocupacion ?? 0);
    switch (sortBy.value) {
      case "nombre_desc":   return nA < nB ? 1 : -1;
      case "ocupacion_desc":return oB - oA;
      case "plantas_desc":  return pB - pA;
      case "updated_desc":  return new Date(b.updated_at) - new Date(a.updated_at);
      default:              return nA > nB ? 1 : -1;
    }
  });
  return arr;
});

const totalItems = computed(() => sorted.value.length);
const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / perPage.value)));
const paginated  = computed(() => sorted.value.slice((page.value-1)*perPage.value, page.value*perPage.value));

watch([sorted, perPage], () => { if (page.value > totalPages.value) page.value = 1; });

// ---------- stats globales ----------
const statsGlobal = computed(() => {
  const all = salas.items;
  return {
    total:        all.length,
    activas:      all.filter(s => s.state === "activa").length,
    plantas:      all.reduce((a, s) => a + Number(s.plantas_totales || 0), 0),
    capacidad:    all.reduce((a, s) => a + Number(s.pots_count || 0), 0),
  };
});

// ---------- Modal Crear ----------
const showCreate   = ref(false);
const createForm   = ref(emptyForm());
const createErrors = ref({});

function emptyForm() {
  return { nombre: "", state: "activa", pots_count: 0, kind: "", notes: "" };
}
function resetCreate() { createForm.value = emptyForm(); createErrors.value = {}; }

function validateSala(form) {
  const e = {};
  if (!form.nombre?.trim()) e.nombre = "El nombre es obligatorio";
  if (!["activa","mantenimiento","cerrada"].includes(form.state)) e.state = "Estado inválido";
  const n = Number(form.pots_count);
  if (!Number.isInteger(n) || n < 0 || n > 9999) e.pots_count = "Debe ser un entero 0–9999";
  return e;
}
async function submitCreate() {
  const e = validateSala(createForm.value);
  createErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    await salas.create({ ...createForm.value });
    showCreate.value = false; resetCreate();
  } catch {}
}

// ---------- Modal Editar ----------
const showEdit   = ref(false);
const editForm   = ref({ id: null, ...emptyForm() });
const editErrors = ref({});

function startEdit(s) {
  editForm.value   = { id: s.id, nombre: s.nombre||"", state: s.state||"activa", pots_count: s.pots_count??0, kind: s.kind||"", notes: s.notes||"" };
  editErrors.value = {};
  showEdit.value   = true;
}
async function submitEdit() {
  const e = validateSala(editForm.value);
  editErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    const { id, ...payload } = editForm.value;
    await salas.update(id, payload);
    showEdit.value = false;
  } catch {}
}

// ---------- Eliminar ----------
const showDelete = ref(false);
const toDelete   = ref(null);
function confirmDelete(s) { toDelete.value = s; showDelete.value = true; }
async function doDelete() {
  if (!toDelete.value) return;
  try { await salas.remove(toDelete.value.id); showDelete.value = false; toDelete.value = null; } catch {}
}
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- ── Header ── -->
    <div class="d-flex justify-content-between align-items-start mb-4">
      <div>
        <h1 class="h3 fw-bold mb-1">Salas de cultivo</h1>
        <p class="text-muted small mb-0">Gestioná los espacios físicos del club</p>
      </div>
      <button v-if="canEdit" class="btn btn-primary d-flex align-items-center gap-2" @click="showCreate = true">
        <span class="fs-5 lh-1">＋</span> Nueva sala
      </button>
    </div>

    <!-- ── KPIs globales ── -->
    <div class="row g-3 mb-4">
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">Total salas</div>
            <div class="h2 fw-bold mb-0">{{ statsGlobal.total }}</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">Activas</div>
            <div class="h2 fw-bold mb-0 text-success">{{ statsGlobal.activas }}</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">Plantas totales</div>
            <div class="h2 fw-bold mb-0">{{ statsGlobal.plantas }}</div>
          </div>
        </div>
      </div>
      <div class="col-6 col-md-3">
        <div class="card border-0 bg-body-secondary h-100">
          <div class="card-body py-3">
            <div class="text-muted small">Capacidad total</div>
            <div class="h2 fw-bold mb-0">{{ statsGlobal.capacidad }}</div>
          </div>
        </div>
      </div>
    </div>

    <!-- ── Toolbar ── -->
    <div class="card border-0 bg-body-secondary mb-4">
      <div class="card-body py-3">
        <div class="row g-2 align-items-end">
          <div class="col-12 col-md-4">
            <input type="search" class="form-control" placeholder="🔍  Buscar por nombre o notas…" v-model.trim="q" />
          </div>
          <div class="col-6 col-md-2">
            <select class="form-select" v-model="filterState">
              <option value="">Todos los estados</option>
              <option value="activa">Activa</option>
              <option value="mantenimiento">Mantenimiento</option>
              <option value="cerrada">Cerrada</option>
            </select>
          </div>
          <div class="col-6 col-md-2">
            <select class="form-select" v-model="filterKind">
              <option value="">Todos los tipos</option>
              <option value="vegetativo">Vegetativo</option>
              <option value="floracion">Floración</option>
              <option value="mixta">Mixta</option>
              <option value="madre">Madres</option>
              <option value="clon">Clones</option>
            </select>
          </div>
          <div class="col-6 col-md-2">
            <select class="form-select" v-model="sortBy">
              <option value="nombre_asc">Nombre A→Z</option>
              <option value="nombre_desc">Nombre Z→A</option>
              <option value="ocupacion_desc">Mayor ocupación</option>
              <option value="plantas_desc">Más plantas</option>
              <option value="updated_desc">Recientes</option>
            </select>
          </div>
          <div class="col-6 col-md-2 d-flex gap-2 align-items-end">
            <select class="form-select" v-model.number="perPage">
              <option :value="6">6</option>
              <option :value="9">9</option>
              <option :value="12">12</option>
            </select>
            <div class="btn-group flex-shrink-0">
              <button class="btn btn-outline-secondary btn-sm px-2" :class="{ active: viewMode==='grid' }" @click="viewMode='grid'" title="Grilla">⊞</button>
              <button class="btn btn-outline-secondary btn-sm px-2" :class="{ active: viewMode==='list' }" @click="viewMode='list'" title="Lista">☰</button>
            </div>
          </div>
        </div>
        <div class="small text-muted mt-2">
          {{ paginated.length }} de {{ totalItems }} sala(s)
        </div>
      </div>
    </div>

    <!-- ── Loading / Error / Empty ── -->
    <div v-if="salas.loading" class="text-center py-5">
      <div class="spinner-border text-primary"></div>
      <div class="mt-2 text-muted">Cargando salas…</div>
    </div>
    <div v-else-if="salas.error" class="alert alert-danger">{{ salas.error }}</div>
    <div v-else-if="!salas.items.length" class="text-center py-5 text-muted">
      <div class="display-4 mb-3">🏗️</div>
      <h5>No hay salas todavía</h5>
      <p v-if="canEdit">Creá la primera sala para empezar a organizar el cultivo.</p>
    </div>
    <div v-else-if="!paginated.length" class="text-center py-5 text-muted">
      <div class="display-4 mb-3">🔍</div>
      <h5>Sin resultados</h5>
      <p>Probá con otros filtros.</p>
    </div>

    <!-- ── GRID view ── -->
    <div v-else-if="viewMode === 'grid'" class="row g-3">
      <div v-for="s in paginated" :key="s.id" class="col-12 col-sm-6 col-xl-4">
        <div class="card h-100 shadow-sm border-0 sala-card" :class="`sala-card--${s.state}`">

          <!-- Color bar top -->
          <div class="sala-card__bar" :class="`bg-${stateBadgeColor(s.state)}`"></div>

          <div class="card-body d-flex flex-column gap-2 pt-3">

            <!-- Título + estado -->
            <div class="d-flex justify-content-between align-items-start gap-2">
              <div class="flex-grow-1 min-w-0">
                <h5 class="fw-bold mb-0 text-truncate" :title="s.nombre">{{ s.nombre }}</h5>
                <div class="small text-muted">{{ kindLabel(s.kind) }}</div>
              </div>
              <span class="badge flex-shrink-0" :class="`text-bg-${stateBadgeColor(s.state)}`">
                {{ stateIcon(s.state) }} {{ s.state }}
              </span>
            </div>

            <!-- Barra de ocupación -->
            <div>
              <div class="d-flex justify-content-between small mb-1">
                <span class="text-muted">Ocupación</span>
                <span class="fw-semibold">{{ s.plantas_totales ?? 0 }} / {{ s.pots_count ?? 0 }} plantas</span>
              </div>
              <div class="progress" style="height:8px">
                <div
                  class="progress-bar"
                  :class="`bg-${ocupacionColor(s.porcentaje_ocupacion)}`"
                  :style="{ width: Math.min(s.porcentaje_ocupacion || 0, 100) + '%' }"
                ></div>
              </div>
              <div class="small text-end mt-1" :class="`text-${ocupacionColor(s.porcentaje_ocupacion)}`">
                {{ (s.porcentaje_ocupacion || 0).toFixed(1) }}%
              </div>
            </div>

            <!-- Notas -->
            <p class="small text-muted flex-grow-1 mb-0 sala-notes">{{ s.notes || "Sin notas." }}</p>

            <!-- Creado por -->
            <div v-if="s.created_by_name" class="small text-muted border-top pt-2">
              👤 {{ s.created_by_name }}
            </div>

            <!-- Acciones -->
            <div class="d-flex gap-2 mt-auto pt-2 border-top">
              <RouterLink class="btn btn-sm btn-primary flex-fill" :to="{ name: 'sala-detail', params: { id: s.id } }">
                Ver detalle
              </RouterLink>
              <template v-if="canEdit">
                <button class="btn btn-sm btn-outline-secondary" @click="startEdit(s)" :disabled="salas.updating && editForm.id === s.id">
                  ✏️
                </button>
                <button class="btn btn-sm btn-outline-danger" @click="confirmDelete(s)" :disabled="salas.removing && toDelete?.id === s.id">
                  🗑️
                </button>
              </template>
            </div>

          </div>
        </div>
      </div>
    </div>

    <!-- ── LIST view ── -->
    <div v-else class="card border-0 shadow-sm">
      <div class="table-responsive">
        <table class="table table-hover align-middle mb-0">
          <thead class="table-light">
          <tr>
            <th>Sala</th>
            <th>Tipo</th>
            <th>Estado</th>
            <th>Plantas</th>
            <th>Ocupación</th>
            <th>Creado por</th>
            <th></th>
          </tr>
          </thead>
          <tbody>
          <tr v-for="s in paginated" :key="s.id">
            <td>
              <div class="fw-semibold">{{ s.nombre }}</div>
              <div v-if="s.notes" class="small text-muted text-truncate" style="max-width:200px">{{ s.notes }}</div>
            </td>
            <td><span class="badge text-bg-light text-dark">{{ kindLabel(s.kind) }}</span></td>
            <td>
                <span class="badge" :class="`text-bg-${stateBadgeColor(s.state)}`">
                  {{ stateIcon(s.state) }} {{ s.state }}
                </span>
            </td>
            <td>{{ s.plantas_totales ?? 0 }} / {{ s.pots_count ?? 0 }}</td>
            <td style="min-width:120px">
              <div class="progress" style="height:6px">
                <div class="progress-bar" :class="`bg-${ocupacionColor(s.porcentaje_ocupacion)}`"
                     :style="{ width: Math.min(s.porcentaje_ocupacion||0,100)+'%' }"></div>
              </div>
              <div class="small text-muted mt-1">{{ (s.porcentaje_ocupacion||0).toFixed(1) }}%</div>
            </td>
            <td class="small text-muted">{{ s.created_by_name || "—" }}</td>
            <td class="text-end">
              <div class="d-flex gap-1 justify-content-end">
                <RouterLink class="btn btn-sm btn-outline-primary" :to="{ name: 'sala-detail', params: { id: s.id } }">Ver</RouterLink>
                <template v-if="canEdit">
                  <button class="btn btn-sm btn-outline-secondary" @click="startEdit(s)">✏️</button>
                  <button class="btn btn-sm btn-outline-danger" @click="confirmDelete(s)">🗑️</button>
                </template>
              </div>
            </td>
          </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ── Paginación ── -->
    <nav v-if="totalPages > 1" class="mt-3">
      <ul class="pagination mb-0">
        <li class="page-item" :class="{ disabled: page <= 1 }">
          <button class="page-link" @click="page--">‹</button>
        </li>
        <li v-for="p in totalPages" :key="p" class="page-item" :class="{ active: p === page }">
          <button class="page-link" @click="page = p">{{ p }}</button>
        </li>
        <li class="page-item" :class="{ disabled: page >= totalPages }">
          <button class="page-link" @click="page++">›</button>
        </li>
      </ul>
    </nav>

    <!-- ===== MODAL Crear ===== -->
    <div class="modal fade" :class="{ show: showCreate }" :style="{ display: showCreate ? 'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nueva sala</h5>
            <button class="btn-close" @click="showCreate=false; resetCreate()"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.createError" class="alert alert-danger">{{ salas.createError }}</div>
            <div class="row g-3">
              <div class="col-12">
                <label class="form-label">Nombre <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="createForm.nombre"
                       :class="{ 'is-invalid': createErrors.nombre }" placeholder="Ej: Sala A — Vegetativo" />
                <div class="invalid-feedback">{{ createErrors.nombre }}</div>
              </div>
              <div class="col-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="createForm.state" :class="{ 'is-invalid': createErrors.state }">
                  <option value="activa">Activa</option>
                  <option value="mantenimiento">Mantenimiento</option>
                  <option value="cerrada">Cerrada</option>
                </select>
                <div class="invalid-feedback">{{ createErrors.state }}</div>
              </div>
              <div class="col-6">
                <label class="form-label">Tipo de sala</label>
                <select class="form-select" v-model="createForm.kind">
                  <option value="">Sin especificar</option>
                  <option value="vegetativo">Vegetativo</option>
                  <option value="floracion">Floración</option>
                  <option value="mixta">Mixta</option>
                  <option value="madre">Madres</option>
                  <option value="clon">Clones</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Capacidad máx. (plantas)</label>
                <input type="number" min="0" max="9999" step="1" class="form-control"
                       v-model.number="createForm.pots_count" :class="{ 'is-invalid': createErrors.pots_count }" />
                <div class="invalid-feedback">{{ createErrors.pots_count }}</div>
              </div>
              <div class="col-12">
                <label class="form-label">Notas</label>
                <textarea class="form-control" rows="2" v-model.trim="createForm.notes" placeholder="Observaciones opcionales…"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="salas.creating" @click="showCreate=false; resetCreate()">Cancelar</button>
            <button class="btn btn-primary" :disabled="salas.creating" @click="submitCreate">
              <span v-if="salas.creating" class="spinner-border spinner-border-sm me-2"></span>Crear sala
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="showCreate=false; resetCreate()"></div>

    <!-- ===== MODAL Editar ===== -->
    <div class="modal fade" :class="{ show: showEdit }" :style="{ display: showEdit ? 'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Editar — {{ editForm.nombre }}</h5>
            <button class="btn-close" @click="showEdit=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.updateError" class="alert alert-danger">{{ salas.updateError }}</div>
            <div class="row g-3">
              <div class="col-12">
                <label class="form-label">Nombre <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="editForm.nombre"
                       :class="{ 'is-invalid': editErrors.nombre }" />
                <div class="invalid-feedback">{{ editErrors.nombre }}</div>
              </div>
              <div class="col-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="editForm.state" :class="{ 'is-invalid': editErrors.state }">
                  <option value="activa">Activa</option>
                  <option value="mantenimiento">Mantenimiento</option>
                  <option value="cerrada">Cerrada</option>
                </select>
                <div class="invalid-feedback">{{ editErrors.state }}</div>
              </div>
              <div class="col-6">
                <label class="form-label">Tipo de sala</label>
                <select class="form-select" v-model="editForm.kind">
                  <option value="">Sin especificar</option>
                  <option value="vegetativo">Vegetativo</option>
                  <option value="floracion">Floración</option>
                  <option value="mixta">Mixta</option>
                  <option value="madre">Madres</option>
                  <option value="clon">Clones</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Capacidad máx. (plantas)</label>
                <input type="number" min="0" max="9999" step="1" class="form-control"
                       v-model.number="editForm.pots_count" :class="{ 'is-invalid': editErrors.pots_count }" />
                <div class="invalid-feedback">{{ editErrors.pots_count }}</div>
              </div>
              <div class="col-12">
                <label class="form-label">Notas</label>
                <textarea class="form-control" rows="2" v-model.trim="editForm.notes"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="salas.updating" @click="showEdit=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="salas.updating" @click="submitEdit">
              <span v-if="salas.updating" class="spinner-border spinner-border-sm me-2"></span>Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showEdit }" v-if="showEdit" @click="showEdit=false"></div>

    <!-- ===== MODAL Eliminar ===== -->
    <div class="modal fade" :class="{ show: showDelete }" :style="{ display: showDelete ? 'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0 pb-0">
            <button class="btn-close ms-auto" @click="showDelete=false"></button>
          </div>
          <div class="modal-body text-center py-2">
            <div class="display-4 mb-3">⚠️</div>
            <h5>¿Eliminar "{{ toDelete?.nombre }}"?</h5>
            <p class="text-muted small">Esta acción eliminará la sala y todos sus datos. No se puede deshacer.</p>
            <div v-if="salas.removeError" class="alert alert-danger">{{ salas.removeError }}</div>
          </div>
          <div class="modal-footer justify-content-center border-0">
            <button class="btn btn-outline-secondary px-4" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger px-4" :disabled="salas.removing" @click="doDelete">
              <span v-if="salas.removing" class="spinner-border spinner-border-sm me-2"></span>Eliminar
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

.sala-card { transition: transform .15s, box-shadow .15s; border-radius: .75rem; overflow: hidden; }
.sala-card:hover { transform: translateY(-2px); box-shadow: 0 .5rem 1.5rem rgba(0,0,0,.12) !important; }
.sala-card__bar { height: 4px; width: 100%; }

.sala-notes {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>


