<template>
  <div class="msd">
    <div v-if="loading" class="msd__loading"><i class="bi bi-arrow-repeat msd__spin"></i></div>
    <template v-else-if="sede">
      <header class="msd__header">
        <div class="msd__header-txt">
          <h1 class="msd__title">{{ sede.nombre }}</h1>
          <span class="msd__tipo">{{ sede.tipo }}</span>
        </div>
        <button class="msd__add" @click="showNuevaSala = true">
          <i class="bi bi-plus-lg"></i> Sala
        </button>
      </header>

      <div v-if="!salas.length" class="msd__empty">
        <i class="bi bi-grid-3x3-gap msd__empty-icon"></i>
        <p>Sin salas en esta sede</p>
        <button class="msd__empty-cta" @click="showNuevaSala = true"><i class="bi bi-plus-lg"></i> Crear primera sala</button>
      </div>

      <div v-else class="msd__list">
        <RouterLink
          v-for="sala in salas" :key="sala.id"
          :to="`/m/sala-m/${sala.id}`" class="msd__card"
        >
          <span class="msd__card-left" :style="{ background: kindColor(sala.kind) + '1f', color: kindColor(sala.kind) }">
            <i class="bi" :class="kindIcon(sala.kind)"></i>
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

    <ModalCrearSala v-if="showNuevaSala" :sede-id-fija="id" @close="showNuevaSala = false" @created="onSalaCreada" />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getSede, listSalas } from '../../lib/api'
import { useToast } from '../../composables/useToast.js'
import ModalCrearSala from '../../components/salas/ModalCrearSala.vue'

const route = useRoute()
const id    = Number(route.params.id)
const toast = useToast()

const sede    = ref(null)
const salas   = ref([])
const loading = ref(true)
const showNuevaSala = ref(false)

const KIND_COLOR = { vegetativo:'#16a34a', floracion:'#9333ea', cosecha:'#dc2626', cosechado:'#dc2626', manicura:'#d97706', curado:'#2563eb', madre:'#0891b2', mixta:'#6b7280' }
const KIND_ICON  = { vegetativo:'bi-flower1', floracion:'bi-flower2', cosecha:'bi-basket', cosechado:'bi-basket', manicura:'bi-scissors', curado:'bi-archive', madre:'bi-tree', mixta:'bi-grid' }
const KIND_LABEL = { vegetativo:'Vegetativo', floracion:'Floración', cosecha:'Cosecha', cosechado:'Cosecha', manicura:'Manicura', curado:'Curado', madre:'Madres', mixta:'Mixta' }
const kindColor = k => KIND_COLOR[k] || '#64748b'
const kindIcon  = k => KIND_ICON[k]  || 'bi-grid'
const kindLabel = k => KIND_LABEL[k] || k || '—'

async function cargar() {
  const [sedeRes, salasRes] = await Promise.allSettled([getSede(id), listSalas()])
  if (sedeRes.status === 'fulfilled') sede.value = sedeRes.value.data
  if (salasRes.status === 'fulfilled')
    salas.value = (salasRes.value.data || []).filter(s => s.sede_id === id || s.sede?.id === id)
}

onMounted(async () => {
  try { await cargar() } catch {} finally { loading.value = false }
})

async function onSalaCreada() {
  showNuevaSala.value = false
  toast.success('Sala creada ✓')
  await cargar()
}
</script>

<style scoped>
.msd { padding: 0 0 1.5rem; }
.msd__loading { display: flex; align-items: center; justify-content: center; min-height: 40vh; }
.msd__spin { font-size: 2rem; color: var(--c-leaf-300, #a8c9b5); animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.msd__header { padding: 1.1rem 1.1rem .8rem; display: flex; align-items: flex-start; justify-content: space-between; gap: .75rem; }
.msd__header-txt { min-width: 0; }
.msd__title  { font-family: var(--font-display, sans-serif); font-size: 1.3rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); margin: 0; line-height: 1.15; }
.msd__tipo   { display: inline-block; margin-top: .3rem; font-size: .68rem; font-weight: 700; color: var(--c-leaf-700, #2d4a3e); background: var(--c-leaf-100, #e8f0eb); padding: .2em .6em; border-radius: 6px; text-transform: capitalize; }
.msd__add {
  flex-shrink: 0; display: inline-flex; align-items: center; gap: .35rem;
  background: var(--c-leaf-800, #1a3d2e); color: #fff; border: none;
  padding: .5rem .8rem; border-radius: 11px; font-size: .82rem; font-weight: 600; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.msd__add:active { transform: scale(.95); }

.msd__empty  { display: flex; flex-direction: column; align-items: center; gap: .6rem; padding: 3rem 1rem; color: var(--c-ink-500, #6b7280); font-size: .875rem; }
.msd__empty-icon { font-size: 2.5rem; color: var(--c-leaf-300, #a8c9b5); }
.msd__empty-cta {
  margin-top: .4rem; display: inline-flex; align-items: center; gap: .4rem;
  background: var(--c-leaf-100, #e8f0eb); color: var(--c-leaf-700, #2d4a3e); border: none;
  padding: .6rem 1rem; border-radius: 11px; font-size: .85rem; font-weight: 600; cursor: pointer;
}

.msd__list  { display: flex; flex-direction: column; gap: .55rem; padding: 0 1.1rem; }
.msd__card  {
  display: flex; align-items: center; gap: .85rem;
  background: #fff; border: 1px solid var(--c-leaf-100, #e8f0eb); border-radius: var(--r-xl, 14px);
  padding: .85rem; text-decoration: none;
  -webkit-tap-highlight-color: transparent; transition: transform .12s, box-shadow .15s, border-color .15s;
}
.msd__card:active { transform: scale(.985); }
.msd__card:hover { border-color: var(--c-leaf-300, #a8c9b5); box-shadow: var(--sh-2); }
.msd__card-left { width: 42px; height: 42px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; flex-shrink: 0; }
.msd__card-info { flex: 1; min-width: 0; }
.msd__card-nombre { font-size: .92rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); }
.msd__card-meta   { font-size: .72rem; color: var(--c-ink-500, #6b7280); display: flex; gap: .3rem; margin-top: .15rem; }
.msd__dot { color: var(--c-ink-300, #d1d5db); }
.msd__estado { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.msd__estado--activa { background: #22c55e; }
.msd__estado--mantenimiento { background: #f59e0b; }
.msd__estado--cerrada { background: #94a3b8; }
.msd__chevron { color: var(--c-ink-300, #d1d5db); font-size: .8rem; flex-shrink: 0; }
</style>
