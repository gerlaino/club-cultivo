<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><BarChart2 :size="20" :stroke-width="1.75" /> Plan vs. real</h1>
      <div class="inf__head-actions">
        <SelectorPeriodo @change="cambiarPeriodo" />
        <button class="inf__pdf" :disabled="!data || exporting" @click="exportarPdf(params)">
          <i class="bi bi-filetype-pdf"></i> {{ exporting ? 'Generando…' : 'PDF' }}
        </button>
        <button class="inf__pdf" :disabled="!data || exporting" @click="exportarXlsx(params)">
          <i class="bi bi-file-earmark-spreadsheet"></i> Excel
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>
    <div v-else-if="data" ref="hoja" class="inf__hoja">
      <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>

      <!-- ── 1. Cómo salió ──────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Cómo salió</h2>
          <span class="inf__section-marco">lotes cosechados en el período, contra su plan</span>
        </div>
        <div class="inf__kpis">
          <div class="inf__kpi">
            <span class="inf__kpi-valor" :class="claseDesvio(sa.gramos.desvio_pct)">{{ pct(sa.gramos.desvio_pct) }}</span>
            <span class="inf__kpi-label">Gramos, contra el plan</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">{{ sa.gramos.lotes ? `${g(sa.gramos.real)} reales de ${g(sa.gramos.plan)} planeados · ${sa.gramos.lotes} ${sa.gramos.lotes === 1 ? 'lote' : 'lotes'}` : 'sin lotes con plan y real' }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor" :class="claseDias(sa.floracion.real, sa.floracion.plan)">{{ dias(sa.floracion.real, sa.floracion.plan) }}</span>
            <span class="inf__kpi-label">Floración, contra el plan</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">{{ sa.floracion.lotes ? `promedio: ${sa.floracion.real} reales de ${sa.floracion.plan} planeados` : 'sin fechas para comparar' }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ sa.gramos_por_planta.real != null ? g(sa.gramos_por_planta.real) : '—' }}</span>
            <span class="inf__kpi-label">Por planta</span>
            <span class="inf__kpi-delta" :class="claseDesvio(desvio(sa.gramos_por_planta.real, sa.gramos_por_planta.plan))">{{ sa.gramos_por_planta.plan != null ? `${pct(desvio(sa.gramos_por_planta.real, sa.gramos_por_planta.plan))} vs. plan (${g(sa.gramos_por_planta.plan)})` : 'sin plan de plantas' }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ sa.cumplieron }} de {{ sa.evaluables }}</span>
            <span class="inf__kpi-label">Cumplieron el plan</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">gramos dentro del ±{{ data.tolerancia.gramos_pct }} % y floración dentro de ±{{ data.tolerancia.dias }} días</span>
          </div>
        </div>
        <table v-if="sa.lotes.length" class="inf__table">
          <thead>
            <tr><th>Lote</th><th>Genética</th><th class="num">Plantas</th><th class="num">g plan</th><th class="num">g real</th><th class="num">g/planta</th><th class="num">Vege plan / real</th><th class="num">Flora plan / real</th><th>Veredicto</th></tr>
          </thead>
          <tbody>
            <tr v-for="l in sa.lotes" :key="l.id">
              <td class="mono">{{ l.codigo }}</td>
              <td>{{ l.genetica || '—' }}</td>
              <td class="num">{{ l.plantas ?? '—' }}</td>
              <td class="num">{{ l.g_plan != null ? g(l.g_plan) : '—' }}</td>
              <td class="num">{{ l.g_real != null ? g(l.g_real) : '—' }}</td>
              <td class="num">{{ l.g_por_planta != null ? g(l.g_por_planta) : '—' }}</td>
              <td class="num">{{ l.vege_plan ?? '—' }} / {{ l.vege_real ?? '—' }}</td>
              <td class="num">{{ l.flora_plan ?? '—' }} / {{ l.flora_real ?? '—' }}</td>
              <td :class="{ 'inf__mal': l.cumplio === false }">{{ l.veredicto }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No se cosechó ningún lote en el período elegido.</p>
      </section>

      <!-- ── 2. Cómo viene ──────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Cómo viene</h2>
          <span class="inf__section-marco">lotes en cultivo, contra su plan hasta hoy</span>
        </div>
        <table v-if="data.viene.length" class="inf__table">
          <thead><tr><th>Lote</th><th>Genética</th><th>Etapa</th><th class="num">Días plan / hoy</th><th>Cosecha planeada</th><th>Cómo viene</th></tr></thead>
          <tbody>
            <tr v-for="l in data.viene" :key="l.id">
              <td class="mono">{{ l.codigo }}</td>
              <td>{{ l.genetica || '—' }}</td>
              <td><span class="inf__badge">{{ nombreEstado(l.estado) }}</span></td>
              <td class="num">{{ l.dias_plan ?? '—' }} / {{ l.dias_hoy ?? '—' }}</td>
              <td>{{ fecha(l.cosecha_planeada) }}</td>
              <td :class="{ 'inf__mal': l.pasado_dias > data.tolerancia.dias }">{{ l.como_viene }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No hay lotes en cultivo.</p>
      </section>

      <!-- ── 3. Qué dice la genética ────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Qué dice la genética</h2>
          <span class="inf__section-marco">lo que rinde de verdad en esta organización, contra su ficha · sobre todos sus lotes cerrados</span>
        </div>
        <table v-if="data.geneticas.length" class="inf__table">
          <thead><tr><th>Genética</th><th class="num">Lotes cerrados</th><th class="num">g/planta ficha</th><th class="num">g/planta real</th><th class="num">Floración ficha / real</th><th></th></tr></thead>
          <tbody>
            <tr v-for="x in data.geneticas" :key="x.genetica">
              <td>{{ x.genetica }}</td>
              <td class="num">{{ x.lotes }}</td>
              <td class="num">{{ x.g_por_planta_ficha ?? '—' }}</td>
              <td class="num">{{ x.g_por_planta_real != null ? g(x.g_por_planta_real) : '—' }}</td>
              <td class="num">{{ x.floracion_ficha ?? '—' }} / {{ x.floracion_real ?? '—' }}</td>
              <td class="inf__frase-gen">{{ x.frase }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">Todavía no hay lotes cerrados con rendimiento.</p>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { BarChart2 } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'
import SelectorPeriodo from '../../components/informes/SelectorPeriodo.vue'
import { ESTADO_META } from '../../lib/loteHelpers.js'

const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_plan_vs_real', 'plan_vs_real')

// Los MISMOS parámetros para la pantalla y para la descarga.
const params  = ref({ periodo: 'mes_actual' })
const loading = ref(false)
const data    = ref(null)
const sa = computed(() => data.value?.salio || { lotes: [], gramos: {}, gramos_por_planta: {}, floracion: {}, vegetativo: {}, cumplieron: 0, evaluables: 0 })

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/plan_vs_real', { params: params.value })
    data.value = res.data
  } finally {
    loading.value = false
  }
}
function cambiarPeriodo(p) { params.value = p; cargar() }

const nombreEstado = (e) => ESTADO_META[e]?.label || e
const g   = (v) => `${Number(v).toLocaleString('es-AR', { maximumFractionDigits: 1 })} g`
const pct = (v) => v == null ? '—' : `${v > 0 ? '▲ ' : v < 0 ? '▼ ' : ''}${Math.abs(v)} %`
const fecha = (d) => d ? new Date(String(d).slice(0, 10) + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—'
const desvio = (real, plan) => real != null && plan ? Math.round(((real - plan) / plan) * 1000) / 10 : null
// «+9 días» de floración es lo que se lee; el número suelto no.
const dias = (real, plan) => real == null || plan == null ? '—' : (real - plan === 0 ? '= plan' : `${real - plan > 0 ? '+' : ''}${real - plan} días`)
// Dentro de la tolerancia es normal y no se pinta; fuera, ámbar. Nunca «crítico» por un −2 %.
const claseDesvio = (v) => v == null || Math.abs(v) <= (data.value?.tolerancia?.gramos_pct ?? 10) ? '' : 'inf__fuera'
const claseDias   = (real, plan) => real == null || plan == null || Math.abs(real - plan) <= (data.value?.tolerancia?.dias ?? 7) ? '' : 'inf__fuera'

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 960px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__head-actions { display: flex; align-items: center; gap: var(--sp-2); }
.inf__pdf { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700); cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__periodo { background: var(--c-ink-100); border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__empty { color: var(--c-ink-500); padding: var(--sp-4); font-size: var(--fs-13); }
.inf__nota { color: var(--c-ink-500); font-size: var(--fs-13); margin: var(--sp-2) 0 0; }
.inf__resena {
  margin: 0 0 var(--sp-6); padding: .7rem .9rem;
  background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-slate-600); line-height: 1.55; max-width: 80ch;
}

.inf__section { margin-bottom: var(--sp-8); }
.inf__section-head { display: flex; align-items: baseline; gap: var(--sp-3); flex-wrap: wrap; margin-bottom: var(--sp-3); }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.inf__section-marco { font-size: var(--fs-12); color: var(--c-ink-500); }

.inf__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: var(--sp-3); margin-bottom: var(--sp-4); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-3) var(--sp-4); }
.inf__kpi-valor { display: block; font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); line-height: 1.1; font-variant-numeric: tabular-nums; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-700); margin-top: var(--sp-1); }
.inf__kpi--ok .inf__kpi-valor { color: var(--c-leaf-600); }
.inf__kpi-delta { display: block; font-size: var(--fs-12); margin-top: var(--sp-2); font-variant-numeric: tabular-nums; }
.inf__kpi-delta--up   { color: var(--c-leaf-600); }
/* Ámbar y no rojo: producir menos que el mes pasado es un dato, no una falta. */
.inf__kpi-delta--down { color: var(--c-amber-500); }
.inf__kpi-delta--flat { color: var(--c-ink-500); }
.inf__bar { display: block; height: 6px; background: var(--c-ink-100); border-radius: 3px; overflow: hidden; margin-top: var(--sp-2); }
.inf__bar i { display: block; height: 100%; background: var(--c-leaf-500); }

.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-100); font-weight: 600; color: var(--c-ink-700); border-bottom: 1px solid var(--c-ink-300); font-size: var(--fs-12); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-100); color: var(--c-ink-900); vertical-align: top; }
.inf__table .num { text-align: right; font-variant-numeric: tabular-nums; }
.inf__table .mono { font-family: var(--font-mono); font-size: var(--fs-13); }
.inf__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-12); font-weight: 600; background: var(--c-leaf-100); color: var(--c-leaf-800); }
.inf__sin-peso { color: var(--c-ink-500); font-style: italic; font-size: var(--fs-13); }
.inf__dias { color: var(--c-ink-500); font-size: var(--fs-12); }
.inf__excedido { display: inline-block; margin-left: var(--sp-2); padding: 1px 7px; border-radius: 999px; background: var(--c-amber-100); color: var(--c-amber-500); font-size: var(--fs-12); font-weight: 600; }

.inf__hoja { background: #fff; }
.inf__fuera { color: var(--c-amber-500) !important; }
.inf__mal { color: var(--c-amber-500); }
.inf__frase-gen { color: var(--c-ink-700); font-size: var(--fs-13); }

@media (max-width: 640px) {
  .inf { padding: var(--sp-4); }
  .inf__table { display: block; overflow-x: auto; }
  .inf__table th, .inf__table td { white-space: nowrap; }
}
</style>
