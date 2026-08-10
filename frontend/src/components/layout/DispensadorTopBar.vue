<template>
  <header class="dtb">
    <div class="dtb__inner">

      <!-- Hamburger (mobile only) -->
      <button
        class="dtb__hamburger"
        aria-label="Abrir menú"
        @click="emit('open-drawer')"
      >
        <Menu :size="20" :stroke-width="1.75" />
      </button>

      <!-- Identidad de la organización (tenant) -->
      <ClubBrand tone="role-dispensador" />

      <!-- Breadcrumb -->
      <nav class="dtb__bc" aria-label="breadcrumb">
        <template v-for="(crumb, i) in breadcrumbs" :key="i">
          <RouterLink v-if="crumb.to" :to="crumb.to" class="dtb__bc-link">{{ crumb.label }}</RouterLink>
          <span v-else class="dtb__bc-current">{{ crumb.label }}</span>
          <span v-if="i < breadcrumbs.length - 1" class="dtb__bc-sep" aria-hidden="true">/</span>
        </template>
      </nav>

      <!-- Right -->
      <div class="dtb__right">

        <!-- Help -->
        <button class="dtb__icon-btn dtb__help-btn" @click="openHelp" aria-label="Ayuda" title="Ayuda">
          <HelpCircle :size="20" :stroke-width="1.75" />
          <span v-if="helpDot" class="dtb__help-dot" />
        </button>

        <!-- Bell (vacío, sin notificaciones para dispensador por ahora) -->
        <button class="dtb__icon-btn" aria-label="Notificaciones">
          <Bell :size="20" :stroke-width="1.75" />
        </button>

        <!-- Avatar dropdown -->
        <DsDropdown v-model="avatarOpen" align="right">
          <template #anchor>
            <button class="dtb__avatar-btn" @click="avatarOpen = !avatarOpen" aria-label="Menú de usuario">
              <DsAvatar :name="auth.displayName" tone="role-dispensador" size="sm" />
            </button>
          </template>
          <template #panel>
            <div class="dtb__user-panel">
              <div class="dtb__user-header">
                <DsAvatar :name="auth.displayName" tone="role-dispensador" size="md" />
                <div class="dtb__user-info">
                  <div class="dtb__user-name">{{ auth.displayName }}</div>
                  <div class="dtb__user-meta">Dispensador · {{ club.name }}</div>
                </div>
              </div>
              <nav class="dtb__user-menu">
                <RouterLink to="/perfil" class="dtb__user-item" @click="avatarOpen = false">
                  <User :size="14" :stroke-width="1.75" /> Mi perfil
                </RouterLink>
                <div class="dtb__divider"></div>
                <button class="dtb__user-item dtb__user-item--danger" @click="handleLogout">
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
import DsDropdown from '../../design-system/components/Dropdown.vue'
import DsAvatar   from '../../design-system/components/Avatar.vue'
import { Bell, User, LogOut, Menu, HelpCircle } from 'lucide-vue-next'
import ClubBrand from './ClubBrand.vue'
import HelpDrawer from '../HelpDrawer.vue'

const emit = defineEmits(['open-drawer'])

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

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

const SEGMENT_LABELS = {
  historial: 'Historial',
  stock:     'Stock',
  pacientes: 'Pacientes',
  perfil:    'Mi perfil',
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
.dtb {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--c-paper);
  border-bottom: 1px solid var(--c-ink-300);
  flex-shrink: 0;
}
.dtb__inner {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-6);
  gap: var(--sp-4);
}

/* Hamburger */
.dtb__hamburger {
  display: none;
  background: none;
  border: none;
  color: var(--c-ink-700);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
  flex-shrink: 0;
}
@media (max-width: 1023px) { .dtb__hamburger { display: flex; } }

/* Breadcrumb */
.dtb__bc { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; flex: 1; }
.dtb__bc-link    { font-size: var(--fs-13); color: var(--c-ink-500); text-decoration: none; white-space: nowrap; transition: color var(--t-fast); }
.dtb__bc-link:hover { color: var(--c-ink-900); }
.dtb__bc-sep     { font-size: var(--fs-13); color: var(--c-ink-300); }
.dtb__bc-current { font-size: var(--fs-13); color: var(--c-ink-900); font-weight: 600; }

/* Right */
.dtb__right { display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0; }

/* Bell */
.dtb__icon-btn {
  width: 36px; height: 36px;
  border-radius: var(--r-md);
  border: 1px solid var(--c-ink-300);
  background: transparent;
  color: var(--c-ink-500);
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  transition: background var(--t-fast), color var(--t-fast);
}
.dtb__icon-btn:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.dtb__help-btn { position: relative; }
.dtb__help-dot {
  position: absolute;
  top: 4px; right: 4px;
  width: 7px; height: 7px;
  background: #3b82f6;
  border-radius: 50%;
  border: 1.5px solid var(--c-paper);
}

/* Avatar */
.dtb__avatar-btn { background: none; border: none; padding: 0; cursor: pointer; border-radius: 50%; display: flex; }
.dtb__avatar-btn:hover { opacity: .85; }

/* User panel */
.dtb__user-panel { width: 220px; }
.dtb__user-header { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-3) var(--sp-4); border-bottom: 1px solid var(--c-ink-100); }
.dtb__user-info { flex: 1; min-width: 0; }
.dtb__user-name { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.dtb__user-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.dtb__user-menu { display: flex; flex-direction: column; padding: var(--sp-1) 0; }
.dtb__user-item {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4);
  font-size: var(--fs-14); color: var(--c-ink-700);
  text-decoration: none; cursor: pointer;
  background: none; border: none; width: 100%; text-align: left;
  transition: background var(--t-fast), color var(--t-fast);
}
.dtb__user-item:hover { background: var(--c-leaf-50); color: var(--c-ink-900); }
.dtb__user-item--danger { color: var(--c-rust-600); }
.dtb__user-item--danger:hover { background: var(--c-rust-100); color: var(--c-rust-600); }
.dtb__divider { height: 1px; background: var(--c-ink-100); margin: var(--sp-1) 0; }
</style>
