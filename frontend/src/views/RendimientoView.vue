<template>
  <div class="rnd">
    <div class="rnd__header">
      <h1 class="rnd__title"><TrendingUp :size="22" :stroke-width="1.75" /> Rendimiento</h1>
      <button class="rnd__refresh" @click="cargar" :disabled="loading">
        <RefreshCw :size="15" :stroke-width="1.75" :class="{ 'rnd__spin': loading }" />
      </button>
    </div>

    <div v-if="loading && !data" class="rnd__loading">Cargando analytics…</div>

    <template v-if="data">
      <!-- KPIs globales -->
      <div class="rnd__kpis">
        <div class="rnd__kpi">
          <span class="rnd__kpi-val">{{ data.resumen.lotes_totales }}</span>
          <span class="rnd__kpi-lbl">Lotes en sistema</span>
        </div>
        <div class="rnd__kpi">
          <span class="rnd__kpi-val">{{ data.resumen.lotes_finalizados }}</span>
          <span class="rnd__kpi-lbl">Finalizados</span>
        </div>
        <div class="rnd__kpi">
          <span class="rnd__kpi-val">{{ data.resumen.geneticas_activas }}</span>
          <span class="rnd__kpi-lbl">Genéticas activas</span>
        </div>
        <div class="rnd__kpi rnd__kpi--ok">
          <span class="rnd__kpi-val">{{ data.resumen.rendimiento_global_g != null ? `${data.resumen.rendimiento_global_g} g` : '—' }}</span>
          <span class="rnd__kpi-lbl">Rendimiento promedio</span>
        </div>
      </div>

      <!-- Por genética -->
      <div class="rnd__section">
        <h2 class="rnd__section-title">Por genética</h2>

        <div v-if="!data.por_genetica.length" class="rnd__empty">
          Sin datos suficientes. Los lotes necesitan tener rendimiento real registrado.
        </div>

        <table v-else class="rnd__table">
          <thead>
            <tr>
              <th>Genética</th>
              <th class="rnd__th-num">Lotes</th>
              <th class="rnd__th-num">Rend. prom. (g)</th>
              <th class="rnd__th-num">Obj. prom. (g)</th>
              <th class="rnd__th-num">Desvío</th>
              <th class="rnd__th-num">Merma %</th>
              <th class="rnd__th-num">Activos</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="g in data.por_genetica" :key="g.genetica_id">
              <td class="rnd__td-nombre">{{ g.nombre }}</td>
              <td class="rnd__td-num">{{ g.lotes_total }}</td>
              <td class="rnd__td-num rnd__td-bold">{{ g.rendimiento_promedio != null ? `${g.rendimiento_promedio} g` : '—' }}</td>
              <td class="rnd__td-num">{{ g.objetivo_promedio != null ? `${g.objetivo_promedio} g` : '—' }}</td>
              <td class="rnd__td-num">
                <span v-if="g.desviacion_promedio != null" class="rnd__desv" :class="g.desviacion_promedio >= 0 ? 'rnd__desv--pos' : 'rnd__desv--neg'">
                  {{ g.desviacion_promedio >= 0 ? '+' : '' }}{{ g.desviacion_promedio }}%
                </span>
                <span v-else class="rnd__nd">—</span>
              </td>
              <td class="rnd__td-num">
                <span v-if="g.merma_promedio_pct != null" class="rnd__merma" :class="g.merma_promedio_pct > 20 ? 'rnd__merma--alta' : 'rnd__merma--ok'">
                  {{ g.merma_promedio_pct }}%
                </span>
                <span v-else class="rnd__nd">—</span>
              </td>
              <td class="rnd__td-num">
                <span v-if="g.lotes_activos" class="rnd__activo">{{ g.lotes_activos }}</span>
                <span v-else class="rnd__nd">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Lotes recientes -->
      <div class="rnd__section">
        <h2 class="rnd__section-title">Lotes recientes</h2>
        <table class="rnd__table">
          <thead>
            <tr>
              <th>Código</th>
              <th>Genética</th>
              <th>Estado</th>
              <th class="rnd__th-num">Plantas</th>
              <th class="rnd__th-num">Real (g)</th>
              <th class="rnd__th-num">Obj. (g)</th>
              <th class="rnd__th-num">Desvío</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="l in data.lotes_recientes" :key="l.id">
              <td>
                <RouterLink :to="`/lotes/${l.id}`" class="rnd__link">{{ l.codigo }}</RouterLink>
              </td>
              <td class="rnd__td-gen">{{ l.genetica || '—' }}</td>
              <td><span class="rnd__badge" :class="`rnd__badge--${l.estado}`">{{ l.estado }}</span></td>
              <td class="rnd__td-num">{{ l.plants_count ?? '—' }}</td>
              <td class="rnd__td-num rnd__td-bold">{{ l.rendimiento_real_g != null ? `${l.rendimiento_real_g} g` : '—' }}</td>
              <td class="rnd__td-num">{{ l.rendimiento_obj_g != null ? `${l.rendimiento_obj_g} g` : '—' }}</td>
              <td class="rnd__td-num">
                <span v-if="l.desv_pct != null" class="rnd__desv" :class="l.desv_pct >= 0 ? 'rnd__desv--pos' : 'rnd__desv--neg'">
                  {{ l.desv_pct >= 0 ? '+' : '' }}{{ l.desv_pct }}%
                </span>
                <span v-else class="rnd__nd">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { TrendingUp, RefreshCw } from 'lucide-vue-next'
import { getAnalyticsRendimiento } from '../lib/api.js'

const loading = ref(false)
const data    = ref(null)

async function cargar() {
  loading.value = true
  try {
    const res = await getAnalyticsRendimiento()
    data.value = res.data
  } catch {
    // silent
  } finally {
    loading.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.rnd { padding: var(--sp-6) var(--sp-8); max-width: 1100px; }
@media (max-width: 767px) { .rnd { padding: var(--sp-4); } }

.rnd__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); }
.rnd__title { font-family: var(--font-display); font-size: var(--fs-24); font-weight: 600; color: var(--c-ink-900); margin: 0; display: flex; align-items: center; gap: var(--sp-2); }
.rnd__refresh { background: var(--c-ink-100); border: none; border-radius: var(--r-md); padding: .5rem; cursor: pointer; color: var(--c-ink-500); display: flex; align-items: center; transition: all .15s; }
.rnd__refresh:hover { background: var(--c-ink-200); color: var(--c-ink-900); }
.rnd__spin { animation: rnd-spin .7s linear infinite; }
@keyframes rnd-spin { to { transform: rotate(360deg); } }

.rnd__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }

/* KPIs */
.rnd__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.rnd__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.rnd__kpi-val { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.rnd__kpi-lbl { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.rnd__kpi--ok .rnd__kpi-val { color: var(--c-role-cultivador, #2D8A6B); }

/* Sections */
.rnd__section { margin-bottom: var(--sp-6); }
.rnd__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0 0 var(--sp-3); }

/* Table */
.rnd__table { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.rnd__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); white-space: nowrap; }
.rnd__th-num { text-align: right; }
.rnd__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.rnd__td-num { text-align: right; }
.rnd__td-bold { font-weight: 700; }
.rnd__td-nombre { font-weight: 600; }
.rnd__td-gen { color: var(--c-ink-500); font-size: var(--fs-12); }
.rnd__link { color: var(--c-role-cultivador, #1b5e20); font-weight: 600; text-decoration: none; font-family: monospace; }
.rnd__link:hover { text-decoration: underline; }
.rnd__desv { font-weight: 700; }
.rnd__desv--pos { color: #2D8A6B; }
.rnd__desv--neg { color: #dc2626; }
.rnd__merma { font-weight: 600; }
.rnd__merma--ok   { color: #2D8A6B; }
.rnd__merma--alta { color: #dc2626; }
.rnd__activo { background: rgba(45,138,107,.1); color: #2D8A6B; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-12); font-weight: 700; }
.rnd__nd { color: var(--c-ink-300); }
.rnd__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 10px; font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600); }
.rnd__badge--vegetativo { background: rgba(45,138,107,.1); color: #2D8A6B; }
.rnd__badge--floracion  { background: rgba(217,119,6,.1); color: #b45309; }
.rnd__badge--cosecha, .rnd__badge--secado, .rnd__badge--curado { background: rgba(91,100,115,.1); color: #5B6473; }
.rnd__badge--finalizado { background: var(--c-ink-100); color: var(--c-ink-400); }
.rnd__empty { color: var(--c-ink-500); font-size: var(--fs-14); background: var(--c-ink-50); padding: var(--sp-5); border-radius: var(--r-lg); text-align: center; }
</style>
