<script setup>
import { onMounted, onUnmounted, ref, computed, watch } from "vue"
import AppDatePicker from '../components/ui/AppDatePicker.vue'
import { useRoute, useRouter } from "vue-router"
import { useLotesStore }  from "../stores/lotes"
import { usePlantsStore } from "../stores/plants"
import { useAuthStore }   from "../stores/auth"
import { useClubStore }   from "../stores/club"
import { getLoteHistorial, registrarTrasplante, listSedes, deleteLote, createSala, listAnalisisLaboratorio, createAnalisisLaboratorio, deleteAnalisisLaboratorio, createLoteEvento, updateLoteEvento, deleteLoteEvento, deleteRegistroAmbiental, deleteTarea } from "../lib/api"
import { useQRCode } from '../composables/useQRCode.js'
import { LAYOUT_LOTE, dibujarEtiquetaLote } from '../lib/pdfEtiquetas.js'
import TareasDelLote from '../components/TareasDelLote.vue'
import ModalCosechaPartial from '../components/salas/ModalCosechaPartial.vue'
import GraficosLote from '../components/GraficosLote.vue'
import Breadcrumb from '../components/ui/Breadcrumb.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import { useToast } from '../composables/useToast.js'
import { useConfirm } from '../composables/useConfirm.js'
import { ArrowRight, ChevronRight } from 'lucide-vue-next'
import { em, sm, pgm, growLabel, lightLabel, macetaLabel, fotoperiodoLabel, formatDate, formatDateTime,
  capitalizarFase, phaseBannerMsg, CICLO_BASE, POST_HARVEST_ESTADOS } from '../lib/loteHelpers.js'
import DesprenderLoteModal  from '../components/lotes/DesprenderLoteModal.vue'
import LoteHistorialSection from '../components/lotes/LoteHistorialSection.vue'
import LoteHistorialModal   from '../components/lotes/LoteHistorialModal.vue'
import LotePlantasSection   from '../components/lotes/LotePlantasSection.vue'
import LotePlanVsReal       from '../components/lotes/LotePlanVsReal.vue'
import LoteFotosSection     from '../components/lotes/LoteFotosSection.vue'
import LoteEditarModal      from '../components/lotes/LoteEditarModal.vue'
import LotePLCard           from '../components/lotes/LotePLCard.vue'
import LoteIACard           from '../components/lotes/LoteIACard.vue'
import DsBanner from '../design-system/components/Banner.vue'
import IniciarManicuraModal   from '../components/lotes/IniciarManicuraModal.vue'
import CompletarManicuraModal  from '../components/lotes/CompletarManicuraModal.vue'
import RegistroLoteModal       from '../components/lotes/registro/RegistroLoteModal.vue'
import ActionsDropdown         from '../components/ui/ActionsDropdown.vue'
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
const canEdit  = computed(() =>
  ['admin', 'supervisor', 'cultivador'].includes(auth.role) &&
  lote.value?.estado !== 'finalizado'
)
const canAdmin = computed(() => ['admin', 'supervisor'].includes(auth.role))
const esAdmin  = computed(() => auth.role === 'admin')
const isCultivador = computed(() => auth.role === 'cultivador')

const { generatePNG } = useQRCode()
const generandoQR = ref(false)

// La etiqueta del lote se dibuja en lib/pdfEtiquetas.js: misma pieza que la impresión en tanda desde
// /lotes. Sale en PDF del tamaño exacto de la etiqueta (93×60mm) — en HTML el diálogo de impresión
// le aplicaba su "ajustar a la página" y la encogía.
async function descargarQR() {
  const l = lote.value
  if (!l?.codigo_qr || generandoQR.value) return
  generandoQR.value = true
  try {
    const { jsPDF } = await import('jspdf')
    const qr = await generatePNG(`${window.location.origin}/l/${l.codigo_qr}`, LAYOUT_LOTE.qr)
    const doc = new jsPDF({ unit: 'mm', format: [LAYOUT_LOTE.ancho, LAYOUT_LOTE.alto], orientation: 'landscape' })
    dibujarEtiquetaLote(doc, 0, 0, {
      qrDataUrl: qr,
      codigo:    l.codigo,
      genetica:  l.genetica?.nombre || l.strain,
      estado:    em(l.estado).label,
      inicio:    l.start_date,
      plantas:   l.plants_count ?? 0,
      clubName:  club.data?.name || '',
    })
    doc.save(`etiqueta-${l.codigo}.pdf`)
  } catch {
    toast.error('No se pudo generar la etiqueta')
  } finally {
    generandoQR.value = false
  }
}

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

// ── Crear sala inline (desde modales de transición) ────────
const crearSalaOpen    = ref(false)
const crearSalaNombre  = ref('')
const crearSalaKind    = ref('')
const crearSalaLoading = ref(false)

async function crearSalaInline(kind) {
  const nombre = crearSalaNombre.value.trim()
  if (!nombre) return
  crearSalaLoading.value = true
  try {
    const { data } = await createSala({ nombre, kind })
    // Inyectar la sala nueva en salas_destino del lote actual
    if (lotes.current) {
      lotes.current = {
        ...lotes.current,
        salas_destino: [...(lotes.current.salas_destino || []), data],
      }
    }
    crearSalaOpen.value   = false
    crearSalaNombre.value = ''
    toast.success(`Sala "${nombre}" creada`)
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al crear la sala')
  } finally { crearSalaLoading.value = false }
}

// ── Historial unificado ───────────────────────────────────
const historial        = ref([])
const loadingHistorial = ref(false)
const verHistorialOpen = ref(false)

async function loadHistorial() {
  loadingHistorial.value = true
  try {
    const { data } = await getLoteHistorial(id)
    historial.value = data.historial || []
  } catch { historial.value = [] }
  finally { loadingHistorial.value = false }
}

async function onCrearEvento(payload) {
  try {
    await createLoteEvento(id, payload)
    toast.success('Actividad registrada')
    await loadHistorial()
    graficosKey.value++
  } catch (err) {
    toast.error(err?.response?.data?.errors?.[0] || err?.response?.data?.error || 'No se pudo registrar la actividad')
  }
}

async function onTrasplante(payload) {
  try {
    await registrarTrasplante(id, payload)
    toast.success('Trasplante registrado')
    await Promise.all([lotes.fetchOne(id), loadHistorial()])
    graficosKey.value++
  } catch (err) {
    toast.error(err?.response?.data?.error || 'No se pudo registrar el trasplante')
  }
}

async function onEditarEvento(payload) {
  // Solo edita eventos manuales de lote (el modal solo muestra ✏️ en los editables).
  try {
    const attrs = { descripcion: payload.descripcion, registrado_en: payload.registrado_en }
    if (payload.metadata) attrs.metadata = payload.metadata
    await updateLoteEvento(id, payload.id, attrs)
    toast.success('Evento actualizado')
    await loadHistorial()
    graficosKey.value++
  } catch (err) {
    toast.error(err?.response?.data?.errors?.[0] || err?.response?.data?.error || 'No se pudo actualizar el evento')
  }
}

async function onDeleteEvento(it) {
  const LABEL = { lote_evento: 'evento', registro_ambiental: 'registro', tarea: 'tarea completada' }
  const ok = await confirm({
    title:       `Borrar ${LABEL[it.source] || 'ítem'} del historial`,
    message:     `¿Borrás "${it.titulo}" del historial?\n\nEsta acción no se puede deshacer.`,
    confirmText: 'Sí, borrar',
    variant:     'danger',
  })
  if (!ok) return
  try {
    if (it.source === 'registro_ambiental') await deleteRegistroAmbiental(id, it.id)
    else if (it.source === 'tarea')          await deleteTarea(it.id)
    else                                     await deleteLoteEvento(id, it.id)
    toast.success('Borrado del historial')
    await loadHistorial()
    graficosKey.value++
  } catch (err) {
    toast.error(err?.response?.data?.error || 'No se pudo borrar')
  }
}

// ── Section toggles ────────────────────────────────────────
const tareasExpanded    = ref(true)
// Lab
const labExpanded   = ref(false)
const labFormOpen   = ref(false)
const loadingLab    = ref(false)
const guardandoLab  = ref(false)
const analisisLab   = ref([])
const labForm       = ref({ fecha_analisis: '', laboratorio: '', thc_pct: '', cbd_pct: '', cbg_pct: '', terpenos_principales: '' })

async function cargarAnalisisLab() {
  loadingLab.value = true
  try {
    const { data } = await listAnalisisLaboratorio(id)
    analisisLab.value = data || []
  } catch { analisisLab.value = [] }
  finally { loadingLab.value = false }
}

async function guardarAnalisis() {
  guardandoLab.value = true
  try {
    const { data } = await createAnalisisLaboratorio(id, labForm.value)
    analisisLab.value.unshift(data)
    labFormOpen.value = false
    labForm.value = { fecha_analisis: '', laboratorio: '', thc_pct: '', cbd_pct: '', cbg_pct: '', terpenos_principales: '' }
  } catch { /* toast handled globally */ } finally { guardandoLab.value = false }
}

async function eliminarAnalisis(a) {
  await deleteAnalisisLaboratorio(id, a.id)
  analisisLab.value = analisisLab.value.filter(x => x.id !== a.id)
}

const plantasExpanded   = ref(true)
const historialExpanded = ref(true)
const graficosExpanded  = ref(true)
const graficosKey       = ref(0)

// ── Plantas ────────────────────────────────────────────────
const plantList      = computed(() => plants.byLote(id))
const plantasActivas = computed(() => plantList.value.filter(p => !['cosechado', 'descartada'].includes(p.state)))
const pasadasUsadas  = computed(() => {
  const pasadas = plantList.value.map(p => p.pasada_cosecha).filter(Boolean)
  return [...new Set(pasadas)]
})
const siguientePasada = computed(() => {
  const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')
  return letras.find(l => !pasadasUsadas.value.includes(l)) || 'Z'
})

const contextoAsistente = computed(() => lote.value ? {
  tipo:          'lote',
  lote_id:       lote.value.id,
  lote_codigo:   lote.value.codigo,
  sala_id:       lote.value.sala?.id,
  sala_nombre:   lote.value.sala?.nombre,
  plantas_count: plantList.value.length,
  estado:        lote.value.estado,
} : null)

// ── Registro modal (nuevo) ────────────────────────────────
const showRegistroModalNew = ref(false)

// ── Acciones dropdown ─────────────────────────────────────
const loteAcciones = computed(() => {
  const items = []
  items.push({ emoji: '📋', label: 'Registrar lote', onClick: () => { showRegistroModalNew.value = true } })
  // Separar parte del lote: típicamente al prender, cuando la mitad va a una maceta y la mitad a
  // otra. Solo en cultivo y con más de una planta (desprender el lote entero lo dejaría vacío).
  if (puedeDesprender.value) {
    items.push({ emoji: '🪴', label: 'Separar plantas a otro lote', onClick: () => { desprenderOpen.value = true } })
  }
  if (canEdit.value) {
    items.push({ emoji: '✏️', label: 'Editar lote', onClick: () => editarOpen.value = true })
    items.push({ divider: true })
    items.push({ emoji: '🗑️', label: 'Eliminar lote', danger: true, onClick: eliminarLote })
  }
  return items
})

// ── Ciclo ──────────────────────────────────────────────────
const cicloPasos = computed(() => {
  const origen = lote.value?.origen
  // Un lote de semilla pasa por germinación → esqueje → vegetativo; uno de esqueje arranca en esqueje.
  if (origen === 'semilla') return ['enraizado', ...CICLO_BASE]
  if (origen === 'esqueje') return ['esqueje', ...CICLO_BASE]
  return ['enraizado', ...CICLO_BASE]
})
const cicloIndex = computed(() => lote.value ? cicloPasos.value.indexOf(lote.value.estado) : -1)

// ── Composables ────────────────────────────────────────────
const editarOpen = ref(false)

// ── Desprender (separar parte del lote) ────────────────────
const desprenderOpen = ref(false)
const CULTIVO = ['enraizado', 'vegetativo', 'floracion']
const puedeDesprender = computed(() =>
  (canEdit.value || isCultivador.value) &&
  CULTIVO.includes(lote.value?.estado) &&
  (lote.value?.plants_count || 0) > 1)

// Tras editar el lote (puede cambiar estado/fechas): refrescamos lote, historial,
// plantas y gráficos — antes solo se refrescaba el lote y quedaban viejos.
async function onLoteEditado() {
  await Promise.all([
    lotes.fetchOne(id),
    loadHistorial(),
    plants.fetchByLote(id),
  ])
  graficosKey.value++
}

const {
  showTransicionModal, savingTransicion, transicionError, transicionForm, transicionSalaId,
  showAvanzarSalaModal, avanzarSalaId, transicionandoRapido,
  avanzarMaceta, faltaMaceta, MACETAS,
  avanzarPrendieron, prendieronInvalido, noPrendieron, plantasDelLote,
  prendieronTodas, bloqueaAvance,
  showIniciarManicuraModal, showCompletarManicuraModal,
  showCosechaModal, cosechaSalaId, savingCosecha, cosechaError, cosechaForm,
  showCosechaPartialModal,
  handleAvanzarFase, openTransicionModal, ejecutarTransicion,
  avanzarFaseRapido, ejecutarCosecha, onCosechadoParcial,
  onManicuraIniciada, onManicuraCompletada,
} = useLoteTransiciones(id, { onPhaseChange: loadHistorial, sedes })

// ── Escape key handler ─────────────────────────────────────
function loteEscapeHandler(e) {
  if (e.key !== 'Escape') return
  if (editarOpen.value)               { editarOpen.value = false; return }
  if (showRegistroModalNew.value)     { showRegistroModalNew.value = false; return }
  if (showCosechaPartialModal.value)  { showCosechaPartialModal.value = false; return }
  if (showCosechaModal.value)         { showCosechaModal.value = false; return }
  if (showAvanzarSalaModal.value)     { showAvanzarSalaModal.value = false; return }
  if (showIniciarManicuraModal.value) { showIniciarManicuraModal.value = false; return }
  if (showCompletarManicuraModal.value) { showCompletarManicuraModal.value = false; return }
  if (showTransicionModal.value)      { showTransicionModal.value = false; return }
}

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
  await loadHistorial()
  try { const { data } = await listSedes(); sedes.value = data || [] } catch {}
  cargarAnalisisLab()
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
              <span v-if="lote.dias_en_estado != null" class="ld__estado-dias">· día {{ lote.dias_en_estado }}</span>
            </span>
          </div>
          <p class="ld__subtitle">
            <span v-if="lote.genetica">🌿 {{ lote.genetica.nombre }}</span>
            <span v-else-if="lote.strain" class="ld__strain-fallback">🌿 {{ lote.strain }}</span>
            <span v-if="lote.sala" class="ld__subtitle-sep">·</span>
            <span v-if="lote.sala">📍 {{ lote.sala.nombre }}</span>
            <span v-if="lote.start_date" class="ld__subtitle-sep">·</span>
            <span v-if="lote.start_date">📅 inicio {{ formatDate(lote.start_date) }}</span>
            <!-- De dónde salió, si nació desprendiéndose de otro lote. Sin esto el sufijo del
                 código (-B) no dice nada. -->
            <template v-if="lote.lote_origen">
              <span class="ld__subtitle-sep">·</span>
              <RouterLink :to="{ name: 'lote-detail', params: { id: lote.lote_origen.id } }" class="ld__origen">
                🪴 desprendido de {{ lote.lote_origen.codigo }}
              </RouterLink>
            </template>
            <template v-if="lote.desprendidos_count > 0">
              <span class="ld__subtitle-sep">·</span>
              <span class="ld__origen-txt">
                {{ lote.desprendidos_count }} lote{{ lote.desprendidos_count === 1 ? '' : 's' }} desprendido{{ lote.desprendidos_count === 1 ? '' : 's' }}
              </span>
            </template>
            <!-- El ciclo arranca en vegetativo; el enraizado se muestra al lado para no perder el
                 panorama ("día 28 de ciclo + 12 enraizando"). -->
            <span v-if="lote.dias_ciclo != null || lote.dias_enraizado != null" class="ld__subtitle-sep">·</span>
            <span v-if="lote.dias_ciclo != null" class="ld__dias-badge">Día {{ lote.dias_ciclo }} de ciclo</span>
            <span v-else-if="lote.dias_enraizado != null" class="ld__dias-badge">Enraizando · día {{ lote.dias_enraizado }}</span>
            <span v-if="lote.dias_ciclo != null && lote.dias_enraizado" class="ld__dias-extra">
              + {{ lote.dias_enraizado }}d enraizando
            </span>
          </p>
        </div>
        <div class="ld__hero-actions">
          <button
            v-if="canAdmin && ['en_manicura'].includes(lote.estado)"
            class="ld__btn-completar-manicura"
            @click="showCompletarManicuraModal = true"
          >
            <i class="bi bi-check2-circle"></i>Registrar pesaje
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
          <button
            v-if="lote.codigo_qr"
            class="ld__btn-sm ld__btn-sm--qr"
            :disabled="generandoQR"
            @click="descargarQR"
            title="Descargar la etiqueta del lote en PDF"
          >
            <i class="bi" :class="generandoQR ? 'bi-hourglass' : 'bi-qr-code'"></i>
            {{ generandoQR ? 'Generando…' : 'Etiqueta PDF' }}
          </button>
          <ActionsDropdown v-if="canEdit || isCultivador" :items="loteAcciones" />
        </div>
      </div>

      <!-- Banner lote finalizado (solo lectura) -->
      <div v-if="lote.estado === 'finalizado'" class="ld__finalizado-banner">
        <i class="bi bi-lock-fill"></i>
        <div>
          <strong>Lote cerrado — solo lectura.</strong>
          Este lote completó su cultivo y sus datos son inmutables. Para correcciones contactá al soporte.
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
              <TareasDelLote :lote="lote" :can-admin="canAdmin" />
            </div>
          </div>

          <!-- 2. Plantas -->
          <LotePlantasSection
            :lote="lote"
            :lote-id="id"
            :can-edit="canEdit"
            :is-cultivador="isCultivador"
            @cosechar="showCosechaPartialModal = true"
          />

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
              <LoteHistorialSection
                :historial="historial" :loading-historial="loadingHistorial"
                @ver="verHistorialOpen = true" />
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

          <!-- Análisis de laboratorio -->
          <div class="ld__section ld__section--mt">
            <button class="ld__section-toggle" @click="labExpanded = !labExpanded">
              <div class="ld__section-toggle-left">
                <span class="ld__section-emoji">🧪</span>
                <span class="ld__section-title">Análisis de laboratorio</span>
                <span v-if="analisisLab.length" class="ld__section-badge">{{ analisisLab.length }}</span>
              </div>
              <ChevronRight :size="16" class="ld__section-chevron" :class="{ 'ld__section-chevron--open': labExpanded }" />
            </button>
            <div v-show="labExpanded" class="ld__section-body ld__section-body--flush">
              <div v-if="loadingLab" class="ld__lab-loading">Cargando…</div>
              <div v-else>
                <table v-if="analisisLab.length" class="ld__lab-table">
                  <thead>
                    <tr><th>Fecha</th><th>THC%</th><th>CBD%</th><th>CBG%</th><th>Terpenos</th><th>Lab</th><th></th></tr>
                  </thead>
                  <tbody>
                    <tr v-for="a in analisisLab" :key="a.id">
                      <td>{{ a.fecha_analisis ? new Date(a.fecha_analisis + 'T00:00:00').toLocaleDateString('es-AR') : '—' }}</td>
                      <td class="ld__lab-val">{{ a.thc_pct != null ? a.thc_pct + '%' : '—' }}</td>
                      <td class="ld__lab-val">{{ a.cbd_pct != null ? a.cbd_pct + '%' : '—' }}</td>
                      <td class="ld__lab-val">{{ a.cbg_pct != null ? a.cbg_pct + '%' : '—' }}</td>
                      <td>{{ a.terpenos_principales || '—' }}</td>
                      <td class="ld__lab-lab">{{ a.laboratorio || '—' }}</td>
                      <td>
                        <button v-if="canEdit" class="ld__lab-del" @click="eliminarAnalisis(a)" title="Eliminar">
                          <i class="bi bi-trash3"></i>
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
                <div v-else class="ld__lab-empty">Sin análisis de laboratorio cargados.</div>
                <div v-if="canEdit" class="ld__lab-add-wrap">
                  <button class="ld__lab-toggle-form" @click="labFormOpen = !labFormOpen">
                    <i class="bi bi-plus-circle"></i> Cargar análisis
                  </button>
                  <div v-if="labFormOpen" class="ld__lab-form">
                    <div class="ld__lab-form-row">
                      <div class="ld__lab-field">
                        <label class="ld__lab-label">Fecha</label>
                        <AppDatePicker v-model="labForm.fecha_analisis" />
                      </div>
                      <div class="ld__lab-field">
                        <label class="ld__lab-label">Laboratorio</label>
                        <input v-model="labForm.laboratorio" type="text" class="ld__lab-input" placeholder="Nombre del lab" />
                      </div>
                    </div>
                    <div class="ld__lab-form-row">
                      <div class="ld__lab-field">
                        <label class="ld__lab-label">THC%</label>
                        <input v-model.number="labForm.thc_pct" type="number" step="0.01" min="0" max="100" class="ld__lab-input" />
                      </div>
                      <div class="ld__lab-field">
                        <label class="ld__lab-label">CBD%</label>
                        <input v-model.number="labForm.cbd_pct" type="number" step="0.01" min="0" max="100" class="ld__lab-input" />
                      </div>
                      <div class="ld__lab-field">
                        <label class="ld__lab-label">CBG%</label>
                        <input v-model.number="labForm.cbg_pct" type="number" step="0.01" min="0" max="100" class="ld__lab-input" />
                      </div>
                    </div>
                    <div class="ld__lab-field">
                      <label class="ld__lab-label">Terpenos principales</label>
                      <input v-model="labForm.terpenos_principales" type="text" class="ld__lab-input" placeholder="Myrcene, Limonene…" />
                    </div>
                    <div class="ld__lab-form-actions">
                      <button class="ld__lab-cancel" :disabled="guardandoLab" @click="labFormOpen = false">
                        Cancelar
                      </button>
                      <button class="ld__lab-save" :disabled="guardandoLab" @click="guardarAnalisis">
                        {{ guardandoLab ? 'Guardando…' : 'Guardar análisis' }}
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- 6. Fotos -->
          <LoteFotosSection :lote-id="id" :can-edit="canEdit" />

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
              <dt>Genética</dt><dd>{{ lote.genetica?.nombre || lote.strain || '—' }}</dd>
              <dt>Fotoperiodo</dt><dd>{{ fotoperiodoLabel(lote.estado, lote.fotoperiodo) }}</dd>
              <dt>Vegetativo objetivo</dt><dd>{{ lote.dias_vegetativo_objetivo ? lote.dias_vegetativo_objetivo + ' días' : '—' }}</dd>
              <dt>Floración objetivo</dt><dd>{{ lote.dias_floracion_objetivo ? lote.dias_floracion_objetivo + ' días' : '—' }}</dd>
              <dt>Cosecha objetivo</dt><dd>{{ lote.dias_cosecha_objetivo ? lote.dias_cosecha_objetivo + ' días' : '—' }}</dd>
              <dt>Inicio</dt><dd>{{ formatDate(lote.start_date) }}</dd>
              <dt>Día del ciclo</dt>
              <dd>
                {{ lote.dias_ciclo != null ? 'día ' + lote.dias_ciclo : 'todavía enraizando' }}
                <small v-if="lote.dias_enraizado" class="ld__dd-nota">+ {{ lote.dias_enraizado }}d enraizando</small>
              </dd>
              <dt>Edad de la planta</dt><dd>{{ lote.dias_desde_inicio != null ? 'día ' + lote.dias_desde_inicio : '—' }}</dd>
              <dt>Día en {{ em(lote.estado).label.toLowerCase() }}</dt><dd>{{ lote.dias_en_estado != null ? 'día ' + lote.dias_en_estado : '—' }}</dd>
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
            </div>
            <LotePlanVsReal :lote="lote" :lote-id="id" :can-admin="canAdmin" @saved="lotes.fetchOne(id)" />
          </div>

          <!-- P&L del lote: solo admin/supervisor -->
          <LotePLCard v-if="canAdmin" :lote-id="id" class="ld__card--mt" />

          <!-- Análisis IA — solo si la organización tiene IA habilitada -->
          <LoteIACard v-if="club.data?.features?.ia && canAdmin" :lote-id="id" class="ld__card--mt" />

        </div>
      </div>
    </template>

    <!-- ══ Modal Editar Lote ══ -->
    <LoteEditarModal
      v-model:open="editarOpen"
      :lote="lote"
      :lote-id="id"
      @saved="onLoteEditado"
    />

    <!-- ══ Modal Historial completo (registrar + ver + filtrar + editar) ══ -->
    <LoteHistorialModal
      v-model="verHistorialOpen"
      :historial="historial"
      :can-admin="esAdmin"
      @crear="onCrearEvento"
      @trasplante="onTrasplante"
      @editar="onEditarEvento"
      @delete="onDeleteEvento"
    />

    <!-- ══ Modal Registro del Lote (nuevo) ══ -->
    <RegistroLoteModal
      v-model="showRegistroModalNew"
      :lote="lote"
      :plants="plantasActivas"
      @saved="loadHistorial(); lotes.fetchOne(id); graficosKey++"
    />

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

                        <!-- Cuántas prendieron. Va vacío a propósito, con "prendieron todas" al lado: si
                 viniera prellenado con el total, el que va rápido confirma sin mirar y la organización
                 queda con 100% de prendimiento falso para siempre. -->
            <div v-if="lote?.estado === 'enraizado'" class="ld__field">
              <label class="ld__label">¿Cuántas prendieron? <span style="color:#dc2626">*</span></label>
              <div class="ld__prend-row">
                <input v-model="avanzarPrendieron" type="number" min="0" :max="plantasDelLote"
                       class="ld__input" :placeholder="`de ${plantasDelLote}`" />
                <button type="button" class="ld__prend-btn" @click="prendieronTodas">Prendieron todas</button>
              </div>
              <span v-if="prendieronInvalido" class="ld__prend-err">
                El lote tiene {{ plantasDelLote }} plantas.
              </span>
              <span v-else-if="noPrendieron > 0" class="ld__optional">
                {{ noPrendieron }} se descartan como "no prendió" — es lo que mide el % de prendimiento.
              </span>
            </div>

            <!-- Mismo pedido que en el avance del cultivador: el esqueje que prendió va a maceta. -->
            <div v-if="lote?.estado === 'enraizado'" class="ld__field">
              <label class="ld__label">Maceta a la que va <span style="color:#dc2626">*</span></label>
              <select v-model="avanzarMaceta" class="ld__input">
                <option value="">— Elegí el tamaño —</option>
                <option v-for="m in MACETAS" :key="m.v" :value="m.v">{{ m.l }}</option>
              </select>
              <span class="ld__optional">Define el riego, la frecuencia y cuándo toca el próximo trasplante.</span>
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
              <div v-if="!crearSalaOpen" class="ld__crear-sala-link">
                <button type="button" class="ld__link-btn" @click="crearSalaOpen = true; crearSalaNombre = ''">
                  <i class="bi bi-plus-circle"></i> Crear sala nueva
                </button>
              </div>
              <div v-else class="ld__crear-sala-form">
                <input v-model.trim="crearSalaNombre" type="text" class="ld__input" placeholder="Nombre de la sala"
                  @keydown.enter="crearSalaInline(lote?.proxima_fase_posible)"
                  @keydown.esc="crearSalaOpen = false" autofocus />
                <div class="ld__crear-sala-btns">
                  <button class="ld__btn-primary ld__btn-sm" :disabled="crearSalaLoading || !crearSalaNombre.trim()" @click="crearSalaInline(lote?.proxima_fase_posible)">
                    <DsSpinner v-if="crearSalaLoading" :size="12" /><template v-else><i class="bi bi-check-lg"></i></template> Crear
                  </button>
                  <button class="ld__btn-ghost ld__btn-sm" @click="crearSalaOpen = false">Cancelar</button>
                </div>
              </div>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" :disabled="savingTransicion" @click="showTransicionModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="savingTransicion || bloqueaAvance" @click="ejecutarTransicion">
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
              <div v-if="!crearSalaOpen" class="ld__crear-sala-link">
                <button type="button" class="ld__link-btn" @click="crearSalaOpen = true; crearSalaNombre = ''">
                  <i class="bi bi-plus-circle"></i> Crear sala nueva
                </button>
              </div>
              <div v-else class="ld__crear-sala-form">
                <input v-model.trim="crearSalaNombre" type="text" class="ld__input" placeholder="Nombre de la sala"
                  @keydown.enter="crearSalaInline('cosecha')" @keydown.esc="crearSalaOpen = false" />
                <div class="ld__crear-sala-btns">
                  <button class="ld__btn-primary ld__btn-sm" :disabled="crearSalaLoading || !crearSalaNombre.trim()" @click="crearSalaInline('cosecha')">
                    <DsSpinner v-if="crearSalaLoading" :size="12" /><template v-else><i class="bi bi-check-lg"></i></template> Crear
                  </button>
                  <button class="ld__btn-ghost ld__btn-sm" @click="crearSalaOpen = false">Cancelar</button>
                </div>
              </div>
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
            <!-- El esqueje que prendió va a maceta. Solo se pide en este salto (enraizado →
                 vegetativo): más adelante la maceta ya está puesta. -->
            <div v-if="lote?.estado === 'enraizado'" class="ld__field">
              <label class="ld__label">Maceta a la que va <span style="color:#dc2626">*</span></label>
              <select v-model="avanzarMaceta" class="ld__input">
                <option value="">— Elegí el tamaño —</option>
                <option v-for="m in MACETAS" :key="m.v" :value="m.v">{{ m.l }}</option>
              </select>
              <span class="ld__optional">Define el riego, la frecuencia y cuándo toca el próximo trasplante.</span>
            </div>
            <div class="ld__field">
              <label class="ld__label">Sala destino</label>
              <select v-model="avanzarSalaId" class="ld__input">
                <option :value="null">— Misma sala —</option>
                <option v-for="s in lote?.salas_destino || []" :key="s.id" :value="s.id">
                  {{ s.nombre }}{{ s.actual ? ' (actual)' : '' }}
                </option>
              </select>
              <span class="ld__optional">Si el lote no cambia de espacio físico, dejá la opción actual.</span>
              <div v-if="!crearSalaOpen" class="ld__crear-sala-link">
                <button type="button" class="ld__link-btn" @click="crearSalaOpen = true; crearSalaNombre = ''">
                  <i class="bi bi-plus-circle"></i> Crear sala nueva
                </button>
              </div>
              <div v-else class="ld__crear-sala-form">
                <input v-model.trim="crearSalaNombre" type="text" class="ld__input" placeholder="Nombre de la sala"
                  @keydown.enter="crearSalaInline(lote?.proxima_fase_posible)" @keydown.esc="crearSalaOpen = false" />
                <div class="ld__crear-sala-btns">
                  <button class="ld__btn-primary ld__btn-sm" :disabled="crearSalaLoading || !crearSalaNombre.trim()" @click="crearSalaInline(lote?.proxima_fase_posible)">
                    <DsSpinner v-if="crearSalaLoading" :size="12" /><template v-else><i class="bi bi-check-lg"></i></template> Crear
                  </button>
                  <button class="ld__btn-ghost ld__btn-sm" @click="crearSalaOpen = false">Cancelar</button>
                </div>
              </div>
            </div>
          </div>
          <div class="ld__modal-footer">
            <button class="ld__btn-ghost" @click="showAvanzarSalaModal = false">Cancelar</button>
            <button class="ld__btn-primary" :disabled="transicionandoRapido || bloqueaAvance" @click="avanzarFaseRapido(avanzarSalaId, avanzarMaceta)">
              <DsSpinner v-if="transicionandoRapido" :size="14" />
              <i v-else class="bi bi-arrow-right-circle"></i>Confirmar avance
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Cosecha Parcial ══ -->
    <DesprenderLoteModal
      v-model="desprenderOpen"
      :lote="lote"
      @desprendido="onLoteEditado"
    />

    <ModalCosechaPartial
      v-if="showCosechaPartialModal && lote"
      :lote="lote"
      :plantas="plantList"
      :pasadas-usadas="pasadasUsadas"
      :pasada-inicial="siguientePasada"
      @cosechado="onCosechadoParcial"
      @cerrar="showCosechaPartialModal = false"
    />

    <!-- ══ Modal Iniciar Manicura ══ -->
    <IniciarManicuraModal
      v-model="showIniciarManicuraModal"
      :lote="lote"
      :salas-destino="lote?.salas_destino || []"
      @avanzado="onManicuraIniciada"
      @sala-creada="(s) => { if (lotes.current) lotes.current = { ...lotes.current, salas_destino: [...(lotes.current.salas_destino || []), s] } }"
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
.ld__estado-dias { font-weight: 700; opacity: .75; margin-left: .15em; }
.ld__subtitle { font-size: .85rem; color: #60725d; margin: 0; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.ld__subtitle-sep { color: var(--c-slate-300); }
.ld__strain-fallback { font-style: italic; color: var(--c-slate-400); }
.ld__dias-badge { background: #e8f5e9; color: #1b5e20; font-size: .75rem; font-weight: 700; padding: .2em .6em; border-radius: 6px; }
/* El enraizado va al lado del ciclo, en tono menor: es contexto, no el número que se compara. */
.ld__dias-extra { font-size: .72rem; color: var(--c-slate-400); }
.ld__prend-row { display: flex; gap: .4rem; align-items: center; }
.ld__prend-row .ld__input { flex: 1; }
.ld__prend-btn {
  border: 1px solid var(--c-slate-200); background: none; border-radius: 8px; cursor: pointer;
  padding: .45rem .7rem; font-size: .75rem; color: #16a34a; white-space: nowrap;
}
.ld__prend-btn:hover { background: #f0fdf4; border-color: #86efac; }
.ld__prend-err { font-size: .72rem; color: #dc2626; }
.ld__origen { color: #16a34a; text-decoration: none; }
.ld__origen:hover { text-decoration: underline; }
.ld__origen-txt { color: var(--c-slate-400); }
.ld__dd-nota    { display: block; font-size: .7rem; color: var(--c-slate-400); font-weight: 400; }
.ld__hero-actions { display: flex; gap: .5rem; flex-wrap: wrap; }
.ld__ciclo { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.25rem 1.5rem 1rem; margin-bottom: 1.5rem; overflow-x: auto; }
.ld__ciclo-track { display: flex; align-items: flex-start; position: relative; min-width: 480px; }
.ld__ciclo-step { display: flex; flex-direction: column; align-items: center; flex: 1; position: relative; }
.ld__ciclo-dot { width: 36px; height: 36px; border-radius: 50%; background: #e8f5e9; border: 2px solid #d4e6d4; display: flex; align-items: center; justify-content: center; margin-bottom: .4rem; position: relative; z-index: 1; }
.ld__ciclo-emoji { font-size: .9rem; }
.ld__ciclo-label { font-size: .58rem; font-weight: 600; color: var(--c-slate-400); text-align: center; text-transform: uppercase; letter-spacing: .03em; }
.ld__ciclo-step--done .ld__ciclo-dot    { background: #dcfce7; border-color: #16a34a; }
.ld__ciclo-step--done .ld__ciclo-label  { color: #16a34a; }
.ld__ciclo-step--current .ld__ciclo-dot { background: #1b5e20; border-color: #1b5e20; box-shadow: 0 0 0 4px rgba(27,94,32,.15); }
.ld__ciclo-step--current .ld__ciclo-label { color: #1b5e20; font-weight: 800; }
.ld__ciclo-step--pending { opacity: .4; }
.ld__ciclo-connector { position: absolute; top: 17px; left: 50%; width: 100%; height: 2px; background: #d4e6d4; }
.ld__ciclo-connector--done { background: #16a34a; }
.ld__ciclo-progress { height: 4px; background: #e8f5e9; border-radius: 999px; overflow: hidden; margin-top: .75rem; }
.ld__ciclo-progress-fill { height: 100%; background: linear-gradient(90deg, #16a34a, #1b5e20); border-radius: 999px; transition: width .5s ease; }
.ld__layout { display: flex; flex-direction: column; gap: 1.25rem; }
.ld__aside { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.25rem; align-items: start; }
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
.ld__selector { display: flex; gap: .4rem; flex-wrap: wrap; }
.ld__sel-btn { display: flex; align-items: center; gap: .3rem; padding: .4rem .8rem; border: 1.5px solid #d4e6d4; border-radius: 8px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; text-transform: capitalize; }
.ld__sel-btn:hover { border-color: #1b5e20; }
.ld__sel-btn--active { transform: translateY(-1px); }
.ld__tareas-grid { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: .25rem; }
.ld__tarea-chip { display: inline-flex; align-items: center; gap: .3rem; padding: .38rem .8rem; border: 1.5px solid #d4e6d4; border-radius: 999px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; user-select: none; }
.ld__tarea-chip:hover { border-color: #1b5e20; background: #f0fdf4; }
.ld__tarea-chip--active { background: #e8f5e9; border-color: #1b5e20; color: #1b5e20; box-shadow: 0 1px 4px rgba(27,94,32,.15); }
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
.ld__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.ld__card--mt { margin-top: 0; }
.ld__card-header { display: flex; align-items: center; justify-content: space-between; padding: .8rem 1rem; border-bottom: 1px solid #e8f0e9; }
.ld__card-title { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.ld__card-notes { padding: .9rem 1rem; font-size: .82rem; color: var(--c-slate-600); line-height: 1.6; }
.ld__card-action { background: none; border: 1px solid #d4e6d4; color: #15803d; font-size: .75rem; font-weight: 600; padding: .25rem .65rem; border-radius: 6px; cursor: pointer; display: flex; align-items: center; gap: .3rem; transition: background .15s; }
.ld__card-action:hover { background: #f0fdf4; }
.ld__dl { display: grid; grid-template-columns: auto 1fr; gap: .4rem .75rem; padding: .9rem 1rem; margin: 0; }
.ld__dl dt { font-size: .75rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.ld__dl dd { font-size: .8rem; color: #1a1a1a; font-weight: 500; margin: 0; }
.ld__dl-total { font-weight: 700 !important; color: #1a3d2e !important; border-top: 1px solid #e8f0e9; padding-top: .3rem; }

.ld__placeholder { padding: 1rem 1.1rem; color: var(--c-slate-400); font-size: .875rem; }
.ld__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.ld__btn-primary:hover { background: #104417; }
.ld__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.ld__btn-secondary { display: inline-flex; align-items: center; gap: .4rem; background: #e8f5e9; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-secondary:hover { background: #d4e6d4; }
.ld__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.ld__btn-ghost:hover { background: #f0fdf4; }
.ld__btn-edit { display: inline-flex; align-items: center; gap: .4rem; background: #fff; color: var(--c-slate-600); border: 1.5px solid var(--c-slate-200); padding: .6rem .9rem; border-radius: 8px; font-size: .875rem; cursor: pointer; transition: all .15s; }
.ld__btn-edit:hover { background: var(--c-slate-50); border-color: var(--c-slate-400); }
.ld__btn-trasplante { display: inline-flex; align-items: center; gap: .4rem; background: #fffbeb; color: #92400e; border: 1.5px solid #fde68a; padding: .6rem 1.1rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: all .15s; white-space: nowrap; }
.ld__btn-trasplante:hover { background: #fef3c7; border-color: #fcd34d; }

/* Selección de plantas en trasplante */
.ld__tp-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: .4rem; }
.ld__tp-todas { font-size: .82rem; color: #374151; gap: .4rem; }
.ld__tp-count { font-size: .75rem; font-weight: 700; color: #1b5e20; background: #dcfce7; padding: .1em .5em; border-radius: 99px; }
.ld__tp-list { display: flex; flex-direction: column; gap: 2px; max-height: 220px; overflow-y: auto; border: 1.5px solid var(--c-slate-200); border-radius: 8px; padding: .25rem; }
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
  background: var(--c-slate-100); border: 1.5px solid var(--c-slate-200); border-radius: 8px;
  padding: .55rem .8rem; min-height: 38px; display: flex; align-items: center;
}
.ld__tl-current-val  { font-size: 1rem; font-weight: 700; color: #374151; }
.ld__tl-current-none { font-size: .82rem; color: var(--c-slate-400); font-style: italic; }
.ld__label-unit { font-size: .65rem; color: var(--c-slate-400); font-weight: 400; text-transform: none; letter-spacing: 0; margin-left: .2rem; }
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
.ld__optional { font-size: .68rem; font-weight: 500; color: var(--c-slate-400); text-transform: none; letter-spacing: 0; }
.ld__hint { font-size: .68rem; font-weight: 400; color: var(--c-slate-400); text-transform: none; letter-spacing: 0; }

/* Banner finalizado */
.ld__finalizado-banner {
  display: flex; align-items: flex-start; gap: .75rem;
  background: var(--c-slate-100); border: 1.5px solid var(--c-slate-300); border-radius: 10px;
  padding: .875rem 1rem; margin-bottom: 1rem;
  font-size: .82rem; color: var(--c-slate-700); line-height: 1.5;
}
.ld__finalizado-banner i { color: var(--c-slate-500); flex-shrink: 0; margin-top: .1rem; font-size: 1rem; }
.ld__finalizado-banner strong { color: var(--c-slate-900); }

.ld__crear-sala-link { margin-top: .4rem; }
.ld__link-btn { background: none; border: none; color: #15803d; font-size: .78rem; font-weight: 600; cursor: pointer; padding: 0; display: inline-flex; align-items: center; gap: .3rem; }
.ld__link-btn:hover { color: #14532d; text-decoration: underline; }
.ld__crear-sala-form { margin-top: .5rem; display: flex; flex-direction: column; gap: .4rem; background: #f0fdf4; border: 1.5px solid #bbf7d0; border-radius: 8px; padding: .65rem .75rem; }
.ld__crear-sala-btns { display: flex; gap: .4rem; }
.ld__btn-sm { padding: .35rem .75rem !important; font-size: .78rem !important; }
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
.ld__btn-completar-manicura { display: inline-flex; align-items: center; gap: .35rem; background: #059669; color: #fff; border: none; padding: .5rem .9rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.ld__btn-completar-manicura:hover { background: #047857; }

/* Sección badge + chevron */
.ld__section-badge { display: inline-flex; align-items: center; justify-content: center; background: #d4e6d4; color: #1b5e20; border-radius: 99px; font-size: .68rem; font-weight: 700; min-width: 18px; height: 18px; padding: 0 5px; margin-left: .3rem; }
.ld__section-chevron { color: #60725d; transition: transform .2s; flex-shrink: 0; }
.ld__section-chevron--open { transform: rotate(90deg); }

/* Lab analysis section */
.ld__lab-loading { font-size: .82rem; color: #60725d; padding: .5rem 0; }
.ld__lab-table { width: 100%; border-collapse: collapse; font-size: .82rem; }
.ld__lab-table th { text-align: left; font-size: .72rem; font-weight: 700; color: #60725d; text-transform: uppercase; letter-spacing: .04em; padding: .35rem .5rem; border-bottom: 1.5px solid #e8f0e9; white-space: nowrap; }
.ld__lab-table td { padding: .45rem .5rem; border-bottom: 1px solid #f0f4f0; vertical-align: middle; }
.ld__lab-val { font-weight: 700; color: #1b5e20; white-space: nowrap; }
.ld__lab-lab { color: #60725d; font-size: .78rem; }
.ld__lab-del { background: none; border: none; color: #dc2626; cursor: pointer; padding: .25rem; border-radius: 5px; display: inline-flex; align-items: center; opacity: .65; transition: opacity .15s; }
.ld__lab-del:hover { opacity: 1; background: #fef2f2; }
.ld__lab-empty { font-size: .82rem; color: var(--c-slate-400); font-style: italic; padding: .5rem 0; }
.ld__lab-add-wrap { margin-top: .75rem; }
.ld__lab-toggle-form { display: inline-flex; align-items: center; gap: var(--sp-2); background: var(--c-leaf-100); color: var(--c-leaf-800); border: 1px solid var(--c-leaf-100); padding: var(--sp-2) var(--sp-4); border-radius: var(--r-lg); font-size: var(--fs-13); font-weight: 600; cursor: pointer; transition: all var(--t-base); }
.ld__lab-toggle-form:hover { background: var(--c-leaf-50); border-color: var(--c-leaf-300); }
.ld__lab-form { margin-top: var(--sp-3); background: var(--c-leaf-50); border: 1.5px solid var(--c-leaf-100); border-radius: var(--r-xl); padding: var(--sp-6); display: flex; flex-direction: column; gap: var(--sp-4); }
.ld__lab-form-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: var(--sp-4); }
.ld__lab-field { display: flex; flex-direction: column; gap: .25rem; }
.ld__lab-label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ld__lab-input { background: #fff; border: 1.5px solid var(--c-leaf-100); border-radius: var(--r-md); padding: var(--sp-2) var(--sp-3); font-size: .85rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.ld__lab-input:focus { outline: none; border-color: var(--c-leaf-500); box-shadow: 0 0 0 3px rgba(26,61,46,.08); }
.ld__lab-form-actions { display: flex; justify-content: flex-end; gap: var(--sp-2); margin-top: var(--sp-2); }
.ld__lab-cancel { background: none; border: 1px solid var(--c-ink-300); color: var(--c-ink-700); padding: var(--sp-2) var(--sp-4); border-radius: var(--r-lg); font-size: var(--fs-13); font-weight: 600; cursor: pointer; }
.ld__lab-cancel:hover:not(:disabled) { background: var(--c-ink-100); }
.ld__lab-cancel:disabled { opacity: .5; cursor: not-allowed; }
.ld__lab-save { display: inline-flex; align-items: center; gap: var(--sp-2); background: var(--c-leaf-800); color: #fff; border: none; padding: var(--sp-2) var(--sp-5); border-radius: var(--r-lg); font-size: var(--fs-13); font-weight: 600; cursor: pointer; transition: opacity var(--t-base); }
.ld__lab-save:hover:not(:disabled) { opacity: .88; }
.ld__lab-save:disabled { opacity: .5; cursor: not-allowed; }
</style>
