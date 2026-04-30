<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listSedes, getContableDashboard, getTareasDashboard, listLotes, listStocks } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import { useStatsStore } from '../../stores/stats.js'
import PlantDistributionChart from '../charts/PlantDistributionChart.vue'
import OnboardingWizard from '../OnboardingWizard.vue'
import DsCard    from '../../design-system/components/Card.vue'
import DsStat    from '../../design-system/components/Stat.vue'
import DsButton  from '../../design-system/components/Button.vue'
import DsEmpty   from '../../design-system/components/EmptyState.vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import DsBanner  from '../../design-system/components/Banner.vue'
import DsBadge   from '../../design-system/components/Badge.vue'
import LeafHerbarium from '../../design-system/icons/LeafHerbarium.vue'

const auth       = useAuthStore()
const club       = useClubStore()
const statsStore = useStatsStore()
const router     = useRouter()

const sedes                  = ref([])
const contable               = ref(null)
const tareas                 = ref(null)
const loading                = ref(true)
const lotesManicuraPendiente = ref([])
const lotesCurado            = ref([])
const stocks                 = ref([])

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
  const sp = lotesManicuraPendiente.value.length
  if (sp > 0) list.push({ variant: 'sky',   icon: 'bi-clipboard-check',       msg: `${sp} lote${sp !== 1 ? 's' : ''} pendiente${sp !== 1 ? 's' : ''} de aprobación de manicura`, to: '/aprobaciones', cta: 'Revisar' })
  const v = stats.value.vencimientos || 0
  if (v > 0) list.push({ variant: 'rust',   icon: 'bi-patch-exclamation-fill', msg: `${v} paciente${v !== 1 ? 's' : ''} con REPROCANN vencido`, to: '/pacientes', cta: 'Ver pacientes' })
  const tv = tareas.value?.stats?.vencidas || 0
  if (tv > 0) list.push({ variant: 'amber', icon: 'bi-clock-history',         msg: `${tv} tarea${tv !== 1 ? 's' : ''} vencida${tv !== 1 ? 's' : ''} sin completar`, to: '/tareas', cta: 'Ver tareas' })
  return list
})

const stockDisponible = computed(() => {
  const map = {}
  for (const s of stocks.value) {
    const key = s.forma_producto || 'otros'
    map[key] = (map[key] || 0) + (Number(s.cantidad) || 0)
  }
  return Object.entries(map).sort((a, b) => b[1] - a[1])
})

const TIPO_META = {
  produccion: { label: 'Producción',  color: 'var(--c-leaf-700)', bg: 'rgba(21,128,61,.08)',   icon: 'bi-flower2',        badgeVariant: 'leaf' },
  social:     { label: 'Dispensario', color: 'var(--c-sky-600)',  bg: 'rgba(3,105,161,.08)',   icon: 'bi-shop',           badgeVariant: 'sky'  },
  mixta:      { label: 'Mixta',       color: '#7c3aed',           bg: 'rgba(124,58,237,.08)',  icon: 'bi-arrow-left-right', badgeVariant: 'ink' },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion }

const tareasUrgentes = computed(() => {
  if (!tareas.value) return []
  return [...(tareas.value.vencidas || []), ...(tareas.value.hoy || [])].slice(0, 5)
})

const PRIORIDAD_META = {
  alta:   { variant: 'rust',  label: 'Alta' },
  normal: { variant: 'sky',   label: 'Normal' },
  baja:   { variant: 'ink',   label: 'Baja' },
}
function prioMeta(p) { return PRIORIDAD_META[p] || PRIORIDAD_META.normal }

const balancePositivo = computed(() => (contable.value?.mes_actual?.balance || 0) >= 0)

onMounted(async () => {
  try {
    const [sedesRes, contableRes, tareasRes, manicuraRes, curadoRes, stocksRes] = await Promise.allSettled([
      listSedes(),
      getContableDashboard(),
      getTareasDashboard(),
      listLotes({ estado: 'manicura_pendiente' }),
      listLotes({ estado: 'curado' }),
      listStocks(),
    ])
    await statsStore.fetchAll()
    if (sedesRes.status    === 'fulfilled') sedes.value                  = sedesRes.value.data    || []
    if (contableRes.status === 'fulfilled') contable.value               = contableRes.value.data
    if (tareasRes.status   === 'fulfilled') tareas.value                 = tareasRes.value.data
    if (manicuraRes.status === 'fulfilled') lotesManicuraPendiente.value = manicuraRes.value.data || []
    if (curadoRes.status   === 'fulfilled') lotesCurado.value            = curadoRes.value.data   || []
    if (stocksRes.status   === 'fulfilled') stocks.value                 = stocksRes.value.data   || []
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

    <OnboardingWizard v-if="mostrarOnboarding" @completado="onOnboardingCompletado" />

    <!-- ── Loading ── -->
    <div v-if="loading" class="ad__loading">
      <DsSpinner :size="22" />
      <span>Cargando datos del club…</span>
    </div>

    <template v-else>

      <!-- ── Sección 1: Bienvenida ── -->
      <div class="ad__welcome">
        <div class="ad__welcome-left">
          <h1 class="ad__saludo">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        </div>
        <div class="ad__welcome-right">
          <span class="ad__fecha">{{ hoy }}</span>
          <RouterLink to="/pacientes/nuevo" custom v-slot="{ navigate }">
            <DsButton variant="primary" size="sm" @click="navigate">
              <i class="bi bi-plus-lg"></i> Nuevo paciente
            </DsButton>
          </RouterLink>
        </div>
      </div>

      <!-- ── Sección 2: Alertas ── -->
      <div v-if="alertas.length" class="ad__alertas">
        <DsBanner
          v-for="(a, i) in alertas"
          :key="i"
          :variant="a.variant"
          :icon="a.icon"
        >
          {{ a.msg }}
          <template #action>
            <RouterLink :to="a.to">{{ a.cta }} →</RouterLink>
          </template>
        </DsBanner>
      </div>

      <!-- ── Sección 3: KPIs ── -->
      <div class="ad__kpis">

        <RouterLink to="/salas" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div class="ad__kpi-ico ad__kpi-ico--green"><i class="bi bi-flower2"></i></div>
            <DsStat
              label="Plantas en ciclo"
              :value="(stats.vegetativo || 0) + (stats.floracion || 0)"
            />
            <p class="ad__kpi-sub">
              <span class="c-leaf">{{ stats.vegetativo || 0 }} veg</span>
              <span class="c-muted"> · </span>
              <span class="c-violet">{{ stats.floracion || 0 }} flor</span>
            </p>
          </DsCard>
        </RouterLink>

        <RouterLink to="/pacientes" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div class="ad__kpi-ico ad__kpi-ico--blue"><i class="bi bi-people"></i></div>
            <DsStat
              label="Pacientes activos"
              :value="stats.pacientes ?? stats.socios ?? 0"
            />
            <p v-if="stats.vencimientos" class="ad__kpi-sub c-amber">
              {{ stats.vencimientos }} REPROCANN por vencer
            </p>
            <p v-else class="ad__kpi-sub c-muted">Socios habilitados</p>
          </DsCard>
        </RouterLink>

        <RouterLink to="/salas" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div class="ad__kpi-ico ad__kpi-ico--violet"><i class="bi bi-boxes"></i></div>
            <DsStat
              label="Lotes activos"
              :value="stats.lotes || 0"
            />
            <p class="ad__kpi-sub c-muted">{{ stats.salas || 0 }} salas activas</p>
          </DsCard>
        </RouterLink>

        <RouterLink to="/contabilidad" class="ad__kpi-link">
          <DsCard variant="default" padding="md" class="ad__kpi-card">
            <div class="ad__kpi-ico" :class="balancePositivo ? 'ad__kpi-ico--green' : 'ad__kpi-ico--red'">
              <i class="bi bi-bar-chart-line"></i>
            </div>
            <DsStat
              :label="`Balance ${mesLabel}`"
              :value="fmtCompacto(contable?.mes_actual?.balance || 0)"
              :tone="balancePositivo ? 'leaf-600' : 'rust-600'"
            />
            <p class="ad__kpi-sub c-muted" style="font-family:var(--font-mono);font-size:var(--fs-12)">
              <span class="c-leaf">↓ {{ fmtCompacto(contable?.mes_actual?.ingresos || 0) }}</span>
              <span>  ·  </span>
              <span class="c-red">↑ {{ fmtCompacto(contable?.mes_actual?.egresos || 0) }}</span>
            </p>
          </DsCard>
        </RouterLink>

      </div>

      <!-- ── Sección 4: Grid 2 columnas ── -->
      <div class="ad__grid">

        <!-- Columna principal (2fr) -->
        <div class="ad__col-main">

          <!-- Sedes -->
          <DsCard variant="outlined" padding="none">
            <div class="ad__ch">
              <div class="ad__ch-left">
                <span class="ad__ch-title">Sedes operativas</span>
                <DsBadge variant="leaf" size="sm">{{ sedes.length }}</DsBadge>
              </div>
              <RouterLink to="/sedes" class="ad__ch-link">Gestionar →</RouterLink>
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
                <i class="bi bi-building ad__sede-ico" :style="{ color: tipoMeta(sede.tipo).color }"></i>
                <div class="ad__sede-info">
                  <span class="ad__sede-nombre">{{ sede.nombre }}</span>
                  <DsBadge :variant="tipoMeta(sede.tipo).badgeVariant" size="sm">{{ tipoMeta(sede.tipo).label }}</DsBadge>
                </div>
                <div class="ad__sede-meta">
                  <span class="ad__sede-salas">{{ sede.salas_count }} sala{{ sede.salas_count !== 1 ? 's' : '' }}</span>
                  <span v-if="sede.ciudad" class="ad__sede-ciudad">{{ sede.ciudad }}</span>
                </div>
                <i class="bi bi-chevron-right ad__sede-arrow"></i>
              </RouterLink>
            </div>
          </DsCard>

          <!-- Pipeline post-cosecha -->
          <DsCard v-if="lotesManicuraPendiente.length || lotesCurado.length" variant="outlined" padding="none" class="ad__card--mt">
            <div class="ad__ch">
              <span class="ad__ch-title">Pipeline post-cosecha</span>
            </div>
            <div class="ad__pipeline">
              <RouterLink v-if="lotesManicuraPendiente.length" to="/aprobaciones" class="ad__pipe-item">
                <div class="ad__pipe-ico ad__pipe-ico--amber"><i class="bi bi-clipboard-check"></i></div>
                <div class="ad__pipe-body">
                  <div class="ad__pipe-label">Pendientes de aprobación</div>
                  <div class="ad__pipe-sub">Manicura finalizada, esperando admin</div>
                </div>
                <span class="ad__pipe-count">{{ lotesManicuraPendiente.length }}</span>
                <i class="bi bi-chevron-right ad__pipe-arrow"></i>
              </RouterLink>
              <RouterLink v-if="lotesCurado.length" to="/admin/curado" class="ad__pipe-item">
                <div class="ad__pipe-ico ad__pipe-ico--green"><i class="bi bi-box-seam"></i></div>
                <div class="ad__pipe-body">
                  <div class="ad__pipe-label">En curado — listos para cerrar</div>
                  <div class="ad__pipe-sub">Pesada final + ingreso a stock</div>
                </div>
                <span class="ad__pipe-count">{{ lotesCurado.length }}</span>
                <i class="bi bi-chevron-right ad__pipe-arrow"></i>
              </RouterLink>
            </div>
          </DsCard>

          <!-- Últimos movimientos -->
          <DsCard variant="outlined" padding="none" class="ad__card--mt">
            <div class="ad__ch">
              <span class="ad__ch-title">Últimos movimientos</span>
              <RouterLink to="/contabilidad" class="ad__ch-link">Ver libro →</RouterLink>
            </div>
            <DsEmpty
              v-if="!contable?.ultimos_movimientos?.length"
              title="Sin movimientos registrados"
              description="Registrá el primer movimiento contable del club."
            >
              <RouterLink to="/contabilidad" custom v-slot="{ navigate }">
                <DsButton variant="secondary" size="sm" class="ad__empty-cta" @click="navigate">
                  Registrar movimiento
                </DsButton>
              </RouterLink>
            </DsEmpty>
            <div v-else class="ad__movs">
              <div v-for="m in contable.ultimos_movimientos.slice(0, 5)" :key="m.id" class="ad__mov">
                <div class="ad__mov-ico" :class="m.tipo === 'ingreso' ? 'ad__mov-ico--green' : 'ad__mov-ico--red'">
                  <i :class="m.tipo === 'ingreso' ? 'bi bi-graph-up-arrow' : 'bi bi-graph-down-arrow'"></i>
                </div>
                <div class="ad__mov-body">
                  <div class="ad__mov-desc">{{ m.descripcion }}</div>
                  <div class="ad__mov-meta">{{ m.categoria }} · {{ formatDate(m.fecha) }}</div>
                </div>
                <div
                  class="ad__mov-monto"
                  :class="m.tipo === 'ingreso' ? 'c-leaf' : 'c-red'"
                >
                  {{ m.tipo === 'ingreso' ? '+' : '-' }}{{ fmtCompacto(m.monto_ars) }}
                </div>
              </div>
            </div>
          </DsCard>

          <!-- Distribución (si hay datos) -->
          <DsCard v-if="stats.vegetativo || stats.floracion" variant="outlined" padding="none" class="ad__card--mt">
            <div class="ad__ch">
              <span class="ad__ch-title">Distribución del cultivo</span>
            </div>
            <div class="ad__card-body"><PlantDistributionChart :data="stats" /></div>
          </DsCard>

        </div>

        <!-- Columna lateral (1fr) -->
        <div class="ad__col-side">

          <!-- Acciones rápidas -->
          <DsCard variant="default" padding="none">
            <div class="ad__ch">
              <span class="ad__ch-title">Acciones rápidas</span>
            </div>
            <div class="ad__actions">
              <RouterLink v-if="lotesManicuraPendiente.length" to="/aprobaciones" class="ad__action ad__action--alert">
                <div class="ad__action-ico ad__action-ico--amber"><i class="bi bi-clipboard-check"></i></div>
                <div class="ad__action-body">
                  <div class="ad__action-label">Aprobaciones</div>
                  <div class="ad__action-hint">{{ lotesManicuraPendiente.length }} lote{{ lotesManicuraPendiente.length !== 1 ? 's' : '' }} esperando</div>
                </div>
                <span class="ad__action-badge">{{ lotesManicuraPendiente.length }}</span>
                <i class="bi bi-chevron-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink v-if="lotesCurado.length" to="/admin/curado" class="ad__action ad__action--alert">
                <div class="ad__action-ico ad__action-ico--green"><i class="bi bi-box-seam"></i></div>
                <div class="ad__action-body">
                  <div class="ad__action-label">Cerrar curado</div>
                  <div class="ad__action-hint">{{ lotesCurado.length }} lote{{ lotesCurado.length !== 1 ? 's' : '' }} listos</div>
                </div>
                <span class="ad__action-badge ad__action-badge--green">{{ lotesCurado.length }}</span>
                <i class="bi bi-chevron-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/pacientes/nuevo" class="ad__action">
                <div class="ad__action-ico ad__action-ico--blue"><i class="bi bi-person-plus"></i></div>
                <div class="ad__action-body">
                  <div class="ad__action-label">Nuevo paciente</div>
                  <div class="ad__action-hint">Registrar en el club</div>
                </div>
                <i class="bi bi-chevron-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/contabilidad" class="ad__action">
                <div class="ad__action-ico ad__action-ico--green"><i class="bi bi-arrow-left-right"></i></div>
                <div class="ad__action-body">
                  <div class="ad__action-label">Registrar movimiento</div>
                  <div class="ad__action-hint">Ingreso o egreso</div>
                </div>
                <i class="bi bi-chevron-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/tareas" class="ad__action">
                <div class="ad__action-ico ad__action-ico--violet"><i class="bi bi-clipboard-check"></i></div>
                <div class="ad__action-body">
                  <div class="ad__action-label">Nueva tarea</div>
                  <div class="ad__action-hint">Asignar al equipo</div>
                </div>
                <i class="bi bi-chevron-right ad__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/informe-semestral" class="ad__action">
                <div class="ad__action-ico ad__action-ico--amber"><i class="bi bi-file-earmark-arrow-down"></i></div>
                <div class="ad__action-body">
                  <div class="ad__action-label">Informe REPROCANN</div>
                  <div class="ad__action-hint">Semestral para el Estado</div>
                </div>
                <i class="bi bi-chevron-right ad__action-arrow"></i>
              </RouterLink>
            </div>
          </DsCard>

          <!-- Stock disponible -->
          <DsCard v-if="stockDisponible.length" variant="outlined" padding="none" class="ad__card--mt">
            <div class="ad__ch">
              <span class="ad__ch-title">Stock disponible</span>
              <RouterLink to="/sedes" class="ad__ch-link">Ver sedes →</RouterLink>
            </div>
            <div class="ad__stock">
              <div v-for="[forma, total] in stockDisponible" :key="forma" class="ad__stock-item">
                <i class="bi bi-bag ad__stock-ico"></i>
                <span class="ad__stock-forma">{{ forma }}</span>
                <span class="ad__stock-total">{{ total % 1 === 0 ? total : total.toFixed(1) }}</span>
              </div>
            </div>
          </DsCard>

          <!-- Tareas urgentes -->
          <DsCard variant="outlined" padding="none" class="ad__card--mt">
            <div class="ad__ch">
              <span class="ad__ch-title">Tareas urgentes</span>
              <DsBadge v-if="tareasUrgentes.length" variant="amber" size="sm">{{ tareasUrgentes.length }}</DsBadge>
            </div>
            <DsEmpty
              v-if="!tareasUrgentes.length"
              title="El equipo está al día"
              class="ad__tareas-empty"
            />
            <div v-else class="ad__tareas">
              <RouterLink
                v-for="t in tareasUrgentes"
                :key="t.id"
                to="/tareas"
                class="ad__tarea"
              >
                <DsBadge :variant="prioMeta(t.prioridad).variant" size="sm">
                  {{ prioMeta(t.prioridad).label }}
                </DsBadge>
                <div class="ad__tarea-body">
                  <div class="ad__tarea-titulo">{{ t.titulo }}</div>
                  <div class="ad__tarea-meta">
                    <span v-if="new Date(t.fecha_programada) < new Date()" class="c-red">
                      Vencida
                    </span>
                    <span v-else-if="t.fecha_programada">
                      {{ formatDate(t.fecha_programada) }}
                    </span>
                  </div>
                </div>
              </RouterLink>
            </div>
          </DsCard>

        </div>
      </div>

      <!-- ── Sección 5: Footer mini ── -->
      <footer class="ad__footer">
        <LeafHerbarium :size="12" class="ad__footer-leaf" />
        <span>Cultivo Espacial · {{ club.data?.nombre }}</span>
      </footer>

    </template>
  </div>
</template>

<style scoped>
/* ── Layout ── */
.ad {
  padding: var(--sp-8) var(--sp-8) var(--sp-12);
  max-width: 1280px;
  margin: 0 auto;
}
@media (max-width: 768px) { .ad { padding: var(--sp-5) var(--sp-4) var(--sp-8); } }

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

/* ── Sección 1: Bienvenida ── */
.ad__welcome {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-4);
  margin-bottom: var(--sp-5);
  flex-wrap: wrap;
}
.ad__saludo {
  font-family: var(--font-display);
  font-size: var(--fs-32);
  font-weight: 500;
  color: var(--c-ink-900);
  margin: 0;
  line-height: var(--lh-tight);
}
.ad__welcome-right {
  display: flex;
  align-items: center;
  gap: var(--sp-4);
}
.ad__fecha {
  font-family: var(--font-mono);
  font-size: var(--fs-13);
  color: var(--c-ink-500);
  white-space: nowrap;
}

/* ── Sección 2: Alertas ── */
.ad__alertas {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  margin-bottom: var(--sp-5);
}

/* ── Sección 3: KPIs ── */
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
.ad__kpi-card {
  display: flex;
  flex-direction: column;
  gap: var(--sp-2);
  height: 100%;
  transition: transform var(--t-base), box-shadow var(--t-base);
  cursor: pointer;
}
.ad__kpi-link:hover .ad__kpi-card {
  transform: translateY(-2px);
  box-shadow: var(--sh-2);
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
.ad__kpi-sub { font-size: var(--fs-12); margin: 0; font-weight: 500; }

/* ── Sección 4: Grid ── */
.ad__grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: var(--sp-5);
  align-items: start;
}
@media (max-width: 1050px) { .ad__grid { grid-template-columns: 1fr; } }
.ad__col-main,
.ad__col-side { display: flex; flex-direction: column; }
.ad__card--mt { margin-top: var(--sp-5); }

/* ── Card headers ── */
.ad__ch {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
  flex-wrap: wrap;
}
.ad__ch-left { display: flex; align-items: center; gap: var(--sp-2); }
.ad__ch-title {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 600;
  color: var(--c-ink-900);
}
.ad__ch-link {
  font-size: var(--fs-12);
  font-weight: 600;
  color: var(--c-sky-600);
  text-decoration: none;
}
.ad__ch-link:hover { text-decoration: underline; }
.ad__card-body { padding: var(--sp-4) var(--sp-5); }
.ad__empty-cta { margin-top: var(--sp-3); }

/* ── Sedes ── */
.ad__sedes { display: flex; flex-direction: column; }
.ad__sede {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
}
.ad__sede:last-child { border-bottom: none; }
.ad__sede:hover { background: var(--c-leaf-50); }
.ad__sede-ico { font-size: 20px; flex-shrink: 0; }
.ad__sede-info {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  flex: 1;
  min-width: 0;
}
.ad__sede-nombre { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.ad__sede-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
  flex-shrink: 0;
}
.ad__sede-salas { font-family: var(--font-mono); font-size: var(--fs-12); color: var(--c-ink-500); }
.ad__sede-ciudad { font-size: var(--fs-12); color: var(--c-ink-500); }
.ad__sede-arrow { color: var(--c-ink-300); font-size: var(--fs-13); flex-shrink: 0; transition: color var(--t-fast), transform var(--t-fast); }
.ad__sede:hover .ad__sede-arrow { color: var(--c-ink-700); transform: translateX(2px); }

/* ── Movimientos ── */
.ad__movs { display: flex; flex-direction: column; }
.ad__mov {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
}
.ad__mov:last-child { border-bottom: none; }
.ad__mov-ico {
  width: 32px; height: 32px;
  border-radius: var(--r-md);
  display: flex; align-items: center; justify-content: center;
  font-size: var(--fs-14);
  flex-shrink: 0;
}
.ad__mov-ico--green { background: rgba(21,128,61,.1); color: #15803d; }
.ad__mov-ico--red   { background: rgba(220,38,38,.1); color: var(--c-rust-600); }
.ad__mov-body { flex: 1; min-width: 0; }
.ad__mov-desc { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ad__mov-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.ad__mov-monto { font-family: var(--font-mono); font-size: var(--fs-14); font-weight: 700; flex-shrink: 0; }

/* ── Acciones rápidas ── */
.ad__actions { display: flex; flex-direction: column; }
.ad__action {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
}
.ad__action:last-child { border-bottom: none; }
.ad__action:hover { background: var(--c-leaf-50); }
.ad__action:hover .ad__action-label { color: var(--c-leaf-700); }
.ad__action-ico {
  width: 36px; height: 36px;
  border-radius: var(--r-lg);
  display: flex; align-items: center; justify-content: center;
  font-size: var(--fs-16);
  flex-shrink: 0;
}
.ad__action-ico--blue   { background: rgba(3,105,161,.08);   color: var(--c-sky-600); }
.ad__action-ico--green  { background: rgba(21,128,61,.08);   color: #15803d; }
.ad__action-ico--violet { background: rgba(124,58,237,.08);  color: #7c3aed; }
.ad__action-ico--amber  { background: rgba(180,83,9,.08);    color: var(--c-gold-500); }
.ad__action-body { flex: 1; }
.ad__action-label { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); transition: color var(--t-fast); }
.ad__action-hint  { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.ad__action-arrow { color: var(--c-ink-300); font-size: var(--fs-13); transition: color var(--t-fast), transform var(--t-fast); }
.ad__action:hover .ad__action-arrow { color: var(--c-leaf-700); transform: translateX(2px); }

/* ── Tareas urgentes ── */
.ad__tareas-empty { padding: var(--sp-6) var(--sp-4); }
.ad__tareas { display: flex; flex-direction: column; }
.ad__tarea {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
}
.ad__tarea:last-child { border-bottom: none; }
.ad__tarea:hover { background: var(--c-leaf-50); }
.ad__tarea-body { flex: 1; min-width: 0; }
.ad__tarea-titulo { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ad__tarea-meta { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }

/* ── Pipeline post-cosecha ── */
.ad__pipeline { display: flex; flex-direction: column; }
.ad__pipe-item {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-bottom: 1px solid var(--c-ink-100);
  text-decoration: none;
  color: inherit;
  transition: background var(--t-fast);
}
.ad__pipe-item:last-child { border-bottom: none; }
.ad__pipe-item:hover { background: var(--c-leaf-50); }
.ad__pipe-ico {
  width: 36px; height: 36px;
  border-radius: var(--r-lg);
  display: flex; align-items: center; justify-content: center;
  font-size: var(--fs-16);
  flex-shrink: 0;
}
.ad__pipe-ico--amber { background: rgba(180,83,9,.1);  color: var(--c-gold-500); }
.ad__pipe-ico--green { background: rgba(21,128,61,.1); color: #15803d; }
.ad__pipe-body { flex: 1; min-width: 0; }
.ad__pipe-label { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.ad__pipe-sub   { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 1px; }
.ad__pipe-count {
  font-family: var(--font-mono);
  font-size: var(--fs-20);
  font-weight: 700;
  color: var(--c-ink-700);
  flex-shrink: 0;
  min-width: 28px;
  text-align: right;
}
.ad__pipe-arrow { color: var(--c-ink-300); font-size: var(--fs-13); transition: color var(--t-fast), transform var(--t-fast); margin-left: var(--sp-1); }
.ad__pipe-item:hover .ad__pipe-arrow { color: var(--c-leaf-700); transform: translateX(2px); }

/* ── Stock disponible ── */
.ad__stock { display: flex; flex-direction: column; padding: var(--sp-2) 0; }
.ad__stock-item {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-5);
}
.ad__stock-ico { color: var(--c-ink-400); font-size: var(--fs-14); flex-shrink: 0; }
.ad__stock-forma {
  flex: 1;
  font-size: var(--fs-13);
  font-weight: 500;
  color: var(--c-ink-700);
  text-transform: capitalize;
}
.ad__stock-total {
  font-family: var(--font-mono);
  font-size: var(--fs-14);
  font-weight: 700;
  color: var(--c-leaf-700);
}

/* ── Acción con badge ── */
.ad__action--alert { background: var(--c-leaf-50); }
.ad__action-badge {
  font-family: var(--font-mono);
  font-size: var(--fs-12);
  font-weight: 800;
  min-width: 22px;
  height: 22px;
  border-radius: var(--r-pill);
  background: rgba(180,83,9,.15);
  color: var(--c-gold-600, #b45309);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 var(--sp-1);
  flex-shrink: 0;
}
.ad__action-badge--green {
  background: rgba(21,128,61,.12);
  color: #15803d;
}

/* ── Footer ── */
.ad__footer {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--sp-2);
  padding-top: var(--sp-12);
  font-size: var(--fs-12);
  color: var(--c-ink-500);
}
.ad__footer-leaf { opacity: 0.5; color: var(--c-leaf-500); }

/* ── Utility color classes ── */
.c-leaf   { color: var(--c-leaf-600); }
.c-violet { color: #7c3aed; }
.c-amber  { color: var(--c-amber-500); }
.c-red    { color: var(--c-rust-600); }
.c-muted  { color: var(--c-ink-500); }
</style>
