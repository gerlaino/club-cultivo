<template>
  <Teleport to="body">
    <div v-modal="() => showModal = false" v-if="showModal" class="gem-overlay" @click.self="showModal = false">
      <div class="gem-modal">
        <div class="gem-modal__header">
          <div>
            <h5 class="gem-modal__title">{{ editingId ? 'Editar genética' : 'Nueva genética' }}</h5>
            <span v-if="editingInase" class="gem-modal__subtitle">Variedad registrada en el INASE</span>
          </div>
          <button class="gem-modal__close" @click="showModal = false"><i class="bi bi-x-lg"></i></button>
        </div>
        <div class="gem-modal__body">

          <div v-if="editingInase" class="inase-notice gem-modal__inase-notice">
            <div class="inase-notice__icon">🏛️</div>
            <div>
              <div class="inase-notice__title">Genética registrada en el INASE</div>
              <div class="inase-notice__desc">
                Nombre, tipo, THC, CBD y criador están certificados por el INASE y no pueden modificarse
                (Resolución 1780/2025). Podés editar disponibilidad, foto, descripción, terpenos y datos de cultivo.
              </div>
            </div>
          </div>

          <div v-if="formError" class="gem-error gem-modal__error">
            <i class="bi bi-exclamation-triangle-fill"></i>
            <span>{{ formError }}</span>
          </div>

          <div class="gem-form">

            <!-- Foto -->
            <div class="gem-form__field gem-form__field--full">
              <label class="gem-form__label">Foto de la genética</label>
              <div class="foto-uploader">
                <div v-if="fotoPreview" class="foto-preview">
                  <img :src="fotoPreview" alt="Preview" />
                  <button type="button" class="foto-remove" @click="quitarFoto" title="Quitar foto">
                    <i class="bi bi-x-lg"></i>
                  </button>
                </div>
                <label v-else class="foto-placeholder" :for="`gem-foto-${editingId || 'new'}`">
                  <i class="bi bi-camera" style="font-size:1.5rem;color:#94a3b8"></i>
                  <span style="font-size:.78rem;color:#94a3b8;margin-top:.25rem">Subir foto</span>
                </label>
                <input
                  :id="`gem-foto-${editingId || 'new'}`"
                  ref="fotoInput"
                  type="file"
                  accept="image/*"
                  style="display:none"
                  @change="onFotoChange"
                />
              </div>
            </div>

            <!-- Nombre -->
            <div class="gem-form__field gem-form__field--full">
              <label class="gem-form__label">
                Nombre <span class="gem-form__req">*</span>
                <span v-if="editingInase" class="field-lock-label">🔒 Protegido INASE</span>
              </label>
              <input
                v-model.trim="form.nombre"
                class="gem-form__input"
                :class="{ 'gem-form__input--error': formErrors.nombre, 'field-locked': editingInase }"
                :disabled="editingInase"
                placeholder="Ej: OG Kush, White Widow…"
              />
              <div v-if="formErrors.nombre" class="gem-form__field-error">{{ formErrors.nombre }}</div>
            </div>

            <!-- Tipo -->
            <div class="gem-form__field">
              <label class="gem-form__label">
                Tipo <span class="gem-form__req">*</span>
                <span v-if="editingInase" class="field-lock-label">🔒 Protegido</span>
              </label>
              <div class="gem-form__btn-group">
                <button
                  v-for="(meta, key) in TIPO_META" :key="key"
                  type="button"
                  class="gem-form__tipo-btn"
                  :style="form.tipo === key ? { background: meta.color, borderColor: meta.color, color: '#fff' } : {}"
                  :disabled="editingInase"
                  @click="!editingInase && (form.tipo = key)"
                >{{ meta.label }}</button>
              </div>
              <div v-if="formErrors.tipo" class="gem-form__field-error">{{ formErrors.tipo }}</div>
            </div>

            <!-- THC / CBD -->
            <div class="gem-form__field">
              <label class="gem-form__label">THC (%) <span v-if="editingInase" class="field-lock-label">🔒</span></label>
              <input
                v-model.number="form.thc" type="number" step="0.01" min="0" max="100"
                class="gem-form__input"
                :class="{ 'gem-form__input--error': formErrors.thc, 'field-locked': editingInase }"
                :disabled="editingInase" placeholder="0.0"
              />
              <div v-if="formErrors.thc" class="gem-form__field-error">{{ formErrors.thc }}</div>
            </div>
            <div class="gem-form__field">
              <label class="gem-form__label">CBD (%) <span v-if="editingInase" class="field-lock-label">🔒</span></label>
              <input
                v-model.number="form.cbd" type="number" step="0.01" min="0" max="100"
                class="gem-form__input"
                :class="{ 'gem-form__input--error': formErrors.cbd, 'field-locked': editingInase }"
                :disabled="editingInase" placeholder="0.0"
              />
              <div v-if="formErrors.cbd" class="gem-form__field-error">{{ formErrors.cbd }}</div>
            </div>

            <!-- Días objetivo por fase / Rendimiento / Altura -->
            <div class="gem-form__field">
              <label class="gem-form__label">Vegetativo (días)</label>
              <input v-model.number="form.dias_vegetativo_objetivo" type="number" min="1" class="gem-form__input" placeholder="30" :disabled="editingInase" />
            </div>
            <div class="gem-form__field">
              <label class="gem-form__label">Floración (días)</label>
              <input v-model.number="form.tiempo_floracion" type="number" min="1" class="gem-form__input" placeholder="60" :disabled="editingInase" />
            </div>
            <div class="gem-form__field">
              <label class="gem-form__label">Cosecha (días)</label>
              <input v-model.number="form.dias_cosecha_objetivo" type="number" min="1" class="gem-form__input" placeholder="14" :disabled="editingInase" />
            </div>
            <div class="gem-form__field">
              <label class="gem-form__label">Rendimiento (g)</label>
              <input v-model.number="form.rendimiento" type="number" min="0" class="gem-form__input" placeholder="450" />
            </div>
            <div class="gem-form__field">
              <label class="gem-form__label">Altura (cm)</label>
              <input v-model.number="form.altura" type="number" min="0" class="gem-form__input" placeholder="120" />
            </div>

            <!-- Criador -->
            <div class="gem-form__field gem-form__field--half">
              <label class="gem-form__label">
                Criador / Banco
                <span v-if="editingInase" class="field-lock-label">🔒 Protegido</span>
              </label>
              <input
                v-model.trim="form.criador"
                class="gem-form__input"
                :class="{ 'field-locked': editingInase }"
                :disabled="editingInase"
                placeholder="Ej: Sweed Lab Seeds…"
              />
            </div>

            <!-- Origen -->
            <div class="gem-form__field gem-form__field--half">
              <label class="gem-form__label">Origen</label>
              <input v-model.trim="form.origen" class="gem-form__input" placeholder="Ej: Argentina, California…" />
            </div>

            <!-- Terpenos -->
            <div class="gem-form__field gem-form__field--full">
              <label class="gem-form__label">Terpenos</label>
              <input v-model.trim="form.terpenos" class="gem-form__input" placeholder="Ej: Mirceno, Limoneno, Cariofileno…" />
            </div>

            <!-- Declaración ante el INASE. No aparece para las variedades que YA están
                 inscriptas: esas no se declaran contra nada, son el destino. -->
            <div v-if="!editingInase" class="gem-form__field gem-form__field--full">
              <label class="gem-form__label">
                Se declara ante el INASE como
                <span class="gem-form__label-hint">(opcional)</span>
              </label>
              <select v-model="form.declarada_como_id" class="gem-form__input">
                <option :value="null">Sin declarar</option>
                <option v-for="v in variedadesInase" :key="v.id" :value="v.id">
                  {{ v.nombre }}{{ v.numero_registro_inase ? ` · ${v.numero_registro_inase}` : '' }}
                </option>
              </select>
              <p class="gem-form__hint">
                Los informes regulatorios (INASE, REPROCANN, trazabilidad y semestral) van a
                nombrar esta genética con la variedad inscripta que elijas. Adentro de la organización
                se sigue llamando <strong>{{ form.nombre || 'como vos le pusiste' }}</strong>.
              </p>
            </div>

            <!-- Disponible -->
            <div class="gem-form__field gem-form__field--full">
              <label class="gem-form__toggle">
                <input v-model="form.disponible" type="checkbox" class="gem-form__toggle-input" />
                <span class="gem-form__toggle-track"></span>
                <span class="gem-form__toggle-label">Disponible para cultivo</span>
              </label>
            </div>

            <!-- Descripción -->
            <div class="gem-form__field gem-form__field--full">
              <label class="gem-form__label">Descripción <span class="gem-form__label-hint">(interna)</span></label>
              <textarea v-model.trim="form.descripcion" class="gem-form__input gem-form__textarea" rows="3" placeholder="Características, efectos, sabor, aromas…"></textarea>
            </div>

            <!-- Consejos de la organización -->
            <div class="gem-form__field gem-form__field--full">
              <label class="gem-form__label">Consejos de la organización <span class="gem-form__label-hint">👁 visible al paciente</span></label>
              <textarea v-model.trim="form.consejos_club" class="gem-form__input gem-form__textarea" rows="3" placeholder="Guardado ideal, qué hacer al recibir el producto, recomendaciones…"></textarea>
            </div>

          </div>
        </div>
        <div class="gem-modal__footer">
          <button class="gem-btn-ghost" :disabled="saving" @click="showModal = false">Cancelar</button>
          <button class="gem-btn-new" :disabled="saving" @click="handleSubmit">
            <DsSpinner v-if="saving" :size="14" />
            {{ editingId ? 'Guardar cambios' : 'Crear genética' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api, { getGenetica, createGenetica, updateGenetica, listGeneticas } from '../lib/api.js'
import DsSpinner from '../design-system/components/Spinner.vue'

const emit = defineEmits(['saved'])

const TIPO_META = {
  indica:  { label: 'Índica',  color: '#6f42c1' },
  sativa:  { label: 'Sativa',  color: '#198754' },
  hibrida: { label: 'Híbrida', color: '#fd7e14' },
}

const showModal    = ref(false)
const saving       = ref(false)
const editingId    = ref(null)
const editingInase = ref(false)
const formError    = ref(null)
const formErrors   = ref({})
const fotoFile     = ref(null)
const fotoPreview  = ref(null)
const fotoInput    = ref(null)

// Catálogo contra el que se declara: las variedades inscriptas en el INASE, que son globales
// (no se duplican por club) y ya vienen en el listado normal de genéticas.
const variedadesInase = ref([])
onMounted(async () => {
  try {
    const { data } = await listGeneticas()
    variedadesInase.value = (data || []).filter(g => g.registrada_inase)
  } catch { variedadesInase.value = [] }
})

function emptyForm() {
  return {
    nombre: '', tipo: '', thc: null, cbd: null,
    descripcion: '', consejos_club: '', origen: '', criador: '', terpenos: '',
    tiempo_floracion: null, dias_vegetativo_objetivo: null, dias_cosecha_objetivo: null,
    rendimiento: null, altura: null, disponible: true, declarada_como_id: null,
  }
}
const form = ref(emptyForm())

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

// Acepta el objeto genética o su id. Siempre trae el detalle completo para no cargar
// el form vacío (el item de la lista no trae descripción/consejos/objetivos/origen).
async function openEdit(genOrId) {
  const id = typeof genOrId === 'object' ? genOrId.id : Number(genOrId)
  let gen = typeof genOrId === 'object' ? genOrId : null
  try { const { data } = await getGenetica(id); gen = data } catch { /* usamos lo que haya */ }
  if (!gen) return
  editingId.value    = gen.id
  editingInase.value = !!gen.registrada_inase
  form.value = {
    nombre:           gen.nombre           || '',
    tipo:             gen.tipo             || '',
    thc:              gen.thc              ?? null,
    cbd:              gen.cbd              ?? null,
    descripcion:      gen.descripcion      || '',
    consejos_club:    gen.consejos_club    || '',
    origen:           gen.origen           || '',
    criador:          gen.criador          || '',
    terpenos:         gen.terpenos         || '',
    tiempo_floracion: gen.tiempo_floracion ?? null,
    dias_vegetativo_objetivo: gen.dias_vegetativo_objetivo ?? null,
    dias_cosecha_objetivo:    gen.dias_cosecha_objetivo    ?? null,
    rendimiento:      gen.rendimiento      ?? null,
    altura:           gen.altura           ?? null,
    disponible:       gen.disponible       ?? true,
    declarada_como_id: gen.declarada_como_id ?? null,
  }
  formErrors.value  = {}
  formError.value   = null
  fotoFile.value    = null
  fotoPreview.value = gen.foto_url || null
  showModal.value   = true
}

async function handleSubmit() {
  if (!validate()) return
  saving.value    = true
  formError.value = null
  try {
    let result
    if (fotoFile.value) {
      const fd = new FormData()
      const payload = { ...form.value }
      if (editingInase.value) { delete payload.nombre; delete payload.tipo; delete payload.thc; delete payload.cbd; delete payload.criador }
      Object.entries(payload).forEach(([k, v]) => {
        if (v !== null && v !== '' && v !== undefined) fd.append(`genetica[${k}]`, v)
      })
      fd.append('foto', fotoFile.value)
      result = editingId.value
        ? await api.patch(`/geneticas/${editingId.value}`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
        : await api.post('/geneticas', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
    } else {
      const payload = { ...form.value }
      if (editingInase.value) { delete payload.nombre; delete payload.tipo; delete payload.thc; delete payload.cbd; delete payload.criador }
      Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
      result = editingId.value
        ? await updateGenetica(editingId.value, payload)
        : await createGenetica(payload)
    }
    emit('saved', { genetica: result.data, created: !editingId.value })
    showModal.value = false
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally {
    saving.value = false
  }
}

defineExpose({ openCreate, openEdit })
</script>

<style scoped>
.gem-overlay { position: fixed; inset: 0; background: rgba(15,23,42,.55); z-index: 1000; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.gem-modal { background: #fff; border-radius: 16px; width: 100%; max-width: 680px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.25); }
.gem-modal__header { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; padding: 1.25rem 1.5rem; border-bottom: 1px solid #e5e7eb; flex-shrink: 0; }
.gem-modal__title    { font-size: 1rem; font-weight: 700; color: var(--c-slate-900); margin: 0; }
.gem-modal__subtitle { font-size: .78rem; color: var(--c-slate-500); display: block; margin-top: .1rem; }
.gem-modal__close    { background: none; border: none; cursor: pointer; color: var(--c-slate-400); font-size: 1rem; padding: .2rem; border-radius: 6px; transition: all .15s; flex-shrink: 0; }
.gem-modal__close:hover { background: var(--c-slate-100); color: var(--c-slate-600); }
.gem-modal__body  { overflow-y: auto; padding: 1.25rem 1.5rem; flex: 1; }
.gem-modal__footer { display: flex; justify-content: flex-end; gap: .75rem; padding: 1rem 1.5rem; border-top: 1px solid #e5e7eb; flex-shrink: 0; }
.gem-modal__inase-notice { margin-bottom: 1.25rem; }
.gem-modal__error { display: flex; align-items: center; gap: .5rem; margin-bottom: 1rem; }

.gem-error { background: #fef2f2; border: 1px solid #fecaca; color: #b91c1c; padding: .875rem 1rem; border-radius: 10px; }

.gem-btn-new { display: inline-flex; align-items: center; gap: .4rem; background: #1a3d2e; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; transition: background .15s; white-space: nowrap; }
.gem-btn-new:hover { background: #0f2a1e; }
.gem-btn-ghost { background: #fff; border: 1.5px solid var(--c-slate-200); color: var(--c-slate-500); padding: .5rem 1rem; border-radius: 8px; font-size: .82rem; cursor: pointer; }
.gem-btn-ghost:hover { background: var(--c-slate-50); }

.gem-form { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: .875rem; }
.gem-form__field { display: flex; flex-direction: column; gap: .3rem; }
.gem-form__field--full { grid-column: 1 / -1; }
.gem-form__field--half { grid-column: span 1; }
@media (max-width: 560px) { .gem-form { grid-template-columns: 1fr; } .gem-form__field--full, .gem-form__field--half { grid-column: 1; } }
.gem-form__label     { font-size: .8rem; font-weight: 600; color: #374151; }
.gem-form__label-hint { font-size: .7rem; font-weight: 500; color: var(--c-slate-400); }
.gem-form__hint { margin: .4rem 0 0; font-size: .74rem; line-height: 1.45; color: var(--c-slate-500); }
.gem-form__hint strong { color: var(--c-slate-700); font-weight: 600; }
.gem-form__req       { color: #dc2626; }
.gem-form__input     { padding: .5rem .7rem; border: 1.5px solid var(--c-slate-200); border-radius: 8px; font-size: .875rem; color: #1e293b; background: #fff; outline: none; transition: border-color .15s; width: 100%; box-sizing: border-box; }
.gem-form__input:focus { border-color: #1a3d2e; }
.gem-form__input--error { border-color: #ef4444; }
.gem-form__textarea  { resize: vertical; min-height: 80px; }
.gem-form__field-error { font-size: .75rem; color: #ef4444; }

.gem-form__btn-group  { display: flex; flex-wrap: wrap; gap: .35rem; }
.gem-form__tipo-btn   { padding: .35rem .7rem; border: 1.5px solid var(--c-slate-200); border-radius: 7px; font-size: .78rem; font-weight: 500; background: #fff; color: #374151; cursor: pointer; transition: all .15s; }
.gem-form__tipo-btn:hover:not(:disabled) { border-color: var(--c-slate-400); }
.gem-form__tipo-btn:disabled { opacity: .45; cursor: not-allowed; }

.gem-form__toggle       { display: inline-flex; align-items: center; gap: .65rem; cursor: pointer; }
.gem-form__toggle-input { position: absolute; opacity: 0; width: 0; height: 0; }
.gem-form__toggle-track { width: 40px; height: 22px; border-radius: 11px; background: var(--c-slate-200); position: relative; transition: background .2s; flex-shrink: 0; }
.gem-form__toggle-track::after { content: ''; position: absolute; top: 3px; left: 3px; width: 16px; height: 16px; border-radius: 50%; background: #fff; transition: transform .2s; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
.gem-form__toggle-input:checked + .gem-form__toggle-track { background: #1a3d2e; }
.gem-form__toggle-input:checked + .gem-form__toggle-track::after { transform: translateX(18px); }
.gem-form__toggle-label { font-size: .875rem; color: #374151; }

.inase-notice { display: flex; align-items: flex-start; gap: .875rem; background: rgba(27,94,32,.06); border: 1px solid rgba(27,94,32,.2); border-radius: 12px; padding: 1rem 1.1rem; }
.inase-notice__icon { font-size: 1.5rem; flex-shrink: 0; }
.inase-notice__title { font-size: .875rem; font-weight: 700; color: #1b5e20; margin-bottom: .2rem; }
.inase-notice__desc { font-size: .78rem; color: #374151; line-height: 1.55; }
.field-lock-label { font-size: .68rem; color: #9ca3af; font-weight: 400; margin-left: .25rem; }
.field-locked { background-color: #f9fafb !important; color: #9ca3af !important; cursor: not-allowed; border-color: #e5e7eb !important; }

.foto-uploader { display: flex; align-items: center; gap: 1rem; }
.foto-preview { position: relative; width: 120px; height: 90px; border-radius: 10px; overflow: hidden; border: 1.5px solid #e5e7eb; }
.foto-preview img { width: 100%; height: 100%; object-fit: cover; }
.foto-remove { position: absolute; top: 4px; right: 4px; width: 22px; height: 22px; border-radius: 50%; background: rgba(0,0,0,.6); color: white; border: none; display: flex; align-items: center; justify-content: center; font-size: .65rem; cursor: pointer; }
.foto-placeholder { width: 120px; height: 90px; border-radius: 10px; border: 1.5px dashed #d1d5db; display: flex; flex-direction: column; align-items: center; justify-content: center; cursor: pointer; transition: border-color .15s; }
.foto-placeholder:hover { border-color: #1b5e20; }
</style>
