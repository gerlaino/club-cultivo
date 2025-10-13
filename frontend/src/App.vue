<!-- src/App.vue -->
<script setup>
import { useAuthStore } from "./stores/auth"
import { useRouter } from "vue-router"

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
            <div class="dropdown">
              <button
                class="btn btn-light btn-sm dropdown-toggle"
                type="button"
                data-bs-toggle="dropdown"
                aria-expanded="false"
              >
                {{
                  ([auth.user?.first_name, auth.user?.last_name].filter(Boolean).join(' ')
                    || auth.email
                    || 'Usuario')
                }}
              </button>
              <ul class="dropdown-menu dropdown-menu-end">
                <li class="dropdown-header small text-muted px-3">{{ auth.email }}</li>
                <li><RouterLink class="dropdown-item" to="/perfil">Perfil</RouterLink></li>
                <li><RouterLink class="dropdown-item" to="/preferencias">Preferencias</RouterLink></li>
                <li><hr class="dropdown-divider" /></li>
                <li>
                  <button class="dropdown-item text-danger" @click="doLogout">
                    <i class="bi bi-box-arrow-right me-2"></i>Salir
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






