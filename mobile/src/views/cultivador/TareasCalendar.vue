<template>
  <div class="page tc">

    <!-- Header -->
    <div class="page-header">
      <h1>Mis Tareas</h1>
      <span class="tc__summary" v-if="!loading">
        {{ tareasHoy.length }} hoy
      </span>
    </div>

    <!-- Strip de días -->
    <div class="tc__strip-wrap">
      <div class="tc__strip">
        <button
          v-for="day in dias"
          :key="day.iso"
          class="tc__day"
          :class="{
            'tc__day--today':    day.isToday,
            'tc__day--selected': day.iso === selectedDay,
            'tc__day--past':     day.isPast,
          }"
          @click="selectedDay = day.iso"
        >
          <span class="tc__day-name">{{ day.nombre }}</span>
          <span class="tc__day-num">{{ day.num }}</span>
          <span class="tc__day-dots">
            <span
              v-for="(t, i) in (tareasPorDia[day.iso] || []).slice(0, 3)"
              :key="i"
              class="tc__dot"
              :class="`tc__dot--${t.estado}`"
            />
          </span>
        </button>
      </div>
    </div>

    <!-- Contenido del día seleccionado -->
    <div class="page-content">
      <div v-if="loading" class="empty-state">
        <div class="spinner spinner--dark" />
      </div>

      <template v-else>
        <p class="tc__day-label">{{ diaSeleccionadoLabel }}</p>

        <div v-if="tareasDelDia.length === 0" class="empty-state">
          <div class="icon">📋</div>
          <p>Sin tareas para este día</p>
        </div>

        <div v-else class="tc__list">
          <button
            v-for="tarea in tareasDelDia"
            :key="tarea.id"
            class="tc__tarea-card"
            :class="{ 'tc__tarea-card--done': tarea.estado === 'completada' }"
            @click="abrirTarea(tarea)"
          >
            <div class="tc__tarea-icon">{{ tipoEmoji(tarea.tipo) }}</div>
            <div class="tc__tarea-body">
              <div class="tc__tarea-titulo">{{ tarea.titulo }}</div>
              <div class="tc__tarea-sub">
                <span v-if="tarea.sala?.nombre">{{ tarea.sala.nombre }}</span>
                <span v-if="tarea.lote?.codigo"> · {{ tarea.lote.codigo }}</span>
              </div>
            </div>
            <div class="tc__tarea-right">
              <span class="tc__prioridad" :class="`tc__prioridad--${tarea.prioridad}`">
                {{ tarea.prioridad }}
              </span>
              <span v-if="tarea.estado === 'completada'" class="tc__check">✓</span>
            </div>
          </button>
        </div>
      </template>
    </div>

    <!-- BottomSheet: completar tarea -->
    <BottomSheet v-model="showTarea" :title="tareaActiva?.titulo || ''">
      <template v-if="tareaActiva">
        <div class="tc__bs-tipo">{{ tipoEmoji(tareaActiva.tipo) }} {{ tareaActiva.tipo }}</div>
        <div v-if="tareaActiva.sala?.nombre || tareaActiva.lote?.codigo" class="tc__bs-ctx">
          <span v-if="tareaActiva.sala?.nombre">📍 {{ tareaActiva.sala.nombre }}</span>
          <span v-if="tareaActiva.lote?.codigo"> · Lote {{ tareaActiva.lote.codigo }}</span>
        </div>
        <div v-if="tareaActiva.descripcion" class="tc__bs-desc">{{ tareaActiva.descripcion }}</div>

        <template v-if="tareaActiva.estado !== 'completada'">
          <div class="field" style="margin-top:1rem">
            <label>Horas trabajadas <span style="font-weight:400;text-transform:none">(opcional)</span></label>
            <input v-model.number="horasForm" type="number" step="0.5" min="0" placeholder="ej: 1.5" />
          </div>
        </template>

        <div v-else class="tc__bs-done">
          ✅ Completada el {{ formatDateTime(tareaActiva.fecha_completada) }}
        </div>
      </template>

      <template #footer>
        <button
          v-if="tareaActiva?.estado !== 'completada'"
          class="btn btn-primary btn-full"
          :disabled="completando"
          @click="marcarCompletada"
        >
          <span v-if="completando" class="spinner" />
          <span v-else>✅ Marcar como completada</span>
        </button>
        <button class="btn btn-ghost btn-full" @click="showTarea = false">Cerrar</button>
      </template>
    </BottomSheet>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import BottomSheet from '@/components/BottomSheet.vue'
import { getTareas, completarTarea } from '@/lib/api'

const TIPO_EMOJI = {
  riego: '💧', poda: '✂️', medicion: '🌡️', limpieza: '🧹', cosecha: '✂️',
  transplante: '🪴', inspeccion: '🔍', otro: '📌', nutricion: '🧪',
  defoliacion: '🍃', scrog_lst: '🪢', ajuste_luz: '💡', revision_plagas: '🔍',
}
function tipoEmoji(t) { return TIPO_EMOJI[t] || '📌' }

// Generar strip de 7 días (hoy en el centro)
const hoy = new Date()
hoy.setHours(0,0,0,0)
const DIA_NAMES = ['Do','Lu','Ma','Mi','Ju','Vi','Sá']

const dias = Array.from({ length: 7 }, (_, i) => {
  const d = new Date(hoy)
  d.setDate(hoy.getDate() + (i - 3))
  const iso = d.toISOString().slice(0, 10)
  return {
    iso,
    nombre:  DIA_NAMES[d.getDay()],
    num:     d.getDate(),
    isToday: i === 3,
    isPast:  i < 3,
  }
})

const fechaDesde = dias[0].iso
const fechaHasta = dias[6].iso

const selectedDay  = ref(dias[3].iso) // hoy
const loading      = ref(true)
const tareas       = ref([])
const showTarea    = ref(false)
const tareaActiva  = ref(null)
const horasForm    = ref(null)
const completando  = ref(false)

const tareasPorDia = computed(() => {
  const map = {}
  for (const t of tareas.value) {
    const d = t.fecha_programada?.slice(0, 10)
    if (!d) continue
    if (!map[d]) map[d] = []
    map[d].push(t)
  }
  return map
})

const tareasDelDia = computed(() => tareasPorDia.value[selectedDay.value] || [])
const tareasHoy    = computed(() => tareasPorDia.value[dias[3].iso] || [])

const diaSeleccionadoLabel = computed(() => {
  const d = new Date(selectedDay.value + 'T12:00:00')
  return d.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
})

function formatDateTime(s) {
  if (!s) return '—'
  return new Date(s).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

function abrirTarea(t) {
  tareaActiva.value = t
  horasForm.value   = null
  showTarea.value   = true
}

async function marcarCompletada() {
  completando.value = true
  try {
    const { data } = await completarTarea(tareaActiva.value.id, {
      horas_reales: horasForm.value || undefined,
    })
    const idx = tareas.value.findIndex(t => t.id === tareaActiva.value.id)
    if (idx !== -1) tareas.value[idx] = { ...tareas.value[idx], ...data }
    tareaActiva.value = tareas.value[idx]
    showTarea.value = false
  } catch { /* silencioso */ }
  finally { completando.value = false }
}

onMounted(async () => {
  try {
    const { data } = await getTareas({
      scope: 'mias',
      fecha_desde: fechaDesde,
      fecha_hasta:  fechaHasta,
    })
    tareas.value = data || []
  } catch { tareas.value = [] }
  loading.value = false
})
</script>

<style scoped>
.tc__summary { font-size: .78rem; color: var(--text-2); font-weight: 600; }

.tc__strip-wrap {
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  padding: .75rem 1rem;
  flex-shrink: 0;
}
.tc__strip { display: flex; justify-content: space-between; gap: .25rem; }

.tc__day {
  flex: 1;
  display: flex; flex-direction: column; align-items: center; gap: .2rem;
  padding: .5rem .25rem;
  border-radius: 12px;
  background: none;
  border: 2px solid transparent;
  transition: all .12s;
}
.tc__day--selected { background: var(--green-bg); border-color: var(--green-border); }
.tc__day--today .tc__day-num { color: var(--green); font-weight: 800; }
.tc__day--past { opacity: .55; }

.tc__day-name { font-size: .6rem; font-weight: 700; text-transform: uppercase; color: var(--text-2); letter-spacing: .04em; }
.tc__day-num  { font-size: .95rem; font-weight: 700; color: var(--text); }
.tc__day-dots { display: flex; gap: 2px; height: 8px; align-items: center; }
.tc__dot      { width: 6px; height: 6px; border-radius: 50%; background: var(--green-border); }
.tc__dot--completada { background: var(--green); }
.tc__dot--pendiente  { background: var(--yellow); }
.tc__dot--en_progreso{ background: #3b82f6; }

.tc__day-label {
  font-size: .8rem; font-weight: 700; color: var(--text-2);
  text-transform: capitalize; margin-bottom: .75rem;
}

.tc__list { display: flex; flex-direction: column; gap: .5rem; }
.tc__tarea-card {
  display: flex; align-items: center; gap: .75rem;
  background: var(--surface); border: 1px solid var(--border);
  border-radius: 14px; padding: .875rem 1rem;
  text-align: left; width: 100%; transition: all .1s;
  box-shadow: var(--shadow);
}
.tc__tarea-card:active { transform: scale(.98); }
.tc__tarea-card--done  { opacity: .6; }
.tc__tarea-icon  { font-size: 1.5rem; flex-shrink: 0; }
.tc__tarea-body  { flex: 1; min-width: 0; }
.tc__tarea-titulo{ font-size: .9rem; font-weight: 600; color: var(--text); }
.tc__tarea-sub   { font-size: .72rem; color: var(--text-2); margin-top: .15rem; }
.tc__tarea-right { display: flex; flex-direction: column; align-items: flex-end; gap: .3rem; flex-shrink: 0; }
.tc__prioridad {
  font-size: .6rem; font-weight: 700; text-transform: uppercase;
  padding: .15em .5em; border-radius: 999px; letter-spacing: .04em;
}
.tc__prioridad--urgente { background: #fef2f2; color: var(--red); }
.tc__prioridad--alta    { background: #fff7ed; color: var(--yellow); }
.tc__prioridad--normal  { background: var(--green-bg); color: var(--green); }
.tc__prioridad--baja    { background: #f1f5f9; color: var(--text-3); }
.tc__check { font-size: 1rem; color: var(--green); font-weight: 700; }

.tc__bs-tipo { font-size: .85rem; font-weight: 700; color: var(--text-2); text-transform: capitalize; margin-bottom: .35rem; }
.tc__bs-ctx  { font-size: .82rem; color: var(--text-2); margin-bottom: .5rem; }
.tc__bs-desc { font-size: .875rem; color: var(--text); background: var(--bg); padding: .75rem; border-radius: 10px; line-height: 1.5; }
.tc__bs-done { font-size: .875rem; color: var(--green); font-weight: 600; margin-top: .75rem; }
</style>
