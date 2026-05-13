<template>
  <header class="mtb">
    <div class="mtb__inner">

      <!-- Hamburger (mobile only) -->
      <button
        class="mtb__hamburger"
        aria-label="Abrir menú"
        @click="emit('open-drawer')"
      >
        <Menu :size="20" :stroke-width="1.75" />
      </button>

      <!-- Breadcrumb -->
      <nav class="mtb__bc" aria-label="breadcrumb">
        <template v-for="(crumb, i) in breadcrumbs" :key="i">
          <RouterLink v-if="crumb.to" :to="crumb.to" class="mtb__bc-link">{{ crumb.label }}</RouterLink>
          <span v-else class="mtb__bc-current">{{ crumb.label }}</span>
          <span v-if="i < breadcrumbs.length - 1" class="mtb__bc-sep" aria-hidden="true">/</span>
        </template>
      </nav>

      <!-- Right -->
      <div class="mtb__right">
        <DsDropdown v-model="avatarOpen" align="right">
          <template #anchor>
            <button class="mtb__avatar-btn" @click="avatarOpen = !avatarOpen" aria-label="Menú de usuario">
              <DsAvatar :name="auth.displayName" tone="role-manicura" size="sm" />
            </button>
          </template>
          <template #panel>
            <div class="mtb__user-panel">
              <div class="mtb__user-header">
                <DsAvatar :name="auth.displayName" tone="role-manicura" size="md" />
                <div class="mtb__user-info">
                  <div class="mtb__user-name">{{ auth.displayName }}</div>
                  <div class="mtb__user-meta">Manicura · {{ club.name }}</div>
                </div>
              </div>
              <nav class="mtb__user-menu">
                <RouterLink to="/perfil" class="mtb__user-item" @click="avatarOpen = false">
                  <User :size="14" :stroke-width="1.75" /> Mi perfil
                </RouterLink>
                <div class="mtb__divider"></div>
                <button class="mtb__user-item mtb__user-item--danger" @click="handleLogout">
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

const emit = defineEmits(['open-drawer'])

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const avatarOpen = ref(false)

const SEGMENT_LABELS = {
  mnc:     'Manicura',
  cosecha: 'En Cosecha',
  secado:  'En Manicura',
  curado:  'En Curado',
  stocks:  'Stocks',
  lotes:   'Lotes',
  perfil:  'Mi perfil',
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
.mtb {
  position: sticky;
  top: 0;
  z-index: 100;
  background: var(--c-paper);
  border-bottom: 1px solid var(--c-ink-300);
  flex-shrink: 0;
}
.mtb__inner {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-6);
  gap: var(--sp-4);
}

/* Hamburger */
.mtb__hamburger {
  display: none;
  background: none;
  border: none;
  color: var(--c-ink-700);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
  flex-shrink: 0;
}
@media (max-width: 1023px) { .mtb__hamburger { display: flex; } }

/* Breadcrumb */
.mtb__bc { display: flex; align-items: center; gap: var(--sp-2); min-width: 0; flex: 1; }
.mtb__bc-link    { font-size: var(--fs-13); color: var(--c-ink-500); text-decoration: none; white-space: nowrap; transition: color var(--t-fast); }
.mtb__bc-link:hover { color: var(--c-ink-900); }
.mtb__bc-sep     { font-size: var(--fs-13); color: var(--c-ink-300); }
.mtb__bc-current { font-size: var(--fs-13); color: var(--c-ink-900); font-weight: 600; }

/* Right */
.mtb__right { display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0; }

/* Avatar */
.mtb__avatar-btn { background: none; border: none; padding: 0; cursor: pointer; border-radius: 50%; display: flex; }
.mtb__avatar-btn:hover { opacity: .85; }

/* User panel */
.mtb__user-panel { width: 220px; }
.mtb__user-header { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-3) var(--sp-4); border-bottom: 1px solid var(--c-ink-100); }
.mtb__user-info { flex: 1; min-width: 0; }
.mtb__user-name { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mtb__user-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.mtb__user-menu { display: flex; flex-direction: column; padding: var(--sp-1) 0; }
.mtb__user-item {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4);
  font-size: var(--fs-14); color: var(--c-ink-700);
  text-decoration: none; cursor: pointer;
  background: none; border: none; width: 100%; text-align: left;
  transition: background var(--t-fast), color var(--t-fast);
}
.mtb__user-item:hover { background: var(--c-leaf-50); color: var(--c-ink-900); }
.mtb__user-item--danger { color: var(--c-rust-600); }
.mtb__user-item--danger:hover { background: var(--c-rust-100); color: var(--c-rust-600); }
.mtb__divider { height: 1px; background: var(--c-ink-100); margin: var(--sp-1) 0; }
</style>
