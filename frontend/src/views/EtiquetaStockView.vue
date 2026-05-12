<template>
  <div class="et">

    <!-- Toolbar (no print) -->
    <div class="et__toolbar no-print">
      <button class="et__btn-back" @click="$router.back()">← Volver</button>
      <div class="et__toolbar-title">Etiqueta de producto</div>
      <div class="et__toolbar-actions">
        <select v-model="tamano" class="et__select">
          <option value="60x40">60 × 40 mm</option>
          <option value="90x50">90 × 50 mm</option>
          <option value="100x70">100 × 70 mm</option>
        </select>
        <button class="et__btn-print" @click="window.print()">🖨️ Imprimir</button>
      </div>
    </div>

    <div v-if="loading" class="et__loading no-print">Cargando stock…</div>
    <div v-else-if="!stock" class="et__loading no-print">Stock no encontrado</div>

    <!-- Etiqueta -->
    <div v-else class="et__preview">
      <div class="et__etiqueta" :class="`et__etiqueta--${tamano}`">
        <!-- Header: club -->
        <div class="et__header">
          <img v-if="stock.club?.logo_url" :src="stock.club.logo_url" alt="logo" class="et__logo" />
          <span class="et__club-nombre">{{ stock.club?.nombre }}</span>
        </div>

        <!-- QR code placeholder -->
        <div class="et__qr-area">
          <div class="et__qr-placeholder">
            <span class="et__qr-icon">▦</span>
            <span class="et__qr-text">{{ stock.codigo_qr }}</span>
          </div>
          <div class="et__lote-numero">{{ stock.numero_lote_producto }}</div>
        </div>

        <!-- Info principal -->
        <div class="et__info">
          <div class="et__genetica">{{ stock.lote?.genetica?.nombre || stock.forma_producto_label }}</div>
          <div class="et__forma">{{ formaLabel(stock.forma_producto) }} · {{ stock.cantidad }}{{ stock.unidad }}</div>
        </div>

        <!-- Fechas y INASE -->
        <div class="et__footer">
          <span v-if="stock.fecha_elaboracion">Elab: {{ formatDate(stock.fecha_elaboracion) }}</span>
          <span v-if="stock.fecha_vencimiento_est"> · Vto: {{ formatDate(stock.fecha_vencimiento_est) }}</span>
          <span v-if="stock.lote?.genetica?.numero_registro_inase" class="et__inase">
            INASE {{ stock.lote.genetica.numero_registro_inase }}
          </span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import api from '../lib/api'

const route   = useRoute()
const stockId = Number(route.params.id)
const loading = ref(true)
const stock   = ref(null)
const tamano  = ref('60x40')

const FORMA_LABELS = {
  flor_seca:   'Flor seca',
  concentrado: 'Concentrado',
  tintura:     'Tintura',
  aceite:      'Aceite',
  comestible:  'Comestible',
  topico:      'Tópico',
}
function formaLabel(f) { return FORMA_LABELS[f] || f || '—' }
function formatDate(d) {
  if (!d) return '—'
  const date = /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
  return date.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

onMounted(async () => {
  try {
    const { data } = await api.get(`/stocks/${stockId}`)
    stock.value = data.data || data
  } catch { stock.value = null }
  finally { loading.value = false }
})
</script>

<style scoped>
.et { min-height: 100vh; background: #f1f5f9; }

/* Toolbar */
.et__toolbar {
  display: flex; align-items: center; gap: 1rem; padding: .75rem 1.5rem;
  background: white; border-bottom: 1px solid #e2e8f0;
  position: sticky; top: 0; z-index: 10;
}
.et__btn-back { font-size: .85rem; color: #64748b; background: none; border: none; cursor: pointer; padding: .3rem .6rem; border-radius: 6px; }
.et__btn-back:hover { background: #f8fafc; color: #334155; }
.et__toolbar-title { font-size: .95rem; font-weight: 700; color: #1a1a1a; flex: 1; }
.et__toolbar-actions { display: flex; align-items: center; gap: .75rem; }
.et__select { padding: .4rem .6rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: .85rem; }
.et__btn-print { padding: .5rem 1rem; background: #1b5e20; color: white; border: none; border-radius: 7px; font-size: .85rem; font-weight: 600; cursor: pointer; }
.et__btn-print:hover { background: #104417; }

.et__loading { padding: 3rem; text-align: center; color: #64748b; }

/* Preview area */
.et__preview {
  display: flex; justify-content: center; align-items: center;
  padding: 3rem 1rem; min-height: calc(100vh - 60px);
}

/* Etiqueta base */
.et__etiqueta {
  background: white;
  border: 2px solid #1b5e20;
  border-radius: 6px;
  display: flex; flex-direction: column;
  padding: 3mm 4mm;
  font-family: system-ui, -apple-system, sans-serif;
  box-shadow: 0 4px 20px rgba(0,0,0,.15);
}

.et__etiqueta--60x40 { width: 60mm; min-height: 40mm; font-size: 7pt; }
.et__etiqueta--90x50 { width: 90mm; min-height: 50mm; font-size: 8pt; }
.et__etiqueta--100x70 { width: 100mm; min-height: 70mm; font-size: 9pt; }

.et__header { display: flex; align-items: center; gap: 1.5mm; border-bottom: .5pt solid #e2e8f0; padding-bottom: 1.5mm; margin-bottom: 2mm; }
.et__logo { height: 5mm; width: auto; object-fit: contain; }
.et__club-nombre { font-weight: 800; color: #1b5e20; font-size: 1.1em; line-height: 1; }

.et__qr-area { display: flex; align-items: center; gap: 2.5mm; margin-bottom: 1.5mm; }
.et__qr-placeholder { display: flex; flex-direction: column; align-items: center; gap: .5mm; padding: 1.5mm; border: 1pt solid #e2e8f0; border-radius: 2px; }
.et__qr-icon { font-size: 2em; line-height: 1; color: #1b5e20; }
.et__qr-text { font-family: monospace; font-size: .75em; color: #64748b; word-break: break-all; text-align: center; }
.et__lote-numero { font-family: monospace; font-size: 1em; font-weight: 800; color: #1b5e20; }

.et__info { margin-bottom: 1.5mm; }
.et__genetica { font-weight: 800; font-size: 1.1em; color: #1a1a1a; }
.et__forma { color: #475569; font-size: .9em; }

.et__footer { display: flex; flex-wrap: wrap; gap: 1mm; color: #64748b; font-size: .85em; border-top: .5pt solid #e2e8f0; padding-top: 1.5mm; margin-top: auto; }
.et__inase { font-weight: 700; color: #1b5e20; }

/* Print styles */
@media print {
  .no-print { display: none !important; }
  .et { background: none; }
  .et__preview { padding: 0; min-height: auto; }
  .et__etiqueta { box-shadow: none; border-color: #000; page-break-inside: avoid; }
  @page { margin: 3mm; }
}
</style>
