<script setup>
import { ref, computed, onMounted, nextTick } from "vue"
import html2pdf from 'html2pdf.js'
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

const periodoLabel = computed(() => {
  if (!informe.value) return ''
  const s = informe.value.periodo.semestre
  const a = informe.value.periodo.anio
  return `${s}° Semestre ${a} — ${s === 1 ? 'Enero a Junio' : 'Julio a Diciembre'}`
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

function estadoMeta(estado) {
  return {
    semilla:    { label: "Semilla",    color: "#64748b", bg: "rgba(100,116,139,.1)" },
    vegetativo: { label: "Vegetativo", color: "#15803d", bg: "rgba(21,128,61,.1)"  },
    floracion:  { label: "Floración",  color: "#d97706", bg: "rgba(217,119,6,.1)"  },
    secado:     { label: "Secado",     color: "#475569", bg: "rgba(71,85,105,.1)"  },
    cosechado:  { label: "Cosechado",  color: "#0369a1", bg: "rgba(3,105,161,.1)"  },
    finalizado: { label: "Finalizado", color: "#1b5e20", bg: "rgba(27,94,32,.1)"   },
  }[estado] || { label: estado, color: "#64748b", bg: "rgba(100,116,139,.1)" }
}

function vigenciaMeta(socio) {
  if (!socio.reprocann_numero || socio.reprocann_numero === '—')
    return { label: 'Sin registro', color: '#475569', bg: 'rgba(71,85,105,.1)' }
  if (socio.reprocann_vigente)
    return { label: 'Vigente', color: '#15803d', bg: 'rgba(21,128,61,.1)' }
  return { label: 'Vencido', color: '#dc2626', bg: 'rgba(220,38,38,.1)' }
}

const generandoPDF = ref(false)

async function descargarPDF() {
  generandoPDF.value = true
  await nextTick()
  const el = document.getElementById('ir-contenido')
  const semestre = informe.value?.periodo?.semestre || ''
  const anio = informe.value?.periodo?.anio || ''
  const club = informe.value?.club?.nombre_legal || informe.value?.club?.nombre || 'Club'
  const filename = `REPROCANN_${semestre}S_${anio}_${club.replace(/\s+/g, '_')}.pdf`
  const opt = {
    margin:       [10, 10, 10, 10],
    filename,
    image:        { type: 'jpeg', quality: 0.95 },
    html2canvas:  { scale: 2, useCORS: true, letterRendering: true },
    jsPDF:        { unit: 'mm', format: 'a4', orientation: 'portrait' },
    pagebreak:    { mode: ['avoid-all', 'css', 'legacy'] },
  }
  try {
    await html2pdf().set(opt).from(el).save()
  } finally {
    generandoPDF.value = false
  }
}

onMounted(() => cargar())
</script>

<template>
  <div class="ir">

    <!-- ── Controles (no imprimibles) ── -->
    <div class="ir__controls d-print-none">
      <div class="ir__controls-left">
        <div class="ir__controls-title">Informe Semestral REPROCANN</div>
        <div class="ir__controls-sub">Resolución Ministerial N° 1780/2025 · Declaración Jurada Semestral</div>
      </div>
      <div class="ir__controls-right">
        <select class="ir__select" v-model.number="semestre">
          <option :value="1">1° Semestre — Ene / Jun</option>
          <option :value="2">2° Semestre — Jul / Dic</option>
        </select>
        <select class="ir__select" v-model.number="anio">
          <option v-for="y in anios" :key="y" :value="y">{{ y }}</option>
        </select>
        <button class="ir__btn-primary" :disabled="loading" @click="cargar">
          <div v-if="loading" class="ir__spin"></div>
          <i v-else class="bi bi-arrow-clockwise"></i>
          Generar
        </button>
        <button v-if="informe" class="ir__btn-download" :disabled="generandoPDF" @click="descargarPDF">
          <div v-if="generandoPDF" class="ir__spin"></div>
          <i v-else class="bi bi-file-earmark-pdf"></i>
          {{ generandoPDF ? 'Generando PDF...' : 'Descargar PDF' }}
        </button>
      </div>
    </div>

    <!-- ── Loading ── -->
    <div v-if="loading" class="ir__loading">
      <div class="ir__ring"></div>
      <span>Generando informe…</span>
    </div>
    <div v-else-if="error" class="ir__error">{{ error }}</div>

    <template v-else-if="informe">
      <div id="ir-contenido">

        <!-- ════════════════════════════════════════════════════════
             PORTADA DEL INFORME
             ════════════════════════════════════════════════════════ -->
        <div class="ir__portada">
          <div class="ir__portada-header">
            <div class="ir__portada-logo">
              <div class="ir__portada-logo-icon"><i class="bi bi-patch-check-fill"></i></div>
              <div>
                <div class="ir__portada-logo-text">REPROCANN</div>
                <div class="ir__portada-logo-sub">Programa Nacional</div>
              </div>
            </div>
            <div class="ir__portada-badge">
              <div class="ir__portada-semestre">{{ informe.periodo.semestre }}° Semestre</div>
              <div class="ir__portada-anio">{{ informe.periodo.anio }}</div>
            </div>
          </div>

          <div class="ir__portada-body">
            <div class="ir__portada-club">
              <h2 class="ir__portada-nombre">{{ informe.club.nombre_legal || informe.club.nombre }}</h2>
              <div class="ir__portada-meta">
                <span v-if="informe.club.direccion"><i class="bi bi-geo-alt"></i> {{ informe.club.direccion }}<span v-if="informe.club.ciudad">, {{ informe.club.ciudad }}</span><span v-if="informe.club.provincia">, {{ informe.club.provincia }}</span></span>
                <span v-if="informe.club.email"><i class="bi bi-envelope"></i> {{ informe.club.email }}</span>
                <span v-if="informe.club.telefono"><i class="bi bi-telephone"></i> {{ informe.club.telefono }}</span>
              </div>
            </div>
            <div class="ir__portada-periodo">
              <div class="ir__portada-periodo-label">Período declarado</div>
              <div class="ir__portada-periodo-val">{{ periodoLabel }}</div>
              <div class="ir__portada-periodo-fechas">{{ formatDateShort(informe.periodo.desde) }} al {{ formatDateShort(informe.periodo.hasta) }}</div>
              <div class="ir__portada-generado">Generado el {{ formatDate(informe.generado_en) }} por {{ informe.generado_por }}</div>
            </div>
          </div>
        </div>

        <!-- ── Alertas ── -->
        <div v-if="informe.socios.vencidos > 0 || informe.socios.por_vencer > 0" class="ir__alertas d-print-none">
          <div v-if="informe.socios.vencidos > 0" class="ir__alerta ir__alerta--danger">
            <i class="bi bi-x-circle-fill"></i>
            <div>
              <strong>{{ informe.socios.vencidos }} paciente{{ informe.socios.vencidos > 1 ? 's' : '' }} con autorización REPROCANN vencida</strong>
              <span>— Requieren renovación urgente ante ANMAT.</span>
            </div>
          </div>
          <div v-if="informe.socios.por_vencer > 0" class="ir__alerta ir__alerta--warn">
            <i class="bi bi-exclamation-triangle-fill"></i>
            <div>
              <strong>{{ informe.socios.por_vencer }} paciente{{ informe.socios.por_vencer > 1 ? 's' : '' }} con autorización próxima a vencer</strong>
              <span>— Vencen en los próximos 30 días.</span>
            </div>
          </div>
        </div>

        <!-- ── KPIs resumen ── -->
        <div class="ir__kpis">
          <div class="ir__kpi">
            <div class="ir__kpi-icon ir__kpi-icon--blue"><i class="bi bi-people-fill"></i></div>
            <div class="ir__kpi-val">{{ informe.socios.con_reprocann }}</div>
            <div class="ir__kpi-label">Pacientes REPROCANN</div>
            <div class="ir__kpi-sub">{{ informe.socios.total }} socios en total</div>
          </div>
          <div class="ir__kpi">
            <div class="ir__kpi-icon ir__kpi-icon--green"><i class="bi bi-flower1"></i></div>
            <div class="ir__kpi-val">{{ informe.produccion.plantas_totales }}</div>
            <div class="ir__kpi-label">Plantas totales</div>
            <div class="ir__kpi-sub">{{ informe.produccion.plantas_en_floracion }} en floración</div>
          </div>
          <div class="ir__kpi">
            <div class="ir__kpi-icon ir__kpi-icon--amber"><i class="bi bi-box-seam"></i></div>
            <div class="ir__kpi-val">{{ informe.produccion.lotes_periodo.length }}</div>
            <div class="ir__kpi-label">Lotes del período</div>
            <div class="ir__kpi-sub">{{ informe.produccion.salas_activas }} salas activas</div>
          </div>
          <div class="ir__kpi">
            <div class="ir__kpi-icon ir__kpi-icon--teal"><i class="bi bi-capsule"></i></div>
            <div class="ir__kpi-val">{{ informe.dispensaciones.total }}</div>
            <div class="ir__kpi-label">Dispensaciones</div>
            <div class="ir__kpi-sub">{{ informe.dispensaciones.total_gramos }}g dispensados</div>
          </div>
        </div>

        <!-- ── Layout principal ── -->
        <div class="ir__layout">
          <div class="ir__main">

            <!-- SECCIÓN 1: Nómina de pacientes -->
            <div class="ir__section">
              <div class="ir__section-header">
                <div class="ir__section-num">1</div>
                <div>
                  <div class="ir__section-title">Nómina de pacientes vinculados</div>
                  <div class="ir__section-desc">Pacientes con autorización REPROCANN registrada en el club</div>
                </div>
                <span class="ir__badge">{{ informe.socios.total }}</span>
              </div>
              <div class="ir__table-wrap">
                <table class="ir__table">
                  <thead>
                  <tr>
                    <th>#</th>
                    <th>Apellido y nombre</th>
                    <th>DNI</th>
                    <th>N° Autorización REPROCANN</th>
                    <th>Vencimiento</th>
                    <th>Estado</th>
                  </tr>
                  </thead>
                  <tbody>
                  <tr v-for="(s, i) in informe.socios.nomina" :key="s.dni">
                    <td class="ir__td-num">{{ i + 1 }}</td>
                    <td class="ir__td-nombre">{{ s.nombre_completo }}</td>
                    <td class="ir__td-mono">{{ s.dni }}</td>
                    <td class="ir__td-mono">{{ s.reprocann_numero || '—' }}</td>
                    <td class="ir__td-fecha">{{ formatDateShort(s.reprocann_vencimiento) }}</td>
                    <td>
                      <span class="ir__pill"
                            :style="{ background: vigenciaMeta(s).bg, color: vigenciaMeta(s).color }">
                        {{ vigenciaMeta(s).label }}
                      </span>
                    </td>
                  </tr>
                  </tbody>
                </table>
              </div>
              <!-- Resumen REPROCANN -->
              <div class="ir__section-footer">
                <div class="ir__stat"><span class="ir__stat-val ir__stat-val--green">{{ informe.socios.con_reprocann }}</span><span class="ir__stat-label">Con autorización</span></div>
                <div class="ir__stat"><span class="ir__stat-val ir__stat-val--amber">{{ informe.socios.sin_reprocann }}</span><span class="ir__stat-label">Sin registro</span></div>
                <div class="ir__stat"><span class="ir__stat-val" :style="{ color: informe.socios.vencidos > 0 ? '#dc2626' : '#94a3b8' }">{{ informe.socios.vencidos }}</span><span class="ir__stat-label">Vencidos</span></div>
                <div class="ir__stat"><span class="ir__stat-val" :style="{ color: informe.socios.por_vencer > 0 ? '#d97706' : '#94a3b8' }">{{ informe.socios.por_vencer }}</span><span class="ir__stat-label">Por vencer (30d)</span></div>
              </div>
            </div>

            <!-- SECCIÓN 2: Producción — lotes del período -->
            <div class="ir__section ir__section--mt">
              <div class="ir__section-header">
                <div class="ir__section-num">2</div>
                <div>
                  <div class="ir__section-title">Producción del período</div>
                  <div class="ir__section-desc">Lotes activos y finalizados durante el semestre declarado</div>
                </div>
                <span class="ir__badge">{{ informe.produccion.lotes_periodo.length }}</span>
              </div>
              <div class="ir__table-wrap">
                <table class="ir__table">
                  <thead>
                  <tr>
                    <th>Código</th>
                    <th>Variedad / Genética</th>
                    <th>Sala</th>
                    <th>Estado</th>
                    <th class="ir__th-center">Plantas</th>
                    <th class="ir__th-center">Gramos prod.</th>
                    <th class="ir__th-center">Cromatog.</th>
                  </tr>
                  </thead>
                  <tbody>
                  <tr v-for="l in informe.produccion.lotes_periodo" :key="l.codigo">
                    <td class="ir__td-mono ir__td-bold">{{ l.codigo }}</td>
                    <td>{{ l.strain || '—' }}</td>
                    <td class="ir__td-muted">{{ l.sala || '—' }}</td>
                    <td>
                      <span class="ir__pill"
                            :style="{ background: estadoMeta(l.estado).bg, color: estadoMeta(l.estado).color }">
                        {{ estadoMeta(l.estado).label }}
                      </span>
                    </td>
                    <td class="ir__td-center">{{ l.plants_count ?? '—' }}</td>
                    <td class="ir__td-center">{{ l.gramos_producidos ? `${l.gramos_producidos}g` : '—' }}</td>
                    <td class="ir__td-center">
                      <span v-if="l.tiene_cromatografico" style="color:#15803d;font-size:1rem">✓</span>
                      <span v-else style="color:#cbd5e1;font-size:1rem">—</span>
                    </td>
                  </tr>
                  </tbody>
                </table>
              </div>
              <!-- Resumen producción -->
              <div class="ir__section-footer">
                <div class="ir__stat"><span class="ir__stat-val ir__stat-val--green">{{ informe.produccion.plantas_en_vegetativo }}</span><span class="ir__stat-label">En vegetativo</span></div>
                <div class="ir__stat"><span class="ir__stat-val ir__stat-val--amber">{{ informe.produccion.plantas_en_floracion }}</span><span class="ir__stat-label">En floración</span></div>
                <div class="ir__stat"><span class="ir__stat-val">{{ informe.produccion.plantas_en_secado }}</span><span class="ir__stat-label">En secado</span></div>
                <div class="ir__stat"><span class="ir__stat-val ir__stat-val--blue">{{ informe.produccion.plantas_totales }}</span><span class="ir__stat-label">Total plantas</span></div>
              </div>
            </div>

            <!-- SECCIÓN 3: Dispensaciones -->
            <div class="ir__section ir__section--mt">
              <div class="ir__section-header">
                <div class="ir__section-num">3</div>
                <div>
                  <div class="ir__section-title">Dispensaciones del período</div>
                  <div class="ir__section-desc">Registro de entregas realizadas a pacientes habilitados</div>
                </div>
              </div>
              <div class="ir__disp-grid">
                <div class="ir__disp-kpi">
                  <div class="ir__disp-kpi-val">{{ informe.dispensaciones.total }}</div>
                  <div class="ir__disp-kpi-label">Total de dispensaciones</div>
                </div>
                <div class="ir__disp-kpi">
                  <div class="ir__disp-kpi-val ir__disp-kpi-val--green">{{ informe.dispensaciones.total_gramos }}g</div>
                  <div class="ir__disp-kpi-label">Gramos entregados</div>
                </div>
                <div class="ir__disp-kpi">
                  <div class="ir__disp-kpi-val">{{ informe.dispensaciones.socios_dispensados }}</div>
                  <div class="ir__disp-kpi-label">Pacientes atendidos</div>
                </div>
                <div class="ir__disp-kpi">
                  <div class="ir__disp-kpi-val ir__disp-kpi-val--green">
                    ${{ (informe.dispensaciones.aporte_total_ars || 0).toLocaleString('es-AR') }}
                  </div>
                  <div class="ir__disp-kpi-label">Aportes recibidos (ARS)</div>
                </div>
              </div>
              <div v-if="informe.dispensaciones.por_tipo_producto?.length" class="ir__disp-tipos">
                <div class="ir__disp-tipos-label">Por tipo de producto:</div>
                <div class="ir__disp-tipos-list">
                <span v-for="t in informe.dispensaciones.por_tipo_producto" :key="t.tipo" class="ir__tipo-tag">
                  {{ t.tipo }}: <strong>{{ t.gramos }}g</strong>
                </span>
                </div>
              </div>
              <div v-else class="ir__empty-sm">Sin dispensaciones registradas en el período.</div>
            </div>

          </div>

          <!-- ── Aside ── -->
          <div class="ir__aside">

            <!-- Estado de producción -->
            <div class="ir__aside-card">
              <div class="ir__aside-title">
                <i class="bi bi-bar-chart-fill" style="color:#1b5e20"></i>
                Estado de producción
              </div>
              <div class="ir__prod-bars">
                <div class="ir__prod-row">
                  <span class="ir__prod-label">Vegetativo</span>
                  <div class="ir__prod-bar-wrap">
                    <div class="ir__prod-bar" style="background:#15803d"
                         :style="{ width: informe.produccion.plantas_totales ? (informe.produccion.plantas_en_vegetativo / informe.produccion.plantas_totales * 100) + '%' : '0%' }">
                    </div>
                  </div>
                  <span class="ir__prod-val">{{ informe.produccion.plantas_en_vegetativo }}</span>
                </div>
                <div class="ir__prod-row">
                  <span class="ir__prod-label">Floración</span>
                  <div class="ir__prod-bar-wrap">
                    <div class="ir__prod-bar" style="background:#d97706"
                         :style="{ width: informe.produccion.plantas_totales ? (informe.produccion.plantas_en_floracion / informe.produccion.plantas_totales * 100) + '%' : '0%' }">
                    </div>
                  </div>
                  <span class="ir__prod-val">{{ informe.produccion.plantas_en_floracion }}</span>
                </div>
                <div class="ir__prod-row">
                  <span class="ir__prod-label">Secado</span>
                  <div class="ir__prod-bar-wrap">
                    <div class="ir__prod-bar" style="background:#475569"
                         :style="{ width: informe.produccion.plantas_totales ? (informe.produccion.plantas_en_secado / informe.produccion.plantas_totales * 100) + '%' : '0%' }">
                    </div>
                  </div>
                  <span class="ir__prod-val">{{ informe.produccion.plantas_en_secado }}</span>
                </div>
              </div>
              <div class="ir__prod-total">
                <span>Total plantas</span>
                <strong>{{ informe.produccion.plantas_totales }}</strong>
              </div>
            </div>

            <!-- Variedades genéticas -->
            <div class="ir__aside-card ir__aside-card--mt">
              <div class="ir__aside-title">
                <i class="bi bi-diagram-3-fill" style="color:#7c3aed"></i>
                Variedades genéticas activas
              </div>
              <div v-if="!informe.resumen_geneticas?.length" class="ir__empty-sm">Sin genéticas activas.</div>
              <div v-else class="ir__gen-list">
                <div v-for="g in informe.resumen_geneticas" :key="g.nombre" class="ir__gen-item">
                  <div class="ir__gen-info">
                    <div class="ir__gen-nombre">{{ g.nombre }}</div>
                    <div class="ir__gen-tipo">{{ g.tipo }}<span v-if="g.thc || g.cbd"> · <span v-if="g.thc">THC {{ g.thc }}%</span><span v-if="g.thc && g.cbd"> · </span><span v-if="g.cbd">CBD {{ g.cbd }}%</span></span></div>
                  </div>
                  <div class="ir__gen-plantas">{{ g.plantas_activas }}<span class="ir__gen-plantas-label">pl.</span></div>
                </div>
              </div>
            </div>

            <!-- Sedes REPROCANN -->
            <div class="ir__aside-card ir__aside-card--mt">
              <div class="ir__aside-title">
                <i class="bi bi-building-check" style="color:#0369a1"></i>
                Sedes declaradas REPROCANN
              </div>
              <div v-if="!informe.club.sedes_reprocann?.length" class="ir__empty-sm">Sin sedes declaradas.</div>
              <div v-else class="ir__sedes-list">
                <div v-for="s in informe.club.sedes_reprocann" :key="s.nombre" class="ir__sede-item">
                  <div class="ir__sede-nombre">{{ s.nombre }}</div>
                  <div class="ir__sede-meta">{{ s.tipo }} · {{ s.direccion }}</div>
                </div>
              </div>
            </div>

            <!-- Estado REPROCANN -->
            <div class="ir__aside-card ir__aside-card--mt">
              <div class="ir__aside-title">
                <i class="bi bi-shield-check" style="color:#15803d"></i>
                Estado REPROCANN
              </div>
              <div class="ir__repro-list">
                <div class="ir__repro-row">
                  <span>Total socios</span>
                  <strong>{{ informe.socios.total }}</strong>
                </div>
                <div class="ir__repro-row">
                  <span>Con autorización</span>
                  <strong style="color:#15803d">{{ informe.socios.con_reprocann }}</strong>
                </div>
                <div class="ir__repro-row">
                  <span>Sin registro</span>
                  <strong style="color:#64748b">{{ informe.socios.sin_reprocann }}</strong>
                </div>
                <div class="ir__repro-row">
                  <span>Autorizaciones vencidas</span>
                  <strong :style="{ color: informe.socios.vencidos > 0 ? '#dc2626' : '#94a3b8' }">{{ informe.socios.vencidos }}</strong>
                </div>
                <div class="ir__repro-row">
                  <span>Por vencer (30 días)</span>
                  <strong :style="{ color: informe.socios.por_vencer > 0 ? '#d97706' : '#94a3b8' }">{{ informe.socios.por_vencer }}</strong>
                </div>
              </div>
            </div>

          </div>
        </div>

        <!-- ── Pie legal ── -->
        <div class="ir__pie">
          <div class="ir__pie-text">
            Declaración Jurada Semestral conforme Resolución Ministerial N° 1780/2025 (REPROCANN) ·
            Generado el {{ formatDate(informe.generado_en) }} por {{ informe.generado_por }} ·
            {{ informe.club.nombre_legal || informe.club.nombre }}
          </div>
          <div class="ir__pie-firma">
            <div class="ir__firma-linea"></div>
            <div class="ir__firma-texto">Firma y sello del responsable legal</div>
          </div>
        </div>

      </div><!-- fin ir-contenido -->
    </template>

  </div>
</template>

<style scoped>
.ir { padding: 2rem 1.75rem 3rem; max-width: 1280px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #0f172a; }
@media (max-width: 768px) { .ir { padding: 1.25rem 1rem 2rem; } }

/* Controles */
.ir__controls { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.ir__controls-title { font-size: 1.3rem; font-weight: 800; color: #0f172a; letter-spacing: -.04em; }
.ir__controls-sub { font-size: .78rem; color: #64748b; margin-top: .1rem; }
.ir__controls-right { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }

.ir__select { background: #fff; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .55rem .875rem; font-size: .82rem; color: #0f172a; outline: none; cursor: pointer; }
.ir__select:focus { border-color: #1b5e20; }

.ir__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.ir__btn-primary:hover:not(:disabled) { background: #144a18; }
.ir__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.ir__btn-ghost { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 9px; font-size: .82rem; font-weight: 500; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ir__btn-ghost:hover { background: #f8fafc; color: #0f172a; }

.ir__spin { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.3); border-top-color: #fff; border-radius: 50%; animation: ir-spin .7s linear infinite; }
@keyframes ir-spin { to { transform: rotate(360deg); } }

/* Loading / Error */
.ir__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; }
.ir__ring { width: 24px; height: 24px; border: 2px solid #e2e8f0; border-top-color: #1b5e20; border-radius: 50%; animation: ir-spin .7s linear infinite; }
.ir__error { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: 1rem 1.25rem; border-radius: 10px; }

/* Portada */
.ir__portada { background: linear-gradient(135deg, #1b5e20, #2d7a35); border-radius: 18px; overflow: hidden; margin-bottom: 1.5rem; color: #fff; }
.ir__portada-header { display: flex; align-items: center; justify-content: space-between; padding: 1.5rem 2rem; border-bottom: 1px solid rgba(255,255,255,.12); }
.ir__portada-logo { display: flex; align-items: center; gap: .75rem; }
.ir__portada-logo-icon { width: 44px; height: 44px; background: rgba(255,255,255,.15); border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; }
.ir__portada-logo-text { font-size: 1rem; font-weight: 800; letter-spacing: .06em; }
.ir__portada-logo-sub { font-size: .7rem; color: rgba(255,255,255,.6); font-weight: 500; }
.ir__portada-badge { text-align: right; }
.ir__portada-semestre { font-size: .75rem; color: rgba(255,255,255,.7); font-weight: 600; text-transform: uppercase; letter-spacing: .06em; }
.ir__portada-anio { font-size: 2rem; font-weight: 900; letter-spacing: -.04em; line-height: 1; }
.ir__portada-body { display: grid; grid-template-columns: 1fr auto; gap: 2rem; padding: 1.75rem 2rem; align-items: end; }
@media (max-width: 640px) { .ir__portada-body { grid-template-columns: 1fr; } }
.ir__portada-nombre { font-size: 1.35rem; font-weight: 800; margin: 0 0 .5rem; letter-spacing: -.03em; }
.ir__portada-meta { display: flex; flex-direction: column; gap: .25rem; font-size: .8rem; color: rgba(255,255,255,.75); }
.ir__portada-meta span { display: flex; align-items: center; gap: .4rem; }
.ir__portada-periodo { text-align: right; }
@media (max-width: 640px) { .ir__portada-periodo { text-align: left; } }
.ir__portada-periodo-label { font-size: .65rem; text-transform: uppercase; letter-spacing: .08em; color: rgba(255,255,255,.55); margin-bottom: .25rem; }
.ir__portada-periodo-val { font-size: .95rem; font-weight: 700; }
.ir__portada-periodo-fechas { font-size: .75rem; color: rgba(255,255,255,.7); margin-top: .15rem; }
.ir__portada-generado { font-size: .7rem; color: rgba(255,255,255,.5); margin-top: .6rem; }

/* Alertas */
.ir__alertas { display: flex; flex-direction: column; gap: .6rem; margin-bottom: 1.5rem; }
.ir__alerta { display: flex; align-items: flex-start; gap: .75rem; padding: .875rem 1.1rem; border-radius: 12px; font-size: .85rem; line-height: 1.5; }
.ir__alerta--danger { background: #fef2f2; border: 1px solid #fecaca; color: #7f1d1d; }
.ir__alerta--danger i { color: #dc2626; font-size: 1.1rem; flex-shrink: 0; margin-top: .1rem; }
.ir__alerta--warn { background: #fffbeb; border: 1px solid #fde68a; color: #78350f; }
.ir__alerta--warn i { color: #d97706; font-size: 1.1rem; flex-shrink: 0; margin-top: .1rem; }

/* KPIs */
.ir__kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; margin-bottom: 1.75rem; }
@media (max-width: 900px) { .ir__kpis { grid-template-columns: 1fr 1fr; } }
@media (max-width: 480px) { .ir__kpis { grid-template-columns: 1fr; } }
.ir__kpi { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; padding: 1.25rem; display: flex; flex-direction: column; gap: .25rem; }
.ir__kpi-icon { width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 1rem; margin-bottom: .4rem; }
.ir__kpi-icon--blue  { background: rgba(3,105,161,.1);  color: #0369a1; }
.ir__kpi-icon--green { background: rgba(21,128,61,.1);  color: #15803d; }
.ir__kpi-icon--amber { background: rgba(217,119,6,.1);  color: #d97706; }
.ir__kpi-icon--teal  { background: rgba(8,145,178,.1);  color: #0891b2; }
.ir__kpi-val   { font-size: 1.75rem; font-weight: 900; letter-spacing: -.04em; color: #0f172a; }
.ir__kpi-label { font-size: .78rem; font-weight: 700; color: #374151; }
.ir__kpi-sub   { font-size: .72rem; color: #64748b; }

/* Layout */
.ir__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.25rem; align-items: start; }
@media (max-width: 1000px) { .ir__layout { grid-template-columns: 1fr; } }
.ir__main { display: flex; flex-direction: column; }

/* Secciones */
.ir__section { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.ir__section--mt { margin-top: 1.25rem; }
.ir__section-header { display: flex; align-items: center; gap: .875rem; padding: 1rem 1.25rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; flex-wrap: wrap; gap: .65rem; }
.ir__section-num { width: 28px; height: 28px; border-radius: 8px; background: #1b5e20; color: #fff; display: flex; align-items: center; justify-content: center; font-size: .8rem; font-weight: 800; flex-shrink: 0; }
.ir__section-title { font-size: .9rem; font-weight: 700; color: #0f172a; }
.ir__section-desc { font-size: .72rem; color: #64748b; margin-top: .05rem; }
.ir__badge { background: #e8f5e9; color: #1b5e20; font-size: .7rem; font-weight: 700; padding: .2em .65em; border-radius: 6px; margin-left: auto; flex-shrink: 0; }

/* Tabla */
.ir__table-wrap { overflow-x: auto; }
.ir__table { width: 100%; border-collapse: collapse; font-size: .8rem; }
.ir__table th { padding: .65rem 1rem; font-size: .67rem; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: .05em; border-bottom: 1.5px solid #f1f5f9; background: #fafbfc; white-space: nowrap; }
.ir__table td { padding: .7rem 1rem; border-bottom: 1px solid #f8fafc; vertical-align: middle; }
.ir__table tbody tr:last-child td { border-bottom: none; }
.ir__table tbody tr:hover td { background: #fafbfc; }
.ir__th-center { text-align: center; }
.ir__td-num    { color: #94a3b8; font-size: .72rem; font-weight: 600; width: 32px; }
.ir__td-nombre { font-weight: 600; color: #0f172a; }
.ir__td-mono   { font-family: monospace; font-size: .78rem; color: #475569; }
.ir__td-fecha  { color: #64748b; font-size: .78rem; white-space: nowrap; }
.ir__td-muted  { color: #64748b; }
.ir__td-bold   { font-weight: 700; }
.ir__td-center { text-align: center; }

/* Pill */
.ir__pill { display: inline-flex; align-items: center; font-size: .67rem; font-weight: 700; padding: .22em .7em; border-radius: 6px; white-space: nowrap; }

/* Section footer stats */
.ir__section-footer { display: flex; gap: 0; border-top: 1.5px solid #f1f5f9; background: #fafbfc; }
.ir__stat { flex: 1; text-align: center; padding: .875rem; border-right: 1px solid #f1f5f9; }
.ir__stat:last-child { border-right: none; }
.ir__stat-val { display: block; font-size: 1.35rem; font-weight: 800; color: #0f172a; letter-spacing: -.03em; }
.ir__stat-val--green { color: #15803d; }
.ir__stat-val--amber { color: #d97706; }
.ir__stat-val--blue  { color: #0369a1; }
.ir__stat-label { display: block; font-size: .65rem; color: #64748b; font-weight: 500; text-transform: uppercase; letter-spacing: .04em; margin-top: .15rem; }

/* Dispensaciones */
.ir__disp-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1px; background: #f1f5f9; border-top: 1px solid #f1f5f9; }
@media (max-width: 640px) { .ir__disp-grid { grid-template-columns: 1fr 1fr; } }
.ir__disp-kpi { background: #fff; padding: 1.25rem; text-align: center; }
.ir__disp-kpi-val { font-size: 1.5rem; font-weight: 800; letter-spacing: -.03em; color: #0f172a; }
.ir__disp-kpi-val--green { color: #15803d; }
.ir__disp-kpi-label { font-size: .72rem; color: #64748b; margin-top: .25rem; }
.ir__disp-tipos { padding: .875rem 1.25rem; border-top: 1px solid #f1f5f9; display: flex; align-items: center; gap: .65rem; flex-wrap: wrap; }
.ir__disp-tipos-label { font-size: .72rem; color: #64748b; font-weight: 600; }
.ir__disp-tipos-list { display: flex; gap: .5rem; flex-wrap: wrap; }
.ir__tipo-tag { background: #f1f5f9; color: #374151; font-size: .75rem; padding: .2em .65em; border-radius: 6px; }
.ir__empty-sm { padding: 1.5rem; text-align: center; color: #94a3b8; font-size: .82rem; }

/* Aside */
.ir__aside { display: flex; flex-direction: column; position: sticky; top: 1.5rem; }
.ir__aside-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 14px; overflow: hidden; }
.ir__aside-card--mt { margin-top: 1rem; }
.ir__aside-title { display: flex; align-items: center; gap: .5rem; font-size: .82rem; font-weight: 700; color: #0f172a; padding: .875rem 1.1rem; border-bottom: 1px solid #f1f5f9; background: #fafbfc; }

/* Producción barras */
.ir__prod-bars { padding: .875rem 1.1rem; display: flex; flex-direction: column; gap: .7rem; }
.ir__prod-row { display: grid; grid-template-columns: 70px 1fr 32px; align-items: center; gap: .5rem; }
.ir__prod-label { font-size: .72rem; color: #64748b; }
.ir__prod-bar-wrap { background: #f1f5f9; border-radius: 999px; height: 6px; overflow: hidden; }
.ir__prod-bar { height: 100%; border-radius: 999px; transition: width .5s ease; min-width: 3px; }
.ir__prod-val { font-size: .75rem; font-weight: 700; color: #0f172a; text-align: right; }
.ir__prod-total { display: flex; justify-content: space-between; align-items: center; padding: .75rem 1.1rem; border-top: 1px solid #f1f5f9; font-size: .8rem; color: #64748b; background: #fafbfc; }
.ir__prod-total strong { color: #0f172a; font-size: .9rem; }

/* Genéticas */
.ir__gen-list { display: flex; flex-direction: column; }
.ir__gen-item { display: flex; align-items: center; justify-content: space-between; padding: .65rem 1.1rem; border-bottom: 1px solid #f8fafc; gap: .5rem; }
.ir__gen-item:last-child { border-bottom: none; }
.ir__gen-nombre { font-size: .8rem; font-weight: 600; color: #0f172a; }
.ir__gen-tipo { font-size: .68rem; color: #64748b; margin-top: .1rem; }
.ir__gen-plantas { font-size: .95rem; font-weight: 800; color: #1b5e20; text-align: right; flex-shrink: 0; }
.ir__gen-plantas-label { font-size: .6rem; font-weight: 500; color: #64748b; margin-left: .1rem; }

/* Sedes */
.ir__sedes-list { display: flex; flex-direction: column; }
.ir__sede-item { padding: .65rem 1.1rem; border-bottom: 1px solid #f8fafc; }
.ir__sede-item:last-child { border-bottom: none; }
.ir__sede-nombre { font-size: .82rem; font-weight: 600; color: #0f172a; }
.ir__sede-meta { font-size: .7rem; color: #64748b; margin-top: .1rem; text-transform: capitalize; }

/* REPROCANN stats */
.ir__repro-list { display: flex; flex-direction: column; padding: .5rem 0; }
.ir__repro-row { display: flex; justify-content: space-between; align-items: center; padding: .5rem 1.1rem; font-size: .8rem; }
.ir__repro-row span { color: #64748b; }
.ir__repro-row strong { font-size: .9rem; }

/* Pie */
.ir__pie { margin-top: 2rem; border-top: 1.5px solid #e2e8f0; padding-top: 1.25rem; display: flex; align-items: flex-end; justify-content: space-between; gap: 2rem; flex-wrap: wrap; }
.ir__pie-text { font-size: .7rem; color: #94a3b8; line-height: 1.7; max-width: 600px; }
.ir__firma-linea { width: 200px; border-bottom: 1px solid #94a3b8; margin-bottom: .4rem; }
.ir__firma-texto { font-size: .65rem; color: #94a3b8; text-align: center; }

.ir__btn-download { display: inline-flex; align-items: center; gap: .4rem; background: #e8f5e9; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 9px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ir__btn-download:hover { background: #d4e6d4; }

/* Print */
@media print {
  .d-print-none { display: none !important; }
  .ir__controls { display: none !important; }
  .ir { padding: 0; max-width: 100%; }
  .ir__portada { border-radius: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .ir__kpi, .ir__section, .ir__aside-card { border: 1px solid #ddd !important; box-shadow: none !important; }
  .ir__layout { grid-template-columns: 1fr 240px; }
  body { font-size: 11px; }
}
</style>
