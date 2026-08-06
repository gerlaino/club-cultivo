import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const updatePaciente = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({
  updatePaciente: (...a) => updatePaciente(...a),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}))

const fetchOne = vi.fn()
vi.mock('../stores/pacientes', () => ({
  usePacientesStore: () => ({
    current: { id: 1, nombre: 'Ana', apellido: 'Gómez', domicilio_calle: 'Falsa' },
    fetchOne,
  }),
}))
vi.mock('../stores/auth.js', () => ({
  useAuthStore: () => ({ user: { role: 'admin' } }),
}))

const SocioEditarModal = (await import('../components/pacientes/SocioEditarModal.vue')).default

// AC: es el MISMO modal en la ficha del paciente y en la lista. Desde la lista el id cambia
// según a quién se edite, y el composable lo capturaba por valor: los cambios se guardaban
// en el paciente que se había editado primero.
describe('SocioEditarModal reusado desde la lista', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    updatePaciente.mockClear()
    fetchOne.mockClear()
    document.body.innerHTML = ''
  })

  const montar = (socioId) => mount(SocioEditarModal, {
    props: { open: true, socioId },
    global: { stubs: { DsSpinner: true, AppDatePicker: true } },
    attachTo: document.body,
  })

  it('carga el paciente que le piden si no es el que está en el store', async () => {
    montar(7)
    await new Promise(r => setTimeout(r, 0))

    expect(fetchOne).toHaveBeenCalledWith(7)
  })

  it('no vuelve a pedirlo si ya es el paciente actual', async () => {
    montar(1)
    await new Promise(r => setTimeout(r, 0))

    expect(fetchOne).not.toHaveBeenCalled()
  })

  it('guarda contra el paciente que se está editando, no contra el primero', async () => {
    const wrapper = montar(1)
    await new Promise(r => setTimeout(r, 0))

    await wrapper.setProps({ socioId: 42 })
    await new Promise(r => setTimeout(r, 0))

    // El modal se teletransporta a <body>: hay que buscar el botón ahí, no en el wrapper.
    const guardar = [...document.body.querySelectorAll('button')]
      .find(b => b.textContent.includes('Guardar'))
    guardar.click()
    await new Promise(r => setTimeout(r, 0))

    expect(updatePaciente.mock.calls[0][0]).toBe(42)
  })
})
