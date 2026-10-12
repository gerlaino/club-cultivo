import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

// AC (Germán, 12-oct-2026): «al cambiar de rol a algún miembro del equipo, que se cambie todo
// como corresponde». Si la persona tiene la app abierta, el backend ya le aplica los permisos
// nuevos: la pantalla tiene que recargar en el inicio de su rol nuevo y decirle por qué, no
// quedarse con el menú viejo y pantallas vacías. A los demás, el aviso no los mueve.
const handlers = {}
vi.mock('../lib/cambios.js', () => ({
  alCambiar: (recurso, fn) => { handlers[recurso] = fn; return () => {} },
  alCambiarAgrupado: () => () => {},
  olvidarCambios: () => {},
}))
vi.mock('../lib/cableConsumer.js', () => ({ cerrarCable: () => {} }))
vi.mock('../utils/reloadTrace.js', () => ({ anotarReload: vi.fn() }))

describe('Le cambian el rol con la app abierta', () => {
  let assign
  beforeEach(async () => {
    setActivePinia(createPinia())
    sessionStorage.clear()
    assign = vi.fn()
    Object.defineProperty(window, 'location', { value: { ...window.location, assign }, writable: true })
    vi.resetModules()
    const { engancharCambios } = await import('../lib/cambiosStores.js')
    engancharCambios()
  })

  async function conUsuario (id) {
    const { useAuthStore } = await import('../stores/auth.js')
    useAuthStore().user = { id, role: 'dispensador' }
  }

  it('si el aviso es para quien está mirando, recarga en su inicio y deja el aviso para mostrar', async () => {
    await conUsuario(7)
    handlers.usuarios({ recurso: 'usuarios', accion: 'rol', id: 7 })
    expect(assign).toHaveBeenCalledWith('/')
    expect(sessionStorage.getItem('aviso_rol')).toBe('1')
  })

  it('si le cambiaron el rol a otra persona, no pasa nada', async () => {
    await conUsuario(7)
    handlers.usuarios({ recurso: 'usuarios', accion: 'rol', id: 8 })
    expect(assign).not.toHaveBeenCalled()
  })

  it('otro cambio de esa persona (el nombre) no recarga', async () => {
    await conUsuario(7)
    handlers.usuarios({ recurso: 'usuarios', accion: 'actualizado', id: 7 })
    expect(assign).not.toHaveBeenCalled()
  })
})
