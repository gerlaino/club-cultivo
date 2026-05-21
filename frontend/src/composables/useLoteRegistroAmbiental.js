import { ref, computed } from 'vue'
import { useToast } from './useToast.js'
import { createRegistroAmbiental } from '../lib/api'

export function useLoteRegistroAmbiental(loteId, { onSaved } = {}) {
  const toast = useToast()

  const showRegistroModal = ref(false)
  const savingRegistro    = ref(false)
  const registroError     = ref(null)
  const csvFile           = ref(null)
  const csvInput          = ref(null)

  function emptyRegistroForm() {
    return {
      temperatura: null, humedad: null, temperatura_sustrato: null, co2: null,
      ph: null, ec: null, ph_runoff: null, ppfd: null,
      horas_luz: null, espectro_luz: '',
      fertilizacion: false, notas_fertilizacion: '',
      plagas_observadas: 'ninguna', estado_general: 'bueno', observaciones: '',
      tareas_realizadas: [],
    }
  }

  const registroForm = ref(emptyRegistroForm())

  const registroErrors = computed(() => {
    const e = {}; const f = registroForm.value
    if (f.temperatura          && (f.temperatura < 0          || f.temperatura > 60))          e.temperatura = '0–60°C'
    if (f.temperatura_sustrato && (f.temperatura_sustrato < 0 || f.temperatura_sustrato > 60)) e.temperatura_sustrato = '0–60°C'
    if (f.humedad              && (f.humedad < 0              || f.humedad > 100))              e.humedad = '0–100%'
    if (f.ph                   && (f.ph < 0                   || f.ph > 14))                   e.ph = '0–14'
    if (f.ph_runoff            && (f.ph_runoff < 0            || f.ph_runoff > 14))             e.ph_runoff = '0–14'
    if (f.horas_luz            && (f.horas_luz < 0            || f.horas_luz > 24))             e.horas_luz = '0–24h'
    return e
  })

  function toggleTarea(key) {
    const t = registroForm.value.tareas_realizadas
    const idx = t.indexOf(key)
    if (idx === -1) t.push(key)
    else t.splice(idx, 1)
  }

  function handleCsvChange(e) {
    csvFile.value = e.target.files?.[0] || null
  }

  async function abrirRegistroModal() {
    registroForm.value  = emptyRegistroForm()
    registroError.value = null
    csvFile.value       = null
    showRegistroModal.value = true
  }

  async function guardarRegistro() {
    if (Object.keys(registroErrors.value).length > 0) return
    savingRegistro.value = true
    registroError.value  = null
    try {
      let result
      if (csvFile.value) {
        const fd = new FormData()
        Object.entries(registroForm.value).forEach(([k, v]) => {
          if (k === 'tareas_realizadas') {
            v.forEach(tarea => fd.append('registro_ambiental[tareas_realizadas][]', tarea))
          } else if (v !== null && v !== '') {
            fd.append(`registro_ambiental[${k}]`, v)
          }
        })
        fd.append('archivo_csv', csvFile.value)
        const { data } = await createRegistroAmbiental(loteId, fd, true)
        result = data
      } else {
        const { data } = await createRegistroAmbiental(loteId, registroForm.value)
        result = data
      }
      onSaved?.(result)
      showRegistroModal.value = false
      registroForm.value      = emptyRegistroForm()
      csvFile.value           = null
    } catch (e) {
      registroError.value = e?.response?.data?.errors?.join(', ') || 'Error al guardar'
    } finally {
      savingRegistro.value = false
    }
  }

  return {
    showRegistroModal, savingRegistro, registroError, csvFile, csvInput,
    registroForm, registroErrors,
    abrirRegistroModal, guardarRegistro, toggleTarea, handleCsvChange,
  }
}
