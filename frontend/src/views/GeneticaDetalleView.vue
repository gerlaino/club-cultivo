<script setup>
import { ref, computed, onMounted } from 'vue'
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

const props = defineProps({ id: { type: Number, required: true } })

const router  = useRouter()
const auth    = useAuthStore()
const { can } = usePermissions()
const { downloadPNG, downloadSVG } = useQRCode()
const toast   = useToast()
const { confirm } = useConfirm()

const canUpdate = computed(() => can('geneticas', 'update'))

const gen      = ref(null)
const loading  = ref(true)
const error    = ref(null)
const toggling = ref(false)

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

// Rendimiento promedio calculado desde lotes históricos
const rendimientoStats = computed(() => {
  const lotes = (gen.value?.lotes_historicos || []).filter(l => l.rendimiento_gramos_planta != null && l.rendimiento_gramos_planta > 0)
  if (!lotes.length) return { avg: null, max: null, min: null, n: 0 }
  const vals = lotes.map(l => Number(l.rendimiento_gramos_planta))
  const avg  = vals.reduce((a, b) => a + b, 0) / vals.length
  const max  = Math.max(...vals)
  const min  = Math.min(...vals)
  return { avg: avg.toFixed(1), max: max.toFixed(1), min: min.toFixed(1), n: lotes.length }
})

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
    activo: { label: 'Activo', cls: 'bg-success' },
    cosechado: { label: 'Cosechado', cls: 'bg-secondary' },
    cancelado: { label: 'Cancelado', cls: 'bg-danger' },
  }
  return MAP[estado] || { label: estado, cls: 'bg-secondary' }
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
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>

    <!-- Contenido -->
    <template v-else-if="gen">

      <Breadcrumb :items="[{ label: 'Genéticas', to: { name: 'geneticas' } }, { label: gen.nombre }]" />

      <!-- Hero card -->
      <div class="hero-card mb-4" :style="{ '--tipo-color': tipoMeta.color }">
        <div class="hero-card__bar"></div>
        <div class="hero-card__body">

          <div class="d-flex flex-wrap align-items-start justify-content-between gap-3">
            <div>
              <div class="d-flex flex-wrap align-items-center gap-2 mb-1">
                <span class="badge rounded-pill fw-semibold" :style="{ background: tipoMeta.color + '22', color: tipoMeta.color, border: '1px solid ' + tipoMeta.color + '44' }">
                  {{ tipoMeta.label }}
                </span>
                <span v-if="gen.registrada_inase" class="badge bg-warning text-dark">🏛️ INASE</span>
                <span v-if="!gen.activa" class="badge bg-secondary">Inactiva</span>
                <span v-if="!gen.disponible" class="badge bg-secondary">No disponible</span>
              </div>
              <h1 class="h2 fw-bold mb-1">{{ gen.nombre }}</h1>
              <div v-if="gen.criador || gen.origen" class="text-muted small">
                <span v-if="gen.criador"><i class="bi bi-person me-1"></i>{{ gen.criador }}</span>
                <span v-if="gen.criador && gen.origen"> · </span>
                <span v-if="gen.origen"><i class="bi bi-geo-alt me-1"></i>{{ gen.origen }}</span>
              </div>
            </div>

            <!-- Acciones header -->
            <div class="d-flex flex-wrap gap-2">
              <!-- QR público dropdown -->
              <div v-if="gen.slug" class="dropdown">
                <button
                  class="btn btn-outline-success dropdown-toggle"
                  data-bs-toggle="dropdown"
                  title="QR público"
                >
                  <i class="bi bi-qr-code me-1"></i>
                  <span class="d-none d-sm-inline">QR público</span>
                </button>
                <ul class="dropdown-menu dropdown-menu-end shadow-sm border-0">
                  <li>
                    <button class="dropdown-item small py-2 d-flex align-items-center gap-2" @click="descargarQRsvg">
                      <i class="bi bi-file-earmark-code text-muted"></i> Descargar SVG
                    </button>
                  </li>
                  <li>
                    <button class="dropdown-item small py-2 d-flex align-items-center gap-2" @click="descargarQRpng">
                      <i class="bi bi-file-earmark-image text-muted"></i> Descargar PNG
                    </button>
                  </li>
                  <li><hr class="dropdown-divider my-1"></li>
                  <li>
                    <a :href="`/g/${gen.slug}`" target="_blank" class="dropdown-item small py-2 d-flex align-items-center gap-2">
                      <i class="bi bi-box-arrow-up-right text-muted"></i> Ver ficha pública
                    </a>
                  </li>
                </ul>
              </div>

              <!-- Toggle visible_web -->
              <button
                v-if="canUpdate"
                class="btn"
                :class="gen.visible_web ? 'btn-success' : 'btn-outline-secondary'"
                :disabled="toggling"
                @click="toggleVisibleWeb"
                :title="gen.visible_web ? 'Publicada en web del club' : 'No visible en web del club'"
              >
                <i class="bi" :class="gen.visible_web ? 'bi-globe2' : 'bi-globe'"></i>
                <span class="d-none d-sm-inline ms-1">{{ gen.visible_web ? 'Publicada' : 'Publicar' }}</span>
              </button>
            </div>
          </div>

          <!-- KPIs rápidos -->
          <div class="kpi-row mt-3">
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

      <!-- Cuerpo: 2 columnas en desktop -->
      <div class="row g-4">

        <!-- Columna izquierda -->
        <div class="col-12 col-lg-7">

          <!-- Descripción -->
          <div v-if="gen.descripcion" class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <h6 class="section-title">Descripción</h6>
              <p class="mb-0 text-secondary lh-lg">{{ gen.descripcion }}</p>
            </div>
          </div>

          <!-- Datos de cultivo -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <h6 class="section-title">Datos de cultivo</h6>
              <div class="dato-grid">
                <div v-if="gen.tiempo_floracion" class="dato-item">
                  <span class="dato-item__icon">🌸</span>
                  <div>
                    <div class="dato-item__label">Floración</div>
                    <div class="dato-item__val">{{ gen.tiempo_floracion }} días</div>
                  </div>
                </div>
                <div v-if="difMeta" class="dato-item">
                  <span class="dato-item__icon">{{ difMeta.icon }}</span>
                  <div>
                    <div class="dato-item__label">Dificultad</div>
                    <div class="dato-item__val">{{ difMeta.label }}</div>
                  </div>
                </div>
                <div v-if="gen.rendimiento" class="dato-item">
                  <span class="dato-item__icon">⚖️</span>
                  <div>
                    <div class="dato-item__label">Rendimiento</div>
                    <div class="dato-item__val">{{ gen.rendimiento }} g/m²</div>
                  </div>
                </div>
                <div v-if="gen.altura" class="dato-item">
                  <span class="dato-item__icon">📏</span>
                  <div>
                    <div class="dato-item__label">Altura</div>
                    <div class="dato-item__val">{{ gen.altura }} cm</div>
                  </div>
                </div>
                <div v-if="gen.origen" class="dato-item">
                  <span class="dato-item__icon">🌍</span>
                  <div>
                    <div class="dato-item__label">Origen</div>
                    <div class="dato-item__val">{{ gen.origen }}</div>
                  </div>
                </div>
                <div v-if="gen.criador" class="dato-item">
                  <span class="dato-item__icon">👤</span>
                  <div>
                    <div class="dato-item__label">Criador</div>
                    <div class="dato-item__val">{{ gen.criador }}</div>
                  </div>
                </div>
              </div>
              <div v-if="!gen.tiempo_floracion && !difMeta && !gen.rendimiento && !gen.altura && !gen.origen && !gen.criador"
                   class="text-muted small fst-italic">Sin datos de cultivo registrados</div>
            </div>
          </div>

          <!-- Terpenos -->
          <div v-if="terpenos.length" class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <h6 class="section-title">Perfil terpénico</h6>
              <div class="d-flex flex-wrap gap-2">
                <span v-for="t in terpenos" :key="t" class="terpeno-chip">{{ t }}</span>
              </div>
            </div>
          </div>

          <!-- Rendimiento promedio -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <h6 class="section-title">📊 Rendimiento real ({{ rendimientoStats.n }} lotes)</h6>
              <div v-if="rendimientoStats.n > 0" class="rend-stats">
                <div class="rend-stat">
                  <div class="rend-stat__label">Promedio</div>
                  <div class="rend-stat__value rend-stat__value--main">{{ rendimientoStats.avg }}<span class="rend-stat__unit">g/planta</span></div>
                </div>
                <div class="rend-stat">
                  <div class="rend-stat__label">Máximo</div>
                  <div class="rend-stat__value" style="color:#1b5e20">{{ rendimientoStats.max }}<span class="rend-stat__unit">g/planta</span></div>
                </div>
                <div class="rend-stat">
                  <div class="rend-stat__label">Mínimo</div>
                  <div class="rend-stat__value" style="color:#dc2626">{{ rendimientoStats.min }}<span class="rend-stat__unit">g/planta</span></div>
                </div>
                <div v-if="gen.rendimiento" class="rend-stat">
                  <div class="rend-stat__label">Est. genética</div>
                  <div class="rend-stat__value" style="color:#64748b">{{ gen.rendimiento }}<span class="rend-stat__unit">g/m²</span></div>
                </div>
              </div>
              <p v-else class="text-muted small mb-0">Marcá plantas con ⭐ para acumular datos de rendimiento real.</p>
            </div>
          </div>

          <!-- Lotes históricos -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <div class="d-flex align-items-center justify-content-between mb-3">
                <h6 class="section-title mb-0">Lotes históricos</h6>
                <span class="badge text-bg-light text-muted fw-normal">{{ lotesTotal }}</span>
              </div>

              <EmptyState v-if="lotesTotal === 0" icon="🌱" title="Sin lotes registrados" compact />

              <div v-else>
                <div class="table-responsive">
                  <table class="table table-sm table-hover align-middle mb-2">
                    <thead>
                      <tr class="table-header">
                        <th>Código</th>
                        <th>Sala</th>
                        <th class="d-none d-md-table-cell">Inicio</th>
                        <th class="d-none d-md-table-cell">Cosecha</th>
                        <th class="text-end">Plantas</th>
                        <th class="text-end">Peso seco</th>
                        <th class="text-end d-none d-md-table-cell">g/planta</th>
                        <th>Estado</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr v-for="lote in lotesPaginados" :key="lote.id">
                        <td>
                          <a :href="`/lotes/${lote.id}`" class="fw-semibold text-decoration-none text-dark link-hover" @click.prevent="router.push(`/lotes/${lote.id}`)">
                            {{ lote.codigo }}
                          </a>
                        </td>
                        <td class="text-muted small">{{ lote.sala || '—' }}</td>
                        <td class="text-muted small d-none d-md-table-cell">{{ formatDate(lote.start_date) }}</td>
                        <td class="text-muted small d-none d-md-table-cell">{{ formatDate(lote.fecha_cosecha) }}</td>
                        <td class="text-end small">{{ lote.plants_count || '—' }}</td>
                        <td class="text-end small fw-semibold">
                          {{ lote.peso_seco_total != null ? lote.peso_seco_total + 'g' : '—' }}
                        </td>
                        <td class="text-end small text-muted d-none d-md-table-cell">
                          {{ lote.rendimiento_gramos_planta != null ? lote.rendimiento_gramos_planta + 'g' : '—' }}
                        </td>
                        <td>
                          <span class="badge rounded-pill" :class="estadoLote(lote.estado).cls" style="font-size:.7rem">
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

        </div>

        <!-- Columna derecha -->
        <div class="col-12 col-lg-5">

          <!-- Galería de fotos -->
          <div v-if="gen.fotos?.length" class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <h6 class="section-title">Fotos</h6>
              <div class="foto-grid">
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
            </div>
          </div>
          <div v-else class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <EmptyState icon="📷" title="Sin fotos" compact />
            </div>
          </div>

          <!-- THC / CBD visual -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <h6 class="section-title">Cannabinoides</h6>
              <div class="cannab-row mb-3">
                <div class="cannab-label fw-bold" style="color:#e53935">THC</div>
                <div class="cannab-bar-wrap">
                  <div class="cannab-bar" :style="{ width: gen.thc != null ? Math.min(gen.thc, 30) / 30 * 100 + '%' : '0%', background: '#e53935' }"></div>
                </div>
                <div class="cannab-val">{{ gen.thc != null ? gen.thc + '%' : '—' }}</div>
              </div>
              <div class="cannab-row">
                <div class="cannab-label fw-bold" style="color:#1b5e20">CBD</div>
                <div class="cannab-bar-wrap">
                  <div class="cannab-bar" :style="{ width: gen.cbd != null ? Math.min(gen.cbd, 30) / 30 * 100 + '%' : '0%', background: '#1b5e20' }"></div>
                </div>
                <div class="cannab-val">{{ gen.cbd != null ? gen.cbd + '%' : '—' }}</div>
              </div>
            </div>
          </div>

          <!-- Info técnica (solo admin) -->
          <div v-if="canUpdate" class="card border-0 shadow-sm mb-4">
            <div class="card-body">
              <h6 class="section-title">Configuración</h6>
              <div class="d-flex flex-column gap-2 small">
                <div class="d-flex justify-content-between align-items-center">
                  <span class="text-muted">Estado</span>
                  <span class="badge" :class="gen.activa ? 'bg-success' : 'bg-secondary'">
                    {{ gen.activa ? 'Activa' : 'Inactiva' }}
                  </span>
                </div>
                <div class="d-flex justify-content-between align-items-center">
                  <span class="text-muted">Disponible</span>
                  <span class="badge" :class="gen.disponible ? 'bg-success' : 'bg-secondary'">
                    {{ gen.disponible ? 'Sí' : 'No' }}
                  </span>
                </div>
                <div class="d-flex justify-content-between align-items-center">
                  <span class="text-muted">Web pública</span>
                  <button
                    class="btn btn-sm py-0 px-2"
                    :class="gen.visible_web ? 'btn-success' : 'btn-outline-secondary'"
                    :disabled="toggling"
                    @click="toggleVisibleWeb"
                  >
                    {{ gen.visible_web ? 'Publicada' : 'Oculta' }}
                  </button>
                </div>
                <div class="d-flex justify-content-between align-items-center">
                  <span class="text-muted">Slug QR</span>
                  <code class="small text-muted">{{ gen.slug || '—' }}</code>
                </div>
                <hr class="my-1">
                <div class="d-flex justify-content-between text-muted">
                  <span>Creada</span><span>{{ formatDate(gen.created_at) }}</span>
                </div>
                <div class="d-flex justify-content-between text-muted">
                  <span>Actualizada</span><span>{{ formatDate(gen.updated_at) }}</span>
                </div>
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
/* Hero */
.hero-card {
  background: white;
  border-radius: 14px;
  border: 1.5px solid rgba(0,0,0,.07);
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(0,0,0,.06);
}
.hero-card__bar { height: 5px; background: var(--tipo-color, #1b5e20); }
.hero-card__body { padding: 1.25rem 1.5rem 1.5rem; }

/* KPI row */
.kpi-row { display: flex; flex-wrap: wrap; gap: .75rem; }
.kpi-cell {
  background: #f8f9fa;
  border-radius: .75rem;
  padding: .5rem .875rem;
  min-width: 70px;
}
.kpi-cell__label { font-size: .65rem; text-transform: uppercase; letter-spacing: .06em; color: #6c757d; margin-bottom: .1rem; }
.kpi-cell__value { font-size: 1.15rem; font-weight: 800; color: #1a2e1a; line-height: 1; }

/* Section titles */
.section-title {
  font-size: .68rem;
  text-transform: uppercase;
  letter-spacing: .08em;
  color: #6c757d;
  font-weight: 700;
  margin-bottom: .875rem;
}

/* Dato grid */
.dato-grid { display: flex; flex-wrap: wrap; gap: .6rem; }
.dato-item {
  display: flex; align-items: center; gap: .65rem;
  background: #f8f9fa; border-radius: .6rem; padding: .6rem .875rem;
  flex: 1 1 140px;
}
.dato-item__icon { font-size: 1.25rem; flex-shrink: 0; }
.dato-item__label { font-size: .65rem; text-transform: uppercase; letter-spacing: .06em; color: #6c757d; line-height: 1.2; }
.dato-item__val { font-size: .875rem; font-weight: 600; color: #1a2e1a; }

/* Terpenos */
.terpeno-chip {
  padding: .3rem .75rem;
  background: rgba(27,94,32,.1);
  color: #1b5e20;
  border-radius: 999px;
  font-size: .8rem;
  font-weight: 600;
  border: 1px solid rgba(27,94,32,.2);
}

/* Tabla lotes */
.table-header th {
  font-size: .68rem;
  text-transform: uppercase;
  letter-spacing: .06em;
  color: #6c757d;
  font-weight: 600;
  border-bottom-width: 1px;
}
.link-hover:hover { color: #1b5e20 !important; text-decoration: underline !important; }

/* Cannabinoides */
.cannab-row { display: flex; align-items: center; gap: .75rem; }
.cannab-label { font-size: .8rem; width: 36px; }
.cannab-bar-wrap { flex: 1; height: 8px; background: rgba(0,0,0,.07); border-radius: 4px; overflow: hidden; }
.cannab-bar { height: 100%; border-radius: 4px; transition: width .4s ease; }
.cannab-val { font-size: .85rem; font-weight: 700; color: #1a2e1a; width: 42px; text-align: right; }

/* Foto grid */
.foto-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem; }
.foto-thumb {
  aspect-ratio: 1;
  border-radius: .5rem;
  overflow: hidden;
  cursor: pointer;
  position: relative;
  background: #f0f0f0;
}
.foto-thumb img { width: 100%; height: 100%; object-fit: cover; transition: transform .2s; }
.foto-thumb:hover img { transform: scale(1.05); }
.foto-thumb__remove {
  position: absolute; top: 4px; right: 4px;
  background: rgba(0,0,0,.6); border: none; border-radius: 50%;
  color: white; width: 22px; height: 22px; font-size: .65rem;
  display: flex; align-items: center; justify-content: center;
  opacity: 0; transition: opacity .15s; cursor: pointer;
}
.foto-thumb:hover .foto-thumb__remove { opacity: 1; }

/* Rendimiento real */
.rend-stats { display: grid; grid-template-columns: repeat(auto-fill, minmax(110px, 1fr)); gap: .75rem; margin-top: .5rem; }
.rend-stat { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .75rem; text-align: center; }
.rend-stat__label { font-size: .68rem; font-weight: 700; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; margin-bottom: .3rem; }
.rend-stat__value { font-size: 1.4rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; line-height: 1; }
.rend-stat__value--main { color: #1b5e20; }
.rend-stat__unit { font-size: .62rem; font-weight: 500; color: #94a3b8; margin-left: .15rem; }
</style>
