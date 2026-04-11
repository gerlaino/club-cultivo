<template>
  <div class="cvd">

    <!-- Header -->
    <div class="cvd__header">
      <div>
        <h1 class="cvd__greeting">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <p class="cvd__date">{{ hoy }}</p>
      </div>
      <div class="cvd__header-right">
        <div v-if="tareasVencidas.length > 0" class="cvd__alert">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <span>{{ tareasVencidas.length }} tarea{{ tareasVencidas.length > 1 ? 's' : '' }} vencida{{ tareasVencidas.length > 1 ? 's' : '' }}</span>
        </div>
      </div>
    </div>

    <div v-if="loading" class="cvd__loading">
      <div class="cvd__spinner"></div>
      <span>Cargando tu día…</span>
    </div>

    <template v-else>

      <!-- Tareas del día -->
      <section class="cvd__section">
        <div class="cvd__section-header cvd__section-header--clickable" @click="tareasExpandidas = !tareasExpandidas">
          <h2 class="cvd__section-title">
            Tareas de hoy
            <span class="cvd__badge">{{ tareasHoy.length }}</span>
          </h2>
          <i class="bi cvd__chevron" :class="tareasExpandidas ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
        </div>

        <div v-show="tareasExpandidas">
          <div class="cvd__filtros">
            <button
              v-for="f in FILTROS_ESTADO" :key="f.value"
              class="cvd__filtro-pill"
              :class="{ 'cvd__filtro-pill--active': filtroEstado === f.value }"
              @click="filtroEstado = filtroEstado === f.value ? '' : f.value"
            >{{ f.emoji }} {{ f.label }}</button>
            <div class="cvd__filtro-sep"></div>
            <button
              v-for="f in FILTROS_PRIORIDAD" :key="f.value"
              class="cvd__filtro-pill"
              :class="{ 'cvd__filtro-pill--active': filtroPrioridad === f.value }"
              :style="filtroPrioridad === f.value ? { borderColor: f.color, background: f.color+'15', color: f.color } : {}"
              @click="filtroPrioridad = filtroPrioridad === f.value ? '' : f.value"
            >{{ f.emoji }} {{ f.label }}</button>
          </div>

          <div v-if="tareasHoyFiltradas.length === 0 && tareasHoy.length === 0" class="cvd__empty cvd__empty--inline">
            <span>🎉</span><p>Sin tareas para hoy — todo al día</p>
          </div>
          <div v-else-if="tareasHoyFiltradas.length === 0" class="cvd__empty cvd__empty--inline">
            <span>🔍</span><p>Sin tareas con ese filtro</p>
          </div>
          <div v-else class="cvd__tareas">
            <div
              v-for="tarea in tareasHoyFiltradas" :key="tarea.id"
              class="cvd__tarea" :class="`cvd__tarea--${tarea.prioridad}`"
            >
              <button v-if="tarea.estado === 'pendiente'" class="cvd__tarea-btn cvd__tarea-btn--start" @click.prevent="iniciarTarea(tarea)">
                <i class="bi bi-play-fill"></i>
              </button>
              <button v-else-if="tarea.estado === 'en_progreso'" class="cvd__tarea-btn cvd__tarea-btn--done" @click.prevent="abrirCompletar(tarea)">
                <i class="bi bi-check-lg"></i>
              </button>
              <div v-else class="cvd__tarea-check">✓</div>
              <div class="cvd__tarea-info">
                <div class="cvd__tarea-titulo" :class="{ 'cvd__tarea-titulo--done': tarea.estado === 'completada' }">{{ tarea.titulo }}</div>
                <div class="cvd__tarea-meta">
                  {{ TIPO_LABELS[tarea.tipo] || tarea.tipo }}
                  <span v-if="tarea.sala"> · {{ tarea.sala.nombre }}</span>
                  <span v-if="tarea.lote"> · {{ tarea.lote.codigo }}</span>
                </div>
              </div>
              <span class="cvd__tarea-prioridad" :class="`cvd__tarea-prioridad--${tarea.prioridad}`">{{ tarea.prioridad }}</span>
            </div>
          </div>
        </div>
      </section>

      <!-- Mis salas -->
      <section class="cvd__section">
        <div class="cvd__section-header cvd__section-header--clickable" @click="salasExpandidas = !salasExpandidas">
          <h2 class="cvd__section-title">
            Mis salas
            <span class="cvd__badge">{{ salas.length }}</span>
          </h2>
          <i class="bi cvd__chevron" :class="salasExpandidas ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
        </div>
        <div v-show="salasExpandidas">
          <div v-if="salas.length === 0" class="cvd__empty">
            <div class="cvd__empty-icon">🏠</div>
            <p>No tenés salas asignadas aún</p>
            <span class="cvd__empty-hint">Contactá al administrador</span>
          </div>
          <div v-else class="cvd__salas">
            <RouterLink v-for="sala in salas" :key="sala.id" :to="{ name: 'sala-detail', params: { id: sala.id } }" class="cvd__sala-card">
              <div class="cvd__sala-bar" :style="{ width: ocupacionPct(sala) + '%', background: ocupacionColor(sala) }"></div>
              <div class="cvd__sala-body">
                <div class="cvd__sala-head">
                  <div>
                    <h3 class="cvd__sala-nombre">{{ sala.nombre }}</h3>
                    <span class="cvd__sala-sede">{{ sala.sede?.nombre || '—' }}</span>
                  </div>
                  <span class="cvd__sala-estado" :class="`cvd__sala-estado--${sala.state}`">{{ estadoLabel(sala.state) }}</span>
                </div>
                <div class="cvd__sala-metrics">
                  <div class="cvd__metric">
                    <span class="cvd__metric-value">{{ sala.lotes_activos || 0 }}</span>
                    <span class="cvd__metric-label">lotes activos</span>
                  </div>
                  <div class="cvd__metric">
                    <span class="cvd__metric-value">{{ sala.plantas_totales || 0 }}</span>
                    <span class="cvd__metric-label">plantas</span>
                  </div>
                  <div class="cvd__metric">
                    <span class="cvd__metric-value">{{ (sala.porcentaje_ocupacion || 0).toFixed(0) }}%</span>
                    <span class="cvd__metric-label">ocupación</span>
                  </div>
                </div>
                <div class="cvd__sala-progress">
                  <div class="cvd__sala-progress-fill" :style="{ width: ocupacionPct(sala) + '%', background: ocupacionColor(sala) }"></div>
                </div>
                <div class="cvd__sala-footer">
                  <span class="cvd__sala-kind">{{ kindLabel(sala.kind) }}</span>
                  <span class="cvd__sala-cta">Ver sala →</span>
                </div>
              </div>
            </RouterLink>
          </div>
        </div>
      </section>

      <!-- Próximas -->
      <section v-if="tareasProximas.length > 0" class="cvd__section">
        <div class="cvd__section-header">
          <h2 class="cvd__section-title">Esta semana</h2>
        </div>
        <div class="cvd__proximas">
          <div v-for="tarea in tareasProximas.slice(0, 5)" :key="tarea.id" class="cvd__proxima">
            <div class="cvd__proxima-fecha">{{ formatFecha(tarea.fecha_programada) }}</div>
            <div class="cvd__proxima-titulo">{{ tarea.titulo }}</div>
            <div class="cvd__proxima-sala">{{ tarea.sala?.nombre || '—' }}</div>
          </div>
        </div>
      </section>

    </template>

    <!-- Modal completar -->
    <Teleport to="body">
      <div v-if="tareaCompletando" class="cvd__overlay" @click.self="tareaCompletando = null">
        <div class="cvd__modal">
          <div class="cvd__modal-header">
            <h3 class="cvd__modal-title">Completar tarea</h3>
            <button class="cvd__modal-close" @click="tareaCompletando = null"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="cvd__modal-body">
            <p class="cvd__modal-tarea-nombre">{{ tareaCompletando.titulo }}</p>
            <div class="cvd__field">
              <label class="cvd__label">Horas trabajadas</label>
              <div class="cvd__input-group">
                <input v-model.number="horasCompletado" type="number" class="cvd__input" min="0.25" max="24" step="0.25" placeholder="0.0">
                <span class="cvd__input-suffix">hs</span>
              </div>
            </div>
            <div class="cvd__field">
              <label class="cvd__label">Notas <span class="cvd__optional">opcional</span></label>
              <textarea v-model="notasCompletado" class="cvd__input cvd__textarea" rows="3" placeholder="¿Algo a destacar?"></textarea>
            </div>
          </div>
          <div class="cvd__modal-footer">
            <button class="cvd__btn-ghost" @click="tareaCompletando = null">Cancelar</button>
            <button class="cvd__btn-success" @click="confirmarCompletar" :disabled="guardando">
              <span v-if="guardando" class="cvd__spinner cvd__spinner--sm"></span>
              <i v-else class="bi bi-check-lg"></i>
              Marcar completada
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/auth'
import { useTareasStore } from '../../stores/tareas'
import { useSalasStore } from '../../stores/salas'
import { storeToRefs } from 'pinia'

const auth        = useAuthStore()
const tareasStore = useTareasStore()
const salasStore  = useSalasStore()
const { dashboard } = storeToRefs(tareasStore)

const loading          = ref(true)
const salasExpandidas  = ref(true)
const tareasExpandidas = ref(true)
const tareaCompletando = ref(null)
const horasCompletado  = ref(null)
const notasCompletado  = ref('')
const guardando        = ref(false)
const filtroEstado     = ref('')
const filtroPrioridad  = ref('')

const FILTROS_ESTADO = [
  { value: 'pendiente',   label: 'Pendiente',  emoji: '⏳' },
  { value: 'en_progreso', label: 'En progreso', emoji: '🔄' },
  { value: 'completada',  label: 'Completada',  emoji: '✅' },
]
const FILTROS_PRIORIDAD = [
  { value: 'urgente', label: 'Urgente', emoji: '🔴', color: '#dc2626' },
  { value: 'alta',    label: 'Alta',    emoji: '🟠', color: '#ea580c' },
  { value: 'normal',  label: 'Normal',  emoji: '🔵', color: '#2563eb' },
  { value: 'baja',    label: 'Baja',    emoji: '🟢', color: '#16a34a' },
]

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = new Date().toLocaleDateString('es-AR', {
  weekday:'long', day:'numeric', month:'long', year:'numeric'
}).replace(/^\w/, c => c.toUpperCase())

const salas          = computed(() => salasStore.items || [])
const tareasHoy      = computed(() => dashboard.value?.hoy     || [])
const tareasProximas = computed(() => dashboard.value?.proximas || [])
const tareasVencidas = computed(() => dashboard.value?.vencidas || [])

const tareasHoyFiltradas = computed(() => {
  let lista = tareasHoy.value
  if (filtroEstado.value)    lista = lista.filter(t => t.estado    === filtroEstado.value)
  if (filtroPrioridad.value) lista = lista.filter(t => t.prioridad === filtroPrioridad.value)
  return lista
})

function ocupacionPct(sala)   { return Math.min(sala?.porcentaje_ocupacion || 0, 100) }
function ocupacionColor(sala) {
  const p = ocupacionPct(sala)
  return p >= 90 ? '#dc2626' : p >= 70 ? '#d97706' : '#16a34a'
}
function estadoLabel(s) { return { activa:'Activa', mantenimiento:'Mantenimiento', cerrada:'Cerrada' }[s] || s }
function kindLabel(k)   { return { produccion:'Producción', social:'Social', mixta:'Mixta' }[k] || k || '—' }
function formatFecha(f) {
  if (!f) return '—'
  return new Date(f).toLocaleDateString('es-AR', { weekday:'short', day:'numeric', month:'short' })
}

const TIPO_LABELS = {
  riego:'💧 Riego', poda:'✂️ Poda', medicion:'📏 Medición',
  limpieza:'🧹 Limpieza', cosecha:'🌿 Cosecha', transplante:'🪴 Trasplante',
  inspeccion:'🔍 Inspección', otro:'📋 Otro'
}


async function iniciarTarea(tarea) {
  try { await tareasStore.iniciar(tarea.id) } catch {}
}
function abrirCompletar(tarea) {
  tareaCompletando.value = tarea
  horasCompletado.value  = tarea.horas_estimadas || null
  notasCompletado.value  = ''
}
async function confirmarCompletar() {
  guardando.value = true
  try {
    await tareasStore.completar(tareaCompletando.value.id, horasCompletado.value, notasCompletado.value)
    tareaCompletando.value = null
  } catch {} finally { guardando.value = false }
}

onMounted(async () => {
  try {
    await Promise.all([
      tareasStore.fetchDashboard(),
      salasStore.fetch(),
    ])
  } catch {} finally { loading.value = false }
})
</script>

<style scoped>
.cvd { padding: 2rem 1.5rem; max-width: 960px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; }
@media (max-width: 640px) { .cvd { padding: 1.25rem 1rem; } }

.cvd__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 2rem; flex-wrap: wrap; }
.cvd__greeting { font-size: 1.65rem; font-weight: 700; color: #1a1a1a; margin: 0 0 .2rem; letter-spacing: -.03em; }
.cvd__date { font-size: .85rem; color: #60725d; margin: 0; }
.cvd__header-right { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.cvd__alert { display: flex; align-items: center; gap: .5rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .55rem 1rem; border-radius: 10px; font-size: .825rem; font-weight: 600; }
.cvd__voz-btn {
  display: flex; align-items: center; gap: .5rem;
  background: #1b5e20; color: #e8f5e9; border: none;
  padding: .6rem 1.1rem; border-radius: 10px; font-size: .875rem;
  font-weight: 600; cursor: pointer; transition: background .15s;
  box-shadow: 0 2px 8px rgba(27,94,32,.25);
}
.cvd__voz-btn:hover { background: #104417; }
.cvd__voz-btn i { font-size: 1rem; }

.cvd__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.cvd__spinner { width: 22px; height: 22px; border: 2.5px solid #d4e6d4; border-top-color: #1b5e20; border-radius: 50%; animation: cvd-spin .6s linear infinite; flex-shrink: 0; }
.cvd__spinner--sm { width: 14px; height: 14px; border-width: 2px; border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes cvd-spin { to { transform: rotate(360deg); } }

.cvd__section { margin-bottom: 2rem; }
.cvd__section-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; padding-bottom: .75rem; border-bottom: 1px solid #e8f0e9; }
.cvd__section-header--clickable { cursor: pointer; user-select: none; border-radius: 8px; padding: .5rem .25rem; margin-bottom: .75rem; border-bottom: none; transition: background .15s; }
.cvd__section-header--clickable:hover { background: #f0fdf4; }
.cvd__section-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; display: flex; align-items: center; gap: .4rem; }
.cvd__badge { display: inline-flex; align-items: center; justify-content: center; background: #e8f5e9; color: #1b5e20; font-size: .7rem; font-weight: 700; width: 20px; height: 20px; border-radius: 999px; }
.cvd__chevron { color: #60725d; font-size: .8rem; }

.cvd__filtros { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; margin-bottom: .85rem; }
.cvd__filtro-pill { display: inline-flex; align-items: center; gap: .3rem; padding: .35rem .8rem; border: 1.5px solid #d4e6d4; border-radius: 999px; background: #f4f8f4; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; color: #60725d; }
.cvd__filtro-pill:hover { border-color: #1b5e20; color: #1b5e20; }
.cvd__filtro-pill--active { background: #e8f5e9; border-color: #1b5e20; color: #1b5e20; }
.cvd__filtro-sep { width: 1px; height: 18px; background: #d4e6d4; flex-shrink: 0; }

.cvd__empty { text-align: center; padding: 3rem 1rem; background: #f4f8f4; border: 1px dashed #d4e6d4; border-radius: 14px; }
.cvd__empty--inline { display: flex; align-items: center; gap: .75rem; justify-content: center; padding: 1.5rem; background: #f4f8f4; border: 1px solid #e8f0e9; border-radius: 12px; }
.cvd__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; }
.cvd__empty p { color: #60725d; font-size: .9rem; margin: 0; font-weight: 500; }
.cvd__empty-hint { font-size: .78rem; color: #94a3b8; margin-top: .3rem; display: block; }

.cvd__salas { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; }
.cvd__sala-card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; text-decoration: none; color: inherit; display: flex; flex-direction: column; transition: box-shadow .2s, transform .15s; }
.cvd__sala-card:hover { box-shadow: 0 8px 28px rgba(27,94,32,.12); transform: translateY(-2px); }
.cvd__sala-bar { height: 3px; }
.cvd__sala-body { padding: 1.1rem; }
.cvd__sala-head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; margin-bottom: .9rem; }
.cvd__sala-nombre { font-size: .95rem; font-weight: 700; color: #1a1a1a; margin: 0 0 .15rem; }
.cvd__sala-sede { font-size: .72rem; color: #94a3b8; font-weight: 500; }
.cvd__sala-estado { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; padding: .2em .6em; border-radius: 999px; flex-shrink: 0; }
.cvd__sala-estado--activa        { background: #dcfce7; color: #15803d; }
.cvd__sala-estado--mantenimiento { background: #fef3c7; color: #b45309; }
.cvd__sala-estado--cerrada       { background: #f1f5f9; color: #64748b; }
.cvd__sala-metrics { display: flex; gap: 1rem; margin-bottom: .75rem; }
.cvd__metric { display: flex; flex-direction: column; }
.cvd__metric-value { font-size: 1.1rem; font-weight: 700; color: #1a1a1a; line-height: 1; }
.cvd__metric-label { font-size: .65rem; color: #94a3b8; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; margin-top: .15rem; }
.cvd__sala-progress { height: 4px; background: #e8f5e9; border-radius: 999px; overflow: hidden; margin-bottom: .75rem; }
.cvd__sala-progress-fill { height: 100%; border-radius: 999px; transition: width .4s ease; }
.cvd__sala-footer { display: flex; align-items: center; justify-content: space-between; }
.cvd__sala-kind { font-size: .72rem; color: #94a3b8; font-weight: 500; }
.cvd__sala-cta { font-size: .75rem; font-weight: 700; color: #1b5e20; opacity: 0; transition: opacity .15s; }
.cvd__sala-card:hover .cvd__sala-cta { opacity: 1; }

.cvd__tareas { display: flex; flex-direction: column; gap: .5rem; }
.cvd__tarea { display: flex; align-items: center; gap: .75rem; padding: .85rem 1rem; background: #fff; border: 1px solid #d4e6d4; border-radius: 10px; border-left: 3px solid #d4e6d4; transition: box-shadow .15s; }
.cvd__tarea:hover { box-shadow: 0 2px 10px rgba(27,94,32,.08); }
.cvd__tarea--urgente { border-left-color: #dc2626; }
.cvd__tarea--alta    { border-left-color: #ea580c; }
.cvd__tarea--normal  { border-left-color: #2563eb; }
.cvd__tarea--baja    { border-left-color: #94a3b8; }
.cvd__tarea-btn { width: 32px; height: 32px; border-radius: 50%; border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; font-size: .85rem; flex-shrink: 0; transition: all .15s; }
.cvd__tarea-btn--start { background: #e8f5e9; color: #1b5e20; }
.cvd__tarea-btn--start:hover { background: #1b5e20; color: #fff; }
.cvd__tarea-btn--done  { background: #fef3c7; color: #b45309; }
.cvd__tarea-btn--done:hover { background: #16a34a; color: #fff; }
.cvd__tarea-check { width: 32px; height: 32px; border-radius: 50%; background: #dcfce7; color: #15803d; display: flex; align-items: center; justify-content: center; font-size: .85rem; font-weight: 700; flex-shrink: 0; }
.cvd__tarea-info { flex: 1; min-width: 0; }
.cvd__tarea-titulo { font-size: .875rem; font-weight: 600; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cvd__tarea-titulo--done { text-decoration: line-through; color: #94a3b8; }
.cvd__tarea-meta { font-size: .72rem; color: #94a3b8; margin-top: .15rem; }
.cvd__tarea-prioridad { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; padding: .2em .55em; border-radius: 6px; flex-shrink: 0; }
.cvd__tarea-prioridad--urgente { background: #fef2f2; color: #dc2626; }
.cvd__tarea-prioridad--alta    { background: #fff7ed; color: #ea580c; }
.cvd__tarea-prioridad--normal  { background: #eff6ff; color: #2563eb; }
.cvd__tarea-prioridad--baja    { background: #f0fdf4; color: #16a34a; }

.cvd__proximas { display: flex; flex-direction: column; gap: .4rem; }
.cvd__proxima { display: grid; grid-template-columns: 90px 1fr auto; gap: .75rem; align-items: center; padding: .7rem 1rem; background: #f4f8f4; border-radius: 10px; border: 1px solid #e8f0e9; }
.cvd__proxima-fecha { font-size: .72rem; color: #60725d; font-weight: 600; text-transform: capitalize; }
.cvd__proxima-titulo { font-size: .85rem; font-weight: 500; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cvd__proxima-sala { font-size: .72rem; color: #94a3b8; text-align: right; white-space: nowrap; }

.cvd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.cvd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 440px; box-shadow: 0 24px 64px rgba(27,94,32,.15); }
.cvd__modal-header { display: flex; align-items: center; justify-content: space-between; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; }
.cvd__modal-title { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.cvd__modal-close { background: #e8f5e9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; }
.cvd__modal-close:hover { background: #c8e6c9; color: #1b5e20; }
.cvd__modal-body { padding: 1.25rem 1.5rem; }
.cvd__modal-tarea-nombre { font-size: .9rem; font-weight: 600; color: #1a1a1a; margin-bottom: 1.25rem; padding: .75rem; background: #f4f8f4; border-radius: 8px; }
.cvd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; }
.cvd__field { margin-bottom: 1rem; }
.cvd__label { display: block; font-size: .8rem; font-weight: 600; color: #374151; margin-bottom: .35rem; }
.cvd__optional { font-size: .7rem; font-weight: 400; color: #94a3b8; }
.cvd__input-group { display: flex; align-items: center; }
.cvd__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.cvd__input-group .cvd__input { border-radius: 8px 0 0 8px; }
.cvd__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.cvd__input-suffix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .6rem .75rem; font-size: .8rem; font-weight: 600; color: #1b5e20; border-radius: 0 8px 8px 0; white-space: nowrap; }
.cvd__textarea { resize: vertical; min-height: 70px; }
.cvd__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.cvd__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }
.cvd__btn-success { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.cvd__btn-success:hover { background: #104417; }
.cvd__btn-success:disabled { opacity: .6; cursor: not-allowed; }
</style>
