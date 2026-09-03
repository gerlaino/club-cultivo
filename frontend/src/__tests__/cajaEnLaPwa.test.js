import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL ESTADO DEL MOSTRADOR EN LA PWA, donde el dispensador aterriza (`/m/dispensar`).
//
// Es un RESUMEN, no un formulario: contar, abrir, cargar y cerrar pasan en `/m/mostrador`, que es
// donde el gesto está completo. Antes esta tarjeta abría la caja pidiendo sólo el fondo —
// salteando el conteo del stock, que es la mitad del arqueo— y era una segunda implementación
// del flujo entero conviviendo con la del mostrador.
//
// Y esa misma pantalla es la de buscar al paciente, que es lo que se hace de pie con alguien
// enfrente: por eso va en modo COMPACTO y no empuja el buscador fuera de la vista.
let respuesta = { mesa: [], turno: null }
const getMostrador = vi.fn(() => Promise.resolve({ data: respuesta }))

vi.mock('../lib/api.js', () => ({
  listPacientes: vi.fn(() => Promise.resolve({ data: { data: [] } })),
  getPaciente: vi.fn(), listDispensaciones: vi.fn(() => Promise.resolve({ data: [] })),
  getPacientePorCarnet: vi.fn(),
  getMostrador: (...a) => getMostrador(...a),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  useRoute: () => ({ query: {}, params: {} }),
  RouterLink: { template: '<a><slot/></a>' },
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

describe('El mostrador en la PWA', () => {
  beforeEach(() => { vi.clearAllMocks(); respuesta = { mesa: [], turno: null } })

  it('aparece en la pantalla donde aterriza, no en una pestaña aparte', async () => {
    const w = await montar()

    expect(w.find('.cjm').exists()).toBe(true)
    expect(getMostrador).toHaveBeenCalledWith(10)
  })

  it('con la mesa vacía dice que hay que cargarla', async () => {
    const w = await montar()

    expect(w.find('.cjm').text()).toContain('La mesa está vacía')
  })

  // El estado que más confunde: hay producto pero nadie abrió, así que no se puede dispensar.
  it('con mercadería y sin caja abierta, lo dice', async () => {
    respuesta = { mesa: [{ stock_id: 1, mostrador: 300 }], turno: null }
    const w = await montar()

    expect(w.find('.cjm').text()).toContain('Hay mercadería sobre la mesa')
  })

  it('con la caja abierta dice quién la abrió', async () => {
    respuesta = {
      mesa: [{ stock_id: 1, mostrador: 300 }],
      turno: { id: 7, abierto_por: 'Ana Gómez', abierto_at: '2026-09-02T12:00:00Z',
               caja: { fondo_ars: 50000, cobrado_efectivo_ars: 0, esperado_ars: 50000 } },
    }
    const w = await montar()

    expect(w.find('.cjm').text()).toContain('Ana Gómez')
  })

  // En el teléfono el detalle empuja el buscador, que es lo que se usa de pie.
  it('en modo compacto no despliega los números', async () => {
    respuesta = {
      mesa: [{ stock_id: 1, mostrador: 300 }],
      turno: { id: 7, abierto_por: 'Ana', abierto_at: '2026-09-02T12:00:00Z',
               caja: { fondo_ars: 50000, cobrado_efectivo_ars: 0, esperado_ars: 50000 } },
    }
    const w = await montar()

    expect(w.find('.cjm-nums').exists()).toBe(false)
  })

  // UNA sola puerta.
  it('no abre ni cierra desde acá: manda al mostrador', async () => {
    const w = await montar()

    expect(w.find('.cjm').text()).toContain('Ir al mostrador')
    expect(w.text()).not.toContain('Abrir caja')
  })
})
