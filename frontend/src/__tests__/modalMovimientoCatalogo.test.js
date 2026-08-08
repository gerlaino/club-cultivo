import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// Crear una categoría o un área desde el alta de movimiento pide el MISMO permiso que crear el
// movimiento (admin), así que se hace sin salir del modal. Lo que sí tiene reglas es QUÉ se puede
// crear: solo subcategorías, porque heredan de la madre el área, la clave y el comportamiento —el
// que decide si la compra entra al depósito o al salón—. Estos tests fijan esas reglas.

const createCategoriaContable = vi.fn()
const createUnidadNegocio     = vi.fn()

vi.mock('../lib/api.js', () => ({
  createCategoriaContable: (...a) => createCategoriaContable(...a),
  createUnidadNegocio:     (...a) => createUnidadNegocio(...a),
}))

const ModalMovimiento = (await import('../components/contabilidad/ModalMovimiento.vue')).default

// Árbol como lo devuelve el back: madres con subcategorías anidadas.
const CATEGORIAS = [
  {
    id: 1, nombre: 'Insumos', tipo: 'egreso', clave_efectiva: 'insumo',
    unidad_negocio: { id: 10, nombre: 'Cultivo' },
    subcategorias: [{ id: 11, nombre: 'Sustrato', tipo: 'egreso', clave_efectiva: 'insumo', unidad_negocio: null }],
  },
  { id: 2, nombre: 'Servicios', tipo: 'egreso', clave_efectiva: null, unidad_negocio: null, subcategorias: [] },
  { id: 3, nombre: 'Aportes', tipo: 'ingreso', clave_efectiva: 'aporte_socio', unidad_negocio: null, subcategorias: [] },
]

function montar() {
  return mount(ModalMovimiento, {
    props: {
      modelValue: true,
      categorias: CATEGORIAS,
      unidades: [{ id: 10, nombre: 'Cultivo' }],
      sedes: [], depositos: [], insumos: [], bares: [], pacientes: [],
    },
    global: { stubs: { Teleport: true, Transition: false, AppDatePicker: true, DestinoStock: true } },
  })
}

// Entra al formulario de un flujo (los flujos viven en movimientoFlows.js).
async function irAlForm(wrapper, key = 'gasto') {
  wrapper.vm.elegirFlujo(key)
  await wrapper.vm.$nextTick()
  return wrapper
}

describe('crear categoría desde el alta de movimiento', () => {
  beforeEach(() => { createCategoriaContable.mockReset(); createUnidadNegocio.mockReset() })

  it('solo ofrece como madre las familias del tipo del movimiento', async () => {
    const w = await irAlForm(montar(), 'gasto')          // egreso
    expect(w.vm.madresDelTipo.map(m => m.nombre)).toEqual(['Insumos', 'Servicios'])
    expect(w.vm.madresDelTipo.some(m => m.nombre === 'Aportes')).toBe(false)
  })

  it('propone el nombre que venías escribiendo en el buscador', async () => {
    const w = await irAlForm(montar(), 'gasto')
    w.vm.catQuery = 'Bebidas'
    w.vm.abrirCrearCat()
    expect(w.vm.crearCat.nombre).toBe('Bebidas')
    // Arranca como CATEGORÍA. Antes se preseleccionaba la primera madre del tipo, o sea que
    // el formulario decidía por vos que estabas creando una subcategoría de algo que ni
    // elegiste — y con una sola madre en la lista parecía que no había alternativa.
    expect(w.vm.crearCat.parent_id).toBeNull()
  })

  it('la crea como subcategoría cuando lo elegís, y la deja elegida', async () => {
    createCategoriaContable.mockResolvedValue({
      data: { id: 99, nombre: 'Bebidas', tipo: 'egreso', clave_efectiva: 'insumo', unidad_negocio: { id: 10 } },
    })
    const w = await irAlForm(montar(), 'gasto')
    w.vm.catQuery = 'Bebidas'
    w.vm.abrirCrearCat()
    w.vm.crearCat.parent_id = 1          // el usuario elige "Una subcategoría" → de Insumos
    await w.vm.confirmarCrearCat()

    expect(createCategoriaContable).toHaveBeenCalledWith({ nombre: 'Bebidas', tipo: 'egreso', parent_id: 1 })
    // Queda seleccionada sin esperar a que el padre refresque el catálogo.
    expect(w.vm.form.categoria_contable_id).toBe(99)
    expect(w.vm.catsSelectables.find(c => c.id === 99)?.label).toBe('Insumos › Bebidas')
    expect(w.vm.crearCat).toBe(null)
    expect(w.emitted('catalogo-actualizado')).toHaveLength(1)
  })

  it('sin nombre no llama a la API y avisa', async () => {
    const w = await irAlForm(montar(), 'gasto')
    w.vm.abrirCrearCat()
    w.vm.crearCat.nombre = '   '
    await w.vm.confirmarCrearCat()
    expect(createCategoriaContable).not.toHaveBeenCalled()
    expect(w.vm.errorCrear).toBeTruthy()
  })

  it('si el back rechaza, muestra el error y no la da por creada', async () => {
    createCategoriaContable.mockRejectedValue({ response: { data: { errors: ['Nombre ya está en uso'] } } })
    const w = await irAlForm(montar(), 'gasto')
    w.vm.catQuery = 'Insumos'
    w.vm.abrirCrearCat()
    await w.vm.confirmarCrearCat()

    expect(w.vm.errorCrear).toBe('Nombre ya está en uso')
    expect(w.vm.crearCat).not.toBe(null)     // el formulario sigue abierto para corregir
    expect(w.vm.form.categoria_contable_id).toBe(null)
    expect(w.emitted('catalogo-actualizado')).toBeUndefined()
  })
})

describe('crear área desde el alta de movimiento', () => {
  beforeEach(() => { createUnidadNegocio.mockReset() })

  it('la crea y la deja elegida', async () => {
    createUnidadNegocio.mockResolvedValue({ data: { id: 77, nombre: 'Eventos', tipo: 'social' } })
    const w = await irAlForm(montar(), 'gasto')
    w.vm.abrirCrearArea()
    w.vm.crearArea.nombre = 'Eventos'
    w.vm.crearArea.tipo   = 'social'
    await w.vm.confirmarCrearArea()

    expect(createUnidadNegocio).toHaveBeenCalledWith({ nombre: 'Eventos', tipo: 'social' })
    expect(w.vm.form.unidad_negocio_id).toBe(77)
    expect(w.vm.areasDisponibles.map(u => u.nombre)).toEqual(['Cultivo', 'Eventos'])
    expect(w.emitted('catalogo-actualizado')).toHaveLength(1)
  })

  // El área SÍ tiene tipo obligatorio en el back (UnidadNegocio valida presence), por eso el
  // formulario arranca con uno puesto en vez de dejarlo vacío y comerse un 422.
  it('arranca con un tipo válido puesto', async () => {
    const w = await irAlForm(montar(), 'gasto')
    w.vm.abrirCrearArea()
    expect(w.vm.AREA_TIPOS.map(t => t.value)).toContain(w.vm.crearArea.tipo)
  })
})
