<template>
  <div class="miv">

    <!-- Header -->
    <div class="miv__header">
      <div>
        <h1 class="miv__title">Indicaciones médicas</h1>
        <p class="miv__sub">Prescripciones activas y vencidas de todos los pacientes</p>
      </div>
      <button class="miv__btn-primary" @click="openNew">
        <Plus :size="15" :stroke-width="1.75" /> Nueva indicación
      </button>
    </div>

    <!-- Filtros rápidos -->
    <div class="miv__filters">
      <button
        v-for="f in FILTROS"
        :key="f.key"
        class="miv__filter-btn"
        :class="{ 'miv__filter-btn--active': filtro === f.key, [`miv__filter-btn--${f.color}`]: filtro === f.key }"
        @click="filtro = f.key"
      >
        {{ f.label }}
        <span v-if="conteos[f.key]" class="miv__filter-count">{{ conteos[f.key] }}</span>
      </button>
    </div>

    <!-- Toolbar -->
    <div class="miv__toolbar">
      <div class="miv__search-wrap">
        <Search :size="16" class="miv__search-icon" />
        <input v-model="search" class="miv__search" placeholder="Buscar paciente o patología…" />
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="miv__loading">
      <DsSpinner :size="20" /> Cargando indicaciones…
    </div>

    <!-- Empty -->
    <div v-else-if="!filtradas.length" class="miv__empty">
      <FileHeart :size="40" :stroke-width="1" />
      <p>{{ search ? 'Sin resultados para tu búsqueda' : 'No hay indicaciones en este filtro' }}</p>
      <button v-if="!search && filtro === 'todas'" class="miv__btn-primary" @click="openNew">
        <Plus :size="15" /> Crear primera indicación
      </button>
    </div>

    <!-- Tabla -->
    <div v-else class="miv__table-wrap">
      <table class="miv__table">
        <thead>
          <tr>
            <th>Paciente</th>
            <th>Patología</th>
            <th>Dosificación</th>
            <th>Vía</th>
            <th>Vencimiento</th>
            <th>Estado</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="ind in filtradas" :key="ind.id" class="miv__tr">
            <td>
              <RouterLink :to="`/medico/pacientes/${ind.paciente?.id}`" class="miv__pac-link" @click.stop>
                {{ ind.paciente?.nombre_completo || '—' }}
              </RouterLink>
            </td>
            <td class="miv__td-patologia">{{ ind.patologia }}</td>
            <td class="miv__td-dosis">{{ ind.dosificacion }}</td>
            <td>
              <span class="miv__via-badge">{{ ind.via_administracion }}</span>
            </td>
            <td class="miv__td-fecha">{{ formatDate(ind.fecha_vencimiento) }}</td>
            <td>
              <span class="miv__estado-badge" :class="estadoClass(ind)">{{ estadoLabel(ind) }}</span>
            </td>
            <td class="miv__td-actions">
              <button class="miv__action-btn" @click="openEdit(ind)" title="Editar">
                <Pencil :size="14" />
              </button>
              <button class="miv__action-btn miv__action-btn--danger" @click="eliminar(ind)" title="Eliminar">
                <Trash2 :size="14" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Modal create/edit -->
    <Teleport to="body">
      <div v-if="showModal" class="miv__overlay" @click.self="closeModal">
        <div class="miv__modal">
          <div class="miv__modal-header">
            <h2 class="miv__modal-title">{{ editing ? 'Editar indicación' : 'Nueva indicación' }}</h2>
            <button class="miv__modal-close" @click="closeModal"><X :size="18" /></button>
          </div>
          <div class="miv__modal-body">
            <div v-if="formError" class="miv__form-error">{{ formError }}</div>
            <div class="miv__form-grid">

              <!-- Selector de paciente (solo al crear) -->
              <div v-if="!editing" class="miv__form-field miv__form-field--full" :class="{ 'miv__form-field--error': formErrors.paciente_id }">
                <label>Paciente <span class="miv__req">*</span></label>
                <select v-model="form.paciente_id">
                  <option value="">— Seleccionar paciente —</option>
                  <option v-for="p in pacientesStore.items" :key="p.id" :value="p.id">
                    {{ p.nombre }} {{ p.apellido }} — {{ p.dni }}
                  </option>
                </select>
                <span v-if="formErrors.paciente_id" class="miv__field-err">{{ formErrors.paciente_id }}</span>
              </div>

              <div class="miv__form-field miv__form-field--full" :class="{ 'miv__form-field--error': formErrors.patologia }">
                <label>Patología <span class="miv__req">*</span></label>
                <input v-model="form.patologia" type="text" placeholder="PTSD, Dolor crónico, Epilepsia…" />
                <span v-if="formErrors.patologia" class="miv__field-err">{{ formErrors.patologia }}</span>
              </div>

              <div class="miv__form-field miv__form-field--full" :class="{ 'miv__form-field--error': formErrors.dosificacion }">
                <label>Dosificación <span class="miv__req">*</span></label>
                <input v-model="form.dosificacion" type="text" placeholder="Ej: 10mg CBD + 1mg THC, 2 veces al día" />
                <span v-if="formErrors.dosificacion" class="miv__field-err">{{ formErrors.dosificacion }}</span>
              </div>

              <div class="miv__form-field" :class="{ 'miv__form-field--error': formErrors.via_administracion }">
                <label>Vía de administración <span class="miv__req">*</span></label>
                <select v-model="form.via_administracion">
                  <option value="">— Seleccionar —</option>
                  <option value="oral">Oral</option>
                  <option value="sublingual">Sublingual</option>
                  <option value="inhalada">Inhalada</option>
                  <option value="topica">Tópica</option>
                  <option value="vaporizacion">Vaporización</option>
                </select>
                <span v-if="formErrors.via_administracion" class="miv__field-err">{{ formErrors.via_administracion }}</span>
              </div>

              <div class="miv__form-field">
                <label>Duración (días)</label>
                <input v-model.number="form.duracion_dias" type="number" min="1" placeholder="90" />
              </div>

              <div class="miv__form-field">
                <label>Fecha de emisión</label>
                <input v-model="form.fecha_emision" type="date" />
              </div>

              <div class="miv__form-field">
                <label>Fecha de vencimiento</label>
                <input v-model="form.fecha_vencimiento" type="date" />
              </div>

              <div class="miv__form-field miv__form-field--full">
                <label>Observaciones clínicas</label>
                <textarea v-model="form.observaciones" rows="3" placeholder="Notas adicionales, instrucciones especiales…"></textarea>
              </div>

            </div>
          </div>
          <div class="miv__modal-footer">
            <button class="miv__btn-ghost" @click="closeModal">Cancelar</button>
            <button class="miv__btn-primary" @click="save" :disabled="saving">
              {{ saving ? 'Guardando…' : (editing ? 'Guardar cambios' : 'Crear indicación') }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { Search, Plus, Pencil, Trash2, X, FileHeart } from 'lucide-vue-next'
import { createIndicacion, updateIndicacion, deleteIndicacion } from '../../lib/api.js'
import { usePacientesStore } from '../../stores/pacientes.js'
import { useConfirm } from '../../composables/useConfirm.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { useToast } from '../../composables/useToast.js'
import api from '../../lib/api.js'

const pacientesStore = usePacientesStore()
const { confirm }    = useConfirm()
const { success: toastOk, error: toastErr } = useToast()

const loading    = ref(false)
const indicaciones = ref([])
const search     = ref('')
const filtro     = ref('todas')
const showModal  = ref(false)
const editing    = ref(false)
const editingId  = ref(null)
const saving     = ref(false)
const formError  = ref(null)
const formErrors = ref({})

const FILTROS = [
  { key: 'todas',     label: 'Todas',          color: 'green'  },
  { key: 'activas',   label: 'Activas',         color: 'ok'     },
  { key: 'por_vencer',label: 'Por vencer',      color: 'warn'   },
  { key: 'vencidas',  label: 'Vencidas',        color: 'danger' },
]

function emptyForm() {
  return {
    paciente_id: '', patologia: '', dosificacion: '', via_administracion: '',
    duracion_dias: '', fecha_emision: '', fecha_vencimiento: '', observaciones: '',
  }
}
const form = ref(emptyForm())

function validate() {
  const e = {}
  if (!editing.value && !form.value.paciente_id) e.paciente_id = 'Seleccioná un paciente'
  if (!form.value.patologia.trim())       e.patologia = 'Obligatorio'
  if (!form.value.dosificacion.trim())    e.dosificacion = 'Obligatorio'
  if (!form.value.via_administracion)     e.via_administracion = 'Seleccioná una vía'
  formErrors.value = e
  return !Object.keys(e).length
}

function openNew() {
  editing.value    = false
  editingId.value  = null
  form.value       = emptyForm()
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function openEdit(ind) {
  editing.value    = true
  editingId.value  = ind.id
  form.value = {
    paciente_id:       ind.paciente?.id || '',
    patologia:         ind.patologia        || '',
    dosificacion:      ind.dosificacion     || '',
    via_administracion: ind.via_administracion || '',
    duracion_dias:     ind.duracion_dias    || '',
    fecha_emision:     ind.fecha_emision?.slice(0, 10)    || '',
    fecha_vencimiento: ind.fecha_vencimiento?.slice(0, 10) || '',
    observaciones:     ind.observaciones    || '',
  }
  formErrors.value = {}
  formError.value  = null
  showModal.value  = true
}

function closeModal() { showModal.value = false }

async function save() {
  if (!validate()) return
  saving.value     = true
  formError.value  = null
  const payload = { ...form.value }
  Object.keys(payload).forEach(k => { if (payload[k] === '' || payload[k] === null) delete payload[k] })
  try {
    if (editing.value) {
      await updateIndicacion(editingId.value, payload)
      toastOk('Indicación actualizada')
    } else {
      await createIndicacion(form.value.paciente_id, payload)
      toastOk('Indicación creada correctamente')
    }
    await cargar()
    closeModal()
  } catch (e) {
    const msgs = e?.response?.data?.errors
    formError.value = Array.isArray(msgs) ? msgs.join(', ') : 'Error al guardar. Verificá los datos.'
  } finally {
    saving.value = false
  }
}

async function eliminar(ind) {
  const nombre = ind.paciente?.nombre_completo || 'este paciente'
  const ok = await confirm({
    title: 'Eliminar indicación',
    message: `¿Eliminar la indicación de ${nombre} (${ind.patologia})? Esta acción no se puede deshacer.`,
    confirmText: 'Eliminar',
    variant: 'danger',
  })
  if (!ok) return
  try {
    await deleteIndicacion(ind.id)
    indicaciones.value = indicaciones.value.filter(i => i.id !== ind.id)
    toastOk('Indicación eliminada')
  } catch {
    toastErr('No se pudo eliminar la indicación')
  }
}

async function cargar() {
  loading.value = true
  try {
    const res = await api.get('/indicaciones_medicas')
    indicaciones.value = res.data ?? []
  } finally {
    loading.value = false
  }
}

function safeDate(d) {
  if (!d) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d)
}
function formatDate(d) {
  if (!d) return '—'
  return safeDate(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function estadoInd(ind) {
  if (!ind.activa) return 'inactiva'
  if (!ind.fecha_vencimiento) return 'activa'
  const hoy  = new Date()
  const venc = safeDate(ind.fecha_vencimiento)
  if (venc < hoy) return 'vencida'
  const dias = Math.floor((venc - hoy) / 86400000)
  if (dias <= 30) return 'por_vencer'
  return 'activa'
}
function estadoLabel(ind) {
  return { activa: 'Activa', vencida: 'Vencida', por_vencer: 'Por vencer', inactiva: 'Inactiva' }[estadoInd(ind)] || '—'
}
function estadoClass(ind) {
  return {
    'miv__est--ok':   estadoInd(ind) === 'activa',
    'miv__est--warn': estadoInd(ind) === 'por_vencer',
    'miv__est--err':  estadoInd(ind) === 'vencida',
    'miv__est--gray': estadoInd(ind) === 'inactiva',
  }
}

const conteos = computed(() => ({
  todas:      indicaciones.value.length,
  activas:    indicaciones.value.filter(i => estadoInd(i) === 'activa').length,
  por_vencer: indicaciones.value.filter(i => estadoInd(i) === 'por_vencer').length,
  vencidas:   indicaciones.value.filter(i => estadoInd(i) === 'vencida').length,
}))

const filtradas = computed(() => {
  let list = indicaciones.value
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(i =>
      (i.paciente?.nombre_completo || '').toLowerCase().includes(q) ||
      (i.patologia || '').toLowerCase().includes(q)
    )
  }
  if (filtro.value !== 'todas') list = list.filter(i => estadoInd(i) === filtro.value)
  return list
})

onMounted(async () => {
  await Promise.all([cargar(), pacientesStore.fetch()])
})
</script>

<style scoped>
.miv { padding: var(--sp-6); max-width: 1000px; }

/* Header */
.miv__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: var(--sp-4); margin-bottom: var(--sp-5); flex-wrap: wrap;
}
.miv__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.miv__sub   { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0; }

/* Botones */
.miv__btn-primary {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  background: #2D8A6B; color: #fff; border: none; border-radius: var(--r-md);
  padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13); font-weight: 600;
  cursor: pointer; transition: background .15s;
}
.miv__btn-primary:hover    { background: #236e55; }
.miv__btn-primary:disabled { opacity: .6; cursor: default; }
.miv__btn-ghost {
  background: none; border: 1px solid var(--c-ink-200); color: var(--c-ink-600);
  border-radius: var(--r-md); padding: var(--sp-2) var(--sp-4); font-size: var(--fs-13);
  cursor: pointer; transition: all .15s;
}
.miv__btn-ghost:hover { background: var(--c-ink-50); }

/* Filtros */
.miv__filters { display: flex; gap: var(--sp-2); flex-wrap: wrap; margin-bottom: var(--sp-4); }
.miv__filter-btn {
  display: inline-flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-1) var(--sp-3); border-radius: 999px;
  border: 1px solid var(--c-ink-200); background: var(--c-paper);
  font-size: var(--fs-13); color: var(--c-ink-600); cursor: pointer; transition: all .15s;
}
.miv__filter-btn:hover { border-color: var(--c-ink-400); }
.miv__filter-btn--active.miv__filter-btn--green  { border-color: #2D8A6B; background: rgba(45,138,107,.1); color: #2D8A6B; }
.miv__filter-btn--active.miv__filter-btn--ok     { border-color: #15803d; background: rgba(21,128,61,.1);  color: #15803d; }
.miv__filter-btn--active.miv__filter-btn--warn   { border-color: #d97706; background: rgba(217,119,6,.1);  color: #d97706; }
.miv__filter-btn--active.miv__filter-btn--danger { border-color: #dc2626; background: rgba(220,38,38,.1);  color: #dc2626; }
.miv__filter-count {
  background: var(--c-ink-100); color: var(--c-ink-600);
  font-size: var(--fs-11); font-weight: 700; padding: 0 5px; border-radius: 999px;
}

/* Toolbar */
.miv__toolbar { margin-bottom: var(--sp-4); }
.miv__search-wrap { position: relative; display: flex; align-items: center; max-width: 380px; }
.miv__search-icon { position: absolute; left: var(--sp-3); color: var(--c-ink-400); pointer-events: none; }
.miv__search {
  width: 100%; padding: var(--sp-2) var(--sp-3) var(--sp-2) calc(var(--sp-3) + 20px + var(--sp-2));
  background: var(--c-paper); border: 1px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-ink-800); outline: none; transition: border-color .15s;
}
.miv__search:focus { border-color: #2D8A6B; }

/* Loading / empty */
.miv__loading {
  display: flex; align-items: center; gap: var(--sp-3);
  color: var(--c-ink-500); padding: var(--sp-8); font-size: var(--fs-14);
}
.miv__empty {
  display: flex; flex-direction: column; align-items: center; gap: var(--sp-3);
  padding: var(--sp-12) var(--sp-6); color: var(--c-ink-300); text-align: center;
}
.miv__empty p { font-size: var(--fs-14); color: var(--c-ink-500); margin: 0; }

/* Tabla */
.miv__table-wrap { overflow-x: auto; border-radius: var(--r-lg); border: 1px solid var(--c-ink-100); }
.miv__table { width: 100%; border-collapse: collapse; background: var(--c-paper); }
.miv__table thead th {
  text-align: left; padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-12); font-weight: 700; color: var(--c-ink-500);
  text-transform: uppercase; letter-spacing: .04em;
  background: var(--c-ink-50); border-bottom: 1px solid var(--c-ink-100);
}
.miv__tr td {
  padding: var(--sp-3) var(--sp-4); font-size: var(--fs-13); color: var(--c-ink-800);
  border-bottom: 1px solid var(--c-ink-50); vertical-align: middle;
}
.miv__tr:last-child td { border-bottom: none; }
.miv__tr:hover td { background: rgba(45,138,107,.03); }

.miv__pac-link { font-weight: 600; color: var(--c-ink-900); text-decoration: none; }
.miv__pac-link:hover { color: #2D8A6B; text-decoration: underline; }
.miv__td-patologia { max-width: 160px; }
.miv__td-dosis     { max-width: 180px; color: var(--c-ink-600); }
.miv__td-fecha     { white-space: nowrap; color: var(--c-ink-500); }

.miv__via-badge {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-11); font-weight: 600; background: var(--c-ink-100); color: var(--c-ink-600);
}

.miv__estado-badge {
  display: inline-block; padding: 2px 8px; border-radius: 999px;
  font-size: var(--fs-11); font-weight: 600;
}
.miv__est--ok   { background: rgba(21,128,61,.1);  color: #15803d; }
.miv__est--warn { background: rgba(217,119,6,.1);  color: #d97706; }
.miv__est--err  { background: rgba(220,38,38,.1);  color: #dc2626; }
.miv__est--gray { background: var(--c-ink-100);    color: var(--c-ink-500); }

.miv__td-actions { white-space: nowrap; width: 70px; }
.miv__action-btn {
  width: 28px; height: 28px; border-radius: var(--r-sm); border: none;
  display: inline-flex; align-items: center; justify-content: center;
  cursor: pointer; transition: all .15s; background: transparent; color: var(--c-ink-400);
}
.miv__action-btn:hover              { background: var(--c-ink-100); color: var(--c-ink-700); }
.miv__action-btn--danger:hover      { background: rgba(220,38,38,.1); color: #dc2626; }

/* Modal */
.miv__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.4); z-index: 1000;
  display: flex; align-items: center; justify-content: center; padding: var(--sp-4);
}
.miv__modal {
  background: var(--c-paper); border-radius: var(--r-xl); width: 100%; max-width: 580px;
  box-shadow: 0 20px 60px rgba(0,0,0,.2); display: flex; flex-direction: column; max-height: 90vh;
}
.miv__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: var(--sp-5) var(--sp-6); border-bottom: 1px solid var(--c-ink-100);
}
.miv__modal-title { font-size: var(--fs-16); font-weight: 700; color: var(--c-ink-900); margin: 0; }
.miv__modal-close {
  background: none; border: none; color: var(--c-ink-400); cursor: pointer;
  display: flex; align-items: center; padding: var(--sp-1); border-radius: var(--r-sm);
}
.miv__modal-close:hover { background: var(--c-ink-50); color: var(--c-ink-700); }
.miv__modal-body { padding: var(--sp-5) var(--sp-6); overflow-y: auto; flex: 1; }
.miv__modal-footer {
  display: flex; justify-content: flex-end; gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-6); border-top: 1px solid var(--c-ink-100);
}

/* Formulario */
.miv__form-error {
  background: rgba(220,38,38,.08); border: 1px solid rgba(220,38,38,.2);
  color: #dc2626; border-radius: var(--r-md); padding: var(--sp-3) var(--sp-4);
  font-size: var(--fs-13); margin-bottom: var(--sp-4);
}
.miv__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); }
.miv__form-field { display: flex; flex-direction: column; gap: var(--sp-1); }
.miv__form-field--full { grid-column: 1 / -1; }
.miv__form-field label { font-size: var(--fs-12); font-weight: 600; color: var(--c-ink-600); }
.miv__req { color: #dc2626; }
.miv__form-field input,
.miv__form-field select,
.miv__form-field textarea {
  padding: var(--sp-2) var(--sp-3); background: var(--c-bg);
  border: 1px solid var(--c-ink-200); border-radius: var(--r-md);
  font-size: var(--fs-14); color: var(--c-ink-800); outline: none;
  transition: border-color .15s; font-family: inherit;
}
.miv__form-field input:focus,
.miv__form-field select:focus,
.miv__form-field textarea:focus { border-color: #2D8A6B; }
.miv__form-field--error input,
.miv__form-field--error select { border-color: #dc2626; }
.miv__field-err { font-size: var(--fs-11); color: #dc2626; }
.miv__form-field textarea { resize: vertical; }
</style>
