<template>
  <div class="msh" :class="`msh--${role}`">

    <!-- Top bar — logo + volver (en detalle) o logout -->
    <header class="msh__top">
      <div class="msh__brand">
        <!-- En detalle: botón volver -->
        <button v-if="isDetalle" class="msh__back" @click="router.back()">
          <i class="bi bi-chevron-left"></i>
        </button>
        <template v-else>
          <img v-if="club.data?.logo_url" :src="club.data.logo_url" class="msh__logo" />
          <span v-else class="msh__logo-text">{{ clubInitials }}</span>
          <span class="msh__club-name">{{ club.data?.name || 'Cultivo Espacial' }}</span>
        </template>
      </div>
      <button class="msh__logout" @click="doLogout" title="Cerrar sesión">
        <i class="bi bi-box-arrow-right"></i>
      </button>
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
        class="msh__tab"
        :class="{ 'msh__tab--active': isActive(item) }"
      >
        <i class="bi msh__tab-icon" :class="item.icon"></i>
        <span class="msh__tab-label">{{ item.label }}</span>
      </RouterLink>
    </nav>

  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useClubStore }  from '../../stores/club'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const role = computed(() => auth.user?.role || '')

// Detecta si estamos en una página de detalle (muestra botón volver)
const isDetalle = computed(() =>
  /\/m\/(sala|lote|planta|mnc\/lotes)\//.test(route.path)
)

const clubInitials = computed(() => {
  const n = club.data?.name || 'CE'
  return n.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase()
})

const NAV = {
  admin: [
    { to: '/m/admin/salas',   icon: 'bi-grid-3x3-gap', label: 'Salas'   },
    { to: '/m/admin/lotes',   icon: 'bi-layers',       label: 'Lotes'   },
    { to: '/m/admin/aprobar', icon: 'bi-check2-circle', label: 'Aprobar' },
    { to: '/m/admin/tareas',  icon: 'bi-list-check',   label: 'Tareas'  },
  ],
  supervisor: [
    { to: '/m/admin/salas',   icon: 'bi-grid-3x3-gap', label: 'Salas'   },
    { to: '/m/admin/lotes',   icon: 'bi-layers',       label: 'Lotes'   },
    { to: '/m/admin/aprobar', icon: 'bi-check2-circle', label: 'Aprobar' },
    { to: '/m/admin/tareas',  icon: 'bi-list-check',   label: 'Tareas'  },
  ],
  cultivador: [
    { to: '/m/cultivador/salas',  icon: 'bi-grid-3x3-gap', label: 'Salas'   },
    { to: '/m/cultivador/lotes',  icon: 'bi-layers',       label: 'Lotes'   },
    { to: '/m/cultivador/plantas', icon: 'bi-flower2',     label: 'Plantas' },
    { to: '/m/cultivador/tareas', icon: 'bi-list-check',   label: 'Tareas'  },
  ],
  manicura: [
    { to: '/m/manicura/pendientes', icon: 'bi-hourglass-split', label: 'Pendientes' },
    { to: '/m/manicura/cosecha',    icon: 'bi-scissors',        label: 'Cosecha'    },
    { to: '/m/manicura/secado',     icon: 'bi-wind',            label: 'Secado'     },
    { to: '/m/manicura/curado',     icon: 'bi-archive',         label: 'Curado'     },
  ],
  dispensador: [
    { to: '/m/dispensador/dispensar', icon: 'bi-bag-heart',     label: 'Dispensar'  },
    { to: '/m/dispensador/historial', icon: 'bi-clock-history', label: 'Historial'  },
    { to: '/m/dispensador/stock',     icon: 'bi-box-seam',      label: 'Stock'      },
  ],
  delivery: [
    { to: '/m/delivery/despachos', icon: 'bi-truck',         label: 'Despachos'  },
    { to: '/m/delivery/historial', icon: 'bi-clock-history', label: 'Historial'  },
  ],
}

const navItems = computed(() => NAV[role.value] || [])

function isActive(item) {
  return route.path === item.to || route.path.startsWith(item.to + '/')
}

async function doLogout() {
  await auth.logOut?.()
  router.replace('/login')
}
</script>

<style scoped>
/* Variables por rol */
.msh--cultivador  { --msh-accent: #16a34a; --msh-top-bg: #0f2417; }
.msh--admin       { --msh-accent: #1b5e20; --msh-top-bg: #0f2417; }
.msh--supervisor  { --msh-accent: #1b5e20; --msh-top-bg: #0f2417; }
.msh--manicura    { --msh-accent: #7c3aed; --msh-top-bg: #1c1028; }
.msh--dispensador { --msh-accent: #1d4ed8; --msh-top-bg: #0c1a33; }
.msh--delivery    { --msh-accent: #c2410c; --msh-top-bg: #1c0a00; }

.msh {
  display: flex;
  flex-direction: column;
  min-height: 100dvh;
  background: #f4f7f4;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

/* ── Top bar ── */
.msh__top {
  position: sticky;
  top: 0;
  z-index: 50;
  background: var(--msh-top-bg);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: .7rem 1rem;
  padding-top: calc(.7rem + env(safe-area-inset-top));
}
.msh__brand { display: flex; align-items: center; gap: .55rem; min-width: 0; }

.msh__logo {
  width: 32px; height: 32px;
  border-radius: 8px;
  object-fit: cover;
  flex-shrink: 0;
}
.msh__logo-text {
  width: 32px; height: 32px;
  border-radius: 8px;
  background: var(--msh-accent);
  color: #fff;
  font-size: .8rem;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.msh__club-name {
  font-size: .88rem;
  font-weight: 700;
  color: #fff;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.msh__back {
  background: rgba(255,255,255,.1);
  border: none; color: #fff;
  width: 36px; height: 36px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.msh__logout {
  background: rgba(255,255,255,.1);
  border: none;
  color: rgba(255,255,255,.7);
  width: 36px; height: 36px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.1rem;
  cursor: pointer;
  flex-shrink: 0;
  transition: background .15s, color .15s;
  -webkit-tap-highlight-color: transparent;
}
.msh__logout:hover { background: rgba(255,255,255,.2); color: #fff; }

/* ── Main ── */
.msh__main {
  flex: 1;
  overflow-y: auto;
  padding-bottom: calc(64px + env(safe-area-inset-bottom));
}

/* ── Bottom nav ── */
.msh__nav {
  position: fixed;
  bottom: 0; left: 0; right: 0;
  z-index: 50;
  background: #fff;
  border-top: 1px solid #e8eae8;
  display: flex;
  padding-bottom: env(safe-area-inset-bottom);
  box-shadow: 0 -2px 12px rgba(0,0,0,.07);
}
.msh__tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: .18rem;
  padding: .55rem .25rem;
  text-decoration: none;
  color: #b0b8b0;
  transition: color .15s;
  -webkit-tap-highlight-color: transparent;
  position: relative;
}
.msh__tab-icon { font-size: 1.3rem; line-height: 1; }
.msh__tab-label { font-size: .6rem; font-weight: 600; letter-spacing: .02em; }

.msh__tab--active { color: var(--msh-accent); }
.msh__tab--active::before {
  content: '';
  position: absolute;
  top: 0; left: 25%; right: 25%;
  height: 2.5px;
  background: var(--msh-accent);
  border-radius: 0 0 3px 3px;
}
</style>
