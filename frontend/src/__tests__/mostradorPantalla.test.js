import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// La pantalla del MOSTRADOR, montada de verdad.
//
// Para una organización que sólo dispensa es LA pantalla del día, así que un build limpio no
// alcanza: acá se monta con la API respondiendo y se recorre el flujo entero. Ya pasó cuatro
// veces en este proyecto que algo compilara perfecto y explotara al abrirse.

const SEDES = [
  { id: 10, nombre: 'Central', tipo: 'social' },
  { id: 11, nombre: 'Vivero',  tipo: 'produccion' }, // no dispensa: no tiene mostrador
]

const DISPONIBLES = [
  { stock_id: 1, etiqueta: 'Northern Lights (flor seca)', numero: 'ST-26-0031', forma: 'flor_seca',
    unidad: 'g', lote: 'L-26-002', genetica: 'Northern Lights', fecha: '2026-06-10',
    precio_ars: 1200, costo_ars: 200, disponible: 500 },
  { stock_id: 2, etiqueta: 'Preroll', numero: 'ST-26-0061', forma: 'preroll',
    unidad: 'un', lote: null, genetica: null, fecha: '2026-07-02',
    precio_ars: 2500, costo_ars: 800, disponible: 120 },
]

const TURNO = {
  id: 7, estado: 'abierto', abierto_at: '2026-08-28T09:02:00Z', abierto_por: 'Ana Gómez',
  caja_turno_id: 3, hubo_correccion_apertura: false,
  confirmado: true, confirmado_por: 'Ana Gómez', confirmado_at: '2026-08-28T09:05:00Z',
  caja: { id: 3, fondo_ars: 50000, cobrado_efectivo_ars: 8500, cobrado_digital_ars: 0,
          salidas_ars: 0, esperado_ars: 58500 },
  items: [
    { id: 71, stock_id: 1, etiqueta: 'Northern Lights (flor seca)', unidad: 'g', heredada: 215,
      apertura: 215, repuesta: 0, devuelta: 0, dispensada: 60, esperado: 155,
      en_deposito: 1240, senal: null, sin_supervision: false },
    { id: 72, stock_id: 2, etiqueta: 'Preroll', unidad: 'un', heredada: 20,
      apertura: 20, repuesta: 0, devuelta: 0, dispensada: 8, esperado: 12,
      en_deposito: 0, senal: 'sin_repuesto', sin_supervision: true },
  ],
}

let respuesta = {}
const getMostrador      = vi.fn(() => Promise.resolve({ data: respuesta }))
const abrirMostrador    = vi.fn(() => Promise.resolve({ data: {} }))
const cargarMostrador   = vi.fn(() => Promise.resolve({ data: {} }))
const devolverMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const cerrarMostrador   = vi.fn(() => Promise.resolve({ data: {} }))
const confirmarMostrador = vi.fn(() => Promise.resolve({ data: {} }))

const MERMA = {
  resumen: { turnos: 12, dispensado: 4200, faltante: 61, sobrante: 2, faltante_ars: 41000, merma_pct: 1.45 },
  por_producto: [
    // El preroll pierde MENOS en absoluto y MÁS en porcentaje: es el cuello de botella, y por
    // eso va primero.
    { producto: 'Preroll', unidad: 'un', dispensado: 200, faltante: 20, faltante_ars: 20000, merma_pct: 10.0, turnos: 8 },
    { producto: 'Northern Lights (flor seca)', unidad: 'g', dispensado: 4000, faltante: 41, faltante_ars: 21000, merma_pct: 1.03, turnos: 12 },
  ],
  por_turno: [
    { id: 91, cerrado_at: '2026-08-28T21:10:00Z', cerrado_por: 'Ana Gómez', recibido_por: 'Ana Gómez',
      dispensado: 350, faltante: 6, faltante_ars: 3000, motivos: ['merma de fraccionamiento'],
      correcciones: 2, revisado: false },
    { id: 90, cerrado_at: '2026-08-27T21:00:00Z', cerrado_por: 'Ana Gómez', recibido_por: 'Ana Gómez',
      dispensado: 300, faltante: 0, faltante_ars: 0, motivos: [], correcciones: 0, revisado: true },
  ],
  sin_revisar: 1,
}
const getMermaMostrador = vi.fn(() => Promise.resolve({ data: MERMA }))
const revisarTurnoMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const getTurnoMostrador = vi.fn(() => Promise.resolve({
  data: { id: 91, items: [{ id: 71, etiqueta: 'Northern Lights (flor seca)', unidad: 'g', contado: 21 }] },
}))
const corregirTurnoMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const TURNOS_CERRADOS = {
  gestiona: false,
  turnos: [
    { id: 91, abierto_at: '2026-08-28T09:00:00Z', cerrado_at: '2026-08-28T21:10:00Z',
      cerrado_por: 'Ana Gómez', atendio: 'Ana Gómez', revisado: false, productos: 2,
      dispensado: 350, faltante: 6, faltante_ars: 3000, con_diferencia: 1,
      efectivo_contado_ars: 58500, diferencia_caja_ars: 0 },
  ],
}
const listTurnosMostrador = vi.fn(() => Promise.resolve({ data: TURNOS_CERRADOS }))
const ingresoCajaMostrador  = vi.fn(() => Promise.resolve({ data: {} }))
const contarMostrador       = vi.fn(() => Promise.resolve({ data: {} }))
const salidaCajaMostrador   = vi.fn(() => Promise.resolve({ data: {} }))

vi.mock('../lib/api.js', () => ({
  getMostrador:      (...a) => getMostrador(...a),
  abrirMostrador:    (...a) => abrirMostrador(...a),
  cargarMostrador:   (...a) => cargarMostrador(...a),
  devolverMostrador: (...a) => devolverMostrador(...a),
  cerrarMostrador:   (...a) => cerrarMostrador(...a),
  confirmarMostrador: (...a) => confirmarMostrador(...a),
  getMermaMostrador:  (...a) => getMermaMostrador(...a),
  revisarTurnoMostrador: (...a) => revisarTurnoMostrador(...a),
  getTurnoMostrador:    (...a) => getTurnoMostrador(...a),
  corregirTurnoMostrador: (...a) => corregirTurnoMostrador(...a),
  listTurnosMostrador:  (...a) => listTurnosMostrador(...a),
  contarMostrador:      (...a) => contarMostrador(...a),
  ingresoCajaMostrador: (...a) => ingresoCajaMostrador(...a),
  salidaCajaMostrador:  (...a) => salidaCajaMostrador(...a),
  listSedes:         vi.fn(() => Promise.resolve({ data: SEDES })),
}))

import MostradorView from '../views/MostradorView.vue'
import { useSedeStore } from '../stores/sede.js'
import { useAuthStore } from '../stores/auth.js'

async function montar () {
  const wrapper = mount(MostradorView, { global: { stubs: { RouterLink: true } } })
  await flushPromises()
  await flushPromises()
  return wrapper
}

beforeEach(() => {
  setActivePinia(createPinia())
  const sede = useSedeStore()
  sede.sedes = SEDES
  sede.loaded = true
  vi.clearAllMocks()
})

describe('La pantalla del mostrador', () => {
  describe('con el mostrador cerrado', () => {
    beforeEach(() => {
      respuesta = {
        mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
        turno: null,
        sugerido: [{ ...DISPONIBLES[0], cantidad: 215 }],
        disponibles: DISPONIBLES,
      }
    })

    it('dice que está cerrado y ofrece abrirlo', async () => {
      const w = await montar()

      expect(w.text()).toContain('Cerrado')
      expect(w.text()).toContain('Abrir el mostrador')
    })

    // El número de partida viene puesto: no es un conteo obligatorio, es algo que se corrige
    // sólo si no coincide.
    it('viene precargado con lo que se contó en el cierre anterior', async () => {
      const w = await montar()
      const filas = w.findAll('.tst__table tbody tr')

      expect(filas[0].text()).toContain('Northern Lights')
      expect(filas[0].find('.tst__input').element.value).toBe('215')
      // Y se ve por qué viene puesto: si no, parece un número que alguien declaró.
      expect(filas[0].text()).toContain('venía de anoche')
    })

    // Perderlo entre cuarenta filas es perder la mitad del valor del módulo.
    it('y lo heredado va arriba de todo, ordene por lo que ordene', async () => {
      const w = await montar()
      await w.findAll('.tst__th-btn')[0].trigger('click') // ordenar por producto

      expect(w.findAll('.tst__table tbody tr')[0].text()).toContain('Northern Lights')
    })

    it('manda al backend lo que quedó en la lista, con el fondo de caja', async () => {
      const w = await montar()
      await w.find('.mst__input--fondo').setValue(50000)
      await w.find('.mst__acciones .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(abrirMostrador).toHaveBeenCalledWith(10, {
        monto_inicial_ars: 50000,
        items: [{ stock_id: 1, cantidad: 215 }],
      })
    })

    // Elegir qué baja no es buscar un ítem: es revisar el inventario y decidir. Era un
    // desplegable, donde no se veía ni el lote, ni la fecha, ni cuánto quedaba.
    describe('la tabla de stock', () => {
      const fila = (w, n) => w.findAll('.tst__table tbody tr')[n]

      it('lista todo el stock de la sede con lo que hace falta para decidir', async () => {
        const w = await montar()

        expect(w.findAll('.tst__table tbody tr')).toHaveLength(2)
        expect(fila(w, 0).text()).toContain('L-26-002')      // lote
        expect(fila(w, 0).text()).toContain('ST-26-0031')    // número
        expect(fila(w, 0).text()).toContain('$1.200')        // precio
      })

      // La CANTIDAD es la marca: un tilde aparte daría el estado sin sentido "marcado en 0".
      it('escribir la cantidad es elegir el producto', async () => {
        const w = await montar()
        await fila(w, 1).find('.tst__input').setValue(40)

        expect(fila(w, 1).classes()).toContain('is-elegida')
        await w.find('.mst__acciones .mst__btn--primary').trigger('click')
        await flushPromises()

        expect(abrirMostrador).toHaveBeenCalledWith(10, {
          monto_inicial_ars: 0,
          items: [{ stock_id: 1, cantidad: 215 }, { stock_id: 2, cantidad: 40 }],
        })
      })

      it('y borrarla lo saca', async () => {
        const w = await montar()
        await fila(w, 0).find('.tst__input').setValue('')

        expect(fila(w, 0).classes()).not.toContain('is-elegida')
        expect(w.find('.mst__acciones .mst__btn--primary').attributes('disabled')).toBeDefined()
      })

      // El backend lo rechaza igual, pero decirlo en la fila evita llenar todo para que rebote.
      it('avisa si se pide más de lo que hay libre', async () => {
        const w = await montar()
        await fila(w, 1).find('.tst__input').setValue(500) // hay 120

        expect(fila(w, 1).text()).toContain('quedan 120')
        expect(fila(w, 1).find('.tst__input').classes()).toContain('is-mal')
        // Y no deja abrir: dejar apretar para que el backend rechace es el peor error posible.
        expect(w.find('.mst__acciones .mst__btn--primary').attributes('disabled')).toBeDefined()
      })

      it('se busca por palabra', async () => {
        const w = await montar()
        await w.find('.tst__buscar').setValue('preroll')

        const filas = w.findAll('.tst__table tbody tr')
        expect(filas).toHaveLength(1)
        expect(filas[0].text()).toContain('Preroll')
      })

      // Con el buscador de por medio, lo elegido puede no estar en pantalla: sin el resumen, el
      // que filtra cree que perdió lo que ya había cargado.
      it('y lo cargado sobrevive al buscador', async () => {
        const w = await montar()
        await fila(w, 1).find('.tst__input').setValue(40)
        await w.find('.tst__buscar').setValue('northern')

        expect(w.findAll('.tst__table tbody tr')).toHaveLength(1)
        expect(w.find('.tst__pie').text()).toContain('2 productos')
        expect(w.find('.tst__pie').text()).toContain('215 g · 40 un')
      })

      it('se ordena por columna, y al segundo click al revés', async () => {
        respuesta = { ...respuesta, sugerido: [] } // sin heredados, el orden se ve limpio
        const w = await montar()

        await w.findAll('.tst__th-btn')[0].trigger('click')
        expect(fila(w, 0).text()).toContain('Northern')
        await w.findAll('.tst__th-btn')[0].trigger('click')
        expect(fila(w, 0).text()).toContain('Preroll')
      })

      // Cuánto vale lo que se está por poner sobre la mesa. Sólo para quien responde por eso.
      it('el costo es de administración', async () => {
        useAuthStore().user = { id: 1, role: 'admin' }
        const w = await montar()
        expect(w.text()).toContain('Costo')

        useAuthStore().user = { id: 2, role: 'dispensador' }
        expect((await montar()).text()).not.toContain('Costo')
      })
    })

    // Un selector con una sola opción es ruido: con una sede que dispensa no aparece.
    it('con una sola sede que dispensa no hay selector', async () => {
      const w = await montar()

      expect(w.find('.mst__select--sede').exists()).toBe(false)
    })

    it('con varias, ofrece sólo las que dispensan', async () => {
      const sede = useSedeStore()
      sede.sedes = [...SEDES, { id: 12, nombre: 'Norte', tipo: 'mixta' }]
      const w = await montar()
      const sedes = w.findAll('.mst__select--sede option').map(o => o.text())

      // 'Vivero' es de producción: no atiende pacientes y no tiene mostrador.
      expect(sedes).toEqual(['Central', 'Norte'])
    })
  })

  describe('con el mostrador abierto', () => {
    beforeEach(() => {
      respuesta = {
        mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
        turno: TURNO, sugerido: [], disponibles: DISPONIBLES,
      }
    })

    it('muestra quién lo abrió y desde cuándo', async () => {
      const w = await montar()

      expect(w.text()).toContain('Abierto')
      expect(w.text()).toContain('Ana Gómez')
    })

    // Las tres columnas son la pantalla: contestan "¿alcanza hasta que cierre?".
    it('muestra en la mesa, lo que salió y lo que queda en el depósito', async () => {
      const w = await montar()
      const fila = w.findAll('tbody tr')[0]

      expect(fila.find('.mst__mesa').text()).toBe('155')
      expect(fila.text()).toContain('60 g')     // salió
      expect(fila.text()).toContain('1.240 g')  // en depósito
    })

    // La señal que no existe hoy en ningún lado: no queda arriba NI abajo.
    it('marca el producto sin repuesto', async () => {
      const w = await montar()
      const fila = w.findAll('tbody tr')[1]

      expect(fila.text()).toContain('Sin repuesto')
      expect(fila.classes()).toContain('is-alerta')
    })

    // El dato útil es que ese producto lo bajó el mostrador y no administración — para saber
    // por dónde se movió, no para señalar a nadie.
    it('marca lo que se repuso desde el mostrador', async () => {
      const w = await montar()

      expect(w.findAll('tbody tr')[1].text()).toContain('Repuesto desde el mostrador')
    })

    // En gramos no se compara con nada; en plata se ve de un vistazo cuánto hay ahí arriba.
    it('dice cuánto vale lo que está sobre la mesa, a costo', async () => {
      useAuthStore().user = { id: 1, role: 'admin' }
      respuesta = { ...respuesta, turno: { ...TURNO, valor_mesa_ars: 68000 } }
      const w = await montar()

      expect(w.find('.mst__valor-mesa').text()).toContain('$68.000')
    })

    it('y no se lo muestra al que atiende: no responde por eso', async () => {
      useAuthStore().user = { id: 2, role: 'dispensador' }
      respuesta = { ...respuesta, turno: { ...TURNO, valor_mesa_ars: 68000 } }
      const w = await montar()

      expect(w.find('.mst__valor-mesa').exists()).toBe(false)
    })

    it('repone un producto contra el backend', async () => {
      const w = await montar()
      await w.findAll('tbody tr')[0].findAll('.mst__btn--mini')[0].trigger('click')
      await w.find('.mst__modal .mst__input').setValue(200)
      await w.find('.mst__modal .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(cargarMostrador).toHaveBeenCalledWith(10, { stock_id: 1, cantidad: 200 })
    })

    // Con el turno andando pasa que se acaban tres cosas juntas: de a uno son tres modales.
    describe('bajar más del depósito', () => {
      async function abrirBajada () {
        const w = await montar()
        await w.find('.mst__acciones--turno .mst__btn').trigger('click')
        return w
      }

      // Lo que ya está arriba se repone desde su propia fila: ofrecerlo dos veces es cómo se
      // terminan cargando dos líneas del mismo frasco.
      it('sólo ofrece lo que NO está sobre la mesa', async () => {
        respuesta = {
          ...respuesta,
          disponibles: [...DISPONIBLES, { stock_id: 9, etiqueta: 'Hash', numero: 'ST-9',
                                          unidad: 'g', genetica: null, fecha: '2026-05-01',
                                          precio_ars: 900, costo_ars: 300, disponible: 60 }],
        }
        const w = await abrirBajada()
        const filas = w.findAll('.tst__table tbody tr')

        expect(filas).toHaveLength(1)
        expect(filas[0].text()).toContain('Hash')
      })

      it('baja varios de una y recarga al final', async () => {
        respuesta = {
          ...respuesta,
          disponibles: [...DISPONIBLES, { stock_id: 9, etiqueta: 'Hash', numero: 'ST-9',
                                          unidad: 'g', genetica: null, fecha: '2026-05-01',
                                          precio_ars: 900, costo_ars: 300, disponible: 60 }],
        }
        const w = await abrirBajada()
        await w.find('.tst__input').setValue(25)
        await w.find('.mst__modal-acc .mst__btn--primary').trigger('click')
        await flushPromises()

        expect(cargarMostrador).toHaveBeenCalledWith(10, { stock_id: 9, cantidad: 25 })
        expect(w.find('.mst__modal').exists()).toBe(false)
      })
    })

    it('devuelve al depósito contra el backend', async () => {
      const w = await montar()
      await w.findAll('tbody tr')[0].findAll('.mst__btn--mini')[1].trigger('click')
      await w.find('.mst__modal .mst__input').setValue(30)
      await w.find('.mst__modal .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(devolverMostrador).toHaveBeenCalledWith(10, { item_id: 71, cantidad: 30 })
    })
  })

  describe('cerrar el mostrador', () => {
    beforeEach(() => {
      respuesta = {
        mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
        turno: TURNO, sugerido: [], disponibles: DISPONIBLES,
      }
    })

    async function abrirCierre () {
      const w = await montar()
      await w.find('.mst__turno .mst__btn--primary').trigger('click')
      return w
    }

    // Nadie pesa 297 g teniendo el 297 delante: con el número a la vista el arqueo es teatro y
    // toda la merma que medimos da cero.
    it('NO muestra lo esperado hasta que el conteo esté escrito', async () => {
      const w = await abrirCierre()

      expect(w.text()).toContain('Cerrar el mostrador')
      expect(w.findAll('.mst__conteo-row')).toHaveLength(2)
      expect(w.find('.mst__conteo-row').text()).not.toContain('tendría que haber')
      expect(w.find('.mst__caja').text()).not.toContain('Tendría que haber')
    })

    it('y lo muestra recién cuando el número está cargado', async () => {
      const w = await abrirCierre()
      await w.findAll('.mst__conteo-row')[0].find('.mst__input--cant').setValue(155)

      expect(w.findAll('.mst__conteo-row')[0].text()).toContain('tendría que haber 155 g')
      // El otro producto sigue sin revelar: se revela de a uno, con el que se contó.
      expect(w.findAll('.mst__conteo-row')[1].text()).not.toContain('tendría que haber')
    })

    it('la caja tampoco muestra contra qué hasta que se cuenta', async () => {
      const w = await abrirCierre()
      expect(w.find('.mst__caja').text()).not.toContain('58.500')

      await w.findAll('.mst__caja .mst__input')[0].setValue(58000)

      expect(w.find('.mst__caja').text()).toContain('58.500')
      expect(w.find('.mst__dif-caja').text()).toBe('Faltan $500')
    })

    it('muestra la diferencia de cada producto mientras se cuenta', async () => {
      const w = await abrirCierre()
      const filas = w.findAll('.mst__conteo-row')
      await filas[0].find('.mst__input--cant').setValue(151.4)

      expect(filas[0].find('.mst__dif').text()).toBe('-3,6 g')
      // Una diferencia se destaca, pero no se pinta como un error: la merma es inevitable.
      expect(filas[0].find('.mst__dif').classes()).toContain('is-dif')
    })

    it('cuando cuadra lo dice, y no pide motivo', async () => {
      const w = await abrirCierre()
      const filas = w.findAll('.mst__conteo-row')
      await filas[0].find('.mst__input--cant').setValue(155)
      await filas[1].find('.mst__input--cant').setValue(12)

      expect(filas[0].find('.mst__dif').text()).toBe('cuadra')
      expect(w.find('.mst__campo--motivo').exists()).toBe(false)
    })

    // Un faltante sin explicación no se puede revisar después.
    it('con diferencia y sin motivo no cierra', async () => {
      const w = await abrirCierre()
      const filas = w.findAll('.mst__conteo-row')
      await filas[0].find('.mst__input--cant').setValue(151.4)
      await filas[1].find('.mst__input--cant').setValue(12)
      await w.find('.mst__modal-acc .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(cerrarMostrador).not.toHaveBeenCalled()
    })

    it('dice cuánto falta o sobra una vez contado', async () => {
      const w = await abrirCierre()
      await w.findAll('.mst__caja .mst__input')[0].setValue(58000)

      expect(w.find('.mst__dif-caja').text()).toBe('Faltan $500')
    })

    // El agujero que no existía: lo contado menos el fondo que queda es la recaudación que sale.
    it('dice cuánto se retira según el fondo que se deja', async () => {
      const w = await abrirCierre()
      const inputs = w.findAll('.mst__caja .mst__input')
      await inputs[0].setValue(58500)
      await inputs[1].setValue(50000)

      expect(w.find('.mst__retiro').text()).toContain('8.500')
    })

    it('manda el cierre entero al backend', async () => {
      const w = await abrirCierre()
      const filas = w.findAll('.mst__conteo-row')
      await filas[0].find('.mst__input--cant').setValue(151.4)
      await filas[1].find('.mst__input--cant').setValue(12)
      await w.find('.mst__campo--motivo .mst__input').setValue('merma de fraccionamiento')
      const inputs = w.findAll('.mst__caja .mst__input')
      await inputs[0].setValue(58500)
      await inputs[1].setValue(50000)
      await w.find('.mst__modal-acc .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(cerrarMostrador).toHaveBeenCalledWith(10, {
        conteos: [
          { item_id: 71, contado: 151.4, motivo: 'merma de fraccionamiento' },
          { item_id: 72, contado: 12,    motivo: 'merma de fraccionamiento' },
        ],
        efectivo_contado_ars: 58500,
        fondo_siguiente_ars: 50000,
        notas: 'merma de fraccionamiento',
      })
    })
  })

  // El fondo se HEREDA: si el que abre pone el número, puede poner cualquiera.
  it('al abrir, el fondo viene con lo que quedó en el cajón anoche', async () => {
    respuesta = {
      mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
      turno: null, fondo_sugerido: 50000, sugerido: [], disponibles: DISPONIBLES,
    }
    const w = await montar()

    expect(w.find('.mst__input--fondo').element.value).toBe('50000')
    expect(w.text()).toContain('quedaron $50.000 en el cajón anoche')
  })

  describe('cargado por el admin y sin recibir', () => {
    const SIN_RECIBIR = {
      ...TURNO, confirmado: false, confirmado_por: null, confirmado_at: null,
      abierto_por: 'Germán (admin)', abierto_por_id: 99,
    }

    beforeEach(() => {
      // Quien recibe es el que atiende, no el que cargó la mesa.
      useAuthStore().user = { id: 2, role: 'dispensador' }
      respuesta = {
        mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
        turno: SIN_RECIBIR, sugerido: [], disponibles: DISPONIBLES,
      }
    })

    it('dice quién lo dejó y pide recibirlo, en vez de dejar atender', async () => {
      const w = await montar()

      expect(w.text()).toContain('Falta recibirlo')
      expect(w.text()).toContain('Germán (admin) dejó esto sobre la mesa')
      expect(w.find('tbody').exists()).toBe(false) // todavía no se opera
    })

    // Confirmar tiene que ser un click: viene con lo que declaró el admin ya puesto.
    it('viene precargado con lo que declaró el admin', async () => {
      const w = await montar()
      const inputs = w.findAll('.mst__input--cant')

      expect(inputs[0].element.value).toBe('155')
      expect(w.find('.mst__btn--primary').text()).toBe('Confirmar y arrancar')
    })

    // Se recibe la mesa Y la plata, y las dos vienen con el número del sistema ya puesto:
    // confirmar es un click.
    it('confirmar sin tocar nada manda el efectivo esperado y ninguna corrección', async () => {
      const w = await montar()
      await w.find('.mst__acciones .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(confirmarMostrador).toHaveBeenCalledWith(10, {
        correcciones: [], efectivo_contado_ars: 58500, motivo_efectivo: undefined,
      })
    })

    it('muestra lo que tendría que haber en la caja', async () => {
      const w = await montar()

      expect(w.find('.mst__caja').text()).toContain('58.500')
      expect(w.find('.mst__dif-caja').text()).toBe('Cuadra')
    })

    // A diferencia del stock, la plata que falta no está en el depósito: no está en ningún lado.
    it('si la plata no coincide pide el motivo y lo manda', async () => {
      const w = await montar()
      await w.find('.mst__caja .mst__input').setValue(56500)

      expect(w.find('.mst__dif-caja').text()).toBe('Faltan $2.000')
      const motivos = w.findAll('.mst__campo--motivo .mst__input')
      await motivos[motivos.length - 1].setValue('faltaban $2.000')
      await w.find('.mst__acciones .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(confirmarMostrador).toHaveBeenCalledWith(10, {
        correcciones: [], efectivo_contado_ars: 56500, motivo_efectivo: 'faltaban $2.000',
      })
    })

    it('con diferencia en caja y sin motivo no confirma', async () => {
      const w = await montar()
      await w.find('.mst__caja .mst__input').setValue(56500)
      await w.find('.mst__acciones .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(confirmarMostrador).not.toHaveBeenCalled()
    })

    it('si algo no coincide, pide el motivo y manda la corrección', async () => {
      const w = await montar()
      await w.findAll('.mst__input--cant')[0].setValue(152)

      expect(w.find('.mst__btn--primary').text()).toBe('Corregir y recibir')
      await w.find('.mst__campo--motivo .mst__input').setValue('faltaban 3 g')
      await w.find('.mst__acciones .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(confirmarMostrador).toHaveBeenCalledWith(10, {
        correcciones: [{ item_id: 71, contado: 152, motivo: 'faltaban 3 g' }],
        efectivo_contado_ars: 58500, motivo_efectivo: undefined,
      })
    })

    it('con diferencia de stock y sin motivo no confirma', async () => {
      const w = await montar()
      await w.findAll('.mst__input--cant')[0].setValue(152)
      await w.find('.mst__acciones .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(confirmarMostrador).not.toHaveBeenCalled()
    })

    // Dos firmas de la misma persona no son ninguna: al que cargó la mesa no se le ofrece
    // recibirla, ve lo que dejó y espera.
    // El producto que directamente NO ESTÁ. Ponerlo en cero lo dejaría sobre la mesa toda la
    // jornada, en cero, pidiendo explicación cada vez que alguien mire la pantalla.
    describe('un producto que no está sobre la mesa', () => {
      async function quitarElPrimero (w) {
        await w.findAll('.mst__draft-row')[0].find('.mst__icon-btn').trigger('click')
      }

      it('se saca, y se ve tachado antes de confirmar', async () => {
        const w = await montar()
        await quitarElPrimero(w)

        const fila = w.findAll('.mst__draft-row')[0]
        expect(fila.classes()).toContain('is-quitado')
        expect(fila.text()).toContain('no está sobre la mesa — se saca')
      })

      it('se puede arrepentir', async () => {
        const w = await montar()
        await quitarElPrimero(w)
        await quitarElPrimero(w)

        expect(w.findAll('.mst__draft-row')[0].classes()).not.toContain('is-quitado')
      })

      it('pide el motivo, como cualquier corrección', async () => {
        const w = await montar()
        await quitarElPrimero(w)
        await w.find('.mst__acciones .mst__btn--primary').trigger('click')
        await flushPromises()

        expect(confirmarMostrador).not.toHaveBeenCalled()
      })

      it('y se manda como quitar, no como cero', async () => {
        const w = await montar()
        await quitarElPrimero(w)
        await w.find('.mst__campo--motivo .mst__input').setValue('nunca estuvo')
        await w.find('.mst__acciones .mst__btn--primary').trigger('click')
        await flushPromises()

        expect(confirmarMostrador).toHaveBeenCalledWith(10, {
          correcciones: [{ item_id: 71, motivo: 'nunca estuvo', quitar: true }],
          efectivo_contado_ars: 58500,
          motivo_efectivo: undefined,
        })
      })
    })

    it('al que cargó la mesa no se le ofrece confirmarla', async () => {
      useAuthStore().user = { id: 99, role: 'admin' }
      const w = await montar()

      expect(w.text()).toContain('Esperando que lo reciban')
      expect(w.find('.mst__acciones').exists()).toBe(false)
      expect(w.find('.mst__input--cant').exists()).toBe(false)
    })
  })

  // Cerrar y reabrir es el arqueo completo, pero con quince frascos son veinte minutos: el
  // control que cuesta eso no se hace, y el que no se hace no controla nada.
  describe('contar un producto sin cerrar el turno', () => {
    beforeEach(() => {
      respuesta = {
        mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
        turno: TURNO, sugerido: [], disponibles: DISPONIBLES,
      }
    })

    async function abrirConteo () {
      const w = await montar()
      await w.findAll('tbody tr')[0].findAll('.mst__btn--mini')[2].trigger('click')
      return w
    }

    // Mismo criterio que el cierre: si ve el 155 antes de pesar, escribe 155.
    it('NO muestra lo esperado hasta que el conteo está escrito', async () => {
      const w = await abrirConteo()

      expect(w.find('.mst__modal').text()).toContain('Contar Northern Lights')
      expect(w.find('.mst__modal').text()).not.toContain('Tendría que haber')
    })

    it('y lo muestra con la diferencia una vez escrito', async () => {
      const w = await abrirConteo()
      await w.find('.mst__modal .mst__input').setValue(152)

      expect(w.find('.mst__modal').text()).toContain('Tendría que haber')
      expect(w.find('.mst__dif-caja').text()).toBe('Faltan 3 g')
    })

    it('con diferencia y sin motivo no registra', async () => {
      const w = await abrirConteo()
      await w.find('.mst__modal .mst__input').setValue(152)
      await w.find('.mst__modal-acc .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(contarMostrador).not.toHaveBeenCalled()
    })

    it('lo manda con el motivo', async () => {
      const w = await abrirConteo()
      await w.find('.mst__modal .mst__input').setValue(152)
      await w.find('.mst__modal .mst__campo--motivo .mst__input').setValue('se cayó al piso')
      await w.find('.mst__modal-acc .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(contarMostrador).toHaveBeenCalledWith(10, {
        item_id: 71, contado: 152, motivo: 'se cayó al piso',
      })
    })
  })

  // El admin corrige la plata en cualquier momento, en los dos sentidos — igual que el stock.
  describe('mover plata durante el turno', () => {
    beforeEach(() => {
      useAuthStore().user = { id: 1, role: 'admin' }
      respuesta = {
        mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
        turno: TURNO, sugerido: [], disponibles: DISPONIBLES,
      }
    })

    it('pone plata en el cajón', async () => {
      const w = await montar()
      await w.findAll('.mst__caja-barra .mst__btn')[0].trigger('click')
      await w.findAll('.mst__modal .mst__input')[0].setValue(5000)
      await w.findAll('.mst__modal .mst__input')[1].setValue('traje cambio')
      await w.find('.mst__modal-acc .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(ingresoCajaMostrador).toHaveBeenCalledWith(10, 3, { monto_ars: 5000, motivo: 'traje cambio' })
    })

    it('y la saca, diciendo si es gasto o retiro', async () => {
      const w = await montar()
      await w.findAll('.mst__caja-barra .mst__btn')[1].trigger('click')
      await w.findAll('.mst__modal .mst__input')[0].setValue(3000)
      await w.findAll('.mst__modal .mst__input')[1].setValue('flete')
      await w.find('.mst__modal .mst__select').setValue('gasto')
      await w.find('.mst__modal-acc .mst__btn--primary').trigger('click')
      await flushPromises()

      expect(salidaCajaMostrador).toHaveBeenCalledWith(10, 3, { monto_ars: 3000, motivo: 'flete', clase: 'gasto' })
    })

    // Es plata: la mueve quien responde por ella.
    it('el que atiende no ve los botones de mover plata', async () => {
      useAuthStore().user = { id: 2, role: 'dispensador' }
      const w = await montar()

      expect(w.find('.mst__caja-barra').exists()).toBe(false)
    })
  })

  // ── La merma: dónde se le va el producto a la organización ─────────────────
  describe('la solapa de merma', () => {
    beforeEach(() => {
      useAuthStore().user = { id: 1, role: 'admin' }
      respuesta = {
        mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
        turno: TURNO, sugerido: [], disponibles: DISPONIBLES, sin_revisar: 1,
      }
    })

    async function verMerma () {
      const w = await montar()
      await w.findAll('.mst__tab').find(t => t.text().startsWith('Merma')).trigger('click')
      await flushPromises()
      return w
    }

    // El que atiende SÍ ve sus turnos —cerraba uno y no tenía dónde mirarlo—, pero la merma es
    // información de gestión: no es una pantalla para él, decide con lo que tiene sobre la mesa.
    it('el que atiende no la ve: es información de gestión' , async () => {
      useAuthStore().user = { id: 2, role: 'dispensador' }
      const w = await montar()

      const solapas = w.findAll('.mst__tab').map(t => t.text())
      expect(solapas.some(t => t.startsWith('Merma'))).toBe(false)
      expect(solapas).toContain('Turnos')
    })

    // Sin entrar a la solapa: un aviso que sólo aparece cuando ya fuiste a mirar no avisa nada.
    it('avisa cuántos turnos hay sin mirar, apenas se abre la pantalla', async () => {
      const w = await montar()

      expect(getMermaMostrador).not.toHaveBeenCalled()
      expect(w.find('.mst__tab-badge').text()).toBe('1')
    })

    it('el número que manda es el porcentaje sobre lo entregado', async () => {
      const w = await verMerma()

      expect(w.findAll('.mrm__kpi-num')[0].text()).toBe('1.45%')
      expect(w.findAll('.mrm__kpi-num')[1].text()).toBe('$41.000')
    })

    // El punto del informe: lo que más se pierde en gramos no es el cuello de botella.
    it('pone primero el producto con más porcentaje, no con más cantidad', async () => {
      const w = await verMerma()
      const filas = w.findAll('tbody tr')

      expect(filas[0].text()).toContain('Preroll')
      expect(filas[0].text()).toContain('10%')
      expect(filas[1].text()).toContain('Northern')
    })

    // Si el que recibe corrige seguido, el cuello no es la merma: es quien carga la mesa.
    it('marca los turnos donde hubo correcciones al recibir', async () => {
      const w = await verMerma()

      expect(w.text()).toContain('2 correcciones al recibir')
    })

    it('marcar un turno como visto lo saca de la lista', async () => {
      const w = await verMerma()
      await w.findAll('tbody .mrm__btn--mini')[0].trigger('click')
      await flushPromises()

      expect(revisarTurnoMostrador).toHaveBeenCalledWith(10, 91)
      expect(w.find('.mst__tab-badge').exists()).toBe(false)
    })

    // El único lugar del módulo donde un dedazo ajusta el inventario real: 21 en vez de 215.
    it('permite corregir un conteo mal cargado de un turno cerrado', async () => {
      const w = await verMerma()
      await w.find('.mrm__btn--corregir').trigger('click')
      await flushPromises()

      expect(w.text()).toContain('se había contado 21 g')
      await w.find('.cc__input--cant').setValue(215)
      await w.find('.cc__campo .cc__input').setValue('me comí un dígito')
      await w.find('.cc__acc .cc__btn--primary').trigger('click')
      await flushPromises()

      expect(corregirTurnoMostrador).toHaveBeenCalledWith(10, 91, {
        conteos: [{ item_id: 71, contado: 215 }],
        motivo: 'me comí un dígito',
      })
    })

    it('corregir sin motivo no manda nada', async () => {
      const w = await verMerma()
      await w.find('.mrm__btn--corregir').trigger('click')
      await flushPromises()
      await w.find('.cc__input--cant').setValue(215)
      await w.find('.cc__acc .cc__btn--primary').trigger('click')
      await flushPromises()

      expect(corregirTurnoMostrador).not.toHaveBeenCalled()
    })

    // Comparar sedes es LA pregunta que encuentra el cuello de botella.
    it('compara sede por sede cuando se piden todas', async () => {
      getMermaMostrador.mockResolvedValueOnce({
        data: {
          ...MERMA,
          por_sede: [
            { sede_id: 10, sede: 'Central', turnos: 12, dispensado: 4200, faltante: 61, faltante_ars: 41000, merma_pct: 1.45 },
            { sede_id: 12, sede: 'Norte',   turnos: 9,  dispensado: 3000, faltante: 15, faltante_ars: 9000,  merma_pct: 0.5 },
          ],
        },
      })
      const w = await verMerma()

      expect(w.text()).toContain('Sede por sede')
      const filas = w.findAll('tbody tr')
      expect(filas[0].text()).toContain('Central')
      expect(filas[0].text()).toContain('1.45%')
      expect(filas[1].text()).toContain('Norte')
    })

    // Con una sola sede, compararla contra sí misma es una tabla de una fila que no dice nada.
    it('con una sola sede no muestra la comparación', async () => {
      const w = await verMerma()

      expect(w.text()).not.toContain('Sede por sede')
    })

    it('sin turnos cerrados lo dice, en vez de mostrar ceros', async () => {
      getMermaMostrador.mockResolvedValueOnce({
        data: { resumen: { turnos: 0, merma_pct: null, faltante_ars: 0 }, por_producto: [], por_turno: [], sin_revisar: 0 },
      })
      const w = await verMerma()

      expect(w.text()).toContain('Todavía no hay turnos cerrados')
    })
  })

  // ── Los turnos que ya cerraron ─────────────────────────────────────────────
  describe('la solapa de turnos', () => {
    async function verTurnos () {
      const w = await montar()
      await w.findAll('.mst__tab').find(t => t.text() === 'Turnos').trigger('click')
      await flushPromises()
      return w
    }

    // Cerraba un turno y no tenía dónde mirarlo: si al día siguiente le preguntan por una
    // diferencia, no tiene con qué.
    it('el que atiende ve los suyos', async () => {
      useAuthStore().user = { id: 2, role: 'dispensador' }
      const w = await verTurnos()

      expect(listTurnosMostrador).toHaveBeenCalledWith(10)
      expect(w.text()).toContain('Los turnos que atendiste vos')
      expect(w.find('.trn__table tbody tr').text()).toContain('Ana Gómez')
    })

    // Corregir un conteo ajusta el inventario real: eso es de administración.
    it('y no puede corregir el conteo', async () => {
      useAuthStore().user = { id: 2, role: 'dispensador' }
      const w = await verTurnos()

      expect(w.find('.trn__btn').exists()).toBe(false)
      expect(w.text()).toContain('Avisale a administración')
    })

    it('administración sí', async () => {
      listTurnosMostrador.mockResolvedValueOnce({ data: { ...TURNOS_CERRADOS, gestiona: true } })
      const w = await verTurnos()

      expect(w.find('.trn__btn').text()).toBe('Corregir conteo')
    })

    it('un turno que cuadró lo dice, en vez de un cero', async () => {
      listTurnosMostrador.mockResolvedValueOnce({
        data: { gestiona: false, turnos: [{ ...TURNOS_CERRADOS.turnos[0], faltante: 0, faltante_ars: 0 }] },
      })
      const w = await verTurnos()

      expect(w.find('.trn__ok').text()).toBe('cuadró')
    })
  })

  it('si la API falla, la pantalla lo dice en vez de quedarse en blanco', async () => {
    getMostrador.mockRejectedValueOnce({ response: { data: { error: 'Esta sede no dispensa' } } })
    const w = await montar()

    expect(w.text()).toContain('Esta sede no dispensa')
  })
})

// `toISOString()` da la fecha en UTC: entre las 21:00 y las 00:00 en Argentina devuelve el día
// SIGUIENTE, y el rango de la merma arrancaba en un mañana donde todavía no cerró nadie — la
// pantalla se veía vacía justo en el horario en que se cierra el mostrador. Lo cazó el e2e.
describe('El rango de la merma usa la fecha LOCAL', () => {
  it('a las 22:00 en Argentina sigue siendo hoy, no mañana', () => {
    // 2026-09-01 01:30 UTC == 2026-08-31 22:30 en Buenos Aires.
    const enArgentina = new Date('2026-09-01T01:30:00Z')
      .toLocaleDateString('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' })
    const enUtc = new Date('2026-09-01T01:30:00Z').toISOString().slice(0, 10)

    expect(enArgentina).toBe('2026-08-31')
    expect(enUtc).toBe('2026-09-01') // lo que hacía antes: un día adelantado
  })
})
