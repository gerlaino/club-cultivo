import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 12-oct-2026): una receta no se traba porque el producto no esté en el depósito. Se
// da de alta ahí mismo, queda ATADO a la receta (por su id, no un texto suelto) y la pantalla
// avisa que no genera registro contable: la compra se registra en Contabilidad.
const api = vi.hoisted(() => ({ listInsumos: vi.fn(), listRecetas: vi.fn(), createInsumo: vi.fn(), createReceta: vi.fn() }))
vi.mock('../lib/api.js', () => ({
  listRecetas: (...a) => api.listRecetas(...a),
  listInsumos: (...a) => api.listInsumos(...a),
  createInsumo: (...a) => api.createInsumo(...a),
  createReceta: (...a) => api.createReceta(...a),
  getReceta: vi.fn(), updateReceta: vi.fn(), comprarInsumo: vi.fn(),
  updateInsumo: vi.fn(), reconteoInsumo: vi.fn(), deleteInsumo: vi.fn(),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn() }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../composables/useUsoPersonal.js', async () => { const { ref } = await import('vue'); return { useUsoPersonal: () => ({ esPersonal: ref(false) }) } })
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: vi.fn() }))

const CALMAG = { id: 3, nombre: 'Cal-Mag', unidad_medida: 'mililitro', stock_actual: 30, activo: true }

async function abrirNuevaReceta(insumos = [CALMAG]) {
  api.listInsumos.mockResolvedValue({ data: { insumos } })
  api.listRecetas.mockResolvedValue({ data: [] })
  setActivePinia(createPinia())
  const V = (await import('../views/RecetasView.vue')).default
  const w = mount(V, { global: { stubs: { teleport: true, RouterLink: true }, directives: { modal: {} } }, attachTo: document.body })
  await vi.waitFor(() => expect(api.listInsumos).toHaveBeenCalled())
  await flushPromises(); await flushPromises()
  await w.findAll('button').find(b => b.text().includes('Nueva receta')).trigger('click')
  await flushPromises()
  return w
}
async function elegirProductoNuevo(w) {
  const sel = w.find('.rc__item-row select')
  sel.element.value = '__nuevo__'
  await sel.trigger('change')
}

describe('Receta: producto que todavía no está cargado', () => {
  beforeEach(() => { Object.values(api).forEach(f => f.mockReset()) })

  it('sin ningún producto cargado, la receta igual se puede armar', async () => {
    const w = await abrirNuevaReceta([])
    const opciones = w.find('.rc__item-row select').findAll('option').map(o => o.text())
    expect(opciones.some(t => t.includes('Producto nuevo'))).toBe(true)
  })

  it('avisa que no genera registro contable', async () => {
    const w = await abrirNuevaReceta()
    await elegirProductoNuevo(w)
    expect(w.find('[data-testid="receta-producto-nuevo"]').text()).toContain('no genera registro contable')
  })

  it('al darlo de alta queda elegido en la fila, por su id, y la receta se guarda con él', async () => {
    api.createInsumo.mockResolvedValue({ data: { id: 99, nombre: 'Big Bloom', unidad_medida: 'mililitro', stock_actual: 0, activo: true } })
    api.createReceta.mockResolvedValue({ data: {} })
    const w = await abrirNuevaReceta()
    await elegirProductoNuevo(w)
    await w.find('[data-testid="receta-producto-nuevo"] input').setValue('Big Bloom')
    await w.findAll('[data-testid="receta-producto-nuevo"] button').find(b => b.text().includes('Dar de alta')).trigger('click')
    await flushPromises()

    expect(api.createInsumo).toHaveBeenCalledWith(expect.objectContaining({ nombre: 'Big Bloom', tipo: 'cultivo' }))
    expect(w.find('.rc__item-row select').element.value).toBe('99')

    await w.find('input[placeholder="Vege semana 2"]').setValue('Flora 1')
    await w.find('.rc__item-row input[type="number"]').setValue(2)
    await w.findAll('button').find(b => b.text().includes('Crear receta')).trigger('click')
    await flushPromises()
    const items = api.createReceta.mock.calls[0][0].receta_items_attributes
    expect(items[0].insumo_id).toBe(99)
  })

  it('si ya existe con ese nombre, ofrece usar ese en vez de duplicarlo', async () => {
    const w = await abrirNuevaReceta()
    await elegirProductoNuevo(w)
    await w.find('[data-testid="receta-producto-nuevo"] input').setValue('cal-mag')
    const usar = w.findAll('[data-testid="receta-producto-nuevo"] button').find(b => b.text() === 'Usar ese')
    expect(usar).toBeTruthy()
    await usar.trigger('click')
    expect(api.createInsumo).not.toHaveBeenCalled()
    expect(w.find('.rc__item-row select').element.value).toBe('3')
  })
})
