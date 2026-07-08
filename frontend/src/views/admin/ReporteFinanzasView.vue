<script setup>
// Reporte consolidado de Finanzas (Bloque 4): rango de fechas + números del período + export.
import { ref, computed, onMounted } from 'vue'
import { getReporteFinanzas, exportReporteFinanzas } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const data = ref(null)
const loading = ref(false)

const hoy = new Date().toISOString().slice(0, 10)
const inicioMes = hoy.slice(0, 8) + '01'
const desde = ref(inicioMes)
const hasta = ref(hoy)

const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

async function cargar() {
  loading.value = true
  try {
    const { data: d } = await getReporteFinanzas({ desde: desde.value, hasta: hasta.value })
    data.value = d
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudo generar el reporte')
  } finally {
    loading.value = false
  }
}
onMounted(cargar)

async function exportar() {
  try {
    const res = await exportReporteFinanzas({ desde: desde.value, hasta: hasta.value })
    const url = window.URL.createObjectURL(new Blob([res.data]))
    const a = document.createElement('a')
    a.href = url
    a.download = `reporte_${desde.value}_${hasta.value}.csv`
    document.body.appendChild(a); a.click(); a.remove()
    window.URL.revokeObjectURL(url)
  } catch {
    toast.error('No se pudo exportar')
  }
}

const maxSerie = computed(() => {
  if (!data.value?.serie?.length) return 1
  return Math.max(1, ...data.value.serie.flatMap(m => [m.ingresos, m.egresos]))
})
</script>

<template>
  <div class="rep">
    <header class="rep__head">
      <div>
        <h1>Reporte de Finanzas</h1>
        <p>El corte del período: qué entró, qué salió y el resultado. Exportable a CSV.</p>
      </div>
    </header>

    <div class="rep__controls">
      <label>Desde <input type="date" v-model="desde" class="inp" /></label>
      <label>Hasta <input type="date" v-model="hasta" class="inp" /></label>
      <button class="btn btn--primary" @click="cargar" :disabled="loading">Generar</button>
      <button class="btn" @click="exportar" :disabled="!data">⭳ Exportar CSV</button>
    </div>

    <div v-if="loading" class="rep__loading">Generando reporte…</div>

    <template v-else-if="data">
      <div class="rep__kpis">
        <div class="kpi kpi--in"><span>Ingresos</span><strong>{{ fmt(data.ingresos) }}</strong></div>
        <div class="kpi kpi--out"><span>Egresos</span><strong>{{ fmt(data.egresos) }}</strong></div>
        <div class="kpi" :class="data.resultado >= 0 ? 'kpi--in' : 'kpi--out'"><span>Resultado</span><strong>{{ fmt(data.resultado) }}</strong></div>
        <div class="kpi"><span>Aportaciones</span><strong>{{ fmt(data.aportaciones) }}</strong></div>
        <div class="kpi"><span>Dispensado</span><strong>{{ Math.round(data.dispensado_gramos) }} g</strong></div>
        <div class="kpi"><span>Por cobrar (CC)</span><strong>{{ fmt(data.por_cobrar) }}</strong></div>
      </div>

      <!-- Gráfico mensual -->
      <section v-if="data.serie?.length" class="card">
        <h2>Ingresos · Egresos · Resultado</h2>
        <div class="chart">
          <div v-for="m in data.serie" :key="m.mes" class="chart__col">
            <div class="chart__bars">
              <div class="chart__bar chart__bar--in" :style="{ height: (m.ingresos / maxSerie * 100) + '%' }" :title="`Ingresos ${fmt(m.ingresos)}`"></div>
              <div class="chart__bar chart__bar--out" :style="{ height: (m.egresos / maxSerie * 100) + '%' }" :title="`Egresos ${fmt(m.egresos)}`"></div>
            </div>
            <span class="chart__lbl">{{ m.mes.slice(5) }}</span>
          </div>
        </div>
        <div class="legend"><span class="dot dot--in"></span>Ingresos <span class="dot dot--out"></span>Egresos</div>
      </section>

      <div class="rep__cols">
        <!-- Gastos por categoría -->
        <section class="card">
          <h2>Gastos por categoría</h2>
          <div v-if="!data.gastos_por_categoria?.length" class="empty">Sin egresos en el período.</div>
          <ul v-else class="brk">
            <li v-for="g in data.gastos_por_categoria" :key="g.categoria">
              <span>{{ g.categoria }}</span><span class="num">{{ fmt(g.total) }}</span>
            </li>
          </ul>
        </section>

        <!-- Por unidad -->
        <section class="card">
          <h2>Resultado por unidad</h2>
          <div v-if="!data.por_unidad?.length" class="empty">Sin datos.</div>
          <ul v-else class="brk">
            <li v-for="u in data.por_unidad" :key="u.id ?? 'sin'">
              <span>{{ u.nombre }}</span>
              <span class="num" :class="u.balance >= 0 ? 'pos' : 'neg'">{{ fmt(u.balance) }}</span>
            </li>
          </ul>
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.rep { padding: var(--sp-6, 24px); max-width: 940px; margin: 0 auto; }
.rep__head h1 { font-size: var(--fs-24, 24px); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.rep__head p { color: var(--c-ink-500); margin: 4px 0 0; font-size: var(--fs-14, 14px); }
.rep__controls { display: flex; align-items: flex-end; gap: var(--sp-3, 12px); margin: var(--sp-5, 20px) 0; flex-wrap: wrap; }
.rep__controls label { display: flex; flex-direction: column; gap: 4px; font-size: var(--fs-12, 12px); color: var(--c-ink-500); }
.rep__loading { color: var(--c-ink-500); padding: var(--sp-8, 32px); text-align: center; }

.rep__kpis { display: grid; grid-template-columns: repeat(6, 1fr); gap: 10px; }
@media (max-width: 780px) { .rep__kpis { grid-template-columns: repeat(2, 1fr); } }
.kpi { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-md, 10px); padding: var(--sp-3, 12px) var(--sp-4, 16px); }
.kpi span { font-size: var(--fs-11, 11px); color: var(--c-ink-400); text-transform: uppercase; letter-spacing: .04em; }
.kpi strong { display: block; font-size: var(--fs-18, 18px); font-weight: 700; color: var(--c-ink-900); margin-top: 5px; font-variant-numeric: tabular-nums; }
.kpi--in strong { color: var(--c-leaf-700, #2f6b3d); }
.kpi--out strong { color: var(--c-rust-600, #b23b2e); }

.card { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); margin-top: var(--sp-4, 16px); }
.card h2 { font-size: var(--fs-16, 16px); font-weight: 650; color: var(--c-ink-900); margin: 0 0 var(--sp-4, 16px); }
.empty { color: var(--c-ink-400); font-size: var(--fs-13, 13px); text-align: center; padding: var(--sp-3, 12px) 0; }

.chart { display: flex; align-items: flex-end; gap: 12px; height: 160px; padding: 0 4px; }
.chart__col { flex: 1; display: flex; flex-direction: column; align-items: center; height: 100%; }
.chart__bars { flex: 1; display: flex; align-items: flex-end; gap: 3px; width: 100%; justify-content: center; }
.chart__bar { width: 42%; border-radius: 4px 4px 0 0; min-height: 2px; }
.chart__bar--in { background: var(--c-leaf-700, #2f6b3d); }
.chart__bar--out { background: var(--c-rust-600, #b23b2e); opacity: .8; }
.chart__lbl { font-size: var(--fs-11, 11px); color: var(--c-ink-400); margin-top: 6px; }
.legend { display: flex; align-items: center; gap: 8px; font-size: var(--fs-12, 12px); color: var(--c-ink-500); margin-top: 10px; }
.dot { width: 10px; height: 10px; border-radius: 3px; display: inline-block; }
.dot--in { background: var(--c-leaf-700, #2f6b3d); } .dot--out { background: var(--c-rust-600, #b23b2e); }

.rep__cols { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
@media (max-width: 640px) { .rep__cols { grid-template-columns: 1fr; } }
.brk { list-style: none; margin: 0; padding: 0; }
.brk li { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid var(--c-ink-100); font-size: var(--fs-14, 14px); color: var(--c-ink-700); }
.brk li:last-child { border-bottom: none; }
.num { font-variant-numeric: tabular-nums; font-weight: 600; color: var(--c-ink-900); }
.num.pos { color: var(--c-leaf-700, #2f6b3d); } .num.neg { color: var(--c-rust-600, #b23b2e); }

.inp { padding: 7px 9px; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm, 8px); font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); color: var(--c-ink-900); }
.btn { border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-800); border-radius: var(--r-sm, 8px); padding: 8px 14px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.btn--primary { background: var(--c-leaf-700, #2f6b3d); border-color: var(--c-leaf-700, #2f6b3d); color: #fff; }
.btn:disabled { opacity: .5; cursor: default; }
</style>
