import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// Dos cosas que el modal no hacía y el club sí necesita:
//   · cargar "1000 etiquetas a $5" sin sacar la calculadora, y que el precio POR UNIDAD quede
//     registrado (es el dato que después dice si una compra fue cara o barata);
//   · que la categoría, que ya sabe si es plata que entra o que sale, acomode el formulario en
//     vez de exigir que uno acierte el tipo antes para que aparezca en la lista.
vi.mock('../lib/api.js', () => ({
  createCategoriaContable: vi.fn(), createUnidadNegocio: vi.fn(),
}))

const CATEGORIAS = [
  {
    id: 1, nombre: 'Insumos', tipo: 'egreso', comportamiento_efectivo: 'insumo',
    unidad_negocio: { id: 7, nombre: 'Cultivo' },
    subcategorias: [{ id: 11, nombre: 'Fertilizante', tipo: 'egreso', comportamiento_efectivo: 'insumo' }],
  },
  { id: 2, nombre: 'Venta de flor', tipo: 'ingreso', comportamiento_efectivo: 'general',
    unidad_negocio: { id: 7, nombre: 'Cultivo' }, subcategorias: [] },
]

describe('Nuevo movimiento — cantidad × precio, y la categoría que manda', () => {
  let wrapper

  beforeEach(async () => {
    const { default: Modal } = await import('../components/contabilidad/ModalMovimiento.vue')
    wrapper = mount(Modal, {
      props: {
        modelValue: true, categorias: CATEGORIAS,
        sedes: [{ id: 3, nombre: 'Finca Norte' }],
        unidades: [{ id: 7, nombre: 'Cultivo' }],
        depositos: [], bares: [], insumos: [], pacientes: [],
        flujoInicial: 'egreso',
      },
      global: { stubs: { Teleport: true, AppDatePicker: true } },
    })
    await wrapper.vm.$nextTick()
    // Entrar al formulario (la primera pantalla es la de intención).
    if (wrapper.vm.paso !== 'form') { wrapper.vm.paso = 'form'; wrapper.vm.flujo = wrapper.vm.flujo || {} }
    await wrapper.vm.$nextTick()
  })

  const campos = () => wrapper.findAll('.mv-cant input')

  it('la fila cantidad × precio existe en el formulario', () => {
    expect(wrapper.find('.mv-cant').exists()).toBe(true)
    expect(campos()).toHaveLength(2)
  })

  it('1000 × $5 da $5.000 sin tener que calcularlo', async () => {
    await campos()[0].setValue('1000')
    await campos()[1].setValue('5')

    expect(wrapper.vm.form.monto_ars).toBe(5000)
    expect(wrapper.find('.mv-cant-total').text()).toContain('5.000')
  })

  // Al revés: el que sabe el total y la cantidad quiere ver cuánto le salió cada una.
  it('escribir el total con una cantidad cargada deduce el precio unitario', async () => {
    await campos()[0].setValue('1000')
    await wrapper.find('.mv-monto-inp').setValue('5000')

    expect(wrapper.vm.form.monto_ars).toBe(5000)
    expect(campos()[1].element.value).toBe('5')
  })

  it('el total escrito a mano no se pisa solo', async () => {
    await wrapper.find('.mv-monto-inp').setValue('7500')

    expect(wrapper.vm.form.monto_ars).toBe(7500)
  })

  // Los campos usan el formato de acá: la coma es el decimal y el punto separa miles
  // (`parseMonto`). 2,5 × 3,33 = 8,325 → 8,33, porque son pesos y no medio centavo.
  it('redondea a dos decimales: son pesos', async () => {
    await campos()[0].setValue('2,5')
    await campos()[1].setValue('3,33')

    expect(wrapper.vm.form.monto_ars).toBe(8.33)
  })

  it('acepta precios con centavos', async () => {
    await campos()[0].setValue('10')
    await campos()[1].setValue('1.250,50')

    expect(wrapper.vm.form.monto_ars).toBe(12505)
  })

  it('sin cantidad, el modal sigue funcionando como antes', async () => {
    await wrapper.find('.mv-monto-inp').setValue('1200')

    expect(wrapper.vm.form.monto_ars).toBe(1200)
    expect(wrapper.vm.form.categoria_contable_id).toBeNull()
  })

  describe('la categoría define si entró o salió plata', () => {
    it('elegir una de ingreso estando en egreso da vuelta el tipo', async () => {
      wrapper.vm.form.tipo = 'egreso'

      wrapper.vm.elegirCat({ id: 2, tipo: 'ingreso', clave: 'otro', label: 'Venta de flor' })

      expect(wrapper.vm.form.tipo).toBe('ingreso')
      expect(wrapper.vm.form.categoria_contable_id).toBe(2)
    })

    it('buscar encuentra categorías del otro tipo, que antes no aparecían', async () => {
      wrapper.vm.form.tipo = 'egreso'
      wrapper.vm.catQuery = 'venta'
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.catsFiltradas.map((c) => c.label)).toContain('Venta de flor')
    })

    it('sin búsqueda, la lista muestra las del tipo actual', async () => {
      wrapper.vm.form.tipo = 'egreso'
      wrapper.vm.catQuery = ''
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.catsFiltradas.every((c) => c.tipo === 'egreso')).toBe(true)
    })
  })
})
