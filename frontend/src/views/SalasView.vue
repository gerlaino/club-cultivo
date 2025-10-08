<script setup>
import { onMounted, ref } from "vue";
import { useSalasStore } from "../stores/salas";
import { useRouter, RouterLink } from "vue-router";

const store = useSalasStore();
const router = useRouter();

const modalEl = ref(null);
let modal; // instancia de bootstrap.Modal
const form = ref({ name: "", state: "activa", pots_count: 0, notes: "" });
const saving = ref(false);

onMounted(async () => {
  await store.load();
  // inicializa el modal de Bootstrap (asumiendo que ya cargaste bootstrap.bundle.js en index.html)
  if (window.bootstrap && modalEl.value) {
    modal = new window.bootstrap.Modal(modalEl.value);
  }
});

function openModal() {
  form.value = { name: "", state: "activa", pots_count: 0, notes: "" };
  modal?.show();
}

async function submit() {
  try {
    saving.value = true;
    await store.create(form.value);
    modal?.hide();
  } finally {
    saving.value = false;
  }
}

function stateBadge(state) {
  if (state === "activa") return "text-bg-success";
  if (state === "mantenimiento") return "text-bg-warning";
  return "text-bg-secondary";
}
</script>

<template>
  <div class="container py-3">
    <div class="d-flex justify-content-between align-items-center mb-3">
      <h1 class="h4 m-0">Salas</h1>
      <button class="btn btn-primary" @click="openModal">
        <i class="bi bi-plus-lg me-1"></i> Nueva sala
      </button>
    </div>

    <div v-if="store.loading" class="text-muted">Cargando...</div>
    <div v-else-if="store.error" class="alert alert-danger">{{ store.error }}</div>

    <div v-else class="row g-3">
      <div v-for="s in store.items" :key="s.id" class="col-12 col-md-6 col-xl-4">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-body d-flex flex-column">
            <div class="d-flex justify-content-between align-items-start mb-2">
              <RouterLink :to="`/salas/${s.id}`" class="h5 m-0 text-decoration-none">
                {{ s.name }}
              </RouterLink>
              <span class="badge" :class="stateBadge(s.state)">{{ s.state }}</span>
            </div>

            <div class="text-muted small mb-3">ID #{{ s.id }}</div>

            <div class="row g-2 mb-3">
              <div class="col-6">
                <div class="border rounded p-2 h-100">
                  <div class="text-muted small">Macetas</div>
                  <div class="fw-semibold">{{ s.pots_count ?? 0 }}</div>
                </div>
              </div>
              <div class="col-6">
                <div class="border rounded p-2 h-100">
                  <div class="text-muted small">Temp</div>
                  <div class="fw-semibold">N/A</div>
                </div>
              </div>
              <div class="col-6">
                <div class="border rounded p-2 h-100">
                  <div class="text-muted small">Humedad</div>
                  <div class="fw-semibold">N/A</div>
                </div>
              </div>
              <div class="col-6">
                <div class="border rounded p-2 h-100">
                  <div class="text-muted small">Ciclo</div>
                  <div class="fw-semibold">N/A</div>
                </div>
              </div>
            </div>

            <div class="mt-auto d-flex gap-2">
              <RouterLink class="btn btn-sm btn-primary" :to="`/salas/${s.id}`">
                Abrir
              </RouterLink>
              <!-- Podremos agregar editar/eliminar acá más adelante -->
            </div>
          </div>
        </div>
      </div>

      <div v-if="store.items.length === 0" class="col-12">
        <div class="alert alert-light border">No hay salas aún.</div>
      </div>
    </div>

    <!-- Modal Nueva Sala -->
    <div class="modal fade" tabindex="-1" ref="modalEl">
      <div class="modal-dialog">
        <form class="modal-content" @submit.prevent="submit">
          <div class="modal-header">
            <h5 class="modal-title">Nueva sala</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
          </div>
          <div class="modal-body d-grid gap-3">
            <div>
              <label class="form-label">Nombre</label>
              <input v-model="form.name" type="text" class="form-control" required />
            </div>
            <div>
              <label class="form-label">Estado</label>
              <select v-model="form.state" class="form-select">
                <option value="activa">Activa</option>
                <option value="mantenimiento">Mantenimiento</option>
                <option value="inactiva">Inactiva</option>
              </select>
            </div>
            <div>
              <label class="form-label">Macetas</label>
              <input v-model.number="form.pots_count" type="number" min="0" class="form-control" />
            </div>
            <div>
              <label class="form-label">Notas</label>
              <textarea v-model="form.notes" rows="3" class="form-control" />
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-light" type="button" data-bs-dismiss="modal">Cancelar</button>
            <button class="btn btn-primary" :disabled="saving">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              Crear sala
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<style scoped>
.card { transition: transform .15s ease; }
.card:hover { transform: translateY(-2px); }
</style>


