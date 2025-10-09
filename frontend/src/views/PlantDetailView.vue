<!-- frontend/src/views/PlantDetailView.vue -->
<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { usePlantsStore } from "../stores/plants";

const route = useRoute();
const router = useRouter();
const plants = usePlantsStore();

const id = Number(route.params.id);
const loading = ref(true);
const error = ref(null);

// notas (edición simple)
const editNotes = ref(false);
const notesDraft = ref("");

// modal crear planta (en el mismo lote que la actual)
const showCreate = ref(false);
const createForm = ref({ strain: "", notes: "" });

onMounted(async () => {
  try {
    await plants.show(id);
  } catch (e) {
    error.value = "No se pudo cargar el lote.";
  } finally {
    loading.value = false;
  }
});

const plant = computed(() => plants.current);
const photo = computed(() => plant.value?.photo_url || "https://placehold.co/800x450?text=Planta");

// acciones
function startEditNotes() {
  notesDraft.value = plant.value?.notes || "";
  editNotes.value = true;
}
async function saveNotes() {
  if (!plant.value) return;
  await plants.update(plant.value.id, { notes: notesDraft.value });
  editNotes.value = false;
}

async function createAnother() {
  if (!plant.value?.lote_id) return;
  await plants.createInLote(plant.value.lote_id, {
    strain: createForm.value.strain?.trim(),
    notes: createForm.value.notes?.trim(),
  });
  showCreate.value = false;
  createForm.value = { strain: "", notes: "" };
}
</script>

<template>
  <div class="container py-4">
    <button class="btn btn-outline-secondary btn-sm mb-3" @click="router.back()">← Volver</button>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!plant" class="alert alert-warning">Planta no encontrada.</div>

    <div v-else class="row g-3">
      <div class="col-12 col-lg-8">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Planta</strong>
            <button class="btn btn-sm btn-primary" @click="showCreate = true">
              Agregar planta
            </button>
          </div>
          <div class="card-body">
            <img :src="photo" alt="planta" class="img-fluid rounded mb-3" />
            <div class="d-flex gap-3 flex-wrap">
              <div><span class="text-muted">Genética:</span> <strong>{{ plant.strain || '—' }}</strong></div>
              <div><span class="text-muted">Código:</span> <strong>{{ plant.code || '—' }}</strong></div>
              <div><span class="text-muted">Etapa:</span> <strong>{{ plant.stage || '—' }}</strong></div>
              <div><span class="text-muted">Salud:</span> <strong>{{ plant.health || '—' }}</strong></div>
            </div>
          </div>
        </div>

        <div class="card mt-3">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Notas</strong>
            <div>
              <button v-if="!editNotes" class="btn btn-sm btn-outline-secondary" @click="startEditNotes">Editar</button>
              <div v-else class="d-flex gap-2">
                <button class="btn btn-sm btn-outline-secondary" @click="editNotes=false">Cancelar</button>
                <button class="btn btn-sm btn-primary" :disabled="plants.updating" @click="saveNotes">
                  <span v-if="plants.updating" class="spinner-border spinner-border-sm me-1"></span>
                  Guardar
                </button>
              </div>
            </div>
          </div>
          <div class="card-body">
            <template v-if="!editNotes">
              <p v-if="plant.notes" class="mb-0">{{ plant.notes }}</p>
              <p v-else class="text-muted mb-0">Sin notas.</p>
            </template>
            <template v-else>
              <textarea class="form-control" rows="8" v-model.trim="notesDraft"></textarea>
            </template>
          </div>
        </div>
      </div>

      <div class="col-12 col-lg-4">
        <div class="card">
          <div class="card-header"><strong>Información</strong></div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">ID</span><span>{{ plant.id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Lote</span><span>#{{ plant.lote_id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Creado</span><span>{{ new Date(plant.created_at).toLocaleString() }}</span>
            </div>
            <div class="d-flex justify-content-between py-1">
              <span class="text-muted">Actualizado</span><span>{{ new Date(plant.updated_at).toLocaleString() }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- MODAL Crear planta (misma lote) -->
    <div class="modal fade" :class="{ show: showCreate }" :style="{ display: showCreate ? 'block' : 'none' }" tabindex="-1" role="dialog" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Agregar planta</h5>
            <button type="button" class="btn-close" @click="showCreate=false" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div v-if="plants.error" class="alert alert-danger">{{ plants.error }}</div>

            <div class="mb-3">
              <label class="form-label">Genética</label>
              <input type="text" class="form-control" v-model.trim="createForm.strain" />
            </div>
            <div class="mb-3">
              <label class="form-label">Notas</label>
              <textarea class="form-control" rows="3" v-model.trim="createForm.notes"></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="plants.creating" @click="showCreate=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="plants.creating" @click="createAnother">
              <span v-if="plants.creating" class="spinner-border spinner-border-sm me-2"></span>
              Crear
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="showCreate=false"></div>
  </div>
</template>

