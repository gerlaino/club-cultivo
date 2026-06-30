<template>
  <AppSidebar :links="NAV_LINKS" role="manicura" />
</template>

<script setup>
import AppSidebar from './AppSidebar.vue'
import { Scissors, Clock, ListChecks, CalendarClock } from 'lucide-vue-next'

const NAV_LINKS = [
  { to: '/mnc/pendientes', icon: Scissors,      label: 'Pendientes' },
  { to: '/mnc/espera',     icon: Clock,         label: 'En espera' },
  { to: '/mis-horas',      icon: CalendarClock, label: 'Mis horas' },
  { to: '/tareas',         icon: ListChecks,    label: 'Tareas' },
]
</script>
