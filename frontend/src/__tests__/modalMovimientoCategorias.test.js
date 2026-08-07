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
  it('ofrece TODAS las áreas del club al crear una categoría principal', async () => {
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

  it('el tipo de área se ofrece con nombres legibles, no con la clave cruda', async () => {
    const wrapper = await montar([])

    const nuevaArea = [...document.body.querySelectorAll('button')]
      .find(b => b.textContent.includes('Crear un área'))
    nuevaArea.click()
    await new Promise(r => setTimeout(r, 0))

    const opciones = [...document.body.querySelectorAll('option')].map(o => o.textContent)
    expect(opciones).toContain('Buffet')
    expect(opciones).not.toContain('administracion')
    wrapper.unmount()
  })
})
