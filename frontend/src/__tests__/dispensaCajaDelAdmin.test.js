import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// A QUÉ CAJA ENTRA EL EFECTIVO CUANDO DISPENSA ADMINISTRACIÓN (decisión de Germán, sep-2026).
//
// Si algo del carrito está sobre una mesa, va a la caja de ese mostrador y no se pregunta. Si todo
// sale del depósito, se elige entre las cajas abiertas — y si no se elige, no entra a ninguna.
// La regla vive en el backend (`Dispensacion#caja_para_cobros`); la pantalla ofrece el selector
// SÓLO cuando aplica, y manda `caja_turno_id` con lo elegido.
const SEDE = { id: 10, nombre: 'Central' }
const DEL_DEPOSITO = { id: 1, cantidad: 300, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 100,
  genetica: { id: 1, nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-05-12', sede: SEDE, en_mostrador: false }
const DE_LA_MESA = { id: 2, cantidad: 120, unidad: 'g', forma_producto: 'hash', precio_sugerido_ars: 200,
  genetica: { id: 2, nombre: 'Critical' }, fecha_elaboracion: '2026-05-12', sede: SEDE, en_mostrador: true }

let mostradores = [
  { sede_id: 10, sede: 'Central', turno: { desde: '2026-09-12T12:00:00Z', quien: 'Ana Pérez', caja_turno_id: 77 } },
  { sede_id: 11, sede: 'Norte',   turno: null },
]
const listMostradores = vi.fn(() => Promise.resolve({ data: { mostradores } }))
const createDispensacion = vi.fn(() => Promise.resolve({ data: { id: 1 } }))

vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [DEL_DEPOSITO, DE_LA_MESA] })),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  listSedes: vi.fn(() => Promise.resolve({ data: [{ id: 10, nombre: 'Central', tipo: 'mixta' }] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: null } })),
  listMostradores: (...a) => listMostradores(...a),
  createDispensacion: (...a) => createDispensacion(...a),
  createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function montar (rol = 'admin') {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 2, role: rol }
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } },
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

async function agregar (w, stock, gramos = 5) {
  w.vm.form.stock_id = stock.id
  w.vm.form.cantidad = gramos
  await w.vm.$nextTick()
  w.vm.agregarItem()
  await w.vm.$nextTick()
}

const selector = (w) => w.findAll('select').find(s => s.text().includes('no entra a ningún mostrador'))

describe('Dispensar — a qué caja entra el efectivo del admin', () => {
  beforeEach(() => { vi.clearAllMocks() })

  it('con todo del depósito y efectivo, ofrece las cajas abiertas; «ninguna» es el valor inicial', async () => {
    const w = await montar()
    await agregar(w, DEL_DEPOSITO)

    const sel = selector(w)
    expect(sel).toBeTruthy()
    const opciones = sel.findAll('option').map(o => o.text())
    expect(opciones).toHaveLength(2)                       // ninguna + Central (Norte no tiene caja)
    expect(opciones[1]).toContain('Caja de Central')
    expect(opciones[1]).toContain('Ana Pérez')
    expect(w.vm.cajaElegida).toBeNull()
  })

  it('manda la caja elegida; sin elegir no manda nada', async () => {
    const w = await montar()
    await agregar(w, DEL_DEPOSITO)
    await selector(w).setValue('77')
    await w.vm.handleSubmit()
    expect(createDispensacion.mock.calls[0][1].caja_turno_id).toBe(77)

    createDispensacion.mockClear()
    const w2 = await montar()
    await agregar(w2, DEL_DEPOSITO)
    await w2.vm.handleSubmit()
    expect(createDispensacion.mock.calls[0][1].caja_turno_id).toBeUndefined()
  })

  it('con algo de la mesa no pregunta: cae en la caja de ese mostrador', async () => {
    const w = await montar()
    await agregar(w, DE_LA_MESA)
    expect(selector(w)).toBeUndefined()
    await agregar(w, DEL_DEPOSITO)   // mezcla: la mesa manda igual
    expect(selector(w)).toBeUndefined()
  })

  it('no pregunta si no se cobra en efectivo, ni a quien atiende', async () => {
    const w = await montar()
    await agregar(w, DEL_DEPOSITO)
    w.vm.form.medio_pago = 'transferencia'
    await w.vm.$nextTick()
    expect(selector(w)).toBeUndefined()

    const w2 = await montar('dispensador')
    expect(listMostradores).toHaveBeenCalledTimes(1)      // sólo lo pidió el admin
    await agregar(w2, DEL_DEPOSITO)
    expect(selector(w2)).toBeUndefined()
  })
})
