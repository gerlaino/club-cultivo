<template>
  <div class="tareas-view container-fluid py-4">
    <!-- Header -->
    <div class="d-flex align-items-center justify-content-between mb-4 flex-wrap gap-3">
      <div>
        <h2 class="fw-bold mb-1">
          <i class="bi bi-clipboard-check me-2 text-primary"></i>Tareas
        </h2>
        <p class="text-muted mb-0 small">
          {{ fechaHoy }} · {{ saludo }}
        </p>
      </div>
      <div class="d-flex gap-2 align-items-center">
        <!-- Selector de vista -->
        <div class="btn-group btn-group-sm">
          <button
            class="btn"
            :class="vistaActiva === 'dashboard' ? 'btn-primary' : 'btn-outline-secondary'"
            @click="vistaActiva = 'dashboard'"
          >
            <i class="bi bi-grid me-1"></i>Mi día
          </button>
          <button
            class="btn"
            :class="vistaActiva === 'kanban' ? 'btn-primary' : 'btn-outline-secondary'"
            @click="cambiarAKanban"
          >
            <i class="bi bi-kanban me-1"></i>Kanban
          </button>
        </div>
        <button
          v-if="puedeCrear"
          class="btn btn-primary btn-sm"
          @click="abrirModalNueva"
        >
          <i class="bi bi-plus-lg me-1"></i>Nueva tarea
        </button>
      </div>
    </div>

    <!-- ═══════════════════════ VISTA: DASHBOARD ═══════════════════════ -->
    <div v-if="vistaActiva === 'dashboard'">

      <!-- Stats rápidas -->
      <div class="row g-3 mb-4">
        <div class="col-6 col-md-3">
          <div class="stat-card stat-card--pending">
            <div class="stat-card__number">{{ stats.pendientes || 0 }}</div>
            <div class="stat-card__label">Pendientes</div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="stat-card stat-card--progress">
            <div class="stat-card__number">{{ stats.en_progreso || 0 }}</div>
            <div class="stat-card__label">En progreso</div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="stat-card stat-card--done">
            <div class="stat-card__number">{{ stats.completadas_hoy || 0 }}</div>
            <div class="stat-card__label">Completadas hoy</div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="stat-card" :class="stats.vencidas > 0 ? 'stat-card--overdue' : 'stat-card--neutral'">
            <div class="stat-card__number">{{ stats.vencidas || 0 }}</div>
            <div class="stat-card__label">Vencidas</div>
          </div>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="text-center py-5">
        <div class="spinner-border text-primary"></div>
        <p class="text-muted mt-2 small">Cargando tareas...</p>
      </div>

      <template v-else>
        <!-- Alerta de vencidas -->
        <div v-if="hayVencidas" class="alert alert-danger d-flex align-items-center gap-3 mb-4">
          <i class="bi bi-exclamation-triangle-fill fs-5"></i>
          <div>
            <strong>{{ dashboard.vencidas.length }} tarea{{ dashboard.vencidas.length > 1 ? 's' : '' }} vencida{{ dashboard.vencidas.length > 1 ? 's' : '' }}</strong>
            <div class="small">
              {{ dashboard.vencidas.map(t => t.titulo).slice(0,2).join(', ') }}
              <span v-if="dashboard.vencidas.length > 2"> y {{ dashboard.vencidas.length - 2 }} más</span>
            </div>
          </div>
          <button class="btn btn-outline-danger btn-sm ms-auto" @click="verVencidas">Ver todas</button>
        </div>

        <!-- Tareas de hoy -->
        <div class="mb-5">
          <h5 class="fw-bold mb-3 d-flex align-items-center gap-2">
            <span class="badge bg-primary rounded-pill">{{ dashboard.hoy.length }}</span>
            Tareas de hoy
          </h5>

          <!-- Estado vacío -->
          <div v-if="dashboard.hoy.length === 0" class="empty-state">
            <div class="empty-state__icon">🎉</div>
            <p class="fw-semibold">Sin tareas programadas para hoy</p>
            <p class="text-muted small">¡Buen trabajo! O creá una nueva tarea.</p>
          </div>

          <!-- Mini-kanban de hoy -->
          <div v-else class="row g-3">
            <!-- Pendientes -->
            <div class="col-md-4">
              <div class="kanban-col">
                <div class="kanban-col__header kanban-col__header--pending">
                  <span>Pendiente</span>
                  <span class="badge rounded-pill bg-secondary">{{ hoyPendientes.length }}</span>
                </div>
                <div class="kanban-col__body">
                  <TareaCard
                    v-for="t in hoyPendientes"
                    :key="t.id"
                    :tarea="t"
                    class="mb-2"
                    @click="abrirDetalle(t)"
                    @iniciar="iniciarTarea(t)"
                    @completar="abrirModalCompletar(t)"
                    @editar="abrirModalEditar(t)"
                    @cancelar="confirmarCancelar(t)"
                  />
                  <div v-if="hoyPendientes.length === 0" class="kanban-col__empty">
                    Sin pendientes 👍
                  </div>
                </div>
              </div>
            </div>
            <!-- En progreso -->
            <div class="col-md-4">
              <div class="kanban-col">
                <div class="kanban-col__header kanban-col__header--progress">
                  <span>En progreso</span>
                  <span class="badge rounded-pill bg-warning text-dark">{{ hoyEnProgreso.length }}</span>
                </div>
                <div class="kanban-col__body">
                  <TareaCard
                    v-for="t in hoyEnProgreso"
                    :key="t.id"
                    :tarea="t"
                    class="mb-2"
                    @click="abrirDetalle(t)"
                    @completar="abrirModalCompletar(t)"
                    @editar="abrirModalEditar(t)"
                    @cancelar="confirmarCancelar(t)"
                  />
                  <div v-if="hoyEnProgreso.length === 0" class="kanban-col__empty">
                    Sin tareas activas
                  </div>
                </div>
              </div>
            </div>
            <!-- Completadas hoy -->
            <div class="col-md-4">
              <div class="kanban-col">
                <div class="kanban-col__header kanban-col__header--done">
                  <span>Completadas</span>
                  <span class="badge rounded-pill bg-success">{{ hoyCompletadas.length }}</span>
                </div>
                <div class="kanban-col__body">
                  <TareaCard
                    v-for="t in hoyCompletadas"
                    :key="t.id"
                    :tarea="t"
                    class="mb-2"
                    @click="abrirDetalle(t)"
                    @editar="abrirModalEditar(t)"
                  />
                  <div v-if="hoyCompletadas.length === 0" class="kanban-col__empty">
                    Aún no hay completadas
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Próximas tareas (hasta 7 días) -->
        <div v-if="dashboard.proximas.length > 0" class="mb-4">
          <h5 class="fw-bold mb-3 d-flex align-items-center gap-2">
            <span class="badge bg-secondary rounded-pill">{{ dashboard.proximas.length }}</span>
            Próximos 7 días
          </h5>
          <div class="row g-2">
            <div
              v-for="t in dashboard.proximas"
              :key="t.id"
              class="col-md-6 col-lg-4"
            >
              <TareaCard
                :tarea="t"
                @click="abrirDetalle(t)"
                @iniciar="iniciarTarea(t)"
                @completar="abrirModalCompletar(t)"
                @editar="abrirModalEditar(t)"
                @cancelar="confirmarCancelar(t)"
              />
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- ═══════════════════════ VISTA: KANBAN COMPLETO ═══════════════════════ -->
    <div v-if="vistaActiva === 'kanban'">

      <!-- Filtros del kanban -->
      <div class="filtros-bar mb-4">
        <div class="row g-2 align-items-end">
          <div class="col-md-3" v-if="esAdmin">
            <label class="form-label small fw-semibold mb-1">Usuario</label>
            <select v-model="filtros.asignada_a_id" class="form-select form-select-sm" @change="cargarKanban">
              <option value="">Todos</option>
              <option v-for="u in usuarios" :key="u.id" :value="u.id">{{ u.nombre_completo || u.nombre }}</option>
            </select>
          </div>
          <div class="col-md-3">
            <label class="form-label small fw-semibold mb-1">Sala</label>
            <select v-model="filtros.sala_id" class="form-select form-select-sm" @change="onFiltroSala">
              <option value="">Todas</option>
              <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
          </div>
          <div class="col-md-3">
            <label class="form-label small fw-semibold mb-1">Lote</label>
            <select v-model="filtros.lote_id" class="form-select form-select-sm" @change="cargarKanban">
              <option value="">Todos</option>
              <option v-for="l in lotesFiltrados" :key="l.id" :value="l.id">{{ l.codigo }}</option>
            </select>
          </div>
          <div class="col-md-3">
            <button class="btn btn-outline-secondary btn-sm w-100" @click="limpiarFiltros">
              <i class="bi bi-x-circle me-1"></i>Limpiar filtros
            </button>
          </div>
        </div>
      </div>

      <div v-if="loading" class="text-center py-5">
        <div class="spinner-border text-primary"></div>
      </div>

      <!-- Columnas kanban -->
      <div v-else class="row g-3">
        <div class="col-md-4" v-for="col in columnas" :key="col.key">
          <div class="kanban-col">
            <div class="kanban-col__header" :class="`kanban-col__header--${col.clase}`">
              <span>{{ col.label }}</span>
              <span class="badge rounded-pill" :class="col.badgeClass">
                {{ kanban[col.key]?.length || 0 }}
              </span>
            </div>
            <div class="kanban-col__body">
              <TareaCard
                v-for="t in kanban[col.key]"
                :key="t.id"
                :tarea="t"
                class="mb-2"
                @click="abrirDetalle(t)"
                @iniciar="iniciarTarea(t)"
                @completar="abrirModalCompletar(t)"
                @editar="abrirModalEditar(t)"
                @cancelar="confirmarCancelar(t)"
              />
              <div v-if="!kanban[col.key]?.length" class="kanban-col__empty">
                Sin tareas
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ═══════════════════════ MODALS ═══════════════════════ -->

    <!-- Modal crear/editar -->
    <ModalTarea
      :show="showModalTarea"
      :tarea-inicial="tareaEditando"
      :salas="salas"
      :lotes="lotes"
      :usuarios="usuarios"
      @guardada="onTareaGuardada"
      @cerrar="showModalTarea = false"
    />

    <!-- Modal completar -->
    <ModalCompletarTarea
      :show="showModalCompletar"
      :tarea="tareaCompletando"
      @completada="onTareaCompletada"
      @cerrar="showModalCompletar = false"
    />

    <!-- Modal detalle (panel lateral) -->
    <div
      v-if="tareaDetalle"
      class="tarea-detalle-panel"
      :class="{ 'tarea-detalle-panel--visible': tareaDetalle }"
      @click.self="tareaDetalle = null"
    >
      <div class="tarea-detalle-panel__content">
        <div class="d-flex justify-content-between align-items-center mb-4">
          <h5 class="fw-bold mb-0">Detalle de tarea</h5>
          <button class="btn btn-sm btn-ghost" @click="tareaDetalle = null">
            <i class="bi bi-x-lg"></i>
          </button>
        </div>

        <div class="mb-3">
          <span class="badge tipo-badge-lg mb-2">{{ TIPO_LABELS[tareaDetalle.tipo] }}</span>
          <h4 class="fw-bold">{{ tareaDetalle.titulo }}</h4>
          <p v-if="tareaDetalle.descripcion" class="text-muted">{{ tareaDetalle.descripcion }}</p>
        </div>

        <div class="detalle-info">
          <div class="detalle-info__row">
            <span class="label">Estado</span>
            <span class="badge" :class="estadoBadge(tareaDetalle.estado)">{{ tareaDetalle.estado }}</span>
          </div>
          <div class="detalle-info__row">
            <span class="label">Prioridad</span>
            <span>{{ tareaDetalle.prioridad }}</span>
          </div>
          <div class="detalle-info__row" v-if="tareaDetalle.asignada_a">
            <span class="label">Asignada a</span>
            <span>{{ tareaDetalle.asignada_a.nombre }}</span>
          </div>
          <div class="detalle-info__row" v-if="tareaDetalle.sala">
            <span class="label">Sala</span>
            <span>{{ tareaDetalle.sala.nombre }}</span>
          </div>
          <div class="detalle-info__row" v-if="tareaDetalle.lote">
            <span class="label">Lote</span>
            <router-link :to="`/lotes/${tareaDetalle.lote.id}`">
              {{ tareaDetalle.lote.codigo }} <i class="bi bi-arrow-right-short"></i>
            </router-link>
          </div>
          <div class="detalle-info__row" v-if="tareaDetalle.fecha_programada">
            <span class="label">Fecha</span>
            <span>{{ tareaDetalle.fecha_programada }}</span>
          </div>
          <div class="detalle-info__row" v-if="tareaDetalle.horas_estimadas">
            <span class="label">Hs. estimadas</span>
            <span>{{ tareaDetalle.horas_estimadas }}h</span>
          </div>
          <div class="detalle-info__row" v-if="tareaDetalle.horas_reales">
            <span class="label">Hs. reales</span>
            <span class="fw-semibold">{{ tareaDetalle.horas_reales }}h</span>
          </div>
          <div class="detalle-info__row" v-if="tareaDetalle.notas_completado">
            <span class="label">Notas</span>
            <span>{{ tareaDetalle.notas_completado }}</span>
          </div>
        </div>

        <!-- Aviso de horas pendientes de aplicar al lote -->
        <div v-if="tareaDetalle.tiene_horas_para_lote" class="alert alert-warning mt-3 small">
          <i class="bi bi-clock-history me-2"></i>
          <strong>{{ tareaDetalle.horas_reales }}h</strong> disponibles para aplicar al lote.
          <router-link :to="`/lotes/${tareaDetalle.lote.id}`" class="alert-link ms-1">
            Ir al lote →
          </router-link>
        </div>

        <!-- Acciones del panel -->
        <div class="mt-4 d-flex flex-column gap-2">
          <button
            v-if="tareaDetalle.estado === 'pendiente'"
            class="btn btn-outline-primary btn-sm"
            @click="iniciarTarea(tareaDetalle)"
          >
            <i class="bi bi-play-fill me-2"></i>Iniciar
          </button>
          <button
            v-if="tareaDetalle.estado === 'pendiente' || tareaDetalle.estado === 'en_progreso'"
            class="btn btn-success btn-sm"
            @click="abrirModalCompletar(tareaDetalle)"
          >
            <i class="bi bi-check-circle me-2"></i>Completar
          </button>
          <button
            v-if="puedeEditarTarea(tareaDetalle)"
            class="btn btn-outline-secondary btn-sm"
            @click="abrirModalEditar(tareaDetalle)"
          >
            <i class="bi bi-pencil me-2"></i>Editar
          </button>
        </div>
      </div>
    </div>

    <!-- Toast de éxito -->
    <div v-if="toast.visible" class="toast-custom" :class="`toast-custom--${toast.tipo}`">
      <i class="bi" :class="toast.icono"></i>
      {{ toast.mensaje }}
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useTareasStore } from '../stores/tareas'
import TareaCard from '../components/TareaCard.vue'
import ModalTarea from '../components/ModalTarea.vue'
import ModalCompletarTarea from '../components/ModalCompletarTarea.vue'
import { listSalas, listLotes, listUsers } from '../lib/api'
import { storeToRefs } from 'pinia'

// ── Stores ────────────────────────────────────────────────────────
const authStore   = useAuthStore()
const tareasStore = useTareasStore()

// ── State de la vista ─────────────────────────────────────────────
const vistaActiva      = ref('dashboard')
const showModalTarea   = ref(false)
const showModalCompletar = ref(false)
const tareaEditando    = ref(null)
const tareaCompletando = ref(null)
const tareaDetalle     = ref(null)
const salas            = ref([])
const lotes            = ref([])
const usuarios         = ref([])
const filtros          = ref({ asignada_a_id: '', sala_id: '', lote_id: '' })
const toast            = ref({ visible: false, mensaje: '', tipo: 'success', icono: 'bi-check-circle' })

// ── Computed ──────────────────────────────────────────────────────
// storeToRefs preserva la reactividad al desestructurar
const {
  loading, dashboard, kanban, stats,
  hayVencidas, hoyPendientes, hoyEnProgreso, hoyCompletadas
} = storeToRefs(tareasStore)

const esAdmin    = computed(() => authStore.user?.role === 'admin')
const puedeCrear = computed(() => authStore.user?.role === 'admin')

const fechaHoy = computed(() => {
  return new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
})

const saludo = computed(() => {
  const hora = new Date().getHours()
  const nombre = authStore.user?.first_name || authStore.user?.nombre || ''
  if (hora < 12) return `Buenos días, ${nombre}`
  if (hora < 19) return `Buenas tardes, ${nombre}`
  return `Buenas noches, ${nombre}`
})

const lotesFiltrados = computed(() => {
  if (!filtros.value.sala_id) return lotes.value
  return lotes.value.filter(l => l.sala_id == filtros.value.sala_id)
})

const columnas = [
  { key: 'pendiente',   label: 'Pendiente',   clase: 'pending',  badgeClass: 'bg-secondary' },
  { key: 'en_progreso', label: 'En progreso',  clase: 'progress', badgeClass: 'bg-warning text-dark' },
  { key: 'completada',  label: 'Completadas',  clase: 'done',     badgeClass: 'bg-success' }
]

const TIPO_LABELS = {
  riego: '💧 Riego', poda: '✂️ Poda', medicion: '📏 Medición',
  limpieza: '🧹 Limpieza', cosecha: '🌿 Cosecha', transplante: '🪴 Transplante',
  inspeccion: '🔍 Inspección', otro: '📋 Otro'
}

// ── Lifecycle ─────────────────────────────────────────────────────
onMounted(async () => {
  await cargarContexto()
  await tareasStore.fetchDashboard()
})

// ── Carga de datos ────────────────────────────────────────────────
async function cargarContexto() {
  try {
    // Médicos y auditores no necesitan el contexto de salas/lotes
    if (!puedeCrear.value) return

    const [resSalas, resLotes] = await Promise.all([
      listSalas(),
      listLotes()
    ])
    salas.value = resSalas.data || []
    lotes.value = resLotes.data || []

    if (esAdmin.value) {
      const resUsuarios = await listUsers()
      usuarios.value = (resUsuarios.data?.data || resUsuarios.data || []).map(u => ({
        ...u,
        nombre_completo: `${u.first_name} ${u.last_name}`.trim()
      }))
    }
  } catch (e) {
    console.error('Error cargando contexto:', e)
  }
}

async function cambiarAKanban() {
  vistaActiva.value = 'kanban'
  await cargarKanban()
}

async function cargarKanban() {
  const params = {}
  if (filtros.value.asignada_a_id) params.asignada_a_id = filtros.value.asignada_a_id
  if (filtros.value.sala_id)       params.sala_id       = filtros.value.sala_id
  if (filtros.value.lote_id)       params.lote_id       = filtros.value.lote_id
  await tareasStore.fetchKanban(params)
}

function onFiltroSala() {
  filtros.value.lote_id = ''
  cargarKanban()
}

function limpiarFiltros() {
  filtros.value = { asignada_a_id: '', sala_id: '', lote_id: '' }
  cargarKanban()
}

// ── Acciones ──────────────────────────────────────────────────────
function abrirModalNueva() {
  tareaEditando.value  = null
  showModalTarea.value = true
}

function abrirModalEditar(tarea) {
  tareaEditando.value  = tarea
  tareaDetalle.value   = null
  showModalTarea.value = true
}

function abrirModalCompletar(tarea) {
  tareaCompletando.value  = tarea
  tareaDetalle.value      = null
  showModalCompletar.value = true
}

function abrirDetalle(tarea) {
  tareaDetalle.value = tarea
}

async function iniciarTarea(tarea) {
  try {
    await tareasStore.iniciar(tarea.id)
    if (tareaDetalle.value?.id === tarea.id) tareaDetalle.value = null
    mostrarToast('Tarea iniciada')
  } catch (e) {
    mostrarToast(e.response?.data?.error || 'Error al iniciar', 'error')
  }
}

async function confirmarCancelar(tarea) {
  if (!confirm(`¿Cancelar la tarea "${tarea.titulo}"?`)) return
  try {
    await tareasStore.cancelar(tarea.id)
    tareaDetalle.value = null
    mostrarToast('Tarea cancelada', 'warning')
  } catch (e) {
    mostrarToast(e.response?.data?.error || 'Error al cancelar', 'error')
  }
}

function onTareaGuardada(tarea) {
  showModalTarea.value = false
  mostrarToast(tareaEditando.value ? 'Tarea actualizada' : 'Tarea creada ✓')
  tareaEditando.value  = null
}

function onTareaCompletada({ tarea, tiene_horas_para_lote }) {
  showModalCompletar.value = false
  tareaCompletando.value   = null
  mostrarToast('Tarea completada ✓')
}

function verVencidas() {
  vistaActiva.value = 'kanban'
  cargarKanban()
}

// ── Helpers ───────────────────────────────────────────────────────
function puedeEditarTarea(t) {
  const user = authStore.user
  if (!user) return false
  return user.role === 'admin' || user.role === 'agricultor' ||
    (user.role === 'cultivador' && t.asignada_a?.id === user.id)
}

function estadoBadge(estado) {
  return {
    pendiente:   'bg-secondary',
    en_progreso: 'bg-warning text-dark',
    completada:  'bg-success',
    cancelada:   'bg-danger'
  }[estado] || 'bg-secondary'
}

function mostrarToast(mensaje, tipo = 'success') {
  const iconos = { success: 'bi-check-circle-fill', error: 'bi-x-circle-fill', warning: 'bi-exclamation-triangle-fill' }
  toast.value = { visible: true, mensaje, tipo, icono: iconos[tipo] }
  setTimeout(() => { toast.value.visible = false }, 3000)
}
</script>

<style scoped>
/* ── Stat cards ─────────────────────────────────────────────────── */
.stat-card {
  background: var(--bs-body-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: 12px;
  padding: 16px 20px;
  text-align: center;
}
.stat-card__number {
  font-size: 2rem;
  font-weight: 800;
  line-height: 1;
}
.stat-card__label {
  font-size: 0.75rem;
  color: var(--bs-secondary);
  margin-top: 4px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.stat-card--pending  .stat-card__number { color: #6c757d; }
.stat-card--progress .stat-card__number { color: #fd7e14; }
.stat-card--done     .stat-card__number { color: #198754; }
.stat-card--overdue  .stat-card__number { color: #dc3545; }
.stat-card--neutral  .stat-card__number { color: #6c757d; }

/* ── Kanban ──────────────────────────────────────────────────────── */
.kanban-col {
  background: var(--bs-tertiary-bg, #f8f9fa);
  border-radius: 12px;
  overflow: hidden;
}
.kanban-col__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  font-size: 0.8rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.kanban-col__header--pending  { background: rgba(108,117,125,0.1); color: #495057; }
.kanban-col__header--progress { background: rgba(253,126,20,0.12); color: #b45309; }
.kanban-col__header--done     { background: rgba(25,135,84,0.1);   color: #146c43; }

.kanban-col__body {
  padding: 10px;
  min-height: 120px;
  max-height: 70vh;
  overflow-y: auto;
}
.kanban-col__empty {
  text-align: center;
  color: var(--bs-secondary);
  font-size: 0.8rem;
  padding: 20px 0;
}

/* ── Filtros bar ──────────────────────────────────────────────────── */
.filtros-bar {
  background: var(--bs-body-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: 10px;
  padding: 14px 16px;
}

/* ── Panel de detalle (slide-in) ──────────────────────────────────── */
.tarea-detalle-panel {
  position: fixed;
  inset: 0;
  z-index: 1040;
  background: rgba(0,0,0,0.35);
  display: flex;
  justify-content: flex-end;
}
.tarea-detalle-panel__content {
  width: min(420px, 100vw);
  height: 100%;
  background: var(--bs-body-bg);
  padding: 28px 24px;
  overflow-y: auto;
  animation: slideInRight 0.2s ease;
}
@keyframes slideInRight {
  from { transform: translateX(100%); }
  to   { transform: translateX(0); }
}

.detalle-info {
  border: 1px solid var(--bs-border-color);
  border-radius: 8px;
  overflow: hidden;
}
.detalle-info__row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  border-bottom: 1px solid var(--bs-border-color);
  font-size: 0.875rem;
}
.detalle-info__row:last-child { border-bottom: none; }
.detalle-info__row .label {
  color: var(--bs-secondary);
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

/* ── Toast ──────────────────────────────────────────────────────── */
.toast-custom {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 9999;
  padding: 12px 20px;
  border-radius: 10px;
  font-size: 0.875rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
  animation: fadeInUp 0.2s ease;
  box-shadow: 0 4px 16px rgba(0,0,0,0.15);
}
.toast-custom--success { background: #198754; color: white; }
.toast-custom--error   { background: #dc3545; color: white; }
.toast-custom--warning { background: #fd7e14; color: white; }
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0); }
}

.tipo-badge-lg {
  background: rgba(var(--bs-primary-rgb), 0.12);
  color: var(--bs-primary);
  font-size: 0.8rem;
  padding: 4px 12px;
  border-radius: 20px;
}

.btn-ghost {
  background: transparent;
  border: none;
  color: var(--bs-secondary);
}

.empty-state {
  text-align: center;
  padding: 40px 20px;
  color: var(--bs-secondary);
}
.empty-state__icon {
  font-size: 3rem;
  margin-bottom: 12px;
}
</style>
