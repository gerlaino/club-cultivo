<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><TrendingDown :size="20" :stroke-width="1.75" /> Informe de pérdidas</h1>
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

      <!-- ── 1. Lo que no llegó a cosecha ──────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Lo que no llegó a cosecha</h2>
          <span class="inf__section-marco">plantas descartadas en el período · comparado con el anterior</span>
        </div>
        <div class="inf__kpis">
          <div class="inf__kpi" :class="pl.total ? 'inf__kpi--warn' : 'inf__kpi--ok'">
            <span class="inf__kpi-valor">{{ pl.total }}</span>
            <span class="inf__kpi-label">Plantas descartadas</span>
            <span class="inf__kpi-delta" :class="claseDeltaMalo(pl.total, pl.anterior)">{{ textoDeltaAbs(pl.total, pl.anterior) }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ pl.porcentaje }} %</span>
            <span class="inf__kpi-label">De las plantas en cultivo</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">{{ pl.total }} de {{ pl.total + pl.en_cultivo }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ fmtArs(pl.costo_ars) }}</span>
            <span class="inf__kpi-label">Producirlas costó</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">{{ pl.sin_costo ? `${pl.sin_costo} sin costo cargado en su lote` : 'costo del lote prorrateado por planta' }}</span>
          </div>
        </div>
        <table v-if="pl.por_motivo.length" class="inf__table">
          <thead><tr><th>Motivo</th><th class="num">Plantas</th><th>Lotes</th><th>Última</th></tr></thead>
          <tbody>
            <tr v-for="m in pl.por_motivo" :key="m.motivo">
              <td>{{ motivoLabel(m.motivo) }}</td>
              <td class="num">{{ m.plantas }}</td>
              <td class="mono">{{ m.lotes.map(l => l.plantas > 1 ? `${l.codigo} (${l.plantas})` : l.codigo).join(' · ') }}</td>
              <td>{{ fecha(m.ultima) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No se descartó ninguna planta en el período.</p>
        <!-- Planta por planta, plegada: el motivo agrupado es lo que se lee; la lista es lo que se busca. -->
        <div v-if="pl.lista.length" class="inf__plegable">
          <button type="button" class="inf__plegar" @click="listaAbierta = !listaAbierta">
            <i :class="listaAbierta ? 'bi bi-chevron-down' : 'bi bi-chevron-right'"></i>
            {{ listaAbierta ? 'Ocultar' : 'Ver' }} planta por planta ({{ pl.lista.length }}{{ pl.omitidas ? ` de ${pl.lista.length + pl.omitidas}` : '' }})
          </button>
          <table v-if="listaAbierta" class="inf__table">
            <thead><tr><th>Fecha</th><th>Lote</th><th>Planta</th><th>Genética</th><th>Motivo</th><th class="num">Costó</th></tr></thead>
            <tbody>
              <tr v-for="p in pl.lista" :key="p.id">
                <td>{{ fecha(p.fecha) }}<span v-if="p.fecha_estimada" class="inf__aprox" title="Sin registro del día del descarte: es la fecha de la última edición"> aprox.</span></td>
                <td class="mono">{{ p.lote }}</td>
                <td class="mono">{{ p.nombre }}</td>
                <td>{{ p.genetica || '—' }}</td>
                <td>{{ motivoLabel(p.motivo) }}</td>
                <td class="num">{{ p.costo_ars != null ? fmtArs(p.costo_ars) : '—' }}</td>
              </tr>
              <tr v-if="pl.omitidas"><td colspan="6" class="inf__mas">… {{ pl.omitidas }} plantas más. El PDF y el Excel las llevan completas.</td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <!-- ── 2. Lo que se perdió después ───────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Lo que se perdió después</h2>
          <span class="inf__section-marco">producto que salió del inventario sin entregarse · por unidad, nunca sumado</span>
        </div>
        <div class="inf__kpis">
          <div v-for="u in pr.por_unidad" :key="u.unidad" class="inf__kpi inf__kpi--warn">
            <span class="inf__kpi-valor">{{ cant(u.cantidad, u.unidad) }}</span>
            <span class="inf__kpi-label">{{ nombreUnidad(u.unidad) }}</span>
            <span class="inf__kpi-delta" :class="claseDeltaMalo(u.cantidad, u.anterior)">{{ u.anterior != null ? textoDeltaAbs(u.cantidad, u.anterior, u.unidad) : 'sin datos del período anterior' }}</span>
          </div>
          <div v-if="!pr.por_unidad.length" class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">0</span>
            <span class="inf__kpi-label">No se perdió producto</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ fmtArs(pr.costo_ars) }}</span>
            <span class="inf__kpi-label">Producirlo costó</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">{{ pr.sin_costo ? `${pr.sin_costo} sin costo cargado` : 'al costo de cada frasco' }}</span>
          </div>
        </div>
        <p v-if="pr.mostrador_por_unidad.length" class="inf__nota">
          De eso, {{ pr.mostrador_por_unidad.map(x => cant(x.cantidad, x.unidad)).join(' · ') }} son diferencias de conteo del mostrador (neto por frasco: un error corregido no cuenta). El detalle cierre por cierre está en <RouterLink :to="{ path: '/mostrador', query: { solapa: 'merma' } }">Mostrador → Merma</RouterLink>.
        </p>
        <table v-if="pr.lista.length" class="inf__table">
          <thead><tr><th>Fecha</th><th>Frasco</th><th>Qué pasó</th><th class="num">Cantidad</th><th class="num">Costó</th></tr></thead>
          <tbody>
            <tr v-for="(f, i) in pr.lista" :key="i">
              <td>{{ fecha(f.fecha) }}</td>
              <td><span class="mono">{{ f.frasco || '—' }}</span><span v-if="f.genetica" class="inf__gen"> · {{ f.genetica }}</span></td>
              <td>{{ f.que_paso }}<span v-if="f.detalle" class="inf__detalle"> · «{{ f.detalle }}»</span></td>
              <td class="num">{{ cant(f.cantidad, f.unidad) }}</td>
              <td class="num">{{ f.costo_ars != null ? fmtArs(f.costo_ars) : '—' }}</td>
            </tr>
            <tr v-if="pr.omitidas"><td colspan="5" class="inf__mas">… {{ pr.omitidas }} más. El PDF y el Excel las llevan completas.</td></tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No se perdió producto en el período.</p>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { TrendingDown } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'
import SelectorPeriodo from '../../components/informes/SelectorPeriodo.vue'

const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_perdidas', 'perdidas')

// Los MISMOS parámetros para la pantalla y para la descarga.
const params  = ref({ periodo: 'mes_actual' })
const loading = ref(false)
const data    = ref(null)
const listaAbierta = ref(false)
const pl = computed(() => data.value?.plantas  || { total: 0, anterior: 0, en_cultivo: 0, porcentaje: 0, costo_ars: 0, sin_costo: 0, por_motivo: [], lista: [], omitidas: 0 })
const pr = computed(() => data.value?.producto || { por_unidad: [], merma_por_unidad: [], mostrador_por_unidad: [], costo_ars: 0, sin_costo: 0, lista: [], omitidas: 0 })

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/perdidas', { params: params.value })
    data.value = res.data
  } finally {
    loading.value = false
  }
}
function cambiarPeriodo(p) { params.value = p; cargar() }

// Plant::MOTIVOS_DESCARTE, en el idioma en que se habla de ellos.
const MOTIVOS = { no_prendio: 'No prendió', plaga: 'Plaga', enfermedad: 'Enfermedad', macho: 'Macho', hermafrodita: 'Hermafrodita',
  estres: 'Estrés', rotura: 'Rotura', otro: 'Otro', sin_motivo: 'Sin motivo' }
const motivoLabel = (m) => MOTIVOS[m] || String(m).replaceAll('_', ' ')
const UNIDADES = { g: 'En gramos', un: 'En unidades', ml: 'En mililitros' }
const nombreUnidad = (u) => UNIDADES[u] || `En ${u}`
const cant   = (c, u) => `${Number(c).toLocaleString('es-AR', { maximumFractionDigits: 1 })} ${u}`
const fmtArs = (v) => `$ ${Math.round(Number(v || 0)).toLocaleString('es-AR')}`
const fecha  = (d) => d ? new Date(String(d).slice(0, 10) + 'T00:00:00').toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—'

// En un informe de pérdidas, SUBIR es malo: la flecha para arriba va en ámbar y la de abajo en
// verde, al revés que en Producción. Y se compara en cantidad, no en porcentaje: «▲ 3 vs. julio (10)»
// se entiende; «▲ 30 %» sobre diez plantas, no.
const textoDeltaAbs = (v, ant, u = '') => {
  if (ant == null) return 'sin datos del período anterior'
  const d = Number(v) - Number(ant)
  const flecha = d > 0 ? '▲' : d < 0 ? '▼' : '='
  const num = Math.abs(d).toLocaleString('es-AR', { maximumFractionDigits: 1 })
  return d === 0 ? `= igual que el anterior (${cant(ant, u).trim()})` : `${flecha} ${num}${u ? ' ' + u : ''} vs. anterior (${cant(ant, u).trim()})`
}
const claseDeltaMalo = (v, ant) => ant == null || Number(v) === Number(ant) ? 'inf__kpi-delta--flat' : Number(v) > Number(ant) ? 'inf__kpi-delta--down' : 'inf__kpi-delta--up'

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
.inf__kpi--warn .inf__kpi-valor { color: var(--c-amber-500); }
.inf__plegable { margin-top: var(--sp-3); }
.inf__plegar { background: none; border: none; padding: 0; margin-bottom: var(--sp-2); cursor: pointer; font: inherit; font-size: var(--fs-13); font-weight: 600; color: var(--c-leaf-700, #15803d); display: inline-flex; align-items: center; gap: .3rem; }
.inf__aprox { font-size: var(--fs-12); color: var(--c-ink-500); }
.inf__mas { color: var(--c-ink-500); font-size: var(--fs-13); font-style: italic; }
.inf__gen { color: var(--c-ink-500); font-size: var(--fs-13); }
.inf__detalle { color: var(--c-ink-500); }
.inf__nota a { color: var(--c-leaf-700, #15803d); }

@media (max-width: 640px) {
  .inf { padding: var(--sp-4); }
  .inf__table { display: block; overflow-x: auto; }
  .inf__table th, .inf__table td { white-space: nowrap; }
}
</style>
