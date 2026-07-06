<template>
  <div class="cp">

    <!-- Cargando -->
    <div v-if="estado === 'cargando'" class="cp__loading">
      <div class="cp__loading-ico">🌿</div>
      <DsSpinner :size="32" />
    </div>

    <!-- No encontrado -->
    <div v-else-if="estado === 'no_encontrado'" class="cp__card">
      <div class="cp__header">
        <div class="cp__header-logo-wrap"><span class="cp__header-emoji">🌿</span></div>
        <div>
          <div class="cp__header-club">Cultivo Espacial</div>
          <div class="cp__header-sub">Carnet de Paciente</div>
        </div>
      </div>
      <div class="cp__body cp__body--center">
        <div class="cp__err-ico">✕</div>
        <div class="cp__err-title">Carnet no válido</div>
        <div class="cp__err-desc">El carnet no se encontró o fue revocado.</div>
      </div>
    </div>

    <template v-else-if="data">

      <!-- Card (capturable por html2pdf) -->
      <div id="carnet-card" class="cp__card">

        <!-- Header -->
        <div class="cp__header">
          <div class="cp__header-logo-wrap">
            <img v-if="data.club?.logo" :src="data.club.logo" :alt="data.club?.nombre" class="cp__header-logo" />
            <span v-else class="cp__header-emoji">🌿</span>
          </div>
          <div>
            <div class="cp__header-club">{{ data.club?.nombre }}</div>
            <div class="cp__header-sub">Carnet de Paciente</div>
          </div>
        </div>

        <!-- Status banner -->
        <div class="cp__status-banner" :class="`cp__status-banner--${data.estado_membresia}`">
          <span class="cp__status-dot"></span>
          {{ estadoLabel }}
        </div>

        <!-- Cuerpo -->
        <div class="cp__body">

          <!-- Nombre y número -->
          <div class="cp__identity">
            <div class="cp__nombre">{{ data.nombre }} {{ data.apellido_inicial }}.</div>
            <div class="cp__numero">Paciente N.° {{ String(data.numero_socio).padStart(6, '0') }}</div>
          </div>

          <!-- REPROCANN -->
          <div class="cp__reprocann-wrap">
            <div class="cp__reprocann-label">REPROCANN</div>
            <div class="cp__reprocann-status" :class="`cp__reprocann-status--${data.reprocann_estado}`">
              <span class="cp__reprocann-dot"></span>
              {{ reprocannLabel }}
              <span v-if="data.reprocann_vencimiento" class="cp__reprocann-vto">
                · Vto. {{ formatDate(data.reprocann_vencimiento) }}
              </span>
            </div>
          </div>

          <!-- QR -->
          <div class="cp__qr-section">
            <div class="cp__qr-frame">
              <canvas ref="qrCanvas" class="cp__qr-canvas"></canvas>
            </div>
            <div class="cp__qr-hint">Escanear para verificar</div>
          </div>

        </div>

        <!-- Footer -->
        <div class="cp__footer">
          <span>Emitido {{ formatDate(data.emitido_at) }}</span>
          <span class="cp__footer-verified"><i>✓</i> Verificado</span>
        </div>

      </div>

      <!-- Acciones (no incluidas en PDF) -->
      <div class="cp__actions">
        <button class="cp__btn cp__btn--primary" @click="descargarPDF" :disabled="descargando">
          <DsSpinner v-if="descargando" :size="14" />
          <svg v-else width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>
            <polyline points="7 10 12 15 17 10"/>
            <line x1="12" y1="15" x2="12" y2="3"/>
          </svg>
          {{ descargando ? 'Generando…' : 'Descargar PDF' }}
        </button>
        <button class="cp__btn cp__btn--ghost" @click="imprimir">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="6 9 6 2 18 2 18 9"/>
            <path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/>
            <rect x="6" y="14" width="12" height="8"/>
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

const route      = useRoute()
const estado     = ref('cargando')
const data       = ref(null)
const qrCanvas   = ref(null)
const descargando = ref(false)

const BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api').replace(/\/api\/?$/, '')
const APP_HOST = window.location.origin

async function cargar() {
  try {
    const res = await axios.get(`${BASE_URL}/c/${route.params.token}`)
    data.value   = res.data
    estado.value = 'ok'
    await nextTick()
    generarQR()
  } catch {
    estado.value = 'no_encontrado'
  }
}

function generarQR() {
  if (!qrCanvas.value) return
  QRCode.toCanvas(qrCanvas.value, `${APP_HOST}/c/${route.params.token}`, {
    width: 96, margin: 1,
    color: { dark: '#1b5e20', light: '#ffffff' },
  })
}

async function descargarPDF() {
  descargando.value = true
  const el     = document.getElementById('carnet-card')
  const nombre = `${data.value?.nombre || 'socio'}-${data.value?.numero_socio || ''}`.toLowerCase().replace(/\s+/g, '-')
  await html2pdf().set({
    margin:      0,
    filename:    `carnet-${nombre}.pdf`,
    image:       { type: 'jpeg', quality: 0.98 },
    html2canvas: { scale: 3, useCORS: true, logging: false },
    jsPDF:       { unit: 'mm', format: [90, 148], orientation: 'portrait' },
  }).from(el).save()
  descargando.value = false
}

function imprimir() { window.print() }

const estadoLabel = computed(() =>
  data.value?.estado_membresia === 'activo' ? 'Activo' : 'Baja'
)
const reprocannLabel = computed(() => ({
  vigente:      'Vigente',
  por_vencer:   'Por vencer',
  vencido:      'Vencido',
  sin_registro: 'Sin registro',
}[data.value?.reprocann_estado] ?? '—'))

const formatDate = (d) => d
  ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
  : '—'

onMounted(cargar)
</script>

<style scoped>
* { box-sizing: border-box; }

.cp {
  min-height: 100dvh;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 1rem;
  background: linear-gradient(160deg, #0f2417 0%, #1a3d2e 50%, #0f2417 100%);
  padding: 1.25rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

.cp__loading {
  display: flex; flex-direction: column;
  align-items: center; gap: 1.5rem; color: #a7f3d0;
}
.cp__loading-ico { font-size: 3rem; animation: cp-pulse 2s ease-in-out infinite; }
@keyframes cp-pulse { 0%,100% { opacity: .7; } 50% { opacity: 1; } }

/* Card */
.cp__card {
  width: 100%; max-width: 360px;
  background: #fff; border-radius: 20px; overflow: hidden;
  box-shadow: 0 24px 64px rgba(0,0,0,.4), 0 4px 16px rgba(0,0,0,.2);
}

/* Header */
.cp__header {
  background: linear-gradient(135deg, #0f2417 0%, #1b5e20 60%, #2e7d32 100%);
  padding: 1.25rem 1.5rem;
  display: flex; align-items: center; gap: 1rem;
}
.cp__header-logo-wrap {
  width: 48px; height: 48px; border-radius: 12px;
  background: rgba(255,255,255,.12); display: flex; align-items: center;
  justify-content: center; flex-shrink: 0; overflow: hidden;
}
.cp__header-logo  { width: 100%; height: 100%; object-fit: contain; }
.cp__header-emoji { font-size: 1.5rem; }
.cp__header-club  { font-size: 1rem; font-weight: 800; color: #fff; letter-spacing: -.01em; }
.cp__header-sub   { font-size: .68rem; color: rgba(255,255,255,.6); text-transform: uppercase; letter-spacing: .06em; margin-top: .15rem; }

/* Status banner */
.cp__status-banner {
  display: flex; align-items: center; gap: .6rem;
  padding: .6rem 1.5rem;
  font-size: .78rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em;
}
.cp__status-banner--activo  { background: #dcfce7; color: #15803d; }
.cp__status-banner--inactivo, .cp__status-banner--baja { background: #fee2e2; color: #dc2626; }
.cp__status-dot {
  width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0;
  background: currentColor; animation: cp-blink 2s ease-in-out infinite;
}
@keyframes cp-blink { 0%,100% { opacity: 1; } 50% { opacity: .4; } }

/* Body */
.cp__body { padding: 1.5rem; display: flex; flex-direction: column; gap: 1.25rem; }
.cp__body--center { align-items: center; text-align: center; }

/* Identity */
.cp__nombre { font-size: 1.4rem; font-weight: 900; color: #0f172a; letter-spacing: -.02em; }
.cp__numero { font-size: .82rem; color: #64748b; margin-top: .2rem; font-family: monospace; font-weight: 600; }

/* REPROCANN */
.cp__reprocann-wrap { background: #f8fafc; border-radius: 12px; padding: .875rem 1rem; }
.cp__reprocann-label {
  font-size: .65rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em;
  color: #94a3b8; margin-bottom: .4rem;
}
.cp__reprocann-status {
  display: flex; align-items: center; gap: .5rem;
  font-size: .9rem; font-weight: 700;
}
.cp__reprocann-status--vigente    { color: #15803d; }
.cp__reprocann-status--por_vencer { color: #d97706; }
.cp__reprocann-status--vencido    { color: #dc2626; }
.cp__reprocann-status--sin_registro { color: #94a3b8; }
.cp__reprocann-dot {
  width: 9px; height: 9px; border-radius: 50%;
  flex-shrink: 0; background: currentColor;
}
.cp__reprocann-vto { font-weight: 400; font-size: .8rem; color: #64748b; }

/* QR */
.cp__qr-section { display: flex; flex-direction: column; align-items: center; gap: .5rem; }
.cp__qr-frame {
  background: #fff; border: 2px solid #e2e8f0; border-radius: 12px;
  padding: .75rem; display: inline-flex;
}
.cp__qr-canvas { display: block; }
.cp__qr-hint { font-size: .68rem; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }

/* Error */
.cp__err-ico   { font-size: 3rem; color: #dc2626; margin-bottom: .5rem; }
.cp__err-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin-bottom: .4rem; }
.cp__err-desc  { font-size: .82rem; color: #64748b; }

/* Footer */
.cp__footer {
  background: #f8fafc; border-top: 1px solid #f1f5f9;
  padding: .75rem 1.5rem;
  display: flex; align-items: center; justify-content: space-between;
  font-size: .72rem; color: #94a3b8;
}
.cp__footer-verified { color: #15803d; font-weight: 700; }

/* Actions */
.cp__actions { display: flex; gap: .75rem; width: 100%; max-width: 360px; }
.cp__btn {
  flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: .5rem;
  padding: .75rem; border-radius: 12px; font-size: .875rem; font-weight: 700;
  cursor: pointer; border: none; transition: all .15s;
}
.cp__btn--primary { background: #1b5e20; color: #fff; }
.cp__btn--primary:hover:not(:disabled) { background: #14532d; }
.cp__btn--primary:disabled { opacity: .5; cursor: not-allowed; }
.cp__btn--ghost { background: rgba(255,255,255,.1); color: #fff; border: 1.5px solid rgba(255,255,255,.25); }
.cp__btn--ghost:hover { background: rgba(255,255,255,.18); }

@media print {
  .cp { background: none; padding: 0; }
  .cp__actions { display: none; }
}
</style>
