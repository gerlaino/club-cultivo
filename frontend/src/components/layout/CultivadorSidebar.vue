<template>
  <AppSidebar :links="NAV_LINKS" role="cultivador" />
</template>

<script setup>
import AppSidebar from './AppSidebar.vue'
import { Home, LayoutGrid, PackageCheck, History, Layers, Leaf, CalendarClock, CheckSquare } from 'lucide-vue-next'

const NAV_LINKS = [
  { to: '/',                     icon: Home,         label: 'Inicio' },
  { to: '/salas',                icon: LayoutGrid,   label: 'Mis salas' },
  { to: '/lotes',                icon: Layers,       label: 'Lotes' },
  { to: '/plantas',              icon: Leaf,         label: 'Plantas' },
  { to: '/cosechado',            icon: PackageCheck, label: 'Cosechado' },
  // El cultivador ya tenía permiso completo sobre tareas, pero no el link: la vista con
  // filtros y selección múltiple (marcar varias como hechas) le quedaba inalcanzable.
  { to: '/tareas',               icon: CheckSquare,  label: 'Tareas' },
  { to: '/mis-horas',            icon: CalendarClock, label: 'Mis horas' },
  { to: '/historial-cultivador', icon: History,      label: 'Historial' },
]
</script>
