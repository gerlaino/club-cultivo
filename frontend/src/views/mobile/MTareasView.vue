<template>
  <div class="mta">
    <div class="mta__topbar">
      <h1 class="mta__title">Tareas</h1>
      <div class="mta__topbar-acciones">
        <button v-if="hayCompletables" class="mta__sel-toggle" @click="alternarModoSeleccion">
          {{ modoSeleccion ? 'Cancelar' : 'Seleccionar' }}
        </button>
        <button v-if="!modoSeleccion" class="mta__fab" @click="showCreate = true">
          <i class="bi bi-plus-lg"></i>
        </button>
      </div>
    </div>

    <!-- Strip 7 días -->
    <div class="mta__strip">
      <button
        v-for="dia in dias"
        :key="dia.fecha"
        class="mta__dia"
        :class="{
          'mta__dia--hoy': dia.esHoy,
          'mta__dia--sel': dia.fecha === diaSeleccionado,
        }"
        @click="diaSeleccionado = dia.fecha"
      >
        <span class="mta__dia-nombre">{{ dia.nombreCorto }}</span>
        <span class="mta__dia-num">{{ dia.numero }}</span>
        <span v-if="dia.conteo" class="mta__dia-badge">{{ dia.conteo }}</span>
      </button>
    </div>

    <!-- Barra de acción del modo selección -->
    <div v-if="modoSeleccion" class="mta__bulk">
      <button class="mta__bulk-todas" @click="alternarTodas">
        {{ seleccionadas.size === completablesDelDia.length ? 'Ninguna' : 'Todas' }}
      </button>
      <button class="mta__bulk-ok" :disabled="!seleccionadas.size || bulkEnCurso" @click="completarSeleccionadas">
        {{ bulkEnCurso ? 'Guardando…' : `Marcar ${seleccionadas.size} como hecha${seleccionadas.size === 1 ? '' : 's'}` }}
      </button>
    </div>

    <!-- Tareas del día seleccionado -->
    <div v-if="tareasStore.loading" class="mta__loading">Cargando…</div>
    <div v-else-if="!tareasDelDia.length" class="mta__empty">
      <i class="bi bi-clipboard-check"></i>
      <p>Sin tareas para este día</p>
    </div>
    <div v-else class="mta__list">
      <div
        v-for="t in tareasDelDia"
        :key="t.id + (t._atrasada ? '-a' : '')"
        class="mta__card"
        :class="[`mta__card--${t.prioridad}`, {
          'mta__card--futura': esFutura(t) && t.estado !== 'completada',
          'mta__card--atrasada': t._atrasada,
        }]"
        @click="modoSeleccion ? alternarTarea(t) : abrirCompletarSheet(t)"
      >
        <div class="mta__card-left">
          <span v-if="modoSeleccion && completable(t)" class="mta__sel-box" :class="{ 'mta__sel-box--on': seleccionadas.has(t.id) }">
            <i v-if="seleccionadas.has(t.id)" class="bi bi-check-lg"></i>
          </span>
          <span v-else class="mta__tipo-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
        </div>
        <div class="mta__card-body">
          <div class="mta__card-titulo">{{ t.titulo }}</div>
          <div class="mta__card-meta">
            <span v-if="t._atrasada" class="mta__atrasada">⏰ Atrasada</span>
            <span v-if="t.sala?.nombre" class="mta__sala">{{ t.sala.nombre }}</span>
            <span v-if="t.estado === 'completada'" class="mta__completada-badge">✓ Completada</span>
            <span v-else-if="esFutura(t)" class="mta__prog-badge"><i class="bi bi-clock"></i> Programada</span>
            <span v-else class="mta__prioridad" :class="`mta__prioridad--${t.prioridad}`">
              {{ PRIORIDAD_LABEL[t.prioridad] || t.prioridad }}
            </span>
          </div>
        </div>
        <button
          v-if="t.estado !== 'completada' && !esFutura(t)"
          class="mta__check"
          @click.stop="abrirCompletarSheet(t)"
        >
          <i class="bi bi-check2"></i>
        </button>
        <i v-else-if="t.estado === 'completada'" class="bi bi-check2-all mta__done-icon"></i>
        <i v-else class="bi bi-lock mta__lock-icon"></i>
      </div>
    </div>

    <!-- Sheet: Completar tarea -->
    <SheetBottom v-model="showCompletar" title="Completar tarea">
      <div v-if="tareaActiva" class="mta__sheet-completar">
        <div class="mta__tarea-preview">
          <span class="mta__tipo-emoji-lg">{{ TIPO_EMOJI[tareaActiva.tipo] || '📋' }}</span>
          <div>
            <div class="mta__tarea-titulo">{{ tareaActiva.titulo }}</div>
            <div class="mta__tarea-meta">{{ tareaActiva.sala?.nombre }}</div>
          </div>
        </div>
        <div class="mta__field">
          <label class="mta__label">
            Horas reales <span class="mta__opcional">opcional</span>
          </label>
          <input
            v-model.number="completarForm.horas_reales"
            type="number"
            step="0.5"
            min="0"
            class="mta__input"
            placeholder="ej: 1.5"
          />
        </div>
        <div class="mta__field">
          <label class="mta__label">
            Notas <span class="mta__opcional">opcional</span>
          </label>
          <textarea
            v-model="completarForm.notas_completado"
            class="mta__input mta__textarea"
            rows="3"
            placeholder="Observaciones sobre la tarea…"
          ></textarea>
        </div>
        <div v-if="completarError" class="mta__error">{{ completarError }}</div>
        <button class="mta__btn-primary mta__btn-full" :disabled="completando" @click="confirmarCompletar">
          <i v-if="!completando" class="bi bi-check2-circle"></i>
          {{ completando ? 'Completando…' : 'Marcar como completada' }}
        </button>
      </div>
    </SheetBottom>

    <!-- Sheet: Nueva tarea -->
    <SheetBottom v-model="showCreate" title="Nueva tarea">
      <div class="mta__sheet-form">
        <div class="mta__field">
          <label class="mta__label">Título *</label>
          <input v-model="form.titulo" class="mta__input" placeholder="Ej: Riego sala vegetativo" />
        </div>
        <div class="mta__field">
          <label class="mta__label">Tipo</label>
          <select v-model="form.tipo" class="mta__input">
            <option v-for="tp in TIPOS" :key="tp.value" :value="tp.value">
              {{ tp.emoji }} {{ tp.label }}
            </option>
          </select>
        </div>
        <div class="mta__field">
          <label class="mta__label">Prioridad</label>
          <select v-model="form.prioridad" class="mta__input">
            <option value="baja">Baja</option>
            <option value="media">Media</option>
            <option value="alta">Alta</option>
            <option value="urgente">Urgente</option>
          </select>
        </div>
        <div class="mta__field">
          <label class="mta__label">Fecha programada</label>
          <AppDatePicker v-model="form.fecha_programada" />
        </div>
        <div v-if="createError" class="mta__error">{{ createError }}</div>
        <button class="mta__btn-primary mta__btn-full" :disabled="saving" @click="crearTarea">
          {{ saving ? 'Creando…' : 'Crear tarea' }}
        </button>
      </div>
    </SheetBottom>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import { useSemanaTareas } from '../../composables/useSemanaTareas.js'
import { useToast } from '../../composables/useToast.js'
import { useTareasStore } from '../../stores/tareas'
import SheetBottom        from '../../components/cultivador/SheetBottom.vue'

const tareasStore = useTareasStore()
const toast = useToast()

// ── Calendario ────────────────────────────────────────────────────

function toISO(d) {
  return d.toISOString().split('T')[0]
}

function addDays(d, n) {
  const r = new Date(d)
  r.setDate(r.getDate() + n)
  return r
}

const hoy = new Date()
hoy.setHours(0, 0, 0, 0)

const NOMBRES = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']

// Misma lectura que el escritorio: la tarea vencida y pendiente se arrastra a HOY.
// Antes cada día mostraba sólo lo programado ese día, así que 19 atrasadas quedaban
// escondidas en su día original y hoy aparecía vacío.
const { dias: diasProcesados } = useSemanaTareas(computed(() => tareasStore.semana))

const dias = computed(() => {
  return Array.from({ length: 7 }, (_, i) => {
    const d     = addDays(hoy, i - 3)
    const fecha = toISO(d)
    const diaData = diasProcesados.value.find(x => x.fecha === fecha)
    return {
      fecha,
      esHoy:       i === 3,
      nombreCorto: NOMBRES[d.getDay()],
      numero:      d.getDate(),
      conteo:      diaData?.tareas?.filter(t => t.estado !== 'completada').length || 0,
    }
  })
})

const diaSeleccionado = ref(toISO(hoy))
const hoyISO = toISO(hoy)
// Una tarea programada a futuro no se puede completar todavía (mismo criterio que el desktop).
const esFutura = (t) => !!t.fecha_programada && t.fecha_programada > hoyISO

// ── Marcar varias como hechas ────────────────────────────────────────────────
// Pasa que no se marcaron en el momento y hay que ponerse al día. Se registra con la fecha de
// HOY (es cuando realmente se anotó): el backend ya lo hace así en completar_masivo, y la tarea
// queda marcada como atrasada si venía de antes, en vez de fingir que se hizo el martes.
const modoSeleccion = ref(false)
const seleccionadas = ref(new Set())
const bulkEnCurso   = ref(false)

const completable = (t) => t.estado !== 'completada' && t.estado !== 'cancelada' && !esFutura(t)
const completablesDelDia = computed(() => tareasDelDia.value.filter(completable))
const hayCompletables    = computed(() => completablesDelDia.value.length > 1)

function alternarModoSeleccion() {
  modoSeleccion.value = !modoSeleccion.value
  seleccionadas.value = new Set()
}

function alternarTarea(t) {
  if (!completable(t)) return
  const s = new Set(seleccionadas.value)
  s.has(t.id) ? s.delete(t.id) : s.add(t.id)
  seleccionadas.value = s
}

function alternarTodas() {
  seleccionadas.value = seleccionadas.value.size === completablesDelDia.value.length
    ? new Set()
    : new Set(completablesDelDia.value.map(t => t.id))
}

async function completarSeleccionadas() {
  if (!seleccionadas.value.size) return
  bulkEnCurso.value = true
  try {
    const n = await tareasStore.completarMasivo(Array.from(seleccionadas.value))
    modoSeleccion.value = false
    seleccionadas.value = new Set()
    toast.success(`${n} ${n === 1 ? 'tarea completada' : 'tareas completadas'} ✓`)
    await tareasStore.fetchSemana(toISO(addDays(hoy, -3)))
  } catch (e) {
    toast.error(e?.response?.data?.error || 'No se pudieron completar las tareas')
  } finally {
    bulkEnCurso.value = false
  }
}

const tareasDelDia = computed(() => {
  const diaData = diasProcesados.value.find(x => x.fecha === diaSeleccionado.value)
  const tareas  = diaData?.tareas || []
  return [...tareas].sort((a, b) => {
    const P = { urgente: 0, alta: 1, media: 2, baja: 3 }
    if (a.estado === 'completada' && b.estado !== 'completada') return 1
    if (b.estado === 'completada' && a.estado !== 'completada') return -1
    return (P[a.prioridad] ?? 2) - (P[b.prioridad] ?? 2)
  })
})

// ── Completar tarea ───────────────────────────────────────────────

const showCompletar  = ref(false)
const tareaActiva    = ref(null)
const completando    = ref(false)
const completarError = ref(null)
const completarForm  = ref({ horas_reales: null, notas_completado: '' })

function abrirCompletarSheet(t) {
  if (t.estado === 'completada') return
  if (esFutura(t)) return   // no se completan tareas futuras
  tareaActiva.value    = t
  completarForm.value  = { horas_reales: null, notas_completado: '' }
  completarError.value = null
  showCompletar.value  = true
}

async function confirmarCompletar() {
  completando.value    = true
  completarError.value = null
  try {
    await tareasStore.completar(
      tareaActiva.value.id,
      completarForm.value.horas_reales || undefined,
      completarForm.value.notas_completado || '',
    )
    // Actualizar optimisticamente en semana.dias
    const diaData = diasProcesados.value.find(x => x.fecha === diaSeleccionado.value)
    if (diaData) {
      const idx = diaData.tareas.findIndex(t => t.id === tareaActiva.value.id)
      if (idx !== -1) diaData.tareas[idx] = { ...diaData.tareas[idx], estado: 'completada' }
    }
    showCompletar.value = false
  } catch (e) {
    completarError.value = e?.response?.data?.error || 'Error al completar la tarea'
  } finally { completando.value = false }
}

// ── Nueva tarea ───────────────────────────────────────────────────

const showCreate  = ref(false)
const saving      = ref(false)
const createError = ref(null)
const form = ref({
  titulo:           '',
  tipo:             'riego',
  prioridad:        'media',
  fecha_programada: toISO(hoy),
})

const TIPO_EMOJI = {
  riego:'💧', nutricion:'🌱', poda:'✂️', inspeccion:'🔍',
  cosecha:'🌾', limpieza:'🧹', mantenimiento:'🔧', otro:'📋',
}
const TIPOS = [
  { value:'riego',         label:'Riego',         emoji:'💧' },
  { value:'nutricion',     label:'Nutrición',      emoji:'🌱' },
  { value:'poda',          label:'Poda',           emoji:'✂️' },
  { value:'inspeccion',    label:'Inspección',     emoji:'🔍' },
  { value:'cosecha',       label:'Cosecha',        emoji:'🌾' },
  { value:'limpieza',      label:'Limpieza',       emoji:'🧹' },
  { value:'mantenimiento', label:'Mantenimiento',  emoji:'🔧' },
  { value:'otro',          label:'Otro',           emoji:'📋' },
]
const PRIORIDAD_LABEL = { baja:'Baja', media:'Media', alta:'Alta', urgente:'🔥 Urgente' }

async function crearTarea() {
  if (!form.value.titulo.trim()) { createError.value = 'El título es obligatorio'; return }
  saving.value = true; createError.value = null
  try {
    await tareasStore.create({ ...form.value, estado: 'pendiente' })
    await tareasStore.fetchSemana(toISO(addDays(hoy, -3)))
    showCreate.value = false
    form.value = { titulo: '', tipo: 'riego', prioridad: 'media', fecha_programada: toISO(hoy) }
  } catch {
    createError.value = 'Error al crear la tarea'
  } finally { saving.value = false }
}

onMounted(async () => {
  await tareasStore.fetchSemana(toISO(addDays(hoy, -3)))
})
</script>

<style scoped>
.mta { padding: 0 0 1rem; }

.mta__topbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.2rem 1.1rem .8rem;
}
.mta__title { font-family: var(--font-display, sans-serif); font-size: 1.45rem; font-weight: 700; color: var(--c-ink-900, #1a1d1f); margin: 0; }
.mta__fab {
  width: 40px; height: 40px; border-radius: 12px;
  background: var(--c-leaf-800, #1a3d2e); color: #fff; border: none;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; cursor: pointer; -webkit-tap-highlight-color: transparent;
  transition: transform .12s;
}
.mta__fab:active { transform: scale(.92); }

/* ── Strip 7 días ── */
.mta__strip {
  display: flex; gap: .25rem;
  padding: 0 1rem .875rem;
  border-bottom: 1px solid #e8f0e9;
}
.mta__dia {
  flex: 1; display: flex; flex-direction: column; align-items: center;
  padding: .5rem .25rem; border: 1.5px solid transparent;
  border-radius: 12px; background: none; cursor: pointer;
  transition: all .15s; position: relative;
  -webkit-tap-highlight-color: transparent;
}
.mta__dia--hoy { background: #f0fdf4; border-color: #bbf7d0; }
.mta__dia--sel { background: #1b5e20 !important; border-color: #1b5e20 !important; }
.mta__dia--sel .mta__dia-nombre,
.mta__dia--sel .mta__dia-num { color: #fff !important; }

.mta__dia-nombre {
  font-size: .62rem; font-weight: 700; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .03em;
}
.mta__dia--hoy .mta__dia-nombre { color: #15803d; }
.mta__dia-num { font-size: 1rem; font-weight: 800; color: #0f172a; line-height: 1.2; }
.mta__dia--hoy .mta__dia-num { color: #15803d; }

.mta__dia-badge {
  position: absolute; top: 3px; right: 4px;
  background: #dc2626; color: #fff;
  font-size: .52rem; font-weight: 800;
  width: 14px; height: 14px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
}
.mta__dia--sel .mta__dia-badge { background: rgba(255,255,255,.3); }

/* ── Lista ── */
.mta__loading, .mta__empty {
  display: flex; flex-direction: column; align-items: center;
  gap: .5rem; padding: 3rem 1rem; color: #94a3b8; font-size: .875rem;
}
.mta__empty i { font-size: 2rem; }

.mta__list { display: flex; flex-direction: column; gap: .5rem; padding: .75rem 1rem 0; }

.mta__card {
  display: flex; align-items: center;
  background: #fff; border-radius: 12px;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
  border-left: 4px solid #e2e8f0;
  cursor: pointer; -webkit-tap-highlight-color: transparent;
}
.mta__card--urgente { border-left-color: #dc2626; }
.mta__card--alta    { border-left-color: #f59e0b; }
.mta__card--media   { border-left-color: #3b82f6; }
.mta__card--baja    { border-left-color: #94a3b8; }

.mta__card-left { padding: .75rem .5rem .75rem .75rem; font-size: 1.2rem; flex-shrink: 0; }
.mta__card-body { flex: 1; padding: .75rem .5rem; min-width: 0; }
.mta__card-titulo { font-size: .875rem; font-weight: 600; color: #0f172a; margin-bottom: .2rem; }
.mta__card-meta {
  display: flex; align-items: center; gap: .5rem;
  font-size: .7rem; color: #94a3b8; flex-wrap: wrap;
}
.mta__completada-badge { color: #16a34a; font-weight: 700; }
.mta__prioridad { font-weight: 700; }
.mta__prioridad--urgente { color: #dc2626; }
.mta__prioridad--alta    { color: #d97706; }
.mta__prioridad--media   { color: #3b82f6; }
.mta__prioridad--baja    { color: #94a3b8; }

.mta__check {
  padding: .75rem; color: #94a3b8; background: none;
  border: none; font-size: 1.2rem; cursor: pointer; flex-shrink: 0;
  transition: color .15s;
}
.mta__check:hover { color: #16a34a; }
.mta__done-icon { color: #16a34a; padding: .75rem; font-size: 1rem; flex-shrink: 0; }
.mta__lock-icon { color: #cbd5e1; padding: .75rem; font-size: .95rem; flex-shrink: 0; }
.mta__card--futura { opacity: .62; }
.mta__prog-badge { color: #94a3b8; font-weight: 600; display: inline-flex; align-items: center; gap: .25rem; }

/* ── Sheets ── */
.mta__sheet-completar,
.mta__sheet-form { display: flex; flex-direction: column; gap: .875rem; }

.mta__tarea-preview {
  display: flex; align-items: center; gap: .75rem;
  background: #f8fafc; border-radius: 10px; padding: .875rem;
  margin-bottom: .125rem;
}
.mta__tipo-emoji-lg { font-size: 1.75rem; flex-shrink: 0; }
.mta__tarea-titulo  { font-size: .95rem; font-weight: 700; color: #0f172a; }
.mta__tarea-meta    { font-size: .75rem; color: #64748b; margin-top: .15rem; }

.mta__field { display: flex; flex-direction: column; gap: .3rem; }
.mta__label {
  font-size: .72rem; font-weight: 700; color: #374151;
  text-transform: uppercase; letter-spacing: .04em;
  display: flex; align-items: center; gap: .4rem;
}
.mta__opcional { font-weight: 400; text-transform: none; color: #94a3b8; font-size: .68rem; }
.mta__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 9px; padding: .65rem .875rem;
  font-size: .9rem; color: #0f172a; outline: none;
  width: 100%; box-sizing: border-box;
}
.mta__input:focus { border-color: #1b5e20; }
.mta__textarea { resize: none; font-family: inherit; }

.mta__error {
  background: #fef2f2; color: #dc2626;
  border: 1px solid #fecaca; border-radius: 8px;
  padding: .5rem .75rem; font-size: .8rem;
}
.mta__btn-primary {
  background: #1b5e20; color: #fff; border: none;
  padding: .8rem 1.25rem; border-radius: 9px;
  font-size: .95rem; font-weight: 700; cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: .4rem;
}
.mta__btn-full { width: 100%; }
.mta__btn-primary:disabled { opacity: .6; }
</style>
