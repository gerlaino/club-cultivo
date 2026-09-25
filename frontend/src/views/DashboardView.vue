<template>
  <div class="dashboard-view">
    <!-- Uso personal: el admin ES el cultivador, y su inicio es el del cultivo —tareas de la
         semana, salas con su ambiente, lotes—, no el panel de una organización (dispensas,
         caja, equipo). Misma pantalla que el cultivador, con la puesta en marcha arriba. -->
    <CultivadorDashboard  v-if="auth.user?.role === 'admin' && club.data?.personal"                 :key="auth.user?.id" personal />
    <AdminDashboard       v-else-if="auth.user?.role === 'admin'"                                   :key="auth.user?.id" />
    <CultivadorDashboard  v-else-if="auth.user?.role === 'cultivador'"                              :key="auth.user?.id" />
    <DispensadorDashboard v-else-if="auth.user?.role === 'dispensador'"                             :key="auth.user?.id" />
    <LegalDashboard       v-else-if="auth.user?.role === 'abogado' || auth.user?.role === 'auditor'" :key="auth.user?.id" />
    <SupervisorDashboard  v-else-if="auth.user?.role === 'supervisor'"                               :key="auth.user?.id" />
    <!-- Sólo con usuario: sin él, «pedile un rol al administrador» aparecía un instante al salir. -->
    <DefaultDashboard     v-else-if="auth.user"                                                      :key="auth.user?.id" />
  </div>
</template>

<script setup>
import { useAuthStore } from '../stores/auth'
import { useClubStore } from '../stores/club'
import AdminDashboard       from '../components/dashboards/AdminDashboard.vue'
import CultivadorDashboard  from '../components/dashboards/CultivadorDashboard.vue'
import DispensadorDashboard from '../components/dashboards/DispensadorDashboard.vue'
import LegalDashboard       from '../components/dashboards/LegalDashboard.vue'
import SupervisorDashboard  from './supervisor/SupervisorDashboard.vue'
import DefaultDashboard     from '../components/dashboards/DefaultDashboard.vue'

const auth = useAuthStore()
const club = useClubStore()
</script>

<style scoped>
.dashboard-view {
  min-height: calc(100vh - 120px);
}
</style>
