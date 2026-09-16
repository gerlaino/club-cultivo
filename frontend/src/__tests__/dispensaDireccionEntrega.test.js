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
let direcciones = {
  domicilio: { origen: 'domicilio', label: 'Domicilio REPROCANN', texto: 'Av. Siempreviva 742, Palermo, CABA' },
  envio:     { origen: 'envio',     label: 'Dirección de envío',  texto: 'Lavalle 400, CABA' },
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
      envio:     { origen: 'envio',     label: 'Dirección de envío',  texto: 'Lavalle 400, CABA' },
    }
  })

  it('al prender el envío pide las direcciones y las muestra CON EL TEXTO', async () => {
    const w = await montar()

    expect(getDireccionesPaciente).toHaveBeenCalledWith(5)
    const t = w.text()
    expect(t).toContain('Domicilio REPROCANN')
    expect(t).toContain('Av. Siempreviva 742, Palermo, CABA')
    expect(t).toContain('Dirección de envío')
    expect(t).toContain('Lavalle 400, CABA')
    expect(t).toContain('Otra dirección')
  })

  it('con las dos cargadas arranca en la de envío, y se puede elegir el domicilio', async () => {
    const w = await montar()
    expect(w.vm.form.direccion_origen).toBe('envio')

    await tarjetas(w)[0].trigger('click')
    expect(w.vm.form.direccion_origen).toBe('domicilio')

    await w.vm.handleSubmit()
    await flushPromises()
    const payload = createDispensacion.mock.calls[0][1]
    expect(payload.direccion_origen).toBe('domicilio')
    expect(payload.usar_domicilio_paciente).toBeUndefined()
  })

  it('sin dirección de envío cargada arranca en el domicilio, y la de envío no se puede elegir', async () => {
    direcciones = { domicilio: direcciones.domicilio, envio: null }
    const w = await montar()

    expect(w.vm.form.direccion_origen).toBe('domicilio')
    const envio = tarjetas(w)[1]
    expect(envio.attributes('disabled')).toBeDefined()
    expect(envio.text()).toContain('No está cargada en la ficha')
  })

  it('sin ninguna cargada arranca en «otra»', async () => {
    direcciones = { domicilio: null, envio: null }
    const w = await montar()

    expect(w.vm.form.direccion_origen).toBe('otra')
    expect(w.find('input[placeholder="Av. Siempreviva"]').exists()).toBe(true)
  })

  it('«otra» exige calle, altura y ciudad antes de mandar', async () => {
    const w = await montar()
    await tarjetas(w)[2].trigger('click')
    w.vm.form.envio_calle = 'Corrientes'
    await w.vm.handleSubmit()

    expect(createDispensacion).not.toHaveBeenCalled()
    expect(w.vm.formError).toContain('calle, altura y ciudad')
  })

  it('«otra» con nombre y «guardar en la ficha» lo manda para que la próxima aparezca como tarjeta', async () => {
    const w = await montar()
    await tarjetas(w)[2].trigger('click')
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

  it('la tarjeta de envío lleva el nombre que le puso el paciente', async () => {
    direcciones = { ...direcciones, envio: { ...direcciones.envio, etiqueta: 'Trabajo' } }
    const w = await montar()

    expect(tarjetas(w)[1].text()).toContain('Dirección de envío · Trabajo')
  })

  it('el tilde de guardar no viaja si se eligió una de la ficha', async () => {
    const w = await montar()
    w.vm.form.guardar_como_envio = true
    await w.vm.handleSubmit()
    await flushPromises()

    expect(createDispensacion.mock.calls[0][1].guardar_como_envio).toBe(false)
  })
})
