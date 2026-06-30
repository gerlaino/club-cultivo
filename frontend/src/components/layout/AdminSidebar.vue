<template>
  <aside class="asb" :class="{ 'asb--collapsed': collapsed }">

    <!-- Marca de la plataforma (el club va en el topbar) -->
    <RouterLink to="/" class="asb__brand" title="Cultivo Espacial">
      <img src="/logo-ce-icono.png" class="asb__brand-logo" alt="Cultivo Espacial" />
      <span class="asb__brand-name">Cultivo Espacial</span>
    </RouterLink>

    <!-- Grupos primarios (1 click → su vista principal) -->
    <nav class="asb__nav">
      <RouterLink
        v-for="g in NAV_GROUPS" :key="g.key"
        :to="g.to" class="asb__link"
        :class="{ 'asb__link--active': activeKey === g.key }"
        :title="collapsed ? g.label : undefined"
      >
        <component :is="ICONS[g.key]" :size="18" :stroke-width="1.75" class="asb__link-ico" />
        <span class="asb__label">{{ g.label }}</span>
        <span v-if="groupBadge(g)" class="asb__badge">{{ groupBadge(g) }}</span>
      </RouterLink>
    </nav>

    <button class="asb__collapse" @click="toggleCollapse" :title="collapsed ? 'Expandir menú' : 'Contraer menú'">
      <PanelLeftClose v-if="!collapsed" :size="15" :stroke-width="1.75" />
      <PanelLeftOpen  v-else            :size="15" :stroke-width="1.75" />
    </button>

  </aside>
</template>

<script setup>
import { computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  LayoutDashboard, Sprout, Users, Factory, ShoppingCart,
  CheckSquare, BarChart3, Settings, PanelLeftClose, PanelLeftOpen,
} from 'lucide-vue-next'
import { NAV_GROUPS, detectGroup, useNavContext } from '../../composables/useNavContext.js'

const route = useRoute()
const { collapsed, toggleCollapse, refreshBadges, badgeFor } = useNavContext()

const ICONS = {
  dashboard: LayoutDashboard,
  cultivo:   Sprout,
  pacientes: Users,
  produccion: Factory,
  comercial: ShoppingCart,
  tareas:    CheckSquare,
  reportes:  BarChart3,
  config:    Settings,
}

const activeKey = computed(() => detectGroup(route.path).key)

function groupBadge(g) {
  return g.tabs.reduce((s, t) => s + (t.badge ? badgeFor(t.badge) : 0), 0)
}

onMounted(refreshBadges)
watch(() => route.path, (path, prev) => {
  // Refresca el badge al entrar/salir de manicura o tareas.
  const tocar = ['/admin/pesajes-manicura', '/tareas']
  if (tocar.some(r => path.startsWith(r) || (prev || '').startsWith(r))) refreshBadges()
})
</script>

<style scoped>
.asb {
  width: 220px; flex-shrink: 0;
  display: flex; flex-direction: column;
  height: 100vh; position: sticky; top: 0; overflow-x: hidden;
  background: var(--c-role-admin);
  transition: width .25s cubic-bezier(.4,0,.2,1);
}
.asb--collapsed { width: 54px; }
.asb--collapsed .asb__brand-name,
.asb--collapsed .asb__label,
.asb--collapsed .asb__badge { display: none; }
.asb--collapsed .asb__brand { justify-content: center; padding: 1.1rem .5rem; }
.asb--collapsed .asb__link  { justify-content: center; padding: 10px 0; }
.asb--collapsed .asb__nav   { padding: var(--sp-3) var(--sp-1); }

/* Club brand */
.asb__brand {
  display: flex; align-items: center; gap: var(--sp-3); text-decoration: none;
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168,201,181,0.18); flex-shrink: 0;
}
.asb__brand-logo { width: 30px; height: 30px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background: rgba(255,255,255,.1); }
.asb__brand-name { font-family: var(--font-display); font-size: var(--fs-16); font-weight: 500; color: var(--c-paper); letter-spacing: -.01em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* Nav primario */
.asb__nav { flex: 1; padding: var(--sp-3) var(--sp-2); display: flex; flex-direction: column; gap: 2px; overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgba(168,201,181,0.22) transparent; }
.asb__nav::-webkit-scrollbar { width: 6px; }
.asb__nav::-webkit-scrollbar-thumb { background: rgba(168,201,181,0.22); border-radius: 6px; }

.asb__link {
  display: flex; align-items: center; gap: 11px; padding: 10px 14px; border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-leaf-300); text-decoration: none;
  border-left: 3px solid transparent; transition: background var(--t-fast), color var(--t-fast);
}
.asb__link:hover { background: rgba(255,255,255,0.06); color: var(--c-paper); }
.asb__link--active { background: rgba(255,255,255,0.14); color: var(--c-paper); font-weight: 600; border-left-color: var(--c-leaf-300); }
.asb__link-ico { flex-shrink: 0; }
.asb__label { flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.asb__badge { background: #d97706; color: #fff; font-size: 10px; font-weight: 700; line-height: 1; padding: 2px 6px; border-radius: 10px; min-width: 16px; text-align: center; }

.asb__collapse { display: flex; align-items: center; justify-content: center; width: 100%; height: 36px; border: none; background: none; color: rgba(168,201,181,0.45); cursor: pointer; flex-shrink: 0; transition: color .15s, background .15s; }
.asb__collapse:hover { color: rgba(168,201,181,0.9); background: rgba(255,255,255,0.05); }

@media (max-width: 1023px) { .asb { display: none; } }
</style>
