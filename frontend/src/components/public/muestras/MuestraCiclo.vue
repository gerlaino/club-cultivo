<template>
  <!-- El reloj de una automática (semilla a cosecha) y los próximos pasos del ciclo. Mismos datos
       que el teléfono de «Llevala en el bolsillo»: L-26-002, día 31, faltan 46. -->
  <div class="mcl">
    <div class="mcl__cab">
      <div>
        <!-- En casa se habla de la planta; en un proyecto, del lote (`casa`). -->
        <p class="mcl__lote">{{ casa ? 'La petisa' : 'L-26-002' }} <span>King’s Juice · auto</span></p>
        <p class="mcl__sub">{{ casa ? 'Carpa grande · maceta de 10 L' : '3 plantas · Balcón · maceta de 10 L' }}</p>
      </div>
      <p class="mcl__dia"><b>Día {{ DIA }}</b><span>de unos {{ TOTAL }}</span></p>
    </div>

    <div class="mcl__reloj" role="img" :aria-label="`Día ${DIA} de unos ${TOTAL}, de semilla a cosecha`">
      <div class="mcl__avance" :style="{ width: `${(DIA / TOTAL) * 100}%` }"></div>
    </div>
    <div class="mcl__marcas"><span>Semilla</span><span>Cosecha</span></div>

    <p class="mcl__t">Próximos pasos</p>
    <ul class="mcl__pasos">
      <li v-for="(p, i) in PASOS" :key="p.que" :style="{ animationDelay: `${700 + i * 220}ms` }">
        <span class="mcl__cuando">{{ p.cuando }}</span>
        <span class="mcl__que">{{ p.que }}<small>{{ p.det }}</small></span>
      </li>
    </ul>
  </div>
</template>

<script setup>
defineProps({ casa: { type: Boolean, default: false } })
const DIA = 31
const TOTAL = 77
const PASOS = [
  { cuando: 'Hoy',        que: 'Regar',                     det: 'El último riego fue hace 2 días' },
  { cuando: 'En 5 días',  que: 'Empieza a florecer',        det: 'Te avisamos al teléfono' },
  { cuando: 'En 46 días', que: 'Cosecha estimada',          det: 'Según la genética' },
]
</script>

<style scoped>
.mcl { display: flex; flex-direction: column; justify-content: center; gap: 10px; }
.mcl__cab { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.mcl__lote { margin: 0; font: 700 1.3rem var(--hb-sans); color: var(--hb-tinta); letter-spacing: -.01em; }
.mcl__lote span { font: 500 11px var(--hb-mono); letter-spacing: .06em; color: var(--hb-verde); margin-left: 6px; }
.mcl__sub { margin: 2px 0 0; font-size: .86rem; color: var(--hb-tinta-2); }
.mcl__dia { margin: 0; display: flex; flex-direction: column; align-items: flex-end; }
.mcl__dia b { font: 600 1.5rem/1 var(--hb-serif); color: var(--hb-tinta); }
.mcl__dia span { font: 11px var(--hb-mono); color: var(--hb-tinta-2); }
.mcl__reloj { margin-top: 8px; height: 12px; border-radius: 999px; background: var(--hb-salvia-suave); overflow: hidden; }
.mcl__avance { height: 100%; border-radius: 999px; background: var(--hb-verde); transform-origin: left; animation: mcl-avanza 1s cubic-bezier(.2, .7, .2, 1) both; }
.mcl__marcas { display: flex; justify-content: space-between; font: 11px var(--hb-mono); color: var(--hb-tinta-2); }
.mcl__t { margin: 12px 0 0; padding-top: 12px; border-top: 1px dashed var(--hb-regla); font: 500 11px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-tinta-2); }
.mcl__pasos { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
.mcl__pasos li {
  display: grid; grid-template-columns: 86px minmax(0, 1fr); gap: 12px; align-items: baseline;
  padding: 10px 12px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla);
  opacity: 0; animation: mcl-entra .35s ease forwards;
}
.mcl__pasos li:first-child { border-color: var(--hb-verde); }
.mcl__cuando { font: 500 12px var(--hb-mono); color: var(--hb-verde); }
.mcl__que { display: flex; flex-direction: column; font-weight: 600; color: var(--hb-tinta); }
.mcl__que small { font-weight: 400; font-size: .82rem; color: var(--hb-tinta-2); }
@keyframes mcl-avanza { from { transform: scaleX(0); } }
@keyframes mcl-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .mcl__avance { animation: none; } .mcl__pasos li { animation: none; opacity: 1; } }
</style>
