<script setup>
import { ref, onMounted, computed } from "vue";
import { useSalasStore } from "../stores/salas";

const salas = useSalasStore();

onMounted(() => {
  if (!salas.items.length) salas.fetch();
});

// ---------- helpers ----------
function stateBadgeColor(state) {
  switch (state) {
    case "activa": return "success";
    case "mantenimiento": return "warning";
    case "cerrada": return "secondary";
    default: return "secondary";
  }
}

// ---------- Modal Crear ----------
const showCreate = ref(false);
const createForm = ref({ name: "", state: "activa", pots_count: 0, notes: "" });
const createErrors = ref({});

function resetCreate() {
  createForm.value = { name: "", state: "activa", pots_count: 0, notes: "" };
  createErrors.value = {};
}
function validateCreate() {
  const e = {};
  if (!createForm.value.name?.trim()) e.name = "El nombre es obligatorio";
  if (!["activa","mantenimiento","cerrada"].includes(createForm.value.state)) e.state = "Estado inválido";
  const n = Number(createForm.value.pots_count);
  if (!Number.isInteger(n) || n < 0 || n > 1000) e.pots_count = "Debe ser un entero 0..1000";
  createErrors.value = e; return Object.keys(e).length === 0;
}
async function submitCreate() {
  if (!validateCreate()) return;
  try {
    await salas.create({ ...createForm.value });
    showCreate.value = false; resetCreate();
  } catch {}
}

// ---------- Modal Editar ----------
const showEdit = ref(false);
const editForm = ref({ id: null, name: "", state: "activa", pots_count: 0, notes: "" });
const editErrors = ref({});

function startEdit(s) {
  editForm.value = { id: s.id, name: s.name || "", state: s.state || "activa", pots_count: s.pots_count ?? 0, notes: s.notes || "" };
  editErrors.value = {};
  showEdit.value = true;
}
function validateEdit() {
  const e = {};
  if (!editForm.value.name?.trim()) e.name = "El nombre es obligatorio";
  if (!["activa","mantenimiento","cerrada"].includes(editForm.value.state)) e.state = "Estado inválido";
  const n = Number(editForm.value.pots_count);
  if (!Number.isInteger(n) || n < 0 || n > 1000) e.pots_count = "Debe ser un entero 0..1000";
  editErrors.value = e; return Object.keys(e).length === 0;
}
async function submitEdit() {
  if (!validateEdit()) return;
  try {
    const { id, ...payload } = editForm.value;
    await salas.update(id, payload);
    showEdit.value = false;
  } catch {}
}

// ---------- Confirmación Eliminar ----------
const showDelete = ref(false);
const toDelete = ref(null);
const deletingName = computed(() => toDelete.value?.name || "");

function confirmDelete(s) {
  toDelete.value = s;
  showDelete.value = true;
}
async function doDelete() {
  if (!toDelete.value) return;
  try {
    await salas.remove(toDelete.value.id);
    showDelete.value = false;
    toDelete.value = null;
  } catch {}
}
</script>

<template>
  <div class="container py-4">
    <div class="d-flex justify-content-between align-items-center mb-3">
      <h2 class="m-0">Salas</h2>
      <button class="btn btn-primary" @click="showCreate = true">Nueva sala</button>
    </div>

    <!-- Estados generales -->
    <div v-if="salas.loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="salas.error" class="alert alert-danger">{{ salas.error }}</div>
    <div v-else-if="!salas.items.length" class="alert alert-secondary">No hay salas todavía.</div>

    <!-- Grid -->
    <div v-else class="row g-3">
      <div v-for="s in salas.items" :key="s.id" class="col-12 col-sm-6 col-lg-4">
        <div class="card h-100 shadow-sm">
          <div class="card-body d-flex flex-column">
            <div class="d-flex justify-content-between align-items-start mb-2">
              <h5 class="card-title mb-0 text-truncate" :title="s.name">{{ s.name }}</h5>
              <span class="badge text-capitalize" :class="`text-bg-${stateBadgeColor(s.state)}`">
                {{ s.state || "—" }}
              </span>
            </div>
            <p class="text-muted mb-2">Macetas: <strong>{{ s.pots_count ?? 0 }}</strong></p>
            <p class="small text-muted flex-grow-1">{{ s.notes || "Sin notas." }}</p>

            <div class="d-flex gap-2 mt-auto">
              <button class="btn btn-outline-primary btn-sm" disabled>Ver</button>
              <button class="btn btn-outline-secondary btn-sm" @click="startEdit(s)">
                <span v-if="salas.updating && editForm.id === s.id" class="spinner-border spinner-border-sm me-1"></span>
                Editar
              </button>
              <button class="btn btn-outline-danger btn-sm ms-auto" @click="confirmDelete(s)">
                <span v-if="salas.removing && toDelete?.id === s.id" class="spinner-border spinner-border-sm me-1"></span>
                Eliminar
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- MODAL Crear -->
    <div class="modal fade" :class="{ show: showCreate }" :style="{ display: showCreate ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nueva sala</h5>
            <button type="button" class="btn-close" @click="showCreate = false" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.createError" class="alert alert-danger">{{ salas.createError }}</div>

            <div class="mb-3">
              <label class="form-label">Nombre</label>
              <input type="text" class="form-control" v-model.trim="createForm.name" :class="{ 'is-invalid': createErrors.name }" />
              <div class="invalid-feedback">{{ createErrors.name }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Estado</label>
              <select class="form-select" v-model="createForm.state" :class="{ 'is-invalid': createErrors.state }">
                <option value="activa">activa</option>
                <option value="mantenimiento">mantenimiento</option>
                <option value="cerrada">cerrada</option>
              </select>
              <div class="invalid-feedback">{{ createErrors.state }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Cantidad de macetas</label>
              <input type="number" min="0" step="1" class="form-control" v-model.number="createForm.pots_count" :class="{ 'is-invalid': createErrors.pots_count }" />
              <div class="invalid-feedback">{{ createErrors.pots_count }}</div>
            </div>

            <div class="mb-2">
              <label class="form-label">Notas</label>
              <textarea class="form-control" rows="3" v-model.trim="createForm.notes"></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="salas.creating" @click="showCreate = false">Cancelar</button>
            <button class="btn btn-primary" :disabled="salas.creating" @click="submitCreate">
              <span v-if="salas.creating" class="spinner-border spinner-border-sm me-2"></span>
              Crear sala
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="showCreate=false"></div>

    <!-- MODAL Editar -->
    <div class="modal fade" :class="{ show: showEdit }" :style="{ display: showEdit ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Editar sala</h5>
            <button type="button" class="btn-close" @click="showEdit = false" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.updateError" class="alert alert-danger">{{ salas.updateError }}</div>

            <div class="mb-3">
              <label class="form-label">Nombre</label>
              <input type="text" class="form-control" v-model.trim="editForm.name" :class="{ 'is-invalid': editErrors.name }" />
              <div class="invalid-feedback">{{ editErrors.name }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Estado</label>
              <select class="form-select" v-model="editForm.state" :class="{ 'is-invalid': editErrors.state }">
                <option value="activa">activa</option>
                <option value="mantenimiento">mantenimiento</option>
                <option value="cerrada">cerrada</option>
              </select>
              <div class="invalid-feedback">{{ editErrors.state }}</div>
            </div>

            <div class="mb-3">
              <label class="form-label">Cantidad de macetas</label>
              <input type="number" min="0" step="1" class="form-control" v-model.number="editForm.pots_count" :class="{ 'is-invalid': editErrors.pots_count }" />
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
    <div class="modal-backdrop fade" :class="{ show: showEdit }" v-if="showEdit" @click="showEdit=false"></div>

    <!-- MODAL Eliminar -->
    <div class="modal fade" :class="{ show: showDelete }" :style="{ display: showDelete ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Eliminar sala</h5>
            <button type="button" class="btn-close" @click="showDelete = false" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div v-if="salas.removeError" class="alert alert-danger">{{ salas.removeError }}</div>
            <p>¿Seguro que querés eliminar <strong>{{ deletingName }}</strong>? Esta acción no se puede deshacer.</p>
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
    <div class="modal-backdrop fade" :class="{ show: showDelete }" v-if="showDelete" @click="showDelete=false"></div>
  </div>
</template>

<style scoped>
.modal { background: rgba(0,0,0,0.01); }
</style>
