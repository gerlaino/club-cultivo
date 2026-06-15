<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import {
  getAdminMedicos, getAdminMedicoDisponibilidad,
  getAdminMedicoTurnos, createAdminTurno,
  updateAdminTurno, deleteAdminTurno,
  getMedicoTurnos, getMedicoDisponibilidad, createMedicoTurno, updateMedicoTurno,
} from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import {
  X, ChevronLeft, ChevronRight, Plus, User2, Clock,
  Calendar, CheckCircle2, Pencil, Trash2, AlertTriangle,
} from 'lucide-vue-next'

const props = defineProps({
  pacienteId:     { type: Number, required: true },
  pacienteNombre: { type: String, default: '' },
  medicoMode:     { type: Boolean, default: false },
})
const emit = defineEmits(['close', 'created'])
const toast = useToast()

// ── Calendar config ───────────────────────────────────────────────────────────
const H_INICIO = 8
const H_FIN    = 21
const PX_MIN   = 1.2
const ALTURA   = (H_FIN - H_INICIO) * 60 * PX_MIN
const HORAS    = Array.from({ length: H_FIN - H_INICIO }, (_, i) => H_INICIO + i)
const DIAS_L   = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']

const TIPO_CFG = {
  primera_vez: { label: 'Primera vez', color: '#7c3aed', bg: '#f5f3ff' },
  seguimiento: { label: 'Seguimiento', color: '#1b5e20', bg: '#f0fdf4' },
  revision:    { label: 'Revisión',    color: '#1d4ed8', bg: '#eff6ff' },
  urgencia:    { label: 'Urgencia',    color: '#dc2626', bg: '#fff1f2' },
}

const ESTADO_OPTS = [
  { value: 'programado',  label: 'Programado' },
  { value: 'confirmado',  label: 'Confirmado' },
  { value: 'realizado',   label: 'Realizado'  },
  { value: 'cancelado',   label: 'Cancelado'  },
  { value: 'ausente',     label: 'Ausente'    },
]

// ── State ─────────────────────────────────────────────────────────────────────
const loadingMedicos = ref(true)
const loadingCal     = ref(false)
const saving         = ref(false)

const medicos        = ref([])
const medicoId       = ref(null)
const disponibilidad = ref([])
const turnosExist    = ref([])
const semanaOff      = ref(0)
const ahora          = new Date()

// ── Form / edit state ─────────────────────────────────────────────────────────
const MODE_NONE   = 'none'
const MODE_CREATE = 'create'
const MODE_EDIT   = 'edit'

const mode        = ref(MODE_NONE)
const slotSel     = ref(null)       // { dia: Date, hora: string, fecha: string }
const editTurnoId = ref(null)
const form        = ref({ duracion_minutos: 30, tipo: 'seguimiento', motivo: '', estado: 'programado' })

// Un turno ya realizado no se puede reprogramar ni cancelar (solo se muestra)
const turnoEditando = computed(() => turnosExist.value.find(t => t.id === editTurnoId.value) || null)
const esRealizado   = computed(() => turnoEditando.value?.estado === 'realizado')

function resetPanel() {
  mode.value        = MODE_NONE
  slotSel.value     = null
  editTurnoId.value = null
  form.value        = { duracion_minutos: 30, tipo: 'seguimiento', motivo: '', estado: 'programado' }
}

// ── Week helpers ──────────────────────────────────────────────────────────────
const diasSemana = computed(() => {
  const base = new Date()
  base.setDate(base.getDate() + semanaOff.value * 7)
  const dow   = (base.getDay() + 6) % 7
  const lunes = new Date(base)
  lunes.setDate(base.getDate() - dow)
  lunes.setHours(0, 0, 0, 0)
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(lunes); d.setDate(lunes.getDate() + i); return d
  })
})
const semanaLabel = computed(() => {
  const [ini, fin] = [diasSemana.value[0], diasSemana.value[6]]
  const fD = d => d.getDate()
  const fM = d => d.toLocaleDateString('es-AR', { month: 'short' })
  return ini.getMonth() === fin.getMonth()
    ? `${fD(ini)}–${fD(fin)} ${fM(ini)} ${ini.getFullYear()}`
    : `${fD(ini)} ${fM(ini)} – ${fD(fin)} ${fM(fin)} ${fin.getFullYear()}`
})

function esHoy(d)    { return d.toDateString() === new Date().toDateString() }
function esPasado(d) { return d < new Date(new Date().setHours(0, 0, 0, 0)) }

// ── Disponibilidad helpers ────────────────────────────────────────────────────
function bloquesFuera(dia) {
  if (!disponibilidad.value.length) return []
  const dow   = (dia.getDay() + 6) % 7
  const slots = disponibilidad.value.filter(s => s.dia_semana === dow).sort((a, b) => a.hora_inicio - b.hora_inicio)
  if (!slots.length) return [{ top: 0, height: ALTURA }]
  const bloques = []; const calIni = H_INICIO * 60; let cursor = calIni
  for (const s of slots) {
    const ini = Math.max(s.hora_inicio, calIni)
    const fin = Math.min(s.hora_fin, H_FIN * 60)
    if (ini > cursor) bloques.push({ top: (cursor - calIni) * PX_MIN, height: (ini - cursor) * PX_MIN })
    cursor = Math.max(cursor, fin)
  }
  if (cursor < H_FIN * 60) bloques.push({ top: (cursor - calIni) * PX_MIN, height: (H_FIN * 60 - cursor) * PX_MIN })
  return bloques
}

function esDentroDisp(dia, minutos) {
  if (!disponibilidad.value.length) return true    // sin configurar = todo libre
  const dow   = (dia.getDay() + 6) % 7
  const slots = disponibilidad.value.filter(s => s.dia_semana === dow)
  if (!slots.length) return false                  // día no configurado = bloqueado
  return slots.some(s => minutos >= s.hora_inicio && minutos < s.hora_fin)
}

// ── Turnos positioning ────────────────────────────────────────────────────────
function turnoTop(t)    { const d = new Date(t.fecha_hora); return (d.getHours() * 60 + d.getMinutes() - H_INICIO * 60) * PX_MIN }
function turnoHeight(t) { return Math.max(t.duracion_minutos * PX_MIN, 26) }
function turnosDia(dia) { return turnosExist.value.filter(t => new Date(t.fecha_hora).toDateString() === dia.toDateString()) }
function fmtHora(fh)    { return new Date(fh).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) }

// ── Computed: slot en edición (para el preview en el cal) ─────────────────────
const slotSelTop = computed(() => {
  if (!slotSel.value) return 0
  const [hh, mm] = slotSel.value.hora.split(':').map(Number)
  return (hh * 60 + mm - H_INICIO * 60) * PX_MIN
})

// ── Click en slot vacío ───────────────────────────────────────────────────────
function onClickSlot(dia, event) {
  if (!medicoId.value) { toast.error('Seleccioná un médico primero'); return }
  if (esPasado(dia))   return

  const rect  = event.currentTarget.getBoundingClientRect()
  const y     = event.clientY - rect.top
  const total = Math.round(y / PX_MIN) + H_INICIO * 60
  const h     = Math.min(Math.floor(total / 60), H_FIN - 1)
  const m     = Math.min(Math.round((total % 60) / 15) * 15, 45)
  const slotDate = new Date(dia); slotDate.setHours(h, m, 0, 0)

  if (slotDate <= ahora) { toast.error('No podés crear turnos en el pasado'); return }

  // ── BLOQUEO DURO: fuera de disponibilidad ──────────────────────────────────
  if (!esDentroDisp(dia, h * 60 + m)) {
    toast.error('Ese horario está fuera de la disponibilidad del médico')
    return
  }

  slotSel.value = {
    dia,
    hora:  `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`,
    fecha: dia.toISOString().split('T')[0],
  }
  editTurnoId.value = null
  form.value        = { duracion_minutos: 30, tipo: 'seguimiento', motivo: '', estado: 'programado' }
  mode.value        = MODE_CREATE
}

// ── Click en turno existente (editar) ────────────────────────────────────────
function onClickTurno(t, event) {
  event.stopPropagation()
  const d = new Date(t.fecha_hora)
  const h = d.getHours(); const m = d.getMinutes()
  slotSel.value = {
    dia:   d,
    hora:  `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`,
    fecha: t.fecha_hora.split('T')[0],
  }
  editTurnoId.value           = t.id
  form.value.duracion_minutos = t.duracion_minutos
  form.value.tipo             = t.tipo
  form.value.motivo           = t.motivo || ''
  form.value.estado           = t.estado
  mode.value                  = MODE_EDIT
}

// ── Cargar datos del médico seleccionado ──────────────────────────────────────
async function cargarMedico(id) {
  if (!id && !props.medicoMode) { disponibilidad.value = []; turnosExist.value = []; return }
  loadingCal.value = true
  resetPanel()
  try {
    if (props.medicoMode) {
      const [dRes, tRes] = await Promise.all([getMedicoDisponibilidad(), getMedicoTurnos()])
      disponibilidad.value = dRes.data || []
      turnosExist.value    = (tRes.data || []).filter(t => t.paciente_id === props.pacienteId || true)
    } else {
      const [dRes, tRes] = await Promise.all([getAdminMedicoDisponibilidad(id), getAdminMedicoTurnos(id)])
      disponibilidad.value = dRes.data || []
      turnosExist.value    = tRes.data || []
    }
  } finally { loadingCal.value = false }
}

watch(medicoId, (id) => { if (!props.medicoMode) cargarMedico(id) })

// ── Crear turno ───────────────────────────────────────────────────────────────
async function crear() {
  if (!slotSel.value) return
  saving.value = true
  try {
    const payload = {
      paciente_id:      props.pacienteId,
      fecha_hora:       new Date(`${slotSel.value.fecha}T${slotSel.value.hora}:00`).toISOString(),
      duracion_minutos: Number(form.value.duracion_minutos),
      tipo:             form.value.tipo,
      motivo:           form.value.motivo || undefined,
    }
    const { data } = props.medicoMode
      ? await createMedicoTurno(payload)
      : await createAdminTurno(medicoId.value, payload)
    turnosExist.value.push(data)
    toast.success('Turno agendado')
    emit('created', data)
    resetPanel()
  } catch { toast.error('No se pudo crear el turno') }
  finally  { saving.value = false }
}

// ── Actualizar turno ──────────────────────────────────────────────────────────
async function actualizar() {
  if (!editTurnoId.value) return
  saving.value = true
  try {
    const payload = {
      duracion_minutos: Number(form.value.duracion_minutos),
      tipo:             form.value.tipo,
      motivo:           form.value.motivo || undefined,
      estado:           form.value.estado,
    }
    const { data } = props.medicoMode
      ? await updateMedicoTurno(editTurnoId.value, payload)
      : await updateAdminTurno(editTurnoId.value, payload)
    const idx = turnosExist.value.findIndex(t => t.id === editTurnoId.value)
    if (idx !== -1) turnosExist.value[idx] = data
    toast.success('Turno actualizado')
    resetPanel()
  } catch { toast.error('No se pudo actualizar el turno') }
  finally  { saving.value = false }
}

// ── Cancelar turno ────────────────────────────────────────────────────────────
async function cancelar() {
  if (!editTurnoId.value) return
  if (!confirm('¿Cancelar este turno?')) return
  saving.value = true
  try {
    const payload = { estado: 'cancelado' }
    props.medicoMode
      ? await updateMedicoTurno(editTurnoId.value, payload)
      : await deleteAdminTurno(editTurnoId.value)
    const idx = turnosExist.value.findIndex(t => t.id === editTurnoId.value)
    if (idx !== -1) turnosExist.value[idx] = { ...turnosExist.value[idx], estado: 'cancelado' }
    toast.success('Turno cancelado')
    resetPanel()
  } catch { toast.error('No se pudo cancelar el turno') }
  finally  { saving.value = false }
}

onMounted(async () => {
  if (props.medicoMode) {
    medicoId.value = -1
    loadingMedicos.value = false
    await cargarMedico()
  } else {
    try {
      const { data } = await getAdminMedicos()
      medicos.value = data || []
      if (medicos.value.length === 1) medicoId.value = medicos.value[0].id
    } finally { loadingMedicos.value = false }
  }
})
</script>

<template>
  <Teleport to="body">
    <div class="atm__overlay" @click.self="$emit('close')">
      <div class="atm__modal">

        <!-- Header -->
        <div class="atm__header">
          <div class="atm__header-info">
            <Calendar :size="16" />
            <div>
              <div class="atm__header-title">Agendar turno médico</div>
              <div class="atm__header-pac">{{ pacienteNombre }}</div>
            </div>
          </div>
          <button class="atm__close" @click="$emit('close')"><X :size="18" /></button>
        </div>

        <!-- Toolbar -->
        <div class="atm__toolbar">
          <div v-if="!medicoMode" class="atm__medico-sel">
            <User2 :size="14" class="atm__toolbar-icon" />
            <select v-model.number="medicoId" class="atm__select">
              <option :value="null" disabled>— Seleccioná un médico —</option>
              <option v-for="m in medicos" :key="m.id" :value="m.id">
                {{ m.nombre_completo }}{{ !m.tiene_disponibilidad ? ' (sin horarios)' : '' }}
              </option>
            </select>
          </div>
          <div class="atm__week-nav">
            <button class="atm__nav-btn" :disabled="semanaOff <= 0" @click="semanaOff--"><ChevronLeft :size="14" /></button>
            <span class="atm__week-lbl">{{ semanaLabel }}</span>
            <button class="atm__nav-btn" @click="semanaOff++"><ChevronRight :size="14" /></button>
            <button v-if="semanaOff !== 0" class="atm__hoy-btn" @click="semanaOff = 0">Hoy</button>
          </div>
        </div>

        <!-- Leyenda -->
        <div class="atm__legend">
          <span class="atm__leg-item"><span class="atm__leg-swatch atm__leg-swatch--disp"></span>Disponible</span>
          <span class="atm__leg-item"><span class="atm__leg-swatch atm__leg-swatch--nodisp"></span>Fuera de horario (bloqueado)</span>
          <span class="atm__leg-item"><span class="atm__leg-swatch atm__leg-swatch--ocupado"></span>Turno agendado — click para editar</span>
        </div>

        <!-- Body -->
        <div class="atm__body">

          <!-- Calendario -->
          <div class="atm__cal-wrap">
            <div v-if="loadingMedicos" class="atm__cal-empty">
              <DsSpinner :size="20" /><p>Cargando médicos…</p>
            </div>
            <div v-else-if="!medicoId" class="atm__cal-empty">
              <User2 :size="32" :stroke-width="1" />
              <p>Seleccioná un médico para ver su disponibilidad</p>
            </div>
            <div v-else class="atm__cal">

              <!-- Gutter horas -->
              <div class="atm__gutter">
                <div class="atm__gutter-spacer"></div>
                <div class="atm__gutter-body" :style="{ height: ALTURA + 'px' }">
                  <div v-for="h in HORAS" :key="h" class="atm__hour-lbl"
                    :style="{ top: ((h - H_INICIO) * 60 * PX_MIN) + 'px' }">
                    {{ String(h).padStart(2,'0') }}:00
                  </div>
                </div>
              </div>

              <!-- Columnas días -->
              <div class="atm__days">
                <div v-for="(dia, idx) in diasSemana" :key="idx"
                  class="atm__day"
                  :class="{
                    'atm__day--hoy':     esHoy(dia),
                    'atm__day--pasado':  esPasado(dia),
                    'atm__day--weekend': idx >= 5,
                  }">

                  <div class="atm__day-header">
                    <span class="atm__day-name">{{ DIAS_L[idx] }}</span>
                    <span class="atm__day-num" :class="{ 'atm__day-num--hoy': esHoy(dia) }">{{ dia.getDate() }}</span>
                  </div>

                  <div class="atm__day-body" :style="{ height: ALTURA + 'px' }"
                    @click="!esPasado(dia) && onClickSlot(dia, $event)">

                    <DsSpinner v-if="loadingCal" :size="14" class="atm__cal-spinner" />
                    <template v-else>
                      <!-- Líneas de hora (detrás de todo) -->
                      <div v-for="h in HORAS" :key="`hl-${h}`" class="atm__hour-line"
                        :style="{ top: ((h - H_INICIO) * 60 * PX_MIN) + 'px' }"></div>
                      <div v-for="h in HORAS" :key="`hh-${h}`" class="atm__half-line"
                        :style="{ top: ((h - H_INICIO) * 60 * PX_MIN + 30 * PX_MIN) + 'px' }"></div>

                      <!-- Overlays fuera de disponibilidad (VISIBLES, encima de líneas) -->
                      <div v-for="(b, bi) in bloquesFuera(dia)" :key="`nd-${bi}`"
                        class="atm__nodisp" :style="{ top: b.top + 'px', height: b.height + 'px' }"></div>

                      <!-- Turnos existentes -->
                      <div v-for="t in turnosDia(dia)" :key="t.id"
                        class="atm__turno"
                        :class="[`atm__turno--${t.tipo}`, t.estado === 'cancelado' && 'atm__turno--cancelado']"
                        :style="{
                          top:    turnoTop(t) + 'px',
                          height: turnoHeight(t) + 'px',
                          '--tcol': TIPO_CFG[t.tipo]?.color,
                          '--tbg':  TIPO_CFG[t.tipo]?.bg,
                        }"
                        :title="`${t.paciente_nombre || 'Paciente'} · ${fmtHora(t.fecha_hora)} · Click para editar`"
                        @click.stop="onClickTurno(t, $event)">
                        <div class="atm__turno-hora">{{ fmtHora(t.fecha_hora) }}</div>
                        <div class="atm__turno-nombre">{{ t.paciente_nombre || pacienteNombre }}</div>
                        <Pencil :size="9" class="atm__turno-edit-icon" />
                      </div>

                      <!-- Slot seleccionado (preview) -->
                      <div v-if="mode === MODE_CREATE && slotSel && slotSel.dia.toDateString() === dia.toDateString()"
                        class="atm__slot-sel"
                        :style="{ top: slotSelTop + 'px', height: (form.duracion_minutos * PX_MIN) + 'px' }">
                        <span>{{ slotSel.hora }}</span>
                      </div>
                    </template>
                  </div>
                </div>
              </div>

            </div>
          </div>

          <!-- Panel lateral -->
          <div class="atm__panel" :class="{ 'atm__panel--visible': mode !== MODE_NONE }">

            <!-- Hint vacío -->
            <div v-if="mode === MODE_NONE" class="atm__panel-hint">
              <Clock :size="28" :stroke-width="1" />
              <p>Hacé click en un slot <strong>verde</strong> para agendar, o en un turno existente para editarlo.</p>
            </div>

            <!-- Modo CREAR -->
            <template v-else-if="mode === MODE_CREATE">
              <div class="atm__panel-header">
                <CheckCircle2 :size="15" />
                <span>Nuevo turno</span>
              </div>

              <div class="atm__panel-info">
                <div class="atm__pi-row">
                  <span class="atm__pi-lbl">Paciente</span>
                  <span class="atm__pi-val">{{ pacienteNombre }}</span>
                </div>
                <div v-if="!medicoMode" class="atm__pi-row">
                  <span class="atm__pi-lbl">Médico</span>
                  <span class="atm__pi-val">{{ medicos.find(m => m.id === medicoId)?.nombre_completo }}</span>
                </div>
                <div class="atm__pi-row">
                  <span class="atm__pi-lbl">Fecha y hora</span>
                  <span class="atm__pi-val atm__pi-val--strong">
                    {{ slotSel ? new Date(slotSel.fecha).toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short' }) : '' }}
                    · {{ slotSel?.hora }}
                  </span>
                </div>
              </div>

              <div class="atm__panel-fields">
                <div class="atm__pf-field">
                  <label class="atm__pf-lbl">Duración</label>
                  <select v-model.number="form.duracion_minutos" class="atm__pf-input" :disabled="esRealizado">
                    <option :value="15">15 min</option>
                    <option :value="30">30 min</option>
                    <option :value="45">45 min</option>
                    <option :value="60">1 hora</option>
                    <option :value="90">1:30 h</option>
                  </select>
                </div>
                <div class="atm__pf-field">
                  <label class="atm__pf-lbl">Tipo de consulta</label>
                  <select v-model="form.tipo" class="atm__pf-input" :disabled="esRealizado">
                    <option value="primera_vez">Primera vez</option>
                    <option value="seguimiento">Seguimiento</option>
                    <option value="revision">Revisión</option>
                    <option value="urgencia">Urgencia</option>
                  </select>
                </div>
                <div class="atm__pf-field">
                  <label class="atm__pf-lbl">Motivo (opcional)</label>
                  <textarea v-model="form.motivo" class="atm__pf-input atm__pf-textarea" rows="2" placeholder="Motivo de la consulta…" :disabled="esRealizado" />
                </div>
              </div>

              <div class="atm__panel-actions">
                <button class="atm__btn-ghost" @click="resetPanel">Cancelar</button>
                <button class="atm__btn-primary" :disabled="saving" @click="crear">
                  <DsSpinner v-if="saving" :size="13" />
                  <template v-else><Plus :size="13" /> Confirmar</template>
                </button>
              </div>
            </template>

            <!-- Modo EDITAR -->
            <template v-else-if="mode === MODE_EDIT">
              <div class="atm__panel-header atm__panel-header--edit">
                <Pencil :size="14" />
                <span>Editar turno</span>
              </div>

              <div class="atm__panel-info">
                <div class="atm__pi-row">
                  <span class="atm__pi-lbl">Paciente</span>
                  <span class="atm__pi-val">{{ turnosExist.find(t => t.id === editTurnoId)?.paciente_nombre || pacienteNombre }}</span>
                </div>
                <div class="atm__pi-row">
                  <span class="atm__pi-lbl">Fecha y hora</span>
                  <span class="atm__pi-val atm__pi-val--strong">
                    {{ slotSel ? new Date(slotSel.fecha + 'T00:00:00').toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short' }) : '' }}
                    · {{ slotSel?.hora }}
                  </span>
                </div>
              </div>

              <div v-if="esRealizado" class="atm__realizado-nota">
                <CheckCircle2 :size="14" /> Este turno ya fue realizado: no puede reprogramarse ni cancelarse.
              </div>

              <div class="atm__panel-fields">
                <div class="atm__pf-field">
                  <label class="atm__pf-lbl">Estado</label>
                  <select v-model="form.estado" class="atm__pf-input" :disabled="esRealizado">
                    <option v-for="o in ESTADO_OPTS" :key="o.value" :value="o.value">{{ o.label }}</option>
                  </select>
                </div>
                <div class="atm__pf-field">
                  <label class="atm__pf-lbl">Duración</label>
                  <select v-model.number="form.duracion_minutos" class="atm__pf-input" :disabled="esRealizado">
                    <option :value="15">15 min</option>
                    <option :value="30">30 min</option>
                    <option :value="45">45 min</option>
                    <option :value="60">1 hora</option>
                    <option :value="90">1:30 h</option>
                  </select>
                </div>
                <div class="atm__pf-field">
                  <label class="atm__pf-lbl">Tipo de consulta</label>
                  <select v-model="form.tipo" class="atm__pf-input" :disabled="esRealizado">
                    <option value="primera_vez">Primera vez</option>
                    <option value="seguimiento">Seguimiento</option>
                    <option value="revision">Revisión</option>
                    <option value="urgencia">Urgencia</option>
                  </select>
                </div>
                <div class="atm__pf-field">
                  <label class="atm__pf-lbl">Motivo (opcional)</label>
                  <textarea v-model="form.motivo" class="atm__pf-input atm__pf-textarea" rows="2" placeholder="Motivo de la consulta…" :disabled="esRealizado" />
                </div>
              </div>

              <div class="atm__panel-actions atm__panel-actions--edit">
                <template v-if="!esRealizado">
                  <button class="atm__btn-danger-ghost" :disabled="saving" @click="cancelar" title="Cancelar turno">
                    <Trash2 :size="13" />
                  </button>
                  <button class="atm__btn-ghost" @click="resetPanel">Descartar</button>
                  <button class="atm__btn-primary" :disabled="saving" @click="actualizar">
                    <DsSpinner v-if="saving" :size="13" />
                    <template v-else><CheckCircle2 :size="13" /> Guardar</template>
                  </button>
                </template>
                <button v-else class="atm__btn-ghost" @click="resetPanel">Cerrar</button>
              </div>
            </template>

          </div>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
*, *::before, *::after { box-sizing: border-box; }

.atm__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.55);
  display: flex; align-items: center; justify-content: center;
  z-index: 1000; padding: 1rem; backdrop-filter: blur(2px);
}
.atm__modal {
  background: #fff; border-radius: 18px; width: 100%; max-width: 1040px;
  max-height: 92vh; display: flex; flex-direction: column;
  box-shadow: 0 32px 80px rgba(0,0,0,.28); overflow: hidden;
}

/* Header */
.atm__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.25rem; border-bottom: 1px solid #e2e8f0; flex-shrink: 0;
  background: #fafafa;
}
.atm__header-info { display: flex; align-items: center; gap: .65rem; color: #1b5e20; }
.atm__header-title { font-size: .9rem; font-weight: 800; color: #0f172a; }
.atm__header-pac   { font-size: .75rem; color: #64748b; margin-top: 1px; }
.atm__close {
  background: none; border: none; cursor: pointer; color: #94a3b8;
  border-radius: 6px; padding: .3rem; transition: color .12s;
}
.atm__close:hover { color: #0f172a; background: #f1f5f9; }

/* Toolbar */
.atm__toolbar {
  display: flex; align-items: center; gap: 1rem; padding: .55rem 1.25rem;
  border-bottom: 1px solid #e2e8f0; flex-shrink: 0; flex-wrap: wrap;
}
.atm__medico-sel { display: flex; align-items: center; gap: .5rem; }
.atm__toolbar-icon { color: #64748b; flex-shrink: 0; }
.atm__select {
  padding: .38rem .65rem; border: 1.5px solid #e2e8f0; border-radius: 8px;
  font-size: .82rem; color: #0f172a; background: #fff; outline: none;
  cursor: pointer; min-width: 200px; transition: border-color .15s;
}
.atm__select:focus { border-color: #1b5e20; }
.atm__week-nav { display: flex; align-items: center; gap: .4rem; margin-left: auto; }
.atm__nav-btn {
  width: 26px; height: 26px; border-radius: 6px; background: none;
  border: 1px solid #e2e8f0; cursor: pointer; display: flex; align-items: center;
  justify-content: center; color: #475569; transition: all .12s;
}
.atm__nav-btn:hover:not(:disabled) { background: #f8fafc; }
.atm__nav-btn:disabled { opacity: .4; cursor: not-allowed; }
.atm__week-lbl { font-size: .8rem; font-weight: 700; color: #0f172a; min-width: 148px; text-align: center; }
.atm__hoy-btn {
  font-size: .72rem; font-weight: 700; color: #1b5e20;
  background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 5px;
  padding: .15rem .5rem; cursor: pointer;
}

/* Leyenda */
.atm__legend {
  display: flex; gap: 1.25rem; padding: .35rem 1.25rem;
  border-bottom: 1px solid #e2e8f0; flex-shrink: 0; background: #fdfdfd;
}
.atm__leg-item { display: flex; align-items: center; gap: .4rem; font-size: .7rem; color: #64748b; }
.atm__leg-swatch { width: 12px; height: 12px; border-radius: 3px; flex-shrink: 0; }
.atm__leg-swatch--disp    { background: #d1fae5; border: 1.5px solid #6ee7b7; }
.atm__leg-swatch--nodisp  { background: repeating-linear-gradient(-45deg, #9ca3af 0,#9ca3af 2px,#f1f5f9 2px,#f1f5f9 6px); border: 1px solid #d1d5db; }
.atm__leg-swatch--ocupado { background: #f0fdf4; border: 2px solid #1b5e20; }

/* Body */
.atm__body { display: flex; flex: 1; min-height: 0; overflow: hidden; }

/* Calendario */
.atm__cal-wrap { flex: 1; min-width: 0; overflow-y: auto; overflow-x: auto; }
.atm__cal-empty {
  display: flex; flex-direction: column; align-items: center; gap: .75rem;
  padding: 4rem 2rem; color: #94a3b8; text-align: center;
}
.atm__cal-empty p { font-size: .85rem; color: #64748b; margin: 0; }
.atm__cal { display: flex; }

.atm__gutter { width: 48px; flex-shrink: 0; background: #f8fafc; border-right: 1.5px solid #cbd5e1; }
.atm__gutter-spacer { height: 40px; border-bottom: 1.5px solid #cbd5e1; }
.atm__gutter-body { position: relative; }
.atm__hour-lbl {
  position: absolute; right: 6px; font-size: .6rem; color: #6b7280; font-weight: 700;
  transform: translateY(-50%); user-select: none; line-height: 1;
}

.atm__days { flex: 1; display: grid; grid-template-columns: repeat(7, 1fr); min-width: 500px; }
.atm__day  { display: flex; flex-direction: column; border-left: 1.5px solid #cbd5e1; }
.atm__day--weekend { background: #f9fafb; }
.atm__day--pasado  { opacity: .5; pointer-events: none; }

.atm__day-header {
  height: 40px; display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 1px; flex-shrink: 0; border-bottom: 1.5px solid #cbd5e1;
  position: sticky; top: 0; background: #f8fafc; z-index: 2;
}
.atm__day--hoy .atm__day-header { background: #f0fdf4; border-bottom-color: #86efac; }
.atm__day-name { font-size: .58rem; font-weight: 800; color: #6b7280; text-transform: uppercase; letter-spacing: .06em; }
.atm__day-num  { font-size: .78rem; font-weight: 700; color: #334155; }
.atm__day-num--hoy {
  background: #1b5e20; color: #fff;
  width: 20px; height: 20px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: .68rem;
}

/* ─────────────────────────────────────────────────────────────────────────────
   CUERPO DEL DÍA
   Fondo verde claro = disponible. El overlay gris oscuro cubre lo que no es.
───────────────────────────────────────────────────────────────────────────── */
.atm__day-body {
  position: relative;
  cursor: crosshair;
  background: #f0fdf4;   /* verde suave = "disponible" por defecto */
}
.atm__day--weekend .atm__day-body { background: #f7faf8; }
.atm__day--pasado .atm__day-body  { cursor: default; background: #f8fafc; }

.atm__cal-spinner { position: absolute; top: 50%; left: 50%; transform: translate(-50%,-50%); }

/* Líneas de hora */
.atm__hour-line {
  position: absolute; left: 0; right: 0; height: 1px;
  background: #94a3b8; pointer-events: none; z-index: 1;
}
.atm__half-line {
  position: absolute; left: 0; right: 0; height: 1px;
  background: #cbd5e1; border: none; pointer-events: none; z-index: 1;
}

/* Overlay FUERA de disponibilidad — bien visible */
.atm__nodisp {
  position: absolute; left: 0; right: 0;
  background: repeating-linear-gradient(
    -45deg,
    rgba(100,116,139,.22) 0,
    rgba(100,116,139,.22) 3px,
    rgba(241,245,249,.92) 3px,
    rgba(241,245,249,.92) 9px
  );
  border-bottom: 1px solid rgba(148,163,184,.4);
  pointer-events: none; z-index: 2;
}

/* Turnos */
.atm__turno {
  position: absolute; left: 3px; right: 3px; border-radius: 5px;
  padding: 3px 5px; overflow: hidden; z-index: 3;
  border-left: 3px solid var(--tcol, #1b5e20);
  background: var(--tbg, #f0fdf4);
  cursor: pointer;
  box-shadow: 0 1px 4px rgba(0,0,0,.1);
  transition: box-shadow .12s, transform .1s;
}
.atm__turno:hover { box-shadow: 0 3px 10px rgba(0,0,0,.18); transform: scaleY(1.01); }
.atm__turno--cancelado { opacity: .45; border-style: dashed; }
.atm__turno-hora   { font-size: .58rem; font-weight: 700; color: #64748b; line-height: 1.2; }
.atm__turno-nombre { font-size: .66rem; font-weight: 600; color: #0f172a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.atm__turno-edit-icon { position: absolute; bottom: 3px; right: 3px; color: var(--tcol, #1b5e20); opacity: .5; }

/* Slot preview */
.atm__slot-sel {
  position: absolute; left: 3px; right: 3px; z-index: 4;
  background: rgba(27,94,32,.18); border: 2px dashed #1b5e20; border-radius: 5px;
  display: flex; align-items: flex-start; padding: 3px 6px;
}
.atm__slot-sel span { font-size: .72rem; font-weight: 800; color: #1b5e20; }

/* Panel lateral */
.atm__panel {
  width: 0; flex-shrink: 0; border-left: 1px solid #e2e8f0;
  display: flex; flex-direction: column; overflow: hidden;
  transition: width .2s ease;
}
.atm__panel--visible { width: 268px; }
.atm__panel-hint {
  display: flex; flex-direction: column; align-items: center; gap: .6rem;
  padding: 2.5rem 1rem; color: #cbd5e1; text-align: center; flex: 1; justify-content: center;
}
.atm__panel-hint p { font-size: .78rem; color: #94a3b8; margin: 0; line-height: 1.6; }

.atm__panel-header {
  display: flex; align-items: center; gap: .4rem;
  font-size: .82rem; font-weight: 800; color: #1b5e20;
  padding: .85rem 1rem .4rem; flex-shrink: 0;
}
.atm__panel-header--edit { color: #1d4ed8; }

/* Info rows */
.atm__panel-info { padding: 0 1rem .3rem; }
.atm__pi-row { display: flex; flex-direction: column; gap: 1px; padding: .25rem 0; }
.atm__pi-lbl { font-size: .6rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; }
.atm__pi-val { font-size: .78rem; color: #1e293b; font-weight: 500; }
.atm__pi-val--strong { font-weight: 700; color: #0f172a; }

/* Fields */
.atm__realizado-nota { display: flex; align-items: center; gap: .4rem; margin: 0 1rem .5rem; padding: .5rem .7rem; background: #f0fdf4; border: 1px solid #bbf7d0; color: #15803d; border-radius: 8px; font-size: .76rem; font-weight: 600; }
.atm__panel-fields { padding: 0 1rem; display: flex; flex-direction: column; gap: .4rem; flex: 1; overflow-y: auto; }
.atm__pf-field { display: flex; flex-direction: column; gap: .2rem; }
.atm__pf-lbl { font-size: .62rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #94a3b8; }
.atm__pf-input {
  width: 100%; padding: .38rem .55rem; border: 1.5px solid #e2e8f0;
  border-radius: 7px; font-size: .8rem; color: #0f172a; outline: none;
  transition: border-color .15s; background: #fff;
}
.atm__pf-input:focus { border-color: #1b5e20; }
.atm__pf-textarea { resize: none; font-family: inherit; }

/* Actions */
.atm__panel-actions {
  display: flex; gap: .4rem; padding: .75rem 1rem;
  margin-top: auto; border-top: 1px solid #f1f5f9; flex-shrink: 0;
}
.atm__panel-actions--edit { gap: .35rem; }
.atm__btn-primary {
  flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: .35rem;
  background: #1b5e20; color: #fff; border: none; border-radius: 7px;
  padding: .45rem .5rem; font-size: .78rem; font-weight: 700; cursor: pointer; transition: background .15s;
}
.atm__btn-primary:hover:not(:disabled) { background: #14532d; }
.atm__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.atm__btn-ghost {
  background: none; border: 1.5px solid #e2e8f0; border-radius: 7px;
  padding: .45rem .55rem; font-size: .78rem; font-weight: 600; color: #64748b; cursor: pointer;
  white-space: nowrap; transition: border-color .12s;
}
.atm__btn-ghost:hover { border-color: #94a3b8; }
.atm__btn-danger-ghost {
  display: inline-flex; align-items: center; justify-content: center;
  width: 34px; height: 34px; border-radius: 7px; flex-shrink: 0;
  border: 1.5px solid #fecaca; background: none; color: #dc2626; cursor: pointer; transition: all .12s;
}
.atm__btn-danger-ghost:hover:not(:disabled) { background: #fee2e2; }
.atm__btn-danger-ghost:disabled { opacity: .5; cursor: not-allowed; }
</style>
