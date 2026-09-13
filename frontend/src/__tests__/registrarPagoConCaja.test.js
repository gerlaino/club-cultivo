import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (Germán, sep-2026): registrar el pago de un gasto pendiente pide CÓMO se pagó, CUÁNDO y —en
// efectivo— DE QUÉ CAJA sale la plata. Y esa última pregunta vale para cualquier movimiento nuevo
// en efectivo, y para un ingreso excepcional (a qué caja entra).
const MOSTRADORES = { mostradores: [
  { sede_id: 1, sede: 'Sede Central', turno: { caja_turno_id: 77, desde: '2026-09-12T12:00:00Z', quien: 'Ana' } },
  { sede_id: 2, sede: 'Norte',        turno: null },
  { sede_id: 3, sede: 'Sur',          turno: { caja_turno_id: 78, desde: '2026-09-12T13:00:00Z', quien: null } },
] }
const listMostradores = vi.fn(() => Promise.resolve({ data: MOSTRADORES }))
vi.mock('../lib/api.js', () => ({
  default: { get: vi.fn(), post: vi.fn() },
  listMostradores: (...a) => listMostradores(...a),
  createCategoriaContable: vi.fn(), listGastosRecurrentes: vi.fn(() => Promise.resolve({ data: [] })),
}))

const ModalRegistrarPago = (await import('../components/contabilidad/ModalRegistrarPago.vue')).default
const ModalIngreso       = (await import('../components/contabilidad/ModalIngreso.vue')).default
const { useCajasAbiertas } = await import('../composables/useCajasAbiertas.js')

// `fmtARS` separa el símbolo con un espacio duro.
const plano = (w) => w.text().replace(/\u00a0/g, ' ')

const MOV = { id: 5, descripcion: 'Fertilizante', monto_ars: 15000, fecha: '2026-09-01', tipo: 'egreso',
              sede: { id: 1, nombre: 'Sede Central' }, pagado: false }

describe('useCajasAbiertas', () => {
  it('lista sólo los mostradores con caja abierta, con su sede', async () => {
    const { cajas, cargar, cajaDeSede } = useCajasAbiertas()
    await cargar()
    expect(cajas.value.map(c => c.id)).toEqual([77, 78])
    expect(cajas.value[0].sede).toBe('Sede Central')
    expect(cajaDeSede(1)).toBe(77)
    expect(cajaDeSede(2)).toBeNull()   // Norte no tiene caja abierta
    expect(cajaDeSede(null)).toBeNull()
  })
})

describe('ModalRegistrarPago', () => {
  beforeEach(() => { document.body.innerHTML = ''; vi.clearAllMocks() })

  const montar = async (props = {}) => {
    const w = mount(ModalRegistrarPago, {
      props: { modelValue: false, movimiento: MOV, ...props },
      global: { stubs: { Teleport: true, AppDatePicker: true } },
    })
    await w.setProps({ modelValue: true })
    await flushPromises()
    return w
  }

  it('pregunta cómo, cuándo y de qué caja; la de la sede del gasto viene elegida', async () => {
    const w = await montar()
    const texto = w.text()
    expect(texto).toContain('Cómo se pagó')
    expect(texto).toContain('Cuándo')
    expect(texto).toContain('De qué caja sale')
    expect(w.find('#rp-caja').element.value).toBe('77')
    expect(plano(w)).toContain('Salen $ 15.000 en efectivo de la caja de Sede Central, hoy.')
  })

  it('una transferencia no pasa por ninguna caja', async () => {
    const w = await montar()
    await w.findAll('.rp__seg-b').find(b => b.text() === 'Transferencia').trigger('click')
    expect(w.find('#rp-caja').exists()).toBe(false)
    expect(plano(w)).toContain('Salen $ 15.000 por transferencia, hoy.')

    await w.find('.rp__btn').trigger('click')
    expect(w.emitted('registrar')[0][0]).toEqual({ id: 5, medio_pago: 'transferencia', fecha_pago: expect.any(String), caja_turno_id: undefined })
  })

  it('en efectivo manda la caja elegida, y «de ninguna» lo dice en la oración', async () => {
    const w = await montar()
    await w.find('.rp__btn').trigger('click')
    expect(w.emitted('registrar')[0][0]).toMatchObject({ id: 5, medio_pago: 'efectivo', caja_turno_id: 77 })

    await w.find('#rp-caja').setValue('')   // «De ninguna»
    expect(w.text()).toContain('No entra al arqueo de ningún mostrador.')
    await w.find('.rp__btn').trigger('click')
    expect(w.emitted('registrar')[1][0].caja_turno_id).toBeUndefined()
  })

  it('sin caja abierta no pregunta nada', async () => {
    listMostradores.mockResolvedValueOnce({ data: { mostradores: [] } })
    const w = await montar()
    expect(w.find('#rp-caja').exists()).toBe(false)
    expect(w.text()).not.toContain('De qué caja sale')
  })

  it('un gasto no se pudo pagar antes de comprarse; una cuota sí antes de vencer', async () => {
    const w = await montar()
    w.vm.fechaPago = '2026-08-20'
    await flushPromises()
    expect(w.text()).toContain('no se pudo pagar antes')
    expect(w.find('.rp__btn').attributes('disabled')).toBeDefined()

    const c = await montar({ movimiento: { ...MOV, compra_cuotas_id: 3, cuota_numero: 2, fecha: '2026-12-01' } })
    expect(c.text()).toContain('Cuota 2')
    expect(c.find('.rp__btn').attributes('disabled')).toBeUndefined()
  })
})

describe('ModalIngreso — a qué caja entra', () => {
  beforeEach(() => { document.body.innerHTML = ''; vi.clearAllMocks() })

  const montar = async () => {
    const w = mount(ModalIngreso, {
      props: { modelValue: false, sedes: [{ id: 1, nombre: 'Sede Central' }, { id: 3, nombre: 'Sur' }], unidades: [] },
      global: { stubs: { Teleport: true, AppDatePicker: true } },
    })
    await w.setProps({ modelValue: true })
    await flushPromises()
    return w
  }

  it('pregunta la caja sólo en efectivo, y la manda en el payload', async () => {
    const w = await montar()
    expect(w.find('#mi-caja').exists()).toBe(false)           // arranca en transferencia

    const medio = w.findAll('select').find(s => s.findAll('option').some(o => o.text() === 'Efectivo'))
    await medio.setValue('efectivo')
    expect(w.find('#mi-caja').exists()).toBe(true)

    await w.find('#mi-caja').setValue('78')
    w.vm.form.monto_ars = 5000; w.vm.form.descripcion = 'Municipio'
    await flushPromises()
    await w.find('.mi__btn').trigger('click')
    expect(w.emitted('guardado')[0][0]).toMatchObject({ medio_pago: 'efectivo', caja_turno_id: 78 })
  })
})
