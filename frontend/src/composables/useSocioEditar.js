import { ref, toValue } from 'vue'
import { useToast } from './useToast.js'
import { usePacientesStore } from '../stores/pacientes'
import { updatePaciente } from '../lib/api.js'
import {
  desdePaciente, aPayload, validarPersona, validarReprocann,
} from '../components/pacientes/formulario/pacienteForm.js'

export const REPROCANN_ESTADOS = [
  { value: 'sin_registro', label: 'Sin registro',         color: '#94a3b8', bg: '#f8fafc' },
  { value: 'pendiente',    label: 'Pendiente de aprobación', color: '#b45309', bg: '#fffbeb' },
  // «Vigente», no «Activo» (2-oct-2026): activo/inactivo es el PACIENTE en la organización (el tilde
  // de abajo), no su REPROCANN. El valor guardado sigue siendo `activo`. «Inactivo» no es un estado
  // del REPROCANN y se sacó; «Vencido» lo calcula la fecha solo (`reprocann_estado_efectivo`).
  { value: 'activo',       label: 'Vigente',              color: '#15803d', bg: '#f0fdf4' },
  // «Vencido» se puede elegir a mano desde el 6-oct-2026 (Javi): saben que venció aunque no tengan
  // la fecha. Con fecha pasada igual sale vencido solo (lo calcula el backend).
  { value: 'vencido',      label: 'Vencido',              color: '#dc2626', bg: '#fef2f2' },
]

// DE QUIÉN ES SU REPROCANN (6-oct-2026), aparte del estado. Vacío = sin dato.
export const REPROCANN_VINCULOS = [
  { value: 'organizacion',      label: 'Vinculado', ayuda: 'Su REPROCANN está con la organización.' },
  { value: 'otra_organizacion', label: 'Adherente', ayuda: 'Tiene su REPROCANN vigente con otra organización.' },
]
export const vinculoLabel = (v) => REPROCANN_VINCULOS.find(x => x.value === v)?.label || null

// Lo que el médico puede escribir (espeja `Paciente::CAMPOS_SALUD` en lo que este formulario toca).
const CAMPOS_MEDICO = ['reprocann_numero', 'reprocann_vencimiento', 'reprocann_estado', 'reprocann_vinculo']
const CAMPOS_SOLO_ADMIN = ['es_paciente', 'descuento_porcentaje']
// Las direcciones de entrega viven en la solapa «Direcciones» de la ficha: la edición no las manda.
const CAMPOS_ENVIO = ['envio_etiqueta', 'envio_calle', 'envio_altura', 'envio_piso', 'envio_depto', 'envio_barrio', 'envio_ciudad']

// La edición usa el MISMO formulario que el alta (`pacienteForm.js`, 19-oct-2026).
// `socioIdRef` puede ser un número o un getter/ref: desde la LISTA de pacientes el id cambia
// según a quién se edite, y capturarlo por valor guardaba los cambios en el paciente anterior.
export function useSocioEditar(socioIdRef, { rol = () => 'admin' } = {}) {
  const socioIdActual = () => toValue(socioIdRef)
  const { success: toastOk } = useToast()
  const store = usePacientesStore()

  const editOpen    = ref(false)
  const editForm    = ref({})
  const editSaving  = ref(false)
  const editError   = ref(null)
  const editErrores = ref({ persona: {}, reprocann: {} })

  function openEdit() {
    editForm.value = desdePaciente(store.current)
    editError.value = null
    editErrores.value = { persona: {}, reprocann: {} }
    editOpen.value  = true
  }

  // Valida todo; devuelve la primera solapa con algo mal (o null).
  function validar() {
    const r = toValue(rol)
    const persona = r === 'medico' ? {} : validarPersona(editForm.value)
    const reprocann = validarReprocann(editForm.value)
    editErrores.value = { persona, reprocann }
    if (Object.keys(persona).length) return 'persona'
    if (Object.keys(reprocann).length) return 'reprocann'
    return null
  }

  async function saveEdit() {
    editError.value = null
    if (validar()) return false
    editSaving.value = true
    try {
      const r = toValue(rol)
      const campos = r === 'medico' ? CAMPOS_MEDICO : null
      const payload = aPayload(editForm.value, { campos })
      CAMPOS_ENVIO.forEach(k => delete payload[k])
      if (!['admin', 'super_admin'].includes(r)) CAMPOS_SOLO_ADMIN.forEach(k => delete payload[k])
      const id = socioIdActual()
      await updatePaciente(id, payload)
      await store.fetchOne(id)
      editOpen.value = false
      toastOk('Paciente actualizado')
      return true
    } catch (e) {
      const msgs = e?.response?.data?.errors
      editError.value = Array.isArray(msgs) ? msgs.join(', ') : (e?.response?.data?.error || 'No se pudo guardar')
      return false
    } finally {
      editSaving.value = false
    }
  }

  return {
    REPROCANN_ESTADOS, REPROCANN_VINCULOS,
    editOpen, editForm, editSaving, editError, editErrores,
    openEdit, saveEdit, validar,
  }
}
