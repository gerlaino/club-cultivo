<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><ShieldAlert :size="20" :stroke-width="1.75" /> Informe Cumplimiento</h1>
      <div class="inf__head-actions">
        <select v-model="periodo" class="inf__periodo" @change="cargar">
        <option value="mes_actual">Mes actual</option>
        <option value="mes_anterior">Mes anterior</option>
        <option value="trimestre">Trimestre</option>
        <option value="anio">Año</option>
      </select>
        <button class="inf__pdf" :disabled="!data || exporting" @click="exportarPdf">
          <i class="bi bi-filetype-pdf"></i> {{ exporting ? 'Generando…' : 'PDF' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <div v-else-if="data" ref="hoja" class="inf__hoja">
      <div class="inf__kpis">
        <div class="inf__kpi inf__kpi--ok">
          <span class="inf__kpi-valor">{{ data.pacientes_con_reprocann_vigente }}</span>
          <span class="inf__kpi-label">REPROCANN vigente</span>
        </div>
        <div class="inf__kpi inf__kpi--warn">
          <span class="inf__kpi-valor">{{ data.reprocann_vencen_30d }}</span>
          <span class="inf__kpi-label">Vencen en 30 días</span>
        </div>
        <div class="inf__kpi inf__kpi--err">
          <span class="inf__kpi-valor">{{ data.reprocann_vencidos }}</span>
          <span class="inf__kpi-label">REPROCANN vencido</span>
        </div>
        <div class="inf__kpi inf__kpi--err">
          <span class="inf__kpi-valor">{{ data.dispensaciones_sobre_limite }}</span>
          <span class="inf__kpi-label">Sobre límite</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ pct(data.tasa_cumplimiento) }}</span>
          <span class="inf__kpi-label">Tasa cumplimiento</span>
        </div>
      </div>

      <div class="inf__section">
        <h2 class="inf__section-title">Alertas de cumplimiento</h2>
        <div v-if="!data.alertas?.length" class="inf__empty">Sin alertas en el período</div>
        <table v-else class="inf__table">
          <thead><tr><th>Tipo</th><th>Paciente</th><th>Detalle</th></tr></thead>
          <tbody>
            <tr v-for="(a, i) in data.alertas" :key="i">
              <td><span class="inf__badge" :class="`inf__badge--${a.severidad}`">{{ a.tipo }}</span></td>
              <td>{{ a.iniciales }}</td>
              <td>{{ a.detalle }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ShieldAlert } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'

const { hoja, exporting, exportarPdf } = useInformePdf('informe_cumplimiento')

const periodo = ref('mes_actual')
const loading = ref(false)
const data    = ref(null)

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/cumplimiento', { params: { periodo: periodo.value } })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

const pct = (v) => v != null ? `${Math.round(v)}%` : '—'

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__head-actions { display: flex; align-items: center; gap: var(--sp-2); }
.inf__pdf { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700, #15803d); cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__periodo { background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__empty { color: var(--c-ink-400); font-size: var(--fs-14); padding: var(--sp-4) 0; }
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.inf__kpi--ok .inf__kpi-valor { color: #2D8A6B; }
.inf__kpi--warn .inf__kpi-valor { color: #B85C00; }
.inf__kpi--err .inf__kpi-valor { color: var(--c-rust-600); }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin-bottom: var(--sp-3); }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.inf__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600); }
.inf__badge--warning { background: rgba(184,92,0,.1); color: #B85C00; }
.inf__badge--error { background: rgba(180,40,40,.1); color: var(--c-rust-600); }
</style>
