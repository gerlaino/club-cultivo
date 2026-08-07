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

  // El SECTOR ya no se elige por movimiento: se define al crear la categoría, que es el único
  // lugar donde tiene sentido decidirlo. (Sector > categoría > subcategoría.)
  it('el tipo de sector se ofrece con nombres legibles, no con la clave cruda', async () => {
    const wrapper = await montar([])
    await abrirComboCategoria()
    ;[...document.body.querySelectorAll('button')]
      .find(b => b.textContent.includes('Crear una categoría')).click()
    await new Promise(r => setTimeout(r, 0))

    const nuevaArea = [...document.body.querySelectorAll('button')]
      .find(b => b.textContent.includes('Crear un sector'))
    nuevaArea.click()
    await new Promise(r => setTimeout(r, 0))

    const opciones = [...document.body.querySelectorAll('option')].map(o => o.textContent)
    expect(opciones).toContain('Buffet')
    expect(opciones).not.toContain('administracion')
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

  it('lo primero es si la plata salió o entró', async () => {
    const w = await abrir()

    const txt = document.body.textContent
    expect(txt).toContain('Salió plata')
    expect(txt).toContain('Entró plata')
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

  // El área dejó de ser un campo del movimiento: la define la categoría.
  it('el sector no se elige por movimiento', async () => {
    const CATS = [{
      id: 1, nombre: 'Insumos', tipo: 'egreso', comportamiento_efectivo: 'insumo',
      unidad_negocio: { id: 3, nombre: 'Cultivo' }, subcategorias: [],
    }]
    const w = await abrir({ categorias: CATS })

    w.vm.form.categoria_contable_id = 1
    await new Promise(r => setTimeout(r, 0))

    expect(w.vm.areaDeLaCategoria).toBe('Cultivo')
    // El sector se muestra como ECO de la categoría, pegado a ella, no como un campo más de
    // la lista: es la consecuencia de lo que se acaba de elegir.
    expect(document.body.textContent).toContain('Cultivo')
    w.unmount()
  })

  // Qué campos pide sale del COMPORTAMIENTO de la categoría, no de un flujo elegido antes.
  it('pide depósito sólo si la categoría stockea', async () => {
    const CATS = [
      { id: 1, nombre: 'Insumos',  tipo: 'egreso', comportamiento_efectivo: 'insumo',  subcategorias: [] },
      { id: 2, nombre: 'Alquiler', tipo: 'egreso', comportamiento_efectivo: 'general', subcategorias: [] },
    ]
    const w = await abrir({ categorias: CATS })

    w.vm.form.categoria_contable_id = 1
    await new Promise(r => setTimeout(r, 0))
    expect(w.vm.pideDestinoCat).toBe(true)

    w.vm.form.categoria_contable_id = 2
    await new Promise(r => setTimeout(r, 0))
    expect(w.vm.pideDestinoCat).toBe(false)
    w.unmount()
  })
})
