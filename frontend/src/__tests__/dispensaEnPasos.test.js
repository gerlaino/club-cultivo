import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EN EL TELÉFONO, DOS PASOS: qué se lleva y cómo paga.
//
// Son los dos momentos reales del mostrador. El formulario completo entra en un escritorio y ahí
// está bien —verlo de una es mejor—, pero en un teléfono el que lo usa está PARADO con alguien
// enfrente: elegir el producto arriba, escribir la cantidad abajo y después buscar "Agregar" eran
// tres puntos de la pantalla a dos scrolls de distancia.
//
// Es la MISMA pantalla con otra distribución, no otra pantalla: la lógica vive una sola vez.

const UNA_SEDE = { id: 10, nombre: 'Central' }
const STOCKS = [
  { id: 1, cantidad: 340, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 1800,
    genetica: { id: 1, nombre: 'Lemon Cookie' }, fecha_elaboracion: '2026-05-12', sede: UNA_SEDE },
  { id: 2, cantidad: 120, unidad: 'g', forma_producto: 'flor_seca', precio_sugerido_ars: 2100,
    genetica: { id: 2, nombre: 'Blue Sherbet' }, fecha_elaboracion: '2026-06-03', sede: UNA_SEDE },
]

const listStocks = vi.fn(() => Promise.resolve({ data: STOCKS }))
vi.mock('../lib/api.js', () => ({
  listStocks: (...a) => listStocks(...a),
  listEntregadores: vi.fn(() => Promise.resolve({ data: [] })),
  getMostrador: vi.fn(() => Promise.resolve({ data: { mesa: [], turno: { id: 1 } } })),
  createDispensacion: vi.fn(), createReserva: vi.fn(), entregarReserva: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

const PACIENTE = { id: 5, nombre_completo: 'Ana Gómez', cuenta_corriente: {} }

// El ancho manda: el componente pregunta por `matchMedia`, que jsdom no implementa.
function anchoDe(px) {
  window.matchMedia = (q) => ({
    matches: /max-width:\s*480px/.test(q) ? px <= 480 : false,
    media: q, addEventListener() {}, removeEventListener() {},
    addListener() {}, removeListener() {}, onchange: null, dispatchEvent: () => false,
  })
}

// Por su CONTENIDO y no por su posición: el orden de la lista lo decide el componente, y buscar
// por índice hace que el test pase por la razón equivocada el día que cambie el criterio.
const fila = (w, texto) => w.findAll('.mnd__stock-row').find(f => f.text().includes(texto))

async function montar(px = 390, rol = 'dispensador') {
  anchoDe(px)
  listStocks.mockResolvedValue({ data: STOCKS })
  setActivePinia(createPinia())
  const { useAuthStore } = await import('../stores/auth.js')
  useAuthStore().user = { id: 1, role: rol }
  const { default: Modal } = await import('../components/pacientes/ModalNuevaDispensacion.vue')
  const w = mount(Modal, {
    props: { modelValue: true, paciente: PACIENTE, socioId: PACIENTE.id, pacienteNombre: 'Ana Gómez' },
    global: { stubs: { Teleport: true, DsSpinner: true, AppDatePicker: true } },
  })
  await flushPromises()
  return w
}

beforeEach(() => { listStocks.mockClear() })

describe('En el teléfono', () => {
  it('arranca en el primer paso, y lo dice', async () => {
    const w = await montar(390)

    expect(w.find('.mnd__modal-title').text()).toContain('Qué se lleva')
    expect(w.find('.mnd__modal-paso').text()).toBe('paso 1 de 2')
  })

  // Lo que rompía la experiencia: el producto arriba, la cantidad abajo y "Agregar" más abajo
  // todavía. Ahora la cantidad aparece donde está el pulgar apenas se toca un producto.
  it('la cantidad aparece al tocar un producto, en la barra de abajo', async () => {
    const w = await montar(390)
    expect(w.find('.mnd__barra-cant').exists()).toBe(false)

    await fila(w, 'Lemon Cookie').trigger('click')

    const barra = w.find('.mnd__barra-cant')
    expect(barra.exists()).toBe(true)
    expect(barra.text()).toContain('Lemon Cookie')   // qué se tocó
    expect(barra.text()).toContain('340')            // y cuánto queda
  })

  it('y ese campo NO se repite en el medio del formulario', async () => {
    const w = await montar(390)
    await fila(w, 'Lemon Cookie').trigger('click')

    expect(w.findAll('.mnd__add-item')).toHaveLength(0)
  })

  it('no se puede pasar al cobro con el carrito vacío', async () => {
    const w = await montar(390)

    expect(w.find('.mnd__barra-seguir').attributes('disabled')).toBeDefined()
  })

  it('agregar lleva el producto al carrito y habilita el paso siguiente', async () => {
    const w = await montar(390)
    await fila(w, 'Lemon Cookie').trigger('click')
    await w.find('.mnd__barra-cant input').setValue('25')
    await w.find('.mnd__barra-add').trigger('click')

    expect(w.find('.mnd__cart').text()).toContain('25')
    expect(w.find('.mnd__barra-seguir').attributes('disabled')).toBeUndefined()
    // El total, siempre a la vista: es lo que se le dice en voz alta al paciente.
    expect(w.find('.mnd__barra-total').text()).toContain('45.000')
  })

  it('el segundo paso es el cobro, y se puede volver', async () => {
    const w = await montar(390)
    await fila(w, 'Lemon Cookie').trigger('click')
    await w.find('.mnd__barra-cant input').setValue('25')
    await w.find('.mnd__barra-add').trigger('click')
    await w.find('.mnd__barra-seguir').trigger('click')

    expect(w.find('.mnd__modal-title').text()).toContain('Cómo paga')
    expect(w.find('.mnd__barra-seguir').text()).toContain('Registrar')

    await w.find('.mnd__barra-acc .mnd__btn-ghost').trigger('click')
    expect(w.find('.mnd__modal-title').text()).toContain('Qué se lleva')
  })

  // Lo escrito no se pierde al ir y volver: es `v-show`, no `v-if`.
  it('lo cargado sobrevive al ir y volver entre pasos', async () => {
    const w = await montar(390)
    await fila(w, 'Lemon Cookie').trigger('click')
    await w.find('.mnd__barra-cant input').setValue('25')
    await w.find('.mnd__barra-add').trigger('click')
    await w.find('.mnd__barra-seguir').trigger('click')
    await w.find('.mnd__barra-acc .mnd__btn-ghost').trigger('click')

    expect(w.find('.mnd__cart').text()).toContain('25')
  })
})

describe('En el escritorio', () => {
  // Entra entero y verlo de una es mejor: no hay pasos que atravesar para llegar al cobro.
  it('no hay pasos: es el formulario completo', async () => {
    const w = await montar(1280, 'admin')

    expect(w.find('.mnd__modal-paso').exists()).toBe(false)
    expect(w.find('.mnd__barra-acc').exists()).toBe(false)
    expect(w.find('.mnd__modal-title').text()).toContain('Nueva dispensación')
    // Y la cantidad sigue en su lugar de siempre, con su botón.
    expect(w.find('.mnd__add-item').exists()).toBe(true)
  })
})
