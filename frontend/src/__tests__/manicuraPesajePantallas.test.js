import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 1-oct-2026: «manicura y pesajes, no podemos fallar ahí»). Lo que fijan las pantallas:
// - si el pesaje ya lo confirmó otra persona, no es un error de quien está confirmando: se avisa,
//   se cierra y se recarga la lista;
// - «completar manicura» sólo ofrece las plantas que todavía se pesan (no descartadas, sin peso,
//   sin pesada en otra jornada), y con una jornada enviada pregunta en vez de dar error;
// - un frasco que se vació se vuelve a usar: se ofrece al confirmar (marcado como vacío) y se
//   puede reajustar su pesaje (el backend lo reabre).

const api = {
  listPesajesManicuraAdmin: vi.fn(), confirmarPesajeManicura: vi.fn(), reabrirPesajeManicura: vi.fn(),
  listStocks: vi.fn(() => Promise.resolve({ data: [] })),
  createPesajeManicura: vi.fn(), registrarDirectoManicura: vi.fn(), listPlants: vi.fn(),
}
vi.mock('../lib/api.js', () => api)
vi.mock('../lib/api', () => api)
const toast = { success: vi.fn(), error: vi.fn(), info: vi.fn(), warning: vi.fn() }
vi.mock('../composables/useToast.js', () => ({ useToast: () => toast }))
const registrarConJornada = vi.fn((_lote, fn) => fn({}))
vi.mock('../composables/useManicuraJornada', () => ({ useManicuraJornada: () => ({ registrarConJornada }) }))

const PESAJE = { id: 9, lote_id: 5, lote_codigo: 'L-26-010', estado: 'enviado', peso_total_g: 30, peso_calculado_g: 30, plantas_count: 3, manicurador_nombre: 'Ana' }

beforeEach(() => { vi.clearAllMocks(); setActivePinia(createPinia()) })

describe('Confirmar pesajes (teléfono del admin)', () => {
  async function montar() {
    api.listPesajesManicuraAdmin.mockResolvedValue({ data: [PESAJE] })
    const { default: V } = await import('../views/mobile/MAdminAprobacionView.vue')
    const w = mount(V, { global: { stubs: { RouterLink: true, Teleport: true }, directives: { modal: {} } } })
    await flushPromises()
    await w.find('.maa__btn-aprobar').trigger('click'); await flushPromises()
    return w
  }

  it('si ya lo confirmó otra persona: avisa, cierra y recarga, sin mostrar un error', async () => {
    const w = await montar()
    api.confirmarPesajeManicura.mockRejectedValue({ response: { data: { error: 'Este pesaje ya fue confirmado por Beto', ya_confirmado: true } } })
    api.listPesajesManicuraAdmin.mockResolvedValue({ data: [] })
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(toast.info).toHaveBeenCalledWith('Este pesaje ya fue confirmado por Beto')
    expect(w.find('.maa__sheet').exists()).toBe(false)
    expect(api.listPesajesManicuraAdmin).toHaveBeenCalledTimes(2)
  })

  it('un error real sí se muestra en la hoja', async () => {
    const w = await montar()
    api.confirmarPesajeManicura.mockRejectedValue({ response: { data: { error: 'El frasco ST-1 está cerrado (agotado): elegí otro o uno nuevo' } } })
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(w.find('.maa__sheet').text()).toContain('está cerrado')
    expect(toast.info).not.toHaveBeenCalled()
  })

  it('ofrece también los frascos del lote que ya se vaciaron, marcados como tales', async () => {
    api.listStocks.mockResolvedValue({ data: [
      { id: 1, forma_producto: 'flor_seca', estado: 'asignado', cantidad: 5, numero_lote_producto: 'ST-1', sede: { nombre: 'Centro' } },
      { id: 2, forma_producto: 'flor_seca', estado: 'agotado', cantidad: 0, numero_lote_producto: 'ST-2', sede: { nombre: 'Centro' } },
    ] })
    const w = await montar()
    expect(api.listStocks).toHaveBeenCalledWith({ lote_id: 5, incluir_vacios: 1 })
    const frascos = w.findAll('.maa__cont').map(c => c.text())
    expect(frascos.some(t => t.includes('ST-2') && t.includes('vacío, se vuelve a usar'))).toBe(true)
    expect(frascos.some(t => t.includes('ST-1') && !t.includes('vacío'))).toBe(true)
  })

  // AC (1-oct-2026): «el admin confirma y crea dos frascos, uno de bajos y uno de copones».
  it('repartir en varios frascos: el botón espera a que el reparto sume el peso, y manda cada frasco', async () => {
    const w = await montar()
    api.confirmarPesajeManicura.mockResolvedValue({ data: {} })
    await w.findAll('.maa__link').find(b => b.text().includes('Repartir')).trigger('click')
    const filas = w.findAll('.rpf__fila')
    expect(filas).toHaveLength(2)
    expect(filas.map(f => f.find('.rpf__input--nombre').element.value)).toEqual(['Copones', 'Bajos'])
    await filas[0].find('.rpf__input--g').setValue(20)
    expect(w.find('.maa__btn-confirmar').attributes('disabled')).toBeDefined() // 20 de 30
    expect(w.find('.rpf__total').text()).toContain('faltan 10')
    await filas[1].find('.rpf__input--g').setValue(10)
    expect(w.find('.maa__btn-confirmar').attributes('disabled')).toBeUndefined()
    expect(w.find('.maa__btn-confirmar').text()).toContain('Confirmar en 2 frascos')
    await w.find('.maa__btn-confirmar').trigger('click'); await flushPromises()
    expect(api.confirmarPesajeManicura.mock.calls[0][2]).toEqual({
      peso_confirmado_g: 30,
      destinos: [{ stock_id: undefined, gramos: 20, descripcion: 'Copones' }, { stock_id: undefined, gramos: 10, descripcion: 'Bajos' }],
    })
  })

  it('un doble toque manda una sola confirmación', async () => {
    const w = await montar()
    let resolver
    api.confirmarPesajeManicura.mockReturnValue(new Promise(r => { resolver = r }))
    const b = w.find('.maa__btn-confirmar')
    b.trigger('click'); b.trigger('click')
    resolver({ data: {} }); await flushPromises()
    expect(api.confirmarPesajeManicura).toHaveBeenCalledTimes(1)
  })
})

describe('Completar manicura (ficha del lote)', () => {
  const PLANTAS = [
    { id: 1, nombre: 'P1', state: 'secado', peso_seco: null, tiene_pesada: false },
    { id: 2, nombre: 'P2', state: 'secado', peso_seco: '10.0', tiene_pesada: true },
    { id: 3, nombre: 'P3', state: 'descartada', peso_seco: null, tiene_pesada: false },
    { id: 4, nombre: 'P4', state: 'secado', peso_seco: null, tiene_pesada: true },
    { id: 5, nombre: 'P5', state: 'secado', peso_seco: null, tiene_pesada: false },
  ]
  async function montar() {
    api.listPlants.mockResolvedValue({ data: PLANTAS })
    const { default: M } = await import('../components/lotes/CompletarManicuraModal.vue')
    const w = mount(M, { props: { modelValue: false, lote: { id: 5, codigo: 'L-26-010', manicurador_id: null } },
      global: { stubs: { Teleport: true, DsSpinner: true }, directives: { modal: {} } } })
    await w.setProps({ modelValue: true }); await flushPromises()
    return w
  }

  it('ofrece sólo las que todavía se pesan', async () => {
    const w = await montar()
    expect(w.text()).toContain('P1'); expect(w.text()).toContain('P5')
    for (const n of ['P2', 'P3', 'P4']) expect(w.text()).not.toContain(n)
  })
})

describe('Reajustar el pesaje desde el frasco', () => {
  it('en un frasco que se vació también se ofrece (si el pesaje era más, se reabre)', async () => {
    vi.resetModules()
    const stock = { id: 7, forma_producto: 'flor_seca', unidad: 'g', origen: 'lote', lote_id: 5, cantidad: 0, cantidad_inicial: 30,
      cantidad_disponible_real: 0, gramos_reservados: 0, estado: 'agotado', numero_lote_producto: 'ST-26-0007', puede_cambiar_forma: true }
    vi.doMock('../lib/api.js', () => ({
      getStock: vi.fn(() => Promise.resolve({ data: { data: stock } })), updateStock: vi.fn(), asignarStock: vi.fn(), ajustarStock: vi.fn(),
      descartarStock: vi.fn(), deleteStock: vi.fn(), getStockMovimientos: vi.fn(() => Promise.resolve({ data: [] })),
      listSedes: vi.fn(() => Promise.resolve({ data: [] })), producirStock: vi.fn(), listPesajesManicura: vi.fn(() => Promise.resolve({ data: [] })),
      reajustarPesoPesajeManicura: vi.fn(), listGeneticas: vi.fn(() => Promise.resolve({ data: [] })),
    }))
    vi.doMock('vue-router', () => ({ useRoute: () => ({ params: { id: '7' } }), useRouter: () => ({ push: vi.fn(), back: vi.fn() }) }))
    setActivePinia(createPinia())
    const { default: V } = await import('../views/admin/AdminStockDetailView.vue')
    const w = mount(V, { global: { stubs: { RouterLink: true, DsSpinner: true, Teleport: true } } })
    await flushPromises(); await flushPromises()
    const editar = w.findAll('button').find(b => /editar/i.test(b.text()))
    if (editar) { await editar.trigger('click'); await flushPromises() }
    expect(w.text()).toContain('Editar pesaje del lote')
  })
})
