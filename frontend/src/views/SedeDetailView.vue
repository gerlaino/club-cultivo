<script setup>
import { ref, computed, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";
import { getSede, listSalas } from "../lib/api";

const route  = useRoute();
const router = useRouter();
const auth   = useAuthStore();

const sedeId  = Number(route.params.id);
const sede    = ref(null);
const salas   = ref([]);
const loading = ref(true);
const error   = ref(null);

const canEdit = computed(() => ["admin", "agricultor"].includes(auth.role));

const TIPO_META = {
  produccion: { label: "Producción",           icon: "🌱", color: "success" },
  social:     { label: "Social / Dispensario", icon: "🏪", color: "primary" },
  mixta:      { label: "Mixta",                icon: "🔄", color: "purple"  },
};
function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.produccion; }

function stateBadge(state) {
  return { activa: "success", mantenimiento: "warning", cerrada: "secondary" }[state] || "secondary";
}
function stateIcon(state) {
  return { activa: "🟢", mantenimiento: "🟡", cerrada: "⚫" }[state] || "⚪";
}

// KPIs de salas de esta sede
const kpis = computed(() => {
  const all = salas.value;
  return {
    total:     all.length,
    activas:   all.filter(s => s.state === "activa").length,
    plantas:   all.reduce((a, s) => a + Number(s.plantas_totales || 0), 0),
    capacidad: all.reduce((a, s) => a + Number(s.pots_count || 0), 0),
  };
});

onMounted(async () => {
  try {
    // Cargamos sede (detail) y todas las salas del club filtradas por sede
    const [sedeRes, salasRes] = await Promise.all([
      getSede(sedeId),
      listSalas(),
    ]);
    sede.value  = sedeRes.data;
    // El index de salas devuelve sede embebida — filtramos por sede_id
    salas.value = (salasRes.data || []).filter(s => s.sede?.id === sedeId);
  } catch (e) {
    error.value = "No se pudo cargar la sede.";
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Breadcrumb -->
    <nav aria-label="breadcrumb" class="mb-3">
      <ol class="breadcrumb small">
        <li class="breadcrumb-item">
          <RouterLink :to="{ name: 'sedes' }">Sedes</RouterLink>
        </li>
        <li class="breadcrumb-item active">{{ sede?.nombre || "Detalle" }}</li>
      </ol>
    </nav>

    <!-- Loading / Error -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-primary"></div>
      <div class="mt-2 text-muted">Cargando sede…</div>
    </div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>
    <div v-else-if="!sede" class="alert alert-warning">Sede no encontrada.</div>

    <template v-else>

      <!-- Header -->
      <div class="d-flex flex-wrap justify-content-between align-items-start gap-3 mb-4">
        <div>
          <div class="d-flex align-items-center gap-2 mb-1 flex-wrap">
            <span class="fs-3">{{ tipoMeta(sede.tipo).icon }}</span>
            <h1 class="h3 fw-bold mb-0">{{ sede.nombre }}</h1>
            <span class="badge text-bg-secondary fs-6">{{ sede.tipo_label }}</span>
            <span v-if="!sede.activa" class="badge text-bg-warning">Inactiva</span>
            <span v-if="sede.declarada_reprocann" class="badge text-bg-success">REPROCANN ✓</span>
          </div>
          <p class="text-muted small mb-0">
            <span v-if="sede.direccion_completa">📍 {{ sede.direccion_completa }}</span>
          </p>
        </div>
        <div class="d-flex gap-2">
          <RouterLink
            v-if="canEdit"
            :to="{ name: 'salas', query: { sede_id: sedeId } }"
            class="btn btn-outline-primary"
          >
            + Nueva sala aquí
          </RouterLink>
          <button class="btn btn-outline-secondary btn-sm" @click="router.back()">
            ← Volver
          </button>
        </div>
      </div>

      <!-- KPIs -->
      <div class="row g-3 mb-4">
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100">
            <div class="card-body py-3 text-center">
              <div class="text-muted small">Salas totales</div>
              <div class="h2 fw-bold mb-0">{{ kpis.total }}</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100">
            <div class="card-body py-3 text-center">
              <div class="text-muted small">Activas</div>
              <div class="h2 fw-bold mb-0 text-success">{{ kpis.activas }}</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100">
            <div class="card-body py-3 text-center">
              <div class="text-muted small">Plantas totales</div>
              <div class="h2 fw-bold mb-0">{{ kpis.plantas }}</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100">
            <div class="card-body py-3 text-center">
              <div class="text-muted small">Capacidad total</div>
              <div class="h2 fw-bold mb-0">{{ kpis.capacidad }}</div>
            </div>
          </div>
        </div>
      </div>

      <div class="row g-4">

        <!-- Col principal: salas -->
        <div class="col-12 col-lg-8">
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>🏗️ Salas de esta sede</strong>
              <span class="badge text-bg-secondary">{{ salas.length }}</span>
            </div>
            <div class="card-body p-0">

              <!-- Sin salas -->
              <div v-if="!salas.length" class="p-4 text-center text-muted">
                <div class="fs-1 mb-2">🏗️</div>
                <div>Esta sede no tiene salas asignadas todavía.</div>
                <RouterLink
                  v-if="canEdit"
                  :to="{ name: 'salas' }"
                  class="btn btn-sm btn-outline-primary mt-2"
                >
                  Ir a Salas para crear una
                </RouterLink>
              </div>

              <!-- Lista de salas -->
              <div v-else class="list-group list-group-flush">
                <RouterLink
                  v-for="s in salas"
                  :key="s.id"
                  :to="{ name: 'sala-detail', params: { id: s.id } }"
                  class="list-group-item list-group-item-action px-3 py-3"
                >
                  <div class="d-flex justify-content-between align-items-center gap-2">
                    <div class="flex-grow-1 min-w-0">
                      <div class="d-flex align-items-center gap-2 mb-1 flex-wrap">
                        <span class="fw-semibold text-truncate">{{ s.nombre }}</span>
                        <span class="badge" :class="`text-bg-${stateBadge(s.state)}`">
                          {{ stateIcon(s.state) }} {{ s.state }}
                        </span>
                        <span v-if="s.kind" class="badge text-bg-light text-dark">{{ s.kind }}</span>
                      </div>
                      <div class="small text-muted d-flex gap-3 flex-wrap">
                        <span>🪴 {{ s.plantas_totales ?? 0 }} plantas</span>
                        <span>📦 cap. {{ s.pots_count ?? 0 }}</span>
                        <span v-if="s.lotes_count !== undefined">📋 {{ s.lotes_count }} lotes</span>
                      </div>
                    </div>
                    <!-- Barra ocupación -->
                    <div class="d-none d-sm-flex flex-column align-items-end gap-1" style="min-width:80px">
                      <div class="small text-muted">{{ (s.porcentaje_ocupacion || 0).toFixed(0) }}%</div>
                      <div class="progress w-100" style="height:6px">
                        <div
                          class="progress-bar"
                          :class="(s.porcentaje_ocupacion||0) >= 90 ? 'bg-danger' : (s.porcentaje_ocupacion||0) >= 70 ? 'bg-warning' : 'bg-success'"
                          :style="{ width: Math.min(s.porcentaje_ocupacion||0, 100) + '%' }"
                        ></div>
                      </div>
                    </div>
                    <span class="text-muted ms-2">›</span>
                  </div>
                </RouterLink>
              </div>

            </div>
          </div>
        </div>

        <!-- Col lateral: info -->
        <div class="col-12 col-lg-4">

          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>ℹ️ Información</strong></div>
            <div class="card-body small">
              <dl class="row mb-0">
                <dt class="col-5 text-muted fw-normal">ID</dt>
                <dd class="col-7">{{ sede.id }}</dd>

                <dt class="col-5 text-muted fw-normal">Tipo</dt>
                <dd class="col-7">{{ sede.tipo_label }}</dd>

                <dt class="col-5 text-muted fw-normal">Estado</dt>
                <dd class="col-7">
                  <span class="badge" :class="sede.activa ? 'text-bg-success' : 'text-bg-warning'">
                    {{ sede.activa ? "Activa" : "Inactiva" }}
                  </span>
                </dd>

                <dt class="col-5 text-muted fw-normal">REPROCANN</dt>
                <dd class="col-7">
                  <span class="badge" :class="sede.declarada_reprocann ? 'text-bg-success' : 'text-bg-light text-dark'">
                    {{ sede.declarada_reprocann ? "Declarada ✓" : "No declarada" }}
                  </span>
                </dd>

                <template v-if="sede.direccion">
                  <dt class="col-5 text-muted fw-normal">Dirección</dt>
                  <dd class="col-7">{{ sede.direccion }}</dd>
                </template>

                <template v-if="sede.ciudad">
                  <dt class="col-5 text-muted fw-normal">Ciudad</dt>
                  <dd class="col-7">{{ sede.ciudad }}</dd>
                </template>

                <template v-if="sede.provincia">
                  <dt class="col-5 text-muted fw-normal">Provincia</dt>
                  <dd class="col-7">{{ sede.provincia }}</dd>
                </template>

                <dt class="col-5 text-muted fw-normal">Creada</dt>
                <dd class="col-7 mb-0">
                  {{ sede.created_at ? new Date(sede.created_at).toLocaleDateString("es-AR") : "—" }}
                </dd>
              </dl>
            </div>
          </div>

          <div v-if="sede.notas" class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>📋 Notas</strong></div>
            <div class="card-body small">{{ sede.notas }}</div>
          </div>

          <!-- Acceso rápido -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent"><strong>🔗 Acceso rápido</strong></div>
            <div class="list-group list-group-flush">
              <RouterLink :to="{ name: 'lotes' }" class="list-group-item list-group-item-action small py-2">
                📦 Ver todos los lotes del club
              </RouterLink>
              <RouterLink :to="{ name: 'plantas' }" class="list-group-item list-group-item-action small py-2">
                🪴 Ver todas las plantas del club
              </RouterLink>
              <RouterLink :to="{ name: 'sedes' }" class="list-group-item list-group-item-action small py-2">
                🏢 Volver a todas las sedes
              </RouterLink>
            </div>
          </div>

        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
/* nada extra — todo Bootstrap */
</style>
