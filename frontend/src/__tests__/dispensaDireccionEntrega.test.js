import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (socio de Germán, 16-sep-2026, primer reparto de Mitocondria ONG): al dispensar con envío,
// la dirección elegida SE VE, y si el paciente tiene dos (domicilio REPROCANN y envío) las dos
// se pueden elegir. Antes «Domicilio del paciente» no mostraba nada y, con las dos cargadas, el
// backend mandaba a la de envío sin decirlo.
const SEDE = { id: 10, nombre: 'Central' }
const STOCK = {
  id: 1, cantidad: 500, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 100,
  genetica: { id: 1, nombre: 'Lemon Cookie' }, sede: SEDE,
}
// Desde el 17-sep las direcciones de entrega son VARIAS (`guardadas`), con nombre y una por defecto.
const TRABAJO = { id: 41, etiqueta: 'Trabajo', texto: 'Lavalle 400, CABA', por_defecto: true }
let direcciones = {
  domicilio: { origen: 'domicilio', label: 'Domicilio REPROCANN', texto: 'Av. Siempreviva 742, Palermo, CABA' },
  guardadas: [TRABAJO],
}
const getDireccionesPaciente = vi.fn(() => Promise.resolve({ data: direcciones }))
const createDispensacion = vi.fn(() => Promise.resolve({ data: { id: 99 } }))
vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [STOCK] })),
  createDispensacion: (...a) => createDispensacion(...a),
  getDireccionesPaciente: (...a) => getDireccionesPaciente(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [{ id: 7, nombre: 'Repartidor' }] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
const PACIENTE = { id: 5, nombre_completo: 'Augusto Test' }

async function montar () {
  setActivePinia(createPinia())
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id, limiteCc: 0, saldoCc: 0 },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
  })
  await flushPromises()
  w.vm.form.stock_id = STOCK.id
  w.vm.form.cantidad = 50
  await w.vm.$nextTick()
  w.vm.agregarItem()
  w.vm.form.con_envio = true
  w.vm.form.delivery_id = 7
  // El valor del envío es obligatorio (23-sep-2026): bonificado, que acá no es lo que se prueba.
  w.vm.form.costo_envio = 0
  w.vm.form.contacto_nombre = 'Augusto'
  await flushPromises()
  return w
}

const tarjetas = (w) => w.findAll('.sde__dir')

describe('Dispensar con envío — a dónde va', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    direcciones = {
      domicilio: { origen: 'domicilio', label: 'Domicilio REPROCANN', texto: 'Av. Siempreviva 742, Palermo, CABA' },
      guardadas: [TRABAJO],
    }
  })

  it('al prender el envío pide las direcciones y las muestra CON EL TEXTO', async () => {
    const w = await montar()

    expect(getDireccionesPaciente).toHaveBeenCalledWith(5)
    const t = w.text()
    expect(t).toContain('Domicilio REPROCANN')
    expect(t).toContain('Av. Siempreviva 742, Palermo, CABA')
    expect(t).toContain('Trabajo')
    expect(t).toContain('Lavalle 400, CABA')
    expect(t).toContain('por defecto')
    expect(t).toContain('Otra dirección')
  })

  it('arranca en la guardada por defecto, y se puede elegir el domicilio', async () => {
    const w = await montar()
    expect(w.vm.form.direccion_origen).toBe('41')

    await tarjetas(w)[0].trigger('click')
    expect(w.vm.form.direccion_origen).toBe('domicilio')

    await w.vm.handleSubmit()
    await flushPromises()
    const payload = createDispensacion.mock.calls[0][1]
    expect(payload.direccion_origen).toBe('domicilio')
    expect(payload.usar_domicilio_paciente).toBeUndefined()
  })

  it('sin guardadas arranca en el domicilio, y sólo hay domicilio y «otra»', async () => {
    direcciones = { domicilio: direcciones.domicilio, guardadas: [] }
    const w = await montar()

    expect(w.vm.form.direccion_origen).toBe('domicilio')
    expect(tarjetas(w)).toHaveLength(2)
  })

  it('sin domicilio ni guardadas, el domicilio se ve apagado y dice por qué', async () => {
    direcciones = { domicilio: null, guardadas: [TRABAJO] }
    const w = await montar()

    const dom = tarjetas(w)[0]
    expect(dom.attributes('disabled')).toBeDefined()
    expect(dom.text()).toContain('No está cargada en la ficha')
  })

  it('con varias guardadas se listan todas, la por defecto marcada', async () => {
    direcciones = { domicilio: null, guardadas: [TRABAJO, { id: 42, etiqueta: 'Casa de la madre', texto: 'Directorio 1602, CABA', por_defecto: false }] }
    const w = await montar()

    expect(tarjetas(w)).toHaveLength(4)   // domicilio (apagado) + 2 guardadas + otra
    expect(w.vm.form.direccion_origen).toBe('41')
    await tarjetas(w)[2].trigger('click')
    expect(w.vm.form.direccion_origen).toBe('42')
  })

  it('sin ninguna cargada arranca en «otra»', async () => {
    direcciones = { domicilio: null, guardadas: [] }
    const w = await montar()

    expect(w.vm.form.direccion_origen).toBe('otra')
    expect(w.find('input[placeholder="Av. Siempreviva"]').exists()).toBe(true)
  })

  it('«otra» exige calle, altura y ciudad antes de mandar', async () => {
    const w = await montar()
    await tarjetas(w).at(-1).trigger('click')
    w.vm.form.envio_calle = 'Corrientes'
    await w.vm.handleSubmit()

    expect(createDispensacion).not.toHaveBeenCalled()
    expect(w.vm.formError).toContain('calle, altura y ciudad')
  })

  it('«otra» con nombre y «guardar en la ficha» lo manda para que la próxima aparezca como tarjeta', async () => {
    const w = await montar()
    await tarjetas(w).at(-1).trigger('click')
    w.vm.form.envio_calle = 'Corrientes'; w.vm.form.envio_altura = '1000'; w.vm.form.envio_ciudad = 'CABA'
    w.vm.form.envio_etiqueta = 'Trabajo'
    w.vm.form.guardar_como_envio = true
    await w.vm.handleSubmit()
    await flushPromises()

    const payload = createDispensacion.mock.calls[0][1]
    expect(payload.direccion_origen).toBe('otra')
    expect(payload.guardar_como_envio).toBe(true)
    expect(payload.envio_calle).toBe('Corrientes')
    expect(payload.envio_etiqueta).toBe('Trabajo')
  })

  it('la tarjeta de una guardada lleva el nombre que le puso el paciente', async () => {
    const w = await montar()

    expect(tarjetas(w)[1].text()).toContain('Trabajo')
    expect(tarjetas(w)[1].text()).toContain('Lavalle 400, CABA')
  })

  it('el tilde de guardar no viaja si se eligió una de la ficha', async () => {
    const w = await montar()
    w.vm.form.guardar_como_envio = true
    await w.vm.handleSubmit()
    await flushPromises()

    expect(createDispensacion.mock.calls[0][1].guardar_como_envio).toBe(false)
  })
})
