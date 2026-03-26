<template>
  <div class="tareas-lote">
    <div class="d-flex align-items-center justify-content-between mb-3">
      <h6 class="fw-bold mb-0">
        <i class="bi bi-clipboard-check me-2 text-primary"></i>Tareas del lote
      </h6>
      <span v-if="horasPendientesTotal > 0" class="badge bg-warning text-dark">
        <i class="bi bi-clock-history me-1"></i>{{ horasPendientesTotal }}h sin aplicar
      </span>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-3">
      <div class="spinner-border spinner-border-sm text-primary"></div>
    </div>

    <!-- Sin tareas -->
    <div v-else-if="tareas.length === 0" class="text-muted text-center py-3 small">
      <i class="bi bi-clipboard me-1"></i>Sin tareas registradas para este lote
    </div>

    <template v-else>
      <!-- Alerta de horas pendientes de aplicar -->
      <div v-if="tareasConHorasPendientes.length > 0" class="alert alert-warning py-2 mb-3 small">
        <div class="d-flex align-items-start gap-2">
          <i class="bi bi-exclamation-triangle-fill mt-1 flex-shrink-0"></i>
          <div>
            <strong>{{ tareasConHorasPendientes.length }} tarea{{ tareasConHorasPendientes.length > 1 ? 's' : '' }} con horas disponibles</strong>
            <div class="mt-1">
              Total: <strong>{{ horasPendientesTotal }}h</strong> disponibles para agregar al costo de mano de obra.
            </div>
            <button
              class="btn btn-warning btn-sm mt-2"
              @click="mostrarModalAplicar = true"
              :disabled="aplicando"
            >
              <span v-if="aplicando" class="spinner-border spinner-border-sm me-1"></span>
              <i v-else class="bi bi-plus-circle me-1"></i>
              Aplicar horas al costo del lote
            </button>
          </div>
        </div>
      </div>

      <!-- Lista de tareas -->
      <div class="tareas-lote__lista">
        <div
          v-for="t in tareas"
          :key="t.id"
          class="tareas-lote__item"
          :class="{ 'pendiente-aplicar': t.tiene_horas_para_lote }"
        >
          <div class="d-flex align-items-center gap-2 flex-grow-1 min-w-0">
            <span class="estado-dot" :class="`estado-dot--${t.estado}`"></span>
            <div class="min-w-0">
              <div class="fw-semibold text-truncate small">{{ t.titulo }}</div>
              <div class="text-muted" style="font-size: 0.72rem;">
                {{ TIPO_LABELS[t.tipo] }}
                <span v-if="t.fecha_programada"> · {{ t.fecha_programada }}</span>
                <span v-if="t.asignada_a"> · {{ t.asignada_a.nombre }}</span>
              </div>
            </div>
          </div>
          <div class="d-flex align-items-center gap-2 flex-shrink-0">
            <span v-if="t.horas_reales" class="small fw-semibold" :class="t.horas_aplicadas_al_lote ? 'text-success' : 'text-warning'">
              {{ t.horas_reales }}h
              <i v-if="t.horas_aplicadas_al_lote" class="bi bi-check-circle-fill" title="Aplicado al costo"></i>
              <i v-else class="bi bi-clock-history" title="Pendiente de aplicar"></i>
            </span>
            <span class="badge small" :class="estadoBadge(t.estado)">{{ t.estado }}</span>
          </div>
        </div>
      </div>
    </template>

    <!-- Modal confirmar aplicar horas -->
    <div v-if="mostrarModalAplicar" class="modal-overlay" @click.self="mostrarModalAplicar = false">
      <div class="modal-box">
        <h6 class="fw-bold mb-3">
          <i class="bi bi-clock-history me-2 text-warning"></i>Aplicar horas al costo del lote
        </h6>
        <p class="small text-muted mb-3">
          Se sumarán <strong>{{ horasPendientesTotal }} horas</strong> al costo de mano de obra del lote
          <strong>{{ lote.codigo }}</strong>.
        </p>

        <div class="alert alert-light border small py-2 mb-3">
          <div class="fw-semibold mb-2">Tareas a aplicar:</div>
          <div v-for="t in tareasConHorasPendientes" :key="t.id" class="d-flex justify-content-between py-1 border-bottom">
            <span class="text-truncate me-2">{{ t.titulo }}</span>
            <span class="fw-semibold text-nowrap">{{ t.horas_reales }}h</span>
          </div>
          <div class="d-flex justify-content-between pt-2 fw-bold">
            <span>Total</span>
            <span>{{ horasPendientesTotal }}h · ${{ costoEstimado.toLocaleString('es-AR') }}</span>
          </div>
          <div class="form-text mt-1">
            <i class="bi bi-info-circle me-1"></i>Tarifa: ${{ TARIFA_HORA.toLocaleString('es-AR') }}/h
          </div>
        </div>

        <div class="mb-3">
          <label class="form-label small fw-semibold">Tarifa por hora (ARS)</label>
          <input v-model.number="tarifaHora" type="number" class="form-control form-control-sm" min="0" step="100">
        </div>

        <div v-if="errorAplicar" class="alert alert-danger py-2 small">{{ errorAplicar }}</div>

        <div class="d-flex gap-2 justify-content-end">
          <button class="btn btn-outline-secondary btn-sm" @click="mostrarModalAplicar = false">Cancelar</button>
          <button class="btn btn-warning btn-sm" @click="aplicarHoras" :disabled="aplicando">
            <span v-if="aplicando" class="spinner-border spinner-border-sm me-1"></span>
            Confirmar y aplicar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { listTareas, updateTarea } from '../lib/api.js'

const props = defineProps({
  lote: { type: Object, required: true }
})

const emit = defineEmits(['horas-aplicadas'])

const tareas           = ref([])
const loading          = ref(false)
const aplicando        = ref(false)
const mostrarModalAplicar = ref(false)
const errorAplicar     = ref('')
const TARIFA_HORA      = 1500
const tarifaHora       = ref(TARIFA_HORA)

const TIPO_LABELS = {
  riego: '💧 Riego', poda: '✂️ Poda', medicion: '📏 Medición',
  limpieza: '🧹 Limpieza', cosecha: '🌿 Cosecha', transplante: '🪴 Transplante',
  inspeccion: '🔍 Inspección', otro: '📋 Otro'
}

const tareasConHorasPendientes = computed(() =>
  tareas.value.filter(t => t.tiene_horas_para_lote)
)

const horasPendientesTotal = computed(() =>
  tareasConHorasPendientes.value.reduce((acc, t) => acc + (parseFloat(t.horas_reales) || 0), 0)
)

const costoEstimado = computed(() =>
  Math.round(horasPendientesTotal.value * tarifaHora.value)
)

onMounted(() => cargarTareas())

async function cargarTareas() {
  loading.value = true
  try {
    const res  = await listTareas({ lote_id: props.lote.id })
    tareas.value = res.data
  } catch (e) {
    console.error('Error cargando tareas del lote:', e)
  } finally {
    loading.value = false
  }
}

async function aplicarHoras() {
  if (tareasConHorasPendientes.value.length === 0) return
  errorAplicar.value = ''
  aplicando.value    = true

  try {
    // Marcar cada tarea como aplicada via API
    // El endpoint PATCH /tareas/:id acepta horas_aplicadas_al_lote
    await Promise.all(
      tareasConHorasPendientes.value.map(t =>
        updateTarea(t.id, { horas_aplicadas_al_lote: true })
      )
    )

    // Emitir al padre para que actualice CostoLote
    emit('horas-aplicadas', {
      horas_total:    horasPendientesTotal.value,
      costo_estimado: costoEstimado.value,
      tarifa_hora:    tarifaHora.value,
      tareas:         tareasConHorasPendientes.value
    })

    mostrarModalAplicar.value = false
    // Refrescar lista
    await cargarTareas()
  } catch (e) {
    errorAplicar.value = e.response?.data?.error || 'Error al aplicar horas'
  } finally {
    aplicando.value = false
  }
}

function estadoBadge(estado) {
  return {
    pendiente:   'bg-secondary text-white',
    en_progreso: 'bg-warning text-dark',
    completada:  'bg-success text-white',
    cancelada:   'bg-danger text-white'
  }[estado] || 'bg-secondary'
}
</script>

<style scoped>
.tareas-lote__lista {
  border: 1px solid var(--bs-border-color);
  border-radius: 8px;
  overflow: hidden;
}

.tareas-lote__item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  border-bottom: 1px solid var(--bs-border-color);
  gap: 12px;
}
.tareas-lote__item:last-child { border-bottom: none; }
.tareas-lote__item.pendiente-aplicar { background: rgba(255,193,7,0.06); }

.estado-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.estado-dot--pendiente   { background: #6c757d; }
.estado-dot--en_progreso { background: #fd7e14; }
.estado-dot--completada  { background: #198754; }
.estado-dot--cancelada   { background: #dc3545; }

/* Modal inline */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.4);
  z-index: 1050;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
}
.modal-box {
  background: var(--bs-body-bg);
  border-radius: 12px;
  padding: 24px;
  width: min(480px, 100%);
  box-shadow: 0 8px 32px rgba(0,0,0,0.2);
}
</style>
