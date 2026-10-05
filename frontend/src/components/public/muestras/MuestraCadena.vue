<template>
  <!-- La cadena de un gramo, de la genética a quien lo recibe. Los eslabones aparecen de a uno y
       la línea se va pintando detrás, como el gramo recorriendo la cadena. -->
  <ol class="mc" aria-label="Recorrido de un gramo">
    <li v-for="(e, i) in ESLABONES" :key="e.que" class="mc__e" :style="{ '--i': i }">
      <span class="mc__punto" aria-hidden="true"></span>
      <span class="mc__que">{{ e.que }}</span>
      <b class="mc__cual">{{ e.cual }}</b>
      <span class="mc__det">{{ e.det }}</span>
    </li>
  </ol>
</template>

<script setup>
const ESLABONES = [
  { que: 'Genética', cual: 'King’s Juice · auto', det: 'Banco y origen declarados' },
  { que: 'Lote',     cual: 'L-26-002',            det: '12 plantas · Vege 1 → Flora 2' },
  { que: 'Planta',   cual: 'P-0142',              det: 'QR propio · 64 registros' },
  { que: 'Cosecha',  cual: '14 de octubre',       det: '1.840 g húmedo → 412 g seco' },
  { que: 'Stock',    cual: 'S-118 · 5 g',         det: 'Sede Palermo' },
  { que: 'Entrega',  cual: 'Paciente N.º 0231',   det: '5 g · con firma' },
]
</script>

<style scoped>
.mc { position: relative; list-style: none; margin: 0; padding: 0 0 0 30px; display: grid; gap: 14px; align-content: center; }
/* La línea que une los eslabones. */
.mc::before { content: ''; position: absolute; left: 7px; top: 10px; bottom: 10px; width: 2px; background: var(--hb-regla); }
.mc__e {
  position: relative; z-index: 1; display: grid; grid-template-columns: 76px minmax(0, 1fr); column-gap: 12px; align-items: baseline;
  opacity: 0; transform: translateX(-6px); animation: mc-entra .45s ease forwards; animation-delay: calc(var(--i) * 260ms);
}
/* El recorrido: la misma línea, pintada de verde mientras aparecen los eslabones. */
.mc::after { content: ''; position: absolute; left: 7px; top: 10px; width: 2px; height: 0; background: var(--hb-verde); animation: mc-pinta 1.5s linear .1s forwards; }
.mc__punto {
  position: absolute; z-index: 1; left: -30px; top: .3em; width: 16px; height: 16px; border-radius: 50%;
  background: var(--hb-papel); border: 2px solid var(--hb-verde);
  animation: mc-llega .3s ease forwards; animation-delay: calc(var(--i) * 260ms + 200ms);
}
.mc__que { font: 500 11px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-tinta-2); }
.mc__cual { font: 600 1.02rem var(--hb-sans); color: var(--hb-tinta); }
.mc__det { grid-column: 2; font-size: .86rem; color: var(--hb-tinta-2); }
@keyframes mc-entra { to { opacity: 1; transform: none; } }
@keyframes mc-pinta { to { height: calc(100% - 26px); } }
@keyframes mc-llega { to { background: var(--hb-verde); } }
@media (prefers-reduced-motion: reduce) {
  .mc__e { animation: none; opacity: 1; transform: none; }
  .mc::after { animation: none; height: calc(100% - 26px); }
  .mc__punto { animation: none; background: var(--hb-verde); }
}
</style>
