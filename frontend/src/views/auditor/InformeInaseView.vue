<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><FileBadge :size="20" :stroke-width="1.75" /> Informe INASE — Variedades</h1>
      <button class="inf__pdf" :disabled="!data || exporting" @click="exportarPdf">
        <i class="bi bi-filetype-pdf"></i> {{ exporting ? 'Generando…' : 'PDF' }}
      </button>
      <button class="inf__pdf" :disabled="!data || exporting" @click="exportarXlsx">
        <i class="bi bi-file-earmark-spreadsheet"></i> Excel
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
            <span class="inf__kpi-label">Inscriptas</span>
          </div>
          <!-- Declaradas: no están inscriptas, pero el club las presenta contra una que sí
               lo está. Cuentan como acreditadas; sólo las que no tienen ninguna de las dos
               cosas son un pendiente. -->
          <div class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ data.declaradas ?? 0 }}</span>
            <span class="inf__kpi-label">Declaradas</span>
          </div>
          <div class="inf__kpi" :class="data.sin_registrar ? 'inf__kpi--warn' : 'inf__kpi--ok'">
            <span class="inf__kpi-valor">{{ data.sin_registrar }}</span>
            <span class="inf__kpi-label">Sin acreditar</span>
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
                <th>Variedad</th><th>Se cultiva como</th><th>INASE</th><th>N° registro</th><th>Categoría</th>
                <th>Criador</th><th class="inf__num">Lotes</th><th class="inf__num">Plantas</th><th class="inf__num">Gramos</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="g in data.geneticas" :key="g.id">
                <td><strong>{{ g.nombre }}</strong><span v-if="g.tipo" class="inf__tipo"> · {{ g.tipo }}</span></td>
                <!-- El nombre real del club, cuando se declaró contra otra variedad: hace
                     auditable la traducción sin salir del informe. -->
                <td>{{ g.declarada ? g.nombre_propio : '—' }}</td>
                <td>
                  <span class="inf__badge" :class="badgeInase(g)">{{ etiquetaInase(g) }}</span>
                </td>
                <td>{{ g.numero_registro_inase || '—' }}</td>
                <td>{{ categoriaLabel(g.categoria_inase) }}</td>
                <td>{{ g.criador || '—' }}</td>
                <td class="inf__num">{{ g.lotes }}</td>
                <td class="inf__num">{{ g.plantas }}</td>
                <td class="inf__num">{{ formatGramos(g.gramos_producidos) }}</td>
              </tr>
              <tr v-if="!data.geneticas.length"><td colspan="9" class="inf__empty">Sin genéticas cargadas.</td></tr>
            </tbody>
          </table>
        </div>

        <!-- Lo único accionable del informe: lo que el club cultiva y todavía no puede
             acreditar, ni por registro propio ni declarándolo. -->
        <div v-if="data.pendientes?.length" class="inf__section">
          <h2 class="inf__section-title">Sin acreditar — hay que declararlas contra una variedad inscripta</h2>
          <table class="inf__table">
            <thead>
              <tr><th>Variedad</th><th class="inf__num">Lotes</th><th class="inf__num">Plantas</th></tr>
            </thead>
            <tbody>
              <tr v-for="g in data.pendientes" :key="g.id">
                <td><strong>{{ g.nombre_propio }}</strong></td>
                <td class="inf__num">{{ g.lotes }}</td>
                <td class="inf__num">{{ g.plantas }}</td>
              </tr>
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
import { useInformePdf } from '../../composables/useInformePdf.js'

const loading   = ref(false)
const data      = ref(null)
const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_inase')

const CATEGORIAS = {
  semilla_feminizada: 'Semilla feminizada',
  semilla_regular:    'Semilla regular',
  material_vegetativo:'Material vegetativo',
  hibrido:            'Híbrido',
}
const categoriaLabel = (c) => CATEGORIAS[c] || (c || '—')

// Tres situaciones, no dos: inscripta, declarada contra una inscripta, o sin acreditar.
const etiquetaInase = (g) =>
  g.registrada_inase ? '✓ Inscripta' : g.declarada ? '✓ Declarada' : 'Sin acreditar'
const badgeInase = (g) => (g.registrada_inase || g.declarada ? 'inf__badge--ok' : 'inf__badge--no')
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

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 1100px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__pdf { background: #fff; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700, #15803d); cursor: pointer; }
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
