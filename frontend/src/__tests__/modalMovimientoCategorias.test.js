import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const createCategoriaContable = vi.fn(() =>
  Promise.resolve({ data: { id: 99, nombre: 'Alquiler', tipo: 'egreso', clave_efectiva: 'otro' } }))

vi.mock('../lib/api.js', () => ({
  createCategoriaContable: (...a) => createCategoriaContable(...a),
  createUnidadNegocio: vi.fn(() => Promise.resolve({ data: { id: 5, nombre: 'Eventos', tipo: 'general' } })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn() }),
}))

const ModalMovimiento = (await import('../components/contabilidad/ModalMovimiento.vue')).default

// AC: el catálogo contable arranca VACÍO (SembrarCatalogo no siembra el árbol por defecto).
// Un club nuevo que quiere anotar su primer gasto tiene que poder crear la categoría desde acá.
// Antes sólo se podían crear SUBcategorías, así que sin categorías madre el botón quedaba
// deshabilitado y mudo: callejón sin salida.
describe('ModalMovimiento — crear categorías', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    createCategoriaContable.mockClear()
    document.body.innerHTML = ''
  })

  const montar = async (categorias = []) => {
    const w = mount(ModalMovimiento, {
    props: {
      modelValue: false,
      // Entra directo al flujo de gasto, que es el caso reportado (el modal arranca en una
      // pantalla de intención con 5 accesos).
      flujoInicial: 'gasto',
      categorias,
      unidades: [
        { id: 1, nombre: 'Cultivo' },
        { id: 2, nombre: 'Dispensario' },
        { id: 3, nombre: 'General' },
      ],
    },
    global: { stubs: { DsSpinner: true, AppDatePicker: true, ConfirmDialog: true } },
    attachTo: document.body,
    })
    // El modal se inicializa al ABRIRSE, no al montarse.
    await w.setProps({ modelValue: true })
    await new Promise(r => setTimeout(r, 0))
    return w
  }

  // El botón vive en el pie del combobox de categoría: hay que desplegarlo.
  const abrirComboCategoria = () => {
    document.body.querySelector('.mv-combo')?.click()
    return new Promise(r => setTimeout(r, 0))
  }

  it('con el catálogo vacío se puede crear igual la primera categoría', async () => {
    const wrapper = await montar([])
    await abrirComboCategoria()

    const crear = [...document.body.querySelectorAll('button')]
      .find(b => b.textContent.includes('Crear una categoría'))

    expect(crear, 'debería existir el botón de crear').toBeTruthy()
    expect(crear.disabled, 'no puede estar deshabilitado sin explicación').toBe(false)
    wrapper.unmount()
  })

  // El síntoma reportado: el selector de área mostraba una sola opción.
  it('ofrece TODOS los sectores del club al crear una categoría principal', async () => {
    const wrapper = await montar([])
    await abrirComboCategoria()

    const crear = [...document.body.querySelectorAll('button')]
      .find(b => b.textContent.includes('Crear una categoría'))
    crear.click()
    await new Promise(r => setTimeout(r, 0))

    const opciones = [...document.body.querySelectorAll('option')].map(o => o.textContent)
    expect(opciones).toContain('Cultivo')
    expect(opciones).toContain('Dispensario')
    expect(opciones).toContain('General')
    wrapper.unmount()
  })

  // Al crear una categoría hay que decir de qué SECTOR es: se elige de los cinco que existen,
  // con su nombre, nunca escribiendo uno nuevo ni viendo la clave interna.
  it('la categoría nueva pide sector, y lo ofrece por nombre', async () => {
    const wrapper = await montar([])
    await abrirComboCategoria()
    ;[...document.body.querySelectorAll('button')]
      .find(b => b.textContent.includes('Crear una categoría')).click()
    await new Promise(r => setTimeout(r, 0))

    const opciones = [...document.body.querySelectorAll('option')].map(o => o.textContent.trim())
    expect(opciones).toContain('Cultivo')
    expect(opciones).not.toContain('administracion')
    // Y no hay forma de inventar uno.
    expect([...document.body.querySelectorAll('button')]
      .find(b => /crear un sector/i.test(b.textContent))).toBeFalsy()
    wrapper.unmount()
  })
})

// AC del rediseño (#28): un solo formulario. La pantalla de intención obligaba a clasificar
// el movimiento ANTES de cargarlo —justo cuando menos se sabe— y esa elección definía qué
// campos aparecían después. Ahora lo único que se elige de entrada es si la plata sale o entra.
describe('ModalMovimiento — un solo formulario', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    document.body.innerHTML = ''
  })

  const abrir = async (props = {}) => {
    const w = mount(ModalMovimiento, {
      props: { modelValue: false, categorias: [], unidades: [], ...props },
      global: { stubs: { DsSpinner: true, AppDatePicker: true, ConfirmDialog: true } },
      attachTo: document.body,
    })
    await w.setProps({ modelValue: true })
    await new Promise(r => setTimeout(r, 0))
    return w
  }

  it('abre directo en el formulario, sin preguntar antes "qué pasó"', async () => {
    const w = await abrir()

    expect(w.vm.paso).toBe('form')
    expect(document.body.innerHTML).not.toContain('¿Qué pasó?')
    w.unmount()
  })

  // CAMBIO DE CRITERIO (Germán, ago-2026): acá SÓLO se registra plata que sale. La que entra ya
  // tiene su puerta —el pago de un paciente se registra en su cuenta corriente, que crea el
  // movimiento sola; el recupero sale de la dispensación; lo del buffet, del mostrador— y
  // cargarla otra vez a mano la contaría dos veces.
  it('acá sólo sale plata, y dice dónde se registra la que entra', async () => {
    const w = await abrir()

    const txt = document.body.textContent
    expect(txt).toContain('Salió plata')
    expect(txt).not.toContain('Entró plata')
    expect(txt).toMatch(/cuenta corriente/i)
    w.unmount()
  })

  it('cambiar de salió a entró conserva el monto y limpia sólo la categoría', async () => {
    const w = await abrir()
    w.vm.form.monto_ars = 45000
    w.vm.form.categoria_contable_id = 7

    w.vm.setTipo('ingreso')
    await new Promise(r => setTimeout(r, 0))

    expect(w.vm.form.tipo).toBe('ingreso')
    expect(w.vm.form.monto_ars, 'lo ya escrito no se pierde').toBe(45000)
    expect(w.vm.form.categoria_contable_id, 'la categoría es de un tipo, no del otro').toBeNull()
    w.unmount()
  })

  // CAMBIO DE CRITERIO (Germán, ago-2026): el sector ya no se pregunta — LO TRAE LA CATEGORÍA,
  // que pasó a ser obligatoria. Se muestra como consecuencia, en una línea debajo de ella, junto
  // con si la compra entra a un depósito. Preguntarlo aparte era pedir dos veces lo mismo y
  // dejaba la puerta abierta a que se contradijeran.
  it('el sector sale de la categoría y se muestra debajo', async () => {
    const CATS = [{
      id: 1, nombre: 'Fertilizante', tipo: 'egreso', comportamiento_efectivo: 'insumo',
      unidad_negocio: { id: 3, nombre: 'Cultivo' }, subcategorias: [],
    }]
    const w = await abrir({ categorias: CATS, unidades: [{ id: 3, nombre: 'Cultivo' }] })

    w.vm.form.categoria_contable_id = 1
    await new Promise(r => setTimeout(r, 0))

    expect(w.vm.areaDeLaCategoria).toBe('Cultivo')

    const eco = document.body.querySelector('.mv-cat-eco')
    expect(eco, 'el eco de la categoría tiene que estar en pantalla').toBeTruthy()
    expect(eco.textContent).toContain('Cultivo')
    expect(eco.textContent).toMatch(/dep[óo]sito/i)
    w.unmount()
  })

  // Qué campos pide sale del COMPORTAMIENTO de la categoría, no de un flujo elegido antes.
  it('pide depósito sólo si la categoría stockea', async () => {
    const CATS = [
      { id: 1, nombre: 'Insumos',  tipo: 'egreso', comportamiento_efectivo: 'insumo',  subcategorias: [] },
      { id: 2, nombre: 'Alquiler', tipo: 'egreso', comportamiento_efectivo: 'general', subcategorias: [] },
    ]
    // El club tiene sus sectores cargados: sin eso el campo no se dibuja (no hay qué elegir).
    const w = await abrir({ categorias: CATS, unidades: [{ id: 3, nombre: 'Cultivo' }] })

    w.vm.form.categoria_contable_id = 1
    await new Promise(r => setTimeout(r, 0))
    expect(w.vm.pideDestinoCat).toBe(true)

    w.vm.form.categoria_contable_id = 2
    await new Promise(r => setTimeout(r, 0))
    expect(w.vm.pideDestinoCat).toBe(false)
    w.unmount()
  })
})
