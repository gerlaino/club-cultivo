<script setup>
import { onMounted, ref, computed } from "vue"
import { useRoute } from "vue-router"
import { useLotesStore }  from "../stores/lotes"
import { usePlantsStore } from "../stores/plants"
import { useAuthStore }   from "../stores/auth"
import { getCostoLote, createCostoLote, updateCostoLote,
  getRegistrosAmbientales, createRegistroAmbiental,
  getLoteEventos, createLoteEvento,
  getLoteFotos, uploadFotoLote } from "../lib/api"
import TareasDelLote from '../components/TareasDelLote.vue'
import { usePermissions } from '../composables/usePermissions'

const { can }  = usePermissions()
const route    = useRoute()
const lotes    = useLotesStore()
const plants   = usePlantsStore()
const auth     = useAuthStore()

const id           = Number(route.params.id)
const error        = ref(null)
const loading      = computed(() => lotes.loading)
const lote         = computed(() => lotes.current)
const canEdit      = computed(() => ["admin","agricultor"].includes(auth.role))
const isCultivador = computed(() => auth.role === "cultivador")

const tareasExpanded    = ref(true)
const plantasExpanded   = ref(true)
const historialExpanded = ref(true)
const fotosExpanded    = ref(false)
const fotos            = ref([])
const uploadingFoto    = ref(false)
const fotoInput        = ref(null)
const ambientalExpanded = ref(false)

// ── Costo ─────────────────────────────────────────────────
const costo          = ref(null)
const showCostoModal = ref(false)
const savingCosto    = ref(false)
const costoError     = ref(null)

function emptyCostoForm() {
  return { costo_insumos:0, costo_energia:0, costo_mano_obra:0, costo_prorrateado:0, gramos_producidos:null, notas:"" }
}
const costoForm = ref(emptyCostoForm())
const costoTotal = computed(() =>
  (Number(costoForm.value.costo_insumos)||0)+(Number(costoForm.value.costo_energia)||0)+
  (Number(costoForm.value.costo_mano_obra)||0)+(Number(costoForm.value.costo_prorrateado)||0)
)
const costoPorGramoPreview = computed(() => {
  const g = Number(costoForm.value.gramos_producidos)
  return (!g||g<=0) ? null : (costoTotal.value/g).toFixed(2)
})
function fmt(n) {
  if (n==null) return "—"
  return new Intl.NumberFormat("es-AR",{style:"currency",currency:"ARS",minimumFractionDigits:0}).format(n)
}
function openCostoModal() {
  costoForm.value = costo.value ? {
    costo_insumos:costo.value.costo_insumos||0, costo_energia:costo.value.costo_energia||0,
    costo_mano_obra:costo.value.costo_mano_obra||0, costo_prorrateado:costo.value.costo_prorrateado||0,
    gramos_producidos:costo.value.gramos_producidos||null, notas:costo.value.notas||"",
  } : emptyCostoForm()
  costoError.value=null; showCostoModal.value=true
}
async function submitCosto() {
  savingCosto.value=true; costoError.value=null
  try {
    const res = costo.value ? await updateCostoLote(id,costoForm.value) : await createCostoLote(id,costoForm.value)
    costo.value=res.data; showCostoModal.value=false
  } catch(e) { costoError.value=e?.response?.data?.errors?.join(", ")||"Error al guardar" }
  finally { savingCosto.value=false }
}
async function loadCosto() {
  try { const {data}=await getCostoLote(id); costo.value=data.costo||null }
  catch { costo.value=null }
}

// ── Registros del lote ────────────────────────────────────
const registros         = ref([])
const loadingRegistros  = ref(false)
const showRegistroModal = ref(false)
const savingRegistro    = ref(false)
const registroError     = ref(null)
const csvFile           = ref(null)
const csvInput          = ref(null)

function emptyRegistroForm() {
  return {
    temperatura:null, humedad:null, temperatura_sustrato:null, co2:null,
    ph:null, ec:null, ph_runoff:null, ppfd:null,
    horas_luz:null, espectro_luz:'',
    fertilizacion:false, notas_fertilizacion:'',
    plagas_observadas:'ninguna', estado_general:'bueno', observaciones:''
  }
}
const registroForm = ref(emptyRegistroForm())

const registroErrors = computed(() => {
  const e={}; const f=registroForm.value
  if (f.temperatura          && (f.temperatura<0||f.temperatura>60))                   e.temperatura='0–60°C'
  if (f.temperatura_sustrato && (f.temperatura_sustrato<0||f.temperatura_sustrato>60)) e.temperatura_sustrato='0–60°C'
  if (f.humedad              && (f.humedad<0||f.humedad>100))                           e.humedad='0–100%'
  if (f.ph                   && (f.ph<0||f.ph>14))                                     e.ph='0–14'
  if (f.ph_runoff            && (f.ph_runoff<0||f.ph_runoff>14))                       e.ph_runoff='0–14'
  if (f.horas_luz            && (f.horas_luz<0||f.horas_luz>24))                       e.horas_luz='0–24h'
  return e
})

async function loadRegistros() {
  loadingRegistros.value=true
  try { const {data}=await getRegistrosAmbientales(id); registros.value=data||[] }
  catch { registros.value=[] }
  finally { loadingRegistros.value=false }
}
function toggleAmbiental() {
  ambientalExpanded.value=!ambientalExpanded.value
  if (ambientalExpanded.value && registros.value.length===0) loadRegistros()
}
function abrirRegistroModal() {
  registroForm.value=emptyRegistroForm(); registroError.value=null
  csvFile.value=null; showRegistroModal.value=true
  if (registros.value.length===0) loadRegistros()
}
function handleCsvChange(e) { csvFile.value=e.target.files?.[0]||null }

async function guardarRegistro() {
  if (Object.keys(registroErrors.value).length>0) return
  savingRegistro.value=true; registroError.value=null
  try {
    let result
    if (csvFile.value) {
      const fd=new FormData()
      Object.entries(registroForm.value).forEach(([k,v])=>{ if(v!==null&&v!=='') fd.append(`registro_ambiental[${k}]`,v) })
      fd.append('archivo_csv',csvFile.value)
      const {data}=await createRegistroAmbiental(id,fd,true)
      result=data
    } else {
      const {data}=await createRegistroAmbiental(id,registroForm.value)
      result=data
    }
    registros.value.unshift(result)
    showRegistroModal.value=false; registroForm.value=emptyRegistroForm(); csvFile.value=null
  } catch(e) { registroError.value=e?.response?.data?.errors?.join(', ')||'Error al guardar' }
  finally { savingRegistro.value=false }
}

// ── Historial (eventos) ───────────────────────────────────
const eventos        = ref([])
const loadingEventos = ref(false)
const showCicloModal = ref(false)
const savingEvento   = ref(false)
const eventoError    = ref(null)
const cicloForm      = ref({ estado_nuevo:'', descripcion:'' })

async function loadEventos() {
  loadingEventos.value=true
  try {
    const [evRes, regRes] = await Promise.all([
      getLoteEventos(id),
      getRegistrosAmbientales(id)
    ])
    const evs  = (evRes.data||[]).map(e => ({ ...e, _tipo: 'evento' }))
    const regs = (regRes.data||[]).map(r => ({
      ...r,
      _tipo: 'registro',
      registrado_en: r.registrado_en,
    }))
    // Mezclar y ordenar por fecha desc
    eventos.value = [...evs, ...regs].sort((a,b) =>
      new Date(b.registrado_en) - new Date(a.registrado_en)
    )
  }
  catch { eventos.value=[] }
  finally { loadingEventos.value=false }
}
async function loadFotos() {
  try { const { data } = await getLoteFotos(id); fotos.value = data || [] }
  catch { fotos.value = [] }
}
async function handleFotoUpload(e) {
  const file = e.target.files?.[0]
  if (!file) return
  uploadingFoto.value = true
  try {
    const fd = new FormData()
    fd.append('foto', file)
    const { data } = await uploadFotoLote(id, fd)
    fotos.value.unshift(data)
  } catch (err) { console.error(err) }
  finally { uploadingFoto.value = false; if (fotoInput.value) fotoInput.value.value = '' }
}
function toggleFotos() {
  fotosExpanded.value = !fotosExpanded.value
  if (fotosExpanded.value && fotos.value.length === 0) loadFotos()
}
function toggleHistorial() {
  historialExpanded.value=!historialExpanded.value
  if (historialExpanded.value && eventos.value.length===0) loadEventos()
}
async function cambiarCiclo() {
  if (!cicloForm.value.estado_nuevo) return
  savingEvento.value=true; eventoError.value=null
  try {
    const {data}=await createLoteEvento(id,{
      tipo:'cambio_estado', estado_nuevo:cicloForm.value.estado_nuevo, descripcion:cicloForm.value.descripcion
    })
    eventos.value.unshift(data)
    if (lotes.current) lotes.current.estado=cicloForm.value.estado_nuevo
    showCicloModal.value=false; cicloForm.value={estado_nuevo:'',descripcion:''}
  } catch(e) { eventoError.value=e?.response?.data?.errors?.join(', ')||'Error' }
  finally { savingEvento.value=false }
}

// ── Helpers ────────────────────────────────────────────────
const CICLO = ["semilla","vegetativo","floracion","cosecha","curado","finalizado"]
const ESTADO_META = {
  semilla:    { label:"Semilla/Esqueje", color:"#64748b", bg:"#f1f5f9",  emoji:"🌱" },
  vegetativo: { label:"Vegetativo",      color:"#16a34a", bg:"#dcfce7",  emoji:"🍃" },
  floracion:  { label:"Floración",       color:"#d97706", bg:"#fef3c7",  emoji:"🌸" },
  cosecha:    { label:"Cosecha",         color:"#92400e", bg:"#fff7ed",  emoji:"✂️"  },
  curado:     { label:"Curado",          color:"#2563eb", bg:"#dbeafe",  emoji:"🫙" },
  finalizado: { label:"Finalizado",      color:"#1b5e20", bg:"#dcfce7",  emoji:"✅" },
}
const PLANT_STATE_META = {
  semilla:    {label:"Semilla",    color:"#64748b",emoji:"🌰"},
  germinacion:{label:"Germinación",color:"#16a34a",emoji:"🌱"},
  esqueje:    {label:"Esqueje",    color:"#0891b2",emoji:"🌿"},
  vegetativo: {label:"Vegetativo", color:"#16a34a",emoji:"🍃"},
  floracion:  {label:"Floración",  color:"#d97706",emoji:"🌸"},
  cosechada:  {label:"Cosechada",  color:"#2563eb",emoji:"✅"},
  descartada: {label:"Descartada", color:"#dc2626",emoji:"❌"},
}
const ESTADO_SALUD_META = {
  excelente:{color:"#16a34a",emoji:"🟢"},
  bueno:    {color:"#65a30d",emoji:"🟡"},
  regular:  {color:"#d97706",emoji:"🟠"},
  malo:     {color:"#dc2626",emoji:"🔴"},
  critico:  {color:"#991b1b",emoji:"🚨"},
}
const PLAGAS_META = {
  ninguna: {color:"#16a34a",emoji:"✅"},
  leve:    {color:"#d97706",emoji:"⚠️"},
  moderada:{color:"#ea580c",emoji:"🐛"},
  severa:  {color:"#dc2626",emoji:"🚨"},
}

function em(e)  { return ESTADO_META[e]       || {label:e||"—",color:"#64748b",bg:"#f1f5f9",emoji:"•"} }
function pm(s)  { return PLANT_STATE_META[s]  || {label:s||"—",color:"#64748b",emoji:"🌿"} }
function sm(s)  { return ESTADO_SALUD_META[s] || {color:"#94a3b8",emoji:"⚪"} }
function pgm(p) { return PLAGAS_META[p]       || {color:"#94a3b8",emoji:"—"} }
function growLabel(g)  { return {sustrato:"Sustrato",hidroponia:"Hidroponia",aeroponia:"Aeroponia"}[g]||g||"—" }
function lightLabel(l) { return {led:"LED",hps:"HPS",cmh:"CMH",natural:"Natural",mixta:"Mixta"}[l]||l||"—" }
function formatDate(d) {
  if(!d) return "—"
  const date=new Date(d)
  return isNaN(date.getTime()) ? "—" : date.toLocaleDateString("es-AR",{day:"numeric",month:"long",year:"numeric"})
}
function formatDateTime(d) {
  if(!d) return "—"
  const date=new Date(d)
  return isNaN(date.getTime()) ? "—" : date.toLocaleString("es-AR",{day:"numeric",month:"short",hour:"2-digit",minute:"2-digit"})
}

const cicloIndex       = computed(() => lote.value ? CICLO.indexOf(lote.value.estado) : -1)
const plantList        = computed(() => plants.byLote(id))
const estadosSiguientes = computed(() => {
  const idx=CICLO.indexOf(lote.value?.estado)
  return CICLO.filter((_,i)=>i>idx)
})

function onHorasAplicadas() {}

onMounted(async () => {
  try   { await lotes.fetchOne(id) }
  catch { error.value="No se pudo cargar el lote." }
  try   { await plants.fetchByLote(id) }
  catch {}
  const promises = [loadEventos()]
  if (auth.role !== 'cultivador') promises.push(loadCosto())
  await Promise.all(promises)
})
</script>

<template>
  <div class="ld">

    <!-- Breadcrumb -->
    <nav class="ld__breadcrumb">
      <RouterLink :to="{ name:'sedes' }" class="ld__breadcrumb-link">Sedes</RouterLink>
      <span class="ld__breadcrumb-sep">›</span>
      <template v-if="lote?.sala">
        <RouterLink :to="{ name:'sala-detail', params:{ id:lote.sala.id } }" class="ld__breadcrumb-link">{{ lote.sala.nombre }}</RouterLink>
        <span class="ld__breadcrumb-sep">›</span>
      </template>
      <span class="ld__breadcrumb-current">{{ lote?.codigo || `Lote #${id}` }}</span>
    </nav>

    <div v-if="loading" class="ld__loading"><div class="ld__spinner"></div><span>Cargando lote…</span></div>
    <div v-else-if="error" class="ld__error">{{ error }}</div>
    <div v-else-if="!lote" class="ld__error">Lote no encontrado.</div>

    <template v-else>

      <!-- Hero -->
      <div class="ld__hero">
        <div class="ld__hero-left">
          <div class="ld__hero-title-row">
            <span class="ld__hero-emoji">{{ em(lote.estado).emoji }}</span>
            <h1 class="ld__title">{{ lote.codigo }}</h1>
            <span class="ld__estado-pill" :style="{ background: em(lote.estado).bg, color: em(lote.estado).color }">
              {{ em(lote.estado).label }}
            </span>
          </div>
          <p class="ld__subtitle">
            <span v-if="lote.strain">🌿 {{ lote.strain }}</span>
            <span v-if="lote.sala" class="ld__subtitle-sep">·</span>
            <span v-if="lote.sala">📍 {{ lote.sala.nombre }}</span>
            <span v-if="lote.start_date" class="ld__subtitle-sep">·</span>
            <span v-if="lote.start_date">📅 inicio {{ lote.start_date }}</span>
            <span v-if="lote.dias_desde_inicio != null" class="ld__subtitle-sep">·</span>
            <span v-if="lote.dias_desde_inicio != null" class="ld__dias-badge">Día {{ lote.dias_desde_inicio }}</span>
          </p>
        </div>
        <div class="ld__hero-actions">
          <button v-if="canEdit && estadosSiguientes.length > 0" class="ld__btn-ghost-sm" @click="showCicloModal = true">
            <i class="bi bi-arrow-right-circle"></i>Avanzar ciclo
          </button>
          <button class="ld__btn-secondary" @click="abrirRegistroModal">
            <i class="bi bi-clipboard-data"></i>Registrar lote
          </button>
          <RouterLink v-if="can('plantas','create')" :to="{ name:'planta-nueva', query:{ lote_id:id } }" class="ld__btn-primary">
            <i class="bi bi-plus-lg"></i>Nueva planta
          </RouterLink>
        </div>
      </div>

      <!-- Timeline ciclo -->
      <div class="ld__ciclo">
        <div class="ld__ciclo-track">
          <div v-for="(etapa, i) in CICLO" :key="etapa" class="ld__ciclo-step"
               :class="{'ld__ciclo-step--done':i<cicloIndex,'ld__ciclo-step--current':i===cicloIndex,'ld__ciclo-step--pending':i>cicloIndex}">
            <div class="ld__ciclo-dot"><span class="ld__ciclo-emoji">{{ em(etapa).emoji }}</span></div>
            <div class="ld__ciclo-label">{{ em(etapa).label }}</div>
            <div v-if="i < CICLO.length-1" class="ld__ciclo-connector" :class="{'ld__ciclo-connector--done':i<cicloIndex}"></div>
          </div>
        </div>
        <div v-if="lote.progreso_ciclo != null" class="ld__ciclo-progress">
          <div class="ld__ciclo-progress-fill" :style="{ width: lote.progreso_ciclo + '%' }"></div>
        </div>
      </div>

      <!-- Layout -->
      <div class="ld__layout">
        <div class="ld__main">

          <!-- 1. Tareas del lote -->
          <div class="ld__section">
            <button class="ld__section-toggle" @click="tareasExpanded = !tareasExpanded">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📋</span>
                <span class="ld__section-title">Tareas del lote</span>
              </div>
              <i class="bi ld__chevron" :class="tareasExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="tareasExpanded" class="ld__section-body">
              <TareasDelLote :lote="lote" @horas-aplicadas="onHorasAplicadas" />
            </div>
          </div>

          <!-- 2. Plantas del lote -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="plantasExpanded = !plantasExpanded">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">🪴</span>
                <span class="ld__section-title">Plantas del lote</span>
                <span class="ld__pill">{{ plantList.length }}</span>
              </div>
              <div class="ld__section-toggle-right">
                <RouterLink v-if="can('plantas','create')" :to="{ name:'planta-nueva', query:{ lote_id:id } }" class="ld__btn-sm" @click.stop>
                  <i class="bi bi-plus-lg"></i>
                </RouterLink>
                <i class="bi ld__chevron" :class="plantasExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
              </div>
            </button>
            <div v-show="plantasExpanded" class="ld__section-body ld__section-body--flush">
              <div v-if="plants.loading" class="ld__placeholder">Cargando plantas…</div>
              <div v-else-if="!plantList.length" class="ld__empty">
                <div class="ld__empty-icon">🪴</div>
                <p>Sin plantas registradas en este lote</p>
                <RouterLink v-if="can('plantas','create')" :to="{ name:'planta-nueva', query:{ lote_id:id } }" class="ld__btn-outline">
                  <i class="bi bi-plus-lg"></i> Agregar primera planta
                </RouterLink>
              </div>
              <div v-else class="ld__plantas">
                <RouterLink v-for="(p,i) in plantList" :key="p.id" :to="{ name:'planta-detalle', params:{ id:p.id } }" class="ld__planta">
                  <div class="ld__planta-num">{{ i+1 }}</div>
                  <div class="ld__planta-dot" :style="{ background: pm(p.state).color }"></div>
                  <div class="ld__planta-info">
                    <div class="ld__planta-nombre">{{ p.nombre||p.codigo_qr||`Planta #${p.id}` }}</div>
                    <div class="ld__planta-qr">{{ p.codigo_qr||'—' }}</div>
                  </div>
                  <span class="ld__planta-estado" :style="{ background: pm(p.state).color+'18', color: pm(p.state).color }">
                    {{ pm(p.state).emoji }} {{ pm(p.state).label }}
                  </span>
                  <i class="bi bi-chevron-right ld__planta-arrow"></i>
                </RouterLink>
              </div>
            </div>
          </div>

          <!-- 3. Historial del lote -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="toggleHistorial">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📜</span>
                <span class="ld__section-title">Historial del lote</span>
              </div>
              <i class="bi ld__chevron" :class="historialExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="historialExpanded" class="ld__section-body ld__section-body--flush">
              <div v-if="loadingEventos" class="ld__placeholder">Cargando historial…</div>
              <div v-else-if="eventos.length === 0" class="ld__empty ld__empty--sm">
                <div class="ld__empty-icon" style="font-size:1.8rem">📜</div>
                <p>Sin eventos registrados todavía</p>
              </div>
              <div v-else class="ld__eventos">
                <div v-for="e in eventos" :key="e._tipo + e.id" class="ld__evento">
                  <!-- Evento (cambio de ciclo, nota) -->
                  <template v-if="e._tipo === 'evento'">
                    <div class="ld__evento-dot" :style="{ background: e.tipo==='cambio_estado' ? '#1b5e20' : '#64748b' }"></div>
                    <div class="ld__evento-content">
                      <div class="ld__evento-head">
                        <span v-if="e.tipo==='cambio_estado'" class="ld__evento-titulo">
                          {{ em(e.estado_anterior).emoji }} {{ em(e.estado_anterior).label }}
                          <span class="ld__evento-arrow">→</span>
                          {{ em(e.estado_nuevo).emoji }} {{ em(e.estado_nuevo).label }}
                        </span>
                        <span v-else class="ld__evento-titulo">{{ e.descripcion }}</span>
                        <span class="ld__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
                      </div>
                      <div class="ld__evento-meta">{{ e.usuario }}</div>
                      <div v-if="e.tipo==='cambio_estado' && e.descripcion" class="ld__evento-desc">{{ e.descripcion }}</div>
                    </div>
                  </template>
                  <!-- Registro ambiental -->
                  <template v-else-if="e._tipo === 'registro'">
                    <div class="ld__evento-dot" style="background:#0891b2"></div>
                    <div class="ld__evento-content">
                      <div class="ld__evento-head">
                        <span class="ld__evento-titulo">
                          📋 Registro del lote
                          <span v-if="e.estado_general" :style="{ color: sm(e.estado_general).color }">· {{ sm(e.estado_general).emoji }} {{ e.estado_general }}</span>
                          <span v-if="e.fertilizacion" style="color:#1b5e20"> · 🌿 fertilización</span>
                          <span v-if="e.plagas_observadas && e.plagas_observadas !== 'ninguna'" :style="{ color: pgm(e.plagas_observadas).color }"> · {{ pgm(e.plagas_observadas).emoji }} {{ e.plagas_observadas }}</span>
                        </span>
                        <span class="ld__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
                      </div>
                      <div class="ld__evento-meta">{{ e.usuario }}</div>
                      <div class="ld__registro-metricas" style="margin-top:.35rem">
                        <div v-if="e.temperatura"          class="ld__metrica"><span>🌡️</span><span>{{ e.temperatura }}°C</span></div>
                        <div v-if="e.humedad"              class="ld__metrica"><span>💧</span><span>{{ e.humedad }}%</span></div>
                        <div v-if="e.vpd"                  class="ld__metrica"><span>🌬️</span><span>VPD {{ e.vpd }}</span></div>
                        <div v-if="e.ph"                   class="ld__metrica"><span>⚗️</span><span>pH {{ e.ph }}</span></div>
                        <div v-if="e.ec"                   class="ld__metrica"><span>⚡</span><span>EC {{ e.ec }}</span></div>
                        <div v-if="e.co2"                  class="ld__metrica"><span>💨</span><span>{{ e.co2 }}ppm</span></div>
                        <div v-if="e.horas_luz"            class="ld__metrica"><span>🕐</span><span>{{ e.horas_luz }}h luz</span></div>
                        <div v-if="e.tiene_csv"            class="ld__metrica" style="color:#1b5e20"><span>📎</span><span>CSV</span></div>
                      </div>
                      <div v-if="e.notas_fertilizacion" class="ld__evento-desc">{{ e.notas_fertilizacion }}</div>
                      <div v-if="e.observaciones"        class="ld__evento-desc">{{ e.observaciones }}</div>
                    </div>
                  </template>
                </div>
              </div>
            </div>
          </div>


          <!-- 4. Fotos -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="toggleFotos">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📷</span>
                <span class="ld__section-title">Fotos del lote</span>
                <span v-if="fotos.length > 0" class="ld__pill">{{ fotos.length }}</span>
              </div>
              <div class="ld__section-toggle-right">
                <button class="ld__btn-sm" @click.stop="fotoInput?.click()" :disabled="uploadingFoto">
                  <span v-if="uploadingFoto" class="ld__spinner" style="width:12px;height:12px;border-width:1.5px"></span>
                  <i v-else class="bi bi-camera-fill"></i>
                </button>
                <i class="bi ld__chevron" :class="fotosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
              </div>
            </button>
            <input ref="fotoInput" type="file" accept="image/*" style="display:none" @change="handleFotoUpload" />
            <div v-show="fotosExpanded" class="ld__section-body">
              <div v-if="fotos.length === 0" class="ld__empty ld__empty--sm">
                <div class="ld__empty-icon" style="font-size:2rem">📷</div>
                <p>Sin fotos todavía</p>
                <button class="ld__btn-outline" @click="fotoInput?.click()">
                  <i class="bi bi-camera-fill"></i> Subir primera foto
                </button>
              </div>
              <div v-else class="ld__fotos-grid">
                <div v-for="f in fotos" :key="f.id" class="ld__foto">
                  <img :src="f.url" :alt="f.filename" class="ld__foto-img" />
                  <div class="ld__foto-meta">{{ f.created_at_label }}</div>
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Aside -->
        <div class="ld__aside">

          <!-- Costo — solo admin/agricultor -->
          <div v-if="!isCultivador" class="ld__card" :class="costo ? 'ld__card--ok' : 'ld__card--warn'">
            <div class="ld__card-header">
              <span class="ld__card-title">💰 Costo</span>
              <button v-if="canEdit" class="ld__btn-xs" @click="openCostoModal">{{ costo ? "Editar" : "+ Cargar" }}</button>
            </div>
            <div class="ld__card-body">
              <div v-if="!costo" class="ld__costo-empty">
                <div style="font-size:2rem">📊</div>
                <p>Sin costo calculado</p>
                <span class="ld__costo-hint">Cargá el costo para habilitar el cálculo en dispensaciones</span>
              </div>
              <template v-else>
                <dl class="ld__costo-dl">
                  <dt>Insumos</dt><dd>{{ fmt(costo.costo_insumos) }}</dd>
                  <dt>Energía</dt><dd>{{ fmt(costo.costo_energia) }}</dd>
                  <dt>Mano de obra</dt><dd>{{ fmt(costo.costo_mano_obra) }}</dd>
                  <dt>Prorrateado</dt><dd>{{ fmt(costo.costo_prorrateado) }}</dd>
                </dl>
                <div class="ld__costo-total"><span>Total</span><span>{{ fmt(costo.costo_total) }}</span></div>
                <div v-if="costo.gramos_producidos" class="ld__costo-gramos"><span>Gramos</span><span>{{ costo.gramos_producidos }}g</span></div>
                <div v-if="costo.costo_por_gramo" class="ld__costo-pgrama"><span>Costo/gramo</span><span>{{ fmt(costo.costo_por_gramo) }}</span></div>
                <div v-if="costo.notas" class="ld__costo-notas">{{ costo.notas }}</div>
              </template>
            </div>
          </div>

          <!-- Datos técnicos -->
          <div class="ld__card" :class="!isCultivador ? 'ld__card--mt' : ''">
            <div class="ld__card-header"><span class="ld__card-title">⚙️ Datos técnicos</span></div>
            <dl class="ld__dl">
              <dt>Plantas</dt><dd><strong>{{ lote.plants_count ?? 0 }}</strong></dd>
              <dt>Capacidad</dt><dd>{{ lote.tamanio_maceta ? lote.plants_count + ' × ' + lote.tamanio_maceta + 'L' : '—' }}</dd>
              <dt>Tipo cultivo</dt><dd>{{ growLabel(lote.grow_type) }}</dd>
              <dt>Luminaria</dt><dd>{{ lightLabel(lote.light_type) }}</dd>
              <dt>Genética</dt><dd>{{ lote.strain || '—' }}</dd>
              <dt>Sustrato</dt><dd>{{ lote.sustrato_especifico || '—' }}</dd>
              <dt>Fotoperiodo</dt><dd>{{ lote.fotoperiodo || '—' }}</dd>
              <dt>Semanas flor.</dt><dd>{{ lote.semanas_floracion ? lote.semanas_floracion + ' sem.' : '—' }}</dd>
              <dt>Inicio</dt><dd>{{ lote.start_date || '—' }}</dd>
              <dt>Días ciclo</dt><dd>{{ lote.dias_desde_inicio ?? '—' }}</dd>
            </dl>
          </div>

          <!-- Información -->
          <div class="ld__card ld__card--mt">
            <div class="ld__card-header"><span class="ld__card-title">ℹ️ Información</span></div>
            <dl class="ld__dl">
              <dt>Sala</dt>
              <dd>
                <RouterLink v-if="lote.sala" :to="{ name:'sala-detail', params:{ id:lote.sala.id } }" class="ld__link">{{ lote.sala.nombre }}</RouterLink>
                <span v-else>—</span>
              </dd>
              <dt>Creado</dt><dd>{{ formatDate(lote.created_at) }}</dd>
              <dt>Actualizado</dt><dd>{{ formatDate(lote.updated_at) }}</dd>
            </dl>
          </div>

          <div v-if="lote.notes" class="ld__card ld__card--mt">
            <div class="ld__card-header"><span class="ld__card-title">📋 Notas</span></div>
            <div class="ld__card-notes">{{ lote.notes }}</div>
          </div>

        </div>
      </div>
    </template>

    <!-- ══ Modal Registro del Lote ══ -->
    <Teleport to="body">
      <div v-if="showRegistroModal" class="ld__overlay" @click.self="showRegistroModal = false">
        <div class="ld__modal">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">📋 Registro del lote</h3>
              <p class="ld__modal-sub">{{ lote?.codigo }} · {{ new Date().toLocaleDateString('es-AR') }}</p>
            </div>
            <button class="ld__modal-close" @click="showRegistroModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="registroError" class="ld__alert">{{ registroError }}</div>

            <!-- Estado general y plagas -->
            <div class="ld__grid">
              <div class="ld__field ld__field--full">
                <label class="ld__label">Estado general</label>
                <div class="ld__selector">
                  <button v-for="(meta, key) in ESTADO_SALUD_META" :key="key" type="button"
                          class="ld__sel-btn"
                          :class="{ 'ld__sel-btn--active': registroForm.estado_general === key }"
                          :style="registroForm.estado_general===key ? {borderColor:meta.color,background:meta.color+'15',color:meta.color} : {}"
                          @click="registroForm.estado_general = key">
                    {{ meta.emoji }} {{ key }}
                  </button>
                </div>
              </div>
              <div class="ld__field ld__field--full">
                <label class="ld__label">Plagas</label>
                <div class="ld__selector">
                  <button v-for="(meta, key) in PLAGAS_META" :key="key" type="button"
                          class="ld__sel-btn"
                          :class="{ 'ld__sel-btn--active': registroForm.plagas_observadas === key }"
                          :style="registroForm.plagas_observadas===key ? {borderColor:meta.color,background:meta.color+'15',color:meta.color} : {}"
                          @click="registroForm.plagas_observadas = key">
                    {{ meta.emoji }} {{ key }}
                  </button>
                </div>
              </div>
            </div>

            <div class="ld__modal-section-title">Ambiente</div>
            <div class="ld__grid">
              <div class="ld__field">
                <label class="ld__label">Temperatura aire (°C)</label>
                <input type="number" step="0.1" class="ld__input" :class="{'ld__input--err':registroErrors.temperatura}" v-model.number="registroForm.temperatura" placeholder="24.5" />
                <span v-if="registroErrors.temperatura" class="ld__err-msg">{{ registroErrors.temperatura }}</span>
              </div>
              <div class="ld__field">
                <label class="ld__label">Temperatura sustrato (°C)</label>
                <input type="number" step="0.1" class="ld__input" :class="{'ld__input--err':registroErrors.temperatura_sustrato}" v-model.number="registroForm.temperatura_sustrato" placeholder="22.0" />
                <span v-if="registroErrors.temperatura_sustrato" class="ld__err-msg">{{ registroErrors.temperatura_sustrato }}</span>
              </div>
              <div class="ld__field">
                <label class="ld__label">Humedad (%)</label>
                <input type="number" step="0.1" class="ld__input" :class="{'ld__input--err':registroErrors.humedad}" v-model.number="registroForm.humedad" placeholder="60" />
                <span v-if="registroErrors.humedad" class="ld__err-msg">{{ registroErrors.humedad }}</span>
              </div>
              <div class="ld__field">
                <label class="ld__label">CO₂ (ppm)</label>
                <input type="number" step="1" class="ld__input" v-model.number="registroForm.co2" placeholder="1200" />
              </div>
            </div>

            <div class="ld__modal-section-title">Agua</div>
            <div class="ld__grid">
              <div class="ld__field">
                <label class="ld__label">pH entrada</label>
                <input type="number" step="0.1" class="ld__input" :class="{'ld__input--err':registroErrors.ph}" v-model.number="registroForm.ph" placeholder="6.2" />
                <span v-if="registroErrors.ph" class="ld__err-msg">{{ registroErrors.ph }}</span>
              </div>
              <div class="ld__field">
                <label class="ld__label">pH runoff</label>
                <input type="number" step="0.1" class="ld__input" :class="{'ld__input--err':registroErrors.ph_runoff}" v-model.number="registroForm.ph_runoff" placeholder="6.0" />
                <span v-if="registroErrors.ph_runoff" class="ld__err-msg">{{ registroErrors.ph_runoff }}</span>
              </div>
              <div class="ld__field">
                <label class="ld__label">EC (mS/cm)</label>
                <input type="number" step="0.1" class="ld__input" v-model.number="registroForm.ec" placeholder="1.8" />
              </div>
            </div>

            <div class="ld__modal-section-title">Luz</div>
            <div class="ld__grid">
              <div class="ld__field">
                <label class="ld__label">Horas de luz</label>
                <input type="number" step="0.5" class="ld__input" :class="{'ld__input--err':registroErrors.horas_luz}" v-model.number="registroForm.horas_luz" placeholder="18" />
                <span v-if="registroErrors.horas_luz" class="ld__err-msg">{{ registroErrors.horas_luz }}</span>
              </div>
              <div class="ld__field">
                <label class="ld__label">Espectro</label>
                <select class="ld__input" v-model="registroForm.espectro_luz">
                  <option value="">Sin especificar</option>
                  <option value="veg">Vegetativo (azul)</option>
                  <option value="bloom">Floración (rojo)</option>
                  <option value="auto">Automático</option>
                </select>
              </div>
              <div class="ld__field">
                <label class="ld__label">PPFD <span class="ld__optional">opcional</span></label>
                <input type="number" step="1" class="ld__input" v-model.number="registroForm.ppfd" placeholder="600" />
              </div>
            </div>

            <!-- Fertilización toggle -->
            <div class="ld__modal-section-title">Fertilización</div>
            <div class="ld__field ld__field--full">
              <label class="ld__toggle">
                <input type="checkbox" v-model="registroForm.fertilizacion" class="ld__toggle-input" />
                <div class="ld__toggle-track"><div class="ld__toggle-thumb"></div></div>
                <span class="ld__toggle-label">Se realizó fertilización en este registro</span>
              </label>
              <textarea v-if="registroForm.fertilizacion" class="ld__input ld__textarea"
                        style="margin-top:.6rem" rows="2"
                        v-model.trim="registroForm.notas_fertilizacion"
                        placeholder="Ej: Base A 10ml/L + Base B 10ml/L · Marca: GHE"></textarea>
            </div>

            <!-- CSV -->
            <div class="ld__modal-section-title">Datos de sensor <span class="ld__optional">opcional</span></div>
            <div class="ld__field">
              <div class="ld__csv-upload" @click="csvInput?.click()">
                <i class="bi bi-file-earmark-spreadsheet"></i>
                <span v-if="csvFile">{{ csvFile.name }}</span>
                <span v-else>Subir CSV (Bluelab, Apogee, etc.)</span>
              </div>
              <input ref="csvInput" type="file" accept=".csv,.txt" style="display:none" @change="handleCsvChange" />
              <span class="ld__field-hint">Se almacena para procesamiento futuro con IA</span>
            </div>

            <!-- Observaciones -->
            <div class="ld__field ld__field--full" style="margin-top:1rem">
              <label class="ld__label">Observaciones <span class="ld__optional">opcional</span></label>
              <textarea class="ld__input ld__textarea" rows="2" v-model.trim="registroForm.observaciones" placeholder="Cualquier observación relevante…"></textarea>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingRegistro" @click="showRegistroModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingRegistro || Object.keys(registroErrors).length > 0" @click="guardarRegistro">
              <div v-if="savingRegistro" class="ld__spinner ld__spinner--sm"></div>
              <i v-else class="bi bi-check-lg"></i>Guardar registro
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Avanzar Ciclo ══ -->
    <Teleport to="body">
      <div v-if="showCicloModal" class="ld__overlay" @click.self="showCicloModal = false">
        <div class="ld__modal" style="max-width:440px">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">🔄 Avanzar ciclo</h3>
              <p class="ld__modal-sub">{{ lote?.codigo }} · ahora en {{ em(lote?.estado).label }}</p>
            </div>
            <button class="ld__modal-close" @click="showCicloModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="eventoError" class="ld__alert">{{ eventoError }}</div>
            <div class="ld__field" style="margin-bottom:1rem">
              <label class="ld__label">Nueva etapa</label>
              <div class="ld__etapas-selector">
                <button v-for="etapa in estadosSiguientes" :key="etapa" type="button"
                        class="ld__etapa-btn"
                        :class="{ 'ld__etapa-btn--active': cicloForm.estado_nuevo === etapa }"
                        :style="cicloForm.estado_nuevo===etapa ? {borderColor:em(etapa).color,background:em(etapa).bg,color:em(etapa).color} : {}"
                        @click="cicloForm.estado_nuevo = etapa">
                  {{ em(etapa).emoji }} {{ em(etapa).label }}
                </button>
              </div>
            </div>
            <div class="ld__field">
              <label class="ld__label">Notas <span class="ld__optional">opcional</span></label>
              <textarea class="ld__input ld__textarea" rows="2" v-model="cicloForm.descripcion" placeholder="Motivo del cambio, observaciones..."></textarea>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" @click="showCicloModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="!cicloForm.estado_nuevo || savingEvento" @click="cambiarCiclo">
              <div v-if="savingEvento" class="ld__spinner ld__spinner--sm"></div>
              <i v-else class="bi bi-check-lg"></i>Confirmar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Costo ══ -->
    <Teleport to="body">
      <div v-if="showCostoModal && !isCultivador" class="ld__overlay" @click.self="showCostoModal = false">
        <div class="ld__modal">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">{{ costo ? "Editar" : "Cargar" }} costo</h3>
              <p class="ld__modal-sub">{{ lote?.codigo }}</p>
            </div>
            <button class="ld__modal-close" @click="showCostoModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="costoError" class="ld__alert">{{ costoError }}</div>
            <div class="ld__grid">
              <div class="ld__field">
                <label class="ld__label">Insumos (ARS)</label>
                <div class="ld__input-group"><span class="ld__input-prefix">$</span>
                  <input type="number" min="0" step="0.01" class="ld__input ld__input--prefixed" v-model.number="costoForm.costo_insumos" /></div>
              </div>
              <div class="ld__field">
                <label class="ld__label">Energía (ARS)</label>
                <div class="ld__input-group"><span class="ld__input-prefix">$</span>
                  <input type="number" min="0" step="0.01" class="ld__input ld__input--prefixed" v-model.number="costoForm.costo_energia" /></div>
              </div>
              <div class="ld__field">
                <label class="ld__label">Mano de obra (ARS)</label>
                <div class="ld__input-group"><span class="ld__input-prefix">$</span>
                  <input type="number" min="0" step="0.01" class="ld__input ld__input--prefixed" v-model.number="costoForm.costo_mano_obra" /></div>
              </div>
              <div class="ld__field">
                <label class="ld__label">Prorrateados (ARS)</label>
                <div class="ld__input-group"><span class="ld__input-prefix">$</span>
                  <input type="number" min="0" step="0.01" class="ld__input ld__input--prefixed" v-model.number="costoForm.costo_prorrateado" /></div>
              </div>
              <div class="ld__field ld__field--full">
                <label class="ld__label">Gramos producidos</label>
                <div class="ld__input-group">
                  <input type="number" min="0.01" step="0.01" class="ld__input" v-model.number="costoForm.gramos_producidos" placeholder="250" />
                  <span class="ld__input-suffix">g</span></div>
              </div>
              <div class="ld__field ld__field--full">
                <div class="ld__costo-preview">
                  <div class="ld__costo-preview-row"><span>Total</span><span class="ld__costo-preview-val">{{ fmt(costoTotal) }}</span></div>
                  <div v-if="costoPorGramoPreview" class="ld__costo-preview-row ld__costo-preview-row--highlight"><span>Costo/gramo</span><span class="ld__costo-preview-val">{{ fmt(costoPorGramoPreview) }}</span></div>
                  <div v-else class="ld__costo-preview-hint">Ingresá gramos para ver el costo/gramo</div>
                </div>
              </div>
              <div class="ld__field ld__field--full">
                <label class="ld__label">Notas <span class="ld__optional">opcional</span></label>
                <textarea class="ld__input ld__textarea" rows="2" v-model.trim="costoForm.notas" placeholder="Observaciones…"></textarea>
              </div>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingCosto" @click="showCostoModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingCosto" @click="submitCosto">
              <div v-if="savingCosto" class="ld__spinner ld__spinner--sm"></div>
              <i v-else class="bi bi-check-lg"></i>Guardar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.ld { padding: 1.75rem 1.5rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .ld { padding: 1rem; } }
.ld__breadcrumb { display: flex; align-items: center; gap: .4rem; font-size: .78rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.ld__breadcrumb-link { color: #94a3b8; text-decoration: none; transition: color .15s; }
.ld__breadcrumb-link:hover { color: #1b5e20; }
.ld__breadcrumb-sep { color: #cbd5e1; }
.ld__breadcrumb-current { color: #1a1a1a; font-weight: 600; }
.ld__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.ld__error { padding: 1rem 1.25rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 10px; font-size: .875rem; }
.ld__spinner { width: 20px; height: 20px; border: 2.5px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: ld-spin .6s linear infinite; flex-shrink: 0; }
.ld__spinner--sm { width: 14px; height: 14px; border-color: rgba(255,255,255,.3); border-top-color: #fff; }
@keyframes ld-spin { to { transform: rotate(360deg); } }
.ld__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.ld__hero-title-row { display: flex; align-items: center; gap: .65rem; margin-bottom: .35rem; flex-wrap: wrap; }
.ld__hero-emoji { font-size: 1.8rem; }
.ld__title { font-size: 1.8rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.ld__estado-pill { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; padding: .28em .75em; border-radius: 999px; }
.ld__subtitle { font-size: .85rem; color: #60725d; margin: 0; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.ld__subtitle-sep { color: #cbd5e1; }
.ld__dias-badge { background: #e8f5e9; color: #1b5e20; font-size: .75rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; }
.ld__hero-actions { display: flex; gap: .5rem; flex-wrap: wrap; }
.ld__ciclo { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.25rem 1.5rem 1rem; margin-bottom: 1.5rem; overflow-x: auto; }
.ld__ciclo-track { display: flex; align-items: flex-start; position: relative; min-width: 480px; }
.ld__ciclo-step { display: flex; flex-direction: column; align-items: center; flex: 1; position: relative; }
.ld__ciclo-dot { width: 36px; height: 36px; border-radius: 50%; background: #e8f5e9; border: 2px solid #d4e6d4; display: flex; align-items: center; justify-content: center; margin-bottom: .4rem; transition: all .2s; position: relative; z-index: 1; }
.ld__ciclo-emoji { font-size: .9rem; }
.ld__ciclo-label { font-size: .58rem; font-weight: 600; color: #94a3b8; text-align: center; text-transform: uppercase; letter-spacing: .03em; }
.ld__ciclo-step--done .ld__ciclo-dot    { background: #dcfce7; border-color: #16a34a; }
.ld__ciclo-step--done .ld__ciclo-label  { color: #16a34a; }
.ld__ciclo-step--current .ld__ciclo-dot { background: #1b5e20; border-color: #1b5e20; box-shadow: 0 0 0 4px rgba(27,94,32,.15); }
.ld__ciclo-step--current .ld__ciclo-label { color: #1b5e20; font-weight: 800; }
.ld__ciclo-step--pending { opacity: .4; }
.ld__ciclo-connector { position: absolute; top: 17px; left: 50%; width: 100%; height: 2px; background: #d4e6d4; }
.ld__ciclo-connector--done { background: #16a34a; }
.ld__ciclo-progress { height: 4px; background: #e8f5e9; border-radius: 999px; overflow: hidden; margin-top: .75rem; }
.ld__ciclo-progress-fill { height: 100%; background: linear-gradient(90deg, #16a34a, #1b5e20); border-radius: 999px; transition: width .5s ease; }
.ld__layout { display: grid; grid-template-columns: 1fr 300px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .ld__layout { grid-template-columns: 1fr; } }
.ld__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.ld__section--mt { margin-top: 1.25rem; }
.ld__section-toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; background: transparent; border: none; cursor: pointer; transition: background .15s; text-align: left; }
.ld__section-toggle:hover { background: #f0fdf4; }
.ld__section-toggle-left { display: flex; align-items: center; gap: .6rem; }
.ld__section-toggle-right { display: flex; align-items: center; gap: .5rem; }
.ld__section-emoji { font-size: 1rem; }
.ld__section-title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.ld__pill { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; }
.ld__pill--wip { background: #fef3c7; color: #b45309; }
.ld__chevron { color: #60725d; font-size: .75rem; }
.ld__section-body { border-top: 1px solid #e8f0e9; padding: 1rem 1.1rem; }
.ld__section-body--flush { padding: 0; border-top: 1px solid #e8f0e9; }
.ld__plantas { display: flex; flex-direction: column; }
.ld__planta { display: flex; align-items: center; gap: .75rem; padding: .75rem 1.1rem; text-decoration: none; color: inherit; border-bottom: 1px solid #f0fdf4; transition: background .15s; }
.ld__planta:last-child { border-bottom: none; }
.ld__planta:hover { background: #f9fdf9; }
.ld__planta-num { font-size: .72rem; color: #94a3b8; font-weight: 600; width: 20px; text-align: right; flex-shrink: 0; }
.ld__planta-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.ld__planta-info { flex: 1; min-width: 0; }
.ld__planta-nombre { font-size: .85rem; font-weight: 600; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ld__planta-qr { font-size: .7rem; color: #94a3b8; font-family: monospace; }
.ld__planta-estado { font-size: .68rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; white-space: nowrap; flex-shrink: 0; }
.ld__planta-arrow { color: #a7d7a9; font-size: .75rem; flex-shrink: 0; }
.ld__registros { display: flex; flex-direction: column; }
.ld__registro { padding: .85rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.ld__registro:last-child { border-bottom: none; }
.ld__registro-header { display: flex; align-items: center; gap: .5rem; margin-bottom: .5rem; flex-wrap: wrap; }
.ld__registro-fecha { font-size: .78rem; font-weight: 700; color: #1a1a1a; }
.ld__registro-badge { font-size: .7rem; font-weight: 700; text-transform: capitalize; }
.ld__registro-usuario { font-size: .7rem; color: #94a3b8; margin-left: auto; }
.ld__csv-badge { font-size: .65rem; font-weight: 700; background: #e8f5e9; color: #1b5e20; padding: .15em .5em; border-radius: 4px; }
.ld__registro-metricas { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: .35rem; }
.ld__metrica { display: flex; align-items: center; gap: .25rem; background: #f4f8f4; border: 1px solid #d4e6d4; border-radius: 6px; padding: .2em .55em; font-size: .72rem; font-weight: 600; color: #1a1a1a; }
.ld__registro-obs { font-size: .75rem; color: #60725d; font-style: italic; margin-top: .25rem; }
.ld__eventos { display: flex; flex-direction: column; }
.ld__evento { display: flex; gap: .75rem; padding: .85rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.ld__evento:last-child { border-bottom: none; }
.ld__evento-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .3rem; }
.ld__evento-content { flex: 1; min-width: 0; }
.ld__evento-head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; margin-bottom: .2rem; }
.ld__evento-titulo { font-size: .85rem; font-weight: 600; color: #1a1a1a; }
.ld__evento-arrow { color: #94a3b8; margin: 0 .25rem; }
.ld__evento-fecha { font-size: .7rem; color: #94a3b8; white-space: nowrap; flex-shrink: 0; }
.ld__evento-meta { font-size: .72rem; color: #94a3b8; }
.ld__evento-desc { font-size: .75rem; color: #60725d; margin-top: .25rem; font-style: italic; }
.ld__selector { display: flex; gap: .4rem; flex-wrap: wrap; }
.ld__sel-btn { display: flex; align-items: center; gap: .3rem; padding: .4rem .8rem; border: 1.5px solid #d4e6d4; border-radius: 8px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; text-transform: capitalize; }
.ld__sel-btn:hover { border-color: #1b5e20; }
.ld__sel-btn--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.ld__etapas-selector { display: flex; gap: .5rem; flex-wrap: wrap; }
.ld__etapa-btn { display: flex; align-items: center; gap: .4rem; padding: .5rem 1rem; border: 1.5px solid #d4e6d4; border-radius: 10px; background: #f4f8f4; font-size: .85rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.ld__etapa-btn:hover { border-color: #1b5e20; }
.ld__etapa-btn--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.1); }
.ld__toggle { display: flex; align-items: center; gap: .65rem; cursor: pointer; }
.ld__toggle-input { display: none; }
.ld__toggle-track { width: 38px; height: 21px; background: #d4e6d4; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.ld__toggle-input:checked + .ld__toggle-track { background: #1b5e20; }
.ld__toggle-thumb { position: absolute; width: 15px; height: 15px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.ld__toggle-input:checked + .ld__toggle-track .ld__toggle-thumb { left: 20px; }
.ld__toggle-label { font-size: .875rem; font-weight: 500; color: #1a1a1a; }
.ld__csv-upload { display: flex; align-items: center; gap: .75rem; padding: .85rem 1rem; border: 1.5px dashed #d4e6d4; border-radius: 10px; background: #f4f8f4; cursor: pointer; font-size: .85rem; color: #60725d; transition: all .15s; }
.ld__csv-upload:hover { border-color: #1b5e20; background: #f0fdf4; color: #1b5e20; }
.ld__csv-upload i { font-size: 1.2rem; }
.ld__field-hint { font-size: .72rem; color: #94a3b8; margin-top: .3rem; }
.ld__modal-section-title { font-size: .72rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .06em; margin: 1.1rem 0 .6rem; padding-bottom: .4rem; border-bottom: 1px solid #e8f0e9; }
.ld__wip { display: flex; flex-direction: column; align-items: center; text-align: center; gap: .4rem; padding: 1.5rem 1rem; }
.ld__fotos-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: .75rem; padding: 1rem 1.1rem; }
.ld__foto { border-radius: 10px; overflow: hidden; border: 1px solid #d4e6d4; }
.ld__foto-img { width: 100%; height: 120px; object-fit: cover; display: block; }
.ld__foto-meta { font-size: .65rem; color: #94a3b8; padding: .3rem .5rem; background: #f4f8f4; text-align: center; }
.ld__wip-icon { font-size: 2rem; }
.ld__wip-title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.ld__wip-desc { font-size: .78rem; color: #60725d; max-width: 300px; }
.ld__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.ld__card--mt { margin-top: 1rem; }
.ld__card--ok { border-color: #a7d7a9; border-left: 4px solid #16a34a; }
.ld__card--warn { border-color: #fde68a; border-left: 4px solid #d97706; }
.ld__card-header { display: flex; align-items: center; justify-content: space-between; padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; }
.ld__card-title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.ld__card-body { padding: 1rem; }
.ld__card-notes { padding: .9rem 1rem; font-size: .82rem; color: #475569; line-height: 1.6; }
.ld__dl { display: grid; grid-template-columns: auto 1fr; gap: .4rem .75rem; padding: .9rem 1rem; margin: 0; }
.ld__dl dt { font-size: .75rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.ld__dl dd { font-size: .8rem; color: #1a1a1a; font-weight: 500; margin: 0; }
.ld__link { color: #1b5e20; text-decoration: none; font-weight: 600; }
.ld__link:hover { text-decoration: underline; }
.ld__costo-empty { text-align: center; padding: .75rem 0; color: #60725d; }
.ld__costo-empty p { font-size: .85rem; font-weight: 600; margin: .5rem 0 .25rem; }
.ld__costo-hint { font-size: .72rem; color: #94a3b8; }
.ld__costo-dl { display: grid; grid-template-columns: 1fr auto; gap: .35rem .75rem; margin-bottom: .75rem; }
.ld__costo-dl dt { font-size: .75rem; color: #60725d; font-weight: 500; }
.ld__costo-dl dd { font-size: .75rem; font-weight: 600; color: #1a1a1a; text-align: right; margin: 0; }
.ld__costo-total { display: flex; justify-content: space-between; font-weight: 700; font-size: .85rem; padding-top: .5rem; border-top: 1px solid #e8f0e9; margin-bottom: .35rem; }
.ld__costo-gramos { display: flex; justify-content: space-between; font-size: .75rem; color: #60725d; }
.ld__costo-pgrama { display: flex; justify-content: space-between; font-size: .85rem; font-weight: 800; color: #1b5e20; margin-top: .35rem; }
.ld__costo-notas { font-size: .75rem; color: #60725d; border-top: 1px solid #e8f0e9; margin-top: .75rem; padding-top: .75rem; }
.ld__costo-preview { background: #f0fdf4; border: 1.5px solid #d4e6d4; border-radius: 10px; padding: .85rem 1rem; }
.ld__costo-preview-row { display: flex; justify-content: space-between; font-size: .85rem; color: #60725d; }
.ld__costo-preview-row+.ld__costo-preview-row { margin-top: .35rem; }
.ld__costo-preview-row--highlight { font-weight: 800; color: #1b5e20; font-size: .95rem; margin-top: .5rem; padding-top: .5rem; border-top: 1px solid #d4e6d4; }
.ld__costo-preview-val { font-weight: 700; }
.ld__costo-preview-hint { font-size: .75rem; color: #94a3b8; text-align: center; }
.ld__empty { text-align: center; padding: 2.5rem 1rem; color: #60725d; }
.ld__empty--sm { padding: 1.5rem 1rem; }
.ld__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; }
.ld__empty p { font-size: .875rem; margin: 0 0 .75rem; }
.ld__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }
.ld__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; text-decoration: none; }
.ld__btn-primary:hover { background: #104417; }
.ld__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.ld__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #e8f5e9; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-secondary:hover { background: #d4e6d4; }
.ld__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.ld__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }
.ld__btn-ghost-sm { display: inline-flex; align-items: center; gap: .35rem; background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .5rem .9rem; border-radius: 8px; font-size: .8rem; font-weight: 500; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-ghost-sm:hover { background: #f0fdf4; color: #1b5e20; border-color: #1b5e20; }
.ld__btn-outline { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .5rem 1.1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; text-decoration: none; }
.ld__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }
.ld__btn-sm { display: inline-flex; align-items: center; gap: .3rem; background: #e8f5e9; color: #1b5e20; border: 1px solid #d4e6d4; padding: .35rem .65rem; border-radius: 7px; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; text-decoration: none; }
.ld__btn-sm:hover { background: #1b5e20; color: #fff; }
.ld__btn-xs { background: #e8f5e9; color: #1b5e20; border: 1px solid #d4e6d4; padding: .25rem .65rem; border-radius: 6px; font-size: .72rem; font-weight: 700; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-xs:hover { background: #1b5e20; color: #fff; }
.ld__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.ld__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 600px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.ld__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.ld__modal-title { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.ld__modal-sub { font-size: .78rem; color: #60725d; margin: .2rem 0 0; }
.ld__modal-close { background: #e8f5e9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0; }
.ld__modal-close:hover { background: #c8e6c9; color: #1b5e20; }
.ld__modal-body { padding: 1.25rem 1.5rem; flex: 1; }
.ld__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }
.ld__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .ld__grid { grid-template-columns: 1fr; } }
.ld__field { display: flex; flex-direction: column; gap: .35rem; }
.ld__field--full { grid-column: 1 / -1; }
.ld__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ld__optional { font-size: .68rem; font-weight: 500; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.ld__req { color: #dc2626; }
.ld__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.ld__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.ld__input--err { border-color: #dc2626; }
.ld__input--prefixed { border-radius: 0 8px 8px 0; }
.ld__textarea { resize: vertical; min-height: 60px; }
.ld__input-group { display: flex; }
.ld__input-prefix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-right: none; padding: .6rem .75rem; font-size: .85rem; font-weight: 600; color: #1b5e20; border-radius: 8px 0 0 8px; white-space: nowrap; }
.ld__input-suffix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .6rem .75rem; font-size: .85rem; font-weight: 600; color: #1b5e20; border-radius: 0 8px 8px 0; white-space: nowrap; }
.ld__err-msg { font-size: .75rem; color: #dc2626; }
.ld__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }
</style>
