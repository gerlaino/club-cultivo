<template>
  <div class="msv">
    <header class="msv__header">
      <h1 class="msv__title">Cultivo</h1>
      <p class="msv__sub">Sedes del club</p>
    </header>

    <div v-if="loading" class="msv__loading">
      <i class="bi bi-arrow-repeat msv__spin"></i> Cargando…
    </div>
    <div v-else-if="!sedes.length" class="msv__empty">
      <i class="bi bi-building msv__empty-icon"></i>
      <p>Sin sedes asignadas</p>
    </div>

    <div v-else class="msv__list">
      <RouterLink
        v-for="sede in sedes" :key="sede.id"
        :to="`/m/sede/${sede.id}`" class="msv__card"
      >
        <span class="msv__card-icon"><i class="bi bi-building"></i></span>
        <div class="msv__card-info">
          <div class="msv__card-nombre">{{ sede.nombre }}</div>
          <div class="msv__card-meta">
            <span class="msv__card-tipo">{{ sede.tipo_label || sede.tipo }}</span>
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
.msv__header { padding: 1.2rem 1.1rem .85rem; }
.msv__title  { font-family: var(--font-display, sans-serif); font-size: 1.45rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); margin: 0; line-height: 1.1; }
.msv__sub    { margin: .2rem 0 0; font-size: .8rem; color: var(--c-ink-500, #6b7280); }

.msv__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-ink-500, #6b7280); font-size: .875rem; }
.msv__spin { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.msv__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: var(--c-ink-500, #6b7280); font-size: .875rem; }
.msv__empty-icon { font-size: 2.5rem; color: var(--c-leaf-300, #a8c9b5); }

.msv__list { display: flex; flex-direction: column; gap: .55rem; padding: 0 1.1rem; }
.msv__card {
  display: flex; align-items: center; gap: .85rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: var(--r-xl, 14px);
  padding: .95rem; text-decoration: none;
  -webkit-tap-highlight-color: transparent; transition: transform .12s, box-shadow .15s, border-color .15s;
}
.msv__card:active { transform: scale(.985); }
.msv__card:hover { border-color: var(--c-leaf-300, #a8c9b5); box-shadow: var(--sh-2); }
.msv__card-icon {
  width: 44px; height: 44px; border-radius: 12px; flex-shrink: 0;
  background: var(--c-leaf-100, #e8f0eb); color: var(--c-leaf-700, #2d4a3e);
  display: flex; align-items: center; justify-content: center; font-size: 1.3rem;
}
.msv__card-info { flex: 1; min-width: 0; }
.msv__card-nombre { font-size: .95rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); }
.msv__card-meta { font-size: .72rem; color: var(--c-ink-500, #6b7280); display: flex; align-items: center; gap: .3rem; margin-top: .15rem; }
.msv__card-tipo { text-transform: capitalize; }
.msv__dot { color: var(--c-ink-300, #d1d5db); }
.msv__chevron { color: var(--c-ink-300, #d1d5db); font-size: .8rem; flex-shrink: 0; }
</style>
