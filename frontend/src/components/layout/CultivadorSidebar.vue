<template>
  <aside class="csb">

    <!-- Brand -->
    <div class="csb__brand">
      <img src="/logo-ce-icono.png" class="csb__brand-logo" alt="Cultivo Espacial" />
      <span class="csb__brand-name">Cultivo Espacial</span>
    </div>

    <!-- Nav links -->
    <nav class="csb__nav">
      <RouterLink
        v-for="link in NAV_LINKS"
        :key="link.to"
        :to="link.to"
        class="csb__link"
        :class="{ 'csb__link--active': isActive(link.to) }"
      >
        <component :is="link.icon" :size="18" :stroke-width="1.75" class="csb__link-ico" />
        <span>{{ link.label }}</span>
      </RouterLink>
    </nav>

  </aside>

</template>

<script setup>
import { useRoute } from 'vue-router'
import { Home, LayoutGrid, PackageCheck, History } from 'lucide-vue-next'

const route = useRoute()

const NAV_LINKS = [
  { to: '/',                     icon: Home,         label: 'Inicio' },
  { to: '/salas',                icon: LayoutGrid,   label: 'Mis salas' },
  { to: '/cosechado',            icon: PackageCheck, label: 'Cosechado' },
  { to: '/historial-cultivador', icon: History,      label: 'Historial' },
]

function isActive(to) {
  if (!to) return false
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(to + '/')
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
.csb__brand-logo { width: 30px; height: 30px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
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
  border-left-color: var(--c-role-cultivador);
}
.csb__link-ico { flex-shrink: 0; display: flex; }

/* Hidden on mobile */
@media (max-width: 1023px) { .csb { display: none; } }
</style>
