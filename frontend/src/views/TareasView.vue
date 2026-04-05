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
          <button class="tv__tab" :class="{ 'tv__tab--active': vistaActiva === 'dashboard' }" @click="vistaActiva = 'dashboard'">
            <i class="bi bi-grid-1x2"></i> Mi día
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

      <!-- ══ DASHBOARD ══ -->
      <div v-if="vistaActiva === 'dashboard'">

        <!-- Alerta vencidas -->
        <div v-if="hayVencidas" class="tv__alerta">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <div>
            <strong>{{ dashboard.vencidas.length }} tarea{{ dashboard.vencidas.length > 1 ? 's' : '' }} vencida{{ dashboard.vencidas.length > 1 ? 's' : '' }}</strong>
            <span class="tv__alerta-sub">— {{ dashboard.vencidas.slice(0,2).map(t => t.titulo).join(', ') }}<span v-if="dashboard.vencidas.length > 2"> y {{ dashboard.vencidas.length - 2 }} más</span></span>
          </div>
          <button class="tv__alerta-btn" @click="cambiarAKanban">Ver todas</button>
        </div>

        <!-- Tareas de hoy -->
        <div class="tv__section">
          <div class="tv__section-header">
            <span class="tv__section-title">Tareas de hoy</span>
            <span class="tv__section-count">{{ dashboard.hoy?.length || 0 }}</span>
          </div>

          <div v-if="!dashboard.hoy?.length" class="tv__empty">
            <div class="tv__empty-emoji">🎉</div>
            <div class="tv__empty-title">Sin tareas para hoy</div>
            <p class="tv__empty-desc">¡Todo al día! O creá una nueva tarea para organizar el trabajo.</p>
            <button v-if="puedeCrear" class="tv__btn-primary" @click="abrirModalNueva">
              <i class="bi bi-plus-lg"></i> Nueva tarea
            </button>
          </div>

          <div v-else class="tv__kanban-cols">
            <!-- Pendiente -->
            <div class="tv__col">
              <div class="tv__col-header tv__col-header--pending">
                <span>Pendiente</span>
                <span class="tv__col-count">{{ hoyPendientes.length }}</span>
              </div>
              <div class="tv__col-body">
                <TareaCard v-for="t in hoyPendientes" :key="t.id" :tarea="t"
                           @click="abrirDetalle(t)" @iniciar="iniciarTarea(t)"
                           @completar="abrirModalCompletar(t)" @editar="abrirModalEditar(t)"
                           @cancelar="confirmarCancelar(t)" />
                <div v-if="!hoyPendientes.length" class="tv__col-empty">Sin pendientes 👍</div>
              </div>
            </div>
            <!-- En progreso -->
            <div class="tv__col">
              <div class="tv__col-header tv__col-header--progress">
                <span>En progreso</span>
                <span class="tv__col-count">{{ hoyEnProgreso.length }}</span>
              </div>
              <div class="tv__col-body">
                <TareaCard v-for="t in hoyEnProgreso" :key="t.id" :tarea="t"
                           @click="abrirDetalle(t)" @completar="abrirModalCompletar(t)"
                           @editar="abrirModalEditar(t)" @cancelar="confirmarCancelar(t)" />
                <div v-if="!hoyEnProgreso.length" class="tv__col-empty">Sin tareas activas</div>
              </div>
            </div>
            <!-- Completadas -->
            <div class="tv__col">
              <div class="tv__col-header tv__col-header--done">
                <span>Completadas</span>
                <span class="tv__col-count">{{ hoyCompletadas.length }}</span>
              </div>
              <div class="tv__col-body">
                <TareaCard v-for="t in hoyCompletadas" :key="t.id" :tarea="t"
                           @click="abrirDetalle(t)" @editar="abrirModalEditar(t)" />
                <div v-if="!hoyCompletadas.length" class="tv__col-empty">Aún no hay completadas</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Próximas -->
        <div v-if="dashboard.proximas?.length" class="tv__section tv__section--mt">
          <div class="tv__section-header">
            <span class="tv__section-title">Próximos 7 días</span>
            <span class="tv__section-count">{{ dashboard.proximas.length }}</span>
          </div>
          <div class="tv__proximas">
            <TareaCard v-for="t in dashboard.proximas" :key="t.id" :tarea="t"
                       @click="abrirDetalle(t)" @iniciar="iniciarTarea(t)"
                       @completar="abrirModalCompletar(t)" @editar="abrirModalEditar(t)"
                       @cancelar="confirmarCancelar(t)" />
          </div>
        </div>

      </div>

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
                         @click="abrirDetalle(t)" @iniciar="iniciarTarea(t)"
                         @completar="abrirModalCompletar(t)" @editar="abrirModalEditar(t)"
                         @cancelar="confirmarCancelar(t)" />
              <div v-if="!kanban[col.key]?.length" class="tv__col-empty">Sin tareas</div>
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
                <span>{{ tareaDetalle.fecha_programada }}</span>
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
              <button v-if="tareaDetalle.estado === 'pendiente'" class="tv__panel-btn tv__panel-btn--ghost" @click="iniciarTarea(tareaDetalle)">
                <i class="bi bi-play-fill"></i> Iniciar
              </button>
              <button v-if="['pendiente','en_progreso'].includes(tareaDetalle.estado)" class="tv__panel-btn tv__panel-btn--primary" @click="abrirModalCompletar(tareaDetalle)">
                <i class="bi bi-check-circle"></i> Completar
              </button>
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
      :sedes="sedes"
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

    <!-- Toast -->
    <Transition name="tv-toast">
      <div v-if="toast.visible" class="tv__toast" :class="`tv__toast--${toast.tipo}`">
        <i :class="toast.icono"></i> {{ toast.mensaje }}
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useTareasStore } from '../stores/tareas'
import TareaCard from '../components/TareaCard.vue'
import ModalTarea from '../components/ModalTarea.vue'
import ModalCompletarTarea from '../components/ModalCompletarTarea.vue'
import { listSalas, listLotes, listUsers, listSedes } from '../lib/api'
import { storeToRefs } from 'pinia'

const authStore   = useAuthStore()
const tareasStore = useTareasStore()

const vistaActiva       = ref('dashboard')
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
const toast             = ref({ visible: false, mensaje: '', tipo: 'success', icono: 'bi bi-check-circle-fill' })

const { loading, dashboard, kanban, stats, hayVencidas, hoyPendientes, hoyEnProgreso, hoyCompletadas } = storeToRefs(tareasStore)

const esAdmin    = computed(() => authStore.user?.role === 'admin')
const puedeCrear = computed(() => authStore.user?.role === 'admin')

const fechaHoy = computed(() =>
  new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
)
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

onMounted(async () => {
  await cargarContexto()
  await tareasStore.fetchDashboard()
})

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
  } catch (e) { console.error('Error cargando contexto:', e) }
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

async function iniciarTarea(t) {
  try { await tareasStore.iniciar(t.id); if (tareaDetalle.value?.id === t.id) tareaDetalle.value = null; mostrarToast('Tarea iniciada') }
  catch (e) { mostrarToast(e.response?.data?.error || 'Error al iniciar', 'error') }
}
async function confirmarCancelar(t) {
  if (!confirm(`¿Cancelar la tarea "${t.titulo}"?`)) return
  try { await tareasStore.cancelar(t.id); tareaDetalle.value = null; mostrarToast('Tarea cancelada', 'warning') }
  catch (e) { mostrarToast(e.response?.data?.error || 'Error', 'error') }
}
function onTareaGuardada() { showModalTarea.value = false; tareaEditando.value = null; mostrarToast(tareaEditando.value ? 'Tarea actualizada' : 'Tarea creada ✓') }
function onTareaCompletada() { showModalCompletar.value = false; tareaCompletando.value = null; mostrarToast('Tarea completada ✓') }

function puedeEditarTarea(t) {
  const u = authStore.user
  return u?.role === 'admin' || u?.role === 'agricultor' || (u?.role === 'cultivador' && t.asignada_a?.id === u.id)
}

function mostrarToast(mensaje, tipo = 'success') {
  const iconos = { success: 'bi bi-check-circle-fill', error: 'bi bi-x-circle-fill', warning: 'bi bi-exclamation-triangle-fill' }
  toast.value = { visible: true, mensaje, tipo, icono: iconos[tipo] }
  setTimeout(() => { toast.value.visible = false }, 3000)
}
</script>

<style scoped>
.tv { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .tv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.tv__header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.tv__title { font-size: 1.75rem; font-weight: 800; margin: 0 0 .15rem; letter-spacing: -.04em; }
.tv__sub { font-size: .82rem; color: #64748b; margin: 0; text-transform: capitalize; }
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
.tv__col-empty { text-align: center; color: #94a3b8; font-size: .8rem; padding: 1.5rem 0; }

/* Próximas */
.tv__proximas { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: .75rem; padding: 1rem; }

/* Empty */
.tv__empty { text-align: center; padding: 3.5rem 1rem; color: #94a3b8; }
.tv__empty-emoji { font-size: 3rem; margin-bottom: .75rem; }
.tv__empty-title { font-size: 1.05rem; font-weight: 700; color: #0f172a; margin-bottom: .4rem; }
.tv__empty-desc { font-size: .875rem; margin-bottom: 1.25rem; }

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
.tv__panel-btn { display: flex; align-items: center; justify-content: center; gap: .5rem; padding: .65rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; }
.tv__panel-btn--primary { background: #1b5e20; color: #fff; }
.tv__panel-btn--primary:hover { background: #144a18; }
.tv__panel-btn--ghost { background: #f8fafc; color: #475569; border: 1.5px solid #e2e8f0; }
.tv__panel-btn--ghost:hover { background: #e2e8f0; }

/* Buttons */
.tv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 10px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.tv__btn-primary:hover { background: #144a18; }

/* Toast */
.tv__toast { position: fixed; bottom: 1.5rem; right: 1.5rem; z-index: 9999; display: flex; align-items: center; gap: .6rem; padding: .875rem 1.25rem; border-radius: 12px; font-size: .875rem; font-weight: 500; box-shadow: 0 8px 24px rgba(0,0,0,.15); }
.tv__toast--success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; }
.tv__toast--error   { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.tv__toast--warning { background: #fffbeb; border: 1px solid #fde68a; color: #b45309; }
.tv-toast-enter-active, .tv-toast-leave-active { transition: all .25s ease; }
.tv-toast-enter-from, .tv-toast-leave-to { opacity: 0; transform: translateY(10px); }
</style>
