<template>
  <AppSidebar :links="navLinks" role="medico" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AppSidebar from './AppSidebar.vue'
import { LayoutDashboard, CalendarDays, Users, FileHeart, FolderOpen, Settings2 } from 'lucide-vue-next'
import { getMedicoTurnos } from '../../lib/api.js'

const turnosHoy = ref(0)

const navLinks = computed(() => [
  { to: '/medico',                icon: LayoutDashboard, label: 'Inicio', exact: true },
  { to: '/medico/turnos',         icon: CalendarDays,    label: 'Turnera', badge: turnosHoy.value },
  { to: '/medico/pacientes',      icon: Users,           label: 'Mis Pacientes' },
  { to: '/medico/indicaciones',   icon: FileHeart,       label: 'Indicaciones' },
  { to: '/medico/documentos',     icon: FolderOpen,      label: 'Documentos' },
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
