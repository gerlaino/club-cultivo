<template>
  <div>
    <div class="lhs__top">
      <button class="lhs__ver-btn" @click="$emit('ver')">
        <i class="bi bi-journal-text me-1"></i>{{ historial.length ? `Ver / registrar (${historial.length})` : 'Registrar actividad' }}
      </button>
    </div>

    <!-- Inline: vista corta de lectura -->
    <div v-if="loadingHistorial" class="lhs__placeholder">Cargando historial…</div>
    <EmptyState v-else-if="!historial.length" icon="📜" title="Sin eventos" message="Todavía no hay actividad registrada." compact />
    <div v-else class="lhs__lista">
      <div v-for="it in historialCorto" :key="it.source + it.id" class="lhs__row">
        <div class="lhs__dot" :style="{ background: dotColor(it) }"></div>
        <div class="lhs__row-body">
          <div class="lhs__row-head">
            <span class="lhs__row-titulo">{{ it.emoji }} {{ it.titulo }}<span v-if="metaDetalle(it)" class="lhs__row-detalle"> · {{ metaDetalle(it) }}</span></span>
            <span class="lhs__row-fecha">{{ formatDateTime(it.fecha) }}</span>
          </div>
          <div v-if="it.detalle" class="lhs__row-desc">{{ it.detalle }}</div>
          <div v-if="it.usuario" class="lhs__row-meta">{{ it.usuario }}</div>
        </div>
      </div>
      <button v-if="historial.length > CORTO" class="lhs__mas" @click="$emit('ver')">
        + {{ historial.length - CORTO }} más — ver historial completo
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { formatDateTime } from '../../lib/loteHelpers.js'
import EmptyState from '../ui/EmptyState.vue'
import { dotColor, metaDetalle } from '../../lib/historialHelpers.js'

const props = defineProps({
  historial:        { type: Array,   default: () => [] },
  loadingHistorial: { type: Boolean, default: false },
})
defineEmits(['ver'])

const CORTO = 6
const historialCorto = computed(() => props.historial.slice(0, CORTO))
</script>

<style scoped>
.lhs__top { display: flex; gap: .5rem; padding: .75rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lhs__ver-btn { flex: 1; background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; border-radius: 8px; padding: .55rem .85rem; font-size: .82rem; font-weight: 700; cursor: pointer; transition: all .15s; }
.lhs__ver-btn:hover { background: #dcfce7; }

.lhs__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }
.lhs__lista { display: flex; flex-direction: column; }
.lhs__row { display: flex; gap: .85rem; padding: .7rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lhs__row:last-of-type { border-bottom: none; }
.lhs__dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .35rem; }
.lhs__row-body { flex: 1; min-width: 0; }
.lhs__row-head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; }
.lhs__row-titulo { font-size: .82rem; font-weight: 600; color: #1a1a1a; }
.lhs__row-detalle { color: #64748b; font-weight: 600; }
.lhs__row-fecha { font-size: .7rem; color: #94a3b8; white-space: nowrap; flex-shrink: 0; }
.lhs__row-desc { font-size: .78rem; color: #475569; margin-top: .2rem; }
.lhs__row-meta { font-size: .72rem; color: #94a3b8; margin-top: .15rem; }
.lhs__mas { width: 100%; background: none; border: none; border-top: 1px dashed #e8f0e9; color: #1b5e20; font-size: .78rem; font-weight: 600; padding: .6rem; cursor: pointer; }
.lhs__mas:hover { background: #f0fdf4; }
</style>
