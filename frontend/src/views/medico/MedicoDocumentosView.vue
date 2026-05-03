<template>
  <div class="mdd">
    <div class="mdd__header">
      <h1 class="mdd__title"><FolderOpen :size="20" :stroke-width="1.75" /> Documentos clínicos</h1>
    </div>

    <div v-if="loading" class="mdd__loading">Cargando…</div>

    <template v-else>
      <div v-if="!documentos.length" class="mdd__empty">Sin documentos clínicos cargados.</div>
      <table v-else class="mdd__table">
        <thead>
          <tr><th>Tipo</th><th>Paciente</th><th>Fecha</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-for="d in documentos" :key="d.id">
            <td><span class="mdd__badge">{{ d.tipo }}</span></td>
            <td>{{ d.paciente?.nombre }} {{ d.paciente?.apellido }}</td>
            <td>{{ formatDate(d.fecha_vencimiento) }}</td>
            <td>
              <button class="mdd__dl" @click="descargar(d.id)" :disabled="!d.tiene_archivo">
                <Download :size="14" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { FolderOpen, Download } from 'lucide-vue-next'
import api from '../../lib/api.js'

const loading    = ref(false)
const documentos = ref([])

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/documentos')
    documentos.value = res.data
  } finally {
    loading.value = false
  }
}

async function descargar(id) {
  const res = await api.get(`/documentos/${id}/descargar`, { responseType: 'blob' })
  const url = URL.createObjectURL(res.data)
  const a   = document.createElement('a')
  a.href = url; a.download = `documento_${id}`; a.click()
  URL.revokeObjectURL(url)
}

const formatDate = (d) => d ? new Date(d).toLocaleDateString('es-AR') : '—'

onMounted(cargar)
</script>

<style scoped>
.mdd { padding: var(--sp-6); max-width: 800px; }
.mdd__header { margin-bottom: var(--sp-5); }
.mdd__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.mdd__loading, .mdd__empty { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; font-size: var(--fs-14); }
.mdd__table { width: 100%; border-collapse: collapse; font-size: var(--fs-14); }
.mdd__table th { text-align: left; padding: var(--sp-2) var(--sp-3); background: var(--c-ink-50); font-weight: 600; color: var(--c-ink-600); border-bottom: 1px solid var(--c-ink-100); }
.mdd__table td { padding: var(--sp-2) var(--sp-3); border-bottom: 1px solid var(--c-ink-50); color: var(--c-ink-800); }
.mdd__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: rgba(45,138,107,.1); color: #2D8A6B; }
.mdd__dl { background: none; border: 1px solid var(--c-ink-200); border-radius: var(--r-sm); padding: 4px 6px; cursor: pointer; color: var(--c-ink-600); display: flex; align-items: center; }
.mdd__dl:disabled { opacity: .35; cursor: default; }
.mdd__dl:not(:disabled):hover { background: var(--c-ink-50); }
</style>
