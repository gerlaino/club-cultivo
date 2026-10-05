<template>
  <!-- El último eslabón: la motito sale de la sede con el paquete y llega a la casa del paciente.
       Abajo, los estados del pedido se van prendiendo al ritmo del viaje. -->
  <div class="md">
    <svg class="md__escena" viewBox="0 0 400 150" role="img" aria-label="Una moto lleva el pedido desde la sede hasta la casa del paciente">
      <!-- Sede -->
      <g class="md__sede">
        <rect x="14" y="58" width="58" height="62" rx="2" />
        <rect class="md__cartel" x="22" y="66" width="42" height="12" rx="2" />
        <rect class="md__puerta" x="36" y="94" width="14" height="26" />
      </g>
      <!-- Casa del paciente -->
      <g class="md__casa">
        <path d="M322 82 L352 58 L382 82 V120 H322 Z" />
        <rect class="md__puerta" x="345" y="96" width="14" height="24" />
        <g class="md__ok">
          <circle cx="352" cy="36" r="13" />
          <path d="M346 36 l4 4 l8 -8" />
        </g>
      </g>
      <!-- Calle -->
      <line class="md__suelo" x1="0" y1="121" x2="400" y2="121" />
      <line class="md__calle" x1="80" y1="134" x2="316" y2="134" />

      <!-- La moto. Se dibuja mirando a la derecha con el origen en la rueda de atrás. -->
      <g class="md__moto">
        <g transform="translate(0 83)">
          <g class="md__estela">
            <line x1="-22" y1="14" x2="-6" y2="14" />
            <line x1="-30" y1="24" x2="-8" y2="24" />
          </g>
          <rect class="md__caja" x="0" y="6" width="17" height="14" rx="2" />
          <path class="md__cuerpo" d="M10 30 L18 21 H35 L43 11 H49" />
          <path class="md__piso" d="M15 29 H37 L44 18" />
          <line class="md__cuerpo" x1="43" y1="11" x2="46" y2="31" />
          <circle class="md__rueda" cx="10" cy="31" r="7" />
          <circle class="md__rueda" cx="46" cy="31" r="7" />
          <circle class="md__cabeza" cx="29" cy="1" r="5" />
          <path class="md__persona" d="M28 6 L25 19 M27 9 L42 12 M25 19 L33 22 L35 29" />
        </g>
      </g>
    </svg>

    <ol class="md__estados">
      <li v-for="e in ESTADOS" :key="e.que" :style="{ '--d': e.cuando }">
        <b>{{ e.que }}</b>
        <small>{{ e.det }}</small>
      </li>
    </ol>
  </div>
</template>

<script setup>
// `cuando`: el momento del viaje en que se prende cada estado (va con la animación de la moto).
const ESTADOS = [
  { que: 'Armado',    det: '16:10 · desde el stock', cuando: '0s' },
  { que: 'En camino', det: '16:25 · ruta del día',   cuando: '.6s' },
  { que: 'Entregado', det: '16:52 · con firma',      cuando: '4.1s' },
]
</script>

<style scoped>
.md { display: flex; flex-direction: column; justify-content: center; gap: 18px; }
.md__escena { width: 100%; height: auto; overflow: visible; }

.md__sede rect:first-child { fill: var(--hb-papel-claro); stroke: var(--hb-tinta-2); stroke-width: 1.5; }
.md__cartel { fill: var(--hb-salvia); }
.md__puerta { fill: var(--hb-salvia-suave); stroke: var(--hb-tinta-2); stroke-width: 1.2; }
.md__casa > path { fill: var(--hb-papel-claro); stroke: var(--hb-tinta-2); stroke-width: 1.5; stroke-linejoin: round; }
.md__ok { opacity: 0; transform-box: fill-box; transform-origin: center; animation: md-ok .4s ease 4.1s forwards; }
.md__ok circle { fill: var(--hb-verde); }
.md__ok path { fill: none; stroke: var(--hb-papel-claro); stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round; }
.md__suelo { stroke: var(--hb-tinta-2); stroke-width: 1.5; }
.md__calle { stroke: var(--hb-regla); stroke-width: 2; stroke-dasharray: 8 8; }

.md__moto { animation: md-viaje 3.5s cubic-bezier(.45, 0, .35, 1) .6s both; }
.md__caja { fill: var(--hb-ambar); }
.md__cuerpo { fill: none; stroke: var(--hb-verde); stroke-width: 4; stroke-linecap: round; stroke-linejoin: round; }
.md__piso { fill: none; stroke: var(--hb-verde-osc); stroke-width: 3; stroke-linecap: round; stroke-linejoin: round; }
.md__rueda { fill: var(--hb-papel); stroke: var(--hb-tinta); stroke-width: 3; }
.md__cabeza { fill: var(--hb-tinta); }
.md__persona { fill: none; stroke: var(--hb-tinta); stroke-width: 3; stroke-linecap: round; stroke-linejoin: round; }
.md__estela { stroke: var(--hb-tinta-2); stroke-width: 1.5; stroke-linecap: round; opacity: 0; animation: md-estela 3.5s linear .6s both; }

/* De la puerta de la sede a la vereda de la casa (la moto mide ~55 y la casa empieza en 322). */
@keyframes md-viaje { from { transform: translateX(40px); } to { transform: translateX(250px); } }
@keyframes md-estela { 0%, 100% { opacity: 0; } 15%, 80% { opacity: .7; } }
@keyframes md-ok { from { opacity: 0; transform: scale(.4); } to { opacity: 1; transform: scale(1); } }

.md__estados { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
.md__estados li {
  display: flex; flex-direction: column; gap: 2px; padding-top: 10px; border-top: 3px solid var(--hb-regla);
  color: var(--hb-tinta-2); animation: md-prende .3s ease var(--d) forwards;
}
.md__estados b { font: 600 .95rem var(--hb-sans); }
.md__estados small { font: 11px var(--hb-mono); }
@keyframes md-prende { to { border-top-color: var(--hb-verde); color: var(--hb-tinta); } }

@media (prefers-reduced-motion: reduce) {
  .md__moto { animation: none; transform: translateX(250px); }
  .md__estela { animation: none; }
  .md__ok { animation: none; opacity: 1; }
  .md__estados li { animation: none; border-top-color: var(--hb-verde); color: var(--hb-tinta); }
}
</style>
