<template>
  <div class="cfg">
    <nav class="cfg__tabs">
      <RouterLink
        v-for="t in TABS"
        :key="t.to"
        :to="t.to"
        class="cfg__tab"
        :class="{ 'cfg__tab--active': isActive(t.to) }"
      >
        <component :is="t.icon" :size="15" :stroke-width="1.75" />
        {{ t.label }}
      </RouterLink>
    </nav>
    <RouterView />
  </div>
</template>

<script setup>
import { useRoute } from 'vue-router'
import { Building2, Users, SlidersHorizontal, Leaf, Trash2 } from 'lucide-vue-next'

const route = useRoute()

const TABS = [
  { to: '/configuracion/club',        label: 'Club',        icon: Leaf            },
  { to: '/configuracion/sedes',       label: 'Sedes',       icon: Building2       },
  { to: '/configuracion/equipo',      label: 'Equipo',      icon: Users           },
  { to: '/configuracion/suscripcion', label: 'Suscripción', icon: SlidersHorizontal },
  { to: '/configuracion/papelera',    label: 'Papelera',    icon: Trash2          },
]

function isActive(to) {
  return route.path === to || route.path.startsWith(to + '/')
}
</script>

<style scoped>
.cfg { display: flex; flex-direction: column; min-height: 100%; }

.cfg__tabs {
  display: flex; gap: 0; background: #fff; border-bottom: 2px solid #e8f0e9;
  padding: 0 1.25rem; position: sticky; top: 0; z-index: 10;
}
@media (max-width: 640px) { .cfg__tabs { padding: 0 .75rem; overflow-x: auto; } }

.cfg__tab {
  display: flex; align-items: center; gap: .4rem;
  padding: .75rem 1rem; font-size: .825rem; font-weight: 600; color: #60725d;
  text-decoration: none; white-space: nowrap; border-bottom: 2px solid transparent;
  margin-bottom: -2px; transition: all .15s;
}
.cfg__tab:hover { color: #0f2611; }
.cfg__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }
</style>
