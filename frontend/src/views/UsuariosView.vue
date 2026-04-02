<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import {listSalas, asignarSalaAUsuario, listSedes} from '../lib/api.js'

const router = useRouter()
const store  = useUsuariosStore()

const q             = ref("")
const showModal     = ref(false)
const editing       = ref(false)
const toast         = ref(null)
const todasLasSalas = ref([])
const todasLasSedes = ref([])

const form = ref({
  id: null, first_name: "", last_name: "", email: "",
  role: "cultivador", sede_id: "", sala_id: ""
})

const ROLES = [
  { value: 'admin',      label: 'Administrador', color: 'danger',    icon: 'bi-shield-fill-check' },
  { value: 'medico',     label: 'Médico',        color: 'success',   icon: 'bi-heart-pulse-fill' },
  { value: 'agricultor', label: 'Agricultor',    color: 'primary',   icon: 'bi-tree-fill' },
  { value: 'cultivador', label: 'Cultivador',    color: 'info',      icon: 'bi-flower1' },
  { value: 'abogado',    label: 'Abogado',       color: 'warning',   icon: 'bi-briefcase-fill' },
  { value: 'auditor',    label: 'Auditor',       color: 'secondary', icon: 'bi-clipboard-data-fill' },
  { value: 'socio',      label: 'Socio',         color: 'dark',      icon: 'bi-person-fill' }
]

const getRoleInfo = (role) => ROLES.find(r => r.value === role) || { label: role, color: 'secondary', icon: 'bi-person' }
const getInitials  = (user) => {
  const first = user.first_name?.[0] || ''
  const last  = user.last_name?.[0]  || ''
  return (first + last).toUpperCase() || user.email[0].toUpperCase()
}

// Todas las sedes únicas derivadas de las salas disponibles
const sedesDisponibles = computed(() => todasLasSedes.value)

// Solo salas de produccion o mixta para la sede seleccionada
const salasDeLaSede = computed(() =>
  todasLasSalas.value.filter(s =>
    s.sede?.id === form.value.sede_id &&
    ['produccion', 'mixta'].includes(s.sede?.tipo)
  )
)

onMounted(() => store.fetch())

async function search() {
  await store.fetch({ query: q.value })
}

function startCreate() {
  editing.value   = false
  form.value      = { id: null, first_name: "", last_name: "", email: "", role: "cultivador", sede_id: "", sala_id: "" }
  showModal.value = true
}

function startEdit(u) {
  editing.value   = true
  form.value      = { id: u.id, first_name: u.first_name || "", last_name: u.last_name || "", email: u.email || "", role: u.role || "cultivador", sede_id: "", sala_id: "" }
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
      if (form.value.role === 'cultivador' && form.value.sala_id) {
        await asignarSalaAUsuario(form.value.id, form.value.sala_id)
      }
      showModal.value = false
      toast.value = { t: "success", m: "Usuario actualizado." }
    } else {
      const nuevo = await store.create(payload)
      if (form.value.role === 'cultivador' && form.value.sala_id && nuevo?.id) {
        await asignarSalaAUsuario(nuevo.id, form.value.sala_id)
      }
      showModal.value = false
      if (form.value.role === 'cultivador' && nuevo?.id) {
        router.push({ name: 'usuario-detail', params: { id: nuevo.id } })
        toast.value = { t: "success", m: "Usuario creado. Podés asignar más salas desde el perfil." }
      } else {
        toast.value = { t: "success", m: "Usuario creado." }
      }
    }
  } catch (e) {
    toast.value = { t: "danger", m: store.error || "Error al guardar." }
  }
}

async function removeOne(u) {
  if (!confirm(`¿Eliminar a ${u.first_name || ''} ${u.last_name || ''}?`)) return
  try {
    await store.remove(u.id)
    toast.value = { t: "success", m: "Usuario eliminado." }
  } catch {
    toast.value = { t: "danger", m: store.error || "No se pudo eliminar." }
  }
}

async function sendReset(u) {
  try {
    await store.sendReset(u.id)
    toast.value = { t: "success", m: "Email de reinicio de contraseña enviado." }
  } catch {
    toast.value = { t: "danger", m: store.error || "No se pudo enviar el email." }
  }
}

watch(showModal, async (val) => {
  if (val) {
    try {
      const [resSalas, resSedes] = await Promise.all([listSalas(), listSedes()])
      todasLasSalas.value = resSalas.data || []
      todasLasSedes.value = resSedes.data || []
    } catch (e) {
      console.error('Error cargando datos:', e)
    }
  }
})
</script>

<template>
  <div>
    <div class="d-flex align-items-center justify-content-between mb-4">
      <h2 class="mb-0">
        <i class="bi bi-people-fill me-2"></i>Equipo
      </h2>
      <button class="btn btn-success" @click="startCreate">
        <i class="bi bi-plus-circle me-2"></i>Nuevo Usuario
      </button>
    </div>

    <div v-if="toast" class="alert alert-dismissible fade show" :class="toast.t==='success'?'alert-success':'alert-danger'">
      {{ toast.m }}
      <button type="button" class="btn-close" @click="toast = null"></button>
    </div>

    <div class="row g-3 mb-4">
      <div class="col-md-6">
        <input class="form-control" v-model.trim="q"
               placeholder="Buscar por nombre, apellido o email" @keyup.enter="search">
      </div>
      <div class="col-auto">
        <button class="btn btn-outline-secondary" @click="search">
          <i class="bi bi-search me-1"></i>Buscar
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
        <i class="bi bi-plus-circle me-2"></i>Crear Primer Usuario
      </button>
    </div>

    <div v-else class="row g-3">
      <div v-for="u in store.items" :key="u.id" class="col-md-6 col-lg-4">
        <div class="card h-100 shadow-sm">
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
              <RouterLink class="btn btn-sm btn-primary"
                          :to="{ name: 'usuario-detail', params: { id: u.id } }"
                          title="Ver detalle">
                <i class="bi bi-person-lines-fill"></i>
              </RouterLink>
              <button class="btn btn-sm btn-outline-secondary" @click="startEdit(u)" title="Editar">
                <i class="bi bi-pencil"></i>
              </button>
              <button class="btn btn-sm btn-outline-warning" @click="sendReset(u)" title="Reiniciar contraseña">
                <i class="bi bi-key"></i>
              </button>
              <button class="btn btn-sm btn-outline-danger" @click="removeOne(u)" title="Eliminar">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal crear/editar -->
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
                <input class="form-control" v-model.trim="form.first_name" placeholder="Juan" required>
              </div>
              <div class="col-md-6">
                <label class="form-label">Apellido *</label>
                <input class="form-control" v-model.trim="form.last_name" placeholder="Pérez" required>
              </div>
              <div class="col-12">
                <label class="form-label">Email *</label>
                <input type="email" class="form-control" v-model.trim="form.email"
                       placeholder="usuario@ejemplo.com" required>
                <small class="text-muted">Se enviará un email para configurar la contraseña</small>
              </div>
              <div class="col-12">
                <label class="form-label">Rol *</label>
                <select class="form-select" v-model="form.role" required>
                  <option v-for="role in ROLES" :key="role.value" :value="role.value">
                    {{ role.label }}
                  </option>
                </select>
              </div>

              <!-- Sede y Sala encadenadas — solo cultivador -->
              <template v-if="form.role === 'cultivador'">
                <div class="col-12">
                  <label class="form-label">Sede</label>
                  <select class="form-select" v-model="form.sede_id" @change="form.sala_id = ''">
                    <option value="">Seleccioná una sede...</option>
                    <option v-for="sede in sedesDisponibles" :key="sede.id" :value="sede.id">
                      {{ sede.nombre }}
                      <template v-if="sede.tipo === 'social'"> (Social)</template>
                    </option>
                  </select>
                </div>

                <!-- Salas disponibles si la sede es produccion o mixta -->
                <div v-if="form.sede_id && salasDeLaSede.length > 0" class="col-12">
                  <label class="form-label">Sala</label>
                  <select class="form-select" v-model="form.sala_id">
                    <option value="">Seleccioná una sala...</option>
                    <option v-for="sala in salasDeLaSede" :key="sala.id" :value="sala.id">
                      {{ sala.nombre }}
                    </option>
                  </select>
                  <small class="text-muted">
                    El cultivador solo verá esta sala. Podés asignar más desde su perfil.
                  </small>
                </div>

                <!-- Aviso sede social sin salas -->
                <div v-else-if="form.sede_id && salasDeLaSede.length === 0" class="col-12">
                  <div class="alert alert-info py-2 small mb-0">
                    <i class="bi bi-info-circle me-1"></i>
                    Esta sede es social — no tiene salas de cultivo asignables.
                  </div>
                </div>
              </template>

            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" @click="showModal=false">Cancelar</button>
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
  width: 42px;
  height: 42px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 0.9rem;
  flex-shrink: 0;
}
</style>
