<script setup>
import { ref, onMounted } from "vue"
import { getStats } from "../lib/api"

const loading = ref(true)
const error = ref(null)
const stats = ref({
  salas: { total: 0, por_estado: {} },
  lotes: { total: 0, por_etapa: {} },
  ocupacion: { total_macetas: 0, plantas_activas: 0 }
})

onMounted(async () => {
  try {
    const { data } = await getStats()
    stats.value = data
  } catch (e) {
    error.value = "No se pudieron cargar las estadísticas"
    console.error(e)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div>
    <h1 class="h3 mb-4">Dashboard</h1>

    <div v-if="loading" class="alert alert-secondary">Cargando…</div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>

    <div v-else class="row g-3">
      <div class="col-12 col-md-4">
        <div class="card h-100">
          <div class="card-body">
            <div class="text-uppercase text-muted small mb-1">Salas (total)</div>
            <div class="display-6 fw-semibold">{{ stats.salas.total }}</div>
            <div class="mt-2 small text-muted">
              <span v-for="(v, k) in stats.salas.por_estado" :key="k" class="me-3">
                {{ k }}: <strong>{{ v }}</strong>
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="col-12 col-md-4">
        <div class="card h-100">
          <div class="card-body">
            <div class="text-uppercase text-muted small mb-1">Lotes (total)</div>
            <div class="display-6 fw-semibold">{{ stats.lotes.total }}</div>
            <div class="mt-2 small text-muted">
              <span v-for="(v, k) in stats.lotes.por_etapa" :key="k" class="me-3">
                {{ k }}: <strong>{{ v }}</strong>
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="col-12 col-md-4">
        <div class="card h-100">
          <div class="card-body">
            <div class="text-uppercase text-muted small mb-1">Ocupación</div>
            <div class="fs-4">Plantas activas: <strong>{{ stats.ocupacion.plantas_activas }}</strong></div>
            <div class="fs-4">Macetas totales: <strong>{{ stats.ocupacion.total_macetas }}</strong></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>



