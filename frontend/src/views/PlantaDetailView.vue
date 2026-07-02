<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useQRCode } from '../composables/useQRCode'
import { logoDataUrl } from '../lib/logoEmbed.js'
import { banderitaHTML, banderitaCSS } from '../lib/etiquetaPlanta.js'
import { usePlantsStore } from '../stores/plants'
import { useAuthStore }   from '../stores/auth'
import { useClubStore }   from '../stores/club'
import { getPlantActivities, createPlantActivity, updatePlant, addPlantFoto, removePlantFoto } from '../lib/api'
import Breadcrumb            from '../components/ui/Breadcrumb.vue'
import EmptyState            from '../components/ui/EmptyState.vue'
import Lightbox              from '../components/ui/Lightbox.vue'
import ActionsDropdown       from '../components/ui/ActionsDropdown.vue'
import RegistroPlantaModal   from '../components/plants/RegistroPlantaModal.vue'
import { useToast }      from '../composables/useToast.js'
import { useConfirm }   from '../composables/useConfirm.js'
import { useBluelabBLE } from '../composables/useBluelabBLE.js'
import DsSpinner from '../design-system/components/Spinner.vue'


const route  = useRoute()
const router = useRouter()
const plants = usePlantsStore()
const auth   = useAuthStore()
const club   = useClubStore()
const toast   = useToast()
const { confirm } = useConfirm()

const id           = Number(route.params.id)
const error        = ref(null)
const loading      = ref(true)
const planta       = computed(() => plants.current)

const activities       = ref([])
const loadingActs      = ref(false)
const fotosExpanded    = ref(false)
const historialExpanded= ref(true)
const fotos            = ref([])
const fotoInput        = ref(null)
const uploadingFoto    = ref(false)
const showFotoUploadModal   = ref(false)
const fotoUploadFile        = ref(null)
const fotoUploadDescripcion = ref('')
const fotoUploadPreview     = ref(null)
const lightboxOpen     = ref(false)
const lightboxIndex    = ref(0)
const lightboxImages   = computed(() => fotos.value.map(f => ({ src: f.url, alt: f.filename })))
function openLightbox(i) { lightboxIndex.value = i; lightboxOpen.value = true }
const qrDataUrl        = ref(null)
const qrDropdownOpen   = ref(false)
const { generatePNG, downloadPNG, downloadSVG } = useQRCode()

function qrPlantaUrl() {
  return `${window.location.origin}/p/${planta.value.codigo_qr}`
}
function qrFilename(ext) {
  return `qr-planta-${planta.value.codigo_qr}.${ext}`
}

async function generarQR() {
  if (!planta.value?.codigo_qr) return
  try {
    qrDataUrl.value = await generatePNG(qrPlantaUrl(), {
      width: 256, color: { dark: '#1b5e20', light: '#ffffff' }
    })
  } catch {}
}
async function descargarQRpng() { await downloadPNG(qrPlantaUrl(), qrFilename('png')) }
async function descargarQRsvg() { await downloadSVG(qrPlantaUrl(), qrFilename('svg')) }

// Banderita plegable (doble faz) de 140×25mm — se pliega en el medio sobre el tronco.
function _fechaEt(d) { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d || '')); return m ? `${m[3]}/${m[2]}/${m[1]}` : null }
async function imprimirEtiqueta() {
  const p = planta.value
  if (!p?.codigo_qr) return
  if (!club.data) { try { await club.fetch() } catch { /* club opcional en la etiqueta */ } }
  const qrDataUrl = await generatePNG(qrPlantaUrl(), { width: 220, margin: 2, color: { dark: '#1b5e20', light: '#ffffff' } })
  const etiqueta = banderitaHTML({
    qrDataUrl,
    nombre:    p.nombre || p.codigo_qr,
    genetica:  p.genetica?.nombre,
    lote:      p.lote?.codigo,
    inicio:    _fechaEt(p.lote?.start_date),
    clubName:  club.name,
    clubLogo:  await logoDataUrl(club.logoUrl),
  })
  const html = `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Etiqueta ${p.codigo_qr}</title>
<style>@page{size:160mm 26mm;margin:0} body{font-family:-apple-system,sans-serif} ${banderitaCSS}</style>
</head><body>${etiqueta}</body></html>`
  const win = window.open('', '_blank', 'width=800,height=400')
  if (!win) { toast.error('Permitir ventanas emergentes para imprimir'); return }
  win.document.write(html); win.document.close()
  setTimeout(() => win.print(), 700)
}

// Modal registro
const showModal   = ref(false)
const guardando   = ref(false)
const modalError  = ref(null)

function emptyForm() {
  return {
    altura_cm:    null,
    num_colas:    null,
    estado_salud: 'bueno',
    color_hojas:  'verde_oscuro',
    plagas:       'ninguna',
    deficiencias: '',
    notas:        ''
  }
}
const form = ref(emptyForm())

// ── Constantes visuales ───────────────────────────────────
const ESTADO_META = {
  germinacion: { label:'Germinación', color:'#64748b', bg:'#f1f5f9', emoji:'🌱' },
  esqueje:     { label:'Esqueje',     color:'#0891b2', bg:'#e0f2fe', emoji:'🪴' },
  vegetativo:  { label:'Vegetativo',  color:'#16a34a', bg:'#dcfce7', emoji:'🍃' },
  floracion:   { label:'Floración',   color:'#d97706', bg:'#fef3c7', emoji:'🌸' },
  cosechado:   { label:'Cosechada',   color:'#92400e', bg:'#fff7ed', emoji:'✂️'  },
  cosecha:     { label:'Cosecha',     color:'#92400e', bg:'#fff7ed', emoji:'✂️'  },
  manicura:    { label:'Manicura',    color:'#7c3aed', bg:'#ede9fe', emoji:'✋' },
  curado:      { label:'Curado',      color:'#b45309', bg:'#fef3c7', emoji:'🫙' },
  descartada:  { label:'Descartada',  color:'#dc2626', bg:'#fef2f2', emoji:'🗑️' },
}
// Secuencia canónica del ciclo: esqueje · vegetativo · floración · cosecha · manicura · curado.
// La planta como entidad llega hasta 'cosechado' (= cosecha); manicura y curado son estados
// del LOTE (post-cosecha), que el stepper refleja para esa parte final. (Secado = curado.)
const CICLO_PLANTA = computed(() => {
  const base = planta.value?.origen === 'esqueje'
    ? ['esqueje', 'vegetativo', 'floracion']
    : ['germinacion', 'vegetativo', 'floracion']
  return [...base, 'cosecha', 'manicura', 'curado']
})
const LOTE_A_CICLO = {
  cosecha: 'cosecha', en_manicura: 'manicura',
}
const SALUD_META = {
  excelente: { color:'#16a34a', emoji:'🟢', label:'Excelente' },
  bueno:     { color:'#65a30d', emoji:'🟡', label:'Bueno'     },
  regular:   { color:'#d97706', emoji:'🟠', label:'Regular'   },
  malo:      { color:'#dc2626', emoji:'🔴', label:'Malo'      },
  critico:   { color:'#991b1b', emoji:'🚨', label:'Crítico'   },
}
const COLOR_HOJAS_META = {
  verde_oscuro: { emoji:'🟢', label:'Verde oscuro', hint:'Óptimo'    },
  verde_claro:  { emoji:'🟩', label:'Verde claro',  hint:'Normal'    },
  amarillo:     { emoji:'🟡', label:'Amarillo',     hint:'Atención'  },
  marron:       { emoji:'🟤', label:'Marrón',       hint:'Problema'  },
}
const PLAGAS_META = {
  ninguna:  { color:'#16a34a', emoji:'✅', label:'Ninguna'  },
  leve:     { color:'#d97706', emoji:'⚠️', label:'Leve'     },
  moderada: { color:'#ea580c', emoji:'🐛', label:'Moderada' },
  severa:   { color:'#dc2626', emoji:'🚨', label:'Severa'   },
}

function em(e)  { return ESTADO_META[e]    || { label:e||'—', color:'#64748b', bg:'#f1f5f9', emoji:'🌿' } }
function sm(s)  { return SALUD_META[s]     || { color:'#94a3b8', emoji:'⚪', label:s||'—' } }
function pgm(p) { return PLAGAS_META[p]    || { color:'#94a3b8', emoji:'—', label:p||'—' } }
function chm(c) { return COLOR_HOJAS_META[c] || { emoji:'🌿', label:c||'—', hint:'' } }

const TAREAS_META = {
  riego:           { emoji: '💧', label: 'Riego' },
  nutricion:       { emoji: '🧪', label: 'Nutrición' },
  poda:            { emoji: '✂️',  label: 'Poda' },
  defoliacion:     { emoji: '🍃', label: 'Defoliación' },
  scrog_lst:       { emoji: '🪢', label: 'SCROG/LST' },
  revision_plagas: { emoji: '🔍', label: 'Rev. plagas' },
  limpieza_sala:   { emoji: '🧹', label: 'Limpieza' },
  ajuste_luz:      { emoji: '💡', label: 'Luz' },
}
function tm(t) { return TAREAS_META[t] || { emoji: '📌', label: t } }

function growLabel(g)  { return { sustrato:'Sustrato', hidroponia:'Hidroponia' }[g]||g||'—' }
function origenLabel(o){ return { semilla:'Semilla', esqueje:'Esqueje', clonacion:'Clonación' }[o]||o||'—' }
function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day:'numeric', month:'long', year:'numeric' })
}
function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' })
}

// ── Datos computados ──────────────────────────────────────
const cicloIndex = computed(() => {
  if (!planta.value) return -1
  const ciclo = CICLO_PLANTA.value
  // Si la planta ya está cosechada, la posición la marca el estado del LOTE (cosecha/manicura/curado).
  if (planta.value.state === 'cosechado') {
    return ciclo.indexOf(LOTE_A_CICLO[planta.value?.lote?.estado] || 'cosecha')
  }
  return ciclo.indexOf(planta.value.state)
})

const diasEnCiclo = computed(() => {
  if (!planta.value?.created_at) return 0
  return Math.floor((Date.now() - new Date(planta.value.created_at)) / 86400000)
})

const ultimoRegistro = computed(() => {
  return activities.value.find(a => a.activity_type === 'registro_planta') || null
})

const ultimoTrasplante = computed(() =>
  activities.value.find(a => a.activity_type === 'transplant') || null
)

const macetaActual = computed(() => {
  if (ultimoTrasplante.value?.metadata?.maceta_destino_l) return ultimoTrasplante.value.metadata.maceta_destino_l
  return planta.value?.lote?.tamanio_maceta || null
})

const alturaActual = computed(() => {
  const r = ultimoRegistro.value
  return r?.metadata?.altura_cm || planta.value?.altura_actual || null
})

// ── Acciones ──────────────────────────────────────────────
async function loadActivities() {
  loadingActs.value = true
  try {
    const { data } = await getPlantActivities(id)
    activities.value = data || []
  } catch { activities.value = [] }
  finally { loadingActs.value = false }
}

function abrirModal() {
  const last = ultimoRegistro.value?.metadata
  form.value = {
    altura_cm:    last?.altura_cm    || null,
    num_colas:    last?.num_colas    || null,
    estado_salud: last?.estado_salud || 'bueno',
    color_hojas:  last?.color_hojas  || 'verde_oscuro',
    plagas:       last?.plagas       || 'ninguna',
    deficiencias: '',
    notas:        ''
  }
  modalError.value = null
  showModal.value = true
}

async function guardarRegistro() {
  guardando.value = true; modalError.value = null
  try {
    const { data } = await createPlantActivity(id, {
      activity_type: 'registro_planta',
      description:   form.value.notas || null,
      metadata: {
        altura_cm:    form.value.altura_cm,
        num_colas:    form.value.num_colas,
        estado_salud: form.value.estado_salud,
        color_hojas:  form.value.color_hojas,
        plagas:       form.value.plagas,
        deficiencias: form.value.deficiencias,
      }
    })
    activities.value.unshift(data)
    if (plants.current) {
      plants.current.altura_actual = form.value.altura_cm
      plants.current.estado_salud  = form.value.estado_salud
    }
    showModal.value = false
  } catch(e) {
    modalError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  }
  finally { guardando.value = false }
}

function toggleFotos() {
  fotosExpanded.value = !fotosExpanded.value
}
function handleFotoUpload(event) {
  const file = event.target.files?.[0]
  if (!file) return
  fotoUploadFile.value        = file
  fotoUploadDescripcion.value = ''
  fotoUploadPreview.value     = URL.createObjectURL(file)
  showFotoUploadModal.value   = true
  event.target.value = ''
}

async function confirmarSubidaFoto() {
  if (!fotoUploadFile.value) return
  uploadingFoto.value = true
  try {
    const fd = new FormData()
    fd.append('foto', fotoUploadFile.value)
    if (fotoUploadDescripcion.value.trim()) fd.append('descripcion', fotoUploadDescripcion.value.trim())
    const { data } = await addPlantFoto(planta.value.id, fd)
    if (data) fotos.value.unshift(data)
    fotosExpanded.value     = true
    showFotoUploadModal.value = false
  } catch (e) {
    toast.error(e?.response?.data?.error || 'Error al subir la foto')
  } finally {
    uploadingFoto.value = false
    fotoUploadFile.value = null
    fotoUploadPreview.value = null
  }
}

function cancelarSubidaFoto() {
  showFotoUploadModal.value   = false
  fotoUploadFile.value        = null
  fotoUploadDescripcion.value = ''
  fotoUploadPreview.value     = null
}

async function handleFotoDelete(blobId) {
  const ok = await confirm({
    title: 'Eliminar foto',
    message: '¿Seguro que querés eliminar esta foto? No se puede deshacer.',
    confirmText: 'Eliminar',
  })
  if (!ok) return
  try {
    await removePlantFoto(planta.value.id, blobId)
    fotos.value = fotos.value.filter(f => f.id !== blobId)
    toast.success('Foto eliminada')
  } catch {
    toast.error('Error al eliminar la foto')
  }
}

// ── Medición sensor (EC / pH / temperatura) ──────────────
const ble = useBluelabBLE()

const showMedicionModal = ref(false)
const savingMedicion    = ref(false)
const medicionError     = ref(null)

function emptyMedicion() {
  return { ec: null, ph: null, temperatura_sustrato: null, notas: '' }
}
const medicionForm = ref(emptyMedicion())

watch(() => ble.lecturas.value.temperatura, (val) => {
  if (val != null && showMedicionModal.value) medicionForm.value.temperatura_sustrato = val
})

function abrirMedicion() {
  medicionForm.value = emptyMedicion()
  medicionError.value = null
  showMedicionModal.value = true
}

async function guardarMedicion() {
  const m = medicionForm.value
  if (!m.ec && !m.ph && !m.temperatura_sustrato) {
    medicionError.value = 'Ingresá al menos un valor (EC, pH o temperatura)'; return
  }
  savingMedicion.value = true
  medicionError.value  = null
  try {
    const meta = {}
    if (m.ec)                   meta.ec                   = parseFloat(m.ec)
    if (m.ph)                   meta.ph                   = parseFloat(m.ph)
    if (m.temperatura_sustrato) meta.temperatura_sustrato = parseFloat(m.temperatura_sustrato)
    meta.fuente = ble.conectado.value ? 'bluelab_ble' : 'manual'
    if (ble.dispositivo.value?.name) meta.dispositivo = ble.dispositivo.value.name

    const { data } = await createPlantActivity(id, {
      activity_type: 'measurement',
      description:   m.notas || null,
      metadata:      meta,
    })
    activities.value.unshift(data)
    showMedicionModal.value = false
    await ble.desconectar()
    toast.success('Medición guardada')
  } catch (e) {
    medicionError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally {
    savingMedicion.value = false }
}

// ── Trasplante ────────────────────────────────────────
const showTrasplanteModal = ref(false)
const savingTrasplante    = ref(false)
const trasplanteError     = ref(null)
const trasplanteForm      = ref({ maceta_origen_l: null, maceta_destino_l: null, notas: '' })

function abrirTrasplante() {
  trasplanteForm.value = { maceta_origen_l: macetaActual.value, maceta_destino_l: null, notas: '' }
  trasplanteError.value = null
  showTrasplanteModal.value = true
}

async function guardarTrasplante() {
  const f = trasplanteForm.value
  if (!f.maceta_destino_l || f.maceta_destino_l <= 0) {
    trasplanteError.value = 'Ingresá el tamaño de la maceta destino'; return
  }
  savingTrasplante.value = true
  trasplanteError.value  = null
  try {
    const { data } = await createPlantActivity(id, {
      activity_type: 'transplant',
      description:   f.notas || null,
      metadata: {
        maceta_origen_l:  f.maceta_origen_l  || null,
        maceta_destino_l: parseFloat(f.maceta_destino_l),
      },
    })
    activities.value.unshift(data)
    showTrasplanteModal.value = false
    toast.success('Trasplante registrado')
  } catch (e) {
    trasplanteError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally { savingTrasplante.value = false }
}

// ── Manicura weight ───────────────────────────────────
const pesoManicura    = ref(null)
const savingManicura  = ref(false)
const manicuraSaved   = ref(false)

async function saveManicura() {
  if (savingManicura.value || !pesoManicura.value) return
  savingManicura.value = true
  try {
    await updatePlant(id, { peso_seco: pesoManicura.value })
    if (plants.current) plants.current.peso_seco = pesoManicura.value
    manicuraSaved.value = true
    toast.success('Peso de manicura guardado')
  } catch {
    toast.error('Error al guardar el peso')
  } finally {
    savingManicura.value = false
  }
}

const canManicura = computed(() =>
  ['manicura', 'admin'].includes(auth.user?.role) &&
  ['en_manicura'].includes(planta.value?.lote?.estado)
)

// ── Nuevo modal registro planta ───────────────────────────
const showRegistroPlanta = ref(false)

// ── Editar planta ──────────────────────────────────────────
const showEditarPlanta = ref(false)
const editForm = ref({ nombre: '', state: '' })
const savingEditar = ref(false)

function abrirEditarPlanta() {
  editForm.value = { nombre: planta.value?.nombre || '', state: planta.value?.state || '' }
  showEditarPlanta.value = true
}

async function guardarEdicion() {
  savingEditar.value = true
  try {
    await updatePlant(id, { nombre: editForm.value.nombre, state: editForm.value.state })
    await plants.fetchOne(id)
    showEditarPlanta.value = false
    toast.success('Planta actualizada')
  } catch { toast.error('Error al guardar') } finally { savingEditar.value = false }
}

// ── Descartar planta ───────────────────────────────────────
async function descartarPlanta() {
  const ok = await confirm({
    title: 'Descartar planta',
    message: `¿Seguro que querés descartar "${planta.value?.nombre}"? Quedará marcada como descartada.`,
    confirmText: 'Descartar',
  })
  if (!ok) return
  try {
    const loteId = planta.value?.lote?.id
    await updatePlant(id, { state: 'descartada' })
    toast.success('Planta descartada')
    if (loteId) router.push({ name: 'lote-detail', params: { id: loteId } })
    else await plants.fetchOne(id)
  } catch { toast.error('Error al descartar') }
}

const registrosHoyPlanta = computed(() =>
  activities.value
    .filter(a => {
      const d = new Date(a.created_at)
      const hoy = new Date()
      return d.toDateString() === hoy.toDateString()
    })
    .map(a => a.activity_type)
)

const plantaAcciones = computed(() => {
  const items = []
  items.push({ emoji: '📋', label: 'Registrar planta', onClick: () => { showRegistroPlanta.value = true } })
  items.push({ emoji: '✏️', label: 'Editar planta',    onClick: abrirEditarPlanta })
  items.push({ divider: true })
  items.push({ emoji: '🗑️', label: 'Descartar planta', danger: true, onClick: descartarPlanta })
  return items
})

onMounted(async () => {
  try {
    await plants.fetchOne(id)

    // Manicura no accede a la vista de detalle — va al flujo de pesaje por QR
    if (auth.user?.role === 'manicura' &&
        ['en_manicura'].includes(plants.current?.lote?.estado) &&
        plants.current?.codigo_qr) {
      router.replace(`/p/${plants.current.codigo_qr}`)
      return
    }

    fotos.value = plants.current?.fotos || []
    await generarQR()
    if (plants.current?.peso_seco) pesoManicura.value = parseFloat(plants.current.peso_seco)
  } catch { error.value = 'No se pudo cargar la planta.' }
  await loadActivities()
  loading.value = false
})
</script>

<template>
  <div class="pd">

    <div v-if="loading" class="pd__loading">
      <DsSpinner />
    </div>
    <div v-else-if="error" class="pd__error">{{ error }}</div>
    <div v-else-if="!planta" class="pd__error">Planta no encontrada.</div>

    <template v-else>

      <Breadcrumb :items="[
        { label: 'Sedes', to: { name: 'sedes' } },
        ...(planta.lote?.sala?.sede ? [{ label: planta.lote.sala.sede.nombre, to: { name: 'sede-detail', params: { id: planta.lote.sala.sede.id } } }] : []),
        ...(planta.lote?.sala ? [{ label: planta.lote.sala.nombre, to: { name: 'sala-detail', params: { id: planta.lote.sala.id } } }] : []),
        ...(planta.lote ? [{ label: planta.lote.codigo, to: { name: 'lote-detail', params: { id: planta.lote.id } } }] : []),
        { label: planta.nombre || planta.codigo_qr },
      ]" />

      <!-- Hero -->
      <div class="pd__hero">
        <div class="pd__hero-left">
          <div class="pd__hero-row">
            <span class="pd__hero-emoji">{{ em(planta.state).emoji }}</span>
            <h1 class="pd__title">{{ planta.nombre || `Planta #${planta.id}` }}</h1>
            <span class="pd__estado-pill" :style="{ background: em(planta.state).bg, color: em(planta.state).color }">
              {{ em(planta.state).label }}
            </span>
            <span v-if="planta.estado_salud" class="pd__salud-pill" :style="{ color: sm(planta.estado_salud).color }">
              {{ sm(planta.estado_salud).emoji }} {{ sm(planta.estado_salud).label }}
            </span>
          </div>
          <div class="pd__hero-meta">
            <span class="pd__qr-code">{{ planta.codigo_qr }}</span>
            <span class="pd__bc-sep">·</span>
            <span>{{ planta.genetica?.nombre || '—' }}</span>
            <span class="pd__bc-sep">·</span>
            <span>Día {{ diasEnCiclo }}</span>
          </div>
        </div>
        <div v-if="auth.user?.role !== 'manicura'" class="pd__hero-actions">
          <ActionsDropdown :items="plantaAcciones" />
        </div>
      </div>

      <!-- Timeline ciclo -->
      <div class="pd__ciclo">
        <div class="pd__ciclo-track">
          <div v-for="(etapa, i) in CICLO_PLANTA" :key="etapa" class="pd__ciclo-step"
               :class="{ 'pd__ciclo-step--done': i < cicloIndex, 'pd__ciclo-step--current': i === cicloIndex, 'pd__ciclo-step--pending': i > cicloIndex }">
            <div class="pd__ciclo-dot">
              <span>{{ em(etapa).emoji }}</span>
            </div>
            <div class="pd__ciclo-label">{{ em(etapa).label }}</div>
            <div v-if="i < CICLO_PLANTA.length - 1" class="pd__ciclo-line"
                 :class="{ 'pd__ciclo-line--done': i < cicloIndex }"></div>
          </div>
        </div>
      </div>

      <!-- Manicura weight (solo rol manicura/admin en lotes elegibles) -->
      <div v-if="canManicura" class="pd__mnc">
        <div class="pd__mnc-label">
          <i class="bi bi-scissors"></i>
          Peso de manicura
        </div>
        <div class="pd__mnc-row">
          <input
            v-model.number="pesoManicura"
            type="number"
            step="0.1"
            min="0"
            class="pd__mnc-input"
            placeholder="0.0"
            @keydown.enter.prevent="saveManicura"
          />
          <span class="pd__mnc-unit">g</span>
          <button class="pd__mnc-btn" :disabled="savingManicura || !pesoManicura" @click="saveManicura">
            <DsSpinner v-if="savingManicura" :size="12" />
            <i v-else class="bi bi-check-lg"></i>
            Guardar
          </button>
        </div>
        <div v-if="planta.peso_seco" class="pd__mnc-saved">
          <i class="bi bi-check-circle-fill"></i> Guardado: {{ planta.peso_seco }}g
        </div>
      </div>

      <!-- Layout -->
      <div class="pd__layout">
        <div class="pd__main">

          <!-- Historial completo -->
          <div class="pd__section">
            <button class="pd__section-toggle" @click="historialExpanded = !historialExpanded">
              <div class="pd__stl">
                <span class="pd__s-emoji">📜</span>
                <span class="pd__s-title">Historial de la planta</span>
              </div>
              <i class="bi pd__chevron" :class="historialExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
            </button>
            <div v-show="historialExpanded" class="pd__section-body pd__section-body--flush">
              <div v-if="loadingActs" class="pd__placeholder">Cargando historial…</div>
              <EmptyState v-else-if="activities.length === 0" icon="📋" title="Sin registros todavía" compact>
                <template v-if="auth.user?.role !== 'manicura'" #actions>
                  <button class="pd__btn-outline" @click="abrirModal">Hacer primer registro</button>
                </template>
              </EmptyState>
              <div v-else class="pd__actividades">
                <div v-for="a in activities" :key="a.id" class="pd__actividad">
                  <div class="pd__act-dot"
                       :style="{
                         background: a.activity_type === 'registro_planta'       ? '#0891b2'
                                   : a.activity_type === 'measurement'            ? '#16a34a'
                                   : a.activity_type === 'transplant'             ? '#d97706'
                                   : a.activity_type === 'registro_ambiental_lote'? '#94a3b8'
                                   : a.activity_type === 'lote_fase'              ? '#1b5e20'
                                   : a.activity_type === 'lote_actividad'         ? '#16a34a'
                                   : a.activity_type === 'lote_alerta'            ? '#dc2626'
                                   : '#64748b'
                       }">
                  </div>
                  <div class="pd__act-content">
                    <div class="pd__act-head">
                      <template v-if="a.activity_type === 'registro_planta'">
                        <div class="pd__act-titulo">
                          🌱 Registro de planta
                          <span v-if="a.metadata?.estado_salud" :style="{ color: sm(a.metadata.estado_salud).color }">
                            · {{ sm(a.metadata.estado_salud).emoji }} {{ sm(a.metadata.estado_salud).label }}
                          </span>
                          <span v-if="a.metadata?.plagas && a.metadata.plagas !== 'ninguna'"
                                :style="{ color: pgm(a.metadata.plagas).color }">
                            · {{ pgm(a.metadata.plagas).emoji }} {{ pgm(a.metadata.plagas).label }}
                          </span>
                        </div>
                        <div class="pd__act-metricas">
                          <div v-if="a.metadata?.altura_cm"   class="pd__metrica"><span>📏</span><span>{{ a.metadata.altura_cm }} cm</span></div>
                          <div v-if="a.metadata?.num_colas"   class="pd__metrica"><span>🌿</span><span>{{ a.metadata.num_colas }} copas</span></div>
                          <div v-if="a.metadata?.color_hojas" class="pd__metrica">
                            <span>{{ chm(a.metadata.color_hojas).emoji }}</span>
                            <span>{{ chm(a.metadata.color_hojas).label }}</span>
                          </div>
                        </div>
                        <div v-if="a.metadata?.deficiencias" class="pd__act-desc">
                          <strong>Deficiencias:</strong> {{ a.metadata.deficiencias }}
                        </div>
                        <div v-if="a.description" class="pd__act-desc">{{ a.description }}</div>
                      </template>
                      <template v-else-if="a.activity_type === 'measurement'">
                        <div class="pd__act-titulo">
                          🔬 Medición sensor
                          <span v-if="a.metadata?.fuente === 'bluelab_ble'" class="pd__act-ble-badge">BLE</span>
                        </div>
                        <div class="pd__act-metricas">
                          <div v-if="a.metadata?.ec"                   class="pd__metrica pd__metrica--sensor"><span>⚡</span><span>EC {{ a.metadata.ec }} mS/cm</span></div>
                          <div v-if="a.metadata?.ph"                   class="pd__metrica pd__metrica--sensor"><span>🧪</span><span>pH {{ a.metadata.ph }}</span></div>
                          <div v-if="a.metadata?.temperatura_sustrato" class="pd__metrica pd__metrica--sensor"><span>🌡️</span><span>{{ a.metadata.temperatura_sustrato }}°C sustrato</span></div>
                        </div>
                        <div v-if="a.description" class="pd__act-desc">{{ a.description }}</div>
                      </template>
                      <template v-else-if="a.activity_type === 'transplant'">
                        <div class="pd__act-titulo">🪴 Trasplante de maceta</div>
                        <div class="pd__act-metricas">
                          <div v-if="a.metadata?.maceta_origen_l" class="pd__metrica pd__metrica--trasplante">
                            <span>{{ a.metadata.maceta_origen_l }}L</span>
                            <i class="bi bi-arrow-right"></i>
                            <span>{{ a.metadata.maceta_destino_l }}L</span>
                          </div>
                          <div v-else-if="a.metadata?.maceta_destino_l" class="pd__metrica pd__metrica--trasplante">
                            <span>→ {{ a.metadata.maceta_destino_l }}L</span>
                          </div>
                        </div>
                        <div v-if="a.description" class="pd__act-desc">{{ a.description }}</div>
                      </template>
                      <template v-else-if="a.activity_type === 'registro_ambiental_lote'">
                        <div class="pd__act-titulo">
                          🌿 Registro del lote
                          <span class="pd__heredado-badge">heredado</span>
                        </div>
                        <div v-if="a.metadata?.tareas_realizadas?.length" class="pd__act-tareas">
                          <span v-for="t in a.metadata.tareas_realizadas" :key="t" class="pd__tarea-chip">
                            {{ tm(t).emoji }} {{ tm(t).label }}
                          </span>
                        </div>
                        <div class="pd__act-metricas">
                          <div v-if="a.metadata?.temperatura" class="pd__metrica"><span>🌡️</span><span>{{ a.metadata.temperatura }}°C</span></div>
                          <div v-if="a.metadata?.humedad"     class="pd__metrica"><span>💧</span><span>{{ a.metadata.humedad }}%</span></div>
                          <div v-if="a.metadata?.ph"          class="pd__metrica"><span>🧪</span><span>pH {{ a.metadata.ph }}</span></div>
                          <div v-if="a.metadata?.ec"          class="pd__metrica"><span>⚡</span><span>EC {{ a.metadata.ec }}</span></div>
                          <div v-if="a.metadata?.co2"         class="pd__metrica"><span>💨</span><span>{{ a.metadata.co2 }} ppm</span></div>
                        </div>
                        <div v-if="a.description" class="pd__act-desc">{{ a.description }}</div>
                      </template>

                      <template v-else-if="a.activity_type === 'lote_fase'">
                        <div class="pd__act-titulo">🔄 {{ a.description }}<span class="pd__heredado-badge">fase del lote</span></div>
                      </template>
                      <template v-else-if="a.activity_type === 'lote_actividad'">
                        <div class="pd__act-titulo">{{ a.description }}<span class="pd__heredado-badge">heredado</span></div>
                      </template>
                      <template v-else-if="a.activity_type === 'lote_alerta'">
                        <div class="pd__act-titulo">⚠️ {{ a.description }}</div>
                      </template>
                      <template v-else-if="a.activity_type === 'lote_nota'">
                        <div class="pd__act-titulo">📝 {{ a.description }}<span class="pd__heredado-badge">nota del lote</span></div>
                      </template>

                      <template v-else>
                        <div class="pd__act-titulo">{{ a.activity_type }} <span v-if="a.description">· {{ a.description }}</span></div>
                      </template>
                    </div>
                    <div class="pd__act-footer">
                      <span class="pd__act-usuario">{{ a.usuario }}</span>
                      <span class="pd__act-fecha">{{ formatDateTime(a.occurred_at) }}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Fotos de la planta -->
          <div class="pd__section pd__section--mt">
            <button class="pd__section-toggle" @click="toggleFotos">
              <div class="pd__stl">
                <span class="pd__s-emoji">📷</span>
                <span class="pd__s-title">Fotos de la planta</span>
                <span v-if="fotos.length > 0" class="pd__pill">{{ fotos.length }}</span>
              </div>
              <div class="pd__str">
                <button v-if="auth.user?.role !== 'manicura'" class="pd__btn-sm" @click.stop="fotoInput?.click()" :disabled="uploadingFoto">
                  <DsSpinner v-if="uploadingFoto" :size="12" />
                  <i v-else class="bi bi-camera-fill"></i>
                </button>
                <i class="bi pd__chevron" :class="fotosExpanded ? 'bi-chevron-up' : 'bi-chevron-down'"></i>
              </div>
            </button>
            <input ref="fotoInput" type="file" accept="image/*" style="display:none" @change="handleFotoUpload" />
            <div v-show="fotosExpanded" class="pd__section-body">
              <EmptyState v-if="fotos.length === 0" icon="📷" title="Sin fotos todavía" compact>
                <template v-if="auth.user?.role !== 'manicura'" #actions>
                  <button class="pd__btn-outline" @click="fotoInput?.click()"><i class="bi bi-camera-fill"></i> Subir primera foto</button>
                </template>
              </EmptyState>
              <div v-else class="pd__fotos-grid">
                <div v-for="(f, i) in fotos" :key="f.id" class="pd__foto">
                  <img :src="f.url" :alt="f.filename" class="pd__foto-img" @click="openLightbox(i)" style="cursor:pointer" />
                  <div class="pd__foto-meta">{{ f.created_at_label }}</div>
                  <div v-if="f.descripcion" class="pd__foto-desc">{{ f.descripcion }}</div>
                  <button
                    v-if="auth.user?.role !== 'manicura'"
                    class="pd__foto-del"
                    @click.stop="handleFotoDelete(f.id)"
                    title="Eliminar foto"
                  ><i class="bi bi-trash3"></i></button>
                </div>
              </div>
            </div>
          </div>

        </div>

        <!-- Aside -->
        <div class="pd__aside">

          <!-- Datos técnicos -->
          <div class="pd__card">
            <div class="pd__card-header"><span class="pd__card-title">⚙️ Datos técnicos</span></div>
            <dl class="pd__dl">
              <dt>Fecha creación</dt><dd>{{ formatDate(planta.created_at) }}</dd>
              <dt>Genética</dt><dd>{{ planta.genetica?.nombre || '—' }}</dd>
              <dt>Origen</dt><dd>{{ origenLabel(planta.origen) }}</dd>
              <dt>Tipo cultivo</dt><dd>{{ growLabel(planta.lote?.grow_type) }}</dd>
              <dt>Maceta</dt><dd>{{ macetaActual ? macetaActual + 'L' : '—' }}</dd>
              <dt>Sustrato</dt><dd>{{ planta.lote?.sustrato_especifico || '—' }}</dd>
            </dl>
          </div>

          <!-- Estado actual -->
          <div class="pd__card pd__card--mt" v-if="ultimoRegistro">
            <div class="pd__card-header"><span class="pd__card-title">📊 Último estado</span></div>
            <div class="pd__estado-card">
              <div class="pd__estado-row">
                <span class="pd__estado-label">Salud</span>
                <span :style="{ color: sm(ultimoRegistro.metadata?.estado_salud).color }">
                  {{ sm(ultimoRegistro.metadata?.estado_salud).emoji }}
                  {{ sm(ultimoRegistro.metadata?.estado_salud).label }}
                </span>
              </div>
              <div class="pd__estado-row">
                <span class="pd__estado-label">Hojas</span>
                <span>{{ chm(ultimoRegistro.metadata?.color_hojas).emoji }} {{ chm(ultimoRegistro.metadata?.color_hojas).label }}</span>
              </div>
              <div class="pd__estado-row">
                <span class="pd__estado-label">Plagas</span>
                <span :style="{ color: pgm(ultimoRegistro.metadata?.plagas).color }">
                  {{ pgm(ultimoRegistro.metadata?.plagas).emoji }} {{ pgm(ultimoRegistro.metadata?.plagas).label }}
                </span>
              </div>
              <div v-if="ultimoRegistro.metadata?.deficiencias" class="pd__estado-row">
                <span class="pd__estado-label">Deficiencias</span>
                <span class="pd__estado-val-sm">{{ ultimoRegistro.metadata.deficiencias }}</span>
              </div>
              <div class="pd__estado-fecha">
                Actualizado {{ formatDateTime(ultimoRegistro.occurred_at) }}
              </div>
            </div>
          </div>

          <!-- Peso seco si está cosechada -->
          <div v-if="planta.peso_seco" class="pd__card pd__card--mt pd__card--harvest">
            <div class="pd__card-header"><span class="pd__card-title">⚖️ Cosecha</span></div>
            <div class="pd__harvest-val">{{ planta.peso_seco }}g</div>
            <div class="pd__harvest-sub">peso seco</div>
          </div>

          <!-- QR -->
          <div v-if="auth.user?.role !== 'manicura'" class="pd__card pd__card--mt">
            <div class="pd__card-header"><span class="pd__card-title">📱 Código QR</span></div>
            <div class="pd__qr-body">
              <img v-if="qrDataUrl" :src="qrDataUrl" alt="QR" class="pd__qr-img" />
              <div v-else class="pd__qr-placeholder">Generando…</div>
              <div class="pd__qr-hint">Escaneá para acceder a esta planta</div>
              <div v-if="qrDataUrl" class="pd__qr-dd" @mouseleave="qrDropdownOpen = false">
                <button class="pd__btn-outline pd__btn-qr-dl" @click.stop="qrDropdownOpen = !qrDropdownOpen">
                  <i class="bi bi-download"></i> Descargar QR
                </button>
                <div v-if="qrDropdownOpen" class="pd__qr-dd-menu">
                  <button class="pd__qr-dd-item" @click="descargarQRsvg(); qrDropdownOpen = false">
                    <i class="bi bi-file-earmark-code"></i> SVG (impresión)
                  </button>
                  <button class="pd__qr-dd-item" @click="descargarQRpng(); qrDropdownOpen = false">
                    <i class="bi bi-file-earmark-image"></i> PNG (digital)
                  </button>
                  <div class="pd__qr-dd-sep"></div>
                  <button class="pd__qr-dd-item" @click="imprimirEtiqueta(); qrDropdownOpen = false">
                    <i class="bi bi-printer"></i> Imprimir banderita
                  </button>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>

    </template>

    <!-- ══ Modal Registro de Planta ══ -->
    <Teleport to="body">
      <div v-if="showModal" class="pd__overlay">
        <div class="pd__modal">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">🌱 Registrar planta</h3>
              <p class="pd__modal-sub">{{ planta?.nombre || planta?.codigo_qr }} · hoy {{ new Date().toLocaleDateString('es-AR') }}</p>
            </div>
            <button class="pd__modal-close" @click="showModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div v-if="modalError" class="pd__alert">{{ modalError }}</div>

            <!-- Estado de salud -->
            <div class="pd__msection">Estado general</div>
            <div class="pd__field pd__field--full">
              <div class="pd__selector">
                <button v-for="(meta, key) in SALUD_META" :key="key" type="button"
                        class="pd__sel-btn"
                        :class="{ 'pd__sel-btn--active': form.estado_salud === key }"
                        :style="form.estado_salud===key ? { borderColor:meta.color, background:meta.color+'15', color:meta.color } : {}"
                        @click="form.estado_salud = key">
                  {{ meta.emoji }} {{ meta.label }}
                </button>
              </div>
            </div>

            <!-- Métricas -->
            <div class="pd__msection">Métricas</div>
            <div class="pd__mgrid">
              <div class="pd__field">
                <label class="pd__label">Altura (cm)</label>
                <div class="pd__input-group">
                  <input type="number" step="0.5" min="0" class="pd__input" v-model.number="form.altura_cm" placeholder="45.0" />
                  <span class="pd__input-suffix">cm</span>
                </div>
              </div>
              <div class="pd__field">
                <label class="pd__label">Copas</label>
                <input type="number" min="1" step="1" class="pd__input" v-model.number="form.num_colas" placeholder="4" />
              </div>
            </div>

            <!-- Color de hojas -->
            <div class="pd__msection">Color de hojas</div>
            <div class="pd__field pd__field--full">
              <div class="pd__selector">
                <button v-for="(meta, key) in COLOR_HOJAS_META" :key="key" type="button"
                        class="pd__sel-btn"
                        :class="{ 'pd__sel-btn--active': form.color_hojas === key }"
                        :style="form.color_hojas===key ? { borderColor:'#1b5e20', background:'#e8f5e9', color:'#1b5e20' } : {}"
                        @click="form.color_hojas = key">
                  {{ meta.emoji }} {{ meta.label }}
                  <span class="pd__sel-hint">{{ meta.hint }}</span>
                </button>
              </div>
            </div>

            <!-- Plagas -->
            <div class="pd__msection">Plagas observadas</div>
            <div class="pd__field pd__field--full">
              <div class="pd__selector">
                <button v-for="(meta, key) in PLAGAS_META" :key="key" type="button"
                        class="pd__sel-btn"
                        :class="{ 'pd__sel-btn--active': form.plagas === key }"
                        :style="form.plagas===key ? { borderColor:meta.color, background:meta.color+'15', color:meta.color } : {}"
                        @click="form.plagas = key">
                  {{ meta.emoji }} {{ meta.label }}
                </button>
              </div>
            </div>

            <!-- Deficiencias -->
            <div class="pd__msection">Observaciones <span class="pd__optional">opcional</span></div>
            <div class="pd__mgrid">
              <div class="pd__field pd__field--full">
                <label class="pd__label">Deficiencias observadas</label>
                <input type="text" class="pd__input" v-model.trim="form.deficiencias"
                       placeholder="Ej: déficit de nitrógeno en hojas bajas" />
              </div>
              <div class="pd__field pd__field--full">
                <label class="pd__label">Notas libres</label>
                <textarea class="pd__input pd__textarea" rows="2" v-model.trim="form.notas"
                          placeholder="Cualquier observación relevante…"></textarea>
              </div>
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" @click="showModal = false">Cancelar</button>
            <button class="pd__btn-primary" @click="guardarRegistro" :disabled="guardando">
              <DsSpinner v-if="guardando" :size="13" />
              <i v-else class="bi bi-check-lg"></i>Guardar registro
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Medición Sensor ══ -->
    <Teleport to="body">
      <div v-if="showMedicionModal" class="pd__overlay">
        <div class="pd__modal">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">🔬 Medición de sustrato / solución</h3>
              <p class="pd__modal-sub">{{ planta?.nombre || planta?.codigo_qr }}</p>
            </div>
            <button class="pd__modal-close" @click="showMedicionModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div v-if="medicionError" class="pd__alert">{{ medicionError }}</div>

            <!-- Conexión BLE (solo si el navegador lo soporta) -->
            <template v-if="ble.soportado.value">
              <div class="pd__ble-panel" :class="{ 'pd__ble-panel--on': ble.conectado.value }">
                <div class="pd__ble-left">
                  <span class="pd__ble-icon">📡</span>
                  <div>
                    <div class="pd__ble-title">
                      <span v-if="ble.conectado.value">Conectado: {{ ble.dispositivo.value?.name || 'Sensor BLE' }}</span>
                      <span v-else>Sensor Bluelab (BLE)</span>
                    </div>
                    <div class="pd__ble-sub">
                      <span v-if="ble.conectado.value">Temperatura auto-leída. EC y pH: ingresalos desde la pantalla del sensor.</span>
                      <span v-else>Conectá el sensor para auto-leer la temperatura del sustrato.</span>
                    </div>
                  </div>
                </div>
                <div class="pd__ble-right">
                  <button v-if="!ble.conectado.value"
                          class="pd__ble-btn"
                          :disabled="ble.conectando.value"
                          @click="ble.conectar()">
                    <DsSpinner v-if="ble.conectando.value" :size="13" />
                    <i v-else class="bi bi-bluetooth"></i>
                    {{ ble.conectando.value ? 'Buscando…' : 'Conectar' }}
                  </button>
                  <button v-else class="pd__ble-btn pd__ble-btn--off" @click="ble.desconectar()">
                    <i class="bi bi-bluetooth-fill"></i> Desconectar
                  </button>
                </div>
              </div>
              <div v-if="ble.error.value" class="pd__ble-error">{{ ble.error.value }}</div>
            </template>

            <!-- Campos de medición -->
            <div class="pd__msection">Valores medidos</div>
            <div class="pd__mgrid">
              <div class="pd__field">
                <label class="pd__label">
                  EC
                  <span class="pd__label-unit">mS/cm</span>
                </label>
                <input type="number" step="0.01" min="0" max="20" class="pd__input pd__input--sensor"
                       v-model.number="medicionForm.ec" placeholder="1.80" />
              </div>
              <div class="pd__field">
                <label class="pd__label">
                  pH
                </label>
                <input type="number" step="0.01" min="0" max="14" class="pd__input pd__input--sensor"
                       v-model.number="medicionForm.ph" placeholder="6.20" />
              </div>
              <div class="pd__field pd__field--full">
                <label class="pd__label">
                  Temperatura sustrato
                  <span class="pd__label-unit">°C</span>
                  <span v-if="ble.conectado.value && medicionForm.temperatura_sustrato" class="pd__label-ble">auto ↑</span>
                </label>
                <input type="number" step="0.1" min="0" max="40" class="pd__input pd__input--sensor"
                       v-model.number="medicionForm.temperatura_sustrato" placeholder="22.0" />
              </div>
            </div>

            <!-- Rangos de referencia -->
            <div class="pd__ref-grid">
              <div class="pd__ref-item">
                <span class="pd__ref-label">EC vegetativo</span>
                <span class="pd__ref-val">0.8 – 1.2 mS/cm</span>
              </div>
              <div class="pd__ref-item">
                <span class="pd__ref-label">EC floración</span>
                <span class="pd__ref-val">1.4 – 2.0 mS/cm</span>
              </div>
              <div class="pd__ref-item">
                <span class="pd__ref-label">pH óptimo</span>
                <span class="pd__ref-val">6.0 – 7.0</span>
              </div>
              <div class="pd__ref-item">
                <span class="pd__ref-label">Temp. sustrato</span>
                <span class="pd__ref-val">18 – 24°C</span>
              </div>
            </div>

            <div class="pd__field">
              <label class="pd__label">Notas <span class="pd__optional">opcional</span></label>
              <input type="text" class="pd__input" v-model.trim="medicionForm.notas"
                     placeholder="Ej: runoff post-riego, día 21 floración…" />
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" @click="showMedicionModal = false; ble.desconectar()">Cancelar</button>
            <button class="pd__btn-primary" @click="guardarMedicion" :disabled="savingMedicion">
              <DsSpinner v-if="savingMedicion" :size="13" />
              <i v-else class="bi bi-check-lg"></i>Guardar medición
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal Trasplante ══ -->
    <Teleport to="body">
      <div v-if="showTrasplanteModal" class="pd__overlay">
        <div class="pd__modal">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">🪴 Registrar trasplante</h3>
              <p class="pd__modal-sub">{{ planta?.nombre || planta?.codigo_qr }}</p>
            </div>
            <button class="pd__modal-close" @click="showTrasplanteModal = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div v-if="trasplanteError" class="pd__alert">{{ trasplanteError }}</div>

            <div class="pd__msection">Cambio de maceta</div>
            <div class="pd__mgrid">
              <div class="pd__field">
                <label class="pd__label">Maceta actual <span class="pd__label-unit">litros</span></label>
                <div v-if="trasplanteForm.maceta_origen_l" class="pd__trasplante-current">
                  <span class="pd__trasplante-current-val">{{ trasplanteForm.maceta_origen_l }}L</span>
                </div>
                <div v-else class="pd__input-group">
                  <input type="number" step="0.5" min="0" class="pd__input"
                         v-model.number="trasplanteForm.maceta_origen_l" placeholder="Ej: 7" />
                  <span class="pd__input-suffix">L</span>
                </div>
              </div>
              <div class="pd__field">
                <label class="pd__label">Maceta destino <span class="pd__label-unit">litros</span> <span class="pd__req">*</span></label>
                <div class="pd__input-group">
                  <input type="number" step="0.5" min="0.5" class="pd__input"
                         v-model.number="trasplanteForm.maceta_destino_l" placeholder="Ej: 11" autofocus />
                  <span class="pd__input-suffix">L</span>
                </div>
              </div>
            </div>

            <div v-if="trasplanteForm.maceta_origen_l && trasplanteForm.maceta_destino_l" class="pd__trasplante-preview">
              <span class="pd__tp-val">{{ trasplanteForm.maceta_origen_l }}L</span>
              <i class="bi bi-arrow-right pd__tp-arrow"></i>
              <span class="pd__tp-val pd__tp-val--dest">{{ trasplanteForm.maceta_destino_l }}L</span>
            </div>

            <div class="pd__msection">Notas <span class="pd__optional">opcional</span></div>
            <div class="pd__field pd__field--full">
              <textarea class="pd__input pd__textarea" rows="2" v-model.trim="trasplanteForm.notas"
                        placeholder="Ej: se mudó a maceta definitiva, sustrato nuevo…"></textarea>
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" @click="showTrasplanteModal = false">Cancelar</button>
            <button class="pd__btn-primary" @click="guardarTrasplante" :disabled="savingTrasplante">
              <DsSpinner v-if="savingTrasplante" :size="13" />
              <i v-else class="bi bi-check-lg"></i>Guardar trasplante
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ Modal subir foto ══ -->
    <Teleport to="body">
      <div v-if="showFotoUploadModal" class="pd__overlay">
        <div class="pd__modal pd__modal--foto">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">📷 Subir foto</h3>
              <p class="pd__modal-sub">{{ planta?.nombre || planta?.codigo_qr }}</p>
            </div>
            <button class="pd__modal-close" @click="cancelarSubidaFoto"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div v-if="fotoUploadPreview" class="pd__foto-preview-wrap">
              <img :src="fotoUploadPreview" class="pd__foto-preview-img" alt="preview" />
            </div>
            <div class="pd__field pd__field--full" style="margin-top:.75rem">
              <label class="pd__label">Descripción <span class="pd__optional">opcional</span></label>
              <input
                type="text"
                class="pd__input"
                v-model.trim="fotoUploadDescripcion"
                placeholder="Ej: Día 14 floración, vista superior"
                maxlength="200"
                autofocus
                @keydown.enter.prevent="confirmarSubidaFoto"
                @keydown.esc.prevent="cancelarSubidaFoto"
              />
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" @click="cancelarSubidaFoto">Cancelar</button>
            <button class="pd__btn-primary" @click="confirmarSubidaFoto" :disabled="uploadingFoto">
              <DsSpinner v-if="uploadingFoto" :size="13" />
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

    <!-- ══ Modal Registro de Planta (nuevo) ══ -->
    <RegistroPlantaModal
      v-model="showRegistroPlanta"
      :planta="planta"
      :registros-hoy="registrosHoyPlanta"
      @saved="loadActivities"
    />

    <!-- ══ Modal Editar Planta ══ -->
    <Teleport to="body">
      <div v-if="showEditarPlanta" class="pd__overlay">
        <div class="pd__modal" style="max-width:440px">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">✏️ Editar planta</h3>
              <p class="pd__modal-sub">{{ planta?.nombre || planta?.codigo_qr }}</p>
            </div>
            <button class="pd__modal-close" @click="showEditarPlanta = false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div class="pd__msection">Nombre</div>
            <div class="pd__field pd__field--full">
              <input
                type="text"
                class="pd__input"
                v-model.trim="editForm.nombre"
                placeholder="Nombre de la planta"
                autofocus
                @keydown.enter.prevent="guardarEdicion"
                @keydown.esc.prevent="showEditarPlanta = false"
              />
            </div>

            <div class="pd__msection" style="margin-top:1rem">Estado</div>
            <div class="pd__field pd__field--full">
              <div class="pd__selector">
                <button
                  v-for="(meta, key) in ESTADO_META"
                  :key="key"
                  type="button"
                  class="pd__sel-btn"
                  :class="{ 'pd__sel-btn--active': editForm.state === key }"
                  :style="editForm.state === key ? { borderColor: meta.color, background: meta.bg, color: meta.color } : {}"
                  @click="editForm.state = key"
                >
                  {{ meta.emoji }} {{ meta.label }}
                </button>
              </div>
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" @click="showEditarPlanta = false">Cancelar</button>
            <button class="pd__btn-primary" @click="guardarEdicion" :disabled="savingEditar">
              <DsSpinner v-if="savingEditar" :size="13" />
              <i v-else class="bi bi-check-lg"></i>Guardar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.pd { padding: 1.75rem 1.5rem; max-width: 1200px; margin: 0 auto; font-family: system-ui, -apple-system, sans-serif; color: #1a1a1a; }
@media (max-width: 640px) { .pd { padding: 1rem; } }

/* Loading / Error */
.pd__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.pd__error   { padding: 1rem 1.25rem; background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; border-radius: 10px; font-size: .875rem; }

/* Breadcrumb */

/* Hero */
.pd__hero { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
.pd__hero-row { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; margin-bottom: .3rem; }
.pd__hero-emoji { font-size: 1.8rem; }
.pd__title { font-size: 1.75rem; font-weight: 800; margin: 0; letter-spacing: -.04em; }
.pd__estado-pill { font-size: .68rem; font-weight: 800; text-transform: uppercase; letter-spacing: .08em; padding: .28em .75em; border-radius: 999px; }
.pd__salud-pill  { font-size: .75rem; font-weight: 700; }
.pd__hero-meta { font-size: .82rem; color: #60725d; display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.pd__qr-code { font-family: monospace; font-size: .75rem; color: #94a3b8; }

/* Ciclo */
.pd__ciclo { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; padding: 1.1rem 1.5rem .9rem; margin-bottom: 1.5rem; overflow-x: auto; }
.pd__ciclo-track { display: flex; align-items: flex-start; min-width: 380px; }
.pd__ciclo-step  { display: flex; flex-direction: column; align-items: center; flex: 1; position: relative; }
.pd__ciclo-dot   { width: 34px; height: 34px; border-radius: 50%; background: #e8f5e9; border: 2px solid #d4e6d4; display: flex; align-items: center; justify-content: center; margin-bottom: .35rem; font-size: .85rem; position: relative; z-index: 1; transition: all .2s; }
.pd__ciclo-label { font-size: .6rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; text-align: center; }
.pd__ciclo-step--done .pd__ciclo-dot   { background: #dcfce7; border-color: #16a34a; }
.pd__ciclo-step--done .pd__ciclo-label { color: #16a34a; }
.pd__ciclo-step--current .pd__ciclo-dot { background: #1b5e20; border-color: #1b5e20; box-shadow: 0 0 0 4px rgba(27,94,32,.15); }
.pd__ciclo-step--current .pd__ciclo-label { color: #1b5e20; font-weight: 800; }
.pd__ciclo-step--pending { opacity: .4; }
.pd__ciclo-line { position: absolute; top: 16px; left: 50%; width: 100%; height: 2px; background: #d4e6d4; }
.pd__ciclo-line--done { background: #16a34a; }

/* Layout */
/* Manicura weight section */
.pd__mnc {
  display: flex; flex-direction: column; gap: .4rem;
  background: #f0fdf4; border: 1px solid #86efac;
  border-radius: 12px; padding: .875rem 1.1rem;
  margin-bottom: 1.25rem;
}
.pd__mnc-label {
  font-size: .72rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em;
  color: #15803d; display: flex; align-items: center; gap: .35rem;
}
.pd__mnc-row {
  display: flex; align-items: center; gap: .5rem;
}
.pd__mnc-input {
  width: 90px;
  background: #fff; border: 1.5px solid #86efac;
  border-radius: 8px; padding: .45rem .65rem;
  font-size: .9rem; color: #1a1a1a; text-align: right;
  outline: none; transition: border-color .15s;
}
.pd__mnc-input:focus { border-color: #16a34a; }
.pd__mnc-unit { font-size: .82rem; color: #15803d; font-weight: 600; }
.pd__mnc-btn {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #16a34a; color: #fff; border: none;
  padding: .45rem .9rem; border-radius: 8px;
  font-size: .8rem; font-weight: 600; cursor: pointer;
  transition: background .15s;
}
.pd__mnc-btn:hover:not(:disabled) { background: #15803d; }
.pd__mnc-btn:disabled { opacity: .45; cursor: not-allowed; }
.pd__mnc-saved {
  font-size: .75rem; color: #15803d; font-weight: 600;
  display: flex; align-items: center; gap: .3rem;
}

.pd__layout { display: grid; grid-template-columns: 1fr 280px; gap: 1.25rem; align-items: start; }
@media (max-width: 900px) { .pd__layout { grid-template-columns: 1fr; } }

/* Sections */
.pd__section { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.pd__section--mt { margin-top: 1.25rem; }
.pd__section-toggle { width: 100%; display: flex; align-items: center; justify-content: space-between; padding: .9rem 1.1rem; background: transparent; border: none; cursor: pointer; transition: background .15s; text-align: left; }
.pd__section-toggle:hover { background: #f0fdf4; }
.pd__stl { display: flex; align-items: center; gap: .6rem; }
.pd__str { display: flex; align-items: center; gap: .5rem; }
.pd__s-emoji { font-size: 1rem; }
.pd__s-title { font-size: .9rem; font-weight: 700; color: #1a1a1a; }
.pd__pill { background: #e8f5e9; color: #1b5e20; font-size: .68rem; font-weight: 700; padding: .15em .55em; border-radius: 999px; }
.pd__chevron { color: #60725d; font-size: .75rem; }
.pd__section-body { border-top: 1px solid #e8f0e9; padding: 1rem 1.1rem; }
.pd__section-body--flush { border-top: 1px solid #e8f0e9; padding: 0; }
.pd__placeholder { padding: 1rem 1.1rem; color: #94a3b8; font-size: .875rem; }

/* Actividades / historial */
.pd__actividades { display: flex; flex-direction: column; }
.pd__actividad   { display: flex; gap: .75rem; padding: .9rem 1.1rem; border-bottom: 1px solid #f0fdf4; }
.pd__actividad:last-child { border-bottom: none; }
.pd__act-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: .3rem; }
.pd__act-content { flex: 1; min-width: 0; }
.pd__act-head { margin-bottom: .35rem; }
.pd__act-titulo { font-size: .875rem; font-weight: 600; color: #1a1a1a; margin-bottom: .3rem; }
.pd__act-metricas { display: flex; flex-wrap: wrap; gap: .4rem; margin-bottom: .25rem; }
.pd__metrica { display: flex; align-items: center; gap: .25rem; background: #f4f8f4; border: 1px solid #d4e6d4; border-radius: 6px; padding: .2em .55em; font-size: .72rem; font-weight: 600; color: #1a1a1a; }
.pd__act-desc { font-size: .75rem; color: #60725d; font-style: italic; margin-top: .2rem; }
.pd__act-footer { display: flex; align-items: center; justify-content: space-between; margin-top: .35rem; }
.pd__act-usuario { font-size: .7rem; color: #94a3b8; }
.pd__act-fecha   { font-size: .7rem; color: #94a3b8; }

/* Fotos */
.pd__fotos-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); gap: .75rem; }
.pd__foto { border-radius: 10px; overflow: hidden; border: 1px solid #d4e6d4; position: relative; }
.pd__foto-img { width: 100%; height: 110px; object-fit: cover; display: block; }
.pd__foto-meta { font-size: .65rem; color: #94a3b8; padding: .3rem .5rem; background: #f4f8f4; text-align: center; }
.pd__foto-desc { font-size: .68rem; color: #374151; padding: .25rem .5rem .35rem; background: #f4f8f4; border-top: 1px solid #e8f0e9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pd__foto-del {
  position: absolute; top: .35rem; right: .35rem;
  width: 22px; height: 22px; border-radius: 50%;
  background: rgba(0,0,0,.55); color: #fff; border: none;
  font-size: .65rem; cursor: pointer; display: flex; align-items: center; justify-content: center;
  opacity: 0; transition: opacity .15s;
}
.pd__foto:hover .pd__foto-del { opacity: 1; }

/* Foto upload modal */
.pd__modal--foto { max-width: 400px; }
.pd__foto-preview-wrap { display: flex; justify-content: center; }
.pd__foto-preview-img { max-height: 220px; max-width: 100%; border-radius: 10px; border: 1px solid #d4e6d4; object-fit: contain; }

/* Aside */
.pd__aside {}
.pd__card { background: #fff; border: 1px solid #d4e6d4; border-radius: 14px; overflow: hidden; }
.pd__card--mt { margin-top: 1rem; }
.pd__card--harvest { border-color: #a7d7a9; border-left: 4px solid #16a34a; text-align: center; padding: 1rem; }
.pd__card-header { display: flex; align-items: center; justify-content: space-between; padding: .75rem 1rem; border-bottom: 1px solid #e8f0e9; }
.pd__card-title  { font-size: .85rem; font-weight: 700; color: #1a1a1a; }
.pd__dl { display: grid; grid-template-columns: auto 1fr; gap: .4rem .75rem; padding: .9rem 1rem; margin: 0; }
.pd__dl dt { font-size: .73rem; color: #60725d; font-weight: 500; white-space: nowrap; }
.pd__dl dd { font-size: .78rem; color: #1a1a1a; font-weight: 500; margin: 0; }
.pd__mono { font-family: monospace; font-size: .72rem; color: #94a3b8; }
.pd__estado-card { padding: .85rem 1rem; display: flex; flex-direction: column; gap: .5rem; }
.pd__estado-row  { display: flex; align-items: center; justify-content: space-between; font-size: .8rem; }
.pd__estado-label { color: #60725d; font-weight: 500; }
.pd__estado-val-sm { font-size: .72rem; color: #1a1a1a; text-align: right; max-width: 120px; }
.pd__estado-fecha { font-size: .68rem; color: #94a3b8; margin-top: .25rem; text-align: right; }
.pd__harvest-val { font-size: 2rem; font-weight: 800; color: #1b5e20; }
.pd__harvest-sub { font-size: .75rem; color: #60725d; }

/* Modal */
.pd__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 1050; padding: 1rem; backdrop-filter: blur(3px); }
.pd__modal { background: #fff; border-radius: 16px; width: 100%; max-width: 520px; max-height: 92vh; overflow-y: auto; box-shadow: 0 24px 64px rgba(27,94,32,.15); display: flex; flex-direction: column; }
.pd__modal-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.1rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9; position: sticky; top: 0; background: #fff; z-index: 1; }
.pd__modal-title  { font-size: 1rem; font-weight: 700; color: #1a1a1a; margin: 0; }
.pd__modal-sub    { font-size: .75rem; color: #60725d; margin: .2rem 0 0; }
.pd__modal-close  { background: #e8f5e9; border: none; width: 28px; height: 28px; border-radius: 7px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #60725d; transition: all .15s; flex-shrink: 0; }
.pd__modal-close:hover { background: #c8e6c9; color: #1b5e20; }
.pd__modal-body   { padding: 1.1rem 1.5rem; flex: 1; }
.pd__modal-footer { display: flex; justify-content: flex-end; gap: .75rem; padding: .9rem 1.5rem; border-top: 1px solid #e8f0e9; position: sticky; bottom: 0; background: #fff; }
.pd__msection { font-size: .7rem; font-weight: 800; color: #60725d; text-transform: uppercase; letter-spacing: .06em; margin: .9rem 0 .5rem; padding-bottom: .35rem; border-bottom: 1px solid #e8f0e9; }
.pd__mgrid { display: grid; grid-template-columns: 1fr 1fr; gap: .85rem; }
@media (max-width: 480px) { .pd__mgrid { grid-template-columns: 1fr; } }
.pd__field { display: flex; flex-direction: column; gap: .3rem; }
.pd__field--full { grid-column: 1 / -1; }
.pd__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.pd__optional { font-size: .65rem; font-weight: 400; color: #94a3b8; text-transform: none; letter-spacing: 0; }
.pd__input { background: #f4f8f4; border: 1.5px solid #d4e6d4; border-radius: 8px; padding: .55rem .8rem; font-size: .875rem; color: #1a1a1a; width: 100%; box-sizing: border-box; transition: border .15s; }
.pd__input:focus { outline: none; border-color: #1b5e20; background: #fff; }
.pd__input-group { display: flex; }
.pd__input-group .pd__input { border-radius: 8px 0 0 8px; }
.pd__input-suffix { background: #e8f5e9; border: 1.5px solid #d4e6d4; border-left: none; padding: .55rem .7rem; font-size: .8rem; font-weight: 600; color: #1b5e20; border-radius: 0 8px 8px 0; white-space: nowrap; }
.pd__textarea { resize: vertical; min-height: 56px; }
.pd__selector { display: flex; gap: .4rem; flex-wrap: wrap; }
.pd__sel-btn { display: flex; align-items: center; gap: .3rem; padding: .38rem .75rem; border: 1.5px solid #d4e6d4; border-radius: 8px; background: #f4f8f4; font-size: .78rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.pd__sel-btn:hover { border-color: #1b5e20; }
.pd__sel-btn--active { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,.08); }
.pd__sel-hint { font-size: .62rem; font-weight: 400; color: #94a3b8; }
.pd__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .9rem; border-radius: 8px; font-size: .82rem; margin-bottom: .75rem; }
/* Buttons */
.pd__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 8px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.pd__btn-primary:hover { background: #104417; }
.pd__btn-primary:disabled { opacity: .6; cursor: not-allowed; }
.pd__btn-ghost { background: transparent; color: #60725d; border: 1px solid #d4e6d4; padding: .55rem 1rem; border-radius: 8px; font-size: .875rem; font-weight: 500; cursor: pointer; transition: all .15s; }
.pd__btn-ghost:hover { background: #f0fdf4; color: #1b5e20; }
.pd__btn-outline { display: inline-flex; align-items: center; gap: .3rem; background: transparent; color: #1b5e20; border: 1.5px solid #d4e6d4; padding: .45rem 1rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.pd__btn-outline:hover { border-color: #1b5e20; background: #f0fdf4; }
.pd__btn-sm { display: inline-flex; align-items: center; gap: .3rem; background: #e8f5e9; color: #1b5e20; border: 1px solid #d4e6d4; padding: .3rem .6rem; border-radius: 7px; font-size: .75rem; font-weight: 600; cursor: pointer; transition: all .15s; }
.pd__btn-sm:hover { background: #1b5e20; color: #fff; }
.pd__qr-body { display: flex; flex-direction: column; align-items: center; gap: .6rem; padding: 1rem; }
.pd__qr-img  { width: 160px; height: 160px; border-radius: 8px; border: 1px solid #d4e6d4; }
.pd__qr-placeholder { width: 160px; height: 160px; background: #f4f8f4; border-radius: 8px; display: flex; align-items: center; justify-content: center; color: #94a3b8; font-size: .8rem; }
.pd__qr-hint { font-size: .72rem; color: #94a3b8; text-align: center; max-width: 160px; }
.pd__btn-qr-dl { width: 100%; justify-content: center; }
.pd__qr-dd { position: relative; width: 100%; }
.pd__qr-dd-menu { position: absolute; top: calc(100% + .35rem); left: 0; right: 0; background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.1); z-index: 100; padding: .3rem; display: flex; flex-direction: column; }
.pd__qr-dd-item { display: flex; align-items: center; gap: .5rem; background: none; border: none; padding: .55rem .75rem; border-radius: 7px; font-size: .8rem; color: #334155; cursor: pointer; text-align: left; transition: background .12s; }
.pd__qr-dd-item:hover { background: #f1f5f9; }
.pd__qr-dd-sep { height: 1px; background: #e2e8f0; margin: .25rem .3rem; }

/* Hero actions */
.pd__hero-actions { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }

/* Botón sensor */
/* Medición en historial */
.pd__metrica--sensor { background: #f0fdf4; border-color: #86efac; color: #15803d; }
.pd__metrica--trasplante { background: #fffbeb; border-color: #fde68a; color: #92400e; display: flex; align-items: center; gap: .35rem; }
.pd__act-ble-badge {
  font-size: .6rem; font-weight: 800; background: #dbeafe; color: #1d4ed8;
  padding: .1em .45em; border-radius: 5px; letter-spacing: .05em; text-transform: uppercase; vertical-align: middle;
}
.pd__heredado-badge {
  font-size: .6rem; font-weight: 700; background: #f1f5f9; color: #64748b;
  padding: .1em .45em; border-radius: 5px; letter-spacing: .04em; text-transform: uppercase; vertical-align: middle;
  border: 1px solid #e2e8f0;
}
.pd__act-tareas { display: flex; flex-wrap: wrap; gap: .3rem; margin: .35rem 0; }
.pd__tarea-chip {
  display: inline-flex; align-items: center; gap: .2rem;
  font-size: .7rem; font-weight: 600; background: #f1f5f9; color: #475569;
  border: 1px solid #e2e8f0; border-radius: 999px; padding: .15em .55em;
}

/* Panel BLE */
.pd__ble-panel {
  display: flex; align-items: center; justify-content: space-between; gap: .75rem;
  background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 10px; padding: .75rem 1rem; transition: all .2s;
}
.pd__ble-panel--on { background: #f0fdf4; border-color: #86efac; }
.pd__ble-left { display: flex; align-items: flex-start; gap: .6rem; flex: 1; min-width: 0; }
.pd__ble-icon { font-size: 1.2rem; flex-shrink: 0; }
.pd__ble-title { font-size: .82rem; font-weight: 700; color: #1a1a1a; }
.pd__ble-sub   { font-size: .72rem; color: #64748b; margin-top: .1rem; }
.pd__ble-right { flex-shrink: 0; }
.pd__ble-btn {
  display: inline-flex; align-items: center; gap: .35rem;
  background: #fff; border: 1.5px solid #d4e6d4; color: #15803d;
  padding: .45rem .9rem; border-radius: 8px; font-size: .8rem; font-weight: 600; cursor: pointer;
  transition: all .15s;
}
.pd__ble-btn:hover:not(:disabled) { background: #f0fdf4; border-color: #4ade80; }
.pd__ble-btn:disabled { opacity: .5; cursor: not-allowed; }
.pd__ble-btn--off { border-color: #fca5a5; color: #dc2626; }
.pd__ble-btn--off:hover { background: #fef2f2; border-color: #f87171; }
.pd__ble-error { font-size: .75rem; color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; padding: .5rem .75rem; }

/* Input sensor */
.pd__input--sensor { font-family: var(--font-mono, monospace); font-size: 1rem; font-weight: 700; text-align: right; }
.pd__label-unit { font-size: .65rem; color: #94a3b8; font-weight: 400; text-transform: none; letter-spacing: 0; margin-left: .25rem; }
.pd__label-ble  { font-size: .62rem; background: #dbeafe; color: #1d4ed8; font-weight: 700; padding: .1em .4em; border-radius: 4px; margin-left: .35rem; }

/* Trasplante modal */
.pd__trasplante-current {
  background: #f1f5f9; border: 1.5px solid #e2e8f0; border-radius: 8px;
  padding: .55rem .8rem; min-height: 38px; display: flex; align-items: center;
}
.pd__trasplante-current-val  { font-size: 1rem; font-weight: 700; color: #374151; }
.pd__trasplante-current-none { font-size: .82rem; color: #94a3b8; font-style: italic; }
.pd__req { color: #dc2626; font-weight: 700; }
.pd__trasplante-preview {
  display: flex; align-items: center; justify-content: center; gap: 1rem;
  background: #fffbeb; border: 1.5px solid #fde68a; border-radius: 10px;
  padding: .85rem 1.25rem; margin-top: .5rem;
}
.pd__tp-val { font-size: 1.4rem; font-weight: 800; color: #92400e; }
.pd__tp-val--dest { color: #1b5e20; }
.pd__tp-arrow { color: #d97706; font-size: 1.1rem; }

/* Rangos de referencia */
.pd__ref-grid {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: .4rem;
  background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .8rem;
}
.pd__ref-item { display: flex; justify-content: space-between; align-items: center; gap: .5rem; }
.pd__ref-label { font-size: .68rem; color: #64748b; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; }
.pd__ref-val   { font-size: .72rem; color: #1a1a1a; font-weight: 700; font-family: monospace; }
</style>

