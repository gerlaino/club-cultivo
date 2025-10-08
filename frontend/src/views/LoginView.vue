<!-- frontend/src/views/LoginView.vue -->
<script setup>
import { reactive, computed } from "vue"
import { useAuthStore } from "../stores/auth"

const auth = useAuthStore()
const form = reactive({
  email: "",
  password: "",
})

const canSubmit = computed(() => form.email.trim() !== "" && form.password.trim() !== "" && !auth.loading)

async function onSubmit() {
  if (!canSubmit.value) return
  try {
    await auth.signIn(form.email, form.password)
    // la navegación a dashboard la hace el store tras fetchMe()
  } catch (e) {
    // El store ya setea auth.error = "Credenciales inválidas"
    // acá no necesitamos hacer nada extra
  }
}
</script>

<template>
  <div class="row justify-content-center">
    <div class="col-12 col-sm-8 col-md-5 col-lg-4">
      <div class="card shadow-sm">
        <div class="card-body p-4">
          <h1 class="h4 mb-3 text-center">Ingresar</h1>

          <form @submit.prevent="onSubmit" novalidate>
            <div class="mb-3">
              <label class="form-label" for="email">Email</label>
              <input
                id="email"
                name="email"
                type="email"
                class="form-control"
                v-model.trim="form.email"
                required
                autocomplete="email"
              />
            </div>

            <div class="mb-3">
              <label class="form-label" for="password">Contraseña</label>
              <input
                id="password"
                name="password"
                type="password"
                class="form-control"
                v-model.trim="form.password"
                required
                autocomplete="current-password"
              />
            </div>

            <div v-if="auth.error" class="alert alert-danger py-2">
              {{ auth.error }}
            </div>

            <button
              type="submit"
              class="btn btn-primary w-100"
              :disabled="!canSubmit"
            >
              <span v-if="auth.loading" class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
              {{ auth.loading ? "Ingresando..." : "Entrar" }}
            </button>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

