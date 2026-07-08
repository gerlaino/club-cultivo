<template>
  <AppSidebar :links="links" role="dispensador" />
</template>

<script setup>
import { computed } from 'vue'
import AppSidebar from './AppSidebar.vue'
import { useClubStore } from '../../stores/club.js'
import { Home, Users, History, Boxes, BookmarkCheck, Beer } from 'lucide-vue-next'

const club = useClubStore()

const BASE_LINKS = [
  { to: '/',          icon: Home,          label: 'Inicio' },
  { to: '/pacientes', icon: Users,         label: 'Pacientes' },
  { to: '/historial', icon: History,       label: 'Dispensaciones' },
  { to: '/reservas',  icon: BookmarkCheck, label: 'Reservas' },
  { to: '/stock',     icon: Boxes,         label: 'Stock' },
]

// El bar aparece solo si el club lo tiene habilitado.
const links = computed(() =>
  club.data?.features?.bar
    ? [...BASE_LINKS, { to: '/bar', icon: Beer, label: 'Bar' }]
    : BASE_LINKS
)
</script>
