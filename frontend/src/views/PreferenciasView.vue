<!-- src/views/PreferenciasView.vue -->
<script setup>
import { onMounted, reactive, ref, computed } from 'vue'
import { useClubStore } from '../stores/club'
import Avatar from '../components/Avatar.vue'

const club = useClubStore()

// toast = { type: 'success'|'danger', msg: '...' }
const toast = ref(null)
const pristine = ref(true)

const form = reactive({
  name: '',
  legal_name: '',
  contact_email: '',
  contact_phone: '',
  website: '',
  address_line1: '',
  city: '',
  province: '',
  country: '',
  timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
})

onMounted(async () => {
  if (!club.data) {
    try {
      await club.fetch()
    } catch (_) {
      // si falla, mostramos error cuando haga save/upload
    }
  }

  // cargar valores existentes
  Object.assign(form, {
    name: club.data?.name || '',
    legal_name: club.data?.legal_name || '',
    contact_email: club.data?.contact_email || '',
    contact_phone: club.data?.contact_phone || '',
    website: club.data?.website || '',
    address_line1: club.data?.address_line1 || '',
    city: club.data?.city || '',
    province: club.data?.province || '',
    country: club.data?.country || '',
    timezone: club.data?.timezone || form.timezone,
  })

  pristine.value = true
})

function onChange() {
  pristine.value = false
}

async function save() {
  if (!form.name.trim()) {
    toast.value = { type: 'danger', msg: 'El nombre del club es obligatorio.' }
    return
  }

  try {
    await club.update(form)
    pristine.value = true
    toast.value = { type: 'success', msg: 'Preferencias guardadas.' }
  } catch (e) {
    toast.value = { type: 'danger', msg: club.error || 'Error al guardar' }
  }
}

const uploading = computed(() => club.saving)

function onFile(e) {
  const input = e.target
  const file = input && input.files && input.files[0]
  if (!file) return

  if (file.size > 5 * 1024 * 1024) {
    toast.value = { type: 'danger', msg: 'El logo no puede superar 5 MB.' }
    input.value = '' // reset input
    return
  }

  club.uploadLogo(file)
    .then(() => {
      toast.value = { type: 'success', msg: 'Logo actualizado.' }
      input.value = ''
    })
    .catch(() => {
      toast.value = { type: 'danger', msg: club.error || 'No se pudo subir el logo.' }
      input.value = ''
    })
}

function removeLogo() {
  club.removeLogo()
    .then(() => {
      toast.value = { type: 'success', msg: 'Logo eliminado.' }
    })
    .catch(() => {
      toast.value = { type: 'danger', msg: club.error || 'No se pudo eliminar el logo.' }
    })
}
</script>

<template>
  <div>
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div>
        <h2 class="mb-0">Preferencias del club</h2>
        <small class="text-muted">Identidad, contacto y domicilio</small>
      </div>

      <button
        class="btn btn-success"
        :disabled="club.saving || pristine"
        @click="save"
      >
        <span v-if="club.saving" class="spinner-border spinner-border-sm me-2"></span>
        Guardar cambios
      </button>
    </div>

    <div v-if="toast" class="alert" :class="toast.type==='success' ? 'alert-success' : 'alert-danger'">
      {{ toast.msg }}
    </div>

    <div class="row g-3">
      <!-- Identidad -->
      <div class="col-12 col-lg-4">
        <div class="card h-100">
          <div class="card-header fw-semibold">Identidad</div>
          <div class="card-body">
            <div class="text-center mb-3">
              <img
                v-if="club.logoUrl"
                :src="club.logoUrl"
                alt="logo"
                class="rounded-circle shadow-sm"
                style="width:96px;height:96px;object-fit:cover;"
              />
              <Avatar v-else :name="form.name || 'Club'" :size="96" />
            </div>

            <div class="d-grid gap-2 mb-3">
              <label class="btn btn-outline-secondary">
                <i class="bi bi-image me-1"></i>
                Cambiar logo
                <input
                  type="file"
                  class="d-none"
                  accept="image/*"
                  :disabled="uploading"
                  @change="onFile"
                >
              </label>

              <button
                class="btn btn-outline-danger"
                :disabled="!club.logoUrl || uploading"
                @click="removeLogo"
              >
                <i class="bi bi-x-circle me-1"></i>
                Quitar logo
              </button>

              <small class="text-muted text-center">JPG/PNG/WebP — máx 5 MB</small>
            </div>

            <div class="mb-3">
              <label class="form-label">Nombre del club *</label>
              <input class="form-control" v-model.trim="form.name" @input="onChange" required>
            </div>
            <div>
              <label class="form-label">Razón social (opcional)</label>
              <input class="form-control" v-model.trim="form.legal_name" @input="onChange">
            </div>
          </div>
        </div>
      </div>

      <!-- Contacto y domicilio -->
      <div class="col-12 col-lg-8">
        <div class="card h-100">
          <div class="card-header fw-semibold">Contacto & domicilio</div>
          <div class="card-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Email de contacto</label>
                <input type="email" class="form-control" v-model.trim="form.contact_email" @input="onChange">
              </div>
              <div class="col-md-6">
                <label class="form-label">Teléfono</label>
                <input type="text" class="form-control" v-model.trim="form.contact_phone" @input="onChange">
              </div>
              <div class="col-md-12">
                <label class="form-label">Website</label>
                <input type="text" class="form-control" v-model.trim="form.website" placeholder="https://…" @input="onChange">
              </div>
              <div class="col-md-8">
                <label class="form-label">Dirección</label>
                <input type="text" class="form-control" v-model.trim="form.address_line1" @input="onChange">
              </div>
              <div class="col-md-4">
                <label class="form-label">Ciudad</label>
                <input type="text" class="form-control" v-model.trim="form.city" @input="onChange">
              </div>
              <div class="col-md-4">
                <label class="form-label">Provincia/Estado</label>
                <input type="text" class="form-control" v-model.trim="form.province" @input="onChange">
              </div>
              <div class="col-md-4">
                <label class="form-label">País</label>
                <input type="text" class="form-control" v-model.trim="form.country" @input="onChange">
              </div>
              <div class="col-md-4">
                <label class="form-label">Zona horaria</label>
                <input type="text" class="form-control" v-model.trim="form.timezone" @input="onChange" list="tz-list">
                <datalist id="tz-list">
                  <option value="America/Argentina/Buenos_Aires" />
                  <option value="UTC" />
                </datalist>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>


