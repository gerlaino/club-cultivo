<template>
  <div class="tv">

    <!-- Header -->
    <div class="tv__header">
      <div class="tv__header-left">
        <h1 class="tv__title">Tareas</h1>
        <p class="tv__sub">{{ fechaHoy }} · {{ saludo }}</p>
      </div>
      <div class="tv__header-right">
        <div class="tv__tabs">
          <button class="tv__tab" :class="{ 'tv__tab--active': vistaActiva === 'semana' }" @click="vistaActiva = 'semana'">
            <i class="bi bi-calendar-week"></i> Semana
          </button>
          <button class="tv__tab" :class="{ 'tv__tab--active': vistaActiva === 'kanban' }" @click="cambiarAKanban">
            <i class="bi bi-kanban"></i> Kanban
          </button>
        </div>
        <button v-if="puedeCrear" class="tv__btn-primary" @click="abrirModalNueva">
          <i class="bi bi-plus-lg"></i> Nueva tarea
        </button>
      </div>
    </div>

    <!-- KPIs -->
    <div class="tv__kpis">
      <div class="tv__kpi">
        <div class="tv__kpi-val" style="color:#64748b">{{ stats.pendientes || 0 }}</div>
        <div class="tv__kpi-label">Pendientes</div>
        <div class="tv__kpi-bar" style="background:#64748b"></div>
      </div>
      <div class="tv__kpi">
        <div class="tv__kpi-val" style="color:#d97706">{{ stats.en_progreso || 0 }}</div>
        <div class="tv__kpi-label">En progreso</div>
        <div class="tv__kpi-bar" style="background:#d97706"></div>
      </div>
      <div class="tv__kpi">
        <div class="tv__kpi-val" style="color:#15803d">{{ stats.completadas_hoy || 0 }}</div>
        <div class="tv__kpi-label">Completadas hoy</div>
        <div class="tv__kpi-bar" style="background:#15803d"></div>
      </div>
      <div class="tv__kpi" :class="{ 'tv__kpi--alert': stats.vencidas > 0 }">
        <div class="tv__kpi-val" :style="{ color: stats.vencidas > 0 ? '#dc2626' : '#94a3b8' }">{{ stats.vencidas || 0 }}</div>
        <div class="tv__kpi-label">Vencidas</div>
        <div class="tv__kpi-bar" :style="{ background: stats.vencidas > 0 ? '#dc2626' : '#e2e8f0' }"></div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="tv__loading">
      <div class="tv__ring"></div><span>Cargando tareas…</span>
    </div>

    <template v-else>

      <!-- ══ KANBAN COMPLETO ══ -->
      <div v-if="vistaActiva === 'kanban'">

        <!-- Filtros -->
        <div class="tv__filtros">
          <select v-if="esAdmin" v-model="filtros.asignada_a_id" class="tv__filtro-select" @change="cargarKanban">
            <option value="">Todos los usuarios</option>
            <option v-for="u in usuarios" :key="u.id" :value="u.id">{{ u.nombre_completo }}</option>
          </select>
          <select v-model="filtros.sala_id" class="tv__filtro-select" @change="onFiltroSala">
            <option value="">Todas las salas</option>
            <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
          </select>
          <select v-model="filtros.lote_id" class="tv__filtro-select" @change="cargarKanban">
            <option value="">Todos los lotes</option>
            <option v-for="l in lotesFiltrados" :key="l.id" :value="l.id">{{ l.codigo }}</option>
          </select>
          <button v-if="filtros.asignada_a_id || filtros.sala_id || filtros.lote_id" class="tv__btn-clear" @click="limpiarFiltros">
            <i class="bi bi-x-circle"></i> Limpiar
          </button>
        </div>

        <div class="tv__kanban-cols">
          <div v-for="col in columnas" :key="col.key" class="tv__col">
            <div class="tv__col-header" :class="`tv__col-header--${col.clase}`">
              <span>{{ col.label }}</span>
              <span class="tv__col-count">{{ kanban[col.key]?.length || 0 }}</span>
            </div>
            <div class="tv__col-body">
              <TareaCard v-for="t in kanban[col.key]" :key="t.id" :tarea="t"
                         @click="abrirDetalle(t)"
                         @completar="abrirModalCompletar(t)" @editar="abrirModalEditar(t)"
                         @cancelar="confirmarCancelar(t)" @cancelar-serie="confirmarCancelarSerie(t)" />
              <EmptyState v-if="!kanban[col.key]?.length" icon="bi-inbox" title="Sin tareas" compact />
            </div>
          </div>
        </div>

      </div>

      <!-- Vista Semana -->
      <div v-if="vistaActiva === 'semana'" class="tv__semana">
        <div class="sem__nav">
          <button class="sem__nav-btn" @click="semAnterior">
            <i class="bi bi-chevron-left"></i>
          </button>
          <span class="sem__nav-label">{{ labelSemana }}</span>
          <button class="sem__nav-btn" @click="semSiguiente">
            <i class="bi bi-chevron-right"></i>
          </button>
          <button class="sem__hoy-btn" @click="irHoy">Hoy</button>
        </div>

        <div v-if="loadingSem" class="sem__loading">
          <div class="sem__ring"></div>
        </div>

        <div v-else class="sem__grid">
          <div
            v-for="dia in semana.dias"
            :key="dia.fecha"
            class="sem__col"
            :class="{ 'sem__col--hoy': esDiaHoy(dia.fecha), 'sem__col--pasado': esPasado(dia.fecha) }"
          >
            <div class="sem__col-header">
              <div class="sem__dia-nombre">{{ dia.dia_semana?.slice(0, 3) }}</div>
              <div class="sem__dia-num" :class="{ 'sem__dia-num--hoy': esDiaHoy(dia.fecha) }">
                {{ new Date(dia.fecha + 'T00:00:00').getDate() }}
              </div>
              <div class="sem__col-count" v-if="dia.tareas.length">{{ dia.tareas.length }}</div>
            </div>
            <div class="sem__tareas">
              <div
                v-for="t in dia.tareas"
                :key="t.id"
                class="sem__tarea"
                :class="['sem__tarea--' + t.prioridad, t.estado === 'completada' && 'sem__tarea--done']"
                @click="abrirTarea(t)"
              >
                <span class="sem__tarea-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
                <span class="sem__tarea-titulo">{{ t.titulo }}</span>
                <span v-if="t.parent_tarea_id || t.recurrente" class="sem__recurrente" title="Tarea recurrente">🔁</span>
                <span v-if="t.asignada_a" class="sem__asig" :title="t.asignada_a.nombre">
                  {{ t.asignada_a.nombre.split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase() }}
                </span>
              </div>
              <button class="sem__add" @click="nuevaTareaEnDia(dia.fecha)" title="Nueva tarea">
                <i class="bi bi-plus"></i>
              </button>
            </div>
          </div>
        </div>
      </div>

    </template>

    <!-- Panel detalle -->
    <Teleport to="body">
      <div v-if="tareaDetalle" class="tv__panel-overlay" @click.self="tareaDetalle = null">
        <div class="tv__panel">
          <div class="tv__panel-header">
            <h3 class="tv__panel-title">Detalle de tarea</h3>
            <button class="tv__panel-close" @click="tareaDetalle = null"><i class="bi bi-x-lg"></i></button>
          </div>

          <div class="tv__panel-body">
            <div class="tv__panel-tipo">
              <span class="tv__tipo-pill">{{ TIPO_META[tareaDetalle.tipo]?.emoji }} {{ TIPO_META[tareaDetalle.tipo]?.label }}</span>
            </div>
            <h4 class="tv__panel-nombre">{{ tareaDetalle.titulo }}</h4>
            <p v-if="tareaDetalle.descripcion" class="tv__panel-desc">{{ tareaDetalle.descripcion }}</p>

            <div class="tv__panel-info">
              <div class="tv__panel-row">
                <span class="tv__panel-key">Estado</span>
                <span class="tv__estado-pill" :style="estadoMeta(tareaDetalle.estado)">{{ tareaDetalle.estado?.replace('_',' ') }}</span>
              </div>
              <div class="tv__panel-row">
                <span class="tv__panel-key">Prioridad</span>
                <span>{{ tareaDetalle.prioridad }}</span>
              </div>
              <div v-if="tareaDetalle.asignada_a" class="tv__panel-row">
                <span class="tv__panel-key">Asignada a</span>
                <span>{{ tareaDetalle.asignada_a.nombre }}</span>
              </div>
              <div v-if="tareaDetalle.sala" class="tv__panel-row">
                <span class="tv__panel-key">Sala</span>
                <span>{{ tareaDetalle.sala.nombre }}</span>
              </div>
              <div v-if="tareaDetalle.lote" class="tv__panel-row">
                <span class="tv__panel-key">Lote</span>
                <RouterLink :to="`/lotes/${tareaDetalle.lote.id}`" class="tv__panel-link">
                  {{ tareaDetalle.lote.codigo }} <i class="bi bi-arrow-right-short"></i>
                </RouterLink>
              </div>
              <div v-if="tareaDetalle.fecha_programada" class="tv__panel-row">
                <span class="tv__panel-key">Fecha</span>
                <span>{{ formatFechaLarga(tareaDetalle.fecha_programada) }}</span>
              </div>
              <div v-if="tareaDetalle.horas_estimadas" class="tv__panel-row">
                <span class="tv__panel-key">Hs. estimadas</span>
                <span>{{ tareaDetalle.horas_estimadas }}h</span>
              </div>
              <div v-if="tareaDetalle.horas_reales" class="tv__panel-row">
                <span class="tv__panel-key">Hs. reales</span>
                <strong>{{ tareaDetalle.horas_reales }}h</strong>
              </div>
            </div>

            <div v-if="tareaDetalle.tiene_horas_para_lote" class="tv__panel-hint">
              <i class="bi bi-clock-history"></i>
              <strong>{{ tareaDetalle.horas_reales }}h</strong> disponibles para aplicar al lote.
              <RouterLink :to="`/lotes/${tareaDetalle.lote.id}`">Ir al lote →</RouterLink>
            </div>

            <div class="tv__panel-actions">
              <button v-if="['pendiente','en_progreso'].includes(tareaDetalle.estado) && !esTareaFutura(tareaDetalle)" class="tv__panel-btn tv__panel-btn--primary" @click="abrirModalCompletar(tareaDetalle)">
                <i class="bi bi-check-circle"></i> Completar
              </button>
              <p v-if="esTareaFutura(tareaDetalle) && ['pendiente','en_progreso'].includes(tareaDetalle.estado)" class="tv__futura-hint">
                <i class="bi bi-calendar-event me-1"></i>Disponible el {{ tareaDetalle.fecha_programada }}
              </p>
              <button v-if="puedeEditarTarea(tareaDetalle)" class="tv__panel-btn tv__panel-btn--ghost" @click="abrirModalEditar(tareaDetalle)">
                <i class="bi bi-pencil"></i> Editar
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modales -->
    <ModalTarea
      :show="showModalTarea"
      :tarea-inicial="tareaEditando"
      :salas="salas"
      :lotes="lotes"
      :usuarios="usuarios"
      @guardada="onTareaGuardada"
      @cerrar="showModalTarea = false"
    />
    <ModalCompletarTarea
      :show="showModalCompletar"
      :tarea="tareaCompletando"
      @completada="onTareaCompletada"
      @cerrar="showModalCompletar = false"
    />


  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { logger } from '../utils/logger.js'
import { useAuthStore } from '../stores/auth'
import { useTareasStore } from '../stores/tareas'
import TareaCard from '../components/TareaCard.vue'
import ModalTarea from '../components/ModalTarea.vue'
import ModalCompletarTarea from '../components/ModalCompletarTarea.vue'
import { listSalas, listLotes, listUsers, listSedes, getTareasSemana } from '../lib/api'
import { storeToRefs } from 'pinia'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import EmptyState from '../components/ui/EmptyState.vue'
import { formatFechaLarga } from '../utils/fecha.js'

const authStore   = useAuthStore()
const tareasStore = useTareasStore()

const vistaActiva       = ref('semana')
const showModalTarea    = ref(false)
const showModalCompletar = ref(false)
const tareaEditando     = ref(null)
const tareaCompletando  = ref(null)
const tareaDetalle      = ref(null)
const salas             = ref([])
const sedes             = ref([])
const lotes             = ref([])
const usuarios          = ref([])
const filtros           = ref({ asignada_a_id: '', sala_id: '', lote_id: '' })
const toast             = useToast()
const { confirm }       = useConfirm()

const { loading, dashboard, kanban, stats, hayVencidas, hoyPendientes, hoyEnProgreso, hoyCompletadas } = storeToRefs(tareasStore)

const esAdmin    = computed(() => authStore.user?.role === 'admin')
const puedeCrear = computed(() => authStore.user?.role === 'admin')

const fechaHoy = computed(() => {
  const s = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
  return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()
})
const saludo = computed(() => {
  const h = new Date().getHours()
  const n = authStore.user?.first_name || ''
  if (h < 12) return `Buenos días, ${n}`
  if (h < 19) return `Buenas tardes, ${n}`
  return `Buenas noches, ${n}`
})

const lotesFiltrados = computed(() => {
  if (!filtros.value.sala_id) return lotes.value
  return lotes.value.filter(l => String(l.sala_id) === String(filtros.value.sala_id))
})

const columnas = [
  { key: 'pendiente',   label: 'Pendiente',  clase: 'pending'  },
  { key: 'en_progreso', label: 'En progreso', clase: 'progress' },
  { key: 'completada',  label: 'Completadas', clase: 'done'     },
]

const TIPO_META = {
  riego:       { label: 'Riego',      emoji: '💧' },
  poda:        { label: 'Poda',       emoji: '✂️' },
  medicion:    { label: 'Medición',   emoji: '📏' },
  limpieza:    { label: 'Limpieza',   emoji: '🧹' },
  cosecha:     { label: 'Cosecha',    emoji: '🌿' },
  transplante: { label: 'Trasplante', emoji: '🪴' },
  inspeccion:  { label: 'Inspección', emoji: '🔍' },
  otro:        { label: 'Otro',       emoji: '📋' },
}

function estadoMeta(estado) {
  return {
    pendiente:   { background: 'rgba(100,116,139,.1)', color: '#475569' },
    en_progreso: { background: 'rgba(217,119,6,.1)',   color: '#d97706' },
    completada:  { background: 'rgba(21,128,61,.1)',   color: '#15803d' },
    cancelada:   { background: 'rgba(220,38,38,.1)',   color: '#dc2626' },
  }[estado] || { background: '#f1f5f9', color: '#64748b' }
}

const semana       = ref({ desde: null, hasta: null, dias: [] })
const loadingSem   = ref(false)

function lunasActual() {
  const hoy = new Date()
  const dow  = hoy.getDay()
  const diff = dow === 0 ? -6 : 1 - dow
  const d = new Date(hoy)
  d.setDate(hoy.getDate() + diff)
  return d.toISOString().slice(0, 10)
}
const desdeRef = ref(lunasActual())

async function cargarSemana() {
  loadingSem.value = true
  try {
    const { data } = await getTareasSemana(desdeRef.value)
    semana.value = data
  } finally {
    loadingSem.value = false
  }
}

function semAnterior() {
  const d = new Date(desdeRef.value + 'T00:00:00')
  d.setDate(d.getDate() - 7)
  desdeRef.value = d.toISOString().slice(0, 10)
  cargarSemana()
}

function semSiguiente() {
  const d = new Date(desdeRef.value + 'T00:00:00')
  d.setDate(d.getDate() + 7)
  desdeRef.value = d.toISOString().slice(0, 10)
  cargarSemana()
}

function irHoy() {
  desdeRef.value = lunasActual()
  cargarSemana()
}

const labelSemana = computed(() => {
  if (!semana.value.desde) return ''
  const d = new Date(semana.value.desde + 'T00:00:00')
  const h = new Date(semana.value.hasta  + 'T00:00:00')
  return `${d.getDate()} — ${h.getDate()} ${h.toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })}`
})

function esDiaHoy(fechaStr) {
  return fechaStr === new Date().toISOString().slice(0, 10)
}
function esPasado(fechaStr) {
  return fechaStr < new Date().toISOString().slice(0, 10)
}

const TIPO_EMOJI = {
  riego: '💧', poda: '✂️', medicion: '📏', limpieza: '🧹',
  cosecha: '🌿', transplante: '🪴', inspeccion: '🔍', otro: '📋',
}

function nuevaTareaEnDia(fecha) {
  tareaEditando.value = null
  showModalTarea.value = true
}

function abrirTarea(tarea) {
  abrirDetalle(tarea)
}

watch(vistaActiva, (v) => {
  if (v === 'semana' && !semana.value.dias.length) cargarSemana()
})

function escapeHandler(e) {
  if (e.key !== 'Escape') return
  if (tareaDetalle.value) { tareaDetalle.value = null }
}
onMounted(async () => {
  document.addEventListener('keydown', escapeHandler, true)
  await cargarContexto()
  await tareasStore.fetchDashboard()
  await cargarSemana()
})
onUnmounted(() => { document.removeEventListener('keydown', escapeHandler, true) })

async function cargarContexto() {
  try {
    const [resSalas, resLotes, resSedes] = await Promise.all([listSalas(), listLotes(), listSedes()])
    salas.value = resSalas.data || []
    lotes.value = resLotes.data || []
    sedes.value = resSedes.data || []
    if (esAdmin.value) {
      const resU = await listUsers()
      usuarios.value = (resU.data?.data || resU.data || []).map(u => ({
        ...u, nombre_completo: `${u.first_name} ${u.last_name}`.trim()
      }))
    }
  } catch (e) { logger.error('Error cargando contexto:', e) }
}

async function cambiarAKanban() { vistaActiva.value = 'kanban'; await cargarKanban() }
async function cargarKanban() {
  const params = {}
  if (filtros.value.asignada_a_id) params.asignada_a_id = filtros.value.asignada_a_id
  if (filtros.value.sala_id)       params.sala_id       = filtros.value.sala_id
  if (filtros.value.lote_id)       params.lote_id       = filtros.value.lote_id
  await tareasStore.fetchKanban(params)
}
function onFiltroSala() { filtros.value.lote_id = ''; cargarKanban() }
function limpiarFiltros() { filtros.value = { asignada_a_id: '', sala_id: '', lote_id: '' }; cargarKanban() }

function abrirModalNueva() { tareaEditando.value = null; showModalTarea.value = true }
function abrirModalEditar(t) { tareaEditando.value = t; tareaDetalle.value = null; showModalTarea.value = true }
function abrirModalCompletar(t) { tareaCompletando.value = t; tareaDetalle.value = null; showModalCompletar.value = true }
function abrirDetalle(t) { tareaDetalle.value = t }

async function confirmarCancelar(t) {
  const ok = await confirm({ title: `¿Cancelar la tarea "${t.titulo}"?`, variant: 'warning', confirmText: 'Cancelar tarea', cancelText: 'Volver' })
  if (!ok) return
  try { await tareasStore.cancelar(t.id); tareaDetalle.value = null; toast.warning('Tarea cancelada') }
  catch (e) { toast.error(e.response?.data?.error || 'Error') }
}

async function confirmarCancelarSerie(t) {
  const ok = await confirm({
    title: '¿Cancelar toda la serie?',
    message: `Se cancelarán todas las tareas pendientes de la serie "${t.titulo}".`,
    variant: 'warning',
    confirmText: 'Cancelar serie',
    cancelText: 'Volver',
  })
  if (!ok) return
  try {
    const res = await tareasStore.cancelarSerie(t.id)
    tareaDetalle.value = null
    toast.warning(`${res?.canceladas ?? 'N'} tareas canceladas`)
    tareasStore.fetchDashboard()
    if (vistaActiva.value === 'kanban') cargarKanban()
    if (vistaActiva.value === 'semana') cargarSemana()
  } catch (e) { toast.error(e.response?.data?.error || 'Error al cancelar serie') }
}
function onTareaGuardada() {
  showModalTarea.value = false
  tareaEditando.value = null
  toast.success('Tarea guardada ✓')
  tareasStore.fetchDashboard()
  cargarSemana()
}
function onTareaCompletada() {
  showModalCompletar.value = false
  tareaCompletando.value = null
  tareaDetalle.value = null
  toast.success('Tarea completada ✓')
  tareasStore.fetchDashboard()
  if (vistaActiva.value === 'kanban') cargarKanban()
  if (vistaActiva.value === 'semana') cargarSemana()
}

function puedeEditarTarea(t) {
  const u = authStore.user
  return ['admin', 'cultivador', 'supervisor'].includes(u?.role)
}

function esTareaFutura(t) {
  if (!t?.fecha_programada) return false
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0)
  return new Date(t.fecha_programada + 'T00:00:00') > hoy
}

function mostrarToast(mensaje, tipo = 'success') {
  if (tipo === 'error') toast.error(mensaje)
  else if (tipo === 'warning') toast.warning(mensaje)
  else toast.success(mensaje)
}
</script>

<style scoped>
.tv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .tv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.tv__header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.tv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.tv__sub { font-size: .82rem; color: #64748b; margin: 0; }
.tv__header-right { display: flex; align-items: center; gap: .75rem; }

/* Tabs */
.tv__tabs { display: flex; background: #f1f5f9; border-radius: 10px; padding: 3px; }
.tv__tab { display: flex; align-items: center; gap: .35rem; padding: .5rem .875rem; border-radius: 8px; border: none; background: none; font-size: .8rem; font-weight: 600; color: #64748b; cursor: pointer; transition: all .15s; }
.tv__tab--active { background: #fff; color: #1b5e20; box-shadow: 0 1px 4px rgba(0,0,0,.1); }

/* KPIs */
.tv__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.75rem; }
@media (max-width: 640px) { .tv__kpis { grid-template-columns: 1fr 1fr; } }
.tv__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.1rem 1.25rem; position: relative; overflow: hidden; transition: box-shadow .15s; }
.tv__kpi:hover { box-shadow: 0 4px 12px rgba(0,0,0,.06); }
.tv__kpi--alert { border-color: #fecaca; }
.tv__kpi-val { font-size: 1.75rem; font-weight: 900; letter-spacing: -.04em; margin-bottom: .15rem; }
.tv__kpi-label { font-size: .7rem; font-weight: 600; color: #64748b; text-transform: uppercase; letter-spacing: .05em; }
.tv__kpi-bar { position: absolute; bottom: 0; left: 0; right: 0; height: 3px; }

/* Loading */
.tv__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.tv__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: tv-spin .7s linear infinite; }
@keyframes tv-spin { to { transform: rotate(360deg); } }

/* Alerta */
.tv__alerta { display: flex; align-items: center; gap: .75rem; background: #fef2f2; border: 1px solid #fecaca; color: #7f1d1d; padding: .875rem 1.1rem; border-radius: 12px; margin-bottom: 1.25rem; font-size: .875rem; flex-wrap: wrap; }
.tv__alerta i { color: #dc2626; font-size: 1.1rem; flex-shrink: 0; }
.tv__alerta-sub { color: #991b1b; font-weight: 400; }
.tv__alerta-btn { margin-left: auto; background: #fff; border: 1.5px solid #fecaca; color: #dc2626; padding: .35rem .875rem; border-radius: 7px; font-size: .78rem; font-weight: 600; cursor: pointer; flex-shrink: 0; }

/* Secciones */
.tv__section { background: #fff; border: 1px solid #e2e8f0; border-radius: 16px; overflow: hidden; }
.tv__section--mt { margin-top: 1.25rem; }
.tv__section-header { display: flex; align-items: center; gap: .65rem; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.tv__section-title { font-size: .9rem; font-weight: 700; color: #0f172a; flex: 1; }
.tv__section-count { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .6em; border-radius: 6px; }

/* Kanban cols */
.tv__kanban-cols { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; padding: 1rem; }
@media (max-width: 900px) { .tv__kanban-cols { grid-template-columns: 1fr; } }
.tv__col { background: #f8fafc; border-radius: 12px; overflow: hidden; }
.tv__col-header { display: flex; align-items: center; justify-content: space-between; padding: .65rem .875rem; font-size: .75rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; }
.tv__col-header--pending  { background: rgba(100,116,139,.08); color: #475569; }
.tv__col-header--progress { background: rgba(217,119,6,.1);   color: #b45309; }
.tv__col-header--done     { background: rgba(21,128,61,.1);   color: #15803d; }
.tv__col-count { font-size: .7rem; font-weight: 700; background: rgba(0,0,0,.06); padding: .15em .5em; border-radius: 5px; }
.tv__col-body { padding: .75rem; min-height: 100px; max-height: 65vh; overflow-y: auto; display: flex; flex-direction: column; gap: .5rem; }

/* Próximas */
.tv__proximas { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: .75rem; padding: 1rem; }

/* Empty */

/* Filtros kanban */
.tv__filtros { display: flex; align-items: center; gap: .65rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.tv__filtro-select { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; font-size: .82rem; color: #0f172a; outline: none; cursor: pointer; }
.tv__filtro-select:focus { border-color: #1b5e20; }
.tv__btn-clear { display: inline-flex; align-items: center; gap: .3rem; background: none; border: 1.5px solid #e2e8f0; color: #64748b; padding: .55rem .875rem; border-radius: 9px; font-size: .8rem; font-weight: 500; cursor: pointer; }
.tv__btn-clear:hover { border-color: #dc2626; color: #dc2626; background: #fef2f2; }

/* Panel detalle */
.tv__panel-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.35); z-index: 1040; display: flex; justify-content: flex-end; }
.tv__panel { width: min(420px, 100vw); height: 100%; background: #fff; display: flex; flex-direction: column; box-shadow: -8px 0 32px rgba(0,0,0,.12); animation: tv-slide .2s ease; }
@keyframes tv-slide { from { transform: translateX(100%); } to { transform: translateX(0); } }
.tv__panel-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; }
.tv__panel-title { font-size: .95rem; font-weight: 700; margin: 0; }
.tv__panel-close { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.tv__panel-close:hover { background: #e2e8f0; }
.tv__panel-body { padding: 1.5rem; flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 1rem; }
.tv__panel-tipo { }
.tv__tipo-pill { display: inline-flex; align-items: center; gap: .35rem; background: #e8f5e9; color: #1b5e20; font-size: .75rem; font-weight: 700; padding: .25em .75em; border-radius: 6px; }
.tv__panel-nombre { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.03em; }
.tv__panel-desc { font-size: .85rem; color: #64748b; margin: 0; line-height: 1.6; }
.tv__panel-info { border: 1px solid #f1f5f9; border-radius: 10px; overflow: hidden; }
.tv__panel-row { display: flex; justify-content: space-between; align-items: center; padding: .65rem 1rem; border-bottom: 1px solid #f8fafc; font-size: .82rem; }
.tv__panel-row:last-child { border-bottom: none; }
.tv__panel-key { color: #94a3b8; font-size: .72rem; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; }
.tv__panel-link { color: #1b5e20; text-decoration: none; font-weight: 600; }
.tv__panel-hint { background: #fffbeb; border: 1px solid #fde68a; color: #78350f; padding: .75rem 1rem; border-radius: 9px; font-size: .82rem; display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.tv__estado-pill { font-size: .7rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; text-transform: capitalize; }
.tv__panel-actions { display: flex; flex-direction: column; gap: .5rem; padding-top: .5rem; }
.tv__futura-hint { display: flex; align-items: center; gap: .4rem; font-size: .8rem; color: #64748b; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: .55rem .875rem; margin: 0; }
.tv__panel-btn { display: flex; align-items: center; justify-content: center; gap: .5rem; padding: .65rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; }
.tv__panel-btn--primary { background: #1b5e20; color: #fff; }
.tv__panel-btn--primary:hover { background: #144a18; }
.tv__panel-btn--ghost { background: #f8fafc; color: #475569; border: 1.5px solid #e2e8f0; }
.tv__panel-btn--ghost:hover { background: #e2e8f0; }

/* Buttons */
.tv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.tv__btn-primary:hover { background: #144a18; }

/* Toast */

/* Vista Semana */
.tv__semana { padding: .5rem 0; }
.sem__nav { display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }
.sem__nav-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 8px; width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: #64748b; transition: all .15s; }
.sem__nav-btn:hover { border-color: #94a3b8; color: #0f172a; }
.sem__nav-label { flex: 1; text-align: center; font-size: .9rem; font-weight: 700; color: #0f172a; }
.sem__hoy-btn { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .3rem .75rem; font-size: .78rem; font-weight: 600; color: #475569; cursor: pointer; }
.sem__hoy-btn:hover { background: #e2e8f0; }
.sem__loading { display: flex; justify-content: center; padding: 3rem; }
.sem__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: spin .7s linear infinite; }
.sem__grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: .5rem; }
@media (max-width: 900px) { .sem__grid { grid-template-columns: repeat(7, minmax(110px, 1fr)); overflow-x: auto; } }
.sem__col { border: 1.5px solid #e2e8f0; border-radius: 10px; background: #fff; display: flex; flex-direction: column; min-height: 280px; overflow: hidden; }
.sem__col--hoy { border-color: #3b82f6; }
.sem__col--pasado { opacity: .65; }
.sem__col-header { padding: .5rem .6rem; text-align: center; border-bottom: 1px solid #f1f5f9; background: #fafbfc; display: flex; flex-direction: column; align-items: center; gap: .1rem; }
.sem__col--hoy .sem__col-header { background: #eff6ff; }
.sem__dia-nombre { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; }
.sem__dia-num { font-size: 1.2rem; font-weight: 800; color: #0f172a; line-height: 1; }
.sem__dia-num--hoy { color: #2563eb; }
.sem__col-count { font-size: .6rem; font-weight: 700; background: #e0e7ff; color: #4338ca; padding: .1em .35em; border-radius: 3px; }
.sem__tareas { flex: 1; padding: .4rem; display: flex; flex-direction: column; gap: .3rem; }
.sem__tarea { display: flex; align-items: center; gap: .3rem; padding: .35rem .45rem; border-radius: 6px; border-left: 3px solid #e2e8f0; background: #f8fafc; cursor: pointer; font-size: .72rem; transition: opacity .12s; }
.sem__tarea:hover { opacity: .8; }
.sem__tarea--urgente { border-left-color: #dc2626; }
.sem__tarea--alta    { border-left-color: #f97316; }
.sem__tarea--normal  { border-left-color: #3b82f6; }
.sem__tarea--baja    { border-left-color: #9ca3af; }
.sem__tarea--done    { opacity: .35; text-decoration: line-through; }
.sem__tarea-emoji { flex-shrink: 0; font-size: .8rem; }
.sem__tarea-titulo { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #0f172a; font-weight: 500; }
.sem__recurrente { font-size: .65rem; flex-shrink: 0; }
.sem__asig { width: 18px; height: 18px; border-radius: 50%; background: #e0e7ff; color: #4338ca; font-size: .6rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sem__add { align-self: flex-start; border: 1.5px dashed #d1d5db; background: none; border-radius: 6px; width: 22px; height: 22px; cursor: pointer; color: #9ca3af; font-size: 1rem; display: flex; align-items: center; justify-content: center; transition: all .15s; margin-top: auto; }
.sem__add:hover { border-color: #6b7280; color: #374151; }
</style>
