import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// Bug real (Germán): «aparece un instante una página clarita con un cartel, como que no tenía
// permisos». Era el panel «pedile un rol al administrador», que se dibujaba con el usuario ya
// borrado mientras la app se iba al login.
vi.mock('../stores/club', () => ({ useClubStore: () => ({ data: null }) }))

describe('Inicio sin usuario', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('no muestra «pedile un rol al administrador» mientras no hay usuario', async () => {
    const DashboardView = (await import('../views/DashboardView.vue')).default
    const w = shallowMount(DashboardView)

    expect(w.findComponent({ name: 'DefaultDashboard' }).exists()).toBe(false)
  })

  it('sí lo muestra a un usuario de verdad sin panel propio', async () => {
    const { useAuthStore } = await import('../stores/auth')
    useAuthStore().user = { id: 1, role: 'paciente', email: 'x@y.z' }
    const DashboardView = (await import('../views/DashboardView.vue')).default
    const w = shallowMount(DashboardView)

    expect(w.findComponent({ name: 'DefaultDashboard' }).exists()).toBe(true)
  })
})
