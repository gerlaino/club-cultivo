<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSuperAdminClub, cambiarPlanClub, crearUsuariosDefault, createSuperAdminUser, updateSuperAdminClub, eliminarClub, restaurarClub } from '../../lib/api.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import { ArrowLeft, Pencil, Trash2, RotateCcw, Sparkles, UserPlus, Check, X, Save, Mail, Zap, Users, Info, CreditCard } from 'lucide-vue-next'

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

const featuresForm    = ref({})
const iaTier          = ref('basico')
const iaLimiteHora    = ref(20)
const savingFeatures  = ref(false)
const featuresSuccess = ref(false)

const IA_TIERS = [
  { value: 'basico',     label: 'Básico',     desc: '20 calls/h · Solo registro por voz',        color: '#64748b' },
  { value: 'pro',        label: 'Pro',        desc: '60 calls/h · Voz + alertas proactivas',      color: '#0891b2' },
  { value: 'enterprise', label: 'Enterprise', desc: '200 calls/h · Voz + alertas + predicciones', color: '#7c3aed' },
]
const FEATURE_META = {
  ia_analisis:      { label: 'Análisis IA',      desc: 'Análisis de lotes, plantas y alertas por IA', icon: '🔬' },
  ia_voz:           { label: 'Asistente de voz', desc: 'Registro y consultas por voz con IA',          icon: '🎙️' },
  web_publica:      { label: 'Web pública',       desc: 'Sitio web público del club',                   icon: '🌐' },
  mailer:           { label: 'Correo',            desc: 'Envío de correos a socios',                    icon: '✉️' },
  iot:              { label: 'IoT / Sensores',    desc: 'Integración de sensores ambientales',           icon: '📡' },
  alertas:          { label: 'Alertas',           desc: 'Alertas automáticas por sala y lote',          icon: '🔔' },
  ariccame:         { label: 'ARICCAME',          desc: 'Reportes para el registro ARICCAME',           icon: '📋' },
  cuenta_corriente: { label: 'Cuenta corriente', desc: 'Saldo y movimientos por socio',                icon: '💳' },
  analytics:        { label: 'Analytics',         desc: 'Dashboard de analítica avanzada',              icon: '📊' },
  multi_sede:       { label: 'Multi-sede',        desc: 'Múltiples sedes/ubicaciones',                  icon: '🏢' },
}
const FEATURES_ORDER = Object.keys(FEATURE_META)
const iaActiva = computed(() => featuresForm.value.ia_analisis || featuresForm.value.ia_voz)

const PLAN_META = {
  semilla:    { label: 'Semilla',    color: '#64748b', bg: '#f1f5f9' },
  brote:      { label: 'Brote',      color: '#15803d', bg: '#dcfce7' },
  cosecha:    { label: 'Cosecha',    color: '#0369a1', bg: '#dbeafe' },
  federacion: { label: 'Federación', color: '#7c3aed', bg: '#ede9fe' },
}
const PLANES = Object.entries(PLAN_META).map(([v, m]) => ({ value: v, ...m }))
function planMeta(p) { return PLAN_META[p] || PLAN_META.semilla }

const ROLES = ['admin', 'medico', 'cultivador', 'supervisor', 'abogado', 'auditor', 'dispensador', 'manicura', 'delivery']
const ROLE_META = {
  admin:       { label: 'Admin',       color: '#0f172a', bg: '#f1f5f9' },
  medico:      { label: 'Médico',      color: '#0369a1', bg: '#dbeafe' },
  cultivador:  { label: 'Cultivador',  color: '#16a34a', bg: '#f0fdf4' },
  supervisor:  { label: 'Supervisor',  color: '#0369a1', bg: '#e0f2fe' },
  abogado:     { label: 'Abogado',     color: '#7c3aed', bg: '#ede9fe' },
  auditor:     { label: 'Auditor',     color: '#b45309', bg: '#fffbeb' },
  dispensador: { label: 'Dispensador', color: '#0f766e', bg: '#ccfbf1' },
  manicura:    { label: 'Manicura',    color: '#9d174d', bg: '#fce7f3' },
  delivery:    { label: 'Delivery',    color: '#374151', bg: '#f3f4f6' },
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
    const features = { ...(data.features || {}) }
    if (features.web_publica === undefined) features.web_publica = data.web_activa || false
    featuresForm.value = features
    iaTier.value       = data.ia_tier        || 'basico'
    iaLimiteHora.value = data.ia_limite_hora || 20
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

async function guardarFeatures() {
  savingFeatures.value = true
  featuresSuccess.value = false
  try {
    const { data } = await updateSuperAdminClub(id, {
      features:       featuresForm.value,
      ia_tier:        iaTier.value,
      ia_limite_hora: iaLimiteHora.value,
      web_activa:     featuresForm.value.web_publica === true,
    })
    club.value = { ...club.value, ...data }
    featuresSuccess.value = true
    setTimeout(() => { featuresSuccess.value = false }, 3000)
  } finally {
    savingFeatures.value = false
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

    <div v-if="loading" class="scd__loading"><div class="scd__ring"></div></div>

    <template v-else-if="club">

      <!-- Banner eliminado -->
      <div v-if="club.deleted_at" class="scd__deleted-banner">
        <Trash2 :size="16" :stroke-width="1.75" />
        <div><strong>Club eliminado</strong> — {{ formatDate(club.deleted_at) }}. Los usuarios no pueden acceder.</div>
        <button class="scd__btn-restore" :disabled="saving" @click="restaurar">
          <RotateCcw :size="13" :stroke-width="2" /> Restaurar
        </button>
      </div>

      <!-- ── Header ── -->
      <div class="scd__hero">
        <RouterLink :to="{ name: 'sa-dashboard' }" class="scd__back">
          <ArrowLeft :size="13" :stroke-width="2.5" /> Clubs
        </RouterLink>
        <div class="scd__hero-body">
          <div class="scd__avatar" :class="{ 'scd__avatar--deleted': club.deleted_at }">
            {{ club.name?.[0]?.toUpperCase() }}
          </div>
          <div class="scd__hero-text">
            <div class="scd__hero-name-row">
              <h1 class="scd__title">{{ club.name }}</h1>
              <span class="scd__plan-pill" :style="{ background: planMeta(club.plan).bg, color: planMeta(club.plan).color }">
                {{ planMeta(club.plan).label }}
              </span>
              <span v-if="club.plan_trial" class="scd__trial-pill">TRIAL</span>
            </div>
            <div class="scd__hero-meta">
              <span class="scd__mono">{{ club.slug }}</span>
              <span v-if="club.city" class="scd__meta-sep">·</span>
              <span v-if="club.city">{{ club.city }}<span v-if="club.state">, {{ club.state }}</span></span>
              <span class="scd__meta-sep">·</span>
              <span>Desde {{ formatDate(club.created_at) }}</span>
            </div>
          </div>
          <div class="scd__hero-stats">
            <div class="scd__hstat"><span class="scd__hstat-val">{{ club.usuarios_count }}</span><span class="scd__hstat-lbl">usuarios</span></div>
            <div class="scd__hstat"><span class="scd__hstat-val">{{ club.pacientes_count }}</span><span class="scd__hstat-lbl">socios</span></div>
            <div class="scd__hstat"><span class="scd__hstat-val">{{ club.lotes_count }}</span><span class="scd__hstat-lbl">lotes</span></div>
          </div>
          <div class="scd__hero-actions">
            <button class="scd__btn-sm scd__btn-secondary" @click="generarUsuarios" :disabled="saving">
              <Sparkles :size="13" :stroke-width="1.75" /> Generar usuarios
            </button>
            <button v-if="!club.deleted_at" class="scd__btn-sm scd__btn-danger" @click="eliminar" :disabled="saving">
              <Trash2 :size="13" :stroke-width="1.75" /> Eliminar
            </button>
          </div>
        </div>
      </div>

      <!-- ── Row 1: Info + Plan ── -->
      <div class="scd__row">

        <!-- Info -->
        <div class="scd__card scd__card--info">
          <div class="scd__card-hd">
            <Info :size="14" :stroke-width="1.75" class="scd__card-ico" /> Información
          </div>
          <dl class="scd__dl">
            <dt>Razón social</dt><dd>{{ club.legal_name || '—' }}</dd>
            <dt>Email</dt><dd>{{ club.email || '—' }}</dd>
            <dt>Teléfono</dt><dd>{{ club.phone || '—' }}</dd>
            <dt>Sitio web</dt><dd>{{ club.website || '—' }}</dd>
            <dt>Dirección</dt><dd>{{ [club.address, club.city, club.state, club.country].filter(Boolean).join(', ') || '—' }}</dd>
            <dt>Timezone</dt><dd>{{ club.timezone || '—' }}</dd>
          </dl>
        </div>

        <!-- Plan + Web -->
        <div class="scd__card-col">
          <div class="scd__card">
            <div class="scd__card-hd">
              <CreditCard :size="14" :stroke-width="1.75" class="scd__card-ico" /> Suscripción
              <button class="scd__link-btn" @click="abrirPlanModal"><Pencil :size="12" :stroke-width="2" /> Cambiar</button>
            </div>
            <div class="scd__plan-body">
              <span class="scd__plan-pill scd__plan-pill--lg" :style="{ background: planMeta(club.plan).bg, color: planMeta(club.plan).color }">
                {{ planMeta(club.plan).label }}
              </span>
              <span v-if="club.plan_trial" class="scd__trial-pill">TRIAL</span>
              <p class="scd__plan-until">
                {{ club.plan_activo_hasta ? `Vigente hasta ${formatDate(club.plan_activo_hasta)}` : 'Sin vencimiento' }}
              </p>
            </div>
          </div>
        </div>

      </div>

      <!-- ── Usuarios ── -->
      <div class="scd__card scd__card--users">
        <div class="scd__card-hd">
          <Users :size="14" :stroke-width="1.75" class="scd__card-ico" />
          Usuarios <span class="scd__count">{{ club.usuarios?.length || 0 }}</span>
          <button class="scd__btn-sm scd__btn-primary" @click="abrirUserModal" style="margin-left:auto">
            <UserPlus :size="13" :stroke-width="1.75" /> Crear
          </button>
        </div>
        <div v-if="!club.usuarios?.length" class="scd__empty">Sin usuarios creados</div>
        <div v-else class="scd__users">
          <div v-for="u in club.usuarios" :key="u.id" class="scd__user-row">
            <div class="scd__user-av">{{ (u.nombre?.[0] || u.email?.[0] || '?').toUpperCase() }}</div>
            <div class="scd__user-info">
              <div class="scd__user-name">{{ u.nombre || '—' }}</div>
              <div class="scd__user-email">{{ u.email }}</div>
            </div>
            <span class="scd__role-pill" :style="{ background: roleMeta(u.role).bg, color: roleMeta(u.role).color }">
              {{ roleMeta(u.role).label }}
            </span>
          </div>
        </div>
      </div>

      <!-- ── Funcionalidades ── -->
      <div class="scd__card">
        <div class="scd__card-hd">
          <Zap :size="14" :stroke-width="1.75" class="scd__card-ico scd__card-ico--purple" /> Funcionalidades
          <span v-if="featuresSuccess" class="scd__saved-badge"><Check :size="11" :stroke-width="3" /> Guardado</span>
          <button class="scd__btn-sm scd__btn-primary" :disabled="savingFeatures" @click="guardarFeatures" style="margin-left:auto">
            <span v-if="savingFeatures" class="scd__spinner"></span>
            <Save v-else :size="13" :stroke-width="1.75" />
            {{ savingFeatures ? 'Guardando…' : 'Guardar' }}
          </button>
        </div>
        <div class="scd__feat-body">
          <div class="scd__feat-grid">
            <label v-for="key in FEATURES_ORDER" :key="key" class="scd__feat-toggle" :class="{ 'scd__feat-toggle--on': featuresForm[key] }">
              <div class="scd__feat-left">
                <span class="scd__feat-ico">{{ FEATURE_META[key].icon }}</span>
                <div>
                  <div class="scd__feat-name">{{ FEATURE_META[key].label }}</div>
                  <div class="scd__feat-desc">{{ FEATURE_META[key].desc }}</div>
                </div>
              </div>
              <input v-model="featuresForm[key]" type="checkbox" class="scd__chk" />
              <div class="scd__track"><div class="scd__thumb"></div></div>
            </label>
          </div>

          <template v-if="iaActiva">
            <div class="scd__divider"><span>Configuración de IA</span></div>
            <div class="scd__ia-tiers">
              <button v-for="tier in IA_TIERS" :key="tier.value" type="button"
                class="scd__ia-tier"
                :class="{ 'scd__ia-tier--active': iaTier === tier.value }"
                :style="iaTier === tier.value ? { borderColor: tier.color, background: tier.color + '12', color: tier.color } : {}"
                @click="iaTier = tier.value; iaLimiteHora = [20,60,200][IA_TIERS.findIndex(t=>t.value===tier.value)]"
              >
                <strong>{{ tier.label }}</strong><span>{{ tier.desc }}</span>
              </button>
            </div>
            <div class="scd__ia-limit">
              <label class="scd__lbl">Límite llamadas/hora</label>
              <input v-model.number="iaLimiteHora" type="number" min="1" max="500" class="scd__input scd__input--sm" />
              <span class="scd__hint">Sobreescribe el límite del tier.</span>
            </div>
          </template>
        </div>
      </div>

      <!-- ── SMTP ── -->
      <div class="scd__card">
        <div class="scd__card-hd">
          <Mail :size="14" :stroke-width="1.75" class="scd__card-ico scd__card-ico--orange" /> Correo saliente (SMTP)
          <span v-if="club.smtp_configured" class="scd__ok-badge">Configurado</span>
          <span v-else class="scd__warn-badge">Sin configurar</span>
          <span v-if="smtpSuccess" class="scd__saved-badge" style="margin-left:.5rem"><Check :size="11" :stroke-width="3" /> Guardado</span>
        </div>
        <form class="scd__smtp-body" @submit.prevent="guardarSmtp">
          <div v-if="smtpError" class="scd__alert">{{ smtpError }}</div>
          <div class="scd__smtp-grid">
            <div class="scd__field">
              <label class="scd__lbl">Nombre remitente</label>
              <input v-model.trim="smtpForm.smtp_from_name" class="scd__input" placeholder="Club Medicinal del Sur" />
            </div>
            <div class="scd__field">
              <label class="scd__lbl">Email remitente</label>
              <input v-model.trim="smtpForm.smtp_from" type="email" class="scd__input" placeholder="no-reply@clubmedicinal.org" />
              <span class="scd__hint">Vacío = usa el usuario SMTP</span>
            </div>
            <div class="scd__field">
              <label class="scd__lbl">Host SMTP</label>
              <input v-model.trim="smtpForm.smtp_host" class="scd__input" placeholder="smtp.gmail.com" />
            </div>
            <div class="scd__field">
              <label class="scd__lbl">Puerto</label>
              <input v-model.number="smtpForm.smtp_port" type="number" class="scd__input" placeholder="587" />
              <span class="scd__hint">587 TLS · 465 SSL</span>
            </div>
            <div class="scd__field">
              <label class="scd__lbl">Usuario SMTP</label>
              <input v-model.trim="smtpForm.smtp_user" class="scd__input" placeholder="correo@gmail.com" />
            </div>
            <div class="scd__field">
              <label class="scd__lbl">Contraseña SMTP</label>
              <input v-model="smtpForm.smtp_pass" type="password" class="scd__input" placeholder="Dejá vacío para no cambiar" autocomplete="new-password" />
              <span class="scd__hint">Gmail: usá una App Password</span>
            </div>
          </div>
          <div class="scd__smtp-footer">
            <button type="submit" class="scd__btn-sm scd__btn-primary" :disabled="savingSmtp">
              <span v-if="savingSmtp" class="scd__spinner"></span>
              <Save v-else :size="13" :stroke-width="1.75" />
              {{ savingSmtp ? 'Guardando…' : 'Guardar SMTP' }}
            </button>
          </div>
        </form>
      </div>

      <!-- ── Modal plan ── -->
      <Teleport to="body">
        <div v-if="showPlanModal" class="scd__overlay" @click.self="showPlanModal = false">
          <div class="scd__modal">
            <div class="scd__modal-hd">
              <span class="scd__modal-title">Cambiar plan — {{ club.name }}</span>
              <button class="scd__modal-close" @click="showPlanModal = false"><X :size="16" :stroke-width="2" /></button>
            </div>
            <div class="scd__modal-body">
              <div v-if="error" class="scd__alert">{{ error }}</div>
              <label class="scd__lbl" style="margin-bottom:.5rem">Plan</label>
              <div class="scd__planes">
                <button v-for="p in PLANES" :key="p.value" type="button"
                  class="scd__plan-opt"
                  :class="{ 'scd__plan-opt--active': planForm.plan === p.value }"
                  :style="planForm.plan === p.value ? { borderColor: p.color, background: p.bg, color: p.color } : {}"
                  @click="planForm.plan = p.value">
                  {{ p.label }}
                </button>
              </div>
              <div class="scd__field" style="margin-top:1rem">
                <label class="scd__lbl">Vigente hasta</label>
                <input v-model="planForm.plan_activo_hasta" type="date" class="scd__input" />
                <span class="scd__hint">Vacío = sin vencimiento</span>
              </div>
              <label class="scd__toggle-row" style="margin-top:.875rem">
                <input v-model="planForm.trial" type="checkbox" class="scd__chk" />
                <div class="scd__track"><div class="scd__thumb"></div></div>
                <span class="scd__toggle-lbl">Período de prueba (trial)</span>
              </label>
            </div>
            <div class="scd__modal-ft">
              <button class="scd__btn-ghost" @click="showPlanModal = false">Cancelar</button>
              <button class="scd__btn-primary" :disabled="saving" @click="guardarPlan">
                <span v-if="saving" class="scd__spinner"></span>
                <Check v-else :size="14" :stroke-width="2.5" />
                Guardar
              </button>
            </div>
          </div>
        </div>
      </Teleport>

      <!-- ── Modal usuario ── -->
      <Teleport to="body">
        <div v-if="showUserModal" class="scd__overlay" @click.self="showUserModal = false">
          <div class="scd__modal">
            <div class="scd__modal-hd">
              <span class="scd__modal-title">Nuevo usuario — {{ club.name }}</span>
              <button class="scd__modal-close" @click="showUserModal = false"><X :size="16" :stroke-width="2" /></button>
            </div>
            <div class="scd__modal-body">
              <div v-if="userError" class="scd__alert">{{ userError }}</div>
              <div class="scd__grid">
                <div class="scd__field">
                  <label class="scd__lbl">Nombre</label>
                  <input v-model.trim="userForm.first_name" class="scd__input" placeholder="Juan" autofocus />
                </div>
                <div class="scd__field">
                  <label class="scd__lbl">Apellido</label>
                  <input v-model.trim="userForm.last_name" class="scd__input" placeholder="García" />
                </div>
                <div class="scd__field scd__field--full">
                  <label class="scd__lbl">Email <span style="color:#dc2626">*</span></label>
                  <input v-model.trim="userForm.email" type="email" class="scd__input" placeholder="juan@club.com" />
                </div>
                <div class="scd__field">
                  <label class="scd__lbl">Contraseña inicial</label>
                  <input v-model="userForm.password" type="password" autocomplete="new-password" class="scd__input" />
                </div>
                <div class="scd__field">
                  <label class="scd__lbl">Rol</label>
                  <select v-model="userForm.role" class="scd__input">
                    <option v-for="r in ROLES" :key="r" :value="r">{{ roleMeta(r).label }}</option>
                  </select>
                </div>
              </div>
            </div>
            <div class="scd__modal-ft">
              <button class="scd__btn-ghost" @click="showUserModal = false">Cancelar</button>
              <button class="scd__btn-primary" :disabled="saving" @click="crearUsuario">
                <span v-if="saving" class="scd__spinner"></span>
                <UserPlus v-else :size="14" :stroke-width="1.75" />
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
.scd { padding: 2rem 2.5rem 3rem; max-width: 1100px; margin: 0 auto; display: flex; flex-direction: column; gap: 1rem; }
/* Loading */
.scd__loading { display: flex; justify-content: center; padding: 5rem; }
.scd__ring { width: 24px; height: 24px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: spin .7s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

/* Deleted banner */
.scd__deleted-banner {
  display: flex; align-items: center; gap: .875rem; flex-wrap: wrap;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 12px;
  padding: .875rem 1.1rem; font-size: .82rem; color: #991b1b;
}
.scd__deleted-banner > div { flex: 1; }
.scd__btn-restore {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #fff; color: #991b1b; border: 1.5px solid #fca5a5;
  padding: .4rem .85rem; border-radius: 8px; font-size: .78rem; font-weight: 600;
  cursor: pointer; transition: background .15s; white-space: nowrap;
}
.scd__btn-restore:hover:not(:disabled) { background: #fef2f2; }
.scd__btn-restore:disabled { opacity: .5; cursor: not-allowed; }

/* Hero header */
.scd__hero {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 16px;
  overflow: hidden;
}
.scd__back {
  display: inline-flex; align-items: center; gap: .35rem;
  font-size: .75rem; font-weight: 600; color: #94a3b8;
  text-decoration: none; padding: .75rem 1.25rem;
  border-bottom: 1px solid #f1f5f9;
  transition: color .15s; width: 100%; box-sizing: border-box;
}
.scd__back:hover { color: #0f172a; background: #fafbfc; }
.scd__hero-body {
  display: flex; align-items: center; gap: 1.25rem;
  padding: 1.25rem 1.5rem; flex-wrap: wrap;
}
.scd__avatar {
  width: 52px; height: 52px; border-radius: 14px; flex-shrink: 0;
  background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.12));
  color: #1b5e20; font-size: 1.2rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
}
.scd__avatar--deleted { background: #f1f5f9; color: #94a3b8; }
.scd__hero-text { flex: 1; min-width: 0; }
.scd__hero-name-row { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .3rem; }
.scd__title { font-size: 1.5rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.035em; }
.scd__hero-meta { font-size: .75rem; color: #94a3b8; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.scd__mono { font-family: monospace; font-size: .72rem; }
.scd__meta-sep { color: #d1d5db; }

.scd__hero-stats {
  display: flex; gap: 0; border: 1px solid #e2e8f0; border-radius: 10px;
  overflow: hidden; flex-shrink: 0;
}
.scd__hstat { padding: .6rem 1rem; text-align: center; border-right: 1px solid #e2e8f0; }
.scd__hstat:last-child { border-right: none; }
.scd__hstat-val { display: block; font-size: 1.15rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; line-height: 1; }
.scd__hstat-lbl { display: block; font-size: .62rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; margin-top: .2rem; }

.scd__hero-actions { display: flex; gap: .5rem; flex-shrink: 0; }

/* Plan + trial pills */
.scd__plan-pill { font-size: .72rem; font-weight: 800; padding: .2em .7em; border-radius: 7px; }
.scd__trial-pill { font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; background: #fffbeb; color: #b45309; padding: .2em .6em; border-radius: 6px; }

/* Row layout */
.scd__row { display: grid; grid-template-columns: 1fr 320px; gap: 1rem; align-items: start; }
@media (max-width: 900px) { .scd__row { grid-template-columns: 1fr; } }

/* Cards */
.scd__card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
  overflow: hidden;
}
.scd__card-col { display: flex; flex-direction: column; gap: 1rem; }
.scd__card-hd {
  display: flex; align-items: center; gap: .5rem;
  padding: .75rem 1.1rem; border-bottom: 1px solid #f1f5f9;
  background: #fafbfc; font-size: .82rem; font-weight: 700; color: #0f172a;
  min-height: 44px;
}
.scd__card-ico { color: #1b5e20; flex-shrink: 0; }
.scd__card-ico--purple { color: #7c3aed; }
.scd__card-ico--orange { color: #ea580c; }
.scd__count { font-size: .72rem; font-weight: 700; background: #f1f5f9; color: #64748b; padding: .1em .55em; border-radius: 6px; }
.scd__link-btn {
  display: inline-flex; align-items: center; gap: .3rem;
  margin-left: auto; font-size: .72rem; font-weight: 600; color: #0369a1;
  background: none; border: none; cursor: pointer; padding: 0;
}
.scd__link-btn:hover { text-decoration: underline; }

/* Info card */
.scd__dl { display: grid; grid-template-columns: 100px 1fr; gap: .4rem .75rem; padding: 1rem 1.1rem; margin: 0; }
.scd__dl dt { font-size: .72rem; color: #94a3b8; font-weight: 500; }
.scd__dl dd { font-size: .8rem; color: #0f172a; font-weight: 500; margin: 0; }

/* Plan card */
.scd__plan-pill--lg { font-size: .85rem; padding: .3em .9em; }
.scd__plan-body { padding: 1rem 1.1rem; display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.scd__plan-until { font-size: .72rem; color: #94a3b8; width: 100%; margin: .25rem 0 0; }

/* Web card */
.scd__web-card { }
.scd__web-body { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; gap: 1rem; }
.scd__web-status { font-size: .82rem; font-weight: 700; color: #94a3b8; margin-bottom: .15rem; }
.scd__web-status--on { color: #15803d; }
.scd__web-toggle {
  width: 44px; height: 24px; border-radius: 12px; background: #e2e8f0;
  border: none; cursor: pointer; position: relative; transition: background .2s; padding: 0; flex-shrink: 0;
}
.scd__web-toggle--on { background: #1b5e20; }
.scd__web-toggle:disabled { opacity: .5; cursor: not-allowed; }
.scd__web-thumb {
  position: absolute; top: 2px; left: 2px; width: 20px; height: 20px;
  border-radius: 50%; background: #fff; transition: transform .2s;
  display: block; box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.scd__web-toggle--on .scd__web-thumb { transform: translateX(20px); }

/* Users */
.scd__card--users { }
.scd__empty { padding: 2rem; text-align: center; color: #94a3b8; font-size: .82rem; }
.scd__users { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px,1fr)); gap: 0; }
.scd__user-row { display: flex; align-items: center; gap: .65rem; padding: .65rem 1.1rem; border-bottom: 1px solid #f8fafc; }
.scd__user-row:last-child { border-bottom: none; }
.scd__user-av { width: 30px; height: 30px; border-radius: 50%; background: #f1f5f9; color: #475569; font-size: .72rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.scd__user-info { flex: 1; min-width: 0; }
.scd__user-name  { font-size: .8rem; font-weight: 600; color: #0f172a; }
.scd__user-email { font-size: .68rem; color: #94a3b8; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.scd__role-pill { font-size: .65rem; font-weight: 700; padding: .18em .55em; border-radius: 5px; white-space: nowrap; flex-shrink: 0; }

/* Features */
.scd__feat-body { padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.scd__feat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px,1fr)); gap: .4rem; }
.scd__feat-toggle {
  display: flex; align-items: center; gap: .65rem; padding: .65rem .875rem;
  border-radius: 10px; border: 1.5px solid #e2e8f0; background: #f8fafc;
  cursor: pointer; transition: border-color .15s, background .15s; user-select: none;
}
.scd__feat-toggle--on { border-color: #bbf7d0; background: #f0fdf4; }
.scd__feat-left { display: flex; align-items: center; gap: .55rem; flex: 1; min-width: 0; }
.scd__feat-ico  { font-size: .9rem; flex-shrink: 0; }
.scd__feat-name { font-size: .78rem; font-weight: 700; color: #0f172a; }
.scd__feat-desc { font-size: .68rem; color: #94a3b8; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.scd__divider {
  display: flex; align-items: center; gap: .75rem;
  color: #94a3b8; font-size: .68rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: .06em;
}
.scd__divider::before, .scd__divider::after { content: ''; flex: 1; height: 1px; background: #e2e8f0; }
.scd__ia-tiers { display: flex; flex-direction: column; gap: .4rem; }
.scd__ia-tier {
  display: flex; flex-direction: column; gap: .1rem; align-items: flex-start;
  padding: .6rem .875rem; border-radius: 8px; border: 1.5px solid #e2e8f0;
  background: #f8fafc; cursor: pointer; text-align: left; transition: all .15s;
}
.scd__ia-tier strong { font-size: .82rem; }
.scd__ia-tier span   { font-size: .7rem; color: #64748b; }
.scd__ia-tier--active span { color: inherit; opacity: .8; }
.scd__ia-tier:hover { border-color: #94a3b8; }
.scd__ia-limit { display: flex; flex-direction: column; gap: .3rem; max-width: 200px; }

/* Toggle (checkbox) */
.scd__chk { display: none; }
.scd__track { width: 34px; height: 19px; background: #cbd5e1; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.scd__chk:checked + .scd__track { background: #1b5e20; }
.scd__thumb { position: absolute; width: 13px; height: 13px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 2px rgba(0,0,0,.2); }
.scd__chk:checked + .scd__track .scd__thumb { left: 18px; }

/* Toggle row (for modals) */
.scd__toggle-row { display: flex; align-items: center; gap: .75rem; cursor: pointer; padding: .75rem; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; }
.scd__toggle-lbl { font-size: .875rem; font-weight: 600; color: #0f172a; }

/* SMTP */
.scd__smtp-body { padding: 1.25rem 1.4rem; }
.scd__smtp-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 1rem; }
@media (max-width: 900px) { .scd__smtp-grid { grid-template-columns: 1fr 1fr; } }
@media (max-width: 580px) { .scd__smtp-grid { grid-template-columns: 1fr; } }
.scd__smtp-footer { display: flex; justify-content: flex-end; margin-top: 1rem; }

/* Badges */
.scd__ok-badge   { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; background: #dcfce7; color: #15803d; padding: .2em .65em; border-radius: 6px; }
.scd__warn-badge { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; background: #fef3c7; color: #b45309; padding: .2em .65em; border-radius: 6px; }
.scd__saved-badge { display: inline-flex; align-items: center; gap: .25rem; font-size: .65rem; font-weight: 700; background: #dcfce7; color: #15803d; padding: .2em .65em; border-radius: 6px; }

/* Form primitives */
.scd__field { display: flex; flex-direction: column; gap: .3rem; }
.scd__field--full { grid-column: 1 / -1; }
.scd__lbl { font-size: .7rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.scd__hint { font-size: .7rem; color: #94a3b8; }
.scd__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: .55rem .875rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s;
}
.scd__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); background: #fff; }
.scd__input--sm { width: 100%; }
.scd__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 8px; font-size: .82rem; }
.scd__grid { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; }

/* Buttons */
.scd__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .5rem .95rem; border-radius: 8px; font-size: .78rem; font-weight: 700;
  cursor: pointer; transition: background .15s; white-space: nowrap;
}
.scd__btn-primary:hover:not(:disabled) { background: #166534; }
.scd__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-secondary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #fff; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .5rem .875rem; border-radius: 8px; font-size: .78rem; font-weight: 600;
  cursor: pointer; transition: all .15s; white-space: nowrap;
}
.scd__btn-secondary:hover:not(:disabled) { background: #f8fafc; border-color: #94a3b8; }
.scd__btn-secondary:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-danger {
  display: inline-flex; align-items: center; gap: .4rem;
  background: transparent; color: #b91c1c; border: 1.5px solid #fca5a5;
  padding: .5rem .875rem; border-radius: 8px; font-size: .78rem; font-weight: 600;
  cursor: pointer; transition: all .15s; white-space: nowrap;
}
.scd__btn-danger:hover:not(:disabled) { background: #fef2f2; }
.scd__btn-danger:disabled { opacity: .6; cursor: not-allowed; }
.scd__btn-sm { /* size set inline via btn variant */ }
.scd__btn-ghost {
  background: transparent; color: #64748b; border: 1.5px solid #e2e8f0;
  padding: .55rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer;
  display: inline-flex; align-items: center; gap: .4rem;
}
.scd__btn-ghost:hover { background: #f8fafc; }
.scd__spinner { width: 13px; height: 13px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: spin .6s linear infinite; }

/* Modals */
.scd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(4px); }
.scd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.scd__modal-hd { display: flex; align-items: center; justify-content: space-between; padding: 1.1rem 1.35rem .9rem; border-bottom: 1px solid #f1f5f9; }
.scd__modal-title { font-size: .95rem; font-weight: 800; color: #0f172a; }
.scd__modal-close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.scd__modal-close:hover { background: #e2e8f0; }
.scd__modal-body { padding: 1.1rem 1.35rem; display: flex; flex-direction: column; gap: .875rem; }
.scd__modal-ft { display: flex; justify-content: flex-end; gap: .65rem; padding: .875rem 1.35rem; border-top: 1px solid #f1f5f9; }
.scd__planes { display: grid; grid-template-columns: repeat(2,1fr); gap: .4rem; }
.scd__plan-opt { padding: .55rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; background: #f8fafc; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; text-align: left; color: #475569; }
.scd__plan-opt:hover { border-color: #94a3b8; }
</style>
