<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getSuperAdminStats } from '../../lib/api.js'

const router  = useRouter()
const loading = ref(true)
const stats   = ref(null)
const search     = ref('')
const filterPlan = ref('todos')

const PLAN_META = {
  semilla:    { label: 'Semilla',    color: '#64748b', bg: '#f1f5f9' },
  brote:      { label: 'Brote',      color: '#15803d', bg: '#dcfce7' },
  cosecha:    { label: 'Cosecha',    color: '#0369a1', bg: '#dbeafe' },
  federacion: { label: 'Federación', color: '#7c3aed', bg: '#ede9fe' },
}
function planMeta(p) { return PLAN_META[p] || PLAN_META.semilla }

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

const clubsFiltrados = computed(() => {
  if (!stats.value?.clubs) return []
  let list = stats.value.clubs
  if (filterPlan.value !== 'todos') list = list.filter(c => c.plan === filterPlan.value)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(c =>
      c.name?.toLowerCase().includes(q) ||
      c.slug?.toLowerCase().includes(q) ||
      c.city?.toLowerCase().includes(q) ||
      c.email?.toLowerCase().includes(q)
    )
  }
  return list
})

onMounted(async () => {
  try {
    const { data } = await getSuperAdminStats()
    stats.value = data
  } catch (e) {
    console.error(e)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="sad">

    <!-- Header -->
    <div class="sad__header">
      <div>
        <div class="sad__eyebrow">Vista global</div>
        <h1 class="sad__title">Dashboard</h1>
        <p class="sad__sub">{{ new Date().toLocaleDateString('es-AR', { weekday:'long', day:'numeric', month:'long', year:'numeric' }) }}</p>
      </div>
      <button class="sad__btn-primary" @click="router.push({ name: 'sa-club-nuevo' })">
        <i class="bi bi-plus-lg"></i>
        Nuevo club
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="sad__loading">
      <div class="sad__ring"></div>
      <span>Cargando datos globales…</span>
    </div>

    <template v-else-if="stats">

      <!-- KPIs globales -->
      <div class="sad__kpis">
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(27,94,32,.1);color:#15803d">
            <i class="bi bi-building"></i>
          </div>
          <div class="sad__kpi-val">{{ stats.resumen.total_clubs }}</div>
          <div class="sad__kpi-lbl">Clubs activos</div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
            <i class="bi bi-people"></i>
          </div>
          <div class="sad__kpi-val">{{ stats.resumen.total_usuarios }}</div>
          <div class="sad__kpi-lbl">Usuarios totales</div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(124,58,237,.1);color:#7c3aed">
            <i class="bi bi-heart-pulse"></i>
          </div>
          <div class="sad__kpi-val">{{ stats.resumen.total_pacientes }}</div>
          <div class="sad__kpi-lbl">Pacientes</div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(21,128,61,.1);color:#15803d">
            <i class="bi bi-flower2"></i>
          </div>
          <div class="sad__kpi-val">{{ stats.resumen.total_plantas }}</div>
          <div class="sad__kpi-lbl">Plantas activas</div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(180,83,9,.1);color:#b45309">
            <i class="bi bi-boxes"></i>
          </div>
          <div class="sad__kpi-val">{{ stats.resumen.total_lotes }}</div>
          <div class="sad__kpi-lbl">Lotes</div>
        </div>
        <div class="sad__kpi" :class="stats.clubs_trial > 0 ? 'sad__kpi--warn' : ''">
          <div class="sad__kpi-icon" :style="stats.clubs_trial > 0 ? 'background:rgba(180,83,9,.1);color:#b45309' : 'background:rgba(15,23,42,.06);color:#475569'">
            <i class="bi bi-clock-history"></i>
          </div>
          <div class="sad__kpi-val" :style="stats.clubs_trial > 0 ? 'color:#b45309' : ''">{{ stats.clubs_trial }}</div>
          <div class="sad__kpi-lbl">En trial</div>
        </div>
      </div>

      <!-- Distribución por plan -->
      <div class="sad__section-label">Distribución por plan</div>
      <div class="sad__planes">
        <div v-for="(count, plan) in stats.por_plan" :key="plan" class="sad__plan-card"
             :style="{ borderColor: planMeta(plan).color + '40' }">
          <div class="sad__plan-badge" :style="{ background: planMeta(plan).bg, color: planMeta(plan).color }">
            {{ planMeta(plan).label }}
          </div>
          <div class="sad__plan-count">{{ count }}</div>
          <div class="sad__plan-lbl">{{ count === 1 ? 'club' : 'clubs' }}</div>
          <div class="sad__plan-bar-wrap">
            <div class="sad__plan-bar"
                 :style="{ width: `${Math.round((count / stats.resumen.total_clubs) * 100)}%`, background: planMeta(plan).color }">
            </div>
          </div>
          <div class="sad__plan-pct">{{ Math.round((count / stats.resumen.total_clubs) * 100) }}%</div>
        </div>
      </div>

      <!-- Buscador + filtros -->
      <div class="sad__section-label">Todos los clubs</div>
      <div class="sad__toolbar">
        <div class="sad__search-wrap">
          <i class="bi bi-search sad__search-icon"></i>
          <input
            v-model="search"
            class="sad__search"
            placeholder="Buscar por nombre, slug, email, ciudad…"
          />
          <span v-if="search" class="sad__search-count">{{ clubsFiltrados.length }}</span>
        </div>
        <div class="sad__plan-filters">
          <button
            v-for="(meta, plan) in { todos: { label: 'Todos', color: '#0f172a', bg: '#f1f5f9' }, ...PLAN_META }"
            :key="plan"
            class="sad__plan-filter"
            :class="{ 'sad__plan-filter--active': filterPlan === plan }"
            :style="filterPlan === plan ? { background: meta.bg, color: meta.color, borderColor: meta.color + '60' } : {}"
            @click="filterPlan = plan"
          >
            {{ meta.label }}
          </button>
        </div>
      </div>

      <!-- Lista de clubs -->
      <div class="sad__clubs">
        <div class="sad__clubs-header">
          <span>Club</span>
          <span>Plan</span>
          <span>Usuarios</span>
          <span>Pacientes</span>
          <span>Lotes</span>
          <span>Creado</span>
          <span></span>
        </div>

        <div v-if="!clubsFiltrados.length" class="sad__empty">
          <i class="bi bi-search" style="font-size:1.5rem;display:block;margin-bottom:.5rem;opacity:.4"></i>
          Sin clubs que coincidan
        </div>

        <RouterLink
          v-for="club in clubsFiltrados"
          :key="club.id"
          :to="{ name: 'sa-club-detail', params: { id: club.id } }"
          class="sad__club-row"
        >
          <div class="sad__club-name-cell">
            <div class="sad__club-avatar">{{ club.name?.[0]?.toUpperCase() }}</div>
            <div>
              <div class="sad__club-name">{{ club.name }}</div>
              <div class="sad__club-slug">{{ club.slug }}</div>
            </div>
          </div>
          <div>
            <span class="sad__plan-pill"
                  :style="{ background: planMeta(club.plan).bg, color: planMeta(club.plan).color }">
              {{ planMeta(club.plan).label }}
              <span v-if="club.plan_trial" class="sad__trial-dot">trial</span>
            </span>
          </div>
          <div class="sad__club-stat">{{ club.usuarios_count }}</div>
          <div class="sad__club-stat">{{ club.pacientes_count }}</div>
          <div class="sad__club-stat">{{ club.lotes_count }}</div>
          <div class="sad__club-date">{{ formatDate(club.created_at) }}</div>
          <div class="sad__club-arrow"><i class="bi bi-arrow-right"></i></div>
        </RouterLink>
      </div>

      <div v-if="clubsFiltrados.length" class="sad__footer">
        {{ clubsFiltrados.length }} club{{ clubsFiltrados.length !== 1 ? 's' : '' }}
        <span v-if="filterPlan !== 'todos' || search"> · filtro activo</span>
      </div>

    </template>
  </div>
</template>

<style scoped>
.sad { padding: 2rem 2rem 3rem; max-width: 1300px; }

.sad__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.sad__eyebrow { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .1em; color: #94a3b8; margin-bottom: .35rem; }
.sad__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.sad__sub { font-size: .83rem; color: #94a3b8; margin: 0; }

.sad__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.sad__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: sad-spin .7s linear infinite; }
@keyframes sad-spin { to { transform: rotate(360deg); } }

.sad__section-label { font-size: .72rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; color: #94a3b8; margin-bottom: .75rem; }

/* KPIs */
.sad__kpis { display: grid; grid-template-columns: repeat(6,1fr); gap: 1rem; margin-bottom: 2rem; }
@media (max-width: 1100px) { .sad__kpis { grid-template-columns: repeat(3,1fr); } }
.sad__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.1rem; display: flex; flex-direction: column; gap: .4rem; }
.sad__kpi--warn { border-color: #fde68a; }
.sad__kpi-icon { width: 36px; height: 36px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: .9rem; }
.sad__kpi-val { font-size: 1.75rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.sad__kpi-lbl { font-size: .7rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; }

/* Planes */
.sad__planes { display: grid; grid-template-columns: repeat(4,1fr); gap: 1rem; margin-bottom: 2rem; }
@media (max-width: 900px) { .sad__planes { grid-template-columns: repeat(2,1fr); } }
.sad__plan-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; display: flex; flex-direction: column; gap: .4rem; }
.sad__plan-badge { display: inline-block; font-size: .72rem; font-weight: 800; padding: .2em .65em; border-radius: 6px; width: fit-content; }
.sad__plan-count { font-size: 2.5rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.05em; margin-top: .25rem; }
.sad__plan-lbl { font-size: .75rem; color: #94a3b8; }
.sad__plan-bar-wrap { height: 4px; background: #f1f5f9; border-radius: 999px; overflow: hidden; margin-top: .5rem; }
.sad__plan-bar { height: 100%; border-radius: 999px; transition: width .4s; }
.sad__plan-pct { font-size: .72rem; font-weight: 600; color: #64748b; }

/* Toolbar buscador + filtros */
.sad__toolbar { display: flex; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; align-items: center; }
.sad__search-wrap { position: relative; flex: 1; min-width: 220px; }
.sad__search-icon { position: absolute; left: .875rem; top: 50%; transform: translateY(-50%); color: #94a3b8; pointer-events: none; font-size: .85rem; }
.sad__search { width: 100%; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .6rem .875rem .6rem 2.4rem; font-size: .875rem; color: #0f172a; box-sizing: border-box; transition: border .15s; }
.sad__search:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sad__search-count { position: absolute; right: .875rem; top: 50%; transform: translateY(-50%); font-size: .72rem; font-weight: 600; color: #94a3b8; }
.sad__plan-filters { display: flex; gap: .4rem; flex-wrap: wrap; }
.sad__plan-filter { padding: .4rem .875rem; border-radius: 8px; border: 1.5px solid #e2e8f0; background: #fff; font-size: .78rem; font-weight: 600; cursor: pointer; color: #64748b; transition: all .15s; }
.sad__plan-filter:hover { border-color: #94a3b8; }
.sad__plan-filter--active { font-weight: 700; }

/* Clubs table */
.sad__clubs { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.sad__clubs-header { display: grid; grid-template-columns: 2fr 1fr 80px 80px 80px 120px 40px; padding: .65rem 1.1rem; font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.sad__club-row { display: grid; grid-template-columns: 2fr 1fr 80px 80px 80px 120px 40px; align-items: center; padding: .875rem 1.1rem; border-bottom: 1px solid #f8fafc; text-decoration: none; color: inherit; transition: background .12s; }
.sad__club-row:last-child { border-bottom: none; }
.sad__club-row:hover { background: #fafbfc; }
.sad__club-name-cell { display: flex; align-items: center; gap: .75rem; }
.sad__club-avatar { width: 36px; height: 36px; border-radius: 9px; background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.15)); color: #1b5e20; font-size: .85rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sad__club-name { font-size: .875rem; font-weight: 700; color: #0f172a; }
.sad__club-slug { font-size: .7rem; color: #94a3b8; font-family: monospace; }
.sad__plan-pill { display: inline-flex; align-items: center; gap: .35rem; font-size: .72rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; }
.sad__trial-dot { font-size: .62rem; font-weight: 600; opacity: .7; }
.sad__club-stat { font-size: .875rem; font-weight: 600; color: #475569; }
.sad__club-date { font-size: .75rem; color: #94a3b8; }
.sad__club-arrow { color: #cbd5e1; font-size: .85rem; text-align: right; transition: color .15s, transform .15s; }
.sad__club-row:hover .sad__club-arrow { color: #0f172a; transform: translateX(2px); }

.sad__empty { padding: 2.5rem; text-align: center; color: #94a3b8; font-size: .875rem; }
.sad__footer { text-align: right; font-size: .75rem; color: #94a3b8; margin-top: .75rem; }

.sad__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s, transform .1s; white-space: nowrap; }
.sad__btn-primary:hover { background: #144a18; transform: translateY(-1px); }
</style>

