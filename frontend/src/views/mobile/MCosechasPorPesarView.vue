<template>
  <div class="mcp">
    <div class="mcp__header">
      <h1 class="mcp__title">Por pesar</h1>
    </div>

    <div v-if="loading" class="mcp__loading"><i class="bi bi-arrow-repeat mcp__spin"></i> Cargando…</div>
    <div v-else-if="!cosechas.length" class="mcp__empty">
      <i class="bi bi-scissors mcp__empty-icon"></i>
      <p>Sin cosechas pendientes de pesaje</p>
    </div>

    <div v-else class="mcp__list">
      <RouterLink
        v-for="lote in cosechas"
        :key="lote.id"
        :to="`/m/mnc/lotes/${lote.id}`"
        class="mcp__card"
      >
        <div class="mcp__card-left">
          <span class="mcp__estado-emoji">{{ lote.estado === 'secado' ? '💨' : '✂️' }}</span>
        </div>
        <div class="mcp__card-body">
          <div class="mcp__card-top">
            <span class="mcp__codigo">{{ lote.codigo }}</span>
            <span class="mcp__badge" :class="`mcp__badge--${lote.estado}`">{{ estadoLabel(lote.estado) }}</span>
          </div>
          <div class="mcp__card-meta">
            <span>{{ lote.genetica?.nombre || '—' }}</span>
            <span class="mcp__dot">·</span>
            <span>{{ lote.plants_count }} plantas</span>
            <template v-if="lote.sala?.nombre">
              <span class="mcp__dot">·</span>
              <span>{{ lote.sala.nombre }}</span>
            </template>
          </div>
          <div v-if="lote.pesadas_pendientes" class="mcp__hint">
            {{ lote.plants_count - (lote.pesadas_pendientes || 0) }} pesadas · faltan {{ lote.pesadas_pendientes }}
          </div>
        </div>
        <i class="bi bi-chevron-right mcp__chevron"></i>
      </RouterLink>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listLotes } from '../../lib/api'

const cosechas = ref([])
const loading  = ref(false)

const EL = { en_manicura: 'Manicura activa' }
const estadoLabel = e => EL[e] || e

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await listLotes()
    cosechas.value = (data || []).filter(l => ['en_manicura'].includes(l.estado))
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.mcp { padding: 0 0 1.5rem; }
.mcp__header { padding: 1rem 1rem .75rem; }
.mcp__title { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.mcp__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.mcp__spin { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.mcp__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: var(--c-slate-400); font-size: .875rem; }
.mcp__empty-icon { font-size: 2.5rem; }
.mcp__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.mcp__card { display: flex; align-items: center; gap: .75rem; background: #fff; border-radius: 14px; padding: .875rem; box-shadow: 0 1px 4px rgba(0,0,0,.07); text-decoration: none; -webkit-tap-highlight-color: transparent; }
.mcp__card-left { flex-shrink: 0; }
.mcp__estado-emoji { font-size: 1.5rem; }
.mcp__card-body { flex: 1; min-width: 0; }
.mcp__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .25rem; }
.mcp__codigo { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); font-family: monospace; }
.mcp__badge { font-size: .62rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; }
.mcp__badge--en_manicura { background: #fef3c7; color: #b45309; }
.mcp__badge--secado { background: #e0f2fe; color: #0369a1; }
.mcp__card-meta { font-size: .72rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .3rem; flex-wrap: wrap; }
.mcp__dot { color: #d1d5db; }
.mcp__hint { font-size: .68rem; color: var(--c-leaf-700); font-weight: 600; margin-top: .2rem; }
.mcp__chevron { color: #d1d5db; font-size: .8rem; flex-shrink: 0; }
</style>
