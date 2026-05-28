<template>
  <div class="cp">

    <div v-if="estado === 'cargando'" class="cp__loading">
      <DsSpinner :size="60" />
    </div>

    <div v-else-if="estado === 'no_encontrado'" class="cp__error">
      <span class="cp__error-ico">✕</span>
      <h2>Carnet no válido</h2>
      <p>El carnet no se encontró o fue revocado.</p>
    </div>

    <template v-else-if="data">

      <!-- Card capturable por html2pdf -->
      <div id="carnet-card" class="cp__card">

        <!-- Header -->
        <div class="cp__header">
          <img v-if="data.club?.logo" :src="data.club.logo" :alt="data.club.nombre" class="cp__logo" />
          <div v-else class="cp__logo-placeholder">🌿</div>
          <div class="cp__header-text">
            <div class="cp__club-name">{{ data.club?.nombre }}</div>
            <div class="cp__card-title">Carnet de Socio</div>
          </div>
        </div>

        <!-- Status strip -->
        <div class="cp__status" :class="`cp__status--${data.estado_membresia}`">
          <span class="cp__status-dot"></span>
          <span>{{ estadoLabel }}</span>
        </div>

        <!-- Body: datos + QR -->
        <div class="cp__body">
          <div class="cp__fields">
            <div class="cp__field">
              <span class="cp__field-label">Nombre</span>
              <span class="cp__field-val">{{ data.nombre }} {{ data.apellido_inicial }}</span>
            </div>
            <div class="cp__field">
              <span class="cp__field-label">N.° socio</span>
              <span class="cp__field-val cp__field-val--mono">{{ String(data.numero_socio).padStart(6, '0') }}</span>
            </div>
            <div class="cp__field">
              <span class="cp__field-label">REPROCANN</span>
              <span class="cp__reprocann" :class="`cp__reprocann--${data.reprocann_estado}`">{{ reprocannLabel }}</span>
            </div>
            <div v-if="data.reprocann_vencimiento" class="cp__field">
              <span class="cp__field-label">Vto. cert.</span>
              <span class="cp__field-val">{{ formatDate(data.reprocann_vencimiento) }}</span>
            </div>
          </div>
          <div class="cp__qr-wrap">
            <canvas ref="qrCanvas" class="cp__qr"></canvas>
            <div class="cp__qr-hint">Escanear para verificar</div>
          </div>
        </div>

        <!-- Footer -->
        <div class="cp__footer">
          <span>Emitido {{ formatDate(data.emitido_at) }}</span>
          <span class="cp__verified">✓ Verificado</span>
        </div>

      </div>

      <!-- Acciones (fuera del card, no se incluyen en el PDF) -->
      <div class="cp__actions">
        <button class="cp__btn cp__btn--primary" @click="descargarPDF" :disabled="descargando">
          <DsSpinner v-if="descargando" :size="14" />
          <svg v-else width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>
          </svg>
          {{ descargando ? 'Generando…' : 'Descargar PDF' }}
        </button>
        <button class="cp__btn cp__btn--ghost" @click="imprimir">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/><rect x="6" y="14" width="12" height="8"/>
          </svg>
          Imprimir
        </button>
      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import axios from 'axios'
import QRCode from 'qrcode'
import html2pdf from 'html2pdf.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const route = useRoute()
const estado     = ref('cargando')
const data       = ref(null)
const qrCanvas   = ref(null)
const descargando = ref(false)

const BASE_URL = import.meta.env.VITE_API_URL?.replace('/api', '') || 'http://localhost:3001'
const APP_HOST = window.location.origin

async function cargar() {
  try {
    const res = await axios.get(`${BASE_URL}/c/${route.params.token}`)
    data.value  = res.data
    estado.value = 'ok'
    await nextTick()
    generarQR()
  } catch {
    estado.value = 'no_encontrado'
  }
}

function generarQR() {
  if (!qrCanvas.value) return
  const url = `${APP_HOST}/c/${route.params.token}`
  QRCode.toCanvas(qrCanvas.value, url, {
    width: 88,
    margin: 1,
    color: { dark: '#1b5e20', light: '#ffffff' },
  })
}

async function descargarPDF() {
  descargando.value = true
  const el = document.getElementById('carnet-card')
  const nombre = `${data.value?.nombre || 'socio'}-${data.value?.numero_socio || ''}`.toLowerCase().replace(/\s+/g, '-')
  await html2pdf().set({
    margin:     0,
    filename:   `carnet-${nombre}.pdf`,
    image:      { type: 'jpeg', quality: 0.98 },
    html2canvas: { scale: 3, useCORS: true, logging: false },
    jsPDF:      { unit: 'mm', format: [90, 148], orientation: 'portrait' },
  }).from(el).save()
  descargando.value = false
}

function imprimir() {
  window.print()
}

const estadoLabel   = computed(() => data.value?.estado_membresia === 'activo' ? 'Activo' : 'Baja')
const reprocannLabel = computed(() => ({
  vigente:       'Vigente',
  por_vencer:    'Por vencer',
  vencido:       'Vencido',
  sin_registro:  'Sin registro',
}[data.value?.reprocann_estado] ?? '—'))

const formatDate = (d) => d
  ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
  : '—'

onMounted(cargar)
</script>

<style scoped>
/* ── Wrapper ──────────────────────────────────────────────── */
.cp {
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  background: #f0f4f0;
  padding: 1.5rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

/* Loading */
.cp__loading { display: flex; align-items: center; justify-content: center; min-height: 100vh; }

/* Error */
.cp__error { text-align: center; background: #fff; border-radius: 20px; padding: 2.5rem 2rem; max-width: 340px; width: 100%; box-shadow: 0 8px 32px rgba(0,0,0,.08); }
.cp__error-ico { display: block; font-size: 3rem; margin-bottom: .75rem; color: #dc2626; }
.cp__error h2 { font-size: 1.2rem; font-weight: 700; color: #1a1a1a; margin: 0 0 .5rem; }
.cp__error p  { font-size: .9rem; color: #5b6473; margin: 0; }

/* ── Card ─────────────────────────────────────────────────── */
.cp__card {
  background: #fff;
  border-radius: 16px;
  width: 100%;
  max-width: 340px;
  box-shadow: 0 8px 32px rgba(27,94,32,.14), 0 2px 8px rgba(0,0,0,.06);
  overflow: hidden;
}

/* Header */
.cp__header {
  background: linear-gradient(135deg, #1a3d2e 0%, #1b5e20 60%, #2e7d32 100%);
  padding: 1.25rem 1.25rem .875rem;
  display: flex;
  align-items: center;
  gap: .875rem;
}
.cp__logo { height: 44px; width: 44px; border-radius: 8px; object-fit: contain; background: rgba(255,255,255,.15); padding: 4px; flex-shrink: 0; }
.cp__logo-placeholder {
  width: 44px; height: 44px; flex-shrink: 0;
  background: rgba(255,255,255,.15); border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.5rem;
}
.cp__header-text { flex: 1; min-width: 0; }
.cp__club-name  { font-size: .78rem; font-weight: 600; color: rgba(255,255,255,.75); margin-bottom: .15rem; text-transform: uppercase; letter-spacing: .06em; }
.cp__card-title { font-size: 1.05rem; font-weight: 800; color: #fff; letter-spacing: .01em; }

/* Status strip */
.cp__status {
  display: flex; align-items: center; justify-content: center; gap: .45rem;
  padding: .45rem 1rem;
  font-size: .72rem; font-weight: 800;
  text-transform: uppercase; letter-spacing: .08em;
}
.cp__status--activo { background: #e8f5e9; color: #1b5e20; }
.cp__status--baja   { background: #fff5f5; color: #dc2626; }
.cp__status-dot { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }

/* Body */
.cp__body {
  display: flex;
  gap: .75rem;
  padding: 1rem 1.1rem;
  align-items: flex-start;
}
.cp__fields { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .6rem; }
.cp__field { display: flex; flex-direction: column; gap: .08rem; }
.cp__field-label { font-size: .62rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; }
.cp__field-val { font-size: .88rem; font-weight: 700; color: #0f172a; }
.cp__field-val--mono { font-family: 'SF Mono', 'Fira Code', monospace; font-size: .85rem; color: #1b5e20; }

.cp__reprocann { display: inline-block; padding: .15rem .55rem; border-radius: 999px; font-size: .72rem; font-weight: 700; margin-top: .08rem; }
.cp__reprocann--vigente     { background: #e8f5e9; color: #1b5e20; }
.cp__reprocann--por_vencer  { background: #fffbeb; color: #b45309; }
.cp__reprocann--vencido     { background: #fff5f5; color: #dc2626; }
.cp__reprocann--sin_registro{ background: #f1f5f9; color: #5b6473; }

/* QR */
.cp__qr-wrap { display: flex; flex-direction: column; align-items: center; gap: .3rem; flex-shrink: 0; }
.cp__qr { display: block; border-radius: 6px; border: 1.5px solid #e8f0e9; }
.cp__qr-hint { font-size: .55rem; color: #b0c4b0; text-align: center; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; }

/* Footer */
.cp__footer {
  padding: .6rem 1.1rem;
  background: #f8faf8;
  border-top: 1px solid #e8f0e9;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: .68rem;
  color: #94a3b8;
}
.cp__verified { color: #1b5e20; font-weight: 700; }

/* ── Botones ──────────────────────────────────────────────── */
.cp__actions {
  display: flex;
  gap: .5rem;
  flex-wrap: wrap;
  justify-content: center;
  width: 100%;
  max-width: 340px;
}
.cp__btn {
  display: inline-flex; align-items: center; gap: .4rem;
  padding: .65rem 1.25rem; border-radius: 10px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  border: none; transition: all .15s; flex: 1;
  justify-content: center; min-width: 0;
}
.cp__btn--primary { background: #1b5e20; color: #fff; }
.cp__btn--primary:hover:not(:disabled) { background: #144a18; }
.cp__btn--primary:disabled { opacity: .6; cursor: not-allowed; }
.cp__btn--ghost { background: #fff; color: #475569; border: 1.5px solid #e2e8f0; }
.cp__btn--ghost:hover { background: #f8fafc; }

/* ── Print ────────────────────────────────────────────────── */
@media print {
  .cp { background: #fff; padding: 0; min-height: unset; }
  .cp__actions { display: none; }
  .cp__card { box-shadow: none; border-radius: 12px; border: 1px solid #e2e8f0; max-width: 100%; }
}
</style>
