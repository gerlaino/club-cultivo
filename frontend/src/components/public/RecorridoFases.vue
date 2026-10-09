<template>
  <!-- DE LA SEMILLA AL FRASCO, FASE POR FASE (Germán, 9-oct-2026): un híbrido entre la planta que
       crece y el teléfono. La app guarda una foto por semana de cada planta, así que la ficha
       muestra la foto real de esa fase (las de `PlantaCreciendo`) con lo que se anotó y lo que
       viene. Pasa sola mientras se ve; un toque la deja quieta. -->
  <section ref="raiz" class="hb__sec hb__sec--claro rc-sec" id="que-hace">
    <div class="hb__wrap">
      <header class="hb__sec-h">
        <p class="hb__ceja">De la semilla al frasco</p>
        <h2 class="hb__h2">Acompañada en cada fase</h2>
        <p class="rc__intro">Así se ve una automática en la app, fase por fase: lo que anotaste y lo que viene.</p>
      </header>

      <div class="rc" :class="{ 'rc--corre': corre }">
        <div ref="lista" class="rc__fases" role="tablist" aria-label="Fases">
          <button v-for="(f, i) in FASES" :key="f.t" type="button" role="tab" class="rc__fase" :aria-selected="sel === i"
                  aria-controls="rc-panel" @click="tocar(i)">
            <span class="rc__fase-dia">Día {{ f.dia }}</span>
            <span class="rc__fase-t">{{ f.t }}</span>
            <span class="rc__fase-d">{{ f.d }}</span>
            <span :key="`${sel}-${vuelta}`" class="rc__barra"></span>
          </button>
        </div>

        <div id="rc-panel" class="rc__tel" role="tabpanel" aria-live="polite">
          <div class="rc__pantalla">
            <div class="rc__cab"><span>King’s Juice · auto · Carpa grande</span><b>La petisa</b></div>
            <div class="rc__foto">
              <Transition name="rc-foto" mode="out-in">
                <img :key="fase.img" :src="fase.img" :alt="`La petisa, día ${fase.dia}: ${fase.t}`" />
              </Transition>
              <span class="rc__dia">Día {{ fase.dia }}<small>{{ fase.t }}</small></span>
              <span class="rc__semana">{{ fase.sem }}</span>
            </div>
            <div class="rc__reloj"><div :style="{ width: `${Math.min(100, (fase.dia / 90) * 100)}%` }"></div></div>
            <div :key="sel" class="rc__cuerpo">
              <p class="rc__sec">Lo que anotaste</p>
              <div v-for="(r, k) in fase.reg" :key="r.t" class="rc__reg" :style="{ animationDelay: `${80 + k * 110}ms` }">
                <span><component :is="r.ico" :size="15" :stroke-width="1.9" /></span>
                <div><b>{{ r.t }}</b><small>{{ r.s }}</small><span v-if="r.voz" class="rc__voz">Dictado por voz</span></div>
              </div>
              <p class="rc__sec" style="animation-delay: 300ms">{{ sel === FASES.length - 1 ? 'Tu resultado' : 'Lo que viene' }}</p>
              <div class="rc__viene" style="animation-delay: 380ms">
                <div><b>{{ fase.viene[0] }}</b><small>{{ fase.viene[1] }}</small></div><em>{{ fase.viene[2] }}</em>
              </div>
            </div>
            <div class="rc__nav" aria-hidden="true"><span>Hoy</span><span class="rc__nav--on">Cultivo</span><b>+</b><span>Stock</span><span>Gastos</span></div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { Bean, Sprout, Droplets, FlaskConical, Scissors, Camera, BellRing, Archive } from 'lucide-vue-next'

// Lo que dice cada fase existe hoy en la app: próximos pasos con aviso, riegos con pH/EC, la dosis
// convertida a solución, foto por semana, cosecha estimada según la genética, pesadas con su merma,
// frascos con su planta y el costo por gramo. Datos ficticios; los números cierran entre sí.
const FASES = [
  { t: 'Germinación', dia: 4, sem: 'Semana 1', img: '/planta/01.webp',
    d: 'Anotás la siembra, aunque sea dictándola, y el día que asoma el brote.',
    reg: [{ ico: Bean, t: 'Sembraste en un vaso', s: 'Día 0 · «puse una semilla de King’s Juice en un vaso»', voz: true },
          { ico: Sprout, t: 'Germinó', s: 'Día 4 · asomó el primer brote' }],
    viene: ['Primer riego', '150 ml · con poca agua al principio', 'En 5 días'] },
  { t: 'Vegetativo', dia: 31, sem: 'Semana 5', img: '/planta/04.webp',
    d: 'Cada riego con cuánto, pH y EC. Le decís la dosis y la app calcula la solución.',
    reg: [{ ico: Droplets, t: 'Riego 1 L · pH 6,3 · EC 1,2', s: 'Día 31 · hace 2 días', voz: true },
          { ico: FlaskConical, t: 'Nutrientes de crecimiento', s: '2 ml/L · 4,5 L de solución' }],
    viene: ['Empieza a florecer', 'Te avisamos al teléfono', 'En 5 días'] },
  { t: 'Floración', dia: 58, sem: 'Semana 9', img: '/planta/06.webp',
    d: 'La app lleva las semanas, te recuerda la foto de cada una y te avisa cuánto falta.',
    reg: [{ ico: Scissors, t: 'Defoliación', s: 'Día 52 · las hojas que tapaban los cogollos' },
          { ico: Camera, t: 'Foto de la semana 9', s: 'Día 58 · la cola engorda' }],
    viene: ['Cosecha estimada', 'Según la genética', 'En 19 días'] },
  { t: 'Cosecha', dia: 79, sem: 'Semana 12', img: '/planta/07.webp',
    d: 'Pesás en húmedo al cortar y la app guarda la fecha y de qué planta salió.',
    reg: [{ ico: Scissors, t: 'Cosechaste', s: 'Día 79 · 312 g en húmedo' },
          { ico: BellRing, t: 'A secar', s: 'Te avisamos para pesar en seco' }],
    viene: ['Pesar en seco', 'Cuando termine de secar', 'En 10 días'] },
  { t: 'Al frasco', dia: 90, sem: 'Curado', img: '/planta/vara.webp',
    d: 'Seco y curado con su merma, cada frasco con su planta, y cuánto te costó cada gramo.',
    reg: [{ ico: Archive, t: 'Al frasco · 64 g curados', s: 'Seco 70 g · merma total 79 %' },
          { ico: FlaskConical, t: 'Frascos F-01 y F-02', s: 'Los dos de La petisa' }],
    viene: ['Cada gramo te costó', 'Informe de la cosecha · PDF', '$ 719'] },
]
const ROTA_MS = 6000

const sel = ref(0)
const vuelta = ref(0)        // re-arranca la barra de la fase aunque se repita la misma
const tocado = ref(false)
const visible = ref(false)
const quieto = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
const corre = computed(() => !quieto && !tocado.value && visible.value)
const fase = computed(() => FASES[sel.value])
const raiz = ref(null)
const lista = ref(null)
let rota = null
let observador = null

function mostrar (i) {
  sel.value = i
  vuelta.value++
  // En el teléfono las fases son una fila que se desliza: la elegida queda a la vista.
  const fila = lista.value
  const b = fila?.children[i]
  if (fila && b && fila.scrollWidth > fila.clientWidth) {
    fila.scrollTo({ left: b.offsetLeft - (fila.clientWidth - b.offsetWidth) / 2, behavior: quieto ? 'auto' : 'smooth' })
  }
  programar()
}
function programar () {
  clearTimeout(rota)
  if (corre.value) rota = setTimeout(() => mostrar((sel.value + 1) % FASES.length), ROTA_MS)
}
function tocar (i) { tocado.value = true; mostrar(i) }

onMounted(() => {
  // Las fotos se piden de entrada: si llegan recién al cambiar de fase, el fundido parpadea.
  for (const f of FASES) { const im = new Image(); im.src = f.img }
  if (!('IntersectionObserver' in window)) return
  observador = new IntersectionObserver((entradas) => {
    const v = entradas.some(e => e.isIntersecting)
    if (v !== visible.value) { visible.value = v; programar() }
  }, { threshold: 0.4 })
  observador.observe(raiz.value)
})
onBeforeUnmount(() => { clearTimeout(rota); observador?.disconnect() })
</script>

<style scoped>
.rc__intro { margin: 12px 0 0; color: var(--hb-tinta-2); font-size: 1.05rem; }
.rc { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 340px); gap: clamp(28px, 5vw, 80px); align-items: center; }
@media (max-width: 860px) { .rc { grid-template-columns: minmax(0, 1fr); } }

.rc__fases { display: grid; border-top: 1px solid var(--hb-regla); }
.rc__fase {
  position: relative; display: grid; grid-template-columns: 92px minmax(0, 1fr); gap: 4px 16px; align-items: baseline;
  width: 100%; text-align: left; padding: 18px 8px 18px 0; background: none; border: 0; border-bottom: 1px solid var(--hb-regla);
  cursor: pointer; font: inherit; color: var(--hb-tinta-2);
}
.rc__fase-dia { grid-row: span 2; font: 500 12px var(--hb-mono); letter-spacing: .06em; padding-top: 5px; }
.rc__fase-t { font: 600 1.3rem/1.2 var(--hb-serif); transition: color .2s; }
.rc__fase-d { font-size: .95rem; line-height: 1.45; }
.rc__fase:hover .rc__fase-t, .rc__fase[aria-selected="true"] .rc__fase-t { color: var(--hb-tinta); }
.rc__fase[aria-selected="true"] .rc__fase-dia { color: var(--hb-verde); }
.rc__fase[aria-selected="true"] .rc__fase-d { color: var(--hb-tinta); }
.rc__barra { position: absolute; left: 0; right: 0; bottom: -1px; height: 2px; background: var(--hb-verde); transform-origin: left; transform: scaleX(0); }
.rc__fase[aria-selected="true"] .rc__barra { transform: scaleX(1); }
.rc--corre .rc__fase[aria-selected="true"] .rc__barra { animation: rc-llena 6000ms linear both; }
@keyframes rc-llena { from { transform: scaleX(0); } to { transform: scaleX(1); } }
@media (max-width: 860px) {
  .rc__fases { display: flex; gap: 8px; overflow-x: auto; border: 0; padding-bottom: 4px; scrollbar-width: none; }
  .rc__fase { flex: 0 0 auto; display: flex; width: auto; padding: 8px 14px; border: 1px solid var(--hb-regla); border-radius: 999px; background: var(--hb-papel); }
  .rc__fase-dia, .rc__fase-d, .rc__barra { display: none; }
  .rc__fase-t { font: 600 14px var(--hb-sans); white-space: nowrap; }
  .rc__fase[aria-selected="true"] { background: var(--hb-verde); border-color: var(--hb-verde); }
  .rc__fase[aria-selected="true"] .rc__fase-t { color: var(--hb-papel-claro); }
}

/* El teléfono: colores de la app, como `TelefonoMiCultivo` */
.rc__tel { justify-self: center; width: min(340px, 100%); padding: 10px; border-radius: 44px; background: #0c1a12; box-shadow: 0 40px 80px -30px rgb(0 0 0 / .45), inset 0 0 0 2px rgb(255 255 255 / .08); }
.rc__pantalla { border-radius: 34px; overflow: hidden; background: #F4F8F5; color: #1A1D1F; display: flex; flex-direction: column; font-family: var(--hb-sans); height: 640px; }
.rc__cab { background: #1A3D2E; color: #fff; padding: 26px 16px 12px; display: flex; flex-direction: column; }
.rc__cab span { font-size: 10px; color: #A8C9B5; }
.rc__cab b { font-size: 19px; }
.rc__foto { position: relative; height: 210px; background: radial-gradient(60% 70% at 60% 35%, #DCEDE1, #EEF5EF 75%); border-bottom: 1px solid #E1E8E3; }
.rc__foto img { position: absolute; inset: 8px 0 0; width: 100%; height: calc(100% - 8px); object-fit: contain; object-position: bottom center; }
.rc-foto-enter-active, .rc-foto-leave-active { transition: opacity .2s; }
.rc-foto-enter-from, .rc-foto-leave-to { opacity: 0; }
.rc__dia { position: absolute; left: 12px; bottom: 12px; display: flex; flex-direction: column; font: 600 22px/1 var(--hb-serif); color: #15301F; }
.rc__dia small { font: 500 9.5px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: #2E6B4A; margin-top: 4px; }
.rc__semana { position: absolute; right: 10px; top: 10px; font: 600 9.5px var(--hb-sans); background: rgb(255 255 255 / .85); border-radius: 99px; padding: 3px 8px; color: #1A3D2E; }
.rc__reloj { height: 5px; background: #DCEDE1; }
.rc__reloj div { height: 100%; background: #2D4A3E; transition: width .6s cubic-bezier(.2, .7, .2, 1); }
.rc__cuerpo { padding: 12px; display: flex; flex-direction: column; gap: 7px; font-size: 12px; flex: 1; overflow: hidden; }
.rc__cuerpo > * { animation: rc-entra .35s ease both; }
.rc__sec { margin: 2px 0 0; font-size: 10px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: #3A3F44; }
.rc__reg { display: grid; grid-template-columns: 26px minmax(0, 1fr); gap: 8px; align-items: center; background: #fff; border: 1px solid #E1E8E3; border-radius: 10px; padding: 8px 10px; }
.rc__reg > span { width: 26px; height: 26px; border-radius: 8px; display: grid; place-items: center; background: #E8F0EB; color: #1A3D2E; }
.rc__reg > div { display: flex; flex-direction: column; min-width: 0; }
.rc__reg small { font-size: 10.5px; color: #3A3F44; }
.rc__voz { font-size: 9.5px; font-weight: 700; color: #2E6B4A; }
.rc__viene { background: #1A3D2E; color: #fff; border-radius: 10px; padding: 9px 11px; display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.rc__viene > div { display: flex; flex-direction: column; min-width: 0; }
.rc__viene small { font-size: 10px; color: #A8C9B5; }
.rc__viene em { font-style: normal; font-size: 10.5px; font-weight: 700; color: #9FD1B0; white-space: nowrap; }
.rc__nav { margin-top: auto; display: flex; align-items: center; justify-content: space-around; padding: 9px 8px 13px; border-top: 1px solid #E1E8E3; background: #fff; font-size: 10px; color: #6B7280; }
.rc__nav--on { color: #1A3D2E; font-weight: 700; }
.rc__nav b { width: 32px; height: 32px; border-radius: 50%; display: grid; place-items: center; background: #2E7D4F; color: #fff; font-size: 18px; font-weight: 400; margin-top: -16px; }
@keyframes rc-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .rc__cuerpo > * { animation: none; } .rc__reloj div { transition: none; } }
</style>
