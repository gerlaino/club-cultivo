<template>
  <header class="dlv-topbar">
    <button class="dlv-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <ClubBrand tone="role-delivery" />
    <span class="dlv-breadcrumb">{{ pageTitle }}</span>
    <div class="dlv-right">
      <button class="dlv-icon-btn" @click="openHelp" aria-label="Ayuda" title="Ayuda">
        <HelpCircle :size="18" :stroke-width="1.75" />
        <span v-if="helpDot" class="dlv-help-dot" />
      </button>
      <span class="dlv-role-badge">Delivery</span>

      <!-- Menú de usuario: el mismo del resto de los roles. El delivery era el único que no
           lo tenía — su "Salir" vivía al fondo del sidebar, que en mobile sólo aparece
           abriendo la hamburguesa, y el delivery trabaja SIEMPRE desde el celular. -->
      <DsDropdown v-model="avatarOpen" align="right">
        <template #anchor>
          <button class="dlv-avatar-btn" @click="avatarOpen = !avatarOpen" aria-label="Menú de usuario">
            <DsAvatar :name="auth.displayName" tone="role-delivery" size="sm" />
          </button>
        </template>
        <template #panel>
          <div class="dlv-user-panel">
            <div class="dlv-user-header">
              <DsAvatar :name="auth.displayName" tone="role-delivery" size="md" />
              <div class="dlv-user-info">
                <div class="dlv-user-name">{{ auth.displayName }}</div>
                <div class="dlv-user-meta">Delivery · {{ club.name }}</div>
              </div>
            </div>
            <nav class="dlv-user-menu">
              <RouterLink to="/perfil" class="dlv-user-item" @click="avatarOpen = false">
                <User :size="14" :stroke-width="1.75" /> Mi perfil
              </RouterLink>
              <div class="dlv-divider"></div>
              <button class="dlv-user-item dlv-user-item--danger" @click="handleLogout">
                <LogOut :size="14" :stroke-width="1.75" /> Cerrar sesión
              </button>
            </nav>
          </div>
        </template>
      </DsDropdown>
    </div>
  </header>

  <HelpDrawer v-model="helpOpen" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Menu, HelpCircle, User, LogOut } from 'lucide-vue-next'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import DsDropdown from '../../design-system/components/Dropdown.vue'
import DsAvatar   from '../../design-system/components/Avatar.vue'
import ClubBrand from './ClubBrand.vue'
import HelpDrawer from '../HelpDrawer.vue'

defineEmits(['open-drawer'])

const auth   = useAuthStore()
const club   = useClubStore()
const route  = useRoute()
const router = useRouter()

const avatarOpen = ref(false)

async function handleLogout() {
  await auth.logOut()
  club.$reset()
  router.replace('/login')
}
const LABELS = { '/delivery': 'Inicio', '/delivery/despachos': 'Despachos' }
const pageTitle = computed(() => LABELS[route.path] || 'Delivery')

const helpOpen = ref(false)
const helpDot  = ref(false)
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
</script>

<style scoped>
.dlv-topbar { height: 54px; display: flex; align-items: center; gap: var(--sp-3); padding: 0 var(--sp-5); background: var(--c-paper); border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0; }
.dlv-hamburger { display: none; background: none; border: none; cursor: pointer; color: var(--c-ink-600); padding: var(--sp-1); border-radius: var(--r-sm); }
.dlv-breadcrumb { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); flex: 1; }
.dlv-right { display: flex; align-items: center; gap: var(--sp-2); }
.dlv-role-badge { background: rgba(26,61,46,.1); color: var(--c-role-delivery); font-size: var(--fs-12); font-weight: 600; padding: 2px 10px; border-radius: 999px; }
.dlv-icon-btn { position: relative; background: none; border: 1px solid var(--c-ink-200); border-radius: var(--r-md); width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: var(--c-ink-500); transition: all .15s; }
.dlv-icon-btn:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.dlv-help-dot { position: absolute; top: 4px; right: 4px; width: 7px; height: 7px; background: #3b82f6; border-radius: 50%; border: 1.5px solid var(--c-paper); }

/* Menú de usuario — mismas medidas que el del dispensador y el de manicura */
.dlv-avatar-btn { background: none; border: none; padding: 0; cursor: pointer; border-radius: 50%; display: flex; }
.dlv-avatar-btn:hover { opacity: .85; }
.dlv-user-panel { width: 220px; }
.dlv-user-header { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-3) var(--sp-4); border-bottom: 1px solid var(--c-ink-100); }
.dlv-user-info { flex: 1; min-width: 0; }
.dlv-user-name { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.dlv-user-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.dlv-user-menu { display: flex; flex-direction: column; padding: var(--sp-1) 0; }
.dlv-user-item {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4);
  font-size: var(--fs-14); color: var(--c-ink-700);
  text-decoration: none; cursor: pointer;
  background: none; border: none; width: 100%; text-align: left;
  transition: background var(--t-fast), color var(--t-fast);
}
.dlv-user-item:hover { background: var(--c-leaf-50); color: var(--c-ink-900); }
.dlv-user-item--danger { color: var(--c-rust-600); }
.dlv-user-item--danger:hover { background: var(--c-rust-100); color: var(--c-rust-600); }
.dlv-divider { height: 1px; background: var(--c-ink-100); margin: var(--sp-1) 0; }

/* En pantallas chicas el badge del rol ya lo dice el panel del avatar: se saca para que la
   barra no se amontone justo donde ahora hay un control más. */
@media (max-width: 1023px) { .dlv-hamburger { display: flex; } }
@media (max-width: 480px) { .dlv-role-badge { display: none; } }
</style>
