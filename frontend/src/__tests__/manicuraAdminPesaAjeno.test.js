import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 27-oct-2026): admin y supervisor pesan aunque el lote esté asignado a otra manicura;
// lo que ella ya pesó queda en su jornada; el admin puede «mandar a confirmar» la jornada abierta
// de ella. La pantalla ofrece lo que el backend acepta (`Lote#pesa_manicura?`).

const api = {
  listPesajesManicuraAdmin: vi.fn(), confirmarPesajeManicura: vi.fn(), reabrirPesajeManicura: vi.fn(),
  enviarPesajeManicura: vi.fn(() => Promise.resolve({ data: {} })), deletePesajeManicura: vi.fn(),
  revisarPesajeManicura: vi.fn(), soltarRevisionPesajeManicura: vi.fn(),
  listStocks: vi.fn(() => Promise.resolve({ data: [] })), listSedes: vi.fn(() => Promise.resolve({ data: [] })), listLotes: vi.fn(),
  createPesajeManicura: vi.fn(), registrarDirectoManicura: vi.fn(() => Promise.resolve({ data: {} })), listPlants: vi.fn(),
}
vi.mock('../lib/api.js', () => api)
vi.mock('../lib/api', () => api)
const toast = { success: vi.fn(), error: vi.fn(), info: vi.fn(), warning: vi.fn() }
vi.mock('../composables/useToast.js', () => ({ useToast: () => toast }))
const confirm = vi.fn(() => Promise.resolve(true))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm }) }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: () => {} }))
const registrarConJornada = vi.fn((_lote, fn) => fn({}))
vi.mock('../composables/useManicuraJornada', () => ({ useManicuraJornada: () => ({ registrarConJornada }) }))

// El store se importa recién al usarlo: importado arriba, arrastra `lib/api.js` antes del mock.
async function comoRol(role) {
  const { useAuthStore } = await import('../stores/auth')
  useAuthStore().user = { id: 1, role }
}

const ELLA = 20
const LOTE = { id: 5, codigo: 'L-26-010', estado: 'en_manicura', manicurador_id: ELLA, manicurador: { id: ELLA, nombre: 'Ana' }, plants_count: 3 }

beforeEach(() => { vi.clearAllMocks(); setActivePinia(createPinia()) })

describe('Completar manicura en un lote asignado a otra manicura', () => {
  async function montar(rol) {
    await comoRol(rol)
    api.listPlants.mockResolvedValue({ data: [{ id: 1, nombre: 'P1', state: 'secado', peso_seco: null, tiene_pesada: false }] })
    const { default: M } = await import('../components/lotes/CompletarManicuraModal.vue')
    const w = mount(M, { props: { modelValue: false, lote: LOTE },
      global: { stubs: { Teleport: true, DsSpinner: true }, directives: { modal: {} } } })
    await w.setProps({ modelValue: true }); await flushPromises()
    await w.find('input[type="number"]').setValue(30)
    return w
  }

  for (const rol of ['admin', 'supervisor']) {
    it(`como ${rol}: registra directo (queda confirmado), no lo manda a la cola`, async () => {
      const w = await montar(rol)
      const boton = w.findAll('button').filter(b => !b.attributes('disabled')).at(-1)
      await boton.trigger('click'); await flushPromises()
      expect(api.registrarDirectoManicura).toHaveBeenCalledWith(5, { resto: { plant_ids: [1], peso_total_g: 30 } })
      expect(api.createPesajeManicura).not.toHaveBeenCalled()
    })
  }
})

describe('Pesajes de manicura (admin): lotes asignados a una manicura', () => {
  const ABIERTA = { id: 9, lote_id: 5, manicurador_id: ELLA, manicurador_nombre: 'Ana', estado: 'borrador', plantas_registradas: 2, peso_calculado_g: 60 }

  async function montar(abiertas = [ABIERTA]) {
    await comoRol('admin')
    api.listPesajesManicuraAdmin.mockImplementation((params = {}) => Promise.resolve({ data: params.abiertas ? abiertas : [] }))
    api.listLotes.mockResolvedValue({ data: [LOTE] })
    const { default: V } = await import('../views/admin/AdminPesajesManicuraView.vue')
    const w = mount(V, { global: { stubs: { RouterLink: true, Teleport: true, CompletarManicuraModal: true, RepartoFrascos: true }, directives: { modal: {} } } })
    await flushPromises()
    return w
  }

  it('ofrece «Pesar» y muestra cuánto lleva la jornada abierta de ella', async () => {
    const w = await montar()
    expect(w.text()).toContain('Jornada abierta de Ana: 2 plantas · 60 g')
    expect(w.findAll('button').some(b => b.text().includes('Pesar'))).toBe(true)
  })

  it('«Mandar a confirmar» envía la jornada de ella y recarga', async () => {
    const w = await montar()
    const boton = w.findAll('button').find(b => b.text().includes('Mandar a confirmar'))
    await boton.trigger('click'); await flushPromises()
    expect(confirm).toHaveBeenCalled()
    expect(api.enviarPesajeManicura).toHaveBeenCalledWith(5, 9)
    expect(api.listPesajesManicuraAdmin).toHaveBeenCalledTimes(4) // carga inicial + recarga, con y sin abiertas
  })

  it('sin plantas en la jornada abierta no ofrece mandarla', async () => {
    const w = await montar([{ ...ABIERTA, plantas_registradas: 0 }])
    expect(w.findAll('button').some(b => b.text().includes('Mandar a confirmar'))).toBe(false)
  })
})
