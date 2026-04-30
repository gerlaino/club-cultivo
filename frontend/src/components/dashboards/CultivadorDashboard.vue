<template>
  <div class="cvd">

    <!-- ── BIENVENIDA ──────────────────────────────────────────── -->
    <div class="cvd__header">
      <div class="cvd__header-text">
        <h1 class="cvd__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <span class="cvd__fecha">{{ hoy }}</span>
      </div>
      <button class="cvd__cta" @click="lecturaOpen = true">
        <Gauge :size="18" :stroke-width="1.75" />
        Registrar lectura
      </button>
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

    <!-- ── MIS SALAS (Trello-like) ─────────────────────────────── -->
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

    <!-- ── GRID 2 COLUMNAS ─────────────────────────────────────── -->
    <div class="cvd__grid2">

      <!-- Mis lotes -->
      <DsCard variant="outlined" class="cvd__lotes-card">
        <div class="cvd__lotes-head">
          <span class="cvd__lotes-title">Mis lotes</span>
          <div class="cvd__lotes-head-right">
            <DsBadge variant="leaf">{{ lotesStore.items.length }}</DsBadge>
            <RouterLink to="/lotes" class="cvd__ver-todos">Ver todos →</RouterLink>
          </div>
        </div>
        <DsEmpty
          v-if="!loading && lotesStore.items.length === 0"
          title="Sin lotes activos en tus salas"
          class="cvd__lotes-empty"
        />
        <div v-else class="cvd__lotes-list">
          <RouterLink
            v-for="l in lotesOrdenados.slice(0, 8)"
            :key="l.id"
            :to="{ name: 'lote-detail', params: { id: l.id } }"
            class="cvd__lote-row"
          >
            <div class="cvd__lote-left">
              <span class="cvd__lote-codigo">{{ l.codigo }}</span>
              <span class="cvd__lote-sala">{{ salaNombre(l.sala_id) }}</span>
            </div>
            <div class="cvd__lote-right">
              <DsBadge :variant="estadoBadgeVariant(l.estado)" size="sm">{{ estadoLabel(l.estado) }}</DsBadge>
              <span class="cvd__lote-dias">{{ l.dias_desde_inicio != null ? `${l.dias_desde_inicio}d` : '—' }}</span>
            </div>
          </RouterLink>
          <DsSkeleton v-if="loading" variant="line" :rows="4" />
        </div>
      </DsCard>

      <!-- Tareas de hoy -->
      <DsCard variant="outlined" class="cvd__tareas-card">
        <div class="cvd__tareas-head">
          <span class="cvd__tareas-title">Tareas de hoy</span>
          <DsBadge v-if="tareasHoy.length > 0" variant="amber">{{ tareasHoy.length }}</DsBadge>
        </div>
        <DsEmpty
          v-if="!loading && tareasHoy.length === 0"
          title="Todo al día — sin tareas para hoy"
          class="cvd__tareas-empty"
        />
        <div v-else class="cvd__tareas-list">
          <div
            v-for="t in tareasHoy.slice(0, 5)"
            :key="t.id"
            class="cvd__tarea-row"
          >
            <DsBadge :variant="prioridadVariant(t.prioridad)" size="sm">{{ t.prioridad }}</DsBadge>
            <div class="cvd__tarea-info">
              <span class="cvd__tarea-titulo">{{ t.titulo }}</span>
              <span v-if="t.sala" class="cvd__tarea-sala">{{ t.sala.nombre }}</span>
            </div>
          </div>
          <DsSkeleton v-if="loading" variant="line" :rows="3" />
        </div>
      </DsCard>

    </div>

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
  Gauge, LayoutGrid, Sprout, GitBranch, AlertTriangle,
} from 'lucide-vue-next'

const auth        = useAuthStore()
const club        = useClubStore()
const tareasStore = useTareasStore()
const salasStore  = useSalasStore()
const lotesStore  = useLotesStore()
const ambienteStore = useAmbienteStore()

const { dashboard } = storeToRefs(tareasStore)
useAlertasBell()

const loading     = ref(true)
const lecturaOpen = ref(false)

// ── Saludo / fecha ─────────────────────────────────────────────
const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = (() => {
  const d = new Date().toLocaleDateString('es-AR', { weekday:'long', day:'numeric', month:'long', year:'numeric' })
  return d.charAt(0).toUpperCase() + d.slice(1)
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

// ── Lotes ──────────────────────────────────────────────────────
const ESTADO_LABEL   = { planificacion:'Planific.', vegetativo:'Vegetativo', floracion:'Floración', secado:'Secado', cosechado:'Cosechado', finalizado:'Finalizado' }
const ESTADO_VARIANT = { vegetativo:'leaf', floracion:'gold', secado:'sky', cosechado:'ink', planificacion:'ink', finalizado:'ink' }
function estadoLabel(e)        { return ESTADO_LABEL[e]   || e || '—' }
function estadoBadgeVariant(e) { return ESTADO_VARIANT[e] || 'ink' }

const lotesOrdenados = computed(() =>
  [...lotesStore.items]
    .filter(l => ['vegetativo','floracion','secado'].includes(l.estado))
    .sort((a, b) => {
      const dA = a.fecha_inicio ? new Date(a.fecha_inicio).getTime() : 0
      const dB = b.fecha_inicio ? new Date(b.fecha_inicio).getTime() : 0
      return dA - dB  // más viejos primero
    })
)

// ── Tareas ─────────────────────────────────────────────────────
const tareasHoy = computed(() => dashboard.value?.hoy || [])
const PRIORIDAD_VARIANT = { urgente:'rust', alta:'amber', normal:'sky', baja:'leaf' }
function prioridadVariant(p) { return PRIORIDAD_VARIANT[p] || 'ink' }

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
    ])
  } catch {} finally { loading.value = false }
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
.cvd__cta {
  display: inline-flex;
  align-items: center;
  gap: var(--sp-2);
  height: 44px;
  padding: 0 var(--sp-5);
  background: var(--c-role-cultivador);
  color: #fff;
  border: none;
  border-radius: var(--r-lg);
  font-size: var(--fs-14);
  font-weight: 600;
  cursor: pointer;
  transition: opacity var(--t-fast);
  white-space: nowrap;
}
.cvd__cta:hover { opacity: 0.9; }
@media (max-width: 767px) { .cvd__cta { display: none; } }

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

/* Grid 2 columnas */
.cvd__grid2 {
  display: grid;
  grid-template-columns: 7fr 5fr;
  gap: var(--sp-6);
  margin-bottom: var(--sp-8);
}
@media (max-width: 1023px) { .cvd__grid2 { grid-template-columns: 1fr; } }

/* Lotes card */
.cvd__lotes-card { padding: var(--sp-4) !important; }
.cvd__lotes-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--sp-4);
  gap: var(--sp-3);
}
.cvd__lotes-head-right { display: flex; align-items: center; gap: var(--sp-3); }
.cvd__lotes-title {
  font-family: var(--font-display);
  font-size: var(--fs-18);
  font-weight: 500;
  color: var(--c-ink-900);
}
.cvd__ver-todos {
  font-size: var(--fs-13);
  color: var(--c-role-cultivador);
  text-decoration: none;
  font-weight: 600;
}
.cvd__ver-todos:hover { text-decoration: underline; }
.cvd__lotes-empty { padding: var(--sp-4) 0; }
.cvd__lotes-list { display: flex; flex-direction: column; }

.cvd__lote-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  border-radius: var(--r-md);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
  min-height: 40px;
}
.cvd__lote-row:hover { background: var(--c-leaf-50); }
.cvd__lote-left { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
.cvd__lote-codigo { font-family: var(--font-mono); font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); }
.cvd__lote-sala   { font-size: var(--fs-12); color: var(--c-ink-500); }
.cvd__lote-right  { display: flex; align-items: center; gap: var(--sp-2); flex-shrink: 0; }
.cvd__lote-dias   { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); }

/* Tareas card */
.cvd__tareas-card { padding: var(--sp-4) !important; }
.cvd__tareas-head {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  margin-bottom: var(--sp-4);
}
.cvd__tareas-title {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 500;
  color: var(--c-ink-900);
}
.cvd__tareas-empty { padding: var(--sp-3) 0; }
.cvd__tareas-list  { display: flex; flex-direction: column; gap: var(--sp-2); }

.cvd__tarea-row {
  display: flex;
  align-items: flex-start;
  gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  border-radius: var(--r-md);
  transition: background var(--t-fast);
}
.cvd__tarea-row:hover { background: var(--c-leaf-50); }
.cvd__tarea-info { flex: 1; min-width: 0; }
.cvd__tarea-titulo { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); display: block; }
.cvd__tarea-sala   { font-size: var(--fs-12); color: var(--c-ink-500); }

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
