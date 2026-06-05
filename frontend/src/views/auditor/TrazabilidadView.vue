<template>
  <div class="trz">

    <!-- Header + búsqueda -->
    <div class="trz__top">
      <div class="trz__top-left">
        <h1 class="trz__title"><i class="bi bi-diagram-3-fill"></i> Trazabilidad legal</h1>
        <p class="trz__sub">Cadena completa: origen → cultivo → stock → dispensaciones · Compliance REPROCANN</p>
      </div>
      <div class="trz__top-right">
        <div class="trz__search-wrap">
          <i class="bi bi-search trz__search-ico"></i>
          <input
            ref="inputRef"
            v-model="query"
            class="trz__search-input"
            placeholder="N.° lote, ID o código QR…"
            autocomplete="off"
            @input="onInput"
            @keyup.enter="buscarDesdeInput"
            @keydown.esc="cerrarAuto"
            @focus="autoVisible = true"
            @blur="onBlur"
          />
          <button class="trz__search-btn" :disabled="!query.trim() || loading" @click="buscarDesdeInput">
            <DsSpinner v-if="loading" :size="14" />
            <i v-else class="bi bi-arrow-right"></i>
          </button>

          <!-- Autocomplete -->
          <div v-if="autoVisible && sugerencias.length" class="trz__autocomplete">
            <button
              v-for="s in sugerencias"
              :key="s.id"
              class="trz__auto-item"
              @mousedown.prevent="seleccionarStock(s)"
            >
              <span class="trz__auto-num">{{ s.numero_lote_producto || `#${s.id}` }}</span>
              <span class="trz__auto-meta">
                {{ FORMA_LABELS[s.forma_producto] || s.forma_producto }}
                <span v-if="s.cantidad_g" class="trz__auto-g">· {{ s.cantidad_g }} g</span>
              </span>
            </button>
          </div>
        </div>

        <button v-if="data" class="trz__btn-pdf" @click="exportPdf">
          <i class="bi bi-printer"></i> PDF
        </button>
        <button v-if="data" class="trz__btn-back" @click="volver">
          <i class="bi bi-arrow-left"></i> Volver
        </button>
      </div>
    </div>

    <!-- Error -->
    <div v-if="error" class="trz__alert">
      <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
    </div>

    <!-- Loading cadena -->
    <div v-if="loading" class="trz__loader">
      <DsSpinner />
      Cargando cadena de trazabilidad…
    </div>

    <!-- ESTADO: listado de stocks (default) -->
    <template v-else-if="!data">
      <div v-if="loadingList" class="trz__loader">
        <DsSpinner /> Cargando stocks…
      </div>
      <div v-else-if="!stocksList.length" class="trz__empty-plain">
        <i class="bi bi-inbox"></i> Sin stocks registrados aún.
      </div>
      <div v-else class="trz__stocks-section">
        <div class="trz__stocks-header">
          <span class="trz__stocks-count">{{ stocksList.length }} stocks registrados</span>
          <span class="trz__stocks-hint"><i class="bi bi-hand-index"></i> Hacé click en un stock para ver su cadena</span>
        </div>
        <div class="trz__table-wrap">
          <table class="trz__table">
            <thead>
              <tr>
                <th>N.° lote producto</th>
                <th>Forma</th>
                <th>Cantidad</th>
                <th>Elaborado</th>
                <th>Código QR</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="s in stocksList"
                :key="s.id"
                class="trz__tr"
                @click="seleccionarStock(s)"
              >
                <td class="trz__td-code">{{ s.numero_lote_producto || `#${s.id}` }}</td>
                <td>
                  <span class="trz__forma-badge">{{ FORMA_LABELS[s.forma_producto] || s.forma_producto }}</span>
                </td>
                <td class="trz__td-g">{{ s.cantidad_g ?? '—' }} g</td>
                <td class="trz__td-fecha">{{ formatDate(s.fecha_elaboracion) }}</td>
                <td class="trz__td-qr">{{ s.codigo_qr || '—' }}</td>
                <td class="trz__td-action">
                  <span class="trz__td-ver">Ver cadena <i class="bi bi-arrow-right"></i></span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- ESTADO: cadena de custodia -->
    <div v-if="data" id="trz-report" class="trz__report">

      <!-- Banner -->
      <div class="trz__banner">
        <div>
          <div class="trz__banner-label">Informe de trazabilidad</div>
          <div class="trz__banner-ref">{{ data.stock.numero_lote_producto || `STOCK-${data.stock.id}` }}</div>
        </div>
        <div class="trz__banner-date"><i class="bi bi-calendar3"></i> {{ hoy }}</div>
      </div>

      <!-- KPIs -->
      <div class="trz__kpis">
        <div class="trz__kpi trz__kpi--green">
          <span class="trz__kpi-ico">🌿</span>
          <span class="trz__kpi-val">{{ data.totales.plantas_origen }}</span>
          <span class="trz__kpi-lbl">Plantas cultivadas</span>
        </div>
        <div class="trz__kpi trz__kpi--amber">
          <span class="trz__kpi-ico">🏷️</span>
          <span class="trz__kpi-val">{{ data.stock.cantidad_g }} g</span>
          <span class="trz__kpi-lbl">Stock generado</span>
        </div>
        <div class="trz__kpi trz__kpi--blue">
          <span class="trz__kpi-ico">📋</span>
          <span class="trz__kpi-val">{{ data.totales.dispensaciones_count }}</span>
          <span class="trz__kpi-lbl">Dispensaciones</span>
        </div>
        <div class="trz__kpi trz__kpi--purple">
          <span class="trz__kpi-ico">⚖️</span>
          <span class="trz__kpi-val">{{ data.totales.gramos_dispensados }} g</span>
          <span class="trz__kpi-lbl">Gramos dispensados</span>
        </div>
      </div>

      <!-- Cadena -->
      <div class="trz__chain-divider">
        <span><i class="bi bi-link-45deg"></i> CADENA DE CUSTODIA</span>
      </div>

      <div class="trz__chain">

        <!-- Nodo 1: ORIGEN -->
        <div class="trz__node trz__node--origen">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--origen">🌱 ORIGEN GENÉTICO</span>
            <span class="trz__node-code">{{ origenLabel }}</span>
          </div>
          <div class="trz__node-body">
            <div class="trz__fields">
              <div class="trz__field">
                <span class="trz__field-lbl">Genética</span>
                <span class="trz__field-val">{{ data.lote?.genetica?.nombre || 'No registrada' }}</span>
              </div>
              <div class="trz__field" v-if="data.lote?.genetica?.tipo">
                <span class="trz__field-lbl">Tipo</span>
                <span class="trz__field-val">{{ data.lote.genetica.tipo }}</span>
              </div>
              <div class="trz__field" v-if="data.lote?.genetica?.numero_registro_inase">
                <span class="trz__field-lbl">Reg. INASE</span>
                <span class="trz__field-val trz__field-inase">
                  <i class="bi bi-patch-check-fill"></i>
                  {{ data.lote.genetica.numero_registro_inase }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div class="trz__arrow"><i class="bi bi-arrow-down"></i></div>

        <!-- Nodo 2: CULTIVO (lote + plantas) -->
        <div class="trz__node trz__node--lote">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--lote">📦 CULTIVO / LOTE</span>
            <span v-if="data.lote" class="trz__node-code">{{ data.lote.codigo }}</span>
          </div>
          <div class="trz__node-body">
            <div class="trz__fields">
              <div class="trz__field">
                <span class="trz__field-lbl">Estado</span>
                <span class="trz__estado-pill">{{ data.lote?.estado }}</span>
              </div>
              <div v-if="data.pesada" class="trz__field">
                <span class="trz__field-lbl">Pesada</span>
                <span class="trz__field-val">{{ data.pesada.peso_total_g }} g · {{ formatDate(data.pesada.registrado_at) }}</span>
              </div>
            </div>

            <!-- Timeline de ciclo -->
            <div v-if="timeline.length" class="trz__timeline">
              <div
                v-for="(ev, idx) in timeline"
                :key="idx"
                class="trz__tl-item"
                :class="{ 'trz__tl-item--pesada': ev.type === 'pesada' }"
              >
                <div class="trz__tl-dot">{{ ev.icon }}</div>
                <div class="trz__tl-text">
                  <span class="trz__tl-title">{{ ev.titulo }}</span>
                  <span v-if="ev.detalle" class="trz__tl-detail">{{ ev.detalle }}</span>
                  <span class="trz__tl-date">{{ formatDate(ev.fecha) }}</span>
                </div>
              </div>
            </div>

            <!-- Plantas individuales -->
            <div v-if="data.plantas?.length" class="trz__plantas">
              <span class="trz__plantas-lbl">{{ data.plantas.length }} plantas</span>
              <div class="trz__plantas-chips">
                <span v-for="p in data.plantas" :key="p.id" class="trz__planta-chip">
                  {{ p.codigo_qr || `#${p.id}` }}{{ p.peso_g ? ` · ${p.peso_g}g` : '' }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <div class="trz__arrow"><i class="bi bi-arrow-down"></i></div>

        <!-- Nodo 3: STOCK -->
        <div class="trz__node trz__node--stock">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--stock">🏷️ STOCK GENERADO</span>
            <span class="trz__node-code">{{ data.stock.numero_lote_producto || `ID ${data.stock.id}` }}</span>
          </div>
          <div class="trz__node-body">
            <div class="trz__fields">
              <div class="trz__field">
                <span class="trz__field-lbl">Forma</span>
                <span class="trz__field-val">{{ FORMA_LABELS[data.stock.forma_producto] || data.stock.forma_producto }}</span>
              </div>
              <div class="trz__field">
                <span class="trz__field-lbl">Cantidad</span>
                <span class="trz__field-val trz__field-g">{{ data.stock.cantidad_g }} g</span>
              </div>
              <div class="trz__field">
                <span class="trz__field-lbl">Elaborado</span>
                <span class="trz__field-val">{{ formatDate(data.stock.fecha_elaboracion) }}</span>
              </div>
            </div>
            <div v-if="data.stock.codigo_qr" class="trz__qr-row">
              <i class="bi bi-qr-code"></i>
              <code>{{ data.stock.codigo_qr }}</code>
            </div>
          </div>
        </div>

        <div class="trz__arrow"><i class="bi bi-arrow-down"></i></div>

        <!-- Nodo 4: DISPENSACIONES -->
        <div class="trz__node trz__node--dispens">
          <div class="trz__node-head">
            <span class="trz__node-badge trz__node-badge--dispens">💊 DISPENSACIONES</span>
            <span class="trz__node-sub">
              {{ data.totales.dispensaciones_count }} entregas · {{ data.totales.gramos_dispensados }} g dispensados
            </span>
          </div>
          <div class="trz__node-body">
            <div v-if="data.dispensaciones.length" class="trz__disp-wrap">
              <table class="trz__disp-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Socio</th>
                    <th>DNI (últimos 4)</th>
                    <th>Gramos</th>
                    <th>Fecha</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(d, i) in data.dispensaciones" :key="d.id">
                    <td class="trz__td-n">{{ i + 1 }}</td>
                    <td class="trz__td-bold">{{ d.paciente_iniciales }}</td>
                    <td class="trz__td-mono">…{{ d.paciente_dni_last4 }}</td>
                    <td class="trz__td-g">{{ d.cantidad_g }} g</td>
                    <td class="trz__td-fecha">{{ formatDate(d.fecha) }}</td>
                  </tr>
                </tbody>
                <tfoot>
                  <tr>
                    <td colspan="3"><strong>Total</strong></td>
                    <td class="trz__td-g"><strong>{{ data.totales.gramos_dispensados }} g</strong></td>
                    <td></td>
                  </tr>
                </tfoot>
              </table>
            </div>
            <div v-else class="trz__no-disp">
              <i class="bi bi-inbox"></i> Sin dispensaciones registradas para este stock.
            </div>
          </div>
        </div>

      </div>

      <div class="trz__footer-legal">
        Informe generado por Cultivo Espacial · {{ hoy }} · Uso exclusivo para auditoría REPROCANN / ARICCAME
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { getStockTrazabilidad, listStocks } from '../../lib/api.js'

const FORMA_LABELS = {
  flor_seca: 'Flor seca', hash: 'Hash', aceite: 'Aceite',
  tintura: 'Tintura', topico: 'Tópico', otro: 'Otro',
}
const FASE_ICONS = {
  germinacion: '🌱', vegetativo: '🌿', floracion: '🌸',
  cosecha: '✂️', secado: '💨', curado: '🫙', finalizado: '✅',
}

const query       = ref('')
const loading     = ref(false)
const loadingList = ref(true)
const error       = ref(null)
const data        = ref(null)
const stocksList  = ref([])
const autoVisible = ref(false)

const hoy = new Date().toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })

const sugerencias = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q || q.length < 2) return []
  return stocksList.value
    .filter(s =>
      (s.numero_lote_producto || '').toLowerCase().includes(q) ||
      String(s.id).includes(q) ||
      (s.codigo_qr || '').toLowerCase().includes(q)
    )
    .slice(0, 8)
})

const origenLabel = computed(() => {
  if (!data.value?.plantas?.length) return 'No especificado'
  const origenes = [...new Set(data.value.plantas.map(p => p.origen).filter(Boolean))]
  if (!origenes.length) return 'No especificado'
  return origenes.map(o => o === 'semilla' ? 'Semilla' : o === 'esqueje' ? 'Esqueje' : o).join(' / ')
})

const timeline = computed(() => {
  if (!data.value) return []
  const items = []
  if (Array.isArray(data.value.lote_eventos)) {
    data.value.lote_eventos.forEach(ev => {
      items.push({
        type: 'evento',
        fecha: ev.registrado_en || ev.created_at,
        icon: FASE_ICONS[ev.tipo] || '📋',
        titulo: ev.descripcion || ev.tipo || 'Evento',
        detalle: null,
      })
    })
  }
  if (data.value.pesada) {
    items.push({
      type: 'pesada',
      fecha: data.value.pesada.registrado_at || data.value.pesada.created_at,
      icon: '⚖️',
      titulo: `Pesada · ${data.value.pesada.peso_total_g} g`,
      detalle: data.value.plantas?.length ? `${data.value.plantas.length} plantas` : null,
    })
  }
  return items.sort((a, b) => new Date(a.fecha) - new Date(b.fecha))
})

onMounted(async () => {
  try {
    const r = await listStocks()
    stocksList.value = r.data || []
  } catch { stocksList.value = [] }
  finally { loadingList.value = false }
})

function onInput() { autoVisible.value = true; error.value = null }
function onBlur() { setTimeout(() => { autoVisible.value = false }, 150) }
function cerrarAuto() { autoVisible.value = false }

async function seleccionarStock(s) {
  query.value = s.numero_lote_producto || String(s.id)
  autoVisible.value = false
  await buscar(s.id)
}

async function buscarDesdeInput() {
  const q = query.value.trim()
  if (!q) return
  autoVisible.value = false
  if (!isNaN(Number(q))) { await buscar(Number(q)); return }

  let found = stocksList.value.find(s => s.numero_lote_producto === q || s.codigo_qr === q)
  if (!found) {
    try {
      const r = await listStocks()
      stocksList.value = r.data || []
      found = stocksList.value.find(s => s.numero_lote_producto === q || s.codigo_qr === q)
    } catch { /* noop */ }
  }
  if (!found) { error.value = `No se encontró "${q}"`; return }
  await buscar(found.id)
}

async function buscar(id) {
  loading.value = true
  error.value   = null
  data.value    = null
  try {
    const res = await getStockTrazabilidad(id)
    data.value = res.data
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al cargar trazabilidad'
  } finally {
    loading.value = false
  }
}

function volver() {
  data.value  = null
  query.value = ''
  error.value = null
}

async function exportPdf() {
  const el = document.getElementById('trz-report')
  if (!el) return
  const ref = data.value?.stock?.numero_lote_producto || data.value?.stock?.id || 'stock'
  const opt = {
    margin: [8, 8, 8, 8],
    filename: `trazabilidad_${ref}_${hoy.replace(/\//g, '-')}.pdf`,
    image: { type: 'jpeg', quality: 0.95 },
    html2canvas: { scale: 2, useCORS: true },
    jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' },
  }
  const { default: html2pdf } = await import('html2pdf.js')
  await html2pdf().set(opt).from(el).save()
}

const formatDate = d => d
  ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
  : '—'
</script>

<style scoped>
.trz { padding: var(--sp-6, 1.5rem); }

/* Top bar */
.trz__top {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem;
}
.trz__top-left {}
.trz__title {
  font-size: 1.35rem; font-weight: 800; color: var(--c-ink-900, #0f172a);
  margin: 0 0 .25rem; display: flex; align-items: center; gap: .5rem;
}
.trz__sub { font-size: .82rem; color: var(--c-ink-500, #64748b); margin: 0; }

.trz__top-right { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }

/* Search */
.trz__search-wrap { position: relative; display: flex; align-items: center; }
.trz__search-ico {
  position: absolute; left: .8rem; color: #94a3b8; font-size: .85rem; pointer-events: none; z-index: 1;
}
.trz__search-input {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .6rem 3rem .6rem 2.2rem; font-size: .875rem; color: #0f172a;
  width: 280px; outline: none; transition: border-color .15s; font-family: inherit;
}
.trz__search-input:focus { border-color: #1b5e20; }
.trz__search-btn {
  position: absolute; right: .35rem; background: #1b5e20; color: #fff;
  border: none; border-radius: 6px; padding: .3rem .6rem;
  cursor: pointer; display: flex; align-items: center; transition: background .15s;
}
.trz__search-btn:hover:not(:disabled) { background: #144a18; }
.trz__search-btn:disabled { opacity: .4; cursor: not-allowed; }

.trz__autocomplete {
  position: absolute; top: calc(100% + 2px); left: 0; right: 0;
  background: #fff; border: 1.5px solid #1b5e20; border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0,0,0,.1); z-index: 50; overflow: hidden;
}
.trz__auto-item {
  display: flex; align-items: center; justify-content: space-between;
  width: 100%; background: none; border: none; padding: .55rem .9rem;
  cursor: pointer; text-align: left; transition: background .1s;
  border-bottom: 1px solid #f1f5f9;
}
.trz__auto-item:last-child { border-bottom: none; }
.trz__auto-item:hover { background: #f0fdf4; }
.trz__auto-num { font-size: .82rem; font-weight: 700; color: #0f172a; font-family: monospace; }
.trz__auto-meta { font-size: .72rem; color: #94a3b8; }
.trz__auto-g { color: #d97706; }

.trz__btn-pdf, .trz__btn-back {
  display: inline-flex; align-items: center; gap: .4rem;
  border: none; padding: .55rem .9rem; border-radius: 8px;
  font-size: .82rem; font-weight: 600; cursor: pointer; white-space: nowrap; transition: all .15s;
}
.trz__btn-pdf  { background: #1b5e20; color: #fff; }
.trz__btn-pdf:hover  { background: #144a18; }
.trz__btn-back { background: #f1f5f9; color: #475569; }
.trz__btn-back:hover { background: #e2e8f0; }

/* Alert */
.trz__alert {
  display: flex; align-items: center; gap: .5rem; color: #dc2626;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 9px;
  padding: .7rem 1rem; margin-bottom: 1.25rem; font-size: .875rem;
}

/* Loader */
.trz__loader {
  display: flex; align-items: center; justify-content: center; padding: 2rem;
}

/* Empty plain */
.trz__empty-plain {
  padding: 3rem 0; color: #94a3b8; font-size: .9rem;
  display: flex; align-items: center; gap: .5rem;
}

/* Stocks list */
.trz__stocks-section {}
.trz__stocks-header {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: .75rem; flex-wrap: wrap; gap: .5rem;
}
.trz__stocks-count { font-size: .82rem; font-weight: 600; color: #64748b; }
.trz__stocks-hint { font-size: .78rem; color: #94a3b8; display: flex; align-items: center; gap: .3rem; }

.trz__table-wrap {
  border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; overflow-x: auto;
}
.trz__table { width: 100%; border-collapse: collapse; font-size: .875rem; background: #fff; }
.trz__table thead th {
  text-align: left; font-size: .65rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: .05em; color: #94a3b8;
  background: #f8fafc; padding: .6rem .875rem;
  border-bottom: 1px solid #e2e8f0; white-space: nowrap;
}
.trz__tr { cursor: pointer; transition: background .1s; }
.trz__tr:not(:last-child) td { border-bottom: 1px solid #f1f5f9; }
.trz__tr:hover { background: #f0fdf4; }
.trz__tr td { padding: .65rem .875rem; color: #0f172a; }
.trz__td-code { font-family: monospace; font-weight: 700; color: #0f172a; }
.trz__td-g { color: #d97706; font-weight: 600; }
.trz__td-fecha { color: #94a3b8; font-size: .78rem; white-space: nowrap; }
.trz__td-qr { font-family: monospace; font-size: .75rem; color: #94a3b8; }
.trz__td-action { text-align: right; }
.trz__td-ver {
  font-size: .75rem; font-weight: 600; color: #1b5e20;
  display: inline-flex; align-items: center; gap: .3rem; opacity: 0; transition: opacity .15s;
}
.trz__tr:hover .trz__td-ver { opacity: 1; }
.trz__forma-badge {
  display: inline-block; background: #f1f5f9; color: #475569;
  font-size: .72rem; font-weight: 600; padding: .15em .6em; border-radius: 999px;
}

/* Report */
.trz__banner {
  display: flex; align-items: center; justify-content: space-between;
  background: #0f172a; color: #fff; border-radius: 12px;
  padding: .875rem 1.25rem; margin-bottom: 1.25rem; flex-wrap: wrap; gap: .5rem;
}
.trz__banner-label { font-size: .65rem; color: rgba(255,255,255,.45); font-weight: 600; text-transform: uppercase; letter-spacing: .06em; }
.trz__banner-ref { font-family: monospace; font-size: 1rem; font-weight: 700; }
.trz__banner-date { font-size: .78rem; color: rgba(255,255,255,.5); display: flex; align-items: center; gap: .35rem; }

/* KPIs */
.trz__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.5rem; }
@media (max-width: 600px) { .trz__kpis { grid-template-columns: repeat(2, 1fr); } }
.trz__kpi {
  background: #fff; border: 1.5px solid #e2e8f0; border-radius: 12px;
  padding: 1rem .875rem; display: flex; flex-direction: column; align-items: center;
  text-align: center; gap: .15rem;
}
.trz__kpi-ico { font-size: 1.2rem; }
.trz__kpi-val { font-size: 1.35rem; font-weight: 800; letter-spacing: -.04em; color: #0f172a; line-height: 1.1; }
.trz__kpi-lbl { font-size: .65rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: #94a3b8; }
.trz__kpi--green  { border-color: #bbf7d0; } .trz__kpi--green  .trz__kpi-val { color: #15803d; }
.trz__kpi--amber  { border-color: #fde68a; } .trz__kpi--amber  .trz__kpi-val { color: #d97706; }
.trz__kpi--blue   { border-color: #bae6fd; } .trz__kpi--blue   .trz__kpi-val { color: #0369a1; }
.trz__kpi--purple { border-color: #e9d5ff; } .trz__kpi--purple .trz__kpi-val { color: #7c3aed; }

/* Chain divider */
.trz__chain-divider {
  display: flex; align-items: center; gap: .75rem;
  font-size: .65rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .07em; margin-bottom: 1rem;
}
.trz__chain-divider::before, .trz__chain-divider::after {
  content: ''; flex: 1; height: 1px; background: #e2e8f0;
}

/* Chain layout: 2-col on wide screens */
.trz__chain { display: flex; flex-direction: column; }

.trz__node {
  background: #fff; border: 2px solid #e2e8f0; border-radius: 14px; overflow: hidden;
}
.trz__node--origen { border-color: #d1fae5; }
.trz__node--lote   { border-color: #bbf7d0; }
.trz__node--stock  { border-color: #fde68a; }
.trz__node--dispens { border-color: #bae6fd; }

.trz__node-head {
  display: flex; align-items: center; gap: .75rem; flex-wrap: wrap;
  padding: .65rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc;
}
.trz__node-badge {
  font-size: .65rem; font-weight: 700; letter-spacing: .05em;
  padding: .2em .65em; border-radius: 999px;
}
.trz__node-badge--origen { background: #d1fae5; color: #065f46; }
.trz__node-badge--lote   { background: #dcfce7; color: #14532d; }
.trz__node-badge--stock  { background: #fef3c7; color: #78350f; }
.trz__node-badge--dispens { background: #dbeafe; color: #1e3a5f; }
.trz__node-code { font-family: monospace; font-size: .9rem; font-weight: 700; color: #0f172a; }
.trz__node-sub  { font-size: .8rem; color: #64748b; }

.trz__node-body { padding: 1rem 1.25rem; display: flex; flex-direction: column; gap: .875rem; }

.trz__fields { display: flex; flex-wrap: wrap; gap: 1rem; }
.trz__field  { display: flex; flex-direction: column; gap: .15rem; min-width: 120px; }
.trz__field-lbl { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; }
.trz__field-val { font-size: .875rem; color: #0f172a; font-weight: 500; }
.trz__field-inase { display: inline-flex; align-items: center; gap: .3rem; color: #15803d; }
.trz__field-g { color: #d97706; font-weight: 700; }
.trz__estado-pill {
  display: inline-block; background: #f1f5f9; color: #475569;
  font-size: .72rem; font-weight: 700; text-transform: capitalize;
  padding: .2em .65em; border-radius: 999px; align-self: flex-start;
}
.trz__qr-row { display: inline-flex; align-items: center; gap: .45rem; font-size: .75rem; color: #94a3b8; }
.trz__qr-row code { background: #f1f5f9; padding: .1em .4em; border-radius: 4px; font-size: .72rem; }

/* Timeline */
.trz__timeline {
  border-left: 2px solid #e2e8f0; padding-left: 1.1rem;
  display: flex; flex-direction: column; gap: .5rem;
}
.trz__tl-item { display: flex; align-items: flex-start; gap: .6rem; }
.trz__tl-dot {
  width: 24px; height: 24px; border-radius: 50%; background: #f1f5f9;
  display: flex; align-items: center; justify-content: center; font-size: .8rem;
  flex-shrink: 0; margin-left: -1.72rem; border: 2px solid #fff;
}
.trz__tl-item--pesada .trz__tl-dot { background: #fef3c7; }
.trz__tl-text { display: flex; flex-direction: column; gap: .05rem; padding-top: .1rem; }
.trz__tl-title { font-size: .82rem; font-weight: 600; color: #0f172a; }
.trz__tl-detail { font-size: .72rem; color: #64748b; }
.trz__tl-date { font-size: .68rem; color: #94a3b8; }

/* Plantas chips */
.trz__plantas { display: flex; flex-direction: column; gap: .35rem; }
.trz__plantas-lbl { font-size: .68rem; font-weight: 600; color: #64748b; }
.trz__plantas-chips { display: flex; flex-wrap: wrap; gap: .25rem; }
.trz__planta-chip {
  background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d;
  font-size: .68rem; padding: .1em .5em; border-radius: 5px; font-family: monospace; font-weight: 600;
}

/* Arrow */
.trz__arrow { text-align: center; color: #94a3b8; font-size: 1.25rem; padding: .3rem 0; line-height: 1; }

/* Dispensaciones table */
.trz__disp-wrap { overflow-x: auto; }
.trz__disp-table { width: 100%; border-collapse: collapse; font-size: .8rem; }
.trz__disp-table th {
  padding: .45rem .75rem; background: #f8fafc; font-weight: 700; color: #64748b;
  font-size: .65rem; text-transform: uppercase; letter-spacing: .05em;
  border-bottom: 1.5px solid #e2e8f0; text-align: left;
}
.trz__disp-table td { padding: .45rem .75rem; border-bottom: 1px solid #f1f5f9; }
.trz__disp-table tfoot td { border-top: 2px solid #e2e8f0; border-bottom: none; background: #f8fafc; }
.trz__disp-table tbody tr:last-child td { border-bottom: none; }
.trz__td-n { text-align: right; color: #94a3b8; }
.trz__td-bold { font-weight: 700; color: #0f172a; }
.trz__td-mono { font-family: monospace; color: #64748b; }
.trz__td-g { text-align: right; color: #15803d; font-weight: 700; }
.trz__td-fecha { color: #94a3b8; font-size: .72rem; }
.trz__no-disp {
  font-size: .875rem; color: #94a3b8; font-style: italic;
  display: flex; align-items: center; gap: .4rem; padding: .25rem 0;
}

/* Footer legal */
.trz__footer-legal {
  margin-top: 1.5rem; padding: .75rem 1.25rem;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px;
  font-size: .68rem; color: #94a3b8; text-align: center; font-style: italic;
}

@media print {
  .trz__top, .trz__btn-pdf, .trz__btn-back { display: none !important; }
  .trz { padding: 0; }
  .trz__node { break-inside: avoid; }
}
</style>
