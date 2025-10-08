<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useSalasStore } from "../stores/salas";

const route = useRoute();
const router = useRouter();
const store = useSalasStore();

const id = Number(route.params.id);
const loading = ref(true);
const error = ref(null);

const sala = computed(() =>
  store.items.find((s) => s.id === id) || store.current
);

onMounted(async () => {
  try {
    await store.fetchOne(id);
  } catch (e) {
    error.value = "No se pudo cargar la sala";
  } finally {
    loading.value = false;
  }
});

function back() {
  router.push("/salas");
}
</script>

<template>
  <div class="container py-3">
    <div class="d-flex align-items-center gap-2 mb-3">
      <button class="btn btn-light" @click="back">
        <i class="bi bi-arrow-left"></i>
      </button>
      <h1 class="h4 m-0">Sala</h1>
    </div>

    <div v-if="loading" class="text-muted">Cargando...</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!sala" class="alert alert-warning">No encontrada.</div>

    <div v-else class="d-grid gap-3">
      <!-- Header -->
      <div class="card border-0 shadow-sm">
        <div class="card-body d-flex flex-wrap justify-content-between align-items-center gap-2">
          <div>
            <h2 class="h4 m-0">{{ sala.name }}</h2>
            <div class="text-muted small">ID #{{ sala.id }}</div>
          </div>
          <span class="badge fs-6"
                :class="{
              'text-bg-success': sala.state === 'activa',
              'text-bg-warning': sala.state === 'mantenimiento',
              'text-bg-secondary': sala.state === 'inactiva'
            }"
          >{{ sala.state }}</span>
        </div>
      </div>

      <div class="row g-3">
        <!-- Overview -->
        <div class="col-12 col-lg-8">
          <div class="card border-0 shadow-sm h-100">
            <div class="card-header bg-white">
              <strong>Resumen</strong>
            </div>
            <div class="card-body">
              <div class="row g-3">
                <div class="col-6 col-md-3">
                  <div class="border rounded p-3">
                    <div class="text-muted small">Macetas</div>
                    <div class="fs-5 fw-semibold">{{ sala.pots_count ?? 0 }}</div>
                  </div>
                </div>
                <div class="col-6 col-md-3">
                  <div class="border rounded p-3">
                    <div class="text-muted small">Temperatura</div>
                    <div class="fs-5 fw-semibold">N/A</div>
                    <div class="small text-muted">pendiente sensor</div>
                  </div>
                </div>
                <div class="col-6 col-md-3">
                  <div class="border rounded p-3">
                    <div class="text-muted small">Humedad</div>
                    <div class="fs-5 fw-semibold">N/A</div>
                    <div class="small text-muted">pendiente sensor</div>
                  </div>
                </div>
                <div class="col-6 col-md-3">
                  <div class="border rounded p-3">
                    <div class="text-muted small">Ciclo</div>
                    <div class="fs-5 fw-semibold">N/A</div>
                    <div class="small text-muted">integraremos con lotes</div>
                  </div>
                </div>
              </div>

              <hr class="my-4" />

              <div>
                <div class="text-muted small mb-1">Notas</div>
                <div v-if="sala.notes" class="p-3 border rounded bg-light">
                  {{ sala.notes }}
                </div>
                <div v-else class="text-muted fst-italic">Sin notas.</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Lateral: Cámara e Imágenes -->
        <div class="col-12 col-lg-4">
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-white d-flex justify-content-between align-items-center">
              <strong>Cámara</strong>
              <span class="badge text-bg-secondary">Próximamente</span>
            </div>
            <div class="card-body">
              <div class="ratio ratio-16x9 border rounded d-flex align-items-center justify-content-center bg-light">
                <div class="text-muted">Stream no configurado</div>
              </div>
              <div class="small text-muted mt-2">
                Integraremos con Home Assistant (RTSP/HLS).
              </div>
            </div>
          </div>

          <div class="card border-0 shadow-sm mt-3">
            <div class="card-header bg-white d-flex justify-content-between align-items-center">
              <strong>Imágenes</strong>
              <span class="badge text-bg-secondary">Próximamente</span>
            </div>
            <div class="card-body text-muted small">
              Galería de fotos para seguimiento visual del cultivo.
            </div>
          </div>
        </div>
      </div>

      <!-- Automations futuro -->
      <div class="card border-0 shadow-sm">
        <div class="card-header bg-white">
          <strong>Automatizaciones (futuro)</strong>
        </div>
        <div class="card-body text-muted small">
          Reglas de temperatura/humedad, alertas push/email, control de extractores/luces/riego.
        </div>
      </div>
    </div>
  </div>
</template>
