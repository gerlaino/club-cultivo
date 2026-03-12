<template>
  <div class="dashboard-view">
    <AdminDashboard v-if="auth.user?.role === 'admin'" />
    <MedicoDashboard v-else-if="auth.user?.role === 'medico'" />
    <AgricultorDashboard v-else-if="auth.user?.role === 'agricultor'" />
    <CultivadorDashboard v-else-if="auth.user?.role === 'cultivador'" />
    <DefaultDashboard v-else />
  </div>
</template>

<script setup>
import { useAuthStore } from '../stores/auth'
import AdminDashboard from '../components/dashboards/AdminDashboard.vue'
import MedicoDashboard from '../components/dashboards/MedicoDashboard.vue'
import AgricultorDashboard from '../components/dashboards/AgricultorDashboard.vue'
import CultivadorDashboard from '../components/dashboards/CultivadorDashboard.vue'
import DefaultDashboard from '../components/dashboards/DefaultDashboard.vue'

const auth = useAuthStore()
</script>

<style scoped>
.dashboard-view {
  min-height: calc(100vh - 120px);
}
</style>

