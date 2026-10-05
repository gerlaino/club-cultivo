<template>
  <!-- El registro por voz: lo que se dijo, lo que el asistente propone y la confirmación. Nada se
       guarda sin que la persona confirme (así funciona en la app). -->
  <div class="mi">
    <div class="mi__dicho">
      <span class="mi__mic" aria-hidden="true">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3"/></svg>
      </span>
      <p>«Regué las tres de la carpa con un litro y medio cada una, pH 6,2, y les puse 2 ml de flora por litro.»</p>
    </div>

    <div class="mi__propuesta">
      <p class="mi__cab">El asistente propone</p>
      <ul>
        <li v-for="(r, i) in REGISTROS" :key="r.que" :style="{ animationDelay: `${600 + i * 300}ms` }">
          <b>{{ r.que }}</b><span>{{ r.det }}</span>
        </li>
      </ul>
      <div class="mi__acciones">
        <span class="mi__btn mi__btn--ok">Confirmar</span>
        <span class="mi__btn">Corregir</span>
      </div>
    </div>
  </div>
</template>

<script setup>
const REGISTROS = [
  { que: 'Riego',     det: '3 plantas · 1,5 L c/u · pH 6,2' },
  { que: 'Nutriente', det: 'Flora · 2 ml/L · 4,5 L de solución' },
  { que: 'Dónde',     det: 'Carpa · lote L-26-002' },
]
</script>

<style scoped>
.mi { display: flex; flex-direction: column; justify-content: center; gap: 16px; }
.mi__dicho { display: flex; gap: 12px; align-items: flex-start; }
.mi__mic {
  width: 38px; height: 38px; flex-shrink: 0; border-radius: 50%; display: grid; place-items: center;
  background: var(--hb-verde); color: var(--hb-papel-claro); animation: mi-late 1.4s ease-in-out 2;
}
.mi__dicho p {
  margin: 0; padding: 12px 14px; border-radius: 4px 14px 14px 14px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla);
  font: italic 400 1.05rem/1.45 var(--hb-serif); color: var(--hb-tinta);
}
.mi__propuesta { margin-left: 50px; padding: 14px 16px; background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde); }
.mi__cab { margin: 0 0 10px; font: 500 11px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-verde); }
.mi ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
.mi li { display: grid; grid-template-columns: 82px minmax(0, 1fr); gap: 10px; font-size: .9rem; opacity: 0; animation: mi-entra .35s ease forwards; }
.mi li b { font-weight: 600; color: var(--hb-tinta); }
.mi li span { color: var(--hb-tinta-2); }
.mi__acciones { display: flex; gap: 8px; margin-top: 14px; }
.mi__btn { padding: 7px 14px; border-radius: 999px; border: 1px solid var(--hb-regla); font: 600 13px var(--hb-sans); color: var(--hb-tinta-2); }
.mi__btn--ok { background: var(--hb-verde); border-color: var(--hb-verde); color: var(--hb-papel-claro); }
@media (max-width: 480px) { .mi__propuesta { margin-left: 0; } }
@keyframes mi-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@keyframes mi-late { 50% { box-shadow: 0 0 0 8px color-mix(in srgb, var(--hb-verde) 18%, transparent); } }
@media (prefers-reduced-motion: reduce) { .mi li { animation: none; opacity: 1; } .mi__mic { animation: none; } }
</style>
