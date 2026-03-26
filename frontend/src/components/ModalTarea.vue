<template>
  <div v-if="show" class="modal fade show d-block" tabindex="-1" aria-modal="true">
    <div class="modal-dialog modal-lg modal-dialog-centered">
      <div class="modal-content">
        <div class="modal-header border-0 pb-0">
          <h5 class="modal-title fw-bold">
            <i class="bi bi-clipboard-check me-2 text-primary"></i>
            {{ editando ? 'Editar tarea' : 'Nueva tarea' }}
          </h5>
          <button type="button" class="btn-close" @click="$emit('cerrar')"></button>
        </div>
        <div class="modal-body pt-3">
          <div class="mb-3">
            <label class="form-label fw-semibold">Título <span class="text-danger">*</span></label>
            <input v-model="form.titulo" type="text" class="form-control" :class="{ 'is-invalid': errores.titulo }" placeholder="Ej: Riego completo sala norte" maxlength="200">
            <div v-if="errores.titulo" class="invalid-feedback">{{ errores.titulo }}</div>
          </div>
          <div class="row g-3 mb-3">
            <div class="col-md-6">
              <label class="form-label fw-semibold">Tipo</label>
              <select v-model="form.tipo" class="form-select">
                <option value="riego">💧 Riego</option>
                <option value="poda">✂️ Poda</option>
                <option value="medicion">📏 Medición</option>
                <option value="limpieza">🧹 Limpieza</option>
                <option value="cosecha">🌿 Cosecha</option>
                <option value="transplante">🪴 Transplante</option>
                <option value="inspeccion">🔍 Inspección</option>
                <option value="otro">📋 Otro</option>
              </select>
            </div>
            <div class="col-md-6">
              <label class="form-label fw-semibold">Prioridad</label>
              <select v-model="form.prioridad" class="form-select">
                <option value="baja">🟢 Baja</option>
                <option value="normal">🔵 Normal</option>
                <option value="alta">🟠 Alta</option>
                <option value="urgente">🔴 Urgente</option>
              </select>
            </div>
          </div>
          <div v-if="puedeAsignar" class="mb-3">
            <label class="form-label fw-semibold">Asignar a</label>
            <select v-model="form.asignada_a_id" class="form-select">
              <option value="">Sin asignar</option>
              <option v-for="u in usuarios" :key="u.id" :value="u.id">
                {{ `${u.first_name} ${u.last_name}`.trim() }} — {{ u.role }}
              </option>
            </select>
          </div>
          <div class="row g-3 mb-3">
            <div class="col-md-6">
              <label class="form-label fw-semibold">Fecha programada</label>
              <input v-model="form.fecha_programada" type="date" class="form-control">
            </div>
            <div class="col-md-6">
              <label class="form-label fw-semibold">Horas estimadas</label>
              <input v-model.number="form.horas_estimadas" type="number" class="form-control" min="0.25" max="24" step="0.25" placeholder="0.0">
            </div>
          </div>
          <div class="row g-3 mb-3">
            <div class="col-md-6">
              <label class="form-label fw-semibold">Sala (opcional)</label>
              <select v-model="form.sala_id" class="form-select" @change="form.lote_id = ''">
                <option value="">Sin sala</option>
                <option v-for="s in salas" :key="s.id" :value="s.id">{{ s.nombre }}</option>
              </select>
            </div>
            <div class="col-md-6">
              <label class="form-label fw-semibold">Lote (opcional)</label>
              <select v-model="form.lote_id" class="form-select">
                <option value="">Sin lote</option>
                <option v-for="l in lotesFiltrados" :key="l.id" :value="l.id">{{ l.codigo }}</option>
              </select>
              <div class="form-text"><i class="bi bi-info-circle me-1"></i>Las horas completadas se pueden aplicar al costo del lote</div>
            </div>
          </div>
          <div class="mb-3">
            <label class="form-label fw-semibold">Descripción</label>
            <textarea v-model="form.descripcion" class="form-control" rows="3" placeholder="Instrucciones o notas adicionales..."></textarea>
          </div>
          <div v-if="errorGlobal" class="alert alert-danger py-2 small">
            <i class="bi bi-exclamation-triangle me-2"></i>{{ errorGlobal }}
          </div>
        </div>
        <div class="modal-footer border-0 pt-0">
          <button type="button" class="btn btn-outline-secondary" @click="$emit('cerrar')">Cancelar</button>
          <button type="button" class="btn btn-primary" @click="guardar" :disabled="guardando || !form.titulo">
            <span v-if="guardando" class="spinner-border spinner-border-sm me-2"></span>
            {{ editando ? 'Guardar cambios' : 'Crear tarea' }}
          </button>
        </div>
      </div>
    </div>
  </div>
  <div v-if="show" class="modal-backdrop fade show" @click="$emit('cerrar')"></div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useTareasStore } from '../stores/tareas'

const props = defineProps({
  show:         { type: Boolean, default: false },
  tareaInicial: { type: Object,  default: null },
  salas:        { type: Array,   default: () => [] },
  lotes:        { type: Array,   default: () => [] },
  usuarios:     { type: Array,   default: () => [] }
})
const emit = defineEmits(['guardada', 'cerrar'])

const authStore   = useAuthStore()
const tareasStore = useTareasStore()
const guardando   = ref(false)
const errorGlobal = ref('')
const errores     = ref({})

const editando     = computed(() => !!props.tareaInicial?.id)
const puedeAsignar = computed(() => ['admin', 'agricultor'].includes(authStore.user?.role))
const lotesFiltrados = computed(() => {
  if (!form.value.sala_id) return props.lotes
  return props.lotes.filter(l => String(l.sala_id) === String(form.value.sala_id))
})

function formVacio() {
  return { titulo: '', descripcion: '', tipo: 'otro', prioridad: 'normal', asignada_a_id: '', sala_id: '', lote_id: '', fecha_programada: new Date().toISOString().split('T')[0], horas_estimadas: null }
}
const form = ref(formVacio())

watch(() => props.show, (val) => {
  if (!val) return
  errorGlobal.value = ''
  errores.value = {}
  form.value = props.tareaInicial ? {
    titulo: props.tareaInicial.titulo || '',
    descripcion: props.tareaInicial.descripcion || '',
    tipo: props.tareaInicial.tipo || 'otro',
    prioridad: props.tareaInicial.prioridad || 'normal',
    asignada_a_id: props.tareaInicial.asignada_a?.id || '',
    sala_id: props.tareaInicial.sala?.id || '',
    lote_id: props.tareaInicial.lote?.id || '',
    fecha_programada: props.tareaInicial.fecha_programada || new Date().toISOString().split('T')[0],
    horas_estimadas: props.tareaInicial.horas_estimadas || null
  } : formVacio()
})

async function guardar() {
  errores.value = {}
  errorGlobal.value = ''
  if (!form.value.titulo?.trim()) { errores.value.titulo = 'El título es requerido'; return }
  guardando.value = true
  try {
    const payload = { ...form.value, asignada_a_id: form.value.asignada_a_id || null, sala_id: form.value.sala_id || null, lote_id: form.value.lote_id || null, horas_estimadas: form.value.horas_estimadas || null }
    const resultado = editando.value ? await tareasStore.update(props.tareaInicial.id, payload) : await tareasStore.create(payload)
    emit('guardada', resultado)
  } catch (e) {
    const msgs = e.response?.data?.errors
    errorGlobal.value = msgs ? msgs.join(', ') : (e.response?.data?.error || 'Error al guardar')
  } finally {
    guardando.value = false
  }
}
</script>
