<script setup>
import { useAuthStore } from "./stores/auth"
const auth = useAuthStore()
</script>

<template>
  <div>
    <nav class="navbar navbar-expand-lg bg-body-tertiary border-bottom">
      <div class="container-fluid">
        <a class="navbar-brand fw-semibold" href="#">Club Cultivo</a>

        <button
          class="navbar-toggler"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#mainNav"
          aria-controls="mainNav"
          aria-expanded="false"
          aria-label="Toggle navigation"
        >
          <span class="navbar-toggler-icon"></span>
        </button>

        <div id="mainNav" class="collapse navbar-collapse">
          <ul class="navbar-nav me-auto mb-2 mb-lg-0" v-if="auth.isAuthenticated">
            <li class="nav-item"><router-link class="nav-link" to="/">Dashboard</router-link></li>
            <li class="nav-item"><router-link class="nav-link" to="/salas">Salas</router-link></li>
            <li class="nav-item"><router-link class="nav-link" to="/lotes">Lotes</router-link></li>
          </ul>

          <div class="d-flex align-items-center gap-3 ms-auto">
            <span v-if="auth.isAuthenticated" class="text-muted small d-none d-md-inline">
              {{ auth.email }}
            </span>
            <button
              v-if="auth.isAuthenticated"
              class="btn btn-outline-secondary btn-sm"
              @click="auth.signOut()"
              title="Cerrar sesión"
            >
              <i class="bi bi-box-arrow-right me-1"></i> Salir
            </button>
          </div>
        </div>
      </div>
    </nav>

    <main class="container my-4">
      <router-view />
    </main>
  </div>
</template>


