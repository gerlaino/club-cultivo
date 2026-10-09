<template>
  <PaginaPublica :accion="{ label: 'Hablemos', to: '#contacto' }">
    <!-- ── Portada de proyectos ───────────────────────────── -->
    <section class="lp__portada">
      <div class="hb__wrap lp__portada-in">
        <div>
          <p class="hb__ceja">Proyectos · asociaciones, fundaciones, investigación y producción</p>
          <h1 class="hb__h1">Del cultivo al mostrador, <em>cada gramo demostrable.</em></h1>
          <p class="hb__bajada">
            La genética, el lote, la planta, la cosecha, el stock y la entrega en un solo lugar, con el
            consultorio y el turnero adentro. Cada persona del equipo ve lo suyo, y los informes salen
            de lo que ya se cargó operando.
          </p>
          <div class="hb__acciones">
            <a href="#contacto" class="hb__btn">
              Contanos de tu proyecto
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </a>
            <a href="#precios" class="hb__btn hb__btn--linea">Ver precios</a>
          </div>
        </div>
        <!-- La cadena del gramo, animada: es la idea de toda la página (antes era una lista de palabras). -->
        <figure class="lp__cadena">
          <p class="lp__cadena-t">Un gramo, de punta a punta</p>
          <MuestraCadena />
          <figcaption class="lp__pie">Ejemplo · datos ficticios</figcaption>
        </figure>
      </div>
    </section>

    <QueHace titulo="Todo el ciclo, de la semilla hasta la casa del paciente" :temas="TEMAS_PROYECTOS" />

    <!-- Una vista por oficio: al tocar cada rol se ve su pantalla. El consultorio vive acá (antes
         tenía sección propia arriba de todo). -->
    <OficiosVista />

    <!-- ── Cómo arrancamos ───────────────────────────────── -->
    <section class="hb__sec hb__sec--claro">
      <div class="hb__wrap">
        <header class="hb__sec-h">
          <p class="hb__ceja">Cómo arrancamos</p>
          <h2 class="hb__h2">Sin cargar todo de nuevo</h2>
        </header>
        <ol class="lp__pasos">
          <li v-for="(p, i) in ARRANQUE" :key="p.t" class="lp__paso hb-rev" :style="{ transitionDelay: `${i * 90}ms` }">
            <span class="lp__paso-n">{{ i + 1 }}</span>
            <h3 class="hb__h3">{{ p.t }}</h3>
            <p>{{ p.d }}</p>
          </li>
        </ol>
      </div>
    </section>

    <PreciosProyectos :precios="precios" />

    <PreguntasFrecuentes titulo="Lo que nos preguntan los proyectos" :preguntas="PREGUNTAS_PROYECTOS" contacto="#contacto" />

    <!-- ── Contacto: acá se cierra ────────────────────────── -->
    <section class="hb__sec hb__sec--claro" id="contacto">
      <div class="hb__wrap lp__contacto">
        <div>
          <p class="hb__ceja">Contacto</p>
          <h2 class="hb__h2">Contanos de tu proyecto</h2>
          <p class="lp__sec-p">
            Qué hacen, cuántas sedes y cuántas personas. Te armamos la cuenta y la propuesta, y si
            tienen padrón, genéticas o stock en planillas, los importamos nosotros.
          </p>
        </div>
        <ContactoForm tipo-inicial="organizacion" :tipos="['organizacion']" />
      </div>
    </section>
  </PaginaPublica>
</template>

<script setup>
// LA PÁGINA DE «PROYECTOS» (/bienvenida/proyectos): asociaciones, fundaciones, investigación y
// producción. «Proyecto» es la palabra de la página pública (Germán); adentro de la app la entidad
// sigue siendo «organización». Termina en el formulario de contacto: la cuenta de una organización
// se arma a mano. Contenido en `components/public/contenido.js`.
//
// Rearmada el 9-oct-2026: la cadena del gramo animada arriba, «Todo el ciclo» en solapas, el
// consultorio adentro de «Una vista por oficio» (cada rol con su pantalla), «Cómo arrancamos» y
// precios comparables con «un pack / los dos». Fuera «precio a consultar», que contradecía los
// precios de la misma página.
import { ref, onMounted } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import QueHace from '../components/public/QueHace.vue'
import PreguntasFrecuentes from '../components/public/PreguntasFrecuentes.vue'
import ContactoForm from '../components/public/ContactoForm.vue'
import OficiosVista from '../components/public/OficiosVista.vue'
import PreciosProyectos from '../components/public/PreciosProyectos.vue'
import MuestraCadena from '../components/public/muestras/MuestraCadena.vue'
import { getRegistroInfo } from '../lib/api.js'
import { TEMAS_PROYECTOS, PREGUNTAS_PROYECTOS } from '../components/public/contenido.js'

const ARRANQUE = [
  { t: 'Una charla', d: 'Nos cuentan cómo trabajan: sedes, equipo, qué cultivan y qué dispensan.' },
  { t: 'Cargamos lo que tienen', d: 'Padrón de pacientes, genéticas y stock, desde sus planillas. No se tipea de nuevo.' },
  { t: 'Cada uno entra con su usuario', d: 'Les mostramos la app por oficio y quedan andando.' },
]

// Los precios los dice el backend (`Precios.lista_publica`); acá sólo las palabras.
const precios = ref(null)
onMounted(async () => {
  try { precios.value = (await getRegistroInfo()).data.precios } catch {}
})
</script>

<style scoped>
.lp__portada {
  padding: clamp(40px, 7vw, 88px) 0 clamp(32px, 5vw, 64px);
  background: radial-gradient(55% 70% at 85% 40%, color-mix(in srgb, var(--hb-salvia) 40%, transparent) 0%, transparent 70%);
}
.lp__portada-in { display: grid; grid-template-columns: minmax(0, 1.15fr) minmax(0, .85fr); gap: clamp(24px, 5vw, 64px); align-items: center; }
@media (max-width: 860px) { .lp__portada-in { grid-template-columns: minmax(0, 1fr); } }

.lp__cadena {
  margin: 0 6px 6px 0; padding: 22px 24px;
  background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia);
}
.lp__cadena-t { margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-tinta-2); }
.lp__pie { margin-top: 14px; padding-top: 10px; border-top: 1px dashed var(--hb-regla); font: 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }

.lp__sec-p { margin: 14px 0 0; max-width: 36em; color: var(--hb-tinta-2); }
.lp__pasos { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 20px; }
.lp__paso { border-top: 3px solid var(--hb-verde); padding-top: 16px; display: flex; flex-direction: column; gap: 8px; }
.lp__paso p { margin: 0; color: var(--hb-tinta-2); line-height: 1.55; }
.lp__paso-n { font: 600 2rem/1 var(--hb-serif); color: var(--hb-verde); }

.lp__contacto { display: grid; grid-template-columns: minmax(0, .8fr) minmax(0, 1fr); gap: clamp(28px, 5vw, 64px); align-items: start; }
@media (max-width: 860px) { .lp__contacto { grid-template-columns: minmax(0, 1fr); } }
</style>
