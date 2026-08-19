import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

const crearAcceso       = vi.fn(() => Promise.resolve({ data: { credenciales: { email: 'ana.diaz@org.paciente', password_inicial: 'frut-mesa-4728' } } }))
const restablecerAcceso = vi.fn(() => Promise.resolve({ data: { credenciales: { email: 'ana.diaz@org.paciente', password_inicial: 'nuev-clav-9182' } } }))
const confirmar = vi.fn(() => Promise.resolve(true))

vi.mock('../lib/api.js', () => ({
  crearAccesoPaciente:       (...a) => crearAcceso(...a),
  restablecerAccesoPaciente: (...a) => restablecerAcceso(...a),
}))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: confirmar }) }))
vi.mock('../composables/useToast', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))

const SocioTabPortal = (await import('../components/pacientes/SocioTabPortal.vue')).default

const montar = (acceso) => mount(SocioTabPortal, {
  props: { socioId: 7, nombre: 'Ana Díaz', acceso },
  global: { stubs: { CredencialesNuevas: true } },
  attachTo: document.body,
})

// AC: la cuenta del portal se ve y se gestiona desde la ficha. Antes la contraseña se mostraba
// una sola vez al dar el alta y no había NINGÚN lugar donde consultar siquiera el usuario.
describe('Acceso al portal, en la ficha del paciente', () => {
  beforeEach(() => { crearAcceso.mockClear(); restablecerAcceso.mockClear(); confirmar.mockClear() })

  it('muestra el usuario del que ya tiene cuenta', () => {
    const w = montar({ modulo: true, tiene: true, email: 'ana.diaz@org.paciente', activo: true, puede_gestionar: true })

    expect(w.text()).toContain('ana.diaz@org.paciente')
    expect(w.text()).toContain('Puede entrar')
  })

  it('avisa cuando el paciente está desactivado: la cuenta existe pero no entra', () => {
    const w = montar({ modulo: true, tiene: true, email: 'ana.diaz@org.paciente', activo: false, puede_gestionar: true })

    expect(w.text()).toContain('No puede entrar')
    expect(w.text()).toContain('desactivado')
  })

  it('al que no tiene cuenta le muestra qué usuario le quedaría, y deja crearla', async () => {
    const w = montar({ modulo: true, tiene: false, sugerido: 'ana.diaz@org.paciente', puede_gestionar: true })

    expect(w.text()).toContain('ana.diaz@org.paciente')
    await w.find('.stp__btn--primary').trigger('click')

    expect(crearAcceso).toHaveBeenCalledWith(7)
  })

  it('restablecer pregunta antes: la clave vieja deja de servir en el acto', async () => {
    const w = montar({ modulo: true, tiene: true, email: 'ana.diaz@org.paciente', activo: true, puede_gestionar: true })

    await w.find('.stp__btn').trigger('click')
    await Promise.resolve()

    expect(confirmar).toHaveBeenCalled()
    expect(restablecerAcceso).toHaveBeenCalledWith(7)
  })

  it('a quien no puede gestionarla no le ofrece un botón que rebota', () => {
    const w = montar({ modulo: true, tiene: false, sugerido: 'ana.diaz@org.paciente', puede_gestionar: false })

    expect(w.findAll('.stp__btn')).toHaveLength(0)
    expect(w.text()).toContain('Sólo un administrador o el médico')
  })
})
