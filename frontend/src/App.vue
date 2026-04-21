<script setup>
import { watch, onMounted, computed } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "./stores/auth";
import { useClubStore } from "./stores/club";
import { usePermissions } from "./composables/usePermissions";
import { usePlan } from "./composables/usePlan";
import Avatar from "./components/Avatar.vue";
import BrandLogo from "./components/BrandLogo.vue";
import PlanBadge from "./components/PlanBadge.vue";
import AsistenteVoz from "./components/AsistenteVoz.vue";

const auth   = useAuthStore();
const club   = useClubStore();
const router = useRouter();
const route  = useRoute();
const { can, isAdmin } = usePermissions();
const { fetchPlan, planData } = usePlan();

async function doLogout() {
  await auth.logOut();
  club.$reset();
  router.replace("/login");
}

function closeNav() {
  const toggler = document.querySelector('.navbar-toggler')
  if (toggler && getComputedStyle(toggler).display !== 'none') {
    const el = document.getElementById("mainNav")
    if (el) el.classList.remove("show")
  }
}

// Links del bottom nav según rol
const bottomNavLinks = computed(() => {
  const role = auth.user?.role
  if (role === 'cultivador' || role === 'agricultor') {
    return [
      { to: '/',      icon: 'bi-house',           label: 'Inicio' },
      { to: '/sedes', icon: 'bi-building',         label: 'Salas', perm: ['sedes','index'] },
      { to: '/tareas',icon: 'bi-clipboard-check',  label: 'Tareas', perm: ['tareas','index'] },
    ]
  }
  if (role === 'admin') {
    return [
      { to: '/',           icon: 'bi-speedometer2',   label: 'Dashboard' },
      { to: '/sedes',      icon: 'bi-building',       label: 'Sedes',     perm: ['sedes','index'] },
      { to: '/socios',     icon: 'bi-people',         label: 'Pacientes', perm: ['socios','index'] },
      { to: '/tareas',     icon: 'bi-clipboard-check',label: 'Tareas',    perm: ['tareas','index'] },
      { to: '/contabilidad',icon: 'bi-cash-stack',    label: 'Caja',      perm: ['movimientos_contables','index'] },
    ]
  }
  return [
    { to: '/', icon: 'bi-house', label: 'Inicio' },
  ]
})

const mostrarAsistenteVoz = computed(() => {
  const role = auth.user?.role
  return role === 'cultivador' || role === 'agricultor' || role === 'admin'
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
      } catch (e) { console.error("Error club:", e); }
    } else {
      club.$reset();
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
  <div class="app-shell" :class="{ 'app-shell--mobile-nav': auth.isAuthenticated && !$route.meta.fullscreen && auth.user?.role !== 'super_admin' }">

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
              <RouterLink class="nav-link px-2" to="/socios" @click="closeNav">Pacientes</RouterLink>
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
            <li class="nav-item" v-if="isAdmin">
              <RouterLink class="nav-link px-2" to="/web" @click="closeNav">Web</RouterLink>
            </li>
            <li class="nav-item" v-if="can('documentos', 'index')">
              <RouterLink class="nav-link px-2" to="/documentos" @click="closeNav">Documentos</RouterLink>
            </li>
          </ul>

          <div class="ms-auto d-flex align-items-center gap-2 mt-2 mt-lg-0">
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
      <router-view />
    </main>

    <!-- ── BOTTOM NAV MOBILE ── -->
    <nav
      v-if="auth.isAuthenticated && !$route.meta.fullscreen && auth.user?.role !== 'super_admin'"
      class="bottom-nav"
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

      <!-- FAB asistente de voz (centro) -->
      <div v-if="mostrarAsistenteVoz" class="bottom-nav__fab-wrap">
        <AsistenteVoz :mini="true" />
      </div>

      <!-- Más opciones (solo admin) -->
      <div v-if="isAdmin" class="bottom-nav__item bottom-nav__item--more dropdown">
        <button
          class="bottom-nav__item-btn"
          data-bs-toggle="dropdown"
          data-bs-auto-close="true"
        >
          <i class="bi bi-grid bottom-nav__icon"></i>
          <span class="bottom-nav__label">Más</span>
        </button>
        <ul class="dropdown-menu dropdown-menu-end bottom-nav__more-menu shadow border-0">
          <li v-if="can('geneticas', 'index')">
            <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/geneticas">
              <i class="bi bi-diagram-3 text-muted"></i> Genéticas
            </RouterLink>
          </li>
          <li v-if="can('usuarios', 'index')">
            <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/usuarios">
              <i class="bi bi-person-badge text-muted"></i> Usuarios
            </RouterLink>
          </li>
          <li v-if="can('informe_semestral', 'show')">
            <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/informe-semestral">
              <i class="bi bi-file-earmark-text text-muted"></i> Informe REPROCANN
            </RouterLink>
          </li>
          <li v-if="isAdmin">
            <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/web">
              <i class="bi bi-globe text-muted"></i> Web pública
            </RouterLink>
          </li>
          <li v-if="can('documentos', 'index')">
            <RouterLink class="dropdown-item py-2 d-flex align-items-center gap-2" to="/documentos">
              <i class="bi bi-file-earmark text-muted"></i> Documentos
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
/* ── Shell ── */
.app-shell {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.app-shell--mobile-nav .app-main {
  padding-bottom: 72px; /* espacio para bottom nav */
}

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

/* ── Mostrar bottom nav solo en mobile ── */
@media (max-width: 767px) {
  .bottom-nav {
    display: flex;
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
