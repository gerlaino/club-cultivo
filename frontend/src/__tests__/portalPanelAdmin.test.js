import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// «ARMÁ TU PORTAL» (Germán, 28-oct-2026: «el portal no queda abierto cuando clickeo el toggle;
// tiene que ser mucho más fácil e intuitivo, pensá que no es alguien de sistemas»).
//
// AC:
// - El interruptor del portal se guarda AL TOCARLO (no hay un «Guardar» al pie) y lo confirma; si
//   falla, lo dice. Cerrarlo pide confirmación.
// - Mientras falte algo, muestra los pasos con lo que lleva hecho; con todo listo, no.
// - Reservar y Mensajes se prenden y apagan por separado, al tocarlos.
// - Invitar / recordar manda a los que el backend dice (con mail), con confirmación.
// - Lo que espera respuesta (pedidos, mensajes, renovaciones) lleva a resolverlo.

const api = vi.hoisted(() => ({
  get: vi.fn(), updatePreferences: vi.fn(), invitarPortalLote: vi.fn(),
}))
vi.mock('@/lib/api', () => ({ default: { get: api.get }, updatePreferences: api.updatePreferences, invitarPortalLote: api.invitarPortalLote }))
const toast = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn(), info: vi.fn(), warning: vi.fn() }))
vi.mock('@/composables/useToast', () => ({ useToast: () => toast }))
const confirm = vi.hoisted(() => vi.fn(() => Promise.resolve(true)))
vi.mock('@/composables/useConfirm', () => ({ useConfirm: () => ({ confirm }) }))
vi.mock('@/composables/useRecargaEnCambios', () => ({ useRecargaEnCambios: () => {} }))

const PANEL = (cambios = {}) => ({
  contratado: true, abierto: false, reservar: true, mensajes: true,
  pasos: { abierto: false, presentacion: false, contenido: false, invitados: false },
  para_atender: {
    pedidos: { total: 0, items: [] }, mensajes: { total: 0, items: [] }, renovaciones: { total: 0, items: [] },
  },
  pacientes: { total: 10, entran: 0, invitados_sin_entrar: 2, sin_invitar: 8, sin_mail: 3, ids_recordar: [4, 5], ids_invitar: [1, 2, 3] },
  publicado: { geneticas: 0, noticias: 0, eventos: 0 },
  link_entrada: 'https://x/paciente',
  ...cambios,
})

async function montar(panel = PANEL()) {
  api.get.mockResolvedValue({ data: panel })
  const { default: V } = await import('../components/portal/PortalPanelAdmin.vue')
  const w = mount(V, { global: { stubs: { RouterLink: { props: ['to'], template: '<a :href="typeof to === \'string\' ? to : \'\'"><slot /></a>' } } } })
  await flushPromises()
  return w
}

beforeEach(() => {
  vi.clearAllMocks()
  setActivePinia(createPinia())
  api.updatePreferences.mockResolvedValue({ data: {} })
  api.invitarPortalLote.mockResolvedValue({ data: { data: { enviados: 3, omitidos: [] } } })
})

describe('El portal del lado del admin', () => {
  it('abrir el portal se guarda al tocar el interruptor y lo confirma', async () => {
    const w = await montar()
    await w.find('[data-testid="portal-abrir"]').trigger('click'); await flushPromises()

    expect(api.updatePreferences).toHaveBeenCalledWith({ vista_paciente_activa: true })
    expect(toast.success).toHaveBeenCalledWith(expect.stringContaining('Portal abierto'))
    expect(api.get).toHaveBeenCalledTimes(2) // y vuelve a pedir el estado
  })

  it('cerrarlo pide confirmación; si no confirma, no se toca nada', async () => {
    confirm.mockResolvedValueOnce(false)
    const w = await montar(PANEL({ abierto: true, pasos: { abierto: true, presentacion: true, contenido: true, invitados: true } }))
    await w.find('[data-testid="portal-abrir"]').trigger('click'); await flushPromises()

    expect(confirm).toHaveBeenCalled()
    expect(api.updatePreferences).not.toHaveBeenCalled()
  })

  it('si el guardado falla, lo dice', async () => {
    api.updatePreferences.mockRejectedValueOnce({ response: { data: { errors: ['Algo salió mal'] } } })
    const w = await montar()
    await w.find('[data-testid="portal-abrir"]').trigger('click'); await flushPromises()

    expect(toast.error).toHaveBeenCalledWith('Algo salió mal')
  })

  it('mientras falte algo muestra los pasos, con lo que lleva hecho', async () => {
    const w = await montar(PANEL({ abierto: true, pasos: { abierto: true, presentacion: true, contenido: false, invitados: false } }))
    const pasos = w.find('[data-testid="portal-pasos"]')
    expect(pasos.exists()).toBe(true)
    expect(pasos.text()).toContain('2 de 4 listos')
  })

  it('con todo listo no muestra los pasos', async () => {
    const w = await montar(PANEL({ abierto: true, pasos: { abierto: true, presentacion: true, contenido: true, invitados: true } }))
    expect(w.find('[data-testid="portal-pasos"]').exists()).toBe(false)
  })

  it('apagar Reservar se guarda al tocarlo', async () => {
    const w = await montar(PANEL({ abierto: true }))
    await w.find('[data-testid="portal-reservar"]').trigger('click'); await flushPromises()
    expect(api.updatePreferences).toHaveBeenCalledWith({ portal_reservar_activo: false })
  })

  it('apagar Mensajes se guarda al tocarlo', async () => {
    const w = await montar(PANEL({ abierto: true }))
    await w.find('[data-testid="portal-mensajes"]').trigger('click'); await flushPromises()
    expect(api.updatePreferences).toHaveBeenCalledWith({ portal_mensajes_activo: false })
  })

  it('invitar manda a los que tienen mail y no fueron invitados, con confirmación', async () => {
    const w = await montar(PANEL({ abierto: true }))
    await w.find('[data-testid="portal-invitar"]').trigger('click'); await flushPromises()

    expect(confirm).toHaveBeenCalled()
    expect(api.invitarPortalLote).toHaveBeenCalledWith([1, 2, 3])
    expect(toast.success).toHaveBeenCalledWith(expect.stringContaining('3 mails'))
  })

  it('recordarles manda a los invitados que no entraron', async () => {
    const w = await montar(PANEL({ abierto: true }))
    await w.find('[data-testid="portal-recordar"]').trigger('click'); await flushPromises()
    expect(api.invitarPortalLote).toHaveBeenCalledWith([4, 5])
  })

  it('con el portal cerrado no deja invitar', async () => {
    const w = await montar()
    expect(w.find('[data-testid="portal-invitar"]').attributes('disabled')).toBeDefined()
  })

  it('lo que espera respuesta lleva a resolverlo', async () => {
    const w = await montar(PANEL({
      abierto: true, pasos: { abierto: true, presentacion: true, contenido: true, invitados: true },
      para_atender: {
        pedidos: { total: 1, items: [{ id: 9, paciente: 'Lucía', fecha: '2026-10-29', detalle: 'Northern Lights 10 g', sede: 'Centro' }] },
        mensajes: { total: 1, items: [{ paciente_id: 5, paciente: 'Diego', at: new Date().toISOString() }] },
        renovaciones: { total: 0, items: [] },
      },
    }))
    const atender = w.find('[data-testid="portal-atender"]')
    expect(atender.text()).toContain('Lucía')
    expect(atender.text()).toContain('Northern Lights 10 g')
    expect(atender.find('a[href="/reservas?estado=solicitada"]').exists()).toBe(true)
    expect(atender.find('a[href="/pacientes/5?tab=chat"]').exists()).toBe(true)
  })

  it('con Reservar apagado no muestra pedidos para confirmar', async () => {
    const w = await montar(PANEL({ abierto: true, reservar: false, pasos: { abierto: true, presentacion: true, contenido: true, invitados: true } }))
    expect(w.find('[data-testid="portal-atender"]').text()).not.toContain('Pedidos para confirmar')
  })
})
