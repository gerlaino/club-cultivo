<template>
  <div class="msv">
    <div class="msv__header">
      <h1 class="msv__title">Sedes</h1>
    </div>

    <div v-if="loading" class="msv__loading">
      <i class="bi bi-arrow-repeat msv__spin"></i> Cargando…
    </div>
    <div v-else-if="!sedes.length" class="msv__empty">
      <i class="bi bi-building msv__empty-icon"></i>
      <p>Sin sedes asignadas</p>
    </div>

    <div v-else class="msv__list">
      <RouterLink
        v-for="sede in sedes"
        :key="sede.id"
        :to="`/m/sede/${sede.id}`"
        class="msv__card"
      >
        <div class="msv__card-icon">🏢</div>
        <div class="msv__card-info">
          <div class="msv__card-nombre">{{ sede.nombre }}</div>
          <div class="msv__card-meta">
            <span>{{ sede.tipo_label || sede.tipo }}</span>
            <span v-if="sede.salas_count" class="msv__dot">·</span>
            <span v-if="sede.salas_count">{{ sede.salas_count }} salas</span>
          </div>
        </div>
        <i class="bi bi-chevron-right msv__chevron"></i>
      </RouterLink>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listSedes } from '../../lib/api'

const sedes   = ref([])
const loading = ref(false)

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await listSedes()
    sedes.value = data || []
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.msv { padding: 0 0 1.5rem; }
.msv__header { padding: 1rem 1rem .75rem; }
.msv__title  { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0; }
.msv__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: #94a3b8; font-size: .875rem; }
.msv__spin { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.msv__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: #94a3b8; font-size: .875rem; }
.msv__empty-icon { font-size: 2.5rem; }
.msv__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.msv__card { display: flex; align-items: center; gap: .875rem; background: #fff; border-radius: 14px; padding: 1rem; text-decoration: none; box-shadow: 0 1px 4px rgba(0,0,0,.07); -webkit-tap-highlight-color: transparent; }
.msv__card-icon { font-size: 1.75rem; flex-shrink: 0; }
.msv__card-info { flex: 1; min-width: 0; }
.msv__card-nombre { font-size: .95rem; font-weight: 700; color: #0f172a; }
.msv__card-meta { font-size: .72rem; color: #64748b; display: flex; align-items: center; gap: .3rem; margin-top: .15rem; }
.msv__dot { color: #d1d5db; }
.msv__chevron { color: #d1d5db; font-size: .8rem; flex-shrink: 0; }
</style>
