<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { getGenetica, updateGenetica } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { usePermissions } from '../composables/usePermissions.js'
import { useQRCode } from '../composables/useQRCode.js'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import Paginator  from '../components/ui/Paginator.vue'
import Lightbox   from '../components/ui/Lightbox.vue'
import api from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'
import Chart from 'chart.js/auto'

const props = defineProps({ id: { type: Number, required: true } })

const router  = useRouter()
const auth    = useAuthStore()
const { can } = usePermissions()
const { downloadPNG, downloadSVG } = useQRCode()
const toast   = useToast()
const { confirm } = useConfirm()

const canUpdate = computed(() => can('geneticas', 'update'))

const gen            = ref(null)
const loading        = ref(true)
const error          = ref(null)
const toggling       = ref(false)
const qrDropdownOpen = ref(false)

const TIPO_META = {
  indica:    { label: 'Índica',    color: '#6f42c1' },
  sativa:    { label: 'Sativa',    color: '#198754' },
  hibrida:   { label: 'Híbrida',   color: '#fd7e14' },
  ruderalis: { label: 'Ruderalis', color: '#0dcaf0' },
}
const DIFICULTAD_META = {
  facil:   { label: 'Fácil',   icon: '🟢' },
  media:   { label: 'Media',   icon: '🟡' },
  dificil: { label: 'Difícil', icon: '🔴' },
}

const tipoMeta   = computed(() => TIPO_META[gen.value?.tipo] || { label: gen.value?.tipo || '—', color: '#6c757d' })
const difMeta    = computed(() => DIFICULTAD_META[gen.value?.dificultad] || null)
const terpenos   = computed(() =>
  gen.value?.terpenos
    ? gen.value.terpenos.split(',').map(t => t.trim()).filter(Boolean)
    : []
)

// Lotes con paginación (Paginator component)
const lotesPagina  = ref(1)
const lotesPerPage = ref(10)
const lotesTotales = computed(() => gen.value?.lotes_historicos || [])
const lotesTotal   = computed(() => lotesTotales.value.length)
const lotesPaginados = computed(() => {
  const start = (lotesPagina.value - 1) * lotesPerPage.value
  return lotesTotales.value.slice(start, start + lotesPerPage.value)
})

// Rendimiento promedio — usa rendimiento_real_g (oficial) cuando existe, si no g/planta
const rendimientoStats = computed(() => {
  const conReal = (gen.value?.lotes_historicos || []).filter(l => l.rendimiento_real_g != null && l.rendimiento_real_g > 0)
  if (conReal.length) {
    const vals = conReal.map(l => Number(l.rendimiento_real_g))
    return {
      avg:  (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1),
      max:  Math.max(...vals).toFixed(1),
      min:  Math.min(...vals).toFixed(1),
      n:    conReal.length,
      unit: 'g/lote',
    }
  }
  const fallback = (gen.value?.lotes_historicos || []).filter(l => l.rendimiento_gramos_planta != null && l.rendimiento_gramos_planta > 0)
  if (!fallback.length) return { avg: null, max: null, min: null, n: 0, unit: 'g/planta' }
  const vals = fallback.map(l => Number(l.rendimiento_gramos_planta))
  return {
    avg:  (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1),
    max:  Math.max(...vals).toFixed(1),
    min:  Math.min(...vals).toFixed(1),
    n:    fallback.length,
    unit: 'g/planta',
  }
})

// P&L resumen de la genética
const plResumen = computed(() => gen.value?.pl_resumen ?? null)

// Sparkline — rendimiento en el tiempo (lotes con rendimiento_real_g, orden cronológico)
const sparklineCanvas = ref(null)
let   sparklineChart  = null

const sparklineData = computed(() => {
  return (gen.value?.lotes_historicos || [])
    .filter(l => l.rendimiento_real_g != null && l.start_date)
    .sort((a, b) => new Date(a.start_date) - new Date(b.start_date))
    .map(l => ({ label: l.codigo, x: l.start_date?.slice(0, 7), y: l.rendimiento_real_g }))
})

function initSparkline() {
  if (!sparklineCanvas.value) return
  if (sparklineChart) { sparklineChart.destroy(); sparklineChart = null }
  if (sparklineData.value.length < 2) return

  sparklineChart = new Chart(sparklineCanvas.value, {
    type: 'line',
    data: {
      labels:   sparklineData.value.map(p => p.x),
      datasets: [{
        data:            sparklineData.value.map(p => p.y),
        borderColor:     '#1b5e20',
        backgroundColor: 'rgba(27,94,32,.08)',
        borderWidth:     2,
        pointRadius:     4,
        pointHoverRadius: 6,
        fill:            true,
        tension:         0.3,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            title: (items) => sparklineData.value[items[0].dataIndex]?.label ?? '',
            label: (ctx)  => `${ctx.raw} g`,
          },
        },
      },
      scales: {
        x: { ticks: { color: '#94a3b8', font: { size: 10 } }, grid: { display: false } },
        y: { ticks: { color: '#94a3b8', font: { size: 10 } }, grid: { color: '#f1f5f9' }, beginAtZero: false },
      },
    },
  })
}

watch(() => gen.value, async () => {
  await nextTick()
  initSparkline()
})

onUnmounted(() => { if (sparklineChart) sparklineChart.destroy() })

// Galería lightbox (Lightbox component)
const fotoActiva   = ref(0)
const lightboxOpen = ref(false)
const lightboxImages = computed(() =>
  (gen.value?.fotos || []).map(f => ({ src: f.url, alt: gen.value.nombre }))
)

function abrirLightbox(i) { fotoActiva.value = i; lightboxOpen.value = true }

function qrUrl()          { return `${window.location.origin}/g/${gen.value?.slug}` }
function qrFilename(ext)  { return `qr-genetica-${gen.value?.slug}.${ext}` }
async function descargarQRpng() { await downloadPNG(qrUrl(), qrFilename('png')) }
async function descargarQRsvg() { await downloadSVG(qrUrl(), qrFilename('svg')) }

async function toggleVisibleWeb() {
  if (!canUpdate.value || toggling.value) return
  toggling.value = true
  try {
    const { data } = await updateGenetica(gen.value.id, { visible_web: !gen.value.visible_web })
    gen.value.visible_web = data.visible_web
    toast.success(gen.value.visible_web ? 'Publicada en la web' : 'Ocultada de la web')
  } catch {
    toast.error('Error al actualizar visibilidad')
  } finally {
    toggling.value = false
  }
}

async function eliminarFoto(fotoId) {
  if (!canUpdate.value) return
  const ok = await confirm({ title: '¿Eliminar foto?', message: 'Esta acción no se puede deshacer.', confirmText: 'Eliminar' })
  if (!ok) return
  try {
    await api.delete(`/geneticas/${gen.value.id}/fotos/${fotoId}`)
    gen.value.fotos = gen.value.fotos.filter(f => f.id !== fotoId)
    if (fotoActiva.value >= gen.value.fotos.length) fotoActiva.value = Math.max(0, gen.value.fotos.length - 1)
    toast.success('Foto eliminada')
  } catch {
    toast.error('Error al eliminar la foto')
  }
}

function estadoLote(estado) {
  const MAP = {
    activo:    { label: 'Activo',    style: { background: '#1b5e20', color: '#fff' } },
    cosechado: { label: 'Cosechado', style: { background: '#64748b', color: '#fff' } },
    cancelado: { label: 'Cancelado', style: { background: '#b91c1c', color: '#fff' } },
  }
  return MAP[estado] || { label: estado, style: { background: '#64748b', color: '#fff' } }
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

onMounted(async () => {
  try {
    const { data } = await getGenetica(props.id)
    gen.value = data
  } catch {
    error.value = 'No se pudo cargar la genética'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="gdv">

    <!-- Loading -->
    <div v-if="loading" class="gdv__loading">
      <DsSpinner />
    </div>

    <!-- Error -->
    <div v-else-if="error" class="gdv__error">{{ error }}</div>

    <!-- Contenido -->
    <template v-else-if="gen">

      <Breadcrumb :items="[{ label: 'Genéticas', to: { name: 'geneticas' } }, { label: gen.nombre }]" />

      <!-- Hero card -->
      <div class="hero-card gdv__hero" :style="{ '--tipo-color': tipoMeta.color }">
        <div class="hero-card__bar"></div>
        <div class="hero-card__body">

          <div class="gdv__hero-row">
            <div class="gdv__hero-info">
              <div class="gdv__badges">
                <span class="gdv__badge" :style="{ background: tipoMeta.color + '22', color: tipoMeta.color, border: '1px solid ' + tipoMeta.color + '44' }">
                  {{ tipoMeta.label }}
                </span>
                <span v-if="gen.registrada_inase" class="gdv__badge gdv__badge--inase">🏛️ INASE</span>
                <span v-if="!gen.activa"     class="gdv__badge gdv__badge--muted">Inactiva</span>
                <span v-if="!gen.disponible" class="gdv__badge gdv__badge--muted">No disponible</span>
              </div>
              <h1 class="gdv__nombre">{{ gen.nombre }}</h1>
              <div v-if="gen.criador || gen.origen" class="gdv__sub">
                <span v-if="gen.criador"><i class="bi bi-person"></i> {{ gen.criador }}</span>
                <span v-if="gen.criador && gen.origen"> · </span>
                <span v-if="gen.origen"><i class="bi bi-geo-alt"></i> {{ gen.origen }}</span>
              </div>
            </div>

            <!-- Acciones header -->
            <div class="gdv__hero-actions">
              <!-- QR dropdown -->
              <div v-if="gen.slug" class="gdv__dropdown" :class="{ 'gdv__dropdown--open': qrDropdownOpen }">
                <button class="gdv__btn gdv__btn--outline-green" @click="qrDropdownOpen = !qrDropdownOpen">
                  <i class="bi bi-qr-code"></i>
                  <span class="gdv__btn-label">QR público</span>
                  <i class="bi bi-chevron-down gdv__dropdown-arrow"></i>
                </button>
                <div class="gdv__dropdown-menu" v-if="qrDropdownOpen" @mouseleave="qrDropdownOpen=false">
                  <button class="gdv__dropdown-item" @click="descargarQRsvg(); qrDropdownOpen=false">
                    <i class="bi bi-file-earmark-code"></i> Descargar SVG
                  </button>
                  <button class="gdv__dropdown-item" @click="descargarQRpng(); qrDropdownOpen=false">
                    <i class="bi bi-file-earmark-image"></i> Descargar PNG
                  </button>
                  <div class="gdv__dropdown-sep"></div>
                  <a :href="`/g/${gen.slug}`" target="_blank" class="gdv__dropdown-item">
                    <i class="bi bi-box-arrow-up-right"></i> Ver ficha pública
                  </a>
                </div>
              </div>

              <!-- Toggle visible_web -->
              <button
                v-if="canUpdate"
                class="gdv__btn"
                :class="gen.visible_web ? 'gdv__btn--green' : 'gdv__btn--ghost'"
                :disabled="toggling"
                @click="toggleVisibleWeb"
              >
                <i class="bi" :class="gen.visible_web ? 'bi-globe2' : 'bi-globe'"></i>
                <span class="gdv__btn-label">{{ gen.visible_web ? 'Publicada' : 'Publicar' }}</span>
              </button>
            </div>
          </div>

          <!-- KPIs rápidos -->
          <div class="kpi-row gdv__kpi-row">
            <div class="kpi-cell">
              <div class="kpi-cell__label">THC</div>
              <div class="kpi-cell__value" style="color:#e53935">{{ gen.thc != null ? gen.thc + '%' : '—' }}</div>
            </div>
            <div class="kpi-cell">
              <div class="kpi-cell__label">CBD</div>
              <div class="kpi-cell__value" style="color:#1b5e20">{{ gen.cbd != null ? gen.cbd + '%' : '—' }}</div>
            </div>
            <div v-if="gen.tiempo_floracion" class="kpi-cell">
              <div class="kpi-cell__label">Floración</div>
              <div class="kpi-cell__value">{{ gen.tiempo_floracion }}d</div>
            </div>
            <div v-if="gen.rendimiento" class="kpi-cell">
              <div class="kpi-cell__label">Rend. est.</div>
              <div class="kpi-cell__value">{{ gen.rendimiento }}g/m²</div>
            </div>
            <div v-if="gen.plantas_count != null" class="kpi-cell">
              <div class="kpi-cell__label">Plantas activas</div>
              <div class="kpi-cell__value">{{ gen.plantas_count }}</div>
            </div>
          </div>

        </div>
      </div>

      <!-- Cuerpo 2 columnas -->
      <div class="gdv__body">

        <!-- Columna izquierda -->
        <div class="gdv__col-main">

          <!-- Descripción -->
          <div v-if="gen.descripcion" class="gdv__card gdv__card--mb">
            <h6 class="section-title">Descripción</h6>
            <p class="gdv__desc">{{ gen.descripcion }}</p>
          </div>

          <!-- Datos de cultivo -->
          <div class="gdv__card gdv__card--mb">
            <h6 class="section-title">Datos de cultivo</h6>
            <div class="dato-grid">
              <div v-if="gen.tiempo_floracion" class="dato-item">
                <span class="dato-item__icon">🌸</span>
                <div><div class="dato-item__label">Floración</div><div class="dato-item__val">{{ gen.tiempo_floracion }} días</div></div>
              </div>
              <div v-if="difMeta" class="dato-item">
                <span class="dato-item__icon">{{ difMeta.icon }}</span>
                <div><div class="dato-item__label">Dificultad</div><div class="dato-item__val">{{ difMeta.label }}</div></div>
              </div>
              <div v-if="gen.rendimiento" class="dato-item">
                <span class="dato-item__icon">⚖️</span>
                <div><div class="dato-item__label">Rendimiento</div><div class="dato-item__val">{{ gen.rendimiento }} g/m²</div></div>
              </div>
              <div v-if="gen.altura" class="dato-item">
                <span class="dato-item__icon">📏</span>
                <div><div class="dato-item__label">Altura</div><div class="dato-item__val">{{ gen.altura }} cm</div></div>
              </div>
              <div v-if="gen.origen" class="dato-item">
                <span class="dato-item__icon">🌍</span>
                <div><div class="dato-item__label">Origen</div><div class="dato-item__val">{{ gen.origen }}</div></div>
              </div>
              <div v-if="gen.criador" class="dato-item">
                <span class="dato-item__icon">👤</span>
                <div><div class="dato-item__label">Criador</div><div class="dato-item__val">{{ gen.criador }}</div></div>
              </div>
            </div>
            <div v-if="!gen.tiempo_floracion && !difMeta && !gen.rendimiento && !gen.altura && !gen.origen && !gen.criador"
                 class="gdv__empty-note">Sin datos de cultivo registrados</div>
          </div>

          <!-- Terpenos -->
          <div v-if="terpenos.length" class="gdv__card gdv__card--mb">
            <h6 class="section-title">Perfil terpénico</h6>
            <div class="gdv__terpenos">
              <span v-for="t in terpenos" :key="t" class="terpeno-chip">{{ t }}</span>
            </div>
          </div>

          <!-- Rendimiento real -->
          <div class="gdv__card gdv__card--mb">
            <h6 class="section-title">📊 Rendimiento real ({{ rendimientoStats.n }} lotes)</h6>
            <div v-if="rendimientoStats.n > 0" class="rend-stats">
              <div class="rend-stat">
                <div class="rend-stat__label">Promedio</div>
                <div class="rend-stat__value rend-stat__value--main">{{ rendimientoStats.avg }}<span class="rend-stat__unit">{{ rendimientoStats.unit }}</span></div>
              </div>
              <div class="rend-stat">
                <div class="rend-stat__label">Máximo</div>
                <div class="rend-stat__value" style="color:#1b5e20">{{ rendimientoStats.max }}<span class="rend-stat__unit">{{ rendimientoStats.unit }}</span></div>
              </div>
              <div class="rend-stat">
                <div class="rend-stat__label">Mínimo</div>
                <div class="rend-stat__value" style="color:#dc2626">{{ rendimientoStats.min }}<span class="rend-stat__unit">{{ rendimientoStats.unit }}</span></div>
              </div>
              <div v-if="gen.rendimiento" class="rend-stat">
                <div class="rend-stat__label">Est. genética</div>
                <div class="rend-stat__value" style="color:#64748b">{{ gen.rendimiento }}<span class="rend-stat__unit">g/m²</span></div>
              </div>
            </div>
            <p v-else class="gdv__empty-note">Sin rendimiento real registrado aún.</p>

            <!-- Sparkline evolución temporal -->
            <div v-if="sparklineData.length >= 2" class="gdv__sparkline-wrap">
              <canvas ref="sparklineCanvas" />
            </div>
          </div>

          <!-- P&L por genética -->
          <div v-if="plResumen && plResumen.lotes_con_datos > 0" class="gdv__card gdv__card--mb">
            <h6 class="section-title">💰 Rentabilidad ({{ plResumen.lotes_con_datos }} lotes)</h6>
            <div class="rend-stats">
              <div class="rend-stat">
                <div class="rend-stat__label">Ingresos prom.</div>
                <div class="rend-stat__value" style="color:#16a34a">
                  {{ plResumen.ingresos_promedio != null ? '$' + Number(plResumen.ingresos_promedio).toLocaleString('es-AR') : '—' }}
                </div>
              </div>
              <div class="rend-stat">
                <div class="rend-stat__label">Costo prom.</div>
                <div class="rend-stat__value" style="color:#64748b">
                  {{ plResumen.costo_promedio != null ? '$' + Number(plResumen.costo_promedio).toLocaleString('es-AR') : '—' }}
                </div>
              </div>
              <div class="rend-stat">
                <div class="rend-stat__label">Margen prom.</div>
                <div class="rend-stat__value" :style="{ color: (plResumen.margen_promedio ?? 0) >= 0 ? '#1b5e20' : '#dc2626' }">
                  {{ plResumen.margen_promedio != null ? '$' + Number(plResumen.margen_promedio).toLocaleString('es-AR') : '—' }}
                  <span v-if="plResumen.margen_pct_promedio != null" class="rend-stat__unit">
                    ({{ plResumen.margen_pct_promedio }}%)
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- Lotes históricos -->
          <div class="gdv__card gdv__card--mb">
            <div class="gdv__card-header">
              <h6 class="section-title gdv__section-mb0">Lotes históricos</h6>
              <span class="gdv__count-badge">{{ lotesTotal }}</span>
            </div>

            <EmptyState v-if="lotesTotal === 0" icon="🌱" title="Sin lotes registrados" compact />

            <div v-else>
              <div class="gdv__table-wrap">
                <table class="gdv__table">
                  <thead>
                    <tr>
                      <th>Código</th>
                      <th class="gdv__col-md">Sala</th>
                      <th class="gdv__col-md">Inicio</th>
                      <th class="gdv__text-right">Plantas</th>
                      <th class="gdv__text-right">Rend. real</th>
                      <th class="gdv__text-right gdv__col-md">Desvío</th>
                      <th class="gdv__text-right gdv__col-md">Ingresos</th>
                      <th class="gdv__text-right gdv__col-md">Margen</th>
                      <th>Estado</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="lote in lotesPaginados" :key="lote.id">
                      <td>
                        <a class="gdv__lote-link" @click.prevent="router.push(`/lotes/${lote.id}`)">
                          {{ lote.codigo }}
                        </a>
                      </td>
                      <td class="gdv__cell-muted gdv__col-md">{{ lote.sala || '—' }}</td>
                      <td class="gdv__cell-muted gdv__col-md">{{ formatDate(lote.start_date) }}</td>
                      <td class="gdv__text-right gdv__cell-sm">{{ lote.plants_count || '—' }}</td>
                      <td class="gdv__text-right gdv__cell-bold">
                        {{ lote.rendimiento_real_g != null ? lote.rendimiento_real_g + ' g' : (lote.peso_seco_total != null ? lote.peso_seco_total + ' g' : '—') }}
                      </td>
                      <td class="gdv__text-right gdv__col-md">
                        <span v-if="lote.desv_pct != null"
                              class="gdv__desv"
                              :class="lote.desv_pct >= 0 ? 'gdv__desv--pos' : 'gdv__desv--neg'">
                          {{ lote.desv_pct >= 0 ? '+' : '' }}{{ lote.desv_pct }}%
                        </span>
                        <span v-else class="gdv__cell-muted">—</span>
                      </td>
                      <td class="gdv__text-right gdv__col-md" style="color:#16a34a;font-size:.8rem">
                        {{ lote.ingresos != null ? '$' + Number(lote.ingresos).toLocaleString('es-AR') : '—' }}
                      </td>
                      <td class="gdv__text-right gdv__col-md">
                        <span v-if="lote.margen != null"
                              :style="{ color: lote.margen >= 0 ? '#16a34a' : '#dc2626', fontSize: '.8rem', fontWeight: '600' }">
                          ${{ Number(lote.margen).toLocaleString('es-AR') }}
                          <small v-if="lote.margen_pct != null" style="opacity:.7">({{ lote.margen_pct }}%)</small>
                        </span>
                        <span v-else class="gdv__cell-muted">—</span>
                      </td>
                      <td>
                        <span class="gdv__estado-badge" :style="estadoLote(lote.estado).style">
                          {{ estadoLote(lote.estado).label }}
                        </span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <Paginator
                v-model:page="lotesPagina"
                v-model:perPage="lotesPerPage"
                :total="lotesTotal"
                :pageSizes="[10, 25]"
              />
            </div>
          </div>

        </div>

        <!-- Columna derecha -->
        <div class="gdv__col-aside">

          <!-- Galería -->
          <div class="gdv__card gdv__card--mb">
            <h6 class="section-title">Fotos</h6>
            <div v-if="gen.fotos?.length" class="foto-grid">
              <div
                v-for="(foto, i) in gen.fotos"
                :key="foto.id"
                class="foto-thumb"
                @click="abrirLightbox(i)"
              >
                <img :src="foto.url" :alt="`${gen.nombre} foto ${i + 1}`" loading="lazy" />
                <button
                  v-if="canUpdate"
                  class="foto-thumb__remove"
                  title="Eliminar foto"
                  @click.stop="eliminarFoto(foto.id)"
                >
                  <i class="bi bi-x-lg"></i>
                </button>
              </div>
            </div>
            <EmptyState v-else icon="📷" title="Sin fotos" compact />
          </div>

          <!-- Cannabinoides -->
          <div class="gdv__card gdv__card--mb">
            <h6 class="section-title">Cannabinoides</h6>
            <div class="cannab-row gdv__cannab-mb">
              <div class="cannab-label" style="color:#e53935;font-weight:700">THC</div>
              <div class="cannab-bar-wrap">
                <div class="cannab-bar" :style="{ width: gen.thc != null ? Math.min(gen.thc, 30) / 30 * 100 + '%' : '0%', background: '#e53935' }"></div>
              </div>
              <div class="cannab-val">{{ gen.thc != null ? gen.thc + '%' : '—' }}</div>
            </div>
            <div class="cannab-row">
              <div class="cannab-label" style="color:#1b5e20;font-weight:700">CBD</div>
              <div class="cannab-bar-wrap">
                <div class="cannab-bar" :style="{ width: gen.cbd != null ? Math.min(gen.cbd, 30) / 30 * 100 + '%' : '0%', background: '#1b5e20' }"></div>
              </div>
              <div class="cannab-val">{{ gen.cbd != null ? gen.cbd + '%' : '—' }}</div>
            </div>
          </div>

          <!-- Configuración (solo admin) -->
          <div v-if="canUpdate" class="gdv__card gdv__card--mb">
            <h6 class="section-title">Configuración</h6>
            <div class="gdv__config">
              <div class="gdv__config-row">
                <span class="gdv__config-label">Estado</span>
                <span class="gdv__config-badge" :style="gen.activa ? { background:'#f0fdf4', color:'#15803d', border:'1px solid #bbf7d0' } : { background:'#f8fafc', color:'#64748b', border:'1px solid #e2e8f0' }">
                  {{ gen.activa ? 'Activa' : 'Inactiva' }}
                </span>
              </div>
              <div class="gdv__config-row">
                <span class="gdv__config-label">Disponible</span>
                <span class="gdv__config-badge" :style="gen.disponible ? { background:'#f0fdf4', color:'#15803d', border:'1px solid #bbf7d0' } : { background:'#f8fafc', color:'#64748b', border:'1px solid #e2e8f0' }">
                  {{ gen.disponible ? 'Sí' : 'No' }}
                </span>
              </div>
              <div class="gdv__config-row">
                <span class="gdv__config-label">Web pública</span>
                <button
                  class="gdv__toggle-sm"
                  :class="gen.visible_web ? 'gdv__toggle-sm--on' : 'gdv__toggle-sm--off'"
                  :disabled="toggling"
                  @click="toggleVisibleWeb"
                >{{ gen.visible_web ? 'Publicada' : 'Oculta' }}</button>
              </div>
              <div class="gdv__config-row">
                <span class="gdv__config-label">Slug QR</span>
                <code class="gdv__config-code">{{ gen.slug || '—' }}</code>
              </div>
              <div class="gdv__config-sep"></div>
              <div class="gdv__config-row gdv__config-row--muted">
                <span>Creada</span><span>{{ formatDate(gen.created_at) }}</span>
              </div>
              <div class="gdv__config-row gdv__config-row--muted">
                <span>Actualizada</span><span>{{ formatDate(gen.updated_at) }}</span>
              </div>
            </div>
          </div>

        </div>
      </div>
    </template>

    <Lightbox
      :images="lightboxImages"
      :index="fotoActiva"
      :open="lightboxOpen"
      @close="lightboxOpen = false"
      @update:index="fotoActiva = $event"
    />

  </div>
</template>

<style scoped>
/* Layout */
.gdv { padding: 2rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .gdv { padding: 1.25rem 1rem 2rem; } }

/* Loading / Error */
.gdv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.gdv__error { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: .875rem 1rem; border-radius: 10px; margin-bottom: 1rem; }

/* Hero */
.gdv__hero { margin-bottom: 1.5rem; }
.gdv__hero-row { display: flex; flex-wrap: wrap; align-items: flex-start; justify-content: space-between; gap: 1rem; }
.gdv__hero-info { flex: 1; }
.gdv__badges    { display: flex; flex-wrap: wrap; align-items: center; gap: .4rem; margin-bottom: .5rem; }
.gdv__badge { display: inline-flex; align-items: center; padding: .2rem .6rem; border-radius: 99px; font-size: .75rem; font-weight: 600; }
.gdv__badge--inase { background: #fef9c3; color: #854d0e; border: 1px solid #fde047; }
.gdv__badge--muted  { background: #f1f5f9; color: #64748b; border: 1px solid #e2e8f0; }
.gdv__nombre { font-size: 1.75rem; font-weight: 800; color: #0f172a; margin: 0 0 .25rem; }
.gdv__sub    { font-size: .82rem; color: #64748b; display: flex; gap: .4rem; flex-wrap: wrap; }
.gdv__sub i  { font-size: .75rem; }

.gdv__hero-actions { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; }
.gdv__btn { display: inline-flex; align-items: center; gap: .4rem; padding: .5rem .9rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; border: 1.5px solid; transition: all .15s; white-space: nowrap; }
.gdv__btn--green   { background: #1a3d2e; border-color: #1a3d2e; color: #fff; }
.gdv__btn--green:hover:not(:disabled) { background: #0f2a1e; }
.gdv__btn--outline-green { background: #fff; border-color: #1a3d2e; color: #1a3d2e; }
.gdv__btn--outline-green:hover { background: #f0f8f4; }
.gdv__btn--ghost   { background: #fff; border-color: #e2e8f0; color: #374151; }
.gdv__btn--ghost:hover:not(:disabled) { background: #f8fafc; }
.gdv__btn:disabled { opacity: .6; cursor: not-allowed; }
.gdv__btn-label    { display: none; }
@media (min-width: 480px) { .gdv__btn-label { display: inline; } }

/* Dropdown */
.gdv__dropdown { position: relative; }
.gdv__dropdown-arrow { font-size: .7rem; }
.gdv__dropdown-menu { position: absolute; right: 0; top: calc(100% + .35rem); background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.1); min-width: 180px; z-index: 100; padding: .3rem; }
.gdv__dropdown-item { display: flex; align-items: center; gap: .5rem; padding: .5rem .75rem; font-size: .82rem; color: #374151; cursor: pointer; border-radius: 7px; text-decoration: none; background: none; border: none; width: 100%; transition: background .1s; }
.gdv__dropdown-item:hover { background: #f8fafc; }
.gdv__dropdown-sep { height: 1px; background: #f1f5f9; margin: .25rem 0; }

.gdv__kpi-row { margin-top: 1rem; }

/* Body 2-col */
.gdv__body { display: grid; grid-template-columns: 1fr 340px; gap: 1.25rem; align-items: start; margin-top: 1.25rem; }
@media (max-width: 900px) { .gdv__body { grid-template-columns: 1fr; } }

/* Cards */
.gdv__card { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; }
.gdv__card--mb { margin-bottom: 1rem; }
.gdv__card-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .875rem; }
.gdv__section-mb0 { margin-bottom: 0; }
.gdv__count-badge { background: #f1f5f9; color: #64748b; padding: .15rem .55rem; border-radius: 99px; font-size: .75rem; font-weight: 600; }
.gdv__desc { color: #475569; line-height: 1.65; margin: 0; font-size: .9rem; }
.gdv__empty-note { color: #94a3b8; font-size: .82rem; font-style: italic; }
.gdv__terpenos { display: flex; flex-wrap: wrap; gap: .4rem; }
.gdv__cannab-mb { margin-bottom: .75rem; }

/* Hero */
.hero-card { background: white; border-radius: 14px; border: 1.5px solid rgba(0,0,0,.07); overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,.06); }
.hero-card__bar { height: 5px; background: var(--tipo-color, #1b5e20); }
.hero-card__body { padding: 1.25rem 1.5rem 1.5rem; }

/* KPI row */
.kpi-row { display: flex; flex-wrap: wrap; gap: .75rem; }
.kpi-cell { background: #f8f9fa; border-radius: .75rem; padding: .5rem .875rem; min-width: 70px; }
.kpi-cell__label { font-size: .65rem; text-transform: uppercase; letter-spacing: .06em; color: #6c757d; margin-bottom: .1rem; }
.kpi-cell__value { font-size: 1.15rem; font-weight: 800; color: #1a2e1a; line-height: 1; }

/* Section titles */
.section-title { font-size: .68rem; text-transform: uppercase; letter-spacing: .08em; color: #6c757d; font-weight: 700; margin-bottom: .875rem; }

/* Dato grid */
.dato-grid { display: flex; flex-wrap: wrap; gap: .6rem; }
.dato-item { display: flex; align-items: center; gap: .65rem; background: #f8f9fa; border-radius: .6rem; padding: .6rem .875rem; flex: 1 1 140px; }
.dato-item__icon  { font-size: 1.25rem; flex-shrink: 0; }
.dato-item__label { font-size: .65rem; text-transform: uppercase; letter-spacing: .06em; color: #6c757d; line-height: 1.2; }
.dato-item__val   { font-size: .875rem; font-weight: 600; color: #1a2e1a; }

/* Terpenos */
.terpeno-chip { padding: .3rem .75rem; background: rgba(27,94,32,.1); color: #1b5e20; border-radius: 999px; font-size: .8rem; font-weight: 600; border: 1px solid rgba(27,94,32,.2); }

/* Table */
.gdv__table-wrap { overflow-x: auto; margin-bottom: .75rem; }
.gdv__table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.gdv__table thead th { padding: .5rem .75rem; text-align: left; font-size: .65rem; text-transform: uppercase; letter-spacing: .06em; color: #6c757d; font-weight: 600; border-bottom: 2px solid #e5e7eb; white-space: nowrap; }
.gdv__table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; }
.gdv__table tbody tr:last-child { border-bottom: none; }
.gdv__table tbody tr:hover { background: #f8fafc; }
.gdv__table td { padding: .55rem .75rem; vertical-align: middle; }
.gdv__col-md { display: none; }
@media (min-width: 640px) { .gdv__col-md { display: table-cell; } }
.gdv__text-right { text-align: right; }
.gdv__lote-link { font-weight: 600; color: #1e293b; text-decoration: none; cursor: pointer; }
.gdv__lote-link:hover { color: #1b5e20; text-decoration: underline; }
.gdv__cell-muted { color: #6b7280; font-size: .78rem; }
.gdv__cell-sm    { font-size: .78rem; }
.gdv__cell-bold  { font-weight: 600; font-size: .78rem; }
.gdv__estado-badge { display: inline-block; padding: .15rem .5rem; border-radius: 99px; font-size: .7rem; font-weight: 600; }

/* Cannabinoides */
.cannab-row { display: flex; align-items: center; gap: .75rem; }
.cannab-label { font-size: .8rem; width: 36px; }
.cannab-bar-wrap { flex: 1; height: 8px; background: rgba(0,0,0,.07); border-radius: 4px; overflow: hidden; }
.cannab-bar { height: 100%; border-radius: 4px; transition: width .4s ease; }
.cannab-val { font-size: .85rem; font-weight: 700; color: #1a2e1a; width: 42px; text-align: right; }

/* Foto grid */
.foto-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem; }
.foto-thumb { aspect-ratio: 1; border-radius: .5rem; overflow: hidden; cursor: pointer; position: relative; background: #f0f0f0; }
.foto-thumb img { width: 100%; height: 100%; object-fit: cover; transition: transform .2s; }
.foto-thumb:hover img { transform: scale(1.05); }
.foto-thumb__remove { position: absolute; top: 4px; right: 4px; background: rgba(0,0,0,.6); border: none; border-radius: 50%; color: white; width: 22px; height: 22px; font-size: .65rem; display: flex; align-items: center; justify-content: center; opacity: 0; transition: opacity .15s; cursor: pointer; }
.foto-thumb:hover .foto-thumb__remove { opacity: 1; }

/* Rendimiento real */
.rend-stats { display: grid; grid-template-columns: repeat(auto-fill, minmax(110px, 1fr)); gap: .75rem; margin-top: .5rem; }
.rend-stat { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .75rem; text-align: center; }
.rend-stat__label { font-size: .68rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .3rem; }
.rend-stat__value { font-size: 1.4rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; line-height: 1; }
.rend-stat__value--main { color: #1b5e20; }
.rend-stat__unit { font-size: .62rem; font-weight: 500; color: #94a3b8; margin-left: .15rem; }

/* Configuración card */
.gdv__config { display: flex; flex-direction: column; gap: .5rem; font-size: .82rem; }
.gdv__config-row { display: flex; justify-content: space-between; align-items: center; }
.gdv__config-row--muted { color: #64748b; }
.gdv__config-label { color: #64748b; }
.gdv__config-badge { display: inline-block; padding: .15rem .55rem; border-radius: 99px; font-size: .75rem; font-weight: 600; }
.gdv__config-code  { font-size: .75rem; color: #94a3b8; font-family: monospace; }
.gdv__config-sep   { height: 1px; background: #f1f5f9; margin: .25rem 0; }
.gdv__toggle-sm { font-size: .72rem; font-weight: 600; padding: .2em .65em; border-radius: 6px; border: 1.5px solid; cursor: pointer; transition: all .15s; }
.gdv__toggle-sm--on  { background: #f0fdf4; color: #15803d; border-color: #bbf7d0; }
.gdv__toggle-sm--off { background: #f8fafc; color: #94a3b8; border-color: #e2e8f0; }
.gdv__toggle-sm:disabled { opacity: .6; cursor: not-allowed; }

/* Sparkline */
.gdv__sparkline-wrap { height: 120px; margin-top: 1rem; border-top: 1px solid #f1f5f9; padding-top: .75rem; }

/* Desvío en tabla */
.gdv__desv { font-size: .76rem; font-weight: 700; }
.gdv__desv--pos { color: #15803d; }
.gdv__desv--neg { color: #dc2626; }
</style>
