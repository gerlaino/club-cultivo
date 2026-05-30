<script setup>
import { onMounted, onUnmounted, ref, computed, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useLotesStore }  from "../stores/lotes"
import { usePlantsStore } from "../stores/plants"
import { useAuthStore }   from "../stores/auth"
import { useClubStore }   from "../stores/club"
import { createPlant, updatePlant,
  getRegistrosAmbientales, getLoteEventos,
  getLoteTimeline, listSedes, deleteLote, updateLote, createPlantActivity } from "../lib/api"
import TareasDelLote from '../components/TareasDelLote.vue'
import ModalCosechaPartial from '../components/salas/ModalCosechaPartial.vue'
import AsistenteVoz from '../components/AsistenteVoz.vue'
import GraficosLote from '../components/GraficosLote.vue'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import Lightbox from '../components/ui/Lightbox.vue'
import Paginator from '../components/ui/Paginator.vue'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import { useQRCode } from '../composables/useQRCode.js'
import { ArrowRight } from 'lucide-vue-next'
import DsBanner from '../design-system/components/Banner.vue'
import IniciarManicuraModal   from '../components/lotes/IniciarManicuraModal.vue'
import CompletarManicuraModal  from '../components/lotes/CompletarManicuraModal.vue'
import LoteTrasplanteModal     from '../components/lotes/LoteTrasplanteModal.vue'
import RegistroLoteModal       from '../components/lotes/registro/RegistroLoteModal.vue'
import ActionsDropdown         from '../components/ui/ActionsDropdown.vue'
import { useLoteAnalisisIA }       from '../composables/useLoteAnalisisIA.js'
import { useLoteCostos }           from '../composables/useLoteCostos.js'
import { useLoteRegistroAmbiental } from '../composables/useLoteRegistroAmbiental.js'
import { useLoteFotos }            from '../composables/useLoteFotos.js'
import { useLoteEditar }           from '../composables/useLoteEditar.js'
import { useLoteTransiciones }     from '../composables/useLoteTransiciones.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const route    = useRoute()
const router   = useRouter()
const lotes    = useLotesStore()
const plants   = usePlantsStore()
const auth     = useAuthStore()
const club     = useClubStore()
const toast    = useToast()
const { confirm } = useConfirm()

const id       = Number(route.params.id)
const error    = ref(null)
const loading  = computed(() => lotes.loading)
const lote     = computed(() => lotes.current)
const canEdit  = computed(() => ['admin', 'supervisor', 'cultivador'].includes(auth.role))
const canAdmin = computed(() => ['admin', 'supervisor'].includes(auth.role))
const isCultivador = computed(() => auth.role === 'cultivador')

const deletingLote = ref(false)
async function eliminarLote() {
  const ok = await confirm({
    title: 'Eliminar lote',
    message: `¿Seguro que querés eliminar el lote "${lote.value?.codigo}"? Quedará archivado (soft delete) junto a sus plantas y registros. Podrá recuperarse si es necesario.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  deletingLote.value = true
  try {
    const salaId = lote.value?.sala?.id
    await deleteLote(id)
    toast.success('Lote eliminado')
    if (salaId) router.push({ name: 'sala-detail', params: { id: salaId } })
    else router.push({ name: 'salas' })
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al eliminar el lote')
  } finally {
    deletingLote.value = false
  }
}

// ── Sedes ─────────────────────────────────────────────────
const sedes = ref([])

// ── Historial ─────────────────────────────────────────────
const eventos        = ref([])
const loadingEventos = ref(false)

async function loadEventos() {
  loadingEventos.value = true
  try {
    const [evRes, regRes] = await Promise.all([getLoteEventos(id), getRegistrosAmbientales(id)])
    const evs  = (evRes.data  || []).map(e => ({ ...e, _tipo: 'evento' }))
    const regs = (regRes.data || []).map(r => ({ ...r, _tipo: 'registro' }))
    eventos.value = [...evs, ...regs].sort((a, b) => new Date(b.registrado_en) - new Date(a.registrado_en))
  } catch { eventos.value = [] }
  finally { loadingEventos.value = false }
}

// ── Section toggles ────────────────────────────────────────
const tareasExpanded    = ref(true)
const plantasExpanded   = ref(true)
const historialExpanded = ref(true)
const graficosExpanded  = ref(true)
const graficosKey       = ref(0)

// ── Timeline ──────────────────────────────────────────────
const timelineExpanded = ref(false)
const timeline         = ref(null)
const loadingTimeline  = ref(false)

function toggleTimeline() {
  timelineExpanded.value = !timelineExpanded.value
  if (timelineExpanded.value && !timeline.value) loadTimeline()
}

async function loadTimeline() {
  loadingTimeline.value = true
  try { const { data } = await getLoteTimeline(id); timeline.value = data }
  catch { timeline.value = null }
  finally { loadingTimeline.value = false }
}

// ── Plantas ────────────────────────────────────────────────
const plantasPage      = ref(1)
const plantasPerPage   = ref(10)
const plantList        = computed(() => plants.byLote(id))
const plantasActivas   = computed(() => plantList.value.filter(p => !['cosechado', 'descartada'].includes(p.state)))
const plantasCosechadas = computed(() => plantList.value.filter(p => p.state === 'cosechado'))
const plantasCosechadasPorPasada = computed(() => {
  const grupos = {}
  for (const p of plantasCosechadas.value) {
    const pasada = p.pasada_cosecha || '—'
    if (!grupos[pasada]) grupos[pasada] = []
    grupos[pasada].push(p)
  }
  return Object.entries(grupos).sort(([a], [b]) => a.localeCompare(b)).map(([pasada, plantas]) => ({ pasada, plantas }))
})
const plantasMostradas = computed(() => {
  const start = (plantasPage.value - 1) * plantasPerPage.value
  return plantasActivas.value.slice(start, start + plantasPerPage.value)
})

const plantasEnFloracion = computed(() => plantList.value.filter(p => p.state === 'floracion'))
const todasCosechadas    = computed(() => plantList.value.length > 0 && plantasEnFloracion.value.length === 0)
const pasadasUsadas      = computed(() => {
  const pasadas = plantList.value.map(p => p.pasada_cosecha).filter(Boolean)
  return [...new Set(pasadas)]
})
const siguientePasada = computed(() => {
  const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')
  return letras.find(l => !pasadasUsadas.value.includes(l)) || 'Z'
})

// ── Bulk QR download ───────────────────────────────────────
const { generatePNG } = useQRCode()
const downloadingQRs  = ref(false)

async function descargarTodosQRs() {
  if (!plantList.value.length || downloadingQRs.value) return
  downloadingQRs.value = true
  try {
    const JSZip  = (await import('jszip')).default
    const zip    = new JSZip()
    const origin = window.location.origin
    const codigo = lote.value?.codigo || 'lote'
    await Promise.all(
      plantList.value
        .filter(p => p.codigo_qr)
        .map(async p => {
          const dataUrl = await generatePNG(`${origin}/p/${p.codigo_qr}`)
          const base64  = dataUrl.split(',')[1]
          zip.file(`${p.nombre || p.codigo_qr}.png`, base64, { base64: true })
        })
    )
    const blob = await zip.generateAsync({ type: 'blob' })
    const href = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = href
    a.download = `QRs-${codigo}.zip`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(href)
  } finally {
    downloadingQRs.value = false
  }
}

// ── Agregar planta al lote ─────────────────────────────────
const showAddPlanta = ref(false)
const savingPlanta  = ref(false)
const plantaError   = ref(null)
const plantaForm    = ref({ state: 'vegetativo', origen: 'semilla' })

const STATE_MAP = {
  semilla: 'germinacion', esqueje: 'esqueje', vegetativo: 'vegetativo',
  floracion: 'floracion', cosecha: 'cosechado',
  curado: 'cosechado', finalizado: 'cosechado',
}

const contextoAsistente = computed(() => lote.value ? {
  tipo:          'lote',
  lote_id:       lote.value.id,
  lote_codigo:   lote.value.codigo,
  sala_id:       lote.value.sala?.id,
  sala_nombre:   lote.value.sala?.nombre,
  plantas_count: plantList.value.length,
  estado:        lote.value.estado,
} : null)

function openAddPlanta() {
  plantaForm.value  = { state: STATE_MAP[lote.value?.estado] || 'vegetativo', origen: 'semilla' }
  plantaError.value = null
  showAddPlanta.value = true
}

async function guardarPlanta() {
  if (!lote.value) return
  savingPlanta.value = true
  plantaError.value  = null
  try {
    const count  = plantList.value.length + 1
    const nombre = `${lote.value.codigo}-P${String(count).padStart(3, '0')}`
    const { data } = await createPlant({
      lote_id:     lote.value.id,
      nombre,
      state:       plantaForm.value.state,
      origen:      plantaForm.value.origen,
      genetica_id: lote.value.genetica_id || undefined,
    })
    plants.addToLote(id, data)
    showAddPlanta.value = false
  } catch (e) {
    plantaError.value = e?.response?.data?.errors?.join(', ') || 'Error al agregar planta'
  } finally {
    savingPlanta.value = false
  }
}

async function toggleEsSeleccion(plant) {
  const original = plant.es_seleccion
  plant.es_seleccion = !original
  try { await updatePlant(plant.id, { es_seleccion: !original }) }
  catch { plant.es_seleccion = original; toast.error('Error al actualizar selección') }
}

// ── Plan vs Real ───────────────────────────────────────────
const showPlanForm = ref(false)
const savingPlan   = ref(false)
const planForm     = ref({})

function openPlanForm() {
  const l = lote.value
  planForm.value = {
    plants_count_objetivo:  l.plants_count_objetivo ?? '',
    rendimiento_objetivo_g: l.rendimiento_objetivo_g ?? '',
    fecha_cosecha_estimada: l.fecha_cosecha_estimada ?? '',
    rendimiento_real_g:     l.rendimiento_real_g ?? '',
  }
  showPlanForm.value = true
}

async function savePlan() {
  savingPlan.value = true
  try {
    const payload = {
      plants_count_objetivo:  planForm.value.plants_count_objetivo || null,
      rendimiento_objetivo_g: planForm.value.rendimiento_objetivo_g || null,
      fecha_cosecha_estimada: planForm.value.fecha_cosecha_estimada || null,
      rendimiento_real_g:     planForm.value.rendimiento_real_g || null,
    }
    await updateLote(id, payload)
    await lotes.fetchOne(id)
    showPlanForm.value = false
    toast.success('Objetivos guardados')
  } catch { toast.error('Error al guardar objetivos') }
  finally { savingPlan.value = false }
}

const plantasDevPct = computed(() => {
  const obj = lote.value?.plants_count_objetivo
  const real = lote.value?.plants_count
  if (!obj || !real) return 0
  return Math.round((real - obj) / obj * 100)
})
const plantasDevClass = computed(() => {
  const p = plantasDevPct.value
  return p > 0 ? 'ld__pvr-positive' : p < 0 ? 'ld__pvr-negative' : ''
})
const rendDevPct = computed(() => {
  const obj = lote.value?.rendimiento_objetivo_g
  const real = lote.value?.rendimiento_real_g
  if (!obj || !real) return 0
  return Math.round((real - obj) / obj * 100)
})
const rendDevClass = computed(() => {
  const p = rendDevPct.value
  return p > 0 ? 'ld__pvr-positive' : p < 0 ? 'ld__pvr-negative' : ''
})

// ── Trasplante de lote ────────────────────────────────────
const showTrasplanteLote = ref(false)
function abrirTrasplanteLote() { showTrasplanteLote.value = true }

// ── Registro modal (nuevo) ────────────────────────────────
const showRegistroModalNew = ref(false)

// ── Acciones dropdown ─────────────────────────────────────
const loteAcciones = computed(() => {
  const items = []
  items.push({ emoji: '📋', label: 'Registrar lote', onClick: () => { showRegistroModalNew.value = true } })
  if (club.data?.features?.ia_voz && (canEdit.value || isCultivador.value)) {
    items.push({ emoji: '🎙️', label: 'Registrar por voz', onClick: () => window.dispatchEvent(new Event('abrir-asistente-voz')) })
  }
  if (canEdit.value && ['semilla','esqueje','planificacion','vegetativo','floracion'].includes(lote.value?.estado)) {
    items.push({ emoji: '🪴', label: 'Trasplantar', onClick: abrirTrasplanteLote })
  }
  if (canEdit.value) {
    items.push({ emoji: '✏️', label: 'Editar lote', onClick: openEditLote })
    items.push({ divider: true })
    items.push({ emoji: '🗑️', label: 'Eliminar lote', danger: true, onClick: eliminarLote })
  }
  return items
})

// ── Helpers ────────────────────────────────────────────────
const CICLO_BASE = ['vegetativo', 'floracion', 'cosecha', 'secado', 'curado']
const cicloPasos = computed(() => {
  const origen = lote.value?.origen
  if (origen === 'semilla') return ['semilla', ...CICLO_BASE]
  if (origen === 'esqueje') return ['esqueje', ...CICLO_BASE]
  return CICLO_BASE
})
const ESTADO_META = {
  semilla:            { label: 'Germinación',        color: '#64748b', bg: '#f1f5f9', emoji: '🌱' },
  esqueje:            { label: 'Esqueje',             color: '#0891b2', bg: '#e0f2fe', emoji: '🪴' },
  vegetativo:         { label: 'Vegetativo',          color: '#16a34a', bg: '#dcfce7', emoji: '🍃' },
  floracion:          { label: 'Floración',          color: '#d97706', bg: '#fef3c7', emoji: '🌸' },
  cosecha:            { label: 'Cosecha',            color: '#059669', bg: '#d1fae5', emoji: '🌿' },
  en_manicura:        { label: 'En manicura',        color: '#7c3aed', bg: '#ede9fe', emoji: '✂️'  },
  secado:             { label: 'Manicura',           color: '#78350f', bg: '#fef3c7', emoji: '✂️'  },
  manicura_pendiente: { label: 'Manicura pendiente', color: '#7c3aed', bg: '#ede9fe', emoji: '✂️'  },
  curado:             { label: 'Curado',             color: '#2563eb', bg: '#dbeafe', emoji: '🫙' },
  finalizado:         { label: 'Finalizado',         color: '#1b5e20', bg: '#dcfce7', emoji: '✅' },
}
const PLANT_STATE_META = {
  semilla:    { label: 'Semilla',    color: '#64748b', emoji: '🌰' },
  germinacion:{ label: 'Germinación',color: '#16a34a', emoji: '🌱' },
  esqueje:    { label: 'Esqueje',    color: '#0891b2', emoji: '🌿' },
  vegetativo: { label: 'Vegetativo', color: '#16a34a', emoji: '🍃' },
  floracion:  { label: 'Floración',  color: '#d97706', emoji: '🌸' },
  cosechado:  { label: 'Cosechada',  color: '#2563eb', emoji: '✅' },
  descartada: { label: 'Descartada', color: '#dc2626', emoji: '❌' },
}
const ESTADO_SALUD_META = {
  excelente: { color: '#16a34a', emoji: '🟢' },
  bueno:     { color: '#65a30d', emoji: '🟡' },
  regular:   { color: '#d97706', emoji: '🟠' },
  malo:      { color: '#dc2626', emoji: '🔴' },
  critico:   { color: '#991b1b', emoji: '🚨' },
}
const PLAGAS_META = {
  ninguna:  { color: '#16a34a', emoji: '✅' },
  leve:     { color: '#d97706', emoji: '⚠️' },
  moderada: { color: '#ea580c', emoji: '🐛' },
  severa:   { color: '#dc2626', emoji: '🚨' },
}
const MACETA_LABELS = {
  '0.5': 'Vaso (0.5L)', '1': '1 litro', '3': '3 litros', '5': '5 litros',
  '7': '7 litros', '10': '10 litros', '12': '12 litros', '15': '15 litros', 'otro': 'Otro',
}
const TAREAS_LOTE = [
  { key: 'riego',                label: 'Riego',               emoji: '💧' },
  { key: 'nutricion',            label: 'Nutrición',           emoji: '🧪' },
  { key: 'poda',                 label: 'Poda',                emoji: '✂️'  },
  { key: 'defoliacion',          label: 'Defoliación',         emoji: '🍃' },
  { key: 'scrog_lst',            label: 'SCROG/LST',           emoji: '🪢' },
  { key: 'revision_plagas',      label: 'Revisión plagas',     emoji: '🔍' },
  { key: 'limpieza_sala',        label: 'Limpieza sala',       emoji: '🧹' },
  { key: 'ajuste_luz',           label: 'Ajuste de luz',       emoji: '💡' },
  { key: 'registro_ambiental',   label: 'Registro ambiental',  emoji: '🌡️' },
]

function em(e)  { return ESTADO_META[e]       || { label: e || '—', color: '#64748b', bg: '#f1f5f9', emoji: '•' } }
function pm(s)  { return PLANT_STATE_META[s]  || { label: s || '—', color: '#64748b', emoji: '🌿' } }
function sm(s)  { return ESTADO_SALUD_META[s] || { color: '#94a3b8', emoji: '⚪' } }
function pgm(p) { return PLAGAS_META[p]       || { color: '#94a3b8', emoji: '—' } }
function growLabel(g)  { return { sustrato: 'Sustrato', hidroponia: 'Hidroponia', aeroponia: 'Aeroponia' }[g] || g || '—' }
function lightLabel(l) { return { led: 'LED', hps: 'HPS', cmh: 'CMH', natural: 'Natural', mixta: 'Mixta' }[l] || l || '—' }
function macetaLabel(m) { return MACETA_LABELS[String(m)] || (m ? m + 'L' : '—') }
function parseDate(d) {
  if (!d) return null
  // Date-only strings (YYYY-MM-DD) must be parsed as local time, not UTC
  if (/^\d{4}-\d{2}-\d{2}$/.test(d)) return new Date(d + 'T00:00:00')
  return new Date(d)
}
function formatDate(d) {
  if (!d) return '—'
  const date = parseDate(d)
  return !date || isNaN(date.getTime()) ? '—' : date.toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
}
function formatDateTime(d) {
  if (!d) return '—'
  const date = parseDate(d)
  return !date || isNaN(date.getTime()) ? '—' : date.toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

const cicloIndex  = computed(() => lote.value ? cicloPasos.value.indexOf(lote.value.estado) : -1)
const FASE_LABELS = { vegetativo: 'Vegetativo', floracion: 'Floración', secado: 'Manicura', curado: 'Curado', cosecha: 'Cosecha', semilla: 'Germinación', manicura: 'Manicura', cerrado: 'Cerrado' }
function capitalizarFase(f) { return FASE_LABELS[f] || (f ? f.charAt(0).toUpperCase() + f.slice(1) : '') }
function phaseBannerMsg(estado) {
  if (estado === 'cosecha') return 'Lote cosechado. Manicura toma desde acá.'
  if (estado === 'semilla') return 'Plantas en germinación. El sistema avanzará automáticamente cuando estén listas.'
  if (estado === 'finalizado') return 'Lote finalizado. Stock confirmado y disponible para dispensar.'
  if (['en_manicura', 'secado', 'manicura_pendiente', 'manicura', 'curado', 'cerrado'].includes(estado)) return 'Este lote pasó tu turno. Otro rol toma desde acá.'
  return null
}

// ── Composables ────────────────────────────────────────────
const {
  analizandoIA, historialAnalisis, expandedAnalisis,
  puedoAnalizar, tiempoRestante,
  toggleAnalisis, formatearFechaRelativa, cargarHistorialAnalisis, ejecutarAnalisisIA,
} = useLoteAnalisisIA(id)

const {
  costoLote, showCostoForm, savingCosto, costoForm,
  costoTotal, costoPorGramo,
  openCostoForm, saveCosto, cargarCostos,
} = useLoteCostos(id)

const {
  showRegistroModal, savingRegistro, registroError, csvFile, csvInput,
  registroForm, registroErrors,
  abrirRegistroModal, guardarRegistro, toggleTarea, handleCsvChange,
} = useLoteRegistroAmbiental(id, {
  onSaved: (registro) => {
    eventos.value.unshift({ ...registro, _tipo: 'registro' })
    graficosKey.value++
  },
})

const {
  fotos, uploadingFoto, fotoInput,
  showFotoUploadModal, fotoUploadFile, fotoUploadDescripcion, fotoUploadPreview,
  fotosExpanded, lightboxOpen, lightboxIndex, lightboxImages,
  loadFotos, toggleFotos, openLightbox,
  handleFotoSelect, confirmarSubidaFoto, cancelarSubidaFoto, eliminarFoto,
} = useLoteFotos(id)

const {
  geneticas, showEditLote, editLoteForm, editLoteError, savingEditLote,
  cargarGeneticas, openEditLote, saveEditLote,
} = useLoteEditar(id)

const {
  showTransicionModal, savingTransicion, transicionError, transicionForm, transicionSalaId,
  showAvanzarSalaModal, avanzarSalaId, transicionandoRapido,
  showIniciarManicuraModal, showCompletarManicuraModal,
  showCosechaModal, cosechaSalaId, savingCosecha, cosechaError, cosechaForm,
  showCosechaPartialModal,
  showCerrarCuradoModal, savingCurado, curadoError, curadoForm, splitOk, pesadaUltimaCurado,
  handleAvanzarFase, openTransicionModal, ejecutarTransicion,
  avanzarFaseRapido, ejecutarCosecha, onCosechadoParcial,
  onManicuraIniciada, onManicuraCompletada,
  openCerrarCuradoModal, ejecutarCerrarCurado,
} = useLoteTransiciones(id, { onPhaseChange: loadEventos, sedes })

function onRegistradoPorVoz() { lotes.fetchOne(id); loadEventos(); graficosKey.value++ }

// ── Escape key handler ─────────────────────────────────────
function loteEscapeHandler(e) {
  if (e.key !== 'Escape') return
  if (showFotoUploadModal.value)      { cancelarSubidaFoto(); return }
  if (showRegistroModalNew.value)     { showRegistroModalNew.value = false; return }
  if (showTrasplanteLote.value)       { showTrasplanteLote.value = false; return }
  if (showEditLote.value)             { showEditLote.value = false; return }
  if (showCerrarCuradoModal.value)    { showCerrarCuradoModal.value = false; return }
  if (showCosechaPartialModal.value)  { showCosechaPartialModal.value = false; return }
  if (showCosechaModal.value)         { showCosechaModal.value = false; return }
  if (showAvanzarSalaModal.value)     { showAvanzarSalaModal.value = false; return }
  if (showIniciarManicuraModal.value) { showIniciarManicuraModal.value = false; return }
  if (showCompletarManicuraModal.value) { showCompletarManicuraModal.value = false; return }
  if (showTransicionModal.value)      { showTransicionModal.value = false; return }
  if (showRegistroModal.value)        { showRegistroModal.value = false; return }
  if (showCostoForm.value)            { showCostoForm.value = false; return }
  if (showAddPlanta.value)            { showAddPlanta.value = false; return }
}

const POST_HARVEST_ESTADOS = ['cosecha', 'secado', 'manicura_pendiente', 'en_manicura', 'curado', 'finalizado']

watch(
  () => lotes.current?.estado,
  (estado) => {
    if (isCultivador.value && estado && POST_HARVEST_ESTADOS.includes(estado)) {
      router.replace({ name: 'cosechado-detalle', params: { id } })
    }
  }
)

onMounted(async () => {
  document.addEventListener('keydown', loteEscapeHandler, true)
  try {
    await lotes.fetchOne(id)
    if (isCultivador.value && POST_HARVEST_ESTADOS.includes(lotes.current?.estado)) {
      router.replace({ name: 'cosechado-detalle', params: { id } })
      return
    }
    // Seed plants store immediately from lote response to avoid empty flash
    if (lotes.current?.plants?.length) {
      plants.itemsByLote[String(id)] = lotes.current.plants
    }
  } catch { error.value = 'No se pudo cargar el lote.' }
  try   { await plants.fetchByLote(id) }
  catch {}
  await loadEventos()
  try { const { data } = await listSedes(); sedes.value = data || [] } catch {}
  await cargarCostos()
  await cargarGeneticas()
  if (canAdmin.value) cargarHistorialAnalisis()
})

onUnmounted(() => {
  document.removeEventListener('keydown', loteEscapeHandler, true)
})
</script>

<template>
  <div class="ld">

    <Breadcrumb :items="[
      ...(!isCultivador ? [{ label: 'Sedes', to: { name: 'sedes' } }] : []),
      ...(!isCultivador && lote?.sala?.sede ? [{ label: lote.sala.sede.nombre, to: { name: 'sede-detail', params: { id: lote.sala.sede.id } } }] : []),
      ...(lote?.sala ? [{ label: lote.sala.nombre, to: { name: 'sala-detail', params: { id: lote.sala.id } } }] : []),
      { label: lote?.codigo || `Lote #${id}` },
    ]" />

    <div v-if="loading" class="ld__loading"><DsSpinner /></div>
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
            <span v-if="lote.genetica">🌿 {{ lote.genetica.nombre }}</span>
            <span v-if="lote.sala" class="ld__subtitle-sep">·</span>
            <span v-if="lote.sala">📍 {{ lote.sala.nombre }}</span>
            <span v-if="lote.start_date" class="ld__subtitle-sep">·</span>
            <span v-if="lote.start_date">📅 inicio {{ lote.start_date }}</span>
            <span v-if="lote.dias_desde_inicio != null" class="ld__subtitle-sep">·</span>
            <span v-if="lote.dias_desde_inicio != null" class="ld__dias-badge">Día {{ lote.dias_desde_inicio }}</span>
          </p>
        </div>
        <div class="ld__hero-actions">
          <button v-if="canEdit && lote.puede_cerrar_curado" class="ld__btn-curado" @click="openCerrarCuradoModal">
            <i class="bi bi-box-seam"></i>Cerrar curado
          </button>
          <button
            v-if="canAdmin && ['en_manicura', 'secado'].includes(lote.estado)"
            class="ld__btn-completar-manicura"
            @click="showCompletarManicuraModal = true"
          >
            <i class="bi bi-check2-circle"></i>Completar manicura
          </button>
          <button
            v-if="(canEdit || isCultivador) && lote.puede_transicionar && lote.proxima_fase_posible"
            class="ld__btn-transicion"
            :disabled="transicionandoRapido"
            @click="handleAvanzarFase"
          >
            <DsSpinner v-if="transicionandoRapido" :size="14" />
            <ArrowRight v-else :size="15" :stroke-width="1.75" />
            Avanzar a {{ capitalizarFase(lote.proxima_fase_posible) }}
          </button>
          <ActionsDropdown v-if="canEdit || isCultivador" :items="loteAcciones" />
          <!-- AsistenteVoz montado oculto para responder al evento abrir-asistente-voz -->
          <div v-if="club.data?.features?.ia_voz && contextoAsistente && (canEdit || isCultivador)" style="display:none">
            <AsistenteVoz :contexto="contextoAsistente" @registrado="onRegistradoPorVoz" />
          </div>
        </div>
      </div>

      <!-- Banner fase terminal (cultivador) -->
      <DsBanner
        v-if="isCultivador && !lote.puede_transicionar && phaseBannerMsg(lote.estado)"
        variant="sky"
        class="ld__fase-banner"
      >
        {{ phaseBannerMsg(lote.estado) }}
      </DsBanner>

      <!-- Timeline ciclo -->
      <div class="ld__ciclo">
        <div class="ld__ciclo-track">
          <div v-for="(etapa, i) in cicloPasos" :key="etapa" class="ld__ciclo-step"
               :class="{ 'ld__ciclo-step--done': i < cicloIndex, 'ld__ciclo-step--current': i === cicloIndex, 'ld__ciclo-step--pending': i > cicloIndex }">
            <div class="ld__ciclo-dot"><span class="ld__ciclo-emoji">{{ em(etapa).emoji }}</span></div>
            <div class="ld__ciclo-label">{{ em(etapa).label }}</div>
            <div v-if="i < cicloPasos.length - 1" class="ld__ciclo-connector" :class="{ 'ld__ciclo-connector--done': i < cicloIndex }"></div>
          </div>
        </div>
        <div v-if="lote.progreso_ciclo != null" class="ld__ciclo-progress">
          <div class="ld__ciclo-progress-fill" :style="{ width: lote.progreso_ciclo + '%' }"></div>
        </div>
      </div>

      <!-- Layout -->
      <div class="ld__layout">
        <div class="ld__main">

          <!-- 1. Tareas -->
          <div class="ld__section">
            <button class="ld__section-toggle" @click="tareasExpanded = !tareasExpanded">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📋</span>
                <span class="ld__section-title">Tareas del lote</span>
              </div>
              <i class="bi ld__chevron" :class="tareasExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="tareasExpanded" class="ld__section-body">
              <TareasDelLote :lote="lote" />
            </div>
          </div>

          <!-- 2. Plantas -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="plantasExpanded = !plantasExpanded">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">🪴</span>
                <span class="ld__section-title">Plantas del lote</span>
                <span class="ld__pill">{{ plantasActivas.length }}</span>
                <span v-if="plantasCosechadas.length" class="ld__pill ld__pill--cosechada">{{ plantasCosechadas.length }} cosechadas</span>
              </div>
              <div class="ld__section-toggle-right">
                <button
                  v-if="(canEdit || isCultivador) && lote.estado === 'floracion' && plantasActivas.length > 0"
                  class="ld__btn-sm ld__btn-sm--cosecha"
                  title="Registrar cosecha parcial"
                  @click.stop="showCosechaPartialModal = true"
                >
                  🌿 Cosechar
                </button>
                <button
                  v-if="plantList.length > 0"
                  class="ld__btn-sm ld__btn-sm--qr"
                  :disabled="downloadingQRs"
                  title="Descargar QRs de todas las plantas"
                  @click.stop="descargarTodosQRs"
                >
                  <i class="bi" :class="downloadingQRs ? 'bi-hourglass-split' : 'bi-qr-code'"></i>
                  {{ downloadingQRs ? 'Descargando…' : 'QRs' }}
                </button>
                <button v-if="canEdit || isCultivador" class="ld__btn-sm" @click.stop="openAddPlanta">
                  <i class="bi bi-plus-lg"></i>
                </button>
                <i class="bi ld__chevron" :class="plantasExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
              </div>
            </button>
            <div v-show="plantasExpanded" class="ld__section-body ld__section-body--flush">
              <div v-if="plants.loading" class="ld__placeholder">Cargando plantas…</div>
              <EmptyState v-else-if="!plantList.length" icon="🪴" title="Sin plantas" message="Sin plantas registradas en este lote." compact>
                <template #actions>
                  <button v-if="canEdit || isCultivador" class="ld__btn-outline" @click="openAddPlanta"><i class="bi bi-plus-lg"></i> Agregar primera planta</button>
                </template>
              </EmptyState>
              <div v-else class="ld__plantas">
                <RouterLink
                  v-for="(p, i) in plantasMostradas" :key="p.id"
                  :to="{ name: 'planta-detalle', params: { id: p.id } }"
                  class="ld__planta"
                >
                  <div class="ld__planta-num">{{ i + 1 }}</div>
                  <div class="ld__planta-dot" :style="{ background: pm(p.state).color }"></div>
                  <div class="ld__planta-info">
                    <div class="ld__planta-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
                    <div class="ld__planta-qr">{{ p.codigo_qr || '—' }}</div>
                  </div>
                  <span class="ld__planta-estado" :style="{ background: pm(p.state).color + '18', color: pm(p.state).color }">
                    {{ pm(p.state).emoji }} {{ pm(p.state).label }}
                  </span>
                  <button v-if="canEdit" class="ld__planta-sel" :class="{ 'ld__planta-sel--on': p.es_seleccion }"
                          :title="p.es_seleccion ? 'Quitar de selección' : 'Marcar como selección'"
                          @click.prevent.stop="toggleEsSeleccion(p)">
                    <i class="bi" :class="p.es_seleccion ? 'bi-star-fill' : 'bi-star'"></i>
                  </button>
                  <i class="bi bi-chevron-right ld__planta-arrow"></i>
                </RouterLink>

              </div>
              <Paginator
                v-if="plantasActivas.length > plantasPerPage"
                v-model:page="plantasPage"
                v-model:perPage="plantasPerPage"
                :total="plantasActivas.length"
                :pageSizes="[10, 25, 50]"
              />

              <!-- Plantas cosechadas agrupadas por pasada -->
              <template v-if="plantasCosechadasPorPasada.length">
                <div v-for="grupo in plantasCosechadasPorPasada" :key="grupo.pasada" class="ld__cosecha-grupo">
                  <div class="ld__cosecha-grupo-header">
                    <span class="ld__cosecha-grupo-label">🌿 Cosecha {{ grupo.pasada }}</span>
                    <span class="ld__cosecha-grupo-count">{{ grupo.plantas.length }} planta{{ grupo.plantas.length !== 1 ? 's' : '' }}</span>
                  </div>
                  <RouterLink
                    v-for="p in grupo.plantas"
                    :key="p.id"
                    :to="{ name: 'planta-detalle', params: { id: p.id } }"
                    class="ld__planta ld__planta--cosechada"
                  >
                    <div class="ld__planta-dot" :style="{ background: pm(p.state).color }"></div>
                    <div class="ld__planta-info">
                      <div class="ld__planta-nombre">{{ p.nombre || p.codigo_qr || `Planta #${p.id}` }}</div>
                      <div class="ld__planta-qr">{{ p.codigo_qr || '—' }}</div>
                    </div>
                    <span class="ld__planta-estado" :style="{ background: pm(p.state).color + '18', color: pm(p.state).color }">
                      {{ pm(p.state).emoji }} {{ pm(p.state).label }}
                    </span>
                    <i class="bi bi-chevron-right ld__planta-arrow"></i>
                  </RouterLink>
                </div>
              </template>

            </div>
          </div>

          <!-- 3. Historial -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="historialExpanded = !historialExpanded">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📜</span>
                <span class="ld__section-title">Historial del lote</span>
              </div>
              <i class="bi ld__chevron" :class="historialExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="historialExpanded" class="ld__section-body ld__section-body--flush">
              <div v-if="loadingEventos" class="ld__placeholder">Cargando historial…</div>
              <EmptyState v-else-if="eventos.length === 0" icon="📜" title="Sin eventos" message="Sin eventos registrados todavía." compact />
              <div v-else class="ld__eventos">
                <div v-for="e in eventos" :key="e._tipo + e.id" class="ld__evento">
                  <template v-if="e._tipo === 'evento'">
                    <div class="ld__evento-dot" :style="{ background: e.tipo === 'cambio_estado' ? '#1b5e20' : '#64748b' }"></div>
                    <div class="ld__evento-content">
                      <div class="ld__evento-head">
                        <span v-if="e.tipo === 'cambio_estado'" class="ld__evento-titulo">
                          {{ em(e.estado_anterior).emoji }} {{ em(e.estado_anterior).label }}
                          <span class="ld__evento-arrow">→</span>
                          {{ em(e.estado_nuevo).emoji }} {{ em(e.estado_nuevo).label }}
                        </span>
                        <span v-else class="ld__evento-titulo">{{ e.descripcion }}</span>
                        <span class="ld__evento-fecha">{{ formatDateTime(e.registrado_en) }}</span>
                      </div>
                      <div class="ld__evento-meta">{{ e.usuario }}</div>
                      <div v-if="e.sala_origen && e.sala_destino" class="ld__evento-sala-move">
                        <i class="bi bi-house-door"></i>
                        <span>{{ e.sala_origen.nombre }}</span>
                        <i class="bi bi-arrow-right"></i>
                        <span>{{ e.sala_destino.nombre }}</span>
                      </div>
                      <div v-if="e.tipo === 'cambio_estado' && e.descripcion" class="ld__evento-desc">{{ e.descripcion }}</div>
                    </div>
                  </template>
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
                      <div v-if="e.tareas_realizadas?.length" class="ld__tareas-chips">
                        <span
                          v-for="tk in e.tareas_realizadas"
                          :key="tk"
                          class="ld__tarea-tag"
                        >{{ TAREAS_LOTE.find(t => t.key === tk)?.emoji }} {{ TAREAS_LOTE.find(t => t.key === tk)?.label || tk }}</span>
                      </div>
                      <div class="ld__registro-metricas">
                        <div v-if="e.temperatura"  class="ld__metrica"><span>🌡️</span><span>{{ e.temperatura }}°C</span></div>
                        <div v-if="e.humedad"      class="ld__metrica"><span>💧</span><span>{{ e.humedad }}%</span></div>
                        <div v-if="e.ph"           class="ld__metrica"><span>⚗️</span><span>pH {{ e.ph }}</span></div>
                        <div v-if="e.ec"           class="ld__metrica"><span>⚡</span><span>EC {{ e.ec }}</span></div>
                        <div v-if="e.co2"          class="ld__metrica"><span>💨</span><span>{{ e.co2 }}ppm</span></div>
                        <div v-if="e.horas_luz"    class="ld__metrica"><span>🕐</span><span>{{ e.horas_luz }}h luz</span></div>
                      </div>
                      <div v-if="e.observaciones" class="ld__evento-desc">{{ e.observaciones }}</div>
                    </div>
                  </template>
                </div>
              </div>
            </div>
          </div>

          <!-- Gráficos ambientales -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="graficosExpanded = !graficosExpanded">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📊</span>
                <span class="ld__section-title">Evolución ambiental</span>
              </div>
              <i class="bi ld__chevron" :class="graficosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="graficosExpanded" class="ld__section-body">
              <GraficosLote :lote-id="id" :key="graficosKey" />
            </div>
          </div>

          <!-- 4. Timeline del ciclo -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="toggleTimeline">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📦</span>
                <span class="ld__section-title">Timeline del ciclo</span>
                <span v-if="timeline?.pesadas?.length" class="ld__pill">{{ timeline.pesadas.length }} pesadas</span>
              </div>
              <i class="bi ld__chevron" :class="timelineExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="timelineExpanded" class="ld__section-body">
              <div v-if="loadingTimeline" class="ld__placeholder">Cargando timeline…</div>
              <EmptyState v-else-if="!timeline" icon="📦" title="Sin datos de ciclo" compact />
              <div v-else class="ld__timeline">

                <!-- Pesadas -->
                <div v-if="timeline.pesadas?.length" class="ld__tl-group">
                  <div class="ld__tl-group-title">🏋️ Pesadas</div>
                  <div v-for="p in timeline.pesadas" :key="p.id" class="ld__tl-row">
                    <div class="ld__tl-fase">
                      <span class="ld__tl-pill" :style="{ background: em(p.fase_origen).bg, color: em(p.fase_origen).color }">{{ em(p.fase_origen).emoji }} {{ em(p.fase_origen).label }}</span>
                      <i class="bi bi-arrow-right" style="color:#94a3b8;font-size:.7rem"></i>
                      <span class="ld__tl-pill" :style="{ background: em(p.fase_destino).bg, color: em(p.fase_destino).color }">{{ em(p.fase_destino).emoji }} {{ em(p.fase_destino).label }}</span>
                    </div>
                    <div class="ld__tl-pesos">
                      <span v-if="p.peso_humedo_g">🌿 húmedo: <strong>{{ p.peso_humedo_g }}g</strong></span>
                      <span v-if="p.peso_seco_g">
                        💨 seco: <strong>{{ p.peso_seco_g }}g</strong>
                        <span v-if="p.peso_humedo_g" class="ld__tl-merma">
                          ({{ (100 - p.peso_seco_g / p.peso_humedo_g * 100).toFixed(1) }}% merma)
                        </span>
                      </span>
                      <span v-if="p.peso_curado_g">
                        🫙 curado: <strong>{{ p.peso_curado_g }}g</strong>
                        <span v-if="p.peso_seco_g" class="ld__tl-merma">
                          ({{ (100 - p.peso_curado_g / p.peso_seco_g * 100).toFixed(1) }}% merma)
                        </span>
                      </span>
                    </div>
                    <div class="ld__tl-meta">{{ p.registrado_por }} · {{ formatDate(p.registrado_at) }}</div>
                  </div>
                </div>

                <!-- Stocks generados -->
                <div v-if="timeline.stocks?.length" class="ld__tl-group">
                  <div class="ld__tl-group-title">🛒 Stocks generados</div>
                  <div v-for="s in timeline.stocks" :key="s.id" class="ld__tl-row">
                    <div class="ld__tl-stock-info">
                      <span class="ld__tl-pill" style="background:#f0fdf4;color:#1b5e20">{{ s.forma_producto || 'flor_seca' }}</span>
                      <span><strong>{{ s.cantidad }}{{ s.unidad }}</strong></span>
                      <span v-if="s.precio_sugerido_ars" class="ld__tl-precio">$ {{ s.precio_sugerido_ars }}/{{ s.unidad }}</span>
                      <span v-if="s.sede_nombre" class="ld__tl-sede">📍 {{ s.sede_nombre }}</span>
                    </div>
                  </div>
                </div>

                <!-- Dispensaciones -->
                <div v-if="timeline.dispensaciones?.length" class="ld__tl-group">
                  <div class="ld__tl-group-title">🧑‍⚕️ Dispensaciones</div>
                  <div v-for="d in timeline.dispensaciones" :key="d.id" class="ld__tl-row">
                    <span>{{ d.socio }}</span>
                    <span><strong>{{ d.cantidad }}{{ d.unidad }}</strong></span>
                    <span class="ld__tl-meta">{{ formatDate(d.fecha) }}</span>
                  </div>
                </div>

                <!-- Trasplantes -->
                <div v-if="timeline.transplantes?.length" class="ld__tl-group">
                  <div class="ld__tl-group-title">🪴 Trasplantes</div>
                  <div v-for="(t, i) in timeline.transplantes" :key="i" class="ld__tl-row">
                    <div class="ld__tl-fase">
                      <span v-if="t.maceta_origen" class="ld__tl-pill" style="background:#f1f5f9;color:#475569">{{ t.maceta_origen }}L</span>
                      <i v-if="t.maceta_origen && t.maceta_destino" class="bi bi-arrow-right" style="color:#94a3b8;font-size:.7rem"></i>
                      <span v-if="t.maceta_destino" class="ld__tl-pill" style="background:#f0fdf4;color:#1b5e20">{{ t.maceta_destino }}L</span>
                    </div>
                    <div class="ld__tl-meta">
                      {{ t.plantas }} planta{{ t.plantas !== 1 ? 's' : '' }}
                      <template v-if="t.usuario"> · {{ t.usuario }}</template>
                      · {{ formatDate(t.fecha) }}
                    </div>
                  </div>
                </div>

                <EmptyState v-if="!timeline.pesadas?.length && !timeline.stocks?.length && !timeline.transplantes?.length" icon="📦" title="Sin actividad de ciclo" compact />
              </div>
            </div>
          </div>

          <!-- 5. Fotos -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="toggleFotos">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">📷</span>
                <span class="ld__section-title">Fotos del lote</span>
                <span v-if="fotos.length > 0" class="ld__pill">{{ fotos.length }}</span>
              </div>
              <div class="ld__section-toggle-right">
                <button class="ld__btn-sm" @click.stop="fotoInput?.click()" :disabled="uploadingFoto">
                  <DsSpinner v-if="uploadingFoto" :size="12" />
                  <i v-else class="bi bi-camera-fill"></i>
                </button>
                <i class="bi ld__chevron" :class="fotosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
              </div>
            </button>
            <input ref="fotoInput" type="file" accept="image/*" style="display:none" @change="handleFotoSelect" />
            <div v-show="fotosExpanded" class="ld__section-body">
              <EmptyState v-if="fotos.length === 0" icon="📷" title="Sin fotos todavía" compact>
                <template #actions>
                  <button class="ld__btn-outline" @click="fotoInput?.click()"><i class="bi bi-camera-fill"></i> Subir primera foto</button>
                </template>
              </EmptyState>
              <div v-else class="ld__fotos-grid">
                <div v-for="(f, i) in fotos" :key="f.id" class="ld__foto">
                  <div class="ld__foto-img-wrap" @click="openLightbox(i)">
                    <img :src="f.url" :alt="f.filename" class="ld__foto-img" />
                  </div>
                  <div class="ld__foto-footer">
                    <div class="ld__foto-info">
                      <span v-if="f.descripcion" class="ld__foto-desc">{{ f.descripcion }}</span>
                      <span class="ld__foto-date">{{ f.created_at_label }}</span>
                    </div>
                    <button v-if="canEdit" class="ld__foto-del" @click.stop="eliminarFoto(f)" title="Eliminar foto">
                      <i class="bi bi-trash"></i>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Aside -->
        <div class="ld__aside">

          <!-- Datos técnicos -->
          <div class="ld__card">
            <div class="ld__card-header"><span class="ld__card-title">⚙️ Datos técnicos</span></div>
            <dl class="ld__dl">
              <dt>Plantas</dt><dd><strong>{{ lote.plants_count ?? 0 }}</strong></dd>
              <dt>Maceta</dt><dd>{{ macetaLabel(lote.tamanio_maceta) }}</dd>
              <dt>Tipo cultivo</dt><dd>{{ growLabel(lote.grow_type) }}</dd>
              <dt>Luminaria</dt><dd>{{ lightLabel(lote.light_type) }}</dd>
              <dt>Genética</dt><dd>{{ lote.genetica?.nombre || '—' }}</dd>
              <dt>Fotoperiodo</dt><dd>{{ lote.fotoperiodo || '—' }}</dd>
              <dt>Semanas flor.</dt><dd>{{ lote.semanas_floracion ? lote.semanas_floracion + ' sem.' : '—' }}</dd>
              <dt>Inicio</dt><dd>{{ lote.start_date || '—' }}</dd>
              <dt>Días ciclo</dt><dd>{{ lote.dias_desde_inicio ?? '—' }}</dd>
            </dl>
          </div>

          <div v-if="lote.notes" class="ld__card ld__card--mt">
            <div class="ld__card-header"><span class="ld__card-title">📋 Notas</span></div>
            <div class="ld__card-notes">{{ lote.notes }}</div>
          </div>

          <!-- Plan vs Real -->
          <div v-if="canAdmin" class="ld__card ld__card--mt">
            <div class="ld__card-header">
              <span class="ld__card-title">🎯 Plan vs Real</span>
              <button v-if="canAdmin" class="ld__card-action" @click="openPlanForm">
                <i class="bi bi-pencil"></i> {{ lote.plants_count_objetivo ? 'Editar' : 'Cargar objetivo' }}
              </button>
            </div>

            <div v-if="showPlanForm" class="ld__costo-form">
              <div class="ld__costo-row">
                <label class="ld__costo-label">Plantas objetivo</label>
                <input type="number" min="0" step="1" class="ld__costo-input" v-model.number="planForm.plants_count_objetivo" placeholder="—" />
              </div>
              <div class="ld__costo-row">
                <label class="ld__costo-label">Rendimiento objetivo (g)</label>
                <input type="number" min="0" step="0.1" class="ld__costo-input" v-model.number="planForm.rendimiento_objetivo_g" placeholder="—" />
              </div>
              <div class="ld__costo-row">
                <label class="ld__costo-label">Fecha cosecha estimada</label>
                <input type="date" class="ld__costo-input" v-model="planForm.fecha_cosecha_estimada" />
              </div>
              <div v-if="lote.estado === 'finalizado'" class="ld__costo-row ld__costo-row--sep">
                <label class="ld__costo-label">Rendimiento real (g)</label>
                <input type="number" min="0" step="0.1" class="ld__costo-input" v-model.number="planForm.rendimiento_real_g" placeholder="—" />
              </div>
              <div class="ld__costo-actions">
                <button class="ld__btn-ghost" @click="showPlanForm = false">Cancelar</button>
                <button class="ld__btn-primary" :disabled="savingPlan" @click="savePlan">
                  {{ savingPlan ? 'Guardando…' : 'Guardar' }}
                </button>
              </div>
            </div>

            <template v-else-if="lote.plants_count_objetivo || lote.rendimiento_objetivo_g">
              <div class="ld__pvr">
                <div v-if="lote.plants_count_objetivo" class="ld__pvr-row">
                  <span class="ld__pvr-label">Plantas</span>
                  <span class="ld__pvr-objetivo">{{ lote.plants_count_objetivo }}</span>
                  <span class="ld__pvr-sep">vs</span>
                  <span class="ld__pvr-real" :class="plantasDevClass">{{ lote.plants_count ?? '—' }}</span>
                  <span v-if="lote.plants_count && lote.plants_count_objetivo" class="ld__pvr-dev" :class="plantasDevClass">
                    {{ plantasDevPct > 0 ? '+' : '' }}{{ plantasDevPct }}%
                  </span>
                </div>
                <div v-if="lote.rendimiento_objetivo_g" class="ld__pvr-row">
                  <span class="ld__pvr-label">Rendimiento</span>
                  <span class="ld__pvr-objetivo">{{ lote.rendimiento_objetivo_g }}g</span>
                  <span class="ld__pvr-sep">vs</span>
                  <span class="ld__pvr-real" :class="rendDevClass">{{ lote.rendimiento_real_g ? lote.rendimiento_real_g + 'g' : '—' }}</span>
                  <span v-if="lote.rendimiento_real_g && lote.rendimiento_objetivo_g" class="ld__pvr-dev" :class="rendDevClass">
                    {{ rendDevPct > 0 ? '+' : '' }}{{ rendDevPct }}%
                  </span>
                </div>
                <div v-if="lote.fecha_cosecha_estimada" class="ld__pvr-row">
                  <span class="ld__pvr-label">Cosecha est.</span>
                  <span class="ld__pvr-objetivo">{{ formatDate(lote.fecha_cosecha_estimada) }}</span>
                </div>
              </div>
            </template>

            <div v-else class="ld__costo-empty">
              <i class="bi bi-bullseye"></i>
              <span>Sin objetivos cargados</span>
            </div>
          </div>

          <!-- Costos de producción: solo admin/supervisor -->
          <div v-if="canAdmin" class="ld__card ld__card--mt">
            <div class="ld__card-header">
              <span class="ld__card-title">💰 Costos de producción</span>
              <button v-if="canAdmin" class="ld__card-action" @click="openCostoForm">
                <i :class="costoLote ? 'bi bi-pencil' : 'bi bi-plus-lg'"></i>
                {{ costoLote ? 'Editar' : 'Cargar' }}
              </button>
            </div>

            <!-- Formulario inline -->
            <div v-if="showCostoForm" class="ld__costo-form">
              <div class="ld__costo-row">
                <label class="ld__costo-label">Insumos (ARS)</label>
                <input type="number" min="0" step="0.01" class="ld__costo-input" v-model.number="costoForm.costo_insumos" placeholder="0" />
              </div>
              <div class="ld__costo-row">
                <label class="ld__costo-label">Energía (ARS)</label>
                <input type="number" min="0" step="0.01" class="ld__costo-input" v-model.number="costoForm.costo_energia" placeholder="0" />
              </div>
              <div class="ld__costo-row">
                <label class="ld__costo-label">Mano de obra (ARS)</label>
                <input type="number" min="0" step="0.01" class="ld__costo-input" v-model.number="costoForm.costo_mano_obra" placeholder="0" />
              </div>
              <div class="ld__costo-row">
                <label class="ld__costo-label">Prorrateado (ARS)</label>
                <input type="number" min="0" step="0.01" class="ld__costo-input" v-model.number="costoForm.costo_prorrateado" placeholder="0" />
              </div>
              <div class="ld__costo-total">
                Total: <strong>{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(costoTotal) }}</strong>
              </div>
              <div class="ld__costo-row ld__costo-row--sep">
                <label class="ld__costo-label">Gramos producidos</label>
                <input type="number" min="0" step="0.1" class="ld__costo-input" v-model.number="costoForm.gramos_producidos" placeholder="g" />
              </div>
              <div v-if="costoPorGramo" class="ld__costo-cpg">
                <span>Costo/g: </span>
                <strong>{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 2 }).format(costoPorGramo) }}</strong>
              </div>
              <div class="ld__costo-row">
                <label class="ld__costo-label">Notas</label>
                <input type="text" class="ld__costo-input" v-model="costoForm.notas" placeholder="Opcional" />
              </div>
              <div class="ld__costo-actions">
                <button class="ld__btn-ghost" @click="showCostoForm = false">Cancelar</button>
                <button class="ld__btn-primary" :disabled="savingCosto" @click="saveCosto">
                  {{ savingCosto ? 'Guardando…' : 'Guardar costos' }}
                </button>
              </div>
            </div>

            <!-- Vista datos guardados -->
            <template v-else-if="costoLote">
              <dl class="ld__dl">
                <dt>Insumos</dt><dd>{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(costoLote.costo_insumos || 0) }}</dd>
                <dt>Energía</dt><dd>{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(costoLote.costo_energia || 0) }}</dd>
                <dt>Mano de obra</dt><dd>{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(costoLote.costo_mano_obra || 0) }}</dd>
                <dt v-if="costoLote.costo_prorrateado">Prorrateado</dt><dd v-if="costoLote.costo_prorrateado">{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(costoLote.costo_prorrateado || 0) }}</dd>
                <dt class="ld__dl-total">Total</dt><dd class="ld__dl-total">{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 0 }).format(costoLote.costo_total || 0) }}</dd>
                <dt v-if="costoLote.gramos_producidos">Rendimiento</dt><dd v-if="costoLote.gramos_producidos">{{ costoLote.gramos_producidos }}g</dd>
              </dl>
              <div v-if="costoLote.costo_por_gramo" class="ld__cpg-badge">
                <span class="ld__cpg-label">Costo/gramo</span>
                <span class="ld__cpg-value">{{ new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', minimumFractionDigits: 2 }).format(costoLote.costo_por_gramo) }}</span>
              </div>
            </template>

            <div v-else class="ld__costo-empty">
              <i class="bi bi-calculator"></i>
              <span>Sin costos cargados</span>
            </div>
          </div>

          <!-- Análisis IA — solo si el club tiene IA habilitada -->
          <div v-if="club.data?.features?.ia_analisis && canAdmin" class="ld__card ld__card--mt ld__card--ia">
            <div class="ld__card-header">
              <span class="ld__card-title">🤖 Análisis IA</span>
              <button class="ld__card-action ld__card-action--ia" @click="ejecutarAnalisisIA" :disabled="analizandoIA || !puedoAnalizar">
                <DsSpinner v-if="analizandoIA" :size="11" />
                <i v-else class="bi bi-stars"></i>
                <span v-if="analizandoIA">Analizando…</span>
                <span v-else-if="!puedoAnalizar">{{ tiempoRestante }}</span>
                <span v-else>{{ historialAnalisis.length ? 'Nuevo análisis' : 'Analizar lote' }}</span>
              </button>
            </div>

            <div v-if="historialAnalisis.length" class="ld__ia-historial">
              <div
                v-for="(analisis, idx) in historialAnalisis"
                :key="analisis.id"
                class="ld__ia-item"
              >
                <button class="ld__ia-item-header" @click="toggleAnalisis(analisis.id)">
                  <div class="ld__ia-meta">
                    <i class="bi bi-clock"></i>
                    {{ formatearFechaRelativa(analisis.created_at) }}
                    <span v-if="idx === 0" class="ld__ia-badge">último</span>
                    <span v-if="analisis.tokens_usados" class="ld__ia-tokens">{{ analisis.tokens_usados }} tokens</span>
                  </div>
                  <i class="bi" :class="expandedAnalisis === analisis.id ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
                </button>
                <div v-if="expandedAnalisis === analisis.id" class="ld__ia-contenido">{{ analisis.contenido }}</div>
              </div>
            </div>

            <div v-else-if="!analizandoIA" class="ld__costo-empty">
              <i class="bi bi-stars"></i>
              <span>Generá un análisis experto del historial de este lote</span>
            </div>
          </div>

        </div>
      </div>
    </template>

    <!-- ══ Modal Agregar Planta ══ -->
    <Teleport to="body">
      <div v-if="showAddPlanta" class="ld__overlay">
        <div class="ld__modal" style="max-width:420px">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">🪴 Agregar planta</h3>
              <p class="ld__modal-sub">{{ lote?.codigo }} · ID autogenerado</p>
            </div>
            <button class="ld__modal-close" @click="showAddPlanta = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="plantaError" class="ld__alert">{{ plantaError }}</div>
            <div v-if="lote?.genetica" class="ld__planta-info-box">
              <span>🧬 Genética heredada del lote:</span>
              <strong>{{ lote.genetica.nombre }}</strong>
            </div>
            <div class="ld__grid">
              <div class="ld__field">
                <label class="ld__label">Estado inicial</label>
                <select class="ld__input" v-model="plantaForm.state">
                  <option value="germinacion">🌰 Semilla/Germinación</option>
                  <option value="esqueje">✂️ Esqueje</option>
                  <option value="vegetativo">🍃 Vegetativo</option>
                  <option value="floracion">🌸 Floración</option>
                </select>
              </div>
              <div class="ld__field">
                <label class="ld__label">Origen</label>
                <select class="ld__input" v-model="plantaForm.origen">
                  <option value="semilla">🌰 Semilla</option>
                  <option value="esqueje">✂️ Esqueje</option>
                  <option value="division">🪴 División</option>
                </select>
              </div>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingPlanta" @click="showAddPlanta = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingPlanta" @click="guardarPlanta">
              <DsSpinner v-if="savingPlanta" :size="14" />
              <i v-else class="bi bi-plus-lg"></i>Agregar planta
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Editar Lote ══ -->
    <Teleport to="body">
      <div v-if="showEditLote" class="ld__overlay">
        <div class="ld__modal">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">✏️ Editar lote</h3>
              <p class="ld__modal-sub">{{ lote?.codigo }}</p>
            </div>
            <button class="ld__modal-close" @click="showEditLote = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="editLoteError" class="ld__alert">{{ editLoteError }}</div>
            <div class="ld__grid">
              <div class="ld__field">
                <label class="ld__label">Código <span style="font-size:.7rem;font-weight:400;color:#94a3b8;margin-left:.3rem">autogenerado · inmutable</span></label>
                <div class="ld__input" style="color:#64748b;cursor:default;background:#f8fafc;font-family:monospace">{{ editLoteForm.codigo }}</div>
              </div>
              <div class="ld__field">
                <label class="ld__label">Fecha de inicio</label>
                <input type="date" class="ld__input" v-model="editLoteForm.start_date" />
              </div>
              <div class="ld__field">
                <label class="ld__label">Genética / Variedad</label>
                <select class="ld__input" v-model="editLoteForm.genetica_id">
                  <option value="">Sin especificar</option>
                  <option v-for="g in geneticas" :key="g.id" :value="g.id">
                    {{ g.nombre }}{{ g.registrada_inase ? ' 🏛️' : '' }} — {{ g.tipo }}
                  </option>
                </select>
              </div>
              <div class="ld__field">
                <label class="ld__label">Tipo de cultivo</label>
                <select class="ld__input" v-model="editLoteForm.grow_type">
                  <option value="">Sin especificar</option>
                  <option value="sustrato">Sustrato</option>
                  <option value="hidroponia">Hidroponia</option>
                  <option value="aeroponia">Aeroponia</option>
                </select>
              </div>
              <div class="ld__field">
                <label class="ld__label">Tipo de luz</label>
                <select class="ld__input" v-model="editLoteForm.light_type">
                  <option value="">Sin especificar</option>
                  <option value="led">LED</option>
                  <option value="hps">HPS</option>
                  <option value="cmh">CMH</option>
                  <option value="natural">Natural</option>
                  <option value="mixta">Mixta</option>
                </select>
              </div>
              <div class="ld__field">
                <label class="ld__label">Semanas de floración</label>
                <label class="ld__checkbox-row">
                  <input type="checkbox" v-model="editLoteForm.tiene_semanas" />
                  <span>Definir semanas</span>
                </label>
                <input v-if="editLoteForm.tiene_semanas" type="number" min="1" max="24" step="1"
                       class="ld__input" v-model.number="editLoteForm.semanas_floracion"
                       placeholder="Ej: 9" style="margin-top:.35rem" />
              </div>
              <div class="ld__field">
                <label class="ld__label">Tamaño de maceta (L)</label>
                <select class="ld__input" v-model="editLoteForm.tamanio_maceta">
                  <option value="">Sin especificar</option>
                  <option value="1">1 litro</option>
                  <option value="3">3 litros</option>
                  <option value="5">5 litros</option>
                  <option value="7">7 litros</option>
                  <option value="10">10 litros</option>
                  <option value="12">12 litros</option>
                  <option value="15">15 litros</option>
                </select>
              </div>
              <div class="ld__field ld__field--full">
                <label class="ld__label">Notas</label>
                <textarea class="ld__input ld__textarea" rows="3" v-model.trim="editLoteForm.notes" placeholder="Observaciones internas…"></textarea>
              </div>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingEditLote" @click="showEditLote = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingEditLote" @click="saveEditLote">
              <DsSpinner v-if="savingEditLote" :size="14" />
              <i v-else class="bi bi-check-lg"></i>Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Registro del Lote (nuevo) ══ -->
    <RegistroLoteModal
      v-model="showRegistroModalNew"
      :lote="lote"
      @saved="loadEventos(); lotes.fetchOne(id); graficosKey++"
    />

    <!-- ══ Modal Registro del Lote (legacy — se puede eliminar cuando el nuevo esté validado) ══ -->
    <Teleport to="body">
      <div v-if="showRegistroModal" class="ld__overlay">
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

            <!-- Tareas realizadas -->
            <div class="ld__msection">Tareas realizadas <span class="ld__optional">opcional, seleccioná todas las que apliquen</span></div>
            <div class="ld__tareas-grid">
              <button
                v-for="t in TAREAS_LOTE"
                :key="t.key"
                type="button"
                class="ld__tarea-chip"
                :class="{ 'ld__tarea-chip--active': registroForm.tareas_realizadas.includes(t.key) }"
                @click="toggleTarea(t.key)"
              >
                <span>{{ t.emoji }}</span> {{ t.label }}
              </button>
            </div>

            <div class="ld__grid">
              <div class="ld__field ld__field--full">
                <label class="ld__label">Estado general</label>
                <div class="ld__selector">
                  <button v-for="(meta, key) in ESTADO_SALUD_META" :key="key" type="button" class="ld__sel-btn"
                          :class="{ 'ld__sel-btn--active': registroForm.estado_general === key }"
                          :style="registroForm.estado_general === key ? { borderColor: meta.color, background: meta.color + '15', color: meta.color } : {}"
                          @click="registroForm.estado_general = key">
                    {{ meta.emoji }} {{ key }}
                  </button>
                </div>
              </div>
              <div class="ld__field ld__field--full">
                <label class="ld__label">Plagas</label>
                <div class="ld__selector">
                  <button v-for="(meta, key) in PLAGAS_META" :key="key" type="button" class="ld__sel-btn"
                          :class="{ 'ld__sel-btn--active': registroForm.plagas_observadas === key }"
                          :style="registroForm.plagas_observadas === key ? { borderColor: meta.color, background: meta.color + '15', color: meta.color } : {}"
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
                <input type="number" step="0.1" class="ld__input" :class="{ 'ld__input--err': registroErrors.temperatura }" v-model.number="registroForm.temperatura" placeholder="24.5" />
                <span v-if="registroErrors.temperatura" class="ld__err-msg">{{ registroErrors.temperatura }}</span>
              </div>
              <div class="ld__field">
                <label class="ld__label">Temperatura sustrato (°C)</label>
                <input type="number" step="0.1" class="ld__input" :class="{ 'ld__input--err': registroErrors.temperatura_sustrato }" v-model.number="registroForm.temperatura_sustrato" placeholder="22.0" />
              </div>
              <div class="ld__field">
                <label class="ld__label">Humedad (%)</label>
                <input type="number" step="0.1" class="ld__input" :class="{ 'ld__input--err': registroErrors.humedad }" v-model.number="registroForm.humedad" placeholder="60" />
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
                <input type="number" step="0.1" class="ld__input" :class="{ 'ld__input--err': registroErrors.ph }" v-model.number="registroForm.ph" placeholder="6.2" />
              </div>
              <div class="ld__field">
                <label class="ld__label">pH runoff</label>
                <input type="number" step="0.1" class="ld__input" v-model.number="registroForm.ph_runoff" placeholder="6.0" />
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
                <input type="number" step="0.5" class="ld__input" :class="{ 'ld__input--err': registroErrors.horas_luz }" v-model.number="registroForm.horas_luz" placeholder="18" />
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
            </div>
            <div class="ld__modal-section-title">Fertilización</div>
            <div class="ld__field ld__field--full">
              <label class="ld__toggle">
                <input type="checkbox" v-model="registroForm.fertilizacion" class="ld__toggle-input" />
                <div class="ld__toggle-track"><div class="ld__toggle-thumb"></div></div>
                <span class="ld__toggle-label">Se realizó fertilización</span>
              </label>
              <textarea v-if="registroForm.fertilizacion" class="ld__input ld__textarea" style="margin-top:.6rem" rows="2"
                        v-model.trim="registroForm.notas_fertilizacion" placeholder="Ej: Base A 10ml/L + Base B 10ml/L"></textarea>
            </div>
            <div class="ld__modal-section-title">CSV sensor <span class="ld__optional">opcional</span></div>
            <div class="ld__field">
              <div class="ld__csv-upload" @click="csvInput?.click()">
                <i class="bi bi-file-earmark-spreadsheet"></i>
                <span v-if="csvFile">{{ csvFile.name }}</span>
                <span v-else>Subir CSV (Bluelab, Apogee, etc.)</span>
              </div>
              <input ref="csvInput" type="file" accept=".csv,.txt" style="display:none" @change="handleCsvChange" />
            </div>
            <div class="ld__field ld__field--full" style="margin-top:1rem">
              <label class="ld__label">Observaciones <span class="ld__optional">opcional</span></label>
              <textarea class="ld__input ld__textarea" rows="2" v-model.trim="registroForm.observaciones" placeholder="Cualquier observación relevante…"></textarea>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingRegistro" @click="showRegistroModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingRegistro || Object.keys(registroErrors).length > 0" @click="guardarRegistro">
              <DsSpinner v-if="savingRegistro" :size="14" />
              <i v-else class="bi bi-check-lg"></i>Guardar registro
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Avanzar Fase ══ -->
    <Teleport to="body">
      <div v-if="showTransicionModal" class="ld__overlay">
        <div class="ld__modal" style="max-width:440px">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">🔄 Avanzar fase</h3>
              <p class="ld__modal-sub">
                {{ lote?.codigo }} · {{ em(lote?.estado).emoji }} {{ em(lote?.estado).label }}
                <span style="color:#94a3b8"> → </span>
                {{ em(lote?.proxima_fase_posible).emoji }} {{ em(lote?.proxima_fase_posible).label }}
              </p>
            </div>
            <button class="ld__modal-close" @click="showTransicionModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="transicionError" class="ld__alert">{{ transicionError }}</div>

            <!-- Peso húmedo (cosecha → manicura, opcional) -->
            <template v-if="lote?.proxima_fase_posible === 'secado'">
              <div class="ld__field" style="margin-bottom:1rem">
                <label class="ld__label">Peso húmedo total (g) <span class="ld__optional">opcional</span></label>
                <input type="number" step="0.1" min="0" class="ld__input" v-model.number="transicionForm.peso_humedo_g" placeholder="ej: 1200.5" />
                <span class="ld__optional">Peso cosechado fresco al inicio del secado</span>
              </div>
            </template>

            <!-- Peso seco (secado → curado) -->
            <div v-if="lote?.proxima_fase_posible === 'curado'" class="ld__field" style="margin-bottom:1rem">
              <label class="ld__label">Peso seco (g) <span style="color:#dc2626">*</span></label>
              <input type="number" step="0.1" min="0" class="ld__input" v-model.number="transicionForm.peso_seco_g" placeholder="ej: 350.0" />
              <span class="ld__optional">Al ingreso del curado</span>
            </div>

            <div class="ld__field">
              <label class="ld__label">Notas <span class="ld__optional">opcional</span></label>
              <textarea class="ld__input ld__textarea" rows="2" v-model="transicionForm.notas" placeholder="Observaciones del cambio de fase…"></textarea>
            </div>

            <div class="ld__field">
              <label class="ld__label">Sala destino</label>
              <select v-model="transicionSalaId" class="ld__input">
                <option :value="null">— Misma sala —</option>
                <option v-for="s in lote?.salas_destino || []" :key="s.id" :value="s.id">
                  {{ s.nombre }}{{ s.actual ? ' (actual)' : '' }}
                </option>
              </select>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingTransicion" @click="showTransicionModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingTransicion" @click="ejecutarTransicion">
              <DsSpinner v-if="savingTransicion" :size="14" />
              <i v-else class="bi bi-arrow-right-circle"></i>Avanzar fase
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Cosecha (cultivador) ══ -->
    <Teleport to="body">
      <div v-if="showCosechaModal" class="ld__overlay">
        <div class="ld__modal" style="max-width:420px">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">🌿 Registrar cosecha</h3>
              <p class="ld__modal-sub">{{ lote?.codigo }} · floración → cosecha</p>
            </div>
            <button class="ld__modal-close" @click="showCosechaModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div class="ld__field">
              <label class="ld__label">Plantas cosechadas <span style="color:var(--c-rust-600)">*</span></label>
              <input
                type="number" min="1" :max="lote?.plants_count"
                class="ld__input" v-model.number="cosechaForm.plantas_cosechadas"
                placeholder="ej: 12"
                autofocus
              />
              <span class="ld__hint">Plantas que pasaron a cosecha (máx {{ lote?.plants_count }})</span>
            </div>
            <div class="ld__field">
              <label class="ld__label">Sala destino</label>
              <select v-model="cosechaSalaId" class="ld__input">
                <option :value="null">— Misma sala —</option>
                <option v-for="s in lote?.salas_destino || []" :key="s.id" :value="s.id">
                  {{ s.nombre }}{{ s.actual ? ' (actual)' : '' }}
                </option>
              </select>
            </div>
            <div class="ld__field">
              <label class="ld__label">Notas (opcional)</label>
              <textarea class="ld__input ld__textarea" rows="2" v-model="cosechaForm.notas" placeholder="Observaciones de la cosecha…"></textarea>
            </div>
            <div v-if="cosechaError" class="ld__alert">{{ cosechaError }}</div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingCosecha" @click="showCosechaModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingCosecha || !cosechaForm.plantas_cosechadas" @click="ejecutarCosecha">
              <DsSpinner v-if="savingCosecha" :size="14" />
              <i v-else class="bi bi-scissors"></i>Confirmar cosecha
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Avanzar Fase (cultivador) — confirmar sala destino ══ -->
    <Teleport to="body">
      <div v-if="showAvanzarSalaModal" class="ld__overlay">
        <div class="ld__modal" style="max-width:400px">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">
                {{ em(lote?.estado).emoji }} → {{ em(lote?.proxima_fase_posible).emoji }} Avanzar fase
              </h3>
              <p class="ld__modal-sub">
                {{ lote?.codigo }} · {{ em(lote?.estado).label }} → {{ em(lote?.proxima_fase_posible).label }}
              </p>
            </div>
            <button class="ld__modal-close" @click="showAvanzarSalaModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div class="ld__field">
              <label class="ld__label">Sala destino</label>
              <select v-model="avanzarSalaId" class="ld__input">
                <option :value="null">— Misma sala —</option>
                <option v-for="s in lote?.salas_destino || []" :key="s.id" :value="s.id">
                  {{ s.nombre }}{{ s.actual ? ' (actual)' : '' }}
                </option>
              </select>
              <span class="ld__optional">Si el lote no cambia de espacio físico, dejá la opción actual.</span>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" @click="showAvanzarSalaModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="transicionandoRapido" @click="avanzarFaseRapido(avanzarSalaId)">
              <DsSpinner v-if="transicionandoRapido" :size="14" />
              <i v-else class="bi bi-arrow-right-circle"></i>Confirmar avance
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Cerrar Curado ══ -->
    <Teleport to="body">
      <div v-if="showCerrarCuradoModal" class="ld__overlay">
        <div class="ld__modal" style="max-width:500px">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">🫙 Cerrar curado y generar stock</h3>
              <p class="ld__modal-sub">{{ lote?.codigo }}</p>
            </div>
            <button class="ld__modal-close" @click="showCerrarCuradoModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="curadoError" class="ld__alert">{{ curadoError }}</div>

            <!-- Peso curado -->
            <div class="ld__field" style="margin-bottom:1rem">
              <label class="ld__label">Peso curado (g) <span style="color:#dc2626">*</span></label>
              <input type="number" step="0.1" min="0" class="ld__input" v-model.number="curadoForm.peso_curado_g" placeholder="ej: 320.0" />
              <span class="ld__optional">Peso final del producto curado</span>
            </div>

            <!-- Splitter -->
            <div class="ld__modal-section-title">Distribución del lote</div>
            <div class="ld__grid" style="margin-bottom:.5rem">
              <div class="ld__field">
                <label class="ld__label">Flor seca (g) <span style="color:#dc2626">*</span></label>
                <input type="number" step="0.1" min="0" class="ld__input" v-model.number="curadoForm.flor_seca" placeholder="ej: 280.0" />
              </div>
              <div class="ld__field">
                <label class="ld__label">Descarte (g) <span style="color:#dc2626">*</span></label>
                <input type="number" step="0.1" min="0" class="ld__input" v-model.number="curadoForm.descarte" placeholder="ej: 40.0" />
              </div>
            </div>
            <div class="ld__split-check" :class="splitOk ? 'ld__split-check--ok' : 'ld__split-check--err'">
              <span v-if="curadoForm.peso_curado_g">
                Total: {{ ((parseFloat(curadoForm.flor_seca) || 0) + (parseFloat(curadoForm.descarte) || 0)).toFixed(1) }}g
                / {{ parseFloat(curadoForm.peso_curado_g).toFixed(1) }}g
                <strong v-if="splitOk"> ✓</strong>
                <span v-else style="color:#dc2626"> ✗ debe coincidir exactamente</span>
              </span>
              <span v-else style="color:#94a3b8">Ingresá el peso curado para validar el splitter</span>
            </div>

            <!-- Stock -->
            <div class="ld__modal-section-title">Stock generado (flor seca)</div>
            <div class="ld__field" style="margin-bottom:1rem">
              <label class="ld__label">Sede destino <span style="color:#dc2626">*</span></label>
              <select class="ld__input" v-model="curadoForm.sede_destino_id">
                <option :value="null" disabled>Seleccioná una sede…</option>
                <option v-for="s in sedes" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
            </div>
            <div class="ld__grid">
              <div class="ld__field">
                <label class="ld__label">Costo unitario (ARS/g) <span class="ld__optional">opcional</span></label>
                <input type="number" step="0.01" min="0" class="ld__input" v-model.number="curadoForm.costo_unitario_ars" placeholder="ej: 1200.00" />
              </div>
              <div class="ld__field">
                <label class="ld__label">Precio sugerido (ARS/g) <span class="ld__optional">opcional</span></label>
                <input type="number" step="0.01" min="0" class="ld__input" v-model.number="curadoForm.precio_sugerido_ars" placeholder="ej: 2500.00" />
              </div>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingCurado" @click="showCerrarCuradoModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingCurado || !splitOk || !curadoForm.sede_destino_id" @click="ejecutarCerrarCurado">
              <DsSpinner v-if="savingCurado" :size="14" />
              <i v-else class="bi bi-box-seam"></i>Cerrar curado
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Trasplante de Lote ══ -->
    <LoteTrasplanteModal
      v-model="showTrasplanteLote"
      :lote="lote"
      :plants="plantList"
      @saved="lotes.fetchOne(id)"
    />

    <!-- ══ Modal Subida de Foto ══ -->
    <Teleport to="body">
      <div v-if="showFotoUploadModal" class="ld__overlay">
        <div class="ld__modal ld__modal--sm">
          <div class="ld__modal-header">
            <div>
              <h3 class="ld__modal-title">📷 Subir foto</h3>
              <p class="ld__modal-sub">{{ fotoUploadFile?.name }}</p>
            </div>
            <button class="ld__modal-close" @click="cancelarSubidaFoto"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="ld__modal-body">
            <div v-if="fotoUploadPreview" class="ld__foto-preview-wrap">
              <img :src="fotoUploadPreview" class="ld__foto-preview-img" alt="Preview" />
            </div>
            <div class="ld__field" style="margin-top: .85rem">
              <label class="ld__label">Descripción <span class="ld__optional">opcional</span></label>
              <input type="text" class="ld__input" v-model.trim="fotoUploadDescripcion"
                     placeholder="Ej: día 14 vegetativo, síntoma de deficiencia…" maxlength="200" />
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" @click="cancelarSubidaFoto">Cancelar</button>
            <button class="ld__btn-primary" :disabled="uploadingFoto" @click="confirmarSubidaFoto">
              <DsSpinner v-if="uploadingFoto" :size="14" />
              <i v-else class="bi bi-cloud-upload"></i>Subir foto
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <Lightbox
      :images="lightboxImages"
      :index="lightboxIndex"
      :open="lightboxOpen"
      @close="lightboxOpen = false"
      @update:index="lightboxIndex = $event"
    />

    <!-- ══ Modal Cosecha Parcial ══ -->
    <ModalCosechaPartial
      v-if="showCosechaPartialModal && lote"
      :lote="lote"
      :plantas="plantList"
      :pasadas-usadas="pasadasUsadas"
      :pasada-inicial="siguientePasada"
      :salas-destino="lote.salas_destino || []"
      @cosechado="onCosechadoParcial"
      @cerrar="showCosechaPartialModal = false"
    />

    <!-- ══ Modal Iniciar Manicura ══ -->
    <IniciarManicuraModal
      v-model="showIniciarManicuraModal"
      :lote="lote"
      :salas-destino="lote?.salas_destino || []"
      @avanzado="onManicuraIniciada"
    />

    <!-- ══ Modal Completar Manicura ══ -->
    <CompletarManicuraModal
      v-model="showCompletarManicuraModal"
      :lote="lote"
      @completado="onManicuraCompletada"
    />

  </div>
</template>

<style scoped>
.ld { padding: 1.75rem 1.5rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .ld { padding: 1rem; } }
.ld__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.ld__error { padding: 1rem 1.25rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 10px; }
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
.ld__ciclo-dot { width: 36px; height: 36px; border-radius: 50%; background: #e8f5e9; border: 2px solid #d4e6d4; display: flex; align-items: center; justify-content: center; margin-bottom: .4rem; position: relative; z-index: 1; }
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
.ld__pill--cosechada { background: #dbeafe; color: #1d4ed8; }
.ld__chevron { color: #60725d; font-size: .75rem; }
.ld__section-body { border-top: 1px solid #e8f0e9; padding: 1rem 1.1rem; }
.ld__section-body--flush { padding: 0; border-top: 1px solid #e8f0e9; }
.ld__plantas { display: flex; flex-direction: column; }
.ld__planta { display: flex; align-items: center; gap: .75rem; padding: .75rem 1.1rem; text-decoration: none; color: inherit; border-bottom: 1px solid #f0fdf4; transition: background .15s; }
.ld__planta:hover { background: #f9fdf9; }
.ld__planta-num { font-size: .72rem; color: #94a3b8; font-weight: 600; width: 20px; text-align: right; flex-shrink: 0; }
.ld__planta-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.ld__planta-info { flex: 1; min-width: 0; }
.ld__planta-nombre { font-size: .85rem; font-weight: 600; color: #1a1a1a; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.ld__planta-qr { font-size: .7rem; color: #94a3b8; font-family: monospace; }
.ld__planta-estado { font-size: .68rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; white-space: nowrap; flex-shrink: 0; }
.ld__planta-arrow { color: #a7d7a9; font-size: .75rem; flex-shrink: 0; }
.ld__ver-mas { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1.1rem; border-top: 1px solid #f0fdf4; background: #fafbfc; }
.ld__btn-ver-mas { display: inline-flex; align-items: center; gap: .35rem; background: none; border: none; color: #1b5e20; font-size: .82rem; font-weight: 600; cursor: pointer; }
.ld__btn-ver-mas:hover { text-decoration: underline; }
.ld__ver-mas-hint { font-size: .72rem; color: #94a3b8; }
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
.ld__evento-sala-move {
  display: flex; align-items: center; gap: 5px;
  margin-top: .3rem;
  font-size: .73rem; color: #0369a1; font-weight: 600;
  background: #f0f9ff; border: 1px solid #bae6fd;
  border-radius: 8px; padding: 3px 8px; width: fit-content;
}
.ld__registro-metricas { display: flex; flex-wrap: wrap; gap: .5rem; margin: .35rem 0; }
.ld__metrica { display: flex; align-items: center; gap: .25rem; background: #f4f8f4; border: 1px solid #d4e6d4; border-radius: 6px; padding: .2em .55em; font-size: .72rem; font-weight: 600; }
.ld__fotos-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: .75rem; padding: 1rem 1.1rem; }
.ld__foto { border-radius: 10px; overflow: hidden; border: 1px solid #d4e6d4; }
.ld__foto-img-wrap { cursor: pointer; }
.ld__foto-img { width: 100%; height: 120px; object-fit: cover; display: block; transition: opacity .15s; }
.ld__foto-img-wrap:hover .ld__foto-img { opacity: .85; }
.ld__foto-footer { display: flex; align-items: flex-start; justify-content: space-between; gap: .25rem; padding: .35rem .5rem; background: #f4f8f4; min-height: 28px; }
.ld__foto-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; }
.ld__foto-desc { font-size: .65rem; color: var(--c-ink-700, #334155); line-height: 1.3; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 500; }
.ld__foto-date { font-size: .6rem; color: #94a3b8; }
.ld__foto-del { flex-shrink: 0; background: none; border: none; padding: 2px 3px; cursor: pointer; color: #94a3b8; border-radius: 4px; line-height: 1; font-size: .7rem; transition: color .12s, background .12s; }
.ld__foto-del:hover { color: #dc2626; background: #fee2e2; }
.ld__foto-preview-wrap { border-radius: 8px; overflow: hidden; border: 1px solid var(--c-ink-100, #e2e8f0); }
.ld__foto-preview-img { width: 100%; max-height: 240px; object-fit: contain; display: block; background: #f8fafc; }
.ld__selector { display: flex; gap: .4rem; flex-wrap: wrap; }
.ld__sel-btn { display: flex; align-items: center; gap: .3rem; padding: .4rem .8rem; border: 1.5px solid #d4e6d4; border-radius: 8px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; text-transform: capitalize; }
.ld__sel-btn:hover { border-color: #1b5e20; }
.ld__sel-btn--active { transform: translateY(-1px); }
.ld__tareas-grid { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: .25rem; }
.ld__tarea-chip { display: inline-flex; align-items: center; gap: .3rem; padding: .38rem .8rem; border: 1.5px solid #d4e6d4; border-radius: 999px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; user-select: none; }
.ld__tarea-chip:hover { border-color: #1b5e20; background: #f0fdf4; }
.ld__tarea-chip--active { background: #e8f5e9; border-color: #1b5e20; color: #1b5e20; box-shadow: 0 1px 4px rgba(27,94,32,.15); }
.ld__tareas-chips { display: flex; flex-wrap: wrap; gap: .35rem; margin-bottom: .4rem; }
.ld__tarea-tag { display: inline-flex; align-items: center; gap: .25rem; background: #e8f5e9; border: 1px solid #a7d7a9; color: #1b5e20; border-radius: 999px; padding: .15em .6em; font-size: .7rem; font-weight: 600; }
.ld__etapas-selector { display: flex; gap: .5rem; flex-wrap: wrap; }
.ld__etapa-btn { display: flex; align-items: center; gap: .4rem; padding: .5rem 1rem; border: 1.5px solid #d4e6d4; border-radius: 10px; background: #f4f8f4; font-size: .85rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.ld__etapa-btn:hover { border-color: #1b5e20; }
.ld__etapa-btn--active { transform: translateY(-1px); }
.ld__toggle { display: flex; align-items: center; gap: .65rem; cursor: pointer; }
.ld__toggle-input { display: none; }
.ld__toggle-track { width: 38px; height: 21px; background: #d4e6d4; border-radius: 999px; position: relative; transition: background .2s; flex-shrink: 0; }
.ld__toggle-input:checked + .ld__toggle-track { background: #1b5e20; }
.ld__toggle-thumb { position: absolute; width: 15px; height: 15px; background: #fff; border-radius: 50%; top: 3px; left: 3px; transition: left .2s; }
.ld__toggle-input:checked + .ld__toggle-track .ld__toggle-thumb { left: 20px; }
.ld__toggle-label { font-size: .875rem; font-weight: 500; }
.ld__csv-upload { display: flex; align-items: center; gap: .75rem; padding: .85rem 1rem; border: 1.5px dashed #d4e6d4; border-radius: 10px; background: #f4f8f4; cursor: pointer; font-size: .85rem; color: #60725d; transition: all .15s; }
.ld__csv-upload:hover { border-color: #1b5e20; }
.ld__csv-upload i { font-size: 1.2rem; }
.ld__modal-section-title { font-size: .72rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .06em; margin: 1.1rem 0 .6rem; padding-bottom: .4rem; border-bottom: 1px solid #e8f0e9; }
.ld__planta-info-box { background: #f0fdf4; border: 1px solid #d4e6d4; border-radius: 9px; padding: .625rem .875rem; font-size: .82rem; color: #374151; display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }
.ld__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.ld__card--mt { margin-top: 1rem; }
.ld__card-header { display: flex; align-items: center; justify-content: space-between; padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; }
.ld__card-title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.ld__card-notes { padding: .9rem 1rem; font-size: .82rem; color: #475569; line-height: 1.6; }
.ld__card-action { background: none; border: 1px solid #d4e6d4; color: #15803d; font-size: .75rem; font-weight: 600; padding: .25rem .65rem; border-radius: 6px; cursor: pointer; display: flex; align-items: center; gap: .3rem; transition: background .15s; }
.ld__card-action:hover { background: #f0fdf4; }
.ld__dl { display: grid; grid-template-columns: auto 1fr; gap: .4rem .75rem; padding: .9rem 1rem; margin: 0; }
.ld__dl dt { font-size: .75rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.ld__dl dd { font-size: .8rem; color: #1a1a1a; font-weight: 500; margin: 0; }
.ld__dl-total { font-weight: 700 !important; color: #1a3d2e !important; border-top: 1px solid #e8f0e9; padding-top: .3rem; }

/* ── Costos ── */
.ld__costo-form { padding: .9rem 1rem; display: flex; flex-direction: column; gap: .6rem; }
.ld__costo-row { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.ld__costo-row--sep { border-top: 1px solid #e8f0e9; padding-top: .6rem; margin-top: .2rem; }
.ld__costo-label { font-size: .75rem; color: #60725d; font-weight: 500; flex-shrink: 0; }
.ld__costo-input { width: 120px; padding: .3rem .5rem; border: 1px solid #d4e6d4; border-radius: 6px; font-size: .8rem; text-align: right; background: #f9fdfb; }
.ld__costo-input:focus { outline: none; border-color: #15803d; }
.ld__costo-total { font-size: .8rem; font-weight: 700; color: #1a3d2e; text-align: right; padding: .4rem .5rem; background: #f0fdf4; border-radius: 6px; }
.ld__costo-cpg { font-size: .8rem; color: #0369a1; text-align: right; font-weight: 600; }
.ld__costo-actions { display: flex; justify-content: flex-end; gap: .5rem; margin-top: .4rem; }
.ld__costo-empty { display: flex; flex-direction: column; align-items: center; gap: .4rem; padding: 1.2rem 1rem; color: #94a3b8; font-size: .8rem; }
.ld__costo-empty i { font-size: 1.4rem; }
.ld__card--ia { border-color: #e9d8fd; }
.ld__card-action--ia { background: linear-gradient(135deg, #7c3aed, #9333ea); color: #fff; border: none; padding: .3rem .75rem; border-radius: 6px; font-size: .75rem; font-weight: 700; cursor: pointer; display:flex; align-items:center; gap:.35rem; }
.ld__card-action--ia:disabled { opacity: .6; cursor: not-allowed; }
.ld__ia-historial { display:flex; flex-direction:column; }
.ld__ia-item { border-top: 1px solid #f3e8ff; }
.ld__ia-item:first-child { border-top: none; }
.ld__ia-item-header { width:100%; display:flex; justify-content:space-between; align-items:center; padding:.5rem 1rem; background:none; border:none; cursor:pointer; text-align:left; }
.ld__ia-item-header:hover { background:#faf5ff; }
.ld__ia-meta { display:flex; align-items:center; gap:.4rem; font-size:.7rem; color:#94a3b8; }
.ld__ia-badge { background:#7c3aed; color:#fff; padding:.1em .45em; border-radius:4px; font-size:.65rem; font-weight:700; text-transform:uppercase; }
.ld__ia-tokens { background:#f3e8ff; color:#7c3aed; padding:.1em .45em; border-radius:4px; font-size:.68rem; font-weight:600; }
.ld__ia-contenido { font-size:.82rem; color:#334155; line-height:1.65; white-space:pre-wrap; max-height:320px; overflow-y:auto; padding:.4rem 1rem .9rem; }
.ld__pvr { padding: .5rem 1rem .8rem; display: flex; flex-direction: column; gap: .5rem; }
.ld__pvr-row { display: flex; align-items: center; gap: .5rem; font-size: .85rem; flex-wrap: wrap; }
.ld__pvr-label { font-size: .75rem; color: #64748b; min-width: 90px; }
.ld__pvr-objetivo { color: #334155; font-weight: 600; }
.ld__pvr-sep { color: #94a3b8; font-size: .7rem; }
.ld__pvr-real { font-weight: 700; color: #1b5e20; }
.ld__pvr-dev { font-size: .75rem; font-weight: 700; padding: .1rem .4rem; border-radius: 4px; }
.ld__pvr-positive { color: #15803d; background: #dcfce7; }
.ld__pvr-negative { color: #dc2626; background: #fee2e2; }
.ld__cpg-badge { display: flex; justify-content: space-between; align-items: center; margin: 0 1rem .9rem; padding: .5rem .75rem; background: linear-gradient(135deg, #f0fdf4, #dcfce7); border-radius: 8px; border: 1px solid #bbf7d0; }
.ld__cpg-label { font-size: .75rem; font-weight: 600; color: #15803d; }
.ld__cpg-value { font-family: var(--font-mono, monospace); font-size: .95rem; font-weight: 800; color: #15803d; }
.ld__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }
.ld__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.ld__btn-primary:hover { background: #104417; }
.ld__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.ld__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #e8f5e9; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-secondary:hover { background: #d4e6d4; }
.ld__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.ld__btn-ghost:hover { background: #f0fdf4; }
.ld__btn-edit { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: #475569; border: 1.5px solid #e2e8f0; padding: .6rem .9rem; border-radius: 8px; font-size: .875rem; cursor: pointer; transition: all .15s; }
.ld__btn-edit:hover { background: #f8fafc; border-color: #94a3b8; }
.ld__btn-trasplante { display: inline-flex; align-items: center; gap: .4rem; background: #fffbeb; color: #92400e; border: 1.5px solid #fde68a; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-trasplante:hover { background: #fef3c7; border-color: #fcd34d; }

/* Selección de plantas en trasplante */
.ld__tp-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .4rem; }
.ld__tp-todas { font-size: .82rem; color: #374151; gap: .4rem; }
.ld__tp-count { font-size: .75rem; font-weight: 700; color: #1b5e20; background: #dcfce7; padding: .1em .5em; border-radius: 99px; }
.ld__tp-list { display: flex; flex-direction: column; gap: 2px; max-height: 220px; overflow-y: auto; border: 1.5px solid #e2e8f0; border-radius: 8px; padding: .25rem; }
.ld__tp-item { display: flex; align-items: center; gap: .5rem; padding: .35rem .5rem; border-radius: 6px; cursor: pointer; font-size: .82rem; transition: background .12s; }
.ld__tp-item:hover { background: #f0fdf4; }
.ld__tp-item--selected { background: #f0fdf4; }
.ld__tp-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.ld__tp-nombre { flex: 1; color: #1e293b; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.ld__tp-estado { font-size: .85rem; flex-shrink: 0; }

/* Trasplante de lote */
.ld__modal--sm { max-width: 440px; }
.ld__tl-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; margin-bottom: .75rem; }
.ld__input-group { display: flex; }
.ld__input-group .ld__input { border-radius: 8px 0 0 8px; }
.ld__input-suffix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .55rem .7rem; font-size: .8rem; font-weight: 600; color: #1b5e20; border-radius: 0 8px 8px 0; white-space: nowrap; }
.ld__tl-current {
  background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: .55rem .8rem; min-height: 38px; display: flex; align-items: center;
}
.ld__tl-current-val  { font-size: 1rem; font-weight: 700; color: #374151; }
.ld__tl-current-none { font-size: .82rem; color: #94a3b8; font-style: italic; }
.ld__label-unit { font-size: .65rem; color: #94a3b8; font-weight: 400; text-transform: none; letter-spacing: 0; margin-left: .2rem; }
.ld__req { color: #dc2626; font-weight: 700; }
.ld__tl-preview {
  display: flex; align-items: center; justify-content: center; gap: .85rem;
  background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 10px;
  padding: .85rem 1rem; margin-bottom: .5rem;
}
.ld__tl-val { font-size: 1.4rem; font-weight: 800; color: #92400e; }
.ld__tl-val--dest { color: #1b5e20; }
.ld__tl-arrow { color: #d97706; font-size: 1.1rem; }
.ld__tl-plants { font-size: .75rem; color: #60725d; font-weight: 600; margin-left: .25rem; }
.ld__btn-danger { display: inline-flex; align-items: center; gap: .4rem; background: #dc2626; color: #fff; border: none; padding: .6rem .9rem; border-radius: 8px; font-size: .875rem; cursor: pointer; transition: background .15s; }
.ld__btn-danger:hover:not(:disabled) { background: #b91c1c; }
.ld__btn-danger:disabled { opacity: .5; cursor: not-allowed; }
.ld__btn-ghost-sm { display: inline-flex; align-items: center; gap: .35rem; background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .5rem .9rem; border-radius: 8px; font-size: .8rem; font-weight: 500; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-ghost-sm:hover { background: #f0fdf4; color: #1b5e20; }
.ld__btn-transicion { display: inline-flex; align-items: center; gap: .4rem; background: var(--c-role-cultivador, #5C7A4A); color: #fff; border: none; padding: .55rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: opacity .15s; white-space: nowrap; }
.ld__btn-transicion:hover { opacity: .88; }
.ld__fase-banner { margin-bottom: 1.25rem; }
.ld__btn-outline { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .5rem 1.1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; text-decoration: none; }
.ld__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }
.ld__btn-sm { display: inline-flex; align-items: center; gap: .3rem; background: #e8f5e9; color: #1b5e20; border: 1px solid #d4e6d4; padding: .35rem .65rem; border-radius: 7px; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.ld__btn-sm:hover { background: #1b5e20; color: #fff; }
.ld__btn-sm--cosecha { background: #dcfce7; border-color: #86efac; color: #15803d; }
.ld__btn-sm--cosecha:hover { background: #15803d; color: #fff; }
.ld__btn-sm--qr { background: #eff6ff; border-color: #bfdbfe; color: #1d4ed8; }
.ld__btn-sm--qr:hover:not(:disabled) { background: #1d4ed8; color: #fff; }
.ld__btn-sm--qr:disabled { opacity: .6; cursor: not-allowed; }
.ld__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.ld__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 600px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.ld__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.ld__modal-title { font-size: 1.05rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.ld__modal-sub { font-size: .78rem; color: #60725d; margin: .2rem 0 0; }
.ld__modal-close { background: #e8f5e9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0; }
.ld__modal-close:hover { background: #c8e6c9; }
.ld__modal-body { padding: 1.25rem 1.5rem; flex: 1; }
.ld__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }
.ld__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .ld__grid { grid-template-columns: 1fr; } }
.ld__field { display: flex; flex-direction: column; gap: .35rem; }
.ld__field--full { grid-column: 1 / -1; }
.ld__label { font-size: .78rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; display: flex; align-items: baseline; gap: 6px; }
.ld__optional { font-size: .68rem; font-weight: 500; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.ld__hint { font-size: .68rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.ld__sala-chip {
  display: flex; align-items: center; gap: 7px;
  padding: .55rem .85rem;
  background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 8px;
  font-size: .82rem; color: #15803d; font-weight: 600;
}
.ld__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .6rem .85rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.ld__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.ld__input--err { border-color: #dc2626; }
.ld__textarea { resize: vertical; min-height: 60px; }
.ld__err-msg { font-size: .75rem; color: #dc2626; }
.ld__checkbox-row { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: #374151; cursor: pointer; user-select: none; }
.ld__checkbox-row input[type="checkbox"] { width: 15px; height: 15px; accent-color: #1b5e20; cursor: pointer; flex-shrink: 0; }
.ld__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .75rem 1rem; border-radius: 8px; font-size: .85rem; margin-bottom: 1rem; }
/* es_seleccion star */
.ld__planta-sel { background: none; border: none; cursor: pointer; padding: .25rem; border-radius: 5px; color: #d4e6d4; font-size: .85rem; flex-shrink: 0; transition: color .15s; }
.ld__planta-sel:hover { color: #d97706; }
.ld__planta-sel--on { color: #d97706; }
.ld__cosecha-grupo { margin-top: .5rem; }
.ld__cosecha-grupo-header { display: flex; align-items: center; justify-content: space-between; padding: .4rem .85rem; background: #f0fdf4; border-top: 1px solid #e8f0e9; border-bottom: 1px solid #e8f0e9; }
.ld__cosecha-grupo-label { font-size: .75rem; font-weight: 700; color: #15803d; }
.ld__cosecha-grupo-count { font-size: .72rem; color: #60725d; }
.ld__planta--cosechada { opacity: .75; }
.ld__planta--cosechada:hover { opacity: 1; }
/* Cerrar curado button */
.ld__btn-curado { display: inline-flex; align-items: center; gap: .35rem; background: #1d4ed8; color: #fff; border: none; padding: .5rem .9rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.ld__btn-curado:hover { background: #1e40af; }
.ld__btn-completar-manicura { display: inline-flex; align-items: center; gap: .35rem; background: #059669; color: #fff; border: none; padding: .5rem .9rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.ld__btn-completar-manicura:hover { background: #047857; }
/* Split validator */
.ld__split-check { font-size: .8rem; padding: .5rem .75rem; border-radius: 8px; margin-top: .25rem; }
.ld__split-check--ok { background: #f0fdf4; color: #16a34a; }
.ld__split-check--err { background: #fef2f2; color: #dc2626; }
/* Timeline */
.ld__timeline { display: flex; flex-direction: column; gap: .5rem; padding: .75rem 1.1rem; }
.ld__tl-group { border: 1px solid #e8f0e9; border-radius: 10px; overflow: hidden; }
.ld__tl-group-title { font-size: .72rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .05em; padding: .5rem .85rem; background: #f4f8f4; border-bottom: 1px solid #e8f0e9; }
.ld__tl-row { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem; padding: .6rem .85rem; border-bottom: 1px solid #f0fdf4; font-size: .8rem; }
.ld__tl-row:last-child { border-bottom: none; }
.ld__tl-fase { display: flex; align-items: center; gap: .35rem; flex-wrap: wrap; }
.ld__tl-pill { font-size: .68rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; white-space: nowrap; }
.ld__tl-pesos { display: flex; flex-wrap: wrap; gap: .75rem; color: #374151; font-size: .78rem; }
.ld__tl-merma { color: #d97706; font-size: .7rem; margin-left: .2rem; }
.ld__tl-meta { font-size: .7rem; color: #94a3b8; margin-left: auto; white-space: nowrap; }
.ld__tl-stock-info { display: flex; align-items: center; flex-wrap: wrap; gap: .5rem; }
.ld__tl-precio { color: #1b5e20; font-weight: 600; }
.ld__tl-sede { font-size: .72rem; color: #64748b; }
</style>
