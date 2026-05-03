<template>
  <header class="atb">
    <div class="atb__inner">

      <!-- Hamburger (mobile/tablet) -->
      <button class="atb__hamburger" aria-label="Abrir menú" @click="emit('toggle-drawer')">
        <Menu :size="20" :stroke-width="1.75" />
      </button>

      <!-- Breadcrumb -->
      <nav class="atb__bc" aria-label="breadcrumb">
        <template v-for="(crumb, i) in breadcrumbs" :key="i">
          <RouterLink v-if="crumb.to" :to="crumb.to" class="atb__bc-link">{{ crumb.label }}</RouterLink>
          <span v-else class="atb__bc-current">{{ crumb.label }}</span>
          <span v-if="i < breadcrumbs.length - 1" class="atb__bc-sep" aria-hidden="true">/</span>
        </template>
      </nav>

      <!-- Right actions -->
      <div class="atb__right">

        <!-- Notification bell -->
        <DsDropdown v-model="bellOpen" align="right">
          <template #anchor>
            <button
              class="atb__icon-btn"
              :class="{ 'atb__icon-btn--alerta': notifCount > 0 }"
              @click="bellOpen = !bellOpen"
              aria-label="Notificaciones"
            >
              <Bell :size="20" :stroke-width="1.75" />
              <span v-if="notifCount > 0" class="atb__badge">{{ notifCount > 9 ? '9+' : notifCount }}</span>
            </button>
          </template>
          <template #panel>
            <div class="atb__notif-panel">
              <div class="atb__notif-header">
                <span class="atb__notif-title">Notificaciones</span>
                <span v-if="notifCount > 0" class="atb__notif-count">{{ notifCount }} activa{{ notifCount !== 1 ? 's' : '' }}</span>
              </div>
              <DsEmpty
                v-if="!notifCount"
                title="Estás al día. Nada pendiente."
                class="atb__notif-empty"
              />
              <div v-else class="atb__notif-list">
                <RouterLink
                  v-for="a in alertasSlice"
                  :key="a.id"
                  :to="a.sala_id ? { name: 'sala-ambiente', params: { id: a.sala_id } } : '/'"
                  class="atb__notif-item"
                  @click="bellOpen = false"
                >
                  <span class="atb__notif-ico atb__notif-ico--amber">{{ TIPO_ICON[a.tipo] || '⚠️' }}</span>
                  <div class="atb__notif-body">
                    <div class="atb__notif-msg">{{ a.regla_nombre || a.tipo }}</div>
                    <div class="atb__notif-time">{{ formatTime(a.generada_at) }}</div>
                  </div>
                </RouterLink>
              </div>
            </div>
          </template>
        </DsDropdown>

        <!-- Avatar dropdown -->
        <DsDropdown v-model="avatarOpen" align="right">
          <template #anchor>
            <button class="atb__avatar-btn" @click="avatarOpen = !avatarOpen" aria-label="Menú de usuario">
              <DsAvatar :name="auth.displayName" tone="role-admin" size="sm" />
            </button>
          </template>
          <template #panel>
            <div class="atb__user-panel">
              <div class="atb__user-header">
                <DsAvatar :name="auth.displayName" tone="role-admin" size="md" />
                <div class="atb__user-info">
                  <div class="atb__user-name">{{ auth.displayName }}</div>
                  <div class="atb__user-meta">Admin · {{ club.name }}</div>
                </div>
              </div>
              <nav class="atb__user-menu">
                <RouterLink to="/perfil" class="atb__user-item" @click="avatarOpen = false">
                  <i class="bi bi-person"></i> Mi perfil
                </RouterLink>
                <RouterLink to="/preferencias" class="atb__user-item" @click="avatarOpen = false">
                  <i class="bi bi-gear"></i> Configuración del club
                </RouterLink>
                <div class="atb__divider"></div>
                <button class="atb__user-item atb__user-item--danger" @click="handleLogout">
                  <i class="bi bi-box-arrow-right"></i> Cerrar sesión
                </button>
              </nav>
            </div>
          </template>
        </DsDropdown>

      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { useAlertasBell } from '../../composables/useAlertasBell.js'
import DsDropdown from '../../design-system/components/Dropdown.vue'
import DsAvatar   from '../../design-system/components/Avatar.vue'
import DsEmpty    from '../../design-system/components/EmptyState.vue'
import { Bell, Menu } from 'lucide-vue-next'

const emit = defineEmits(['toggle-drawer'])

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()
const ambStore = useAmbienteStore()

useAlertasBell()

const bellOpen   = ref(false)
const avatarOpen = ref(false)

const notifCount  = computed(() => ambStore.alertasCount)
const alertasSlice = computed(() => ambStore.alertasActivas.slice(0, 5))

const TIPO_ICON = { temperatura: '🌡️', humedad: '💧', vpd: '🌫️', co2: '🌬️', ec: '⚡', ph: '🧪' }

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
  pacientes: 'Pacientes', sedes: 'Sedes', contabilidad: 'Contabilidad',
  tareas: 'Tareas', usuarios: 'Usuarios', geneticas: 'Genéticas',
  manicura: 'Manicura', 'informe-semestral': 'REPROCANN', documentos: 'Documentos',
  perfil: 'Mi perfil', preferencias: 'Preferencias', web: 'Web', nuevo: 'Nuevo',
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
.atb {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--c-paper);
  border-bottom: 1px solid var(--c-ink-300);
  flex-shrink: 0;
}
.atb__inner {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-6);
  gap: var(--sp-4);
}

/* Hamburger — solo visible en tablet/mobile */
.atb__hamburger {
  display: none;
  background: none;
  border: none;
  color: var(--c-ink-700);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  transition: background var(--t-fast), color var(--t-fast);
}
.atb__hamburger:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
@media (max-width: 1023px) { .atb__hamburger { display: flex; } }

/* Breadcrumb */
.atb__bc {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  min-width: 0;
  flex: 1;
}
.atb__bc-link {
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  text-decoration: none;
  white-space: nowrap;
  transition: color var(--t-fast);
}
.atb__bc-link:hover { color: var(--c-ink-900); }
.atb__bc-sep    { font-size: var(--fs-13); color: var(--c-ink-300); }
.atb__bc-current { font-size: var(--fs-13); color: var(--c-ink-900); font-weight: 600; }

/* Right actions */
.atb__right {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  flex-shrink: 0;
}

/* Icon button (bell) */
.atb__icon-btn {
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
.atb__icon-btn:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.atb__icon-btn--alerta { border-color: #fca5a5; background: var(--c-rust-100); color: var(--c-rust-600); }

.atb__badge {
  position: absolute;
  top: -4px;
  right: -4px;
  min-width: 18px;
  height: 18px;
  background: var(--c-rust-600);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
  border-radius: var(--r-pill);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 3px;
  border: 2px solid var(--c-paper);
}

/* Avatar button */
.atb__avatar-btn {
  background: none;
  border: none;
  padding: 0;
  cursor: pointer;
  border-radius: 50%;
  display: flex;
}
.atb__avatar-btn:hover { opacity: .85; }

/* Notification panel */
.atb__notif-panel { width: 360px; max-height: 480px; overflow-y: auto; }
.atb__notif-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
  background: var(--c-ink-100);
  position: sticky;
  top: 0;
}
.atb__notif-title { font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900); }
.atb__notif-count { font-size: var(--fs-12); font-weight: 700; color: var(--c-rust-600); }
.atb__notif-empty { padding: var(--sp-4); }
.atb__notif-list  { display: flex; flex-direction: column; }

.atb__notif-item {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
}
.atb__notif-item:last-child { border-bottom: none; }
.atb__notif-item:hover { background: var(--c-leaf-50); }
.atb__notif-ico { font-size: 20px; flex-shrink: 0; }
.atb__notif-body { flex: 1; min-width: 0; }
.atb__notif-msg  { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.atb__notif-time { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }

/* User panel */
.atb__user-panel { width: 220px; }
.atb__user-header {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  border-bottom: 1px solid var(--c-ink-100);
}
.atb__user-info { flex: 1; min-width: 0; }
.atb__user-name { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.atb__user-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }

.atb__user-menu { display: flex; flex-direction: column; padding: var(--sp-1) 0; }
.atb__user-item {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4);
  font-size: var(--fs-14);
  color: var(--c-ink-700);
  text-decoration: none;
  cursor: pointer;
  background: none;
  border: none;
  width: 100%;
  text-align: left;
  transition: background var(--t-fast), color var(--t-fast);
}
.atb__user-item:hover { background: var(--c-leaf-50); color: var(--c-ink-900); }
.atb__user-item--danger { color: var(--c-rust-600); }
.atb__user-item--danger:hover { background: var(--c-rust-100); color: var(--c-rust-600); }
.atb__divider { height: 1px; background: var(--c-ink-100); margin: var(--sp-1) 0; }
</style>
