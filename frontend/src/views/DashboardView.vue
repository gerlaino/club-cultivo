<script setup>
import { ref, onMounted } from "vue";
import { listSalas, listLotes, me } from "../lib/api";

const loading = ref(true);
const error = ref("");
const user = ref(null);
const totals = ref({ salas: 0, lotes: 0 });

onMounted(async () => {
  try {
    const [meRes, salasRes, lotesRes] = await Promise.all([
      me(),
      listSalas().catch(() => ({ data: [] })), // por si aún no hay endpoint
      listLotes().catch(() => ({ data: [] })),
    ]);
    user.value = meRes.data;
    totals.value = {
      salas: (salasRes.data || []).length,
      lotes: (lotesRes.data || []).length,
    };
  } catch (e) {
    error.value = "No se pudo cargar el dashboard.";
    console.error(e);
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="container py-4">
    <h1 class="mb-4">Dashboard</h1>

    <div v-if="loading" class="alert alert-secondary">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <template v-else>
      <div class="row g-3">
        <div class="col-md-4">
          <div class="card shadow-sm">
            <div class="card-body">
              <h5 class="card-title mb-1">Usuario</h5>
              <div class="text-muted">{{ user?.email }}</div>
              <span class="badge text-bg-primary mt-2">{{ user?.role }}</span>
            </div>
          </div>
        </div>

        <div class="col-md-4">
          <div class="card shadow-sm">
            <div class="card-body">
              <h5 class="card-title mb-1">Salas</h5>
              <div class="display-6">{{ totals.salas }}</div>
              <small class="text-muted">Totales</small>
            </div>
          </div>
        </div>

        <div class="col-md-4">
          <div class="card shadow-sm">
            <div class="card-body">
              <h5 class="card-title mb-1">Lotes</h5>
              <div class="display-6">{{ totals.lotes }}</div>
              <small class="text-muted">Totales</small>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
