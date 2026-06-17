<template>
  <AppSidebar :links="NAV_LINKS" role="dispensador" />
</template>

<script setup>
import AppSidebar from './AppSidebar.vue'
import { Home, PackagePlus, Users, History, Boxes, BookmarkCheck } from 'lucide-vue-next'

const NAV_LINKS = [
  { to: '/',          icon: Home,          label: 'Inicio' },
  { to: '/dispensar', icon: PackagePlus,   label: 'Dispensar' },
  { to: '/pacientes', icon: Users,         label: 'Pacientes' },
  { to: '/historial', icon: History,       label: 'Dispensaciones' },
  { to: '/reservas',  icon: BookmarkCheck, label: 'Reservas' },
  { to: '/stock',     icon: Boxes,         label: 'Stock' },
]
</script>
