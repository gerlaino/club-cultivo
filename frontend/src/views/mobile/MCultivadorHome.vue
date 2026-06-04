<template>
  <div class="mc">
    <div class="mc__hero">
      <div class="mc__greeting">Hola, {{ auth.user?.first_name || 'Cultivador' }} 👋</div>
      <div class="mc__date">{{ fechaHoy }}</div>
    </div>

    <!-- KPIs rápidos -->
    <div class="mc__kpis">
      <div class="mc__kpi">
        <div class="mc__kpi-val">{{ salasActivas.length }}</div>
        <div class="mc__kpi-lbl">Salas activas</div>
      </div>
      <div class="mc__kpi">
        <div class="mc__kpi-val">{{ lotesActivos.length }}</div>
        <div class="mc__kpi-lbl">Lotes activos</div>
      </div>
      <div class="mc__kpi">
        <div class="mc__kpi-val">{{ totalPlantas }}</div>
        <div class="mc__kpi-lbl">Plantas</div>
      </div>
    </div>

    <!-- Acciones rápidas -->
    <div class="mc__section-title">Acciones rápidas</div>
    <div class="mc__actions">
      <RouterLink to="/m/cultivador/salas" class="mc__action-card mc__action-card--green">
        <i class="bi bi-grid-3x3-gap"></i>
        <span>Ver salas</span>
      </RouterLink>
      <RouterLink to="/m/cultivador/lotes" class="mc__action-card mc__action-card--blue">
        <i class="bi bi-layers"></i>
        <span>Ver lotes</span>
      </RouterLink>
      <RouterLink to="/m/cultivador/tareas" class="mc__action-card mc__action-card--amber">
        <i class="bi bi-list-check"></i>
        <span>Tareas</span>
      </RouterLink>
    </div>

    <!-- Salas -->
    <div class="mc__section-title">Mis salas</div>
    <div v-if="salasStore.loading" class="mc__loading">Cargando…</div>
    <div v-else-if="!salasActivas.length" class="mc__empty">Sin salas asignadas</div>
    <div v-else class="mc__list">
      <RouterLink
        v-for="sala in salasActivas.slice(0, 5)"
        :key="sala.id"
        :to="`/salas/${sala.id}`"
        class="mc__sala-card"
      >
        <div class="mc__sala-dot" :class="`mc__sala-dot--${sala.kind}`"></div>
        <div class="mc__sala-info">
          <div class="mc__sala-nombre">{{ sala.nombre }}</div>
          <div class="mc__sala-sub">{{ kindLabel(sala.kind) }} · {{ sala.state }}</div>
        </div>
        <i class="bi bi-chevron-right mc__chevron"></i>
      </RouterLink>
    </div>

    <!-- Lotes activos -->
    <div class="mc__section-title">Lotes activos</div>
    <div v-if="!lotesActivos.length" class="mc__empty">Sin lotes activos</div>
    <div v-else class="mc__list">
      <RouterLink
        v-for="lote in lotesActivos.slice(0, 5)"
        :key="lote.id"
        :to="`/lotes/${lote.id}`"
        class="mc__lote-card"
      >
        <div class="mc__lote-estado-dot" :style="{ background: estadoColor(lote.estado) }"></div>
        <div class="mc__lote-info">
          <div class="mc__lote-codigo">{{ lote.codigo }}</div>
          <div class="mc__lote-sub">{{ lote.strain || '—' }} · {{ lote.plants_count }} plantas</div>
        </div>
        <span class="mc__lote-badge" :style="{ background: estadoColor(lote.estado) + '20', color: estadoColor(lote.estado) }">
          {{ estadoLabel(lote.estado) }}
        </span>
        <i class="bi bi-chevron-right mc__chevron"></i>
      </RouterLink>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useAuthStore }  from '../../stores/auth'
import { useSalasStore } from '../../stores/salas'
import { useLotesStore } from '../../stores/lotes'

const auth      = useAuthStore()
const salasStore = useSalasStore()
const lotesStore = useLotesStore()

const fechaHoy = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })

const salasActivas  = computed(() => salasStore.items.filter(s => s.state === 'activa'))
const lotesActivos  = computed(() => lotesStore.items.filter(l => l.estado !== 'finalizado'))
const totalPlantas  = computed(() => lotesActivos.value.reduce((s, l) => s + (l.plants_count || 0), 0))

const ESTADO_COLORS = {
  vegetativo: '#16a34a', floracion: '#9333ea', cosecha: '#dc2626',
  en_manicura: '#d97706', secado: '#d97706', curado: '#2563eb',
  semilla: '#64748b', esqueje: '#0891b2',
}
const ESTADO_LABELS = {
  semilla: 'Semilla', esqueje: 'Esqueje', vegetativo: 'Vegetativo',
  floracion: 'Floración', cosecha: 'Cosecha', en_manicura: 'Manicura',
  secado: 'Secado', curado: 'Curado',
}
const KIND_LABELS = {
  vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Cosecha', manicura: 'Manicura',
}

function estadoColor(e) { return ESTADO_COLORS[e] || '#64748b' }
function estadoLabel(e)  { return ESTADO_LABELS[e] || e || '—' }
function kindLabel(k)    { return KIND_LABELS[k] || k || '—' }

onMounted(async () => {
  await Promise.all([salasStore.fetchAll?.(), lotesStore.fetchAll?.()])
})
</script>

<style scoped>
.mc { padding: 0 0 1rem; }

.mc__hero {
  background: linear-gradient(135deg, #0f2417 0%, #1b5e20 100%);
  padding: 1.25rem 1.25rem 1.5rem;
}
.mc__greeting { font-size: 1.1rem; font-weight: 700; color: #fff; }
.mc__date { font-size: .78rem; color: rgba(255,255,255,.6); margin-top: .15rem; text-transform: capitalize; }

.mc__kpis {
  display: grid; grid-template-columns: repeat(3, 1fr);
  gap: .75rem; padding: 1rem 1rem 0;
  margin-top: -1rem;
}
.mc__kpi {
  background: #fff; border-radius: 12px; padding: .875rem .5rem;
  text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,.06);
}
.mc__kpi-val { font-size: 1.5rem; font-weight: 800; color: #1b5e20; line-height: 1; }
.mc__kpi-lbl { font-size: .65rem; color: #94a3b8; font-weight: 600; margin-top: .2rem; text-transform: uppercase; letter-spacing: .04em; }

.mc__section-title {
  font-size: .7rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .06em;
  padding: 1.25rem 1.25rem .5rem;
}

.mc__actions { display: grid; grid-template-columns: repeat(3, 1fr); gap: .75rem; padding: 0 1rem; }
.mc__action-card {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .4rem; padding: 1rem .5rem; border-radius: 14px;
  text-decoration: none; font-size: .75rem; font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.mc__action-card i { font-size: 1.6rem; }
.mc__action-card--green { background: #f0fdf4; color: #15803d; }
.mc__action-card--blue  { background: #eff6ff; color: #1d4ed8; }
.mc__action-card--amber { background: #fffbeb; color: #b45309; }

.mc__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.mc__loading, .mc__empty { padding: .75rem 1.25rem; color: #94a3b8; font-size: .82rem; }

.mc__sala-card, .mc__lote-card {
  background: #fff; border-radius: 12px; padding: .875rem 1rem;
  display: flex; align-items: center; gap: .75rem;
  text-decoration: none; box-shadow: 0 1px 4px rgba(0,0,0,.05);
  -webkit-tap-highlight-color: transparent;
}
.mc__sala-dot {
  width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0;
}
.mc__sala-dot--vegetativo { background: #16a34a; }
.mc__sala-dot--floracion  { background: #9333ea; }
.mc__sala-dot--cosecha    { background: #dc2626; }
.mc__sala-dot--manicura   { background: #d97706; }

.mc__sala-info, .mc__lote-info { flex: 1; min-width: 0; }
.mc__sala-nombre, .mc__lote-codigo { font-size: .88rem; font-weight: 700; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mc__sala-sub, .mc__lote-sub { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }
.mc__chevron { color: #d4e6d4; font-size: .8rem; flex-shrink: 0; }

.mc__lote-estado-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
.mc__lote-badge { font-size: .65rem; font-weight: 700; padding: .2em .6em; border-radius: 999px; white-space: nowrap; flex-shrink: 0; }
</style>
