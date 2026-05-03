<template>
  <header class="ctb">
    <div class="ctb__inner">

      <!-- Breadcrumb -->
      <nav class="ctb__bc" aria-label="breadcrumb">
        <template v-for="(crumb, i) in breadcrumbs" :key="i">
          <RouterLink v-if="crumb.to" :to="crumb.to" class="ctb__bc-link">{{ crumb.label }}</RouterLink>
          <span v-else class="ctb__bc-current">{{ crumb.label }}</span>
          <span v-if="i < breadcrumbs.length - 1" class="ctb__bc-sep" aria-hidden="true">/</span>
        </template>
      </nav>

      <!-- Hamburger (mobile only) -->
      <button class="ctb__hamburger" @click="$emit('toggle-drawer')" aria-label="Abrir menú">
        <Menu :size="20" :stroke-width="1.75" />
      </button>

      <!-- Right -->
      <div class="ctb__right">

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
                  <div class="ctb__user-meta">Supervisor · {{ club.name }}</div>
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
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import DsDropdown from '../../design-system/components/Dropdown.vue'
import DsAvatar   from '../../design-system/components/Avatar.vue'
import { User, LogOut, Menu } from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

defineEmits(['toggle-drawer'])

const avatarOpen = ref(false)

const SEGMENT_LABELS = {
  sedes:     'Mis sedes',
  salas:     'Salas',
  lotes:     'Lotes',
  tareas:    'Tareas',
  geneticas: 'Genéticas',
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

/* Avatar */
.ctb__avatar-btn { background: none; border: none; padding: 0; cursor: pointer; border-radius: 50%; display: flex; }
.ctb__avatar-btn:hover { opacity: .85; }

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

/* Hamburger — only on mobile */
.ctb__hamburger {
  display: none;
  background: none;
  border: none;
  color: var(--c-ink-600);
  cursor: pointer;
  padding: var(--sp-2);
  border-radius: var(--r-md);
  transition: background var(--t-fast);
  flex-shrink: 0;
}
.ctb__hamburger:hover { background: var(--c-ink-100); }
@media (max-width: 1023px) { .ctb__hamburger { display: flex; align-items: center; } }
</style>
