<template>
  <div class="msl">
    <div class="msl__topbar">
      <h1 class="msl__title">Salas</h1>
      <button v-if="canCreate" class="msl__fab" @click="showCreate = true">
        <i class="bi bi-plus-lg"></i>
      </button>
    </div>

    <div v-if="salasStore.loading" class="msl__loading">Cargando…</div>

    <div v-else-if="!salas.length" class="msl__empty">
      <i class="bi bi-grid-3x3-gap"></i>
      <p>Sin salas registradas</p>
    </div>

    <div v-else class="msl__list">
      <RouterLink
        v-for="sala in salas"
        :key="sala.id"
        :to="`/m/sala/${sala.id}`"
        class="msl__card"
      >
        <div class="msl__card-accent" :style="{ background: kindColor(sala.kind) }"></div>
        <div class="msl__card-body">
          <div class="msl__card-top">
            <span class="msl__kind-emoji">{{ kindEmoji(sala.kind) }}</span>
            <span class="msl__nombre">{{ sala.nombre }}</span>
            <span class="msl__estado-dot" :class="`msl__estado-dot--${sala.state}`"></span>
          </div>
          <div class="msl__card-meta">
            <span class="msl__meta-item">{{ kindLabel(sala.kind) }}</span>
            <span class="msl__meta-sep">·</span>
            <span class="msl__meta-item">{{ lotesEnSala(sala.id) }} lote{{ lotesEnSala(sala.id) !== 1 ? 's' : '' }}</span>
            <span v-if="sala.sede" class="msl__meta-sep">·</span>
            <span v-if="sala.sede" class="msl__meta-item msl__meta-sede">{{ sala.sede.nombre }}</span>
          </div>
        </div>
        <i class="bi bi-chevron-right msl__chevron"></i>
      </RouterLink>
    </div>

    <!-- Modal crear sala -->
    <Teleport to="body">
      <div v-if="showCreate" class="msl__modal-overlay" @click.self="showCreate = false">
        <div class="msl__modal">
          <ModalCrearSala @created="onCreated" @close="showCreate = false" />
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useSalasStore } from '../../stores/salas'
import { useLotesStore } from '../../stores/lotes'
import { useAuthStore }  from '../../stores/auth'
import ModalCrearSala    from '../../components/salas/ModalCrearSala.vue'

const salasStore = useSalasStore()
const lotesStore = useLotesStore()
const auth       = useAuthStore()

const showCreate = ref(false)
const canCreate  = computed(() => ['admin', 'supervisor'].includes(auth.role))

const salas = computed(() =>
  salasStore.items.filter(s => s.state !== 'cerrada').sort((a, b) => a.nombre.localeCompare(b.nombre))
)

function lotesEnSala(salaId) {
  return lotesStore.items.filter(l => l.sala_id === salaId && l.estado !== 'finalizado').length
}

const KIND_COLORS = { vegetativo: '#16a34a', floracion: '#9333ea', cosecha: '#dc2626', manicura: '#d97706' }
const KIND_EMOJIS = { vegetativo: '🍃', floracion: '🌸', cosecha: '🌾', manicura: '✂️' }
const KIND_LABELS = { vegetativo: 'Vegetativo', floracion: 'Floración', cosecha: 'Cosecha', manicura: 'Manicura' }

function kindColor(k) { return KIND_COLORS[k] || '#64748b' }
function kindEmoji(k) { return KIND_EMOJIS[k] || '🏠' }
function kindLabel(k) { return KIND_LABELS[k] || k || '—' }

function onCreated() { showCreate.value = false }

onMounted(async () => {
  await Promise.all([salasStore.fetchAll?.(), lotesStore.fetchAll?.()])
})
</script>

<style scoped>
.msl { padding: 0 0 1rem; }

.msl__topbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1rem .75rem;
}
.msl__title { font-size: 1.1rem; font-weight: 800; color: #0f2417; margin: 0; }
.msl__fab {
  width: 38px; height: 38px; border-radius: 12px;
  background: #1b5e20; color: #fff; border: none;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; cursor: pointer;
}

.msl__loading, .msl__empty {
  display: flex; flex-direction: column; align-items: center;
  gap: .5rem; padding: 3rem 1rem; color: #94a3b8; font-size: .875rem;
}
.msl__empty i { font-size: 2rem; }

.msl__list { display: flex; flex-direction: column; gap: .5rem; padding: 0 1rem; }

.msl__card {
  display: flex; align-items: center;
  background: #fff; border-radius: 14px;
  box-shadow: 0 1px 4px rgba(0,0,0,.07);
  text-decoration: none; overflow: hidden;
  -webkit-tap-highlight-color: transparent;
}
.msl__card-accent { width: 5px; align-self: stretch; flex-shrink: 0; }
.msl__card-body { flex: 1; padding: .875rem .875rem .875rem .75rem; min-width: 0; }
.msl__card-top { display: flex; align-items: center; gap: .5rem; margin-bottom: .3rem; }
.msl__kind-emoji { font-size: 1rem; flex-shrink: 0; }
.msl__nombre { font-size: .95rem; font-weight: 700; color: #0f172a; flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.msl__estado-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.msl__estado-dot--activa { background: #22c55e; }
.msl__estado-dot--mantenimiento { background: #f59e0b; }
.msl__estado-dot--cerrada { background: #94a3b8; }

.msl__card-meta { display: flex; align-items: center; gap: .35rem; flex-wrap: wrap; }
.msl__meta-item { font-size: .72rem; color: #64748b; }
.msl__meta-sep { color: #cbd5e1; font-size: .65rem; }
.msl__meta-sede { color: #94a3b8; }
.msl__chevron { color: #d4e6d4; font-size: .8rem; padding-right: .875rem; flex-shrink: 0; }

.msl__modal-overlay {
  position: fixed; inset: 0; z-index: 200;
  background: rgba(0,0,0,.5);
  display: flex; align-items: flex-end;
}
.msl__modal { width: 100%; max-height: 90vh; overflow-y: auto; border-radius: 20px 20px 0 0; }
</style>
