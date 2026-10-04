<template>
  <div ref="raiz" class="pc" :class="{ 'pc--portada': portada }">
    <div class="pc__escena">
      <!-- El piso y la planta. Las 7 fotos están apiladas; se ven, a lo sumo, dos a la vez (la que
           se va y la que llega). -->
      <div class="pc__piso" aria-hidden="true"></div>
      <div class="pc__planta" role="img" :aria-label="`Una planta en el día ${dia}: ${fase.nombre}`">
        <span class="pc__sombra" aria-hidden="true"></span>
        <img v-for="(e, i) in ETAPAS" :key="e.src" :src="e.src" alt="" class="pc__foto" draggable="false"
             :style="{ opacity: opacidades[i] }" :fetchpriority="i < 2 ? 'high' : 'low'" decoding="async" />
      </div>

      <!-- Al final, el cogollo seco de cerca -->
      <Transition name="pc-lupa">
        <figure v-if="dia >= 84" class="pc__lupa">
          <img src="/planta/cogollo.webp" alt="Un cogollo seco y curado, de cerca" />
          <figcaption>64 g · cogollo seco</figcaption>
        </figure>
      </Transition>

      <!-- Lo que dice la lámina: el día y la fase, grandes. -->
      <div class="pc__dia" aria-live="polite">
        <span class="pc__dia-n">Día {{ dia }}</span>
        <span class="pc__dia-fase">{{ fase.nombre }}</span>
      </div>

      <!-- Lo que anotó la app ese día. -->
      <Transition name="pc-nota" mode="out-in">
        <div :key="evento.dia" class="pc__nota">
          <span class="pc__nota-ico" aria-hidden="true"><component :is="evento.ico" :size="18" :stroke-width="1.8" /></span>
          <div class="pc__nota-txt">
            <span class="pc__nota-h">En la app · día {{ evento.dia }}</span>
            <span class="pc__nota-t">{{ evento.texto }}</span>
          </div>
        </div>
      </Transition>
    </div>

    <!-- El control: arrastrar los días, o mirarla crecer. -->
    <div class="pc__control">
      <button type="button" class="pc__play" :aria-label="reproduciendo ? 'Pausar' : (dia >= MAX ? 'Ver crecer de nuevo' : 'Ver crecer')" @click="alternar">
        <svg v-if="reproduciendo" width="14" height="14" viewBox="0 0 14 14" aria-hidden="true"><rect x="2" y="1" width="3.5" height="12" rx="1"/><rect x="8.5" y="1" width="3.5" height="12" rx="1"/></svg>
        <svg v-else-if="dia >= MAX" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/></svg>
        <svg v-else width="14" height="14" viewBox="0 0 14 14" aria-hidden="true"><path d="M3 1.5v11l9-5.5z"/></svg>
      </button>
      <div class="pc__riel">
        <input v-model.number="dia" type="range" min="0" :max="MAX" step="1" class="pc__rango"
               :style="{ '--avance': `${(dia / MAX) * 100}%` }" aria-label="Día del ciclo" @pointerdown="pausar" @keydown="pausar" />
        <div class="pc__marcas" aria-hidden="true">
          <button v-for="f in MARCAS" :key="f.nombre" type="button" tabindex="-1" class="pc__marca"
                  :class="{ 'pc__marca--on': faseMarca === f.nombre }" :style="{ left: `${((f.en ?? f.desde) / MAX) * 100}%` }"
                  @click="pausar(); dia = f.en ?? f.desde">{{ f.corto }}</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
// LA PLANTA QUE CRECE: de la semilla al cogollo seco. Se reproduce sola la primera vez que aparece
// en pantalla y después se maneja a mano (deslizador o etiquetas de fase). Cada etapa trae la
// tarjeta «En la app»: lo que la app anotó ese día. La idea es que se entienda qué hace la app sin
// leer nada, y que den ganas de probarla.
//
// Son 7 fotos fotorrealistas de la MISMA planta en la misma maceta (generadas con IA por Germán,
// 4-oct-2026), recortadas sin fondo y alineadas para que la maceta quede idéntica en todas
// (`public/planta/01..07.webp`). Entre una etapa y la siguiente se funden: así se la ve crecer.
// Antes era un dibujo hecho en código y no llegaba a parecer una planta de verdad.
//
// `portada`: la planta ocupa la portada entera, de borde a borde, con el texto de la página encima
// a la izquierda. Sin `portada`, una lámina angosta (el teléfono).
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { Bean, Sprout, Droplet, Droplets, FlaskConical, Scissors, BellRing, Camera, Archive } from 'lucide-vue-next'

defineProps({ portada: { type: Boolean, default: false } })
const MAX = 90

// Qué foto corresponde a qué día del ciclo.
const ETAPAS = [
  { dia: 2,  src: '/planta/01.webp' },
  { dia: 9,  src: '/planta/02.webp' },
  { dia: 18, src: '/planta/03.webp' },
  { dia: 32, src: '/planta/04.webp' },
  { dia: 42, src: '/planta/05.webp' },
  { dia: 58, src: '/planta/06.webp' },
  { dia: 78, src: '/planta/07.webp' },
]

// `marca`: las que llevan etiqueta bajo el deslizador (todas no entran sin pisarse).
const FASES = [
  { nombre: 'Semilla',       corto: 'Semilla',    desde: 0,  marca: true },
  { nombre: 'Germinación',   corto: 'Germina',    desde: 3 },
  { nombre: 'Vegetativo',    corto: 'Vegetativo', desde: 12, marca: true, en: 24 }, // la etiqueta, a mitad de la fase
  { nombre: 'Prefloración',  corto: 'Pre',        desde: 38 },
  { nombre: 'Floración',     corto: 'Floración',  desde: 50, marca: true },
  { nombre: 'Cosecha',       corto: 'Cosecha',    desde: 78, marca: true },
  { nombre: 'Al frasco',     corto: 'Frasco',     desde: 86 },
]
const MARCAS = FASES.filter(f => f.marca)
const EVENTOS = [
  { dia: 0,  ico: Bean,         texto: 'Sembraste una King’s Juice (auto)' },
  { dia: 4,  ico: Sprout,       texto: 'Germinó: asomó el primer brote' },
  { dia: 9,  ico: Droplet,      texto: 'Primer riego · 150 ml' },
  { dia: 16, ico: Droplets,     texto: 'Riego 0,4 L · pH 6,2 · EC 0,6' },
  { dia: 24, ico: FlaskConical, texto: 'Primeros nutrientes de crecimiento · EC 1,0' },
  { dia: 31, ico: Droplets,     texto: 'Riego 1 L · pH 6,3 · EC 1,2' },
  { dia: 40, ico: BellRing,     texto: 'Aviso: asoman los primeros pistilos' },
  { dia: 47, ico: FlaskConical, texto: 'Nutrientes de floración · EC 1,4' },
  { dia: 58, ico: Camera,       texto: 'Foto de la semana 9: la cola engorda' },
  { dia: 70, ico: BellRing,     texto: 'Tricomas lechosos: se acerca la cosecha' },
  { dia: 79, ico: Scissors,     texto: 'Cosechaste: 312 g en húmedo' },
  { dia: 86, ico: Archive,      texto: 'Al frasco: 64 g secos, a curar' },
]

const dia = ref(0)
const fase = computed(() => [...FASES].reverse().find(f => dia.value >= f.desde))
const faseMarca = computed(() => [...MARCAS].reverse().find(f => dia.value >= f.desde).nombre)
const evento = computed(() => [...EVENTOS].reverse().find(e => dia.value >= e.dia))

// Opacidad de cada foto: entre dos etapas, la que llega aparece en la segunda mitad del tramo (un
// fundido corto se lee como crecimiento; uno largo, como dos plantas superpuestas).
const suave = (t) => { const x = Math.max(0, Math.min(1, t)); return x * x * (3 - 2 * x) }
const opacidades = computed(() => {
  const d = dia.value
  const op = ETAPAS.map(() => 0)
  const k = ETAPAS.findIndex(e => e.dia > d)
  if (k === -1) { op[ETAPAS.length - 1] = 1; return op }
  if (k === 0) { op[0] = 1; return op }
  const a = ETAPAS[k - 1].dia
  const b = ETAPAS[k].dia
  op[k - 1] = 1
  op[k] = suave(((d - a) / (b - a) - 0.4) / 0.6)
  return op
})

// ── Reproducción ─────────────────────────────────────────
const raiz = ref(null)
const reproduciendo = ref(false)
const DURACION_MS = 16000
let raf = null
let ultimo = 0
let acumulado = 0
let observador = null

function paso (t) {
  if (!reproduciendo.value) return
  if (ultimo) acumulado += ((t - ultimo) / DURACION_MS) * MAX
  ultimo = t
  if (acumulado >= 1) {
    const avance = Math.floor(acumulado)
    acumulado -= avance
    dia.value = Math.min(MAX, dia.value + avance)
  }
  if (dia.value >= MAX) { reproduciendo.value = false; return }
  raf = requestAnimationFrame(paso)
}
function reproducir () {
  if (dia.value >= MAX) dia.value = 0
  reproduciendo.value = true
  ultimo = 0
  acumulado = 0
  raf = requestAnimationFrame(paso)
}
function pausar () { reproduciendo.value = false; cancelAnimationFrame(raf) }
function alternar () { reproduciendo.value ? pausar() : reproducir() }

onMounted(() => {
  // Las fotos se piden todas de entrada: si llegan recién al deslizar, el fundido parpadea.
  for (const e of ETAPAS) { const im = new Image(); im.src = e.src }
  const quieto = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  if (quieto) { dia.value = 64; return }
  // Arranca sola la primera vez que se ve, no antes (en el teléfono puede estar más abajo).
  observador = new IntersectionObserver((entradas) => {
    if (entradas.some(e => e.isIntersecting)) { reproducir(); observador.disconnect() }
  }, { threshold: 0.35 })
  if (raiz.value) observador.observe(raiz.value)
})
onBeforeUnmount(() => { pausar(); observador?.disconnect() })
</script>

<style scoped>
.pc { display: flex; flex-direction: column; gap: 14px; }

/* ── Escena angosta (teléfono): la foto, con el piso abajo ── */
.pc__escena { position: relative; aspect-ratio: 900 / 1100; }
.pc__piso { position: absolute; left: -16px; right: -16px; bottom: 0; height: 4%; border-top: 1px solid color-mix(in srgb, var(--hb-tierra) 45%, transparent); background: linear-gradient(color-mix(in srgb, var(--hb-tierra) 14%, transparent), transparent); }
.pc__planta { position: absolute; inset: 0; user-select: none; }
.pc__foto { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: contain; object-position: bottom center; pointer-events: none; will-change: opacity; }
/* Sombra propia, igual para todas las fotos: la maceta ocupa un tercio del ancho, al centro. */
.pc__sombra { position: absolute; left: 30%; right: 30%; bottom: 1.4%; height: 3%; border-radius: 50%; background: radial-gradient(closest-side, rgb(21 48 31 / .28), transparent); }

.pc__dia { position: absolute; top: 4px; left: 6px; display: flex; flex-direction: column; gap: 2px; pointer-events: none; }
.pc__dia-n { font: 600 2.1rem/1 var(--hb-serif); color: var(--hb-tinta); font-variant-numeric: tabular-nums; letter-spacing: -.02em; }
.pc__dia-fase { font: 500 12px var(--hb-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--hb-verde); }

/* El cogollo seco, en una lupa. */
.pc__lupa { position: absolute; top: 8%; right: 2%; width: 34%; margin: 0; display: flex; flex-direction: column; align-items: center; gap: 8px; }
.pc__lupa img { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 50%; border: 2px solid var(--hb-papel-claro); box-shadow: 0 0 0 1px var(--hb-tinta), 0 18px 40px -18px rgb(21 48 31 / .6); background: var(--hb-salvia-suave); }
.pc__lupa figcaption { font: 600 11px var(--hb-mono); color: var(--hb-verde); background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); border-radius: 99px; padding: 3px 10px; white-space: nowrap; }
.pc-lupa-enter-active, .pc-lupa-leave-active { transition: opacity .5s, transform .5s cubic-bezier(.2,.7,.2,1); }
.pc-lupa-enter-from, .pc-lupa-leave-to { opacity: 0; transform: scale(.85); }

/* La tarjeta «En la app»: el mismo verde oscuro que la ficha del lote en el teléfono. */
.pc__nota {
  position: absolute; left: -10px; bottom: 6%; max-width: 78%;
  display: flex; gap: 10px; align-items: center;
  background: var(--hb-bosque); color: var(--hb-papel-claro);
  border-radius: 14px; padding: 10px 14px 10px 10px;
  box-shadow: 0 14px 30px -12px rgb(16 40 28 / .55);
}
.pc__nota-ico { width: 34px; height: 34px; flex-shrink: 0; display: grid; place-items: center; background: rgb(255 255 255 / .1); border-radius: 10px; color: var(--hb-menta); }
.pc__nota-txt { display: flex; flex-direction: column; min-width: 0; }
.pc__nota-h { font: 500 10.5px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-menta); }
.pc__nota-t { font: 500 14px/1.35 var(--hb-sans); }
.pc-nota-enter-active, .pc-nota-leave-active { transition: opacity .25s, transform .25s; }
.pc-nota-enter-from { opacity: 0; transform: translateY(8px); }
.pc-nota-leave-to { opacity: 0; transform: translateY(-6px); }
@media (max-width: 520px) { .pc__nota { left: 0; max-width: 92%; } }

/* El control */
.pc__control { display: flex; align-items: flex-start; gap: 12px; }
.pc__play {
  flex-shrink: 0; width: 44px; height: 44px; border-radius: 50%; display: grid; place-items: center;
  background: var(--hb-verde); color: var(--hb-papel-claro); border: none; cursor: pointer; fill: currentColor;
  box-shadow: 0 6px 16px -6px rgb(46 107 74 / .7); transition: transform .15s;
}
.pc__play:hover { transform: scale(1.06); }
.pc__riel { flex: 1; min-width: 0; padding-top: 8px; }
.pc__rango { -webkit-appearance: none; appearance: none; width: 100%; height: 28px; background: transparent; cursor: pointer; margin: 0; }
.pc__rango::-webkit-slider-runnable-track { height: 6px; border-radius: 99px; background: linear-gradient(90deg, var(--hb-verde) var(--avance), var(--hb-regla) var(--avance)); }
.pc__rango::-moz-range-track { height: 6px; border-radius: 99px; background: linear-gradient(90deg, var(--hb-verde) var(--avance), var(--hb-regla) var(--avance)); }
.pc__rango::-webkit-slider-thumb { -webkit-appearance: none; width: 22px; height: 22px; margin-top: -8px; border-radius: 50%; background: var(--hb-papel-claro); border: 2px solid var(--hb-verde); box-shadow: 0 2px 6px rgb(0 0 0 / .18); }
.pc__rango::-moz-range-thumb { width: 18px; height: 18px; border-radius: 50%; background: var(--hb-papel-claro); border: 2px solid var(--hb-verde); }
.pc__rango:focus-visible { outline: 2px solid var(--hb-verde); outline-offset: 4px; border-radius: 6px; }
.pc__marcas { position: relative; height: 22px; }
.pc__marca {
  position: absolute; top: 0; transform: translateX(-10%); padding: 2px 0; border: none; background: none; cursor: pointer;
  font: 500 10.5px var(--hb-mono); color: var(--hb-tinta-2); white-space: nowrap; letter-spacing: .02em;
}
.pc__marca--on { color: var(--hb-verde); font-weight: 600; }
.pc__marca:first-child { transform: none; }
.pc__marca:last-child { transform: translateX(-60%); }

/* ── Portada: de borde a borde ──
   El piso es una franja abajo, a todo el ancho; la planta apoya sobre él, a la derecha. El día, la
   tarjeta y el control van sobre el piso. */
.pc--portada { position: absolute; inset: 0; display: block; }
.pc--portada .pc__escena { position: absolute; inset: 0; aspect-ratio: auto; }
.pc--portada .pc__piso { left: 0; right: 0; height: 128px; }
.pc--portada .pc__planta { inset: auto; bottom: 116px; right: max(4%, calc((100% - 1120px) / 2 + 12px)); height: calc(100% - 150px); aspect-ratio: 900 / 1100; }
.pc--portada .pc__lupa { top: 9%; right: max(2%, calc((100% - 1120px) / 2 - 40px)); width: clamp(140px, 15vw, 200px); }
.pc--portada .pc__dia { top: auto; left: max(32px, calc((100% - 1120px) / 2 + 32px)); bottom: 30px; }
.pc--portada .pc__dia-n { font-size: 2.6rem; }
.pc--portada .pc__nota { left: calc(max(32px, calc((100% - 1120px) / 2 + 32px)) + 150px); bottom: 26px; max-width: min(360px, 30%); }
.pc--portada .pc__control { position: absolute; right: 32px; bottom: 28px; width: min(560px, 46%); }
</style>
