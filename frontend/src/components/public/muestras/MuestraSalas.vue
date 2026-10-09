<template>
  <!-- Las salas vistas desde administración: fase, lote y las tareas del día cumplidas, y la que
       quedó sin hacer con quién la marcó (las tareas se cierran con «Hecho» / «No se hizo»). -->
  <div class="ms">
    <p class="ms__t">Salas · Sede Palermo <span>jueves 14 · 17:30</span></p>
    <div v-for="(s, i) in SALAS" :key="s.sala" class="ms__sala" :class="{ 'ms__sala--ojo': s.ojo }" :style="{ animationDelay: `${100 + i * 180}ms` }">
      <b>{{ s.sala }}</b>
      <span class="ms__tareas">{{ s.tareas }}<br>tareas</span>
      <small><span class="ms__fase">{{ s.fase }}</span> · {{ s.det }}</small>
    </div>
    <div class="ms__nohizo">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M12 3l9.5 17h-19z M12 10v4 M12 17.5v.5"/></svg>
      <span><b>No se hizo:</b> defoliar L-26-007 · lo marcó Lucía a las 17:10</span>
    </div>
  </div>
</template>

<script setup>
const SALAS = [
  { sala: 'Flora 2', fase: 'Floración · día 23',   det: 'L-26-002 · 12 plantas · 24,8° · 55 %', tareas: '4 de 4' },
  { sala: 'Flora 1', fase: 'Floración · semana 3', det: 'L-26-007 · 10 plantas',                tareas: '2 de 3', ojo: true },
  { sala: 'Vege 1',  fase: 'Vegetativo · día 18',  det: 'L-26-011 y L-26-012 · 24 plantas',     tareas: '3 de 3' },
]
</script>

<style scoped>
.ms { display: grid; gap: 10px; }
.ms__t { margin: 0; font: 600 1rem var(--hb-sans); color: var(--hb-tinta); display: flex; justify-content: space-between; gap: 10px; flex-wrap: wrap; }
.ms__t span { font: 500 11px var(--hb-mono); letter-spacing: .08em; color: var(--hb-tinta-2); }
.ms__sala {
  display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 4px 12px; padding: 11px 12px;
  background: var(--hb-papel); border: 1px solid var(--hb-regla); border-left: 3px solid var(--hb-verde);
  opacity: 0; animation: ms-entra .35s ease forwards;
}
.ms__sala--ojo { border-left-color: var(--hb-ambar); }
.ms__sala b { font-weight: 600; color: var(--hb-tinta); }
.ms__sala small { grid-column: 1; font-size: .84rem; color: var(--hb-tinta-2); }
.ms__fase { font: 500 10.5px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-verde); }
.ms__tareas { grid-row: span 2; align-self: center; font: 500 12px var(--hb-mono); color: var(--hb-verde); text-align: right; }
.ms__sala--ojo .ms__tareas { color: var(--hb-tierra); }
.ms__nohizo {
  display: flex; gap: 8px; align-items: center; padding: 9px 12px; font-size: .86rem; color: var(--hb-tinta);
  border-left: 3px solid var(--hb-ambar); background: color-mix(in srgb, var(--hb-ambar) 12%, var(--hb-papel-claro));
  opacity: 0; animation: ms-entra .35s ease 1s forwards;
}
.ms__nohizo svg { color: var(--hb-tierra); flex-shrink: 0; }
@keyframes ms-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .ms__sala, .ms__nohizo { animation: none; opacity: 1; } }
</style>
