<script setup>
import { ref, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useUsuariosStore } from "../stores/usuarios"
import { useAuthStore } from "../stores/auth"
import UsuarioSalasManager  from '../components/UsuarioSalasManager.vue'
import UsuarioSedesManager  from '../components/UsuarioSedesManager.vue'
import MedicoCalendarioWidget from '../components/medico/MedicoCalendarioWidget.vue'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import Paginator from '../components/ui/Paginator.vue'
import CredencialesNuevas from '../components/ui/CredencialesNuevas.vue'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import { getUsuarioStats, getUsuarioAuditorias, recibirCajaDelivery, listJornadas, confirmarJornadas, reabrirJornadas, resetUserPassword } from '../lib/api.js'
import { ROLES as ROLES_DS, rolInfo, rolColor, rolBg } from '../lib/roles.js'

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
// Qué roles se acotan por sede sale de la misma fuente que todo lo demás.
const ROLES_CON_SEDES = ROLES_DS.filter(r => r.sedes).map(r => r.value)
// Roles con módulo propio en la columna main

// Metadata de roles: una sola fuente (lib/roles.js). Acá vivía una copia con descripciones
// distintas de las de la lista de Equipo, para los mismos roles.
const ROLES     = ROLES_DS
const PERMISOS  = Object.fromEntries(ROLES_DS.map(r => [r.value, r.permisos || []]))
const SEDE_HINTS = Object.fromEntries(
  ROLES_DS.filter(r => r.sedes).map(r => [r.value, r.sedes.hint]))


const AVATAR_COLORS = ['#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626','#15803d']

// El color sale de los tokens del DS (`--c-role-<rol>`), no de hexadecimales sueltos.
function roleInfo(role) {
  return { ...rolInfo(role), color: rolColor(role), bg: rolBg(role) }
}
function getInitials(user) {
  if (!user) return '?'
  return ((user.first_name?.[0] || '') + (user.last_name?.[0] || '')).toUpperCase() || user.email?.[0]?.toUpperCase() || '?'
}
function getAvatarColor(user) { return AVATAR_COLORS[(user?.id || 0) % AVATAR_COLORS.length] }
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}

// ── Restablecer contraseña ──────────────────────────────────────────────
// "Me olvidé la contraseña" es lo que más se pide de esta pantalla y no había forma de
// resolverlo: el endpoint existía sin estar enchufado a nada. La clave se muestra para poder
// dictarla, porque el mail sólo sale si la organización tiene el correo configurado.
const reseteando  = ref(false)
const credenciales = ref(null)

async function resetearPassword() {
  const ok = await confirm({
    title: `Restablecer la contraseña de ${u.value?.first_name || 'este usuario'}`,
    message: 'Se genera una contraseña nueva y la actual deja de funcionar en el acto. Vas a poder verla y copiarla para dársela.',
    confirmText: 'Generar contraseña',
  })
  if (!ok) return
  reseteando.value = true
  try {
    const { data } = await resetUserPassword(userId)
    credenciales.value = { ...data, nombre: u.value?.first_name || u.value?.email }
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo restablecer la contraseña')
  } finally {
    reseteando.value = false
  }
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

// ── Estadísticas ──────────────────────────────────────────────
const hoy = new Date()
const statsAnio = ref(hoy.getFullYear())
const statsMes  = ref(hoy.getMonth() + 1)
const stats     = ref(null)
const loadingStats = ref(false)
const puedeVerStats = computed(() => ['admin', 'supervisor'].includes(auth.role))

const MESES = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre']
const statsLabelMes = computed(() => `${MESES[statsMes.value-1]} ${statsAnio.value}`)
const statsEsMesActual = computed(() => statsAnio.value === hoy.getFullYear() && statsMes.value === hoy.getMonth()+1)

async function cargarStats() {
  if (!puedeVerStats.value) return
  loadingStats.value = true
  try {
    const { data } = await getUsuarioStats(userId, { anio: statsAnio.value, mes: statsMes.value })
    stats.value = data
  } catch { stats.value = null } finally { loadingStats.value = false }
}

// ── Horas del mes: confirmación por el admin/supervisor ────────────────────
const puedeConfirmarHoras = computed(() => ['admin', 'supervisor', 'super_admin'].includes(auth.role))
const jornadas        = ref([])
const loadingJornadas = ref(false)
const selJornadas     = ref([])   // ids seleccionados
const confirmandoHoras = ref(false)

const jornadasPendientes = computed(() => jornadas.value.filter(j => j.estado !== 'confirmada'))
const todasPendSeleccionadas = computed(() =>
  jornadasPendientes.value.length > 0 && jornadasPendientes.value.every(j => selJornadas.value.includes(j.id)))

async function cargarJornadas() {
  if (!puedeConfirmarHoras.value) return
  loadingJornadas.value = true
  selJornadas.value = []
  try {
    const { data } = await listJornadas({ user_id: userId, anio: statsAnio.value, mes: statsMes.value })
    jornadas.value = (data.jornadas || []).sort((a, b) => a.fecha.localeCompare(b.fecha))
  } catch { jornadas.value = [] } finally { loadingJornadas.value = false }
}

function toggleSelJornada(id) {
  const i = selJornadas.value.indexOf(id)
  if (i >= 0) selJornadas.value.splice(i, 1); else selJornadas.value.push(id)
}
function toggleTodasPendientes() {
  selJornadas.value = todasPendSeleccionadas.value ? [] : jornadasPendientes.value.map(j => j.id)
}

async function confirmarHoras(ids) {
  if (!ids.length) return
  confirmandoHoras.value = true
  try {
    const { data } = await confirmarJornadas(ids)
    toast.success(`${data.confirmadas} jornada${data.confirmadas !== 1 ? 's' : ''} confirmada${data.confirmadas !== 1 ? 's' : ''}`)
    await cargarJornadas()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudieron confirmar')
  } finally { confirmandoHoras.value = false }
}
function confirmarSeleccionadas() { confirmarHoras([...selJornadas.value]) }
function confirmarTodoElMes()     { confirmarHoras(jornadasPendientes.value.map(j => j.id)) }

async function reabrirHora(j) {
  const ok = await confirm({ title: 'Reabrir jornada',
    message: `Vas a reabrir la jornada del ${j.fecha}. Vuelve a estado pendiente y el usuario podrá editarla.`,
    confirmText: 'Reabrir' })
  if (!ok) return
  try {
    await reabrirJornadas([j.id])
    toast.success('Jornada reabierta')
    await cargarJornadas()
  } catch (e) { toast.error(e?.response?.data?.error || 'No se pudo reabrir') }
}

// ── Caja del delivery (efectivo en mano) ──────────────────────────────────
const recibiendoCaja = ref(false)
const fmtARS = (n) => '$' + (Number(n) || 0).toLocaleString('es-AR', { minimumFractionDigits: 0, maximumFractionDigits: 2 })
const cajaEfectivo = computed(() => stats.value?.caja_delivery?.efectivo_en_mano || 0)
const cajaCobros   = computed(() => stats.value?.caja_delivery?.cobros_pendientes || 0)
const cajaEnViaje  = computed(() => stats.value?.caja_delivery?.en_viaje || 0)
// Lo que se quedó al rendir la caja, acumulado. No es una pérdida del club: esa plata existe y
// está con una persona — por eso se muestra como saldo y no como gasto.
const aCuenta = computed(() => stats.value?.a_cuenta || { total_ars: 0, veces: 0, detalle: [] })
const fmtFechaCorta = (f) => (f ? new Date(f).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' }) : '')

async function recibirCaja() {
  if (cajaEfectivo.value <= 0) return
  recibiendoCaja.value = true
  try {
    const { data } = await recibirCajaDelivery(userId)
    toast.success(`Caja recibida: ${fmtARS(data.recibido_ars)} (${data.cobros} cobro${data.cobros !== 1 ? 's' : ''})`)
    await cargarStats()
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo recibir la caja')
  } finally { recibiendoCaja.value = false }
}
function cambiarMesStats(delta) {
  let m = statsMes.value + delta, a = statsAnio.value
  if (m < 1) { m = 12; a-- } else if (m > 12) { m = 1; a++ }
  if (a > hoy.getFullYear() || (a === hoy.getFullYear() && m > hoy.getMonth()+1)) return
  statsMes.value = m; statsAnio.value = a
  cargarStats()
  cargarJornadas()
}
const MEDIO_LABEL = { efectivo: 'Efectivo', transferencia: 'Transferencia', cuenta_corriente: 'Cuenta corriente', no_abona: 'No abona', credito_gramos: 'Crédito gramos' }

// ── Historial de actividad (audit log, read-only) ─────────────────────────
// Solo admin: el endpoint es admin-only (require_admin!). No es editable ni borrable.
const esAdmin = computed(() => auth.role === 'admin')
const audits        = ref([])
const auditsPage    = ref(1)
const auditsPerPage = ref(10)
const auditsTotal   = ref(0)
const loadingAudits = ref(false)
const auditsFiltro  = ref({ desde: '', hasta: '', tipo: '' })
const hayFiltro     = computed(() => !!(auditsFiltro.value.desde || auditsFiltro.value.hasta || auditsFiltro.value.tipo))
const TIPO_OPCIONES = [
  { v: '', l: 'Todos los tipos' }, { v: 'Lote', l: 'Lote' }, { v: 'Plant', l: 'Planta' },
  { v: 'Stock', l: 'Stock' }, { v: 'Dispensacion', l: 'Dispensación' },
  { v: 'Paciente', l: 'Paciente' }, { v: 'User', l: 'Usuario' }, { v: 'Reserva', l: 'Reserva' },
]

const ACCION_INFO = {
  crear:      { label: 'Creó',    icon: 'bi-plus-circle-fill',   cls: 'act--new' },
  actualizar: { label: 'Editó',   icon: 'bi-pencil-fill',        cls: 'act--edit' },
  eliminar:   { label: 'Eliminó', icon: 'bi-trash-fill',         cls: 'act--del' },
}
// Nombres lindos para los campos más habituales; el resto se humaniza (guiones bajos → espacios).
const CAMPO_LABEL = {
  tamano_maceta: 'tamaño de maceta', tamaño_maceta: 'tamaño de maceta',
  precio_sugerido_ars: 'precio sugerido', costo_unitario_ars: 'costo unitario',
  sala_id: 'sala', sede_id: 'sede', genetica_id: 'genética', estado: 'estado',
  codigo: 'código', descripcion: 'descripción', categoria: 'categoría',
  medio_pago: 'medio de pago', cantidad: 'cantidad', notas: 'notas', nombre: 'nombre',
  // Fase 2: paciente / usuario / reserva
  apellido: 'apellido', fecha_nacimiento: 'fecha de nacimiento',
  reprocann_vencimiento: 'venc. REPROCANN', reprocann_estado: 'estado REPROCANN',
  role: 'rol', first_name: 'nombre', last_name: 'apellido', email_personal: 'email personal',
  fecha_entrega_estimada: 'fecha de entrega', sena_ars: 'seña', aporte_estimado_ars: 'aporte estimado',
  con_envio: 'con envío', direccion_envio: 'dirección de envío', contacto_nombre: 'contacto',
  contacto_telefono: 'tel. de contacto',
}
function labelCampo(c) { return CAMPO_LABEL[c] || String(c).replace(/_/g, ' ') }
function formatVal(v) {
  if (v === null || v === undefined || v === '') return '—'
  if (v === true) return 'Sí'
  if (v === false) return 'No'
  return String(v)
}
function fechaAudit(d) {
  const dt = new Date(d)
  return dt.toLocaleDateString('es-AR', { day: 'numeric', month: 'short' }) + ' · ' +
         dt.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

async function cargarAudits() {
  if (!esAdmin.value) return
  loadingAudits.value = true
  try {
    const { data } = await getUsuarioAuditorias(userId, {
      page:     auditsPage.value,
      per_page: auditsPerPage.value,
      tipo:     auditsFiltro.value.tipo || undefined,
      desde:    auditsFiltro.value.desde || undefined,
      hasta:    auditsFiltro.value.hasta || undefined,
    })
    audits.value        = data.data || []
    auditsTotal.value   = data.total || 0
    auditsPerPage.value = data.per_page || auditsPerPage.value
  } catch { audits.value = []; auditsTotal.value = 0 }
  finally { loadingAudits.value = false }
}
function aplicarFiltro()   { auditsPage.value = 1; cargarAudits() }
function limpiarFiltro()   { auditsFiltro.value = { desde: '', hasta: '', tipo: '' }; aplicarFiltro() }
function irAPagina(p)      { auditsPage.value = p; cargarAudits() }
function cambiarPerPage(pp){ auditsPerPage.value = pp; auditsPage.value = 1; cargarAudits() }

onMounted(async () => {
  try { await store.fetchOne(userId) }
  catch { error.value = 'No se pudo cargar el usuario.' }
  finally { loading.value = false }
  cargarStats()
  cargarJornadas()
  cargarAudits()
})
</script>

<template>
  <div class="ud">

    <Breadcrumb :items="[{ label: 'Equipo', to: { name: 'usuarios' } }, { label: u ? `${u.first_name} ${u.last_name}` : `Usuario #${userId}` }]" />

    <CredencialesNuevas :datos="credenciales" @cerrar="credenciales = null" />

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
            <button v-if="canEdit" class="ud__btn-edit-hero" @click="resetearPassword" :disabled="reseteando">
              <i class="bi bi-key"></i> {{ reseteando ? 'Generando…' : 'Restablecer contraseña' }}
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

          <!-- Estadísticas del usuario -->
          <div v-if="puedeVerStats" class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(26,61,46,.1);color:#1a3d2e">
                <i class="bi bi-bar-chart-line"></i>
              </div>
              <span class="ud__card-title">Estadísticas</span>
              <div class="uds__monthnav">
                <button class="uds__nav" @click="cambiarMesStats(-1)"><i class="bi bi-chevron-left"></i></button>
                <span class="uds__month">{{ statsLabelMes }}</span>
                <button class="uds__nav" :disabled="statsEsMesActual" @click="cambiarMesStats(1)"><i class="bi bi-chevron-right"></i></button>
              </div>
            </div>
            <div class="ud__card-body">
              <div v-if="loadingStats" class="uds__loading"><DsSpinner :size="22" /></div>
              <div v-else-if="stats" class="uds__grid">
                <div class="uds__stat">
                  <span class="uds__val">{{ stats.horas.total }}<small>hs</small></span>
                  <span class="uds__lbl">Horas trabajadas</span>
                  <span class="uds__sub">{{ stats.horas.dias }} día{{ stats.horas.dias !== 1 ? 's' : '' }}</span>
                </div>
                <div v-if="u.role === 'manicura'" class="uds__stat">
                  <span class="uds__val">{{ stats.produccion.gramos }}<small>g</small></span>
                  <span class="uds__lbl">Producción</span>
                  <span class="uds__sub">{{ stats.produccion.pesajes }} pesaje{{ stats.produccion.pesajes !== 1 ? 's' : '' }}</span>
                </div>
                <div v-if="stats.despachos.total > 0" class="uds__stat">
                  <span class="uds__val">{{ stats.despachos.total }}</span>
                  <span class="uds__lbl">Despachos</span>
                  <span class="uds__sub">{{ stats.despachos.entregados }} entreg. · {{ stats.despachos.fallidos }} fall.</span>
                </div>
                <div v-if="stats.dispensaciones.total > 0" class="uds__stat">
                  <span class="uds__val">{{ stats.dispensaciones.total }}</span>
                  <span class="uds__lbl">Dispensaciones</span>
                  <span class="uds__sub">{{ stats.dispensaciones.gramos }}g entregados</span>
                </div>
                <!-- Desglose por medio de pago -->
                <div v-if="stats.dispensaciones.total > 0" class="uds__medios">
                  <span class="uds__medios-title">Por medio de pago</span>
                  <div class="uds__medios-list">
                    <span v-for="(n, medio) in stats.dispensaciones.por_medio" :key="medio" class="uds__medio">
                      {{ MEDIO_LABEL[medio] || medio }}: <strong>{{ n }}</strong>
                    </span>
                  </div>
                </div>
              </div>
              <p v-else class="uds__empty">Sin datos para este período.</p>
            </div>
          </div>

          <!-- Horas del mes: confirmación (admin/supervisor) -->
          <div v-if="puedeConfirmarHoras" class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(180,83,9,.1);color:#b45309">
                <i class="bi bi-clock-history"></i>
              </div>
              <span class="ud__card-title">Horas de {{ statsLabelMes }}</span>
              <span class="ud__card-hint">{{ jornadasPendientes.length }} pendiente{{ jornadasPendientes.length !== 1 ? 's' : '' }}</span>
            </div>
            <div class="ud__card-body">
              <div v-if="loadingJornadas" class="uds__loading"><DsSpinner :size="22" /></div>
              <template v-else-if="jornadas.length">
                <div class="udh__head">
                  <label class="udh__all">
                    <input type="checkbox" :checked="todasPendSeleccionadas" :disabled="!jornadasPendientes.length" @change="toggleTodasPendientes" />
                    Seleccionar pendientes
                  </label>
                  <span class="udh__sel">{{ selJornadas.length }} sel.</span>
                </div>
                <div class="udh__list">
                  <div v-for="j in jornadas" :key="j.id" class="udh__row" :class="{ 'udh__row--conf': j.estado === 'confirmada' }">
                    <input type="checkbox" :checked="selJornadas.includes(j.id)" :disabled="j.estado === 'confirmada'" @change="toggleSelJornada(j.id)" />
                    <span class="udh__fecha">{{ j.fecha }}</span>
                    <span class="udh__horario">{{ j.hora_entrada }}–{{ j.hora_salida }}</span>
                    <span class="udh__hs">{{ j.horas }}h</span>
                    <span class="udh__estado" :class="j.estado === 'confirmada' ? 'udh__estado--ok' : 'udh__estado--pend'">
                      {{ j.estado === 'confirmada' ? 'Confirmada' : 'Pendiente' }}
                    </span>
                    <button v-if="j.estado === 'confirmada'" class="udh__reabrir" title="Reabrir" @click="reabrirHora(j)"><i class="bi bi-unlock"></i></button>
                    <span v-else class="udh__reabrir-ph"></span>
                  </div>
                </div>
                <div class="udh__actions">
                  <button class="udh__btn" :disabled="confirmandoHoras || !selJornadas.length" @click="confirmarSeleccionadas">Confirmar seleccionadas</button>
                  <button class="udh__btn udh__btn--primary" :disabled="confirmandoHoras || !jornadasPendientes.length" @click="confirmarTodoElMes">Confirmar todo el mes</button>
                </div>
              </template>
              <p v-else class="uds__empty">Sin horas cargadas este mes.</p>
            </div>
          </div>

          <!-- Historial de actividad (audit log, read-only, solo admin) -->
          <div v-if="esAdmin" class="ud__card ud__card--mt">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(71,85,105,.1);color:#475569">
                <i class="bi bi-clock-history"></i>
              </div>
              <span class="ud__card-title">Historial de actividad</span>
              <span class="ud__card-hint">{{ auditsTotal }} acción{{ auditsTotal !== 1 ? 'es' : '' }} · solo lectura</span>
            </div>
            <div class="ud__card-body">
              <!-- Filtros -->
              <div class="uda__filtros">
                <label class="uda__f">
                  <span>Desde</span>
                  <input type="date" v-model="auditsFiltro.desde" class="uda__inp" @change="aplicarFiltro" />
                </label>
                <label class="uda__f">
                  <span>Hasta</span>
                  <input type="date" v-model="auditsFiltro.hasta" class="uda__inp" @change="aplicarFiltro" />
                </label>
                <label class="uda__f">
                  <span>Tipo</span>
                  <select v-model="auditsFiltro.tipo" class="uda__inp" @change="aplicarFiltro">
                    <option v-for="o in TIPO_OPCIONES" :key="o.v" :value="o.v">{{ o.l }}</option>
                  </select>
                </label>
                <button v-if="hayFiltro" class="uda__clear" @click="limpiarFiltro">
                  <i class="bi bi-x-lg"></i> Limpiar
                </button>
              </div>

              <div v-if="loadingAudits" class="uds__loading"><DsSpinner :size="22" /></div>
              <p v-else-if="!audits.length" class="uds__empty">
                {{ hayFiltro ? 'Sin actividad para estos filtros.' : 'Sin actividad registrada todavía.' }}
              </p>
              <template v-else>
                <div class="uda__table-wrap">
                  <table class="uda__table">
                    <thead>
                      <tr>
                        <th>Fecha</th><th>Acción</th><th>Tipo</th><th>Registro</th><th>Cambios</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="a in audits" :key="a.id">
                        <td class="uda__td-fecha">{{ fechaAudit(a.fecha) }}</td>
                        <td>
                          <span class="uda__chip" :class="(ACCION_INFO[a.accion] || {}).cls">
                            <i :class="['bi', (ACCION_INFO[a.accion] || {}).icon]"></i>
                            {{ (ACCION_INFO[a.accion] || {}).label || a.accion }}
                          </span>
                        </td>
                        <td>{{ a.tipo }}</td>
                        <td class="uda__ref">#{{ a.registro_id }}</td>
                        <td>
                          <ul v-if="a.cambios && a.cambios.length" class="uda__diffs">
                            <li v-for="(c, i) in a.cambios" :key="i" class="uda__diff">
                              <span class="uda__campo">{{ labelCampo(c.campo) }}:</span>
                              <span class="uda__de">{{ formatVal(c.de) }}</span>
                              <i class="bi bi-arrow-right"></i>
                              <span class="uda__a">{{ formatVal(c.a) }}</span>
                            </li>
                          </ul>
                          <span v-else class="uda__nodiff">—</span>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <Paginator
                  :page="auditsPage" :per-page="auditsPerPage" :total="auditsTotal"
                  @update:page="irAPagina" @update:perPage="cambiarPerPage"
                />
              </template>
            </div>
          </div>

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

          <!-- Delivery → Caja (efectivo en mano) -->
          <div v-if="u.role === 'delivery'" class="ud__card">
            <div class="ud__card-hdr">
              <div class="ud__card-ico" style="background:rgba(21,128,61,.1);color:#15803d">
                <i class="bi bi-cash-stack"></i>
              </div>
              <span class="ud__card-title">Caja del delivery</span>
              <span class="ud__card-hint">Efectivo cobrado en entregas, pendiente de rendir</span>
            </div>
            <div class="udc">
              <div class="udc__monto">
                <span class="udc__monto-lbl">Efectivo en mano</span>
                <span class="udc__monto-val">{{ fmtARS(cajaEfectivo) }}</span>
                <span class="udc__monto-sub">{{ cajaCobros }} cobro{{ cajaCobros !== 1 ? 's' : '' }} · {{ cajaEnViaje }} en viaje</span>
              </div>
              <button v-if="canEdit" class="udc__btn" :disabled="recibiendoCaja || cajaEfectivo <= 0" @click="recibirCaja">
                <DsSpinner v-if="recibiendoCaja" :size="14" />
                <template v-else><i class="bi bi-check2-circle"></i> Recibir caja</template>
              </button>
            </div>
            <p class="udc__hint">Al recibir la caja, el efectivo se asienta en contabilidad como ingreso y se marca como rendido.</p>

            <!-- Lo que se quedó al rendir, acumulado. Sin verlo junto, cada faltante parece un
                 caso aislado y nadie nota que van seis meses seguidos. -->
            <div v-if="aCuenta.veces" class="udc__acuenta">
              <div class="udc__acuenta-hdr">
                <span class="udc__acuenta-lbl">Tiene del club</span>
                <span class="udc__acuenta-val">{{ fmtARS(aCuenta.total_ars) }}</span>
              </div>
              <p class="udc__acuenta-sub">
                En {{ aCuenta.veces }} rendici{{ aCuenta.veces === 1 ? 'ón' : 'ones' }}. No es una
                pérdida: esa plata está con él y se reclama.
              </p>
              <ul class="udc__acuenta-lista">
                <li v-for="m in aCuenta.detalle" :key="m.id">
                  <span class="udc__acuenta-fecha">{{ fmtFechaCorta(m.fecha) }}</span>
                  <span class="udc__acuenta-monto">{{ fmtARS(m.monto_ars) }}</span>
                  <span class="udc__acuenta-desc">{{ m.descripcion }}</span>
                </li>
              </ul>
            </div>
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
                Sin sedes asignadas = accede a toda la organización
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
                Sin sedes = acceso a toda la organización
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
.ud { padding: 1.5rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: var(--c-slate-900); }
@media (max-width: 768px) { .ud { padding: 1rem 1rem 2rem; } }

/* Loading / Error */
.ud__loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.ud__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem; border-radius: 10px; margin-top: 1rem; }

/* ── Hero ── */
.ud__hero {
  border-radius: 18px;
  border: 1px solid var(--c-slate-200);
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
.ud__btn-edit-hero:hover { background: #fff; border-color: var(--c-slate-400); }

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
  font-size: 1.6rem; font-weight: 800; color: var(--c-slate-900);
  letter-spacing: -.04em; line-height: 1.15;
  margin-bottom: .3rem;
  display: flex; align-items: center; gap: .65rem;
}
.ud__me-badge {
  font-size: .6rem; font-weight: 700; background: var(--c-slate-100); color: var(--c-slate-500);
  padding: .2em .65em; border-radius: 5px; letter-spacing: .05em; text-transform: uppercase;
}
.ud__email { font-size: .875rem; color: var(--c-slate-500); margin-bottom: .55rem; }
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
  font-size: .75rem; color: var(--c-slate-500); font-weight: 500;
}
.ud__strip-item i { font-size: .8rem; }
.ud__strip-item--role { color: #15803d; font-weight: 600; }

/* ── Body layout ── */
.ud__body { display: grid; grid-template-columns: 1fr 280px; gap: 1.5rem; align-items: start; }
@media (max-width: 960px) { .ud__body { grid-template-columns: 1fr; } }
.ud__main { display: flex; flex-direction: column; }
.ud__aside { display: flex; flex-direction: column; gap: 0; position: sticky; top: 1.5rem; }

/* ── Cards ── */
.ud__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.ud__card--mt { margin-top: 1.25rem; }
.ud__aside .ud__card + .ud__card { margin-top: 1rem; }

/* Caja del delivery */
.udc { display: flex; align-items: center; gap: 1rem; padding: 1rem; }
.udc__monto { display: flex; flex-direction: column; gap: 2px; flex: 1; }
.udc__monto-lbl { font-size: .72rem; font-weight: 600; color: var(--c-slate-500); text-transform: uppercase; letter-spacing: .04em; }
.udc__monto-val { font-size: 1.6rem; font-weight: 800; letter-spacing: -.03em; color: #15803d; font-variant-numeric: tabular-nums; }
.udc__monto-sub { font-size: .75rem; color: var(--c-slate-400); }
.udc__btn { display: inline-flex; align-items: center; gap: .4rem; background: #15803d; color: #fff; border: none; border-radius: 9px; padding: .6rem 1rem; font-size: .85rem; font-weight: 700; cursor: pointer; white-space: nowrap; }
.udc__btn:hover:not(:disabled) { background: #14532d; }
.udc__btn:disabled { opacity: .45; cursor: not-allowed; }
/* Lo que el repartidor tiene del club. Ámbar y no rojo: no es una pérdida, es un saldo. */
.udc__acuenta { margin-top: 12px; padding-top: 12px; border-top: 1px solid rgba(0,0,0,.06); }
.udc__acuenta-hdr { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; }
.udc__acuenta-lbl { font-size: .8rem; font-weight: 700; color: #92400e; }
.udc__acuenta-val { font-size: 1.05rem; font-weight: 800; color: #92400e; font-variant-numeric: tabular-nums; }
.udc__acuenta-sub { margin: 4px 0 8px; font-size: .75rem; color: #6b7280; }
.udc__acuenta-lista { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 4px; }
.udc__acuenta-lista li { display: flex; gap: 8px; font-size: .75rem; color: #4b5563; align-items: baseline; }
.udc__acuenta-fecha { font-variant-numeric: tabular-nums; color: #9ca3af; flex-shrink: 0; }
.udc__acuenta-monto { font-weight: 700; font-variant-numeric: tabular-nums; flex-shrink: 0; }
.udc__acuenta-desc { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.udc__hint { font-size: .72rem; color: var(--c-slate-400); padding: 0 1rem 1rem; margin: 0; line-height: 1.4; }
.ud__card-hdr {
  display: flex; align-items: center; gap: .65rem;
  padding: .875rem 1.25rem;
  border-bottom: 1px solid var(--c-slate-100);
  background: #fafbfc;
}
.ud__card-ico {
  width: 30px; height: 30px; border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: .8rem; flex-shrink: 0;
}
.ud__card-title { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); flex: 1; }
.ud__card-hint { font-size: .7rem; color: var(--c-slate-400); font-weight: 500; }
.ud__card-body { padding: 1.25rem; }

.ud__field { display: flex; flex-direction: column; gap: .35rem; }
.ud__field-label { font-size: .7rem; font-weight: 700; color: var(--c-slate-500); text-transform: uppercase; letter-spacing: .04em; }
.ud__input {
  background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px;
  padding: .6rem .875rem; font-size: .875rem; color: var(--c-slate-900);
  outline: none; transition: border .15s, background .15s; width: 100%; box-sizing: border-box;
}
.ud__input:focus { border-color: #1b5e20; background: #fff; }
.ud__edit-actions { display: flex; justify-content: flex-end; gap: .5rem; padding-top: .25rem; border-top: 1px solid var(--c-slate-100); margin-top: .25rem; }

/* Edit button */
.ud__edit-btn {
  display: inline-flex; align-items: center; gap: .3rem;
  background: none; border: 1px solid var(--c-slate-200); color: var(--c-slate-500);
  padding: .25rem .7rem; border-radius: 7px; font-size: .72rem; font-weight: 600; cursor: pointer; transition: all .15s;
}
.ud__edit-btn:hover { background: var(--c-slate-100); color: var(--c-slate-900); }

/* Rol aside */
.ud__role-display { display: flex; flex-direction: column; gap: .65rem; }
.ud__role-pill {
  display: inline-flex; align-items: center; gap: .45rem;
  font-size: .85rem; font-weight: 700; padding: .45em 1em; border-radius: 9px;
  align-self: flex-start;
}
.ud__role-desc { font-size: .78rem; color: var(--c-slate-500); line-height: 1.55; margin: 0; }

/* Rol edit */
.ud__role-options { display: flex; flex-direction: column; gap: .35rem; margin-bottom: .875rem; }
.ud__role-option {
  display: flex; align-items: center; gap: .45rem;
  padding: .5rem .75rem; border-radius: 9px;
  border: 1.5px solid var(--c-slate-200); background: var(--c-slate-50);
  font-size: .8rem; font-weight: 500; cursor: pointer; color: var(--c-slate-600);
  transition: all .15s; text-align: left;
}
.ud__role-option:hover { border-color: var(--c-slate-300); }
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
.ud__permiso--no { color: var(--c-slate-400); }
.ud__permiso--ok i { color: #15803d; font-size: .85rem; }
.ud__permiso--no i { color: var(--c-slate-300); font-size: .85rem; }

/* Sedes note */
.ud__sede-note {
  font-size: .73rem; color: var(--c-slate-500); margin: .75rem 0 0;
  padding: .45rem .7rem; background: var(--c-slate-50);
  border-radius: 7px; border-left: 3px solid var(--c-slate-300);
  display: flex; align-items: flex-start; gap: .4rem; line-height: 1.5;
}
.ud__sede-note--warn { background: #fffbeb; color: #92400e; border-left-color: #d97706; }
.ud__sede-note i { flex-shrink: 0; font-size: .8rem; margin-top: .1rem; }

/* DL */
.ud__dl { display: grid; grid-template-columns: auto 1fr; gap: .5rem .75rem; padding: .875rem 1.25rem; margin: 0; }
.ud__dl dt { font-size: .72rem; color: var(--c-slate-400); font-weight: 500; }
.ud__dl dd { font-size: .82rem; color: var(--c-slate-900); font-weight: 600; margin: 0; }

/* Back link */
.ud__back-link {
  display: flex; align-items: center; gap: .5rem;
  color: var(--c-slate-500); font-size: .82rem; font-weight: 500;
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
  background: #fff; color: var(--c-slate-500); border: 1.5px solid var(--c-slate-200);
  padding: .55rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 500; cursor: pointer;
}
.ud__btn-ghost:hover { background: var(--c-slate-50); }
.ud__btn-danger-outline {
  display: inline-flex; align-items: center; gap: .35rem;
  background: rgba(255,255,255,.8); color: #dc2626;
  border: 1.5px solid rgba(220,38,38,.3);
  padding: .5rem .875rem; border-radius: 9px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; backdrop-filter: blur(4px);
}
.ud__btn-danger-outline:hover { background: #fef2f2; border-color: #dc2626; }

/* Estadísticas */
.uds__monthnav { margin-left: auto; display: flex; align-items: center; gap: .5rem; }
.uds__nav { width: 30px; height: 30px; border-radius: 8px; border: 1px solid var(--c-slate-200); background: #fff; color: var(--c-slate-600); cursor: pointer; display: flex; align-items: center; justify-content: center; }
.uds__nav:disabled { opacity: .4; cursor: not-allowed; }
.uds__month { font-size: .82rem; font-weight: 700; color: #1a2e1a; min-width: 110px; text-align: center; }
.uds__loading { display: flex; justify-content: center; padding: 1rem; }
.uds__empty { color: var(--c-slate-400); font-size: .85rem; text-align: center; padding: 1rem 0; margin: 0; }

/* Horas del mes — confirmación */
.udh__head { display: flex; align-items: center; justify-content: space-between; margin-bottom: .5rem; }
.udh__all { display: flex; align-items: center; gap: .4rem; font-size: .78rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; }
.udh__sel { font-size: .75rem; font-weight: 700; color: #15803d; }
.udh__list { display: flex; flex-direction: column; border: 1px solid var(--c-slate-100); border-radius: 10px; overflow: hidden; }
.udh__row { display: grid; grid-template-columns: auto 1fr auto auto auto auto; align-items: center; gap: .6rem; padding: .5rem .7rem; font-size: .82rem; }
.udh__row:not(:last-child) { border-bottom: 1px solid var(--c-slate-100); }
.udh__row--conf { background: var(--c-slate-50); }
.udh__row input { width: 15px; height: 15px; cursor: pointer; }
.udh__fecha { font-weight: 600; color: var(--c-slate-900); font-variant-numeric: tabular-nums; }
.udh__horario { color: var(--c-slate-500); font-variant-numeric: tabular-nums; }
.udh__hs { font-weight: 700; color: #2d4a3e; font-variant-numeric: tabular-nums; }
.udh__estado { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: .12rem .5rem; border-radius: 999px; }
.udh__estado--ok { background: #dcfce7; color: #15803d; }
.udh__estado--pend { background: #fef3c7; color: #b45309; }
.udh__reabrir { border: none; background: none; color: var(--c-slate-500); cursor: pointer; padding: .1rem .3rem; font-size: .85rem; }
.udh__reabrir:hover { color: #b45309; }
.udh__reabrir-ph { width: 18px; }
.udh__actions { display: flex; gap: .5rem; justify-content: flex-end; margin-top: .7rem; flex-wrap: wrap; }
.udh__btn { border: 1.5px solid var(--c-slate-200); background: #fff; color: var(--c-slate-700); border-radius: 8px; padding: .45rem .9rem; font-size: .8rem; font-weight: 600; cursor: pointer; }
.udh__btn:hover:not(:disabled) { border-color: var(--c-slate-300); }
.udh__btn--primary { background: #5C7A4A; border-color: #5C7A4A; color: #fff; }
.udh__btn--primary:hover:not(:disabled) { background: #4a6239; }
.udh__btn:disabled { opacity: .5; cursor: not-allowed; }
.uds__grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: .75rem; }
.uds__stat { background: var(--c-slate-50); border: 1px solid #eef2f6; border-radius: 12px; padding: .9rem; display: flex; flex-direction: column; gap: .15rem; }
.uds__val { font-family: var(--font-display, sans-serif); font-size: 1.6rem; font-weight: 700; color: #1a2e1a; line-height: 1; }
.uds__val small { font-size: .9rem; font-weight: 600; color: var(--c-slate-500); margin-left: .1rem; }
.uds__lbl { font-size: .78rem; font-weight: 600; color: var(--c-slate-700); }
.uds__sub { font-size: .7rem; color: var(--c-slate-400); }
.uds__medios { grid-column: 1 / -1; background: var(--c-slate-50); border: 1px solid #eef2f6; border-radius: 12px; padding: .8rem .9rem; }
.uds__medios-title { font-size: .7rem; font-weight: 700; color: var(--c-slate-500); text-transform: uppercase; letter-spacing: .04em; }
.uds__medios-list { display: flex; flex-wrap: wrap; gap: .4rem .9rem; margin-top: .4rem; }
.uds__medio { font-size: .8rem; color: var(--c-slate-600); }

/* Historial de actividad (audit log) — filtros + tabla */
.uda__filtros { display: flex; align-items: flex-end; gap: .6rem; flex-wrap: wrap; margin-bottom: 1rem; }
.uda__f { display: flex; flex-direction: column; gap: .25rem; font-size: .68rem; font-weight: 700; color: var(--c-slate-500); text-transform: uppercase; letter-spacing: .04em; }
.uda__inp { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .4rem .6rem; font-size: .82rem; color: var(--c-slate-900); outline: none; }
.uda__inp:focus { border-color: #1b5e20; background: #fff; }
.uda__clear { display: inline-flex; align-items: center; gap: .3rem; background: none; border: 1px solid var(--c-slate-200); color: var(--c-slate-500); border-radius: 8px; padding: .45rem .7rem; font-size: .75rem; font-weight: 600; cursor: pointer; }
.uda__clear:hover { background: var(--c-slate-100); color: #dc2626; }

.uda__table-wrap { overflow-x: auto; }
.uda__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.uda__table th { text-align: left; font-size: .66rem; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-400); font-weight: 700; padding: .5rem .6rem; border-bottom: 1.5px solid var(--c-slate-100); white-space: nowrap; }
.uda__table td { padding: .6rem .6rem; border-bottom: 1px solid #f5f7fa; color: var(--c-slate-600); vertical-align: top; }
.uda__table tbody tr:hover td { background: #fafbfc; }
.uda__td-fecha { white-space: nowrap; color: var(--c-slate-500); font-variant-numeric: tabular-nums; }
.uda__ref { color: var(--c-slate-400); font-variant-numeric: tabular-nums; white-space: nowrap; }
.uda__chip { display: inline-flex; align-items: center; gap: .3rem; font-size: .7rem; font-weight: 700; padding: .18rem .55rem; border-radius: 999px; white-space: nowrap; background: var(--c-slate-100); color: var(--c-slate-500); }
.uda__chip.act--new { background: rgba(21,128,61,.1); color: #15803d; }
.uda__chip.act--edit { background: rgba(180,83,9,.1); color: #b45309; }
.uda__chip.act--del { background: rgba(220,38,38,.1); color: #dc2626; }
.uda__diffs { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .2rem; }
.uda__diff { display: flex; align-items: center; gap: .3rem; flex-wrap: wrap; }
.uda__campo { font-weight: 600; color: var(--c-slate-500); }
.uda__de { color: var(--c-slate-400); text-decoration: line-through; }
.uda__diff i { font-size: .68rem; color: var(--c-slate-300); }
.uda__a { color: #15803d; font-weight: 600; }
.uda__nodiff { color: var(--c-slate-300); }
</style>
