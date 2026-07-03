<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><BarChart2 :size="20" :stroke-width="1.75" /> Plan vs Real</h1>
      <button class="inf__pdf" :disabled="!data || exporting" @click="exportarPdf">
          <i class="bi bi-filetype-pdf"></i> {{ exporting ? 'Generando…' : 'PDF' }}
        </button>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <div v-else-if="data" ref="hoja" class="inf__hoja">
      <div class="inf__kpis">
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.total_lotes_con_objetivo }}</span>
          <span class="inf__kpi-label">Lotes con objetivo</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.total_lotes_cerrados }}</span>
          <span class="inf__kpi-label">Lotes cerrados</span>
        </div>
        <div class="inf__kpi" :class="desvClass(data.promedio_desviacion_pct)">
          <span class="inf__kpi-valor">{{ formatDesv(data.promedio_desviacion_pct) }}</span>
          <span class="inf__kpi-label">Desviación promedio</span>
        </div>
      </div>

      <div v-if="data.detalle.length === 0" class="inf__empty">
        No hay lotes con objetivos definidos. Configurá los objetivos desde el detalle de cada lote.
      </div>

      <div v-else class="inf__section">
        <h2 class="inf__section-title">Detalle por lote</h2>
        <table class="inf__table">
          <thead>
            <tr>
              <th>Lote</th>
              <th>Estado</th>
              <th>Plantas obj.</th>
              <th>Plantas real</th>
              <th>Rend. obj. (g)</th>
              <th>Rend. real (g)</th>
              <th>Desviación</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="l in data.detalle" :key="l.id">
              <td class="inf__td-codigo">{{ l.codigo }}</td>
              <td><span class="inf__badge" :class="`inf__badge--${l.estado}`">{{ l.estado }}</span></td>
              <td>{{ l.plants_count_objetivo ?? '—' }}</td>
              <td>{{ l.plants_count_cosechadas ?? '—' }}</td>
              <td>{{ l.rendimiento_objetivo_g != null ? `${Number(l.rendimiento_objetivo_g).toLocaleString('es-AR')} g` : '—' }}</td>
              <td>{{ l.rendimiento_real_g != null ? `${Number(l.rendimiento_real_g).toLocaleString('es-AR')} g` : '—' }}</td>
              <td>
                <span v-if="l.desv_rendimiento_pct != null" class="inf__desv" :class="l.desv_rendimiento_pct >= 0 ? 'inf__desv--pos' : 'inf__desv--neg'">
                  {{ l.desv_rendimiento_pct >= 0 ? '+' : '' }}{{ l.desv_rendimiento_pct }}%
                </span>
                <span v-else class="inf__nd">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { BarChart2 } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'

const { hoja, exporting, exportarPdf } = useInformePdf('informe_plan_vs_real')

const loading = ref(false)
const data    = ref(null)

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/plan_vs_real')
    data.value = res.data
  } finally {
    loading.value = false
  }
}

const formatDesv = (v) => v != null ? `${v >= 0 ? '+' : ''}${v}%` : '—'
const desvClass  = (v) => v == null ? '' : v >= 0 ? 'inf__kpi--ok' : 'inf__kpi--warn'

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 960px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__head-actions { display: flex; align-items: center; gap: var(--sp-2); }
.inf__pdf { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700, #15803d); cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__empty { color: var(--c-ink-500); font-size: var(--fs-14); padding: var(--sp-6); text-align: center; background: var(--c-ink-50); border-radius: var(--r-lg); }
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.inf__kpi--ok .inf__kpi-valor { color: #2D8A6B; }
.inf__kpi--warn .inf__kpi-valor { color: #dc2626; }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin-bottom: var(--sp-3); }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); white-space: nowrap; }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.inf__td-codigo { font-weight: 600; font-family: monospace; }
.inf__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600); }
.inf__badge--vegetativo { background: rgba(45,138,107,.1); color: #2D8A6B; }
.inf__badge--floracion { background: rgba(217,119,6,.1); color: #b45309; }
.inf__badge--cosecha { background: rgba(91,100,115,.1); color: #5B6473; }
.inf__badge--finalizado { background: var(--c-ink-100); color: var(--c-ink-500); }
.inf__desv { font-weight: 700; font-size: var(--fs-13); }
.inf__desv--pos { color: #2D8A6B; }
.inf__desv--neg { color: #dc2626; }
.inf__nd { color: var(--c-ink-400); }
</style>
