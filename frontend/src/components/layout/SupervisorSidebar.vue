<template>
  <AppSidebarGroups :home="HOME" :groups="GRUPOS" role="supervisor" />
</template>

<script setup>
import AppSidebarGroups from './AppSidebarGroups.vue'
import { Home, Building2, LayoutGrid, Sprout, CheckSquare, Dna, TrendingUp, Store } from 'lucide-vue-next'

// Supervisor: estilo admin (grupos colapsables) pero con menos accesos.
const HOME = { to: '/', icon: Home, label: 'Inicio' }

const GRUPOS = [
  {
    label: 'Cultivo', icon: Sprout, defaultOpen: true,
    items: [
      { to: '/salas',     icon: LayoutGrid, label: 'Salas' },
      { to: '/lotes',     icon: Sprout,     label: 'Lotes' },
      { to: '/geneticas', icon: Dna,        label: 'Genéticas' },
    ],
  },
  {
    // El supervisor dispensa, así que el mostrador es suyo también. El link faltaba: una
    // pantalla permitida sin forma de llegar es una pantalla que no existe.
    label: 'Dispensa', icon: Store, defaultOpen: true,
    items: [
      { to: '/mostrador', icon: Store, label: 'Mostrador' },
    ],
  },
  {
    label: 'Planificación', icon: CheckSquare, defaultOpen: true,
    items: [
      { to: '/tareas', icon: CheckSquare, label: 'Tareas' },
    ],
  },
  {
    label: 'Infraestructura', icon: Building2, defaultOpen: false,
    items: [
      { to: '/sedes', icon: Building2, label: 'Mis sedes' },
    ],
  },
  {
    label: 'Analytics', icon: TrendingUp, defaultOpen: false,
    items: [
      { to: '/analitica', icon: TrendingUp, label: 'Analítica' },
    ],
  },
]
</script>
