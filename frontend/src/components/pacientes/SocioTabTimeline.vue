<template>
  <div class="stl__card">
    <div class="stl__card-header">
      <div class="stl__card-icon"><Clock :size="15" /></div>
      <span class="stl__card-title">Timeline del paciente</span>
    </div>
    <div v-if="timelineLoading" class="stl__loading"><DsSpinner :size="40" /></div>
    <div v-else-if="!timeline.length" class="stl__empty">
      <div class="stl__empty-icon"><Clock :size="28" /></div>
      <div class="stl__empty-title">Sin eventos registrados</div>
    </div>
    <div v-else class="stl__timeline">
      <div v-for="(ev, i) in timeline" :key="i" class="stl__item"
        :class="{ 'stl__item--turno': ev.tipo === 'turno' }">
        <div class="stl__dot" :style="{ background: timelineColor(ev.tipo) }"></div>
        <div class="stl__body">
          <div class="stl__tipo-row">
            <div class="stl__tipo" :style="{ color: timelineColor(ev.tipo) }">{{ timelineLabel(ev.tipo) }}</div>
            <span v-if="ev.tipo === 'turno' && ev.estado"
              class="stl__turno-chip" :class="ESTADO_CLS[ev.estado]">
              {{ ESTADO_LABEL[ev.estado] || ev.estado }}
            </span>
          </div>
          <div class="stl__desc">{{ ev.descripcion }}</div>
          <div class="stl__fecha">{{ formatDateTime(ev.fecha) }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { Clock } from 'lucide-vue-next'
import DsSpinner from '../../design-system/components/Spinner.vue'

defineProps({
  timeline:        { type: Array,   required: true },
  timelineLoading: { type: Boolean, default: false },
})

const TIMELINE_COLORS = {
  dispensacion: '#0369a1',
  nota:         '#b45309',
  indicacion:   '#7c3aed',
  alta:         '#15803d',
  turno:        '#0891b2',
}
const TIMELINE_LABELS = {
  dispensacion: 'Dispensación',
  nota:         'Nota clínica',
  indicacion:   'Indicación médica',
  alta:         'Alta',
  turno:        'Turno médico',
}
const ESTADO_CLS = {
  programado: 'stl__turno-chip--prog',
  confirmado: 'stl__turno-chip--conf',
  realizado:  'stl__turno-chip--real',
  cancelado:  'stl__turno-chip--canc',
  ausente:    'stl__turno-chip--aus',
}
const ESTADO_LABEL = { programado: 'Programado', confirmado: 'Confirmado', realizado: 'Realizado', cancelado: 'Cancelado', ausente: 'Ausente' }
function timelineColor(tipo) { return TIMELINE_COLORS[tipo] || '#64748b' }
function timelineLabel(tipo) { return TIMELINE_LABELS[tipo] || tipo }
function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
</script>

<style scoped>
.stl__card { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden; }
.stl__card-header { display: flex; align-items: center; gap: .6rem; padding: .875rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.stl__card-icon { width: 28px; height: 28px; background: #dbeafe; color: #1d4ed8; border-radius: 8px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.stl__card-title { font-size: .875rem; font-weight: 700; color: #0f172a; }
.stl__loading { display: flex; justify-content: center; padding: 2rem; }
.stl__empty { text-align: center; padding: 3rem 1rem; color: #94a3b8; }
.stl__empty-icon { display: flex; justify-content: center; margin-bottom: .5rem; opacity: .4; }
.stl__empty-title { font-size: .875rem; font-weight: 600; color: #64748b; }
.stl__timeline { padding: 1.25rem; display: flex; flex-direction: column; gap: 0; }
.stl__item { display: flex; gap: 1rem; padding: .875rem 0; border-bottom: 1px solid #f1f5f9; }
.stl__item:last-child { border-bottom: none; }
.stl__dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .35rem; }
.stl__tipo-row { display: flex; align-items: center; gap: .5rem; margin-bottom: .2rem; }
.stl__tipo { font-size: .7rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; }
.stl__desc { font-size: .875rem; color: #374151; margin-bottom: .25rem; }
.stl__fecha { font-size: .72rem; color: #94a3b8; }
.stl__item--turno { background: #f0f9ff; border-radius: 8px; padding: .875rem .75rem; margin: 0 -.75rem; }
.stl__turno-chip {
  font-size: .6rem; font-weight: 700; padding: .15em .55em; border-radius: 999px;
  text-transform: uppercase; letter-spacing: .04em;
}
.stl__turno-chip--prog { background: #dbeafe; color: #1d4ed8; }
.stl__turno-chip--conf { background: #d1fae5; color: #065f46; }
.stl__turno-chip--real { background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; }
.stl__turno-chip--canc { background: #fee2e2; color: #dc2626; }
.stl__turno-chip--aus  { background: #fef3c7; color: #b45309; }
</style>
