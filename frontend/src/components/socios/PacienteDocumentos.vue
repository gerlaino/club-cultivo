<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  listPatientDocuments,
  uploadPatientDocument,
  createPatientDocument,
  deletePatientDocument,
  archivarDocumento,
  listDocumentTemplates,
} from '../../lib/api.js'
import { useAuthStore } from '../../stores/auth.js'

const props = defineProps({
  socioId:     { type: Number, required: true },
  socioNombre: { type: String, default: '' },
})

const auth     = useAuthStore()
const canEdit  = computed(() => ['admin', 'medico'].includes(auth.user?.role))

// ── Estado ────────────────────────────────────────────────────────────
const docs      = ref([])
const templates = ref([])
const loading   = ref(true)
const uploading = ref(false)
const saving    = ref(false)
const error     = ref(null)

// Modales
const showUpload    = ref(false)
const showTemplate  = ref(false)
const showDelete    = ref(false)
const deleteTarget  = ref(null)

// Form upload
const uploadForm = ref({ nombre: '', tipo: 'reprocann', archivo: null })
const uploadInput = ref(null)
const uploadError = ref(null)

// Form template
const templateForm = ref({ template_id: null, nombre: '' })
const templateError = ref(null)

const TIPOS = [
  { value: 'reprocann',             label: 'Autorización REPROCANN',         icon: 'bi-patch-check-fill',     color: '#15803d' },
  { value: 'consentimiento',        label: 'Consentimiento informado',        icon: 'bi-file-earmark-check',   color: '#0369a1' },
  { value: 'indicacion',            label: 'Indicación médica',               icon: 'bi-file-earmark-medical', color: '#7c3aed' },
  { value: 'declaracion_jurada',    label: 'Declaración jurada',              icon: 'bi-file-earmark-text',    color: '#b45309' },
  { value: 'historia_clinica',      label: 'Historia clínica',                icon: 'bi-journal-medical',      color: '#0891b2' },
  { value: 'otro',                  label: 'Otro',                             icon: 'bi-file-earmark',         color: '#64748b' },
]

const ESTADOS = {
  borrador:        { label: 'Borrador',           bg: '#f1f5f9', color: '#64748b' },
  pendiente_firma: { label: 'Pendiente de firma', bg: '#fffbeb', color: '#b45309' },
  firmado:         { label: 'Firmado',            bg: '#dcfce7', color: '#15803d' },
  archivado:       { label: 'Archivado',          bg: '#f1f5f9', color: '#94a3b8' },
}

function tipoMeta(tipo) { return TIPOS.find(t => t.value === tipo) || TIPOS[TIPOS.length - 1] }
function estadoMeta(estado) { return ESTADOS[estado] || ESTADOS.borrador }

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function formatDateTime(d) {
  if (!d) return '—'
  return new Date(d).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

// ── Carga ─────────────────────────────────────────────────────────────
onMounted(async () => {
  try {
    const [docsRes, templatesRes] = await Promise.all([
      listPatientDocuments(props.socioId),
      listDocumentTemplates(),
    ])
    docs.value      = docsRes.data || []
    templates.value = (templatesRes.data || []).filter(t => t.activo)
  } catch (e) {
    error.value = 'No se pudieron cargar los documentos'
  } finally {
    loading.value = false
  }
})

// ── Upload archivo ────────────────────────────────────────────────────
function abrirUpload() {
  uploadForm.value = { nombre: '', tipo: 'reprocann', archivo: null }
  uploadError.value = null
  showUpload.value = true
}

function handleFileChange(e) {
  const file = e.target.files?.[0]
  if (!file) return
  uploadForm.value.archivo = file
  if (!uploadForm.value.nombre) {
    uploadForm.value.nombre = file.name.replace(/\.[^/.]+$/, '')
  }
}

async function confirmarUpload() {
  if (!uploadForm.value.archivo) { uploadError.value = 'Seleccioná un archivo'; return }
  if (!uploadForm.value.nombre.trim()) { uploadError.value = 'El nombre es obligatorio'; return }

  uploading.value = true
  uploadError.value = null
  try {
    const fd = new FormData()
    fd.append('document[nombre]', uploadForm.value.nombre.trim())
    fd.append('document[tipo]',   uploadForm.value.tipo)
    fd.append('document[estado]', 'firmado')
    fd.append('archivo_pdf',      uploadForm.value.archivo)
    const { data } = await uploadPatientDocument(props.socioId, fd)
    docs.value.unshift(data)
    showUpload.value = false
  } catch (e) {
    uploadError.value = e?.response?.data?.errors?.join(', ') || 'Error al subir el archivo'
  } finally {
    uploading.value = false
  }
}

// ── Crear desde template ──────────────────────────────────────────────
function abrirTemplate() {
  templateForm.value = { template_id: null, nombre: '' }
  templateError.value = null
  showTemplate.value = true
}

function onTemplateSelect() {
  const t = templates.value.find(t => t.id === templateForm.value.template_id)
  if (t && !templateForm.value.nombre) {
    templateForm.value.nombre = `${t.nombre} — ${props.socioNombre}`
  }
}

async function confirmarTemplate() {
  if (!templateForm.value.template_id) { templateError.value = 'Seleccioná un template'; return }
  if (!templateForm.value.nombre.trim()) { templateError.value = 'El nombre es obligatorio'; return }

  saving.value = true
  templateError.value = null
  try {
    const { data } = await createPatientDocument(props.socioId, {
      template_id: templateForm.value.template_id,
      nombre:      templateForm.value.nombre.trim(),
      tipo:        templates.value.find(t => t.id === templateForm.value.template_id)?.tipo || 'otro',
    })
    docs.value.unshift(data)
    showTemplate.value = false
  } catch (e) {
    templateError.value = e?.response?.data?.errors?.join(', ') || 'Error al crear el documento'
  } finally {
    saving.value = false
  }
}

// ── Archivar ──────────────────────────────────────────────────────────
async function archivar(doc) {
  if (!confirm(`¿Archivar "${doc.nombre}"? Seguirá disponible pero no aparecerá en los activos.`)) return
  try {
    const { data } = await archivarDocumento(props.socioId, doc.id)
    const idx = docs.value.findIndex(d => d.id === doc.id)
    if (idx !== -1) docs.value[idx] = data
  } catch {}
}

// ── Eliminar ──────────────────────────────────────────────────────────
async function confirmarDelete() {
  try {
    await deletePatientDocument(props.socioId, deleteTarget.value.id)
    docs.value = docs.value.filter(d => d.id !== deleteTarget.value.id)
    showDelete.value = false
  } catch {}
}

// ── Computed ──────────────────────────────────────────────────────────
const docsActivos   = computed(() => docs.value.filter(d => d.estado !== 'archivado'))
const docsArchivados = computed(() => docs.value.filter(d => d.estado === 'archivado'))
const showArchivados = ref(false)
</script>

<template>
  <div class="pd">

    <!-- Header -->
    <div class="pd__header">
      <div class="pd__header-left">
        <div class="pd__header-title">Expediente documental</div>
        <div class="pd__header-sub">
          {{ docsActivos.length }} documento{{ docsActivos.length !== 1 ? 's' : '' }} activo{{ docsActivos.length !== 1 ? 's' : '' }}
        </div>
      </div>
      <div v-if="canEdit" class="pd__header-actions">
        <button class="pd__btn-secondary" @click="abrirTemplate" :disabled="!templates.length">
          <i class="bi bi-file-earmark-plus"></i>
          Desde template
          <span v-if="!templates.length" class="pd__btn-hint">Sin templates</span>
        </button>
        <button class="pd__btn-primary" @click="abrirUpload">
          <i class="bi bi-cloud-upload"></i>
          Subir archivo
        </button>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="pd__loading">
      <div class="pd__ring"></div>
      <span>Cargando documentos…</span>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="pd__alert">
      <i class="bi bi-exclamation-triangle-fill"></i> {{ error }}
    </div>

    <!-- Empty -->
    <div v-else-if="!docsActivos.length && !docsArchivados.length" class="pd__empty">
      <div class="pd__empty-icon">
        <i class="bi bi-file-earmark-medical"></i>
      </div>
      <h3 class="pd__empty-title">Sin documentos todavía</h3>
      <p class="pd__empty-desc">
        Subí el certificado REPROCANN, el consentimiento informado o cualquier
        documento clínico relevante para este paciente.
      </p>
      <div v-if="canEdit" class="pd__empty-actions">
        <button class="pd__btn-primary" @click="abrirUpload">
          <i class="bi bi-cloud-upload"></i> Subir primer documento
        </button>
      </div>
    </div>

    <!-- Lista documentos activos -->
    <div v-else>
      <div class="pd__list">
        <div
          v-for="doc in docsActivos"
          :key="doc.id"
          class="pd__doc"
        >
          <!-- Icono tipo -->
          <div class="pd__doc-icon"
               :style="{ background: tipoMeta(doc.tipo).color + '15', color: tipoMeta(doc.tipo).color }">
            <i :class="['bi', tipoMeta(doc.tipo).icon]"></i>
          </div>

          <!-- Info -->
          <div class="pd__doc-body">
            <div class="pd__doc-nombre">{{ doc.nombre }}</div>
            <div class="pd__doc-meta">
              <span class="pd__doc-tipo">{{ tipoMeta(doc.tipo).label }}</span>
              <span class="pd__meta-dot">·</span>
              <span>{{ formatDate(doc.created_at) }}</span>
              <span class="pd__meta-dot">·</span>
              <span>{{ doc.created_by?.nombre }}</span>
              <template v-if="doc.template">
                <span class="pd__meta-dot">·</span>
                <span class="pd__doc-template">
                  <i class="bi bi-layout-text-window-reverse"></i>
                  {{ doc.template.nombre }}
                </span>
              </template>
            </div>

            <!-- Firmas -->
            <div class="pd__doc-firmas" v-if="doc.firmado_paciente_at || doc.firmado_medico_at">
              <span v-if="doc.firmado_medico_at" class="pd__firma pd__firma--ok">
                <i class="bi bi-pen-fill"></i> Médico firmó {{ formatDateTime(doc.firmado_medico_at) }}
              </span>
              <span v-else class="pd__firma pd__firma--pending">
                <i class="bi bi-pen"></i> Pendiente firma médico
              </span>
              <span v-if="doc.firmado_paciente_at" class="pd__firma pd__firma--ok">
                <i class="bi bi-person-check-fill"></i> Paciente firmó {{ formatDateTime(doc.firmado_paciente_at) }}
              </span>
              <span v-else class="pd__firma pd__firma--pending">
                <i class="bi bi-person"></i> Pendiente firma paciente
              </span>
            </div>
          </div>

          <!-- Estado + acciones -->
          <div class="pd__doc-right">
            <span class="pd__estado"
                  :style="{ background: estadoMeta(doc.estado).bg, color: estadoMeta(doc.estado).color }">
              {{ estadoMeta(doc.estado).label }}
            </span>
            <div v-if="canEdit" class="pd__doc-actions">
              <button
                v-if="doc.estado !== 'archivado'"
                class="pd__action-btn"
                title="Archivar"
                @click="archivar(doc)"
              >
                <i class="bi bi-archive"></i>
              </button>
              <button
                class="pd__action-btn pd__action-btn--danger"
                title="Eliminar"
                @click="deleteTarget = doc; showDelete = true"
              >
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Archivados (colapsable) -->
      <div v-if="docsArchivados.length" class="pd__archivados">
        <button class="pd__archivados-toggle" @click="showArchivados = !showArchivados">
          <i class="bi bi-archive me-1"></i>
          {{ docsArchivados.length }} documento{{ docsArchivados.length !== 1 ? 's' : '' }} archivado{{ docsArchivados.length !== 1 ? 's' : '' }}
          <i class="bi" :class="showArchivados ? 'bi-chevron-up' : 'bi-chevron-down'" style="margin-left:.35rem"></i>
        </button>
        <div v-if="showArchivados" class="pd__list pd__list--archivados">
          <div v-for="doc in docsArchivados" :key="doc.id" class="pd__doc pd__doc--archivado">
            <div class="pd__doc-icon" style="background:#f1f5f9;color:#94a3b8">
              <i class="bi bi-archive"></i>
            </div>
            <div class="pd__doc-body">
              <div class="pd__doc-nombre" style="color:#94a3b8">{{ doc.nombre }}</div>
              <div class="pd__doc-meta">{{ formatDate(doc.created_at) }}</div>
            </div>
            <div class="pd__doc-right">
              <span class="pd__estado" style="background:#f1f5f9;color:#94a3b8">Archivado</span>
              <button v-if="canEdit" class="pd__action-btn pd__action-btn--danger" @click="deleteTarget = doc; showDelete = true">
                <i class="bi bi-trash"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ══ MODAL SUBIR ARCHIVO ══ -->
    <Teleport to="body">
      <div v-if="showUpload" class="pd__overlay" @click.self="showUpload=false">
        <div class="pd__modal">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">Subir documento</h3>
              <p class="pd__modal-sub">PDF, JPG o PNG · máx. 10MB</p>
            </div>
            <button class="pd__modal-close" @click="showUpload=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div v-if="uploadError" class="pd__alert pd__alert--sm">
              <i class="bi bi-exclamation-triangle-fill"></i> {{ uploadError }}
            </div>

            <!-- Dropzone -->
            <div
              class="pd__dropzone"
              :class="{ 'pd__dropzone--active': uploadForm.archivo }"
              @click="uploadInput?.click()"
            >
              <input
                ref="uploadInput"
                type="file"
                accept=".pdf,.jpg,.jpeg,.png"
                style="display:none"
                @change="handleFileChange"
              />
              <div v-if="!uploadForm.archivo" class="pd__dropzone-empty">
                <i class="bi bi-cloud-upload pd__dropzone-icon"></i>
                <div class="pd__dropzone-text">Hacé click para seleccionar</div>
                <div class="pd__dropzone-hint">PDF, JPG o PNG · máx. 10MB</div>
              </div>
              <div v-else class="pd__dropzone-file">
                <i class="bi bi-file-earmark-check pd__dropzone-icon" style="color:#15803d"></i>
                <div class="pd__dropzone-filename">{{ uploadForm.archivo.name }}</div>
                <div class="pd__dropzone-size">{{ (uploadForm.archivo.size / 1024).toFixed(0) }} KB</div>
              </div>
            </div>

            <!-- Nombre -->
            <div class="pd__field">
              <label class="pd__label">Nombre del documento <span class="pd__req">*</span></label>
              <input v-model.trim="uploadForm.nombre" class="pd__input" placeholder="Ej: REPROCANN Juan García 2024" />
            </div>

            <!-- Tipo -->
            <div class="pd__field">
              <label class="pd__label">Tipo de documento</label>
              <div class="pd__tipo-grid">
                <button
                  v-for="t in TIPOS"
                  :key="t.value"
                  type="button"
                  class="pd__tipo-btn"
                  :class="{ 'pd__tipo-btn--active': uploadForm.tipo === t.value }"
                  :style="uploadForm.tipo === t.value ? { borderColor: t.color, background: t.color + '12', color: t.color } : {}"
                  @click="uploadForm.tipo = t.value"
                >
                  <i :class="['bi', t.icon]"></i>
                  <span>{{ t.label }}</span>
                </button>
              </div>
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" :disabled="uploading" @click="showUpload=false">Cancelar</button>
            <button class="pd__btn-primary" :disabled="uploading || !uploadForm.archivo" @click="confirmarUpload">
              <span v-if="uploading" class="pd__spinner"></span>
              <i v-else class="bi bi-cloud-upload"></i>
              {{ uploading ? 'Subiendo…' : 'Subir documento' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL TEMPLATE ══ -->
    <Teleport to="body">
      <div v-if="showTemplate" class="pd__overlay" @click.self="showTemplate=false">
        <div class="pd__modal">
          <div class="pd__modal-header">
            <div>
              <h3 class="pd__modal-title">Crear desde template</h3>
              <p class="pd__modal-sub">Las variables se interpolan automáticamente con los datos del paciente</p>
            </div>
            <button class="pd__modal-close" @click="showTemplate=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <div v-if="templateError" class="pd__alert pd__alert--sm">
              <i class="bi bi-exclamation-triangle-fill"></i> {{ templateError }}
            </div>

            <div class="pd__field">
              <label class="pd__label">Template <span class="pd__req">*</span></label>
              <div class="pd__template-list">
                <button
                  v-for="t in templates"
                  :key="t.id"
                  type="button"
                  class="pd__template-btn"
                  :class="{ 'pd__template-btn--active': templateForm.template_id === t.id }"
                  @click="templateForm.template_id = t.id; onTemplateSelect()"
                >
                  <div class="pd__template-nombre">{{ t.nombre }}</div>
                  <div class="pd__template-meta">
                    {{ tipoMeta(t.tipo).label }}
                    <span v-if="t.requiere_firma_paciente || t.requiere_firma_medico" class="pd__template-firma">
                      · Requiere firma
                      <span v-if="t.requiere_firma_medico">médico</span>
                      <span v-if="t.requiere_firma_paciente && t.requiere_firma_medico"> y </span>
                      <span v-if="t.requiere_firma_paciente">paciente</span>
                    </span>
                  </div>
                </button>
              </div>
            </div>

            <div class="pd__field">
              <label class="pd__label">Nombre del documento <span class="pd__req">*</span></label>
              <input v-model.trim="templateForm.nombre" class="pd__input" placeholder="Ej: Consentimiento — Juan García" />
            </div>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" :disabled="saving" @click="showTemplate=false">Cancelar</button>
            <button class="pd__btn-primary" :disabled="saving || !templateForm.template_id" @click="confirmarTemplate">
              <span v-if="saving" class="pd__spinner"></span>
              <i v-else class="bi bi-file-earmark-plus"></i>
              {{ saving ? 'Creando…' : 'Crear documento' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL ELIMINAR ══ -->
    <Teleport to="body">
      <div v-if="showDelete" class="pd__overlay" @click.self="showDelete=false">
        <div class="pd__modal pd__modal--sm">
          <div class="pd__modal-header">
            <h3 class="pd__modal-title pd__modal-title--danger">Eliminar documento</h3>
            <button class="pd__modal-close" @click="showDelete=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="pd__modal-body">
            <p style="margin:0 0 .4rem">¿Eliminar <strong>{{ deleteTarget?.nombre }}</strong>?</p>
            <p style="font-size:.82rem;color:#64748b;margin:0">Esta acción no se puede deshacer.</p>
          </div>
          <div class="pd__modal-footer">
            <button class="pd__btn-ghost" @click="showDelete=false">Cancelar</button>
            <button class="pd__btn-danger" @click="confirmarDelete">
              <i class="bi bi-trash"></i> Eliminar
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.pd {
  padding: .25rem 0;
}

/* Header */
.pd__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
}
.pd__header-title {
  font-size: 1rem;
  font-weight: 800;
  color: #0f172a;
  letter-spacing: -.02em;
}
.pd__header-sub { font-size: .78rem; color: #94a3b8; margin-top: .1rem; }
.pd__header-actions { display: flex; gap: .6rem; flex-wrap: wrap; }

/* Loading */
.pd__loading {
  display: flex; align-items: center; justify-content: center;
  gap: .75rem; padding: 3rem; color: #94a3b8; font-size: .875rem;
}
.pd__ring {
  width: 20px; height: 20px;
  border: 2px solid #e2e8f0; border-top-color: #0369a1;
  border-radius: 50%; animation: pd-spin .7s linear infinite;
}
@keyframes pd-spin { to { transform: rotate(360deg); } }

/* Alert */
.pd__alert {
  background: #fef2f2; border: 1px solid #fecaca;
  color: #dc2626; padding: .75rem 1rem; border-radius: 9px;
  font-size: .85rem; margin-bottom: 1rem;
  display: flex; gap: .5rem; align-items: flex-start;
}
.pd__alert--sm { margin-bottom: 1rem; }

/* Empty */
.pd__empty {
  text-align: center; padding: 3.5rem 1rem;
  background: #fafbfc; border: 1.5px dashed #e2e8f0;
  border-radius: 14px;
}
.pd__empty-icon {
  font-size: 2.5rem; color: #cbd5e1;
  margin-bottom: .875rem; display: block;
}
.pd__empty-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0 0 .4rem; }
.pd__empty-desc  { font-size: .82rem; color: #94a3b8; margin: 0 0 1.25rem; max-width: 380px; margin-left: auto; margin-right: auto; }
.pd__empty-actions { display: flex; justify-content: center; gap: .6rem; }

/* Doc list */
.pd__list { display: flex; flex-direction: column; gap: .6rem; }
.pd__list--archivados { margin-top: .6rem; opacity: .75; }

.pd__doc {
  display: flex;
  align-items: flex-start;
  gap: .875rem;
  padding: 1rem 1.1rem;
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  transition: box-shadow .15s;
}
.pd__doc:hover { box-shadow: 0 2px 12px rgba(0,0,0,.06); }
.pd__doc--archivado { background: #fafbfc; }

.pd__doc-icon {
  width: 40px; height: 40px;
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; flex-shrink: 0;
}
.pd__doc-body { flex: 1; min-width: 0; }
.pd__doc-nombre {
  font-size: .9rem; font-weight: 700; color: #0f172a;
  margin-bottom: .25rem;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.pd__doc-meta {
  display: flex; align-items: center; gap: .35rem;
  font-size: .72rem; color: #94a3b8; flex-wrap: wrap;
}
.pd__doc-tipo { font-weight: 600; color: #475569; }
.pd__meta-dot { color: #cbd5e1; }
.pd__doc-template {
  display: inline-flex; align-items: center; gap: .25rem;
  background: #eff6ff; color: #0369a1;
  padding: .1em .45em; border-radius: 4px;
  font-size: .68rem; font-weight: 600;
}

/* Firmas */
.pd__doc-firmas {
  display: flex; gap: .5rem; flex-wrap: wrap; margin-top: .4rem;
}
.pd__firma {
  display: inline-flex; align-items: center; gap: .25rem;
  font-size: .68rem; font-weight: 600;
  padding: .15em .55em; border-radius: 5px;
}
.pd__firma--ok      { background: #dcfce7; color: #15803d; }
.pd__firma--pending { background: #fffbeb; color: #b45309; }

/* Doc right */
.pd__doc-right {
  display: flex; flex-direction: column;
  align-items: flex-end; gap: .5rem; flex-shrink: 0;
}
.pd__estado {
  font-size: .68rem; font-weight: 700;
  padding: .2em .6em; border-radius: 6px;
  white-space: nowrap;
}
.pd__doc-actions { display: flex; gap: .35rem; }
.pd__action-btn {
  width: 28px; height: 28px;
  border-radius: 7px; border: 1px solid #e2e8f0;
  background: #f8fafc; color: #64748b;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; font-size: .8rem; transition: all .15s;
}
.pd__action-btn:hover { background: #e2e8f0; color: #0f172a; }
.pd__action-btn--danger:hover { background: #fef2f2; color: #dc2626; border-color: #fecaca; }

/* Archivados toggle */
.pd__archivados { margin-top: 1.25rem; }
.pd__archivados-toggle {
  display: flex; align-items: center;
  font-size: .78rem; font-weight: 600; color: #64748b;
  background: none; border: none; cursor: pointer;
  padding: .35rem 0; transition: color .15s;
}
.pd__archivados-toggle:hover { color: #0f172a; }

/* Buttons */
.pd__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: var(--brand-primary, #1b5e20); color: #fff;
  border: none; padding: .55rem 1.1rem; border-radius: 8px;
  font-size: .82rem; font-weight: 700; cursor: pointer;
  transition: background .15s, transform .1s; white-space: nowrap;
}
.pd__btn-primary:hover:not(:disabled) { background: #144a18; transform: translateY(-1px); }
.pd__btn-primary:disabled { opacity: .5; cursor: not-allowed; }

.pd__btn-secondary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #fff; color: #0369a1;
  border: 1.5px solid #bfdbfe; padding: .55rem 1rem;
  border-radius: 8px; font-size: .82rem; font-weight: 600;
  cursor: pointer; transition: all .15s; white-space: nowrap;
  position: relative;
}
.pd__btn-secondary:hover:not(:disabled) { background: #eff6ff; }
.pd__btn-secondary:disabled { opacity: .5; cursor: not-allowed; }
.pd__btn-hint {
  position: absolute; top: -22px; left: 50%; transform: translateX(-50%);
  font-size: .65rem; background: #0f172a; color: #fff;
  padding: .2em .5em; border-radius: 4px; white-space: nowrap;
  pointer-events: none; opacity: 0; transition: opacity .15s;
}
.pd__btn-secondary:hover .pd__btn-hint { opacity: 1; }

.pd__btn-ghost {
  background: transparent; color: #64748b;
  border: 1.5px solid #e2e8f0; padding: .6rem 1.1rem;
  border-radius: 8px; font-size: .875rem; font-weight: 600;
  cursor: pointer; transition: all .15s;
}
.pd__btn-ghost:hover:not(:disabled) { background: #f8fafc; color: #0f172a; }
.pd__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }

.pd__btn-danger {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #dc2626; color: #fff; border: none;
  padding: .6rem 1.25rem; border-radius: 8px;
  font-size: .875rem; font-weight: 700; cursor: pointer;
  transition: background .15s;
}
.pd__btn-danger:hover { background: #b91c1c; }

/* Modal */
.pd__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1060; padding: 1rem; backdrop-filter: blur(3px);
}
.pd__modal {
  background: #fff; border-radius: 16px; width: 100%;
  max-width: 560px; max-height: 90vh; overflow-y: auto;
  display: flex; flex-direction: column;
  box-shadow: 0 24px 64px rgba(0,0,0,.15);
}
.pd__modal--sm { max-width: 420px; }
.pd__modal-header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; padding: 1.4rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9;
  position: sticky; top: 0; background: #fff; z-index: 1;
}
.pd__modal-title { font-size: 1.1rem; font-weight: 800; color: #0f172a; margin: 0; }
.pd__modal-title--danger { color: #dc2626; }
.pd__modal-sub { font-size: .75rem; color: #64748b; margin: .2rem 0 0; }
.pd__modal-close {
  background: #f1f5f9; border: none; width: 30px; height: 30px;
  border-radius: 8px; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  color: #64748b; flex-shrink: 0; transition: all .15s;
}
.pd__modal-close:hover { background: #e2e8f0; color: #0f172a; }
.pd__modal-body { padding: 1.25rem 1.4rem; flex: 1; display: flex; flex-direction: column; gap: 1rem; }
.pd__modal-footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9;
  position: sticky; bottom: 0; background: #fff;
}

/* Form */
.pd__field { display: flex; flex-direction: column; gap: .4rem; }
.pd__label { font-size: .75rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.pd__req { color: #dc2626; }
.pd__input {
  background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px;
  padding: .65rem .9rem; font-size: .875rem; color: #0f172a;
  width: 100%; box-sizing: border-box; transition: border .15s, box-shadow .15s;
}
.pd__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.1); background: #fff; }

/* Dropzone */
.pd__dropzone {
  border: 2px dashed #e2e8f0; border-radius: 12px;
  padding: 2rem 1rem; text-align: center;
  cursor: pointer; transition: all .2s; background: #fafbfc;
}
.pd__dropzone:hover { border-color: #1b5e20; background: #f0fdf4; }
.pd__dropzone--active { border-color: #15803d; background: #f0fdf4; border-style: solid; }
.pd__dropzone-icon { font-size: 2rem; color: #94a3b8; display: block; margin-bottom: .5rem; }
.pd__dropzone--active .pd__dropzone-icon { color: #15803d; }
.pd__dropzone-text { font-size: .875rem; font-weight: 600; color: #475569; }
.pd__dropzone-hint { font-size: .75rem; color: #94a3b8; margin-top: .25rem; }
.pd__dropzone-file { display: flex; flex-direction: column; align-items: center; gap: .25rem; }
.pd__dropzone-filename { font-size: .875rem; font-weight: 700; color: #15803d; }
.pd__dropzone-size { font-size: .72rem; color: #94a3b8; }

/* Tipo grid */
.pd__tipo-grid {
  display: grid; grid-template-columns: repeat(2, 1fr); gap: .5rem;
}
@media (max-width: 480px) { .pd__tipo-grid { grid-template-columns: 1fr; } }
.pd__tipo-btn {
  display: flex; align-items: center; gap: .5rem;
  padding: .55rem .75rem; border: 1.5px solid #e2e8f0;
  border-radius: 9px; background: #f8fafc; color: #475569;
  font-size: .78rem; font-weight: 600; cursor: pointer;
  transition: all .15s; text-align: left;
}
.pd__tipo-btn:hover { border-color: #94a3b8; background: #f1f5f9; }
.pd__tipo-btn--active { font-weight: 700; }

/* Template list */
.pd__template-list { display: flex; flex-direction: column; gap: .5rem; }
.pd__template-btn {
  padding: .75rem 1rem; border: 1.5px solid #e2e8f0;
  border-radius: 10px; background: #f8fafc; text-align: left;
  cursor: pointer; transition: all .15s; width: 100%;
}
.pd__template-btn:hover { border-color: #1b5e20; background: #f0fdf4; }
.pd__template-btn--active { border-color: #1b5e20; background: #f0fdf4; }
.pd__template-nombre { font-size: .875rem; font-weight: 700; color: #0f172a; }
.pd__template-meta { font-size: .72rem; color: #64748b; margin-top: .2rem; }
.pd__template-firma { color: #b45309; font-weight: 600; }

/* Spinner */
.pd__spinner {
  width: 14px; height: 14px;
  border: 2px solid rgba(255,255,255,.3); border-top-color: #fff;
  border-radius: 50%; animation: pd-spin .6s linear infinite; flex-shrink: 0;
}
</style>
