<!-- frontend/src/views/DashboardView.vue -->
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
  <div class="p-6 space-y-6">
    <h1 class="text-2xl font-semibold">Dashboard</h1>

    <div v-if="loading">Cargando…</div>
    <div v-else-if="error" class="text-red-600">{{ error }}</div>
    <div v-else class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="rounded-xl shadow p-4">
        <div class="text-sm text-gray-500">Salas (total)</div>
        <div class="text-3xl font-bold">{{ stats.salas.total }}</div>
        <div class="mt-2 text-xs text-gray-500">
          <span v-for="(v, k) in stats.salas.por_estado" :key="k" class="mr-3">
            {{ k }}: <strong>{{ v }}</strong>
          </span>
        </div>
      </div>

      <div class="rounded-xl shadow p-4">
        <div class="text-sm text-gray-500">Lotes (total)</div>
        <div class="text-3xl font-bold">{{ stats.lotes.total }}</div>
        <div class="mt-2 text-xs text-gray-500">
          <span v-for="(v, k) in stats.lotes.por_etapa" :key="k" class="mr-3">
            {{ k }}: <strong>{{ v }}</strong>
          </span>
        </div>
      </div>

      <div class="rounded-xl shadow p-4">
        <div class="text-sm text-gray-500">Ocupación</div>
        <div class="text-lg">
          Plantas activas: <strong>{{ stats.ocupacion.plantas_activas }}</strong>
        </div>
        <div class="text-lg">
          Macetas totales: <strong>{{ stats.ocupacion.total_macetas }}</strong>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* simple cards con Tailwind ya que lo tenés habilitado via Vite PostCSS (si no, se ven igual decentes) */
</style>

