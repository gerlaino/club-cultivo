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
        <!-- Qué contesta este informe. Sin esto hay que deducirlo de los números, y
             dos informes que cortan el mismo dato distinto parecen contradecirse. -->
        <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>
        <div class="inf__kpis">
          <!-- Los KPIs van en la MISMA unidad que la tabla: la variedad del INASE. Contaban
               genéticas propias mientras la tabla agrupaba por variedad, así que un club con 24
               genéticas declaradas contra TROPICANA WFC leía "24 genéticas" arriba de UNA fila.
               Los tres primeros cierran: variedades = con N° + falta N°. -->
          <div class="inf__kpi">
            <span class="inf__kpi-valor">{{ data.total_variedades }}</span>
            <span class="inf__kpi-label">Variedades</span>
          </div>
          <div class="inf__kpi inf__kpi--ok">
            <span class="inf__kpi-valor">{{ data.con_registro }}</span>
            <span class="inf__kpi-label">Con N° registro</span>
          </div>
          <!-- Lo accionable del encabezado: la variedad acredita, pero le falta cargar el número
               del INASE — es lo que sale en blanco en la columna "N° registro". -->
          <div class="inf__kpi" :class="data.falta_registro ? 'inf__kpi--warn' : 'inf__kpi--ok'">
            <span class="inf__kpi-valor">{{ data.falta_registro }}</span>
            <span class="inf__kpi-label">Falta N° registro</span>
          </div>
          <!-- El único que va en genéticas propias, y a propósito: son las que todavía NO son una
               variedad. Tienen su propia sección abajo. -->
          <div class="inf__kpi" :class="data.sin_acreditar ? 'inf__kpi--warn' : 'inf__kpi--ok'">
            <span class="inf__kpi-valor">{{ data.sin_acreditar }}</span>
            <span class="inf__kpi-label">Genéticas sin acreditar</span>
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
          <h2 class="inf__section-title">Variedades acreditadas y su producción</h2>
          <table class="inf__table">
            <thead>
              <tr>
                <th>Variedad</th><th>N° registro INASE</th>
                <th class="inf__num">Lotes</th><th class="inf__num">Plantas</th><th class="inf__num">Gramos</th>
              </tr>
            </thead>
            <tbody>
              <!-- UNA FILA POR VARIEDAD ACREDITABLE, no por genética de la organización: si veinte
                   genéticas propias se declaran contra TROPICANA WFC, listarlas sueltas daba
                   veinte filas con el mismo nombre y parecía un error de datos.
                   Y los nombres propios NO se muestran: esto se presenta ante el INASE, y cómo la
                   organización llama a sus genéticas puertas adentro es asunto suyo. El par se
                   audita en la pantalla de Genéticas, que es donde se declara cada una. -->
              <tr v-for="g in (data.agrupadas || [])" :key="g.nombre">
                <td><strong>{{ g.nombre }}</strong></td>
                <td>
                  <span v-if="g.numero">{{ g.numero }}</span>
                  <span v-else class="inf__badge inf__badge--no">Falta cargar</span>
                </td>
                <td class="inf__num">{{ g.lotes }}</td>
                <td class="inf__num">{{ g.plantas }}</td>
                <td class="inf__num">{{ formatGramos(g.gramos) }}</td>
              </tr>
              <tr v-if="!(data.agrupadas || []).length"><td colspan="5" class="inf__empty">Ninguna variedad acreditada todavía.</td></tr>
            </tbody>
          </table>
        </div>

        <!-- Lo único accionable del informe: lo que la organización cultiva y todavía no puede
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
.inf__resena {
  margin: 0 0 var(--sp-4); padding: .7rem .9rem;
  background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-slate-600); line-height: 1.55; max-width: 80ch;
}
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
