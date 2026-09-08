import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// LOS CIERRES, tal como los lee el admin de la organización.
//
// Germán, mirándolos en producción: «es ilegible, entrás ahí, ves eso y no entendés absolutamente
// nada... ponete en el lugar del admin del club, el admin no sabe nada de todo esto, lo que sabe
// es de cultivar».
//
// Era una tabla de cinco columnas —CIERRE · ENTREGADO · FALTÓ · CAJA— que mostraba el RESULTADO de
// una cuenta sin mostrar la cuenta: «$27.636,6 en 1 producto» sin decir cuál producto, contra qué
// se comparó ni de dónde sale el número de la caja. Ahora cada fila cuenta qué pasó, en oraciones,
// y el detalle está a un toque.
const TURNO = {
  id: 7,
  abierto_at: '2026-09-05T17:02:00Z', cerrado_at: '2026-09-05T23:03:00Z',
  atendio: 'Ana Gómez', cerrado_por: 'Ana Gómez', productos: 4, revisado: false,
  dispensado: 120, dispensado_ars: 480000,
  motivos_revision: ['faltante', 'mesa_movida'],
  faltaron: {
    total: 1, cantidad: 23, ars: 27636.6,
    items: [{ etiqueta: 'Critical Kush L-26-017', cantidad: 23, unidad: 'g',
              ars: 27636.6, esperado: 46, contado: 23 }],
  },
  sobraron: { total: 0, cantidad: 0, ars: 0, items: [] },
  caja: { fondo_ars: 110000, esperado_ars: 150000, contado_ars: 130000, diferencia_ars: -20000 },
}

let respuesta = { turnos: [TURNO], gestiona: true, pagina: 1, paginas: 1, total: 1, sin_revisar: 1 }
const revisarTurnoMostrador = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({
  listTurnosMostrador: (...a) => Promise.resolve({ data: respuesta }),
  descargarTurnosMostrador: vi.fn(),
  corregirTurnoMostrador: vi.fn(),
  getTurnoMostrador: vi.fn(() => Promise.resolve({ data: { items: [] } })),
  revisarTurnoMostrador: (...a) => revisarTurnoMostrador(...a),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

import MostradorTurnos from '../components/mostrador/MostradorTurnos.vue'

async function montar (turnos = [TURNO]) {
  respuesta = { ...respuesta, turnos }
  const w = mount(MostradorTurnos, { props: { sedeId: 10 } })
  await flushPromises()
  return w
}
const abrir = async (w) => { await w.find('.trn__c-hd').trigger('click'); return w }

beforeEach(() => { setActivePinia(createPinia()); revisarTurnoMostrador.mockClear() })

describe('La fila, sin abrirla', () => {
  it('dice cuándo y quién en castellano, no una fecha con dos horas al lado', async () => {
    const w = await montar()
    expect(w.find('.trn__c-cuando').text()).toContain('septiembre')
    expect(w.find('.trn__c-quien').text()).toContain('Ana Gómez')
  })

  // EL BUG QUE APARECIÓ LEYENDO: decía «14:02–12:03», que se lee como que cerró antes de abrir.
  // Es una caja que cruzó la medianoche y sólo se mostraba la fecha del cierre. Una fila
  // imposible te hace desconfiar de toda la tabla.
  it('cuando la caja cruzó la medianoche, lo dice en vez de parecer imposible', async () => {
    const w = await montar([{ ...TURNO,
      abierto_at: '2026-09-05T17:02:00Z', cerrado_at: '2026-09-06T15:03:00Z' }])

    const txt = w.find('.trn__c-quien').text()
    expect(txt).toMatch(/del (lunes|martes|miércoles|jueves|viernes|sábado|domingo)/)
  })

  it('y cuando abrió uno y cerró otro, nombra a los dos', async () => {
    const w = await montar([{ ...TURNO, atendio: 'Admin Demo', cerrado_por: 'Dispensa Demo' }])
    const txt = w.find('.trn__c-quien').text()
    expect(txt).toContain('Abrió Admin Demo')
    expect(txt).toContain('cerró Dispensa Demo')
  })

  it('el veredicto se lee sin abrir nada', async () => {
    const w = await montar()
    expect(w.find('.trn__pill').text()).toBe('Falta producto')
  })

  it('y un cierre sin novedad lo dice, en vez de no decir nada', async () => {
    const w = await montar([{ ...TURNO, motivos_revision: [],
      faltaron: { total: 0, items: [] }, sobraron: { total: 0, items: [] },
      caja: { ...TURNO.caja, contado_ars: 150000, diferencia_ars: 0 } }])
    expect(w.find('.trn__pill').text()).toBe('Sin novedad')
  })
})

describe('La fila abierta cuenta qué pasó', () => {
  it('nombra EL PRODUCTO que faltó, que es lo único accionable', async () => {
    const w = await abrir(await montar())
    expect(w.text()).toContain('Critical Kush L-26-017')
    expect(w.text()).toContain('23')
  })

  // Mostrar el resultado sin la cuenta es pedir que se confíe: sin el 46 no hay forma de
  // comprobar de dónde salen los 23 que faltan.
  it('muestra la cuenta: lo que tenía que haber y lo que apareció', async () => {
    const w = await abrir(await montar())
    const t = w.text()
    expect(t).toContain('46')
    expect(t).toContain('costó')
  })

  it('explica la caja en vez de tirar dos números pegados', async () => {
    const w = await abrir(await montar())
    const t = w.text()
    expect(t).toContain('130.000')          // lo que había
    expect(t).toContain('20.000')           // la diferencia
    expect(t).toContain('110.000')          // el fondo: de dónde sale la cuenta
  })

  // Antes eran chips y un «+2 más» que escondía justo lo que había que leer.
  it('los otros motivos son oraciones, no chips escondidos', async () => {
    const w = await abrir(await montar())
    expect(w.text()).toContain('administración movió lo que había sobre la mesa')
    expect(w.text()).not.toContain('+1 más')
  })

  it('contar de más se explica distinto: no se carga al inventario', async () => {
    const w = await abrir(await montar([{ ...TURNO, motivos_revision: ['sobrante'],
      faltaron: { total: 0, items: [] },
      sobraron: { total: 1, items: [{ etiqueta: 'Northern Lights', cantidad: 12, unidad: 'g',
                                      ars: 0, esperado: 108, contado: 120 }] } }]))
    expect(w.text()).toContain('de más')
    expect(w.text()).toContain('nunca lo carga')
  })
})

describe('Qué se puede hacer', () => {
  it('con algo para mirar, corregir es la acción principal', async () => {
    const w = await abrir(await montar())
    expect(w.find('.trn__btn--primary').text()).toContain('Corregir')
    expect(w.text()).toContain('ya lo miré')
  })

  // Si contó mal pero por casualidad dio bien, tiene que poder entrar — pero la fila no pide
  // atención, así que la acción no compite con nada.
  it('sin novedad, corregir sigue accesible pero en segundo plano', async () => {
    const w = await abrir(await montar([{ ...TURNO, motivos_revision: [],
      faltaron: { total: 0, items: [] }, sobraron: { total: 0, items: [] } }]))
    expect(w.find('.trn__btn--primary').exists()).toBe(false)
    expect(w.text()).toContain('Corregir')
    expect(w.text()).not.toContain('ya lo miré')
  })

  it('marcar visto lo saca de la lista de trabajo', async () => {
    const w = await abrir(await montar())
    const btn = w.findAll('.trn__btn').find(b => b.text().includes('ya lo miré'))
    await btn.trigger('click')
    await flushPromises()
    expect(revisarTurnoMostrador).toHaveBeenCalledWith(10, 7)
  })
})
