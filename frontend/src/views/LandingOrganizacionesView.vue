<template>
  <PaginaPublica :accion="{ label: 'Hablemos', to: '#contacto' }">
    <!-- ── Portada: el panel de administración (quien contrata conduce la organización) ── -->
    <section class="lp__portada">
      <div class="hb__wrap lp__portada-in">
        <div>
          <p class="hb__ceja">Organizaciones · asociaciones, fundaciones y producción</p>
          <h1 class="hb__h1">Toda tu organización, <em>en un solo panel.</em></h1>
          <p class="hb__bajada">
            Cultivo, stock, dispensas, caja y consultorio, al día. Tu equipo trabaja desde el teléfono
            y vos sabés cómo va cada área sin estar en cada sala.
          </p>
          <div class="hb__acciones">
            <a href="#contacto" class="hb__btn">
              Contanos de tu organización
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </a>
            <a href="#precios" class="hb__btn hb__btn--linea">Ver precios</a>
          </div>
          <p class="hb__nota">Armamos la cuenta con ustedes · cargamos tu padrón, genéticas y stock</p>
        </div>
        <PanelAdmin />
      </div>
    </section>

    <!-- ── El alcance, en cuatro datos ── -->
    <section class="lp__alcance" aria-label="Alcance">
      <div class="hb__wrap lp__alcance-in">
        <div v-for="a in ALCANCE" :key="a.n" class="lp__dato">
          <span class="lp__dato-n">{{ a.n }} <em>{{ a.que }}</em></span>
          <span class="lp__dato-t">{{ a.t }}</span>
        </div>
      </div>
    </section>

    <!-- ── Lo que ve administración: una fortaleza por fila, con su pantalla ── -->
    <section class="hb__sec" id="que-hace">
      <div class="hb__wrap">
        <header class="lp__fz-cab">
          <p class="hb__ceja">Desde administración</p>
          <h2 class="hb__h2">Lo que ves sin pedirle nada a nadie</h2>
          <p class="lp__sec-p">Pantallas de la app con datos de ejemplo.</p>
        </header>

        <Fortaleza ceja="Caja y cuenta corriente" titulo="Cada peso," enfasis="en su caja."
                   texto="Cada dispensa queda cobrada por medio de pago y quien atiende cierra su caja contando. Vos ves lo que entró, lo que se debe y lo que quedó a favor de cada paciente."
                   :puntos="['Cierre de caja firmado; lo que entra después no lo mueve', 'Lo pagado de más se descuenta solo en la próxima', 'Una dispensa no se borra: se anula con motivo']">
          <MuestraTicket />
        </Fortaleza>

        <Fortaleza invertida ceja="Trazabilidad" titulo="Cada gramo," enfasis="de la planta a la entrega."
                   texto="Lo trazable sólo sale del inventario con una dispensa. Si algo falta, se ve, y sabés de qué lote y de qué cosecha era."
                   :puntos="['Cada planta con su QR y su historia completa', 'Stock por sede y por depósito, con cada movimiento', 'El paciente escanea el QR de su retiro y ve la genética que se llevó']">
          <MuestraCadena />
        </Fortaleza>

        <Fortaleza ceja="Cultivo" titulo="El cultivo," enfasis="sin pisar la sala."
                   texto="Cada sala con su fase, sus lotes y las tareas del día. El equipo marca lo hecho y lo que no se hizo desde el teléfono, y lo ves en el momento."
                   :puntos="['Tareas armadas según la fase de cada lote', 'Rendimiento en g/m² por cosecha, genética y sala', 'Plantas en floración contra el tope de tu plan']">
          <MuestraSalas />
        </Fortaleza>

        <Fortaleza invertida ceja="Registro por voz · asistente IA" titulo="Tu equipo carga hablando." enfasis="Nada queda sin anotar."
                   texto="Con los guantes puestos, el cultivador cuenta qué hizo y el asistente lo arma como riegos, nutrientes y tareas. Confirma, y ya está en tu panel."
                   :puntos="['Riegos con receta: descuentan del depósito solos', 'El dictado también propone tareas para mañana', 'Lee la planilla del datalogger por vos']">
          <MuestraIa />
        </Fortaleza>

        <Fortaleza ceja="Módulo médico · incluido" titulo="El consultorio," enfasis="adentro."
                   texto="Los médicos atienden en el mismo sistema donde se cultiva y se dispensa. La agenda, la historia clínica y la indicación de cada paciente están al lado de lo que retira."
                   :puntos="['Turnos sobre el horario de cada médico, con aviso al teléfono', 'Indicación con vencimiento y prescripción en PDF', 'El médico ve sólo a sus pacientes; lo clínico va cifrado']">
          <MuestraTurnero />
        </Fortaleza>

        <Fortaleza invertida ceja="Informes" titulo="El día que te los piden," enfasis="ya están hechos."
                   texto="Producción, inventario, pérdidas, dispensaciones, REPROCANN e INASE, en PDF y Excel, con el balance que cuadra y el costo de cada gramo."
                   :puntos="['Del mismo período que estás mirando en pantalla', 'Por sede o de toda la organización', 'Salen de lo que se cargó trabajando']">
          <MuestraInforme />
        </Fortaleza>
      </div>
    </section>

    <!-- Una vista por rol: administración primero; delivery con la entrega simulada. -->
    <OficiosVista />

    <PreciosProyectos :precios="precios" />

    <PreguntasFrecuentes titulo="Lo que nos preguntan las organizaciones" :preguntas="PREGUNTAS_PROYECTOS" contacto="#contacto" />

    <!-- ── Contacto: acá se cierra ────────────────────────── -->
    <section class="hb__sec hb__sec--claro" id="contacto">
      <div class="hb__wrap lp__contacto">
        <div>
          <p class="hb__ceja">Contacto</p>
          <h2 class="hb__h2">Contanos de tu organización</h2>
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
// LA PÁGINA DE ORGANIZACIONES (/bienvenida/organizaciones; hasta el 9-oct-2026 «proyectos», que
// redirige acá): asociaciones, fundaciones, investigación y producción. Termina en el formulario de
// contacto: la cuenta de una organización se arma a mano.
//
// Rearmada el 9-oct-2026 con el enfoque de quien contrata: el administrador conduce la
// organización, no riega todos los días; quiere monitorear y controlar todo sin estar en cada
// sala. Por eso abre con el panel de administración, cada fortaleza se cuenta desde lo que ve
// administración, y en «Una vista por rol» administración va primero. Lo que se afirma tiene que
// existir hoy en la app (regla de `components/public/contenido.js`).
import { ref, onMounted } from 'vue'
import PaginaPublica from '../components/public/PaginaPublica.vue'
import PanelAdmin from '../components/public/PanelAdmin.vue'
import Fortaleza from '../components/public/Fortaleza.vue'
import PreguntasFrecuentes from '../components/public/PreguntasFrecuentes.vue'
import ContactoForm from '../components/public/ContactoForm.vue'
import OficiosVista from '../components/public/OficiosVista.vue'
import PreciosProyectos from '../components/public/PreciosProyectos.vue'
import MuestraTicket from '../components/public/muestras/MuestraTicket.vue'
import MuestraCadena from '../components/public/muestras/MuestraCadena.vue'
import MuestraSalas from '../components/public/muestras/MuestraSalas.vue'
import MuestraIa from '../components/public/muestras/MuestraIa.vue'
import MuestraTurnero from '../components/public/muestras/MuestraTurnero.vue'
import MuestraInforme from '../components/public/muestras/MuestraInforme.vue'
import { getRegistroInfo } from '../lib/api.js'
import { PREGUNTAS_PROYECTOS } from '../components/public/contenido.js'

const ALCANCE = [
  { n: 8, que: 'áreas',     t: 'Cultivo, post-cosecha, stock, mostrador, consultorio, delivery, contabilidad e informes' },
  { n: 6, que: 'roles',     t: 'Cada persona entra con su usuario y ve su pantalla' },
  { n: 1, que: 'gramo',     t: 'Se sigue de la genética a la entrega, con firma' },
  { n: 0, que: 'planillas', t: 'REPROCANN e INASE salen de lo que ya se cargó' },
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
.lp__portada-in { display: grid; grid-template-columns: minmax(0, .85fr) minmax(0, 1.15fr); gap: clamp(28px, 4vw, 64px); align-items: center; }
@media (max-width: 1000px) { .lp__portada-in { grid-template-columns: minmax(0, 1fr); } }

.lp__portada .hb__h1 { font-size: clamp(2.2rem, 4.6vw, 3.6rem); }

/* El alcance, en cuatro datos */
.lp__alcance { background: var(--hb-papel-claro); border-block: 1px solid var(--hb-regla); }
.lp__alcance-in { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); }
.lp__dato { padding: 26px 24px 24px 0; display: grid; gap: 4px; align-content: start; }
.lp__dato + .lp__dato { padding-left: 24px; border-left: 1px solid var(--hb-regla); }
.lp__dato-n { font: 600 clamp(1.7rem, 2.6vw, 2.2rem)/1 var(--hb-serif); letter-spacing: -.02em; color: var(--hb-tinta); }
.lp__dato-n em { font-style: italic; font-weight: 400; color: var(--hb-verde); }
.lp__dato-t { font-size: .92rem; color: var(--hb-tinta-2); line-height: 1.45; }
@media (max-width: 860px) {
  .lp__alcance-in { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .lp__dato, .lp__dato + .lp__dato { padding: 20px 16px 18px 0; border-left: 0; }
  .lp__dato:nth-child(even) { padding-left: 16px; border-left: 1px solid var(--hb-regla); }
  .lp__dato:nth-child(n+3) { border-top: 1px solid var(--hb-regla); }
}
.lp__fz-cab { max-width: 46em; margin-bottom: clamp(16px, 3vw, 28px); }

.lp__sec-p { margin: 14px 0 0; max-width: 36em; color: var(--hb-tinta-2); }

.lp__contacto { display: grid; grid-template-columns: minmax(0, .8fr) minmax(0, 1fr); gap: clamp(28px, 5vw, 64px); align-items: start; }
@media (max-width: 860px) { .lp__contacto { grid-template-columns: minmax(0, 1fr); } }
</style>
