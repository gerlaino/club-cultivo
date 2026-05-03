<script setup>
import { ref, watch, onMounted, onUnmounted, computed } from 'vue'
import Chart from 'chart.js/auto'

const props = defineProps({
  lecturas: { type: Array, default: () => [] },
  tipo:     { type: String, default: 'temperatura' },
  bucket:   { type: String, default: 'raw' },       // 'raw' | 'daily'
  setpoint: { type: Object, default: null },         // { valor_min, valor_max, valor_ideal, unidad }
  height:   { type: Number, default: 220 },
})

const canvas = ref(null)
let chart = null

const COLORES = {
  temperatura:          '#ef4444',
  humedad:              '#3b82f6',
  vpd:                  '#8b5cf6',
  co2:                  '#10b981',
  ppfd:                 '#f59e0b',
  ec:                   '#6366f1',
  ph:                   '#14b8a6',
  ph_runoff:            '#0ea5e9',
  ec_runoff:            '#a855f7',
  temperatura_sustrato: '#f97316',
}

function buildDatasets(lecturas, tipo, bucket, setpoint) {
  const color  = COLORES[tipo] || '#64748b'
  const points = lecturas
    .filter(l => l.tipo === tipo)
    .sort((a, b) => new Date(a.medido_at || a.fecha) - new Date(b.medido_at || b.fecha))
    .map(l => ({
      x: new Date(l.medido_at || l.fecha),
      y: typeof l.valor === 'number' ? l.valor : parseFloat(l.valor),
    }))
    .filter(p => !isNaN(p.y))

  const datasets = [{
    label: tipo,
    data:  points,
    borderColor:           color,
    backgroundColor:       color + '18',
    borderWidth:           2,
    pointRadius:           bucket === 'daily' ? 4 : 2,
    pointHoverRadius:      5,
    tension:               0.35,
    fill:                  false,
  }]

  if (setpoint) {
    if (setpoint.valor_ideal != null) {
      datasets.push({
        label:        'Ideal',
        data:         points.map(p => ({ x: p.x, y: setpoint.valor_ideal })),
        borderColor:  '#22c55e',
        borderWidth:  1.5,
        borderDash:   [6, 4],
        pointRadius:  0,
        fill:         false,
      })
    }
    if (setpoint.valor_min != null && setpoint.valor_max != null) {
      datasets.push({
        label:           'Rango',
        data:            points.map(p => ({ x: p.x, y: setpoint.valor_max })),
        borderColor:     '#fbbf24',
        borderWidth:     1,
        borderDash:      [3, 3],
        pointRadius:     0,
        fill:            '+1',
        backgroundColor: '#fbbf2410',
      })
      datasets.push({
        label:        '_min',
        data:         points.map(p => ({ x: p.x, y: setpoint.valor_min })),
        borderColor:  '#fbbf24',
        borderWidth:  1,
        borderDash:   [3, 3],
        pointRadius:  0,
        fill:         false,
      })
    }
  }

  return datasets
}

function destroyChart() {
  if (chart) { chart.destroy(); chart = null }
}

function buildChart() {
  destroyChart()
  if (!canvas.value) return

  const datasets = buildDatasets(props.lecturas, props.tipo, props.bucket, props.setpoint)
  if (!datasets[0].data.length) return

  chart = new Chart(canvas.value, {
    type: 'line',
    data: { datasets },
    options: {
      responsive:          true,
      maintainAspectRatio: false,
      interaction:         { mode: 'index', intersect: false },
      plugins: {
        legend: {
          display: false,
        },
        tooltip: {
          callbacks: {
            label: ctx => {
              if (ctx.dataset.label?.startsWith('_')) return null
              const unit = props.setpoint?.unidad || ''
              return ` ${ctx.dataset.label}: ${ctx.parsed.y?.toFixed(2)} ${unit}`
            },
          },
          filter: item => !item.dataset.label?.startsWith('_'),
        },
      },
      scales: {
        x: {
          type:    'time',
          time:    {
            unit:         props.bucket === 'daily' ? 'day' : 'hour',
            tooltipFormat: props.bucket === 'daily' ? 'dd/MM/yyyy' : 'dd/MM HH:mm',
            displayFormats: { hour: 'HH:mm', day: 'dd/MM' },
          },
          grid:    { color: '#f0fdf4' },
          ticks:   { color: '#94a3b8', font: { size: 10 } },
        },
        y: {
          grid:    { color: '#f0fdf4' },
          ticks:   { color: '#94a3b8', font: { size: 10 } },
        },
      },
    },
  })
}

watch([() => props.lecturas, () => props.tipo, () => props.bucket, () => props.setpoint],
  buildChart, { deep: true })

onMounted(buildChart)
onUnmounted(destroyChart)
</script>

<template>
  <div class="ac" :style="{ height: height + 'px' }">
    <canvas v-show="lecturas.filter(l => l.tipo === tipo).length > 0" ref="canvas" />
    <div v-if="lecturas.filter(l => l.tipo === tipo).length === 0" class="ac__empty">
      Sin datos para {{ tipo }}
    </div>
  </div>
</template>

<style scoped>
.ac { position: relative; width: 100%; }
.ac__empty {
  display: flex; align-items: center; justify-content: center;
  height: 100%; color: #94a3b8; font-size: .82rem;
}
</style>
