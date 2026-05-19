<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSuperAdminClub, cambiarPlanClub, crearUsuariosDefault, createSuperAdminUser, updateSuperAdminClub, eliminarClub, restaurarClub } from '../../lib/api.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'

const { confirm } = useConfirm()
const toast = useToast()
const route  = useRoute()
const router = useRouter()
const id     = Number(route.params.id)

const club    = ref(null)
const loading = ref(true)
const saving  = ref(false)
const error   = ref(null)

const showPlanModal = ref(false)
const showUserModal = ref(false)
const planForm = ref({ plan: '', plan_activo_hasta: '', trial: false })
const userForm = ref({ first_name: '', last_name: '', email: '', password: '123456Aa', role: 'cultivador' })
const userError = ref(null)

const smtpForm     = ref({ smtp_host: '', smtp_port: 587, smtp_user: '', smtp_pass: '', smtp_from: '', smtp_from_name: '' })
const savingSmtp   = ref(false)
const smtpError    = ref(null)
const smtpSuccess  = ref(false)

const iaForm       = ref({ ia_habilitada: false, ia_tier: 'basico', ia_limite_hora: 20 })
const savingIa     = ref(false)
const iaSuccess    = ref(false)

const IA_TIERS = [
  { value: 'basico',     label: 'Básico',     desc: '20 calls/h · Solo registro por voz',          color: '#64748b' },
  { value: 'pro',        label: 'Pro',        desc: '60 calls/h · Voz + alertas proactivas',        color: '#0891b2' },
  { value: 'enterprise', label: 'Enterprise', desc: '200 calls/h · Voz + alertas + predicciones',   color: '#7c3aed' },
]
function iaTierMeta(t) { return IA_TIERS.find(x => x.value === t) || IA_TIERS[0] }

const PLAN_META = {
  semilla:    { label: 'Semilla',    color: '#64748b', bg: '#f1f5f9' },
  brote:      { label: 'Brote',      color: '#15803d', bg: '#dcfce7' },
  cosecha:    { label: 'Cosecha',    color: '#0369a1', bg: '#dbeafe' },
  federacion: { label: 'Federación', color: '#7c3aed', bg: '#ede9fe' },
}
const PLANES = Object.entries(PLAN_META).map(([v, m]) => ({ value: v, ...m }))
function planMeta(p) { return PLAN_META[p] || PLAN_META.semilla }

const ROLES = ['admin', 'medico', 'cultivador', 'abogado', 'auditor']
const ROLE_META = {
  admin:      { label: 'Admin',      color: '#0f172a', bg: '#f1f5f9' },
  medico:     { label: 'Médico',     color: '#0369a1', bg: '#dbeafe' },
  cultivador: { label: 'Cultivador', color: '#16a34a', bg: '#f0fdf4' },
  abogado:    { label: 'Abogado',    color: '#7c3aed', bg: '#ede9fe' },
  auditor:    { label: 'Auditor',    color: '#b45309', bg: '#fffbeb' },
}
function roleMeta(r) { return ROLE_META[r] || { label: r, color: '#64748b', bg: '#f1f5f9' } }

function formatDate(d) {
  if (!d) return '—'
  const safe = /^\d{4}-\d{2}-\d{2}$/.test(d) ? d + 'T00:00:00' : d
  return new Date(safe).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

async function cargar() {
  try {
    const { data } = await getSuperAdminClub(id)
    club.value = data
    smtpForm.value = {
      smtp_host:      data.smtp_host      || '',
      smtp_port:      data.smtp_port      || 587,
      smtp_user:      data.smtp_user      || '',
      smtp_pass:      '',
      smtp_from:      data.smtp_from      || '',
      smtp_from_name: data.smtp_from_name || '',
    }
    iaForm.value = {
      ia_habilitada:  data.ia_habilitada  ?? false,
      ia_tier:        data.ia_tier        || 'basico',
      ia_limite_hora: data.ia_limite_hora || 20,
    }
  } finally {
    loading.value = false
  }
}

function abrirPlanModal() {
  planForm.value = {
    plan:              club.value.plan,
    plan_activo_hasta: club.value.plan_activo_hasta?.toString().slice(0, 10) || '',
    trial:             club.value.plan_trial,
  }
  showPlanModal.value = true
}

function abrirUserModal() {
  userForm.value = { first_name: '', last_name: '', email: '', password: '123456Aa', role: 'cultivador' }
  userError.value = null
  showUserModal.value = true
}

async function guardarPlan() {
  saving.value = true
  error.value  = null
  try {
    const { data } = await cambiarPlanClub(id, {
      plan:  planForm.value.plan,
      hasta: planForm.value.plan_activo_hasta || null,
      trial: planForm.value.trial,
    })
    club.value = { ...club.value, ...data }
    showPlanModal.value = false
    toast.success('Plan actualizado')
  } catch (e) {
    error.value = e?.response?.data?.error || 'Error al actualizar el plan'
  } finally {
    saving.value = false
  }
}

async function crearUsuario() {
  if (!userForm.value.email.trim()) { userError.value = 'El email es obligatorio'; return }
  saving.value = true
  userError.value = null
  try {
    await createSuperAdminUser({ ...userForm.value, club_id: id })
    await cargar()
    showUserModal.value = false
    toast.success('Usuario creado')
  } catch (e) {
    userError.value = e?.response?.data?.errors?.join(', ') || 'Error al crear el usuario'
  } finally {
    saving.value = false
  }
}

async function generarUsuarios() {
  const ok = await confirm({ title: '¿Generar usuarios por defecto?', message: 'Solo se crean los que no existen todavía.', variant: 'default', confirmText: 'Generar' })
  if (!ok) return
  saving.value = true
  try {
    const { data } = await crearUsuariosDefault(id)
    await cargar()
    toast.success(`Se crearon ${data.usuarios.length} usuarios nuevos.`)
  } finally {
    saving.value = false
  }
}

async function toggleWeb() {
  saving.value = true
  try {
    const { data } = await updateSuperAdminClub(id, { web_activa: !club.value.web_activa })
    club.value = { ...club.value, ...data }
  } catch {
    toast.error('Error al actualizar')
  } finally {
    saving.value = false
  }
}

async function eliminar() {
  const ok = await confirm({
    title: `Eliminar ${club.value.name}`,
    message: 'El club y toda su data quedarán inaccesibles para sus usuarios. Los datos NO se borran de la base de datos.',
    confirmText: 'Eliminar club',
    variant: 'danger',
  })
  if (!ok) return
  saving.value = true
  try {
    await eliminarClub(id)
    toast.success('Club eliminado')
    router.push({ name: 'sa-dashboard' })
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al eliminar')
  } finally {
    saving.value = false
  }
}

async function restaurar() {
  const ok = await confirm({
    title: `Restaurar ${club.value.name}`,
    message: 'El club y sus usuarios recuperarán acceso al sistema.',
    confirmText: 'Restaurar',
    variant: 'default',
  })
  if (!ok) return
  saving.value = true
  try {
    const { data } = await restaurarClub(id)
    club.value = data
    toast.success('Club restaurado')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al restaurar')
  } finally {
    saving.value = false
  }
}

async function guardarIa() {
  savingIa.value = true
  iaSuccess.value = false
  try {
    const { data } = await updateSuperAdminClub(id, iaForm.value)
    club.value = { ...club.value, ...data }
    iaSuccess.value = true
    setTimeout(() => { iaSuccess.value = false }, 3000)
  } finally {
    savingIa.value = false
  }
}

async function guardarSmtp() {
  savingSmtp.value = true
  smtpError.value  = null
  smtpSuccess.value = false
  try {
    const payload = { ...smtpForm.value }
    if (!payload.smtp_pass) delete payload.smtp_pass
    const { data } = await updateSuperAdminClub(id, payload)
    club.value = { ...club.value, ...data }
    smtpForm.value.smtp_pass = ''
    smtpSuccess.value = true
    setTimeout(() => { smtpSuccess.value = false }, 3000)
  } catch (e) {
    smtpError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally {
    savingSmtp.value = false
  }
}

onMounted(cargar)
</script>

<template>
  <div class="scd">

    <div v-if="loading" class="scd__loading">
      <div class="scd__ring"></div>
    </div>

    <template v-else-if="club">

      <!-- Banner eliminado -->
      <div v-if="club.deleted_at" class="scd__deleted-banner">
        <i class="bi bi-trash3"></i>
        <div>
          <strong>Club eliminado</strong> — eliminado el {{ formatDate(club.deleted_at) }}. Los usuarios no pueden acceder.
        </div>
        <button class="scd__btn-restore" :disabled="saving" @click="restaurar">
          <i class="bi bi-arrow-counterclockwise"></i> Restaurar
        </button>
      </div>

      <!-- Header -->
      <div class="scd__header">
        <div>
          <RouterLink :to="{ name: 'sa-dashboard' }" class="scd__back">
            <i class="bi bi-arrow-left"></i> Dashboard
          </RouterLink>
          <div class="scd__title-row">
            <div class="scd__avatar" :class="{ 'scd__avatar--deleted': club.deleted_at }">
              {{ club.name?.[0]?.toUpperCase() }}
            </div>
            <div>
              <h1 class="scd__title">{{ club.name }}</h1>
              <div class="scd__slug">{{ club.slug }}</div>
            </div>
          </div>
        </div>
        <div class="scd__header-actions">
          <button class="scd__btn-secondary" @click="generarUsuarios" :disabled="saving">
            <i class="bi bi-magic"></i> Generar usuarios
          </button>
          <button v-if="!club.deleted_at" class="scd__btn-danger" @click="eliminar" :disabled="saving">
            <i class="bi bi-trash3"></i> Eliminar club
          </button>
        </div>
      </div>

      <!-- Layout 3 columnas -->
      <div class="scd__layout">

        <!-- Col 1: Info del club -->
        <div class="scd__card">
          <div class="scd__card-header">
            <span class="scd__card-title">Información</span>
          </div>
          <dl class="scd__dl">
            <dt>Nombre legal</dt><dd>{{ club.legal_name || '—' }}</dd>
            <dt>Email</dt><dd>{{ club.email || '—' }}</dd>
            <dt>Teléfono</dt><dd>{{ club.phone || '—' }}</dd>
            <dt>Sitio web</dt><dd>{{ club.website || '—' }}</dd>
            <dt>Dirección</dt><dd>{{ club.address || '—' }}</dd>
            <dt>Ciudad</dt><dd>{{ club.city || '—' }}</dd>
            <dt>Provincia</dt><dd>{{ club.state || '—' }}</dd>
            <dt>País</dt><dd>{{ club.country || '—' }}</dd>
            <dt>Timezone</dt><dd>{{ club.timezone || '—' }}</dd>
            <dt>Registrado</dt><dd>{{ formatDate(club.created_at) }}</dd>
          </dl>

          <!-- Estadísticas rápidas -->
          <div class="scd__stats">
            <div class="scd__stat">
              <div class="scd__stat-val">{{ club.usuarios_count }}</div>
              <div class="scd__stat-lbl">Usuarios</div>
            </div>
            <div class="scd__stat">
              <div class="scd__stat-val">{{ club.pacientes_count }}</div>
              <div class="scd__stat-lbl">Pacientes</div>
            </div>
            <div class="scd__stat">
              <div class="scd__stat-val">{{ club.lotes_count }}</div>
              <div class="scd__stat-lbl">Lotes</div>
            </div>
          </div>
        </div>

        <!-- Col 2: Plan + Web -->
        <div class="scd__col">

          <div class="scd__card">
            <div class="scd__card-header">
              <span class="scd__card-title">Plan</span>
              <button class="scd__edit-btn" @click="abrirPlanModal">
                <i class="bi bi-pencil"></i> Cambiar
              </button>
            </div>
            <div class="scd__plan-body">
              <span class="scd__plan-badge"
                    :style="{ background: planMeta(club.plan).bg, color: planMeta(club.plan).color }">
                {{ planMeta(club.plan).label }}
              </span>
              <span v-if="club.plan_trial" class="scd__trial-badge">TRIAL</span>
              <div class="scd__plan-meta">
                <span v-if="club.plan_activo_hasta">Vigente hasta {{ formatDate(club.plan_activo_hasta) }}</span>
                <span v-else>Sin fecha de vencimiento</span>
              </div>
            </div>
          </div>

          <div class="scd__card scd__card--mt">
            <div class="scd__card-header">
              <span class="scd__card-title">Web pública</span>
            </div>
            <div class="scd__plan-body" style="justify-content:space-between">
              <div>
                <div class="scd__web-status">{{ club.web_activa ? 'Activa y visible al público' : 'Desactivada' }}</div>
                <div class="scd__web-hint">{{ club.web_activa ? 'El sitio público es accesible.' : 'El sitio no es accesible públicamente.' }}</div>
              </div>
              <button
                class="scd__web-toggle"
                :class="{ 'scd__web-toggle--on': club.web_activa }"
                :disabled="saving"
                @click="toggleWeb"
              >
                <span class="scd__web-toggle-thumb"></span>
              </button>
            </div>
          </div>

        </div>

        <!-- Col 3: Usuarios -->
        <div class="scd__card">
          <div class="scd__card-header">
            <span class="scd__card-title">Usuarios ({{ club.usuarios?.length || 0 }})</span>
            <button class="scd__btn-primary scd__btn-sm" @click="abrirUserModal">
              <i class="bi bi-person-plus"></i> Crear
            </button>
          </div>
          <div v-if="!club.usuarios?.length" class="scd__empty">Sin usuarios</div>
          <div v-else class="scd__users">
            <div v-for="u in club.usuarios" :key="u.id" class="scd__user-row">
              <div class="scd__user-avatar">
                {{ (u.nombre?.[0] || u.email?.[0] || '?').toUpperCase() }}
              </div>
              <div class="scd__user-info">
                <div class="scd__user-nombre">{{ u.nombre || '—' }}</div>
                <div class="scd__user-email">{{ u.email }}</div>
              </div>
              <span class="scd__role-badge"
                    :style="{ background: roleMeta(u.role).bg, color: roleMeta(u.role).color }">
                {{ roleMeta(u.role).label }}
              </span>
            </div>
          </div>
        </div>

      </div>

      <!-- ══ SMTP ══ -->
      <div class="scd__smtp-card">
        <div class="scd__smtp-header">
          <div class="scd__smtp-title-row">
            <i class="bi bi-envelope-at" style="color:#ea580c"></i>
            <span class="scd__card-title">Correo saliente (SMTP)</span>
            <span v-if="club.smtp_configured" class="scd__smtp-ok">Configurado</span>
            <span v-else class="scd__smtp-missing">Sin configurar</span>
          </div>
        </div>
        <div class="scd__smtp-body">
          <div v-if="smtpError"   class="scd__alert">{{ smtpError }}</div>
          <div v-if="smtpSuccess" class="scd__alert scd__alert--ok"><i class="bi bi-check-circle"></i> Configuración guardada</div>
          <div class="scd__smtp-grid">
            <div class="scd__field">
              <label class="scd__label">Nombre remitente</label>
              <input v-model.trim="smtpForm.smtp_from_name" class="scd__input" placeholder="Club Medicinal del Sur" />
            </div>
            <div class="scd__field">
              <label class="scd__label">Email remitente</label>
              <input v-model.trim="smtpForm.smtp_from" type="email" class="scd__input" placeholder="no-reply@clubmedicinal.org" />
              <span class="scd__hint">Dejá vacío para usar el usuario SMTP</span>
            </div>
            <div class="scd__field">
              <label class="scd__label">Host SMTP</label>
              <input v-model.trim="smtpForm.smtp_host" class="scd__input" placeholder="smtp.gmail.com" />
            </div>
            <div class="scd__field">
              <label class="scd__label">Puerto</label>
              <input v-model.number="smtpForm.smtp_port" type="number" class="scd__input" placeholder="587" />
              <span class="scd__hint">587 TLS · 465 SSL · 25 sin cifrado</span>
            </div>
            <div class="scd__field">
              <label class="scd__label">Usuario SMTP</label>
              <input v-model.trim="smtpForm.smtp_user" class="scd__input" placeholder="correo@gmail.com" />
            </div>
            <div class="scd__field">
              <label class="scd__label">Contraseña SMTP</label>
              <input v-model="smtpForm.smtp_pass" type="password" class="scd__input" placeholder="Dejá vacío para no cambiar" autocomplete="new-password" />
              <span class="scd__hint">Para Gmail usá una App Password</span>
            </div>
          </div>
          <div class="scd__smtp-footer">
            <button class="scd__btn-primary scd__btn-sm" :disabled="savingSmtp" @click="guardarSmtp">
              <span v-if="savingSmtp" class="scd__spinner"></span>
              <i v-else class="bi bi-floppy"></i>
              {{ savingSmtp ? 'Guardando…' : 'Guardar SMTP' }}
            </button>
          </div>
        </div>
      </div>

      <!-- ══ IA ══ -->
      <div class="scd__ia-card">
        <div class="scd__ia-header">
          <div class="scd__ia-title-row">
            <span class="scd__ia-icon">🤖</span>
            <span class="scd__ia-title">Asistente de IA</span>
            <span v-if="club.ia_habilitada" class="scd__ia-badge scd__ia-badge--on"
                  :style="{ background: iaTierMeta(club.ia_tier).color + '20', color: iaTierMeta(club.ia_tier).color }">
              {{ iaTierMeta(club.ia_tier).label }}
            </span>
            <span v-else class="scd__ia-badge scd__ia-badge--off">Desactivado</span>
            <span v-if="iaSuccess" class="scd__alert--ok">Guardado</span>
          </div>
        </div>
        <div class="scd__ia-body">
          <label class="scd__toggle scd__ia-toggle">
            <input v-model="iaForm.ia_habilitada" type="checkbox" class="scd__toggle__input" />
            <div class="scd__toggle__track"><div class="scd__toggle__thumb"></div></div>
            <div class="scd__toggle__label">Habilitar asistente de IA para este club</div>
          </label>

          <div v-if="iaForm.ia_habilitada" class="scd__ia-tiers">
            <button
              v-for="tier in IA_TIERS" :key="tier.value"
              type="button"
              class="scd__ia-tier-btn"
              :class="{ 'scd__ia-tier-btn--active': iaForm.ia_tier === tier.value }"
              :style="iaForm.ia_tier === tier.value ? { borderColor: tier.color, background: tier.color + '12', color: tier.color } : {}"
              @click="iaForm.ia_tier = tier.value; iaForm.ia_limite_hora = IA_TIERS.find(t => t.value === tier.value) ? [20,60,200][IA_TIERS.findIndex(t=>t.value===tier.value)] : 20"
            >
              <strong>{{ tier.label }}</strong>
              <span>{{ tier.desc }}</span>
            </button>
          </div>

          <div v-if="iaForm.ia_habilitada" class="scd__ia-limite">
            <label class="scd__label">Límite de llamadas por hora</label>
            <input v-model.number="iaForm.ia_limite_hora" type="number" min="1" max="500" class="scd__input scd__input--sm" />
            <span class="scd__hint">Sobreescribe el límite del tier. Usar con cuidado.</span>
          </div>
        </div>
        <div class="scd__ia-footer">
          <button class="scd__btn-primary scd__btn-sm" :disabled="savingIa" @click="guardarIa">
            <span v-if="savingIa" class="scd__spinner"></span>
            <i v-else class="bi bi-robot"></i>
            {{ savingIa ? 'Guardando…' : 'Guardar IA' }}
          </button>
        </div>
      </div>

      <!-- ══ Modal cambiar plan ══ -->
      <Teleport to="body">
        <div v-if="showPlanModal" class="scd__overlay" @click.self="showPlanModal = false">
          <div class="scd__modal">
            <div class="scd__modal-header">
              <h3 class="scd__modal-title">Cambiar plan — {{ club.name }}</h3>
              <button class="scd__modal-close" @click="showPlanModal = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="scd__modal-body">
              <div v-if="error" class="scd__alert">{{ error }}</div>
              <div class="scd__field">
                <label class="scd__label">Plan</label>
                <div class="scd__planes">
                  <button v-for="p in PLANES" :key="p.value" type="button"
                          class="scd__plan-btn"
                          :class="{ 'scd__plan-btn--active': planForm.plan === p.value }"
                          :style="planForm.plan === p.value ? { borderColor: p.color, background: p.bg, color: p.color } : {}"
                          @click="planForm.plan = p.value">
                    {{ p.label }}
                  </button>
                </div>
              </div>
              <div class="scd__field">
                <label class="scd__label">Vigente hasta</label>
                <input v-model="planForm.plan_activo_hasta" type="date" class="scd__input" />
                <span class="scd__hint">Dejá vacío para sin vencimiento</span>
              </div>
              <label class="scd__toggle">
                <input v-model="planForm.trial" type="checkbox" class="scd__toggle__input" />
                <div class="scd__toggle__track"><div class="scd__toggle__thumb"></div></div>
                <div class="scd__toggle__label">Período de prueba (trial)</div>
              </label>
            </div>
            <div class="scd__modal-footer">
              <button class="scd__btn-ghost" @click="showPlanModal = false">Cancelar</button>
              <button class="scd__btn-primary" :disabled="saving" @click="guardarPlan">
                <span v-if="saving" class="scd__spinner"></span>
                <i v-else class="bi bi-check-lg"></i> Guardar
              </button>
            </div>
          </div>
        </div>
      </Teleport>

      <!-- ══ Modal crear usuario ══ -->
      <Teleport to="body">
        <div v-if="showUserModal" class="scd__overlay" @click.self="showUserModal = false">
          <div class="scd__modal">
            <div class="scd__modal-header">
              <h3 class="scd__modal-title">Nuevo usuario — {{ club.name }}</h3>
              <button class="scd__modal-close" @click="showUserModal = false"><i class="bi bi-x-lg"></i></button>
            </div>
            <div class="scd__modal-body">
              <div v-if="userError" class="scd__alert">{{ userError }}</div>
              <div class="scd__grid">
                <div class="scd__field">
                  <label class="scd__label">Nombre</label>
                  <input v-model.trim="userForm.first_name" class="scd__input" placeholder="Juan" autofocus />
                </div>
                <div class="scd__field">
                  <label class="scd__label">Apellido</label>
                  <input v-model.trim="userForm.last_name" class="scd__input" placeholder="García" />
                </div>
                <div class="scd__field scd__field--full">
                  <label class="scd__label">Email <span style="color:#dc2626">*</span></label>
                  <input v-model.trim="userForm.email" type="email" class="scd__input" placeholder="juan@club.com" />
                </div>
                <div class="scd__field">
                  <label class="scd__label">Contraseña inicial</label>
                  <input v-model="userForm.password" class="scd__input" />
                </div>
                <div class="scd__field">
                  <label class="scd__label">Rol</label>
                  <select v-model="userForm.role" class="scd__input">
                    <option v-for="r in ROLES" :key="r" :value="r">{{ roleMeta(r).label }}</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="scd__modal-footer">
              <button class="scd__btn-ghost" @click="showUserModal = false">Cancelar</button>
              <button class="scd__btn-primary" :disabled="saving" @click="crearUsuario">
                <span v-if="saving" class="scd__spinner"></span>
                <i v-else class="bi bi-person-plus"></i>
                {{ saving ? 'Creando…' : 'Crear usuario' }}
              </button>
            </div>
          </div>
        </div>
      </Teleport>

    </template>
  </div>
</template>

<style scoped>
.scd { padding: 2rem 2rem 3rem; max-width: 1200px; }
.scd__loading { display: flex; justify-content: center; padding: 5rem; }
.scd__ring { width: 24px; height: 24px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: scd-spin .7s linear infinite; }
@keyframes scd-spin { to { transform: rotate(360deg); } }

/* Banner eliminado */
.scd__deleted-banner {
  display: flex; align-items: center; gap: 1rem; flex-wrap: wrap;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 12px;
  padding: 1rem 1.25rem; margin-bottom: 1.5rem;
  font-size: .875rem; color: #991b1b;
}
.scd__deleted-banner strong { color: #7f1d1d; }
.scd__deleted-banner > div { flex: 1; }
.scd__btn-restore {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #fff; color: #991b1b; border: 1.5px solid #fca5a5;
  padding: .45rem .9rem; border-radius: 8px; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s; white-space: nowrap;
}
.scd__btn-restore:hover:not(:disabled) { background: #fef2f2; }
.scd__btn-restore:disabled { opacity: .5; cursor: not-allowed; }

/* Header */
.scd__back { display: inline-flex; align-items: center; gap: .4rem; font-size: .8rem; font-weight: 600; color: #64748b; text-decoration: none; margin-bottom: .75rem; }
.scd__back:hover { color: #0f172a; }
.scd__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.scd__title-row { display: flex; align-items: center; gap: .875rem; }
.scd__avatar { width: 48px; height: 48px; border-radius: 12px; background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.15)); color: #1b5e20; font-size: 1.1rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.scd__avatar--deleted { background: #f1f5f9; color: #94a3b8; }
.scd__title { font-size: 1.75rem; font-weight: 800; color: #0f172a; margin: 0 0 .15rem; letter-spacing: -.03em; }
.scd__slug  { font-size: .78rem; color: #94a3b8; font-family: monospace; }
.scd__header-actions { display: flex; gap: .6rem; flex-wrap: wrap; align-items: center; }

/* Layout 3 columnas */
.scd__layout { display: grid; grid-template-columns: 1.2fr 1fr 1.2fr; gap: 1.25rem; align-items: start; }
@media (max-width: 1100px) { .scd__layout { grid-template-columns: 1fr 1fr; } }
@media (max-width: 700px)  { .scd__layout { grid-template-columns: 1fr; } }
.scd__col { display: flex; flex-direction: column; gap: 1.25rem; }

/* Cards */
.scd__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.scd__card--mt { margin-top: 1.25rem; }
.scd__card-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.scd__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; }
.scd__edit-btn { font-size: .75rem; font-weight: 600; color: #0369a1; background: none; border: none; cursor: pointer; display: flex; align-items: center; gap: .3rem; }
.scd__edit-btn:hover { text-decoration: underline; }

.scd__dl { display: grid; grid-template-columns: 110px 1fr; gap: .4rem .75rem; padding: 1rem 1.1rem; margin: 0; }
.scd__dl dt { font-size: .75rem; color: #94a3b8; font-weight: 500; }
.scd__dl dd { font-size: .82rem; color: #0f172a; font-weight: 500; margin: 0; }

/* Stats rápidas */
.scd__stats { display: grid; grid-template-columns: repeat(3, 1fr); border-top: 1px solid #f1f5f9; }
.scd__stat { padding: .875rem; text-align: center; border-right: 1px solid #f1f5f9; }
.scd__stat:last-child { border-right: none; }
.scd__stat-val { font-size: 1.4rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; }
.scd__stat-lbl { font-size: .68rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; margin-top: .1rem; }

/* Plan */
.scd__plan-body { padding: 1rem 1.1rem; display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.scd__plan-badge { font-size: .82rem; font-weight: 800; padding: .3em .85em; border-radius: 8px; }
.scd__trial-badge { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; background: #fffbeb; color: #b45309; padding: .2em .6em; border-radius: 6px; }
.scd__plan-meta { font-size: .78rem; color: #94a3b8; width: 100%; }
.scd__web-status { font-size: .875rem; font-weight: 600; color: #0f172a; margin-bottom: .2rem; }
.scd__web-hint   { font-size: .78rem; color: #94a3b8; }

/* Usuarios */
.scd__empty { padding: 2rem; text-align: center; color: #94a3b8; font-size: .875rem; }
.scd__users { display: flex; flex-direction: column; max-height: 420px; overflow-y: auto; }
.scd__user-row { display: flex; align-items: center; gap: .75rem; padding: .7rem 1.1rem; border-bottom: 1px solid #f8fafc; }
.scd__user-row:last-child { border-bottom: none; }
.scd__user-avatar { width: 32px; height: 32px; border-radius: 50%; background: #f1f5f9; color: #475569; font-size: .75rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.scd__user-info { flex: 1; min-width: 0; }
.scd__user-nombre { font-size: .82rem; font-weight: 600; color: #0f172a; }
.scd__user-email  { font-size: .72rem; color: #94a3b8; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.scd__role-badge { font-size: .68rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; white-space: nowrap; flex-shrink: 0; }

/* Botones */
.scd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s; white-space: nowrap; }
.scd__btn-primary:hover:not(:disabled) { background: #144a18; }
.scd__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-sm { padding: .45rem .875rem; font-size: .8rem; }
.scd__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.scd__btn-secondary:hover:not(:disabled) { background: #f8fafc; border-color: #94a3b8; }
.scd__btn-secondary:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-danger { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #b91c1c; border: 1.5px solid #fca5a5; padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.scd__btn-danger:hover:not(:disabled) { background: #fef2f2; border-color: #f87171; }
.scd__btn-danger:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-ghost { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.scd__btn-ghost:hover { background: #f8fafc; }

/* Modal */
.scd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.scd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.scd__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9; }
.scd__modal-title { font-size: 1.05rem; font-weight: 800; color: #0f172a; margin: 0; }
.scd__modal-close { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.scd__modal-close:hover { background: #e2e8f0; }
.scd__modal-body { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: 1rem; }
.scd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; }
.scd__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem; border-radius: 8px; font-size: .85rem; }
.scd__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.scd__field { display: flex; flex-direction: column; gap: .35rem; }
.scd__field--full { grid-column: 1 / -1; }
.scd__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.scd__hint { font-size: .72rem; color: #94a3b8; }
.scd__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .6rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; }
.scd__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.scd__planes { display: grid; grid-template-columns: repeat(2,1fr); gap: .5rem; }
.scd__plan-btn { padding: .6rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 9px; background: #f8fafc; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; text-align: left; color: #475569; }
.scd__plan-btn:hover { border-color: #94a3b8; }
.scd__toggle { display: flex; align-items: center; gap: .75rem; cursor: pointer; padding: .75rem; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; }
.scd__toggle__input { display: none; }
.scd__toggle__track { width: 38px; height: 22px; background: #cbd5e1; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.scd__toggle__input:checked + .scd__toggle__track { background: #1b5e20; }
.scd__toggle__thumb { position: absolute; width: 16px; height: 16px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; }
.scd__toggle__input:checked + .scd__toggle__track .scd__toggle__thumb { left: 19px; }
.scd__toggle__label { font-size: .875rem; font-weight: 600; color: #0f172a; }
.scd__spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: scd-spin .6s linear infinite; }

/* SMTP card */
.scd__smtp-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; margin-top: 1.25rem; }
.scd__smtp-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.scd__smtp-title-row { display: flex; align-items: center; gap: .6rem; }
.scd__smtp-ok      { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; background: #dcfce7; color: #15803d; padding: .2em .65em; border-radius: 6px; }
.scd__smtp-missing { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; background: #fef3c7; color: #b45309; padding: .2em .65em; border-radius: 6px; }
.scd__smtp-body { padding: 1.25rem 1.4rem; }
.scd__smtp-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 1rem; }
@media (max-width: 900px) { .scd__smtp-grid { grid-template-columns: 1fr 1fr; } }
@media (max-width: 600px) { .scd__smtp-grid { grid-template-columns: 1fr; } }
.scd__smtp-footer { display: flex; justify-content: flex-end; margin-top: 1rem; }
.scd__alert--ok { background: #f0fdf4; border-color: #bbf7d0; color: #15803d; display: flex; align-items: center; gap: .5rem; }

/* IA card */
.scd__ia-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; margin-top: 1.5rem; }
.scd__ia-header { padding: 1rem 1.25rem .75rem; border-bottom: 1px solid #f1f5f9; }
.scd__ia-title-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.scd__ia-icon { font-size: 1.1rem; }
.scd__ia-title { font-size: .95rem; font-weight: 700; color: #0f172a; }
.scd__ia-badge { font-size: .65rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; padding: .2em .65em; border-radius: 6px; }
.scd__ia-badge--on  { /* color set inline */ }
.scd__ia-badge--off { background: #f1f5f9; color: #94a3b8; }
.scd__ia-body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.scd__ia-toggle { gap: .75rem; }
.scd__ia-tiers { display: flex; flex-direction: column; gap: .5rem; }
.scd__ia-tier-btn {
  display: flex; flex-direction: column; align-items: flex-start; gap: .15rem;
  padding: .65rem 1rem; border-radius: 8px;
  border: 1.5px solid #e2e8f0; background: #f8fafc;
  cursor: pointer; text-align: left; transition: all .15s;
}
.scd__ia-tier-btn strong { font-size: .85rem; }
.scd__ia-tier-btn span   { font-size: .72rem; color: #64748b; }
.scd__ia-tier-btn--active span { color: inherit; opacity: .8; }
.scd__ia-tier-btn:hover { border-color: #94a3b8; }
.scd__ia-limite { display: flex; flex-direction: column; gap: .3rem; max-width: 200px; }
.scd__input--sm { width: 100%; }
.scd__ia-footer { padding: .75rem 1.25rem; border-top: 1px solid #f1f5f9; display: flex; justify-content: flex-end; }

/* Web toggle */
.scd__web-toggle { width: 46px; height: 26px; border-radius: 13px; background: #e2e8f0; border: none; cursor: pointer; position: relative; transition: background .25s; padding: 0; flex-shrink: 0; }
.scd__web-toggle--on { background: #1b5e20; }
.scd__web-toggle:disabled { opacity: .5; cursor: not-allowed; }
.scd__web-toggle-thumb { position: absolute; top: 3px; left: 3px; width: 20px; height: 20px; border-radius: 50%; background: white; transition: transform .25s; display: block; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.scd__web-toggle--on .scd__web-toggle-thumb { transform: translateX(20px); }
</style>
