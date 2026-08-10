<template>
  <Teleport to="body">
    <div v-if="show" class="mt-overlay">
      <div class="mt-panel">

        <!-- Header -->
        <div class="mt-header">
          <div class="mt-header-left">
            <div class="mt-header-icon" :style="{ background: tipoActual.bg }">
              <span>{{ tipoActual.emoji }}</span>
            </div>
            <div>
              <h2 class="mt-title">{{ editando ? 'Editar tarea' : 'Nueva tarea' }}</h2>
              <p class="mt-subtitle">Paso {{ currentStep + 1 }} de {{ STEPS.length }} — {{ STEPS[currentStep].label }}</p>
            </div>
          </div>
          <button class="mt-close" @click="$emit('cerrar')">
            <i class="bi bi-x-lg"></i>
          </button>
        </div>

        <!-- Stepper -->
        <div class="mt-stepper">
          <template v-for="(s, i) in STEPS" :key="s.key">
            <div class="mt-step-item"
                 :class="{ 'mt-step--done': i < currentStep, 'mt-step--active': i === currentStep }"
                 @click="i < currentStep && (currentStep = i)">
              <div class="mt-step-dot">
                <i v-if="i < currentStep" class="bi bi-check-lg"></i>
                <span v-else>{{ i + 1 }}</span>
              </div>
              <span class="mt-step-lbl">{{ s.label }}</span>
            </div>
            <div v-if="i < STEPS.length - 1" class="mt-step-line" :class="{ 'mt-step-line--done': i < currentStep }"></div>
          </template>
        </div>

        <!-- Body -->
        <div class="mt-body">

          <!-- ══ PASO 1: ¿A quién? ══ -->
          <template v-if="currentStep === 0">
            <div class="mt-step-head">
              <h3 class="mt-step-title">¿A quién asignás esta tarea?</h3>
              <p class="mt-step-desc">Podés dejarlo sin asignar y hacerlo después.</p>
            </div>

            <div v-if="puedeAsignar">
              <div class="mt-search">
                <i class="bi bi-search mt-search__ico"></i>
                <input v-model="busquedaUsuario" class="mt-search__input"
                       placeholder="Buscar por nombre o rol…" />
              </div>

              <div class="mt-asign-list">
                <div class="mt-asign-card"
                     :class="{ 'mt-asign-card--active': !form.asignada_a_id }"
                     @click="seleccionarUsuario(null)">
                  <div class="mt-asign-avatar mt-asign-avatar--none">
                    <i class="bi bi-person-dash"></i>
                  </div>
                  <div class="mt-asign-info">
                    <div class="mt-asign-nombre">Sin asignar</div>
                    <div class="mt-asign-rol">Asignar después</div>
                  </div>
                  <div v-if="!form.asignada_a_id" class="mt-asign-check"><i class="bi bi-check-lg"></i></div>
                </div>

                <div v-for="u in usuariosFiltrados" :key="u.id"
                     class="mt-asign-card"
                     :class="{ 'mt-asign-card--active': String(form.asignada_a_id) === String(u.id) }"
                     @click="seleccionarUsuario(u)">
                  <div class="mt-asign-avatar" :style="{ background: avatarColor(u.id) }">
                    {{ iniciales(u) }}
                  </div>
                  <div class="mt-asign-info">
                    <div class="mt-asign-nombre">{{ `${u.first_name} ${u.last_name}`.trim() }}</div>
                    <div class="mt-asign-rol">{{ u.role }}</div>
                  </div>
                  <div v-if="String(form.asignada_a_id) === String(u.id)" class="mt-asign-check">
                    <i class="bi bi-check-lg"></i>
                  </div>
                </div>

                <p v-if="!usuariosFiltrados.length" class="mt-hint">Sin resultados.</p>
              </div>
            </div>

            <div v-else class="mt-info-box">
              <i class="bi bi-info-circle-fill"></i>
              La tarea se creará sin asignar a un miembro específico.
            </div>
          </template>

          <!-- ══ PASO 2: ¿Qué tarea? ══ -->
          <template v-if="currentStep === 1">
            <div class="mt-step-head">
              <h3 class="mt-step-title">¿Qué hay que hacer?</h3>
            </div>

            <!-- Tipo -->
            <div class="mt-field">
              <label class="mt-label">Tipo de tarea</label>
              <div class="mt-tipos">
                <button v-for="t in TIPOS" :key="t.value" type="button"
                        class="mt-tipo"
                        :class="{ 'mt-tipo--active': form.tipo === t.value }"
                        :style="form.tipo === t.value ? { background: t.bg, borderColor: '#1b5e20' } : {}"
                        @click="form.tipo = t.value">
                  <span class="mt-tipo-emoji">{{ t.emoji }}</span>
                  <span class="mt-tipo-label">{{ t.label }}</span>
                </button>
              </div>
            </div>

            <!-- Título -->
            <div class="mt-field">
              <label class="mt-label">Título <span class="mt-opt">opcional</span></label>
              <input v-model="form.titulo" class="mt-input"
                     :placeholder="`${tipoActual.label}${salaSeleccionada ? ' — ' + salaSeleccionada.nombre : ''}`" />
            </div>

            <!-- Prioridad -->
            <div class="mt-field">
              <label class="mt-label">Prioridad</label>
              <div class="mt-prioridades">
                <button v-for="p in PRIORIDADES" :key="p.value" type="button"
                        class="mt-prioridad"
                        :class="{ 'mt-prioridad--active': form.prioridad === p.value }"
                        :style="form.prioridad === p.value ? { background: p.bg, borderColor: p.color, color: p.color } : {}"
                        @click="form.prioridad = p.value">
                  <span>{{ p.dot }}</span><span>{{ p.label }}</span>
                </button>
              </div>
            </div>

            <!-- Ubicación -->
            <div class="mt-divider"><span>Ubicación</span></div>

            <template v-if="!mostrarSala">
              <button type="button" class="mt-sala-toggle" @click="mostrarSala = true">
                <i class="bi bi-plus-circle"></i>
                Asignar sala
                <span class="mt-sala-toggle__opt">opcional</span>
              </button>
            </template>
            <template v-else>
              <div class="mt-field">
                <label class="mt-label">
                  Sala
                  <button type="button" class="mt-sala-quitar" @click="mostrarSala = false; form.sala_id = ''; form.lote_id = ''">quitar</button>
                </label>
                <div v-if="form.asignada_a_id && !cargandoSalas && salasDisponibles.length === 0"
                     class="mt-hint-warn">
                  Este usuario no tiene salas disponibles en su sede asignada.
                </div>
                <select v-else v-model="form.sala_id" class="mt-input" @change="form.lote_id = ''"
                        :disabled="cargandoSalas">
                  <option value="">{{ cargandoSalas ? 'Cargando…' : 'Sin sala específica' }}</option>
                  <option v-for="s in salasDisponibles" :key="s.id" :value="s.id">{{ s.nombre }}</option>
                </select>
              </div>
              <div v-if="form.sala_id" class="mt-field">
                <label class="mt-label">Lote <span class="mt-opt">opcional</span></label>
                <select v-model="form.lote_id" class="mt-input">
                  <option value="">Sin lote específico</option>
                  <option v-for="l in lotesDeLaSala" :key="l.id" :value="l.id">{{ l.codigo }} — {{ l.estado }}</option>
                </select>
              </div>
            </template>

            <!-- Descripción -->
            <div class="mt-field">
              <label class="mt-label">Descripción <span class="mt-opt">opcional</span></label>
              <textarea v-model="form.descripcion" class="mt-input mt-textarea" rows="2"
                        placeholder="Instrucciones, observaciones…"></textarea>
            </div>
          </template>

          <!-- ══ PASO 3: ¿Cuándo? ══ -->
          <template v-if="currentStep === 2">
            <div class="mt-step-head">
              <h3 class="mt-step-title">¿Cuándo hay que hacerlo?</h3>
            </div>

            <!-- Fecha -->
            <div class="mt-field">
              <label class="mt-label">{{ conRepeticion ? 'Fecha de inicio' : 'Fecha' }}</label>
              <AppDatePicker v-model="form.fecha_programada" />
            </div>

            <!-- Toggle única / recurrente -->
            <div class="mt-modo-tabs">
              <button type="button" class="mt-modo-tab"
                      :class="{ 'mt-modo-tab--active': !conRepeticion }"
                      @click="conRepeticion = false">
                <i class="bi bi-1-circle-fill"></i> Tarea única
              </button>
              <button type="button" class="mt-modo-tab"
                      :class="{ 'mt-modo-tab--active': conRepeticion }"
                      @click="conRepeticion = true">
                <i class="bi bi-arrow-repeat"></i> Se repite
              </button>
            </div>

            <!-- Días de repetición -->
            <div v-if="conRepeticion" class="mt-recur-fields">
              <div class="mt-field">
                <label class="mt-label">Días</label>
                <div class="mt-dias-row">
                  <button v-for="d in DIAS_SEMANA" :key="d.v" type="button"
                          class="mt-dia-btn"
                          :class="{ 'mt-dia-btn--active': repeticion.dias.includes(d.v) }"
                          @click="toggleDia(d.v)">
                    {{ d.l }}
                  </button>
                </div>
              </div>

              <div class="mt-field">
                <label class="mt-label">Hasta</label>
                <AppDatePicker v-model="repeticion.hasta" :min="form.fecha_programada" />
              </div>
            </div>

            <!-- Preview — siempre visible, es lo más prominente -->
            <div class="mt-preview" :class="{ 'mt-preview--warn': previewWarn }">
              <div class="mt-preview__header">
                <span class="mt-preview__ico">{{ previewWarn ? '⚠️' : '📅' }}</span>
                <span class="mt-preview__titulo">{{ previewTitulo }}</span>
              </div>
              <div v-if="!previewWarn && !conRepeticion" class="mt-preview__fecha-unica">
                {{ form.fecha_programada ? formatFechaLarga(form.fecha_programada) : '—' }}
              </div>
              <div v-if="!previewWarn && conRepeticion && fechasGeneradas.length" class="mt-preview__chips">
                <span v-for="(f, i) in fechasGeneradas.slice(0, 10)" :key="i" class="mt-fecha-chip">
                  {{ formatFechaCorta(f) }}
                </span>
                <span v-if="fechasGeneradas.length > 10" class="mt-fecha-chip mt-fecha-chip--more">
                  +{{ fechasGeneradas.length - 10 }} más
                </span>
              </div>
            </div>

          </template>

          <!-- Error -->
          <div v-if="errorGlobal" class="mt-error">
            <i class="bi bi-exclamation-triangle-fill"></i> {{ errorGlobal }}
          </div>

        </div>

        <!-- Footer -->
        <div class="mt-footer">
          <button class="mt-btn-ghost" @click="retroceder">
            {{ currentStep === 0 ? 'Cancelar' : '← Atrás' }}
          </button>
          <button v-if="currentStep < STEPS.length - 1"
                  class="mt-btn-primary"
                  @click="currentStep++">
            Siguiente →
          </button>
          <button v-else class="mt-btn-primary" @click="guardar" :disabled="guardando">
            <DsSpinner v-if="guardando" :size="14" />
            <i v-else class="bi bi-check-lg"></i>
            {{ editando ? 'Guardar cambios' : conRepeticion ? `Crear ${fechasGeneradas.length || 1} tareas` : 'Crear tarea' }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useModalEscape } from '../composables/useModalEscape.js'
import { useAuthStore } from '../stores/auth'
import { useTareasStore } from '../stores/tareas'
import { formatFechaCorta, formatFechaLarga } from '../utils/fecha.js'
import { getUserSalasAsignadas } from '../lib/api.js'
import AppDatePicker from './ui/AppDatePicker.vue'
import DsSpinner from '../design-system/components/Spinner.vue'

const props = defineProps({
  show:         { type: Boolean, default: false },
  tareaInicial: { type: Object,  default: null },
  salas:        { type: Array,   default: () => [] },
  lotes:        { type: Array,   default: () => [] },
  usuarios:     { type: Array,   default: () => [] },
})
const emit = defineEmits(['guardada', 'cerrar'])
useModalEscape(() => emit('cerrar'))

const authStore   = useAuthStore()
const tareasStore = useTareasStore()
const guardando      = ref(false)
const errorGlobal    = ref('')
const currentStep    = ref(0)
const conRepeticion  = ref(false)
const busquedaUsuario = ref('')
const mostrarSala    = ref(false)
const repeticion     = ref({ dias: [], hasta: '' })

const STEPS = [
  { key: 'asignacion', label: 'Asignación' },
  { key: 'tarea',      label: 'Tarea' },
  { key: 'horario',    label: 'Horario' },
]

const TIPOS = [
  { value: 'riego',       label: 'Riego',      emoji: '💧', bg: '#e8f5e9' },
  { value: 'poda',        label: 'Poda',       emoji: '✂️', bg: '#f3e5f5' },
  { value: 'medicion',    label: 'Medición',   emoji: '📏', bg: '#e0f7fa' },
  { value: 'limpieza',    label: 'Limpieza',   emoji: '🧹', bg: '#e8f5e9' },
  { value: 'cosecha',     label: 'Cosecha',    emoji: '🌿', bg: '#dcedc8' },
  { value: 'trasplante', label: 'Trasplante', emoji: '🪴', bg: '#fff8e1' },
  { value: 'inspeccion',  label: 'Inspección', emoji: '🔍', bg: '#fff3e0' },
  { value: 'otro',        label: 'Otro',       emoji: '📋', bg: '#f1f8e9' },
]

const PRIORIDADES = [
  { value: 'baja',    label: 'Baja',    dot: '🟢', color: '#15803d', bg: '#f0fdf4' },
  { value: 'normal',  label: 'Normal',  dot: '🔵', color: '#0369a1', bg: '#eff6ff' },
  { value: 'alta',    label: 'Alta',    dot: '🟠', color: '#d97706', bg: '#fffbeb' },
  { value: 'urgente', label: 'Urgente', dot: '🔴', color: '#dc2626', bg: '#fef2f2' },
]

const DIAS_SEMANA = [
  { v: 1, l: 'L' }, { v: 2, l: 'M' }, { v: 3, l: 'M' },
  { v: 4, l: 'J' }, { v: 5, l: 'V' }, { v: 6, l: 'S' }, { v: 0, l: 'D' },
]

const AVATAR_COLORS = ['#1b5e20','#0369a1','#7c3aed','#b45309','#0891b2','#dc2626','#0f766e']
function avatarColor(id) { return AVATAR_COLORS[(id || 0) % AVATAR_COLORS.length] }
function iniciales(u) { return ((u.first_name?.[0] || '') + (u.last_name?.[0] || '')).toUpperCase() || '?' }

const editando     = computed(() => !!props.tareaInicial?.id)
const puedeAsignar = computed(() => ['admin', 'cultivador', 'supervisor'].includes(authStore.user?.role))
const tipoActual   = computed(() => TIPOS.find(t => t.value === form.value.tipo) || TIPOS[0])

const salasDelUsuario  = ref([])
const cargandoSalas    = ref(false)

const salasDisponibles = computed(() => {
  if (!form.value.asignada_a_id) return props.salas
  if (cargandoSalas.value) return []
  const ids = salasDelUsuario.value.map(s => String(s.id))
  return props.salas.filter(s => ids.includes(String(s.id)))
})
const lotesDeLaSala    = computed(() => props.lotes.filter(l => String(l.sala_id) === String(form.value.sala_id)))
const salaSeleccionada = computed(() => props.salas.find(s => String(s.id) === String(form.value.sala_id)) || null)
const usuariosFiltrados = computed(() => {
  const q = busquedaUsuario.value.trim().toLowerCase()
  if (!q) return props.usuarios
  return props.usuarios.filter(u =>
    `${u.first_name} ${u.last_name}`.toLowerCase().includes(q) ||
    (u.role || '').toLowerCase().includes(q)
  )
})

function toggleDia(v) {
  const idx = repeticion.value.dias.indexOf(v)
  if (idx === -1) repeticion.value.dias.push(v)
  else repeticion.value.dias.splice(idx, 1)
}

function retroceder() {
  if (currentStep.value > 0) currentStep.value--
  else emit('cerrar')
}

const fechasGeneradas = computed(() => {
  if (!conRepeticion.value || !form.value.fecha_programada) return []
  if (!repeticion.value.dias.length || !repeticion.value.hasta) return []
  const fechas = []
  const fin    = new Date(repeticion.value.hasta + 'T00:00:00')
  const cur    = new Date(form.value.fecha_programada + 'T00:00:00')
  while (cur <= fin && fechas.length < 365) {
    if (repeticion.value.dias.includes(cur.getDay()))
      fechas.push(cur.toISOString().split('T')[0])
    cur.setDate(cur.getDate() + 1)
  }
  return fechas
})

const previewWarn = computed(() =>
  conRepeticion.value && (!repeticion.value.dias.length || !repeticion.value.hasta)
)
const previewTitulo = computed(() => {
  if (previewWarn.value) {
    if (!repeticion.value.dias.length) return 'Elegí al menos un día para ver el preview'
    return 'Elegí una fecha de fin para ver el preview'
  }
  if (!conRepeticion.value) return 'Se creará 1 tarea:'
  return `Se crearán ${fechasGeneradas.value.length} tareas:`
})

function formVacio() {
  return {
    titulo: '', descripcion: '', tipo: 'riego', prioridad: 'normal',
    asignada_a_id: '', sala_id: '', lote_id: '',
    fecha_programada: new Date().toISOString().split('T')[0],
  }
}
const form = ref(formVacio())

async function seleccionarUsuario(u) {
  const uid = u ? (String(form.value.asignada_a_id) === String(u.id) ? '' : u.id) : ''
  form.value.asignada_a_id = uid
  form.value.sala_id = ''
  form.value.lote_id = ''
  salasDelUsuario.value = []
  if (!uid) return
  cargandoSalas.value = true
  try {
    const res = await getUserSalasAsignadas(uid)
    salasDelUsuario.value = Array.isArray(res.data) ? res.data : (res.data?.data || [])
  } catch {
  } finally {
    cargandoSalas.value = false
  }
}

watch(() => props.show, (val) => {
  if (!val) return
  errorGlobal.value     = ''
  currentStep.value     = 0
  conRepeticion.value   = false
  busquedaUsuario.value = ''
  salasDelUsuario.value = []
  repeticion.value      = { dias: [], hasta: '' }
  if (props.tareaInicial) {
    const t = props.tareaInicial
    const tieneSala = !!(t.sala_id || t.sala?.id)
    mostrarSala.value = tieneSala
    form.value = {
      titulo:           t.titulo || '',
      descripcion:      t.descripcion || '',
      tipo:             t.tipo || 'riego',
      prioridad:        t.prioridad || 'normal',
      asignada_a_id:    t.asignada_a?.id || '',
      sala_id:          t.sala_id || t.sala?.id || '',
      lote_id:          t.lote_id || t.lote?.id || '',
      fecha_programada: t.fecha_programada || new Date().toISOString().split('T')[0],
    }
  } else {
    mostrarSala.value = false
    form.value = formVacio()
  }
})

async function guardar() {
  errorGlobal.value = ''
  const tipoLabel  = TIPOS.find(t => t.value === form.value.tipo)?.label || 'Tarea'
  const salaNombre = salaSeleccionada.value?.nombre || ''
  const payload = {
    ...form.value,
    titulo:        form.value.titulo?.trim() || (tipoLabel + (salaNombre ? ` — ${salaNombre}` : '')),
    asignada_a_id: form.value.asignada_a_id || null,
    sala_id:       form.value.sala_id || null,
    lote_id:       form.value.lote_id || null,
  }

  guardando.value = true
  try {
    if (editando.value) {
      const res = await tareasStore.update(props.tareaInicial.id, payload)
      emit('guardada', res)
    } else if (conRepeticion.value) {
      if (!fechasGeneradas.value.length) {
        errorGlobal.value = 'Seleccioná al menos un día y una fecha de fin'
        guardando.value = false
        return
      }
      const tareas = await Promise.all(
        fechasGeneradas.value.map(fecha =>
          tareasStore.create({ ...payload, fecha_programada: fecha })
        )
      )
      emit('guardada', tareas[0])
    } else {
      const res = await tareasStore.create(payload)
      emit('guardada', res)
    }
  } catch (e) {
    const msgs = e.response?.data?.errors
    errorGlobal.value = msgs ? msgs.join(', ') : (e.response?.data?.error || 'Error al guardar')
  } finally {
    guardando.value = false
  }
}
</script>

<style scoped>
/* ── Overlay & Panel ── */
.mt-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 2000; padding: 1rem; backdrop-filter: blur(4px);
}
.mt-panel {
  background: #fff; border-radius: 20px;
  width: 100%; max-width: 520px; max-height: 90vh;
  overflow: hidden; display: flex; flex-direction: column;
  box-shadow: 0 28px 64px rgba(0,0,0,.18);
}

/* ── Header ── */
.mt-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.1rem 1.25rem; border-bottom: 1px solid #e8f0e9;
  gap: .75rem; flex-shrink: 0;
}
.mt-header-left { display: flex; align-items: center; gap: .75rem; min-width: 0; }
.mt-header-icon {
  width: 40px; height: 40px; border-radius: 11px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.2rem; flex-shrink: 0; transition: background .2s;
}
.mt-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; line-height: 1.2; }
.mt-subtitle { font-size: .7rem; color: #60725d; margin: .1rem 0 0; }
.mt-close {
  background: #f1f5f1; border: none; width: 30px; height: 30px;
  border-radius: 8px; cursor: pointer; display: flex;
  align-items: center; justify-content: center; color: var(--c-slate-500);
  font-size: .8rem; flex-shrink: 0; transition: all .15s;
}
.mt-close:hover { background: #c8e6c9; color: #1b5e20; }

/* ── Stepper ── */
.mt-stepper {
  display: flex; align-items: center; padding: .875rem 1.5rem;
  border-bottom: 1px solid #f1f5f1; gap: 0; flex-shrink: 0;
}
.mt-step-item {
  display: flex; align-items: center; gap: .45rem; cursor: default;
}
.mt-step-item.mt-step--done { cursor: pointer; }
.mt-step-dot {
  width: 26px; height: 26px; border-radius: 50%; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  font-size: .72rem; font-weight: 800;
  background: #f1f5f1; color: var(--c-slate-400);
  border: 1.5px solid var(--c-slate-200); transition: all .2s;
}
.mt-step--active .mt-step-dot {
  background: #1b5e20; color: #fff; border-color: #1b5e20;
  box-shadow: 0 0 0 3px rgba(27,94,32,.15);
}
.mt-step--done .mt-step-dot {
  background: #e8f5e9; color: #1b5e20; border-color: #a5d6a7;
}
.mt-step-lbl {
  font-size: .72rem; font-weight: 600; color: var(--c-slate-400); white-space: nowrap;
  transition: color .2s;
}
.mt-step--active .mt-step-lbl { color: #1b5e20; font-weight: 700; }
.mt-step--done .mt-step-lbl { color: #4caf50; }
.mt-step-line {
  flex: 1; height: 2px; background: var(--c-slate-200); margin: 0 .5rem; min-width: 20px;
  transition: background .2s;
}
.mt-step-line--done { background: #a5d6a7; }

/* ── Body ── */
.mt-body {
  padding: 1.25rem 1.5rem; overflow-y: auto;
  display: flex; flex-direction: column; gap: 1rem; flex: 1;
}

/* ── Step heading ── */
.mt-step-head { margin-bottom: .25rem; }
.mt-step-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0 0 .2rem; }
.mt-step-desc  { font-size: .78rem; color: #60725d; margin: 0; }

/* ── Fields ── */
.mt-field { display: flex; flex-direction: column; gap: .4rem; }
.mt-label { font-size: .7rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .05em; }
.mt-opt   { font-size: .67rem; font-weight: 400; color: var(--c-slate-400); text-transform: none; letter-spacing: 0; }
.mt-hint  { font-size: .72rem; color: var(--c-slate-400); margin: 0; }
.mt-row   { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; }
@media (max-width: 440px) { .mt-row { grid-template-columns: 1fr; } }

/* ── Inputs ── */
.mt-input {
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px;
  padding: .65rem .9rem; font-size: .875rem; color: #1a1a1a;
  width: 100%; box-sizing: border-box; outline: none;
  transition: border .15s, background .15s;
}
.mt-input:focus { border-color: #1b5e20; background: #fff; }
.mt-input--sm { padding: .55rem .85rem; font-size: .85rem; }
.mt-textarea { resize: vertical; min-height: 60px; }
.mt-input-group { display: flex; }
.mt-input-group .mt-input { border-radius: 10px 0 0 10px; }
.mt-input-suffix {
  background: #e8f0e9; border: 1.5px solid #d4e6d4; border-left: none;
  padding: .65rem .85rem; font-size: .8rem; font-weight: 600;
  color: #60725d; border-radius: 0 10px 10px 0; white-space: nowrap;
}

/* ── Tipo ── */
.mt-tipos { display: grid; grid-template-columns: repeat(4, 1fr); gap: .45rem; }
@media (max-width: 440px) { .mt-tipos { grid-template-columns: repeat(2, 1fr); } }
.mt-tipo {
  display: flex; flex-direction: column; align-items: center; gap: .3rem;
  padding: .7rem .3rem; background: #f4f8f4; border: 1.5px solid #d4e6d4;
  border-radius: 11px; cursor: pointer; transition: all .15s;
}
.mt-tipo:hover { border-color: #66bb6a; background: #e8f5e9; }
.mt-tipo--active { box-shadow: 0 2px 8px rgba(27,94,32,.14); transform: translateY(-1px); }
.mt-tipo-emoji { font-size: 1.3rem; }
.mt-tipo-label { font-size: .65rem; font-weight: 600; color: #1a1a1a; text-align: center; line-height: 1.2; }

/* ── Prioridad ── */
.mt-prioridades { display: flex; gap: .4rem; flex-wrap: wrap; }
.mt-prioridad {
  display: flex; align-items: center; gap: .35rem;
  padding: .45rem .875rem; border: 1.5px solid #d4e6d4;
  border-radius: 999px; background: #f4f8f4;
  font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s;
}
.mt-prioridad:hover { border-color: #66bb6a; }
.mt-prioridad--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.08); }

/* ── Divider ── */
.mt-divider { display: flex; align-items: center; gap: .75rem; }
.mt-divider::before, .mt-divider::after { content: ''; flex: 1; height: 1px; background: #e8f0e9; }
.mt-divider span { font-size: .65rem; font-weight: 700; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .07em; white-space: nowrap; }

/* ── Info box ── */
.mt-info-box { display: flex; align-items: center; gap: .6rem; background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; padding: .75rem 1rem; border-radius: 10px; font-size: .82rem; }
.mt-hint-warn { background: #fffbeb; border: 1px solid #fde68a; color: #92400e; padding: .65rem .9rem; border-radius: 10px; font-size: .8rem; line-height: 1.4; }

/* ── Buscador ── */
.mt-search {
  position: relative; margin-bottom: .65rem;
}
.mt-search__ico {
  position: absolute; left: .8rem; top: 50%; transform: translateY(-50%);
  color: var(--c-slate-400); font-size: .8rem; pointer-events: none;
}
.mt-search__input {
  width: 100%; box-sizing: border-box;
  background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 10px;
  padding: .6rem .9rem .6rem 2.2rem; font-size: .875rem; color: #1a1a1a;
  outline: none; transition: border .15s, background .15s;
}
.mt-search__input:focus { border-color: #1b5e20; background: #fff; }
.mt-search__input::placeholder { color: var(--c-slate-400); }

/* ── Asignación (step 1) ── */
.mt-asign-list { display: flex; flex-direction: column; gap: .4rem; }
.mt-asign-card {
  display: flex; align-items: center; gap: .75rem;
  padding: .7rem 1rem; border: 1.5px solid var(--c-slate-200);
  border-radius: 12px; cursor: pointer; transition: all .15s; background: #fafbfc;
}
.mt-asign-card:hover { border-color: #c8e6c9; background: #f0fdf4; }
.mt-asign-card--active { border-color: #1b5e20; background: #f0fdf4; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.mt-asign-avatar {
  width: 38px; height: 38px; border-radius: 10px; flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-size: .78rem; font-weight: 800;
}
.mt-asign-avatar--none { background: var(--c-slate-200); color: var(--c-slate-400); font-size: 1rem; }
.mt-asign-info { flex: 1; min-width: 0; }
.mt-asign-nombre { font-size: .875rem; font-weight: 600; color: var(--c-slate-900); }
.mt-asign-rol    { font-size: .7rem; color: var(--c-slate-500); text-transform: capitalize; }
.mt-asign-check {
  width: 22px; height: 22px; border-radius: 50%; background: #1b5e20;
  color: #fff; display: flex; align-items: center; justify-content: center;
  font-size: .7rem; flex-shrink: 0;
}

/* ── Sala toggle (step 2) ── */
.mt-sala-toggle {
  display: inline-flex; align-items: center; gap: .45rem;
  background: none; border: 1.5px dashed #a5d6a7; border-radius: 10px;
  padding: .6rem 1rem; font-size: .82rem; font-weight: 600; color: #1b5e20;
  cursor: pointer; width: 100%; transition: all .15s;
}
.mt-sala-toggle:hover { background: #f0fdf4; border-color: #66bb6a; }
.mt-sala-toggle__opt { font-size: .67rem; font-weight: 400; color: var(--c-slate-400); }
.mt-sala-quitar {
  background: none; border: none; padding: 0; margin-left: auto;
  font-size: .65rem; font-weight: 600; color: var(--c-slate-400); cursor: pointer;
  text-transform: uppercase; letter-spacing: .04em;
}
.mt-sala-quitar:hover { color: #dc2626; }

/* ── Paso 3 — Horario ── */
.mt-input--fecha { font-size: .95rem; font-weight: 600; }

/* Segmented toggle: única / se repite */
.mt-modo-tabs {
  display: flex; gap: 0; background: #f4f8f4; border: 1.5px solid #d4e6d4;
  border-radius: 11px; padding: 3px; overflow: clip;
}
.mt-modo-tab {
  flex: 1; display: flex; align-items: center; justify-content: center; gap: .4rem;
  padding: .55rem .5rem; border: none; border-radius: 8px;
  background: transparent; font-size: .8rem; font-weight: 600; color: #60725d;
  cursor: pointer; transition: all .15s;
}
.mt-modo-tab--active {
  background: #fff; color: #1b5e20;
  box-shadow: 0 1px 4px rgba(0,0,0,.10);
}
.mt-modo-tab:hover:not(.mt-modo-tab--active) { color: #1b5e20; }

/* Contenedor campos recurrencia */
.mt-recur-fields { display: flex; flex-direction: column; gap: 1rem; }

/* Días de la semana */
.mt-dias-row { display: flex; justify-content: space-between; gap: .25rem; }
.mt-dia-btn {
  width: 38px; height: 38px; border-radius: 50%; flex-shrink: 0;
  border: 1.5px solid #d4e6d4; background: #f4f8f4;
  font-size: .75rem; font-weight: 700; color: var(--c-slate-400);
  cursor: pointer; transition: all .15s;
  display: flex; align-items: center; justify-content: center;
}
.mt-dia-btn:hover { border-color: #66bb6a; color: #1b5e20; background: #e8f5e9; }
.mt-dia-btn--active {
  background: #1b5e20; border-color: #1b5e20; color: #fff;
  box-shadow: 0 2px 8px rgba(27,94,32,.3);
}

/* Preview — prominente, siempre visible */
.mt-preview {
  background: #e8f5e9; border: 1.5px solid #a5d6a7; border-radius: 14px;
  padding: 1rem 1.1rem; display: flex; flex-direction: column; gap: .65rem;
  transition: background .2s, border-color .2s;
}
.mt-preview--warn {
  background: #fffde7; border-color: #ffe082;
}
.mt-preview__header { display: flex; align-items: center; gap: .5rem; }
.mt-preview__ico { font-size: 1.1rem; }
.mt-preview__titulo { font-size: .82rem; font-weight: 700; color: #1b5e20; }
.mt-preview--warn .mt-preview__titulo { color: #b45309; }
.mt-preview__fecha-unica { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; padding-left: 1.6rem; }
.mt-preview__chips { display: flex; flex-wrap: wrap; gap: .3rem; padding-left: 1.6rem; }
.mt-fecha-chip {
  font-size: .68rem; font-weight: 600; color: #1b5e20;
  background: #c8e6c9; border: 1px solid #a5d6a7;
  padding: .2em .6em; border-radius: 6px;
}
.mt-fecha-chip--more { background: #f1f8e9; color: #60725d; border-color: #d4e6d4; }

/* ── Error ── */
.mt-error {
  background: #ffebee; border: 1.5px solid #ffcdd2; color: #b71c1c;
  padding: .75rem 1rem; border-radius: 10px; font-size: .85rem;
  display: flex; align-items: center; gap: .5rem;
}

/* ── Footer ── */
.mt-footer {
  display: flex; justify-content: space-between; gap: .75rem;
  padding: 1rem 1.25rem; border-top: 1px solid #e8f0e9;
  position: sticky; bottom: 0; background: #fff;
  border-radius: 0 0 20px 20px; flex-shrink: 0;
}
.mt-btn-ghost {
  background: transparent; color: #60725d; border: 1.5px solid #d4e6d4;
  padding: .65rem 1.1rem; border-radius: 10px;
  font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s;
}
.mt-btn-ghost:hover { background: #e8f0e9; color: #1b5e20; border-color: #a5d6a7; }
.mt-btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #1b5e20; color: #fff; border: none;
  padding: .65rem 1.4rem; border-radius: 10px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  white-space: nowrap; transition: background .15s; margin-left: auto;
}
.mt-btn-primary:hover:not(:disabled) { background: #104417; }
.mt-btn-primary:disabled { opacity: .6; cursor: not-allowed; }
</style>
