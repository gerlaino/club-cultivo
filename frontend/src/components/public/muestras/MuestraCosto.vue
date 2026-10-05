<template>
  <!-- Los gastos de un ciclo por categoría y el costo por gramo que sale de dividirlos por lo que
       rindió. Una serie: cada barra lleva su monto al lado (son cuatro, se leen como una lista). -->
  <div class="mco">
    <p class="mco__t">Gastos del ciclo <span>carpa · L-26-002</span></p>
    <div v-for="(g, i) in GASTOS" :key="g.que" class="mco__fila">
      <span class="mco__que">{{ g.que }}</span>
      <div class="mco__riel"><div class="mco__barra" :style="{ width: `${(g.monto / MAYOR) * 100}%`, animationDelay: `${i * 150}ms` }"></div></div>
      <span class="mco__monto">{{ pesos(g.monto) }}</span>
    </div>
    <div class="mco__cuenta">
      <div><span>Total</span><b>{{ pesos(total) }}</b></div>
      <i aria-hidden="true">÷</i>
      <div><span>Curado</span><b>{{ GRAMOS }} g</b></div>
      <i aria-hidden="true">=</i>
      <div class="mco__res"><span>Cada gramo</span><b>{{ pesos(Math.round(total / GRAMOS)) }}</b></div>
    </div>
  </div>
</template>

<script setup>
const GASTOS = [
  { que: 'Semillas',          monto: 18000 },
  { que: 'Sustrato y macetas', monto: 26000 },
  { que: 'Nutrientes',        monto: 22000 },
  { que: 'Luz',               monto: 31000 },
]
const GRAMOS = 136
const MAYOR = Math.max(...GASTOS.map(g => g.monto))
const total = GASTOS.reduce((s, g) => s + g.monto, 0)
const pesos = (n) => `$ ${n.toLocaleString('es-AR')}`
</script>

<style scoped>
.mco { display: flex; flex-direction: column; justify-content: center; gap: 12px; }
.mco__t { margin: 0 0 4px; font: 600 1rem var(--hb-sans); color: var(--hb-tinta); }
.mco__t span { font: 500 11px var(--hb-mono); letter-spacing: .08em; color: var(--hb-tinta-2); margin-left: 6px; }
.mco__fila { display: grid; grid-template-columns: 128px minmax(0, 1fr) 76px; gap: 10px; align-items: center; }
.mco__que { font-size: .9rem; color: var(--hb-tinta); }
.mco__riel { height: 12px; }
.mco__barra { height: 100%; border-radius: 0 4px 4px 0; background: var(--hb-salvia); transform-origin: left; animation: mco-crece .7s cubic-bezier(.2, .7, .2, 1) both; }
.mco__monto { font: 500 13px var(--hb-mono); color: var(--hb-tinta); text-align: right; }
.mco__cuenta {
  display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: 10px; padding: 14px 16px;
  background: var(--hb-papel-claro); border: 1px solid var(--hb-regla);
}
.mco__cuenta div { display: flex; flex-direction: column; gap: 2px; }
.mco__cuenta span { font: 500 10.5px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
.mco__cuenta b { font: 600 1.05rem var(--hb-mono); color: var(--hb-tinta); }
.mco__cuenta i { font: 400 1.2rem var(--hb-serif); font-style: normal; color: var(--hb-tinta-2); }
.mco__res b { font: 600 1.45rem var(--hb-serif); color: var(--hb-verde); }
@media (max-width: 420px) { .mco__fila { grid-template-columns: 96px minmax(0, 1fr) 70px; } .mco__cuenta { flex-wrap: wrap; } }
@keyframes mco-crece { from { transform: scaleX(0); } }
@media (prefers-reduced-motion: reduce) { .mco__barra { animation: none; } }
</style>
