import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (22-oct-2026, Javi en prod con ST-26-0028): «había 132, en realidad hay 70; ajusté como
// reconteo a 70 y sobre la mesa siguen quedando 132». Con producto sobre la mesa, recontar es contar
// cada lugar: el depósito y la mesa, y el total lo suma la máquina. La ficha dice cuánto hay ahora
// y dónde. Un frasco de cosecha recupera sólo lo que un reconteo anterior le sacó.
const BASE = {
  id: 28, forma_producto: 'flor_seca', unidad: 'g', origen: 'lote', lote_id: 3, sede_id: 1,
  cantidad: 53, cantidad_inicial: 168, cantidad_disponible_real: 0, separable: 0, disponible_para_entregar: 53,
  en_mostrador_g: 115, en_deposito_g: 0, mesas: [{ id: 9, sede: 'Centro', cantidad: 115 }], reconteo_devolvible: 115,
  estado: 'asignado', numero_lote_producto: 'ST-26-0028', puede_cambiar_forma: true, dispensas_cerradas: 0,
}
let stock = { ...BASE }
const ajustarStock = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({
  getStock: vi.fn(() => Promise.resolve({ data: { data: stock } })),
  updateStock: vi.fn(), asignarStock: vi.fn(), ajustarStock: (...a) => ajustarStock(...a), descartarStock: vi.fn(), deleteStock: vi.fn(),
  getStockMovimientos: vi.fn(() => Promise.resolve({ data: [] })), listSedes: vi.fn(() => Promise.resolve({ data: [] })),
  producirStock: vi.fn(), listPesajesManicura: vi.fn(() => Promise.resolve({ data: [] })), reajustarPesoPesajeManicura: vi.fn(),
  listGeneticas: vi.fn(() => Promise.resolve({ data: [] })), separarStock: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }) }))
vi.mock('vue-router', () => ({ useRoute: () => ({ params: { id: '28' } }), useRouter: () => ({ push: vi.fn(), back: vi.fn() }) }))

async function montar() {
  setActivePinia(createPinia())
  const { default: V } = await import('../views/admin/AdminStockDetailView.vue')
  const w = mount(V, { global: { stubs: { RouterLink: true, DsSpinner: true, Teleport: true }, directives: { modal: {} } } })
  await flushPromises(); await flushPromises()
  return w
}
async function abrirReconteo(w) {
  await w.findAll('.sd__action').find(b => b.text().includes('Ajustar gramos')).trigger('click'); await flushPromises()
  await w.find('.sd__modal select.sd__input').setValue('reconteo'); await flushPromises()
}
const confirmar = (w) => w.findAll('.sd__btn-primary').find(b => b.text().includes('Confirmar'))

describe('Recontar con producto sobre la mesa', () => {
  beforeEach(() => { vi.clearAllMocks(); stock = { ...BASE } })

  it('la ficha dice cuánto hay ahora y dónde', async () => {
    const w = await montar()
    const kpi = w.findAll('.sd__kpi').find(k => k.text().includes('Hay ahora'))
    expect(kpi.text()).toContain('53.0')
    expect(kpi.text()).toContain('depósito 0.0 + mesa 115.0')
  })

  it('pide el depósito y la mesa por separado y manda los dos; el total es la suma', async () => {
    const w = await montar()
    await abrirReconteo(w)
    expect(w.find('input[aria-label="Cuánto hay sobre la mesa de Centro"]').element.value).toBe('115')
    await w.find('input[aria-label="Cuánto hay en el depósito"]').setValue(53)
    await w.find('.sd__modal textarea').setValue('pesé todo')
    expect(w.find('.sd__ajuste-preview').text()).toContain('168')
    await confirmar(w).trigger('click'); await flushPromises()
    expect(ajustarStock).toHaveBeenCalledWith(28, { tipo: 'reconteo', deposito: 53, mesas: { 9: 115 }, motivo: 'pesé todo' })
  })

  it('el caso de Javi: la mesa tenía de más → depósito 0 y mesa 53', async () => {
    const w = await montar()
    await abrirReconteo(w)
    await w.find('input[aria-label="Cuánto hay en el depósito"]').setValue(0)
    await w.find('input[aria-label="Cuánto hay sobre la mesa de Centro"]').setValue(53)
    await w.find('.sd__modal textarea').setValue('verificación')
    await confirmar(w).trigger('click'); await flushPromises()
    expect(ajustarStock).toHaveBeenCalledWith(28, { tipo: 'reconteo', deposito: 0, mesas: { 9: 53 }, motivo: 'verificación' })
  })

  it('un frasco de cosecha no puede subir más de lo que le sacaron los reconteos', async () => {
    stock = { ...BASE, reconteo_devolvible: 62 }
    const w = await montar()
    await abrirReconteo(w)
    await w.find('input[aria-label="Cuánto hay en el depósito"]').setValue(53) // +115
    await w.find('.sd__modal textarea').setValue('x')
    expect(w.text()).toContain('Sólo pueden volver')
    expect(confirmar(w).attributes('disabled')).toBeDefined()
  })

  it('sin depósito contado no se manda nada', async () => {
    const w = await montar()
    await abrirReconteo(w)
    await w.find('.sd__modal textarea').setValue('x')
    await confirmar(w).trigger('click'); await flushPromises()
    expect(ajustarStock).not.toHaveBeenCalled()
    expect(w.text()).toContain('Escribí lo que hay en cada lugar')
  })

  it('una merma con mesa avisa que sale del depósito y no deja pasar de ahí', async () => {
    stock = { ...BASE, origen: 'compra_externa', cantidad: 132, en_deposito_g: 32, en_mostrador_g: 100, mesas: [{ id: 9, sede: 'Centro', cantidad: 100 }] }
    const w = await montar()
    await w.findAll('.sd__action').find(b => b.text().includes('Ajustar gramos')).trigger('click'); await flushPromises()
    await w.find('.sd__modal select.sd__input').setValue('merma'); await flushPromises()
    expect(w.text()).toContain('Esto sale del depósito')
    await w.find('.sd__modal input[type=number]').setValue(40)
    await w.find('.sd__modal textarea').setValue('se rompió')
    await confirmar(w).trigger('click'); await flushPromises()
    expect(ajustarStock).not.toHaveBeenCalled()
    expect(w.text()).toContain('se baja desde el mostrador')
  })
})
