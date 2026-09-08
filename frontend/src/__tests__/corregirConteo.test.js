import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// CORREGIR UN CONTEO: LA PANTALLA QUE NO LISTABA NADA.
//
// Germán, probándola: «se abre un modal que dice ingresar motivo, pero no hacés más nada, ¿para
// qué sirve eso?». No era una impresión — estaba ROTA: el modal leía `data.items` y el backend
// mandaba la lista bajo `conteo_apertura`, así que salía vacía SIEMPRE y quedaba un campo de
// motivo suelto. Al confirmar contestaba «no cambiaste ningún número». La función existía,
// tenía su servicio y su ruta, y no era alcanzable.
//
// Y aunque hubiera listado: mostraba «se había contado 23 g» y un campo, sin decir nunca que la
// mesa decía 46. Corregir un número sin ver contra qué está mal es adivinar.

const TURNO = {
  id: 7, abierto_at: '2026-09-05T12:00:00Z', cerrado_at: '2026-09-05T22:00:00Z',
  atendio: 'Ana Gómez', cerrado_por: 'Ana Gómez', productos: 2, dispensado_ars: 186400,
  motivos_revision: ['faltante', 'mesa_movida'],
  faltaron: { total: 1, cantidad: 23, ars: 27636,
              items: [{ etiqueta: 'Critical Kush L-26-017', cantidad: 23, unidad: 'g',
                        ars: 27636, esperado: 46, contado: 23 }] },
  sobraron: { total: 0, cantidad: 0, ars: 0, items: [] },
  caja: { fondo_ars: 110000, esperado_ars: 150000, contado_ars: 130000, diferencia_ars: -20000 },
  // El nombre que manda el backend. `items` es el mismo array, agregado para esta pantalla.
  conteo_apertura: [
    { id: 91, stock_id: 1, etiqueta: 'Critical Kush L-26-017', unidad: 'g',
      esperado: 46, contado: 46, esperado_cierre: 46, contado_cierre: 23 },
    { id: 92, stock_id: 2, etiqueta: 'Northern Lights L-26-001', unidad: 'g',
      esperado: 120, contado: 120, esperado_cierre: 120, contado_cierre: 120 },
  ],
}
TURNO.items = TURNO.conteo_apertura

const getTurnoMostrador     = vi.fn(() => Promise.resolve({ data: TURNO }))
const corregirTurnoMostrador = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({
  getTurnoMostrador:      (...a) => getTurnoMostrador(...a),
  corregirTurnoMostrador: (...a) => corregirTurnoMostrador(...a),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

import CorregirConteo from '../components/mostrador/CorregirConteo.vue'

async function abrir (data = TURNO) {
  getTurnoMostrador.mockResolvedValue({ data })
  // El turno ENTERO como prop: la ficha cuenta qué pasó con esos datos, no sólo con lo que trae
  // el pedido de los conteos.
  const w = mount(CorregirConteo, { props: { sedeId: 10, turno: data } })
  await flushPromises()
  return w
}

beforeEach(() => { getTurnoMostrador.mockClear(); corregirTurnoMostrador.mockClear() })

describe('Corregir el conteo de un cierre', () => {
  it('lista los productos: era lo que no pasaba nunca', async () => {
    const w = await abrir()
    expect(w.findAll('.cc__row:not(.cc__row--head):not(.cc__row--plata)')).toHaveLength(2)
    expect(w.text()).toContain('Critical Kush L-26-017')
  })

  // Aunque el backend mandara sólo el nombre viejo, la pantalla tiene que andar: es la que
  // desbloquea la corrección, y romperla otra vez por un rename no vale la pena.
  it('funciona con cualquiera de los dos nombres del payload', async () => {
    const soloViejo = { ...TURNO, items: undefined }
    const w = await abrir(soloViejo)
    expect(w.findAll('.cc__row:not(.cc__row--head):not(.cc__row--plata)')).toHaveLength(2)
  })

  it('muestra contra QUÉ está mal, no sólo lo que se contó', async () => {
    const w = await abrir()
    const fila = w.findAll('.cc__row:not(.cc__row--head):not(.cc__row--plata)')[0]

    expect(fila.text()).toContain('46')   // lo que tenía que haber
    expect(fila.text()).toContain('23')   // lo que se contó
    expect(fila.find('.cc__num--dif').exists()).toBe(true)   // y cuál es el que no cerró
  })

  // Se corrige el conteo del CIERRE. Leía `it.contado`, que es lo que se contó al ABRIR: se
  // ofrecía para corregir un número que no era el que estaba mal.
  it('parte del conteo del cierre, no del de la apertura', async () => {
    const w = await abrir()
    expect(w.findAll('.cc__input--cant')[0].element.value).toBe('23')
  })

  it('dice qué va a pasar con el inventario, y se recalcula al escribir', async () => {
    const w = await abrir()
    expect(w.find('.cc__efecto').text()).toContain('faltan 23')

    // Se corrigen las DOS cosas: el producto y la plata. Son dos arqueos distintos y el efecto
    // habla de los dos — dejar la caja mal y esperar «no falta nada» sería mentira.
    await w.findAll('.cc__input--cant')[0].setValue(46)
    await w.find('.cc__row--plata .cc__input--cant').setValue(150000)
    expect(w.find('.cc__efecto').text()).toContain('no falta nada')
  })

  it('manda el id del renglón, que es con lo que corrige el backend', async () => {
    const w = await abrir()
    await w.findAll('.cc__input--cant')[0].setValue(40)
    await w.find('.cc__campo input').setValue('se cargó 23 en vez de 40')
    await w.find('.cc__btn--primary').trigger('click')
    await flushPromises()

    expect(corregirTurnoMostrador).toHaveBeenCalledWith(10, 7, {
      conteos: [{ item_id: 91, contado: 40 }],
      motivo: 'se cargó 23 en vez de 40',
    })
  })
})

// ── LA PLATA TAMBIÉN SE CUENTA MAL ─────────────────────────────────────────────────
//
// Germán: «en mostrador/cierres, cuando voy a corregir lo que se contó no me permite editar el
// dinero contado, sólo las cantidades de stocks». Y el efectivo mal cargado quedaba así para
// siempre, con su asiento de faltante en el libro y su diferencia en el arqueo.
describe('Corregir la plata contada', () => {
  it('la ofrece, con lo que tenía que haber al lado', async () => {
    const w = await abrir()
    const fila = w.find('.cc__row--plata')

    expect(fila.exists()).toBe(true)
    expect(fila.text()).toContain('150.000')   // lo que tenía que haber
    expect(fila.text()).toContain('130.000')   // lo que se contó
  })

  it('dice qué se va a asentar en el libro, mientras se escribe', async () => {
    const w = await abrir()
    await w.find('.cc__row--plata .cc__input--cant').setValue(150000)
    expect(w.find('.cc__efecto').text()).not.toContain('caja')

    await w.find('.cc__row--plata .cc__input--cant').setValue(140000)
    expect(w.find('.cc__efecto').text()).toContain('caja')
  })

  it('la manda sólo si de verdad cambió', async () => {
    const w = await abrir()
    await w.findAll('.cc__input--cant')[0].setValue(40)
    await w.find('.cc__campo input').setValue('dedazo')
    await w.find('.cc__btn--primary').trigger('click')
    await flushPromises()

    expect(corregirTurnoMostrador.mock.calls[0][2].efectivo_contado_ars).toBeUndefined()
  })

  it('y se puede corregir SÓLO la plata, sin tocar ningún producto', async () => {
    const w = await abrir()
    await w.find('.cc__row--plata .cc__input--cant').setValue(148000)
    await w.find('.cc__campo input').setValue('se contó mal el efectivo')
    await w.find('.cc__btn--primary').trigger('click')
    await flushPromises()

    expect(corregirTurnoMostrador).toHaveBeenCalledWith(10, 7, {
      conteos: [], motivo: 'se contó mal el efectivo', efectivo_contado_ars: 148000,
    })
  })
})

// ── NO SE CIERRA AL TOCAR AFUERA ───────────────────────────────────────────────────
//
// Germán: «si hacés click sin querer afuera, salís del modal, deberíamos prevenir eso, es
// bastante molesto». Acá se cuenta plata y mercadería: el click que se te va buscando el scroll
// borraba todo lo escrito sin preguntar nada, y no hay forma de recuperarlo.
//
// Pero un modal del que no se puede salir con el teclado es otro problema —y peor para quien no
// usa mouse—, así que la salida deliberada queda: Cancelar o Escape.
describe('Salir del modal', () => {
  it('un click afuera NO lo cierra', async () => {
    const w = await abrir()
    await w.find('.cc__back').trigger('click')
    expect(w.emitted('cerrar')).toBeUndefined()
  })

  it('Escape sí, que es un gesto deliberado', async () => {
    const w = await abrir()
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    expect(w.emitted('cerrar')).toBeTruthy()
  })

  it('y al desmontarse deja de escuchar: cuatro modales son cuatro listeners sueltos', async () => {
    const w = await abrir()
    w.unmount()
    // Si el listener siguiera vivo, esto tiraría sobre un componente desmontado.
    expect(() => document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))).not.toThrow()
  })
})

// ── LA FICHA CUENTA QUÉ PASÓ, ANTES DE PEDIR NADA ──────────────────────────────────
//
// Estas oraciones vivían en la fila de la lista y el modal te pedía un número sin contexto: dos
// gestos para una sola pregunta. Ahora es un solo lugar — mirás el cierre y, si algo está mal, lo
// corregís sin cambiar de pantalla. Propuesta de Germán al agrupar por día.
describe('La ficha del cierre', () => {
  const hechos = (w) => w.findAll('.cc__hecho').map(h => h.text())

  it('dice cuándo fue y quién atendió', async () => {
    const w = await abrir()
    const sub = w.find('.cc__sub').text()
    expect(sub).toContain('septiembre')
    expect(sub).toContain('Ana Gómez')
  })

  it('nombra EL PRODUCTO que faltó, con la cuenta a la vista', async () => {
    const w = await abrir()
    const t = hechos(w).join(' ')

    expect(t).toContain('Critical Kush L-26-017')
    expect(t).toContain('46')     // lo que tenía que haber: sin esto no se puede comprobar
    expect(t).toContain('23')
    expect(t).toContain('costó')
  })

  it('explica la caja en vez de tirar dos números pegados', async () => {
    const w = await abrir()
    const t = hechos(w).join(' ')

    expect(t).toContain('130.000')   // lo que había
    expect(t).toContain('20.000')    // la diferencia
    expect(t).toContain('110.000')   // el fondo: de dónde sale la cuenta
  })

  // Antes eran chips con un «+2 más» que escondía justo lo que había que leer.
  it('los otros motivos son oraciones, no chips escondidos', async () => {
    const w = await abrir()
    expect(hechos(w).join(' ')).toContain('administración movió lo que había sobre la mesa')
  })

  it('y un cierre sin novedad lo dice', async () => {
    const w = await abrir({ ...TURNO, motivos_revision: [],
      faltaron: { total: 0, items: [] }, sobraron: { total: 0, items: [] } })
    expect(hechos(w).join(' ')).toContain('estaba todo')
  })

  it('contar de más se explica distinto: no se carga al inventario', async () => {
    const w = await abrir({ ...TURNO, motivos_revision: ['sobrante'],
      faltaron: { total: 0, items: [] },
      sobraron: { total: 1, items: [{ etiqueta: 'Northern Lights', cantidad: 12, unidad: 'g',
                                      ars: 0, esperado: 108, contado: 120 }] } })
    const t = hechos(w).join(' ')
    expect(t).toContain('de más')
    expect(t).toContain('nunca lo carga')
  })
})
