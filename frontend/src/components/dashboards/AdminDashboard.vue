<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api, { listSedes, getContableDashboard, getTareasDashboard } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import PlantDistributionChart from '../charts/PlantDistributionChart.vue'
import OnboardingWizard from '../OnboardingWizard.vue'

const auth   = useAuthStore()
const club   = useClubStore()
const router = useRouter()

const stats    = ref({})
const sedes    = ref([])
const contable = ref(null)
const tareas   = ref(null)
const loading  = ref(true)

const mostrarOnboarding = computed(() => !loading.value && sedes.value.length === 0)

const hora     = new Date().getHours()
const saludo   = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy      = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const mesLabel = new Date().toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })

const fmt = (n) => new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0, maximumFractionDigits: 0 }).format(n || 0)

function fmtCompacto(n) {
  if (!n) return '$0'
  const abs = Math.abs(n)
  if (abs >= 1_000_000) return (n < 0 ? '-' : '') + '$' + (abs / 1_000_000).toFixed(1) + 'M'
  if (abs >= 1_000)     return (n < 0 ? '-' : '') + '$' + (abs / 1_000).toFixed(0) + 'k'
  return fmt(n)
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}

const alertas = computed(() => {
  const list = []
  const v = stats.value.vencimientos || 0
  if (v > 0) list.push({ level: 'danger', icon: 'bi-patch-exclamation-fill', msg: `${v} paciente${v !== 1 ? 's' : ''} con REPROCANN vencido`, action: { label: 'Ver pacientes', to: '/socios' } })
  const tv = tareas.value?.stats?.vencidas || 0
  if (tv > 0) list.push({ level: 'warning', icon: 'bi-clock-history', msg: `${tv} tarea${tv !== 1 ? 's' : ''} vencida${tv !== 1 ? 's' : ''} sin completar`, action: { label: 'Ver tareas', to: '/tareas' } })
  return list
})

const TIPO_META = {
  produccion: { label: 'Producción',  color: '#15803d', bg: 'rgba(21,128,61,.08)',   icon: 'bi-flower2' },
  social:     { label: 'Dispensario', color: '#0369a1', bg: 'rgba(3,105,161,.08)',   icon: 'bi-shop' },
  mixta:      { label: 'Mixta',       color: '#7c3aed', bg: 'rgba(124,58,237,.08)', icon: 'bi-arrow-left-right' },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion }

const tareasUrgentes = computed(() => {
  if (!tareas.value) return []
  return [...(tareas.value.vencidas || []), ...(tareas.value.hoy || [])].slice(0, 6)
})

const PRIORIDAD_META = {
  alta:   { color: '#dc2626', bg: '#fef2f2', label: 'Alta' },
  normal: { color: '#0369a1', bg: '#eff6ff', label: 'Normal' },
  baja:   { color: '#64748b', bg: '#f1f5f9', label: 'Baja' },
}
function prioMeta(p) { return PRIORIDAD_META[p] || PRIORIDAD_META.normal }

onMounted(async () => {
  try {
    const [statsRes, sedesRes, contableRes, tareasRes] = await Promise.allSettled([
      api.get('/stats'),
      listSedes(),
      getContableDashboard(),
      getTareasDashboard(),
    ])
    if (statsRes.status    === 'fulfilled') stats.value    = statsRes.value.data
    if (sedesRes.status    === 'fulfilled') sedes.value    = sedesRes.value.data || []
    if (contableRes.status === 'fulfilled') contable.value = contableRes.value.data
    if (tareasRes.status   === 'fulfilled') tareas.value   = tareasRes.value.data
  } finally {
    loading.value = false
  }
})

async function onOnboardingCompletado() {
  const res = await listSedes()
  sedes.value = res.data || []
}
</script>

<template>
  <div class="ad">

    <!-- Onboarding fullscreen — aparece cuando no hay sedes -->
    <OnboardingWizard v-if="mostrarOnboarding" @completado="onOnboardingCompletado" />

    <!-- Header -->
    <div class="ad__header">
      <div class="ad__header-left">
        <div class="ad__eyebrow">
          <span class="ad__eyebrow-dot"></span>
          Panel de gestión
        </div>
        <h1 class="ad__title">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <p class="ad__sub">{{ hoy }}</p>
      </div>
      <div class="ad__header-actions">
        <RouterLink to="/socios/nuevo" class="ad__btn-secondary">
          <i class="bi bi-person-plus"></i> Nuevo paciente
        </RouterLink>
        <RouterLink to="/preferencias" class="ad__btn-ghost">
          <i class="bi bi-gear"></i>
        </RouterLink>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="ad__loading">
      <div class="ad__ring"></div>
      <span>Cargando datos del club…</span>
    </div>

    <template v-else>

      <!-- Alertas -->
      <div v-if="alertas.length" class="ad__alertas">
        <div v-for="(a, i) in alertas" :key="i" class="ad__alerta" :class="`ad__alerta--${a.level}`">
          <i :class="['bi', a.icon, 'ad__alerta-icon']"></i>
          <span class="ad__alerta-msg">{{ a.msg }}</span>
          <RouterLink :to="a.action.to" class="ad__alerta-action">{{ a.action.label }} →</RouterLink>
        </div>
      </div>

      <!-- KPIs -->
      <div class="ad__kpis">
        <RouterLink to="/salas" class="ad__kpi ad__kpi--link">
          <div class="ad__kpi-icon" style="background:rgba(21,128,61,.1);color:#15803d"><i class="bi bi-flower2"></i></div>
          <div class="ad__kpi-body">
            <div class="ad__kpi-val">{{ (stats.vegetativo || 0) + (stats.floracion || 0) }}</div>
            <div class="ad__kpi-lbl">Plantas en ciclo</div>
          </div>
          <div class="ad__kpi-sub">
            <span style="color:#15803d">{{ stats.vegetativo || 0 }} veg</span>
            <span style="color:#9333ea"> · {{ stats.floracion || 0 }} flor</span>
          </div>
        </RouterLink>

        <RouterLink to="/socios" class="ad__kpi ad__kpi--link">
          <div class="ad__kpi-icon" style="background:rgba(3,105,161,.1);color:#0369a1"><i class="bi bi-people"></i></div>
          <div class="ad__kpi-body">
            <div class="ad__kpi-val">{{ stats.socios || 0 }}</div>
            <div class="ad__kpi-lbl">Pacientes activos</div>
          </div>
          <div v-if="stats.vencimientos" class="ad__kpi-sub" style="color:#b45309">{{ stats.vencimientos }} REPROCANN por vencer</div>
        </RouterLink>

        <RouterLink to="/salas" class="ad__kpi ad__kpi--link">
          <div class="ad__kpi-icon" style="background:rgba(124,58,237,.1);color:#7c3aed"><i class="bi bi-boxes"></i></div>
          <div class="ad__kpi-body">
            <div class="ad__kpi-val">{{ stats.lotes || 0 }}</div>
            <div class="ad__kpi-lbl">Lotes activos</div>
          </div>
          <div class="ad__kpi-sub">{{ stats.salas || 0 }} salas</div>
        </RouterLink>

        <RouterLink to="/contabilidad" class="ad__kpi ad__kpi--link" :class="(contable?.mes_actual?.balance || 0) >= 0 ? 'ad__kpi--ok' : 'ad__kpi--danger'">
          <div class="ad__kpi-icon" :style="(contable?.mes_actual?.balance || 0) >= 0 ? 'background:rgba(21,128,61,.1);color:#15803d' : 'background:rgba(220,38,38,.1);color:#dc2626'"><i class="bi bi-bar-chart-line"></i></div>
          <div class="ad__kpi-body">
            <div class="ad__kpi-val" :style="(contable?.mes_actual?.balance || 0) >= 0 ? 'color:#15803d' : 'color:#dc2626'">{{ fmtCompacto(contable?.mes_actual?.balance || 0) }}</div>
            <div class="ad__kpi-lbl">Balance {{ mesLabel }}</div>
          </div>
          <div class="ad__kpi-sub">
            <span style="color:#15803d">↓ {{ fmtCompacto(contable?.mes_actual?.ingresos || 0) }}</span>
            <span style="color:#dc2626"> · ↑ {{ fmtCompacto(contable?.mes_actual?.egresos || 0) }}</span>
          </div>
        </RouterLink>

        <RouterLink to="/tareas" class="ad__kpi ad__kpi--link" :class="(tareas?.stats?.vencidas || 0) > 0 ? 'ad__kpi--danger' : (tareas?.stats?.pendientes || 0) > 0 ? 'ad__kpi--warn' : ''">
          <div class="ad__kpi-icon" :style="(tareas?.stats?.vencidas || 0) > 0 ? 'background:rgba(220,38,38,.1);color:#dc2626' : 'background:rgba(180,83,9,.1);color:#b45309'"><i class="bi bi-clipboard-check"></i></div>
          <div class="ad__kpi-body">
            <div class="ad__kpi-val">{{ tareas?.stats?.pendientes || 0 }}</div>
            <div class="ad__kpi-lbl">Tareas pendientes</div>
          </div>
          <div class="ad__kpi-sub">
            <span v-if="tareas?.stats?.vencidas" style="color:#dc2626">{{ tareas.stats.vencidas }} vencida{{ tareas.stats.vencidas !== 1 ? 's' : '' }}</span>
            <span v-else style="color:#64748b">{{ tareas?.stats?.en_progreso || 0 }} en progreso</span>
          </div>
        </RouterLink>

        <RouterLink to="/usuarios" class="ad__kpi ad__kpi--link">
          <div class="ad__kpi-icon" style="background:rgba(15,23,42,.06);color:#475569"><i class="bi bi-person-badge"></i></div>
          <div class="ad__kpi-body">
            <div class="ad__kpi-val">{{ stats.salas || 0 }}</div>
            <div class="ad__kpi-lbl">Salas activas</div>
          </div>
          <div class="ad__kpi-sub">{{ sedes.length }} sede{{ sedes.length !== 1 ? 's' : '' }}</div>
        </RouterLink>
      </div>

      <!-- Layout -->
      <div class="ad__layout">

        <div class="ad__col ad__col--main">

          <!-- Sedes -->
          <div class="ad__card">
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-icon" style="background:rgba(27,94,32,.1);color:#1b5e20"><i class="bi bi-building"></i></span>
                <span class="ad__card-title">Sedes operativas</span>
                <span class="ad__pill">{{ sedes.length }}</span>
              </div>
              <RouterLink to="/sedes" class="ad__card-link">Gestionar →</RouterLink>
            </div>
            <div v-if="!sedes.length" class="ad__empty">
              <i class="bi bi-building-slash ad__empty-icon"></i>
              <p>Sin sedes configuradas</p>
            </div>
            <div v-else class="ad__sedes">
              <RouterLink v-for="sede in sedes" :key="sede.id" :to="{ name: 'sede-detail', params: { id: sede.id } }" class="ad__sede">
                <div class="ad__sede-stripe" :style="{ background: tipoMeta(sede.tipo).color }"></div>
                <div class="ad__sede-icon" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
                  <i :class="['bi', tipoMeta(sede.tipo).icon]"></i>
                </div>
                <div class="ad__sede-info">
                  <div class="ad__sede-nombre">{{ sede.nombre }}</div>
                  <div class="ad__sede-meta">
                    <span>{{ tipoMeta(sede.tipo).label }}</span>
                    <span class="ad__meta-dot">·</span>
                    <span>{{ sede.salas_count }} sala{{ sede.salas_count !== 1 ? 's' : '' }}</span>
                    <span v-if="sede.ciudad" class="ad__meta-dot">·</span>
                    <span v-if="sede.ciudad">{{ sede.ciudad }}</span>
                  </div>
                </div>
                <div v-if="sede.declarada_reprocann" class="ad__sede-reprocann">
                  <i class="bi bi-patch-check-fill" style="color:#15803d"></i>
                </div>
                <i class="bi bi-arrow-right ad__sede-arrow"></i>
              </RouterLink>
            </div>
          </div>

          <!-- Distribución plantas -->
          <div class="ad__card ad__card--mt" v-if="stats.vegetativo || stats.floracion">
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-icon" style="background:rgba(21,128,61,.1);color:#15803d"><i class="bi bi-pie-chart"></i></span>
                <span class="ad__card-title">Distribución del cultivo</span>
              </div>
            </div>
            <div class="ad__card-body"><PlantDistributionChart :data="stats" /></div>
          </div>

        </div>

        <div class="ad__col ad__col--side">

          <!-- Acciones rápidas -->
          <div class="ad__card">
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-icon" style="background:rgba(15,23,42,.06);color:#0f172a"><i class="bi bi-lightning-charge"></i></span>
                <span class="ad__card-title">Acciones rápidas</span>
              </div>
            </div>
            <div class="ad__actions">
              <RouterLink to="/socios/nuevo" class="ad__action">
                <div class="ad__action-icon" style="background:rgba(3,105,161,.08);color:#0369a1"><i class="bi bi-person-plus"></i></div>
                <div class="ad__action-body"><div class="ad__action-label">Nuevo paciente</div><div class="ad__action-hint">Registrar en el club</div></div>
                <i class="bi bi-arrow-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/contabilidad" class="ad__action">
                <div class="ad__action-icon" style="background:rgba(21,128,61,.08);color:#15803d"><i class="bi bi-cash-stack"></i></div>
                <div class="ad__action-body"><div class="ad__action-label">Registrar movimiento</div><div class="ad__action-hint">Ingreso o egreso</div></div>
                <i class="bi bi-arrow-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/tareas" class="ad__action">
                <div class="ad__action-icon" style="background:rgba(124,58,237,.08);color:#7c3aed"><i class="bi bi-clipboard-plus"></i></div>
                <div class="ad__action-body"><div class="ad__action-label">Nueva tarea</div><div class="ad__action-hint">Asignar al equipo</div></div>
                <i class="bi bi-arrow-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/informe-semestral" class="ad__action">
                <div class="ad__action-icon" style="background:rgba(180,83,9,.08);color:#b45309"><i class="bi bi-file-earmark-text"></i></div>
                <div class="ad__action-body"><div class="ad__action-label">Informe REPROCANN</div><div class="ad__action-hint">Semestral para el Estado</div></div>
                <i class="bi bi-arrow-right ad__action-arrow"></i>
              </RouterLink>
            </div>
          </div>

          <!-- Tareas urgentes -->
          <div class="ad__card ad__card--mt" v-if="tareasUrgentes.length">
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-icon" style="background:rgba(180,83,9,.1);color:#b45309"><i class="bi bi-clock-history"></i></span>
                <span class="ad__card-title">Tareas urgentes</span>
                <span class="ad__pill ad__pill--warn">{{ tareasUrgentes.length }}</span>
              </div>
              <RouterLink to="/tareas" class="ad__card-link">Ver todas →</RouterLink>
            </div>
            <div class="ad__tareas">
              <RouterLink v-for="t in tareasUrgentes" :key="t.id" to="/tareas" class="ad__tarea">
                <div class="ad__tarea-prio" :style="{ background: prioMeta(t.prioridad).bg, color: prioMeta(t.prioridad).color }">{{ prioMeta(t.prioridad).label }}</div>
                <div class="ad__tarea-body">
                  <div class="ad__tarea-titulo">{{ t.titulo }}</div>
                  <div class="ad__tarea-meta">
                    <span v-if="t.sala_nombre">{{ t.sala_nombre }}</span>
                    <span v-if="t.fecha_programada" class="ad__meta-dot">·</span>
                    <span v-if="t.fecha_programada" :style="new Date(t.fecha_programada) < new Date() ? 'color:#dc2626;font-weight:600' : ''">{{ formatDate(t.fecha_programada) }}</span>
                  </div>
                </div>
              </RouterLink>
            </div>
          </div>

          <!-- Últimos movimientos -->
          <div class="ad__card ad__card--mt" v-if="contable?.ultimos_movimientos?.length">
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1"><i class="bi bi-receipt"></i></span>
                <span class="ad__card-title">Últimos movimientos</span>
              </div>
              <RouterLink to="/contabilidad" class="ad__card-link">Ver libro →</RouterLink>
            </div>
            <div class="ad__movs">
              <div v-for="m in contable.ultimos_movimientos.slice(0, 5)" :key="m.id" class="ad__mov">
                <div class="ad__mov-icon" :style="m.tipo === 'ingreso' ? 'background:rgba(21,128,61,.1);color:#15803d' : 'background:rgba(220,38,38,.1);color:#dc2626'">
                  <i :class="m.tipo === 'ingreso' ? 'bi bi-arrow-down' : 'bi bi-arrow-up'"></i>
                </div>
                <div class="ad__mov-body">
                  <div class="ad__mov-desc">{{ m.descripcion }}</div>
                  <div class="ad__mov-meta">{{ m.categoria }} · {{ formatDate(m.fecha) }}</div>
                </div>
                <div class="ad__mov-monto" :style="m.tipo === 'ingreso' ? 'color:#15803d' : 'color:#dc2626'">
                  {{ m.tipo === 'ingreso' ? '+' : '-' }}{{ fmtCompacto(m.monto_ars) }}
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.ad { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; }
@media (max-width: 768px) { .ad { padding: 1.25rem 1rem 2rem; } }

.ad__header { display: flex; align-items: flex-end; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.ad__eyebrow { display: flex; align-items: center; gap: .4rem; font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .1em; color: var(--brand-accent, #66bb6a); margin-bottom: .35rem; }
.ad__eyebrow-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--brand-accent, #66bb6a); animation: ad-pulse 2s ease-in-out infinite; }
@keyframes ad-pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.4;transform:scale(.7)} }
.ad__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; letter-spacing: -.04em; line-height: 1; }
.ad__sub { font-size: .83rem; color: #64748b; margin: 0; text-transform: capitalize; }
.ad__header-actions { display: flex; gap: .6rem; align-items: center; }

.ad__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.ad__ring { width: 22px; height: 22px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: ad-spin .7s linear infinite; }
@keyframes ad-spin { to { transform: rotate(360deg); } }

.ad__alertas { display: flex; flex-direction: column; gap: .5rem; margin-bottom: 1.5rem; }
.ad__alerta { display: flex; align-items: center; gap: .75rem; padding: .75rem 1rem; border-radius: 10px; font-size: .875rem; font-weight: 500; }
.ad__alerta--danger  { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.ad__alerta--warning { background: #fffbeb; border: 1px solid #fde68a; color: #b45309; }
.ad__alerta-icon { font-size: 1rem; flex-shrink: 0; }
.ad__alerta-msg { flex: 1; }
.ad__alerta-action { font-size: .78rem; font-weight: 700; color: inherit; text-decoration: none; opacity: .8; white-space: nowrap; }
.ad__alerta-action:hover { opacity: 1; text-decoration: underline; }

.ad__kpis { display: grid; grid-template-columns: repeat(6, 1fr); gap: 1rem; margin-bottom: 1.75rem; }
@media (max-width: 1100px) { .ad__kpis { grid-template-columns: repeat(3,1fr); } }
@media (max-width: 640px)  { .ad__kpis { grid-template-columns: repeat(2,1fr); } }
.ad__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1rem 1rem .875rem; display: flex; flex-direction: column; gap: .4rem; text-decoration: none; color: inherit; transition: box-shadow .15s, transform .12s, border-color .15s; }
.ad__kpi--link:hover { box-shadow: 0 4px 16px rgba(0,0,0,.07); transform: translateY(-1px); border-color: #cbd5e1; }
.ad__kpi--ok     { border-color: #bbf7d0; }
.ad__kpi--warn   { border-color: #fde68a; }
.ad__kpi--danger { border-color: #fecaca; }
.ad__kpi-icon { width: 36px; height: 36px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: .9rem; flex-shrink: 0; }
.ad__kpi-val { font-size: 1.75rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.ad__kpi-lbl { font-size: .7rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; }
.ad__kpi-sub { font-size: .72rem; font-weight: 500; color: #64748b; }

.ad__layout { display: grid; grid-template-columns: 1fr 340px; gap: 1.25rem; align-items: start; }
@media (max-width: 1050px) { .ad__layout { grid-template-columns: 1fr; } }
.ad__col { display: flex; flex-direction: column; }
.ad__card--mt { margin-top: 1.25rem; }

.ad__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.ad__card-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; }
.ad__card-title-wrap { display: flex; align-items: center; gap: .6rem; }
.ad__card-icon { width: 30px; height: 30px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: .8rem; flex-shrink: 0; }
.ad__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; }
.ad__card-link { font-size: .78rem; font-weight: 600; color: #0369a1; text-decoration: none; white-space: nowrap; }
.ad__card-link:hover { text-decoration: underline; }
.ad__card-body { padding: 1rem 1.1rem; }
.ad__pill { font-size: .65rem; font-weight: 800; background: #f1f5f9; color: #475569; padding: .15em .5em; border-radius: 999px; }
.ad__pill--warn { background: #fffbeb; color: #b45309; }

.ad__empty { text-align: center; padding: 2.5rem 1rem; color: #94a3b8; }
.ad__empty-icon { font-size: 2rem; display: block; margin-bottom: .75rem; }
.ad__empty p { font-size: .85rem; margin: 0 0 .75rem; }

.ad__sedes { display: flex; flex-direction: column; }
.ad__sede { display: flex; align-items: center; gap: .75rem; padding: .875rem 1.1rem; border-bottom: 1px solid #f8fafc; text-decoration: none; color: inherit; transition: background .12s; }
.ad__sede:last-child { border-bottom: none; }
.ad__sede:hover { background: #fafbfc; }
.ad__sede-stripe { width: 3px; height: 36px; border-radius: 999px; flex-shrink: 0; }
.ad__sede-icon { width: 36px; height: 36px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: .9rem; flex-shrink: 0; }
.ad__sede-info { flex: 1; min-width: 0; }
.ad__sede-nombre { font-size: .875rem; font-weight: 700; color: #0f172a; }
.ad__sede-meta { font-size: .72rem; color: #94a3b8; margin-top: .1rem; display: flex; align-items: center; gap: .35rem; }
.ad__meta-dot { color: #e2e8f0; }
.ad__sede-reprocann { font-size: .85rem; flex-shrink: 0; }
.ad__sede-arrow { color: #cbd5e1; font-size: .8rem; flex-shrink: 0; transition: color .15s, transform .15s; }
.ad__sede:hover .ad__sede-arrow { color: #0f172a; transform: translateX(2px); }

.ad__actions { display: flex; flex-direction: column; }
.ad__action { display: flex; align-items: center; gap: .75rem; padding: .75rem 1.1rem; text-decoration: none; color: inherit; border-bottom: 1px solid #f8fafc; transition: background .12s; }
.ad__action:last-child { border-bottom: none; }
.ad__action:hover { background: #fafbfc; }
.ad__action-icon { width: 34px; height: 34px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: .875rem; flex-shrink: 0; }
.ad__action-body { flex: 1; }
.ad__action-label { font-size: .85rem; font-weight: 700; color: #0f172a; }
.ad__action-hint { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }
.ad__action-arrow { color: #cbd5e1; font-size: .8rem; transition: color .15s, transform .15s; }
.ad__action:hover .ad__action-arrow { color: #0f172a; transform: translateX(2px); }

.ad__tareas { display: flex; flex-direction: column; }
.ad__tarea { display: flex; align-items: flex-start; gap: .6rem; padding: .75rem 1.1rem; border-bottom: 1px solid #f8fafc; text-decoration: none; color: inherit; transition: background .12s; }
.ad__tarea:last-child { border-bottom: none; }
.ad__tarea:hover { background: #fafbfc; }
.ad__tarea-prio { font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; padding: .2em .55em; border-radius: 5px; flex-shrink: 0; margin-top: .15rem; }
.ad__tarea-body { flex: 1; min-width: 0; }
.ad__tarea-titulo { font-size: .83rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ad__tarea-meta { font-size: .7rem; color: #94a3b8; margin-top: .1rem; display: flex; gap: .35rem; }

.ad__movs { display: flex; flex-direction: column; }
.ad__mov { display: flex; align-items: center; gap: .65rem; padding: .65rem 1.1rem; border-bottom: 1px solid #f8fafc; }
.ad__mov:last-child { border-bottom: none; }
.ad__mov-icon { width: 28px; height: 28px; border-radius: 7px; display: flex; align-items: center; justify-content: center; font-size: .78rem; flex-shrink: 0; }
.ad__mov-body { flex: 1; min-width: 0; }
.ad__mov-desc { font-size: .8rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ad__mov-meta { font-size: .68rem; color: #94a3b8; margin-top: .05rem; }
.ad__mov-monto { font-size: .8rem; font-weight: 800; flex-shrink: 0; font-family: monospace; }

.ad__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #0369a1; border: 1.5px solid #bfdbfe; padding: .55rem 1rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; text-decoration: none; transition: all .15s; white-space: nowrap; }
.ad__btn-secondary:hover { background: #eff6ff; }
.ad__btn-ghost { display: inline-flex; align-items: center; justify-content: center; width: 36px; height: 36px; background: #fff; color: #64748b; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: 1rem; cursor: pointer; text-decoration: none; transition: all .15s; }
.ad__btn-ghost:hover { background: #f8fafc; color: #0f172a; }
.ad__btn-sm-green { display: inline-flex; align-items: center; gap: .35rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .5rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; text-decoration: none; }
</style>
