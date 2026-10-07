import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 7-oct-2026): «no puedo eliminar las tareas». El backend lo permitía y ninguna
// pantalla de Tareas lo ofrecía. Reglas: admin, supervisor y cultivador; una ya hecha, sólo admin.
const remove = vi.fn(() => Promise.resolve())
const confirmar = vi.fn(() => Promise.resolve(true))
vi.mock('../stores/tareas.js', () => ({ useTareasStore: () => ({ remove }) }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: confirmar }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../lib/api.js', () => ({ cancelarSerieTarea: vi.fn(() => Promise.resolve({ data: { canceladas: 3 } })) }))

const { useAuthStore } = await import('../stores/auth')
const { useEliminarTarea } = await import('../composables/useEliminarTarea.js')

function como(role) {
  setActivePinia(createPinia())
  useAuthStore().user = { role }
  return useEliminarTarea()
}

beforeEach(() => { remove.mockClear(); confirmar.mockClear() })

describe('Eliminar una tarea', () => {
  const pendiente = { id: 7, titulo: 'Revisar plagas', estado: 'pendiente' }
  const hecha     = { id: 8, titulo: 'Riego', estado: 'completada' }

  it('admin, supervisor y cultivador pueden eliminar una pendiente', () => {
    for (const r of ['admin', 'supervisor', 'cultivador']) expect(como(r).puedeEliminar(pendiente)).toBe(true)
  })

  it('el dispensador y la manicura no', () => {
    expect(como('dispensador').puedeEliminar(pendiente)).toBe(false)
    expect(como('manicura').puedeEliminar(pendiente)).toBe(false)
  })

  it('una ya hecha sólo la borra un admin (corrige historia)', () => {
    expect(como('admin').puedeEliminar(hecha)).toBe(true)
    expect(como('cultivador').puedeEliminar(hecha)).toBe(false)
  })

  it('pregunta antes y recién ahí borra', async () => {
    const { eliminar } = como('admin')
    expect(await eliminar(pendiente)).toBe(true)
    expect(confirmar).toHaveBeenCalled()
    expect(remove).toHaveBeenCalledWith(7)
  })

  it('si se arrepiente, no borra nada', async () => {
    confirmar.mockResolvedValueOnce(false)
    const { eliminar } = como('admin')
    expect(await eliminar(pendiente)).toBe(false)
    expect(remove).not.toHaveBeenCalled()
  })

  it('una que se repite ofrece cortar la serie', () => {
    const { esDeSerie } = como('admin')
    expect(esDeSerie({ recurrente: true })).toBe(true)
    expect(esDeSerie({ parent_tarea_id: 3 })).toBe(true)
    expect(esDeSerie(pendiente)).toBe(false)
  })
})
