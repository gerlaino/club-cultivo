import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { useAuthStore } from '../stores/auth'

// AC (29-oct-2026, pedido de Javi; Germán: «obligatorio a partir de ahora, poder agregarlo al editar
// el stock»): la flor seca nueva —de una cosecha o externa— nace con su calidad (Altos, Medios,
// Bajos u Otro). Las opciones y si es obligatoria las manda el backend en /me (`reglas_stock`); en
// uso personal no se ofrecen. Al confirmar una cosecha a un frasco nuevo sin calidad, la pantalla
// lo dice y no manda nada; con calidad, la manda. Repartida, cada frasco nuevo lleva la suya.

const api = vi.hoisted(() => ({
  listPesajesManicuraAdmin: vi.fn(), confirmarPesajeManicura: vi.fn(), reabrirPesajeManicura: vi.fn(),
  revisarPesajeManicura: vi.fn(), soltarRevisionPesajeManicura: vi.fn(() => Promise.resolve({ data: {} })),
  listStocks: vi.fn(() => Promise.resolve({ data: [] })),
  default: { get: vi.fn(), post: vi.fn(), interceptors: { request: { use: vi.fn() }, response: { use: vi.fn() } } },
}))
vi.mock('../lib/api.js', () => api)
vi.mock('../lib/api', () => api)
const toast = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn(), info: vi.fn(), warning: vi.fn() }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => toast }))

const CALIDADES = { altos: 'Altos', medios: 'Medios', bajos: 'Bajos', otro: 'Otro' }
const PESAJE = { id: 9, lote_id: 5, lote_codigo: 'L-26-010', estado: 'enviado', peso_total_g: 30, peso_calculado_g: 30, plantas_count: 3, manicurador_nombre: 'Ana' }

function comoOrganizacion() {
  useAuthStore().user = { id: 1, role: 'admin', reglas_stock: { calidades: CALIDADES, calidad_obligatoria: true, formas_que_producen: ['flor_seca', 'otro'] } }
}

beforeEach(() => {
  vi.clearAllMocks(); setActivePinia(createPinia())
  api.revisarPesajeManicura.mockImplementation(() => Promise.resolve({ data: { ...PESAJE, enviado_at: 'v1', en_revision: true } }))
  api.listPesajesManicuraAdmin.mockResolvedValue({ data: [PESAJE] })
  api.confirmarPesajeManicura.mockResolvedValue({ data: {} })
})

async function montarAprobacion() {
  const { default: V } = await import('../views/mobile/MAdminAprobacionView.vue')
  const w = mount(V, { global: { stubs: { RouterLink: true, Teleport: true }, directives: { modal: {} } } })
  await flushPromises()
  await w.find('.maa__btn-aprobar').trigger('click'); await flushPromises()
  return w
}

describe('Confirmar una cosecha a un frasco nuevo', () => {
  it('sin calidad: lo dice y no confirma', async () => {
    comoOrganizacion()
    const w = await montarAprobacion()
    expect(w.find('.cfn select').exists()).toBe(true)
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura).not.toHaveBeenCalled()
    expect(w.find('.maa__error').text()).toMatch(/calidad/i)
  })

  it('con calidad: la manda', async () => {
    comoOrganizacion()
    const w = await montarAprobacion()
    await w.find('.cfn select').setValue('medios')
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura.mock.calls[0][2]).toMatchObject({ peso_confirmado_g: 30, calidad: 'medios' })
  })

  it('«Otro» pide qué es, y lo manda como descripción', async () => {
    comoOrganizacion()
    const w = await montarAprobacion()
    await w.find('.cfn select').setValue('otro')
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura).not.toHaveBeenCalled()

    await w.find('.cfn input').setValue('Recortes')
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura.mock.calls[0][2]).toMatchObject({ calidad: 'otro', descripcion: 'Recortes' })
  })

  it('a un frasco que ya existe no la pide (lo viejo no se bloquea)', async () => {
    comoOrganizacion()
    api.listStocks.mockResolvedValueOnce({ data: [{ id: 3, forma_producto: 'flor_seca', estado: 'asignado', cantidad: 5, numero_lote_producto: 'ST-3' }] })
    const w = await montarAprobacion()
    await w.findAll('.maa__cont').find(c => c.text().includes('ST-3')).trigger('click')
    expect(w.find('.cfn').exists()).toBe(false)
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura.mock.calls[0][2]).toMatchObject({ stock_id: 3 })
    expect(api.confirmarPesajeManicura.mock.calls[0][2].calidad).toBeUndefined()
  })

  it('repartida: cada frasco nuevo con su calidad, y si a uno le falta no confirma', async () => {
    comoOrganizacion()
    const w = await montarAprobacion()
    await w.findAll('.maa__link').find(b => b.text().includes('Repartir')).trigger('click')
    const filas = w.findAll('.rpf__fila')
    await filas[0].find('.rpf__input--g').setValue(20)
    await filas[1].find('.rpf__input--g').setValue(10)
    await filas[1].find('.rpf__select--calidad').setValue('')
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura).not.toHaveBeenCalled()

    await filas[1].find('.rpf__select--calidad').setValue('medios')
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura.mock.calls[0][2].destinos.map(d => d.calidad)).toEqual(['altos', 'medios'])
  })

  it('en uso personal no se ofrece ni se pide', async () => {
    useAuthStore().user = { id: 1, role: 'admin', reglas_stock: { calidades: {}, calidad_obligatoria: false } }
    const w = await montarAprobacion()
    expect(w.find('.cfn').exists()).toBe(false)
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura).toHaveBeenCalled()
  })
})

describe('Cómo se nombra el producto', () => {
  it('«Flor seca · Altos» con calidad; sin calidad, como siempre', async () => {
    const { productoLabel } = await import('../lib/formatters.js')
    expect(productoLabel({ forma_producto: 'flor_seca', calidad_label: 'Altos' })).toBe('Flor seca · Altos')
    expect(productoLabel({ forma_producto: 'flor_seca' })).toBe('Flor seca')
  })
})
