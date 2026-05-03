<template>
  <div class="mpc">
    <div class="mpc__header">
      <h1 class="mpc__title"><Users :size="20" :stroke-width="1.75" /> Mis pacientes</h1>
    </div>

    <div v-if="loading" class="mpc__loading">Cargando…</div>

    <template v-else>
      <div v-if="!pacientes.length" class="mpc__empty">Sin pacientes con seguimiento médico asignados.</div>
      <div v-else class="mpc__lista">
        <div v-for="p in pacientes" :key="p.id" class="mpc__card">
          <div class="mpc__card-head">
            <span class="mpc__nombre">{{ p.nombre }} {{ p.apellido }}</span>
            <span class="mpc__badge" :class="estadoBadge(p.reprocann_estado)">{{ estadoLabel(p.reprocann_estado) }}</span>
          </div>
          <div class="mpc__card-meta">
            <span>DNI: {{ p.dni }}</span>
            <span v-if="p.reprocann_vencimiento">Vence: {{ formatDate(p.reprocann_vencimiento) }}</span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { Users } from 'lucide-vue-next'
import api from '../../lib/api.js'

const loading   = ref(false)
const pacientes = ref([])

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/pacientes')
    pacientes.value = res.data?.data ?? res.data ?? []
  } finally {
    loading.value = false
  }
}

const LABELS = { vigente: 'Vigente', vencido: 'Vencido', por_vencer: 'Por vencer', sin_reprocann: 'Sin REPROCANN' }
const estadoLabel = (e) => LABELS[e] || e
const estadoBadge = (e) => ({
  'mpc__badge--ok':   e === 'vigente',
  'mpc__badge--warn': e === 'por_vencer',
  'mpc__badge--err':  e === 'vencido',
})
const parseDate = (d) => d && typeof d === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
const formatDate = (d) => d ? parseDate(d).toLocaleDateString('es-AR') : '—'

onMounted(cargar)
</script>

<style scoped>
.mpc { padding: var(--sp-6); max-width: 700px; }
.mpc__header { margin-bottom: var(--sp-5); }
.mpc__title { font-size: var(--fs-20); font-weight: 700; color: var(--c-ink-900); display: flex; align-items: center; gap: var(--sp-2); margin: 0; }
.mpc__loading, .mpc__empty { color: var(--c-ink-500); padding: var(--sp-8); text-align: center; font-size: var(--fs-14); }
.mpc__lista { display: flex; flex-direction: column; gap: var(--sp-3); }
.mpc__card { background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg); padding: var(--sp-4); }
.mpc__card-head { display: flex; align-items: center; justify-content: space-between; gap: var(--sp-3); margin-bottom: var(--sp-1); }
.mpc__nombre { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); }
.mpc__card-meta { font-size: var(--fs-13); color: var(--c-ink-500); display: flex; gap: var(--sp-4); }
.mpc__badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600); }
.mpc__badge--ok   { background: rgba(45,138,107,.1); color: #2D8A6B; }
.mpc__badge--warn { background: rgba(184,92,0,.1); color: #B85C00; }
.mpc__badge--err  { background: rgba(180,40,40,.1); color: var(--c-rust-600); }
</style>
