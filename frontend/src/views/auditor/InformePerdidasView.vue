<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><TrendingDown :size="20" :stroke-width="1.75" /> Informe de pérdidas</h1>
      <div class="inf__acciones">
        <select v-model="periodo" class="inf__periodo" @change="cargar">
          <option value="mes_actual">Mes actual</option>
          <option value="mes_anterior">Mes anterior</option>
          <option value="trimestre">Trimestre</option>
          <option value="anio">Año</option>
        </select>
        <button class="inf__btn" :disabled="exporting" @click="exportarPdf">
          <FileDown :size="15" :stroke-width="2" /> PDF
        </button>
        <button class="inf__btn" :disabled="exporting" @click="exportarXlsx">
          <Sheet :size="15" :stroke-width="2" /> Excel
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <div v-else-if="data" ref="hoja" class="inf__hoja">
      <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>

      <div class="inf__kpis">
        <div class="inf__kpi" :class="data.plantas_descartadas ? 'inf__kpi--warn' : 'inf__kpi--ok'">
          <span class="inf__kpi-valor">{{ data.plantas_descartadas }}</span>
          <span class="inf__kpi-label">Plantas descartadas</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ fmtG(data.merma_g) }}</span>
          <span class="inf__kpi-label">Merma declarada</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ fmtG(data.ajustes_negativos_g) }}</span>
          <span class="inf__kpi-label">Ajustes en menos</span>
        </div>
        <!-- Todavía no es pérdida: está en góndola. Pero si no se mueve, lo va a ser. -->
        <div class="inf__kpi" :class="data.stock_vencido_g ? 'inf__kpi--err' : 'inf__kpi--ok'">
          <span class="inf__kpi-valor">{{ fmtG(data.stock_vencido_g) }}</span>
          <span class="inf__kpi-label">Vencido en góndola</span>
        </div>
      </div>

      <div class="inf__section">
        <h2 class="inf__section-title">Plantas descartadas, por motivo</h2>
        <p class="inf__section-hint">
          El motivo es lo accionable: varias por plaga es un problema de sala; varios machos,
          un problema de semilla.
        </p>
        <table v-if="motivos.length" class="inf__table">
          <thead><tr><th>Motivo</th><th class="inf__num">Plantas</th></tr></thead>
          <tbody>
            <tr v-for="[motivo, n] in motivos" :key="motivo">
              <td>{{ motivo }}</td>
              <td class="inf__num">{{ n }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">No se descartó ninguna planta en el período.</p>
      </div>

      <div class="inf__section">
        <h2 class="inf__section-title">Producto perdido</h2>
        <table class="inf__table">
          <thead><tr><th>Concepto</th><th class="inf__num">Gramos</th></tr></thead>
          <tbody>
            <tr><td>Merma declarada</td><td class="inf__num">{{ fmtG(data.merma_g) }}</td></tr>
            <tr><td>Ajustes de inventario en menos</td><td class="inf__num">{{ fmtG(data.ajustes_negativos_g) }}</td></tr>
            <tr class="inf__row-total">
              <td><strong>Total perdido</strong></td>
              <td class="inf__num"><strong>{{ fmtG(data.total_gramos) }}</strong></td>
            </tr>
            <tr>
              <td>Vencido todavía en góndola <span class="inf__nota">({{ data.stock_vencido_items }} ítems)</span></td>
              <td class="inf__num">{{ fmtG(data.stock_vencido_g) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { TrendingDown, FileDown, Sheet } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'

const periodo = ref('mes_actual')
const loading = ref(false)
const data    = ref(null)
const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_perdidas', 'perdidas')

const motivos = computed(() =>
  Object.entries(data.value?.plantas_por_motivo || {}).sort((a, b) => b[1] - a[1]))
const fmtG = (g) => `${Number(g || 0).toLocaleString('es-AR')} g`

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/perdidas', { params: { periodo: periodo.value } })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__acciones { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.inf__periodo, .inf__btn { background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-slate-700); cursor: pointer; }
.inf__btn { display: inline-flex; align-items: center; gap: 6px; color: var(--c-leaf-700, #15803d); }
.inf__btn:disabled { opacity: .5; cursor: not-allowed; }
.inf__loading { color: var(--c-slate-500); padding: var(--sp-8); text-align: center; }
.inf__hoja { background: #fff; }
.inf__resena { margin: 0 0 var(--sp-4); padding: .7rem .9rem; background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300); border-radius: 0 8px 8px 0; font-size: var(--fs-13); color: var(--c-slate-600); line-height: 1.55; max-width: 80ch; }
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-slate-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-24); font-weight: 800; color: var(--c-slate-900); line-height: 1.1; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-slate-500); margin-top: var(--sp-1); }
.inf__kpi--ok   .inf__kpi-valor { color: #15803d; }
.inf__kpi--warn .inf__kpi-valor { color: #b45309; }
.inf__kpi--err  .inf__kpi-valor { color: #dc2626; }
.inf__section { margin-bottom: var(--sp-6); }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin-bottom: var(--sp-3); }
.inf__section-hint { margin: calc(var(--sp-3) * -1) 0 var(--sp-3); font-size: var(--fs-12); color: var(--c-slate-500); line-height: 1.5; }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.inf__table th { text-align: left; font-size: var(--fs-12); text-transform: uppercase; letter-spacing: .04em; color: var(--c-slate-500); padding: .5rem .6rem; border-bottom: 1px solid var(--c-slate-200); }
.inf__table td { padding: .55rem .6rem; border-bottom: 1px solid var(--c-slate-50); color: var(--c-slate-700); }
.inf__num { text-align: right; }
.inf__row-total td { border-top: 1px solid var(--c-slate-200); color: var(--c-slate-900); }
.inf__nota { font-size: var(--fs-12); color: var(--c-slate-400); }
.inf__empty { font-size: var(--fs-13); color: var(--c-slate-500); font-style: italic; }
</style>
