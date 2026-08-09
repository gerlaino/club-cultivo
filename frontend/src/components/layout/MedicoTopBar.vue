<template>
  <header class="mdc-topbar">
    <button class="mdc-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>

    <ClubBrand tone="role-medico" />

    <div class="mdc-breadcrumb">
      <span class="mdc-page-title">{{ pageTitle }}</span>
    </div>

    <div class="mdc-right">
      <!-- Bell -->
      <button class="mdc-icon-btn" :class="{ 'mdc-icon-btn--alert': count > 0 }" @click="bellOpen = !bellOpen">
        <Bell :size="17" :stroke-width="1.75" />
        <span v-if="count > 0" class="mdc-bell-badge">{{ count > 9 ? '9+' : count }}</span>
      </button>
      <div v-if="bellOpen" class="mdc-bell-panel">
        <div class="mdc-panel-header">
          <span>Alertas</span>
          <button v-if="count" class="mdc-panel-clear" @click="marcarTodas">Leer todas</button>
          <button class="mdc-panel-close" @click="bellOpen = false">✕</button>
        </div>
        <div v-if="!count" class="mdc-panel-empty">Sin alertas pendientes</div>
        <div v-for="a in noLeidas.slice(0, 8)" :key="a.id" class="mdc-panel-item" :class="`mdc-panel-item--${a.severidad}`" @click="marcarLeida(a.id)">
          <div class="mdc-panel-msg">{{ a.mensaje }}</div>
          <div class="mdc-panel-time">{{ formatTime(a.created_at) }}</div>
        </div>
      </div>

      <!-- User menu -->
      <div class="mdc-user-wrap">
        <button class="mdc-user-btn" @click="userMenuOpen = !userMenuOpen">
          <div class="mdc-user-av">{{ initials }}</div>
          <span class="mdc-user-name">{{ auth.user?.first_name }}</span>
          <ChevronDown :size="13" :stroke-width="2" class="mdc-chevron" :class="{ 'mdc-chevron--open': userMenuOpen }" />
        </button>
        <Transition name="dropdown">
          <div v-if="userMenuOpen" class="mdc-user-menu" v-click-outside="() => userMenuOpen = false">
            <div class="mdc-menu-header">
              <div class="mdc-menu-av">{{ initials }}</div>
              <div class="mdc-menu-info">
                <span class="mdc-menu-fullname">{{ auth.user?.first_name }} {{ auth.user?.last_name }}</span>
                <span class="mdc-menu-email">{{ auth.user?.email }}</span>
              </div>
            </div>
            <div class="mdc-menu-divider"></div>
            <RouterLink to="/perfil" class="mdc-menu-item" @click="userMenuOpen = false">
              <UserCircle :size="15" /> Mi perfil
            </RouterLink>
            <button class="mdc-menu-item mdc-menu-item--danger" @click="doLogout">
              <LogOut :size="15" /> Cerrar sesión
            </button>
          </div>
        </Transition>
      </div>
    </div>
  </header>

  <HelpDrawer v-model="helpOpen" />
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Menu, Bell, ChevronDown, UserCircle, LogOut } from 'lucide-vue-next'
import { useAlertasInternas } from '../../composables/useAlertasInternas.js'
import { useAuthStore } from '../../stores/auth.js'
import { clearAuthToken } from '../../lib/api.js'
import ClubBrand from './ClubBrand.vue'
import HelpDrawer from '../HelpDrawer.vue'

defineEmits(['open-drawer'])

const auth   = useAuthStore()
const route  = useRoute()
const router = useRouter()

const LABELS = {
  '/medico':             'Inicio',
  '/medico/turnos':      'Turnera',
  '/medico/pacientes':   'Mis Pacientes',
}
const pageTitle = computed(() => {
  if (/^\/medico\/pacientes\/\d+/.test(route.path)) return 'Ficha Clínica'
  return LABELS[route.path] || 'Panel Médico'
})

const initials = computed(() => {
  const fn = auth.user?.first_name?.[0] || ''
  const ln = auth.user?.last_name?.[0]  || ''
  return (fn + ln).toUpperCase() || 'M'
})

const bellOpen    = ref(false)
const userMenuOpen = ref(false)
const helpOpen    = ref(false)

const { noLeidas, count, marcarLeida, marcarTodas } = useAlertasInternas()

function formatTime(ts) {
  if (!ts) return ''
  const diff = Date.now() - new Date(ts).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `hace ${mins}m`
  const hrs = Math.floor(mins / 60)
  return hrs < 24 ? `hace ${hrs}h` : `hace ${Math.floor(hrs / 24)}d`
}

async function doLogout() {
  userMenuOpen.value = false
  clearAuthToken()
  await auth.logOut()
  router.push('/login')
}

// Simple click-outside directive
const vClickOutside = {
  mounted(el, binding) {
    el._clickHandler = (e) => { if (!el.contains(e.target)) binding.value(e) }
    document.addEventListener('mousedown', el._clickHandler)
  },
  unmounted(el) {
    document.removeEventListener('mousedown', el._clickHandler)
  },
}
</script>

<style scoped>
.mdc-topbar {
  height: 54px; display: flex; align-items: center; gap: .75rem;
  padding: 0 1.25rem;
  background: #fff;
  border-bottom: 1px solid var(--c-slate-100);
  flex-shrink: 0; position: relative; z-index: 10;
}
.mdc-hamburger {
  display: none; background: none; border: none; cursor: pointer;
  color: var(--c-slate-600); padding: .25rem; border-radius: 6px;
}
@media (max-width: 1023px) { .mdc-hamburger { display: flex; } }

.mdc-breadcrumb { flex: 1; }
.mdc-page-title { font-size: .9rem; font-weight: 700; color: var(--c-slate-900); }

.mdc-right { display: flex; align-items: center; gap: .6rem; position: relative; }

.mdc-icon-btn {
  position: relative; width: 34px; height: 34px; border-radius: 8px;
  background: none; border: 1px solid var(--c-slate-200); cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  color: var(--c-slate-500); transition: all .15s;
}
.mdc-icon-btn:hover { background: var(--c-slate-50); color: var(--c-slate-900); }
.mdc-icon-btn--alert { border-color: #fca5a5; background: #fff5f5; color: #dc2626; }
.mdc-bell-badge {
  position: absolute; top: -4px; right: -4px;
  min-width: 16px; height: 16px; background: #dc2626; color: #fff;
  font-size: 9px; font-weight: 800; border-radius: 999px;
  display: flex; align-items: center; justify-content: center;
  padding: 0 2px; border: 2px solid #fff;
}

.mdc-bell-panel {
  position: absolute; top: calc(100% + 8px); right: 36px;
  width: 320px; background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,.12);
  z-index: 200; max-height: 380px; overflow-y: auto;
}
.mdc-panel-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .6rem .9rem; border-bottom: 1px solid var(--c-slate-100);
  font-size: .8rem; font-weight: 700; color: var(--c-slate-900);
}
.mdc-panel-clear { font-size: .72rem; color: var(--c-slate-500); background: none; border: none; cursor: pointer; text-decoration: underline; }
.mdc-panel-close { background: none; border: none; cursor: pointer; color: var(--c-slate-400); font-size: .82rem; }
.mdc-panel-empty { padding: .9rem; font-size: .8rem; color: var(--c-slate-400); text-align: center; }
.mdc-panel-item { padding: .55rem .9rem; border-bottom: 1px solid var(--c-slate-50); cursor: pointer; }
.mdc-panel-item:hover { background: var(--c-slate-50); }
.mdc-panel-msg { font-size: .8rem; color: #1e293b; font-weight: 500; }
.mdc-panel-time { font-size: .7rem; color: var(--c-slate-400); margin-top: 2px; }

/* User menu */
.mdc-user-wrap { position: relative; }
.mdc-user-btn {
  display: flex; align-items: center; gap: .4rem;
  background: none; border: 1px solid var(--c-slate-200); border-radius: 8px;
  padding: .3rem .5rem .3rem .35rem; cursor: pointer; transition: all .15s;
}
.mdc-user-btn:hover { background: var(--c-slate-50); border-color: var(--c-slate-300); }
.mdc-user-av {
  width: 26px; height: 26px; border-radius: 50%; flex-shrink: 0;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #fff; font-size: .65rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
}
.mdc-user-name { font-size: .78rem; font-weight: 600; color: var(--c-slate-700); max-width: 80px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.mdc-chevron { color: var(--c-slate-400); transition: transform .2s; }
.mdc-chevron--open { transform: rotate(180deg); }

.mdc-user-menu {
  position: absolute; top: calc(100% + 6px); right: 0;
  width: 240px; background: #fff; border: 1px solid var(--c-slate-200);
  border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,.12); z-index: 200;
  overflow: hidden;
}
.mdc-menu-header { display: flex; align-items: center; gap: .65rem; padding: .85rem 1rem; background: var(--c-slate-50); }
.mdc-menu-av {
  width: 36px; height: 36px; border-radius: 50%; flex-shrink: 0;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #fff; font-size: .75rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
}
.mdc-menu-info { min-width: 0; }
.mdc-menu-fullname { display: block; font-size: .82rem; font-weight: 700; color: var(--c-slate-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mdc-menu-email { display: block; font-size: .7rem; color: var(--c-slate-400); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mdc-menu-divider { height: 1px; background: var(--c-slate-100); }
.mdc-menu-item {
  display: flex; align-items: center; gap: .5rem;
  padding: .6rem 1rem; font-size: .82rem; font-weight: 500; color: var(--c-slate-700);
  text-decoration: none; cursor: pointer; background: none; border: none;
  width: 100%; transition: background .12s;
}
.mdc-menu-item:hover { background: var(--c-slate-50); color: var(--c-slate-900); }
.mdc-menu-item--danger { color: #dc2626; }
.mdc-menu-item--danger:hover { background: #fff5f5; color: #dc2626; }

.dropdown-enter-active, .dropdown-leave-active { transition: opacity .15s, transform .15s; }
.dropdown-enter-from, .dropdown-leave-to { opacity: 0; transform: translateY(-4px); }
</style>
