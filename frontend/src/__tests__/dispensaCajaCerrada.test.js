import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// DISPENSAR CON LA CAJA CERRADA: que se sepa ANTES, no al confirmar.
//
// La mesa es permanente —el producto está arriba con la caja abierta y con la caja cerrada—, así
// que el carrito se llenaba igual: elegía el frasco, la cantidad, el medio de pago, confirmaba…
// y recién ahí el backend contestaba "la caja del mostrador está cerrada", con el paciente
// enfrente. Es el peor error posible: parece culpa del usuario.
//
// La regla sigue viviendo entera en el backend (`Dispensacion#mostrador_abierto`). Acá sólo se
// mira el estado para no ofrecer un camino que termina en un 422.
const UNA_SEDE = { id: 10, nombre: 'Central' }
const STOCKS = [
  { id: 1, cantidad: 300, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
    genetica: { id: 1, nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-05-12', sede: UNA_SEDE },
]

let mostrador = { mesa: [], turno: null }
const getMostrador = vi.fn(() => Promise.resolve({ data: mostrador }))

vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: STOCKS })),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: (...a) => getMostrador(...a),
  createDispensacion: vi.fn(), createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function montar ({ rol = 'dispensador', sede = UNA_SEDE } = {}) {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 2, role: rol, dispensario_sede: sede }

  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id },
    global: {
      stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true,
               RouterLink: { template: '<a><slot/></a>' } },
    },
  })
  for (let i = 0; i < 6; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

beforeEach(() => { vi.clearAllMocks(); mostrador = { mesa: [], turno: null } })

describe('el carrito de quien atiende el mostrador', () => {
  it('con la caja cerrada lo dice arriba, antes de elegir nada', async () => {
    const w = await montar()

    expect(getMostrador).toHaveBeenCalledWith(10)
    const aviso = w.find('.mnd__caja-box')
    expect(aviso.exists()).toBe(true)
    expect(aviso.text()).toContain('La caja del mostrador está cerrada')
    // Y dice DÓNDE se arregla: un aviso sin salida obliga a preguntarle a alguien.
    expect(aviso.text()).toContain('Mostrador')
  })

  // Dejar apretar para que el backend rebote es el peor error posible.
  it('y no deja confirmar', async () => {
    const w = await montar()

    expect(w.find('.mnd__btn-primary').attributes('disabled')).toBeDefined()
  })

  it('con la caja abierta no molesta con nada', async () => {
    mostrador = { mesa: [{ stock_id: 1, mostrador: 300 }], turno: { id: 7 } }
    const w = await montar()

    expect(w.find('.mnd__caja-box').exists()).toBe(false)
  })

  // Administración dispensa del depósito entero, con o sin turno abierto: preguntarle por una
  // caja que no la gobierna sería trabarle el trabajo por una regla que no es suya.
  it('a administración no se le pregunta por la caja', async () => {
    const w = await montar({ rol: 'admin' })

    expect(getMostrador).not.toHaveBeenCalled()
    expect(w.find('.mnd__caja-box').exists()).toBe(false)
  })

  // Una organización sin mostrador (sede de producción, o el dispensador sin sede asignada) no
  // tiene caja que consultar: bloquear ahí sería inventar un candado que el backend no tiene.
  it('sin sede de mostrador tampoco', async () => {
    const w = await montar({ sede: null })

    expect(getMostrador).not.toHaveBeenCalled()
    expect(w.find('.mnd__caja-box').exists()).toBe(false)
  })

  // Si la consulta falla, el backend sigue siendo el que decide: trabar la dispensa por un
  // request que no salió es peor que dejar que rebote.
  it('si no se pudo preguntar, no traba', async () => {
    getMostrador.mockRejectedValueOnce(new Error('sin red'))
    const w = await montar()

    expect(w.find('.mnd__caja-box').exists()).toBe(false)
  })
})
