// El historial de un lote y lo que se le hace desde «Historial» (registrar, trasplante, corregir,
// borrar). Lo usan la ficha de escritorio y la del teléfono: corregir o borrar un riego mal cargado
// es de todos los días y estaba sólo en la compu (20-oct-2026).
//
// `alCambiar({ lote })`: lo que la pantalla tiene que refrescar además del historial (gráficos,
// el lote si cambió la maceta). Los errores los dice el backend, tal cual.
import { ref } from 'vue'
import {
  getLoteHistorial, createLoteEvento, registrarTrasplante, updateLoteEvento,
  deleteLoteEvento, deleteRegistroAmbiental, deleteTarea,
} from '../lib/api'
import { useToast } from './useToast'
import { useConfirm } from './useConfirm.js'

const errorDe = (err, porDefecto) =>
  err?.response?.data?.errors?.[0] || err?.response?.data?.error || porDefecto

export function useHistorialLote(loteId, { alCambiar = () => {} } = {}) {
  const toast = useToast()
  const { confirm } = useConfirm()
  const historial        = ref([])
  const loadingHistorial = ref(false)

  async function loadHistorial() {
    loadingHistorial.value = true
    try {
      const { data } = await getLoteHistorial(loteId)
      historial.value = data.historial || []
    } catch { historial.value = [] }
    finally { loadingHistorial.value = false }
  }

  async function onCrearEvento(payload) {
    try {
      await createLoteEvento(loteId, payload)
      toast.success('Actividad registrada')
      await loadHistorial()
      alCambiar({ lote: false })
    } catch (err) {
      toast.error(errorDe(err, 'No se pudo registrar la actividad'))
    }
  }

  async function onTrasplante(payload) {
    try {
      await registrarTrasplante(loteId, payload)
      toast.success('Trasplante registrado')
      await loadHistorial()
      alCambiar({ lote: true })
    } catch (err) {
      toast.error(errorDe(err, 'No se pudo registrar el trasplante'))
    }
  }

  // Sólo edita eventos manuales de lote (el modal sólo muestra ✏️ en los editables).
  async function onEditarEvento(payload) {
    try {
      const attrs = { descripcion: payload.descripcion, registrado_en: payload.registrado_en }
      if (payload.metadata) attrs.metadata = payload.metadata
      await updateLoteEvento(loteId, payload.id, attrs)
      toast.success('Evento actualizado')
      await loadHistorial()
      alCambiar({ lote: false })
    } catch (err) {
      toast.error(errorDe(err, 'No se pudo actualizar el evento'))
    }
  }

  async function onDeleteEvento(it) {
    const LABEL = { lote_evento: 'evento', registro_ambiental: 'registro', tarea: 'tarea completada' }
    const ok = await confirm({
      title:       `Borrar ${LABEL[it.source] || 'ítem'} del historial`,
      message:     `¿Borrás "${it.titulo}" del historial?\n\nEsta acción no se puede deshacer.`,
      confirmText: 'Sí, borrar',
      variant:     'danger',
    })
    if (!ok) return
    try {
      if (it.source === 'registro_ambiental') await deleteRegistroAmbiental(loteId, it.id)
      else if (it.source === 'tarea')          await deleteTarea(it.id)
      else                                     await deleteLoteEvento(loteId, it.id)
      toast.success('Borrado del historial')
      await loadHistorial()
      alCambiar({ lote: false })
    } catch (err) {
      toast.error(errorDe(err, 'No se pudo borrar'))
    }
  }

  return { historial, loadingHistorial, loadHistorial, onCrearEvento, onTrasplante, onEditarEvento, onDeleteEvento }
}
