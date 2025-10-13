<template>
  <div class="login-wrap d-flex align-items-stretch min-vh-100 px-3 px-md-4 py-4">
    <!-- IZQUIERDA: tarjeta de login -->
    <div class="flex-fill d-flex align-items-center justify-content-center">
      <div class="login-card card border-0 bg-white" style="max-width: 440px; width:100%;">
        <div class="card-body p-4 p-md-5">
          <h2 class="fw-bold text-center mb-4" style="color: var(--brand-primary)">Ingresar</h2>

          <form @submit.prevent="onSubmit" novalidate>
            <div class="mb-3">
              <label class="form-label">Email</label>
              <input v-model.trim="email" type="email" class="form-control form-control-lg"
                     autocomplete="username" required :disabled="auth.loading">
            </div>

            <div class="mb-3">
              <label class="form-label">Contraseña</label>
              <input v-model="password" type="password" class="form-control form-control-lg"
                     autocomplete="current-password" required :disabled="auth.loading">
            </div>

            <div v-if="auth.error" class="alert alert-danger py-2">{{ auth.error }}</div>

            <button class="btn btn-success w-100 btn-lg"
                    :disabled="auth.loading || !email || !password">
              <span v-if="auth.loading" class="spinner-border spinner-border-sm me-2"></span>
              Entrar
            </button>

            <p class="text-center text-muted small mt-3 mb-0">
              © {{ new Date().getFullYear() }} {{ auth.user?.club_name || 'Cultivo Espacial' }}
            </p>
          </form>
        </div>
      </div>
    </div>

    <!-- DERECHA: novedades -->
    <aside class="login-aside d-none d-lg-flex flex-column justify-content-between p-5 ms-4">
      <div>
        <h4 class="fw-semibold mb-3">Novedades</h4>
        <ul class="list-unstyled mb-0 small">
          <li><span class="badge-dot"></span>Nuevo módulo de <b>Socios</b> en desarrollo.</li>
          <li><span class="badge-dot" style="background:#6ecbff"></span>Mejoras en control de riego automatizado.</li>
          <li><span class="badge-dot" style="background:#f7b267"></span>Integración con inventario en prueba.</li>
        </ul>
      </div>
      <div class="small opacity-75">Versión beta 0.1.0</div>
    </aside>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')

async function onSubmit(){
  try{
    await auth.login(email.value, password.value)
    router.replace(String(route.query.redirect || '/'))
  }catch(_){ /* el store ya setea error */ }
}
</script>




