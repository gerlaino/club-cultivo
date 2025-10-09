<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useLotesStore } from "../stores/lotes";
import { usePlantsStore } from "../stores/plants";

const plants = usePlantsStore();
const route = useRoute();
const router = useRouter();
const lotes = useLotesStore();
const id = Number(route.params.id);
const error = ref(null);
const loading = computed(() => lotes.loading);
const lote = computed(() => lotes.current);

onMounted(async () => {
  try {
    await lotes.fetchOne(id);
  } catch (e) {
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
</script>

<template>
  <div class="container py-4">
    <button class="btn btn-outline-secondary btn-sm mb-3" @click="router.back()">← Volver</button>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!lote" class="alert alert-warning">Lote no encontrado.</div>

    <div v-else class="row g-3">
      <div class="col-12">
        <h2 class="m-0">Lote #{{ lote.id }}</h2>
      </div>

      <!-- Izquierda: imagen + datos principales -->
      <div class="col-12 col-lg-8">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Imagen</strong>
            <span class="badge text-bg-secondary">placeholder</span>
          </div>
          <div class="card-body">
            <div
              class="ratio ratio-16x9 bg-dark rounded d-flex align-items-center justify-content-center text-white">
              <div class="text-center">
                <div class="mb-2">Sin imagen adjunta</div>
                <small class="text-white-50">Más adelante podremos subir/traer imágenes por planta.</small>
              </div>
            </div>
          </div>
        </div>

        <div class="card mt-3">
          <div class="card-header"><strong>Datos del lote</strong></div>
          <div class="card-body">
            <div class="row">
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Cantidad de plantas</div>
                <div class="fs-5 fw-semibold">{{ label(lote.plants_count, 0) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Genética</div>
                <div class="fs-5 fw-semibold">{{ label(lote.strain) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Fecha de inicio</div>
                <div class="fs-5 fw-semibold">{{ label(lote.start_date) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Tipo de cultivo</div>
                <div class="fs-5 fw-semibold text-capitalize">{{ label(lote.grow_type) }}</div>
              </div>
              <div class="col-md-6 mb-2">
                <div class="text-muted small">Tipo de luminaria</div>
                <div class="fs-5 fw-semibold">{{ label(lote.light_type) }}</div>
              </div>
            </div>

            <div class="mt-3">
              <div class="text-muted small">Notas</div>
              <p class="mb-0">{{ lote.notes || "—" }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Derecha: metadata -->
      <div class="col-12 col-lg-4">
        <div class="card">
          <div class="card-header"><strong>Información</strong></div>
          <div class="card-body small">
            <div class="d-flex justify-content-between border-bottom py-1">
              <span class="text-muted">ID</span><span>{{ lote.id }}</span>
            </div>
            <div class="d-flex justify-content-between border-bottom py-1" v-if="lote.sala_id">
              <span class="text-muted">Sala</span>
              <RouterLink class="link-primary" :to="{ name:'sala-detail', params:{ id: lote.sala_id } }">
                #{{ lote.sala_id }}
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
            <RouterLink
              v-if="lote"
              class="btn btn-sm btn-outline-secondary"
              :to="{ name: 'lote-detail', params: { id: lote.id } }">
              Refrescar
            </RouterLink>
          </div>
          <div class="card-body">
            <div v-if="plants.loading" class="text-muted">Cargando…</div>
            <div v-else-if="!plants.byLote(lote.id).length" class="text-muted">Sin plantas.</div>
            <div v-else class="table-responsive">
              <table class="table align-middle">
                <thead>
                <tr>
                  <th>#</th>
                  <th>Código</th>
                  <th>Genética</th>
                  <th>Etapa</th>
                  <th>Salud</th>
                  <th></th>
                </tr>
                </thead>
                <tbody>
                <tr v-for="(p, i) in plants.byLote(lote.id)" :key="p.id">
                  <td>{{ i+1 }}</td>
                  <td class="text-monospace">{{ p.code || `P${p.id}` }}</td>
                  <td>{{ p.strain || '—' }}</td>
                  <td class="text-capitalize">{{ p.stage || '—' }}</td>
                  <td>{{ p.health || '—' }}</td>
                  <td class="text-end">
                    <RouterLink class="btn btn-sm btn-outline-primary"
                                :to="{ name:'plant-detail', params:{ id: p.id } }">
                      Ver
                    </RouterLink>
                  </td>
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
