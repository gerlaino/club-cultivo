<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
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
import { getPacienteTimeline, getPacienteTurnos, updateAdminTurno, deleteAdminTurno, aprobarPaciente } from '../lib/api.js'
import {
  User, ShieldCheck, Pill, BookOpen, FileText, ClipboardList, Clock,
  Pencil, AlertTriangle, Info, Wallet, CreditCard, Mail, CalendarPlus,
  CalendarDays, UserCheck, RotateCcw, X, Check, FileHeart, KeyRound, MapPin, MessageCircle } from 'lucide-vue-next'
import { useRecargaEnCambios } from '../composables/useRecargaEnCambios.js'
import SocioMedicos from '../components/pacientes/SocioMedicos.vue'
import { reprocannCategoria, reprocannDias, reprocannPlazo } from '../composables/useReprocann.js'
import { useToast } from '../composables/useToast.js'
import DsSpinner               from '../design-system/components/Spinner.vue'
import SocioTabTimeline        from '../components/pacientes/SocioTabTimeline.vue'
import SocioTabCuentaCorriente from '../components/pacientes/SocioTabCuentaCorriente.vue'
import SocioTabCorreo          from '../components/pacientes/SocioTabCorreo.vue'
import SocioTabHistoria        from '../components/pacientes/SocioTabHistoria.vue'
import SocioTabNotas           from '../components/pacientes/SocioTabNotas.vue'
import SocioTabPortal          from '../components/pacientes/SocioTabPortal.vue'
import LinkPortalNuevo         from '../components/pacientes/LinkPortalNuevo.vue'
import ChatConPaciente         from '../components/chat/ChatConPaciente.vue'
import RenovacionPortalCard    from '../components/pacientes/RenovacionPortalCard.vue'
import { useChatPacientesStore } from '../stores/chatPacientes'
import SocioTabDirecciones     from '../components/pacientes/SocioTabDirecciones.vue'
import SocioResumen            from '../components/pacientes/SocioResumen.vue'
import SocioEditarModal          from '../components/pacientes/SocioEditarModal.vue'
import ProximoPasoReprocann      from '../components/pacientes/ProximoPasoReprocann.vue'
import { reprocannSit, pacienteSit, vinculoSit } from '../composables/useSituacionPaciente.js'
import '../components/pacientes/formulario/formulario.css'
import ModalAgendarTurnoMedico  from '../components/pacientes/ModalAgendarTurnoMedico.vue'
import TurnoDetallePanel        from '../components/TurnoDetallePanel.vue'
import { hoyISO, yaPaso, fechaLocal } from '../utils/dates.js'

const route  = useRoute()
const store  = usePacientesStore()
const auth   = useAuthStore()

const socioId   = Number(route.params.id)
const loading   = ref(true)
const error     = ref(null)
const activeTab = ref(auth.user?.role === 'dispensador' ? 'dispensaciones' : 'resumen')

const club       = useClubStore()
// canEdit = lo de SALUD (REPROCANN, historia clínica): admin y médico. Los datos personales, el
// alta y el portal son de administración: el médico sólo se ocupa de la salud (15-oct-2026).
const canEdit    = computed(() => ['admin', 'medico', 'super_admin'].includes(auth.user?.role))
const canEditDatos = computed(() => ['admin', 'super_admin'].includes(auth.user?.role))
const s          = computed(() => store.current)
const edadSocio  = computed(() => s.value ? edad(s.value.fecha_nacimiento) : null)

const editarOpen     = ref(false)
const editarSolapa   = ref('persona')
function abrirEditar(solapa = 'persona') { editarSolapa.value = solapa; editarOpen.value = true }
// Los tres estados (19-oct-2026): los calcula el backend (`situacion`), la ficha los muestra.
const sit = computed(() => s.value?.situacion || null)
function darTurno() { activeTab.value = 'turnos'; agendarTurnoOpen.value = true }
const agendarTurnoOpen = ref(false)
const isAdmin    = computed(() => ['admin', 'super_admin'].includes(auth.user?.role))
const isMedico   = computed(() => auth.user?.role === 'medico')
const canAgendar = computed(() => isAdmin.value || isMedico.value)

// ── Admisión ──────────────────────────────────────────────────────────────────
// Una ficha cargada en el mostrador existe pero todavía no fue admitida: se puede completar,
// pero no recibir dispensaciones ni reservas. Aprobar es de administración (lo valida el
// backend; acá sólo se decide a quién se le muestra el botón).
const pendienteAprobacion = computed(() => !!s.value && !s.value.aprobado_at)
const puedeAprobar        = computed(() => isAdmin.value)
const aprobando           = ref(false)

// La bienvenida de un alta de mostrador sale ACÁ, no cuando la cargaron: recién al aprobarla
// la persona es paciente de la organización.
const mandarBienvenida = ref(false)
const puedeMandarBienvenida = computed(() =>
  puedeAprobar.value && club.data?.features?.mailer === true && !!s.value?.email
)

const linkPortal = ref(null)

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
    // El link de su portal, para mandárselo ya (27-oct-2026).
    if (data?.acceso?.link) linkPortal.value = { ...data.acceso.link, nombre: s.value.nombre_completo }
    else if (data?.acceso?.error) toast.warning(`Quedó aprobado, pero no se pudo generar el link del portal: ${data.acceso.error}`)
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
  resumenRef.value?.recargar?.()
  // La dispensa ya quedó; si la recarga falla, la ficha sigue con lo que tenía.
  store.fetchOne(socioId).catch(() => {})
}

// «Que se replique»: si otra pantalla cambia a este paciente (el médico inicia el trámite, alguien
// le vincula un médico, le dan un turno), esta ficha se actualiza sola, sin parpadear.
useRecargaEnCambios('pacientes', () => store.refrescarActual(socioId), { filtro: ev => ev.id === socioId })
useRecargaEnCambios('turnos', () => {
  store.refrescarActual(socioId)
  if (turnosLoaded.value) loadTurnos()
})

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

// Reprogramar a una fecha y hora que ya pasaron se avisa y no se manda (12-oct-2026). Sólo si se
// CAMBIÓ: marcar como realizado un turno de ayer manda la misma fecha y eso sí vale.
const editaAlPasado = computed(() => {
  const t = turnoEditando.value
  if (!t) return false
  const d = new Date(t.fecha_hora)
  const pad = n => String(n).padStart(2, '0')
  const igual = editForm.value.fecha === `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}` &&
                editForm.value.hora  === `${pad(d.getHours())}:${pad(d.getMinutes())}`
  return !igual && yaPaso(editForm.value.fecha, editForm.value.hora)
})

async function guardarEdicion() {
  if (editaAlPasado.value) return
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
  } catch (e) { toast.error(e?.response?.data?.errors?.[0] || 'No se pudo guardar') }
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
  // Lo que se ve al abrir la ficha (28-oct-2026): un vistazo de todo, sin entrar a ninguna sección.
  { key: 'resumen',          label: 'Resumen',          icon: User,          primary: true },
  { key: 'info',             label: 'Datos',            icon: User,          primary: true },
  { key: 'reprocann',        label: 'REPROCANN',         icon: ShieldCheck,   primary: true },
  { key: 'dispensaciones',   label: 'Dispensaciones',    icon: Pill,          primary: true },
  { key: 'cuenta_corriente', label: 'Cuenta corriente',  icon: Wallet,        roles: ['admin', 'supervisor', 'dispensador'], primary: true },
  // El chat del portal con este paciente (27-oct-2026): sólo con el portal contratado (ver TABS).
  { key: 'chat',             label: 'Chat del portal',   icon: MessageCircle, roles: ['admin', 'supervisor'], primary: true },
  // A dónde se le mandan los paquetes: varias, con nombre y una por defecto (Germán, 17-sep).
  { key: 'direcciones',      label: 'Direcciones',       icon: MapPin,        roles: ['admin', 'supervisor', 'medico', 'dispensador'] },
  { key: 'turnos',           label: 'Turnos',            icon: CalendarDays,  roles: ['admin', 'medico'] },
  { key: 'historia',         label: 'Historia clínica',  icon: ClipboardList, roles: ['admin', 'medico'] },
  // Lo de salud es de admin y médico: el backend se lo rechaza a todo otro rol (29-oct-2026).
  { key: 'indicaciones',     label: 'Indicaciones',      icon: FileHeart,     roles: ['admin', 'medico'] },
  { key: 'notas',            label: 'Notas',             icon: BookOpen,      roles: ['admin', 'medico'] },
  { key: 'documentos',       label: 'Documentos',        icon: FileText,      roles: ['admin', 'medico'] },
  { key: 'timeline',         label: 'Historial',         icon: Clock,         roles: ['admin', 'medico'] },
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
    if (t.key === 'portal' || t.key === 'chat') return s.value?.acceso?.modulo === true
    return true
  })
})

// Un panel EXISTE sólo si el rol tiene esa solapa. Con `v-show` solo se montaban todos escondidos
// y cada uno pedía lo suyo: el dispensador abría la ficha y se comía tres 403 (notas,
// indicaciones, documentos) que no veía (21-oct-2026).
const tieneTab = (key) => TABS.value.some(t => t.key === key)

// `?tab=` abre la ficha en una solapa concreta (Contabilidad → Deudores manda a la cuenta
// corriente). Va DESPUÉS de `ALL_TABS` a propósito: `activeTab` se declara arriba y esto lo
// referencia al montar. Si el rol no ve esa solapa, `TABS` la filtra y queda la de siempre.
if (typeof route.query.tab === 'string' && TABS.value.some(t => t.key === route.query.tab)) {
  activeTab.value = route.query.tab
}

// P1: tabs primarias (alta frecuencia) visibles; el resto va a un menú "Más".
// Los mensajes del portal sin leer de ESTE paciente: el contador de la solapa «Chat».
const chatPacientes = useChatPacientesStore()
const chatSinLeer = computed(() => chatPacientes.bandeja.find(c => c.paciente.id === socioId)?.sin_leer || 0)
watch(() => tieneTab('chat'), (si) => { if (si) { chatPacientes.escuchar(); chatPacientes.cargar() } }, { immediate: true })

// ── Secciones (Germán, 28-oct-2026: «siento que tiene mil solapas, difícil encontrar las cosas») ──
// Las 15 solapas quedan agrupadas en 5 secciones por lo que el admin viene a buscar. Las solapas
// siguen siendo las mismas (y `?tab=` sigue abriendo cualquiera): cambia cómo se llega a ellas.
// Una sección existe si el rol tiene al menos una de sus solapas.
const SECCIONES = [
  { key: 'resumen',   label: 'Resumen',             tabs: ['resumen'] },
  { key: 'salud',     label: 'Salud',               tabs: ['reprocann', 'indicaciones', 'turnos', 'historia', 'notas', 'documentos'] },
  { key: 'dispensas', label: 'Dispensas y cuenta',  tabs: ['dispensaciones', 'cuenta_corriente'] },
  { key: 'mensajes',  label: 'Mensajes',            tabs: ['chat', 'correo'] },
  { key: 'datos',     label: 'Datos y contacto',    tabs: ['info', 'direcciones', 'portal'] },
  { key: 'historial', label: 'Historial de la ficha', tabs: ['timeline'], chica: true },
]
const secciones = computed(() => SECCIONES
  .map(sec => ({ ...sec, visibles: sec.tabs.map(k => TABS.value.find(t => t.key === k)).filter(Boolean) }))
  .filter(sec => sec.visibles.length))
const seccionActual = computed(() => secciones.value.find(sec => sec.tabs.includes(activeTab.value)) || secciones.value[0])
// La última solapa que se abrió en cada sección: volver a «Salud» vuelve a donde estabas.
const ultimaDe = ref({})
watch(activeTab, (k) => { const sec = SECCIONES.find(x => x.tabs.includes(k)); if (sec) ultimaDe.value[sec.key] = k })
function irSeccion(sec) { activeTab.value = ultimaDe.value[sec.key] && sec.tabs.includes(ultimaDe.value[sec.key]) ? ultimaDe.value[sec.key] : sec.visibles[0].key }
function badgeSeccion(sec) {
  if (sec.key === 'salud')    return s.value?.renovacion_portal ? 1 : 0
  if (sec.key === 'mensajes') return chatSinLeer.value
  return 0
}

// «Para atender»: lo que espera algo de administración con este paciente, con el atajo a resolverlo.
const paraAtender = computed(() => {
  const items = []
  if (s.value?.pedidos_portal) items.push({ key: 'pedido', texto: s.value.pedidos_portal === 1 ? 'Pidió desde el portal: falta confirmar' : `${s.value.pedidos_portal} pedidos del portal para confirmar`, to: '/reservas?estado=solicitada' })
  if (s.value?.renovacion_portal && tieneTab('reprocann')) items.push({ key: 'renov', texto: 'Mandó su REPROCANN renovado', tab: 'reprocann' })
  if (chatSinLeer.value && tieneTab('chat')) items.push({ key: 'chat', texto: chatSinLeer.value === 1 ? '1 mensaje sin leer' : `${chatSinLeer.value} mensajes sin leer`, tab: 'chat' })
  return items
})

// Las dos cosas que más se hacen con un paciente, siempre a mano en la cabecera.
const dispRef = ref(null)
const puedeDispensar = computed(() => tieneTab('dispensaciones') && ['admin', 'dispensador', 'supervisor', 'super_admin'].includes(auth.user?.role) && !pendienteAprobacion.value)
function dispensar() {
  activeTab.value = 'dispensaciones'
  nextTick(() => dispRef.value?.openCreate?.('dispensa'))
}
const tabEscribir = computed(() => tieneTab('chat') ? 'chat' : tieneTab('correo') ? 'correo' : null)
const resumenRef = ref(null)

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
    // Las notas son clínicas (sólo admin y médico, `PacienteNotasController`): sin la solapa no se
    // piden. El badge de la solapa las contaba desde acá y el dispensador se comía el 403 igual.
    if (tieneTab('notas')) await store.fetchNotas(socioId)
  } catch {
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
            <h1 class="sd__hero-name">
              {{ s.nombre }} {{ s.apellido }}
              <span v-if="s.apodo" class="sd__apodo">«{{ s.apodo }}»</span>
            </h1>
            <div class="sd__hero-meta">
              <span>DNI {{ s.dni || '—' }}</span>
              <span v-if="edadSocio" class="sd__meta-sep">·</span>
              <span v-if="edadSocio">{{ edadSocio }} años</span>
            </div>
            <div class="sd__hero-badges">
              <template v-if="sit">
                <span v-if="reprocannSit(sit)" class="pf-pill" :class="`pf-pill--${reprocannSit(sit).nivel}`" :title="reprocannSit(sit).ayuda">
                  <i class="bi bi-patch-check"></i> REPROCANN · {{ reprocannSit(sit).label }}
                </span>
                <span v-if="pacienteSit(sit)" class="pf-pill" :class="`pf-pill--${pacienteSit(sit).nivel}`" :title="pacienteSit(sit).ayuda">
                  {{ pacienteSit(sit).label }}
                </span>
                <span v-if="vinculoSit(sit)" class="pf-pill pf-pill--off" :title="vinculoSit(sit).ayuda">{{ vinculoSit(sit).label }}</span>
              </template>
              <!-- El mostrador no recibe la situación (el REPROCANN no es asunto suyo): sólo activo/inactivo. -->
              <template v-else>
                <span v-if="pendienteAprobacion" class="pf-pill pf-pill--warn">Sin aprobar</span>
                <span v-else-if="!s.es_paciente" class="pf-pill pf-pill--off">Inactivo</span>
                <span v-else class="pf-pill pf-pill--ok">Activo</span>
              </template>
            </div>
          </div>
        </div>
        <div class="sd__hero-actions">
          <RouterLink v-if="s?.carnet_token" :to="`/c/${s.carnet_token}`" target="_blank" class="sd__btn-carnet">
            <CreditCard :size="14" :stroke-width="1.75" /> Carnet
          </RouterLink>
          <button v-if="canEditDatos" class="sd__btn-edit" @click="abrirEditar()">
            <Pencil :size="14" :stroke-width="1.75" /> Editar
          </button>
          <button v-if="tabEscribir" class="sd__btn-edit" data-testid="ficha-escribir" @click="activeTab = tabEscribir">
            <MessageCircle :size="14" :stroke-width="1.75" /> Escribirle
          </button>
          <button v-if="puedeDispensar" class="sd__btn-dispensar" data-testid="ficha-dispensar" @click="dispensar">
            <Pill :size="15" :stroke-width="2" /> Dispensar
          </button>
        </div>
      </div>

      <!-- Qué sigue con su REPROCANN, con las acciones de ese paso (19-oct-2026). -->
      <ProximoPasoReprocann v-if="sit" :paciente="s" :es-admin="isAdmin"
                            @cambio="store.refrescarActual(socioId)" @dar-turno="darTurno" />

      <!-- Alta cargada en el mostrador y todavía sin admitir. Va arriba de las tabs porque
           condiciona todo lo demás: se puede completar la ficha, pero no entregarle nada. -->
      <div v-if="pendienteAprobacion" class="sd__alerta sd__alerta--pend">
        <UserCheck :size="16" />
        <div class="sd__alerta-txt">
          <strong>Sin aprobar</strong> — Se cargó desde el mostrador. No puede recibir
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

      <!-- Lo que espera algo de administración con este paciente (28-oct-2026). -->
      <div v-if="paraAtender.length" class="sd__atender" data-testid="ficha-para-atender">
        <strong class="sd__atender-t">Para atender</strong>
        <template v-for="a in paraAtender" :key="a.key">
          <RouterLink v-if="a.to" :to="a.to" class="sd__atender-item">{{ a.texto }}</RouterLink>
          <button v-else type="button" class="sd__atender-item" @click="activeTab = a.tab">{{ a.texto }}</button>
        </template>
      </div>

      <div class="sd__cuerpo" :class="{ 'sd__cuerpo--sin-nav': secciones.length < 2 }">
      <!-- Secciones: 5 en vez de 15 solapas -->
      <nav v-if="secciones.length > 1" class="sd__secciones" aria-label="Secciones de la ficha" data-testid="ficha-secciones">
        <button v-for="sec in secciones" :key="sec.key" type="button" class="sd__sec"
                :class="{ 'sd__sec--on': seccionActual?.key === sec.key, 'sd__sec--chica': sec.chica }"
                :aria-current="seccionActual?.key === sec.key ? 'page' : undefined" @click="irSeccion(sec)">
          {{ sec.label }}
          <span v-if="badgeSeccion(sec)" class="sd__tab-badge">{{ badgeSeccion(sec) }}</span>
        </button>
      </nav>

      <div class="sd__contenido">
      <!-- Dentro de la sección, sus partes (sólo si tiene más de una) -->
      <div v-if="seccionActual && seccionActual.visibles.length > 1" class="sd__subtabs" role="tablist">
        <button v-for="tab in seccionActual.visibles" :key="tab.key" type="button" role="tab" class="sd__subtab"
                :class="{ 'sd__subtab--on': activeTab === tab.key }" :aria-selected="activeTab === tab.key" @click="activeTab = tab.key">
          {{ tab.label }}
          <span v-if="tab.key === 'chat' && chatSinLeer" class="sd__tab-badge" data-testid="chat-sin-leer">{{ chatSinLeer }}</span>
          <span v-if="tab.key === 'reprocann' && s.renovacion_portal" class="sd__tab-badge" title="Renovación para revisar">1</span>
          <span v-if="tab.key === 'notas' && store.notas.length" class="sd__tab-badge sd__tab-badge--gris">{{ store.notas.length }}</span>
        </button>
      </div>

      <!-- ── Resumen ── -->
      <div v-if="tieneTab('resumen') && activeTab === 'resumen'" class="sd__tab-content">
        <SocioResumen ref="resumenRef" :s="s" :tabs="TABS.map(t => t.key)" @ir="(k) => { if (k === 'turnos' && !tieneTab('turnos')) return; activeTab = k }" />
      </div>

      <!-- ── Tab: Datos ── -->
      <div v-if="tieneTab('info')" v-show="activeTab === 'info'" class="sd__tab-content">
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
              <div class="sd__info-label">Apodo</div>
              <div class="sd__info-val">{{ s.apodo || '—' }}</div>
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
        <!-- Los médicos que lo atienden (6-oct-2026). Administración vincula; el médico ve la lista. -->
        <div v-if="club.data?.features?.medico === true && (isAdmin || isMedico)" class="sd__card sd__card--pad">
          <SocioMedicos :paciente-id="socioId" :medicos="s.medicos || []" :puede-editar="isAdmin"
                        @cambio="store.refrescarActual(socioId)" />
        </div>
        <div class="sd__sys-info">
          <span>ID sistema: <strong>#{{ s.id }}</strong></span>
          <span>Registrado: <strong>{{ formatDate(s.created_at) }}</strong></span>
          <span>Actualizado: <strong>{{ formatDate(s.updated_at) }}</strong></span>
        </div>
      </div>

      <!-- ── Tab: REPROCANN ── -->
      <div v-if="tieneTab('reprocann')" v-show="activeTab === 'reprocann'" class="sd__tab-content">
        <!-- La renovación que subió el paciente desde su portal y espera revisión (27-oct-2026). -->
        <RenovacionPortalCard v-if="s.renovacion_portal" :socio-id="socioId" :renovacion="s.renovacion_portal"
                              :numero-actual="s.reprocann_numero || ''" :puede-revisar="canEdit"
                              @revisada="store.fetchOne(socioId)" />
        <div class="sd__card" :class="reprocannStatus?.key === 'danger' ? 'sd__card--danger' : reprocannStatus?.key === 'warning' ? 'sd__card--warning' : ''">
          <div class="sd__card-header">
            <div class="sd__card-icon sd__card-icon--green"><ShieldCheck :size="15" /></div>
            <span class="sd__card-title">Datos REPROCANN</span>
          </div>
          <div class="sd__info-grid">
            <div class="sd__info-item">
              <div class="sd__info-label">Estado REPROCANN</div>
              <div class="sd__info-val">
                <span v-if="reprocannSit(sit)" class="pf-pill" :class="`pf-pill--${reprocannSit(sit).nivel}`">{{ reprocannSit(sit).label }}</span>
                <span v-else class="sd__val-empty">—</span>
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
              <div class="sd__info-label">De quién es su REPROCANN</div>
              <div class="sd__info-val" :title="vinculoSit(sit)?.ayuda">{{ vinculoSit(sit)?.label || 'Sin dato' }}</div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Trámite</div>
              <div class="sd__info-val">
                <span v-if="s.reprocann_tramite_iniciado_el">Iniciado el {{ formatDate(s.reprocann_tramite_iniciado_el) }}</span>
                <span v-else class="sd__val-empty">Sin trámite registrado</span>
              </div>
            </div>
            <div class="sd__info-item">
              <div class="sd__info-label">Estado del paciente</div>
              <div class="sd__info-val">
                <span v-if="pacienteSit(sit)" class="pf-pill" :class="`pf-pill--${pacienteSit(sit).nivel}`" :title="pacienteSit(sit).ayuda">{{ pacienteSit(sit).label }}</span>
              </div>
            </div>
          </div>
          <div v-if="canEdit" class="sd__rep-editar">
            <button type="button" class="sd__btn-edit" @click="abrirEditar('reprocann')">
              <Pencil :size="14" :stroke-width="1.75" /> Corregir datos del REPROCANN
            </button>
            <span>Los pasos del trámite (iniciarlo, aprobado, no indicado…) se dan desde el recuadro de arriba.</span>
          </div>
          <div class="sd__card-note">
            <Info :size="12" />
            Vigencia del certificado: 3 años (Res. 1780/2025). Las ONG deben renovar anualmente.
          </div>
        </div>
      </div>

      <!-- ── Tab: Indicaciones ── -->
      <div v-if="tieneTab('indicaciones')" v-show="activeTab === 'indicaciones'" class="sd__tab-content">
        <div class="sd__card">
          <IndicacionesMedicas :socio-id="socioId" />
        </div>
      </div>

      <!-- ── Tab: Dispensaciones ── -->
      <div v-if="tieneTab('dispensaciones')" v-show="activeTab === 'dispensaciones'" class="sd__tab-content">
        <div class="sd__card">
          <Dispensaciones
            ref="dispRef"
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
      <div v-if="tieneTab('turnos')" v-show="activeTab === 'turnos'" class="sd__tab-content">
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
              <div class="sd__turno-dia">{{ fechaLocal(new Date(t.fecha_hora), { weekday: 'short', day: 'numeric', month: 'short' }) }}</div>
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
                  <AppDatePicker v-model="editForm.fecha" :min="hoyISO()" />
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

              <p v-if="editaAlPasado" class="sd__edit-warn" role="alert">
                Esa fecha y hora ya pasaron. Elegí un momento que todavía no haya llegado.
              </p>
              <div class="sd__edit-footer">
                <button class="sd__btn-ghost" @click="turnoEditando = null">Cancelar</button>
                <button class="sd__btn-primary" :disabled="editSaving || editaAlPasado" @click="guardarEdicion">
                  <DsSpinner v-if="editSaving" :size="13" />
                  <template v-else><RotateCcw :size="13" /> Guardar cambios</template>
                </button>
              </div>
            </div>
          </div>
        </Teleport>
      </div>

      <!-- ── Tab: Historia clínica ── -->
      <div v-if="tieneTab('historia')" v-show="activeTab === 'historia'" class="sd__tab-content">
        <SocioTabHistoria :socio-id="socioId" :s="s" />
      </div>

      <!-- ── Tab: Notas ── -->
      <div v-if="tieneTab('notas')" v-show="activeTab === 'notas'" class="sd__tab-content">
        <SocioTabNotas :socio-id="socioId" :can-edit="canEdit" />
      </div>

      <!-- ── Tab: Documentos ── -->
      <div v-if="tieneTab('documentos')" v-show="activeTab === 'documentos'" class="sd__tab-content">
        <div class="sd__card">
          <PatientDocuments :socio-id="socioId" :socio-nombre="`${s.nombre} ${s.apellido}`" />
        </div>
      </div>

      <!-- ── Tab: Timeline ── -->
      <div v-if="tieneTab('timeline')" v-show="activeTab === 'timeline'" class="sd__tab-content">
        <SocioTabTimeline :timeline="timeline" :timeline-loading="timelineLoading" />
      </div>

      <!-- ── Tab: Correo ── -->
      <div v-if="tabVisible('correo') && activeTab === 'correo'" class="sd__tab-content">
        <SocioTabCorreo :socio-id="socioId" :socio="s" @open-edit="editarOpen = true" />
      </div>

      <!-- ── Tab: Direcciones ── -->
      <div v-if="tabVisible('direcciones') && activeTab === 'direcciones'" class="sd__tab-content">
        <SocioTabDirecciones :socio-id="socioId" />
      </div>

      <!-- ── Tab: Chat del portal ── -->
      <div v-if="tieneTab('chat') && activeTab === 'chat'" class="sd__tab-content">
        <div class="sd__chat">
          <ChatConPaciente :paciente-id="socioId" :nombre="s.nombre_completo" />
        </div>
      </div>

      <!-- ── Tab: Acceso al portal ── -->
      <div v-if="tabVisible('portal') && activeTab === 'portal'" class="sd__tab-content">
        <SocioTabPortal :socio-id="socioId" :nombre="s.nombre_completo" :acceso="s.acceso"
                        @actualizado="store.fetchOne(socioId)" />
      </div>
      </div><!-- /sd__contenido -->
      </div><!-- /sd__cuerpo -->

    </template>

  <!-- El link del portal al aprobar el alta (cualquier solapa puede estar abierta). -->
  <LinkPortalNuevo :datos="linkPortal" @cerrar="linkPortal = null" />

  <SocioEditarModal v-if="canEdit" v-model:open="editarOpen" :socio-id="socioId" :solapa="editarSolapa" @saved="store.fetchOne(socioId)" />

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
  </div>
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
.sd__status-badge--susp { background: var(--c-amber-100); color: var(--c-amber-500); border: 1px dashed var(--c-amber-500); cursor: help; }
.sd__val-susp { color: var(--c-amber-500); font-weight: 600; }
.sd__apodo { font-size: 1rem; font-weight: 600; color: var(--c-slate-500); letter-spacing: 0; margin-left: .35rem; }
.sd__status-badge--entrevista { background: var(--c-amber-100); color: var(--c-amber-500); border: 1px solid var(--c-amber-500); cursor: help; }
.sd__status-badge--falto { background: var(--c-slate-100); color: var(--c-slate-600); border: 1px dashed var(--c-slate-400); cursor: help; }
.sd__status-badge--vinculo { background: var(--c-leaf-50); color: var(--c-leaf-800); border: 1px solid var(--c-leaf-100); }
.sd__card--pad { padding: 1rem 1.25rem; }
.sd__vinculo-select { max-width: 100%; min-height: 34px; border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: 0 .5rem; font-size: .85rem; background: var(--c-paper); }
.sd__tramite { display: flex; align-items: center; flex-wrap: wrap; gap: .6rem; }
.sd__btn-tramite { min-height: 32px; padding: 0 .85rem; white-space: nowrap; border-radius: 8px; border: 1.5px solid var(--c-leaf-800); background: transparent; color: var(--c-leaf-800); font-weight: 700; font-size: .8rem; cursor: pointer; }
.sd__btn-tramite:hover:not(:disabled) { background: var(--c-leaf-50); }
.sd__btn-tramite:disabled { opacity: .5; cursor: not-allowed; }

/* Secciones (28-oct-2026) */
.sd__cuerpo { display: grid; grid-template-columns: 220px minmax(0, 1fr); gap: 1.5rem; align-items: start; margin-top: .25rem; }
.sd__cuerpo--sin-nav { grid-template-columns: minmax(0, 1fr); }
.sd__secciones { display: flex; flex-direction: column; gap: 2px; position: sticky; top: 1rem; }
.sd__sec { display: flex; align-items: center; justify-content: space-between; gap: .5rem; min-height: 44px; padding: 0 .85rem;
  border: none; border-radius: 10px; background: none; color: var(--c-slate-700); font: inherit; font-size: .95rem; font-weight: 500; text-align: left; cursor: pointer; }
.sd__sec:hover { background: var(--c-slate-100); }
.sd__sec--on { background: var(--c-leaf-100); color: var(--c-leaf-900); font-weight: 700; }
.sd__sec--chica { margin-top: .6rem; padding-top: .6rem; border-top: 1px solid var(--c-slate-200); border-radius: 0; font-size: .85rem; color: var(--c-slate-500); }
.sd__sec--chica.sd__sec--on { border-radius: 10px; }
.sd__contenido { min-width: 0; }
.sd__subtabs { display: flex; flex-wrap: wrap; gap: .4rem; margin-bottom: 1rem; }
.sd__subtab { display: inline-flex; align-items: center; gap: .35rem; min-height: 36px; padding: 0 .9rem; border-radius: 999px;
  border: 1px solid var(--c-slate-300); background: var(--c-surface, #fff); color: var(--c-slate-700); font: inherit; font-size: .875rem; font-weight: 500; cursor: pointer; }
.sd__subtab:hover { border-color: var(--c-leaf-500); }
.sd__subtab--on { background: var(--c-leaf-800); border-color: var(--c-leaf-800); color: #fff; }
.sd__tab-badge--gris { background: var(--c-slate-200) !important; color: var(--c-slate-700) !important; }
.sd__atender { display: flex; flex-wrap: wrap; align-items: center; gap: .4rem 1.4rem; padding: .8rem 1.1rem; margin-bottom: 1.25rem;
  background: var(--c-amber-100); border: 1px solid #f3dcae; border-radius: 12px; }
.sd__atender-t { font-size: .9rem; color: #7a4a0b; }
.sd__atender-item { padding: 0; border: none; background: none; font: inherit; font-size: .9rem; color: #7a4a0b; text-decoration: underline; cursor: pointer; min-height: 32px; }
.sd__btn-dispensar { display: inline-flex; align-items: center; gap: .4rem; min-height: 40px; padding: 0 1.1rem; border: none; border-radius: 10px;
  background: var(--c-leaf-800); color: #fff; font: inherit; font-size: .9rem; font-weight: 700; cursor: pointer; }
.sd__btn-dispensar:hover { background: var(--c-leaf-900); }
@media (max-width: 860px) {
  .sd__cuerpo { grid-template-columns: minmax(0, 1fr); gap: .75rem; }
  .sd__secciones { position: static; flex-direction: row; overflow-x: auto; gap: .35rem; padding-bottom: .25rem; scrollbar-width: none; }
  .sd__sec { flex: 0 0 auto; white-space: nowrap; border: 1px solid var(--c-slate-200); }
  .sd__sec--chica { margin-top: 0; padding-top: 0; border-radius: 10px; }
}

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

/* Contadores de las secciones y sus partes */
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
.sd__rep-editar { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem 1rem; padding: .9rem 1.25rem; border-top: 1px solid var(--c-slate-100); font-size: .78rem; color: var(--c-slate-500); }
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

.sd__edit-warn { margin: 0 20px 8px; font-size: var(--fs-12); color: var(--c-rust-600); }
.sd__chat { height: min(70vh, 720px); min-height: 460px; border: 1px solid var(--c-slate-200); border-radius: 12px; overflow: hidden; }
</style>
