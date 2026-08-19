import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import CredencialesNuevas from '../components/ui/CredencialesNuevas.vue'

// AC: las credenciales de un alta se muestran UNA vez. El admin tiene que poder pasarlas —a mano
// o copiándolas— antes de cerrar, porque después no se recuperan.
describe('Credenciales de un alta', () => {
  const datos = { nombre: 'Ana Díaz', email: 'ana.diaz@mi-organizacion.paciente', password_inicial: 'frut-mesa-4728' }

  function montar(props) {
    setActivePinia(createPinia())
    return mount(CredencialesNuevas, { props, attachTo: document.body })
  }

  it('sin datos no muestra nada: no es un modal que se abre solo', () => {
    const w = montar({ datos: null })

    expect(document.body.textContent).not.toContain('ya puede entrar')
    w.unmount()
  })

  it('muestra el usuario y la contraseña, que es lo único que hay que pasar', () => {
    const w = montar({ datos })

    expect(document.body.textContent).toContain('ana.diaz@mi-organizacion.paciente')
    expect(document.body.textContent).toContain('frut-mesa-4728')
    expect(document.body.textContent).toContain('Ana Díaz ya puede entrar')
    w.unmount()
  })

  it('copia las dos cosas juntas, no sólo la contraseña', async () => {
    const escrito = vi.fn().mockResolvedValue()
    Object.assign(navigator, { clipboard: { writeText: escrito } })
    const w = montar({ datos })

    // El contenido va en un `<Teleport to="body">`, así que no está en el árbol del wrapper.
    document.querySelector('.cred__btn').click()
    await Promise.resolve()

    expect(escrito).toHaveBeenCalledWith(expect.stringContaining('ana.diaz@mi-organizacion.paciente'))
    expect(escrito).toHaveBeenCalledWith(expect.stringContaining('frut-mesa-4728'))
    w.unmount()
  })

  it('avisa cuando el mail no salió, para que el admin sepa que las tiene que pasar él', () => {
    const w = montar({ datos: { ...datos, mail_enviado: false } })

    expect(document.body.textContent).toContain('no salió')
    w.unmount()
  })
})
