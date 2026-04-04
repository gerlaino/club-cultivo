<script setup>
import { ref, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import { useAuthStore } from "../stores/auth"
import UsuarioSalasManager from '../components/UsuarioSalasManager.vue'

const route  = useRoute()
const router = useRouter()
const store  = useUsuariosStore()
const auth   = useAuthStore()

const userId  = Number(route.params.id)
const loading = ref(true)
const error   = ref(null)
const toast   = ref(null)
const toastTimer = ref(null)

const u = computed(() => store.current)

const isMe    = computed(() => auth.user?.id === userId)
const canEdit = computed(() => auth.role === "admin" && !isMe.value)

const ROLES = [
  { value: "admin",      label: "Administrador", color: "#dc2626", bg: "rgba(220,38,38,.1)",  icon: "bi-shield-fill-check",   desc: "Acceso total al sistema — puede gestionar todos los módulos, usuarios y configuración." },
  { value: "medico",     label: "Médico",        color: "#15803d", bg: "rgba(21,128,61,.1)",  icon: "bi-heart-pulse-fill",    desc: "Gestión de pacientes e indicaciones médicas. Sin acceso a producción." },
  { value: "agricultor", label: "Agricultor",    color: "#0369a1", bg: "rgba(3,105,161,.1)",  icon: "bi-tree-fill",           desc: "Gestión de sedes, salas, lotes y plantas. Sin acceso a pacientes." },
  { value: "cultivador", label: "Cultivador",    color: "#0891b2", bg: "rgba(8,145,178,.1)",  icon: "bi-flower1",             desc: "Seguimiento de plantas y actividades en sus salas asignadas." },
  { value: "abogado",    label: "Abogado",       color: "#b45309", bg: "rgba(180,83,9,.1)",   icon: "bi-briefcase-fill",      desc: "Acceso a documentos, contabilidad y trazabilidad legal. Solo lectura clínica." },
  { value: "auditor",    label: "Auditor",       color: "#475569", bg: "rgba(71,85,105,.1)",  icon: "bi-clipboard-data-fill", desc: "Lectura de todos los módulos e informes. Sin modificar datos." },
]

const PERMISOS = {
  admin:      [{ ok: true, label: "Gestión total del sistema" }, { ok: true, label: "Usuarios y configuración" }, { ok: true, label: "Contabilidad y documentos" }, { ok: true, label: "Todos los módulos" }],
  medico:     [{ ok: true, label: "Gestionar pacientes" }, { ok: true, label: "Indicaciones médicas" }, { ok: true, label: "Dispensaciones" }, { ok: false, label: "Gestión de producción" }],
  agricultor: [{ ok: true, label: "Sedes y salas" }, { ok: true, label: "Lotes y plantas" }, { ok: true, label: "Genéticas" }, { ok: false, label: "Pacientes y clínico" }],
  cultivador: [{ ok: true, label: "Ver salas asignadas" }, { ok: true, label: "Actualizar plantas" }, { ok: true, label: "Registrar actividades" }, { ok: false, label: "Crear lotes o dispensar" }],
  abogado:    [{ ok: true, label: "Documentos legales" }, { ok: true, label: "Contabilidad (lectura)" }, { ok: true, label: "Trazabilidad" }, { ok: false, label: "Modificar datos clínicos" }],
  auditor:    [{ ok: true, label: "Lectura completa" }, { ok: true, label: "Contabilidad" }, { ok: false, label: "Crear o modificar datos" }, { ok: false, label: "Gestionar usuarios" }],
}

const AVATAR_COLORS = ['#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626','#15803d']

function roleInfo(role) { return ROLES.find(r => r.value === role) || { label: role, color: '#475569', bg: 'rgba(71,85,105,.1)', icon: 'bi-person', desc: '' } }
function getInitials(user) {
  if (!user) return '?'
  return ((user.first_name?.[0] || '') + (user.last_name?.[0] || '')).toUpperCase() || user.email?.[0]?.toUpperCase() || '?'
}
function getAvatarColor(user) { return AVATAR_COLORS[(user?.id || 0) % AVATAR_COLORS.length] }
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

function showToast(type, msg) {
  clearTimeout(toastTimer.value)
  toast.value = { type, msg }
  toastTimer.value = setTimeout(() => toast.value = null, 3500)
}

// ── Editar rol ────────────────────────────────────────────
const editingRole = ref(false)
const newRole     = ref('')
function startEditRole() { newRole.value = u.value?.role || ''; editingRole.value = true }
async function saveRole() {
  try {
    await store.update(userId, { role: newRole.value })
    editingRole.value = false
    showToast('success', 'Rol actualizado correctamente.')
  } catch { showToast('error', store.error || 'No se pudo actualizar el rol.') }
}

// ── Eliminar ──────────────────────────────────────────────
const showDelete = ref(false)
async function doDelete() {
  try {
    await store.remove(userId)
    router.push({ name: 'usuarios' })
  } catch {
    showToast('error', store.error || 'No se pudo eliminar el usuario.')
    showDelete.value = false
  }
}

onMounted(async () => {
  try { await store.fetchOne(userId) }
  catch { error.value = 'No se pudo cargar el usuario.' }
  finally { loading.value = false }
})
</script>

<template>
  <div class="ud">

    <!-- Toast -->
    <Transition name="ud-toast">
      <div v-if="toast" class="ud__toast" :class="`ud__toast--${toast.type}`">
        <i :class="toast.type === 'success' ? 'bi bi-check-circle-fill' : 'bi bi-exclamation-triangle-fill'"></i>
        {{ toast.msg }}
      </div>
    </Transition>

    <!-- Breadcrumb -->
    <nav class="ud__breadcrumb">
      <RouterLink :to="{ name: 'usuarios' }" class="ud__breadcrumb-link">Equipo</RouterLink>
      <span class="ud__breadcrumb-sep">›</span>
      <span class="ud__breadcrumb-current">{{ u ? `${u.first_name} ${u.last_name}` : `Usuario #${userId}` }}</span>
    </nav>

    <div v-if="loading" class="ud__loading">
      <div class="ud__ring"></div><span>Cargando…</span>
    </div>
    <div v-else-if="error" class="ud__error">{{ error }}</div>
    <div v-else-if="!u" class="ud__error">Usuario no encontrado.</div>

    <template v-else>

      <!-- Hero -->
      <div class="ud__hero">
        <div class="ud__hero-bg" :style="{ background: `linear-gradient(135deg, ${getAvatarColor(u)}22, ${roleInfo(u.role).color}11)` }"></div>

        <div class="ud__hero-content">
          <div class="ud__avatar-wrap">
            <div class="ud__avatar" :style="{ background: getAvatarColor(u) }">
              {{ getInitials(u) }}
            </div>
            <div class="ud__avatar-role" :style="{ background: roleInfo(u.role).color }">
              <i :class="['bi', roleInfo(u.role).icon]"></i>
            </div>
          </div>

          <div class="ud__hero-info">
            <div class="ud__hero-name">{{ u.first_name }} {{ u.last_name }}
              <span v-if="isMe" class="ud__me-badge">Vos</span>
            </div>
            <div class="ud__hero-email">{{ u.email }}</div>
            <div class="ud__hero-role" :style="{ color: roleInfo(u.role).color }">
              <i :class="['bi', roleInfo(u.role).icon]"></i>
              {{ roleInfo(u.role).label }}
            </div>
          </div>

          <div v-if="canEdit" class="ud__hero-actions">
            <button class="ud__btn-danger-outline" @click="showDelete = true">
              <i class="bi bi-trash"></i> Eliminar
            </button>
          </div>
        </div>
      </div>

      <!-- Layout -->
      <div class="ud__layout">

        <!-- Main -->
        <div class="ud__main">

          <!-- Información personal -->
          <div class="ud__card">
            <div class="ud__card-header">
              <div class="ud__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
                <i class="bi bi-person"></i>
              </div>
              <span class="ud__card-title">Información personal</span>
            </div>
            <div class="ud__info-grid">
              <div class="ud__info-item">
                <div class="ud__info-label">Nombre</div>
                <div class="ud__info-val">{{ u.first_name || '—' }}</div>
              </div>
              <div class="ud__info-item">
                <div class="ud__info-label">Apellido</div>
                <div class="ud__info-val">{{ u.last_name || '—' }}</div>
              </div>
              <div class="ud__info-item ud__info-item--full">
                <div class="ud__info-label">Email</div>
                <div class="ud__info-val">{{ u.email }}</div>
              </div>
              <div class="ud__info-item">
                <div class="ud__info-label">Miembro desde</div>
                <div class="ud__info-val">{{ formatDate(u.created_at) }}</div>
              </div>
              <div class="ud__info-item">
                <div class="ud__info-label">Última actualización</div>
                <div class="ud__info-val">{{ formatDate(u.updated_at) }}</div>
              </div>
            </div>
          </div>

          <!-- Permisos del rol -->
          <div class="ud__card ud__card--mt">
            <div class="ud__card-header">
              <div class="ud__card-icon" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
                <i :class="['bi', roleInfo(u.role).icon]"></i>
              </div>
              <span class="ud__card-title">Accesos del rol — {{ roleInfo(u.role).label }}</span>
            </div>
            <div class="ud__card-body">
              <p class="ud__role-desc">{{ roleInfo(u.role).desc }}</p>
              <div class="ud__permisos">
                <div
                  v-for="p in PERMISOS[u.role] || []" :key="p.label"
                  class="ud__permiso"
                  :class="p.ok ? 'ud__permiso--ok' : 'ud__permiso--no'"
                >
                  <i :class="p.ok ? 'bi bi-check-circle-fill' : 'bi bi-x-circle-fill'"></i>
                  {{ p.label }}
                </div>
              </div>
            </div>
          </div>

          <!-- Salas asignadas — solo cultivador -->
          <div v-if="u.role === 'cultivador'" class="ud__card ud__card--mt">
            <div class="ud__card-header">
              <div class="ud__card-icon" style="background:rgba(8,145,178,.1);color:#0891b2">
                <i class="bi bi-grid-3x3-gap"></i>
              </div>
              <span class="ud__card-title">Salas asignadas</span>
            </div>
            <div class="ud__card-body">
              <UsuarioSalasManager :user-id="userId" />
            </div>
          </div>

        </div>

        <!-- Aside -->
        <div class="ud__aside">

          <!-- Rol -->
          <div class="ud__card">
            <div class="ud__card-header">
              <div class="ud__card-icon" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
                <i class="bi bi-shield-check"></i>
              </div>
              <span class="ud__card-title">Rol</span>
              <button v-if="canEdit && !editingRole" class="ud__edit-btn" @click="startEditRole">
                <i class="bi bi-pencil"></i> Cambiar
              </button>
            </div>
            <div class="ud__card-body">
              <div v-if="!editingRole" class="ud__role-display">
                <div class="ud__role-pill" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
                  <i :class="['bi', roleInfo(u.role).icon]"></i>
                  {{ roleInfo(u.role).label }}
                </div>
              </div>
              <div v-else class="ud__role-edit">
                <div class="ud__role-options">
                  <button
                    v-for="r in ROLES" :key="r.value"
                    class="ud__role-option"
                    :class="{ 'ud__role-option--active': newRole === r.value }"
                    :style="newRole === r.value ? { background: r.bg, borderColor: r.color, color: r.color } : {}"
                    @click="newRole = r.value"
                  >
                    <i :class="['bi', r.icon]"></i>
                    {{ r.label }}
                  </button>
                </div>
                <div class="ud__role-edit-actions">
                  <button class="ud__btn-ghost" @click="editingRole = false">Cancelar</button>
                  <button class="ud__btn-primary" :disabled="store.saving" @click="saveRole">
                    <div v-if="store.saving" class="ud__spinner"></div>
                    <i v-else class="bi bi-check-lg"></i>
                    Guardar
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Info técnica -->
          <div class="ud__card ud__card--mt">
            <div class="ud__card-header">
              <div class="ud__card-icon" style="background:rgba(71,85,105,.08);color:#475569">
                <i class="bi bi-info-circle"></i>
              </div>
              <span class="ud__card-title">Datos de cuenta</span>
            </div>
            <dl class="ud__dl">
              <dt>ID de usuario</dt><dd>#{{ u.id }}</dd>
              <dt>Creado</dt><dd>{{ formatDate(u.created_at) }}</dd>
              <dt>Actualizado</dt><dd>{{ formatDate(u.updated_at) }}</dd>
            </dl>
          </div>

          <!-- Volver -->
          <RouterLink :to="{ name: 'usuarios' }" class="ud__back-link">
            <i class="bi bi-arrow-left"></i>
            Volver al equipo
          </RouterLink>

        </div>
      </div>

    </template>

    <!-- Modal eliminar -->
    <Teleport to="body">
      <div v-if="showDelete" class="ud__overlay" @click.self="showDelete = false">
        <div class="ud__modal-delete">
          <div class="ud__delete-icon">
            <i class="bi bi-exclamation-triangle-fill"></i>
          </div>
          <h3 class="ud__delete-title">¿Eliminar usuario?</h3>
          <p class="ud__delete-desc">
            Vas a eliminar a <strong>{{ u?.first_name }} {{ u?.last_name }}</strong>.
            Esta acción no se puede deshacer — el usuario perderá acceso inmediatamente.
          </p>
          <div class="ud__delete-actions">
            <button class="ud__btn-ghost" @click="showDelete = false">Cancelar</button>
            <button class="ud__btn-danger" :disabled="store.removing" @click="doDelete">
              <div v-if="store.removing" class="ud__spinner ud__spinner--white"></div>
              <i v-else class="bi bi-trash"></i>
              Eliminar definitivamente
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.ud { padding: 2rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .ud { padding: 1.25rem 1rem 2rem; } }

/* Toast */
.ud__toast { position: fixed; top: 1.25rem; right: 1.25rem; z-index: 9999; display: flex; align-items: center; gap: .6rem; padding: .875rem 1.25rem; border-radius: 12px; font-size: .875rem; font-weight: 500; box-shadow: 0 8px 24px rgba(0,0,0,.15); max-width: 380px; }
.ud__toast--success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; }
.ud__toast--error   { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.ud-toast-enter-active, .ud-toast-leave-active { transition: all .25s ease; }
.ud-toast-enter-from, .ud-toast-leave-to { opacity: 0; transform: translateY(-10px); }

/* Breadcrumb */
.ud__breadcrumb { display: flex; align-items: center; gap: .4rem; font-size: .78rem; margin-bottom: 1.5rem; }
.ud__breadcrumb-link { color: #94a3b8; text-decoration: none; font-weight: 600; }
.ud__breadcrumb-link:hover { color: #1b5e20; }
.ud__breadcrumb-sep { color: #cbd5e1; }
.ud__breadcrumb-current { color: #0f172a; font-weight: 600; }

/* Loading / Error */
.ud__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.ud__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: ud-spin .7s linear infinite; }
@keyframes ud-spin { to { transform: rotate(360deg); } }
.ud__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; }

/* Hero */
.ud__hero { position: relative; border-radius: 18px; overflow: hidden; margin-bottom: 1.75rem; border: 1px solid #e2e8f0; }
.ud__hero-bg { position: absolute; inset: 0; }
.ud__hero-content { position: relative; display: flex; align-items: center; gap: 1.5rem; padding: 2rem 2rem; flex-wrap: wrap; }
.ud__avatar-wrap { position: relative; flex-shrink: 0; }
.ud__avatar { width: 72px; height: 72px; border-radius: 18px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 1.5rem; font-weight: 800; letter-spacing: -.02em; border: 3px solid rgba(255,255,255,.4); }
.ud__avatar-role { position: absolute; bottom: -4px; right: -4px; width: 26px; height: 26px; border-radius: 8px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: .65rem; border: 2px solid #fff; }
.ud__hero-info { flex: 1; min-width: 0; }
.ud__hero-name { font-size: 1.5rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; margin-bottom: .2rem; display: flex; align-items: center; gap: .65rem; }
.ud__me-badge { font-size: .65rem; font-weight: 700; background: #f1f5f9; color: #64748b; padding: .2em .6em; border-radius: 5px; letter-spacing: .04em; text-transform: uppercase; }
.ud__hero-email { font-size: .85rem; color: #64748b; margin-bottom: .4rem; }
.ud__hero-role { font-size: .82rem; font-weight: 700; display: flex; align-items: center; gap: .35rem; }
.ud__hero-actions { display: flex; gap: .6rem; margin-left: auto; }

/* Layout */
.ud__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .ud__layout { grid-template-columns: 1fr; } }
.ud__main { display: flex; flex-direction: column; }
.ud__aside { display: flex; flex-direction: column; gap: 1.1rem; position: sticky; top: 1.5rem; }

/* Cards */
.ud__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.ud__card--mt { margin-top: 1.25rem; }
.ud__card-header { display: flex; align-items: center; gap: .65rem; padding: .875rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.ud__card-icon { width: 30px; height: 30px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: .8rem; flex-shrink: 0; }
.ud__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; flex: 1; }
.ud__card-body { padding: 1.25rem; }

/* Info grid */
.ud__info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0; }
.ud__info-item { padding: 1rem 1.25rem; border-bottom: 1px solid #f8fafc; border-right: 1px solid #f8fafc; }
.ud__info-item:nth-child(even) { border-right: none; }
.ud__info-item--full { grid-column: 1 / -1; border-right: none; }
.ud__info-label { font-size: .72rem; color: #94a3b8; font-weight: 500; margin-bottom: .25rem; text-transform: uppercase; letter-spacing: .04em; }
.ud__info-val { font-size: .875rem; font-weight: 600; color: #0f172a; }

/* Permisos */
.ud__role-desc { font-size: .83rem; color: #64748b; margin-bottom: 1rem; line-height: 1.6; }
.ud__permisos { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
@media (max-width: 640px) { .ud__permisos { grid-template-columns: 1fr; } }
.ud__permiso { display: flex; align-items: center; gap: .5rem; font-size: .82rem; font-weight: 500; }
.ud__permiso--ok { color: #15803d; }
.ud__permiso--no { color: #94a3b8; }
.ud__permiso--ok i { color: #15803d; }
.ud__permiso--no i { color: #cbd5e1; }

/* Rol display */
.ud__role-display { padding: .25rem 0; }
.ud__role-pill { display: inline-flex; align-items: center; gap: .5rem; font-size: .85rem; font-weight: 700; padding: .45em 1em; border-radius: 9px; }

/* Rol edit */
.ud__role-options { display: flex; flex-direction: column; gap: .4rem; margin-bottom: 1rem; }
.ud__role-option { display: flex; align-items: center; gap: .5rem; padding: .55rem .875rem; border-radius: 9px; border: 1.5px solid #e2e8f0; background: #f8fafc; font-size: .82rem; font-weight: 500; cursor: pointer; color: #475569; transition: all .15s; text-align: left; }
.ud__role-option:hover { border-color: #cbd5e1; }
.ud__role-option--active { font-weight: 700; }
.ud__role-edit-actions { display: flex; gap: .5rem; justify-content: flex-end; }

/* DL */
.ud__dl { display: grid; grid-template-columns: auto 1fr; gap: .5rem .75rem; padding: .875rem 1.25rem; margin: 0; }
.ud__dl dt { font-size: .75rem; color: #94a3b8; font-weight: 500; }
.ud__dl dd { font-size: .82rem; color: #0f172a; font-weight: 500; margin: 0; }

/* Edit btn */
.ud__edit-btn { display: inline-flex; align-items: center; gap: .3rem; background: none; border: 1px solid #e2e8f0; color: #64748b; padding: .25rem .7rem; border-radius: 7px; font-size: .72rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.ud__edit-btn:hover { background: #f1f5f9; color: #0f172a; }

/* Back link */
.ud__back-link { display: flex; align-items: center; gap: .5rem; color: #64748b; font-size: .82rem; font-weight: 500; text-decoration: none; padding: .75rem .25rem; transition: color .15s; }
.ud__back-link:hover { color: #1b5e20; }

/* Buttons */
.ud__btn-primary { display: inline-flex; align-items: center; gap: .35rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.ud__btn-primary:hover:not(:disabled) { background: #144a18; }
.ud__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.ud__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .55rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 500; cursor: pointer; }
.ud__btn-ghost:hover { background: #f8fafc; }
.ud__btn-danger { display: inline-flex; align-items: center; gap: .35rem; background: #dc2626; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.ud__btn-danger:hover:not(:disabled) { background: #b91c1c; }
.ud__btn-danger:disabled { opacity: .55; cursor: not-allowed; }
.ud__btn-danger-outline { display: inline-flex; align-items: center; gap: .35rem; background: rgba(255,255,255,.8); color: #dc2626; border: 1.5px solid rgba(220,38,38,.3); padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; backdrop-filter: blur(4px); }
.ud__btn-danger-outline:hover { background: #fef2f2; border-color: #dc2626; }

/* Spinner */
.ud__spinner { width: 14px; height: 14px; border: 2px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: ud-spin .6s linear infinite; }
.ud__spinner--white { border-color: rgba(255,255,255,.3); border-top-color: #fff; }

/* Modal delete */
.ud__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(4px); }
.ud__modal-delete { background: #fff; border-radius: 18px; padding: 2.5rem 2rem; max-width: 420px; width: 100%; text-align: center; box-shadow: 0 24px 64px rgba(0,0,0,.18); }
.ud__delete-icon { width: 60px; height: 60px; border-radius: 50%; background: #fef2f2; color: #dc2626; font-size: 1.5rem; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.25rem; }
.ud__delete-title { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0 0 .75rem; letter-spacing: -.03em; }
.ud__delete-desc { font-size: .875rem; color: #64748b; line-height: 1.6; margin: 0 0 1.75rem; }
.ud__delete-actions { display: flex; gap: .75rem; justify-content: center; }
</style>
