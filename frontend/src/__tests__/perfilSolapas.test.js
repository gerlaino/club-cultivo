import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { reactive } from 'vue'

// AC (Germán, 25-sep-2026): «la página de perfil debería ser con solapas: Datos personales,
// Notificaciones, Seguridad». Acordado: la foto con nombre y rol queda fija al costado, la tarjeta
// «Cuenta» (IDs internos) se va, la solapa vive en la URL y «Notificaciones» aparece sólo si la
// persona tiene avisos para elegir.
const api = vi.hoisted(() => ({ getMisNotificaciones: vi.fn() }))
vi.mock('../lib/api', () => ({
  getProfile: vi.fn(() => Promise.resolve({ data: { data: { id: 7, club_id: 3, role: 'admin', first_name: 'Germán', last_name: 'L', email: 'admin@x.com' } } })),
  updateProfile: vi.fn(), updateMyPassword: vi.fn(), uploadAvatar: vi.fn(), updateMisNotificaciones: vi.fn(),
  getMisNotificaciones: (...a) => api.getMisNotificaciones(...a),
}))
const ruta = vi.hoisted(() => ({ route: null, replace: vi.fn() }))
vi.mock('vue-router', () => ({ useRoute: () => ruta.route, useRouter: () => ({ replace: ruta.replace }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }) }))
vi.mock('../composables/usePushNotifications.js', () => ({
  MOTIVOS: {},
  usePushNotifications: () => ({ disponible: { value: false }, iosSinInstalar: { value: false }, subscribed: { value: false },
    loading: { value: false }, denied: { value: false }, subscribe: vi.fn(), unsubscribe: vi.fn() }),
}))

const NOTIF = { tipos: [{ clave: 'reponer_insumos', grupo: 'Cultivo', label: 'Reponer', desc: '', activo: true }], grupos: {},
                no_molestar: false, no_molestar_desde: '22:00', no_molestar_hasta: '08:00' }

async function montar({ solapa, notif = NOTIF } = {}) {
  ruta.route = reactive({ query: solapa ? { solapa } : {} })
  ruta.replace.mockReset()
  api.getMisNotificaciones.mockResolvedValue({ data: notif })
  setActivePinia(createPinia())
  const V = (await import('../views/PerfilView.vue')).default
  const w = mount(V, { global: { stubs: { AppDatePicker: true } } })
  await flushPromises()
  return w
}
// El nombre completo (en el teléfono se ve el corto: «Datos»).
const tabs = w => w.findAll('.pfl__tab-largo').map(t => t.text())

describe('Perfil con solapas', () => {
  beforeEach(() => vi.clearAllMocks())

  it('tiene Datos personales, Notificaciones y Seguridad, y arranca en Datos personales', async () => {
    const w = await montar()

    expect(tabs(w)).toEqual(['Datos personales', 'Notificaciones', 'Seguridad'])
    expect(w.find('.pfl__tab--on .pfl__tab-largo').text()).toBe('Datos personales')
    expect(w.text()).toContain('Usuario de ingreso')
    expect(w.text()).not.toContain('Contraseña actual')
  })

  it('la solapa sale de la URL: ?solapa=seguridad abre la contraseña', async () => {
    const w = await montar({ solapa: 'seguridad' })

    expect(w.text()).toContain('Contraseña actual')
    expect(w.text()).not.toContain('Usuario de ingreso')
  })

  it('tocar una solapa la anota en la URL', async () => {
    const w = await montar()

    await w.findAll('.pfl__tab')[1].trigger('click')

    expect(ruta.replace).toHaveBeenCalledWith({ query: { solapa: 'notificaciones' } })
  })

  it('sin avisos para elegir no hay solapa Notificaciones, y pedirla cae en Datos personales', async () => {
    const w = await montar({ solapa: 'notificaciones', notif: null })

    expect(tabs(w)).toEqual(['Datos personales', 'Seguridad'])
    expect(w.find('.pfl__tab--on .pfl__tab-largo').text()).toBe('Datos personales')
  })

  it('la foto, el nombre y el rol quedan fijos; la tarjeta «Cuenta» con IDs internos no está', async () => {
    const w = await montar({ solapa: 'seguridad' })

    expect(w.find('.pfl__avatar-card').text()).toContain('Germán')
    expect(w.text()).not.toContain('ID de organización')
    expect(w.text()).not.toContain('ID usuario')
  })
})
