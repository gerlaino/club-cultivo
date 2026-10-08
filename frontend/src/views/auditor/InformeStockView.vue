<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><Boxes :size="20" :stroke-width="1.75" /> Informe de stock</h1>
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

    <FiltrosInforme class="inf__filtros" :usa="['origen', 'saldo', 'formas', 'geneticas', 'lotes', 'sedes']" @change="cambiarFiltros" />

    <div v-if="loading" class="inf__loading">Cargando…</div>
    <div v-else-if="data">
      <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>
      <p v-if="data.filtros?.activo" class="inf__filtrado"><i class="bi bi-funnel-fill"></i> Filtrado — {{ data.filtros.descripcion }}</p>

      <!-- ── 1. Qué hay hoy ─────────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Qué hay hoy</h2>
          <span class="inf__section-marco">la foto de ahora · cada unidad en lo suyo</span>
        </div>
        <div class="inf__kpis">
          <div v-for="u in quedaPorUnidad" :key="u.unidad" class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ cant(u.queda, u.unidad) }}</span>
            <span class="inf__kpi-label">Queda ({{ u.unidad }})</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ plata(hoy.valor_costo) }}</span>
            <span class="inf__kpi-label">Valor a costo</span>
            <span v-if="hoy.sin_costo" class="inf__kpi-delta inf__kpi-delta--flat">{{ hoy.sin_costo }} sin costo cargado</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ plata(hoy.valor_venta) }}</span>
            <span class="inf__kpi-label">Valor de venta</span>
            <span v-if="hoy.sin_precio" class="inf__kpi-delta inf__kpi-delta--flat">{{ hoy.sin_precio }} sin precio</span>
          </div>
        </div>
        <!-- La mesa es un LUGAR, no un compromiso: lo libre descuenta eventos y reservas, no la
             mesa. Es el mismo número que valida la dispensa. -->
        <table v-if="hoy.por_unidad?.length" class="inf__table">
          <thead>
            <tr><th>Unidad</th><th>Origen</th><th class="num">Stocks</th><th class="num">Queda</th><th class="num">Sobre una mesa</th><th class="num">Comprometido</th><th class="num">Libre</th></tr>
          </thead>
          <tbody>
            <tr v-for="x in hoy.por_unidad" :key="`${x.unidad}-${x.origen}`">
              <td>{{ x.unidad }}</td>
              <td><span class="inf__badge" :class="{ 'inf__badge--ext': x.origen === 'externo' }">{{ nombreOrigen(x.origen) }}</span></td>
              <td class="num">{{ x.stocks }}</td>
              <td class="num">{{ num(x.queda) }}</td>
              <td class="num">{{ num(x.en_mesa) }}</td>
              <td class="num">{{ num(x.comprometido) }}</td>
              <td class="num"><strong>{{ num(x.libre) }}</strong></td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">No hay stock con saldo.</p>
      </section>

      <!-- ── Lo que entró, por genética ─────────────────────────────────────── -->
      <!-- Lo que se presenta: «en septiembre entraron tantos gramos de cada genética». Suma las
           altas del período y la mercadería que llegó a stocks que ya existían. -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Lo que entró</h2>
          <span class="inf__section-marco">en el período elegido, por genética</span>
        </div>
        <table v-if="data.ingresos?.length" class="inf__table">
          <thead><tr><th>Genética</th><th>Producto</th><th>Origen</th><th class="num">Stocks</th><th class="num">Entró</th></tr></thead>
          <tbody>
            <tr v-for="x in data.ingresos" :key="`${x.genetica}-${x.producto}-${x.unidad}-${x.origen}`">
              <td>{{ x.genetica || '—' }}</td>
              <td>{{ nombreProducto(x.producto) }} <span class="inf__dias">({{ x.unidad }})</span></td>
              <td><span class="inf__badge" :class="{ 'inf__badge--ext': x.origen === 'externo' }">{{ nombreOrigen(x.origen) }}</span></td>
              <td class="num">{{ x.stocks }}</td>
              <td class="num"><strong>{{ cant(x.ingreso, x.unidad) }}</strong></td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">No entró producto en el período elegido.</p>
      </section>

      <!-- ── 2. Stock por stock ─────────────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Stock por stock</h2>
          <span class="inf__section-marco">en la unidad de cada producto · cada fila cierra: había + ingresó − salidas ± ajustes = quedaba</span>
        </div>
        <table v-if="data.stocks.length" class="inf__table">
          <thead>
            <tr>
              <th>Stock</th><th>Producto</th><th>Genética</th><th>De dónde</th>
              <th class="num" title="Lo que tenía el día que empieza el período">Había</th>
              <th class="num">Ingresó</th><th class="num">Dispensado</th><th class="num">Merma</th><th class="num">Otras salidas</th>
              <th class="num" title="Suma de los ajustes manuales (+ suma, − resta). Tocá el número para verlos">Ajustes</th>
              <th class="num" title="Lo que tenía el último día del período">Quedaba</th><th class="num" title="Lo que hoy se puede entregar">Libre hoy</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="f in data.stocks" :key="f.id">
            <tr>
              <td class="mono">{{ f.numero || `#${f.id}` }}</td>
              <td>{{ nombreProducto(f.producto) }} <span class="inf__dias">({{ f.unidad }})</span></td>
              <td>{{ f.genetica || '—' }}</td>
              <td><span class="inf__badge" :class="{ 'inf__badge--ext': f.origen === 'externo' }">{{ nombreOrigen(f.origen) }}</span> {{ f.de_donde || '—' }}</td>
              <td class="num">{{ num(f.habia) }}</td>
              <td class="num">{{ num(f.ingreso) }}</td>
              <td class="num">{{ num(f.dispensado) }}</td>
              <td class="num">{{ num(f.merma) }}</td>
              <td class="num">{{ num(f.otras_salidas) }}</td>
              <td class="num">
                <button v-if="f.ajustes_detalle?.length" type="button" class="inf__ajustes-btn"
                        :aria-expanded="abierto === f.id" :title="`Ver los ${f.ajustes_detalle.length} ajustes`"
                        @click="abierto = abierto === f.id ? null : f.id">{{ f.ajustes > 0 ? '+' : '' }}{{ num(f.ajustes) }}</button>
                <template v-else>{{ num(f.ajustes) }}</template>
              </td>
              <td class="num">
                <strong>{{ num(f.quedaba) }}</strong>
                <span v-if="f.descuadre" class="inf__descuadre" :title="`Los movimientos no explican ${num(Math.abs(f.descuadre))} ${f.unidad}: mirá la trazabilidad del stock`">no cierra</span>
              </td>
              <td class="num">{{ num(f.libre) }}</td>
            </tr>
            <!-- Los ajustes de ese stock, uno por uno: cuándo, cuánto, quién y por qué. -->
            <tr v-if="abierto === f.id" class="inf__ajustes-fila">
              <td colspan="12">
                <ul class="inf__ajustes">
                  <li v-for="(a, i) in f.ajustes_detalle" :key="i">
                    <span class="mono">{{ formatFechaCorta(a.fecha) }}</span>
                    <strong>{{ a.gramos > 0 ? '+' : '' }}{{ num(a.gramos) }} {{ f.unidad }}</strong>
                    <span>{{ a.quien || '—' }}</span>
                    <span class="inf__ajustes-nota">{{ a.notas || 'sin motivo anotado' }}</span>
                  </li>
                </ul>
              </td>
            </tr>
            </template>
          </tbody>
        </table>
        <p v-else class="inf__empty">No hay stock con saldo ni con movimientos en el período elegido.</p>

        <table v-if="data.periodo?.length" class="inf__table inf__table--total">
          <thead><tr><th>En el período</th><th class="num">Había</th><th class="num">Ingresó</th><th class="num">Dispensado</th><th class="num">Merma</th><th class="num">Otras salidas</th><th class="num">Ajustes</th><th class="num">Quedaba</th></tr></thead>
          <tbody>
            <tr v-for="x in data.periodo" :key="x.unidad">
              <td>Total en {{ x.unidad }}</td>
              <td class="num">{{ num(x.habia) }}</td>
              <td class="num">{{ num(x.ingreso) }}</td><td class="num">{{ num(x.dispensado) }}</td>
              <td class="num">{{ num(x.merma) }}</td><td class="num">{{ num(x.otras_salidas) }}</td><td class="num">{{ num(x.ajustes) }}</td>
              <td class="num">{{ num(x.quedaba) }}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <!-- ── 3. Lo que vence y lo que no se mueve ───────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Vence pronto</h2>
          <span class="inf__section-marco">con saldo, en los próximos 30 días o ya vencido</span>
        </div>
        <table v-if="data.vencen.length" class="inf__table">
          <thead><tr><th>Stock</th><th>Producto</th><th>Genética</th><th class="num">Queda</th><th>Vence</th></tr></thead>
          <tbody>
            <tr v-for="f in data.vencen" :key="f.id">
              <td class="mono">{{ f.numero || `#${f.id}` }}</td>
              <td>{{ nombreProducto(f.producto) }}</td>
              <td>{{ f.genetica || '—' }}</td>
              <td class="num">{{ cant(f.queda, f.unidad) }}</td>
              <td>
                {{ formatFechaCorta(f.vence) }}
                <span v-if="f.dias_para_vencer < 0" class="inf__excedido">vencido</span>
                <span v-else class="inf__dias">en {{ f.dias_para_vencer }} días</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">Nada con saldo vence en los próximos 30 días.</p>
      </section>

      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Sin salida hace más de un mes</h2>
          <span class="inf__section-marco">con saldo y sin dispensas ni salidas</span>
        </div>
        <table v-if="data.sin_movimiento.length" class="inf__table">
          <thead><tr><th>Stock</th><th>Producto</th><th>Genética</th><th>Sede</th><th class="num">Queda</th><th>Última salida</th><th class="num">Días quieto</th></tr></thead>
          <tbody>
            <tr v-for="f in data.sin_movimiento" :key="f.id">
              <td class="mono">{{ f.numero || `#${f.id}` }}</td>
              <td>{{ nombreProducto(f.producto) }}</td>
              <td>{{ f.genetica || '—' }}</td>
              <td>{{ f.sede || '—' }}</td>
              <td class="num">{{ cant(f.queda, f.unidad) }}</td>
              <td>{{ f.nunca_salio ? 'nunca' : formatFechaCorta(f.ultima_salida) }}</td>
              <td class="num">{{ f.dias_quieto }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">Todo lo que tiene saldo salió en el último mes.</p>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { Boxes } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'
import SelectorPeriodo from '../../components/informes/SelectorPeriodo.vue'
import FiltrosInforme from '../../components/informes/FiltrosInforme.vue'
import { formatFechaCorta } from '../../utils/dates.js'

// Los stocks con su información (Germán, 29-sep-2026). El cálculo vive en `Informes::Inventario`;
// acá sólo se muestra. Los MISMOS parámetros para la pantalla y la descarga: período + filtros.
const { exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_stock')
const periodo = ref({ periodo: 'mes_actual' })
const filtros = ref({})
const params  = computed(() => ({ ...periodo.value, ...filtros.value }))
const loading = ref(false)
const data    = ref(null)
// El stock con el detalle de ajustes abierto (uno a la vez).
const abierto = ref(null)

const hoy = computed(() => data.value?.hoy || {})
// Un KPI por unidad: lo propio y lo externo juntos, pero nunca gramos con unidades.
const quedaPorUnidad = computed(() => {
  const m = {}
  for (const x of hoy.value.por_unidad || []) m[x.unidad] = (m[x.unidad] || 0) + x.queda
  return Object.entries(m).map(([unidad, queda]) => ({ unidad, queda }))
})

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/stock', { params: params.value })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

function cambiarPeriodo(p) { periodo.value = p; cargar() }
function cambiarFiltros(f) { filtros.value = f; cargar() }

const num   = (c) => Number(c || 0).toLocaleString('es-AR', { maximumFractionDigits: 2 })
const cant  = (c, u) => `${num(c)} ${u}`
const plata = (v) => `$ ${Math.round(Number(v || 0)).toLocaleString('es-AR')}`
const nombreOrigen   = (o) => o === 'externo' ? 'Externo' : 'Propio'
const nombreProducto = (f) => { const t = String(f || '').replace(/_/g, ' '); return t.charAt(0).toUpperCase() + t.slice(1) }

onMounted(cargar)
</script>

<style scoped>
.inf__ajustes-btn { border: 0; background: none; padding: 0; font: inherit; color: var(--c-leaf-800); text-decoration: underline dotted; cursor: pointer; }
.inf__descuadre { display: block; font-size: .68rem; font-weight: 700; color: var(--c-rust-600); }
.inf__ajustes-fila td { background: var(--c-paper); }
.inf__ajustes { list-style: none; margin: 0; padding: .3rem 0; display: flex; flex-direction: column; gap: .3rem; font-size: .82rem; }
.inf__ajustes li { display: grid; grid-template-columns: 90px 90px 160px 1fr; gap: .6rem; }
.inf__ajustes-nota { color: var(--c-slate-500); }
.inf { padding: var(--sp-6); max-width: 1100px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__head-actions { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.inf__pdf { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700); cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__filtros { margin: calc(-1 * var(--sp-3)) 0 var(--sp-5); }
.inf__filtrado { margin: 0 0 var(--sp-5); padding: .55rem .9rem; background: var(--c-leaf-100); color: var(--c-leaf-800); border-radius: var(--r-md); font-size: var(--fs-13); font-weight: 600; }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__empty { color: var(--c-ink-500); padding: var(--sp-4); font-size: var(--fs-13); }
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
.inf__kpi-delta { display: block; font-size: var(--fs-12); margin-top: var(--sp-2); }
.inf__kpi-delta--flat { color: var(--c-ink-500); }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.inf__table--total { margin-top: var(--sp-3); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-100); font-weight: 600; color: var(--c-ink-700); border-bottom: 1px solid var(--c-ink-300); font-size: var(--fs-12); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-100); color: var(--c-ink-900); vertical-align: top; }
.inf__table .num { text-align: right; font-variant-numeric: tabular-nums; }
.inf__table .mono { font-family: var(--font-mono); font-size: var(--fs-13); }
.inf__badge { display: inline-block; padding: 1px 7px; border-radius: 999px; font-size: var(--fs-12); font-weight: 600; background: var(--c-leaf-100); color: var(--c-leaf-800); }
.inf__badge--ext { background: var(--c-amber-100); color: var(--c-amber-500); }
.inf__dias { color: var(--c-ink-500); font-size: var(--fs-12); }
.inf__excedido { display: inline-block; margin-left: var(--sp-2); padding: 1px 7px; border-radius: 999px; background: var(--c-amber-100); color: var(--c-amber-500); font-size: var(--fs-12); font-weight: 600; }

@media (max-width: 640px) {
  .inf { padding: var(--sp-4); }
  .inf__table { display: block; overflow-x: auto; }
  .inf__table th, .inf__table td { white-space: nowrap; }
}
</style>
