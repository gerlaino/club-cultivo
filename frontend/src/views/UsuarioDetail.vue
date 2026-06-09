<script setup>
import { ref, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import { useAuthStore } from "../stores/auth"
import UsuarioSalasManager  from '../components/UsuarioSalasManager.vue'
import UsuarioSedesManager  from '../components/UsuarioSedesManager.vue'
import MedicoCalendarioWidget from '../components/medico/MedicoCalendarioWidget.vue'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const route  = useRoute()
const router = useRouter()
const store  = useUsuariosStore()
const auth   = useAuthStore()

const userId = Number(route.params.id)
const loading = ref(true)
const error   = ref(null)
const toast   = useToast()
const { confirm } = useConfirm()

const u = computed(() => store.current)

const isMe        = computed(() => auth.user?.id === userId)
const canEdit     = computed(() => ['admin', 'supervisor'].includes(auth.role) && !isMe.value)
const canEditRole = computed(() => auth.role === 'admin' && !isMe.value)

// Roles que tienen sedes asignables
const ROLES_CON_SEDES = ['cultivador', 'supervisor', 'medico', 'dispensador', 'delivery']
// Roles con módulo propio en la columna main

const ROLES = [
  { value: "admin",       label: "Administrador", color: "#dc2626", bg: "rgba(220,38,38,.1)",   icon: "bi-shield-fill-check",   desc: "Acceso total al sistema — puede gestionar todos los módulos, usuarios y configuración." },
  { value: "medico",      label: "Médico",        color: "#15803d", bg: "rgba(21,128,61,.1)",   icon: "bi-heart-pulse-fill",    desc: "Gestión de pacientes e indicaciones médicas. Sin acceso a producción." },
  { value: "cultivador",  label: "Cultivador",    color: "#0891b2", bg: "rgba(8,145,178,.1)",   icon: "bi-flower1",             desc: "Accede a las salas de vegetativo y floración de la sede que le asignes. Sin acceso a pacientes." },
  { value: "supervisor",  label: "Supervisor",    color: "#0f766e", bg: "rgba(15,118,110,.1)",  icon: "bi-binoculars-fill",     desc: "Supervisa las sedes que le asigne el admin. Puede crear y gestionar tareas en esas sedes." },
  { value: "manicura",    label: "Manicura",      color: "#7c3aed", bg: "rgba(124,58,237,.1)",  icon: "bi-scissors",            desc: "Ve todas las salas de cosecha y manicura del club. Registra peso de cosecha por lote. Requiere aprobación del admin." },
  { value: "dispensador", label: "Dispensador",   color: "#0891b2", bg: "rgba(8,145,178,.08)",  icon: "bi-bag-check-fill",      desc: "Opera el dispensario: registra entregas a socios y consulta stock disponible." },
  { value: "delivery",    label: "Delivery",      color: "#1A3D2E", bg: "rgba(26,61,46,.1)",    icon: "bi-bicycle",             desc: "Gestiona las entregas a domicilio de dispensaciones." },
  { value: "abogado",     label: "Abogado",       color: "#92400e", bg: "rgba(146,64,14,.1)",   icon: "bi-briefcase-fill",      desc: "Acceso a documentos, contabilidad y trazabilidad legal. Solo lectura clínica." },
  { value: "auditor",     label: "Auditor",       color: "#475569", bg: "rgba(71,85,105,.1)",   icon: "bi-clipboard-data-fill", desc: "Lectura de todos los módulos e informes. Sin modificar datos." },
  { value: "socio",       label: "Socio",         color: "#64748b", bg: "rgba(100,116,139,.1)", icon: "bi-person-badge-fill",   desc: "Acceso al portal del socio: su perfil y su historial de dispensaciones." },
]

const PERMISOS = {
  admin:       [{ ok: true, label: "Gestión total" }, { ok: true, label: "Usuarios y configuración" }, { ok: true, label: "Contabilidad" }, { ok: true, label: "Todos los módulos" }],
  medico:      [{ ok: true, label: "Gestionar pacientes" }, { ok: true, label: "Indicaciones médicas" }, { ok: true, label: "Dispensaciones" }, { ok: false, label: "Producción" }],
  cultivador:  [{ ok: true, label: "Salas de su sede" }, { ok: true, label: "Lotes y plantas" }, { ok: true, label: "Genéticas" }, { ok: false, label: "Pacientes" }],
  supervisor:  [{ ok: true, label: "Sedes asignadas" }, { ok: true, label: "Crear tareas" }, { ok: true, label: "Ver salas y lotes" }, { ok: false, label: "Usuarios / pacientes" }],
  manicura:    [{ ok: true, label: "Registrar cosecha" }, { ok: true, label: "Salas cosecha/manicura" }, { ok: false, label: "Aprobar stock" }, { ok: false, label: "Dispensar / socios" }],
  dispensador: [{ ok: true, label: "Registrar dispensaciones" }, { ok: true, label: "Consultar socios" }, { ok: true, label: "Ver stock" }, { ok: false, label: "Producción" }],
  delivery:    [{ ok: true, label: "Entregas a domicilio" }, { ok: true, label: "Consultar socios" }, { ok: false, label: "Crear dispensaciones" }, { ok: false, label: "Producción" }],
  abogado:     [{ ok: true, label: "Documentos legales" }, { ok: true, label: "Contabilidad (lectura)" }, { ok: true, label: "Trazabilidad" }, { ok: false, label: "Modificar datos clínicos" }],
  auditor:     [{ ok: true, label: "Lectura completa" }, { ok: true, label: "Contabilidad" }, { ok: false, label: "Crear / modificar" }, { ok: false, label: "Gestionar usuarios" }],
  socio:       [{ ok: true, label: "Ver su perfil" }, { ok: true, label: "Sus dispensaciones" }, { ok: false, label: "Producción" }, { ok: false, label: "Otros módulos" }],
}

const SEDE_HINTS = {
  cultivador:  'Accede a salas de vege/floración de estas sedes',
  supervisor:  'Solo puede crear tareas en estas sedes',
  medico:      'Solo ve pacientes de estas sedes — sin asignar: todo el club',
  dispensador: 'Solo puede dispensar en estas sedes — sin asignar: todas',
  delivery:    'Solo gestiona entregas de estas sedes — sin asignar: todas',
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

// ── Editar info personal ────────────────────────────────────────────────
const editingInfo = ref(false)
const savingInfo  = ref(false)
const infoForm    = ref({ first_name: '', last_name: '', email: '' })

function startEditInfo() {
  infoForm.value = { first_name: u.value?.first_name || '', last_name: u.value?.last_name || '', email: u.value?.email || '' }
  editingInfo.value = true
}

async function saveInfo() {
  savingInfo.value = true
  try {
    await store.update(userId, infoForm.value)
    editingInfo.value = false
    toast.success('Información actualizada.')
  } catch { toast.error(store.error || 'No se pudo actualizar.') }
  finally { savingInfo.value = false }
}

// ── Editar rol ──────────────────────────────────────────────────────────
const editingRole = ref(false)
const newRole     = ref('')
function startEditRole() { newRole.value = u.value?.role || ''; editingRole.value = true }
async function saveRole() {
  try {
    await store.update(userId, { role: newRole.value })
    editingRole.value = false
    toast.success('Rol actualizado.')
  } catch { toast.error(store.error || 'No se pudo actualizar el rol.') }
}

async function doDelete() {
  const ok = await confirm({
    title: `¿Eliminar a ${u.value?.first_name || ''} ${u.value?.last_name || ''}?`,
    message: 'Esta acción no se puede deshacer.',
    confirmText: 'Eliminar',
  })
  if (!ok) return
  try {
    await store.remove(userId)
    router.push({ name: 'usuarios' })
  } catch { toast.error(store.error || 'No se pudo eliminar el usuario.') }
}

onMounted(async () => {
  try { await store.fetchOne(userId) }
  catch { error.value = 'No se pudo cargar el usuario.' }
  finally { loading.value = false }
})
</script>

<template>
  <div class="ud">

    <Breadcrumb :items="[{ label: 'Equipo', to: { name: 'usuarios' } }, { label: u ? `${u.first_name} ${u.last_name}` : `Usuario #${userId}` }]" />

    <div v-if="loading" class="ud__loading"><DsSpinner /></div>
    <div v-else-if="error" class="ud__error">{{ error }}</div>
    <div v-else-if="!u" class="ud__error">Usuario no encontrado.</div>

    <template v-else>

      <!-- ── Hero ── -->
      <div class="ud__hero" :style="{ background: `linear-gradient(135deg, ${roleInfo(u.role).color}14 0%, #f8fafc 60%)` }">

        <!-- Fila principal -->
        <div class="ud__hero-content">

          <!-- Avatar -->
          <div class="ud__av-wrap">
            <div class="ud__av" :style="{ background: getAvatarColor(u) }">{{ getInitials(u) }}</div>
            <div class="ud__av-badge" :style="{ background: roleInfo(u.role).color }">
              <i :class="['bi', roleInfo(u.role).icon]"></i>
            </div>
          </div>

          <!-- Identidad -->
          <div class="ud__identity">
            <div class="ud__name">
              {{ u.first_name }} {{ u.last_name }}
              <span v-if="isMe" class="ud__me-badge">Vos</span>
            </div>
            <div class="ud__email">{{ u.email }}</div>
            <div class="ud__role-chip" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
              <i :class="['bi', roleInfo(u.role).icon]"></i>
              {{ roleInfo(u.role).label }}
            </div>
          </div>

          <!-- Acciones -->
          <div class="ud__hero-actions">
            <button v-if="canEdit && !editingInfo" class="ud__btn-edit-hero" @click="startEditInfo">
              <i class="bi bi-pencil"></i> Editar datos
            </button>
            <button v-if="canEdit" class="ud__btn-danger-outline" @click="doDelete">
              <i class="bi bi-trash"></i>
            </button>
          </div>

        </div>

        <!-- Formulario inline (visible al editar) -->
        <div v-if="editingInfo" class="ud__hero-form">
          <div class="ud__hero-form-row">
            <div class="ud__field">
              <label class="ud__field-label">Nombre</label>
              <input v-model="infoForm.first_name" class="ud__input" placeholder="Nombre" />
            </div>
            <div class="ud__field">
              <label class="ud__field-label">Apellido</label>
              <input v-model="infoForm.last_name" class="ud__input" placeholder="Apellido" />
            </div>
            <div class="ud__field ud__field--email">
              <label class="ud__field-label">Email</label>
              <input v-model="infoForm.email" class="ud__input" type="email" placeholder="correo@ejemplo.com" />
            </div>
          </div>
          <div class="ud__hero-form-actions">
            <button class="ud__btn-ghost" @click="editingInfo = false">Cancelar</button>
            <button class="ud__btn-primary" :disabled="savingInfo" @click="saveInfo">
              <DsSpinner v-if="savingInfo" :size="14" />
              <i v-else class="bi bi-check-lg"></i> Guardar
            </button>
          </div>
        </div>

        <!-- Strip (oculto mientras se edita) -->
        <div v-if="!editingInfo" class="ud__hero-strip">
          <div class="ud__strip-item">
            <i class="bi bi-calendar3"></i>
            <span>Miembro desde {{ formatDate(u.created_at) }}</span>
          </div>
          <div class="ud__strip-item">
            <i class="bi bi-hash"></i>
            <span>ID #{{ u.id }}</span>
          </div>
          <div v-if="u.role === 'medico'" class="ud__strip-item ud__strip-item--role">
            <i class="bi bi-calendar-week"></i>
            <span>Agenda semanal ↓</span>
          </div>
          <div v-else-if="u.role === 'cultivador'" class="ud__strip-item ud__strip-item--role">
            <i class="bi bi-layers"></i>
            <span>Salas asignadas ↓</span>
          </div>
        </div>

      </div>

      <!-- ── Body ── -->
      <div class="ud__body">

        <!-- ── Columna main ── -->
        <div class="ud__main">

          <!-- Módulo: Médico → Agenda semanal -->
          <div v-if="u.role === 'medico'" class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(21,128,61,.1);color:#15803d">
                <i class="bi bi-calendar-week"></i>
              </div>
              <span class="ud__card-title">Agenda semanal</span>
              <span class="ud__card-hint">Solo lectura</span>
            </div>
            <MedicoCalendarioWidget :medico-id="userId" />
          </div>

          <!-- Cultivador → Salas asignadas -->
          <div v-if="u.role === 'cultivador'" class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(8,145,178,.1);color:#0891b2">
                <i class="bi bi-layers"></i>
              </div>
              <span class="ud__card-title">Salas asignadas</span>
            </div>
            <div class="ud__card-body">
              <UsuarioSalasManager :user-id="userId" />
            </div>
          </div>

          <!-- Cultivador → Sedes (en main, no de costado) -->
          <div v-if="u.role === 'cultivador'" class="ud__card ud__card--mt">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(8,145,178,.1);color:#0891b2">
                <i class="bi bi-building"></i>
              </div>
              <span class="ud__card-title">Sedes asignadas</span>
            </div>
            <div class="ud__card-body">
              <UsuarioSedesManager :user-id="userId" />
              <p class="ud__sede-note">
                <i class="bi bi-info-circle"></i>
                Sin sedes asignadas = accede a todo el club
              </p>
            </div>
          </div>

        </div>

        <!-- ── Aside ── -->
        <div class="ud__aside">

          <!-- Rol -->
          <div class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
                <i class="bi bi-shield-check"></i>
              </div>
              <span class="ud__card-title">Rol</span>
              <button v-if="canEditRole && !editingRole" class="ud__edit-btn" @click="startEditRole">
                <i class="bi bi-pencil"></i>
              </button>
            </div>
            <div class="ud__card-body">
              <div v-if="!editingRole" class="ud__role-display">
                <div class="ud__role-pill" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
                  <i :class="['bi', roleInfo(u.role).icon]"></i>
                  {{ roleInfo(u.role).label }}
                </div>
                <p class="ud__role-desc">{{ roleInfo(u.role).desc }}</p>
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
                    <i :class="['bi', r.icon]"></i> {{ r.label }}
                  </button>
                </div>
                <div v-if="newRole === 'supervisor'" class="ud__role-warn">
                  <i class="bi bi-exclamation-triangle-fill"></i>
                  El supervisor requiere al menos una sede asignada.
                </div>
                <div class="ud__role-edit-actions">
                  <button class="ud__btn-ghost" @click="editingRole = false">Cancelar</button>
                  <button class="ud__btn-primary" :disabled="store.saving" @click="saveRole">
                    <DsSpinner v-if="store.saving" :size="14" />
                    <i v-else class="bi bi-check-lg"></i> Guardar
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Permisos -->
          <div class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
                <i :class="['bi', roleInfo(u.role).icon]"></i>
              </div>
              <span class="ud__card-title">Permisos</span>
            </div>
            <div class="ud__card-body">
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

          <!-- Sedes asignadas (aside — todos excepto cultivador, que las ve en main) -->
          <div v-if="ROLES_CON_SEDES.includes(u.role) && u.role !== 'cultivador'" class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" :style="{ background: roleInfo(u.role).bg, color: roleInfo(u.role).color }">
                <i class="bi bi-building"></i>
              </div>
              <span class="ud__card-title">Sedes</span>
            </div>
            <div class="ud__card-body">
              <UsuarioSedesManager :user-id="userId" />
              <p v-if="u.role === 'supervisor'" class="ud__sede-note ud__sede-note--warn">
                <i class="bi bi-exclamation-triangle-fill"></i>
                Requiere al menos una sede asignada para operar.
              </p>
              <p v-else class="ud__sede-note">
                <i class="bi bi-info-circle"></i>
                Sin sedes = acceso a todo el club
              </p>
            </div>
          </div>

          <!-- Datos de cuenta -->
          <div class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(71,85,105,.08);color:#475569">
                <i class="bi bi-info-circle"></i>
              </div>
              <span class="ud__card-title">Cuenta</span>
            </div>
            <dl class="ud__dl">
              <dt>ID de usuario</dt><dd>#{{ u.id }}</dd>
              <dt>Creado</dt><dd>{{ formatDate(u.created_at) }}</dd>
              <dt>Actualizado</dt><dd>{{ formatDate(u.updated_at) }}</dd>
            </dl>
          </div>

          <RouterLink :to="{ name: 'usuarios' }" class="ud__back-link">
            <i class="bi bi-arrow-left"></i> Volver al equipo
          </RouterLink>

        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.ud { padding: 1.5rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .ud { padding: 1rem 1rem 2rem; } }

/* Loading / Error */
.ud__loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.ud__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; margin-top: 1rem; }

/* ── Hero ── */
.ud__hero {
  border-radius: 18px;
  border: 1px solid #e2e8f0;
  overflow: hidden;
  margin-bottom: 1.75rem;
}
.ud__hero-content {
  display: flex; align-items: center; gap: 1.5rem;
  padding: 1.75rem 2rem 1.25rem;
  flex-wrap: wrap;
}

/* Hero form (datos personales inline) */
.ud__hero-form {
  padding: 1.25rem 2rem 1.5rem;
  border-top: 1px solid rgba(0,0,0,.06);
  background: rgba(255,255,255,.55);
  backdrop-filter: blur(4px);
}
.ud__hero-form-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1.5fr;
  gap: .75rem;
  margin-bottom: .875rem;
}
@media (max-width: 700px) { .ud__hero-form-row { grid-template-columns: 1fr; } }
.ud__field--email { grid-column: auto; }
.ud__hero-form-actions { display: flex; justify-content: flex-end; gap: .5rem; }

/* Edit hero button */
.ud__btn-edit-hero {
  display: inline-flex; align-items: center; gap: .4rem;
  background: rgba(255,255,255,.75); color: #374151;
  border: 1.5px solid rgba(0,0,0,.12);
  padding: .45rem .875rem; border-radius: 9px; font-size: .8rem; font-weight: 600; cursor: pointer;
  transition: all .15s; backdrop-filter: blur(4px);
}
.ud__btn-edit-hero:hover { background: #fff; border-color: #94a3b8; }

/* Avatar */
.ud__av-wrap { position: relative; flex-shrink: 0; }
.ud__av {
  width: 80px; height: 80px; border-radius: 20px;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-size: 1.6rem; font-weight: 800; letter-spacing: -.03em;
  border: 3px solid rgba(255,255,255,.5);
  box-shadow: 0 4px 16px rgba(0,0,0,.12);
}
.ud__av-badge {
  position: absolute; bottom: -5px; right: -5px;
  width: 28px; height: 28px; border-radius: 9px;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-size: .68rem;
  border: 2.5px solid #fff;
  box-shadow: 0 2px 6px rgba(0,0,0,.15);
}

/* Identity */
.ud__identity { flex: 1; min-width: 0; }
.ud__name {
  font-size: 1.6rem; font-weight: 800; color: #0f172a;
  letter-spacing: -.04em; line-height: 1.15;
  margin-bottom: .3rem;
  display: flex; align-items: center; gap: .65rem;
}
.ud__me-badge {
  font-size: .6rem; font-weight: 700; background: #f1f5f9; color: #64748b;
  padding: .2em .65em; border-radius: 5px; letter-spacing: .05em; text-transform: uppercase;
}
.ud__email { font-size: .875rem; color: #64748b; margin-bottom: .55rem; }
.ud__role-chip {
  display: inline-flex; align-items: center; gap: .4rem;
  font-size: .78rem; font-weight: 700;
  padding: .35em .875em; border-radius: 9px;
}

/* Hero actions */
.ud__hero-actions { display: flex; gap: .6rem; margin-left: auto; align-self: flex-start; }

/* Hero strip */
.ud__hero-strip {
  display: flex; gap: 1.5rem; flex-wrap: wrap;
  padding: .75rem 2rem;
  border-top: 1px solid rgba(0,0,0,.05);
  background: rgba(255,255,255,.6);
}
.ud__strip-item {
  display: flex; align-items: center; gap: .4rem;
  font-size: .75rem; color: #64748b; font-weight: 500;
}
.ud__strip-item i { font-size: .8rem; }
.ud__strip-item--role { color: #15803d; font-weight: 600; }

/* ── Body layout ── */
.ud__body { display: grid; grid-template-columns: 1fr 280px; gap: 1.5rem; align-items: start; }
@media (max-width: 960px) { .ud__body { grid-template-columns: 1fr; } }
.ud__main { display: flex; flex-direction: column; }
.ud__aside { display: flex; flex-direction: column; gap: 0; position: sticky; top: 1.5rem; }

/* ── Cards ── */
.ud__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.ud__card--mt { margin-top: 1.25rem; }
.ud__aside .ud__card + .ud__card { margin-top: 1rem; }
.ud__card-hdr {
  display: flex; align-items: center; gap: .65rem;
  padding: .875rem 1.25rem;
  border-bottom: 1px solid #f1f5f9;
  background: #fafbfc;
}
.ud__card-ico {
  width: 30px; height: 30px; border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: .8rem; flex-shrink: 0;
}
.ud__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; flex: 1; }
.ud__card-hint { font-size: .7rem; color: #94a3b8; font-weight: 500; }
.ud__card-body { padding: 1.25rem; }

.ud__field { display: flex; flex-direction: column; gap: .35rem; }
.ud__field-label { font-size: .7rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: .04em; }
.ud__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .6rem .875rem; font-size: .875rem; color: #0f172a;
  outline: none; transition: border .15s, background .15s; width: 100%; box-sizing: border-box;
}
.ud__input:focus { border-color: #1b5e20; background: #fff; }
.ud__edit-actions { display: flex; justify-content: flex-end; gap: .5rem; padding-top: .25rem; border-top: 1px solid #f1f5f9; margin-top: .25rem; }

/* Edit button */
.ud__edit-btn {
  display: inline-flex; align-items: center; gap: .3rem;
  background: none; border: 1px solid #e2e8f0; color: #64748b;
  padding: .25rem .7rem; border-radius: 7px; font-size: .72rem; font-weight: 600; cursor: pointer; transition: all .15s;
}
.ud__edit-btn:hover { background: #f1f5f9; color: #0f172a; }

/* Rol aside */
.ud__role-display { display: flex; flex-direction: column; gap: .65rem; }
.ud__role-pill {
  display: inline-flex; align-items: center; gap: .45rem;
  font-size: .85rem; font-weight: 700; padding: .45em 1em; border-radius: 9px;
  align-self: flex-start;
}
.ud__role-desc { font-size: .78rem; color: #64748b; line-height: 1.55; margin: 0; }

/* Rol edit */
.ud__role-options { display: flex; flex-direction: column; gap: .35rem; margin-bottom: .875rem; }
.ud__role-option {
  display: flex; align-items: center; gap: .45rem;
  padding: .5rem .75rem; border-radius: 9px;
  border: 1.5px solid #e2e8f0; background: #f8fafc;
  font-size: .8rem; font-weight: 500; cursor: pointer; color: #475569;
  transition: all .15s; text-align: left;
}
.ud__role-option:hover { border-color: #cbd5e1; }
.ud__role-option--active { font-weight: 700; }
.ud__role-edit-actions { display: flex; gap: .5rem; justify-content: flex-end; }
.ud__role-warn {
  display: flex; align-items: flex-start; gap: .5rem;
  background: #fffbeb; border: 1px solid #fde68a; border-radius: 8px;
  padding: .55rem .75rem; font-size: .75rem; color: #92400e; margin-bottom: .75rem; line-height: 1.5;
}
.ud__role-warn i { color: #d97706; flex-shrink: 0; margin-top: 1px; }

/* Permisos */
.ud__permisos { display: flex; flex-direction: column; gap: .5rem; }
.ud__permiso { display: flex; align-items: center; gap: .5rem; font-size: .82rem; font-weight: 500; }
.ud__permiso--ok { color: #15803d; }
.ud__permiso--no { color: #94a3b8; }
.ud__permiso--ok i { color: #15803d; font-size: .85rem; }
.ud__permiso--no i { color: #cbd5e1; font-size: .85rem; }

/* Sedes note */
.ud__sede-note {
  font-size: .73rem; color: #64748b; margin: .75rem 0 0;
  padding: .45rem .7rem; background: #f8fafc;
  border-radius: 7px; border-left: 3px solid #cbd5e1;
  display: flex; align-items: flex-start; gap: .4rem; line-height: 1.5;
}
.ud__sede-note--warn { background: #fffbeb; color: #92400e; border-left-color: #d97706; }
.ud__sede-note i { flex-shrink: 0; font-size: .8rem; margin-top: .1rem; }

/* DL */
.ud__dl { display: grid; grid-template-columns: auto 1fr; gap: .5rem .75rem; padding: .875rem 1.25rem; margin: 0; }
.ud__dl dt { font-size: .72rem; color: #94a3b8; font-weight: 500; }
.ud__dl dd { font-size: .82rem; color: #0f172a; font-weight: 600; margin: 0; }

/* Back link */
.ud__back-link {
  display: flex; align-items: center; gap: .5rem;
  color: #64748b; font-size: .82rem; font-weight: 500;
  text-decoration: none; padding: .875rem .25rem;
  transition: color .15s; margin-top: .75rem;
}
.ud__back-link:hover { color: #1b5e20; }

/* Buttons */
.ud__btn-primary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .55rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.ud__btn-primary:hover:not(:disabled) { background: #144a18; }
.ud__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.ud__btn-ghost {
  background: #fff; color: #64748b; border: 1.5px solid #e2e8f0;
  padding: .55rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 500; cursor: pointer;
}
.ud__btn-ghost:hover { background: #f8fafc; }
.ud__btn-danger-outline {
  display: inline-flex; align-items: center; gap: .35rem;
  background: rgba(255,255,255,.8); color: #dc2626;
  border: 1.5px solid rgba(220,38,38,.3);
  padding: .5rem .875rem; border-radius: 9px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; backdrop-filter: blur(4px);
}
.ud__btn-danger-outline:hover { background: #fef2f2; border-color: #dc2626; }
</style>
