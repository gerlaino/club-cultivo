<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { getAnalyticsRendimiento, getAnalyticsProduccion, getAnalyticsCorrelacion, getAnalyticsContabilidad, getAnalyticsCostoPorGramoSede } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import Chart from 'chart.js/auto'

const tab        = ref('geneticas')
const loading    = ref(false)
const dataRend   = ref(null)
const dataProd   = ref(null)
const dataCorr   = ref(null)
const dataCont   = ref(null)
const dataCpg    = ref(null)
const añoFiltro  = ref(null)

const añoActual = new Date().getFullYear()
const años = [null, ...Array.from({ length: 4 }, (_, i) => añoActual - i)]

async function cargar(bust = false) {
  loading.value = true
  const params = {}
  if (añoFiltro.value) params.año = añoFiltro.value
  if (bust) params.bust = true
  try {
    const [r, p, c] = await Promise.all([
      getAnalyticsRendimiento(params),
      getAnalyticsProduccion(params),
      getAnalyticsCorrelacion(params),
    ])
    dataRend.value = r.data
    dataProd.value = p.data
    dataCorr.value = c.data
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

async function goTab(t) {
  tab.value = t
  if (t === 'contabilidad' && !dataCont.value) {
    try {
      const { data } = await getAnalyticsContabilidad()
      dataCont.value = data
    } catch {}
  }
  if (t === 'costo_gramo' && !dataCpg.value) {
    try {
      const { data } = await getAnalyticsCostoPorGramoSede()
      dataCpg.value = data
    } catch {}
  }
}

// ── Costo por gramo producido (por sede) ─────────────────────────
const cpgSedes = computed(() => dataCpg.value?.sedes ?? [])
const cpgTotal = computed(() => dataCpg.value?.total ?? null)
const cpgExpandida = ref(null)
function toggleCpg(id) { cpgExpandida.value = cpgExpandida.value === id ? null : id }
function fmtArs(v) { return v != null ? '$' + Math.round(v).toLocaleString('es-AR') : '—' }
function fmtG(v) { return v != null ? Math.round(v).toLocaleString('es-AR') + ' g' : '—' }

function exportCsvCostoGramo() {
  const headers = ['Sede', 'Tipo', 'Costo total', 'Gramos producidos', '$/g', 'Lotes con costo', 'Lotes sin rendimiento']
  const rows = [headers, ...cpgSedes.value.map(s => [
    s.sede_nombre, s.sede_tipo ?? '', s.costo_total, s.gramos_producidos,
    s.costo_por_gramo ?? '', s.lotes_con_costo, s.lotes_sin_rendimiento,
  ])]
  downloadCsv(`analitica_costo_por_gramo_${fechaHoy()}.csv`, rows)
}

// ── Contabilidad computeds ─────────────────────────────────────────
const contMeses     = computed(() => dataCont.value?.meses ?? [])
const contProy      = computed(() => dataCont.value?.proyeccion_lotes ?? [])
const contProyTotal = computed(() => dataCont.value?.ingreso_proy_total ?? 0)
const contMaxIngreso = computed(() => Math.max(...contMeses.value.map(m => m.ingresos), 1))
const contMaxCosto   = computed(() => Math.max(...contMeses.value.map(m => m.costos), 1))
const contMaxAbs     = computed(() => Math.max(contMaxIngreso.value, contMaxCosto.value))

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
  const headers = ['Genética','Lotes con datos','Vegetativo total (d)','Propagación (d)','Vegetativo puro (d)','Floración (d)','Cosecha (d)','Manicura (d)','Curado (d)','Total (d)']
  const rows = [headers, ...ciclos.value.map(c => [
    c.nombre, c.lotes_con_datos,
    c.vegetativo ?? '', c.propagacion ?? '', c.vegetativo_puro ?? '',
    c.floracion ?? '', c.cosecha ?? '', c.secado ?? '', c.curado ?? '',
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
  curado:     { bg: 'rgba(139,92,246,.1)',  color: '#7c3aed' },
  finalizado: { bg: '#f1f5f9',              color: '#94a3b8' },
}
function estadoStyle(e) { return ESTADO_COLOR[e] || ESTADO_COLOR.finalizado }
function fmt(v, u = 'g') { return v != null ? `${v} ${u}` : '—' }
function fmtDias(v) { return v != null ? `${Math.round(Number(v))} d` : '—' }
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
const FASES_CICLO = ['vegetativo', 'floracion', 'cosecha', 'curado']
function totalCiclo(c) {
  // Number(): los días por fase pueden venir como string (decimal de Rails) y el +
  // concatenaría en vez de sumar, rompiendo el .toFixed.
  return Math.round(FASES_CICLO.reduce((s, f) => s + Number(c[f] ?? 0), 0))
}

// ── Pérdidas ─────────────────────────────────────────────────────
const perdidas = computed(() => dataProd.value?.perdidas ?? [])
const expandida = ref(null)
function toggleExpand(id) { expandida.value = expandida.value === id ? null : id }

// ── Comparativa ──────────────────────────────────────────────────
const comparativa = computed(() => dataProd.value?.comparativa ?? [])

// ── Correlación ambiental ─────────────────────────────────────────
const corrLotes    = computed(() => dataCorr.value?.lotes        ?? [])
const corrVpd      = computed(() => dataCorr.value?.vpd_buckets  ?? [])
const corrTemp     = computed(() => dataCorr.value?.temp_buckets ?? [])
const corrPh       = computed(() => dataCorr.value?.ph_buckets   ?? [])
const corrMeta     = computed(() => ({
  total_con_datos:   dataCorr.value?.total_con_datos   ?? 0,
  total_finalizados: dataCorr.value?.total_finalizados ?? 0,
}))
const corrBestLote = computed(() => corrLotes.value[0] ?? null)

// ── Scatter chart ─────────────────────────────────────────────────
const VARS_SCATTER = ['vpd', 'temperatura', 'humedad', 'ph', 'co2', 'ec', 'ppfd']
const VAR_LABELS   = { vpd: 'VPD (kPa)', temperatura: 'Temperatura (°C)', humedad: 'Humedad (%)',
                       ph: 'pH', co2: 'CO₂ (ppm)', ec: 'EC (mS/cm)', ppfd: 'PPFD' }
const corrVarSeleccionada = ref('vpd')
const scatterCanvas       = ref(null)
let   scatterChart        = null

const corrRegresiones = computed(() => dataCorr.value?.regresiones ?? {})
const scatterInfo     = computed(() => corrRegresiones.value[corrVarSeleccionada.value] ?? null)
const scatterPoints   = computed(() =>
  corrLotes.value
    .filter(l => l[corrVarSeleccionada.value] != null)
    .map(l => ({ x: l[corrVarSeleccionada.value], y: l.rendimiento_g, label: l.codigo }))
)

function initScatterChart() {
  if (!scatterCanvas.value) return
  if (scatterChart) { scatterChart.destroy(); scatterChart = null }
  if (!scatterPoints.value.length) return

  const reg      = scatterInfo.value
  const varLabel = VAR_LABELS[corrVarSeleccionada.value] || corrVarSeleccionada.value
  const datasets = [
    {
      type:            'scatter',
      label:           'Lotes',
      data:            scatterPoints.value,
      backgroundColor: 'rgba(21,128,61,.65)',
      pointRadius:     6,
      pointHoverRadius: 8,
    },
  ]

  if (reg) {
    datasets.push({
      type:            'line',
      label:           `Tendencia (r²=${reg.r_squared})`,
      data:            [{ x: reg.x_min, y: reg.y_at_xmin }, { x: reg.x_max, y: reg.y_at_xmax }],
      borderColor:     'rgba(220,38,38,.7)',
      backgroundColor: 'transparent',
      borderWidth:     2,
      pointRadius:     0,
      tension:         0,
    })
  }

  scatterChart = new Chart(scatterCanvas.value, {
    type: 'scatter',
    data: { datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: !!reg, position: 'bottom', labels: { color: '#64748b', font: { size: 11 } } },
        tooltip: {
          callbacks: {
            label(ctx) {
              if (ctx.datasetIndex === 0) return `${ctx.raw.label}: x=${ctx.raw.x}, ${ctx.raw.y} g`
              return null
            },
          },
        },
      },
      scales: {
        x: {
          title: { display: true, text: varLabel, color: '#64748b', font: { size: 11 } },
          ticks: { color: '#94a3b8', font: { size: 11 } },
          grid:  { color: '#f8fafc' },
        },
        y: {
          title: { display: true, text: 'Rendimiento (g)', color: '#64748b', font: { size: 11 } },
          ticks: { color: '#94a3b8', font: { size: 11 } },
          grid:  { color: '#f1f5f9' },
          beginAtZero: false,
        },
      },
    },
  })
}

watch([corrVarSeleccionada, () => dataCorr.value], async () => {
  await nextTick()
  initScatterChart()
})

onUnmounted(() => { if (scatterChart) scatterChart.destroy() })

function exportCsvAmbiente() {
  const headers = ['Lote','Genética','Rend. (g)','Desvío %','Temperatura','Humedad %','VPD kPa','pH','CO₂ ppm','EC mS/cm','PPFD','N° registros']
  const rows = [headers, ...corrLotes.value.map(l => [
    l.codigo, l.genetica ?? '—', l.rendimiento_g, l.desv_pct ?? '—',
    l.temperatura ?? '—', l.humedad ?? '—', l.vpd ?? '—', l.ph ?? '—',
    l.co2 ?? '—', l.ec ?? '—', l.ppfd ?? '—', l.n_registros,
  ])]
  downloadCsv(`analitica_ambiente_${fechaHoy()}.csv`, rows)
}

function bucketColor(desv) {
  if (desv == null) return '#64748b'
  if (desv >= 5)  return '#15803d'
  if (desv >= 0)  return '#65a30d'
  if (desv >= -10) return '#b45309'
  return '#dc2626'
}
</script>

<template>
  <div class="an">
    <div class="an__header">
      <div>
        <h1 class="an__title">Analítica de producción</h1>
        <p class="an__sub">Rendimiento, ciclos y pérdidas por genética</p>
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
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'geneticas' }" @click="goTab('geneticas')">
          <i class="bi bi-graph-up-arrow"></i> Genéticas
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'ciclos' }" @click="goTab('ciclos')">
          <i class="bi bi-clock-history"></i> Ciclos
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'perdidas' }" @click="goTab('perdidas')">
          <i class="bi bi-exclamation-triangle"></i> Pérdidas
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'comparativa' }" @click="goTab('comparativa')">
          <i class="bi bi-bar-chart-steps"></i> Comparativa
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'ambiente' }" @click="goTab('ambiente')">
          <i class="bi bi-thermometer-half"></i> Ambiente
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'contabilidad' }" @click="goTab('contabilidad')">
          <i class="bi bi-cash-stack"></i> Contabilidad
        </button>
        <button class="an__tab" :class="{ 'an__tab--active': tab === 'costo_gramo' }" @click="goTab('costo_gramo')">
          <i class="bi bi-tag"></i> Costo/g
        </button>
      </div>
      <div v-if="dataRend || dataProd" class="an__export-btns">
        <button class="an__export-btn" @click="tab === 'geneticas' ? exportCsvGeneticas() : tab === 'ciclos' ? exportCsvCiclos() : tab === 'perdidas' ? exportCsvPerdidas() : tab === 'ambiente' ? exportCsvAmbiente() : tab === 'costo_gramo' ? exportCsvCostoGramo() : null"
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
        Días promedio que cada genética pasa en cada fase del ciclo, calculados a partir de los eventos de transición registrados.
        Los lotes sin eventos de fase son excluidos.
      </div>

      <div v-if="!ciclos.length" class="an__empty-lg">
        <i class="bi bi-clock-history"></i>
        <p>Sin datos de ciclos aún.</p>
        <span>Se registran automáticamente al avanzar fases de lotes.</span>
      </div>

      <div v-else class="an__card">
        <div class="an__card-header"><span class="an__card-title">Días promedio por fase por genética</span></div>
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
                <td class="an__td-r">
                  <span class="an__fase-chip an__fase-chip--veg">{{ fmtDias(c.vegetativo) }}</span>
                  <div v-if="c.propagacion != null" class="an__veg-detalle">
                    <span class="an__veg-sub">🪴 {{ fmtDias(c.propagacion) }} prop.</span>
                    <span class="an__veg-sub">🍃 {{ fmtDias(c.vegetativo_puro) }} veg.</span>
                  </div>
                </td>
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
        Lotes finalizados de la misma genética comparados entre sí. Solo aparecen genéticas con 2 o más lotes finalizados.
      </div>

      <div v-if="!comparativa.length" class="an__empty-lg">
        <i class="bi bi-bar-chart-steps"></i>
        <p>Sin datos comparativos aún.</p>
        <span>Se necesitan al menos 2 lotes finalizados de la misma genética.</span>
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

    <!-- ══ TAB AMBIENTE ════════════════════════════════════════════ -->
    <template v-if="tab === 'ambiente' && dataCorr">

      <div v-if="!corrMeta.total_con_datos" class="an__empty-lg">
        <i class="bi bi-thermometer-half"></i>
        <p>Sin datos ambientales correlacionados aún.</p>
        <span>Se necesitan lotes finalizados con registros ambientales cargados.</span>
      </div>

      <template v-else>

        <!-- KPIs -->
        <div class="an__kpis" style="margin-bottom:1.25rem">
          <div class="an__kpi">
            <span class="an__kpi-val">{{ corrMeta.total_con_datos }}</span>
            <span class="an__kpi-lbl">Lotes con datos</span>
          </div>
          <div class="an__kpi">
            <span class="an__kpi-val">{{ corrMeta.total_finalizados }}</span>
            <span class="an__kpi-lbl">Total finalizados</span>
          </div>
          <div v-if="corrBestLote" class="an__kpi an__kpi--green">
            <span class="an__kpi-val">{{ corrBestLote.rendimiento_g }} g</span>
            <span class="an__kpi-lbl">Mejor rendimiento</span>
          </div>
          <div v-if="corrBestLote" class="an__kpi">
            <span class="an__kpi-val" style="font-size:1.1rem">{{ corrBestLote.codigo }}</span>
            <span class="an__kpi-lbl">Lote destacado</span>
          </div>
        </div>

        <!-- Scatter chart: variable ambiental vs rendimiento -->
        <div class="an__card" style="margin-bottom:1.25rem">
          <div class="an__card-header">
            <span class="an__card-title">Correlación ambiental vs rendimiento</span>
            <span
              v-if="scatterInfo"
              class="an__r2-badge"
              :class="scatterInfo.r_squared >= 0.5 ? 'an__r2-badge--strong' : scatterInfo.r_squared >= 0.25 ? 'an__r2-badge--moderate' : 'an__r2-badge--weak'"
            >r² = {{ scatterInfo.r_squared }} · n={{ scatterInfo.n }}</span>
            <span v-else-if="scatterPoints.length >= 3" class="an__r2-badge an__r2-badge--weak">Sin regresión (n={{ scatterPoints.length }})</span>
          </div>

          <div class="an__scatter-vars">
            <button
              v-for="v in VARS_SCATTER"
              :key="v"
              class="an__scatter-var-btn"
              :class="{ 'an__scatter-var-btn--active': corrVarSeleccionada === v }"
              @click="corrVarSeleccionada = v"
            >{{ VAR_LABELS[v] }}</button>
          </div>

          <div v-if="!scatterPoints.length" class="an__empty" style="padding:1.5rem 1.25rem">
            Sin lotes con datos de {{ VAR_LABELS[corrVarSeleccionada] }}.
          </div>
          <div v-else class="an__scatter-wrap">
            <canvas ref="scatterCanvas" />
          </div>

          <div v-if="scatterInfo" class="an__scatter-footer">
            <span class="an__scatter-eq">
              ŷ = {{ scatterInfo.slope >= 0 ? '+' : '' }}{{ scatterInfo.slope }}·x {{ scatterInfo.intercept >= 0 ? '+' : '' }}{{ scatterInfo.intercept }}
            </span>
            <span v-if="scatterInfo.n < 10" class="an__scatter-warn">
              ⚠️ Baja confianza estadística ({{ scatterInfo.n }} lotes — se recomiendan ≥10)
            </span>
          </div>
        </div>

        <!-- Buckets: VPD / Temperatura / pH -->
        <div class="an__corr-insights">

          <!-- VPD -->
          <div class="an__corr-card" v-if="corrVpd.length">
            <div class="an__corr-card-title">
              <i class="bi bi-moisture"></i> VPD (kPa)
              <span class="an__corr-hint">Presión de vapor del déficit — clave en floración</span>
            </div>
            <div v-for="b in corrVpd" :key="b.label" class="an__corr-bucket">
              <div class="an__corr-bucket-header">
                <span class="an__corr-bucket-label">{{ b.label }}</span>
                <span class="an__corr-bucket-count">{{ b.count }} lote{{ b.count !== 1 ? 's' : '' }}</span>
              </div>
              <div class="an__corr-bucket-bar-wrap">
                <div class="an__corr-bucket-bar"
                     :style="{ width: Math.min((b.rend_avg / Math.max(...corrVpd.map(x => x.rend_avg), 1)) * 100, 100) + '%',
                               background: bucketColor(b.desv_avg) }"></div>
              </div>
              <div class="an__corr-bucket-vals">
                <span class="an__corr-rend">{{ b.rend_avg }} g promedio</span>
                <span v-if="b.desv_avg != null" class="an__desv" :class="b.desv_avg >= 0 ? 'an__desv--pos' : 'an__desv--neg'">
                  {{ b.desv_avg >= 0 ? '+' : '' }}{{ b.desv_avg }}%
                </span>
              </div>
            </div>
          </div>

          <!-- Temperatura -->
          <div class="an__corr-card" v-if="corrTemp.length">
            <div class="an__corr-card-title">
              <i class="bi bi-thermometer-half"></i> Temperatura (°C)
            </div>
            <div v-for="b in corrTemp" :key="b.label" class="an__corr-bucket">
              <div class="an__corr-bucket-header">
                <span class="an__corr-bucket-label">{{ b.label }}</span>
                <span class="an__corr-bucket-count">{{ b.count }} lote{{ b.count !== 1 ? 's' : '' }}</span>
              </div>
              <div class="an__corr-bucket-bar-wrap">
                <div class="an__corr-bucket-bar"
                     :style="{ width: Math.min((b.rend_avg / Math.max(...corrTemp.map(x => x.rend_avg), 1)) * 100, 100) + '%',
                               background: bucketColor(b.desv_avg) }"></div>
              </div>
              <div class="an__corr-bucket-vals">
                <span class="an__corr-rend">{{ b.rend_avg }} g promedio</span>
                <span v-if="b.desv_avg != null" class="an__desv" :class="b.desv_avg >= 0 ? 'an__desv--pos' : 'an__desv--neg'">
                  {{ b.desv_avg >= 0 ? '+' : '' }}{{ b.desv_avg }}%
                </span>
              </div>
            </div>
          </div>

          <!-- pH -->
          <div class="an__corr-card" v-if="corrPh.length">
            <div class="an__corr-card-title">
              <i class="bi bi-droplet-half"></i> pH del agua
            </div>
            <div v-for="b in corrPh" :key="b.label" class="an__corr-bucket">
              <div class="an__corr-bucket-header">
                <span class="an__corr-bucket-label">{{ b.label }}</span>
                <span class="an__corr-bucket-count">{{ b.count }} lote{{ b.count !== 1 ? 's' : '' }}</span>
              </div>
              <div class="an__corr-bucket-bar-wrap">
                <div class="an__corr-bucket-bar"
                     :style="{ width: Math.min((b.rend_avg / Math.max(...corrPh.map(x => x.rend_avg), 1)) * 100, 100) + '%',
                               background: bucketColor(b.desv_avg) }"></div>
              </div>
              <div class="an__corr-bucket-vals">
                <span class="an__corr-rend">{{ b.rend_avg }} g promedio</span>
                <span v-if="b.desv_avg != null" class="an__desv" :class="b.desv_avg >= 0 ? 'an__desv--pos' : 'an__desv--neg'">
                  {{ b.desv_avg >= 0 ? '+' : '' }}{{ b.desv_avg }}%
                </span>
              </div>
            </div>
          </div>

        </div>

        <!-- Tabla individual de lotes -->
        <div class="an__card" style="margin-top:1.25rem">
          <div class="an__card-header">
            <span class="an__card-title">Huella ambiental por lote</span>
            <span class="an__pill an__pill--muted">{{ corrLotes.length }} lotes</span>
          </div>
          <div class="an__table-wrap">
            <table class="an__table">
              <thead>
                <tr>
                  <th>Lote</th>
                  <th>Genética</th>
                  <th class="an__th-r">Rend.</th>
                  <th class="an__th-r">Desvío</th>
                  <th class="an__th-r">Temp °C</th>
                  <th class="an__th-r">Hum %</th>
                  <th class="an__th-r">VPD</th>
                  <th class="an__th-r">pH</th>
                  <th class="an__th-r">CO₂</th>
                  <th class="an__th-r">EC</th>
                  <th class="an__th-r">Registros</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="l in corrLotes" :key="l.lote_id">
                  <td>
                    <RouterLink :to="`/lotes/${l.lote_id}`" class="an__link">{{ l.codigo }}</RouterLink>
                  </td>
                  <td class="an__td-muted">{{ l.genetica ?? '—' }}</td>
                  <td class="an__td-r an__td-bold">{{ l.rendimiento_g }} g</td>
                  <td class="an__td-r">
                    <span v-if="l.desv_pct != null" class="an__desv" :class="l.desv_pct >= 0 ? 'an__desv--pos' : 'an__desv--neg'">
                      {{ l.desv_pct >= 0 ? '+' : '' }}{{ l.desv_pct }}%
                    </span>
                    <span v-else class="an__nd">—</span>
                  </td>
                  <td class="an__td-r">{{ l.temperatura ?? '—' }}</td>
                  <td class="an__td-r">{{ l.humedad ?? '—' }}</td>
                  <td class="an__td-r">
                    <span v-if="l.vpd != null" class="an__vpd-chip"
                          :style="{ background: l.vpd >= 1.2 && l.vpd < 1.6 ? 'rgba(21,128,61,.1)' : l.vpd < 0.8 || l.vpd >= 2.0 ? 'rgba(220,38,38,.1)' : 'rgba(217,119,6,.1)',
                                    color: l.vpd >= 1.2 && l.vpd < 1.6 ? '#15803d' : l.vpd < 0.8 || l.vpd >= 2.0 ? '#dc2626' : '#b45309' }">
                      {{ l.vpd }}
                    </span>
                    <span v-else class="an__nd">—</span>
                  </td>
                  <td class="an__td-r">{{ l.ph ?? '—' }}</td>
                  <td class="an__td-r">{{ l.co2 != null ? l.co2 + ' ppm' : '—' }}</td>
                  <td class="an__td-r">{{ l.ec ?? '—' }}</td>
                  <td class="an__td-r an__td-muted">{{ l.n_registros }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

      </template>
    </template>

    <!-- ══ TAB CONTABILIDAD ═════════════════════════════════════════ -->
    <template v-if="tab === 'contabilidad'">
      <div v-if="!dataCont" class="an__empty-lg">
        <i class="bi bi-cash-stack"></i>
        <p>Cargando datos contables…</p>
      </div>

      <template v-else>
        <!-- KPIs del último mes -->
        <div class="an__kpis" style="margin-bottom:1.25rem">
          <div class="an__kpi an__kpi--green">
            <span class="an__kpi-val">$ {{ contMeses.at(-1)?.ingresos?.toLocaleString('es-AR') ?? '—' }}</span>
            <span class="an__kpi-lbl">Ingresos (mes actual)</span>
          </div>
          <div class="an__kpi">
            <span class="an__kpi-val">$ {{ contMeses.at(-1)?.costos?.toLocaleString('es-AR') ?? '—' }}</span>
            <span class="an__kpi-lbl">Costos (mes actual)</span>
          </div>
          <div class="an__kpi" :class="(contMeses.at(-1)?.margen ?? 0) >= 0 ? 'an__kpi--green' : 'an__kpi--red'">
            <span class="an__kpi-val">$ {{ contMeses.at(-1)?.margen?.toLocaleString('es-AR') ?? '—' }}</span>
            <span class="an__kpi-lbl">Margen (mes actual)</span>
          </div>
          <div v-if="contProyTotal > 0" class="an__kpi">
            <span class="an__kpi-val">$ {{ contProyTotal.toLocaleString('es-AR') }}</span>
            <span class="an__kpi-lbl">Ingreso proyectado</span>
          </div>
        </div>

        <!-- Gráfico de barras: P&L mensual -->
        <div class="an__card" style="margin-bottom:1.25rem">
          <div class="an__card-header">
            <span class="an__card-title">P&amp;L mensual — últimos 12 meses</span>
          </div>
          <div class="an__cont-chart">
            <div v-for="m in contMeses" :key="m.mes" class="an__cont-col">
              <div class="an__cont-bars">
                <div class="an__cont-bar an__cont-bar--ing"
                     :style="{ height: contMaxAbs > 0 ? (m.ingresos / contMaxAbs * 100) + '%' : '2px' }"
                     :title="'Ingresos: $' + m.ingresos.toLocaleString('es-AR')"></div>
                <div class="an__cont-bar an__cont-bar--cos"
                     :style="{ height: contMaxAbs > 0 ? (m.costos / contMaxAbs * 100) + '%' : '2px' }"
                     :title="'Costos: $' + m.costos.toLocaleString('es-AR')"></div>
              </div>
              <div class="an__cont-margen" :class="m.margen >= 0 ? 'an__cont-margen--pos' : 'an__cont-margen--neg'">
                {{ m.margen >= 0 ? '+' : '' }}{{ (m.margen / 1000).toFixed(1) }}k
              </div>
              <div class="an__cont-label">{{ m.mes.split(' ')[0] }}</div>
            </div>
          </div>
          <div class="an__cont-legend">
            <span class="an__cont-leg-item"><span class="an__cont-leg-dot an__cont-leg-dot--ing"></span> Ingresos</span>
            <span class="an__cont-leg-item"><span class="an__cont-leg-dot an__cont-leg-dot--cos"></span> Costos</span>
          </div>
        </div>

        <!-- Tabla de meses -->
        <div class="an__card" style="margin-bottom:1.25rem">
          <div class="an__card-header">
            <span class="an__card-title">Detalle mensual</span>
          </div>
          <div class="an__table-wrap">
            <table class="an__table">
              <thead>
                <tr>
                  <th>Mes</th>
                  <th class="an__th-r">Ingresos</th>
                  <th class="an__th-r">Costos</th>
                  <th class="an__th-r">Margen</th>
                  <th class="an__th-r">Margen %</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="m in [...contMeses].reverse()" :key="m.mes">
                  <td>{{ m.mes }}</td>
                  <td class="an__td-r">$ {{ m.ingresos.toLocaleString('es-AR') }}</td>
                  <td class="an__td-r">$ {{ m.costos.toLocaleString('es-AR') }}</td>
                  <td class="an__td-r an__td-bold" :class="m.margen >= 0 ? '' : 'an__td-red'">
                    $ {{ m.margen.toLocaleString('es-AR') }}
                  </td>
                  <td class="an__td-r">
                    <span v-if="m.ingresos > 0">{{ (m.margen / m.ingresos * 100).toFixed(1) }}%</span>
                    <span v-else class="an__nd">—</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Proyección de lotes en curso -->
        <div v-if="contProy.length" class="an__card">
          <div class="an__card-header">
            <span class="an__card-title">Proyección — lotes en curso</span>
            <span class="an__pill an__pill--muted">{{ contProy.length }} lotes</span>
          </div>
          <div class="an__table-wrap">
            <table class="an__table">
              <thead>
                <tr>
                  <th>Lote</th>
                  <th>Genética</th>
                  <th>Estado</th>
                  <th class="an__th-r">Rend. obj. (g)</th>
                  <th class="an__th-r">Precio/g est.</th>
                  <th class="an__th-r">Ingreso est.</th>
                  <th>Cosecha est.</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="p in contProy" :key="p.lote_id">
                  <td>
                    <RouterLink :to="`/lotes/${p.lote_id}`" class="an__link">{{ p.codigo }}</RouterLink>
                  </td>
                  <td class="an__td-muted">{{ p.genetica ?? '—' }}</td>
                  <td><span class="an__pill an__pill--muted">{{ p.estado }}</span></td>
                  <td class="an__td-r">{{ p.rendimiento_obj_g?.toLocaleString('es-AR') }}</td>
                  <td class="an__td-r">{{ p.precio_g_estimado != null ? '$ ' + p.precio_g_estimado : '—' }}</td>
                  <td class="an__td-r an__td-bold an__td-green">
                    {{ p.ingreso_estimado != null ? '$ ' + p.ingreso_estimado.toLocaleString('es-AR') : '—' }}
                  </td>
                  <td>{{ p.fecha_cosecha_est ?? '—' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

      </template>
    </template>

    <!-- ══ TAB COSTO POR GRAMO ══════════════════════════════════════ -->
    <template v-if="tab === 'costo_gramo'">
      <div v-if="!dataCpg" class="an__empty-lg">
        <i class="bi bi-tag"></i>
        <p>Cargando costo por gramo…</p>
      </div>

      <template v-else>
        <div class="an__info-box">
          <i class="bi bi-info-circle"></i>
          Costo real de producción dividido por los gramos efectivamente producidos (rendimiento
          real de manicura), agregado por sede. Numerador: costo total del lote (insumos, energía,
          mano de obra). Denominador: gramos cosechados — no dispensados. Un lote que costó y no rindió
          suma su costo con cero gramos: es un costo real de esa sede.
        </div>

        <div v-if="!cpgSedes.length" class="an__empty-lg">
          <i class="bi bi-tag"></i>
          <p>Sin datos de costo por gramo aún.</p>
          <span>Se necesitan lotes con costo calculado (Contabilidad → Costo del lote) y rendimiento real.</span>
        </div>

        <template v-else>
          <!-- KPIs del club -->
          <div class="an__kpis" style="margin-bottom:1.25rem">
            <div class="an__kpi an__kpi--green">
              <span class="an__kpi-val">{{ fmtArs(cpgTotal?.costo_por_gramo) }}<small style="font-size:.6em;font-weight:600"> /g</small></span>
              <span class="an__kpi-lbl">Costo por gramo — club</span>
            </div>
            <div class="an__kpi">
              <span class="an__kpi-val">{{ fmtG(cpgTotal?.gramos_producidos) }}</span>
              <span class="an__kpi-lbl">Gramos producidos</span>
            </div>
            <div class="an__kpi">
              <span class="an__kpi-val">{{ fmtArs(cpgTotal?.costo_total) }}</span>
              <span class="an__kpi-lbl">Costo total</span>
            </div>
            <div class="an__kpi">
              <span class="an__kpi-val">{{ cpgTotal?.lotes_con_costo ?? '—' }}</span>
              <span class="an__kpi-lbl">Lotes con costo</span>
            </div>
          </div>

          <!-- Tabla por sede, expandible a lotes -->
          <div class="an__card">
            <div class="an__card-header">
              <span class="an__card-title">Costo por gramo por sede</span>
              <span class="an__pill an__pill--muted">{{ cpgSedes.length }} sede{{ cpgSedes.length !== 1 ? 's' : '' }}</span>
            </div>
            <div class="an__table-wrap">
              <table class="an__table">
                <thead>
                  <tr>
                    <th>Sede</th>
                    <th class="an__th-r">$/g</th>
                    <th class="an__th-r">Gramos prod.</th>
                    <th class="an__th-r">Costo total</th>
                    <th class="an__th-r">Lotes</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <template v-for="s in cpgSedes" :key="s.sede_id ?? 'sin'">
                    <tr>
                      <td class="an__td-bold">
                        {{ s.sede_nombre }}
                        <span v-if="s.sede_tipo" class="an__pill an__pill--muted" style="margin-left:.4rem">{{ s.sede_tipo }}</span>
                      </td>
                      <td class="an__td-r an__td-bold an__td-green">{{ fmtArs(s.costo_por_gramo) }}</td>
                      <td class="an__td-r">{{ fmtG(s.gramos_producidos) }}</td>
                      <td class="an__td-r an__td-muted">{{ fmtArs(s.costo_total) }}</td>
                      <td class="an__td-r">
                        {{ s.lotes_con_costo }}
                        <span v-if="s.lotes_sin_rendimiento" class="an__desv an__desv--neg" :title="s.lotes_sin_rendimiento + ' sin rendimiento'">· {{ s.lotes_sin_rendimiento }} s/r</span>
                      </td>
                      <td class="an__td-r">
                        <button v-if="s.lotes?.length" class="an__rank-toggle" style="margin:0" @click="toggleCpg(s.sede_id ?? 'sin')">
                          {{ cpgExpandida === (s.sede_id ?? 'sin') ? 'Ocultar' : 'Ver lotes' }}
                          <i :class="cpgExpandida === (s.sede_id ?? 'sin') ? 'bi bi-chevron-up' : 'bi bi-chevron-down'"></i>
                        </button>
                      </td>
                    </tr>
                    <tr v-if="cpgExpandida === (s.sede_id ?? 'sin')">
                      <td colspan="6" style="padding:0">
                        <table class="an__table an__table--compact" style="margin:0">
                          <thead>
                            <tr>
                              <th>Lote</th>
                              <th>Genética</th>
                              <th>Estado</th>
                              <th class="an__th-r">Costo</th>
                              <th class="an__th-r">Gramos</th>
                              <th class="an__th-r">$/g</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr v-for="l in s.lotes" :key="l.id">
                              <td><RouterLink :to="`/lotes/${l.id}`" class="an__link">{{ l.codigo }}</RouterLink></td>
                              <td class="an__td-muted">{{ l.genetica ?? '—' }}</td>
                              <td><span class="an__badge" :style="{ background: estadoStyle(l.estado).bg, color: estadoStyle(l.estado).color }">{{ l.estado }}</span></td>
                              <td class="an__td-r">{{ fmtArs(l.costo_total) }}</td>
                              <td class="an__td-r">
                                <span v-if="l.gramos_producidos > 0">{{ fmtG(l.gramos_producidos) }}</span>
                                <span v-else class="an__desv an__desv--neg">sin rendimiento</span>
                              </td>
                              <td class="an__td-r an__td-bold">{{ l.costo_por_gramo != null ? fmtArs(l.costo_por_gramo) : '—' }}</td>
                            </tr>
                          </tbody>
                        </table>
                      </td>
                    </tr>
                  </template>
                </tbody>
              </table>
            </div>
          </div>
        </template>
      </template>
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
.an__veg-detalle { display: flex; gap: .3rem; margin-top: .25rem; flex-wrap: wrap; }
.an__veg-sub { font-size: .68rem; color: #6b7280; white-space: nowrap; }

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

/* Correlación ambiental */
.an__corr-insights { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.an__corr-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.1rem; display: flex; flex-direction: column; gap: .75rem; }
.an__corr-card-title { font-size: .82rem; font-weight: 700; color: #0f172a; display: flex; align-items: baseline; gap: .5rem; flex-wrap: wrap; }
.an__corr-hint { font-size: .68rem; font-weight: 400; color: #94a3b8; }
.an__corr-bucket { display: flex; flex-direction: column; gap: .3rem; }
.an__corr-bucket-header { display: flex; justify-content: space-between; align-items: center; }
.an__corr-bucket-label { font-size: .75rem; color: #374151; font-weight: 500; }
.an__corr-bucket-count { font-size: .68rem; color: #94a3b8; }
.an__corr-bucket-bar-wrap { height: 6px; background: #f1f5f9; border-radius: 999px; overflow: hidden; }
.an__corr-bucket-bar { height: 100%; border-radius: 999px; transition: width .4s; }
.an__corr-bucket-vals { display: flex; align-items: center; justify-content: space-between; }
.an__corr-rend { font-size: .72rem; color: #64748b; }
.an__vpd-chip { display: inline-block; padding: .12em .45em; border-radius: 5px; font-size: .75rem; font-weight: 700; }

/* Scatter chart */
.an__r2-badge { font-size: .72rem; font-weight: 700; padding: .18em .6em; border-radius: 999px; }
.an__r2-badge--strong   { background: rgba(21,128,61,.1);  color: #15803d; }
.an__r2-badge--moderate { background: rgba(217,119,6,.1);  color: #b45309; }
.an__r2-badge--weak     { background: #f1f5f9; color: #94a3b8; }
.an__scatter-vars { display: flex; gap: .35rem; flex-wrap: wrap; padding: .75rem 1.1rem; border-bottom: 1px solid #f1f5f9; }
.an__scatter-var-btn { padding: .25rem .65rem; font-size: .72rem; font-weight: 600; border: 1.5px solid #e2e8f0; border-radius: 999px; background: #f8fafc; color: #64748b; cursor: pointer; transition: all .15s; white-space: nowrap; }
.an__scatter-var-btn:hover { border-color: #1b5e20; color: #1b5e20; }
.an__scatter-var-btn--active { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.an__scatter-wrap { height: 280px; padding: 1rem 1.1rem .5rem; }
.an__scatter-footer { display: flex; align-items: center; gap: 1rem; padding: .5rem 1.1rem .875rem; flex-wrap: wrap; }
.an__scatter-eq   { font-size: .75rem; color: #64748b; font-family: monospace; }
.an__scatter-warn { font-size: .72rem; color: #b45309; background: rgba(217,119,6,.08); padding: .2em .55em; border-radius: 5px; }

/* ── Contabilidad tab ───────────────────────────────────── */
.an__kpi--red .an__kpi-val { color: #dc2626; }
.an__td-red   { color: #dc2626; }
.an__td-green { color: #15803d; }
.an__cont-chart { display: flex; align-items: flex-end; gap: 6px; height: 180px; padding: .5rem 1.1rem 0; overflow-x: auto; }
.an__cont-col { display: flex; flex-direction: column; align-items: center; gap: 4px; flex: 1; min-width: 36px; }
.an__cont-bars { display: flex; align-items: flex-end; gap: 2px; height: 120px; width: 100%; }
.an__cont-bar { flex: 1; border-radius: 4px 4px 0 0; min-height: 2px; transition: height .3s; }
.an__cont-bar--ing { background: #15803d; }
.an__cont-bar--cos { background: #dc2626; opacity: .65; }
.an__cont-margen { font-size: .68rem; font-weight: 700; white-space: nowrap; }
.an__cont-margen--pos { color: #15803d; }
.an__cont-margen--neg { color: #dc2626; }
.an__cont-label { font-size: .65rem; color: #94a3b8; white-space: nowrap; }
.an__cont-legend { display: flex; gap: 1rem; padding: .5rem 1.1rem .875rem; }
.an__cont-leg-item { display: flex; align-items: center; gap: .35rem; font-size: .75rem; color: #64748b; }
.an__cont-leg-dot { width: 10px; height: 10px; border-radius: 2px; }
.an__cont-leg-dot--ing { background: #15803d; }
.an__cont-leg-dot--cos { background: #dc2626; opacity: .65; }
</style>
