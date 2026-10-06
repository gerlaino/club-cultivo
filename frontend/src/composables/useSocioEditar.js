import { ref, toValue } from 'vue'
import { useToast } from './useToast.js'
import { usePacientesStore } from '../stores/pacientes'
import { updatePaciente } from '../lib/api.js'

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
  { value: 'otra_organizacion', label: 'Adherente', ayuda: 'Paciente nuevo con REPROCANN vigente, vinculado a otra organización por ahora.' },
]
export const vinculoLabel = (v) => REPROCANN_VINCULOS.find(x => x.value === v)?.label || null

// `socioIdRef` puede ser un número o un getter/ref: desde la LISTA de pacientes el id cambia
// según a quién se edite, y capturarlo por valor guardaba los cambios en el paciente anterior.
export function useSocioEditar(socioIdRef) {
  const socioIdActual = () => toValue(socioIdRef)
  const { success: toastOk, error: toastErr } = useToast()
  const store = usePacientesStore()

  const editOpen   = ref(false)
  const editForm   = ref({})
  const editSaving = ref(false)
  const editError  = ref(null)

  function openEdit() {
    const s = store.current
    editForm.value = {
      nombre:                         s?.nombre               || '',
      apellido:                       s?.apellido             || '',
      apodo:                          s?.apodo                || '',
      dni:                            s?.dni                  || '',
      fecha_nacimiento:               s?.fecha_nacimiento     || '',
      email:                          s?.email                || '',
      telefono:                       s?.telefono             || '',
      reprocann_numero:               s?.reprocann_numero     || '',
      reprocann_vencimiento:          s?.reprocann_vencimiento || '',
      reprocann_estado:               s?.reprocann_estado     || 'sin_registro',
      reprocann_vinculo:              s?.reprocann_vinculo    || '',
      es_paciente:                    s?.es_paciente          ?? true,
      descuento_porcentaje:           s?.descuento_porcentaje ?? 0,
      domicilio_calle:                s?.domicilio_calle      || '',
      domicilio_altura:               s?.domicilio_altura     || '',
      domicilio_piso:                 s?.domicilio_piso       || '',
      domicilio_depto:                s?.domicilio_depto      || '',
      domicilio_barrio:               s?.domicilio_barrio     || '',
      domicilio_ciudad:               s?.domicilio_ciudad     || '',
    }
    editError.value = null
    editOpen.value  = true
  }

  async function saveEdit() {
    // El domicilio NO frena la edición, igual que no frena el alta: se anota a la persona con lo
    // que hay y la dirección aparece después. Donde sí hace falta es al despachar un envío, y
    // ahí se pide. (Se sacó del alta y quedó acá, que es otra validación distinta.)
    editError.value = null
    editSaving.value = true
    try {
      const id = socioIdActual()
      await updatePaciente(id, editForm.value)
      await store.fetchOne(id)
      editOpen.value = false
      toastOk('Paciente actualizado')
    } catch (e) {
      const msgs = e?.response?.data?.errors
      editError.value = Array.isArray(msgs) ? msgs.join(', ') : 'Error al guardar'
    } finally {
      editSaving.value = false
    }
  }

  return {
    REPROCANN_ESTADOS, REPROCANN_VINCULOS,
    editOpen, editForm, editSaving, editError,
    openEdit, saveEdit,
  }
}
