<template>
  <div class="chart-container">
    <canvas ref="chartCanvas"></canvas>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import {
  Chart,
  ArcElement,
  Tooltip,
  Legend,
  DoughnutController
} from 'chart.js'

Chart.register(ArcElement, Tooltip, Legend, DoughnutController)

const props = defineProps({
  data: {
    type: Object,
    required: true
  }
})

const chartCanvas = ref(null)
let chartInstance = null

const createChart = () => {
  if (!chartCanvas.value) return

  const ctx = chartCanvas.value.getContext('2d')

  // Destruir chart anterior si existe
  if (chartInstance) {
    chartInstance.destroy()
  }

  const labels = []
  const values = []
  const colors = []

  if (props.data.vegetativo > 0) {
    labels.push('Vegetativo')
    values.push(props.data.vegetativo)
    colors.push('#198754')
  }
  if (props.data.floracion > 0) {
    labels.push('Floración')
    values.push(props.data.floracion)
    colors.push('#ffc107')
  }
  if (props.data.secado > 0) {
    labels.push('Secado')
    values.push(props.data.secado)
    colors.push('#17a2b8')
  }

  // Si no hay datos, mostrar placeholder
  if (values.length === 0) {
    labels.push('Sin plantas')
    values.push(1)
    colors.push('#dee2e6')
  }

  chartInstance = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: labels,
      datasets: [{
        data: values,
        backgroundColor: colors,
        borderWidth: 0
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          position: 'bottom',
          labels: {
            padding: 15,
            font: {
              size: 12
            },
            usePointStyle: true
          }
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              const label = context.label || ''
              const value = context.parsed || 0
              const total = context.dataset.data.reduce((a, b) => a + b, 0)
              const percentage = ((value / total) * 100).toFixed(1)
              return `${label}: ${value} (${percentage}%)`
            }
          }
        }
      }
    }
  })
}

onMounted(() => {
  createChart()
})

watch(() => props.data, () => {
  createChart()
}, { deep: true })
</script>

<style scoped>
.chart-container {
  position: relative;
  height: 250px;
}
</style>
