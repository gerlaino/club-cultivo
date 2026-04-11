<template>
  <div class="ag">

    <!-- Header -->
    <div class="ag__header">
      <div>
        <h1 class="ag__greeting">{{ saludo }}, {{ auth.user?.first_name }}</h1>
        <p class="ag__date">{{ hoy }} · Responsable de Cultivo</p>
      </div>
    </div>

    <div v-if="loading" class="ag__loading">
      <div class="ag__spinner"></div>
      <span>Cargando sala de control…</span>
    </div>

    <template v-else>

      <!-- Alertas críticas -->
      <div v-if="alertas.length > 0" class="ag__alertas">
        <div v-for="a in alertas" :key="a.id" class="ag__alerta" :class="`ag__alerta--${a.tipo}`">
          <i class="bi" :class="a.icono"></i>
          <span>{{ a.mensaje }}</span>
          <RouterLink v-if="a.link" :to="a.link" class="ag__alerta-link">Ver →</RouterLink>
        </div>
      </div>

      <!-- KPIs reales -->
      <div class="ag__kpis">
        <div class="ag__kpi">
          <div class="ag__kpi-top">
            <span class="ag__kpi-icon">🌿</span>
            <span v-if="kpis.lotesEnRiesgo > 0" class="ag__kpi-alerta">{{ kpis.lotesEnRiesgo }} en riesgo</span>
          </div>
          <div class="ag__kpi-value" :class="{ 'ag__kpi-value--warn': kpis.lotesEnRiesgo > 0 }">
            {{ kpis.lotesActivos }}
          </div>
          <div class="ag__kpi-label">Lotes activos</div>
        </div>

        <div class="ag__kpi">
          <div class="ag__kpi-top"><span class="ag__kpi-icon">🪴</span></div>
          <div class="ag__kpi-value">{{ kpis.plantasActivas }}</div>
          <div class="ag__kpi-label">Plantas activas</div>
        </div>

        <div class="ag__kpi" :class="{ 'ag__kpi--danger': kpis.tareasVencidas > 0 }">
          <div class="ag__kpi-top"><span class="ag__kpi-icon">⚠️</span></div>
          <div class="ag__kpi-value" :class="{ 'ag__kpi-value--red': kpis.tareasVencidas > 0 }">
            {{ kpis.tareasVencidas }}
          </div>
          <div class="ag__kpi-label">Tareas vencidas</div>
        </div>

        <div class="ag__kpi" :class="{ 'ag__kpi--warn': kpis.docsPorVencer > 0 }">
          <div class="ag__kpi-top"><span class="ag__kpi-icon">📋</span></div>
          <div class="ag__kpi-value" :class="{ 'ag__kpi-value--warn': kpis.docsPorVencer > 0 }">
            {{ kpis.docsPorVencer }}
          </div>
          <div class="ag__kpi-label">Docs por vencer</div>
        </div>
      </div>

      <!-- Layout principal -->
      <div class="ag__layout">
        <div class="ag__main">

          <!-- Estado del cultivo — kanban por ciclo -->
          <div class="ag__section">
            <div class="ag__section-header">
              <h2 class="ag__section-title">🌱 Estado del cultivo</h2>
              <RouterLink to="/lotes" class="ag__section-link">Ver todos →</RouterLink>
            </div>
            <div class="ag__kanban">
              <div v-for="etapa in CICLO" :key="etapa.key" class="ag__kanban-col">
                <div class="ag__kanban-header" :style="{ borderColor: etapa.color }">
                  <span>{{ etapa.emoji }}</span>
                  <span class="ag__kanban-label">{{ etapa.label }}</span>
                  <span class="ag__kanban-count" :style="{ background: etapa.color + '20', color: etapa.color }">
                    {{ lotesPorEtapa(etapa.key).length }}
                  </span>
                </div>
                <div class="ag__kanban-cards">
                  <RouterLink
                    v-for="lote in lotesPorEtapa(etapa.key)"
                    :key="lote.id"
                    :to="{ name: 'lote-detail', params: { id: lote.id } }"
                    class="ag__kanban-card"
                    :class="{ 'ag__kanban-card--alerta': lote.dias_sin_registro > 5 }"
                  >
                    <div class="ag__kc-codigo">{{ lote.codigo }}</div>
                    <div class="ag__kc-info">
                      <span>{{ lote.plants_count }} plantas</span>
                      <span class="ag__kc-dias" :class="{ 'ag__kc-dias--warn': lote.dias_sin_registro > 5 }">
                        {{ lote.dias_desde_inicio }}d ciclo
                      </span>
                    </div>
                    <div v-if="lote.dias_sin_registro > 5" class="ag__kc-alerta">
                      ⚠️ Sin registro hace {{ lote.dias_sin_registro }}d
                    </div>
                    <div class="ag__kc-strain">{{ lote.strain || '—' }}</div>
                  </RouterLink>
                  <div v-if="lotesPorEtapa(etapa.key).length === 0" class="ag__kanban-empty">
                    Sin lotes
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Tareas vencidas o urgentes -->
          <div v-if="tareasUrgentes.length > 0" class="ag__section ag__section--mt">
            <div class="ag__section-header">
              <h2 class="ag__section-title">🔴 Requieren atención inmediata</h2>
              <RouterLink to="/tareas" class="ag__section-link">Ver todas →</RouterLink>
            </div>
            <div class="ag__tareas-urgentes">
              <div v-for="t in tareasUrgentes.slice(0,5)" :key="t.id" class="ag__tarea-urgente">
                <div class="ag__tu-prioridad" :class="`ag__tu-prioridad--${t.prioridad}`">
                  {{ t.prioridad }}
                </div>
                <div class="ag__tu-info">
                  <div class="ag__tu-titulo">{{ t.titulo }}</div>
                  <div class="ag__tu-meta">
                    {{ t.asignada_a?.nombre || 'Sin asignar' }}
                    <span v-if="t.lote"> · {{ t.lote.codigo }}</span>
                    <span v-if="t.sala"> · {{ t.sala.nombre }}</span>
                  </div>
                </div>
                <div class="ag__tu-fecha" :class="{ 'ag__tu-fecha--vencida': estaVencida(t) }">
                  {{ estaVencida(t) ? '⚠️ Vencida' : formatFecha(t.fecha_programada) }}
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Aside derecho -->
        <div class="ag__aside">

          <!-- Documentos -->
          <div class="ag__card">
            <div class="ag__card-header">
              <span class="ag__card-title">📁 Documentos</span>
              <RouterLink to="/documentos" class="ag__section-link">Ver todos →</RouterLink>
            </div>
            <div v-if="documentos.length === 0" class="ag__card-empty">
              <p>Sin documentos cargados</p>
              <RouterLink to="/documentos" class="ag__btn-outline-sm">Ir a Documentos</RouterLink>
            </div>
            <div v-else class="ag__docs">
              <div v-for="d in documentos" :key="d.id" class="ag__doc">
                <div class="ag__doc-icon">{{ DOC_TIPOS[d.tipo]?.emoji || '📄' }}</div>
                <div class="ag__doc-info">
                  <div class="ag__doc-titulo">{{ d.titulo }}</div>
                  <div class="ag__doc-meta">{{ DOC_TIPOS[d.tipo]?.label || d.tipo }}</div>
                  <div v-if="d.fecha_vencimiento" class="ag__doc-vence"
                       :class="{ 'ag__doc-vence--warn': diasParaVencer(d) <= 30, 'ag__doc-vence--danger': diasParaVencer(d) <= 0 }">
                    {{ diasParaVencer(d) <= 0 ? '⚠️ Vencido' : diasParaVencer(d) <= 30 ? `⏰ Vence en ${diasParaVencer(d)}d` : `Vence ${formatFecha(d.fecha_vencimiento)}` }}
                  </div>
                </div>
                <a v-if="d.tiene_archivo && d.archivo_url" :href="d.archivo_url" target="_blank" class="ag__doc-dl">
                  <i class="bi bi-download"></i>
                </a>
              </div>
            </div>
          </div>

          <!-- Actividad reciente -->
          <div class="ag__card ag__card--mt">
            <div class="ag__card-header">
              <span class="ag__card-title">📊 Actividad reciente</span>
            </div>
            <div class="ag__actividad">
              <div v-for="a in actividadReciente.slice(0,6)" :key="a.id + a._tipo" class="ag__act-item">
                <div class="ag__act-dot" :style="{ background: a._color }"></div>
                <div class="ag__act-info">
                  <div class="ag__act-texto">{{ a.texto }}</div>
                  <div class="ag__act-fecha">{{ formatDateTime(a.fecha) }}</div>
                </div>
              </div>
              <div v-if="actividadReciente.length === 0" class="ag__card-empty">
                <p>Sin actividad reciente</p>
              </div>
            </div>
          </div>

        </div>
      </div>

    </template>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAuthStore }   from '../../stores/auth'
import { useLotesStore }  from '../../stores/lotes'
import { useSalasStore }  from '../../stores/salas'
import { useTareasStore } from '../../stores/tareas'
import { getDocumentos, listTareas } from '../../lib/api.js'

const auth        = useAuthStore()
const lotesStore  = useLotesStore()
const salasStore  = useSalasStore()
const tareasStore = useTareasStore()

const loading     = ref(true)
const lotes       = ref([])
const tareas      = ref([])
const documentos  = ref([])

const CICLO = [
  { key:'semilla',    label:'Semilla',    emoji:'🌱', color:'#64748b' },
  { key:'vegetativo', label:'Vegetativo', emoji:'🍃', color:'#16a34a' },
  { key:'floracion',  label:'Floración',  emoji:'🌸', color:'#d97706' },
  { key:'cosecha',    label:'Cosecha',    emoji:'✂️',  color:'#92400e' },
  { key:'curado',     label:'Curado',     emoji:'🫙', color:'#2563eb' },
]

const DOC_TIPOS = {
  plan_trabajo:      { label:'Plan de trabajo',    emoji:'📋' },
  reprocann:         { label:'REPROCANN',           emoji:'🏛️' },
  informe_semestral: { label:'Informe semestral',  emoji:'📊' },
  otro:              { label:'Otro',               emoji:'📄' },
}

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = new Date().toLocaleDateString('es-AR', {
  weekday:'long', day:'numeric', month:'long', year:'numeric'
}).replace(/^\w/, c => c.toUpperCase())

const lotesActivos = computed(() =>
  lotes.value.filter(l => !['finalizado'].includes(l.estado))
)

function lotesPorEtapa(etapa) {
  return lotesActivos.value.filter(l => l.estado === etapa)
}

const tareasVencidas = computed(() =>
  tareas.value.filter(t => t.estado !== 'completada' && t.estado !== 'cancelada' && estaVencida(t))
)

const tareasUrgentes = computed(() =>
  tareas.value
    .filter(t => !['completada','cancelada'].includes(t.estado) && (t.prioridad === 'urgente' || estaVencida(t)))
    .sort((a,b) => {
      if (estaVencida(a) && !estaVencida(b)) return -1
      if (!estaVencida(a) && estaVencida(b)) return 1
      return 0
    })
)

const kpis = computed(() => ({
  lotesActivos:   lotesActivos.value.length,
  lotesEnRiesgo:  lotesActivos.value.filter(l => l.dias_sin_registro > 5).length,
  plantasActivas: lotes.value.reduce((acc, l) => acc + (l.plants_count || 0), 0),
  tareasVencidas: tareasVencidas.value.length,
  docsPorVencer:  documentos.value.filter(d => {
    if (!d.fecha_vencimiento) return false
    const dias = diasParaVencer(d)
    return dias >= 0 && dias <= 30
  }).length,
}))

const alertas = computed(() => {
  const lista = []
  if (tareasVencidas.value.length > 0) {
    lista.push({
      id: 'tareas-vencidas', tipo: 'danger', icono: 'bi-exclamation-triangle-fill',
      mensaje: `${tareasVencidas.value.length} tarea${tareasVencidas.value.length > 1 ? 's' : ''} vencida${tareasVencidas.value.length > 1 ? 's' : ''}`,
      link: '/tareas'
    })
  }
  lotesActivos.value.filter(l => l.dias_sin_registro > 7).forEach(l => {
    lista.push({
      id: `lote-${l.id}`, tipo: 'warn', icono: 'bi-clock-history',
      mensaje: `${l.codigo} lleva ${l.dias_sin_registro} días sin registro ambiental`,
      link: { name: 'lote-detail', params: { id: l.id } }
    })
  })
  documentos.value.filter(d => d.fecha_vencimiento && diasParaVencer(d) <= 15 && diasParaVencer(d) >= 0).forEach(d => {
    lista.push({
      id: `doc-${d.id}`, tipo: 'warn', icono: 'bi-file-earmark-x',
      mensaje: `"${d.titulo}" vence en ${diasParaVencer(d)} días`,
      link: null
    })
  })
  return lista
})

const actividadReciente = computed(() => {
  const items = []
  tareas.value
    .filter(t => t.estado === 'completada' && t.updated_at)
    .slice(0, 5)
    .forEach(t => items.push({
      id: t.id, _tipo: 'tarea', _color: '#16a34a',
      texto: `✅ ${t.titulo} completada por ${t.asignada_a?.nombre || '—'}`,
      fecha: t.updated_at
    }))
  documentos.value.slice(0, 3).forEach(d => items.push({
    id: d.id, _tipo: 'doc', _color: '#2563eb',
    texto: `📁 ${d.titulo} subido por ${d.usuario}`,
    fecha: d.created_at
  }))
  return items.sort((a,b) => new Date(b.fecha) - new Date(a.fecha))
})

function estaVencida(t) {
  if (!t.fecha_programada) return false
  return new Date(t.fecha_programada) < new Date() && t.estado !== 'completada'
}
function diasParaVencer(d) {
  if (!d.fecha_vencimiento) return 999
  return Math.floor((new Date(d.fecha_vencimiento) - new Date()) / 86400000)
}
function formatFecha(f) {
  if (!f) return '—'
  return new Date(f).toLocaleDateString('es-AR', { day:'numeric', month:'short' })
}
function formatDateTime(f) {
  if (!f) return '—'
  return new Date(f).toLocaleString('es-AR', { day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' })
}

onMounted(async () => {
  try {
    const [lotesRes, tareasRes, docsRes] = await Promise.all([
      lotesStore.fetch().then(() => lotesStore.items),
      listTareas({ limit: 100 }),
      getDocumentos(),
    ])
    lotes.value      = lotesRes || []
    tareas.value     = tareasRes?.data || []
    documentos.value = docsRes?.data || []
  } catch(e) { console.error(e) }
  finally { loading.value = false }
})
</script>

<style scoped>
.ag { padding: 2rem 1.5rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .ag { padding: 1.25rem 1rem; } }

.ag__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.ag__greeting { font-size: 1.65rem; font-weight: 800; color: #1a1a1a; margin: 0 0 .2rem; letter-spacing: -.03em; }
.ag__date { font-size: .82rem; color: #60725d; margin: 0; }
.ag__header-actions { display: flex; gap: .5rem; flex-wrap: wrap; }

.ag__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.ag__spinner { width: 22px; height: 22px; border: 2.5px solid #d4e6d4; border-top-color: #1b5e20; border-radius: 50%; animation: ag-spin .6s linear infinite; }
.ag__spinner--sm { width: 14px; height: 14px; border-width: 2px; border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes ag-spin { to { transform: rotate(360deg); } }

.ag__alertas { display: flex; flex-direction: column; gap: .5rem; margin-bottom: 1.5rem; }
.ag__alerta { display: flex; align-items: center; gap: .6rem; padding: .65rem 1rem; border-radius: 10px; font-size: .835rem; font-weight: 500; }
.ag__alerta--danger { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; }
.ag__alerta--warn   { background: #fffbeb; border: 1px solid #fde68a; color: #b45309; }
.ag__alerta-link { margin-left: auto; font-weight: 700; color: inherit; text-decoration: none; border-bottom: 1px solid currentColor; font-size: .78rem; }

.ag__kpis { display: grid; grid-template-columns: repeat(4,1fr); gap: 1rem; margin-bottom: 2rem; }
@media (max-width: 640px) { .ag__kpis { grid-template-columns: repeat(2,1fr); } }
.ag__kpi { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.1rem 1rem; transition: box-shadow .15s; }
.ag__kpi:hover { box-shadow: 0 4px 16px rgba(27,94,32,.1); }
.ag__kpi--danger { border-color: #fecaca; background: #fef2f2; }
.ag__kpi--warn   { border-color: #fde68a; background: #fffbeb; }
.ag__kpi-top { display: flex; align-items: center; justify-content: space-between; margin-bottom: .6rem; }
.ag__kpi-icon { font-size: 1.3rem; }
.ag__kpi-alerta { font-size: .62rem; font-weight: 700; background: #fef2f2; color: #dc2626; padding: .15em .5em; border-radius: 999px; }
.ag__kpi-value { font-size: 2rem; font-weight: 800; color: #1a1a1a; line-height: 1; letter-spacing: -.04em; margin-bottom: .25rem; }
.ag__kpi-value--warn { color: #b45309; }
.ag__kpi-value--red  { color: #dc2626; }
.ag__kpi-label { font-size: .7rem; color: #60725d; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; }

.ag__layout { display: grid; grid-template-columns: 1fr 300px; gap: 1.25rem; align-items: start; }
@media (max-width: 960px) { .ag__layout { grid-template-columns: 1fr; } }

.ag__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.25rem; }
.ag__section--mt { margin-top: 1.25rem; }
.ag__section-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; }
.ag__section-title { font-size: .95rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.ag__section-link { font-size: .78rem; color: #60725d; text-decoration: none; font-weight: 500; }
.ag__section-link:hover { color: #1b5e20; }

.ag__kanban { display: grid; grid-template-columns: repeat(5,1fr); gap: .75rem; overflow-x: auto; }
@media (max-width: 900px) { .ag__kanban { grid-template-columns: repeat(3,1fr); } }
.ag__kanban-col { display: flex; flex-direction: column; gap: .5rem; min-width: 140px; }
.ag__kanban-header { display: flex; align-items: center; gap: .4rem; padding: .5rem .65rem; border-radius: 8px; border-left: 3px solid; background: #f8fafc; margin-bottom: .25rem; }
.ag__kanban-label { font-size: .72rem; font-weight: 700; color: #1a1a1a; flex: 1; }
.ag__kanban-count { font-size: .65rem; font-weight: 800; padding: .15em .5em; border-radius: 999px; }
.ag__kanban-empty { font-size: .72rem; color: #94a3b8; text-align: center; padding: .75rem .5rem; background: #f8fafc; border-radius: 8px; border: 1px dashed #e2e8f0; }
.ag__kanban-cards { display: flex; flex-direction: column; gap: .4rem; }
.ag__kanban-card { background: #fff; border: 1px solid #d4e6d4; border-radius: 8px; padding: .6rem .75rem; text-decoration: none; color: inherit; transition: all .15s; display: block; }
.ag__kanban-card:hover { box-shadow: 0 2px 10px rgba(27,94,32,.1); transform: translateY(-1px); }
.ag__kanban-card--alerta { border-color: #fde68a; background: #fffbeb; }
.ag__kc-codigo { font-size: .7rem; font-weight: 800; color: #1b5e20; font-family: monospace; margin-bottom: .25rem; }
.ag__kc-info { display: flex; align-items: center; justify-content: space-between; margin-bottom: .2rem; }
.ag__kc-dias { font-size: .65rem; color: #94a3b8; font-weight: 500; }
.ag__kc-dias--warn { color: #b45309; font-weight: 700; }
.ag__kc-alerta { font-size: .62rem; color: #b45309; font-weight: 600; margin-bottom: .2rem; }
.ag__kc-strain { font-size: .68rem; color: #60725d; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.ag__tareas-urgentes { display: flex; flex-direction: column; gap: .4rem; }
.ag__tarea-urgente { display: flex; align-items: center; gap: .75rem; padding: .7rem .9rem; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; }
.ag__tu-prioridad { font-size: .62rem; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; padding: .2em .55em; border-radius: 6px; flex-shrink: 0; }
.ag__tu-prioridad--urgente { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
.ag__tu-prioridad--alta    { background: #fff7ed; color: #ea580c; border: 1px solid #fed7aa; }
.ag__tu-info { flex: 1; min-width: 0; }
.ag__tu-titulo { font-size: .85rem; font-weight: 600; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ag__tu-meta   { font-size: .72rem; color: #94a3b8; }
.ag__tu-fecha  { font-size: .72rem; color: #94a3b8; white-space: nowrap; flex-shrink: 0; }
.ag__tu-fecha--vencida { color: #dc2626; font-weight: 700; }

.ag__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.ag__card--mt { margin-top: 1rem; }
.ag__card-header { display: flex; align-items: center; justify-content: space-between; padding: .85rem 1rem; border-bottom: 1px solid #e8f0e9; }
.ag__card-title  { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.ag__card-empty  { padding: 1.25rem 1rem; text-align: center; color: #60725d; font-size: .82rem; }
.ag__card-empty p { margin: 0 0 .5rem; }

.ag__docs { display: flex; flex-direction: column; }
.ag__doc  { display: flex; align-items: flex-start; gap: .6rem; padding: .75rem 1rem; border-bottom: 1px solid #f0fdf4; }
.ag__doc:last-child { border-bottom: none; }
.ag__doc-icon  { font-size: 1.3rem; flex-shrink: 0; }
.ag__doc-info  { flex: 1; min-width: 0; }
.ag__doc-titulo{ font-size: .82rem; font-weight: 600; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ag__doc-meta  { font-size: .7rem; color: #94a3b8; }
.ag__doc-vence { font-size: .7rem; font-weight: 600; margin-top: .15rem; }
.ag__doc-vence--warn   { color: #b45309; }
.ag__doc-vence--danger { color: #dc2626; }
.ag__doc-dl { color: #60725d; font-size: .85rem; flex-shrink: 0; padding: .25rem; transition: color .15s; }
.ag__doc-dl:hover { color: #1b5e20; }

.ag__actividad { display: flex; flex-direction: column; }
.ag__act-item { display: flex; align-items: flex-start; gap: .6rem; padding: .65rem 1rem; border-bottom: 1px solid #f0fdf4; }
.ag__act-item:last-child { border-bottom: none; }
.ag__act-dot  { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; margin-top: .3rem; }
.ag__act-info { flex: 1; min-width: 0; }
.ag__act-texto{ font-size: .78rem; color: #1a1a1a; line-height: 1.4; }
.ag__act-fecha{ font-size: .68rem; color: #94a3b8; margin-top: .1rem; }

.ag__btn-outline-sm { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .4rem .9rem; border-radius: 8px; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.ag__btn-outline-sm:hover { border-color: #1b5e20; background: #f0fdf4; }
.ag__empty { text-align: center; padding: 1.5rem; color: #60725d; font-size: .875rem; }
</style>
