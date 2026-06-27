<script setup>
import { onMounted, reactive, ref, computed } from 'vue'
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { getProfile, updateProfile, updateMyPassword, uploadAvatar } from '../lib/api'
import { useAuthStore } from '../stores/auth'
import DsSpinner from '../design-system/components/Spinner.vue'

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
  first_name:     '',
  last_name:      '',
  dni:            '',
  birth_date:     '',
  email:          '',
  email_personal: '',
  phone:          '',
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

const passwordStrength = computed(() => {
  const p = pass.password
  if (!p) return { score: 0, label: '', color: '' }
  let score = 0
  if (p.length >= 8)           score++
  if (p.length >= 12)          score++
  if (/[A-Z]/.test(p))         score++
  if (/[0-9]/.test(p))         score++
  if (/[^A-Za-z0-9]/.test(p)) score++
  if      (score <= 1) return { score, label: 'Muy débil',  color: '#ef4444' }
  else if (score === 2) return { score, label: 'Débil',      color: '#f59e0b' }
  else if (score === 3) return { score, label: 'Regular',    color: '#3b82f6' }
  else if (score === 4) return { score, label: 'Fuerte',     color: '#1b5e20' }
  else                  return { score, label: 'Muy fuerte', color: '#15803d' }
})

const strengthWidth = computed(() => `${(passwordStrength.value.score / 5) * 100}%`)

function validatePassword() {
  let ok = true
  passErrors.current_password      = ''
  passErrors.password              = ''
  passErrors.password_confirmation = ''
  if (!pass.current_password.trim()) { passErrors.current_password = 'Ingresá tu contraseña actual'; ok = false }
  if (pass.password.length < 8)      { passErrors.password = 'Mínimo 8 caracteres'; ok = false }
  else if (passwordStrength.value.score < 2) { passErrors.password = 'La contraseña es muy débil'; ok = false }
  if (pass.password !== pass.password_confirmation) { passErrors.password_confirmation = 'Las contraseñas no coinciden'; ok = false }
  return ok
}

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
      email_personal: me.value.email_personal || '',
      phone:      me.value.phone      || '',
    })
    avatarPreview.value = me.value.avatar_url || null
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || e.message
  } finally {
    loading.value = false
  }
}

async function onSave() {
  saving.value = true
  okMsg.value  = null
  error.value  = null
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

function onPickAvatar() { document.getElementById('avatarInput').click() }

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

function roleLabel(role) {
  return { admin: 'Administrador', medico: 'Médico', cultivador: 'Cultivador', abogado: 'Abogado', auditor: 'Auditor', socio: 'Socio' }[role] || role
}

function initials(first, last) {
  return ((first?.[0] || '') + (last?.[0] || '')).toUpperCase() || '?'
}

onMounted(fetchProfile)
</script>

<template>
  <div class="pfl">

    <!-- Header -->
    <div class="pfl__header">
      <h1 class="pfl__title">Mi perfil</h1>
      <p class="pfl__sub">Gestioná tu información personal y seguridad de acceso</p>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="pfl__loading">
      <DsSpinner />
    </div>

    <template v-else>

      <!-- Alertas globales -->
      <div v-if="error" class="pfl__alert pfl__alert--danger">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <span>{{ error }}</span>
        <button class="pfl__alert-close" @click="error=null"><i class="bi bi-x-lg"></i></button>
      </div>
      <div v-if="okMsg" class="pfl__alert pfl__alert--success">
        <i class="bi bi-check-circle-fill"></i>
        <span>{{ okMsg }}</span>
        <button class="pfl__alert-close" @click="okMsg=null"><i class="bi bi-x-lg"></i></button>
      </div>

      <div class="pfl__body">

        <!-- ── Columna izquierda ── -->
        <div class="pfl__aside">

          <!-- Avatar card -->
          <div class="pfl__card pfl__avatar-card">
            <div class="pfl__avatar-wrap" @click="onPickAvatar">
              <img v-if="avatarPreview" :src="avatarPreview" class="pfl__avatar-img" alt="Avatar" />
              <div v-else class="pfl__avatar-placeholder">{{ initials(form.first_name, form.last_name) }}</div>
              <div class="pfl__avatar-overlay"><i class="bi bi-camera-fill"></i></div>
              <div v-if="avatarSaving" class="pfl__avatar-loading">
                <DsSpinner :size="16" />
              </div>
            </div>

            <h5 class="pfl__avatar-name">{{ form.first_name }} {{ form.last_name }}</h5>
            <p class="pfl__avatar-email">{{ form.email }}</p>
            <span class="pfl__role-badge">{{ roleLabel(me?.role) }}</span>

            <input id="avatarInput" type="file" accept="image/jpeg,image/png,image/webp" style="display:none" @change="onFileChange" />

            <button class="pfl__btn-secondary pfl__avatar-btn" @click="onPickAvatar" :disabled="avatarSaving">
              <i class="bi bi-image"></i>
              {{ avatarSaving ? 'Subiendo...' : 'Cambiar foto' }}
            </button>
            <div class="pfl__avatar-hint">JPG, PNG o WebP · máx 5 MB</div>
          </div>

          <!-- Info de cuenta -->
          <div class="pfl__card">
            <div class="pfl__card-section-title">Cuenta</div>
            <dl class="pfl__dl">
              <div class="pfl__dl-row"><dt>ID usuario</dt><dd class="pfl__mono">#{{ me?.id }}</dd></div>
              <div class="pfl__dl-row"><dt>Rol</dt><dd>{{ roleLabel(me?.role) }}</dd></div>
              <div class="pfl__dl-row"><dt>Club ID</dt><dd class="pfl__mono">#{{ me?.club_id }}</dd></div>
            </dl>
          </div>

        </div>

        <!-- ── Columna derecha ── -->
        <div class="pfl__main">

          <!-- Datos personales -->
          <div class="pfl__card pfl__card--form">
            <div class="pfl__card-header">
              <div>
                <div class="pfl__card-title">Datos personales</div>
                <div class="pfl__card-desc">Tu nombre, DNI y datos de contacto</div>
              </div>
              <button class="pfl__btn-primary" :disabled="saving" @click="onSave">
                <DsSpinner v-if="saving" :size="16" />
                <i v-else class="bi bi-check2"></i>
                {{ saving ? 'Guardando...' : 'Guardar' }}
              </button>
            </div>
            <div class="pfl__form-grid">
              <div class="pfl__field">
                <label class="pfl__label">Nombre <span class="pfl__required">*</span></label>
                <input v-model.trim="form.first_name" class="pfl__input" placeholder="Tu nombre" />
              </div>
              <div class="pfl__field">
                <label class="pfl__label">Apellido <span class="pfl__required">*</span></label>
                <input v-model.trim="form.last_name" class="pfl__input" placeholder="Tu apellido" />
              </div>
              <div class="pfl__field">
                <label class="pfl__label">DNI</label>
                <input v-model.trim="form.dni" class="pfl__input" placeholder="12.345.678" />
              </div>
              <div class="pfl__field">
                <label class="pfl__label">Fecha de nacimiento</label>
                <AppDatePicker v-model="form.birth_date" />
              </div>
              <div class="pfl__field">
                <label class="pfl__label">Teléfono</label>
                <input v-model.trim="form.phone" class="pfl__input" placeholder="+54 9 11..." />
              </div>
              <div class="pfl__field pfl__field--full">
                <label class="pfl__label">Usuario de ingreso <span class="pfl__required">*</span></label>
                <input v-model.trim="form.email" type="email" class="pfl__input" placeholder="rol@nombreclub.com" />
                <div class="pfl__hint">Es con lo que iniciás sesión. Cambiarlo afecta tu acceso.</div>
              </div>
              <div class="pfl__field">
                <label class="pfl__label">Email personal</label>
                <input v-model.trim="form.email_personal" type="email" class="pfl__input" placeholder="tu@gmail.com" />
                <div class="pfl__hint">Tu mail real, donde el club puede contactarte.</div>
              </div>
            </div>
          </div>

          <!-- Seguridad -->
          <div class="pfl__card pfl__card--form">
            <div class="pfl__card-header">
              <div>
                <div class="pfl__card-title">Seguridad</div>
                <div class="pfl__card-desc">Actualizá tu contraseña de acceso</div>
              </div>
            </div>

            <div v-if="pError" class="pfl__alert pfl__alert--danger pfl__alert--inline">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ pError }}</span>
              <button class="pfl__alert-close" @click="pError=null"><i class="bi bi-x-lg"></i></button>
            </div>
            <div v-if="pOkMsg" class="pfl__alert pfl__alert--success pfl__alert--inline">
              <i class="bi bi-check-circle-fill"></i>
              <span>{{ pOkMsg }}</span>
              <button class="pfl__alert-close" @click="pOkMsg=null"><i class="bi bi-x-lg"></i></button>
            </div>

            <div class="pfl__form-grid">

              <!-- Contraseña actual -->
              <div class="pfl__field pfl__field--full">
                <label class="pfl__label">Contraseña actual <span class="pfl__required">*</span></label>
                <div class="pfl__input-row">
                  <input
                    v-model="pass.current_password"
                    :type="showCurrent ? 'text' : 'password'"
                    class="pfl__input"
                    :class="{ 'pfl__input--error': passErrors.current_password }"
                    placeholder="Tu contraseña actual"
                    autocomplete="current-password"
                  />
                  <button class="pfl__eye-btn" type="button" @click="showCurrent=!showCurrent">
                    <i :class="showCurrent ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                  </button>
                </div>
                <div v-if="passErrors.current_password" class="pfl__field-error">{{ passErrors.current_password }}</div>
              </div>

              <!-- Nueva contraseña -->
              <div class="pfl__field">
                <label class="pfl__label">Nueva contraseña <span class="pfl__required">*</span></label>
                <div class="pfl__input-row">
                  <input
                    v-model="pass.password"
                    :type="showNew ? 'text' : 'password'"
                    class="pfl__input"
                    :class="{ 'pfl__input--error': passErrors.password }"
                    placeholder="Mínimo 8 caracteres"
                    autocomplete="new-password"
                  />
                  <button class="pfl__eye-btn" type="button" @click="showNew=!showNew">
                    <i :class="showNew ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                  </button>
                </div>
                <div v-if="passErrors.password" class="pfl__field-error">{{ passErrors.password }}</div>
                <div v-if="pass.password" class="pfl__strength">
                  <div class="pfl__strength-bar-wrap">
                    <div class="pfl__strength-bar" :style="{ width: strengthWidth, background: passwordStrength.color, transition: 'width .3s' }"></div>
                  </div>
                  <div class="pfl__strength-row">
                    <span :style="{ color: passwordStrength.color, fontSize: '.8rem', fontWeight: 600 }">{{ passwordStrength.label }}</span>
                    <span class="pfl__strength-chars">{{ pass.password.length }} caracteres</span>
                  </div>
                  <ul class="pfl__hints">
                    <li :class="pass.password.length >= 8 ? 'pfl__hint--ok' : ''">Mínimo 8 caracteres</li>
                    <li :class="/[A-Z]/.test(pass.password) ? 'pfl__hint--ok' : ''">Al menos una mayúscula</li>
                    <li :class="/[0-9]/.test(pass.password) ? 'pfl__hint--ok' : ''">Al menos un número</li>
                  </ul>
                </div>
              </div>

              <!-- Confirmar contraseña -->
              <div class="pfl__field">
                <label class="pfl__label">Confirmar contraseña <span class="pfl__required">*</span></label>
                <div class="pfl__input-row">
                  <input
                    v-model="pass.password_confirmation"
                    :type="showConfirm ? 'text' : 'password'"
                    class="pfl__input"
                    :class="{
                      'pfl__input--error': passErrors.password_confirmation,
                      'pfl__input--ok': pass.password && pass.password === pass.password_confirmation
                    }"
                    placeholder="Repetí la nueva contraseña"
                    autocomplete="new-password"
                  />
                  <button class="pfl__eye-btn" type="button" @click="showConfirm=!showConfirm">
                    <i :class="showConfirm ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
                  </button>
                </div>
                <div v-if="passErrors.password_confirmation" class="pfl__field-error">{{ passErrors.password_confirmation }}</div>
                <div v-else-if="pass.password && pass.password === pass.password_confirmation" class="pfl__field-ok">Las contraseñas coinciden ✓</div>
              </div>

            </div>

            <div class="pfl__form-actions">
              <button class="pfl__btn-primary" :disabled="passSaving" @click="onChangePassword">
                <DsSpinner v-if="passSaving" :size="16" />
                <i v-else class="bi bi-shield-lock"></i>
                {{ passSaving ? 'Actualizando...' : 'Actualizar contraseña' }}
              </button>
            </div>

          </div>

        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
/* Layout */
.pfl { padding: 2rem 1.75rem 3rem; max-width: 960px; margin: 0 auto; }
@media (max-width: 768px) { .pfl { padding: 1.25rem 1rem 2rem; } }

/* Header */
.pfl__header { margin-bottom: 1.5rem; }
.pfl__title  { font-size: 1.5rem; font-weight: 700; color: #0f172a; margin: 0 0 .15rem; }
.pfl__sub    { font-size: .82rem; color: #64748b; margin: 0; }

/* Loading */
.pfl__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

/* Spinner */

/* Alerts */
.pfl__alert { display: flex; align-items: center; gap: .65rem; padding: .75rem 1rem; border-radius: 10px; margin-bottom: 1rem; font-size: .875rem; }
.pfl__alert--danger  { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; }
.pfl__alert--success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; }
.pfl__alert--inline  { margin-bottom: 1rem; }
.pfl__alert-close    { margin-left: auto; background: none; border: none; cursor: pointer; color: inherit; opacity: .6; padding: .1rem; }
.pfl__alert-close:hover { opacity: 1; }

/* 2-col body */
.pfl__body  { display: grid; grid-template-columns: 280px 1fr; gap: 1.5rem; align-items: start; }
@media (max-width: 768px) { .pfl__body { grid-template-columns: 1fr; } }

/* Cards */
.pfl__card { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; margin-bottom: 1rem; }
.pfl__card--form { padding: 1.25rem; }

/* Avatar card */
.pfl__avatar-card { text-align: center; }
.pfl__avatar-wrap { position: relative; width: 110px; height: 110px; border-radius: 50%; cursor: pointer; overflow: hidden; margin: 0 auto 1rem; }
.pfl__avatar-img  { width: 100%; height: 100%; object-fit: cover; border-radius: 50%; }
.pfl__avatar-placeholder { width: 100%; height: 100%; border-radius: 50%; display: flex; align-items: center; justify-content: center; background: color-mix(in srgb, #1b5e20 15%, white); color: #1b5e20; font-size: 2rem; font-weight: 700; }
.pfl__avatar-overlay { position: absolute; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; color: white; font-size: 1.4rem; opacity: 0; transition: opacity .2s; border-radius: 50%; }
.pfl__avatar-wrap:hover .pfl__avatar-overlay { opacity: 1; }
.pfl__avatar-loading { position: absolute; inset: 0; background: rgba(0,0,0,.5); display: flex; align-items: center; justify-content: center; border-radius: 50%; }
.pfl__avatar-name  { font-weight: 700; font-size: 1rem; color: #0f172a; margin: 0 0 .2rem; }
.pfl__avatar-email { font-size: .82rem; color: #64748b; margin: 0 0 .5rem; }
.pfl__role-badge   { display: inline-block; background: #1a3d2e; color: #fff; border-radius: 99px; padding: .25rem .8rem; font-size: .75rem; font-weight: 600; margin-bottom: .75rem; }
.pfl__avatar-btn   { width: 100%; margin-bottom: .25rem; }
.pfl__avatar-hint  { font-size: .7rem; color: #94a3b8; }

/* Account info */
.pfl__card-section-title { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: #94a3b8; margin-bottom: .75rem; }
.pfl__dl     { display: flex; flex-direction: column; gap: .5rem; }
.pfl__dl-row { display: flex; justify-content: space-between; align-items: center; font-size: .82rem; }
.pfl__dl-row dt { color: #64748b; font-weight: 400; }
.pfl__dl-row dd { margin: 0; color: #0f172a; font-weight: 500; }
.pfl__mono { font-family: monospace; }

/* Card headers */
.pfl__card-header { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; margin-bottom: 1.25rem; }
.pfl__card-title  { font-size: .95rem; font-weight: 700; color: #0f172a; }
.pfl__card-desc   { font-size: .78rem; color: #64748b; margin-top: .1rem; }

/* Form grid */
.pfl__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }
@media (max-width: 560px) { .pfl__form-grid { grid-template-columns: 1fr; } }
.pfl__field      { display: flex; flex-direction: column; gap: .3rem; }
.pfl__field--full { grid-column: 1 / -1; }

/* Inputs */
.pfl__label       { font-size: .8rem; font-weight: 600; color: #374151; }
.pfl__required    { color: #dc2626; }
.pfl__input       { padding: .55rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; width: 100%; box-sizing: border-box; }
.pfl__input:focus { border-color: #1a3d2e; }
.pfl__input--error { border-color: #ef4444; }
.pfl__input--ok   { border-color: #22c55e; }
.pfl__hint        { font-size: .75rem; color: #64748b; }
.pfl__field-error { font-size: .78rem; color: #ef4444; }
.pfl__field-ok    { font-size: .78rem; color: #15803d; }

/* Password reveal */
.pfl__input-row { display: flex; gap: 0; }
.pfl__input-row .pfl__input { border-radius: 8px 0 0 8px; flex: 1; }
.pfl__eye-btn { padding: 0 .75rem; border: 1.5px solid #e2e8f0; border-left: none; border-radius: 0 8px 8px 0; background: #fff; color: #64748b; cursor: pointer; transition: background .15s; }
.pfl__eye-btn:hover { background: #f8fafc; }

/* Strength bar */
.pfl__strength { margin-top: .5rem; }
.pfl__strength-bar-wrap { height: 4px; background: #e2e8f0; border-radius: 2px; overflow: hidden; margin-bottom: .35rem; }
.pfl__strength-bar { height: 100%; border-radius: 2px; }
.pfl__strength-row { display: flex; justify-content: space-between; margin-bottom: .25rem; }
.pfl__strength-chars { font-size: .78rem; color: #94a3b8; }
.pfl__hints { list-style: none; padding: 0; margin: .25rem 0 0; display: flex; flex-direction: column; gap: .15rem; }
.pfl__hints li { font-size: .78rem; color: #94a3b8; }
.pfl__hints li::before { content: '○ '; }
.pfl__hints li.pfl__hint--ok { color: #15803d; }
.pfl__hints li.pfl__hint--ok::before { content: '✓ '; }

/* Buttons */
.pfl__btn-primary   { display: inline-flex; align-items: center; gap: .4rem; background: #1a3d2e; color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.pfl__btn-primary:hover:not(:disabled) { background: #0f2a1e; }
.pfl__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.pfl__btn-secondary { display: inline-flex; align-items: center; justify-content: center; gap: .4rem; background: #fff; border: 1.5px solid #e2e8f0; color: #374151; padding: .5rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 500; cursor: pointer; transition: background .15s; }
.pfl__btn-secondary:hover:not(:disabled) { background: #f8fafc; }
.pfl__btn-secondary:disabled { opacity: .6; cursor: not-allowed; }

.pfl__form-actions { display: flex; justify-content: flex-end; margin-top: 1rem; }
</style>
