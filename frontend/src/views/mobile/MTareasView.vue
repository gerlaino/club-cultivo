<template>
  <div class="mta">
    <div class="mta__topbar">
      <h1 class="mta__title">Tareas</h1>
      <button class="mta__fab" @click="showCreate = true">
        <i class="bi bi-plus-lg"></i>
      </button>
    </div>

    <!-- Tabs estado -->
    <div class="mta__tabs">
      <button v-for="t in TABS" :key="t.value" class="mta__tab"
        :class="{ 'mta__tab--active': tab === t.value }" @click="tab = t.value">
        {{ t.label }}
        <span v-if="conteo[t.value]" class="mta__tab-n">{{ conteo[t.value] }}</span>
      </button>
    </div>

    <div v-if="loading" class="mta__loading">Cargando…</div>
    <div v-else-if="!tareasMostradas.length" class="mta__empty">
      <i class="bi bi-clipboard-check"></i>
      <p>Sin tareas {{ tabLabel }}</p>
    </div>

    <div v-else class="mta__list">
      <div
        v-for="t in tareasMostradas"
        :key="t.id"
        class="mta__card"
        :class="`mta__card--${t.prioridad}`"
        @click="abrirDetalle(t)"
      >
        <div class="mta__card-left">
          <span class="mta__tipo-emoji">{{ TIPO_EMOJI[t.tipo] || '📋' }}</span>
        </div>
        <div class="mta__card-body">
          <div class="mta__card-titulo">{{ t.titulo }}</div>
          <div class="mta__card-meta">
            <span v-if="t.sala?.nombre" class="mta__sala">{{ t.sala.nombre }}</span>
            <span v-if="t.fecha_vencimiento" class="mta__fecha" :class="{ 'mta__fecha--vencida': estaVencida(t) }">
              {{ formatFecha(t.fecha_vencimiento) }}
            </span>
          </div>
        </div>
        <button v-if="t.estado !== 'completada'" class="mta__completar" @click.stop="completar(t)">
          <i class="bi bi-check2"></i>
        </button>
      </div>
    </div>

    <!-- Modal nueva tarea simplificado -->
    <Teleport to="body">
      <div v-if="showCreate" class="mta__modal-overlay" @click.self="showCreate = false">
        <div class="mta__modal">
          <div class="mta__modal-header">
            <h3 class="mta__modal-title">Nueva tarea</h3>
            <button class="mta__modal-close" @click="showCreate = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="mta__modal-body">
            <div class="mta__field">
              <label class="mta__label">Título</label>
              <input v-model="form.titulo" class="mta__input" placeholder="Ej: Riego sala vegetativo" />
            </div>
            <div class="mta__field">
              <label class="mta__label">Tipo</label>
              <select v-model="form.tipo" class="mta__input">
                <option v-for="tp in TIPOS" :key="tp.value" :value="tp.value">{{ tp.emoji }} {{ tp.label }}</option>
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
              <label class="mta__label">Fecha límite</label>
              <input v-model="form.fecha_vencimiento" type="date" class="mta__input" />
            </div>
            <div v-if="createError" class="mta__error">{{ createError }}</div>
            <div class="mta__modal-actions">
              <button class="mta__btn-ghost" @click="showCreate = false">Cancelar</button>
              <button class="mta__btn-primary" :disabled="saving" @click="crearTarea">
                {{ saving ? 'Creando…' : 'Crear' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useTareasStore } from '../../stores/tareas'
import { useAuthStore }   from '../../stores/auth'

const tareasStore = useTareasStore()
const auth        = useAuthStore()

const tab        = ref('pendiente')
const loading    = ref(false)
const showCreate = ref(false)
const saving     = ref(false)
const createError = ref(null)

const form = ref({ titulo: '', tipo: 'riego', prioridad: 'media', fecha_vencimiento: '' })

const TABS = [
  { value: 'pendiente',    label: 'Pendientes' },
  { value: 'en_progreso',  label: 'En curso' },
  { value: 'completada',   label: 'Completadas' },
]
const TIPO_EMOJI = {
  riego: '💧', nutricion: '🌱', poda: '✂️', inspeccion: '🔍',
  cosecha: '🌾', limpieza: '🧹', mantenimiento: '🔧', otro: '📋',
}
const TIPOS = [
  { value: 'riego',         label: 'Riego',         emoji: '💧' },
  { value: 'nutricion',     label: 'Nutrición',      emoji: '🌱' },
  { value: 'poda',          label: 'Poda',           emoji: '✂️' },
  { value: 'inspeccion',    label: 'Inspección',     emoji: '🔍' },
  { value: 'cosecha',       label: 'Cosecha',        emoji: '🌾' },
  { value: 'limpieza',      label: 'Limpieza',       emoji: '🧹' },
  { value: 'mantenimiento', label: 'Mantenimiento',  emoji: '🔧' },
  { value: 'otro',          label: 'Otro',           emoji: '📋' },
]

const tabLabel = computed(() => TABS.find(t => t.value === tab.value)?.label.toLowerCase() || '')

const todas = computed(() => tareasStore.items || [])
const tareasMostradas = computed(() => todas.value.filter(t => t.estado === tab.value)
  .sort((a, b) => {
    const P = { urgente: 0, alta: 1, media: 2, baja: 3 }
    return (P[a.prioridad] ?? 2) - (P[b.prioridad] ?? 2)
  })
)
const conteo = computed(() => ({
  pendiente:   todas.value.filter(t => t.estado === 'pendiente').length,
  en_progreso: todas.value.filter(t => t.estado === 'en_progreso').length,
  completada:  todas.value.filter(t => t.estado === 'completada').length,
}))

function formatFecha(d) {
  if (!d) return ''
  return new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}
function estaVencida(t) {
  if (!t.fecha_vencimiento || t.estado === 'completada') return false
  return new Date(t.fecha_vencimiento) < new Date()
}

async function completar(tarea) {
  await tareasStore.update?.(tarea.id, { estado: 'completada' })
}

function abrirDetalle(t) { /* abrir detalle inline — por ahora no hace nada extra */ }

async function crearTarea() {
  if (!form.value.titulo.trim()) { createError.value = 'El título es obligatorio'; return }
  saving.value = true; createError.value = null
  try {
    await tareasStore.create?.({ ...form.value, estado: 'pendiente' })
    showCreate.value = false
    form.value = { titulo: '', tipo: 'riego', prioridad: 'media', fecha_vencimiento: '' }
  } catch (e) {
    createError.value = 'Error al crear la tarea'
  } finally { saving.value = false }
}

onMounted(async () => {
  loading.value = true
  await tareasStore.fetchAll?.()
  loading.value = false
})
</script>

<style scoped>
.mta { padding: 0 0 1rem; }
.mta__topbar { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1rem .5rem; }
.mta__title { font-size: 1.1rem; font-weight: 800; color: #0f2417; margin: 0; }
.mta__fab { width: 38px; height: 38px; border-radius: 12px; background: #1b5e20; color: #fff; border: none; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; cursor: pointer; }

.mta__tabs { display: flex; gap: 0; padding: 0 1rem .75rem; border-bottom: 1px solid #e8f0e9; }
.mta__tab { flex: 1; padding: .5rem .25rem; border: none; background: none; font-size: .75rem; font-weight: 600; color: #94a3b8; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: .3rem; border-bottom: 2px solid transparent; margin-bottom: -1px; transition: all .15s; }
.mta__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }
.mta__tab-n { background: #dcfce7; color: #15803d; font-size: .62rem; font-weight: 800; padding: .1em .4em; border-radius: 999px; }

.mta__loading, .mta__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 3rem 1rem; color: #94a3b8; font-size: .875rem; }
.mta__empty i { font-size: 2rem; }

.mta__list { display: flex; flex-direction: column; gap: .5rem; padding: .75rem 1rem 0; }
.mta__card { display: flex; align-items: center; background: #fff; border-radius: 12px; box-shadow: 0 1px 4px rgba(0,0,0,.06); border-left: 4px solid #e2e8f0; cursor: pointer; -webkit-tap-highlight-color: transparent; }
.mta__card--urgente { border-left-color: #dc2626; }
.mta__card--alta    { border-left-color: #f59e0b; }
.mta__card--media   { border-left-color: #3b82f6; }
.mta__card--baja    { border-left-color: #94a3b8; }
.mta__card-left { padding: .75rem .5rem .75rem .75rem; font-size: 1.2rem; flex-shrink: 0; }
.mta__card-body { flex: 1; padding: .75rem .5rem; min-width: 0; }
.mta__card-titulo { font-size: .875rem; font-weight: 600; color: #0f172a; margin-bottom: .2rem; }
.mta__card-meta { display: flex; align-items: center; gap: .5rem; font-size: .7rem; color: #94a3b8; }
.mta__fecha--vencida { color: #dc2626; font-weight: 700; }
.mta__completar { padding: .75rem; color: #94a3b8; background: none; border: none; font-size: 1.2rem; cursor: pointer; flex-shrink: 0; transition: color .15s; }
.mta__completar:hover { color: #16a34a; }

/* Modal */
.mta__modal-overlay { position: fixed; inset: 0; z-index: 200; background: rgba(0,0,0,.5); display: flex; align-items: flex-end; }
.mta__modal { width: 100%; background: #fff; border-radius: 20px 20px 0 0; max-height: 85vh; overflow-y: auto; }
.mta__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; }
.mta__modal-title { font-size: 1rem; font-weight: 700; margin: 0; }
.mta__modal-close { background: none; border: none; font-size: 1rem; color: #94a3b8; cursor: pointer; }
.mta__modal-body { padding: 1.25rem; display: flex; flex-direction: column; gap: .875rem; }
.mta__field { display: flex; flex-direction: column; gap: .3rem; }
.mta__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.mta__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .65rem .875rem; font-size: .9rem; color: #0f172a; outline: none; }
.mta__input:focus { border-color: #1b5e20; }
.mta__error { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; font-size: .8rem; }
.mta__modal-actions { display: flex; gap: .75rem; justify-content: flex-end; }
.mta__btn-primary { background: #1b5e20; color: #fff; border: none; padding: .65rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.mta__btn-primary:disabled { opacity: .6; }
.mta__btn-ghost { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .65rem 1rem; border-radius: 9px; font-size: .875rem; cursor: pointer; }
</style>
