import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán): "hay que aplicar todo a la PWA ya que probablemente se use una tablet".
//
// La caja va en la pantalla donde el dispensador ATERRIZA en la PWA (`/m/dispensar`), no en una
// pestaña aparte: sin caja abierta el mostrador no arrancó, así que tiene que ser lo primero que
// ve. Pero esa misma pantalla es la de buscar al paciente, y buscar es lo que hace de pie con
// alguien enfrente — con el turno ya andando, la tarjeta entera empujaría el buscador fuera de la
// vista. Por eso va en modo COMPACTO: se colapsa a un renglón cuando no hay nada que hacer, y se
// abre sola cuando pide una acción.
let cajaActual = null
const getCajaMostrador = vi.fn(() => Promise.resolve({ data: { caja: cajaActual } }))

vi.mock('../lib/api.js', () => ({
  listPacientes: vi.fn(() => Promise.resolve({ data: { data: [] } })),
  getPaciente: vi.fn(), listDispensaciones: vi.fn(() => Promise.resolve({ data: [] })),
  getPacientePorCarnet: vi.fn(),
  getCajaMostrador: (...a) => getCajaMostrador(...a),
  abrirCajaMostrador: vi.fn(), confirmarAperturaMostrador: vi.fn(),
  solicitarCierreMostrador: vi.fn(), confirmarCierreMostrador: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  useRoute: () => ({ query: {}, params: {} }),
}))

// `dispensario_sede` viaja en /me: la PWA no pide el listado de sedes en la pantalla más usada.
async function montar({ sede = { id: 10, nombre: 'Central' }, rol = 'dispensador' } = {}) {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, first_name: 'Ana', role: rol, dispensario_sede: sede }

  const { default: View } = await import('../views/mobile/MDispensarView.vue')
  const w = mount(View, { global: { stubs: { RouterLink: { template: '<a><slot/></a>' }, DsSpinner: true } } })
  for (let i = 0; i < 8; i++) await new Promise((r) => setTimeout(r, 0))
  return w
}

describe('La caja en la PWA del mostrador', () => {
  beforeEach(() => { vi.clearAllMocks(); cajaActual = null })

  it('aparece en la pantalla donde aterriza, no en una pestaña aparte', async () => {
    const w = await montar()

    expect(w.find('.cjm').exists()).toBe(true)
    expect(getCajaMostrador).toHaveBeenCalledWith(10)
  })

  // Sin caja abierta hay algo que hacer: se muestra entera aunque sea modo compacto.
  it('sin caja abierta se muestra entera: hay algo que resolver', async () => {
    const w = await montar()

    expect(w.find('.cjm-mini').exists()).toBe(false)
    expect(w.text()).toContain('La caja todavía no se abrió')
  })

  it('abierta pero sin confirmar tampoco se colapsa: le toca al que atiende', async () => {
    cajaActual = { id: 7, estado: 'abierta', apertura_confirmada: false, monto_inicial_ars: 10000, abierta_por: 'Vera' }
    const w = await montar()

    expect(w.find('.cjm-mini').exists()).toBe(false)
    expect(w.text()).toContain('Confirmo que está el fondo')
  })

  // Con el turno andando no pide nada: un renglón, y el buscador arriba de la vista.
  it('en marcha se colapsa a un renglón', async () => {
    cajaActual = {
      id: 7, estado: 'abierta', apertura_confirmada: true, monto_inicial_ars: 10000,
      total_efectivo_ars: 4000, total_digital_ars: 0, efectivo_esperado_ars: 14000,
    }
    const w = await montar()

    expect(w.find('.cjm-mini').exists()).toBe(true)
    expect(w.find('.cjm-nums').exists()).toBe(false)
    expect(w.find('.cjm-mini').text()).toContain('En turno')
  })

  it('tocando el renglón se abre el arqueo', async () => {
    cajaActual = {
      id: 7, estado: 'abierta', apertura_confirmada: true, monto_inicial_ars: 10000,
      total_efectivo_ars: 4000, total_digital_ars: 0, efectivo_esperado_ars: 14000,
    }
    const w = await montar()

    await w.find('.cjm-mini').trigger('click')

    expect(w.find('.cjm-nums').exists()).toBe(true)
    expect(w.text()).toContain('esperado en caja')
  })

  it('sin mostrador asignado, no se dibuja', async () => {
    const w = await montar({ sede: null })

    expect(w.find('.cjm').exists()).toBe(false)
    expect(getCajaMostrador).not.toHaveBeenCalled()
  })

  // El buscador tiene que seguir siendo lo primero: es lo que se usa con alguien enfrente.
  it('el buscador sigue estando', async () => {
    const w = await montar()

    expect(w.find('.mdis__search').exists()).toBe(true)
  })
})
