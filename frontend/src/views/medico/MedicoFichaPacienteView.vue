<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getMedicoFicha } from '../../lib/api.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import SocioTabHistoria from '../../components/pacientes/SocioTabHistoria.vue'

const route  = useRoute()
const router = useRouter()

const loading = ref(true)
const error   = ref(null)
const data    = ref(null)

// Tabs del timeline
const tab = ref('timeline')

// Paginación dispensaciones
const PAGE = 8
const page = ref(1)
const dispensacionesPaginadas = computed(() => {
  if (!data.value) return []
  return data.value.dispensaciones.slice(0, page.value * PAGE)
})
const hayMas = computed(() =>
  data.value && dispensacionesPaginadas.value.length < data.value.dispensaciones.length
)

onMounted(async () => {
  try {
    const { data: d } = await getMedicoFicha(route.params.id)
    data.value = d
  } catch (e) {
    error.value = e?.response?.status === 404
      ? 'Paciente no encontrado'
      : 'No se pudo cargar la ficha'
  } finally {
    loading.value = false
  }
})

// ── helpers UI ──────────────────────────────────────────────────────────────
const QUIMIOTIPO_LABEL = { I: 'THC dom.', II: 'Balanceado', III: 'CBD dom.' }
const QUIMIOTIPO_CLS   = { I: 'qt--i', II: 'qt--ii', III: 'qt--iii' }
const TIPO_LABEL       = { I: 'Tipo I', II: 'Tipo II', III: 'Tipo III' }

function qtLabel(qt)   { return qt ? `${TIPO_LABEL[qt]} · ${QUIMIOTIPO_LABEL[qt]}` : null }
function qtCls(qt)     { return qt ? QUIMIOTIPO_CLS[qt] : 'qt--nd' }

function formatFecha(f) {
  if (!f) return '—'
  return new Date(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}
function formatFechaCorta(f) {
  if (!f) return '—'
  return new Date(f).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}
function formatDateTime(f) {
  if (!f) return '—'
  return new Date(f).toLocaleDateString('es-AR', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

function reprocannCls(estado, dias) {
  if (!estado || estado === 'sin_registro') return 'badge--gray'
  if (dias !== null && dias < 0)  return 'badge--danger'
  if (dias !== null && dias <= 30) return 'badge--warn'
  return 'badge--ok'
}
function reprocannLabel(estado, dias) {
  if (!estado || estado === 'sin_registro') return 'Sin REPROCANN'
  if (dias !== null && dias < 0)  return `Vencido hace ${Math.abs(dias)}d`
  if (dias !== null && dias <= 30) return `Vence en ${dias}d`
  return 'Vigente'
}

function estrellas(n) {
  if (!n) return null
  const llenas = Math.round(n / 2)
  return Array.from({ length: 5 }, (_, i) => i < llenas)
}

// Sparkline: últimas dispensaciones en orden cronológico para el gráfico
const sparklineData = computed(() => {
  if (!data.value?.dispensaciones?.length) return []
  return [...data.value.dispensaciones]
    .reverse()
    .slice(-12)
    .map(d => d.cantidad_g)
})
const sparklineMax = computed(() => Math.max(...sparklineData.value, 1))

// Agrupar dispensaciones por mes para el timeline
const dispensacionesPorMes = computed(() => {
  const grupos = []
  let mesActual = null
  for (const d of dispensacionesPaginadas.value) {
    const mes = new Date(d.fecha).toLocaleDateString('es-AR', { month: 'long', year: 'numeric' })
    if (mes !== mesActual) {
      grupos.push({ mes, items: [] })
      mesActual = mes
    }
    grupos[grupos.length - 1].items.push(d)
  }
  return grupos
})

const initiales = computed(() => {
  const p = data.value?.paciente
  if (!p) return '?'
  return `${p.nombre?.[0] || ''}${p.apellido?.[0] || ''}`.toUpperCase()
})

// Adapta data.paciente al shape que espera SocioTabHistoria/useSocioHistoriaClinica
const fichaComoSocio = computed(() => data.value?.paciente ?? null)
</script>

<template>
  <div class="mfp">

    <!-- Breadcrumb -->
    <div class="mfp__breadcrumb">
      <button class="mfp__back" @click="router.back()">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
        Mis Pacientes
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mfp__loading">
      <DsSpinner :size="24" />
      <span>Cargando ficha…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="mfp__error">
      <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
      <p>{{ error }}</p>
      <button class="mfp__btn-ghost" @click="router.back()">Volver</button>
    </div>

    <template v-else-if="data">
      <!-- ── HEADER ────────────────────────────────────────── -->
      <div class="mfp__header">
        <div class="mfp__avatar">{{ initiales }}</div>
        <div class="mfp__header-info">
          <h1 class="mfp__nombre">{{ data.paciente.nombre_completo }}</h1>
          <div class="mfp__header-meta">
            <span>DNI {{ data.paciente.dni }}</span>
            <span class="mfp__sep">·</span>
            <span>{{ data.paciente.edad }} años</span>
            <template v-if="data.paciente.diagnostico_principal">
              <span class="mfp__sep">·</span>
              <span>{{ data.paciente.diagnostico_principal }}</span>
            </template>
          </div>
        </div>
        <div class="mfp__header-badges">
          <span class="mfp__badge" :class="reprocannCls(data.paciente.reprocann_estado, data.paciente.dias_hasta_vencimiento)">
            {{ reprocannLabel(data.paciente.reprocann_estado, data.paciente.dias_hasta_vencimiento) }}
          </span>
          <span v-if="data.paciente.reprocann_numero" class="mfp__repro-num">
            {{ data.paciente.reprocann_numero }}
          </span>
        </div>
      </div>

      <!-- ── BODY: 2 columnas ────────────────────────────── -->
      <div class="mfp__body">

        <!-- Columna izquierda: datos clínicos -->
        <aside class="mfp__aside">

          <!-- Diagnóstico -->
          <section class="mfp__card">
            <div class="mfp__card-title">Diagnóstico</div>
            <div v-if="data.paciente.diagnostico_principal" class="mfp__dato">
              <span class="mfp__dato-lbl">Principal</span>
              <span class="mfp__dato-val">{{ data.paciente.diagnostico_principal }}</span>
            </div>
            <div v-if="data.paciente.diagnostico_secundario" class="mfp__dato">
              <span class="mfp__dato-lbl">Secundario</span>
              <span class="mfp__dato-val">{{ data.paciente.diagnostico_secundario }}</span>
            </div>
            <div v-if="data.paciente.motivo_consulta" class="mfp__dato mfp__dato--full">
              <span class="mfp__dato-lbl">Motivo</span>
              <span class="mfp__dato-val mfp__dato-val--text">{{ data.paciente.motivo_consulta }}</span>
            </div>
            <div v-if="!data.paciente.diagnostico_principal" class="mfp__empty-small">Sin diagnóstico registrado</div>
          </section>

          <!-- Indicación activa -->
          <section class="mfp__card">
            <div class="mfp__card-title">Indicación activa</div>
            <template v-if="data.indicacion_activa">
              <div class="mfp__dato">
                <span class="mfp__dato-lbl">Dosificación</span>
                <span class="mfp__dato-val">{{ data.indicacion_activa.dosificacion }}</span>
              </div>
              <div class="mfp__dato">
                <span class="mfp__dato-lbl">Vía</span>
                <span class="mfp__dato-val">{{ data.indicacion_activa.via_administracion }}</span>
              </div>
              <div class="mfp__dato">
                <span class="mfp__dato-lbl">Vence</span>
                <span class="mfp__dato-val">{{ formatFecha(data.indicacion_activa.fecha_vencimiento) }}</span>
              </div>
            </template>
            <div v-else class="mfp__empty-small">Sin indicación activa</div>
          </section>

          <!-- Medicación + alergias -->
          <section v-if="data.paciente.medicacion_habitual || data.paciente.alergias" class="mfp__card">
            <div class="mfp__card-title">Antecedentes</div>
            <div v-if="data.paciente.medicacion_habitual" class="mfp__dato mfp__dato--full">
              <span class="mfp__dato-lbl">Medicación</span>
              <span class="mfp__dato-val mfp__dato-val--text">{{ data.paciente.medicacion_habitual }}</span>
            </div>
            <div v-if="data.paciente.alergias" class="mfp__dato mfp__dato--full">
              <span class="mfp__dato-lbl">Alergias</span>
              <span class="mfp__dato-val mfp__dato-val--text mfp__dato-val--warn">{{ data.paciente.alergias }}</span>
            </div>
          </section>

          <!-- Próximo turno -->
          <section class="mfp__card">
            <div class="mfp__card-title">Próximo turno</div>
            <template v-if="data.proximo_turno">
              <div class="mfp__turno-item">
                <div class="mfp__turno-fecha">{{ formatDateTime(data.proximo_turno.fecha_hora) }}</div>
                <div class="mfp__turno-tipo">{{ data.proximo_turno.tipo.replace('_', ' ') }}</div>
              </div>
            </template>
            <div v-else class="mfp__empty-small">Sin turnos próximos</div>
          </section>

          <!-- Contacto -->
          <section class="mfp__card mfp__card--compact">
            <div class="mfp__card-title">Contacto</div>
            <div v-if="data.paciente.email" class="mfp__dato">
              <span class="mfp__dato-lbl">Email</span>
              <span class="mfp__dato-val">{{ data.paciente.email }}</span>
            </div>
            <div v-if="data.paciente.telefono" class="mfp__dato">
              <span class="mfp__dato-lbl">Tel.</span>
              <span class="mfp__dato-val">{{ data.paciente.telefono }}</span>
            </div>
            <div v-if="data.paciente.grupo_sanguineo" class="mfp__dato">
              <span class="mfp__dato-lbl">Grupo</span>
              <span class="mfp__dato-val">{{ data.paciente.grupo_sanguineo }}</span>
            </div>
          </section>

        </aside>

        <!-- Columna derecha: timeline clínico -->
        <main class="mfp__main">

          <!-- Resumen consumo -->
          <div class="mfp__consumo-bar">
            <div class="mfp__consumo-stat">
              <span class="mfp__consumo-val">{{ data.resumen_consumo.total_g_90d.toFixed(0) }}g</span>
              <span class="mfp__consumo-lbl">últimos 90 días</span>
            </div>
            <div class="mfp__consumo-sep"></div>
            <div class="mfp__consumo-stat">
              <span class="mfp__consumo-val">{{ data.resumen_consumo.promedio_mensual_g.toFixed(1) }}g</span>
              <span class="mfp__consumo-lbl">promedio/mes</span>
            </div>
            <div class="mfp__consumo-sep"></div>
            <div class="mfp__consumo-stat">
              <span class="mfp__consumo-val">{{ data.total_dispensaciones }}</span>
              <span class="mfp__consumo-lbl">dispensaciones</span>
            </div>
            <!-- Sparkline -->
            <div v-if="sparklineData.length > 1" class="mfp__sparkline">
              <svg viewBox="0 0 120 32" preserveAspectRatio="none">
                <polyline
                  :points="sparklineData.map((v, i) =>
                    `${(i / (sparklineData.length - 1)) * 120},${32 - (v / sparklineMax) * 28}`
                  ).join(' ')"
                  fill="none" stroke="var(--brand-primary, #1b5e20)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                />
              </svg>
            </div>
          </div>

          <!-- Tabs -->
          <div class="mfp__tabs">
            <button class="mfp__tab" :class="{ 'mfp__tab--active': tab === 'timeline' }" @click="tab = 'timeline'">
              Timeline de dispensaciones
            </button>
            <button class="mfp__tab" :class="{ 'mfp__tab--active': tab === 'notas' }" @click="tab = 'notas'">
              Historia clínica
            </button>
          </div>

          <!-- Tab: Timeline -->
          <div v-if="tab === 'timeline'">
            <div v-if="!data.dispensaciones.length" class="mfp__empty">
              <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
              <p>Sin dispensaciones registradas</p>
            </div>
            <div v-else>
              <div v-for="grupo in dispensacionesPorMes" :key="grupo.mes" class="mfp__mes-grupo">
                <div class="mfp__mes-label">{{ grupo.mes }}</div>
                <div v-for="d in grupo.items" :key="d.id" class="mfp__disp-card">
                  <div class="mfp__disp-dot"></div>
                  <div class="mfp__disp-content">
                    <!-- Fila principal -->
                    <div class="mfp__disp-row">
                      <span class="mfp__disp-fecha">{{ formatFechaCorta(d.fecha) }}</span>
                      <span class="mfp__disp-gramos">{{ d.cantidad_g.toFixed(1) }}g</span>
                      <span v-if="d.forma_producto" class="mfp__disp-forma">{{ d.forma_producto }}</span>
                    </div>
                    <!-- Genética -->
                    <div v-if="d.genetica" class="mfp__disp-genetica">
                      <span class="mfp__gen-nombre">{{ d.genetica.nombre }}</span>
                      <template v-if="d.genetica.thc !== null || d.genetica.cbd !== null">
                        <span class="mfp__gen-pct">
                          <span v-if="d.genetica.thc !== null">THC {{ d.genetica.thc }}%</span>
                          <span v-if="d.genetica.cbd !== null">CBD {{ d.genetica.cbd }}%</span>
                        </span>
                      </template>
                      <span v-if="d.genetica.quimiotipo" class="mfp__qt-badge" :class="qtCls(d.genetica.quimiotipo)">
                        {{ qtLabel(d.genetica.quimiotipo) }}
                      </span>
                      <span v-else class="mfp__qt-badge qt--nd">Sin datos</span>
                      <span v-if="d.genetica.tipo" class="mfp__gen-tipo">{{ d.genetica.tipo }}</span>
                    </div>
                    <!-- Check-in -->
                    <div v-if="d.check_in" class="mfp__checkin">
                      <div class="mfp__checkin-stars">
                        <template v-for="(llena, i) in estrellas(d.check_in.escala_bienestar)" :key="i">
                          <svg width="12" height="12" viewBox="0 0 24 24" :fill="llena ? 'currentColor' : 'none'" stroke="currentColor" stroke-width="1.5">
                            <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
                          </svg>
                        </template>
                        <span class="mfp__checkin-val">{{ d.check_in.escala_bienestar }}/10</span>
                      </div>
                      <span v-if="d.check_in.notas" class="mfp__checkin-nota">"{{ d.check_in.notas }}"</span>
                    </div>
                    <div v-else class="mfp__checkin-empty">Sin check-in</div>
                  </div>
                </div>
              </div>

              <!-- Ver más -->
              <div v-if="hayMas" class="mfp__ver-mas">
                <button class="mfp__btn-ghost" @click="page++">
                  Ver más dispensaciones ({{ data.dispensaciones.length - dispensacionesPaginadas.length }} restantes)
                </button>
              </div>
            </div>
          </div>

          <!-- Tab: Historia clínica (editable) -->
          <div v-if="tab === 'notas'">
            <SocioTabHistoria :socio-id="Number(route.params.id)" :s="fichaComoSocio" />
          </div>

        </main>
      </div>
    </template>
  </div>
</template>

<style scoped>
*, *::before, *::after { box-sizing: border-box; }

.mfp {
  max-width: 1100px;
  margin: 0 auto;
  padding: 1.5rem 1.25rem 3rem;
  font-family: system-ui, -apple-system, sans-serif;
}

/* Breadcrumb */
.mfp__breadcrumb { margin-bottom: 1.25rem; }
.mfp__back {
  display: inline-flex; align-items: center; gap: .35rem;
  background: none; border: none; cursor: pointer;
  font-size: .8rem; font-weight: 600; color: #64748b;
  padding: .25rem .5rem; border-radius: 6px; transition: all .15s;
}
.mfp__back:hover { background: #f1f5f9; color: #0f172a; }

/* Loading / error */
.mfp__loading, .mfp__error {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .75rem; min-height: 200px; color: #64748b;
}
.mfp__error svg { color: #94a3b8; }
.mfp__error p { font-size: .9rem; }

/* ── HEADER ───────────────────────────────────────────────── */
.mfp__header {
  display: flex; align-items: center; gap: 1rem;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 14px;
  padding: 1.1rem 1.25rem; margin-bottom: 1.25rem;
  box-shadow: 0 1px 4px rgba(0,0,0,.04);
}
.mfp__avatar {
  width: 52px; height: 52px; border-radius: 50%;
  background: linear-gradient(135deg, #1b5e20, #2e7d32);
  color: #fff; font-weight: 800; font-size: 1.1rem;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.mfp__header-info { flex: 1; min-width: 0; }
.mfp__nombre { font-size: 1.15rem; font-weight: 800; color: #0f172a; margin: 0 0 .2rem; }
.mfp__header-meta { font-size: .78rem; color: #64748b; display: flex; flex-wrap: wrap; gap: .25rem .4rem; }
.mfp__sep { color: #cbd5e1; }
.mfp__header-badges { display: flex; flex-direction: column; align-items: flex-end; gap: .3rem; flex-shrink: 0; }
.mfp__repro-num { font-size: .68rem; color: #94a3b8; font-family: monospace; }

/* Badges REPROCANN */
.mfp__badge {
  font-size: .68rem; font-weight: 700; padding: .25em .7em;
  border-radius: 999px; text-transform: uppercase; letter-spacing: .04em;
}
.badge--ok     { background: #dcfce7; color: #166534; }
.badge--warn   { background: #fef3c7; color: #92400e; }
.badge--danger { background: #fee2e2; color: #991b1b; }
.badge--gray   { background: #f1f5f9; color: #64748b; }

/* ── BODY ─────────────────────────────────────────────────── */
.mfp__body {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: 1.25rem;
  align-items: start;
}
@media (max-width: 860px) {
  .mfp__body { grid-template-columns: 1fr; }
}

/* ── ASIDE ────────────────────────────────────────────────── */
.mfp__aside { display: flex; flex-direction: column; gap: .75rem; }

.mfp__card {
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  padding: .9rem 1rem; box-shadow: 0 1px 3px rgba(0,0,0,.04);
}
.mfp__card--compact { padding: .75rem 1rem; }
.mfp__card-title {
  font-size: .65rem; font-weight: 800; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .06em; margin-bottom: .6rem;
}

.mfp__dato { display: flex; flex-direction: column; gap: .1rem; margin-bottom: .5rem; }
.mfp__dato:last-child { margin-bottom: 0; }
.mfp__dato--full { width: 100%; }
.mfp__dato-lbl { font-size: .65rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; }
.mfp__dato-val { font-size: .82rem; color: #1e293b; font-weight: 500; }
.mfp__dato-val--text { white-space: pre-wrap; line-height: 1.5; color: #475569; font-weight: 400; font-size: .8rem; }
.mfp__dato-val--warn { color: #b45309; background: #fef3c7; padding: .2rem .4rem; border-radius: 4px; display: inline-block; }

.mfp__empty-small { font-size: .78rem; color: #94a3b8; font-style: italic; }

.mfp__turno-item { display: flex; flex-direction: column; gap: .15rem; }
.mfp__turno-fecha { font-size: .82rem; font-weight: 700; color: #1e293b; }
.mfp__turno-tipo  { font-size: .72rem; color: #64748b; text-transform: capitalize; }

/* ── MAIN ─────────────────────────────────────────────────── */
.mfp__main { display: flex; flex-direction: column; gap: .75rem; }

/* Barra de consumo */
.mfp__consumo-bar {
  display: flex; align-items: center; gap: 1.25rem; flex-wrap: wrap;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 12px;
  padding: .9rem 1.1rem; box-shadow: 0 1px 3px rgba(0,0,0,.04);
}
.mfp__consumo-stat { display: flex; flex-direction: column; gap: .1rem; }
.mfp__consumo-val { font-size: 1.25rem; font-weight: 800; color: #1b5e20; line-height: 1; }
.mfp__consumo-lbl { font-size: .65rem; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; font-weight: 600; }
.mfp__consumo-sep { width: 1px; height: 28px; background: #f1f5f9; flex-shrink: 0; }
.mfp__sparkline {
  margin-left: auto; width: 120px; height: 32px; flex-shrink: 0;
}
.mfp__sparkline svg { width: 100%; height: 100%; }

/* Tabs */
.mfp__tabs {
  display: flex; gap: .5rem; border-bottom: 2px solid #f1f5f9; padding-bottom: 0;
}
.mfp__tab {
  background: none; border: none; cursor: pointer; padding: .6rem .9rem;
  font-size: .8rem; font-weight: 600; color: #64748b;
  border-bottom: 2px solid transparent; margin-bottom: -2px;
  transition: all .15s; border-radius: 6px 6px 0 0;
}
.mfp__tab:hover { color: #1b5e20; background: #f0fdf4; }
.mfp__tab--active { color: #1b5e20; border-bottom-color: #1b5e20; }

/* Timeline */
.mfp__mes-grupo { margin-bottom: .5rem; }
.mfp__mes-label {
  font-size: .65rem; font-weight: 800; color: #94a3b8;
  text-transform: uppercase; letter-spacing: .06em;
  padding: .5rem 0 .35rem; border-bottom: 1px solid #f1f5f9; margin-bottom: .4rem;
}
.mfp__disp-card {
  display: flex; gap: .75rem;
  background: #fff; border: 1px solid #f1f5f9; border-radius: 10px;
  padding: .75rem .9rem; margin-bottom: .4rem;
  transition: box-shadow .15s;
}
.mfp__disp-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,.06); border-color: #e2e8f0; }
.mfp__disp-dot {
  width: 8px; height: 8px; border-radius: 50%;
  background: #1b5e20; flex-shrink: 0; margin-top: .4rem;
}
.mfp__disp-content { flex: 1; min-width: 0; }

.mfp__disp-row {
  display: flex; align-items: center; gap: .6rem; margin-bottom: .35rem;
}
.mfp__disp-fecha { font-size: .8rem; font-weight: 700; color: #0f172a; }
.mfp__disp-gramos {
  font-size: .8rem; font-weight: 800; color: #1b5e20;
  background: #f0fdf4; padding: .1rem .45rem; border-radius: 6px;
}
.mfp__disp-forma { font-size: .72rem; color: #94a3b8; background: #f8fafc; padding: .1rem .4rem; border-radius: 4px; }

.mfp__disp-genetica {
  display: flex; flex-wrap: wrap; align-items: center; gap: .4rem;
  margin-bottom: .35rem;
}
.mfp__gen-nombre { font-size: .82rem; font-weight: 600; color: #334155; }
.mfp__gen-pct {
  display: flex; gap: .3rem;
  font-size: .7rem; color: #64748b;
}
.mfp__gen-tipo {
  font-size: .65rem; color: #94a3b8; background: #f8fafc;
  padding: .1rem .4rem; border-radius: 4px; text-transform: capitalize;
}

/* Quimiotipo badges */
.mfp__qt-badge {
  font-size: .65rem; font-weight: 700; padding: .15em .55em;
  border-radius: 999px; text-transform: none;
}
.qt--i   { background: #fff7ed; color: #c2410c; border: 1px solid #fed7aa; }
.qt--ii  { background: #f0fdf4; color: #166534; border: 1px solid #bbf7d0; }
.qt--iii { background: #eff6ff; color: #1d4ed8; border: 1px solid #bfdbfe; }
.qt--nd  { background: #f8fafc; color: #94a3b8; border: 1px solid #e2e8f0; }

/* Check-in */
.mfp__checkin { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; }
.mfp__checkin-stars {
  display: flex; align-items: center; gap: .15rem; color: #f59e0b;
}
.mfp__checkin-val { font-size: .72rem; color: #64748b; margin-left: .25rem; }
.mfp__checkin-nota { font-size: .75rem; color: #475569; font-style: italic; }
.mfp__checkin-empty { font-size: .72rem; color: #cbd5e1; }

/* Ver más */
.mfp__ver-mas { text-align: center; margin-top: .75rem; }
.mfp__btn-ghost {
  background: none; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: .5rem 1.1rem; font-size: .8rem; font-weight: 600; color: #64748b;
  cursor: pointer; transition: all .15s;
}
.mfp__btn-ghost:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }

/* Historia clínica */
.mfp__historia { display: flex; flex-direction: column; gap: .75rem; }
.mfp__hist-bloque {
  background: #fff; border: 1px solid #f1f5f9; border-radius: 10px; padding: .9rem 1rem;
}
.mfp__hist-titulo { font-size: .65rem; font-weight: 800; color: #94a3b8; text-transform: uppercase; letter-spacing: .06em; margin-bottom: .5rem; }
.mfp__hist-texto { font-size: .82rem; color: #475569; line-height: 1.65; white-space: pre-wrap; margin: 0; }

/* Empty */
.mfp__empty {
  display: flex; flex-direction: column; align-items: center;
  gap: .75rem; padding: 2.5rem; color: #94a3b8; text-align: center;
}
.mfp__empty p { font-size: .85rem; margin: 0; }
</style>
