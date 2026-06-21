<template>
  <AppSidebar :links="NAV_LINKS" role="cultivador" />
</template>

<script setup>
import AppSidebar from './AppSidebar.vue'
import { Home, LayoutGrid, PackageCheck, History, Layers, Leaf, CalendarClock } from 'lucide-vue-next'

const NAV_LINKS = [
  { to: '/',                     icon: Home,         label: 'Inicio' },
  { to: '/salas',                icon: LayoutGrid,   label: 'Mis salas' },
  { to: '/lotes',                icon: Layers,       label: 'Lotes' },
  { to: '/plantas',              icon: Leaf,         label: 'Plantas' },
  { to: '/cosechado',            icon: PackageCheck, label: 'Cosechado' },
  { to: '/mis-horas',            icon: CalendarClock, label: 'Mis horas' },
  { to: '/historial-cultivador', icon: History,      label: 'Historial' },
]
</script>
