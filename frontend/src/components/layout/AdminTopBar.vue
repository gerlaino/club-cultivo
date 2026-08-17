<template>
  <header class="atb">
    <div class="atb__inner">

      <!-- Hamburger (mobile/tablet) -->
      <button class="atb__hamburger" aria-label="Abrir menú" @click="emit('toggle-drawer')">
        <Menu :size="20" :stroke-width="1.75" />
      </button>

      <!-- Identidad de la organización (tenant) -->
      <div class="atb__club" :title="club.name">
        <img v-if="club.logoUrl" :src="club.logoUrl" class="atb__club-logo" :alt="club.name" />
        <DsAvatar v-else :name="club.name" tone="role-admin" size="md" />
        <span class="atb__club-name">{{ club.name }}</span>
      </div>
      <span class="atb__club-sep" aria-hidden="true"></span>

      <!-- Sub-pestañas del grupo activo, pegadas al club (el grupo primario vive en el sidebar) -->
      <nav v-if="visibleTabs.length" class="atb__tabs" aria-label="Secciones">
        <RouterLink
          v-for="t in visibleTabs" :key="t.to"
          :to="t.to" class="atb__tab"
          :class="{ 'atb__tab--active': isTabActive(t) }"
        >
          {{ t.label }}
          <span v-if="t.badge && badgeFor(t.badge)" class="atb__tab-badge">{{ badgeFor(t.badge) }}</span>
        </RouterLink>
      </nav>
      <span v-else class="atb__page-title">{{ activeGroup.label }}</span>

      <!-- Right actions -->
      <div class="atb__right">

        <!-- Preguntarle a la organización. Va acá y no adentro de un modal de cultivo: el
             asistente sólo estaba montado en los modales de sala, lote y planta, así que el
             admin no tenía forma de llegar sin abrir un registro de cultivo que no iba a abrir.
             Sin contexto se abre en modo consulta, que es a lo que viene el admin. -->
        <AsistenteVoz v-if="club.data?.features?.ia" :mini="true" class="atb__ia" />

        <!-- Help -->
        <button class="atb__icon-btn" @click="openHelp" aria-label="Ayuda" title="Ayuda">
          <HelpCircle :size="20" :stroke-width="1.75" />
          <span v-if="helpDot" class="atb__help-dot" />
        </button>

        <!-- Notification bell → opens drawer -->
        <button
          class="atb__icon-btn"
          :class="{ 'atb__icon-btn--alerta': notifCount > 0 }"
          @click="notifOpen = true"
          aria-label="Notificaciones"
        >
          <Bell :size="20" :stroke-width="1.75" />
          <span v-if="notifCount > 0" class="atb__badge">{{ notifCount > 9 ? '9+' : notifCount }}</span>
        </button>
        <NotificationDrawer v-model="notifOpen" />

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

                <!-- Push notifications toggle -->
                <button
                  v-if="pushSupported && !pushDenied"
                  class="atb__user-item atb__push-item"
                  :class="{ 'atb__push-item--on': pushSubscribed }"
                  @click="togglePush"
                  :disabled="pushLoading"
                >
                  <BellRing v-if="pushSubscribed" :size="14" :stroke-width="2" />
                  <BellOff  v-else                :size="14" :stroke-width="2" />
                  <span>{{ pushSubscribed ? 'Notificaciones activas' : 'Activar notificaciones' }}</span>
                  <span class="atb__push-dot" :class="pushSubscribed ? 'atb__push-dot--on' : 'atb__push-dot--off'"></span>
                </button>

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

  <HelpDrawer v-model="helpOpen" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import { useAmbienteStore } from '../../stores/ambiente.js'
import { useAlertasBell } from '../../composables/useAlertasBell.js'
import { useAlertasInternas } from '../../composables/useAlertasInternas.js'
import { detectGroup, useNavContext } from '../../composables/useNavContext.js'
import DsDropdown         from '../../design-system/components/Dropdown.vue'
import DsAvatar           from '../../design-system/components/Avatar.vue'
import { Bell, BellRing, BellOff, Menu, HelpCircle } from 'lucide-vue-next'
import { usePushNotifications } from '../../composables/usePushNotifications.js'
import HelpDrawer         from '../HelpDrawer.vue'
import AsistenteVoz       from '../AsistenteVoz.vue'
import NotificationDrawer from '../ui/NotificationDrawer.vue'

const emit = defineEmits(['toggle-drawer'])

const route    = useRoute()
const router   = useRouter()
const auth     = useAuthStore()
const club     = useClubStore()
const ambStore = useAmbienteStore()

useAlertasBell()
const { noLeidas: internasNoLeidas } = useAlertasInternas()

const avatarOpen = ref(false)
const helpOpen   = ref(false)
const notifOpen  = ref(false)
const helpDot    = ref(false)

const {
  supported: pushSupported,
  subscribed: pushSubscribed,
  loading: pushLoading,
  denied: pushDenied,
  subscribe: pushSubscribe,
  unsubscribe: pushUnsubscribe,
} = usePushNotifications()

async function togglePush() {
  pushSubscribed.value ? await pushUnsubscribe() : await pushSubscribe()
}

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

const notifCount = computed(() => ambStore.alertasCount + internasNoLeidas.value.length)

// Grupo activo + tab activo para las sub-pestañas (badges del singleton del sidebar).
const { badgeFor } = useNavContext()
const activeGroup = computed(() => detectGroup(route.path))
// Tabs visibles: oculta las que dependen de un feature flag apagado de la organización (insumos, bar…)
const visibleTabs = computed(() =>
  (activeGroup.value.tabs || []).filter(t => !t.feature || club.data?.features?.[t.feature])
)
function isTabActive(t) {
  let best = null, len = -1
  for (const x of visibleTabs.value) {
    if ((route.path === x.to || route.path.startsWith(x.to + '/')) && x.to.length > len) {
      best = x; len = x.to.length
    }
  }
  return best === t
}

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
  /* iOS/PWA: el contenido no queda bajo el notch (en navegador el inset es 0, sin efecto) */
  padding-top: env(safe-area-inset-top, 0);
}
.atb__inner {
  height: 64px;
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

/* Identidad de la organización */
.atb__club { display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0; min-width: 0; }
.atb__club-logo {
  width: 36px; height: 36px; border-radius: var(--r-md);
  object-fit: contain; padding: 2px; border: 1px solid var(--c-ink-100);
  background: #fff; flex-shrink: 0; box-sizing: border-box;
}
.atb__club-name {
  font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900);
  white-space: nowrap; max-width: 200px; overflow: hidden; text-overflow: ellipsis; letter-spacing: -.01em;
}
.atb__club-sep { width: 1px; height: 24px; background: var(--c-ink-200); flex-shrink: 0; }

@media (max-width: 700px) { .atb__club-name { display: none; } }

/* Sub-pestañas del grupo activo */
.atb__tabs {
  display: flex; align-items: center; gap: 2px; min-width: 0; flex: 1;
  overflow-x: auto; scrollbar-width: none;
}
.atb__tabs::-webkit-scrollbar { display: none; }
.atb__tab {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 6px 12px; border-radius: 8px;
  font-size: var(--fs-14); font-weight: 500; color: var(--c-ink-500);
  text-decoration: none; white-space: nowrap;
  transition: background var(--t-fast), color var(--t-fast);
}
.atb__tab:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.atb__tab--active { background: var(--c-leaf-100, #e9f2e4); color: var(--c-role-admin); font-weight: 700; }
.atb__tab-badge {
  background: #d97706; color: #fff; font-size: 10px; font-weight: 700; line-height: 1;
  padding: 2px 5px; border-radius: 10px; min-width: 15px; text-align: center;
}
.atb__page-title { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); flex: 1; }

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

.atb__ia { display: inline-flex; align-items: center; }
.atb__help-dot {
  position: absolute;
  top: 4px; right: 4px;
  width: 7px; height: 7px;
  background: #3b82f6;
  border-radius: 50%;
  border: 1.5px solid var(--c-paper);
}

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

/* Push toggle */
.atb__push-item {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  color: var(--c-ink-500);
}
.atb__push-item--on { color: var(--c-leaf-700); }
.atb__push-item:disabled { opacity: .6; cursor: wait; }
.atb__push-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  margin-left: auto;
  flex-shrink: 0;
}
.atb__push-dot--on  { background: var(--c-leaf-500); }
.atb__push-dot--off { background: var(--c-ink-300); }
</style>
