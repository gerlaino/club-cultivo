import { ref, watch } from 'vue'
import { useToast } from './useToast.js'
import { updatePaciente } from '../lib/api.js'

export function useSocioHistoriaClinica(socioId, { s }) {
  const { success: toastOk, error: toastErr } = useToast()

  const notasClinicas       = ref('')
  const notasClinicasSaved  = ref(true)
  const notasClinicasSaving = ref(false)

  const hcForm = ref({
    motivo_consulta:         '',
    anamnesis:               '',
    antecedentes_personales: '',
    antecedentes_familiares: '',
    diagnostico_principal:   '',
    diagnostico_secundario:  '',
    evolucion_clinica:       '',
    alergias:                '',
    medicacion_habitual:     '',
    grupo_sanguineo:         '',
  })

  watch(s, (val) => {
    if (!val) return
    notasClinicas.value = val.notas_clinicas || ''
    hcForm.value = {
      motivo_consulta:         val.motivo_consulta         || '',
      anamnesis:               val.anamnesis               || '',
      antecedentes_personales: val.antecedentes_personales || '',
      antecedentes_familiares: val.antecedentes_familiares || '',
      diagnostico_principal:   val.diagnostico_principal   || '',
      diagnostico_secundario:  val.diagnostico_secundario  || '',
      evolucion_clinica:       val.evolucion_clinica       || '',
      alergias:                val.alergias                || '',
      medicacion_habitual:     val.medicacion_habitual     || '',
      grupo_sanguineo:         val.grupo_sanguineo         || '',
    }
  }, { immediate: true })

  watch(notasClinicas, () => { notasClinicasSaved.value = false })
  watch(hcForm, () => { notasClinicasSaved.value = false }, { deep: true })

  async function saveNotasClinicas() {
    notasClinicasSaving.value = true
    try {
      await updatePaciente(socioId, { notas_clinicas: notasClinicas.value, ...hcForm.value })
      notasClinicasSaved.value = true
      toastOk('Historia clínica guardada')
    } catch {
      toastErr('Error al guardar historia clínica')
    } finally {
      notasClinicasSaving.value = false
    }
  }

  return {
    notasClinicas, notasClinicasSaved, notasClinicasSaving,
    hcForm,
    saveNotasClinicas,
  }
}
