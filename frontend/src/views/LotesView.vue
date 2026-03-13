<script setup>
import { ref, computed, watch, onMounted } from "vue";
import { useLotesStore } from "../stores/lotes";
import { useSalasStore } from "../stores/salas";

// Campos reales DB Lotes:
// codigo, estado, plants_count, start_date, strain, notes, grow_type, light_type, sala_id
//
// Valores permitidos por el modelo:
// estado:     planificacion | vegetativo | floracion | secado | cosechado | finalizado
// grow_type:  sustrato | hidroponia | aeroponia
// light_type: led | hps | cmh | natural | mixta

const store = useLotesStore();
const salas = useSalasStore();

onMounted(() => {
  store.fetch();
  if (!salas.items.length) salas.fetch();
});

// ---------- helpers ----------
const ESTADOS = ["planificacion","vegetativo","floracion","secado","cosechado","finalizado"];

function estadoBadgeColor(estado) {
  switch (estado) {
    case "planificacion": return "info";
    case "vegetativo":    return "success";
    case "floracion":     return "warning";
    case "secado":        return "secondary";
    case "cosechado":     return "primary";
    case "finalizado":    return "dark";
    default:              return "secondary";
  }
}

function estadoLabel(estado) {
  const map = {
    planificacion: "Planificación",
    vegetativo:    "Vegetativo",
    floracion:     "Floración",
    secado:        "Secado",
    cosechado:     "Cosechado",
    finalizado:    "Finalizado",
  };
  return map[estado] || estado || "—";
}

function growTypeLabel(t) {
  const map = { sustrato: "Sustrato", hidroponia: "Hidroponia", aeroponia: "Aeroponia" };
  return map[t] || t || "—";
}

function lightTypeLabel(t) {
  const map = { led: "LED", hps: "HPS", cmh: "CMH", natural: "Natural", mixta: "Mixta" };
  return map[t] || t || "—";
}

function diasDesdeInicio(start_date) {
  if (!start_date) return null;
  return Math.floor((Date.now() - new Date(start_date).getTime()) / 86_400_000);
}

function salaName(sala_id) {
  const s = salas.items.find(s => String(s.id) === String(sala_id));
  return s?.nombre || `Sala #${sala_id}`;
}

// ---------- Filtros / Orden ----------
const q            = ref("");
const filterEstado = ref("");
const sortBy       = ref("fecha_desc");

// ---------- Paginación ----------
const page    = ref(1);
const perPage = ref(6);

const filtered = computed(() => {
  const query = q.value.trim().toLowerCase();
  return store.items.filter(l => {
    const matchesText =
      !query ||
      (l.codigo || "").toLowerCase().includes(query) ||
      (l.strain  || "").toLowerCase().includes(query) ||
      (l.notes   || "").toLowerCase().includes(query);
    const matchesEstado = !filterEstado.value || l.estado === filterEstado.value;
    return matchesText && matchesEstado;
  });
});

const sorted = computed(() => {
  const arr = [...filtered.value];
  arr.sort((a, b) => {
    const codigoA = (a.codigo || "").toLocaleLowerCase();
    const codigoB = (b.codigo || "").toLocaleLowerCase();
    const fechaA  = new Date(a.start_date || a.created_at || 0).getTime();
    const fechaB  = new Date(b.start_date || b.created_at || 0).getTime();
    const planA   = Number(a.plants_count ?? 0);
    const planB   = Number(b.plants_count ?? 0);
    switch (sortBy.value) {
      case "codigo_asc":   return codigoA > codigoB ? 1 : -1;
      case "codigo_desc":  return codigoA < codigoB ? 1 : -1;
      case "fecha_asc":    return fechaA - fechaB;
      case "plantas_desc": return planB - planA;
      case "plantas_asc":  return planA - planB;
      case "fecha_desc":
      default:             return fechaB - fechaA;
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

// ---------- Form base ----------
function emptyForm() {
  return {
    codigo:       "",
    estado:       "vegetativo",
    plants_count: 0,
    start_date:   new Date().toISOString().slice(0, 10),
    strain:       "",
    grow_type:    "sustrato",
    light_type:   "",
    notes:        "",
    sala_id:      salas.items[0]?.id ?? "",
  };
}

// ---------- Modal Crear ----------
const showCreate   = ref(false);
const createForm   = ref(emptyForm());
const createErrors = ref({});

function resetCreate() {
  createForm.value   = emptyForm();
  createErrors.value = {};
}

function validateForm(form) {
  const e = {};
  if (!form.codigo?.trim())          e.codigo = "El código es obligatorio";
  if (!ESTADOS.includes(form.estado)) e.estado = "Estado inválido";
  const n = Number(form.plants_count);
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser un entero 0–5000";
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
    resetCreate();
  } catch { /* store ya setea createError */ }
}

// ---------- Modal Editar ----------
const showEdit   = ref(false);
const editForm   = ref({ id: null, ...emptyForm() });
const editErrors = ref({});

function startEdit(l) {
  editForm.value = {
    id:           l.id,
    codigo:       l.codigo       || "",
    estado:       l.estado       || "vegetativo",
    plants_count: l.plants_count ?? 0,
    start_date:   l.start_date   ? l.start_date.slice(0, 10) : new Date().toISOString().slice(0, 10),
    strain:       l.strain       || "",
    grow_type:    l.grow_type    || "sustrato",
    light_type:   l.light_type   || "",
    notes:        l.notes        || "",
    sala_id:      l.sala_id      || "",
  };
  editErrors.value = {};
  showEdit.value   = true;
}

async function submitEdit() {
  const e = validateForm(editForm.value);
  editErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    const { id, sala_id, ...payload } = editForm.value;
    await store.update(id, payload, sala_id);
    showEdit.value = false;
  } catch { /* store ya setea updateError */ }
}

// ---------- Confirmación Eliminar ----------
const showDelete = ref(false);
const toDelete   = ref(null);
function confirmDelete(l) { toDelete.value = l; showDelete.value = true; }
async function doDelete() {
  if (!toDelete.value) return;
  try {
    await store.remove(toDelete.value.id, toDelete.value.sala_id);
    showDelete.value = false;
    toDelete.value   = null;
  } catch { /* store ya setea removeError */ }
}
</script>

<template>
  <div class="container py-4">

    <div class="d-flex justify-content-between align-items-center mb-3">
      <h2 class="m-0">Lotes</h2>
      <button class="btn btn-success" @click="showCreate = true">+ Nuevo lote</button>
    </div>

    <!-- Toolbar -->
    <div class="card mb-3">
      <div class="card-body">
        <div class="row g-2 align-items-end">
          <div class="col-12 col-md-4">
            <label class="form-label">Buscar</label>
            <input type="search" class="form-control" placeholder="Código, strain, notas…" v-model.trim="q" />
          </div>
          <div class="col-6 col-md-3">
            <label class="form-label">Estado</label>
            <select class="form-select" v-model="filterEstado">
              <option value="">Todos</option>
              <option value="planificacion">Planificación</option>
              <option value="vegetativo">Vegetativo</option>
              <option value="floracion">Floración</option>
              <option value="secado">Secado</option>
              <option value="cosechado">Cosechado</option>
              <option value="finalizado">Finalizado</option>
            </select>
          </div>
          <div class="col-6 col-md-3">
            <label class="form-label">Ordenar por</label>
            <select class="form-select" v-model="sortBy">
              <option value="fecha_desc">Más recientes</option>
              <option value="fecha_asc">Más antiguos</option>
              <option value="codigo_asc">Código (A→Z)</option>
              <option value="codigo_desc">Código (Z→A)</option>
              <option value="plantas_desc">Plantas (mayor→menor)</option>
              <option value="plantas_asc">Plantas (menor→mayor)</option>
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
          Mostrando {{ paginated.length }} de {{ totalItems }} lote(s)
        </div>
      </div>
    </div>

    <div v-if="store.loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="store.error" class="alert alert-danger">{{ store.error }}</div>
    <div v-else-if="!store.items.length" class="alert alert-secondary">No hay lotes todavía.</div>

    <div v-else>
      <div v-if="!paginated.length" class="alert alert-warning">
        No se encontraron lotes con los filtros actuales.
      </div>

      <div class="row g-3">
        <div v-for="l in paginated" :key="l.id" class="col-12 col-sm-6 col-lg-4">
          <div class="card h-100 shadow-sm">
            <div class="card-body d-flex flex-column gap-2">

              <div class="d-flex justify-content-between align-items-start">
                <h5 class="card-title mb-0 fw-bold text-truncate" :title="l.codigo">{{ l.codigo }}</h5>
                <span class="badge flex-shrink-0 ms-2" :class="`text-bg-${estadoBadgeColor(l.estado)}`">
                  {{ estadoLabel(l.estado) }}
                </span>
              </div>

              <p v-if="l.strain" class="small text-muted mb-0">🌿 <em>{{ l.strain }}</em></p>

              <div class="d-flex flex-wrap gap-3 small">
                <span>🪴 <strong>{{ l.plants_count ?? 0 }}</strong> plantas</span>
                <span>📍 {{ salaName(l.sala_id) }}</span>
                <span v-if="l.grow_type">⚗️ {{ growTypeLabel(l.grow_type) }}</span>
                <span v-if="l.light_type">💡 {{ lightTypeLabel(l.light_type) }}</span>
              </div>

              <div v-if="diasDesdeInicio(l.start_date) !== null" class="small text-muted">
                📅 Día <strong>{{ diasDesdeInicio(l.start_date) }}</strong>
                <span class="text-muted"> · inicio {{ l.start_date }}</span>
              </div>

              <p class="small text-muted flex-grow-1 mb-0">{{ l.notes || "Sin notas." }}</p>

              <div class="d-flex gap-2 mt-auto pt-2 border-top">
                <RouterLink
                  class="btn btn-sm btn-outline-primary flex-fill"
                  :to="{ name: 'lote-detail', params: { id: l.id } }"
                >
                  Ver
                </RouterLink>
                <button
                  class="btn btn-sm btn-outline-secondary flex-fill"
                  @click="startEdit(l)"
                  :disabled="store.updating && editForm.id === l.id"
                >
                  <span v-if="store.updating && editForm.id === l.id" class="spinner-border spinner-border-sm me-1"></span>
                  Editar
                </button>
                <button
                  class="btn btn-sm btn-outline-danger"
                  @click="confirmDelete(l)"
                  :disabled="store.removing && toDelete?.id === l.id"
                >
                  <span v-if="store.removing && toDelete?.id === l.id" class="spinner-border spinner-border-sm"></span>
                  <span v-else>✕</span>
                </button>
              </div>

            </div>
          </div>
        </div>
      </div>

      <nav class="mt-3" aria-label="Paginación">
        <ul class="pagination mb-0">
          <li class="page-item" :class="{ disabled: page <= 1 }">
            <button class="page-link" @click="page = Math.max(1, page - 1)">Anterior</button>
          </li>
          <li v-for="p in totalPages" :key="p" class="page-item" :class="{ active: p === page }">
            <button class="page-link" @click="page = p">{{ p }}</button>
          </li>
          <li class="page-item" :class="{ disabled: page >= totalPages }">
            <button class="page-link" @click="page = Math.min(totalPages, page + 1)">Siguiente</button>
          </li>
        </ul>
      </nav>
    </div>

    <!-- ===== MODAL Crear ===== -->
    <div class="modal fade" :class="{ show: showCreate }" :style="{ display: showCreate ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nuevo lote</h5>
            <button type="button" class="btn-close" @click="showCreate = false; resetCreate()"></button>
          </div>
          <div class="modal-body">
            <div v-if="store.createError" class="alert alert-danger">{{ store.createError }}</div>
            <div class="row g-3">

              <div class="col-12 col-md-6">
                <label class="form-label">Código <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="createForm.codigo"
                       :class="{ 'is-invalid': createErrors.codigo }" placeholder="Ej: LOT-2026-001" />
                <div class="invalid-feedback">{{ createErrors.codigo }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Sala <span class="text-danger">*</span></label>
                <select class="form-select" v-model="createForm.sala_id" :class="{ 'is-invalid': createErrors.sala_id }">
                  <option value="" disabled>Seleccioná una sala…</option>
                  <option v-for="s in salas.items" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
                <div class="invalid-feedback">{{ createErrors.sala_id }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="createForm.estado" :class="{ 'is-invalid': createErrors.estado }">
                  <option value="planificacion">Planificación</option>
                  <option value="vegetativo">Vegetativo</option>
                  <option value="floracion">Floración</option>
                  <option value="secado">Secado</option>
                  <option value="cosechado">Cosechado</option>
                  <option value="finalizado">Finalizado</option>
                </select>
                <div class="invalid-feedback">{{ createErrors.estado }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" step="1" class="form-control"
                       v-model.number="createForm.plants_count" :class="{ 'is-invalid': createErrors.plants_count }" />
                <div class="invalid-feedback">{{ createErrors.plants_count }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Fecha de inicio</label>
                <input type="date" class="form-control" v-model="createForm.start_date" />
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Strain / Variedad</label>
                <input type="text" class="form-control" v-model.trim="createForm.strain" placeholder="Ej: OG Kush" />
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Tipo de cultivo</label>
                <select class="form-select" v-model="createForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>

              <div class="col-12 col-md-6">
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
                <textarea class="form-control" rows="2" v-model.trim="createForm.notes" placeholder="Observaciones opcionales…"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="store.creating" @click="showCreate = false; resetCreate()">Cancelar</button>
            <button class="btn btn-success" :disabled="store.creating" @click="submitCreate">
              <span v-if="store.creating" class="spinner-border spinner-border-sm me-2"></span>
              Crear lote
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="showCreate = false; resetCreate()"></div>

    <!-- ===== MODAL Editar ===== -->
    <div class="modal fade" :class="{ show: showEdit }" :style="{ display: showEdit ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Editar lote <span class="text-muted fw-normal">{{ editForm.codigo }}</span></h5>
            <button type="button" class="btn-close" @click="showEdit = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="store.updateError" class="alert alert-danger">{{ store.updateError }}</div>
            <div class="row g-3">

              <div class="col-12 col-md-6">
                <label class="form-label">Código <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="editForm.codigo"
                       :class="{ 'is-invalid': editErrors.codigo }" />
                <div class="invalid-feedback">{{ editErrors.codigo }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Sala</label>
                <select class="form-select" v-model="editForm.sala_id">
                  <option v-for="s in salas.items" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="editForm.estado" :class="{ 'is-invalid': editErrors.estado }">
                  <option value="planificacion">Planificación</option>
                  <option value="vegetativo">Vegetativo</option>
                  <option value="floracion">Floración</option>
                  <option value="secado">Secado</option>
                  <option value="cosechado">Cosechado</option>
                  <option value="finalizado">Finalizado</option>
                </select>
                <div class="invalid-feedback">{{ editErrors.estado }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" step="1" class="form-control"
                       v-model.number="editForm.plants_count" :class="{ 'is-invalid': editErrors.plants_count }" />
                <div class="invalid-feedback">{{ editErrors.plants_count }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Fecha de inicio</label>
                <input type="date" class="form-control" v-model="editForm.start_date" />
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Strain / Variedad</label>
                <input type="text" class="form-control" v-model.trim="editForm.strain" />
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Tipo de cultivo</label>
                <select class="form-select" v-model="editForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>

              <div class="col-12 col-md-6">
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
            <button class="btn btn-outline-secondary" :disabled="store.updating" @click="showEdit = false">Cancelar</button>
            <button class="btn btn-primary" :disabled="store.updating" @click="submitEdit">
              <span v-if="store.updating" class="spinner-border spinner-border-sm me-2"></span>
              Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showEdit }" v-if="showEdit" @click="showEdit = false"></div>

    <!-- ===== MODAL Eliminar ===== -->
    <div class="modal fade" :class="{ show: showDelete }" :style="{ display: showDelete ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Eliminar lote</h5>
            <button type="button" class="btn-close" @click="showDelete = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="store.removeError" class="alert alert-danger">{{ store.removeError }}</div>
            <p>¿Seguro que querés eliminar el lote <strong>{{ toDelete?.codigo }}</strong>? Esta acción no se puede deshacer.</p>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="store.removing" @click="showDelete = false">Cancelar</button>
            <button class="btn btn-danger" :disabled="store.removing" @click="doDelete">
              <span v-if="store.removing" class="spinner-border spinner-border-sm me-2"></span>
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
.modal { background: rgba(0,0,0,0.01); }
</style>


