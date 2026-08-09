<template>
  <div class="et">

    <!-- Toolbar (no print) -->
    <div class="et__toolbar no-print">
      <button class="et__btn-back" @click="$router.back()">← Volver</button>
      <div class="et__toolbar-title">Etiqueta de despacho</div>
      <div class="et__toolbar-actions">
        <select v-model="tamano" class="et__select">
          <option value="100x70">100 × 70 mm</option>
          <option value="100x150">100 × 150 mm</option>
        </select>
        <button class="et__btn-ghost" :disabled="!despacho || descargando" @click="descargarPDF">
          {{ descargando ? 'Generando…' : '⬇ Descargar' }}
        </button>
        <button class="et__btn-print" :disabled="!despacho" @click="imprimir">🖨️ Imprimir</button>
      </div>
    </div>

    <div v-if="loading" class="et__loading no-print">Cargando despacho…</div>
    <div v-else-if="!despacho" class="et__loading no-print">Despacho no encontrado</div>

    <!-- Etiqueta -->
    <div v-else class="et__preview">
      <div id="despacho-label">
        <EtiquetaDespacho :despacho="despacho" :tamano="tamano" />
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import html2pdf from 'html2pdf.js'
import { getDispensacion } from '../../lib/api.js'
import { useClubStore } from '../../stores/club.js'
import EtiquetaDespacho from '../../components/delivery/EtiquetaDespacho.vue'

const route   = useRoute()
const club    = useClubStore()
const id      = Number(route.params.id)
const loading = ref(true)
const despacho = ref(null)
const tamano   = ref('100x70')
const descargando = ref(false)

function imprimir() { window.print() }

async function descargarPDF() {
  descargando.value = true
  try {
    const el = document.getElementById('despacho-label')
    const [w, h] = tamano.value.split('x').map(Number)
    const code = despacho.value?.codigo_paquete || id
    await html2pdf().set({
      margin:      0,
      filename:    `despacho-${code}.pdf`,
      image:       { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 3, useCORS: true, logging: false },
      jsPDF:       { unit: 'mm', format: [w, h], orientation: w > h ? 'landscape' : 'portrait' },
    }).from(el).save()
  } finally { descargando.value = false }
}

onMounted(async () => {
  if (!club.data) { try { await club.fetch() } catch {} }
  try {
    const { data } = await getDispensacion(id)
    despacho.value = data.data || data
  } catch { despacho.value = null }
  finally { loading.value = false }
})
</script>

<style scoped>
.et { min-height: 100vh; background: var(--c-slate-100); }

/* Toolbar */
.et__toolbar {
  display: flex; align-items: center; gap: 1rem; padding: .75rem 1.5rem;
  background: white; border-bottom: 1px solid var(--c-slate-200);
  position: sticky; top: 0; z-index: 10; flex-wrap: wrap;
}
.et__btn-back { font-size: .85rem; color: var(--c-slate-500); background: none; border: none; cursor: pointer; padding: .3rem .6rem; border-radius: 6px; }
.et__btn-back:hover { background: var(--c-slate-50); color: var(--c-slate-700); }
.et__toolbar-title { font-size: .95rem; font-weight: 700; color: #1a1a1a; flex: 1; }
.et__toolbar-actions { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.et__select { padding: .4rem .6rem; border: 1px solid var(--c-slate-300); border-radius: 6px; font-size: .85rem; }
.et__btn-ghost { padding: .5rem .8rem; background: #fff; color: var(--c-slate-700); border: 1.5px solid var(--c-slate-300); border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; }
.et__btn-ghost:hover:not(:disabled) { background: var(--c-slate-50); }
.et__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
.et__btn-print { padding: .5rem 1rem; background: #1b5e20; color: white; border: none; border-radius: 7px; font-size: .85rem; font-weight: 600; cursor: pointer; }
.et__btn-print:hover:not(:disabled) { background: #104417; }
.et__btn-print:disabled { opacity: .5; cursor: not-allowed; }

.et__loading { padding: 3rem; text-align: center; color: var(--c-slate-500); }

/* Preview */
.et__preview { display: flex; justify-content: center; align-items: center; padding: 3rem 1rem; min-height: calc(100vh - 60px); }

/* Etiqueta */
.et__etiqueta {
  background: white; border: 2px solid #1b5e20; border-radius: 6px;
  display: flex; flex-direction: column; padding: 4mm 5mm;
  font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a;
  box-shadow: 0 4px 20px rgba(0,0,0,.15);
}
.et__etiqueta--100x70 { width: 100mm; min-height: 70mm; font-size: 10pt; }
.et__etiqueta--100x150 { width: 100mm; min-height: 150mm; font-size: 12pt; }

.et__header { display: flex; align-items: center; gap: 2mm; border-bottom: .5pt solid var(--c-slate-300); padding-bottom: 2mm; margin-bottom: 3mm; }
.et__logo { height: 8mm; width: auto; object-fit: contain; }
.et__club-nombre { font-weight: 800; color: #1b5e20; font-size: 1.25em; line-height: 1.1; }

.et__para-lbl { font-size: .7em; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: var(--c-slate-400); }
.et__para { font-weight: 800; font-size: 1.6em; line-height: 1.15; color: var(--c-slate-900); margin-bottom: 2mm; }
.et__dir { font-size: 1em; line-height: 1.3; color: var(--c-slate-700); }
.et__tel { font-size: .95em; color: var(--c-slate-600); margin-top: 1mm; }
.et__cobrar { margin-top: 2mm; padding: 1.5mm 2mm; border: 1pt solid #166534; border-radius: 1.5mm; background: #f0fdf4; color: #166534; font-weight: 800; font-size: .95em; text-align: center; letter-spacing: .02em; }

.et__footer { display: flex; align-items: center; gap: 2mm; border-top: .5pt solid var(--c-slate-300); padding-top: 2mm; margin-top: auto; }
.et__cod-lbl { font-size: .7em; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-slate-400); }
.et__cod { font-family: monospace; font-weight: 800; font-size: 1.1em; color: #1b5e20; }

/* Print */
@media print {
  .no-print { display: none !important; }
  .et { background: none; }
  .et__preview { padding: 0; min-height: auto; }
  .et__etiqueta { box-shadow: none; border-color: #000; page-break-inside: avoid; }
  @page { margin: 5mm; }
}
</style>
