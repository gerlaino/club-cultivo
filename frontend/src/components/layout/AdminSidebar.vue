<template>
  <aside class="asb">

    <!-- Brand -->
    <div class="asb__brand">
      <LeafSeal :size="24" class="asb__brand-leaf" />
      <span class="asb__brand-name">cultivoespacial</span>
    </div>

    <!-- Nav links -->
    <nav class="asb__nav">
      <RouterLink
        v-for="link in NAV_LINKS"
        :key="link.to"
        :to="link.to"
        class="asb__link"
        :class="{ 'asb__link--active': isActive(link.to) }"
      >
        <component :is="link.icon" :size="18" :stroke-width="1.75" class="asb__link-ico" />
        <span>{{ link.label }}</span>
      </RouterLink>
    </nav>

    <!-- User card -->
    <div class="asb__user">
      <DsAvatar :name="auth.displayName" tone="role-admin" size="sm" />
      <div class="asb__user-info">
        <div class="asb__user-name">{{ auth.displayName }}</div>
        <div class="asb__user-role">Admin · {{ club.name }}</div>
      </div>
      <button class="asb__logout" @click="handleLogout" title="Cerrar sesión">
        <i class="bi bi-box-arrow-right"></i>
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
  LayoutDashboard, Users, Building2, Wallet, CheckSquare,
  Sprout, FileCheck, FileText, UserCog, Globe, ClipboardCheck, Container, Layers,
} from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const NAV_LINKS = [
  { to: '/',                  icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/pacientes',         icon: Users,           label: 'Pacientes' },
  { to: '/sedes',             icon: Building2,       label: 'Sedes' },
  { to: '/salas',             icon: Layers,          label: 'Salas' },
  { to: '/contabilidad',      icon: Wallet,          label: 'Contabilidad' },
  { to: '/tareas',            icon: CheckSquare,     label: 'Tareas' },
  { to: '/geneticas',         icon: Sprout,          label: 'Genéticas' },
  { to: '/aprobaciones',      icon: ClipboardCheck,  label: 'Aprobaciones' },
  { to: '/admin/curado',      icon: Container,       label: 'Curado' },
  { to: '/informe-semestral', icon: FileCheck,       label: 'REPROCANN' },
  { to: '/documentos',        icon: FileText,        label: 'Documentos' },
  { to: '/usuarios',          icon: UserCog,         label: 'Equipo' },
  { to: '/web',               icon: Globe,           label: 'Web' },
]

function isActive(to) {
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
.asb {
  width: 240px;
  flex-shrink: 0;
  background: var(--c-role-admin);
  display: flex;
  flex-direction: column;
  height: 100vh;
  position: sticky;
  top: 0;
  overflow-y: auto;
  overflow-x: hidden;
}

/* Brand */
.asb__brand {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168,201,181,0.15);
}
.asb__brand-leaf { color: var(--c-leaf-300); flex-shrink: 0; }
.asb__brand-name {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 500;
  color: var(--c-paper);
  letter-spacing: -.01em;
}

/* Nav */
.asb__nav {
  flex: 1;
  padding: var(--sp-3) var(--sp-2);
  display: flex;
  flex-direction: column;
  gap: 2px;
  overflow-y: auto;
}

.asb__link {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  font-weight: 400;
  color: var(--c-leaf-300);
  text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast), border-color var(--t-fast);
  border-left: 3px solid transparent;
}
.asb__link:hover {
  background: rgba(255,255,255,0.06);
  color: var(--c-paper);
}
.asb__link--active {
  background: var(--c-leaf-700);
  color: var(--c-paper);
  font-weight: 500;
  border-left-color: var(--c-leaf-300);
}
.asb__link-ico { flex-shrink: 0; display: flex; }

/* User card */
.asb__user {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-top: 1px solid rgba(168,201,181,0.15);
  flex-shrink: 0;
}
.asb__user-info { flex: 1; min-width: 0; }
.asb__user-name {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-paper);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.asb__user-role {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--c-leaf-300);
  margin-top: 1px;
}
.asb__logout {
  background: none;
  border: none;
  color: var(--c-leaf-300);
  font-size: var(--fs-16);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
  transition: color var(--t-fast), background var(--t-fast);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.asb__logout:hover { color: var(--c-paper); background: rgba(255,255,255,0.08); }

/* Hide on mobile — Ola 1.B handles mobile admin nav */
@media (max-width: 1023px) { .asb { display: none; } }
</style>
