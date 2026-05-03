<template>
  <div class="cvd">

    <!-- ── BIENVENIDA ──────────────────────────────────────────── -->
    <div class="cvd__header">
      <div class="cvd__header-text">
        <h1 class="cvd__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <span class="cvd__fecha">{{ hoy }}</span>
      </div>
    </div>

    <!-- Banner alertas críticas -->
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
        <div class="cvd__kpi-ico">
          <Sprout :size="20" :stroke-width="1.75" />
        </div>
        <DsStat label="Plantas a cargo" :value="String(totalPlantas)" />
        <div class="cvd__kpi-sub">{{ plantasVeg }} veg · {{ plantasFlor }} flor</div>
      </DsCard>
      <DsCard variant="elevated" class="cvd__kpi-card">
        <div class="cvd__kpi-ico">
          <LayoutGrid :size="20" :stroke-width="1.75" />
        </div>
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
        <div class="cvd__kpi-sub">
          {{ alertasCriticas.length > 0 ? `${alertasCriticas.length} crítica${alertasCriticas.length !== 1 ? 's' : ''}` : 'sin alertas críticas' }}
        </div>
      </DsCard>
    </div>

    <!-- ── SEMANA DE TAREAS ──────────────────────────────────────── -->
    <section class="cvd__section cvd__section--semana">
      <div class="cvd__section-head">
        <span class="cvd__section-dot cvd__section-dot--semana"></span>
        <h2 class="cvd__section-title">Esta semana</h2>
        <DsBadge variant="leaf">{{ totalTareasSemana }}</DsBadge>
      </div>
      <div v-if="loadingSem" class="cvd__semana">
        <DsCard v-for="i in 7" :key="i" variant="elevated" class="cvd__dia">
          <DsSkeleton variant="line" :rows="2" />
        </DsCard>
      </div>
      <div v-else class="cvd__semana">
        <div
          v-for="dia in semana.dias"
          :key="dia.fecha"
          class="cvd__dia"
          :class="{ 'cvd__dia--hoy': esDiaHoy(dia.fecha), 'cvd__dia--pasado': esPasado(dia.fecha) }"
        >
          <span class="cvd__dia-nombre">{{ diaNombre(dia.fecha) }}</span>
          <span class="cvd__dia-num">{{ diaNum(dia.fecha) }}</span>
          <div class="cvd__dia-chips">
            <span v-for="t in dia.tareas.slice(0, 2)" :key="t.id" class="cvd__tarea-chip" :title="t.titulo">
              {{ t.titulo.length > 18 ? t.titulo.slice(0, 18) + '…' : t.titulo }}
            </span>
            <span v-if="dia.tareas.length > 2" class="cvd__dia-mas">+{{ dia.tareas.length - 2 }} más</span>
            <span v-if="!dia.tareas.length" class="cvd__dia-libre">libre</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ── TABLERO ────────────────────────────────────────────────── -->
    <section class="cvd__section cvd__section--tablero">
      <div class="cvd__section-head">
        <span class="cvd__section-dot cvd__section-dot--tablero"></span>
        <h2 class="cvd__section-title">Mis tareas</h2>
      </div>
      <div class="cvd__kanban">
        <!-- Pendientes (pendiente + en_progreso) -->
        <div class="cvd__kanban-col">
          <div class="cvd__kanban-colhead cvd__kanban-colhead--pending">
            Pendientes
            <span class="cvd__kanban-badge">{{ tareasPendientesTotal }}</span>
          </div>
          <div
            v-for="t in tareasPendientes.slice(0, 8)"
            :key="t.id"
            class="cvd__kanban-card"
            :class="{ 'cvd__kanban-card--selected': tareaSeleccionada?.id === t.id }"
            @click="seleccionarTarea(t, 'finalizar')"
          >
            <span class="cvd__kanban-titulo">{{ t.titulo }}</span>
            <span v-if="t.sala" class="cvd__kanban-meta">{{ t.sala.nombre }}</span>
          </div>
          <div v-if="!tareasPendientes.length" class="cvd__kanban-empty">Sin pendientes ✓</div>
        </div>
        <!-- Completadas -->
        <div class="cvd__kanban-col">
          <div class="cvd__kanban-colhead cvd__kanban-colhead--done">
            Completadas
            <span class="cvd__kanban-badge">{{ (kanban.completada || []).length }}</span>
          </div>
          <div
            v-for="t in (kanban.completada || []).slice(0, 8)"
            :key="t.id"
            class="cvd__kanban-card cvd__kanban-card--done"
            :class="{ 'cvd__kanban-card--selected': tareaSeleccionada?.id === t.id }"
            @click="seleccionarTarea(t, 'revertir')"
          >
            <span class="cvd__kanban-titulo">{{ t.titulo }}</span>
            <span v-if="t.sala" class="cvd__kanban-meta">{{ t.sala.nombre }}</span>
          </div>
          <div v-if="!(kanban.completada || []).length" class="cvd__kanban-empty">Sin completadas aún</div>
        </div>
      </div>
    </section>

    <!-- ── MIS SALAS ──────────────────────────────────────────────── -->
    <section class="cvd__section cvd__section--salas">
      <div class="cvd__section-head">
        <span class="cvd__section-dot cvd__section-dot--salas"></span>
        <h2 class="cvd__section-title">Mis salas</h2>
        <DsBadge variant="leaf">{{ salas.length }}</DsBadge>
      </div>
      <div v-if="loading" class="cvd__salas-grid">
        <DsCard v-for="i in 3" :key="i" variant="elevated">
          <DsSkeleton variant="card" />
        </DsCard>
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
    </section>

    <!-- ── PANEL ACCIÓN TAREA ────────────────────────────────────── -->
    <Teleport to="body">
      <Transition name="cvd-accion">
        <div v-if="tareaSeleccionada" class="cvd__accion-overlay" @click.self="tareaSeleccionada = null">
          <div class="cvd__accion-bar">
            <div class="cvd__accion-info">
              <span class="cvd__accion-titulo">{{ tareaSeleccionada.titulo }}</span>
              <span v-if="tareaSeleccionada.sala" class="cvd__accion-meta">{{ tareaSeleccionada.sala.nombre }}</span>
            </div>
            <div class="cvd__accion-btns">
              <button
                v-if="accionTipo === 'finalizar'"
                class="cvd__accion-btn cvd__accion-btn--ok"
                :disabled="guardandoAccion"
                @click="ejecutarFinalizar"
              >
                <i class="bi bi-check-circle-fill"></i>
                {{ guardandoAccion ? 'Guardando…' : 'Finalizada' }}
              </button>
              <button
                v-if="accionTipo === 'revertir'"
                class="cvd__accion-btn cvd__accion-btn--revert"
                :disabled="guardandoAccion"
                @click="ejecutarRevertir"
              >
                <i class="bi bi-arrow-counterclockwise"></i>
                {{ guardandoAccion ? 'Guardando…' : 'Sin finalizar' }}
              </button>
              <button class="cvd__accion-btn cvd__accion-btn--cancel" @click="tareaSeleccionada = null">
                Cerrar
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Footer -->
    <footer class="cvd__footer">
      <LeafHerbarium :size="12" />
      Cultivo Espacial · {{ club.name }}
    </footer>

  </div>

  <!-- Sheet registrar lectura (botón header) -->
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
import { storeToRefs }     from 'pinia'
import { getTareasSemana } from '../../lib/api.js'

import DsCard     from '../../design-system/components/Card.vue'
import DsStat     from '../../design-system/components/Stat.vue'
import DsBadge    from '../../design-system/components/Badge.vue'
import DsBanner   from '../../design-system/components/Banner.vue'
import DsEmpty    from '../../design-system/components/EmptyState.vue'
import DsSkeleton from '../../design-system/components/Skeleton.vue'
import LeafHerbarium from '../../design-system/icons/LeafHerbarium.vue'
import SalaCard   from '../cultivador/SalaCard.vue'
import RegistrarLecturaSheet from '../cultivador/RegistrarLecturaSheet.vue'

import {
  LayoutGrid, Sprout, GitBranch, AlertTriangle,
} from 'lucide-vue-next'

const auth        = useAuthStore()
const club        = useClubStore()
const tareasStore = useTareasStore()
const salasStore  = useSalasStore()
const lotesStore  = useLotesStore()
const ambienteStore = useAmbienteStore()

const { dashboard, kanban } = storeToRefs(tareasStore)
useAlertasBell()

const loading          = ref(true)
const lecturaOpen      = ref(false)
const semana           = ref({ dias: [] })
const loadingSem       = ref(false)
const tareaSeleccionada = ref(null)
const accionTipo        = ref(null)  // 'finalizar' | 'revertir'
const guardandoAccion   = ref(false)

// ── Saludo / fecha ─────────────────────────────────────────────
const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = (() => {
  const d = new Date().toLocaleDateString('es-AR', { weekday:'long', day:'numeric', month:'long', year:'numeric' })
  return d.charAt(0).toUpperCase() + d.slice(1).toLowerCase()
})()

// ── Salas ──────────────────────────────────────────────────────
const salas        = computed(() => salasStore.items || [])
const salasActivas = computed(() => salas.value.filter(s => s.state === 'activa'))

function salaNombre(salaId) {
  return salas.value.find(s => String(s.id) === String(salaId))?.nombre || `Sala #${salaId}`
}

// ── KPIs plantas ───────────────────────────────────────────────
const totalPlantas = computed(() => salas.value.reduce((acc, s) => acc + (s.plantas_totales || 0), 0))
const plantasVeg   = computed(() => {
  const lotesVeg = lotesStore.items.filter(l => l.estado === 'vegetativo')
  return lotesVeg.reduce((acc, l) => acc + (l.plants_count || 0), 0)
})
const plantasFlor  = computed(() => {
  const lotesFlor = lotesStore.items.filter(l => l.estado === 'floracion')
  return lotesFlor.reduce((acc, l) => acc + (l.plants_count || 0), 0)
})

// ── KPIs lotes ─────────────────────────────────────────────────
const lotesEnCiclo = computed(() =>
  lotesStore.items.filter(l => ['vegetativo', 'floracion', 'secado'].includes(l.estado)).length
)
const lotesListos  = computed(() =>
  lotesStore.items.filter(l => l.puede_transicionar === true).length
)

// ── KPIs alertas ───────────────────────────────────────────────
const notifCount     = computed(() => ambienteStore.alertasCount)
const alertasCriticas = computed(() =>
  ambienteStore.alertasActivas.filter(a => ['temperatura', 'co2'].includes(a.tipo))
)

// ── Tareas ─────────────────────────────────────────────────────
const tareasPendientes     = computed(() => [
  ...(kanban.value.pendiente  || []),
  ...(kanban.value.en_progreso || []),
])
const tareasPendientesTotal = computed(() => tareasPendientes.value.length)

// ── Semana ─────────────────────────────────────────────────────
const totalTareasSemana = computed(() => semana.value.dias?.reduce((s, d) => s + d.tareas.length, 0) || 0)

function lunasActual() {
  const d = new Date()
  const diff = d.getDay() === 0 ? -6 : 1 - d.getDay()
  d.setDate(d.getDate() + diff)
  return d.toISOString().slice(0, 10)
}

function esDiaHoy(fecha) { return fecha === new Date().toISOString().slice(0, 10) }
function esPasado(fecha)  { return fecha < new Date().toISOString().slice(0, 10) }

function diaNombre(fecha) {
  return new Date(fecha + 'T00:00:00').toLocaleDateString('es-AR', { weekday: 'short' }).replace('.', '')
}
function diaNum(fecha) {
  return new Date(fecha + 'T00:00:00').getDate()
}

async function cargarSemana() {
  loadingSem.value = true
  try {
    const { data } = await getTareasSemana(lunasActual())
    semana.value = data
  } catch { /* no crítico */ }
  finally { loadingSem.value = false }
}

// ── Acciones de tarea ──────────────────────────────────────────
function seleccionarTarea(t, tipo) {
  tareaSeleccionada.value = t
  accionTipo.value        = tipo
}

async function ejecutarFinalizar() {
  if (!tareaSeleccionada.value) return
  guardandoAccion.value = true
  try {
    await tareasStore.completar(tareaSeleccionada.value.id, 0, '')
    await tareasStore.fetchKanban({})
    tareaSeleccionada.value = null
  } catch { /* silencioso */ }
  finally { guardandoAccion.value = false }
}

async function ejecutarRevertir() {
  if (!tareaSeleccionada.value) return
  guardandoAccion.value = true
  try {
    await tareasStore.update(tareaSeleccionada.value.id, { estado: 'pendiente' })
    await tareasStore.fetchKanban({})
    tareaSeleccionada.value = null
  } catch { /* silencioso */ }
  finally { guardandoAccion.value = false }
}

// ── Registrar lectura desde SalaCard ──────────────────────────
function onRegistrarDesdeSala(_sala) {
  lecturaOpen.value = true
}

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
  gap: var(--sp-4);
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
  margin-bottom: var(--sp-8);
}
@media (max-width: 1023px) { .cvd__kpi-row { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 640px)  { .cvd__kpi-row { grid-template-columns: 1fr 1fr; gap: var(--sp-3); } }

.cvd__kpi-card {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  padding: var(--sp-4) !important;
  transition: box-shadow var(--t-base), transform var(--t-base);
  cursor: default;
}
@media (hover: hover) {
  .cvd__kpi-card:hover { box-shadow: var(--sh-3) !important; transform: translateY(-2px); }
}
.cvd__kpi-ico {
  width: 36px;
  height: 36px;
  border-radius: var(--r-md);
  background: var(--c-leaf-50);
  color: var(--c-role-cultivador);
  display: flex;
  align-items: center;
  justify-content: center;
}
.cvd__kpi-ico--amber { background: var(--c-amber-100); color: var(--c-amber-500); }
.cvd__kpi-ico--rust  { background: var(--c-rust-100);  color: var(--c-rust-600); }
.cvd__kpi-sub {
  font-size: var(--fs-12);
  color: var(--c-ink-500);
  margin-top: -var(--sp-1);
}

/* Sections */
.cvd__section {
  margin-bottom: var(--sp-6);
  background: var(--c-paper);
  border: 1px solid var(--c-ink-100);
  border-radius: var(--r-2xl);
  padding: var(--sp-5) var(--sp-6);
  border-top-width: 3px;
}
@media (max-width: 767px) { .cvd__section { padding: var(--sp-4); border-radius: var(--r-xl); } }
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
  width: 10px;
  height: 10px;
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
.cvd__salas-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: var(--sp-6);
}
@media (max-width: 767px) {
  .cvd__salas-grid { grid-template-columns: 1fr; gap: var(--sp-4); }
}

.cvd__semana {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: var(--sp-3);
}
@media (max-width: 1023px) { .cvd__semana { grid-template-columns: repeat(4, 1fr); } }
@media (max-width: 640px)  { .cvd__semana { grid-template-columns: repeat(3, 1fr); gap: var(--sp-2); } }

.cvd__dia {
  background: var(--c-paper);
  border: 1.5px solid var(--c-ink-100);
  border-radius: var(--r-lg);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  gap: var(--sp-1);
  min-height: 100px;
}
.cvd__dia--hoy {
  border-color: var(--c-role-cultivador);
  background: color-mix(in srgb, var(--c-role-cultivador) 6%, transparent);
}
.cvd__dia--pasado { opacity: .6; }

.cvd__dia-nombre {
  font-size: var(--fs-11);
  font-weight: 700;
  color: var(--c-ink-500);
  text-transform: uppercase;
  letter-spacing: .04em;
}
.cvd__dia--hoy .cvd__dia-nombre { color: var(--c-role-cultivador); }

.cvd__dia-num {
  font-family: var(--font-display);
  font-size: var(--fs-22);
  font-weight: 700;
  color: var(--c-ink-900);
  line-height: 1;
  margin-bottom: var(--sp-1);
}
.cvd__dia--hoy .cvd__dia-num { color: var(--c-role-cultivador); }

.cvd__dia-chips { display: flex; flex-direction: column; gap: 3px; }
.cvd__tarea-chip {
  font-size: var(--fs-11);
  background: var(--c-leaf-50);
  color: var(--c-role-cultivador);
  border-radius: 4px;
  padding: 2px 5px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cvd__dia-mas  { font-size: var(--fs-11); color: var(--c-ink-400); font-weight: 600; }
.cvd__dia-libre { font-size: var(--fs-11); color: var(--c-ink-300); font-style: italic; }

/* Kanban */
.cvd__kanban {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sp-4);
}
@media (max-width: 640px) { .cvd__kanban { grid-template-columns: 1fr; } }

.cvd__kanban-col {
  background: var(--c-ink-50);
  border-radius: var(--r-lg);
  padding: var(--sp-3);
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  min-height: 160px;
}
.cvd__kanban-colhead {
  font-size: var(--fs-12);
  font-weight: 700;
  letter-spacing: .03em;
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  margin-bottom: var(--sp-1);
  color: var(--c-ink-600);
}
.cvd__kanban-colhead--pending { color: #64748b; }
.cvd__kanban-colhead--done    { color: #15803d; }

.cvd__kanban-badge {
  background: var(--c-paper);
  border-radius: 9px;
  padding: 1px 7px;
  font-size: var(--fs-11);
  color: var(--c-ink-600);
  border: 1px solid var(--c-ink-200);
}

.cvd__kanban-card {
  background: var(--c-paper);
  border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-3);
  display: flex;
  flex-direction: column;
  gap: 2px;
  color: inherit;
  border: 1px solid var(--c-ink-100);
  cursor: pointer;
  transition: box-shadow var(--t-fast), border-color var(--t-fast);
}
.cvd__kanban-card:hover         { box-shadow: var(--sh-1); border-color: var(--c-ink-300); }
.cvd__kanban-card--done         { border-left: 3px solid #15803d; opacity: .75; }
.cvd__kanban-card--selected     { border-color: #6366f1; box-shadow: 0 0 0 2px rgba(99,102,241,.2); opacity: 1 !important; }

.cvd__kanban-titulo { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
.cvd__kanban-meta   { font-size: var(--fs-11); color: var(--c-ink-400); }
.cvd__kanban-empty  { font-size: var(--fs-12); color: var(--c-ink-400); text-align: center; padding: var(--sp-4) 0; }

/* Floating action panel */
.cvd__accion-overlay {
  position: fixed;
  inset: 0;
  z-index: 9000;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  background: rgba(0, 0, 0, .35);
  padding: var(--sp-4);
}
.cvd__accion-bar {
  width: 100%;
  max-width: 540px;
  background: var(--c-paper);
  border-radius: var(--r-2xl);
  padding: var(--sp-5) var(--sp-6);
  display: flex;
  flex-direction: column;
  gap: var(--sp-4);
  box-shadow: var(--sh-4);
}
.cvd__accion-info { display: flex; flex-direction: column; gap: 2px; }
.cvd__accion-titulo { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); }
.cvd__accion-meta   { font-size: var(--fs-13); color: var(--c-ink-500); }
.cvd__accion-btns   { display: flex; gap: var(--sp-3); }
.cvd__accion-btn {
  flex: 1;
  padding: var(--sp-3) var(--sp-4);
  border-radius: var(--r-lg);
  font-size: var(--fs-14);
  font-weight: 600;
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--sp-2);
  transition: opacity var(--t-fast);
}
.cvd__accion-btn:disabled { opacity: .6; cursor: not-allowed; }
.cvd__accion-btn--ok     { background: #15803d; color: #fff; }
.cvd__accion-btn--revert { background: var(--c-ink-100); color: var(--c-ink-700); }
.cvd__accion-btn--cancel { background: transparent; color: var(--c-ink-500); border: 1px solid var(--c-ink-200); flex: 0 0 auto; }
.cvd__accion-btn--ok:not(:disabled):hover     { opacity: .88; }
.cvd__accion-btn--revert:not(:disabled):hover { opacity: .8; }

/* Action transition */
.cvd-accion-enter-active, .cvd-accion-leave-active { transition: opacity .2s, transform .2s; }
.cvd-accion-enter-from, .cvd-accion-leave-to { opacity: 0; }
.cvd-accion-enter-from .cvd__accion-bar, .cvd-accion-leave-to .cvd__accion-bar { transform: translateY(20px); }

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
</style>
