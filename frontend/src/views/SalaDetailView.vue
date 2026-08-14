<script setup>
import { onMounted, onUnmounted, ref, computed, watch } from "vue"
import { logger } from '../utils/logger.js'
import { useRoute, useRouter } from "vue-router"
import { useSalasStore } from "../stores/salas"
import { useLotesStore } from "../stores/lotes"
import { useAuthStore } from "../stores/auth"
import { useClubStore } from "../stores/club"
import ModalCargarLote        from '../components/salas/ModalCargarLote.vue'
import ModalCrearLoteCosecha  from '../components/salas/ModalCrearLoteCosecha.vue'
import NuevoLoteModal         from '../components/lotes/NuevoLoteModal.vue'
import RegistroSalaModal      from '../components/salas/RegistroSalaModal.vue'
import RegistroEnraizadoModal from '../components/salas/RegistroEnraizadoModal.vue'
import ActionsDropdown        from '../components/ui/ActionsDropdown.vue'
import { listGeneticas, listPlants, updateSala, getSalaAmbiente, deleteSala, getLoteProximoCodigo, createLoteHeredado, cambiarFaseSala, moverLotes, listFotosSala, deleteFotoSala } from '../lib/api.js'
import { useConfirm } from '../composables/useConfirm.js'
import { Gauge } from 'lucide-vue-next'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import { useToast } from '../composables/useToast.js'
import SemaforoAmbiente from '../components/ambiente/SemaforoAmbiente.vue'
import DsSpinner from '../design-system/components/Spinner.vue'

const route  = useRoute()
const router = useRouter()
const salas  = useSalasStore()
const lotes  = useLotesStore()
const auth   = useAuthStore()
const club   = useClubStore()
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
const canCambiarFase = computed(() =>
  ['admin', 'supervisor', 'cultivador'].includes(auth.role) &&
  ['vegetativo', 'floracion'].includes(sala.value?.kind)
)

const lecturaOpen   = ref(false)
// Registro del propagador: aparte del de la sala, porque adentro del domo hay otro ambiente.
const enraizadoOpen = ref(false)
const hayEnraizando = computed(() => items.value.some(l => l.estado === 'enraizado'))
const lotesExpanded = ref(true)
// Fotos del cuarto
const fotosExpanded = ref(true)
const fotosSala     = ref([])
async function cargarFotosSala() {
  try { const { data } = await listFotosSala(salaId); fotosSala.value = data || [] } catch { fotosSala.value = [] }
}
async function borrarFoto(f) {
  try { await deleteFotoSala(salaId, f.id); await cargarFotosSala() } catch {}
}

const ESTADOS_LOTE = ["enraizado","vegetativo","floracion","cosecha","curado","finalizado"]
const DIAS_CICLO   = { semilla:7, esqueje:7, vegetativo:45, floracion:65, cosecha:10, curado:14, finalizado:0 }

// ── Genéticas ──────────────────────────────────────────────
const geneticas = ref([])

// ── Cámara ─────────────────────────────────────────────────
const showCameraForm  = ref(false)
const savingCamera    = ref(false)
const cameraError     = ref(false)
const snapshotKey     = ref(0)
const snapshotTs      = ref('')
const cameraInputUrl  = ref('')
const cameraTestSrc   = ref('')
const cameraTestOk    = ref(false)
const cameraTestError = ref(false)

const snapshotSrc = computed(() => {
  const url = sala.value?.camera_stream_url || sala.value?.camera_snapshot_url
  if (!url) return ''
  return url + (url.includes('?') ? '&' : '?') + '_t=' + snapshotKey.value
})

function refreshSnapshot() {
  cameraError.value = false
  snapshotKey.value = Date.now()
  snapshotTs.value  = new Date().toLocaleTimeString('es-AR')
}

function normalizarUrl(input) {
  const s = input.trim()
  if (!s) return ''
  return /^https?:\/\//i.test(s) ? s : 'http://' + s
}

function abrirFormCamera() {
  cameraInputUrl.value  = sala.value?.camera_stream_url || sala.value?.camera_snapshot_url || ''
  cameraTestSrc.value   = ''
  cameraTestOk.value    = false
  cameraTestError.value = false
  showCameraForm.value  = true
}

function probarCamara() {
  const url = normalizarUrl(cameraInputUrl.value)
  if (!url) return
  cameraTestOk.value    = false
  cameraTestError.value = false
  cameraTestSrc.value   = url + (url.includes('?') ? '&' : '?') + '_t=' + Date.now()
}

async function saveCamera() {
  const url = normalizarUrl(cameraInputUrl.value)
  savingCamera.value = true
  try {
    await updateSala(salaId, { camera_stream_url: url, camera_snapshot_url: '' })
    await salas.fetchOne(salaId)
    showCameraForm.value = false
    toast.success('Cámara guardada')
    refreshSnapshot()
  } catch { toast.error('Error al guardar la cámara') }
  finally { savingCamera.value = false }
}

async function eliminarCamara() {
  savingCamera.value = true
  try {
    await updateSala(salaId, { camera_stream_url: '', camera_snapshot_url: '' })
    await salas.fetchOne(salaId)
    cameraError.value = false
    toast.success('Cámara eliminada')
  } catch { toast.error('Error') }
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
  { value: 'cosecha',    label: 'Cosecha'    },
]

function openEditSala() {
  editSalaForm.value = {
    nombre:     sala.value.nombre     || '',
    kind:       sala.value.kind       || '',
    state:      sala.value.state      || 'activa',
    pots_count: sala.value.pots_count ?? '',
    notes:      sala.value.notes      || '',
  }
  editSalaError.value = null
  showEditSala.value  = true
}

async function saveEditSala(confirmado = false) {
  if (!editSalaForm.value.nombre?.trim()) { editSalaError.value = 'El nombre es obligatorio'; return }
  savingEditSala.value = true
  editSalaError.value  = null
  try {
    const payload = { ...editSalaForm.value }
    if (confirmado) payload.confirmar_cambio_fase = true
    await updateSala(salaId, payload)
    await salas.fetchSala(salaId)
    await lotes.fetchBySala(salaId)
    showEditSala.value = false
    toast.success('Sala actualizada')
  } catch (e) {
    // Cambiar el kind de la sala ARRASTRA a los lotes de adentro. El backend frena y devuelve
    // cuáles son; recién con el sí explícito se guarda. Mismo criterio que mover lotes de sala.
    const data = e?.response?.data
    if (data?.requiere_confirmacion) {
      savingEditSala.value = false
      if (await confirmarCambioDeFaseDeSala(data)) return saveEditSala(true)
      return
    }
    editSalaError.value = data?.error || 'Error al guardar'
  } finally {
    savingEditSala.value = false
  }
}

async function confirmarCambioDeFaseDeSala(data) {
  const lotes = data.lotes_afectados || []
  const aFloracion = lotes[0]?.estado_nuevo === 'floracion'

  const lineas = [
    `Cambiar la fase de la sala arrastra a ${lotes.length} lote(s) que están adentro:`,
    '',
    ...lotes.map(l => {
      const dias = l.dias_en_fase != null ? ` · lleva ${l.dias_en_fase} día${l.dias_en_fase === 1 ? '' : 's'}` : ''
      return `   · ${l.codigo}: ${estadoMeta(l.estado_actual).label} → ${estadoMeta(l.estado_nuevo).label}${dias} · ${l.plantas} plantas`
    }),
    '',
    aFloracion
      ? 'Pasar a floración no se deshace: la planta ya recibió 12/12.'
      : 'Volver a vegetativo REVEGETA las plantas que están florando y reinicia el contador de días de fase.',
    '',
    'Si lo que querés es mover estos lotes y no revegetarlos, cancelá y usá "Mover lotes".',
  ]

  return confirm({
    title: 'Esto cambia de fase a los lotes de la sala',
    message: lineas.join('\n'),
    variant: 'danger',
    confirmText: aFloracion ? 'Pasar a floración' : 'Revegetar igual',
  })
}

const salaAcciones = computed(() => {
  const items = []
  if (canEdit.value || isCultivador.value) {
    items.push({ emoji: '🌿', label: 'Registrar sala', onClick: () => { lecturaOpen.value = true } })
    // Los lotes que enraízan viven en un propagador con otro clima —la sala marca 60% de humedad y
    // adentro hay 90%—, así que su registro va aparte y solo aparece si hay alguno.
    if (hayEnraizando.value) {
      items.push({ emoji: '🌱', label: 'Registrar enraizado', onClick: () => { enraizadoOpen.value = true } })
    }
  }
  if (puedeCargarLote.value) {
    const lbl = 'Cargar lote de cosecha'
    items.push({ emoji: '📦', label: lbl, onClick: () => { showCargarLote.value = true } })
  }
  if (canCambiarFase.value) {
    const hacia = sala.value?.kind === 'vegetativo' ? 'Floración' : 'Vegetativo'
    items.push({ emoji: '🔄', label: `Pasar sala a ${hacia}`, onClick: () => { showCambiarFaseModal.value = true; cambiarFaseError.value = null } })
  }
  if (canEdit.value) {
    items.push({ emoji: '✏️', label: 'Editar sala', onClick: openEditSala })
    items.push({ divider: true })
    items.push({ emoji: '🗑️', label: 'Eliminar sala', danger: true, onClick: eliminarSala, disabled: deleting.value })
  }
  return items
})

function salaEscapeHandler(e) {
  if (e.key !== 'Escape') return
  if (showEditSala.value)    { showEditSala.value = false; return }
  if (showCambiarFaseModal.value)   { showCambiarFaseModal.value = false; return }
  if (showCrearLoteCosecha.value) { showCrearLoteCosecha.value = false; return }
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
    const res = await listGeneticas({ solo_club: 'true' })
    geneticas.value = res.data || []
  } catch { /* genéticas no críticas */ }

  // Todas las salas de la organización: son los destinos posibles para mover lotes (incluso de otra sede).
  if (!salas.items.length) { try { await salas.fetch() } catch { /* destino opcional */ } }

  if (canSeeAmbiente.value) cargarAmbienteMini()
})

onUnmounted(() => {
  document.removeEventListener('keydown', salaEscapeHandler, true)
})

const sala  = computed(() => salas.currentSala)
const ESTADOS_ACTIVOS_CULTIVADOR = ['enraizado', 'vegetativo', 'floracion']
const items = computed(() => {
  const todos = lotes.bySala(salaId)
  return isCultivador.value
    ? todos.filter(l => ESTADOS_ACTIVOS_CULTIVADOR.includes(l.estado))
    : todos
})

watch(() => sala.value?.camera_stream_url, (url) => {
  if (url) refreshSnapshot()
}, { immediate: true })

// ── Cambiar estado de sala ──────────────────────────────────
const cambiandoEstado  = ref(false)
const showEstadoMenu   = ref(false)

function toggleEstadoMenu() { showEstadoMenu.value = !showEstadoMenu.value }
function cerrarEstadoMenu()  { showEstadoMenu.value = false }
const ESTADOS_SALA = [
  { value: 'activa',        label: 'Activa',          style: 'background:#dcfce7;color:#15803d' },
  { value: 'mantenimiento', label: 'En mantenimiento', style: 'background:#fef3c7;color:#b45309' },
  { value: 'cerrada',       label: 'Cerrada',          style: 'background:#f1f5f9;color:#64748b' },
]
async function cambiarEstado(nuevoEstado) {
  cerrarEstadoMenu()
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
    cosechados:   ls.filter(l => ["cosecha","en_manicura","curado","finalizado"].includes(l.estado)).length,
  }
})

// ── Mover lotes a otra sala ───────────────────────────────────────────────────
// Hasta ahora la única forma de que un lote cambiara de sala era avanzando de fase, así que
// rebalancear salas o corregir un alta obligaba a fingir un avance y ensuciaba la historia.
//
// La regla que hay que dejar clarísima ANTES de confirmar: **el lote toma la fase de la sala
// destino**. Una sala en floración da 12/12, así que lo que entre ahí pasa a florecer. Es
// irreversible en el sentido de que no se "des-florece" una planta, por eso el diálogo enumera
// lote por lote qué va a cambiar, en vez de un "¿estás seguro?" genérico.
const selMover  = ref(new Set())
const moviendo  = ref(false)
const salaDestinoId = ref(null)
const showMover = ref(false)

const puedeMover = computed(() => canEdit.value || isCultivador.value)
const esMovible  = (l) => ESTADOS_ACTIVOS_CULTIVADOR.includes(l.estado)
function alternarMover(id) {
  const s = new Set(selMover.value)
  s.has(id) ? s.delete(id) : s.add(id)
  selMover.value = s
}
const lotesAMover = computed(() => items.value.filter(l => selMover.value.has(l.id)))

const salasDestino = computed(() =>
  (salas.items || []).filter(s => s.id !== sala.value?.id && s.state === 'activa'))
const salaDestino  = computed(() => salasDestino.value.find(s => s.id === Number(salaDestinoId.value)) || null)

// Qué va a pasar con cada lote si se confirma. Es el contenido de la alerta.
const efectosMover = computed(() => {
  const d = salaDestino.value
  if (!d) return { cambian: [], cambiaSede: false }
  const faseDestino = ['vegetativo', 'floracion'].includes(d.kind) ? d.kind : null
  return {
    faseDestino,
    // El enraizado no lo cambia ninguna sala: comparte fotoperíodo con vegetativo y lo que lo
    // tiene ahí es no tener raíz, no el cuarto. Sale cuando prende.
    cambian: faseDestino ? lotesAMover.value.filter(l => l.estado !== faseDestino && l.estado !== 'enraizado') : [],
    cambiaSede: !!(d.sede?.id && sala.value?.sede?.id && d.sede.id !== sala.value.sede.id),
  }
})

async function confirmarMover() {
  const d = salaDestino.value
  if (!d || !lotesAMover.value.length) return

  const ef = efectosMover.value
  const lineas = [`Vas a mover ${lotesAMover.value.length} lote(s) a "${d.nombre}".`]
  if (ef.cambiaSede) lineas.push(`⚠️ Es de OTRA SEDE: los lotes pasan a ${d.sede?.nombre || 'esa sede'} y sus costos se imputan ahí.`)
  if (ef.cambian.length) {
    lineas.push(`⚠️ La sala está en ${ef.faseDestino === 'floracion' ? 'FLORACIÓN' : 'VEGETATIVO'}, así que estos lotes cambian de fase:`)
    lineas.push(...ef.cambian.map(l => `   · ${l.codigo}: ${estadoMeta(l.estado).label} → ${estadoMeta(ef.faseDestino).label}`))
    if (ef.faseDestino === 'floracion') lineas.push('Pasar a floración no se deshace: la planta ya recibió 12/12.')
  }

  if (!(await confirm({
    title: 'Mover lotes de sala',
    message: lineas.join('\n'),
    variant: ef.cambian.length ? 'danger' : 'warning',   // el diálogo no conoce 'primary'
    confirmText: 'Mover',
  }))) return

  moviendo.value = true
  try {
    const { data } = await moverLotes([...selMover.value], d.id)
    const extra = data.cambios_de_fase?.length ? ` · ${data.cambios_de_fase.length} cambiaron de fase` : ''
    toast.success(`${data.movidos} lote(s) movidos a ${d.nombre}${extra}`)
    selMover.value = new Set(); showMover.value = false; salaDestinoId.value = null
    await Promise.all([salas.fetchSala(salaId), lotes.fetchBySala(salaId)])
    cargarFotosSala()
  } catch (e) {
    toast.error(e?.response?.data?.error || e?.response?.data?.errors?.join(', ') || 'No se pudieron mover')
  } finally { moviendo.value = false }
}

// ── Ambiente actual de la sala ────────────────────────────────────────────────
// Sin sensores conectados, "actual" es el último registro manual cargado en cualquier lote de la
// sala. Por eso el dato viaja siempre con su antigüedad y con el lote del que salió.
//
// El VPD lo calcula el backend (con temperatura de hoja estimada). Acá solo lo interpretamos: es la
// métrica que de verdad dice si el cuarto está bien — 25° con 40% y 25° con 70% son dos mundos, y
// mirar temperatura y humedad por separado no los distingue.
function nivelVpd(v) {
  if (v < 0.4)  return { cls: 'bajo',  ayuda: 'Muy bajo: el aire está saturado, la planta casi no transpira. Riesgo de hongos.' }
  if (v < 0.8)  return { cls: 'ok',    ayuda: 'Bajo: propio de esquejes y vegetativo temprano.' }
  if (v <= 1.2) return { cls: 'ok',    ayuda: 'En rango: transpiración cómoda para vegetativo y floración.' }
  if (v <= 1.6) return { cls: 'alto',  ayuda: 'Alto: propio de floración tardía; vigilá que no se estrese.' }
  return { cls: 'malo', ayuda: 'Muy alto: el aire tira demasiado, la planta cierra estomas y frena.' }
}
function haceCuanto(iso) {
  const t = new Date(iso)
  if (isNaN(t)) return ''
  const min = Math.round((Date.now() - t.getTime()) / 60000)
  if (min < 60)   return min <= 1 ? 'recién' : `hace ${min} min`
  const h = Math.round(min / 60)
  if (h < 24)     return `hace ${h} h`
  const d = Math.round(h / 24)
  return d === 1 ? 'ayer' : `hace ${d} días`
}
function lectura(a) {
  if (!a || (a.temperatura == null && a.humedad == null)) return null
  const horas = (Date.now() - new Date(a.registrado_en).getTime()) / 3600000
  return {
    ...a,
    hace:  haceCuanto(a.registrado_en),
    viejo: horas > 24,                       // más de un día: se marca, no es "el ambiente de ahora"
    vpdNivel: a.vpd != null ? nivelVpd(a.vpd) : null,
  }
}
const amb = computed(() => lectura(sala.value?.ambiente_actual))

// El clima del PROPAGADOR, aparte del cuarto: adentro del domo la sala marca 60% y hay 90%. El
// backend ya no los mezcla (antes el KPI de la sala mostraba este dato como si fuera el del
// cuarto). Aparece solo si hay algo enraizando.
//
// A propósito SIN el semáforo de VPD: la escala de `nivelVpd` es la del cuarto, y un esqueje sin
// raíz quiere justo lo que ahí figura como "muy bajo" — pintarlo de rojo diría lo contrario de
// lo que hay que hacer.
const ambIncubadora = computed(() => lectura(sala.value?.ambiente_incubadora))

const ESTADO_META = {
  semilla:    { label:"Semilla",  color:"#64748b", emoji:"🌱" },
  esqueje:    { label:"Enraizado",color:"#0891b2", emoji:"🌱" },
  vegetativo: { label:"Vegetativo",      color:"#16a34a", emoji:"🌱" },
  floracion:  { label:"Floración",       color:"#d97706", emoji:"🌸" },
  cosecha:     { label:"Cosecha",     color:"#92400e", emoji:"✂️" },
  en_manicura: { label:"En manicura", color:"#7c3aed", emoji:"✂️" },
  curado:      { label:"Curado",      color:"#2563eb", emoji:"🍂" },
  finalizado:  { label:"Finalizado",  color:"#1b5e20", emoji:"✅" },
}
function estadoMeta(e) { return ESTADO_META[e] || { label:e, color:"#64748b", emoji:"📦" } }
function growLabel(g)  { return { sustrato:"Sustrato", hidroponia:"Hidroponia" }[g] || g || "—" }
function kindLabel(k)  { return { vegetativo:"Vegetativo", floracion:"Floración", mixta:"Mixta", madre:"Madres", clon:"Clones", manicura:"Manicura" }[k] || k || "—" }

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
  if (["cosecha","en_manicura","curado","finalizado"].includes(lote.estado)) return 100
  return Math.min(Math.round((dias / total) * 100), 99)
}

// Buscar por código y filtrar por estado. Con una sala de 30 lotes, tildar de a uno para mover
// media sala no es una opción.
const sdQuery  = ref('')
const sdEstado = ref('')
const itemsFiltrados = computed(() => {
  const q = sdQuery.value.trim().toLowerCase()
  return items.value.filter(l =>
    (!q || (l.codigo || '').toLowerCase().includes(q) ||
           (l.genetica?.nombre || l.strain || '').toLowerCase().includes(q)) &&
    (!sdEstado.value || l.estado === sdEstado.value))
})
const itemsSorted = computed(() => {
  const order = ["vegetativo","floracion","enraizado","cosecha","curado","finalizado"]
  return [...itemsFiltrados.value].sort((a,b) => order.indexOf(a.estado) - order.indexOf(b.estado))
})

// "Seleccionar todo" toma lo FILTRADO, no la página: filtrás enraizado y entran todos, aunque la
// lista muestre 10. Misma regla que la selección de etiquetas.
const movibles = computed(() => itemsSorted.value.filter(esMovible))
const todosElegidos = computed(() =>
  movibles.value.length > 0 && movibles.value.every(l => selMover.value.has(l.id)))
function alternarTodos() {
  const s = new Set(selMover.value)
  todosElegidos.value ? movibles.value.forEach(l => s.delete(l.id))
                      : movibles.value.forEach(l => s.add(l.id))
  selMover.value = s
}
// Fases de LOTE para el filtro. Ojo: ESTADOS_SALA (más arriba) es otra cosa — el estado de la sala
// misma (activa/mantenimiento/cerrada).
const FASES_FILTRO = [
  { v: 'enraizado',  l: 'Enraizado' },
  { v: 'vegetativo', l: 'Vegetativo' },
  { v: 'floracion',  l: 'Floración' },
]

const SD_PER_PAGE    = 10
const sdPage         = ref(1)
const itemsPaginados = computed(() => itemsSorted.value.slice((sdPage.value - 1) * SD_PER_PAGE, sdPage.value * SD_PER_PAGE))
const sdTotalPages   = computed(() => Math.max(1, Math.ceil(itemsSorted.value.length / SD_PER_PAGE)))
watch(itemsSorted, () => { sdPage.value = 1 })

const breadcrumbs = computed(() => {
  if (isCultivador.value) return []
  const crumbs = [{ label:"Sedes", to:{ name:"sedes" } }]
  if (sala.value?.sede) crumbs.push({ label:sala.value.sede.nombre, to:{ name:"sede-detail", params:{ id:sala.value.sede.id } } })
  return crumbs
})

// ── Cargar lote (manicura) ─────────────────────────────────
const showCargarLote = ref(false)

// ── Cambiar fase (vege ↔ flora) ────────────────────────────
const showCambiarFaseModal = ref(false)
const cambiarFaseLoading   = ref(false)
const cambiarFaseError     = ref(null)

const faseSiguiente = computed(() =>
  sala.value?.kind === 'vegetativo' ? 'floracion' : 'vegetativo'
)
const faseLabel = (f) => ({ vegetativo: 'Vegetativo', floracion: 'Floración' }[f] || f)

const lotesAfectados = computed(() =>
  lotes.bySala(salaId).filter(l => l.estado === sala.value?.kind)
)
const plantasAfectadas = computed(() =>
  lotesAfectados.value.reduce((sum, l) => sum + (l.plants_count || 0), 0)
)

async function ejecutarCambioFase() {
  cambiarFaseLoading.value = true
  cambiarFaseError.value   = null
  try {
    const { data } = await cambiarFaseSala(salaId)
    await salas.fetchSala(salaId)
    await lotes.fetchBySala(salaId)
    showCambiarFaseModal.value = false
    toast.success(`Sala cambiada a ${faseLabel(data.nueva_fase)} — ${data.lotes_afectados} lotes, ${data.plantas_afectadas} plantas`)
  } catch (e) {
    cambiarFaseError.value = e?.response?.data?.error || e?.response?.data?.errors?.[0] || 'Error al cambiar la fase'
  } finally {
    cambiarFaseLoading.value = false
  }
}

const esSalaManicura = computed(() => sala.value?.kind === 'manicura')
const esSalaCosecha  = computed(() => sala.value?.kind === 'cosecha')
const puedeCargarLote = computed(() =>
  esSalaManicura.value && (canEdit.value || isAgricultor.value || isManicurador.value)
)

async function onLoteCargado() {
  await lotes.fetchBySala(salaId)
  await salas.fetchSala(salaId)
}

// ── Crear lote ─────────────────────────────────────────────
const KIND_TO_ESTADO = { floracion:"floracion" }
const KINDS_CON_ORIGEN = ['vegetativo', 'madre', 'clon', 'mixta']

const ESTADOS_HEREDADO = [
  { value: 'enraizado', label: 'Enraizado' },
  { value: 'vegetativo', label: 'Vegetativo' },
  { value: 'floracion',  label: 'Floración' },
  { value: 'cosecha',    label: 'Cosecha' },
]

const estadosHeredadoPermitidos = computed(() => {
  const kind = sala.value?.kind
  if (kind === 'floracion') return ESTADOS_HEREDADO.filter(e => e.value === 'floracion')
  if (kind === 'cosecha') return ESTADOS_HEREDADO.filter(e => e.value === 'cosecha')
  return ESTADOS_HEREDADO.filter(e => ['enraizado', 'vegetativo'].includes(e.value))
})

const showCreate            = ref(false)
const showCrearLoteCosecha  = ref(false)
const loteForm       = ref(emptyLoteForm())
const loteErrors     = ref({})
const loteApiError   = ref(null)
const showUpgrade    = ref(false)
const creandoLote    = ref(false)
const tipoCreacion   = ref('nuevo')
const proximoCodigo  = ref('')
const loadingCodigo  = ref(false)
const heredadoEstado = ref('germinacion')
const heredadoDias   = ref({ semilla_esqueje: 0, vegetativo: 0, floracion: 0, cosecha: 0 })
const plantasMadre    = ref([])
const loadingMadres   = ref(false)
const madreQuery      = ref('')
const madreFocused    = ref(false)

const plantaMadreSeleccionada = computed(() =>
  plantasMadre.value.find(p => p.id === loteForm.value.planta_madre_id)
)
const madreDropdown = computed(() => {
  const q = madreQuery.value.trim().toLowerCase()
  if (!q) return []
  return plantasMadre.value.filter(p =>
    p.nombre?.toLowerCase().includes(q) ||
    p.lote?.codigo?.toLowerCase().includes(q) ||
    p.lote?.sala?.nombre?.toLowerCase().includes(q) ||
    p.genetica?.nombre?.toLowerCase().includes(q)
  ).slice(0, 40)
})
const madreAgrupado = computed(() => {
  const salas = {}
  for (const p of plantasMadre.value) {
    const salaId     = p.lote?.sala?.id    ?? 0
    const salaNombre = p.lote?.sala?.nombre ?? 'Sin sala'
    const loteId     = p.lote?.id          ?? 0
    const loteCodigo = p.lote?.codigo      ?? '–'
    const genetica   = p.genetica?.nombre  ?? ''
    if (!salas[salaId]) salas[salaId] = { sala_id: salaId, sala_nombre: salaNombre, lotes: {} }
    if (!salas[salaId].lotes[loteId])
      salas[salaId].lotes[loteId] = { lote_id: loteId, lote_codigo: loteCodigo, genetica, plants: [] }
    salas[salaId].lotes[loteId].plants.push(p)
  }
  return Object.values(salas).map(s => ({ ...s, lotes: Object.values(s.lotes) }))
})

const heredadoStartDatePreview = computed(() => {
  const e = heredadoEstado.value
  const d = heredadoDias.value
  let total = d.semilla_esqueje
  if (['vegetativo','floracion','cosecha'].includes(e)) total += d.vegetativo
  if (['floracion','cosecha'].includes(e))              total += d.floracion
  if (e === 'cosecha')                                  total += d.cosecha
  if (total <= 0) return null
  const date = new Date()
  date.setDate(date.getDate() - total)
  return date.toISOString().slice(0, 10)
})

function emptyLoteForm() {
  const kind = sala.value?.kind
  const conOrigen = !kind || KINDS_CON_ORIGEN.includes(kind)
  const estadoInicial = conOrigen ? 'germinacion' : (KIND_TO_ESTADO[kind] || 'vegetativo')
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
  // Estado inicial según origen: semilla → germinación, esqueje → esqueje.
  loteForm.value.estado = valor === 'esqueje' ? 'esqueje' : 'germinacion'
  loteForm.value.planta_madre_id = null
  madreQuery.value = ''
  if (valor === 'esqueje') {
    loadingMadres.value = true
    try {
      const { data } = await listPlants({ lote_estado: 'vegetativo' })
      plantasMadre.value = data || []
    } catch { plantasMadre.value = [] }
    finally { loadingMadres.value = false }
  }
}

let _madreFocusTimer = null
function onMadreBlur() {
  _madreFocusTimer = setTimeout(() => { madreFocused.value = false }, 180)
}
function selectMadre(plant) {
  clearTimeout(_madreFocusTimer)
  loteForm.value.planta_madre_id = plant.id
  madreQuery.value = ''
  madreFocused.value = false
  if (plant.genetica?.id) {
    loteForm.value.genetica_id = plant.genetica.id
  }
}
function clearMadre() {
  loteForm.value.planta_madre_id = null
  madreQuery.value = ''
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
  if (tipoCreacion.value === 'existente') {
    const estadoReal = (heredadoEstado.value === 'germinacion' && loteForm.value.origen === 'esqueje')
      ? 'esqueje' : heredadoEstado.value
    loteForm.value.estado = estadoReal
  }
  const e = validateLote(loteForm.value)
  loteErrors.value   = e
  loteApiError.value = null
  if (Object.keys(e).length) return

  creandoLote.value = true
  try {
    const payload = { ...loteForm.value }
    if (!payload.genetica_id)     delete payload.genetica_id
    if (!payload.light_type)      delete payload.light_type
    if (!payload.planta_madre_id) delete payload.planta_madre_id

    if (tipoCreacion.value === 'existente') {
      delete payload.start_date
      if (!payload.origen) payload.origen = 'semilla'
      await createLoteHeredado(salaId, payload, {
        dias_semilla_esqueje: heredadoDias.value.semilla_esqueje || 0,
        dias_vegetativo:      heredadoDias.value.vegetativo      || 0,
        dias_floracion:       heredadoDias.value.floracion        || 0,
        dias_cosecha:         heredadoDias.value.cosecha          || 0,
      })
      await lotes.fetchBySala(salaId)
    } else {
      if (!payload.origen) delete payload.origen
      await lotes.createInSala(salaId, payload)
    }

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
  } finally {
    creandoLote.value = false
  }
}
function openCreate() {
  // Sala de cosecha (legacy) usa su propio modal; el resto, el NuevoLoteModal compartido
  if (esSalaCosecha.value) { showCrearLoteCosecha.value = true; return }
  showCreate.value = true
}

// Lote creado desde el NuevoLoteModal compartido
async function onNuevoLoteCreado() {
  await lotes.fetchBySala(salaId)
  await salas.fetchSala(salaId)
  lotesExpanded.value = true
}

async function onLoteCosechaCreado() {
  await lotes.fetchBySala(salaId)
  await salas.fetchSala(salaId)
  lotesExpanded.value = true
}
function closeCreate() {
  showCreate.value     = false
  loteForm.value       = emptyLoteForm()
  loteErrors.value     = {}
  loteApiError.value   = null
  tipoCreacion.value   = 'nuevo'
  proximoCodigo.value  = ''
  heredadoDias.value   = { semilla_esqueje: 0, vegetativo: 0, floracion: 0, cosecha: 0 }
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

// ── Tabs (Layout / Historial) ──────────────────────────────
const tabActiva = ref('lotes')

// Slots ocupados de la sala = solo lotes realmente en cultivo. Los estados de
const historialLotes = computed(() => sala.value?.lotes_historial || [])
const historialKpis  = computed(() => sala.value?.historial_kpis  || null)
</script>

<template>
  <div class="sd">

    <Breadcrumb
      v-if="breadcrumbs.length > 0"
      :items="[...breadcrumbs, { label: sala?.nombre || '…' }]"
    />

    <div v-if="loading" class="sd__loading"><DsSpinner /></div>
    <div v-else-if="error" class="sd__error">{{ error }}</div>
    <div v-else-if="!sala" class="sd__error">Sala no encontrada.</div>

    <template v-else>

      <!-- Header -->
      <div class="sd__hero">
        <div class="sd__hero-left">
          <div class="sd__hero-title-row">
            <h1 class="sd__title">{{ sala.nombre }}</h1>
            <!-- Estado con dropdown para cambiar -->
            <div class="sd__estado-wrap" v-if="canEdit" v-click-outside="cerrarEstadoMenu">
              <div class="sd__estado-dropdown">
                <span class="sd__estado-pill" :style="{ background: salaEstadoStyle(sala.state).bg, color: salaEstadoStyle(sala.state).color }"
                      @click.stop="toggleEstadoMenu">
                  {{ sala.state }} <i class="bi" :class="showEstadoMenu ? 'bi-chevron-up' : 'bi-chevron-down'" style="font-size:.6rem"></i>
                </span>
                <div v-if="showEstadoMenu" class="sd__estado-menu">
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
          <button v-if="(canEdit || isCultivador) && !esSalaManicura" class="sd__btn-primary" @click="openCreate">
            <i class="bi bi-plus-lg"></i>Crear lote
          </button>
          <ActionsDropdown v-if="(canEdit || isCultivador) && salaAcciones.length" :items="salaAcciones" />
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

        <!-- Ambiente. Mientras no haya sensores es el último registro manual, así que la
             ANTIGÜEDAD va siempre: un dato de hace una semana mostrado como si fuera de ahora es
             peor que no tener dato. -->
        <div v-if="amb" class="sd__kpi sd__kpi--amb" :class="{ 'sd__kpi--viejo': amb.viejo }">
          <div class="sd__kpi-icon">🌡️</div>
          <div class="sd__kpi-body">
            <div class="sd__kpi-value">
              <span v-if="amb.temperatura != null">{{ amb.temperatura }}°</span>
              <span v-if="amb.humedad != null" class="sd__amb-hum">{{ amb.humedad }}%</span>
            </div>
            <div class="sd__kpi-label">
              Ambiente
              <span v-if="amb.vpd != null" class="sd__amb-vpd" :class="`sd__amb-vpd--${amb.vpdNivel.cls}`"
                    :title="amb.vpdNivel.ayuda">VPD {{ amb.vpd }} kPa</span>
            </div>
            <div class="sd__kpi-sub">{{ amb.hace }}<span v-if="amb.lote_codigo"> · {{ amb.lote_codigo }}</span></div>
          </div>
        </div>

        <!-- Incubadora / bandeja: su propio KPI. Es otro aire, no una segunda medición del mismo. -->
        <div v-if="ambIncubadora" class="sd__kpi sd__kpi--amb sd__kpi--incubadora"
             :class="{ 'sd__kpi--viejo': ambIncubadora.viejo }">
          <div class="sd__kpi-icon">🫙</div>
          <div class="sd__kpi-body">
            <div class="sd__kpi-value">
              <span v-if="ambIncubadora.temperatura != null">{{ ambIncubadora.temperatura }}°</span>
              <span v-if="ambIncubadora.humedad != null" class="sd__amb-hum">{{ ambIncubadora.humedad }}%</span>
            </div>
            <div class="sd__kpi-label">Incubadora</div>
            <div class="sd__kpi-sub">
              {{ ambIncubadora.hace }}<span v-if="ambIncubadora.lote_codigo"> · {{ ambIncubadora.lote_codigo }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Tabs -->
      <div class="sd__tabs">
        <button class="sd__tab" :class="{ 'sd__tab--active': tabActiva === 'lotes' }" @click="tabActiva = 'lotes'">🌿 Lotes</button>
        <button class="sd__tab" :class="{ 'sd__tab--active': tabActiva === 'historial' }" @click="tabActiva = 'historial'">📋 Historial</button>
      </div>

      <div class="sd__layout">
        <div class="sd__main">

          <!-- Lotes -->
          <div v-show="tabActiva === 'lotes'" class="sd__section">
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
                  <button v-if="(canEdit || isCultivador) && !esSalaManicura" class="sd__btn-outline" @click="openCreate">Crear primer lote</button>
                  <button v-else-if="puedeCargarLote" class="sd__btn-outline" style="color:#b45309;border-color:#fde68a" @click="showCargarLote=true">
                    <i class="bi bi-box-arrow-in-down"></i>
                    Cargar lote de cosecha
                  </button>
                </template>
              </EmptyState>
              <!-- Hay lotes: buscador (si vale la pena) + lista. Van juntos bajo el mismo v-else:
                   con el buscador como un v-if suelto, el v-else de la lista se enganchaba a ÉL y
                   la lista desaparecía apenas había más de 3 lotes. -->
              <template v-else>
              <!-- Buscar / filtrar / seleccionar todo -->
              <div v-if="items.length > 3 || sdQuery || sdEstado" class="sd__lotes-tools">
                <label v-if="puedeMover && movibles.length" class="sd__selall">
                  <input type="checkbox" :checked="todosElegidos" @change="alternarTodos" />
                  Todos<span v-if="sdEstado || sdQuery"> los filtrados</span> ({{ movibles.length }})
                </label>
                <input v-model="sdQuery" class="sd__lotes-search" placeholder="Buscar por código o genética…" />
                <select v-model="sdEstado" class="sd__lotes-filter">
                  <option value="">Todos los estados</option>
                  <option v-for="e in FASES_FILTRO" :key="e.v" :value="e.v">{{ e.l }}</option>
                </select>
              </div>

              <!-- El filtro no encontró nada: hay lotes, pero ninguno matchea. Sin esto la lista
                   quedaba en blanco y parecía que la sala se había vaciado. -->
              <div v-if="!itemsSorted.length" class="sd__placeholder">
                Ningún lote coincide con la búsqueda.
              </div>

              <div v-else class="sd__lotes">
                <div v-for="l in itemsPaginados" :key="l.id" class="sd__lote-wrap">
                <label v-if="puedeMover && esMovible(l)" class="sd__lote-cb" @click.stop>
                  <input type="checkbox" :checked="selMover.has(l.id)" @change="alternarMover(l.id)" />
                </label>
                <RouterLink :to="{ name:'lote-detail', params:{ id:l.id } }" class="sd__lote">
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
                      <span v-if="l.tamanio_maceta">🪣 {{ l.tamanio_maceta }}L</span>
                      <span v-if="l.estado === 'floracion' && l.plantas_cosechadas_count > 0"
                            class="sd__cosecha-parcial">
                        🌸 {{ (l.plants_count || 0) - l.plantas_cosechadas_count }} en floración · ✅ {{ l.plantas_cosechadas_count }} cosechadas
                      </span>
                      <span v-if="l.genetica?.nombre" class="sd__lote-gen">🌿 {{ l.genetica.nombre }}</span>
                      <span v-else-if="l.strain" class="sd__lote-strain">🌿 {{ l.strain }}</span>
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
                <!-- Barra de mover: aparece solo con algo seleccionado -->
                <Teleport to="body">
                  <div v-if="selMover.size" class="sd__movbar">
                    <span class="sd__movbar-txt">{{ selMover.size }} lote{{ selMover.size === 1 ? '' : 's' }}</span>
                    <select v-model="salaDestinoId" class="sd__movbar-sel">
                      <option :value="null">Mover a…</option>
                      <option v-for="s in salasDestino" :key="s.id" :value="s.id">
                        {{ s.nombre }}<template v-if="s.kind"> ({{ kindLabel(s.kind) }})</template><template v-if="s.sede?.nombre"> · {{ s.sede.nombre }}</template>
                      </option>
                    </select>
                    <button class="sd__movbar-ghost" @click="selMover = new Set()">Cancelar</button>
                    <button class="sd__movbar-btn" :disabled="!salaDestino || moviendo" @click="confirmarMover">
                      {{ moviendo ? 'Moviendo…' : 'Mover' }}
                    </button>
                  </div>
                </Teleport>

                <div v-if="sdTotalPages > 1" class="sd__lotes-pager">
                  <button class="sd__pager-btn" :disabled="sdPage <= 1" @click="sdPage--">«</button>
                  <span class="sd__pager-info">{{ sdPage }} / {{ sdTotalPages }}</span>
                  <button class="sd__pager-btn" :disabled="sdPage >= sdTotalPages" @click="sdPage++">»</button>
                </div>
              </div>
              </template>
            </div>
          </div>

          <!-- Fotos del cuarto. Las sube el cultivador desde la PWA; antes se guardaban en la nada
               (el handler era un placeholder vacío) y acá no había dónde verlas. -->
          <div v-show="tabActiva === 'lotes'" class="sd__section">
            <button class="sd__section-toggle" @click="fotosExpanded = !fotosExpanded">
              <div class="sd__section-toggle-left">
                <span class="sd__section-emoji">📷</span>
                <span class="sd__section-title">Fotos</span>
                <span v-if="fotosSala.length" class="sd__pill">{{ fotosSala.length }}</span>
              </div>
              <i class="bi sd__chevron" :class="fotosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="fotosExpanded" class="sd__section-body">
              <div v-if="!fotosSala.length" class="sd__placeholder">
                Sin fotos todavía. El cultivador las saca desde la app del celular.
              </div>
              <div v-else class="sd__fotos">
                <div v-for="f in fotosSala" :key="f.id" class="sd__foto">
                  <a :href="f.url" target="_blank" rel="noopener">
                    <img :src="f.url" :alt="f.filename" loading="lazy" />
                  </a>
                  <div class="sd__foto-pie">
                    <span>{{ f.created_at_label }}</span>
                    <button v-if="canEdit" class="sd__foto-del" title="Eliminar" @click="borrarFoto(f)">
                      <i class="bi bi-trash"></i>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Tab: Historial -->
          <div v-show="tabActiva === 'historial'" class="sd__tab-panel">
            <div v-if="historialKpis" class="sd__hist-kpis">
              <div class="sd__hist-kpi">
                <div class="sd__hist-kpi-val">{{ historialKpis.total_ciclos }}</div>
                <div class="sd__hist-kpi-lbl">Total cultivos</div>
              </div>
              <div class="sd__hist-kpi">
                <div class="sd__hist-kpi-val">{{ historialKpis.ciclos_finalizados }}</div>
                <div class="sd__hist-kpi-lbl">Finalizados</div>
              </div>
              <div class="sd__hist-kpi">
                <div class="sd__hist-kpi-val">
                  {{ historialKpis.duracion_promedio_dias ?? '—' }}<small v-if="historialKpis.duracion_promedio_dias">d</small>
                </div>
                <div class="sd__hist-kpi-lbl">Duración prom.</div>
              </div>
              <div class="sd__hist-kpi">
                <div class="sd__hist-kpi-val">
                  {{ historialKpis.rendimiento_promedio_g != null ? historialKpis.rendimiento_promedio_g + ' g' : '—' }}
                </div>
                <div class="sd__hist-kpi-lbl">Rend. prom.</div>
              </div>
            </div>

            <div v-if="historialLotes.length" class="sd__hist-wrap">
              <table class="sd__hist-table">
                <thead>
                  <tr>
                    <th>Código</th>
                    <th>Genética</th>
                    <th>Inicio</th>
                    <!-- Días: el ciclo cerrado si ya cosechó, o los que lleva si sigue en curso.
                         Antes solo mostraba el cerrado, así que todo lote vivo decía "—". -->
                    <th>Días</th>
                    <th>En estado</th>
                    <th>Rendimiento</th>
                    <th>Estado</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="l in historialLotes" :key="l.id">
                    <td>
                      <RouterLink :to="{ name: 'lote-detail', params: { id: l.id } }" class="sd__hist-link">{{ l.codigo }}</RouterLink>
                    </td>
                    <td>{{ l.genetica_nombre || '—' }}</td>
                    <td>{{ l.start_date || '—' }}</td>
                    <td>
                      <template v-if="l.duracion_dias != null">{{ l.duracion_dias }}</template>
                      <template v-else-if="l.dias_transcurridos != null">
                        {{ l.dias_transcurridos }}<span class="sd__hist-encurso" title="Ciclo en curso: el número sigue corriendo">·</span>
                      </template>
                      <template v-else>—</template>
                    </td>
                    <td>{{ l.dias_en_estado != null ? l.dias_en_estado + ' d' : '—' }}</td>
                    <td>{{ l.rendimiento_real_g != null ? l.rendimiento_real_g + ' g' : '—' }}</td>
                    <td>
                      <span class="sd__lote-badge" :style="{ background: estadoMeta(l.estado).color + '18', color: estadoMeta(l.estado).color }">
                        {{ estadoMeta(l.estado).label }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-else class="sd__hist-empty">Sin historial disponible para esta sala.</div>
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
              <dt>Creado por</dt><dd>{{ sala.created_by_name || "—" }}</dd>
              <dt>Creado</dt><dd>{{ formatDate(sala.created_at) }}</dd>
              <dt>Actualizado</dt><dd>{{ formatDate(sala.updated_at) }}</dd>
            </dl>
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
              <button v-if="canEdit && !showCameraForm" class="sd__link-small" @click="abrirFormCamera">
                <i :class="sala.camera_stream_url ? 'bi bi-pencil' : 'bi bi-plus-lg'"></i>
                {{ sala.camera_stream_url ? 'Editar' : 'Conectar cámara' }}
              </button>
            </div>

            <!-- Formulario de configuración -->
            <div v-if="showCameraForm" class="sd__cam-form">
              <p class="sd__cam-help">
                Ingresá la dirección IP de tu cámara. La encontrás en la configuración de la cámara o en tu router.<br>
                <strong>Ejemplo:</strong> <code>192.168.1.50</code> o <code>http://192.168.1.50/snapshot.jpg</code>
              </p>
              <div class="sd__cam-row">
                <label class="sd__cam-label">Dirección de la cámara</label>
                <div class="sd__cam-input-wrap">
                  <input
                    v-model="cameraInputUrl"
                    type="text"
                    placeholder="192.168.1.50  o  http://192.168.1.50/video"
                    class="sd__cam-input"
                    @keydown.enter="probarCamara"
                  />
                  <button class="sd__cam-btn-probar" :disabled="!cameraInputUrl.trim()" @click="probarCamara">
                    Probar
                  </button>
                </div>
              </div>

              <!-- Preview de prueba -->
              <div v-if="cameraTestSrc" class="sd__cam-test">
                <div class="sd__cam-stream">
                  <img
                    :src="cameraTestSrc"
                    class="sd__cam-img"
                    alt="Prueba de cámara"
                    @load="cameraTestOk = true; cameraTestError = false"
                    @error="cameraTestError = true; cameraTestOk = false"
                  />
                </div>
                <div v-if="cameraTestOk" class="sd__cam-test-ok">
                  <i class="bi bi-check-circle-fill"></i> La cámara responde correctamente
                </div>
                <div v-if="cameraTestError" class="sd__cam-test-err">
                  <i class="bi bi-exclamation-triangle"></i>
                  No se pudo conectar. Verificá que la cámara esté encendida y en la misma red.
                </div>
              </div>

              <div class="sd__cam-actions">
                <button class="sd__btn-ghost-sm" @click="showCameraForm = false">Cancelar</button>
                <button
                  v-if="sala.camera_stream_url"
                  class="sd__btn-ghost-sm sd__btn-ghost-sm--danger"
                  :disabled="savingCamera"
                  @click="eliminarCamara"
                >Quitar cámara</button>
                <button
                  class="sd__btn-primary-sm"
                  :disabled="savingCamera || !cameraInputUrl.trim()"
                  @click="saveCamera"
                >
                  {{ savingCamera ? 'Guardando…' : 'Guardar' }}
                </button>
              </div>
            </div>

            <!-- Vista de cámara guardada -->
            <template v-else-if="sala.camera_stream_url || sala.camera_snapshot_url">
              <div class="sd__cam-stream">
                <img
                  :src="snapshotSrc"
                  :key="snapshotKey"
                  class="sd__cam-img"
                  alt="Cámara sala"
                  @error="cameraError = true"
                />
                <div v-if="cameraError" class="sd__cam-error">
                  <span>📷 Sin señal — verificá que la cámara esté encendida</span>
                </div>
                <div class="sd__cam-controls">
                  <button class="sd__cam-btn" @click="refreshSnapshot" title="Actualizar imagen">
                    <i class="bi bi-arrow-clockwise"></i>
                  </button>
                  <span class="sd__cam-ts">{{ snapshotTs }}</span>
                </div>
              </div>
            </template>

            <div v-else class="sd__cam-empty">
              <span>Sin cámara configurada</span>
            </div>
          </div>

        </div>
      </div>
    </template>
    <!-- Modal Crear Lote (componente compartido NuevoLoteModal) -->
    <NuevoLoteModal :show="showCreate" :sala="sala" @close="showCreate = false" @created="onNuevoLoteCreado" />

    <!-- Modal cambiar fase (vege ↔ flora) -->
    <Teleport to="body">
      <div v-if="showCambiarFaseModal" class="sd__overlay">
        <div class="sd__modal" style="max-width:420px">
          <div class="sd__modal-header">
            <div>
              <h3 class="sd__modal-title">🔄 Cambiar fase de la sala</h3>
              <p class="sd__modal-sub">{{ sala?.nombre }}</p>
            </div>
            <button class="sd__modal-close" @click="showCambiarFaseModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="sd__modal-body">
            <div v-if="cambiarFaseError" class="sd__alert">{{ cambiarFaseError }}</div>

            <!-- Flecha de transición -->
            <div class="sd__fase-arrow">
              <div class="sd__fase-chip sd__fase-chip--origen">
                <i class="bi" :class="sala?.kind === 'vegetativo' ? 'bi-flower1' : 'bi-flower2'"></i>
                {{ faseLabel(sala?.kind) }}
              </div>
              <i class="bi bi-arrow-right sd__fase-ico"></i>
              <div class="sd__fase-chip sd__fase-chip--destino">
                <i class="bi" :class="faseSiguiente === 'vegetativo' ? 'bi-flower1' : 'bi-flower2'"></i>
                {{ faseLabel(faseSiguiente) }}
              </div>
            </div>

            <!-- Impacto -->
            <div v-if="lotesAfectados.length" class="sd__fase-impacto">
              <div class="sd__fase-impacto-row">
                <span>Lotes que cambian de estado</span>
                <strong>{{ lotesAfectados.length }}</strong>
              </div>
              <div class="sd__fase-impacto-row">
                <span>Plantas afectadas</span>
                <strong>{{ plantasAfectadas }}</strong>
              </div>
            </div>
            <div v-else class="sd__fase-warning">
              <i class="bi bi-exclamation-triangle-fill"></i>
              No hay lotes en estado <strong>{{ faseLabel(sala?.kind) }}</strong> en esta sala. No habrá cambios en lotes ni plantas, solo cambia el tipo de sala.
            </div>

            <p class="sd__fase-desc">
              Esta acción cambia el estado de todos los lotes y sus plantas. Se registra un evento en cada lote para trazabilidad.
            </p>
          </div>
          <div class="sd__modal-footer">
            <button class="sd__btn-ghost" :disabled="cambiarFaseLoading" @click="showCambiarFaseModal = false">Cancelar</button>
            <button class="sd__btn-primary" :disabled="cambiarFaseLoading" @click="ejecutarCambioFase">
              <DsSpinner v-if="cambiarFaseLoading" :size="14" />
              <i v-else class="bi bi-arrow-right-circle"></i>
              Pasar a {{ faseLabel(faseSiguiente) }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Wizard crear lote cosecha -->
    <ModalCrearLoteCosecha
      v-if="showCrearLoteCosecha && sala"
      :sala="sala"
      @created="onLoteCosechaCreado"
      @close="showCrearLoteCosecha = false"
    />

    <!-- Modal cargar lote (usa Teleport internamente) -->
    <ModalCargarLote
      v-if="showCargarLote && sala"
      :sala="sala"
      @loaded="onLoteCargado"
      @close="showCargarLote = false"
    />

    <!-- El clima del propagador: va aparte del de la sala porque adentro del domo hay otro
         ambiente (60% en el cuarto, 90% adentro). -->
    <RegistroEnraizadoModal
      v-model="enraizadoOpen"
      :sala-id="salaId"
      :sala-nombre="sala?.nombre || ''"
      :lotes-count="items.filter(l => l.estado === 'enraizado').length"
      @registrado="lotes.fetchBySala(salaId)"
    />

    <RegistroSalaModal
      v-model="lecturaOpen"
      :sala="sala"
      @saved="cargarAmbienteMini"
    />

    <!-- Modal Editar Sala -->
    <Teleport to="body">
      <div v-if="showEditSala" class="sd__overlay">
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
                  <option v-if="!['vegetativo','floracion'].includes(sala?.kind)" value="">Sin especificar</option>
                  <option
                    v-for="k in (['vegetativo','floracion'].includes(sala?.kind) ? SALA_KINDS.filter(k => ['vegetativo','floracion'].includes(k.value)) : SALA_KINDS)"
                    :key="k.value"
                    :value="k.value"
                  >{{ k.label }}</option>
                </select>
              </div>
              <div class="sd__field">
                <label class="sd__label">Estado</label>
                <select class="sd__input" v-model="editSalaForm.state">
                  <option value="activa">Activa</option>
                  <option value="mantenimiento">En mantenimiento</option>
                  <option value="cerrada">Cerrada</option>
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
            <button class="sd__btn-primary" :disabled="savingEditSala" @click="saveEditSala()">
              <DsSpinner v-if="savingEditSala" :size="14" />
              <i v-else class="bi bi-check-lg"></i>Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal upgrade plan -->
    <Teleport to="body">
      <div v-if="showUpgrade" class="sd__overlay">
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


.sd__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.sd__error { padding: 1rem 1.25rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 10px; font-size: .875rem; }

.sd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.75rem; flex-wrap: wrap; }
.sd__hero-title-row { display: flex; align-items: center; gap: .65rem; margin-bottom: .3rem; flex-wrap: wrap; }
.sd__title { font-size: 1.8rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.sd__subtitle { font-size: .85rem; color: #60725d; margin: 0; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.sd__subtitle-sep { color: var(--c-slate-300); }
.sd__hero-actions { display: flex; gap: .5rem; }

/* Estado dropdown */
.sd__estado-wrap { position: relative; }
.sd__estado-dropdown { position: relative; }
.sd__estado-pill {
  font-size: .68rem; font-weight: 800; text-transform: uppercase;
  letter-spacing: .08em; padding: .28em .75em; border-radius: 999px;
  cursor: pointer; user-select: none; display: inline-flex; align-items: center; gap: .3rem;
}
.sd__estado-menu {
  display: flex; flex-direction: column; position: absolute;
  top: calc(100% + 4px); left: 0; z-index: 100;
  background: #fff; border: 1px solid var(--c-slate-200); border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0,0,0,.12); overflow: hidden; min-width: 160px;
}
.sd__estado-option {
  padding: .6rem 1rem; font-size: .82rem; font-weight: 600;
  background: transparent; border: none; cursor: pointer;
  text-align: left; transition: background .12s; color: var(--c-slate-600);
}
.sd__estado-option:hover { background: var(--c-slate-50); }
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
.sd__kpi-sub { font-size: .72rem; color: var(--c-slate-400); }
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

/* Selección para mover lotes */
.sd__lotes-tools { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; padding: 0 0 10px; }
.sd__selall { display: flex; align-items: center; gap: 6px; font-size: 13px; color: var(--c-slate-600); cursor: pointer; white-space: nowrap; }
.sd__selall input { width: 15px; height: 15px; accent-color: #1b5e20; cursor: pointer; }
.sd__lotes-search { flex: 1; min-width: 160px; padding: 7px 11px; border: 1px solid var(--c-slate-200); border-radius: 8px; font-size: 13px; }
.sd__lotes-filter { padding: 7px 11px; border: 1px solid var(--c-slate-200); border-radius: 8px; font-size: 13px; background: #fff; }
.sd__lote-wrap { display: flex; align-items: center; gap: 8px; }
.sd__lote-wrap > .sd__lote { flex: 1; min-width: 0; }
.sd__lote-cb { display: flex; align-items: center; padding: 0 2px 0 6px; cursor: pointer; }
.sd__lote-cb input { width: 16px; height: 16px; cursor: pointer; accent-color: #1b5e20; }
.sd__movbar {
  position: fixed; left: 50%; bottom: 20px; transform: translateX(-50%); z-index: 900;
  display: flex; align-items: center; gap: 10px; flex-wrap: wrap;
  background: var(--c-slate-900); color: #fff; padding: 10px 14px; border-radius: 999px;
  box-shadow: 0 12px 32px rgb(15 23 42 / .3); font-size: 13px;
}
.sd__movbar-txt { font-weight: 700; }
.sd__movbar-sel { border: none; border-radius: 999px; padding: 6px 12px; font-size: 13px; max-width: 260px; }
.sd__movbar-ghost { background: none; border: none; color: var(--c-slate-400); font-size: 13px; font-weight: 600; cursor: pointer; }
.sd__movbar-ghost:hover { color: #fff; }
.sd__movbar-btn {
  background: #16a34a; border: none; color: #fff; border-radius: 999px;
  padding: 7px 18px; font-size: 13px; font-weight: 700; cursor: pointer;
}
.sd__movbar-btn:disabled { background: var(--c-slate-600); cursor: default; }

/* Ambiente actual */
.sd__kpi--amb .sd__kpi-value { display: flex; align-items: baseline; gap: 8px; }
/* Se distingue del ambiente del cuarto de un vistazo: son dos aires, no dos lecturas. */
.sd__kpi--incubadora { border-color: #a5f3fc; background: #ecfeff; }
.sd__amb-hum { font-size: .62em; color: var(--c-slate-500); font-weight: 600; }
.sd__kpi--viejo .sd__kpi-value { color: var(--c-slate-400); }
.sd__amb-vpd { font-size: 10px; font-weight: 700; padding: 1px 7px; border-radius: 999px; margin-left: 6px; cursor: help; }
.sd__amb-vpd--ok   { background: #f0fdf4; color: #15803d; }
.sd__amb-vpd--bajo { background: #dbeafe; color: #1d4ed8; }
.sd__amb-vpd--alto { background: #fef3c7; color: #b45309; }
.sd__amb-vpd--malo { background: #fee2e2; color: #dc2626; }
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
.sd__lote-meta { display: flex; gap: .6rem; flex-wrap: wrap; font-size: .73rem; color: var(--c-slate-400); margin-bottom: .5rem; }
.sd__lote-gen    { color: #3F6452; font-weight: 600; }
.sd__lote-strain { color: var(--c-slate-400); font-style: italic; }
.sd__cosecha-parcial { color: #15803d; font-weight: 600; }
.sd__lote-progress-wrap { display: flex; align-items: center; gap: .6rem; }
.sd__lote-progress-track { flex: 1; height: 3px; background: #e8f5e9; border-radius: 999px; overflow: hidden; }
.sd__lote-progress-fill { height: 100%; border-radius: 999px; transition: width .5s ease; }
.sd__lote-progress-pct { font-size: .65rem; color: var(--c-slate-400); font-weight: 600; flex-shrink: 0; }
.sd__lote-arrow { color: #a7d7a9; font-size: .75rem; align-self: center; padding-right: 1rem; flex-shrink: 0; }
.sd__lotes-pager { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: .75rem 1rem; border-top: 1px solid #e8f5e9; }
.sd__pager-btn { background: #fff; border: 1.5px solid #d4e6d4; color: #2d6a4f; padding: .3rem .7rem; border-radius: 7px; font-size: .82rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.sd__pager-btn:hover:not(:disabled) { border-color: #1b5e20; color: #1b5e20; }
.sd__pager-btn:disabled { opacity: .4; cursor: not-allowed; }
.sd__pager-info { font-size: .82rem; color: var(--c-slate-500); font-weight: 600; min-width: 50px; text-align: center; }

.sd__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.sd__card--mt { margin-top: 1rem; }
.sd__card--ambiente { margin-bottom: 1rem; }
.sd__card-body--p0 { padding: .75rem; }
.sd__link-small { font-size: .72rem; font-weight: 600; color: #1b5e20; text-decoration: none; display: flex; align-items: center; gap: .25rem; }
.sd__link-small:hover { text-decoration: underline; }
.sd__card-header { padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; }
.sd__card-title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.sd__card-body { padding: 1rem; }
.sd__card-notes { padding: .9rem 1rem; font-size: .82rem; color: var(--c-slate-600); line-height: 1.6; }

.sd__dl { display: grid; grid-template-columns: auto 1fr; gap: .45rem .75rem; padding: .9rem 1rem; margin: 0; }
.sd__dl dt { font-size: .75rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.sd__dl dd { font-size: .8rem; color: #1a1a1a; font-weight: 500; margin: 0; }

.sd__placeholder { padding: 1rem 1.1rem; color: var(--c-slate-400); font-size: .875rem; }

.sd__btn-lectura { display: inline-flex; align-items: center; gap: .35rem; background: transparent; color: var(--c-role-cultivador, #5C7A4A); border: 1.5px solid var(--c-role-cultivador, #5C7A4A); padding: .5rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.sd__btn-lectura:hover { background: rgba(92,122,74,.08); }
.sd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.sd__btn-primary:hover:not(:disabled) { background: #104417; }
.sd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.sd__btn-edit { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); padding: .6rem .9rem; border-radius: 8px; font-size: .875rem; cursor: pointer; transition: all .15s; }
.sd__btn-edit:hover { background: var(--c-slate-50); border-color: var(--c-slate-400); }
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
.sd__capacity-info { display: flex; justify-content: space-between; font-size: .82rem; margin-bottom: .5rem; color: var(--c-slate-600); }
.sd__capacity-track { height: 6px; background: #d4e6d4; border-radius: 999px; overflow: hidden; }
.sd__capacity-fill { height: 100%; border-radius: 999px; transition: width .4s; }

.sd__grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
@media (max-width: 480px) { .sd__grid { grid-template-columns: 1fr; } }
.sd__field { display: flex; flex-direction: column; gap: .35rem; }
.sd__field--full { grid-column: 1 / -1; }
.sd__label { font-size: .8rem; font-weight: 600; color: #374151; }
.sd__label-opt { font-weight: 400; color: var(--c-slate-400); }
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
.sd__input--disabled { color: var(--c-slate-400); cursor: default; }
.sd__hint { font-size: .72rem; color: var(--c-slate-400); line-height: 1.3; }

/* Madre picker */
.sd__madre-picker { position: relative; display: flex; flex-direction: column; gap: .4rem; }
.sd__madre-chip {
  display: inline-flex; align-items: center; gap: .4rem; flex-wrap: wrap;
  background: #e8f5e9; border: 1px solid #a5d6a7; border-radius: 8px;
  padding: .4rem .75rem; font-size: .82rem; color: #1b5e20;
}
.sd__madre-chip i { color: #16a34a; font-size: .85rem; }
.sd__madre-chip-lote { color: var(--c-slate-400); font-size: .75rem; font-family: monospace; }
.sd__madre-chip-gen  { color: #60725d; font-size: .75rem; }
.sd__madre-clear {
  margin-left: auto; background: none; border: none; cursor: pointer;
  color: #6b7280; font-size: 1rem; line-height: 1; padding: 0 .1rem;
}
.sd__madre-clear:hover { color: #dc2626; }
.sd__madre-dropdown {
  position: absolute; top: calc(100% + 2px); left: 0; right: 0;
  background: #fff; border: 1.5px solid #d4e6d4; border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0,0,0,.1);
  max-height: 300px; overflow-y: auto; z-index: 50;
}
.sd__madre-sala-hd {
  display: flex; align-items: center; justify-content: space-between; gap: .5rem;
  padding: .4rem .85rem; background: #1a1f36; color: var(--c-slate-200);
  font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em;
  position: sticky; top: 0; z-index: 1;
}
.sd__madre-sala-hd i { color: #7c8db5; font-size: .72rem; }
.sd__madre-sala-cnt { font-weight: 400; color: var(--c-slate-500); font-size: .66rem; }
.sd__madre-lote-hd {
  display: flex; align-items: center; gap: .4rem;
  padding: .32rem .85rem .32rem 1.1rem;
  background: var(--c-slate-50); border-bottom: 1px solid #e8f0e8;
  font-size: .72rem; font-weight: 600; color: #374151;
}
.sd__madre-lote-hd i { color: #9ca3af; font-size: .72rem; }
.sd__madre-lote-gen { margin-left: auto; color: #15803d; font-size: .7rem; font-weight: 500; }
.sd__madre-opt {
  display: flex; align-items: baseline; justify-content: space-between; gap: .5rem;
  padding: .52rem .85rem; cursor: pointer; transition: background .1s;
}
.sd__madre-opt--plant { padding-left: 1.75rem; }
.sd__madre-opt:hover, .sd__madre-opt--sel { background: #f0fdf4; }
.sd__madre-opt-nombre { font-size: .875rem; font-weight: 600; color: #1a1a1a; }
.sd__madre-opt-meta { font-size: .72rem; color: #60725d; white-space: nowrap; }
.sd__madre-opt-sala { color: #7c3aed; font-weight: 600; }
.sd__madre-empty { padding: .75rem 1rem; font-size: .82rem; color: var(--c-slate-400); text-align: center; }

/* Genetica hints */
.sd__label-heredada {
  font-size: .68rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em;
  color: #16a34a; background: #dcfce7; padding: .1rem .45rem; border-radius: 4px; margin-left: .4rem;
}
.sd__genetica-hint { margin: .3rem 0 0; font-size: .75rem; color: var(--c-slate-500); display: flex; align-items: center; gap: .3rem; }
.sd__genetica-link { color: #1b5e20; font-weight: 600; text-decoration: none; }
.sd__genetica-link:hover { text-decoration: underline; }

/* Tipo creación tabs */
.sd__tipo-tabs { display: flex; gap: .5rem; }
.sd__tipo-tab {
  flex: 1; padding: .6rem .9rem; background: #f4f8f4; border: 2px solid #d4e6d4;
  border-radius: 9px; font-size: .82rem; font-weight: 600; color: #374151;
  cursor: pointer; transition: all .15s; display: flex; align-items: center; justify-content: center; gap: .4rem;
}
.sd__tipo-tab:hover { border-color: #1b5e20; background: #f0fdf4; }
.sd__tipo-tab--active { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); }

/* Código readonly */
.sd__codigo-hint { font-size: .72rem; color: var(--c-slate-400); }

.sd__btn-ghost-sm { background: transparent; border: 1px solid #d4e6d4; color: #60725d; padding: .4rem .8rem; border-radius: 6px; font-size: .78rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.sd__btn-ghost-sm:hover { background: #f0fdf4; color: #1b5e20; }

/* Cambiar fase modal */
.sd__fase-arrow { display: flex; align-items: center; justify-content: center; gap: 1rem; margin: 1.25rem 0; }
.sd__fase-chip { display: flex; align-items: center; gap: .4rem; padding: .5rem 1rem; border-radius: 9px; font-size: .9rem; font-weight: 700; }
.sd__fase-chip--origen { background: var(--c-slate-100); color: var(--c-slate-600); }
.sd__fase-chip--destino { background: #f0fdf4; color: #15803d; border: 1.5px solid #86efac; }
.sd__fase-ico { color: var(--c-slate-400); font-size: 1.1rem; }
.sd__fase-impacto { background: var(--c-slate-50); border: 1.5px solid var(--c-slate-200); border-radius: 10px; padding: .75rem 1rem; margin-bottom: 1rem; display: flex; flex-direction: column; gap: .4rem; }
.sd__fase-impacto-row { display: flex; justify-content: space-between; align-items: center; font-size: .85rem; color: var(--c-slate-700); }
.sd__fase-impacto-row strong { color: var(--c-slate-900); font-size: .95rem; }
.sd__fase-warning { background: #fffbeb; border: 1.5px solid #fde68a; color: #92400e; border-radius: 10px; padding: .75rem 1rem; font-size: .82rem; margin-bottom: 1rem; display: flex; align-items: flex-start; gap: .5rem; }
.sd__fase-desc { font-size: .78rem; color: var(--c-slate-400); margin: 0; }
.sd__btn-primary-sm { background: #1b5e20; color: #fff; border: none; padding: .4rem .9rem; border-radius: 6px; font-size: .78rem; font-weight: 600; cursor: pointer; transition: background .15s; }
.sd__btn-primary-sm:hover { background: #155016; }
.sd__cam-form { display: flex; flex-direction: column; gap: .75rem; padding-top: .25rem; }
.sd__cam-help { font-size: .78rem; color: var(--c-slate-500); line-height: 1.5; background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 8px; padding: .6rem .8rem; margin: 0; }
.sd__cam-help code { background: var(--c-slate-200); border-radius: 4px; padding: .1em .35em; font-size: .85em; }
.sd__cam-row { display: flex; flex-direction: column; gap: .3rem; }
.sd__cam-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.sd__cam-input-wrap { display: flex; gap: .4rem; }
.sd__cam-input { flex: 1; background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .55rem .8rem; font-size: .875rem; color: #1a1a1a; outline: none; transition: border-color .15s; font-family: monospace; }
.sd__cam-input:focus { border-color: #1b5e20; }
.sd__cam-btn-probar { background: #f0fdf4; border: 1.5px solid #86efac; color: #15803d; border-radius: 8px; padding: .55rem 1rem; font-size: .82rem; font-weight: 700; cursor: pointer; white-space: nowrap; transition: all .15s; }
.sd__cam-btn-probar:hover:not(:disabled) { background: #dcfce7; }
.sd__cam-btn-probar:disabled { opacity: .4; cursor: not-allowed; }
.sd__cam-test { display: flex; flex-direction: column; gap: .4rem; }
.sd__cam-test-ok  { display: flex; align-items: center; gap: .4rem; font-size: .78rem; font-weight: 700; color: #16a34a; }
.sd__cam-test-err { display: flex; align-items: center; gap: .4rem; font-size: .78rem; color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; border-radius: 7px; padding: .5rem .7rem; }
.sd__cam-actions { display: flex; justify-content: flex-end; gap: .5rem; flex-wrap: wrap; }
.sd__btn-ghost-sm--danger { color: #dc2626; border-color: #fecaca; }
.sd__btn-ghost-sm--danger:hover { background: #fef2f2; }
.sd__cam-controls { display: flex; gap: .5rem; flex-wrap: wrap; margin-top: .25rem; align-items: center; }
.sd__cam-stream { margin-top: .25rem; border-radius: 8px; overflow: hidden; border: 1px solid #d4e6d4; background: #000; }
.sd__cam-img { width: 100%; display: block; max-height: 220px; object-fit: cover; }
.sd__cam-error { padding: .5rem .75rem; font-size: .78rem; color: var(--c-slate-400); text-align: center; background: #111; }
.sd__cam-btn { background: rgba(255,255,255,.15); border: none; color: #fff; border-radius: 5px; padding: .25rem .5rem; cursor: pointer; font-size: .78rem; }
.sd__cam-ts { font-size: .7rem; color: rgba(255,255,255,.5); }
.sd__cam-empty { color: var(--c-slate-400); font-size: .8rem; font-style: italic; text-align: center; padding: .5rem 0; }

/* ── Tabs ─────────────────────────────────────────────────── */
.sd__tabs { display: flex; gap: .4rem; margin-bottom: 1rem; }
.sd__tab {
  padding: .45rem 1rem; background: #f4f8f4; border: 1.5px solid #d4e6d4;
  border-radius: 8px; font-size: .82rem; font-weight: 600; color: var(--c-slate-600);
  cursor: pointer; transition: all .14s; white-space: nowrap;
}
.sd__tab:hover { border-color: #1b5e20; color: #1b5e20; background: #f0fdf4; }
.sd__tab--active { background: #f0fdf4; border-color: #1b5e20; color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }

.sd__tab-panel { padding: 1rem 0; }

/* ── Historial ────────────────────────────────────────────── */
.sd__hist-kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.25rem; }
.sd__hist-kpi { background: var(--c-slate-50); border: 1px solid var(--c-slate-200); border-radius: 10px; padding: .75rem 1rem; text-align: center; }
.sd__hist-kpi-val { font-size: 1.35rem; font-weight: 800; color: #1a1a1a; line-height: 1; }
.sd__hist-kpi-val small { font-size: .7rem; font-weight: 600; color: var(--c-slate-500); margin-left: .1rem; }
.sd__hist-kpi-lbl { font-size: .7rem; color: var(--c-slate-500); margin-top: .25rem; font-weight: 500; }

.sd__hist-wrap { overflow-x: auto; }
.sd__hist-table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.sd__hist-table th { padding: .45rem .75rem; text-align: left; font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: var(--c-slate-500); background: var(--c-slate-50); border-bottom: 2px solid var(--c-slate-200); white-space: nowrap; }
.sd__hist-table td { padding: .5rem .75rem; border-bottom: 1px solid var(--c-slate-100); color: var(--c-slate-700); vertical-align: middle; white-space: nowrap; }
.sd__hist-table tbody tr:hover { background: var(--c-slate-50); }
.sd__hist-link { color: #1b5e20; font-weight: 700; text-decoration: none; }
.sd__hist-link:hover { text-decoration: underline; }
.sd__hist-empty { font-size: .82rem; color: var(--c-slate-400); text-align: center; padding: 1.5rem 0; }
/* Marca discreta de "sigue corriendo": distingue un ciclo cerrado de uno en curso sin meter otra
   columna ni repetir la palabra en cada fila. */
.sd__hist-encurso { color: #86efac; font-weight: 700; margin-left: .2em; }
.sd__fotos { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: .6rem; }
.sd__foto { border: 1px solid var(--c-slate-200); border-radius: 10px; overflow: hidden; background: #fff; }
.sd__foto img { width: 100%; aspect-ratio: 4/3; object-fit: cover; display: block; }
.sd__foto-pie {
  display: flex; align-items: center; justify-content: space-between;
  padding: .3rem .5rem; font-size: .7rem; color: var(--c-slate-400);
}
.sd__foto-del { border: none; background: none; cursor: pointer; color: var(--c-slate-300); }
.sd__foto-del:hover { color: #dc2626; }

@media (max-width: 600px) {
  .sd__hist-kpis { grid-template-columns: repeat(2, 1fr); }
  .sd__tabs { flex-wrap: wrap; }
}
</style>
