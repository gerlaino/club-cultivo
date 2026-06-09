<template>
  <div class="mpd">

    <!-- Header -->
    <div class="mpd__header">
      <div>
        <h1 class="mpd__title">
          {{ saludo }}, {{ auth.user?.first_name || 'Doctor' }}
        </h1>
        <p class="mpd__sub">{{ fechaHoy }}</p>
      </div>
      <div class="mpd__actions">
        <RouterLink to="/medico/turnos" class="mpd__btn-secondary">
          <Calendar :size="15" :stroke-width="1.75" /> Turnera
        </RouterLink>
        <RouterLink to="/medico/indicaciones" class="mpd__btn-primary">
          <FilePlus :size="15" :stroke-width="1.75" /> Nueva indicación
        </RouterLink>
      </div>
    </div>

    <!-- KPIs -->
    <div class="mpd__kpis">
      <RouterLink to="/medico/turnos" class="mpd__kpi mpd__kpi--green">
        <Calendar :size="20" :stroke-width="1.5" />
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : turnosHoy.length }}</div>
          <div class="mpd__kpi-lbl">Turnos hoy</div>
        </div>
      </RouterLink>
      <RouterLink to="/medico/pacientes" class="mpd__kpi">
        <Users :size="20" :stroke-width="1.5" />
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : kpis.total }}</div>
          <div class="mpd__kpi-lbl">Pacientes</div>
        </div>
      </RouterLink>
      <RouterLink to="/medico/pacientes" class="mpd__kpi mpd__kpi--orange">
        <ShieldAlert :size="20" :stroke-width="1.5" />
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : kpis.reproAlertas }}</div>
          <div class="mpd__kpi-lbl">Alertas REPROCANN</div>
        </div>
      </RouterLink>
      <RouterLink to="/medico/indicaciones" class="mpd__kpi mpd__kpi--purple">
        <FileHeart :size="20" :stroke-width="1.5" />
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : kpis.indPorVencer }}</div>
          <div class="mpd__kpi-lbl">Indicaciones ×vencer</div>
        </div>
      </RouterLink>
    </div>

    <!-- Cuerpo dos columnas -->
    <div v-if="!loading" class="mpd__body">

      <!-- Columna izquierda: Turnos de hoy -->
      <div class="mpd__col">
        <div class="mpd__section-head">
          <h2 class="mpd__section-title"><Clock :size="14" /> Turnos de hoy</h2>
          <RouterLink to="/medico/turnos" class="mpd__section-link">Ver turnera →</RouterLink>
        </div>

        <div v-if="turnosHoy.length === 0" class="mpd__empty-col">
          <Calendar :size="28" :stroke-width="1" />
          <p>Sin turnos para hoy</p>
          <RouterLink to="/medico/turnos" class="mpd__btn-ghost mpd__btn-sm">Agendar cita</RouterLink>
        </div>

        <div v-else class="mpd__turno-list">
          <div
            v-for="t in turnosHoy"
            :key="t.id"
            class="mpd__turno"
            :class="`mpd__turno--${t.tipo}`"
          >
            <div class="mpd__turno-hora">{{ fmtHora(t.fecha_hora) }}</div>
            <div class="mpd__turno-info">
              <div class="mpd__turno-nombre">{{ t.paciente_nombre }}</div>
              <div class="mpd__turno-tipo">{{ TIPO_LABEL[t.tipo] }}</div>
            </div>
            <span class="mpd__est-badge" :class="`mpd__est--${t.estado}`">
              {{ ESTADO_LABEL[t.estado] }}
            </span>
          </div>
        </div>
      </div>

      <!-- Columna derecha: Alertas -->
      <div class="mpd__col">
        <div class="mpd__section-head">
          <h2 class="mpd__section-title"><AlertTriangle :size="14" /> Alertas clínicas</h2>
        </div>

        <div v-if="!alertas.length && !indPorVencer.length" class="mpd__empty-col">
          <CheckCircle :size="28" :stroke-width="1" />
          <p>Sin alertas activas</p>
        </div>

        <!-- REPROCANN -->
        <template v-if="alertas.length">
          <p class="mpd__alert-subtitle">REPROCANN</p>
          <div class="mpd__alert-list">
            <RouterLink
              v-for="p in alertas"
              :key="p.id"
              :to="`/medico/pacientes/${p.id}/ficha`"
              class="mpd__alert-row"
              :class="diasHasta(p.reprocann_vencimiento) < 0 ? 'mpd__alert-row--danger' : 'mpd__alert-row--warn'"
            >
              <div class="mpd__alert-av">{{ iniciales(p) }}</div>
              <div class="mpd__alert-info">
                <span class="mpd__alert-name">{{ p.apellido }}, {{ p.nombre }}</span>
              </div>
              <span class="mpd__alert-badge" :class="diasHasta(p.reprocann_vencimiento) < 0 ? 'mpd__badge--danger' : 'mpd__badge--warn'">
                {{ diasHasta(p.reprocann_vencimiento) < 0 ? 'Vencido' : `${diasHasta(p.reprocann_vencimiento)}d` }}
              </span>
            </RouterLink>
          </div>
        </template>

        <!-- Indicaciones -->
        <template v-if="indPorVencer.length">
          <p class="mpd__alert-subtitle" style="margin-top: .85rem;">Indicaciones</p>
          <div class="mpd__alert-list">
            <RouterLink
              v-for="ind in indPorVencer"
              :key="ind.id"
              :to="`/medico/pacientes/${ind.paciente?.id}/ficha`"
              class="mpd__alert-row mpd__alert-row--warn"
            >
              <div class="mpd__alert-av mpd__alert-av--purple">{{ iniciales(ind.paciente || {}) }}</div>
              <div class="mpd__alert-info">
                <span class="mpd__alert-name">{{ ind.paciente?.nombre_completo || '—' }}</span>
                <span class="mpd__alert-meta">{{ ind.patologia }}</span>
              </div>
              <span class="mpd__alert-badge mpd__badge--warn">{{ formatDate(ind.fecha_vencimiento) }}</span>
            </RouterLink>
          </div>
        </template>
      </div>

    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  Users, AlertTriangle, Clock, ShieldAlert, FilePlus, FileHeart,
  CheckCircle, Calendar,
} from 'lucide-vue-next'
import { listPacientes, getMedicoTurnos } from '../../lib/api.js'
import api from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

const loading      = ref(true)
const pacientes    = ref([])
const indicaciones = ref([])
const turnos       = ref([])

const TIPO_LABEL  = { primera_vez: 'Primera vez', seguimiento: 'Seguimiento', revision: 'Revisión', urgencia: 'Urgencia' }
const ESTADO_LABEL = { programado: 'Pendiente', confirmado: 'Confirmado', realizado: 'Realizado', cancelado: 'Cancelado', ausente: 'Ausente' }

async function cargar() {
  try {
    const [pRes, iRes, tRes] = await Promise.all([
      listPacientes(),
      api.get('/indicaciones_medicas').catch(() => ({ data: [] })),
      getMedicoTurnos().catch(() => ({ data: [] })),
    ])
    pacientes.value    = pRes.data?.data ?? pRes.data ?? []
    indicaciones.value = iRes.data ?? []
    turnos.value       = tRes.data || []
  } finally {
    loading.value = false
  }
}

function safeDate(d) {
  if (!d) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}
function diasHasta(d) {
  if (!d) return null
  return Math.floor((safeDate(d) - new Date()) / 86400000)
}
function iniciales(p) {
  return ((p.nombre?.[0] || '') + (p.apellido?.[0] || '')).toUpperCase() || '?'
}
function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}
function fmtHora(fechaHora) {
  return new Date(fechaHora).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

const saludo = computed(() => {
  const h = new Date().getHours()
  if (h < 12) return 'Buenos días'
  if (h < 19) return 'Buenas tardes'
  return 'Buenas noches'
})

const fechaHoy = computed(() =>
  new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
)

const turnosHoy = computed(() => {
  const hoy = new Date().toDateString()
  return turnos.value
    .filter(t => new Date(t.fecha_hora).toDateString() === hoy && t.estado !== 'cancelado')
    .sort((a, b) => new Date(a.fecha_hora) - new Date(b.fecha_hora))
})

const kpis = computed(() => {
  const hoy  = new Date()
  const en30 = new Date(hoy.getTime() + 30 * 86400000)
  const activos = pacientes.value.filter(p => p.es_paciente !== false)
  const indActivas = indicaciones.value.filter(i => i.activa)
  return {
    total: activos.length,
    indPorVencer: indActivas.filter(i => {
      if (!i.fecha_vencimiento) return false
      const d = safeDate(i.fecha_vencimiento)
      return d >= hoy && d <= en30
    }).length,
    reproAlertas: activos.filter(p => {
      if (!p.reprocann_vencimiento) return false
      return safeDate(p.reprocann_vencimiento) <= en30
    }).length,
  }
})

const alertas = computed(() => {
  const en30 = new Date(new Date().getTime() + 30 * 86400000)
  return pacientes.value
    .filter(p => p.reprocann_vencimiento && safeDate(p.reprocann_vencimiento) <= en30)
    .sort((a, b) => safeDate(a.reprocann_vencimiento) - safeDate(b.reprocann_vencimiento))
    .slice(0, 8)
})

const indPorVencer = computed(() => {
  const hoy  = new Date()
  const en30 = new Date(hoy.getTime() + 30 * 86400000)
  return indicaciones.value
    .filter(i => i.activa && i.fecha_vencimiento && safeDate(i.fecha_vencimiento) >= hoy && safeDate(i.fecha_vencimiento) <= en30)
    .sort((a, b) => safeDate(a.fecha_vencimiento) - safeDate(b.fecha_vencimiento))
    .slice(0, 5)
})

onMounted(cargar)
</script>

<style scoped>
.mpd { padding: var(--sp-6); max-width: 1100px; }

.mpd__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: var(--sp-4); margin-bottom: var(--sp-5); flex-wrap: wrap;
}
.mpd__title  { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); text-transform: capitalize; }
.mpd__sub    { color: var(--c-ink-500); font-size: var(--fs-13); margin: 0; text-transform: capitalize; }
.mpd__actions { display: flex; gap: var(--sp-2); align-items: center; }

.mpd__btn-primary {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #1b5e20; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  text-decoration: none; cursor: pointer; transition: background .15s;
}
.mpd__btn-primary:hover { background: #14532d; }
.mpd__btn-secondary {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: none; color: #1b5e20; border: 1.5px solid #1b5e20; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  text-decoration: none; cursor: pointer; transition: all .15s;
}
.mpd__btn-secondary:hover { background: #f0fdf4; }
.mpd__btn-ghost {
  background: none; border: 1px solid var(--c-ink-200); color: var(--c-ink-600);
  border-radius: var(--r-md); font-size: var(--fs-13); cursor: pointer;
  text-decoration: none; transition: all .15s; display: inline-flex; align-items: center;
}
.mpd__btn-ghost:hover { background: var(--c-ink-50); }
.mpd__btn-sm { padding: .35rem .8rem !important; font-size: .75rem !important; }

/* KPIs */
.mpd__kpis {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: var(--sp-3); margin-bottom: var(--sp-6);
}
.mpd__kpi {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-4); text-decoration: none; color: inherit;
  transition: border-color .15s, box-shadow .15s;
}
.mpd__kpi:hover { border-color: #2D8A6B; box-shadow: 0 2px 8px rgba(45,138,107,.1); }
.mpd__kpi svg { flex-shrink: 0; color: var(--c-ink-400); }
.mpd__kpi--green svg { color: #15803d; }
.mpd__kpi--orange svg { color: #d97706; }
.mpd__kpi--purple svg { color: #7c3aed; }
.mpd__kpi-val { font-size: var(--fs-22); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.mpd__kpi-lbl { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }

/* Body two columns */
.mpd__body { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-6); }
@media (max-width: 768px) { .mpd__body { grid-template-columns: 1fr; } }
.mpd__col { display: flex; flex-direction: column; min-width: 0; }

.mpd__section-head {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: var(--sp-3);
}
.mpd__section-title {
  font-size: var(--fs-12); font-weight: 700; color: var(--c-ink-600); text-transform: uppercase;
  letter-spacing: .05em; display: flex; align-items: center; gap: var(--sp-2); margin: 0;
}
.mpd__section-link {
  font-size: var(--fs-12); font-weight: 600; color: #1b5e20; text-decoration: none;
}
.mpd__section-link:hover { text-decoration: underline; }

.mpd__empty-col {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-3);
  padding: var(--sp-8) var(--sp-4); color: var(--c-ink-300); text-align: center;
  border: 1.5px dashed var(--c-ink-100); border-radius: var(--r-lg);
}
.mpd__empty-col p { font-size: var(--fs-13); color: var(--c-ink-400); margin: 0; }

/* Turno list */
.mpd__turno-list { display: flex; flex-direction: column; gap: 4px; }
.mpd__turno {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-md);
  padding: .55rem var(--sp-3); border-left: 3px solid transparent;
}
.mpd__turno--primera_vez { border-left-color: #7c3aed; }
.mpd__turno--seguimiento { border-left-color: #1b5e20; }
.mpd__turno--revision    { border-left-color: #1d4ed8; }
.mpd__turno--urgencia    { border-left-color: #dc2626; }
.mpd__turno-hora { font-size: var(--fs-13); font-weight: 800; color: var(--c-ink-900); flex-shrink: 0; min-width: 44px; font-variant-numeric: tabular-nums; }
.mpd__turno-info { flex: 1; min-width: 0; }
.mpd__turno-nombre { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpd__turno-tipo   { font-size: var(--fs-11); color: var(--c-ink-400); }
.mpd__est-badge {
  font-size: .65rem; font-weight: 700; padding: .15em .55em; border-radius: 999px;
  text-transform: uppercase; letter-spacing: .04em; flex-shrink: 0;
}
.mpd__est--programado  { background: #f1f5f9; color: #475569; }
.mpd__est--confirmado  { background: #dcfce7; color: #166534; }
.mpd__est--realizado   { background: #d1fae5; color: #065f46; }
.mpd__est--ausente     { background: #fef3c7; color: #92400e; }

/* Alertas */
.mpd__alert-subtitle {
  font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .06em;
  color: var(--c-ink-400); margin: 0 0 .35rem; padding-left: 2px;
}
.mpd__alert-list { display: flex; flex-direction: column; gap: 3px; }
.mpd__alert-row {
  display: flex; align-items: center; gap: var(--sp-2);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-3); text-decoration: none; color: inherit;
  transition: border-color .15s; border-left: 3px solid transparent;
}
.mpd__alert-row--danger { border-left-color: #dc2626; }
.mpd__alert-row--warn   { border-left-color: #d97706; }
.mpd__alert-row:hover { border-color: #2D8A6B; }
.mpd__alert-av {
  width: 26px; height: 26px; border-radius: 50%; background: #1b5e20;
  color: #fff; display: flex; align-items: center; justify-content: center;
  font-size: 10px; font-weight: 700; flex-shrink: 0;
}
.mpd__alert-av--purple { background: #7c3aed; }
.mpd__alert-info { flex: 1; min-width: 0; }
.mpd__alert-name { display: block; font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpd__alert-meta { display: block; font-size: var(--fs-11); color: var(--c-ink-400); }
.mpd__alert-badge { font-size: var(--fs-11); font-weight: 700; flex-shrink: 0; }
.mpd__badge--danger { color: #dc2626; }
.mpd__badge--warn   { color: #d97706; }

.mpd__ok {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-3);
  padding: var(--sp-10) var(--sp-6); color: #2D8A6B; text-align: center;
}
.mpd__ok p { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }
</style>
