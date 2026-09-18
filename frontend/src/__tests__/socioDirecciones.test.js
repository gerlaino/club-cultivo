import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (Germán, 17-sep-2026): en la ficha del paciente, una solapa Direcciones: ver todas las
// guardadas, agregar más, e indicar una por defecto para que quede preseleccionada al dispensar.
let datos = {
  domicilio: { texto: 'Av. Siempreviva 742, CABA' },
  guardadas: [
    { id: 41, etiqueta: 'Trabajo', texto: 'Lavalle 400, CABA', por_defecto: true, calle: 'Lavalle', altura: '400', ciudad: 'CABA' },
    { id: 42, etiqueta: 'Casa de la madre', texto: 'Directorio 1602, CABA', por_defecto: false, calle: 'Directorio', altura: '1602', ciudad: 'CABA' },
  ],
}
const crear = vi.fn(() => Promise.resolve({ data: {} }))
const editar = vi.fn(() => Promise.resolve({ data: {} }))
const borrar = vi.fn(() => Promise.resolve({}))
const porDefecto = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({
  getDireccionesPaciente:  vi.fn(() => Promise.resolve({ data: datos })),
  crearDireccionPaciente:  (...a) => crear(...a),
  editarDireccionPaciente: (...a) => editar(...a),
  borrarDireccionPaciente: (...a) => borrar(...a),
  direccionPorDefecto:     (...a) => porDefecto(...a),
}))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }) }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))

async function montar () {
  const { default: Tab } = await import('../components/pacientes/SocioTabDirecciones.vue')
  const w = mount(Tab, { props: { socioId: 5 } })
  await flushPromises()
  return w
}

describe('Solapa Direcciones', () => {
  beforeEach(() => vi.clearAllMocks())

  it('muestra el domicilio REPROCANN y todas las guardadas, marcando la por defecto', async () => {
    const w = await montar()
    const t = w.text()

    expect(t).toContain('Av. Siempreviva 742, CABA')
    expect(t).toContain('Trabajo')
    expect(t).toContain('Casa de la madre')
    expect(w.findAll('.std__item')).toHaveLength(2)
    expect(w.find('.std__item--def').text()).toContain('Trabajo')
  })

  it('«Usar por defecto» sólo en las que no lo son, y lo manda', async () => {
    const w = await montar()
    const botones = w.findAll('button').filter(b => b.text().includes('Usar por defecto'))
    expect(botones).toHaveLength(1)

    await botones[0].trigger('click')
    await flushPromises()
    expect(porDefecto).toHaveBeenCalledWith(5, 42)
  })

  it('agrega una con nombre; sin calle, altura y ciudad no manda', async () => {
    const w = await montar()
    await w.findAll('button').find(b => b.text().includes('Agregar')).trigger('click')
    w.vm.form.etiqueta = 'Club'
    w.vm.form.calle = 'Corrientes'
    await w.find('form').trigger('submit')
    expect(crear).not.toHaveBeenCalled()
    expect(w.text()).toContain('Completá calle, altura y ciudad')

    w.vm.form.altura = '1000'; w.vm.form.ciudad = 'CABA'
    await w.find('form').trigger('submit')
    await flushPromises()
    expect(crear).toHaveBeenCalledWith(5, expect.objectContaining({ etiqueta: 'Club', calle: 'Corrientes', altura: '1000', ciudad: 'CABA' }))
  })

  it('la primera que se agrega nace por defecto', async () => {
    datos = { domicilio: null, guardadas: [] }
    const w = await montar()
    await w.findAll('button').find(b => b.text().includes('Agregar')).trigger('click')

    expect(w.vm.form.por_defecto).toBe(true)
  })

  it('corrige y borra', async () => {
    datos = { domicilio: null, guardadas: [{ id: 41, etiqueta: 'Trabajo', texto: 'Lavalle 400, CABA', por_defecto: true, calle: 'Lavalle', altura: '400', ciudad: 'CABA' }] }
    const w = await montar()

    await w.find('button[title="Corregir"]').trigger('click')
    expect(w.vm.form.id).toBe(41)
    w.vm.form.piso = '3'
    await w.find('form').trigger('submit')
    await flushPromises()
    expect(editar).toHaveBeenCalledWith(5, 41, expect.objectContaining({ piso: '3' }))

    await w.find('button[title="Borrar"]').trigger('click')
    await flushPromises()
    expect(borrar).toHaveBeenCalledWith(5, 41)
  })
})
