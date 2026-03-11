<template>
  <div class="dashboard-view">
    <div class="container-fluid py-4">
      <!-- Header con saludo -->
      <div class="row mb-4">
        <div class="col-12">
          <h1 class="mb-1">
            Hola, {{ auth.displayName || 'Usuario' }} 👋
          </h1>
          <p class="text-muted">
            {{ getGreeting() }} - {{ currentDate }}
          </p>
        </div>
      </div>

      <!-- Dashboard según rol -->
      <AdminDashboard v-if="auth.isClubAdmin" />
      <MedicoDashboard v-else-if="auth.role === 'medico'" />
      <AgricultorDashboard v-else-if="auth.role === 'cultivador'" />
      <DefaultDashboard v-else />
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '../stores/auth'
import AdminDashboard from '../components/dashboards/AdminDashboard.vue'
import MedicoDashboard from '../components/dashboards/MedicoDashboard.vue'
import AgricultorDashboard from '../components/dashboards/AgricultorDashboard.vue'
import DefaultDashboard from '../components/dashboards/DefaultDashboard.vue'

const auth = useAuthStore()

const currentDate = computed(() => {
  return new Date().toLocaleDateString('es-AR', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
})

function getGreeting() {
  const hour = new Date().getHours()
  if (hour < 12) return 'Buenos días'
  if (hour < 20) return 'Buenas tardes'
  return 'Buenas noches'
}
</script>

<style scoped>
.dashboard-view {
  min-height: calc(100vh - 120px);
}
</style>

