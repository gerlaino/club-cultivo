<script setup>
import { ref, onMounted, computed } from "vue"
import { useUsuariosStore } from "../stores/usuarios"

const store = useUsuariosStore()

const q = ref("")
const showModal = ref(false)
const editing = ref(false)
const form = ref({ id:null, first_name:"", last_name:"", email:"", role:"cultivador" })
const toast = ref(null)

const ROLES = [
  { value: 'admin', label: 'Administrador', color: 'danger', icon: 'bi-shield-fill-check' },
  { value: 'medico', label: 'Médico', color: 'success', icon: 'bi-heart-pulse-fill' },
  { value: 'agricultor', label: 'Agricultor', color: 'primary', icon: 'bi-tree-fill' },
  { value: 'cultivador', label: 'Cultivador', color: 'info', icon: 'bi-flower1' },
  { value: 'abogado', label: 'Abogado', color: 'warning', icon: 'bi-briefcase-fill' },
  { value: 'auditor', label: 'Auditor', color: 'secondary', icon: 'bi-clipboard-data-fill' },
  { value: 'socio', label: 'Socio', color: 'dark', icon: 'bi-person-fill' }
]

const getRoleInfo = (role) => {
  return ROLES.find(r => r.value === role) || { label: role, color: 'secondary', icon: 'bi-person' }
}

const getInitials = (user) => {
  const first = user.first_name?.[0] || ''
  const last = user.last_name?.[0] || ''
  return (first + last).toUpperCase() || user.email[0].toUpperCase()
}

onMounted(() => store.fetch())

async function search() {
  await store.fetch({ query: q.value })
}

function startCreate() {
  editing.value = false
  form.value = { id:null, first_name:"", last_name:"", email:"", role:"cultivador" }
  showModal.value = true
}

function startEdit(u) {
  editing.value = true
  form.value = {
    id: u.id,
    first_name: u.first_name || "",
    last_name: u.last_name || "",
    email: u.email || "",
    role: u.role || "cultivador"
  }
  showModal.value = true
}

async function save() {
  try {
    const payload = {
      first_name: form.value.first_name,
      last_name:  form.value.last_name,
      email:      form.value.email,
      role:       form.value.role
    }
    if (editing.value && form.value.id) {
      await store.update(form.value.id, payload)
      toast.value = { t:"success", m:"Usuario actualizado." }
    } else {
      await store.create(payload)
      toast.value = { t:"success", m:"Usuario creado. Se envió email para definir contraseña." }
    }
    showModal.value = false
  } catch (e) {
    toast.value = { t:"danger", m: store.error || "Error al guardar." }
  }
}

async function removeOne(u) {
  if (!confirm(`¿Eliminar a ${u.first_name || ''} ${u.last_name || ''}?`)) return
  try {
    await store.remove(u.id)
    toast.value = { t:"success", m:"Usuario eliminado." }
  } catch {
    toast.value = { t:"danger", m: store.error || "No se pudo eliminar." }
  }
}

async function sendReset(u) {
  try {
    await store.sendReset(u.id)
    toast.value = { t:"success", m:"Email de reinicio de contraseña enviado." }
  } catch {
    toast.value = { t:"danger", m: store.error || "No se pudo enviar el email." }
  }
}
</script>

<template>
  <div>
    <div class="d-flex align-items-center justify-content-between mb-4">
      <h2 class="mb-0">
        <i class="bi bi-people-fill me-2"></i>
        Equipo
      </h2>
      <button class="btn btn-success" @click="startCreate">
        <i class="bi bi-plus-circle me-2"></i>
        Nuevo Usuario
      </button>
    </div>

    <div v-if="toast" class="alert alert-dismissible fade show" :class="toast.t==='success'?'alert-success':'alert-danger'">
      {{ toast.m }}
      <button type="button" class="btn-close" @click="toast = null"></button>
    </div>

    <div class="row g-3 mb-4">
      <div class="col-md-6">
        <input
          class="form-control"
          v-model.trim="q"
          placeholder="Buscar por nombre, apellido o email"
          @keyup.enter="search"
        >
      </div>
      <div class="col-auto">
        <button class="btn btn-outline-secondary" @click="search">
          <i class="bi bi-search me-1"></i>
          Buscar
        </button>
      </div>
    </div>

    <div v-if="store.loading" class="text-center py-5">
      <div class="spinner-border text-primary"></div>
    </div>

    <div v-else-if="store.items.length === 0" class="text-center py-5">
      <i class="bi bi-people display-1 text-muted"></i>
      <p class="mt-3 text-muted">No hay usuarios registrados</p>
      <button class="btn btn-primary" @click="startCreate">
        <i class="bi bi-plus-circle me-2"></i>
        Crear Primer Usuario
      </button>
    </div>

    <div v-else class="row g-3">
      <div v-for="u in store.items" :key="u.id" class="col-md-6 col-lg-4">
        <div class="card h-100 shadow-sm hover-shadow">
          <div class="card-body">
            <div class="d-flex align-items-start mb-3">
              <div class="avatar-circle me-3" :class="`bg-${getRoleInfo(u.role).color}`">
                {{ getInitials(u) }}
              </div>
              <div class="flex-grow-1">
                <h6 class="mb-1">{{ u.first_name }} {{ u.last_name }}</h6>
                <p class="text-muted small mb-2">{{ u.email }}</p>
                <span class="badge" :class="`bg-${getRoleInfo(u.role).color}`">
                  <i :class="getRoleInfo(u.role).icon + ' me-1'"></i>
                  {{ getRoleInfo(u.role).label }}
                </span>
              </div>
            </div>

            <div class="btn-group w-100" role="group">
              <button
                class="btn btn-sm btn-outline-primary"
                @click="startEdit(u)"
                title="Editar"
              >
                <i class="bi bi-pencil"></i>
              </button>
              <button
                class="btn btn-sm btn-outline-warning"
                @click="sendReset(u)"
                title="Reiniciar contraseña"
              >
                <i class="bi bi-key"></i>
              </button>
              <button
                class="btn btn-sm btn-outline-danger"
                @click="removeOne(u)"
                title="Eliminar"
              >
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="modal show d-block" tabindex="-1">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i :class="editing ? 'bi bi-pencil-square' : 'bi bi-person-plus-fill'" class="me-2"></i>
              {{ editing ? 'Editar Usuario' : 'Nuevo Usuario' }}
            </h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Nombre *</label>
                <input
                  class="form-control"
                  v-model.trim="form.first_name"
                  placeholder="Juan"
                  required
                >
              </div>
              <div class="col-md-6">
                <label class="form-label">Apellido *</label>
                <input
                  class="form-control"
                  v-model.trim="form.last_name"
                  placeholder="Pérez"
                  required
                >
              </div>
              <div class="col-12">
                <label class="form-label">Email *</label>
                <input
                  type="email"
                  class="form-control"
                  v-model.trim="form.email"
                  placeholder="usuario@ejemplo.com"
                  required
                >
                <small class="text-muted">Se enviará un email para configurar la contraseña</small>
              </div>
              <div class="col-12">
                <label class="form-label">Rol *</label>
                <select class="form-select" v-model="form.role" required>
                  <option
                    v-for="role in ROLES"
                    :key="role.value"
                    :value="role.value"
                  >
                    {{ role.label }}
                  </option>
                </select>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showModal=false">
              Cancelar
            </button>
            <button class="btn btn-primary" :disabled="store.saving" @click="save">
              <span v-if="store.saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editing ? 'Guardar Cambios' : 'Crear Usuario' }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showModal" class="modal-backdrop show"></div>
  </div>
</template>

<style scoped>
.avatar-circle {
  width: 50px;
  height: 50px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 1.2rem;
  flex-shrink: 0;
}

.hover-shadow {
  transition: all 0.2s;
}

.hover-shadow:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15) !important;
}

.modal.show {
  background: rgba(0,0,0,0.5);
}
</style>
