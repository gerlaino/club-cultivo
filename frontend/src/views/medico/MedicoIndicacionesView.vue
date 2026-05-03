<template>
  <div class="mdi">
    <div class="mdi__header">
      <h1 class="mdi__title"><FileHeart :size="20" :stroke-width="1.75" /> Indicaciones médicas</h1>
    </div>

    <div v-if="loading" class="mdi__loading">Cargando…</div>

    <template v-else>
      <div v-if="!indicaciones.length" class="mdi__empty">Sin indicaciones registradas.</div>
      <table v-else class="mdi__table">
        <thead>
          <tr><th>Paciente</th><th>Patología</th><th>Dosificación</th><th>Vía</th><th>Vence</th></tr>
        </thead>
        <tbody>
          <tr v-for="ind in indicaciones" :key="ind.id">
            <td>{{ ind.paciente?.nombre_completo || '—' }}</td>
            <td>{{ ind.patologia }}</td>
            <td>{{ ind.dosificacion }}</td>
            <td>{{ ind.via_administracion }}</td>
            <td>{{ formatDate(ind.fecha_vencimiento) }}</td>
          </tr>
        </tbody>
      </table>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { FileHeart } from 'lucide-vue-next'
import api from '../../lib/api.js'

const loading     = ref(false)
const indicaciones = ref([])

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/indicaciones_medicas')
    indicaciones.value = res.data
  } finally {
    loading.value = false
  }
}

const formatDate = (d) => d ? new Date(d).toLocaleDateString('es-AR') : '—'

onMounted(cargar)
</script>

<style scoped>
.mdi { padding: var(--sp-6); max-width: 900px; }
.mdi__header { margin-bottom: var(--sp-5); }
.mdi__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.mdi__loading, .mdi__empty { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; font-size: var(--fs-14); }
.mdi__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.mdi__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.mdi__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
</style>
