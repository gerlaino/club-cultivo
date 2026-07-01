<template>
  <Teleport to="body">
    <div class="apm__overlay" @mousedown.self="$emit('close')">
      <div class="apm__modal">

        <!-- Header -->
        <div class="apm__header">
          <div>
            <h2 class="apm__title">Aplicar plan de trabajo</h2>
            <p class="apm__sub">Lote {{ lote.codigo }} · inicio {{ lote.start_date }}</p>
          </div>
          <button class="apm__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Body -->
        <div class="apm__body">

          <!-- Step 1: selector de plan -->
          <div class="apm__section">
            <label class="apm__label">Plan de trabajo</label>
            <div class="apm__select-row">
              <select class="apm__select" v-model="planId" @change="onPlanChange" :disabled="loadingPlanes || applying">
                <option value="" disabled>Seleccionar plan…</option>
                <option v-for="p in planes" :key="p.id" :value="p.id">
                  {{ p.titulo }} ({{ p.duracion_dias }}d)
                </option>
              </select>
              <button v-if="planId && !loadingPreview" class="apm__btn-refresh" @click="cargarPreview" title="Actualizar preview">
                <i class="bi bi-arrow-clockwise"></i>
              </button>
            </div>
            <p v-if="loadingPlanes" class="apm__hint">Cargando planes…</p>
            <p v-else-if="planes.length === 0" class="apm__hint apm__hint--warn">
              Sin planes <strong>publicados</strong>. Solo se pueden aplicar planes publicados —
              si el tuyo quedó en borrador, andá a
              <a href="/plan-trabajo" class="apm__link">Planes de trabajo</a>
              y publicalo (o creá uno con "Crear y publicar").
            </p>
          </div>

          <!-- Fecha de inicio del plan -->
          <div class="apm__section">
            <label class="apm__label">Fecha de inicio del plan</label>
            <AppDatePicker v-model="fechaInicio" @update:modelValue="onFechaChange" />
            <p class="apm__hint">
              Las tareas se calculan desde esta fecha. Si el lote ya venía empezado, ponela
              en el pasado y se generan las tareas pasadas para un registro fiel
              (después las marcás como realizadas).
            </p>
          </div>

          <!-- Loading preview -->
          <div v-if="loadingPreview" class="apm__preview-loading">
            <DsSpinner :size="28" />
            <span>Calculando tareas…</span>
          </div>

          <!-- Preview table -->
          <template v-else-if="preview">
            <div class="apm__preview-meta">
              <span class="apm__badge">{{ preview.total }} tarea{{ preview.total !== 1 ? 's' : '' }}</span>
              <span class="apm__hint">Fechas calculadas desde el {{ formatDate(fechaInicio) }}</span>
            </div>

            <div class="apm__table-wrap">
              <table class="apm__table">
                <thead>
                  <tr>
                    <th>Fecha</th>
                    <th>Tarea</th>
                    <th>Tipo</th>
                    <th>Prioridad</th>
                    <th>Responsable</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(t, i) in preview.tareas" :key="i">
                    <td class="apm__td-date">{{ formatDate(t.fecha) }}</td>
                    <td class="apm__td-titulo">{{ t.titulo }}</td>
                    <td><span class="apm__tipo">{{ TIPO_LABELS[t.tipo] || t.tipo }}</span></td>
                    <td><span class="apm__pri" :class="`apm__pri--${t.prioridad}`">{{ t.prioridad }}</span></td>
                    <td class="apm__td-resp">{{ t.responsable || '—' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <p v-if="preview.total === 0" class="apm__hint apm__hint--warn">
              El plan no generó tareas para este lote. Verificá que tenga plan-tareas configuradas.
            </p>
          </template>

          <!-- Error -->
          <div v-if="error" class="apm__error">
            <i class="bi bi-exclamation-triangle"></i> {{ error }}
          </div>

        </div>

        <!-- Footer -->
        <div class="apm__footer">
          <button class="apm__btn-ghost" @click="$emit('close')" :disabled="applying">Cancelar</button>
          <button
            class="apm__btn-primary"
            :disabled="!preview || preview.total === 0 || applying"
            @click="confirmarAplicar"
          >
            <DsSpinner v-if="applying" :size="14" />
            <i v-else class="bi bi-check2-all"></i>
            {{ applying ? 'Aplicando…' : `Aplicar ${preview?.total ?? ''} tareas` }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { listPlanTrabajos, previewLotePlan, aplicarLotePlan } from '../../lib/api.js'
import DsSpinner from '../../design-system/components/Spinner.vue'
import AppDatePicker from '../ui/AppDatePicker.vue'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  lote: { type: Object, required: true },
})
const emit = defineEmits(['close', 'applied'])

const toast = useToast()

const planes        = ref([])
const planId        = ref('')
const fechaInicio   = ref((props.lote.start_date || '').slice(0, 10) || new Date().toISOString().slice(0, 10))
const preview       = ref(null)
const loadingPlanes = ref(false)
const loadingPreview = ref(false)
const applying      = ref(false)
const error         = ref(null)

const TIPO_LABELS = {
  riego: 'Riego', poda: 'Poda', medicion: 'Medición', limpieza: 'Limpieza',
  cosecha: 'Cosecha', trasplante: 'Trasplante', inspeccion: 'Inspección',
  nutricion: 'Nutrición', defoliacion: 'Defoliación', scrog_lst: 'SCROG/LST',
  ajuste_luz: 'Ajuste luz', revision_plagas: 'Revisión plagas', otro: 'Otro',
}

onMounted(async () => {
  loadingPlanes.value = true
  try {
    // Solo planes PUBLICADOS: aplicar un borrador da 404 (el backend exige .publicados).
    const { data } = await listPlanTrabajos({ plantilla: 'true', estado: 'publicado', per_page: 50 })
    planes.value = Array.isArray(data) ? data : (data.planes ?? data.data ?? [])
  } catch {
    error.value = 'No se pudieron cargar los planes.'
  } finally {
    loadingPlanes.value = false
  }
})

function onPlanChange() {
  preview.value = null
  error.value   = null
  if (planId.value) cargarPreview()
}

function onFechaChange() {
  if (planId.value) cargarPreview()
}

async function cargarPreview() {
  if (!fechaInicio.value) { error.value = 'Elegí una fecha de inicio.'; return }
  loadingPreview.value = true
  error.value = null
  try {
    const { data } = await previewLotePlan(props.lote.id, planId.value, fechaInicio.value)
    preview.value = data
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al calcular el preview.'
    preview.value = null
  } finally {
    loadingPreview.value = false
  }
}

async function confirmarAplicar() {
  if (!planId.value || !preview.value || preview.value.total === 0) return
  applying.value = true
  error.value = null
  try {
    const { data } = await aplicarLotePlan(props.lote.id, planId.value, fechaInicio.value)
    toast.success(`${data.tareas_creadas} tarea${data.tareas_creadas !== 1 ? 's' : ''} creadas correctamente`)
    emit('applied', data.tareas_creadas)
  } catch (e) {
    error.value = e.response?.data?.error || 'Error al aplicar el plan.'
  } finally {
    applying.value = false
  }
}

function formatDate(iso) {
  if (!iso) return '—'
  const [y, m, d] = iso.split('-')
  return `${d}/${m}/${y}`
}
</script>

<style scoped>
.apm__overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,.45);
  display: flex; align-items: center; justify-content: center;
  z-index: 1200; padding: 1rem;
}
.apm__modal {
  background: #fff; border-radius: 14px; width: 100%; max-width: 760px;
  max-height: 90vh; display: flex; flex-direction: column;
  box-shadow: 0 20px 60px rgba(0,0,0,.18);
}
.apm__header {
  display: flex; align-items: flex-start; justify-content: space-between;
  padding: 1.25rem 1.5rem 1rem; border-bottom: 1px solid #e8f0e9;
}
.apm__title { font-size: 1.05rem; font-weight: 700; color: #1a2e1a; margin: 0 0 .15rem; }
.apm__sub   { font-size: .78rem; color: #64748b; margin: 0; }
.apm__close { background: none; border: none; color: #64748b; font-size: 1.1rem; cursor: pointer; padding: .25rem; line-height: 1; }
.apm__close:hover { color: #1a2e1a; }

.apm__body { flex: 1; overflow-y: auto; padding: 1.25rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; }

.apm__section { display: flex; flex-direction: column; gap: .4rem; }
.apm__label   { font-size: .78rem; font-weight: 600; color: #374151; }
.apm__select-row { display: flex; gap: .5rem; }
.apm__select {
  flex: 1; padding: .5rem .75rem; border: 1px solid #d1d5db; border-radius: 8px;
  font-size: .875rem; background: #fff; color: #111827;
}
.apm__select:focus { outline: none; border-color: #15803d; box-shadow: 0 0 0 2px #dcfce7; }
.apm__select:disabled { background: #f9fafb; color: #9ca3af; }
.apm__btn-refresh {
  padding: .5rem .75rem; border: 1px solid #d1d5db; border-radius: 8px;
  background: #fff; color: #6b7280; cursor: pointer; font-size: .9rem;
}
.apm__btn-refresh:hover { background: #f9fafb; color: #374151; }
.apm__hint      { font-size: .75rem; color: #6b7280; margin: 0; }
.apm__hint--warn { color: #b45309; }
.apm__link { color: #15803d; text-decoration: underline; }

.apm__preview-loading {
  display: flex; align-items: center; justify-content: center; gap: .75rem;
  padding: 2rem; color: #6b7280; font-size: .875rem;
}

.apm__preview-meta {
  display: flex; align-items: center; gap: .75rem;
}
.apm__badge {
  background: #dcfce7; color: #15803d; font-size: .75rem; font-weight: 700;
  padding: .2rem .6rem; border-radius: 99px;
}

.apm__table-wrap { overflow-x: auto; border: 1px solid #e5e7eb; border-radius: 8px; }
.apm__table { width: 100%; border-collapse: collapse; font-size: .8rem; }
.apm__table thead th {
  background: #f9fafb; padding: .5rem .75rem; text-align: left;
  font-size: .72rem; font-weight: 600; color: #6b7280; text-transform: uppercase;
  letter-spacing: .04em; border-bottom: 1px solid #e5e7eb;
}
.apm__table tbody tr:not(:last-child) td { border-bottom: 1px solid #f3f4f6; }
.apm__table td { padding: .5rem .75rem; color: #374151; vertical-align: middle; }
.apm__table tbody tr:hover td { background: #f9fafb; }
.apm__td-date  { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; color: #1a2e1a; }
.apm__td-titulo { max-width: 200px; }
.apm__td-resp  { color: #6b7280; white-space: nowrap; }

.apm__tipo {
  background: #f1f5f9; color: #475569; font-size: .7rem; font-weight: 500;
  padding: .15rem .45rem; border-radius: 4px;
}
.apm__pri {
  font-size: .7rem; font-weight: 700; padding: .15rem .45rem; border-radius: 4px;
}
.apm__pri--urgente { background: #fee2e2; color: #dc2626; }
.apm__pri--alta    { background: #ffedd5; color: #ea580c; }
.apm__pri--normal  { background: #f0fdf4; color: #16a34a; }
.apm__pri--baja    { background: #f1f5f9; color: #64748b; }

.apm__error {
  background: #fef2f2; border: 1px solid #fecaca; color: #dc2626;
  padding: .6rem .9rem; border-radius: 8px; font-size: .82rem;
  display: flex; align-items: center; gap: .5rem;
}

.apm__footer {
  display: flex; justify-content: flex-end; gap: .75rem;
  padding: 1rem 1.5rem; border-top: 1px solid #e8f0e9;
}
.apm__btn-ghost {
  padding: .55rem 1.1rem; border: 1px solid #d1d5db; border-radius: 8px;
  background: #fff; color: #374151; font-size: .875rem; font-weight: 500; cursor: pointer;
}
.apm__btn-ghost:hover:not(:disabled) { background: #f9fafb; }
.apm__btn-primary {
  display: inline-flex; align-items: center; gap: .4rem;
  padding: .55rem 1.25rem; border: none; border-radius: 8px;
  background: #15803d; color: #fff; font-size: .875rem; font-weight: 600; cursor: pointer;
}
.apm__btn-primary:hover:not(:disabled) { background: #166534; }
.apm__btn-primary:disabled { opacity: .5; cursor: not-allowed; }
</style>
