<template>
  <div class="mpd">

    <!-- Header -->
    <div class="mpd__header">
      <div>
        <h1 class="mpd__title">Panel Médico</h1>
        <p class="mpd__sub">Gestión de pacientes y documentación clínica.</p>
      </div>
      <div class="mpd__actions">
        <RouterLink to="/medico/indicaciones" class="mpd__btn-primary">
          <FilePlus :size="15" :stroke-width="1.75" /> Nueva indicación
        </RouterLink>
      </div>
    </div>

    <!-- KPIs -->
    <div class="mpd__kpis">
      <RouterLink to="/medico/pacientes" class="mpd__kpi">
        <div class="mpd__kpi-icon mpd__kpi-icon--blue"><Users :size="20" :stroke-width="1.5" /></div>
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : kpis.total }}</div>
          <div class="mpd__kpi-lbl">Pacientes activos</div>
        </div>
      </RouterLink>
      <RouterLink to="/medico/indicaciones" class="mpd__kpi">
        <div class="mpd__kpi-icon mpd__kpi-icon--orange"><Clock :size="20" :stroke-width="1.5" /></div>
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : kpis.indPorVencer }}</div>
          <div class="mpd__kpi-lbl">Indicaciones por vencer</div>
        </div>
      </RouterLink>
      <RouterLink to="/medico/pacientes" class="mpd__kpi">
        <div class="mpd__kpi-icon mpd__kpi-icon--red"><ShieldAlert :size="20" :stroke-width="1.5" /></div>
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : kpis.reproAlertas }}</div>
          <div class="mpd__kpi-lbl">REPROCANN alertas</div>
        </div>
      </RouterLink>
      <RouterLink to="/medico/indicaciones" class="mpd__kpi">
        <div class="mpd__kpi-icon mpd__kpi-icon--gray"><ClipboardList :size="20" :stroke-width="1.5" /></div>
        <div>
          <div class="mpd__kpi-val">{{ loading ? '—' : kpis.sinIndicacion }}</div>
          <div class="mpd__kpi-lbl">Sin indicación activa</div>
        </div>
      </RouterLink>
    </div>

    <!-- Alertas REPROCANN -->
    <template v-if="!loading">
      <div v-if="alertas.length" class="mpd__section">
        <h2 class="mpd__section-title">
          <AlertTriangle :size="15" :stroke-width="1.75" /> Alertas REPROCANN
        </h2>
        <div class="mpd__alert-list">
          <RouterLink
            v-for="p in alertas"
            :key="p.id"
            :to="`/medico/pacientes/${p.id}`"
            class="mpd__alert-row"
            :class="{ 'mpd__alert-row--danger': diasHasta(p.reprocann_vencimiento) < 0, 'mpd__alert-row--warn': diasHasta(p.reprocann_vencimiento) >= 0 }"
          >
            <div class="mpd__alert-av">{{ iniciales(p) }}</div>
            <div class="mpd__alert-info">
              <span class="mpd__alert-name">{{ p.nombre }} {{ p.apellido }}</span>
              <span class="mpd__alert-sep">·</span>
              <span class="mpd__alert-meta">{{ p.dni }}</span>
            </div>
            <span
              class="mpd__alert-badge"
              :class="diasHasta(p.reprocann_vencimiento) < 0 ? 'mpd__badge--danger' : 'mpd__badge--warn'"
            >
              {{ diasHasta(p.reprocann_vencimiento) < 0 ? 'Vencido' : `Vence en ${diasHasta(p.reprocann_vencimiento)}d` }}
            </span>
          </RouterLink>
        </div>
      </div>

      <!-- Indicaciones por vencer -->
      <div v-if="indPorVencer.length" class="mpd__section">
        <h2 class="mpd__section-title">
          <FileHeart :size="15" :stroke-width="1.75" /> Indicaciones próximas a vencer
        </h2>
        <div class="mpd__alert-list">
          <RouterLink
            v-for="ind in indPorVencer"
            :key="ind.id"
            :to="`/medico/pacientes/${ind.paciente?.id}`"
            class="mpd__alert-row mpd__alert-row--warn"
          >
            <div class="mpd__alert-av mpd__alert-av--purple">{{ iniciales(ind.paciente || {}) }}</div>
            <div class="mpd__alert-info">
              <span class="mpd__alert-name">{{ ind.paciente?.nombre_completo || '—' }}</span>
              <span class="mpd__alert-sep">·</span>
              <span class="mpd__alert-meta">{{ ind.patologia }}</span>
            </div>
            <span class="mpd__alert-badge mpd__badge--warn">
              Vence {{ formatDate(ind.fecha_vencimiento) }}
            </span>
          </RouterLink>
        </div>
      </div>

      <!-- Estado vacío -->
      <div v-if="!alertas.length && !indPorVencer.length && !loading" class="mpd__ok">
        <CheckCircle :size="32" :stroke-width="1.5" />
        <p>Todo en orden — sin alertas activas.</p>
      </div>
    </template>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { Users, AlertTriangle, Clock, ShieldAlert, ClipboardList, FilePlus, FileHeart, CheckCircle } from 'lucide-vue-next'
import { listPacientes } from '../../lib/api.js'
import api from '../../lib/api.js'

const loading      = ref(true)
const pacientes    = ref([])
const indicaciones = ref([])

async function cargar() {
  try {
    const [pRes, iRes] = await Promise.all([
      listPacientes(),
      api.get('/indicaciones_medicas'),
    ])
    pacientes.value    = pRes.data?.data ?? pRes.data ?? []
    indicaciones.value = iRes.data ?? []
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

const kpis = computed(() => {
  const hoy  = new Date()
  const en30 = new Date(hoy.getTime() + 30 * 86400000)
  const activos = pacientes.value.filter(p => p.es_paciente !== false)
  const indActivas = indicaciones.value.filter(i => i.activa)
  const pConInd = new Set(indActivas.map(i => i.paciente?.id).filter(Boolean))
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
    sinIndicacion: activos.filter(p => !pConInd.has(p.id)).length,
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
.mpd { padding: var(--sp-6); max-width: 900px; }

.mpd__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: var(--sp-4); margin-bottom: var(--sp-6); flex-wrap: wrap;
}
.mpd__title  { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mpd__sub    { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0; }
.mpd__actions { display: flex; gap: var(--sp-2); align-items: center; }

.mpd__btn-primary {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #2D8A6B; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  text-decoration: none; cursor: pointer; transition: background .15s;
}
.mpd__btn-primary:hover { background: #236e55; }

/* KPIs */
.mpd__kpis {
  display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr));
  gap: var(--sp-4); margin-bottom: var(--sp-6);
}
.mpd__kpi {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-4) var(--sp-5); text-decoration: none; color: inherit;
  transition: border-color .15s, box-shadow .15s;
}
.mpd__kpi:hover { border-color: #2D8A6B; box-shadow: 0 2px 8px rgba(45,138,107,.1); }
.mpd__kpi-icon {
  width: 40px; height: 40px; border-radius: var(--r-md);
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mpd__kpi-icon--blue   { background: rgba(3,105,161,.1);   color: #0369a1; }
.mpd__kpi-icon--orange { background: rgba(217,119,6,.1);   color: #d97706; }
.mpd__kpi-icon--red    { background: rgba(220,38,38,.1);   color: #dc2626; }
.mpd__kpi-icon--gray   { background: var(--c-ink-50);      color: var(--c-ink-500); }
.mpd__kpi-val { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); line-height: 1; }
.mpd__kpi-lbl { font-size: var(--fs-12); color: var(--c-ink-500); margin-top: 2px; }

/* Secciones */
.mpd__section { margin-top: var(--sp-6); }
.mpd__section-title {
  font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-600); text-transform: uppercase;
  letter-spacing: .04em; display: flex; align-items: center; gap: var(--sp-2);
  margin: 0 0 var(--sp-3);
}
.mpd__alert-list { display: flex; flex-direction: column; gap: 2px; }
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
  width: 28px; height: 28px; border-radius: 50%; background: #1b5e20;
  color: #fff; display: flex; align-items: center; justify-content: center;
  font-size: var(--fs-11); font-weight: 700; flex-shrink: 0;
}
.mpd__alert-av--purple { background: #7c3aed; }
.mpd__alert-info { flex: 1; min-width: 0; display: flex; align-items: baseline; gap: var(--sp-1); overflow: hidden; }
.mpd__alert-name { font-size: var(--fs-13); font-weight: 600; color: var(--c-ink-900); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpd__alert-sep  { font-size: var(--fs-11); color: var(--c-ink-300); flex-shrink: 0; }
.mpd__alert-meta { font-size: var(--fs-11); color: var(--c-ink-500); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.mpd__alert-badge {
  font-size: 12px; font-weight: 600; white-space: nowrap; flex-shrink: 0;
}
.mpd__badge--danger { color: #dc2626; }
.mpd__badge--warn   { color: #d97706; }

/* OK state */
.mpd__ok {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-3);
  padding: var(--sp-10) var(--sp-6); color: #2D8A6B; text-align: center;
}
.mpd__ok p { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }
</style>
