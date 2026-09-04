import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// NO SE PUEDE ENTREGAR ALGO QUE TODAVÍA NO EXISTÍA.
//
// Cargando historia vieja es fácil poner el 10 de agosto en una dispensa cuyo producto se elaboró
// el 15. El backend lo rechaza, pero enterarse al confirmar es enterarse con el carrito armado —
// y el aviso tiene que estar al lado de la fecha, que es donde se arregla.
//
// Sin atajo: no se ofrece "corregir la fecha del producto y seguir". Esa fecha manda el
// vencimiento, el orden con que sale del depósito y el rendimiento de su lote; cambiarla como
// efecto colateral de guardar una dispensa es falsear el dato del cultivo para tapar un dedazo.
const UNA_SEDE = { id: 10, nombre: 'Central' }
const FLOR = {
  id: 1, cantidad: 300, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
  genetica: { id: 1, nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-08-15', sede: UNA_SEDE,
}

vi.mock('../lib/api.js', () => ({
  listStocks: vi.fn(() => Promise.resolve({ data: [FLOR] })),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createDispensacion: vi.fn(), createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

async function montar () {
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: 'admin' }   // sólo administración puede fechar atrás

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

// Arma el carrito con la flor y deja la dispensa en la fecha pedida.
async function conFecha (w, fecha) {
  w.vm.form.stock_id = 1
  w.vm.form.cantidad = 10
  await w.vm.$nextTick()
  w.vm.agregarItem()
  w.vm.form.fecha_dispensacion = fecha
  await w.vm.$nextTick()
  return w
}

describe('la fecha de la dispensa contra la del producto', () => {
  beforeEach(() => vi.clearAllMocks())

  it('con una fecha anterior a la elaboración, lo dice con las dos fechas', async () => {
    const w = await conFecha(await montar(), '2026-08-01')

    const aviso = w.find('.mnd__fecha-box')
    expect(aviso.exists()).toBe(true)
    expect(aviso.text()).toContain('anterior al producto')
    expect(aviso.text()).toContain('15/08/2026')
  })

  // Dejar apretar para que el backend rebote es el peor error posible.
  it('y no deja confirmar', async () => {
    const w = await conFecha(await montar(), '2026-08-01')

    expect(w.find('.mnd__btn-primary').attributes('disabled')).toBeDefined()
  })

  // Sin atajo: las dos salidas son corregir la fecha de la dispensa o la del producto por su
  // propia puerta. Cambiar la del stock desde acá movería su vencimiento y su orden de salida.
  it('ofrece las dos salidas honestas, y ninguna es "seguir igual"', async () => {
    const w = await conFecha(await montar(), '2026-08-01')

    const texto = w.find('.mnd__fecha-box').text()
    expect(texto).toContain('Corregí la fecha de la dispensa')
    expect(texto).toContain('Depósito')
    expect(texto).not.toContain('Continuar')
  })

  it('el mismo día que se elaboró está bien', async () => {
    const w = await conFecha(await montar(), '2026-08-15')

    expect(w.find('.mnd__fecha-box').exists()).toBe(false)
    expect(w.find('.mnd__btn-primary').attributes('disabled')).toBeUndefined()
  })

  it('y una fecha posterior también', async () => {
    const w = await conFecha(await montar(), '2026-08-20')

    expect(w.find('.mnd__fecha-box').exists()).toBe(false)
  })
})
