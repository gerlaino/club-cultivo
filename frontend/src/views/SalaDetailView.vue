<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useSalasStore } from "../stores/salas";
import { useLotesStore } from "../stores/lotes";

const route = useRoute();
const router = useRouter();

const salas = useSalasStore();
const lotes = useLotesStore();

const salaId = Number(route.params.id);

const loading = ref(true);
const error = ref(null);

// UI: modal crear lote
const showCreate = ref(false);
const form = ref({
  grow_type: "sustrato",
  plants_count: 0,
  strain: "",
  start_date: new Date().toISOString().slice(0,10),
  notes: "",
});

onMounted(async () => {
  try {
    // Cargamos detalle + lotes por sala
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

// KPI plantas: suma de plants_count de los lotes
const totalPlantas = computed(() =>
  items.value.reduce((acc, l) => acc + Number(l.plants_count || 0), 0)
);

function badge(state) {
  switch (state) {
    case "activa": return "success";
    case "mantenimiento": return "warning";
    case "cerrada": return "secondary";
    default: return "secondary";
  }
}

async function createLote() {
  try {
    await lotes.createInSala(salaId, { ...form.value });
    showCreate.value = false;
    form.value = {
      grow_type: "sustrato",
      plants_count: 0,
      strain: "",
      start_date: new Date().toISOString().slice(0,10),
      notes: "",
    };
  } catch (e) {
    // el store ya setea error
  }
}
</script>

<template>
  <div class="container py-4">
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-outline-secondary btn-sm" @click="router.back()">← Volver</button>
        <h2 class="m-0">{{ sala?.name || "Sala" }}</h2>
        <span v-if="sala" class="badge text-capitalize" :class="`text-bg-${badge(sala.state)}`">
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
      <!-- Col izquierda: KPIs + Cámara + Lotes -->
      <div class="col-12 col-lg-8">

        <!-- KPIs -->
        <div class="row g-3">
          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Plantas</div>
                <div class="display-6 fw-bold">{{ totalPlantas }}</div>
              </div>
            </div>
          </div>

          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Capacidad de la sala (plantas)</div>
                <div class="display-6 fw-bold">{{ sala.pots_count ?? 0 }}</div>
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
            <button class="btn btn-sm btn-primary" @click="showCreate = true">Agregar lote</button>
          </div>
          <div class="card-body">
            <div v-if="lotes.loading" class="alert alert-info">Cargando lotes…</div>
            <div v-else-if="lotes.error" class="alert alert-danger">{{ lotes.error }}</div>
            <div v-else-if="!items.length" class="text-muted">Esta sala no tiene lotes.</div>

            <ul v-else class="list-group">
              <li v-for="l in items" :key="l.id" class="list-group-item d-flex justify-content-between align-items-center">
                <div>
                  <strong>Lote #{{ l.id }}</strong>
                  <span class="text-muted ms-2">Plantas: {{ l.plants_count ?? 0 }}</span>
                  <span class="text-muted ms-2">Genética: {{ l.strain || "—" }}</span>
                  <span class="text-muted ms-2">Inicio: {{ l.start_date }}</span>
                </div>
                <RouterLink class="btn btn-sm btn-outline-primary" :to="{ name: 'lote-detail', params: { id: l.id } }">
                  Ver
                </RouterLink>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Col derecha: Info -->
      <div class="col-12 col-lg-4">
        <div class="card">
          <div class="card-header"><strong>Información</strong></div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">ID</span><span>{{ sala.id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Estado</span><span class="text-capitalize">{{ sala.state }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Creado</span><span>{{ new Date(sala.created_at).toLocaleString() }}</span>
            </div>
            <div class="d-flex justify-content-between py-1">
              <span class="text-muted">Actualizado</span><span>{{ new Date(sala.updated_at).toLocaleString() }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Crear Lote -->
    <div class="modal fade" :class="{ show: showCreate }" :style="{ display: showCreate ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nuevo lote</h5>
            <button type="button" class="btn-close" @click="showCreate = false" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div v-if="lotes.error" class="alert alert-danger">{{ lotes.error }}</div>

            <div class="mb-2">
              <label class="form-label">Tipo cultivo</label>
              <select class="form-select" v-model="form.grow_type">
                <option value="sustrato">Sustrato</option>
                <option value="hidroponia">Hidroponia</option>
              </select>
            </div>

            <div class="mb-2">
              <label class="form-label">Cantidad de plantas</label>
              <input type="number" class="form-control" min="0" step="1" v-model.number="form.plants_count" />
            </div>

            <div class="mb-2">
              <label class="form-label">Genética</label>
              <input type="text" class="form-control" v-model.trim="form.strain" />
            </div>

            <div class="mb-2">
              <label class="form-label">Fecha de inicio</label>
              <input type="date" class="form-control" v-model="form.start_date" />
            </div>

            <div class="mb-2">
              <label class="form-label">Notas</label>
              <textarea class="form-control" rows="3" v-model.trim="form.notes"></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="lotes.creating" @click="showCreate = false">Cancelar</button>
            <button class="btn btn-primary" :disabled="lotes.creating" @click="createLote">
              <span v-if="lotes.creating" class="spinner-border spinner-border-sm me-2"></span>
              Crear
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="showCreate=false"></div>
  </div>
</template>

<style scoped>
.modal { background: rgba(0,0,0,0.01); }
</style>
