<template>
  <aside class="csb">

    <!-- Brand -->
    <div class="csb__brand">
      <LeafSeal :size="24" class="csb__brand-leaf" />
      <span class="csb__brand-name">cultivoespacial</span>
    </div>

    <!-- Nav links -->
    <nav class="csb__nav">
      <RouterLink
        v-for="link in NAV_LINKS"
        :key="link.label"
        :to="link.to"
        class="csb__link"
        :class="{ 'csb__link--active': isActive(link.to) }"
      >
        <component :is="link.icon" :size="18" :stroke-width="1.75" class="csb__link-ico" />
        <span>{{ link.label }}</span>
      </RouterLink>
    </nav>

    <!-- User card -->
    <div class="csb__user">
      <DsAvatar :name="auth.displayName" tone="role-cultivador" size="sm" />
      <div class="csb__user-info">
        <div class="csb__user-name">{{ auth.displayName }}</div>
        <div class="csb__user-role">Supervisor · {{ club.name }}</div>
      </div>
      <button class="csb__logout" @click="handleLogout" title="Cerrar sesión">
        <LogOut :size="16" :stroke-width="1.75" />
      </button>
    </div>

  </aside>
</template>

<script setup>
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import LeafSeal from '../../design-system/icons/LeafSeal.vue'
import DsAvatar from '../../design-system/components/Avatar.vue'
import {
  Home, Building2, LayoutGrid, Sprout, CheckSquare, Dna, LogOut,
} from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const NAV_LINKS = [
  { to: '/',          icon: Home,        label: 'Inicio' },
  { to: '/sedes',     icon: Building2,   label: 'Mis sedes' },
  { to: '/salas',     icon: LayoutGrid,  label: 'Salas' },
  { to: '/lotes',     icon: Sprout,      label: 'Lotes' },
  { to: '/tareas',    icon: CheckSquare, label: 'Tareas' },
  { to: '/geneticas', icon: Dna,         label: 'Genéticas' },
]

function isActive(to) {
  if (!to) return false
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(to + '/')
}

async function handleLogout() {
  await auth.logOut()
  club.$reset()
  router.replace('/login')
}
</script>

<style scoped>
.csb {
  width: 240px;
  flex-shrink: 0;
  background: var(--c-leaf-800);
  display: flex;
  flex-direction: column;
  height: 100vh;
  position: sticky;
  top: 0;
  overflow-y: auto;
  overflow-x: hidden;
}

/* Brand */
.csb__brand {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168, 201, 181, 0.15);
}
.csb__brand-leaf { color: var(--c-leaf-300); flex-shrink: 0; }
.csb__brand-name {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 500;
  color: var(--c-paper);
  letter-spacing: -0.01em;
}

/* Nav */
.csb__nav {
  flex: 1;
  padding: var(--sp-3) var(--sp-2);
  display: flex;
  flex-direction: column;
  gap: 2px;
  overflow-y: auto;
}
.csb__link {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  font-weight: 400;
  color: var(--c-leaf-300);
  text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast);
  border-left: 3px solid transparent;
  background: none;
  border-right: none;
  border-top: none;
  border-bottom: none;
  width: 100%;
  text-align: left;
  cursor: pointer;
}
.csb__link:hover {
  background: rgba(255, 255, 255, 0.06);
  color: var(--c-paper);
}
.csb__link--active {
  background: var(--c-leaf-700);
  color: var(--c-paper);
  font-weight: 500;
  border-left-color: #0f766e;
}
.csb__link-ico { flex-shrink: 0; display: flex; }

/* User card */
.csb__user {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-top: 1px solid rgba(168, 201, 181, 0.15);
  flex-shrink: 0;
}
.csb__user-info { flex: 1; min-width: 0; }
.csb__user-name {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-paper);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.csb__user-role {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--c-leaf-300);
  margin-top: 1px;
}
.csb__logout {
  background: none;
  border: none;
  color: var(--c-leaf-300);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
  transition: color var(--t-fast), background var(--t-fast);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.csb__logout:hover { color: var(--c-paper); background: rgba(255, 255, 255, 0.08); }

/* Hidden on mobile */
@media (max-width: 1023px) { .csb { display: none; } }
</style>
