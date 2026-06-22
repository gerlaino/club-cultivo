<template>
  <div class="et">

    <!-- Toolbar (no print) -->
    <div class="et__toolbar no-print">
      <button class="et__btn-back" @click="$router.back()">← Volver</button>
      <div class="et__toolbar-title">Etiqueta de despacho</div>
      <div class="et__toolbar-actions">
        <select v-model="tamano" class="et__select">
          <option value="90x50">90 × 50 mm</option>
          <option value="100x70">100 × 70 mm</option>
        </select>
        <button class="et__btn-ghost" :disabled="!despacho" @click="descargarPNG">⬇ PNG</button>
        <button class="et__btn-ghost" :disabled="!despacho" @click="descargarSVG">⬇ SVG</button>
        <button class="et__btn-print" @click="imprimir">🖨️ Imprimir</button>
      </div>
    </div>

    <div v-if="loading" class="et__loading no-print">Cargando despacho…</div>
    <div v-else-if="!despacho" class="et__loading no-print">Despacho no encontrado</div>

    <!-- Etiqueta -->
    <div v-else class="et__preview">
      <div class="et__etiqueta" :class="`et__etiqueta--${tamano}`">

        <!-- Header: club -->
        <div class="et__header">
          <img v-if="club.logoUrl" :src="club.logoUrl" alt="logo" class="et__logo" />
          <span class="et__club-nombre">{{ club.name }}</span>
        </div>

        <div class="et__body">
          <!-- QR -->
          <div class="et__qr-area">
            <img v-if="qrDataUrl" :src="qrDataUrl" alt="QR" class="et__qr-img" />
            <div class="et__qr-cap">Escaneá para gestionar la entrega</div>
          </div>

          <!-- Info -->
          <div class="et__info">
            <div class="et__codigo">{{ despacho.codigo_paquete || `#${despacho.id}` }}</div>
            <div class="et__paciente">{{ despacho.paciente_nombre || '—' }}</div>
            <div v-if="despacho.direccion_envio" class="et__dir">📍 {{ despacho.direccion_envio }}</div>
            <div v-if="despacho.contacto_nombre || despacho.contacto_telefono" class="et__contacto">
              📞 {{ despacho.contacto_nombre }}<span v-if="despacho.contacto_telefono"> · {{ despacho.contacto_telefono }}</span>
            </div>
          </div>
        </div>

        <!-- Footer: producto -->
        <div class="et__footer">
          <span v-if="despacho.genetica_nombre">{{ despacho.genetica_nombre }}</span>
          <span v-if="despacho.cantidad"> · {{ despacho.cantidad }}g</span>
          <span v-if="despacho.lote_codigo" class="et__lote"> · Lote {{ despacho.lote_codigo }}</span>
        </div>

      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getDispensacion } from '../../lib/api.js'
import { useClubStore } from '../../stores/club.js'
import { useQRCode } from '../../composables/useQRCode.js'

const route   = useRoute()
const club    = useClubStore()
const id      = Number(route.params.id)
const loading = ref(true)
const despacho = ref(null)
const tamano   = ref('90x50')
const qrDataUrl = ref(null)
const { generatePNG, downloadPNG, downloadSVG } = useQRCode()

// El QR lleva (con login) a la página de despachos, enfocando este paquete.
function qrUrl() {
  const code = despacho.value?.codigo_paquete || despacho.value?.id
  return `${window.location.origin}/delivery/despachos?paquete=${encodeURIComponent(code)}`
}

function imprimir() { window.print() }

async function descargarPNG() {
  await downloadPNG(qrUrl(), `despacho-${despacho.value?.codigo_paquete || id}.png`)
}
async function descargarSVG() {
  await downloadSVG(qrUrl(), `despacho-${despacho.value?.codigo_paquete || id}.svg`)
}

onMounted(async () => {
  if (!club.data) { try { await club.fetch() } catch {} }
  try {
    const { data } = await getDispensacion(id)
    despacho.value = data.data || data
    qrDataUrl.value = await generatePNG(qrUrl(), { width: 240, margin: 1, color: { dark: '#1b5e20', light: '#ffffff' } })
  } catch { despacho.value = null }
  finally { loading.value = false }
})
</script>

<style scoped>
.et { min-height: 100vh; background: #f1f5f9; }

/* Toolbar */
.et__toolbar {
  display: flex; align-items: center; gap: 1rem; padding: .75rem 1.5rem;
  background: white; border-bottom: 1px solid #e2e8f0;
  position: sticky; top: 0; z-index: 10; flex-wrap: wrap;
}
.et__btn-back { font-size: .85rem; color: #64748b; background: none; border: none; cursor: pointer; padding: .3rem .6rem; border-radius: 6px; }
.et__btn-back:hover { background: #f8fafc; color: #334155; }
.et__toolbar-title { font-size: .95rem; font-weight: 700; color: #1a1a1a; flex: 1; }
.et__toolbar-actions { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.et__select { padding: .4rem .6rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: .85rem; }
.et__btn-ghost { padding: .5rem .8rem; background: #fff; color: #334155; border: 1.5px solid #cbd5e1; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; }
.et__btn-ghost:hover:not(:disabled) { background: #f8fafc; }
.et__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
.et__btn-print { padding: .5rem 1rem; background: #1b5e20; color: white; border: none; border-radius: 7px; font-size: .85rem; font-weight: 600; cursor: pointer; }
.et__btn-print:hover { background: #104417; }

.et__loading { padding: 3rem; text-align: center; color: #64748b; }

/* Preview */
.et__preview { display: flex; justify-content: center; align-items: center; padding: 3rem 1rem; min-height: calc(100vh - 60px); }

/* Etiqueta */
.et__etiqueta {
  background: white; border: 2px solid #1b5e20; border-radius: 6px;
  display: flex; flex-direction: column; padding: 3mm 4mm;
  font-family: system-ui, -apple-system, sans-serif;
  box-shadow: 0 4px 20px rgba(0,0,0,.15);
}
.et__etiqueta--90x50 { width: 90mm; min-height: 50mm; font-size: 8pt; }
.et__etiqueta--100x70 { width: 100mm; min-height: 70mm; font-size: 9pt; }

.et__header { display: flex; align-items: center; gap: 1.5mm; border-bottom: .5pt solid #e2e8f0; padding-bottom: 1.5mm; margin-bottom: 2mm; }
.et__logo { height: 6mm; width: auto; object-fit: contain; }
.et__club-nombre { font-weight: 800; color: #1b5e20; font-size: 1.15em; line-height: 1; }

.et__body { display: flex; gap: 3mm; align-items: flex-start; }
.et__qr-area { display: flex; flex-direction: column; align-items: center; gap: 1mm; flex-shrink: 0; }
.et__qr-img { width: 22mm; height: 22mm; display: block; }
.et__qr-cap { font-size: .7em; color: #64748b; text-align: center; max-width: 22mm; line-height: 1.1; }

.et__info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .8mm; }
.et__codigo { font-family: monospace; font-weight: 800; font-size: 1.2em; color: #1b5e20; }
.et__paciente { font-weight: 700; color: #1a1a1a; font-size: 1.05em; }
.et__dir { color: #334155; font-size: .92em; line-height: 1.25; }
.et__contacto { color: #475569; font-size: .88em; }

.et__footer { display: flex; flex-wrap: wrap; gap: 1mm; color: #64748b; font-size: .85em; border-top: .5pt solid #e2e8f0; padding-top: 1.5mm; margin-top: auto; }
.et__lote { font-weight: 600; }

/* Print */
@media print {
  .no-print { display: none !important; }
  .et { background: none; }
  .et__preview { padding: 0; min-height: auto; }
  .et__etiqueta { box-shadow: none; border-color: #000; page-break-inside: avoid; }
  @page { margin: 4mm; }
}
</style>
