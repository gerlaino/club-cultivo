<template>
  <div class="inf">
    <div class="inf__header">
      <h1 class="inf__title"><FileBadge :size="20" :stroke-width="1.75" /> Informe INASE — Variedades</h1>
      <div class="inf__head-actions">
        <!-- Arranca en el año: nadie declara variedades por mes. -->
        <SelectorPeriodo inicial="anio" @change="cambiarPeriodo" />
        <button class="inf__pdf" :disabled="!data || exporting" @click="exportarPdf(params)">
          <i class="bi bi-filetype-pdf"></i> {{ exporting ? 'Generando…' : 'PDF' }}
        </button>
        <!-- DOS documentos, no dos modos del mismo archivo. Presentar es un acto aparte que la app
             no hace: el PDF de arriba sale siempre para que la organización vea su realidad; éste
             valida que todo lo que aparece esté vinculado al INASE y no sale si falta algo. -->
        <button class="inf__pdf" :disabled="!data || exporting"
                title="Valida que todas las variedades del informe estén vinculadas al INASE"
                @click="exportarPdf({ ...params, para_presentar: 1 })">
          <i class="bi bi-patch-check"></i> Para presentar
        </button>
        <button class="inf__pdf" :disabled="!data || exporting" @click="exportarXlsx(params)">
          <i class="bi bi-file-earmark-spreadsheet"></i> Excel
        </button>
      </div>
    </div>

    <div v-if="loading" class="inf__loading">Cargando…</div>

    <div v-else-if="data" ref="hoja" class="inf__hoja">
      <p v-if="data.resena" class="inf__resena">{{ data.resena }}</p>

      <!-- UN AVISO, sólo si hay algo, y sólo sobre lo que SALE en este informe. No un KPI en grande
           en un documento que se presenta (decisión de Germán, sep-2026). Es la misma lista que la
           salvedad del PDF y que el candado de «Para presentar». -->
      <div v-if="data.sin_vincular?.length" class="inf__aviso">
        <strong>{{ data.sin_vincular.length === 1 ? '1 genética sale' : `${data.sin_vincular.length} genéticas salen` }}
          en este informe sin vinculación con el INASE:</strong>
        {{ data.sin_vincular.map(g => g.nombre).join(', ') }}.
        El PDF sale con la salvedad impresa; «Para presentar» no sale hasta declararlas.
        <RouterLink :to="`/geneticas?edit=${data.sin_vincular[0].id}`" class="inf__aviso-link">Declararlas →</RouterLink>
      </div>

      <div class="inf__kpis">
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.kpis.variedades }}</span>
          <span class="inf__kpi-label">Variedades</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.kpis.lotes }}</span>
          <span class="inf__kpi-label">Lotes cosechados</span>
        </div>
        <div class="inf__kpi">
          <span class="inf__kpi-valor">{{ data.kpis.plantas }}</span>
          <span class="inf__kpi-label">Plantas</span>
        </div>
        <div class="inf__kpi inf__kpi--ok">
          <span class="inf__kpi-valor">{{ formatGramos(data.kpis.gramos) }}</span>
          <span class="inf__kpi-label">Flor seca</span>
        </div>
      </div>

      <!-- ── Cosechado en el período ─────────────────────────────────────── -->
      <section class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">Cosechado en el período</h2>
          <span class="inf__section-marco">un lote pertenece al período en que se cortó · una fila por variedad del Catálogo</span>
        </div>
        <table v-if="data.variedades.length" class="inf__table">
          <thead>
            <tr>
              <th>Variedad</th><th>Obtentor</th>
              <th class="num">Lotes</th><th class="num">Plantas</th>
              <th class="num" title="De dónde vino el material de propagación de cada planta">Semilla / esqueje</th>
              <th class="num">Flor seca</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="v in data.variedades" :key="v.nombre">
              <td>
                <strong>{{ v.nombre }}</strong>
                <span v-if="!v.vinculada" class="inf__sin-vinculo">sin vinculación</span>
                <!-- Con qué nombre la cultiva la organización puertas adentro: lo que hace que el
                     informe se audite solo, sin ir a Genéticas. -->
                <div v-if="v.acredita.length" class="inf__acredita">acredita: {{ v.acredita.join(', ') }}</div>
                <div v-else-if="!v.vinculada" class="inf__acredita">
                  nombre propio · <RouterLink :to="`/geneticas?edit=${v.genetica_ids[0]}`" class="inf__aviso-link">declarar</RouterLink>
                </div>
              </td>
              <td class="inf__obtentor">{{ v.criador || '—' }}</td>
              <td class="num">{{ v.lotes }}</td>
              <td class="num">{{ v.plantas }}</td>
              <td class="num">{{ v.origen.semilla }} / {{ v.origen.esqueje }}</td>
              <td class="num">{{ formatGramos(v.gramos) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No se cosechó ningún lote en el período elegido.</p>
      </section>

      <!-- ── En cultivo hoy ──────────────────────────────────────────────── -->
      <section v-if="data.periodo.incluye_hoy" class="inf__section">
        <div class="inf__section-head">
          <h2 class="inf__section-title">En cultivo hoy</h2>
          <span class="inf__section-marco">lo que hay en pie, con su variedad</span>
        </div>
        <table v-if="data.en_cultivo.length" class="inf__table">
          <thead>
            <tr><th>Variedad</th><th class="num">Lotes</th><th class="num">Plantas en pie</th><th class="num">Semilla / esqueje</th></tr>
          </thead>
          <tbody>
            <tr v-for="v in data.en_cultivo" :key="v.nombre">
              <td>
                <strong>{{ v.nombre }}</strong>
                <span v-if="!v.vinculada" class="inf__sin-vinculo">sin vinculación</span>
                <div v-if="v.acredita.length" class="inf__acredita">acredita: {{ v.acredita.join(', ') }}</div>
              </td>
              <td class="num">{{ v.lotes }}</td>
              <td class="num">{{ v.plantas }}</td>
              <td class="num">{{ v.origen.semilla }} / {{ v.origen.esqueje }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="inf__nota">No hay lotes en cultivo hoy.</p>
      </section>

      <p class="inf__nota">
        La variedad se identifica por su nombre en el Catálogo Nacional de Cultivares — el INASE no asigna
        un número por variedad.
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { FileBadge } from 'lucide-vue-next'
import api from '../../lib/api.js'
import { useInformePdf } from '../../composables/useInformePdf.js'
import SelectorPeriodo from '../../components/informes/SelectorPeriodo.vue'

const loading = ref(false)
const data    = ref(null)
const params  = ref({ periodo: 'anio' })
const { hoja, exporting, exportarPdf, exportarXlsx } = useInformePdf('informe_inase')

const formatGramos = (g) => g != null ? `${Number(g).toLocaleString('es-AR')} g` : '—'

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/informes/inase', { params: params.value })
    data.value = res.data
  } finally {
    loading.value = false
  }
}

function cambiarPeriodo(p) { params.value = p; cargar() }

onMounted(cargar)
</script>

<style scoped>
.inf { padding: var(--sp-6); max-width: 1100px; margin: 0 auto; }
.inf__header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--sp-6); gap: var(--sp-4); flex-wrap: wrap; }
.inf__head-actions { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
.inf__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.inf__pdf { display: inline-flex; align-items: center; gap: .4rem; background: #fff; border: 1.5px solid var(--c-ink-300); border-radius: var(--r-md); padding: 6px 14px; font-size: var(--fs-14); font-weight: 600; color: var(--c-leaf-700); cursor: pointer; }
.inf__pdf:disabled { opacity: .5; cursor: not-allowed; }
.inf__loading { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; }
.inf__hoja { background: #fff; }
.inf__resena {
  margin: 0 0 var(--sp-4); padding: .7rem .9rem;
  background: var(--c-slate-50); border-left: 3px solid var(--c-slate-300); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-slate-600); line-height: 1.55; max-width: 80ch;
}
.inf__aviso {
  margin: 0 0 var(--sp-4); padding: .7rem .9rem;
  background: var(--c-amber-100); border-left: 3px solid var(--c-amber-500); border-radius: 0 8px 8px 0;
  font-size: var(--fs-13); color: var(--c-ink-800); line-height: 1.55;
}
.inf__aviso-link { color: var(--c-leaf-700); font-weight: 600; text-decoration: underline; }
.inf__kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: var(--sp-4); margin-bottom: var(--sp-6); max-width: 720px; }
.inf__kpi { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); text-align: center; }
.inf__kpi-valor { display: block; font-size: var(--fs-28); font-weight: 800; color: var(--c-ink-900); line-height: 1; font-variant-numeric: tabular-nums; }
.inf__kpi-label { display: block; font-size: var(--fs-12); color: var(--c-ink-500); margin-top: var(--sp-1); text-wrap: balance; }
.inf__kpi--ok .inf__kpi-valor { color: var(--c-leaf-600); }
.inf__section { margin-bottom: var(--sp-8); }
.inf__section-head { display: flex; align-items: baseline; gap: var(--sp-3); flex-wrap: wrap; margin-bottom: var(--sp-3); }
.inf__section-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.inf__section-marco { font-size: var(--fs-12); color: var(--c-ink-500); }
.inf__nota { color: var(--c-ink-500); font-size: var(--fs-13); margin: var(--sp-2) 0 0; }
.inf__table { width: 100%; border-collapse: collapse; font-size: var(--fs-13); }
.inf__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.inf__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); vertical-align: top; }
.inf__table .num { text-align: right; width: 1%; white-space: nowrap; font-variant-numeric: tabular-nums; }
/* La primera columna se come el sobrante: así los números quedan juntos a la derecha. */
.inf__table th:first-child, .inf__table td:first-child { width: auto; }
.inf__obtentor { color: var(--c-ink-500); }
.inf__acredita { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }
.inf__sin-vinculo { display: inline-block; margin-left: var(--sp-2); padding: 1px 7px; border-radius: 999px; background: var(--c-amber-100); color: var(--c-amber-500); font-size: var(--fs-11); font-weight: 600; text-transform: uppercase; letter-spacing: .03em; }
</style>
