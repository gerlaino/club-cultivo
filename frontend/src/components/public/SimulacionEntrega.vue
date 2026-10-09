<template>
  <!-- LA ENTREGA, simulada en el teléfono de quien reparte (Germán, 9-oct-2026): la moto va por el
       mapa a la parada 2, el paciente firma, queda entregada y cobrada, el efectivo a rendir sube y
       sigue a la parada 3. En bucle mientras está en pantalla; con «reducir movimiento», quieta. -->
  <div ref="raiz" class="se">
    <div class="se__estado"><span>{{ estado }}</span><span>{{ hora }}</span></div>
    <div class="se__mapa">
      <svg viewBox="0 0 280 92" aria-hidden="true">
        <path class="se__calle" d="M0 70 H280 M60 0 V92 M150 0 V92 M0 24 H280 M228 0 V92" />
        <path ref="ruta" class="se__ruta" d="M28 70 C 70 70, 70 24, 120 24 S 190 70, 228 46" />
        <circle class="se__parada se__parada--ok" cx="28" cy="70" r="6" />
        <circle class="se__parada" :class="{ 'se__parada--ok': paso >= 2 }" cx="120" cy="24" r="6" />
        <circle class="se__parada" cx="228" cy="46" r="6" />
        <circle class="se__moto" :cx="moto.x" :cy="moto.y" r="7" />
      </svg>
    </div>

    <div class="se__fila"><span class="se__num se__num--ok">1</span><div class="se__crece"><b>Paciente N.º 0231</b><small>Palermo · cobrado</small></div><b class="se__ok">Entregado</b></div>
    <div class="se__fila" :class="{ 'se__fila--ahora': paso < 2 }">
      <span class="se__num" :class="paso >= 2 ? 'se__num--ok' : 'se__num--ahora'">2</span>
      <div class="se__crece"><b>Paciente N.º 0145</b><small>Villa Crespo · contra entrega $ 18.000</small></div>
      <b :class="paso >= 2 ? 'se__ok' : 'se__ahora'">{{ ['En camino', 'Firmando', 'Entregado', 'Entregado'][paso] }}</b>
    </div>

    <div v-if="paso === 1" class="se__firma" :class="{ 'se__firma--on': firmando }">
      <small>Firma del paciente · cobro $ 18.000 en efectivo</small>
      <svg viewBox="0 0 240 46" aria-hidden="true"><path class="se__trazo" d="M10 32 C 22 8, 30 40, 42 22 S 58 10, 64 30 C 70 42, 80 12, 92 24 S 110 36, 120 18 C 128 6, 136 38, 150 26 S 176 20, 186 30 L 228 22" /></svg>
    </div>
    <div v-else-if="paso >= 2" class="se__listo">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" aria-hidden="true"><path d="M5 12l5 5L20 7" /></svg>
      Entregado y firmado · 18:42
    </div>

    <div class="se__fila">
      <span class="se__num" :class="paso === 3 ? 'se__num--ahora' : 'se__num--gris'">3</span>
      <div class="se__crece"><b>Paciente N.º 0098</b><small>Almagro · pagado</small></div>
      <b :class="paso === 3 ? 'se__ahora' : 'se__gris'">{{ paso === 3 ? 'En camino' : 'Pendiente' }}</b>
    </div>
    <div class="se__fila"><span>Efectivo a rendir a Javier</span><b :class="{ 'se__ok': paso >= 2 }">{{ paso >= 2 ? '$ 66.000' : '$ 48.000' }}</b></div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'

// paso: 0 en camino a la 2 · 1 firmando · 2 entregada · 3 en camino a la 3
const paso = ref(0)
const firmando = ref(false)
const moto = ref({ x: 28, y: 70 })
const ruta = ref(null)
const raiz = ref(null)
const estado = computed(() => ['En camino a la parada 2', 'Llegaste · Villa Crespo', 'Entregada en Villa Crespo', 'En camino a la parada 3'][paso.value])
const hora = computed(() => ['18:31', '18:40', '18:42', '18:43'][paso.value])

let timers = []
let raf = null
let corriendo = false
let observador = null
const espera = (ms, fn) => timers.push(setTimeout(fn, ms))

function viajar (desde, hasta, ms, fin) {
  const camino = ruta.value
  const largo = camino.getTotalLength()
  const t0 = performance.now()
  const avanzar = (t) => {
    const k = Math.min(1, (t - t0) / ms)
    const e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2
    const p = camino.getPointAtLength(largo * (desde + (hasta - desde) * e))
    moto.value = { x: p.x, y: p.y }
    if (k < 1) raf = requestAnimationFrame(avanzar)
    else fin()
  }
  raf = requestAnimationFrame(avanzar)
}

function vuelta () {
  paso.value = 0
  firmando.value = false
  moto.value = { x: 28, y: 70 }
  viajar(0, 0.5, 2200, () => {
    paso.value = 1
    espera(120, () => { firmando.value = true })
    espera(1900, () => {
      paso.value = 2
      espera(1300, () => {
        paso.value = 3
        viajar(0.5, 1, 2000, () => espera(1800, vuelta))
      })
    })
  })
}

function arrancar () { if (corriendo) return; corriendo = true; vuelta() }
function frenar () {
  corriendo = false
  timers.forEach(clearTimeout); timers = []
  if (raf) cancelAnimationFrame(raf); raf = null
}

onMounted(() => {
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return
  if (!('IntersectionObserver' in window)) { arrancar(); return }
  // Corre sólo mientras se ve: fuera de pantalla no gasta batería.
  observador = new IntersectionObserver((entradas) => {
    if (entradas.some(e => e.isIntersecting)) arrancar()
    else frenar()
  }, { threshold: 0.3 })
  observador.observe(raiz.value)
})
onBeforeUnmount(() => { frenar(); observador?.disconnect() })
</script>

<style scoped>
.se { display: flex; flex-direction: column; gap: 7px; font-size: 12px; }
.se__estado { font-size: 11px; font-weight: 700; color: #1A3D2E; display: flex; justify-content: space-between; }
.se__mapa { background: #E8F0EB; border-radius: 10px; height: 92px; overflow: hidden; }
.se__mapa svg { width: 100%; height: 100%; display: block; }
.se__calle { fill: none; stroke: #fff; stroke-width: 7; stroke-linecap: round; }
.se__ruta { fill: none; stroke: #2D4A3E; stroke-width: 2.5; stroke-dasharray: 5 5; }
.se__parada { fill: #fff; stroke: #2D4A3E; stroke-width: 2.5; transition: fill .3s; }
.se__parada--ok { fill: #2D4A3E; }
.se__moto { fill: #B45309; stroke: #fff; stroke-width: 2.5; }
.se__fila { background: #fff; border: 1px solid #E1E8E3; border-radius: 10px; padding: 9px 10px; display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.se__fila--ahora { border-color: #B45309; }
.se__crece { flex: 1; display: flex; flex-direction: column; min-width: 0; }
.se__fila small { font-size: 10.5px; color: #3A3F44; }
.se__num { width: 22px; height: 22px; border-radius: 50%; display: grid; place-items: center; font-size: 11px; font-weight: 700; flex-shrink: 0; color: #fff; }
.se__num--ok { background: #2D4A3E; }
.se__num--ahora { background: #B45309; }
.se__num--gris { background: #6B7280; }
.se__ok { color: #2D4A3E; }
.se__ahora { color: #B45309; }
.se__gris { color: #6B7280; }
.se__firma { background: #fff; border: 1.5px dashed #9CA3AF; border-radius: 10px; padding: 6px 10px 4px; display: grid; gap: 2px; animation: se-entra .35s ease both; }
.se__firma small { font-size: 10px; color: #3A3F44; }
.se__firma svg { width: 100%; height: 46px; }
.se__trazo { fill: none; stroke: #1A1D1F; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; stroke-dasharray: 420; stroke-dashoffset: 420; }
.se__firma--on .se__trazo { transition: stroke-dashoffset 1.4s ease; stroke-dashoffset: 0; }
.se__listo { background: #E8F0EB; border: 1.5px solid #2D4A3E; color: #1A3D2E; border-radius: 10px; padding: 9px 10px; font-weight: 700; display: flex; align-items: center; gap: 6px; animation: se-entra .35s ease both; }
@keyframes se-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
</style>
