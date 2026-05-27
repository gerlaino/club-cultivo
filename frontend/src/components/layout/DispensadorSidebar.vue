<template>
  <aside class="dsb">

    <!-- Brand -->
    <div class="dsb__brand">
      <img src="/logo-ce-icono.png" class="dsb__brand-logo" alt="Cultivo Espacial" />
      <span class="dsb__brand-name">Cultivo Espacial</span>
    </div>

    <!-- Nav links -->
    <nav class="dsb__nav">
      <RouterLink
        v-for="link in NAV_LINKS"
        :key="link.label"
        :to="link.to"
        class="dsb__link"
        :class="{ 'dsb__link--active': isActive(link.to) }"
      >
        <component :is="link.icon" :size="18" :stroke-width="1.75" class="dsb__link-ico" />
        <span>{{ link.label }}</span>
      </RouterLink>
    </nav>

    <!-- User card -->
    <div class="dsb__user">
      <DsAvatar :name="auth.displayName" tone="role-dispensador" size="sm" />
      <div class="dsb__user-info">
        <div class="dsb__user-name">{{ auth.displayName }}</div>
        <div class="dsb__user-role">Dispensador · {{ club.name }}</div>
      </div>
      <button class="dsb__logout" @click="handleLogout" title="Cerrar sesión">
        <LogOut :size="16" :stroke-width="1.75" />
      </button>
    </div>

  </aside>
</template>

<script setup>
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import DsAvatar from '../../design-system/components/Avatar.vue'
import { Home, PackagePlus, Users, History, Boxes, LogOut } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const NAV_LINKS = [
  { to: '/',          icon: Home,        label: 'Inicio' },
  { to: '/dispensar', icon: PackagePlus, label: 'Dispensar' },
  { to: '/pacientes', icon: Users,       label: 'Pacientes' },
  { to: '/historial', icon: History,     label: 'Historial' },
  { to: '/stock',     icon: Boxes,       label: 'Stock' },
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
.dsb {
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
.dsb__brand {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168, 201, 181, 0.15);
}
.dsb__brand-logo { width: 30px; height: 30px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
.dsb__brand-name {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 500;
  color: var(--c-paper);
  letter-spacing: -0.01em;
}

/* Nav */
.dsb__nav {
  flex: 1;
  padding: var(--sp-3) var(--sp-2);
  display: flex;
  flex-direction: column;
  gap: 2px;
  overflow-y: auto;
}
.dsb__link {
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
}
.dsb__link:hover {
  background: rgba(255, 255, 255, 0.06);
  color: var(--c-paper);
}
.dsb__link--active {
  background: var(--c-leaf-700);
  color: var(--c-paper);
  font-weight: 500;
  border-left-color: var(--c-role-dispensador);
}
.dsb__link-ico { flex-shrink: 0; display: flex; }

/* User card */
.dsb__user {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-top: 1px solid rgba(168, 201, 181, 0.15);
  flex-shrink: 0;
}
.dsb__user-info { flex: 1; min-width: 0; }
.dsb__user-name {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-paper);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.dsb__user-role {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--c-leaf-300);
  margin-top: 1px;
}
.dsb__logout {
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
.dsb__logout:hover { color: var(--c-paper); background: rgba(255, 255, 255, 0.08); }

/* Hidden on mobile */
@media (max-width: 1023px) { .dsb { display: none; } }
</style>
