<template>
  <div v-if="loadingEventos" class="lhs__placeholder">Cargando historial…</div>
  <EmptyState v-else-if="eventos.length === 0" icon="📜" title="Sin eventos" message="Sin eventos registrados todavía." compact />
  <div v-else class="lhs__eventos">
    <div v-for="e in eventos" :key="e._tipo + e.id" class="lhs__evento">

      <!-- Evento de estado -->
      <template v-if="e._tipo === 'evento'">
        <div class="lhs__evento-dot" :style="{ background: e.tipo === 'cambio_estado' ? '#1b5e20' : '#64748b' }"></div>
        <div class="lhs__evento-content">
          <div class="lhs__evento-head">
            <span v-if="e.tipo === 'cambio_estado'" class="lhs__evento-titulo">
              {{ em(e.estado_anterior).emoji }} {{ em(e.estado_anterior).label }}
              <span class="lhs__evento-arrow">→</span>
              {{ em(e.estado_nuevo).emoji }} {{ em(e.estado_nuevo).label }}
            </span>
            <span v-else class="lhs__evento-titulo">{{ e.descripcion }}</span>
            <span class="lhs__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
          </div>
          <div class="lhs__evento-meta">{{ e.usuario }}</div>
          <div v-if="e.sala_origen && e.sala_destino" class="lhs__evento-sala-move">
            <i class="bi bi-house-door"></i>
            <span>{{ e.sala_origen.nombre }}</span>
            <i class="bi bi-arrow-right"></i>
            <span>{{ e.sala_destino.nombre }}</span>
          </div>
          <div v-if="e.tipo === 'cambio_estado' && e.descripcion" class="lhs__evento-desc">{{ e.descripcion }}</div>
        </div>
      </template>

      <!-- Registro ambiental -->
      <template v-else-if="e._tipo === 'registro'">
        <div class="lhs__evento-dot" style="background:#0891b2"></div>
        <div class="lhs__evento-content">
          <div class="lhs__evento-head">
            <span class="lhs__evento-titulo">
              📋 Registro del lote
              <span v-if="e.estado_general" :style="{ color: sm(e.estado_general).color }">· {{ sm(e.estado_general).emoji }} {{ e.estado_general }}</span>
              <span v-if="e.fertilizacion" style="color:#1b5e20"> · 🌿 fertilización</span>
              <span v-if="e.plagas_observadas && e.plagas_observadas !== 'ninguna'" :style="{ color: pgm(e.plagas_observadas).color }"> · {{ pgm(e.plagas_observadas).emoji }} {{ e.plagas_observadas }}</span>
            </span>
            <span class="lhs__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
          </div>
          <div class="lhs__evento-meta">{{ e.usuario }}</div>
          <div v-if="e.tareas_realizadas?.length" class="lhs__tareas-chips">
            <span v-for="tk in e.tareas_realizadas" :key="tk" class="lhs__tarea-tag">
              {{ TAREAS_LOTE.find(t => t.key === tk)?.emoji }} {{ TAREAS_LOTE.find(t => t.key === tk)?.label || tk }}
            </span>
          </div>
          <div class="lhs__metricas">
            <div v-if="e.temperatura"  class="lhs__metrica"><span>🌡️</span><span>{{ e.temperatura }}°C</span></div>
            <div v-if="e.humedad"      class="lhs__metrica"><span>💧</span><span>{{ e.humedad }}%</span></div>
            <div v-if="e.ph"           class="lhs__metrica"><span>⚗️</span><span>pH {{ e.ph }}</span></div>
            <div v-if="e.ec"           class="lhs__metrica"><span>⚡</span><span>EC {{ e.ec }}</span></div>
            <div v-if="e.co2"          class="lhs__metrica"><span>💨</span><span>{{ e.co2 }}ppm</span></div>
            <div v-if="e.horas_luz"    class="lhs__metrica"><span>🕐</span><span>{{ e.horas_luz }}h luz</span></div>
          </div>
          <div v-if="e.observaciones" class="lhs__evento-desc">{{ e.observaciones }}</div>
        </div>
      </template>

    </div>
  </div>
</template>

<script setup>
import { em, sm, pgm, formatDateTime, TAREAS_LOTE } from '../../lib/loteHelpers.js'
import EmptyState from '../ui/EmptyState.vue'

defineProps({
  eventos:        { type: Array,   required: true },
  loadingEventos: { type: Boolean, default: false },
})
</script>

<style scoped>
.lhs__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }
.lhs__eventos { display: flex; flex-direction: column; }
.lhs__evento { display: flex; gap: .85rem; padding: .75rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lhs__evento:last-child { border-bottom: none; }
.lhs__evento-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .35rem; }
.lhs__evento-content { flex: 1; min-width: 0; }
.lhs__evento-head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; flex-wrap: wrap; margin-bottom: .15rem; }
.lhs__evento-titulo { font-size: .82rem; font-weight: 600; color: #1a1a1a; }
.lhs__evento-arrow  { color: #94a3b8; margin: 0 .2rem; }
.lhs__evento-fecha  { font-size: .7rem; color: #94a3b8; white-space: nowrap; flex-shrink: 0; }
.lhs__evento-meta   { font-size: .72rem; color: #64748b; margin-bottom: .2rem; }
.lhs__evento-sala-move { display: flex; align-items: center; gap: .35rem; font-size: .75rem; color: #475569; margin: .2rem 0; }
.lhs__evento-desc   { font-size: .78rem; color: #475569; margin-top: .25rem; line-height: 1.5; }
.lhs__tareas-chips  { display: flex; flex-wrap: wrap; gap: .35rem; margin-bottom: .4rem; }
.lhs__tarea-tag     { display: inline-flex; align-items: center; gap: .25rem; background: #e8f5e9; border: 1px solid #a7d7a9; color: #1b5e20; border-radius: 999px; padding: .15em .6em; font-size: .7rem; font-weight: 600; }
.lhs__metricas      { display: flex; flex-wrap: wrap; gap: .5rem; margin: .35rem 0; }
.lhs__metrica       { display: flex; align-items: center; gap: .25rem; background: #f4f8f4; border: 1px solid #d4e6d4; border-radius: 6px; padding: .2em .55em; font-size: .72rem; font-weight: 600; }
</style>
