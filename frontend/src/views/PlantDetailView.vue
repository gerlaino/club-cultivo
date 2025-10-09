<script setup>
import { onMounted, computed, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { usePlantsStore } from "../stores/plants";

const route = useRoute();
const router = useRouter();
const plants = usePlantsStore();

const id = Number(route.params.id);
const error = ref(null);
const saving = ref(false);

const loading = computed(() => plants.loading);
const plant = computed(() => plants.current);

const notesDraft = ref("");

onMounted(async () => {
  try {
    await plants.fetchOne(id);
    notesDraft.value = plants.current?.notes || "";
  } catch (e) {
    error.value = "No se pudo cargar la planta.";
  }
});

async function saveNotes() {
  if (!plant.value) return;
  try {
    saving.value = true;
    await plants.update(plant.value.id, { notes: notesDraft.value });
  } catch (e) {
    alert("No se pudieron guardar las notas");
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="container py-4">
    <button class="btn btn-outline-secondary btn-sm mb-3" @click="router.back()">← Volver</button>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!plant" class="alert alert-warning">Planta no encontrada.</div>

    <div v-else class="row g-3">
      <div class="col-12">
        <h2 class="m-0">Planta {{ plant.code || `#${plant.id}` }}</h2>
      </div>

      <!-- Izquierda: imagen -->
      <div class="col-12 col-lg-8">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Imagen</strong>
            <span class="badge text-bg-secondary">placeholder</span>
          </div>
          <div class="card-body">
            <div class="ratio ratio-16x9 bg-dark rounded d-flex align-items-center justify-content-center text-white">
              <div class="text-center">
                <div class="mb-2">Sin imagen adjunta</div>
                <small class="text-white-50">Luego podremos subir fotos por planta.</small>
              </div>
            </div>
          </div>
        </div>

        <!-- Notas -->
        <div class="card mt-3">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Notas</strong>
            <button class="btn btn-sm btn-primary" :disabled="saving" @click="saveNotes">
              <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
              Guardar
            </button>
          </div>
          <div class="card-body">
            <textarea class="form-control" rows="8" v-model="notesDraft" />
          </div>
        </div>
      </div>

      <!-- Derecha: metadata -->
      <div class="col-12 col-lg-4">
        <div class="card">
          <div class="card-header"><strong>Información</strong></div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">ID</span><span>{{ plant.id }}</span>
            </div>
            <div v-if="plant.lote_id" class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Lote</span>
              <RouterLink class="link-primary" :to="{ name: 'lote-detail', params: { id: plant.lote_id } }">
                #{{ plant.lote_id }}
              </RouterLink>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Genética</span><span>{{ plant.strain || '—' }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Etapa</span><span class="text-capitalize">{{ plant.stage || '—' }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Salud</span><span>{{ plant.health || '—' }}</span>
            </div>
            <div v-if="plant.created_at" class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Creado</span><span>{{ new Date(plant.created_at).toLocaleString() }}</span>
            </div>
            <div v-if="plant.updated_at" class="d-flex justify-content-between py-1">
              <span class="text-muted">Actualizado</span><span>{{ new Date(plant.updated_at).toLocaleString() }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
