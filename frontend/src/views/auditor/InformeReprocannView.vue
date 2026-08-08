<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><FileCheck :size="20" :stroke-width="1.75" /> Informe REPROCANN</h1>
      <div class="inf__acciones">
        <select v-model="periodo" class="inf__periodo" @change="cargar">
          <option value="mes_actual">Mes actual</option>
          <option value="mes_anterior">Mes anterior</option>
          <option value="trimestre">Trimestre</option>
          <option value="anio">Año</option>
        </select>
        <button class="inf__btn" :disabled="descargando" @click="descargar('pdf')">
          <FileDown :size="15" :stroke-width="2" /> PDF
        </button>
        <button class="inf__btn" :disabled="descargando" @click="descargar('xlsx')">
          <Sheet :size="15" :stroke-width="2" /> Excel
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <div v-else-if="data">
      <div class="inf__kpis">
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.total_pacientes }}</span>
          <span class="inf__kpi-label">Total pacientes</span>
        </div>
        <div class="inf__kpi inf__kpi--ok">
          <span class="inf__kpi-valor">{{ data.con_reprocann_vigente }}</span>
          <span class="inf__kpi-label">Con REPROCANN vigente</span>
        </div>
        <div class="inf__kpi inf__kpi--warn">
          <span class="inf__kpi-valor">{{ data.vencen_30d }}</span>
          <span class="inf__kpi-label">Vencen en 30 días</span>
        </div>
        <div class="inf__kpi inf__kpi--err">
          <span class="inf__kpi-valor">{{ data.vencidos }}</span>
          <span class="inf__kpi-label">Vencidos</span>
        </div>
        <div v-if="data.pendientes" class="inf__kpi inf__kpi--warn">
          <span class="inf__kpi-valor">{{ data.pendientes }}</span>
          <span class="inf__kpi-label">Trámite pendiente</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.sin_reprocann }}</span>
          <span class="inf__kpi-label">Sin REPROCANN</span>
        </div>
      </div>

      <!-- Qué se entregó y a quién. Nada de cultivo: eso está en el informe de Producción. -->
      <div v-if="data.dispensaciones" class="inf__section">
        <h2 class="inf__section-title">Dispensaciones a esta población</h2>
        <div class="inf__kpis">
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.dispensaciones.total }}</span>
            <span class="inf__kpi-label">Entregas</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.dispensaciones.gramos }} g</span>
            <span class="inf__kpi-label">Total dispensado</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.dispensaciones.pacientes_atendidos }}</span>
            <span class="inf__kpi-label">Pacientes atendidos</span>
          </div>
          <div class="inf__kpi" :class="data.dispensaciones.sin_reprocann_vigente ? 'inf__kpi--err' : ''">
            <span class="inf__kpi-valor">{{ data.dispensaciones.sin_reprocann_vigente }}</span>
            <span class="inf__kpi-label">Sin REPROCANN vigente</span>
          </div>
        </div>
      </div>

      <!-- El paciente no tiene sede propia: se atiende donde dispensa. -->
      <div v-if="data.por_sede?.length" class="inf__section">
        <h2 class="inf__section-title">Por sede de atención</h2>
        <table class="inf__table">
          <thead>
            <tr>
              <th>Sede</th><th>Pacientes</th><th>Vigentes</th><th>Vencen ≤30d</th>
              <th>Vencidos</th><th>En trámite</th><th>Sin REPROCANN</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in data.por_sede" :key="r.sede">
              <td>{{ r.sede }}</td>
              <td>{{ r.total }}</td>
              <td>{{ r.vigentes }}</td>
              <td>{{ r.por_vencer }}</td>
              <td>{{ r.vencidos }}</td>
              <td>{{ r.pendientes }}</td>
              <td>{{ r.sin_reprocann }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="inf__section">
        <h2 class="inf__section-title">Nómina de pacientes (vigentes y por vencer)</h2>
        <table class="inf__table">
          <thead><tr><th>Paciente</th><th>DNI (últ. 3)</th><th>Estado REPROCANN</th><th>Vencimiento</th></tr></thead>
          <tbody>
            <tr v-for="(p, i) in listaFiltrada" :key="i">
              <td>{{ p.nombre_completo || p.iniciales }}</td>
              <td>***{{ p.dni_ultimos_3 }}</td>
              <td><span class="inf__badge" :class="`inf__badge--${p.reprocann_estado}`">{{ estadoLabel(p.reprocann_estado) }}</span></td>
              <td>{{ p.reprocann_vencimiento ? formatDate(p.reprocann_vencimiento) : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { FileCheck, FileDown, Sheet } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const toast = useToast()
const periodo = ref('mes_actual')
const loading = ref(false)
const data    = ref(null)
const descargando = ref(false)

async function descargar(formato) {
  descargando.value = true
  try {
    const res = await api.get(`/informes/reprocann.${formato}`, { responseType: 'blob' })
    const url = window.URL.createObjectURL(new Blob([res.data]))
    const a = document.createElement('a')
    a.href = url
    a.download = `informe_reprocann_${new Date().toISOString().slice(0, 10)}.${formato}`
    document.body.appendChild(a); a.click(); a.remove()
    window.URL.revokeObjectURL(url)
  } catch {
    toast.error('No se pudo descargar el informe')
  } finally {
    descargando.value = false
  }
}

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/reprocann', { params: { periodo: periodo.value } })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

const ESTADOS_VISIBLES = new Set(['vigente', 'vigente_sin_vencimiento', 'por_vencer'])
const listaFiltrada = computed(() => data.value?.lista_anonimizada?.filter(p => ESTADOS_VISIBLES.has(p.reprocann_estado)) ?? [])
const ESTADO_LABELS = { vigente: 'Vigente', vencido: 'Vencido', por_vencer: 'Por vencer', sin_reprocann: 'Sin REPROCANN', vigente_sin_vencimiento: 'Vigente s/venc.' }
const estadoLabel = (e) => ESTADO_LABELS[e] || e
const formatDate = (d) => d ? new Date(d).toLocaleDateString('es-AR') : '—'

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 900px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__acciones { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.inf__btn { display: inline-flex; align-items: center; gap: 5px; background: #15803d; color: #fff; border: none; border-radius: var(--r-md); padding: 7px 12px; font-size: var(--fs-13); font-weight: 600; cursor: pointer; transition: background .15s; }
.inf__btn:hover:not(:disabled) { background: #166534; }
.inf__btn:disabled { opacity: .55; cursor: wait; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__periodo { background: var(--c-ink-50); border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 12px; font-size: var(--fs-14); color: var(--c-ink-900); }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
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
.inf__badge--vigente { background: rgba(45,138,107,.1); color: #2D8A6B; }
.inf__badge--vencido { background: rgba(180,40,40,.1); color: var(--c-rust-600); }
.inf__badge--por_vencer { background: rgba(184,92,0,.1); color: #B85C00; }
</style>
