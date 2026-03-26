<template>
  <div class="modal fade" id="modalCompletarTarea" tabindex="-1" ref="modalEl">
    <div class="modal-dialog modal-md">
      <div class="modal-content">
        <div class="modal-header border-0 pb-0">
          <h5 class="modal-title fw-bold">
            <i class="bi bi-check-circle-fill text-success me-2"></i>
            Completar tarea
          </h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
        </div>

        <div class="modal-body" v-if="tarea">
          <!-- Nombre de la tarea -->
          <div class="alert alert-light border py-2 mb-4">
            <strong>{{ tarea.titulo }}</strong>
            <div v-if="tarea.lote" class="small text-muted mt-1">
              <i class="bi bi-box me-1"></i>Lote: {{ tarea.lote.codigo }}
            </div>
          </div>

          <!-- Horas reales -->
          <div class="mb-4">
            <label class="form-label fw-semibold">
              Horas trabajadas <span class="text-muted fw-normal">(opcional pero recomendado)</span>
            </label>
            <div class="input-group">
              <input
                v-model.number="horas"
                type="number"
                class="form-control form-control-lg"
                min="0.25"
                max="24"
                step="0.25"
                placeholder="0.0"
              >
              <span class="input-group-text">hs</span>
            </div>
            <div v-if="tarea.horas_estimadas" class="form-text">
              <i class="bi bi-clock me-1"></i>Estimado: {{ tarea.horas_estimadas }} hs
            </div>
          </div>

          <!-- Aviso de lote (solo informativo) -->
          <div v-if="tarea.lote && horas > 0" class="alert alert-info py-2 small">
            <i class="bi bi-info-circle-fill me-2"></i>
            Se registrarán <strong>{{ horas }}h</strong> para el lote <strong>{{ tarea.lote.codigo }}</strong>.
            Podés aplicarlas al costo del lote desde la vista del lote.
          </div>

          <!-- Notas de completado -->
          <div class="mb-3">
            <label class="form-label fw-semibold">Notas de completado</label>
            <textarea
              v-model="notas"
              class="form-control"
              rows="3"
              placeholder="¿Cómo salió? ¿Algo a destacar?"
            ></textarea>
          </div>

          <!-- Error -->
          <div v-if="error" class="alert alert-danger py-2 small">
            <i class="bi bi-exclamation-triangle me-2"></i>{{ error }}
          </div>
        </div>

        <div class="modal-footer border-0 pt-0">
          <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">
            Cancelar
          </button>
          <button
            type="button"
            class="btn btn-success"
            @click="confirmar"
            :disabled="guardando"
          >
            <span v-if="guardando" class="spinner-border spinner-border-sm me-2"></span>
            <i v-else class="bi bi-check-lg me-2"></i>
            Marcar como completada
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useTareasStore } from '../stores/tareas.js'

const props = defineProps({
  tarea: { type: Object, default: null }
})

const emit = defineEmits(['completada', 'cerrar'])

const tareasStore = useTareasStore()

const horas    = ref(null)
const notas    = ref('')
const error    = ref('')
const guardando = ref(false)

// Reset al abrir con nueva tarea
watch(() => props.tarea, (val) => {
  if (val) {
    horas.value  = val.horas_estimadas || null
    notas.value  = ''
    error.value  = ''
  }
})

async function confirmar() {
  error.value   = ''
  guardando.value = true

  try {
    const resultado = await tareasStore.completar(
      props.tarea.id,
      horas.value || null,
      notas.value || null
    )
    emit('completada', resultado)
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al completar la tarea'
  } finally {
    guardando.value = false
  }
}
</script>
