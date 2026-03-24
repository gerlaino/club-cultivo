<script setup>
import { ref, computed, onMounted } from "vue"
import { useAuthStore } from "../stores/auth"
import { getInformeSemestral } from "../lib/api"

const auth    = useAuthStore()
const informe = ref(null)
const loading = ref(false)
const error   = ref(null)

const anioActual     = new Date().getFullYear()
const semestreActual = new Date().getMonth() < 6 ? 1 : 2

const anio     = ref(anioActual)
const semestre = ref(semestreActual)

const anios = computed(() => {
  const arr = []
  for (let y = anioActual; y >= anioActual - 3; y--) arr.push(y)
  return arr
})

async function cargar() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await getInformeSemestral({ anio: anio.value, semestre: semestre.value })
    informe.value = data
  } catch (e) {
    error.value = e?.response?.data?.error || "No se pudo generar el informe"
  } finally {
    loading.value = false
  }
}

function formatDate(d) {
  if (!d) return "—"
  return new Date(d).toLocaleDateString("es-AR", { day: "numeric", month: "long", year: "numeric" })
}

function formatDateShort(d) {
  if (!d) return "—"
  return new Date(d).toLocaleDateString("es-AR")
}

function estadoBadge(estado) {
  return {
    planificacion: "info", vegetativo: "success", floracion: "warning",
    secado: "secondary", cosechado: "primary", finalizado: "dark"
  }[estado] || "secondary"
}

// ── Exportar como HTML para imprimir / guardar PDF ────────────────────────────
function imprimir() {
  window.print()
}

onMounted(() => cargar())
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex justify-content-between align-items-start mb-4 flex-wrap gap-3 d-print-none">
      <div>
        <h1 class="h3 fw-bold mb-1">📋 Informe Semestral REPROCANN</h1>
        <p class="text-muted small mb-0">Resolución 1780/2025 — Declaración Jurada Semestral</p>
      </div>
      <div class="d-flex gap-2 flex-wrap align-items-end">
        <select class="form-select form-select-sm" v-model.number="semestre" style="width:auto">
          <option :value="1">1° Semestre (Ene–Jun)</option>
          <option :value="2">2° Semestre (Jul–Dic)</option>
        </select>
        <select class="form-select form-select-sm" v-model.number="anio" style="width:auto">
          <option v-for="y in anios" :key="y" :value="y">{{ y }}</option>
        </select>
        <button class="btn btn-primary btn-sm" :disabled="loading" @click="cargar">
          <span v-if="loading" class="spinner-border spinner-border-sm me-1"></span>
          Generar
        </button>
        <button v-if="informe" class="btn btn-outline-secondary btn-sm" @click="imprimir">
          🖨️ Imprimir / PDF
        </button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-primary"></div>
      <div class="mt-2 text-muted">Generando informe…</div>
    </div>
    <div v-else-if="error" class="alert alert-danger">{{ error }}</div>

    <template v-else-if="informe">

      <!-- ══════════════════════════════════════════════════════ -->
      <!-- ENCABEZADO DEL INFORME (imprimible)                   -->
      <!-- ══════════════════════════════════════════════════════ -->
      <div class="card border-0 shadow-sm mb-4">
        <div class="card-body">
          <div class="row align-items-center">
            <div class="col-md-8">
              <h2 class="h4 fw-bold mb-1">{{ informe.club.nombre_legal || informe.club.nombre }}</h2>
              <div class="text-muted small">
                <span v-if="informe.club.direccion">{{ informe.club.direccion }}, </span>
                <span v-if="informe.club.ciudad">{{ informe.club.ciudad }}</span>
                <span v-if="informe.club.provincia">, {{ informe.club.provincia }}</span>
              </div>
              <div class="text-muted small">
                <span v-if="informe.club.email">📧 {{ informe.club.email }}</span>
                <span v-if="informe.club.telefono"> · 📞 {{ informe.club.telefono }}</span>
              </div>
            </div>
            <div class="col-md-4 text-md-end mt-3 mt-md-0">
              <div class="badge text-bg-primary fs-6 mb-1">
                {{ informe.periodo.semestre }}° Semestre {{ informe.periodo.anio }}
              </div>
              <div class="small text-muted">
                {{ formatDateShort(informe.periodo.desde) }} al {{ formatDateShort(informe.periodo.hasta) }}
              </div>
              <div class="small text-muted mt-1">
                Generado por {{ informe.generado_por }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ── KPIs resumen ── -->
      <div class="row g-3 mb-4">
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100 text-center">
            <div class="card-body py-3">
              <div class="text-muted small">Socios REPROCANN</div>
              <div class="h2 fw-bold mb-0 text-primary">{{ informe.socios.con_reprocann }}</div>
              <div class="small text-muted">de {{ informe.socios.total }} totales</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100 text-center">
            <div class="card-body py-3">
              <div class="text-muted small">Plantas totales</div>
              <div class="h2 fw-bold mb-0 text-success">{{ informe.produccion.plantas_totales }}</div>
              <div class="small text-muted">{{ informe.produccion.plantas_en_floracion }} en floración</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100 text-center">
            <div class="card-body py-3">
              <div class="text-muted small">Dispensaciones</div>
              <div class="h2 fw-bold mb-0">{{ informe.dispensaciones.total }}</div>
              <div class="small text-muted">{{ informe.dispensaciones.total_gramos }}g dispensados</div>
            </div>
          </div>
        </div>
        <div class="col-6 col-md-3">
          <div class="card border-0 bg-body-secondary h-100 text-center">
            <div class="card-body py-3">
              <div class="text-muted small">Lotes en período</div>
              <div class="h2 fw-bold mb-0">{{ informe.produccion.lotes_periodo.length }}</div>
              <div class="small text-muted">{{ informe.produccion.salas_activas }} salas activas</div>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Alertas ── -->
      <div v-if="informe.socios.vencidos > 0 || informe.socios.por_vencer > 0" class="mb-4">
        <div v-if="informe.socios.vencidos > 0" class="alert alert-danger d-flex align-items-center gap-2">
          <span class="fs-5">❌</span>
          <strong>{{ informe.socios.vencidos }} socio(s) con permiso REPROCANN vencido</strong> — requieren renovación urgente.
        </div>
        <div v-if="informe.socios.por_vencer > 0" class="alert alert-warning d-flex align-items-center gap-2">
          <span class="fs-5">⚠️</span>
          <strong>{{ informe.socios.por_vencer }} socio(s) con permiso próximo a vencer</strong> — vencen en los próximos 30 días.
        </div>
      </div>

      <div class="row g-4">
        <div class="col-12 col-lg-8">

          <!-- ── Nómina de pacientes ── -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>👥 Nómina de pacientes vinculados</strong>
              <span class="badge text-bg-secondary">{{ informe.socios.total }}</span>
            </div>
            <div class="table-responsive">
              <table class="table table-sm table-hover align-middle mb-0">
                <thead class="table-light">
                <tr>
                  <th>Apellido y nombre</th>
                  <th>DNI</th>
                  <th>N° REPROCANN</th>
                  <th>Vencimiento</th>
                  <th>Estado</th>
                </tr>
                </thead>
                <tbody>
                <tr v-for="s in informe.socios.nomina" :key="s.dni">
                  <td class="small fw-semibold">{{ s.nombre_completo }}</td>
                  <td class="small font-monospace">{{ s.dni }}</td>
                  <td class="small font-monospace">{{ s.reprocann_numero }}</td>
                  <td class="small">{{ formatDateShort(s.reprocann_vencimiento) }}</td>
                  <td>
                      <span v-if="!s.reprocann_numero || s.reprocann_numero === '—'"
                            class="badge text-bg-secondary">Sin registro</span>
                    <span v-else-if="s.reprocann_vigente" class="badge text-bg-success">Vigente</span>
                    <span v-else class="badge text-bg-danger">Vencido</span>
                  </td>
                </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- ── Lotes del período ── -->
          <div class="card border-0 shadow-sm mb-4">
            <div class="card-header bg-transparent d-flex justify-content-between align-items-center">
              <strong>📦 Lotes del período</strong>
              <span class="badge text-bg-secondary">{{ informe.produccion.lotes_periodo.length }}</span>
            </div>
            <div class="table-responsive">
              <table class="table table-sm table-hover align-middle mb-0">
                <thead class="table-light">
                <tr>
                  <th>Código</th>
                  <th>Variedad</th>
                  <th>Sala</th>
                  <th>Estado</th>
                  <th>Plantas</th>
                  <th>Gramos prod.</th>
                  <th>Cromatog.</th>
                </tr>
                </thead>
                <tbody>
                <tr v-for="l in informe.produccion.lotes_periodo" :key="l.codigo">
                  <td class="small font-monospace fw-semibold">{{ l.codigo }}</td>
                  <td class="small">{{ l.strain || "—" }}</td>
                  <td class="small text-muted">{{ l.sala || "—" }}</td>
                  <td>
                      <span class="badge" :class="`text-bg-${estadoBadge(l.estado)}`">
                        {{ l.estado }}
                      </span>
                  </td>
                  <td class="small text-center">{{ l.plants_count ?? "—" }}</td>
                  <td class="small text-center">
                    {{ l.gramos_producidos ? `${l.gramos_producidos}g` : "—" }}
                  </td>
                  <td class="text-center">
                    <span v-if="l.tiene_cromatografico" class="text-success">✓</span>
                    <span v-else class="text-danger">✗</span>
                  </td>
                </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- ── Dispensaciones del período ── -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent">
              <strong>💊 Dispensaciones del período</strong>
            </div>
            <div class="card-body">
              <div class="row g-3">
                <div class="col-6 col-md-3 text-center">
                  <div class="text-muted small">Total dispensaciones</div>
                  <div class="h4 fw-bold mb-0">{{ informe.dispensaciones.total }}</div>
                </div>
                <div class="col-6 col-md-3 text-center">
                  <div class="text-muted small">Gramos totales</div>
                  <div class="h4 fw-bold mb-0">{{ informe.dispensaciones.total_gramos }}g</div>
                </div>
                <div class="col-6 col-md-3 text-center">
                  <div class="text-muted small">Socios atendidos</div>
                  <div class="h4 fw-bold mb-0">{{ informe.dispensaciones.socios_dispensados }}</div>
                </div>
                <div class="col-6 col-md-3 text-center">
                  <div class="text-muted small">Aportes recibidos</div>
                  <div class="h4 fw-bold mb-0 text-success">
                    ${{ informe.dispensaciones.aporte_total_ars.toLocaleString('es-AR') }}
                  </div>
                </div>
              </div>

              <div v-if="informe.dispensaciones.por_tipo_producto?.length" class="mt-3">
                <div class="small text-muted mb-2">Por tipo de producto:</div>
                <div class="d-flex flex-wrap gap-2">
                  <span v-for="t in informe.dispensaciones.por_tipo_producto" :key="t.tipo"
                        class="badge text-bg-secondary fs-6">
                    {{ t.tipo }}: {{ t.gramos }}g
                  </span>
                </div>
              </div>
            </div>
          </div>

        </div>

        <div class="col-12 col-lg-4">

          <!-- ── Estado de producción ── -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>🌿 Estado de producción</strong></div>
            <div class="card-body small">
              <dl class="row mb-0">
                <dt class="col-7 text-muted fw-normal">Plantas totales</dt>
                <dd class="col-5 text-end fw-semibold">{{ informe.produccion.plantas_totales }}</dd>

                <dt class="col-7 text-muted fw-normal">En floración</dt>
                <dd class="col-5 text-end fw-semibold text-warning">{{ informe.produccion.plantas_en_floracion }}</dd>

                <dt class="col-7 text-muted fw-normal">En vegetativo</dt>
                <dd class="col-5 text-end fw-semibold text-success">{{ informe.produccion.plantas_en_vegetativo }}</dd>

                <dt class="col-7 text-muted fw-normal">En secado</dt>
                <dd class="col-5 text-end fw-semibold text-secondary">{{ informe.produccion.plantas_en_secado }}</dd>

                <dt class="col-7 text-muted fw-normal">Salas activas</dt>
                <dd class="col-5 text-end mb-0">{{ informe.produccion.salas_activas }}</dd>
              </dl>
            </div>
          </div>

          <!-- ── Genéticas ── -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>🧬 Variedades genéticas activas</strong></div>
            <div class="card-body p-0">
              <div v-if="!informe.resumen_geneticas?.length" class="p-3 text-muted small">
                Sin genéticas registradas.
              </div>
              <div v-else class="list-group list-group-flush">
                <div v-for="g in informe.resumen_geneticas" :key="g.nombre"
                     class="list-group-item px-3 py-2 small">
                  <div class="d-flex justify-content-between align-items-center">
                    <div>
                      <span class="fw-semibold">{{ g.nombre }}</span>
                      <span class="text-muted ms-1">{{ g.tipo }}</span>
                    </div>
                    <span class="badge text-bg-success">{{ g.plantas_activas }} plantas</span>
                  </div>
                  <div v-if="g.thc || g.cbd" class="text-muted mt-1">
                    <span v-if="g.thc">THC: {{ g.thc }}%</span>
                    <span v-if="g.thc && g.cbd"> · </span>
                    <span v-if="g.cbd">CBD: {{ g.cbd }}%</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- ── Sedes REPROCANN ── -->
          <div class="card border-0 shadow-sm mb-3">
            <div class="card-header bg-transparent"><strong>🏢 Sedes declaradas REPROCANN</strong></div>
            <div class="card-body p-0">
              <div v-if="!informe.club.sedes_reprocann?.length" class="p-3 text-muted small">
                Sin sedes declaradas.
              </div>
              <div v-else class="list-group list-group-flush">
                <div v-for="s in informe.club.sedes_reprocann" :key="s.nombre"
                     class="list-group-item px-3 py-2 small">
                  <div class="fw-semibold">{{ s.nombre }}</div>
                  <div class="text-muted">{{ s.tipo }} · {{ s.direccion }}</div>
                </div>
              </div>
            </div>
          </div>

          <!-- ── Estado REPROCANN socios ── -->
          <div class="card border-0 shadow-sm">
            <div class="card-header bg-transparent"><strong>📊 Estado REPROCANN socios</strong></div>
            <div class="card-body small">
              <dl class="row mb-0">
                <dt class="col-8 text-muted fw-normal">Total socios</dt>
                <dd class="col-4 text-end">{{ informe.socios.total }}</dd>

                <dt class="col-8 text-muted fw-normal">Con REPROCANN</dt>
                <dd class="col-4 text-end text-success fw-semibold">{{ informe.socios.con_reprocann }}</dd>

                <dt class="col-8 text-muted fw-normal">Sin REPROCANN</dt>
                <dd class="col-4 text-end text-warning">{{ informe.socios.sin_reprocann }}</dd>

                <dt class="col-8 text-muted fw-normal">Vencidos</dt>
                <dd class="col-4 text-end text-danger">{{ informe.socios.vencidos }}</dd>

                <dt class="col-8 text-muted fw-normal">Por vencer (30d)</dt>
                <dd class="col-4 text-end text-warning mb-0">{{ informe.socios.por_vencer }}</dd>
              </dl>
            </div>
          </div>

        </div>
      </div>

      <!-- Pie de página -->
      <div class="card border-0 bg-body-secondary mt-4">
        <div class="card-body py-2 small text-muted text-center">
          Informe generado el {{ formatDate(informe.generado_en) }} por {{ informe.generado_por }} ·
          En cumplimiento de la Resolución Ministerial N° 1780/2025 (REPROCANN)
        </div>
      </div>

    </template>

  </div>
</template>

<style>
@media print {
  .d-print-none { display: none !important; }
  .card { border: 1px solid #dee2e6 !important; box-shadow: none !important; }
  .container-fluid { padding: 0 !important; }
  body { font-size: 12px; }
}
</style>
