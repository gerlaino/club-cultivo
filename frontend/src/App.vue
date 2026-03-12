<script setup>
import { watch, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "./stores/auth";
import { useClubStore } from "./stores/club";
import { usePermissions } from "./composables/usePermissions";
import Avatar from "./components/Avatar.vue";
import BrandLogo from "./components/BrandLogo.vue";

const auth = useAuthStore();
const club = useClubStore();
const router = useRouter();
const { can, isAdmin } = usePermissions();

async function doLogout() {
  await auth.logOut();
  club.$reset();
  router.replace("/login");
}

watch(
  () => auth.isAuthenticated,
  async (logged) => {
    if (logged) {
      try {
        await club.fetch();
      } catch (e) {
        console.error("Error al cargar preferencias del club:", e);
      }
    } else {
      club.$reset();
    }
  },
  { immediate: true }
);

onMounted(async () => {
  await auth.ensureBootstrapped();
  if (auth.isAuthenticated && !club.data) {
    await club.fetch();
  }
});
</script>

<template>
  <div>
    <nav
      class="navbar navbar-expand-lg"
      :class="[$route.meta.fullscreen ? 'navbar-login' : 'navbar-default']"
    >
      <div class="container-fluid">
        <!-- BRAND -->
        <span
          class="navbar-brand fw-semibold d-flex align-items-center gap-2 user-select-none"
        >
          <BrandLogo />
        </span>

        <!-- Toggler mobile -->
        <button
          v-if="auth.isAuthenticated && !$route.meta.fullscreen"
          class="navbar-toggler d-lg-none"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#mainNav"
        >
          <span class="navbar-toggler-icon"></span>
        </button>

        <!-- Contenido navbar -->
        <div
          v-if="auth.isAuthenticated && !$route.meta.fullscreen"
          id="mainNav"
          class="collapse navbar-collapse show"
        >
          <!-- Links con permisos -->
          <ul class="navbar-nav align-items-lg-center mb-2 mb-lg-0 ms-3 gap-lg-2">
            <li class="nav-item">
              <RouterLink class="nav-link" to="/">Dashboard</RouterLink>
            </li>

            <li class="nav-item" v-if="can('salas', 'index')">
              <RouterLink class="nav-link" to="/salas">Salas</RouterLink>
            </li>

            <li class="nav-item" v-if="can('usuarios', 'index')">
              <RouterLink class="nav-link" to="/usuarios">Usuarios</RouterLink>
            </li>

            <li class="nav-item" v-if="can('socios', 'index')">
              <RouterLink class="nav-link" to="/socios">Pacientes</RouterLink>
            </li>

            <li class="nav-item" v-if="can('plantas', 'index')">
              <RouterLink class="nav-link" to="/plantas">Plantas</RouterLink>
            </li>

            <li class="nav-item" v-if="can('geneticas', 'index')">
              <RouterLink class="nav-link" to="/geneticas">Genéticas</RouterLink>
            </li>
          </ul>

          <!-- Menú de usuario -->
          <div class="ms-auto d-flex align-items-center">
            <div class="dropdown" v-if="auth.isAuthenticated">
              <button
                class="btn btn-outline-secondary dropdown-toggle d-flex align-items-center gap-2"
                type="button"
                data-bs-toggle="dropdown"
              >
                <Avatar
                  :src="auth.avatarUrl"
                  :name="auth.displayName"
                  :size="28"
                />
                <span class="fw-medium">{{ auth.displayName }}</span>
              </button>

              <ul class="dropdown-menu dropdown-menu-end shadow-sm">
                <li class="px-3 py-2 border-bottom small text-muted">
                  <div class="d-flex align-items-center gap-2">
                    <Avatar
                      :src="auth.avatarUrl"
                      :name="auth.displayName"
                      :size="36"
                    />
                    <div>
                      <div class="fw-semibold text-dark">
                        {{ auth.displayName }}
                      </div>
                      <div class="text-muted">{{ auth.email }}</div>
                      <div class="badge bg-secondary mt-1">{{ auth.user?.role }}</div>
                    </div>
                  </div>
                </li>

                <li>
                  <RouterLink class="dropdown-item py-2" to="/perfil">
                    Perfil
                  </RouterLink>
                </li>
                <li v-if="isAdmin">
                  <RouterLink class="dropdown-item py-2" to="/preferencias">
                    Preferencias
                  </RouterLink>
                </li>
                <li><hr class="dropdown-divider" /></li>
                <li>
                  <button
                    class="dropdown-item text-danger d-flex align-items-center gap-2"
                    @click="doLogout"
                  >
                    <i class="bi bi-box-arrow-right"></i> Salir
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
    <main v-else class="container my-4">
      <router-view />
    </main>
  </div>
</template>

<style scoped>
.navbar-default {
  background: var(--bs-body-bg);
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
}
.navbar-login {
  background: transparent;
  border: 0;
  padding-top: 0.75rem;
}
</style>
