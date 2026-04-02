<script setup>
import { ref, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import { useAuthStore } from "../stores/auth"
import UsuarioSalasManager from '../components/UsuarioSalasManager.vue'
import UsuarioSedesManager from "../components/UsuarioSedesManager.vue";

const route  = useRoute()
const router = useRouter()
const store  = useUsuariosStore()
const auth   = useAuthStore()

const userId  = Number(route.params.id)
const loading = ref(true)
const error   = ref(null)
const toast   = ref(null)

const u = computed(() => store.current)

const isMe     = computed(() => auth.user?.id === userId)
const canEdit  = computed(() => auth.role === "admin" && !isMe.value)

const ROLES = [
  { value: "admin",      label: "Administrador", color: "danger",    icon: "bi-shield-fill-check",  desc: "Acceso total al sistema" },
  { value: "medico",     label: "Médico",        color: "success",   icon: "bi-heart-pulse-fill",   desc: "Gestión de pacientes e indicaciones" },
  { value: "agricultor", label: "Agricultor",    color: "primary",   icon: "bi-tree-fill",          desc: "Gestión de producción, lotes y salas" },
  { value: "cultivador", label: "Cultivador",    color: "info",      icon: "bi-flower1",            desc: "Seguimiento de plantas y actividades" },
  { value: "abogado",    label: "Abogado",       color: "warning",   icon: "bi-briefcase-fill",     desc: "Acceso a documentos y trazabilidad legal" },
  { value: "auditor",    label: "Auditor",       color: "secondary", icon: "bi-clipboard-data-fill", desc: "Lectura de informes y reportes" },
  { value: "socio",      label: "Socio",         color: "dark",      icon: "bi-person-fill",        desc: "Acceso a su propio perfil y dispensaciones" },
]

function roleInfo(role) {
  return ROLES.find(r => r.value === role) || { label: role, color: "secondary", icon: "bi-person", desc: "" }
}
function getInitials(user) {
  if (!user) return "?"
  const f = user.first_name?.[0] || ""
  const l = user.last_name?.[0]  || ""
  return (f + l).toUpperCase() || user.email?.[0]?.toUpperCase() || "?"
}
function formatDate(d) {
  if (!d) return "—"
  return new Date(d).toLocaleDateString("es-AR", { day: "numeric", month: "long", year: "numeric" })
}

// ── Editar rol inline ─────────────────────────────────────────────────────────
const editingRole = ref(false)
const newRole     = ref("")

function startEditRole() {
  newRole.value     = u.value?.role || ""
  editingRole.value = true
}
async function saveRole() {
  try {
    await store.update(userId, { role: newRole.value })
    editingRole.value = false
    toast.value = { t: "success", m: "Rol actualizado correctamente." }
  } catch {
    toast.value = { t: "danger", m: store.error || "No se pudo actualizar el rol." }
  }
}

// ── Reset password ────────────────────────────────────────────────────────────
const sendingReset = ref(false)
async function sendReset() {
  sendingReset.value = true
  try {
    await store.sendReset(userId)
    toast.value = { t: "success", m: "Email de reinicio de contraseña enviado." }
  } catch {
    toast.value = { t: "danger", m: store.error || "No se pudo enviar el email." }
  } finally {
    sendingReset.value = false
  }
}

// ── Eliminar ──────────────────────────────────────────────────────────────────
const showDelete = ref(false)
async function doDelete() {
  try {
    await store.remove(userId)
    router.push({ name: "usuarios" })
  } catch {
    toast.value = { t: "danger", m: store.error || "No se pudo eliminar el usuario." }
    showDelete.value = false
  }
}

onMounted(async () => {
  try {
    await store.fetchOne(userId)
  } catch {
    error.value = "No se pudo cargar el usuario."
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Breadcrumb -->
    <nav aria-label="breadcrumb" class="mb-3">
      <ol class="breadcrumb small">
        <li class="breadcrumb-item">
          <RouterLink :to="{ name: 'usuarios' }">Equipo</RouterLink>
        </li>
        <li class="breadcrumb-item active">
          {{ u ? `${u.first_name} ${u.last_name}` : `Usuario #${userId}` }}
        </li>
      </ol>
    </nav>

    <!-- Toast -->
    <div v-if="toast" class="alert alert-dismissible fade show mb-3"
         :class="`alert-${toast.t}`">
      {{ toast.m }}
      <button class="btn-close" @click="toast = null"></button>
    </div>

    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-primary"></div>
    </div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!u" class="alert alert-warning">Usuario no encontrado.</div>

    <template v-else>

      <!-- Header -->
      <div class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-4">
        <div class="d-flex align-items-center gap-3">
          <!-- Avatar -->
          <div class="avatar-xl d-flex align-items-center justify-content-center rounded-circle text-white fw-bold fs-2 flex-shrink-0"
               :class="`bg-${roleInfo(u.role).color}`">
            {{ getInitials(u) }}
          </div>
          <div>
            <h1 class="h3 fw-bold mb-1">{{ u.first_name }} {{ u.last_name }}</h1>
            <div class="text-muted small">{{ u.email }}</div>
            <div class="mt-1">
              <span class="badge" :class="`text-bg-${roleInfo(u.role).color}`">
                <i :class="roleInfo(u.role).icon + ' me-1'"></i>
                {{ roleInfo(u.role).label }}
              </span>
              <span v-if="isMe" class="badge text-bg-light text-dark ms-2">Vos</span>
            </div>
          </div>
        </div>

        <!-- Acciones -->
        <div v-if="canEdit" class="d-flex gap-2 flex-wrap">
          <button class="btn btn-outline-warning btn-sm" :disabled="sendingReset"
                  @click="sendReset">
            <span v-if="sendingReset" class="spinner-border spinner-border-sm me-1"></span>
            <i v-else class="bi bi-key me-1"></i> Resetear contraseña
          </button>
          <button class="btn btn-outline-danger btn-sm" @click="showDelete = true">
            <i class="bi bi-trash me-1"></i> Eliminar
          </button>
        </div>
      </div>

      <div class="row g-4">

        <!-- Col principal -->
        <div class="col-12 col-lg-8">

          <!-- Información personal -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-header bg-transparent"><strong>👤 Información personal</strong></div>
            <div class="card-body">
              <div class="row g-3">
                <div class="col-md-6">
                  <div class="text-muted small mb-1">Nombre</div>
                  <div class="fw-semibold">{{ u.first_name || "—" }}</div>
                </div>
                <div class="col-md-6">
                  <div class="text-muted small mb-1">Apellido</div>
                  <div class="fw-semibold">{{ u.last_name || "—" }}</div>
                </div>
                <div class="col-12">
                  <div class="text-muted small mb-1">Email</div>
                  <div class="fw-semibold">{{ u.email }}</div>
                </div>
                <div class="col-md-6">
                  <div class="text-muted small mb-1">Miembro desde</div>
                  <div class="fw-semibold">{{ formatDate(u.created_at) }}</div>
                </div>
                <div class="col-md-6">
                  <div class="text-muted small mb-1">Última actualización</div>
                  <div class="fw-semibold">{{ formatDate(u.updated_at) }}</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Permisos del rol -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent"><strong>🔐 Permisos del rol</strong></div>
            <div class="card-body">
              <div class="row g-2">
                <template v-if="u.role === 'admin'">
                  <div class="col-12">
                    <div class="alert alert-danger mb-0 small">
                      <i class="bi bi-shield-fill-check me-2"></i>
                      Acceso total al sistema — puede gestionar todos los módulos, usuarios y configuración.
                    </div>
                  </div>
                </template>
                <template v-else-if="u.role === 'medico'">
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Ver y gestionar pacientes</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Crear indicaciones médicas</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Registrar dispensaciones</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-x-circle-fill text-danger"></i>Gestionar producción</div></div>
                </template>
                <template v-else-if="u.role === 'agricultor'">
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Gestionar sedes y salas</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Crear y gestionar lotes</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Gestionar plantas</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-x-circle-fill text-danger"></i>Gestionar pacientes</div></div>
                </template>
                <template v-else-if="u.role === 'cultivador'">
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Ver salas y lotes</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Actualizar estado de plantas</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Registrar actividades</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-x-circle-fill text-danger"></i>Crear lotes o dispensar</div></div>
                </template>
                <template v-else-if="u.role === 'abogado'">
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Ver pacientes (solo lectura)</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Acceso a contabilidad</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Trazabilidad legal</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-x-circle-fill text-danger"></i>Modificar datos clínicos</div></div>
                </template>
                <template v-else-if="u.role === 'auditor'">
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Lectura de todos los módulos</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-check-circle-fill text-success"></i>Ver contabilidad</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-x-circle-fill text-danger"></i>Crear o modificar datos</div></div>
                  <div class="col-md-6"><div class="d-flex align-items-center gap-2 small"><i class="bi bi-x-circle-fill text-danger"></i>Gestionar usuarios</div></div>
                </template>
                <template v-else>
                  <div class="col-12 small text-muted">Sin permisos especiales definidos para este rol.</div>
                </template>
              </div>
            </div>
          </div>

          <div v-if="u.role === 'cultivador'" class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent">
              <strong>🏠 Salas asignadas</strong>
            </div>
            <div class="card-body">
              <UsuarioSalasManager :user-id="userId" />
              <!-- Sedes asignadas (médico y auditor) -->
              <div v-if="['medico', 'auditor'].includes(u.role)" class="card border-0 shadow-sm mb-3">
                <div class="card-header bg-transparent">
                  <strong>🏢 Sedes asignadas</strong>
                </div>
                <div class="card-body">
                  <UsuarioSedesManager :user-id="userId" />
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Col lateral -->
        <div class="col-12 col-lg-4">

          <!-- Cambiar rol -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>🎭 Rol</strong>
              <button v-if="canEdit && !editingRole" class="btn btn-sm btn-outline-secondary"
                      @click="startEditRole">
                ✏️ Cambiar
              </button>
            </div>
            <div class="card-body">
              <div v-if="!editingRole">
                <div class="d-flex align-items-center gap-2 mb-2">
                  <span class="badge fs-6" :class="`text-bg-${roleInfo(u.role).color}`">
                    <i :class="roleInfo(u.role).icon + ' me-1'"></i>
                    {{ roleInfo(u.role).label }}
                  </span>
                </div>
                <div class="small text-muted">{{ roleInfo(u.role).desc }}</div>
              </div>
              <div v-else>
                <select class="form-select form-select-sm mb-2" v-model="newRole">
                  <option v-for="r in ROLES" :key="r.value" :value="r.value">
                    {{ r.label }}
                  </option>
                </select>
                <div class="small text-muted mb-3">{{ roleInfo(newRole).desc }}</div>
                <div class="d-flex gap-2">
                  <button class="btn btn-sm btn-primary flex-fill" :disabled="store.saving"
                          @click="saveRole">
                    <span v-if="store.saving" class="spinner-border spinner-border-sm me-1"></span>
                    Guardar
                  </button>
                  <button class="btn btn-sm btn-outline-secondary" @click="editingRole = false">
                    Cancelar
                  </button>
                </div>
              </div>
            </div>

          </div>

          <!-- Acceso rápido -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>⚡ Acciones</strong></div>
            <div class="list-group list-group-flush">
              <button v-if="canEdit" class="list-group-item list-group-item-action small py-2 text-warning"
                      :disabled="sendingReset" @click="sendReset">
                <i class="bi bi-key me-2"></i>Enviar reset de contraseña
              </button>
              <RouterLink :to="{ name: 'usuarios' }"
                          class="list-group-item list-group-item-action small py-2">
                <i class="bi bi-arrow-left me-2"></i>Volver al equipo
              </RouterLink>
            </div>
          </div>

          <!-- Info técnica -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent"><strong>ℹ️ Info</strong></div>
            <div class="card-body small">
              <dl class="row mb-0">
                <dt class="col-5 text-muted fw-normal">ID</dt>
                <dd class="col-7">{{ u.id }}</dd>
                <dt class="col-5 text-muted fw-normal">Creado</dt>
                <dd class="col-7">{{ formatDate(u.created_at) }}</dd>
                <dt class="col-5 text-muted fw-normal">Actualizado</dt>
                <dd class="col-7 mb-0">{{ formatDate(u.updated_at) }}</dd>
              </dl>
            </div>
          </div>

        </div>
      </div>
    </template>

    <!-- ═══════════════ MODAL ELIMINAR ═══════════════ -->
    <div class="modal fade" :class="{ show: showDelete }"
         :style="{ display: showDelete ? 'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0 pb-0">
            <button class="btn-close ms-auto" @click="showDelete = false"></button>
          </div>
          <div class="modal-body text-center py-2">
            <div class="display-4 mb-3">⚠️</div>
            <h5>¿Eliminar a {{ u?.first_name }} {{ u?.last_name }}?</h5>
            <p class="text-muted small">Esta acción no se puede deshacer. El usuario perderá acceso inmediatamente.</p>
          </div>
          <div class="modal-footer justify-content-center border-0">
            <button class="btn btn-outline-secondary px-4" @click="showDelete = false">Cancelar</button>
            <button class="btn btn-danger px-4" :disabled="store.removing" @click="doDelete">
              <span v-if="store.removing" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showDelete }" v-if="showDelete"
         @click="showDelete = false"></div>

  </div>
</template>

<style scoped>
.avatar-xl {
  width: 72px;
  height: 72px;
  font-size: 1.8rem;
}
</style>
