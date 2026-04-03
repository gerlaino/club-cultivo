<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listSocios, listIndicaciones } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'

const router = useRouter()
const auth   = useAuthStore()

const loading   = ref(true)
const socios    = ref([])
const indicaciones = ref([])

// ── Computed ──────────────────────────────────────────────────
const hoy = new Date()

function diasHasta(fecha) {
  if (!fecha) return null
  return Math.ceil((new Date(fecha) - hoy) / 86400000)
}

function formatFecha(fecha) {
  if (!fecha) return '—'
  return new Date(fecha).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function urgenciaBadge(dias) {
  if (dias === null) return null
  if (dias < 0)   return { label: 'Vencido',     color: '#dc2626', bg: '#fef2f2', border: '#fecaca' }
  if (dias <= 30) return { label: `${dias}d`,     color: '#b45309', bg: '#fffbeb', border: '#fde68a' }
  if (dias <= 90) return { label: `${dias}d`,     color: '#0369a1', bg: '#eff6ff', border: '#bfdbfe' }
  return null
}

const kpis = computed(() => {
  const activos   = socios.value.length
  const repVenc   = socios.value.filter(s => { const d = diasHasta(s.reprocann_vencimiento); return d !== null && d < 0 }).length
  const repProx   = socios.value.filter(s => { const d = diasHasta(s.reprocann_vencimiento); return d !== null && d >= 0 && d <= 30 }).length
  const indActivas = indicaciones.value.filter(i => i.activa).length
  const indVenc   = indicaciones.value.filter(i => { const d = diasHasta(i.fecha_vencimiento); return d !== null && d < 0 && i.activa }).length
  const indProx   = indicaciones.value.filter(i => { const d = diasHasta(i.fecha_vencimiento); return d !== null && d >= 0 && d <= 30 && i.activa }).length
  const inicioMes = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  const indMes    = indicaciones.value.filter(i => i.fecha_emision && new Date(i.fecha_emision) >= inicioMes).length
  return { activos, repVenc, repProx, indActivas, indVenc, indProx, indMes }
})

const alertasReprocann = computed(() =>
  socios.value
    .map(s => ({ ...s, dias: diasHasta(s.reprocann_vencimiento) }))
    .filter(s => s.dias !== null && s.dias <= 90)
    .sort((a, b) => a.dias - b.dias)
    .slice(0, 8)
)

const alertasIndicaciones = computed(() =>
  indicaciones.value
    .filter(i => i.activa)
    .map(i => ({ ...i, dias: diasHasta(i.fecha_vencimiento) }))
    .filter(i => i.dias !== null && i.dias <= 90)
    .sort((a, b) => a.dias - b.dias)
    .slice(0, 8)
)

const ultimasIndicaciones = computed(() =>
  [...indicaciones.value]
    .sort((a, b) => new Date(b.fecha_emision) - new Date(a.fecha_emision))
    .slice(0, 6)
)

// ── Carga ─────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const { data } = await listSocios()
    socios.value = Array.isArray(data) ? data : []

    if (socios.value.length > 0) {
      const results = await Promise.all(
        socios.value.map(s =>
          listIndicaciones(s.id)
            .then(r => (r.data || []).map(i => ({
              ...i,
              socio_id:     s.id,
              socio_nombre: `${s.nombre} ${s.apellido}`,
              socio_dni:    s.dni,
            })))
            .catch(() => [])
        )
      )
      indicaciones.value = results.flat()
    }
  } catch (e) {
    console.error('MedicoDashboard:', e)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="md">

    <!-- ── Header ───────────────────────────────────────────── -->
    <div class="md__header">
      <div class="md__header-left">
        <div class="md__eyebrow">
          <span class="md__eyebrow-dot"></span>
          Panel clínico
        </div>
        <h1 class="md__title">Buenas {{ new Date().getHours() < 13 ? 'mañanas' : new Date().getHours() < 20 ? 'tardes' : 'noches' }}, {{ auth.user?.first_name }}</h1>
        <p class="md__subtitle">
          {{ new Date().toLocaleDateString('es-AR', { weekday:'long', day:'numeric', month:'long', year:'numeric' }) }}
          · Médico tratante
        </p>
      </div>
    </div>

    <!-- ── Loading ───────────────────────────────────────────── -->
    <div v-if="loading" class="md__loading">
      <div class="md__ring"></div>
      <span>Cargando datos clínicos…</span>
    </div>

    <template v-else>

      <!-- ── KPIs ──────────────────────────────────────────── -->
      <div class="md__kpis">

        <div class="md__kpi md__kpi--main" @click="router.push('/socios')">
          <div class="md__kpi-icon" style="background:rgba(27,94,32,.1);color:#1b5e20">
            <i class="bi bi-people"></i>
          </div>
          <div class="md__kpi-body">
            <div class="md__kpi-val">{{ kpis.activos }}</div>
            <div class="md__kpi-lbl">Pacientes activos</div>
          </div>
          <i class="bi bi-arrow-right md__kpi-arrow"></i>
        </div>

        <div class="md__kpi" :class="kpis.indActivas > 0 ? 'md__kpi--ok' : ''">
          <div class="md__kpi-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
            <i class="bi bi-file-medical"></i>
          </div>
          <div class="md__kpi-body">
            <div class="md__kpi-val">{{ kpis.indActivas }}</div>
            <div class="md__kpi-lbl">Indicaciones vigentes</div>
          </div>
          <div class="md__kpi-sub">{{ kpis.indMes }} este mes</div>
        </div>

        <div class="md__kpi" :class="kpis.repVenc > 0 ? 'md__kpi--danger' : kpis.repProx > 0 ? 'md__kpi--warn' : 'md__kpi--ok'">
          <div class="md__kpi-icon"
               :style="kpis.repVenc > 0 ? 'background:rgba(220,38,38,.1);color:#dc2626' : kpis.repProx > 0 ? 'background:rgba(180,83,9,.1);color:#b45309' : 'background:rgba(21,128,61,.1);color:#15803d'">
            <i class="bi bi-patch-check"></i>
          </div>
          <div class="md__kpi-body">
            <div class="md__kpi-val">{{ kpis.repVenc + kpis.repProx }}</div>
            <div class="md__kpi-lbl">REPROCANN por atender</div>
          </div>
          <div class="md__kpi-sub" v-if="kpis.repVenc > 0" style="color:#dc2626">
            {{ kpis.repVenc }} vencido{{ kpis.repVenc > 1 ? 's' : '' }}
          </div>
          <div class="md__kpi-sub" v-else-if="kpis.repProx > 0" style="color:#b45309">
            {{ kpis.repProx }} en 30 días
          </div>
          <div class="md__kpi-sub" v-else style="color:#15803d">Al día</div>
        </div>

        <div class="md__kpi" :class="kpis.indVenc > 0 ? 'md__kpi--danger' : kpis.indProx > 0 ? 'md__kpi--warn' : 'md__kpi--ok'">
          <div class="md__kpi-icon"
               :style="kpis.indVenc > 0 ? 'background:rgba(220,38,38,.1);color:#dc2626' : kpis.indProx > 0 ? 'background:rgba(180,83,9,.1);color:#b45309' : 'background:rgba(21,128,61,.1);color:#15803d'">
            <i class="bi bi-clock-history"></i>
          </div>
          <div class="md__kpi-body">
            <div class="md__kpi-val">{{ kpis.indVenc + kpis.indProx }}</div>
            <div class="md__kpi-lbl">Indicaciones por renovar</div>
          </div>
          <div class="md__kpi-sub" v-if="kpis.indVenc > 0" style="color:#dc2626">
            {{ kpis.indVenc }} vencida{{ kpis.indVenc > 1 ? 's' : '' }}
          </div>
          <div class="md__kpi-sub" v-else-if="kpis.indProx > 0" style="color:#b45309">
            {{ kpis.indProx }} en 30 días
          </div>
          <div class="md__kpi-sub" v-else style="color:#15803d">Al día</div>
        </div>

      </div>

      <!-- ── Layout principal ──────────────────────────────── -->
      <div class="md__layout">

        <!-- Columna izquierda -->
        <div class="md__col">

          <!-- Alertas REPROCANN -->
          <div class="md__card">
            <div class="md__card-header">
              <div class="md__card-title-wrap">
                <span class="md__card-icon" style="background:rgba(180,83,9,.1);color:#b45309">
                  <i class="bi bi-patch-exclamation"></i>
                </span>
                <span class="md__card-title">REPROCANN por vencer</span>
                <span v-if="alertasReprocann.length" class="md__badge md__badge--warn">{{ alertasReprocann.length }}</span>
              </div>
              <RouterLink to="/socios" class="md__card-link">Ver todos →</RouterLink>
            </div>

            <div v-if="!alertasReprocann.length" class="md__empty">
              <i class="bi bi-patch-check-fill md__empty-icon" style="color:#15803d"></i>
              <p>Todas las autorizaciones están al día</p>
            </div>

            <div v-else class="md__alert-list">
              <RouterLink
                v-for="s in alertasReprocann"
                :key="s.id"
                :to="`/socios/${s.id}`"
                class="md__alert-row"
                :class="s.dias < 0 ? 'md__alert-row--danger' : s.dias <= 30 ? 'md__alert-row--warn' : 'md__alert-row--info'"
              >
                <div class="md__alert-avatar">{{ s.nombre[0] }}{{ s.apellido[0] }}</div>
                <div class="md__alert-body">
                  <div class="md__alert-nombre">{{ s.nombre }} {{ s.apellido }}</div>
                  <div class="md__alert-meta">
                    DNI {{ s.dni }}
                    <span v-if="s.reprocann_numero">· #{{ s.reprocann_numero }}</span>
                  </div>
                </div>
                <div class="md__alert-badge"
                     :style="s.dias < 0 ? 'background:#fef2f2;color:#dc2626;border-color:#fecaca' : s.dias <= 30 ? 'background:#fffbeb;color:#b45309;border-color:#fde68a' : 'background:#eff6ff;color:#0369a1;border-color:#bfdbfe'">
                  {{ s.dias < 0 ? 'Vencido' : `${s.dias}d` }}
                </div>
              </RouterLink>
            </div>
          </div>

          <!-- Alertas Indicaciones -->
          <div class="md__card md__card--mt">
            <div class="md__card-header">
              <div class="md__card-title-wrap">
                <span class="md__card-icon" style="background:rgba(220,38,38,.1);color:#dc2626">
                  <i class="bi bi-file-earmark-medical"></i>
                </span>
                <span class="md__card-title">Indicaciones por renovar</span>
                <span v-if="alertasIndicaciones.length" class="md__badge md__badge--danger">{{ alertasIndicaciones.length }}</span>
              </div>
            </div>

            <div v-if="!alertasIndicaciones.length" class="md__empty">
              <i class="bi bi-file-medical-fill md__empty-icon" style="color:#15803d"></i>
              <p>Todas las indicaciones están vigentes</p>
            </div>

            <div v-else class="md__alert-list">
              <RouterLink
                v-for="ind in alertasIndicaciones"
                :key="ind.id"
                :to="`/socios/${ind.socio_id}`"
                class="md__alert-row"
                :class="ind.dias < 0 ? 'md__alert-row--danger' : ind.dias <= 30 ? 'md__alert-row--warn' : 'md__alert-row--info'"
              >
                <div class="md__alert-avatar md__alert-avatar--ind">
                  <i class="bi bi-file-text"></i>
                </div>
                <div class="md__alert-body">
                  <div class="md__alert-nombre">{{ ind.socio_nombre }}</div>
                  <div class="md__alert-meta">
                    {{ ind.patologia }}
                    <span v-if="ind.fecha_vencimiento">· vence {{ formatFecha(ind.fecha_vencimiento) }}</span>
                  </div>
                </div>
                <div class="md__alert-badge"
                     :style="ind.dias < 0 ? 'background:#fef2f2;color:#dc2626;border-color:#fecaca' : ind.dias <= 30 ? 'background:#fffbeb;color:#b45309;border-color:#fde68a' : 'background:#eff6ff;color:#0369a1;border-color:#bfdbfe'">
                  {{ ind.dias < 0 ? 'Vencida' : `${ind.dias}d` }}
                </div>
              </RouterLink>
            </div>
          </div>

        </div>

        <!-- Columna derecha -->
        <div class="md__col">

          <!-- Últimas indicaciones emitidas -->
          <div class="md__card">
            <div class="md__card-header">
              <div class="md__card-title-wrap">
                <span class="md__card-icon" style="background:rgba(3,105,161,.1);color:#0369a1">
                  <i class="bi bi-journal-medical"></i>
                </span>
                <span class="md__card-title">Indicaciones recientes</span>
              </div>
            </div>

            <div v-if="!ultimasIndicaciones.length" class="md__empty">
              <i class="bi bi-journal-plus md__empty-icon" style="color:#94a3b8"></i>
              <p>Sin indicaciones registradas</p>
            </div>

            <div v-else class="md__ind-list">
              <RouterLink
                v-for="ind in ultimasIndicaciones"
                :key="ind.id"
                :to="`/socios/${ind.socio_id}`"
                class="md__ind-row"
              >
                <div class="md__ind-left">
                  <div class="md__ind-nombre">{{ ind.socio_nombre }}</div>
                  <div class="md__ind-patologia">{{ ind.patologia }}</div>
                  <div class="md__ind-meta">
                    <span>{{ ind.via_administracion }}</span>
                    <span class="md__dot">·</span>
                    <span>{{ formatFecha(ind.fecha_emision) }}</span>
                  </div>
                </div>
                <div class="md__ind-right">
                  <span class="md__ind-estado" :class="ind.activa ? 'md__ind-estado--ok' : 'md__ind-estado--off'">
                    {{ ind.activa ? 'Vigente' : 'Inactiva' }}
                  </span>
                  <span v-if="ind.fecha_vencimiento && diasHasta(ind.fecha_vencimiento) !== null && diasHasta(ind.fecha_vencimiento) <= 90"
                        class="md__ind-venc"
                        :style="diasHasta(ind.fecha_vencimiento) < 0 ? 'color:#dc2626' : diasHasta(ind.fecha_vencimiento) <= 30 ? 'color:#b45309' : 'color:#64748b'">
                    {{ diasHasta(ind.fecha_vencimiento) < 0 ? 'Vencida' : `Vence en ${diasHasta(ind.fecha_vencimiento)}d` }}
                  </span>
                </div>
              </RouterLink>
            </div>
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.md {
  padding: 2rem 1.5rem;
  max-width: 1200px;
  margin: 0 auto;
}
@media (max-width: 768px) { .md { padding: 1.25rem 1rem; } }

/* Header */
.md__header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 2rem;
  flex-wrap: wrap;
}
.md__eyebrow {
  display: flex;
  align-items: center;
  gap: .4rem;
  font-size: .72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: .1em;
  color: #0369a1;
  margin-bottom: .35rem;
}
.md__eyebrow-dot {
  width: 6px; height: 6px;
  border-radius: 50%;
  background: #0369a1;
  animation: md-pulse 2s ease-in-out infinite;
}
@keyframes md-pulse {
  0%,100% { opacity:1; transform:scale(1); }
  50%      { opacity:.4; transform:scale(.7); }
}
.md__title {
  font-size: 2rem;
  font-weight: 800;
  color: #0f172a;
  margin: 0 0 .25rem;
  letter-spacing: -.04em;
  line-height: 1;
}
.md__subtitle {
  font-size: .83rem;
  color: #64748b;
  margin: 0;
}
.md__btn-primary {
  display: inline-flex;
  align-items: center;
  gap: .4rem;
  background: #0f172a;
  color: #fff;
  border: none;
  padding: .6rem 1.25rem;
  border-radius: 8px;
  font-size: .875rem;
  font-weight: 600;
  cursor: pointer;
  text-decoration: none;
  transition: background .15s, transform .1s;
  white-space: nowrap;
}
.md__btn-primary:hover { background: #1e293b; transform: translateY(-1px); }

/* Loading */
.md__loading {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: .75rem;
  padding: 5rem;
  color: #94a3b8;
  font-size: .875rem;
}
.md__ring {
  width: 24px; height: 24px;
  border: 2px solid #e2e8f0;
  border-top-color: #0369a1;
  border-radius: 50%;
  animation: md-spin .7s linear infinite;
}
@keyframes md-spin { to { transform: rotate(360deg); } }

/* KPIs */
.md__kpis {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
  margin-bottom: 1.75rem;
}
@media (max-width: 900px) { .md__kpis { grid-template-columns: repeat(2,1fr); } }
@media (max-width: 480px) { .md__kpis { grid-template-columns: 1fr; } }

.md__kpi {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  padding: 1.1rem 1.1rem 1rem;
  display: flex;
  flex-direction: column;
  gap: .5rem;
  position: relative;
  transition: box-shadow .15s, transform .15s;
}
.md__kpi--main { cursor: pointer; }
.md__kpi--main:hover { box-shadow: 0 4px 16px rgba(0,0,0,.07); transform: translateY(-1px); }
.md__kpi--ok     { border-color: #bbf7d0; }
.md__kpi--warn   { border-color: #fde68a; }
.md__kpi--danger { border-color: #fecaca; }

.md__kpi-icon {
  width: 38px; height: 38px;
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1rem;
  flex-shrink: 0;
}
.md__kpi-body { flex: 1; }
.md__kpi-val {
  font-size: 1.9rem;
  font-weight: 800;
  color: #0f172a;
  line-height: 1;
  letter-spacing: -.04em;
}
.md__kpi-lbl {
  font-size: .72rem;
  font-weight: 600;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: .04em;
  margin-top: .15rem;
}
.md__kpi-arrow {
  position: absolute;
  top: 1rem; right: 1rem;
  color: #cbd5e1;
  font-size: .85rem;
}
.md__kpi-sub {
  font-size: .75rem;
  font-weight: 600;
  color: #64748b;
}

/* Layout */
.md__layout {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.25rem;
  align-items: start;
}
@media (max-width: 900px) { .md__layout { grid-template-columns: 1fr; } }
.md__col { display: flex; flex-direction: column; }
.md__card--mt { margin-top: 1.25rem; }

/* Cards */
.md__card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  overflow: hidden;
}
.md__card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.1rem;
  border-bottom: 1px solid #f1f5f9;
}
.md__card-title-wrap {
  display: flex;
  align-items: center;
  gap: .6rem;
}
.md__card-icon {
  width: 32px; height: 32px;
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: .85rem;
  flex-shrink: 0;
}
.md__card-title {
  font-size: .9rem;
  font-weight: 700;
  color: #0f172a;
}
.md__card-link {
  font-size: .78rem;
  font-weight: 600;
  color: #0369a1;
  text-decoration: none;
  white-space: nowrap;
}
.md__card-link:hover { text-decoration: underline; }

/* Badges */
.md__badge {
  font-size: .65rem;
  font-weight: 800;
  padding: .15em .5em;
  border-radius: 999px;
}
.md__badge--warn   { background: #fffbeb; color: #b45309; border: 1px solid #fde68a; }
.md__badge--danger { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }

/* Empty */
.md__empty {
  text-align: center;
  padding: 2.5rem 1rem;
  color: #94a3b8;
}
.md__empty-icon {
  font-size: 2rem;
  display: block;
  margin-bottom: .75rem;
}
.md__empty p { font-size: .85rem; margin: 0; }

/* Alert rows */
.md__alert-list { display: flex; flex-direction: column; }

.md__alert-row {
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .75rem 1.1rem;
  text-decoration: none;
  color: inherit;
  border-bottom: 1px solid #f8fafc;
  transition: background .15s;
}
.md__alert-row:last-child { border-bottom: none; }
.md__alert-row:hover { background: #f8fafc; }
.md__alert-row--danger { border-left: 3px solid #dc2626; }
.md__alert-row--warn   { border-left: 3px solid #f59e0b; }
.md__alert-row--info   { border-left: 3px solid #3b82f6; }

.md__alert-avatar {
  width: 34px; height: 34px;
  border-radius: 50%;
  background: linear-gradient(135deg, #0369a1, #1b5e20);
  color: #fff;
  font-size: .72rem;
  font-weight: 800;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.md__alert-avatar--ind {
  border-radius: 8px;
  background: #f1f5f9;
  color: #64748b;
  font-size: .9rem;
}
.md__alert-body { flex: 1; min-width: 0; }
.md__alert-nombre {
  font-size: .85rem;
  font-weight: 700;
  color: #0f172a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.md__alert-meta {
  font-size: .72rem;
  color: #94a3b8;
  margin-top: .1rem;
}
.md__alert-badge {
  font-size: .72rem;
  font-weight: 800;
  padding: .25em .6em;
  border-radius: 6px;
  border: 1px solid;
  white-space: nowrap;
  flex-shrink: 0;
}

/* Indicaciones list */
.md__ind-list { display: flex; flex-direction: column; }
.md__ind-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: .75rem;
  padding: .85rem 1.1rem;
  text-decoration: none;
  color: inherit;
  border-bottom: 1px solid #f8fafc;
  transition: background .15s;
}
.md__ind-row:last-child { border-bottom: none; }
.md__ind-row:hover { background: #f8fafc; }
.md__ind-left { flex: 1; min-width: 0; }
.md__ind-nombre {
  font-size: .85rem;
  font-weight: 700;
  color: #0f172a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.md__ind-patologia {
  font-size: .78rem;
  color: #475569;
  margin-top: .1rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.md__ind-meta {
  font-size: .7rem;
  color: #94a3b8;
  margin-top: .15rem;
  display: flex;
  align-items: center;
  gap: .3rem;
}
.md__dot { color: #cbd5e1; }
.md__ind-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: .25rem;
  flex-shrink: 0;
}
.md__ind-estado {
  font-size: .68rem;
  font-weight: 700;
  padding: .15em .5em;
  border-radius: 5px;
}
.md__ind-estado--ok  { background: #dcfce7; color: #15803d; }
.md__ind-estado--off { background: #f1f5f9; color: #64748b; }
.md__ind-venc {
  font-size: .68rem;
  font-weight: 600;
}

/* Acciones rápidas */
.md__actions { display: flex; flex-direction: column; }
.md__action {
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .85rem 1.1rem;
  text-decoration: none;
  color: inherit;
  border-bottom: 1px solid #f8fafc;
  transition: background .15s;
}
.md__action:last-child { border-bottom: none; }
.md__action:hover { background: #f8fafc; }
.md__action-icon {
  width: 38px; height: 38px;
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: .95rem;
  flex-shrink: 0;
}
.md__action-body { flex: 1; }
.md__action-label {
  font-size: .875rem;
  font-weight: 700;
  color: #0f172a;
}
.md__action-hint {
  font-size: .75rem;
  color: #94a3b8;
  margin-top: .1rem;
}
.md__action-arrow {
  color: #cbd5e1;
  font-size: .85rem;
  transition: color .15s, transform .15s;
}
.md__action:hover .md__action-arrow {
  color: #0f172a;
  transform: translateX(2px);
}
</style>
