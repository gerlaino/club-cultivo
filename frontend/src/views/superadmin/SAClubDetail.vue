<script setup>
import { ref, computed, onMounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import { useRoute, useRouter } from 'vue-router'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { getSuperAdminClub, cambiarPlanClub, crearUsuariosDefault, createSuperAdminUser, updateSuperAdminClub, eliminarClub, restaurarClub, suspenderClub, reactivarClub, getSuperAdminCatalogo, getHistorialClub } from '../../lib/api.js'
import { useConfirm } from '../../composables/useConfirm.js'
import { useToast } from '../../composables/useToast.js'
import SAModulos from './SAModulos.vue'
import { ArrowLeft, Pencil, Trash2, RotateCcw, Sparkles, UserPlus, Check, X, Users, Info, CreditCard, PauseCircle, PlayCircle, History } from 'lucide-vue-next'

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
const userForm = ref({ first_name: '', last_name: '', email: '', email_personal: '', password: '123456Aa', role: 'cultivador' })
const userError = ref(null)

const editingInfo  = ref(false)
const infoForm     = ref({})
const savingInfo   = ref(false)
const infoError    = ref(null)

function abrirEditInfo() {
  infoForm.value = {
    name:       club.value.name       || '',
    legal_name: club.value.legal_name || '',
    email:      club.value.email      || '',
    phone:      club.value.phone      || '',
    website:    club.value.website    || '',
    address:    club.value.address    || '',
    city:       club.value.city       || '',
    state:      club.value.state      || '',
    country:    club.value.country    || '',
    timezone:   club.value.timezone   || '',
  }
  infoError.value   = null
  editingInfo.value = true
}

async function guardarInfo() {
  if (!infoForm.value.name?.trim()) { infoError.value = 'El nombre es obligatorio'; return }
  savingInfo.value = true
  infoError.value  = null
  try {
    const { data } = await updateSuperAdminClub(id, infoForm.value)
    club.value = { ...club.value, ...data }
    editingInfo.value = false
    toast.success('Información actualizada')
  } catch (e) {
    infoError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally {
    savingInfo.value = false
  }
}

// Qué tiene contratado hoy, para el resumen de la tarjeta de Suscripción. Los interruptores y
// su configuración viven en <SAModulos>: acá sólo se lee lo que ya está guardado.
const suitesActivas = computed(() =>
  (club.value?.suites || []).filter(s => club.value?.features?.[s.clave] === true)
)
const addonsActivos = computed(() =>
  (club.value?.addons || []).filter(a => club.value?.features?.[a.clave] === true)
)

// El componente de módulos devuelve la organización entera ya recalculada por el backend
// (prendido ≠ andando), así que se reemplaza y no se hace merge: un merge dejaría vivos los
// `estado` viejos de la respuesta anterior.
function onModulosActualizados(data) {
  club.value = { ...club.value, ...data }
}

// ── Historial ──────────────────────────────────────────────────────────
// A pedido, no al cargar: son hasta 100 registros y sólo se miran cuando hay una discusión.
const historial = ref(null)

const ACCION_LABEL = { crear: 'Alta', actualizar: 'Cambio', eliminar: 'Baja' }

// Los campos del club en el idioma en que se habla de ellos, no el de la columna.
const CAMPO_LABEL = {
  plan: 'plan', plan_activo_hasta: 'vigencia', plan_trial: 'período de prueba',
  features: 'módulos', activo: 'estado', deleted_at: 'baja', name: 'nombre',
  legal_name: 'razón social', email: 'email', slug: 'slug', demo: 'club demo',
  ia_tier: 'nivel de IA', ia_limite_hora: 'límite de IA', vista_paciente_activa: 'web pública',
}

function resumirCambios(cambios) {
  if (!cambios) return ''
  return Object.keys(cambios).map(k => CAMPO_LABEL[k] || k).join(', ')
}

async function cargarHistorial() {
  const { data } = await getHistorialClub(id)
  historial.value = data
}

function formatDateTime(f) {
  if (!f) return '—'
  return new Date(f).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })
}

// Dos planes: el plan dice CUÁNTO, nunca QUÉ. Los límites salen del catálogo del backend —
// duplicarlos acá era garantía de que la pantalla dijera un número y el sistema aplicara otro.
const PLAN_META = {
  basico: { label: 'Básico', color: '#15803d', bg: '#dcfce7' },
  total:  { label: 'Total',  color: '#7c3aed', bg: '#ede9fe' },
}
const PLANES = ref([])
function planMeta(p) { return PLAN_META[p] || PLAN_META.basico }

// Mismos roles que ofrece el alta del club y que acepta el backend (Club::ROLES_ALTA + delivery).
const ROLES = ['admin', 'medico', 'cultivador', 'dispensador', 'manicura', 'delivery']
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
    // Todo lo de módulos (suites, add-ons, incluidos, bajas, IA, Twilio, Pulse) sale de acá y
    // lo consume <SAModulos> por prop: antes se copiaba a ocho refs locales que había que
    // volver a sincronizar a mano después de cada guardado.
    club.value = data
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
  userForm.value = { first_name: '', last_name: '', email: '', email_personal: '', password: '123456Aa', role: 'cultivador' }
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


// Dar de baja: el club deja de operar pero sigue entero y en la lista. Es lo que se hace
// cuando dejan de pagar o se toman una pausa — reversible sin consecuencias.
async function suspender() {
  const ok = await confirm({
    title: `Suspender ${club.value.name}`,
    message: 'Sus usuarios no van a poder entrar hasta que lo reactives. No se borra ni se cambia nada: el club queda tal cual está.',
    confirmText: 'Suspender club',
    variant: 'danger',
  })
  if (!ok) return
  saving.value = true
  try {
    const { data } = await suspenderClub(id)
    club.value = data
    toast.success('Club suspendido')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al suspender')
  } finally {
    saving.value = false
  }
}

async function reactivar() {
  saving.value = true
  try {
    const { data } = await reactivarClub(id)
    club.value = data
    toast.success('Club reactivado')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al reactivar')
  } finally {
    saving.value = false
  }
}

async function eliminar() {
  const ok = await confirm({
    title: `Eliminar ${club.value.name}`,
    message: 'El club sale de la lista y se liberan su nombre, los emails de sus usuarios y los DNI de sus pacientes, para que puedan volver a usarse. Los datos no se borran: se puede restaurar mientras nadie haya tomado esos identificadores.',
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

onMounted(async () => {
  await cargar()
  // Los planes con sus límites salen del backend, para que el modal muestre exactamente los
  // topes que después se aplican.
  try {
    const { data } = await getSuperAdminCatalogo()
    PLANES.value = (data.planes || []).map(p => ({ value: p.clave, ...planMeta(p.clave), ...p }))
  } catch { /* el modal cae a los dos planes conocidos si el catálogo no responde */ }
})
</script>

<template>
  <div class="scd">

    <div v-if="loading" class="scd__loading"><DsSpinner /></div>

    <template v-else-if="club">

      <!-- Banner eliminado -->
      <div v-if="club.deleted_at" class="scd__deleted-banner">
        <Trash2 :size="16" :stroke-width="1.75" />
        <div>
          <strong>Organización eliminada</strong> — {{ formatDate(club.deleted_at) }}.
          Su nombre, los emails de sus usuarios y los DNI de sus pacientes quedaron libres.
        </div>
        <button class="scd__btn-restore" :disabled="saving" @click="restaurar">
          <RotateCcw :size="13" :stroke-width="2" /> Restaurar
        </button>
      </div>

      <!-- Banner suspendido -->
      <div v-else-if="club.activo === false" class="scd__susp-banner">
        <PauseCircle :size="16" :stroke-width="1.75" />
        <div><strong>Organización suspendida</strong> — sus usuarios no pueden iniciar sesión. Los datos están intactos.</div>
        <button class="scd__btn-restore" :disabled="saving" @click="reactivar">
          <PlayCircle :size="13" :stroke-width="2" /> Reactivar
        </button>
      </div>

      <!-- ── Header ── -->
      <div class="scd__hero">
        <RouterLink :to="{ name: 'sa-dashboard' }" class="scd__back">
          <ArrowLeft :size="13" :stroke-width="2.5" /> Organizaciones
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
            <!-- Dos acciones distintas, no una: suspender pausa, eliminar libera. -->
            <template v-if="!club.deleted_at">
              <button v-if="club.activo !== false" class="scd__btn-sm scd__btn-secondary" @click="suspender" :disabled="saving">
                <PauseCircle :size="13" :stroke-width="1.75" /> Suspender
              </button>
              <button v-else class="scd__btn-sm scd__btn-secondary" @click="reactivar" :disabled="saving">
                <PlayCircle :size="13" :stroke-width="1.75" /> Reactivar
              </button>
              <button class="scd__btn-sm scd__btn-danger" @click="eliminar" :disabled="saving">
                <Trash2 :size="13" :stroke-width="1.75" /> Eliminar
              </button>
            </template>
          </div>
        </div>
      </div>

      <!-- ── Row 1: Info + Plan ── -->
      <div class="scd__row">

        <!-- Info -->
        <div class="scd__card scd__card--info">
          <div class="scd__card-hd">
            <Info :size="14" :stroke-width="1.75" class="scd__card-ico" /> Información
            <button v-if="!editingInfo" class="scd__link-btn" @click="abrirEditInfo">
              <Pencil :size="12" :stroke-width="2" /> Editar
            </button>
          </div>

          <!-- Vista -->
          <dl v-if="!editingInfo" class="scd__dl">
            <dt>Nombre</dt><dd>{{ club.name || '—' }}</dd>
            <dt>Razón social</dt><dd>{{ club.legal_name || '—' }}</dd>
            <dt>Email</dt><dd>{{ club.email || '—' }}</dd>
            <dt>Teléfono</dt><dd>{{ club.phone || '—' }}</dd>
            <dt>Sitio web</dt><dd>{{ club.website || '—' }}</dd>
            <dt>Dirección</dt><dd>{{ [club.address, club.city, club.state, club.country].filter(Boolean).join(', ') || '—' }}</dd>
            <dt>Timezone</dt><dd>{{ club.timezone || '—' }}</dd>
          </dl>

          <!-- Edición inline -->
          <div v-else class="scd__info-form">
            <div v-if="infoError" class="scd__alert">{{ infoError }}</div>
            <div class="scd__info-grid">
              <div class="scd__field scd__field--full">
                <label class="scd__lbl">Nombre de la organización <span style="color:#dc2626">*</span></label>
                <input v-model.trim="infoForm.name" class="scd__input" placeholder="Club Cannábico del Sur" autofocus />
              </div>
              <div class="scd__field scd__field--full">
                <label class="scd__lbl">Razón social</label>
                <input v-model.trim="infoForm.legal_name" class="scd__input" placeholder="Asociación Civil Club Cannábico del Sur" />
              </div>
              <div class="scd__field">
                <label class="scd__lbl">Email</label>
                <input v-model.trim="infoForm.email" type="email" class="scd__input" placeholder="contacto@club.org" />
              </div>
              <div class="scd__field">
                <label class="scd__lbl">Teléfono</label>
                <input v-model.trim="infoForm.phone" class="scd__input" placeholder="+54 11 1234-5678" />
              </div>
              <div class="scd__field scd__field--full">
                <label class="scd__lbl">Sitio web</label>
                <input v-model.trim="infoForm.website" class="scd__input" placeholder="https://club.org" />
              </div>
              <div class="scd__field scd__field--full">
                <label class="scd__lbl">Dirección</label>
                <input v-model.trim="infoForm.address" class="scd__input" placeholder="Av. Corrientes 1234" />
              </div>
              <div class="scd__field">
                <label class="scd__lbl">Ciudad</label>
                <input v-model.trim="infoForm.city" class="scd__input" placeholder="Buenos Aires" />
              </div>
              <div class="scd__field">
                <label class="scd__lbl">Provincia / Estado</label>
                <input v-model.trim="infoForm.state" class="scd__input" placeholder="CABA" />
              </div>
              <div class="scd__field">
                <label class="scd__lbl">País</label>
                <input v-model.trim="infoForm.country" class="scd__input" placeholder="Argentina" />
              </div>
              <div class="scd__field">
                <label class="scd__lbl">Timezone</label>
                <input v-model.trim="infoForm.timezone" class="scd__input" placeholder="America/Argentina/Buenos_Aires" />
              </div>
            </div>
            <div class="scd__info-footer">
              <button class="scd__btn-ghost" :disabled="savingInfo" @click="editingInfo = false">Cancelar</button>
              <button class="scd__btn-primary" :disabled="savingInfo" @click="guardarInfo">
                <DsSpinner v-if="savingInfo" :size="13" />
                <Check v-else :size="14" :stroke-width="2.5" />
                {{ savingInfo ? 'Guardando…' : 'Guardar' }}
              </button>
            </div>
          </div>
        </div>

        <!-- Plan + Web -->
        <div class="scd__card-col">
          <div class="scd__card">
            <div class="scd__card-hd">
              <CreditCard :size="14" :stroke-width="1.75" class="scd__card-ico" /> Suscripción
              <button class="scd__link-btn" @click="abrirPlanModal"><Pencil :size="12" :stroke-width="2" /> Vigencia</button>
            </div>
            <!-- Lo que contrató son las SUITES, no un plan de una tabla vieja
                 (Semilla/Brote/Cosecha/Federación). Se activan en Funcionalidades. -->
            <div class="scd__plan-body">
              <div class="scd__susc-suites">
                <span v-for="s in suitesActivas" :key="s.clave"
                      class="scd__plan-pill scd__plan-pill--lg scd__susc-pill">
                  {{ s.label }}
                </span>
                <span v-if="!suitesActivas.length" class="scd__plan-pill scd__plan-pill--lg scd__susc-pill--none">
                  Sin suites contratadas
                </span>
              </div>
              <p v-if="addonsActivos.length" class="scd__susc-addons">
                + {{ addonsActivos.length }} módulo{{ addonsActivos.length === 1 ? '' : 's' }}:
                {{ addonsActivos.map(a => a.label).join(', ') }}
              </p>
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

      <!-- ── Módulos ──
           La sección vive en su propio componente y cada interruptor se guarda solo: acá había
           un "Guardar" arriba de todo que se perdía de vista al bajar, así que se tildaban tres
           módulos, se cambiaba de pestaña y no se había guardado ninguno. -->
      <div class="scd__card">
        <SAModulos :club="club" @actualizado="onModulosActualizados" />
      </div>

      <!-- Qué le hicimos NOSOTROS a este club. Es lo primero que se pregunta cuando reclaman
           "yo no pedí que me cambien el plan": hasta ahora no había forma de saberlo. -->
      <div class="scd__card">
        <div class="scd__card-hd">
          <History :size="14" :stroke-width="1.75" class="scd__card-ico" />
          Historial
          <button v-if="!historial" class="scd__btn-sm" style="margin-left:auto" @click="cargarHistorial">
            Ver historial
          </button>
        </div>
        <template v-if="historial">
          <div v-if="!historial.length" class="scd__empty">
            Todavía no se registró ningún cambio sobre este club.
          </div>
          <ul v-else class="scd__hist">
            <li v-for="h in historial" :key="h.id" class="scd__hist-item">
              <span class="scd__hist-fecha">{{ formatDateTime(h.fecha) }}</span>
              <span class="scd__hist-accion" :class="`scd__hist-accion--${h.accion}`">{{ ACCION_LABEL[h.accion] || h.accion }}</span>
              <span class="scd__hist-cambios">{{ resumirCambios(h.cambios) }}</span>
              <span class="scd__hist-quien">{{ h.usuario?.nombre || h.usuario?.email || 'sistema' }}</span>
            </li>
          </ul>
        </template>
      </div>

      <!-- El correo lo configura el ADMIN del club (conecta su Gmail), no el super_admin. -->

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
                  <strong class="scd__plan-opt-name">{{ p.label }}</strong>
                  <!-- Los topes a la vista: elegir un plan sin verlos es elegir a ciegas. -->
                  <span v-if="p.resumen" class="scd__plan-opt-limites">{{ p.resumen.join(' · ') }}</span>
                </button>
              </div>
              <!-- Lo que el club ya tiene, para saber si el plan nuevo le queda chico. -->
              <p v-if="club.plan_info" class="scd__hint" style="margin-top:.5rem">
                Hoy usa:
                {{ club.plan_info.uso.sedes }} sedes ·
                {{ club.plan_info.uso.salas }} salas ·
                {{ club.plan_info.uso.lotes }} lotes ·
                {{ club.plan_info.uso.plantas }} plantas ·
                {{ club.plan_info.uso.pacientes }} pacientes ·
                {{ club.plan_info.uso.usuarios }} usuarios
              </p>
              <div class="scd__field" style="margin-top:1rem">
                <label class="scd__lbl">Vigente hasta</label>
                <AppDatePicker v-model="planForm.plan_activo_hasta" />
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
                <DsSpinner v-if="saving" :size="13" />
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
                <!-- Dos cosas distintas, que este modal confundía en un solo campo: `email` es
                     el IDENTIFICADOR DE LOGIN (puede ser inventado) y `email_personal` es el
                     mail real de la persona. La pantalla de usuarios del club ya los separaba;
                     acá seguía pidiendo "Email" a secas y lo guardaba como login, así que el
                     mail real quedaba sin cargar y los avisos rebotaban. -->
                <div class="scd__field scd__field--full">
                  <label class="scd__lbl">Usuario de ingreso <span style="color:#dc2626">*</span></label>
                  <input v-model.trim="userForm.email" type="email" class="scd__input"
                         placeholder="rol@nombreorganizacion.com" autocomplete="off" />
                  <span class="scd__hint">Es con lo que se loguea. Puede ser inventado: no necesita ser un mail real.</span>
                </div>
                <div class="scd__field scd__field--full">
                  <label class="scd__lbl">Email personal <span style="font-weight:400;color:#94a3b8">(opcional)</span></label>
                  <input v-model.trim="userForm.email_personal" type="email" class="scd__input"
                         placeholder="persona@gmail.com" autocomplete="off" />
                  <span class="scd__hint">El mail REAL de la persona, al que le llegan los avisos.</span>
                </div>
                <div class="scd__field">
                  <label class="scd__lbl">Contraseña inicial</label>
                  <!-- Visible: es temporal y hay que poder dictársela a quien va a usarla.
                       Detrás de puntitos había que acordarse de lo que uno acababa de tipear. -->
                  <input v-model="userForm.password" type="text" autocomplete="off" spellcheck="false"
                         class="scd__input scd__input--mono" />
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
                <DsSpinner v-if="saving" :size="13" />
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
.scd { padding: 2rem 2.5rem 3rem; display: flex; flex-direction: column; gap: 1rem; }
/* Loading */
.scd__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

/* Deleted banner */
.scd__susp-banner { display: flex; align-items: center; gap: .6rem; background: #fffbeb; border: 1px solid #fcd34d; color: #92400e; border-radius: 10px; padding: .7rem 1rem; margin-bottom: 1rem; font-size: .85rem; }
.scd__susp-banner > div { flex: 1; }
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
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 16px;
  overflow: hidden;
}
.scd__back {
  display: inline-flex; align-items: center; gap: .35rem;
  font-size: .75rem; font-weight: 600; color: var(--c-slate-400);
  text-decoration: none; padding: .75rem 1.25rem;
  border-bottom: 1px solid var(--c-slate-100);
  transition: color .15s; width: 100%; box-sizing: border-box;
}
.scd__back:hover { color: var(--c-slate-900); background: #fafbfc; }
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
.scd__avatar--deleted { background: var(--c-slate-100); color: var(--c-slate-400); }
.scd__hero-text { flex: 1; min-width: 0; }
.scd__hero-name-row { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; margin-bottom: .3rem; }
.scd__title { font-size: 1.5rem; font-weight: 800; color: var(--c-slate-900); margin: 0; letter-spacing: -.035em; }
.scd__hero-meta { font-size: .75rem; color: var(--c-slate-400); display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.scd__mono { font-family: monospace; font-size: .72rem; }
.scd__meta-sep { color: #d1d5db; }

.scd__hero-stats {
  display: flex; gap: 0; border: 1px solid var(--c-slate-200); border-radius: 10px;
  overflow: hidden; flex-shrink: 0;
}
.scd__hstat { padding: .6rem 1rem; text-align: center; border-right: 1px solid var(--c-slate-200); }
.scd__hstat:last-child { border-right: none; }
.scd__hstat-val { display: block; font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); letter-spacing: -.03em; line-height: 1; }
.scd__hstat-lbl { display: block; font-size: .62rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-400); margin-top: .2rem; }

.scd__hero-actions { display: flex; gap: .5rem; flex-shrink: 0; }

/* Plan + trial pills */
.scd__plan-pill { font-size: .72rem; font-weight: 800; padding: .2em .7em; border-radius: 7px; }
.scd__trial-pill { font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em; background: #fffbeb; color: #b45309; padding: .2em .6em; border-radius: 6px; }

/* Row layout */
.scd__row { display: grid; grid-template-columns: 1fr 320px; gap: 1rem; align-items: start; }
@media (max-width: 900px) { .scd__row { grid-template-columns: 1fr; } }

/* Cards */
.scd__card {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px;
  overflow: hidden;
}
.scd__card-col { display: flex; flex-direction: column; gap: 1rem; }
.scd__card-hd {
  display: flex; align-items: center; gap: .5rem;
  padding: .75rem 1.1rem; border-bottom: 1px solid var(--c-slate-100);
  background: #fafbfc; font-size: .82rem; font-weight: 700; color: var(--c-slate-900);
  min-height: 44px;
}
.scd__card-ico { color: #1b5e20; flex-shrink: 0; }
.scd__card-ico--orange { color: #ea580c; }
.scd__count { font-size: .72rem; font-weight: 700; background: var(--c-slate-100); color: var(--c-slate-500); padding: .1em .55em; border-radius: 6px; }
.scd__link-btn {
  display: inline-flex; align-items: center; gap: .3rem;
  margin-left: auto; font-size: .72rem; font-weight: 600; color: #0369a1;
  background: none; border: none; cursor: pointer; padding: 0;
}
.scd__link-btn:hover { text-decoration: underline; }

/* Info card */
.scd__dl { display: grid; grid-template-columns: 100px 1fr; gap: .4rem .75rem; padding: 1rem 1.1rem; margin: 0; }
.scd__dl dt { font-size: .72rem; color: var(--c-slate-400); font-weight: 500; }
.scd__dl dd { font-size: .8rem; color: var(--c-slate-900); font-weight: 500; margin: 0; }
.scd__info-form { padding: 1rem 1.1rem; display: flex; flex-direction: column; gap: .875rem; }
.scd__info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
@media (max-width: 640px) { .scd__info-grid { grid-template-columns: 1fr; } }
.scd__info-footer { display: flex; justify-content: flex-end; gap: .65rem; padding-top: .25rem; }

/* Plan card */
.scd__plan-pill--lg { font-size: .85rem; padding: .3em .9em; }
.scd__plan-body { padding: 1rem 1.1rem; display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.scd__plan-until { font-size: .72rem; color: var(--c-slate-400); width: 100%; margin: .25rem 0 0; }

/* Web card */
.scd__web-card { }
.scd__web-body { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; gap: 1rem; }
.scd__web-status { font-size: .82rem; font-weight: 700; color: var(--c-slate-400); margin-bottom: .15rem; }
.scd__web-status--on { color: #15803d; }
.scd__web-toggle {
  width: 44px; height: 24px; border-radius: 12px; background: var(--c-slate-200);
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
.scd__empty { padding: 2rem; text-align: center; color: var(--c-slate-400); font-size: .82rem; }
.scd__users { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px,1fr)); gap: 0; }
.scd__user-row { display: flex; align-items: center; gap: .65rem; padding: .65rem 1.1rem; border-bottom: 1px solid var(--c-slate-50); }
.scd__user-row:last-child { border-bottom: none; }
.scd__user-av { width: 30px; height: 30px; border-radius: 50%; background: var(--c-slate-100); color: var(--c-slate-600); font-size: .72rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.scd__user-info { flex: 1; min-width: 0; }
.scd__user-name  { font-size: .8rem; font-weight: 600; color: var(--c-slate-900); }
.scd__user-email { font-size: .68rem; color: var(--c-slate-400); font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.scd__role-pill { font-size: .65rem; font-weight: 700; padding: .18em .55em; border-radius: 5px; white-space: nowrap; flex-shrink: 0; }

/* Los estilos de los módulos (suites, add-ons, incluidos, en construcción y sus paneles de
   configuración) se fueron con el markup a SAModulos.vue. */

.scd__input--mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing: .02em; }

/* Historial — qué le hicimos nosotros a este club */
.scd__hist { list-style: none; margin: 0; padding: 0; display: grid; gap: .3rem; }
.scd__hist-item {
  display: grid; grid-template-columns: 110px 76px 1fr auto; gap: .6rem; align-items: baseline;
  padding: .5rem .65rem; border-radius: 8px; background: var(--c-slate-50);
  font-size: .76rem;
}
.scd__hist-fecha { color: var(--c-slate-400); font-variant-numeric: tabular-nums; }
.scd__hist-accion {
  font-size: .65rem; font-weight: 800; text-transform: uppercase; letter-spacing: .04em;
  text-align: center; border-radius: 5px; padding: .12rem .3rem;
  background: var(--c-slate-200); color: var(--c-slate-600);
}
.scd__hist-accion--crear   { background: #dcfce7; color: #15803d; }
.scd__hist-accion--eliminar { background: #fee2e2; color: #b91c1c; }
.scd__hist-cambios { color: var(--c-slate-700); }
.scd__hist-quien   { color: var(--c-slate-400); font-size: .7rem; }

@media (max-width: 700px) {
  .scd__hist-item { grid-template-columns: 1fr; gap: .15rem; }
}

/* Suscripción */
.scd__susc-suites { display: flex; flex-wrap: wrap; gap: .35rem; }
.scd__susc-pill { background: #dcfce7; color: #15803d; }
.scd__susc-pill--none { background: var(--c-slate-100); color: var(--c-slate-400); }
.scd__susc-addons { font-size: .72rem; color: var(--c-slate-500); margin: .5rem 0 0; line-height: 1.45; }

/* Toggle (checkbox) */
.scd__chk { display: none; }
.scd__track { width: 34px; height: 19px; background: var(--c-slate-300); border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.scd__chk:checked + .scd__track { background: #1b5e20; }
.scd__thumb { position: absolute; width: 13px; height: 13px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 2px rgba(0,0,0,.2); }
.scd__chk:checked + .scd__track .scd__thumb { left: 18px; }

/* Toggle row (for modals) */
.scd__toggle-row { display: flex; align-items: center; gap: .75rem; cursor: pointer; padding: .75rem; background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; }
.scd__toggle-lbl { font-size: .875rem; font-weight: 600; color: var(--c-slate-900); }

/* SMTP */
.scd__smtp-body { padding: 1.25rem 1.4rem; }
.scd__smtp-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 1rem; }
@media (max-width: 900px) { .scd__smtp-grid { grid-template-columns: 1fr 1fr; } }
@media (max-width: 580px) { .scd__smtp-grid { grid-template-columns: 1fr; } }
.scd__smtp-footer { display: flex; justify-content: flex-end; margin-top: 1rem; }

/* Form primitives */
.scd__field { display: flex; flex-direction: column; gap: .3rem; }
.scd__field--full { grid-column: 1 / -1; }
.scd__lbl { font-size: .7rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.scd__hint { font-size: .7rem; color: var(--c-slate-400); }
.scd__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  padding: .55rem .875rem; font-size: .875rem; color: var(--c-slate-900);
  width: 100%; box-sizing: border-box; transition: border .15s;
}
.scd__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); background: #fff; }
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
  background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200);
  padding: .5rem .875rem; border-radius: 8px; font-size: .78rem; font-weight: 600;
  cursor: pointer; transition: all .15s; white-space: nowrap;
}
.scd__btn-secondary:hover:not(:disabled) { background: var(--c-slate-50); border-color: var(--c-slate-400); }
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
  background: transparent; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200);
  padding: .55rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer;
  display: inline-flex; align-items: center; gap: .4rem;
}
.scd__btn-ghost:hover { background: var(--c-slate-50); }

/* Modals */
.scd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(4px); }
.scd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }
.scd__modal-hd { display: flex; align-items: center; justify-content: space-between; padding: 1.1rem 1.35rem .9rem; border-bottom: 1px solid var(--c-slate-100); }
.scd__modal-title { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); }
.scd__modal-close { background: var(--c-slate-100); border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: var(--c-slate-500); }
.scd__modal-close:hover { background: var(--c-slate-200); }
.scd__modal-body { padding: 1.1rem 1.35rem; display: flex; flex-direction: column; gap: .875rem; }
.scd__modal-ft { display: flex; justify-content: flex-end; gap: .65rem; padding: .875rem 1.35rem; border-top: 1px solid var(--c-slate-100); }
.scd__planes { display: grid; grid-template-columns: repeat(2,1fr); gap: .4rem; }
.scd__plan-opt { padding: .625rem .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; background: var(--c-slate-50); font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; text-align: left; color: var(--c-slate-600); display: grid; gap: .25rem; }
.scd__plan-opt:hover { border-color: var(--c-slate-400); }
.scd__plan-opt-name { font-size: .85rem; font-weight: 800; }
.scd__plan-opt-limites { font-size: .66rem; font-weight: 500; line-height: 1.4; opacity: .8; }
</style>
