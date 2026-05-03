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
    <section class="cvd__section">
      <div class="cvd__section-head">
        <h2 class="cvd__section-title">Semana</h2>
        <DsBadge variant="leaf">{{ totalTareasSemana }}</DsBadge>
        <RouterLink to="/tareas" class="cvd__ver-todos">Ver en calendario →</RouterLink>
      </div>
      <div v-if="loadingSem" class="cvd__semana">
        <DsCard v-for="i in 7" :key="i" variant="elevated" class="cvd__dia">
          <DsSkeleton variant="line" :rows="2" />
        </DsCard>
      </div>
      <div v-else class="cvd__semana">
        <RouterLink
          v-for="dia in semana.dias"
          :key="dia.fecha"
          to="/tareas"
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
        </RouterLink>
      </div>
    </section>

    <!-- ── KANBAN ─────────────────────────────────────────────────── -->
    <section class="cvd__section">
      <div class="cvd__section-head">
        <h2 class="cvd__section-title">Tablero</h2>
        <RouterLink to="/tareas" class="cvd__ver-todos">Kanban completo →</RouterLink>
      </div>
      <div class="cvd__kanban">
        <!-- Pendiente -->
        <div class="cvd__kanban-col">
          <div class="cvd__kanban-colhead cvd__kanban-colhead--pending">
            Pendiente <span class="cvd__kanban-badge">{{ kanban.pendiente?.length || 0 }}</span>
          </div>
          <RouterLink
            v-for="t in (kanban.pendiente || []).slice(0, 5)"
            :key="t.id"
            to="/tareas"
            class="cvd__kanban-card"
          >
            <span class="cvd__kanban-titulo">{{ t.titulo }}</span>
            <span v-if="t.sala" class="cvd__kanban-meta">{{ t.sala.nombre }}</span>
          </RouterLink>
          <div v-if="!kanban.pendiente?.length" class="cvd__kanban-empty">Sin pendientes ✓</div>
        </div>
        <!-- En progreso -->
        <div class="cvd__kanban-col">
          <div class="cvd__kanban-colhead cvd__kanban-colhead--progress">
            En progreso <span class="cvd__kanban-badge">{{ kanban.en_progreso?.length || 0 }}</span>
          </div>
          <RouterLink
            v-for="t in (kanban.en_progreso || []).slice(0, 5)"
            :key="t.id"
            to="/tareas"
            class="cvd__kanban-card cvd__kanban-card--progress"
          >
            <span class="cvd__kanban-titulo">{{ t.titulo }}</span>
            <span v-if="t.sala" class="cvd__kanban-meta">{{ t.sala.nombre }}</span>
          </RouterLink>
          <div v-if="!kanban.en_progreso?.length" class="cvd__kanban-empty">Nada en curso</div>
        </div>
        <!-- Completadas hoy -->
        <div class="cvd__kanban-col">
          <div class="cvd__kanban-colhead cvd__kanban-colhead--done">
            Completadas hoy <span class="cvd__kanban-badge">{{ tareasHoy.filter(t => t.estado === 'completada').length }}</span>
          </div>
          <RouterLink
            v-for="t in tareasHoy.filter(t => t.estado === 'completada').slice(0, 5)"
            :key="t.id"
            to="/tareas"
            class="cvd__kanban-card cvd__kanban-card--done"
          >
            <span class="cvd__kanban-titulo">{{ t.titulo }}</span>
            <span v-if="t.sala" class="cvd__kanban-meta">{{ t.sala.nombre }}</span>
          </RouterLink>
          <div v-if="!tareasHoy.filter(t => t.estado === 'completada').length" class="cvd__kanban-empty">Sin completadas aún</div>
        </div>
      </div>
    </section>

    <!-- ── MIS SALAS ──────────────────────────────────────────────── -->
    <section class="cvd__section">
      <div class="cvd__section-head">
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

const loading     = ref(true)
const lecturaOpen = ref(false)
const semana      = ref({ dias: [] })
const loadingSem  = ref(false)

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
const tareasHoy = computed(() => dashboard.value?.hoy || [])

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

/* Salas */
.cvd__section { margin-bottom: var(--sp-8); }
.cvd__section-head {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
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

/* Semana de tareas */
.cvd__ver-todos {
  font-size: var(--fs-13);
  color: var(--c-role-cultivador);
  text-decoration: none;
  font-weight: 600;
  margin-left: auto;
}
.cvd__ver-todos:hover { text-decoration: underline; }

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
  cursor: pointer;
  text-decoration: none;
  color: inherit;
  transition: border-color var(--t-fast), box-shadow var(--t-fast);
}
.cvd__dia:hover { border-color: var(--c-role-cultivador); box-shadow: var(--sh-1); }
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
  grid-template-columns: repeat(3, 1fr);
  gap: var(--sp-4);
}
@media (max-width: 767px) { .cvd__kanban { grid-template-columns: 1fr; } }

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
.cvd__kanban-colhead--pending  { color: #64748b; }
.cvd__kanban-colhead--progress { color: #d97706; }
.cvd__kanban-colhead--done     { color: #15803d; }

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
  text-decoration: none;
  color: inherit;
  border: 1px solid var(--c-ink-100);
  transition: box-shadow var(--t-fast);
}
.cvd__kanban-card:hover { box-shadow: var(--sh-1); }
.cvd__kanban-card--progress { border-left: 3px solid #d97706; }
.cvd__kanban-card--done     { border-left: 3px solid #15803d; opacity: .7; }

.cvd__kanban-titulo { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
.cvd__kanban-meta   { font-size: var(--fs-11); color: var(--c-ink-400); }
.cvd__kanban-empty  { font-size: var(--fs-12); color: var(--c-ink-400); text-align: center; padding: var(--sp-4) 0; }

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
