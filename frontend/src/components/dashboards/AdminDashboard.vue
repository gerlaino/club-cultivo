<script setup>
import { ref, computed, onMounted } from 'vue'
import api, { listSedes } from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'
import OnboardingWizard from '../OnboardingWizard.vue'
import PlantDistributionChart from '../charts/PlantDistributionChart.vue'
import PlantsByGeneticaChart from '../charts/PlantsByGeneticaChart.vue'

const auth    = useAuthStore()
const stats   = ref({})
const sedes   = ref([])
const loading = ref(true)
const sedeAbierta = ref(null)
const mostrarOnboarding = ref(false)

const plantasPorGenetica = computed(() => stats.value.plantas_por_genetica || [])

const hora   = new Date().getHours()
const saludo = hora < 12 ? 'Buenos días' : hora < 19 ? 'Buenas tardes' : 'Buenas noches'
const hoy    = new Date().toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })

const TIPO_META = {
  produccion: { label: 'Producción',           icon: '🌱', color: '#198754' },
  social:     { label: 'Social / Dispensario', icon: '🏪', color: '#0d6efd' },
  mixta:      { label: 'Mixta',                icon: '🔄', color: '#6f42c1' },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion }
function toggleSede(sede) {
  sedeAbierta.value = sedeAbierta.value === sede.id ? null : sede.id
}

async function cargar() {
  loading.value = true
  try {
    const [statsRes, sedesRes] = await Promise.allSettled([
      api.get('/stats'),
      listSedes(),
    ])
    if (statsRes.status === 'fulfilled') stats.value = statsRes.value.data
    if (sedesRes.status === 'fulfilled') {
      sedes.value = sedesRes.value.data || []
      if (!sedes.value.length) mostrarOnboarding.value = true
    }
  } finally {
    loading.value = false
  }
}

async function onOnboardingCompletado() {
  mostrarOnboarding.value = false
  await cargar()
}

onMounted(cargar)
</script>

<template>
  <div>
    <OnboardingWizard v-if="mostrarOnboarding" @completado="onOnboardingCompletado" />

    <div class="container-fluid py-4 px-3 px-md-4">

      <div class="d-flex flex-wrap align-items-center justify-content-between gap-2 mb-4">
        <div>
          <h1 class="h3 fw-bold mb-0">{{ saludo }}, {{ auth.displayName }}</h1>
          <p class="text-muted small mb-0 text-capitalize">{{ hoy }}</p>
        </div>
        <RouterLink to="/preferencias" class="btn btn-sm btn-outline-secondary">
          <i class="bi bi-gear me-1"></i>Preferencias
        </RouterLink>
      </div>

      <div v-if="loading" class="text-center py-5">
        <div class="spinner-border text-success"></div>
      </div>

      <template v-else>

        <div class="row g-3 mb-4">
          <div class="col-6 col-md-3">
            <div class="kpi card border-0 h-100"><div class="card-body">
              <div class="kpi-icon mb-2" style="background:rgba(27,94,32,.12)">🌱</div>
              <div class="kpi-value">{{ stats.vegetativo || 0 }}</div>
              <div class="kpi-label">Vegetativo</div>
            </div></div>
          </div>
          <div class="col-6 col-md-3">
            <div class="kpi card border-0 h-100"><div class="card-body">
              <div class="kpi-icon mb-2" style="background:rgba(255,193,7,.15)">🌸</div>
              <div class="kpi-value">{{ stats.floracion || 0 }}</div>
              <div class="kpi-label">Floración</div>
            </div></div>
          </div>
          <div class="col-6 col-md-3">
            <div class="kpi card border-0 h-100"><div class="card-body">
              <div class="kpi-icon mb-2" style="background:rgba(13,110,253,.1)">👥</div>
              <div class="kpi-value">{{ stats.socios || 0 }}</div>
              <div class="kpi-label">Pacientes</div>
            </div></div>
          </div>
          <div class="col-6 col-md-3">
            <div class="kpi card border-0 h-100"><div class="card-body">
              <div class="kpi-icon mb-2" style="background:rgba(108,117,125,.1)">📦</div>
              <div class="kpi-value">{{ stats.lotes || 0 }}</div>
              <div class="kpi-label">Lotes activos</div>
            </div></div>
          </div>
        </div>

        <div class="mb-3 d-flex align-items-center justify-content-between">
          <p class="fw-semibold text-muted small text-uppercase mb-0" style="letter-spacing:.05em">
            Sedes ({{ sedes.length }})
          </p>
          <RouterLink to="/sedes" class="btn btn-sm btn-outline-secondary">
            <i class="bi bi-plus-circle me-1"></i>Gestionar sedes
          </RouterLink>
        </div>

        <div v-if="!sedes.length" class="card border-0 shadow-sm mb-4">
          <div class="card-body text-center py-5">
            <div class="fs-1 mb-3">🏢</div>
            <h5>No hay sedes configuradas</h5>
            <p class="text-muted small mb-3">Creá tu primera sede para empezar</p>
            <button class="btn btn-success" @click="mostrarOnboarding = true">
              <i class="bi bi-plus-circle me-1"></i>Crear primera sede
            </button>
          </div>
        </div>

        <div v-else class="row g-3 mb-4">
          <div v-for="sede in sedes" :key="sede.id" class="col-12 col-md-6 col-xl-4">
            <div class="sede-dash-card" :style="{ '--tipo-color': tipoMeta(sede.tipo).color }"
                 @click="toggleSede(sede)">
              <div class="sede-dash-card__bar"></div>
              <div class="sede-dash-card__body">
                <div class="d-flex align-items-start justify-content-between gap-2 mb-2">
                  <div>
                    <div class="d-flex align-items-center gap-2">
                      <span class="fs-5">{{ tipoMeta(sede.tipo).icon }}</span>
                      <h6 class="fw-bold mb-0">{{ sede.nombre }}</h6>
                    </div>
                    <span class="small fw-semibold" :style="{ color: tipoMeta(sede.tipo).color }">
                      {{ tipoMeta(sede.tipo).label }}
                    </span>
                  </div>
                  <div class="d-flex flex-column align-items-end gap-1">
                    <span v-if="sede.declarada_reprocann" class="badge text-bg-success" style="font-size:.65rem">
                      ✓ REPROCANN
                    </span>
                    <i class="bi small text-muted"
                       :class="sedeAbierta === sede.id ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
                  </div>
                </div>
                <div class="d-flex gap-3 small text-muted">
                  <span><i class="bi bi-building me-1"></i>{{ sede.salas_count }} salas</span>
                  <span v-if="sede.ciudad" class="text-truncate">
                    <i class="bi bi-geo-alt me-1"></i>{{ sede.ciudad }}
                  </span>
                </div>
              </div>
            </div>

            <div v-if="sedeAbierta === sede.id" class="sede-panel mt-2">
              <template v-if="['produccion','mixta'].includes(sede.tipo)">
                <div class="sede-panel__titulo">🌱 Producción</div>
                <div class="row g-2 mb-2">
                  <div class="col-4">
                    <div class="mini-kpi">
                      <div class="mini-kpi__valor">{{ sede.salas_count }}</div>
                      <div class="mini-kpi__label">Salas</div>
                    </div>
                  </div>
                  <div class="col-4">
                    <div class="mini-kpi">
                      <div class="mini-kpi__valor">{{ stats.lotes || 0 }}</div>
                      <div class="mini-kpi__label">Lotes</div>
                    </div>
                  </div>
                  <div class="col-4">
                    <div class="mini-kpi">
                      <div class="mini-kpi__valor">{{ stats.plantas || 0 }}</div>
                      <div class="mini-kpi__label">Plantas</div>
                    </div>
                  </div>
                </div>
                <RouterLink to="/salas" class="btn btn-sm btn-outline-success w-100 mb-2">
                  <i class="bi bi-building me-1"></i>Ver salas
                </RouterLink>
              </template>
              <template v-if="['social','mixta'].includes(sede.tipo)">
                <div class="sede-panel__titulo">🏪 Dispensario</div>
                <div class="row g-2 mb-2">
                  <div class="col-6">
                    <div class="mini-kpi">
                      <div class="mini-kpi__valor">{{ stats.socios || 0 }}</div>
                      <div class="mini-kpi__label">Pacientes</div>
                    </div>
                  </div>
                  <div class="col-6">
                    <div class="mini-kpi">
                      <div class="mini-kpi__valor text-warning">{{ stats.vencimientos || 0 }}</div>
                      <div class="mini-kpi__label">Por vencer</div>
                    </div>
                  </div>
                </div>
                <RouterLink to="/socios" class="btn btn-sm btn-outline-primary w-100 mb-2">
                  <i class="bi bi-people me-1"></i>Ver pacientes
                </RouterLink>
              </template>
            </div>
          </div>
        </div>

        <div v-if="sedes.length" class="row g-3 mb-4">
          <div class="col-12 col-lg-6">
            <div class="card border-0 shadow-sm h-100">
              <div class="card-header bg-transparent border-0 pt-3 pb-0"><strong>Distribución de plantas</strong></div>
              <div class="card-body"><PlantDistributionChart :data="stats" /></div>
            </div>
          </div>
          <div class="col-12 col-lg-6">
            <div class="card border-0 shadow-sm h-100">
              <div class="card-header bg-transparent border-0 pt-3 pb-0"><strong>Plantas por genética</strong></div>
              <div class="card-body">
                <div v-if="!plantasPorGenetica.length" class="text-center py-4 text-muted">
                  <div class="fs-2 mb-2">🌿</div>
                  <div class="small">Sin datos de genéticas aún</div>
                </div>
                <PlantsByGeneticaChart v-else :data="plantasPorGenetica" />
              </div>
            </div>
          </div>
        </div>

        <div v-if="sedes.length && stats.vencimientos > 0" class="alert alert-warning d-flex align-items-center gap-2">
          <i class="bi bi-exclamation-triangle-fill"></i>
          <div>
            <strong>{{ stats.vencimientos }} paciente{{ stats.vencimientos !== 1 ? 's' : '' }}</strong>
            con Reprocann venciendo en los próximos 30 días.
            <RouterLink to="/socios" class="ms-1 alert-link">Ver pacientes →</RouterLink>
          </div>
        </div>

      </template>
    </div>
  </div>
</template>

<style scoped>
.kpi .card-body { padding: 1.25rem 1.5rem; }
.kpi-icon { width:44px; height:44px; border-radius:12px; display:flex; align-items:center; justify-content:center; font-size:1.4rem; }
.kpi-value { font-size:2rem; font-weight:700; line-height:1; color:#1f2937; }
.kpi-label { font-size:.85rem; color:#6b7280; margin-top:.2rem; }
.sede-dash-card { background:white; border-radius:12px; border:1.5px solid rgba(0,0,0,.06); overflow:hidden; cursor:pointer; transition:all .15s; }
.sede-dash-card:hover { transform:translateY(-2px); box-shadow:0 6px 20px rgba(0,0,0,.08); border-color:var(--tipo-color); }
.sede-dash-card__bar  { height:4px; background:var(--tipo-color); }
.sede-dash-card__body { padding:1rem; }
.sede-panel { background:#f8f9fa; border-radius:10px; padding:1rem; border:1px solid rgba(0,0,0,.06); }
.sede-panel__titulo { font-size:.78rem; font-weight:700; text-transform:uppercase; letter-spacing:.05em; color:#6b7280; margin-bottom:.75rem; }
.mini-kpi { background:white; border-radius:8px; padding:.6rem; text-align:center; border:1px solid rgba(0,0,0,.06); }
.mini-kpi__valor { font-size:1.3rem; font-weight:700; color:#1f2937; line-height:1; }
.mini-kpi__label { font-size:.72rem; color:#6b7280; margin-top:.15rem; }
</style>


