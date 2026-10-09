import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (9-oct-2026, Germán): decíamos «no permitimos menores» sin pedir nada aparte. La edad es una
// declaración propia, separada de los términos: sin ella no se puede crear la cuenta, y viaja en
// el pedido para que el backend la exija y la registre.
const registrarPersonal = vi.fn(() => Promise.resolve({ data: { ok: true } }))
vi.mock('../lib/api.js', () => ({
  getRegistroInfo: () => Promise.resolve({ data: { password_minimo: 8, dias_prueba: 30 } }),
  registrarPersonal: (...a) => registrarPersonal(...a),
}))
vi.mock('../lib/fuentesHerbario.js', () => ({ cargarFuentesHerbario: () => {} }))
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ login: () => Promise.resolve() }) }))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn(), back: vi.fn(), replace: vi.fn() }) }))

import RegistroView from '../views/RegistroView.vue'

async function montar() {
  const w = mount(RegistroView, { global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } } })
  await flushPromises()
  await w.find('#rg-nombre').setValue('Juana Pérez')
  await w.find('#rg-email').setValue('juana@ejemplo.com')
  await w.find('#rg-pass').setValue('clave-larga-1')
  return w
}
const tildes = (w) => w.findAll('.rg__check input[type="checkbox"]')
const boton = (w) => w.find('button[type="submit"]')

describe('Registro: mayor de 18', () => {
  it('hay un tilde propio para la edad, aparte del de los términos', async () => {
    const w = await montar()
    expect(tildes(w)).toHaveLength(2)
    expect(w.findAll('.rg__check')[0].text()).toContain('mayor de 18 años')
    expect(w.findAll('.rg__check')[1].text()).not.toContain('mayor de 18')
  })

  it('con sólo los términos aceptados no se puede crear', async () => {
    const w = await montar()
    await tildes(w)[1].setValue(true)
    expect(boton(w).attributes('disabled')).toBeDefined()
  })

  it('con las dos declaraciones se crea, y el pedido lleva la de la edad', async () => {
    const w = await montar()
    await tildes(w)[0].setValue(true)
    await tildes(w)[1].setValue(true)
    expect(boton(w).attributes('disabled')).toBeUndefined()
    await w.find('form').trigger('submit')
    await vi.waitFor(() =>
      expect(registrarPersonal).toHaveBeenCalledWith(expect.objectContaining({ mayor_de_edad: true, acepta_terminos: true })))
  })
})
