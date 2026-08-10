<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import { getMedicoDisponibilidad, saveMedicoDisponibilidad } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { CheckCircle2, Plus, Trash2, Info, CalendarX2 } from 'lucide-vue-next'

const toast   = useToast()
const loading = ref(true)
const saving  = ref(false)

// ── Config ─────────────────────────────────────────────────────────────────
const H_INI  = 7      // primera hora visible
const H_FIN  = 22     // última hora (exclusive)
const STEP   = 30     // minutos por slot

const DIAS   = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
const SLOTS  = (() => {
  const arr = []
  for (let m = H_INI * 60; m < H_FIN * 60; m += STEP) arr.push(m)
  return arr
})()

function minToStr(m) {
  return `${String(Math.floor(m / 60)).padStart(2,'0')}:${String(m % 60).padStart(2,'0')}`
}

// ── Grid state: grid[dia][slotIdx] = true|false ──────────────────────────
const grid = ref(Array.from({ length: 7 }, () => new Array(SLOTS.length).fill(false)))

// ── Drag state ──────────────────────────────────────────────────────────
const dragging   = ref(false)
const dragMode   = ref(true)   // true = activar, false = desactivar
const dragOrigin = ref(null)   // { dia, slot }
const dragCurrent = ref(null)

function onCellMousedown(dia, slotIdx) {
  dragging.value   = true
  dragMode.value   = !grid.value[dia][slotIdx]  // toggle en sentido del primer click
  dragOrigin.value  = { dia, slot: slotIdx }
  dragCurrent.value = { dia, slot: slotIdx }
  applyDrag(dia, slotIdx)
}

function onCellMouseenter(dia, slotIdx) {
  if (!dragging.value) return
  // Solo drag en la misma columna (día)
  if (dia !== dragOrigin.value.dia) return
  dragCurrent.value = { dia, slot: slotIdx }
  const [from, to] = [dragOrigin.value.slot, slotIdx].sort((a, b) => a - b)
  for (let i = from; i <= to; i++) grid.value[dia][i] = dragMode.value
}

function applyDrag(dia, slotIdx) {
  grid.value[dia][slotIdx] = dragMode.value
}

function stopDrag() {
  dragging.value   = false
  dragOrigin.value  = null
  dragCurrent.value = null
}

onMounted(() => document.addEventListener('mouseup', stopDrag))
onUnmounted(() => document.removeEventListener('mouseup', stopDrag))

// ── Computed helpers ─────────────────────────────────────────────────────
const resumenDia = computed(() =>
  grid.value.map(diaSlots => {
    const activos = diaSlots.filter(Boolean).length
    if (!activos) return null
    const horas   = Math.floor(activos * STEP / 60)
    const minutos = (activos * STEP) % 60
    return horas > 0
      ? (minutos > 0 ? `${horas}h ${minutos}m` : `${horas}h`)
      : `${minutos}m`
  })
)

const totalHorasSemanales = computed(() => {
  const total = grid.value.reduce((sum, d) => sum + d.filter(Boolean).length, 0)
  return ((total * STEP) / 60).toFixed(1)
})

const diasActivos = computed(() =>
  grid.value.filter(d => d.some(Boolean)).length
)

// ── Selección rápida de día completo ────────────────────────────────────
function toggleDia(diaIdx) {
  const activos = grid.value[diaIdx].some(Boolean)
  // Si tiene algo activo → limpiar. Si no → activar franja típica 9-18
  if (activos) {
    grid.value[diaIdx].fill(false)
  } else {
    const from = SLOTS.indexOf(9 * 60)
    const to   = SLOTS.indexOf(18 * 60)
    grid.value[diaIdx] = grid.value[diaIdx].map((_, i) => i >= from && i < to)
  }
}

// ── Vacaciones / bloqueos ────────────────────────────────────────────────
const vacaciones = ref([])   // [{ id, fecha_inicio, fecha_fin, motivo }]
const showAddVac = ref(false)
const vacForm    = ref({ fecha_inicio: '', fecha_fin: '', motivo: '' })
let   vacIdSeq   = 1

function addVacacion() {
  if (!vacForm.value.fecha_inicio || !vacForm.value.fecha_fin) {
    toast.error('Indicá fecha de inicio y fin')
    return
  }
  vacaciones.value.push({ id: vacIdSeq++, ...vacForm.value })
  vacForm.value  = { fecha_inicio: '', fecha_fin: '', motivo: '' }
  showAddVac.value = false
}

// ── Serializar grid → slots para backend ────────────────────────────────
function gridToSlots() {
  const result = []
  for (let dia = 0; dia < 7; dia++) {
    let ini = null
    for (let si = 0; si <= SLOTS.length; si++) {
      const active = si < SLOTS.length && grid.value[dia][si]
      if (active && ini === null) ini = si
      if (!active && ini !== null) {
        result.push({ dia_semana: dia, hora_inicio: SLOTS[ini], hora_fin: SLOTS[si - 1] + STEP })
        ini = null
      }
    }
  }
  return result
}

// ── Cargar desde backend ─────────────────────────────────────────────────
function slotsToGrid(slots) {
  const g = Array.from({ length: 7 }, () => new Array(SLOTS.length).fill(false))
  for (const s of slots) {
    const dia = s.dia_semana
    for (let si = 0; si < SLOTS.length; si++) {
      const m = SLOTS[si]
      if (m >= s.hora_inicio && m < s.hora_fin) g[dia][si] = true
    }
  }
  return g
}

async function guardar() {
  saving.value = true
  try {
    await saveMedicoDisponibilidad(gridToSlots())
    toast.success('Disponibilidad guardada')
  } catch {
    toast.error('No se pudo guardar')
  } finally { saving.value = false }
}

onMounted(async () => {
  try {
    const { data } = await getMedicoDisponibilidad()
    if (data?.length) grid.value = slotsToGrid(data)
  } finally { loading.value = false }
})
</script>

<template>
  <div class="mdv" @mouseleave="stopDrag">

    <!-- Header -->
    <div class="mdv__header">
      <div class="mdv__header-text">
        <h1 class="mdv__title">Mi disponibilidad</h1>
        <p class="mdv__sub">
          Pintá los bloques horarios en que atendés. Arrastrá para seleccionar múltiples franjas.
          El administrador verá tu disponibilidad al agendar turnos para tus pacientes.
        </p>
      </div>
      <button class="mdv__btn-save" :disabled="saving || loading" @click="guardar">
        <DsSpinner v-if="saving" :size="14" />
        <CheckCircle2 v-else :size="15" />
        {{ saving ? 'Guardando…' : 'Guardar cambios' }}
      </button>
    </div>

    <!-- Resumen rápido -->
    <div class="mdv__stats">
      <div class="mdv__stat">
        <span class="mdv__stat-val">{{ diasActivos }}</span>
        <span class="mdv__stat-lbl">días / semana</span>
      </div>
      <div class="mdv__stat-sep"></div>
      <div class="mdv__stat">
        <span class="mdv__stat-val">{{ totalHorasSemanales }}h</span>
        <span class="mdv__stat-lbl">horas semanales</span>
      </div>
      <div class="mdv__stat-sep"></div>
      <div class="mdv__stat-hint">
        <Info :size="13" />
        Hacé click en el nombre del día para activar/desactivar rápidamente el horario típico 9–18h
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mdv__loading">
      <DsSpinner :size="22" /> Cargando disponibilidad…
    </div>

    <!-- Grilla de disponibilidad -->
    <div v-else class="mdv__grid-wrap">
      <div class="mdv__grid" :class="{ 'mdv__grid--dragging': dragging }" @dragstart.prevent>

        <!-- Cabecera de días -->
        <div class="mdv__grid-corner"></div>
        <button
          v-for="(dia, di) in DIAS"
          :key="di"
          class="mdv__day-header"
          :class="{ 'mdv__day-header--on': resumenDia[di], 'mdv__day-header--weekend': di >= 5 }"
          @click="toggleDia(di)"
          :title="`Click para activar/desactivar ${dia}`"
        >
          <span class="mdv__day-name">{{ dia }}</span>
          <span class="mdv__day-summary" :class="resumenDia[di] ? 'mdv__day-summary--on' : 'mdv__day-summary--off'">
            {{ resumenDia[di] || 'Sin atención' }}
          </span>
        </button>

        <!-- Filas de horarios -->
        <template v-for="(slotMin, si) in SLOTS" :key="si">
          <!-- Label de hora (solo en punto) -->
          <div class="mdv__time-label" :class="{ 'mdv__time-label--half': slotMin % 60 !== 0 }">
            <span v-if="slotMin % 60 === 0">{{ minToStr(slotMin) }}</span>
          </div>

          <!-- Celdas de los 7 días -->
          <div
            v-for="(_, di) in DIAS"
            :key="di"
            class="mdv__cell"
            :class="{
              'mdv__cell--on':      grid[di][si],
              'mdv__cell--weekend': di >= 5,
              'mdv__cell--hour':    slotMin % 60 === 0,
              'mdv__cell--drag':    dragging && dragOrigin?.dia === di &&
                                    (() => { const [f,t] = [dragOrigin.slot, dragCurrent?.slot].sort((a,b)=>a-b); return si >= f && si <= t })(),
            }"
            @mousedown.prevent="onCellMousedown(di, si)"
            @mouseenter="onCellMouseenter(di, si)"
          >
            <span v-if="grid[di][si] && slotMin % 60 === 0 && si > 0 && !grid[di][si-1]" class="mdv__cell-start">
              {{ minToStr(slotMin) }}
            </span>
          </div>
        </template>

      </div>

      <!-- Leyenda -->
      <div class="mdv__legend">
        <span class="mdv__leg"><span class="mdv__leg-box mdv__leg-box--on"></span>Disponible</span>
        <span class="mdv__leg"><span class="mdv__leg-box"></span>No disponible</span>
        <span class="mdv__leg mdv__leg--hint">Arrastrá verticalmente en una columna para seleccionar un rango</span>
      </div>
    </div>

    <!-- Vacaciones y bloqueos -->
    <div v-if="!loading" class="mdv__vacaciones">
      <div class="mdv__vac-header">
        <div class="mdv__vac-title">
          <CalendarX2 :size="16" />
          Vacaciones y bloqueos
        </div>
        <button class="mdv__btn-add-vac" @click="showAddVac = !showAddVac">
          <Plus :size="13" /> Agregar bloqueo
        </button>
      </div>

      <!-- Form agregar -->
      <Transition name="vac-form">
        <div v-if="showAddVac" class="mdv__vac-form">
          <div class="mdv__vac-fields">
            <div class="mdv__vac-field">
              <label>Desde</label>
              <AppDatePicker v-model="vacForm.fecha_inicio" />
            </div>
            <div class="mdv__vac-field">
              <label>Hasta</label>
              <AppDatePicker v-model="vacForm.fecha_fin" />
            </div>
            <div class="mdv__vac-field mdv__vac-field--wide">
              <label>Motivo (opcional)</label>
              <input v-model="vacForm.motivo" type="text" class="mdv__vac-input" placeholder="Ej: Vacaciones, feriado, congreso…" />
            </div>
          </div>
          <div class="mdv__vac-form-actions">
            <button class="mdv__btn-ghost-sm" @click="showAddVac = false">Cancelar</button>
            <button class="mdv__btn-primary-sm" @click="addVacacion">Agregar</button>
          </div>
        </div>
      </Transition>

      <!-- Lista -->
      <div v-if="vacaciones.length === 0 && !showAddVac" class="mdv__vac-empty">
        Sin bloqueos registrados. Tus pacientes pueden ser agendados cualquier semana según tu horario.
      </div>
      <div class="mdv__vac-list">
        <div v-for="v in vacaciones" :key="v.id" class="mdv__vac-item">
          <CalendarX2 :size="14" class="mdv__vac-item-icon" />
          <div class="mdv__vac-item-info">
            <span class="mdv__vac-dates">
              {{ new Date(v.fecha_inicio + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' }) }}
              →
              {{ new Date(v.fecha_fin + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' }) }}
            </span>
            <span v-if="v.motivo" class="mdv__vac-motivo">{{ v.motivo }}</span>
          </div>
          <button class="mdv__vac-remove" @click="vacaciones.splice(vacaciones.indexOf(v), 1)" title="Eliminar">
            <Trash2 :size="13" />
          </button>
        </div>
      </div>
    </div>

    <!-- Footer save -->
    <div v-if="!loading" class="mdv__footer">
      <button class="mdv__btn-save" :disabled="saving" @click="guardar">
        <DsSpinner v-if="saving" :size="14" />
        <CheckCircle2 v-else :size="15" />
        {{ saving ? 'Guardando…' : 'Guardar cambios' }}
      </button>
    </div>

  </div>
</template>

<style scoped>
*, *::before, *::after { box-sizing: border-box; }
.mdv { padding: var(--sp-6); max-width: 920px; user-select: none; }

/* Header */
.mdv__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: var(--sp-5); margin-bottom: var(--sp-4); flex-wrap: wrap;
}
.mdv__header-text { min-width: 0; }
.mdv__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mdv__sub   { color: var(--c-ink-500); font-size: var(--fs-13); margin: 0; max-width: 560px; line-height: 1.5; }

/* Stats */
.mdv__stats {
  display: flex; align-items: center; gap: var(--sp-4);
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-radius: var(--r-lg); padding: var(--sp-3) var(--sp-5);
  margin-bottom: var(--sp-5); flex-wrap: wrap;
}
.mdv__stat { display: flex; align-items: baseline; gap: var(--sp-2); }
.mdv__stat-val { font-size: var(--fs-22); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.mdv__stat-lbl { font-size: var(--fs-12); color: var(--c-ink-500); }
.mdv__stat-sep { width: 1px; height: 26px; background: var(--c-ink-100); }
.mdv__stat-hint { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-12); color: var(--c-ink-400); flex: 1; min-width: 200px; }

/* Loading */
.mdv__loading { display: flex; align-items: center; gap: var(--sp-3); color: var(--c-ink-400); padding: var(--sp-8); }

/* Grid wrapper */
.mdv__grid-wrap {
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-radius: var(--r-xl); overflow: hidden; margin-bottom: var(--sp-5);
}

/* Grid */
.mdv__grid {
  display: grid;
  grid-template-columns: 44px repeat(7, 1fr);
  overflow-x: auto;
}
.mdv__grid--dragging { cursor: ns-resize; }
.mdv__grid--dragging .mdv__cell { cursor: ns-resize; }

/* Corner */
.mdv__grid-corner {
  background: #fafafa; border-bottom: 2px solid var(--c-ink-100);
  border-right: 1px solid var(--c-ink-100);
}

/* Day headers */
.mdv__day-header {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 2px; padding: var(--sp-2) var(--sp-1);
  background: #fafafa; border-bottom: 2px solid var(--c-ink-100);
  border-left: 1px solid var(--c-ink-100);
  cursor: pointer; transition: background .15s;
  min-height: 52px;
}
.mdv__day-header:hover { background: var(--c-leaf-50); }
.mdv__day-header--on { background: var(--c-leaf-50); border-bottom-color: #86efac; }
.mdv__day-header--weekend { background: var(--c-slate-50); }
.mdv__day-header--weekend.mdv__day-header--on { background: var(--c-leaf-50); }
.mdv__day-name { font-size: var(--fs-12); font-weight: 800; color: var(--c-ink-700); text-transform: uppercase; letter-spacing: .06em; }
.mdv__day-summary { font-size: .62rem; font-weight: 600; }
.mdv__day-summary--on  { color: #16a34a; }
.mdv__day-summary--off { color: var(--c-ink-300); }

/* Time labels */
.mdv__time-label {
  display: flex; align-items: flex-start; justify-content: flex-end;
  padding-right: 6px; padding-top: 0;
  border-right: 1px solid var(--c-ink-100);
  background: #fafafa; height: 18px; font-size: .6rem;
  color: var(--c-ink-400); font-weight: 700;
  line-height: 1; padding-top: 2px;
}
.mdv__time-label--half { color: transparent; }

/* Cells */
.mdv__cell {
  height: 18px; border-left: 1px solid var(--c-slate-100);
  border-top: 1px solid transparent;
  background: #fff; cursor: pointer; position: relative;
  transition: background .06s;
}
.mdv__cell--hour    { border-top-color: var(--c-slate-200); }
.mdv__cell--weekend { background: #fafafa; }
.mdv__cell--on      { background: #bbf7d0; border-top-color: #86efac !important; }
.mdv__cell--on.mdv__cell--weekend { background: #a7f3d0; }
.mdv__cell:hover:not(.mdv__cell--on) { background: var(--c-leaf-50); }
.mdv__cell--on:hover { background: #a7f3d0; }
.mdv__cell--drag:not(.mdv__cell--on) { background: #dcfce7; }

.mdv__cell-start {
  position: absolute; top: 1px; left: 3px;
  font-size: .55rem; font-weight: 800; color: #15803d;
  pointer-events: none; line-height: 1;
}

/* Legend */
.mdv__legend {
  display: flex; align-items: center; gap: var(--sp-4);
  padding: var(--sp-3) var(--sp-4);
  border-top: 1px solid var(--c-ink-100); background: #fafafa;
}
.mdv__leg { display: flex; align-items: center; gap: var(--sp-2); font-size: .72rem; color: var(--c-ink-500); }
.mdv__leg-box {
  width: 14px; height: 14px; border-radius: 3px;
  background: #fff; border: 1.5px solid var(--c-ink-200);
}
.mdv__leg-box--on { background: #bbf7d0; border-color: #86efac; }
.mdv__leg--hint { margin-left: auto; color: var(--c-ink-400); font-style: italic; }

/* Vacaciones */
.mdv__vacaciones {
  background: var(--c-paper); border: 1px solid var(--c-ink-100);
  border-radius: var(--r-xl); overflow: hidden; margin-bottom: var(--sp-5);
}
.mdv__vac-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-4) var(--sp-5); border-bottom: 1px solid var(--c-ink-100);
  background: #fafafa;
}
.mdv__vac-title { display: flex; align-items: center; gap: var(--sp-2); font-size: var(--fs-14); font-weight: 700; color: var(--c-ink-800); }
.mdv__btn-add-vac {
  display: inline-flex; align-items: center; gap: var(--sp-1);
  background: none; border: 1.5px solid var(--c-leaf-800); color: var(--c-leaf-800);
  border-radius: var(--r-md); padding: .3rem .75rem; font-size: var(--fs-12); font-weight: 700;
  cursor: pointer; transition: all .15s;
}
.mdv__btn-add-vac:hover { background: var(--c-leaf-50); }

.mdv__vac-form {
  padding: var(--sp-4) var(--sp-5); border-bottom: 1px solid var(--c-ink-100);
  background: var(--c-slate-50);
}
.mdv__vac-fields {
  display: flex; gap: var(--sp-3); flex-wrap: wrap; margin-bottom: var(--sp-3);
}
.mdv__vac-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.mdv__vac-field--wide { flex: 1; min-width: 200px; }
.mdv__vac-field label { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; color: var(--c-ink-500); }
.mdv__vac-input {
  padding: .4rem .65rem; border: 1.5px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-13); color: var(--c-ink-900); outline: none; background: #fff;
  transition: border-color .15s; min-width: 140px;
}
.mdv__vac-input:focus { border-color: var(--c-leaf-800); }
.mdv__vac-form-actions { display: flex; gap: var(--sp-2); justify-content: flex-end; }

.mdv__vac-empty { padding: var(--sp-4) var(--sp-5); font-size: var(--fs-13); color: var(--c-ink-400); font-style: italic; }
.mdv__vac-list { display: flex; flex-direction: column; }
.mdv__vac-item {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-3) var(--sp-5); border-top: 1px solid var(--c-ink-50);
}
.mdv__vac-item:first-child { border-top: none; }
.mdv__vac-item-icon { color: #dc2626; flex-shrink: 0; }
.mdv__vac-item-info { flex: 1; display: flex; flex-direction: column; gap: 1px; }
.mdv__vac-dates { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-800); }
.mdv__vac-motivo { font-size: var(--fs-12); color: var(--c-ink-500); }
.mdv__vac-remove {
  background: none; border: none; cursor: pointer;
  color: var(--c-ink-300); border-radius: var(--r-sm); padding: .2rem; transition: color .12s;
}
.mdv__vac-remove:hover { color: #dc2626; }

/* Buttons */
.mdv__btn-save {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: var(--c-leaf-800); color: #fff; border: none; border-radius: var(--r-md);
  padding: .55rem var(--sp-5); font-size: var(--fs-14); font-weight: 700;
  cursor: pointer; transition: background .15s; white-space: nowrap;
}
.mdv__btn-save:hover:not(:disabled) { background: var(--c-leaf-900); }
.mdv__btn-save:disabled { opacity: .6; cursor: not-allowed; }
.mdv__btn-primary-sm {
  background: var(--c-leaf-800); color: #fff; border: none; border-radius: var(--r-md);
  padding: .35rem .85rem; font-size: var(--fs-13); font-weight: 700; cursor: pointer; transition: background .15s;
}
.mdv__btn-primary-sm:hover { background: var(--c-leaf-900); }
.mdv__btn-ghost-sm {
  background: none; border: 1.5px solid var(--c-ink-200); color: var(--c-ink-500);
  border-radius: var(--r-md); padding: .35rem .85rem; font-size: var(--fs-13); cursor: pointer; transition: all .15s;
}
.mdv__btn-ghost-sm:hover { border-color: var(--c-ink-400); }

/* Footer */
.mdv__footer { display: flex; justify-content: flex-end; padding-top: var(--sp-2); }

/* Transition */
.vac-form-enter-active, .vac-form-leave-active { transition: all .2s ease; }
.vac-form-enter-from, .vac-form-leave-to { opacity: 0; transform: translateY(-8px); }
</style>
