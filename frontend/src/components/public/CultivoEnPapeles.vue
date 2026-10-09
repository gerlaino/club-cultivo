<template>
  <!-- «TU CULTIVO, EN PAPELES» (Germán, 9-oct-2026: lo que hace sentir profesional al que recién
       arranca): el diario de fotos por semana y el informe de la cosecha, como salen de la app.
       Las fotos son las de `PlantaCreciendo`; los números, los del recorrido (`RecorridoFases`). -->
  <section class="hb__sec">
    <div class="hb__wrap">
      <header class="hb__sec-h">
        <p class="hb__ceja">Tu cultivo, en papeles</p>
        <h2 class="hb__h2">Lo que hiciste, <em class="cp__em">guardado y para mostrar</em></h2>
        <p class="cp__intro">Cada cosecha te queda con su diario de fotos y su informe. La próxima la arrancás sabiendo qué funcionó.</p>
      </header>
      <div class="cp">
        <div class="cp__marco hb-rev">
          <p class="cp__t">Diario de fotos · La petisa</p>
          <div class="cp__fotos">
            <figure v-for="f in FOTOS" :key="f.src"><img :src="f.src" :alt="`La petisa, semana ${f.sem}`" loading="lazy" /><figcaption>Sem. {{ f.sem }}</figcaption></figure>
          </div>
          <p class="cp__pie">Una foto por semana, sacada desde el teléfono</p>
        </div>
        <div class="cp__marco hb-rev">
          <div class="cp__cab">
            <div><p class="cp__titulo">Informe de mi cosecha</p><p class="cp__sub">La petisa · King’s Juice auto · 90 días</p></div>
            <span class="cp__fmt">PDF · Excel</span>
          </div>
          <div class="cp__filas">
            <div v-for="f in FILAS" :key="f[0]"><span>{{ f[0] }}</span><b>{{ f[1] }}</b></div>
            <div class="cp__res"><span>Cada gramo te costó</span><b>$ 719</b></div>
          </div>
          <p class="cp__frascos">Frascos F-01 y F-02 · los dos de La petisa</p>
          <p class="cp__pie">Ejemplo · datos ficticios</p>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const FOTOS = [
  { src: '/planta/02.webp', sem: 2 },
  { src: '/planta/04.webp', sem: 5 },
  { src: '/planta/05.webp', sem: 6 },
  { src: '/planta/06.webp', sem: 9 },
  { src: '/planta/07.webp', sem: 12 },
]
// $ 46.000 ÷ 64 g curados = $ 719 por gramo.
const FILAS = [['Húmedo', '312 g'], ['Seco', '70 g'], ['Curado', '64 g'], ['Merma total', '79 %'], ['Gastos de la cosecha', '$ 46.000']]
</script>

<style scoped>
.cp__em { font-style: italic; font-weight: 400; color: var(--hb-verde); }
.cp__intro { margin: 12px 0 0; color: var(--hb-tinta-2); font-size: 1.05rem; max-width: 40em; }
.cp { display: grid; grid-template-columns: minmax(0, 1.2fr) minmax(0, .8fr); gap: 24px; align-items: start; }
@media (max-width: 860px) { .cp { grid-template-columns: minmax(0, 1fr); } }
.cp__marco { min-width: 0; margin-right: 6px; background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); box-shadow: 6px 6px 0 var(--hb-salvia); padding: clamp(16px, 2.4vw, 26px); }
.cp__t { margin: 0 0 14px; font: 600 1rem var(--hb-sans); color: var(--hb-tinta); }
.cp__fotos { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 8px; }
.cp__fotos figure { margin: 0; display: grid; gap: 6px; }
.cp__fotos img { width: 100%; aspect-ratio: 3 / 4; object-fit: contain; object-position: bottom center; background: radial-gradient(70% 70% at 50% 40%, var(--hb-salvia-suave), var(--hb-papel) 80%); border: 1px solid var(--hb-regla); }
.cp__fotos figcaption { font: 500 10.5px var(--hb-mono); letter-spacing: .06em; color: var(--hb-tinta-2); text-align: center; }
.cp__cab { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding-bottom: 10px; border-bottom: 1.5px solid var(--hb-tinta); }
.cp__titulo { margin: 0; font: 600 1.15rem var(--hb-serif); color: var(--hb-tinta); }
.cp__sub { margin: 2px 0 0; font: 11px var(--hb-mono); color: var(--hb-tinta-2); }
.cp__fmt { font: 500 10.5px var(--hb-mono); letter-spacing: .08em; color: var(--hb-verde); border: 1px solid var(--hb-salvia); border-radius: 999px; padding: 2px 8px; white-space: nowrap; }
.cp__filas { display: grid; margin-top: 8px; }
.cp__filas div { display: flex; justify-content: space-between; gap: 12px; padding: 7px 0; border-top: 1px solid var(--hb-regla); font-size: .92rem; color: var(--hb-tinta); }
.cp__filas div:first-child { border-top: 0; }
.cp__filas b { font: 500 .88rem var(--hb-mono); }
.cp__filas .cp__res { border-top: 1.5px solid var(--hb-tinta); padding-top: 10px; }
.cp__res b { font: 600 1.35rem var(--hb-serif); color: var(--hb-verde); }
.cp__frascos { margin: 10px 0 0; font-size: .86rem; color: var(--hb-tinta-2); }
.cp__pie { margin: 18px 0 0; padding-top: 10px; border-top: 1px dashed var(--hb-regla); font: 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
</style>
