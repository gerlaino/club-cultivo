// «No se hizo» (7-oct-2026): el par de «Completar». Pregunta con un motivo opcional («no llegué»,
// «faltó el producto»), guarda y avisa. Una sola versión para todas las pantallas donde se
// completa una tarea: la lista, el teléfono, el inicio y la ficha del lote.
//
// Devuelve la tarea actualizada, o null si se arrepintió o falló (el error ya se mostró).
import { useConfirm } from './useConfirm.js'
import { useToast } from './useToast.js'
import { useTareasStore } from '../stores/tareas.js'

export function useNoSeHizo() {
  const { confirm } = useConfirm()
  const toast = useToast()
  const tareas = useTareasStore()

  async function marcarNoSeHizo(tarea) {
    const r = await confirm({
      title:       '¿No se hizo?',
      message:     `«${tarea.titulo}» queda registrada como no hecha y sale de pendientes.`,
      variant:     'warning',
      confirmText: 'No se hizo',
      cancelText:  'Volver',
      campo:       { label: 'Por qué (opcional)', placeholder: 'No llegué, faltó el producto…' },
    })
    if (!r) return null
    try {
      const actualizada = await tareas.noRealizada(tarea.id, r.valor || '')
      toast.success('Anotado: no se hizo')
      return actualizada
    } catch (e) {
      toast.error(e?.response?.data?.error || 'No se pudo marcar')
      return null
    }
  }

  return { marcarNoSeHizo }
}
