<template>
  <!-- La agenda del día de un médico (sobre el horario que cargó) y, al lado, la indicación del
       paciente que está atendiendo: vencimiento con aviso y la prescripción en PDF. Los estados
       van con su palabra, no sólo con color. -->
  <div class="mtu">
    <div>
      <p class="mtu__t">Agenda · Dra. López</p>
      <p class="mtu__sub">Martes 14 de octubre · horario 14 a 18 h</p>
      <ol class="mtu__lista">
        <li v-for="(t, i) in TURNOS" :key="t.hora" class="mtu__turno" :class="[`mtu__turno--${t.estado || 'libre'}`, { 'mtu__turno--ahora': t.ahora }]"
            :style="{ animationDelay: `${i * 110}ms` }">
          <span class="mtu__hora">{{ t.hora }}</span>
          <template v-if="t.paciente">
            <span class="mtu__quien">{{ t.paciente }}<small>{{ t.tipo }}</small></span>
            <span class="mtu__estado">{{ ESTADO[t.estado] }}</span>
          </template>
          <span v-else class="mtu__libre">Libre</span>
        </li>
      </ol>
    </div>

    <aside class="mtu__ficha">
      <p class="mtu__ficha-cab">Atendiendo · 15:30</p>
      <p class="mtu__pac">Paciente N.º 0302</p>
      <div class="mtu__ind">
        <span>Indicación médica</span>
        <b>Aceite 1:1 · 0,5 ml cada 12 h</b>
        <p class="mtu__vence">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
          Vence en 12 días · ya avisó
        </p>
      </div>
      <p class="mtu__nota">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>
        Notas del médico: sólo las ve el médico
      </p>
      <span class="mtu__pdf">Prescripción · PDF</span>
    </aside>
  </div>
</template>

<script setup>
// Tipos y estados: los de `Turno::TIPOS` y `Turno::ESTADOS`.
const ESTADO = { realizado: 'Realizado', ausente: 'Ausente', confirmado: 'Confirmado', programado: 'Programado' }
const TURNOS = [
  { hora: '14:00', paciente: 'Paciente N.º 0231', tipo: 'Seguimiento', estado: 'realizado' },
  { hora: '14:30', paciente: 'Paciente N.º 0187', tipo: 'Primera vez', estado: 'ausente' },
  { hora: '15:00' },
  { hora: '15:30', paciente: 'Paciente N.º 0302', tipo: 'Revisión',    estado: 'confirmado', ahora: true },
  { hora: '16:00', paciente: 'Paciente N.º 0145', tipo: 'Seguimiento', estado: 'programado' },
  { hora: '16:30', paciente: 'Paciente N.º 0098', tipo: 'Urgencia',    estado: 'programado' },
]
</script>

<style scoped>
.mtu { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 16px; align-items: start; }
@media (max-width: 560px) { .mtu { grid-template-columns: minmax(0, 1fr); } }

.mtu__t { margin: 0; font: 600 1rem var(--hb-sans); color: var(--hb-tinta); }
.mtu__sub { margin: 2px 0 10px; font: 11px var(--hb-mono); color: var(--hb-tinta-2); }
.mtu__lista { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
.mtu__turno {
  display: grid; grid-template-columns: 44px minmax(0, 1fr) auto; gap: 10px; align-items: center;
  padding: 8px 10px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); border-left-width: 3px;
  opacity: 0; animation: mtu-entra .35s ease forwards;
}
.mtu__hora { font: 500 12px var(--hb-mono); color: var(--hb-tinta-2); }
.mtu__quien { display: flex; flex-direction: column; font-size: .88rem; font-weight: 600; color: var(--hb-tinta); min-width: 0; }
.mtu__quien small { font-weight: 400; font-size: .78rem; color: var(--hb-tinta-2); }
.mtu__estado { font: 500 10.5px var(--hb-mono); letter-spacing: .04em; text-transform: uppercase; padding: 2px 7px; border-radius: 999px; border: 1px solid var(--hb-regla); color: var(--hb-tinta-2); white-space: nowrap; }
.mtu__libre { grid-column: 2 / -1; font: 12px var(--hb-mono); color: var(--hb-tinta-2); opacity: .7; }
.mtu__turno--libre { background: transparent; border-style: dashed; }
.mtu__turno--realizado { border-left-color: var(--hb-verde); }
.mtu__turno--realizado .mtu__estado { color: var(--hb-verde); border-color: var(--hb-salvia); }
.mtu__turno--ausente { border-left-color: var(--hb-ambar); }
.mtu__turno--ausente .mtu__quien { color: var(--hb-tinta-2); }
.mtu__turno--ausente .mtu__estado { color: var(--hb-tierra); border-color: color-mix(in srgb, var(--hb-ambar) 50%, transparent); }
.mtu__turno--confirmado { border-left-color: var(--hb-verde); }
.mtu__turno--programado { border-left-color: var(--hb-regla); }
.mtu__turno--ahora { border-color: var(--hb-verde); box-shadow: 0 0 0 3px var(--hb-salvia-suave); }
.mtu__turno--ahora .mtu__estado { background: var(--hb-verde); border-color: var(--hb-verde); color: var(--hb-papel-claro); }

.mtu__ficha {
  display: flex; flex-direction: column; gap: 10px; padding: 14px 16px;
  background: var(--hb-papel-claro); border: 1.5px solid var(--hb-verde);
  opacity: 0; animation: mtu-entra .4s ease .7s forwards;
}
.mtu__ficha-cab { margin: 0; font: 500 11px var(--hb-mono); letter-spacing: .1em; text-transform: uppercase; color: var(--hb-verde); }
.mtu__pac { margin: 0; font: 600 1.15rem var(--hb-serif); color: var(--hb-tinta); }
.mtu__ind { display: flex; flex-direction: column; gap: 3px; padding: 10px 0; border-block: 1px dashed var(--hb-regla); }
.mtu__ind span { font: 500 10.5px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
.mtu__ind b { font-size: .92rem; color: var(--hb-tinta); }
.mtu__vence { margin: 4px 0 0; display: flex; align-items: center; gap: 6px; font-size: .82rem; color: var(--hb-tierra); }
.mtu__nota { margin: 0; display: flex; align-items: center; gap: 6px; font-size: .8rem; color: var(--hb-tinta-2); }
.mtu__pdf { align-self: flex-start; font: 500 11px var(--hb-mono); letter-spacing: .06em; color: var(--hb-verde); border: 1px solid var(--hb-salvia); border-radius: 999px; padding: 3px 10px; }
@keyframes mtu-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .mtu__turno, .mtu__ficha { animation: none; opacity: 1; } }
</style>
