<template>
  <!-- Rendimiento por cosecha, en g/m². Una serie: el título la nombra y no hace falta leyenda.
       Rótulo directo sólo en la última y en el promedio; el resto, al pasar el mouse. -->
  <div class="mr">
    <p class="mr__t">Rendimiento por cosecha <span>g/m²</span></p>
    <div class="mr__plot" role="img" :aria-label="descripcion">
      <div class="mr__prom" :style="{ bottom: `${pct(promedio)}%` }"><span>Promedio {{ promedio }}</span></div>
      <div v-for="(c, i) in COSECHAS" :key="c.lote" class="mr__col" tabindex="0">
        <div class="mr__barra" :class="{ 'mr__barra--ult': i === COSECHAS.length - 1 }"
             :style="{ height: `${pct(c.g)}%`, animationDelay: `${i * 90}ms` }">
          <span v-if="i === COSECHAS.length - 1" class="mr__valor">{{ c.g }}</span>
        </div>
        <span class="mr__tip" role="tooltip">{{ c.lote }} · {{ c.gen }}<b>{{ c.g }} g/m²</b></span>
      </div>
    </div>
    <div class="mr__ejes">
      <span v-for="c in COSECHAS" :key="c.lote">{{ c.lote.slice(5) }}</span>
    </div>
  </div>
</template>

<script setup>
const COSECHAS = [
  { lote: 'L-25-031', gen: 'Gorilla Glue', g: 412 },
  { lote: 'L-25-038', gen: 'King’s Juice', g: 455 },
  { lote: 'L-26-002', gen: 'King’s Juice', g: 498 },
  { lote: 'L-26-007', gen: 'Amnesia',      g: 431 },
  { lote: 'L-26-011', gen: 'Gorilla Glue', g: 520 },
  { lote: 'L-26-015', gen: 'King’s Juice', g: 547 },
]
const TOPE = 600
const pct = (g) => (g / TOPE) * 100
const promedio = Math.round(COSECHAS.reduce((s, c) => s + c.g, 0) / COSECHAS.length)
const descripcion = `Rendimiento por cosecha en gramos por metro cuadrado: ${COSECHAS.map(c => `${c.lote} ${c.g}`).join(', ')}. Promedio ${promedio}.`
</script>

<style scoped>
.mr { display: flex; flex-direction: column; justify-content: center; gap: 10px; }
.mr__t { margin: 0 0 6px; font: 600 1rem var(--hb-sans); color: var(--hb-tinta); }
.mr__t span { font: 500 11px var(--hb-mono); letter-spacing: .08em; color: var(--hb-tinta-2); margin-left: 6px; }
.mr__plot {
  position: relative; height: 220px; display: grid; grid-template-columns: repeat(6, 1fr); gap: 2px;
  align-items: end; border-bottom: 1px solid var(--hb-tinta-2);
  /* Grilla recesiva cada 200 g/m². */
  background: repeating-linear-gradient(to top, transparent 0 calc(33.333% - 1px), var(--hb-regla) calc(33.333% - 1px) 33.333%);
}
.mr__col { position: relative; height: 100%; display: flex; align-items: flex-end; justify-content: center; outline: none; }
.mr__barra {
  position: relative; width: min(30px, 60%); border-radius: 4px 4px 0 0; background: var(--hb-salvia);
  transform-origin: bottom; animation: mr-crece .7s cubic-bezier(.2, .7, .2, 1) both;
}
.mr__barra--ult { background: var(--hb-verde); }
.mr__col:hover .mr__barra, .mr__col:focus-visible .mr__barra { background: var(--hb-verde-osc); }
.mr__valor { position: absolute; bottom: calc(100% + 4px); left: 50%; transform: translateX(-50%); font: 600 12px var(--hb-mono); color: var(--hb-tinta); }
.mr__prom { position: absolute; left: 0; right: 0; border-top: 1.5px dashed var(--hb-tinta-2); z-index: 1; pointer-events: none; }
.mr__prom span { position: absolute; left: 0; bottom: 3px; font: 11px var(--hb-mono); color: var(--hb-tinta-2); background: var(--hb-papel); padding: 0 4px; }
.mr__tip {
  position: absolute; bottom: calc(100% + 8px); left: 50%; transform: translateX(-50%); z-index: 2; white-space: nowrap;
  display: none; flex-direction: column; gap: 2px; padding: 6px 9px; border-radius: 6px;
  background: var(--hb-tinta); color: var(--hb-papel-claro); font: 12px var(--hb-sans);
}
.mr__tip b { font: 600 13px var(--hb-mono); }
.mr__col:hover .mr__tip, .mr__col:focus-visible .mr__tip { display: flex; bottom: auto; top: 0; }
.mr__ejes { display: grid; grid-template-columns: repeat(6, 1fr); text-align: center; font: 11px var(--hb-mono); color: var(--hb-tinta-2); }
@keyframes mr-crece { from { transform: scaleY(0); } }
@media (prefers-reduced-motion: reduce) { .mr__barra { animation: none; } }
</style>
