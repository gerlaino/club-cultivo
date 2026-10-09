<template>
  <!-- EL PANEL DE ADMINISTRACIÓN, como pantalla de escritorio (Germán, 9-oct-2026: quien contrata
       es quien conduce la organización; no riega, quiere saber cómo va todo sin estar en cada sala).
       Datos ficticios; lo que muestra existe en la app: pacientes, dispensas, caja, stock, tareas
       por sala, plantas en floración contra el tope del plan y los avisos para mirar.
       Usa los colores de la app (como los teléfonos de `OficiosVista`), no los de la página. -->
  <div class="adm" role="img" aria-label="El panel de administración: pacientes, dispensas, caja, stock, salas y avisos">
    <div class="adm__barra" aria-hidden="true"><i></i><i></i><i></i><span>Inicio · Administración</span></div>
    <div class="adm__cab">
      <div><small>Asociación Ejemplo · Sede Palermo</small><b>Hoy en la organización</b></div>
      <span class="adm__vivo">Al día · jueves 14, 17:42</span>
    </div>
    <div class="adm__cuerpo">
      <div class="adm__kpis">
        <div v-for="k in KPIS" :key="k.t" class="adm__kpi"><small>{{ k.t }}</small><b>{{ k.v }}</b><em>{{ k.d }}</em></div>
      </div>
      <div class="adm__dos">
        <div class="adm__caja">
          <p class="adm__t"><span>Cultivo</span><span>Tareas de hoy</span></p>
          <div v-for="s in SALAS" :key="s.sala" class="adm__fila">
            <div><b>{{ s.sala }}</b><small>{{ s.det }}</small></div>
            <span class="adm__chip" :class="s.ojo ? 'adm__chip--ojo' : 'adm__chip--ok'">{{ s.tareas }}</span>
          </div>
          <div class="adm__tope">
            <span>En floración: 318 de 450 plantas del plan</span>
            <div><i></i></div>
          </div>
        </div>
        <div class="adm__caja">
          <p class="adm__t"><span>Para mirar</span></p>
          <div v-for="a in AVISOS" :key="a[0]" class="adm__aviso"><span>{{ a[0] }}</span><b>{{ a[1] }}</b></div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
const KPIS = [
  { t: 'Pacientes activos',  v: '87',        d: '4 nuevos este mes' },
  { t: 'Dispensado hoy',     v: '$ 412.000', d: '23 dispensas' },
  { t: 'Caja del mostrador', v: 'Abierta',   d: 'Sofía · desde 14:02' },
  { t: 'Flor en stock',      v: '1.240 g',   d: '3 genéticas' },
]
const SALAS = [
  { sala: 'Flora 2', det: 'L-26-002 · floración día 23',    tareas: '4 de 4' },
  { sala: 'Flora 1', det: 'L-26-007 · floración semana 3',  tareas: '1 sin hacer', ojo: true },
  { sala: 'Vege 1',  det: '2 lotes · vegetativo día 18',    tareas: '3 de 3' },
]
const AVISOS = [
  ['REPROCANN por vencer', '6 pacientes'],
  ['Pesadas para aprobar', '2'],
  ['Turnos sin cerrar', '1'],
  ['Stock bajo · Aceite 1:1', 'quedan 3'],
]
</script>

<style scoped>
.adm { background: #F4F8F5; color: #1A1D1F; border-radius: 12px; overflow: hidden; font-family: var(--hb-sans); box-shadow: 0 30px 70px -34px rgb(10 30 20 / .55); border: 1px solid rgb(255 255 255 / .12); text-align: left; }
.adm__barra { display: flex; align-items: center; gap: 6px; padding: 9px 12px; background: #E1E8E3; }
.adm__barra i { width: 9px; height: 9px; border-radius: 50%; background: #C3CEC6; }
.adm__barra span { margin-left: 10px; font: 11px var(--hb-mono); color: #3A3F44; }
.adm__cab { background: #1A3D2E; color: #fff; padding: 14px 18px; display: flex; justify-content: space-between; align-items: flex-end; gap: 12px; flex-wrap: wrap; }
.adm__cab b { font-size: 17px; display: block; }
.adm__cab small { font-size: 11px; color: #A8C9B5; }
.adm__vivo { display: inline-flex; align-items: center; gap: 6px; font-size: 11px; color: #E8F0EB; }
.adm__vivo::before { content: ''; width: 7px; height: 7px; border-radius: 50%; background: #9FD1B0; animation: adm-late 2s infinite; }
.adm__cuerpo { padding: 14px; display: grid; gap: 12px; }
.adm__kpis { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; }
@media (max-width: 560px) { .adm__kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
.adm__kpi { background: #fff; border: 1px solid #E1E8E3; border-radius: 10px; padding: 9px 11px; display: grid; gap: 2px; min-width: 0; }
.adm__kpi small { font-size: 10.5px; color: #3A3F44; }
.adm__kpi b { font-size: 17px; font-variant-numeric: tabular-nums; white-space: nowrap; }
.adm__kpi em { font-style: normal; font-size: 10.5px; color: #2D4A3E; font-weight: 600; }
.adm__dos { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(0, .9fr); gap: 12px; }
@media (max-width: 560px) { .adm__dos { grid-template-columns: minmax(0, 1fr); } }
.adm__caja { background: #fff; border: 1px solid #E1E8E3; border-radius: 10px; padding: 11px 12px; display: grid; gap: 7px; align-content: start; min-width: 0; }
.adm__t { margin: 0; font-size: 10.5px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: #3A3F44; display: flex; justify-content: space-between; }
.adm__fila { display: flex; justify-content: space-between; align-items: center; gap: 8px; font-size: 12px; padding: 6px 0; border-top: 1px solid #EEF2EF; }
.adm__fila:first-of-type { border-top: 0; }
.adm__fila > div { display: flex; flex-direction: column; min-width: 0; }
.adm__fila small { font-size: 10.5px; color: #3A3F44; }
.adm__chip { font-size: 10.5px; font-weight: 700; padding: 2px 8px; border-radius: 99px; white-space: nowrap; }
.adm__chip--ok { background: #E8F0EB; color: #1A3D2E; }
.adm__chip--ojo { background: #FEF3C7; color: #92400E; }
.adm__tope { display: grid; gap: 4px; font-size: 11px; color: #3A3F44; margin-top: 2px; }
.adm__tope div { height: 7px; border-radius: 99px; background: #E1E8E3; overflow: hidden; }
.adm__tope i { display: block; height: 100%; width: 70.7%; background: #2D4A3E; border-radius: 99px; transform-origin: left; animation: adm-avanza 1.1s cubic-bezier(.2, .7, .2, 1) both; }
.adm__aviso { display: flex; justify-content: space-between; gap: 8px; align-items: center; font-size: 12px; padding: 7px 9px; border-radius: 8px; background: #FFFBEB; border: 1px solid #FDE68A; }
.adm__aviso b { color: #92400E; white-space: nowrap; }
.adm__cuerpo > *, .adm__caja > * { animation: adm-entra .4s ease both; }
@keyframes adm-late { 0% { box-shadow: 0 0 0 0 rgb(159 209 176 / .7); } 70%, 100% { box-shadow: 0 0 0 7px rgb(159 209 176 / 0); } }
@keyframes adm-avanza { from { transform: scaleX(0); } }
@keyframes adm-entra { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
@media (prefers-reduced-motion: reduce) { .adm__vivo::before, .adm__tope i, .adm__cuerpo > *, .adm__caja > * { animation: none; } }
</style>
