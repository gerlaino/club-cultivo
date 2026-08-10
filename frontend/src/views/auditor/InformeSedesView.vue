<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><Building2 :size="20" :stroke-width="1.75" /> Informe Sedes</h1>
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
        <button class="inf__pdf" :disabled="!data || exporting" @click="exportarXlsx">
          <i class="bi bi-file-earmark-spreadsheet"></i> Excel
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <div v-else-if="data" ref="hoja" class="inf__hoja">
      <!-- Qué contesta este informe. Sin esto hay que deducirlo de los números, y
           dos informes que cortan el mismo dato distinto parecen contradecirse. -->
      <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>
      <div class="inf__kpis">
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.total_sedes }}</span>
          <span class="inf__kpi-label">Total sedes</span>
        </div>
        <div class="inf__kpi inf__kpi--ok">
          <span class="inf__kpi-valor">{{ data.sedes_activas }}</span>
          <span class="inf__kpi-label">Activas</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.salas_totales }}</span>
          <span class="inf__kpi-label">Salas totales</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.plantas_totales }}</span>
          <span class="inf__kpi-label">Plantas totales</span>
        </div>
      </div>

      <div class="inf__section">
        <h2 class="inf__section-title">Detalle por sede</h2>
        <table class="inf__table">
          <thead><tr><th>Sede</th><th>Salas</th><th>Plantas</th><th>Stock disponible (g)</th></tr></thead>
          <tbody>
            <tr v-for="(s, i) in data.por_sede" :key="i">
              <td>{{ s.nombre }}</td>
              <td>{{ s.salas }}</td>
              <td>{{ s.plantas }}</td>
              <td>{{ formatGramos(s.stock_disponible) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Building2 } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'

const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_sedes')

const periodo = ref('mes_actual')
const loading = ref(false)
const data    = ref(null)

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/sedes', { params: { periodo: periodo.value } })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

const formatGramos = (g) => g != null ? `${Number(g).toLocaleString('es-AR')} g` : '—'

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
.inf__resena {
  margin: 0 0 var(--sp-4); padding: .7rem .9rem;
  background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-slate-600); line-height: 1.55; max-width: 80ch;
}
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.inf__kpi--ok .inf__kpi-valor { color: #2D8A6B; }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin-bottom: var(--sp-3); }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
</style>
