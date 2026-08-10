<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { getAdminMedicoDisponibilidad, getAdminMedicoTurnos } from '../../lib/api.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { ChevronLeft, ChevronRight, X, User2 } from 'lucide-vue-next'

const props = defineProps({ medicoId: { type: Number, required: true } })

// ── Config ────────────────────────────────────────────────
const H_INICIO   = 8
const H_FIN      = 21
const PX_MIN     = 1.2
const ALTURA_CAL = (H_FIN - H_INICIO) * 60 * PX_MIN

const HORAS      = Array.from({ length: H_FIN - H_INICIO }, (_, i) => H_INICIO + i)
const DIAS_LABEL = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']

const TIPO_CFG = {
  primera_vez: { label: 'Primera vez', color: '#7c3aed', bg: '#f5f3ff' },
  seguimiento: { label: 'Seguimiento', color: '#1b5e20', bg: '#f0fdf4' },
  revision:    { label: 'Revisión',    color: '#1d4ed8', bg: '#eff6ff' },
  urgencia:    { label: 'Urgencia',    color: '#dc2626', bg: '#fff5f5' },
}
const ESTADO_CFG = {
  programado: { label: 'Programado', cls: 'est--prog' },
  confirmado: { label: 'Confirmado', cls: 'est--conf' },
  realizado:  { label: 'Realizado',  cls: 'est--real' },
  cancelado:  { label: 'Cancelado',  cls: 'est--canc' },
  ausente:    { label: 'Ausente',    cls: 'est--aus'  },
}

// ── State ─────────────────────────────────────────────────
const loading        = ref(true)
const semanaOff      = ref(0)
const turnos         = ref([])
const disponibilidad = ref([])
const turnoDetalle   = ref(null)

const ahora = ref(new Date())
let tick = null

// ── Week navigation ───────────────────────────────────────
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

function esHoy(d)    { return d.toDateString() === new Date().toDateString() }
function esPasado(d) { return d < new Date(new Date().setHours(0, 0, 0, 0)) }

const currentTimeTop = computed(() => {
  const h = ahora.value.getHours(), m = ahora.value.getMinutes()
  return (h * 60 + m - H_INICIO * 60) * PX_MIN
})

function pastHeightForDay(dia) {
  if (esPasado(dia)) return ALTURA_CAL
  if (!esHoy(dia))   return 0
  return Math.min(currentTimeTop.value, ALTURA_CAL)
}

// ── Availability overlay ──────────────────────────────────
function bloquesFueraDisponibilidad(dia) {
  if (!disponibilidad.value.length) return []
  const dow   = (dia.getDay() + 6) % 7
  const slots = disponibilidad.value.filter(s => s.dia_semana === dow).sort((a, b) => a.hora_inicio - b.hora_inicio)
  if (!slots.length) return [{ top: 0, height: ALTURA_CAL }]
  const bloques = [], calIni = H_INICIO * 60
  let cursor = calIni
  for (const s of slots) {
    const ini = Math.max(s.hora_inicio, calIni)
    const fin = Math.min(s.hora_fin, H_FIN * 60)
    if (ini > cursor) bloques.push({ top: (cursor - calIni) * PX_MIN, height: (ini - cursor) * PX_MIN })
    cursor = Math.max(cursor, fin)
  }
  if (cursor < H_FIN * 60) bloques.push({ top: (cursor - calIni) * PX_MIN, height: (H_FIN * 60 - cursor) * PX_MIN })
  return bloques
}

// ── Turno helpers ─────────────────────────────────────────
function turnoTop(t)    { const d = new Date(t.fecha_hora); return Math.max(0, (d.getHours() * 60 + d.getMinutes() - H_INICIO * 60) * PX_MIN) }
function turnoHeight(t) { return Math.max(t.duracion_minutos * PX_MIN, 28) }
function turnosDia(dia) {
  return turnos.value
    .filter(t => new Date(t.fecha_hora).toDateString() === dia.toDateString())
    .sort((a, b) => new Date(a.fecha_hora) - new Date(b.fecha_hora))
}

// ── KPIs ─────────────────────────────────────────────────
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

// ── Format helpers ────────────────────────────────────────
function fmtHora(fh)          { return new Date(fh).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) }
function fmtFechaCompleta(fh) { return new Date(fh).toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) }
function fmtHoraFin(fh, mins) { const d = new Date(fh); d.setMinutes(d.getMinutes() + mins); return d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) }

// ── Load ──────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [tRes, dRes] = await Promise.all([
      getAdminMedicoTurnos(props.medicoId),
      getAdminMedicoDisponibilidad(props.medicoId),
    ])
    turnos.value        = tRes.data || []
    disponibilidad.value = dRes.data || []
  } finally { loading.value = false }
  tick = setInterval(() => { ahora.value = new Date() }, 60000)
})
onUnmounted(() => clearInterval(tick))
</script>

<template>
  <div class="cw">

    <!-- Nav + KPIs -->
    <div class="cw__top">
      <div class="cw__nav">
        <button class="cw__nav-btn" @click="semanaOff--"><ChevronLeft :size="15" :stroke-width="2.5" /></button>
        <span class="cw__week-lbl">{{ semanaLabel }}</span>
        <button class="cw__nav-btn" @click="semanaOff++"><ChevronRight :size="15" :stroke-width="2.5" /></button>
        <button v-if="semanaOff !== 0" class="cw__hoy-btn" @click="semanaOff = 0">Hoy</button>
      </div>
      <div class="cw__kpis">
        <div class="cw__kpi">
          <span class="cw__kpi-val">{{ kpis.total }}</span>
          <span class="cw__kpi-lbl">Esta semana</span>
        </div>
        <div class="cw__kpi cw__kpi--warn">
          <span class="cw__kpi-val">{{ kpis.pendientes }}</span>
          <span class="cw__kpi-lbl">Pendientes</span>
        </div>
        <div class="cw__kpi cw__kpi--ok">
          <span class="cw__kpi-val">{{ kpis.realizados }}</span>
          <span class="cw__kpi-lbl">Realizados</span>
        </div>
        <div v-if="kpis.urgencias > 0" class="cw__kpi cw__kpi--danger">
          <span class="cw__kpi-val">{{ kpis.urgencias }}</span>
          <span class="cw__kpi-lbl">Urgencias</span>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="cw__loading"><DsSpinner :size="22" /></div>

    <!-- Calendar -->
    <div v-else class="cw__cal-wrap">
      <div class="cw__cal">

        <!-- Gutter -->
        <div class="cw__gutter">
          <div class="cw__gutter-spacer"></div>
          <div class="cw__gutter-body" :style="{ height: ALTURA_CAL + 'px' }">
            <div
              v-for="h in HORAS" :key="h"
              class="cw__hour-label"
              :style="{ top: ((h - H_INICIO) * 60 * PX_MIN) + 'px' }"
            >{{ h.toString().padStart(2, '0') }}:00</div>
          </div>
        </div>

        <!-- Day columns -->
        <div class="cw__days">
          <div
            v-for="(dia, idx) in diasSemana"
            :key="idx"
            class="cw__day"
            :class="{
              'cw__day--hoy':     esHoy(dia),
              'cw__day--pasado':  esPasado(dia) && !esHoy(dia),
              'cw__day--weekend': idx >= 5,
            }"
          >
            <div class="cw__day-header">
              <span class="cw__day-name">{{ DIAS_LABEL[idx] }}</span>
              <span class="cw__day-num" :class="{ 'cw__day-num--hoy': esHoy(dia) }">{{ dia.getDate() }}</span>
            </div>

            <div class="cw__day-body" :style="{ height: ALTURA_CAL + 'px' }">

              <!-- Disponibilidad overlay -->
              <div
                v-for="(bloque, bi) in bloquesFueraDisponibilidad(dia)"
                :key="`d${bi}`"
                class="cw__nodisp"
                :style="{ top: bloque.top + 'px', height: bloque.height + 'px' }"
              ></div>

              <!-- Past overlay -->
              <div v-if="pastHeightForDay(dia) > 0" class="cw__past" :style="{ height: pastHeightForDay(dia) + 'px' }"></div>

              <!-- Current time -->
              <template v-if="esHoy(dia) && currentTimeTop >= 0 && currentTimeTop <= ALTURA_CAL">
                <div class="cw__now" :style="{ top: currentTimeTop + 'px' }">
                  <div class="cw__now-dot"></div>
                </div>
              </template>

              <!-- Hour + half lines -->
              <div v-for="h in HORAS" :key="h" class="cw__hour-line" :style="{ top: ((h - H_INICIO) * 60 * PX_MIN) + 'px' }"></div>
              <div v-for="h in HORAS" :key="`h${h}`" class="cw__half-line" :style="{ top: ((h - H_INICIO) * 60 * PX_MIN + 30 * PX_MIN) + 'px' }"></div>

              <!-- Turnos -->
              <div
                v-for="t in turnosDia(dia)"
                :key="t.id"
                class="cw__turno"
                :class="[`cw__turno--${t.tipo}`, `cw__turno--${t.estado}`]"
                :style="{ top: turnoTop(t) + 'px', height: turnoHeight(t) + 'px' }"
                @click.stop="turnoDetalle = turnoDetalle?.id === t.id ? null : t"
                :title="`${t.paciente_nombre} · ${TIPO_CFG[t.tipo]?.label} · ${fmtHora(t.fecha_hora)}`"
              >
                <div class="cw__turno-hora">{{ fmtHora(t.fecha_hora) }}</div>
                <div class="cw__turno-nombre">{{ t.paciente_nombre }}</div>
                <div v-if="turnoHeight(t) > 42" class="cw__turno-tipo">{{ TIPO_CFG[t.tipo]?.label }}</div>
              </div>

            </div>
          </div>
        </div>

      </div>
    </div>

    <!-- Detalle turno (read-only) -->
    <Teleport to="body">
      <Transition name="slide-right">
        <div v-if="turnoDetalle" class="cw__det-overlay" @click.self="turnoDetalle = null">
          <div class="cw__det">
            <div class="cw__det-hdr">
              <div class="cw__det-tipo" :style="{ background: TIPO_CFG[turnoDetalle.tipo]?.bg, color: TIPO_CFG[turnoDetalle.tipo]?.color }">
                {{ TIPO_CFG[turnoDetalle.tipo]?.label }}
              </div>
              <span class="cw__det-est" :class="ESTADO_CFG[turnoDetalle.estado]?.cls">
                {{ ESTADO_CFG[turnoDetalle.estado]?.label }}
              </span>
              <button class="cw__det-close" @click="turnoDetalle = null"><X :size="17" /></button>
            </div>

            <div class="cw__det-pac">
              <div class="cw__det-av">
                {{ (turnoDetalle.paciente_nombre?.split(' ').map(w => w[0]).join('').slice(0, 2) || 'P').toUpperCase() }}
              </div>
              <div class="cw__det-pac-nombre">{{ turnoDetalle.paciente_nombre }}</div>
            </div>

            <dl class="cw__det-dl">
              <dt>Fecha</dt>
              <dd>{{ fmtFechaCompleta(turnoDetalle.fecha_hora) }}</dd>
              <dt>Horario</dt>
              <dd>{{ fmtHora(turnoDetalle.fecha_hora) }} – {{ fmtHoraFin(turnoDetalle.fecha_hora, turnoDetalle.duracion_minutos) }}</dd>
              <dt>Duración</dt>
              <dd>{{ turnoDetalle.duracion_minutos }} min</dd>
              <dt v-if="turnoDetalle.motivo">Motivo</dt>
              <dd v-if="turnoDetalle.motivo">{{ turnoDetalle.motivo }}</dd>
            </dl>

            <p class="cw__det-readonly-note">Vista de solo lectura — gestioná el turno desde el perfil del paciente.</p>
          </div>
        </div>
      </Transition>
    </Teleport>

  </div>
</template>

<style scoped>
.cw { display: flex; flex-direction: column; }

/* Nav + KPIs */
.cw__top { display: flex; align-items: center; gap: 1.25rem; padding: .875rem 1.25rem; border-bottom: 1px solid var(--c-slate-100); flex-wrap: wrap; }
.cw__nav { display: flex; align-items: center; gap: .35rem; }
.cw__nav-btn { display: flex; align-items: center; justify-content: center; width: 28px; height: 28px; border: 1px solid var(--c-slate-200); border-radius: 7px; background: #fff; color: var(--c-slate-600); cursor: pointer; transition: all .15s; }
.cw__nav-btn:hover { background: var(--c-slate-100); border-color: var(--c-slate-300); }
.cw__week-lbl { font-size: .82rem; font-weight: 600; color: var(--c-slate-900); min-width: 140px; text-align: center; }
.cw__hoy-btn { border: none; background: var(--c-slate-100); color: var(--c-slate-600); padding: .25rem .7rem; border-radius: 7px; font-size: .72rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.cw__hoy-btn:hover { background: var(--c-slate-200); }
.cw__kpis { display: flex; gap: .75rem; margin-left: auto; flex-wrap: wrap; }
.cw__kpi { display: flex; flex-direction: column; align-items: center; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 8px; padding: .35rem .75rem; min-width: 56px; }
.cw__kpi--warn   { background: #fffbeb; border-color: #fde68a; }
.cw__kpi--ok     { background: #f0fdf4; border-color: #bbf7d0; }
.cw__kpi--danger { background: #fff5f5; border-color: #fecaca; }
.cw__kpi-val { font-size: 1.1rem; font-weight: 800; color: var(--c-slate-900); line-height: 1.1; }
.cw__kpi--warn   .cw__kpi-val { color: #92400e; }
.cw__kpi--ok     .cw__kpi-val { color: #15803d; }
.cw__kpi--danger .cw__kpi-val { color: #dc2626; }
.cw__kpi-lbl { font-size: .6rem; font-weight: 600; color: var(--c-slate-400); text-transform: uppercase; letter-spacing: .04em; margin-top: .1rem; }

/* Loading */
.cw__loading { display: flex; justify-content: center; padding: 3rem; }

/* Calendar wrap — scrollable */
.cw__cal-wrap { overflow-x: auto; }
.cw__cal { display: flex; min-width: 600px; }

/* Gutter */
.cw__gutter { width: 48px; flex-shrink: 0; }
.cw__gutter-spacer { height: 48px; border-bottom: 1px solid var(--c-slate-200); }
.cw__gutter-body { position: relative; }
.cw__hour-label { position: absolute; right: 8px; font-size: .62rem; color: var(--c-slate-400); transform: translateY(-50%); white-space: nowrap; }

/* Days */
.cw__days { display: flex; flex: 1; border-left: 1px solid var(--c-slate-200); }
.cw__day { flex: 1; border-right: 1px solid var(--c-slate-200); min-width: 80px; }
.cw__day--weekend { background: #fafbfc; }
.cw__day--hoy .cw__day-header { background: #f0fdf4; }
.cw__day-header { height: 48px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: .1rem; border-bottom: 1px solid var(--c-slate-200); background: var(--c-slate-50); }
.cw__day-name { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: var(--c-slate-500); }
.cw__day-num { font-size: .95rem; font-weight: 700; color: #374151; line-height: 1; }
.cw__day-num--hoy { width: 26px; height: 26px; background: #15803d; color: #fff; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: .82rem; }

/* Day body */
.cw__day-body { position: relative; background: #fff; }
.cw__day--weekend .cw__day-body { background: #fafbfc; }

/* Overlays */
.cw__nodisp {
  position: absolute; left: 0; right: 0; z-index: 1; pointer-events: none;
  background: repeating-linear-gradient(-45deg,
    rgba(100,116,139,.2) 0, rgba(100,116,139,.2) 3px,
    rgba(241,245,249,.9) 3px, rgba(241,245,249,.9) 9px);
}
.cw__past { position: absolute; top: 0; left: 0; right: 0; z-index: 1; background: rgba(241,245,249,.55); pointer-events: none; }
.cw__now  { position: absolute; left: 0; right: 0; z-index: 5; height: 2px; background: #ef4444; }
.cw__now-dot { width: 8px; height: 8px; background: #ef4444; border-radius: 50%; margin-top: -3px; margin-left: -4px; }

/* Grid lines */
.cw__hour-line { position: absolute; left: 0; right: 0; height: 1px; background: var(--c-slate-200); z-index: 0; }
.cw__half-line { position: absolute; left: 0; right: 0; height: 1px; background: var(--c-slate-100); z-index: 0; }

/* Turnos */
.cw__turno {
  position: absolute; left: 3px; right: 3px; z-index: 3;
  border-radius: 6px; padding: 3px 6px; cursor: pointer;
  overflow: hidden; border-left: 3px solid;
  transition: box-shadow .15s, transform .1s;
  background: #eff6ff; border-left-color: #1d4ed8; color: #1d4ed8;
}
.cw__turno:hover { box-shadow: 0 2px 8px rgba(0,0,0,.12); transform: translateX(1px); }
.cw__turno--primera_vez { background: #f5f3ff; border-left-color: #7c3aed; color: #7c3aed; }
.cw__turno--seguimiento { background: #f0fdf4; border-left-color: #15803d; color: #15803d; }
.cw__turno--revision    { background: #eff6ff; border-left-color: #1d4ed8; color: #1d4ed8; }
.cw__turno--urgencia    { background: #fff5f5; border-left-color: #dc2626; color: #dc2626; }
.cw__turno--cancelado   { opacity: .45; text-decoration: line-through; }
.cw__turno--realizado   { opacity: .65; }
.cw__turno-hora   { font-size: .62rem; font-weight: 700; opacity: .8; }
.cw__turno-nombre { font-size: .7rem;  font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cw__turno-tipo   { font-size: .6rem;  opacity: .7; }

/* Detail panel */
.cw__det-overlay { position: fixed; inset: 0; z-index: 1100; background: transparent; }
.cw__det {
  position: fixed; top: 0; right: 0; bottom: 0; width: 300px;
  background: #fff; border-left: 1px solid var(--c-slate-200);
  box-shadow: -4px 0 24px rgba(0,0,0,.1);
  display: flex; flex-direction: column; z-index: 1101; overflow-y: auto;
}
.cw__det-hdr { display: flex; align-items: center; gap: .5rem; padding: 1rem; border-bottom: 1px solid var(--c-slate-100); }
.cw__det-tipo { font-size: .72rem; font-weight: 700; padding: .3em .75em; border-radius: 999px; }
.cw__det-close { margin-left: auto; background: none; border: none; cursor: pointer; color: var(--c-slate-400); display: flex; align-items: center; }
.cw__det-close:hover { color: #374151; }
.cw__det-pac { display: flex; align-items: center; gap: .875rem; padding: 1rem 1rem .5rem; }
.cw__det-av { width: 40px; height: 40px; border-radius: 12px; background: #1b5e20; color: #fff; display: flex; align-items: center; justify-content: center; font-size: .85rem; font-weight: 700; flex-shrink: 0; }
.cw__det-pac-nombre { font-size: .9rem; font-weight: 700; color: var(--c-slate-900); }
.cw__det-dl { display: grid; grid-template-columns: auto 1fr; gap: .45rem .75rem; padding: .75rem 1rem 1rem; margin: 0; }
.cw__det-dl dt { font-size: .72rem; color: var(--c-slate-400); font-weight: 500; align-self: start; padding-top: .05rem; }
.cw__det-dl dd { font-size: .82rem; color: var(--c-slate-900); font-weight: 500; margin: 0; }
.cw__det-readonly-note { font-size: .72rem; color: var(--c-slate-400); padding: .75rem 1rem; margin: auto 0 0; border-top: 1px solid var(--c-slate-100); line-height: 1.5; }

/* Estado chips in detail */
.est--prog { background: #dbeafe; color: #1d4ed8; font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; }
.est--conf { background: #d1fae5; color: #065f46; font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; }
.est--real { background: #f0fdf4; color: #15803d; font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; border: 1px solid #bbf7d0; }
.est--canc { background: #fee2e2; color: #dc2626; font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; }
.est--aus  { background: #fef3c7; color: #b45309; font-size: .65rem; font-weight: 700; padding: .2em .55em; border-radius: 999px; }

/* Transitions */
.slide-right-enter-active, .slide-right-leave-active { transition: transform .25s ease; }
.slide-right-enter-from, .slide-right-leave-to { transform: translateX(100%); }
</style>
