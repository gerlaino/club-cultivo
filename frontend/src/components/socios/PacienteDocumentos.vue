<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { useAuthStore } from '../../stores/auth'
import {
  listPatientDocuments, createPatientDocument, deletePatientDocument,
  firmarDocumento, archivarDocumento, listDocumentTemplates
} from '../../lib/api.js'

const props = defineProps({ socioId: { type: Number, required: true } })
const auth  = useAuthStore()

const docs      = ref([])
const templates = ref([])
const loading   = ref(true)
const saving    = ref(false)
const formError = ref(null)

const showCreate  = ref(false)
const showViewer  = ref(false)
const showFirmar  = ref(false)
const showDelete  = ref(false)
const currentDoc  = ref(null)
const deleteTarget = ref(null)

// Firma
const canvasRef    = ref(null)
const firmante     = ref('medico')   // 'paciente' | 'medico'
const firmandoDoc  = ref(false)
let   ctx          = null
let   drawing      = false
let   lastX        = 0
let   lastY        = 0

const canEdit    = computed(() => ['admin', 'medico'].includes(auth.user?.role))
const canManage  = computed(() => auth.user?.role === 'admin')

// ── Form crear documento ──────────────────────────────────────────────
const form = ref({
  template_id:    '',
  nombre:         '',
  tipo:           'consentimiento_informado',
  contenido_html: '',
})

const TIPO_LABELS = {
  consentimiento_informado: 'Consentimiento Informado Bilateral',
  indicacion_medica:        'Indicación Médica',
  declaracion_jurada:       'Declaración Jurada',
  informe_semestral:        'Informe Semestral',
  carnet_vinculacion:       'Carnet de Vinculación',
  otro:                     'Otro',
}

const ESTADO_META = {
  borrador:         { label: 'Borrador',          color: 'secondary' },
  pendiente_firma:  { label: 'Pendiente de firma', color: 'warning'   },
  firmado:          { label: 'Firmado',            color: 'success'   },
  archivado:        { label: 'Archivado',          color: 'dark'      },
}

function estadoMeta(e) { return ESTADO_META[e] || { label: e, color: 'secondary' } }

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

// ── Cargar template al seleccionar ───────────────────────────────────
watch(() => form.value.template_id, async (id) => {
  if (!id) return
  const t = templates.value.find(t => t.id === Number(id))
  if (t) {
    form.value.nombre         = t.nombre
    form.value.tipo           = t.tipo
    form.value.contenido_html = t.contenido_html || ''
  }
})

// ── CRUD ──────────────────────────────────────────────────────────────
async function load() {
  loading.value = true
  try {
    const [docsRes, tmplRes] = await Promise.allSettled([
      listPatientDocuments(props.socioId),
      listDocumentTemplates(),
    ])
    if (docsRes.status === 'fulfilled') docs.value      = docsRes.value.data || []
    if (tmplRes.status === 'fulfilled') templates.value = tmplRes.value.data || []
  } catch (e) {
    console.error('Error cargando documentos:', e)
  } finally {
    loading.value = false
  }
}

async function crear() {
  if (!form.value.nombre.trim() || !form.value.contenido_html.trim()) {
    formError.value = 'El nombre y el contenido son obligatorios'
    return
  }
  saving.value    = true
  formError.value = null
  try {
    const payload = { ...form.value }
    if (!payload.template_id) delete payload.template_id
    const { data } = await createPatientDocument(props.socioId, payload)
    docs.value.unshift(data)
    showCreate.value = false
    resetForm()
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || 'Error al crear el documento'
  } finally {
    saving.value = false
  }
}

function resetForm() {
  form.value = { template_id: '', nombre: '', tipo: 'consentimiento_informado', contenido_html: '' }
  formError.value = null
}

function verDoc(doc) {
  currentDoc.value = doc
  showViewer.value = true
}

function abrirFirmar(doc, quien) {
  currentDoc.value = doc
  firmante.value   = quien
  showFirmar.value = true
  nextTick(() => initCanvas())
}

async function doDelete() {
  try {
    await deletePatientDocument(props.socioId, deleteTarget.value.id)
    docs.value     = docs.value.filter(d => d.id !== deleteTarget.value.id)
    showDelete.value = false
  } catch (e) {
    console.error('Error eliminando:', e)
  }
}

async function doArchivar(doc) {
  try {
    const { data } = await archivarDocumento(props.socioId, doc.id)
    const idx = docs.value.findIndex(d => d.id === doc.id)
    if (idx !== -1) docs.value[idx] = data
  } catch (e) {
    console.error('Error archivando:', e)
  }
}

// ── Canvas de firma ───────────────────────────────────────────────────
function initCanvas() {
  const canvas = canvasRef.value
  if (!canvas) return
  ctx = canvas.getContext('2d')
  ctx.strokeStyle = '#1a1a1a'
  ctx.lineWidth   = 2.5
  ctx.lineCap     = 'round'
  ctx.lineJoin    = 'round'
  clearCanvas()
}

function clearCanvas() {
  if (!ctx || !canvasRef.value) return
  ctx.clearRect(0, 0, canvasRef.value.width, canvasRef.value.height)
  ctx.fillStyle = '#f8f9fa'
  ctx.fillRect(0, 0, canvasRef.value.width, canvasRef.value.height)
}

function getPos(e) {
  const canvas = canvasRef.value
  const rect   = canvas.getBoundingClientRect()
  const scaleX = canvas.width  / rect.width
  const scaleY = canvas.height / rect.height
  const src    = e.touches ? e.touches[0] : e
  return {
    x: (src.clientX - rect.left) * scaleX,
    y: (src.clientY - rect.top)  * scaleY,
  }
}

function startDraw(e) {
  e.preventDefault()
  drawing = true
  const pos = getPos(e)
  lastX = pos.x; lastY = pos.y
}

function draw(e) {
  if (!drawing) return
  e.preventDefault()
  const pos = getPos(e)
  ctx.beginPath()
  ctx.moveTo(lastX, lastY)
  ctx.lineTo(pos.x, pos.y)
  ctx.stroke()
  lastX = pos.x; lastY = pos.y
}

function endDraw() { drawing = false }

function canvasIsEmpty() {
  if (!canvasRef.value || !ctx) return true
  const data = ctx.getImageData(0, 0, canvasRef.value.width, canvasRef.value.height).data
  // Si todos los pixels son el color de fondo (#f8f9fa = 248,249,250) está vacío
  for (let i = 0; i < data.length; i += 4) {
    if (data[i] !== 248 || data[i+1] !== 249 || data[i+2] !== 250) return false
  }
  return true
}

async function confirmarFirma() {
  if (canvasIsEmpty()) {
    alert('Por favor dibujá tu firma antes de confirmar')
    return
  }
  firmandoDoc.value = true
  try {
    const firmaData = canvasRef.value.toDataURL('image/png')
    const { data } = await firmarDocumento(props.socioId, currentDoc.value.id, {
      firmante:   firmante.value,
      firma_data: firmaData,
    })
    const idx = docs.value.findIndex(d => d.id === data.id)
    if (idx !== -1) docs.value[idx] = data
    showFirmar.value = false
  } catch (e) {
    alert(e.response?.data?.error || 'Error al registrar la firma')
  } finally {
    firmandoDoc.value = false
  }
}

// ── Imprimir / descargar ──────────────────────────────────────────────
function imprimirDoc(doc) {
  const ventana = window.open('', '_blank')
  ventana.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>${doc.nombre}</title>
      <style>
        body { font-family: Arial, sans-serif; padding: 40px; font-size: 13px; }
        h1 { font-size: 18px; text-align: center; margin-bottom: 8px; }
        .meta { text-align: center; color: #666; font-size: 11px; margin-bottom: 32px; }
        .content { line-height: 1.7; }
        .firmas { margin-top: 60px; display: flex; gap: 80px; }
        .firma-box { flex: 1; border-top: 1px solid #333; padding-top: 8px; }
        .firma-img { max-height: 60px; }
        .hash { margin-top: 40px; font-size: 9px; color: #aaa; word-break: break-all; }
        @media print { .no-print { display: none; } }
      </style>
    </head>
    <body>
      <h1>${doc.nombre}</h1>
      <div class="meta">
        Generado el ${formatDate(doc.created_at)} · Hash: ${doc.hash_documento?.slice(0, 16) || '—'}
      </div>
      <div class="content">${doc.contenido_html || ''}</div>
      <div class="firmas">
        ${doc.firma_paciente_nombre ? `
          <div class="firma-box">
            ${doc.firma_paciente_data ? `<img src="${doc.firma_paciente_data}" class="firma-img" />` : ''}
            <div><strong>${doc.firma_paciente_nombre}</strong></div>
            <div style="font-size:11px;color:#666">${formatDate(doc.firmado_paciente_at)}</div>
            <div style="font-size:11px">Paciente</div>
          </div>
        ` : ''}
        ${doc.firma_medico_nombre ? `
          <div class="firma-box">
            ${doc.firma_medico_data ? `<img src="${doc.firma_medico_data}" class="firma-img" />` : ''}
            <div><strong>${doc.firma_medico_nombre}</strong></div>
            <div style="font-size:11px;color:#666">${formatDate(doc.firmado_medico_at)}</div>
            <div style="font-size:11px">Profesional médico</div>
          </div>
        ` : ''}
      </div>
      <div class="hash">Integridad: SHA-256 ${doc.hash_documento || '—'}</div>
      <script>window.onload = () => { window.print(); }<\/script>
    </body>
    </html>
  `)
  ventana.document.close()
}

onMounted(load)
</script>

<template>
  <div>
    <!-- Header -->
    <div class="d-flex align-items-center justify-content-between mb-3">
      <div>
        <strong>📄 Documentos</strong>
        <p class="text-muted small mb-0">Consentimientos, indicaciones y declaraciones con firma digital</p>
      </div>
      <button v-if="canEdit" class="btn btn-sm btn-success" @click="showCreate=true; resetForm()">
        <i class="bi bi-plus-circle me-1"></i> Nuevo documento
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-4">
      <div class="spinner-border spinner-border-sm text-success"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!docs.length" class="text-center py-5 text-muted">
      <div class="fs-1 mb-2">📄</div>
      <div class="small">Sin documentos registrados para este paciente</div>
    </div>

    <!-- Lista de documentos -->
    <div v-else class="doc-list">
      <div v-for="doc in docs" :key="doc.id" class="doc-item">
        <div class="d-flex align-items-start justify-content-between gap-2">
          <div class="flex-grow-1 min-w-0">
            <div class="d-flex align-items-center gap-2 mb-1">
              <span class="fw-semibold text-truncate">{{ doc.nombre }}</span>
              <span class="badge rounded-pill flex-shrink-0" :class="`text-bg-${estadoMeta(doc.estado).color}`">
                {{ estadoMeta(doc.estado).label }}
              </span>
            </div>
            <div class="small text-muted d-flex flex-wrap gap-3">
              <span>{{ TIPO_LABELS[doc.tipo] || doc.tipo }}</span>
              <span><i class="bi bi-person me-1"></i>{{ doc.created_by?.nombre }}</span>
              <span><i class="bi bi-calendar me-1"></i>{{ formatDate(doc.created_at) }}</span>
            </div>
            <!-- Estado de firmas -->
            <div class="d-flex gap-2 mt-1 flex-wrap">
              <span class="firma-badge" :class="doc.firmado_paciente_at ? 'firma-badge--ok' : 'firma-badge--pending'">
                <i class="bi" :class="doc.firmado_paciente_at ? 'bi-pen-fill' : 'bi-pen'"></i>
                Paciente {{ doc.firmado_paciente_at ? '✓' : 'pendiente' }}
              </span>
              <span class="firma-badge" :class="doc.firmado_medico_at ? 'firma-badge--ok' : 'firma-badge--pending'">
                <i class="bi" :class="doc.firmado_medico_at ? 'bi-pen-fill' : 'bi-pen'"></i>
                Médico {{ doc.firmado_medico_at ? '✓' : 'pendiente' }}
              </span>
            </div>
          </div>

          <!-- Acciones -->
          <div class="d-flex gap-1 flex-shrink-0">
            <button class="btn btn-sm btn-outline-secondary" title="Ver" @click="verDoc(doc)">
              <i class="bi bi-eye"></i>
            </button>
            <button class="btn btn-sm btn-outline-success" title="Imprimir / PDF" @click="imprimirDoc(doc)">
              <i class="bi bi-printer"></i>
            </button>
            <div v-if="canEdit && doc.estado !== 'archivado'" class="dropdown">
              <button class="btn btn-sm btn-outline-secondary dropdown-toggle" data-bs-toggle="dropdown">
                <i class="bi bi-three-dots"></i>
              </button>
              <ul class="dropdown-menu dropdown-menu-end shadow-sm border-0">
                <li v-if="!doc.firmado_paciente_at">
                  <button class="dropdown-item small" @click="abrirFirmar(doc, 'paciente')">
                    <i class="bi bi-pen me-2"></i>Firma paciente
                  </button>
                </li>
                <li v-if="!doc.firmado_medico_at">
                  <button class="dropdown-item small" @click="abrirFirmar(doc, 'medico')">
                    <i class="bi bi-pen me-2"></i>Firma médico
                  </button>
                </li>
                <li v-if="doc.estado === 'firmado'">
                  <button class="dropdown-item small" @click="doArchivar(doc)">
                    <i class="bi bi-archive me-2"></i>Archivar
                  </button>
                </li>
                <li><hr class="dropdown-divider my-1"></li>
                <li>
                  <button class="dropdown-item small text-danger" @click="deleteTarget=doc; showDelete=true">
                    <i class="bi bi-trash me-2"></i>Eliminar
                  </button>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== MODAL CREAR ===== -->
    <div v-if="showCreate" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Nuevo documento</h5>
            <button class="btn-close" @click="showCreate=false; resetForm()"></button>
          </div>
          <div class="modal-body">

            <div v-if="formError" class="alert alert-danger d-flex align-items-center gap-2 mb-3">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ formError }}</span>
            </div>

            <div class="row g-3 mb-4">
              <!-- Template -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Usar template</label>
                <select v-model="form.template_id" class="form-select">
                  <option value="">— Sin template, crear desde cero —</option>
                  <option v-for="t in templates" :key="t.id" :value="t.id">
                    {{ t.nombre }} ({{ TIPO_LABELS[t.tipo] || t.tipo }})
                  </option>
                </select>
                <div class="form-text">Seleccioná un template para pre-cargar el contenido</div>
              </div>

              <!-- Nombre -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Nombre del documento <span class="text-danger">*</span></label>
                <input v-model.trim="form.nombre" class="form-control" placeholder="Ej: Consentimiento — Juan Pérez — 2025" />
              </div>

              <!-- Tipo -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Tipo</label>
                <select v-model="form.tipo" class="form-select">
                  <option v-for="(label, key) in TIPO_LABELS" :key="key" :value="key">{{ label }}</option>
                </select>
              </div>
            </div>

            <!-- Editor de contenido -->
            <label class="form-label small fw-semibold">
              Contenido <span class="text-danger">*</span>
              <span class="text-muted ms-2" style="font-weight:400">
                — Usá variables: <code>{{'{{'}}paciente_nombre{{'}}'}}</code>, <code>{{'{{'}}paciente_dni{{'}}'}}</code>, <code>{{'{{'}}fecha_hoy{{'}}'}}</code>, etc.
              </span>
            </label>
            <textarea
              v-model="form.contenido_html"
              class="form-control font-monospace"
              rows="16"
              placeholder="Escribí el contenido del documento en HTML o texto plano. Las variables {{paciente_nombre}}, {{paciente_dni}}, {{club_nombre}}, {{medico_nombre}}, {{fecha_hoy}} se reemplazarán automáticamente..."
              style="font-size:.82rem"
            ></textarea>
            <div class="form-text">
              Variables disponibles:
              <code>{{'{{'}}paciente_nombre{{'}}'}}</code>
              <code>{{'{{'}}paciente_apellido{{'}}'}}</code>
              <code>{{'{{'}}paciente_dni{{'}}'}}</code>
              <code>{{'{{'}}paciente_reprocann{{'}}'}}</code>
              <code>{{'{{'}}club_nombre{{'}}'}}</code>
              <code>{{'{{'}}medico_nombre{{'}}'}}</code>
              <code>{{'{{'}}fecha_hoy{{'}}'}}</code>
            </div>

          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="saving" @click="showCreate=false; resetForm()">Cancelar</button>
            <button class="btn btn-success px-4" :disabled="saving" @click="crear">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              Crear documento
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showCreate" class="modal-backdrop fade show" @click="showCreate=false; resetForm()"></div>

    <!-- ===== MODAL VISOR ===== -->
    <div v-if="showViewer && currentDoc" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-xl modal-dialog-scrollable">
        <div class="modal-content">
          <div class="modal-header">
            <div>
              <h5 class="modal-title mb-0">{{ currentDoc.nombre }}</h5>
              <span class="badge mt-1" :class="`text-bg-${estadoMeta(currentDoc.estado).color}`">
                {{ estadoMeta(currentDoc.estado).label }}
              </span>
            </div>
            <div class="d-flex gap-2 ms-3">
              <button class="btn btn-sm btn-outline-secondary" @click="imprimirDoc(currentDoc)" title="Imprimir">
                <i class="bi bi-printer"></i>
              </button>
              <button class="btn-close" @click="showViewer=false"></button>
            </div>
          </div>
          <div class="modal-body">

            <!-- Contenido del documento -->
            <div class="doc-preview p-4 mb-4" v-html="currentDoc.contenido_html"></div>

            <!-- Sección de firmas -->
            <div class="row g-3 mt-2">
              <div class="col-md-6">
                <div class="firma-display" :class="currentDoc.firmado_paciente_at ? 'firma-display--ok' : 'firma-display--empty'">
                  <div class="small fw-semibold mb-2">Firma del paciente</div>
                  <img v-if="currentDoc.firma_paciente_data" :src="currentDoc.firma_paciente_data" class="firma-img mb-2" />
                  <div v-else class="firma-placeholder">Sin firma</div>
                  <div class="small text-muted">
                    {{ currentDoc.firma_paciente_nombre || '—' }}
                    <span v-if="currentDoc.firmado_paciente_at"> · {{ formatDate(currentDoc.firmado_paciente_at) }}</span>
                  </div>
                </div>
              </div>
              <div class="col-md-6">
                <div class="firma-display" :class="currentDoc.firmado_medico_at ? 'firma-display--ok' : 'firma-display--empty'">
                  <div class="small fw-semibold mb-2">Firma del médico</div>
                  <img v-if="currentDoc.firma_medico_data" :src="currentDoc.firma_medico_data" class="firma-img mb-2" />
                  <div v-else class="firma-placeholder">Sin firma</div>
                  <div class="small text-muted">
                    {{ currentDoc.firma_medico_nombre || '—' }}
                    <span v-if="currentDoc.firmado_medico_at"> · {{ formatDate(currentDoc.firmado_medico_at) }}</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Hash integridad -->
            <div v-if="currentDoc.hash_documento" class="mt-3 p-2 rounded bg-body-secondary">
              <div class="small text-muted">
                <i class="bi bi-shield-check me-1 text-success"></i>
                Integridad SHA-256: <code class="small">{{ currentDoc.hash_documento }}</code>
              </div>
            </div>

          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" @click="showViewer=false">Cerrar</button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showViewer" class="modal-backdrop fade show" @click="showViewer=false"></div>

    <!-- ===== MODAL FIRMA DIGITAL ===== -->
    <div v-if="showFirmar && currentDoc" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              ✍️ Firma digital —
              {{ firmante === 'paciente' ? 'Paciente' : 'Médico' }}
            </h5>
            <button class="btn-close" @click="showFirmar=false"></button>
          </div>
          <div class="modal-body">
            <p class="small text-muted mb-3">
              Dibujá tu firma en el recuadro. Esta firma quedará vinculada al documento
              <strong>{{ currentDoc.nombre }}</strong> con fecha y hora registradas.
            </p>

            <!-- Canvas firma -->
            <div class="canvas-wrapper mb-3">
              <canvas
                ref="canvasRef"
                width="460"
                height="180"
                class="firma-canvas"
                @mousedown="startDraw"
                @mousemove="draw"
                @mouseup="endDraw"
                @mouseleave="endDraw"
                @touchstart="startDraw"
                @touchmove="draw"
                @touchend="endDraw"
              ></canvas>
            </div>

            <div class="d-flex justify-content-between align-items-center">
              <button class="btn btn-sm btn-outline-secondary" @click="clearCanvas">
                <i class="bi bi-eraser me-1"></i>Borrar
              </button>
              <div class="small text-muted">
                <i class="bi bi-clock me-1"></i>
                Se registrará: {{ new Date().toLocaleString('es-AR') }}
              </div>
            </div>

            <div class="alert alert-info small mt-3 mb-0 d-flex align-items-start gap-2">
              <i class="bi bi-info-circle-fill mt-1 flex-shrink-0"></i>
              <div>
                Esta firma electrónica tiene validez conforme a la <strong>Ley 25.506</strong> de Firma Digital.
                Se almacena junto con nombre, DNI, fecha/hora y hash del documento.
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="firmandoDoc" @click="showFirmar=false">Cancelar</button>
            <button class="btn btn-success px-4" :disabled="firmandoDoc" @click="confirmarFirma">
              <span v-if="firmandoDoc" class="spinner-border spinner-border-sm me-2"></span>
              <i v-else class="bi bi-pen me-1"></i>
              Confirmar firma
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showFirmar" class="modal-backdrop fade show" @click="showFirmar=false"></div>

    <!-- ===== MODAL ELIMINAR ===== -->
    <div v-if="showDelete" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0">
            <h5 class="modal-title text-danger">⚠️ Eliminar documento</h5>
            <button class="btn-close" @click="showDelete=false"></button>
          </div>
          <div class="modal-body">
            <p>¿Seguro que querés eliminar <strong>{{ deleteTarget?.nombre }}</strong>?</p>
            <p class="text-muted small mb-0">Se eliminarán también las firmas registradas. Esta acción no se puede deshacer.</p>
          </div>
          <div class="modal-footer border-0">
            <button class="btn btn-outline-secondary" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger" @click="doDelete">Eliminar</button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showDelete" class="modal-backdrop fade show" @click="showDelete=false"></div>

  </div>
</template>

<style scoped>
/* Lista de documentos */
.doc-list { display: flex; flex-direction: column; gap: .75rem; }
.doc-item {
  background: white;
  border: 1.5px solid rgba(0,0,0,.06);
  border-radius: 10px;
  padding: 1rem;
  transition: border-color .15s;
}
.doc-item:hover { border-color: var(--brand-primary, #1b5e20); }

/* Badges de firma */
.firma-badge {
  font-size: .72rem;
  padding: .2rem .5rem;
  border-radius: 20px;
  display: inline-flex;
  align-items: center;
  gap: .3rem;
}
.firma-badge--ok      { background: rgba(25,135,84,.1);  color: #198754; }
.firma-badge--pending { background: rgba(108,117,125,.1); color: #6c757d; }

/* Preview del documento */
.doc-preview {
  background: white;
  border: 1px solid rgba(0,0,0,.08);
  border-radius: 8px;
  min-height: 200px;
  line-height: 1.7;
  font-size: .9rem;
}

/* Display de firma */
.firma-display {
  border-radius: 8px;
  padding: 1rem;
  border: 2px solid;
}
.firma-display--ok    { border-color: #198754; background: rgba(25,135,84,.04); }
.firma-display--empty { border-color: #dee2e6; background: #f8f9fa; }
.firma-img {
  max-height: 70px;
  max-width: 100%;
  display: block;
  border-bottom: 1px solid #dee2e6;
  padding-bottom: .5rem;
}
.firma-placeholder {
  height: 50px;
  display: flex;
  align-items: center;
  color: #adb5bd;
  font-size: .85rem;
  border-bottom: 1px solid #dee2e6;
  margin-bottom: .5rem;
}

/* Canvas firma */
.canvas-wrapper {
  border: 2px dashed #dee2e6;
  border-radius: 8px;
  overflow: hidden;
  background: #f8f9fa;
}
.firma-canvas {
  display: block;
  width: 100%;
  cursor: crosshair;
  touch-action: none;
}
</style>
