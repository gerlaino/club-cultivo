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

  it('«Copiar todo» lleva las dos cosas juntas, para mandarlas', async () => {
    const escrito = vi.fn().mockResolvedValue()
    Object.assign(navigator, { clipboard: { writeText: escrito } })
    const w = montar({ datos })

    // El contenido va en un `<Teleport to="body">`, así que no está en el árbol del wrapper.
    document.querySelector('[data-testid="cred-copiar-todo"]').click()
    await Promise.resolve()

    expect(escrito).toHaveBeenCalledWith(expect.stringContaining('ana.diaz@mi-organizacion.paciente'))
    expect(escrito).toHaveBeenCalledWith(expect.stringContaining('frut-mesa-4728'))
    w.unmount()
  })

  // AC (Javi y Germán, 15-oct-2026): «regenerar contraseña desde Equipo no loguea… al copiar se
  // copian los guiones como si fueran espacios en blanco».
  describe('la contraseña se puede pegar tal cual en el login', () => {
    const generada = { nombre: 'Leo', email: 'leo@org.com', password_inicial: 'abcdEFGH2345' }

    it('«Copiar contraseña» copia SÓLO la contraseña, sin espacios ni guiones', async () => {
      const escrito = vi.fn().mockResolvedValue()
      Object.assign(navigator, { clipboard: { writeText: escrito } })
      const w = montar({ datos: generada })

      document.querySelector('[aria-label="Copiar contraseña"]').click()
      await Promise.resolve()

      expect(escrito).toHaveBeenCalledWith('abcdEFGH2345')
      w.unmount()
    })

    it('«Copiar usuario» copia SÓLO el usuario', async () => {
      const escrito = vi.fn().mockResolvedValue()
      Object.assign(navigator, { clipboard: { writeText: escrito } })
      const w = montar({ datos: generada })

      document.querySelector('[aria-label="Copiar usuario"]').click()
      await Promise.resolve()

      expect(escrito).toHaveBeenCalledWith('leo@org.com')
      w.unmount()
    })

    it('se muestra de corrido: seleccionarla a mano no agrega nada', () => {
      const w = montar({ datos: generada })
      const pw = document.querySelector('[data-testid="cred-password"]')

      expect(pw.textContent).toBe('abcdEFGH2345')
      expect(pw.children.length).toBe(0)
      w.unmount()
    })
  })

  it('avisa cuando el mail no salió, para que el admin sepa que las tiene que pasar él', () => {
    const w = montar({ datos: { ...datos, mail_enviado: false } })

    expect(document.body.textContent).toContain('no salió')
    w.unmount()
  })
})
