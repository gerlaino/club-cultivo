<template>
  <div class="ptv">

    <!-- Loading inicial -->
    <div v-if="loading" class="ptv__loading">
      <div class="ptv__spinner-lg"></div>
    </div>

    <!-- Sin plan -->
    <EmptyStatePlan v-else-if="!plan" :planes-anteriores="planesAnteriores" @nuevo="showNuevo = true" @ver="cargarPlan" />

    <!-- Plan cargado -->
    <div v-else class="ptv__plan-body">

      <!-- Header del plan -->
      <div class="ptv__plan-hdr">
        <div class="ptv__plan-info">
          <div class="ptv__plan-title-row">
            <h1 class="ptv__plan-titulo">{{ plan.titulo || 'Plan de trabajo' }}</h1>
            <span class="ptv__badge" :class="`ptv__badge--${plan.estado}`">{{ ESTADO_LABEL[plan.estado] }}</span>
          </div>
          <p class="ptv__plan-meta">
            {{ PERIODO_LABEL[plan.periodo_tipo] }} · {{ plan.fecha_inicio }} → {{ plan.fecha_fin }}
            <span v-if="plan.total_plan_tareas"> · {{ plan.total_plan_tareas }} tareas</span>
          </p>
        </div>
        <div class="ptv__plan-actions">
          <button v-if="plan.estado === 'borrador'" class="ptv__btn-primary" :disabled="saving" @click="publicar">
            <i class="bi bi-send-check"></i> Publicar
          </button>
          <button v-if="plan.estado === 'publicado'" class="ptv__btn-ghost" :disabled="saving" @click="archivar">
            <i class="bi bi-archive"></i> Archivar
          </button>
          <button v-if="plan.estado === 'borrador' || plan.estado === 'archivado'" class="ptv__btn-danger" :disabled="saving" @click="eliminarPlan">
            <i class="bi bi-trash3"></i> Eliminar
          </button>
          <div class="ptv__actions-sep"></div>
          <button class="ptv__btn-new-plan" @click="showNuevo = true">
            <i class="bi bi-plus-lg"></i> Nuevo plan
          </button>
        </div>
      </div>

      <!-- Tabs de vista -->
      <div class="ptv__tabs">
        <button v-for="tab in TABS" :key="tab.value" class="ptv__tab" :class="{ 'ptv__tab--active': vistaActual === tab.value }" @click="vistaActual = tab.value">
          <i :class="`bi ${tab.icon}`"></i> {{ tab.label }}
        </button>
        <div class="ptv__tabs-spacer"></div>
        <button class="ptv__btn-tarea" @click="abrirNuevaTarea({})">
          <i class="bi bi-plus-lg"></i> Tarea
        </button>
      </div>

      <!-- Aviso plan archivado -->
      <div v-if="plan.estado === 'archivado'" class="ptv__info-archivado">
        <i class="bi bi-archive"></i>
        Este plan está archivado. Las tareas mostradas son históricas.
      </div>

      <!-- Error inline -->
      <div v-if="errorMsg" class="ptv__error">{{ errorMsg }}</div>

      <!-- Sub-views -->
      <div class="ptv__view">
        <SemanaPlanView
          v-if="vistaActual === 'semana'"
          :plan="plan"
          :plan-tareas="planTareas"
          :usuarios="usuarios"
          @add-tarea="abrirNuevaTarea"
          @edit-tarea="abrirEditarTarea"
        />
        <MesPlanView
          v-else-if="vistaActual === 'mes'"
          :plan="plan"
          :plan-tareas="planTareas"
          @add-tarea="abrirNuevaTarea"
          @edit-tarea="abrirEditarTarea"
        />
        <TrimestralPlanView
          v-else-if="vistaActual === 'trimestral'"
          :plan="plan"
          :plan-tareas="planTareas"
          @add-tarea="abrirNuevaTarea"
          @edit-tarea="abrirEditarTarea"
        />
      </div>
    </div>

    <!-- Modal nuevo plan -->
    <NuevoPlanModal
      v-if="showNuevo"
      :usuarios="usuarios"
      :salas="salas"
      @close="showNuevo = false"
      @created="onPlanCreado"
    />

    <!-- Modal nueva tarea (inline form) -->
    <Teleport to="body" v-if="showNuevaTarea">
      <div class="ptv__overlay" @click.self="showNuevaTarea = false">
        <div class="ptv__quick-panel">
          <div class="ptv__qp-hdr">
            <span class="ptv__qp-title">Nueva tarea</span>
            <button class="ptv__qp-close" @click="showNuevaTarea = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ptv__qp-body">
            <div v-if="quickError" class="ptv__qp-error">{{ quickError }}</div>
            <div class="ptv__qp-field">
              <label class="ptv__qp-label">Tipo</label>
              <select class="ptv__qp-input" v-model="quickForm.tipo">
                <option v-for="t in TIPOS" :key="t.value" :value="t.value">{{ t.label }}</option>
              </select>
            </div>
            <div class="ptv__qp-field">
              <label class="ptv__qp-label">Título <span class="ptv__qp-hint">(opcional)</span></label>
              <input class="ptv__qp-input" v-model="quickForm.titulo" placeholder="Deja vacío para usar el tipo" />
            </div>
            <div class="ptv__qp-field">
              <label class="ptv__qp-label">Responsable</label>
              <select class="ptv__qp-input" v-model="quickForm.responsable_id">
                <option :value="null">Sin asignar</option>
                <option v-for="u in usuarios" :key="u.id" :value="u.id">{{ u.nombre_completo || u.nombre }}</option>
              </select>
            </div>
            <div class="ptv__qp-row">
              <div class="ptv__qp-field">
                <label class="ptv__qp-label">¿Se repite?</label>
                <div class="ptv__toggle-row">
                  <button class="ptv__toggle" :class="{ 'ptv__toggle--on': !quickForm.es_recurrente }" @click="quickForm.es_recurrente = false">Única</button>
                  <button class="ptv__toggle" :class="{ 'ptv__toggle--on': quickForm.es_recurrente }"  @click="quickForm.es_recurrente = true">Recurrente</button>
                </div>
              </div>
              <div class="ptv__qp-field">
                <label class="ptv__qp-label">Hora <span class="ptv__qp-hint">(opc.)</span></label>
                <input class="ptv__qp-input ptv__qp-input--sm" type="time" v-model="quickForm.hora" />
              </div>
            </div>
            <div class="ptv__qp-field" v-if="quickForm.es_recurrente" key="dias-field">
              <label class="ptv__qp-label">Días</label>
              <div class="ptv__dias">
                <button v-for="d in DIAS" :key="d.value" class="ptv__dia" :class="{ 'ptv__dia--on': quickDiasArr.includes(d.value) }" @click="quickToggleDia(d.value)">{{ d.label }}</button>
              </div>
            </div>
            <div class="ptv__qp-field" v-else key="fecha-field">
              <label class="ptv__qp-label">Fecha</label>
              <input class="ptv__qp-input" type="date" v-model="quickForm.fecha_especifica" :min="plan?.fecha_inicio" :max="plan?.fecha_fin" />
            </div>
          </div>
          <div class="ptv__qp-footer">
            <button class="ptv__qp-cancel" @click="showNuevaTarea = false">Cancelar</button>
            <button class="ptv__qp-save" :disabled="quickSaving" @click="guardarNuevaTarea">
              <span v-if="quickSaving" class="ptv__qp-spinner"></span>
              {{ quickSaving ? 'Guardando…' : 'Agregar' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal editar tarea -->
    <EditarPlanTareaModal
      v-if="tareaEditando"
      :plan-tarea="tareaEditando"
      :plan-id="plan?.id"
      :plan-publicado="plan?.estado === 'publicado'"
      :usuarios="usuarios"
      :salas="salas"
      @close="tareaEditando = null"
      @updated="onTareaUpdated"
      @deleted="onTareaDeleted"
    />

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  getPlanTrabajoActivo, listPlanTrabajos, listPlanTareas, createPlanTarea,
  publicarPlanTrabajo, archivarPlanTrabajo, deletePlanTrabajo, listUsers, listSalas,
} from '../lib/api.js'
import EmptyStatePlan      from '../components/plan-trabajo/EmptyStatePlan.vue'
import SemanaPlanView      from '../components/plan-trabajo/SemanaPlanView.vue'
import MesPlanView         from '../components/plan-trabajo/MesPlanView.vue'
import TrimestralPlanView  from '../components/plan-trabajo/TrimestralPlanView.vue'
import NuevoPlanModal      from '../components/plan-trabajo/NuevoPlanModal.vue'
import EditarPlanTareaModal from '../components/plan-trabajo/EditarPlanTareaModal.vue'

const TABS = [
  { value: 'semana',    label: 'Semana',     icon: 'bi-calendar3-week' },
  { value: 'mes',       label: 'Mes',        icon: 'bi-calendar-month' },
  { value: 'trimestral', label: 'Trimestral', icon: 'bi-bar-chart-steps' },
]
const ESTADO_LABEL = { borrador: 'Borrador', publicado: 'Publicado', archivado: 'Archivado' }
const PERIODO_LABEL = { semanal: 'Semanal', mensual: 'Mensual', trimestral: 'Trimestral' }
const TIPOS = [
  { value: 'riego', label: '💧 Riego' }, { value: 'poda', label: '✂️ Poda' },
  { value: 'medicion', label: '📏 Medición' }, { value: 'limpieza', label: '🧹 Limpieza' },
  { value: 'cosecha', label: '🌿 Cosecha' }, { value: 'transplante', label: '🪴 Trasplante' },
  { value: 'inspeccion', label: '🔍 Inspección' }, { value: 'otro', label: '📋 Otro' },
]
const DIAS = [
  { value: 'lun', label: 'L' }, { value: 'mar', label: 'M' }, { value: 'mie', label: 'M' },
  { value: 'jue', label: 'J' }, { value: 'vie', label: 'V' }, { value: 'sab', label: 'S' }, { value: 'dom', label: 'D' },
]

const loading = ref(true)
const saving  = ref(false)
const errorMsg = ref(null)

const plan       = ref(null)
const planTareas = ref([])
const usuarios   = ref([])
const salas      = ref([])
const planesAnteriores = ref([])

const vistaActual = ref('semana')
const showNuevo   = ref(false)

// Nueva tarea rápida
const showNuevaTarea = ref(false)
const quickSaving    = ref(false)
const quickError     = ref(null)
const quickForm      = ref({})
const quickDiasArr   = computed(() => quickForm.value.dias_semana ? quickForm.value.dias_semana.split(',').map(s => s.trim()) : [])
function quickToggleDia(d) {
  const arr = [...quickDiasArr.value]
  const idx = arr.indexOf(d)
  if (idx >= 0) arr.splice(idx, 1); else arr.push(d)
  quickForm.value.dias_semana = arr.join(',')
}

// Editar tarea
const tareaEditando = ref(null)

onMounted(async () => {
  await Promise.all([cargarUsuarios(), cargarSalas()])
  await cargarPlanActivo()
  loading.value = false
})

async function cargarPlanActivo() {
  try {
    const { data } = await getPlanTrabajoActivo()
    if (data) {
      plan.value = data
      await cargarTareas()
    } else {
      plan.value = null
      await cargarPlanesAnteriores()
    }
  } catch {
    plan.value = null
    await cargarPlanesAnteriores()
  }
}

async function cargarPlan(p) {
  plan.value = p
  await cargarTareas()
}

async function cargarTareas() {
  if (!plan.value) return
  const { data } = await listPlanTareas(plan.value.id)
  planTareas.value = data || []
}

async function cargarUsuarios() {
  try { const { data } = await listUsers({ per_page: 100 }); usuarios.value = Array.isArray(data) ? data : (data?.data || data?.usuarios || []) } catch {}
}
async function cargarSalas() {
  try { const { data } = await listSalas(); salas.value = data || [] } catch {}
}
async function cargarPlanesAnteriores() {
  try { const { data } = await listPlanTrabajos({ per_page: 10 }); planesAnteriores.value = data?.planes || data || [] } catch {}
}

async function publicar() {
  if (!confirm('¿Publicar el plan? Se generarán las tareas para el equipo.')) return
  saving.value = true; errorMsg.value = null
  try {
    const { data } = await publicarPlanTrabajo(plan.value.id)
    plan.value = data
    planTareas.value = data.plan_tareas || planTareas.value
  } catch (e) {
    errorMsg.value = e?.response?.data?.error || 'Error al publicar'
  } finally { saving.value = false }
}

async function archivar() {
  if (!confirm('¿Archivar este plan?')) return
  saving.value = true
  try {
    const { data } = await archivarPlanTrabajo(plan.value.id)
    plan.value = data
  } catch { errorMsg.value = 'Error al archivar' }
  finally { saving.value = false }
}

async function eliminarPlan() {
  if (!confirm('¿Eliminar este borrador? Esta acción no se puede deshacer.')) return
  saving.value = true; errorMsg.value = null
  try {
    await deletePlanTrabajo(plan.value.id)
    plan.value = null
    planTareas.value = []
    await cargarPlanesAnteriores()
  } catch { errorMsg.value = 'Error al eliminar el plan' }
  finally { saving.value = false }
}

function abrirNuevaTarea(defaults = {}) {
  quickError.value = null
  quickForm.value = {
    tipo: 'riego', titulo: '', responsable_id: null, prioridad: 'normal',
    es_recurrente: true, dias_semana: 'lun,mie,vie', hora: '',
    fecha_especifica: defaults.fecha || plan.value?.fecha_inicio || '',
    ...defaults,
  }
  showNuevaTarea.value = true
}

async function guardarNuevaTarea() {
  quickSaving.value = true; quickError.value = null
  try {
    const { data } = await createPlanTarea(plan.value.id, quickForm.value)
    planTareas.value.push(data)
    showNuevaTarea.value = false
  } catch (e) {
    quickError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally { quickSaving.value = false }
}

function abrirEditarTarea(tarea) { tareaEditando.value = tarea }
function onTareaUpdated(updated) {
  const idx = planTareas.value.findIndex(t => t.id === updated.id)
  if (idx >= 0) planTareas.value.splice(idx, 1, updated)
  tareaEditando.value = null
}
function onTareaDeleted(id) {
  planTareas.value = planTareas.value.filter(t => t.id !== id)
  tareaEditando.value = null
}

async function onPlanCreado(nuevoPlan) {
  plan.value = nuevoPlan
  await cargarTareas()
}
</script>

<style scoped>
.ptv { display: flex; flex-direction: column; gap: 1.25rem; padding: 1.5rem 2rem; min-height: 100vh; background: #f6faf6; max-width: 1400px; margin: 0 auto; }

.ptv__loading { display: flex; justify-content: center; padding: 5rem; }
.ptv__plan-body { display: contents; }
.ptv__spinner-lg { width: 36px; height: 36px; border: 3px solid #e8f0e9; border-top-color: #1b5e20; border-radius: 50%; animation: ptv-spin .7s linear infinite; }

.ptv__plan-hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1.1rem 1.4rem; }
.ptv__plan-info { display: flex; flex-direction: column; gap: .3rem; }
.ptv__plan-title-row { display: flex; align-items: center; gap: .65rem; }
.ptv__plan-titulo { font-size: 1.2rem; font-weight: 800; color: #0f2611; margin: 0; }
.ptv__badge { font-size: .7rem; font-weight: 700; padding: .2em .6em; border-radius: 5px; }
.ptv__badge--borrador  { background: #f1f5f9; color: #64748b; }
.ptv__badge--publicado { background: #f0fdf4; color: #15803d; }
.ptv__badge--archivado { background: #fafafa; color: #94a3b8; }
.ptv__plan-meta { font-size: .78rem; color: #60725d; margin: 0; }
.ptv__plan-actions { display: flex; align-items: center; gap: .5rem; flex-shrink: 0; }

.ptv__tabs { display: flex; align-items: center; gap: .25rem; background: #fff; border: 1px solid #e8f0e9; border-radius: 10px; padding: .35rem .5rem; }
.ptv__tab { display: flex; align-items: center; gap: .35rem; padding: .4rem .875rem; border-radius: 7px; border: none; background: none; font-size: .82rem; font-weight: 600; color: #60725d; cursor: pointer; transition: all .12s; }
.ptv__tab--active { background: #1b5e20; color: #fff; }
.ptv__tab:not(.ptv__tab--active):hover { background: #f0fdf4; color: #1b5e20; }
.ptv__tabs-spacer { flex: 1; }
.ptv__btn-tarea { display: flex; align-items: center; gap: .35rem; background: #1b5e20; color: #fff; border: none; padding: .4rem .875rem; border-radius: 7px; font-size: .82rem; font-weight: 700; cursor: pointer; }

.ptv__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 8px; font-size: .82rem; }
.ptv__info-archivado { display: flex; align-items: center; gap: .5rem; background: #fafafa; border: 1px solid #e2e8f0; color: #64748b; padding: .6rem .875rem; border-radius: 8px; font-size: .8rem; }

.ptv__view { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1rem 1.25rem; overflow: hidden; }

/* Buttons shared */
.ptv__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 700; cursor: pointer; }
.ptv__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.ptv__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: transparent; color: #60725d; border: 1.5px solid #e2e8f0; padding: .5rem .875rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; }
.ptv__btn-ghost:hover { border-color: #1b5e20; color: #1b5e20; }
.ptv__btn-danger { display: inline-flex; align-items: center; gap: .4rem; background: transparent; color: #dc2626; border: 1.5px solid #fecaca; padding: .5rem .875rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; }
.ptv__btn-danger:hover:not(:disabled) { background: #fef2f2; border-color: #dc2626; }
.ptv__btn-danger:disabled { opacity: .55; cursor: not-allowed; }
.ptv__actions-sep { width: 1px; height: 24px; background: #e2e8f0; flex-shrink: 0; }
.ptv__btn-new-plan { display: inline-flex; align-items: center; gap: .4rem; background: #f0fdf4; color: #15803d; border: 1.5px solid #bbf7d0; padding: .5rem .875rem; border-radius: 8px; font-size: .8rem; font-weight: 700; cursor: pointer; }
.ptv__btn-new-plan:hover { background: #dcfce7; border-color: #86efac; }

/* Quick panel */
.ptv__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.ptv__quick-panel { background: #fff; border-radius: 14px; width: 100%; max-width: 420px; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.15); }
.ptv__qp-hdr { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.2rem; border-bottom: 1px solid #f1f5f9; }
.ptv__qp-title { font-size: .95rem; font-weight: 800; color: #0f2611; }
.ptv__qp-close { background: #f1f5f9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.ptv__qp-body  { padding: 1rem 1.2rem; display: flex; flex-direction: column; gap: .75rem; }
.ptv__qp-error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .5rem .75rem; border-radius: 7px; font-size: .8rem; }
.ptv__qp-field { display: flex; flex-direction: column; gap: .25rem; }
.ptv__qp-label { font-size: .7rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ptv__qp-hint  { font-weight: 400; text-transform: none; color: #94a3b8; }
.ptv__qp-input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .55rem .8rem; font-size: .875rem; color: #0f2611; width: 100%; box-sizing: border-box; }
.ptv__qp-input--sm { max-width: 110px; }
.ptv__qp-row { display: flex; gap: .75rem; }
.ptv__qp-row .ptv__qp-field { flex: 1; }
.ptv__toggle-row { display: flex; background: #f1f5f9; border-radius: 7px; padding: 2px; width: fit-content; }
.ptv__toggle { padding: .3rem .7rem; border-radius: 5px; border: none; background: none; font-size: .78rem; font-weight: 600; color: #64748b; cursor: pointer; }
.ptv__toggle--on { background: #fff; color: #1b5e20; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
.ptv__dias { display: flex; gap: .25rem; }
.ptv__dia  { width: 30px; height: 30px; border-radius: 50%; border: 1.5px solid #e2e8f0; background: #f8fafc; font-size: .75rem; font-weight: 700; color: #60725d; cursor: pointer; display: flex; align-items: center; justify-content: center; }
.ptv__dia--on { border-color: #1b5e20; background: #1b5e20; color: #fff; }
.ptv__qp-footer { display: flex; justify-content: flex-end; gap: .65rem; padding: .875rem 1.2rem; border-top: 1px solid #f1f5f9; }
.ptv__qp-cancel { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .55rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.ptv__qp-save { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.ptv__qp-save:disabled { opacity: .55; cursor: not-allowed; }
.ptv__qp-spinner { width: 13px; height: 13px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: ptv-spin .6s linear infinite; }

@keyframes ptv-spin { to { transform: rotate(360deg); } }

@media (max-width: 767px) {
  .ptv { padding: 1rem; }
  .ptv__plan-hdr { flex-direction: column; }
  .ptv__tabs { flex-wrap: wrap; }
}
</style>
