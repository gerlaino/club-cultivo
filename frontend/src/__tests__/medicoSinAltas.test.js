import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { usePermissions } from '../composables/usePermissions.js'
import { useAuthStore } from '../stores/auth'

// AC (Germán y Javi, 15-oct-2026): «el médico ahora puede [crear pacientes], pero quiero que no
// pueda, el alta lo da admin». La pantalla no ofrece lo que el backend rechaza.
vi.mock('../lib/api.js', () => ({
  getMedicoPacientes: vi.fn(() => Promise.resolve({ data: { data: [], meta: { total: 0 } } })),
}))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))

describe('el médico no da altas de pacientes', () => {
  it('«Mis pacientes» no tiene «Nuevo paciente» y explica quién los da de alta', async () => {
    setActivePinia(createPinia())
    const V = (await import('../views/medico/MedicoPacientesView.vue')).default
    const w = mount(V, { global: { stubs: { teleport: true }, directives: { modal: {} } } })
    await flushPromises()

    expect(w.text()).not.toMatch(/nuevo paciente|agregar primer paciente/i)
    expect(w.text()).toContain('Los da de alta y te los vincula administración')
  })

  it('el permiso de crear pacientes no está en el rol médico', () => {
    setActivePinia(createPinia())
    useAuthStore().user = { id: 1, role: 'medico' }
    const { can } = usePermissions()
    expect(can('socios', 'create')).toBe(false)
    expect(can('socios', 'show')).toBe(true)
  })

  // AC (Germán, 15-oct-2026): «ni altas ni bajas ni editar, nada, sólo se ocupa de la salud».
  it('tampoco elimina ni edita los datos personales', async () => {
    setActivePinia(createPinia())
    useAuthStore().user = { id: 1, role: 'medico' }
    const { can } = usePermissions()
    expect(can('socios', 'destroy')).toBe(false)
    expect(can('socios', 'update')).toBe(false)

    const { getMedicoPacientes } = await import('../lib/api.js')
    getMedicoPacientes.mockResolvedValueOnce({ data: { data: [
      { id: 7, nombre: 'Ana', apellido: 'Díaz', dni: '30111222', es_paciente: true },
    ], meta: { total: 1, kpis: {} } } })
    const V = (await import('../views/medico/MedicoPacientesView.vue')).default
    const w = mount(V, { global: { stubs: { teleport: true, RouterLink: { template: '<a><slot /></a>' } }, directives: { modal: {} } } })
    await flushPromises()
    expect(w.text()).toContain('Díaz')
    expect(w.find('[title="Eliminar paciente"]').exists()).toBe(false)
  })
})
