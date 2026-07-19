<script setup>
import { ref, onMounted } from 'vue'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import AplicarPlanModal       from '../components/plan-trabajo/AplicarPlanModal.vue'
import EditarPlantillaModal   from '../components/plan-trabajo/EditarPlantillaModal.vue'
import ExportarCalendarioModal from '../components/plan-trabajo/ExportarCalendarioModal.vue'
import { listPlanTrabajos, deletePlanTrabajo, getPlanTrabajo, exportPlanCSV, listAplicaciones, cancelarAplicacion, publicarPlanTrabajo } from '../lib/api.js'

const toast   = useToast()
const confirm = useConfirm()

const loading    = ref(true)
const plantillas = ref([])

const aplicaciones        = ref([])
const loadingAplicaciones = ref(false)
const verHistorialApl     = ref(false)
const quitandoId          = ref(null)

const showEditar    = ref(false)
const showAplicar   = ref(false)
const showCalendario = ref(false)
const planActivo    = ref(null)

// dropdown de exportar abierto para qué plan
const exportDropdownPlan = ref(null)

const TIPO_LABEL = {
  riego: 'Riego', poda: 'Poda', medicion: 'Medición', limpieza: 'Limpieza',
  cosecha: 'Cosecha', trasplante: 'Trasplante', inspeccion: 'Inspección',
  nutricion: 'Nutrición', defoliacion: 'Defoliación', scrog_lst: 'SCROG/LST',
  ajuste_luz: 'Ajuste de luz', revision_plagas: 'Revisión de plagas', otro: 'Otro',
}

async function cargar() {
  loading.value = true
  try {
    const { data } = await listPlanTrabajos({ plantilla: 'true' })
    plantillas.value = data
  } catch { toast.error('Error al cargar plantillas') }
  finally { loading.value = false }
}

async function abrirEditar(plan = null) {
  if (plan) {
    const { data } = await getPlanTrabajo(plan.id)
    planActivo.value = data
  } else {
    planActivo.value = null
  }
  showEditar.value = true
}

async function abrirAplicar(plan) {
  const { data } = await getPlanTrabajo(plan.id)
  planActivo.value = data
  showAplicar.value = true
}

async function abrirCalendario(plan) {
  const { data } = await getPlanTrabajo(plan.id)
  planActivo.value = data
  showCalendario.value = true
  exportDropdownPlan.value = null
}

async function descargarPlantillaCSV(plan) {
  exportDropdownPlan.value = null
  try {
    const { data } = await exportPlanCSV(plan.id, { modo: 'plantilla' })
    triggerDownload(data, `${slugify(plan.titulo)}-plantilla.csv`)
    toast.success('Plantilla descargada')
  } catch { toast.error('Error al exportar') }
}

function triggerDownload(blob, filename) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename
  document.body.appendChild(a); a.click()
  document.body.removeChild(a); URL.revokeObjectURL(url)
}
function slugify(s) { return s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') }

async function eliminar(plan) {
  const ok = await confirm.confirm({
    title:       'Eliminar plan de trabajo',
    message:     `¿Eliminás "${plan.titulo}"?\n\nTodas las tareas futuras (pendientes o en progreso) generadas por este plan serán eliminadas. Las tareas ya completadas se conservan. Esta acción no se puede deshacer.`,
    confirmText: 'Sí, eliminar',
    variant:     'danger',
  })
  if (!ok) return
  try {
    const { data } = await deletePlanTrabajo(plan.id)
    plantillas.value = plantillas.value.filter(p => p.id !== plan.id)
    const n = data?.tareas_eliminadas ?? 0
    toast.success(n > 0
      ? `Plan eliminado. Se eliminaron ${n} tarea${n === 1 ? '' : 's'} pendiente${n === 1 ? '' : 's'}.`
      : 'Plan eliminado.')
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al eliminar')
  }
}

async function publicar(plan) {
  try {
    await publicarPlanTrabajo(plan.id)
    const idx = plantillas.value.findIndex(p => p.id === plan.id)
    if (idx !== -1) plantillas.value[idx] = { ...plantillas.value[idx], estado: 'publicado' }
    toast.success('Plan publicado — ya podés aplicarlo a un lote.')
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al publicar')
  }
}

async function cargarAplicaciones() {
  loadingAplicaciones.value = true
  try {
    const params = verHistorialApl.value ? {} : { estado: 'activo' }
    const { data } = await listAplicaciones(params)
    aplicaciones.value = data
  } catch { toast.error('Error al cargar planes aplicados') }
  finally { loadingAplicaciones.value = false }
}

function toggleHistorialApl() {
  verHistorialApl.value = !verHistorialApl.value
  cargarAplicaciones()
}

const OBJETIVO_LABEL = { Lote: 'Lote', Sala: 'Sala' }

function describirObjetivo(a) {
  if (!a.objetivo_tipo) return 'Todo el club'
  const tipo = OBJETIVO_LABEL[a.objetivo_tipo] || a.objetivo_tipo
  return a.objetivo_nombre ? `${tipo} · ${a.objetivo_nombre}` : tipo
}

async function quitarPlan(a) {
  const ok = await confirm.confirm({
    title:       'Quitar plan aplicado',
    message:     `¿Quitás "${a.plan_trabajo?.titulo}" de ${describirObjetivo(a)}?\n\nLas tareas pendientes y en progreso generadas por esta aplicación se cancelan. Las completadas se conservan.`,
    confirmText: 'Sí, quitar plan',
    variant:     'danger',
  })
  if (!ok) return
  quitandoId.value = a.id
  try {
    await cancelarAplicacion(a.id)
    toast.success('Plan quitado — las tareas pendientes fueron canceladas')
    await cargarAplicaciones()
  } catch (e) {
    toast.error(e.response?.data?.error || 'Error al quitar el plan')
  } finally {
    quitandoId.value = null
  }
}

function onSaved() { showEditar.value = false; cargar() }
function onAplicado() {
  showAplicar.value = false
  toast.success('Plan aplicado — las tareas fueron creadas en el calendario')
  cargarAplicaciones()
}
function toggleExportDropdown(plan) {
  exportDropdownPlan.value = exportDropdownPlan.value?.id === plan.id ? null : plan
}

// Cerrar dropdown al hacer click fuera
function onDocClick(e) {
  if (!e.target.closest('.ptv__export-wrap')) exportDropdownPlan.value = null
}
onMounted(() => {
  cargar()
  cargarAplicaciones()
  document.addEventListener('click', onDocClick)
})
</script>

<template>
  <div class="ptv">

    <!-- Header -->
    <div class="ptv__hdr">
      <div>
        <h1 class="ptv__title">Planes de trabajo</h1>
        <p class="ptv__subtitle">Plantillas reutilizables para organizar cultivos</p>
      </div>
      <div class="ptv__hdr-actions">
        <button class="ptv__btn-primary" @click="abrirEditar()">
          <i class="bi bi-plus-lg"></i> Nueva plantilla
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="ptv__loading"><DsSpinner /></div>

    <!-- Empty -->
    <div v-else-if="!plantillas.length" class="ptv__empty">
      <div class="ptv__empty-icon"><i class="bi bi-clipboard2-check"></i></div>
      <div class="ptv__empty-title">Sin plantillas todavía</div>
      <div class="ptv__empty-sub">Creá tu primera plantilla para organizar cultivos.</div>
      <div class="ptv__empty-actions">
        <button class="ptv__btn-primary" @click="abrirEditar()">
          <i class="bi bi-plus-lg"></i> Crear plantilla
        </button>
      </div>
    </div>

    <!-- Lista -->
    <div v-else class="ptv__grid">
      <div v-for="plan in plantillas" :key="plan.id" class="ptv__card">
        <div class="ptv__card-hdr">
          <div class="ptv__card-info">
            <h3 class="ptv__card-titulo">{{ plan.titulo }}</h3>
            <p v-if="plan.notas" class="ptv__card-notas">{{ plan.notas }}</p>
          </div>
          <div class="ptv__card-badge">
            <i class="bi bi-list-task"></i>
            {{ plan.total_plan_tareas }} tarea{{ plan.total_plan_tareas !== 1 ? 's' : '' }}
          </div>
        </div>

        <!-- Preview chips -->
        <div v-if="plan.plan_tareas?.length" class="ptv__tareas-preview">
          <div v-for="pt in plan.plan_tareas.slice(0, 5)" :key="pt.id" class="ptv__tarea-chip">
            <span class="ptv__tarea-dia">D{{ pt.dia_relativo ?? 0 }}</span>
            <span class="ptv__tarea-nombre">{{ pt.titulo || TIPO_LABEL[pt.tipo] || pt.tipo }}</span>
          </div>
          <div v-if="plan.plan_tareas.length > 5" class="ptv__tarea-chip ptv__tarea-chip--more">
            +{{ plan.plan_tareas.length - 5 }} más
          </div>
        </div>

        <div class="ptv__card-footer">
          <span class="ptv__card-meta">{{ plan.creado_por?.nombre }}</span>
          <div class="ptv__card-actions">

            <!-- Aplicar -->
            <button class="ptv__btn-apply" @click="abrirAplicar(plan)">
              <i class="bi bi-play-fill"></i> Aplicar
            </button>

            <!-- Exportar dropdown -->
            <div class="ptv__export-wrap">
              <button class="ptv__btn-ghost" @click.stop="toggleExportDropdown(plan)" title="Exportar">
                <i class="bi bi-download"></i>
              </button>
              <div v-if="exportDropdownPlan?.id === plan.id" class="ptv__export-drop">
                <button class="ptv__drop-item" @click="descargarPlantillaCSV(plan)">
                  <i class="bi bi-filetype-csv"></i>
                  Descargar plantilla (.csv)
                </button>
                <button class="ptv__drop-item" @click="abrirCalendario(plan)">
                  <i class="bi bi-calendar3-week"></i>
                  Exportar como calendario…
                </button>
              </div>
            </div>

            <!-- Publicar (solo borradores: un plan en borrador no se puede aplicar) -->
            <button
              v-if="plan.estado === 'borrador'"
              class="ptv__btn-publicar"
              @click="publicar(plan)"
              title="Publicar — necesario para poder aplicarlo a un lote"
            >
              <i class="bi bi-send-check"></i> Publicar
            </button>

            <!-- Editar -->
            <button class="ptv__btn-ghost" @click="abrirEditar(plan)" title="Editar">
              <i class="bi bi-pencil"></i>
            </button>

            <!-- Eliminar -->
            <button class="ptv__btn-danger-sm" @click="eliminar(plan)" title="Eliminar">
              <i class="bi bi-trash3"></i>
            </button>

          </div>
        </div>
      </div>
    </div>

    <!-- ── Planes aplicados ─────────────────────────────────── -->
    <div class="ptv__apl">
      <div class="ptv__apl-hdr">
        <div>
          <h2 class="ptv__apl-title">Planes aplicados</h2>
          <p class="ptv__subtitle">Aplicaciones de plantillas sobre lotes, salas o el club</p>
        </div>
        <button class="ptv__btn-secondary" @click="toggleHistorialApl">
          {{ verHistorialApl ? 'Ver solo activos' : 'Ver historial' }}
        </button>
      </div>

      <div v-if="loadingAplicaciones" class="ptv__loading"><DsSpinner /></div>

      <div v-else-if="!aplicaciones.length" class="ptv__apl-empty">
        {{ verHistorialApl ? 'Todavía no se aplicó ninguna plantilla.' : 'No hay planes activos. Aplicá una plantilla con el botón "Aplicar".' }}
      </div>

      <div v-else class="ptv__apl-list">
        <div v-for="a in aplicaciones" :key="a.id" class="ptv__apl-row">
          <div class="ptv__apl-info">
            <div class="ptv__apl-plan">
              {{ a.plan_trabajo?.titulo }}
              <span class="ptv__apl-estado" :class="`ptv__apl-estado--${a.estado}`">{{ a.estado }}</span>
            </div>
            <div class="ptv__apl-meta">
              <span><i class="bi bi-geo-alt"></i> {{ describirObjetivo(a) }}</span>
              <span><i class="bi bi-calendar3"></i> {{ new Date(a.fecha_inicio).toLocaleDateString('es-AR') }}</span>
              <span><i class="bi bi-list-task"></i> {{ a.tareas_creadas }} tareas</span>
              <span v-if="a.aplicado_por"><i class="bi bi-person"></i> {{ a.aplicado_por.nombre }}</span>
            </div>
          </div>
          <div class="ptv__apl-right">
            <div class="ptv__apl-progreso" :title="`${a.porcentaje_completado}% completado`">
              <div class="ptv__apl-progreso-bar">
                <div class="ptv__apl-progreso-fill" :style="{ width: a.porcentaje_completado + '%' }"></div>
              </div>
              <span class="ptv__apl-progreso-pct">{{ a.porcentaje_completado }}%</span>
            </div>
            <button
              v-if="a.estado === 'activo'"
              class="ptv__btn-danger-sm ptv__apl-quitar"
              :disabled="quitandoId === a.id"
              @click="quitarPlan(a)"
              title="Quitar plan (cancela tareas pendientes)"
            >
              <i class="bi bi-x-lg"></i> Quitar
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modales -->
    <EditarPlantillaModal
      v-if="showEditar"
      :plan="planActivo"
      @close="showEditar = false"
      @saved="onSaved"
    />

    <AplicarPlanModal
      v-if="showAplicar && planActivo"
      :plan="planActivo"
      @close="showAplicar = false"
      @applied="onAplicado"
    />

    <ExportarCalendarioModal
      v-if="showCalendario && planActivo"
      :plan="planActivo"
      @close="showCalendario = false"
    />


  </div>
</template>

<style scoped>
.ptv { padding: 2rem 1.75rem 3rem; max-width: 1100px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .ptv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.ptv__hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.ptv__title { font-size: 1.6rem; font-weight: 800; margin: 0 0 .25rem; letter-spacing: -.04em; }
.ptv__subtitle { font-size: .875rem; color: #64748b; margin: 0; }
.ptv__hdr-actions { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }

/* Buttons */
.ptv__btn-primary   { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 700; cursor: pointer; transition: background .15s; }
.ptv__btn-primary:hover { background: #144a18; }
.ptv__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #f8fafc; color: #475569; border: 1.5px solid #e2e8f0; padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 700; cursor: pointer; transition: all .15s; }
.ptv__btn-secondary:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.ptv__btn-apply     { display: inline-flex; align-items: center; gap: .35rem; background: #1b5e20; color: #fff; border: none; padding: .45rem .9rem; border-radius: 7px; font-size: .78rem; font-weight: 700; cursor: pointer; transition: background .15s; }
.ptv__btn-apply:hover { background: #144a18; }
.ptv__btn-ghost     { display: inline-flex; align-items: center; justify-content: center; width: 32px; height: 32px; background: #f8fafc; color: #475569; border: 1.5px solid #e2e8f0; border-radius: 7px; font-size: .85rem; cursor: pointer; transition: all .15s; }
.ptv__btn-ghost:hover { border-color: #94a3b8; color: #1b5e20; }
.ptv__btn-danger-sm { display: inline-flex; align-items: center; justify-content: center; width: 32px; height: 32px; background: #fef2f2; color: #dc2626; border: 1.5px solid #fecaca; border-radius: 7px; font-size: .85rem; cursor: pointer; transition: all .15s; }
.ptv__btn-danger-sm:hover { background: #fee2e2; }
.ptv__btn-publicar { display: inline-flex; align-items: center; gap: .35rem; height: 32px; padding: 0 .7rem; background: #dcfce7; color: #15803d; border: 1.5px solid #bbf7d0; border-radius: 7px; font-size: .78rem; font-weight: 700; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ptv__btn-publicar:hover { background: #bbf7d0; }

/* Loading */
.ptv__loading { display: flex; justify-content: center; padding: 4rem; }

/* Empty state */
.ptv__empty { text-align: center; padding: 5rem 2rem; display: flex; flex-direction: column; align-items: center; gap: 1rem; }
.ptv__empty-icon  { width: 64px; height: 64px; border-radius: 18px; background: #f0fdf4; color: #1b5e20; display: flex; align-items: center; justify-content: center; font-size: 1.75rem; }
.ptv__empty-title { font-size: 1.1rem; font-weight: 700; color: #0f172a; }
.ptv__empty-sub   { font-size: .875rem; color: #64748b; max-width: 420px; }
.ptv__empty-actions { display: flex; gap: .5rem; flex-wrap: wrap; justify-content: center; }

/* Grid de cards */
.ptv__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 1.25rem; }
@media (max-width: 600px) { .ptv__grid { grid-template-columns: 1fr; } }

/* Card */
.ptv__card { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 14px; overflow: visible; display: flex; flex-direction: column; transition: box-shadow .15s; }
.ptv__card:hover { box-shadow: 0 4px 16px rgba(0,0,0,.08); }
.ptv__card-hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.1rem .75rem; }
.ptv__card-info { flex: 1; min-width: 0; }
.ptv__card-titulo { font-size: .975rem; font-weight: 800; color: #0f172a; margin: 0 0 .25rem; }
.ptv__card-notas { font-size: .78rem; color: #64748b; margin: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ptv__card-badge { display: inline-flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 700; color: #1b5e20; background: #f0fdf4; padding: .25em .65em; border-radius: 999px; white-space: nowrap; flex-shrink: 0; }

/* Preview tareas */
.ptv__tareas-preview { display: flex; flex-wrap: wrap; gap: .35rem; padding: 0 1.1rem .875rem; }
.ptv__tarea-chip { display: inline-flex; align-items: center; gap: .3rem; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: .2rem .5rem; font-size: .72rem; max-width: 180px; }
.ptv__tarea-dia { font-size: .65rem; font-weight: 800; color: #1b5e20; background: #dcfce7; padding: .1em .35em; border-radius: 4px; flex-shrink: 0; }
.ptv__tarea-nombre { color: #475569; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-weight: 600; }
.ptv__tarea-chip--more { color: #94a3b8; border-style: dashed; }

/* Footer */
.ptv__card-footer { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1.1rem; border-top: 1px solid #f1f5f9; background: #fafbfc; margin-top: auto; border-radius: 0 0 14px 14px; }
.ptv__card-meta { font-size: .72rem; color: #94a3b8; }
.ptv__card-actions { display: flex; align-items: center; gap: .4rem; }

/* Planes aplicados */
.ptv__apl { margin-top: 2.5rem; }
.ptv__apl-hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; }
.ptv__apl-title { font-size: 1.15rem; font-weight: 800; margin: 0 0 .25rem; letter-spacing: -.03em; }
.ptv__apl-empty { font-size: .85rem; color: #94a3b8; background: #f8fafc; border: 1.5px dashed #e2e8f0; border-radius: 12px; padding: 1.5rem; text-align: center; }
.ptv__apl-list { display: flex; flex-direction: column; gap: .6rem; }
.ptv__apl-row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: .85rem 1.1rem; flex-wrap: wrap; }
.ptv__apl-info { flex: 1; min-width: 220px; }
.ptv__apl-plan { font-size: .9rem; font-weight: 800; color: #0f172a; display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.ptv__apl-estado { font-size: .65rem; font-weight: 800; text-transform: uppercase; letter-spacing: .04em; padding: .15em .55em; border-radius: 999px; }
.ptv__apl-estado--activo     { background: #dcfce7; color: #15803d; }
.ptv__apl-estado--completado { background: #e0f2fe; color: #0369a1; }
.ptv__apl-estado--cancelado  { background: #f1f5f9; color: #94a3b8; }
.ptv__apl-meta { display: flex; flex-wrap: wrap; gap: .85rem; font-size: .75rem; color: #64748b; margin-top: .3rem; }
.ptv__apl-meta i { margin-right: .25rem; color: #94a3b8; }
.ptv__apl-right { display: flex; align-items: center; gap: 1rem; flex-shrink: 0; }
.ptv__apl-progreso { display: flex; align-items: center; gap: .5rem; }
.ptv__apl-progreso-bar { width: 90px; height: 6px; background: #f1f5f9; border-radius: 999px; overflow: hidden; }
.ptv__apl-progreso-fill { height: 100%; background: #1b5e20; border-radius: 999px; transition: width .3s; }
.ptv__apl-progreso-pct { font-size: .72rem; font-weight: 700; color: #475569; min-width: 32px; }
.ptv__apl-quitar { width: auto; padding: 0 .7rem; gap: .35rem; font-size: .75rem; font-weight: 700; }
.ptv__apl-quitar:disabled { opacity: .5; cursor: wait; }

/* Export dropdown */
.ptv__export-wrap { position: relative; }
.ptv__export-drop { position: absolute; bottom: calc(100% + 6px); right: 0; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.12); min-width: 210px; overflow: hidden; z-index: 100; }
.ptv__drop-item { display: flex; align-items: center; gap: .5rem; width: 100%; padding: .6rem .875rem; font-size: .8rem; font-weight: 600; color: #0f172a; background: none; border: none; cursor: pointer; text-align: left; transition: background .1s; white-space: nowrap; }
.ptv__drop-item:hover { background: #f0fdf4; color: #1b5e20; }
.ptv__drop-item i { font-size: .9rem; color: #64748b; flex-shrink: 0; }
.ptv__drop-item:hover i { color: #1b5e20; }
</style>
