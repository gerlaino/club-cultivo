<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><Sprout :size="20" :stroke-width="1.75" /> Informe Producción</h1>
      <select v-model="periodo" class="inf__periodo" @change="cargar">
        <option value="mes_actual">Mes actual</option>
        <option value="mes_anterior">Mes anterior</option>
        <option value="trimestre">Trimestre</option>
        <option value="anio">Año</option>
      </select>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <template v-else-if="data">
      <div class="inf__kpis">
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.total_lotes }}</span>
          <span class="inf__kpi-label">Total lotes</span>
        </div>
        <div class="inf__kpi inf__kpi--ok">
          <span class="inf__kpi-valor">{{ data.lotes_activos }}</span>
          <span class="inf__kpi-label">Lotes activos</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.lotes_cosechados }}</span>
          <span class="inf__kpi-label">Cosechados</span>
        </div>
        <div class="inf__kpi inf__kpi--ok">
          <span class="inf__kpi-valor">{{ formatGramos(data.gramos_producidos) }}</span>
          <span class="inf__kpi-label">Gramos producidos</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.plantas_totales }}</span>
          <span class="inf__kpi-label">Plantas totales</span>
        </div>
      </div>

      <div class="inf__section">
        <h2 class="inf__section-title">Lotes por estado</h2>
        <table class="inf__table">
          <thead><tr><th>Estado</th><th>Cantidad</th><th>Plantas</th><th>Gramos</th></tr></thead>
          <tbody>
            <tr v-for="(r, i) in data.por_estado" :key="i">
              <td><span class="inf__badge" :class="`inf__badge--${r.estado}`">{{ r.estado }}</span></td>
              <td>{{ r.lotes }}</td>
              <td>{{ r.plantas }}</td>
              <td>{{ formatGramos(r.gramos) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Sprout } from 'lucide-vue-next'
import api from '../../lib/api.js'

const periodo = ref('mes_actual')
const loading = ref(false)
const data    = ref(null)

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/produccion', { params: { periodo: periodo.value } })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

const formatGramos = (g) => g != null ? `${Number(g).toLocaleString('es-AR')} g` : '—'

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 900px; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__periodo { background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.inf__kpi--ok .inf__kpi-valor { color: #2D8A6B; }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin-bottom: var(--sp-3); }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.inf__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600); }
.inf__badge--activo { background: rgba(45,138,107,.1); color: #2D8A6B; }
.inf__badge--cosechado { background: rgba(91,100,115,.1); color: #5B6473; }
</style>
