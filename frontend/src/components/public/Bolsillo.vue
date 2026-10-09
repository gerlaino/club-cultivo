<template>
  <section class="hb__bolsillo" id="bolsillo">
    <div class="hb__wrap hb__bolsillo-in">
      <div class="hb__bolsillo-txt hb-rev">
        <p class="hb__ceja hb__ceja--claro">La app</p>
        <h2 class="hb__h2">Llevala en el bolsillo</h2>
        <p>
          Se instala en el teléfono desde el navegador, sin tiendas y en segundos. Abrís tu planta,
          tocás «Regar» y listo: cuánto y con qué, una foto, una nota. Te avisa cuando le toca algo.
        </p>
        <ul class="hb__pasos">
          <li><span>1</span> Creá tu cuenta gratis</li>
          <li><span>2</span> Cargá tu espacio y tus plantas</li>
          <li><span>3</span> Instalala y anotá desde la planta</li>
        </ul>
        <div class="hb__acciones">
          <RouterLink to="/registro" class="hb__btn hb__btn--claro">Probala gratis</RouterLink>
          <button v-if="instalable" type="button" class="hb__btn hb__btn--linea-claro" @click="instalar">Instalar en este dispositivo</button>
        </div>
        <p class="hb__instalar-ayuda">
          En iPhone: <b>Compartir</b> → <b>Agregar a inicio</b>. En Android: menú <b>⋮</b> → <b>Instalar app</b>.
        </p>
      </div>

      <!-- Un teléfono con la ficha de una planta, como se ve de verdad en la app (9-oct-2026). -->
      <div class="hb__tel hb-rev" aria-hidden="true">
        <div class="hb__tel-pantalla">
          <div class="hb__tel-hero">
            <span class="hb__tel-fase">VEGETATIVO <i>AUTO</i></span>
            <b class="hb__tel-cod">La petisa</b>
            <span class="hb__tel-gen">King’s Juice · de semilla · Carpa grande</span>
            <span class="hb__tel-falta">→ Faltan 46 días para la cosecha</span>
            <div class="hb__tel-stats">
              <div><b>31</b><small>Día</small></div>
              <div><b>77</b><small>Ciclo</small></div>
              <div><b>Carpa</b><small>Espacio</small></div>
              <div><b>10 L</b><small>Maceta</small></div>
            </div>
          </div>
          <div class="hb__tel-cta">Regar<small>Cuánto y con qué: receta, nutrientes o sólo agua</small></div>
          <div class="hb__tel-feed">
            <div v-for="r in telFeed" :key="r.t" class="hb__tel-item"><span><component :is="r.i" :size="16" :stroke-width="1.8" /></span><div><b>{{ r.t }}</b><small>{{ r.s }}</small></div></div>
          </div>
          <div class="hb__tel-nav">
            <span>Hoy</span><span class="hb__tel-nav--on">Cultivo</span><b>+</b><span>Stock</span><span>Gastos</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
// «LLEVALA EN EL BOLSILLO»: cómo se instala en el teléfono y cómo se ve la ficha de una planta. Salió
// de la portada (5-oct-2026) para la página de casa. El teléfono replica la ficha real de la app.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { Droplets, Camera, BellRing } from 'lucide-vue-next'

const telFeed = [
  { i: Droplets, t: 'Riego 1,2 L · pH 6,3', s: 'Hoy, 9:40' },
  { i: Camera,   t: 'Foto · semana 5', s: 'Ayer' },
  { i: BellRing, t: 'Próximo paso: empieza a florecer', s: 'En 5 días' },
]

// Instalar como app: Chrome/Android ofrecen el evento; en iPhone se explica a mano.
const instalable = ref(false)
let promptInstalar = null
function alPedirInstalar (e) { e.preventDefault(); promptInstalar = e; instalable.value = true }
async function instalar () {
  if (!promptInstalar) return
  promptInstalar.prompt()
  try { await promptInstalar.userChoice } catch {}
  promptInstalar = null
  instalable.value = false
}
onMounted(() => window.addEventListener('beforeinstallprompt', alPedirInstalar))
onBeforeUnmount(() => window.removeEventListener('beforeinstallprompt', alPedirInstalar))
</script>

<style scoped>
.hb__bolsillo { background: var(--hb-bosque); color: var(--hb-papel-claro); padding: clamp(56px, 8vw, 100px) 0; overflow: hidden; }
.hb__bolsillo-in { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, .8fr); gap: clamp(32px, 6vw, 80px); align-items: center; }
.hb__bolsillo-txt > p:not(.hb__ceja):not(.hb__instalar-ayuda) { margin: 16px 0 0; color: color-mix(in srgb, var(--hb-papel-claro) 78%, transparent); max-width: 32em; }
.hb__pasos { list-style: none; margin: 22px 0 0; padding: 0; display: grid; gap: 10px; }
.hb__pasos li { display: flex; align-items: center; gap: 12px; }
.hb__pasos span { width: 28px; height: 28px; border-radius: 50%; display: grid; place-items: center; border: 1px solid var(--hb-menta); color: var(--hb-menta); font: 500 13px var(--hb-mono); flex-shrink: 0; }
.hb__instalar-ayuda { margin: 16px 0 0; font-size: 13px; color: color-mix(in srgb, var(--hb-papel-claro) 60%, transparent); }
.hb__instalar-ayuda b { color: var(--hb-papel-claro); font-weight: 600; }
@media (max-width: 860px) { .hb__bolsillo-in { grid-template-columns: minmax(0, 1fr); } }

.hb__tel {
  justify-self: center; width: min(300px, 100%); aspect-ratio: 9 / 18.5; padding: 10px;
  border-radius: 44px; background: #0c1a12; box-shadow: 0 40px 80px -30px rgb(0 0 0 / .6), inset 0 0 0 2px rgb(255 255 255 / .08);
  transform: rotate(-3deg);
}
.hb__tel.hb-rev--on { transform: rotate(-3deg); }
.hb__tel-pantalla { height: 100%; border-radius: 34px; overflow: hidden; background: var(--hb-papel-claro); color: var(--hb-tinta); display: flex; flex-direction: column; font-family: var(--hb-sans); }
.hb__tel-hero { background: linear-gradient(160deg, #1F4A33, #2E6B4A); color: #fff; padding: 34px 16px 16px; border-radius: 0 0 22px 22px; display: flex; flex-direction: column; gap: 3px; }
.hb__tel-fase { font: 600 10px var(--hb-mono); letter-spacing: .08em; opacity: .9; }
.hb__tel-fase i { font-style: normal; background: rgb(255 255 255 / .18); border-radius: 99px; padding: 1px 6px; margin-left: 4px; }
.hb__tel-cod { font: 700 24px var(--hb-sans); letter-spacing: -.01em; }
.hb__tel-gen { font-size: 12px; opacity: .8; }
.hb__tel-falta { margin-top: 6px; font-size: 11px; background: rgb(255 255 255 / .12); border-radius: 99px; padding: 4px 10px; align-self: flex-start; }
.hb__tel-stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 5px; margin-top: 10px; }
.hb__tel-stats div { background: rgb(255 255 255 / .1); border-radius: 10px; padding: 6px 2px; text-align: center; display: flex; flex-direction: column; }
.hb__tel-stats b { font-size: 13px; }
.hb__tel-stats small { font-size: 9px; opacity: .75; }
.hb__tel-cta { margin: 12px 12px 0; background: var(--hb-bosque); color: #fff; border-radius: 14px; padding: 10px 12px; font: 600 13px var(--hb-sans); display: flex; flex-direction: column; }
.hb__tel-cta small { font-weight: 400; font-size: 10.5px; opacity: .75; }
.hb__tel-feed { padding: 10px 12px; display: grid; gap: 8px; }
.hb__tel-item { display: flex; gap: 9px; align-items: center; background: #fff; border: 1px solid var(--hb-regla); border-radius: 12px; padding: 8px 10px; font-size: 12px; }
.hb__tel-item > span { width: 28px; height: 28px; flex-shrink: 0; display: grid; place-items: center; border-radius: 8px; background: var(--hb-salvia-suave); color: var(--hb-verde); }
.hb__tel-item div { display: flex; flex-direction: column; }
.hb__tel-item small { color: var(--hb-tinta-2); font-size: 10.5px; }
.hb__tel-nav { margin-top: auto; display: flex; align-items: center; justify-content: space-around; padding: 10px 8px 14px; border-top: 1px solid var(--hb-regla); font-size: 10.5px; color: var(--hb-tinta-2); }
.hb__tel-nav--on { color: var(--hb-verde); font-weight: 700; }
.hb__tel-nav b { width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; background: var(--hb-verde); color: #fff; font-size: 20px; font-weight: 400; margin-top: -18px; box-shadow: 0 6px 14px -6px rgb(46 107 74 / .8); }

</style>
