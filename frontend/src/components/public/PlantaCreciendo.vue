<template>
  <div ref="raiz" class="pc" :class="{ 'pc--portada': portada }">
    <!-- En la portada, el piso es una franja a todo el ancho. -->
    <div v-if="portada" class="pc__piso" aria-hidden="true"></div>

    <!-- La columna de la planta. -->
    <div class="pc__columna">
      <div class="pc__planta" role="img" :aria-label="`Una planta en el día ${dia}: ${fase.nombre}`">
        <div v-if="!portada" class="pc__piso pc__piso--local" aria-hidden="true"></div>
        <span class="pc__sombra" aria-hidden="true"></span>
        <!-- Las 7 fotos apiladas: se ven, a lo sumo, dos a la vez (la que se va y la que llega). -->
        <img v-for="(e, i) in ETAPAS" :key="e.src" :src="e.src" alt="" class="pc__foto" draggable="false"
             :style="{ opacity: opacidades[i] * (1 - final) }" :fetchpriority="i < 2 ? 'high' : 'low'" decoding="async" />
        <!-- El final: la planta se va y queda lo cosechado, solo y grande, en su lugar. -->
        <figure class="pc__cosecha" :style="{ opacity: final, transform: `scale(${0.9 + 0.1 * final})` }" :aria-hidden="final < 0.5">
          <img :src="COSECHA" alt="Lo cosechado: un cogollo seco y curado" draggable="false" />
        </figure>

        <!-- El contador, al lado de la maceta, y (en la portada) lo que anotó la app ese día, pegado. -->
        <div class="pc__dia" aria-live="polite">
          <span class="pc__dia-n">Día {{ dia }}</span>
          <span class="pc__dia-fase">{{ fase.nombre }}</span>
          <Transition v-if="portada" name="pc-nota" mode="out-in">
            <div :key="evento.dia" class="pc__nota">
              <span class="pc__nota-ico" aria-hidden="true"><component :is="evento.ico" :size="18" :stroke-width="1.8" /></span>
              <div class="pc__nota-txt">
                <span class="pc__nota-h">En la app · día {{ evento.dia }}</span>
                <span class="pc__nota-t">{{ evento.texto }}</span>
              </div>
            </div>
          </Transition>
        </div>

      </div>
    </div>


    <!-- En el teléfono, lo que anotó la app ese día va debajo (al lado de la maceta no entra). -->
    <Transition v-if="!portada" name="pc-nota" mode="out-in">
      <div :key="evento.dia" class="pc__nota">
        <span class="pc__nota-ico" aria-hidden="true"><component :is="evento.ico" :size="18" :stroke-width="1.8" /></span>
        <div class="pc__nota-txt">
          <span class="pc__nota-h">En la app · día {{ evento.dia }}</span>
          <span class="pc__nota-t">{{ evento.texto }}</span>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
// LA PLANTA QUE CRECE: de la semilla al cogollo seco, en bucle y sola mientras se ve (Germán: que
// no haya que tocar nada, sin controles). Cada etapa trae la
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

// Lo que queda al final, en lugar de la planta (Germán: terminar mostrando lo cosechado, no la
// maceta). Cuando llegue la foto de la vara cosechada, se cambia sólo este archivo.
const COSECHA = '/planta/cogollo.webp'

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

const FASES = [
  { nombre: 'Semilla',      desde: 0 },
  { nombre: 'Germinación',  desde: 3 },
  { nombre: 'Vegetativo',   desde: 12 },
  { nombre: 'Prefloración', desde: 38 },
  { nombre: 'Floración',    desde: 50 },
  { nombre: 'Cosecha',      desde: 78 },
  { nombre: 'Al frasco',    desde: 86 },
]
const EVENTOS = [
  { dia: 0,  ico: Bean,         texto: 'Sembraste una King’s Juice (auto)' },
  { dia: 4,  ico: Sprout,       texto: 'Germinó: asomó el primer brote' },
  { dia: 9,  ico: Droplet,      texto: 'Primer riego · 150 ml' },
  { dia: 16, ico: Droplets,     texto: 'Riego 0,4 L · pH 6,2 · EC 0,6' },
  { dia: 24, ico: FlaskConical, texto: 'Primeros nutrientes de crecimiento · EC 1,0' },
  { dia: 31, ico: Droplets,     texto: 'Riego 1 L · pH 6,3 · EC 1,2' },
  { dia: 40, ico: BellRing,     texto: 'Aviso: asoman los primeros pistilos' },
  { dia: 47, ico: FlaskConical, texto: 'Nutrientes de floración · EC 1,4' },
  { dia: 52, ico: Scissors,     texto: 'Defoliación: le sacaste las hojas que tapaban los cogollos' },
  { dia: 58, ico: Camera,       texto: 'Foto de la semana 9: la cola engorda' },
  { dia: 70, ico: BellRing,     texto: 'Tricomas lechosos: se acerca la cosecha' },
  { dia: 79, ico: Scissors,     texto: 'Cosechaste: 312 g en húmedo' },
  { dia: 86, ico: Archive,      texto: 'Al frasco: 64 g secos, a curar' },
]

const dia = ref(0)
const fase = computed(() => [...FASES].reverse().find(f => dia.value >= f.desde))
const evento = computed(() => [...EVENTOS].reverse().find(e => dia.value >= e.dia))

// Opacidad de cada foto: entre dos etapas, la que llega aparece en el último 30 % del tramo (un
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
  op[k] = suave(((d - a) / (b - a) - 0.7) / 0.3)
  return op
})

// 0 → 1 entre los días 82 y 86: la planta se desvanece y aparece lo cosechado.
const final = computed(() => suave((dia.value - 82) / 4))

// ── Reproducción: en bucle, sola ─────────────────────────
// Corre de la semilla al cogollo, se queda un momento mostrando el cogollo y vuelve a empezar. No
// hay controles (Germán: empieza y termina, sola). Lento a propósito: cada evento («Defoliación», «Tricomas lechosos») tiene que alcanzar a leerse.
const raiz = ref(null)
const detenido = ref(false)   // sólo con «reducir movimiento»: queda quieta
const DURACION_MS = 28000
const ESPERA_FINAL_MS = 3200
let raf = null
let ultimo = 0
let acumulado = 0
let espera = null
let observador = null
let visible = false

function paso (t) {
  if (ultimo) acumulado += ((t - ultimo) / DURACION_MS) * MAX
  ultimo = t
  if (acumulado >= 1) {
    const avance = Math.floor(acumulado)
    acumulado -= avance
    dia.value = Math.min(MAX, dia.value + avance)
  }
  if (dia.value >= MAX) { raf = null; esperar(ESPERA_FINAL_MS, () => { dia.value = 0; correr() }); return }
  raf = requestAnimationFrame(paso)
}
function correr () {
  if (detenido.value || !visible || raf) return
  ultimo = 0
  acumulado = 0
  raf = requestAnimationFrame(paso)
}
function frenar () {
  if (raf) cancelAnimationFrame(raf)
  raf = null
  clearTimeout(espera)
}
function esperar (ms, fn) { clearTimeout(espera); espera = setTimeout(fn, ms) }

onMounted(() => {
  // Las fotos se piden todas de entrada: si llegan recién al deslizar, el fundido parpadea.
  for (const e of ETAPAS) { const im = new Image(); im.src = e.src }
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) { dia.value = 64; detenido.value = true; return }
  // Corre sólo mientras se ve (fuera de pantalla no gasta batería) y arranca la primera vez que aparece.
  observador = new IntersectionObserver((entradas) => {
    visible = entradas.some(e => e.isIntersecting)
    if (visible) correr()
    else frenar()
  }, { threshold: 0.2 })
  if (raiz.value) observador.observe(raiz.value)
})
onBeforeUnmount(() => { frenar(); observador?.disconnect() })
</script>

<style scoped>
.pc { display: flex; flex-direction: column; gap: 14px; }

/* ── Angosta (teléfono): la planta, su línea de tiempo y la tarjeta, una debajo de otra ── */
.pc__columna { display: flex; flex-direction: column; gap: 10px; }
.pc__planta { position: relative; aspect-ratio: 900 / 1100; user-select: none; }
.pc__piso { pointer-events: none; border-top: 1px solid color-mix(in srgb, var(--hb-tierra) 45%, transparent); background: linear-gradient(color-mix(in srgb, var(--hb-tierra) 14%, transparent), transparent); }
.pc__piso--local { position: absolute; left: -16px; right: -16px; bottom: 0; height: 3%; }
.pc__foto { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: contain; object-position: bottom center; pointer-events: none; will-change: opacity; }
/* Sombra propia, igual para todas las fotos: la maceta ocupa un tercio del ancho, al centro. */
.pc__sombra { position: absolute; left: 30%; right: 30%; bottom: 1.4%; height: 3%; border-radius: 50%; background: radial-gradient(closest-side, rgb(21 48 31 / .28), transparent); }

/* El contador, a la izquierda de la maceta (la maceta va del 33 % al 67 % del ancho). */
.pc__dia { position: absolute; right: 70%; bottom: 4%; display: flex; flex-direction: column; align-items: flex-end; gap: 2px; text-align: right; }
.pc__dia-n { font: 600 clamp(1.6rem, 3vw, 2.4rem)/1 var(--hb-serif); color: var(--hb-tinta); font-variant-numeric: tabular-nums; letter-spacing: -.02em; white-space: nowrap; }
.pc__dia-fase { font: 500 11px var(--hb-mono); letter-spacing: .12em; text-transform: uppercase; color: var(--hb-verde); white-space: nowrap; }

/* El final: lo cosechado ocupa el lugar de la planta, apoyado en el piso y a la derecha del
   contador (que está pegado a la izquierda de donde estaba la maceta). */
.pc__cosecha { position: absolute; left: 31%; right: 0; bottom: 3%; top: 18%; margin: 0; display: flex; align-items: flex-end; justify-content: center; pointer-events: none; transform-origin: 50% 100%; }
.pc__cosecha img { width: 100%; height: 100%; object-fit: contain; object-position: bottom center; filter: drop-shadow(0 24px 30px rgb(21 48 31 / .28)); }

/* La tarjeta «En la app»: el mismo verde oscuro que la ficha del lote en el teléfono. */
.pc__nota {
  display: flex; gap: 10px; align-items: center; align-self: flex-start; max-width: 100%; text-align: left;
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

/* ── Portada: la columna contra el borde derecho, a toda la altura; el piso, una franja a todo
   el ancho a la altura de la base de la maceta; la tarjeta, sobre el piso alineada con el texto. ── */
.pc--portada { position: absolute; inset: 0; display: block; }
.pc--portada .pc__columna {
  /* Un poco más a la derecha que el borde del contenido, para que no se acerque al texto. */
  position: absolute; right: max(8px, calc(var(--hb-borde, 32px) - 4vw)); top: 20px; bottom: 60px;
  aspect-ratio: 900 / 1100;
}
.pc--portada .pc__planta { flex: 1; min-height: 0; aspect-ratio: auto; }
/* El piso empieza justo en la base de la maceta: la foto ocupa la columna (20 px arriba, 60 abajo)
   y la base cae al 97,3 % de la foto. Altura del piso = 100 % − 20 − 0,973 × (100 % − 80) ≈ 2,7 % + 58 px. */
.pc--portada .pc__piso { position: absolute; left: 0; right: 0; bottom: 0; height: calc(2.7% + 58px); }
.pc--portada .pc__dia { gap: 4px; }
.pc--portada .pc__nota { margin-top: 10px; align-self: flex-end; width: max-content; max-width: 340px; }
</style>
