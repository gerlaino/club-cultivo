<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useLotesStore }  from "../stores/lotes";
import { usePlantsStore } from "../stores/plants";
import { useAuthStore }   from "../stores/auth";
import { getCostoLote, createCostoLote, updateCostoLote } from "../lib/api";

const route  = useRoute();
const router = useRouter();
const lotes  = useLotesStore();
const plants = usePlantsStore();
const auth   = useAuthStore();

const id      = Number(route.params.id);
const error   = ref(null);
const loading = computed(() => lotes.loading);
const lote    = computed(() => lotes.current);
const canEdit = computed(() => ["admin","agricultor"].includes(auth.role));

// ── Costo lote ────────────────────────────────────────────────────────────────
const costo          = ref(null)
const showCostoModal = ref(false)
const savingCosto    = ref(false)
const costoError     = ref(null)

function emptyCostoForm() {
  return { costo_insumos: 0, costo_energia: 0, costo_mano_obra: 0,
    costo_prorrateado: 0, gramos_producidos: null, notas: "" }
}
const costoForm = ref(emptyCostoForm())

const costoTotal = computed(() =>
  (Number(costoForm.value.costo_insumos)     || 0) +
  (Number(costoForm.value.costo_energia)     || 0) +
  (Number(costoForm.value.costo_mano_obra)   || 0) +
  (Number(costoForm.value.costo_prorrateado) || 0)
)
const costoPorGramoPreview = computed(() => {
  const g = Number(costoForm.value.gramos_producidos)
  if (!g || g <= 0) return null
  return (costoTotal.value / g).toFixed(2)
})

function fmt(n) {
  if (n == null) return "—"
  return new Intl.NumberFormat("es-AR", { style: "currency", currency: "ARS",
    minimumFractionDigits: 0 }).format(n)
}

function openCostoModal() {
  if (costo.value) {
    costoForm.value = {
      costo_insumos:     costo.value.costo_insumos     || 0,
      costo_energia:     costo.value.costo_energia     || 0,
      costo_mano_obra:   costo.value.costo_mano_obra   || 0,
      costo_prorrateado: costo.value.costo_prorrateado || 0,
      gramos_producidos: costo.value.gramos_producidos || null,
      notas:             costo.value.notas             || "",
    }
  } else {
    costoForm.value = emptyCostoForm()
  }
  costoError.value    = null
  showCostoModal.value = true
}

async function submitCosto() {
  savingCosto.value = true
  costoError.value  = null
  try {
    const payload = { ...costoForm.value }
    let res
    if (costo.value) {
      res = await updateCostoLote(id, payload)
    } else {
      res = await createCostoLote(id, payload)
    }
    costo.value          = res.data
    showCostoModal.value = false
  } catch (e) {
    costoError.value = e?.response?.data?.errors?.join(", ") || "No se pudo guardar el costo"
  } finally {
    savingCosto.value = false
  }
}

async function loadCosto() {
  try {
    const { data } = await getCostoLote(id)
    costo.value = data.costo || null
  } catch { costo.value = null }
}

// helpers
const ESTADO_META = {
  planificacion: { label:"Planificación", color:"info",      icon:"📋" },
  vegetativo:    { label:"Vegetativo",    color:"success",   icon:"🌱" },
  floracion:     { label:"Floración",     color:"warning",   icon:"🌸" },
  secado:        { label:"Secado",        color:"secondary", icon:"🍂" },
  cosechado:     { label:"Cosechado",     color:"primary",   icon:"✂️"  },
  finalizado:    { label:"Finalizado",    color:"dark",      icon:"✅" },
};
function em(e)         { return ESTADO_META[e] || { label:e||"—", color:"secondary", icon:"•" }; }
function estadoLabel(e){ return em(e).label; }
function estadoBadge(e){ return em(e).color; }
function estadoIcon(e) { return em(e).icon; }
function growLabel(g)  { return { sustrato:"Sustrato", hidroponia:"Hidroponia", aeroponia:"Aeroponia" }[g] || g || "—"; }
function lightLabel(l) { return { led:"LED", hps:"HPS", cmh:"CMH", natural:"Natural", mixta:"Mixta" }[l] || l || "—"; }
function plantStateLabel(s) {
  return { germinacion:"Germinación", vegetativo:"Vegetativo", floracion:"Floración",
    cosecha:"Cosecha", seco:"Seco" }[s] || s || "—";
}

const CICLO = ["planificacion","vegetativo","floracion","secado","cosechado","finalizado"];
const cicloIndex = computed(() => lote.value ? CICLO.indexOf(lote.value.estado) : -1);
const plantList  = computed(() => plants.byLote(id));

onMounted(async () => {
  try   { await lotes.fetchOne(id); }
  catch { error.value = "No se pudo cargar el lote."; }
  try   { await plants.fetchByLote(id); }
  catch (e) { console.warn("Sin plantas:", e); }
  await loadCosto()
});
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Breadcrumb -->
    <nav aria-label="breadcrumb" class="mb-3">
      <ol class="breadcrumb small">
        <li class="breadcrumb-item"><RouterLink :to="{ name: 'lotes' }">Lotes</RouterLink></li>
        <li v-if="lote?.sala" class="breadcrumb-item">
          <RouterLink :to="{ name: 'sala-detail', params: { id: lote.sala.id } }">{{ lote.sala.nombre }}</RouterLink>
        </li>
        <li class="breadcrumb-item active">{{ lote?.codigo || `Lote #${id}` }}</li>
      </ol>
    </nav>

    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!lote" class="alert alert-warning">Lote no encontrado.</div>

    <template v-else>

      <!-- Header -->
      <div class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-4">
        <div>
          <div class="d-flex align-items-center gap-2 mb-1">
            <span class="fs-3">{{ estadoIcon(lote.estado) }}</span>
            <h1 class="h3 fw-bold mb-0">{{ lote.codigo }}</h1>
            <span class="badge fs-6" :class="`text-bg-${estadoBadge(lote.estado)}`">
              {{ estadoLabel(lote.estado) }}
            </span>
          </div>
          <p class="text-muted small mb-0">
            <span v-if="lote.strain">🌿 {{ lote.strain }}</span>
            <span v-if="lote.sala"> · 📍 {{ lote.sala.nombre }}</span>
            <span v-if="lote.start_date"> · 📅 inicio {{ lote.start_date }}</span>
          </p>
        </div>
      </div>

      <!-- Timeline del ciclo -->
      <div class="card border-0 bg-body-secondary mb-4">
        <div class="card-body py-3">
          <div class="small text-muted mb-2">Ciclo de cultivo</div>
          <div class="d-flex align-items-center gap-0 ciclo-timeline">
            <template v-for="(etapa, i) in CICLO" :key="etapa">
              <div
                class="ciclo-step flex-fill text-center py-2 px-1 rounded small"
                :class="{
                  'ciclo-step--done':    i < cicloIndex,
                  'ciclo-step--current': i === cicloIndex,
                  'ciclo-step--pending': i > cicloIndex,
                }"
              >
                <div class="ciclo-step__icon">{{ em(etapa).icon }}</div>
                <div class="ciclo-step__label d-none d-sm-block" style="font-size:.7rem">{{ em(etapa).label }}</div>
              </div>
              <div v-if="i < CICLO.length-1" class="ciclo-connector"
                   :class="{ 'ciclo-connector--done': i < cicloIndex }"></div>
            </template>
          </div>
          <div v-if="lote.dias_desde_inicio != null" class="text-center small text-muted mt-2">
            Día <strong>{{ lote.dias_desde_inicio }}</strong> desde el inicio del ciclo
          </div>
        </div>
      </div>

      <div class="row g-4">

        <!-- ── Col principal ── -->
        <div class="col-12 col-lg-8">

          <!-- Imagen placeholder -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>📷 Registro visual</strong>
              <span class="badge text-bg-secondary">Próximamente</span>
            </div>
            <div class="ratio ratio-16x9 bg-dark d-flex align-items-center justify-content-center text-white rounded-bottom">
              <div class="text-center py-4">
                <div class="fs-1 mb-2">🌿</div>
                <div>Sin imágenes adjuntas</div>
                <small class="text-white-50">Podrás subir fotos por planta en futuras versiones</small>
              </div>
            </div>
          </div>

          <!-- Plantas -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>🪴 Plantas del lote</strong>
              <div class="d-flex align-items-center gap-2">
                <span class="badge text-bg-secondary">{{ plantList.length }}</span>
                <button class="btn btn-sm btn-outline-secondary" @click="plants.fetchByLote(id)">↻</button>
              </div>
            </div>
            <div class="card-body p-0">
              <div v-if="plants.loading" class="p-3 text-muted">Cargando plantas…</div>
              <div v-else-if="plants.error" class="alert alert-danger m-3">{{ plants.error }}</div>
              <div v-else-if="!plantList.length" class="p-4 text-center text-muted">
                <div class="fs-1 mb-2">🪴</div>
                <div>Sin plantas registradas en este lote</div>
              </div>
              <div v-else class="table-responsive">
                <table class="table table-hover align-middle mb-0">
                  <thead class="table-light">
                  <tr>
                    <th>#</th>
                    <th>Código QR</th>
                    <th>Nombre</th>
                    <th>Estado</th>
                    <th>Germinación</th>
                    <th></th>
                  </tr>
                  </thead>
                  <tbody>
                  <tr v-for="(p, i) in plantList" :key="p.id">
                    <td class="text-muted small">{{ i+1 }}</td>
                    <td class="font-monospace small">{{ p.codigo_qr || "—" }}</td>
                    <td>{{ p.nombre || "—" }}</td>
                    <td class="text-capitalize small">{{ plantStateLabel(p.state) }}</td>
                    <td class="small text-muted">{{ p.fecha_germinacion || "—" }}</td>
                    <td class="text-end">
                      <RouterLink class="btn btn-sm btn-outline-primary"
                                  :to="{ name:'planta-detalle', params:{ id: p.id } }">
                        Ver
                      </RouterLink>
                    </td>
                  </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

        </div>

        <!-- ── Col lateral ── -->
        <div class="col-12 col-lg-4">

          <!-- ── COSTO DEL LOTE ── -->
          <div class="card border-0 shadow-sm mb-3"
               :class="costo ? 'border-success' : 'border-warning'"
               style="border-left: 4px solid;">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>💰 Costo de producción</strong>
              <button v-if="canEdit" class="btn btn-sm btn-outline-secondary"
                      @click="openCostoModal">
                {{ costo ? "✏️ Editar" : "＋ Cargar" }}
              </button>
            </div>
            <div class="card-body small">

              <!-- Sin costo -->
              <div v-if="!costo" class="text-center py-2 text-muted">
                <div class="fs-3 mb-1">📊</div>
                <div>Sin costo calculado</div>
                <div class="mt-1" style="font-size:.75rem">
                  Cargá el costo para habilitar el cálculo automático en dispensaciones
                </div>
              </div>

              <!-- Con costo -->
              <template v-else>
                <dl class="row mb-2">
                  <dt class="col-7 text-muted fw-normal">Insumos</dt>
                  <dd class="col-5 text-end">{{ fmt(costo.costo_insumos) }}</dd>

                  <dt class="col-7 text-muted fw-normal">Energía</dt>
                  <dd class="col-5 text-end">{{ fmt(costo.costo_energia) }}</dd>

                  <dt class="col-7 text-muted fw-normal">Mano de obra</dt>
                  <dd class="col-5 text-end">{{ fmt(costo.costo_mano_obra) }}</dd>

                  <dt class="col-7 text-muted fw-normal">Prorrateado</dt>
                  <dd class="col-5 text-end">{{ fmt(costo.costo_prorrateado) }}</dd>
                </dl>

                <div class="border-top pt-2">
                  <div class="d-flex justify-content-between fw-semibold">
                    <span>Total</span>
                    <span>{{ fmt(costo.costo_total) }}</span>
                  </div>
                  <div v-if="costo.gramos_producidos" class="d-flex justify-content-between text-muted mt-1">
                    <span>Gramos producidos</span>
                    <span>{{ costo.gramos_producidos }}g</span>
                  </div>
                  <div v-if="costo.costo_por_gramo"
                       class="d-flex justify-content-between mt-1 fw-bold text-success">
                    <span>Costo / gramo</span>
                    <span>{{ fmt(costo.costo_por_gramo) }}</span>
                  </div>
                </div>

                <div v-if="costo.notas" class="mt-2 text-muted border-top pt-2">
                  {{ costo.notas }}
                </div>
              </template>

            </div>
          </div>

          <!-- Info técnica -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>⚙️ Datos técnicos</strong></div>
            <div class="card-body small">
              <dl class="row mb-0">
                <dt class="col-6 text-muted fw-normal">Plantas</dt>
                <dd class="col-6"><strong>{{ lote.plants_count ?? 0 }}</strong></dd>

                <dt class="col-6 text-muted fw-normal">Tipo cultivo</dt>
                <dd class="col-6">{{ growLabel(lote.grow_type) }}</dd>

                <dt class="col-6 text-muted fw-normal">Luminaria</dt>
                <dd class="col-6">{{ lightLabel(lote.light_type) }}</dd>

                <dt class="col-6 text-muted fw-normal">Fecha inicio</dt>
                <dd class="col-6">{{ lote.start_date || "—" }}</dd>

                <dt class="col-6 text-muted fw-normal">Días en ciclo</dt>
                <dd class="col-6">{{ lote.dias_desde_inicio ?? "—" }}</dd>

                <dt v-if="lote.progreso_ciclo != null" class="col-6 text-muted fw-normal">Progreso</dt>
                <dd v-if="lote.progreso_ciclo != null" class="col-6 mb-0">
                  <div class="progress mt-1" style="height:6px">
                    <div class="progress-bar bg-success" :style="{ width: lote.progreso_ciclo + '%' }"></div>
                  </div>
                  <div class="text-muted">{{ lote.progreso_ciclo }}%</div>
                </dd>
              </dl>
            </div>
          </div>

          <!-- Info general -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>ℹ️ Información</strong></div>
            <div class="card-body small">
              <dl class="row mb-0">
                <dt class="col-5 text-muted fw-normal">ID</dt>
                <dd class="col-7">{{ lote.id }}</dd>

                <dt class="col-5 text-muted fw-normal">Sala</dt>
                <dd class="col-7">
                  <RouterLink v-if="lote.sala" :to="{ name:'sala-detail', params:{ id: lote.sala.id } }">
                    {{ lote.sala.nombre }}
                  </RouterLink>
                  <span v-else>—</span>
                </dd>

                <dt class="col-5 text-muted fw-normal">Creado</dt>
                <dd class="col-7">{{ lote.created_at ? new Date(lote.created_at).toLocaleDateString("es-AR") : "—" }}</dd>

                <dt class="col-5 text-muted fw-normal">Actualizado</dt>
                <dd class="col-7 mb-0">{{ lote.updated_at ? new Date(lote.updated_at).toLocaleDateString("es-AR") : "—" }}</dd>
              </dl>
            </div>
          </div>

          <!-- Notas -->
          <div v-if="lote.notes" class="card border-0 shadow-sm">
            <div class="card-header bg-transparent"><strong>📋 Notas</strong></div>
            <div class="card-body small">{{ lote.notes }}</div>
          </div>

        </div>
      </div>
    </template>

    <!-- ═══════════════ MODAL COSTO ═══════════════ -->
    <div class="modal fade" :class="{ show: showCostoModal }"
         :style="{ display: showCostoModal ? 'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">💰 {{ costo ? "Editar" : "Cargar" }} costo de producción</h5>
            <button class="btn-close" @click="showCostoModal = false"></button>
          </div>
          <div class="modal-body">
            <div v-if="costoError" class="alert alert-danger">{{ costoError }}</div>

            <div class="row g-3">
              <div class="col-6">
                <label class="form-label small">Insumos (ARS)</label>
                <div class="input-group input-group-sm">
                  <span class="input-group-text">$</span>
                  <input type="number" min="0" step="0.01" class="form-control"
                         v-model.number="costoForm.costo_insumos" />
                </div>
              </div>
              <div class="col-6">
                <label class="form-label small">Energía (ARS)</label>
                <div class="input-group input-group-sm">
                  <span class="input-group-text">$</span>
                  <input type="number" min="0" step="0.01" class="form-control"
                         v-model.number="costoForm.costo_energia" />
                </div>
              </div>
              <div class="col-6">
                <label class="form-label small">Mano de obra (ARS)</label>
                <div class="input-group input-group-sm">
                  <span class="input-group-text">$</span>
                  <input type="number" min="0" step="0.01" class="form-control"
                         v-model.number="costoForm.costo_mano_obra" />
                </div>
              </div>
              <div class="col-6">
                <label class="form-label small">Gastos prorrateados (ARS)</label>
                <div class="input-group input-group-sm">
                  <span class="input-group-text">$</span>
                  <input type="number" min="0" step="0.01" class="form-control"
                         v-model.number="costoForm.costo_prorrateado" />
                </div>
              </div>
              <div class="col-12">
                <label class="form-label small">Gramos producidos</label>
                <div class="input-group input-group-sm">
                  <input type="number" min="0.01" step="0.01" class="form-control"
                         v-model.number="costoForm.gramos_producidos"
                         placeholder="Ej: 250" />
                  <span class="input-group-text">g</span>
                </div>
              </div>

              <!-- Preview en tiempo real -->
              <div class="col-12">
                <div class="card border-0 bg-body-secondary">
                  <div class="card-body py-2 px-3 small">
                    <div class="d-flex justify-content-between">
                      <span class="text-muted">Costo total</span>
                      <span class="fw-semibold">{{ fmt(costoTotal) }}</span>
                    </div>
                    <div v-if="costoPorGramoPreview" class="d-flex justify-content-between mt-1">
                      <span class="text-muted">Costo / gramo</span>
                      <span class="fw-bold text-success">{{ fmt(costoPorGramoPreview) }}</span>
                    </div>
                    <div v-else class="text-muted mt-1">
                      Ingresá los gramos producidos para calcular el costo/gramo
                    </div>
                  </div>
                </div>
              </div>

              <div class="col-12">
                <label class="form-label small">Notas</label>
                <textarea class="form-control form-control-sm" rows="2"
                          v-model.trim="costoForm.notas"
                          placeholder="Observaciones opcionales…"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="savingCosto"
                    @click="showCostoModal = false">Cancelar</button>
            <button class="btn btn-success" :disabled="savingCosto" @click="submitCosto">
              <span v-if="savingCosto" class="spinner-border spinner-border-sm me-2"></span>
              Guardar costo
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCostoModal }" v-if="showCostoModal"
         @click="showCostoModal = false"></div>

  </div>
</template>

<style scoped>
.ciclo-timeline { overflow-x: auto; }
.ciclo-step { min-width: 48px; cursor: default; transition: background .15s; }
.ciclo-step--done    { background: rgba(25,135,84,.15); color: #198754; }
.ciclo-step--current { background: rgba(13,110,253,.15); color: #0d6efd; font-weight: 700; box-shadow: 0 0 0 2px #0d6efd33; }
.ciclo-step--pending { opacity: .4; }
.ciclo-connector { width: 16px; height: 2px; background: #dee2e6; flex-shrink: 0; }
.ciclo-connector--done { background: #198754; }
</style>
