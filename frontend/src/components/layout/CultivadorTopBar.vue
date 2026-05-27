<template>
  <header class="ctb">
    <div class="ctb__inner">

      <!-- Hamburger (tablet 768-1023px) -->
      <button class="ctb__hamburger" @click="emit('open-drawer')" aria-label="Abrir menú">
        <Menu :size="20" :stroke-width="1.75" />
      </button>

      <!-- Breadcrumb -->
      <nav class="ctb__bc" aria-label="breadcrumb">
        <template v-for="(crumb, i) in breadcrumbs" :key="i">
          <RouterLink v-if="crumb.to" :to="crumb.to" class="ctb__bc-link">{{ crumb.label }}</RouterLink>
          <span v-else class="ctb__bc-current">{{ crumb.label }}</span>
          <span v-if="i < breadcrumbs.length - 1" class="ctb__bc-sep" aria-hidden="true">/</span>
        </template>
      </nav>

      <!-- Right -->
      <div class="ctb__right">

        <!-- Help -->
        <button class="ctb__icon-btn" @click="openHelp" aria-label="Ayuda" title="Ayuda">
          <HelpCircle :size="20" :stroke-width="1.75" />
          <span v-if="helpDot" class="ctb__help-dot" />
        </button>

        <!-- Bell con notificaciones del cultivador -->
        <DsDropdown v-model="bellOpen" align="right">
          <template #anchor>
            <button
              class="ctb__icon-btn"
              :class="{ 'ctb__icon-btn--alerta': notifCount > 0 }"
              @click="bellOpen = !bellOpen"
              aria-label="Notificaciones"
            >
              <Bell :size="20" :stroke-width="1.75" />
              <span v-if="notifCount > 0" class="ctb__badge">{{ notifCount > 9 ? '9+' : notifCount }}</span>
            </button>
          </template>
          <template #panel>
            <div class="ctb__notif-panel">
              <div class="ctb__notif-header">
                <span class="ctb__notif-title">Alertas ambientales</span>
                <span v-if="notifCount > 0" class="ctb__notif-count">{{ notifCount }} activa{{ notifCount !== 1 ? 's' : '' }}</span>
              </div>
              <DsEmpty
                v-if="!notifCount"
                title="Sin alertas activas."
                class="ctb__notif-empty"
              />
              <div v-else class="ctb__notif-list">
                <RouterLink
                  v-for="a in alertasSlice"
                  :key="a.id"
                  :to="a.sala_id ? { name: 'sala-ambiente', params: { id: a.sala_id } } : '/'"
                  class="ctb__notif-item"
                  @click="bellOpen = false"
                >
                  <span
                    class="ctb__notif-ico"
                    :class="`ctb__notif-ico--${alertaSeveridad(a)}`"
                  >{{ TIPO_ICON[a.tipo] || '⚠️' }}</span>
                  <div class="ctb__notif-body">
                    <div class="ctb__notif-msg">{{ a.regla_nombre || a.tipo }}</div>
                    <div class="ctb__notif-time">{{ formatTime(a.generada_at) }}</div>
                  </div>
                </RouterLink>
              </div>
            </div>
          </template>
        </DsDropdown>

        <!-- Avatar dropdown -->
        <DsDropdown v-model="avatarOpen" align="right">
          <template #anchor>
            <button class="ctb__avatar-btn" @click="avatarOpen = !avatarOpen" aria-label="Menú de usuario">
              <DsAvatar :name="auth.displayName" tone="role-cultivador" size="sm" />
            </button>
          </template>
          <template #panel>
            <div class="ctb__user-panel">
              <div class="ctb__user-header">
                <DsAvatar :name="auth.displayName" tone="role-cultivador" size="md" />
                <div class="ctb__user-info">
                  <div class="ctb__user-name">{{ auth.displayName }}</div>
                  <div class="ctb__user-meta">Cultivador · {{ club.name }}</div>
                </div>
              </div>
              <nav class="ctb__user-menu">
                <RouterLink to="/perfil" class="ctb__user-item" @click="avatarOpen = false">
                  <User :size="14" :stroke-width="1.75" /> Mi perfil
                </RouterLink>
                <div class="ctb__divider"></div>
                <button class="ctb__user-item ctb__user-item--danger" @click="handleLogout">
                  <LogOut :size="14" :stroke-width="1.75" /> Cerrar sesión
                </button>
              </nav>
            </div>
          </template>
        </DsDropdown>

      </div>
    </div>
  </header>

  <HelpDrawer v-model="helpOpen" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { useAlertasBell } from '../../composables/useAlertasBell.js'
import DsDropdown from '../../design-system/components/Dropdown.vue'
import DsAvatar   from '../../design-system/components/Avatar.vue'
import DsEmpty    from '../../design-system/components/EmptyState.vue'
import { Bell, User, LogOut, Menu, HelpCircle } from 'lucide-vue-next'
import HelpDrawer from '../HelpDrawer.vue'

const emit = defineEmits(['open-drawer'])

const route    = useRoute()
const router   = useRouter()
const auth     = useAuthStore()
const club     = useClubStore()
const ambStore = useAmbienteStore()

useAlertasBell()

const bellOpen   = ref(false)
const avatarOpen = ref(false)
const helpOpen   = ref(false)
const helpDot    = ref(false)
onMounted(() => {
  helpDot.value = !localStorage.getItem(`help_seen_${auth.user?.id || 'u'}`)
})
function openHelp() {
  helpOpen.value = true
  if (helpDot.value) {
    helpDot.value = false
    localStorage.setItem(`help_seen_${auth.user?.id || 'u'}`, '1')
  }
}

const notifCount   = computed(() => ambStore.alertasCount)
const alertasSlice = computed(() => ambStore.alertasActivas.slice(0, 6))

const TIPO_ICON = { temperatura: '🌡️', humedad: '💧', vpd: '🌫️', co2: '🌬️', ec: '⚡', ph: '🧪', ppfd: '💡' }
const TIPO_CRITICO = new Set(['temperatura', 'co2'])

function alertaSeveridad(a) {
  if (TIPO_CRITICO.has(a.tipo)) return 'rust'
  if (['humedad', 'vpd'].includes(a.tipo)) return 'amber'
  return 'sky'
}

function formatTime(ts) {
  if (!ts) return ''
  const diff = Date.now() - new Date(ts).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60)  return `hace ${mins}m`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24)   return `hace ${hrs}h`
  return `hace ${Math.floor(hrs / 24)}d`
}

const SEGMENT_LABELS = {
  salas: 'Mis salas', lotes: 'Mis lotes', tareas: 'Tareas',
  perfil: 'Mi perfil', 'sala-ambiente': 'Ambiente',
  ambiente: 'Ambiente',
}

const breadcrumbs = computed(() => {
  const path = route.path
  if (path === '/') return [{ label: 'Inicio' }]
  const segments = path.split('/').filter(Boolean)
  const crumbs = [{ label: 'Inicio', to: '/' }]
  let acc = ''
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i]
    acc += '/' + seg
    if (/^\d+$/.test(seg)) { crumbs.push({ label: 'Detalle' }); break }
    const label = SEGMENT_LABELS[seg] || (seg.charAt(0).toUpperCase() + seg.slice(1).replace(/-/g, ' '))
    const isLast = acc === path
    crumbs.push(isLast ? { label } : { label, to: acc })
  }
  return crumbs
})

async function handleLogout() {
  await auth.logOut()
  club.$reset()
  router.replace('/login')
}
</script>

<style scoped>
.ctb {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--c-paper);
  border-bottom: 1px solid var(--c-ink-300);
  flex-shrink: 0;
}
.ctb__inner {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-6);
  gap: var(--sp-4);
}

/* Breadcrumb */
.ctb__bc { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; flex: 1; }
.ctb__bc-link { font-size: var(--fs-13); color: var(--c-ink-500); text-decoration: none; white-space: nowrap; transition: color var(--t-fast); }
.ctb__bc-link:hover { color: var(--c-ink-900); }
.ctb__bc-sep     { font-size: var(--fs-13); color: var(--c-ink-300); }
.ctb__bc-current { font-size: var(--fs-13); color: var(--c-ink-900); font-weight: 600; }

/* Right */
.ctb__right { display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0; }

/* Bell button */
.ctb__icon-btn {
  position: relative;
  width: 36px;
  height: 36px;
  border-radius: var(--r-md);
  border: 1px solid var(--c-ink-300);
  background: transparent;
  color: var(--c-ink-500);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background var(--t-fast), color var(--t-fast), border-color var(--t-fast);
}
.ctb__icon-btn:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.ctb__icon-btn--alerta { border-color: #fca5a5; background: var(--c-rust-100); color: var(--c-rust-600); }

.ctb__help-dot {
  position: absolute;
  top: 4px; right: 4px;
  width: 7px; height: 7px;
  background: #3b82f6;
  border-radius: 50%;
  border: 1.5px solid var(--c-paper);
}

.ctb__badge {
  position: absolute;
  top: -4px; right: -4px;
  min-width: 18px; height: 18px;
  background: var(--c-rust-600);
  color: #fff;
  font-size: 10px; font-weight: 800;
  border-radius: var(--r-pill);
  display: flex; align-items: center; justify-content: center;
  padding: 0 3px;
  border: 2px solid var(--c-paper);
}

/* Avatar */
.ctb__avatar-btn { background: none; border: none; padding: 0; cursor: pointer; border-radius: 50%; display: flex; }
.ctb__avatar-btn:hover { opacity: .85; }

/* Notif panel */
.ctb__notif-panel { width: 340px; max-height: 440px; overflow-y: auto; }
.ctb__notif-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
  background: var(--c-ink-100);
  position: sticky; top: 0;
}
.ctb__notif-title { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900); }
.ctb__notif-count { font-size: var(--fs-12); font-weight: 700; color: var(--c-rust-600); }
.ctb__notif-empty { padding: var(--sp-4); }
.ctb__notif-list  { display: flex; flex-direction: column; }
.ctb__notif-item {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
  text-decoration: none; color: inherit;
  transition: background var(--t-fast);
}
.ctb__notif-item:last-child { border-bottom: none; }
.ctb__notif-item:hover { background: var(--c-leaf-50); }
.ctb__notif-ico { font-size: 20px; flex-shrink: 0; border-radius: var(--r-sm); padding: 2px; }
.ctb__notif-ico--rust  { background: var(--c-rust-100); }
.ctb__notif-ico--amber { background: var(--c-amber-100); }
.ctb__notif-ico--sky   { background: var(--c-sky-100); }
.ctb__notif-msg  { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.ctb__notif-time { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.ctb__notif-body { flex: 1; min-width: 0; }

/* User panel */
.ctb__user-panel { width: 220px; }
.ctb__user-header { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-3) var(--sp-4); border-bottom: 1px solid var(--c-ink-100); }
.ctb__user-info { flex: 1; min-width: 0; }
.ctb__user-name { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ctb__user-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.ctb__user-menu { display: flex; flex-direction: column; padding: var(--sp-1) 0; }
.ctb__user-item {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4);
  font-size: var(--fs-14); color: var(--c-ink-700);
  text-decoration: none; cursor: pointer;
  background: none; border: none; width: 100%; text-align: left;
  transition: background var(--t-fast), color var(--t-fast);
}
.ctb__user-item:hover { background: var(--c-leaf-50); color: var(--c-ink-900); }
.ctb__user-item--danger { color: var(--c-rust-600); }
.ctb__user-item--danger:hover { background: var(--c-rust-100); color: var(--c-rust-600); }
.ctb__divider { height: 1px; background: var(--c-ink-100); margin: var(--sp-1) 0; }

/* Hamburger: solo visible en tablet (768-1023px) */
.ctb__hamburger {
  display: none;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: var(--r-md);
  border: 1px solid var(--c-ink-300);
  background: transparent;
  color: var(--c-ink-600);
  cursor: pointer;
  flex-shrink: 0;
  transition: background var(--t-fast);
}
.ctb__hamburger:hover { background: var(--c-ink-100); }
@media (max-width: 1023px) { .ctb__hamburger { display: flex; } }

/* Hidden on mobile */
@media (max-width: 767px) { .ctb { display: none; } }
</style>
