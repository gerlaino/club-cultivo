import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { reactive } from 'vue'

// AC (Germán, 29-sep): en el teléfono del uso personal, al crear un gasto se puede poner que se
// paga en cuotas. Es la misma compra en cuotas de una organización: una cuota por mes.
const createCompraCuotas = vi.fn(() => Promise.resolve({ data: {} }))
const createMovimiento   = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api', () => ({
  createCompraCuotas: (...a) => createCompraCuotas(...a),
  createMovimiento:   (...a) => createMovimiento(...a),
  updateMovimiento: vi.fn(), deleteMovimiento: vi.fn(),
  listMovimientos: vi.fn(() => Promise.resolve({ data: { movimientos: [], totales: { egresos: 0 } } })),
  listCategoriasContables: vi.fn(() => Promise.resolve({ data: [{ id: 5, nombre: 'Luz', clave_efectiva: 'servicios', unidad_negocio: { tipo: 'cultivo' } }] })),
  listLotes: vi.fn(() => Promise.resolve({ data: [] })),
  listSedes: vi.fn(() => Promise.resolve({ data: [{ id: 9, nombre: 'Casa' }] })),
  listInsumos: vi.fn(() => Promise.resolve({ data: [] })), listDepositos: vi.fn(() => Promise.resolve({ data: [] })),
  listUnidadesNegocio: vi.fn(), createCategoriaContable: vi.fn(), updateCategoriaContable: vi.fn(),
}))

const { useGastosPersonal, formVacio } = await import('../composables/useGastosPersonal.js')
const GastoForm = (await import('../components/personal/GastoForm.vue')).default

function montarForm(form) {
  return mount(GastoForm, { props: { form, categorias: [{ id: 5, nombre: 'Luz' }], lotes: [{ id: 1, codigo: 'CASA-01' }], hoy: '2026-09-29' } })
}

describe('Gasto personal en cuotas', () => {
  beforeEach(() => { createCompraCuotas.mockClear(); createMovimiento.mockClear() })

  it('al anotar se puede elegir «En cuotas», y dice cuánto es cada una', async () => {
    const form = reactive({ ...formVacio(5), descripcion: 'Lámpara LED', monto_ars: 60000 })
    const w = montarForm(form)
    await w.findAll('.gf__seg-b').find(b => b.text() === 'En cuotas').trigger('click')
    await w.find('input[type=number][max="60"]').setValue(6)

    expect(w.text()).toContain('cuotas de')
    expect(w.find('.gf__resumen').text()).toContain('6 cuotas')
    expect(w.find('.gf__resumen').text()).toContain('$10.000')
  })

  it('en cuotas no ofrece lote ni nutriente (la compra en cuotas no los guarda)', async () => {
    const form = reactive({ ...formVacio(5), plan: 'cuotas' })
    const w = montarForm(form)
    expect(w.text()).toContain('En cuotas no se imputa a un lote')
    expect(w.find('.gf__check').exists()).toBe(false)
  })

  it('al corregir un gasto ya anotado no ofrece cuotas', () => {
    const form = reactive({ ...formVacio(5), id: 3 })
    expect(montarForm(form).find('.gf__seg').exists()).toBe(false)
  })

  it('guardar en cuotas crea la compra en cuotas, con la sede y la categoría', async () => {
    const g = useGastosPersonal()
    await g.cargarCatalogo()
    g.nuevo()
    Object.assign(g.form, { descripcion: 'Lámpara LED', monto_ars: 60000, plan: 'cuotas', cuotas_total: 6, fecha: '2026-10-05' })

    expect(await g.guardar()).toBe(true)
    expect(createMovimiento).not.toHaveBeenCalled()
    expect(createCompraCuotas).toHaveBeenCalledWith(expect.objectContaining({
      sede_id: 9, descripcion: 'Lámpara LED', monto_total_ars: 60000, cuotas_total: 6,
      fecha_primera_cuota: '2026-10-05', categoria_contable_id: 5, categoria: 'servicios',
    }))
  })

  it('en un pago sigue siendo un gasto común', async () => {
    const g = useGastosPersonal()
    await g.cargarCatalogo()
    g.nuevo()
    Object.assign(g.form, { descripcion: 'Sustrato', monto_ars: 8000 })
    await g.guardar()
    expect(createMovimiento).toHaveBeenCalled()
    expect(createCompraCuotas).not.toHaveBeenCalled()
  })
})
