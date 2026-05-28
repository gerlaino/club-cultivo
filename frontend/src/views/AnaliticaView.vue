<script setup>
import { ref, computed, onMounted } from 'vue'
import { getAnalyticsRendimiento, getAnalyticsProduccion } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const tab        = ref('geneticas')
const loading    = ref(false)
const dataRend   = ref(null)
const dataProd   = ref(null)
const añoFiltro  = ref(null)

const añoActual = new Date().getFullYear()
const años = [null, ...Array.from({ length: 4 }, (_, i) => añoActual - i)]

async function cargar(bust = false) {
  loading.value = true
  const params = {}
  if (añoFiltro.value) params.año = añoFiltro.value
  if (bust) params.bust = true
  try {
    const [r, p] = await Promise.all([getAnalyticsRendimiento(params), getAnalyticsProduccion(params)])
    dataRend.value = r.data
    dataProd.value = p.data
  } catch {
    // silent
  } finally {
    loading.value = false
  }
}

function setAño(y) {
  añoFiltro.value = y
  cargar()
}

onMounted(cargar)

// ── Exportaciones ─────────────────────────────────────────────────
function downloadCsv(filename, rows) {
  const csv = rows.map(r => r.map(v => `"${String(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
  const url  = URL.createObjectURL(blob)
  const a    = document.createElement('a')
  a.href = url; a.download = filename; a.click()
  URL.revokeObjectURL(url)
}

function exportCsvGeneticas() {
  const headers = ['Genética','Lotes total','Activos','Rend. prom. (g)','Objetivo prom. (g)','Desvío %','Merma %']
  const rows = [headers, ...porGenetica.value.map(g => [
    g.nombre, g.lotes_total, g.lotes_activos ?? 0,
    g.rendimiento_promedio ?? '', g.objetivo_promedio ?? '',
    g.desviacion_promedio ?? '', g.merma_promedio_pct ?? '',
  ])]
  downloadCsv(`analitica_geneticas_${fechaHoy()}.csv`, rows)
}

function exportCsvCiclos() {
  const headers = ['Genética','Lotes con datos','Vegetativo (d)','Floración (d)','Cosecha (d)','Manicura (d)','Curado (d)','Total (d)']
  const rows = [headers, ...ciclos.value.map(c => [
    c.nombre, c.lotes_con_datos,
    c.vegetativo ?? '', c.floracion ?? '', c.cosecha ?? '', c.secado ?? '', c.curado ?? '',
    totalCiclo(c),
  ])]
  downloadCsv(`analitica_ciclos_${fechaHoy()}.csv`, rows)
}

function exportCsvPerdidas() {
  const headers = ['Genética','Lotes','Merma prom. %','Descarte prom. %']
  const rows = [headers, ...perdidas.value.map(g => [
    g.nombre, g.lotes_count, g.merma_promedio ?? '', g.descarte_promedio ?? '',
  ])]
  downloadCsv(`analitica_perdidas_${fechaHoy()}.csv`, rows)
}

async function exportPdf() {
  const el = document.getElementById('an-tab-content')
  if (!el) return
  const fecha = fechaHoy()
  const opt = {
    margin:      [8, 8, 8, 8],
    filename:    `analitica_${tab.value}_${fecha}.pdf`,
    image:       { type: 'jpeg', quality: 0.95 },
    html2canvas: { scale: 2, useCORS: true },
    jsPDF:       { unit: 'mm', format: 'a4', orientation: 'landscape' },
  }
  const { default: html2pdf } = await import('html2pdf.js')
  await html2pdf().set(opt).from(el).save()
}

function fechaHoy() {
  return new Date().toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }).replace(/\//g, '-')
}

// ── Helpers ──────────────────────────────────────────────────────
const ESTADO_COLOR = {
  vegetativo: { bg: 'rgba(45,138,107,.12)', color: '#1b5e20' },
  floracion:  { bg: 'rgba(217,119,6,.12)',  color: '#b45309' },
  cosecha:    { bg: 'rgba(91,100,115,.1)',  color: '#475569' },
  secado:     { bg: 'rgba(91,100,115,.1)',  color: '#475569' },
  curado:     { bg: 'rgba(139,92,246,.1)',  color: '#7c3aed' },
  finalizado: { bg: '#f1f5f9',              color: '#94a3b8' },
}
function estadoStyle(e) { return ESTADO_COLOR[e] || ESTADO_COLOR.finalizado }
function fmt(v, u = 'g') { return v != null ? `${v} ${u}` : '—' }
function fmtDias(v) { return v != null ? `${v} d` : '—' }
function fmtPct(v) { return v != null ? `${v}%` : '—' }

// ── Genéticas — datos derivados ──────────────────────────────────
const porGenetica    = computed(() => dataRend.value?.por_genetica ?? [])
const lotesRecientes = computed(() => dataRend.value?.lotes_recientes ?? [])
const resumen        = computed(() => dataRend.value?.resumen ?? {})

const maxRendimiento = computed(() =>
  Math.max(...porGenetica.value.map(g => Math.max(g.rendimiento_promedio || 0, g.objetivo_promedio || 0)), 1)
)
function barPct(val) { return val != null ? Math.min((val / maxRendimiento.value) * 100, 100) : 0 }

// ── Ciclos ───────────────────────────────────────────────────────
const ciclos = computed(() => dataProd.value?.ciclos ?? [])
const FASES_CICLO = ['vegetativo', 'floracion', 'cosecha', 'secado', 'curado']
function totalCiclo(c) {
  return FASES_CICLO.reduce((s, f) => s + (c[f] ?? 0), 0).toFixed(1)
}

// ── Pérdidas ─────────────────────────────────────────────────────
const perdidas = computed(() => dataProd.value?.perdidas ?? [])
const expandida = ref(null)
function toggleExpand(id) { expandida.value = expandida.value === id ? null : id }

// ── Comparativa ──────────────────────────────────────────────────
const comparativa = computed(() => dataProd.value?.comparativa ?? [])
</script>

<template>
  <div class="an">
    <div class="an__header">
      <div>
        <h1 class="an__title">Analítica de producción</h1>
        <p class="an__sub">Rendimiento, ciclos y pérdidas por cepa</p>
      </div>
      <div class="an__header-right">
        <div class="an__year-filter">
          <button
            v-for="y in años" :key="y ?? 'all'"
            class="an__year-btn"
            :class="{ 'an__year-btn--active': añoFiltro === y }"
            @click="setAño(y)"
          >{{ y ?? 'Todos' }}</button>
        </div>
        <button class="an__refresh" @click="cargar(true)" :disabled="loading" title="Forzar actualización">
          <i class="bi bi-arrow-clockwise" :class="{ 'an__spin': loading }"></i>
        </button>
      </div>
    </div>

    <!-- Tabs -->
    <div class="an__tabs-row">
      <div class="an__tabs">
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'geneticas' }" @click="tab = 'geneticas'">
          <i class="bi bi-graph-up-arrow"></i> Genéticas
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'ciclos' }" @click="tab = 'ciclos'">
          <i class="bi bi-clock-history"></i> Ciclos
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'perdidas' }" @click="tab = 'perdidas'">
          <i class="bi bi-exclamation-triangle"></i> Pérdidas
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'comparativa' }" @click="tab = 'comparativa'">
          <i class="bi bi-bar-chart-steps"></i> Comparativa
        </button>
      </div>
      <div v-if="dataRend || dataProd" class="an__export-btns">
        <button class="an__export-btn" @click="tab === 'geneticas' ? exportCsvGeneticas() : tab === 'ciclos' ? exportCsvCiclos() : tab === 'perdidas' ? exportCsvPerdidas() : null"
                :disabled="tab === 'comparativa'">
          <i class="bi bi-filetype-csv"></i> CSV
        </button>
        <button class="an__export-btn an__export-btn--pdf" @click="exportPdf">
          <i class="bi bi-file-earmark-pdf"></i> PDF
        </button>
      </div>
    </div>

    <div v-if="loading && !dataRend" class="an__loading">
      <DsSpinner /> Cargando analítica…
    </div>

    <div id="an-tab-content">

    <!-- ══ TAB GENÉTICAS ════════════════════════════════════════════ -->
    <template v-if="tab === 'geneticas' && dataRend">
      <div class="an__kpis">
        <div class="an__kpi">
          <span class="an__kpi-val">{{ resumen.lotes_totales ?? '—' }}</span>
          <span class="an__kpi-lbl">Lotes en sistema</span>
        </div>
        <div class="an__kpi">
          <span class="an__kpi-val">{{ resumen.lotes_finalizados ?? '—' }}</span>
          <span class="an__kpi-lbl">Finalizados</span>
        </div>
        <div class="an__kpi">
          <span class="an__kpi-val">{{ resumen.geneticas_activas ?? '—' }}</span>
          <span class="an__kpi-lbl">Genéticas activas</span>
        </div>
        <div class="an__kpi an__kpi--green">
          <span class="an__kpi-val">{{ resumen.rendimiento_global_g != null ? `${resumen.rendimiento_global_g} g` : '—' }}</span>
          <span class="an__kpi-lbl">Rendimiento promedio</span>
        </div>
      </div>

      <!-- Chart visual -->
      <div v-if="porGenetica.length" class="an__card" style="margin-bottom:1.25rem">
        <div class="an__card-header">
          <span class="an__card-title">Comparación visual</span>
          <div class="an__legend">
            <span class="an__legend-dot an__legend-dot--real"></span><span class="an__legend-lbl">Real</span>
            <span class="an__legend-dot an__legend-dot--obj"></span><span class="an__legend-lbl">Objetivo</span>
          </div>
        </div>
        <div class="an__chart-body">
          <div v-for="g in porGenetica" :key="g.genetica_id" class="an__chart-row">
            <span class="an__chart-lbl" :title="g.nombre">{{ g.nombre }}</span>
            <div class="an__chart-bars-wrap">
              <div class="an__chart-track">
                <div class="an__bar-real" :style="{ width: barPct(g.rendimiento_promedio) + '%' }"></div>
              </div>
              <div class="an__chart-track">
                <div class="an__bar-obj" :style="{ width: barPct(g.objetivo_promedio) + '%' }"></div>
              </div>
            </div>
            <span class="an__chart-val">{{ fmt(g.rendimiento_promedio) }}</span>
          </div>
        </div>
      </div>

      <!-- Tabla -->
      <div class="an__card">
        <div class="an__card-header">
          <span class="an__card-title">Rendimiento por genética</span>
        </div>
        <div v-if="!porGenetica.length" class="an__empty">
          Sin datos. Los lotes necesitan tener rendimiento real registrado.
        </div>
        <div v-else class="an__table-wrap">
          <table class="an__table">
            <thead>
              <tr>
                <th>Genética</th>
                <th class="an__th-r">Lotes</th>
                <th class="an__th-r">Activos</th>
                <th class="an__th-r">Rend. prom.</th>
                <th class="an__th-r">g/planta</th>
                <th class="an__th-r">Objetivo</th>
                <th class="an__th-r">Desvío</th>
                <th class="an__th-r">Merma %</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="g in porGenetica" :key="g.genetica_id">
                <td class="an__td-bold">{{ g.nombre }}</td>
                <td class="an__td-r">{{ g.lotes_total }}</td>
                <td class="an__td-r">
                  <span v-if="g.lotes_activos" class="an__pill an__pill--green">{{ g.lotes_activos }}</span>
                  <span v-else class="an__nd">—</span>
                </td>
                <td class="an__td-r an__td-bold">{{ fmt(g.rendimiento_promedio) }}</td>
                <td class="an__td-r an__td-muted">{{ g.g_por_planta != null ? g.g_por_planta + ' g' : '—' }}</td>
                <td class="an__td-r">{{ fmt(g.objetivo_promedio) }}</td>
                <td class="an__td-r">
                  <span v-if="g.desviacion_promedio != null" class="an__desv" :class="g.desviacion_promedio >= 0 ? 'an__desv--pos' : 'an__desv--neg'">
                    {{ g.desviacion_promedio >= 0 ? '+' : '' }}{{ g.desviacion_promedio }}%
                  </span>
                  <span v-else class="an__nd">—</span>
                </td>
                <td class="an__td-r">
                  <span v-if="g.merma_promedio_pct != null" class="an__desv" :class="g.merma_promedio_pct > 20 ? 'an__desv--neg' : 'an__desv--pos'">
                    {{ g.merma_promedio_pct }}%
                  </span>
                  <span v-else class="an__nd">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="an__card" style="margin-top:1.25rem">
        <div class="an__card-header"><span class="an__card-title">Lotes recientes</span></div>
        <div class="an__table-wrap">
          <table class="an__table">
            <thead>
              <tr>
                <th>Código</th>
                <th>Genética</th>
                <th>Estado</th>
                <th class="an__th-r">Plantas</th>
                <th class="an__th-r">Real</th>
                <th class="an__th-r">g/planta</th>
                <th class="an__th-r">Objetivo</th>
                <th class="an__th-r">Desvío</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="l in lotesRecientes" :key="l.id">
                <td>
                  <RouterLink :to="`/lotes/${l.id}`" class="an__link">{{ l.codigo }}</RouterLink>
                </td>
                <td class="an__td-muted">{{ l.genetica || '—' }}</td>
                <td>
                  <span class="an__badge" :style="{ background: estadoStyle(l.estado).bg, color: estadoStyle(l.estado).color }">{{ l.estado }}</span>
                </td>
                <td class="an__td-r">{{ l.plants_count ?? '—' }}</td>
                <td class="an__td-r an__td-bold">{{ fmt(l.rendimiento_real_g) }}</td>
                <td class="an__td-r an__td-muted">{{ l.g_por_planta != null ? l.g_por_planta + ' g' : '—' }}</td>
                <td class="an__td-r">{{ fmt(l.rendimiento_obj_g) }}</td>
                <td class="an__td-r">
                  <span v-if="l.desv_pct != null" class="an__desv" :class="l.desv_pct >= 0 ? 'an__desv--pos' : 'an__desv--neg'">
                    {{ l.desv_pct >= 0 ? '+' : '' }}{{ l.desv_pct }}%
                  </span>
                  <span v-else class="an__nd">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- ══ TAB CICLOS ═══════════════════════════════════════════════ -->
    <template v-if="tab === 'ciclos' && dataProd">
      <div class="an__info-box">
        <i class="bi bi-info-circle"></i>
        Días promedio que cada cepa pasa en cada fase del ciclo, calculados a partir de los eventos de transición registrados.
        Los lotes sin eventos de fase son excluidos.
      </div>

      <div v-if="!ciclos.length" class="an__empty-lg">
        <i class="bi bi-clock-history"></i>
        <p>Sin datos de ciclos aún.</p>
        <span>Se registran automáticamente al avanzar fases de lotes.</span>
      </div>

      <div v-else class="an__card">
        <div class="an__card-header"><span class="an__card-title">Días promedio por fase por cepa</span></div>
        <div class="an__table-wrap">
          <table class="an__table">
            <thead>
              <tr>
                <th>Genética</th>
                <th class="an__th-r">Lotes</th>
                <th class="an__th-r">Vegetativo</th>
                <th class="an__th-r">Floración</th>
                <th class="an__th-r">Cosecha</th>
                <th class="an__th-r">Manicura</th>
                <th class="an__th-r">Curado</th>
                <th class="an__th-r an__th-total">Total ciclo</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="c in ciclos" :key="c.genetica_id">
                <td class="an__td-bold">{{ c.nombre }}</td>
                <td class="an__td-r an__td-muted">{{ c.lotes_con_datos }}</td>
                <td class="an__td-r"><span class="an__fase-chip an__fase-chip--veg">{{ fmtDias(c.vegetativo) }}</span></td>
                <td class="an__td-r"><span class="an__fase-chip an__fase-chip--flo">{{ fmtDias(c.floracion) }}</span></td>
                <td class="an__td-r"><span class="an__fase-chip an__fase-chip--cos">{{ fmtDias(c.cosecha) }}</span></td>
                <td class="an__td-r"><span class="an__fase-chip an__fase-chip--sec">{{ fmtDias(c.secado) }}</span></td>
                <td class="an__td-r"><span class="an__fase-chip an__fase-chip--cur">{{ fmtDias(c.curado) }}</span></td>
                <td class="an__td-r an__td-bold">{{ totalCiclo(c) }} d</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- ══ TAB PÉRDIDAS ═════════════════════════════════════════════ -->
    <template v-if="tab === 'perdidas' && dataProd">
      <div class="an__info-box">
        <i class="bi bi-info-circle"></i>
        Tasa de plantas no cosechadas respecto al total inicial del lote. Incluye descartadas + no registradas como cosechadas.
      </div>

      <div v-if="!perdidas.length" class="an__empty-lg">
        <i class="bi bi-exclamation-triangle"></i>
        <p>Sin datos de pérdidas aún.</p>
        <span>Se calculan a partir de lotes con plants_count registrado.</span>
      </div>

      <template v-else>
        <!-- Ranking visual -->
        <div class="an__rank-grid">
          <div v-for="g in perdidas" :key="g.genetica_id" class="an__rank-card">
            <div class="an__rank-header">
              <span class="an__rank-nombre">{{ g.nombre }}</span>
              <span class="an__rank-lotes">{{ g.lotes_count }} lotes</span>
            </div>
            <div class="an__rank-bar-wrap">
              <div class="an__rank-bar" :style="{
                width: Math.min(g.merma_promedio || 0, 100) + '%',
                background: (g.merma_promedio || 0) > 25 ? '#dc2626' : (g.merma_promedio || 0) > 15 ? '#f59e0b' : '#16a34a'
              }"></div>
            </div>
            <div class="an__rank-vals">
              <span class="an__rank-pct" :style="{ color: (g.merma_promedio || 0) > 25 ? '#dc2626' : (g.merma_promedio || 0) > 15 ? '#b45309' : '#15803d' }">
                {{ fmtPct(g.merma_promedio) }}
              </span>
              <span class="an__rank-sub">merma promedio</span>
            </div>
            <button class="an__rank-toggle" @click="toggleExpand(g.genetica_id)">
              {{ expandida === g.genetica_id ? 'Ocultar detalle' : 'Ver por lote' }}
              <i :class="expandida === g.genetica_id ? 'bi bi-chevron-up' : 'bi bi-chevron-down'"></i>
            </button>
            <div v-if="expandida === g.genetica_id" class="an__rank-detail">
              <table class="an__table an__table--compact">
                <thead>
                  <tr>
                    <th>Lote</th>
                    <th class="an__th-r">Total</th>
                    <th class="an__th-r">Cosechadas</th>
                    <th class="an__th-r">Descartadas</th>
                    <th class="an__th-r">Merma %</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="l in g.por_lote" :key="l.lote_id">
                    <td>
                      <RouterLink :to="`/lotes/${l.lote_id}`" class="an__link">{{ l.lote_codigo }}</RouterLink>
                    </td>
                    <td class="an__td-r">{{ l.total }}</td>
                    <td class="an__td-r">{{ l.cosechadas }}</td>
                    <td class="an__td-r">
                      <span :style="{ color: l.descartadas > 0 ? '#dc2626' : '#94a3b8' }">{{ l.descartadas }}</span>
                    </td>
                    <td class="an__td-r">
                      <span class="an__desv" :class="(l.merma_pct || 0) > 20 ? 'an__desv--neg' : 'an__desv--pos'">
                        {{ fmtPct(l.merma_pct) }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </template>
    </template>

    <!-- ══ TAB COMPARATIVA ══════════════════════════════════════════ -->
    <template v-if="tab === 'comparativa' && dataProd">
      <div class="an__info-box">
        <i class="bi bi-info-circle"></i>
        Lotes finalizados de la misma cepa comparados entre sí. Solo aparecen cepas con 2 o más lotes finalizados.
      </div>

      <div v-if="!comparativa.length" class="an__empty-lg">
        <i class="bi bi-bar-chart-steps"></i>
        <p>Sin datos comparativos aún.</p>
        <span>Se necesitan al menos 2 lotes finalizados de la misma cepa.</span>
      </div>

      <div v-for="c in comparativa" :key="c.genetica_id" class="an__card" style="margin-bottom:1.25rem">
        <div class="an__card-header">
          <span class="an__card-title">{{ c.nombre }}</span>
          <span class="an__pill an__pill--muted">{{ c.lotes.length }} lotes</span>
        </div>
        <div class="an__comp-grid">
          <div v-for="l in c.lotes" :key="l.id" class="an__comp-card">
            <RouterLink :to="`/lotes/${l.id}`" class="an__comp-codigo">{{ l.codigo }}</RouterLink>
            <div class="an__comp-rend">
              <strong>{{ fmt(l.rendimiento_g) }}</strong>
              <span v-if="l.objetivo_g" class="an__comp-obj">/ obj {{ fmt(l.objetivo_g) }}</span>
            </div>
            <div class="an__comp-meta">
              <span v-if="l.plants_count">🌿 {{ l.plants_count }} plantas</span>
              <span v-if="l.grow_type">· {{ l.grow_type }}</span>
              <span v-if="l.light_type">· {{ l.light_type }}</span>
            </div>
            <div v-if="l.start_date" class="an__comp-fecha">
              {{ new Date(l.start_date).toLocaleDateString('es-AR', { month: 'short', year: 'numeric' }) }}
            </div>
          </div>
        </div>
      </div>
    </template>

    </div><!-- /#an-tab-content -->

  </div>
</template>

<style scoped>
.an { padding: 1.75rem 1.75rem 3rem; max-width: 1100px; margin: 0 auto; }
@media (max-width: 767px) { .an { padding: 1.25rem 1rem 2rem; } }

.an__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.an__title { font-size: 1.6rem; font-weight: 800; color: #0f172a; margin: 0; letter-spacing: -.03em; }
.an__sub { font-size: .82rem; color: #64748b; margin: .2rem 0 0; }
.an__header-right { display: flex; align-items: center; gap: .75rem; flex-shrink: 0; }
.an__refresh { background: #f1f5f9; border: none; border-radius: 8px; padding: .5rem .65rem; cursor: pointer; color: #64748b; font-size: .9rem; transition: all .15s; }
.an__refresh:hover { background: #e2e8f0; color: #0f172a; }
.an__spin { display: inline-block; animation: an-spin .7s linear infinite; }
@keyframes an-spin { to { transform: rotate(360deg); } }

/* Year filter */
.an__year-filter { display: flex; gap: .25rem; }
.an__year-btn { padding: .3rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 6px; background: #fff; font-size: .75rem; font-weight: 600; color: #64748b; cursor: pointer; transition: all .15s; white-space: nowrap; }
.an__year-btn:hover { border-color: #1b5e20; color: #1b5e20; }
.an__year-btn--active { background: #1b5e20; border-color: #1b5e20; color: #fff; }

/* Chart visual */
.an__legend { display: flex; align-items: center; gap: .6rem; }
.an__legend-dot { width: 10px; height: 10px; border-radius: 3px; }
.an__legend-dot--real { background: #15803d; }
.an__legend-dot--obj  { background: #93c5fd; }
.an__legend-lbl { font-size: .72rem; color: #64748b; }
.an__chart-body { padding: .75rem 1.1rem 1rem; display: flex; flex-direction: column; gap: .55rem; }
.an__chart-row { display: grid; grid-template-columns: 140px 1fr 72px; align-items: center; gap: .75rem; }
@media (max-width: 640px) { .an__chart-row { grid-template-columns: 100px 1fr 60px; } }
.an__chart-lbl { font-size: .78rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.an__chart-bars-wrap { display: flex; flex-direction: column; gap: .2rem; }
.an__chart-track { height: 8px; background: #f1f5f9; border-radius: 999px; overflow: hidden; }
.an__bar-real { height: 100%; border-radius: 999px; background: #15803d; transition: width .5s ease; }
.an__bar-obj  { height: 100%; border-radius: 999px; background: #93c5fd; transition: width .5s ease; }
.an__chart-val { font-size: .8rem; font-weight: 700; color: #0f172a; text-align: right; }

/* Tabs */
.an__tabs-row { display: flex; align-items: flex-end; justify-content: space-between; border-bottom: 2px solid #e2e8f0; margin-bottom: 1.75rem; gap: .5rem; flex-wrap: wrap; }
.an__tabs { display: flex; gap: .25rem; flex-wrap: wrap; }
.an__tab { display: flex; align-items: center; gap: .4rem; padding: .65rem 1rem; font-size: .875rem; font-weight: 600; color: #64748b; background: none; border: none; border-bottom: 2.5px solid transparent; margin-bottom: -2px; cursor: pointer; transition: all .15s; white-space: nowrap; }
.an__tab:hover { color: #0f172a; }
.an__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }
.an__export-btns { display: flex; gap: .4rem; padding-bottom: .35rem; flex-shrink: 0; }
.an__export-btn { display: inline-flex; align-items: center; gap: .35rem; padding: .4rem .8rem; border: 1.5px solid #e2e8f0; border-radius: 7px; background: #f8fafc; font-size: .75rem; font-weight: 600; color: #64748b; cursor: pointer; transition: all .15s; white-space: nowrap; }
.an__export-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; background: rgba(27,94,32,.05); }
.an__export-btn:disabled { opacity: .4; cursor: not-allowed; }
.an__export-btn--pdf { color: #b91c1c; border-color: #fecaca; background: #fff5f5; }
.an__export-btn--pdf:hover:not(:disabled) { background: #fef2f2; border-color: #b91c1c; }

/* Loading */
.an__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }

/* KPIs */
.an__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 1rem; margin-bottom: 1.75rem; }
.an__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 1.1rem; text-align: center; }
.an__kpi-val { display: block; font-size: 1.8rem; font-weight: 800; color: #0f172a; line-height: 1; letter-spacing: -.04em; }
.an__kpi-lbl { display: block; font-size: .7rem; color: #94a3b8; margin-top: .35rem; font-weight: 600; text-transform: uppercase; letter-spacing: .03em; }
.an__kpi--green .an__kpi-val { color: #15803d; }

/* Card */
.an__card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.an__card-header { display: flex; align-items: center; justify-content: space-between; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }
.an__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; }

/* Tables */
.an__table-wrap { overflow-x: auto; }
.an__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.an__table th { text-align: left; padding: .65rem 1rem; background: #fafbfc; font-weight: 600; color: #64748b; font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1.5px solid #f1f5f9; white-space: nowrap; }
.an__th-r { text-align: right; }
.an__th-total { color: #0f172a; }
.an__table td { padding: .7rem 1rem; border-bottom: 1px solid #f8fafc; color: #0f172a; }
.an__table tbody tr:last-child td { border-bottom: none; }
.an__table--compact td, .an__table--compact th { padding: .5rem .75rem; }
.an__td-r { text-align: right; }
.an__td-bold { font-weight: 700; }
.an__td-muted { color: #94a3b8; font-size: .78rem; }
.an__nd { color: #cbd5e1; }

/* Badges + pills */
.an__badge { display: inline-block; padding: .15em .55em; border-radius: 999px; font-size: .68rem; font-weight: 700; }
.an__pill { font-size: .65rem; font-weight: 800; padding: .15em .55em; border-radius: 999px; }
.an__pill--green { background: rgba(21,128,61,.1); color: #15803d; }
.an__pill--muted { background: #f1f5f9; color: #64748b; }
.an__desv { font-weight: 700; font-size: .78rem; }
.an__desv--pos { color: #15803d; }
.an__desv--neg { color: #dc2626; }
.an__link { color: #1b5e20; font-weight: 600; text-decoration: none; font-family: monospace; font-size: .8rem; }
.an__link:hover { text-decoration: underline; }

/* Info box */
.an__info-box { display: flex; align-items: flex-start; gap: .6rem; background: #f0f9ff; border: 1px solid #bae6fd; border-radius: 10px; padding: .875rem 1rem; font-size: .8rem; color: #0369a1; margin-bottom: 1.25rem; line-height: 1.5; }
.an__info-box i { flex-shrink: 0; margin-top: .1rem; }

/* Empty states */
.an__empty { color: #94a3b8; font-size: .875rem; background: #f8fafc; padding: 2rem; text-align: center; border-radius: 10px; }
.an__empty-lg { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 4rem; color: #94a3b8; text-align: center; }
.an__empty-lg i { font-size: 2.5rem; opacity: .35; }
.an__empty-lg p { font-size: .95rem; font-weight: 600; color: #64748b; margin: 0; }
.an__empty-lg span { font-size: .8rem; }

/* Ciclos — chips por fase */
.an__fase-chip { display: inline-block; padding: .15em .55em; border-radius: 6px; font-size: .75rem; font-weight: 600; }
.an__fase-chip--veg { background: rgba(21,128,61,.1); color: #15803d; }
.an__fase-chip--flo { background: rgba(217,119,6,.1); color: #b45309; }
.an__fase-chip--cos { background: rgba(91,100,115,.1); color: #475569; }
.an__fase-chip--sec { background: rgba(99,102,241,.1); color: #4338ca; }
.an__fase-chip--cur { background: rgba(124,58,237,.1); color: #7c3aed; }

/* Pérdidas — ranking cards */
.an__rank-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }
.an__rank-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.1rem; }
.an__rank-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .75rem; }
.an__rank-nombre { font-size: .9rem; font-weight: 700; color: #0f172a; }
.an__rank-lotes { font-size: .72rem; color: #94a3b8; }
.an__rank-bar-wrap { height: 6px; background: #f1f5f9; border-radius: 999px; overflow: hidden; margin-bottom: .5rem; }
.an__rank-bar { height: 100%; border-radius: 999px; transition: width .4s; }
.an__rank-vals { display: flex; align-items: baseline; gap: .4rem; margin-bottom: .75rem; }
.an__rank-pct { font-size: 1.6rem; font-weight: 800; letter-spacing: -.04em; }
.an__rank-sub { font-size: .72rem; color: #94a3b8; }
.an__rank-toggle { display: flex; align-items: center; gap: .35rem; font-size: .75rem; color: #0369a1; background: none; border: none; cursor: pointer; padding: 0; font-weight: 600; transition: color .15s; }
.an__rank-toggle:hover { color: #0c4a6e; }
.an__rank-detail { margin-top: .75rem; padding-top: .75rem; border-top: 1px solid #f1f5f9; overflow-x: auto; }

/* Comparativa */
.an__comp-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: .75rem; padding: 1rem 1.1rem; }
.an__comp-card { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .875rem; display: flex; flex-direction: column; gap: .35rem; }
.an__comp-codigo { font-family: monospace; font-size: .8rem; font-weight: 700; color: #1b5e20; text-decoration: none; }
.an__comp-codigo:hover { text-decoration: underline; }
.an__comp-rend { font-size: 1.3rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; }
.an__comp-obj { font-size: .75rem; color: #94a3b8; font-weight: 400; }
.an__comp-meta { font-size: .72rem; color: #64748b; }
.an__comp-fecha { font-size: .7rem; color: #94a3b8; margin-top: .15rem; }
</style>
