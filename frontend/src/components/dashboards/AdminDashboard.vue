<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listSedes, getContableDashboard, getTareasDashboard, getInventarioPendiente } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import { useStatsStore } from '../../stores/stats.js'
import PlantDistributionChart from '../charts/PlantDistributionChart.vue'
import OnboardingWizard from '../OnboardingWizard.vue'
import DsCard     from '../../design-system/components/Card.vue'
import DsStat     from '../../design-system/components/Stat.vue'
import DsButton   from '../../design-system/components/Button.vue'
import DsEmpty    from '../../design-system/components/EmptyState.vue'
import DsSpinner  from '../../design-system/components/Spinner.vue'

const auth       = useAuthStore()
const club       = useClubStore()
const statsStore = useStatsStore()
const router     = useRouter()

const sedes          = ref([])
const contable       = ref(null)
const tareas         = ref(null)
const loading        = ref(true)
const stockPendiente = ref(0)

const stats = computed(() => statsStore.data ?? {})

const mostrarOnboarding = computed(() => !loading.value && sedes.value.length === 0)

const hora     = new Date().getHours()
const saludo   = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const _hoy     = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const hoy      = _hoy.charAt(0).toUpperCase() + _hoy.slice(1)
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
  const sp = stockPendiente.value || 0
  if (sp > 0) list.push({ level: 'info', icon: 'bi-scissors', msg: `${sp} movimiento${sp !== 1 ? 's' : ''} de manicura pendiente${sp !== 1 ? 's' : ''} de aprobación`, action: { label: 'Revisar stock', to: '/manicura' } })
  const v = stats.value.vencimientos || 0
  if (v > 0) list.push({ level: 'danger', icon: 'bi-patch-exclamation-fill', msg: `${v} paciente${v !== 1 ? 's' : ''} con REPROCANN vencido`, action: { label: 'Ver pacientes', to: '/pacientes' } })
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
    const [sedesRes, contableRes, tareasRes, stockRes] = await Promise.allSettled([
      listSedes(),
      getContableDashboard(),
      getTareasDashboard(),
      getInventarioPendiente(),
    ])
    await statsStore.fetchAll()
    if (sedesRes.status    === 'fulfilled') sedes.value    = sedesRes.value.data || []
    if (contableRes.status === 'fulfilled') contable.value = contableRes.value.data
    if (tareasRes.status   === 'fulfilled') tareas.value   = tareasRes.value.data
    if (stockRes.status    === 'fulfilled') stockPendiente.value = (stockRes.value.data || []).length
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
  <div class="ad ds-root">

    <!-- Role accent bar -->
    <div class="ad__accent-bar" />

    <!-- Onboarding fullscreen -->
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
        <RouterLink to="/pacientes/nuevo" custom v-slot="{ navigate }">
          <DsButton variant="secondary" size="sm" @click="navigate">
            <i class="bi bi-person-plus"></i> Nuevo paciente
          </DsButton>
        </RouterLink>
        <RouterLink to="/preferencias" custom v-slot="{ navigate }">
          <DsButton variant="icon" @click="navigate">
            <i class="bi bi-gear"></i>
          </DsButton>
        </RouterLink>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="ad__loading">
      <DsSpinner :size="22" />
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
        <RouterLink to="/salas" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div class="ad__kpi-ico ad__kpi-ico--green"><i class="bi bi-flower2"></i></div>
            <DsStat
              label="Plantas en ciclo"
              :value="(stats.vegetativo || 0) + (stats.floracion || 0)"
            />
            <div class="ad__kpi-sub">
              <span class="c-green">{{ stats.vegetativo || 0 }} veg</span>
              <span class="c-violet"> · {{ stats.floracion || 0 }} flor</span>
            </div>
          </DsCard>
        </RouterLink>

        <RouterLink to="/pacientes" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div class="ad__kpi-ico ad__kpi-ico--blue"><i class="bi bi-people"></i></div>
            <DsStat
              label="Pacientes activos"
              :value="stats.pacientes ?? stats.socios ?? 0"
            />
            <div v-if="stats.vencimientos" class="ad__kpi-sub c-amber">{{ stats.vencimientos }} REPROCANN por vencer</div>
          </DsCard>
        </RouterLink>

        <RouterLink to="/salas" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div class="ad__kpi-ico ad__kpi-ico--violet"><i class="bi bi-boxes"></i></div>
            <DsStat
              label="Lotes activos"
              :value="stats.lotes || 0"
            />
            <div class="ad__kpi-sub c-muted">{{ stats.salas || 0 }} salas activas</div>
          </DsCard>
        </RouterLink>

        <RouterLink to="/contabilidad" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div
              class="ad__kpi-ico"
              :class="(contable?.mes_actual?.balance || 0) >= 0 ? 'ad__kpi-ico--green' : 'ad__kpi-ico--red'"
            >
              <i class="bi bi-bar-chart-line"></i>
            </div>
            <DsStat
              :label="`Balance ${mesLabel}`"
              :value="fmtCompacto(contable?.mes_actual?.balance || 0)"
              :tone="(contable?.mes_actual?.balance || 0) >= 0 ? 'leaf-600' : 'rust-600'"
            />
            <div class="ad__kpi-sub">
              <span class="c-green">↓ {{ fmtCompacto(contable?.mes_actual?.ingresos || 0) }}</span>
              <span class="c-red"> · ↑ {{ fmtCompacto(contable?.mes_actual?.egresos || 0) }}</span>
            </div>
          </DsCard>
        </RouterLink>
      </div>

      <!-- Layout -->
      <div class="ad__layout">

        <div class="ad__col ad__col--main">

          <!-- Sedes -->
          <DsCard variant="outlined" padding="none">
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-ico ad__card-ico--green"><i class="bi bi-building"></i></span>
                <span class="ad__card-title">Sedes operativas</span>
                <span class="ad__pill">{{ sedes.length }}</span>
              </div>
              <RouterLink to="/sedes" class="ad__card-link">Gestionar →</RouterLink>
            </div>
            <DsEmpty
              v-if="!sedes.length"
              title="Sin sedes configuradas"
              description="Creá tu primera sede para comenzar a gestionar el club."
            />
            <div v-else class="ad__sedes">
              <RouterLink
                v-for="sede in sedes"
                :key="sede.id"
                :to="{ name: 'sede-detail', params: { id: sede.id } }"
                class="ad__sede"
              >
                <div class="ad__sede-stripe" :style="{ background: tipoMeta(sede.tipo).color }"></div>
                <div class="ad__sede-ico" :style="{ background: tipoMeta(sede.tipo).bg, color: tipoMeta(sede.tipo).color }">
                  <i :class="['bi', tipoMeta(sede.tipo).icon]"></i>
                </div>
                <div class="ad__sede-info">
                  <div class="ad__sede-nombre">{{ sede.nombre }}</div>
                  <div class="ad__sede-meta">
                    <span>{{ tipoMeta(sede.tipo).label }}</span>
                    <span class="ad__dot">·</span>
                    <span>{{ sede.salas_count }} sala{{ sede.salas_count !== 1 ? 's' : '' }}</span>
                    <span v-if="sede.ciudad" class="ad__dot">·</span>
                    <span v-if="sede.ciudad">{{ sede.ciudad }}</span>
                  </div>
                </div>
                <div v-if="sede.declarada_reprocann" class="ad__sede-reprocann">
                  <i class="bi bi-patch-check-fill c-green"></i>
                </div>
                <i class="bi bi-arrow-right ad__arrow"></i>
              </RouterLink>
            </div>
          </DsCard>

          <!-- Distribución plantas -->
          <DsCard
            v-if="stats.vegetativo || stats.floracion"
            variant="outlined"
            padding="none"
            class="ad__card--mt"
          >
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-ico ad__card-ico--green"><i class="bi bi-pie-chart"></i></span>
                <span class="ad__card-title">Distribución del cultivo</span>
              </div>
            </div>
            <div class="ad__card-body"><PlantDistributionChart :data="stats" /></div>
          </DsCard>

        </div>

        <div class="ad__col ad__col--side">

          <!-- Acciones rápidas -->
          <DsCard variant="outlined" padding="none">
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-ico ad__card-ico--ink"><i class="bi bi-lightning-charge"></i></span>
                <span class="ad__card-title">Acciones rápidas</span>
              </div>
            </div>
            <div class="ad__actions">
              <RouterLink to="/pacientes/nuevo" custom v-slot="{ navigate }">
                <DsButton variant="ghost" class="ad__action" @click="navigate">
                  <div class="ad__action-ico ad__action-ico--blue"><i class="bi bi-person-plus"></i></div>
                  <div class="ad__action-body">
                    <div class="ad__action-label">Nuevo paciente</div>
                    <div class="ad__action-hint">Registrar en el club</div>
                  </div>
                  <i class="bi bi-arrow-right ad__action-arrow"></i>
                </DsButton>
              </RouterLink>
              <RouterLink to="/contabilidad" custom v-slot="{ navigate }">
                <DsButton variant="ghost" class="ad__action" @click="navigate">
                  <div class="ad__action-ico ad__action-ico--green"><i class="bi bi-cash-stack"></i></div>
                  <div class="ad__action-body">
                    <div class="ad__action-label">Registrar movimiento</div>
                    <div class="ad__action-hint">Ingreso o egreso</div>
                  </div>
                  <i class="bi bi-arrow-right ad__action-arrow"></i>
                </DsButton>
              </RouterLink>
              <RouterLink to="/tareas" custom v-slot="{ navigate }">
                <DsButton variant="ghost" class="ad__action" @click="navigate">
                  <div class="ad__action-ico ad__action-ico--violet"><i class="bi bi-clipboard-plus"></i></div>
                  <div class="ad__action-body">
                    <div class="ad__action-label">Nueva tarea</div>
                    <div class="ad__action-hint">Asignar al equipo</div>
                  </div>
                  <i class="bi bi-arrow-right ad__action-arrow"></i>
                </DsButton>
              </RouterLink>
              <RouterLink to="/informe-semestral" custom v-slot="{ navigate }">
                <DsButton variant="ghost" class="ad__action" @click="navigate">
                  <div class="ad__action-ico ad__action-ico--amber"><i class="bi bi-file-earmark-text"></i></div>
                  <div class="ad__action-body">
                    <div class="ad__action-label">Informe REPROCANN</div>
                    <div class="ad__action-hint">Semestral para el Estado</div>
                  </div>
                  <i class="bi bi-arrow-right ad__action-arrow"></i>
                </DsButton>
              </RouterLink>
            </div>
          </DsCard>

          <!-- Tareas urgentes -->
          <DsCard
            v-if="tareasUrgentes.length"
            variant="outlined"
            padding="none"
            class="ad__card--mt"
          >
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-ico ad__card-ico--amber"><i class="bi bi-clock-history"></i></span>
                <span class="ad__card-title">Tareas urgentes</span>
                <span class="ad__pill ad__pill--warn">{{ tareasUrgentes.length }}</span>
              </div>
              <RouterLink to="/tareas" class="ad__card-link">Ver todas →</RouterLink>
            </div>
            <div class="ad__tareas">
              <RouterLink v-for="t in tareasUrgentes" :key="t.id" to="/tareas" class="ad__tarea">
                <div class="ad__tarea-prio" :style="{ background: prioMeta(t.prioridad).bg, color: prioMeta(t.prioridad).color }">
                  {{ prioMeta(t.prioridad).label }}
                </div>
                <div class="ad__tarea-body">
                  <div class="ad__tarea-titulo">{{ t.titulo }}</div>
                  <div class="ad__tarea-meta">
                    <span v-if="t.sala_nombre">{{ t.sala_nombre }}</span>
                    <span v-if="t.fecha_programada" class="ad__dot">·</span>
                    <span
                      v-if="t.fecha_programada"
                      :class="new Date(t.fecha_programada) < new Date() ? 'c-red fw-600' : ''"
                    >{{ formatDate(t.fecha_programada) }}</span>
                  </div>
                </div>
              </RouterLink>
            </div>
          </DsCard>
          <DsEmpty
            v-else
            title="Sin tareas urgentes"
            description="El equipo está al día."
            class="ad__card--mt"
          />

          <!-- Últimos movimientos -->
          <DsCard
            v-if="contable?.ultimos_movimientos?.length"
            variant="outlined"
            padding="none"
            class="ad__card--mt"
          >
            <div class="ad__card-header">
              <div class="ad__card-title-wrap">
                <span class="ad__card-ico ad__card-ico--blue"><i class="bi bi-receipt"></i></span>
                <span class="ad__card-title">Últimos movimientos</span>
              </div>
              <RouterLink to="/contabilidad" class="ad__card-link">Ver libro →</RouterLink>
            </div>
            <div class="ad__movs">
              <div v-for="m in contable.ultimos_movimientos.slice(0, 5)" :key="m.id" class="ad__mov">
                <div class="ad__mov-ico" :class="m.tipo === 'ingreso' ? 'ad__mov-ico--green' : 'ad__mov-ico--red'">
                  <i :class="m.tipo === 'ingreso' ? 'bi bi-arrow-down' : 'bi bi-arrow-up'"></i>
                </div>
                <div class="ad__mov-body">
                  <div class="ad__mov-desc">{{ m.descripcion }}</div>
                  <div class="ad__mov-meta">{{ m.categoria }} · {{ formatDate(m.fecha) }}</div>
                </div>
                <div class="ad__mov-monto" :class="m.tipo === 'ingreso' ? 'c-green' : 'c-red'">
                  {{ m.tipo === 'ingreso' ? '+' : '-' }}{{ fmtCompacto(m.monto_ars) }}
                </div>
              </div>
            </div>
          </DsCard>

        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
/* ── Layout base ── */
.ad {
  padding: 0 var(--sp-6) var(--sp-12);
  max-width: 1280px;
  margin: 0 auto;
  background: var(--c-paper);
}
@media (max-width: 768px) { .ad { padding: 0 var(--sp-4) var(--sp-8); } }

/* ── Role accent bar ── */
.ad__accent-bar {
  height: 4px;
  background: var(--c-role-admin);
  margin: 0 calc(-1 * var(--sp-6)) var(--sp-8);
}
@media (max-width: 768px) { .ad__accent-bar { margin: 0 calc(-1 * var(--sp-4)) var(--sp-6); } }

/* ── Header ── */
.ad__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-6);
  flex-wrap: wrap;
}
.ad__eyebrow {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  font-size: var(--fs-12);
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .1em;
  color: var(--c-leaf-500);
  margin-bottom: var(--sp-2);
}
.ad__eyebrow-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--c-leaf-500);
  animation: ad-pulse 2s ease-in-out infinite;
}
@keyframes ad-pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.4;transform:scale(.7)} }

.ad__title {
  font-family: var(--font-display);
  font-size: var(--fs-32);
  font-weight: 800;
  color: var(--c-ink-900);
  margin: 0 0 var(--sp-1);
  letter-spacing: -.03em;
  line-height: var(--lh-tight);
}
.ad__sub {
  font-family: var(--font-mono);
  font-size: var(--fs-14);
  color: var(--c-ink-500);
  margin: 0;
}
.ad__header-actions { display: flex; gap: var(--sp-2); align-items: center; }

/* ── Loading ── */
.ad__loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--sp-3);
  padding: var(--sp-12);
  color: var(--c-ink-500);
  font-size: var(--fs-14);
}

/* ── Alertas ── */
.ad__alertas { display: flex; flex-direction: column; gap: var(--sp-2); margin-bottom: var(--sp-5); }
.ad__alerta {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-4);
  border-radius: var(--r-lg);
  font-size: var(--fs-14);
  font-weight: 500;
}
.ad__alerta--info    { background: var(--c-sky-100);   border: 1px solid #bfdbfe; color: var(--c-sky-600); }
.ad__alerta--danger  { background: var(--c-rust-100);  border: 1px solid #fecaca; color: var(--c-rust-600); }
.ad__alerta--warning { background: var(--c-amber-100); border: 1px solid #fde68a; color: var(--c-amber-500); }
.ad__alerta-icon { font-size: var(--fs-16); flex-shrink: 0; }
.ad__alerta-msg  { flex: 1; }
.ad__alerta-action {
  font-size: var(--fs-12);
  font-weight: 700;
  color: inherit;
  text-decoration: none;
  opacity: .8;
  white-space: nowrap;
}
.ad__alerta-action:hover { opacity: 1; text-decoration: underline; }

/* ── KPIs ── */
.ad__kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--sp-4);
  margin-bottom: var(--sp-6);
}
@media (max-width: 1100px) { .ad__kpis { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 560px)  { .ad__kpis { grid-template-columns: 1fr 1fr; } }

.ad__kpi-link {
  display: block;
  text-decoration: none;
  color: inherit;
}
.ad__kpi-link:hover .ad__kpi-card {
  transform: translateY(-2px);
  box-shadow: var(--sh-3);
}
.ad__kpi-card {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  transition: transform var(--t-base), box-shadow var(--t-base);
  height: 100%;
}
.ad__kpi-ico {
  width: 36px;
  height: 36px;
  border-radius: var(--r-lg);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--fs-16);
  flex-shrink: 0;
}
.ad__kpi-ico--green  { background: rgba(21,128,61,.1);   color: #15803d; }
.ad__kpi-ico--blue   { background: rgba(3,105,161,.1);   color: var(--c-sky-600); }
.ad__kpi-ico--violet { background: rgba(124,58,237,.1);  color: #7c3aed; }
.ad__kpi-ico--red    { background: rgba(220,38,38,.1);   color: var(--c-rust-600); }
.ad__kpi-sub {
  font-size: var(--fs-12);
  font-weight: 500;
  color: var(--c-ink-500);
}

/* ── Layout ── */
.ad__layout {
  display: grid;
  grid-template-columns: 1fr 340px;
  gap: var(--sp-5);
  align-items: start;
}
@media (max-width: 1050px) { .ad__layout { grid-template-columns: 1fr; } }
.ad__col { display: flex; flex-direction: column; }
.ad__card--mt { margin-top: var(--sp-5); }

/* ── Card headers (shared) ── */
.ad__card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
}
.ad__card-title-wrap { display: flex; align-items: center; gap: var(--sp-2); }
.ad__card-ico {
  width: 30px;
  height: 30px;
  border-radius: var(--r-md);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--fs-13);
  flex-shrink: 0;
}
.ad__card-ico--green  { background: rgba(21,128,61,.1);  color: #1b5e20; }
.ad__card-ico--blue   { background: rgba(3,105,161,.1);  color: var(--c-sky-600); }
.ad__card-ico--violet { background: rgba(124,58,237,.1); color: #7c3aed; }
.ad__card-ico--amber  { background: rgba(180,83,9,.1);   color: var(--c-gold-500); }
.ad__card-ico--ink    { background: rgba(15,23,42,.06);  color: var(--c-ink-700); }
.ad__card-title { font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.ad__card-link  {
  font-size: var(--fs-12);
  font-weight: 600;
  color: var(--c-sky-600);
  text-decoration: none;
  white-space: nowrap;
}
.ad__card-link:hover { text-decoration: underline; }
.ad__card-body { padding: var(--sp-4) var(--sp-5); }
.ad__pill      {
  font-size: var(--fs-12);
  font-weight: 700;
  background: var(--c-ink-100);
  color: var(--c-ink-500);
  padding: 2px var(--sp-2);
  border-radius: var(--r-pill);
}
.ad__pill--warn { background: var(--c-amber-100); color: var(--c-amber-500); }

/* ── Sedes ── */
.ad__sedes { display: flex; flex-direction: column; }
.ad__sede {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-leaf-50);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
}
.ad__sede:last-child { border-bottom: none; }
.ad__sede:hover { background: var(--c-leaf-50); }
.ad__sede-stripe { width: 3px; height: 36px; border-radius: var(--r-pill); flex-shrink: 0; }
.ad__sede-ico {
  width: 36px;
  height: 36px;
  border-radius: var(--r-lg);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--fs-16);
  flex-shrink: 0;
}
.ad__sede-info { flex: 1; min-width: 0; }
.ad__sede-nombre { font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.ad__sede-meta {
  font-size: var(--fs-12);
  color: var(--c-ink-300);
  margin-top: 2px;
  display: flex;
  align-items: center;
  gap: var(--sp-1);
}
.ad__sede-reprocann { font-size: var(--fs-14); flex-shrink: 0; }
.ad__arrow {
  color: var(--c-ink-300);
  font-size: var(--fs-13);
  flex-shrink: 0;
  transition: color var(--t-fast), transform var(--t-fast);
}
.ad__sede:hover .ad__arrow { color: var(--c-ink-900); transform: translateX(2px); }

/* ── Acciones rápidas ── */
.ad__actions { display: flex; flex-direction: column; }
.ad__action {
  width: 100%;
  justify-content: flex-start;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5);
  border-radius: 0;
  border-bottom: 1px solid var(--c-leaf-50);
  color: var(--c-ink-900) !important;
  font-weight: normal;
  text-align: left;
}
.ad__action:last-child { border-bottom: none; }
.ad__action-ico {
  width: 34px;
  height: 34px;
  border-radius: var(--r-lg);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--fs-14);
  flex-shrink: 0;
}
.ad__action-ico--blue   { background: rgba(3,105,161,.08);   color: var(--c-sky-600); }
.ad__action-ico--green  { background: rgba(21,128,61,.08);   color: #15803d; }
.ad__action-ico--violet { background: rgba(124,58,237,.08);  color: #7c3aed; }
.ad__action-ico--amber  { background: rgba(180,83,9,.08);    color: var(--c-gold-500); }
.ad__action-body { flex: 1; text-align: left; }
.ad__action-label { font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-900); }
.ad__action-hint  { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.ad__action-arrow {
  color: var(--c-ink-300);
  font-size: var(--fs-13);
  transition: color var(--t-fast), transform var(--t-fast);
}
.ad__action:hover .ad__action-arrow { color: var(--c-ink-900); transform: translateX(2px); }

/* ── Tareas ── */
.ad__tareas { display: flex; flex-direction: column; }
.ad__tarea {
  display: flex;
  align-items: flex-start;
  gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-leaf-50);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
}
.ad__tarea:last-child { border-bottom: none; }
.ad__tarea:hover { background: var(--c-leaf-50); }
.ad__tarea-prio {
  font-size: var(--fs-12);
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: .05em;
  padding: 2px var(--sp-2);
  border-radius: var(--r-sm);
  flex-shrink: 0;
  margin-top: 2px;
}
.ad__tarea-body { flex: 1; min-width: 0; }
.ad__tarea-titulo {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-ink-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.ad__tarea-meta {
  font-size: var(--fs-12);
  color: var(--c-ink-500);
  margin-top: 2px;
  display: flex;
  gap: var(--sp-1);
}

/* ── Movimientos ── */
.ad__movs { display: flex; flex-direction: column; }
.ad__mov {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-5);
  border-bottom: 1px solid var(--c-leaf-50);
}
.ad__mov:last-child { border-bottom: none; }
.ad__mov-ico {
  width: 28px;
  height: 28px;
  border-radius: var(--r-md);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--fs-12);
  flex-shrink: 0;
}
.ad__mov-ico--green { background: rgba(21,128,61,.1);  color: #15803d; }
.ad__mov-ico--red   { background: rgba(220,38,38,.1);  color: var(--c-rust-600); }
.ad__mov-body { flex: 1; min-width: 0; }
.ad__mov-desc { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ad__mov-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.ad__mov-monto {
  font-size: var(--fs-13);
  font-weight: 800;
  flex-shrink: 0;
  font-family: var(--font-mono);
}

/* ── Utility color/weight classes ── */
.c-green  { color: #15803d; }
.c-violet { color: #7c3aed; }
.c-amber  { color: var(--c-amber-500); }
.c-red    { color: var(--c-rust-600); }
.c-muted  { color: var(--c-ink-500); }
.fw-600   { font-weight: 600; }
.ad__dot  { color: var(--c-ink-300); }
</style>
