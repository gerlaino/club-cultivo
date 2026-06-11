<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { listGeneticas, createGenetica, updateGenetica, deleteGenetica } from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { useQRCode } from '../composables/useQRCode.js'
import { useConfirm } from '../composables/useConfirm.js'
import { useToast } from '../composables/useToast.js'
import EmptyState from '../components/ui/EmptyState.vue'
import DsSpinner from '../design-system/components/Spinner.vue'
import api from '../lib/api.js'

const router = useRouter()

const auth    = useAuthStore()
const canEdit = computed(() => auth.role === 'admin')
const { downloadPNG, downloadSVG } = useQRCode()
const { confirm } = useConfirm()
const toast = useToast()

function qrUrl(gen) {
  return `${window.location.origin}/g/${gen.slug}`
}
function qrFilename(gen, ext) {
  return `qr-genetica-${gen.slug}.${ext}`
}
async function descargarQRpng(gen) { await downloadPNG(qrUrl(gen), qrFilename(gen, 'png')) }
async function descargarQRsvg(gen) { await downloadSVG(qrUrl(gen), qrFilename(gen, 'svg')) }

const geneticas    = ref([])
const loading      = ref(true)
const saving       = ref(false)
const deleting     = ref(false)
const error        = ref(null)
const showModal    = ref(false)
const editingId    = ref(null)
const editingInase = ref(false)
const formError    = ref(null)
const qrOpenId     = ref(null)

const search            = ref('')
const filterTipo        = ref('')
const filterOrigen      = ref('')  // '' | 'inase' | 'propias'
const filterDisponible  = ref(true) // true = solo disponibles (default), false = todas
const sortBy            = ref('inase_first')

// Foto
const fotoFile     = ref(null)
const fotoPreview  = ref(null)
const fotoInput    = ref(null)

const TIPO_META = {
  indica:    { label: 'Índica',    color: '#6f42c1', bg: 'rgba(111,66,193,.12)' },
  sativa:    { label: 'Sativa',    color: '#198754', bg: 'rgba(25,135,84,.12)'  },
  hibrida:   { label: 'Híbrida',   color: '#fd7e14', bg: 'rgba(253,126,20,.12)' },
  ruderalis: { label: 'Ruderalis', color: '#0dcaf0', bg: 'rgba(13,202,240,.12)' },
}
function tipoMeta(tipo) { return TIPO_META[tipo] || { label: tipo || '—', color: '#6c757d', bg: 'rgba(108,117,125,.1)' } }

const DIFICULTAD_META = {
  facil:   { label: 'Fácil',   icon: '🟢' },
  media:   { label: 'Media',   icon: '🟡' },
  dificil: { label: 'Difícil', icon: '🔴' },
}
function difLabel(d) { return DIFICULTAD_META[d]?.label || '—' }
function difIcon(d)  { return DIFICULTAD_META[d]?.icon  || '' }

const kpis = computed(() => ({
  total:   geneticas.value.length,
  inase:   geneticas.value.filter(g => g.registrada_inase).length,
  indica:  geneticas.value.filter(g => g.tipo === 'indica').length,
  sativa:  geneticas.value.filter(g => g.tipo === 'sativa').length,
  hibrida: geneticas.value.filter(g => g.tipo === 'hibrida').length,
  plantas: geneticas.value.reduce((a, g) => a + (g.plantas_count || 0), 0),
}))

const filtered = computed(() => {
  let list = [...geneticas.value]
  if (filterDisponible.value) list = list.filter(g => g.disponible)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(g =>
      g.nombre?.toLowerCase().includes(q) ||
      g.origen?.toLowerCase().includes(q) ||
      g.descripcion?.toLowerCase().includes(q) ||
      g.criador?.toLowerCase().includes(q)
    )
  }
  if (filterTipo.value) list = list.filter(g => g.tipo === filterTipo.value)
  if (filterOrigen.value === 'inase')   list = list.filter(g => g.registrada_inase)
  if (filterOrigen.value === 'propias') list = list.filter(g => !g.registrada_inase)
  switch (sortBy.value) {
    case 'thc_desc':     list.sort((a,b) => (b.thc||0) - (a.thc||0)); break
    case 'plantas_desc': list.sort((a,b) => (b.plantas_count||0) - (a.plantas_count||0)); break
    case 'nombre_asc':   list.sort((a,b) => (a.nombre||'').localeCompare(b.nombre||'')); break
    case 'inase_first':
    default:
      list.sort((a,b) => {
        if (b.registrada_inase !== a.registrada_inase) return b.registrada_inase ? 1 : -1
        return (a.nombre||'').localeCompare(b.nombre||'')
      })
  }
  return list
})

const hasFilters = computed(() => search.value.trim() || filterTipo.value || filterOrigen.value || !filterDisponible.value)
function clearFilters() { search.value = ''; filterTipo.value = ''; filterOrigen.value = ''; filterDisponible.value = true; sortBy.value = 'inase_first' }

function emptyForm() {
  return {
    nombre: '', tipo: '', thc: null, cbd: null,
    descripcion: '', origen: '', criador: '', terpenos: '',
    tiempo_floracion: null, rendimiento: null, altura: null,
    dificultad: '', disponible: true,
  }
}
const form       = ref(emptyForm())
const formErrors = ref({})

function validate() {
  const e = {}
  if (!form.value.nombre.trim()) e.nombre = 'El nombre es obligatorio'
  if (!form.value.tipo)          e.tipo   = 'Seleccioná un tipo'
  if (form.value.thc !== null && (form.value.thc < 0 || form.value.thc > 100)) e.thc = 'Debe ser entre 0 y 100'
  if (form.value.cbd !== null && (form.value.cbd < 0 || form.value.cbd > 100)) e.cbd = 'Debe ser entre 0 y 100'
  formErrors.value = e
  return !Object.keys(e).length
}

function onFotoChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  fotoFile.value = file
  fotoPreview.value = URL.createObjectURL(file)
}

function quitarFoto() {
  fotoFile.value    = null
  fotoPreview.value = null
  if (fotoInput.value) fotoInput.value.value = ''
}

function openCreate() {
  editingId.value    = null
  editingInase.value = false
  form.value         = emptyForm()
  formErrors.value   = {}
  formError.value    = null
  fotoFile.value     = null
  fotoPreview.value  = null
  showModal.value    = true
}

function openEdit(gen) {
  editingId.value    = gen.id
  editingInase.value = !!gen.registrada_inase
  form.value = {
    nombre:           gen.nombre           || '',
    tipo:             gen.tipo             || '',
    thc:              gen.thc              ?? null,
    cbd:              gen.cbd              ?? null,
    descripcion:      gen.descripcion      || '',
    origen:           gen.origen           || '',
    criador:          gen.criador          || '',
    terpenos:         gen.terpenos         || '',
    tiempo_floracion: gen.tiempo_floracion ?? null,
    rendimiento:      gen.rendimiento      ?? null,
    altura:           gen.altura           ?? null,
    dificultad:       gen.dificultad       || '',
    disponible:       gen.disponible       ?? true,
  }
  formErrors.value  = {}
  formError.value   = null
  fotoFile.value    = null
  fotoPreview.value = gen.foto_url || null
  showModal.value   = true
}

async function loadGeneticas() {
  loading.value = true
  error.value   = null
  try {
    const { data } = await listGeneticas()
    geneticas.value = data
  } catch (e) {
    error.value = 'No se pudieron cargar las genéticas'
  } finally {
    loading.value = false
  }
}

async function handleSubmit() {
  if (!validate()) return
  saving.value    = true
  formError.value = null
  try {
    // Usar FormData si hay foto
    let result
    if (fotoFile.value) {
      const fd = new FormData()
      const payload = { ...form.value }
      if (editingInase.value) {
        delete payload.nombre; delete payload.tipo
        delete payload.thc; delete payload.cbd; delete payload.criador
      }
      Object.entries(payload).forEach(([k, v]) => {
        if (v !== null && v !== '' && v !== undefined) fd.append(`genetica[${k}]`, v)
      })
      fd.append('foto', fotoFile.value)
      if (editingId.value) {
        result = await api.patch(`/geneticas/${editingId.value}`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      } else {
        result = await api.post('/geneticas', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      }
    } else {
      const payload = { ...form.value }
      if (editingInase.value) {
        delete payload.nombre; delete payload.tipo
        delete payload.thc; delete payload.cbd; delete payload.criador
      }
      Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
      if (editingId.value) {
        result = await updateGenetica(editingId.value, payload)
      } else {
        result = await createGenetica(payload)
      }
    }

    const savedGen = result.data
    if (editingId.value) {
      const idx = geneticas.value.findIndex(g => g.id === editingId.value)
      if (idx !== -1) geneticas.value[idx] = savedGen
    } else {
      geneticas.value.unshift(savedGen)
    }
    showModal.value = false
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally {
    saving.value = false
  }
}

async function toggleDisponible(gen) {
  try {
    const result = await updateGenetica(gen.id, { disponible: !gen.disponible })
    const idx = geneticas.value.findIndex(g => g.id === gen.id)
    if (idx !== -1) geneticas.value[idx] = result.data
  } catch {
    toast.error('Error al cambiar disponibilidad')
  }
}

async function openDelete(gen) {
  const ok = await confirm({
    title: 'Eliminar genética',
    message: `¿Seguro que querés eliminar ${gen.nombre}? Se marcará como inactiva.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  deleting.value = true
  try {
    await deleteGenetica(gen.id)
    geneticas.value = geneticas.value.filter(g => g.id !== gen.id)
    toast.success('Genética eliminada')
  } catch (e) {
    toast.error('Error al eliminar')
  } finally {
    deleting.value = false
  }
}

onMounted(loadGeneticas)
</script>

<template>
  <div class="gv">

    <!-- Header -->
    <div class="gv__header">
      <div>
        <h1 class="gv__title">Genéticas</h1>
        <p class="gv__sub">Catálogo de cepas del club</p>
      </div>
      <button v-if="canEdit" class="gv__btn-new" @click="openCreate">
        <i class="bi bi-plus-lg"></i> Nueva genética
      </button>
    </div>

    <!-- Stats row -->
    <div class="gv__stats">
      <span>🌿 <strong>{{ kpis.total }}</strong> cepas</span>
      <span>🏛️ <strong>{{ kpis.inase }}</strong> INASE</span>
      <span>💜 <strong>{{ kpis.indica }}</strong> Índica</span>
      <span>💚 <strong>{{ kpis.sativa }}</strong> Sativa</span>
      <span>🧡 <strong>{{ kpis.hibrida }}</strong> Híbrida</span>
      <span>🪴 <strong>{{ kpis.plantas }}</strong> plantas activas</span>
    </div>

    <!-- Filtros -->
    <div class="gv__filters">
      <div class="gv__filter-row gv__filter-row--top">
        <div class="gv__search-wrap">
          <i class="bi bi-search gv__search-icon"></i>
          <input v-model="search" class="gv__search" placeholder="Buscar por nombre, criador, origen…" />
        </div>
        <select v-model="sortBy" class="gv__sort">
          <option value="inase_first">INASE primero</option>
          <option value="nombre_asc">Nombre A-Z</option>
          <option value="thc_desc">Mayor THC</option>
          <option value="plantas_desc">Más plantas</option>
        </select>
        <button v-if="hasFilters" class="gv__clear" @click="clearFilters" title="Limpiar filtros">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
      <div class="gv__filter-row gv__filter-row--pills">
        <div class="gv__filter-group">
          <span class="gv__filter-label">Estado</span>
          <div class="gv__pills">
            <button class="gv__pill gv__pill--disp" :class="{ 'gv__pill--active': filterDisponible }" @click="filterDisponible = true">Disponibles</button>
            <button class="gv__pill" :class="{ 'gv__pill--active': !filterDisponible }" @click="filterDisponible = false">Todas</button>
          </div>
        </div>
        <div class="gv__filter-sep"></div>
        <div class="gv__filter-group">
          <span class="gv__filter-label">Origen</span>
          <div class="gv__pills">
            <button class="gv__pill" :class="{ 'gv__pill--active': !filterOrigen }" @click="filterOrigen = ''">Todas</button>
            <button class="gv__pill gv__pill--propias" :class="{ 'gv__pill--active': filterOrigen === 'propias' }" @click="filterOrigen = filterOrigen === 'propias' ? '' : 'propias'">Propias</button>
            <button class="gv__pill gv__pill--inase" :class="{ 'gv__pill--active': filterOrigen === 'inase' }" @click="filterOrigen = filterOrigen === 'inase' ? '' : 'inase'">🏛️ INASE</button>
          </div>
        </div>
        <div class="gv__filter-sep"></div>
        <div class="gv__filter-group">
          <span class="gv__filter-label">Tipo</span>
          <div class="gv__pills">
            <button class="gv__pill" :class="{ 'gv__pill--active': !filterTipo }" @click="filterTipo = ''">Todos</button>
            <button
              v-for="(meta, key) in TIPO_META" :key="key"
              class="gv__pill" :class="{ 'gv__pill--active': filterTipo === key }"
              @click="filterTipo = filterTipo === key ? '' : key"
            >{{ meta.label }}</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="gv__loading">
      <DsSpinner />
    </div>

    <!-- Error -->
    <div v-else-if="error" class="gv__error">{{ error }}</div>

    <!-- Empty -->
    <EmptyState
      v-else-if="!filtered.length"
      icon="🌿"
      :title="hasFilters ? 'Sin resultados' : 'No hay genéticas todavía'"
      :message="hasFilters ? 'Probá ajustando los filtros' : 'Agregá la primera cepa al catálogo'"
    >
      <template #actions>
        <button v-if="hasFilters" class="gv__btn-ghost" @click="clearFilters">Limpiar filtros</button>
        <button v-else-if="canEdit" class="gv__btn-new" @click="openCreate">Nueva genética</button>
      </template>
    </EmptyState>

    <!-- Tabla -->
    <div v-else class="gv__table-wrap">
      <table class="gen-table">
        <thead>
          <tr>
            <th>Nombre</th>
            <th title="Registrada INASE">INASE</th>
            <th>Tipo</th>
            <th>THC · CBD</th>
            <th title="Dificultad">Dif.</th>
            <th>Floración</th>
            <th>Criador</th>
            <th>🪴</th>
            <th v-if="canEdit">Disponible</th>
            <th v-if="canEdit"></th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="gen in filtered"
            :key="gen.id"
            class="gen-table__row"
            @click="router.push({ name: 'genetica-detalle', params: { id: gen.id } })"
          >
            <td>
              <span class="gen-nombre">{{ gen.nombre }}</span>
            </td>
            <td>
              <span v-if="gen.registrada_inase" class="gen-inase-col" title="Registrada en el INASE">🏛️</span>
              <span v-else class="gen-empty">—</span>
            </td>
            <td>
              <span class="gen-badge"
                :style="{ background: tipoMeta(gen.tipo).bg, color: tipoMeta(gen.tipo).color }">
                {{ tipoMeta(gen.tipo).label }}
              </span>
            </td>
            <td>
              <span class="gen-thc-cbd">
                {{ gen.thc != null ? gen.thc + '%' : '—' }} · {{ gen.cbd != null ? gen.cbd + '%' : '—' }}
              </span>
            </td>
            <td>
              <span v-if="gen.dificultad" :title="difLabel(gen.dificultad)">{{ difIcon(gen.dificultad) }}</span>
              <span v-else class="gen-empty">—</span>
            </td>
            <td>
              <span v-if="gen.tiempo_floracion" class="gen-floracion">{{ gen.tiempo_floracion }}d</span>
              <span v-else class="gen-empty">—</span>
            </td>
            <td>
              <span class="gen-criador" :title="gen.criador">{{ gen.criador ? gen.criador.slice(0, 25) + (gen.criador.length > 25 ? '…' : '') : '—' }}</span>
            </td>
            <td>
              <span :class="gen.plantas_count > 0 ? 'gen-plantas' : 'gen-empty'">{{ gen.plantas_count || 0 }}</span>
            </td>
            <td v-if="canEdit" @click.stop>
              <button
                class="gen-toggle"
                :class="gen.disponible ? 'gen-toggle--on' : 'gen-toggle--off'"
                @click="toggleDisponible(gen)"
                :title="gen.disponible ? 'Disponible — clic para desactivar' : 'Inactiva — clic para activar'"
              >{{ gen.disponible ? 'Sí' : 'No' }}</button>
            </td>
            <td v-if="canEdit" @click.stop>
              <div class="gen-actions">
                <button class="gen-edit-btn" @click="openEdit(gen)" title="Editar">
                  <i class="bi bi-pencil"></i>
                </button>
                <div v-if="gen.slug" class="gen-qrdd" :class="{ 'gen-qrdd--open': qrOpenId === gen.id }">
                  <button class="gen-edit-btn" title="QR público" @click.stop="qrOpenId = qrOpenId === gen.id ? null : gen.id">
                    <i class="bi bi-qr-code"></i>
                  </button>
                  <div v-if="qrOpenId === gen.id" class="gen-qrdd__menu" @mouseleave="qrOpenId=null">
                    <button class="gen-qrdd__item" @click="descargarQRsvg(gen); qrOpenId=null"><i class="bi bi-file-earmark-code"></i> SVG</button>
                    <button class="gen-qrdd__item" @click="descargarQRpng(gen); qrOpenId=null"><i class="bi bi-file-earmark-image"></i> PNG</button>
                    <div class="gen-qrdd__sep"></div>
                    <a :href="`/g/${gen.slug}`" target="_blank" class="gen-qrdd__item"><i class="bi bi-box-arrow-up-right"></i> Ver pública</a>
                  </div>
                </div>
                <button
                  class="gen-edit-btn gen-edit-btn--danger"
                  @click="openDelete(gen)"
                  :disabled="gen.plantas_count > 0 || !!gen.registrada_inase"
                  :title="gen.registrada_inase ? 'INASE: no eliminable' : gen.plantas_count > 0 ? 'Tiene plantas activas' : 'Eliminar'"
                >
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div class="gv__count">{{ filtered.length }} de {{ filterDisponible ? geneticas.filter(g => g.disponible).length : geneticas.length }} genéticas{{ filterDisponible ? ' disponibles' : '' }}</div>
    </div>

    <!-- ===== MODAL CREAR / EDITAR ===== -->
    <Teleport to="body">
      <div v-if="showModal" class="gv-modal-overlay" @click.self="showModal=false">
        <div class="gv-modal">
          <div class="gv-modal__header">
            <div>
              <h5 class="gv-modal__title">{{ editingId ? 'Editar genética' : 'Nueva genética' }}</h5>
              <span v-if="editingInase" class="gv-modal__subtitle">Variedad registrada en el INASE</span>
            </div>
            <button class="gv-modal__close" @click="showModal=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="gv-modal__body">

            <!-- Aviso INASE -->
            <div v-if="editingInase" class="inase-notice gv-modal__inase-notice">
              <div class="inase-notice__icon">🏛️</div>
              <div>
                <div class="inase-notice__title">Genética registrada en el INASE</div>
                <div class="inase-notice__desc">
                  Nombre, tipo, THC, CBD y criador están certificados por el INASE y no pueden modificarse
                  (Resolución 1780/2025). Podés editar disponibilidad, foto, descripción, terpenos y datos de cultivo.
                </div>
              </div>
            </div>

            <div v-if="formError" class="gv__error gv-modal__error">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ formError }}</span>
            </div>

            <div class="gv-form">

              <!-- Foto -->
              <div class="gv-form__field gv-form__field--full">
                <label class="gv-form__label">Foto de la genética</label>
                <div class="foto-uploader">
                  <div v-if="fotoPreview" class="foto-preview">
                    <img :src="fotoPreview" alt="Preview" />
                    <button type="button" class="foto-remove" @click="quitarFoto" title="Quitar foto">
                      <i class="bi bi-x-lg"></i>
                    </button>
                  </div>
                  <label v-else class="foto-placeholder" :for="`foto-input-${editingId || 'new'}`">
                    <i class="bi bi-camera" style="font-size:1.5rem;color:#94a3b8"></i>
                    <span style="font-size:.78rem;color:#94a3b8;margin-top:.25rem">Subir foto</span>
                  </label>
                  <input
                    :id="`foto-input-${editingId || 'new'}`"
                    ref="fotoInput"
                    type="file"
                    accept="image/*"
                    style="display:none"
                    @change="onFotoChange"
                  />
                </div>
              </div>

              <!-- Nombre -->
              <div class="gv-form__field gv-form__field--full">
                <label class="gv-form__label">
                  Nombre <span class="gv-form__req">*</span>
                  <span v-if="editingInase" class="field-lock-label">🔒 Protegido INASE</span>
                </label>
                <input
                  v-model.trim="form.nombre"
                  class="gv-form__input"
                  :class="{ 'gv-form__input--error': formErrors.nombre, 'field-locked': editingInase }"
                  :disabled="editingInase"
                  placeholder="Ej: OG Kush, White Widow…"
                />
                <div v-if="formErrors.nombre" class="gv-form__field-error">{{ formErrors.nombre }}</div>
              </div>

              <!-- Tipo -->
              <div class="gv-form__field">
                <label class="gv-form__label">
                  Tipo <span class="gv-form__req">*</span>
                  <span v-if="editingInase" class="field-lock-label">🔒 Protegido</span>
                </label>
                <div class="gv-form__btn-group">
                  <button
                    v-for="(meta, key) in TIPO_META" :key="key"
                    type="button"
                    class="gv-form__tipo-btn"
                    :style="form.tipo === key ? { background: meta.color, borderColor: meta.color, color: '#fff' } : {}"
                    :disabled="editingInase"
                    @click="!editingInase && (form.tipo = key)"
                  >{{ meta.label }}</button>
                </div>
                <div v-if="formErrors.tipo" class="gv-form__field-error">{{ formErrors.tipo }}</div>
              </div>

              <!-- Dificultad -->
              <div class="gv-form__field">
                <label class="gv-form__label">Dificultad de cultivo</label>
                <div class="gv-form__btn-group">
                  <button
                    v-for="(meta, key) in DIFICULTAD_META" :key="key"
                    type="button"
                    class="gv-form__tipo-btn"
                    :class="{ 'gv-form__tipo-btn--active': form.dificultad === key }"
                    @click="form.dificultad = form.dificultad === key ? '' : key"
                  >{{ meta.icon }} {{ meta.label }}</button>
                </div>
              </div>

              <!-- THC / CBD -->
              <div class="gv-form__field">
                <label class="gv-form__label">
                  THC (%) <span v-if="editingInase" class="field-lock-label">🔒</span>
                </label>
                <input
                  v-model.number="form.thc" type="number" step="0.01" min="0" max="100"
                  class="gv-form__input"
                  :class="{ 'gv-form__input--error': formErrors.thc, 'field-locked': editingInase }"
                  :disabled="editingInase" placeholder="0.0"
                />
                <div v-if="formErrors.thc" class="gv-form__field-error">{{ formErrors.thc }}</div>
              </div>
              <div class="gv-form__field">
                <label class="gv-form__label">
                  CBD (%) <span v-if="editingInase" class="field-lock-label">🔒</span>
                </label>
                <input
                  v-model.number="form.cbd" type="number" step="0.01" min="0" max="100"
                  class="gv-form__input"
                  :class="{ 'gv-form__input--error': formErrors.cbd, 'field-locked': editingInase }"
                  :disabled="editingInase" placeholder="0.0"
                />
                <div v-if="formErrors.cbd" class="gv-form__field-error">{{ formErrors.cbd }}</div>
              </div>

              <!-- Floración / Rendimiento / Altura -->
              <div class="gv-form__field">
                <label class="gv-form__label">Floración (días)</label>
                <input v-model.number="form.tiempo_floracion" type="number" min="1" class="gv-form__input" placeholder="60" />
              </div>
              <div class="gv-form__field">
                <label class="gv-form__label">Rendimiento (g)</label>
                <input v-model.number="form.rendimiento" type="number" min="0" class="gv-form__input" placeholder="450" />
              </div>
              <div class="gv-form__field">
                <label class="gv-form__label">Altura (cm)</label>
                <input v-model.number="form.altura" type="number" min="0" class="gv-form__input" placeholder="120" />
              </div>

              <!-- Criador -->
              <div class="gv-form__field gv-form__field--half">
                <label class="gv-form__label">
                  Criador / Banco
                  <span v-if="editingInase" class="field-lock-label">🔒 Protegido</span>
                </label>
                <input
                  v-model.trim="form.criador"
                  class="gv-form__input"
                  :class="{ 'field-locked': editingInase }"
                  :disabled="editingInase"
                  placeholder="Ej: Sweed Lab Seeds…"
                />
              </div>

              <!-- Origen -->
              <div class="gv-form__field gv-form__field--half">
                <label class="gv-form__label">Origen</label>
                <input v-model.trim="form.origen" class="gv-form__input" placeholder="Ej: Argentina, California…" />
              </div>

              <!-- Terpenos -->
              <div class="gv-form__field gv-form__field--full">
                <label class="gv-form__label">Terpenos</label>
                <input v-model.trim="form.terpenos" class="gv-form__input" placeholder="Ej: Mirceno, Limoneno, Cariofileno…" />
              </div>

              <!-- Disponible -->
              <div class="gv-form__field gv-form__field--full">
                <label class="gv-form__toggle">
                  <input v-model="form.disponible" type="checkbox" class="gv-form__toggle-input" />
                  <span class="gv-form__toggle-track"></span>
                  <span class="gv-form__toggle-label">Disponible para cultivo</span>
                </label>
              </div>

              <!-- Descripción -->
              <div class="gv-form__field gv-form__field--full">
                <label class="gv-form__label">Descripción</label>
                <textarea
                  v-model.trim="form.descripcion"
                  class="gv-form__input gv-form__textarea"
                  rows="3"
                  placeholder="Características, efectos, sabor, aromas…"
                ></textarea>
              </div>

            </div>
          </div>
          <div class="gv-modal__footer">
            <button class="gv__btn-ghost" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="gv__btn-new" :disabled="saving" @click="handleSubmit">
              <DsSpinner v-if="saving" :size="14" />
              {{ editingId ? 'Guardar cambios' : 'Crear genética' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>


  </div>
</template>

<style scoped>
/* Layout */
.gv { padding: 2rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .gv { padding: 1.25rem 1rem 2rem; } }

.gv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; }
.gv__title { font-size: 1.5rem; font-weight: 700; color: #0f172a; margin: 0; }
.gv__sub { font-size: .82rem; color: #64748b; margin: .15rem 0 0; }

.gv__btn-new { display: inline-flex; align-items: center; gap: .4rem; background: #1a3d2e; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.gv__btn-new:hover { background: #0f2a1e; }
.gv__btn-ghost { background: #fff; border: 1.5px solid #e2e8f0; color: #64748b; padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; cursor: pointer; }
.gv__btn-ghost:hover { background: #f8fafc; }

/* Stats row */
.gv__stats { display: flex; gap: 20px; flex-wrap: wrap; padding: .875rem 0; margin-bottom: 1rem; border-bottom: 1px solid #e5e7eb; font-size: .875rem; color: #374151; }
.gv__stats strong { font-weight: 600; }

/* Filters */
.gv__filters { display: flex; flex-direction: column; gap: .65rem; margin-bottom: 1.5rem; }
.gv__search-wrap { position: relative; flex: 1; min-width: 200px; }
.gv__search-icon { position: absolute; left: .65rem; top: 50%; transform: translateY(-50%); color: #94a3b8; font-size: .85rem; pointer-events: none; }
.gv__search { width: 100%; padding: .55rem .75rem .55rem 2rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; }
.gv__search:focus { border-color: #1a3d2e; }
.gv__pills { display: flex; gap: .3rem; flex-wrap: wrap; }
.gv__pill { background: none; border: 1.5px solid #e2e8f0; color: #6b7280; padding: .35rem .75rem; border-radius: 99px; font-size: .78rem; font-weight: 500; cursor: pointer; transition: all .15s; white-space: nowrap; }
.gv__pill:hover { border-color: #94a3b8; color: #1e293b; }
.gv__pill--active { background: #1a3d2e; border-color: #1a3d2e; color: #fff; }
.gv__sort { padding: .45rem .75rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .82rem; color: #374151; background: #fff; cursor: pointer; }
.gv__clear { background: none; border: none; color: #94a3b8; padding: .4rem; cursor: pointer; border-radius: 6px; font-size: .9rem; transition: all .15s; }
.gv__clear:hover { background: #f1f5f9; color: #475569; }
.gv__filter-row { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.gv__filter-row--top { }
.gv__filter-row--pills { flex-wrap: wrap; gap: .5rem 1.25rem; }
.gv__filter-group { display: flex; align-items: center; gap: .5rem; }
.gv__filter-label { font-size: .68rem; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: #94a3b8; white-space: nowrap; }
.gv__filter-sep { width: 1px; height: 20px; background: #e2e8f0; }
.gv__pill--propias.gv__pill--active { background: #ede9fe; color: #7c3aed; border-color: #c4b5fd; }
.gv__pill--inase.gv__pill--active  { background: #dbeafe; color: #0369a1; border-color: #93c5fd; }
.gv__pill--disp.gv__pill--active   { background: #dcfce7; color: #15803d; border-color: #86efac; }
.gen-inase-col { font-size: 1rem; }

/* Loading / error */
.gv__loading { display: flex; align-items: center; justify-content: center; min-height: calc(100vh - 56px); }
.gv__error { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: .875rem 1rem; border-radius: 10px; }

/* Table */
.gv__table-wrap { background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden; }
.gen-table { width: 100%; border-collapse: collapse; font-size: .875rem; }
.gen-table thead th { padding: 10px 12px; text-align: left; font-weight: 600; color: #6b7280; border-bottom: 2px solid #e5e7eb; white-space: nowrap; background: #fafafa; }
.gen-table tbody tr { border-bottom: 1px solid #f3f4f6; transition: background .1s; cursor: pointer; }
.gen-table tbody tr:last-child { border-bottom: none; }
.gen-table tbody tr:hover { background: #f8fafc; }
.gen-table td { padding: 10px 12px; vertical-align: middle; }

.gen-nombre { font-weight: 600; color: #1e293b; }
.gen-inase { display: inline-block; font-size: .65rem; font-weight: 700; background: rgba(27,94,32,.1); color: #1b5e20; padding: .1em .45em; border-radius: 4px; border: 1px solid rgba(27,94,32,.2); margin-left: .35rem; }
.gen-toggle {
  font-size: .72rem; font-weight: 600; padding: .2em .6em; border-radius: 5px;
  border: 1.5px solid; cursor: pointer; transition: all .15s;
}
.gen-toggle--on  { background: #f0fdf4; color: #15803d; border-color: #86efac; }
.gen-toggle--on:hover  { background: #dcfce7; }
.gen-toggle--off { background: #f8fafc; color: #94a3b8; border-color: #e2e8f0; }
.gen-toggle--off:hover { background: #f1f5f9; }
.gen-badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: .75rem; font-weight: 500; }
.gen-thc-cbd { font-family: monospace; font-size: .82rem; color: #374151; }
.gen-floracion { font-size: .82rem; color: #374151; }
.gen-criador { font-size: .82rem; color: #64748b; }
.gen-plantas { font-weight: 600; color: #1a3d2e; }
.gen-empty { color: #cbd5e1; }

.gen-actions { display: flex; align-items: center; gap: .25rem; opacity: 0; transition: opacity .15s; }
.gen-table tbody tr:hover .gen-actions { opacity: 1; }
.gen-edit-btn { background: none; border: none; cursor: pointer; padding: 5px 7px; border-radius: 6px; color: #6b7280; font-size: .875rem; transition: all .15s; }
.gen-edit-btn:hover:not(:disabled) { background: #f1f5f9; color: #1e293b; }
.gen-edit-btn--danger:hover:not(:disabled) { background: #fef2f2; color: #b91c1c; }
.gen-edit-btn:disabled { opacity: .35; cursor: not-allowed; }

.gv__count { padding: .6rem 1rem; font-size: .75rem; color: #94a3b8; border-top: 1px solid #f1f5f9; text-align: right; }

/* Responsive: mobile — ocultar columnas menos importantes */
@media (max-width: 640px) {
  .gen-table thead th:nth-child(5),
  .gen-table thead th:nth-child(6),
  .gen-table td:nth-child(5),
  .gen-table td:nth-child(6) { display: none; }
  .gen-actions { opacity: 1; }
}

/* INASE notice */
.inase-notice { display: flex; align-items: flex-start; gap: .875rem; background: rgba(27,94,32,.06); border: 1px solid rgba(27,94,32,.2); border-radius: 12px; padding: 1rem 1.1rem; }
.inase-notice__icon { font-size: 1.5rem; flex-shrink: 0; }
.inase-notice__title { font-size: .875rem; font-weight: 700; color: #1b5e20; margin-bottom: .2rem; }
.inase-notice__desc { font-size: .78rem; color: #374151; line-height: 1.55; }

.field-lock-label { font-size: .68rem; color: #9ca3af; font-weight: 400; margin-left: .25rem; }
.field-locked { background-color: #f9fafb !important; color: #9ca3af !important; cursor: not-allowed; border-color: #e5e7eb !important; }

/* Table QR dropdown */
.gen-qrdd { position: relative; }
.gen-qrdd__menu { position: absolute; right: 0; top: calc(100% + .25rem); background: #fff; border: 1.5px solid #e2e8f0; border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.1); min-width: 160px; z-index: 200; padding: .3rem; }
.gen-qrdd__item { display: flex; align-items: center; gap: .45rem; padding: .45rem .7rem; font-size: .8rem; color: #374151; cursor: pointer; border-radius: 7px; text-decoration: none; background: none; border: none; width: 100%; transition: background .1s; }
.gen-qrdd__item:hover { background: #f8fafc; }
.gen-qrdd__sep  { height: 1px; background: #f1f5f9; margin: .25rem 0; }

/* Foto uploader */
.foto-uploader { display: flex; align-items: center; gap: 1rem; }
.foto-preview { position: relative; width: 120px; height: 90px; border-radius: 10px; overflow: hidden; border: 1.5px solid #e5e7eb; }
.foto-preview img { width: 100%; height: 100%; object-fit: cover; }
.foto-remove { position: absolute; top: 4px; right: 4px; width: 22px; height: 22px; border-radius: 50%; background: rgba(0,0,0,.6); color: white; border: none; display: flex; align-items: center; justify-content: center; font-size: .65rem; cursor: pointer; }
.foto-placeholder { width: 120px; height: 90px; border-radius: 10px; border: 1.5px dashed #d1d5db; display: flex; flex-direction: column; align-items: center; justify-content: center; cursor: pointer; transition: border-color .15s; }
.foto-placeholder:hover { border-color: #1b5e20; }

/* DS Modal */
.gv-modal-overlay { position: fixed; inset: 0; background: rgba(15,23,42,.55); z-index: 1000; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.gv-modal { background: #fff; border-radius: 16px; width: 100%; max-width: 680px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.25); }
.gv-modal__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e5e7eb; flex-shrink: 0; }
.gv-modal__title    { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.gv-modal__subtitle { font-size: .78rem; color: #64748b; display: block; margin-top: .1rem; }
.gv-modal__close    { background: none; border: none; cursor: pointer; color: #94a3b8; font-size: 1rem; padding: .2rem; border-radius: 6px; transition: all .15s; flex-shrink: 0; }
.gv-modal__close:hover { background: #f1f5f9; color: #475569; }
.gv-modal__body  { overflow-y: auto; padding: 1.25rem 1.5rem; flex: 1; }
.gv-modal__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e5e7eb; flex-shrink: 0; }
.gv-modal__inase-notice { margin-bottom: 1.25rem; }
.gv-modal__error { display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }

/* Form inside modal */
.gv-form { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: .875rem; }
.gv-form__field { display: flex; flex-direction: column; gap: .3rem; }
.gv-form__field--full { grid-column: 1 / -1; }
.gv-form__field--half { grid-column: span 1; }
@media (max-width: 560px) { .gv-form { grid-template-columns: 1fr; } .gv-form__field--full, .gv-form__field--half { grid-column: 1; } }
.gv-form__label     { font-size: .8rem; font-weight: 600; color: #374151; }
.gv-form__req       { color: #dc2626; }
.gv-form__input     { padding: .5rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; width: 100%; box-sizing: border-box; }
.gv-form__input:focus { border-color: #1a3d2e; }
.gv-form__input--error { border-color: #ef4444; }
.gv-form__textarea  { resize: vertical; min-height: 80px; }
.gv-form__field-error { font-size: .75rem; color: #ef4444; }

/* Tipo / dificultad buttons */
.gv-form__btn-group  { display: flex; flex-wrap: wrap; gap: .35rem; }
.gv-form__tipo-btn   { padding: .35rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 7px; font-size: .78rem; font-weight: 500; background: #fff; color: #374151; cursor: pointer; transition: all .15s; }
.gv-form__tipo-btn:hover:not(:disabled)    { border-color: #94a3b8; }
.gv-form__tipo-btn--active { background: #1a3d2e; border-color: #1a3d2e; color: #fff; }
.gv-form__tipo-btn:disabled { opacity: .45; cursor: not-allowed; }

/* Toggle switch */
.gv-form__toggle       { display: inline-flex; align-items: center; gap: .65rem; cursor: pointer; }
.gv-form__toggle-input { position: absolute; opacity: 0; width: 0; height: 0; }
.gv-form__toggle-track {
  width: 40px; height: 22px; border-radius: 11px; background: #e2e8f0;
  position: relative; transition: background .2s; flex-shrink: 0;
}
.gv-form__toggle-track::after {
  content: ''; position: absolute; top: 3px; left: 3px;
  width: 16px; height: 16px; border-radius: 50%; background: #fff;
  transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2);
}
.gv-form__toggle-input:checked + .gv-form__toggle-track { background: #1a3d2e; }
.gv-form__toggle-input:checked + .gv-form__toggle-track::after { transform: translateX(18px); }
.gv-form__toggle-label { font-size: .875rem; color: #374151; }
</style>
