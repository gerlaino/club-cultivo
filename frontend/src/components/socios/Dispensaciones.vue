<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useAuthStore } from '../../stores/auth'
import {
  listDispensaciones, createDispensacion, updateDispensacion, deleteDispensacion,
  listIndicaciones, listLotes,
} from '../../lib/api.js'

const props = defineProps({
  socioId: { type: Number, required: true }
})

const auth            = useAuthStore()
const dispensaciones  = ref([])
const indicaciones    = ref([])
const lotes           = ref([])
const loading         = ref(true)
const showModal       = ref(false)
const editingId       = ref(null)
const saving          = ref(false)
const deleting        = ref(false)
const showDelete      = ref(false)
const deleteTarget    = ref(null)
const formError       = ref(null)

const cupoMensual         = ref(40)
const totalDispensadoMes  = ref(0)
const cupoDisponible      = ref(40)

const canCreate = computed(() => ['admin', 'medico', 'agricultor'].includes(auth.user?.role))
const canEdit   = computed(() => ['admin', 'medico', 'agricultor'].includes(auth.user?.role))

const porcentajeCupo = computed(() =>
  cupoMensual.value ? Math.min(100, (totalDispensadoMes.value / cupoMensual.value) * 100) : 0
)

const today = new Date().toISOString().split('T')[0]

// Lote seleccionado con su costo/gramo
const loteSeleccionado = computed(() =>
  lotes.value.find(l => l.id === form.value.lote_id) || null
)
const costoPorGramo = computed(() =>
  loteSeleccionado.value?.costo_por_gramo || null
)
const costoCalculado = computed(() => {
  if (!costoPorGramo.value || !form.value.cantidad_gramos) return null
  return (costoPorGramo.value * form.value.cantidad_gramos).toFixed(2)
})

function fmt(n) {
  if (!n) return '—'
  return new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS',
    minimumFractionDigits: 0 }).format(n)
}

function emptyForm() {
  return {
    cantidad_gramos:      null,
    tipo_producto:        'flores',
    fecha_dispensacion:   today,
    lote_id:              null,
    sede_id:              null,
    indicacion_medica_id: null,
    aporte_socio_ars:     null,
    observaciones:        '',
  }
}
const form = ref(emptyForm())

// Auto-sugerir aporte = costo calculado
watch(costoCalculado, (val) => {
  if (val && !editingId.value && !form.value.aporte_socio_ars) {
    form.value.aporte_socio_ars = parseFloat(val)
  }
})

function formatDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function openCreate() {
  editingId.value = null
  form.value      = emptyForm()
  formError.value = null
  showModal.value = true
}

function openEdit(disp) {
  editingId.value = disp.id
  form.value = {
    cantidad_gramos:      disp.cantidad_gramos,
    tipo_producto:        disp.tipo_producto,
    fecha_dispensacion:   disp.fecha_dispensacion,
    lote_id:              disp.lote?.id              || null,
    sede_id:              disp.sede?.id              || null,
    indicacion_medica_id: disp.indicacion_medica?.id || null,
    aporte_socio_ars:     disp.aporte_socio_ars      || null,
    observaciones:        disp.observaciones         || '',
  }
  formError.value = null
  showModal.value = true
}

async function loadDispensaciones() {
  loading.value = true
  try {
    const { data } = await listDispensaciones(props.socioId)
    dispensaciones.value     = data.dispensaciones        || []
    cupoMensual.value        = data.cupo_mensual          || 40
    totalDispensadoMes.value = data.total_dispensado_mes  || 0
    cupoDisponible.value     = data.cupo_disponible       || 40
  } catch (e) {
    console.error('Error cargando dispensaciones:', e)
  } finally {
    loading.value = false
  }
}

async function handleSubmit() {
  if (!form.value.cantidad_gramos || form.value.cantidad_gramos <= 0) {
    formError.value = 'La cantidad debe ser mayor a 0'
    return
  }
  saving.value    = true
  formError.value = null
  try {
    const payload = { ...form.value }
    Object.keys(payload).forEach(k => {
      if (payload[k] === '' || payload[k] === null || payload[k] === undefined) delete payload[k]
    })
    if (editingId.value) {
      await updateDispensacion(editingId.value, payload)
    } else {
      await createDispensacion(props.socioId, payload)
    }
    await loadDispensaciones()
    showModal.value = false
  } catch (e) {
    formError.value = e.response?.data?.errors?.[0] || 'Error al guardar'
  } finally {
    saving.value = false
  }
}

async function handleDelete() {
  deleting.value = true
  try {
    await deleteDispensacion(deleteTarget.value.id)
    await loadDispensaciones()
    showDelete.value = false
  } catch (e) {
    console.error('Error eliminando:', e)
  } finally {
    deleting.value = false
  }
}

onMounted(async () => {
  const [, indRes, lotesRes] = await Promise.allSettled([
    loadDispensaciones(),
    listIndicaciones(props.socioId),
    listLotes(),
  ])
  if (indRes.status   === 'fulfilled') indicaciones.value = (indRes.value.data || []).filter(i => i.activa)
  if (lotesRes.status === 'fulfilled') lotes.value        = lotesRes.value.data || []
})
</script>

<template>
  <div>
    <div class="d-flex justify-content-between align-items-center mb-3">
      <div>
        <strong>💊 Dispensaciones</strong>
        <p class="text-muted small mb-0">Registro de entregas al paciente (máx. {{ cupoMensual }}g/mes)</p>
      </div>
      <button
        v-if="canCreate"
        class="btn btn-sm btn-success"
        :disabled="cupoDisponible <= 0"
        @click="openCreate"
      >
        <i class="bi bi-plus-circle me-1"></i> Nueva dispensación
      </button>
    </div>

    <!-- Cupo mensual -->
    <div class="card border-0 mb-3"
         :class="`border-${porcentajeCupo >= 90 ? 'danger' : porcentajeCupo >= 70 ? 'warning' : 'success'}`"
         style="border-left-width:4px !important; border-left-style:solid !important">
      <div class="card-body py-2 px-3 small">
        <div class="d-flex justify-content-between align-items-center mb-1">
          <span class="text-muted">Cupo mensual utilizado</span>
          <span class="fw-bold">{{ totalDispensadoMes }}g / {{ cupoMensual }}g</span>
        </div>
        <div class="progress" style="height:6px">
          <div
            class="progress-bar"
            :class="`bg-${porcentajeCupo >= 90 ? 'danger' : porcentajeCupo >= 70 ? 'warning' : 'success'}`"
            :style="{ width: porcentajeCupo + '%' }"
          ></div>
        </div>
        <div class="text-muted mt-1">Disponible este mes: <strong>{{ cupoDisponible }}g</strong></div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-3">
      <div class="spinner-border spinner-border-sm text-success"></div>
    </div>

    <!-- Empty -->
    <div v-else-if="!dispensaciones.length" class="text-center py-4 text-muted">
      <div class="fs-2 mb-2">💊</div>
      <div class="small">Sin dispensaciones registradas</div>
    </div>

    <!-- Tabla -->
    <div v-else class="table-responsive">
      <table class="table table-sm table-hover align-middle mb-0">
        <thead class="table-light">
        <tr>
          <th>Fecha</th>
          <th>Tipo</th>
          <th>Cantidad</th>
          <th>Costo calc.</th>
          <th>Aporte socio</th>
          <th>Lote</th>
          <th>Por</th>
          <th v-if="canEdit" class="text-end">Acciones</th>
        </tr>
        </thead>
        <tbody>
        <tr v-for="d in dispensaciones" :key="d.id">
          <td class="small">{{ formatDate(d.fecha_dispensacion) }}</td>
          <td>
            <span class="badge text-bg-secondary text-capitalize">{{ d.tipo_producto }}</span>
          </td>
          <td class="fw-bold small">{{ d.cantidad_gramos }}g</td>
          <td class="small text-muted">
            <span v-if="d.costo_total_calculado">{{ fmt(d.costo_total_calculado) }}</span>
            <span v-else>—</span>
          </td>
          <td class="small">
              <span v-if="d.aporte_socio_ars" class="text-success fw-semibold">
                {{ fmt(d.aporte_socio_ars) }}
              </span>
            <span v-else class="text-muted">—</span>
          </td>
          <td class="small font-monospace">{{ d.lote?.codigo || '—' }}</td>
          <td class="small text-muted">{{ d.usuario?.nombre || '—' }}</td>
          <td v-if="canEdit" class="text-end">
            <button class="btn btn-sm btn-outline-primary me-1" @click="openEdit(d)">
              <i class="bi bi-pencil"></i>
            </button>
            <button class="btn btn-sm btn-outline-danger" @click="deleteTarget=d; showDelete=true">
              <i class="bi bi-trash"></i>
            </button>
          </td>
        </tr>
        </tbody>
      </table>
    </div>

    <!-- ===== MODAL CREAR / EDITAR ===== -->
    <div v-if="showModal" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ editingId ? 'Editar dispensación' : 'Nueva dispensación' }}</h5>
            <button class="btn-close" @click="showModal=false"></button>
          </div>
          <div class="modal-body">
            <div v-if="formError" class="alert alert-danger alert-dismissible d-flex align-items-center gap-2 mb-3">
              <i class="bi bi-exclamation-triangle-fill"></i>
              <span>{{ formError }}</span>
              <button class="btn-close" @click="formError=null"></button>
            </div>

            <div class="row g-3">

              <!-- Cantidad -->
              <div class="col-md-4">
                <label class="form-label small fw-semibold">Cantidad (gramos) <span class="text-danger">*</span></label>
                <input v-model.number="form.cantidad_gramos" type="number" step="0.01" min="0.01"
                       :max="cupoDisponible" class="form-control" placeholder="Ej: 10" />
                <div class="form-text">Disponible: {{ cupoDisponible }}g</div>
              </div>

              <!-- Tipo producto -->
              <div class="col-md-4">
                <label class="form-label small fw-semibold">Tipo de producto <span class="text-danger">*</span></label>
                <select v-model="form.tipo_producto" class="form-select">
                  <option value="flores">Flores</option>
                  <option value="aceite">Aceite</option>
                  <option value="extracto">Extracto</option>
                  <option value="crema">Crema</option>
                </select>
              </div>

              <!-- Fecha -->
              <div class="col-md-4">
                <label class="form-label small fw-semibold">Fecha <span class="text-danger">*</span></label>
                <input v-model="form.fecha_dispensacion" type="date" class="form-control" :max="today" />
              </div>

              <!-- Lote -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Lote</label>
                <select v-model="form.lote_id" class="form-select">
                  <option :value="null">Sin lote asignado</option>
                  <option v-for="l in lotes" :key="l.id" :value="l.id">
                    {{ l.codigo }}
                    <template v-if="l.costo_por_gramo"> — ${{ l.costo_por_gramo }}/g</template>
                  </option>
                </select>
                <!-- Info de costo del lote seleccionado -->
                <div v-if="costoPorGramo" class="form-text text-info">
                  💰 Costo/gramo: {{ fmt(costoPorGramo) }} · Total estimado: {{ fmt(costoCalculado) }}
                </div>
                <div v-else-if="loteSeleccionado && !costoPorGramo" class="form-text text-warning">
                  ⚠️ Este lote no tiene costo calculado
                </div>
              </div>

              <!-- Indicación médica -->
              <div class="col-md-6">
                <label class="form-label small fw-semibold">Indicación médica</label>
                <select v-model="form.indicacion_medica_id" class="form-select">
                  <option :value="null">Sin indicación asociada</option>
                  <option v-for="i in indicaciones" :key="i.id" :value="i.id">{{ i.patologia }}</option>
                </select>
              </div>

              <!-- Bloque financiero -->
              <div class="col-12">
                <div class="card border-0 bg-body-secondary">
                  <div class="card-body py-2 px-3">
                    <div class="small fw-semibold mb-2 text-muted">💰 Datos financieros</div>
                    <div class="row g-2">
                      <div class="col-md-6">
                        <label class="form-label small">Aporte del socio (ARS)</label>
                        <div class="input-group input-group-sm">
                          <span class="input-group-text">$</span>
                          <input v-model.number="form.aporte_socio_ars" type="number"
                                 min="0" step="0.01" class="form-control"
                                 placeholder="0.00" />
                        </div>
                        <div v-if="costoCalculado" class="form-text">
                          Costo calculado: {{ fmt(costoCalculado) }}
                        </div>
                      </div>
                      <div class="col-md-6 d-flex align-items-end">
                        <div class="small text-muted">
                          <template v-if="costoCalculado && form.aporte_socio_ars">
                            <span v-if="form.aporte_socio_ars >= costoCalculado" class="text-success">
                              ✓ Aporte cubre el costo
                            </span>
                            <span v-else class="text-warning">
                              ⚠ Aporte por debajo del costo
                            </span>
                          </template>
                          <template v-else>
                            El aporte generará un movimiento contable de tipo "recupero de costo"
                          </template>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Observaciones -->
              <div class="col-12">
                <label class="form-label small fw-semibold">Observaciones</label>
                <textarea v-model.trim="form.observaciones" class="form-control" rows="2"
                          placeholder="Notas adicionales…"></textarea>
              </div>

            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-outline-secondary" :disabled="saving" @click="showModal=false">Cancelar</button>
            <button class="btn btn-success" :disabled="saving" @click="handleSubmit">
              <span v-if="saving" class="spinner-border spinner-border-sm me-2"></span>
              {{ editingId ? 'Guardar cambios' : 'Registrar dispensación' }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showModal" class="modal-backdrop fade show" @click="showModal=false"></div>

    <!-- ===== MODAL ELIMINAR ===== -->
    <div v-if="showDelete" class="modal fade show d-block" tabindex="-1" aria-modal="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header border-0">
            <h5 class="modal-title text-danger">⚠️ Eliminar dispensación</h5>
            <button class="btn-close" @click="showDelete=false"></button>
          </div>
          <div class="modal-body">
            <p>¿Eliminar la dispensación de <strong>{{ deleteTarget?.cantidad_gramos }}g</strong>
              del {{ formatDate(deleteTarget?.fecha_dispensacion) }}?</p>
            <p class="text-muted small mb-0">El cupo se liberará nuevamente.</p>
          </div>
          <div class="modal-footer border-0">
            <button class="btn btn-outline-secondary" :disabled="deleting" @click="showDelete=false">Cancelar</button>
            <button class="btn btn-danger" :disabled="deleting" @click="handleDelete">
              <span v-if="deleting" class="spinner-border spinner-border-sm me-2"></span>
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    <div v-if="showDelete" class="modal-backdrop fade show" @click="showDelete=false"></div>

  </div>
</template>
