<script setup>
// Entradas vendidas de un evento (Capa 4): listado + QR de cada entrada (para entregar/imprimir)
// + anular. El QR codifica el código que la puerta escanea.
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { listEntradas, anularEntrada } from '../../lib/api.js'
import { useQRCode } from '../../composables/useQRCode.js'
import { useToast } from '../../composables/useToast.js'
import { useConfirm } from '../../composables/useConfirm.js'

const route = useRoute()
const toast = useToast()
const { confirm } = useConfirm()
const { generatePNG, downloadPNG } = useQRCode()
const barId = route.params.barId
const evId  = route.params.eventoId

const entradas = ref([])
const loading  = ref(false)
const qrModal  = ref(null) // { entrada, dataUrl }

const ESTADO_CLS = { valida: 'ok', usada: 'used', anulada: 'bad' }
const fmt = (n) => `$${Math.round(n || 0).toLocaleString('es-AR')}`

async function cargar() {
  loading.value = true
  try { const { data } = await listEntradas(barId, evId); entradas.value = data || [] }
  catch (e) { toast.error(e?.response?.data?.error || 'No se pudo cargar') }
  finally { loading.value = false }
}
onMounted(cargar)

async function verQR(e) {
  const dataUrl = await generatePNG(e.codigo, { width: 320 })
  qrModal.value = { entrada: e, dataUrl }
}
async function descargarQR() {
  await downloadPNG(qrModal.value.entrada.codigo, `entrada-${qrModal.value.entrada.codigo}.png`)
}
async function anular(e) {
  if (!(await confirm({ title: 'Anular entrada', message: `¿Anular la entrada de ${e.comprador || e.tipo}?`, variant: 'danger' }))) return
  try { await anularEntrada(barId, evId, e.id); await cargar(); toast.success('Entrada anulada') }
  catch { toast.error('No se pudo anular') }
}
</script>

<template>
  <div class="en">
    <header class="en__head">
      <RouterLink :to="`/bar/${barId}/eventos/${evId}`" class="en__back">← Evento</RouterLink>
      <h1>Entradas vendidas</h1>
    </header>

    <div v-if="loading" class="en__loading">Cargando…</div>
    <div v-else-if="!entradas.length" class="en__empty">Todavía no se vendieron entradas.</div>

    <table v-else class="tbl">
      <thead><tr><th>Comprador</th><th>Tipo</th><th>Precio</th><th>Estado</th><th></th></tr></thead>
      <tbody>
        <tr v-for="e in entradas" :key="e.id">
          <td>{{ e.comprador || '—' }}<small class="cod">{{ e.codigo }}</small></td>
          <td class="mut">{{ e.tipo }}</td>
          <td class="num">{{ fmt(e.precio_ars) }}</td>
          <td><span class="st" :class="ESTADO_CLS[e.estado]">{{ e.estado }}</span></td>
          <td class="acts">
            <button class="lnk" @click="verQR(e)">QR</button>
            <button v-if="e.estado !== 'anulada'" class="lnk lnk--danger" @click="anular(e)">Anular</button>
          </td>
        </tr>
      </tbody>
    </table>

    <div v-if="qrModal" class="ov" @click.self="qrModal = null">
      <div class="modal">
        <h3>Entrada</h3>
        <p class="modal__hint">{{ qrModal.entrada.comprador || qrModal.entrada.tipo }} · {{ qrModal.entrada.tipo }}</p>
        <img :src="qrModal.dataUrl" alt="QR de la entrada" class="qrimg" />
        <p class="cod2">{{ qrModal.entrada.codigo }}</p>
        <div class="modal__actions">
          <button class="btn" @click="qrModal = null">Cerrar</button>
          <button class="btn btn--primary" @click="descargarQR">⭳ Descargar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.en { padding: var(--sp-6, 24px); max-width: 720px; margin: 0 auto; }
.en__head { display: flex; align-items: center; gap: 14px; margin-bottom: var(--sp-4, 16px); }
.en__back { font-size: var(--fs-13, 13px); color: #1b5e20; text-decoration: none; font-weight: 600; }
.en__head h1 { font-size: var(--fs-22, 22px); font-weight: 700; color: #0f172a; margin: 0; }
.en__loading, .en__empty { color: #64748b; padding: var(--sp-8, 32px); text-align: center; }

.tbl { width: 100%; border-collapse: collapse; font-size: var(--fs-14, 14px); background: var(--c-paper, #fff); border: 1px solid #f1f5f9; border-radius: var(--r-md, 10px); overflow: hidden; }
.tbl th { text-align: left; font-size: var(--fs-11, 11px); text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; font-weight: 700; padding: 10px 12px; border-bottom: 1px solid #f1f5f9; }
.tbl td { padding: 10px 12px; border-bottom: 1px solid #f1f5f9; color: #1e293b; }
.tbl tr:last-child td { border-bottom: none; }
.cod { display: block; font-family: inherit; font-size: var(--fs-11, 11px); color: #94a3b8; }
.num { text-align: right; font-variant-numeric: tabular-nums; }
.mut { color: #94a3b8; }
.acts { text-align: right; white-space: nowrap; }
.st { font-size: .66rem; font-weight: 640; padding: 3px 9px; border-radius: 999px; }
.st.ok { background: #f0fdf4; color: #1b5e20; }
.st.used { background: #f1f5f9; color: #64748b; }
.st.bad { background: #fee2e2; color: #dc2626; }
.lnk { background: none; border: none; color: #64748b; font-size: var(--fs-13, 13px); cursor: pointer; padding: 2px 6px; }
.lnk:hover { color: #0f172a; }
.lnk--danger:hover { color: #dc2626; }

.ov { position: fixed; inset: 0; background: rgba(20,20,20,.5); display: grid; place-items: center; z-index: 1000; padding: 16px; }
.modal { background: var(--c-paper, #fff); border-radius: var(--r-lg, 14px); padding: var(--sp-5, 20px); width: 100%; max-width: 320px; text-align: center; box-shadow: var(--sh-3, 0 20px 50px rgba(0,0,0,.25)); }
.modal h3 { margin: 0; font-size: var(--fs-18, 18px); color: #0f172a; }
.modal__hint { color: #64748b; font-size: var(--fs-13, 13px); margin: 4px 0 var(--sp-3, 12px); }
.qrimg { width: 220px; height: 220px; border-radius: var(--r-md, 10px); }
.cod2 { font-family: inherit; font-size: var(--fs-12, 12px); color: #94a3b8; margin: 8px 0 var(--sp-3, 12px); }
.modal__actions { display: flex; gap: 8px; justify-content: center; }
.btn { border: 1px solid #e2e8f0; background: var(--c-paper, #fff); color: #1e293b; border-radius: var(--r-sm, 8px); padding: 8px 16px; font-size: var(--fs-13, 13px); font-weight: 600; cursor: pointer; }
.btn--primary { background: #1b5e20; border-color: #1b5e20; color: #fff; }
</style>
