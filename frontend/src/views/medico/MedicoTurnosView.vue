<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import { useRouter } from 'vue-router'
import { getMedicoTurnos, getMedicoPacientes, createMedicoTurno, updateMedicoTurno, getMedicoDisponibilidad } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import TurnoDetallePanel from '../../components/TurnoDetallePanel.vue'
import {
  ChevronLeft, ChevronRight, Plus, X, Clock, User2,
  CheckCircle2, XCircle, AlertCircle, Calendar,
  FileText, Pencil, ChevronDown,
} from 'lucide-vue-next'

const router = useRouter()
const toast  = useToast()

// ── Calendar config ───────────────────────────────────────────────────────────
const H_INICIO   = 8
const H_FIN      = 21
const PX_MIN     = 1.2           // px per minute
const ALTURA_CAL = (H_FIN - H_INICIO) * 60 * PX_MIN  // total px height

const HORAS = Array.from({ length: H_FIN - H_INICIO }, (_, i) => H_INICIO + i)
const DIAS_LABEL = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']

const TIPO_CFG = {
  primera_vez: { label: 'Primera vez', color: '#7c3aed', bg: '#f5f3ff' },
  seguimiento: { label: 'Seguimiento', color: 'var(--c-leaf-800)', bg: 'var(--c-leaf-50)' },
  revision:    { label: 'Revisión',    color: '#1d4ed8', bg: '#eff6ff' },
  urgencia:    { label: 'Urgencia',    color: '#dc2626', bg: '#fff5f5' },
}
const ESTADO_CFG = {
  programado:  { label: 'Programado',  cls: 'est--prog'  },
  confirmado:  { label: 'Confirmado',  cls: 'est--conf'  },
  realizado:   { label: 'Realizado',   cls: 'est--real'  },
  cancelado:   { label: 'Cancelado',   cls: 'est--canc'  },
  ausente:     { label: 'Ausente',     cls: 'est--aus'   },
}

// ── Current time ─────────────────────────────────────────────────────────────
const ahora = ref(new Date())
let tickInterval = null

const currentTimeTop = computed(() => {
  const h = ahora.value.getHours()
  const m = ahora.value.getMinutes()
  return (h * 60 + m - H_INICIO * 60) * PX_MIN
})

function pastHeightForDay(dia) {
  if (esPasado(dia)) return ALTURA_CAL
  if (!esHoy(dia))   return 0
  return Math.min(currentTimeTop.value, ALTURA_CAL)
}

// Devuelve los bloques FUERA de disponibilidad para un día (para sombrear)
// Retorna array de { top, height } en px
function bloquesFueraDisponibilidad(dia) {
  if (!disponibilidad.value.length) return []
  const dow = (dia.getDay() + 6) % 7  // 0=lunes
  const slots = disponibilidad.value
    .filter(s => s.dia_semana === dow)
    .sort((a, b) => a.hora_inicio - b.hora_inicio)
  if (!slots.length) return [{ top: 0, height: ALTURA_CAL }]  // sin disponibilidad = todo bloqueado

  const bloques = []
  const calIni  = H_INICIO * 60
  let cursor    = calIni

  for (const s of slots) {
    const ini = Math.max(s.hora_inicio, calIni)
    const fin = Math.min(s.hora_fin, H_FIN * 60)
    if (ini > cursor) bloques.push({ top: (cursor - calIni) * PX_MIN, height: (ini - cursor) * PX_MIN })
    cursor = Math.max(cursor, fin)
  }
  if (cursor < H_FIN * 60) bloques.push({ top: (cursor - calIni) * PX_MIN, height: (H_FIN * 60 - cursor) * PX_MIN })
  return bloques
}

function esDentroDisponibilidad(dia, horaMin) {
  if (!disponibilidad.value.length) return true
  const dow = (dia.getDay() + 6) % 7
  return disponibilidad.value
    .filter(s => s.dia_semana === dow)
    .some(s => horaMin >= s.hora_inicio && horaMin < s.hora_fin)
}

// ── State ─────────────────────────────────────────────────────────────────────
const loading        = ref(true)
const semanaOff      = ref(0)
const turnos         = ref([])
const pacientes      = ref([])
const disponibilidad = ref([])   // [{ dia_semana, hora_inicio, hora_fin }]

// Modals
const showCrear    = ref(false)
const turnoDetalle = ref(null)

// Create form
const defForm = () => ({
  paciente_id: null, pacienteLabel: '',
  fecha: '', hora: '09:00',
  duracion_minutos: 30, tipo: 'seguimiento', motivo: '',
})
const form       = ref(defForm())
const searchPac  = ref('')
const pacOpen    = ref(false)
const saving     = ref(false)

// ── Week ──────────────────────────────────────────────────────────────────────
const diasSemana = computed(() => {
  const base = new Date()
  base.setDate(base.getDate() + semanaOff.value * 7)
  const dow   = (base.getDay() + 6) % 7
  const lunes = new Date(base)
  lunes.setDate(base.getDate() - dow)
  lunes.setHours(0, 0, 0, 0)
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(lunes)
    d.setDate(lunes.getDate() + i)
    return d
  })
})

const semanaLabel = computed(() => {
  const [ini, fin] = [diasSemana.value[0], diasSemana.value[6]]
  const fD = d => d.getDate()
  const fM = d => d.toLocaleDateString('es-AR', { month: 'short' })
  const fA = d => d.getFullYear()
  return ini.getMonth() === fin.getMonth()
    ? `${fD(ini)}–${fD(fin)} ${fM(ini)} ${fA(ini)}`
    : `${fD(ini)} ${fM(ini)} – ${fD(fin)} ${fM(fin)} ${fA(fin)}`
})

function esHoy(d) { return d.toDateString() === new Date().toDateString() }
function esPasado(d) { return d < new Date(new Date().setHours(0,0,0,0)) }

// ── Turno positioning ─────────────────────────────────────────────────────────
function turnoTop(t) {
  const d = new Date(t.fecha_hora)
  return Math.max(0, (d.getHours() * 60 + d.getMinutes() - H_INICIO * 60) * PX_MIN)
}
function turnoHeight(t) {
  return Math.max(t.duracion_minutos * PX_MIN, 28)
}
function turnosDia(dia) {
  return turnos.value
    .filter(t => new Date(t.fecha_hora).toDateString() === dia.toDateString())
    .sort((a, b) => new Date(a.fecha_hora) - new Date(b.fecha_hora))
}

// ── KPIs ─────────────────────────────────────────────────────────────────────
const kpis = computed(() => {
  const [ini, fin] = [diasSemana.value[0], new Date(diasSemana.value[6])]
  fin.setHours(23, 59, 59)
  const ts = turnos.value.filter(t => { const d = new Date(t.fecha_hora); return d >= ini && d <= fin })
  return {
    total:      ts.length,
    pendientes: ts.filter(t => t.estado === 'programado').length,
    realizados: ts.filter(t => t.estado === 'realizado').length,
    urgencias:  ts.filter(t => t.tipo === 'urgencia' && t.estado !== 'cancelado').length,
  }
})

// ── Patient search ────────────────────────────────────────────────────────────
const pacFiltrados = computed(() => {
  if (!searchPac.value.trim()) return pacientes.value.slice(0, 6)
  const q = searchPac.value.toLowerCase()
  return pacientes.value
    .filter(p => `${p.nombre} ${p.apellido} ${p.dni}`.toLowerCase().includes(q))
    .slice(0, 6)
})

function selectPaciente(p) {
  form.value.paciente_id  = p.id
  form.value.pacienteLabel = `${p.apellido}, ${p.nombre}`
  searchPac.value = ''
  pacOpen.value   = false
}

// ── Click on time slot ────────────────────────────────────────────────────────
function esMomentoFuturo(dia, horaMin) {
  const slotDate = new Date(dia)
  slotDate.setHours(Math.floor(horaMin / 60), horaMin % 60, 0, 0)
  return slotDate > ahora.value
}

function onClickSlot(dia, event) {
  const rect  = event.currentTarget.getBoundingClientRect()
  const y     = event.clientY - rect.top
  const total = Math.round(y / PX_MIN) + H_INICIO * 60
  const hora  = Math.floor(total / 60)
  const min   = Math.round((total % 60) / 15) * 15
  const h     = Math.min(hora, H_FIN - 1)
  const m     = min >= 60 ? 45 : min

  if (!esMomentoFuturo(dia, h * 60 + m)) return  // bloquear slots pasados

  const fueraDisp = !esDentroDisponibilidad(dia, h * 60 + m)

  form.value = {
    ...defForm(),
    fecha: dia.toISOString().split('T')[0],
    hora:  `${h.toString().padStart(2,'0')}:${m.toString().padStart(2,'0')}`,
  }
  searchPac.value = ''
  pacOpen.value   = false
  showCrear.value = true
  if (fueraDisp) toast.error('Este horario está fuera de tu disponibilidad configurada, pero podés agendarlo igualmente.')
}

function abrirCrear() {
  const hoy = new Date()
  form.value = {
    ...defForm(),
    fecha: hoy.toISOString().split('T')[0],
    hora:  '09:00',
  }
  searchPac.value = ''
  pacOpen.value   = false
  showCrear.value = true
}

// ── Create ────────────────────────────────────────────────────────────────────
async function crearTurno() {
  if (!form.value.paciente_id) { toast.error('Seleccioná un paciente'); return }
  if (!form.value.fecha)        { toast.error('Indicá la fecha'); return }
  const fechaHora = new Date(`${form.value.fecha}T${form.value.hora}:00`)
  if (fechaHora <= ahora.value) { toast.error('No podés agendar en una fecha u hora pasada'); return }
  saving.value = true
  try {
    const { data } = await createMedicoTurno({
      paciente_id:      form.value.paciente_id,
      fecha_hora:       fechaHora.toISOString(),
      duracion_minutos: Number(form.value.duracion_minutos),
      tipo:             form.value.tipo,
      motivo:           form.value.motivo || undefined,
    })
    turnos.value.push(data)
    showCrear.value = false
    toast.success('Turno creado')
  } catch { toast.error('No se pudo crear el turno') }
  finally { saving.value = false }
}

function patchTurno(data) {
  const idx = turnos.value.findIndex(t => t.id === data.id)
  if (idx > -1) turnos.value[idx] = data
  if (turnoDetalle.value?.id === data.id) turnoDetalle.value = data
}

function abrirDetalle(t) {
  turnoDetalle.value = t
}

// ── Format helpers ────────────────────────────────────────────────────────────
function fmtHora(fechaHora) {
  return new Date(fechaHora).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}
function fmtFechaCompleta(fechaHora) {
  return new Date(fechaHora).toLocaleDateString('es-AR', {
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric',
  })
}
function fmtHoraFin(fechaHora, mins) {
  const d = new Date(fechaHora)
  d.setMinutes(d.getMinutes() + mins)
  return d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

// ── Load ──────────────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [tRes, pRes] = await Promise.all([
      getMedicoTurnos(),
      // El selector de pacientes del turno necesita la lista entera, no la primera página.
      getMedicoPacientes({ limite: 500 }),
    ])
    turnos.value    = tRes.data || []
    pacientes.value = pRes.data?.data ?? pRes.data ?? []
    getMedicoDisponibilidad()
      .then(dRes => { disponibilidad.value = dRes.data || [] })
      .catch(() => {})
  } catch (e) {
    toast.error('Error al cargar la agenda')
    console.error('[turnera] load error:', e)
  } finally { loading.value = false }

  tickInterval = setInterval(() => { ahora.value = new Date() }, 60000)
})

onUnmounted(() => clearInterval(tickInterval))
</script>

<template>
  <div class="tv">

    <!-- ── Header ── -->
    <div class="tv__header">
      <div class="tv__week-nav">
        <button class="tv__nav-btn" @click="semanaOff--" title="Semana anterior">
          <ChevronLeft :size="16" :stroke-width="2.5" />
        </button>
        <span class="tv__week-label">{{ semanaLabel }}</span>
        <button class="tv__nav-btn" @click="semanaOff++" title="Semana siguiente">
          <ChevronRight :size="16" :stroke-width="2.5" />
        </button>
        <button v-if="semanaOff !== 0" class="tv__hoy-btn" @click="semanaOff = 0">Hoy</button>
      </div>
      <button class="tv__new-btn" @click="abrirCrear">
        <Plus :size="15" :stroke-width="2.5" /> Nueva cita
      </button>
    </div>

    <!-- ── KPIs ── -->
    <div class="tv__kpis">
      <div class="tv__kpi">
        <span class="tv__kpi-val">{{ kpis.total }}</span>
        <span class="tv__kpi-lbl">Esta semana</span>
      </div>
      <div class="tv__kpi tv__kpi--warn">
        <span class="tv__kpi-val">{{ kpis.pendientes }}</span>
        <span class="tv__kpi-lbl">Pendientes</span>
      </div>
      <div class="tv__kpi tv__kpi--ok">
        <span class="tv__kpi-val">{{ kpis.realizados }}</span>
        <span class="tv__kpi-lbl">Realizados</span>
      </div>
      <div v-if="kpis.urgencias > 0" class="tv__kpi tv__kpi--danger">
        <span class="tv__kpi-val">{{ kpis.urgencias }}</span>
        <span class="tv__kpi-lbl">Urgencias</span>
      </div>
    </div>

    <!-- ── Loading ── -->
    <div v-if="loading" class="tv__loading">
      <DsSpinner :size="22" /> Cargando turnos…
    </div>

    <!-- ── Calendar ── -->
    <div v-else class="tv__calendar-wrap">
      <div class="tv__calendar">

        <!-- Time gutter -->
        <div class="tv__gutter">
          <div class="tv__gutter-spacer"></div>
          <div class="tv__gutter-body" :style="{ height: ALTURA_CAL + 'px' }">
            <div
              v-for="h in HORAS" :key="h"
              class="tv__hour-label"
              :style="{ top: ((h - H_INICIO) * 60 * PX_MIN) + 'px' }"
            >{{ h.toString().padStart(2,'0') }}:00</div>
          </div>
        </div>

        <!-- Day columns -->
        <div class="tv__days">
          <div
            v-for="(dia, idx) in diasSemana"
            :key="idx"
            class="tv__day"
            :class="{
              'tv__day--hoy':   esHoy(dia),
              'tv__day--pasado': esPasado(dia) && !esHoy(dia),
              'tv__day--weekend': idx >= 5,
            }"
          >
            <!-- Day header -->
            <div class="tv__day-header">
              <span class="tv__day-name">{{ DIAS_LABEL[idx] }}</span>
              <span class="tv__day-num" :class="{ 'tv__day-num--hoy': esHoy(dia) }">
                {{ dia.getDate() }}
              </span>
            </div>

            <!-- Day body — clickable for new turno -->
            <div
              class="tv__day-body"
              :style="{ height: ALTURA_CAL + 'px' }"
              :class="{ 'tv__day-body--past': esPasado(dia) }"
              @click="onClickSlot(dia, $event)"
            >
              <!-- Disponibilidad overlay (fuera de horario) -->
              <div
                v-for="(bloque, bi) in bloquesFueraDisponibilidad(dia)"
                :key="`disp-${bi}`"
                class="tv__nodisp-overlay"
                :style="{ top: bloque.top + 'px', height: bloque.height + 'px' }"
              ></div>

              <!-- Past overlay -->
              <div
                v-if="pastHeightForDay(dia) > 0"
                class="tv__past-overlay"
                :style="{ height: pastHeightForDay(dia) + 'px' }"
              ></div>

              <!-- Current time line (solo hoy) -->
              <template v-if="esHoy(dia) && currentTimeTop >= 0 && currentTimeTop <= ALTURA_CAL">
                <div class="tv__now-line" :style="{ top: currentTimeTop + 'px' }">
                  <div class="tv__now-dot"></div>
                </div>
              </template>

              <!-- Hour lines -->
              <div
                v-for="h in HORAS" :key="h"
                class="tv__hour-line"
                :style="{ top: ((h - H_INICIO) * 60 * PX_MIN) + 'px' }"
              ></div>
              <!-- Half-hour lines -->
              <div
                v-for="h in HORAS" :key="`h${h}`"
                class="tv__half-line"
                :style="{ top: ((h - H_INICIO) * 60 * PX_MIN + 30 * PX_MIN) + 'px' }"
              ></div>

              <!-- Turnos -->
              <div
                v-for="t in turnosDia(dia)"
                :key="t.id"
                class="tv__turno"
                :class="[
                  `tv__turno--${t.tipo}`,
                  `tv__turno--${t.estado}`,
                ]"
                :style="{
                  top:    turnoTop(t) + 'px',
                  height: turnoHeight(t) + 'px',
                }"
                @click.stop="abrirDetalle(t)"
                :title="`${t.paciente_nombre} · ${TIPO_CFG[t.tipo]?.label} · ${fmtHora(t.fecha_hora)}`"
              >
                <div class="tv__turno-hora">{{ fmtHora(t.fecha_hora) }}</div>
                <div class="tv__turno-nombre">{{ t.paciente_nombre }}</div>
                <div v-if="turnoHeight(t) > 40" class="tv__turno-tipo">{{ TIPO_CFG[t.tipo]?.label }}</div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>

    <!-- ── Modal: Crear turno ── -->
    <Teleport to="body">
      <Transition name="modal">
        <div v-modal="() => showCrear = false" v-if="showCrear" class="tv__overlay" @click.self="showCrear = false">
          <div class="tv__modal">
            <div class="tv__modal-header">
              <h3 class="tv__modal-title"><Calendar :size="16" /> Nueva cita</h3>
              <button class="tv__modal-close" @click="showCrear = false"><X :size="18" /></button>
            </div>

            <div class="tv__modal-body">

              <!-- Paciente -->
              <div class="tv__field">
                <label class="tv__label">Paciente <span class="tv__req">*</span></label>
                <template v-if="form.pacienteLabel">
                  <div class="tv__pac-selected">
                    <User2 :size="14" />
                    <span>{{ form.pacienteLabel }}</span>
                    <button class="tv__pac-clear" @click="() => { form.paciente_id = null; form.pacienteLabel = '' }">
                      <X :size="12" />
                    </button>
                  </div>
                </template>
                <template v-else>
                  <div class="tv__pac-search-wrap">
                    <input
                      v-model="searchPac"
                      @focus="pacOpen = true"
                      class="tv__input"
                      placeholder="Buscar por nombre o DNI…"
                      autocomplete="off"
                    />
                    <div v-if="pacOpen && pacFiltrados.length" class="tv__pac-dropdown">
                      <button
                        v-for="p in pacFiltrados" :key="p.id"
                        class="tv__pac-opt"
                        @mousedown.prevent="selectPaciente(p)"
                      >
                        <div class="tv__pac-opt-av">{{ (p.nombre?.[0]||'') + (p.apellido?.[0]||'') }}</div>
                        <div class="tv__pac-opt-info">
                          <span class="tv__pac-opt-name">{{ p.apellido }}, {{ p.nombre }}</span>
                          <span class="tv__pac-opt-dni">DNI {{ p.dni }}</span>
                        </div>
                      </button>
                    </div>
                  </div>
                </template>
              </div>

              <!-- Fecha + Hora -->
              <div class="tv__row-2">
                <div class="tv__field">
                  <label class="tv__label">Fecha <span class="tv__req">*</span></label>
                  <AppDatePicker v-model="form.fecha" :min="ahora.toISOString().split('T')[0]" />
                </div>
                <div class="tv__field">
                  <label class="tv__label">Hora</label>
                  <input v-model="form.hora" type="time" step="900" class="tv__input" />
                </div>
              </div>

              <!-- Duración + Tipo -->
              <div class="tv__row-2">
                <div class="tv__field">
                  <label class="tv__label">Duración</label>
                  <select v-model.number="form.duracion_minutos" class="tv__input tv__select">
                    <option :value="15">15 min</option>
                    <option :value="30">30 min</option>
                    <option :value="45">45 min</option>
                    <option :value="60">1 hora</option>
                    <option :value="90">1:30 h</option>
                  </select>
                </div>
                <div class="tv__field">
                  <label class="tv__label">Tipo de consulta</label>
                  <select v-model="form.tipo" class="tv__input tv__select">
                    <option value="primera_vez">Primera vez</option>
                    <option value="seguimiento">Seguimiento</option>
                    <option value="revision">Revisión</option>
                    <option value="urgencia">Urgencia</option>
                  </select>
                </div>
              </div>

              <!-- Motivo -->
              <div class="tv__field">
                <label class="tv__label">Motivo / notas (opcional)</label>
                <textarea v-model="form.motivo" class="tv__input tv__textarea" rows="2" placeholder="Motivo de la consulta…" />
              </div>
            </div>

            <div class="tv__modal-footer">
              <button class="tv__btn-ghost" @click="showCrear = false">Cancelar</button>
              <button class="tv__btn-primary" :disabled="saving" @click="crearTurno">
                <DsSpinner v-if="saving" :size="14" />
                <template v-else><Plus :size="14" /> Crear cita</template>
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ── Panel lateral: Detalle turno ── -->
    <TurnoDetallePanel
      v-if="turnoDetalle"
      :turno="turnoDetalle"
      @close="turnoDetalle = null"
      @updated="patchTurno"
    />

  </div>
</template>

<style scoped>
*, *::before, *::after { box-sizing: border-box; }

.tv {
  display: flex; flex-direction: column;
  height: calc(100vh - 54px);    /* 54px = topbar */
  overflow: hidden;
  font-family: system-ui, -apple-system, sans-serif;
}

/* ── Header ─────────────────────────────────────────────────────────────────── */
.tv__header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .75rem 1.25rem .5rem; flex-shrink: 0; gap: 1rem;
  background: #fff; border-bottom: 1px solid var(--c-slate-100);
}
.tv__week-nav { display: flex; align-items: center; gap: .5rem; }
.tv__nav-btn {
  width: 30px; height: 30px; border-radius: 7px; background: none;
  border: 1px solid var(--c-slate-200); cursor: pointer; display: flex; align-items: center;
  justify-content: center; color: var(--c-slate-600); transition: all .12s;
}
.tv__nav-btn:hover { background: var(--c-slate-50); border-color: var(--c-slate-400); }
.tv__week-label { font-size: .85rem; font-weight: 700; color: var(--c-slate-900); min-width: 150px; text-align: center; }
.tv__hoy-btn {
  font-size: .75rem; font-weight: 700; color: var(--c-leaf-800);
  background: var(--c-leaf-50); border: 1px solid #bbf7d0; border-radius: 6px;
  padding: .2rem .6rem; cursor: pointer; transition: all .12s;
}
.tv__hoy-btn:hover { background: #dcfce7; }
.tv__new-btn {
  display: flex; align-items: center; gap: .4rem;
  background: var(--c-leaf-800); color: #fff; border: none; border-radius: 8px;
  padding: .45rem .9rem; font-size: .82rem; font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.tv__new-btn:hover { background: var(--c-leaf-900); }

/* ── KPIs ────────────────────────────────────────────────────────────────────── */
.tv__kpis {
  display: flex; gap: .75rem; padding: .5rem 1.25rem;
  flex-shrink: 0; background: #fff; border-bottom: 1px solid var(--c-slate-100);
}
.tv__kpi {
  display: flex; align-items: center; gap: .5rem;
  padding: .3rem .75rem; border-radius: 8px;
  background: var(--c-slate-50); border: 1px solid var(--c-slate-100);
}
.tv__kpi--ok     { background: var(--c-leaf-50); border-color: #bbf7d0; }
.tv__kpi--warn   { background: #fefce8; border-color: #fde68a; }
.tv__kpi--danger { background: #fff5f5; border-color: #fecaca; }
.tv__kpi-val { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); line-height: 1; }
.tv__kpi--ok   .tv__kpi-val { color: #15803d; }
.tv__kpi--warn .tv__kpi-val { color: #92400e; }
.tv__kpi--danger .tv__kpi-val { color: #dc2626; }
.tv__kpi-lbl { font-size: .72rem; color: var(--c-slate-500); font-weight: 600; }

/* ── Loading ─────────────────────────────────────────────────────────────────── */
.tv__loading { display: flex; align-items: center; gap: .65rem; justify-content: center; padding: 3rem; color: var(--c-slate-500); }

/* ── Calendar layout ─────────────────────────────────────────────────────────── */
.tv__calendar-wrap { flex: 1; overflow-y: auto; overflow-x: auto; }
.tv__calendar { display: flex; min-width: 700px; }

/* Time gutter */
.tv__gutter { width: 52px; flex-shrink: 0; background: var(--c-slate-50); border-right: 1px solid #d1d5db; }
.tv__gutter-spacer { height: 42px; border-bottom: 1px solid #d1d5db; }
.tv__gutter-body { position: relative; }
.tv__hour-label {
  position: absolute; right: 8px;
  font-size: .68rem; color: var(--c-slate-500); font-weight: 700;
  transform: translateY(-50%);
  user-select: none;
}

/* Days */
.tv__days { flex: 1; display: grid; grid-template-columns: repeat(7, 1fr); min-width: 0; }
.tv__day { display: flex; flex-direction: column; border-left: 1px solid #d1d5db; }
.tv__day--weekend { background: var(--c-slate-50); }
.tv__day--weekend .tv__day-header { background: var(--c-slate-100); }
.tv__day--pasado { opacity: .6; }

.tv__day-header {
  height: 42px; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 1px; flex-shrink: 0;
  border-bottom: 2px solid #d1d5db;
  position: sticky; top: 0; background: #fff; z-index: 2;
}
.tv__day--hoy .tv__day-header { background: var(--c-leaf-50); border-bottom-color: #a7f3d0; }
.tv__day-name { font-size: .65rem; font-weight: 700; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .05em; }
.tv__day-num { font-size: .82rem; font-weight: 700; color: var(--c-slate-700); }
.tv__day-num--hoy {
  background: var(--c-leaf-800); color: #fff; width: 22px; height: 22px;
  border-radius: 50%; display: flex; align-items: center; justify-content: center;
  font-size: .75rem;
}

.tv__day-body {
  position: relative; cursor: crosshair;
  background: var(--c-leaf-50);   /* verde suave = disponible */
}
.tv__day-body--past { cursor: default; background: var(--c-slate-50); }

/* No-disponibilidad overlay — bien visible */
.tv__nodisp-overlay {
  position: absolute; left: 0; right: 0;
  background: repeating-linear-gradient(
    -45deg,
    rgba(100,116,139,.22) 0,
    rgba(100,116,139,.22) 3px,
    rgba(241,245,249,.92) 3px,
    rgba(241,245,249,.92) 9px
  );
  border-bottom: 1px solid rgba(148,163,184,.3);
  pointer-events: none; z-index: 2;
}

/* Past overlay */
.tv__past-overlay {
  position: absolute; top: 0; left: 0; right: 0;
  background: rgba(148, 163, 184, 0.13);
  pointer-events: none; z-index: 1;
}

/* Current time line */
.tv__now-line {
  position: absolute; left: 0; right: 0; z-index: 3;
  height: 2px; background: #ef4444;
  pointer-events: none;
}
.tv__now-dot {
  position: absolute; left: -4px; top: 50%;
  transform: translateY(-50%);
  width: 8px; height: 8px; border-radius: 50%;
  background: #ef4444;
}
.tv__hour-line {
  position: absolute; left: 0; right: 0; height: 1px;
  background: var(--c-slate-300); pointer-events: none;
}
.tv__half-line {
  position: absolute; left: 0; right: 0; height: 1px;
  background: var(--c-slate-200); pointer-events: none; border-top: 1px dashed var(--c-slate-200);
}

/* Turno cards */
.tv__turno {
  position: absolute; left: 2px; right: 2px;
  border-radius: 5px; padding: 3px 5px; cursor: pointer;
  overflow: hidden; transition: opacity .12s, box-shadow .12s;
  border-left: 3px solid; z-index: 2;
}
.tv__turno:hover { box-shadow: 0 2px 8px rgba(0,0,0,.15); opacity: .95; }
.tv__turno--primera_vez { background: #f5f3ff; border-left-color: #7c3aed; }
.tv__turno--seguimiento { background: var(--c-leaf-50); border-left-color: var(--c-leaf-800); }
.tv__turno--revision    { background: #eff6ff; border-left-color: #1d4ed8; }
.tv__turno--urgencia    { background: #fff5f5; border-left-color: #dc2626; }
.tv__turno--cancelado   { opacity: .4; text-decoration: line-through; }
.tv__turno--realizado   { opacity: .7; }

.tv__turno-hora   { font-size: .62rem; font-weight: 700; color: var(--c-slate-500); line-height: 1.2; }
.tv__turno-nombre { font-size: .7rem; font-weight: 700; color: var(--c-slate-900); line-height: 1.3; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.tv__turno-tipo   { font-size: .62rem; color: var(--c-slate-500); line-height: 1.2; }

/* ── Modal crear ─────────────────────────────────────────────────────────────── */
.tv__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.tv__modal {
  background: #fff; border-radius: 16px; width: 100%; max-width: 480px;
  box-shadow: 0 20px 60px rgba(0,0,0,.2); overflow: hidden;
}
.tv__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-slate-100);
}
.tv__modal-title { font-size: .95rem; font-weight: 800; color: var(--c-slate-900); display: flex; align-items: center; gap: .5rem; margin: 0; }
.tv__modal-close { background: none; border: none; cursor: pointer; color: var(--c-slate-400); border-radius: 6px; padding: .2rem; transition: color .12s; }
.tv__modal-close:hover { color: var(--c-slate-900); }
.tv__modal-body { padding: 1.1rem 1.25rem; display: flex; flex-direction: column; gap: .85rem; }
.tv__modal-footer { display: flex; justify-content: flex-end; gap: .6rem; padding: .9rem 1.25rem; border-top: 1px solid var(--c-slate-100); background: #fafafa; }

.tv__field { display: flex; flex-direction: column; gap: .3rem; }
.tv__label { font-size: .72rem; font-weight: 700; color: var(--c-slate-600); text-transform: uppercase; letter-spacing: .04em; }
.tv__req { color: #dc2626; }
.tv__row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.tv__input {
  width: 100%; padding: .5rem .65rem; border: 1.5px solid var(--c-slate-200);
  border-radius: 8px; font-size: .83rem; color: var(--c-slate-900); background: #fff;
  transition: border-color .15s; outline: none;
}
.tv__input:focus { border-color: var(--c-leaf-800); box-shadow: 0 0 0 3px rgba(26,61,46,.1); }
.tv__select { appearance: none; background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2394a3b8' stroke-width='2.5'%3E%3Cpolyline points='6 9 12 15 18 9'/%3E%3C/svg%3E"); background-repeat: no-repeat; background-position: right .6rem center; padding-right: 2rem; }
.tv__textarea { resize: vertical; min-height: 60px; }

/* Patient search */
.tv__pac-selected {
  display: flex; align-items: center; gap: .5rem;
  padding: .45rem .75rem; background: var(--c-leaf-50); border: 1.5px solid #bbf7d0;
  border-radius: 8px; font-size: .83rem; color: #166534; font-weight: 600;
}
.tv__pac-selected span { flex: 1; }
.tv__pac-clear { background: none; border: none; cursor: pointer; color: var(--c-slate-400); display: flex; align-items: center; }
.tv__pac-clear:hover { color: #dc2626; }
.tv__pac-search-wrap { position: relative; }
.tv__pac-dropdown {
  position: absolute; left: 0; right: 0; top: calc(100% + 4px);
  background: #fff; border: 1.5px solid var(--c-slate-200); border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0,0,0,.1); z-index: 10; overflow: hidden;
}
.tv__pac-opt {
  display: flex; align-items: center; gap: .6rem;
  padding: .55rem .75rem; width: 100%; background: none; border: none;
  cursor: pointer; text-align: left; transition: background .1s;
}
.tv__pac-opt:hover { background: var(--c-slate-50); }
.tv__pac-opt-av {
  width: 28px; height: 28px; border-radius: 50%; background: var(--c-leaf-800); color: #fff;
  font-size: .65rem; font-weight: 800; display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.tv__pac-opt-info { display: flex; flex-direction: column; gap: 1px; }
.tv__pac-opt-name { font-size: .8rem; font-weight: 600; color: var(--c-slate-900); }
.tv__pac-opt-dni  { font-size: .7rem; color: var(--c-slate-400); }

/* Buttons */
.tv__btn-primary {
  display: inline-flex; align-items: center; gap: .35rem;
  background: var(--c-leaf-800); color: #fff; border: none; border-radius: 8px;
  padding: .5rem 1rem; font-size: .83rem; font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.tv__btn-primary:hover:not(:disabled) { background: var(--c-leaf-900); }
.tv__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.tv__btn-ghost {
  background: none; border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  padding: .5rem .9rem; font-size: .83rem; font-weight: 600; color: var(--c-slate-500);
  cursor: pointer; transition: all .15s;
}
.tv__btn-ghost:hover { border-color: var(--c-slate-400); color: var(--c-slate-700); }
.tv__btn-xs { padding: .35rem .7rem !important; font-size: .75rem !important; }

/* ── Detail panel ────────────────────────────────────────────────────────────── */
.tv__detail-overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.3); z-index: 900;
  display: flex; justify-content: flex-end;
}
.tv__detail {
  width: 380px; max-width: 95vw; height: 100%; background: #fff;
  box-shadow: -4px 0 24px rgba(0,0,0,.15);
  overflow-y: auto; display: flex; flex-direction: column; gap: 0;
}
.tv__detail-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: .9rem 1.1rem; border-bottom: 1px solid var(--c-slate-100);
  position: sticky; top: 0; background: #fff; z-index: 2;
}
.tv__detail-tipo {
  font-size: .72rem; font-weight: 800; padding: .25em .75em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .05em;
}
.tv__detail-pac {
  display: flex; align-items: center; gap: .75rem;
  padding: 1rem 1.1rem; border-bottom: 1px solid var(--c-slate-100);
}
.tv__detail-av {
  width: 44px; height: 44px; border-radius: 50%; flex-shrink: 0;
  background: linear-gradient(135deg, var(--c-leaf-800), var(--c-leaf-600));
  color: #fff; font-size: .8rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
}
.tv__detail-pac-info { display: flex; flex-direction: column; gap: .15rem; }
.tv__detail-pac-nombre { font-size: .9rem; font-weight: 800; color: var(--c-slate-900); }
.tv__detail-ficha-link {
  font-size: .75rem; font-weight: 600; color: var(--c-leaf-800); background: none; border: none;
  cursor: pointer; padding: 0; text-decoration: underline; text-underline-offset: 2px;
}
.tv__detail-ficha-link:hover { color: var(--c-leaf-900); }

.tv__detail-info-grid {
  display: flex; flex-direction: column; gap: .65rem;
  padding: 1rem 1.1rem; border-bottom: 1px solid var(--c-slate-100);
}
.tv__detail-item { display: flex; flex-direction: column; gap: .15rem; }
.tv__detail-item--full { }
.tv__detail-lbl { font-size: .65rem; font-weight: 800; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .05em; }
.tv__detail-val { font-size: .82rem; color: #1e293b; font-weight: 500; }
.tv__detail-val--text { white-space: pre-wrap; color: var(--c-slate-600); font-weight: 400; line-height: 1.5; }
.tv__detail-dur { font-size: .72rem; color: var(--c-slate-400); margin-left: .25rem; }

/* Estado badge */
.tv__estado-badge {
  display: inline-block; font-size: .7rem; font-weight: 700;
  padding: .2em .7em; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em;
}
.est--prog { background: var(--c-slate-100); color: var(--c-slate-600); }
.est--conf { background: #dcfce7; color: #166534; }
.est--real { background: #d1fae5; color: #065f46; }
.est--canc { background: #fee2e2; color: #991b1b; }
.est--aus  { background: #fef3c7; color: #92400e; }

.tv__detail-acciones {
  display: flex; flex-wrap: wrap; gap: .5rem;
  padding: .9rem 1.1rem; border-bottom: 1px solid var(--c-slate-100);
}
.tv__accion {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .4rem .8rem; border-radius: 8px; font-size: .78rem; font-weight: 700;
  cursor: pointer; border: 1.5px solid; transition: all .15s;
}
.tv__accion--ok      { background: var(--c-leaf-50); color: #166534; border-color: #bbf7d0; }
.tv__accion--ok:hover { background: #dcfce7; }
.tv__accion--primary { background: var(--c-leaf-50); color: var(--c-leaf-800); border-color: var(--c-leaf-800); }
.tv__accion--primary:hover { background: var(--c-leaf-800); color: #fff; }
.tv__accion--warn    { background: #fefce8; color: #92400e; border-color: #fde68a; }
.tv__accion--warn:hover { background: #fef3c7; }
.tv__accion--danger  { background: #fff5f5; color: #dc2626; border-color: #fecaca; }
.tv__accion--danger:hover { background: #fee2e2; }
.tv__accion--reprog  { background: #eff6ff; color: #1d4ed8; border-color: #bfdbfe; }
.tv__accion--reprog:hover { background: #dbeafe; }

/* Form reprogramar */
.tv__reprog-form {
  margin: 0 .9rem .9rem;
  background: #f0f9ff; border: 1.5px solid #bae6fd; border-radius: 10px;
  padding: .8rem .9rem; display: flex; flex-direction: column; gap: .6rem;
}
.tv__reprog-title { font-size: .75rem; font-weight: 700; color: #0369a1; margin-bottom: .1rem; }
.tv__reprog-fields { display: flex; flex-direction: column; gap: .4rem; }
.tv__reprog-field { display: flex; flex-direction: column; gap: .2rem; }

.tv__detail-notas { padding: .9rem 1.1rem; flex: 1; }
.tv__detail-notas-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .5rem; }
.tv__notas-edit {
  display: flex; align-items: center; gap: .3rem; font-size: .72rem; font-weight: 600;
  color: var(--c-slate-500); background: none; border: 1px solid var(--c-slate-200); border-radius: 6px;
  padding: .15rem .5rem; cursor: pointer; transition: all .12s;
}
.tv__notas-edit:hover { color: var(--c-leaf-800); border-color: var(--c-leaf-800); }
.tv__notas-actions { display: flex; gap: .5rem; margin-top: .5rem; }
.tv__detail-notas-text { font-size: .82rem; color: var(--c-slate-600); white-space: pre-wrap; line-height: 1.6; margin: 0; }
.tv__detail-notas-empty { font-size: .8rem; color: var(--c-slate-400); font-style: italic; margin: 0; }

/* Transitions */
.modal-enter-active, .modal-leave-active { transition: opacity .2s; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-active .tv__modal, .modal-leave-active .tv__modal { transition: transform .2s; }
.modal-enter-from .tv__modal, .modal-leave-to .tv__modal { transform: scale(.96) translateY(-8px); }

.slide-right-enter-active, .slide-right-leave-active { transition: opacity .2s; }
.slide-right-enter-from, .slide-right-leave-to { opacity: 0; }
.slide-right-enter-active .tv__detail, .slide-right-leave-active .tv__detail { transition: transform .25s cubic-bezier(.4,0,.2,1); }
.slide-right-enter-from .tv__detail, .slide-right-leave-to .tv__detail { transform: translateX(100%); }
</style>
