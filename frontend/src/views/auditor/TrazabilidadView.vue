<template>
  <div class="trz">
    <div class="trz__header">
      <div>
        <h1 class="trz__title"><i class="bi bi-diagram-3"></i> Trazabilidad legal</h1>
        <p class="trz__subtitle">Cadena completa: planta → lote → stock → dispensaciones. Para compliance REPROCANN.</p>
      </div>
      <button v-if="data" class="trz__btn-pdf" @click="exportPdf">
        <i class="bi bi-printer"></i> Imprimir / PDF
      </button>
    </div>

    <!-- Búsqueda -->
    <div class="trz__search-wrap">
      <div class="trz__search">
        <i class="bi bi-search trz__search-ico"></i>
        <input
          v-model="query"
          class="trz__input"
          placeholder="N.° lote (ej: LP-2026-001), ID numérico o código QR del stock"
          @keyup.enter="buscar"
        />
        <button class="trz__btn" :disabled="!query.trim() || loading" @click="buscar">
          <span v-if="loading" class="trz__spin"></span>
          <span v-else>Buscar</span>
        </button>
      </div>
      <div v-if="stocksList.length" class="trz__hints">
        <span class="trz__hint-label">Stocks disponibles:</span>
        <button
          v-for="s in stocksList.slice(0, 8)"
          :key="s.id"
          class="trz__hint-chip"
          @click="seleccionarStock(s)"
        >
          {{ s.numero_lote_producto || `#${s.id}` }}
          <span class="trz__hint-forma">{{ FORMA_LABELS[s.forma_producto] || s.forma_producto }}</span>
        </button>
      </div>
    </div>

    <div v-if="loading" class="trz__loading"><div class="trz__ring"></div> Cargando trazabilidad…</div>
    <div v-if="error" class="trz__error"><i class="bi bi-exclamation-triangle-fill"></i> {{ error }}</div>

    <!-- Resultado: para imprimir usamos #trz-report -->
    <div v-if="data" id="trz-report" class="trz__report">

      <!-- Encabezado del informe (visible en PDF) -->
      <div class="trz__report-header">
        <div class="trz__report-org">
          <strong>Informe de trazabilidad</strong>
          <span class="trz__report-date">Generado: {{ hoy }}</span>
        </div>
        <div class="trz__report-ref">
          Ref: {{ data.stock.numero_lote_producto || `STOCK-${data.stock.id}` }}
        </div>
      </div>

      <!-- KPIs -->
      <div class="trz__kpis">
        <div class="trz__kpi">
          <span class="trz__kpi-val">{{ data.totales.plantas_origen }}</span>
          <span class="trz__kpi-lbl">Plantas origen</span>
        </div>
        <div class="trz__kpi trz__kpi--blue">
          <span class="trz__kpi-val">{{ data.stock.cantidad_g }} g</span>
          <span class="trz__kpi-lbl">Stock generado</span>
        </div>
        <div class="trz__kpi">
          <span class="trz__kpi-val">{{ data.totales.dispensaciones_count }}</span>
          <span class="trz__kpi-lbl">Dispensaciones</span>
        </div>
        <div class="trz__kpi trz__kpi--green">
          <span class="trz__kpi-val">{{ data.totales.gramos_dispensados }} g</span>
          <span class="trz__kpi-lbl">Dispensados</span>
        </div>
      </div>

      <!-- Árbol de trazabilidad -->
      <div class="trz__tree">

        <!-- Plantas -->
        <div class="trz__node trz__node--plantas">
          <div class="trz__node-icon">🌿</div>
          <div class="trz__node-body">
            <div class="trz__node-title">Plantas origen</div>
            <div class="trz__node-sub">{{ data.totales.plantas_origen }} plantas pesadas</div>
            <div v-if="data.pesada" class="trz__node-detail">
              Pesada #{{ data.pesada.id }} · {{ formatDate(data.pesada.registrado_at) }} · {{ data.pesada.peso_total_g }} g totales
            </div>
            <div v-if="data.plantas.length" class="trz__plantas-list">
              <span v-for="p in data.plantas" :key="p.id" class="trz__planta-chip">
                {{ p.codigo_qr || `#${p.id}` }}{{ p.peso_g ? ` · ${p.peso_g}g` : '' }}
              </span>
            </div>
          </div>
        </div>

        <div class="trz__connector"><i class="bi bi-arrow-down"></i></div>

        <!-- Lote -->
        <div v-if="data.lote" class="trz__node trz__node--lote">
          <div class="trz__node-icon">📦</div>
          <div class="trz__node-body">
            <div class="trz__node-title">Lote de cultivo</div>
            <div class="trz__node-code">{{ data.lote.codigo }}</div>
            <div class="trz__node-sub">{{ data.lote.genetica?.nombre || 'Genética no registrada' }}</div>
            <div v-if="data.lote.genetica?.numero_registro_inase" class="trz__inase">
              <i class="bi bi-patch-check-fill"></i>
              INASE: {{ data.lote.genetica.numero_registro_inase }}
            </div>
            <span class="trz__estado-badge">{{ data.lote.estado }}</span>
          </div>
        </div>

        <div class="trz__connector"><i class="bi bi-arrow-down"></i></div>

        <!-- Stock -->
        <div class="trz__node trz__node--stock">
          <div class="trz__node-icon">🏷️</div>
          <div class="trz__node-body">
            <div class="trz__node-title">Stock generado</div>
            <div class="trz__node-code">{{ data.stock.numero_lote_producto || `ID ${data.stock.id}` }}</div>
            <div class="trz__node-sub">{{ FORMA_LABELS[data.stock.forma_producto] || data.stock.forma_producto }}</div>
            <div class="trz__node-detail">
              {{ data.stock.cantidad_g }} g · Elaborado: {{ formatDate(data.stock.fecha_elaboracion) }}
            </div>
            <div v-if="data.stock.codigo_qr" class="trz__qr-ref">
              QR: <code>{{ data.stock.codigo_qr }}</code>
            </div>
          </div>
        </div>

        <div class="trz__connector"><i class="bi bi-arrow-down"></i></div>

        <!-- Dispensaciones -->
        <div class="trz__node trz__node--dispens">
          <div class="trz__node-icon">💊</div>
          <div class="trz__node-body">
            <div class="trz__node-title">Dispensaciones</div>
            <div class="trz__node-sub">
              {{ data.totales.dispensaciones_count }} entregas · {{ data.totales.gramos_dispensados }} g dispensados
            </div>

            <div v-if="data.dispensaciones.length" class="trz__disp-table-wrap">
              <table class="trz__disp-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Paciente</th>
                    <th>DNI (últimos 4)</th>
                    <th>Gramos</th>
                    <th>Fecha</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(d, i) in data.dispensaciones" :key="d.id">
                    <td class="trz__td-num">{{ i + 1 }}</td>
                    <td class="trz__td-bold">{{ d.paciente_iniciales }}</td>
                    <td class="trz__td-mono">…{{ d.paciente_dni_last4 }}</td>
                    <td class="trz__td-num trz__td-g">{{ d.cantidad_g }} g</td>
                    <td class="trz__td-fecha">{{ formatDate(d.fecha) }}</td>
                  </tr>
                </tbody>
                <tfoot>
                  <tr>
                    <td colspan="3"><strong>Total dispensado</strong></td>
                    <td class="trz__td-num trz__td-g"><strong>{{ data.totales.gramos_dispensados }} g</strong></td>
                    <td></td>
                  </tr>
                </tfoot>
              </table>
            </div>
            <div v-else class="trz__no-disps">Sin dispensaciones registradas para este stock.</div>
          </div>
        </div>

      </div>

      <div class="trz__footer-legal">
        Este informe es generado automáticamente por Club Cultivo con datos del sistema a la fecha de emisión.
        La información es confidencial y de uso exclusivo para auditoría REPROCANN / ARICCAME.
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getStockTrazabilidad, listStocks } from '../../lib/api.js'

const query      = ref('')
const loading    = ref(false)
const error      = ref(null)
const data       = ref(null)
const stocksList = ref([])

const FORMA_LABELS = { flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite', tintura: 'Tintura', topico: 'Tópico', otro: 'Otro' }

const hoy = new Date().toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })

onMounted(async () => {
  try {
    const r = await listStocks()
    stocksList.value = r.data || []
  } catch { stocksList.value = [] }
})

function seleccionarStock(s) {
  query.value = s.numero_lote_producto || String(s.id)
  buscar()
}

async function buscar() {
  const q = query.value.trim()
  if (!q) return
  loading.value = true
  error.value   = null
  data.value    = null

  try {
    let id = q

    if (isNaN(Number(q))) {
      const found = stocksList.value.find(s =>
        s.numero_lote_producto === q || s.codigo_qr === q
      )
      if (!found) {
        const r = await listStocks()
        stocksList.value = r.data || []
        const f2 = stocksList.value.find(s => s.numero_lote_producto === q || s.codigo_qr === q)
        if (!f2) { error.value = `No se encontró el stock "${q}"`; return }
        id = f2.id
      } else {
        id = found.id
      }
    }

    const res = await getStockTrazabilidad(id)
    data.value = res.data
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al cargar trazabilidad'
  } finally {
    loading.value = false
  }
}

async function exportPdf() {
  const el = document.getElementById('trz-report')
  if (!el) return
  const opt = {
    margin:      [8, 8, 8, 8],
    filename:    `trazabilidad_${data.value?.stock?.numero_lote_producto || data.value?.stock?.id}_${hoy.replace(/\//g, '-')}.pdf`,
    image:       { type: 'jpeg', quality: 0.95 },
    html2canvas: { scale: 2, useCORS: true },
    jsPDF:       { unit: 'mm', format: 'a4', orientation: 'portrait' },
  }
  const { default: html2pdf } = await import('html2pdf.js')
  await html2pdf().set(opt).from(el).save()
}

const formatDate = (d) => d
  ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
  : '—'
</script>

<style scoped>
.trz { padding: var(--sp-6); max-width: 820px; }

.trz__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: var(--sp-6); flex-wrap: wrap; }
.trz__title { font-size: 1.35rem; font-weight: 800; color: var(--c-ink-900); display: flex; align-items: center; gap: .5rem; margin: 0 0 .25rem; }
.trz__subtitle { font-size: .82rem; color: var(--c-ink-500); margin: 0; }
.trz__btn-pdf { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; white-space: nowrap; transition: background .15s; }
.trz__btn-pdf:hover { background: #144a18; }

/* Search */
.trz__search-wrap { margin-bottom: 1.5rem; }
.trz__search { display: flex; gap: .5rem; position: relative; }
.trz__search-ico { position: absolute; left: .9rem; top: 50%; transform: translateY(-50%); color: var(--c-ink-400); font-size: .9rem; pointer-events: none; }
.trz__input { flex: 1; background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem 1rem .65rem 2.4rem; font-size: .875rem; color: #0f172a; outline: none; transition: border-color .15s; }
.trz__input:focus { border-color: #1b5e20; }
.trz__btn { background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: .4rem; white-space: nowrap; transition: background .15s; }
.trz__btn:hover:not(:disabled) { background: #144a18; }
.trz__btn:disabled { opacity: .5; cursor: not-allowed; }
.trz__spin { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: trz-spin .6s linear infinite; display: inline-block; }
@keyframes trz-spin { to { transform: rotate(360deg); } }

/* Hints */
.trz__hints { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; margin-top: .6rem; }
.trz__hint-label { font-size: .72rem; color: #94a3b8; font-weight: 600; }
.trz__hint-chip { display: inline-flex; align-items: center; gap: .3rem; background: #f1f5f9; border: 1px solid #e2e8f0; border-radius: 999px; padding: .15rem .65rem; font-size: .72rem; font-weight: 600; color: #475569; cursor: pointer; transition: all .12s; }
.trz__hint-chip:hover { background: #e2e8f0; color: #0f172a; }
.trz__hint-forma { font-weight: 400; color: #94a3b8; }

/* Loading / Error */
.trz__loading { display: flex; align-items: center; gap: .5rem; color: #94a3b8; font-size: .875rem; padding: 2rem; }
.trz__ring { width: 18px; height: 18px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: trz-spin .7s linear infinite; }
.trz__error { display: flex; align-items: center; gap: .5rem; color: #dc2626; font-size: .875rem; background: #fef2f2; border: 1px solid #fecaca; border-radius: 9px; padding: .75rem 1rem; margin-bottom: 1.25rem; }

/* Report */
.trz__report { }
.trz__report-header { display: flex; align-items: center; justify-content: space-between; background: #0f172a; color: #fff; border-radius: 12px; padding: .875rem 1.25rem; margin-bottom: 1.25rem; }
.trz__report-org { display: flex; flex-direction: column; gap: .15rem; }
.trz__report-org strong { font-size: .95rem; }
.trz__report-date { font-size: .72rem; color: rgba(255,255,255,.5); }
.trz__report-ref { font-family: monospace; font-size: .82rem; background: rgba(255,255,255,.1); padding: .25rem .7rem; border-radius: 6px; }

/* KPIs */
.trz__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.5rem; }
@media (max-width: 600px) { .trz__kpis { grid-template-columns: repeat(2, 1fr); } }
.trz__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: .875rem; text-align: center; }
.trz__kpi-val { display: block; font-size: 1.5rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; line-height: 1; }
.trz__kpi-lbl { display: block; font-size: .68rem; color: #94a3b8; margin-top: .3rem; font-weight: 600; text-transform: uppercase; letter-spacing: .03em; }
.trz__kpi--green .trz__kpi-val { color: #15803d; }
.trz__kpi--blue  .trz__kpi-val { color: #0369a1; }

/* Tree */
.trz__tree { display: flex; flex-direction: column; gap: 0; }
.trz__connector { text-align: center; color: #94a3b8; font-size: 1.2rem; padding: .25rem 0; }
.trz__node { display: flex; align-items: flex-start; gap: 1rem; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px; padding: 1rem 1.25rem; }
.trz__node-icon { font-size: 1.5rem; flex-shrink: 0; }
.trz__node-body { flex: 1; min-width: 0; }
.trz__node-title { font-size: .72rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; margin-bottom: .2rem; }
.trz__node-code { font-size: 1rem; font-weight: 800; color: #0f172a; font-family: monospace; margin-bottom: .15rem; }
.trz__node-sub { font-size: .875rem; color: #374151; font-weight: 500; }
.trz__node-detail { font-size: .75rem; color: #94a3b8; margin-top: .2rem; }
.trz__node--plantas { border-color: #bbf7d0; }
.trz__node--lote    { border-color: #ddd6fe; }
.trz__node--stock   { border-color: #fde68a; }
.trz__node--dispens { border-color: #bae6fd; }
.trz__inase { display: inline-flex; align-items: center; gap: .3rem; font-size: .75rem; color: #15803d; font-weight: 600; margin-top: .25rem; }
.trz__estado-badge { display: inline-block; margin-top: .35rem; padding: .15em .6em; background: #f1f5f9; color: #475569; border-radius: 999px; font-size: .68rem; font-weight: 700; text-transform: capitalize; }
.trz__qr-ref { font-size: .72rem; color: #94a3b8; margin-top: .25rem; }
.trz__qr-ref code { background: #f1f5f9; padding: .1em .4em; border-radius: 4px; font-size: .7rem; }

/* Plantas list */
.trz__plantas-list { display: flex; flex-wrap: wrap; gap: .3rem; margin-top: .5rem; }
.trz__planta-chip { background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; font-size: .68rem; padding: .1em .5em; border-radius: 5px; font-family: monospace; font-weight: 600; }

/* Dispensaciones table */
.trz__disp-table-wrap { margin-top: .75rem; overflow-x: auto; }
.trz__disp-table { width: 100%; border-collapse: collapse; font-size: .8rem; }
.trz__disp-table th { padding: .5rem .75rem; background: #f8fafc; font-weight: 700; color: #64748b; font-size: .68rem; text-transform: uppercase; letter-spacing: .04em; border-bottom: 1.5px solid #e2e8f0; text-align: left; }
.trz__disp-table td { padding: .5rem .75rem; border-bottom: 1px solid #f1f5f9; }
.trz__disp-table tfoot td { border-top: 2px solid #e2e8f0; border-bottom: none; background: #f8fafc; }
.trz__disp-table tbody tr:last-child td { border-bottom: none; }
.trz__td-num { text-align: right; }
.trz__td-bold { font-weight: 700; color: #0f172a; }
.trz__td-mono { font-family: monospace; color: #64748b; }
.trz__td-g { color: #15803d; font-weight: 700; }
.trz__td-fecha { color: #94a3b8; font-size: .75rem; }
.trz__no-disps { font-size: .82rem; color: #94a3b8; margin-top: .5rem; font-style: italic; }

/* Footer legal */
.trz__footer-legal { margin-top: 1.5rem; padding: .875rem 1.25rem; background: #fafbfc; border: 1px solid #e2e8f0; border-radius: 10px; font-size: .72rem; color: #94a3b8; line-height: 1.6; font-style: italic; text-align: center; }

/* Print styles */
@media print {
  .trz__search-wrap, .trz__btn-pdf, .trz__header > button { display: none !important; }
  .trz { padding: 0; }
  .trz__node { break-inside: avoid; }
}
</style>
