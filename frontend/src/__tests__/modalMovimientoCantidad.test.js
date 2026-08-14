import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// Dos cosas del alta de un movimiento:
//   · el cuerpo registra PLATA. Cuántos kilos entraron es una pregunta de inventario y se hace
//     una sola vez, en DestinoStock, que es donde el dato se guarda;
//   · el flujo y la categoría COEXISTEN: cualquiera de los dos puede ofrecer el depósito y
//     ninguno lo impone, porque un gasto puede pertenecer a una categoría con sector y no
//     entrar a ningún inventario (una limpieza contratada, por ejemplo).
vi.mock('../lib/api.js', () => ({
  createCategoriaContable: vi.fn(), createUnidadNegocio: vi.fn(),
}))

// UN SOLO NIVEL: sector → categoría (las subcategorías se eliminaron en ago-2026).
// "Fertilizante" entra al depósito de Cultivo; "Alquiler" es puro gasto del mismo sector.
const CATEGORIAS = [
  { id: 1, nombre: 'Fertilizante', tipo: 'egreso', comportamiento_efectivo: 'insumo',
    unidad_negocio: { id: 7, nombre: 'Cultivo' }, subcategorias: [] },
  { id: 2, nombre: 'Alquiler', tipo: 'egreso', comportamiento_efectivo: 'general',
    unidad_negocio: { id: 7, nombre: 'Cultivo' }, subcategorias: [] },
]

describe('Nuevo movimiento — la plata acá, el inventario allá', () => {
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

  // CAMBIO DE CRITERIO (ago-2026). Antes la cantidad vivía SÓLO en "¿Entra al inventario?"
  // (DestinoStock), para no pedirla dos veces. El problema: un gasto que no entra a ningún
  // depósito —10 horas de electricista, 3 análisis de laboratorio— se quedaba sin cantidad y
  // por lo tanto sin costo unitario, que es el número con el que se compara un proveedor contra
  // otro. Ahora la cantidad es del MOVIMIENTO y el bloque de depósito la refleja: se sigue
  // cargando en un solo lugar, que era el motivo de la regla vieja, pero ese lugar es el cuerpo.
  // Elegir una categoría que entra al depósito (Insumos, comportamiento 'insumo').
  const conCategoriaQueStockea = async () => {
    wrapper.vm.form.categoria_contable_id = 1
    await wrapper.vm.$nextTick()
  }

  // CAMBIO DE CRITERIO (Germán, ago-2026): la cantidad se pregunta cuando hay algo que contar,
  // o sea cuando la categoría entra a un depósito. Para pagar la luz no hay nada que contar, y
  // preguntarlo igual era una de las doce decisiones que hacían el alta poco natural.
  it('pide cantidad y unidad cuando la compra entra al depósito', async () => {
    await conCategoriaQueStockea()

    expect(wrapper.find('.mv-cant').exists()).toBe(true)
  })

  it('y no las pide para un gasto que no stockea', async () => {
    wrapper.vm.form.categoria_contable_id = 2   // "Venta de flor": comportamiento general
    await wrapper.vm.$nextTick()

    expect(wrapper.find('.mv-cant').exists()).toBe(false)
  })

  it('con el monto calcula el precio por unidad', async () => {
    await conCategoriaQueStockea()
    await wrapper.find('.mv-monto-inp').setValue('1200')
    wrapper.vm.form.cantidad = 4
    await wrapper.vm.$nextTick()

    expect(wrapper.vm.unitario).toBe(300)
    expect(wrapper.find('.mv-cant-uni').text()).toContain('300')
  })

  // Dentro de una compra la cantidad sigue siendo opcional hasta que se elige el depósito.
  it('sin cantidad no hay unitario', async () => {
    await conCategoriaQueStockea()
    await wrapper.find('.mv-monto-inp').setValue('1200')

    expect(wrapper.vm.unitario).toBeNull()
  })

  // Un alquiler, un sueldo o una limpieza contratada no tienen cantidad. Que el bloque de
  // depósito aparezca o no lo decide el flujo o la categoría, nunca un campo suelto.
  it('un gasto que no entra a inventario no muestra el bloque de depósito', async () => {
    wrapper.vm.form.categoria_contable_id = null
    wrapper.vm.flujo = { key: 'gasto', tipo: 'egreso', pideDestino: false }
    await wrapper.vm.$nextTick()

    expect(wrapper.vm.pideDestino).toBe(false)
  })

  // El espejo del bug: "Compré algo" declara `pideDestino: true`, pero el bloque se mostraba
  // sólo si la CATEGORÍA stockeaba. Con una categoría de comportamiento general, la compra no
  // podía entrar a ningún depósito aunque el flujo dijera que sí.
  it('el flujo de compra ofrece depósito aunque la categoría no stockee', async () => {
    wrapper.vm.flujo = { key: 'compra', tipo: 'egreso', pideDestino: true }
    wrapper.vm.form.categoria_contable_id = 2   // "Venta de flor": comportamiento general
    await wrapper.vm.$nextTick()

    expect(wrapper.vm.pideDestinoCat).toBe(false)   // la categoría no lo pide…
    expect(wrapper.vm.pideDestino).toBe(true)       // …y el depósito se ofrece igual
  })

  it('el total es el hecho y lo escribe una persona: nadie se lo pisa', async () => {
    await wrapper.find('.mv-monto-inp').setValue('1200')

    expect(wrapper.vm.form.monto_ars).toBe(1200)
    expect(wrapper.vm.form.categoria_contable_id).toBeNull()
  })

  describe('la categoría define si entró o salió plata', () => {
    // El tipo lo elige la persona arriba y NO se lo cambia nada por debajo. Que la categoría lo
    // diera vuelta "para ayudar" hacía que un egreso se guardara como ingreso sin que nadie lo
    // pidiera; ahora una del otro tipo directamente no llega hasta acá, y si llegara se ignora.
    it('una categoría del otro tipo no cambia el signo del movimiento', async () => {
      wrapper.vm.form.tipo = 'egreso'

      wrapper.vm.elegirCat({ id: 2, tipo: 'ingreso', clave: 'otro', label: 'Venta de flor' })

      expect(wrapper.vm.form.tipo).toBe('egreso')
      expect(wrapper.vm.form.categoria_contable_id).toBeNull()
    })

    // Buscar tampoco cruza el tipo: "Venta de flor" es de ingresos y no aparece mientras se
    // esté cargando un egreso, por más que el texto coincida.
    it('buscar no trae categorías del otro tipo', async () => {
      wrapper.vm.form.tipo = 'egreso'
      wrapper.vm.catQuery = 'venta'
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.catsFiltradas.map((c) => c.label)).not.toContain('Venta de flor')
      expect(wrapper.vm.catsFiltradas.every((c) => c.tipo === 'egreso')).toBe(true)
    })

    it('sin búsqueda, la lista muestra las del tipo actual', async () => {
      wrapper.vm.form.tipo = 'egreso'
      wrapper.vm.catQuery = ''
      await wrapper.vm.$nextTick()

      expect(wrapper.vm.catsFiltradas.every((c) => c.tipo === 'egreso')).toBe(true)
    })
  })
})

// ── Reordenado del formulario ────────────────────────────────────────────────────
// El único campo obligatorio vivía en la columna de al lado, bajo el título "Se registra así",
// mientras la principal hacía seis preguntas seguidas y la derecha se llenaba de campos que se
// tocan una de cada veinte veces.
describe('Nuevo movimiento — el formulario reordenado', () => {
  let wrapper

  beforeEach(async () => {
    const { default: Modal } = await import('../components/contabilidad/ModalMovimiento.vue')
    wrapper = mount(Modal, {
      props: {
        modelValue: true, categorias: CATEGORIAS,
        sedes: [{ id: 3, nombre: 'Finca Norte' }], unidades: [{ id: 7, nombre: 'Cultivo' }],
        depositos: [], bares: [], insumos: [], pacientes: [], flujoInicial: 'egreso',
      },
      global: { stubs: { Teleport: true, AppDatePicker: true } },
    })
    await wrapper.vm.$nextTick()
  })

  it('la categoría está en el camino principal, no en una columna aparte', () => {
    expect(wrapper.find('.mv-col--asiento').exists()).toBe(false)
    expect(wrapper.text()).not.toContain('Se registra así')
    expect(wrapper.find('.mv-fld--clave').exists()).toBe(true)
  })

  it('la categoría va ANTES que el monto', () => {
    const html = wrapper.html()

    expect(html.indexOf('mv-fld--clave')).toBeLessThan(html.indexOf('mv-monto'))
  })

  it('comprobante, proveedor y notas quedan plegados', () => {
    const extra = wrapper.find('.mv-extra')

    expect(extra.exists()).toBe(true)
    expect(extra.attributes('open')).toBeUndefined()
    expect(extra.find('.mv-extra-sum').text()).toContain('Comprobante')
  })

  it('el resumen del bloque plegado avisa si hay algo adentro', async () => {
    expect(wrapper.vm.resumenExtras).toBe('')

    wrapper.vm.form.proveedor = 'Edenor'
    await wrapper.vm.$nextTick()

    expect(wrapper.vm.resumenExtras).toContain('Edenor')
  })

  // No se pide el detalle de un pago que no ocurrió.
  it('si queda pendiente, no pregunta con qué se pagó', async () => {
    wrapper.vm.form.pagado = true
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain('Cómo se pagó')

    wrapper.vm.form.pagado = false
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).not.toContain('Cómo se pagó')
  })

  it('las etiquetas dejaron de ser un interrogatorio', () => {
    const texto = wrapper.text()

    // Las únicas dos preguntas que quedan, y las dos son a propósito: el atajo de los gastos
    // que se repiten, y la decisión de si la compra entra al inventario (que desde ago-2026
    // está siempre a la vista). El resto son etiquetas: Fecha, Estado del pago, Sector.
    const preguntas = (texto.match(/¿[^?]*\?/g) || [])
    expect(preguntas.every(p => /se repiten|entra al inventario/i.test(p)), preguntas.join(' | ')).toBe(true)

    expect(texto).toContain('Fecha')
    expect(texto).toContain('Estado del pago')
  })
})

// ── Crear categoría: el modelo dicho con sus palabras ────────────────────────────
// Un SECTOR es una línea de negocio; una CATEGORÍA pertenece a un sector; una SUBCATEGORÍA
// pertenece a una categoría y hereda su sector. El formulario daba por sentado que estabas
// creando una subcategoría —preseleccionaba la primera madre que existiera— y preguntaba
// "¿Dentro de cuál?" con una sola opción, que no se entendía.
describe('Nuevo movimiento — crear una categoría', () => {
  let wrapper

  beforeEach(async () => {
    const { default: Modal } = await import('../components/contabilidad/ModalMovimiento.vue')
    wrapper = mount(Modal, {
      props: {
        modelValue: true, categorias: CATEGORIAS,
        sedes: [{ id: 3, nombre: 'Finca Norte' }], unidades: [{ id: 7, nombre: 'Cultivo' }],
        depositos: [], bares: [], insumos: [], pacientes: [], flujoInicial: 'egreso',
      },
      global: { stubs: { Teleport: true, AppDatePicker: true } },
    })
    await wrapper.vm.$nextTick()
    // La caja de crear vive DENTRO del desplegable de categoría: sin abrirlo no se renderiza.
    wrapper.vm.abrirCat()
    wrapper.vm.abrirCrearCat()
    await wrapper.vm.$nextTick()
  })

  it('arranca creando una CATEGORÍA, no una subcategoría de algo que no elegiste', () => {
    expect(wrapper.vm.crearCat.parent_id).toBeNull()
  })

  it('pregunta qué estás creando, con las dos opciones a la vista', () => {
    const texto = wrapper.text()

    expect(texto).toContain('¿Qué estás creando?')
    expect(texto).toContain('Una categoría')
    expect(texto).toContain('Una subcategoría')
    expect(texto).not.toContain('¿Dentro de cuál?')
  })

  it('el selector de madre aparece recién al elegir subcategoría', async () => {
    expect(wrapper.text()).not.toContain('Subcategoría de')

    wrapper.vm.crearCat.parent_id = 1
    await wrapper.vm.$nextTick()

    expect(wrapper.text()).toContain('Subcategoría de')
    expect(wrapper.text()).toContain('Hereda el sector')
  })

  it('creando una categoría se elige su sector; creando una subcategoría no (lo hereda)', async () => {
    expect(wrapper.text()).toContain('Sector')

    wrapper.vm.crearCat.parent_id = 1
    await wrapper.vm.$nextTick()

    expect(wrapper.text()).not.toContain('Crear un sector')
  })

  it('la caja de crear se distingue de la lista de resultados', () => {
    expect(wrapper.find('.mv-newbox-tit').text()).toContain('Nueva categoría')
  })

  // AC (Germán): el alta tiene que seguir SU orden, y las decisiones no pueden quedar escondidas
  // adentro del acordeón de comprobante/notas. El sector es el eje del P&L y "¿entra al
  // depósito?" decide si la compra mueve inventario: ninguna de las dos es papeleo.
  describe('el orden de la pantalla', () => {
    /** Posición en el DOM de cada bloque, para comparar cuál va antes. */
    const posDe = (sel) => {
      const el = wrapper.element.querySelector(sel)
      if (!el) return -1
      return [...wrapper.element.querySelectorAll('*')].indexOf(el)
    }

    it('la categoría va primero y la plata después: categoría → monto → cantidad', async () => {
      wrapper.vm.form.categoria_contable_id = 1
      await wrapper.vm.$nextTick()

      const cat   = posDe('.mv-fld--clave')
      const monto = posDe('.mv-monto')
      const cant  = posDe('.mv-cant')

      expect(cat).toBeGreaterThan(-1)
      expect(monto).toBeGreaterThan(cat)
      expect(cant).toBeGreaterThan(monto)
    })

    // El sector no se pregunta más: lo trae la categoría, y se muestra como consecuencia
    // debajo de ella.
    it('el sector se muestra como eco de la categoría, no como campo', async () => {
      wrapper.vm.form.categoria_contable_id = 1
      await wrapper.vm.$nextTick()

      expect(wrapper.element.querySelector('.mv-cat-eco').textContent).toContain('Cultivo')
    })

    it('el depósito aparece cuando la categoría stockea', async () => {
      wrapper.vm.form.categoria_contable_id = 1
      await wrapper.vm.$nextTick()

      expect(wrapper.element.textContent).toMatch(/entra al inventario/i)
    })
  })

})
