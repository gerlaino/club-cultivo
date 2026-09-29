import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 29-sep-2026): la receta es de la organización y el depósito del que se descuenta lo
// decide la sala donde se aplica. Con varias sedes:
// - al armar la receta, el mismo producto (nombre y unidad) se ofrece UNA vez, aunque esté en el
//   depósito de cada sede; al editarla, el producto guardado no queda en blanco;
// - al regar, la pantalla pide la receta y los productos de la sede del lote/sala;
// - si esa sede no lo tiene, lo dice y no ofrece «descontar lo que hay».
const api = vi.hoisted(() => ({ listInsumos: vi.fn(), listRecetas: vi.fn() }))
vi.mock('../lib/api.js', () => ({
  listRecetas: (...a) => api.listRecetas(...a),
  listInsumos: (...a) => api.listInsumos(...a),
  getReceta: vi.fn(), createReceta: vi.fn(), updateReceta: vi.fn(), createInsumo: vi.fn(), comprarInsumo: vi.fn(),
  updateInsumo: vi.fn(), reconteoInsumo: vi.fn(), deleteInsumo: vi.fn(),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn() }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../composables/useUsoPersonal.js', () => ({ useUsoPersonal: () => ({ esPersonal: { value: false } }) }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: vi.fn() }))

const GROW_A = { id: 1, nombre: 'Bio-Grow', unidad_medida: 'mililitro', stock_actual: 1000, activo: true, sede_id: 10 }
const GROW_B = { id: 2, nombre: 'Bio-Grow ', unidad_medida: 'mililitro', stock_actual: 500, activo: true, sede_id: 20 }
const CALMAG = { id: 3, nombre: 'Cal-Mag', unidad_medida: 'mililitro', stock_actual: 30, activo: true, sede_id: 10 }

async function montarRecetas(recetas = []) {
  api.listInsumos.mockResolvedValue({ data: { insumos: [GROW_A, GROW_B, CALMAG] } })
  api.listRecetas.mockResolvedValue({ data: recetas })
  setActivePinia(createPinia())
  const V = (await import('../views/RecetasView.vue')).default
  const w = mount(V, { global: { stubs: { teleport: true, RouterLink: true }, directives: { modal: {} } }, attachTo: document.body })
  await flushPromises()
  return w
}
const opcionesProducto = w => w.find('.rc__item-row select').findAll('option').filter(o => o.attributes('value') !== '')

describe('Recetas con varias sedes: el selector de productos', () => {
  beforeEach(() => { Object.values(api).forEach(f => f.mockReset()) })

  it('el mismo producto de dos sedes se ofrece una sola vez', async () => {
    const w = await montarRecetas()
    await w.findAll('button').find(b => b.text().includes('Nueva receta')).trigger('click')
    const textos = opcionesProducto(w).map(o => o.text())
    expect(textos.filter(t => t.startsWith('Bio-Grow'))).toHaveLength(1)
    expect(textos).toContain('Cal-Mag')
  })

  it('al editar una receta armada con el de la otra sede, ese producto sigue elegido', async () => {
    const receta = { id: 7, nombre: 'Vege', uso: 'riego', activa: true,
      items: [{ id: 70, insumo_id: GROW_B.id, nombre: 'Bio-Grow', dosis: '2', unidad: 'ml_l', unidad_label: 'ml/L' }] }
    const w = await montarRecetas([receta])
    await w.find('.rc__receta-acts button[title="Editar"]').trigger('click')
    const select = w.find('.rc__item-row select')
    expect(select.element.value).toBe(String(GROW_B.id))
    expect(opcionesProducto(w).filter(o => o.text().startsWith('Bio-Grow'))).toHaveLength(1)
  })
})

describe('Regar: los productos son los de la sede donde se riega', () => {
  beforeEach(() => { Object.values(api).forEach(f => f.mockReset()) })

  async function montarRiego(props, receta) {
    api.listRecetas.mockResolvedValue({ data: [receta] })
    api.listInsumos.mockResolvedValue({ data: { insumos: [] } })
    const RiegoForm = (await import('../components/lotes/registro/RiegoForm.vue')).default
    const w = mount(RiegoForm, { props: { modelValue: { fertilizo: true, modo_nutricion: 'receta', receta_id: receta.id, volumen: 20 }, ...props,
      'onUpdate:modelValue': v => w.setProps({ modelValue: v }) } })
    await flushPromises()
    return w
  }
  const RECETA = { id: 7, nombre: 'Vege', uso: 'riego', activa: true,
    items: [{ id: 70, insumo_id: GROW_A.id, nombre: 'Bio-Grow', dosis: '2', unidad: 'ml_l', unidad_label: 'ml/L', unidad_insumo: 'mililitro', stock_actual: 0, sin_en_sede: true, factor: 1 }] }

  it('desde un lote pide la receta y los productos de la sede de ese lote', async () => {
    await montarRiego({ loteId: 55 }, RECETA)
    expect(api.listRecetas).toHaveBeenCalledWith('riego', { lote_id: 55 })
    expect(api.listInsumos).toHaveBeenCalledWith(expect.objectContaining({ lote_id: 55 }))
  })

  it('en la sala, el volumen se pide como TOTAL de la sala', async () => {
    const w = await montarRiego({ salaId: 9 }, RECETA)
    expect(w.text()).toContain('Volumen total de la sala')
    const w2 = await montarRiego({ loteId: 55 }, RECETA)
    expect(w2.text()).not.toContain('Volumen total de la sala')
  })

  it('desde una sala, con la sala', async () => {
    await montarRiego({ salaId: 9 }, RECETA)
    expect(api.listRecetas).toHaveBeenCalledWith('riego', { sala_id: 9 })
    expect(api.listInsumos).toHaveBeenCalledWith(expect.objectContaining({ sala_id: 9 }))
  })

  it('si la sede no lo tiene, lo dice y no ofrece descontar lo que hay', async () => {
    const w = await montarRiego({ loteId: 55 }, RECETA)
    expect(w.text()).toContain('No hay Bio-Grow en el depósito de esta sede')
    expect(w.text()).not.toContain('Descontar lo que hay')
  })

  it('si la sede lo tiene pero no alcanza, ofrece las dos opciones de siempre', async () => {
    const conPoco = { ...RECETA, items: [{ ...RECETA.items[0], insumo_id: GROW_B.id, stock_actual: 10, sin_en_sede: false }] }
    const w = await montarRiego({ loteId: 55 }, conPoco)
    expect(w.text()).toContain('Faltan 30')
    expect(w.text()).toContain('Descontar lo que hay')
  })
})
