<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { useRoute } from 'vue-router'

const props = defineProps({ backPath: { type: String, default: '/pacientes' } })
import { usePacientesStore } from '../stores/pacientes'
import { useAuthStore } from '../stores/auth'
import { useClubStore } from '../stores/club'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import IndicacionesMedicas from '../components/pacientes/IndicacionesMedicas.vue'
import Dispensaciones from '../components/pacientes/Dispensaciones.vue'
import PatientDocuments from '../components/pacientes/PacienteDocumentos.vue'
import { getPacienteTimeline, getPacienteTurnos, updateAdminTurno, deleteAdminTurno, updatePaciente, aprobarPaciente } from '../lib/api.js'
import {
  User, ShieldCheck, Pill, BookOpen, FileText, ClipboardList, Clock,
  Pencil, AlertTriangle, Info, Wallet, CreditCard, Mail, CalendarPlus,
  CalendarDays, UserCheck, RotateCcw, X, ChevronDown, Check, MoreHorizontal, FileHeart, KeyRound
} from 'lucide-vue-next'
import DsDropdown from '../design-system/components/Dropdown.vue'
import { REPROCANN_ESTADOS } from '../composables/useSocioEditar.js'
import { reprocannCategoria, reprocannDias, reprocannPlazo } from '../composables/useReprocann.js'
import { useToast } from '../composables/useToast.js'
import DsSpinner               from '../design-system/components/Spinner.vue'
import SocioTabTimeline        from '../components/pacientes/SocioTabTimeline.vue'
import SocioTabCuentaCorriente from '../components/pacientes/SocioTabCuentaCorriente.vue'
import SocioTabCorreo          from '../components/pacientes/SocioTabCorreo.vue'
import SocioTabHistoria        from '../components/pacientes/SocioTabHistoria.vue'
import SocioTabNotas           from '../components/pacientes/SocioTabNotas.vue'
import SocioTabPortal          from '../components/pacientes/SocioTabPortal.vue'
import SocioEditarModal          from '../components/pacientes/SocioEditarModal.vue'
import ModalAgendarTurnoMedico  from '../components/pacientes/ModalAgendarTurnoMedico.vue'
import TurnoDetallePanel        from '../components/TurnoDetallePanel.vue'

const route  = useRoute()
const store  = usePacientesStore()
const auth   = useAuthStore()

const socioId   = Number(route.params.id)
const loading   = ref(true)
const error     = ref(null)
const activeTab = ref(auth.user?.role === 'dispensador' ? 'dispensaciones' : 'info')

const club       = useClubStore()
const canEdit    = computed(() => ['admin', 'medico', 'super_admin'].includes(auth.user?.role))
const s          = computed(() => store.current)
const edadSocio  = computed(() => s.value ? edad(s.value.fecha_nacimiento) : null)

const reprocannEstadoMeta = computed(() => {
  // estado_efectivo viene del backend cruzado con la fecha de vencimiento;
  // si está vencido pisa al campo manual (que puede haber quedado en "activo")
  const estado = s.value?.reprocann_estado_efectivo || s.value?.reprocann_estado || 'sin_registro'
  if (estado === 'vencido') return { value: 'vencido', label: 'Vencido', color: '#dc2626', bg: '#fef2f2' }
  return REPROCANN_ESTADOS.find(e => e.value === estado)
})

const editarOpen     = ref(false)
const agendarTurnoOpen = ref(false)
const isAdmin    = computed(() => ['admin', 'super_admin'].includes(auth.user?.role))
const isMedico   = computed(() => auth.user?.role === 'medico')
const canAgendar = computed(() => isAdmin.value || isMedico.value)

// ── Admisión ──────────────────────────────────────────────────────────────────
// Una ficha cargada en el mostrador existe pero todavía no fue admitida: se puede completar,
// pero no recibir dispensaciones ni reservas. Aprobar es de admin y médico (lo valida el
// backend; acá sólo se decide a quién se le muestra el botón).
const pendienteAprobacion = computed(() => !!s.value && !s.value.aprobado_at)
const puedeAprobar        = computed(() => isAdmin.value || isMedico.value)
const aprobando           = ref(false)

// La bienvenida de un alta de mostrador sale ACÁ, no cuando la cargaron: recién al aprobarla
// la persona es paciente de la organización.
const mandarBienvenida = ref(false)
const puedeMandarBienvenida = computed(() =>
  puedeAprobar.value && club.data?.features?.mailer === true && !!s.value?.email
)

async function aprobarAlta() {
  aprobando.value = true
  try {
    const { data } = await aprobarPaciente(s.value.id, {
      enviarBienvenida: puedeMandarBienvenida.value && mandarBienvenida.value,
    })
    await store.fetchOne(s.value.id)
    toast.success('Paciente aprobado — ya puede recibir dispensaciones')
    // El alta se aprobó igual; si el mail no salió es un aviso aparte, no un error del alta.
    if (data?.aviso) toast.warning(data.aviso)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo aprobar el alta')
  } finally {
    aprobando.value = false
  }
}
const toast   = useToast()

const ccRefreshKey = ref(0)
function onDispensacionCreada() {
  ccRefreshKey.value++
  store.fetchOne(socioId)
}

// ── Cambio rápido de estado REPROCANN (sin abrir el modal de edición) ──
const cambiandoEstado    = ref(false)
const estadoDropdownOpen = ref(false)
const activarModalOpen   = ref(false)
const nuevaVencimiento   = ref('')

async function cambiarEstadoReprocann(nuevo) {
  estadoDropdownOpen.value = false
  // Activar exige (re)cargar la fecha de vencimiento → mini-modal
  if (nuevo === 'activo') {
    nuevaVencimiento.value = (s.value?.reprocann_vencimiento || '').toString().slice(0, 10)
    activarModalOpen.value = true
    return
  }
  if (s.value?.reprocann_estado === nuevo) return
  await guardarEstadoReprocann({ reprocann_estado: nuevo })
}

async function confirmarActivacion() {
  if (!nuevaVencimiento.value) { toast.error('Ingresá la fecha de vencimiento'); return }
  await guardarEstadoReprocann({ reprocann_estado: 'activo', reprocann_vencimiento: nuevaVencimiento.value })
  activarModalOpen.value = false
}

async function guardarEstadoReprocann(payload) {
  cambiandoEstado.value = true
  try {
    await updatePaciente(socioId, payload)
    await store.fetchOne(socioId)
    toast.success('REPROCANN actualizado')
  } catch (e) {
    toast.error(e?.response?.data?.errors?.join(', ') || 'No se pudo actualizar')
  } finally {
    cambiandoEstado.value = false
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────
const timeline        = ref([])
const timelineLoading = ref(false)
const timelineLoaded  = ref(false)

async function loadTimeline() {
  if (timelineLoaded.value) return
  timelineLoading.value = true
  try {
    const { data } = await getPacienteTimeline(socioId)
    timeline.value = data.timeline ?? []
    timelineLoaded.value = true
  } catch {
    timeline.value = []
  } finally {
    timelineLoading.value = false
  }
}

// ── Turnos ────────────────────────────────────────────────────────────────────
const turnosList    = ref([])
const turnosLoading = ref(false)
const turnosLoaded  = ref(false)

async function loadTurnos() {
  turnosLoading.value = true
  try {
    const { data } = await getPacienteTurnos(socioId)
    turnosList.value = data ?? []
    turnosLoaded.value = true
  } catch {
    turnosList.value = []
  } finally {
    turnosLoading.value = false
  }
}

const TIPO_LABEL   = { primera_vez: 'Primera vez', seguimiento: 'Seguimiento', revision: 'Revisión', urgencia: 'Urgencia' }
const ESTADO_LABEL = { programado: 'Programado', confirmado: 'Confirmado', realizado: 'Realizado', cancelado: 'Cancelado', ausente: 'Ausente' }
const ESTADO_CLS   = { programado: 'turno-chip--prog', confirmado: 'turno-chip--conf', realizado: 'turno-chip--real', cancelado: 'turno-chip--canc', ausente: 'turno-chip--aus' }
const TIPO_CLS     = { primera_vez: 'turno-chip--pv', seguimiento: 'turno-chip--seg', revision: 'turno-chip--rev', urgencia: 'turno-chip--urg' }

// ── Edición de turno ─────────────────────────────────────────────────────────
const turnoEditando    = ref(null)   // turno completo que se está editando
const turnoSeleccionado = ref(null)

function onTurnoUpdated(data) {
  const idx = turnosList.value.findIndex(t => t.id === data.id)
  if (idx !== -1) turnosList.value[idx] = { ...turnosList.value[idx], ...data }
  turnoSeleccionado.value = { ...turnoSeleccionado.value, ...data }
}
const editSaving     = ref(false)
const editCancelling = ref(false)
const editForm       = ref({ fecha: '', hora: '', duracion_minutos: 30, tipo: 'seguimiento', estado: 'programado', motivo: '' })

function abrirEdicion(t) {
  const d = new Date(t.fecha_hora)
  const pad = n => String(n).padStart(2, '0')
  editForm.value = {
    fecha:            `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}`,
    hora:             `${pad(d.getHours())}:${pad(d.getMinutes())}`,
    duracion_minutos: t.duracion_minutos,
    tipo:             t.tipo,
    estado:           t.estado,
    motivo:           t.motivo || '',
  }
  turnoEditando.value = t
}

async function guardarEdicion() {
  editSaving.value = true
  try {
    const fecha_hora = `${editForm.value.fecha}T${editForm.value.hora}:00`
    const { data } = await updateAdminTurno(turnoEditando.value.id, {
      fecha_hora,
      duracion_minutos: Number(editForm.value.duracion_minutos),
      tipo:    editForm.value.tipo,
      estado:  editForm.value.estado,
      motivo:  editForm.value.motivo || undefined,
    })
    const idx = turnosList.value.findIndex(t => t.id === turnoEditando.value.id)
    if (idx !== -1) turnosList.value[idx] = { ...turnosList.value[idx], ...data }
    turnoEditando.value = null
    toast.success('Turno actualizado')
  } catch { toast.error('No se pudo guardar') }
  finally  { editSaving.value = false }
}

async function cancelarTurno(t) {
  if (!confirm(`¿Cancelar el turno del ${new Date(t.fecha_hora).toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })}?`)) return
  editCancelling.value = true
  try {
    await deleteAdminTurno(t.id)
    const idx = turnosList.value.findIndex(x => x.id === t.id)
    if (idx !== -1) turnosList.value[idx] = { ...turnosList.value[idx], estado: 'cancelado' }
    if (turnoEditando.value?.id === t.id) turnoEditando.value = null
    toast.success('Turno cancelado')
  } catch { toast.error('No se pudo cancelar') }
  finally  { editCancelling.value = false }
}

watch(activeTab, (tab) => {
  if (tab === 'timeline') loadTimeline()
  if (tab === 'turnos')   loadTurnos()
})

// ── Helpers ───────────────────────────────────────────────────────────────────
function safeDate(d) {
  if (!d) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}
function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}
function edad(fn) {
  if (!fn) return null
  return Math.floor((Date.now() - safeDate(fn).getTime()) / (1000 * 60 * 60 * 24 * 365.25))
}

// El ESTADO manda sobre la fecha — la misma regla que ya centraliza `reprocannCategoria`.
//
// Antes esto arrancaba con `if (!reprocann_vencimiento) return null`, y un trámite PENDIENTE no
// tiene vencimiento por definición: caía en el `v-else` de la plantilla, que dice
// "Sin REPROCANN". Justo lo contrario de lo que pasa — sin REPROCANN es que ni siquiera se
// inició el trámite, y acá hay uno presentado esperando resolución.
const reprocannStatus = computed(() => {
  if (!s.value) return null
  const cat  = reprocannCategoria(s.value)
  const days = reprocannDias(s.value)

  switch (cat) {
    case 'sin_reprocann':
      return null // no hay nada que informar: la plantilla muestra "Sin REPROCANN"
    case 'pendiente':
      // Con fecha vencida además, se aclara: hay renovación en curso, por eso ámbar y no rojo.
      return days !== null && days < 0
        ? { label: 'Vencido — trámite pendiente', color: '#b45309', bg: 'rgba(180,83,9,.12)', key: 'pendiente' }
        : { label: 'Trámite pendiente',           color: '#b45309', bg: 'rgba(180,83,9,.12)', key: 'pendiente' }
    case 'vencido':
      return { label: 'Vencido', color: '#dc2626', bg: 'rgba(220,38,38,.1)', key: 'danger' }
    case 'por_vencer':
      return { label: `Vence en ${reprocannPlazo(s.value)}`, color: '#d97706', bg: 'rgba(217,119,6,.1)', key: 'warning' }
    default: // vigente, con o sin fecha cargada
      return days === null
        ? { label: 'Vigente', color: '#15803d', bg: 'rgba(21,128,61,.1)', key: 'success' }
        // "947 días restantes" no le dice nada a nadie: va en años y meses.
        : { label: `Vigente — faltan ${reprocannPlazo(s.value)}`, color: '#15803d', bg: 'rgba(21,128,61,.1)', key: 'success' }
  }
})

const AVATAR_COLORS = ['#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626','#15803d']
function avatarColor(id) { return AVATAR_COLORS[(id || 0) % AVATAR_COLORS.length] }

const ALL_TABS = [
  { key: 'info',             label: 'Datos',            icon: User,          primary: true },
  { key: 'reprocann',        label: 'REPROCANN',         icon: ShieldCheck,   primary: true },
  { key: 'dispensaciones',   label: 'Dispensaciones',    icon: Pill,          primary: true },
  { key: 'cuenta_corriente', label: 'Cuenta corriente',  icon: Wallet,        roles: ['admin', 'dispensador'], primary: true },
  { key: 'turnos',           label: 'Turnos',            icon: CalendarDays,  roles: ['admin', 'medico'] },
  { key: 'historia',         label: 'Historia clínica',  icon: ClipboardList, roles: ['admin', 'medico'] },
  { key: 'indicaciones',     label: 'Indicaciones',      icon: FileHeart,     roles: ['admin', 'medico', 'supervisor'] },
  { key: 'notas',            label: 'Notas',             icon: BookOpen,      roles: ['admin', 'medico'] },
  { key: 'documentos',       label: 'Documentos',        icon: FileText,      roles: ['admin', 'medico', 'auditor', 'abogado'] },
  { key: 'timeline',         label: 'Timeline',          icon: Clock,         roles: ['admin', 'medico'] },
  { key: 'correo',           label: 'Correo',            icon: Mail,          roles: ['admin', 'supervisor'] },
  // Su cuenta del portal. Sólo aparece si la organización tiene el módulo (ver TABS).
  { key: 'portal',           label: 'Acceso al portal',  icon: KeyRound,      roles: ['admin', 'medico'] },
]


const TABS = computed(() => {
  const role = auth.user?.role
  // El dispensador entra a la ficha solo para dispensar: ve únicamente esa tab.
  if (role === 'dispensador') return ALL_TABS.filter(t => t.key === 'dispensaciones')

  return ALL_TABS.filter(t => {
    if (t.roles && !t.roles.includes(role)) return false
    // Sin el módulo no hay portal del que hablar: la tab no existe, no aparece vacía.
    if (t.key === 'portal') return s.value?.acceso?.modulo === true
    return true
  })
})

// P1: tabs primarias (alta frecuencia) visibles; el resto va a un menú "Más".
const TABS_PRIMARY = computed(() => TABS.value.filter(t => t.primary))
const TABS_MORE    = computed(() => TABS.value.filter(t => !t.primary))
const masOpen      = ref(false)
const activeEnMas  = computed(() => TABS_MORE.value.some(t => t.key === activeTab.value))
function elegirTab(key) { activeTab.value = key; masOpen.value = false }

// Solo montar el contenido de un tab si el rol actual tiene acceso a él
const tabVisible = (key) => TABS.value.some(t => t.key === key)

function escapeHandler(e) {
  if (e.key !== 'Escape') return
  if (editarOpen.value) { editarOpen.value = false }
}
onMounted(async () => {
  document.addEventListener('keydown', escapeHandler, true)
  try {
    await store.fetchOne(socioId)
    await store.fetchNotas(socioId)
  } catch (e) {
    error.value = store.error || 'No se pudo cargar el paciente'
  } finally {
    loading.value = false
  }
})
onUnmounted(() => { document.removeEventListener('keydown', escapeHandler, true) })
</script>

<template>
  <div class="sd">

    <!-- Loading -->
    <div v-if="loading" class="sd__loading">
      <DsSpinner />
    </div>
    <div v-else-if="error" class="sd__error">{{ error }}</div>
    <div v-else-if="!s" class="sd__error">Paciente no encontrado.</div>

    <template v-else>

      <!-- Breadcrumb -->
      <Breadcrumb :items="[{ label: 'Pacientes', to: props.backPath }, { label: `${s.nombre} ${s.apellido}` }]" />

      <!-- Hero -->
      <div class="sd__hero">
        <div class="sd__hero-left">
          <div class="sd__avatar" :style="{ background: avatarColor(s.id) }">
            {{ (s.nombre?.[0] || '') + (s.apellido?.[0] || '') }}
          </div>
          <div class="sd__hero-info">
            <h1 class="sd__hero-name">{{ s.nombre }} {{ s.apellido }}</h1>
            <div class="sd__hero-meta">
              <span>DNI {{ s.dni || '—' }}</span>
              <span v-if="edadSocio" class="sd__meta-sep">·</span>
              <span v-if="edadSocio">{{ edadSocio }} años</span>
            </div>
            <div class="sd__hero-badges">
              <span v-if="reprocannStatus"
                    class="sd__repro-badge"
                    :style="{ background: reprocannStatus.bg, color: reprocannStatus.color }">
                {{ reprocannStatus.label }}
              </span>
              <span v-else class="sd__repro-badge sd__repro-badge--none">Sin REPROCANN</span>
              <span v-if="pendienteAprobacion" class="sd__repro-badge sd__repro-badge--pend">
                Pendiente de aprobación
              </span>
              <span v-if="s.es_paciente" class="sd__status-badge sd__status-badge--active">En tratamiento</span>
              <span v-else class="sd__status-badge">Inactivo</span>
            </div>
          </div>
        </div>
        <div class="sd__hero-actions">
          <RouterLink v-if="s?.carnet_token" :to="`/c/${s.carnet_token}`" target="_blank" class="sd__btn-carnet">
            <CreditCard :size="14" :stroke-width="1.75" /> Carnet
          </RouterLink>
          <button v-if="canEdit" class="sd__btn-edit" @click="editarOpen = true">
            <Pencil :size="14" :stroke-width="1.75" /> Editar
          </button>
        </div>
      </div>

      <!-- Alerta REPROCANN -->
      <div v-if="reprocannStatus?.key === 'danger'" class="sd__alerta sd__alerta--danger">
        <AlertTriangle :size="16" />
        <div><strong>REPROCANN vencido</strong> — El certificado venció el {{ formatDate(s.reprocann_vencimiento) }}.</div>
      </div>
      <div v-else-if="reprocannStatus?.key === 'pendiente'" class="sd__alerta sd__alerta--warning">
        <AlertTriangle :size="16" />
        <div><strong>REPROCANN vencido — trámite pendiente</strong> — El certificado venció el {{ formatDate(s.reprocann_vencimiento) }}, con renovación en trámite.</div>
      </div>
      <div v-else-if="reprocannStatus?.key === 'warning'" class="sd__alerta sd__alerta--warning">
        <AlertTriangle :size="16" />
        <div><strong>REPROCANN por vencer</strong> — El certificado vence el {{ formatDate(s.reprocann_vencimiento) }}.</div>
      </div>

      <!-- Alta cargada en el mostrador y todavía sin admitir. Va arriba de las tabs porque
           condiciona todo lo demás: se puede completar la ficha, pero no entregarle nada. -->
      <div v-if="pendienteAprobacion" class="sd__alerta sd__alerta--pend">
        <UserCheck :size="16" />
        <div class="sd__alerta-txt">
          <strong>Pendiente de aprobación</strong> — Se cargó desde el mostrador. No puede recibir
          dispensaciones ni reservas hasta que se apruebe el alta.
          <template v-if="!puedeAprobar"> Pedíselo a un administrador o al médico.</template>
        </div>
        <div v-if="puedeAprobar" class="sd__alerta-acc">
          <label v-if="puedeMandarBienvenida" class="sd__alerta-check">
            <input type="checkbox" v-model="mandarBienvenida" />
            <span>Enviar mail de bienvenida</span>
          </label>
          <button class="sd__btn-aprobar" :disabled="aprobando" @click="aprobarAlta">
            <Check :size="14" :stroke-width="3" />
            {{ aprobando ? 'Aprobando…' : 'Aprobar alta' }}
          </button>
        </div>
      </div>

      <!-- Tabs: primarias inline + resto en "Más" -->
      <div class="sd__tabs">
        <button
          v-for="tab in TABS_PRIMARY" :key="tab.key"
          class="sd__tab"
          :class="{ 'sd__tab--active': activeTab === tab.key }"
          @click="activeTab = tab.key"
        >
          <component :is="tab.icon" :size="14" :stroke-width="1.75" />
          {{ tab.label }}
        </button>

        <div v-if="TABS_MORE.length" class="sd__tab-mas" @mouseleave="masOpen = false">
          <button
            class="sd__tab"
            :class="{ 'sd__tab--active': activeEnMas }"
            @click="masOpen = !masOpen"
          >
            <MoreHorizontal :size="14" :stroke-width="1.75" />
            {{ activeEnMas ? (TABS_MORE.find(t => t.key === activeTab)?.label) : 'Más' }}
            <ChevronDown :size="12" :stroke-width="2" />
          </button>
          <div v-if="masOpen" class="sd__tab-mas-menu">
            <button
              v-for="tab in TABS_MORE" :key="tab.key"
              class="sd__tab-mas-item"
              :class="{ 'sd__tab-mas-item--active': activeTab === tab.key }"
              @click="elegirTab(tab.key)"
            >
              <component :is="tab.icon" :size="14" :stroke-width="1.75" />
              {{ tab.label }}
              <span v-if="tab.key === 'notas' && store.notas.length" class="sd__tab-badge">{{ store.notas.length }}</span>
            </button>
          </div>
        </div>
      </div>

      <!-- ── Tab: Datos ── -->
      <div v-show="activeTab === 'info'" class="sd__tab-content">
        <div class="sd__card">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--blue"><User :size="15" /></div>
            <span class="sd__card-title">Datos personales</span>
          </div>
          <div class="sd__info-grid">
            <div class="sd__info-item">
              <div class="sd__info-label">Nombre completo</div>
              <div class="sd__info-val">{{ s.nombre }} {{ s.apellido }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">DNI</div>
              <div class="sd__info-val sd__info-val--mono">{{ s.dni || '—' }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Fecha de nacimiento</div>
              <div class="sd__info-val">{{ formatDate(s.fecha_nacimiento) }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Edad</div>
              <div class="sd__info-val">{{ edadSocio ? edadSocio + ' años' : '—' }}</div>
            </div>
            <div class="sd__info-item sd__info-item--full">
              <div class="sd__info-label">Email</div>
              <div class="sd__info-val">{{ s.email || '—' }}</div>
            </div>
            <div class="sd__info-item sd__info-item--full">
              <div class="sd__info-label">Teléfono</div>
              <div class="sd__info-val">{{ s.telefono || '—' }}</div>
            </div>
          </div>
        </div>
        <div class="sd__sys-info">
          <span>ID sistema: <strong>#{{ s.id }}</strong></span>
          <span>Registrado: <strong>{{ formatDate(s.created_at) }}</strong></span>
          <span>Actualizado: <strong>{{ formatDate(s.updated_at) }}</strong></span>
        </div>
      </div>

      <!-- ── Tab: REPROCANN ── -->
      <div v-show="activeTab === 'reprocann'" class="sd__tab-content">
        <div class="sd__card" :class="reprocannStatus?.key === 'danger' ? 'sd__card--danger' : reprocannStatus?.key === 'warning' ? 'sd__card--warning' : ''">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--green"><ShieldCheck :size="15" /></div>
            <span class="sd__card-title">Datos REPROCANN</span>
          </div>
          <div class="sd__info-grid">
            <div class="sd__info-item">
              <div class="sd__info-label">Estado REPROCANN</div>
              <div class="sd__info-val">
                <!-- Editable: el badge es un menú discreto. Limpio por defecto. -->
                <DsDropdown v-if="canEdit" v-model="estadoDropdownOpen" align="left">
                  <template #anchor>
                    <button
                      type="button"
                      class="sd__estado-trigger"
                      :disabled="cambiandoEstado"
                      :style="{ background: reprocannEstadoMeta?.bg, color: reprocannEstadoMeta?.color, borderColor: reprocannEstadoMeta?.color }"
                      @click="estadoDropdownOpen = !estadoDropdownOpen"
                    >
                      {{ reprocannEstadoMeta?.label || 'Sin estado' }}
                      <ChevronDown :size="13" :stroke-width="2.5" />
                    </button>
                  </template>
                  <template #panel>
                    <div class="sd__estado-menu">
                      <button
                        v-for="opt in REPROCANN_ESTADOS" :key="opt.value"
                        type="button"
                        class="sd__estado-opt"
                        @click="cambiarEstadoReprocann(opt.value)"
                      >
                        <span class="sd__estado-dot" :style="{ background: opt.color }"></span>
                        <span class="sd__estado-opt-label">{{ opt.label }}</span>
                        <Check v-if="s.reprocann_estado === opt.value" :size="14" class="sd__estado-check" />
                      </button>
                    </div>
                  </template>
                </DsDropdown>
                <!-- Solo lectura -->
                <span v-else class="sd__inline-badge"
                      :style="{ background: reprocannEstadoMeta?.bg, color: reprocannEstadoMeta?.color, borderColor: reprocannEstadoMeta?.color }">
                  {{ reprocannEstadoMeta?.label || '—' }}
                </span>
              </div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">N° autorización</div>
              <div class="sd__info-val sd__info-val--mono">{{ s.reprocann_numero || '—' }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Vencimiento</div>
              <div class="sd__info-val">
                <span v-if="s.reprocann_vencimiento">
                  {{ formatDate(s.reprocann_vencimiento) }}
                  <span v-if="reprocannStatus" class="sd__inline-badge"
                        :style="{ background: reprocannStatus.bg, color: reprocannStatus.color }">
                    {{ reprocannStatus.label }}
                  </span>
                </span>
                <span v-else class="sd__val-empty">Sin datos</span>
              </div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Estado del tratamiento</div>
              <div class="sd__info-val">
                <span v-if="s.es_paciente" style="color:#15803d;font-weight:600">✓ En tratamiento activo</span>
                <span v-else class="sd__val-empty">Inactivo</span>
              </div>
            </div>
          </div>
          <div class="sd__card-note">
            <Info :size="12" />
            Vigencia del certificado: 3 años (Res. 1780/2025). Las ONG deben renovar anualmente.
          </div>
        </div>
      </div>

      <!-- ── Tab: Indicaciones ── -->
      <div v-show="activeTab === 'indicaciones'" class="sd__tab-content">
        <div class="sd__card">
          <IndicacionesMedicas :socio-id="socioId" />
        </div>
      </div>

      <!-- ── Tab: Dispensaciones ── -->
      <div v-show="activeTab === 'dispensaciones'" class="sd__tab-content">
        <div class="sd__card">
          <Dispensaciones
            :socio-id="socioId"
            :paciente-nombre="s ? `${s.nombre} ${s.apellido}`.trim() : ''"
            :saldo-cc="s?.saldo_cc ?? null"
            :limite-cc="s?.limite_cc ?? null"
            :descuento-porcentaje="Number(s?.descuento_porcentaje ?? 0)"
            :pendiente-aprobacion="pendienteAprobacion"
            @dispensacion-creada="onDispensacionCreada"
          />
        </div>
      </div>

      <!-- ── Tab: Cuenta corriente ── -->
      <div v-if="tabVisible('cuenta_corriente') && activeTab === 'cuenta_corriente'" class="sd__tab-content">
        <SocioTabCuentaCorriente
          :socio-id="socioId"
          :refresh-key="ccRefreshKey"
          :readonly="auth.user?.role === 'dispensador'"
        />
      </div>

      <!-- ── Tab: Turnos ── -->
      <div v-show="activeTab === 'turnos'" class="sd__tab-content">
        <div class="sd__turnos-header">
          <div>
            <div class="sd__turnos-title">Turnos médicos</div>
            <div class="sd__turnos-sub">Historial de consultas y turnos agendados para este paciente.</div>
          </div>
          <button v-if="canAgendar" class="sd__btn-agendar" @click="agendarTurnoOpen = true">
            <CalendarPlus :size="14" :stroke-width="1.75" /> Agendar turno
          </button>
        </div>

        <div v-if="turnosLoading" class="sd__turnos-loading">
          <DsSpinner :size="18" /> Cargando turnos…
        </div>
        <div v-else-if="turnosList.length === 0" class="sd__turnos-empty">
          <CalendarDays :size="32" stroke-width="1.2" />
          <p>Sin turnos registrados para este paciente.</p>
          <button v-if="canAgendar" class="sd__btn-agendar" @click="agendarTurnoOpen = true">
            <CalendarPlus :size="14" /> Agendar primer turno
          </button>
        </div>
        <div v-else class="sd__turnos-list">
          <div v-for="t in turnosList" :key="t.id"
            class="sd__turno-row sd__turno-row--clickable"
            :class="{ 'sd__turno-row--cancelado': t.estado === 'cancelado' }"
            @click="turnoSeleccionado = t">
            <div class="sd__turno-fecha">
              <div class="sd__turno-dia">{{ new Date(t.fecha_hora).toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short' }) }}</div>
              <div class="sd__turno-hora">{{ new Date(t.fecha_hora).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) }}</div>
            </div>
            <div class="sd__turno-info">
              <div class="sd__turno-medico">
                <UserCheck :size="12" /> {{ t.medico_nombre || 'Sin asignar' }}
              </div>
              <div v-if="t.motivo" class="sd__turno-motivo">{{ t.motivo }}</div>
            </div>
            <div class="sd__turno-chips">
              <span class="turno-chip" :class="TIPO_CLS[t.tipo]">{{ TIPO_LABEL[t.tipo] || t.tipo }}</span>
              <span class="turno-chip" :class="ESTADO_CLS[t.estado]">{{ ESTADO_LABEL[t.estado] || t.estado }}</span>
            </div>
            <div class="sd__turno-dur">{{ t.duracion_minutos }}min</div>
            <div v-if="canAgendar && t.estado !== 'cancelado'" class="sd__turno-actions" @click.stop>
              <button class="sd__turno-btn sd__turno-btn--edit"
                title="Reprogramar turno"
                @click="abrirEdicion(t)">
                <RotateCcw :size="13" /> Reprogramar
              </button>
              <button class="sd__turno-btn sd__turno-btn--cancel"
                title="Cancelar turno"
                :disabled="editCancelling"
                @click="cancelarTurno(t)">
                <X :size="13" />
              </button>
            </div>
          </div>
        </div>

        <!-- Modal edición inline -->
        <Teleport to="body">
          <div v-if="turnoEditando" class="sd__edit-overlay" @click.self="turnoEditando = null">
            <div class="sd__edit-modal">
              <div class="sd__edit-header">
                <div class="sd__edit-title">
                  <RotateCcw :size="15" /> Reprogramar turno
                </div>
                <button class="sd__edit-close" @click="turnoEditando = null"><X :size="16" /></button>
              </div>

              <div class="sd__edit-body">
                <div class="sd__edit-row">
                  <label class="sd__edit-lbl">Fecha</label>
                  <AppDatePicker v-model="editForm.fecha" :min="new Date().toISOString().split('T')[0]" />
                </div>
                <div class="sd__edit-row">
                  <label class="sd__edit-lbl">Hora</label>
                  <input v-model="editForm.hora" type="time" class="sd__edit-input" step="900" />
                </div>
                <div class="sd__edit-row">
                  <label class="sd__edit-lbl">Duración</label>
                  <select v-model.number="editForm.duracion_minutos" class="sd__edit-input">
                    <option :value="15">15 min</option>
                    <option :value="30">30 min</option>
                    <option :value="45">45 min</option>
                    <option :value="60">1 hora</option>
                    <option :value="90">1:30 h</option>
                  </select>
                </div>
                <div class="sd__edit-row">
                  <label class="sd__edit-lbl">Tipo</label>
                  <select v-model="editForm.tipo" class="sd__edit-input">
                    <option value="primera_vez">Primera vez</option>
                    <option value="seguimiento">Seguimiento</option>
                    <option value="revision">Revisión</option>
                    <option value="urgencia">Urgencia</option>
                  </select>
                </div>
                <div class="sd__edit-row">
                  <label class="sd__edit-lbl">Estado</label>
                  <select v-model="editForm.estado" class="sd__edit-input">
                    <option value="programado">Programado</option>
                    <option value="confirmado">Confirmado</option>
                    <option value="realizado">Realizado</option>
                    <option value="ausente">Ausente</option>
                  </select>
                </div>
                <div class="sd__edit-row">
                  <label class="sd__edit-lbl">Motivo</label>
                  <textarea v-model="editForm.motivo" class="sd__edit-input sd__edit-textarea"
                    rows="2" placeholder="Motivo (opcional)" />
                </div>
              </div>

              <div class="sd__edit-footer">
                <button class="sd__btn-ghost" @click="turnoEditando = null">Cancelar</button>
                <button class="sd__btn-primary" :disabled="editSaving" @click="guardarEdicion">
                  <DsSpinner v-if="editSaving" :size="13" />
                  <template v-else><RotateCcw :size="13" /> Guardar cambios</template>
                </button>
              </div>
            </div>
          </div>
        </Teleport>
      </div>

      <!-- ── Tab: Historia clínica ── -->
      <div v-show="activeTab === 'historia'" class="sd__tab-content">
        <SocioTabHistoria :socio-id="socioId" :s="s" />
      </div>

      <!-- ── Tab: Notas ── -->
      <div v-show="activeTab === 'notas'" class="sd__tab-content">
        <SocioTabNotas :socio-id="socioId" :can-edit="canEdit" />
      </div>

      <!-- ── Tab: Documentos ── -->
      <div v-show="activeTab === 'documentos'" class="sd__tab-content">
        <div class="sd__card">
          <PatientDocuments :socio-id="socioId" :socio-nombre="`${s.nombre} ${s.apellido}`" />
        </div>
      </div>

      <!-- ── Tab: Timeline ── -->
      <div v-show="activeTab === 'timeline'" class="sd__tab-content">
        <SocioTabTimeline :timeline="timeline" :timeline-loading="timelineLoading" />
      </div>

      <!-- ── Tab: Correo ── -->
      <div v-if="tabVisible('correo') && activeTab === 'correo'" class="sd__tab-content">
        <SocioTabCorreo :socio-id="socioId" :socio="s" @open-edit="editarOpen = true" />
      </div>

      <!-- ── Tab: Acceso al portal ── -->
      <div v-if="tabVisible('portal') && activeTab === 'portal'" class="sd__tab-content">
        <SocioTabPortal :socio-id="socioId" :nombre="s.nombre_completo" :acceso="s.acceso"
                        @actualizado="store.fetchOne(socioId)" />
      </div>

    </template>
  </div>

  <SocioEditarModal v-model:open="editarOpen" :socio-id="socioId" @saved="store.fetchOne(socioId)" />

  <!-- Mini-modal: activar REPROCANN con nueva fecha de vencimiento -->
  <Teleport to="body">
    <div v-if="activarModalOpen" class="sd__rep-modal-overlay" @click.self="activarModalOpen = false">
      <div class="sd__rep-modal">
        <h3 class="sd__rep-modal-title">Activar REPROCANN</h3>
        <p class="sd__rep-modal-sub">Ingresá la fecha de vencimiento del certificado aprobado.</p>
        <label class="sd__rep-modal-label">Vencimiento</label>
        <AppDatePicker v-model="nuevaVencimiento" />
        <div class="sd__rep-modal-actions">
          <button class="sd__rep-modal-cancel" :disabled="cambiandoEstado" @click="activarModalOpen = false">Cancelar</button>
          <button class="sd__rep-modal-ok" :disabled="cambiandoEstado || !nuevaVencimiento" @click="confirmarActivacion">
            {{ cambiandoEstado ? 'Guardando…' : 'Activar' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>

  <ModalAgendarTurnoMedico
    v-if="agendarTurnoOpen && s"
    :paciente-id="socioId"
    :paciente-nombre="`${s.nombre} ${s.apellido}`"
    :medico-mode="isMedico"
    @close="agendarTurnoOpen = false"
    @created="agendarTurnoOpen = false; loadTurnos()"
  />

  <TurnoDetallePanel
    v-if="turnoSeleccionado"
    :turno="turnoSeleccionado"
    :admin-mode="isAdmin"
    @close="turnoSeleccionado = null"
    @updated="onTurnoUpdated"
  />
</template>

<style scoped>
.sd { padding: 2rem 1.75rem 3rem; max-width: 1100px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: var(--c-slate-900); }
@media (max-width: 768px) { .sd { padding: 1.25rem 1rem 2rem; } }

/* Loading / Error */
.sd__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.sd__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; }

/* Hero */
.sd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1.25rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.sd__hero-left { display: flex; align-items: center; gap: 1.1rem; }
.sd__avatar { width: 64px; height: 64px; border-radius: 16px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 1.4rem; font-weight: 800; flex-shrink: 0; letter-spacing: -.02em; }
.sd__hero-name { font-size: 1.6rem; font-weight: 800; margin: 0 0 .2rem; letter-spacing: -.04em; }
.sd__hero-meta { font-size: .82rem; color: var(--c-slate-500); margin-bottom: .5rem; display: flex; align-items: center; gap: .4rem; }
.sd__meta-sep { color: var(--c-slate-300); }
.sd__hero-badges { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.sd__repro-badge { font-size: .72rem; font-weight: 700; padding: .25em .75em; border-radius: 999px; }
.sd__repro-badge--none { background: rgba(100,116,139,.1); color: var(--c-slate-500); }
.sd__repro-badge--pend { background: rgba(180,83,9,.12); color: #b45309; }
.sd__status-badge { font-size: .7rem; font-weight: 600; padding: .22em .65em; border-radius: 6px; background: var(--c-slate-100); color: var(--c-slate-500); }
.sd__status-badge--active { background: rgba(21,128,61,.1); color: #15803d; }

/* Alertas */
.sd__alerta { display: flex; align-items: flex-start; gap: .75rem; padding: .875rem 1.1rem; border-radius: 12px; font-size: .875rem; margin-bottom: 1.25rem; }
.sd__alerta--danger { background: #fef2f2; border: 1px solid #fecaca; color: #7f1d1d; }
.sd__alerta--warning { background: #fffbeb; border: 1px solid #fde68a; color: #78350f; }

/* Admisión pendiente: mismo ámbar que el resto de "esto espera algo", pero con el botón que lo
   resuelve dentro de la misma franja — el aviso y la acción no deberían estar separados. */
.sd__alerta--pend { background: #fffbeb; border: 1px solid #fde68a; color: #78350f; align-items: center; }
.sd__alerta-txt { flex: 1; }
.sd__btn-aprobar {
  display: inline-flex; align-items: center; gap: .35rem; flex-shrink: 0;
  background: #b45309; color: #fff; border: none; border-radius: 8px;
  padding: .5rem .9rem; font-size: .8rem; font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.sd__btn-aprobar:hover:not(:disabled) { background: #92400e; }
.sd__btn-aprobar:disabled { opacity: .6; cursor: default; }
/* El tilde va PEGADO al botón y no suelto en la franja: es una opción de esa acción, no un
   ajuste del paciente. En pantalla angosta se apila arriba del botón. */
.sd__alerta-acc { display: flex; align-items: center; gap: .75rem; flex-shrink: 0; flex-wrap: wrap; justify-content: flex-end; }
.sd__alerta-check { display: inline-flex; align-items: center; gap: .35rem; font-size: .78rem; font-weight: 600; color: #78350f; cursor: pointer; white-space: nowrap; }
.sd__alerta-check input { cursor: pointer; accent-color: #b45309; }

/* Tabs */
.sd__tabs { display: flex; gap: .25rem; border-bottom: 2px solid var(--c-slate-200); margin-bottom: 1.5rem; flex-wrap: wrap; }
.sd__tab { display: flex; align-items: center; gap: .4rem; padding: .65rem 1rem; border-radius: 8px 8px 0 0; border: none; border-bottom: 2px solid transparent; margin-bottom: -2px; background: none; font-size: .82rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; transition: all .15s; }
.sd__tab-mas { position: relative; }
.sd__tab-mas-menu { position: absolute; top: 100%; right: 0; z-index: 20; min-width: 190px; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 10px; box-shadow: 0 12px 32px rgba(0,0,0,.12); padding: .3rem; margin-top: .2rem; }
.sd__tab-mas-item { display: flex; align-items: center; gap: .5rem; width: 100%; padding: .55rem .7rem; border: none; background: none; border-radius: 7px; font-size: .82rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; text-align: left; }
.sd__tab-mas-item:hover { background: var(--c-slate-100); }
.sd__tab-mas-item--active { background: #f0fdf4; color: #15803d; }
.sd__tab:hover { color: var(--c-slate-900); background: var(--c-slate-50); }
.sd__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }
.sd__tab-badge { background: #e8f5e9; color: #1b5e20; font-size: .65rem; font-weight: 700; padding: .1em .5em; border-radius: 999px; }

/* Cards */
.sd__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; margin-bottom: 1rem; }
.sd__card--mt { margin-top: 1rem; }
.sd__card--danger { border-color: #fecaca; border-left: 3px solid #dc2626; }
.sd__card--warning { border-color: #fde68a; border-left: 3px solid #d97706; }
.sd__card-header { display: flex; align-items: flex-start; gap: .65rem; padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); background: #fafbfc; }
.sd__card-icon { width: 32px; height: 32px; border-radius: 9px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sd__card-icon--blue  { background: rgba(3,105,161,.1);  color: #0369a1; }
.sd__card-icon--green { background: rgba(21,128,61,.1);  color: #15803d; }
.sd__card-icon--amber { background: rgba(180,83,9,.1);   color: #b45309; }
.sd__card-title { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); margin-top: .15rem; }
.sd__card-subtitle { font-size: .72rem; color: var(--c-slate-500); margin-top: .1rem; }
.sd__card-note { padding: .75rem 1.25rem; border-top: 1px solid var(--c-slate-100); font-size: .72rem; color: var(--c-slate-400); display: flex; align-items: center; gap: .4rem; background: #fafbfc; }

/* Info grid */
.sd__info-grid { display: grid; grid-template-columns: 1fr 1fr; }
.sd__info-item { padding: .875rem 1.25rem; border-bottom: 1px solid var(--c-slate-50); border-right: 1px solid var(--c-slate-50); }
.sd__info-item:nth-child(even) { border-right: none; }
.sd__info-item--full { grid-column: 1 / -1; border-right: none; }
.sd__info-label { font-size: .68rem; color: var(--c-slate-400); font-weight: 500; text-transform: uppercase; letter-spacing: .05em; margin-bottom: .25rem; }
.sd__info-val { font-size: .875rem; font-weight: 600; color: var(--c-slate-900); }
.sd__info-val--mono { font-family: monospace; }
.sd__val-empty { color: var(--c-slate-400); font-weight: 400; }
.sd__inline-badge { display: inline-flex; align-items: center; font-size: .68rem; font-weight: 700; padding: .18em .6em; border-radius: 6px; margin-left: .4rem; }
/* Badge-trigger: se ve como un chip de estado, pero al hacer clic abre el menú */
.sd__estado-trigger { display: inline-flex; align-items: center; gap: .3rem; font-size: .68rem; font-weight: 700; padding: .22em .55em .22em .7em; border-radius: 6px; border: 1px solid; cursor: pointer; transition: filter .15s; }
.sd__estado-trigger:hover:not(:disabled) { filter: brightness(.96); }
.sd__estado-trigger:disabled { opacity: .6; cursor: wait; }
.sd__estado-menu { display: flex; flex-direction: column; padding: .3rem; min-width: 190px; }
.sd__estado-opt { display: flex; align-items: center; gap: .55rem; width: 100%; padding: .5rem .6rem; border: none; background: none; border-radius: 7px; font-size: .8rem; font-weight: 600; color: var(--c-slate-700); cursor: pointer; text-align: left; transition: background .12s; }
.sd__estado-opt:hover { background: var(--c-slate-100); }
.sd__estado-opt-label { flex: 1; }
.sd__estado-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
.sd__estado-check { color: #15803d; }
/* Mini-modal activar REPROCANN */
.sd__rep-modal-overlay { position: fixed; inset: 0; background: rgba(15,23,42,.45); z-index: 900; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.sd__rep-modal { background: #fff; border-radius: 14px; padding: 1.5rem; width: 100%; max-width: 360px; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.sd__rep-modal-title { font-size: 1.05rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .4rem; }
.sd__rep-modal-sub { font-size: .8rem; color: var(--c-slate-500); margin: 0 0 1rem; }
.sd__rep-modal-label { display: block; font-size: .72rem; font-weight: 700; color: var(--c-slate-500); margin-bottom: .3rem; }
.sd__rep-modal-input { width: 100%; box-sizing: border-box; padding: .55rem .75rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .9rem; color: var(--c-slate-900); }
.sd__rep-modal-input:focus { outline: none; border-color: #15803d; }
.sd__rep-modal-actions { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
.sd__rep-modal-cancel { background: none; color: var(--c-slate-500); border: 1px solid var(--c-slate-300); border-radius: 8px; padding: .45rem .9rem; font-size: .82rem; font-weight: 600; cursor: pointer; }
.sd__rep-modal-cancel:hover:not(:disabled) { background: var(--c-slate-100); }
.sd__rep-modal-ok { background: #15803d; color: #fff; border: none; border-radius: 8px; padding: .45rem 1.1rem; font-size: .82rem; font-weight: 700; cursor: pointer; }
.sd__rep-modal-ok:hover:not(:disabled) { background: #166534; }
.sd__rep-modal-ok:disabled, .sd__rep-modal-cancel:disabled { opacity: .55; cursor: not-allowed; }

/* Sys info */
.sd__sys-info { display: flex; gap: 2rem; flex-wrap: wrap; padding: .875rem 1.25rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 10px; font-size: .78rem; color: var(--c-slate-500); }

/* Buttons */
.sd__btn-agendar { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sd__btn-agendar:hover { background: #14532d; }
.sd__btn-edit { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd__btn-edit:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.sd__btn-carnet { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; text-decoration: none; }
.sd__btn-carnet:hover { background: #144a18; }
.sd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sd__btn-primary:hover:not(:disabled) { background: #144a18; }
.sd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.sd__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: none; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd__btn-ghost:hover { border-color: var(--c-slate-400); }

/* Documento REPROCANN */
.sd__repro-doc-body { padding: 1rem 1.25rem; }
.sd__repro-doc-row { display: flex; align-items: center; gap: .75rem; }
.sd__repro-doc-link { display: inline-flex; align-items: center; gap: .4rem; font-size: .875rem; font-weight: 600; color: #0369a1; text-decoration: none; padding: .45rem .9rem; border: 1.5px solid #bae6fd; border-radius: 8px; background: #f0f9ff; transition: all .15s; }
.sd__repro-doc-link:hover { background: #e0f2fe; border-color: #0369a1; }
.sd__repro-upload-row { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.sd__repro-hint { font-size: .72rem; color: var(--c-slate-400); }

/* Modal genérico */
.sd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 9999; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.sd__modal { background: white; border-radius: 16px; max-height: 90vh; overflow-y: auto; width: 100%; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.sd__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--c-slate-100); }
.sd__modal-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.sd__modal-close { background: none; border: none; cursor: pointer; color: var(--c-slate-400); padding: .25rem; border-radius: 6px; }
.sd__modal-close:hover { background: var(--c-slate-50); color: var(--c-slate-600); }
.sd__modal-body { padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
.sd__modal-footer { padding: 1rem 1.5rem; border-top: 1px solid var(--c-slate-100); display: flex; justify-content: flex-end; gap: .75rem; }
.sd__form-row { display: flex; flex-direction: column; gap: .35rem; }
.sd__form-label { font-size: .75rem; font-weight: 600; color: var(--c-slate-600); }
.sd__form-input { padding: .55rem .8rem; border: 1px solid var(--c-slate-300); border-radius: 7px; font-size: .875rem; width: 100%; box-sizing: border-box; outline: none; font-family: inherit; }
.sd__form-input:focus { border-color: #1b5e20; box-shadow: 0 0 0 2px #dcfce7; }

/* Renovaciones REPROCANN */
.sd__reno-form { padding: .75rem 1.25rem; display: flex; flex-direction: column; gap: .6rem; border-bottom: 1px solid var(--c-slate-100); }
.sd__reno-row { display: flex; flex-direction: column; gap: .25rem; }
.sd__reno-row label { font-size: .75rem; font-weight: 600; color: var(--c-slate-600); }
.sd__reno-input { width: 100%; padding: .45rem .7rem; border: 1px solid var(--c-slate-300); border-radius: 6px; font-size: .875rem; outline: none; }
.sd__reno-input:focus { border-color: #1b5e20; box-shadow: 0 0 0 2px #dcfce7; }
.sd__reno-actions { display: flex; justify-content: flex-end; gap: .5rem; }
.sd__reno-empty { padding: 1rem 1.25rem; color: var(--c-slate-400); font-size: .85rem; }
.sd__reno-list { display: flex; flex-direction: column; gap: 0; }
.sd__reno-item { padding: .75rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); }
.sd__reno-item:last-child { border-bottom: none; }
.sd__reno-item-head { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.sd__reno-estado { font-size: .7rem; font-weight: 700; padding: .15rem .5rem; border-radius: 999px; }
.sd__reno-numero { font-size: .8rem; font-weight: 600; color: var(--c-slate-700); }
.sd__reno-fecha { font-size: .75rem; color: var(--c-slate-400); margin-left: auto; }
.sd__reno-acciones { display: flex; gap: .3rem; }
.sd__reno-obs { margin-top: .3rem; font-size: .8rem; color: var(--c-slate-500); }
.sd__reno-aprobado { margin-top: .3rem; font-size: .78rem; color: #15803d; font-weight: 600; }
.sd__btn-tiny { display: inline-flex; align-items: center; padding: .25rem .4rem; border: 1px solid; border-radius: 5px; cursor: pointer; background: transparent; transition: all .15s; }
.sd__btn-tiny--ok { border-color: #bbf7d0; color: #15803d; }
.sd__btn-tiny--ok:hover { background: #dcfce7; }
.sd__btn-tiny--danger { border-color: #fecaca; color: #dc2626; }
.sd__btn-tiny--danger:hover { background: #fee2e2; }
.sd__btn-tiny--ghost { border-color: var(--c-slate-200); color: var(--c-slate-400); }
.sd__btn-tiny--ghost:hover { background: var(--c-slate-50); color: var(--c-slate-600); }

/* Turnos tab */
.sd__turnos-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.sd__turnos-title  { font-size: 1rem; font-weight: 700; color: var(--c-slate-900); margin-bottom: .2rem; }
.sd__turnos-sub    { font-size: .8rem; color: var(--c-slate-500); }
.sd__turnos-loading { display: flex; align-items: center; gap: .65rem; padding: 2rem; color: var(--c-slate-500); font-size: .88rem; }
.sd__turnos-empty  { display: flex; flex-direction: column; align-items: center; gap: .75rem; padding: 3rem; text-align: center; color: var(--c-slate-400); }
.sd__turnos-empty p { margin: 0; font-size: .88rem; }
.sd__turnos-list   { display: flex; flex-direction: column; gap: .5rem; }
.sd__turno-row {
  display: flex; align-items: center; gap: 1rem;
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 10px;
  padding: .75rem 1rem; flex-wrap: wrap;
  transition: box-shadow .12s;
}
.sd__turno-row:hover { box-shadow: 0 2px 8px rgba(0,0,0,.06); }
.sd__turno-row--clickable { cursor: pointer; }
.sd__turno-row--clickable:hover { border-color: #bbf7d0; background: #f0fdf4; }
.sd__turno-fecha { min-width: 88px; }
.sd__turno-dia   { font-size: .8rem; font-weight: 700; color: var(--c-slate-900); text-transform: capitalize; }
.sd__turno-hora  { font-size: .78rem; color: var(--c-slate-500); }
.sd__turno-info  { flex: 1; min-width: 0; }
.sd__turno-medico { font-size: .82rem; font-weight: 600; color: var(--c-slate-700); display: flex; align-items: center; gap: .35rem; }
.sd__turno-motivo { font-size: .78rem; color: var(--c-slate-500); margin-top: .15rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sd__turno-chips  { display: flex; gap: .35rem; flex-wrap: wrap; }
.sd__turno-dur    { font-size: .78rem; color: var(--c-slate-400); white-space: nowrap; }
.turno-chip { font-size: .65rem; font-weight: 700; padding: .2em .65em; border-radius: 999px; }
.turno-chip--prog { background: #dbeafe; color: #1d4ed8; }
.turno-chip--conf { background: #d1fae5; color: #065f46; }
.turno-chip--real { background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; }
.turno-chip--canc { background: #fee2e2; color: #dc2626; }
.turno-chip--aus  { background: #fef3c7; color: #b45309; }
.turno-chip--pv   { background: #ede9fe; color: #7c3aed; }
.turno-chip--seg  { background: #f0fdf4; color: #15803d; }
.turno-chip--rev  { background: #dbeafe; color: #1d4ed8; }
.turno-chip--urg  { background: #fee2e2; color: #dc2626; }
.sd__turno-row--cancelado { opacity: .55; background: var(--c-slate-50); }
.sd__turno-actions { display: flex; gap: .35rem; align-items: center; margin-left: auto; flex-shrink: 0; }
.sd__turno-btn {
  display: inline-flex; align-items: center; gap: .3rem;
  border-radius: 7px; padding: .3rem .6rem; font-size: .72rem; font-weight: 600;
  cursor: pointer; transition: all .12s; border: 1.5px solid;
}
.sd__turno-btn--edit  { border-color: #bfdbfe; color: #1d4ed8; background: #eff6ff; }
.sd__turno-btn--edit:hover  { background: #dbeafe; }
.sd__turno-btn--cancel { border-color: #fecaca; color: #dc2626; background: none; padding: .3rem .45rem; }
.sd__turno-btn--cancel:hover:not(:disabled) { background: #fee2e2; }
.sd__turno-btn--cancel:disabled { opacity: .5; cursor: not-allowed; }

/* Modal edición turno */
.sd__edit-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1200; padding: 1rem; backdrop-filter: blur(2px);
}
.sd__edit-modal {
  background: #fff; border-radius: 14px; width: 100%; max-width: 420px;
  box-shadow: 0 20px 60px rgba(0,0,0,.22); display: flex; flex-direction: column;
  overflow: hidden;
}
.sd__edit-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .9rem 1.25rem; border-bottom: 1px solid var(--c-slate-200); background: #fafafa;
}
.sd__edit-title {
  display: flex; align-items: center; gap: .45rem;
  font-size: .88rem; font-weight: 800; color: #1d4ed8;
}
.sd__edit-close {
  background: none; border: none; cursor: pointer; color: var(--c-slate-400);
  border-radius: 6px; padding: .2rem; transition: color .12s;
}
.sd__edit-close:hover { color: var(--c-slate-900); }
.sd__edit-body { padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .75rem; }
.sd__edit-row  { display: flex; flex-direction: column; gap: .2rem; }
.sd__edit-lbl  { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); }
.sd__edit-input {
  padding: .42rem .65rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  font-size: .83rem; color: var(--c-slate-900); outline: none; transition: border-color .15s;
  font-family: inherit;
}
.sd__edit-input:focus { border-color: #1b5e20; }
.sd__edit-textarea { resize: none; }
.sd__edit-footer {
  display: flex; gap: .5rem; justify-content: flex-end;
  padding: .85rem 1.25rem; border-top: 1px solid var(--c-slate-200);
}

</style>
