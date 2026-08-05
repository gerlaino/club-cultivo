<template>
  <div class="dashboard-view">
    <AdminDashboard       v-if="auth.user?.role === 'admin'"                                        :key="auth.user?.id" />
    <CultivadorDashboard  v-else-if="auth.user?.role === 'cultivador'"                              :key="auth.user?.id" />
    <DispensadorDashboard v-else-if="auth.user?.role === 'dispensador'"                             :key="auth.user?.id" />
    <LegalDashboard       v-else-if="auth.user?.role === 'abogado' || auth.user?.role === 'auditor'" :key="auth.user?.id" />
    <SupervisorDashboard  v-else-if="auth.user?.role === 'supervisor'"                               :key="auth.user?.id" />
    <DefaultDashboard     v-else                                                                     :key="auth.user?.id" />
  </div>
</template>

<script setup>
import { useAuthStore } from '../stores/auth'
import AdminDashboard       from '../components/dashboards/AdminDashboard.vue'
import CultivadorDashboard  from '../components/dashboards/CultivadorDashboard.vue'
import DispensadorDashboard from '../components/dashboards/DispensadorDashboard.vue'
import LegalDashboard       from '../components/dashboards/LegalDashboard.vue'
import SupervisorDashboard  from './supervisor/SupervisorDashboard.vue'
import DefaultDashboard     from '../components/dashboards/DefaultDashboard.vue'

const auth = useAuthStore()
</script>

<style scoped>
.dashboard-view {
  min-height: calc(100vh - 120px);
}
</style>
