import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 28-oct-2026): el catálogo ES «Reservar». El paciente elige la sede y si retira hoy o
// mañana (los días los manda el backend), pide de lo que ve, y el pedido espera que admin o
// supervisor lo confirme. Una reserva por día; el rechazo trae el motivo; el dispensador no
// confirma; sin el portal contratado, administración no ve nada de esto.

const portal = {
  getPortalCatalogo: vi.fn(), getPortalReservas: vi.fn(), getPortalDispensa: vi.fn(),
  pedirPortalReserva: vi.fn(() => Promise.resolve({})), cancelarPortalReserva: vi.fn(() => Promise.resolve({})),
}
vi.mock('@/lib/portalApi', () => portal)
const api = {
  listReservas: vi.fn(), confirmarReserva: vi.fn(() => Promise.resolve({})), rechazarReserva: vi.fn(() => Promise.resolve({})),
  cancelarReserva: vi.fn(), anularSenaReserva: vi.fn(), deleteReserva: vi.fn(),
}
vi.mock('../lib/api.js', () => api)
const toast = { success: vi.fn(), error: vi.fn(), info: vi.fn(), warning: vi.fn() }
vi.mock('@/composables/useToast', () => ({ useToast: () => toast }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => toast }))
const confirm = vi.fn(() => Promise.resolve(true))
vi.mock('@/composables/useConfirm', () => ({ useConfirm: () => ({ confirm }) }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm }) }))
vi.mock('@/composables/useRecargaEnCambios', () => ({ useRecargaEnCambios: () => {} }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: () => {} }))
const ruta = { query: {} }
const routerReplace = vi.fn()
vi.mock('vue-router', () => ({ useRoute: () => ruta, useRouter: () => ({ replace: routerReplace }), RouterLink: { template: '<a><slot /></a>' } }))

const SEDES = [
  { sede_id: 1, sede: 'Centro', productos: [
    { stock_id: 10, nombre: 'Northern Lights', forma: 'Flor seca', unidad: 'g', precio: 1000, disponibilidad: 'hay' },
    { stock_id: 11, nombre: 'Gelato', forma: 'Flor seca', unidad: 'g', precio: 1200, disponibilidad: 'no_hay' },
  ] },
  { sede_id: 2, sede: 'Norte', productos: [
    { stock_id: 20, nombre: 'OG Kush', forma: 'Flor seca', unidad: 'g', precio: 900, disponibilidad: 'pocos' },
  ] },
]
const dias = (hoy = true, manana = true) => [{ fecha: '2026-10-28', etiqueta: 'Hoy', libre: hoy }, { fecha: '2026-10-29', etiqueta: 'Mañana', libre: manana }]

beforeEach(() => { vi.clearAllMocks(); setActivePinia(createPinia()); ruta.query = {} })

describe('Reservar (portal del paciente)', () => {
  async function montar({ fechas = dias(), pedidos = [] } = {}) {
    portal.getPortalCatalogo.mockResolvedValue(SEDES)
    portal.getPortalReservas.mockResolvedValue({ data: pedidos, fechas_retiro: fechas })
    const { default: V } = await import('../views/portal/PortalCatalogoView.vue')
    const w = mount(V, { global: { stubs: { RouterLink: true, PortalCabecera: true, PortalVacio: true, DsSpinner: true } } })
    await flushPromises()
    return w
  }

  it('pide de la sede elegida, para el día elegido, con lo que cargó', async () => {
    const w = await montar()
    await w.find('[data-testid="cantidad"]').setValue('5')
    const manana = w.findAll('button').find(b => b.text() === 'Mañana')
    await manana.trigger('click')
    await w.find('[data-testid="pedir"]').trigger('click'); await flushPromises()

    expect(portal.pedirPortalReserva).toHaveBeenCalledWith({ sede_id: 1, fecha: '2026-10-29', notas: undefined, items: [{ stock_id: 10, cantidad: 5 }] })
    expect(toast.success).toHaveBeenCalled()
  })

  it('sólo ofrece los días que manda el backend (hoy y mañana)', async () => {
    const w = await montar()
    await w.find('[data-testid="cantidad"]').setValue('5')
    const dias = w.findAll('.pcv__retiro button').map(b => b.text())
    expect(dias).toEqual(['Hoy', 'Mañana'])
  })

  it('lo que no hay hoy no se puede pedir', async () => {
    const w = await montar()
    expect(w.findAll('[data-testid="cantidad"]')).toHaveLength(1) // Northern Lights sí, Gelato no
  })

  it('al cambiar de sede se empieza de cero: el pedido es de una sede', async () => {
    const w = await montar()
    await w.find('[data-testid="cantidad"]').setValue('5')
    expect(w.find('[data-testid="pedir"]').exists()).toBe(true)
    await w.findAll('button').find(b => b.text() === 'Norte').trigger('click')
    expect(w.find('[data-testid="pedir"]').exists()).toBe(false)
  })

  it('una por día: con hoy ocupado, ofrece sólo mañana y pide para mañana', async () => {
    const w = await montar({ fechas: dias(false, true), pedidos: [{ id: 3, estado: 'solicitada', fecha: '2026-10-28', sede: 'Centro', items: [], total_estimado: 0 }] })
    expect(w.text()).toContain('Esperando confirmación')
    await w.find('[data-testid="cantidad"]').setValue('5')
    const hoy = w.findAll('.pcv__retiro button').find(b => b.text() === 'Hoy')
    expect(hoy.attributes('disabled')).toBeDefined()
    await w.find('[data-testid="pedir"]').trigger('click'); await flushPromises()
    expect(portal.pedirPortalReserva).toHaveBeenCalledWith(expect.objectContaining({ fecha: '2026-10-29' }))
  })

  it('con hoy y mañana ocupados no deja pedir y lo dice', async () => {
    const w = await montar({ fechas: dias(false, false) })
    expect(w.find('[data-testid="sin-dias"]').exists()).toBe(true)
    expect(w.findAll('[data-testid="cantidad"]')).toHaveLength(0)
  })

  it('un pedido rechazado muestra el motivo', async () => {
    const w = await montar({ pedidos: [{ id: 4, estado: 'rechazada', motivo_rechazo: 'Hoy cerramos temprano', fecha: '2026-10-28', items: [] }] })
    expect(w.text()).toContain('No se pudo confirmar')
    expect(w.text()).toContain('Hoy cerramos temprano')
  })

  it('el error del backend se muestra tal cual (no dice cuánto hay)', async () => {
    portal.pedirPortalReserva.mockRejectedValueOnce({ response: { data: { error: 'Hoy no hay tanto de «Northern Lights»: pedí menos o consultá por el chat.' } } })
    const w = await montar()
    await w.find('[data-testid="cantidad"]').setValue('500')
    await w.find('[data-testid="pedir"]').trigger('click'); await flushPromises()
    expect(w.find('[role="alert"]').text()).toContain('Hoy no hay tanto')
  })

  it('los botones + y − cambian la cantidad de a uno', async () => {
    const w = await montar()
    await w.find('button[aria-label="Más Northern Lights"]').trigger('click')
    await w.find('button[aria-label="Más Northern Lights"]').trigger('click')
    await w.find('button[aria-label="Menos Northern Lights"]').trigger('click')
    await w.find('[data-testid="pedir"]').trigger('click'); await flushPromises()
    expect(portal.pedirPortalReserva).toHaveBeenCalledWith(expect.objectContaining({ items: [{ stock_id: 10, cantidad: 1 }] }))
  })

  it('«Volver a pedir lo mismo»: precarga lo de la dispensa en la sede donde está hoy', async () => {
    ruta.query = { repetir: '42' }
    portal.getPortalDispensa.mockResolvedValue({ items: [{ stock_id: 20, nombre: 'OG Kush', cantidad: 7, unidad: 'g' }] })
    const w = await montar()

    expect(portal.getPortalDispensa).toHaveBeenCalledWith('42')
    expect(w.find('[data-testid="repetir-aviso"]').text()).toContain('Cargamos lo mismo')
    await w.find('[data-testid="pedir"]').trigger('click'); await flushPromises()
    expect(portal.pedirPortalReserva).toHaveBeenCalledWith(expect.objectContaining({ sede_id: 2, items: [{ stock_id: 20, cantidad: 7 }] }))
  })

  it('«Volver a pedir»: si hoy no está, lo dice y no carga nada', async () => {
    ruta.query = { repetir: '42' }
    portal.getPortalDispensa.mockResolvedValue({ items: [{ stock_id: 11, nombre: 'Gelato', cantidad: 5, unidad: 'g' }] })
    const w = await montar()

    expect(w.find('[data-testid="repetir-aviso"]').text()).toContain('hoy no está')
    expect(w.find('[data-testid="pedir"]').exists()).toBe(false)
  })

  it('si la organización no atiende Reservar, muestra lo que hay pero no deja pedir', async () => {
    const { usePortalClubStore } = await import('../stores/portalClub')
    usePortalClubStore().club = { reservar: false }
    const w = await montar()
    expect(w.find('[data-testid="reservar-apagado"]').exists()).toBe(true)
    expect(w.findAll('[data-testid="cantidad"]')).toHaveLength(0)
    expect(w.text()).toContain('Northern Lights')
  })

  it('cancela el pedido que espera, con confirmación', async () => {
    const w = await montar({ pedidos: [{ id: 3, estado: 'solicitada', fecha: '2026-10-28', items: [] }] })
    await w.findAll('button').find(b => b.text().includes('Cancelar el pedido')).trigger('click'); await flushPromises()
    expect(confirm).toHaveBeenCalled()
    expect(portal.cancelarPortalReserva).toHaveBeenCalledWith(3)
  })
})

describe('Pedidos del portal (administración)', () => {
  const PEDIDO = { id: 7, estado: 'solicitada', origen: 'portal', fecha_entrega_estimada: '2026-10-28', paciente: { id: 1, nombre: 'Ana' },
    items: [{ id: 1, stock_id: 10, cantidad: 5, unidad: 'g', genetica: 'Northern Lights' }], stock: { sede: { id: 1, nombre: 'Centro' } } }

  async function montar(role, { portal = true } = {}) {
    const { useAuthStore } = await import('../stores/auth')
    const { useClubStore } = await import('../stores/club')
    useAuthStore().user = { id: 9, role }
    useClubStore().data = { features: { vista_paciente: portal } }
    api.listReservas.mockResolvedValue({ data: { reservas: [PEDIDO] } })
    const { default: V } = await import('../views/ReservasView.vue')
    const w = mount(V, { global: { stubs: { DsSpinner: true, ModalNuevaDispensacion: true, ModalEditarReserva: true } } })
    await flushPromises()
    return w
  }

  for (const role of ['admin', 'supervisor']) {
    it(`${role}: confirma el pedido`, async () => {
      const w = await montar(role)
      await w.findAll('button').find(b => b.text() === 'Confirmar').trigger('click'); await flushPromises()
      expect(api.confirmarReserva).toHaveBeenCalledWith(7)
    })
  }

  it('rechazar sin motivo no manda nada', async () => {
    confirm.mockResolvedValueOnce({ valor: '' })
    const w = await montar('admin')
    await w.findAll('button').find(b => b.text() === 'Rechazar').trigger('click'); await flushPromises()
    expect(api.rechazarReserva).not.toHaveBeenCalled()
  })

  it('rechazar con motivo lo manda', async () => {
    confirm.mockResolvedValueOnce({ valor: 'Pasá mañana' })
    const w = await montar('admin')
    await w.findAll('button').find(b => b.text() === 'Rechazar').trigger('click'); await flushPromises()
    expect(api.rechazarReserva).toHaveBeenCalledWith(7, 'Pasá mañana')
  })

  it('sin el portal contratado, administración no ve «Pedidos del portal»', async () => {
    const w = await montar('admin', { portal: false })
    expect(w.findAll('option').some(o => o.text().startsWith('Pedidos del portal'))).toBe(false)
  })

  it('el dispensador no tiene cómo confirmar', async () => {
    const w = await montar('dispensador')
    expect(w.findAll('button').some(b => b.text() === 'Confirmar')).toBe(false)
    expect(w.findAll('option').some(o => o.text().startsWith('Pedidos del portal'))).toBe(false)
  })
})
