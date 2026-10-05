<template>
  <PaginaPublica>
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
            <a href="#que-hace" class="hb__btn hb__btn--linea">Ver qué hace</a>
          </div>
          <p class="hb__nota">La cuenta se arma a medida · precio a consultar</p>
        </div>
        <!-- La cadena del gramo, en chico: es la idea de toda la página. -->
        <ol class="lp__cadena hb-rev" aria-label="La cadena de un gramo">
          <li v-for="(e, i) in CADENA" :key="e" :style="{ transitionDelay: `${i * 70}ms` }"><span>{{ String(i + 1).padStart(2, '0') }}</span>{{ e }}</li>
        </ol>
      </div>
    </section>

    <!-- ── El consultorio: el diferencial, con sección propia y arriba ── -->
    <section class="lp__medico" id="consultorio">
      <div class="hb__wrap lp__medico-in">
        <div class="lp__medico-txt">
          <p class="hb__ceja hb__ceja--claro">Módulo médico · viene con Producción y dispensa</p>
          <h2 class="hb__h2">El consultorio y el turnero, adentro</h2>
          <p>
            Los médicos de la organización atienden en el mismo sistema donde se cultiva y se dispensa.
            La agenda, la historia clínica y la indicación de cada paciente están al lado de lo que
            retira: nada en una planilla aparte ni en otro programa.
          </p>
          <ul class="hb__lista lp__medico-lista">
            <li v-for="x in MEDICO" :key="x">{{ x }}</li>
          </ul>
        </div>
        <figure ref="laminaMedico" class="lp__medico-lamina">
          <MuestraTurnero v-if="medicoVisto" />
          <figcaption class="lp__medico-pie">Ejemplo · datos ficticios</figcaption>
        </figure>
      </div>
    </section>

    <QueHace titulo="Todo el ciclo, de la semilla hasta la casa del paciente" :temas="TEMAS_PROYECTOS" />

    <!-- ── Una vista por oficio ───────────────────────────── -->
    <section class="hb__sec">
      <div class="hb__wrap">
        <header class="hb__sec-h">
          <p class="hb__ceja">El equipo</p>
          <h2 class="hb__h2">Una vista por oficio</h2>
          <p class="lp__sec-p">Cada persona entra con su usuario y ve lo que necesita para su trabajo. Nada más.</p>
        </header>
        <div class="lp__oficios">
          <article v-for="(o, i) in OFICIOS" :key="o.quien" class="lp__oficio hb-rev" :style="{ transitionDelay: `${(i % 3) * 80}ms` }">
            <h3 class="hb__h3">{{ o.quien }}</h3>
            <p>{{ o.que }}</p>
          </article>
        </div>
      </div>
    </section>

    <Packs :packs="PACKS_PROYECTOS" :accion="{ label: 'Lo quiero', to: '#contacto' }" />

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
// LA PÁGINA DE «PROYECTOS» (/bienvenida/proyectos, 5-oct-2026): asociaciones, fundaciones,
// investigación y producción. «Proyecto» es la palabra de la página pública (Germán); adentro de
// la app la entidad sigue siendo «organización». Termina en el formulario de contacto: la cuenta
// de una organización se arma a mano. Contenido en `components/public/contenido.js`.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import QueHace from '../components/public/QueHace.vue'
import PreguntasFrecuentes from '../components/public/PreguntasFrecuentes.vue'
import ContactoForm from '../components/public/ContactoForm.vue'
import Packs from '../components/public/Packs.vue'
import MuestraTurnero from '../components/public/muestras/MuestraTurnero.vue'
import { TEMAS_PROYECTOS, PREGUNTAS_PROYECTOS, OFICIOS, PACKS_PROYECTOS } from '../components/public/contenido.js'

const CADENA = ['Genética', 'Lote', 'Planta', 'Cosecha', 'Stock', 'Entrega']

// Lo que hace el módulo médico HOY (Turno, DisponibilidadMedico, IndicacionMedica, prescripción
// PDF, alertas internas). El seguimiento de bienestar (CheckIn) existe en la base pero no tiene
// pantalla: no se nombra hasta que la tenga.
const MEDICO = [
  'Cada médico carga su horario de la semana y los turnos se dan sobre esa agenda',
  'Primera vez, seguimiento, revisión o urgencia; confirmado, realizado o ausente',
  'Historia clínica en la misma ficha del paciente, con notas que sólo ve el médico',
  'Indicación médica con vencimiento y aviso antes de que venza; prescripción en PDF',
  'Lo clínico va cifrado en la base',
]

// La muestra del turnero se monta cuando la lámina entra en pantalla, así su animación se ve.
const laminaMedico = ref(null)
const medicoVisto = ref(false)
let obs = null
onMounted(() => {
  if (!('IntersectionObserver' in window) || !laminaMedico.value) { medicoVisto.value = true; return }
  obs = new IntersectionObserver((es) => { if (es.some(e => e.isIntersecting)) { medicoVisto.value = true; obs.disconnect() } }, { threshold: 0.3 })
  obs.observe(laminaMedico.value)
})
onBeforeUnmount(() => obs?.disconnect())
</script>

<style scoped>
.lp__portada {
  padding: clamp(40px, 7vw, 88px) 0 clamp(32px, 5vw, 64px);
  background: radial-gradient(55% 70% at 85% 40%, color-mix(in srgb, var(--hb-salvia) 40%, transparent) 0%, transparent 70%);
}
.lp__portada-in { display: grid; grid-template-columns: minmax(0, 1.2fr) minmax(0, .8fr); gap: clamp(24px, 5vw, 64px); align-items: center; }
@media (max-width: 860px) { .lp__portada-in { grid-template-columns: minmax(0, 1fr); } }

.lp__cadena {
  list-style: none; margin: 0 6px 6px 0; padding: 22px 24px; display: grid; gap: 0;
  background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia);
}
.lp__cadena li { display: flex; align-items: baseline; gap: 14px; padding: 10px 0; font: 600 1.25rem var(--hb-serif); color: var(--hb-tinta); }
.lp__cadena li + li { border-top: 1px dashed var(--hb-regla); }
.lp__cadena li span { font: 500 12px var(--hb-mono); color: var(--hb-ambar); }

.lp__medico { background: var(--hb-bosque); color: var(--hb-papel-claro); padding: clamp(56px, 8vw, 100px) 0; scroll-margin-top: 64px; }
.lp__medico-in { display: grid; grid-template-columns: minmax(0, .9fr) minmax(0, 1.1fr); gap: clamp(28px, 5vw, 64px); align-items: center; }
@media (max-width: 960px) { .lp__medico-in { grid-template-columns: minmax(0, 1fr); } }
.lp__medico-txt > p:not(.hb__ceja) { margin: 16px 0 0; max-width: 34em; color: color-mix(in srgb, var(--hb-papel-claro) 80%, transparent); }
.lp__medico-lista { margin-top: 22px; }
.lp__medico-lista li::before { background: var(--hb-menta); }
.lp__medico-lamina { margin: 0 6px 6px 0; min-height: 380px; display: flex; flex-direction: column; padding: clamp(16px, 3vw, 24px); background: var(--hb-papel); color: var(--hb-tinta); border: 1.5px solid var(--hb-menta); box-shadow: 6px 6px 0 color-mix(in srgb, var(--hb-menta) 45%, transparent); }
.lp__medico-lamina > :first-child { flex: 1; }
.lp__medico-pie { margin-top: 14px; padding-top: 10px; border-top: 1px dashed var(--hb-regla); font: 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }

.lp__sec-p { margin: 14px 0 0; max-width: 36em; color: var(--hb-tinta-2); }

.lp__oficios { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 340px), 1fr)); gap: 0; border-top: 1px solid var(--hb-tinta); }
.lp__oficio { padding: 22px 22px 22px 0; border-bottom: 1px solid var(--hb-regla); display: flex; flex-direction: column; gap: 8px; }
.lp__oficio p { margin: 0; color: var(--hb-tinta-2); }

.lp__contacto { display: grid; grid-template-columns: minmax(0, .8fr) minmax(0, 1fr); gap: clamp(28px, 5vw, 64px); align-items: start; }
@media (max-width: 860px) { .lp__contacto { grid-template-columns: minmax(0, 1fr); } }
</style>
