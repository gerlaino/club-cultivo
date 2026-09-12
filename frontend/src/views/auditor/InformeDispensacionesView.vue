<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><Package :size="20" :stroke-width="1.75" /> Informe de dispensaciones</h1>
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

      <!-- ── 1. Lo que salió ──────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Lo que salió</h2>
          <span class="inf__section-marco">por unidad, nunca sumado · comparado con el período anterior</span>
        </div>
        <div class="inf__kpis">
          <!-- Cada unidad en lo suyo: 12 prerolls no son 12 gramos. -->
          <div v-for="u in salio.por_unidad" :key="u.unidad" class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ cant(u.cantidad, u.unidad) }}</span>
            <span class="inf__kpi-label">{{ nombreUnidad(u.unidad) }}</span>
            <span class="inf__kpi-delta" :class="claseDelta(u.variacion)">{{ textoDelta(u.variacion, u.anterior != null ? cant(u.anterior, u.unidad) : null) }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ salio.entregas.valor }}</span>
            <span class="inf__kpi-label">Entregas</span>
            <span class="inf__kpi-delta" :class="claseDelta(salio.entregas.variacion)">{{ textoDelta(salio.entregas.variacion, salio.entregas.anterior) }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ salio.pacientes.valor }}</span>
            <span class="inf__kpi-label">Pacientes</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">{{ salio.nuevos }} {{ salio.nuevos === 1 ? 'retiró' : 'retiraron' }} por primera vez</span>
          </div>
        </div>
        <!-- Los regalos cuentan —salieron— y se dicen: sin esta línea el admin ve gramos que no cobró. -->
        <p v-if="salio.regalos_entregas" class="inf__nota">De eso, {{ salio.regalos.map(r => cant(r.cantidad, r.unidad)).join(' · ') }} fueron regalos, en {{ salio.regalos_entregas }} {{ salio.regalos_entregas === 1 ? 'entrega' : 'entregas' }}.</p>

        <table v-if="data.productos.length" class="inf__table">
          <thead>
            <tr><th>Producto</th><th>Genética</th><th class="num">Entregas</th><th class="num">Cantidad</th><th class="num">Pacientes</th><th class="num">vs. anterior</th></tr>
          </thead>
          <tbody>
            <template v-for="f in data.productos" :key="f.forma">
              <tr class="inf__fila-forma">
                <td><span class="inf__badge">{{ nombreForma(f.forma) }}</span></td>
                <td class="inf__todas">todas</td>
                <td class="num">{{ f.entregas }}</td>
                <td class="num">{{ cant(f.cantidad, f.unidad) }}</td>
                <td class="num">{{ f.pacientes }}</td>
                <td class="num"></td>
              </tr>
              <tr v-for="g in f.geneticas" :key="f.forma + g.genetica">
                <td></td>
                <td>{{ g.genetica }}</td>
                <td class="num">{{ g.entregas }}</td>
                <td class="num">{{ cant(g.cantidad, f.unidad) }}</td>
                <td class="num">{{ g.pacientes }}</td>
                <td class="num" :class="claseDelta(g.variacion)">{{ deltaCorto(g.variacion) }}</td>
              </tr>
            </template>
          </tbody>
        </table>
        <p v-else class="inf__nota">No se dispensó nada en el período elegido.</p>
      </section>

      <!-- ── 2. A quién ───────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">A quién</h2>
          <span class="inf__section-marco">una fila por paciente, ordenada por lo que retiró</span>
        </div>
        <table v-if="data.pacientes.length" class="inf__table">
          <thead>
            <!-- Últimos TRES del DNI en pantalla; el entero va sólo en el PDF y el Excel. -->
            <tr><th>Paciente</th><th>DNI</th><th class="num">Entregas</th><th class="num">Flor seca</th><th>Otros</th><th>Genéticas</th><th>Última</th></tr>
          </thead>
          <tbody>
            <tr v-for="r in data.pacientes" :key="r.paciente + r.dni_ultimos_3">
              <td>{{ r.paciente || '—' }}</td>
              <td class="mono">···{{ r.dni_ultimos_3 }}</td>
              <td class="num">{{ r.entregas }}</td>
              <td class="num">{{ r.flor_seca_g ? cant(r.flor_seca_g, 'g') : '—' }}</td>
              <td>{{ otros(r.otros) }}</td>
              <td>{{ r.geneticas.join(', ') || '—' }}</td>
              <td>{{ fecha(r.ultima_fecha) }}</td>
            </tr>
            <!-- Los totales de arriba son sobre todos; acá se listan los primeros cien. -->
            <tr v-if="data.pacientes_omitidos">
              <td colspan="7" class="inf__mas">… {{ data.pacientes_omitidos }} pacientes más. Los totales son sobre todos; el PDF y el Excel los llevan completos.</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">Nadie retiró en el período elegido.</p>
      </section>

      <!-- ── 3. Por dónde ─────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Por dónde</h2>
          <span class="inf__section-marco">mostrador de cada sede, o envío a domicilio</span>
        </div>
        <table v-if="data.canales.length" class="inf__table">
          <thead>
            <tr><th>Canal</th><th class="num">Entregas</th><th class="num">Flor seca</th><th>Otros</th><th class="num">Pacientes</th></tr>
          </thead>
          <tbody>
            <tr v-for="c in data.canales" :key="c.canal">
              <td>{{ c.canal }}<span v-if="c.sin_llegar" class="inf__excedido">{{ c.sin_llegar }} sin llegar todavía</span></td>
              <td class="num">{{ c.entregas }}</td>
              <td class="num">{{ c.flor_seca_g ? cant(c.flor_seca_g, 'g') : '—' }}</td>
              <td>{{ otros(c.otros) }}</td>
              <td class="num">{{ c.pacientes }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No se dispensó nada en el período elegido.</p>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { Package } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'
import SelectorPeriodo from '../../components/informes/SelectorPeriodo.vue'

const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_dispensaciones')

// Los MISMOS parámetros para la pantalla y para la descarga: antes el PDF bajaba siempre «mes
// actual» aunque en pantalla estuviera el trimestre.
const params  = ref({ periodo: 'mes_actual' })
const loading = ref(false)
const data    = ref(null)
const salio   = computed(() => data.value?.salio || { por_unidad: [], entregas: {}, pacientes: {}, regalos: [] })

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/dispensaciones', { params: params.value })
    data.value = res.data
  } finally {
    loading.value = false
  }
}
function cambiarPeriodo(p) { params.value = p; cargar() }

const FORMAS = { flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura', crema: 'Crema',
  capsula: 'Cápsula', comestible: 'Comestible', prensado: 'Prensado', preroll: 'Preroll', otro: 'Otro', externo: 'Externo' }
const nombreForma  = (f) => FORMAS[f] || String(f).replaceAll('_', ' ')
const UNIDADES = { g: 'En gramos', un: 'En unidades', ml: 'En mililitros' }
const nombreUnidad = (u) => UNIDADES[u] || `En ${u}`
const cant  = (c, u) => `${Number(c).toLocaleString('es-AR', { maximumFractionDigits: 1 })} ${u}`
// «10 g de hash · 6 un de preroll»: cada cosa en su forma y su unidad, nunca sumadas.
const otros = (lista) => (lista || []).map(o => `${cant(o.cantidad, o.unidad)} ${nombreForma(o.forma).toLowerCase()}`).join(' · ') || '—'
const fecha = (d) => d ? new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—'

// «▲ 12 % vs. anterior (2.535 g)». Sin anterior no hay flecha: «▲ ∞ %» no le dice nada a nadie.
const textoDelta = (v, anterior) => {
  if (v == null) return 'sin datos del período anterior'
  const flecha = v > 0 ? '▲' : v < 0 ? '▼' : '='
  return `${flecha} ${Math.abs(v)} % vs. anterior (${anterior})`
}
const deltaCorto = (v) => v == null ? '—' : v === 0 ? '=' : `${v > 0 ? '▲' : '▼'} ${Math.abs(v)} %`
const claseDelta = (v) => v == null || v === 0 ? 'inf__kpi-delta--flat' : v > 0 ? 'inf__kpi-delta--up' : 'inf__kpi-delta--down'

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

.inf__fila-forma td { background: var(--c-ink-50); font-weight: 600; }
.inf__todas { color: var(--c-ink-500); font-weight: 400; font-size: var(--fs-13); }
.inf__mas { color: var(--c-ink-500); font-size: var(--fs-13); font-style: italic; }
.inf__table td.inf__kpi-delta--up { color: var(--c-leaf-600); }
.inf__table td.inf__kpi-delta--down { color: var(--c-amber-500); }
.inf__table td.inf__kpi-delta--flat { color: var(--c-ink-500); }

@media (max-width: 640px) {
  .inf { padding: var(--sp-4); }
  .inf__table { display: block; overflow-x: auto; }
  .inf__table th, .inf__table td { white-space: nowrap; }
}
</style>
