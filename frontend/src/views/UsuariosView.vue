<script setup>
import { ref, onMounted } from "vue"
import { useUsuariosStore } from "../stores/usuarios"

const store = useUsuariosStore()

const q = ref("")
const showModal = ref(false)
const editing = ref(false)
const form = ref({ id:null, first_name:"", last_name:"", email:"", role:"cultivador" })
const toast = ref(null)

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
  form.value = { id:u.id, first_name:u.first_name || "", last_name:u.last_name || "", email:u.email || "", role:u.role || "cultivador" }
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
    <div class="d-flex align-items-center justify-content-between mb-3">
      <h2 class="mb-0">Usuarios</h2>
      <button class="btn btn-success" @click="startCreate">+ Nuevo usuario</button>
    </div>

    <div v-if="toast" class="alert" :class="toast.t==='success'?'alert-success':'alert-danger'">
      {{ toast.m }}
    </div>

    <div class="row g-2 mb-3">
      <div class="col-md-6">
        <input class="form-control" v-model.trim="q" placeholder="Buscar por nombre, apellido o email" @keyup.enter="search">
      </div>
      <div class="col-auto">
        <button class="btn btn-outline-secondary" @click="search">Buscar</button>
      </div>
    </div>

    <div class="table-responsive">
      <table class="table align-middle table-hover">
        <thead>
        <tr>
          <th>Nombre</th>
          <th>Email</th>
          <th>Rol</th>
          <th class="text-end">Acciones</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="u in store.items" :key="u.id">
          <td>{{ (u.first_name || '') + ' ' + (u.last_name || '') }}</td>
          <td>{{ u.email }}</td>
          <td class="text-capitalize">{{ u.role }}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-secondary me-2" @click="startEdit(u)">Editar</button>
            <button class="btn btn-sm btn-outline-warning me-2" @click="sendReset(u)">Reiniciar contraseña</button>
            <button class="btn btn-sm btn-outline-danger" @click="removeOne(u)">Borrar</button>
          </td>
        </tr>
        <tr v-if="!store.loading && store.items.length===0">
          <td colspan="4" class="text-muted text-center">Sin usuarios.</td>
        </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div class="modal fade" :class="{ show: showModal }" :style="{ display: showModal ? 'block':'none' }" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editing ? 'Editar usuario' : 'Nuevo usuario' }}</h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">
            <div class="row g-2">
              <div class="col-md-6">
                <label class="form-label">Nombre</label>
                <input class="form-control" v-model.trim="form.first_name">
              </div>
              <div class="col-md-6">
                <label class="form-label">Apellido</label>
                <input class="form-control" v-model.trim="form.last_name">
              </div>
              <div class="col-md-12">
                <label class="form-label">Email</label>
                <input type="email" class="form-control" v-model.trim="form.email">
              </div>
              <div class="col-md-6">
                <label class="form-label">Rol</label>
                <select class="form-select text-capitalize" v-model="form.role">
                  <option value="cultivador">cultivador</option>
                  <option value="admin">admin</option>
                  <option value="super_admin">super_admin</option>
                </select>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" @click="showModal=false">Cancelar</button>
            <button class="btn btn-primary" :disabled="store.saving" @click="save">
              <span v-if="store.saving" class="spinner-border spinner-border-sm me-2"></span>
              Guardar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showModal }" v-if="showModal" @click="showModal=false"></div>
  </div>
</template>
