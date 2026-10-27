import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// LA PUERTA DEL PACIENTE (27-oct-2026).
//
// AC:
//   - Entra con DNI y clave. Si es paciente en más de una organización, recién DESPUÉS de validar
//     se le pregunta a cuál entra, y se vuelve a mandar con la elegida.
//   - «Me olvidé la clave» pide el DNI y muestra lo que contesta el backend (siempre lo mismo).
//   - El link de invitación muestra de qué organización es y a quién saluda; pide DNI y la clave
//     dos veces; si el link no sirve (venció, ya se usó), lo dice y lleva a entrar con el DNI.

const api = vi.hoisted(() => ({
  entrarPortal: vi.fn(), linkPortal: vi.fn(), activarPortal: vi.fn(), recuperarPortal: vi.fn(), me: vi.fn(),
}))
vi.mock('../lib/api', () => ({
  entrarPortal: (...a) => api.entrarPortal(...a),
  linkPortal: (...a) => api.linkPortal(...a),
  activarPortal: (...a) => api.activarPortal(...a),
  recuperarPortal: (...a) => api.recuperarPortal(...a),
  me: (...a) => api.me(...a),
  signIn: vi.fn(), signOut: vi.fn(), clearAuthToken: vi.fn(),
}))
vi.mock('../lib/cambiosStores.js', () => ({ engancharCambios: vi.fn(), soltarCambios: vi.fn() }))
vi.mock('../lib/fuentesHerbario.js', () => ({ cargarFuentesHerbario: () => {} }))
const router = vi.hoisted(() => ({ push: vi.fn(), replace: vi.fn() }))
let params = {}
vi.mock('vue-router', () => ({ useRoute: () => ({ params, query: {} }), useRouter: () => router }))
vi.mock('../router', () => ({ default: router }))

const stubs = { RouterLink: { props: ['to'], template: '<a :data-to="to"><slot /></a>' }, DsSpinner: true }

beforeEach(() => {
  setActivePinia(createPinia())
  Object.values(api).forEach((f) => f.mockReset())
  router.push.mockClear()
})

async function llenar(w, selector, valor) {
  await w.find(selector).setValue(valor)
}

describe('Entrar con DNI', () => {
  const montar = async () => mount((await import('../views/portal/PortalEntrarView.vue')).default, { global: { stubs } })

  it('con DNI y clave entra y va a su portal', async () => {
    api.entrarPortal.mockResolvedValue({ data: { id: 5, role: 'paciente' } })
    api.me.mockResolvedValue({ data: { id: 5, role: 'paciente', club_id: 2 } })
    const w = await montar()

    await llenar(w, '#pe-dni', '30111222')
    await llenar(w, '#pe-clave', 'clave-larga')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(api.entrarPortal).toHaveBeenCalledWith('30111222', 'clave-larga', null)
    expect(router.push).toHaveBeenCalledWith('/portal')
  })

  it('si es paciente en dos, pregunta a cuál y entra con la elegida', async () => {
    api.entrarPortal
      .mockResolvedValueOnce({ data: { elegir: [{ id: 1, nombre: 'Raíces' }, { id: 2, nombre: 'Mundo Verde' }] } })
      .mockResolvedValueOnce({ data: { id: 9, role: 'paciente' } })
    api.me.mockResolvedValue({ data: { id: 9, role: 'paciente', club_id: 2 } })
    const w = await montar()

    await llenar(w, '#pe-dni', '30111222')
    await llenar(w, '#pe-clave', 'clave-larga')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(w.text()).toContain('¿A cuál entrás?')
    const orgs = w.findAll('.pe__org')
    expect(orgs.map((b) => b.text())).toEqual(expect.arrayContaining(['Raíces', 'Mundo Verde'].map((n) => expect.stringContaining(n))))

    await orgs[1].trigger('click')
    await flushPromises()

    expect(api.entrarPortal).toHaveBeenLastCalledWith('30111222', 'clave-larga', 2)
    expect(router.push).toHaveBeenCalledWith('/portal')
  })

  it('con la clave equivocada muestra lo que dice el backend y no entra', async () => {
    api.entrarPortal.mockRejectedValue({ response: { status: 401, data: { error: 'El DNI o la clave no son correctos.' } } })
    const w = await montar()

    await llenar(w, '#pe-dni', '30111222')
    await llenar(w, '#pe-clave', 'otra')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(w.find('.hb-error').text()).toBe('El DNI o la clave no son correctos.')
    expect(router.push).not.toHaveBeenCalled()
  })

  it('«Me olvidé la clave» pide el DNI y muestra la respuesta', async () => {
    api.recuperarPortal.mockResolvedValue({ data: { mensaje: 'Si tu DNI está… te mandamos un link.' } })
    const w = await montar()

    await w.find('.pe__olvide').trigger('click')
    await llenar(w, '#pe-dni-rec', '30111222')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(api.recuperarPortal).toHaveBeenCalledWith('30111222')
    expect(w.text()).toContain('te mandamos un link')
  })
})

describe('El link de invitación', () => {
  const montar = async () => {
    const w = mount((await import('../views/portal/PortalActivarView.vue')).default, { global: { stubs } })
    await flushPromises()
    return w
  }

  beforeEach(() => { params = { token: 'tok123' } })

  it('saluda por el nombre, dice la organización y deja entrar con DNI y la clave elegida', async () => {
    api.linkPortal.mockResolvedValue({ data: { motivo: 'invitacion', nombre: 'Lucía', organizacion: { id: 2, nombre: 'Raíces' } } })
    api.activarPortal.mockResolvedValue({ data: { id: 5, role: 'paciente' } })
    api.me.mockResolvedValue({ data: { id: 5, role: 'paciente', club_id: 2 } })
    const w = await montar()

    expect(api.linkPortal).toHaveBeenCalledWith('tok123')
    expect(w.text()).toContain('Hola, Lucía')
    expect(w.text()).toContain('Raíces')

    await llenar(w, '#pa-dni', '30111222')
    await llenar(w, '#pa-clave', 'mi-clave-nueva')
    await llenar(w, '#pa-clave2', 'mi-clave-nueva')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(api.activarPortal).toHaveBeenCalledWith('tok123', '30111222', 'mi-clave-nueva', 'mi-clave-nueva')
    expect(router.push).toHaveBeenCalledWith('/portal')
  })

  it('si las dos claves no son iguales, lo dice y no manda nada', async () => {
    api.linkPortal.mockResolvedValue({ data: { motivo: 'invitacion', nombre: 'Lucía', organizacion: { id: 2, nombre: 'Raíces' } } })
    const w = await montar()

    await llenar(w, '#pa-dni', '30111222')
    await llenar(w, '#pa-clave', 'mi-clave-nueva')
    await llenar(w, '#pa-clave2', 'mi-clave-otra')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(w.find('.hb-error').text()).toContain('no son iguales')
    expect(api.activarPortal).not.toHaveBeenCalled()
  })

  it('el botón no se habilita con una clave de menos de 8', async () => {
    api.linkPortal.mockResolvedValue({ data: { motivo: 'invitacion', nombre: 'Lucía', organizacion: { id: 2, nombre: 'Raíces' } } })
    const w = await montar()

    await llenar(w, '#pa-dni', '30111222')
    await llenar(w, '#pa-clave', 'corta')
    await llenar(w, '#pa-clave2', 'corta')

    expect(w.find('button[type="submit"]').attributes('disabled')).toBeDefined()
  })

  it('un link que ya no sirve lo dice y lleva a entrar con el DNI', async () => {
    api.linkPortal.mockRejectedValue({ response: { status: 410, data: { error: 'Este link venció.', organizacion: { nombre: 'Raíces' } } } })
    const w = await montar()

    expect(w.text()).toContain('Este link no sirve')
    expect(w.text()).toContain('Este link venció.')
    expect(w.find('a[data-to="/paciente"]').exists()).toBe(true)
  })
})
