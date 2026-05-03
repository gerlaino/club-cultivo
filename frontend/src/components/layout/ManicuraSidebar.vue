<template>
  <aside class="msb">

    <!-- Brand -->
    <div class="msb__brand">
      <Scissors :size="22" :stroke-width="1.5" class="msb__brand-icon" />
      <span class="msb__brand-name">cultivoespacial</span>
    </div>

    <!-- Nav links -->
    <nav class="msb__nav">
      <RouterLink
        v-for="link in NAV_LINKS"
        :key="link.label"
        :to="link.to"
        class="msb__link"
        :class="{ 'msb__link--active': isActive(link.to) }"
      >
        <component :is="link.icon" :size="18" :stroke-width="1.75" class="msb__link-ico" />
        <span>{{ link.label }}</span>
        <span v-if="link.badge" class="msb__badge">{{ link.badge }}</span>
      </RouterLink>
    </nav>

    <!-- User card -->
    <div class="msb__user">
      <DsAvatar :name="auth.displayName" tone="role-manicura" size="sm" />
      <div class="msb__user-info">
        <div class="msb__user-name">{{ auth.displayName }}</div>
        <div class="msb__user-role">Manicura · {{ club.name }}</div>
      </div>
      <button class="msb__logout" @click="handleLogout" title="Cerrar sesión">
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
import { Scissors, Clock, LogOut } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const NAV_LINKS = [
  { to: '/mnc/pendientes', icon: Scissors, label: 'Pendientes' },
  { to: '/mnc/espera',     icon: Clock,    label: 'En espera' },
]

function isActive(to) {
  return route.path === to || route.path.startsWith(to + '/')
}

async function handleLogout() {
  await auth.logOut()
  club.$reset()
  router.replace('/login')
}
</script>

<style scoped>
.msb {
  width: 240px;
  flex-shrink: 0;
  background: var(--c-role-manicura);
  display: flex;
  flex-direction: column;
  height: 100vh;
  position: sticky;
  top: 0;
  overflow-y: auto;
  overflow-x: hidden;
}

/* Brand */
.msb__brand {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(122, 155, 110, 0.25);
}
.msb__brand-icon { color: var(--c-role-manicura); flex-shrink: 0; }
.msb__brand-name {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 500;
  color: var(--c-paper);
  letter-spacing: -0.01em;
}

/* Nav */
.msb__nav {
  flex: 1;
  padding: var(--sp-3) var(--sp-2);
  display: flex;
  flex-direction: column;
  gap: 2px;
  overflow-y: auto;
}
.msb__link {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  border-radius: var(--r-md);
  font-size: var(--fs-14);
  font-weight: 400;
  color: rgba(168, 201, 181, 0.7);
  text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast);
  border-left: 3px solid transparent;
}
.msb__link:hover {
  background: rgba(122, 155, 110, 0.15);
  color: var(--c-leaf-300);
}
.msb__link--active {
  background: rgba(122, 155, 110, 0.2);
  color: var(--c-paper);
  font-weight: 500;
  border-left-color: var(--c-role-manicura);
}
.msb__link-ico { flex-shrink: 0; display: flex; }
.msb__badge {
  margin-left: auto;
  background: var(--c-role-manicura);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  padding: 1px 7px;
  border-radius: 999px;
  min-width: 20px;
  text-align: center;
}

/* User card */
.msb__user {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-top: 1px solid rgba(122, 155, 110, 0.25);
  flex-shrink: 0;
}
.msb__user-info { flex: 1; min-width: 0; }
.msb__user-name {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-paper);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.msb__user-role {
  font-family: var(--font-mono);
  font-size: 11px;
  color: rgba(168, 201, 181, 0.7);
  margin-top: 1px;
}
.msb__logout {
  background: none;
  border: none;
  color: rgba(168, 201, 181, 0.6);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
  transition: color var(--t-fast), background var(--t-fast);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.msb__logout:hover { color: var(--c-paper); background: rgba(255, 255, 255, 0.08); }

/* Hidden on mobile */
@media (max-width: 1023px) { .msb { display: none; } }
</style>
