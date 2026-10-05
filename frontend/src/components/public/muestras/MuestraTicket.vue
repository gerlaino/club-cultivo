<template>
  <!-- Una dispensa como la ve quien atiende: lo que se lleva, cómo pagó (con lo que tenía a favor
       descontado solo) y la caja que cierra. -->
  <div class="mt">
    <div class="mt__cab">
      <span>Dispensa N.º 1.284</span><span>12-oct · 18:40</span>
    </div>
    <p class="mt__pac">Paciente N.º 0231 <small>REPROCANN vigente</small></p>
    <ul>
      <li v-for="it in ITEMS" :key="it.d"><span>{{ it.d }}</span><b>{{ pesos(it.p) }}</b></li>
      <li class="mt__total"><span>Total</span><b>{{ pesos(total) }}</b></li>
    </ul>
    <ul class="mt__cobros">
      <li v-for="(c, i) in COBROS" :key="c.medio" :style="{ animationDelay: `${300 + i * 260}ms` }">
        <span>{{ c.medio }}</span><b>{{ pesos(c.monto) }}</b>
      </li>
    </ul>
    <p class="mt__cierre">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><path d="M5 12l5 5L20 7"/></svg>
      Cierre de caja · cuadra
    </p>
  </div>
</template>

<script setup>
const ITEMS = [
  { d: 'King’s Juice · flor · 5 g', p: 25000 },
  { d: 'Aceite 10 ml',              p: 18000 },
]
const COBROS = [
  { medio: 'A favor de la vez pasada', monto: 3000 },
  { medio: 'Efectivo',                 monto: 20000 },
  { medio: 'Transferencia',            monto: 20000 },
]
const total = ITEMS.reduce((s, i) => s + i.p, 0)
const pesos = (n) => `$ ${n.toLocaleString('es-AR')}`
</script>

<style scoped>
.mt { display: flex; flex-direction: column; justify-content: center; gap: 12px; max-width: 420px; width: 100%; margin: 0 auto; }
.mt__cab { display: flex; justify-content: space-between; font: 500 11px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); padding-bottom: 8px; border-bottom: 1px solid var(--hb-regla); }
.mt__pac { margin: 0; font: 600 1.15rem var(--hb-serif); color: var(--hb-tinta); display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 10px; }
.mt__pac small { font: 500 11px var(--hb-mono); letter-spacing: .06em; color: var(--hb-verde); border: 1px solid var(--hb-salvia); border-radius: 999px; padding: 1px 8px; }
.mt ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
.mt li { display: flex; justify-content: space-between; gap: 12px; font-size: .92rem; color: var(--hb-tinta); }
.mt li b { font: 500 14px var(--hb-mono); white-space: nowrap; }
.mt__total { padding-top: 8px; border-top: 1px dashed var(--hb-regla); font-weight: 600; }
.mt__total b { font-weight: 600 !important; }
.mt__cobros { padding: 12px 14px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); }
.mt__cobros li { color: var(--hb-tinta-2); opacity: 0; animation: mt-entra .4s ease forwards; }
.mt__cobros li b { color: var(--hb-tinta); }
.mt__cierre { margin: 0; display: flex; align-items: center; gap: 8px; font: 600 .95rem var(--hb-sans); color: var(--hb-verde); opacity: 0; animation: mt-entra .4s ease 1.2s forwards; }
@keyframes mt-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .mt__cobros li, .mt__cierre { animation: none; opacity: 1; } }
</style>
