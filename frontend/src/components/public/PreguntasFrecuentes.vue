<template>
  <section class="pf" id="preguntas">
    <div class="pf__wrap">
      <header class="pf__cab">
        <p class="pf__ceja">Preguntas frecuentes</p>
        <h2 class="pf__h2">{{ titulo }}</h2>
      </header>

      <div class="pf__lista">
        <!-- <details>: se abre y se cierra sin JS, con teclado y lector de pantalla. -->
        <details v-for="p in preguntas" :key="p.q" class="pf__p">
          <summary>{{ p.q }}</summary>
          <p>{{ p.r }}</p>
        </details>
      </div>

      <p class="pf__mas">
        <!-- Un ancla de la misma página va con <a>: el router de la app no hace scroll a los `#`. -->
        ¿Te quedó otra duda?
        <a v-if="typeof contacto === 'string' && contacto.startsWith('#')" :href="contacto">Escribinos</a>
        <RouterLink v-else :to="contacto">Escribinos</RouterLink>
        y te respondemos por mail.
      </p>
    </div>
  </section>
</template>

<script setup>
// PREGUNTAS FRECUENTES de las páginas públicas (Germán, 5-oct-2026: que la página conteste las
// dudas y el contacto quede para cerrar). Escritas desde quien mira la página sin conocernos; las
// de cada público están en `contenido.js`, con la regla de qué se puede afirmar.
defineProps({
  titulo:     { type: String, default: 'Lo que nos suelen preguntar' },
  preguntas:  { type: Array, required: true },   // [{ q, r }]
  // A dónde lleva «Escribinos»: en proyectos, al formulario de la misma página.
  contacto:   { type: [String, Object], default: '/contacto' },
})
</script>

<style scoped>
.pf { padding: clamp(56px, 8vw, 104px) 0; scroll-margin-top: 64px; }
.pf__wrap { width: 100%; max-width: var(--hb-ancho, 1320px); margin: 0 auto; padding: 0 var(--hb-relleno, 16px); }
.pf__cab { margin-bottom: clamp(24px, 4vw, 40px); }
.pf__ceja { margin: 0 0 12px; font: 500 12px var(--hb-mono); letter-spacing: .14em; text-transform: uppercase; color: var(--hb-tinta-2); }
.pf__h2 { margin: 0; font: 600 clamp(1.7rem, 3.6vw, 2.5rem)/1.1 var(--hb-serif); letter-spacing: -.015em; }
.pf__lista { max-width: 860px; border-top: 1px solid var(--hb-tinta); }
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
