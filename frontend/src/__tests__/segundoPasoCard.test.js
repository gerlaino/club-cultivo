import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (29-oct-2026, seguridad tanda 2): el super admin activa el segundo paso desde Mi perfil →
// Seguridad: su clave, el QR (y la clave a mano), un código de la app. Ya activo, no se saca desde
// acá. El estado lo dice el backend.
const api = vi.hoisted(() => ({ getSegundoPaso: vi.fn(), iniciarSegundoPaso: vi.fn(), activarSegundoPaso: vi.fn() }))
vi.mock('../lib/api', () => ({
  getSegundoPaso: (...a) => api.getSegundoPaso(...a), iniciarSegundoPaso: (...a) => api.iniciarSegundoPaso(...a),
  activarSegundoPaso: (...a) => api.activarSegundoPaso(...a), me: vi.fn(() => Promise.resolve({ data: { id: 1, role: 'super_admin' } })),
}))
vi.mock('qrcode', () => ({ default: { toDataURL: vi.fn(() => Promise.resolve('data:image/png;base64,QR')) } }))

const Card = (await import('../components/perfil/SegundoPasoCard.vue')).default

describe('Segundo paso en Mi perfil', () => {
  beforeEach(() => { setActivePinia(createPinia()); vi.clearAllMocks() })

  const montar = async (estado) => {
    api.getSegundoPaso.mockResolvedValue({ data: estado })
    const w = mount(Card, { global: { stubs: { DsSpinner: true } } })
    await flushPromises()
    return w
  }

  it('sin activar y obligatorio: avisa que no puede seguir y pide la clave antes del QR', async () => {
    const w = await montar({ activo: false, obligatorio: true, disponible: true })

    expect(w.find('[data-testid="segundo-paso-estado"]').text()).toBe('Sin activar')
    expect(w.text()).toContain('hasta activarlo no podés seguir')
    expect(w.find('[data-testid="segundo-paso-empezar"]').attributes('disabled')).toBeDefined()
  })

  it('con la clave muestra el QR y la clave a mano; con el código lo activa', async () => {
    const w = await montar({ activo: false, obligatorio: true, disponible: true })
    api.iniciarSegundoPaso.mockResolvedValue({ data: { secreto: 'ABCDEF', uri: 'otpauth://totp/x?secret=ABCDEF' } })
    await w.find('[data-testid="segundo-paso-clave"]').setValue('MiClave1')
    await w.find('[data-testid="segundo-paso-empezar"]').trigger('click')
    await flushPromises()

    expect(api.iniciarSegundoPaso).toHaveBeenCalledWith('MiClave1')
    expect(w.find('img').attributes('src')).toBe('data:image/png;base64,QR')
    expect(w.find('[data-testid="segundo-paso-secreto"]').text()).toBe('ABCDEF')

    api.activarSegundoPaso.mockResolvedValue({ data: { activo: true, obligatorio: true, disponible: true } })
    await w.find('[data-testid="segundo-paso-codigo"]').setValue('123456')
    await w.find('[data-testid="segundo-paso-activar"]').trigger('click')
    await flushPromises()

    expect(api.activarSegundoPaso).toHaveBeenCalledWith('123456')
    expect(w.find('[data-testid="segundo-paso-estado"]').text()).toBe('Activo')
  })

  it('con la clave equivocada dice el motivo del servidor y no muestra QR', async () => {
    const w = await montar({ activo: false, obligatorio: true, disponible: true })
    api.iniciarSegundoPaso.mockRejectedValue({ response: { status: 422, data: { errors: ['La contraseña actual no es correcta.'] } } })
    await w.find('[data-testid="segundo-paso-clave"]').setValue('mal')
    await w.find('[data-testid="segundo-paso-empezar"]').trigger('click')
    await flushPromises()

    expect(w.text()).toContain('La contraseña actual no es correcta.')
    expect(w.find('img').exists()).toBe(false)
  })

  it('activo: lo dice y no ofrece sacarlo', async () => {
    const w = await montar({ activo: true, obligatorio: true, disponible: true })

    expect(w.find('[data-testid="segundo-paso-estado"]').text()).toBe('Activo')
    expect(w.find('button').exists()).toBe(false)
  })
})
