import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// Quien atiende más de una sede no puede leer una lista con las reservas de dos mostradores
// mezcladas: la de la otra sede no la va a entregar él. Con una sola sede no se agrupa nada —
// un encabezado que siempre dice lo mismo es ruido.
const reserva = (id, sede) => ({
  id, estado: 'pendiente', cantidad: 10, sena_ars: 0, aporte_restante_ars: 500,
  fecha_entrega_estimada: '2026-08-20',
  paciente: { id: id * 10, nombre: `Paciente ${id}` },
  stock: { id, forma_producto: 'flor_seca', unidad: 'g', sede },
})

const NORTE = { id: 10, nombre: 'Finca Norte' }
const SUR   = { id: 20, nombre: 'Finca Sur' }

const listReservas = vi.fn()
vi.mock('../lib/api.js', () => ({
  listReservas: (...a) => listReservas(...a),
  entregarReserva: vi.fn(), cancelarReserva: vi.fn(), deleteReserva: vi.fn(),
  updateReserva: vi.fn(), anularSenaReserva: vi.fn(), listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))

async function montar(reservas) {
  listReservas.mockResolvedValue({ data: { reservas } })
  setActivePinia(createPinia())
  const { default: Vista } = await import('../views/ReservasView.vue')
  const w = mount(Vista, { global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true, RouterLink: true } } })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

describe('Reservas agrupadas por sede', () => {
  beforeEach(() => vi.clearAllMocks())

  it('con dos sedes, arma un grupo por cada una', async () => {
    const w = await montar([reserva(1, NORTE), reserva(2, SUR), reserva(3, NORTE)])

    expect(w.vm.agruparPorSede).toBe(true)
    expect(w.vm.gruposPorSede.map((g) => g.nombre)).toEqual(['Finca Norte', 'Finca Sur'])
    expect(w.vm.gruposPorSede[0].reservas).toHaveLength(2)
  })

  it('pinta el encabezado de cada sede con su cantidad', async () => {
    const w = await montar([reserva(1, NORTE), reserva(2, SUR)])
    const filas = w.findAll('.rsv__sede-row')

    expect(filas).toHaveLength(2)
    expect(filas[0].text()).toContain('Finca Norte')
    expect(filas[0].find('.rsv__sede-n').text()).toBe('1')
  })

  it('con una sola sede no agrupa: el encabezado sería siempre el mismo', async () => {
    const w = await montar([reserva(1, NORTE), reserva(2, NORTE)])

    expect(w.vm.agruparPorSede).toBe(false)
    expect(w.findAll('.rsv__sede-row')).toHaveLength(0)
  })

  it('no se pierde ninguna reserva al agrupar', async () => {
    const w = await montar([reserva(1, NORTE), reserva(2, SUR), reserva(3, null)])

    const total = w.vm.gruposPorSede.reduce((n, g) => n + g.reservas.length, 0)
    expect(total).toBe(3)
  })

  it('las que no tienen sede van al final, en su propio grupo', async () => {
    const w = await montar([reserva(1, null), reserva(2, NORTE)])

    expect(w.vm.gruposPorSede.at(-1).nombre).toBe('Sin sede (club)')
  })
})
