<template>
  <div>
    <!-- Registrar actividad (backfill de historia real) -->
    <div v-if="canAdmin" class="lhs__add">
      <button v-if="!formAbierto" class="lhs__add-btn" @click="abrirForm">
        <i class="bi bi-plus-circle me-1"></i>Registrar actividad
      </button>
      <div v-else class="lhs__form">
        <div class="lhs__form-row">
          <select v-model="form.categoria" class="lhs__form-sel">
            <option v-for="t in CATEGORIAS" :key="t.value" :value="t.value">{{ t.emoji }} {{ t.label }}</option>
          </select>
          <AppDatePicker v-model="form.fecha" :max="hoy" class="lhs__form-date" />
        </div>

        <!-- Campos según el tipo de actividad -->
        <div v-if="form.categoria === 'fertilizacion'" class="lhs__form-row">
          <input v-model="form.producto" type="text" class="lhs__form-input" maxlength="120" placeholder="Producto / fórmula (ej: Bio-Grow 2ml/L)" />
          <input v-model.number="form.ec" type="number" step="0.1" min="0" class="lhs__form-num" placeholder="EC" />
        </div>
        <div v-else-if="form.categoria === 'riego'" class="lhs__form-row">
          <input v-model.number="form.volumen" type="number" step="0.1" min="0" class="lhs__form-num" placeholder="Volumen (L)" />
          <input v-model.number="form.ec" type="number" step="0.1" min="0" class="lhs__form-num" placeholder="EC" />
        </div>

        <input v-model="form.descripcion" type="text" class="lhs__form-input" maxlength="200"
               :placeholder="placeholderDescripcion" @keyup.enter="guardar" />
        <div class="lhs__form-actions">
          <button class="lhs__form-cancel" @click="cerrarForm">Cancelar</button>
          <button class="lhs__form-save" :disabled="!formValido" @click="guardar">Registrar</button>
        </div>
      </div>
    </div>

    <div v-if="loadingEventos" class="lhs__placeholder">Cargando historial…</div>
    <EmptyState v-else-if="eventos.length === 0" icon="📜" title="Sin eventos" message="Sin eventos registrados todavía." compact />
    <div v-else>
    <div class="lhs__eventos">
      <div v-for="e in eventosPaginados" :key="e._tipo + e.id" class="lhs__evento">

        <!-- Evento de estado -->
        <template v-if="e._tipo === 'evento'">
          <div class="lhs__evento-dot" :style="{ background: dotColor(e) }"></div>
          <div class="lhs__evento-content">
            <!-- Modo edición (solo notas/alertas manuales) -->
            <div v-if="editandoId === e.id" class="lhs__form">
              <input v-model="editForm.descripcion" type="text" class="lhs__form-input" maxlength="200"
                     placeholder="Descripción del evento" @keyup.enter="guardarEdicion(e)" />
              <div class="lhs__form-row">
                <AppDatePicker v-model="editForm.fecha" :max="hoy" class="lhs__form-date" />
                <div class="lhs__form-actions">
                  <button class="lhs__form-cancel" @click="cancelarEdicion">Cancelar</button>
                  <button class="lhs__form-save" @click="guardarEdicion(e)">Guardar</button>
                </div>
              </div>
            </div>
            <!-- Modo normal -->
            <template v-else>
              <div class="lhs__evento-head">
                <span v-if="e.tipo === 'cambio_estado'" class="lhs__evento-titulo">
                  {{ em(e.estado_anterior).emoji }} {{ em(e.estado_anterior).label }}
                  <span class="lhs__evento-arrow">→</span>
                  {{ em(e.estado_nuevo).emoji }} {{ em(e.estado_nuevo).label }}
                </span>
                <span v-else-if="e.tipo === 'actividad'" class="lhs__evento-titulo">
                  {{ e.categoria_emoji }} {{ e.categoria_label }}<span v-if="metaDetalle(e)" class="lhs__evento-detalle"> · {{ metaDetalle(e) }}</span>
                </span>
                <span v-else class="lhs__evento-titulo">{{ e.descripcion }}</span>
                <div class="lhs__evento-head-right">
                  <span class="lhs__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
                  <button
                    v-if="canAdmin && e.tipo !== 'cambio_estado'"
                    class="lhs__edit-btn"
                    title="Editar evento"
                    @click="empezarEdicion(e)"
                  ><i class="bi bi-pencil"></i></button>
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
              <div v-if="(e.tipo === 'cambio_estado' || e.tipo === 'actividad') && e.descripcion" class="lhs__evento-desc">{{ e.descripcion }}</div>
            </template>
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
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { em, sm, pgm, formatDateTime, TAREAS_LOTE } from '../../lib/loteHelpers.js'
import EmptyState from '../ui/EmptyState.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'

const props = defineProps({
  eventos:        { type: Array,   required: true },
  loadingEventos: { type: Boolean, default: false },
  canAdmin:       { type: Boolean, default: false },
})
const emit = defineEmits(['delete', 'crear', 'editar'])

const PER_PAGE = 10
const pagina   = ref(1)

// ── Registrar actividad (eventos tipados, backfill) ───────
const CATEGORIAS = [
  { value: 'riego',         label: 'Riego',         emoji: '💧' },
  { value: 'fertilizacion', label: 'Fertilización', emoji: '🌿' },
  { value: 'poda',          label: 'Poda',          emoji: '✂️' },
  { value: 'defoliacion',   label: 'Defoliación',   emoji: '🍃' },
  { value: 'tratamiento',   label: 'Tratamiento',   emoji: '🧪' },
  { value: 'medicion',      label: 'Medición',      emoji: '📏' },
  { value: 'inspeccion',    label: 'Inspección',    emoji: '🔍' },
  { value: 'nota',          label: 'Nota',          emoji: '📝' },
  { value: 'otro',          label: 'Otro',          emoji: '•' },
]
const hoy = new Date().toISOString().split('T')[0]
const formAbierto = ref(false)
const form = ref({ categoria: 'riego', fecha: hoy, descripcion: '', producto: '', ec: null, volumen: null })

// Solo nota/otro exigen texto; las demás se entienden por su categoría + detalle.
const formValido = computed(() =>
  !['nota', 'otro'].includes(form.value.categoria) || form.value.descripcion.trim().length > 0
)
const placeholderDescripcion = computed(() => ({
  riego: 'Detalle (opcional)', fertilizacion: 'Detalle (opcional)',
  poda: '¿Qué podaste? (opcional)', defoliacion: 'Detalle (opcional)',
  tratamiento: 'Producto / plaga tratada', medicion: '¿Qué mediste?',
  inspeccion: 'Observaciones', nota: '¿Qué pasó?', otro: 'Describí la actividad',
}[form.value.categoria] || 'Detalle'))

function abrirForm() {
  form.value = { categoria: 'riego', fecha: hoy, descripcion: '', producto: '', ec: null, volumen: null }
  formAbierto.value = true
}
function cerrarForm() { formAbierto.value = false }

function guardar() {
  if (!formValido.value) return
  const f = form.value
  const metadata = {}
  if (f.ec != null && f.ec !== '')           metadata.ec = Number(f.ec)
  if (f.volumen != null && f.volumen !== '')  metadata.volumen_l = Number(f.volumen)
  if (f.categoria === 'fertilizacion' && f.producto.trim()) metadata.producto = f.producto.trim()

  emit('crear', {
    tipo: 'actividad',
    categoria: f.categoria,
    descripcion: f.descripcion.trim() || null,
    metadata,
    registrado_en: `${f.fecha}T12:00:00`,
  })
  formAbierto.value = false
}

// ── Editar nota/evento manual existente ───────────────────
const editandoId = ref(null)
const editForm   = ref({ descripcion: '', fecha: hoy })

function empezarEdicion(e) {
  formAbierto.value = false   // cerrar el form de alta si estaba abierto
  editandoId.value = e.id
  editForm.value = {
    descripcion: e.descripcion || '',
    fecha: (e.registrado_en || '').slice(0, 10) || hoy,
  }
}
function cancelarEdicion() { editandoId.value = null }

function guardarEdicion(e) {
  // descripción opcional (una actividad puede no tener texto; se puede editar solo la fecha)
  emit('editar', {
    id: e.id,
    descripcion: editForm.value.descripcion.trim() || null,
    registrado_en: `${editForm.value.fecha}T12:00:00`,
  })
  editandoId.value = null
}

// ── Render de actividades ─────────────────────────────────
const CAT_COLOR = {
  riego: '#0891b2', fertilizacion: '#16a34a', poda: '#d97706', defoliacion: '#65a30d',
  tratamiento: '#9333ea', medicion: '#0ea5e9', inspeccion: '#64748b', nota: '#64748b', otro: '#94a3b8',
}
function dotColor(e) {
  if (e.tipo === 'cambio_estado') return '#1b5e20'
  if (e.tipo === 'actividad')     return CAT_COLOR[e.categoria] || '#64748b'
  return '#64748b'
}
function metaDetalle(e) {
  const m = e.metadata || {}
  const parts = []
  if (m.producto)  parts.push(m.producto)
  if (m.ec != null)        parts.push(`EC ${m.ec}`)
  if (m.volumen_l != null) parts.push(`${m.volumen_l}L`)
  return parts.join(' · ')
}

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
.lhs__add { padding: .75rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.lhs__add-btn { background: #f0fdf4; border: 1px dashed #86c98a; color: #15803d; border-radius: 8px; padding: .5rem .85rem; font-size: .8rem; font-weight: 600; cursor: pointer; width: 100%; transition: all .15s; }
.lhs__add-btn:hover { background: #dcfce7; border-style: solid; }
.lhs__form { display: flex; flex-direction: column; gap: .5rem; }
.lhs__form-row { display: flex; gap: .5rem; }
.lhs__form-sel { flex: 1; min-width: 0; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .45rem .55rem; font-size: .82rem; color: #0f172a; background: #fff; }
.lhs__form-date { flex: 1; min-width: 0; }
.lhs__form-input { border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .65rem; font-size: .85rem; color: #0f172a; outline: none; }
.lhs__form-input:focus { border-color: #16a34a; }
.lhs__form-num { width: 90px; flex-shrink: 0; border: 1.5px solid #cbd5e1; border-radius: 8px; padding: .5rem .55rem; font-size: .85rem; color: #0f172a; outline: none; }
.lhs__form-num:focus { border-color: #16a34a; }
.lhs__evento-detalle { color: #64748b; font-weight: 600; }
.lhs__form-actions { display: flex; justify-content: flex-end; gap: .5rem; }
.lhs__form-cancel { background: #fff; border: 1.5px solid #cbd5e1; color: #334155; border-radius: 8px; padding: .4rem .85rem; font-size: .8rem; font-weight: 600; cursor: pointer; }
.lhs__form-save { background: #1b5e20; border: none; color: #fff; border-radius: 8px; padding: .4rem 1rem; font-size: .8rem; font-weight: 700; cursor: pointer; }
.lhs__form-save:disabled { opacity: .5; cursor: not-allowed; }
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
.lhs__edit-btn { background: none; border: none; color: #cbd5e1; cursor: pointer; padding: .1rem .25rem; font-size: .78rem; line-height: 1; border-radius: 5px; transition: all .15s; }
.lhs__edit-btn:hover { color: #2563eb; background: #eff6ff; }
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
