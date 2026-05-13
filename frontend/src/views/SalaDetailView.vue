<script setup>
import { onMounted, onUnmounted, ref, computed, watch } from "vue"
import { logger } from '../utils/logger.js'
import { useRoute, useRouter } from "vue-router"
import { useSalasStore } from "../stores/salas"
import { useLotesStore } from "../stores/lotes"
import { useAuthStore } from "../stores/auth"
import SalaCultivadoresManager from '../components/SalaCultivadoresManager.vue'
import ModalCargarLote from '../components/salas/ModalCargarLote.vue'
import RegistrarLecturaModal from '../components/salas/RegistrarLecturaModal.vue'
import { listGeneticas, listPlants, updateSala, getSalaAmbiente, deleteSala } from '../lib/api.js'
import { useConfirm } from '../composables/useConfirm.js'
import AsistenteVoz from '../components/AsistenteVoz.vue'
import { Gauge } from 'lucide-vue-next'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import { useToast } from '../composables/useToast.js'
import SemaforoAmbiente from '../components/ambiente/SemaforoAmbiente.vue'

const route  = useRoute()
const router = useRouter()
const salas  = useSalasStore()
const lotes  = useLotesStore()
const auth   = useAuthStore()
const toast  = useToast()
const { confirm } = useConfirm()

const deleting = ref(false)
async function eliminarSala() {
  const ok = await confirm({
    title: 'Eliminar sala',
    message: `¿Seguro que querés eliminar "${sala.value?.nombre}"? Los lotes y plantas quedarán archivados (soft delete) y podrán recuperarse si es necesario.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  deleting.value = true
  try {
    await deleteSala(salaId)
    toast.success('Sala eliminada')
    router.push({ name: 'salas' })
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al eliminar la sala')
  } finally {
    deleting.value = false
  }
}

const salaId  = Number(route.params.id) || 0
const loading = ref(true)
const error   = ref(null)

const canEdit        = computed(() => ['admin', 'supervisor'].includes(auth.role))
const isCultivador   = computed(() => auth.role === "cultivador")
const isManicurador  = computed(() => auth.role === "manicura")
const isAgricultor   = computed(() => auth.role === "cultivador")

const lecturaOpen   = ref(false)
const lotesExpanded = ref(true)

const ESTADOS_LOTE = ["semilla","esqueje","vegetativo","floracion","cosecha","curado","finalizado"]
const DIAS_CICLO   = { semilla:7, esqueje:7, vegetativo:45, floracion:65, cosecha:10, curado:14, finalizado:0 }

// ── Genéticas ──────────────────────────────────────────────
const geneticas = ref([])

// ── Cámara ─────────────────────────────────────────────────
const showCameraForm = ref(false)
const savingCamera   = ref(false)
const cameraError    = ref(false)
const snapshotKey    = ref(0)
const snapshotTs     = ref('')
const cameraForm     = ref({ camera_stream_url: '', camera_snapshot_url: '' })

const snapshotSrc = computed(() => {
  const url = sala.value?.camera_snapshot_url || sala.value?.camera_stream_url
  if (!url) return ''
  return url + (url.includes('?') ? '&' : '?') + '_t=' + snapshotKey.value
})

function refreshSnapshot() {
  cameraError.value = false
  snapshotKey.value = Date.now()
  snapshotTs.value  = new Date().toLocaleTimeString('es-AR')
}

async function saveCamera() {
  savingCamera.value = true
  try {
    await updateSala(salaId, cameraForm.value)
    await salas.fetchOne(salaId)
    showCameraForm.value = false
    toast.success('Cámara configurada')
  } catch { toast.error('Error al guardar la cámara') }
  finally { savingCamera.value = false }
}

// ── Editar sala ────────────────────────────────────────────
const showEditSala   = ref(false)
const editSalaForm   = ref({})
const editSalaError  = ref(null)
const savingEditSala = ref(false)

const SALA_KINDS = [
  { value: 'vegetativo', label: 'Vegetativo' },
  { value: 'floracion',  label: 'Floración'  },
  { value: 'mixta',      label: 'Mixta'      },
  { value: 'madre',      label: 'Madres'     },
  { value: 'clon',       label: 'Clones'     },
  { value: 'secado',     label: 'Secado'     },
]

function openEditSala() {
  editSalaForm.value = {
    nombre: sala.value.nombre || '',
    kind:   sala.value.kind   || '',
    notes:  sala.value.notes  || '',
  }
  editSalaError.value = null
  showEditSala.value  = true
}

async function saveEditSala() {
  if (!editSalaForm.value.nombre?.trim()) { editSalaError.value = 'El nombre es obligatorio'; return }
  savingEditSala.value = true
  editSalaError.value  = null
  try {
    await updateSala(salaId, editSalaForm.value)
    await salas.fetchSala(salaId)
    showEditSala.value = false
    toast.success('Sala actualizada')
  } catch (e) {
    editSalaError.value = e?.response?.data?.error || 'Error al guardar'
  } finally {
    savingEditSala.value = false
  }
}

function salaEscapeHandler(e) {
  if (e.key !== 'Escape') return
  if (showEditSala.value)    { showEditSala.value = false; return }
  if (showCreate.value)      { closeCreate(); return }
  if (showCargarLote.value)  { showCargarLote.value = false; return }
  if (showUpgrade.value)     { showUpgrade.value = false; return }
  if (lecturaOpen.value)     { lecturaOpen.value = false; return }
}

onMounted(async () => {
  document.addEventListener('keydown', salaEscapeHandler, true)
  try {
    await salas.fetchSala(salaId)
    await lotes.fetchBySala(salaId)
  } catch { error.value = "No se pudo cargar la sala." }
  finally  { loading.value = false }

  try {
    const res = await listGeneticas({ activa: true, disponible: true })
    geneticas.value = res.data || []
  } catch { /* genéticas no críticas */ }

  if (canSeeAmbiente.value) cargarAmbienteMini()
})

onUnmounted(() => {
  document.removeEventListener('keydown', salaEscapeHandler, true)
})

const sala  = computed(() => salas.currentSala)
const items = computed(() => lotes.bySala(salaId))

watch(() => sala.value?.camera_stream_url, (url) => {
  if (url) {
    cameraForm.value.camera_stream_url   = url
    cameraForm.value.camera_snapshot_url = sala.value?.camera_snapshot_url || ''
    refreshSnapshot()
  }
}, { immediate: true })

const contextoAsistente = computed(() => sala.value ? {
  tipo:        'sala',
  sala_id:     sala.value.id,
  sala_nombre: sala.value.nombre,
} : null)

// ── Cambiar estado de sala ──────────────────────────────────
const cambiandoEstado = ref(false)
const ESTADOS_SALA = [
  { value: 'activa',        label: 'Activa',          style: 'background:#dcfce7;color:#15803d' },
  { value: 'mantenimiento', label: 'En mantenimiento', style: 'background:#fef3c7;color:#b45309' },
  { value: 'cerrada',       label: 'Cerrada',          style: 'background:#f1f5f9;color:#64748b' },
]
async function cambiarEstado(nuevoEstado) {
  if (!sala.value || sala.value.state === nuevoEstado) return
  cambiandoEstado.value = true
  try {
    await updateSala(salaId, { state: nuevoEstado })
    await salas.fetchSala(salaId)
    toast.success('Estado de la sala actualizado')
  } catch (e) {
    logger.error('Error cambiando estado:', e)
    toast.error('Error al cambiar el estado')
  } finally {
    cambiandoEstado.value = false
  }
}

// ── KPIs ───────────────────────────────────────────────────
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
  semilla:    { label:"Semilla",  color:"#64748b", emoji:"🌱" },
  esqueje:    { label:"Esqueje",  color:"#16a34a", emoji:"🪴" },
  vegetativo: { label:"Vegetativo",      color:"#16a34a", emoji:"🌱" },
  floracion:  { label:"Floración",       color:"#d97706", emoji:"🌸" },
  cosecha:    { label:"Cosecha",         color:"#92400e", emoji:"✂️" },
  curado:     { label:"Curado",          color:"#2563eb", emoji:"🍂" },
  finalizado: { label:"Finalizado",      color:"#1b5e20", emoji:"✅" },
}
function estadoMeta(e) { return ESTADO_META[e] || { label:e, color:"#64748b", emoji:"📦" } }
function growLabel(g)  { return { sustrato:"Sustrato", hidroponia:"Hidroponia", aeroponia:"Aeroponia" }[g] || g || "—" }
function kindLabel(k)  { return { vegetativo:"Vegetativo", floracion:"Floración", mixta:"Mixta", madre:"Madres", clon:"Clones", secado:"Secado", manicura:"Manicura" }[k] || k || "—" }

function salaEstadoStyle(state) {
  return { activa:{bg:"#dcfce7",color:"#15803d"}, mantenimiento:{bg:"#fef3c7",color:"#b45309"}, cerrada:{bg:"#f1f5f9",color:"#64748b"} }[state] || {bg:"#f1f5f9",color:"#64748b"}
}
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
  const order = ["vegetativo","floracion","semilla","cosecha","curado","finalizado"]
  return [...items.value].sort((a,b) => order.indexOf(a.estado) - order.indexOf(b.estado))
})

const breadcrumbs = computed(() => {
  if (isCultivador.value) return []
  const crumbs = [{ label:"Sedes", to:{ name:"sedes" } }]
  if (sala.value?.sede) crumbs.push({ label:sala.value.sede.nombre, to:{ name:"sede-detail", params:{ id:sala.value.sede.id } } })
  return crumbs
})

// ── Cargar lote (secado / manicura) ────────────────────────
const showCargarLote = ref(false)

const esSalaSecado   = computed(() => sala.value?.kind === 'secado')
const esSalaManicura = computed(() => sala.value?.kind === 'manicura')
const puedeCargarLote = computed(() =>
  (esSalaSecado.value   && (canEdit.value || isAgricultor.value)) ||
  (esSalaManicura.value && (canEdit.value || isAgricultor.value || isManicurador.value))
)

async function onLoteCargado() {
  await lotes.fetchBySala(salaId)
  await salas.fetchSala(salaId)
}

// ── Crear lote ─────────────────────────────────────────────
const KIND_TO_ESTADO = { floracion:"floracion", secado:"secado", manicura:"curado" }
const KINDS_CON_ORIGEN = ['vegetativo', 'madre', 'clon', 'mixta']

const showCreate   = ref(false)
const loteForm     = ref(emptyLoteForm())
const loteErrors   = ref({})
const loteApiError = ref(null)
const showUpgrade  = ref(false)
const plantasMadre    = ref([])
const loadingMadres   = ref(false)

function emptyLoteForm() {
  const kind = sala.value?.kind
  const conOrigen = !kind || KINDS_CON_ORIGEN.includes(kind)
  const estadoInicial = conOrigen ? 'semilla' : (KIND_TO_ESTADO[kind] || 'vegetativo')
  return {
    estado: estadoInicial,
    origen: conOrigen ? 'semilla' : null,
    planta_madre_id: null,
    plants_count: 0,
    start_date: new Date().toISOString().slice(0, 10),
    genetica_id: '',
    grow_type: 'sustrato',
    light_type: '',
    tamanio_maceta: '',
    notes: '',
  }
}

async function setOrigen(valor) {
  loteForm.value.origen = valor
  loteForm.value.estado = valor
  loteForm.value.planta_madre_id = null
  if (valor === 'esqueje' && !plantasMadre.value.length) {
    loadingMadres.value = true
    try {
      const { data } = await listPlants({ state: 'vegetativo' })
      plantasMadre.value = data || []
    } catch { plantasMadre.value = [] }
    finally { loadingMadres.value = false }
  }
}

const mostrarOrigenSelector = computed(() => {
  const k = sala.value?.kind
  return !k || KINDS_CON_ORIGEN.includes(k)
})

function validateLote(form) {
  const e = {}
  if (!ESTADOS_LOTE.includes(form.estado)) e.estado = "Estado inválido"
  const n = Number(form.plants_count)
  if (!Number.isInteger(n) || n < 0 || n > 5000) e.plants_count = "Debe ser 0–5000"
  return e
}

async function createLote() {
  const e = validateLote(loteForm.value)
  loteErrors.value = e
  loteApiError.value = null
  if (Object.keys(e).length) return
  try {
    const payload = { ...loteForm.value }
    if (!payload.genetica_id)    delete payload.genetica_id
    if (!payload.light_type)     delete payload.light_type
    if (!payload.planta_madre_id) delete payload.planta_madre_id
    if (!payload.origen)         delete payload.origen
    await lotes.createInSala(salaId, payload)
    closeCreate()
    lotesExpanded.value = true
    salas.fetchSala(salaId)
  } catch (err) {
    if (err.response?.status === 402) {
      showCreate.value  = false
      showUpgrade.value = true
    } else {
      loteApiError.value = err.response?.data?.errors?.[0] || err.response?.data?.error || 'Error al crear el lote'
    }
  }
}
function openCreate() {
  loteForm.value     = emptyLoteForm()
  loteErrors.value   = {}
  loteApiError.value = null
  showCreate.value   = true
}
function closeCreate() {
  showCreate.value   = false
  loteForm.value     = emptyLoteForm()
  loteErrors.value   = {}
  loteApiError.value = null
}

// ── Mini widget ambiente ───────────────────────────────────────
const ambienteMini = ref([])

async function cargarAmbienteMini() {
  try {
    // No enviamos `desde` — el backend defaultea a 24h, evitando problemas de timezone
    const res = await getSalaAmbiente(salaId, { bucket: 'raw' })
    const lecturas = res.data || []
    const tiposTarget = ['temperatura', 'humedad', 'vpd', 'co2']
    ambienteMini.value = tiposTarget.map(tipo => {
      const last = lecturas
        .filter(l => l.tipo === tipo)
        .sort((a, b) => new Date(b.medido_at) - new Date(a.medido_at))[0]
      return { tipo, valor: last?.valor ?? null, unidad: last?.unidad || '' }
    }).filter(i => i.valor !== null)
  } catch { /* ambiente no crítico */ }
}

const canSeeAmbiente = computed(() =>
  auth.role === 'admin' || auth.role === 'cultivador'
)
</script>

<template>
  <div class="sd">

    <Breadcrumb
      v-if="breadcrumbs.length > 0"
      :items="[...breadcrumbs, { label: sala?.nombre || '…' }]"
    />

    <div v-if="loading" class="sd__loading"><div class="sd__spinner"></div><span>Cargando sala…</span></div>
    <div v-else-if="error" class="sd__error">{{ error }}</div>
    <div v-else-if="!sala" class="sd__error">Sala no encontrada.</div>

    <template v-else>

      <!-- Header -->
      <div class="sd__hero">
        <div class="sd__hero-left">
          <div class="sd__hero-title-row">
            <h1 class="sd__title">{{ sala.nombre }}</h1>
            <!-- Estado con dropdown para cambiar -->
            <div class="sd__estado-wrap" v-if="canEdit">
              <div class="sd__estado-dropdown">
                <span class="sd__estado-pill" :style="{ background: salaEstadoStyle(sala.state).bg, color: salaEstadoStyle(sala.state).color }">
                  {{ sala.state }} <i class="bi bi-chevron-down" style="font-size:.6rem"></i>
                </span>
                <div class="sd__estado-menu">
                  <button
                    v-for="est in ESTADOS_SALA"
                    :key="est.value"
                    class="sd__estado-option"
                    :class="{ 'sd__estado-option--active': sala.state === est.value }"
                    :style="sala.state === est.value ? est.style : ''"
                    @click="cambiarEstado(est.value)"
                    :disabled="cambiandoEstado"
                  >
                    {{ est.label }}
                  </button>
                </div>
              </div>
            </div>
            <span v-else class="sd__estado-pill" :style="{ background: salaEstadoStyle(sala.state).bg, color: salaEstadoStyle(sala.state).color }">
              {{ sala.state }}
            </span>
          </div>
          <p class="sd__subtitle">
            <span v-if="sala.kind">{{ kindLabel(sala.kind) }}</span>
            <span v-if="sala.sede" class="sd__subtitle-sep">·</span>
            <span v-if="sala.sede">{{ sala.sede.nombre }}</span>
          </p>
        </div>
        <div class="sd__hero-actions">
          <button
            v-if="canEdit || isCultivador"
            class="sd__btn-lectura"
            @click="lecturaOpen = true"
          >
            <Gauge :size="16" :stroke-width="1.75" />
            Registrar lectura
          </button>
          <AsistenteVoz
            v-if="contextoAsistente"
            :contexto="contextoAsistente"
          />
          <button
            v-if="puedeCargarLote"
            class="sd__btn-secondary"
            @click="showCargarLote = true"
          >
            <i class="bi bi-box-arrow-in-down"></i>
            {{ esSalaSecado ? 'Cargar lote de floración' : 'Cargar lote de secado' }}
          </button>
          <button v-if="canEdit && !esSalaSecado && !esSalaManicura" class="sd__btn-primary" @click="openCreate">
            <i class="bi bi-plus-lg"></i>Nuevo lote
          </button>
          <button v-if="canEdit" class="sd__btn-edit" @click="openEditSala" title="Editar sala">
            <i class="bi bi-pencil"></i>
          </button>
          <button v-if="canEdit" class="sd__btn-danger" :disabled="deleting" @click="eliminarSala">
            <i class="bi bi-trash3"></i>
          </button>
        </div>
      </div>

      <!-- KPIs -->
      <div class="sd__kpis">
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

          <!-- Lotes -->
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
              <EmptyState v-else-if="!items.length" icon="📦" title="Sin lotes todavía" message="Esta sala no tiene lotes asignados." compact>
                <template #actions>
                  <button v-if="canEdit && !esSalaSecado && !esSalaManicura" class="sd__btn-outline" @click="openCreate">Crear primer lote</button>
                  <button v-else-if="puedeCargarLote" class="sd__btn-outline" style="color:#b45309;border-color:#fde68a" @click="showCargarLote=true">
                    <i class="bi bi-box-arrow-in-down"></i>
                    {{ esSalaSecado ? 'Cargar lote de floración' : 'Cargar lote de secado' }}
                  </button>
                </template>
              </EmptyState>
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
                      <span v-if="l.estado === 'floracion' && l.plantas_cosechadas_count > 0"
                            class="sd__cosecha-parcial">
                        ✅ {{ l.plantas_cosechadas_count }}/{{ l.plants_count || '?' }} cosechadas
                      </span>
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

        </div>

        <!-- Aside -->
        <div class="sd__aside">

          <!-- Widget Ambiente -->
          <div v-if="canSeeAmbiente && (ambienteMini.length > 0)" class="sd__card sd__card--ambiente">
            <div class="sd__card-header" style="display:flex;align-items:center;justify-content:space-between">
              <span class="sd__card-title">🌿 Ambiente</span>
              <RouterLink :to="{ name: 'sala-ambiente', params: { id: salaId } }" class="sd__link-small">
                Ver detalle <i class="bi bi-arrow-right"></i>
              </RouterLink>
            </div>
            <div class="sd__card-body sd__card-body--p0">
              <SemaforoAmbiente :items="ambienteMini" />
            </div>
          </div>
          <div v-else-if="canSeeAmbiente" class="sd__card sd__card--ambiente">
            <div class="sd__card-header" style="display:flex;align-items:center;justify-content:space-between">
              <span class="sd__card-title">🌿 Ambiente</span>
              <RouterLink :to="{ name: 'sala-ambiente', params: { id: salaId } }" class="sd__link-small">
                Ver detalle <i class="bi bi-arrow-right"></i>
              </RouterLink>
            </div>
            <div class="sd__card-body" style="color:#94a3b8;font-size:.78rem">Sin lecturas recientes.</div>
          </div>

          <!-- Información -->
          <div class="sd__card sd__card--mt">
            <div class="sd__card-header"><span class="sd__card-title">ℹ️ Información</span></div>
            <dl class="sd__dl">
              <dt>Estado</dt>
              <dd>
                <span class="sd__inline-badge" :style="salaEstadoStyle(sala.state).bg ? `background:${salaEstadoStyle(sala.state).bg};color:${salaEstadoStyle(sala.state).color}` : ''">
                  {{ sala.state }}
                </span>
              </dd>
              <dt>Tipo</dt><dd>{{ kindLabel(sala.kind) }}</dd>
              <dt>Sede</dt><dd>{{ sala.sede?.nombre || "—" }}</dd>
              <dt>A cargo</dt><dd>{{ sala.cultivadores?.map(c => c.nombre).join(', ') || "—" }}</dd>
              <dt>Creado por</dt><dd>{{ sala.created_by_name || "—" }}</dd>
              <dt>Creado</dt><dd>{{ formatDate(sala.created_at) }}</dd>
              <dt>Actualizado</dt><dd>{{ formatDate(sala.updated_at) }}</dd>
            </dl>
          </div>

          <!-- Cultivadores -->
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

          <!-- Cámara -->
          <div class="sd__card sd__card--mt">
            <div class="sd__card-header">
              <span class="sd__card-title">📷 Cámara</span>
              <button v-if="canEdit" class="sd__link-small" @click="showCameraForm = !showCameraForm">
                <i :class="sala.camera_stream_url ? 'bi bi-pencil' : 'bi bi-plus-lg'"></i>
                {{ sala.camera_stream_url ? 'Editar' : 'Configurar' }}
              </button>
            </div>

            <div v-if="showCameraForm" class="sd__cam-form">
              <div class="sd__cam-row">
                <label>URL de stream (MJPEG / HLS)</label>
                <input v-model="cameraForm.camera_stream_url" type="url" placeholder="http://cam.local/stream" class="sd__cam-input" />
              </div>
              <div class="sd__cam-row">
                <label>URL de snapshot (imagen estática)</label>
                <input v-model="cameraForm.camera_snapshot_url" type="url" placeholder="http://cam.local/snapshot.jpg" class="sd__cam-input" />
              </div>
              <div class="sd__cam-actions">
                <button class="sd__btn-ghost-sm" @click="showCameraForm = false">Cancelar</button>
                <button class="sd__btn-primary-sm" :disabled="savingCamera" @click="saveCamera">
                  {{ savingCamera ? 'Guardando…' : 'Guardar' }}
                </button>
              </div>
            </div>

            <template v-else-if="sala.camera_stream_url || sala.camera_snapshot_url">
              <!-- Stream en vivo -->
              <div v-if="sala.camera_stream_url" class="sd__cam-stream">
                <img
                  :src="snapshotSrc"
                  :key="snapshotKey"
                  class="sd__cam-img"
                  alt="Cámara sala"
                  @error="cameraError = true"
                />
                <div v-if="cameraError" class="sd__cam-error">
                  <span>📷 Sin señal</span>
                  <a :href="sala.camera_stream_url" target="_blank" rel="noopener" class="sd__cam-link">Abrir stream externo</a>
                </div>
                <div class="sd__cam-controls">
                  <button class="sd__cam-btn" @click="refreshSnapshot" title="Actualizar imagen">
                    <i class="bi bi-arrow-clockwise"></i>
                  </button>
                  <span class="sd__cam-ts">{{ snapshotTs }}</span>
                </div>
              </div>
              <!-- Solo snapshot -->
              <div v-else-if="sala.camera_snapshot_url" class="sd__cam-stream">
                <img :src="sala.camera_snapshot_url" class="sd__cam-img" alt="Snapshot sala" @error="cameraError = true" />
              </div>
            </template>

            <div v-else class="sd__cam-empty">
              <span>Sin cámara configurada</span>
            </div>
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
            <div v-if="loteApiError" class="sd__alert">{{ loteApiError }}</div>
            <div v-else-if="lotes.createError" class="sd__alert">{{ lotes.createError }}</div>

            <div class="sd__grid">

              <!-- Origen: semilla / esqueje -->
              <div v-if="mostrarOrigenSelector" class="sd__field sd__field--full">
                <label class="sd__label">¿Cómo inicia este lote?</label>
                <div class="sd__origen-pills">
                  <button
                    type="button"
                    class="sd__origen-pill"
                    :class="{ 'sd__origen-pill--active': loteForm.origen === 'semilla' }"
                    @click="setOrigen('semilla')"
                  >
                    🌱 Semilla
                  </button>
                  <button
                    type="button"
                    class="sd__origen-pill"
                    :class="{ 'sd__origen-pill--active': loteForm.origen === 'esqueje' }"
                    @click="setOrigen('esqueje')"
                  >
                    🪴 Esqueje
                  </button>
                </div>
              </div>

              <!-- Planta madre (solo esqueje) -->
              <div v-if="loteForm.origen === 'esqueje'" class="sd__field sd__field--full">
                <label class="sd__label">Planta madre <span class="sd__label-opt">(opcional)</span></label>
                <select class="sd__input" v-model="loteForm.planta_madre_id">
                  <option :value="null">— No especificada —</option>
                  <template v-if="loadingMadres">
                    <option disabled>Cargando plantas…</option>
                  </template>
                  <template v-else>
                    <option v-for="p in plantasMadre" :key="p.id" :value="p.id">
                      {{ p.nombre }}{{ p.lote?.codigo ? ` (${p.lote.codigo})` : '' }}
                    </option>
                  </template>
                </select>
              </div>

              <div class="sd__field">
                <label class="sd__label">Cantidad de plantas</label>
                <input type="number" min="0" max="5000" step="1" class="sd__input"
                       :class="{ 'sd__input--err': loteErrors.plants_count }"
                       v-model.number="loteForm.plants_count" />
                <span v-if="loteErrors.plants_count" class="sd__err-msg">{{ loteErrors.plants_count }}</span>
              </div>
              <div class="sd__field">
                <label class="sd__label">Fecha de inicio</label>
                <input type="date" class="sd__input" v-model="loteForm.start_date" />
              </div>
              <div class="sd__field">
                <label class="sd__label">Genética / Variedad</label>
                <select class="sd__input" v-model="loteForm.genetica_id">
                  <option value="">Sin especificar</option>
                  <option v-for="g in geneticas" :key="g.id" :value="g.id">
                    {{ g.nombre }}{{ g.registrada_inase ? ' 🏛️' : '' }} — {{ g.tipo }}
                  </option>
                </select>
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
                <label class="sd__label">Tamaño de maceta</label>
                <select class="sd__input" v-model="loteForm.tamanio_maceta">
                  <option value="">Sin especificar</option>
                  <option value="0.5">Vaso (0.5L)</option>
                  <option value="1">1 litro</option>
                  <option value="3">3 litros</option>
                  <option value="5">5 litros</option>
                  <option value="7">7 litros</option>
                  <option value="10">10 litros</option>
                  <option value="12">12 litros</option>
                  <option value="15">15 litros</option>
                  <option value="otro">Otro</option>
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

    <!-- Modal cargar lote (usa Teleport internamente) -->
    <ModalCargarLote
      v-if="showCargarLote && sala"
      :sala="sala"
      @loaded="onLoteCargado"
      @close="showCargarLote = false"
    />

    <RegistrarLecturaModal
      v-model="lecturaOpen"
      :sala-id="salaId"
      :lotes="items"
      @registrada="cargarAmbienteMini"
    />

    <!-- Modal Editar Sala -->
    <Teleport to="body">
      <div v-if="showEditSala" class="sd__overlay" @click.self="showEditSala = false">
        <div class="sd__modal">
          <div class="sd__modal-header">
            <div>
              <h3 class="sd__modal-title">Editar sala</h3>
              <p class="sd__modal-sub">{{ sala?.nombre }}</p>
            </div>
            <button class="sd__modal-close" @click="showEditSala = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="sd__modal-body">
            <div v-if="editSalaError" class="sd__alert">{{ editSalaError }}</div>
            <div class="sd__grid">
              <div class="sd__field sd__field--full">
                <label class="sd__label">Nombre</label>
                <input type="text" class="sd__input" v-model.trim="editSalaForm.nombre" placeholder="Nombre de la sala" />
              </div>
              <div class="sd__field">
                <label class="sd__label">Tipo de sala</label>
                <select class="sd__input" v-model="editSalaForm.kind">
                  <option value="">Sin especificar</option>
                  <option v-for="k in SALA_KINDS" :key="k.value" :value="k.value">{{ k.label }}</option>
                </select>
              </div>
              <div class="sd__field sd__field--full">
                <label class="sd__label">Notas</label>
                <textarea class="sd__input sd__textarea" rows="3" v-model.trim="editSalaForm.notes" placeholder="Observaciones internas…"></textarea>
              </div>
            </div>
          </div>
          <div class="sd__modal-footer">
            <button class="sd__btn-ghost" :disabled="savingEditSala" @click="showEditSala = false">Cancelar</button>
            <button class="sd__btn-primary" :disabled="savingEditSala" @click="saveEditSala">
              <div v-if="savingEditSala" class="sd__spinner sd__spinner--sm"></div>
              <i v-else class="bi bi-check-lg"></i>Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal upgrade plan -->
    <Teleport to="body">
      <div v-if="showUpgrade" class="sd__overlay" @click.self="showUpgrade=false">
        <div class="sd__modal" style="max-width:380px;text-align:center;padding:2rem">
          <div style="font-size:3rem;margin-bottom:.75rem">🚀</div>
          <h3 class="sd__modal-title" style="margin-bottom:.5rem">Límite del plan alcanzado</h3>
          <p style="color:#64748b;font-size:.875rem;margin-bottom:1.5rem">Alcanzaste el máximo de lotes o plantas de tu plan. Contactá al equipo para actualizar.</p>
          <button class="sd__btn-primary" @click="showUpgrade=false">Entendido</button>
        </div>
      </div>
    </Teleport>

  </div>

</template>

<style scoped>
.sd { padding: 1.75rem 1.5rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .sd { padding: 1rem; } }


.sd__loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 5rem; color: #94a3b8; font-size: .875rem; }
.sd__error { padding: 1rem 1.25rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 10px; font-size: .875rem; }
.sd__spinner { width: 20px; height: 20px; border: 2.5px solid rgba(27,94,32,.2); border-top-color: #1b5e20; border-radius: 50%; animation: sd-spin .6s linear infinite; flex-shrink: 0; }
.sd__spinner--sm { width: 14px; height: 14px; border-top-color: #fff; border-color: rgba(255,255,255,.3); }
@keyframes sd-spin { to { transform: rotate(360deg); } }

.sd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sd__hero-title-row { display: flex; align-items: center; gap: .65rem; margin-bottom: .3rem; flex-wrap: wrap; }
.sd__title { font-size: 1.8rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.sd__subtitle { font-size: .85rem; color: #60725d; margin: 0; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.sd__subtitle-sep { color: #cbd5e1; }
.sd__hero-actions { display: flex; gap: .5rem; }

/* Estado dropdown */
.sd__estado-wrap { position: relative; }
.sd__estado-dropdown { position: relative; }
.sd__estado-dropdown:hover .sd__estado-menu { display: flex; }
.sd__estado-pill {
  font-size: .68rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .08em; padding: .28em .75em; border-radius: 999px;
  cursor: pointer; user-select: none; display: inline-flex; align-items: center; gap: .3rem;
}
.sd__estado-menu {
  display: none; flex-direction: column; position: absolute;
  top: calc(100% + 4px); left: 0; z-index: 100;
  background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0,0,0,.12); overflow: hidden; min-width: 160px;
}
.sd__estado-option {
  padding: .6rem 1rem; font-size: .82rem; font-weight: 600;
  background: transparent; border: none; cursor: pointer;
  text-align: left; transition: background .12s; color: #475569;
}
.sd__estado-option:hover { background: #f8fafc; }
.sd__estado-option--active { font-weight: 800; }
.sd__estado-option:disabled { opacity: .5; cursor: not-allowed; }
.sd__inline-badge { font-size: .72rem; font-weight: 700; padding: .2em .55em; border-radius: 5px; text-transform: capitalize; }

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
.sd__section-toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; background: transparent; border: none; cursor: pointer; transition: background .15s; text-align: left; }
.sd__section-toggle:hover { background: #f0fdf4; }
.sd__section-toggle-left { display: flex; align-items: center; gap: .6rem; }
.sd__section-emoji { font-size: 1rem; }
.sd__section-title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.sd__pill { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; }
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
.sd__cosecha-parcial { color: #15803d; font-weight: 600; }
.sd__lote-progress-wrap { display: flex; align-items: center; gap: .6rem; }
.sd__lote-progress-track { flex: 1; height: 3px; background: #e8f5e9; border-radius: 999px; overflow: hidden; }
.sd__lote-progress-fill { height: 100%; border-radius: 999px; transition: width .5s ease; }
.sd__lote-progress-pct { font-size: .65rem; color: #94a3b8; font-weight: 600; flex-shrink: 0; }
.sd__lote-arrow { color: #a7d7a9; font-size: .75rem; align-self: center; padding-right: 1rem; flex-shrink: 0; }

.sd__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.sd__card--mt { margin-top: 1rem; }
.sd__card--ambiente { margin-bottom: 1rem; }
.sd__card-body--p0 { padding: .75rem; }
.sd__link-small { font-size: .72rem; font-weight: 600; color: #1b5e20; text-decoration: none; display: flex; align-items: center; gap: .25rem; }
.sd__link-small:hover { text-decoration: underline; }
.sd__card-header { padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; }
.sd__card-title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.sd__card-body { padding: 1rem; }
.sd__card-notes { padding: .9rem 1rem; font-size: .82rem; color: #475569; line-height: 1.6; }

.sd__dl { display: grid; grid-template-columns: auto 1fr; gap: .45rem .75rem; padding: .9rem 1rem; margin: 0; }
.sd__dl dt { font-size: .75rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.sd__dl dd { font-size: .8rem; color: #1a1a1a; font-weight: 500; margin: 0; }

.sd__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }

.sd__btn-lectura { display: inline-flex; align-items: center; gap: .35rem; background: transparent; color: var(--c-role-cultivador, #5C7A4A); border: 1.5px solid var(--c-role-cultivador, #5C7A4A); padding: .5rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sd__btn-lectura:hover { background: rgba(92,122,74,.08); }
.sd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.sd__btn-primary:hover:not(:disabled) { background: #104417; }
.sd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.sd__btn-edit { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .6rem .9rem; border-radius: 8px; font-size: .875rem; cursor: pointer; transition: all .15s; }
.sd__btn-edit:hover { background: #f8fafc; border-color: #94a3b8; }
.sd__btn-danger { display: inline-flex; align-items: center; gap: .4rem; background: #b91c1c; color: #fff; border: none; padding: .6rem .9rem; border-radius: 8px; font-size: .875rem; cursor: pointer; transition: background .15s; }
.sd__btn-danger:hover:not(:disabled) { background: #991b1b; }
.sd__btn-danger:disabled { opacity: .5; cursor: not-allowed; }
.sd__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #b45309; border: 1.5px solid #fde68a; padding: .6rem 1.1rem; border-radius: 8px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sd__btn-secondary:hover { background: #fffbeb; border-color: #f59e0b; }
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
.sd__modal-body { padding: 1.25rem 1.5rem; flex: 1; display: flex; flex-direction: column; gap: 1rem; }
.sd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }

/* Capacidad bar */
.sd__capacity-bar { background: #f0fdf4; border: 1px solid #d4e6d4; border-radius: 9px; padding: .75rem 1rem; }
.sd__capacity-info { display: flex; justify-content: space-between; font-size: .82rem; margin-bottom: .5rem; color: #475569; }
.sd__capacity-track { height: 6px; background: #d4e6d4; border-radius: 999px; overflow: hidden; }
.sd__capacity-fill { height: 100%; border-radius: 999px; transition: width .4s; }

.sd__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .sd__grid { grid-template-columns: 1fr; } }
.sd__field { display: flex; flex-direction: column; gap: .35rem; }
.sd__field--full { grid-column: 1 / -1; }
.sd__label { font-size: .8rem; font-weight: 600; color: #374151; }
.sd__label-opt { font-weight: 400; color: #94a3b8; }
.sd__origen-pills { display: flex; gap: .5rem; }
.sd__origen-pill {
  flex: 1; padding: .65rem 1rem; background: #f4f8f4; border: 2px solid #d4e6d4;
  border-radius: 9px; font-size: .9rem; font-weight: 600; color: #374151;
  cursor: pointer; transition: all .15s; text-align: center;
}
.sd__origen-pill:hover { border-color: #1b5e20; background: #f0fdf4; }
.sd__origen-pill--active { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }
.sd__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.sd__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.sd__input--err { border-color: #dc2626; }
.sd__textarea { resize: vertical; min-height: 70px; }
.sd__err-msg { font-size: .75rem; color: #dc2626; }
.sd__checkbox-row { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: #374151; cursor: pointer; user-select: none; }
.sd__checkbox-row input[type="checkbox"] { width: 15px; height: 15px; accent-color: #1b5e20; cursor: pointer; flex-shrink: 0; }
.sd__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; }

/* Cámara */
.sd__cam-form { display: flex; flex-direction: column; gap: .75rem; }
.sd__btn-ghost-sm { background: transparent; border: 1px solid #d4e6d4; color: #60725d; padding: .4rem .8rem; border-radius: 6px; font-size: .78rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.sd__btn-ghost-sm:hover { background: #f0fdf4; color: #1b5e20; }
.sd__btn-primary-sm { background: #1b5e20; color: #fff; border: none; padding: .4rem .9rem; border-radius: 6px; font-size: .78rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sd__btn-primary-sm:hover { background: #155016; }
.sd__cam-controls { display: flex; gap: .5rem; flex-wrap: wrap; margin-top: .25rem; }
.sd__cam-stream { margin-top: .5rem; border-radius: 8px; overflow: hidden; border: 1px solid #d4e6d4; background: #000; }
.sd__cam-img { width: 100%; display: block; max-height: 220px; object-fit: cover; }
.sd__cam-empty { color: #94a3b8; font-size: .8rem; font-style: italic; text-align: center; padding: .5rem 0; }
</style>
