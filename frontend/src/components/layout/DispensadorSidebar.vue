<template>
  <AppSidebar :links="links" role="dispensador" />
</template>

<script setup>
import { computed } from 'vue'
import AppSidebar from './AppSidebar.vue'
import { useClubStore } from '../../stores/club.js'
import { Home, Users, History, Boxes, BookmarkCheck, Beer, ListChecks, Clock } from 'lucide-vue-next'

const club = useClubStore()

const BASE_LINKS = [
  { to: '/',          icon: Home,          label: 'Inicio' },
  { to: '/pacientes', icon: Users,         label: 'Pacientes' },
  { to: '/historial', icon: History,       label: 'Dispensaciones' },
  { to: '/reservas',  icon: BookmarkCheck, label: 'Reservas' },
  { to: '/stock',     icon: Boxes,         label: 'Stock' },
  // Sus tareas y sus horas. Las dos pantallas ya existían y el dispensador ya tenía permiso
  // (`tareas: ['index','show']`, y `/mis-horas` está en las rutas COMUNES): lo que faltaba era
  // el link. Una pantalla permitida sin forma de llegar es una pantalla que no existe.
  { to: '/tareas',    icon: ListChecks,    label: 'Tareas' },
  { to: '/mis-horas', icon: Clock,         label: 'Mis horas' },
]

// El bar aparece solo si la organización lo tiene habilitado.
const links = computed(() =>
  club.data?.features?.bar
    ? [...BASE_LINKS, { to: '/bar', icon: Beer, label: 'Buffet' }]
    : BASE_LINKS
)
</script>
