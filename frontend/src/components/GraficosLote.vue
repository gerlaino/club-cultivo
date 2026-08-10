<template>
  <div class="gl">

    <div class="gl__tabs">
      <button
        v-for="m in METRICAS" :key="m.key"
        class="gl__tab"
        :class="{ 'gl__tab--active': metricaActiva === m.key }"
        :style="metricaActiva === m.key ? { borderColor: m.color, color: m.color } : {}"
        @click="metricaActiva = m.key"
      >
        <span class="gl__tab-dot" :style="{ background: m.color }"></span>
        {{ m.label }}
        <span v-if="ultimoValor(m.key) !== null" class="gl__tab-val">
          {{ ultimoValor(m.key) }}{{ m.unit }}
        </span>
      </button>
    </div>

    <div v-if="loading" class="gl__loading">
      <DsSpinner :size="24" />
    </div>

    <div v-else-if="!datos.length" class="gl__empty">
      <span>📊</span>
      <p>Sin registros ambientales aún</p>
    </div>

    <div v-else-if="!valoresValidos.length" class="gl__empty">
      <span>📭</span>
      <p>Sin registros de {{ metrica.label }} todavía</p>
    </div>

    <div v-else class="gl__chart-wrap">
      <svg :viewBox="`0 0 ${W} ${H}`" class="gl__svg" @mousemove="onMouseMove" @mouseleave="tooltip = null">

        <g class="gl__grid">
          <line
            v-for="(tick, i) in yTicks" :key="'g'+i"
            :x1="PAD_L" :y1="yScale(tick)"
            :x2="W - PAD_R" :y2="yScale(tick)"
            stroke="currentColor" stroke-width="0.5" opacity="0.12"
          />
          <text
            v-for="(tick, i) in yTicks" :key="'l'+i"
            :x="PAD_L - 8" :y="yScale(tick) + 4"
            text-anchor="end" class="gl__axis-label"
          >{{ tick }}{{ metrica.unit }}</text>
        </g>

        <g>
          <text
            v-for="(d, i) in xLabels" :key="'x'+i"
            :x="d.x" :y="H - PAD_B + 16"
            text-anchor="middle" class="gl__axis-label"
          >{{ d.label }}</text>
        </g>

        <g v-if="metrica.optimo">
          <rect
            :x="PAD_L"
            :y="yScale(metrica.optimo[1])"
            :width="W - PAD_L - PAD_R"
            :height="Math.max(yScale(metrica.optimo[0]) - yScale(metrica.optimo[1]), 0)"
            :fill="metrica.color"
            fill-opacity="0.06"
          />
          <text
            :x="W - PAD_R + 4"
            :y="yScale((metrica.optimo[0] + metrica.optimo[1]) / 2) + 4"
            class="gl__range-label"
            :fill="metrica.color"
          >óptimo</text>
        </g>

        <path :d="areaPath" :fill="metrica.color" fill-opacity="0.08"/>

        <path
          :d="linePath"
          fill="none"
          :stroke="metrica.color"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />

        <circle
          v-for="(p, i) in puntos" :key="'p'+i"
          :cx="p.x" :cy="p.y" r="3"
          :fill="metrica.color" opacity="0.6"
        />

        <g v-if="tooltip">
          <line
            :x1="tooltip.x" :y1="PAD_T"
            :x2="tooltip.x" :y2="H - PAD_B"
            :stroke="metrica.color"
            stroke-width="1" stroke-dasharray="4 3" opacity="0.5"
          />
          <circle
            :cx="tooltip.x" :cy="tooltip.y" r="5"
            :fill="metrica.color" stroke="white" stroke-width="2"
          />
        </g>

      </svg>

      <div
        v-if="tooltip"
        class="gl__tooltip"
        :style="{ left: tooltip.screenX + 'px', top: tooltip.screenY + 'px' }"
      >
        <div class="gl__tooltip-fecha">{{ tooltip.fecha }}</div>
        <div class="gl__tooltip-val" :style="{ color: metrica.color }">
          {{ tooltip.valor }}{{ metrica.unit }}
        </div>
      </div>

      <div class="gl__stats">
        <div class="gl__stat">
          <span class="gl__stat-label">Último</span>
          <span class="gl__stat-val" :style="{ color: metrica.color }">{{ stats.ultimo }}{{ metrica.unit }}</span>
        </div>
        <div class="gl__stat">
          <span class="gl__stat-label">Promedio</span>
          <span class="gl__stat-val">{{ stats.promedio }}{{ metrica.unit }}</span>
        </div>
        <div class="gl__stat">
          <span class="gl__stat-label">Mín</span>
          <span class="gl__stat-val">{{ stats.min }}{{ metrica.unit }}</span>
        </div>
        <div class="gl__stat">
          <span class="gl__stat-label">Máx</span>
          <span class="gl__stat-val">{{ stats.max }}{{ metrica.unit }}</span>
        </div>
        <div class="gl__stat">
          <span class="gl__stat-label">Registros</span>
          <span class="gl__stat-val">{{ valoresValidos.length }}</span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { getRegistrosAmbientales } from '../lib/api'
import DsSpinner from '../design-system/components/Spinner.vue'

const props = defineProps({
  loteId: { type: Number, required: true }
})

const W = 600, H = 200
const PAD_L = 44, PAD_R = 52, PAD_T = 12, PAD_B = 28

const METRICAS = [
  { key: 'temperatura', label: 'Temperatura', unit: '°C',  color: '#e65100', optimo: [20, 28] },
  { key: 'humedad',     label: 'Humedad',     unit: '%',   color: '#00695c', optimo: [50, 70] },
  { key: 'ph',          label: 'pH',          unit: '',    color: '#1b5e20', optimo: [5.8, 6.8] },
  { key: 'ec',          label: 'EC',          unit: ' mS', color: '#1565c0', optimo: [1.2, 2.0] },
]

const loading       = ref(true)
const datos         = ref([])
const metricaActiva = ref('temperatura')
const tooltip       = ref(null)

const metrica = computed(() => METRICAS.find(m => m.key === metricaActiva.value))

function toNum(v) {
  if (v === null || v === undefined || v === '') return null
  const n = parseFloat(v)
  return isNaN(n) ? null : n
}

const datosOrdenados = computed(() =>
  [...datos.value].sort((a, b) => new Date(a.registrado_en) - new Date(b.registrado_en))
)

const registrosConValor = computed(() =>
  datosOrdenados.value
    .map(r => ({ ...r, _valor: toNum(r[metricaActiva.value]) }))
    .filter(r => r._valor !== null)
)

const valoresValidos = computed(() => registrosConValor.value.map(r => r._valor))

const yMin = computed(() => {
  if (!valoresValidos.value.length) return 0
  const min = Math.min(...valoresValidos.value)
  const max = Math.max(...valoresValidos.value)
  const rango = (max - min) || 1
  return parseFloat((min - rango * 0.1).toFixed(1))
})
const yMax = computed(() => {
  if (!valoresValidos.value.length) return 10
  const min = Math.min(...valoresValidos.value)
  const max = Math.max(...valoresValidos.value)
  const rango = (max - min) || 1
  return parseFloat((max + rango * 0.1).toFixed(1))
})

function yScale(v) {
  const rango = (yMax.value - yMin.value) || 1
  return PAD_T + (H - PAD_T - PAD_B) * (1 - (v - yMin.value) / rango)
}
function xScale(i, total) {
  return PAD_L + (i / Math.max(total - 1, 1)) * (W - PAD_L - PAD_R)
}

const yTicks = computed(() => {
  const rango = yMax.value - yMin.value
  if (rango <= 0) return [yMin.value]
  const step = rango > 20 ? 10 : rango > 5 ? 2 : rango > 2 ? 1 : 0.5
  const ticks = []
  let v = Math.ceil(yMin.value / step) * step
  while (v <= yMax.value && ticks.length < 6) {
    ticks.push(parseFloat(v.toFixed(1)))
    v += step
  }
  return ticks
})

const puntos = computed(() => {
  const regs = registrosConValor.value
  const n = regs.length
  return regs.map((r, i) => ({
    x: xScale(i, n),
    y: yScale(r._valor),
    valor: parseFloat(r._valor.toFixed(2)),
    fecha: new Date(r.registrado_en).toLocaleDateString('es-AR', {
      day: '2-digit', month: '2-digit', year: '2-digit',
      hour: '2-digit', minute: '2-digit'
    })
  }))
})

const xLabels = computed(() => {
  const pts = puntos.value
  const n = pts.length
  if (!n) return []
  if (n === 1) return [{ x: pts[0].x, label: pts[0].fecha.split(',')[0] }]
  const step = Math.max(1, Math.floor(n / 5))
  const result = []
  for (let i = 0; i < n; i++) {
    if (i === 0 || i === n - 1 || i % step === 0) {
      result.push({ x: pts[i].x, label: pts[i].fecha.split(',')[0] })
    }
  }
  return result
})

const linePath = computed(() => {
  const pts = puntos.value
  if (!pts.length) return ''
  return pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.y}`).join(' ')
})

const areaPath = computed(() => {
  const pts = puntos.value
  if (!pts.length) return ''
  const base = H - PAD_B
  const line = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x} ${p.y}`).join(' ')
  return `${line} L ${pts[pts.length-1].x} ${base} L ${pts[0].x} ${base} Z`
})

const stats = computed(() => {
  const vs = valoresValidos.value
  if (!vs.length) return { ultimo: '—', promedio: '—', min: '—', max: '—' }
  const ultimo = vs[vs.length - 1]
  const promedio = vs.reduce((a, b) => a + b, 0) / vs.length
  return {
    ultimo:   parseFloat(ultimo.toFixed(2)),
    promedio: parseFloat(promedio.toFixed(2)),
    min:      parseFloat(Math.min(...vs).toFixed(2)),
    max:      parseFloat(Math.max(...vs).toFixed(2)),
  }
})

function ultimoValor(key) {
  const vs = datosOrdenados.value
    .map(r => toNum(r[key]))
    .filter(v => v !== null)
  if (!vs.length) return null
  return parseFloat(vs[vs.length - 1].toFixed(2))
}

function onMouseMove(e) {
  const svg = e.currentTarget
  const rect = svg.getBoundingClientRect()
  const scaleX = W / rect.width
  const svgX = (e.clientX - rect.left) * scaleX

  const pts = puntos.value
  if (!pts.length) return

  let closest = pts[0]
  let minDist = Math.abs(pts[0].x - svgX)
  for (const p of pts) {
    const d = Math.abs(p.x - svgX)
    if (d < minDist) { minDist = d; closest = p }
  }

  const rawX = (closest.x / W) * rect.width + 8
  const rawY = (closest.y / H) * rect.height - 44
  tooltip.value = {
    x:       closest.x,
    y:       closest.y,
    valor:   closest.valor,
    fecha:   closest.fecha,
    screenX: Math.min(rawX, rect.width - 110),
    screenY: Math.max(4, rawY),
  }
}

onMounted(async () => {
  try {
    const { data } = await getRegistrosAmbientales(props.loteId)
    datos.value = Array.isArray(data) ? data : []
  } catch {
    datos.value = []
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.gl { width: 100%; }

.gl__tabs {
  display: flex; gap: .4rem;
  margin-bottom: .75rem; flex-wrap: wrap;
}
.gl__tab {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .35rem .75rem;
  border: 1.5px solid #d4e6d4;
  border-radius: 999px;
  background: #f4f8f4;
  font-size: .75rem; font-weight: 600;
  cursor: pointer; color: #60725d;
  transition: all .15s;
}
.gl__tab:hover { border-color: #1b5e20; color: #1b5e20; }
.gl__tab--active { background: #fff; }
.gl__tab-dot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
.gl__tab-val {
  font-size: .7rem; font-weight: 700;
  background: rgba(0,0,0,.06);
  padding: .1em .45em; border-radius: 4px;
}

.gl__loading {
  display: flex; align-items: center; justify-content: center;
  height: 140px;
}
.gl__empty {
  display: flex; align-items: center; gap: .75rem;
  justify-content: center; padding: 2rem;
  font-size: .85rem; color: var(--c-slate-400);
  background: #f9fdf9;
  border: 1px dashed #d4e6d4;
  border-radius: 10px;
}
.gl__empty p { margin: 0; }

.gl__chart-wrap {
  position: relative;
  background: #f9fdf9;
  border: 1px solid #e8f0e9;
  border-radius: 10px;
  padding: .75rem;
  overflow: hidden;
}

.gl__svg {
  width: 100%; display: block;
  color: #60725d; overflow: visible;
}

.gl__axis-label {
  font-size: 9px; fill: var(--c-slate-400);
  font-family: system-ui, sans-serif;
}
.gl__range-label {
  font-size: 9px;
  font-family: system-ui, sans-serif;
  opacity: .7;
}

.gl__tooltip {
  position: absolute;
  background: #fff;
  border: 1px solid #e8f0e9;
  border-radius: 8px;
  padding: .4rem .7rem;
  pointer-events: none;
  box-shadow: 0 4px 14px rgba(0,0,0,.1);
  white-space: nowrap;
  z-index: 10;
}
.gl__tooltip-fecha { font-size: .7rem; color: var(--c-slate-400); }
.gl__tooltip-val   { font-size: .9rem; font-weight: 700; margin-top: .1rem; }

.gl__stats {
  display: flex; gap: 1rem;
  margin-top: .75rem; padding-top: .75rem;
  border-top: 1px solid #e8f0e9;
  flex-wrap: wrap;
}
.gl__stat { display: flex; flex-direction: column; gap: .1rem; }
.gl__stat-label {
  font-size: .65rem; color: var(--c-slate-400);
  font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em;
}
.gl__stat-val {
  font-size: .9rem; font-weight: 700; color: #1a1a1a;
}
</style>
