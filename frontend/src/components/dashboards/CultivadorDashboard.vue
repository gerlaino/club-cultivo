<template>
  <div class="cvd">

    <!-- ── BIENVENIDA ──────────────────────────────────────────── -->
    <div class="cvd__header">
      <div class="cvd__header-text">
        <h1 class="cvd__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <span class="cvd__fecha">{{ hoy }}</span>
      </div>
    </div>

    <!-- Alertas críticas -->
    <DsBanner
      v-for="(a, i) in alertasCriticas.slice(0, 2)"
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

    <!-- ── KPIs ────────────────────────────────────────────────── -->
    <div v-if="loading" class="cvd__kpi-row">
      <DsCard v-for="i in 4" :key="i" variant="elevated" class="cvd__kpi-card">
        <DsSkeleton variant="line" :rows="2" />
      </DsCard>
    </div>
    <div v-else class="cvd__kpi-row">
      <DsCard variant="elevated" class="cvd__kpi-card">
        <div class="cvd__kpi-ico"><Sprout :size="20" :stroke-width="1.75" /></div>
        <DsStat label="Plantas a cargo" :value="String(totalPlantas)" />
        <div class="cvd__kpi-sub">{{ plantasVeg }} veg · {{ plantasFlor }} flor</div>
      </DsCard>
      <DsCard variant="elevated" class="cvd__kpi-card">
        <div class="cvd__kpi-ico"><LayoutGrid :size="20" :stroke-width="1.75" /></div>
        <DsStat label="Salas activas" :value="String(salasActivas.length)" />
        <div class="cvd__kpi-sub">de {{ salas.length }} total</div>
      </DsCard>
      <DsCard variant="elevated" class="cvd__kpi-card">
        <div class="cvd__kpi-ico" :class="{ 'cvd__kpi-ico--amber': lotesListos > 0 }">
          <GitBranch :size="20" :stroke-width="1.75" />
        </div>
        <DsStat label="Lotes en ciclo" :value="String(lotesEnCiclo)" :tone="lotesListos > 0 ? 'amber' : undefined" />
        <div class="cvd__kpi-sub">{{ lotesListos > 0 ? `${lotesListos} listos para siguiente fase` : 'sin cambios pendientes' }}</div>
      </DsCard>
      <DsCard variant="elevated" class="cvd__kpi-card">
        <div class="cvd__kpi-ico" :class="{ 'cvd__kpi-ico--rust': notifCount > 0 }">
          <AlertTriangle :size="20" :stroke-width="1.75" />
        </div>
        <DsStat label="Alertas activas" :value="String(notifCount)" :tone="notifCount > 0 ? 'rust' : undefined" />
        <div class="cvd__kpi-sub">{{ alertasCriticas.length > 0 ? `${alertasCriticas.length} crítica${alertasCriticas.length !== 1 ? 's' : ''}` : 'sin alertas críticas' }}</div>
      </DsCard>
    </div>

    <!-- ── SEMANA ──────────────────────────────────────────────── -->
    <div class="cvd__section cvd__section--semana">
      <div class="cvd__section-head">
        <span class="cvd__section-dot cvd__section-dot--semana"></span>
        <h2 class="cvd__section-title">Esta semana</h2>
      </div>

      <div class="tv__semana">
        <div class="sem__nav">
          <button class="sem__nav-btn" @click="semAnterior"><i class="bi bi-chevron-left"></i></button>
          <span class="sem__nav-label">{{ labelSemana }}</span>
          <button class="sem__nav-btn" @click="semSiguiente"><i class="bi bi-chevron-right"></i></button>
          <button class="sem__hoy-btn" @click="irHoy">Hoy</button>
        </div>

        <div v-if="loadingSem" class="sem__loading"><div class="sem__ring"></div></div>

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
              <div v-if="dia.tareas.length" class="sem__col-count">{{ dia.tareas.length }}</div>
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
                <span v-if="t.asignada_a" class="sem__asig" :title="t.asignada_a.nombre">
                  {{ t.asignada_a.nombre.split(' ').map(p => p[0]).join('').slice(0, 2).toUpperCase() }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ── MIS TAREAS (kanban 2 cols) ──────────────────────────── -->
    <div class="cvd__section cvd__section--tablero">
      <div class="cvd__section-head">
        <span class="cvd__section-dot cvd__section-dot--tablero"></span>
        <h2 class="cvd__section-title">Mis tareas</h2>
      </div>

      <div class="tv__kanban-cols cvd__kanban-2">
        <!-- Pendientes -->
        <div class="tv__col">
          <div class="tv__col-header tv__col-header--pending">
            <span>Pendientes</span>
            <span class="tv__col-count">{{ tareasPendientes.length }}</span>
          </div>
          <div class="tv__col-body">
            <div
              v-for="t in tareasPendientes"
              :key="t.id"
              class="cvd__tc"
              @click="abrirTarea(t)"
            >
              <span class="cvd__tc-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
              <div class="cvd__tc-info">
                <span class="cvd__tc-titulo">{{ t.titulo }}</span>
                <span v-if="t.sala" class="cvd__tc-meta">{{ t.sala.nombre }}</span>
              </div>
              <span v-if="t.fecha_programada && esPasado(t.fecha_programada)" class="cvd__tc-vencida" title="Vencida">⚠️</span>
            </div>
            <div v-if="!tareasPendientes.length" class="tv__col-empty">Sin pendientes ✓</div>
          </div>
        </div>

        <!-- Finalizadas -->
        <div class="tv__col">
          <div class="tv__col-header tv__col-header--done">
            <span>Finalizadas</span>
            <span class="tv__col-count">{{ tareasFinalizadas.length }}</span>
          </div>
          <div class="tv__col-body">
            <div
              v-for="t in tareasFinalizadas"
              :key="t.id"
              class="cvd__tc cvd__tc--done"
              @click="abrirTarea(t)"
            >
              <span class="cvd__tc-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
              <div class="cvd__tc-info">
                <span class="cvd__tc-titulo">{{ t.titulo }}</span>
                <span v-if="t.sala" class="cvd__tc-meta">{{ t.sala.nombre }}</span>
              </div>
            </div>
            <div v-if="!tareasFinalizadas.length" class="tv__col-empty">Nada finalizado aún</div>
          </div>
        </div>
      </div>
    </div>

    <!-- ── MIS SALAS ──────────────────────────────────────────── -->
    <div class="cvd__section cvd__section--salas">
      <div class="cvd__section-head">
        <span class="cvd__section-dot cvd__section-dot--salas"></span>
        <h2 class="cvd__section-title">Mis salas</h2>
        <DsBadge variant="leaf">{{ salas.length }}</DsBadge>
      </div>
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

    <!-- Footer -->
    <footer class="cvd__footer">
      <LeafHerbarium :size="12" />
      Cultivo Espacial · {{ club.name }}
    </footer>

  </div>

  <!-- ── PANEL DETALLE TAREA ────────────────────────────────────── -->
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
              <span class="tv__estado-pill" :style="estadoMeta(tareaDetalle.estado)">{{ tareaDetalle.estado?.replace('_', ' ') }}</span>
            </div>
            <div class="tv__panel-row">
              <span class="tv__panel-key">Prioridad</span>
              <span>{{ tareaDetalle.prioridad }}</span>
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
          </div>

          <div class="tv__panel-actions">
            <!-- Finalizar: visible si no está completada -->
            <button
              v-if="tareaDetalle.estado !== 'completada'"
              class="tv__panel-btn tv__panel-btn--primary"
              :disabled="guardandoAccion"
              @click="finalizarTarea"
            >
              <i class="bi bi-check-circle-fill"></i>
              {{ guardandoAccion ? 'Guardando…' : 'Finalizada' }}
            </button>
            <!-- Sin finalizar: visible solo si está completada -->
            <button
              v-if="tareaDetalle.estado === 'completada'"
              class="tv__panel-btn tv__panel-btn--ghost"
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

  <!-- Sheet registrar lectura -->
  <RegistrarLecturaSheet v-model="lecturaOpen" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore }    from '../../stores/auth'
import { useClubStore }    from '../../stores/club'
import { useTareasStore }  from '../../stores/tareas'
import { useSalasStore }   from '../../stores/salas'
import { useLotesStore }   from '../../stores/lotes'
import { useAmbienteStore } from '../../stores/ambiente'
import { useAlertasBell }  from '../../composables/useAlertasBell.js'
import { useToast }        from '../../composables/useToast.js'
import { storeToRefs }     from 'pinia'
import { getTareasSemana } from '../../lib/api.js'
import { formatFechaLarga } from '../../utils/fecha.js'

import DsCard     from '../../design-system/components/Card.vue'
import DsStat     from '../../design-system/components/Stat.vue'
import DsBadge    from '../../design-system/components/Badge.vue'
import DsBanner   from '../../design-system/components/Banner.vue'
import DsEmpty    from '../../design-system/components/EmptyState.vue'
import DsSkeleton from '../../design-system/components/Skeleton.vue'
import LeafHerbarium from '../../design-system/icons/LeafHerbarium.vue'
import SalaCard   from '../cultivador/SalaCard.vue'
import RegistrarLecturaSheet from '../cultivador/RegistrarLecturaSheet.vue'
import { LayoutGrid, Sprout, GitBranch, AlertTriangle } from 'lucide-vue-next'

const auth        = useAuthStore()
const club        = useClubStore()
const tareasStore = useTareasStore()
const salasStore  = useSalasStore()
const lotesStore  = useLotesStore()
const ambienteStore = useAmbienteStore()

const { dashboard, kanban } = storeToRefs(tareasStore)
const toast = useToast()
useAlertasBell()

const loading      = ref(true)
const lecturaOpen  = ref(false)
const semana       = ref({ desde: null, hasta: null, dias: [] })
const loadingSem   = ref(false)
const tareaDetalle = ref(null)
const guardandoAccion = ref(false)

// ── Semana navigation ──────────────────────────────────────────
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

function esDiaHoy(fecha) { return fecha === new Date().toISOString().slice(0, 10) }
function esPasado(fecha)  { return fecha < new Date().toISOString().slice(0, 10) }

// ── Tipo helpers ───────────────────────────────────────────────
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

// ── Kanban ─────────────────────────────────────────────────────
const tareasPendientes  = computed(() => [
  ...(kanban.value.pendiente   || []),
  ...(kanban.value.en_progreso || []),
])
const tareasFinalizadas = computed(() => kanban.value.completada || [])

// ── Saludo / fecha ─────────────────────────────────────────────
const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = (() => {
  const d = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
  return d.charAt(0).toUpperCase() + d.slice(1).toLowerCase()
})()

// ── Salas ──────────────────────────────────────────────────────
const salas        = computed(() => salasStore.items || [])
const salasActivas = computed(() => salas.value.filter(s => s.state === 'activa'))
function salaNombre(salaId) {
  return salas.value.find(s => String(s.id) === String(salaId))?.nombre || `Sala #${salaId}`
}

// ── KPIs ───────────────────────────────────────────────────────
const totalPlantas = computed(() => salas.value.reduce((acc, s) => acc + (s.plantas_totales || 0), 0))
const plantasVeg   = computed(() => lotesStore.items.filter(l => l.estado === 'vegetativo').reduce((a, l) => a + (l.plants_count || 0), 0))
const plantasFlor  = computed(() => lotesStore.items.filter(l => l.estado === 'floracion').reduce((a, l) => a + (l.plants_count || 0), 0))
const lotesEnCiclo = computed(() => lotesStore.items.filter(l => ['vegetativo', 'floracion', 'secado'].includes(l.estado)).length)
const lotesListos  = computed(() => lotesStore.items.filter(l => l.puede_transicionar === true).length)
const notifCount      = computed(() => ambienteStore.alertasCount)
const alertasCriticas = computed(() => ambienteStore.alertasActivas.filter(a => ['temperatura', 'co2'].includes(a.tipo)))

// ── Acciones de tarea ──────────────────────────────────────────
function abrirTarea(t) { tareaDetalle.value = t }

async function finalizarTarea() {
  if (!tareaDetalle.value) return
  guardandoAccion.value = true
  try {
    await tareasStore.completar(tareaDetalle.value.id, null, '')
    await tareasStore.fetchKanban({})
    await cargarSemana()
    tareaDetalle.value = null
    toast.success('Tarea finalizada')
  } catch (e) {
    toast.error(e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'No se pudo finalizar la tarea')
  } finally { guardandoAccion.value = false }
}

async function revertirTarea() {
  if (!tareaDetalle.value) return
  guardandoAccion.value = true
  try {
    await tareasStore.update(tareaDetalle.value.id, { estado: 'pendiente' })
    await tareasStore.fetchKanban({})
    await cargarSemana()
    tareaDetalle.value = null
    toast.success('Tarea marcada como pendiente')
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo actualizar la tarea')
  } finally { guardandoAccion.value = false }
}

function onRegistrarDesdeSala() { lecturaOpen.value = true }

// ── Load ───────────────────────────────────────────────────────
onMounted(async () => {
  try {
    await Promise.all([
      salasStore.fetch(),
      lotesStore.fetch(),
      tareasStore.fetchDashboard(),
      tareasStore.fetchKanban({}),
    ])
  } catch {} finally { loading.value = false }
  cargarSemana()
})
</script>

<style scoped>
.cvd {
  max-width: 1280px;
  margin: 0 auto;
  padding: var(--sp-8) var(--sp-8) var(--sp-8);
  font-family: var(--font-ui);
}
@media (max-width: 767px) {
  .cvd { padding: var(--sp-4); padding-bottom: 80px; }
}

/* Header */
.cvd__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: var(--sp-6);
  flex-wrap: wrap;
}
.cvd__header-text { display: flex; flex-direction: column; gap: 4px; }
.cvd__saludo {
  font-family: var(--font-display);
  font-size: var(--fs-32);
  font-weight: 500;
  color: var(--c-ink-900);
  margin: 0;
  line-height: var(--lh-tight);
}
@media (max-width: 767px) { .cvd__saludo { font-size: var(--fs-24); } }
.cvd__fecha {
  font-family: var(--font-mono);
  font-size: var(--fs-13);
  color: var(--c-ink-500);
}
.cvd__banner { margin-bottom: var(--sp-4); }
.cvd__banner-link { font-size: var(--fs-13); font-weight: 600; text-decoration: underline; color: inherit; }

/* KPIs */
.cvd__kpi-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--sp-4);
  margin-bottom: var(--sp-6);
}
@media (max-width: 1023px) { .cvd__kpi-row { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 640px)  { .cvd__kpi-row { grid-template-columns: 1fr 1fr; gap: var(--sp-3); } }
.cvd__kpi-card {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  padding: var(--sp-4) !important;
}
.cvd__kpi-ico {
  width: 36px; height: 36px;
  border-radius: var(--r-md);
  background: var(--c-leaf-50);
  color: var(--c-role-cultivador);
  display: flex; align-items: center; justify-content: center;
}
.cvd__kpi-ico--amber { background: var(--c-amber-100); color: var(--c-amber-500); }
.cvd__kpi-ico--rust  { background: var(--c-rust-100);  color: var(--c-rust-600); }
.cvd__kpi-sub { font-size: var(--fs-12); color: var(--c-ink-500); }

/* Sections */
.cvd__section {
  margin-bottom: var(--sp-6);
  background: var(--c-paper);
  border: 1px solid var(--c-ink-100);
  border-radius: var(--r-2xl);
  padding: var(--sp-5) var(--sp-6);
  border-top-width: 3px;
}
@media (max-width: 767px) { .cvd__section { padding: var(--sp-4); } }
.cvd__section--semana  { border-top-color: var(--c-role-cultivador); }
.cvd__section--tablero { border-top-color: #6366f1; }
.cvd__section--salas   { border-top-color: #f59e0b; }

.cvd__section-head {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
.cvd__section-dot {
  width: 10px; height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}
.cvd__section-dot--semana  { background: var(--c-role-cultivador); }
.cvd__section-dot--tablero { background: #6366f1; }
.cvd__section-dot--salas   { background: #f59e0b; }
.cvd__section-title {
  font-family: var(--font-display);
  font-size: var(--fs-18);
  font-weight: 500;
  color: var(--c-ink-900);
  margin: 0;
}

/* Salas */
.cvd__salas-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: var(--sp-6);
}
@media (max-width: 767px) { .cvd__salas-grid { grid-template-columns: 1fr; gap: var(--sp-4); } }

/* Footer */
.cvd__footer {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  font-family: var(--font-mono);
  font-size: var(--fs-12);
  color: var(--c-ink-500);
  padding-top: var(--sp-6);
  border-top: 1px solid var(--c-ink-100);
}

/* ── Semana (same as TareasView) ────────────────────────────── */
.tv__semana { padding: .25rem 0; }

.sem__nav { display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }
.sem__nav-btn { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 8px; width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: #64748b; transition: all .15s; }
.sem__nav-btn:hover { border-color: #94a3b8; color: #0f172a; }
.sem__nav-label { flex: 1; text-align: center; font-size: .9rem; font-weight: 700; color: #0f172a; }
.sem__hoy-btn { background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .3rem .75rem; font-size: .78rem; font-weight: 600; color: #475569; cursor: pointer; }
.sem__hoy-btn:hover { background: #e2e8f0; }
.sem__loading { display: flex; justify-content: center; padding: 3rem; }
.sem__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: cvd-spin .7s linear infinite; }
@keyframes cvd-spin { to { transform: rotate(360deg); } }

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
.sem__asig { width: 18px; height: 18px; border-radius: 50%; background: #e0e7ff; color: #4338ca; font-size: .6rem; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }

/* ── Kanban 2 cols ────────────────────────────────────────────── */
.tv__kanban-cols { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }
.cvd__kanban-2  { grid-template-columns: 1fr 1fr; }
@media (max-width: 640px) { .cvd__kanban-2 { grid-template-columns: 1fr; } }

.tv__col { background: #f8fafc; border-radius: 12px; overflow: hidden; }
.tv__col-header { display: flex; align-items: center; justify-content: space-between; padding: .65rem .875rem; font-size: .75rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; }
.tv__col-header--pending { background: rgba(100,116,139,.08); color: #475569; }
.tv__col-header--done    { background: rgba(21,128,61,.1);   color: #15803d; }
.tv__col-count { font-size: .7rem; font-weight: 700; background: rgba(0,0,0,.06); padding: .15em .5em; border-radius: 5px; }
.tv__col-body { padding: .75rem; min-height: 100px; max-height: 65vh; overflow-y: auto; display: flex; flex-direction: column; gap: .5rem; }
.tv__col-empty { text-align: center; color: #94a3b8; font-size: .82rem; padding: 1.5rem 0; }

/* Tarea card (kanban) */
.cvd__tc {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .55rem .7rem;
  border-radius: 8px;
  background: #fff;
  border: 1px solid #e2e8f0;
  cursor: pointer;
  transition: box-shadow .12s, border-color .12s;
}
.cvd__tc:hover { box-shadow: 0 2px 8px rgba(0,0,0,.07); border-color: #94a3b8; }
.cvd__tc--done { opacity: .6; }
.cvd__tc-emoji { font-size: .9rem; flex-shrink: 0; }
.cvd__tc-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; }
.cvd__tc-titulo { font-size: .82rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cvd__tc-meta   { font-size: .7rem; color: #94a3b8; }
.cvd__tc-vencida { font-size: .7rem; flex-shrink: 0; }

/* ── Panel detalle tarea ─────────────────────────────────────── */
.tv__panel-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.35); z-index: 1040; display: flex; justify-content: flex-end; }
.tv__panel { width: min(420px, 100vw); height: 100%; background: #fff; display: flex; flex-direction: column; box-shadow: -8px 0 32px rgba(0,0,0,.12); animation: cvd-slide .2s ease; }
@keyframes cvd-slide { from { transform: translateX(100%); } to { transform: translateX(0); } }
.tv__panel-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem; border-bottom: 1px solid #f1f5f9; }
.tv__panel-title { font-size: .95rem; font-weight: 700; margin: 0; }
.tv__panel-close { background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; }
.tv__panel-close:hover { background: #e2e8f0; }
.tv__panel-body { padding: 1.5rem; flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 1rem; }
.tv__tipo-pill { display: inline-flex; align-items: center; gap: .35rem; background: #e8f5e9; color: #1b5e20; font-size: .75rem; font-weight: 700; padding: .25em .75em; border-radius: 6px; }
.tv__panel-nombre { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.03em; }
.tv__panel-desc { font-size: .85rem; color: #64748b; margin: 0; line-height: 1.6; }
.tv__panel-info { border: 1px solid #f1f5f9; border-radius: 10px; overflow: hidden; }
.tv__panel-row { display: flex; justify-content: space-between; align-items: center; padding: .65rem 1rem; border-bottom: 1px solid #f8fafc; font-size: .82rem; }
.tv__panel-row:last-child { border-bottom: none; }
.tv__panel-key { color: #94a3b8; font-size: .72rem; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; }
.tv__panel-link { color: #1b5e20; text-decoration: none; font-weight: 600; }
.tv__estado-pill { font-size: .7rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; text-transform: capitalize; }
.tv__panel-actions { display: flex; flex-direction: column; gap: .5rem; padding-top: .5rem; }
.tv__panel-btn { display: flex; align-items: center; justify-content: center; gap: .5rem; padding: .65rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; border: none; transition: all .15s; }
.tv__panel-btn:disabled { opacity: .6; cursor: not-allowed; }
.tv__panel-btn--primary { background: #1b5e20; color: #fff; }
.tv__panel-btn--primary:not(:disabled):hover { background: #144a18; }
.tv__panel-btn--ghost { background: #f8fafc; color: #475569; border: 1.5px solid #e2e8f0; }
.tv__panel-btn--ghost:not(:disabled):hover { background: #e2e8f0; }
</style>
