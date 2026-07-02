<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><FileBadge :size="20" :stroke-width="1.75" /> Informe INASE — Variedades</h1>
      <button class="inf__pdf" :disabled="!data || exporting" @click="exportarPdf">
        <i class="bi bi-filetype-pdf"></i> {{ exporting ? 'Generando…' : 'PDF' }}
      </button>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <template v-else-if="data">
      <div ref="hoja" class="inf__hoja">
        <div class="inf__kpis">
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.total_geneticas }}</span>
            <span class="inf__kpi-label">Genéticas</span>
          </div>
          <div class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ data.registradas_inase }}</span>
            <span class="inf__kpi-label">Registradas INASE</span>
          </div>
          <div class="inf__kpi inf__kpi--warn">
            <span class="inf__kpi-valor">{{ data.sin_registrar }}</span>
            <span class="inf__kpi-label">Sin registrar</span>
          </div>
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.lotes_totales }}</span>
            <span class="inf__kpi-label">Lotes producidos</span>
          </div>
          <div class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ formatGramos(data.gramos_totales) }}</span>
            <span class="inf__kpi-label">Gramos producidos</span>
          </div>
        </div>

        <div class="inf__section">
          <h2 class="inf__section-title">Variedades del club y su producción</h2>
          <table class="inf__table">
            <thead>
              <tr>
                <th>Variedad</th><th>INASE</th><th>N° registro</th><th>Categoría</th>
                <th>Criador</th><th class="inf__num">Lotes</th><th class="inf__num">Plantas</th><th class="inf__num">Gramos</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="g in data.geneticas" :key="g.id">
                <td><strong>{{ g.nombre }}</strong><span v-if="g.tipo" class="inf__tipo"> · {{ g.tipo }}</span></td>
                <td>
                  <span class="inf__badge" :class="g.registrada_inase ? 'inf__badge--ok' : 'inf__badge--no'">
                    {{ g.registrada_inase ? '✓ Registrada' : 'Sin registro' }}
                  </span>
                </td>
                <td>{{ g.numero_registro_inase || '—' }}</td>
                <td>{{ categoriaLabel(g.categoria_inase) }}</td>
                <td>{{ g.criador || '—' }}</td>
                <td class="inf__num">{{ g.lotes }}</td>
                <td class="inf__num">{{ g.plantas }}</td>
                <td class="inf__num">{{ formatGramos(g.gramos_producidos) }}</td>
              </tr>
              <tr v-if="!data.geneticas.length"><td colspan="8" class="inf__empty">Sin genéticas cargadas.</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { FileBadge } from 'lucide-vue-next'
import api from '../../lib/api.js'

const loading   = ref(false)
const exporting = ref(false)
const data      = ref(null)
const hoja      = ref(null)

const CATEGORIAS = {
  semilla_feminizada: 'Semilla feminizada',
  semilla_regular:    'Semilla regular',
  material_vegetativo:'Material vegetativo',
  hibrido:            'Híbrido',
}
const categoriaLabel = (c) => CATEGORIAS[c] || (c || '—')
const formatGramos = (g) => g != null ? `${Number(g).toLocaleString('es-AR')} g` : '—'

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/inase')
    data.value = res.data
  } finally {
    loading.value = false
  }
}

async function exportarPdf() {
  if (!hoja.value) return
  exporting.value = true
  try {
    const html2pdf = (await import('html2pdf.js')).default
    await html2pdf().set({
      margin: 8,
      filename: `informe_inase_${new Date().toISOString().slice(0, 10)}.pdf`,
      image: { type: 'jpeg', quality: 0.95 },
      html2canvas: { scale: 2 },
      jsPDF: { unit: 'mm', format: 'a4', orientation: 'landscape' },
    }).from(hoja.value).save()
  } finally {
    exporting.value = false
  }
}

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 1100px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__pdf { background: #fff; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: #b91c1c; cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__hoja { background: #fff; }
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); }
.inf__kpi--ok .inf__kpi-valor   { color: #2D8A6B; }
.inf__kpi--warn .inf__kpi-valor { color: #b45309; }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin-bottom: var(--sp-3); }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.inf__num { text-align: right; }
.inf__tipo { color: var(--c-ink-400); font-weight: 400; }
.inf__empty { text-align: center; color: var(--c-ink-400); padding: var(--sp-6); }
.inf__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; }
.inf__badge--ok { background: rgba(45,138,107,.12); color: #2D8A6B; }
.inf__badge--no { background: rgba(180,83,9,.12);  color: #b45309; }
</style>
