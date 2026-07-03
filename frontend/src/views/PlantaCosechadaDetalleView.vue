<template>
  <div class="pcd">

    <Breadcrumb :items="[
      { label: 'Mis cosechas', to: { name: 'cosechado' } },
      { label: loteInfo?.codigo || `Lote #${loteId}`, to: { name: 'cosechado-detalle', params: { id: loteId } } },
      { label: planta?.nombre || `Planta #${id}` },
    ]" />

    <div v-if="loading" class="pcd__loading"><DsSpinner /></div>
    <div v-else-if="error" class="pcd__error">{{ error }}</div>

    <template v-else-if="planta">

      <!-- Hero -->
      <div class="pcd__hero">
        <div class="pcd__hero-left">
          <div class="pcd__hero-title-row">
            <span class="pcd__hero-emoji">🌱</span>
            <h1 class="pcd__title">{{ planta.nombre }}</h1>
            <span v-if="planta.es_seleccion" class="pcd__sel-badge">★ Selección</span>
          </div>
          <p class="pcd__subtitle">
            <span v-if="loteInfo?.genetica">{{ loteInfo.genetica.nombre }}</span>
            <span v-if="loteInfo?.codigo" class="pcd__sep">·</span>
            <span v-if="loteInfo?.codigo">{{ loteInfo.codigo }}</span>
          </p>
        </div>
        <div class="pcd__hero-pesos">
          <div v-if="planta.peso_seco" class="pcd__peso">
            <span class="pcd__peso-val">{{ planta.peso_seco }}g</span>
            <span class="pcd__peso-lbl">Peso seco</span>
          </div>
          <div v-if="planta.peso_humedo" class="pcd__peso">
            <span class="pcd__peso-val pcd__peso-val--muted">{{ planta.peso_humedo }}g</span>
            <span class="pcd__peso-lbl">Peso bruto al corte</span>
          </div>
        </div>
      </div>

      <!-- Fechas del ciclo -->
      <div v-if="tieneFechas" class="pcd__fechas-grid">
        <div v-if="planta.fecha_germinacion" class="pcd__fecha-item">
          <span class="pcd__fecha-lbl">Germinación</span>
          <span class="pcd__fecha-val">{{ formatFecha(planta.fecha_germinacion) }}</span>
        </div>
        <div v-if="planta.fecha_vegetativo" class="pcd__fecha-item">
          <span class="pcd__fecha-lbl">Vegetativo</span>
          <span class="pcd__fecha-val">{{ formatFecha(planta.fecha_vegetativo) }}</span>
        </div>
        <div v-if="planta.fecha_floracion" class="pcd__fecha-item">
          <span class="pcd__fecha-lbl">Floración</span>
          <span class="pcd__fecha-val">{{ formatFecha(planta.fecha_floracion) }}</span>
        </div>
        <div v-if="planta.fecha_cosecha" class="pcd__fecha-item">
          <span class="pcd__fecha-lbl">Cosecha</span>
          <span class="pcd__fecha-val">{{ formatFecha(planta.fecha_cosecha) }}</span>
        </div>
        <div v-if="diasVegetativo" class="pcd__fecha-item">
          <span class="pcd__fecha-lbl">Días veg.</span>
          <span class="pcd__fecha-val pcd__fecha-val--days">{{ diasVegetativo }}d</span>
        </div>
        <div v-if="diasFloracion" class="pcd__fecha-item">
          <span class="pcd__fecha-lbl">Días flor.</span>
          <span class="pcd__fecha-val pcd__fecha-val--days">{{ diasFloracion }}d</span>
        </div>
      </div>

      <!-- Notas -->
      <div v-if="planta.notas" class="pcd__notas">
        <span class="pcd__notas-ico">📝</span>
        <p>{{ planta.notas }}</p>
      </div>

      <!-- Historial de actividades -->
      <div class="pcd__section">
        <h2 class="pcd__section-title">
          Historial de actividades
          <span v-if="actividades.length" class="pcd__section-count">{{ actividades.length }}</span>
        </h2>
        <div v-if="loadingActividades" class="pcd__loading-sm"><DsSpinner :size="20" /></div>
        <div v-else-if="!actividades.length" class="pcd__empty">Sin actividades registradas para esta planta.</div>
        <div v-else class="pcd__timeline">
          <div
            v-for="act in actividades"
            :key="act.id"
            class="pcd__ev"
            :class="act._heredado ? 'pcd__ev--ambiental' : 'pcd__ev--actividad'"
          >
            <div class="pcd__ev-dot"></div>
            <div class="pcd__ev-body">
              <div class="pcd__ev-header">
                <span class="pcd__ev-tipo">{{ actividadLabel(act) }}</span>
                <span class="pcd__ev-fecha">{{ formatFechaHora(act.occurred_at) }}</span>
              </div>

              <!-- Descripción -->
              <p v-if="act.description" class="pcd__ev-desc">{{ act.description }}</p>

              <!-- Metadata de registro de planta -->
              <div v-if="act.activity_type === 'registro_planta' && act.metadata" class="pcd__meta-grid">
                <div v-if="act.metadata.altura_cm"    class="pcd__meta-item"><span class="pcd__meta-k">Altura</span><span class="pcd__meta-v">{{ act.metadata.altura_cm }} cm</span></div>
                <div v-if="act.metadata.num_colas"    class="pcd__meta-item"><span class="pcd__meta-k">Colas</span><span class="pcd__meta-v">{{ act.metadata.num_colas }}</span></div>
                <div v-if="act.metadata.estado_salud" class="pcd__meta-item"><span class="pcd__meta-k">Salud</span><span class="pcd__meta-v">{{ act.metadata.estado_salud }}</span></div>
                <div v-if="act.metadata.color_hojas"  class="pcd__meta-item"><span class="pcd__meta-k">Color</span><span class="pcd__meta-v">{{ act.metadata.color_hojas }}</span></div>
              </div>

              <!-- Metadata de registro ambiental heredado -->
              <div v-if="act._heredado && act.metadata" class="pcd__meta-grid">
                <div v-if="act.metadata.temperatura"    class="pcd__meta-item"><span class="pcd__meta-k">Temp.</span><span class="pcd__meta-v">{{ act.metadata.temperatura }}°C</span></div>
                <div v-if="act.metadata.humedad"        class="pcd__meta-item"><span class="pcd__meta-k">Humedad</span><span class="pcd__meta-v">{{ act.metadata.humedad }}%</span></div>
                <div v-if="act.metadata.ph"             class="pcd__meta-item"><span class="pcd__meta-k">pH</span><span class="pcd__meta-v">{{ act.metadata.ph }}</span></div>
                <div v-if="act.metadata.ec"             class="pcd__meta-item"><span class="pcd__meta-k">EC</span><span class="pcd__meta-v">{{ act.metadata.ec }}</span></div>
                <div v-if="act.metadata.co2"            class="pcd__meta-item"><span class="pcd__meta-k">CO₂</span><span class="pcd__meta-v">{{ act.metadata.co2 }} ppm</span></div>
                <div v-if="act.metadata.ppfd"           class="pcd__meta-item"><span class="pcd__meta-k">PPFD</span><span class="pcd__meta-v">{{ act.metadata.ppfd }}</span></div>
                <template v-if="act.metadata.tareas_realizadas?.length">
                  <div class="pcd__meta-item pcd__meta-item--full">
                    <span class="pcd__meta-k">Tareas</span>
                    <span class="pcd__meta-v">{{ act.metadata.tareas_realizadas.join(', ') }}</span>
                  </div>
                </template>
                <template v-if="act.metadata.fertilizacion">
                  <div class="pcd__meta-item pcd__meta-item--full">
                    <span class="pcd__meta-k">Fertilización</span>
                    <span class="pcd__meta-v">{{ act.metadata.fertilizacion }}{{ act.metadata.notas_fertilizacion ? ' — ' + act.metadata.notas_fertilizacion : '' }}</span>
                  </div>
                </template>
                <div v-if="act.metadata.plagas_observadas" class="pcd__meta-item pcd__meta-item--full">
                  <span class="pcd__meta-k">⚠️ Plagas</span>
                  <span class="pcd__meta-v">{{ act.metadata.plagas_observadas }}</span>
                </div>
              </div>

              <!-- Metadata de trasplante -->
              <div v-if="act.activity_type === 'transplant' && act.metadata" class="pcd__meta-grid">
                <div v-if="act.metadata.maceta_origen_l"  class="pcd__meta-item"><span class="pcd__meta-k">Desde</span><span class="pcd__meta-v">{{ act.metadata.maceta_origen_l }}L</span></div>
                <div v-if="act.metadata.maceta_destino_l" class="pcd__meta-item"><span class="pcd__meta-k">Hasta</span><span class="pcd__meta-v">{{ act.metadata.maceta_destino_l }}L</span></div>
              </div>

              <p v-if="act.usuario" class="pcd__ev-autor">por {{ act.usuario }}</p>
            </div>
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { getPlant, getPlantActivities, getLote } from '../lib/api.js'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import DsSpinner  from '../design-system/components/Spinner.vue'

const route  = useRoute()
const id     = Number(route.params.id)
const loteId = Number(route.params.loteId)

const loading           = ref(true)
const loadingActividades= ref(false)
const error             = ref(null)
const planta            = ref(null)
const loteInfo          = ref(null)
const actividades       = ref([])

const ACTIVITY_LABEL = {
  riego:                   '💧 Riego',
  poda:                    '✂️ Poda',
  medicion:                '📏 Medición',
  limpieza:                '🧹 Limpieza',
  cosecha:                 '🌿 Cosecha',
  transplant:              '🪴 Trasplante',
  inspeccion:              '🔍 Inspección',
  state_change:            '🔄 Cambio de estado',
  registro_planta:         '📋 Registro de planta',
  registro_ambiental_lote: '🌡️ Registro ambiental',
  lote_nota:               '📝 Nota del lote',
}
const TAREA_LABEL = {
  riego:            '💧 Riego',
  nutricion:        '🧪 Nutrición',
  poda:             '✂️ Poda',
  defoliacion:      '🍃 Defoliación',
  scrog_lst:        '🪢 SCROG/LST',
  revision_plagas:  '🔍 Rev. plagas',
  limpieza_sala:    '🧹 Limpieza',
  ajuste_luz:       '💡 Ajuste luz',
  registro_ambiental: '🌡️ Registro',
}
function actividadLabel(act) {
  if (act.activity_type === 'lote_nota') return '📝 Nota del lote'
  if (act._heredado) {
    const tareas = act.metadata?.tareas_realizadas
    if (tareas?.length) {
      return tareas.map(t => TAREA_LABEL[t] || t).join(' · ') + ' — lote'
    }
    return '🌡️ Registro ambiental — lote'
  }
  return ACTIVITY_LABEL[act.activity_type] || `📋 ${act.activity_type}`
}

const tieneFechas = computed(() =>
  planta.value && (planta.value.fecha_germinacion || planta.value.fecha_vegetativo ||
                   planta.value.fecha_floracion   || planta.value.fecha_cosecha)
)
const diasVegetativo = computed(() => {
  const p = planta.value
  if (!p?.fecha_vegetativo || !p?.fecha_floracion) return null
  return Math.round((new Date(p.fecha_floracion) - new Date(p.fecha_vegetativo)) / 86400000)
})
const diasFloracion = computed(() => {
  const p = planta.value
  if (!p?.fecha_floracion || !p?.fecha_cosecha) return null
  return Math.round((new Date(p.fecha_cosecha) - new Date(p.fecha_floracion)) / 86400000)
})

function formatFecha(d) {
  if (!d) return '—'
  return new Date(d + 'T00:00:00').toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}
function formatFechaHora(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

onMounted(async () => {
  try {
    const [plantRes, loteRes] = await Promise.all([
      getPlant(id),
      getLote(loteId),
    ])
    planta.value   = plantRes.data
    loteInfo.value = loteRes.data
  } catch {
    error.value = 'No se pudo cargar la planta.'
  } finally {
    loading.value = false
  }

  loadingActividades.value = true
  try {
    const { data } = await getPlantActivities(id)
    actividades.value = data || []
  } catch {
    actividades.value = []
  } finally {
    loadingActividades.value = false
  }
})
</script>

<style scoped>
.pcd { max-width: 760px; margin: 0 auto; padding: 1.5rem 1.25rem; display: flex; flex-direction: column; gap: 1.5rem; }
@media (max-width: 640px) { .pcd { padding: 1rem .75rem 80px; gap: 1.25rem; } }

.pcd__loading { display: flex; justify-content: center; padding: 4rem; }
.pcd__loading-sm { display: flex; justify-content: center; padding: 1.5rem; }
.pcd__error { color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; padding: 1rem 1.25rem; }

/* Hero */
.pcd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
.pcd__hero-left { flex: 1; min-width: 0; }
.pcd__hero-title-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; margin-bottom: .3rem; }
.pcd__hero-emoji { font-size: 1.4rem; line-height: 1; flex-shrink: 0; }
.pcd__title { font-size: 1.4rem; font-weight: 700; color: #0f2611; margin: 0; letter-spacing: -.025em; }
.pcd__sel-badge { font-size: .72rem; font-weight: 700; padding: .2em .6em; border-radius: 999px; background: #fef3c7; color: #92400e; white-space: nowrap; }
.pcd__subtitle { font-size: .875rem; color: #60725d; margin: 0; display: flex; align-items: center; flex-wrap: wrap; gap: .35rem; }
.pcd__sep { color: #c8e6c9; }
.pcd__hero-pesos { display: flex; gap: .75rem; flex-shrink: 0; }
.pcd__peso { display: flex; flex-direction: column; align-items: flex-end; }
.pcd__peso-val { font-size: 1.25rem; font-weight: 700; color: #1b5e20; line-height: 1; font-variant-numeric: tabular-nums; }
.pcd__peso-val--muted { color: #60725d; font-size: 1rem; }
.pcd__peso-lbl { font-size: .68rem; color: #9ca3af; text-transform: uppercase; letter-spacing: .05em; font-weight: 600; }

/* Fechas */
.pcd__fechas-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: .5rem; }
.pcd__fecha-item { background: #fff; border: 1px solid #e8f0e9; border-radius: 8px; padding: .6rem .75rem; display: flex; flex-direction: column; gap: 2px; }
.pcd__fecha-lbl { font-size: .68rem; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #9ca3af; }
.pcd__fecha-val { font-size: .82rem; font-weight: 600; color: #0f2611; }
.pcd__fecha-val--days { color: #1b5e20; font-size: 1rem; font-weight: 700; }

/* Notas */
.pcd__notas { display: flex; gap: .6rem; background: #fffbeb; border: 1px solid #fde68a; border-radius: 10px; padding: .875rem 1rem; }
.pcd__notas-ico { font-size: 1rem; flex-shrink: 0; }
.pcd__notas p { font-size: .85rem; color: #78350f; margin: 0; line-height: 1.6; }

/* Section */
.pcd__section { background: #fff; border: 1px solid #e8f0e9; border-radius: 12px; padding: 1.25rem; display: flex; flex-direction: column; gap: 1rem; }
.pcd__section-title { display: flex; align-items: center; gap: .5rem; font-size: 1rem; font-weight: 700; color: #0f2611; margin: 0; }
.pcd__section-count { display: inline-flex; align-items: center; justify-content: center; min-width: 20px; height: 20px; border-radius: 999px; background: #e8f0e9; color: #0f2611; font-size: .72rem; font-weight: 700; padding: 0 .35rem; }
.pcd__empty { font-size: .85rem; color: #9ca3af; }

/* Timeline */
.pcd__timeline { display: flex; flex-direction: column; }
.pcd__ev { display: flex; gap: .75rem; position: relative; padding-bottom: 1.25rem; }
.pcd__ev:last-child { padding-bottom: 0; }
.pcd__ev::before { content: ''; position: absolute; left: 7px; top: 16px; bottom: 0; width: 1px; background: #e8f0e9; }
.pcd__ev:last-child::before { display: none; }
.pcd__ev-dot { width: 15px; height: 15px; border-radius: 50%; flex-shrink: 0; margin-top: 2px; border: 2px solid #e8f0e9; background: #fff; z-index: 1; }
.pcd__ev--actividad .pcd__ev-dot { border-color: #1b5e20; background: #dcfce7; }
.pcd__ev--ambiental .pcd__ev-dot { border-color: #0369a1; background: #e0f2fe; }
.pcd__ev-body { flex: 1; min-width: 0; }
.pcd__ev-header { display: flex; align-items: baseline; justify-content: space-between; gap: .5rem; flex-wrap: wrap; margin-bottom: .2rem; }
.pcd__ev-tipo { font-size: .8rem; font-weight: 600; color: #0f2611; }
.pcd__ev-fecha { font-size: .72rem; color: #9ca3af; white-space: nowrap; }
.pcd__ev-desc { font-size: .82rem; color: #475569; margin: 0 0 .35rem; line-height: 1.5; }
.pcd__ev-autor { font-size: .72rem; color: #9ca3af; margin: .25rem 0 0; }

/* Metadata grid */
.pcd__meta-grid { display: flex; flex-wrap: wrap; gap: .3rem .75rem; margin-bottom: .2rem; }
.pcd__meta-item { display: flex; gap: .3rem; align-items: center; font-size: .75rem; }
.pcd__meta-item--full { width: 100%; }
.pcd__meta-k { color: #9ca3af; font-weight: 500; }
.pcd__meta-v { color: #0f2611; font-weight: 600; }
</style>
