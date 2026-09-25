<script setup>
import { onMounted, reactive, ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { getProfile, updateProfile, updateMyPassword, uploadAvatar, getMisNotificaciones, updateMisNotificaciones } from '../lib/api'
import { useAuthStore } from '../stores/auth'
import DsSpinner from '../design-system/components/Spinner.vue'
import { useToast } from '../composables/useToast.js'
import { usePushNotifications, MOTIVOS } from '../composables/usePushNotifications.js'

const auth = useAuthStore()
const route  = useRoute()
const router = useRouter()

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
  password:              '',
  password_confirmation: '',
})

const passErrors = reactive({
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
  passErrors.password              = ''
  passErrors.password_confirmation = ''
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
    Object.assign(pass, { password: '', password_confirmation: '' })
    setTimeout(() => { pOkMsg.value = null }, 4000)
  } catch (e) {
    pError.value = e?.response?.data?.errors?.join(', ') || 'Error al actualizar la contraseña'
  } finally {
    passSaving.value = false
  }
}

function roleLabel(role) {
  return { admin: 'Administrador', medico: 'Médico', cultivador: 'Cultivador', abogado: 'Abogado', auditor: 'Auditor', socio: 'Paciente' }[role] || role
}

function initials(first, last) {
  return ((first?.[0] || '') + (last?.[0] || '')).toUpperCase() || '?'
}

// ── Notificaciones al teléfono ──────────────────────────────────────────
// La lista la manda el backend YA filtrada para esta persona (su rol, los módulos de su
// organización): la pantalla no decide qué ofrecer. Cada interruptor se guarda al tocarlo.
const toast = useToast()
const notif = ref(null)
const notifGuardando = ref(null)
const { disponible: pushDisponible, iosSinInstalar, subscribed: pushSubscribed, loading: pushLoading, denied: pushDenied,
        subscribe: pushSubscribe, unsubscribe: pushUnsubscribe } = usePushNotifications()

const notifGrupos = computed(() => {
  const grupos = []
  for (const t of notif.value?.tipos || []) {
    let g = grupos.find(x => x.nombre === t.grupo)
    if (!g) { g = { nombre: t.grupo, tipos: [] }; grupos.push(g) }
    g.tipos.push(t)
  }
  return grupos
})

const notifCargadas = ref(false)
async function fetchNotificaciones() {
  try { notif.value = (await getMisNotificaciones()).data } catch { notif.value = null }
  finally { notifCargadas.value = true }
}

// ── Solapas ─────────────────────────────────────────────────────────────
// La solapa vive en la URL (`?solapa=notificaciones`): al recargar se queda donde estaba y un
// aviso puede abrir directo la que corresponde. «Notificaciones» sólo existe si hay avisos para
// elegir (lo decide el backend); pedida sin avisos, cae en «Datos personales».
const solapas = computed(() => [
  { id: 'datos',          label: 'Datos personales', corto: 'Datos', icon: 'bi-person' },
  ...(notif.value || !notifCargadas.value ? [{ id: 'notificaciones', label: 'Notificaciones', icon: 'bi-bell' }] : []),
  { id: 'seguridad',      label: 'Seguridad',        icon: 'bi-shield-lock' },
])
const solapa = computed(() => {
  const pedida = route.query.solapa
  return solapas.value.some(x => x.id === pedida) ? pedida : 'datos'
})
function irASolapa(id) {
  if (id === solapa.value) return
  router.replace({ query: { ...route.query, solapa: id === 'datos' ? undefined : id } })
}

async function toggleTipo(t) {
  notifGuardando.value = t.clave
  try {
    notif.value = (await updateMisNotificaciones({ tipos: { [t.clave]: !t.activo } })).data
  } catch {
    toast.error('No se pudo guardar. Probá de nuevo.')
  } finally {
    notifGuardando.value = null
  }
}

async function toggleNoMolestar() {
  notifGuardando.value = 'no_molestar'
  try {
    notif.value = (await updateMisNotificaciones({ no_molestar: !notif.value.no_molestar })).data
  } catch {
    toast.error('No se pudo guardar. Probá de nuevo.')
  } finally {
    notifGuardando.value = null
  }
}

// El mismo interruptor de «este dispositivo» que hay en el menú: acá es donde se viene a
// buscar cuando algo no llega.
async function togglePushDispositivo() {
  if (pushDenied.value) { toast.error(MOTIVOS.denegado, { timeout: 9000 }); return }
  if (pushSubscribed.value) {
    const r = await pushUnsubscribe()
    r === true ? toast.info('Notificaciones desactivadas en este dispositivo') : toast.error(MOTIVOS[r] || MOTIVOS.error)
  } else {
    const r = await pushSubscribe()
    r === true ? toast.success('Notificaciones activadas en este dispositivo') : toast.error(MOTIVOS[r] || MOTIVOS.error)
  }
}

onMounted(() => { fetchProfile(); fetchNotificaciones() })
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

          <!-- Quién sos: foto, nombre y rol. Queda fija al lado de las solapas. La tarjeta «Cuenta»
               (ID de usuario y de organización) se sacó: eran números internos. -->
          <div class="pfl__card pfl__avatar-card">
            <div class="pfl__avatar-wrap" @click="onPickAvatar">
              <img v-if="avatarPreview" :src="avatarPreview" class="pfl__avatar-img" alt="Avatar" />
              <div v-else class="pfl__avatar-placeholder">{{ initials(form.first_name, form.last_name) }}</div>
              <div class="pfl__avatar-overlay"><i class="bi bi-camera-fill"></i></div>
              <div v-if="avatarSaving" class="pfl__avatar-loading">
                <DsSpinner :size="16" />
              </div>
            </div>

            <div class="pfl__avatar-info">
              <h5 class="pfl__avatar-name">{{ form.first_name }} {{ form.last_name }}</h5>
              <p class="pfl__avatar-email">{{ form.email }}</p>
              <span class="pfl__role-badge">{{ roleLabel(me?.role) }}</span>
            </div>

            <input id="avatarInput" type="file" accept="image/jpeg,image/png,image/webp" style="display:none" @change="onFileChange" />

            <button class="pfl__btn-secondary pfl__avatar-btn" @click="onPickAvatar" :disabled="avatarSaving">
              <i class="bi bi-image"></i>
              {{ avatarSaving ? 'Subiendo...' : 'Cambiar foto' }}
            </button>
            <div class="pfl__avatar-hint">JPG, PNG o WebP · máx 5 MB</div>
          </div>

        </div>

        <!-- ── Columna derecha ── -->
        <div class="pfl__main">

          <div class="pfl__tabs" role="tablist">
            <button v-for="t in solapas" :key="t.id" type="button" role="tab" class="pfl__tab"
                    :class="{ 'pfl__tab--on': solapa === t.id }" :aria-selected="solapa === t.id"
                    @click="irASolapa(t.id)">
              <i class="bi" :class="t.icon"></i>
              <span class="pfl__tab-largo">{{ t.label }}</span><span class="pfl__tab-corto">{{ t.corto || t.label }}</span>
            </button>
          </div>

          <!-- Datos personales -->
          <div v-if="solapa === 'datos'" class="pfl__card pfl__card--form">
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
                <div class="pfl__hint">Tu mail real, donde la organización puede contactarte.</div>
              </div>
            </div>
          </div>

          <!-- Notificaciones al teléfono -->
          <div v-else-if="solapa === 'notificaciones'" class="pfl__card pfl__card--form">
            <div v-if="!notif" class="pfl__loading pfl__loading--inline"><DsSpinner /></div>
            <template v-else>
            <div class="pfl__card-header">
              <div>
                <div class="pfl__card-title">Notificaciones</div>
                <div class="pfl__card-desc">Qué avisos te llegan al teléfono. En la campanita de la app está todo igual.</div>
              </div>
            </div>

            <!-- Este dispositivo -->
            <div class="pfl__notif-dispositivo">
              <div>
                <div class="pfl__notif-label">{{ pushDenied ? 'Este navegador tiene las notificaciones bloqueadas' : (pushSubscribed ? 'Este dispositivo recibe avisos' : 'Este dispositivo no recibe avisos') }}</div>
                <div class="pfl__hint">
                  {{ pushDenied ? 'Tocá el candado a la izquierda de la dirección → Notificaciones → Permitir. Al volver, el botón cambia solo.'
                     : iosSinInstalar ? 'En iPhone hay que agregar la app a la pantalla de inicio.'
                     : (pushSubscribed ? 'Cada teléfono o computadora se activa por separado.' : 'Activalo para que los avisos de abajo te lleguen acá.') }}
                </div>
              </div>
              <button v-if="pushDisponible || iosSinInstalar" class="pfl__btn-secondary" :disabled="pushLoading || pushDenied" @click="togglePushDispositivo">
                <i class="bi" :class="pushSubscribed ? 'bi-bell-slash' : 'bi-bell'"></i>
                {{ pushDenied ? 'Bloqueadas' : (pushSubscribed ? 'Desactivar acá' : 'Activar acá') }}
              </button>
            </div>

            <div v-for="g in notifGrupos" :key="g.nombre" class="pfl__notif-grupo">
              <div class="pfl__card-section-title">{{ g.nombre }}</div>
              <p v-if="notif.grupos?.[g.nombre]" class="pfl__hint pfl__notif-grupo-desc">{{ notif.grupos[g.nombre] }}</p>
              <label v-for="t in g.tipos" :key="t.clave" class="pfl__notif-row">
                <input type="checkbox" class="pfl__switch" :checked="t.activo" :disabled="notifGuardando === t.clave" @change="toggleTipo(t)" />
                <span class="pfl__notif-txt">
                  <span class="pfl__notif-label">{{ t.label }}</span>
                  <span class="pfl__hint">{{ t.desc }}</span>
                </span>
              </label>
            </div>

            <div class="pfl__notif-grupo">
              <div class="pfl__card-section-title">Horario</div>
              <label class="pfl__notif-row">
                <input type="checkbox" class="pfl__switch" :checked="notif.no_molestar" :disabled="notifGuardando === 'no_molestar'" @change="toggleNoMolestar" />
                <span class="pfl__notif-txt">
                  <span class="pfl__notif-label">No molestar de {{ notif.no_molestar_desde }} a {{ notif.no_molestar_hasta }}</span>
                  <span class="pfl__hint">Lo que caiga en ese horario se entrega a las {{ notif.no_molestar_hasta }}; no se pierde.</span>
                </span>
              </label>
            </div>
            </template>
          </div>

          <!-- Seguridad -->
          <div v-else class="pfl__card pfl__card--form">
            <div class="pfl__card-header">
              <div>
                <div class="pfl__card-title">Seguridad</div>
                <div class="pfl__card-desc">Elegí una contraseña nueva. Al cambiarla se cierra tu sesión en los otros dispositivos y te llega un mail avisando.</div>
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
.pfl__title  { font-size: 1.5rem; font-weight: 700; color: var(--c-slate-900); margin: 0 0 .15rem; }
.pfl__sub    { font-size: .82rem; color: var(--c-slate-500); margin: 0; }

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
/* Sin esto la fila de solapas (que scrollea de costado) estiraba la columna más allá de la pantalla. */
.pfl__body > * { min-width: 0; }

/* Cards */
.pfl__card { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 14px; padding: 1.25rem; margin-bottom: 1rem; }
.pfl__card--form { padding: 1.25rem; }

/* Avatar card */
.pfl__avatar-card { text-align: center; }
.pfl__avatar-wrap { position: relative; width: 110px; height: 110px; border-radius: 50%; cursor: pointer; overflow: hidden; margin: 0 auto 1rem; }
.pfl__avatar-img  { width: 100%; height: 100%; object-fit: cover; border-radius: 50%; }
.pfl__avatar-placeholder { width: 100%; height: 100%; border-radius: 50%; display: flex; align-items: center; justify-content: center; background: color-mix(in srgb, #1b5e20 15%, white); color: #1b5e20; font-size: 2rem; font-weight: 700; }
.pfl__avatar-overlay { position: absolute; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; color: white; font-size: 1.4rem; opacity: 0; transition: opacity .2s; border-radius: 50%; }
.pfl__avatar-wrap:hover .pfl__avatar-overlay { opacity: 1; }
.pfl__avatar-loading { position: absolute; inset: 0; background: rgba(0,0,0,.5); display: flex; align-items: center; justify-content: center; border-radius: 50%; }
.pfl__avatar-name  { font-weight: 700; font-size: 1rem; color: var(--c-slate-900); margin: 0 0 .2rem; }
.pfl__avatar-info { min-width: 0; }
.pfl__avatar-email { font-size: .82rem; color: var(--c-slate-500); margin: 0 0 .5rem; overflow-wrap: anywhere; }
.pfl__role-badge   { display: inline-block; background: #1a3d2e; color: #fff; border-radius: 99px; padding: .25rem .8rem; font-size: .75rem; font-weight: 600; margin-bottom: .75rem; }
.pfl__avatar-btn   { width: 100%; margin-bottom: .25rem; }
.pfl__avatar-hint  { font-size: .7rem; color: var(--c-slate-400); }

/* Solapas */
.pfl__tabs { display: flex; gap: .25rem; border-bottom: 1.5px solid var(--c-slate-200); margin-bottom: 1rem; overflow-x: auto; scrollbar-width: none; }
.pfl__tab { display: inline-flex; align-items: center; gap: .4rem; white-space: nowrap; background: none; border: 0; border-bottom: 2.5px solid transparent; margin-bottom: -1.5px; padding: .55rem .85rem; font-size: .875rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; }
.pfl__tab:hover { color: var(--c-slate-900); }
.pfl__tab--on { color: #1a3d2e; border-bottom-color: #1a3d2e; }
.pfl__loading--inline { min-height: 120px; }
.pfl__tab-corto { display: none; }

/* Teléfono: la foto queda chica, al lado del nombre, arriba de las solapas. */
@media (max-width: 768px) {
  .pfl__avatar-card { display: grid; grid-template-columns: 64px 1fr; column-gap: .9rem; align-items: center; text-align: left; padding: .9rem 1rem; }
  .pfl__avatar-wrap { width: 64px; height: 64px; margin: 0; grid-row: span 2; }
  .pfl__avatar-placeholder { font-size: 1.3rem; }
  .pfl__role-badge { margin-bottom: .35rem; }
  .pfl__avatar-btn { width: auto; justify-self: start; padding: .3rem .7rem; font-size: .76rem; }
  .pfl__avatar-hint { display: none; }
  .pfl__body { gap: .25rem; }
  /* Las tres tienen que entrar: una solapa cortada a la mitad no se lee como solapa. */
  .pfl__tab { flex: 1; justify-content: center; padding: .55rem .4rem; }
  .pfl__tab-largo { display: none; }
  .pfl__tab-corto { display: inline; }
}

.pfl__notif-dispositivo { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: .85rem 1rem; border-radius: 10px; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); margin-bottom: 1rem; }
.pfl__notif-dispositivo .pfl__btn-secondary { white-space: nowrap; flex: none; }
@media (max-width: 480px) { .pfl__notif-dispositivo { flex-direction: column; align-items: stretch; } }
.pfl__notif-grupo { margin-top: 1rem; }
.pfl__notif-grupo-desc { margin: -.35rem 0 .35rem; }
.pfl__notif-row { display: flex; align-items: flex-start; gap: .75rem; padding: .55rem 0; border-top: 1px solid var(--c-slate-100); cursor: pointer; }
.pfl__notif-row:first-of-type { border-top: 0; }
.pfl__notif-txt { display: flex; flex-direction: column; gap: .1rem; }
.pfl__notif-label { font-size: .88rem; font-weight: 600; color: var(--c-slate-800); }
.pfl__switch { appearance: none; width: 38px; height: 22px; border-radius: 999px; background: var(--c-slate-300); position: relative; flex: none; margin-top: .15rem; cursor: pointer; transition: background .15s; }
.pfl__switch::after { content: ''; position: absolute; top: 3px; left: 3px; width: 16px; height: 16px; border-radius: 50%; background: #fff; transition: transform .15s; }
.pfl__switch:checked { background: var(--c-leaf-600); }
.pfl__switch:checked::after { transform: translateX(16px); }
.pfl__switch:disabled { opacity: .6; }
.pfl__card-section-title { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-slate-400); margin-bottom: .75rem; }

/* Card headers */
.pfl__card-header { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; margin-bottom: 1.25rem; }
.pfl__card-title  { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); }
.pfl__card-desc   { font-size: .78rem; color: var(--c-slate-500); margin-top: .1rem; }

/* Form grid */
.pfl__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }
@media (max-width: 560px) { .pfl__form-grid { grid-template-columns: 1fr; } }
.pfl__field      { display: flex; flex-direction: column; gap: .3rem; }
.pfl__field--full { grid-column: 1 / -1; }

/* Inputs */
.pfl__label       { font-size: .8rem; font-weight: 600; color: #374151; }
.pfl__required    { color: #dc2626; }
.pfl__input       { padding: .55rem .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; width: 100%; box-sizing: border-box; }
.pfl__input:focus { border-color: #1a3d2e; }
.pfl__input--error { border-color: #ef4444; }
.pfl__input--ok   { border-color: #22c55e; }
.pfl__hint        { font-size: .75rem; color: var(--c-slate-500); }
.pfl__field-error { font-size: .78rem; color: #ef4444; }
.pfl__field-ok    { font-size: .78rem; color: #15803d; }

/* Password reveal */
.pfl__input-row { display: flex; gap: 0; }
.pfl__input-row .pfl__input { border-radius: 8px 0 0 8px; flex: 1; }
.pfl__eye-btn { padding: 0 .75rem; border: 1.5px solid var(--c-slate-200); border-left: none; border-radius: 0 8px 8px 0; background: #fff; color: var(--c-slate-500); cursor: pointer; transition: background .15s; }
.pfl__eye-btn:hover { background: var(--c-slate-50); }

/* Strength bar */
.pfl__strength { margin-top: .5rem; }
.pfl__strength-bar-wrap { height: 4px; background: var(--c-slate-200); border-radius: 2px; overflow: hidden; margin-bottom: .35rem; }
.pfl__strength-bar { height: 100%; border-radius: 2px; }
.pfl__strength-row { display: flex; justify-content: space-between; margin-bottom: .25rem; }
.pfl__strength-chars { font-size: .78rem; color: var(--c-slate-400); }
.pfl__hints { list-style: none; padding: 0; margin: .25rem 0 0; display: flex; flex-direction: column; gap: .15rem; }
.pfl__hints li { font-size: .78rem; color: var(--c-slate-400); }
.pfl__hints li::before { content: '○ '; }
.pfl__hints li.pfl__hint--ok { color: #15803d; }
.pfl__hints li.pfl__hint--ok::before { content: '✓ '; }

/* Buttons */
.pfl__btn-primary   { display: inline-flex; align-items: center; gap: .4rem; background: #1a3d2e; color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.pfl__btn-primary:hover:not(:disabled) { background: #0f2a1e; }
.pfl__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.pfl__btn-secondary { display: inline-flex; align-items: center; justify-content: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-slate-200); color: #374151; padding: .5rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 500; cursor: pointer; transition: background .15s; }
.pfl__btn-secondary:hover:not(:disabled) { background: var(--c-slate-50); }
.pfl__btn-secondary:disabled { opacity: .6; cursor: not-allowed; }

.pfl__form-actions { display: flex; justify-content: flex-end; margin-top: 1rem; }
</style>
