<template>
  <section class="qh" id="que-hace">
    <div class="qh__wrap">
      <header class="qh__cab">
        <p class="qh__ceja">Qué hace</p>
        <h2 class="qh__h2">Todo el ciclo, de la semilla hasta la casa del paciente</h2>
      </header>

      <!-- Solapas. Todos los paneles están en la página (v-show): quien busca en Google encuentra
           también lo que está en la solapa que no se ve. La muestra se monta sólo en la activa y
           cuando la lámina ya está en pantalla, así su animación se ve entera cada vez que se abre
           (en el teléfono la lámina queda debajo del texto). -->
      <div class="qh__solapas" role="tablist" aria-label="Qué hace Cultivo Espacial" @keydown="moverConTeclas">
        <button v-for="t in TEMAS" :key="t.id" :id="`qh-tab-${t.id}`" ref="botones" type="button" role="tab"
                class="qh__solapa" :class="{ 'qh__solapa--on': activa === t.id }"
                :aria-selected="activa === t.id" :aria-controls="`qh-panel-${t.id}`"
                :tabindex="activa === t.id ? 0 : -1" @click="activa = t.id">
          {{ t.label }}
        </button>
      </div>

      <div v-for="t in TEMAS" v-show="activa === t.id" :key="t.id" :id="`qh-panel-${t.id}`"
           class="qh__panel" role="tabpanel" :aria-labelledby="`qh-tab-${t.id}`">
        <div>
          <p class="qh__para">
            <span>{{ t.para }}</span>
            <span v-if="t.addon" class="qh__addon">Se suma aparte</span>
          </p>
          <h3 class="qh__h3">{{ t.titulo }}</h3>
          <p class="qh__d">{{ t.texto }}</p>
          <ul class="qh__lista">
            <li v-for="p in t.puntos" :key="p">{{ p }}</li>
          </ul>
        </div>
        <figure ref="laminas" class="qh__lamina">
          <component :is="t.muestra" v-if="activa === t.id && vista" />
          <figcaption class="qh__pie">Ejemplo · datos ficticios</figcaption>
        </figure>
      </div>
    </div>
  </section>
</template>

<script setup>
// «QUÉ HACE» de la página pública (Germán, 5-oct-2026: la portada era linda pero vacía; quien la
// miraba tenía que escribir para enterarse de qué ofrecemos). Una solapa por tema, cada una con
// una muestra dibujada en el estilo de la página — no capturas: la app de adentro tiene otro
// estilo y una captura envejece con cada cambio de pantalla.
//
// Lo que se afirma acá tiene que existir hoy en la app. Lo que se vende aparte (`Club::ADDONS`:
// delivery, IoT, IA) lleva «Se suma aparte». No se nombra lo que está simulado (ARICCAME) ni lo
// que está en prueba (el chatbot).
import { ref, nextTick, onMounted, onBeforeUnmount } from 'vue'
import MuestraCadena from './muestras/MuestraCadena.vue'
import MuestraRendimiento from './muestras/MuestraRendimiento.vue'
import MuestraPesadas from './muestras/MuestraPesadas.vue'
import MuestraTicket from './muestras/MuestraTicket.vue'
import MuestraDelivery from './muestras/MuestraDelivery.vue'
import MuestraAmbiente from './muestras/MuestraAmbiente.vue'
import MuestraIa from './muestras/MuestraIa.vue'
import MuestraInforme from './muestras/MuestraInforme.vue'

const AMBOS = 'En casa y en organizaciones'
const ORGS = 'Organizaciones'

const TEMAS = [
  {
    id: 'trazabilidad', label: 'Trazabilidad', para: AMBOS, muestra: MuestraCadena,
    titulo: 'Cada gramo sabe de dónde viene',
    texto: 'La genética, el lote, la planta, la cosecha, el frasco y la entrega quedan unidos. Desde cualquier punta llegás a la otra en un toque.',
    puntos: [
      'Cada planta con su QR y su historia completa',
      'El frasco sabe de qué cosecha y de qué plantas salió',
      'El paciente escanea el QR de su retiro y ve la genética que se llevó',
      'Lo trazable sólo sale del inventario con una entrega: lo que falta, se ve',
    ],
  },
  {
    id: 'cultivo', label: 'Cultivo', para: AMBOS, muestra: MuestraRendimiento,
    titulo: 'El ciclo, medido',
    texto: 'Lotes y plantas en sus salas, de la semilla o el esqueje a la cosecha, con los próximos pasos del ciclo avisados al teléfono.',
    puntos: [
      'Fases por sala; autos que se quedan en vege todo el ciclo',
      'Riegos, nutrientes con su dosis, pH/EC y fotos por semana',
      'Suelo vivo: la cama vive más que los lotes',
      'Rendimiento en g/m² por cosecha, por genética y por sala',
    ],
  },
  {
    id: 'cosecha', label: 'Cosecha y stock', para: AMBOS, muestra: MuestraPesadas,
    titulo: 'El peso que entra y el que sale',
    texto: 'Secado y curado con sus pesadas, la manicura con aprobación, y el stock por sede y por depósito con cada movimiento a la vista.',
    puntos: [
      'Húmedo, seco y curado: la merma de cada etapa, calculada',
      'Manicura que carga aun sin señal y espera aprobación',
      'Stock por sede y por depósito, con transferencias',
      'Contar no crea stock: una diferencia queda como diferencia',
    ],
  },
  {
    id: 'mostrador', label: 'Mostrador y caja', para: ORGS, muestra: MuestraTicket,
    titulo: 'Dispensar y que la caja cierre',
    texto: 'El mostrador entrega lo que está sobre la mesa y cobra como pague cada paciente. Quien atiende abre contando y cierra sin esperar a nadie.',
    puntos: [
      'Varios productos en una dispensa, varios medios de pago',
      'Cuenta corriente: lo pagado de más se descuenta solo en la próxima',
      'Reservas, anulación con motivo y cierre de caja firmado',
      'Portal del paciente con su credencial y sus retiros (se suma aparte)',
    ],
  },
  {
    id: 'delivery', label: 'Delivery', para: ORGS, addon: true, muestra: MuestraDelivery,
    titulo: 'Hasta la puerta del paciente',
    texto: 'Paquetes armados desde el stock, rutas para quien reparte y la entrega confirmada con firma en el teléfono.',
    puntos: [
      'Rutas del día en el teléfono de quien reparte',
      'Firma de entrega y cobro contra entrega',
      'Lo que no se entregó vuelve al stock, desarmado',
      'Rendición del efectivo dirigida a una persona',
    ],
  },
  {
    id: 'ambiente', label: 'Ambiente e IoT', para: AMBOS, addon: true, muestra: MuestraAmbiente,
    titulo: 'La sala, a la vista',
    texto: 'Temperatura, humedad y VPD de cada sala, desde sensores o desde la planilla de tu datalogger, con aviso cuando algo se sale del rango.',
    puntos: [
      'Sensores conectados (Sonoff u otros) o carga por CSV',
      'VPD calculado con la fase del lote',
      'Rangos por sala y aviso al teléfono',
      'Lectura a mano desde el teléfono cuando no hay sensor',
    ],
  },
  {
    id: 'ia', label: 'Asistente IA', para: AMBOS, addon: true, muestra: MuestraIa,
    titulo: 'Contalo y queda anotado',
    texto: 'Con las manos en la tierra, decís lo que hiciste y el asistente lo convierte en registros. Vos confirmás antes de que se guarde.',
    puntos: [
      'Registro por voz de salas, lotes y plantas',
      'Propone; nada se guarda sin tu confirmación',
      'Arma el plan de trabajo de la semana',
      'Lee la planilla del datalogger por vos',
    ],
  },
  {
    id: 'informes', label: 'Informes y números', para: AMBOS, muestra: MuestraInforme,
    titulo: 'Lo que pide la normativa, de lo que ya cargaste',
    texto: 'Los informes salen de la misma data que se carga operando. Nada se arma aparte el día que te lo piden.',
    puntos: [
      'REPROCANN, INASE, producción, inventario y pérdidas',
      'Siempre se descargan; «para presentar» además valida',
      'Costo por lote y costo por gramo',
      'PDF y CSV, del mismo período que ves en pantalla',
    ],
  },
]

const activa = ref(TEMAS[0].id)
const botones = ref([])
const laminas = ref([])

// La primera vez que una lámina entra en pantalla se montan las muestras; después, cada solapa
// que se abre arranca la suya en el momento.
const vista = ref(false)
let observador = null
onMounted(() => {
  if (!('IntersectionObserver' in window)) { vista.value = true; return }
  observador = new IntersectionObserver((entradas) => {
    if (entradas.some(e => e.isIntersecting)) { vista.value = true; observador.disconnect() }
  }, { threshold: 0.35 })
  laminas.value.forEach(el => observador.observe(el))
})
onBeforeUnmount(() => observador?.disconnect())

// Flechas, Inicio y Fin entre solapas (el patrón de pestañas de WAI-ARIA).
async function moverConTeclas (e) {
  const i = TEMAS.findIndex(t => t.id === activa.value)
  const destino = { ArrowRight: i + 1, ArrowLeft: i - 1, Home: 0, End: TEMAS.length - 1 }[e.key]
  if (destino === undefined) return
  e.preventDefault()
  const j = (destino + TEMAS.length) % TEMAS.length
  activa.value = TEMAS[j].id
  await nextTick()
  botones.value[j]?.focus()
}
</script>

<style scoped>
.qh { padding: clamp(56px, 8vw, 104px) 0; background: var(--hb-papel-claro); border-block: 1px solid var(--hb-regla); scroll-margin-top: 64px; }
.qh__wrap { width: 100%; max-width: var(--hb-ancho, 1320px); margin: 0 auto; padding: 0 var(--hb-relleno, 16px); }
.qh__cab { margin-bottom: clamp(22px, 3vw, 32px); }
.qh__ceja { margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .14em; text-transform: uppercase; color: var(--hb-tinta-2); }
.qh__h2 { margin: 0; max-width: 22em; font: 600 clamp(1.7rem, 3.6vw, 2.5rem)/1.1 var(--hb-serif); letter-spacing: -.015em; text-wrap: balance; }

/* Solapas: en el teléfono, una fila que se desliza de costado. */
.qh__solapas {
  display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none;
  margin: 0 calc(-1 * var(--hb-relleno, 16px)); padding: 2px var(--hb-relleno, 16px) 14px;
  border-bottom: 1px solid var(--hb-regla);
}
.qh__solapas::-webkit-scrollbar { display: none; }
.qh__solapa {
  flex-shrink: 0; min-height: 40px; padding: .45rem 1rem; border-radius: 999px; cursor: pointer;
  background: transparent; border: 1px solid var(--hb-regla); color: var(--hb-tinta-2);
  font: 500 14px var(--hb-sans); white-space: nowrap; transition: background .2s, color .2s, border-color .2s;
}
.qh__solapa:hover { border-color: var(--hb-tinta-2); color: var(--hb-tinta); }
.qh__solapa--on, .qh__solapa--on:hover { background: var(--hb-tinta); border-color: var(--hb-tinta); color: var(--hb-papel-claro); }
.qh__solapa:focus-visible { outline: 2px solid var(--hb-verde); outline-offset: 2px; }

.qh__panel {
  display: grid; grid-template-columns: minmax(0, .85fr) minmax(0, 1fr); gap: clamp(28px, 5vw, 64px);
  align-items: center; padding-top: clamp(28px, 4vw, 44px);
}
@media (max-width: 900px) { .qh__panel { grid-template-columns: minmax(0, 1fr); } }

.qh__para { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-verde); }
.qh__addon { border: 1px solid var(--hb-ambar); color: var(--hb-tierra); border-radius: 999px; padding: 2px 9px; letter-spacing: .06em; }
.qh__h3 { margin: 0; font: 600 clamp(1.5rem, 2.6vw, 2rem)/1.15 var(--hb-serif); letter-spacing: -.01em; }
.qh__d { margin: 14px 0 0; color: var(--hb-tinta-2); font-size: 1.05rem; max-width: 32em; }
.qh__lista { list-style: none; margin: 20px 0 0; padding: 0; display: grid; gap: 10px; }
.qh__lista li { position: relative; padding-left: 26px; }
.qh__lista li::before {
  content: ''; position: absolute; left: 2px; top: .45em; width: 12px; height: 12px; background: var(--hb-verde);
  -webkit-mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M1 11C1 5 5 1 11 1c0 6-4 10-10 10z'/%3E%3C/svg%3E") center / contain no-repeat;
          mask: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 12'%3E%3Cpath d='M1 11C1 5 5 1 11 1c0 6-4 10-10 10z'/%3E%3C/svg%3E") center / contain no-repeat;
}

/* La lámina: donde va la muestra. Misma ficha de la página (borde verde, sombra salvia). */
.qh__lamina {
  margin: 0 6px 6px 0; min-height: 360px; display: flex; flex-direction: column;
  background: var(--hb-papel); border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia);
  padding: clamp(18px, 3vw, 28px);
}
.qh__lamina > :first-child { flex: 1; }
.qh__pie { margin-top: 16px; padding-top: 10px; border-top: 1px dashed var(--hb-regla); font: 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
</style>
