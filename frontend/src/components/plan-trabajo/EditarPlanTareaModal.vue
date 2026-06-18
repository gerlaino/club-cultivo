<template>
  <Teleport to="body">
    <div class="ept__overlay">
      <div class="ept__panel">
        <div class="ept__header">
          <div class="ept__header-ico"><i class="bi bi-pencil-square"></i></div>
          <div>
            <h2 class="ept__title">{{ planTarea?.titulo_display || 'Tarea del plan' }}</h2>
            <p class="ept__sub">{{ planTarea?.es_recurrente ? 'Tarea recurrente' : 'Tarea única' }}</p>
          </div>
          <button class="ept__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <div class="ept__body">
          <div v-if="error" class="ept__alert">{{ error }}</div>

          <!-- Scope (solo para recurrentes y plan publicado) -->
          <div v-if="planTarea?.es_recurrente && planPublicado" class="ept__field">
            <label class="ept__label">¿Qué modificar?</label>
            <div class="ept__scope-btns">
              <button v-for="s in SCOPES" :key="s.value" class="ept__scope-btn" :class="{ 'ept__scope-btn--active': scope === s.value }" @click="scope = s.value">{{ s.label }}</button>
            </div>
          </div>

          <!-- Responsable -->
          <div class="ept__field">
            <label class="ept__label">Responsable</label>
            <select class="ept__input" v-model="form.responsable_id">
              <option :value="null">Sin asignar</option>
              <option v-for="u in usuarios" :key="u.id" :value="u.id">{{ u.nombre_completo || u.nombre }}</option>
            </select>
          </div>

          <!-- Tipo -->
          <div class="ept__field">
            <label class="ept__label">Tipo</label>
            <select class="ept__input" v-model="form.tipo">
              <option v-for="t in TIPOS" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
          </div>

          <!-- Título -->
          <div class="ept__field">
            <label class="ept__label">Título <span class="ept__hint">(opcional)</span></label>
            <input class="ept__input" v-model="form.titulo" placeholder="Deja vacío para usar el tipo" />
          </div>

          <!-- Prioridad -->
          <div class="ept__field">
            <label class="ept__label">Prioridad</label>
            <div class="ept__prio-btns">
              <button v-for="p in PRIORIDADES" :key="p.value" class="ept__prio-btn" :class="[`ept__prio-btn--${p.value}`, { 'ept__prio-btn--active': form.prioridad === p.value }]" @click="form.prioridad = p.value">{{ p.label }}</button>
            </div>
          </div>

          <!-- Recurrencia / días -->
          <div class="ept__field">
            <label class="ept__label">¿Se repite?</label>
            <div class="ept__toggle-row">
              <button class="ept__toggle" :class="{ 'ept__toggle--on': !form.es_recurrente }" @click="form.es_recurrente = false">Única</button>
              <button class="ept__toggle" :class="{ 'ept__toggle--on': form.es_recurrente }"  @click="form.es_recurrente = true">Recurrente</button>
            </div>
          </div>

          <div v-if="form.es_recurrente" class="ept__field">
            <label class="ept__label">Días de semana</label>
            <div class="ept__dias">
              <button v-for="d in DIAS" :key="d.value" class="ept__dia" :class="{ 'ept__dia--on': diasSeleccionados.includes(d.value) }" @click="toggleDia(d.value)">{{ d.label }}</button>
            </div>
          </div>

          <div v-else class="ept__field">
            <label class="ept__label">Fecha</label>
            <AppDatePicker v-model="form.fecha_especifica" />
          </div>

          <!-- Hora -->
          <div class="ept__field">
            <label class="ept__label">Hora <span class="ept__hint">(opcional)</span></label>
            <input class="ept__input ept__input--sm" type="time" v-model="form.hora" />
          </div>

          <!-- Sala -->
          <div class="ept__field">
            <label class="ept__label">Sala <span class="ept__hint">(opcional)</span></label>
            <select class="ept__input" v-model="form.sala_id">
              <option :value="null">Sin sala</option>
              <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
            </select>
          </div>

          <!-- Descripción -->
          <div class="ept__field">
            <label class="ept__label">Notas <span class="ept__hint">(opcional)</span></label>
            <textarea class="ept__input ept__textarea" v-model="form.descripcion" rows="2" placeholder="Instrucciones adicionales…"></textarea>
          </div>
        </div>

        <div class="ept__footer">
          <button class="ept__btn-danger" :disabled="saving" @click="eliminar">
            <i class="bi bi-trash3"></i>
          </button>
          <div class="ept__footer-right">
            <button class="ept__btn-ghost" @click="$emit('close')">Cancelar</button>
            <button class="ept__btn-primary" :disabled="saving" @click="guardar">
              <DsSpinner v-if="saving" :size="14" />
              {{ saving ? 'Guardando…' : 'Guardar' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, watch, computed } from 'vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { updatePlanTarea, deletePlanTarea } from '../../lib/api.js'
import DsSpinner from '../../design-system/components/Spinner.vue'

const props = defineProps({
  planTarea:    { type: Object, default: null },
  planId:       { type: Number, required: true },
  planPublicado:{ type: Boolean, default: false },
  usuarios:     { type: Array, default: () => [] },
  salas:        { type: Array, default: () => [] },
})
const emit = defineEmits(['close', 'updated', 'deleted'])

const saving = ref(false)
const error  = ref(null)
const scope  = ref('esta')

const SCOPES = [
  { value: 'esta',       label: 'Solo esta vez' },
  { value: 'siguientes', label: 'Esta y las siguientes' },
  { value: 'todas',      label: 'Todas las instancias' },
]
const TIPOS = [
  { value: 'riego', label: '💧 Riego' }, { value: 'poda', label: '✂️ Poda' },
  { value: 'medicion', label: '📏 Medición' }, { value: 'limpieza', label: '🧹 Limpieza' },
  { value: 'cosecha', label: '🌿 Cosecha' }, { value: 'transplante', label: '🪴 Trasplante' },
  { value: 'inspeccion', label: '🔍 Inspección' }, { value: 'otro', label: '📋 Otro' },
]
const PRIORIDADES = [
  { value: 'baja', label: 'Baja' }, { value: 'normal', label: 'Normal' },
  { value: 'alta', label: 'Alta' }, { value: 'urgente', label: 'Urgente' },
]
const DIAS = [
  { value: 'lun', label: 'L' }, { value: 'mar', label: 'M' }, { value: 'mie', label: 'M' },
  { value: 'jue', label: 'J' }, { value: 'vie', label: 'V' }, { value: 'sab', label: 'S' }, { value: 'dom', label: 'D' },
]

const form = ref({})

watch(() => props.planTarea, (pt) => {
  if (!pt) return
  form.value = {
    titulo:          pt.titulo || '',
    tipo:            pt.tipo || 'otro',
    responsable_id:  pt.responsable?.id || null,
    prioridad:       pt.prioridad || 'normal',
    sala_id:         pt.sala?.id || null,
    descripcion:     pt.descripcion || '',
    dias_semana:     pt.dias_semana || '',
    hora:            pt.hora || '',
    es_recurrente:   pt.es_recurrente ?? false,
    fecha_especifica: pt.fecha_especifica || '',
  }
}, { immediate: true })

const diasSeleccionados = computed(() => form.value.dias_semana ? form.value.dias_semana.split(',').map(d => d.trim()) : [])

function toggleDia(d) {
  const arr = [...diasSeleccionados.value]
  const idx = arr.indexOf(d)
  if (idx >= 0) arr.splice(idx, 1); else arr.push(d)
  form.value.dias_semana = arr.join(',')
}

async function guardar() {
  saving.value = true; error.value = null
  try {
    const { data } = await updatePlanTarea(props.planId, props.planTarea.id, form.value, scope.value)
    emit('updated', data)
    emit('close')
  } catch (e) {
    error.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
  } finally { saving.value = false }
}

async function eliminar() {
  if (!confirm('¿Eliminar esta tarea del plan?')) return
  saving.value = true
  try {
    await deletePlanTarea(props.planId, props.planTarea.id)
    emit('deleted', props.planTarea.id)
    emit('close')
  } finally { saving.value = false }
}
</script>

<style scoped>
.ept__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1060; padding: 1rem; backdrop-filter: blur(3px); }
.ept__panel   { background: #fff; border-radius: 16px; width: 100%; max-width: 480px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); max-height: 90vh; overflow-y: auto; }
.ept__header  { display: flex; align-items: center; gap: .875rem; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9; position: sticky; top: 0; background: #fff; z-index: 1; }
.ept__header-ico { width: 38px; height: 38px; border-radius: 10px; background: rgba(27,94,32,.1); color: #1b5e20; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.ept__title { font-size: 1rem; font-weight: 800; color: #0f2611; margin: 0 0 .1rem; }
.ept__sub   { font-size: .75rem; color: #94a3b8; margin: 0; }
.ept__close { margin-left: auto; background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; }
.ept__close:hover { background: #e2e8f0; }
.ept__body  { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: .875rem; }
.ept__alert { background: #fef2f2; border: 1px solid #fecaca; color: #dc2626; padding: .65rem .875rem; border-radius: 8px; font-size: .82rem; }
.ept__field { display: flex; flex-direction: column; gap: .3rem; }
.ept__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ept__hint  { font-weight: 400; text-transform: none; color: #94a3b8; letter-spacing: 0; }
.ept__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; font-size: .875rem; color: #0f2611; width: 100%; box-sizing: border-box; }
.ept__input:focus { outline: none; border-color: #1b5e20; box-shadow: 0 0 0 3px rgba(27,94,32,.08); }
.ept__input--sm { max-width: 120px; }
.ept__textarea { resize: vertical; min-height: 60px; }
.ept__scope-btns { display: flex; gap: .4rem; flex-wrap: wrap; }
.ept__scope-btn  { padding: .35rem .8rem; border: 1.5px solid #e2e8f0; border-radius: 7px; background: #f8fafc; font-size: .78rem; font-weight: 600; color: #60725d; cursor: pointer; }
.ept__scope-btn--active { border-color: #1b5e20; background: rgba(27,94,32,.07); color: #1b5e20; }
.ept__prio-btns { display: flex; gap: .35rem; }
.ept__prio-btn  { flex: 1; padding: .35rem .5rem; border: 1.5px solid #e2e8f0; border-radius: 7px; background: #f8fafc; font-size: .75rem; font-weight: 600; color: #60725d; cursor: pointer; text-align: center; }
.ept__prio-btn--active.ept__prio-btn--baja    { border-color: #9ca3af; background: #f1f5f9; color: #374151; }
.ept__prio-btn--active.ept__prio-btn--normal  { border-color: #1b5e20; background: #f0fdf4; color: #15803d; }
.ept__prio-btn--active.ept__prio-btn--alta    { border-color: #f97316; background: #fff7ed; color: #c2410c; }
.ept__prio-btn--active.ept__prio-btn--urgente { border-color: #dc2626; background: #fef2f2; color: #dc2626; }
.ept__toggle-row { display: flex; background: #f1f5f9; border-radius: 8px; padding: 3px; width: fit-content; }
.ept__toggle     { padding: .35rem .875rem; border-radius: 6px; border: none; background: none; font-size: .8rem; font-weight: 600; color: #64748b; cursor: pointer; }
.ept__toggle--on { background: #fff; color: #1b5e20; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
.ept__dias { display: flex; gap: .3rem; }
.ept__dia  { width: 36px; height: 36px; border-radius: 50%; border: 1.5px solid #e2e8f0; background: #f8fafc; font-size: .8rem; font-weight: 700; color: #60725d; cursor: pointer; display: flex; align-items: center; justify-content: center; }
.ept__dia--on { border-color: #1b5e20; background: #1b5e20; color: #fff; }
.ept__footer { display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; position: sticky; bottom: 0; background: #fff; }
.ept__footer-right { display: flex; gap: .75rem; }
.ept__btn-danger  { background: #fff; border: 1.5px solid #fecaca; color: #dc2626; width: 36px; height: 36px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
.ept__btn-danger:hover { background: #fef2f2; }
.ept__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #1b5e20; color: #fff; border: none; padding: .6rem 1.1rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.ept__btn-primary:hover:not(:disabled) { background: #144a18; }
.ept__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
.ept__btn-ghost  { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
</style>
