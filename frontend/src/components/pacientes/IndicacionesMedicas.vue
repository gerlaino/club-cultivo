<template>
  <div class="im__wrap">
    <div class="im__header">
      <h5 class="im__title">Indicaciones Médicas</h5>
      <button v-if="canCreate" class="im__btn-primary" @click="showModal = true; resetForm()">
        + Nueva Indicación
      </button>
    </div>

    <!-- Consumo dispensado: el contexto con el que se lee (y se escribe) una indicación -->
    <div v-if="resumenConsumo && !loading" class="im__consumo">
      <div class="im__consumo-stat">
        <span class="im__consumo-val">{{ resumenConsumo.total_g_90d }} g</span>
        <span class="im__consumo-lbl">últimos 90 días</span>
      </div>
      <span class="im__consumo-sep"></span>
      <div class="im__consumo-stat">
        <span class="im__consumo-val">{{ resumenConsumo.promedio_mensual_g }} g</span>
        <span class="im__consumo-lbl">promedio mensual</span>
      </div>
      <span class="im__consumo-sep"></span>
      <div class="im__consumo-stat">
        <span class="im__consumo-val">{{ resumenConsumo.total_dispensaciones }}</span>
        <span class="im__consumo-lbl">dispensaciones</span>
      </div>
      <div v-if="sparkline" class="im__sparkline" aria-hidden="true">
        <svg viewBox="0 0 120 32" preserveAspectRatio="none">
          <polyline :points="sparkline" fill="none" stroke="currentColor"
                    stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="im__loading">
      <DsSpinner :size="18" />
    </div>

    <!-- Lista vacía -->
    <div v-else-if="indicaciones.length === 0" class="im__empty">
      <span class="im__empty-icon">📋</span>
      <p>No hay indicaciones médicas registradas</p>
    </div>

    <!-- Lista de indicaciones -->
    <div v-else class="im__list">
      <div
        v-for="ind in indicaciones"
        :key="ind.id"
        class="im__card"
        :class="{
          'im__card--vencida': ind.vencida,
          'im__card--warning': ind.por_vencer,
          'im__card--activa': ind.activa && !ind.vencida && !ind.por_vencer
        }"
      >
        <div class="im__card-top">
          <div>
            <p class="im__card-patologia">{{ ind.patologia }}</p>
            <p class="im__card-medico">{{ ind.medico.nombre }}</p>
          </div>
          <span
            class="im__badge"
            :class="{
              'im__badge--danger': ind.vencida,
              'im__badge--warning': ind.por_vencer && !ind.vencida,
              'im__badge--success': ind.activa && !ind.vencida && !ind.por_vencer,
              'im__badge--neutral': !ind.activa
            }"
          >
            <template v-if="ind.vencida">Vencida</template>
            <template v-else-if="ind.por_vencer">Por vencer ({{ ind.dias_hasta_vencimiento }}d)</template>
            <template v-else-if="ind.activa">Activa</template>
            <template v-else>Inactiva</template>
          </span>
        </div>

        <div class="im__card-meta">
          <div class="im__meta-item">
            <span class="im__meta-label">Dosificación</span>
            <span class="im__meta-val">{{ ind.dosificacion }}</span>
          </div>
          <div class="im__meta-item">
            <span class="im__meta-label">Vía</span>
            <span class="im__meta-val" style="text-transform:capitalize">{{ ind.via_administracion }}</span>
          </div>
          <div class="im__meta-item">
            <span class="im__meta-label">Emisión</span>
            <span class="im__meta-val">{{ formatDate(ind.fecha_emision) }}</span>
          </div>
          <div v-if="ind.fecha_vencimiento" class="im__meta-item">
            <span class="im__meta-label">Vence</span>
            <span class="im__meta-val">
              {{ formatDate(ind.fecha_vencimiento) }}
              <span v-if="ind.vencimiento_calculado" class="im__meta-nota">
                · {{ ind.duracion_dias }} días de tratamiento
              </span>
            </span>
          </div>
          <div v-else class="im__meta-item">
            <span class="im__meta-label">Vence</span>
            <span class="im__meta-val im__meta-val--muted">Sin fecha — no genera alertas</span>
          </div>
        </div>

        <div v-if="canEdit" class="im__card-actions">
          <button class="im__action-btn" @click="editIndicacion(ind)">Editar</button>
          <button class="im__action-btn im__action-btn--danger" @click="confirmDelete(ind)">Desactivar</button>
        </div>
      </div>
    </div>

    <!-- Modal Crear/Editar -->
    <Teleport to="body">
      <div v-if="showModal" class="im__overlay" @click.self="showModal = false">
        <div class="im__modal">
          <div class="im__modal-header">
            <h2 class="im__modal-title">{{ editingId ? 'Editar' : 'Nueva' }} Indicación Médica</h2>
            <button class="im__modal-close" @click="showModal = false">✕</button>
          </div>
          <div class="im__modal-body">
            <div v-if="formError" class="im__form-error">{{ formError }}</div>
            <div class="im__form-grid">
              <div class="im__form-field im__form-field--full">
                <label>PATOLOGÍA / DIAGNÓSTICO <span class="im__req">*</span></label>
                <input v-model="form.patologia" type="text" placeholder="Ej: Dolor crónico, Ansiedad, Epilepsia refractaria…" />
              </div>
              <div class="im__form-field im__form-field--full">
                <label>DOSIFICACIÓN <span class="im__req">*</span></label>
                <textarea v-model="form.dosificacion" rows="3" placeholder="Ej: 2 gotas sublinguales cada 8 horas…"></textarea>
              </div>
              <div class="im__form-field">
                <label>VÍA DE ADMINISTRACIÓN <span class="im__req">*</span></label>
                <select v-model="form.via_administracion">
                  <option value="">Seleccionar…</option>
                  <option value="oral">Oral</option>
                  <option value="sublingual">Sublingual</option>
                  <option value="inhalada">Inhalada</option>
                  <option value="topica">Tópica</option>
                  <option value="vaporizacion">Vaporización</option>
                </select>
              </div>
              <div class="im__form-field">
                <label>DURACIÓN (días)</label>
                <input v-model.number="form.duracion_dias" type="number" min="1" placeholder="Ej: 90, 180…" />
                <span class="im__hint">Cuánto dura el tratamiento</span>
              </div>
              <div class="im__form-field">
                <label>FECHA DE EMISIÓN <span class="im__req">*</span></label>
                <AppDatePicker v-model="form.fecha_emision" />
              </div>
              <div class="im__form-field">
                <label>FECHA DE VENCIMIENTO</label>
                <AppDatePicker v-model="form.fecha_vencimiento" />
                <span class="im__hint">{{ hintVencimiento }}</span>
              </div>
              <div class="im__form-field im__form-field--full">
                <label>OBSERVACIONES</label>
                <textarea v-model="form.observaciones" rows="2" placeholder="Notas adicionales, contraindicaciones, seguimiento…"></textarea>
              </div>
              <div class="im__form-field im__form-field--full">
                <label class="im__check-label">
                  <input v-model="form.activa" type="checkbox" class="im__check" />
                  Indicación activa
                </label>
              </div>
            </div>
          </div>
          <div class="im__modal-footer">
            <button class="im__btn-ghost" :disabled="saving" @click="showModal = false">Cancelar</button>
            <button class="im__btn-primary" :disabled="saving" @click="handleSubmit">
              <DsSpinner v-if="saving" :size="13" />
              {{ editingId ? 'Guardar cambios' : 'Crear indicación' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Modal confirmar desactivar -->
    <Teleport to="body">
      <div v-if="deleteConfirm" class="im__overlay" @click.self="deleteConfirm = null">
        <div class="im__modal" style="max-width:440px">
          <div class="im__modal-header">
            <h2 class="im__modal-title">Confirmar desactivación</h2>
            <button class="im__modal-close" @click="deleteConfirm = null">✕</button>
          </div>
          <div class="im__modal-body">
            <p class="im__confirm-text">
              ¿Desactivar la indicación para <strong>{{ deleteConfirm.patologia }}</strong>?
            </p>
            <p class="im__confirm-hint">La indicación se marcará como inactiva.</p>
          </div>
          <div class="im__modal-footer">
            <button class="im__btn-ghost" :disabled="deleting" @click="deleteConfirm = null">Cancelar</button>
            <button class="im__btn-danger" :disabled="deleting" @click="handleDelete">
              <DsSpinner v-if="deleting" :size="13" />
              Desactivar
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { logger } from '../../utils/logger.js'
import { useAuthStore } from '../../stores/auth'
import { listIndicaciones, createIndicacion, updateIndicacion, deleteIndicacion } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  socioId: { type: Number, required: true }
})

const auth = useAuthStore()
const toast = useToast()
const indicaciones = ref([])
const resumenConsumo = ref(null)
const loading = ref(true)
const showModal = ref(false)
const editingId = ref(null)
const saving = ref(false)
const deleting = ref(false)
const deleteConfirm = ref(null)
const formError = ref('')

const canCreate = computed(() => ['admin', 'medico', 'super_admin'].includes(auth.user?.role))
const canEdit   = computed(() => ['admin', 'medico', 'super_admin'].includes(auth.user?.role))

const form = ref({
  patologia: '',
  dosificacion: '',
  via_administracion: '',
  duracion_dias: null,
  fecha_emision: new Date().toISOString().split('T')[0],
  fecha_vencimiento: '',
  activa: true,
  observaciones: ''
})

const formatDate = (date) => {
  if (!date) return '-'
  return new Date(date).toLocaleDateString('es-AR', { year: 'numeric', month: 'long', day: 'numeric' })
}

// Sparkline del consumo: normalizado contra el mes más alto de la serie.
const sparkline = computed(() => {
  const serie = resumenConsumo.value?.serie_mensual || []
  if (serie.length < 2) return null
  const max = Math.max(...serie.map(m => m.gramos), 1)
  return serie
    .map((m, i) => `${(i / (serie.length - 1)) * 120},${32 - (m.gramos / max) * 28}`)
    .join(' ')
})

// La duración PROPONE el vencimiento; una fecha escrita a mano gana. El form tiene que
// decir cuál de las dos está mandando, porque antes el cálculo pisaba en silencio.
const vencimientoCalculado = computed(() => {
  const dias = Number(form.value.duracion_dias)
  if (!dias || !form.value.fecha_emision) return null
  const d = new Date(form.value.fecha_emision)
  if (Number.isNaN(d.getTime())) return null
  d.setDate(d.getDate() + dias)
  return d.toISOString().split('T')[0]
})

const hintVencimiento = computed(() => {
  const calc = vencimientoCalculado.value
  const actual = form.value.fecha_vencimiento
  if (!actual && calc)          return `Se va a calcular por la duración: ${formatDate(calc)}`
  if (!actual)                  return 'Dejar vacío si no vence — sin fecha no llegan alertas'
  if (calc && actual === calc)  return `Calculado por la duración (${form.value.duracion_dias} días)`
  if (calc)                     return 'Fijado a mano: la duración no lo va a modificar'
  return 'Fijado a mano'
})

const loadIndicaciones = async () => {
  try {
    loading.value = true
    const { data } = await listIndicaciones(props.socioId)
    indicaciones.value  = data.indicaciones || []
    resumenConsumo.value = data.resumen_consumo || null
  } catch (error) {
    logger.error('Error cargando indicaciones:', error)
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  editingId.value = null
  formError.value = ''
  form.value = {
    patologia: '',
    dosificacion: '',
    via_administracion: '',
    duracion_dias: null,
    fecha_emision: new Date().toISOString().split('T')[0],
    fecha_vencimiento: '',
    activa: true,
    observaciones: ''
  }
}

const editIndicacion = (ind) => {
  editingId.value = ind.id
  formError.value = ''
  form.value = {
    patologia: ind.patologia,
    dosificacion: ind.dosificacion,
    via_administracion: ind.via_administracion,
    duracion_dias: ind.duracion_dias,
    fecha_emision: ind.fecha_emision,
    fecha_vencimiento: ind.fecha_vencimiento || '',
    activa: ind.activa,
    observaciones: ind.observaciones || ''
  }
  showModal.value = true
}

const handleSubmit = async () => {
  formError.value = ''
  try {
    saving.value = true
    const payload = { ...form.value }
    Object.keys(payload).forEach(k => {
      if (payload[k] === '' || payload[k] === null) delete payload[k]
    })
    if (editingId.value) {
      await updateIndicacion(editingId.value, payload)
    } else {
      await createIndicacion(props.socioId, payload)
    }
    await loadIndicaciones()
    showModal.value = false
    resetForm()
  } catch (error) {
    logger.error('Error guardando indicación:', error)
    formError.value = error?.response?.data?.error || 'Error al guardar la indicación'
    toast.error('Error al guardar la indicación')
  } finally {
    saving.value = false
  }
}

const confirmDelete = (ind) => { deleteConfirm.value = ind }

const handleDelete = async () => {
  try {
    deleting.value = true
    await deleteIndicacion(deleteConfirm.value.id)
    await loadIndicaciones()
    deleteConfirm.value = null
  } catch (error) {
    logger.error('Error eliminando indicación:', error)
    toast.error('Error al desactivar la indicación')
  } finally {
    deleting.value = false
  }
}

onMounted(loadIndicaciones)
</script>

<style scoped>
/* Wrapper */
.im__wrap { display: flex; flex-direction: column; gap: 1rem; }
.im__header { display: flex; align-items: center; justify-content: space-between; }
.im__title { font-size: .9375rem; font-weight: 700; color: #0f172a; margin: 0; }

/* Empty / Loading */
.im__loading { display: flex; justify-content: center; padding: 2rem 0; }
.im__empty { display: flex; flex-direction: column; align-items: center; gap: .5rem; padding: 2.5rem 0; color: #94a3b8; }
.im__empty-icon { font-size: 2rem; }
.im__empty p { margin: 0; font-size: .875rem; }

/* Cards */
.im__list { display: flex; flex-direction: column; gap: .75rem; }
.im__card {
  background: #fff; border-radius: 10px; padding: 1rem; border-left: 4px solid #e2e8f0;
  transition: box-shadow .15s;
}
.im__card:hover { box-shadow: 0 2px 10px rgba(0,0,0,.08); }
.im__card--activa  { border-left-color: #22c55e; }
.im__card--warning { border-left-color: #f59e0b; }
.im__card--vencida { border-left-color: #ef4444; }
.im__card-top { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: .6rem; }
.im__card-patologia { font-size: .875rem; font-weight: 700; color: #0f172a; margin: 0 0 .2rem; }
.im__card-medico { font-size: .75rem; color: #64748b; margin: 0; }
.im__badge { font-size: .68rem; font-weight: 700; padding: .25rem .6rem; border-radius: 99px; white-space: nowrap; }
.im__badge--success { background: #dcfce7; color: #166534; }
.im__badge--warning { background: #fef9c3; color: #854d0e; }
.im__badge--danger  { background: #fee2e2; color: #991b1b; }
.im__badge--neutral { background: #f1f5f9; color: #64748b; }
.im__card-meta { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: .4rem .75rem; margin-bottom: .6rem; }
.im__meta-item { display: flex; flex-direction: column; gap: .1rem; }
.im__meta-label { font-size: .68rem; font-weight: 600; color: #94a3b8; text-transform: uppercase; letter-spacing: .04em; }
.im__meta-val { font-size: .8rem; color: #334155; }
.im__meta-val--muted { color: #94a3b8; font-style: italic; }
.im__meta-nota { color: #94a3b8; font-size: .72rem; }

/* Consumo dispensado */
.im__consumo {
  display: flex; align-items: center; gap: var(--sp-4, 16px);
  background: var(--c-leaf-50, #F4F8F5); border: 1px solid var(--c-leaf-100, #E8F0EB);
  border-radius: var(--r-lg, 8px); padding: var(--sp-3, 12px) var(--sp-4, 16px);
  margin-bottom: var(--sp-4, 16px);
}
.im__consumo-stat { display: flex; flex-direction: column; gap: .1rem; }
.im__consumo-val { font-size: var(--fs-16, 16px); font-weight: 700; color: var(--c-leaf-800, #1A3D2E); letter-spacing: -.02em; }
.im__consumo-lbl { font-size: var(--fs-12, 12px); color: var(--c-ink-500, #6B7280); }
.im__consumo-sep { width: 1px; height: 26px; background: var(--c-leaf-100, #E8F0EB); }
.im__sparkline { margin-left: auto; width: 120px; height: 32px; color: var(--c-leaf-500, #5A8A72); }
.im__sparkline svg { width: 100%; height: 100%; overflow: visible; }
@media (max-width: 640px) {
  .im__consumo { flex-wrap: wrap; gap: var(--sp-3, 12px); }
  .im__sparkline { margin-left: 0; width: 100%; }
}
.im__card-actions { display: flex; gap: .5rem; padding-top: .6rem; border-top: 1px solid #f1f5f9; }
.im__action-btn {
  font-size: .75rem; font-weight: 600; padding: .3rem .7rem; border-radius: 6px;
  border: 1.5px solid #e2e8f0; background: none; color: #475569; cursor: pointer; transition: all .12s;
}
.im__action-btn:hover { border-color: #94a3b8; background: #f8fafc; }
.im__action-btn--danger { color: #dc2626; border-color: #fecaca; }
.im__action-btn--danger:hover { background: #fef2f2; border-color: #f87171; }

/* Botones principales */
.im__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #2D8A6B; color: #fff; border: none; padding: .55rem 1rem;
  border-radius: 9px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.im__btn-primary:hover:not(:disabled) { background: #236b53; }
.im__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
.im__btn-ghost {
  display: inline-flex; align-items: center; gap: .4rem;
  background: none; color: #475569; border: 1.5px solid #e2e8f0;
  padding: .55rem 1rem; border-radius: 9px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: all .15s;
}
.im__btn-ghost:hover:not(:disabled) { border-color: #94a3b8; }
.im__btn-ghost:disabled { opacity: .5; cursor: not-allowed; }
.im__btn-danger {
  display: inline-flex; align-items: center; gap: .4rem;
  background: #dc2626; color: #fff; border: none; padding: .55rem 1rem;
  border-radius: 9px; font-size: .8rem; font-weight: 600; cursor: pointer; transition: background .15s;
}
.im__btn-danger:hover:not(:disabled) { background: #b91c1c; }
.im__btn-danger:disabled { opacity: .5; cursor: not-allowed; }

/* Modal */
.im__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 1000;
  display: flex; align-items: center; justify-content: center; padding: 1rem;
}
.im__modal {
  background: #fff; border-radius: 16px; width: 100%; max-width: 600px;
  box-shadow: 0 24px 64px rgba(0,0,0,.22); display: flex; flex-direction: column; max-height: 90vh;
}
.im__modal-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 1.25rem 1.5rem; border-bottom: 1px solid #e2e8f0;
}
.im__modal-title { font-size: 1rem; font-weight: 700; color: #0f172a; margin: 0; }
.im__modal-close {
  background: none; border: none; color: #94a3b8; cursor: pointer;
  font-size: 1rem; padding: .3rem .4rem; border-radius: 6px; line-height: 1; transition: all .12s;
}
.im__modal-close:hover { background: #f1f5f9; color: #475569; }
.im__modal-body { padding: 1.5rem; overflow-y: auto; flex: 1; background: #f8fafc; }
.im__modal-footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem; border-top: 1px solid #e2e8f0; background: #fff;
  border-radius: 0 0 16px 16px;
}

/* Formulario */
.im__form-error {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  border-radius: 8px; padding: .75rem 1rem; font-size: .8rem; margin-bottom: 1rem;
}
.im__form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: .9rem; }
.im__form-field { display: flex; flex-direction: column; gap: .3rem; }
.im__form-field--full { grid-column: 1 / -1; }
.im__form-field label {
  font-size: .7rem; font-weight: 700; color: #475569;
  text-transform: uppercase; letter-spacing: .04em;
}
.im__req { color: #dc2626; }
.im__form-field input,
.im__form-field select,
.im__form-field textarea {
  padding: .55rem .8rem; background: #ffffff;
  border: 1.5px solid #cbd5e1; border-radius: 8px;
  font-size: .875rem; color: #0f172a; outline: none;
  transition: border-color .15s, box-shadow .15s;
  font-family: inherit; box-shadow: 0 1px 2px rgba(0,0,0,.04);
}
.im__form-field input::placeholder,
.im__form-field textarea::placeholder { color: #94a3b8; }
.im__form-field select { cursor: pointer; }
.im__form-field input:focus,
.im__form-field select:focus,
.im__form-field textarea:focus {
  border-color: #2D8A6B;
  box-shadow: 0 0 0 3px rgba(45,138,107,.12);
}
.im__form-field textarea { resize: vertical; min-height: 80px; line-height: 1.5; }
.im__hint { font-size: .7rem; color: #94a3b8; display: block; margin-top: .1rem; }
.im__check-label { display: flex; align-items: center; gap: .5rem; font-size: .8rem !important; font-weight: 500 !important; color: #475569 !important; text-transform: none !important; letter-spacing: 0 !important; cursor: pointer; }
.im__check { width: 15px; height: 15px; accent-color: #2D8A6B; }

/* Confirm modal */
.im__confirm-text { font-size: .9rem; color: #0f172a; margin: 0 0 .4rem; }
.im__confirm-hint { font-size: .8rem; color: #64748b; margin: 0; }
</style>
