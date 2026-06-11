<template>
  <div class="msd">
    <div v-if="loading" class="msd__loading"><i class="bi bi-arrow-repeat msd__spin"></i></div>
    <template v-else-if="sede">
      <div class="msd__header">
        <h1 class="msd__title">{{ sede.nombre }}</h1>
        <span class="msd__tipo">{{ sede.tipo }}</span>
      </div>

      <div v-if="!salas.length" class="msd__empty">
        <i class="bi bi-grid-3x3-gap msd__empty-icon"></i>
        <p>Sin salas en esta sede</p>
      </div>

      <div v-else class="msd__list">
        <RouterLink
          v-for="sala in salas"
          :key="sala.id"
          :to="`/m/sala-m/${sala.id}`"
          class="msd__card"
        >
          <span class="msd__card-left" :style="{ background: kindColor(sala.kind) }">
            {{ kindEmoji(sala.kind) }}
          </span>
          <div class="msd__card-info">
            <div class="msd__card-nombre">{{ sala.nombre }}</div>
            <div class="msd__card-meta">
              <span>{{ kindLabel(sala.kind) }}</span>
              <span v-if="sala.lotes_activos_count" class="msd__dot">·</span>
              <span v-if="sala.lotes_activos_count">{{ sala.lotes_activos_count }} lotes</span>
            </div>
          </div>
          <span class="msd__estado" :class="`msd__estado--${sala.state}`"></span>
          <i class="bi bi-chevron-right msd__chevron"></i>
        </RouterLink>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getSede, listSalas } from '../../lib/api'

const route = useRoute()
const id    = Number(route.params.id)

const sede    = ref(null)
const salas   = ref([])
const loading = ref(true)

const KIND_COLOR = { vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', cosechado:'#dc2626', manicura:'#d97706', secado:'#b45309', curado:'#2563eb', madre:'#0891b2', mixta:'#6b7280' }
const KIND_EMOJI = { vegetativo:'🍃', floracion:'🌸', cosecha:'🌾', cosechado:'🌾', manicura:'✂️', secado:'🍂', curado:'💊', madre:'🌱', mixta:'🏠' }
const KIND_LABEL = { vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', cosechado:'Cosecha', manicura:'Manicura', secado:'Secado', curado:'Curado', madre:'Madres', mixta:'Mixta' }
const kindColor = k => KIND_COLOR[k] || '#64748b'
const kindEmoji = k => KIND_EMOJI[k] || '🏠'
const kindLabel = k => KIND_LABEL[k] || k || '—'

onMounted(async () => {
  try {
    const [sedeRes, salasRes] = await Promise.allSettled([getSede(id), listSalas()])
    if (sedeRes.status === 'fulfilled') sede.value = sedeRes.value.data
    if (salasRes.status === 'fulfilled')
      salas.value = (salasRes.value.data || []).filter(s => s.sede_id === id || s.sede?.id === id)
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.msd { padding: 0 0 1.5rem; }
.msd__loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.msd__spin { font-size: 2rem; color: #94a3b8; animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.msd__header { padding: 1rem 1rem .75rem; display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.msd__title  { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin: 0; }
.msd__tipo   { font-size: .7rem; font-weight: 700; color: #64748b; background: #f1f5f9; padding: .2em .6em; border-radius: 6px; text-transform: capitalize; }
.msd__empty  { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: #94a3b8; font-size: .875rem; }
.msd__empty-icon { font-size: 2.5rem; }
.msd__list  { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }
.msd__card  { display: flex; align-items: center; gap: .875rem; background: #fff; border-radius: 14px; padding: .875rem; text-decoration: none; box-shadow: 0 1px 4px rgba(0,0,0,.07); -webkit-tap-highlight-color: transparent; }
.msd__card-left { width: 40px; height: 40px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; flex-shrink: 0; opacity: .85; }
.msd__card-info { flex: 1; min-width: 0; }
.msd__card-nombre { font-size: .92rem; font-weight: 700; color: #0f172a; }
.msd__card-meta   { font-size: .72rem; color: #64748b; display: flex; gap: .3rem; margin-top: .15rem; }
.msd__dot { color: #d1d5db; }
.msd__estado { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.msd__estado--activa { background: #22c55e; }
.msd__estado--mantenimiento { background: #f59e0b; }
.msd__estado--cerrada { background: #94a3b8; }
.msd__chevron { color: #d1d5db; font-size: .8rem; flex-shrink: 0; }
</style>
