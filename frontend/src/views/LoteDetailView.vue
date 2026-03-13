<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useLotesStore } from "../stores/lotes";
import { usePlantsStore } from "../stores/plants";

const route  = useRoute();
const router = useRouter();
const lotes  = useLotesStore();
const plants = usePlantsStore();

const id      = Number(route.params.id);
const error   = ref(null);
const loading = computed(() => lotes.loading);
const lote    = computed(() => lotes.current);

onMounted(async () => {
  try {
    await lotes.fetchOne(id);
  } catch {
    error.value = "No se pudo cargar el lote.";
  }
  try {
    await plants.fetchByLote(id);
  } catch (e) {
    console.warn("No se pudieron cargar plantas del lote", e);
  }
});

function label(val, fallback = "—") {
  return val ?? fallback;
}

function growTypeLabel(t) {
  const map = { sustrato: "Sustrato", hidroponia: "Hidroponia", aeroponia: "Aeroponia" };
  return map[t] || t || "—";
}

function lightTypeLabel(t) {
  const map = { led: "LED", hps: "HPS", cmh: "CMH", natural: "Natural", mixta: "Mixta" };
  return map[t] || t || "—";
}

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
</script>

<template>
  <div class="container py-4">
    <button class="btn btn-outline-secondary btn-sm mb-3" @click="router.back()">← Volver</button>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!lote" class="alert alert-warning">Lote no encontrado.</div>

    <div v-else class="row g-3">
      <div class="col-12">
        <h2 class="m-0">{{ lote.codigo || `Lote #${lote.id}` }}</h2>
      </div>

      <!-- Izquierda -->
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
                <small class="text-white-50">Más adelante podremos subir imágenes por planta.</small>
              </div>
            </div>
          </div>
        </div>

        <div class="card mt-3">
          <div class="card-header"><strong>Datos del lote</strong></div>
          <div class="card-body">
            <div class="row">
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Estado</div>
                <div class="fs-5 fw-semibold">{{ estadoLabel(lote.estado) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Cantidad de plantas</div>
                <div class="fs-5 fw-semibold">{{ label(lote.plants_count, 0) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Genética / Strain</div>
                <div class="fs-5 fw-semibold">{{ label(lote.strain) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Fecha de inicio</div>
                <div class="fs-5 fw-semibold">{{ label(lote.start_date) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Tipo de cultivo</div>
                <div class="fs-5 fw-semibold">{{ growTypeLabel(lote.grow_type) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Tipo de luminaria</div>
                <div class="fs-5 fw-semibold">{{ lightTypeLabel(lote.light_type) }}</div>
              </div>
              <div v-if="lote.dias_desde_inicio != null" class="col-md-6 mb-2">
                <div class="text-muted small">Días en curso</div>
                <div class="fs-5 fw-semibold">{{ lote.dias_desde_inicio }} días</div>
              </div>
            </div>
            <div class="mt-3">
              <div class="text-muted small">Notas</div>
              <p class="mb-0">{{ lote.notes || "—" }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Derecha -->
      <div class="col-12 col-lg-4">
        <div class="card">
          <div class="card-header"><strong>Información</strong></div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">ID</span><span>{{ lote.id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">Código</span><span>{{ lote.codigo || "—" }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1" v-if="lote.sala">
              <span class="text-muted">Sala</span>
              <RouterLink class="link-primary" :to="{ name: 'sala-detail', params: { id: lote.sala.id } }">
                {{ lote.sala.nombre }}
              </RouterLink>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1" v-if="lote.created_at">
              <span class="text-muted">Creado</span>
              <span>{{ new Date(lote.created_at).toLocaleString() }}</span>
            </div>
            <div class="d-flex justify-content-between py-1" v-if="lote.updated_at">
              <span class="text-muted">Actualizado</span>
              <span>{{ new Date(lote.updated_at).toLocaleString() }}</span>
            </div>
          </div>
        </div>

        <div class="card mt-3">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Plantas</strong>
            <button class="btn btn-sm btn-outline-secondary" @click="plants.fetchByLote(id)">
              Refrescar
            </button>
          </div>
          <div class="card-body">
            <div v-if="plants.loading" class="text-muted">Cargando…</div>
            <div v-else-if="plants.error" class="alert alert-danger small">{{ plants.error }}</div>
            <div v-else-if="!plants.byLote(id).length" class="text-muted">Sin plantas registradas.</div>
            <div v-else class="table-responsive">
              <table class="table table-sm align-middle mb-0">
                <thead>
                <tr>
                  <th>#</th>
                  <th>Código QR</th>
                  <th>Nombre</th>
                  <th>Estado</th>
                </tr>
                </thead>
                <tbody>
                <tr v-for="(p, i) in plants.byLote(id)" :key="p.id">
                  <td>{{ i + 1 }}</td>
                  <td class="font-monospace small">{{ p.codigo_qr || `P${p.id}` }}</td>
                  <td>{{ p.nombre || "—" }}</td>
                  <td class="text-capitalize">{{ p.state || "—" }}</td>
                </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

