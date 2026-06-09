<script setup>
import { ref } from 'vue'
import DsSpinner from '../../design-system/components/Spinner.vue'
import { exportPlanCSV } from '../../lib/api.js'
import { useToast } from '../../composables/useToast.js'

const props = defineProps({
  plan: { type: Object, required: true },
})
const emit = defineEmits(['close'])
const toast = useToast()

function isoHoy() { return new Date().toISOString().slice(0, 10) }

const fechaInicio = ref(isoHoy())
const descargando = ref(false)

function formatFecha(iso) {
  if (!iso) return ''
  const [y, m, d] = iso.split('-')
  return `${d}/${m}/${y}`
}

// Calcula la fecha de fin estimada según la última tarea de la plantilla
const ultimoDia = props.plan.plan_tareas?.reduce((max, t) => Math.max(max, t.dia_relativo ?? 0), 0) ?? 0

function fechaEstimadaFin() {
  if (!fechaInicio.value) return ''
  const d = new Date(fechaInicio.value + 'T00:00:00')
  d.setDate(d.getDate() + ultimoDia)
  return formatFecha(d.toISOString().slice(0, 10))
}

function triggerDownload(blob, filename) {
  const url = URL.createObjectURL(blob)
  const a   = document.createElement('a')
  a.href     = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

async function descargar() {
  if (!fechaInicio.value) return
  descargando.value = true
  try {
    const { data } = await exportPlanCSV(props.plan.id, { modo: 'calendario', fecha_inicio: fechaInicio.value })
    const filename = `${props.plan.titulo.toLowerCase().replace(/\s+/g, '-')}-calendario.csv`
    triggerDownload(data, filename)
    toast.success('Calendario descargado')
    emit('close')
  } catch (e) {
    toast.error('Error al exportar el calendario')
  } finally {
    descargando.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="ecm__overlay" @click.self="$emit('close')">
      <div class="ecm__panel">

        <!-- Header -->
        <div class="ecm__hdr">
          <div class="ecm__hdr-ico"><i class="bi bi-calendar3-week"></i></div>
          <div>
            <h2 class="ecm__title">Exportar como calendario</h2>
            <p class="ecm__sub">{{ plan.titulo }}</p>
          </div>
          <button class="ecm__close" @click="$emit('close')"><i class="bi bi-x-lg"></i></button>
        </div>

        <!-- Body -->
        <div class="ecm__body">

          <!-- Fecha de inicio -->
          <div class="ecm__field">
            <label class="ecm__label">Fecha de inicio del plan</label>
            <input class="ecm__input" type="date" v-model="fechaInicio" />
          </div>

          <!-- Info resumen -->
          <div class="ecm__info">
            <div class="ecm__info-row">
              <i class="bi bi-list-task"></i>
              <span>{{ plan.total_plan_tareas }} tarea{{ plan.total_plan_tareas !== 1 ? 's' : '' }}</span>
            </div>
            <div class="ecm__info-row">
              <i class="bi bi-calendar-range"></i>
              <span>
                {{ formatFecha(fechaInicio) }}
                <span v-if="ultimoDia > 0"> → {{ fechaEstimadaFin() }} ({{ ultimoDia + 1 }} días)</span>
              </span>
            </div>
          </div>

          <!-- Descripción del formato -->
          <div class="ecm__formato">
            <div class="ecm__formato-title">Columnas del archivo CSV:</div>
            <div class="ecm__chips">
              <span class="ecm__chip">semana</span>
              <span class="ecm__chip">fecha</span>
              <span class="ecm__chip">dia_semana</span>
              <span class="ecm__chip">tipo</span>
              <span class="ecm__chip">tarea</span>
              <span class="ecm__chip">descripcion</span>
              <span class="ecm__chip">rol</span>
              <span class="ecm__chip">prioridad</span>
            </div>
            <p class="ecm__formato-hint">
              Abre en Excel o Google Sheets. La columna "semana" te permite agrupar las tareas por semana del ciclo.
            </p>
          </div>

        </div>

        <!-- Footer -->
        <div class="ecm__footer">
          <button class="ecm__btn-ghost" @click="$emit('close')">Cancelar</button>
          <button class="ecm__btn-primary" :disabled="!fechaInicio || descargando" @click="descargar">
            <DsSpinner v-if="descargando" :size="14" />
            <i v-else class="bi bi-download"></i>
            {{ descargando ? 'Descargando…' : 'Descargar CSV' }}
          </button>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.ecm__overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; z-index: 1065; padding: 1rem; backdrop-filter: blur(3px); }
.ecm__panel   { background: #fff; border-radius: 16px; width: 100%; max-width: 440px; display: flex; flex-direction: column; box-shadow: 0 24px 64px rgba(0,0,0,.15); }

.ecm__hdr     { display: flex; align-items: center; gap: .875rem; padding: 1.25rem 1.4rem 1rem; border-bottom: 1px solid #f1f5f9; }
.ecm__hdr-ico { width: 38px; height: 38px; border-radius: 10px; background: #eff6ff; color: #2563eb; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; flex-shrink: 0; }
.ecm__title   { font-size: 1rem; font-weight: 800; color: #0f172a; margin: 0 0 .1rem; }
.ecm__sub     { font-size: .78rem; color: #60725d; margin: 0; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 260px; }
.ecm__close   { margin-left: auto; background: #f1f5f9; border: none; width: 30px; height: 30px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; color: #64748b; flex-shrink: 0; }

.ecm__body  { padding: 1.25rem 1.4rem; display: flex; flex-direction: column; gap: 1rem; }
.ecm__field { display: flex; flex-direction: column; gap: .3rem; }
.ecm__label { font-size: .72rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ecm__input { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 9px; padding: .6rem .875rem; font-size: .875rem; color: #0f172a; width: 100%; box-sizing: border-box; }
.ecm__input:focus { outline: none; border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37,99,235,.08); }

.ecm__info { background: #f0fdf4; border: 1.5px solid #c8e6c9; border-radius: 10px; padding: .75rem 1rem; display: flex; flex-direction: column; gap: .4rem; }
.ecm__info-row { display: flex; align-items: center; gap: .5rem; font-size: .82rem; color: #1b5e20; font-weight: 600; }

.ecm__formato { background: #f8fafc; border: 1.5px solid #e2e8f0; border-radius: 10px; padding: .875rem 1rem; display: flex; flex-direction: column; gap: .5rem; }
.ecm__formato-title { font-size: .7rem; font-weight: 700; color: #374151; text-transform: uppercase; letter-spacing: .04em; }
.ecm__chips { display: flex; flex-wrap: wrap; gap: .3rem; }
.ecm__chip  { font-size: .7rem; font-weight: 700; color: #475569; background: #e2e8f0; padding: .2em .55em; border-radius: 5px; font-family: monospace; }
.ecm__formato-hint { font-size: .72rem; color: #94a3b8; margin: 0; line-height: 1.4; }

.ecm__footer { display: flex; align-items: center; justify-content: flex-end; gap: .75rem; padding: 1rem 1.4rem; border-top: 1px solid #f1f5f9; }
.ecm__btn-ghost   { background: transparent; color: #64748b; border: 1.5px solid #e2e8f0; padding: .6rem 1rem; border-radius: 9px; font-size: .875rem; font-weight: 600; cursor: pointer; }
.ecm__btn-primary { display: inline-flex; align-items: center; gap: .4rem; background: #2563eb; color: #fff; border: none; padding: .6rem 1.25rem; border-radius: 9px; font-size: .875rem; font-weight: 700; cursor: pointer; }
.ecm__btn-primary:hover:not(:disabled) { background: #1d4ed8; }
.ecm__btn-primary:disabled { opacity: .55; cursor: not-allowed; }
</style>
