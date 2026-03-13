<script setup>
import { ref, computed, watch, onMounted } from "vue";
import { useSalasStore } from "../stores/salas";

const salas = useSalasStore();

onMounted(() => {
  if (!salas.items.length) salas.fetch();
});

// ---------- helpers ----------
// Campos reales DB: nombre, state, pots_count, notes
function stateBadgeColor(state) {
  switch (state) {
    case "activa":        return "success";
    case "mantenimiento": return "warning";
    case "cerrada":       return "secondary";
    default:              return "secondary";
  }
}

// ---------- Filtros / Orden ----------
const q           = ref("");
const filterState = ref("");
const sortBy      = ref("nombre_asc");

// ---------- Paginación ----------
const page    = ref(1);
const perPage = ref(6);

const filtered = computed(() => {
  const query = q.value.trim().toLowerCase();
  return salas.items.filter(s => {
    const matchesText =
      !query ||
      (s.nombre || "").toLowerCase().includes(query) ||
      (s.notes  || "").toLowerCase().includes(query);
    const matchesState = !filterState.value || s.state === filterState.value;
    return matchesText && matchesState;
  });
});

const sorted = computed(() => {
  const arr = [...filtered.value];
  arr.sort((a, b) => {
    const potsA   = Number(a.pots_count ?? 0);
    const potsB   = Number(b.pots_count ?? 0);
    const nombreA = (a.nombre || "").toLocaleLowerCase();
    const nombreB = (b.nombre || "").toLocaleLowerCase();
    const updA    = new Date(a.updated_at || a.created_at || 0).getTime();
    const updB    = new Date(b.updated_at || b.created_at || 0).getTime();

    switch (sortBy.value) {
      case "nombre_desc":   return nombreA < nombreB ? 1 : nombreA > nombreB ? -1 : 0;
      case "pots_desc":     return potsB - potsA;
      case "pots_asc":      return potsA - potsB;
      case "updated_desc":  return updB - updA;
      case "updated_asc":   return updA - updB;
      case "nombre_asc":
      default:              return nombreA > nombreB ? 1 : nombreA < nombreB ? -1 : 0;
    }
  });
  return arr;
});

const totalItems = computed(() => sorted.value.length);
const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / perPage.value)));
const paginated  = computed(() => {
  const start = (page.value - 1) * perPage.value;
  return sorted.value.slice(start, start + perPage.value);
});

watch([sorted, perPage], () => {
  if (page.value > totalPages.value) page.value = 1;
});

// ---------- Modal Crear ----------
const showCreate  = ref(false);
const createForm  = ref({ nombre: "", state: "activa", pots_count: 0, notes: "" });
const createErrors = ref({});

function resetCreate() {
  createForm.value  = { nombre: "", state: "activa", pots_count: 0, notes: "" };
  createErrors.value = {};
}
function validateCreate() {
  const e = {};
  if (!createForm.value.nombre?.trim()) e.nombre = "El nombre es obligatorio";
  if (!["activa","mantenimiento","cerrada"].includes(createForm.value.state)) e.state = "Estado inválido";
  const n = Number(createForm.value.pots_count);
  if (!Number.isInteger(n) || n < 0 || n > 1000) e.pots_count = "Debe ser un entero 0–1000";
  createErrors.value = e;
  return Object.keys(e).length === 0;
}
async function submitCreate() {
  if (!validateCreate()) return;
  try {
    await salas.create({ ...createForm.value });
    showCreate.value = false;
    resetCreate();
  } catch { /* el store ya setea createError */ }
}

// ---------- Modal Editar ----------
const showEdit  = ref(false);
const editForm  = ref({ id: null, nombre: "", state: "activa", pots_count: 0, notes: "" });
const editErrors = ref({});

function startEdit(s) {
  editForm.value  = {
    id:         s.id,
    nombre:     s.nombre     || "",
    state:      s.state      || "activa",
    pots_count: s.pots_count ?? 0,
    notes:      s.notes      || "",
  };
  editErrors.value = {};
  showEdit.value  = true;
}
function validateEdit() {
  const e = {};
  if (!editForm.value.nombre?.trim()) e.nombre = "El nombre es obligatorio";
  if (!["activa","mantenimiento","cerrada"].includes(editForm.value.state)) e.state = "Estado inválido";
  const n = Number(editForm.value.pots_count);
  if (!Number.isInteger(n) || n < 0 || n > 1000) e.pots_count = "Debe ser un entero 0–1000";
  editErrors.value = e;
  return Object.keys(e).length === 0;
}
async function submitEdit() {
  if (!validateEdit()) return;
  try {
    const { id, ...payload } = editForm.value;
    await salas.update(id, payload);
    showEdit.value = false;
  } catch { /* el store ya setea updateError */ }
}

// ---------- Confirmación Eliminar ----------
const showDelete = ref(false);
const toDelete   = ref(null);
function confirmDelete(s) { toDelete.value = s; showDelete.value = true; }
async function doDelete() {
  if (!toDelete.value) return;
  try {
    await salas.remove(toDelete.value.id);
    showDelete.value = false;
    toDelete.value   = null;
  } catch { /* el store ya setea removeError */ }
}
</script>

<template>
  <div class="container py-4">

    <!-- Encabezado -->
    <div class="d-flex justify-content-between align-items-center mb-3">
      <h2 class="m-0">Salas</h2>
      <button class="btn btn-primary" @click="showCreate = true">
        <i class="bi bi-plus-lg me-1"></i>Nueva sala
      </button>
    </div>

    <!-- Toolbar filtros/orden -->
    <div class="card mb-3">
      <div class="card-body">
        <div class="row g-2 align-items-end">
          <div class="col-12 col-md-4">
            <label class="form-label">Buscar</label>
            <input
              type="search"
              class="form-control"
              placeholder="Nombre o notas…"
              v-model.trim="q"
            />
          </div>
          <div class="col-6 col-md-3">
            <label class="form-label">Estado</label>
            <select class="form-select" v-model="filterState">
              <option value="">Todos</option>
              <option value="activa">Activa</option>
              <option value="mantenimiento">Mantenimiento</option>
              <option value="cerrada">Cerrada</option>
            </select>
          </div>
          <div class="col-6 col-md-3">
            <label class="form-label">Ordenar por</label>
            <select class="form-select" v-model="sortBy">
              <option value="nombre_asc">Nombre (A→Z)</option>
              <option value="nombre_desc">Nombre (Z→A)</option>
              <option value="pots_desc">Plantas (mayor→menor)</option>
              <option value="pots_asc">Plantas (menor→mayor)</option>
              <option value="updated_desc">Recientes</option>
              <option value="updated_asc">Antiguas</option>
            </select>
          </div>
          <div class="col-6 col-md-2">
            <label class="form-label">Por página</label>
            <select class="form-select" v-model.number="perPage">
              <option :value="6">6</option>
              <option :value="9">9</option>
              <option :value="12">12</option>
            </select>
          </div>
        </div>
        <div class="small text-muted mt-2">
          Mostrando {{ paginated.length }} de {{ totalItems }} sala(s)
        </div>
      </div>
    </div>

    <!-- Estados generales -->
    <div v-if="salas.loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="salas.error" class="alert alert-danger">{{ salas.error }}</div>
    <div v-else-if="!salas.items.length" class="alert alert-secondary">No hay salas todavía.</div>

    <!-- Grid -->
    <div v-else>
      <div v-if="!paginated.length" class="alert alert-warning">
        No se encontraron salas con los filtros actuales.
      </div>

      <div class="row g-3">
        <div v-for="s in paginated" :key="s.id" class="col-12 col-sm-6 col-lg-4">
          <div class="card h-100 shadow-sm">
            <div class="card-body d-flex flex-column gap-2">

              <!-- Título + badge estado -->
              <div class="d-flex justify-content-between align-items-start">
                <h5 class="card-title mb-0 text-truncate" :title="s.nombre">{{ s.nombre }}</h5>
                <span
                  class="badge text-capitalize flex-shrink-0 ms-2"
                  :class="`text-bg-${stateBadgeColor(s.state)}`"
                >
                  {{ s.state || "—" }}
                </span>
              </div>

              <!-- Info -->
              <p class="text-muted mb-0">
                🌱 Plantas: <strong>{{ s.pots_count ?? 0 }}</strong>
              </p>
              <p class="small text-muted flex-grow-1 mb-0">{{ s.notes || "Sin notas." }}</p>

              <!-- Acciones agrupadas -->
              <div class="d-flex gap-2 mt-auto pt-2 border-top">
                <RouterLink
                  class="btn btn-sm btn-outline-primary flex-fill"
                  :to="{ name: 'sala-detail', params: { id: s.id } }"
                >
                  Ver
                </RouterLink>
                <button
                  class="btn btn-sm btn-outline-secondary flex-fill"
                  @click="startEdit(s)"
                  :disabled="salas.updating && editForm.id === s.id"
                >
                  <span v-if="salas.updating && editForm.id === s.id" class="spinner-border spinner-border-sm me-1"></span>
                  Editar
                </button>
                <button
                  class="btn btn-sm btn-outline-danger"
                  @click="confirmDelete(s)"
                  :disabled="salas.removing && toDelete?.id === s.id"
                >
                  <span v-if="salas.removing && toDelete?.id === s.id" class="spinner-border spinner-border-sm"></span>
                  <span v-else>✕</span>
                </button>
              </div>

            </div>
          </div>
        </div>
      </div>

      <!-- Paginación -->
      <nav class="mt-3" aria-label="Paginación">
        <ul class="pagination mb-0">
          <li class="page-item" :class="{ disabled: page <= 1 }">
            <button class="page-link" @click="page = Math.max(1, page - 1)">Anterior</button>
          </li>
          <li
            v-for="p in totalPages"
            :key="p"
            class="page-item"
            :class="{ active: p === page }"
          >
            <button class="page-link" @click="page = p">{{ p }}</button>
          </li>
          <li class="page-item" :class="{ disabled: page >= totalPages }">
            <button class="page-link" @click="page = Math.min(totalPages, page + 1)">Siguiente</button>
          </li>
        </ul>
      </nav>
    </div>

    <!-- ===== MODAL Crear ===== -->
    <div
      class="modal fade"
      :class="{ show: showCreate }"
      :style="{ display: showCreate ? 'block' : 'none' }"
      tabindex="-1" role="dialog" aria-modal="true"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nueva sala</h5>
            <button type="button" class="btn-close" @click="showCreate = false; resetCreate()"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.createError" class="alert alert-danger">{{ salas.createError }}</div>

            <div class="mb-3">
              <label class="form-label">Nombre <span class="text-danger">*</span></label>
              <input
                type="text" class="form-control"
                v-model.trim="createForm.nombre"
                :class="{ 'is-invalid': createErrors.nombre }"
                placeholder="Ej: Sala A"
              />
              <div class="invalid-feedback">{{ createErrors.nombre }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Estado</label>
              <select class="form-select" v-model="createForm.state" :class="{ 'is-invalid': createErrors.state }">
                <option value="activa">Activa</option>
                <option value="mantenimiento">Mantenimiento</option>
                <option value="cerrada">Cerrada</option>
              </select>
              <div class="invalid-feedback">{{ createErrors.state }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Capacidad (plantas)</label>
              <input
                type="number" min="0" max="1000" step="1" class="form-control"
                v-model.number="createForm.pots_count"
                :class="{ 'is-invalid': createErrors.pots_count }"
              />
              <div class="invalid-feedback">{{ createErrors.pots_count }}</div>
            </div>

            <div class="mb-2">
              <label class="form-label">Notas</label>
              <textarea class="form-control" rows="3" v-model.trim="createForm.notes" placeholder="Observaciones opcionales…"></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="salas.creating" @click="showCreate = false; resetCreate()">Cancelar</button>
            <button class="btn btn-primary" :disabled="salas.creating" @click="submitCreate">
              <span v-if="salas.creating" class="spinner-border spinner-border-sm me-2"></span>
              Crear sala
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="showCreate = false; resetCreate()"></div>

    <!-- ===== MODAL Editar ===== -->
    <div
      class="modal fade"
      :class="{ show: showEdit }"
      :style="{ display: showEdit ? 'block' : 'none' }"
      tabindex="-1" role="dialog" aria-modal="true"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Editar sala</h5>
            <button type="button" class="btn-close" @click="showEdit = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.updateError" class="alert alert-danger">{{ salas.updateError }}</div>

            <div class="mb-3">
              <label class="form-label">Nombre <span class="text-danger">*</span></label>
              <input
                type="text" class="form-control"
                v-model.trim="editForm.nombre"
                :class="{ 'is-invalid': editErrors.nombre }"
              />
              <div class="invalid-feedback">{{ editErrors.nombre }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Estado</label>
              <select class="form-select" v-model="editForm.state" :class="{ 'is-invalid': editErrors.state }">
                <option value="activa">Activa</option>
                <option value="mantenimiento">Mantenimiento</option>
                <option value="cerrada">Cerrada</option>
              </select>
              <div class="invalid-feedback">{{ editErrors.state }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Capacidad (plantas)</label>
              <input
                type="number" min="0" max="1000" step="1" class="form-control"
                v-model.number="editForm.pots_count"
                :class="{ 'is-invalid': editErrors.pots_count }"
              />
              <div class="invalid-feedback">{{ editErrors.pots_count }}</div>
            </div>

            <div class="mb-2">
              <label class="form-label">Notas</label>
              <textarea class="form-control" rows="3" v-model.trim="editForm.notes"></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="salas.updating" @click="showEdit = false">Cancelar</button>
            <button class="btn btn-primary" :disabled="salas.updating" @click="submitEdit">
              <span v-if="salas.updating" class="spinner-border spinner-border-sm me-2"></span>
              Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showEdit }" v-if="showEdit" @click="showEdit = false"></div>

    <!-- ===== MODAL Eliminar ===== -->
    <div
      class="modal fade"
      :class="{ show: showDelete }"
      :style="{ display: showDelete ? 'block' : 'none' }"
      tabindex="-1" role="dialog" aria-modal="true"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Eliminar sala</h5>
            <button type="button" class="btn-close" @click="showDelete = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.removeError" class="alert alert-danger">{{ salas.removeError }}</div>
            <p>
              ¿Seguro que querés eliminar <strong>{{ toDelete?.nombre }}</strong>?
              Esta acción no se puede deshacer.
            </p>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="salas.removing" @click="showDelete = false">Cancelar</button>
            <button class="btn btn-danger" :disabled="salas.removing" @click="doDelete">
              <span v-if="salas.removing" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showDelete }" v-if="showDelete" @click="showDelete = false"></div>

  </div>
</template>

<style scoped>
.modal { background: rgba(0, 0, 0, 0.01); }
</style>


