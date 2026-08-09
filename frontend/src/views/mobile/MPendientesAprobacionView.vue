<template>
  <div class="mpa">
    <div class="mpa__header">
      <h1 class="mpa__title">Pendientes de aprobación</h1>
    </div>

    <div v-if="loading" class="mpa__loading"><i class="bi bi-arrow-repeat mpa__spin"></i> Cargando…</div>

    <div v-else-if="!pendientes.length" class="mpa__empty">
      <i class="bi bi-check2-circle mpa__empty-icon"></i>
      <p>Sin cosechas pendientes de aprobación</p>
      <span class="mpa__empty-sub">Cuando el admin apruebe una cosecha, desaparecerá de acá</span>
    </div>

    <div v-else class="mpa__list">
      <div v-for="lote in pendientes" :key="lote.id" class="mpa__card">
        <div class="mpa__card-icon">⏳</div>
        <div class="mpa__card-body">
          <div class="mpa__card-top">
            <span class="mpa__codigo">{{ lote.codigo }}</span>
            <span class="mpa__badge">Pendiente</span>
          </div>
          <div class="mpa__card-meta">
            <span>{{ lote.genetica?.nombre || '—' }}</span>
            <span class="mpa__dot">·</span>
            <span>{{ lote.plants_count }} plantas</span>
          </div>
          <div v-if="lote.manicurador" class="mpa__manicurador">
            Registrado por {{ lote.manicurador.nombre }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listLotes } from '../../lib/api'

const pendientes = ref([])
const loading    = ref(false)

onMounted(async () => {
  loading.value = true
  try {
    // Lotes con un pesaje enviado, esperando confirmación del admin.
    const { data } = await listLotes({ pesaje_enviado: true })
    pendientes.value = data || []
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.mpa { padding: 0 0 1.5rem; }
.mpa__header { padding: 1rem 1rem .75rem; }
.mpa__title { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mpa__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.mpa__spin { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.mpa__empty { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 3rem 1rem; color: var(--c-slate-400); font-size: .875rem; text-align: center; }
.mpa__empty-icon { font-size: 2.5rem; color: #22c55e; }
.mpa__empty-sub { font-size: .75rem; color: var(--c-slate-400); }
.mpa__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.mpa__card { display: flex; align-items: center; gap: .75rem; background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 14px; padding: .875rem; }
.mpa__card-icon { font-size: 1.5rem; flex-shrink: 0; }
.mpa__card-body { flex: 1; min-width: 0; }
.mpa__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .25rem; }
.mpa__codigo { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); font-family: monospace; }
.mpa__badge { font-size: .62rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; background: #fef3c7; color: #b45309; }
.mpa__card-meta { font-size: .72rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .3rem; }
.mpa__dot { color: #d1d5db; }
.mpa__manicurador { font-size: .7rem; color: #b45309; margin-top: .2rem; font-weight: 600; }
</style>
