<template>
  <!-- El VPD de una sala en las últimas 24 h, con la banda ideal de la fase y el momento en que se
       salió del rango (con ícono y rótulo, no sólo color). Una serie: el título la nombra. -->
  <div class="ma">
    <div class="ma__lect">
      <div v-for="l in LECTURA" :key="l.que"><span>{{ l.que }}</span><b>{{ l.valor }}</b></div>
    </div>
    <p class="ma__t">VPD · {{ espacio }} <span>últimas 24 h · kPa</span></p>
    <svg class="ma__plot" :viewBox="`0 0 ${W} ${H}`" role="img" :aria-label="descripcion" @mouseleave="hover = null">
      <rect class="ma__banda" x="0" :y="y(BANDA[1])" :width="W" :height="y(BANDA[0]) - y(BANDA[1])" />
      <text class="ma__banda-t" x="6" :y="y(BANDA[1]) + 13">Rango de la fase · 1,0–1,5</text>
      <line v-for="v in [0.5, 1, 1.5, 2]" :key="v" class="ma__grilla" x1="0" :x2="W" :y1="y(v)" :y2="y(v)" />
      <text v-for="v in [0.5, 1, 1.5, 2]" :key="`t${v}`" class="ma__eje" :x="W - 2" :y="y(v) - 3" text-anchor="end">{{ String(v).replace('.', ',') }}</text>
      <path class="ma__linea" :d="camino" pathLength="1" />
      <!-- El desvío -->
      <circle class="ma__alerta" :cx="x(PICO)" :cy="y(SERIE[PICO])" r="5" />
      <line v-if="hover !== null" class="ma__cruz" :x1="x(hover)" :x2="x(hover)" y1="0" :y2="H" />
      <circle v-if="hover !== null" class="ma__punto" :cx="x(hover)" :cy="y(SERIE[hover])" r="4" />
      <rect v-for="(_, i) in SERIE" :key="`h${i}`" class="ma__hit" :x="x(i) - W / SERIE.length / 2" y="0"
            :width="W / SERIE.length" :height="H" @mouseenter="hover = i" />
    </svg>
    <div class="ma__ejes"><span>00 h</span><span>06 h</span><span>12 h</span><span>18 h</span><span>24 h</span></div>
    <p class="ma__aviso" :class="{ 'ma__aviso--hover': hover !== null }">
      <template v-if="hover !== null">{{ String(hover).padStart(2, '0') }}:00 · VPD {{ coma(SERIE[hover]) }} kPa</template>
      <template v-else>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" aria-hidden="true"><path d="M12 3l9.5 17h-19z M12 10v4 M12 17.5v.5"/></svg>
        14:00 · VPD 1,7 kPa · se avisó al teléfono
      </template>
    </p>
  </div>
</template>

<script setup>
import { ref } from 'vue'

defineProps({ espacio: { type: String, default: 'Flora 2' } })

const LECTURA = [
  { que: 'Temperatura', valor: '26,1 °C' },
  { que: 'Humedad',     valor: '58 %' },
  { que: 'VPD',         valor: '1,26 kPa' },
]
// Una lectura por hora. De noche baja (luces apagadas), de día se mantiene en rango y a las 14 h
// se escapa: un día de calor con el extractor corto.
const SERIE = [0.82, 0.8, 0.78, 0.79, 0.8, 0.84, 1.05, 1.16, 1.22, 1.25, 1.28, 1.3, 1.38, 1.55, 1.7, 1.52, 1.36, 1.3, 1.27, 1.24, 1.2, 1.1, 0.92, 0.85]
const PICO = 14
const BANDA = [1.0, 1.5]
const W = 420, H = 180, MIN = 0.4, MAX = 2.1

const x = (i) => (i / (SERIE.length - 1)) * W
const y = (v) => H - ((v - MIN) / (MAX - MIN)) * H
const camino = SERIE.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ')
const coma = (v) => v.toLocaleString('es-AR', { minimumFractionDigits: 2 })
const descripcion = `VPD de las últimas 24 horas, entre ${coma(Math.min(...SERIE))} y ${coma(Math.max(...SERIE))} kPa; se salió del rango a las 14.`
const hover = ref(null)
</script>

<style scoped>
.ma { display: flex; flex-direction: column; justify-content: center; gap: 8px; }
.ma__lect { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; margin-bottom: 10px; }
.ma__lect div { display: flex; flex-direction: column; gap: 2px; padding: 10px 12px; background: var(--hb-papel-claro); border: 1px solid var(--hb-regla); }
.ma__lect span { font: 500 10.5px var(--hb-mono); letter-spacing: .08em; text-transform: uppercase; color: var(--hb-tinta-2); }
.ma__lect b { font: 600 1.15rem var(--hb-serif); color: var(--hb-tinta); }
.ma__t { margin: 0; font: 600 1rem var(--hb-sans); color: var(--hb-tinta); }
.ma__t span { font: 500 11px var(--hb-mono); letter-spacing: .08em; color: var(--hb-tinta-2); margin-left: 6px; }
.ma__plot { width: 100%; height: auto; overflow: visible; }
.ma__banda { fill: var(--hb-salvia-suave); }
.ma__banda-t { font: 10.5px var(--hb-mono); fill: var(--hb-verde); }
.ma__grilla { stroke: var(--hb-regla); stroke-width: 1; }
.ma__eje { font: 10px var(--hb-mono); fill: var(--hb-tinta-2); }
.ma__linea { fill: none; stroke: var(--hb-verde); stroke-width: 2; stroke-linejoin: round; stroke-linecap: round; stroke-dasharray: 1; stroke-dashoffset: 1; animation: ma-traza 1.6s ease forwards; }
.ma__alerta { fill: var(--hb-ambar); stroke: var(--hb-papel); stroke-width: 2; opacity: 0; animation: ma-aparece .3s ease 1.3s forwards; }
.ma__cruz { stroke: var(--hb-tinta-2); stroke-width: 1; stroke-dasharray: 3 3; pointer-events: none; }
.ma__punto { fill: var(--hb-verde); stroke: var(--hb-papel); stroke-width: 2; pointer-events: none; }
.ma__hit { fill: transparent; }
.ma__ejes { display: flex; justify-content: space-between; font: 10.5px var(--hb-mono); color: var(--hb-tinta-2); }
.ma__aviso {
  margin: 6px 0 0; min-height: 34px; display: flex; align-items: center; gap: 8px; padding: 6px 10px;
  border-left: 3px solid var(--hb-ambar); background: color-mix(in srgb, var(--hb-ambar) 12%, var(--hb-papel-claro));
  font-size: .88rem; color: var(--hb-tinta); opacity: 0; animation: ma-aparece .3s ease 1.5s forwards;
}
.ma__aviso svg { color: var(--hb-tierra); flex-shrink: 0; }
.ma__aviso--hover { border-left-color: var(--hb-verde); background: var(--hb-papel-claro); font-family: var(--hb-mono); font-size: .82rem; }
@keyframes ma-traza { to { stroke-dashoffset: 0; } }
@keyframes ma-aparece { to { opacity: 1; } }
@media (prefers-reduced-motion: reduce) {
  .ma__linea { animation: none; stroke-dashoffset: 0; }
  .ma__alerta, .ma__aviso { animation: none; opacity: 1; }
}
</style>
