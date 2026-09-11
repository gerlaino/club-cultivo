<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><Sprout :size="20" :stroke-width="1.75" /> Informe Producción</h1>
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
        <!-- LOS MISMOS NOMBRES QUE EL PDF Y EL EXCEL. Acá decía «Gramos producidos» y «Plantas
             totales» donde el archivo dice «Cosechado en el período» y «Plantas en pie»: el mismo
             número con dos nombres, y uno de los dos mentía (no son las plantas totales, son las
             que están en pie). -->
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.total_lotes }}</span>
          <span class="inf__kpi-label">Lotes totales</span>
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
          <span class="inf__kpi-label">Cosechado en el período</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.plantas_totales }}</span>
          <span class="inf__kpi-label">Plantas en pie</span>
        </div>
      </div>

      <!-- LA FOTO DE HOY, no del período: estos lotes están en ese estado AHORA, con el
           rendimiento acumulado de cada uno. La columna leía `r.gramos`, que el backend dejó de
           mandar cuando la renombró a `rendimiento`: mostraba «—» en todas las filas mientras el
           PDF del mismo informe traía el número. -->
      <div class="inf__section">
        <h2 class="inf__section-title">Hoy en el cultivo</h2>
        <table class="inf__table">
          <thead><tr><th>Estado</th><th>Lotes</th><th>Plantas</th><th>Rendimiento acumulado</th></tr></thead>
          <tbody>
            <tr v-for="(r, i) in data.por_estado" :key="i">
              <td><span class="inf__badge" :class="`inf__badge--${r.estado}`">{{ r.estado }}</span></td>
              <td>{{ r.lotes }}</td>
              <td>{{ r.plantas }}</td>
              <td>{{ formatGramos(r.rendimiento) }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Estaba en el PDF y el Excel y no en la pantalla: la descarga mostraba más que la app. -->
      <div class="inf__section">
        <h2 class="inf__section-title">Por sede</h2>
        <table v-if="data.por_sede?.length" class="inf__table">
          <thead><tr><th>Sede</th><th>Salas</th><th>Plantas</th><th>Flor seca (g)</th></tr></thead>
          <tbody>
            <tr v-for="s in data.por_sede" :key="s.id">
              <td>{{ s.nombre }}</td>
              <td>{{ s.salas }}</td>
              <td>{{ s.plantas }}</td>
              <td>{{ formatGramos(s.stock_disponible) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__empty">La organización todavía no tiene sedes cargadas.</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Sprout } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'

const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_produccion')
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
.inf { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__head-actions { display: flex; align-items: center; gap: var(--sp-2); }
.inf__pdf { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700, #15803d); cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__periodo { background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__empty { color: var(--c-ink-400); padding: var(--sp-4); font-size: var(--fs-13); }
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
.inf__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600); }
.inf__badge--activo { background: rgba(45,138,107,.1); color: #2D8A6B; }
.inf__badge--cosechado { background: rgba(91,100,115,.1); color: #5B6473; }
</style>
