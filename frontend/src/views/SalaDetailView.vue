<script setup>
import { ref, computed, onMounted, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useSalasStore } from "../stores/salas";

const route = useRoute();
const router = useRouter();
const salas = useSalasStore();

const id = computed(() => Number(route.params.id));

const loading = ref(true);
const error = ref(null);

const sala = computed(() => {
  const fromItems =
    salas.items.find((s) => String(s.id) === String(id.value)) || null;
  return fromItems || salas.currentSala || null;
});

async function load() {
  loading.value = true;
  error.value = null;
  try {
    if (!sala.value) {
      if (typeof salas.fetchSala === "function") {
        await salas.fetchSala(id.value);
      } else {
        if (!salas.items.length && typeof salas.fetch === "function") {
          await salas.fetch();
        }
      }
    }
  } catch (e) {
    error.value =
      e?.response?.data?.error || e?.message || "No se pudo cargar la sala.";
  } finally {
    loading.value = false;
  }
}

onMounted(load);
watch(id, load);

function stateBadgeColor(state) {
  switch (state) {
    case "activa":
      return "success";
    case "mantenimiento":
      return "warning";
    case "cerrada":
      return "secondary";
    default:
      return "secondary";
  }
}

// Sensores (placeholder)
const temp = ref(null);
const hum = ref(null);
onMounted(() => {
  temp.value = 24.7;
  hum.value = 57;
});

// Notas
const editNotes = ref(false);
const notesDraft = ref("");

function startEditNotes() {
  notesDraft.value = sala.value?.notes || "";
  editNotes.value = true;
}

async function saveNotes() {
  if (!sala.value) return;
  try {
    await salas.update(sala.value.id, { notes: notesDraft.value });
    editNotes.value = false;
  } catch {}
}

// Imagen destacada de planta (usa sala.photo_url o placeholder)
const plantaImg = computed(() => {
  return (
    sala.value?.photo_url ||
    `https://picsum.photos/seed/sala-${id.value}/800/450`
  );
});
function goToPlantaDetail() {
  // ruta a definir cuando creemos el módulo de plantas
  router.push({ name: "planta-detail", params: { salaId: id.value } });
}
</script>

<template>
  <div class="container py-4">
    <!-- Header -->
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div class="d-flex align-items-center gap-2">
        <button class="btn btn-outline-secondary btn-sm" @click="router.back()">
          ← Volver
        </button>

        <h2 class="m-0">{{ sala?.name || "Sala" }}</h2>

        <span
          v-if="sala"
          class="badge text-capitalize"
          :class="`text-bg-${stateBadgeColor(sala.state)}`"
        >
          {{ sala.state }}
        </span>
      </div>

      <div class="text-muted small">
        <div v-if="sala?.updated_at">
          Actualizado: {{ new Date(sala.updated_at).toLocaleString() }}
        </div>
        <div v-else-if="sala?.created_at">
          Creado: {{ new Date(sala.created_at).toLocaleString() }}
        </div>
      </div>
    </div>

    <!-- Estados -->
    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!sala" class="alert alert-warning">Sala no encontrada.</div>

    <!-- Contenido -->
    <div v-else class="row g-3">
      <!-- Columna izquierda -->
      <div class="col-12 col-lg-8">
        <!-- KPIs -->
        <div class="row g-3">
          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Plantas</div>
                <div class="display-6 fw-bold">{{ sala.pots_count ?? 0 }}</div>
              </div>
            </div>
          </div>

          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Temperatura</div>
                <div class="display-6 fw-bold">
                  <span v-if="temp !== null">{{ temp.toFixed(1) }}°C</span>
                  <span v-else class="text-muted">—</span>
                </div>
              </div>
            </div>
          </div>

          <div class="col-6 col-md-4">
            <div class="card text-center h-100">
              <div class="card-body">
                <div class="text-muted small">Humedad</div>
                <div class="display-6 fw-bold">
                  <span v-if="hum !== null">{{ hum }}%</span>
                  <span v-else class="text-muted">—</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Cámara (placeholder) -->
        <div class="card mt-3">
          <div
            class="card-header d-flex justify-content-between align-items-center"
          >
            <strong>Cámara</strong>
            <span class="badge text-bg-secondary">placeholder</span>
          </div>
          <div class="card-body">
            <div
              class="ratio ratio-16x9 bg-dark rounded d-flex align-items-center justify-content-center text-white"
            >
              <div class="text-center">
                <div class="mb-2">Stream no configurado</div>
                <small class="text-white-50"
                >Cuando integremos Home Assistant aparecerá aquí.</small
                >
              </div>
            </div>
          </div>
        </div>

        <!-- Lotes (placeholder futuro) -->
        <div class="card mt-3">
          <div class="card-header"><strong>Lotes activos</strong></div>
          <div class="card-body">
            <div class="text-muted">
              En la próxima iteración listamos lotes asociados a la sala.
            </div>
          </div>
        </div>
      </div>

      <!-- Columna derecha -->
      <div class="col-12 col-lg-4">
        <!-- Notas -->
        <div class="card">
          <div
            class="card-header d-flex justify-content-between align-items-center"
          >
            <strong>Notas</strong>
            <div>
              <button
                v-if="!editNotes"
                class="btn btn-sm btn-outline-secondary"
                @click="startEditNotes"
              >
                Editar
              </button>
              <div v-else class="d-flex gap-2">
                <button
                  class="btn btn-sm btn-outline-secondary"
                  @click="editNotes = false"
                >
                  Cancelar
                </button>
                <button
                  class="btn btn-sm btn-primary"
                  :disabled="salas.updating"
                  @click="saveNotes"
                >
                  <span
                    v-if="salas.updating"
                    class="spinner-border spinner-border-sm me-1"
                  ></span>
                  Guardar
                </button>
              </div>
            </div>
          </div>
          <div class="card-body">
            <template v-if="!editNotes">
              <p v-if="sala.notes" class="mb-0">{{ sala.notes }}</p>
              <p v-else class="text-muted mb-0">Sin notas.</p>
            </template>
            <template v-else>
              <textarea
                class="form-control"
                rows="8"
                v-model.trim="notesDraft"
              ></textarea>
            </template>
          </div>
        </div>

        <!-- Información -->
        <div class="card mt-3">
          <div class="card-header"><strong>Información</strong></div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">ID</span><span>{{ sala.id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Estado</span
              ><span class="text-capitalize">{{ sala.state }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Plantas</span
              ><span>{{ sala.pots_count ?? 0 }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Creado</span
              ><span>{{ new Date(sala.created_at).toLocaleString() }}</span>
            </div>
            <div class="d-flex justify-content-between py-1">
              <span class="text-muted">Actualizado</span
              ><span>{{ new Date(sala.updated_at).toLocaleString() }}</span>
            </div>
          </div>
        </div>

        <!-- Planta destacada -->
        <div class="card mt-3">
          <div class="card-header d-flex justify-content-between">
            <strong>Planta destacada</strong>
            <span class="text-muted small">clic para ver detalle</span>
          </div>
          <button class="p-0 border-0 bg-transparent" @click="goToPlantaDetail">
            <img
              :src="plantaImg"
              class="img-fluid rounded-bottom"
              alt="Planta destacada"
              style="display:block; width:100%;"
              loading="lazy"
            />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>




