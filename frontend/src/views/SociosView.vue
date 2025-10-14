<!-- src/views/SociosView.vue -->
<script setup>
import { ref, onMounted } from "vue"
import { useSociosStore } from "../stores/socios"

const store = useSociosStore()

const q = ref("")      // búsqueda por nombre/apellido/dni/email (tu backend decide)
const showModal = ref(false)
const form = ref({
  id: null,
  nombre: "",
  apellido: "",
  dni: "",
  email: "",
  telefono: "",
  fecha_nacimiento: "",
  es_paciente: true
})
const editing = ref(false)
const toast = ref(null)

onMounted(() => store.fetch())

async function search() {
  await store.fetch({ query: q.value })
}

function startCreate() {
  editing.value = false
  form.value = { id:null, nombre:"", apellido:"", dni:"", email:"", telefono:"", fecha_nacimiento: "", es_paciente: true }
  showModal.value = true
}

function startEdit(s) {
  editing.value = true
  form.value = {
    id: s.id,
    nombre: s.nombre || s.first_name || "",
    apellido: s.apellido || s.last_name || "",
    dni: s.dni || "",
    email: s.email || "",
    telefono: s.telefono || s.phone || "",
    fecha_nacimiento: (s.fecha_nacimiento || "").toString().slice(0, 10),
    es_paciente: s.es_paciente ?? true
  }
  showModal.value = true
}

async function save() {
  try {
    const payload = {
      nombre: form.value.nombre,
      apellido: form.value.apellido,
      dni: form.value.dni,
      email: form.value.email,
      telefono: form.value.telefono,
      fecha_nacimiento: form.value.fecha_nacimiento,
      es_paciente: !!form.value.es_paciente,
    }
    if (editing.value && form.value.id) {
      await store.update(form.value.id, payload)
      toast.value = { t:"success", m:"Socio actualizado." }
    } else {
      await store.create(payload)
      toast.value = { t:"success", m:"Socio creado." }
    }
    showModal.value = false
  } catch (e) {
    toast.value = { t:"danger", m: store.error || "Error al guardar." }
  }
}

async function removeOne(s) {
  if (!confirm(`¿Eliminar a ${s.nombre} ${s.apellido}?`)) return
  try {
    await store.remove(s.id)
    toast.value = { t:"success", m:"Socio eliminado." }
  } catch (e) {
    toast.value = { t:"danger", m: store.error || "No se pudo eliminar." }
  }
}

</script>

<template>
  <div>
    <div class="d-flex align-items-center justify-content-between mb-3">
      <h2 class="mb-0">Socios</h2>
      <button class="btn btn-success" @click="startCreate">
        + Nuevo socio
      </button>
    </div>

    <div v-if="toast" class="alert" :class="toast.t==='success'?'alert-success':'alert-danger'">
      {{ toast.m }}
    </div>

    <div class="row g-2 mb-3">
      <div class="col-md-6">
        <input class="form-control" v-model.trim="q" placeholder="Buscar por nombre, apellido, DNI o email" @keyup.enter="search">
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
          <th>DNI</th>
          <th>Email</th>
          <th>Teléfono</th>
          <th class="text-end">Acciones</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="s in store.items" :key="s.id">
          <td>
            <router-link :to="`/socios/${s.id}`" class="text-decoration-none">
              {{ s.nombre || s.first_name }} {{ s.apellido || s.last_name }}
            </router-link>
          </td>
          <td>{{ s.dni }}</td>
          <td>{{ s.email }}</td>
          <td>{{ s.telefono || s.phone }}</td>
          <td class="text-end">
            <button class="btn btn-sm btn-outline-secondary me-2" @click="startEdit(s)">Editar</button>
            <button class="btn btn-sm btn-outline-danger" @click="removeOne(s)">Borrar</button>
          </td>
        </tr>
        <tr v-if="!store.loading && store.items.length===0">
          <td colspan="5" class="text-muted text-center">Sin resultados.</td>
        </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal -->
    <div class="modal fade" :class="{ show: showModal }" :style="{ display: showModal ? 'block':'none' }" tabindex="-1">
      <div class="modal-dialog modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editing ? 'Editar socio' : 'Nuevo socio' }}</h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>

          <div class="modal-body">
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Nombre *</label>
                <input class="form-control" v-model.trim="form.nombre">
              </div>
              <div class="col-md-6">
                <label class="form-label">Apellido *</label>
                <input class="form-control" v-model.trim="form.apellido">
              </div>

              <div class="col-md-6">
                <label class="form-label">DNI *</label>
                <input class="form-control" v-model.trim="form.dni">
              </div>

              <div class="col-md-6">
                <label class="form-label">Fecha de nacimiento *</label>
                <input type="date" class="form-control" v-model="form.fecha_nacimiento">
              </div>

              <div class="col-md-6">
                <label class="form-label">Email</label>
                <input type="email" class="form-control" v-model.trim="form.email">
              </div>

              <div class="col-md-6">
                <label class="form-label">Teléfono</label>
                <input class="form-control" v-model.trim="form.telefono">
              </div>

              <div class="col-12">
                <div class="form-check form-switch">
                  <input class="form-check-input" type="checkbox" id="chkPaciente" v-model="form.es_paciente">
                  <label class="form-check-label" for="chkPaciente">Es paciente</label>
                </div>
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
