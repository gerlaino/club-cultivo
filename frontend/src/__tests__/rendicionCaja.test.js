import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// La entrega de la recaudación del repartidor, montada de verdad.
//
// La plata nunca queda en el aire: el que cuenta es el que la tiene en la mano y ese número entra
// al cajón. Si el receptor ajusta, lo que queda es la CONFORMIDAD del repartidor — constancia,
// no candado.

let rendiciones = []
let miSaldo = 0
const listRendiciones     = vi.fn(() => Promise.resolve({
  data: { rendiciones, sin_conformar: 0, mi_saldo_ars: miSaldo },
}))
const receptoresRendicion = vi.fn(() => Promise.resolve({ data: [{ id: 5, nombre: 'Germán', rol: 'admin' }] }))
const crearRendicion      = vi.fn(() => Promise.resolve({ data: {} }))
const recibirRendicion    = vi.fn(() => Promise.resolve({ data: {} }))
const conformarRendicion  = vi.fn(() => Promise.resolve({ data: {} }))

vi.mock('../lib/api.js', () => ({
  listRendiciones:     (...a) => listRendiciones(...a),
  receptoresRendicion: (...a) => receptoresRendicion(...a),
  crearRendicion:      (...a) => crearRendicion(...a),
  recibirRendicion:    (...a) => recibirRendicion(...a),
  conformarRendicion:  (...a) => conformarRendicion(...a),
}))

import RendicionCajaCard from '../components/RendicionCajaCard.vue'
import { useAuthStore } from '../stores/auth.js'

async function montar (rol, id = 1) {
  setActivePinia(createPinia())
  useAuthStore().user = { id, role: rol }
  const w = mount(RendicionCajaCard)
  await flushPromises()
  await flushPromises()
  return w
}

beforeEach(() => { vi.clearAllMocks(); rendiciones = []; miSaldo = 0 })

describe('El repartidor rinde', () => {
  it('elige a quién le da la plata; el monto no lo escribe él', async () => {
    const w = await montar('delivery')

    expect(w.text()).toContain('Rendir la caja')
    expect(w.text()).toContain('El monto lo pone el sistema')
    expect(w.find('.rnd__input').exists()).toBe(false) // no hay campo de monto

    await w.find('.rnd__select').setValue('5')
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(crearRendicion).toHaveBeenCalledWith({ receptor_id: 5 })
  })

  it('sin elegir a quién, no puede rendir', async () => {
    const w = await montar('delivery')

    expect(w.find('.rnd__btn--primary').attributes('disabled')).toBeDefined()
  })

  it('mientras espera, ve que ya rindió y a quién', async () => {
    rendiciones = [{ id: 1, estado: 'pendiente', declarado_ars: 100000, receptor: 'Germán',
                     puedo_recibir: false, puedo_conformar: false }]
    const w = await montar('delivery')

    expect(w.text()).toContain('Rendiste $100.000')
    expect(w.text()).toContain('Esperando que Germán la reciba')
  })
})

describe('El receptor cuenta y recibe', () => {
  beforeEach(() => {
    rendiciones = [{ id: 7, estado: 'pendiente', delivery: 'Juan', declarado_ars: 100000,
                     cobros: 4, puedo_recibir: true, puedo_conformar: false }]
  })

  it('muestra quién rinde y cuánto declara', async () => {
    const w = await montar('admin', 5)

    expect(w.text()).toContain('Juan te está rindiendo')
    expect(w.text()).toContain('4 entregas · declara $100.000')
  })

  it('sin contar no se recibe', async () => {
    const w = await montar('admin', 5)
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(recibirRendicion).not.toHaveBeenCalled()
  })

  it('si coincide, entra completo', async () => {
    const w = await montar('admin', 5)
    await w.find('.rnd__input').setValue(100000)
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(recibirRendicion).toHaveBeenCalledWith(7, {
      monto_recibido_ars: 100000, motivo: undefined,
    })
  })

  // El texto importa tanto como el número: esa plata no se perdió, la tiene alguien.
  it('si falta, lo dice sin darla por perdida y pide el motivo', async () => {
    const w = await montar('admin', 5)
    await w.find('.rnd__input').setValue(80000)

    expect(w.find('.rnd__falta').text()).toContain('Faltan $20.000')
    expect(w.find('.rnd__falta').text()).toContain('quedan a cuenta de Juan, no se dan por perdidos')

    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()
    expect(recibirRendicion).not.toHaveBeenCalled() // falta el motivo

    await w.find('.rnd__input--motivo').setValue('se quedó 20 a cuenta')
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(recibirRendicion).toHaveBeenCalledWith(7, {
      monto_recibido_ars: 80000, motivo: 'se quedó 20 a cuenta',
    })
  })
})

describe('Los paquetes que vuelven', () => {
  beforeEach(() => {
    rendiciones = [{
      id: 7, estado: 'pendiente', delivery: 'Juan', declarado_ars: 100000, cobros: 4,
      puedo_recibir: true, puedo_conformar: false,
      devoluciones: [
        { id: 31, paciente: 'Ana Pérez', cantidad: 25, unidad: 'g',
          producto: 'Northern Lights (flor seca)', motivo_fallo: 'no había nadie' },
      ],
    }]
  })

  it('los muestra con qué son, de quién y por qué volvieron', async () => {
    const w = await montar('admin', 5)

    expect(w.text()).toContain('Trae 1 paquete sin entregar')
    expect(w.text()).toContain('25 g')
    expect(w.text()).toContain('Ana Pérez')
    expect(w.text()).toContain('no había nadie')
  })

  // TODO paquete que vuelve se desarma: es una decisión de calidad, no una opción del que
  // recibe. No hay nada que tildar.
  it('no se eligen: no hay tilde', async () => {
    const w = await montar('admin', 5)

    expect(w.find('.rnd__paquete input').exists()).toBe(false)
  })

  it('dice qué les va a pasar', async () => {
    const w = await montar('admin', 5)

    expect(w.text()).toContain('Se desarman y el producto vuelve al mostrador')
    expect(w.text()).toContain('se arma en el momento')
  })
})

describe('La conformidad del repartidor', () => {
  beforeEach(() => {
    rendiciones = [{ id: 9, estado: 'recibida', receptor: 'Germán', declarado_ars: 100000,
                     recibido_ars: 80000, diferencia_ars: -20000, motivo: 'faltaron 20',
                     conforme: false, puedo_recibir: false, puedo_conformar: true }]
  })

  it('le muestra qué recibieron y contra qué', async () => {
    const w = await montar('delivery')

    expect(w.text()).toContain('Germán recibió $80.000 de los $100.000 que cobraste')
    expect(w.text()).toContain('faltaron 20')
  })

  it('puede decir que está de acuerdo', async () => {
    const w = await montar('delivery')
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(conformarRendicion).toHaveBeenCalledWith(9, { conforme: true, notas: undefined })
  })

  // No estar de acuerdo no devuelve la plata ni reabre nada: queda escrito.
  it('y puede decir que no, con lo que pasó', async () => {
    vi.stubGlobal('prompt', () => 'yo entregué los 100')
    const w = await montar('delivery')
    await w.findAll('.rnd__btn')[1].trigger('click')
    await flushPromises()

    expect(conformarRendicion).toHaveBeenCalledWith(9, { conforme: false, notas: 'yo entregué los 100' })
  })
})

// El historial: lo mismo, pero como tabla y sin acciones. Es la solapa del Mostrador.
describe('El historial de rendiciones', () => {
  beforeEach(() => {
    rendiciones = [
      { id: 9, estado: 'recibida', delivery: 'Juan', receptor: 'Germán', declarado_ars: 100000,
        recibido_ars: 80000, diferencia_ars: -20000, conforme: false,
        recibida_at: '2026-08-31T20:00:00Z', puedo_recibir: false, puedo_conformar: false },
      { id: 8, estado: 'recibida', delivery: 'Juan', receptor: 'Germán', declarado_ars: 50000,
        recibido_ars: 50000, diferencia_ars: 0, conforme: null,
        recibida_at: '2026-08-30T20:00:00Z', puedo_recibir: false, puedo_conformar: false },
    ]
  })

  async function historial (rol = 'admin') {
    setActivePinia(createPinia())
    useAuthStore().user = { id: 5, role: rol }
    const w = mount(RendicionCajaCard, { props: { historial: true } })
    await flushPromises(); await flushPromises()
    return w
  }

  it('muestra qué cobró y qué entregó cada uno', async () => {
    const w = await historial()
    const filas = w.findAll('tbody tr')

    expect(filas).toHaveLength(2)
    expect(filas[0].text()).toContain('Juan')
    expect(filas[0].text()).toContain('$100.000')
    expect(filas[0].text()).toContain('$80.000')
    expect(filas[0].find('.rnd__dif').text()).toBe('−$20.000')
  })

  it('marca la que el repartidor todavía no conformó', async () => {
    const w = await historial()
    const filas = w.findAll('tbody tr')

    expect(filas[0].text()).toContain('Sin conformar')
    expect(filas[1].text()).not.toContain('Sin conformar') // esa cuadró
  })

  // Es historial: acá no se recibe ni se cuenta nada.
  it('no tiene acciones', async () => {
    const w = await historial()

    expect(w.find('.rnd__input').exists()).toBe(false)
    expect(w.find('.rnd__btn').exists()).toBe(false)
  })

  it('sin rendiciones lo dice, en vez de una tabla vacía', async () => {
    rendiciones = []
    const w = await historial()

    expect(w.text()).toContain('Todavía no se rindió ninguna caja')
  })
})

// Sin nada que rendir ni que recibir, no ocupa lugar.
it('no se muestra si no hay nada que hacer', async () => {
  receptoresRendicion.mockResolvedValueOnce({ data: [] })
  const w = await montar('admin', 5)

  expect(w.find('.rnd').exists()).toBe(false)
})


// LO QUE TIENE DEL CLUB Y TODAVÍA NO DEVOLVIÓ.
//
// Cuando rinde $100.000 y sobre la mesa aparecen $80.000, los $20.000 quedan a su nombre — y el
// repartidor no lo veía en ningún lado: si le anotaron una diferencia, tenía que preguntar. Así
// es como algo chico se convierte en una discusión.
describe('Lo que el repartidor tiene del club', () => {
  it('se lo dice, sin que tenga que preguntar', async () => {
    miSaldo = 20000
    const w = await montar('delivery')

    expect(w.text()).toContain('Tenés $20.000 del club')
    // No es una deuda ni una pérdida: es plata suya que quedó con él.
    expect(w.text()).not.toMatch(/debé|deuda|debe/i)
  })

  it('sin saldo, no dice nada', async () => {
    const w = await montar('delivery')

    expect(w.find('.rnd__saldo').exists()).toBe(false)
  })

  // La tarjeta se escondía cuando no había nada que rendir, y con eso se escondía el saldo.
  it('y la tarjeta aparece aunque no haya nada que rendir', async () => {
    miSaldo = 20000
    receptoresRendicion.mockResolvedValueOnce({ data: [] })
    const w = await montar('delivery')

    expect(w.find('.rnd').exists()).toBe(true)
  })
})
