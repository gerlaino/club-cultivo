import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// `MostradorView` lee `?sede=` para saber a qué sede llegar desde "Cajas del día": sin este
// mock, `useRoute()` explota por falta de router en el árbol de montaje.
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {} }),
}))

// LA PANTALLA DEL MOSTRADOR, montada de verdad.
//
// Para una organización que sólo dispensa es LA pantalla del día, así que un build limpio no
// alcanza: acá se monta con la API respondiendo y se recorre el flujo entero. Ya pasó cuatro
// veces en este proyecto que algo compilara perfecto y explotara al abrirse.
//
// Son DOS cosas separadas, de personas distintas:
//   · QUÉ HAY sobre la mesa → lo gobierna administración, cuando quiera y desde donde esté
//   · LA CAJA               → la abre y la cierra quien atiende, contando

const SEDES = [
  { id: 10, nombre: 'Central', tipo: 'social' },
  { id: 11, nombre: 'Vivero',  tipo: 'produccion' }, // no dispensa: no tiene mostrador
]

const FLOR = {
  stock_id: 1, etiqueta: 'Northern Lights (flor seca)', numero: 'ST-26-0031', forma: 'flor_seca',
  unidad: 'g', lote: 'L-26-002', genetica: 'Northern Lights', fecha: '2026-06-10',
  precio_ars: 1200, costo_ars: 200, disponible: 500,
}
const PREROLL = {
  stock_id: 2, etiqueta: 'Preroll', numero: 'ST-26-0061', forma: 'preroll',
  unidad: 'un', lote: null, genetica: null, fecha: '2026-07-02',
  precio_ars: 2500, costo_ars: 800, disponible: 120,
}

const TURNO = {
  id: 7, estado: 'abierto', abierto_at: '2026-09-02T09:02:00Z', abierto_por: 'Ana Gómez',
  abierto_por_id: 2, caja_turno_id: 3, valor_mesa_ars: 68000,
  caja: { id: 3, fondo_ars: 50000, cobrado_efectivo_ars: 8500, cobrado_digital_ars: 0,
          salidas_ars: 0, esperado_ars: 58500 },
  conteo_apertura: [],
}

let respuesta = {}
const getMostrador    = vi.fn(() => Promise.resolve({ data: respuesta }))
const cargarMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const abrirMostrador  = vi.fn(() => Promise.resolve({ data: {} }))
const cerrarMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const contarMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const ingresoCajaMostrador = vi.fn(() => Promise.resolve({ data: {} }))
const salidaCajaMostrador  = vi.fn(() => Promise.resolve({ data: {} }))

let avisarDelCanal = () => {}
vi.mock('../composables/useStockChannel.js', () => ({
  useStockChannel: (_onStock, onEvento) => { avisarDelCanal = onEvento || (() => {}) },
}))
vi.mock('../lib/api.js', () => ({
  getMostrador:    (...a) => getMostrador(...a),
  cargarMostrador: (...a) => cargarMostrador(...a),
  abrirMostrador:  (...a) => abrirMostrador(...a),
  cerrarMostrador: (...a) => cerrarMostrador(...a),
  ingresoCajaMostrador: (...a) => ingresoCajaMostrador(...a),
  salidaCajaMostrador:  (...a) => salidaCajaMostrador(...a),
  getMermaMostrador: vi.fn(() => Promise.resolve({ data: { resumen: { turnos: 0 }, por_producto: [], por_turno: [] } })),
  contarMostrador: (...a) => contarMostrador(...a),
  revisarTurnoMostrador: vi.fn(), getTurnoMostrador: vi.fn(), corregirTurnoMostrador: vi.fn(),
  listTurnosMostrador: vi.fn(() => Promise.resolve({ data: { turnos: [], gestiona: false } })),
  listRendiciones: vi.fn(() => Promise.resolve({ data: { rendiciones: [] } })),
  receptoresRendicion: vi.fn(() => Promise.resolve({ data: [] })),
  crearRendicion: vi.fn(), recibirRendicion: vi.fn(), conformarRendicion: vi.fn(),
  listSedes: vi.fn(() => Promise.resolve({ data: SEDES })),
}))

import MostradorView from '../views/MostradorView.vue'
import { useSedeStore } from '../stores/sede.js'
import { useAuthStore } from '../stores/auth.js'

async function montar (rol = 'admin', extra = {}) {
  useAuthStore().user = { id: 1, role: rol, ...extra }
  const w = mount(MostradorView, { global: { stubs: { RouterLink: true } } })
  await flushPromises()
  await flushPromises()
  return w
}

const fila  = (w, n) => w.findAll('.tmo__table tbody tr')[n]
const filas = (w) => w.findAll('.tmo__table tbody tr')

beforeEach(() => {
  setActivePinia(createPinia())
  const sede = useSedeStore()
  sede.sedes = SEDES
  sede.loaded = true
  vi.clearAllMocks()
  respuesta = {
    mostrador: { id: 1, nombre: 'Mostrador', sede: { id: 10, nombre: 'Central' } },
    mesa: [], turno: null, disponibles: [FLOR, PREROLL],
    puedo: { cargar: true, abrir: true, cerrar: false }, fondo_sugerido: 50000,
  }
})

describe('La mesa, que gobierna administración', () => {
  it('lista el stock de la sede con DEPÓSITO y MOSTRADOR como dos columnas', async () => {
    const w = await montar()

    expect(filas(w)).toHaveLength(2)
    const th = w.findAll('.tmo__th').map(t => t.text())
    expect(th.join(' ')).toContain('Depósito')
    expect(th.join(' ')).toContain('Mostrador')
  })

  // Antes la primera columna decía "LO (flor seca)" y la de al lado "LO": el mismo dato dos
  // veces, y la forma —que es lo que distingue un frasco de un preroll— entre paréntesis.
  it('Producto es la forma y Variedad la genética: no el mismo dato dos veces', async () => {
    const w = await montar()

    expect(fila(w, 0).find('.tmo__prod').text()).toBe('Flor seca')
    expect(fila(w, 0).text()).toContain('Northern Lights')
    expect(fila(w, 0).find('.tmo__prod').text()).not.toContain('Northern')
  })

  it('muestra lo que ya está sobre la mesa', async () => {
    respuesta = { ...respuesta, mesa: [{ ...FLOR, mostrador: 300 }] }
    const w = await montar()

    const flor = filas(w).find(f => f.text().includes('Northern'))
    expect(flor.find('.tmo__input').element.value).toBe('300')
    expect(flor.classes()).toContain('is-en-mesa')
  })

  // Se escribe el TOTAL que tiene que quedar, no la diferencia: pedirle al usuario que calcule
  // el delta es pedirle la cuenta que hace la máquina.
  it('se escribe el total y se guarda con motivo', async () => {
    const w = await montar()
    await fila(w, 0).find('.tmo__input').setValue(300)
    await w.find('.mst__btn--guardar').trigger('click')
    await w.find('.cmm__input').setValue('carga del lunes')
    await w.find('.cmm__btn--primary').trigger('click')
    await flushPromises()

    expect(cargarMostrador).toHaveBeenCalledWith(10, {
      cambios: [{ stock_id: 1, cantidad: 300 }],
      motivo: 'carga del lunes',
    })
  })

  // Con buscador y orden de por medio, lo tocado puede no estar todo en pantalla al guardar: el
  // modal muestra la lista completa con el antes y el después ANTES de pedir el motivo.
  it('el modal muestra qué cambia, con el antes y el después', async () => {
    respuesta = { ...respuesta, mesa: [{ ...FLOR, mostrador: 120 }] }
    const w = await montar()
    const flor = filas(w).find(f => f.text().includes('Northern'))
    await flor.find('.tmo__input').setValue(300)
    await w.find('.mst__btn--guardar').trigger('click')

    const row = w.find('.cmm__row')
    expect(row.classes()).toContain('is-sube')
    expect(row.find('.cmm__antes').text()).toBe('120')
    expect(row.find('.cmm__ahora').text()).toContain('300')
    expect(row.find('.cmm__delta').text()).toContain('+180')
  })

  // BAJAR NO SIEMPRE ES "VUELVE AL DEPÓSITO": si se perdió, esos gramos tienen que salir del
  // inventario. Devolverlos al depósito los deja contados como existentes y la pérdida no se
  // mide en ningún lado.
  describe('a dónde va lo que baja', () => {
    beforeEach(() => { respuesta = { ...respuesta, mesa: [{ ...FLOR, mostrador: 300 }] } })

    async function bajarA (w, cantidad) {
      const flor = filas(w).find(f => f.text().includes('Northern'))
      await flor.find('.tmo__input').setValue(cantidad)
      await w.find('.mst__btn--guardar').trigger('click')
    }

    it('por defecto vuelve al depósito y no manda destino', async () => {
      const w = await montar()
      await bajarA(w, 120)
      await w.find('.cmm__input').setValue('sobró de la mañana')
      await w.find('.cmm__btn--primary').trigger('click')
      await flushPromises()

      expect(cargarMostrador).toHaveBeenCalledWith(10, {
        cambios: [{ stock_id: 1, cantidad: 120, destino: 'deposito' }],
        motivo: 'sobró de la mañana',
      })
    })

    it('marcado como perdido, lo dice y avisa que sale del inventario', async () => {
      const w = await montar()
      await bajarA(w, 120)
      await w.findAll('.cmm__chip--merma')[0].trigger('click')

      expect(w.find('.cmm__aviso-merma').text()).toContain('sale del inventario')

      await w.find('.cmm__input').setValue('se cayó el frasco')
      await w.find('.cmm__btn--primary').trigger('click')
      await flushPromises()

      expect(cargarMostrador).toHaveBeenCalledWith(10, {
        cambios: [{ stock_id: 1, cantidad: 120, destino: 'merma' }],
        motivo: 'se cayó el frasco',
      })
    })

    // Subir viene del depósito: no hay nada que declarar.
    it('lo que SUBE no pregunta a dónde va', async () => {
      const w = await montar()
      await bajarA(w, 400)

      expect(w.find('.cmm__destino').exists()).toBe(false)
    })
  })

  // Bajar a cero NO borra la fila ni su historial: deja de listarse. Decirlo evita que parezca
  // que se está eliminando el producto.
  it('avisa cuando un producto sale de la mesa', async () => {
    respuesta = { ...respuesta, mesa: [{ ...FLOR, mostrador: 120 }] }
    const w = await montar()
    const flor = filas(w).find(f => f.text().includes('Northern'))
    await flor.find('.tmo__input').setValue(0)
    await w.find('.mst__btn--guardar').trigger('click')

    expect(w.find('.cmm__row').classes()).toContain('is-baja')
    expect(w.find('.cmm__chip-sale').text()).toContain('sale de la mesa')
  })

  // Un cambio de mesa sin motivo es un número que aparece: el backend lo rechaza igual, pero
  // ofrecer el botón para que rebote es el peor error posible.
  it('sin motivo no deja guardar', async () => {
    const w = await montar()
    await fila(w, 0).find('.tmo__input').setValue(300)
    await w.find('.mst__btn--guardar').trigger('click')

    expect(w.find('.cmm__btn--primary').attributes('disabled')).toBeDefined()
  })

  // Los motivos de siempre a un click: sin esto se escribe la palabra más corta que cierre el
  // modal, y el historial de la mesa —que es lo que se quería guardar— no dice nada.
  it('ofrece motivos sugeridos, distintos según se suba o se baje', async () => {
    const w = await montar()
    await fila(w, 0).find('.tmo__input').setValue(300)
    await w.find('.mst__btn--guardar').trigger('click')

    const chips = w.findAll('.cmm__chip')
    expect(chips.map(c => c.text())).toContain('Reposición del turno')
    await chips[0].trigger('click')
    expect(w.find('.cmm__input').element.value).toBe('Reposición del turno')
    expect(w.find('.cmm__btn--primary').attributes('disabled')).toBeUndefined()
  })

  it('avisa si se pide más de lo que hay libre en el depósito', async () => {
    const w = await montar()
    await fila(w, 1).find('.tmo__input').setValue(500) // hay 120

    expect(fila(w, 1).text()).toContain('quedan 120')
    expect(fila(w, 1).find('.tmo__input').classes()).toContain('is-mal')
  })

  // El backend lo rechaza igual: dejar apretar para que rebote parece culpa del usuario.
  it('y con exceso no deja ni abrir el modal', async () => {
    const w = await montar()
    await fila(w, 1).find('.tmo__input').setValue(500) // hay 120

    expect(w.find('.mst__btn--guardar').attributes('disabled')).toBeDefined()
  })

  it('se busca y se ordena por columna', async () => {
    const w = await montar()
    await w.find('.tmo__buscar').setValue('preroll')
    expect(filas(w)).toHaveLength(1)

    await w.find('.tmo__buscar').setValue('')
    await w.findAll('.tmo__th-btn')[0].trigger('click')
    expect(fila(w, 0).find('.tmo__prod').text()).toBe('Flor seca')
    await w.findAll('.tmo__th-btn')[0].trigger('click')
    expect(fila(w, 0).find('.tmo__prod').text()).toBe('Preroll')
  })

  // Con buscador de por medio, lo escrito puede no estar en pantalla.
  it('lo cargado sobrevive al buscador', async () => {
    const w = await montar()
    await fila(w, 1).find('.tmo__input').setValue(40)
    await w.find('.tmo__buscar').setValue('northern')

    expect(filas(w)).toHaveLength(1)
    expect(w.find('.tmo__pie').text()).toContain('1 cambio sin guardar')
  })
})

// Quien atiende NUNCA elige qué hay: cuenta lo que encuentra.
describe('Lo que ve quien atiende', () => {
  beforeEach(() => {
    respuesta = { ...respuesta, mesa: [{ ...FLOR, mostrador: 300 }],
                  puedo: { cargar: false, abrir: true, cerrar: false } }
  })

  it('ve la mesa, sin poder editarla', async () => {
    const w = await montar('dispensador')

    expect(filas(w)).toHaveLength(1)
    expect(w.find('.tmo__input').exists()).toBe(false)
    expect(w.find('.tmo__mesa').text()).toBe('300')
  })

  it('y no ve el costo: no responde por eso', async () => {
    const w = await montar('dispensador')

    expect(w.findAll('.tmo__th').map(t => t.text()).join(' ')).not.toContain('Costo')
  })

  // Cerrar y reabrir con quince frascos son veinte minutos: el control que cuesta eso no se
  // hace, y el que no se hace no controla nada. El servicio existía sin pantalla.
  describe('contar un producto sin cerrar la caja', () => {
    // Es un control DEL TURNO: se cuenta mientras se atiende. Con la caja cerrada el gesto es
    // abrir, que ya cuenta todo.
    beforeEach(() => { respuesta = { ...respuesta, turno: TURNO } })

    it('quien atiende puede contar una fila suelta', async () => {
      const w = await montar('dispensador')

      expect(w.find('.tmo__contar').exists()).toBe(true)
    })

    it('con la caja cerrada no se ofrece: ahí el gesto es abrir, que cuenta todo', async () => {
      respuesta = { ...respuesta, turno: null }
      const w = await montar('dispensador')

      expect(w.find('.tmo__contar').exists()).toBe(false)
    })

    // Administración no cuenta a distancia: su gesto sobre la mesa es decir cuánto tiene que
    // haber, que mueve producto del depósito. Contar se hace con el frasco en la mano.
    it('administración no: ella carga, no cuenta', async () => {
      respuesta = { ...respuesta, mesa: [{ ...FLOR, mostrador: 300 }] }
      const w = await montar()

      expect(w.find('.tmo__contar').exists()).toBe(false)
    })

    // LO ESPERADO SE VE MIENTRAS SE CUENTA (sep-2026). Se escondía para que nadie escribiera el
    // número que tenía delante en vez de terminar de pesar; pesó más poder salir a buscar la
    // diferencia en el momento, con el frasco en la mano. Lo que se guarda sigue siendo lo
    // contado.
    it('dice cuánto debería haber mientras se cuenta, y no tapa la mesa de atrás', async () => {
      const w = await montar('dispensador')
      await w.find('.tmo__contar').trigger('click')

      expect(w.find('.cti__esperado').text()).toContain('300')
      expect(w.find('.tmo__mesa').text()).toBe('300')
    })

    it('y lo compara apenas se escribe', async () => {
      const w = await montar('dispensador')
      await w.find('.tmo__contar').trigger('click')
      await w.find('.cti__input').setValue(280)

      const comp = w.find('.cti__comparacion')
      expect(comp.text()).toContain('300')
      expect(comp.text()).toContain('280')
      expect(w.find('.cti__comp-dif').text()).toContain('−20')
    })

    // Acá la diferencia SÍ ajusta el inventario: el producto estaba sobre la mesa y no está.
    // Sin motivo el backend lo rechaza, así que el botón no se habilita.
    it('con diferencia pide el motivo', async () => {
      const w = await montar('dispensador')
      await w.find('.tmo__contar').trigger('click')
      await w.find('.cti__input').setValue(280)

      expect(w.find('.cti__btn--primary').attributes('disabled')).toBeDefined()
      await w.find('.cti__input--texto').setValue('se fraccionó para prerolls')
      expect(w.find('.cti__btn--primary').attributes('disabled')).toBeUndefined()
    })

    it('si cuadra, no pide nada y se registra', async () => {
      const w = await montar('dispensador')
      await w.find('.tmo__contar').trigger('click')
      await w.find('.cti__input').setValue(300)

      expect(w.find('.cti__input--texto').exists()).toBe(false)
      await w.find('.cti__btn--primary').trigger('click')
      await flushPromises()

      expect(contarMostrador).toHaveBeenCalledWith(10, { stock_id: 1, contado: 300, motivo: undefined })
    })
  })
})

describe('Abrir y cerrar la caja', () => {
  // LO QUE ABRE Y CIERRA ES LA CAJA, NO EL MOSTRADOR: desde que la mesa dejó de ser del turno,
  // un "Cerrado" con 300 g arriba se contradice con lo que la persona está mirando.
  it('con la caja cerrada ofrece abrirla, y lo dice sin confundir con la mesa', async () => {
    const w = await montar()

    expect(w.find('.mst__estado').text()).toBe('Caja cerrada')
    expect(w.find('.mst__turno-acc .mst__btn').text()).toBe('Abrir caja')
  })

  it('con la caja abierta el estado lo dice igual de claro', async () => {
    respuesta = { ...respuesta, turno: TURNO }
    const w = await montar()

    expect(w.find('.mst__estado').text()).toBe('Caja abierta')
  })

  it('con la caja abierta dice quién y ofrece cerrarla', async () => {
    respuesta = { ...respuesta, turno: TURNO, mesa: [{ ...FLOR, mostrador: 300 }] }
    const w = await montar()

    expect(w.text()).toContain('Ana Gómez')
    expect(w.find('.mst__turno-acc .mst__btn').text()).toBe('Cerrar caja')
  })

  describe('el conteo', () => {
    beforeEach(() => {
      respuesta = { ...respuesta, mesa: [{ ...FLOR, mostrador: 300 }] }
    })

    async function abrirModal (w) {
      await w.find('.mst__turno-acc .mst__btn').trigger('click')
      await flushPromises()
    }

    // Lo esperado acompaña cada campo desde que se abre el modal: la plata y los gramos.
    it('al ABRIR dice los gramos y el fondo que dejó el cierre anterior', async () => {
      const w = await montar()
      await abrirModal(w)

      expect(w.find('.cnt__esperado').text()).toContain('300')
      expect(w.find('.cnt__esperado-plata').text()).toContain('50.000')
    })

    it('al CERRAR dice lo que tendría que haber en el cajón', async () => {
      respuesta = { ...respuesta, turno: TURNO }
      const w = await montar()
      await abrirModal(w)

      expect(w.find('.cnt__esperado-plata').text()).toContain('58.500')
    })

    it('y la comparación aparece, grande y clara, apenas se escribe', async () => {
      const w = await montar()
      await abrirModal(w)
      await w.find('.cnt__cant .cnt__input').setValue(295)

      const comp = w.find('.cnt__comparacion')
      expect(comp.exists()).toBe(true)
      expect(comp.text()).toContain('Debería haber')
      expect(comp.text()).toContain('300')
      expect(comp.text()).toContain('295')
      expect(comp.text()).toContain('−5')
    })

    // La merma es inevitable y no es culpa de nadie: se anota, no frena.
    it('la diferencia no bloquea', async () => {
      const w = await montar()
      await abrirModal(w)
      await w.find('.cnt__cant .cnt__input').setValue(295)

      expect(w.find('.cnt__comparacion').text()).toContain('podés abrir igual')
      expect(w.find('.cnt__acc .cnt__btn--primary').attributes('disabled')).toBeUndefined()
    })

    // CONTAR DE MÁS NO PONE PRODUCTO SOBRE LA MESA, y se dice MIENTRAS se escribe el número:
    // después de confirmar, la persona ya se fue creyendo que la mesa quedó en lo que contó.
    it('a quien atiende le avisa que un sobrante no se carga', async () => {
      const w = await montar('dispensador')
      await abrirModal(w)
      await w.find('.cnt__cant .cnt__input').setValue(1500)

      const aviso = w.find('.cnt__nota--sobrante')
      expect(aviso.exists()).toBe(true)
      expect(aviso.text()).toContain('sobrante')
      expect(aviso.text()).toContain('la mesa sigue como está')
      // Y NO bloquea: abrir nunca bloquea.
      expect(w.find('.cnt__acc .cnt__btn--primary').attributes('disabled')).toBeUndefined()
    })

    it('y a administración no, porque ella sí gobierna la mesa', async () => {
      const w = await montar('admin')
      await abrirModal(w)
      await w.find('.cnt__cant .cnt__input').setValue(1500)

      expect(w.find('.cnt__nota--sobrante').exists()).toBe(false)
    })

    it('contar de MENOS no dispara ese aviso: eso sí se aplica', async () => {
      const w = await montar('dispensador')
      await abrirModal(w)
      await w.find('.cnt__cant .cnt__input').setValue(295)

      expect(w.find('.cnt__nota--sobrante').exists()).toBe(false)
    })

    // AL CERRAR, LOS CAMPOS LLEGAN CON UN NÚMERO. Quien atiende no puede retirar: si dejaba el
    // fondo vacío, el modal le anunciaba un retiro a su nombre y tenía que volver a escribir el
    // número que acababa de contar.
    it('al CERRAR el efectivo arranca con lo esperado y el fondo con lo mismo', async () => {
      respuesta = { ...respuesta, turno: TURNO }
      const w = await montar('dispensador')
      await abrirModal(w)

      const plata = w.findAll('.cnt__input--plata')
      expect(Number(plata[0].element.value)).toBe(58500)   // debería haber
      expect(Number(plata[1].element.value)).toBe(58500)   // y dejo todo
      expect(w.find('.cnt__retiro').exists()).toBe(false)  // no se retira nada
    })

    it('a administración el fondo NO se le llena: ella sí se lleva la recaudación', async () => {
      respuesta = { ...respuesta, turno: TURNO }
      const w = await montar('admin')
      await abrirModal(w)

      const plata = w.findAll('.cnt__input--plata')
      expect(Number(plata[0].element.value)).toBe(58500)
      expect(plata[1].element.value).toBe('')
      expect(w.find('.cnt__retiro').text()).toContain('58.500')
    })

    it('al ABRIR no se llena nada: ahí el número es lo que hay en el cajón', async () => {
      const w = await montar('dispensador')
      await abrirModal(w)

      expect(w.find('.cnt__input--plata').element.value).toBe('')
    })

    it('manda el conteo y el efectivo al abrir', async () => {
      const w = await montar()
      await abrirModal(w)
      await w.find('.cnt__cant .cnt__input').setValue(295)
      await w.find('.cnt__input--plata').setValue(50000)
      await w.find('.cnt__acc .cnt__btn--primary').trigger('click')
      await flushPromises()

      expect(abrirMostrador).toHaveBeenCalledWith(10, expect.objectContaining({
        conteos: [{ stock_id: 1, contado: 295 }],
        efectivo_contado_ars: 50000,
      }))
    })

    it('y al cerrar manda todo, aunque no se haya tocado', async () => {
      respuesta = { ...respuesta, turno: TURNO }
      const w = await montar()
      await abrirModal(w)
      await w.find('.cnt__input--plata').setValue(58500)
      await w.find('.cnt__acc .cnt__btn--primary').trigger('click')
      await flushPromises()

      expect(cerrarMostrador).toHaveBeenCalledWith(10, expect.objectContaining({
        conteos: [{ stock_id: 1, contado: 300 }],
      }))
    })

    it('al cerrar muestra el retiro de lo que no queda de fondo', async () => {
      respuesta = { ...respuesta, turno: TURNO }
      const w = await montar()
      await abrirModal(w)
      await w.findAll('.cnt__input--plata')[0].setValue(58500)
      await w.findAll('.cnt__input--plata')[1].setValue(50000)

      expect(w.find('.cnt__retiro').text()).toContain('8.500')
    })
  })
})

// Si administración le sacó 200 g a las 15:40 y no lo ve, cierra con un faltante que no es suyo
// y encima no lo puede explicar.
describe('Lo que administración tocó durante el turno', () => {
  it('se le muestra a quien está atendiendo', async () => {
    respuesta = {
      ...respuesta, turno: TURNO,
      mesa: [{ ...FLOR, mostrador: 100, movimientos_del_turno: [
        { tipo: 'retiro', cantidad: -200, motivo: 'me lo llevo a la otra sede',
          usuario: 'Germán', cuando: '2026-09-02T18:40:00Z' },
      ] }],
      puedo: { cargar: false, abrir: true, cerrar: true },
    }
    const w = await montar('dispensador')

    const movs = w.find('.mst__movs')
    expect(movs.exists()).toBe(true)
    expect(movs.text()).toContain('Germán')
    expect(movs.text()).toContain('bajó')
    expect(movs.text()).toContain('200')
    expect(movs.text()).toContain('me lo llevo a la otra sede')
  })
})

describe('Mientras carga', () => {
  // El watcher de la sede corre con `immediate` ANTES de que `onMounted` la fije: si en esa
  // ventana se pintara la pantalla vacía, un instante después se rearmaría y lo que la persona
  // hubiera empezado a escribir se perdería sin que hubiera tocado nada.
  it('muestra el esqueleto, no una pantalla vacía que después se rearma', async () => {
    const w = mount(MostradorView, { global: { stubs: { RouterLink: true } } })

    expect(w.find('.mst__skel').exists()).toBe(true)
    expect(w.find('.tmo__buscar').exists()).toBe(false)
  })

  // La mesa se recarga sola con cada aviso del canal: si eso desmontara la pantalla, al que está
  // eligiendo qué bajar se le borra lo que escribió.
  it('el aviso del canal refresca sin desmontar', async () => {
    const w = await montar()
    await w.find('.tmo__buscar').setValue('preroll')

    avisarDelCanal({ tipo: 'mostrador_actualizado', sede_id: 10 })
    await new Promise(r => setTimeout(r, 350))
    await flushPromises()

    expect(w.find('.mst__skel').exists()).toBe(false)
    expect(w.find('.tmo__buscar').element.value).toBe('preroll')
    expect(getMostrador).toHaveBeenCalledTimes(2)
  })
})

// QUIEN ATIENDE ABRE LA CAJA EN SU MOSTRADOR. Aterrizar en el de otra sede le muestra una mesa
// vacía y ninguna caja abierta: la pantalla le dice que no hizo lo que acaba de hacer.
describe('Con qué sede arranca la pantalla', () => {
  const DOS_SEDES = [
    { id: 10, nombre: 'Central', tipo: 'social' },
    { id: 12, nombre: 'Norte',   tipo: 'social' },
  ]

  beforeEach(() => {
    const sede = useSedeStore()
    sede.sedes = DOS_SEDES
    sede.loaded = true
  })

  it('la del usuario antes que la primera de la lista', async () => {
    await montar('dispensador', { dispensario_sede: { id: 12, nombre: 'Norte' } })

    expect(getMostrador).toHaveBeenCalledWith(12)
  })

  it('sin sede propia, la primera', async () => {
    await montar('admin')

    expect(getMostrador).toHaveBeenCalledWith(10)
  })
})

describe('Las solapas', () => {
  it('administración ve las cuatro', async () => {
    const w = await montar()

    expect(w.findAll('.mst__tab').map(t => t.text().trim())).toEqual(
      expect.arrayContaining(['Hoy', 'Turnos', expect.stringContaining('Merma'), 'Rendiciones'])
    )
  })

  // La merma es información de gestión; sus turnos, no.
  it('quien atiende ve Hoy y Turnos', async () => {
    const w = await montar('dispensador')

    const tabs = w.findAll('.mst__tab').map(t => t.text().trim())
    expect(tabs).toContain('Turnos')
    expect(tabs.some(t => t.startsWith('Merma'))).toBe(false)
  })
})

it('si la API falla, la pantalla lo dice en vez de quedarse en blanco', async () => {
  getMostrador.mockRejectedValueOnce({ response: { data: { error: 'Esta sede no dispensa' } } })
  const w = await montar()

  expect(w.text()).toContain('Esta sede no dispensa')
})

// Le pasa también a administración: una organización sin sede social ni mixta no tiene dónde
// vivir el mostrador, y la pantalla ofrecía abrir una caja que el backend iba a rechazar.
describe('Cuando no hay sede de atención', () => {
  it('lo dice en vez de ofrecer abrir la caja, y a cada uno le dice quién lo arregla', async () => {
    useSedeStore().sedes = []
    const w = await montar('admin')

    expect(w.find('.mst__sinsede').exists()).toBe(true)
    expect(w.find('.mst__turno').exists()).toBe(false)
    expect(w.find('.tmo__table').exists()).toBe(false)
    expect(w.find('.mst__sinsede').text()).toContain('Sedes')   // el admin lo arregla ahí
  })

  it('al que atiende lo manda a administración, que es quien puede', async () => {
    useSedeStore().sedes = []
    const w = await montar('dispensador')

    expect(w.find('.mst__sinsede').text()).toContain('administración')
  })
})
