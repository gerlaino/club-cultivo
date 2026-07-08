<script setup>
// Puerta del evento (Capa 4): check-in por QR o código manual, con aforo en vivo y anti-duplicado.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRoute } from 'vue-router'
import QrScanner from 'qr-scanner'
import { getPuertaEstado, checkinEntrada } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const route = useRoute()
const toast = useToast()
const barId = route.params.barId
const evId  = route.params.eventoId

const aforo    = ref({ adentro: 0, vendidas: 0, aforo: null, no_show: 0 })
const ultimo   = ref(null)  // { resultado, mensaje, entrada }
const feed     = ref([])    // últimos check-ins
const manual   = ref('')
const videoEl  = ref(null)
const scanning = ref(false)
let scanner = null
let ultimoCodigo = null
let ultimoAt = 0

const RES_CLS = { ok: 'ok', duplicada: 'dup', invalida: 'bad', anulada: 'bad', aforo: 'warn' }

function pct() {
  if (!aforo.value.aforo) return aforo.value.vendidas ? Math.round(aforo.value.adentro / aforo.value.vendidas * 100) : 0
  return Math.min(100, Math.round(aforo.value.adentro / aforo.value.aforo * 100))
}

async function cargarEstado() {
  try { const { data } = await getPuertaEstado(barId, evId); aforo.value = data } catch {}
}

async function procesar(codigo) {
  const cod = (codigo || '').toString().trim()
  if (!cod) return
  // De un QR con URL, tomamos el último segmento; si es el código pelado, lo usamos tal cual.
  const limpio = cod.includes('/') ? cod.split('/').filter(Boolean).pop() : cod
  const ahora = Date.now()
  if (limpio === ultimoCodigo && ahora - ultimoAt < 2500) return // evita re-escaneo del mismo
  ultimoCodigo = limpio; ultimoAt = ahora
  try {
    const { data } = await checkinEntrada(barId, evId, limpio)
    aplicar(data)
  } catch (e) {
    aplicar(e?.response?.data || { resultado: 'bad', mensaje: 'Error de red' })
  }
}

function aplicar(data) {
  ultimo.value = data
  if (data.aforo) aforo.value = data.aforo
  feed.value.unshift({ ...data, at: new Date().toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) })
  feed.value = feed.value.slice(0, 12)
  if (data.resultado === 'ok') toast.success('Ingreso válido')
}

async function checkManual() {
  if (!manual.value.trim()) return
  await procesar(manual.value)
  manual.value = ''
}

async function iniciarScanner() {
  try {
    if (!(await QrScanner.hasCamera())) { toast.warning('No hay cámara disponible'); return }
    scanner = new QrScanner(videoEl.value, (r) => procesar(r.data || r), {
      highlightScanRegion: true, highlightCodeOutline: true, preferredCamera: 'environment',
    })
    await scanner.start()
    scanning.value = true
  } catch {
    toast.warning('No se pudo abrir la cámara — usá el código manual')
  }
}
function detener() { scanner?.stop(); scanner?.destroy?.(); scanner = null; scanning.value = false }

onMounted(cargarEstado)
onBeforeUnmount(detener)
</script>

<template>
  <div class="pt">
    <header class="pt__head">
      <RouterLink :to="`/bar/${barId}/eventos/${evId}`" class="pt__back">← Evento</RouterLink>
      <h1>Puerta</h1>
    </header>

    <!-- Aforo -->
    <div class="pt__aforo">
      <div class="pt__aforo-num"><strong>{{ aforo.adentro }}</strong><span>/ {{ aforo.aforo || aforo.vendidas }} adentro</span></div>
      <div class="pt__track"><i :style="{ width: pct() + '%' }" :class="{ full: aforo.aforo && aforo.adentro >= aforo.aforo }"></i></div>
      <div class="pt__aforo-meta">
        <span>Vendidas <b>{{ aforo.vendidas }}</b></span>
        <span>No-show <b>{{ aforo.no_show }}</b></span>
      </div>
    </div>

    <!-- Último resultado -->
    <div v-if="ultimo" class="pt__result" :class="RES_CLS[ultimo.resultado] || 'bad'">
      <div class="pt__result-ic">{{ ultimo.resultado === 'ok' ? '✓' : (ultimo.resultado === 'duplicada' ? '↻' : '✕') }}</div>
      <div>
        <b>{{ ultimo.entrada?.comprador || ultimo.entrada?.tipo || 'Entrada' }}</b>
        <span>{{ ultimo.mensaje }}</span>
      </div>
    </div>

    <!-- Scanner -->
    <div class="pt__scan">
      <video ref="videoEl" class="pt__video" :class="{ on: scanning }"></video>
      <button v-if="!scanning" class="btn btn--primary btn--lg" @click="iniciarScanner">📷 Escanear QR</button>
      <button v-else class="btn btn--lg" @click="detener">Detener cámara</button>
    </div>

    <!-- Manual -->
    <form class="pt__manual" @submit.prevent="checkManual">
      <input v-model="manual" class="inp" placeholder="…o ingresá el código a mano" />
      <button type="submit" class="btn btn--primary">Validar</button>
    </form>

    <!-- Feed -->
    <div v-if="feed.length" class="pt__feed">
      <h2>Últimos ingresos</h2>
      <ul>
        <li v-for="(f, i) in feed" :key="i" :class="RES_CLS[f.resultado] || 'bad'">
          <span class="pt__feed-ic">{{ f.resultado === 'ok' ? '✓' : (f.resultado === 'duplicada' ? '↻' : '✕') }}</span>
          <span class="pt__feed-txt">{{ f.entrada?.comprador || f.entrada?.tipo || 'Entrada' }} — {{ f.mensaje }}</span>
          <span class="pt__feed-at">{{ f.at }}</span>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.pt { padding: var(--sp-5, 20px); max-width: 520px; margin: 0 auto; }
.pt__head { display: flex; align-items: center; gap: 14px; margin-bottom: var(--sp-4, 16px); }
.pt__back { font-size: var(--fs-13, 13px); color: var(--c-leaf-700, #2f6b3d); text-decoration: none; font-weight: 600; }
.pt__head h1 { font-size: var(--fs-22, 22px); font-weight: 700; color: var(--c-ink-900); margin: 0; }

.pt__aforo { background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg, 14px); padding: var(--sp-4, 16px); }
.pt__aforo-num { display: flex; align-items: baseline; gap: 8px; }
.pt__aforo-num strong { font-size: 2.6rem; font-weight: 720; letter-spacing: -.03em; color: var(--c-ink-900); }
.pt__aforo-num span { color: var(--c-ink-400); }
.pt__track { height: 10px; background: var(--c-ink-50, #f6f7f5); border: 1px solid var(--c-ink-100); border-radius: 6px; overflow: hidden; margin: 10px 0; }
.pt__track i { display: block; height: 100%; background: var(--c-leaf-500, #40915a); border-radius: 6px; transition: width .3s; }
.pt__track i.full { background: var(--c-rust-600, #b23b2e); }
.pt__aforo-meta { display: flex; gap: 18px; font-size: var(--fs-13, 13px); color: var(--c-ink-500); }
.pt__aforo-meta b { color: var(--c-ink-900); }

.pt__result { display: flex; align-items: center; gap: 14px; padding: 14px 16px; border-radius: var(--r-lg, 14px); margin: var(--sp-3, 12px) 0; }
.pt__result-ic { width: 42px; height: 42px; border-radius: 50%; display: grid; place-items: center; font-size: 1.4rem; color: #fff; flex-shrink: 0; }
.pt__result b { display: block; color: var(--c-ink-900); }
.pt__result span { font-size: var(--fs-13, 13px); color: var(--c-ink-600); }
.pt__result.ok   { background: var(--c-leaf-50, #e7f0e5); } .pt__result.ok .pt__result-ic { background: var(--c-leaf-700, #2f6b3d); }
.pt__result.dup  { background: var(--c-amber-100, #f6ecd8); } .pt__result.dup .pt__result-ic { background: var(--c-amber-500, #b7791f); }
.pt__result.bad  { background: var(--c-rust-100, #f6e5e2); } .pt__result.bad .pt__result-ic { background: var(--c-rust-600, #b23b2e); }
.pt__result.warn { background: var(--c-amber-100, #f6ecd8); } .pt__result.warn .pt__result-ic { background: var(--c-amber-500, #b7791f); }

.pt__scan { display: flex; flex-direction: column; align-items: center; gap: 12px; margin: var(--sp-4, 16px) 0; }
.pt__video { width: 100%; max-width: 320px; aspect-ratio: 1; border-radius: var(--r-lg, 14px); background: #000; display: none; object-fit: cover; }
.pt__video.on { display: block; }
.pt__manual { display: flex; gap: 8px; }
.pt__manual .inp { flex: 1; }

.pt__feed { margin-top: var(--sp-5, 20px); }
.pt__feed h2 { font-size: var(--fs-14, 14px); text-transform: uppercase; letter-spacing: .05em; color: var(--c-ink-400); margin: 0 0 10px; }
.pt__feed ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }
.pt__feed li { display: flex; align-items: center; gap: 10px; padding: 8px 12px; border-radius: var(--r-sm, 8px); background: var(--c-paper, #fff); border: 1px solid var(--c-ink-100); font-size: var(--fs-13, 13px); }
.pt__feed-ic { width: 20px; height: 20px; border-radius: 50%; display: grid; place-items: center; color: #fff; font-size: .7rem; flex-shrink: 0; }
.pt__feed li.ok .pt__feed-ic { background: var(--c-leaf-700, #2f6b3d); }
.pt__feed li.dup .pt__feed-ic, .pt__feed li.warn .pt__feed-ic { background: var(--c-amber-500, #b7791f); }
.pt__feed li.bad .pt__feed-ic { background: var(--c-rust-600, #b23b2e); }
.pt__feed-txt { flex: 1; color: var(--c-ink-700); }
.pt__feed-at { color: var(--c-ink-400); font-variant-numeric: tabular-nums; }

.inp { padding: 10px 12px; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm, 8px); font-size: var(--fs-15, 15px); background: var(--c-paper, #fff); color: var(--c-ink-900); }
.btn { border: 1px solid var(--c-ink-200); background: var(--c-paper, #fff); color: var(--c-ink-800); border-radius: var(--r-sm, 8px); padding: 10px 16px; font-size: var(--fs-14, 14px); font-weight: 600; cursor: pointer; }
.btn--lg { padding: 13px 22px; font-size: var(--fs-15, 15px); }
.btn--primary { background: var(--c-leaf-700, #2f6b3d); border-color: var(--c-leaf-700, #2f6b3d); color: #fff; }
</style>
