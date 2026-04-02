<template>
  <div v-if="show" class="modal fade show d-block" tabindex="-1" aria-modal="true">
    <div class="modal-dialog modal-dialog-centered">
      <div class="modal-content">

        <!-- Header -->
        <div class="modal-header border-0 pb-0">
          <div>
            <h5 class="modal-title fw-bold">
              {{ accionMeta.emoji }} {{ accionMeta.label }}
            </h5>
            <p class="text-muted small mb-0">
              <span v-if="modo === 'lote'">
                Lote <strong>{{ contexto?.codigo }}</strong> —
                se aplicará a <strong>{{ totalPlantas }}</strong> planta{{ totalPlantas !== 1 ? 's' : '' }}
              </span>
              <span v-else>
                Planta <strong>{{ contexto?.nombre || contexto?.codigo_qr }}</strong>
              </span>
            </p>
          </div>
          <button class="btn-close" @click="$emit('cerrar')"></button>
        </div>

        <div class="modal-body pt-3">

          <!-- Selector de tipo (solo si se abre genérico) -->
          <div v-if="!tipoFijo" class="mb-4">
            <label class="form-label fw-semibold small">Tipo de actividad</label>
            <div class="acciones-grid">
              <button
                v-for="tipo in TIPOS"
                :key="tipo.value"
                type="button"
                class="accion-chip"
                :class="{ 'accion-chip--selected': form.activity_type === tipo.value }"
                @click="form.activity_type = tipo.value"
              >
                <span class="accion-chip__emoji">{{ tipo.emoji }}</span>
                <span class="accion-chip__label">{{ tipo.label }}</span>
              </button>
            </div>
          </div>

          <!-- Campos específicos por tipo -->

          <!-- Medición -->
          <div v-if="form.activity_type === 'measurement'" class="mb-3">
            <label class="form-label fw-semibold small">Mediciones</label>
            <div class="row g-2">
              <div class="col-6">
                <div class="input-group input-group-sm">
                  <span class="input-group-text">pH</span>
                  <input v-model.number="form.ph" type="number" class="form-control" step="0.1" min="0" max="14" placeholder="7.0">
                </div>
              </div>
              <div class="col-6">
                <div class="input-group input-group-sm">
                  <span class="input-group-text">EC</span>
                  <input v-model.number="form.ec" type="number" class="form-control" step="0.1" placeholder="1.2">
                  <span class="input-group-text">mS</span>
                </div>
              </div>
              <div class="col-6">
                <div class="input-group input-group-sm">
                  <span class="input-group-text">🌡️</span>
                  <input v-model.number="form.temperatura" type="number" class="form-control" step="0.5" placeholder="24">
                  <span class="input-group-text">°C</span>
                </div>
              </div>
              <div class="col-6">
                <div class="input-group input-group-sm">
                  <span class="input-group-text">💧</span>
                  <input v-model.number="form.humedad" type="number" class="form-control" step="1" min="0" max="100" placeholder="60">
                  <span class="input-group-text">%</span>
                </div>
              </div>
              <div class="col-6">
                <div class="input-group input-group-sm">
                  <span class="input-group-text">📏</span>
                  <input v-model.number="form.altura_cm" type="number" class="form-control" step="1" placeholder="45">
                  <span class="input-group-text">cm</span>
                </div>
              </div>
              <div class="col-6">
                <div class="input-group input-group-sm">
                  <span class="input-group-text">💡</span>
                  <input v-model.number="form.horas_luz" type="number" class="form-control" step="1" min="0" max="24" placeholder="18">
                  <span class="input-group-text">h</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Riego -->
          <div v-if="form.activity_type === 'watering'" class="mb-3">
            <label class="form-label fw-semibold small">Cantidad de agua (opcional)</label>
            <div class="input-group input-group-sm">
              <input v-model.number="form.litros" type="number" class="form-control" step="0.1" min="0" placeholder="2.0">
              <span class="input-group-text">litros</span>
            </div>
          </div>

          <!-- Cambio de estado -->
          <div v-if="form.activity_type === 'state_change'" class="mb-3">
            <label class="form-label fw-semibold small">Nuevo estado</label>
            <div class="estados-grid">
              <button
                v-for="estado in ESTADOS"
                :key="estado.value"
                type="button"
                class="estado-chip"
                :class="{ 'estado-chip--selected': form.nuevo_estado === estado.value }"
                @click="form.nuevo_estado = estado.value"
              >
                {{ estado.emoji }} {{ estado.label }}
              </button>
            </div>
          </div>

          <!-- Fecha -->
          <div class="mb-3">
            <label class="form-label fw-semibold small">Fecha y hora</label>
            <input v-model="form.occurred_at" type="datetime-local" class="form-control form-control-sm">
          </div>

          <!-- Descripción + Voz -->
          <div class="mb-3">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <label class="form-label fw-semibold small mb-0">Notas</label>
              <!-- Botón de voz -->
              <VoiceInput
                :contexto="contextoVoz"
                @campos-detectados="onVozDetectada"
              />
            </div>
            <textarea
              v-model="form.description"
              class="form-control form-control-sm"
              rows="2"
              :placeholder="placeholderDescripcion"
            ></textarea>
          </div>

          <!-- Preview modo lote -->
          <div v-if="modo === 'lote'" class="alert alert-info py-2 small">
            <i class="bi bi-info-circle-fill me-2"></i>
            Esta acción se registrará en las <strong>{{ totalPlantas }} plantas activas</strong> del lote.
          </div>

          <!-- Error -->
          <div v-if="error" class="alert alert-danger py-2 small">
            <i class="bi bi-exclamation-triangle me-2"></i>{{ error }}
          </div>

        </div>

        <div class="modal-footer border-0 pt-0">
          <button type="button" class="btn btn-outline-secondary" @click="$emit('cerrar')">
            Cancelar
          </button>
          <button
            type="button"
            class="btn btn-success"
            @click="guardar"
            :disabled="guardando || !form.activity_type"
          >
            <span v-if="guardando" class="spinner-border spinner-border-sm me-2"></span>
            <i v-else class="bi bi-check-lg me-2"></i>
            {{ modo === 'lote' ? `Registrar en ${totalPlantas} plantas` : 'Registrar' }}
          </button>
        </div>

      </div>
    </div>
  </div>
  <div v-if="show" class="modal-backdrop fade show" @click="$emit('cerrar')"></div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { createPlantActivity } from '../../lib/api.js'
import VoiceInput from '../VoiceInput.vue'

const props = defineProps({
  show:       { type: Boolean, default: false },
  // 'planta' o 'lote'
  modo:       { type: String,  default: 'planta' },
  // Si modo=planta: objeto planta. Si modo=lote: objeto lote con plantas[]
  contexto:   { type: Object,  default: null },
  // Si se quiere fijar el tipo desde afuera (ej: al hacer click en "Regar")
  tipoInicial: { type: String, default: null }
})

const emit = defineEmits(['guardada', 'cerrar'])

const guardando = ref(false)
const error     = ref('')
const tipoFijo  = computed(() => !!props.tipoInicial)

const TIPOS = [
  { value: 'watering',      emoji: '💧', label: 'Riego' },
  { value: 'fertilization', emoji: '🧪', label: 'Fertilización' },
  { value: 'pruning',       emoji: '✂️',  label: 'Poda' },
  { value: 'measurement',   emoji: '📏', label: 'Medición' },
  { value: 'state_change',  emoji: '🔄', label: 'Cambio estado' },
  { value: 'transplant',    emoji: '🪴', label: 'Trasplante' },
  { value: 'note',          emoji: '📝', label: 'Nota' },
  { value: 'other',         emoji: '📋', label: 'Otro' },
]

const ESTADOS = [
  { value: 'germinacion', emoji: '🌰', label: 'Germinación' },
  { value: 'vegetativo',  emoji: '🌱', label: 'Vegetativo' },
  { value: 'floracion',   emoji: '🌸', label: 'Floración' },
  { value: 'secado',      emoji: '🍂', label: 'Secado' },
  { value: 'cosechada',   emoji: '✅', label: 'Cosechada' },
  { value: 'descartada',  emoji: '❌', label: 'Descartada' },
]

const accionMeta = computed(() => {
  const tipo = TIPOS.find(t => t.value === form.value.activity_type)
  return tipo || { emoji: '📋', label: 'Actividad' }
})

const totalPlantas = computed(() => {
  if (props.modo !== 'lote' || !props.contexto) return 0
  return (props.contexto.plantas || []).filter(p =>
    !['cosechada', 'descartada'].includes(p.state)
  ).length
})

const placeholderDescripcion = computed(() => {
  const placeholders = {
    watering:      'Ej: 2 litros, agua a temperatura ambiente',
    fertilization: 'Ej: Nutriente A 5ml/L, semana 3 de floración',
    pruning:       'Ej: Poda de ramas bajas, defoliación leve',
    measurement:   'Observaciones adicionales...',
    state_change:  'Motivo del cambio de estado...',
    note:          'Observación o novedad...',
  }
  return placeholders[form.value.activity_type] || 'Notas opcionales...'
})

const contextoVoz = computed(() => {
  const tipo = form.value.activity_type
  const map = {
    watering:      'registro de riego: litros, pH, observaciones',
    fertilization: 'registro de fertilización: producto, dosis, observaciones',
    measurement:   'medición: pH, EC, temperatura en °C, humedad en %, altura en cm, horas de luz',
    pruning:       'registro de poda: tipo de poda, observaciones',
    note:          'nota o novedad sobre la planta',
  }
  return map[tipo] || 'actividad de cultivo: tipo, descripción, observaciones'
})

function formVacio() {
  return {
    activity_type: props.tipoInicial || '',
    description:   '',
    occurred_at:   new Date().toISOString().slice(0, 16),
    ph:            null,
    ec:            null,
    temperatura:   null,
    humedad:       null,
    altura_cm:     null,
    horas_luz:     null,
    litros:        null,
    nuevo_estado:  null,
  }
}

const form = ref(formVacio())

watch(() => props.show, (val) => {
  if (val) {
    form.value = formVacio()
    error.value = ''
  }
})

// ── Voz ───────────────────────────────────────────────
function onVozDetectada(campos) {
  if (campos.description || campos._transcripcion) {
    form.value.description = campos.description || campos._transcripcion
  }
  if (campos.ph)          form.value.ph          = campos.ph
  if (campos.ec)          form.value.ec          = campos.ec
  if (campos.temperatura) form.value.temperatura = campos.temperatura
  if (campos.humedad)     form.value.humedad     = campos.humedad
  if (campos.altura_cm)   form.value.altura_cm   = campos.altura_cm
  if (campos.litros)      form.value.litros      = campos.litros
  if (campos.horas_luz)   form.value.horas_luz   = campos.horas_luz
}

// ── Guardar ───────────────────────────────────────────
async function guardar() {
  if (!form.value.activity_type) { error.value = 'Seleccioná el tipo de actividad'; return }
  if (form.value.activity_type === 'state_change' && !form.value.nuevo_estado) {
    error.value = 'Seleccioná el nuevo estado'
    return
  }

  guardando.value = true
  error.value     = ''

  try {
    // Construir el payload de actividad
    const payload = buildPayload()

    if (props.modo === 'lote') {
      // Aplicar a todas las plantas activas del lote
      const plantasActivas = (props.contexto.plantas || []).filter(p =>
        !['cosechada', 'descartada'].includes(p.state)
      )
      await Promise.all(
        plantasActivas.map(planta => createPlantActivity(planta.id, payload))
      )
      emit('guardada', { modo: 'lote', cantidad: plantasActivas.length, tipo: form.value.activity_type })
    } else {
      // Aplicar a la planta individual
      const resultado = await createPlantActivity(props.contexto.id, payload)
      emit('guardada', { modo: 'planta', actividad: resultado.data })
    }

  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Error al registrar la actividad'
  } finally {
    guardando.value = false
  }
}

function buildPayload() {
  // Construir description enriquecida con las mediciones
  let description = form.value.description || ''

  if (form.value.activity_type === 'measurement') {
    const mediciones = []
    if (form.value.ph)          mediciones.push(`pH: ${form.value.ph}`)
    if (form.value.ec)          mediciones.push(`EC: ${form.value.ec} mS`)
    if (form.value.temperatura) mediciones.push(`Temp: ${form.value.temperatura}°C`)
    if (form.value.humedad)     mediciones.push(`Humedad: ${form.value.humedad}%`)
    if (form.value.altura_cm)   mediciones.push(`Altura: ${form.value.altura_cm}cm`)
    if (form.value.horas_luz)   mediciones.push(`Luz: ${form.value.horas_luz}h`)
    if (mediciones.length) {
      description = mediciones.join(' | ') + (description ? ` — ${description}` : '')
    }
  }

  if (form.value.activity_type === 'watering' && form.value.litros) {
    description = `${form.value.litros}L` + (description ? ` — ${description}` : '')
  }

  if (form.value.activity_type === 'state_change' && form.value.nuevo_estado) {
    description = `→ ${form.value.nuevo_estado}` + (description ? ` — ${description}` : '')
  }

  return {
    activity_type: form.value.activity_type,
    description:   description || null,
    occurred_at:   form.value.occurred_at,
    // Metadata como JSON en description — el modelo lo soporta via text
    metadata: {
      ph:          form.value.ph,
      ec:          form.value.ec,
      temperatura: form.value.temperatura,
      humedad:     form.value.humedad,
      altura_cm:   form.value.altura_cm,
      horas_luz:   form.value.horas_luz,
      litros:      form.value.litros,
      nuevo_estado: form.value.nuevo_estado,
    }
  }
}
</script>

<style scoped>
.acciones-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
}
@media (max-width: 480px) {
  .acciones-grid { grid-template-columns: repeat(3, 1fr); }
}

.accion-chip {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 10px 6px;
  border-radius: 10px;
  border: 2px solid var(--bs-border-color);
  background: var(--bs-body-bg);
  cursor: pointer;
  transition: all 0.15s;
}
.accion-chip:hover { border-color: #198754; background: rgba(25,135,84,0.06); }
.accion-chip--selected { border-color: #198754 !important; background: rgba(25,135,84,0.1) !important; }
.accion-chip__emoji { font-size: 1.3rem; }
.accion-chip__label { font-size: 0.65rem; font-weight: 600; text-align: center; color: var(--bs-body-color); }

.estados-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.estado-chip {
  padding: 6px 14px;
  border-radius: 20px;
  border: 2px solid var(--bs-border-color);
  background: var(--bs-body-bg);
  font-size: 0.8rem;
  cursor: pointer;
  transition: all 0.15s;
}
.estado-chip:hover { border-color: #0d6efd; }
.estado-chip--selected { border-color: #0d6efd !important; background: rgba(13,110,253,0.1) !important; font-weight: 600; }
</style>
