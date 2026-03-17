<script setup>
import { onMounted, reactive, ref, computed } from 'vue'
import { getProfile, updateProfile, updateMyPassword, uploadAvatar } from '../lib/api'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()

const me            = ref(null)
const avatarPreview = ref(null)
const loading       = ref(true)
const saving        = ref(false)
const passSaving    = ref(false)
const avatarSaving  = ref(false)
const error         = ref(null)
const okMsg         = ref(null)
const pError        = ref(null)
const pOkMsg        = ref(null)
const showCurrent   = ref(false)
const showNew       = ref(false)
const showConfirm   = ref(false)

const form = reactive({
  first_name: '',
  last_name:  '',
  dni:        '',
  birth_date: '',
  email:      '',
  phone:      '',
})

const pass = reactive({
  current_password:      '',
  password:              '',
  password_confirmation: '',
})

const passErrors = reactive({
  current_password:      '',
  password:              '',
  password_confirmation: '',
})

// ── Fortaleza de contraseña ──────────────────────────────────────────
const passwordStrength = computed(() => {
  const p = pass.password
  if (!p) return { score: 0, label: '', color: '' }
  let score = 0
  if (p.length >= 8)                    score++
  if (p.length >= 12)                   score++
  if (/[A-Z]/.test(p))                  score++
  if (/[0-9]/.test(p))                  score++
  if (/[^A-Za-z0-9]/.test(p))          score++
  if      (score <= 1) return { score, label: 'Muy débil',  color: 'danger'  }
  else if (score === 2) return { score, label: 'Débil',      color: 'warning' }
  else if (score === 3) return { score, label: 'Regular',    color: 'info'    }
  else if (score === 4) return { score, label: 'Fuerte',     color: 'primary' }
  else                  return { score, label: 'Muy fuerte', color: 'success' }
})

const strengthWidth = computed(() => `${(passwordStrength.value.score / 5) * 100}%`)

// ── Validaciones ─────────────────────────────────────────────────────
function validatePassword() {
  let ok = true
  passErrors.current_password      = ''
  passErrors.password              = ''
  passErrors.password_confirmation = ''

  if (!pass.current_password.trim()) {
    passErrors.current_password = 'Ingresá tu contraseña actual'
    ok = false
  }
  if (pass.password.length < 8) {
    passErrors.password = 'Mínimo 8 caracteres'
    ok = false
  } else if (passwordStrength.value.score < 2) {
    passErrors.password = 'La contraseña es muy débil'
    ok = false
  }
  if (pass.password !== pass.password_confirmation) {
    passErrors.password_confirmation = 'Las contraseñas no coinciden'
    ok = false
  }
  return ok
}

// ── Fetch perfil ──────────────────────────────────────────────────────
async function fetchProfile() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await getProfile()
    me.value = data.data
    Object.assign(form, {
      first_name: me.value.first_name || '',
      last_name:  me.value.last_name  || '',
      dni:        me.value.dni        || '',
      birth_date: me.value.birth_date || '',
      email:      me.value.email      || '',
      phone:      me.value.phone      || '',
    })
    avatarPreview.value = me.value.avatar_url || null
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e.message
  } finally {
    loading.value = false
  }
}

// ── Guardar datos personales ──────────────────────────────────────────
async function onSave() {
  saving.value  = true
  okMsg.value   = null
  error.value   = null
  try {
    const { data } = await updateProfile({ ...form })
    me.value = data.data
    okMsg.value = '✓ Perfil actualizado correctamente'
    await auth.refreshUser?.()
    setTimeout(() => { okMsg.value = null }, 4000)
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e.message
  } finally {
    saving.value = false
  }
}

// ── Avatar ────────────────────────────────────────────────────────────
function onPickAvatar() {
  document.getElementById('avatarInput').click()
}

function onFileChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  const reader = new FileReader()
  reader.onload = () => { avatarPreview.value = reader.result }
  reader.readAsDataURL(file)
  uploadAvatarNow(file)
}

async function uploadAvatarNow(file) {
  avatarSaving.value = true
  okMsg.value        = null
  error.value        = null
  try {
    const { data } = await uploadAvatar(file)
    me.value = data.data
    avatarPreview.value = data.data.avatar_url
    okMsg.value = '✓ Avatar actualizado'
    await auth.refreshUser?.()
    setTimeout(() => { okMsg.value = null }, 4000)
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e.message
  } finally {
    avatarSaving.value = false
  }
}

// ── Cambiar contraseña ────────────────────────────────────────────────
async function onChangePassword() {
  if (!validatePassword()) return
  pOkMsg.value    = null
  pError.value    = null
  passSaving.value = true
  try {
    await updateMyPassword({ ...pass })
    pOkMsg.value = '✓ Contraseña actualizada correctamente'
    Object.assign(pass, { current_password: '', password: '', password_confirmation: '' })
    setTimeout(() => { pOkMsg.value = null }, 4000)
  } catch (e) {
    pError.value = e?.response?.data?.errors?.join(', ') || 'Error al actualizar la contraseña'
  } finally {
    passSaving.value = false
  }
}

// ── Helpers ───────────────────────────────────────────────────────────
function roleLabel(role) {
  return {
    admin:       'Administrador',
    medico:      'Médico',
    agricultor:  'Agricultor',
    cultivador:  'Cultivador',
    abogado:     'Abogado',
    auditor:     'Auditor',
    socio:       'Socio',
  }[role] || role
}

function initials(first, last) {
  return ((first?.[0] || '') + (last?.[0] || '')).toUpperCase() || '?'
}

onMounted(fetchProfile)
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4" style="max-width:960px">

    <!-- Header -->
    <div class="mb-4">
      <h1 class="h3 fw-bold mb-0">Mi perfil</h1>
      <p class="text-muted small mb-0">Gestioná tu información personal y seguridad de acceso</p>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <template v-else>

      <!-- Alertas globales -->
      <div v-if="error" class="alert alert-danger alert-dismissible d-flex align-items-center gap-2 mb-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <span>{{ error }}</span>
        <button class="btn-close" @click="error=null"></button>
      </div>
      <div v-if="okMsg" class="alert alert-success alert-dismissible d-flex align-items-center gap-2 mb-4" role="alert">
        <i class="bi bi-check-circle-fill"></i>
        <span>{{ okMsg }}</span>
        <button class="btn-close" @click="okMsg=null"></button>
      </div>

      <div class="row g-4">

        <!-- ── Columna izquierda: avatar + info básica ── -->
        <div class="col-12 col-lg-4">

          <!-- Card avatar -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-body text-center py-4">
              <div class="avatar-wrap mx-auto mb-3" @click="onPickAvatar">
                <img
                  v-if="avatarPreview"
                  :src="avatarPreview"
                  class="avatar-img"
                  alt="Avatar"
                />
                <div v-else class="avatar-placeholder">
                  {{ initials(form.first_name, form.last_name) }}
                </div>
                <div class="avatar-overlay">
                  <i class="bi bi-camera-fill"></i>
                </div>
                <div v-if="avatarSaving" class="avatar-loading">
                  <div class="spinner-border spinner-border-sm text-white"></div>
                </div>
              </div>

              <h5 class="fw-bold mb-0">{{ form.first_name }} {{ form.last_name }}</h5>
              <p class="text-muted small mb-2">{{ form.email }}</p>
              <span class="badge rounded-pill px-3" style="background:var(--brand-primary);font-size:.75rem">
                {{ roleLabel(me?.role) }}
              </span>

              <input id="avatarInput" type="file" accept="image/jpeg,image/png,image/webp" class="d-none" @change="onFileChange" />

              <div class="mt-3">
                <button class="btn btn-sm btn-outline-secondary w-100" @click="onPickAvatar" :disabled="avatarSaving">
                  <i class="bi bi-image me-1"></i>
                  {{ avatarSaving ? 'Subiendo...' : 'Cambiar foto' }}
                </button>
                <div class="text-muted" style="font-size:.72rem;margin-top:.4rem">JPG, PNG o WebP · máx 5 MB</div>
              </div>
            </div>
          </div>

          <!-- Info de cuenta (solo lectura) -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent border-0 pt-3 pb-0">
              <strong class="small text-uppercase text-muted" style="letter-spacing:.05em">Cuenta</strong>
            </div>
            <div class="card-body small pt-2">
              <dl class="row mb-0 g-1">
                <dt class="col-5 fw-normal text-muted">ID usuario</dt>
                <dd class="col-7 font-monospace">#{{ me?.id }}</dd>
                <dt class="col-5 fw-normal text-muted">Rol</dt>
                <dd class="col-7">{{ roleLabel(me?.role) }}</dd>
                <dt class="col-5 fw-normal text-muted">Club ID</dt>
                <dd class="col-7 font-monospace">#{{ me?.club_id }}</dd>
              </dl>
            </div>
          </div>

        </div>

        <!-- ── Columna derecha: formularios ── -->
        <div class="col-12 col-lg-8">

          <!-- Datos personales -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-header bg-transparent border-bottom-0 pt-3 pb-0 d-flex align-items-center justify-content-between">
              <div>
                <strong>Datos personales</strong>
                <p class="text-muted small mb-0">Tu nombre, DNI y datos de contacto</p>
              </div>
              <button class="btn btn-success btn-sm px-3" :disabled="saving" @click="onSave">
                <span v-if="saving" class="spinner-border spinner-border-sm me-1"></span>
                <i v-else class="bi bi-check2 me-1"></i>
                {{ saving ? 'Guardando...' : 'Guardar' }}
              </button>
            </div>
            <div class="card-body">
              <div class="row g-3">

                <div class="col-md-6">
                  <label class="form-label small fw-semibold">Nombre <span class="text-danger">*</span></label>
                  <input v-model.trim="form.first_name" class="form-control" placeholder="Tu nombre" />
                </div>

                <div class="col-md-6">
                  <label class="form-label small fw-semibold">Apellido <span class="text-danger">*</span></label>
                  <input v-model.trim="form.last_name" class="form-control" placeholder="Tu apellido" />
                </div>

                <div class="col-md-5">
                  <label class="form-label small fw-semibold">DNI</label>
                  <input v-model.trim="form.dni" class="form-control" placeholder="12.345.678" />
                </div>

                <div class="col-md-4">
                  <label class="form-label small fw-semibold">Fecha de nacimiento</label>
                  <input v-model="form.birth_date" type="date" class="form-control" />
                </div>

                <div class="col-md-3">
                  <label class="form-label small fw-semibold">Teléfono</label>
                  <input v-model.trim="form.phone" class="form-control" placeholder="+54 9 11..." />
                </div>

                <div class="col-12">
                  <label class="form-label small fw-semibold">Email <span class="text-danger">*</span></label>
                  <input v-model.trim="form.email" type="email" class="form-control" placeholder="tu@email.com" />
                  <div class="form-text">Cambiar el email afecta tu acceso al sistema.</div>
                </div>

              </div>
            </div>
          </div>

          <!-- Seguridad / contraseña -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent border-bottom-0 pt-3 pb-0">
              <strong>Seguridad</strong>
              <p class="text-muted small mb-0">Actualizá tu contraseña de acceso</p>
            </div>
            <div class="card-body">

              <div v-if="pError" class="alert alert-danger alert-dismissible d-flex align-items-center gap-2 mb-3" role="alert">
                <i class="bi bi-exclamation-triangle-fill"></i>
                <span>{{ pError }}</span>
                <button class="btn-close" @click="pError=null"></button>
              </div>
              <div v-if="pOkMsg" class="alert alert-success alert-dismissible d-flex align-items-center gap-2 mb-3" role="alert">
                <i class="bi bi-check-circle-fill"></i>
                <span>{{ pOkMsg }}</span>
                <button class="btn-close" @click="pOkMsg=null"></button>
              </div>

              <div class="row g-3">

                <!-- Contraseña actual -->
                <div class="col-12">
                  <label class="form-label small fw-semibold">Contraseña actual <span class="text-danger">*</span></label>
                  <div class="input-group">
                    <input
                      v-model="pass.current_password"
                      :type="showCurrent ? 'text' : 'password'"
                      class="form-control"
                      :class="{ 'is-invalid': passErrors.current_password }"
                      placeholder="Tu contraseña actual"
                      autocomplete="current-password"
                    />
                    <button class="btn btn-outline-secondary" type="button" @click="showCurrent=!showCurrent">
                      <i :class="showCurrent ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                    </button>
                    <div class="invalid-feedback">{{ passErrors.current_password }}</div>
                  </div>
                </div>

                <!-- Nueva contraseña -->
                <div class="col-md-6">
                  <label class="form-label small fw-semibold">Nueva contraseña <span class="text-danger">*</span></label>
                  <div class="input-group">
                    <input
                      v-model="pass.password"
                      :type="showNew ? 'text' : 'password'"
                      class="form-control"
                      :class="{ 'is-invalid': passErrors.password }"
                      placeholder="Mínimo 8 caracteres"
                      autocomplete="new-password"
                    />
                    <button class="btn btn-outline-secondary" type="button" @click="showNew=!showNew">
                      <i :class="showNew ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                    </button>
                    <div class="invalid-feedback">{{ passErrors.password }}</div>
                  </div>
                  <!-- Barra de fortaleza -->
                  <div v-if="pass.password" class="mt-2">
                    <div class="progress" style="height:4px;border-radius:2px">
                      <div
                        class="progress-bar"
                        :class="`bg-${passwordStrength.color}`"
                        :style="{ width: strengthWidth, transition: 'width .3s' }"
                      ></div>
                    </div>
                    <div class="d-flex justify-content-between mt-1">
                      <span class="small" :class="`text-${passwordStrength.color}`">{{ passwordStrength.label }}</span>
                      <span class="small text-muted">{{ pass.password.length }} caracteres</span>
                    </div>
                    <ul class="pass-hints small text-muted mt-1 mb-0 ps-3">
                      <li :class="pass.password.length >= 8 ? 'text-success' : ''">Mínimo 8 caracteres</li>
                      <li :class="/[A-Z]/.test(pass.password) ? 'text-success' : ''">Al menos una mayúscula</li>
                      <li :class="/[0-9]/.test(pass.password) ? 'text-success' : ''">Al menos un número</li>
                    </ul>
                  </div>
                </div>

                <!-- Confirmar contraseña -->
                <div class="col-md-6">
                  <label class="form-label small fw-semibold">Confirmar contraseña <span class="text-danger">*</span></label>
                  <div class="input-group">
                    <input
                      v-model="pass.password_confirmation"
                      :type="showConfirm ? 'text' : 'password'"
                      class="form-control"
                      :class="{
                        'is-invalid': passErrors.password_confirmation,
                        'is-valid': pass.password && pass.password === pass.password_confirmation
                      }"
                      placeholder="Repetí la nueva contraseña"
                      autocomplete="new-password"
                    />
                    <button class="btn btn-outline-secondary" type="button" @click="showConfirm=!showConfirm">
                      <i :class="showConfirm ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                    </button>
                    <div class="invalid-feedback">{{ passErrors.password_confirmation }}</div>
                    <div class="valid-feedback">Las contraseñas coinciden ✓</div>
                  </div>
                </div>

              </div>

              <div class="mt-3 d-flex justify-content-end">
                <button class="btn btn-success px-4" :disabled="passSaving" @click="onChangePassword">
                  <span v-if="passSaving" class="spinner-border spinner-border-sm me-2"></span>
                  <i v-else class="bi bi-shield-lock me-1"></i>
                  {{ passSaving ? 'Actualizando...' : 'Actualizar contraseña' }}
                </button>
              </div>

            </div>
          </div>

        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
/* Avatar interactivo */
.avatar-wrap {
  position: relative;
  width: 110px;
  height: 110px;
  border-radius: 50%;
  cursor: pointer;
  overflow: hidden;
}
.avatar-img,
.avatar-placeholder {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  object-fit: cover;
}
.avatar-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: color-mix(in srgb, var(--brand-primary, #1b5e20) 15%, white);
  color: var(--brand-primary, #1b5e20);
  font-size: 2rem;
  font-weight: 700;
}
.avatar-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0,0,0,.45);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 1.4rem;
  opacity: 0;
  transition: opacity .2s;
  border-radius: 50%;
}
.avatar-wrap:hover .avatar-overlay { opacity: 1; }
.avatar-loading {
  position: absolute;
  inset: 0;
  background: rgba(0,0,0,.5);
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
}

/* Hints de contraseña */
.pass-hints { list-style: none; padding-left: 0; }
.pass-hints li::before { content: '○ '; }
.pass-hints li.text-success::before { content: '✓ '; }
</style>
