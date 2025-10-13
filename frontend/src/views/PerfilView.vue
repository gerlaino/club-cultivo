<template>
  <div class="container-sm" style="max-width:720px">
    <h2 class="mb-3">Perfil</h2>

    <div class="card shadow-sm border-0 mb-3">
      <div class="card-body">
        <div class="row g-3">
          <div class="col-md-6">
            <label class="form-label">Nombre</label>
            <input class="form-control" v-model="firstName" />
          </div>
          <div class="col-md-6">
            <label class="form-label">Apellido</label>
            <input class="form-control" v-model="lastName" />
          </div>
          <div class="col-md-12">
            <label class="form-label">Email</label>
            <input class="form-control" :value="auth.email" disabled />
          </div>
        </div>
        <div class="mt-3 text-end">
          <button class="btn btn-success btn-sm" @click="saveName" :disabled="saving">
            <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
            Guardar cambios
          </button>
        </div>
      </div>
    </div>

    <div class="card shadow-sm border-0">
      <div class="card-body">
        <h5 class="card-title">Cambiar contraseña</h5>
        <div class="row g-3">
          <div class="col-md-6">
            <label class="form-label">Nueva contraseña</label>
            <input type="password" class="form-control" v-model="password" />
          </div>
          <div class="col-md-6">
            <label class="form-label">Confirmación</label>
            <input type="password" class="form-control" v-model="password2" />
          </div>
        </div>
        <div class="mt-3 text-end">
          <button class="btn btn-outline-secondary btn-sm" @click="changePassword" :disabled="changing">
            <span v-if="changing" class="spinner-border spinner-border-sm me-2"></span>
            Actualizar
          </button>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref } from "vue"
import { useAuthStore } from "../stores/auth"

const auth = useAuthStore()
const firstName = ref(auth.user?.first_name || "")
const lastName  = ref(auth.user?.last_name  || "")
const saving = ref(false)

async function saveName(){
  // TODO: POST/PATCH a /users/:id (si querés persistirlo)
  saving.value = true
  try {
    auth.user = { ...auth.user, first_name: firstName.value, last_name: lastName.value }
  } finally { saving.value = false }
}

const password = ref("")
const password2 = ref("")
const changing = ref(false)
async function changePassword(){
  if (password.value.length < 8 || password.value !== password2.value) return
  // TODO: llamar a endpoint de cambio de contraseña
  changing.value = true
  try {
    // await api.post('/users/change_password', { ... })
  } finally { changing.value = false }
}
</script>

