<template>
  <div class="msh">
    <!-- Top bar -->
    <header class="msh__topbar">
      <div class="msh__topbar-brand">
        <img v-if="club.data?.logo_url" :src="club.data.logo_url" class="msh__logo" />
        <span v-else class="msh__logo-emoji">🌿</span>
        <span class="msh__club-name">{{ club.data?.name || 'Cultivo Espacial' }}</span>
      </div>
      <div class="msh__topbar-actions">
        <NotificationBell />
      </div>
    </header>

    <!-- Contenido -->
    <main class="msh__main">
      <RouterView />
    </main>

    <!-- Bottom nav -->
    <nav class="msh__nav">
      <RouterLink
        v-for="item in navItems"
        :key="item.to"
        :to="item.to"
        class="msh__nav-item"
        :class="{ 'msh__nav-item--active': isActive(item) }"
      >
        <i class="bi" :class="item.icon"></i>
        <span>{{ item.label }}</span>
      </RouterLink>
    </nav>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useClubStore }  from '../../stores/club'
import NotificationBell  from '../ui/NotificationBell.vue'

const route = useRoute()
const auth  = useAuthStore()
const club  = useClubStore()

const NAV = {
  admin: [
    { to: '/m/admin',       icon: 'bi-house-fill',         label: 'Inicio'    },
    { to: '/m/admin/aprobar', icon: 'bi-check-circle',     label: 'Aprobar'   },
    { to: '/m/admin/alertas', icon: 'bi-bell',             label: 'Alertas'   },
    { to: '/m/perfil',      icon: 'bi-person-circle',      label: 'Perfil'    },
  ],
  cultivador: [
    { to: '/m/cultivador',         icon: 'bi-house-fill',   label: 'Inicio'  },
    { to: '/m/cultivador/salas',   icon: 'bi-grid',         label: 'Salas'   },
    { to: '/m/cultivador/lotes',   icon: 'bi-layers',       label: 'Lotes'   },
    { to: '/m/cultivador/tareas',  icon: 'bi-list-check',   label: 'Tareas'  },
    { to: '/m/perfil',             icon: 'bi-person-circle', label: 'Perfil' },
  ],
  manicura: [
    { to: '/m/manicura',          icon: 'bi-house-fill',    label: 'Inicio'     },
    { to: '/m/manicura/pendientes', icon: 'bi-scissors',    label: 'Pendientes' },
    { to: '/m/manicura/lotes',    icon: 'bi-layers',        label: 'Lotes'      },
    { to: '/m/perfil',            icon: 'bi-person-circle', label: 'Perfil'     },
  ],
  dispensador: [
    { to: '/m/dispensador',           icon: 'bi-house-fill',    label: 'Inicio'    },
    { to: '/m/dispensador/dispensar', icon: 'bi-bag-heart',     label: 'Dispensar' },
    { to: '/m/dispensador/historial', icon: 'bi-clock-history', label: 'Historial' },
    { to: '/m/perfil',                icon: 'bi-person-circle', label: 'Perfil'    },
  ],
}

const navItems = computed(() => NAV[auth.user?.role] || [])

function isActive(item) {
  if (item.exact) return route.path === item.to
  // Home solo activo si es exacto
  if (item.icon === 'bi-house-fill') return route.path === item.to
  return route.path.startsWith(item.to)
}
</script>

<style scoped>
.msh {
  display: flex; flex-direction: column;
  min-height: 100dvh; background: #f4f8f4;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

/* Top bar */
.msh__topbar {
  position: sticky; top: 0; z-index: 50;
  background: #0f2417;
  padding: .75rem 1rem;
  display: flex; align-items: center; justify-content: space-between;
  gap: .75rem;
  padding-top: calc(.75rem + env(safe-area-inset-top));
}
.msh__topbar-brand { display: flex; align-items: center; gap: .6rem; }
.msh__logo { width: 30px; height: 30px; border-radius: 8px; object-fit: cover; }
.msh__logo-emoji { font-size: 1.4rem; }
.msh__club-name { font-size: .9rem; font-weight: 700; color: #fff; }
.msh__topbar-actions { display: flex; align-items: center; gap: .5rem; }

/* Main */
.msh__main {
  flex: 1;
  overflow-y: auto;
  padding-bottom: calc(70px + env(safe-area-inset-bottom));
}

/* Bottom nav */
.msh__nav {
  position: fixed; bottom: 0; left: 0; right: 0; z-index: 50;
  background: #fff;
  border-top: 1px solid #e2e8f0;
  display: flex;
  padding-bottom: env(safe-area-inset-bottom);
  box-shadow: 0 -4px 16px rgba(0,0,0,.06);
}
.msh__nav-item {
  flex: 1; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: .2rem;
  padding: .6rem .25rem;
  text-decoration: none; color: #94a3b8;
  font-size: .62rem; font-weight: 600;
  transition: color .15s;
  -webkit-tap-highlight-color: transparent;
}
.msh__nav-item i { font-size: 1.35rem; line-height: 1; }
.msh__nav-item--active { color: #1b5e20; }
.msh__nav-item--active i { color: #1b5e20; }
</style>
