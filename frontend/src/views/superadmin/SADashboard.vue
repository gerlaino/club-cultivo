<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { logger } from '../../utils/logger.js'
import { useRouter } from 'vue-router'
import { getSuperAdminStats } from '../../lib/api.js'

const router  = useRouter()
const loading = ref(true)
const stats   = ref(null)

// Se vende por SUITES, no por planes de una tabla vieja. Lo que importa saber de un vistazo
// es cuántos clubes tienen cada cosa —que es lo que se factura— y qué necesita atención.
const SUITE_META = {
  cultivo:             { label: 'Cultivo',  color: '#15803d', bg: '#dcfce7' },
  produccion_dispensa: { label: 'Producción y dispensa', color: '#0369a1', bg: '#dbeafe' },
}
const ADDON_LABEL = {
  bar: 'Buffet', eventos: 'Eventos', medico: 'Médico', iot: 'Ambiente/IoT', ia: 'Asistente IA',
  mailer: 'Correo', whatsapp: 'WhatsApp', web_publica: 'Web pública', ariccame: 'ARICCAME',
}

const clubsActivos    = computed(() => stats.value?.clubs?.filter(c => !c.deleted_at) || [])
const clubsEliminados = computed(() => stats.value?.clubs?.filter(c =>  c.deleted_at) || [])

function pct(n) {
  const total = clubsActivos.value.length
  return total ? Math.round((n / total) * 100) : 0
}

// Los add-ons ordenados por adopción: los que nadie usa quedan al final y se ven apagados.
const addonsOrdenados = computed(() =>
  Object.entries(stats.value?.por_addon || {}).sort((a, b) => b[1] - a[1]))

// Lo accionable. Un dashboard que sólo cuenta totales no dice qué hacer con el día.
const atencion = computed(() => {
  const s = stats.value
  if (!s) return []
  const items = []
  if (s.sin_suites)  items.push({ key: 'sin', count: s.sin_suites, tono: 'crit',
    titulo: 'sin ninguna suite', detalle: 'no pueden trabajar hasta que se les active una',
    to: { name: 'sa-clubs' } })
  if (s.suspendidos) items.push({ key: 'susp', count: s.suspendidos, tono: 'warn',
    titulo: 'suspendidos', detalle: 'sus usuarios no pueden entrar', to: { name: 'sa-clubs' } })
  if (s.clubs_trial) items.push({ key: 'trial', count: s.clubs_trial, tono: 'info',
    titulo: 'en periodo de prueba', detalle: 'hay que pasarlos a pago o darlos de baja',
    to: { name: 'sa-clubs' } })
  if (clubsEliminados.value.length) items.push({ key: 'elim', count: clubsEliminados.value.length,
    tono: 'info', titulo: 'eliminados', detalle: 'se pueden restaurar', to: { name: 'sa-clubs' } })
  return items
})

onMounted(async () => {
  try {
    const { data } = await getSuperAdminStats()
    stats.value = data
  } catch (e) {
    logger.error(e)
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
        <div class="sad__eyebrow">Super Admin</div>
        <h1 class="sad__title">Dashboard global</h1>
        <p class="sad__sub">{{ new Date().toLocaleDateString('es-AR', { weekday:'long', day:'numeric', month:'long', year:'numeric' }) }}</p>
      </div>
      <button class="sad__btn-primary" @click="router.push({ name: 'sa-club-nuevo' })">
        <i class="bi bi-plus-lg"></i> Nuevo club
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="sad__loading">
      <DsSpinner />
    </div>

    <template v-else-if="stats">

      <!-- KPIs -->
      <div class="sad__kpis">
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(27,94,32,.1);color:#15803d"><i class="bi bi-building"></i></div>
          <div>
            <div class="sad__kpi-val">{{ clubsActivos.length }}</div>
            <div class="sad__kpi-lbl">Clubs activos</div>
          </div>
        </div>
        <div class="sad__kpi" v-if="clubsEliminados.length">
          <div class="sad__kpi-icon" style="background:rgba(185,28,28,.08);color:#b91c1c"><i class="bi bi-trash3"></i></div>
          <div>
            <div class="sad__kpi-val" style="color:#b91c1c">{{ clubsEliminados.length }}</div>
            <div class="sad__kpi-lbl">Eliminados</div>
          </div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(3,105,161,.1);color:#0369a1"><i class="bi bi-people"></i></div>
          <div>
            <div class="sad__kpi-val">{{ stats.resumen.total_usuarios }}</div>
            <div class="sad__kpi-lbl">Usuarios</div>
          </div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(124,58,237,.1);color:#7c3aed"><i class="bi bi-heart-pulse"></i></div>
          <div>
            <div class="sad__kpi-val">{{ stats.resumen.total_pacientes }}</div>
            <div class="sad__kpi-lbl">Pacientes</div>
          </div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(21,128,61,.1);color:#15803d"><i class="bi bi-flower2"></i></div>
          <div>
            <div class="sad__kpi-val">{{ stats.resumen.total_plantas }}</div>
            <div class="sad__kpi-lbl">Plantas</div>
          </div>
        </div>
        <div class="sad__kpi">
          <div class="sad__kpi-icon" style="background:rgba(180,83,9,.1);color:#b45309"><i class="bi bi-boxes"></i></div>
          <div>
            <div class="sad__kpi-val">{{ stats.resumen.total_lotes }}</div>
            <div class="sad__kpi-lbl">Lotes</div>
          </div>
        </div>
        <div class="sad__kpi" :class="stats.clubs_trial > 0 ? 'sad__kpi--warn' : ''">
          <div class="sad__kpi-icon" :style="stats.clubs_trial > 0 ? 'background:rgba(180,83,9,.1);color:#b45309' : 'background:rgba(15,23,42,.06);color:#475569'">
            <i class="bi bi-clock-history"></i>
          </div>
          <div>
            <div class="sad__kpi-val" :style="stats.clubs_trial > 0 ? 'color:#b45309' : ''">{{ stats.clubs_trial }}</div>
            <div class="sad__kpi-lbl">En trial</div>
          </div>
        </div>
      </div>

      <!-- Qué necesita que alguien haga algo. Va PRIMERO: un dashboard que sólo cuenta
           totales no dice qué hacer con el día. Si no hay nada pendiente, no ocupa lugar. -->
      <div v-if="atencion.length" class="sad__section">
        <div class="sad__section-header">
          <span class="sad__section-title">Requiere atención</span>
        </div>
        <div class="sad__atencion">
          <button v-for="a in atencion" :key="a.key" class="sad__alerta" :class="`sad__alerta--${a.tono}`"
                  @click="router.push(a.to)">
            <span class="sad__alerta-num">{{ a.count }}</span>
            <span class="sad__alerta-txt">
              <strong>{{ a.titulo }}</strong>
              <span>{{ a.detalle }}</span>
            </span>
            <i class="bi bi-arrow-right"></i>
          </button>
        </div>
      </div>

      <!-- Adopción: qué contrataron y qué están usando de verdad. Es lo que se factura. -->
      <div class="sad__section">
        <div class="sad__section-header">
          <span class="sad__section-title">Suites contratadas</span>
          <span class="sad__section-sub">sobre {{ clubsActivos.length }} club{{ clubsActivos.length === 1 ? '' : 's' }}</span>
        </div>
        <div class="sad__planes">
          <div v-for="(count, k) in (stats.por_suite || {})" :key="k" class="sad__plan-card"
               :style="{ borderColor: (SUITE_META[k]?.color || '#94a3b8') + '30' }">
            <div class="sad__plan-badge" :style="{ background: SUITE_META[k]?.bg, color: SUITE_META[k]?.color }">
              {{ SUITE_META[k]?.label || k }}
            </div>
            <div class="sad__plan-count">{{ count }}</div>
            <div class="sad__plan-pct-wrap">
              <div class="sad__plan-bar-track">
                <div class="sad__plan-bar" :style="{ width: `${pct(count)}%`, background: SUITE_META[k]?.color }"></div>
              </div>
              <span class="sad__plan-pct">{{ pct(count) }}%</span>
            </div>
          </div>
        </div>
      </div>

      <div v-if="addonsOrdenados.length" class="sad__section">
        <div class="sad__section-header">
          <span class="sad__section-title">Módulos adicionales</span>
          <span class="sad__section-sub">cuántos clubes tienen cada uno</span>
        </div>
        <div class="sad__addons">
          <div v-for="[k, count] in addonsOrdenados" :key="k" class="sad__addon"
               :class="{ 'sad__addon--cero': !count }">
            <span class="sad__addon-name">{{ ADDON_LABEL[k] || k }}</span>
            <span class="sad__addon-count">{{ count }}</span>
            <div class="sad__addon-bar-track">
              <div class="sad__addon-bar" :style="{ width: `${pct(count)}%` }"></div>
            </div>
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.sad { padding: 2rem 2.5rem 3rem; }

/* Header */
.sad__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.sad__eyebrow { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .12em; color: var(--c-slate-400); margin-bottom: .3rem; }
.sad__title { font-size: 2rem; font-weight: 800; color: var(--c-slate-900); margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.sad__sub { font-size: .83rem; color: var(--c-slate-400); margin: 0; }

.sad__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

/* KPIs — fila horizontal compacta */
.sad__kpis {
  display: flex; gap: .75rem; margin-bottom: 1.75rem; flex-wrap: wrap;
}
.sad__kpi {
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px;
  padding: .875rem 1rem; display: flex; align-items: center; gap: .875rem;
  flex: 1; min-width: 120px;
}
.sad__kpi--warn { border-color: #fde68a; }
.sad__kpi-icon { width: 36px; height: 36px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: .9rem; flex-shrink: 0; }
.sad__kpi-val { font-size: 1.5rem; font-weight: 800; color: var(--c-slate-900); line-height: 1.1; letter-spacing: -.04em; }
.sad__kpi-lbl { font-size: .65rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-400); }

/* Sections */
.sad__section { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 16px; overflow: hidden; margin-bottom: 1.25rem; }
.sad__section-header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); gap: 1rem; flex-wrap: wrap; }
.sad__section-title { font-size: .78rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; color: var(--c-slate-500); }

/* Plan distribution */
/* Requiere atención */
.sad__atencion { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px,1fr)); gap: .6rem; }
.sad__alerta { display: flex; align-items: center; gap: .85rem; padding: .85rem 1rem; border-radius: 12px; border: 1.5px solid var(--c-slate-200); background: #fff; cursor: pointer; text-align: left; transition: border-color .15s, transform .15s; font: inherit; }
.sad__alerta:hover { transform: translateY(-1px); }
.sad__alerta > i { margin-left: auto; color: var(--c-slate-300); }
.sad__alerta:hover > i { color: var(--c-slate-900); }
.sad__alerta-num { font-size: 1.5rem; font-weight: 800; line-height: 1; min-width: 2ch; }
.sad__alerta-txt { display: flex; flex-direction: column; gap: .1rem; }
.sad__alerta-txt strong { font-size: .85rem; font-weight: 700; color: var(--c-slate-900); }
.sad__alerta-txt span { font-size: .72rem; color: var(--c-slate-500); line-height: 1.4; }
.sad__alerta--crit { border-color: #fecaca; background: #fef2f2; }
.sad__alerta--crit .sad__alerta-num { color: #b91c1c; }
.sad__alerta--warn { border-color: #fde68a; background: #fffbeb; }
.sad__alerta--warn .sad__alerta-num { color: #b45309; }
.sad__alerta--info .sad__alerta-num { color: var(--c-slate-600); }

/* Add-ons */
.sad__addons { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px,1fr)); gap: .5rem; }
.sad__addon { display: grid; grid-template-columns: 1fr auto; gap: .15rem .5rem; padding: .7rem .85rem; border: 1px solid var(--c-slate-100); border-radius: 10px; background: #fff; }
.sad__addon--cero { opacity: .5; }
.sad__addon-name { font-size: .8rem; font-weight: 600; color: var(--c-slate-900); }
.sad__addon-count { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); }
.sad__addon-bar-track { grid-column: 1 / -1; height: 4px; background: var(--c-slate-100); border-radius: 999px; overflow: hidden; margin-top: .35rem; }
.sad__addon-bar { height: 100%; background: #15803d; border-radius: 999px; }
.sad__section-sub { font-size: .72rem; color: var(--c-slate-400); margin-left: .5rem; }

.sad__planes { display: grid; grid-template-columns: repeat(4,1fr); gap: 0; }
@media (max-width: 900px) { /* Requiere atención */
.sad__atencion { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px,1fr)); gap: .6rem; }
.sad__alerta { display: flex; align-items: center; gap: .85rem; padding: .85rem 1rem; border-radius: 12px; border: 1.5px solid var(--c-slate-200); background: #fff; cursor: pointer; text-align: left; transition: border-color .15s, transform .15s; font: inherit; }
.sad__alerta:hover { transform: translateY(-1px); }
.sad__alerta > i { margin-left: auto; color: var(--c-slate-300); }
.sad__alerta:hover > i { color: var(--c-slate-900); }
.sad__alerta-num { font-size: 1.5rem; font-weight: 800; line-height: 1; min-width: 2ch; }
.sad__alerta-txt { display: flex; flex-direction: column; gap: .1rem; }
.sad__alerta-txt strong { font-size: .85rem; font-weight: 700; color: var(--c-slate-900); }
.sad__alerta-txt span { font-size: .72rem; color: var(--c-slate-500); line-height: 1.4; }
.sad__alerta--crit { border-color: #fecaca; background: #fef2f2; }
.sad__alerta--crit .sad__alerta-num { color: #b91c1c; }
.sad__alerta--warn { border-color: #fde68a; background: #fffbeb; }
.sad__alerta--warn .sad__alerta-num { color: #b45309; }
.sad__alerta--info .sad__alerta-num { color: var(--c-slate-600); }

/* Add-ons */
.sad__addons { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px,1fr)); gap: .5rem; }
.sad__addon { display: grid; grid-template-columns: 1fr auto; gap: .15rem .5rem; padding: .7rem .85rem; border: 1px solid var(--c-slate-100); border-radius: 10px; background: #fff; }
.sad__addon--cero { opacity: .5; }
.sad__addon-name { font-size: .8rem; font-weight: 600; color: var(--c-slate-900); }
.sad__addon-count { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); }
.sad__addon-bar-track { grid-column: 1 / -1; height: 4px; background: var(--c-slate-100); border-radius: 999px; overflow: hidden; margin-top: .35rem; }
.sad__addon-bar { height: 100%; background: #15803d; border-radius: 999px; }
.sad__section-sub { font-size: .72rem; color: var(--c-slate-400); margin-left: .5rem; }

.sad__planes { grid-template-columns: repeat(2,1fr); } }
.sad__plan-card { padding: 1.1rem 1.25rem; border-right: 1px solid var(--c-slate-100); display: flex; flex-direction: column; gap: .5rem; }
.sad__plan-card:last-child { border-right: none; }
.sad__plan-badge { display: inline-block; font-size: .72rem; font-weight: 800; padding: .2em .65em; border-radius: 6px; width: fit-content; }
.sad__plan-count { font-size: 2rem; font-weight: 800; color: var(--c-slate-900); line-height: 1; letter-spacing: -.05em; }
.sad__plan-pct-wrap { display: flex; align-items: center; gap: .5rem; }
.sad__plan-bar-track { flex: 1; height: 4px; background: var(--c-slate-100); border-radius: 999px; overflow: hidden; }
.sad__plan-bar { height: 100%; border-radius: 999px; transition: width .4s; }
.sad__plan-pct { font-size: .68rem; font-weight: 600; color: var(--c-slate-500); white-space: nowrap; }

/* Estado tabs */
.sad__estado-tabs { display: flex; gap: .3rem; background: var(--c-slate-100); border-radius: 8px; padding: .25rem; }
.sad__estado-tab { background: none; border: none; padding: .35rem .75rem; border-radius: 6px; font-size: .78rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; transition: all .15s; display: flex; align-items: center; gap: .4rem; }
.sad__estado-tab--active { background: #fff; color: var(--c-slate-900); box-shadow: 0 1px 3px rgba(0,0,0,.08); }
.sad__tab-count { font-size: .7rem; font-weight: 700; background: var(--c-slate-200); color: var(--c-slate-500); padding: .1em .45em; border-radius: 4px; }
.sad__tab-count--danger { background: #fef2f2; color: #b91c1c; }

/* Toolbar */
.sad__toolbar { display: flex; gap: 1rem; padding: 1rem 1.25rem; flex-wrap: wrap; align-items: center; border-bottom: 1px solid var(--c-slate-50); }
.sad__search-wrap { position: relative; flex: 1; min-width: 200px; }
.sad__search-icon { position: absolute; left: .875rem; top: 50%; transform: translateY(-50%); color: var(--c-slate-400); pointer-events: none; font-size: .85rem; }
.sad__search { width: 100%; background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 9px; padding: .55rem .875rem .55rem 2.4rem; font-size: .875rem; color: var(--c-slate-900); box-sizing: border-box; transition: border .15s; }
.sad__search:focus { outline: none; border-color: var(--c-role-superadmin, #1b5e20); box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sad__search-count { position: absolute; right: .875rem; top: 50%; transform: translateY(-50%); font-size: .72rem; font-weight: 600; color: var(--c-slate-400); }
.sad__plan-filters { display: flex; gap: .35rem; flex-wrap: wrap; }
.sad__plan-filter { padding: .35rem .75rem; border-radius: 7px; border: 1.5px solid var(--c-slate-200); background: #fff; font-size: .75rem; font-weight: 600; cursor: pointer; color: var(--c-slate-500); transition: all .15s; }
.sad__plan-filter:hover { border-color: var(--c-slate-400); }
.sad__plan-filter--active { font-weight: 700; }

/* Club table */
.sad__clubs { }
.sad__clubs-header { display: grid; grid-template-columns: 2fr 1fr 70px 80px 60px 110px 36px; padding: .55rem 1.25rem; font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-400); border-bottom: 1px solid var(--c-slate-100); background: #fafbfc; }
.sad__club-row { display: grid; grid-template-columns: 2fr 1fr 70px 80px 60px 110px 36px; align-items: center; padding: .825rem 1.25rem; border-bottom: 1px solid var(--c-slate-50); text-decoration: none; color: inherit; transition: background .12s; }
.sad__club-row:last-child { border-bottom: none; }
.sad__club-row:hover { background: #fafbfc; }
.sad__club-row--deleted { opacity: .65; }
.sad__club-row--deleted:hover { background: #fef2f2; }
.sad__club-name-cell { display: flex; align-items: center; gap: .75rem; }
.sad__club-avatar { width: 34px; height: 34px; border-radius: 9px; background: linear-gradient(135deg, rgba(27,94,32,.15), rgba(3,105,161,.15)); color: var(--c-role-superadmin, #1b5e20); font-size: .82rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.sad__club-avatar--deleted { background: var(--c-slate-100); color: var(--c-slate-400); }
.sad__club-name { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }
.sad__club-slug { font-size: .68rem; color: var(--c-slate-400); font-family: monospace; }
.sad__plan-pill { display: inline-flex; align-items: center; gap: .35rem; font-size: .72rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; }
.sad__trial-dot { font-size: .62rem; font-weight: 600; opacity: .7; }
.sad__club-stat { font-size: .875rem; font-weight: 600; color: var(--c-slate-600); }
.sad__club-date { font-size: .75rem; color: var(--c-slate-400); }
.sad__club-arrow { color: var(--c-slate-300); font-size: .85rem; text-align: right; transition: color .15s, transform .15s; }
.sad__club-row:hover .sad__club-arrow { color: var(--c-slate-900); transform: translateX(2px); }

.sad__empty { padding: 2.5rem; text-align: center; color: var(--c-slate-400); font-size: .875rem; }
.sad__footer { text-align: right; font-size: .75rem; color: var(--c-slate-400); padding: .75rem 1.25rem; border-top: 1px solid var(--c-slate-50); }

.sad__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, var(--c-role-superadmin, #1b5e20)); color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; transition: background .15s, transform .1s; white-space: nowrap; }
.sad__btn-primary:hover { background: #144a18; transform: translateY(-1px); }
</style>
