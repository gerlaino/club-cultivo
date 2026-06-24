<template>
  <div class="etl">
    <!-- Toolbar (no print) -->
    <div class="etl__toolbar no-print">
      <button class="etl__btn-back" @click="$router.back()">← Volver</button>
      <div class="etl__title">
        Etiquetas de despacho
        <span v-if="despachos.length" class="etl__count">· {{ despachos.length }}</span>
      </div>
      <div class="etl__actions">
        <select v-model="tamano" class="etl__select">
          <option value="100x70">100 × 70 mm</option>
          <option value="100x150">100 × 150 mm</option>
        </select>
        <button class="etl__btn-ghost" :disabled="!despachos.length || descargando" @click="descargarPDF">
          {{ descargando ? 'Generando…' : '⬇ Descargar PDF' }}
        </button>
        <button class="etl__btn-print" :disabled="!despachos.length" @click="imprimir">🖨️ Imprimir todas</button>
      </div>
    </div>

    <div v-if="loading" class="etl__loading no-print">Cargando despachos…</div>
    <div v-else-if="!despachos.length" class="etl__loading no-print">No se encontraron despachos para imprimir.</div>

    <!-- Etiquetas: una por hoja al imprimir -->
    <div v-else id="etiquetas-lote" class="etl__hojas">
      <div v-for="d in despachos" :key="d.id" class="etl__hoja">
        <EtiquetaDespacho :despacho="d" :tamano="tamano" />
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

const route = useRoute()
const club  = useClubStore()
const loading = ref(true)
const despachos = ref([])
const tamano = ref('100x70')
const descargando = ref(false)

const ids = String(route.query.ids || '')
  .split(',').map(s => Number(s.trim())).filter(Boolean)

function imprimir() { window.print() }

async function descargarPDF() {
  descargando.value = true
  try {
    const el = document.getElementById('etiquetas-lote')
    const [w, h] = tamano.value.split('x').map(Number)
    await html2pdf().set({
      margin:      0,
      filename:    `etiquetas-despacho-${despachos.value.length}.pdf`,
      image:       { type: 'jpeg', quality: 0.98 },
      html2canvas: { scale: 3, useCORS: true, logging: false },
      jsPDF:       { unit: 'mm', format: [w, h], orientation: w > h ? 'landscape' : 'portrait' },
      pagebreak:   { mode: ['css', 'legacy'] },
    }).from(el).save()
  } finally { descargando.value = false }
}

onMounted(async () => {
  if (!club.data) { try { await club.fetch() } catch {} }
  try {
    const results = await Promise.all(ids.map(id => getDispensacion(id).then(r => r.data?.data || r.data).catch(() => null)))
    despachos.value = results.filter(Boolean)
  } catch { despachos.value = [] }
  finally { loading.value = false }
})
</script>

<style scoped>
.etl { min-height: 100vh; background: #f1f5f9; }

.etl__toolbar {
  display: flex; align-items: center; gap: 1rem; padding: .75rem 1.5rem;
  background: white; border-bottom: 1px solid #e2e8f0;
  position: sticky; top: 0; z-index: 10; flex-wrap: wrap;
}
.etl__btn-back { font-size: .85rem; color: #64748b; background: none; border: none; cursor: pointer; padding: .3rem .6rem; border-radius: 6px; }
.etl__btn-back:hover { background: #f8fafc; color: #334155; }
.etl__title { font-size: .95rem; font-weight: 700; color: #1a1a1a; flex: 1; }
.etl__count { color: #1b5e20; }
.etl__actions { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.etl__select { padding: .4rem .6rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: .85rem; }
.etl__btn-ghost { padding: .5rem .8rem; background: #fff; color: #334155; border: 1.5px solid #cbd5e1; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; }
.etl__btn-ghost:hover:not(:disabled) { background: #f8fafc; }
.etl__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
.etl__btn-print { padding: .5rem 1rem; background: #1b5e20; color: white; border: none; border-radius: 7px; font-size: .85rem; font-weight: 600; cursor: pointer; }
.etl__btn-print:hover:not(:disabled) { background: #104417; }
.etl__btn-print:disabled { opacity: .5; cursor: not-allowed; }

.etl__loading { padding: 3rem; text-align: center; color: #64748b; }

.etl__hojas { display: flex; flex-direction: column; align-items: center; gap: 1.5rem; padding: 2rem 1rem; }
.etl__hoja { page-break-after: always; }

@media print {
  .no-print { display: none !important; }
  .etl { background: none; }
  .etl__hojas { gap: 0; padding: 0; }
  .etl__hoja { page-break-after: always; }
  .etl__hoja:last-child { page-break-after: auto; }
  @page { margin: 5mm; }
}
</style>
