import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 25-sep-2026, «Mis nutrientes»): «¿cómo hago para editar o eliminar un producto?».
// Acordado: editar (nombre, unidad sólo sin movimientos, aviso de poco), corregir la cantidad con
// motivo, y eliminar; si ya se usó o está en una receta no se borra y se ofrece archivar.
const api = vi.hoisted(() => ({
  listInsumos: vi.fn(), updateInsumo: vi.fn(), reconteoInsumo: vi.fn(), deleteInsumo: vi.fn(),
}))
vi.mock('../lib/api.js', () => ({
  listRecetas: vi.fn(() => Promise.resolve({ data: [] })),
  getReceta: vi.fn(), createReceta: vi.fn(), updateReceta: vi.fn(), createInsumo: vi.fn(), comprarInsumo: vi.fn(),
  listInsumos: (...a) => api.listInsumos(...a),
  updateInsumo: (...a) => api.updateInsumo(...a),
  reconteoInsumo: (...a) => api.reconteoInsumo(...a),
  deleteInsumo: (...a) => api.deleteInsumo(...a),
}))
const confirmar = vi.hoisted(() => ({ respuestas: [] }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(confirmar.respuestas.shift())) }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../composables/useUsoPersonal.js', () => ({ useUsoPersonal: () => ({ esPersonal: { value: true } }) }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: vi.fn() }))

const BASE_A = { id: 3, nombre: 'Base A', unidad_medida: 'mililitro', stock_actual: 10000, stock_minimo: 0, con_movimientos: true }

async function montar(insumo = BASE_A) {
  api.listInsumos.mockResolvedValue({ data: [insumo] })
  setActivePinia(createPinia())
  const V = (await import('../views/RecetasView.vue')).default
  const w = mount(V, { global: { stubs: { teleport: true, RouterLink: true }, directives: { modal: {} } }, attachTo: document.body })
  await flushPromises()
  return w
}
const boton = (w, titulo) => w.find(`.rc__nutriente button[title="${titulo}"]`)

describe('Mis nutrientes: editar, corregir, eliminar', () => {
  beforeEach(() => { Object.values(api).forEach(f => f.mockReset()); confirmar.respuestas = [] })

  it('cada nutriente tiene Editar, Corregir cantidad y Eliminar', async () => {
    const w = await montar()
    for (const t of ['Editar', 'Corregir cantidad', 'Eliminar']) expect(boton(w, t).exists()).toBe(true)
  })

  it('con compras o riegos la unidad no se ofrece para cambiar', async () => {
    const w = await montar()
    await boton(w, 'Editar').trigger('click')

    expect(w.find('select.rc__input').attributes('disabled')).toBeDefined()
    expect(w.text()).toContain('No se puede cambiar')
  })

  it('editar guarda nombre y aviso, sin mandar la unidad si tiene movimientos', async () => {
    api.updateInsumo.mockResolvedValue({ data: {} })
    const w = await montar()
    await boton(w, 'Editar').trigger('click')
    const [nombre] = w.findAll('.rc__modal input')
    await nombre.setValue('Base A (Canna)')

    await w.findAll('.rc__modal-foot .rc__btn-primary').at(-1).trigger('click')
    await flushPromises()

    expect(api.updateInsumo).toHaveBeenCalledWith(3, { nombre: 'Base A (Canna)', stock_minimo: 0 })
  })

  it('corregir la cantidad por derrame no deja subir', async () => {
    const w = await montar()
    await boton(w, 'Corregir cantidad').trigger('click')
    await w.find('input[value="merma"]').setValue(true)
    await w.find('.rc__modal input[type="number"]').setValue(12000)

    expect(w.text()).toContain('no es una pérdida')
    expect(w.findAll('.rc__modal-foot .rc__btn-primary').at(-1).attributes('disabled')).toBeDefined()
  })

  it('corregir por error de carga manda el reconteo con motivo', async () => {
    api.reconteoInsumo.mockResolvedValue({ data: {} })
    const w = await montar()
    await boton(w, 'Corregir cantidad').trigger('click')
    await w.find('.rc__modal input[type="number"]').setValue(8000)

    await w.findAll('.rc__modal-foot .rc__btn-primary').at(-1).trigger('click')
    await flushPromises()

    expect(api.reconteoInsumo).toHaveBeenCalledWith(3, { nuevo_stock: 8000, motivo: 'correccion' })
  })

  it('si está en una receta no se borra: ofrece archivar y archiva', async () => {
    api.deleteInsumo.mockRejectedValue({ response: { status: 422, data: { error: 'Está en la receta «Vege 2».', puede_archivar: true } } })
    api.updateInsumo.mockResolvedValue({ data: {} })
    confirmar.respuestas = [true, true]
    const w = await montar()

    await boton(w, 'Eliminar').trigger('click')
    await flushPromises()

    expect(api.updateInsumo).toHaveBeenCalledWith(3, { activo: false })
  })

  it('uno sin uso se elimina', async () => {
    api.deleteInsumo.mockResolvedValue({})
    confirmar.respuestas = [true]
    const w = await montar({ ...BASE_A, con_movimientos: false })

    await boton(w, 'Eliminar').trigger('click')
    await flushPromises()

    expect(api.deleteInsumo).toHaveBeenCalledWith(3)
    expect(api.updateInsumo).not.toHaveBeenCalled()
  })
})

// AC (Germán, 25-sep-2026): «agregá una solapa para ver los archivados y volverlos a activar».
describe('Mis nutrientes: archivados', () => {
  const ARCHIVADO = { id: 9, nombre: 'Flora vieja', unidad_medida: 'mililitro', stock_actual: 250, activo: false, con_movimientos: true }

  beforeEach(() => { Object.values(api).forEach(f => f.mockReset()) })

  async function montarCon(lista) {
    api.listInsumos.mockResolvedValue({ data: lista })
    setActivePinia(createPinia())
    const V = (await import('../views/RecetasView.vue')).default
    const w = mount(V, { global: { stubs: { teleport: true, RouterLink: true }, directives: { modal: {} } }, attachTo: document.body })
    await flushPromises()
    return w
  }

  it('en uso no muestra los archivados; su solapa sí, con cuántos hay', async () => {
    const w = await montarCon([{ ...BASE_A, activo: true }, ARCHIVADO])

    expect(w.findAll('.rc__nutriente').map(n => n.text()).join()).not.toContain('Flora vieja')
    expect(w.findAll('.rc__tab')[1].text()).toContain('1')

    await w.findAll('.rc__tab')[1].trigger('click')
    expect(w.find('.rc__nutriente--archivado').text()).toContain('Flora vieja')
  })

  it('«Reactivar» lo vuelve a poner en uso', async () => {
    api.updateInsumo.mockResolvedValue({ data: {} })
    const w = await montarCon([{ ...BASE_A, activo: true }, ARCHIVADO])
    await w.findAll('.rc__tab')[1].trigger('click')

    await w.find('.rc__nutriente--archivado button').trigger('click')
    await flushPromises()

    expect(api.updateInsumo).toHaveBeenCalledWith(9, { activo: true })
  })

  it('una receta nueva no ofrece los archivados', async () => {
    const w = await montarCon([{ ...BASE_A, activo: true }, ARCHIVADO])
    await w.find('.rc__head .rc__btn-primary').trigger('click')

    const opciones = w.findAll('.rc__item-row option').map(o => o.text())
    expect(opciones.join()).toContain('Base A')
    expect(opciones.join()).not.toContain('Flora vieja')
  })
})
