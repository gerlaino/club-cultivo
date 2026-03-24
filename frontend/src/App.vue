<script setup>
import { watch, onMounted } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuthStore } from "./stores/auth";
import { useClubStore } from "./stores/club";
import { usePermissions } from "./composables/usePermissions";
import { usePlan } from "./composables/usePlan";
import Avatar from "./components/Avatar.vue";
import BrandLogo from "./components/BrandLogo.vue";
import PlanBadge from "./components/PlanBadge.vue";

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
  const el = document.getElementById("mainNav");
  if (el && el.classList.contains("show")) {
    el.classList.remove("show");
  }
}

watch(
  () => auth.isAuthenticated,
  async (logged) => {
    if (logged) {
      try {
        await club.fetch();
        await fetchPlan();
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
  if (auth.isAuthenticated && !club.data) {
    await club.fetch();
    await fetchPlan();
  }
});
</script>

<template>
  <div>
    <nav
      class="navbar navbar-expand-lg"
      :class="[$route.meta.fullscreen ? 'navbar-login' : 'navbar-default']"
    >
      <div class="container-fluid px-3 px-md-4">

        <!-- BRAND -->
        <RouterLink class="navbar-brand fw-semibold d-flex align-items-center gap-2 text-decoration-none" to="/" @click="closeNav">
          <BrandLogo />
        </RouterLink>

        <!-- Toggler mobile -->
        <button
          v-if="auth.isAuthenticated && !$route.meta.fullscreen"
          class="navbar-toggler border-0"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#mainNav"
          aria-controls="mainNav"
          aria-expanded="false"
        >
          <span class="navbar-toggler-icon"></span>
        </button>

        <!-- Contenido navbar -->
        <div
          v-if="auth.isAuthenticated && !$route.meta.fullscreen"
          id="mainNav"
          class="collapse navbar-collapse"
        >
          <!-- Links -->
          <ul class="navbar-nav align-items-lg-center mb-2 mb-lg-0 ms-3 gap-lg-1">

            <li class="nav-item">
              <RouterLink class="nav-link px-2" to="/" @click="closeNav">
                <i class="bi bi-speedometer2 me-1 d-lg-none"></i>Dashboard
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('sedes', 'index')">
              <RouterLink class="nav-link px-2" to="/sedes" @click="closeNav">
                <i class="bi bi-building me-1 d-lg-none"></i>Sedes
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('salas', 'index')">
              <RouterLink class="nav-link px-2" to="/salas" @click="closeNav">
                <i class="bi bi-grid me-1 d-lg-none"></i>Salas
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('lotes', 'index')">
              <RouterLink class="nav-link px-2" to="/lotes" @click="closeNav">
                <i class="bi bi-box-seam me-1 d-lg-none"></i>Lotes
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('plantas', 'index')">
              <RouterLink class="nav-link px-2" to="/plantas" @click="closeNav">
                <i class="bi bi-flower2 me-1 d-lg-none"></i>Plantas
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('socios', 'index')">
              <RouterLink class="nav-link px-2" to="/socios" @click="closeNav">
                <i class="bi bi-people me-1 d-lg-none"></i>Pacientes
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('geneticas', 'index')">
              <RouterLink class="nav-link px-2" to="/geneticas" @click="closeNav">
                <i class="bi bi-diagram-3 me-1 d-lg-none"></i>Genéticas
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('usuarios', 'index')">
              <RouterLink class="nav-link px-2" to="/usuarios" @click="closeNav">
                <i class="bi bi-person-badge me-1 d-lg-none"></i>Usuarios
              </RouterLink>
            </li>
            <li class="nav-item" v-if="can('movimientos_contables', 'index')">
              <RouterLink class="nav-link px-2" to="/contabilidad" @click="closeNav">
                <i class="bi bi-cash-stack me-1 d-lg-none"></i>Contabilidad
              </RouterLink>
            </li>

            <li class="nav-item" v-if="can('informe_semestral', 'show')">
              <RouterLink class="nav-link px-2" to="/informe-semestral" @click="closeNav">
                <i class="bi bi-clipboard-check me-1 d-lg-none"></i>Informe REPROCANN
              </RouterLink>
            </li>

          </ul>

          <!-- Menú de usuario -->
          <div class="ms-auto d-flex align-items-center mt-2 mt-lg-0">
            <div class="dropdown">
              <button
                class="btn btn-sm btn-outline-secondary dropdown-toggle d-flex align-items-center gap-2 py-1 px-2"
                type="button"
                data-bs-toggle="dropdown"
                aria-expanded="false"
              >
                <Avatar :src="auth.avatarUrl" :name="auth.displayName" :size="26" />
                <span class="fw-medium d-none d-lg-inline">{{ auth.displayName }}</span>
              </button>

              <ul class="dropdown-menu dropdown-menu-end shadow-sm border-0" style="min-width:240px">
                <!-- Info usuario -->
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
                  <button
                    class="dropdown-item py-2 text-danger d-flex align-items-center gap-2"
                    @click="doLogout"
                  >
                    <i class="bi bi-box-arrow-right"></i> Cerrar sesión
                  </button>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </nav>

    <!-- Contenido principal -->
    <main v-if="$route.meta.fullscreen">
      <router-view />
    </main>
    <main v-else>
      <router-view />
    </main>
  </div>
</template>

<style scoped>
.navbar-default {
  background: rgba(242, 245, 242, 0.95);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  backdrop-filter: blur(8px);
  position: sticky;
  top: 0;
  z-index: 100;
}
.navbar-login {
  background: transparent;
  border: 0;
  padding-top: 0.75rem;
}
.navbar-nav .nav-link.router-link-active {
  color: var(--brand-primary, #1b5e20);
  font-weight: 600;
}
.navbar-nav .nav-link.router-link-exact-active {
  color: var(--brand-primary, #1b5e20);
  font-weight: 600;
}
</style>

