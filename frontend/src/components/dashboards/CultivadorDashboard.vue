<template>
  <div class="cvd">

    <!-- Greeting -->
    <div class="cvd__top">
      <div>
        <h1 class="cvd__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <span class="cvd__fecha">{{ hoy }}</span>
      </div>
    </div>

    <!-- Alertas críticas -->
    <DsBanner
      v-for="a in alertasCriticas.slice(0, 2)"
      :key="a.id"
      variant="rust"
      icon="bi-exclamation-triangle-fill"
      class="cvd__banner"
    >
      {{ a.regla_nombre || a.tipo }} en Sala {{ salaNombre(a.sala_id) }}
      <template #action>
        <RouterLink
          v-if="a.sala_id"
          :to="{ name: 'sala-ambiente', params: { id: a.sala_id } }"
          class="cvd__banner-link"
        >Ver alerta →</RouterLink>
      </template>
    </DsBanner>

    <!-- KPIs -->
    <div v-if="loading" class="cvd__kpi-row">
      <div v-for="i in 4" :key="i" class="cvd__kpi-card cvd__kpi-card--skeleton">
        <div class="cvd__sk-ico"></div>
        <div class="cvd__sk-val"></div>
        <div class="cvd__sk-lbl"></div>
      </div>
    </div>
    <div v-else class="cvd__kpi-row">
      <div class="cvd__kpi-card">
        <div class="cvd__kpi-ico"><Sprout :size="18" :stroke-width="1.75" /></div>
        <div class="cvd__kpi-val">{{ totalPlantas }}</div>
        <div class="cvd__kpi-lbl">Plantas a cargo</div>
        <div class="cvd__kpi-sub">{{ plantasVeg }} veg · {{ plantasFlor }} flor</div>
      </div>
      <div class="cvd__kpi-card">
        <div class="cvd__kpi-ico"><LayoutGrid :size="18" :stroke-width="1.75" /></div>
        <div class="cvd__kpi-val">{{ salasActivas.length }}</div>
        <div class="cvd__kpi-lbl">Salas activas</div>
        <div class="cvd__kpi-sub">de {{ salas.length }} en total</div>
      </div>
      <div class="cvd__kpi-card">
        <div class="cvd__kpi-ico" :class="{ 'cvd__kpi-ico--amber': lotesListos > 0 }"><GitBranch :size="18" :stroke-width="1.75" /></div>
        <div class="cvd__kpi-val" :class="{ 'cvd__kpi-val--amber': lotesListos > 0 }">{{ lotesEnCiclo }}</div>
        <div class="cvd__kpi-lbl">Lotes en ciclo</div>
        <div class="cvd__kpi-sub" :class="{ 'cvd__kpi-sub--amber': lotesListos > 0 }">
          {{ lotesListos > 0 ? `${lotesListos} listo${lotesListos !== 1 ? 's' : ''} para avanzar` : 'sin cambios pendientes' }}
        </div>
      </div>
      <div class="cvd__kpi-card">
        <div class="cvd__kpi-ico" :class="{ 'cvd__kpi-ico--rust': notifCount > 0 }"><AlertTriangle :size="18" :stroke-width="1.75" /></div>
        <div class="cvd__kpi-val" :class="{ 'cvd__kpi-val--rust': notifCount > 0 }">{{ notifCount }}</div>
        <div class="cvd__kpi-lbl">Alertas activas</div>
        <div class="cvd__kpi-sub" :class="{ 'cvd__kpi-sub--rust': alertasCriticas.length > 0 }">
          {{ alertasCriticas.length > 0 ? `${alertasCriticas.length} crítica${alertasCriticas.length !== 1 ? 's' : ''}` : 'sin alertas críticas' }}
        </div>
      </div>
    </div>

    <!-- Semana de trabajo -->
    <div class="cvd__section">
      <button class="cvd__section-toggle" @click="tareasExpanded = !tareasExpanded">
        <div class="cvd__section-toggle-left">
          <h2 class="cvd__section-title">Semana de trabajo</h2>
          <span v-if="totalTareasSemana" class="cvd__section-badge cvd__section-badge--amber">{{ totalTareasSemana }}</span>
        </div>
        <div class="cvd__sem-nav" @click.stop>
          <button class="cvd__sem-btn" @click="semAnterior"><i class="bi bi-chevron-left"></i></button>
          <span class="cvd__sem-label">{{ labelSemana }}</span>
          <button class="cvd__sem-btn" @click="semSiguiente"><i class="bi bi-chevron-right"></i></button>
          <button class="cvd__sem-hoy" @click="irHoy">Hoy</button>
        </div>
        <ChevronRight :size="16" class="cvd__section-chevron" :class="{ 'cvd__section-chevron--open': tareasExpanded }" />
      </button>
      <div v-show="tareasExpanded">
        <div v-if="loadingSem" class="cvd__sem-loading">
          <div class="cvd__sem-ring"></div>
        </div>
        <div v-else-if="!semanaProcessed.dias?.length" class="cvd__tareas-empty">
          Sin datos de semana disponibles.
        </div>
        <div v-else class="cvd__sem-grid">
          <div
            v-for="dia in semanaProcessed.dias"
            :key="dia.fecha"
            class="cvd__sem-col"
            :class="{ 'cvd__sem-col--hoy': dia.fecha === hoyISO, 'cvd__sem-col--pasado': dia.fecha < hoyISO }"
          >
            <div class="cvd__sem-col-header">
              <div class="cvd__sem-dia-nombre">{{ dia.dia_semana?.slice(0, 3) }}</div>
              <div class="cvd__sem-dia-num" :class="{ 'cvd__sem-dia-num--hoy': dia.fecha === hoyISO }">
                {{ new Date(dia.fecha + 'T00:00:00').getDate() }}
              </div>
              <div v-if="dia.tareas.length" class="cvd__sem-col-count">{{ dia.tareas.length }}</div>
            </div>
            <div class="cvd__sem-tareas">
              <div
                v-for="t in dia.tareas"
                :key="t.id + (t._atrasada ? '-a' : '')"
                class="cvd__sem-tarea"
                :class="[
                  'cvd__sem-tarea--' + t.prioridad,
                  t.estado === 'completada' && 'cvd__sem-tarea--done',
                  t._atrasada && 'cvd__sem-tarea--atrasada',
                ]"
                @click="abrirTarea(t)"
              >
                <span class="cvd__sem-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
                <span class="cvd__sem-titulo">{{ t.titulo }}</span>
                <span v-if="t._atrasada" class="cvd__sem-late" title="Atrasada">⏰</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Mis salas -->
    <div class="cvd__section">
      <button class="cvd__section-toggle" @click="salasExpanded = !salasExpanded">
        <div class="cvd__section-toggle-left">
          <h2 class="cvd__section-title">Mis salas</h2>
          <span v-if="salas.length" class="cvd__section-badge">{{ salas.length }}</span>
        </div>
        <ChevronRight :size="16" class="cvd__section-chevron" :class="{ 'cvd__section-chevron--open': salasExpanded }" />
      </button>
      <div v-show="salasExpanded">
        <div v-if="loading" class="cvd__salas-grid">
          <DsCard v-for="i in 3" :key="i" variant="elevated"><DsSkeleton variant="card" /></DsCard>
        </div>
        <DsEmpty
          v-else-if="salas.length === 0"
          title="Todavía no tenés salas asignadas"
          description="Hablá con el admin para que te asigne salas."
        />
        <div v-else class="cvd__salas-grid">
          <SalaCard
            v-for="sala in salas"
            :key="sala.id"
            :sala="sala"
            :alertas="ambienteStore.alertasActivas"
            :lotes="lotesStore.items.filter(l => String(l.sala_id) === String(sala.id))"
            @registrar-lectura="onRegistrarDesdeSala"
          />
        </div>
      </div>
    </div>

    <footer class="cvd__footer">
      <LeafHerbarium :size="12" />
      Cultivo Espacial · {{ club.name }}
    </footer>

  </div>

  <!-- Panel detalle tarea -->
  <Teleport to="body">
    <div v-if="tareaDetalle" class="cvd__panel-overlay" @click.self="tareaDetalle = null">
      <div class="cvd__panel">
        <div class="cvd__panel-header">
          <h3 class="cvd__panel-title">Detalle de tarea</h3>
          <button class="cvd__panel-close" @click="tareaDetalle = null"><i class="bi bi-x-lg"></i></button>
        </div>
        <div class="cvd__panel-body">
          <div class="cvd__panel-tipo">
            <span class="cvd__tipo-pill">{{ TIPO_META[tareaDetalle.tipo]?.emoji }} {{ TIPO_META[tareaDetalle.tipo]?.label }}</span>
          </div>
          <h4 class="cvd__panel-nombre">{{ tareaDetalle.titulo }}</h4>
          <p v-if="tareaDetalle.descripcion" class="cvd__panel-desc">{{ tareaDetalle.descripcion }}</p>
          <div class="cvd__panel-info">
            <div class="cvd__panel-row">
              <span class="cvd__panel-key">Estado</span>
              <span class="cvd__estado-pill" :style="estadoMeta(tareaDetalle.estado)">{{ tareaDetalle.estado?.replace('_', ' ') }}</span>
            </div>
            <div class="cvd__panel-row">
              <span class="cvd__panel-key">Prioridad</span>
              <span>{{ tareaDetalle.prioridad }}</span>
            </div>
            <div v-if="tareaDetalle.sala" class="cvd__panel-row">
              <span class="cvd__panel-key">Sala</span>
              <span>{{ tareaDetalle.sala.nombre }}</span>
            </div>
            <div v-if="tareaDetalle.lote" class="cvd__panel-row">
              <span class="cvd__panel-key">Lote</span>
              <RouterLink :to="`/lotes/${tareaDetalle.lote.id}`" class="cvd__panel-link">
                {{ tareaDetalle.lote.codigo }} <i class="bi bi-arrow-right-short"></i>
              </RouterLink>
            </div>
            <div v-if="tareaDetalle.fecha_programada" class="cvd__panel-row">
              <span class="cvd__panel-key">Fecha</span>
              <span>{{ formatFechaLarga(tareaDetalle.fecha_programada) }}</span>
            </div>
          </div>
          <div class="cvd__panel-actions">
            <p v-if="esTareaFutura(tareaDetalle) && tareaDetalle.estado !== 'completada'" class="cvd__futura-hint">
              <i class="bi bi-calendar-event"></i> Disponible el {{ formatFechaLarga(tareaDetalle.fecha_programada) }}
            </p>
            <button
              v-if="tareaDetalle.estado !== 'completada' && !esTareaFutura(tareaDetalle)"
              class="cvd__panel-btn cvd__panel-btn--primary"
              :disabled="guardandoAccion"
              @click="finalizarTarea"
            >
              <i class="bi bi-check-circle-fill"></i>
              {{ guardandoAccion ? 'Guardando…' : 'Finalizada' }}
            </button>
            <button
              v-if="tareaDetalle.estado === 'completada'"
              class="cvd__panel-btn cvd__panel-btn--ghost"
              :disabled="guardandoAccion"
              @click="revertirTarea"
            >
              <i class="bi bi-arrow-counterclockwise"></i>
              {{ guardandoAccion ? 'Guardando…' : 'Sin finalizar' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>

  <RegistrarLecturaSheet v-model="lecturaOpen" :sala-id-inicial="lecturaSalaId" />
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useAuthStore }     from '../../stores/auth'
import { useClubStore }     from '../../stores/club'
import { useTareasStore }   from '../../stores/tareas'
import { useSalasStore }    from '../../stores/salas'
import { useLotesStore }    from '../../stores/lotes'
import { useAmbienteStore } from '../../stores/ambiente'
import { useAlertasBell }   from '../../composables/useAlertasBell.js'
import { useToast }         from '../../composables/useToast.js'
import { formatFechaLarga } from '../../utils/fecha.js'
import { getTareasSemana }  from '../../lib/api'

import DsCard     from '../../design-system/components/Card.vue'
import DsStat     from '../../design-system/components/Stat.vue'
import DsBadge    from '../../design-system/components/Badge.vue'
import DsBanner   from '../../design-system/components/Banner.vue'
import DsEmpty    from '../../design-system/components/EmptyState.vue'
import DsSkeleton from '../../design-system/components/Skeleton.vue'
import LeafHerbarium from '../../design-system/icons/LeafHerbarium.vue'
import SalaCard   from '../cultivador/SalaCard.vue'
import RegistrarLecturaSheet from '../cultivador/RegistrarLecturaSheet.vue'
import { LayoutGrid, Sprout, GitBranch, AlertTriangle, ChevronRight } from 'lucide-vue-next'

const auth          = useAuthStore()
const club          = useClubStore()
const tareasStore   = useTareasStore()
const salasStore    = useSalasStore()
const lotesStore    = useLotesStore()
const ambienteStore = useAmbienteStore()

const toast = useToast()
useAlertasBell()

const loading       = ref(true)
const lecturaOpen   = ref(false)
const lecturaSalaId = ref(null)
const tareaDetalle  = ref(null)
const guardandoAccion = ref(false)
const salasExpanded  = ref(true)
const tareasExpanded = ref(true)

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
const TIPO_EMOJI = {
  riego: '💧', poda: '✂️', medicion: '📏', limpieza: '🧹',
  cosecha: '🌿', transplante: '🪴', inspeccion: '🔍', otro: '📋',
}
function estadoMeta(estado) {
  return {
    pendiente:   { background: 'rgba(100,116,139,.1)', color: '#475569' },
    en_progreso: { background: 'rgba(217,119,6,.1)',   color: '#d97706' },
    completada:  { background: 'rgba(21,128,61,.1)',   color: '#15803d' },
    cancelada:   { background: 'rgba(220,38,38,.1)',   color: '#dc2626' },
  }[estado] || { background: '#f1f5f9', color: '#64748b' }
}

function localDateISO() {
  const n = new Date()
  return `${n.getFullYear()}-${String(n.getMonth() + 1).padStart(2, '0')}-${String(n.getDate()).padStart(2, '0')}`
}
const hoyISO = localDateISO()

// ── Semana de trabajo ──────────────────────────────────────
const semana     = ref({ desde: null, hasta: null, dias: [] })
const loadingSem = ref(false)

function isoLunes() {
  const hoy = new Date()
  const dow  = hoy.getDay()
  const diff = dow === 0 ? -6 : 1 - dow
  const d    = new Date(hoy)
  d.setDate(hoy.getDate() + diff)
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}
const desdeRef = ref(isoLunes())

function addDays(iso, n) {
  const d = new Date(iso + 'T00:00:00')
  d.setDate(d.getDate() + n)
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}

async function cargarSemana() {
  loadingSem.value = true
  try {
    const { data } = await getTareasSemana(desdeRef.value)
    semana.value = data
  } finally {
    loadingSem.value = false
  }
}
function semAnterior()  { desdeRef.value = addDays(desdeRef.value, -7); cargarSemana() }
function semSiguiente() { desdeRef.value = addDays(desdeRef.value,  7); cargarSemana() }
function irHoy()        { desdeRef.value = isoLunes(); cargarSemana() }

const labelSemana = computed(() => {
  if (!semana.value.desde) return ''
  const d = new Date(semana.value.desde + 'T00:00:00')
  const h = new Date(semana.value.hasta  + 'T00:00:00')
  return `${d.getDate()} — ${h.getDate()} ${h.toLocaleDateString('es-AR', { month: 'short' })}`
})

const semanaProcessed = computed(() => {
  if (!semana.value.dias?.length) return semana.value
  const dias = semana.value.dias.map(d => ({ ...d, tareas: [...d.tareas] }))
  const hoyIdx = dias.findIndex(d => d.fecha === hoyISO)
  if (hoyIdx > 0) {
    for (let i = 0; i < hoyIdx; i++) {
      const overdue = dias[i].tareas.filter(t => t.estado !== 'completada' && t.estado !== 'cancelada')
      overdue.forEach(t => dias[hoyIdx].tareas.unshift({ ...t, _atrasada: true }))
      dias[i] = { ...dias[i], tareas: dias[i].tareas.filter(t => t.estado === 'completada' || t.estado === 'cancelada') }
    }
  }
  return { ...semana.value, dias }
})

const totalTareasSemana = computed(() =>
  semanaProcessed.value.dias?.reduce((acc, d) =>
    acc + d.tareas.filter(t => t.estado !== 'completada' && t.estado !== 'cancelada').length, 0) || 0
)

function esTareaFutura(t) {
  if (!t?.fecha_programada) return false
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0)
  return new Date(t.fecha_programada + 'T00:00:00') > hoy
}

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = (() => {
  const d = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
  return d.charAt(0).toUpperCase() + d.slice(1).toLowerCase()
})()

const salas        = computed(() => salasStore.items || [])
const salasActivas = computed(() => salas.value.filter(s => s.state === 'activa'))
function salaNombre(salaId) {
  return salas.value.find(s => String(s.id) === String(salaId))?.nombre || `Sala #${salaId}`
}

const totalPlantas    = computed(() => salas.value.reduce((acc, s) => acc + (s.plantas_totales || 0), 0))
const plantasVeg      = computed(() => lotesStore.items.filter(l => l.estado === 'vegetativo').reduce((a, l) => a + (l.plants_count || 0), 0))
const plantasFlor     = computed(() => lotesStore.items.filter(l => l.estado === 'floracion').reduce((a, l) => a + (l.plants_count || 0), 0))
const lotesEnCiclo    = computed(() => lotesStore.items.filter(l => ['vegetativo', 'floracion', 'secado'].includes(l.estado)).length)
const lotesListos     = computed(() => lotesStore.items.filter(l => l.puede_transicionar === true).length)
const notifCount      = computed(() => ambienteStore.alertasCount)
const alertasCriticas = computed(() => ambienteStore.alertasActivas.filter(a => ['temperatura', 'co2'].includes(a.tipo)))

function abrirTarea(t) { tareaDetalle.value = t }

async function finalizarTarea() {
  if (!tareaDetalle.value) return
  guardandoAccion.value = true
  try {
    await tareasStore.completar(tareaDetalle.value.id, null, '')
    await cargarSemana()
    tareaDetalle.value = null
    toast.success('Tarea finalizada')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo finalizar la tarea')
  } finally { guardandoAccion.value = false }
}

async function revertirTarea() {
  if (!tareaDetalle.value) return
  guardandoAccion.value = true
  try {
    await tareasStore.update(tareaDetalle.value.id, { estado: 'pendiente' })
    await cargarSemana()
    tareaDetalle.value = null
    toast.success('Tarea marcada como pendiente')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo actualizar la tarea')
  } finally { guardandoAccion.value = false }
}

function onRegistrarDesdeSala(sala) {
  lecturaSalaId.value = sala?.id ?? null
  lecturaOpen.value = true
}

function panelEscapeHandler(e) {
  if (e.key === 'Escape' && tareaDetalle.value) tareaDetalle.value = null
}
onMounted(() => document.addEventListener('keydown', panelEscapeHandler, true))
onUnmounted(() => document.removeEventListener('keydown', panelEscapeHandler, true))

onMounted(async () => {
  try {
    await Promise.all([
      salasStore.fetch(),
      lotesStore.fetch(),
      cargarSemana(),
      ambienteStore.cargarAlertas(),
    ])
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.cvd { max-width: 1280px; margin: 0 auto; padding: 1.5rem 1.25rem; display: flex; flex-direction: column; gap: 1.75rem; }
@media (max-width: 767px) { .cvd { padding: 1rem .75rem 80px; gap: 1.25rem; } }

/* Greeting */
.cvd__top   { display: flex; align-items: flex-start; justify-content: space-between; flex-wrap: wrap; }
.cvd__saludo { font-size: 1.5rem; font-weight: 700; color: #0f2611; margin: 0 0 .2rem; line-height: 1.2; }
@media (max-width: 640px) { .cvd__saludo { font-size: 1.2rem; } }
.cvd__fecha { font-size: .85rem; color: #60725d; }
.cvd__banner { margin-bottom: 0; }
.cvd__banner-link { font-size: .82rem; font-weight: 600; text-decoration: underline; color: inherit; }

/* KPIs */
.cvd__kpi-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; }
@media (max-width: 1023px) { .cvd__kpi-row { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 480px)  { .cvd__kpi-row { grid-template-columns: 1fr 1fr; gap: .5rem; } }
.cvd__kpi-card { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1rem; display: flex; flex-direction: column; gap: .35rem; }
.cvd__kpi-card--skeleton { gap: .5rem; }
.cvd__kpi-ico { width: 34px; height: 34px; border-radius: 8px; background: #f0fdf4; color: #1b5e20; display: flex; align-items: center; justify-content: center; margin-bottom: .15rem; }
.cvd__kpi-ico--amber { background: #fffbeb; color: #d97706; }
.cvd__kpi-ico--rust  { background: #fef2f2; color: #dc2626; }
.cvd__kpi-val { font-size: 1.75rem; font-weight: 700; color: #0f2611; line-height: 1; }
.cvd__kpi-val--amber { color: #d97706; }
.cvd__kpi-val--rust  { color: #dc2626; }
.cvd__kpi-lbl { font-size: .8rem; font-weight: 600; color: #0f2611; }
.cvd__kpi-sub { font-size: .75rem; color: #60725d; }
.cvd__kpi-sub--amber { color: #d97706; font-weight: 500; }
.cvd__kpi-sub--rust  { color: #dc2626; font-weight: 500; }

/* Skeleton KPI */
.cvd__sk-ico { width: 34px; height: 34px; border-radius: 8px; background: #e8f0e9; animation: cvd-pulse 1.4s ease infinite; }
.cvd__sk-val { height: 28px; width: 60%; border-radius: 6px; background: #e8f0e9; animation: cvd-pulse 1.4s ease infinite .1s; }
.cvd__sk-lbl { height: 12px; width: 80%; border-radius: 4px; background: #e8f0e9; animation: cvd-pulse 1.4s ease infinite .2s; }
@keyframes cvd-pulse { 0%,100% { opacity: 1; } 50% { opacity: .45; } }

/* Sections */
.cvd__section {}
.cvd__section-toggle {
  width: 100%; display: flex; align-items: center; justify-content: space-between;
  background: #fff; border: 1px solid #e8f0e9; border-radius: 10px;
  padding: .65rem 1rem; cursor: pointer; margin-bottom: 1rem;
  transition: border-color .15s, box-shadow .15s;
}
.cvd__section-toggle:hover { border-color: #c8e6c9; box-shadow: 0 2px 6px rgba(0,0,0,.05); }
.cvd__section-toggle-left { display: flex; align-items: center; gap: .5rem; }
.cvd__section-title { font-size: 1.05rem; font-weight: 700; color: #0f2611; margin: 0; }
.cvd__section-badge { display: inline-flex; align-items: center; justify-content: center; min-width: 20px; height: 20px; border-radius: 999px; background: #e8f0e9; color: #0f2611; font-size: .72rem; font-weight: 700; padding: 0 .35rem; }
.cvd__section-badge--amber { background: #fef3c7; color: #d97706; }
.cvd__section-chevron { color: #60725d; transition: transform .2s; flex-shrink: 0; }
.cvd__section-chevron--open { transform: rotate(90deg); }

/* Salas grid */
.cvd__salas-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; }
@media (max-width: 640px) { .cvd__salas-grid { grid-template-columns: 1fr; } }

/* Semana de trabajo */
.cvd__sem-nav { display: flex; align-items: center; gap: .35rem; margin-left: auto; margin-right: .75rem; }
.cvd__sem-btn { background: #f6faf6; border: 1px solid #e8f0e9; border-radius: 6px; width: 26px; height: 26px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: #60725d; font-size: .75rem; transition: all .12s; }
.cvd__sem-btn:hover { background: #e8f0e9; color: #0f2611; }
.cvd__sem-label { font-size: .78rem; font-weight: 600; color: #0f2611; white-space: nowrap; padding: 0 .25rem; }
.cvd__sem-hoy { background: none; border: 1px solid #e8f0e9; border-radius: 6px; padding: .2rem .55rem; font-size: .72rem; font-weight: 600; color: #60725d; cursor: pointer; transition: all .12s; white-space: nowrap; }
.cvd__sem-hoy:hover { background: #e8f0e9; color: #0f2611; }

.cvd__tareas-empty { font-size: .85rem; color: #60725d; padding: 1rem 0; }

.cvd__sem-loading { display: flex; justify-content: center; padding: 2.5rem; }
.cvd__sem-ring { width: 20px; height: 20px; border: 2px solid #e8f0e9; border-top-color: #1b5e20; border-radius: 50%; animation: cvd-spin .7s linear infinite; }
@keyframes cvd-spin { to { transform: rotate(360deg); } }

.cvd__sem-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: .4rem; padding-bottom: .25rem; overflow-x: auto; }
@media (max-width: 900px) { .cvd__sem-grid { grid-template-columns: repeat(7, minmax(105px, 1fr)); } }

.cvd__sem-col { border: 1.5px solid #e8f0e9; border-radius: 10px; background: #fff; display: flex; flex-direction: column; min-height: 200px; overflow: hidden; }
.cvd__sem-col--hoy { border-color: #1b5e20; }
.cvd__sem-col--pasado { opacity: .6; }

.cvd__sem-col-header { padding: .45rem .5rem; text-align: center; border-bottom: 1px solid #f0f4f0; background: #f6faf6; display: flex; flex-direction: column; align-items: center; gap: .1rem; }
.cvd__sem-col--hoy .cvd__sem-col-header { background: #f0fdf4; }
.cvd__sem-dia-nombre { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #60725d; }
.cvd__sem-dia-num { font-size: 1.15rem; font-weight: 800; color: #0f2611; line-height: 1; }
.cvd__sem-dia-num--hoy { color: #1b5e20; }
.cvd__sem-col-count { font-size: .58rem; font-weight: 700; background: #e8f0e9; color: #0f2611; padding: .1em .4em; border-radius: 3px; }
.cvd__sem-col--hoy .cvd__sem-col-count { background: #dcfce7; color: #15803d; }

.cvd__sem-tareas { flex: 1; padding: .35rem; display: flex; flex-direction: column; gap: .25rem; }

.cvd__sem-tarea { display: flex; align-items: center; gap: .25rem; padding: .3rem .4rem; border-radius: 6px; border-left: 3px solid #e8f0e9; background: #f6faf6; cursor: pointer; font-size: .7rem; transition: opacity .12s, box-shadow .12s; }
.cvd__sem-tarea:hover { opacity: .85; box-shadow: 0 1px 4px rgba(0,0,0,.08); }
.cvd__sem-tarea--urgente { border-left-color: #dc2626; }
.cvd__sem-tarea--alta    { border-left-color: #f97316; }
.cvd__sem-tarea--normal  { border-left-color: #1b5e20; }
.cvd__sem-tarea--baja    { border-left-color: #9ca3af; }
.cvd__sem-tarea--done    { opacity: .35; text-decoration: line-through; }
.cvd__sem-tarea--atrasada { background: #fff7ed; border-left-color: #f97316; }
.cvd__sem-emoji  { flex-shrink: 0; font-size: .78rem; }
.cvd__sem-titulo { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #0f2611; font-weight: 500; }
.cvd__sem-late   { flex-shrink: 0; font-size: .7rem; }

/* Footer */
.cvd__footer { display: flex; align-items: center; gap: .5rem; font-size: .78rem; color: #60725d; padding-top: .75rem; border-top: 1px solid #e8f0e9; }

/* Panel detalle tarea */
.cvd__panel-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.35); z-index: 1040; display: flex; justify-content: flex-end; }
.cvd__panel { width: min(420px, 100vw); height: 100%; background: #fff; display: flex; flex-direction: column; box-shadow: -8px 0 32px rgba(0,0,0,.12); animation: cvd-slide .2s ease; }
@keyframes cvd-slide { from { transform: translateX(100%); } to { transform: translateX(0); } }
.cvd__panel-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; }
.cvd__panel-title  { font-size: .95rem; font-weight: 700; margin: 0; }
.cvd__panel-close  { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.cvd__panel-close:hover { background: #e2e8f0; }
.cvd__panel-body { padding: 1.5rem; flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 1rem; }
.cvd__tipo-pill { display: inline-flex; align-items: center; gap: .35rem; background: #e8f5e9; color: #1b5e20; font-size: .75rem; font-weight: 700; padding: .25em .75em; border-radius: 6px; }
.cvd__panel-nombre { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.03em; }
.cvd__panel-desc   { font-size: .85rem; color: #64748b; margin: 0; line-height: 1.6; }
.cvd__panel-info   { border: 1px solid #f1f5f9; border-radius: 10px; overflow: hidden; }
.cvd__panel-row    { display: flex; justify-content: space-between; align-items: center; padding: .65rem 1rem; border-bottom: 1px solid #f8fafc; font-size: .82rem; }
.cvd__panel-row:last-child { border-bottom: none; }
.cvd__panel-key    { color: #94a3b8; font-size: .72rem; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; }
.cvd__panel-link   { color: #1b5e20; text-decoration: none; font-weight: 600; }
.cvd__estado-pill  { font-size: .7rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; text-transform: capitalize; }
.cvd__panel-actions { display: flex; flex-direction: column; gap: .5rem; padding-top: .5rem; }
.cvd__panel-btn { display: flex; align-items: center; justify-content: center; gap: .5rem; padding: .65rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; }
.cvd__panel-btn:disabled { opacity: .6; cursor: not-allowed; }
.cvd__panel-btn--primary { background: #1b5e20; color: #fff; }
.cvd__panel-btn--primary:not(:disabled):hover { background: #144a18; }
.cvd__panel-btn--ghost { background: #f8fafc; color: #475569; border: 1.5px solid #e2e8f0; }
.cvd__panel-btn--ghost:not(:disabled):hover { background: #e2e8f0; }
.cvd__futura-hint { display: flex; align-items: center; gap: .4rem; font-size: .8rem; color: #64748b; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: .55rem .875rem; margin: 0; }
</style>
