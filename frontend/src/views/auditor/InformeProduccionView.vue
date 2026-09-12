<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><Sprout :size="20" :stroke-width="1.75" /> Informe Producción</h1>
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

    <!-- TRES BLOQUES EN TRES MARCOS DE TIEMPO: el período elegido gobierna sólo el primero. Los
         otros dos son de hoy y de lo que viene, y decirlo en cada encabezado es lo que evita
         que un lote curado el mes pasado parezca contradecir al KPI de arriba. -->
    <div v-else-if="data" ref="hoja" class="inf__hoja">
      <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>

      <!-- ── 1. Lo que se cosechó ─────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Lo que se cosechó</h2>
          <span class="inf__section-marco">del período elegido · comparado con el anterior</span>
        </div>

        <div class="inf__kpis">
          <div class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ formatGramos(per.gramos) }}</span>
            <span class="inf__kpi-label">Flor seca cosechada</span>
            <span class="inf__kpi-delta" :class="claseDelta(per.variacion.gramos)">{{ textoDelta(per.variacion.gramos, formatGramos(per.anterior.gramos)) }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ per.total_lotes }}</span>
            <span class="inf__kpi-label">Lotes cosechados</span>
            <span class="inf__kpi-delta" :class="claseDelta(per.variacion.total_lotes)">{{ textoDelta(per.variacion.total_lotes, per.anterior.total_lotes) }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ formatGramos(per.gramos_por_planta) }}</span>
            <span class="inf__kpi-label">Por planta cosechada</span>
            <span class="inf__kpi-delta" :class="claseDelta(per.variacion.gramos_por_planta)">{{ textoDelta(per.variacion.gramos_por_planta, formatGramos(per.anterior.gramos_por_planta)) }}</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ per.plantas }}</span>
            <span class="inf__kpi-label">Plantas cosechadas</span>
            <span class="inf__kpi-delta" :class="claseDelta(per.variacion.plantas)">{{ textoDelta(per.variacion.plantas, per.anterior.plantas) }}</span>
          </div>
        </div>

        <!-- Sin la lista, el total no se puede comprobar ni cruzar con la trazabilidad. -->
        <table v-if="per.lotes.length" class="inf__table">
          <thead>
            <tr>
              <th>Lote</th><th>Genética</th><th>Sede</th><th>Cosecha</th>
              <th class="num">Plantas</th><th class="num">Flor seca</th><th class="num">g / planta</th><th class="num">Días de ciclo</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="l in per.lotes" :key="l.id">
              <td class="mono">{{ l.codigo }}</td>
              <td>{{ l.genetica || '—' }}</td>
              <td>{{ l.sede || '—' }}</td>
              <td>{{ formatFechaCorta(l.fecha) }}</td>
              <td class="num">{{ l.plantas ?? '—' }}</td>
              <td class="num"><span v-if="l.gramos == null" class="inf__sin-peso">sin peso todavía</span><template v-else>{{ formatGramos(l.gramos) }}</template></td>
              <td class="num">{{ l.gramos_por_planta ?? '—' }}</td>
              <td class="num">{{ l.dias_ciclo ?? '—' }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">No se cosechó ningún lote en el período elegido.</p>
        <p v-if="per.sin_peso" class="inf__nota">
          {{ per.sin_peso === 1 ? 'Un lote todavía no tiene peso' : `${per.sin_peso} lotes todavía no tienen peso` }}: se cuenta como cosechado y sus gramos van a sumar acá cuando se cierre el curado.
        </p>
      </section>

      <!-- ── 2. Hoy en el cultivo ─────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Hoy en el cultivo</h2>
          <span class="inf__section-marco">la foto de ahora, no del período</span>
        </div>

        <div class="inf__kpis">
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ hoy.plantas_en_pie }}</span>
            <span class="inf__kpi-label">Plantas en cultivo</span>
            <!-- Sólo en el plan con tope. Es EL MISMO número contra el que el alta rebota
                 (PlanEnforcer), no las plantas en pie: si dijera otro, el informe diría «queda
                 lugar» y el alta no dejaría. -->
            <template v-if="hoy.plan">
              <span class="inf__kpi-delta inf__kpi-delta--flat">{{ hoy.plan.cuentan }} de {{ hoy.plan.tope }} del plan {{ hoy.plan.label }} · {{ porcentaje(hoy.plan.cuentan, hoy.plan.tope) }} %</span>
              <span class="inf__bar"><i :style="{ width: Math.min(100, porcentaje(hoy.plan.cuentan, hoy.plan.tope)) + '%' }"></i></span>
            </template>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ hoy.lotes_en_pie }}</span>
            <span class="inf__kpi-label">Lotes en cultivo</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">enraizado · vegetativo · floración</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ hoy.lotes_en_proceso }}</span>
            <span class="inf__kpi-label">Lotes cosechados</span>
            <span class="inf__kpi-delta inf__kpi-delta--flat">cosecha · manicura · curado</span>
          </div>
        </div>

        <table v-if="hoy.por_estado.length" class="inf__table">
          <thead>
            <tr>
              <th>Etapa</th><th class="num">Lotes</th><th class="num">Plantas</th><th class="num">Días ahí (prom.)</th><th>El más viejo</th><th class="num">Rendimiento acumulado</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="e in hoy.por_estado" :key="e.estado">
              <td><span class="inf__badge">{{ nombreEstado(e.estado) }}</span></td>
              <td class="num">{{ e.lotes }}</td>
              <!-- Cortadas en cosecha y manicura son plantas todavía (colgadas, pesándose);
                   en curado el backend manda null y acá va «—»: ya es flor en frasco. -->
              <td class="num">{{ e.plantas ?? '—' }}</td>
              <td class="num">{{ e.dias_promedio ?? '—' }}</td>
              <td>
                <template v-if="e.mas_viejo">
                  <span class="mono">{{ e.mas_viejo.codigo }}</span> · {{ e.mas_viejo.dias }} días
                  <!-- Se marca contra el objetivo que el lote heredó de la genética; sin objetivo,
                       no se marca: un número fijo sería una regla más escrita en otro lado. -->
                  <span v-if="e.mas_viejo.excedido" class="inf__excedido">objetivo {{ e.mas_viejo.objetivo }}</span>
                </template>
                <template v-else>—</template>
              </td>
              <td class="num">{{ e.rendimiento ? formatGramos(e.rendimiento) : '—' }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">No hay lotes en el cultivo ahora mismo.</p>
      </section>

      <!-- ── 3. Lo que viene ──────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Lo que viene</h2>
          <span class="inf__section-marco">todo lo que está en floración</span>
        </div>

        <table v-if="data.proximas.length" class="inf__table">
          <thead>
            <tr><th>Lote</th><th>Genética</th><th>Sala</th><th class="num">Plantas</th><th>Cosecha estimada</th><th class="num">Estimado</th></tr>
          </thead>
          <tbody>
            <tr v-for="p in data.proximas" :key="p.id">
              <td class="mono">{{ p.codigo }}</td>
              <td>{{ p.genetica || '—' }}</td>
              <td>{{ p.sala || '—' }}</td>
              <td class="num">{{ p.plantas }}</td>
              <td>
                <template v-if="p.fecha">{{ formatFechaCorta(p.fecha) }} <span class="inf__dias">{{ enDias(p.dias) }}</span></template>
                <span v-else class="inf__sin-peso">sin fecha</span>
              </td>
              <!-- El estimado sale del g/planta HISTÓRICO de esa genética en esta organización.
                   Sin historia no se inventa: un número inventado se lee como promesa. -->
              <td class="num">
                <template v-if="p.estimado != null">≈ {{ formatGramos(p.estimado) }} <span class="inf__dias">a {{ p.gramos_por_planta_ref }} g/planta</span></template>
                <span v-else class="inf__sin-peso">sin historia para estimar</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">No hay lotes en floración.</p>
      </section>

      <!-- ── Por sede ─────────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Por sede</h2>
        </div>
        <table v-if="data.por_sede?.length" class="inf__table">
          <thead><tr><th>Sede</th><th class="num">Salas</th><th class="num">Plantas en cultivo</th><th class="num">Flor seca disponible</th></tr></thead>
          <tbody>
            <tr v-for="s in data.por_sede" :key="s.id">
              <td>{{ s.nombre }}</td>
              <td class="num">{{ s.salas }}</td>
              <td class="num">{{ s.plantas }}</td>
              <td class="num">{{ formatGramos(s.stock_disponible) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">La organización todavía no tiene sedes cargadas.</p>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { Sprout } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'
import SelectorPeriodo from '../../components/informes/SelectorPeriodo.vue'
import { formatFechaCorta } from '../../utils/dates.js'

const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_produccion')
// Los MISMOS parámetros para la pantalla y para la descarga.
const params  = ref({ periodo: 'mes_actual' })
const loading = ref(false)
const data    = ref(null)

const per = computed(() => data.value?.periodo || {})
const hoy = computed(() => data.value?.hoy || {})

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/produccion', { params: params.value })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

const ESTADOS = {
  enraizado: 'Enraizado', vegetativo: 'Vegetativo', floracion: 'Floración',
  cosecha: 'Cosecha', en_manicura: 'En manicura', curado: 'Curado',
}
const nombreEstado = (e) => ESTADOS[e] || e
const formatGramos = (g) => g != null ? `${Number(g).toLocaleString('es-AR')} g` : '—'
const porcentaje   = (a, b) => b ? Math.round((a / b) * 100) : 0

// «▲ 12 % vs. anterior (2.535 g)». Sin anterior no hay flecha: «▲ ∞ %» no le dice nada a nadie.
const textoDelta = (v, anterior) => {
  if (v == null) return 'sin datos del período anterior'
  const flecha = v > 0 ? '▲' : v < 0 ? '▼' : '='
  return `${flecha} ${Math.abs(v)} % vs. anterior (${anterior})`
}
const claseDelta = (v) => v == null || v === 0 ? 'inf__kpi-delta--flat' : v > 0 ? 'inf__kpi-delta--up' : 'inf__kpi-delta--down'
const enDias = (d) => d < 0 ? `hace ${-d} días` : d === 0 ? 'hoy' : d === 1 ? 'mañana' : `en ${d} días`

function cambiarPeriodo(p) { params.value = p; cargar() }

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

@media (max-width: 640px) {
  .inf { padding: var(--sp-4); }
  /* La tabla scrollea en su contenedor en vez de partir cada celda en una torre de sílabas. */
  .inf__table { display: block; overflow-x: auto; }
  .inf__table th, .inf__table td { white-space: nowrap; }
}
</style>
