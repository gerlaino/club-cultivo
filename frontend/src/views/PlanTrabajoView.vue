<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useUsoPersonal } from '../composables/useUsoPersonal.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import AplicarPlanModal       from '../components/plan-trabajo/AplicarPlanModal.vue'
import EditarPlantillaModal   from '../components/plan-trabajo/EditarPlantillaModal.vue'
import ExportarCalendarioModal from '../components/plan-trabajo/ExportarCalendarioModal.vue'
import PlanCalendario from '../components/plan-trabajo/PlanCalendario.vue'
import { listPlanTrabajos, deletePlanTrabajo, getPlanTrabajo, exportPlanCSV, listAplicaciones, cancelarAplicacion, publicarPlanTrabajo } from '../lib/api.js'
const { esPersonal } = useUsoPersonal()

const toast   = useToast()
const confirm = useConfirm()

const loading    = ref(true)
const plantillas = ref([])
// La biblioteca a la izquierda, el plan elegido a la derecha con su calendario (7-oct-2026).
const elegidoId = ref(null)
const elegido = computed(() => plantillas.value.find(p => p.id === elegidoId.value) || plantillas.value[0] || null)
// El listado trae cuántas tareas tiene cada plan, no cuáles: el calendario del elegido pide su
// detalle (una vez por plan; se vuelve a pedir al guardarlo).
const detalles = ref({})
const tareasElegido = computed(() => detalles.value[elegido.value?.id]?.plan_tareas || [])
async function cargarDetalle(id, forzar = false) {
  if (!id || (detalles.value[id] && !forzar)) return
  try {
    const { data } = await getPlanTrabajo(id)
    detalles.value = { ...detalles.value, [id]: data }
  } catch { /* el calendario queda vacío; la lista sigue andando */ }
}
watch(() => elegido.value?.id, (id) => cargarDetalle(id), { immediate: true })
const semanasDe = (plan) => {
  const tareas = detalles.value[plan?.id]?.plan_tareas || plan?.plan_tareas
  if (!tareas?.length) return null
  return Math.floor(Math.max(0, ...tareas.map(t => t.dia_relativo ?? 0)) / 7) + 1
}
const enCursoDe = (plan) => aplicaciones.value.filter(a => a.estado === 'activo' && a.plan_trabajo?.id === plan.id).length

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
  if (!a.objetivo_tipo) return esPersonal.value ? 'Todo el cultivo' : 'Toda la organización'
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

function onSaved() {
  const id = planActivo.value?.id
  showEditar.value = false
  cargar()
  if (id) cargarDetalle(id, true)
}
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
  <!-- Rediseño 7-oct-2026: biblioteca de planes a la izquierda, el elegido con su calendario por
       semana a la derecha, y abajo lo que está en curso. Antes eran tarjetas con chips «D3». -->
  <div class="ptv">
    <div class="ptv__hdr">
      <div>
        <h1 class="ptv__title">Planes</h1>
        <p class="ptv__subtitle">Lo que se hace en cada semana del ciclo. Se arma una vez y se aplica a los lotes.</p>
      </div>
      <button class="ptv__btn-primary" @click="abrirEditar()"><i class="bi bi-plus-lg"></i> Plan nuevo</button>
    </div>

    <div v-if="loading" class="ptv__loading"><DsSpinner /></div>

    <div v-else-if="!plantillas.length" class="ptv__empty">
      <div class="ptv__empty-icon"><i class="bi bi-clipboard2-check"></i></div>
      <div class="ptv__empty-title">Todavía no hay planes</div>
      <div class="ptv__empty-sub">Armá el primero: qué se hace cada semana, desde que el lote entra a la sala.</div>
      <button class="ptv__btn-primary" @click="abrirEditar()"><i class="bi bi-plus-lg"></i> Armar un plan</button>
    </div>

    <div v-else class="ptv__lib">
      <nav class="ptv__lista" aria-label="Mis planes">
        <div class="ptv__lista-tit">Mis planes</div>
        <button v-for="plan in plantillas" :key="plan.id" type="button" class="ptv__item"
                :class="{ 'ptv__item--on': elegido?.id === plan.id }" :aria-current="elegido?.id === plan.id ? 'true' : undefined"
                @click="elegidoId = plan.id">
          <span class="ptv__item-tit">{{ plan.titulo }}</span>
          <span class="ptv__item-sub">
            {{ plan.total_plan_tareas }} {{ plan.total_plan_tareas === 1 ? 'tarea' : 'tareas' }}<template v-if="semanasDe(plan)"> · {{ semanasDe(plan) }} sem</template>
            <template v-if="enCursoDe(plan)"> · en curso en {{ enCursoDe(plan) }}</template>
            <template v-if="plan.estado === 'borrador'"> · borrador</template>
          </span>
        </button>
      </nav>

      <section v-if="elegido" class="ptv__detalle">
        <div class="ptv__detalle-hdr">
          <div class="ptv__detalle-txt">
            <h2 class="ptv__detalle-tit">{{ elegido.titulo }}</h2>
            <p v-if="elegido.notas" class="ptv__subtitle">{{ elegido.notas }}</p>
          </div>
          <div class="ptv__card-actions">
            <button class="ptv__btn-ghost-txt" @click="abrirEditar(elegido)"><i class="bi bi-pencil"></i> Editar</button>
            <div class="ptv__export-wrap">
              <button class="ptv__btn-ghost-txt" @click.stop="toggleExportDropdown(elegido)"><i class="bi bi-download"></i> Exportar</button>
              <div v-if="exportDropdownPlan?.id === elegido.id" class="ptv__export-drop">
                <button class="ptv__drop-item" @click="descargarPlantillaCSV(elegido)"><i class="bi bi-filetype-csv"></i> Descargar plantilla (.csv)</button>
                <button class="ptv__drop-item" @click="abrirCalendario(elegido)"><i class="bi bi-calendar3-week"></i> Exportar como calendario…</button>
              </div>
            </div>
            <button class="ptv__btn-ghost-txt ptv__btn-ghost-txt--peligro" @click="eliminar(elegido)"><i class="bi bi-trash3"></i> Eliminar</button>
            <!-- Un borrador no se puede aplicar: primero se publica. -->
            <button v-if="elegido.estado === 'borrador'" class="ptv__btn-primary" @click="publicar(elegido)"
                    title="Publicar — necesario para poder aplicarlo a un lote"><i class="bi bi-send-check"></i> Publicar</button>
            <button v-else class="ptv__btn-primary" @click="abrirAplicar(elegido)"><i class="bi bi-play-fill"></i> Aplicar a lotes</button>
          </div>
        </div>
        <PlanCalendario :tareas="tareasElegido" />
        <p class="ptv__pie">Cada casilla dice qué toca esa semana. Para cambiarlo, «Editar».</p>
      </section>
    </div>

    <!-- ── Planes en curso ─────────────────────────────────── -->
    <section class="ptv__apl">
      <div class="ptv__apl-hdr">
        <div>
          <h2 class="ptv__apl-title">{{ verHistorialApl ? 'Todos los planes aplicados' : 'Planes en curso' }}</h2>
          <p class="ptv__subtitle">Sobre lotes, salas o {{ esPersonal ? 'todo el cultivo' : 'la organización' }}.</p>
        </div>
        <button class="ptv__btn-ghost-txt" @click="toggleHistorialApl">{{ verHistorialApl ? 'Ver sólo los activos' : 'Ver historial' }}</button>
      </div>

      <div v-if="loadingAplicaciones" class="ptv__loading"><DsSpinner /></div>
      <p v-else-if="!aplicaciones.length" class="ptv__apl-empty">
        {{ verHistorialApl ? 'Todavía no se aplicó ningún plan.' : 'No hay planes en curso. Elegí uno arriba y «Aplicar a lotes».' }}
      </p>
      <div v-else class="ptv__apl-list">
        <div v-for="a in aplicaciones" :key="a.id" class="ptv__apl-row">
          <div class="ptv__apl-info">
            <div class="ptv__apl-plan">
              {{ a.plan_trabajo?.titulo }}
              <span class="ptv__apl-estado" :class="`ptv__apl-estado--${a.estado}`">{{ a.estado }}</span>
            </div>
            <div class="ptv__apl-meta">
              <span>{{ describirObjetivo(a) }}</span>
              <span>desde el {{ new Date(a.fecha_inicio).toLocaleDateString('es-AR') }}</span>
              <span>{{ a.tareas_creadas }} tareas</span>
              <span v-if="a.aplicado_por">por {{ a.aplicado_por.nombre }}</span>
            </div>
          </div>
          <div class="ptv__apl-right">
            <div class="ptv__apl-progreso" :title="`${a.porcentaje_completado}% completado`">
              <div class="ptv__apl-progreso-bar"><div class="ptv__apl-progreso-fill" :style="{ width: a.porcentaje_completado + '%' }"></div></div>
              <span class="ptv__apl-progreso-pct">{{ a.porcentaje_completado }}%</span>
            </div>
            <button v-if="a.estado === 'activo'" class="ptv__btn-ghost-txt ptv__btn-ghost-txt--peligro" :disabled="quitandoId === a.id"
                    @click="quitarPlan(a)" title="Quitar plan (cancela tareas pendientes)">Quitar</button>
          </div>
        </div>
      </div>
    </section>

    <EditarPlantillaModal v-if="showEditar" :plan="planActivo" @close="showEditar = false" @saved="onSaved" />
    <AplicarPlanModal v-if="showAplicar && planActivo" :plan="planActivo" @close="showAplicar = false" @applied="onAplicado" />
    <ExportarCalendarioModal v-if="showCalendario && planActivo" :plan="planActivo" @close="showCalendario = false" />
  </div>
</template>

<style scoped>
.ptv { display: flex; flex-direction: column; gap: 1.2rem; }
.ptv__lib { display: flex; gap: 1.2rem; align-items: flex-start; flex-wrap: wrap; }
.ptv__lista { flex: 1 1 240px; max-width: 300px; display: flex; flex-direction: column; gap: .45rem; }
.ptv__lista-tit { font-size: .7rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--c-slate-500); }
.ptv__item { display: flex; flex-direction: column; gap: .15rem; text-align: left; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; padding: .7rem .85rem; cursor: pointer; font: inherit; }
.ptv__item:hover { border-color: var(--c-leaf-300); }
.ptv__item--on { border: 2px solid var(--c-leaf-800); }
.ptv__item-tit { font-weight: 700; font-size: .9rem; color: var(--c-slate-900); }
.ptv__item-sub { font-size: .76rem; color: var(--c-slate-500); }
.ptv__detalle { flex: 999 1 520px; min-width: 0; background: #fff; border: 1px solid var(--c-slate-200); border-radius: 16px; padding: 1.2rem; display: flex; flex-direction: column; gap: 1rem; }
.ptv__detalle-hdr { display: flex; align-items: flex-start; gap: .8rem; flex-wrap: wrap; }
.ptv__detalle-txt { flex: 1; min-width: 200px; }
.ptv__detalle-tit { margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--c-slate-900); }
.ptv__pie { margin: 0; font-size: .8rem; color: var(--c-slate-500); }
.ptv__btn-ghost-txt { height: 40px; display: inline-flex; align-items: center; gap: .35rem; padding: 0 .85rem; border-radius: 10px; border: 1px solid var(--c-slate-300); background: #fff; color: var(--c-slate-700); font-weight: 600; font-size: .82rem; cursor: pointer; }
.ptv__btn-ghost-txt:hover { background: var(--c-slate-50); }
.ptv__btn-ghost-txt--peligro { color: var(--c-rust-600); }
.ptv__card-actions { display: flex; gap: .4rem; flex-wrap: wrap; align-items: center; }
.ptv { padding: 2rem 1.75rem 3rem; max-width: 1100px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: var(--c-slate-900); }
@media (max-width: 768px) { .ptv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.ptv__hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.ptv__title { font-size: 1.6rem; font-weight: 800; margin: 0 0 .25rem; letter-spacing: -.04em; }
.ptv__subtitle { font-size: .875rem; color: var(--c-slate-500); margin: 0; }
.ptv__hdr-actions { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }

/* Buttons */
.ptv__btn-primary   { display: inline-flex; align-items: center; gap: .4rem; background: var(--c-leaf-800); color: #fff; border: none; height: 40px; padding: 0 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 700; cursor: pointer; transition: background .15s; }
.ptv__btn-primary:hover { background: var(--c-leaf-900); }
.ptv__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: var(--c-slate-50); color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); padding: .55rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 700; cursor: pointer; transition: all .15s; }
.ptv__btn-secondary:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.ptv__btn-apply     { display: inline-flex; align-items: center; gap: .35rem; background: #1b5e20; color: #fff; border: none; padding: .45rem .9rem; border-radius: 7px; font-size: .78rem; font-weight: 700; cursor: pointer; transition: background .15s; }
.ptv__btn-apply:hover { background: #144a18; }
.ptv__btn-ghost     { display: inline-flex; align-items: center; justify-content: center; width: 32px; height: 32px; background: var(--c-slate-50); color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); border-radius: 7px; font-size: .85rem; cursor: pointer; transition: all .15s; }
.ptv__btn-ghost:hover { border-color: var(--c-slate-400); color: #1b5e20; }
.ptv__btn-danger-sm { display: inline-flex; align-items: center; justify-content: center; width: 32px; height: 32px; background: #fef2f2; color: #dc2626; border: 1.5px solid #fecaca; border-radius: 7px; font-size: .85rem; cursor: pointer; transition: all .15s; }
.ptv__btn-danger-sm:hover { background: #fee2e2; }
.ptv__btn-publicar { display: inline-flex; align-items: center; gap: .35rem; height: 32px; padding: 0 .7rem; background: #dcfce7; color: #15803d; border: 1.5px solid #bbf7d0; border-radius: 7px; font-size: .78rem; font-weight: 700; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ptv__btn-publicar:hover { background: #bbf7d0; }

/* Loading */
.ptv__loading { display: flex; justify-content: center; padding: 4rem; }

/* Empty state */
.ptv__empty { text-align: center; padding: 5rem 2rem; display: flex; flex-direction: column; align-items: center; gap: 1rem; }
.ptv__empty-icon  { width: 64px; height: 64px; border-radius: 18px; background: #f0fdf4; color: #1b5e20; display: flex; align-items: center; justify-content: center; font-size: 1.75rem; }
.ptv__empty-title { font-size: 1.1rem; font-weight: 700; color: var(--c-slate-900); }
.ptv__empty-sub   { font-size: .875rem; color: var(--c-slate-500); max-width: 420px; }
.ptv__empty-actions { display: flex; gap: .5rem; flex-wrap: wrap; justify-content: center; }

/* Grid de cards */
.ptv__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); gap: 1.25rem; }
@media (max-width: 600px) { .ptv__grid { grid-template-columns: 1fr; } }

/* Card */
.ptv__card { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 14px; overflow: visible; display: flex; flex-direction: column; transition: box-shadow .15s; }
.ptv__card:hover { box-shadow: 0 4px 16px rgba(0,0,0,.08); }
.ptv__card-hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.1rem .75rem; }
.ptv__card-info { flex: 1; min-width: 0; }
.ptv__card-titulo { font-size: .975rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .25rem; }
.ptv__card-notas { font-size: .78rem; color: var(--c-slate-500); margin: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ptv__card-badge { display: inline-flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 700; color: #1b5e20; background: #f0fdf4; padding: .25em .65em; border-radius: 999px; white-space: nowrap; flex-shrink: 0; }

/* Preview tareas */
.ptv__tareas-preview { display: flex; flex-wrap: wrap; gap: .35rem; padding: 0 1.1rem .875rem; }
.ptv__tarea-chip { display: inline-flex; align-items: center; gap: .3rem; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 6px; padding: .2rem .5rem; font-size: .72rem; max-width: 180px; }
.ptv__tarea-dia { font-size: .65rem; font-weight: 800; color: #1b5e20; background: #dcfce7; padding: .1em .35em; border-radius: 4px; flex-shrink: 0; }
.ptv__tarea-nombre { color: var(--c-slate-600); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-weight: 600; }
.ptv__tarea-chip--more { color: var(--c-slate-400); border-style: dashed; }

/* Footer */
.ptv__card-footer { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1.1rem; border-top: 1px solid var(--c-slate-100); background: #fafbfc; margin-top: auto; border-radius: 0 0 14px 14px; }
.ptv__card-meta { font-size: .72rem; color: var(--c-slate-400); }
.ptv__card-actions { display: flex; align-items: center; gap: .4rem; }

/* Planes aplicados */
.ptv__apl { margin-top: 2.5rem; }
.ptv__apl-hdr { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; }
.ptv__apl-title { font-size: 1.15rem; font-weight: 800; margin: 0 0 .25rem; letter-spacing: -.03em; }
.ptv__apl-empty { font-size: .85rem; color: var(--c-slate-400); background: var(--c-slate-50); border: 1.5px dashed var(--c-slate-200); border-radius: 12px; padding: 1.5rem; text-align: center; }
.ptv__apl-list { display: flex; flex-direction: column; gap: .6rem; }
.ptv__apl-row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 12px; padding: .85rem 1.1rem; flex-wrap: wrap; }
.ptv__apl-info { flex: 1; min-width: 220px; }
.ptv__apl-plan { font-size: .9rem; font-weight: 800; color: var(--c-slate-900); display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.ptv__apl-estado { font-size: .65rem; font-weight: 800; text-transform: uppercase; letter-spacing: .04em; padding: .15em .55em; border-radius: 999px; }
.ptv__apl-estado--activo     { background: #dcfce7; color: #15803d; }
.ptv__apl-estado--completado { background: #e0f2fe; color: #0369a1; }
.ptv__apl-estado--cancelado  { background: var(--c-slate-100); color: var(--c-slate-400); }
.ptv__apl-meta { display: flex; flex-wrap: wrap; gap: .85rem; font-size: .75rem; color: var(--c-slate-500); margin-top: .3rem; }
.ptv__apl-meta i { margin-right: .25rem; color: var(--c-slate-400); }
.ptv__apl-right { display: flex; align-items: center; gap: 1rem; flex-shrink: 0; }
.ptv__apl-progreso { display: flex; align-items: center; gap: .5rem; }
.ptv__apl-progreso-bar { width: 90px; height: 6px; background: var(--c-slate-100); border-radius: 999px; overflow: hidden; }
.ptv__apl-progreso-fill { height: 100%; background: #1b5e20; border-radius: 999px; transition: width .3s; }
.ptv__apl-progreso-pct { font-size: .72rem; font-weight: 700; color: var(--c-slate-600); min-width: 32px; }
.ptv__apl-quitar { width: auto; padding: 0 .7rem; gap: .35rem; font-size: .75rem; font-weight: 700; }
.ptv__apl-quitar:disabled { opacity: .5; cursor: wait; }

/* Export dropdown */
.ptv__export-wrap { position: relative; }
.ptv__export-drop { position: absolute; top: calc(100% + 6px); right: 0; background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.12); min-width: 210px; overflow: hidden; z-index: 100; }
.ptv__drop-item { display: flex; align-items: center; gap: .5rem; width: 100%; padding: .6rem .875rem; font-size: .8rem; font-weight: 600; color: var(--c-slate-900); background: none; border: none; cursor: pointer; text-align: left; transition: background .1s; white-space: nowrap; }
.ptv__drop-item:hover { background: #f0fdf4; color: #1b5e20; }
.ptv__drop-item i { font-size: .9rem; color: var(--c-slate-500); flex-shrink: 0; }
.ptv__drop-item:hover i { color: #1b5e20; }
</style>
