<template>
  <AppSidebar :links="navLinks" role="medico" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AppSidebar from './AppSidebar.vue'
import { LayoutDashboard, CalendarDays, Users, Settings2 } from 'lucide-vue-next'
import { getMedicoTurnos } from '../../lib/api.js'

const turnosHoy = ref(0)

const navLinks = computed(() => [
  { to: '/medico',                icon: LayoutDashboard, label: 'Inicio', exact: true },
  { to: '/medico/turnos',         icon: CalendarDays,    label: 'Turnera', badge: turnosHoy.value },
  // Indicaciones y Documentos no son secciones: son tabs del paciente al que pertenecen.
  { to: '/medico/pacientes',      icon: Users,           label: 'Mis Pacientes' },
  { to: '/medico/disponibilidad', icon: Settings2,       label: 'Mi disponibilidad' },
])

onMounted(async () => {
  try {
    const { data } = await getMedicoTurnos()
    const hoy = new Date().toDateString()
    turnosHoy.value = (data || []).filter(t =>
      new Date(t.fecha_hora).toDateString() === hoy &&
      t.estado !== 'cancelado' && t.estado !== 'realizado'
    ).length
  } catch { /* silent */ }
})
</script>
