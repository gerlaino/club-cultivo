<script setup>
import { watch, onMounted, computed, ref } from "vue";
import { logger } from './utils/logger.js'
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "./stores/auth";
import { useClubStore } from "./stores/club";
import { useSalasStore } from "./stores/salas";
import { useLotesStore } from "./stores/lotes";
import { usePlantsStore } from "./stores/plants";
import { usePermissions } from "./composables/usePermissions";
import { usePlan } from "./composables/usePlan";
import Avatar from "./components/Avatar.vue";
import BrandLogo from "./components/BrandLogo.vue";
import PlanBadge from "./components/PlanBadge.vue";
import ToastProvider from "./components/ui/ToastProvider.vue";
import ConfirmDialog from "./components/ui/ConfirmDialog.vue";
import NotificationBell from "./components/ui/NotificationBell.vue";
import AuditorBanner from "./components/AuditorBanner.vue";
import AdminSidebar          from "./components/layout/AdminSidebar.vue";
import AdminTopBar            from "./components/layout/AdminTopBar.vue";
import CultivadorSidebar      from "./components/layout/CultivadorSidebar.vue";
import CultivadorTopBar       from "./components/layout/CultivadorTopBar.vue";
import CultivadorMobileHeader from "./components/layout/CultivadorMobileHeader.vue";
import BottomNavCultivador    from "./components/cultivador/BottomNavCultivador.vue";
import SupervisorSidebar      from "./components/layout/SupervisorSidebar.vue";
import SupervisorTopBar       from "./components/layout/SupervisorTopBar.vue";
import DispensadorSidebar     from "./components/layout/DispensadorSidebar.vue";
import DispensadorTopBar      from "./components/layout/DispensadorTopBar.vue";
import ManicuraSidebar        from "./components/layout/ManicuraSidebar.vue";
import ManicuraTopBar         from "./components/layout/ManicuraTopBar.vue";
import MedicoSidebar          from "./components/layout/MedicoSidebar.vue";
import MedicoTopBar           from "./components/layout/MedicoTopBar.vue";
import AbogadoSidebar         from "./components/layout/AbogadoSidebar.vue";
import AbogadoTopBar          from "./components/layout/AbogadoTopBar.vue";
import AuditorSidebar         from "./components/layout/AuditorSidebar.vue";
import AuditorTopBar          from "./components/layout/AuditorTopBar.vue";
import DeliverySidebar        from "./components/layout/DeliverySidebar.vue";
import DeliveryTopBar         from "./components/layout/DeliveryTopBar.vue";

const auth   = useAuthStore();
const club   = useClubStore();
const salas  = useSalasStore();
const lotes  = useLotesStore();
const plants = usePlantsStore();
const router = useRouter();
const route  = useRoute();

const routeLoading = ref(false)
router.beforeEach(() => { routeLoading.value = true })
router.afterEach(() => { routeLoading.value = false })
const { can, isAdmin, isCultivador, isSupervisor, isDispensador, isManicura, isMedico, isAbogado, isAuditor, isDelivery } = usePermissions();

const adminDrawerOpen = ref(false);
const svrDrawerOpen = ref(false);
const dpvDrawerOpen = ref(false);
const mncDrawerOpen = ref(false);
const audDrawerOpen = ref(false);
const medDrawerOpen = ref(false);
const abgDrawerOpen = ref(false);
const dlvDrawerOpen = ref(false);

watch(() => route.path, () => { adminDrawerOpen.value = false; svrDrawerOpen.value = false });
const { fetchPlan, planData } = usePlan();

async function doLogout() {
  await auth.logOut();
  club.$reset();
  salas.$reset();
  lotes.$reset();
  plants.$reset();
  router.replace("/login");
}

function closeNav() {
  const toggler = document.querySelector('.navbar-toggler')
  if (toggler && getComputedStyle(toggler).display !== 'none') {
    const el = document.getElementById("mainNav")
    if (el) el.classList.remove("show")
  }
}

// Master list for bottom nav + "Más" drawer
const ALL_NAV_LINKS = [
  { to: '/',                  icon: 'bi-house',             label: 'Inicio' },
  { to: '/pacientes',         icon: 'bi-people',             label: 'Pacientes',  perm: ['socios','index'] },
  { to: '/sedes',             icon: 'bi-building',           label: 'Sedes',      perm: ['sedes','index'] },
  { to: '/contabilidad',      icon: 'bi-cash-stack',         label: 'Caja',       perm: ['movimientos_contables','index'] },
  { to: '/tareas',            icon: 'bi-clipboard-check',    label: 'Tareas',     perm: ['tareas','index'] },
  { to: '/geneticas',         icon: 'bi-diagram-3',          label: 'Genéticas',  perm: ['geneticas','index'] },
  { to: '/manicura',          icon: 'bi-scissors',           label: 'Manicura',   perm: ['manicura','access'] },
  { to: '/informe-semestral', icon: 'bi-file-earmark-text',  label: 'REPROCANN',  perm: ['informe_semestral','show'] },
  { to: '/documentos',        icon: 'bi-file-earmark',       label: 'Docs',       perm: ['documentos','index'] },
  { to: '/usuarios',          icon: 'bi-person-badge',       label: 'Usuarios',   adminOnly: true },
  { to: '/web',               icon: 'bi-globe',              label: 'Web',        adminOnly: true },
]

// 4 priority paths per role
const ROLE_PRIORITY = {
  admin:       ['/', '/pacientes', '/contabilidad', '/tareas'],
  medico:      ['/', '/pacientes', '/tareas', '/documentos'],
  dispensador: ['/', '/pacientes', '/__dispensario__', '/tareas'],
  cultivador:  ['/', '/sedes', '/tareas', '/geneticas'],
  supervisor:  ['/', '/sedes', '/salas', '/tareas'],
  manicura:    ['/', '/sedes', '/manicura', '/geneticas'],
  abogado:     ['/documentos'],
  auditor:     ['/', '/pacientes', '/informe-semestral'],
  socio:       ['/'],
}

// Sede asignada al dispensador (fallback a primera sede social/mixta via me_controller)
const dispensarioSedeId = computed(() => auth.user?.dispensario_sede_id || null)
const dispensarioLink   = computed(() =>
  dispensarioSedeId.value ? `/sedes/${dispensarioSedeId.value}` : '/sedes'
)

function isAccessible(link) {
  if (link.adminOnly) return isAdmin.value
  if (!link.perm) return true
  return can(link.perm[0], link.perm[1])
}

function resolveLink(path) {
  if (path === '/__dispensario__') {
    return { to: dispensarioLink.value, icon: 'bi-bag-check-fill', label: 'Dispensario' }
  }
  return ALL_NAV_LINKS.find(l => l.to === path) || null
}

const priorityPaths = computed(() => ROLE_PRIORITY[auth.user?.role] || ['/'])

const bottomNavLinks = computed(() =>
  priorityPaths.value
    .map(resolveLink)
    .filter(l => l && isAccessible(l))
)

const moreNavLinks = computed(() => {
  const prioritySet = new Set(priorityPaths.value)
  return ALL_NAV_LINKS.filter(l => !prioritySet.has(l.to) && isAccessible(l))
})


watch(
  () => auth.isAuthenticated,
  async (logged) => {
    if (logged) {
      try {
        if (auth.user?.role !== 'super_admin') {
          await club.fetch();
          await fetchPlan();
        }
      } catch (e) { logger.error("Error club:", e); }
    } else {
      club.$reset();
      salas.$reset();
      lotes.$reset();
      plants.$reset();
      planData.value = null
    }
  },
  { immediate: true }
);

onMounted(async () => {
  await auth.ensureBootstrapped();
  if (auth.isAuthenticated && !club.data && auth.user?.role !== 'super_admin') {
    await club.fetch();
    await fetchPlan();
  }
});
</script>

<template>
  <ToastProvider />
  <ConfirmDialog />
  <div v-if="routeLoading" class="route-loading-bar"></div>
  <div class="app-shell" :class="{ 'app-shell--mobile-nav': auth.isAuthenticated && !$route.meta.fullscreen && auth.user?.role !== 'super_admin' && !isAdmin && !isCultivador && !isSupervisor && !isDispensador && !isManicura && !isMedico && !isAbogado && !isAuditor && !isDelivery }">

    <!-- ── ADMIN LAYOUT (sidebar + topbar, desktop ≥1024px) ── -->
    <template v-if="isAdmin && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="admin-shell">
        <AdminSidebar />
        <div class="admin-body">
          <AdminTopBar @toggle-drawer="adminDrawerOpen = !adminDrawerOpen" />
          <div class="admin-accent-bar"></div>
          <main class="admin-main">
            <router-view />
          </main>
        </div>
      </div>
      <!-- Mobile drawer overlay -->
      <Teleport to="body">
        <Transition name="admin-drawer">
          <div v-if="adminDrawerOpen" class="admin-drawer-overlay" @click.self="adminDrawerOpen = false">
            <div class="admin-drawer">
              <AdminSidebar />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── CULTIVADOR LAYOUT (sidebar + topbar desktop, mobile header + bottom-nav) ── -->
    <template v-else-if="isCultivador && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="cvd-shell">
        <CultivadorSidebar />
        <div class="cvd-body">
          <CultivadorTopBar />
          <CultivadorMobileHeader />
          <div class="cvd-accent-bar"></div>
          <main class="cvd-main">
            <router-view />
          </main>
        </div>
      </div>
      <BottomNavCultivador />
    </template>

    <!-- ── SUPERVISOR LAYOUT (sidebar + topbar desktop, sin mobile bottom-nav) ── -->
    <template v-else-if="isSupervisor && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="svr-shell">
        <SupervisorSidebar />
        <div class="svr-body">
          <SupervisorTopBar @toggle-drawer="svrDrawerOpen = !svrDrawerOpen" />
          <div class="svr-accent-bar"></div>
          <main class="svr-main">
            <router-view />
          </main>
        </div>
      </div>
      <!-- Mobile drawer overlay -->
      <Teleport to="body">
        <Transition name="svr-drawer">
          <div v-if="svrDrawerOpen" class="svr-drawer-overlay" @click.self="svrDrawerOpen = false">
            <div class="svr-drawer">
              <SupervisorSidebar />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── DISPENSADOR LAYOUT (sidebar desktop + topbar con hamburger en mobile) ── -->
    <template v-else-if="isDispensador && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="dpv-shell">
        <DispensadorSidebar />
        <div class="dpv-body">
          <DispensadorTopBar @open-drawer="dpvDrawerOpen = true" />
          <div class="dpv-accent-bar"></div>
          <main class="dpv-main">
            <router-view />
          </main>
        </div>
      </div>
      <!-- Mobile drawer overlay -->
      <Teleport to="body">
        <Transition name="dpv-drawer">
          <div v-if="dpvDrawerOpen" class="dpv-drawer-overlay" @click.self="dpvDrawerOpen = false">
            <div class="dpv-drawer">
              <DispensadorSidebar />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── MANICURA LAYOUT (sidebar + topbar, mismo patrón que dispensador) ── -->
    <template v-else-if="isManicura && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="mnc-shell">
        <ManicuraSidebar />
        <div class="mnc-body">
          <ManicuraTopBar @open-drawer="mncDrawerOpen = true" />
          <div class="mnc-accent-bar"></div>
          <main class="mnc-main">
            <router-view />
          </main>
        </div>
      </div>
      <!-- Mobile drawer overlay -->
      <Teleport to="body">
        <Transition name="mnc-drawer">
          <div v-if="mncDrawerOpen" class="mnc-drawer-overlay" @click.self="mncDrawerOpen = false">
            <div class="mnc-drawer">
              <ManicuraSidebar />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── MEDICO LAYOUT ── -->
    <template v-else-if="isMedico && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="med-shell">
        <MedicoSidebar @logout="doLogout" />
        <div class="med-body">
          <MedicoTopBar @open-drawer="medDrawerOpen = true" />
          <div class="med-accent-bar"></div>
          <main class="med-main">
            <router-view />
          </main>
        </div>
      </div>
      <Teleport to="body">
        <Transition name="med-drawer">
          <div v-if="medDrawerOpen" class="med-drawer-overlay" @click.self="medDrawerOpen = false">
            <div class="med-drawer">
              <MedicoSidebar @logout="doLogout" />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── ABOGADO LAYOUT ── -->
    <template v-else-if="isAbogado && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="abg-shell">
        <AbogadoSidebar @logout="doLogout" />
        <div class="abg-body">
          <AbogadoTopBar @open-drawer="abgDrawerOpen = true" />
          <div class="abg-accent-bar"></div>
          <main class="abg-main">
            <router-view />
          </main>
        </div>
      </div>
      <Teleport to="body">
        <Transition name="abg-drawer">
          <div v-if="abgDrawerOpen" class="abg-drawer-overlay" @click.self="abgDrawerOpen = false">
            <div class="abg-drawer">
              <AbogadoSidebar @logout="doLogout" />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── AUDITOR LAYOUT ── -->
    <template v-else-if="isAuditor && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="aud-shell">
        <AuditorSidebar @logout="doLogout" />
        <div class="aud-body">
          <AuditorTopBar @open-drawer="audDrawerOpen = true" />
          <div class="aud-accent-bar"></div>
          <main class="aud-main">
            <router-view />
          </main>
        </div>
      </div>
      <Teleport to="body">
        <Transition name="aud-drawer">
          <div v-if="audDrawerOpen" class="aud-drawer-overlay" @click.self="audDrawerOpen = false">
            <div class="aud-drawer">
              <AuditorSidebar @logout="doLogout" />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── DELIVERY LAYOUT ── -->
    <template v-else-if="isDelivery && auth.isAuthenticated && !$route.meta.fullscreen">
      <div class="dlv-shell">
        <DeliverySidebar @logout="doLogout" />
        <div class="dlv-body">
          <DeliveryTopBar @open-drawer="dlvDrawerOpen = true" />
          <div class="dlv-accent-bar"></div>
          <main class="dlv-main">
            <router-view />
          </main>
        </div>
      </div>
      <Teleport to="body">
        <Transition name="dlv-drawer">
          <div v-if="dlvDrawerOpen" class="dlv-drawer-overlay" @click.self="dlvDrawerOpen = false">
            <div class="dlv-drawer">
              <DeliverySidebar @logout="doLogout" />
            </div>
          </div>
        </Transition>
      </Teleport>
    </template>

    <!-- ── LAYOUT ESTÁNDAR (todos los demás roles) ── -->
    <template v-else>

    <!-- ── NAVBAR DESKTOP (oculto en mobile) ── -->
    <nav
      v-if="!$route.meta.fullscreen"
      class="navbar navbar-expand-lg navbar-default"
    >
      <div class="container-fluid px-3 px-md-4">

        <RouterLink class="navbar-brand fw-semibold d-flex align-items-center gap-2 text-decoration-none" to="/" @click="closeNav">
          <BrandLogo />
        </RouterLink>

        <!-- Toggler tablet (visible 768-1024) -->
        <button
          v-if="auth.isAuthenticated && auth.user?.role !== 'super_admin'"
          class="navbar-toggler border-0 d-lg-none d-none d-md-flex"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#mainNav"
        >
          <span class="navbar-toggler-icon"></span>
        </button>

        <!-- Nav links desktop -->
        <div
          v-if="auth.isAuthenticated && auth.user?.role !== 'super_admin'"
          id="mainNav"
          class="collapse navbar-collapse"
        >
          <ul class="navbar-nav align-items-lg-center mb-2 mb-lg-0 ms-3 gap-lg-1">
            <li class="nav-item">
              <RouterLink class="nav-link px-2" to="/" @click="closeNav">Dashboard</RouterLink>
            </li>
            <li class="nav-item" v-if="can('sedes', 'index')">
              <RouterLink class="nav-link px-2" to="/sedes" @click="closeNav">Sedes</RouterLink>
            </li>
            <li class="nav-item" v-if="can('socios', 'index')">
              <RouterLink class="nav-link px-2" to="/pacientes" @click="closeNav">Pacientes</RouterLink>
            </li>
            <li class="nav-item" v-if="can('geneticas', 'index')">
              <RouterLink class="nav-link px-2" to="/geneticas" @click="closeNav">Genéticas</RouterLink>
            </li>
            <li class="nav-item" v-if="can('usuarios', 'index')">
              <RouterLink class="nav-link px-2" to="/usuarios" @click="closeNav">Usuarios</RouterLink>
            </li>
            <li class="nav-item" v-if="can('movimientos_contables', 'index')">
              <RouterLink class="nav-link px-2" to="/contabilidad" @click="closeNav">Contabilidad</RouterLink>
            </li>
            <li class="nav-item" v-if="can('informe_semestral', 'show')">
              <RouterLink class="nav-link px-2" to="/informe-semestral" @click="closeNav">Informe REPROCANN</RouterLink>
            </li>
            <li class="nav-item" v-if="can('tareas', 'index')">
              <RouterLink class="nav-link px-2" to="/tareas" @click="closeNav">Tareas</RouterLink>
            </li>
            <li class="nav-item" v-if="can('manicura', 'access')">
              <RouterLink class="nav-link px-2" to="/manicura" @click="closeNav">Manicura</RouterLink>
            </li>
            <li class="nav-item" v-if="isAdmin">
              <RouterLink class="nav-link px-2" to="/web" @click="closeNav">Web</RouterLink>
            </li>
            <li class="nav-item" v-if="can('documentos', 'index')">
              <RouterLink class="nav-link px-2" to="/documentos" @click="closeNav">Documentos</RouterLink>
            </li>
          </ul>

          <div class="ms-auto d-flex align-items-center gap-2 mt-2 mt-lg-0">
            <NotificationBell v-if="auth.isAuthenticated && (auth.user?.role === 'admin' || auth.user?.role === 'cultivador')" />
            <div class="dropdown">
              <button
                class="btn btn-sm btn-outline-secondary dropdown-toggle d-flex align-items-center gap-2 py-1 px-2"
                type="button"
                data-bs-toggle="dropdown"
              >
                <Avatar :src="auth.avatarUrl" :name="auth.displayName" :size="26" />
                <span class="fw-medium d-none d-lg-inline">{{ auth.displayName }}</span>
              </button>

              <ul class="dropdown-menu dropdown-menu-end shadow-sm border-0" style="min-width:240px">
                <li class="px-3 py-2 border-bottom">
                  <div class="d-flex align-items-center gap-2">
                    <Avatar :src="auth.avatarUrl" :name="auth.displayName" :size="36" />
                    <div class="overflow-hidden">
                      <div class="fw-semibold text-dark text-truncate">{{ auth.displayName }}</div>
                      <div class="text-muted small text-truncate">{{ auth.email }}</div>
                      <div class="d-flex gap-1 mt-1">
                        <span class="badge bg-secondary" style="font-size:.68rem">{{ auth.user?.role }}</span>
                        <PlanBadge />
                      </div>
                    </div>
                  </div>
                </li>
                <li>
                  <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/perfil" @click="closeNav">
                    <i class="bi bi-person text-muted"></i> Mi perfil
                  </RouterLink>
                </li>
                <li v-if="isAdmin">
                  <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/preferencias" @click="closeNav">
                    <i class="bi bi-gear text-muted"></i> Preferencias
                  </RouterLink>
                </li>
                <li v-if="isAdmin">
                  <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/documentos/templates" @click="closeNav">
                    <i class="bi bi-file-earmark-text text-muted"></i> Templates
                  </RouterLink>
                </li>
                <li><hr class="dropdown-divider my-1" /></li>
                <li>
                  <button class="dropdown-item py-2 text-danger d-flex align-items-center gap-2" @click="doLogout">
                    <i class="bi bi-box-arrow-right"></i> Cerrar sesión
                  </button>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <!-- Usuario en mobile (solo avatar + logout) -->
        <div v-if="auth.isAuthenticated && auth.user?.role !== 'super_admin'" class="d-flex d-md-none align-items-center gap-2 ms-auto">
          <div class="dropdown">
            <button
              class="btn p-0 border-0 bg-transparent"
              type="button"
              data-bs-toggle="dropdown"
            >
              <Avatar :src="auth.avatarUrl" :name="auth.displayName" :size="32" />
            </button>
            <ul class="dropdown-menu dropdown-menu-end shadow border-0" style="min-width:200px">
              <li class="px-3 py-2 border-bottom">
                <div class="fw-semibold text-dark text-truncate" style="font-size:.85rem">{{ auth.displayName }}</div>
                <div class="text-muted" style="font-size:.72rem">{{ auth.user?.role }}</div>
              </li>
              <li>
                <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/perfil">
                  <i class="bi bi-person text-muted"></i> Mi perfil
                </RouterLink>
              </li>
              <li v-if="isAdmin">
                <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/preferencias">
                  <i class="bi bi-gear text-muted"></i> Preferencias
                </RouterLink>
              </li>
              <li><hr class="dropdown-divider my-1" /></li>
              <li>
                <button class="dropdown-item py-2 text-danger d-flex align-items-center gap-2" @click="doLogout">
                  <i class="bi bi-box-arrow-right"></i> Cerrar sesión
                </button>
              </li>
            </ul>
          </div>
        </div>

      </div>
    </nav>

    <!-- ── CONTENIDO PRINCIPAL ── -->
    <main v-if="$route.meta.fullscreen">
      <router-view />
    </main>
    <main v-else class="app-main">
      <AuditorBanner v-if="auth.user?.role === 'auditor'" />
      <router-view />
    </main>

    </template><!-- /layout estándar -->

    <!-- ── BOTTOM NAV MOBILE (todos los roles autenticados, incl. admin en mobile) ── -->
    <nav
      v-if="auth.isAuthenticated && !$route.meta.fullscreen && auth.user?.role !== 'super_admin' && !isAdmin && !isCultivador && !isSupervisor && !isDispensador && !isManicura && !isMedico && !isAbogado && !isAuditor && !isDelivery"
      class="bottom-nav d-md-none"
    >
      <RouterLink
        v-for="link in bottomNavLinks"
        :key="link.to"
        :to="link.to"
        class="bottom-nav__item"
        :class="{ 'bottom-nav__item--active': $route.path === link.to || ($route.path.startsWith(link.to) && link.to !== '/') }"
        @click="closeNav"
      >
        <i :class="`bi ${link.icon}`" class="bottom-nav__icon"></i>
        <span class="bottom-nav__label">{{ link.label }}</span>
      </RouterLink>

      <!-- Más opciones (cuando hay overflow) -->
      <div v-if="moreNavLinks.length > 0" class="bottom-nav__item bottom-nav__item--more dropdown">
        <button
          class="bottom-nav__item-btn"
          data-bs-toggle="dropdown"
          data-bs-auto-close="true"
        >
          <i class="bi bi-three-dots bottom-nav__icon"></i>
          <span class="bottom-nav__label">Más</span>
        </button>
        <ul class="dropdown-menu dropdown-menu-end bottom-nav__more-menu shadow border-0">
          <li v-for="link in moreNavLinks" :key="link.to">
            <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" :to="link.to">
              <i :class="`bi ${link.icon} text-muted`"></i> {{ link.label }}
            </RouterLink>
          </li>
          <li><hr class="dropdown-divider my-1"></li>
          <li>
            <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/perfil">
              <i class="bi bi-person text-muted"></i> Mi perfil
            </RouterLink>
          </li>
        </ul>
      </div>

    </nav>

  </div>
</template>

<style scoped>
/* ── Route loading bar ── */
.route-loading-bar {
  position: fixed;
  top: 0; left: 0; right: 0;
  height: 3px;
  background: linear-gradient(90deg, #1b5e20, #4ade80, #1b5e20);
  background-size: 200% 100%;
  animation: route-loading-slide 1s linear infinite;
  z-index: 99999;
}
@keyframes route-loading-slide {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* ── Shell ── */
.app-shell {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.app-shell--mobile-nav .app-main {
  padding-bottom: 72px; /* espacio para bottom nav */
}

/* ── Admin layout ── */
.admin-shell {
  display: flex;
  min-height: 100vh;
}

/* Drawer overlay (mobile <1024px) */
.admin-drawer-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 500;
  display: flex;
}
.admin-drawer {
  width: 240px;
  height: 100%;
  overflow: hidden;
}
.admin-drawer :deep(.asb) {
  display: flex !important;
  height: 100%;
  position: static;
}

/* Drawer transition */
.admin-drawer-enter-active,
.admin-drawer-leave-active { transition: opacity .2s, transform .2s; }
.admin-drawer-enter-from,
.admin-drawer-leave-to { opacity: 0; pointer-events: none; }
.admin-drawer-enter-from .admin-drawer,
.admin-drawer-leave-to  .admin-drawer { transform: translateX(-100%); }

/* ── Cultivador layout ── */
.cvd-shell {
  display: flex;
  min-height: 100vh;
}
.cvd-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: var(--c-paper);
}
.cvd-accent-bar {
  height: 4px;
  background: var(--c-role-cultivador);
  flex-shrink: 0;
}
.cvd-main {
  flex: 1;
}
@media (max-width: 767px) {
  .cvd-main { padding-bottom: 80px; }
}
.admin-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: var(--c-paper);
}
.admin-accent-bar {
  height: 4px;
  background: var(--c-role-admin);
  flex-shrink: 0;
}
.admin-main {
  flex: 1;
}
@media (max-width: 767px) {
  .admin-main { padding-bottom: 72px; }
}

/* ── Dispensador layout ── */
.dpv-shell {
  display: flex;
  min-height: 100vh;
}
.dpv-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: var(--c-paper);
}
.dpv-accent-bar {
  height: 4px;
  background: var(--c-role-dispensador);
  flex-shrink: 0;
}
.dpv-main {
  flex: 1;
}

/* Drawer overlay (mobile <1024px) */
/* ── Supervisor drawer (mobile) ── */
.svr-drawer-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 500;
  display: flex;
}
.svr-drawer {
  width: 240px;
  height: 100%;
  overflow: hidden;
}
.svr-drawer :deep(.csb) {
  display: flex !important;
  height: 100%;
  position: static;
}
.svr-drawer-enter-active,
.svr-drawer-leave-active { transition: opacity .2s, transform .2s; }
.svr-drawer-enter-from,
.svr-drawer-leave-to { opacity: 0; pointer-events: none; }
.svr-drawer-enter-from .svr-drawer,
.svr-drawer-leave-to  .svr-drawer { transform: translateX(-100%); }

.dpv-drawer-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 500;
  display: flex;
}
.dpv-drawer {
  width: 240px;
  height: 100%;
  overflow: hidden;
}
.dpv-drawer :deep(.dsb) {
  display: flex !important;
  height: 100%;
  position: static;
}

/* Drawer transition */
.dpv-drawer-enter-active,
.dpv-drawer-leave-active { transition: opacity .2s, transform .2s; }
.dpv-drawer-enter-from,
.dpv-drawer-leave-to { opacity: 0; pointer-events: none; }
.dpv-drawer-enter-from .dpv-drawer,
.dpv-drawer-leave-to  .dpv-drawer { transform: translateX(-100%); }

/* ── Manicura layout ── */
.mnc-shell {
  display: flex;
  min-height: 100vh;
}
.mnc-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: var(--c-paper);
}
.mnc-accent-bar {
  height: 4px;
  background: var(--c-role-manicura);
  flex-shrink: 0;
}
.mnc-main {
  flex: 1;
}

/* Drawer overlay (mobile <1024px) */
.mnc-drawer-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 500;
  display: flex;
}
.mnc-drawer {
  width: 240px;
  height: 100%;
  overflow: hidden;
}
.mnc-drawer :deep(.msb) {
  display: flex !important;
  height: 100%;
  position: static;
}

/* Drawer transition */
.mnc-drawer-enter-active,
.mnc-drawer-leave-active { transition: opacity .2s, transform .2s; }
.mnc-drawer-enter-from,
.mnc-drawer-leave-to { opacity: 0; pointer-events: none; }
.mnc-drawer-enter-from .mnc-drawer,
.mnc-drawer-leave-to  .mnc-drawer { transform: translateX(-100%); }

/* ── Navbar desktop ── */
.navbar-default {
  background: rgba(242, 245, 242, 0.95);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  backdrop-filter: blur(8px);
  position: sticky;
  top: 0;
  z-index: 100;
}
.navbar-nav .nav-link.router-link-active,
.navbar-nav .nav-link.router-link-exact-active {
  color: var(--brand-primary, #1b5e20);
  font-weight: 600;
}

/* ── Bottom Nav ── */
.bottom-nav {
  display: none; /* oculto en desktop */
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 64px;
  background: rgba(255, 255, 255, 0.97);
  backdrop-filter: blur(12px);
  border-top: 1px solid rgba(0, 0, 0, 0.08);
  z-index: 200;
  align-items: center;
  justify-content: space-around;
  padding: 0 4px;
  padding-bottom: env(safe-area-inset-bottom, 0px);
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.06);
}

.bottom-nav__item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  flex: 1;
  height: 100%;
  text-decoration: none;
  color: #94a3b8;
  transition: color .15s;
  min-width: 0;
  padding: 6px 4px;
  position: relative;
}
.bottom-nav__item--active {
  color: #1b5e20;
}
.bottom-nav__item--active::before {
  content: '';
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 32px;
  height: 3px;
  background: #1b5e20;
  border-radius: 0 0 3px 3px;
}
.bottom-nav__icon {
  font-size: 1.25rem;
  line-height: 1;
}
.bottom-nav__label {
  font-size: .6rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: .04em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}

/* FAB asistente de voz centrado */
.bottom-nav__fab-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  flex-shrink: 0;
  margin-bottom: 12px;
}
/* Override del trigger para que sea un círculo grande en el centro */
.bottom-nav__fab-wrap :deep(.av__trigger) {
  width: 52px !important;
  height: 52px !important;
  border-radius: 50% !important;
  padding: 0 !important;
  font-size: 18px !important;
  justify-content: center;
  box-shadow: 0 4px 16px rgba(27, 94, 32, 0.4) !important;
}
.bottom-nav__fab-wrap :deep(.av__trigger-dot) {
  display: none;
}

/* More button */
.bottom-nav__item--more {
  flex: 1;
}
.bottom-nav__item-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  background: none;
  border: none;
  color: #94a3b8;
  width: 100%;
  height: 100%;
  padding: 6px 4px;
  cursor: pointer;
}
.bottom-nav__more-menu {
  bottom: 70px !important;
  top: auto !important;
  right: 8px !important;
  border-radius: 12px !important;
  min-width: 200px;
}

/* ── Médico layout ── */
.med-shell { display: flex; min-height: 100vh; }
.med-body { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--c-paper); }
.med-accent-bar { height: 4px; background: #2D8A6B; flex-shrink: 0; }
.med-main { flex: 1; }
.med-drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 500; display: flex; }
.med-drawer { width: 240px; height: 100%; overflow: hidden; }
.med-drawer-enter-active, .med-drawer-leave-active { transition: opacity .2s, transform .2s; }
.med-drawer-enter-from, .med-drawer-leave-to { opacity: 0; pointer-events: none; }
.med-drawer-enter-from .med-drawer, .med-drawer-leave-to .med-drawer { transform: translateX(-100%); }

/* ── Abogado layout ── */
.abg-shell { display: flex; min-height: 100vh; }
.abg-body { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--c-paper); }
.abg-accent-bar { height: 4px; background: #5B6473; flex-shrink: 0; }
.abg-main { flex: 1; }
.abg-drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 500; display: flex; }
.abg-drawer { width: 240px; height: 100%; overflow: hidden; }
.abg-drawer-enter-active, .abg-drawer-leave-active { transition: opacity .2s, transform .2s; }
.abg-drawer-enter-from, .abg-drawer-leave-to { opacity: 0; pointer-events: none; }
.abg-drawer-enter-from .abg-drawer, .abg-drawer-leave-to .abg-drawer { transform: translateX(-100%); }

/* ── Auditor layout ── */
.aud-shell { display: flex; min-height: 100vh; }
.aud-body { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--c-paper); }
.aud-accent-bar { height: 4px; background: #8B5A2B; flex-shrink: 0; }
.aud-main { flex: 1; }
.aud-drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 500; display: flex; }
.aud-drawer { width: 240px; height: 100%; overflow: hidden; }
.aud-drawer-enter-active, .aud-drawer-leave-active { transition: opacity .2s, transform .2s; }
.aud-drawer-enter-from, .aud-drawer-leave-to { opacity: 0; pointer-events: none; }
.aud-drawer-enter-from .aud-drawer, .aud-drawer-leave-to .aud-drawer { transform: translateX(-100%); }

/* ── Delivery layout ── */
.dlv-shell { display: flex; min-height: 100vh; }
.dlv-body { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--c-paper); }
.dlv-accent-bar { height: 4px; background: var(--c-role-delivery, #1A3A4A); flex-shrink: 0; }
.dlv-main { flex: 1; }
.dlv-drawer-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 500; display: flex; }
.dlv-drawer { width: 200px; height: 100%; overflow: hidden; }
.dlv-drawer-enter-active, .dlv-drawer-leave-active { transition: opacity .2s, transform .2s; }
.dlv-drawer-enter-from, .dlv-drawer-leave-to { opacity: 0; pointer-events: none; }
.dlv-drawer-enter-from .dlv-drawer, .dlv-drawer-leave-to .dlv-drawer { transform: translateX(-100%); }

/* ── Supervisor layout ── */
.svr-shell { display: flex; min-height: 100vh; }
.svr-body { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--c-paper); }
.svr-accent-bar { height: 4px; background: #0f766e; flex-shrink: 0; }
.svr-main { flex: 1; }

/* ── Mostrar bottom nav solo en mobile ── */
@media (max-width: 767px) {
  .bottom-nav {
    display: flex !important;
  }
  /* Ocultar navbar links en mobile, solo mostrar brand + avatar */
  .navbar-default .navbar-collapse {
    display: none !important;
  }
  /* Ajustar padding del contenido principal */
  .app-main {
    padding-bottom: 72px;
  }
}

/* ── Tablet (768px - 1024px) ── */
@media (min-width: 768px) and (max-width: 1023px) {
  .bottom-nav {
    display: none;
  }
  /* Navbar con toggler visible en tablet */
  .navbar-default .navbar-toggler {
    display: flex !important;
  }
}
</style>
