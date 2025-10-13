<!-- src/App.vue -->
<script setup>
import { useAuthStore } from "./stores/auth"
import { useRouter } from "vue-router"
import Avatar from "./components/Avatar.vue"

const auth = useAuthStore()
const router = useRouter()

async function doLogout() {
  await auth.logOut()
  router.replace("/login")
}

const appName = "Cultivo Espacial" // nombre visible cuando NO hay sesión
</script>

<template>
  <div>
    <nav
      class="navbar navbar-expand-lg"
      :class="[$route.meta.fullscreen ? 'navbar-login' : 'navbar-default']"
    >
      <div class="container-fluid">
        <!-- Brand (no clickeable) -->
        <span class="navbar-brand fw-semibold d-flex align-items-center gap-2 user-select-none">
      <span class="logo-dot"></span>
      {{ !auth.isAuthenticated ? 'Cultivo Espacial' : (auth.user?.club_name || 'Cultivo Espacial') }}
    </span>

        <!-- Toggler SOLO en mobile -->
        <button
          v-if="auth.isAuthenticated && !$route.meta.fullscreen"
          class="navbar-toggler d-lg-none"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#mainNav"
          aria-controls="mainNav"
          aria-expanded="false"
          aria-label="Toggle navigation"
        >
          <span class="navbar-toggler-icon"></span>
        </button>

        <!-- Contenido del navbar -->
        <div
          v-if="auth.isAuthenticated && !$route.meta.fullscreen"
          id="mainNav"
          class="collapse navbar-collapse show"
        >
          <!-- Links SIEMPRE visibles (pegados al brand) -->
          <ul class="navbar-nav align-items-lg-center mb-2 mb-lg-0 ms-3 gap-lg-2">
            <li class="nav-item">
              <RouterLink class="nav-link" to="/">Dashboard</RouterLink>
            </li>
            <li class="nav-item">
              <RouterLink class="nav-link" to="/salas">Salas</RouterLink>
            </li>
            <li class="nav-item">
              <RouterLink class="nav-link" to="/usuarios">Usuarios</RouterLink>
            </li>
            <li class="nav-item">
              <RouterLink class="nav-link" to="/socios">Socios</RouterLink>
            </li>
          </ul>

          <!-- Menú de usuario a la derecha -->
          <div class="ms-auto d-flex align-items-center">
            <div class="dropdown" v-if="auth.isAuthenticated">
              <button
                class="btn btn-outline-secondary dropdown-toggle d-flex align-items-center gap-2"
                type="button" data-bs-toggle="dropdown" aria-expanded="false"
              >
                <Avatar :src="auth.avatarUrl" :name="auth.displayName" :size="28" />
                <span class="fw-medium">{{ auth.displayName }}</span>
              </button>

              <ul class="dropdown-menu dropdown-menu-end shadow-sm">
                <!-- Cabecera con avatar + nombre + email -->
                <li class="px-3 py-2 border-bottom small text-muted">
                  <div class="d-flex align-items-center gap-2">
                    <Avatar :src="auth.avatarUrl" :name="auth.displayName" :size="36" />
                    <div>
                      <div class="fw-semibold text-dark">{{ auth.displayName }}</div>
                      <div class="text-muted">{{ auth.email }}</div>
                    </div>
                  </div>
                </li>

                <li>
                  <RouterLink class="dropdown-item py-2" to="/perfil">Perfil</RouterLink>
                </li>
                <li v-if="auth.isClubAdmin">
                  <RouterLink class="dropdown-item py-2" to="/preferencias">Preferencias</RouterLink>
                </li>
                <li><hr class="dropdown-divider" /></li>
                <li>
                  <button class="dropdown-item text-danger d-flex align-items-center gap-2" @click="auth.logOut()">
                    <i class="bi bi-box-arrow-right"></i> Salir
                  </button>
                </li>
              </ul>
            </div>

          </div>
        </div>
      </div>
    </nav>


    <!-- Si la ruta es fullscreen (login), no uses container -->
    <main v-if="$route.meta.fullscreen">
      <router-view />
    </main>
    <main v-else class="container my-4">
      <router-view />
    </main>
  </div>
</template>

<style scoped>
.navbar-default{
  background: var(--bs-body-bg);
  border-bottom: 1px solid rgba(0,0,0,.06);
}
.navbar-login{
  background: transparent;
  border: 0;
  padding-top: .75rem;
}
.logo-dot{
  width: .75rem; height: .75rem; display:inline-block; border-radius: 50%;
  background: var(--brand-primary, #2e7d32);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--brand-primary, #2e7d32) 25%, transparent);
}
</style>






