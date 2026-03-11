<script setup>
import { onMounted, reactive, ref } from "vue"
import { getProfile, updateProfile, updateMyPassword, uploadAvatar } from "../lib/api"
import { useAuthStore } from "../stores/auth"


const me            = ref(null)
const avatarPreview = ref(null)
const loading       = ref(false)
const saving        = ref(false)
const passSaving    = ref(false)
const error         = ref(null)
const pError        = ref(null)
const okMsg         = ref(null)
const pOkMsg        = ref(null)
const auth          = useAuthStore()

const form = reactive({
  first_name: "",
  last_name: "",
  dni: "",
  birth_date: "",
  email: "",
  phone: ""
})

const pass = reactive({
  current_password: "",
  password: "",
  password_confirmation: ""
})

async function fetchProfile(){
  loading.value = true; error.value = null
  try {
    const { data } = await getProfile()
    me.value = data.data
    Object.assign(form, {
      first_name: me.value.first_name || "",
      last_name: me.value.last_name || "",
      dni: me.value.dni || "",
      birth_date: me.value.birth_date || "",
      email: me.value.email || "",
      phone: me.value.phone || ""
    })
    avatarPreview.value = me.value.avatar_url || null
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(", ") || e.message
  } finally {
    loading.value = false
  }
}

async function onSave(){
  saving.value = true; okMsg.value = null; error.value = null
  try {
    const { data } = await updateProfile({ ...form })
    me.value = data.data
    okMsg.value = "Perfil actualizado"
    await auth.refreshUser?.()
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(", ") || e.message
  } finally {
    saving.value = false
  }
}

function onPickAvatar(){
  document.getElementById("avatarInput").click()
}
function onFileChange(e){
  const file = e.target.files?.[0]
  if (!file) return
  // preview inmediata
  const reader = new FileReader()
  reader.onload = () => { avatarPreview.value = reader.result }
  reader.readAsDataURL(file)
  // subir
  uploadAvatarNow(file)
}
async function uploadAvatarNow(file){
  okMsg.value = null; error.value = null
  try {
    const { data } = await uploadAvatar(file)
    me.value = data.data
    okMsg.value = "Avatar actualizado"
    await auth.refreshUser?.()
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(", ") || e.message
  }
}

async function onChangePassword(){
  pOkMsg.value = null; pError.value = null; passSaving.value = true
  try {
    await updateMyPassword({ ...pass })
    pOkMsg.value = "Contraseña actualizada"
    Object.assign(pass, { current_password:"", password:"", password_confirmation:"" })
  } catch (e) {
    pError.value = e?.response?.data?.errors?.join(", ") || e.message
  } finally {
    passSaving.value = false
  }
}

onMounted(fetchProfile)
</script>

<template>
  <div class="container py-4">
    <h2 class="mb-1">Perfil</h2>
    <div class="text-muted mb-3">Gestioná tu información personal y seguridad.</div>

    <div v-if="loading" class="alert alert-info">Cargando…</div>
    <div v-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-if="okMsg" class="alert alert-success">{{ okMsg }}</div>

    <div class="row g-3">
      <!-- Avatar -->
      <div class="col-12 col-lg-4">
        <div class="card h-100 shadow-sm border-0">
          <div class="card-header bg-white"><strong>Avatar</strong></div>
          <div class="card-body">
            <div class="d-flex flex-column align-items-center gap-3">
              <div class="avatar-xxl rounded-circle overflow-hidden shadow-sm">
                <img :src="avatarPreview || 'https://api.dicebear.com/7.x/initials/svg?seed=' + (form.first_name||'U') + (form.last_name||'S')" class="w-100 h-100 object-fit-cover" alt="avatar">
              </div>
              <input id="avatarInput" type="file" accept="image/*" class="d-none" @change="onFileChange">
              <button class="btn btn-outline-success btn-sm" @click="onPickAvatar">
                <i class="bi bi-image me-1"></i> Cambiar imagen
              </button>
              <div class="text-muted small">JPG/PNG/WebP — máx 5 MB</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Datos personales -->
      <div class="col-12 col-lg-8">
        <div class="card shadow-sm border-0">
          <div class="card-header bg-white d-flex align-items-center justify-content-between">
            <strong>Datos personales</strong>
            <button class="btn btn-success btn-sm" :disabled="saving" @click="onSave">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              Guardar cambios
            </button>
          </div>
          <div class="card-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Nombre</label>
                <input v-model.trim="form.first_name" class="form-control">
              </div>
              <div class="col-md-6">
                <label class="form-label">Apellido</label>
                <input v-model.trim="form.last_name" class="form-control">
              </div>
              <div class="col-md-4">
                <label class="form-label">DNI</label>
                <input v-model.trim="form.dni" class="form-control">
              </div>
              <div class="col-md-4">
                <label class="form-label">Fecha de nacimiento</label>
                <input v-model="form.birth_date" type="date" class="form-control">
              </div>
              <div class="col-md-4">
                <label class="form-label">Teléfono</label>
                <input v-model.trim="form.phone" class="form-control">
              </div>
              <div class="col-md-12">
                <label class="form-label">Email</label>
                <input v-model.trim="form.email" type="email" class="form-control">
              </div>
            </div>
          </div>
        </div>

        <!-- Cambiar contraseña -->
        <div class="card shadow-sm border-0 mt-3">
          <div class="card-header bg-white"><strong>Seguridad</strong></div>
          <div class="card-body">
            <div v-if="pError" class="alert alert-danger">{{ pError }}</div>
            <div v-if="pOkMsg" class="alert alert-success">{{ pOkMsg }}</div>

            <div class="row g-3">
              <div class="col-md-4">
                <label class="form-label">Contraseña actual</label>
                <input v-model.trim="pass.current_password" type="password" class="form-control">
              </div>
              <div class="col-md-4">
                <label class="form-label">Nueva contraseña</label>
                <input v-model.trim="pass.password" type="password" class="form-control">
              </div>
              <div class="col-md-4">
                <label class="form-label">Confirmación</label>
                <input v-model.trim="pass.password_confirmation" type="password" class="form-control">
              </div>
            </div>

            <div class="mt-3">
              <button class="btn btn-outline-success" :disabled="passSaving" @click="onChangePassword">
                <span v-if="passSaving" class="spinner-border spinner-border-sm me-2"></span>
                Actualizar contraseña
              </button>
            </div>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.avatar-xxl { width: 128px; height: 128px; }
</style>


