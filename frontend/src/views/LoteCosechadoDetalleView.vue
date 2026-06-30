<template>
  <div class="lcd">

    <Breadcrumb :items="[
      { label: 'Mis cosechas', to: { name: 'cosechado' } },
      { label: lote?.codigo || `Lote #${id}` },
    ]" />

    <div v-if="loading" class="lcd__loading"><DsSpinner /></div>
    <div v-else-if="error" class="lcd__error">{{ error }}</div>

    <template v-else-if="lote">

      <!-- Hero -->
      <div class="lcd__hero">
        <div class="lcd__hero-left">
          <div class="lcd__hero-title-row">
            <span class="lcd__hero-emoji">🌿</span>
            <h1 class="lcd__title">{{ lote.codigo }}</h1>
            <span class="lcd__estado-pill">Cosechado</span>
          </div>
          <p class="lcd__subtitle">
            <span v-if="lote.genetica">{{ lote.genetica.nombre }}</span>
            <span v-if="lote.sala" class="lcd__sep">·</span>
            <span v-if="lote.sala">{{ lote.sala.nombre }}</span>
            <span v-if="lote.start_date" class="lcd__sep">·</span>
            <span v-if="lote.start_date">Inicio {{ formatFecha(lote.start_date) }}</span>
          </p>
        </div>
        <div v-if="lote.fecha_cosechado" class="lcd__hero-fecha">
          <span class="lcd__hero-fecha-label">Cosechado el</span>
          <span class="lcd__hero-fecha-val">{{ formatFecha(lote.fecha_cosechado) }}</span>
        </div>
      </div>

      <!-- Stats -->
      <div class="lcd__stats-grid">
        <div class="lcd__stat">
          <span class="lcd__stat-val">{{ lote.plants_count ?? '—' }}</span>
          <span class="lcd__stat-lbl">Plantas</span>
        </div>
        <div class="lcd__stat">
          <span class="lcd__stat-val">{{ lote.plants_count_cosechadas ?? '—' }}</span>
          <span class="lcd__stat-lbl">Cosechadas</span>
        </div>
        <div class="lcd__stat">
          <span class="lcd__stat-val">{{ lote.dias_vegetacion != null ? lote.dias_vegetacion + 'd' : '—' }}</span>
          <span class="lcd__stat-lbl">Vegetativo</span>
        </div>
        <div class="lcd__stat">
          <span class="lcd__stat-val">{{ lote.dias_floracion != null ? lote.dias_floracion + 'd' : '—' }}</span>
          <span class="lcd__stat-lbl">Floración</span>
        </div>
        <div v-if="lote.rendimiento_real_g" class="lcd__stat">
          <span class="lcd__stat-val">{{ lote.rendimiento_real_g }}g</span>
          <span class="lcd__stat-lbl">Rendimiento</span>
        </div>
        <div v-if="lote.rendimiento_objetivo_g" class="lcd__stat">
          <span class="lcd__stat-val">{{ lote.rendimiento_objetivo_g }}g</span>
          <span class="lcd__stat-lbl">Objetivo</span>
        </div>
      </div>

      <!-- Historial de estados -->
      <div class="lcd__section">
        <h2 class="lcd__section-title">
          Historial del ciclo
          <span v-if="eventos.length" class="lcd__section-count">{{ eventos.length }}</span>
        </h2>
        <div v-if="loadingEventos" class="lcd__loading-sm"><DsSpinner :size="20" /></div>
        <div v-else-if="!eventos.length" class="lcd__empty">Sin registros en el historial.</div>
        <div v-else class="lcd__timeline">
          <div
            v-for="ev in eventos"
            :key="ev.id + ev._tipo"
            class="lcd__ev"
            :class="`lcd__ev--${ev._tipo}`"
          >
            <div class="lcd__ev-dot"></div>
            <div class="lcd__ev-body">
              <div class="lcd__ev-header">
                <span class="lcd__ev-tipo">{{ tipoLabelEvento(ev) }}</span>
                <span class="lcd__ev-fecha">{{ formatFechaHora(ev.registrado_en) }}</span>
              </div>
              <p v-if="ev.descripcion" class="lcd__ev-desc">{{ ev.descripcion }}</p>
              <div v-if="ev._tipo === 'evento' && ev.estado_anterior && ev.estado_nuevo" class="lcd__ev-transicion">
                <span class="lcd__ev-estado">{{ estadoLabel(ev.estado_anterior) }}</span>
                <span class="lcd__ev-arrow">→</span>
                <span class="lcd__ev-estado lcd__ev-estado--nuevo">{{ estadoLabel(ev.estado_nuevo) }}</span>
              </div>
              <p v-if="ev.usuario" class="lcd__ev-autor">por {{ ev.usuario }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Tareas registradas -->
      <div class="lcd__section">
        <h2 class="lcd__section-title">
          Tareas del ciclo
          <span v-if="tareas.length" class="lcd__section-count">{{ tareas.length }}</span>
        </h2>
        <div v-if="loadingTareas" class="lcd__loading-sm"><DsSpinner :size="20" /></div>
        <div v-else-if="!tareas.length" class="lcd__empty">No hay tareas registradas para este lote.</div>
        <div v-else class="lcd__tareas-list">
          <div v-for="t in tareas" :key="t.id" class="lcd__tarea" :class="`lcd__tarea--${t.estado}`">
            <span class="lcd__tarea-emoji">{{ TAREA_EMOJI[t.tipo] || '📋' }}</span>
            <div class="lcd__tarea-body">
              <span class="lcd__tarea-titulo">{{ t.titulo }}</span>
              <span v-if="t.descripcion" class="lcd__tarea-desc">{{ t.descripcion }}</span>
              <div class="lcd__tarea-meta">
                <span v-if="t.fecha_programada" class="lcd__tarea-fecha">{{ formatFecha(t.fecha_programada) }}</span>
                <span v-if="t.asignada_a" class="lcd__tarea-asignado">{{ t.asignada_a.nombre }}</span>
              </div>
            </div>
            <span class="lcd__tarea-estado" :class="`lcd__tarea-estado--${t.estado}`">
              {{ TAREA_ESTADO_LABEL[t.estado] || t.estado }}
            </span>
          </div>
        </div>
      </div>

      <!-- Plantas -->
      <div v-if="plantas.length" class="lcd__section">
        <h2 class="lcd__section-title">
          Plantas del lote
          <span class="lcd__section-count">{{ plantas.length }}</span>
        </h2>
        <div class="lcd__plantas-grid">
          <RouterLink
            v-for="p in plantas"
            :key="p.id"
            :to="{ name: 'planta-cosechada-detalle', params: { loteId: id, id: p.id } }"
            class="lcd__planta"
          >
            <div class="lcd__planta-left">
              <span class="lcd__planta-nombre">{{ p.nombre }}</span>
              <span v-if="p.es_seleccion" class="lcd__planta-sel">★ Selección</span>
            </div>
            <div class="lcd__planta-right">
              <span v-if="p.peso_seco" class="lcd__planta-peso">{{ p.peso_seco }}g</span>
              <span v-else class="lcd__planta-peso lcd__planta-peso--none">—</span>
              <ChevronRight :size="13" class="lcd__planta-arr" />
            </div>
          </RouterLink>
        </div>
      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getLote, getLoteEventos, getRegistrosAmbientales, listTareas } from '../lib/api.js'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import DsSpinner  from '../design-system/components/Spinner.vue'
import { ChevronRight } from 'lucide-vue-next'

const route = useRoute()
const id    = Number(route.params.id)

const loading       = ref(true)
const loadingEventos= ref(false)
const loadingTareas = ref(false)
const error         = ref(null)
const lote          = ref(null)
const plantas       = ref([])
const eventos       = ref([])
const tareas        = ref([])

const ESTADO_LABEL = {
  semilla: 'Semilla', esqueje: 'Esqueje', vegetativo: 'Vegetativo',
  floracion: 'Floración', cosecha: 'Cosecha', en_manicura: 'En manicura',
  curado: 'Curado', finalizado: 'Finalizado',
}
const TAREA_EMOJI = {
  riego: '💧', poda: '✂️', medicion: '📏', limpieza: '🧹',
  cosecha: '🌿', transplante: '🪴', inspeccion: '🔍', otro: '📋',
}
const TAREA_ESTADO_LABEL = {
  pendiente: 'Pendiente', en_progreso: 'En progreso',
  completada: 'Completada', cancelada: 'Cancelada',
}

function estadoLabel(e)  { return ESTADO_LABEL[e] || e }

function tipoLabelEvento(ev) {
  if (ev._tipo === 'registro') return '🌡️ Registro ambiental'
  if (ev.tipo === 'cambio_estado') return '🔄 Cambio de estado'
  if (ev.tipo === 'nota') return '📝 Nota'
  return '📋 Evento'
}

function formatFecha(d) {
  if (!d) return '—'
  return new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}
function formatFechaHora(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  try {
    const { data } = await getLote(id)
    lote.value    = data
    plantas.value = data.plants || []
  } catch {
    error.value = 'No se pudo cargar el lote cosechado.'
  } finally {
    loading.value = false
  }

  loadingEventos.value = true
  try {
    const [evRes, regRes] = await Promise.all([
      getLoteEventos(id),
      getRegistrosAmbientales(id),
    ])
    const evs  = (evRes.data  || []).map(e => ({ ...e, _tipo: 'evento' }))
    const regs = (regRes.data || []).map(r => ({ ...r, _tipo: 'registro' }))
    eventos.value = [...evs, ...regs].sort((a, b) => new Date(b.registrado_en) - new Date(a.registrado_en))
  } catch {
    eventos.value = []
  } finally {
    loadingEventos.value = false
  }

  loadingTareas.value = true
  try {
    const { data } = await listTareas({ lote_id: id })
    tareas.value = (data || []).sort((a, b) => {
      if (a.fecha_programada && b.fecha_programada)
        return new Date(b.fecha_programada) - new Date(a.fecha_programada)
      return 0
    })
  } catch {
    tareas.value = []
  } finally {
    loadingTareas.value = false
  }
})
</script>

<style scoped>
.lcd { max-width: 860px; margin: 0 auto; padding: 1.5rem 1.25rem; display: flex; flex-direction: column; gap: 1.75rem; }
@media (max-width: 640px) { .lcd { padding: 1rem .75rem 80px; gap: 1.25rem; } }

.lcd__loading { display: flex; justify-content: center; padding: 4rem; }
.lcd__loading-sm { display: flex; justify-content: center; padding: 1.5rem; }
.lcd__error { color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; padding: 1rem 1.25rem; }

/* Hero */
.lcd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
.lcd__hero-left { flex: 1; min-width: 0; }
.lcd__hero-title-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; margin-bottom: .35rem; }
.lcd__hero-emoji { font-size: 1.5rem; line-height: 1; flex-shrink: 0; }
.lcd__title { font-size: 1.5rem; font-weight: 700; color: #0f2611; margin: 0; letter-spacing: -.025em; }
.lcd__estado-pill { font-size: .72rem; font-weight: 700; padding: .25em .7em; border-radius: 999px; background: #dcfce7; color: #14532d; white-space: nowrap; }
.lcd__subtitle { font-size: .875rem; color: #60725d; margin: 0; display: flex; align-items: center; flex-wrap: wrap; gap: .35rem; }
.lcd__sep { color: #c8e6c9; }
.lcd__hero-fecha { display: flex; flex-direction: column; align-items: flex-end; flex-shrink: 0; padding-top: 2px; }
.lcd__hero-fecha-label { font-size: .72rem; color: #60725d; text-transform: uppercase; letter-spacing: .05em; font-weight: 600; }
.lcd__hero-fecha-val { font-size: 1.1rem; font-weight: 700; color: #1b5e20; }

/* Stats */
.lcd__stats-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(110px, 1fr)); gap: .75rem; }
.lcd__stat { background: #fff; border: 1px solid #e8f0e9; border-radius: 10px; padding: .875rem 1rem; display: flex; flex-direction: column; gap: .2rem; }
.lcd__stat-val { font-size: 1.4rem; font-weight: 700; color: #0f2611; line-height: 1; font-variant-numeric: tabular-nums; }
.lcd__stat-lbl { font-size: .72rem; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #60725d; }

/* Sections */
.lcd__section { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.lcd__section-title { display: flex; align-items: center; gap: .5rem; font-size: 1rem; font-weight: 700; color: #0f2611; margin: 0; }
.lcd__section-count { display: inline-flex; align-items: center; justify-content: center; min-width: 20px; height: 20px; border-radius: 999px; background: #e8f0e9; color: #0f2611; font-size: .72rem; font-weight: 700; padding: 0 .35rem; }
.lcd__empty { font-size: .85rem; color: #9ca3af; }

/* Timeline eventos */
.lcd__timeline { display: flex; flex-direction: column; }
.lcd__ev { display: flex; gap: .75rem; position: relative; padding-bottom: 1.25rem; }
.lcd__ev:last-child { padding-bottom: 0; }
.lcd__ev::before { content: ''; position: absolute; left: 7px; top: 16px; bottom: 0; width: 1px; background: #e8f0e9; }
.lcd__ev:last-child::before { display: none; }
.lcd__ev-dot { width: 15px; height: 15px; border-radius: 50%; flex-shrink: 0; margin-top: 2px; border: 2px solid #e8f0e9; background: #fff; z-index: 1; }
.lcd__ev--evento .lcd__ev-dot { border-color: #1b5e20; background: #dcfce7; }
.lcd__ev--registro .lcd__ev-dot { border-color: #0369a1; background: #e0f2fe; }
.lcd__ev-body { flex: 1; min-width: 0; }
.lcd__ev-header { display: flex; align-items: baseline; justify-content: space-between; gap: .5rem; flex-wrap: wrap; margin-bottom: .2rem; }
.lcd__ev-tipo { font-size: .8rem; font-weight: 600; color: #0f2611; }
.lcd__ev-fecha { font-size: .72rem; color: #9ca3af; white-space: nowrap; }
.lcd__ev-desc { font-size: .82rem; color: #475569; margin: 0 0 .2rem; line-height: 1.5; }
.lcd__ev-transicion { display: flex; align-items: center; gap: .4rem; font-size: .78rem; margin-bottom: .2rem; }
.lcd__ev-estado { background: #f1f5f9; color: #475569; padding: .15em .5em; border-radius: 4px; font-weight: 600; }
.lcd__ev-estado--nuevo { background: #dcfce7; color: #14532d; }
.lcd__ev-arrow { color: #9ca3af; }
.lcd__ev-autor { font-size: .72rem; color: #9ca3af; margin: 0; }

/* Tareas */
.lcd__tareas-list { display: flex; flex-direction: column; gap: .4rem; }
.lcd__tarea { display: flex; align-items: flex-start; gap: .75rem; padding: .75rem; border-radius: 8px; border: 1px solid #f0f4f0; background: #fafafa; }
.lcd__tarea--completada { background: #f8fdf8; border-color: #e8f0e9; }
.lcd__tarea--cancelada  { opacity: .5; }
.lcd__tarea-emoji { font-size: 1.1rem; flex-shrink: 0; margin-top: 1px; }
.lcd__tarea-body { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: .15rem; }
.lcd__tarea-titulo { font-size: .85rem; font-weight: 600; color: #0f2611; }
.lcd__tarea-desc { font-size: .78rem; color: #60725d; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.lcd__tarea-meta { display: flex; gap: .5rem; flex-wrap: wrap; margin-top: .1rem; }
.lcd__tarea-fecha, .lcd__tarea-asignado { font-size: .72rem; color: #9ca3af; }
.lcd__tarea-estado { font-size: .68rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; white-space: nowrap; flex-shrink: 0; align-self: center; }
.lcd__tarea-estado--completada { background: #dcfce7; color: #14532d; }
.lcd__tarea-estado--en_progreso { background: #fef3c7; color: #92400e; }
.lcd__tarea-estado--pendiente   { background: #f1f5f9; color: #475569; }
.lcd__tarea-estado--cancelada   { background: #fef2f2; color: #991b1b; }

/* Plantas */
.lcd__plantas-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: .5rem; }
.lcd__planta { display: flex; justify-content: space-between; align-items: center; background: #f8fdf8; border: 1px solid #e8f0e9; border-radius: 8px; padding: .6rem .75rem; gap: .5rem; text-decoration: none; transition: background .12s, border-color .12s; cursor: pointer; }
.lcd__planta:hover { background: #f0fdf4; border-color: #a7d9ae; }
.lcd__planta-left { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.lcd__planta-nombre { font-size: .82rem; font-weight: 600; color: #0f2611; }
.lcd__planta-sel { font-size: .68rem; font-weight: 600; color: #d97706; }
.lcd__planta-right { display: flex; align-items: center; gap: .3rem; flex-shrink: 0; }
.lcd__planta-peso { font-size: .78rem; font-weight: 700; color: #1b5e20; }
.lcd__planta-peso--none { color: #c8e6c9; font-weight: 400; }
.lcd__planta-arr { color: #c8e6c9; }
.lcd__planta:hover .lcd__planta-arr { color: #1b5e20; }
</style>
