<script setup>
import { ref, computed, onMounted } from 'vue'
import { logger } from '../utils/logger.js'
import {
  listDocumentTemplates, getDocumentTemplate,
  createDocumentTemplate, updateDocumentTemplate, deleteDocumentTemplate
} from '../lib/api.js'
import { useAuthStore } from '../stores/auth.js'
import { useConfirm } from '../composables/useConfirm.js'

const auth = useAuthStore()
const { confirm } = useConfirm()

const templates = ref([])
const loading   = ref(true)
const saving    = ref(false)
const formError = ref(null)

const showModal = ref(false)
const editingId = ref(null)

const TIPO_LABELS = {
  consentimiento_informado: 'Consentimiento Informado Bilateral',
  indicacion_medica:        'Indicación Médica',
  declaracion_jurada:       'Declaración Jurada',
  informe_semestral:        'Informe Semestral',
  carnet_vinculacion:       'Carnet de Vinculación',
  otro:                     'Otro',
}

const TIPO_META = {
  consentimiento_informado: { color: '#0369a1', bg: '#E0F2FE', icon: '📋' },
  indicacion_medica:        { color: '#15803d', bg: '#dcfce7', icon: '🩺' },
  declaracion_jurada:       { color: '#b91c1c', bg: '#fef2f2', icon: '⚖️'  },
  informe_semestral:        { color: '#6d28d9', bg: '#ede9fe', icon: '📊' },
  carnet_vinculacion:       { color: '#b45309', bg: '#fef3c7', icon: '🪪' },
  otro:                     { color: '#475569', bg: '#f1f5f9', icon: '📄' },
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

const filterTipo = ref('')
const filtered = computed(() => {
  if (!filterTipo.value) return templates.value
  return templates.value.filter(t => t.tipo === filterTipo.value)
})

async function load() {
  loading.value = true
  try {
    const { data } = await listDocumentTemplates()
    templates.value = data
  } catch (e) {
    logger.error('Error:', e)
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
    logger.error('Error cargando template:', e)
  }
}

function insertVariable(variable) {
  const textarea = document.getElementById('contenidoTextarea')
  if (!textarea) { form.value.contenido_html += variable; return }
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

async function handleDelete(t) {
  const ok = await confirm({
    title: 'Eliminar template',
    message: `¿Seguro que querés eliminar ${t.nombre}? Los documentos ya generados no se verán afectados.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  try {
    await deleteDocumentTemplate(t.id)
    templates.value = templates.value.filter(x => x.id !== t.id)
  } catch {}
}

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

onMounted(load)
</script>

<template>
  <div class="dtv">

    <!-- Header -->
    <div class="dtv__header">
      <div>
        <h1 class="dtv__title">Templates de documentos</h1>
        <p class="dtv__sub">Plantillas reutilizables para generar documentos con firma digital por paciente</p>
      </div>
      <button class="dtv__btn-new" @click="openCreate">
        <i class="bi bi-plus-lg"></i> Nuevo template
      </button>
    </div>

    <!-- Info legal -->
    <div class="dtv__banner">
      <i class="bi bi-info-circle-fill dtv__banner-icon"></i>
      <div>
        <strong>Resolución 1780/2025 — Documentos requeridos:</strong>
        Consentimiento Informado Bilateral, Indicación Médica, Declaración Jurada del paciente,
        Informe Semestral del Director Médico, Carnet de Vinculación con la ONG.
        Todos deben estar firmados digitalmente (Ley 25.506).
      </div>
    </div>

    <!-- Filtro por tipo -->
    <div class="dtv__pills">
      <button
        class="dtv__pill"
        :class="{ 'dtv__pill--active': filterTipo === '' }"
        @click="filterTipo=''"
      >
        Todos ({{ templates.length }})
      </button>
      <button
        v-for="(label, tipo) in TIPO_LABELS" :key="tipo"
        class="dtv__pill"
        :class="{ 'dtv__pill--active': filterTipo === tipo }"
        @click="filterTipo = filterTipo === tipo ? '' : tipo"
      >
        {{ tipoMeta(tipo).icon }} {{ label }}
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="dtv__loading">
      <div class="dtv__spinner"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!filtered.length" class="dtv__empty">
      <div class="dtv__empty-icon">📄</div>
      <h5 class="dtv__empty-title">{{ filterTipo ? 'Sin templates de este tipo' : 'No hay templates todavía' }}</h5>
      <p class="dtv__empty-desc">Creá el primer template para empezar a generar documentos para los pacientes</p>
      <button class="dtv__btn-new" @click="openCreate">Nuevo template</button>
    </div>

    <!-- Grid -->
    <div v-else class="dtv__grid">
      <div v-for="t in filtered" :key="t.id" class="template-card" :style="{ '--tipo-color': tipoMeta(t.tipo).color }">
        <div class="template-card__bar"></div>
        <div class="template-card__body">
          <div class="template-card__head">
            <div>
              <span class="template-card__tipo-icon">{{ tipoMeta(t.tipo).icon }}</span>
              <span class="template-card__tipo-label" :style="{ color: tipoMeta(t.tipo).color }">
                {{ TIPO_LABELS[t.tipo] }}
              </span>
            </div>
            <span v-if="!t.activo" class="template-card__badge template-card__badge--inactive">Inactivo</span>
          </div>

          <h6 class="template-card__name">{{ t.nombre }}</h6>
          <p v-if="t.descripcion" class="template-card__desc">{{ t.descripcion }}</p>

          <div class="template-card__flags">
            <span v-if="t.requiere_firma_paciente"><i class="bi bi-pen"></i> Firma paciente</span>
            <span v-if="t.requiere_firma_medico"><i class="bi bi-pen"></i> Firma médico</span>
          </div>

          <div class="template-card__actions">
            <button class="dtv__btn-edit" @click="openEdit(t)">
              <i class="bi bi-pencil"></i> Editar
            </button>
            <button class="dtv__btn-delete" @click="handleDelete(t)">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ===== MODAL CREAR / EDITAR ===== -->
    <Teleport to="body">
      <div v-if="showModal" class="dtv-modal-overlay" @click.self="showModal=false">
        <div class="dtv-modal">
          <div class="dtv-modal__header">
            <h5 class="dtv-modal__title">{{ editingId ? 'Editar template' : 'Nuevo template' }}</h5>
            <button class="dtv-modal__close" @click="showModal=false"><i class="bi bi-x-lg"></i></button>
          </div>
          <div class="dtv-modal__body">

            <div v-if="formError" class="dtv-modal__error">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ formError }}</span>
            </div>

            <div class="dtv-form">
              <div class="dtv-form__field dtv-form__field--half">
                <label class="dtv-form__label">Nombre <span class="dtv-form__req">*</span></label>
                <input v-model.trim="form.nombre" class="dtv-form__input" placeholder="Ej: Consentimiento Informado Bilateral v2025" />
              </div>
              <div class="dtv-form__field dtv-form__field--half">
                <label class="dtv-form__label">Tipo</label>
                <select v-model="form.tipo" class="dtv-form__input">
                  <option v-for="(label, key) in TIPO_LABELS" :key="key" :value="key">
                    {{ tipoMeta(key).icon }} {{ label }}
                  </option>
                </select>
              </div>
              <div class="dtv-form__field dtv-form__field--full">
                <label class="dtv-form__label">Descripción</label>
                <input v-model.trim="form.descripcion" class="dtv-form__input" placeholder="Descripción breve del documento…" />
              </div>
              <div class="dtv-form__field dtv-form__field--full dtv-form__toggles">
                <label class="dtv-form__toggle">
                  <input v-model="form.requiere_firma_paciente" type="checkbox" class="dtv-form__toggle-input" />
                  <span class="dtv-form__toggle-track"></span>
                  <span>Requiere firma paciente</span>
                </label>
                <label class="dtv-form__toggle">
                  <input v-model="form.requiere_firma_medico" type="checkbox" class="dtv-form__toggle-input" />
                  <span class="dtv-form__toggle-track"></span>
                  <span>Requiere firma médico</span>
                </label>
                <label class="dtv-form__toggle">
                  <input v-model="form.activo" type="checkbox" class="dtv-form__toggle-input" />
                  <span class="dtv-form__toggle-track"></span>
                  <span>Template activo</span>
                </label>
              </div>
            </div>

            <!-- Variables -->
            <div class="dtv-vars">
              <div class="dtv-vars__title">Variables disponibles — click para insertar en el cursor:</div>
              <div class="dtv-vars__pills">
                <button
                  v-for="v in VARIABLES" :key="v"
                  type="button"
                  class="dtv-vars__pill"
                  @click="insertVariable(v)"
                >{{ v }}</button>
              </div>
            </div>

            <!-- Editor -->
            <div class="dtv-form__field">
              <label class="dtv-form__label">Contenido <span class="dtv-form__req">*</span></label>
              <textarea
                id="contenidoTextarea"
                v-model="form.contenido_html"
                class="dtv-form__input dtv-form__textarea"
                rows="20"
                placeholder="Escribí el contenido del template en HTML o texto plano. Las variables se reemplazarán con los datos reales del paciente al generar el documento..."
              ></textarea>
            </div>

          </div>
          <div class="dtv-modal__footer">
            <button class="dtv__btn-ghost" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="dtv__btn-new" :disabled="saving" @click="handleSubmit">
              <span v-if="saving" class="dtv-modal__spinner"></span>
              {{ editingId ? 'Guardar cambios' : 'Crear template' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
/* Layout */
.dtv { padding: 2rem 1.75rem 3rem; max-width: 1200px; margin: 0 auto; }
@media (max-width: 768px) { .dtv { padding: 1.25rem 1rem 2rem; } }

/* Header */
.dtv__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.dtv__title  { font-size: 1.5rem; font-weight: 700; color: #0f172a; margin: 0; }
.dtv__sub    { font-size: .82rem; color: #64748b; margin: .15rem 0 0; }

/* Buttons */
.dtv__btn-new  { display: inline-flex; align-items: center; gap: .4rem; background: #1a3d2e; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.dtv__btn-new:hover:not(:disabled) { background: #0f2a1e; }
.dtv__btn-new:disabled { opacity: .6; cursor: not-allowed; }
.dtv__btn-ghost { background: #fff; border: 1.5px solid #e2e8f0; color: #64748b; padding: .55rem 1rem; border-radius: 9px; font-size: .875rem; font-weight: 500; cursor: pointer; }
.dtv__btn-ghost:hover:not(:disabled) { background: #f8fafc; }
.dtv__btn-ghost:disabled { opacity: .6; cursor: not-allowed; }
.dtv__btn-edit   { display: inline-flex; align-items: center; gap: .35rem; flex: 1; justify-content: center; padding: .45rem .75rem; border: 1.5px solid #1a3d2e; color: #1a3d2e; border-radius: 8px; font-size: .8rem; font-weight: 600; background: none; cursor: pointer; transition: all .15s; }
.dtv__btn-edit:hover { background: #f0f8f4; }
.dtv__btn-delete { display: inline-flex; align-items: center; justify-content: center; padding: .45rem .65rem; border: 1.5px solid #fecaca; color: #b91c1c; border-radius: 8px; font-size: .875rem; background: none; cursor: pointer; transition: all .15s; }
.dtv__btn-delete:hover { background: #fef2f2; }

/* Info banner */
.dtv__banner { display: flex; align-items: flex-start; gap: .65rem; background: #EFF6FF; border: 1px solid #bfdbfe; border-radius: 10px; padding: .875rem 1rem; margin-bottom: 1.25rem; font-size: .82rem; color: #1e3a5f; }
.dtv__banner-icon { color: #2563eb; margin-top: .1rem; flex-shrink: 0; }

/* Filter pills */
.dtv__pills { display: flex; flex-wrap: wrap; gap: .4rem; margin-bottom: 1.5rem; }
.dtv__pill  { background: none; border: 1.5px solid #e2e8f0; color: #6b7280; padding: .35rem .75rem; border-radius: 99px; font-size: .78rem; font-weight: 500; cursor: pointer; transition: all .15s; white-space: nowrap; }
.dtv__pill:hover { border-color: #94a3b8; color: #1e293b; }
.dtv__pill--active { background: #1a3d2e; border-color: #1a3d2e; color: #fff; }

/* Loading */
.dtv__loading { display: flex; justify-content: center; padding: 3rem; }
.dtv__spinner { width: 28px; height: 28px; border: 3px solid #e2e8f0; border-top-color: #1a3d2e; border-radius: 50%; animation: dtv-spin .8s linear infinite; }
@keyframes dtv-spin { to { transform: rotate(360deg); } }

/* Empty */
.dtv__empty      { text-align: center; padding: 3rem 1rem; color: #64748b; }
.dtv__empty-icon { font-size: 2.5rem; margin-bottom: .75rem; }
.dtv__empty-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0 0 .4rem; }
.dtv__empty-desc  { font-size: .82rem; margin: 0 0 1rem; }

/* Card grid */
.dtv__grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }
@media (max-width: 900px) { .dtv__grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 560px) { .dtv__grid { grid-template-columns: 1fr; } }

/* Template card */
.template-card { background: #fff; border-radius: 14px; border: 1.5px solid #e2e8f0; overflow: hidden; display: flex; flex-direction: column; transition: all .15s; }
.template-card:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,.09); border-color: var(--tipo-color); }
.template-card__bar  { height: 5px; background: var(--tipo-color); }
.template-card__body { padding: 1rem; flex: 1; display: flex; flex-direction: column; }
.template-card__head { display: flex; align-items: flex-start; justify-content: space-between; gap: .5rem; margin-bottom: .5rem; }
.template-card__tipo-icon  { font-size: .9rem; margin-right: .25rem; }
.template-card__tipo-label { font-size: .75rem; font-weight: 600; }
.template-card__badge { font-size: .68rem; font-weight: 600; padding: .15rem .5rem; border-radius: 99px; }
.template-card__badge--inactive { background: #f1f5f9; color: #64748b; border: 1px solid #e2e8f0; }
.template-card__name { font-size: .9rem; font-weight: 700; color: #0f172a; margin: 0 0 .3rem; }
.template-card__desc { font-size: .78rem; color: #64748b; margin: 0 0 .5rem; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; flex: 1; }
.template-card__flags { display: flex; flex-wrap: wrap; gap: .3rem .75rem; font-size: .75rem; color: #64748b; margin-bottom: .75rem; }
.template-card__flags i { margin-right: .2rem; }
.template-card__actions { display: flex; gap: .5rem; padding-top: .75rem; border-top: 1px solid #f1f5f9; margin-top: auto; }

/* Modal */
.dtv-modal-overlay { position: fixed; inset: 0; background: rgba(15,23,42,.55); z-index: 1000; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.dtv-modal { background: #fff; border-radius: 16px; width: 100%; max-width: 760px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.25); }
.dtv-modal__header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e5e7eb; flex-shrink: 0; }
.dtv-modal__title  { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.dtv-modal__close  { background: none; border: none; cursor: pointer; color: #94a3b8; font-size: 1rem; padding: .2rem; border-radius: 6px; transition: all .15s; }
.dtv-modal__close:hover { background: #f1f5f9; color: #475569; }
.dtv-modal__body   { overflow-y: auto; padding: 1.25rem 1.5rem; flex: 1; }
.dtv-modal__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e5e7eb; flex-shrink: 0; }
.dtv-modal__error  { display: flex; align-items: center; gap: .5rem; background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: .65rem .875rem; border-radius: 8px; font-size: .875rem; margin-bottom: 1rem; }
.dtv-modal__spinner { width: 14px; height: 14px; border: 2px solid rgba(255,255,255,.35); border-top-color: #fff; border-radius: 50%; animation: dtv-spin .7s linear infinite; display: inline-block; }

/* Form */
.dtv-form { display: grid; grid-template-columns: 1fr 1fr; gap: .875rem; margin-bottom: 1rem; }
.dtv-form__field      { display: flex; flex-direction: column; gap: .3rem; }
.dtv-form__field--full { grid-column: 1 / -1; }
.dtv-form__field--half { grid-column: span 1; }
.dtv-form__label  { font-size: .8rem; font-weight: 600; color: #374151; }
.dtv-form__req    { color: #dc2626; }
.dtv-form__input  { padding: .5rem .7rem; border: 1.5px solid #e2e8f0; border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; width: 100%; box-sizing: border-box; }
.dtv-form__input:focus { border-color: #1a3d2e; }
.dtv-form__textarea { resize: vertical; min-height: 400px; font-family: monospace; font-size: .82rem; }
.dtv-form__toggles { display: flex; flex-wrap: wrap; gap: .75rem 1.5rem; }
.dtv-form__toggle       { display: inline-flex; align-items: center; gap: .55rem; cursor: pointer; font-size: .875rem; color: #374151; }
.dtv-form__toggle-input { position: absolute; opacity: 0; width: 0; height: 0; }
.dtv-form__toggle-track { width: 36px; height: 20px; border-radius: 10px; background: #e2e8f0; position: relative; transition: background .2s; flex-shrink: 0; }
.dtv-form__toggle-track::after { content: ''; position: absolute; top: 2px; left: 2px; width: 16px; height: 16px; border-radius: 50%; background: #fff; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.dtv-form__toggle-input:checked + .dtv-form__toggle-track { background: #1a3d2e; }
.dtv-form__toggle-input:checked + .dtv-form__toggle-track::after { transform: translateX(16px); }

/* Variables */
.dtv-vars { margin-bottom: 1rem; }
.dtv-vars__title { font-size: .78rem; font-weight: 600; color: #374151; margin-bottom: .4rem; }
.dtv-vars__pills { display: flex; flex-wrap: wrap; gap: .3rem; }
.dtv-vars__pill { background: none; border: 1px solid #e2e8f0; color: #475569; padding: .15rem .45rem; border-radius: 5px; font-size: .72rem; font-family: monospace; cursor: pointer; transition: all .15s; }
.dtv-vars__pill:hover { background: #f8fafc; border-color: #1a3d2e; color: #1a3d2e; }
</style>
