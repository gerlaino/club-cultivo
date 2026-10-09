<template>
  <PaginaPublica :accion="null">
    <!-- ── Portada: el texto y la lámina ──────────────────── -->
    <!-- En pantallas anchas la planta es el fondo de la portada, de borde a borde, y el texto va
         encima a la izquierda. En el teléfono, el texto y debajo la planta. -->
    <section class="hb__portada" :class="{ 'hb__portada--ancha': ancha }">
      <PlantaCreciendo v-if="ancha" :key="'ancha'" portada />
      <div class="hb__wrap hb__portada-in">
        <div class="hb__portada-txt">
          <p class="hb__ceja">Cuaderno de cultivo · de la semilla a la cosecha</p>
          <h1 class="hb__h1">Cada planta tiene su historia. <em>Escribila mientras crece.</em></h1>
          <p class="hb__bajada">
            Riegos, nutrientes, fotos, fases y cosecha, anotados en el teléfono en el momento en que
            pasan. Para tu autocultivo y para los proyectos que cultivan y dispensan.
          </p>
          <div class="hb__acciones">
            <RouterLink to="/bienvenida/autocultivo" class="hb__btn">
              Autocultivo
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </RouterLink>
            <RouterLink to="/bienvenida/proyectos" class="hb__btn hb__btn--linea">Tengo un proyecto</RouterLink>
          </div>
          <p class="hb__nota">{{ diasPrueba }} días gratis en autocultivo · sin tarjeta · entrás en el momento</p>
        </div>
      </div>
      <div v-if="!ancha" class="hb__lamina">
        <PlantaCreciendo :key="'angosta'" />
      </div>
    </section>

    <!-- ── Las dos puertas (9-oct-2026): para quién es cada una, cómo se ve y desde cuánto ── -->
    <section class="hb__sec lv__puertas">
      <div class="hb__wrap">
        <h2 class="hb__h2">¿Para qué la querés?</h2>
        <div class="lv__grilla">
          <RouterLink to="/bienvenida/autocultivo" class="lv__puerta">
            <p class="hb__ceja">Autocultivo</p>
            <h3 class="lv__puerta-t">Cultivo en casa</h3>
            <p class="lv__puerta-d">Tu carpa, tu balcón o tu cama de suelo vivo. Cada planta con su diario, lo que le diste y lo que viene.</p>
            <div class="lv__muestra"><MuestraCiclo casa /></div>
            <div class="lv__pie">
              <div>
                <p v-if="precioAuto" class="lv__precio">{{ precioAuto }} <span>por mes</span></p>
                <p class="lv__nota">{{ diasPrueba }} días gratis · sin tarjeta</p>
              </div>
              <span class="hb__btn">Probar gratis</span>
            </div>
          </RouterLink>
          <RouterLink to="/bienvenida/proyectos" class="lv__puerta lv__puerta--proy">
            <p class="hb__ceja">Proyectos</p>
            <h3 class="lv__puerta-t">Asociaciones, fundaciones y producción</h3>
            <p class="lv__puerta-d">Del cultivo al mostrador, cada gramo demostrable. Con el consultorio y el turnero adentro.</p>
            <div class="lv__muestra"><MuestraCadena /></div>
            <div class="lv__pie">
              <div>
                <p v-if="precioProy" class="lv__precio">Desde {{ precioProy }} <span>por mes</span></p>
                <p class="lv__nota">Armamos la cuenta y cargamos tu padrón</p>
              </div>
              <span class="hb__btn hb__btn--linea">Conocer más</span>
            </div>
          </RouterLink>
        </div>
      </div>
    </section>

    <section class="hb__sec hb__sec--claro">
      <div class="hb__wrap lv__confianza">
        <div><h3 class="hb__h3">Tus datos son tuyos</h3><p>No se venden ni se usan para publicidad. Cada cuenta está aislada y hay copias de seguridad verificadas.</p></div>
        <div><h3 class="hb__h3">Anda en el teléfono</h3><p>Se instala desde el navegador en segundos, sin tiendas. Y sin señal también anota.</p></div>
        <div><h3 class="hb__h3">Pensada para la Argentina</h3><p>REPROCANN e INASE adentro, con informes que salen de lo que ya cargaste.</p></div>
      </div>
    </section>
  </PaginaPublica>
</template>

<script setup>
// LA PORTADA PÚBLICA (/bienvenida), en la dirección «Herbario»: la planta que crece y las dos
// opciones, nada más (Germán y Javi, 5-oct-2026).
//
// Cada público entra a SU página —/bienvenida/autocultivo (uso personal, se registra solo) y
// /bienvenida/proyectos (organizaciones: la cuenta se arma a mano desde el contacto)—, para que
// nadie lea lo del otro. Lo que antes vivía acá (qué hace, el teléfono, preguntas, contacto,
// principios) se repartió entre esas páginas y /contacto; los packs con precios van adentro de
// cada una (acá no se repiten: 7-oct-2026). Los días de prueba los dice el backend.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import PlantaCreciendo from '../components/public/PlantaCreciendo.vue'
import MuestraCiclo from '../components/public/muestras/MuestraCiclo.vue'
import MuestraCadena from '../components/public/muestras/MuestraCadena.vue'
import { getRegistroInfo } from '../lib/api.js'

const diasPrueba = ref(30)
// Los precios los dice el backend (`Precios.lista_publica`): sin respuesta, no se muestra un número.
const precioAuto = ref('')
const precioProy = ref('')
const plata = (n, moneda) => (moneda === 'USD' ? `US$ ${n}` : `$ ${n}`)

// Portada ancha (planta de fondo) o angosta (apilada). Se decide por el ancho y se re-arma si cambia.
const consultaAncha = typeof window !== 'undefined' ? window.matchMedia('(min-width: 960px)') : null
const ancha = ref(!!consultaAncha?.matches)
const alCambiarAncho = (e) => { ancha.value = e.matches }

onMounted(async () => {
  consultaAncha?.addEventListener('change', alCambiarAncho)
  try {
    const { data } = await getRegistroInfo()
    diasPrueba.value = data.dias_prueba
    const p = data.precios
    if (p?.autocultivo) precioAuto.value = plata(p.autocultivo.precio, p.moneda)
    const min = Math.min(...(p?.escalones || []).map(e => e.un_pack))
    if (Number.isFinite(min)) precioProy.value = plata(min, p.moneda)
  } catch {}
})
onBeforeUnmount(() => consultaAncha?.removeEventListener('change', alCambiarAncho))
</script>

<style scoped>
/* ── Portada ── */
.hb__portada {
  position: relative; overflow: hidden;
  padding: clamp(32px, 6vw, 72px) 0 8px;
  background:
    radial-gradient(60% 70% at 80% 30%, color-mix(in srgb, var(--hb-menta) 32%, transparent) 0%, transparent 70%),
    radial-gradient(50% 60% at 0% 100%, color-mix(in srgb, var(--hb-salvia) 38%, transparent) 0%, transparent 70%);
}
/* Ancha: ocupa la pantalla y la planta es el fondo; el texto, encima y a la izquierda. Llega
   hasta el pie: la franja de precios que cerraba la portada se sacó (Germán, 7-oct: los precios
   ya están en autocultivo y proyectos). */
.hb__portada--ancha { min-height: max(600px, calc(100svh - 64px)); display: flex; align-items: center; padding: 0; }
.hb__portada--ancha .hb__portada-in { position: relative; z-index: 2; pointer-events: none; padding-bottom: 90px; }
.hb__portada--ancha .hb__portada-txt { pointer-events: auto; max-width: 540px; }
.hb__portada-txt { min-width: 0; }
/* ── Las dos puertas ── */
.lv__puertas .hb__h2 { margin-bottom: 24px; }
.lv__grilla { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 340px), 1fr)); gap: 20px; }
.lv__puerta {
  display: flex; flex-direction: column; gap: 14px; padding: 28px; text-decoration: none; color: var(--hb-tinta);
  background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); transition: border-color .15s, box-shadow .15s;
}
.lv__puerta:hover { border-color: var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia); }
.lv__puerta--proy { border-top: 4px solid var(--hb-bosque); }
.lv__puerta .hb__ceja { margin: 0; }
.lv__puerta-t { margin: 0; font: 600 clamp(1.5rem, 2.4vw, 2rem)/1.1 var(--hb-serif); }
.lv__puerta-d { margin: 0; color: var(--hb-tinta-2); line-height: 1.5; }
.lv__muestra { padding: 18px; background: var(--hb-papel); border: 1px solid var(--hb-regla); pointer-events: none; }
.lv__pie { margin-top: auto; display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
.lv__precio { margin: 0; font: 600 1.4rem var(--hb-serif); }
.lv__precio span { font: 13px var(--hb-mono); color: var(--hb-tinta-2); }
.lv__nota { margin: 2px 0 0; font-size: .9rem; color: var(--hb-tinta-2); }
.lv__confianza { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 28px; }
.lv__confianza p { margin: 8px 0 0; color: var(--hb-tinta-2); line-height: 1.55; }

/* Angosta: la planta debajo del texto, sin recuadro. */
.hb__lamina { max-width: 480px; margin: 18px auto 0; padding: 0 16px 24px; }
</style>
