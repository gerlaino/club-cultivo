<template>
  <div class="mdv">

    <!-- Header -->
    <div class="mdv__header">
      <div>
        <h1 class="mdv__title">Documentos clínicos</h1>
        <p class="mdv__sub">REPROCANN, certificados y documentación del club</p>
      </div>
      <button class="mdv__btn-primary" @click="openUpload">
        <Upload :size="15" :stroke-width="1.75" /> Subir documento
      </button>
    </div>

    <!-- Tabs -->
    <div class="mdv__tabs">
      <button
        class="mdv__tab"
        :class="{ 'mdv__tab--active': tab === 'clinicos' }"
        @click="tab = 'clinicos'"
      >
        <Stethoscope :size="14" :stroke-width="1.75" /> Clínicos
        <span v-if="conteos.clinicos" class="mdv__tab-badge">{{ conteos.clinicos }}</span>
      </button>
      <button
        class="mdv__tab"
        :class="{ 'mdv__tab--active': tab === 'legales' }"
        @click="tab = 'legales'"
      >
        <Scale :size="14" :stroke-width="1.75" /> Del club
        <span v-if="conteos.legales" class="mdv__tab-badge">{{ conteos.legales }}</span>
      </button>
    </div>

    <!-- Toolbar -->
    <div class="mdv__toolbar">
      <div class="mdv__search-wrap">
        <Search :size="16" class="mdv__search-icon" />
        <input v-model="search" class="mdv__search" placeholder="Buscar por título o paciente…" />
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="mdv__loading">
      <DsSpinner :size="20" /> Cargando documentos…
    </div>

    <!-- Empty -->
    <div v-else-if="!filtrados.length" class="mdv__empty">
      <FolderOpen :size="40" :stroke-width="1" />
      <p>{{ search ? 'Sin resultados para tu búsqueda' : 'No hay documentos en esta categoría' }}</p>
      <button class="mdv__btn-primary" @click="openUpload">
        <Upload :size="15" /> Subir primer documento
      </button>
    </div>

    <!-- Lista de documentos -->
    <div v-else class="mdv__list">
      <div v-for="d in filtrados" :key="d.id" class="mdv__doc-row">
        <div class="mdv__doc-icon" :class="docIconClass(d)">
          <component :is="docIcon(d)" :size="18" :stroke-width="1.5" />
        </div>
        <div class="mdv__doc-info">
          <div class="mdv__doc-title">{{ d.titulo || `Documento #${d.id}` }}</div>
          <div class="mdv__doc-meta">
            <span class="mdv__tipo-badge">{{ d.tipo }}</span>
            <span v-if="d.paciente" class="mdv__doc-pac">
              <RouterLink :to="`/medico/pacientes/${d.paciente.id}`" @click.stop>
                {{ d.paciente.nombre }} {{ d.paciente.apellido }}
              </RouterLink>
            </span>
            <span>{{ formatDate(d.created_at) }}</span>
            <span v-if="d.fecha_vencimiento">Vence: {{ formatDate(d.fecha_vencimiento) }}</span>
          </div>
        </div>
        <div class="mdv__doc-estado">
          <span v-if="d.estado" class="mdv__est-badge" :class="estadoClass(d)">{{ d.estado }}</span>
        </div>
        <div class="mdv__doc-actions">
          <button
            v-if="d.tiene_archivo"
            class="mdv__action-btn"
            @click="descargar(d.id)"
            title="Descargar"
          >
            <Download :size="14" />
          </button>
          <button
            class="mdv__action-btn mdv__action-btn--danger"
            @click="eliminar(d)"
            title="Eliminar"
          >
            <Trash2 :size="14" />
          </button>
        </div>
      </div>
    </div>

    <!-- Modal: Subir documento -->
    <Teleport to="body">
      <div v-if="showUpload" class="mdv__overlay" @click.self="showUpload = false">
        <div class="mdv__modal">
          <div class="mdv__modal-header">
            <h2 class="mdv__modal-title">Subir documento</h2>
            <button class="mdv__modal-close" @click="showUpload = false"><X :size="18" /></button>
          </div>
          <div class="mdv__modal-body">
            <div v-if="uploadError" class="mdv__form-error">{{ uploadError }}</div>
            <div class="mdv__form-grid">

              <div class="mdv__form-field mdv__form-field--full">
                <label>Título del documento <span class="mdv__req">*</span></label>
                <input v-model="uploadForm.titulo" type="text" placeholder="Ej: REPROCANN Juan García 2026" />
              </div>

              <div class="mdv__form-field">
                <label>Tipo <span class="mdv__req">*</span></label>
                <select v-model="uploadForm.tipo">
                  <option value="">— Seleccionar —</option>
                  <optgroup label="Clínicos">
                    <option value="reprocann">REPROCANN</option>
                    <option value="receta">Receta</option>
                    <option value="certificado_medico">Certificado médico</option>
                    <option value="estudio_clinico">Estudio clínico</option>
                    <option value="dni">DNI</option>
                    <option value="identificacion">Identificación</option>
                  </optgroup>
                  <optgroup label="Del club">
                    <option value="contrato_socio">Contrato socio</option>
                    <option value="estatuto">Estatuto</option>
                    <option value="acta_asamblea">Acta asamblea</option>
                    <option value="reglamento_interno">Reglamento interno</option>
                    <option value="plan_trabajo">Plan de trabajo</option>
                    <option value="informe_semestral">Informe semestral</option>
                    <option value="otro">Otro</option>
                  </optgroup>
                </select>
              </div>

              <div class="mdv__form-field">
                <label>Fecha del documento</label>
                <AppDatePicker v-model="uploadForm.fecha_documento" />
              </div>

              <div class="mdv__form-field">
                <label>Fecha de vencimiento</label>
                <AppDatePicker v-model="uploadForm.fecha_vencimiento" />
              </div>

              <div class="mdv__form-field">
                <label>Paciente vinculado (opcional)</label>
                <select v-model="uploadForm.paciente_id">
                  <option value="">— Ninguno (doc. del club) —</option>
                  <option v-for="p in pacientesStore.items" :key="p.id" :value="p.id">
                    {{ p.nombre }} {{ p.apellido }}
                  </option>
                </select>
              </div>

              <div class="mdv__form-field mdv__form-field--full">
                <label>Notas</label>
                <textarea v-model="uploadForm.descripcion" rows="2" placeholder="Observaciones opcionales…"></textarea>
              </div>

            </div>
          </div>
          <div class="mdv__modal-footer">
            <button class="mdv__btn-ghost" @click="showUpload = false">Cancelar</button>
            <button class="mdv__btn-primary" @click="guardarDoc" :disabled="uploading">
              {{ uploading ? 'Guardando…' : 'Guardar documento' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AppDatePicker from '../../components/ui/AppDatePicker.vue'
import {
  Search, Upload, Download, Trash2, X, FolderOpen,
  FileText, File, Stethoscope, Scale,
} from 'lucide-vue-next'
import api from '../../lib/api.js'
import { usePacientesStore } from '../../stores/pacientes.js'
import { useConfirm } from '../../composables/useConfirm.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useToast } from '../../composables/useToast.js'

const pacientesStore = usePacientesStore()
const { confirm }    = useConfirm()
const { success: toastOk, error: toastErr } = useToast()

const loading    = ref(false)
const documentos = ref([])
const tab        = ref('clinicos')
const search     = ref('')
const showUpload = ref(false)
const uploading  = ref(false)
const uploadError = ref(null)

const TIPOS_CLINICOS = ['reprocann', 'receta', 'certificado_medico', 'estudio_clinico', 'dni', 'identificacion']

function emptyUploadForm() {
  return { titulo: '', tipo: '', fecha_documento: '', fecha_vencimiento: '', paciente_id: '', descripcion: '' }
}
const uploadForm = ref(emptyUploadForm())

function openUpload() {
  uploadForm.value = emptyUploadForm()
  uploadError.value = null
  showUpload.value  = true
}

async function guardarDoc() {
  if (!uploadForm.value.titulo.trim() || !uploadForm.value.tipo) {
    uploadError.value = 'El título y el tipo son obligatorios'
    return
  }
  uploading.value  = true
  uploadError.value = null
  const payload = { ...uploadForm.value }
  Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
  try {
    await api.post('/documentos', { documento: payload })
    await cargar()
    showUpload.value = false
    toastOk('Documento guardado correctamente')
  } catch (e) {
    const msgs = e?.response?.data?.errors
    uploadError.value = Array.isArray(msgs) ? msgs.join(', ') : 'Error al guardar el documento'
  } finally {
    uploading.value = false
  }
}

async function descargar(id) {
  try {
    const res = await api.get(`/documentos/${id}/descargar`, { responseType: 'blob' })
    const url = URL.createObjectURL(res.data)
    const a   = document.createElement('a')
    a.href = url; a.download = `documento_${id}`; a.click()
    URL.revokeObjectURL(url)
  } catch {
    toastErr('No se pudo descargar el documento')
  }
}

async function eliminar(d) {
  const ok = await confirm({
    title: 'Eliminar documento',
    message: `¿Eliminar "${d.titulo || 'este documento'}"? Esta acción no se puede deshacer.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  try {
    await api.delete(`/documentos/${d.id}`)
    documentos.value = documentos.value.filter(x => x.id !== d.id)
    toastOk('Documento eliminado')
  } catch {
    toastErr('No se pudo eliminar el documento')
  }
}

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/documentos')
    documentos.value = Array.isArray(res.data) ? res.data : (res.data?.data ?? [])
  } finally {
    loading.value = false
  }
}

function esClin(d) { return TIPOS_CLINICOS.includes(d.tipo) }

const conteos = computed(() => ({
  clinicos: documentos.value.filter(d => esClin(d)).length,
  legales:  documentos.value.filter(d => !esClin(d)).length,
}))

const filtrados = computed(() => {
  let list = documentos.value.filter(d => tab.value === 'clinicos' ? esClin(d) : !esClin(d))
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(d =>
      (d.titulo || '').toLowerCase().includes(q) ||
      (`${d.paciente?.nombre || ''} ${d.paciente?.apellido || ''}`).toLowerCase().includes(q)
    )
  }
  return list
})

function safeDate(d) {
  if (!d) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}
function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function docIcon(d) {
  if (['reprocann', 'certificado_medico'].includes(d.tipo)) return FileText
  return File
}
function docIconClass(d) {
  if (['reprocann', 'certificado_medico', 'estudio_clinico'].includes(d.tipo)) return 'mdv__doc-icon--blue'
  if (['receta'].includes(d.tipo)) return 'mdv__doc-icon--green'
  if (['estatuto', 'acta_asamblea', 'reglamento_interno'].includes(d.tipo)) return 'mdv__doc-icon--purple'
  return 'mdv__doc-icon--gray'
}
function estadoClass(d) {
  return {
    'mdv__est--ok':   d.estado === 'vigente',
    'mdv__est--err':  d.estado === 'vencido',
    'mdv__est--gray': d.estado === 'pendiente',
  }
}

onMounted(async () => {
  await Promise.all([cargar(), pacientesStore.fetch()])
})
</script>

<style scoped>
.mdv { padding: var(--sp-6); max-width: 900px; }

/* Header */
.mdv__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: var(--sp-4); margin-bottom: var(--sp-5); flex-wrap: wrap;
}
.mdv__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mdv__sub   { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0; }

/* Botones */
.mdv__btn-primary {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #2D8A6B; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.mdv__btn-primary:hover    { background: #236e55; }
.mdv__btn-primary:disabled { opacity: .6; cursor: default; }
.mdv__btn-ghost {
  background: none; border: 1px solid var(--c-ink-200); color: var(--c-ink-600);
  border-radius: var(--r-md); padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13);
  cursor: pointer; transition: all .15s;
}
.mdv__btn-ghost:hover { background: var(--c-ink-50); }

/* Tabs */
.mdv__tabs { display: flex; gap: var(--sp-1); margin-bottom: var(--sp-4); border-bottom: 1px solid var(--c-ink-100); }
.mdv__tab {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 500;
  color: var(--c-ink-500); background: none; border: none;
  border-bottom: 2px solid transparent; cursor: pointer; transition: all .15s;
  margin-bottom: -1px;
}
.mdv__tab:hover { color: var(--c-ink-800); }
.mdv__tab--active { color: #2D8A6B; border-bottom-color: #2D8A6B; font-weight: 600; }
.mdv__tab-badge {
  background: var(--c-ink-100); color: var(--c-ink-600);
  font-size: var(--fs-11); font-weight: 700; padding: 0 5px; border-radius: 999px;
}

/* Toolbar */
.mdv__toolbar { margin-bottom: var(--sp-4); }
.mdv__search-wrap { position: relative; display: flex; align-items: center; max-width: 380px; }
.mdv__search-icon { position: absolute; left: var(--sp-3); color: var(--c-ink-400); pointer-events: none; }
.mdv__search {
  width: 100%; padding: var(--sp-2) var(--sp-3) var(--sp-2) calc(var(--sp-3) + 20px + var(--sp-2));
  background: var(--c-paper); border: 1px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-ink-800); outline: none; transition: border-color .15s;
}
.mdv__search:focus { border-color: #2D8A6B; }

/* Loading / empty */
.mdv__loading {
  display: flex; align-items: center; gap: var(--sp-3);
  color: var(--c-ink-500); padding: var(--sp-8); font-size: var(--fs-14);
}
.mdv__empty {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-3);
  padding: var(--sp-12) var(--sp-6); color: var(--c-ink-300); text-align: center;
}
.mdv__empty p { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

/* Lista */
.mdv__list { display: flex; flex-direction: column; gap: 2px; }
.mdv__doc-row {
  display: flex; align-items: center; gap: var(--sp-3);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-3) var(--sp-4); transition: border-color .15s;
}
.mdv__doc-row:hover { border-color: #2D8A6B; }

.mdv__doc-icon {
  width: 40px; height: 40px; border-radius: var(--r-md); flex-shrink: 0;
  display: flex; align-items: center; justify-content: center;
}
.mdv__doc-icon--blue   { background: rgba(3,105,161,.1);  color: #0369a1; }
.mdv__doc-icon--green  { background: rgba(45,138,107,.1); color: #2D8A6B; }
.mdv__doc-icon--purple { background: rgba(124,58,237,.1); color: #7c3aed; }
.mdv__doc-icon--gray   { background: var(--c-ink-50);     color: var(--c-ink-500); }

.mdv__doc-info { flex: 1; min-width: 0; }
.mdv__doc-title { font-size: var(--fs-14); font-weight: 600; color: var(--c-ink-900); }
.mdv__doc-meta  { display: flex; gap: var(--sp-3); margin-top: 2px; align-items: center; flex-wrap: wrap; }
.mdv__doc-meta span { font-size: var(--fs-12); color: var(--c-ink-500); }
.mdv__doc-pac a { font-size: var(--fs-12); color: #2D8A6B; text-decoration: none; }
.mdv__doc-pac a:hover { text-decoration: underline; }

.mdv__tipo-badge {
  display: inline-block; padding: 1px 7px; border-radius: 999px;
  font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600);
}

.mdv__doc-estado { flex-shrink: 0; }
.mdv__est-badge {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-11); font-weight: 600;
}
.mdv__est--ok   { background: rgba(21,128,61,.1);  color: #15803d; }
.mdv__est--err  { background: rgba(220,38,38,.1);  color: #dc2626; }
.mdv__est--gray { background: var(--c-ink-100);    color: var(--c-ink-500); }

.mdv__doc-actions { display: flex; gap: var(--sp-1); flex-shrink: 0; }
.mdv__action-btn {
  width: 30px; height: 30px; border-radius: var(--r-sm); border: none;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; transition: all .15s; background: transparent; color: var(--c-ink-400);
}
.mdv__action-btn:hover              { background: var(--c-ink-100); color: var(--c-ink-700); }
.mdv__action-btn--danger:hover      { background: rgba(220,38,38,.1); color: #dc2626; }

/* Modal */
.mdv__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.4); z-index: 1000;
  display: flex; align-items: center; justify-content: center; padding: var(--sp-4);
}
.mdv__modal {
  background: var(--c-paper); border-radius: var(--r-xl); width: 100%; max-width: 540px;
  box-shadow: 0 20px 60px rgba(0,0,0,.2); display: flex; flex-direction: column; max-height: 90vh;
}
.mdv__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6); border-bottom: 1px solid var(--c-ink-100);
}
.mdv__modal-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.mdv__modal-close {
  background: none; border: none; color: var(--c-ink-400); cursor: pointer;
  display: flex; align-items: center; padding: var(--sp-1); border-radius: var(--r-sm);
}
.mdv__modal-close:hover { background: var(--c-ink-50); color: var(--c-ink-700); }
.mdv__modal-body { padding: var(--sp-5) var(--sp-6); overflow-y: auto; flex: 1; }
.mdv__modal-footer {
  display: flex; justify-content: flex-end; gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-6); border-top: 1px solid var(--c-ink-100);
}

/* Formulario */
.mdv__form-error {
  background: rgba(220,38,38,.08); border: 1px solid rgba(220,38,38,.2);
  color: #dc2626; border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); margin-bottom: var(--sp-4);
}
.mdv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); }
.mdv__form-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.mdv__form-field--full { grid-column: 1 / -1; }
.mdv__form-field label { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-600); }
.mdv__req { color: #dc2626; }
.mdv__form-field input,
.mdv__form-field select,
.mdv__form-field textarea {
  padding: var(--sp-2) var(--sp-3); background: var(--c-bg);
  border: 1px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-ink-800); outline: none;
  transition: border-color .15s; font-family: inherit;
}
.mdv__form-field input:focus,
.mdv__form-field select:focus,
.mdv__form-field textarea:focus { border-color: #2D8A6B; }
.mdv__form-field textarea { resize: vertical; }
</style>
