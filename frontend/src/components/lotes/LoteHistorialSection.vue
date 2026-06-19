<template>
  <div v-if="loadingEventos" class="lhs__placeholder">Cargando historial…</div>
  <EmptyState v-else-if="eventos.length === 0" icon="📜" title="Sin eventos" message="Sin eventos registrados todavía." compact />
  <div v-else>
    <div class="lhs__eventos">
      <div v-for="e in eventosPaginados" :key="e._tipo + e.id" class="lhs__evento">

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
              <div class="lhs__evento-head-right">
                <span class="lhs__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
                <button
                  v-if="canAdmin && e.tipo !== 'cambio_estado'"
                  class="lhs__del-btn"
                  title="Borrar evento"
                  @click="$emit('delete', e)"
                ><i class="bi bi-trash"></i></button>
              </div>
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
              <div class="lhs__evento-head-right">
                <span class="lhs__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
                <button
                  v-if="canAdmin"
                  class="lhs__del-btn"
                  title="Borrar del historial"
                  @click="$emit('delete', e)"
                ><i class="bi bi-trash"></i></button>
              </div>
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

        <!-- Tarea completada -->
        <template v-else-if="e._tipo === 'tarea'">
          <div class="lhs__evento-dot" style="background:#16a34a"></div>
          <div class="lhs__evento-content">
            <div class="lhs__evento-head">
              <span class="lhs__evento-titulo">
                ✅ {{ e.titulo }}
                <span class="lhs__tarea-tipo-tag">{{ TIPO_LABELS[e.tipo] || e.tipo }}</span>
              </span>
              <div class="lhs__evento-head-right">
                <span class="lhs__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
                <button
                  v-if="canAdmin"
                  class="lhs__del-btn"
                  title="Borrar del historial"
                  @click="$emit('delete', e)"
                ><i class="bi bi-trash"></i></button>
              </div>
            </div>
            <div class="lhs__evento-meta">
              <span v-if="e.asignada_a">{{ e.asignada_a.nombre }}</span>
              <span v-if="e.horas_reales"> · {{ e.horas_reales }}hs</span>
            </div>
            <div v-if="e.notas_completado" class="lhs__evento-desc">{{ e.notas_completado }}</div>
          </div>
        </template>

      </div>
    </div>

    <!-- Paginación -->
    <div v-if="totalPaginas > 1" class="lhs__paginacion">
      <button class="lhs__pag-btn" :disabled="pagina === 1" @click="pagina--">
        <i class="bi bi-chevron-left"></i>
      </button>
      <button
        v-for="p in totalPaginas"
        :key="p"
        class="lhs__pag-num"
        :class="{ 'lhs__pag-num--activo': p === pagina }"
        @click="pagina = p"
      >{{ p }}</button>
      <button class="lhs__pag-btn" :disabled="pagina === totalPaginas" @click="pagina++">
        <i class="bi bi-chevron-right"></i>
      </button>
      <span class="lhs__pag-info">{{ (pagina - 1) * PER_PAGE + 1 }}–{{ Math.min(pagina * PER_PAGE, eventos.length) }} de {{ eventos.length }}</span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { em, sm, pgm, formatDateTime, TAREAS_LOTE } from '../../lib/loteHelpers.js'
import EmptyState from '../ui/EmptyState.vue'

const props = defineProps({
  eventos:        { type: Array,   required: true },
  loadingEventos: { type: Boolean, default: false },
  canAdmin:       { type: Boolean, default: false },
})
defineEmits(['delete'])

const PER_PAGE = 10
const pagina   = ref(1)

watch(() => props.eventos, () => { pagina.value = 1 })

const totalPaginas = computed(() => Math.ceil(props.eventos.length / PER_PAGE))
const eventosPaginados = computed(() =>
  props.eventos.slice((pagina.value - 1) * PER_PAGE, pagina.value * PER_PAGE)
)

const TIPO_LABELS = {
  riego: 'Riego', poda: 'Poda', medicion: 'Medición', limpieza: 'Limpieza',
  cosecha: 'Cosecha', transplante: 'Trasplante', inspeccion: 'Inspección',
  registrar_lote: 'Registro lote', registrar_planta: 'Registro planta', otro: 'Otro',
}
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
.lhs__evento-head-right { display: flex; align-items: center; gap: .4rem; flex-shrink: 0; }
.lhs__del-btn { background: none; border: none; color: #cbd5e1; cursor: pointer; padding: .1rem .25rem; font-size: .78rem; line-height: 1; border-radius: 5px; transition: all .15s; }
.lhs__del-btn:hover { color: #dc2626; background: #fef2f2; }
.lhs__evento-meta   { font-size: .72rem; color: #64748b; margin-bottom: .2rem; }
.lhs__evento-sala-move { display: flex; align-items: center; gap: .35rem; font-size: .75rem; color: #475569; margin: .2rem 0; }
.lhs__evento-desc   { font-size: .78rem; color: #475569; margin-top: .25rem; line-height: 1.5; }
.lhs__tareas-chips  { display: flex; flex-wrap: wrap; gap: .35rem; margin-bottom: .4rem; }
.lhs__tarea-tag     { display: inline-flex; align-items: center; gap: .25rem; background: #e8f5e9; border: 1px solid #a7d7a9; color: #1b5e20; border-radius: 999px; padding: .15em .6em; font-size: .7rem; font-weight: 600; }
.lhs__tarea-tipo-tag { display: inline-flex; align-items: center; background: #f0fdf4; border: 1px solid #d4e6d4; color: #15803d; border-radius: 6px; padding: .1em .5em; font-size: .65rem; font-weight: 600; margin-left: .35rem; text-transform: uppercase; letter-spacing: .04em; }
.lhs__metricas      { display: flex; flex-wrap: wrap; gap: .5rem; margin: .35rem 0; }
.lhs__metrica       { display: flex; align-items: center; gap: .25rem; background: #f4f8f4; border: 1px solid #d4e6d4; border-radius: 6px; padding: .2em .55em; font-size: .72rem; font-weight: 600; }

/* Paginación */
.lhs__paginacion { display: flex; align-items: center; gap: .35rem; padding: .75rem 1.1rem; border-top: 1px solid #e8f0e9; flex-wrap: wrap; }
.lhs__pag-btn { width: 30px; height: 30px; border-radius: 7px; border: 1px solid #d4e6d4; background: #f4f8f4; color: #1b5e20; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: .78rem; transition: all .15s; flex-shrink: 0; }
.lhs__pag-btn:hover:not(:disabled) { background: #1b5e20; color: #fff; border-color: #1b5e20; }
.lhs__pag-btn:disabled { opacity: .35; cursor: not-allowed; }
.lhs__pag-num { width: 30px; height: 30px; border-radius: 7px; border: 1px solid #d4e6d4; background: #f4f8f4; color: #374151; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; flex-shrink: 0; }
.lhs__pag-num:hover { border-color: #1b5e20; color: #1b5e20; }
.lhs__pag-num--activo { background: #1b5e20; border-color: #1b5e20; color: #fff; }
.lhs__pag-info { font-size: .72rem; color: #94a3b8; margin-left: .25rem; }
</style>
