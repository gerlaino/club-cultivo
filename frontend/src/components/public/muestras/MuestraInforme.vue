<template>
  <!-- Un informe abreviado, como sale en PDF: por genética, con el balance que cierra y el costo
       por gramo al pie. -->
  <div class="mn">
    <div class="mn__hoja">
      <div class="mn__cab">
        <div>
          <p class="mn__titulo">Informe de producción</p>
          <p class="mn__sub">1.er semestre 2026 · Organización Ejemplo</p>
        </div>
        <span class="mn__fmt">PDF · CSV</span>
      </div>
      <table class="mn__tabla">
        <thead><tr><th>Genética</th><th>Cosechado</th><th>Entregado</th><th>En stock</th></tr></thead>
        <tbody>
          <tr v-for="(f, i) in FILAS" :key="f.gen" :style="{ animationDelay: `${i * 160}ms` }">
            <td>{{ f.gen }}</td><td>{{ g(f.cos) }}</td><td>{{ g(f.ent) }}</td><td>{{ g(f.cos - f.ent - f.per) }}</td>
          </tr>
        </tbody>
        <tfoot><tr><td>Total</td><td>{{ g(tot('cos')) }}</td><td>{{ g(tot('ent')) }}</td><td>{{ g(tot('cos') - tot('ent') - tot('per')) }}</td></tr></tfoot>
      </table>
      <div class="mn__pie">
        <span class="mn__ok">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" aria-hidden="true"><path d="M5 12l5 5L20 7"/></svg>
          Balance: cuadra (pérdidas declaradas {{ g(tot('per')) }})
        </span>
        <span class="mn__costo">Costo por gramo <b>$ 1.840</b></span>
      </div>
    </div>
    <div class="mn__otros">
      <span v-for="o in OTROS" :key="o">{{ o }}</span>
    </div>
  </div>
</template>

<script setup>
const FILAS = [
  { gen: 'King’s Juice', cos: 1420, ent: 1105, per: 22 },
  { gen: 'Gorilla Glue', cos: 980,  ent: 760,  per: 15 },
  { gen: 'Amnesia',      cos: 640,  ent: 512,  per: 9 },
]
const OTROS = ['REPROCANN', 'INASE', 'Inventario', 'Pérdidas', 'Dispensaciones']
const tot = (k) => FILAS.reduce((s, f) => s + f[k], 0)
const g = (n) => `${n.toLocaleString('es-AR')} g`
</script>

<style scoped>
.mn { display: flex; flex-direction: column; justify-content: center; gap: 14px; }
.mn__hoja { background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); padding: 16px 18px; box-shadow: 0 10px 24px -18px color-mix(in srgb, var(--hb-tinta) 60%, transparent); }
.mn__cab { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; padding-bottom: 10px; border-bottom: 1.5px solid var(--hb-tinta); }
.mn__titulo { margin: 0; font: 600 1.15rem var(--hb-serif); color: var(--hb-tinta); }
.mn__sub { margin: 2px 0 0; font: 11px var(--hb-mono); color: var(--hb-tinta-2); }
.mn__fmt { font: 500 10.5px var(--hb-mono); letter-spacing: .08em; color: var(--hb-verde); border: 1px solid var(--hb-salvia); border-radius: 999px; padding: 2px 8px; white-space: nowrap; }
.mn__tabla { width: 100%; border-collapse: collapse; margin-top: 8px; font-size: .86rem; }
.mn__tabla th { text-align: right; font: 500 10.5px var(--hb-mono); letter-spacing: .06em; text-transform: uppercase; color: var(--hb-tinta-2); padding: 6px 0; }
.mn__tabla td { text-align: right; padding: 7px 0; border-top: 1px solid var(--hb-regla); font-family: var(--hb-mono); font-size: .82rem; color: var(--hb-tinta); }
.mn__tabla th:first-child, .mn__tabla td:first-child { text-align: left; font-family: var(--hb-sans); font-size: .88rem; }
.mn__tabla tbody tr { opacity: 0; animation: mn-entra .35s ease forwards; }
.mn__tabla tfoot td { font-weight: 600; border-top: 1.5px solid var(--hb-tinta); }
.mn__pie { display: flex; flex-wrap: wrap; justify-content: space-between; gap: 8px 16px; margin-top: 12px; font-size: .84rem; }
.mn__ok { display: inline-flex; align-items: center; gap: 6px; color: var(--hb-verde); font-weight: 600; }
.mn__costo { color: var(--hb-tinta-2); }
.mn__costo b { font-family: var(--hb-mono); color: var(--hb-tinta); }
.mn__otros { display: flex; flex-wrap: wrap; gap: 6px; }
.mn__otros span { font: 500 11px var(--hb-mono); letter-spacing: .06em; color: var(--hb-tinta-2); border: 1px solid var(--hb-regla); border-radius: 999px; padding: 3px 10px; background: var(--hb-papel-claro); }
@keyframes mn-entra { from { opacity: 0; } to { opacity: 1; } }
@media (prefers-reduced-motion: reduce) { .mn__tabla tbody tr { animation: none; opacity: 1; } }
</style>
