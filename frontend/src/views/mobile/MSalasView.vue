<template>
  <div class="ms">
    <div class="ms__header">
      <h1 class="ms__title">Salas</h1>
      <button v-if="canCreate" class="ms__add-btn" @click="showCrear = true">
        <i class="bi bi-plus-lg"></i>
      </button>
    </div>

    <div v-if="loading" class="ms__loading">
      <i class="bi bi-arrow-repeat ms__spin"></i> Cargando…
    </div>

    <div v-else-if="!salas.length" class="ms__empty">
      <i class="bi bi-grid-3x3-gap ms__empty-icon"></i>
      <p>Sin salas asignadas</p>
    </div>

    <div v-else class="ms__list">
      <RouterLink
        v-for="sala in salas"
        :key="sala.id"
        :to="`/m/sala/${sala.id}`"
        class="ms__card"
      >
        <span class="ms__card-left" :style="{ background: kindColor(sala.kind) }">
          {{ kindEmoji(sala.kind) }}
        </span>
        <div class="ms__card-info">
          <div class="ms__card-nombre">{{ sala.nombre }}</div>
          <div class="ms__card-meta">
            <span>{{ kindLabel(sala.kind) }}</span>
            <span class="ms__dot">·</span>
            <span>{{ lotesActivosEnSala(sala.id) }} lotes activos</span>
          </div>
        </div>
        <span class="ms__estado" :class="`ms__estado--${sala.state}`"></span>
        <i class="bi bi-chevron-right ms__chevron"></i>
      </RouterLink>
    </div>

    <Teleport to="body">
      <div v-modal="() => showCrear = false" v-if="showCrear" class="ms__overlay" @click.self="showCrear = false">
        <div class="ms__sheet">
          <ModalCrearSala @created="onCreado" @close="showCrear = false" />
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listSalas } from '../../lib/api'
import { useLotesStore } from '../../stores/lotes'
import { useAuthStore }  from '../../stores/auth'
import ModalCrearSala    from '../../components/salas/ModalCrearSala.vue'

const auth    = useAuthStore()
const lotesStore = useLotesStore()

const salas      = ref([])
const loading    = ref(false)
const showCrear  = ref(false)
const canCreate  = computed(() => ['admin', 'supervisor'].includes(auth.role))

function lotesActivosEnSala(id) {
  return lotesStore.items.filter(l => l.sala_id === id && l.estado !== 'finalizado').length
}

const KIND_COLOR = { vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', manicura:'#d97706' }
const KIND_EMOJI = { vegetativo:'🍃', floracion:'🌸', cosecha:'🌾', manicura:'✂️' }
const KIND_LABEL = { vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', manicura:'Manicura' }
const kindColor = k => KIND_COLOR[k] || '#64748b'
const kindEmoji = k => KIND_EMOJI[k] || '🏠'
const kindLabel = k => KIND_LABEL[k] || k || '—'

function onCreado() { showCrear.value = false; load() }

async function load() {
  loading.value = true
  try {
    const { data } = await listSalas()
    salas.value = data || []
  } catch {} finally { loading.value = false }
}

onMounted(async () => {
  await Promise.all([load(), lotesStore.fetch()])
})
</script>

<style scoped>
.ms { padding: 0 0 1.5rem; }
.ms__header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1rem .75rem; }
.ms__title  { font-size: 1.15rem; font-weight: 800; color: var(--c-slate-900); margin: 0; }
.ms__add-btn { width: 36px; height: 36px; border-radius: 10px; background: #1b5e20; color: #fff; border: none; font-size: 1rem; display: flex; align-items: center; justify-content: center; cursor: pointer; }

.ms__loading { display: flex; align-items: center; gap: .5rem; justify-content: center; padding: 2.5rem; color: var(--c-slate-400); font-size: .875rem; }
.ms__spin { animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.ms__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: var(--c-slate-400); font-size: .875rem; }
.ms__empty-icon { font-size: 2.5rem; }

.ms__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }

.ms__card { display: flex; align-items: center; gap: .875rem; background: #fff; border-radius: 14px; padding: .875rem; text-decoration: none; box-shadow: 0 1px 4px rgba(0,0,0,.07); -webkit-tap-highlight-color: transparent; }
.ms__card-left { width: 42px; height: 42px; border-radius: 11px; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; flex-shrink: 0; opacity: .85; }
.ms__card-info { flex: 1; min-width: 0; }
.ms__card-nombre { font-size: .95rem; font-weight: 700; color: var(--c-slate-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ms__card-meta { font-size: .72rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .3rem; margin-top: .15rem; }
.ms__dot { color: #d1d5db; }
.ms__estado { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.ms__estado--activa { background: #22c55e; }
.ms__estado--mantenimiento { background: #f59e0b; }
.ms__estado--cerrada { background: var(--c-slate-400); }
.ms__chevron { color: #d1d5db; font-size: .8rem; flex-shrink: 0; }

.ms__overlay { position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,.5); display: flex; align-items: flex-end; }
.ms__sheet { width: 100%; max-height: 90vh; overflow-y: auto; border-radius: 20px 20px 0 0; }
</style>
