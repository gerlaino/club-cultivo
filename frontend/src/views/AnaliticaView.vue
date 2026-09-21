<script setup>
// LA ANALÍTICA COMPARA. Los informes dicen qué pasó en un período; acá se contesta QUÉ RINDE
// MEJOR —qué genética, cuánto tarda cada fase, en qué sala y con qué método, a qué costo— sobre
// todos los lotes cerrados, para decidir el próximo ciclo. Cuatro solapas, una pregunta cada una
// (rediseño de sep-2026, decisiones de Germán sobre el artifact). Eran ocho: tres contaban mal
// (una «merma» que daba siempre 0, una fase `secado` que no es estado del lote, el costo de lotes
// abiertos dividido por gramos de cerrados), cuatro repetían informes ya revisados, y una
// proyectaba «ingresos» con el costo por gramo.
//
// Todo sale de `Analitica::*` en el backend; acá sólo se presenta. El PDF sigue siendo una
// captura de la solapa: acá el contenido son barras y tablas, y para trabajar los números está
// el CSV. Nada se promedia entre promedios: g/planta es gramos ÷ plantas, ponderado.
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getAnaliticaGeneticas, getAnaliticaFases, getAnaliticaDondeYComo, getAnaliticaCosto } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import SelectorPeriodo from '../components/informes/SelectorPeriodo.vue'
import { hoyISO } from '../utils/dates.js'

const route  = useRoute()
const router = useRouter()

const TABS = [
  { id: 'geneticas',    label: 'Genéticas',    pregunta: '¿Qué genética rinde mejor?' },
  { id: 'fases',        label: 'Fases',        pregunta: '¿Cuánto tarda cada fase?' },
  { id: 'donde_y_como', label: 'Dónde y cómo', pregunta: '¿En qué sala, con qué método, con qué ambiente?' },
  { id: 'costo',        label: 'Costo',        pregunta: '¿Cuánto cuesta producir un gramo?' },
]
// Las rutas viejas siguen entrando: cada solapa retirada cae en la que contesta su pregunta.
const ALIAS = { ciclos: 'fases', prendimiento: 'fases', perdidas: 'geneticas', comparativa: 'donde_y_como',
                ambiente: 'donde_y_como', costo_gramo: 'costo', contabilidad: 'costo' }
const tab     = ref(ALIAS[route.query.tab] || (TABS.some(t => t.id === route.query.tab) ? route.query.tab : 'geneticas'))
const params  = ref({ periodo: 'todo' })
const corte   = ref('sala')
const loading = ref(false)
const error   = ref('')
const data    = ref({ geneticas: null, fases: null, donde_y_como: null, costo: null })

const FASE_LABEL = { enraizado: 'Enraizado', vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Secado',
                     en_manicura: 'Manicura', curado: 'Curado', total: 'Total a frasco' }
const CORTES = [{ id: 'sala', label: 'Sala' }, { id: 'metodo', label: 'Método' }, { id: 'luz', label: 'Luz' }, { id: 'receta', label: 'Receta' }]

async function cargar() {
  loading.value = true
  error.value   = ''
  try {
    const p = params.value.periodo === 'todo' ? {} : params.value
    const [g, f, d, c] = await Promise.all([
      getAnaliticaGeneticas(p), getAnaliticaFases(p),
      getAnaliticaDondeYComo({ ...p, corte: corte.value }), getAnaliticaCosto(p),
    ])
    data.value = { geneticas: g.data, fases: f.data, donde_y_como: d.data, costo: c.data }
  } catch (e) {
    error.value = e?.response?.data?.error || 'No se pudo cargar la analítica.'
  } finally {
    loading.value = false
  }
}

async function cambiarCorte(c) {
  corte.value = c
  const p = params.value.periodo === 'todo' ? {} : params.value
  try {
    const { data: d } = await getAnaliticaDondeYComo({ ...p, corte: c })
    data.value.donde_y_como = d
  } catch { /* la pantalla conserva el corte anterior */ }
}

function cambiarPeriodo(p) { params.value = p; cargar() }
function goTab(t) { tab.value = t; router.replace({ query: { ...route.query, tab: t } }) }
watch(() => route.query.tab, (t) => { if (t && ALIAS[t]) goTab(ALIAS[t]) })

onMounted(cargar)

const periodo   = computed(() => data.value.geneticas?.periodo)
const geneticas = computed(() => data.value.geneticas?.filas || [])
const fases     = computed(() => data.value.fases)
const donde     = computed(() => data.value.donde_y_como)
const costo     = computed(() => data.value.costo)
const pregunta  = computed(() => TABS.find(t => t.id === tab.value)?.pregunta)

// Barras de g/planta contra la mejor: un solo eje visual.
const maxGpp = computed(() => Math.max(0, ...geneticas.value.map(g => g.g_por_planta || 0)))
const pct = (v, max) => (max > 0 && v ? Math.round((v / max) * 100) : 0)

const fmt  = (n, d = 1) => n == null ? '—' : Number(n).toLocaleString('es-AR', { maximumFractionDigits: d })
const ars  = (n) => n == null ? '—' : `$ ${Math.round(Number(n)).toLocaleString('es-AR')}`
const pc   = (n) => n == null ? '—' : `${fmt(n, 1)} %`
const dias = (n) => n == null ? '—' : `${Math.round(n)} d`

// ── CSV de la solapa a la vista: dato crudo, para trabajar los números ──
function exportCsv() {
  let headers = [], rows = []
  if (tab.value === 'geneticas') {
    headers = ['Genética', 'Lotes', 'Plantas', 'g/planta', 'Flor seca (g)', 'Prendió %', 'Se perdió en el ciclo %', 'Ciclo (días)']
    rows = geneticas.value.map(g => [g.nombre, g.lotes, g.plantas, g.g_por_planta, g.gramos, g.prendio_pct, g.perdida_pct, g.ciclo_dias])
  } else if (tab.value === 'fases') {
    const fs = fases.value?.fases || []
    headers = ['Genética', 'Lotes', 'Prendió %', 'Origen', ...fs.map(f => FASE_LABEL[f]), 'Total a frasco']
    rows = (fases.value?.filas || []).map(f => [f.nombre, f.lotes, f.prendio_pct, f.origen_label, ...fs.map(x => f.dias[x]), f.dias.total])
  } else if (tab.value === 'donde_y_como') {
    headers = [CORTES.find(c => c.id === corte.value)?.label, 'Lotes', 'Plantas', 'g/planta', 'Floración (días)', 'VPD flora', 'Temp flora', 'Humedad flora']
    rows = (donde.value?.filas || []).map(f => [f.nombre, f.lotes, f.plantas, f.g_por_planta, f.floracion_dias, f.ambiente?.vpd, f.ambiente?.temperatura, f.ambiente?.humedad])
  } else {
    headers = ['Corte', 'Nombre', 'Lotes', 'Costo total', 'Gramos', '$/g']
    rows = [...(costo.value?.por_sede || []).map(f => ['Sede', f.nombre, f.lotes, f.costo_total, f.gramos, f.costo_por_gramo]),
            ...(costo.value?.por_genetica || []).map(f => ['Genética', f.nombre, f.lotes, f.costo_total, f.gramos, f.costo_por_gramo])]
  }
  const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const csv = [headers, ...rows].map(r => r.map(esc).join(';')).join('\n')
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([`﻿${csv}`], { type: 'text/csv;charset=utf-8' }))
  a.download = `analitica_${tab.value}_${hoyISO()}.csv`
  a.click(); URL.revokeObjectURL(a.href)
}

// ÚNICO PDF que sigue siendo una captura de pantalla, y a propósito: acá el contenido son barras
// y tablas de comparación, y para trabajar los números está el CSV.
async function exportPdf() {
  const el = document.getElementById('an-tab-content')
  if (!el) return
  const { default: html2pdf } = await import('html2pdf.js')
  await html2pdf().set({
    margin: [8, 8, 8, 8], filename: `analitica_${tab.value}_${hoyISO()}.pdf`,
    image: { type: 'jpeg', quality: 0.95 }, html2canvas: { scale: 2, useCORS: true },
    jsPDF: { unit: 'mm', format: 'a4', orientation: 'landscape' },
  }).from(el).save()
}
</script>

<template>
  <div class="an">
    <div class="an__header">
      <div>
        <h1 class="an__title">Analítica</h1>
        <p class="an__sub">{{ pregunta }} · sobre los lotes cerrados con rendimiento<template v-if="periodo"> · {{ periodo.etiqueta }} · {{ periodo.lotes }} lotes</template></p>
      </div>
      <div class="an__header-right">
        <SelectorPeriodo inicial="todo" con-todo @change="cambiarPeriodo" />
        <button class="an__export-btn" :disabled="loading" @click="exportCsv"><i class="bi bi-filetype-csv"></i> CSV</button>
        <button class="an__export-btn an__export-btn--pdf" :disabled="loading" @click="exportPdf"><i class="bi bi-file-earmark-pdf"></i> PDF</button>
      </div>
    </div>

    <div class="an__tabs">
      <button v-for="t in TABS" :key="t.id" class="an__tab" :class="{ 'an__tab--active': tab === t.id }" @click="goTab(t.id)">
        {{ t.label }}
      </button>
    </div>

    <div v-if="loading && !data.geneticas" class="an__loading"><DsSpinner /> Cargando analítica…</div>
    <div v-else-if="error" class="an__empty">{{ error }}</div>

    <div v-else id="an-tab-content">
      <!-- ══ GENÉTICAS · ¿cuál rinde mejor? ═══════════════════════════════════ -->
      <template v-if="tab === 'geneticas'">
        <div v-if="!geneticas.length" class="an__empty">Todavía no hay lotes cerrados con rendimiento en este período.</div>
        <div v-else class="an__card">
          <div class="an__card-header">
            <span class="an__card-title">Rendimiento por genética</span>
            <span class="an__card-hint">g/planta ponderado: gramos ÷ plantas cosechadas, nunca promedio de promedios</span>
          </div>
          <div class="an__table-wrap">
            <table class="an__table">
              <thead>
                <tr>
                  <th>Genética</th><th class="an__th-r">Lotes</th><th class="an__th-r">Plantas</th>
                  <th class="an__th-r">g/planta</th><th class="an__th-bar"></th><th class="an__th-r">Flor seca</th>
                  <th class="an__th-r" title="De todas las plantas que arrancaron, cuántas enraizaron">Prendió</th>
                  <th class="an__th-r" title="De las que prendieron, cuántas se descartaron después">Se perdió en el ciclo</th>
                  <th class="an__th-r" title="Del arranque a que existe el frasco">Ciclo</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="g in geneticas" :key="g.genetica_id" :class="{ 'an__row--pocos': !g.suficientes }">
                  <td class="an__td-bold">{{ g.nombre }}<span v-if="g.automatica" class="chip-auto">Auto</span><span v-if="!g.suficientes" class="an__pocos">{{ g.lotes === 1 ? 'un solo lote: sin conclusión' : 'pocos lotes: sin conclusión' }}</span></td>
                  <td class="an__td-r">{{ g.lotes }}</td>
                  <td class="an__td-r">{{ g.plantas }}</td>
                  <td class="an__td-r an__td-bold">{{ fmt(g.g_por_planta) }}</td>
                  <td class="an__td-bar"><div class="an__bar"><i :style="{ width: pct(g.g_por_planta, maxGpp) + '%' }"></i></div></td>
                  <td class="an__td-r">{{ fmt(g.gramos, 0) }} g</td>
                  <td class="an__td-r">{{ pc(g.prendio_pct) }}</td>
                  <td class="an__td-r" :class="{ 'an__td-warn': g.perdida_pct > 10 }">{{ pc(g.perdida_pct) }}</td>
                  <td class="an__td-r">{{ dias(g.ciclo_dias) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <p class="an__nota">Lo que la genética promete en su ficha contra lo que rindió de verdad está en <RouterLink to="/auditor/plan-vs-real" class="an__link">Plan vs. real → Qué dice la genética</RouterLink>.</p>
      </template>

      <!-- ══ FASES · ¿cuánto tarda cada fase? ═════════════════════════════════ -->
      <template v-else-if="tab === 'fases'">
        <div v-if="!fases?.filas?.length" class="an__empty">Todavía no hay lotes cerrados con cronología en este período.</div>
        <div v-else class="an__card">
          <div class="an__card-header">
            <span class="an__card-title">Días promedio por fase, por genética</span>
            <span class="an__card-hint">de la cronología real de cada lote · el prendimiento es la primera etapa</span>
          </div>
          <div class="an__table-wrap">
            <table class="an__table">
              <thead>
                <tr>
                  <th>Genética</th><th class="an__th-r">Lotes</th>
                  <th class="an__th-r" title="De todas las plantas que arrancaron, cuántas enraizaron">Prendió</th>
                  <th v-for="f in fases.fases" :key="f" class="an__th-r">{{ FASE_LABEL[f] }}</th>
                  <th class="an__th-r an__th-total">Total a frasco</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="f in fases.filas" :key="f.genetica_id" :class="{ 'an__row--pocos': !f.suficientes }">
                  <td class="an__td-bold">{{ f.nombre }}<span v-if="f.automatica" class="chip-auto" title="Automática: sin floración anotada, el vegetativo es el ciclo entero">Auto</span><span class="an__origen">{{ f.origen_label }}</span><span v-if="!f.suficientes" class="an__pocos">pocos lotes: sin conclusión</span></td>
                  <td class="an__td-r">{{ f.lotes }}</td>
                  <td class="an__td-r">{{ pc(f.prendio_pct) }}</td>
                  <td v-for="x in fases.fases" :key="x" class="an__td-r"><span class="an__fase" :class="`an__fase--${x}`">{{ dias(f.dias[x]) }}</span></td>
                  <td class="an__td-r an__td-bold">{{ dias(f.dias.total) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <p class="an__nota">Un esqueje y una semilla no enraízan igual: el origen va al lado del nombre para leer el enraizado contra lo que corresponde.</p>
      </template>

      <!-- ══ DÓNDE Y CÓMO · ¿en qué sala, con qué método, con qué ambiente? ═══ -->
      <template v-else-if="tab === 'donde_y_como'">
        <div class="an__cortes">
          <span class="an__cortes-lbl">Cortar por</span>
          <button v-for="c in CORTES" :key="c.id" class="an__corte" :class="{ 'an__corte--on': corte === c.id }" @click="cambiarCorte(c.id)">{{ c.label }}</button>
        </div>
        <div v-if="!donde?.filas?.length" class="an__empty">Todavía no hay lotes cerrados con rendimiento en este período.</div>
        <div v-else class="an__card">
          <div class="an__card-header">
            <span class="an__card-title">g/planta por {{ CORTES.find(c => c.id === corte)?.label.toLowerCase() }}</span>
            <span class="an__card-hint">{{ corte === 'sala' ? 'la sala donde FLORECIÓ cada lote' : corte === 'receta' ? 'la receta con la que más se regó cada lote' : 'según lo cargado en cada lote' }} · el ambiente es el de la sala durante la floración</span>
          </div>
          <div class="an__table-wrap">
            <table class="an__table">
              <thead>
                <tr>
                  <th>{{ CORTES.find(c => c.id === corte)?.label }}</th><th class="an__th-r">Lotes</th><th class="an__th-r">Plantas</th>
                  <th class="an__th-r">g/planta</th><th class="an__th-r">$ nutr./planta</th><th class="an__th-r">Floración</th>
                  <th class="an__th-r">VPD flora</th><th class="an__th-r">Temp flora</th><th class="an__th-r">Hum. flora</th><th></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="f in donde.filas" :key="String(f.clave)" :class="{ 'an__row--pocos': !f.suficientes, 'an__row--mejor': f.mejor }">
                  <td class="an__td-bold">{{ f.nombre }}<span v-if="!f.suficientes" class="an__pocos">pocos lotes: sin conclusión</span></td>
                  <td class="an__td-r">{{ f.lotes }}</td>
                  <td class="an__td-r">{{ f.plantas }}</td>
                  <td class="an__td-r an__td-bold">{{ fmt(f.g_por_planta) }}</td>
                  <td class="an__td-r">{{ f.nutrientes_por_planta != null ? `$ ${fmt(f.nutrientes_por_planta, 0)}` : '—' }}</td>
                  <td class="an__td-r">{{ dias(f.floracion_dias) }}</td>
                  <td class="an__td-r">{{ f.ambiente?.vpd != null ? fmt(f.ambiente.vpd, 2) : '—' }}</td>
                  <td class="an__td-r">{{ f.ambiente?.temperatura != null ? `${fmt(f.ambiente.temperatura)} °C` : '—' }}</td>
                  <td class="an__td-r">{{ f.ambiente?.humedad != null ? `${fmt(f.ambiente.humedad, 0)} %` : '—' }}</td>
                  <td class="an__veredicto">
                    <span v-if="f.mejor" class="an__mejor">la que mejor rinde</span>
                    <span v-else-if="f.suficientes && f.contra_mejor_pct != null" class="an__contra">{{ Math.abs(f.contra_mejor_pct) }} % menos que la mejor</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <p v-if="donde && !donde.con_lecturas" class="an__nota">Sin lecturas de ambiente en la floración de estos lotes: cuando los sensores de la sala estén conectados, VPD, temperatura y humedad de la floración aparecen acá solos.</p>
        <p v-if="corte !== 'sala' && donde?.filas?.some(f => f.clave == null)" class="an__nota">«Sin dato» son lotes sin {{ corte === 'metodo' ? 'método de cultivo' : 'tipo de luz' }} cargado: se completa en la ficha del lote.</p>
        <p v-if="corte === 'sala' && donde?.filas?.some(f => f.clave == null)" class="an__nota">«Sin dato» son lotes cuya cronología no registra en qué sala florecieron (cargas anteriores a que se guardara la sala en cada cambio de fase).</p>
      </template>

      <!-- ══ COSTO · ¿cuánto cuesta producir un gramo? ════════════════════════ -->
      <template v-else-if="tab === 'costo'">
        <div v-if="!costo || !costo.total.lotes" class="an__empty">Todavía no hay lotes cerrados con costo cargado en este período.</div>
        <template v-else>
          <div class="an__kpis">
            <div class="an__kpi an__kpi--green">
              <span class="an__kpi-val">{{ ars(costo.total.costo_por_gramo) }}</span>
              <span class="an__kpi-lbl">por gramo, organización</span>
              <span class="an__kpi-sub">{{ costo.total.lotes }} lotes cerrados con costo<template v-if="costo.total.lotes_sin_costo"> · {{ costo.total.lotes_sin_costo }} sin costo cargado</template></span>
            </div>
            <div class="an__kpi">
              <span class="an__kpi-val">{{ fmt(costo.total.gramos, 0) }} g</span>
              <span class="an__kpi-lbl">Flor seca</span>
            </div>
            <div class="an__kpi">
              <span class="an__kpi-val">{{ ars(costo.total.costo_total) }}</span>
              <span class="an__kpi-lbl">Costo total</span>
            </div>
          </div>
          <div class="an__grid2">
            <div v-for="(grupo, key) in { por_sede: 'Por sede', por_genetica: 'Por genética' }" :key="key" class="an__card">
              <div class="an__card-header"><span class="an__card-title">{{ grupo }}</span></div>
              <table class="an__table an__table--compact">
                <thead><tr><th>{{ key === 'por_sede' ? 'Sede' : 'Genética' }}</th><th class="an__th-r">Lotes</th><th class="an__th-r">Gramos</th><th class="an__th-r">$/g</th></tr></thead>
                <tbody>
                  <tr v-for="f in costo[key]" :key="f.nombre" :class="{ 'an__row--pocos': !f.suficientes }">
                    <td class="an__td-bold">{{ f.nombre }}<span v-if="f.automatica" class="chip-auto">Auto</span></td>
                    <td class="an__td-r">{{ f.lotes }}</td>
                    <td class="an__td-r">{{ fmt(f.gramos, 0) }}</td>
                    <td class="an__td-r an__td-bold">{{ ars(f.costo_por_gramo) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <p class="an__nota">Un lote sin rendimiento no entra: su costo se divide cuando tenga gramos. El detalle lote por lote está en <RouterLink to="/contabilidad?vista=pl" class="an__link">Contabilidad → Ganancia por lote</RouterLink>.</p>
        </template>
      </template>
    </div>
  </div>
</template>

<style scoped>
.an { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; color: var(--c-slate-900); }
@media (max-width: 768px) { .an { padding: 1.25rem 1rem 2rem; } }
.an__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.an__title { font-size: 1.6rem; font-weight: 800; color: var(--c-slate-900); margin: 0; letter-spacing: -.03em; }
.an__sub { margin: .25rem 0 0; font-size: .82rem; color: var(--c-slate-500); }
.an__header-right { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.an__export-btn { display: inline-flex; align-items: center; gap: .35rem; padding: .4rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 7px; background: var(--c-slate-50); font-size: .75rem; font-weight: 600; color: var(--c-slate-500); cursor: pointer; white-space: nowrap; font-family: inherit; }
.an__export-btn:hover:not(:disabled) { border-color: var(--c-leaf-700); color: var(--c-leaf-700); }
.an__export-btn:disabled { opacity: .4; cursor: not-allowed; }
.an__export-btn--pdf { color: var(--c-rust-600); border-color: var(--c-rust-100); background: #fff5f5; }

.an__tabs { display: flex; gap: .25rem; flex-wrap: wrap; border-bottom: 2px solid var(--c-slate-200); margin-bottom: 1.5rem; }
.an__tab { padding: .65rem 1rem; font-size: .875rem; font-weight: 600; color: var(--c-slate-500); background: none; border: none; border-bottom: 2.5px solid transparent; margin-bottom: -2px; cursor: pointer; white-space: nowrap; font-family: inherit; }
.an__tab:hover { color: var(--c-slate-900); }
.an__tab--active { color: var(--c-leaf-700); border-bottom-color: var(--c-leaf-700); }

.an__loading { display: flex; align-items: center; justify-content: center; gap: .6rem; min-height: 40vh; color: var(--c-slate-500); }
.an__empty { color: var(--c-slate-500); font-size: .875rem; background: var(--c-slate-50); padding: 2rem; text-align: center; border-radius: 10px; }
.an__nota { margin: .9rem 0 0; font-size: .8rem; color: var(--c-slate-500); line-height: 1.5; }
.an__link { color: var(--c-leaf-700); font-weight: 600; text-decoration: underline; }

.an__card { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 14px; overflow: hidden; }
.an__card-header { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; flex-wrap: wrap; padding: .875rem 1.1rem; border-bottom: 1px solid var(--c-slate-100); background: var(--c-slate-50); }
.an__card-title { font-size: .875rem; font-weight: 700; color: var(--c-slate-900); }
.an__card-hint { font-size: .74rem; color: var(--c-slate-500); }
.an__table-wrap { overflow-x: auto; }
.an__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.an__table th { text-align: left; padding: .65rem 1rem; background: var(--c-slate-50); font-weight: 600; color: var(--c-slate-500); font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1.5px solid var(--c-slate-100); white-space: nowrap; }
.an__th-r, .an__td-r { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
.an__th-total { border-left: 1px solid var(--c-slate-200); }
.an__th-bar { width: 22%; }
.an__table td { padding: .7rem 1rem; border-bottom: 1px solid var(--c-slate-50); color: var(--c-slate-900); vertical-align: top; }
.an__table tbody tr:last-child td { border-bottom: none; }
.an__table--compact td, .an__table--compact th { padding: .5rem .75rem; }
.an__td-bold { font-weight: 700; }
.an__td-warn { color: var(--c-amber-500); font-weight: 700; }
.an__td-bar { padding-left: 0 !important; }
.an__bar { height: 8px; background: var(--c-slate-100); border-radius: 4px; overflow: hidden; min-width: 90px; }
.an__bar i { display: block; height: 100%; background: var(--c-leaf-600); border-radius: 4px; }
.an__row--pocos td { color: var(--c-slate-400); }
.an__row--pocos .an__bar i { background: var(--c-slate-300); }
.an__row--mejor td { background: var(--c-leaf-50); }
.an__pocos, .an__origen { display: block; font-size: .7rem; font-weight: 500; color: var(--c-slate-400); margin-top: 2px; }
.an__fase { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: .78rem; font-weight: 600; background: var(--c-slate-100); color: var(--c-slate-700); }
.an__fase--floracion { background: var(--c-amber-100); color: var(--c-amber-500); }
.an__fase--vegetativo, .an__fase--enraizado { background: var(--c-leaf-100); color: var(--c-leaf-800); }
.an__veredicto { font-size: .78rem; white-space: nowrap; }
.an__mejor { color: var(--c-leaf-700); font-weight: 700; }
.an__contra { color: var(--c-amber-500); font-weight: 600; }

.an__cortes { display: flex; align-items: center; gap: .4rem; margin-bottom: 1rem; flex-wrap: wrap; }
.an__cortes-lbl { font-size: .74rem; color: var(--c-slate-500); font-weight: 600; text-transform: uppercase; letter-spacing: .04em; margin-right: .3rem; }
.an__corte { padding: .35rem .8rem; border: 1.5px solid var(--c-slate-200); border-radius: 999px; background: #fff; font-size: .78rem; font-weight: 600; color: var(--c-slate-600); cursor: pointer; font-family: inherit; }
.an__corte--on { background: var(--c-leaf-700); border-color: var(--c-leaf-700); color: #fff; }

.an__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.an__kpi { background: #fff; border: 1px solid var(--c-slate-200); border-radius: 12px; padding: 1.1rem; }
.an__kpi-val { display: block; font-size: 1.7rem; font-weight: 800; color: var(--c-slate-900); line-height: 1; letter-spacing: -.03em; font-variant-numeric: tabular-nums; }
.an__kpi-lbl { display: block; font-size: .7rem; color: var(--c-slate-500); margin-top: .4rem; font-weight: 600; text-transform: uppercase; letter-spacing: .03em; }
.an__kpi-sub { display: block; font-size: .74rem; color: var(--c-slate-400); margin-top: .25rem; }
.an__kpi--green .an__kpi-val { color: var(--c-leaf-700); }
.an__grid2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1rem; }
</style>
