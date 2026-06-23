<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import {
  PackageCheck, Truck, CheckCircle2, XCircle, User, MapPin,
  Phone, FileText, RefreshCw, ChevronDown, ChevronUp, AlertCircle,
  CalendarClock, ArrowRight, BookmarkCheck, Tag
} from 'lucide-vue-next'
import {
  listDespachos, listEntregadores, reasignarDelivery, reprogramarPaquete,
  listReservas, entregarReserva, entregarPaquete, reportarFallo, cancelarEntregaDispensacion,
  getRutaEntrega, ordenarRuta, bloquearRuta,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const toast = useToast()
const { confirm } = useConfirm()

const despachos      = ref([])
const deliveryUsers  = ref([])
const loading        = ref(true)
const saving         = ref(false)
const reprogramando  = ref(false)

const filtroEstado   = ref('')
const filtroDelivery = ref('')
const filtroDesde    = ref('')
const filtroHasta    = ref('')
const filtroBusca    = ref('')

const expandedId     = ref(null)
const reasignandoId  = ref(null)
const nuevoDelivery  = ref('')

// Menú "Acciones" desplegable por despacho (guarda el id abierto).
const menuAbierto = ref(null)
function toggleMenu(id) { menuAbierto.value = menuAbierto.value === id ? null : id }
function cerrarMenu()   { menuAbierto.value = null }

// Reservas con envío pendientes: entregas futuras que todavía no son un despacho real.
// Al "preparar entrega" se convierten en Dispensacion con envío y bajan a la lista.
const reservas          = ref([])
const entregandoReservaId = ref(null)

const kpis = computed(() => ({
  pendientes: despachos.value.filter(d => d.estado_envio === 'pendiente').length,
  en_viaje:   despachos.value.filter(d => d.estado_envio === 'en_viaje').length,
  entregados: despachos.value.filter(d => d.estado_envio === 'entregado').length,
  fallidos:   despachos.value.filter(d => d.estado_envio === 'fallido').length,
}))

const despachosFiltered = computed(() => {
  let list = despachos.value
  if (filtroBusca.value.trim()) {
    const q = filtroBusca.value.toLowerCase()
    list = list.filter(d =>
      d.codigo_paquete?.toLowerCase().includes(q) ||
      d.paciente_nombre?.toLowerCase().includes(q) ||
      d.direccion_envio?.toLowerCase().includes(q) ||
      d.delivery_nombre?.toLowerCase().includes(q)
    )
  }
  // En modo ruta: pendientes primero (en orden de entrega), el resto después por fecha.
  // La hoja de ruta se arma solo con los pendientes.
  if (modoRuta.value) {
    const peso = e => (e === 'pendiente' ? 0 : 1)
    list = [...list].sort((a, b) => {
      const pa = peso(a.estado_envio), pb = peso(b.estado_envio)
      if (pa !== pb) return pa - pb
      if (pa === 0) return (a.orden_entrega ?? Infinity) - (b.orden_entrega ?? Infinity)
      return new Date(b.created_at) - new Date(a.created_at)
    })
  }
  return list
})

// Solo los pendientes se reordenan en la ruta.
const despachosPendientesRuta = computed(() =>
  despachosFiltered.value.filter(d => d.estado_envio === 'pendiente'))

// Selección de despachos (en modo ruta) para armar la ruta en Maps.
const seleccionados = ref(new Set())
function toggleSel(id) {
  const s = new Set(seleccionados.value)
  s.has(id) ? s.delete(id) : s.add(id)
  seleccionados.value = s
}

// Ruta en Google Maps: usa los seleccionados (si hay) o todos los pendientes en orden.
function abrirEnMaps() {
  let base = despachosPendientesRuta.value
  if (seleccionados.value.size) base = base.filter(d => seleccionados.value.has(d.id))
  const dirs = base.map(d => d.direccion_envio).filter(Boolean)
  if (!dirs.length) { toast.error('Seleccioná despachos con dirección para armar la ruta'); return }
  const destino   = encodeURIComponent(dirs[dirs.length - 1])
  const waypoints = dirs.slice(0, -1).map(encodeURIComponent).join('|')
  let url = `https://www.google.com/maps/dir/?api=1&travelmode=driving&destination=${destino}`
  if (waypoints) url += `&waypoints=${waypoints}`
  window.open(url, '_blank', 'noopener')
}

// ── Ruta de entrega (orden + candado) ──────────────────────────────────────
// Modo ruta: un repartidor seleccionado → se ordena la ruta de una FECHA (hoy o futura).
const modoRuta       = computed(() => !!filtroDelivery.value)
const fechaRuta      = ref(new Date().toISOString().slice(0, 10))
const rutaActual     = ref(null)   // { id, bloqueada, despachos: [ids] } de (repartidor, fechaRuta)
const guardandoOrden = ref(false)

const rutaId        = computed(() => rutaActual.value?.id || null)
const rutaBloqueada = computed(() => rutaActual.value?.bloqueada || false)

async function cargarRuta() {
  if (!filtroDelivery.value) { rutaActual.value = null; return }
  try {
    const { data } = await getRutaEntrega({ delivery_id: filtroDelivery.value, fecha: fechaRuta.value })
    rutaActual.value = (data && data.id) ? data : null
  } catch { rutaActual.value = null }
}
watch([filtroDelivery, fechaRuta], cargarRuta)

async function persistirOrden(lista) {
  guardandoOrden.value = true
  try {
    const { data } = await ordenarRuta({
      delivery_id: filtroDelivery.value,
      fecha:       fechaRuta.value,
      orden:       lista.map(d => d.id),
    })
    rutaActual.value = data
    despachos.value.forEach(d => {
      if (data.despachos.includes(d.id)) {
        d.ruta_id        = data.id
        d.ruta_bloqueada = data.bloqueada
        d.orden_entrega  = data.despachos.indexOf(d.id) + 1
      }
    })
    return data
  } catch {
    toast.error('No se pudo guardar el orden')
  } finally { guardandoOrden.value = false }
}

function aplicarOrden(nueva) {
  nueva.forEach((d, i) => { d.orden_entrega = i + 1 })  // refleja al instante
  persistirOrden(nueva)
}
function moverArriba(d) {
  if (rutaBloqueada.value) return
  const lista = [...despachosPendientesRuta.value]
  const i = lista.findIndex(x => x.id === d.id)
  if (i <= 0) return
  ;[lista[i - 1], lista[i]] = [lista[i], lista[i - 1]]
  aplicarOrden(lista)
}
function moverAbajo(d) {
  if (rutaBloqueada.value) return
  const lista = [...despachosPendientesRuta.value]
  const i = lista.findIndex(x => x.id === d.id)
  if (i === -1 || i >= lista.length - 1) return
  ;[lista[i + 1], lista[i]] = [lista[i], lista[i + 1]]
  aplicarOrden(lista)
}

async function toggleBloqueoRuta() {
  let id = rutaId.value
  if (!id) {
    const data = await persistirOrden(despachosPendientesRuta.value)  // crea la ruta
    id = data?.id
  }
  if (!id) { toast.error('Ordená los despachos primero'); return }
  try {
    const { data } = await bloquearRuta(id, !rutaBloqueada.value)
    rutaActual.value = data
    despachos.value.forEach(d => { if (d.ruta_id === id) d.ruta_bloqueada = data.bloqueada })
    toast.success(data.bloqueada ? 'Orden fijado — el repartidor debe respetarlo' : 'Orden liberado')
  } catch { toast.error('No se pudo cambiar el candado') }
}

const ESTADO_META = {
  pendiente: { label: 'Pendiente', bg: '#dbeafe', color: '#1d4ed8' },
  en_viaje:  { label: 'En camino', bg: '#fef3c7', color: '#d97706' },
  entregado: { label: 'Entregado', bg: '#dcfce7', color: '#15803d' },
  fallido:   { label: 'Fallido',   bg: '#fee2e2', color: '#dc2626' },
  cancelada: { label: 'Cancelada', bg: '#f1f5f9', color: '#64748b' },
}

const EVENTO_META = {
  despachado:  { label: 'Despachado',  color: '#d97706' },
  entregado:   { label: 'Entregado',   color: '#15803d' },
  fallido:     { label: 'Fallo de entrega', color: '#dc2626' },
  reprogramado:{ label: 'Reprogramado', color: '#1d4ed8' },
  cancelado:   { label: 'Cancelado',   color: '#64748b' },
}

function estadoBadgeStyle(estado) {
  const m = ESTADO_META[estado] || {}
  return { background: m.bg || '#f1f5f9', color: m.color || '#475569' }
}

const fmtFecha = (d) => d
  ? new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
  : '—'
const fmtFechaHora = (iso) => iso
  ? new Date(iso).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
  : '—'

const fmtMoneda = (n) => (n == null ? null : new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 }).format(n))

const HOY = new Date().toISOString().slice(0, 10)

// Reservas con envío pendientes, ordenadas por urgencia (las más próximas/vencidas primero).
const reservasEnvio = computed(() =>
  reservas.value
    .filter(r => r.con_envio && r.estado === 'pendiente')
    .sort((a, b) => (a.fecha_entrega_estimada || '').localeCompare(b.fecha_entrega_estimada || ''))
)

// 'vencida' (fecha pasada), 'hoy', o 'proxima'. Define color y etiqueta.
function urgenciaReserva(r) {
  if (!r.fecha_entrega_estimada) return 'proxima'
  if (r.fecha_entrega_estimada < HOY)  return 'vencida'
  if (r.fecha_entrega_estimada === HOY) return 'hoy'
  return 'proxima'
}
const URGENCIA_LABEL = { vencida: 'Vencida', hoy: 'Hoy', proxima: 'Próxima' }

async function load() {
  loading.value = true
  try {
    const params = {}
    if (filtroEstado.value)   params.estado_envio = filtroEstado.value
    if (filtroDelivery.value) params.delivery_id  = filtroDelivery.value
    if (filtroDesde.value)    params.desde        = filtroDesde.value
    if (filtroHasta.value)    params.hasta        = filtroHasta.value
    const { data } = await listDespachos(params)
    despachos.value = data.dispensaciones || []
  } catch { toast.error('Error al cargar despachos') }
  finally { loading.value = false }
}

async function loadReservas() {
  try {
    const { data } = await listReservas({ estado: 'pendiente' })
    reservas.value = (data.reservas || [])
  } catch { reservas.value = [] }
}

// Convierte la reserva en una dispensación con envío (corre validaciones de crédito/stock
// en el backend). Al confirmarse, aparece como despacho 'pendiente' en la lista de abajo.
async function prepararEntrega(r) {
  const restante = r.aporte_restante_ars > 0 ? ` Se cobrará ${fmtMoneda(r.aporte_restante_ars)}.` : ''
  const ok = await confirm({
    title:       'Preparar entrega',
    message:     `Se generará el despacho con envío de ${r.cantidad}${r.stock?.unidad || 'g'} para ${r.paciente?.nombre}.${restante} Después podés asignarle un repartidor en la lista de despachos.`,
    confirmText: 'Generar despacho',
    variant:     'primary',
  })
  if (!ok) return
  entregandoReservaId.value = r.id
  try {
    await entregarReserva(r.id)
    toast.success(`Despacho generado para ${r.paciente?.nombre}`)
    await Promise.all([loadReservas(), load()])
  } catch (e) {
    toast.error(e.response?.data?.errors?.[0] || e.response?.data?.error || 'No se pudo generar el despacho')
  } finally {
    entregandoReservaId.value = null
  }
}

const ROLE_LABEL = { delivery: 'Repartidor', admin: 'Admin', supervisor: 'Supervisor' }

async function loadDeliveryUsers() {
  try {
    const { data } = await listEntregadores()
    deliveryUsers.value = data.data || []
  } catch {}
}

function toggleExpand(id) {
  expandedId.value = expandedId.value === id ? null : id
}

function iniciarReasignacion(d) {
  reasignandoId.value = d.id
  nuevoDelivery.value = d.delivery_id ? String(d.delivery_id) : ''
  expandedId.value    = d.id
}

function cancelarReasignacion() {
  reasignandoId.value = null
  nuevoDelivery.value = ''
}

async function confirmarReasignacion(id) {
  saving.value = true
  try {
    await reasignarDelivery(id, nuevoDelivery.value || null)
    reasignandoId.value = null
    await load()
    toast.success('Delivery reasignado')
  } catch { toast.error('Error al reasignar') }
  finally { saving.value = false }
}

function deliveryNombre(d) {
  if (d.delivery_nombre) return d.delivery_nombre
  const u = deliveryUsers.value.find(u => u.id === d.delivery_id)
  return u ? entregadorLabel(u) : '—'
}

function entregadorLabel(u) {
  const nombre = [u.first_name, u.last_name].filter(Boolean).join(' ') || u.email
  if (u.role !== 'delivery') return `${nombre} (${ROLE_LABEL[u.role] || u.role})`
  return nombre
}

// ── Completar entrega (admin cierra el círculo) ──
const entregaModal = ref({ open: false, id: null, codigo: '', paciente: '', notas: '' })
function abrirEntrega(d) {
  entregaModal.value = { open: true, id: d.id, codigo: d.codigo_paquete || `#${d.id}`, paciente: d.paciente?.nombre || '', notas: '' }
}
async function confirmarEntrega() {
  saving.value = true
  try {
    await entregarPaquete(entregaModal.value.id, entregaModal.value.notas || null, null)
    toast.success('Entrega completada')
    entregaModal.value.open = false
    await load()
  } catch (e) { toast.error(e.response?.data?.error || 'No se pudo completar la entrega') }
  finally { saving.value = false }
}

// ── Reportar fallo ──
const falloModal = ref({ open: false, id: null, codigo: '', paciente: '', motivo: '' })
function abrirFallo(d) {
  falloModal.value = { open: true, id: d.id, codigo: d.codigo_paquete || `#${d.id}`, paciente: d.paciente?.nombre || '', motivo: '' }
}
async function confirmarFallo() {
  if (!falloModal.value.motivo) return
  saving.value = true
  try {
    await reportarFallo(falloModal.value.id, falloModal.value.motivo)
    toast.success('Fallo reportado')
    falloModal.value.open = false
    await load()
  } catch (e) { toast.error(e.response?.data?.error || 'No se pudo reportar el fallo') }
  finally { saving.value = false }
}

// ── Cancelar entrega (revierte + queda registrada como cancelada) ──
const cancelarModal = ref({ open: false, id: null, codigo: '', paciente: '', motivo: '' })
function abrirCancelar(d) {
  cancelarModal.value = { open: true, id: d.id, codigo: d.codigo_paquete || `#${d.id}`, paciente: d.paciente?.nombre || '', motivo: '' }
}
async function confirmarCancelar() {
  saving.value = true
  try {
    await cancelarEntregaDispensacion(cancelarModal.value.id, cancelarModal.value.motivo || null)
    toast.success('Entrega cancelada — producto devuelto al stock')
    cancelarModal.value.open = false
    await load()
  } catch (e) { toast.error(e.response?.data?.errors?.[0] || e.response?.data?.error || 'No se pudo cancelar') }
  finally { saving.value = false }
}

async function reprogramar(id) {
  reprogramando.value = true
  try {
    await reprogramarPaquete(id)
    expandedId.value = null
    await load()
    toast.success('Paquete reprogramado — volvió a Pendiente')
  } catch { toast.error('Error al reprogramar') }
  finally { reprogramando.value = false }
}

const route = useRoute()
onMounted(async () => {
  document.addEventListener('click', cerrarMenu)  // cerrar el menú Acciones al clickear afuera
  await Promise.all([load(), loadDeliveryUsers(), loadReservas()])
  // Si venís desde el QR de una etiqueta (?paquete=CODIGO), abrir/enfocar ese despacho.
  const code = route.query.paquete
  if (code) {
    const match = despachos.value.find(d => d.codigo_paquete === code || String(d.id) === String(code))
    if (match) {
      expandedId.value = match.id
      requestAnimationFrame(() => {
        document.getElementById(`despacho-${match.id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      })
    }
  }
})
onUnmounted(() => document.removeEventListener('click', cerrarMenu))
</script>

<template>
  <div class="dsp">

    <!-- Header -->
    <div class="dsp__header">
      <div class="dsp__header-left">
        <PackageCheck :size="22" :stroke-width="1.75" />
        <div>
          <div class="dsp__title">Despachos con envío</div>
          <div class="dsp__sub">{{ despachos.length }} despacho{{ despachos.length !== 1 ? 's' : '' }} totales</div>
        </div>
      </div>
      <button class="dsp__btn-refresh" :disabled="loading" @click="load">
        <RefreshCw :size="15" :stroke-width="2" :class="{ 'dsp__spin': loading }" />
        Actualizar
      </button>
    </div>

    <!-- KPI strip -->
    <div class="dsp__kpis">
      <div class="dsp__kpi dsp__kpi--blue" @click="filtroEstado = filtroEstado === 'pendiente' ? '' : 'pendiente'; load()">
        <span class="dsp__kpi-n">{{ kpis.pendientes }}</span>
        <span class="dsp__kpi-l">Pendientes</span>
      </div>
      <div class="dsp__kpi dsp__kpi--amber" @click="filtroEstado = filtroEstado === 'en_viaje' ? '' : 'en_viaje'; load()">
        <Truck :size="18" :stroke-width="1.75" class="dsp__kpi-icon" />
        <span class="dsp__kpi-n">{{ kpis.en_viaje }}</span>
        <span class="dsp__kpi-l">En camino</span>
      </div>
      <div class="dsp__kpi dsp__kpi--green" @click="filtroEstado = filtroEstado === 'entregado' ? '' : 'entregado'; load()">
        <CheckCircle2 :size="18" :stroke-width="1.75" class="dsp__kpi-icon" />
        <span class="dsp__kpi-n">{{ kpis.entregados }}</span>
        <span class="dsp__kpi-l">Entregados</span>
      </div>
      <div class="dsp__kpi dsp__kpi--red" @click="filtroEstado = filtroEstado === 'fallido' ? '' : 'fallido'; load()">
        <XCircle :size="18" :stroke-width="1.75" class="dsp__kpi-icon" />
        <span class="dsp__kpi-n">{{ kpis.fallidos }}</span>
        <span class="dsp__kpi-l">Fallidos</span>
      </div>
    </div>

    <!-- Próximas entregas: reservas con envío pendientes -->
    <section v-if="reservasEnvio.length" class="dsp__resv">
      <div class="dsp__resv-head">
        <BookmarkCheck :size="16" :stroke-width="2" />
        <span class="dsp__resv-title">Próximas entregas</span>
        <span class="dsp__resv-count">{{ reservasEnvio.length }}</span>
        <span class="dsp__resv-hint">reservas con envío pendientes de despachar</span>
      </div>

      <div class="dsp__resv-list">
        <div
          v-for="r in reservasEnvio"
          :key="r.id"
          class="dsp__resv-card"
          :class="`dsp__resv-card--${urgenciaReserva(r)}`"
        >
          <div class="dsp__resv-when">
            <CalendarClock :size="13" :stroke-width="2" />
            <span class="dsp__resv-urg" :class="`dsp__resv-urg--${urgenciaReserva(r)}`">
              {{ URGENCIA_LABEL[urgenciaReserva(r)] }}
            </span>
            <span class="dsp__resv-date">{{ fmtFecha(r.fecha_entrega_estimada) }}</span>
          </div>

          <div class="dsp__resv-body">
            <div class="dsp__resv-nombre"><User :size="12" :stroke-width="2" /> {{ r.paciente?.nombre }}</div>
            <div class="dsp__resv-meta">
              <span><PackageCheck :size="12" :stroke-width="2" /> {{ r.cantidad }}{{ r.stock?.unidad || 'g' }}<template v-if="r.stock?.lote"> · {{ r.stock.lote }}</template></span>
              <span><MapPin :size="12" :stroke-width="2" /> {{ r.direccion_envio || '(sin dirección)' }}</span>
              <span v-if="r.contacto_telefono"><Phone :size="12" :stroke-width="2" /> {{ r.contacto_telefono }}</span>
              <span v-if="r.aporte_restante_ars > 0" class="dsp__resv-cobrar">A cobrar {{ fmtMoneda(r.aporte_restante_ars) }}</span>
            </div>
          </div>

          <button
            class="dsp__resv-btn"
            :disabled="entregandoReservaId === r.id"
            @click="prepararEntrega(r)"
          >
            Generar despacho <ArrowRight :size="14" :stroke-width="2" />
          </button>
        </div>
      </div>
    </section>

    <!-- Filtros -->
    <div class="dsp__filters">
      <input
        v-model="filtroBusca"
        class="dsp__search"
        type="text"
        placeholder="Buscar código, socio, dirección, repartidor…"
      />
      <select v-model="filtroEstado" class="dsp__select" @change="load">
        <option value="">Todos los estados</option>
        <option value="pendiente">Pendiente</option>
        <option value="en_viaje">En camino</option>
        <option value="entregado">Entregado</option>
        <option value="fallido">Fallido</option>
      </select>
      <select v-model="filtroDelivery" class="dsp__select" @change="load">
        <option value="">Todos los asignados</option>
        <option v-for="u in deliveryUsers" :key="u.id" :value="String(u.id)">
          {{ entregadorLabel(u) }}
        </option>
      </select>
      <div class="dsp__date-range">
        <label class="dsp__date-field">
          <span class="dsp__date-label">Dispensadas desde</span>
          <AppDatePicker v-model="filtroDesde" @update:model-value="load" />
        </label>
        <label class="dsp__date-field">
          <span class="dsp__date-label">Hasta</span>
          <AppDatePicker v-model="filtroHasta" @update:model-value="load" />
        </label>
      </div>
      <button
        v-if="filtroEstado || filtroDelivery || filtroDesde || filtroHasta || filtroBusca"
        class="dsp__btn-clear"
        @click="filtroEstado=''; filtroDelivery=''; filtroDesde=''; filtroHasta=''; filtroBusca=''; load()"
      >
        Limpiar
      </button>
    </div>

    <!-- Hint: cómo armar la ruta (cuando no hay repartidor elegido) -->
    <div v-if="!modoRuta && !loading && despachosFiltered.length" class="dsp__ruta-hint">
      <i class="bi bi-signpost-split"></i>
      Para <strong>armar la hoja de ruta</strong> y fijar el orden de entrega, elegí un <strong>repartidor</strong> en el filtro de arriba.
    </div>

    <!-- Barra de ruta (al filtrar por repartidor) -->
    <div v-if="modoRuta && despachosFiltered.length" class="dsp__ruta-bar">
      <div class="dsp__ruta-info">
        <Truck :size="15" :stroke-width="2" />
        <span><strong>Ruta de entrega</strong> · ordená con ↑↓ · tildá los que mandás a Maps</span>
        <DsSpinner v-if="guardandoOrden" :size="13" />
      </div>
      <label class="dsp__ruta-fecha">
        <span class="dsp__date-label">Fecha de ruta</span>
        <AppDatePicker v-model="fechaRuta" />
      </label>
      <button class="dsp__ruta-maps" :disabled="!despachosPendientesRuta.length" @click="abrirEnMaps">
        <i class="bi bi-geo-alt-fill"></i>
        Ruta en Maps<template v-if="seleccionados.size"> ({{ seleccionados.size }})</template>
      </button>
      <button
        class="dsp__ruta-lock"
        :class="{ 'dsp__ruta-lock--on': rutaBloqueada }"
        @click="toggleBloqueoRuta"
      >
        <i :class="rutaBloqueada ? 'bi bi-lock-fill' : 'bi bi-unlock'"></i>
        {{ rutaBloqueada ? 'Orden fijo' : 'Respetar orden' }}
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="dsp__loading">
      <DsSpinner />
    </div>

    <!-- Empty -->
    <div v-else-if="!despachosFiltered.length" class="dsp__empty">
      <PackageCheck :size="44" :stroke-width="1.25" />
      <div class="dsp__empty-title">Sin despachos</div>
      <div class="dsp__empty-sub">No hay despachos con los filtros actuales</div>
    </div>

    <!-- Lista -->
    <div v-else class="dsp__list">
      <div
        v-for="d in despachosFiltered"
        :key="d.id"
        :id="`despacho-${d.id}`"
        class="dsp__row"
        :class="`dsp__row--${d.estado_envio}`"
      >

        <!-- Fila principal (clickable) -->
        <div class="dsp__row-main" @click="toggleExpand(d.id)">

          <!-- Selección para la ruta en Maps (solo pendientes, en modo ruta) -->
          <input
            v-if="modoRuta && d.estado_envio === 'pendiente'"
            type="checkbox" class="dsp__sel"
            :checked="seleccionados.has(d.id)"
            title="Incluir en la ruta de Maps"
            @click.stop="toggleSel(d.id)"
          />

          <!-- Orden de ruta (solo pendientes, al filtrar por repartidor) -->
          <div v-if="modoRuta && d.estado_envio === 'pendiente'" class="dsp__orden" @click.stop>
            <span class="dsp__orden-n">{{ d.orden_entrega ?? '—' }}</span>
            <div class="dsp__orden-btns">
              <button class="dsp__orden-btn" :disabled="rutaBloqueada || guardandoOrden" title="Subir" @click.stop="moverArriba(d)"><i class="bi bi-chevron-up"></i></button>
              <button class="dsp__orden-btn" :disabled="rutaBloqueada || guardandoOrden" title="Bajar" @click.stop="moverAbajo(d)"><i class="bi bi-chevron-down"></i></button>
            </div>
          </div>

          <div class="dsp__row-left">
            <span class="dsp__code">{{ d.codigo_paquete || `#${d.id}` }}</span>
            <span class="dsp__estado-badge" :style="estadoBadgeStyle(d.estado_envio)">
              {{ ESTADO_META[d.estado_envio]?.label || d.estado_envio }}
            </span>
          </div>

          <div class="dsp__row-mid">
            <div class="dsp__row-nombre">
              <User :size="12" :stroke-width="2" />
              {{ d.paciente_nombre }}
            </div>
            <div class="dsp__row-dir">
              <MapPin :size="12" :stroke-width="2" />
              {{ d.direccion_envio || '(sin dirección)' }}
            </div>
          </div>

          <div class="dsp__row-right">
            <div class="dsp__row-delivery">
              <Truck :size="12" :stroke-width="2" />
              {{ d.delivery_nombre || deliveryNombre(d) || 'Sin asignar' }}
            </div>
            <div class="dsp__row-fecha">{{ fmtFecha(d.fecha_dispensacion) }}</div>
          </div>

          <div class="dsp__row-toggle">
            <ChevronDown v-if="expandedId !== d.id" :size="16" :stroke-width="2" />
            <ChevronUp   v-else                     :size="16" :stroke-width="2" />
          </div>

        </div>

        <!-- Panel expandido -->
        <div v-if="expandedId === d.id" class="dsp__detail">

          <div class="dsp__detail-grid">

            <div class="dsp__detail-col">
              <div class="dsp__detail-label">Socio</div>
              <div class="dsp__detail-val"><User :size="13" :stroke-width="2" /> {{ d.paciente_nombre }}</div>

              <div class="dsp__detail-label">Dirección de envío</div>
              <div class="dsp__detail-val"><MapPin :size="13" :stroke-width="2" /> {{ d.direccion_envio || '—' }}</div>

              <div v-if="d.contacto_nombre" class="dsp__detail-label">Contacto</div>
              <div v-if="d.contacto_nombre" class="dsp__detail-val">{{ d.contacto_nombre }}</div>

              <div v-if="d.contacto_telefono" class="dsp__detail-label">Teléfono</div>
              <div v-if="d.contacto_telefono" class="dsp__detail-val"><Phone :size="13" :stroke-width="2" /> {{ d.contacto_telefono }}</div>

              <div v-if="d.notas_envio" class="dsp__detail-label">Notas envío</div>
              <div v-if="d.notas_envio" class="dsp__detail-val dsp__detail-val--italic">
                <FileText :size="13" :stroke-width="2" /> {{ d.notas_envio }}
              </div>
            </div>

            <div class="dsp__detail-col">
              <div class="dsp__detail-label">Código paquete</div>
              <div class="dsp__detail-val"><code class="dsp__code-sm">{{ d.codigo_paquete || '—' }}</code></div>

              <div class="dsp__detail-label">Producto</div>
              <div class="dsp__detail-val">
                {{ d.stock?.forma_producto || '—' }}
                <span v-if="d.cantidad">· {{ d.cantidad }}{{ d.stock?.unidad || 'g' }}</span>
              </div>

              <div class="dsp__detail-label">Fecha dispensación</div>
              <div class="dsp__detail-val">{{ fmtFecha(d.fecha_dispensacion) }}</div>

              <template v-if="d.estado_envio === 'fallido' && d.motivo_fallo">
                <div class="dsp__detail-label dsp__detail-label--red">Motivo fallo</div>
                <div class="dsp__detail-val dsp__detail-val--red">
                  <AlertCircle :size="13" :stroke-width="2" /> {{ d.motivo_fallo }}
                </div>
              </template>

              <template v-if="d.estado_envio === 'entregado' && d.notas_entrega">
                <div class="dsp__detail-label dsp__detail-label--green">Notas entrega</div>
                <div class="dsp__detail-val dsp__detail-val--green">
                  <CheckCircle2 :size="13" :stroke-width="2" /> {{ d.notas_entrega }}
                </div>
              </template>

              <template v-if="d.estado_envio === 'entregado' && d.firma_entrega_data">
                <div class="dsp__detail-label dsp__detail-label--green">Firma del receptor</div>
                <div class="dsp__firma-preview">
                  <img :src="d.firma_entrega_data" alt="Firma" class="dsp__firma-img" />
                </div>
              </template>
            </div>

          </div>

          <!-- Historial de la entrega -->
          <div v-if="d.historial_envio?.length" class="dsp__historial">
            <div class="dsp__detail-label">Historial</div>
            <div v-for="(ev, i) in d.historial_envio" :key="i" class="dsp__hist-row">
              <span class="dsp__hist-dot" :style="{ background: EVENTO_META[ev.evento]?.color || '#94a3b8' }"></span>
              <span class="dsp__hist-evento">{{ EVENTO_META[ev.evento]?.label || ev.evento }}</span>
              <span class="dsp__hist-fecha">{{ fmtFechaHora(ev.fecha) }}</span>
              <span v-if="ev.usuario_nombre" class="dsp__hist-user">· {{ ev.usuario_nombre }}</span>
              <span v-if="ev.motivo" class="dsp__hist-motivo">— {{ ev.motivo }}</span>
            </div>
          </div>

          <!-- Reasignación -->
          <div class="dsp__reasign-bar">
            <template v-if="reasignandoId === d.id">
              <span class="dsp__reasign-label">Asignar a:</span>
              <select v-model="nuevoDelivery" class="dsp__reasign-select">
                <option value="">— Sin asignar —</option>
                <optgroup v-if="deliveryUsers.filter(u => u.role === 'delivery').length" label="Repartidores">
                  <option v-for="u in deliveryUsers.filter(u => u.role === 'delivery')" :key="u.id" :value="String(u.id)">
                    {{ [u.first_name, u.last_name].filter(Boolean).join(' ') || u.email }}
                  </option>
                </optgroup>
                <optgroup v-if="deliveryUsers.filter(u => u.role !== 'delivery').length" label="Admin / Supervisor">
                  <option v-for="u in deliveryUsers.filter(u => u.role !== 'delivery')" :key="u.id" :value="String(u.id)">
                    {{ [u.first_name, u.last_name].filter(Boolean).join(' ') || u.email }}
                  </option>
                </optgroup>
              </select>
              <button class="dsp__btn-confirm" :disabled="saving" @click="confirmarReasignacion(d.id)">
                <DsSpinner v-if="saving" :size="12" />
                Guardar
              </button>
              <button class="dsp__btn-ghost" :disabled="saving" @click="cancelarReasignacion">
                Cancelar
              </button>
            </template>
            <template v-else>
              <span class="dsp__reasign-info">
                <Truck :size="14" :stroke-width="2" />
                Repartidor: <strong>{{ d.delivery_nombre || deliveryNombre(d) || 'Sin asignar' }}</strong>
              </span>

              <!-- Etiqueta -->
              <RouterLink
                class="dsp__btn-outline"
                :to="{ name: 'despacho-etiqueta', params: { id: d.id } }"
                @click.stop
              >
                <Tag :size="13" :stroke-width="2" /> Etiqueta
              </RouterLink>

              <!-- Acciones (agrupa completar / reportar fallo / reprogramar / reasignar) -->
              <div
                v-if="!['entregado', 'cancelada'].includes(d.estado_envio)"
                class="dsp__acc"
                @click.stop
              >
                <button class="dsp__btn-confirm" @click="toggleMenu(d.id)">
                  Acciones <ChevronDown :size="13" :stroke-width="2" />
                </button>
                <div v-if="menuAbierto === d.id" class="dsp__acc-menu">
                  <button v-if="['pendiente', 'en_viaje'].includes(d.estado_envio)" class="dsp__acc-item" @click="cerrarMenu(); abrirEntrega(d)">
                    <CheckCircle2 :size="14" :stroke-width="2" /> Completar entrega
                  </button>
                  <button v-if="['pendiente', 'en_viaje'].includes(d.estado_envio)" class="dsp__acc-item" @click="cerrarMenu(); abrirFallo(d)">
                    <AlertCircle :size="14" :stroke-width="2" /> Reportar fallo
                  </button>
                  <button v-if="d.estado_envio === 'fallido'" class="dsp__acc-item" :disabled="reprogramando" @click="cerrarMenu(); reprogramar(d.id)">
                    <RefreshCw :size="14" :stroke-width="2" /> Reprogramar
                  </button>
                  <button class="dsp__acc-item" @click="cerrarMenu(); iniciarReasignacion(d)">
                    <Truck :size="14" :stroke-width="2" /> Reasignar
                  </button>
                </div>
              </div>

              <!-- Cancelar -->
              <button
                v-if="!['entregado', 'cancelada'].includes(d.estado_envio)"
                class="dsp__btn-fallo"
                @click.stop="abrirCancelar(d)"
                title="Cancela y devuelve el producto al stock"
              >
                <XCircle :size="13" :stroke-width="2" /> Cancelar
              </button>
            </template>
          </div>

        </div>
      </div>
    </div>

    <!-- Modal completar entrega (admin) -->
    <Teleport to="body">
      <div v-if="entregaModal.open" class="dsp__overlay" @click.self="entregaModal.open = false">
        <div class="dsp__modal">
          <h3 class="dsp__modal-title">Completar entrega</h3>
          <p class="dsp__modal-sub">{{ entregaModal.codigo }} · {{ entregaModal.paciente }}</p>
          <label class="dsp__modal-label">Notas de entrega <span class="dsp__opt">opcional</span></label>
          <textarea v-model.trim="entregaModal.notas" class="dsp__modal-input" rows="2" placeholder="Quién recibió, observaciones…"></textarea>
          <div class="dsp__modal-foot">
            <button class="dsp__btn-ghost" @click="entregaModal.open = false">Cancelar</button>
            <button class="dsp__btn-confirm" :disabled="saving" @click="confirmarEntrega">
              <DsSpinner v-if="saving" :size="12" /> Marcar entregado
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal cancelar entrega (admin) -->
    <Teleport to="body">
      <div v-if="cancelarModal.open" class="dsp__overlay" @click.self="cancelarModal.open = false">
        <div class="dsp__modal">
          <h3 class="dsp__modal-title">Cancelar entrega</h3>
          <p class="dsp__modal-sub">{{ cancelarModal.codigo }} · {{ cancelarModal.paciente }}</p>
          <div class="dsp__modal-warn">
            <AlertCircle :size="14" :stroke-width="2" />
            Se devuelve el producto al stock y se revierte el cobro. La dispensación queda registrada como <strong>cancelada</strong>.
          </div>
          <label class="dsp__modal-label">Motivo <span class="dsp__opt">opcional</span></label>
          <textarea v-model.trim="cancelarModal.motivo" class="dsp__modal-input" rows="2" placeholder="Ej: el socio canceló el pedido…"></textarea>
          <div class="dsp__modal-foot">
            <button class="dsp__btn-ghost" @click="cancelarModal.open = false">Volver</button>
            <button class="dsp__btn-fallo" :disabled="saving" @click="confirmarCancelar">
              <DsSpinner v-if="saving" :size="12" /> Cancelar entrega
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal reportar fallo (admin) -->
    <Teleport to="body">
      <div v-if="falloModal.open" class="dsp__overlay" @click.self="falloModal.open = false">
        <div class="dsp__modal">
          <h3 class="dsp__modal-title">Reportar fallo de entrega</h3>
          <p class="dsp__modal-sub">{{ falloModal.codigo }} · {{ falloModal.paciente }}</p>
          <label class="dsp__modal-label">Motivo <span class="dsp__req">*</span></label>
          <textarea v-model.trim="falloModal.motivo" class="dsp__modal-input" rows="2" placeholder="Ej: dirección incorrecta, nadie atendió…"></textarea>
          <div class="dsp__modal-foot">
            <button class="dsp__btn-ghost" @click="falloModal.open = false">Cancelar</button>
            <button class="dsp__btn-fallo" :disabled="saving || !falloModal.motivo" @click="confirmarFallo">
              <DsSpinner v-if="saving" :size="12" /> Reportar fallo
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.dsp {
  padding: var(--sp-6);
  max-width: 1100px;
  margin: 0 auto;
}

/* Header */
.dsp__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--sp-5);
  gap: var(--sp-3);
}
.dsp__header-left {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  color: var(--c-ink-700);
}
.dsp__title {
  font-size: var(--fs-18);
  font-weight: 700;
  color: var(--c-ink-900);
  line-height: 1;
}
.dsp__sub {
  font-size: var(--fs-13);
  color: var(--c-ink-400);
  margin-top: 2px;
}
.dsp__btn-refresh {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  color: var(--c-ink-600);
  padding: .45rem .9rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 500;
  cursor: pointer;
  transition: border-color .15s;
}
.dsp__btn-refresh:hover:not(:disabled) { border-color: var(--c-ink-400); }
.dsp__btn-refresh:disabled { opacity: .5; cursor: not-allowed; }
.dsp__spin { animation: dsp-spin .7s linear infinite; }
@keyframes dsp-spin { to { transform: rotate(360deg); } }

/* KPI strip */
.dsp__kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--sp-3);
  margin-bottom: var(--sp-5);
}
.dsp__kpi {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-3);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  transition: border-color .15s, box-shadow .15s;
  position: relative;
}
.dsp__kpi:hover { box-shadow: var(--sh-2); }
.dsp__kpi--blue:hover  { border-color: #93c5fd; }
.dsp__kpi--amber:hover { border-color: #fcd34d; }
.dsp__kpi--green:hover { border-color: var(--c-leaf-300); }
.dsp__kpi--red:hover   { border-color: #fca5a5; }
.dsp__kpi-icon { position: absolute; top: var(--sp-3); right: var(--sp-3); opacity: .35; }
.dsp__kpi-n {
  font-size: 1.875rem;
  font-weight: 800;
  line-height: 1;
}
.dsp__kpi--blue  .dsp__kpi-n { color: #1d4ed8; }
.dsp__kpi--amber .dsp__kpi-n { color: #d97706; }
.dsp__kpi--green .dsp__kpi-n { color: var(--c-leaf-700); }
.dsp__kpi--red   .dsp__kpi-n { color: #dc2626; }
.dsp__kpi-l {
  font-size: 11px;
  font-weight: 600;
  color: var(--c-ink-500);
  text-transform: uppercase;
  letter-spacing: .05em;
}

/* Filtros */
.dsp__filters {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sp-2);
  margin-bottom: var(--sp-5);
  align-items: flex-end;
}
.dsp__date-range { display: flex; gap: var(--sp-2); align-items: flex-end; }
.dsp__date-field { display: flex; flex-direction: column; gap: 3px; }
.dsp__date-label { font-size: 11px; font-weight: 600; color: var(--c-text-soft, #64748b); text-transform: uppercase; letter-spacing: .03em; white-space: nowrap; height: 13px; line-height: 13px; }
.dsp__search {
  flex: 1;
  min-width: 220px;
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-md);
  padding: .45rem .8rem;
  font-size: var(--fs-13);
  color: var(--c-ink-900);
}
.dsp__search:focus { outline: none; border-color: var(--c-leaf-600); }
.dsp__select,
.dsp__input-date {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-300);
  border-radius: var(--r-md);
  padding: .42rem .7rem;
  font-size: var(--fs-13);
  color: var(--c-ink-700);
  cursor: pointer;
}
.dsp__select:focus,
.dsp__input-date:focus { outline: none; border-color: var(--c-leaf-600); }

/* Barra de ruta */
.dsp__ruta-bar {
  display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3);
  flex-wrap: wrap; margin-bottom: var(--sp-4);
  background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: var(--r-lg);
  padding: var(--sp-3) var(--sp-4);
}
.dsp__ruta-info { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-13); color: #166534; }
.dsp__ruta-fecha { display: flex; flex-direction: column; gap: 2px; }
.dsp__ruta-hint {
  display: flex; align-items: center; gap: .5rem; margin-bottom: var(--sp-4);
  background: #eff6ff; border: 1.5px solid #bfdbfe; color: #1e40af;
  border-radius: var(--r-lg); padding: var(--sp-3) var(--sp-4); font-size: var(--fs-13);
}
.dsp__ruta-lock {
  display: inline-flex; align-items: center; gap: .4rem; cursor: pointer;
  background: #fff; border: 1.5px solid #cbd5e1; border-radius: 8px;
  padding: .45rem .8rem; font-size: .8rem; font-weight: 700; color: #475569; white-space: nowrap;
}
.dsp__ruta-lock:hover { border-color: #94a3b8; }
.dsp__ruta-lock--on { background: #fef3c7; border-color: #fcd34d; color: #b45309; }
.dsp__ruta-maps {
  display: inline-flex; align-items: center; gap: .4rem; cursor: pointer;
  background: #1d4ed8; color: #fff; border: none; border-radius: 8px;
  padding: .45rem .8rem; font-size: .8rem; font-weight: 700; white-space: nowrap;
}
.dsp__ruta-maps:hover:not(:disabled) { background: #1e40af; }
.dsp__ruta-maps:disabled { opacity: .5; cursor: not-allowed; }

/* Controles de orden en la fila */
.dsp__sel { width: 17px; height: 17px; accent-color: var(--c-leaf-700, #15803d); cursor: pointer; flex-shrink: 0; margin-right: var(--sp-1); }
.dsp__orden { display: flex; align-items: center; gap: .4rem; padding-right: var(--sp-2); border-right: 1px solid var(--c-ink-100); margin-right: var(--sp-2); }
.dsp__orden-n { font-size: 1rem; font-weight: 800; color: var(--c-leaf-700); min-width: 18px; text-align: center; }
.dsp__orden-btns { display: flex; flex-direction: column; gap: 2px; }
.dsp__orden-btn { display: flex; align-items: center; justify-content: center; width: 22px; height: 18px; border: 1px solid var(--c-ink-200); background: #fff; border-radius: 4px; cursor: pointer; color: #475569; font-size: .7rem; padding: 0; }
.dsp__orden-btn:hover:not(:disabled) { background: #f0fdf4; border-color: var(--c-leaf-300); color: var(--c-leaf-700); }
.dsp__orden-btn:disabled { opacity: .4; cursor: not-allowed; }
.dsp__btn-clear {
  background: none;
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .42rem .75rem;
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  cursor: pointer;
  white-space: nowrap;
}
.dsp__btn-clear:hover { border-color: var(--c-ink-400); color: var(--c-ink-700); }

/* Loading / Empty */
.dsp__loading {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: calc(100vh - 56px);
}
.dsp__empty {
  text-align: center;
  padding: var(--sp-12) var(--sp-4);
  color: var(--c-ink-300);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--sp-2);
}
.dsp__empty-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-600); }
.dsp__empty-sub { font-size: var(--fs-13); color: var(--c-ink-400); }

/* Lista */
.dsp__list {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
}
.dsp__row {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  overflow: hidden;
  transition: border-color .15s, box-shadow .15s;
}
.dsp__row--pendiente { border-left: 3px solid #60a5fa; }
.dsp__row--en_viaje  { border-left: 3px solid #fbbf24; }
.dsp__row--entregado { border-left: 3px solid var(--c-leaf-400); }
.dsp__row--fallido   { border-left: 3px solid #f87171; }
.dsp__row:hover { box-shadow: var(--sh-2); border-color: var(--c-ink-200); }

/* Fila principal */
.dsp__row-main {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-4);
  cursor: pointer;
  user-select: none;
}
.dsp__row-left {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  flex-shrink: 0;
  min-width: 200px;
}
.dsp__code {
  font-family: monospace;
  font-size: var(--fs-13);
  font-weight: 700;
  color: var(--c-ink-800);
  background: var(--c-ink-50, #f1f5f9);
  padding: .2em .55em;
  border-radius: 5px;
  white-space: nowrap;
}
.dsp__estado-badge {
  font-size: 11px;
  font-weight: 700;
  padding: .2em .6em;
  border-radius: 5px;
  white-space: nowrap;
}
.dsp__row-mid {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.dsp__row-nombre,
.dsp__row-dir {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-700);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.dsp__row-nombre { font-weight: 600; }
.dsp__row-dir { color: var(--c-ink-500); }
.dsp__row-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
  flex-shrink: 0;
  min-width: 160px;
}
.dsp__row-delivery {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-600);
  font-weight: 500;
}
.dsp__row-fecha {
  font-size: 12px;
  color: var(--c-ink-400);
}
.dsp__row-toggle {
  color: var(--c-ink-300);
  flex-shrink: 0;
}

/* Panel detalle */
.dsp__detail {
  border-top: 1px solid var(--c-ink-100);
  padding: var(--sp-4) var(--sp-5) var(--sp-3);
  background: var(--c-ink-50, #f8fafc);
}
.dsp__detail-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sp-4) var(--sp-6);
  margin-bottom: var(--sp-4);
}
.dsp__detail-col {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.dsp__detail-label {
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: var(--c-ink-400);
  margin-top: var(--sp-2);
}
.dsp__detail-label--red   { color: #dc2626; }
.dsp__detail-label--green { color: var(--c-leaf-700); }
.dsp__detail-val {
  display: flex;
  align-items: flex-start;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-800);
  line-height: 1.4;
}
.dsp__detail-val--italic { font-style: italic; color: var(--c-ink-500); }
.dsp__detail-val--red    { color: #dc2626; }
.dsp__detail-val--green  { color: var(--c-leaf-700); }
.dsp__firma-preview { border: 1px solid #e5e7eb; border-radius: 6px; background: #fff; padding: .4rem; display: inline-block; }
.dsp__firma-img { display: block; max-width: 240px; height: auto; }
.dsp__code-sm {
  font-family: monospace;
  font-size: var(--fs-13);
  background: var(--c-paper);
  border: 1px solid var(--c-ink-200);
  padding: .1em .45em;
  border-radius: 4px;
  color: var(--c-ink-800);
}

/* Reasignación */
.dsp__reasign-bar {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding-top: var(--sp-3);
  border-top: 1px dashed var(--c-ink-200);
  flex-wrap: wrap;
}
.dsp__reasign-label {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-ink-700);
  white-space: nowrap;
}
.dsp__reasign-info {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-13);
  color: var(--c-ink-600);
  flex: 1;
}
.dsp__reasign-select {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-200);
  border-radius: var(--r-md);
  padding: .4rem .7rem;
  font-size: var(--fs-13);
  color: var(--c-ink-800);
  flex: 1;
  min-width: 160px;
}
.dsp__reasign-select:focus { outline: none; border-color: var(--c-leaf-600); }

/* Menú Acciones */
.dsp__acc { position: relative; display: inline-block; }
.dsp__acc-menu {
  position: absolute; top: calc(100% + 4px); right: 0; z-index: 20;
  min-width: 190px; background: #fff; border: 1px solid var(--c-ink-200);
  border-radius: 10px; box-shadow: var(--sh-3, 0 8px 24px rgba(0,0,0,.12));
  padding: 4px; display: flex; flex-direction: column;
}
.dsp__acc-item {
  display: flex; align-items: center; gap: .5rem; width: 100%;
  background: none; border: none; cursor: pointer; text-align: left;
  padding: .5rem .65rem; border-radius: 7px; font-size: var(--fs-13);
  color: var(--c-ink-700); white-space: nowrap;
}
.dsp__acc-item:hover:not(:disabled) { background: var(--c-ink-50, #f1f5f9); }
.dsp__acc-item:disabled { opacity: .5; cursor: not-allowed; }

/* Botones */
.dsp__btn-confirm {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--c-leaf-700);
  color: #fff;
  border: none;
  padding: .42rem .9rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
}
.dsp__btn-confirm:hover:not(:disabled) { background: var(--c-leaf-800); }
.dsp__btn-confirm:disabled { opacity: .5; cursor: not-allowed; }
.dsp__btn-fallo {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #fff; color: #dc2626; border: 1.5px solid #fecaca;
  padding: .42rem .9rem; border-radius: var(--r-md); font-size: var(--fs-13);
  font-weight: 600; cursor: pointer; white-space: nowrap;
}
.dsp__btn-fallo:hover:not(:disabled) { background: #fef2f2; }
.dsp__btn-fallo:disabled { opacity: .5; cursor: not-allowed; }

/* Modales completar entrega / fallo */
.dsp__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.dsp__modal { background: #fff; border-radius: 14px; width: 100%; max-width: 420px; padding: 1.25rem; box-shadow: 0 24px 64px rgba(0,0,0,.18); }
.dsp__modal-title { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; }
.dsp__modal-sub { font-size: .8rem; color: #64748b; margin: 0 0 .9rem; }
.dsp__modal-label { display: block; font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .3rem; }
.dsp__opt { font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.dsp__req { color: #dc2626; }
.dsp__modal-input { width: 100%; box-sizing: border-box; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .8rem; font-size: .85rem; color: #0f172a; outline: none; resize: vertical; }
.dsp__modal-warn { display: flex; align-items: flex-start; gap: .4rem; background: #fffbeb; border: 1px solid #fde68a; color: #92400e; border-radius: 9px; padding: .55rem .7rem; font-size: .78rem; margin-bottom: .75rem; }

/* Historial de la entrega */
.dsp__historial { margin-top: var(--sp-3); padding-top: var(--sp-3); border-top: 1px solid var(--c-ink-100, #f1f5f9); }
.dsp__hist-row { display: flex; align-items: center; flex-wrap: wrap; gap: .35rem; font-size: .78rem; color: #475569; padding: .2rem 0; }
.dsp__hist-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.dsp__hist-evento { font-weight: 700; color: #0f172a; }
.dsp__hist-fecha { color: #94a3b8; }
.dsp__hist-user { color: #64748b; }
.dsp__hist-motivo { color: #64748b; font-style: italic; }
.dsp__modal-foot { display: flex; justify-content: flex-end; gap: .6rem; margin-top: 1rem; }
.dsp__btn-ghost {
  background: var(--c-paper);
  color: var(--c-ink-500);
  border: 1.5px solid var(--c-ink-200);
  padding: .42rem .8rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 500;
  cursor: pointer;
}
.dsp__btn-ghost:hover { border-color: var(--c-ink-400); }
.dsp__btn-outline {
  background: none;
  color: var(--c-leaf-700);
  border: 1.5px solid var(--c-leaf-300);
  padding: .38rem .8rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: background .15s, border-color .15s;
}
.dsp__btn-outline:hover { background: var(--c-leaf-50); border-color: var(--c-leaf-600); }
.dsp__btn-reprogramar {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  background: #fff7ed;
  color: #c2410c;
  border: 1.5px solid #fed7aa;
  padding: .38rem .8rem;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: background .15s, border-color .15s;
}
.dsp__btn-reprogramar:hover:not(:disabled) { background: #ffedd5; border-color: #fb923c; }
.dsp__btn-reprogramar:disabled { opacity: .5; cursor: not-allowed; }


/* Próximas entregas (reservas con envío) */
.dsp__resv {
  background: var(--c-leaf-50);
  border: 1px solid var(--c-leaf-100);
  border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-5);
  margin-bottom: var(--sp-5);
}
.dsp__resv-head {
  display: flex; align-items: center; gap: var(--sp-2);
  color: var(--c-leaf-800); margin-bottom: var(--sp-3);
}
.dsp__resv-title { font-size: var(--fs-14); font-weight: 700; }
.dsp__resv-count {
  background: var(--c-leaf-700); color: #fff; font-size: var(--fs-11); font-weight: 700;
  min-width: 18px; text-align: center; padding: 1px 6px; border-radius: 10px;
}
.dsp__resv-hint { font-size: var(--fs-12); color: var(--c-ink-500); font-weight: 500; }

.dsp__resv-list { display: flex; flex-direction: column; gap: var(--sp-2); }
.dsp__resv-card {
  display: flex; align-items: center; gap: var(--sp-4);
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-left: 3px solid var(--c-leaf-500);
  border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
}
.dsp__resv-card--vencida { border-left-color: #dc2626; }
.dsp__resv-card--hoy     { border-left-color: #d97706; }
.dsp__resv-card--proxima { border-left-color: var(--c-leaf-500); }

.dsp__resv-when { display: flex; align-items: center; gap: 6px; min-width: 150px; color: var(--c-ink-500); }
.dsp__resv-urg { font-size: var(--fs-11); font-weight: 700; text-transform: uppercase; letter-spacing: .04em; }
.dsp__resv-urg--vencida { color: #dc2626; }
.dsp__resv-urg--hoy     { color: #d97706; }
.dsp__resv-urg--proxima { color: var(--c-leaf-700); }
.dsp__resv-date { font-size: var(--fs-12); color: var(--c-ink-500); }

.dsp__resv-body { flex: 1; min-width: 0; }
.dsp__resv-nombre { display: flex; align-items: center; gap: 5px; font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.dsp__resv-meta {
  display: flex; flex-wrap: wrap; gap: 4px var(--sp-3); margin-top: 2px;
  font-size: var(--fs-12); color: var(--c-ink-500);
}
.dsp__resv-meta span { display: inline-flex; align-items: center; gap: 4px; }
.dsp__resv-cobrar { color: #d97706; font-weight: 700; }

.dsp__resv-btn {
  display: inline-flex; align-items: center; gap: 6px; flex-shrink: 0;
  background: var(--c-leaf-700); color: #fff; border: none;
  padding: .5rem .9rem; border-radius: var(--r-sm);
  font-size: var(--fs-13); font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.dsp__resv-btn:hover:not(:disabled) { background: var(--c-leaf-800); }
.dsp__resv-btn:disabled { opacity: .5; cursor: not-allowed; }

@media (max-width: 768px) {
  .dsp { padding: var(--sp-4); }
  .dsp__kpis { grid-template-columns: repeat(2, 1fr); }
  .dsp__row-main { flex-wrap: wrap; }
  .dsp__row-left { min-width: unset; }
  .dsp__row-right { align-items: flex-start; }
  .dsp__detail-grid { grid-template-columns: 1fr; }
  .dsp__resv-card { flex-wrap: wrap; }
  .dsp__resv-btn { width: 100%; justify-content: center; }
}
</style>
