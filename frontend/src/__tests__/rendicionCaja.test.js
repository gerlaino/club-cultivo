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
let cajasAbiertas = []
const listRendiciones     = vi.fn(() => Promise.resolve({
  data: { rendiciones, sin_conformar: 0, mi_saldo_ars: miSaldo, cajas_abiertas: cajasAbiertas, receptores: receptoresHist },
}))
const receptoresRendicion = vi.fn(() => Promise.resolve({ data: [{ id: 5, nombre: 'Germán', rol: 'admin' }] }))
const crearRendicion      = vi.fn(() => Promise.resolve({ data: {} }))
const recibirRendicion    = vi.fn(() => Promise.resolve({ data: {} }))
const conformarRendicion  = vi.fn(() => Promise.resolve({ data: {} }))
const reasignarRendicion  = vi.fn(() => Promise.resolve({ data: {} }))
let receptoresHist = []

vi.mock('../lib/api.js', () => ({
  listRendiciones:     (...a) => listRendiciones(...a),
  receptoresRendicion: (...a) => receptoresRendicion(...a),
  crearRendicion:      (...a) => crearRendicion(...a),
  recibirRendicion:    (...a) => recibirRendicion(...a),
  conformarRendicion:  (...a) => conformarRendicion(...a),
  reasignarRendicion:  (...a) => reasignarRendicion(...a),
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

beforeEach(() => { vi.clearAllMocks(); rendiciones = []; miSaldo = 0; cajasAbiertas = []; receptoresHist = [] })

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
    expect(w.text()).toContain('4 entregas cobradas en efectivo')
    expect(w.find('.rnd__declara-n').text()).toBe('$100.000')
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
    const w = await montar('delivery')
    await w.findAll('.rnd__btn')[1].trigger('click')
    await w.find('.rnd__desacuerdo input').setValue('yo entregué los 100')
    await w.findAll('.rnd__desacuerdo .rnd__btn').find(b => b.text() === 'Enviar').trigger('click')
    await flushPromises()

    expect(conformarRendicion).toHaveBeenCalledWith(9, { conforme: false, notas: 'yo entregué los 100' })
  })
})

// El historial: Comercial → Rendiciones. El mes entero con las pendientes arriba, y quién, cuándo
// y cuánto en cada fila (Germán, 13-oct-2026: el panel avisaba una pendiente que acá no estaba).
describe('El historial de rendiciones', () => {
  beforeEach(() => {
    rendiciones = [
      { id: 10, estado: 'pendiente', delivery: 'Delivery Test', delivery_id: 3, receptor: 'Pablo Ezquer',
        receptor_id: 7, declarado_ars: 100000, recibido_ars: null, diferencia_ars: null, conforme: null,
        rendida_at: '2026-09-17T15:00:00Z', recibida_at: null, puedo_recibir: false, puedo_reasignar: true },
      { id: 9, estado: 'recibida', delivery: 'Juan', delivery_id: 4, receptor: 'Germán', receptor_id: 5,
        declarado_ars: 100000, recibido_ars: 80000, diferencia_ars: -20000, conforme: false,
        motivo: 'faltaron billetes', rendida_at: '2026-08-31T19:00:00Z', recibida_at: '2026-08-31T20:00:00Z',
        puedo_recibir: false, puedo_reasignar: false },
      { id: 8, estado: 'recibida', delivery: 'Juan', delivery_id: 4, receptor: 'Germán', receptor_id: 5,
        declarado_ars: 50000, recibido_ars: 50000, diferencia_ars: 0, conforme: null,
        rendida_at: '2026-08-30T19:00:00Z', recibida_at: '2026-08-30T20:00:00Z',
        puedo_recibir: false, puedo_reasignar: false },
    ]
    receptoresHist = [{ id: 5, nombre: 'Germán' }, { id: 7, nombre: 'Pablo Ezquer' }, { id: 3, nombre: 'Delivery Test' }]
  })

  async function historial (rol = 'admin', mes = '2026-09') {
    setActivePinia(createPinia())
    useAuthStore().user = { id: 5, role: rol }
    const w = mount(RendicionCajaCard, { props: { historial: true, mes, nombreMes: 'septiembre 2026' } })
    await flushPromises(); await flushPromises()
    return w
  }

  it('pide el mes que se mira', async () => {
    await historial()
    expect(listRendiciones).toHaveBeenCalledWith({ mes: '2026-09' })
  })

  it('muestra la PENDIENTE, con a quién se la rindió y desde cuándo espera', async () => {
    const w = await historial()
    const pend = w.findAll('tbody tr')[0]

    expect(pend.text()).toContain('Sin recibir')
    expect(pend.text()).toContain('Delivery Test')
    expect(pend.text()).toContain('Pablo Ezquer')
    expect(pend.text()).toMatch(/Esperando hace \d+ días/)
    expect(pend.text()).toContain('$100.000')
  })

  it('cada fila dice quién rindió y quién recibió, con fecha y hora', async () => {
    const w = await historial()
    const fila = w.findAll('tbody tr')[1]

    expect(fila.text()).toContain('Juan')
    expect(fila.text()).toMatch(/Rindió el 31\/08.*\d{2}:\d{2}/)
    expect(fila.text()).toContain('Germán')
    expect(fila.text()).toMatch(/Recibió el 31\/08.*\d{2}:\d{2}/)
    expect(fila.find('.rnd__dif').text()).toBe('−$20.000')
  })

  it('la conformidad se ve con su motivo, y sólo donde hubo diferencia', async () => {
    const w = await historial()
    const filas = w.findAll('tbody tr')

    expect(filas[1].text()).toContain('Sin conformar')
    expect(filas[1].text()).toContain('faltaron billetes')
    expect(filas[2].text()).not.toContain('Sin conformar') // esa cuadró
  })

  it('una pendiente se reasigna a otra persona (ni a quien ya la tiene ni al repartidor)', async () => {
    const w = await historial()
    const select = w.findAll('tbody tr')[0].find('.rnd__reasignar select')
    const opciones = select.findAll('option').map(o => o.text())

    expect(opciones).toContain('Germán')
    expect(opciones).not.toContain('Pablo Ezquer')
    expect(opciones).not.toContain('Delivery Test')

    await select.setValue('5')
    await w.findAll('tbody tr')[0].find('.rnd__reasignar button').trigger('click')
    await flushPromises()
    expect(reasignarRendicion).toHaveBeenCalledWith(10, { receptor_id: 5 })
    expect(w.emitted('reasignada')).toBeTruthy()
  })

  it('en el historial no se cuenta ni se recibe plata', async () => {
    const w = await historial()
    expect(w.find('.rnd__input').exists()).toBe(false)
    expect(w.find('.rnd__btn--primary').exists()).toBe(false)
  })

  it('sin rendiciones en el mes lo dice, en vez de una tabla vacía', async () => {
    rendiciones = []
    const w = await historial()
    expect(w.text()).toContain('No hay rendiciones en septiembre 2026')
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
describe('Lo que el repartidor tiene de la organización', () => {
  it('se lo dice, sin que tenga que preguntar', async () => {
    miSaldo = 20000
    const w = await montar('delivery')

    expect(w.text()).toContain('Tenés $20.000 de la organización')
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

// DÓNDE ENTRA EL EFECTIVO.
//
// El que atiende no elige: cae en la caja de su mostrador, que es el cajón que tiene abierto
// adelante. Administración sí — puede haber varios mostradores abiertos, y puede no querer
// ninguno (se lo lleva, y queda asentado como ingreso de la organización).
describe('Dónde entra el efectivo', () => {
  beforeEach(() => {
    cajasAbiertas = [{ sede_id: 3, sede: 'Example', abierta_por: 'Ada' }]
  })

  it('al que atiende no se le pregunta', async () => {
    rendiciones = [{ id: 7, estado: 'pendiente', delivery: 'Juan', declarado_ars: 100000,
                     cobros: 1, puedo_recibir: true, elijo_destino: false }]
    const w = await montar('dispensador', 5)

    expect(w.find('.rnd__campo--destino').exists()).toBe(false)

    await w.find('.rnd__input').setValue(100000)
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(recibirRendicion).toHaveBeenCalledWith(7, {
      monto_recibido_ars: 100000, motivo: undefined, destino: undefined,
    })
  })

  it('administración elige entre los mostradores abiertos', async () => {
    rendiciones = [{ id: 7, estado: 'pendiente', delivery: 'Juan', declarado_ars: 100000,
                     cobros: 1, puedo_recibir: true, elijo_destino: true }]
    const w = await montar('admin', 5)

    // Arranca en el placeholder, no en blanco: un select apuntando a `undefined` no matchea
    // ninguna opción y se dibuja vacío, sin el aviso de que falta contestarlo.
    expect(w.find('.rnd__campo--destino select').element.value).toBe('')

    const opciones = w.find('.rnd__campo--destino select').findAll('option').map(o => o.text())
    expect(opciones).toContain('Caja de Example — la abrió Ada')
    // El efectivo ENTRA A UNA CAJA: llevárselo es sacarlo del cajón después, y eso queda
    // registrado a nombre de quien lo saca. Con una caja abierta no se ofrece la organización.
    expect(opciones.some(o => /organización/i.test(o))).toBe(false)
    expect(w.find('.rnd__destino-hint').text()).toMatch(/sacala del cajón/i)
  })

  it('sin ninguna caja abierta sí se puede recibir: si no, el repartidor se va con la plata', async () => {
    cajasAbiertas = []
    rendiciones = [{ id: 7, estado: 'pendiente', delivery: 'Juan', declarado_ars: 100000,
                     cobros: 1, puedo_recibir: true, elijo_destino: true }]
    const w = await montar('admin', 5)

    const opciones = w.find('.rnd__campo--destino select').findAll('option').map(o => o.text())
    expect(opciones.some(o => /No hay ninguna caja abierta/i.test(o))).toBe(true)
  })

  it('sin elegir dónde, no recibe', async () => {
    rendiciones = [{ id: 7, estado: 'pendiente', delivery: 'Juan', declarado_ars: 100000,
                     cobros: 1, puedo_recibir: true, elijo_destino: true }]
    const w = await montar('admin', 5)
    await w.find('.rnd__input').setValue(100000)
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(recibirRendicion).not.toHaveBeenCalled()
  })

  it('elegido el mostrador, viaja la sede', async () => {
    rendiciones = [{ id: 7, estado: 'pendiente', delivery: 'Juan', declarado_ars: 100000,
                     cobros: 1, puedo_recibir: true, elijo_destino: true }]
    const w = await montar('admin', 5)
    await w.find('.rnd__input').setValue(100000)
    await w.find('.rnd__campo--destino select').setValue('3')
    await w.find('.rnd__btn--primary').trigger('click')
    await flushPromises()

    expect(recibirRendicion).toHaveBeenCalledWith(7, {
      monto_recibido_ars: 100000, motivo: undefined, destino: '3',
    })
  })
})
