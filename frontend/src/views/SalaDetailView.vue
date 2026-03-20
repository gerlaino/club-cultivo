<script setup>
import { onMounted, ref, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useSalasStore } from "../stores/salas";
import { useLotesStore } from "../stores/lotes";
import { useAuthStore } from "../stores/auth";

const route  = useRoute();
const router = useRouter();
const salas  = useSalasStore();
const lotes  = useLotesStore();
const auth   = useAuthStore();

const salaId  = Number(route.params.id) || 0;
const loading = ref(true);
const error   = ref(null);

const canEdit = computed(() => ["admin","agricultor"].includes(auth.role));

// Valores permitidos:
// estado lote: planificacion | vegetativo | floracion | secado | cosechado | finalizado
// grow_type:   sustrato | hidroponia | aeroponia
// light_type:  led | hps | cmh | natural | mixta

const ESTADOS_LOTE = ["planificacion","vegetativo","floracion","secado","cosechado","finalizado"];

function emptyLoteForm() {
  return {
    codigo: "", estado: "vegetativo", plants_count: 0,
    start_date: new Date().toISOString().slice(0,10),
    strain: "", grow_type: "sustrato", light_type: "", notes: "",
  };
}

const showCreate  = ref(false);
const loteForm    = ref(emptyLoteForm());
const loteErrors  = ref({});

onMounted(async () => {
  try {
    await salas.fetchSala(salaId);
    await lotes.fetchBySala(salaId);
  } catch { error.value = "No se pudo cargar la sala."; }
  finally  { loading.value = false; }
});

const sala  = computed(() => salas.currentSala);
const items = computed(() => lotes.bySala(salaId));

// KPIs de lotes
const kpis = computed(() => {
  const ls = items.value;
  return {
    totalLotes:   ls.length,
    totalPlantas: ls.reduce((a,l) => a + Number(l.plants_count||0), 0),
    enCiclo:      ls.filter(l => ["vegetativo","floracion"].includes(l.estado)).length,
    cosechados:   ls.filter(l => l.estado === "cosechado").length,
  };
});

// helpers
function salaBadge(state) {
  return { activa:"success", mantenimiento:"warning", cerrada:"secondary" }[state] || "secondary";
}
function estadoBadge(e) {
  return { planificacion:"info", vegetativo:"success", floracion:"warning", secado:"secondary", cosechado:"primary", finalizado:"dark" }[e] || "secondary";
}
function estadoLabel(e) {
  return { planificacion:"Planificación", vegetativo:"Vegetativo", floracion:"Floración", secado:"Secado", cosechado:"Cosechado", finalizado:"Finalizado" }[e] || e || "—";
}
function growLabel(g) {
  return { sustrato:"Sustrato", hidroponia:"Hidroponia", aeroponia:"Aeroponia" }[g] || g || "—";
}
function lightLabel(l) {
  return { led:"LED", hps:"HPS", cmh:"CMH", natural:"Natural", mixta:"Mixta" }[l] || l || "—";
}
function ocupacionColor(pct) {
  return pct >= 90 ? "danger" : pct >= 70 ? "warning" : "success";
}
function ocupacionPct(sala) {
  return Math.min(sala?.porcentaje_ocupacion || 0, 100);
}

// Ordenar lotes por estado activo primero
const itemsSorted = computed(() => {
  const order = ["vegetativo","floracion","planificacion","secado","cosechado","finalizado"];
  return [...items.value].sort((a,b) => order.indexOf(a.estado) - order.indexOf(b.estado));
});

function validateLote(form) {
  const e = {};
  if (!form.codigo?.trim()) e.codigo = "El código es obligatorio";
  if (!ESTADOS_LOTE.includes(form.estado)) e.estado = "Estado inválido";
  const n = Number(form.plants_count);
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser 0–5000";
  return e;
}
async function createLote() {
  const e = validateLote(loteForm.value);
  loteErrors.value = e;
  if (Object.keys(e).length) return;
  try {
    await lotes.createInSala(salaId, { ...loteForm.value });
    closeCreate();
  } catch {}
}
function closeCreate() {
  showCreate.value = false;
  loteForm.value   = emptyLoteForm();
  loteErrors.value = {};
}
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- ── Breadcrumb + header ── -->
    <nav aria-label="breadcrumb" class="mb-3">
      <ol class="breadcrumb small">
        <li class="breadcrumb-item">
          <RouterLink :to="{ name: 'sedes' }">Sedes</RouterLink>
        </li>
        <li v-if="sala?.sede" class="breadcrumb-item">
          <RouterLink :to="{ name: 'sede-detail', params: { id: sala.sede.id } }">
            {{ sala.sede.nombre }}
          </RouterLink>
        </li>
        <li class="breadcrumb-item" :class="{ active: !sala?.sede }">
          <RouterLink v-if="!sala?.sede" :to="{ name: 'salas' }">Salas</RouterLink>
          <span v-else>{{ sala?.nombre || "Detalle" }}</span>
        </li>
        <li v-if="sala?.sede" class="breadcrumb-item active">
          {{ sala?.nombre || "Detalle" }}
        </li>
      </ol>
    </nav>

    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-primary"></div>
    </div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!sala" class="alert alert-warning">Sala no encontrada.</div>

    <template v-else>

      <!-- ── Header sala ── -->
      <div class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-4">
        <div>
          <div class="d-flex align-items-center gap-2 mb-1">
            <h1 class="h3 fw-bold mb-0">{{ sala.nombre }}</h1>
            <span class="badge fs-6" :class="`text-bg-${salaBadge(sala.state)}`">{{ sala.state }}</span>
          </div>
          <p class="text-muted small mb-0">
            {{ sala.kind ? `Sala de ${sala.kind}` : 'Sin tipo asignado' }}
            <span v-if="sala.created_by_name"> · Creado por {{ sala.created_by_name }}</span>
          </p>
        </div>
        <button v-if="canEdit" class="btn btn-primary" @click="showCreate = true">
          + Nuevo lote
        </button>
      </div>

      <!-- ── KPIs ── -->
      <div class="row g-3 mb-4">
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary text-center h-100">
            <div class="card-body py-3">
              <div class="text-muted small">Plantas activas</div>
              <div class="h2 fw-bold mb-0">{{ kpis.totalPlantas }}</div>
              <div class="small text-muted">de {{ sala.pots_count ?? 0 }} cap.</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary text-center h-100">
            <div class="card-body py-3">
              <div class="text-muted small">Ocupación</div>
              <div class="h2 fw-bold mb-0" :class="`text-${ocupacionColor(sala.porcentaje_ocupacion)}`">
                {{ (sala.porcentaje_ocupacion || 0).toFixed(0) }}%
              </div>
              <div class="progress mt-1" style="height:6px">
                <div class="progress-bar" :class="`bg-${ocupacionColor(sala.porcentaje_ocupacion)}`"
                     :style="{ width: ocupacionPct(sala) + '%' }"></div>
              </div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary text-center h-100">
            <div class="card-body py-3">
              <div class="text-muted small">Lotes activos</div>
              <div class="h2 fw-bold mb-0 text-success">{{ kpis.enCiclo }}</div>
              <div class="small text-muted">en vegetativo o floración</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary text-center h-100">
            <div class="card-body py-3">
              <div class="text-muted small">Total lotes</div>
              <div class="h2 fw-bold mb-0">{{ kpis.totalLotes }}</div>
              <div class="small text-muted">{{ kpis.cosechados }} cosechados</div>
            </div>
          </div>
        </div>
      </div>

      <div class="row g-4">
        <!-- ── Col principal ── -->
        <div class="col-12 col-lg-8">

          <!-- Cámara -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>📷 Cámara en vivo</strong>
              <span class="badge text-bg-secondary">No configurada</span>
            </div>
            <div class="card-body p-0">
              <div class="ratio ratio-16x9 bg-dark d-flex align-items-center justify-content-center text-white rounded-bottom">
                <div class="text-center py-4">
                  <div class="fs-1 mb-2">🎥</div>
                  <div>Stream no configurado</div>
                  <small class="text-white-50">Integración con Home Assistant próximamente</small>
                </div>
              </div>
            </div>
          </div>

          <!-- Lotes -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>🌿 Lotes</strong>
              <span class="badge text-bg-secondary">{{ items.length }}</span>
            </div>
            <div class="card-body p-0">
              <div v-if="lotes.loading" class="p-3 text-muted">Cargando lotes…</div>
              <div v-else-if="!items.length" class="p-4 text-center text-muted">
                <div class="fs-1 mb-2">📦</div>
                <div>Esta sala no tiene lotes todavía</div>
                <button v-if="canEdit" class="btn btn-sm btn-outline-primary mt-2" @click="showCreate=true">
                  Crear primer lote
                </button>
              </div>
              <div v-else class="list-group list-group-flush">
                <RouterLink
                  v-for="l in itemsSorted" :key="l.id"
                  :to="{ name: 'lote-detail', params: { id: l.id } }"
                  class="list-group-item list-group-item-action px-3 py-3"
                >
                  <div class="d-flex justify-content-between align-items-center gap-2">
                    <div class="flex-grow-1 min-w-0">
                      <div class="d-flex align-items-center gap-2 mb-1">
                        <span class="fw-semibold">{{ l.codigo }}</span>
                        <span class="badge" :class="`text-bg-${estadoBadge(l.estado)}`">
                          {{ estadoLabel(l.estado) }}
                        </span>
                      </div>
                      <div class="small text-muted d-flex gap-3 flex-wrap">
                        <span>🪴 {{ l.plants_count ?? 0 }} plantas</span>
                        <span v-if="l.strain">🌿 {{ l.strain }}</span>
                        <span v-if="l.grow_type">⚗️ {{ growLabel(l.grow_type) }}</span>
                        <span v-if="l.start_date">📅 {{ l.start_date }}</span>
                      </div>
                    </div>
                    <span class="text-muted">›</span>
                  </div>
                </RouterLink>
              </div>
            </div>
          </div>
        </div>

        <!-- ── Col lateral ── -->
        <div class="col-12 col-lg-4">
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>ℹ️ Información</strong></div>
            <div class="card-body small">
              <dl class="row mb-0">
                <dt class="col-5 text-muted fw-normal">ID</dt>
                <dd class="col-7">{{ sala.id }}</dd>

                <dt class="col-5 text-muted fw-normal">Estado</dt>
                <dd class="col-7 text-capitalize">{{ sala.state }}</dd>

                <dt class="col-5 text-muted fw-normal">Tipo</dt>
                <dd class="col-7">{{ sala.kind || "—" }}</dd>

                <dt class="col-5 text-muted fw-normal">Capacidad</dt>
                <dd class="col-7">{{ sala.pots_count ?? 0 }} plantas</dd>

                <dt class="col-5 text-muted fw-normal">Creado por</dt>
                <dd class="col-7">{{ sala.created_by_name || "—" }}</dd>

                <dt class="col-5 text-muted fw-normal">Creado</dt>
                <dd class="col-7">{{ new Date(sala.created_at).toLocaleDateString() }}</dd>

                <dt class="col-5 text-muted fw-normal">Actualizado</dt>
                <dd class="col-7 mb-0">{{ new Date(sala.updated_at).toLocaleDateString() }}</dd>
              </dl>
            </div>
          </div>

          <div v-if="sala.notes" class="card border-0 shadow-sm">
            <div class="card-header bg-transparent"><strong>📋 Notas</strong></div>
            <div class="card-body small">{{ sala.notes }}</div>
          </div>
        </div>
      </div>
    </template>

    <!-- ===== MODAL Crear Lote ===== -->
    <div class="modal fade" :class="{ show: showCreate }" :style="{ display: showCreate ? 'block':'none' }" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nuevo lote — {{ sala?.nombre }}</h5>
            <button class="btn-close" @click="closeCreate"></button>
          </div>
          <div class="modal-body">
            <div v-if="lotes.createError" class="alert alert-danger">{{ lotes.createError }}</div>
            <div class="row g-3">
              <div class="col-md-6">
                <label class="form-label">Código <span class="text-danger">*</span></label>
                <input type="text" class="form-control" v-model.trim="loteForm.codigo"
                       :class="{ 'is-invalid': loteErrors.codigo }" placeholder="Ej: LOT-2026-001" />
                <div class="invalid-feedback">{{ loteErrors.codigo }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Estado</label>
                <select class="form-select" v-model="loteForm.estado" :class="{ 'is-invalid': loteErrors.estado }">
                  <option value="planificacion">Planificación</option>
                  <option value="vegetativo">Vegetativo</option>
                  <option value="floracion">Floración</option>
                  <option value="secado">Secado</option>
                  <option value="cosechado">Cosechado</option>
                  <option value="finalizado">Finalizado</option>
                </select>
                <div class="invalid-feedback">{{ loteErrors.estado }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" step="1" class="form-control"
                       v-model.number="loteForm.plants_count" :class="{ 'is-invalid': loteErrors.plants_count }" />
                <div class="invalid-feedback">{{ loteErrors.plants_count }}</div>
              </div>
              <div class="col-md-6">
                <label class="form-label">Fecha de inicio</label>
                <input type="date" class="form-control" v-model="loteForm.start_date" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Strain / Variedad</label>
                <input type="text" class="form-control" v-model.trim="loteForm.strain" placeholder="Ej: OG Kush" />
              </div>
              <div class="col-md-6">
                <label class="form-label">Tipo de cultivo</label>
                <select class="form-select" v-model="loteForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Tipo de luz</label>
                <select class="form-select" v-model="loteForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Notas</label>
                <textarea class="form-control" rows="2" v-model.trim="loteForm.notes" placeholder="Observaciones…"></textarea>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="lotes.creating" @click="closeCreate">Cancelar</button>
            <button class="btn btn-primary" :disabled="lotes.creating" @click="createLote">
              <span v-if="lotes.creating" class="spinner-border spinner-border-sm me-2"></span>Crear lote
            </button>
          </div>
        </div>
      </div>
    </div>
    <div class="modal-backdrop fade" :class="{ show: showCreate }" v-if="showCreate" @click="closeCreate"></div>

  </div>
</template>

<style scoped>
.modal { background: rgba(0,0,0,.01); }
</style>

