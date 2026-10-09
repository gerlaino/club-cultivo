<template>
  <!-- «CÓMO SE HACE» (Germán, 9-oct-2026): la app DE VERDAD, grabada con Playwright sobre las
       cuentas demo (`frontend/scripts/demos`, `npm run demos`). A la izquierda los flujos; el que
       se está viendo despliega sus pasos, que se marcan solos mientras corre el video y al
       tocarlos lo llevan a ese momento. Cuando un video termina pasa al flujo siguiente: mirado
       de corrido es un recorrido entero. Los tiempos los escribe la misma grabación
       (`demos/tiempos.json`); los videos se piden recién cuando la sección aparece. -->
  <section ref="raiz" class="hb__sec cs" :class="`cs--${tema}`" :id="ancla">
    <div class="hb__wrap">
      <header class="cs__cab">
        <p class="hb__ceja" :class="{ 'hb__ceja--claro': tema === 'oscuro' }">{{ ceja }}</p>
        <h2 class="hb__h2 cs__h2">{{ titulo }}</h2>
        <p v-if="intro" class="cs__intro">{{ intro }}</p>
      </header>

      <div class="cs__grilla">
        <div class="cs__lado">
          <div v-if="vistasDisponibles.length > 1" class="cs__vista" role="tablist" aria-label="Dónde">
            <button v-for="v in vistasDisponibles" :key="v" type="button" role="tab" class="cs__vista-btn"
                    :aria-selected="vista === v" @click="cambiarVista(v)">{{ v === 'compu' ? 'Compu' : 'Teléfono' }}</button>
          </div>

          <ol class="cs__flujos">
            <li v-for="(f, i) in flujos" :key="f.etiqueta" class="cs__flujo" :class="{ 'is-on': i === actual }">
              <button type="button" class="cs__flujo-btn" :aria-expanded="i === actual" @click="elegir(i)">
                <span class="cs__flujo-n">{{ i + 1 }}</span>
                <span class="cs__flujo-txt">
                  <b>{{ f.etiqueta }}</b>
                  <small v-if="f.texto">{{ f.texto }}</small>
                </span>
              </button>
              <ol v-if="i === actual && datos" class="cs__pasos">
                <li v-for="(p, k) in datos.pasos" :key="p.texto">
                  <button type="button" class="cs__paso" :class="{ 'is-on': k === pasoActual, 'is-hecho': k < pasoActual }" @click="irA(p.t)">
                    {{ p.texto }}
                    <span v-if="k === pasoActual" class="cs__paso-barra" :style="{ transform: `scaleX(${avancePaso})` }"></span>
                  </button>
                </li>
              </ol>
            </li>
          </ol>
          <p v-if="datos" class="cs__nota">{{ datos.quien }} Grabado en la app, con datos de ejemplo.</p>
        </div>

        <div class="cs__pantalla">
          <div v-if="vista === 'compu'" class="cs__compu">
            <div class="cs__compu-barra" aria-hidden="true"><i></i><i></i><i></i><span>cultivoespacial.com</span></div>
            <video ref="video" :src="cargar ? datos?.video : undefined" muted playsinline preload="none"
                   :poster="cargar ? datos?.portada : undefined"
                   :aria-label="`${flujos[actual].etiqueta}, en la compu`"
                   @loadedmetadata="alCargar" @timeupdate="alAvanzar" @ended="siguiente"></video>
          </div>
          <div v-else class="cs__tel">
            <video ref="video" :src="cargar ? datos?.video : undefined" muted playsinline preload="none"
                   :poster="cargar ? datos?.portada : undefined"
                   :aria-label="`${flujos[actual].etiqueta}, en el teléfono`"
                   @loadedmetadata="alCargar" @timeupdate="alAvanzar" @ended="siguiente"></video>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, onBeforeUnmount } from 'vue'
import TIEMPOS from './demos/tiempos.json'

const props = defineProps({
  ceja:   { type: String, required: true },
  titulo: { type: String, required: true },
  intro:  { type: String, default: '' },
  ancla:  { type: String, default: 'como-se-hace' },
  tema:   { type: String, default: 'oscuro' },           // 'oscuro' (bosque) | 'claro'
  // [{ etiqueta, texto?, ids: { compu?: 'genetica-compu', telefono?: 'genetica-telefono' } }]
  flujos: { type: Array, required: true },
})

const vistasDisponibles = computed(() => ['compu', 'telefono'].filter(v => props.flujos.some(f => f.ids[v])))
const vista = ref(vistasDisponibles.value[0])
const actual = ref(0)
const datos = computed(() => TIEMPOS[props.flujos[actual.value].ids[vista.value]] || null)
const video = ref(null)
const raiz = ref(null)
const cargar = ref(false)
const ahora = ref(0)
let visible = false
const quieto = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches

// El paso en curso: el último que ya empezó (antes del primero, el primero).
const pasoActual = computed(() => {
  const ps = datos.value?.pasos || []
  let i = 0
  ps.forEach((p, k) => { if (ahora.value >= p.t) i = k })
  return i
})
const avancePaso = computed(() => {
  const ps = datos.value?.pasos || []
  if (!ps.length) return 0
  const ini = ps[pasoActual.value].t
  const fin = ps[pasoActual.value + 1]?.t ?? datos.value.duracion
  return Math.min(1, Math.max(0, (ahora.value - ini) / (fin - ini)))
})

function reproducir () {
  if (!visible || quieto) return
  video.value?.play().catch(() => {})
}
// Cada video arranca después de la carga de su pantalla (`inicio`), que quedó grabada antes.
function alCargar () {
  if (!video.value || !datos.value) return
  video.value.currentTime = datos.value.inicio || 0
  ahora.value = video.value.currentTime
  reproducir()
}
function alAvanzar (e) { ahora.value = e.target.currentTime }
function irA (t) {
  if (!video.value) return
  video.value.currentTime = t
  ahora.value = t
  reproducir()
}
async function elegir (i) {
  if (i === actual.value && video.value?.src) { irA(datos.value?.inicio || 0); return }
  actual.value = i
  ahora.value = 0
  // Con `preload="none"` cambiar el src no carga nada: `play()` lo pide, y al llegar
  // `loadedmetadata` lo pone en su inicio.
  await nextTick()
  reproducir()
}
async function siguiente () {
  // El que no tiene versión en esta vista se salta.
  let i = actual.value
  for (let n = 0; n < props.flujos.length; n++) {
    i = (i + 1) % props.flujos.length
    if (props.flujos[i].ids[vista.value]) break
  }
  if (i === actual.value) { irA(datos.value?.inicio || 0); return }
  await elegir(i)
}
async function cambiarVista (v) {
  vista.value = v
  if (!props.flujos[actual.value].ids[v]) actual.value = props.flujos.findIndex(f => f.ids[v])
  ahora.value = 0
  await nextTick()
  reproducir()
}

let observador = null
onMounted(() => {
  if (!('IntersectionObserver' in window)) { visible = true; cargar.value = true; return }
  // Se pide el video recién al acercarse a la sección, y se pausa cuando sale de pantalla.
  observador = new IntersectionObserver(async (entradas) => {
    visible = entradas.some(e => e.isIntersecting)
    if (visible && !cargar.value) { cargar.value = true; await nextTick() }
    if (visible) reproducir()
    else video.value?.pause()
  }, { threshold: 0.3 })
  observador.observe(raiz.value)
})
onBeforeUnmount(() => observador?.disconnect())
</script>

<style scoped>
.cs--oscuro { background: var(--hb-bosque); color: var(--hb-papel-claro); }
.cs--claro { background: var(--hb-papel-claro); border-block: 1px solid var(--hb-regla); }
.cs__cab { max-width: 46em; margin-bottom: clamp(24px, 4vw, 40px); }
.cs--oscuro .cs__h2 { color: var(--hb-papel-claro); }
.cs__intro { margin: 12px 0 0; font-size: 1.05rem; color: var(--hb-tinta-2); }
.cs--oscuro .cs__intro { color: color-mix(in srgb, var(--hb-papel-claro) 78%, transparent); }

.cs__grilla { display: grid; grid-template-columns: minmax(0, 380px) minmax(0, 1fr); gap: clamp(28px, 4vw, 64px); align-items: center; }
@media (max-width: 900px) { .cs__grilla { grid-template-columns: minmax(0, 1fr); } .cs__pantalla { order: -1; } }
.cs__lado { min-width: 0; }

.cs__vista { display: inline-flex; gap: 4px; margin-bottom: 16px; padding: 4px; border-radius: 999px; background: rgb(255 255 255 / .08); }
.cs--claro .cs__vista { background: var(--hb-salvia-suave); }
.cs__vista-btn { border: 0; background: none; color: var(--hb-salvia); padding: 7px 16px; border-radius: 999px; font: 600 14px var(--hb-sans); cursor: pointer; }
.cs--claro .cs__vista-btn { color: var(--hb-tinta-2); }
.cs__vista-btn[aria-selected="true"] { background: var(--hb-menta); color: var(--hb-bosque); }
.cs--claro .cs__vista-btn[aria-selected="true"] { background: var(--hb-verde); color: var(--hb-papel-claro); }

.cs__flujos { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
.cs__flujo { border-radius: 12px; transition: background .2s; }
.cs__flujo.is-on { background: rgb(255 255 255 / .07); }
.cs--claro .cs__flujo.is-on { background: var(--hb-papel); box-shadow: inset 0 0 0 1.5px var(--hb-verde); }
.cs__flujo-btn { width: 100%; display: grid; grid-template-columns: 30px minmax(0, 1fr); gap: 12px; align-items: start; padding: 12px; border: 0; background: none; color: inherit; text-align: left; font: inherit; cursor: pointer; border-radius: 12px; }
.cs__flujo-btn:focus-visible, .cs__paso:focus-visible, .cs__vista-btn:focus-visible { outline: 2px solid var(--hb-menta); outline-offset: 1px; }
.cs--claro .cs__flujo-btn:focus-visible, .cs--claro .cs__paso:focus-visible { outline-color: var(--hb-verde); }
.cs__flujo-n { width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; border: 1px solid currentColor; font: 600 1rem var(--hb-serif); opacity: .7; }
.cs__flujo.is-on .cs__flujo-n { opacity: 1; background: var(--hb-menta); border-color: var(--hb-menta); color: var(--hb-bosque); }
.cs--claro .cs__flujo.is-on .cs__flujo-n { background: var(--hb-verde); border-color: var(--hb-verde); color: var(--hb-papel-claro); }
.cs__flujo-txt { display: grid; gap: 3px; padding-top: 4px; min-width: 0; }
.cs__flujo-txt b { font: 600 1.12rem/1.25 var(--hb-serif); }
.cs__flujo-txt small { font-size: .92rem; line-height: 1.45; opacity: .78; }

.cs__pasos { list-style: none; margin: 0; padding: 0 12px 12px 54px; display: grid; gap: 2px; }
.cs__paso { position: relative; overflow: hidden; width: 100%; padding: 7px 10px; border: 0; border-radius: 8px; background: none; color: inherit; opacity: .6; text-align: left; font: 500 .9rem/1.35 var(--hb-sans); cursor: pointer; }
.cs__paso.is-hecho { opacity: .8; }
.cs__paso.is-on { opacity: 1; font-weight: 600; background: rgb(255 255 255 / .08); }
.cs--claro .cs__paso.is-on { background: var(--hb-salvia-suave); }
.cs__paso-barra { position: absolute; left: 0; right: 0; bottom: 0; height: 2px; background: var(--hb-menta); transform-origin: left; }
.cs--claro .cs__paso-barra { background: var(--hb-verde); }
.cs__nota { margin: 14px 0 0; font: 12px/1.5 var(--hb-mono); opacity: .7; }

.cs__pantalla { min-width: 0; display: grid; place-items: center; }
.cs__compu { width: 100%; border-radius: 12px; overflow: hidden; background: #0c1a12; box-shadow: 0 40px 80px -36px rgb(0 0 0 / .6); border: 1px solid rgb(255 255 255 / .1); }
.cs__compu-barra { display: flex; align-items: center; gap: 6px; padding: 9px 12px; background: #1f2a23; }
.cs__compu-barra i { width: 9px; height: 9px; border-radius: 50%; background: #3b4a40; }
.cs__compu-barra span { margin: 0 auto; padding: 2px 14px; border-radius: 6px; background: #2a362e; font: 11px var(--hb-mono); color: #a9bdb0; }
.cs__compu video { display: block; width: 100%; aspect-ratio: 1280 / 800; background: #F3F6F4; }
.cs__tel { width: min(320px, 100%); padding: 10px; border-radius: 44px; background: #0c1a12; box-shadow: 0 40px 80px -30px rgb(0 0 0 / .5), inset 0 0 0 2px rgb(255 255 255 / .08); }
.cs__tel video { display: block; width: 100%; aspect-ratio: 390 / 844; border-radius: 34px; background: #F4F8F5; }
/* En el teléfono, el marco arriba de los controles: más chico, para que se vean los pasos. */
@media (max-width: 900px) { .cs__tel { width: min(250px, 72%); } }
</style>
