<template>
  <section class="pf" id="preguntas">
    <div class="pf__wrap">
      <header class="pf__cab">
        <p class="pf__ceja">Preguntas frecuentes</p>
        <h2 class="pf__h2">Lo que nos suelen preguntar</h2>
      </header>

      <div class="pf__grupos">
        <div v-for="g in GRUPOS" :key="g.titulo">
          <h3 class="pf__h3">{{ g.titulo }}</h3>
          <!-- <details>: se abre y se cierra sin JS, con teclado y lector de pantalla. -->
          <details v-for="p in g.preguntas" :key="p.q" class="pf__p">
            <summary>{{ p.q }}</summary>
            <p>{{ p.r }}</p>
          </details>
        </div>
      </div>

      <p class="pf__mas">
        ¿Te quedó otra duda? <a href="#contacto" @click="$emit('contacto')">Escribinos</a> y te respondemos por mail.
      </p>
    </div>
  </section>
</template>

<script setup>
// PREGUNTAS FRECUENTES de la página pública (Germán, 5-oct-2026: que la página conteste las
// dudas y el contacto quede para cerrar). Escritas desde quien mira la página sin conocernos.
//
// Cada respuesta tiene que ser verdad HOY en el código. Las que dependen de una persona y no de
// la app (importar datos al arrancar, exportarlos al irse, activar después de la prueba) lo dicen
// así: lo hacemos nosotros. Si cambia una regla (la prueba, qué funciona sin señal), cambiar acá.
defineEmits(['contacto'])

const GRUPOS = [
  {
    titulo: 'Si cultivás en casa',
    preguntas: [
      { q: '¿Qué pasa cuando termina la prueba gratis?',
        r: 'No se cobra nada solo: no te pedimos tarjeta. Si querés seguir, nos escribís y la activamos. Si no, la cuenta queda en pausa y no se borra nada de lo que cargaste.' },
      { q: '¿Sirve para automáticas y para fotoperiódicas?',
        r: 'Sí. Marcás la genética como automática y la app la cuenta de semilla a cosecha, sin pedirte el cambio a floración. Las fotoperiódicas siguen su ciclo de vege y flora.' },
      { q: '¿Tengo que instalar algo?',
        r: 'No hace falta una tienda de apps: se instala desde el navegador del teléfono en unos segundos y queda como una app más. También la podés usar desde la compu.' },
      { q: '¿Anda sin señal?',
        r: 'La app abre igual. Los registros del espacio, las lecturas de ambiente y los pesajes se guardan en el teléfono y se mandan solos cuando vuelve la señal.' },
      { q: '¿Quién ve mis datos?',
        r: 'Sólo vos. No los vendemos ni los usamos para publicidad. Están en servidores en la nube (algunos fuera de la Argentina), con copias de seguridad.' },
      { q: '¿Me sirve para el REPROCANN?',
        r: 'Cultivo Espacial no tramita el REPROCANN ni autoriza a cultivar: eso lo dan la ley y el registro. Lo que te da es tu cultivo registrado y ordenado, planta por planta.' },
      { q: '¿Me puedo dar de baja?',
        r: 'Cuando quieras, sin explicar nada. Y si contrataste hace menos de 10 días, tenés el botón de arrepentimiento al pie de esta página.' },
    ],
  },
  {
    titulo: 'Si sos una organización',
    preguntas: [
      { q: '¿Cuánto tarda arrancar?',
        r: 'Armamos la cuenta con vos: la organización, las sedes, quién hace qué y lo que contratan. Cuando está lista, cada persona entra con su usuario y ve lo suyo.' },
      { q: 'Tenemos todo en planillas, ¿hay que cargarlo de nuevo?',
        r: 'No. Nos pasás el padrón de pacientes, las genéticas o el stock como los tengas, y los importamos nosotros.' },
      { q: '¿Sirve si tenemos varias sedes? ¿Y si sólo dispensamos?',
        r: 'Sí a las dos. Cada sede tiene su stock y su caja. Se contrata por partes: Cultivo, Producción y dispensa, o las dos, y arriba lo que sume (delivery, ambiente, asistente IA, portal del paciente).' },
      { q: '¿Cada persona ve sólo lo suyo?',
        r: 'Sí. Hay una vista por oficio: cultivo, manicura, mostrador, médico, delivery y administración. Quien atiende el mostrador, por ejemplo, no ve la contabilidad.' },
      { q: '¿Qué informes salen?',
        r: 'REPROCANN, INASE, producción, inventario, pérdidas y dispensaciones, en PDF y CSV. Salen de lo que se carga operando: no hay que armar nada aparte el día que te los piden.' },
      { q: '¿Qué pasa si se corta internet en el mostrador?',
        r: 'Sin señal no se dispensa, a propósito: así el stock y la caja nunca quedan distintos entre dos teléfonos. La manicura y los registros de las salas sí siguen y se sincronizan al volver.' },
      { q: '¿Dónde están los datos y quién los ve?',
        r: 'En servidores en la nube, con copias de seguridad verificadas. Cada organización está aislada de las demás y sus datos no se venden ni se comparten.' },
      { q: 'Si un día nos vamos, ¿nos llevamos los datos?',
        r: 'Sí. Nos lo pedís y te armamos la exportación completa de lo que cargaron.' },
      { q: '¿Cuánto sale?',
        r: 'Depende de qué partes usen y de cuántas personas. Escribinos, contanos qué hacen y te armamos la propuesta.' },
    ],
  },
]
</script>

<style scoped>
.pf { padding: clamp(56px, 8vw, 104px) 0; scroll-margin-top: 64px; }
.pf__wrap { width: 100%; max-width: var(--hb-ancho, 1320px); margin: 0 auto; padding: 0 var(--hb-relleno, 16px); }
.pf__cab { margin-bottom: clamp(24px, 4vw, 40px); }
.pf__ceja { margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .14em; text-transform: uppercase; color: var(--hb-tinta-2); }
.pf__h2 { margin: 0; font: 600 clamp(1.7rem, 3.6vw, 2.5rem)/1.1 var(--hb-serif); letter-spacing: -.015em; }
.pf__grupos { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 420px), 1fr)); gap: clamp(28px, 4vw, 56px); align-items: start; }
.pf__h3 { margin: 0 0 6px; padding-bottom: 10px; border-bottom: 1px solid var(--hb-tinta); font: 600 1.3rem var(--hb-serif); }
.pf__p { border-bottom: 1px solid var(--hb-regla); }
.pf__p summary {
  list-style: none; cursor: pointer; display: flex; justify-content: space-between; align-items: center; gap: 16px;
  padding: 14px 0; font: 600 1rem/1.4 var(--hb-sans); color: var(--hb-tinta);
}
.pf__p summary::-webkit-details-marker { display: none; }
/* El + que gira a × al abrir. */
.pf__p summary::after {
  content: '+'; flex-shrink: 0; width: 26px; height: 26px; border-radius: 50%; display: grid; place-items: center;
  border: 1px solid var(--hb-regla); color: var(--hb-verde); font: 400 18px/1 var(--hb-sans); transition: transform .2s;
}
.pf__p[open] summary::after { transform: rotate(45deg); }
.pf__p summary:hover { color: var(--hb-verde); }
.pf__p summary:focus-visible { outline: 2px solid var(--hb-verde); outline-offset: 2px; }
.pf__p p { margin: 0 0 16px; padding-right: 42px; color: var(--hb-tinta-2); }
.pf__mas { margin: clamp(28px, 4vw, 40px) 0 0; color: var(--hb-tinta-2); }
.pf__mas a { color: var(--hb-verde); font-weight: 600; }
</style>
