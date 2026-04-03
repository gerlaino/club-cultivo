<script setup>
import { onMounted, ref, computed } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useSalasStore } from "../stores/salas"
import { useLotesStore } from "../stores/lotes"
import { useAuthStore } from "../stores/auth"
import SalaCultivadoresManager from '../components/SalaCultivadoresManager.vue'
import ModalTarea from '../components/ModalTarea.vue'
import { listUsers } from '../lib/api.js'

const route  = useRoute()
const router = useRouter()
const salas  = useSalasStore()
const lotes  = useLotesStore()
const auth   = useAuthStore()

const salaId  = Number(route.params.id) || 0
const loading = ref(true)
const error   = ref(null)

const canEdit      = computed(() => auth.role === "admin")
const isCultivador = computed(() => auth.role === "cultivador")

const lotesExpanded = ref(true)
const fotosExpanded = ref(false)

const ESTADOS_LOTE = ["planificacion","vegetativo","floracion","secado","cosechado","finalizado"]
const DIAS_CICLO   = { planificacion:7, vegetativo:45, floracion:65, secado:10, cosechado:0, finalizado:0 }

const showModalTarea    = ref(false)
const usuariosParaTarea = ref([])
const lotesParaTarea    = computed(() => items.value)

async function abrirModalTarea() {
  showModalTarea.value = true
  if (usuariosParaTarea.value.length === 0) {
    try {
      const res = await listUsers()
      usuariosParaTarea.value = res.data?.data || []
    } catch {}
  }
}
const tareaInicialConSala = computed(() => ({ sala_id: salaId }))

function emptyLoteForm() {
  return { codigo:"", estado:"vegetativo", plants_count:0, start_date:new Date().toISOString().slice(0,10), strain:"", grow_type:"sustrato", light_type:"", notes:"" }
}
const showCreate = ref(false)
const loteForm   = ref(emptyLoteForm())
const loteErrors = ref({})

onMounted(async () => {
  try {
    await salas.fetchSala(salaId)
    await lotes.fetchBySala(salaId)
  } catch { error.value = "No se pudo cargar la sala." }
  finally  { loading.value = false }
})

const sala  = computed(() => salas.currentSala)
const items = computed(() => lotes.bySala(salaId))

const kpis = computed(() => {
  const ls = items.value
  return {
    totalLotes:   ls.length,
    totalPlantas: ls.reduce((a,l) => a + Number(l.plants_count||0), 0),
    enCiclo:      ls.filter(l => ["vegetativo","floracion"].includes(l.estado)).length,
    cosechados:   ls.filter(l => l.estado === "cosechado").length,
  }
})

const ESTADO_META = {
  semilla:       { label:"Semilla/Esqueje", color:"#64748b", emoji:"📋" },
  vegetativo:    { label:"Vegetativo",    color:"#16a34a", emoji:"🌱" },
  floracion:     { label:"Floración",     color:"#d97706", emoji:"🌸" },
  cosecha:       { label:"Cosecha",        color:"#92400e", emoji:"✂️" },
  curado:        { label:"Curado",     color:"#2563eb", emoji:"🍂"  },
  finalizado:    { label:"Finalizado",    color:"#1b5e20", emoji:"✅" },
}
function estadoMeta(e) { return ESTADO_META[e] || { label:e, color:"#64748b", emoji:"📦" } }
function growLabel(g)  { return { sustrato:"Sustrato", hidroponia:"Hidroponia", aeroponia:"Aeroponia" }[g] || g || "—" }
function kindLabel(k)  { return { produccion:"Producción", social:"Social", mixta:"Mixta" }[k] || k || "—" }

function salaEstadoStyle(state) {
  return { activa:{bg:"#dcfce7",color:"#15803d"}, mantenimiento:{bg:"#fef3c7",color:"#b45309"}, cerrada:{bg:"#f1f5f9",color:"#64748b"} }[state] || {bg:"#f1f5f9",color:"#64748b"}
}
function ocupacionColor(pct) { return pct >= 90 ? "#dc2626" : pct >= 70 ? "#d97706" : "#16a34a" }
function ocupacionPct(s)     { return Math.min(s?.porcentaje_ocupacion || 0, 100) }
function formatDate(d) {
  if (!d) return "—"
  const date = new Date(d)
  return isNaN(date.getTime()) ? "—" : date.toLocaleDateString("es-AR", { day:"numeric", month:"long", year:"numeric" })
}
function diasDesdeInicio(startDate) {
  if (!startDate) return null
  return Math.floor((Date.now() - new Date(startDate)) / 86400000)
}
function progresoCiclo(lote) {
  if (!lote.start_date) return 0
  const dias  = diasDesdeInicio(lote.start_date)
  const total = DIAS_CICLO[lote.estado] || 60
  if (lote.estado === 'cosechado' || lote.estado === 'finalizado') return 100
  return Math.min(Math.round((dias / total) * 100), 99)
}

const itemsSorted = computed(() => {
  const order = ["vegetativo","floracion","planificacion","secado","cosechado","finalizado"]
  return [...items.value].sort((a,b) => order.indexOf(a.estado) - order.indexOf(b.estado))
})

const breadcrumbs = computed(() => {
  if (isCultivador.value) return []
  const crumbs = [{ label:"Sedes", to:{ name:"sedes" } }]
  if (sala.value?.sede) crumbs.push({ label:sala.value.sede.nombre, to:{ name:"sede-detail", params:{ id:sala.value.sede.id } } })
  return crumbs
})

function validateLote(form) {
  const e = {}
  if (!form.codigo?.trim()) e.codigo = "El código es obligatorio"
  if (!ESTADOS_LOTE.includes(form.estado)) e.estado = "Estado inválido"
  const n = Number(form.plants_count)
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser 0–5000"
  return e
}
async function createLote() {
  const e = validateLote(loteForm.value)
  loteErrors.value = e
  if (Object.keys(e).length) return
  try {
    await lotes.createInSala(salaId, { ...loteForm.value })
    closeCreate()
    lotesExpanded.value = true
  } catch {}
}
function closeCreate() {
  showCreate.value = false
  loteForm.value   = emptyLoteForm()
  loteErrors.value = {}
}
</script>

<template>
  <div class="sd">

    <!-- Breadcrumb — solo no cultivadores -->
    <nav v-if="breadcrumbs.length > 0" class="sd__breadcrumb">
      <template v-for="(crumb, i) in breadcrumbs" :key="i">
        <RouterLink :to="crumb.to" class="sd__breadcrumb-link">{{ crumb.label }}</RouterLink>
        <span class="sd__breadcrumb-sep">›</span>
      </template>
      <span class="sd__breadcrumb-current">{{ sala?.nombre || "…" }}</span>
    </nav>

    <div v-if="loading" class="sd__loading"><div class="sd__spinner"></div><span>Cargando sala…</span></div>
    <div v-else-if="error" class="sd__error">{{ error }}</div>
    <div v-else-if="!sala" class="sd__error">Sala no encontrada.</div>

    <template v-else>

      <!-- Header -->
      <div class="sd__hero">
        <div class="sd__hero-left">
          <div class="sd__hero-title-row">
            <h1 class="sd__title">{{ sala.nombre }}</h1>
            <span class="sd__estado-pill" :style="{ background: salaEstadoStyle(sala.state).bg, color: salaEstadoStyle(sala.state).color }">{{ sala.state }}</span>
          </div>
          <p class="sd__subtitle">
            <span v-if="sala.kind">{{ kindLabel(sala.kind) }}</span>
            <span v-if="sala.sede" class="sd__subtitle-sep">·</span>
            <span v-if="sala.sede">{{ sala.sede.nombre }}</span>
          </p>
        </div>
        <div class="sd__hero-actions">
          <button v-if="canEdit" class="sd__btn-primary" @click="showCreate = true">
            <i class="bi bi-plus-lg"></i>Nuevo lote
          </button>
        </div>
      </div>

      <!-- KPIs: Ocupación · Lotes activos · Plantas activas · Total lotes -->
      <div class="sd__kpis">
        <div class="sd__kpi sd__kpi--accent">
          <div class="sd__kpi-icon">📊</div>
          <div class="sd__kpi-body">
            <div class="sd__kpi-value" :style="{ color: ocupacionColor(ocupacionPct(sala)) }">{{ ocupacionPct(sala).toFixed(0) }}%</div>
            <div class="sd__kpi-label">Ocupación</div>
            <div class="sd__kpi-progress">
              <div class="sd__kpi-progress-fill" :style="{ width: ocupacionPct(sala) + '%', background: ocupacionColor(ocupacionPct(sala)) }"></div>
            </div>
          </div>
        </div>
        <div class="sd__kpi">
          <div class="sd__kpi-icon">🌿</div>
          <div class="sd__kpi-body">
            <div class="sd__kpi-value" style="color:#16a34a">{{ kpis.enCiclo }}</div>
            <div class="sd__kpi-label">Lotes activos</div>
            <div class="sd__kpi-sub">vegetativo · floración</div>
          </div>
        </div>
        <div class="sd__kpi">
          <div class="sd__kpi-icon">🪴</div>
          <div class="sd__kpi-body">
            <div class="sd__kpi-value">{{ kpis.totalPlantas }}</div>
            <div class="sd__kpi-label">Plantas activas</div>
            <div class="sd__kpi-sub">cap. {{ sala.pots_count ?? 0 }}</div>
          </div>
        </div>
        <div class="sd__kpi">
          <div class="sd__kpi-icon">📦</div>
          <div class="sd__kpi-body">
            <div class="sd__kpi-value">{{ kpis.totalLotes }}</div>
            <div class="sd__kpi-label">Total lotes</div>
            <div class="sd__kpi-sub">{{ kpis.cosechados }} cosechados</div>
          </div>
        </div>
      </div>

      <div class="sd__layout">
        <div class="sd__main">

          <!-- Lotes collapsable -->
          <div class="sd__section">
            <button class="sd__section-toggle" @click="lotesExpanded = !lotesExpanded">
              <div class="sd__section-toggle-left">
                <span class="sd__section-emoji">🌿</span>
                <span class="sd__section-title">Lotes</span>
                <span class="sd__pill">{{ items.length }}</span>
              </div>
              <i class="bi sd__chevron" :class="lotesExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="lotesExpanded" class="sd__section-body sd__section-body--flush">
              <div v-if="lotes.loading" class="sd__placeholder">Cargando lotes…</div>
              <div v-else-if="!items.length" class="sd__empty">
                <div class="sd__empty-icon">📦</div>
                <p>Esta sala no tiene lotes todavía</p>
                <button v-if="canEdit" class="sd__btn-outline" @click="showCreate=true">Crear primer lote</button>
              </div>
              <div v-else class="sd__lotes">
                <RouterLink v-for="l in itemsSorted" :key="l.id" :to="{ name:'lote-detail', params:{ id:l.id } }" class="sd__lote">
                  <div class="sd__lote-stripe" :style="{ background: estadoMeta(l.estado).color }"></div>
                  <div class="sd__lote-content">
                    <div class="sd__lote-head">
                      <div class="sd__lote-title-row">
                        <span class="sd__lote-emoji">{{ estadoMeta(l.estado).emoji }}</span>
                        <span class="sd__lote-codigo">{{ l.codigo }}</span>
                        <span class="sd__lote-badge" :style="{ background: estadoMeta(l.estado).color+'18', color: estadoMeta(l.estado).color }">{{ estadoMeta(l.estado).label }}</span>
                      </div>
                      <div class="sd__lote-dias" v-if="diasDesdeInicio(l.start_date) !== null">{{ diasDesdeInicio(l.start_date) }}d</div>
                    </div>
                    <div class="sd__lote-meta">
                      <span v-if="l.plants_count">🪴 {{ l.plants_count }} plantas</span>
                      <span v-if="l.strain">🌿 {{ l.strain }}</span>
                      <span v-if="l.grow_type">⚗️ {{ growLabel(l.grow_type) }}</span>
                      <span v-if="l.start_date">📅 {{ l.start_date }}</span>
                    </div>
                    <div class="sd__lote-progress-wrap">
                      <div class="sd__lote-progress-track">
                        <div class="sd__lote-progress-fill" :style="{ width: progresoCiclo(l)+'%', background: estadoMeta(l.estado).color }"></div>
                      </div>
                      <span class="sd__lote-progress-pct">{{ progresoCiclo(l) }}%</span>
                    </div>
                  </div>
                  <i class="bi bi-chevron-right sd__lote-arrow"></i>
                </RouterLink>
              </div>
            </div>
          </div>

          <!-- Fotos — en construcción -->
          <div class="sd__section sd__section--mt">
            <button class="sd__section-toggle" @click="fotosExpanded = !fotosExpanded">
              <div class="sd__section-toggle-left">
                <span class="sd__section-emoji">📷</span>
                <span class="sd__section-title">Fotos de la sala</span>
              </div>
              <i class="bi sd__chevron" :class="fotosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="fotosExpanded" class="sd__section-body">
              <div class="sd__wip">
                <div class="sd__wip-icon">🚧</div>
                <div class="sd__wip-title">Sección en construcción</div>
                <div class="sd__wip-desc">Las fotos se gestionarán desde cada lote. Próximamente disponible.</div>
              </div>
            </div>
          </div>

        </div>

        <!-- Aside -->
        <div class="sd__aside">

          <!-- Información -->
          <div class="sd__card">
            <div class="sd__card-header"><span class="sd__card-title">ℹ️ Información</span></div>
            <dl class="sd__dl">
              <dt>Estado</dt><dd style="text-transform:capitalize">{{ sala.state }}</dd>
              <dt>Tipo</dt><dd>{{ kindLabel(sala.kind) }}</dd>
              <dt>Capacidad</dt><dd>{{ sala.pots_count ?? 0 }} plantas</dd>
              <dt>Sede</dt><dd>{{ sala.sede?.nombre || "—" }}</dd>
              <dt>A cargo de</dt><dd>{{ sala.cultivadores?.map(c => c.nombre).join(', ') || sala.created_by_name || "—" }}</dd>
              <dt>Creado por</dt><dd>{{ sala.created_by_name || "—" }}</dd>
              <dt>Creado</dt><dd>{{ formatDate(sala.created_at) }}</dd>
              <dt>Actualizado</dt><dd>{{ formatDate(sala.updated_at) }}</dd>
            </dl>
          </div>

          <!-- Cultivadores — solo admin/agricultor -->
          <div v-if="!isCultivador" class="sd__card sd__card--mt">
            <div class="sd__card-header"><span class="sd__card-title">👨‍🌾 Cultivadores</span></div>
            <div class="sd__card-body">
              <SalaCultivadoresManager :sala-id="sala.id" :sala-nombre="sala.nombre" />
            </div>
          </div>

          <!-- Notas -->
          <div v-if="sala.notes" class="sd__card sd__card--mt">
            <div class="sd__card-header"><span class="sd__card-title">📋 Notas</span></div>
            <div class="sd__card-notes">{{ sala.notes }}</div>
          </div>

          <!-- Nueva tarea — solo admin/agricultor -->
          <div v-if="canEdit" class="sd__card sd__card--mt sd__card--cta">
            <button class="sd__cta" @click="abrirModalTarea">
              <i class="bi bi-plus-circle-fill sd__cta-icon"></i>
              <div>
                <div class="sd__cta-label">Nueva tarea</div>
                <div class="sd__cta-hint">para esta sala</div>
              </div>
              <i class="bi bi-arrow-right sd__cta-arrow"></i>
            </button>
          </div>

        </div>
      </div>
    </template>

    <!-- Modal Crear Lote -->
    <Teleport to="body">
      <div v-if="showCreate" class="sd__overlay" @click.self="closeCreate">
        <div class="sd__modal">
          <div class="sd__modal-header">
            <div>
              <h3 class="sd__modal-title">Nuevo lote</h3>
              <p class="sd__modal-sub">{{ sala?.nombre }}</p>
            </div>
            <button class="sd__modal-close" @click="closeCreate"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="sd__modal-body">
            <div v-if="lotes.createError" class="sd__alert">{{ lotes.createError }}</div>
            <div class="sd__grid">
              <div class="sd__field">
                <label class="sd__label">Estado</label>
                <select class="sd__input" v-model="loteForm.estado">
                  <option v-for="e in ESTADOS_LOTE" :key="e" :value="e">{{ estadoMeta(e).label }}</option>
                </select>
              </div>
              <div class="sd__field">
                <label class="sd__label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" step="1" class="sd__input" :class="{ 'sd__input--err': loteErrors.plants_count }" v-model.number="loteForm.plants_count" />
                <span v-if="loteErrors.plants_count" class="sd__err-msg">{{ loteErrors.plants_count }}</span>
              </div>
              <div class="sd__field">
                <label class="sd__label">Fecha de inicio</label>
                <input type="date" class="sd__input" v-model="loteForm.start_date" />
              </div>
              <div class="sd__field">
                <label class="sd__label">Strain / Variedad</label>
                <input type="text" class="sd__input" v-model.trim="loteForm.strain" placeholder="Ej: OG Kush" />
              </div>
              <div class="sd__field">
                <label class="sd__label">Tipo de cultivo</label>
                <select class="sd__input" v-model="loteForm.grow_type">
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>
              <div class="sd__field">
                <label class="sd__label">Tipo de luz</label>
                <select class="sd__input" v-model="loteForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Notas</label>
                <textarea class="sd__input sd__textarea" rows="2" v-model.trim="loteForm.notes" placeholder="Observaciones…"></textarea>
              </div>
            </div>
          </div>
          <div class="sd__modal-footer">
            <button class="sd__btn-ghost" :disabled="lotes.creating" @click="closeCreate">Cancelar</button>
            <button class="sd__btn-primary" :disabled="lotes.creating" @click="createLote">
              <div v-if="lotes.creating" class="sd__spinner sd__spinner--sm"></div>
              <i v-else class="bi bi-plus-lg"></i>Crear lote
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <ModalTarea
      v-if="!isCultivador"
      :show="showModalTarea"
      :tarea-inicial="tareaInicialConSala"
      :salas="sala ? [sala] : []"
      :lotes="lotesParaTarea"
      :usuarios="usuariosParaTarea"
      @cerrar="showModalTarea = false"
      @guardada="showModalTarea = false"
    />

  </div>
</template>

<style scoped>
.sd { padding: 1.75rem 1.5rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .sd { padding: 1rem; } }

.sd__breadcrumb { display: flex; align-items: center; gap: .4rem; font-size: .78rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.sd__breadcrumb-link { color: #94a3b8; text-decoration: none; transition: color .15s; }
.sd__breadcrumb-link:hover { color: #1b5e20; }
.sd__breadcrumb-sep { color: #cbd5e1; }
.sd__breadcrumb-current { color: #1a1a1a; font-weight: 600; }

.sd__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.sd__error { padding: 1rem 1.25rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 10px; font-size: .875rem; }
.sd__spinner { width: 20px; height: 20px; border: 2.5px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: sd-spin .6s linear infinite; flex-shrink: 0; }
.sd__spinner--sm { width: 14px; height: 14px; border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes sd-spin { to { transform: rotate(360deg); } }

.sd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sd__hero-title-row { display: flex; align-items: center; gap: .65rem; margin-bottom: .3rem; flex-wrap: wrap; }
.sd__title { font-size: 1.8rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.sd__estado-pill { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; padding: .28em .75em; border-radius: 999px; }
.sd__subtitle { font-size: .85rem; color: #60725d; margin: 0; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.sd__subtitle-sep { color: #cbd5e1; }
.sd__hero-actions { display: flex; gap: .5rem; }

.sd__kpis { display: grid; grid-template-columns: repeat(4,1fr); gap: 1rem; margin-bottom: 1.75rem; }
@media (max-width: 640px) { .sd__kpis { grid-template-columns: repeat(2,1fr); } }
.sd__kpi { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.1rem; display: flex; align-items: flex-start; gap: .75rem; transition: box-shadow .15s; }
.sd__kpi:hover { box-shadow: 0 4px 16px rgba(27,94,32,.1); }
.sd__kpi--accent { border-color: #a7d7a9; background: #f0fdf4; }
.sd__kpi-icon { font-size: 1.4rem; flex-shrink: 0; margin-top: .1rem; }
.sd__kpi-body { flex: 1; min-width: 0; }
.sd__kpi-value { font-size: 1.75rem; font-weight: 800; line-height: 1; letter-spacing: -.04em; margin-bottom: .2rem; color: #1a1a1a; }
.sd__kpi-label { font-size: .7rem; color: #60725d; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; margin-bottom: .15rem; }
.sd__kpi-sub { font-size: .72rem; color: #94a3b8; }
.sd__kpi-progress { height: 4px; background: #d4e6d4; border-radius: 999px; overflow: hidden; margin-top: .5rem; }
.sd__kpi-progress-fill { height: 100%; border-radius: 999px; transition: width .5s ease; }

.sd__layout { display: grid; grid-template-columns: 1fr 300px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .sd__layout { grid-template-columns: 1fr; } }

.sd__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.sd__section--mt { margin-top: 1.25rem; }
.sd__section-toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; background: transparent; border: none; cursor: pointer; transition: background .15s; text-align: left; }
.sd__section-toggle:hover { background: #f0fdf4; }
.sd__section-toggle-left { display: flex; align-items: center; gap: .6rem; }
.sd__section-toggle-right { display: flex; align-items: center; gap: .5rem; }
.sd__section-emoji { font-size: 1rem; }
.sd__section-title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.sd__pill { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; min-width: 20px; text-align: center; }
.sd__chevron { color: #60725d; font-size: .75rem; }
.sd__section-body { border-top: 1px solid #e8f0e9; padding: 1rem 1.1rem; }
.sd__section-body--flush { padding: 0; border-top: 1px solid #e8f0e9; }

.sd__lotes { display: flex; flex-direction: column; }
.sd__lote { display: flex; align-items: stretch; text-decoration: none; color: inherit; border-bottom: 1px solid #f0fdf4; transition: background .15s; }
.sd__lote:last-child { border-bottom: none; }
.sd__lote:hover { background: #f9fdf9; }
.sd__lote-stripe { width: 4px; flex-shrink: 0; }
.sd__lote-content { flex: 1; padding: .9rem 1rem; min-width: 0; }
.sd__lote-head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; margin-bottom: .35rem; }
.sd__lote-title-row { display: flex; align-items: center; gap: .45rem; flex-wrap: wrap; }
.sd__lote-emoji { font-size: .95rem; }
.sd__lote-codigo { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.sd__lote-badge { font-size: .65rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; padding: .2em .6em; border-radius: 6px; }
.sd__lote-dias { font-size: .72rem; font-weight: 700; color: #60725d; background: #e8f5e9; padding: .2em .6em; border-radius: 6px; white-space: nowrap; flex-shrink: 0; }
.sd__lote-meta { display: flex; gap: .6rem; flex-wrap: wrap; font-size: .73rem; color: #94a3b8; margin-bottom: .5rem; }
.sd__lote-progress-wrap { display: flex; align-items: center; gap: .6rem; }
.sd__lote-progress-track { flex: 1; height: 3px; background: #e8f5e9; border-radius: 999px; overflow: hidden; }
.sd__lote-progress-fill { height: 100%; border-radius: 999px; transition: width .5s ease; }
.sd__lote-progress-pct { font-size: .65rem; color: #94a3b8; font-weight: 600; flex-shrink: 0; }
.sd__lote-arrow { color: #a7d7a9; font-size: .75rem; align-self: center; padding-right: 1rem; flex-shrink: 0; }

/* WIP section */
.sd__wip { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 2rem 1rem; text-align: center; gap: .5rem; }
.sd__wip-icon { font-size: 2rem; }
.sd__wip-title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.sd__wip-desc { font-size: .8rem; color: #60725d; max-width: 280px; }

.sd__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.sd__card--mt { margin-top: 1rem; }
.sd__card--cta { border-style: dashed; }
.sd__card-header { padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; }
.sd__card-title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.sd__card-body { padding: 1rem; }
.sd__card-notes { padding: .9rem 1rem; font-size: .82rem; color: #475569; line-height: 1.6; }

.sd__dl { display: grid; grid-template-columns: auto 1fr; gap: .45rem .75rem; padding: .9rem 1rem; margin: 0; }
.sd__dl dt { font-size: .75rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.sd__dl dd { font-size: .8rem; color: #1a1a1a; font-weight: 500; margin: 0; }

.sd__cta { display: flex; align-items: center; gap: .75rem; padding: .9rem 1rem; background: transparent; border: none; width: 100%; cursor: pointer; text-align: left; transition: background .15s; }
.sd__cta:hover { background: #f0fdf4; }
.sd__cta-icon { font-size: 1.25rem; color: #1b5e20; flex-shrink: 0; }
.sd__cta-label { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.sd__cta-hint { font-size: .72rem; color: #60725d; }
.sd__cta-arrow { color: #a7d7a9; margin-left: auto; font-size: .8rem; }

.sd__empty { text-align: center; padding: 2.5rem 1rem; color: #60725d; }
.sd__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; }
.sd__empty p { font-size: .875rem; margin: 0 0 .75rem; }
.sd__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }

.sd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.sd__btn-primary:hover { background: #104417; }
.sd__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.sd__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }
.sd__btn-outline { background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .5rem 1.1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }

.sd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.sd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 620px; max-height: 90vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.sd__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.sd__modal-title { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.sd__modal-sub { font-size: .78rem; color: #60725d; margin: .2rem 0 0; }
.sd__modal-close { background: #e8f5e9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0; }
.sd__modal-close:hover { background: #c8e6c9; color: #1b5e20; }
.sd__modal-body { padding: 1.25rem 1.5rem; flex: 1; }
.sd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }

.sd__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .sd__grid { grid-template-columns: 1fr; } }
.sd__field { display: flex; flex-direction: column; gap: .35rem; }
.sd__field--full { grid-column: 1 / -1; }
.sd__label { font-size: .8rem; font-weight: 600; color: #374151; }
.sd__req { color: #dc2626; }
.sd__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.sd__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.sd__input--err { border-color: #dc2626; }
.sd__textarea { resize: vertical; min-height: 70px; }
.sd__err-msg { font-size: .75rem; color: #dc2626; }
.sd__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }
</style>
