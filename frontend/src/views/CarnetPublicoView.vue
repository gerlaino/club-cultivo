<template>
  <div class="cp">

    <!-- Cargando -->
    <div v-if="estado === 'cargando'" class="cp__loading">
      <div class="cp__loading-ico">🌿</div>
      <DsSpinner :size="32" />
    </div>

    <!-- No encontrado / inválido -->
    <div v-else-if="estado === 'no_encontrado'" class="cp__card">
      <div class="cp__band">
        <div class="cp__crest"><span class="cp__crest-emoji">🌿</span></div>
        <div class="cp__band-txt">
          <div class="cp__band-club">Carnet de Paciente</div>
          <div class="cp__band-kicker">Credencial digital</div>
        </div>
      </div>
      <div class="cp__error">
        <div class="cp__error-ico">!</div>
        <div class="cp__error-title">Carnet no válido</div>
        <div class="cp__error-desc">No se encontró la credencial, fue revocada o el enlace es incorrecto.</div>
      </div>
    </div>

    <template v-else-if="data">

      <!-- Credencial (capturable por html2pdf) -->
      <div id="carnet-card" class="cp__card">

        <!-- Banda superior -->
        <div class="cp__band">
          <div class="cp__crest">
            <img v-if="data.club?.logo" :src="data.club.logo" :alt="data.club?.nombre" class="cp__crest-logo" />
            <span v-else class="cp__crest-emoji">🌿</span>
          </div>
          <div class="cp__band-txt">
            <div class="cp__band-club">{{ data.club?.nombre || 'Club de Cultivo' }}</div>
            <div class="cp__band-kicker">Carnet de Paciente</div>
          </div>
          <span class="cp__state" :class="`cp__state--${estadoKey}`">
            <span class="cp__state-dot"></span>{{ estadoLabel }}
          </span>
        </div>

        <!-- Cuerpo -->
        <div class="cp__body">

          <!-- Identidad -->
          <div class="cp__identity">
            <span class="cp__eyebrow">Titular</span>
            <div class="cp__name">{{ nombreCompleto }}</div>
            <div class="cp__number">
              <span class="cp__number-label">N.º de paciente</span>
              <span class="cp__number-val">{{ numeroFmt }}</span>
            </div>
          </div>

          <!-- REPROCANN + QR -->
          <div class="cp__grid">
            <div class="cp__reprocann" :class="`cp__reprocann--${data.reprocann_estado}`">
              <div class="cp__reprocann-top">
                <span class="cp__reprocann-label">REPROCANN</span>
                <span class="cp__reprocann-chip">
                  <span class="cp__reprocann-dot"></span>{{ reprocannLabel }}
                </span>
              </div>
              <div class="cp__reprocann-vto">
                <template v-if="data.reprocann_vencimiento">
                  Vence el <strong>{{ formatDate(data.reprocann_vencimiento) }}</strong>
                </template>
                <template v-else>Sin fecha de vencimiento registrada</template>
              </div>
            </div>

            <div class="cp__qr">
              <div class="cp__qr-frame"><canvas ref="qrCanvas" class="cp__qr-canvas"></canvas></div>
              <span class="cp__qr-hint">Escaneá para verificar</span>
            </div>
          </div>

        </div>

        <!-- Pie -->
        <div class="cp__foot">
          <span class="cp__foot-item">Emitido {{ formatDate(data.emitido_at) }}</span>
          <span class="cp__foot-seal"><span class="cp__foot-check">✓</span> Credencial verificada</span>
        </div>

      </div>

      <!-- Acciones (fuera del PDF) -->
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

const route       = useRoute()
const estado      = ref('cargando')
const data        = ref(null)
const qrCanvas    = ref(null)
const descargando = ref(false)

const BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:3001/api').replace(/\/api\/?$/, '')
const APP_HOST = window.location.origin

async function cargar() {
  try {
    // Accept explícito: sin esto, un request con Accept text/html puede caer al SPA
    // (index.html) y devolver un string sin campos → la card salía con todo "undefined".
    // Los datos van bajo /api (la página /c/:token es del SPA; a nivel root el backend
    // no sirve JSON). Ver routes.rb.
    const res = await axios.get(`${BASE_URL}/api/c/${route.params.token}`, {
      headers: { Accept: 'application/json' },
    })
    const d = res.data
    // Guard: solo es un carnet válido si vino un objeto con número de paciente. Si llegó
    // HTML del SPA o un objeto vacío, lo tratamos como no encontrado (nada de "undefined").
    if (!d || typeof d !== 'object' || d.numero_socio == null) {
      estado.value = 'no_encontrado'
      return
    }
    data.value   = d
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
    width: 104, margin: 0,
    color: { dark: '#123524', light: '#ffffff' },
  })
}

async function descargarPDF() {
  descargando.value = true
  const el     = document.getElementById('carnet-card')
  const nombre = `${data.value?.nombre || 'paciente'}-${data.value?.numero_socio || ''}`.toLowerCase().replace(/\s+/g, '-')
  await html2pdf().set({
    margin:      0,
    filename:    `carnet-${nombre}.pdf`,
    image:       { type: 'jpeg', quality: 0.98 },
    html2canvas: { scale: 3, useCORS: true, logging: false, backgroundColor: null },
    jsPDF:       { unit: 'mm', format: [108, 150], orientation: 'portrait' },
  }).from(el).save()
  descargando.value = false
}

function imprimir() { window.print() }

// El backend manda apellido_inicial ya con el punto ("P."). Componemos sin duplicarlo.
const nombreCompleto = computed(() => {
  const n = (data.value?.nombre || '').trim()
  const a = (data.value?.apellido_inicial || '').trim()
  return [n, a].filter(Boolean).join(' ') || 'Paciente'
})

const numeroFmt = computed(() => {
  const id = data.value?.numero_socio
  return id != null ? String(id).padStart(6, '0') : '—'
})

const estadoKey   = computed(() => (data.value?.estado_membresia === 'activo' ? 'activo' : 'baja'))
const estadoLabel = computed(() => (estadoKey.value === 'activo' ? 'Activo' : 'Baja'))

const reprocannLabel = computed(() => ({
  vigente:      'Vigente',
  por_vencer:   'Por vencer',
  vencido:      'Vencido',
  sin_registro: 'Sin registro',
}[data.value?.reprocann_estado] ?? 'Sin registro'))

const formatDate = (d) => d
  ? new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: 'short', year: 'numeric' })
  : '—'

onMounted(cargar)
</script>

<style scoped>
* { box-sizing: border-box; }

.cp {
  min-height: 100dvh;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 1.15rem;
  background:
    radial-gradient(120% 80% at 50% -10%, #1c4a33 0%, transparent 55%),
    linear-gradient(165deg, #0a1c12 0%, #123524 55%, #0a1c12 100%);
  padding: 1.5rem 1.25rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
}

.cp__loading { display: flex; flex-direction: column; align-items: center; gap: 1.4rem; color: #a7f3d0; }
.cp__loading-ico { font-size: 2.8rem; animation: cp-pulse 2s ease-in-out infinite; }
@keyframes cp-pulse { 0%,100% { opacity: .6; } 50% { opacity: 1; } }

/* ── Credencial ─────────────────────────────────────────── */
.cp__card {
  position: relative;
  width: 100%; max-width: 420px;
  background: #fbfbf8;
  border-radius: 22px; overflow: hidden;
  box-shadow: 0 30px 70px rgba(0,0,0,.5), 0 6px 18px rgba(0,0,0,.28);
}

/* Banda superior con textura sutil */
.cp__band {
  position: relative;
  background: linear-gradient(135deg, #0d2a1c 0%, #1b5e20 62%, #2e7d32 100%);
  padding: 1.35rem 1.4rem 1.25rem;
  display: flex; align-items: center; gap: .85rem;
  border-bottom: 2px solid #c9a961;
}
.cp__band::after {
  content: ''; position: absolute; inset: 0; pointer-events: none;
  background:
    radial-gradient(60% 120% at 90% -20%, rgba(201,169,97,.22) 0%, transparent 60%),
    repeating-linear-gradient(115deg, rgba(255,255,255,.035) 0 2px, transparent 2px 9px);
}
.cp__crest {
  position: relative; z-index: 1;
  width: 46px; height: 46px; border-radius: 12px;
  background: rgba(255,255,255,.14); border: 1px solid rgba(201,169,97,.5);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; overflow: hidden;
}
.cp__crest-logo  { width: 100%; height: 100%; object-fit: contain; }
.cp__crest-emoji { font-size: 1.4rem; }
.cp__band-txt    { position: relative; z-index: 1; min-width: 0; flex: 1; }
.cp__band-club   { font-size: 1.02rem; font-weight: 800; color: #fff; letter-spacing: -.01em; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cp__band-kicker { font-size: .62rem; color: rgba(201,169,97,.95); text-transform: uppercase; letter-spacing: .16em; margin-top: .25rem; font-weight: 700; }

/* Chip de estado */
.cp__state {
  position: relative; z-index: 1;
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .28rem .6rem; border-radius: 999px; flex-shrink: 0;
  font-size: .6rem; font-weight: 800; text-transform: uppercase; letter-spacing: .07em;
}
.cp__state--activo { background: rgba(220,252,231,.95); color: #15803d; }
.cp__state--baja   { background: rgba(254,226,226,.95); color: #b91c1c; }
.cp__state-dot { width: 6px; height: 6px; border-radius: 50%; background: currentColor; }

/* Cuerpo */
.cp__body { padding: 1.4rem; display: flex; flex-direction: column; gap: 1.25rem; }

.cp__eyebrow { font-size: .6rem; font-weight: 700; text-transform: uppercase; letter-spacing: .14em; color: #9aa79f; }
.cp__name {
  font-size: 1.5rem; font-weight: 800; color: #12251b; letter-spacing: -.025em;
  line-height: 1.12; margin-top: .3rem; text-wrap: balance;
}
.cp__number { display: flex; align-items: baseline; gap: .5rem; margin-top: .6rem; }
.cp__number-label { font-size: .66rem; font-weight: 600; color: #9aa79f; text-transform: uppercase; letter-spacing: .05em; }
.cp__number-val {
  font-family: ui-monospace, 'SFMono-Regular', Menlo, monospace;
  font-size: 1.02rem; font-weight: 700; color: #1b5e20; letter-spacing: .08em;
}

/* Grid REPROCANN + QR */
.cp__grid { display: grid; grid-template-columns: 1fr auto; gap: .9rem; align-items: stretch; }

.cp__reprocann {
  background: #f3f6f2; border: 1px solid #e4ebe3; border-left: 3px solid var(--c-slate-400);
  border-radius: 13px; padding: .85rem .95rem;
  display: flex; flex-direction: column; justify-content: center; gap: .5rem; min-width: 0;
}
.cp__reprocann--vigente    { border-left-color: #16a34a; background: #f0faf3; }
.cp__reprocann--por_vencer { border-left-color: #d97706; background: #fdf7ee; }
.cp__reprocann--vencido    { border-left-color: #dc2626; background: #fdf1f1; }
.cp__reprocann-top { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.cp__reprocann-label { font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .1em; color: #7c8a80; }
.cp__reprocann-chip {
  display: inline-flex; align-items: center; gap: .32rem;
  font-size: .74rem; font-weight: 800; letter-spacing: -.01em; color: var(--c-slate-500);
}
.cp__reprocann--vigente    .cp__reprocann-chip { color: #15803d; }
.cp__reprocann--por_vencer .cp__reprocann-chip { color: #b45309; }
.cp__reprocann--vencido    .cp__reprocann-chip { color: #dc2626; }
.cp__reprocann-dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; flex-shrink: 0; }
.cp__reprocann-vto { font-size: .74rem; color: #56635b; line-height: 1.35; }
.cp__reprocann-vto strong { color: #12251b; font-weight: 700; }

/* QR */
.cp__qr { display: flex; flex-direction: column; align-items: center; gap: .4rem; }
.cp__qr-frame { background: #fff; border: 1px solid #e4ebe3; border-radius: 12px; padding: .55rem; display: inline-flex; box-shadow: inset 0 0 0 3px #fff, 0 1px 2px rgba(0,0,0,.05); }
.cp__qr-canvas { display: block; }
.cp__qr-hint { font-size: .58rem; color: #9aa79f; text-transform: uppercase; letter-spacing: .05em; text-align: center; }

/* Pie */
.cp__foot {
  border-top: 1px dashed #dbe3da; margin: 0 1.4rem; padding: .85rem 0;
  display: flex; align-items: center; justify-content: space-between;
  font-size: .68rem; color: #9aa79f;
}
.cp__foot-seal { display: inline-flex; align-items: center; gap: .3rem; color: #15803d; font-weight: 700; }
.cp__foot-check {
  display: inline-flex; align-items: center; justify-content: center;
  width: 14px; height: 14px; border-radius: 50%; background: #15803d; color: #fff; font-size: .6rem;
}

/* Error */
.cp__error { padding: 2.5rem 1.5rem; display: flex; flex-direction: column; align-items: center; text-align: center; gap: .5rem; }
.cp__error-ico { width: 46px; height: 46px; border-radius: 50%; background: #fdecec; color: #dc2626; display: flex; align-items: center; justify-content: center; font-size: 1.6rem; font-weight: 800; margin-bottom: .3rem; }
.cp__error-title { font-size: 1.1rem; font-weight: 800; color: #12251b; }
.cp__error-desc  { font-size: .82rem; color: var(--c-slate-500); max-width: 24ch; line-height: 1.45; }

/* Acciones */
.cp__actions { display: flex; gap: .7rem; width: 100%; max-width: 420px; }
.cp__btn {
  flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: .5rem;
  padding: .8rem; border-radius: 13px; font-size: .875rem; font-weight: 700;
  cursor: pointer; border: none; transition: transform .12s, background .15s, box-shadow .15s;
}
.cp__btn:active { transform: translateY(1px); }
.cp__btn--primary { background: #1b5e20; color: #fff; box-shadow: 0 4px 14px rgba(27,94,32,.4); }
.cp__btn--primary:hover:not(:disabled) { background: #14532d; }
.cp__btn--primary:disabled { opacity: .55; cursor: not-allowed; box-shadow: none; }
.cp__btn--ghost { background: rgba(255,255,255,.08); color: #eafff0; border: 1.5px solid rgba(201,169,97,.4); }
.cp__btn--ghost:hover { background: rgba(255,255,255,.15); }

@media print {
  .cp { background: none; padding: 0; min-height: 0; }
  .cp__actions { display: none; }
  .cp__card { box-shadow: none; }
}
</style>
