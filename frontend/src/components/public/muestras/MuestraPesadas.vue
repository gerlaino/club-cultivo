<template>
  <!-- Las pesadas de una cosecha: el peso que entra a cada etapa y la merma calculada, y abajo
       dónde quedó el stock. -->
  <div class="mp">
    <p class="mp__t">Cosecha L-26-002 <span>14 de octubre</span></p>
    <div v-for="(e, i) in ETAPAS" :key="e.que" class="mp__fila">
      <span class="mp__que">{{ e.que }}</span>
      <div class="mp__riel"><div class="mp__barra" :style="{ width: `${(e.g / ETAPAS[0].g) * 100}%`, animationDelay: `${i * 220}ms` }"></div></div>
      <span class="mp__g">{{ fmt(e.g) }} g</span>
      <span class="mp__merma">{{ i ? `−${merma(i)} %` : '' }}</span>
    </div>

    <p class="mp__t mp__t--stock">Stock que quedó <span>por sede</span></p>
    <div class="mp__sedes">
      <div v-for="s in SEDES" :key="s.sede" class="mp__sede">
        <span>{{ s.sede }}</span><b>{{ s.g }} g</b><small>{{ s.frascos }} frascos</small>
      </div>
    </div>
  </div>
</template>

<script setup>
const ETAPAS = [
  { que: 'Húmedo', g: 1840 },
  { que: 'Seco',   g: 412 },
  { que: 'Curado', g: 398 },
]
const SEDES = [
  { sede: 'Palermo',   g: 214, frascos: 42 },
  { sede: 'Caballito', g: 184, frascos: 36 },
]
const fmt = (n) => n.toLocaleString('es-AR')
const merma = (i) => ((1 - ETAPAS[i].g / ETAPAS[i - 1].g) * 100).toLocaleString('es-AR', { maximumFractionDigits: 1 })
</script>

<style scoped>
.mp { display: flex; flex-direction: column; justify-content: center; gap: 12px; }
.mp__t { margin: 0 0 2px; font: 600 1rem var(--hb-sans); color: var(--hb-tinta); }
.mp__t span { font: 500 11px var(--hb-mono); letter-spacing: .08em; color: var(--hb-tinta-2); margin-left: 6px; }
.mp__t--stock { margin-top: 14px; padding-top: 14px; border-top: 1px dashed var(--hb-regla); }
.mp__fila { display: grid; grid-template-columns: 62px minmax(0, 1fr) 70px 56px; gap: 10px; align-items: center; }
.mp__que { font: 500 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
.mp__riel { height: 14px; }
.mp__barra { height: 100%; border-radius: 0 4px 4px 0; background: var(--hb-verde); transform-origin: left; animation: mp-crece .8s cubic-bezier(.2, .7, .2, 1) both; }
.mp__fila:first-of-type .mp__barra { background: var(--hb-salvia); }
.mp__g { font: 600 14px var(--hb-mono); color: var(--hb-tinta); text-align: right; }
.mp__merma { font: 12px var(--hb-mono); color: var(--hb-tinta-2); }
.mp__sedes { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.mp__sede { display: flex; flex-direction: column; gap: 2px; padding: 12px 14px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); }
.mp__sede span { font: 500 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
.mp__sede b { font: 600 1.35rem var(--hb-serif); color: var(--hb-tinta); }
.mp__sede small { font-size: .8rem; color: var(--hb-tinta-2); }
@keyframes mp-crece { from { transform: scaleX(0); } }
@media (prefers-reduced-motion: reduce) { .mp__barra { animation: none; } }
</style>
