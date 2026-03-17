<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  listDocumentTemplates, getDocumentTemplate,
  createDocumentTemplate, updateDocumentTemplate, deleteDocumentTemplate
} from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()

const templates = ref([])
const loading   = ref(true)
const saving    = ref(false)
const formError = ref(null)

const showModal  = ref(false)
const showDelete = ref(false)
const editingId  = ref(null)
const deleteTarget = ref(null)

const TIPO_LABELS = {
  consentimiento_informado: 'Consentimiento Informado Bilateral',
  indicacion_medica:        'Indicación Médica',
  declaracion_jurada:       'Declaración Jurada',
  informe_semestral:        'Informe Semestral',
  carnet_vinculacion:       'Carnet de Vinculación',
  otro:                     'Otro',
}

const TIPO_META = {
  consentimiento_informado: { color: '#0d6efd', icon: '📋' },
  indicacion_medica:        { color: '#198754', icon: '🩺' },
  declaracion_jurada:       { color: '#dc3545', icon: '⚖️' },
  informe_semestral:        { color: '#6f42c1', icon: '📊' },
  carnet_vinculacion:       { color: '#fd7e14', icon: '🪪' },
  otro:                     { color: '#6c757d', icon: '📄' },
}

function tipoMeta(tipo) { return TIPO_META[tipo] || TIPO_META.otro }

const VARIABLES = [
  '{{paciente_nombre}}', '{{paciente_apellido}}', '{{paciente_dni}}',
  '{{paciente_fecha_nacimiento}}', '{{paciente_reprocann}}',
  '{{club_nombre}}', '{{club_legal_name}}', '{{club_direccion}}',
  '{{medico_nombre}}', '{{medico_dni}}',
  '{{fecha_hoy}}', '{{fecha_hoy_largo}}',
]

function emptyForm() {
  return {
    nombre:                  '',
    tipo:                    'consentimiento_informado',
    descripcion:             '',
    contenido_html:          '',
    requiere_firma_paciente: true,
    requiere_firma_medico:   true,
    activo:                  true,
  }
}
const form = ref(emptyForm())

// ── Filtro ────────────────────────────────────────────────────────────
const filterTipo = ref('')
const filtered = computed(() => {
  if (!filterTipo.value) return templates.value
  return templates.value.filter(t => t.tipo === filterTipo.value)
})

// ── CRUD ──────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const { data } = await listDocumentTemplates()
    templates.value = data
  } catch (e) {
    console.error('Error:', e)
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingId.value = null
  form.value      = emptyForm()
  formError.value = null
  showModal.value = true
}

async function openEdit(t) {
  editingId.value = t.id
  formError.value = null
  try {
    const { data } = await getDocumentTemplate(t.id)
    form.value = {
      nombre:                  data.nombre,
      tipo:                    data.tipo,
      descripcion:             data.descripcion             || '',
      contenido_html:          data.contenido_html          || '',
      requiere_firma_paciente: data.requiere_firma_paciente,
      requiere_firma_medico:   data.requiere_firma_medico,
      activo:                  data.activo,
    }
    showModal.value = true
  } catch (e) {
    console.error('Error cargando template:', e)
  }
}

function insertVariable(variable) {
  const textarea = document.getElementById('contenidoTextarea')
  if (!textarea) {
    form.value.contenido_html += variable
    return
  }
  const start = textarea.selectionStart
  const end   = textarea.selectionEnd
  const text  = form.value.contenido_html
  form.value.contenido_html = text.slice(0, start) + variable + text.slice(end)
  textarea.focus()
}

async function handleSubmit() {
  if (!form.value.nombre.trim() || !form.value.contenido_html.trim()) {
    formError.value = 'El nombre y el contenido son obligatorios'
    return
  }
  saving.value    = true
  formError.value = null
  try {
    const payload = { ...form.value }
    if (editingId.value) {
      const { data } = await updateDocumentTemplate(editingId.value, payload)
      const idx = templates.value.findIndex(t => t.id === editingId.value)
      if (idx !== -1) templates.value[idx] = data
    } else {
      const { data } = await createDocumentTemplate(payload)
      templates.value.unshift(data)
    }
    showModal.value = false
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally {
    saving.value = false
  }
}

async function handleDelete() {
  try {
    await deleteDocumentTemplate(deleteTarget.value.id)
    templates.value = templates.value.filter(t => t.id !== deleteTarget.value.id)
    showDelete.value = false
  } catch (e) {
    console.error('Error:', e)
  }
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

onMounted(load)
</script>

<template>
  <div class="container-fluid py-4 px-3 px-md-4">

    <!-- Header -->
    <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-4">
      <div>
        <h1 class="h3 fw-bold mb-0">Templates de documentos</h1>
        <p class="text-muted small mb-0">
          Plantillas reutilizables para generar documentos con firma digital por paciente
        </p>
      </div>
      <button class="btn btn-success" @click="openCreate">
        <i class="bi bi-plus-circle me-1"></i> Nuevo template
      </button>
    </div>

    <!-- Info legal -->
    <div class="alert alert-info d-flex align-items-start gap-2 mb-4 small">
      <i class="bi bi-info-circle-fill mt-1 flex-shrink-0"></i>
      <div>
        <strong>Resolución 1780/2025 — Documentos requeridos:</strong>
        Consentimiento Informado Bilateral, Indicación Médica, Declaración Jurada del paciente,
        Informe Semestral del Director Médico, Carnet de Vinculación con la ONG.
        Todos deben estar firmados digitalmente (Ley 25.506).
      </div>
    </div>

    <!-- Filtro por tipo -->
    <div class="mb-4">
      <div class="d-flex flex-wrap gap-2">
        <button
          class="btn btn-sm"
          :class="filterTipo === '' ? 'btn-dark' : 'btn-outline-secondary'"
          @click="filterTipo=''"
        >
          Todos ({{ templates.length }})
        </button>
        <button
          v-for="(label, tipo) in TIPO_LABELS" :key="tipo"
          class="btn btn-sm"
          :class="filterTipo === tipo ? 'btn-dark' : 'btn-outline-secondary'"
          @click="filterTipo = filterTipo === tipo ? '' : tipo"
        >
          {{ tipoMeta(tipo).icon }} {{ label }}
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5">
      <div class="spinner-border text-success"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!filtered.length" class="text-center py-5 text-muted">
      <div class="fs-1 mb-3">📄</div>
      <h5>{{ filterTipo ? 'Sin templates de este tipo' : 'No hay templates todavía' }}</h5>
      <p class="small mb-3">Creá el primer template para empezar a generar documentos para los pacientes</p>
      <button class="btn btn-success btn-sm" @click="openCreate">Nuevo template</button>
    </div>

    <!-- Grid -->
    <div v-else class="row g-3">
      <div v-for="t in filtered" :key="t.id" class="col-12 col-md-6 col-xl-4">
        <div class="template-card" :style="{ '--tipo-color': tipoMeta(t.tipo).color }">
          <div class="template-card__bar"></div>
          <div class="template-card__body">
            <div class="d-flex align-items-start justify-content-between gap-2 mb-2">
              <div>
                <span class="template-tipo-icon">{{ tipoMeta(t.tipo).icon }}</span>
                <span class="small fw-semibold ms-1" :style="{ color: tipoMeta(t.tipo).color }">
                  {{ TIPO_LABELS[t.tipo] }}
                </span>
              </div>
              <span v-if="!t.activo" class="badge text-bg-secondary">Inactivo</span>
            </div>

            <h6 class="fw-bold mb-1">{{ t.nombre }}</h6>
            <p v-if="t.descripcion" class="small text-muted mb-2 text-truncate-2">{{ t.descripcion }}</p>

            <div class="d-flex flex-wrap gap-2 small text-muted mb-3">
              <span v-if="t.requiere_firma_paciente">
                <i class="bi bi-pen me-1"></i>Firma paciente
              </span>
              <span v-if="t.requiere_firma_medico">
                <i class="bi bi-pen me-1"></i>Firma médico
              </span>
            </div>

            <div class="d-flex gap-2 pt-2 border-top">
              <button class="btn btn-sm btn-outline-primary flex-fill" @click="openEdit(t)">
                <i class="bi bi-pencil me-1"></i>Editar
              </button>
              <button class="btn btn-sm btn-outline-danger" @click="deleteTarget=t; showDelete=true">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== MODAL CREAR / EDITAR ===== -->
    <div v-if="showModal" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingId ? 'Editar template' : 'Nuevo template' }}</h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">

            <div v-if="formError" class="alert alert-danger d-flex align-items-center gap-2 mb-3">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ formError }}</span>
            </div>

            <div class="row g-3 mb-4">
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Nombre <span class="text-danger">*</span></label>
                <input v-model.trim="form.nombre" class="form-control" placeholder="Ej: Consentimiento Informado Bilateral v2025" />
              </div>
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Tipo</label>
                <select v-model="form.tipo" class="form-select">
                  <option v-for="(label, key) in TIPO_LABELS" :key="key" :value="key">
                    {{ tipoMeta(key).icon }} {{ label }}
                  </option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label small fw-semibold">Descripción</label>
                <input v-model.trim="form.descripcion" class="form-control" placeholder="Descripción breve del documento…" />
              </div>
              <div class="col-md-4 d-flex align-items-center gap-4">
                <div class="form-check form-switch mb-0">
                  <input v-model="form.requiere_firma_paciente" class="form-check-input" type="checkbox" id="chkFirmaPac" role="switch" />
                  <label class="form-check-label small" for="chkFirmaPac">Requiere firma paciente</label>
                </div>
              </div>
              <div class="col-md-4 d-flex align-items-center">
                <div class="form-check form-switch mb-0">
                  <input v-model="form.requiere_firma_medico" class="form-check-input" type="checkbox" id="chkFirmaMed" role="switch" />
                  <label class="form-check-label small" for="chkFirmaMed">Requiere firma médico</label>
                </div>
              </div>
              <div class="col-md-4 d-flex align-items-center">
                <div class="form-check form-switch mb-0">
                  <input v-model="form.activo" class="form-check-input" type="checkbox" id="chkActivo" role="switch" />
                  <label class="form-check-label small" for="chkActivo">Template activo</label>
                </div>
              </div>
            </div>

            <!-- Variables disponibles -->
            <div class="mb-2">
              <div class="small fw-semibold mb-1">Variables disponibles — click para insertar en el cursor:</div>
              <div class="d-flex flex-wrap gap-1">
                <button
                  v-for="v in VARIABLES" :key="v"
                  type="button"
                  class="btn btn-xs btn-outline-secondary"
                  style="font-size:.72rem; padding:.15rem .4rem"
                  @click="insertVariable(v)"
                >
                  {{ v }}
                </button>
              </div>
            </div>

            <!-- Editor -->
            <label class="form-label small fw-semibold">Contenido <span class="text-danger">*</span></label>
            <textarea
              id="contenidoTextarea"
              v-model="form.contenido_html"
              class="form-control font-monospace"
              rows="20"
              style="font-size:.82rem"
              placeholder="Escribí el contenido del template en HTML o texto plano. Las variables se reemplazarán con los datos reales del paciente al generar el documento..."
            ></textarea>

          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="btn btn-success px-4" :disabled="saving" @click="handleSubmit">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editingId ? 'Guardar cambios' : 'Crear template' }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showModal" class="modal-backdrop fade show" @click="showModal=false"></div>

    <!-- ===== MODAL ELIMINAR ===== -->
    <div v-if="showDelete" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0">
            <h5 class="modal-title text-danger">⚠️ Eliminar template</h5>
            <button class="btn-close" @click="showDelete=false"></button>
          </div>
          <div class="modal-body">
            <p>¿Seguro que querés eliminar <strong>{{ deleteTarget?.nombre }}</strong>?</p>
            <p class="text-muted small mb-0">Se marcará como inactivo. Los documentos ya generados no se verán afectados.</p>
          </div>
          <div class="modal-footer border-0">
            <button class="btn btn-outline-secondary" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger" @click="handleDelete">Eliminar</button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showDelete" class="modal-backdrop fade show" @click="showDelete=false"></div>

  </div>
</template>

<style scoped>
.template-card {
  background: white;
  border-radius: 14px;
  border: 1.5px solid rgba(0,0,0,.06);
  overflow: hidden;
  height: 100%;
  display: flex;
  flex-direction: column;
  transition: all .15s;
}
.template-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0,0,0,.09);
  border-color: var(--tipo-color);
}
.template-card__bar {
  height: 5px;
  background: var(--tipo-color);
}
.template-card__body { padding: 1rem; flex: 1; display: flex; flex-direction: column; }
.text-truncate-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
