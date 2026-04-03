<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { getContableDashboard, listSocios, getInformeSemestral } from '../../lib/api.js'

const router = useRouter()
const auth   = useAuthStore()

const isAbogado = computed(() => auth.user?.role === 'abogado')
const isAuditor = computed(() => auth.user?.role === 'auditor')

const loading     = ref(true)
const contable    = ref(null)
const socios      = ref([])
const informe     = ref(null)

const hoy          = new Date()
const anioActual   = hoy.getFullYear()
const semActual    = hoy.getMonth() < 6 ? 1 : 2
const mesLabel     = hoy.toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })

const fmt = (n) => new Intl.NumberFormat('es-AR', {
  style: 'currency', currency: 'ARS',
  minimumFractionDigits: 0, maximumFractionDigits: 0
}).format(n || 0)

function fmtCompacto(n) {
  if (Math.abs(n) >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M'
  if (Math.abs(n) >= 1_000)     return (n / 1_000).toFixed(0) + 'k'
  return String(Math.round(n))
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function variacion(actual, anterior) {
  if (!anterior || anterior === 0) return null
  return ((actual - anterior) / Math.abs(anterior) * 100).toFixed(1)
}

// REPROCANN
const reprocannKpis = computed(() => {
  const hoy = new Date()
  const en30 = new Date(hoy.getTime() + 30 * 86400000)
  const en90 = new Date(hoy.getTime() + 90 * 86400000)
  return {
    total:    socios.value.length,
    activos:  socios.value.filter(s => s.es_paciente).length,
    vencidos: socios.value.filter(s => s.reprocann_vencimiento && new Date(s.reprocann_vencimiento) < hoy).length,
    proximos: socios.value.filter(s => {
      if (!s.reprocann_vencimiento) return false
      const v = new Date(s.reprocann_vencimiento)
      return v >= hoy && v <= en30
    }).length,
    sin_rep: socios.value.filter(s => !s.reprocann_numero).length,
  }
})

const sociosAlerta = computed(() =>
  socios.value
    .map(s => ({
      ...s,
      dias: s.reprocann_vencimiento
        ? Math.floor((new Date(s.reprocann_vencimiento) - new Date()) / 86400000)
        : null
    }))
    .filter(s => s.dias !== null && s.dias <= 90)
    .sort((a, b) => a.dias - b.dias)
    .slice(0, 6)
)

const ultimosMovimientos = computed(() =>
  (contable.value?.ultimos_movimientos || []).slice(0, 8)
)

onMounted(async () => {
  try {
    const [contRes, sociosRes, informeRes] = await Promise.all([
      getContableDashboard(),
      listSocios(),
      getInformeSemestral({ anio: anioActual, semestre: semActual }).catch(() => ({ data: null })),
    ])
    contable.value = contRes.data
    socios.value   = Array.isArray(sociosRes.data) ? sociosRes.data : []
    informe.value  = informeRes.data
  } catch (e) {
    console.error('LegalDashboard:', e)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="ld">

    <!-- Header -->
    <div class="ld__header">
      <div>
        <div class="ld__eyebrow">
          <span class="ld__eyebrow-dot"></span>
          {{ isAbogado ? 'Panel de cumplimiento legal' : 'Panel de auditoría' }}
        </div>
        <h1 class="ld__title">Buenas {{ new Date().getHours() < 13 ? 'mañanas' : new Date().getHours() < 20 ? 'tardes' : 'noches' }}, {{ auth.user?.first_name }}</h1>
        <p class="ld__subtitle">
          {{ new Date().toLocaleDateString('es-AR', { weekday:'long', day:'numeric', month:'long', year:'numeric' }) }}
          · {{ isAbogado ? 'Oficial de cumplimiento' : 'Auditor' }}
        </p>
      </div>
      <div class="ld__header-actions" v-if="isAbogado">
        <RouterLink to="/contabilidad" class="ld__btn-secondary">
          <i class="bi bi-cash-stack"></i> Contabilidad
        </RouterLink>
        <RouterLink to="/informe-semestral" class="ld__btn-primary">
          <i class="bi bi-file-earmark-text"></i> Informe REPROCANN
        </RouterLink>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="ld__loading">
      <div class="ld__ring"></div>
      <span>Cargando datos…</span>
    </div>

    <template v-else>

      <!-- KPIs financieros -->
      <div class="ld__section-label">Financiero · {{ mesLabel }}</div>
      <div class="ld__kpis">

        <div class="ld__kpi" :class="(contable?.mes_actual?.balance || 0) >= 0 ? 'ld__kpi--ok' : 'ld__kpi--danger'">
          <div class="ld__kpi-icon"
               :style="(contable?.mes_actual?.balance || 0) >= 0 ? 'background:rgba(21,128,61,.1);color:#15803d' : 'background:rgba(220,38,38,.1);color:#dc2626'">
            <i class="bi bi-bar-chart-line"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val">{{ fmtCompacto(contable?.mes_actual?.balance || 0) }}</div>
            <div class="ld__kpi-lbl">Balance del mes</div>
          </div>
          <div v-if="variacion(contable?.mes_actual?.balance, contable?.mes_anterior?.balance)" class="ld__kpi-var"
               :class="Number(variacion(contable?.mes_actual?.balance, contable?.mes_anterior?.balance)) >= 0 ? 'ld__kpi-var--up' : 'ld__kpi-var--down'">
            {{ Number(variacion(contable?.mes_actual?.balance, contable?.mes_anterior?.balance)) >= 0 ? '↑' : '↓' }}
            {{ Math.abs(Number(variacion(contable?.mes_actual?.balance, contable?.mes_anterior?.balance))) }}%
          </div>
        </div>

        <div class="ld__kpi ld__kpi--ok">
          <div class="ld__kpi-icon" style="background:rgba(21,128,61,.1);color:#15803d">
            <i class="bi bi-arrow-down-circle"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val" style="color:#15803d">{{ fmtCompacto(contable?.mes_actual?.ingresos || 0) }}</div>
            <div class="ld__kpi-lbl">Ingresos del mes</div>
          </div>
        </div>

        <div class="ld__kpi">
          <div class="ld__kpi-icon" style="background:rgba(220,38,38,.1);color:#dc2626">
            <i class="bi bi-arrow-up-circle"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val" style="color:#dc2626">{{ fmtCompacto(contable?.mes_actual?.egresos || 0) }}</div>
            <div class="ld__kpi-lbl">Egresos del mes</div>
          </div>
        </div>

        <div class="ld__kpi">
          <div class="ld__kpi-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
            <i class="bi bi-calendar-year"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val" :style="(contable?.anio_actual?.balance || 0) >= 0 ? 'color:#15803d' : 'color:#dc2626'">
              {{ fmtCompacto(contable?.anio_actual?.balance || 0) }}
            </div>
            <div class="ld__kpi-lbl">Balance {{ anioActual }}</div>
          </div>
        </div>

      </div>

      <!-- KPIs REPROCANN -->
      <div class="ld__section-label">Compliance REPROCANN</div>
      <div class="ld__kpis ld__kpis--5">

        <div class="ld__kpi">
          <div class="ld__kpi-icon" style="background:rgba(15,23,42,.06);color:#475569">
            <i class="bi bi-people"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val">{{ reprocannKpis.total }}</div>
            <div class="ld__kpi-lbl">Total pacientes</div>
          </div>
        </div>

        <div class="ld__kpi ld__kpi--ok">
          <div class="ld__kpi-icon" style="background:rgba(21,128,61,.1);color:#15803d">
            <i class="bi bi-patch-check"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val" style="color:#15803d">{{ reprocannKpis.activos }}</div>
            <div class="ld__kpi-lbl">En tratamiento</div>
          </div>
        </div>

        <div class="ld__kpi" :class="reprocannKpis.vencidos > 0 ? 'ld__kpi--danger' : ''">
          <div class="ld__kpi-icon" :style="reprocannKpis.vencidos > 0 ? 'background:rgba(220,38,38,.1);color:#dc2626' : 'background:rgba(15,23,42,.06);color:#475569'">
            <i class="bi bi-x-circle"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val" :style="reprocannKpis.vencidos > 0 ? 'color:#dc2626' : ''">{{ reprocannKpis.vencidos }}</div>
            <div class="ld__kpi-lbl">Vencidos</div>
          </div>
        </div>

        <div class="ld__kpi" :class="reprocannKpis.proximos > 0 ? 'ld__kpi--warn' : ''">
          <div class="ld__kpi-icon" :style="reprocannKpis.proximos > 0 ? 'background:rgba(180,83,9,.1);color:#b45309' : 'background:rgba(15,23,42,.06);color:#475569'">
            <i class="bi bi-clock-history"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val" :style="reprocannKpis.proximos > 0 ? 'color:#b45309' : ''">{{ reprocannKpis.proximos }}</div>
            <div class="ld__kpi-lbl">Vencen en 30d</div>
          </div>
        </div>

        <div class="ld__kpi" :class="reprocannKpis.sin_rep > 0 ? 'ld__kpi--warn' : ''">
          <div class="ld__kpi-icon" :style="reprocannKpis.sin_rep > 0 ? 'background:rgba(180,83,9,.1);color:#b45309' : 'background:rgba(15,23,42,.06);color:#475569'">
            <i class="bi bi-file-earmark-x"></i>
          </div>
          <div class="ld__kpi-body">
            <div class="ld__kpi-val" :style="reprocannKpis.sin_rep > 0 ? 'color:#b45309' : ''">{{ reprocannKpis.sin_rep }}</div>
            <div class="ld__kpi-lbl">Sin número</div>
          </div>
        </div>

      </div>

      <!-- Layout principal -->
      <div class="ld__layout">

        <!-- Columna izquierda — Movimientos + Alertas REPROCANN -->
        <div class="ld__col">

          <!-- Últimos movimientos -->
          <div class="ld__card">
            <div class="ld__card-header">
              <div class="ld__card-title-wrap">
                <span class="ld__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
                  <i class="bi bi-receipt"></i>
                </span>
                <span class="ld__card-title">Últimos movimientos</span>
              </div>
              <RouterLink to="/contabilidad" class="ld__card-link">Ver libro →</RouterLink>
            </div>

            <div v-if="!ultimosMovimientos.length" class="ld__empty">
              <i class="bi bi-receipt ld__empty-icon"></i>
              <p>Sin movimientos registrados</p>
            </div>

            <div v-else class="ld__mov-list">
              <div v-for="m in ultimosMovimientos" :key="m.id" class="ld__mov-row">
                <div class="ld__mov-icon"
                     :style="m.tipo === 'ingreso' ? 'background:rgba(21,128,61,.1);color:#15803d' : 'background:rgba(220,38,38,.1);color:#dc2626'">
                  <i :class="m.tipo === 'ingreso' ? 'bi bi-arrow-down' : 'bi bi-arrow-up'"></i>
                </div>
                <div class="ld__mov-body">
                  <div class="ld__mov-desc">{{ m.descripcion }}</div>
                  <div class="ld__mov-meta">
                    {{ m.categoria }}
                    <span class="ld__meta-dot">·</span>
                    {{ formatDate(m.fecha) }}
                    <span v-if="m.proveedor" class="ld__meta-dot">·</span>
                    <span v-if="m.proveedor">{{ m.proveedor }}</span>
                  </div>
                </div>
                <div class="ld__mov-monto"
                     :style="m.tipo === 'ingreso' ? 'color:#15803d' : 'color:#dc2626'">
                  {{ m.tipo === 'ingreso' ? '+' : '-' }}{{ fmt(m.monto_ars) }}
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Columna derecha — Alertas REPROCANN + Acciones + Informe -->
        <div class="ld__col">

          <!-- Alertas REPROCANN -->
          <div class="ld__card">
            <div class="ld__card-header">
              <div class="ld__card-title-wrap">
                <span class="ld__card-icon" style="background:rgba(180,83,9,.1);color:#b45309">
                  <i class="bi bi-patch-exclamation"></i>
                </span>
                <span class="ld__card-title">REPROCANN por atender</span>
                <span v-if="sociosAlerta.length" class="ld__badge ld__badge--warn">{{ sociosAlerta.length }}</span>
              </div>
              <RouterLink to="/socios" class="ld__card-link">Ver todos →</RouterLink>
            </div>

            <div v-if="!sociosAlerta.length" class="ld__empty">
              <i class="bi bi-patch-check-fill ld__empty-icon" style="color:#15803d"></i>
              <p>Todas las autorizaciones al día</p>
            </div>

            <div v-else class="ld__alert-list">
              <RouterLink
                v-for="s in sociosAlerta"
                :key="s.id"
                :to="`/socios/${s.id}`"
                class="ld__alert-row"
                :class="s.dias < 0 ? 'ld__alert-row--danger' : s.dias <= 30 ? 'ld__alert-row--warn' : 'ld__alert-row--info'"
              >
                <div class="ld__alert-avatar">{{ s.nombre?.[0] }}{{ s.apellido?.[0] }}</div>
                <div class="ld__alert-body">
                  <div class="ld__alert-nombre">{{ s.nombre }} {{ s.apellido }}</div>
                  <div class="ld__alert-meta">DNI {{ s.dni }}{{ s.reprocann_numero ? ` · #${s.reprocann_numero}` : '' }}</div>
                </div>
                <div class="ld__alert-badge"
                     :style="s.dias < 0 ? 'background:#fef2f2;color:#dc2626;border-color:#fecaca' : s.dias <= 30 ? 'background:#fffbeb;color:#b45309;border-color:#fde68a' : 'background:#eff6ff;color:#0369a1;border-color:#bfdbfe'">
                  {{ s.dias < 0 ? 'Vencido' : `${s.dias}d` }}
                </div>
              </RouterLink>
            </div>
          </div>

          <!-- Acciones rápidas -->
          <div class="ld__card ld__card--mt">
            <div class="ld__card-header">
              <div class="ld__card-title-wrap">
                <span class="ld__card-icon" style="background:rgba(27,94,32,.1);color:#1b5e20">
                  <i class="bi bi-lightning"></i>
                </span>
                <span class="ld__card-title">Accesos rápidos</span>
              </div>
            </div>
            <div class="ld__actions">
              <RouterLink to="/informe-semestral" class="ld__action">
                <div class="ld__action-icon" style="background:rgba(27,94,32,.08);color:#1b5e20">
                  <i class="bi bi-file-earmark-text"></i>
                </div>
                <div class="ld__action-body">
                  <div class="ld__action-label">Informe REPROCANN</div>
                  <div class="ld__action-hint">{{ semActual }}° semestre {{ anioActual }}</div>
                </div>
                <i class="bi bi-arrow-right ld__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/contabilidad" class="ld__action">
                <div class="ld__action-icon" style="background:rgba(3,105,161,.08);color:#0369a1">
                  <i class="bi bi-cash-stack"></i>
                </div>
                <div class="ld__action-body">
                  <div class="ld__action-label">Libro contable</div>
                  <div class="ld__action-hint">Ingresos y egresos del club</div>
                </div>
                <i class="bi bi-arrow-right ld__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/socios" class="ld__action">
                <div class="ld__action-icon" style="background:rgba(124,58,237,.08);color:#7c3aed">
                  <i class="bi bi-people"></i>
                </div>
                <div class="ld__action-body">
                  <div class="ld__action-label">Padrón de pacientes</div>
                  <div class="ld__action-hint">Estado REPROCANN</div>
                </div>
                <i class="bi bi-arrow-right ld__action-arrow"></i>
              </RouterLink>
              <RouterLink v-if="isAbogado" to="/tareas" class="ld__action">
                <div class="ld__action-icon" style="background:rgba(180,83,9,.08);color:#b45309">
                  <i class="bi bi-clipboard-check"></i>
                </div>
                <div class="ld__action-body">
                  <div class="ld__action-label">Tareas pendientes</div>
                  <div class="ld__action-hint">Agenda del día</div>
                </div>
                <i class="bi bi-arrow-right ld__action-arrow"></i>
              </RouterLink>
              <RouterLink to="/documentos" class="ld__action">
                <div class="ld__action-icon" style="background:rgba(15,23,42,.06);color:#475569">
                  <i class="bi bi-folder2-open"></i>
                </div>
                <div class="ld__action-body">
                  <div class="ld__action-label">Documentos</div>
                  <div class="ld__action-hint">Archivos legales del club</div>
                </div>
                <i class="bi bi-arrow-right ld__action-arrow"></i>
              </RouterLink>
            </div>
          </div>

        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.ld {
  padding: 2rem 1.5rem;
  max-width: 1200px;
  margin: 0 auto;
}
@media (max-width: 768px) { .ld { padding: 1.25rem 1rem; } }

/* Header */
.ld__header { display: flex; align-items: flex-end; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.ld__eyebrow { display: flex; align-items: center; gap: .4rem; font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .1em; color: #7c3aed; margin-bottom: .35rem; }
.ld__eyebrow-dot { width: 6px; height: 6px; border-radius: 50%; background: #7c3aed; animation: ld-pulse 2s ease-in-out infinite; }
@keyframes ld-pulse { 0%,100% { opacity:1; transform:scale(1); } 50% { opacity:.4; transform:scale(.7); } }
.ld__title { font-size: 2rem; font-weight: 800; color: #0f172a; margin: 0 0 .25rem; letter-spacing: -.04em; line-height: 1; }
.ld__subtitle { font-size: .83rem; color: #64748b; margin: 0; }
.ld__header-actions { display: flex; gap: .6rem; flex-wrap: wrap; }

/* Section label */
.ld__section-label {
  font-size: .72rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .08em; color: #94a3b8; margin-bottom: .75rem;
}

/* KPIs */
.ld__kpis { display: grid; grid-template-columns: repeat(4,1fr); gap: 1rem; margin-bottom: 1.75rem; }
.ld__kpis--5 { grid-template-columns: repeat(5,1fr); }
@media (max-width: 1000px) { .ld__kpis--5 { grid-template-columns: repeat(3,1fr); } }
@media (max-width: 900px)  { .ld__kpis { grid-template-columns: repeat(2,1fr); } }

.ld__kpi {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
  padding: 1.1rem; display: flex; flex-direction: column; gap: .5rem;
}
.ld__kpi--ok     { border-color: #bbf7d0; }
.ld__kpi--warn   { border-color: #fde68a; }
.ld__kpi--danger { border-color: #fecaca; }
.ld__kpi-icon { width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 1rem; flex-shrink: 0; }
.ld__kpi-body { flex: 1; }
.ld__kpi-val { font-size: 1.8rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.ld__kpi-lbl { font-size: .72rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; margin-top: .15rem; }
.ld__kpi-var { font-size: .72rem; font-weight: 700; }
.ld__kpi-var--up   { color: #15803d; }
.ld__kpi-var--down { color: #dc2626; }

/* Layout */
.ld__layout { display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .ld__layout { grid-template-columns: 1fr; } }
.ld__col { display: flex; flex-direction: column; }
.ld__card--mt { margin-top: 1.25rem; }

/* Cards */
.ld__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.ld__card-header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.1rem; border-bottom: 1px solid #f1f5f9; }
.ld__card-title-wrap { display: flex; align-items: center; gap: .6rem; }
.ld__card-icon { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: .85rem; flex-shrink: 0; }
.ld__card-title { font-size: .9rem; font-weight: 700; color: #0f172a; }
.ld__card-link { font-size: .78rem; font-weight: 600; color: #0369a1; text-decoration: none; white-space: nowrap; }
.ld__card-link:hover { text-decoration: underline; }

/* Badges */
.ld__badge { font-size: .65rem; font-weight: 800; padding: .15em .5em; border-radius: 999px; }
.ld__badge--warn { background: #fffbeb; color: #b45309; border: 1px solid #fde68a; }

/* Empty */
.ld__empty { text-align: center; padding: 2.5rem 1rem; color: #94a3b8; }
.ld__empty-icon { font-size: 2rem; display: block; margin-bottom: .75rem; }
.ld__empty p { font-size: .85rem; margin: 0; }

/* Movimientos */
.ld__mov-list { display: flex; flex-direction: column; }
.ld__mov-row {
  display: flex; align-items: center; gap: .75rem;
  padding: .75rem 1.1rem; border-bottom: 1px solid #f8fafc;
}
.ld__mov-row:last-child { border-bottom: none; }
.ld__mov-icon { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: .85rem; flex-shrink: 0; }
.ld__mov-body { flex: 1; min-width: 0; }
.ld__mov-desc { font-size: .85rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ld__mov-meta { font-size: .7rem; color: #94a3b8; margin-top: .1rem; display: flex; align-items: center; gap: .3rem; }
.ld__meta-dot { color: #cbd5e1; }
.ld__mov-monto { font-size: .85rem; font-weight: 800; flex-shrink: 0; font-family: monospace; }

/* Alertas REPROCANN */
.ld__alert-list { display: flex; flex-direction: column; }
.ld__alert-row { display: flex; align-items: center; gap: .75rem; padding: .75rem 1.1rem; text-decoration: none; color: inherit; border-bottom: 1px solid #f8fafc; transition: background .15s; }
.ld__alert-row:last-child { border-bottom: none; }
.ld__alert-row:hover { background: #f8fafc; }
.ld__alert-row--danger  { border-left: 3px solid #dc2626; }
.ld__alert-row--warn    { border-left: 3px solid #f59e0b; }
.ld__alert-row--info    { border-left: 3px solid #3b82f6; }
.ld__alert-avatar { width: 34px; height: 34px; border-radius: 50%; background: linear-gradient(135deg, #7c3aed22, #0369a122); color: #7c3aed; font-size: .72rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.ld__alert-body { flex: 1; min-width: 0; }
.ld__alert-nombre { font-size: .85rem; font-weight: 700; color: #0f172a; }
.ld__alert-meta { font-size: .72rem; color: #94a3b8; margin-top: .1rem; }
.ld__alert-badge { font-size: .72rem; font-weight: 800; padding: .25em .6em; border-radius: 6px; border: 1px solid; white-space: nowrap; flex-shrink: 0; }

/* Acciones */
.ld__actions { display: flex; flex-direction: column; }
.ld__action { display: flex; align-items: center; gap: .75rem; padding: .85rem 1.1rem; text-decoration: none; color: inherit; border-bottom: 1px solid #f8fafc; transition: background .15s; }
.ld__action:last-child { border-bottom: none; }
.ld__action:hover { background: #f8fafc; }
.ld__action-icon { width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: .95rem; flex-shrink: 0; }
.ld__action-body { flex: 1; }
.ld__action-label { font-size: .875rem; font-weight: 700; color: #0f172a; }
.ld__action-hint { font-size: .75rem; color: #94a3b8; margin-top: .1rem; }
.ld__action-arrow { color: #cbd5e1; font-size: .85rem; transition: color .15s, transform .15s; }
.ld__action:hover .ld__action-arrow { color: #0f172a; transform: translateX(2px); }

/* Loading */
.ld__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.ld__ring { width: 24px; height: 24px; border: 2px solid #e2e8f0; border-top-color: #7c3aed; border-radius: 50%; animation: ld-spin .7s linear infinite; }
@keyframes ld-spin { to { transform: rotate(360deg); } }

/* Buttons */
.ld__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: var(--brand-primary, #1b5e20); color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; text-decoration: none; transition: background .15s; white-space: nowrap; }
.ld__btn-primary:hover { background: #144a18; }
.ld__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #0369a1; border: 1.5px solid #bfdbfe; padding: .6rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; text-decoration: none; transition: all .15s; white-space: nowrap; }
.ld__btn-secondary:hover { background: #eff6ff; }
</style>
