<script setup>
import { ref, computed, onMounted, watch } from "vue"
import { useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import { useAuthStore } from "../stores/auth"
import { listSalas, listSedes, asignarSedeAUsuario } from '../lib/api.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const store           = useUsuariosStore()
const auth            = useAuthStore()
const toast           = useToast()
const { confirm }     = useConfirm()

// ── Lista ─────────────────────────────────────────────────────────────────
const q           = ref("")
const currentPage = ref(1)
const PER_PAGE    = 20

watch(q, () => { currentPage.value = 1 })

const filteredUsers = computed(() => {
  const base = store.items.filter(u => u.id !== auth.user?.id)
  if (!q.value.trim()) return base
  const s = q.value.toLowerCase()
  return base.filter(u =>
    u.first_name?.toLowerCase().includes(s) ||
    u.last_name?.toLowerCase().includes(s)  ||
    u.email?.toLowerCase().includes(s)
  )
})
const totalPages = computed(() => Math.max(1, Math.ceil(filteredUsers.value.length / PER_PAGE)))
const pagedUsers = computed(() => {
  const start = (currentPage.value - 1) * PER_PAGE
  return filteredUsers.value.slice(start, start + PER_PAGE)
})

onMounted(() => store.fetch())

// ── Roles ─────────────────────────────────────────────────────────────────
const ROLES = [
  { value: 'admin',       label: 'Administrador', icon: 'bi-shield-fill-check',   desc: 'Acceso total al club, usuarios y configuración.' },
  { value: 'medico',      label: 'Médico',        icon: 'bi-heart-pulse-fill',    desc: 'Gestión de pacientes e indicaciones médicas.' },
  { value: 'cultivador',  label: 'Cultivador',    icon: 'bi-flower1',             desc: 'Ve todas las salas de vege/floración de la sede asignada. Sin acceso a pacientes.' },
  { value: 'supervisor',  label: 'Supervisor',    icon: 'bi-binoculars-fill',     desc: 'Supervisa las sedes asignadas y gestiona tareas.' },
  { value: 'manicura',    label: 'Manicura',      icon: 'bi-scissors',            desc: 'Ve todas las salas de cosecha y manicura del club. Registra pesadas. Requiere aprobación del admin.' },
  { value: 'dispensador', label: 'Dispensador',   icon: 'bi-bag-check-fill',      desc: 'Opera el dispensario y registra entregas a socios.' },
  { value: 'delivery',    label: 'Delivery',      icon: 'bi-bicycle',             desc: 'Gestiona las entregas a domicilio.' },
  { value: 'abogado',     label: 'Abogado',       icon: 'bi-briefcase-fill',      desc: 'Documentos, contabilidad y trazabilidad legal.' },
  { value: 'auditor',     label: 'Auditor',       icon: 'bi-clipboard-data-fill', desc: 'Lectura completa de todos los módulos.' },
]

const ROLES_CONFIG = {
  admin:       { sedes: false, salas: false },
  medico:      { sedes: true,  salas: false, sedeRequerida: false, sedeHint: 'Sin asignar: accede a pacientes de todo el club.' },
  cultivador:  { sedes: true,  salas: false, sedeRequerida: true,  sedeHint: 'El cultivador necesita una sede asignada para ver salas y lotes.' },
  supervisor:  { sedes: true,  salas: false, sedeRequerida: true },
  manicura:    { sedes: false, salas: false },
  dispensador: { sedes: true,  salas: false, sedeRequerida: false, sedeHint: 'Sin asignar: puede dispensar en todas las sedes.' },
  delivery:    { sedes: true,  salas: false, sedeRequerida: false, sedeHint: 'Sin asignar: gestiona entregas de todas las sedes.' },
  abogado:     { sedes: false, salas: false },
  auditor:     { sedes: true,  salas: false, sedeRequerida: false, sedeHint: 'Sin asignar: accede a informes y datos de todo el club.' },
}

function getRoleInfo(role) {
  return ROLES.find(r => r.value === role) || { label: role, icon: 'bi-person', desc: '' }
}

const AVATAR_COLORS = ['#1A3D2E','#1A1F36','#172B1F','#C2410C','#1A2F1E','#2A2F38','#1F1810']
function getInitials(user) {
  const f = user.first_name?.[0] || ''
  const l = user.last_name?.[0]  || ''
  return (f + l).toUpperCase() || user.email?.[0]?.toUpperCase() || '?'
}
function getAvatarColor(user) { return AVATAR_COLORS[(user.id || 0) % AVATAR_COLORS.length] }

function roleVar(role)    { return `--c-role-${role}` }
function roleColor(role)  { return `var(${roleVar(role)}, #475569)` }
function roleBg(role)     { return `color-mix(in srgb, var(${roleVar(role)}, #475569) 12%, white)` }
function roleBorder(role) { return `color-mix(in srgb, var(${roleVar(role)}, #475569) 30%, white)` }
function roleStyle(role)  { return { color: roleColor(role), background: roleBg(role), borderColor: roleBorder(role) } }

// ── Modal ─────────────────────────────────────────────────────────────────
const showModal  = ref(false)
const editing    = ref(false)
const originalRole = ref(null)
const wizardStep = ref(1)

const todasLasSalas       = ref([])
const todasLasSedes       = ref([])
const sedesSeleccionadas  = ref([])

const form = ref({ id: null, first_name: "", last_name: "", email: "", role: "admin", sede_id: "", sala_id: "" })

const roleConfig = computed(() => ROLES_CONFIG[form.value.role] || { sedes: false, salas: false })

const salasDeLaSede = computed(() =>
  todasLasSalas.value.filter(s => {
    if (s.sede?.id !== form.value.sede_id) return false
    return form.value.role === 'manicura' ? s.kind === 'manicura' : s.kind !== 'manicura'
  })
)

const formValidStep2 = computed(() => {
  const base = form.value.first_name.trim() && form.value.last_name.trim() && form.value.email.trim()
  if (!base) return false
  if (roleConfig.value.sedeRequerida && sedesSeleccionadas.value.length === 0) return false
  return true
})

watch(showModal, async (val) => {
  if (val && !editing.value) {
    try {
      const [resSalas, resSedes] = await Promise.all([listSalas(), listSedes()])
      todasLasSalas.value = resSalas.data || []
      todasLasSedes.value = resSedes.data || []
    } catch {}
  }
})

function startCreate() {
  editing.value            = false
  wizardStep.value         = 1
  sedesSeleccionadas.value = []
  form.value               = { id: null, first_name: "", last_name: "", email: "", role: "admin", sede_id: "", sala_id: "" }
  showModal.value          = true
}

const router = useRouter()
function irADetalle(u) { router.push({ name: 'usuario-detail', params: { id: u.id } }) }

function startEdit(u) {
  editing.value     = true
  originalRole.value = u.role
  form.value      = { id: u.id, first_name: u.first_name || "", last_name: u.last_name || "", email: u.email || "", role: u.role || "admin", sede_id: "", sala_id: "" }
  showModal.value = true
}

function closeModal() {
  showModal.value  = false
  wizardStep.value = 1
  sedesSeleccionadas.value = []
}

function nextStep() {
  if (wizardStep.value === 1) wizardStep.value = 2
}

function prevStep() {
  if (wizardStep.value === 2) { wizardStep.value = 1; sedesSeleccionadas.value = [] }
}

async function save() {
  if (editing.value) {
    if (!form.value.first_name.trim() || !form.value.last_name.trim() || !form.value.email.trim()) return

    // Aviso si cambia el rol: los permisos cambian de inmediato; el historial se conserva.
    if (form.value.role !== originalRole.value) {
      const ok = await confirm({
        title: 'Cambiar rol del usuario',
        message: `Vas a cambiar el rol de ${form.value.first_name} de "${getRoleInfo(originalRole.value).label}" a "${getRoleInfo(form.value.role).label}".\n\nSus permisos cambian de inmediato, pero su historial (lo que hizo) se conserva tal cual. Revisá sus asignaciones (sedes, salas, despachos) por si quedan sin sentido con el rol nuevo.`,
        confirmText: 'Cambiar rol',
      })
      if (!ok) return
    }

    try {
      await store.update(form.value.id, {
        first_name: form.value.first_name,
        last_name:  form.value.last_name,
        email:      form.value.email,
        role:       form.value.role,
      })
      closeModal()
      toast.success('Usuario actualizado correctamente.')
    } catch (e) {
      toast.error(store.error || 'Error al actualizar.')
    }
    return
  }

  if (!formValidStep2.value) return
  try {
    const nuevo = await store.create({
      first_name:            form.value.first_name,
      last_name:             form.value.last_name,
      email:                 form.value.email,
      role:                  form.value.role,
      password:              '123456Aa',
      password_confirmation: '123456Aa',
    })

    // Asignar sedes seleccionadas
    if (nuevo?.id && sedesSeleccionadas.value.length > 0) {
      await Promise.all(sedesSeleccionadas.value.map(sedeId => asignarSedeAUsuario(nuevo.id, sedeId)))
    }

    // Asignar sala inicial (cultivador/manicura)
    // (sala assignment queda para el perfil — no hay endpoint create-with-sala)

    closeModal()
    const n = sedesSeleccionadas.value.length
    const sedeMsg = n > 0 ? ` con ${n} sede${n !== 1 ? 's' : ''} asignada${n !== 1 ? 's' : ''}` : ''
    toast.success(`Usuario creado${sedeMsg}. Contraseña inicial: 123456Aa`)
  } catch (e) {
    if (e.response?.status === 402) {
      toast.error(e.response.data?.mensaje || 'Límite del plan alcanzado. Contactá al equipo.')
    } else {
      toast.error(store.error || 'Error al crear usuario.')
    }
  }
}

async function removeOne(u) {
  const ok = await confirm({ title: `¿Eliminar a ${u.first_name || ''} ${u.last_name || ''}?`, message: 'Esta acción no se puede deshacer.', confirmText: 'Eliminar' })
  if (!ok) return
  try {
    await store.remove(u.id)
    toast.success('Usuario eliminado.')
  } catch {
    toast.error(store.error || 'No se pudo eliminar.')
  }
}
</script>

<template>
  <div class="uv">

    <!-- Header -->
    <div class="uv__header">
      <div class="uv__header-left">
        <h1 class="uv__title">Equipo</h1>
        <p class="uv__sub">{{ store.items.length }} miembro{{ store.items.length !== 1 ? 's' : '' }} del club</p>
      </div>
      <div class="uv__header-right">
        <div class="uv__search">
          <i class="bi bi-search uv__search-icon"></i>
          <input v-model="q" class="uv__search-input" placeholder="Buscar por nombre o email…" />
          <span v-if="q" class="uv__search-clear" @click="q = ''"><i class="bi bi-x"></i></span>
        </div>
        <button class="uv__btn-primary" @click="startCreate">
          <i class="bi bi-plus-lg"></i> Nuevo usuario
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="store.loading" class="uv__loading">
      <DsSpinner />
    </div>

    <!-- Empty -->
    <div v-else-if="filteredUsers.length === 0" class="uv__empty">
      <div class="uv__empty-icon"><i class="bi bi-people"></i></div>
      <h3 class="uv__empty-title">{{ q ? 'Sin resultados' : 'Sin usuarios todavía' }}</h3>
      <p class="uv__empty-desc">{{ q ? 'Probá con otro término de búsqueda.' : 'Agregá el primer miembro del equipo.' }}</p>
      <button v-if="!q" class="uv__btn-primary" @click="startCreate">
        <i class="bi bi-plus-lg"></i> Crear primer usuario
      </button>
    </div>

    <!-- Tabla -->
    <div v-else class="uv__table-wrap">
      <table class="uv__table">
        <thead>
          <tr>
            <th>Usuario</th>
            <th>Rol</th>
            <th class="uv__col-fecha">Miembro desde</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="u in pagedUsers" :key="u.id" class="uv__table-row uv__table-row--link" @click="irADetalle(u)">
            <td>
              <div class="uv__user-cell">
                <div class="uv__avatar" :style="{ background: getAvatarColor(u) }">{{ getInitials(u) }}</div>
                <div>
                  <div class="uv__cell-name">{{ u.first_name }} {{ u.last_name }}</div>
                  <div class="uv__cell-email">{{ u.email }}</div>
                </div>
              </div>
            </td>
            <td>
              <span class="uv__role-badge" :style="roleStyle(u.role)">
                <i :class="['bi', getRoleInfo(u.role).icon]"></i>
                {{ getRoleInfo(u.role).label }}
              </span>
            </td>
            <td class="uv__col-fecha">
              <span class="uv__fecha">{{ u.created_at ? new Date(u.created_at).toLocaleDateString('es-AR', { day:'numeric', month:'short', year:'numeric' }) : '—' }}</span>
            </td>
            <td>
              <div class="uv__row-actions">
                <button class="uv__row-btn" @click.stop="startEdit(u)" title="Editar datos">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="uv__row-btn uv__row-btn--danger" @click.stop="removeOne(u)" title="Eliminar">
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <div v-if="totalPages > 1" class="uv__pagination">
        <span class="uv__page-info">
          {{ filteredUsers.length }} usuario{{ filteredUsers.length !== 1 ? 's' : '' }} ·
          página {{ currentPage }} de {{ totalPages }}
        </span>
        <div class="uv__page-nav">
          <button class="uv__page-btn" :disabled="currentPage === 1" @click="currentPage--">
            <i class="bi bi-chevron-left"></i>
          </button>
          <button v-for="p in totalPages" :key="p" class="uv__page-btn" :class="{ 'uv__page-btn--active': p === currentPage }" @click="currentPage = p">{{ p }}</button>
          <button class="uv__page-btn" :disabled="currentPage === totalPages" @click="currentPage++">
            <i class="bi bi-chevron-right"></i>
          </button>
        </div>
      </div>
      <div v-else class="uv__page-footer">
        {{ filteredUsers.length }} usuario{{ filteredUsers.length !== 1 ? 's' : '' }}
      </div>
    </div>

    <!-- ── MODAL ── -->
    <Teleport to="body">
      <div v-if="showModal" class="uv__overlay" @click.self="closeModal">
        <div class="uv__modal">

          <!-- Header -->
          <div class="uv__modal-header">
            <div class="uv__modal-header-left">
              <h3 class="uv__modal-title">
                {{ editing ? 'Editar usuario' : (wizardStep === 1 ? 'Nuevo usuario' : `Nuevo ${getRoleInfo(form.role).label}`) }}
              </h3>
              <!-- Step indicator (solo en creación) -->
              <div v-if="!editing" class="uv__steps">
                <div class="uv__step" :class="{ 'uv__step--active': wizardStep >= 1, 'uv__step--done': wizardStep > 1 }">
                  <span class="uv__step-dot">{{ wizardStep > 1 ? '✓' : '1' }}</span>
                  <span class="uv__step-lbl">Rol</span>
                </div>
                <div class="uv__step-line" :class="{ 'uv__step-line--done': wizardStep > 1 }"></div>
                <div class="uv__step" :class="{ 'uv__step--active': wizardStep >= 2 }">
                  <span class="uv__step-dot">2</span>
                  <span class="uv__step-lbl">Datos</span>
                </div>
              </div>
            </div>
            <button class="uv__modal-close" @click="closeModal"><i class="bi bi-x-lg"></i></button>
          </div>

          <!-- ── PASO 1: Selector de rol ── -->
          <div v-if="!editing && wizardStep === 1" class="uv__modal-body">
            <p class="uv__step-intro">¿Qué tipo de usuario vas a crear?</p>
            <div class="uv__role-grid">
              <button
                v-for="r in ROLES"
                :key="r.value"
                type="button"
                class="uv__role-card"
                :class="{ 'uv__role-card--active': form.role === r.value }"
                :style="form.role === r.value ? { borderColor: roleColor(r.value), background: roleBg(r.value) } : {}"
                @click="form.role = r.value"
              >
                <i :class="['bi', r.icon, 'uv__role-card-ico']" :style="form.role === r.value ? { color: roleColor(r.value) } : {}"></i>
                <span class="uv__role-card-name" :style="form.role === r.value ? { color: roleColor(r.value) } : {}">{{ r.label }}</span>
                <span class="uv__role-card-desc">{{ r.desc }}</span>
              </button>
            </div>
          </div>

          <!-- ── PASO 2: Formulario por rol ── -->
          <div v-else-if="!editing && wizardStep === 2" class="uv__modal-body">

            <!-- Preview del rol seleccionado -->
            <div class="uv__rol-preview" :style="{ borderColor: roleColor(form.role), background: roleBg(form.role) }">
              <i :class="['bi', getRoleInfo(form.role).icon]" :style="{ color: roleColor(form.role) }"></i>
              <span :style="{ color: roleColor(form.role), fontWeight: 700 }">{{ getRoleInfo(form.role).label }}</span>
              <span class="uv__rol-preview-desc">{{ getRoleInfo(form.role).desc }}</span>
            </div>

            <div class="uv__form-grid">

              <!-- Nombre / Apellido -->
              <div class="uv__field">
                <label class="uv__label">Nombre <span class="uv__req">*</span></label>
                <input class="uv__input" v-model.trim="form.first_name" placeholder="Juan" />
              </div>
              <div class="uv__field">
                <label class="uv__label">Apellido <span class="uv__req">*</span></label>
                <input class="uv__input" v-model.trim="form.last_name" placeholder="Pérez" />
              </div>

              <!-- Email -->
              <div class="uv__field uv__field--full">
                <label class="uv__label">Email <span class="uv__req">*</span></label>
                <input type="email" class="uv__input" v-model.trim="form.email" placeholder="usuario@club.org" autocomplete="off" />
                <span class="uv__hint">Contraseña inicial: <strong>123456Aa</strong> — el usuario deberá cambiarla.</span>
              </div>

              <!-- Sedes (supervisor, medico, dispensador, delivery) -->
              <div v-if="roleConfig.sedes" class="uv__field uv__field--full">
                <label class="uv__label">
                  Sedes asignadas
                  <span v-if="roleConfig.sedeRequerida" class="uv__req"> *</span>
                  <span v-else class="uv__opt"> (opcional)</span>
                </label>

                <div v-if="todasLasSedes.length === 0" class="uv__sedes-empty">
                  <i class="bi bi-building-dash"></i> No hay sedes configuradas en el club.
                </div>
                <div v-else class="uv__sedes-list">
                  <label
                    v-for="s in todasLasSedes"
                    :key="s.id"
                    class="uv__sede-item"
                    :class="{ 'uv__sede-item--checked': sedesSeleccionadas.includes(s.id) }"
                  >
                    <input
                      type="checkbox"
                      :value="s.id"
                      v-model="sedesSeleccionadas"
                      class="uv__sede-check"
                    />
                    <div class="uv__sede-info">
                      <span class="uv__sede-nombre">{{ s.nombre }}</span>
                      <span v-if="s.tipo" class="uv__sede-tipo">{{ s.tipo }}</span>
                    </div>
                    <i v-if="sedesSeleccionadas.includes(s.id)" class="bi bi-check-circle-fill uv__sede-check-ico"></i>
                  </label>
                </div>

                <div v-if="roleConfig.sedeRequerida && sedesSeleccionadas.length === 0" class="uv__sede-warn">
                  <i class="bi bi-exclamation-triangle-fill"></i>
                  {{ form.role === 'cultivador' ? 'El cultivador necesita una sede asignada para ver salas y lotes.' : 'El supervisor necesita al menos una sede asignada para poder operar.' }}
                </div>
                <p v-else-if="roleConfig.sedeHint" class="uv__hint">{{ roleConfig.sedeHint }}</p>
              </div>

              <!-- Sede + sala (cultivador/manicura) -->
              <template v-if="roleConfig.salas">
                <div class="uv__field uv__field--full">
                  <label class="uv__label">Sede <span class="uv__opt">(opcional)</span></label>
                  <select class="uv__input" v-model="form.sede_id" @change="form.sala_id = ''">
                    <option value="">Sin sede asignada</option>
                    <option v-for="s in todasLasSedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                  </select>
                </div>
                <div v-if="form.sede_id && salasDeLaSede.length > 0" class="uv__field uv__field--full">
                  <label class="uv__label">Sala inicial <span class="uv__opt">(opcional)</span></label>
                  <select class="uv__input" v-model="form.sala_id">
                    <option value="">Sin sala asignada</option>
                    <option v-for="sala in salasDeLaSede" :key="sala.id" :value="sala.id">{{ sala.nombre }}</option>
                  </select>
                  <span class="uv__hint">Podés cambiarla o agregar más desde el perfil del usuario.</span>
                </div>
              </template>

            </div>
          </div>

          <!-- ── MODO EDICIÓN: formulario simple ── -->
          <div v-else class="uv__modal-body">
            <div class="uv__form-grid">
              <div class="uv__field">
                <label class="uv__label">Nombre <span class="uv__req">*</span></label>
                <input class="uv__input" v-model.trim="form.first_name" placeholder="Juan" />
              </div>
              <div class="uv__field">
                <label class="uv__label">Apellido <span class="uv__req">*</span></label>
                <input class="uv__input" v-model.trim="form.last_name" placeholder="Pérez" />
              </div>
              <div class="uv__field uv__field--full">
                <label class="uv__label">Email <span class="uv__req">*</span></label>
                <input type="email" class="uv__input" v-model.trim="form.email" placeholder="usuario@club.org" />
              </div>
            </div>
            <p class="uv__edit-note">
              <i class="bi bi-info-circle me-1"></i>
              Para cambiar el rol o las sedes asignadas, usá el perfil del usuario.
            </p>
          </div>

          <!-- Footer -->
          <div class="uv__modal-footer">
            <button class="uv__btn-ghost" @click="!editing && wizardStep === 2 ? prevStep() : closeModal()">
              <i v-if="!editing && wizardStep === 2" class="bi bi-arrow-left"></i>
              {{ !editing && wizardStep === 2 ? 'Volver' : 'Cancelar' }}
            </button>

            <!-- Paso 1: Continuar -->
            <button v-if="!editing && wizardStep === 1" class="uv__btn-primary" @click="nextStep">
              Continuar <i class="bi bi-arrow-right"></i>
            </button>

            <!-- Paso 2 o edición: Guardar -->
            <button
              v-else
              class="uv__btn-primary"
              :disabled="store.saving || (editing ? (!form.first_name.trim() || !form.last_name.trim() || !form.email.trim()) : !formValidStep2)"
              @click="save"
            >
              <DsSpinner v-if="store.saving" :size="15" />
              <i v-else :class="editing ? 'bi bi-check-lg' : 'bi bi-person-plus'"></i>
              {{ editing ? 'Guardar cambios' : 'Crear usuario' }}
            </button>
          </div>

        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.uv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .uv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.uv__header { display: flex; align-items: center; justify-content: space-between; gap: 1.25rem; margin-bottom: 2rem; flex-wrap: wrap; }
.uv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.uv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.uv__header-right { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }

/* Search */
.uv__search { position: relative; display: flex; align-items: center; }
.uv__search-icon { position: absolute; left: .875rem; color: #94a3b8; font-size: .85rem; pointer-events: none; }
.uv__search-input { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .65rem .875rem .65rem 2.25rem; font-size: .875rem; color: #0f172a; width: 280px; outline: none; transition: border-color .15s; }
.uv__search-input:focus { border-color: var(--c-role-admin); }
.uv__search-input::placeholder { color: #94a3b8; }
.uv__search-clear { position: absolute; right: .75rem; color: #94a3b8; cursor: pointer; display: flex; align-items: center; font-size: 1rem; }
.uv__search-clear:hover { color: #0f172a; }

/* Buttons */
.uv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--c-role-admin); color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; text-decoration: none; }
.uv__btn-primary:hover:not(:disabled) { background: #144a18; }
.uv__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.uv__btn-ghost { background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; padding: .65rem 1.1rem; border-radius: 10px; font-size: .875rem; font-weight: 500; cursor: pointer; display: inline-flex; align-items: center; gap: .4rem; }
.uv__btn-ghost:hover { background: #f8fafc; color: #0f172a; }

/* Loading */
.uv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

/* Empty */
.uv__empty { text-align: center; padding: 5rem 1rem; color: #94a3b8; }
.uv__empty-icon { font-size: 3rem; margin-bottom: 1rem; opacity: .4; }
.uv__empty-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; margin: 0 0 .5rem; }
.uv__empty-desc { font-size: .875rem; margin: 0 0 1.25rem; }

/* Table */
.uv__table-wrap { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.uv__table { width: 100%; border-collapse: collapse; font-size: .875rem; }
.uv__table thead th { padding: 10px 14px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; background: #fafafa; white-space: nowrap; }
.uv__table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; }
.uv__table tbody tr:last-child { border-bottom: none; }
.uv__table tbody tr:hover { background: #f8fafc; }
.uv__table-row--link { cursor: pointer; }
.uv__table td { padding: 10px 14px; vertical-align: middle; }
.uv__user-cell { display: flex; align-items: center; gap: .75rem; }
.uv__avatar { width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-size: .72rem; font-weight: 700; flex-shrink: 0; }
.uv__cell-name { font-weight: 600; font-size: .875rem; color: #0f172a; }
.uv__cell-email { font-size: .75rem; color: #9ca3af; }
.uv__role-badge { display: inline-flex; align-items: center; gap: .35rem; font-size: .72rem; font-weight: 700; padding: .2em .6em; border-radius: 5px; border: 1px solid transparent; }
.uv__col-fecha { width: 140px; }
.uv__fecha { font-size: .78rem; color: #94a3b8; }
.uv__row-actions { display: flex; align-items: center; gap: .2rem; justify-content: flex-end; opacity: 0; transition: opacity .15s; }
.uv__table-row:hover .uv__row-actions { opacity: 1; }
.uv__row-btn { display: inline-flex; align-items: center; justify-content: center; width: 30px; height: 30px; border-radius: 7px; background: none; border: none; color: #64748b; cursor: pointer; font-size: .875rem; transition: all .15s; text-decoration: none; }
.uv__row-btn:hover { background: #f1f5f9; color: #1e293b; }
.uv__row-btn--danger:hover { background: #fef2f2; color: #b91c1c; }
@media (max-width: 640px) {
  .uv__col-fecha, .uv__table thead th:nth-child(3), .uv__table td:nth-child(3) { display: none; }
  .uv__row-actions { opacity: 1; }
}

/* Pagination */
.uv__pagination { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1rem; border-top: 1px solid #f1f5f9; gap: 1rem; flex-wrap: wrap; }
.uv__page-footer { padding: .65rem 1rem; border-top: 1px solid #f1f5f9; font-size: .75rem; color: #94a3b8; text-align: right; }
.uv__page-info { font-size: .75rem; color: #94a3b8; }
.uv__page-nav { display: flex; gap: .25rem; align-items: center; }
.uv__page-btn { min-width: 32px; height: 32px; padding: 0 .5rem; border: 1.5px solid #e2e8f0; border-radius: 7px; background: #fff; font-size: .8rem; font-weight: 500; color: #475569; cursor: pointer; transition: all .15s; display: inline-flex; align-items: center; justify-content: center; }
.uv__page-btn:hover:not(:disabled) { border-color: #94a3b8; color: #0f172a; }
.uv__page-btn:disabled { opacity: .4; cursor: not-allowed; }
.uv__page-btn--active { background: var(--c-role-admin); border-color: var(--c-role-admin); color: #fff; font-weight: 700; }

/* ── Modal ─────────────────────────────────────────────────────────────── */
.uv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.uv__modal { background: #fff; border-radius: 20px; width: 100%; max-width: 600px; max-height: 90vh; overflow-y: auto; box-shadow: 0 32px 80px rgba(0,0,0,.18); display: flex; flex-direction: column; }

.uv__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.4rem 1.5rem 1.1rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.uv__modal-header-left { display: flex; flex-direction: column; gap: .6rem; }
.uv__modal-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.02em; }
.uv__modal-close { background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 9px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; font-size: .85rem; flex-shrink: 0; transition: all .15s; }
.uv__modal-close:hover { background: #e2e8f0; color: #0f172a; }

/* Steps */
.uv__steps { display: flex; align-items: center; gap: 0; }
.uv__step { display: flex; align-items: center; gap: .4rem; font-size: .75rem; font-weight: 600; color: #94a3b8; }
.uv__step--active { color: #0f172a; }
.uv__step--done { color: #15803d; }
.uv__step-dot { width: 20px; height: 20px; border-radius: 50%; background: #e2e8f0; color: #64748b; font-size: .68rem; font-weight: 800; display: flex; align-items: center; justify-content: center; transition: all .2s; }
.uv__step--active .uv__step-dot { background: #1b5e20; color: #fff; }
.uv__step--done .uv__step-dot { background: #15803d; color: #fff; }
.uv__step-lbl { font-size: .75rem; }
.uv__step-line { width: 32px; height: 2px; background: #e2e8f0; margin: 0 .4rem; border-radius: 1px; transition: background .2s; }
.uv__step-line--done { background: #15803d; }

/* Modal body */
.uv__modal-body { padding: 1.4rem 1.5rem; flex: 1; }
.uv__step-intro { font-size: .875rem; color: #64748b; margin: 0 0 1.1rem; }

/* Role grid (step 1) */
.uv__role-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: .6rem; }
@media (max-width: 480px) { .uv__role-grid { grid-template-columns: repeat(2, 1fr); } }

.uv__role-card {
  display: flex; flex-direction: column; align-items: flex-start;
  gap: .25rem; padding: .875rem 1rem;
  border: 1.5px solid #e2e8f0; border-radius: 12px;
  background: #fafbfc; cursor: pointer; text-align: left;
  transition: all .15s;
}
.uv__role-card:hover { border-color: #94a3b8; background: #fff; }
.uv__role-card--active { background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.uv__role-card-ico { font-size: 1.1rem; color: #64748b; margin-bottom: .1rem; }
.uv__role-card-name { font-size: .82rem; font-weight: 700; color: #0f172a; }
.uv__role-card-desc { font-size: .7rem; color: #94a3b8; line-height: 1.35; }

/* Role preview (step 2) */
.uv__rol-preview {
  display: flex; align-items: center; gap: .6rem;
  padding: .65rem 1rem;
  border: 1.5px solid #e2e8f0; border-radius: 10px;
  font-size: .82rem; color: #475569;
  margin-bottom: 1.25rem;
}
.uv__rol-preview-desc { color: #64748b; margin-left: .25rem; }

/* Form grid */
.uv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .uv__form-grid { grid-template-columns: 1fr; } }
.uv__field { display: flex; flex-direction: column; gap: .35rem; }
.uv__field--full { grid-column: 1 / -1; }
.uv__label { font-size: .78rem; font-weight: 600; color: #374151; }
.uv__req { color: #ef4444; }
.uv__opt { font-size: .7rem; font-weight: 400; color: #94a3b8; }
.uv__hint { font-size: .73rem; color: #64748b; margin: .2rem 0 0; }
.uv__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; outline: none; transition: border-color .15s; }
.uv__input:focus { border-color: var(--c-role-admin); background: #fff; }

/* Sedes multi-select */
.uv__sedes-empty { font-size: .82rem; color: #94a3b8; padding: .75rem; background: #f8fafc; border-radius: 9px; display: flex; align-items: center; gap: .5rem; }
.uv__sedes-list { display: flex; flex-direction: column; border: 1.5px solid #e2e8f0; border-radius: 10px; overflow: hidden; }
.uv__sede-item {
  display: flex; align-items: center; gap: .75rem;
  padding: .65rem 1rem; cursor: pointer;
  border-bottom: 1px solid #f1f5f9; transition: background .12s;
  user-select: none;
}
.uv__sede-item:last-child { border-bottom: none; }
.uv__sede-item:hover { background: #f8fafc; }
.uv__sede-item--checked { background: #f0fdf4; }
.uv__sede-check { width: 15px; height: 15px; accent-color: #15803d; flex-shrink: 0; cursor: pointer; }
.uv__sede-info { flex: 1; display: flex; flex-direction: column; gap: 1px; }
.uv__sede-nombre { font-size: .85rem; font-weight: 600; color: #0f172a; }
.uv__sede-tipo { font-size: .7rem; color: #94a3b8; text-transform: capitalize; }
.uv__sede-check-ico { color: #15803d; font-size: .85rem; }

/* Sede warning */
.uv__sede-warn {
  display: flex; align-items: flex-start; gap: .5rem;
  background: #fffbeb; border: 1px solid #fde68a;
  border-radius: 9px; padding: .65rem .875rem;
  font-size: .78rem; color: #92400e; margin-top: .5rem; line-height: 1.5;
}
.uv__sede-warn i { color: #d97706; flex-shrink: 0; margin-top: 1px; }

/* Edit note */
.uv__edit-note { font-size: .78rem; color: #64748b; margin: 1rem 0 0; padding: .65rem .875rem; background: #f8fafc; border-radius: 9px; border-left: 3px solid #e2e8f0; }

/* Footer */
.uv__modal-footer { display: flex; justify-content: space-between; gap: .75rem; padding: 1.1rem 1.5rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }

/* Spinner */
</style>
