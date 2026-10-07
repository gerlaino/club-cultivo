// ELIMINAR UNA TAREA (7-oct-2026). El backend lo permitía desde siempre (`DELETE /tareas/:id`) y
// ninguna pantalla de Tareas lo ofrecía: sólo se podía desde el historial del lote. Una versión
// para el escritorio y el teléfono.
//
// Las reglas son las del backend (`TareasController#authorize_manage!` y `#destroy`): admin,
// supervisor y cultivador; una tarea ya HECHA sólo la borra un admin (corrige historia). Una que
// se repite puede cortarse entera: las que faltan de la serie se cancelan.
import { useConfirm } from './useConfirm.js'
import { useToast } from './useToast.js'
import { useAuthStore } from '../stores/auth'
import { useTareasStore } from '../stores/tareas.js'
import { cancelarSerieTarea } from '../lib/api.js'

const GESTIONAN = ['admin', 'supervisor', 'cultivador']

export function useEliminarTarea() {
  const { confirm } = useConfirm()
  const toast = useToast()
  const auth = useAuthStore()
  const tareas = useTareasStore()

  const esDeSerie = (t) => !!(t?.recurrente || t?.parent_tarea_id)

  function puedeEliminar(t) {
    const rol = auth.user?.role
    if (!t || !GESTIONAN.includes(rol)) return false
    return t.estado !== 'completada' || rol === 'admin'
  }

  // true si se borró.
  async function eliminar(t) {
    const ok = await confirm({
      title:       '¿Eliminar la tarea?',
      message:     `«${t.titulo}» se borra de la lista.` +
                   (esDeSerie(t) ? ' Sólo esta: las otras de la serie siguen (para cortarlas todas, «Cortar la serie»).' : '') +
                   (t.origen_plan_id ? ' Es de un plan: no vuelve a aparecer.' : ''),
      variant:     'danger',
      confirmText: 'Eliminar',
      cancelText:  'Volver',
    })
    if (!ok) return false
    try {
      await tareas.remove(t.id)
      toast.success('Tarea eliminada')
      return true
    } catch (e) {
      toast.error(e?.response?.data?.error || 'No se pudo eliminar la tarea')
      return false
    }
  }

  // true si se cortó. Las ya hechas o no hechas quedan como historia.
  async function cortarSerie(t) {
    const ok = await confirm({
      title:       '¿Cortar la serie?',
      message:     `Las que faltan de «${t.titulo}» se cancelan. Las que ya se hicieron (o no) quedan en la historia.`,
      variant:     'danger',
      confirmText: 'Cortar la serie',
      cancelText:  'Volver',
    })
    if (!ok) return false
    try {
      const { data } = await cancelarSerieTarea(t.id)
      toast.success(`Serie cortada: ${data?.canceladas ?? 0} ${data?.canceladas === 1 ? 'tarea cancelada' : 'tareas canceladas'}`)
      return true
    } catch (e) {
      toast.error(e?.response?.data?.error || 'No se pudo cortar la serie')
      return false
    }
  }

  return { puedeEliminar, eliminar, cortarSerie, esDeSerie }
}
