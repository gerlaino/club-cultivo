<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useSalasStore } from "../stores/salas";
import { useLotesStore } from "../stores/lotes";

const route  = useRoute();
const router = useRouter();
const salas  = useSalasStore();
const lotes  = useLotesStore();
const salaId = Number(route.params.id);

const loading = ref(true);
const error   = ref(null);

// Valores permitidos por el modelo Lote (backend):
// estado:     planificacion | vegetativo | floracion | secado | cosechado | finalizado
// grow_type:  sustrato | hidroponia | aeroponia
// light_type: led | hps | cmh | natural | mixta

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
  };
}

const showCreate = ref(false);
const form       = ref(emptyForm());
const formErrors = ref({});

onMounted(async () => {
  try {
    await salas.fetchSala(salaId);
    await lotes.fetchBySala(salaId);
  } catch (e) {
    error.value = "No se pudo cargar la sala.";
  } finally {
    loading.value = false;
  }
});

const sala  = computed(() => salas.currentSala);
const items = computed(() => lotes.bySala(salaId));

const totalPlantas = computed(() =>
  items.value.reduce((acc, l) => acc + Number(l.plants_count || 0), 0)
);

const ESTADOS_LOTE = ["planificacion","vegetativo","floracion","secado","cosechado","finalizado"];

function estadoLabel(e) {
  const map = {
    planificacion: "Planificación",
    vegetativo:    "Vegetativo",
    floracion:     "Floración",
    secado:        "Secado",
    cosechado:     "Cosechado",
    finalizado:    "Finalizado",
  };
  return map[e] || e || "—";
}

function estadoBadge(e) {
  switch (e) {
    case "planificacion": return "info";
    case "vegetativo":    return "success";
    case "floracion":     return "warning";
    case "secado":        return "secondary";
    case "cosechado":     return "primary";
    case "finalizado":    return "dark";
    default:              return "secondary";
  }
}

function salaBadge(state) {
  switch (state) {
    case "activa":        return "success";
    case "mantenimiento": return "warning";
    case "cerrada":       return "secondary";
    default:              return "secondary";
  }
}

function validateForm() {
  const e = {};
  if (!form.value.codigo?.trim()) e.codigo = "El código es obligatorio";
  if (!ESTADOS_LOTE.includes(form.value.estado)) e.estado = "Estado inválido";
  const n = Number(form.value.plants_count);
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser un entero 0–5000";
  formErrors.value = e;
  return Object.keys(e).length === 0;
}

async function createLote() {
  if (!validateForm()) return;
  try {
    await lotes.createInSala(salaId, { ...form.value });
    closeCreate();
  } catch { /* store ya setea createError */ }
}

function closeCreate() {
  showCreate.value = false;
  form.value       = emptyForm();
  formErrors.value = {};
}
</script>

<template>
  <div class="container py-4">
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-outline-secondary btn-sm" @click="router.back()">← Volver</button>
        <h2 class="m-0">{{ sala?.nombre || "Sala" }}</h2>
        <span v-if="sala" class="badge text-capitalize" :class="`text-bg-${salaBadge(sala.state)}`">
          {{ sala.state }}
        </span>
      </div>
      <div class="text-muted small">
        <div v-if="sala?.updated_at">Actualizado: {{ new Date(sala.updated_at).toLocaleString() }}</div>
        <div v-else-if="sala?.created_at">Creado: {{ new Date(sala.created_at).toLocaleString() }}</div>
      </div>
    </div>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!sala" class="alert alert-warning">Sala no encontrada.</div>

    <div v-else class="row g-3">
      <!-- Col izquierda -->
      <div class="col-12 col-lg-8">

        <!-- KPIs -->
        <div class="row g-3">
          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Plantas activas</div>
                <div class="display-6 fw-bold">{{ totalPlantas }}</div>
              </div>
            </div>
          </div>
          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Capacidad (plantas)</div>
                <div class="display-6 fw-bold">{{ sala.pots_count ?? 0 }}</div>
              </div>
            </div>
          </div>
          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Lotes activos</div>
                <div class="display-6 fw-bold">{{ items.length }}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Cámara -->
        <div class="card mt-3">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Cámara</strong>
            <span class="badge text-bg-secondary">placeholder</span>
          </div>
          <div class="card-body">
            <div class="ratio ratio-16x9 bg-dark rounded d-flex align-items-center justify-content-center text-white">
              <div class="text-center">
                <div class="mb-2">Stream no configurado</div>
                <small class="text-white-50">Cuando integremos Home Assistant aparecerá aquí.</small>
              </div>
            </div>
          </div>
        </div>

        <!-- Lotes -->
        <div class="card mt-3">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Lotes</strong>
            <button class="btn btn-sm btn-primary" @click="showCreate = true">+ Agregar lote</button>
          </div>
          <div class="card-body">
            <div v-if="lotes.loading" class="text-muted">Cargando lotes…</div>
            <div v-else-if="lotes.error" class="alert alert-danger">{{ lotes.error }}</div>
            <div v-else-if="!items.length" class="text-muted">Esta sala no tiene lotes todavía.</div>

            <ul v-else class="list-group list-group-flush">
              <li
                v-for="l in items" :key="l.id"
                class="list-group-item d-flex justify-content-between align-items-center px-0"
              >
                <div class="d-flex align-items-center gap-2 flex-wrap">
                  <strong>{{ l.codigo || `Lote #${l.id}` }}</strong>
                  <span class="badge" :class="`text-bg-${estadoBadge(l.estado)}`">
                    {{ estadoLabel(l.estado) }}
                  </span>
                  <span class="text-muted small">{{ l.plants_count ?? 0 }} plantas</span>
                  <span v-if="l.strain" class="text-muted small">· {{ l.strain }}</span>
                  <span v-if="l.start_date" class="text-muted small">· {{ l.start_date }}</span>
                </div>
                <RouterLink
                  class="btn btn-sm btn-outline-primary flex-shrink-0"
                  :to="{ name: 'lote-detail', params: { id: l.id } }"
                >
                  Ver
                </RouterLink>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Col derecha -->
      <div class="col-12 col-lg-4">
        <div class="card">
          <div class="card-header"><strong>Información</strong></div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">ID</span><span>{{ sala.id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Estado</span>
              <span class="text-capitalize">{{ sala.state }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Notas</span>
              <span class="text-end" style="max-width:60%">{{ sala.notes || "—" }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Creado</span>
              <span>{{ new Date(sala.created_at).toLocaleString() }}</span>
            </div>
            <div class="d-flex justify-content-between py-1">
              <span class="text-muted">Actualizado</span>
              <span>{{ new Date(sala.updated_at).toLocaleString() }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== MODAL Crear Lote ===== -->
    <div
      class="modal fade"
      :class="{ show: showCreate }"
      :style="{ display: showCreate ? 'block' : 'none' }"
      tabindex="-1" role="dialog" aria-modal="true"
    >
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nuevo lote — {{ sala?.nombre }}</h5>
            <button type="button" class="btn-close" @click="closeCreate"></button>
          </div>
          <div class="modal-body">
            <div v-if="lotes.createError" class="alert alert-danger">{{ lotes.createError }}</div>

            <div class="row g-3">
              <div class="col-12 col-md-6">
                <label class="form-label">Código <span class="text-danger">*</span></label>
                <input
                  type="text" class="form-control"
                  v-model.trim="form.codigo"
                  :class="{ 'is-invalid': formErrors.codigo }"
                  placeholder="Ej: LOT-2026-001"
                />
                <div class="invalid-feedback">{{ formErrors.codigo }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="form.estado" :class="{ 'is-invalid': formErrors.estado }">
                  <option value="planificacion">Planificación</option>
                  <option value="vegetativo">Vegetativo</option>
                  <option value="floracion">Floración</option>
                  <option value="secado">Secado</option>
                  <option value="cosechado">Cosechado</option>
                  <option value="finalizado">Finalizado</option>
                </select>
                <div class="invalid-feedback">{{ formErrors.estado }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Cantidad de plantas</label>
                <input
                  type="number" min="0" max="5000" step="1" class="form-control"
                  v-model.number="form.plants_count"
                  :class="{ 'is-invalid': formErrors.plants_count }"
                />
                <div class="invalid-feedback">{{ formErrors.plants_count }}</div>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Fecha de inicio</label>
                <input type="date" class="form-control" v-model="form.start_date" />
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Strain / Variedad</label>
                <input type="text" class="form-control" v-model.trim="form.strain" placeholder="Ej: OG Kush" />
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Tipo de cultivo</label>
                <select class="form-select" v-model="form.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>

              <div class="col-12 col-md-6">
                <label class="form-label">Tipo de luz</label>
                <select class="form-select" v-model="form.light_type">
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
                <textarea class="form-control" rows="2" v-model.trim="form.notes" placeholder="Observaciones opcionales…"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="lotes.creating" @click="closeCreate">Cancelar</button>
            <button class="btn btn-primary" :disabled="lotes.creating" @click="createLote">
              <span v-if="lotes.creating" class="spinner-border spinner-border-sm me-2"></span>
              Crear lote
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="closeCreate"></div>

  </div>
</template>

<style scoped>
.modal { background: rgba(0,0,0,0.01); }
</style>
