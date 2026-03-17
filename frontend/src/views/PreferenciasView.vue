<script setup>
import { onMounted, reactive, ref, computed, watch } from 'vue'
import { useClubStore } from '../stores/club'
import Avatar from '../components/Avatar.vue'

const club     = useClubStore()
const toast    = ref(null)
const pristine = ref(true)
const logoPreview = ref(null)
let toastTimer = null

// Campos corregidos — coinciden exactamente con el backend
const form = reactive({
  name:          '',
  legal_name:    '',
  email:         '',
  phone:         '',
  website:       '',
  address:       '',
  city:          '',
  state:         '',
  country:       'Argentina',
  timezone:      'America/Argentina/Buenos_Aires',
})

const formErrors = reactive({
  name:  '',
  email: '',
})

// ── Cargar datos ──────────────────────────────────────────────────────
onMounted(async () => {
  if (!club.data) {
    try { await club.fetch() } catch (_) {}
  }
  loadFromStore()
})

watch(() => club.data, loadFromStore)

function loadFromStore() {
  if (!club.data) return
  Object.assign(form, {
    name:       club.data.name       || '',
    legal_name: club.data.legal_name || '',
    email:      club.data.email      || '',
    phone:      club.data.phone      || '',
    website:    club.data.website    || '',
    address:    club.data.address    || '',
    city:       club.data.city       || '',
    state:      club.data.state      || '',
    country:    club.data.country    || 'Argentina',
    timezone:   club.data.timezone   || 'America/Argentina/Buenos_Aires',
  })
  logoPreview.value = club.data.logo_url || null
  pristine.value = true
}

// ── Cambios ───────────────────────────────────────────────────────────
function onChange() { pristine.value = false }

// ── Validación ────────────────────────────────────────────────────────
function validate() {
  formErrors.name  = ''
  formErrors.email = ''
  let ok = true
  if (!form.name.trim()) {
    formErrors.name = 'El nombre del club es obligatorio'
    ok = false
  }
  if (form.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
    formErrors.email = 'Email inválido'
    ok = false
  }
  return ok
}

// ── Guardar ───────────────────────────────────────────────────────────
async function save() {
  if (!validate()) return
  try {
    await club.update({ ...form })
    pristine.value = true
    showToast('success', '✓ Preferencias guardadas correctamente')
  } catch (_) {
    showToast('danger', club.error || 'Error al guardar')
  }
}

// ── Logo ──────────────────────────────────────────────────────────────
function onLogoFile(e) {
  const file = e.target?.files?.[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) {
    showToast('danger', 'El logo no puede superar 5 MB')
    e.target.value = ''
    return
  }
  // Preview inmediata
  const reader = new FileReader()
  reader.onload = () => { logoPreview.value = reader.result }
  reader.readAsDataURL(file)

  club.uploadLogo(file)
    .then(() => {
      logoPreview.value = club.logoUrl || logoPreview.value
      showToast('success', '✓ Logo actualizado')
    })
    .catch(() => showToast('danger', club.error || 'Error al subir el logo'))
    .finally(() => { e.target.value = '' })
}

async function removeLogo() {
  if (!confirm('¿Seguro que querés quitar el logo del club?')) return
  try {
    await club.removeLogo()
    logoPreview.value = null
    showToast('success', '✓ Logo eliminado')
  } catch (_) {
    showToast('danger', club.error || 'Error al eliminar el logo')
  }
}

// ── Toast ─────────────────────────────────────────────────────────────
function showToast(type, msg) {
  clearTimeout(toastTimer)
  toast.value = { type, msg }
  toastTimer = setTimeout(() => { toast.value = null }, 5000)
}

// ── Timezones AR ──────────────────────────────────────────────────────
const timezones = [
  'America/Argentina/Buenos_Aires',
  'America/Argentina/Cordoba',
  'America/Argentina/Mendoza',
  'America/Argentina/Salta',
  'UTC',
]
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4" style="max-width:960px">

    <!-- Header -->
    <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">Preferencias del club</h1>
        <p class="text-muted small mb-0">Identidad, contacto, domicilio legal y configuración</p>
      </div>
      <button
        class="btn btn-success px-4"
        :disabled="club.saving || pristine"
        @click="save"
      >
        <span v-if="club.saving" class="spinner-border spinner-border-sm me-2"></span>
        <i v-else class="bi bi-check2 me-1"></i>
        {{ club.saving ? 'Guardando...' : 'Guardar cambios' }}
      </button>
    </div>

    <!-- Toast -->
    <transition name="fade">
      <div
        v-if="toast"
        class="alert alert-dismissible d-flex align-items-center gap-2 mb-4"
        :class="toast.type === 'success' ? 'alert-success' : 'alert-danger'"
        role="alert"
      >
        <i :class="toast.type === 'success' ? 'bi bi-check-circle-fill' : 'bi bi-exclamation-triangle-fill'"></i>
        <span>{{ toast.msg }}</span>
        <button class="btn-close" @click="toast=null"></button>
      </div>
    </transition>

    <div class="row g-4">

      <!-- ── Col izquierda: identidad visual ── -->
      <div class="col-12 col-lg-4">
        <div class="card border-0 shadow-sm h-100">
          <div class="card-header bg-transparent border-bottom-0 pt-3 pb-0">
            <strong>Identidad visual</strong>
            <p class="text-muted small mb-0">Logo y nombre del club</p>
          </div>
          <div class="card-body">

            <!-- Logo -->
            <div class="text-center mb-4">
              <div class="logo-wrap mx-auto mb-3">
                <img
                  v-if="logoPreview"
                  :src="logoPreview"
                  alt="Logo del club"
                  class="logo-img"
                />
                <Avatar v-else :name="form.name || 'Club'" :size="96" />
                <div v-if="club.saving" class="logo-loading">
                  <div class="spinner-border spinner-border-sm text-white"></div>
                </div>
              </div>

              <div class="d-grid gap-2">
                <label class="btn btn-outline-secondary btn-sm" :class="{ disabled: club.saving }">
                  <i class="bi bi-image me-1"></i> Cambiar logo
                  <input type="file" class="d-none" accept="image/jpeg,image/png,image/webp" :disabled="club.saving" @change="onLogoFile" />
                </label>
                <button
                  class="btn btn-outline-danger btn-sm"
                  :disabled="!logoPreview || club.saving"
                  @click="removeLogo"
                >
                  <i class="bi bi-x-circle me-1"></i> Quitar logo
                </button>
              </div>
              <div class="text-muted mt-2" style="font-size:.72rem">JPG, PNG o WebP · máx 5 MB</div>
            </div>

            <!-- Nombre -->
            <div class="mb-3">
              <label class="form-label small fw-semibold">Nombre del club <span class="text-danger">*</span></label>
              <input
                class="form-control"
                :class="{ 'is-invalid': formErrors.name }"
                v-model.trim="form.name"
                @input="onChange"
                placeholder="Ej: Verde Esperanza"
              />
              <div class="invalid-feedback">{{ formErrors.name }}</div>
            </div>

            <div>
              <label class="form-label small fw-semibold">Razón social</label>
              <input
                class="form-control"
                v-model.trim="form.legal_name"
                @input="onChange"
                placeholder="Nombre legal (opcional)"
              />
              <div class="form-text">Usado en documentos oficiales y trazabilidad Reprocann.</div>
            </div>

          </div>
        </div>
      </div>

      <!-- ── Col derecha: contacto + domicilio + config ── -->
      <div class="col-12 col-lg-8">

        <!-- Contacto -->
        <div class="card border-0 shadow-sm mb-4">
          <div class="card-header bg-transparent border-bottom-0 pt-3 pb-0">
            <strong>Contacto</strong>
            <p class="text-muted small mb-0">Datos de contacto del club (visibles para socios)</p>
          </div>
          <div class="card-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Email de contacto</label>
                <input
                  type="email"
                  class="form-control"
                  :class="{ 'is-invalid': formErrors.email }"
                  v-model.trim="form.email"
                  @input="onChange"
                  placeholder="contacto@miclub.org"
                />
                <div class="invalid-feedback">{{ formErrors.email }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Teléfono</label>
                <input
                  type="text"
                  class="form-control"
                  v-model.trim="form.phone"
                  @input="onChange"
                  placeholder="+54 11 1234-5678"
                />
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Sitio web</label>
                <div class="input-group">
                  <span class="input-group-text text-muted small">🌐</span>
                  <input
                    type="url"
                    class="form-control"
                    v-model.trim="form.website"
                    @input="onChange"
                    placeholder="https://miclub.org"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Domicilio legal -->
        <div class="card border-0 shadow-sm mb-4">
          <div class="card-header bg-transparent border-bottom-0 pt-3 pb-0">
            <strong>Domicilio legal</strong>
            <p class="text-muted small mb-0">Requerido para informes Reprocann y trazabilidad</p>
          </div>
          <div class="card-body">
            <div class="row g-3">
              <div class="col-12">
                <label class="form-label small fw-semibold">Dirección</label>
                <input
                  type="text"
                  class="form-control"
                  v-model.trim="form.address"
                  @input="onChange"
                  placeholder="Av. Corrientes 1234, Piso 2"
                />
              </div>
              <div class="col-md-5">
                <label class="form-label small fw-semibold">Ciudad</label>
                <input
                  type="text"
                  class="form-control"
                  v-model.trim="form.city"
                  @input="onChange"
                  placeholder="Buenos Aires"
                />
              </div>
              <div class="col-md-4">
                <label class="form-label small fw-semibold">Provincia</label>
                <input
                  type="text"
                  class="form-control"
                  v-model.trim="form.state"
                  @input="onChange"
                  placeholder="CABA"
                />
              </div>
              <div class="col-md-3">
                <label class="form-label small fw-semibold">País</label>
                <input
                  type="text"
                  class="form-control"
                  v-model.trim="form.country"
                  @input="onChange"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Configuración -->
        <div class="card border-0 shadow-sm">
          <div class="card-header bg-transparent border-bottom-0 pt-3 pb-0">
            <strong>Configuración regional</strong>
          </div>
          <div class="card-body">
            <div class="row g-3">
              <div class="col-md-8">
                <label class="form-label small fw-semibold">Zona horaria</label>
                <select class="form-select" v-model="form.timezone" @change="onChange">
                  <option v-for="tz in timezones" :key="tz" :value="tz">{{ tz }}</option>
                </select>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>

<style scoped>
.logo-wrap {
  position: relative;
  width: 96px;
  height: 96px;
  border-radius: 50%;
}
.logo-img {
  width: 96px;
  height: 96px;
  border-radius: 50%;
  object-fit: cover;
  box-shadow: 0 2px 8px rgba(0,0,0,.12);
}
.logo-loading {
  position: absolute;
  inset: 0;
  background: rgba(0,0,0,.45);
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
}

.fade-enter-active, .fade-leave-active { transition: opacity .3s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>

