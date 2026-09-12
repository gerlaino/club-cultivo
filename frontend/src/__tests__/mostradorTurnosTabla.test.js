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
// una cuenta sin mostrar la cuenta.
//
// Ahora, propuesta de Germán: AGRUPADO POR DÍA —«¿cómo fue el martes?», no «¿cómo fue el cierre
// 47?»— con el saldo del día en el encabezado, una línea por cierre, y el detalle en su ficha.
// Lo que cuenta qué pasó se prueba en `corregirConteo.test.js`, que es donde vive ahora.
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
const listTurnos = vi.fn()
vi.mock('../lib/api.js', () => ({
  listTurnosMostrador: (...a) => { listTurnos(...a); return Promise.resolve({ data: respuesta }) },
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

beforeEach(() => { setActivePinia(createPinia()); revisarTurnoMostrador.mockClear(); listTurnos.mockClear() })

describe('Agrupado por día', () => {
  const dia = (w, i = 0) => w.findAll('.trn__dia')[i]

  it('junta los cierres del día bajo su nombre', async () => {
    const w = await montar([TURNO, { ...TURNO, id: 8, abierto_at: '2026-09-05T12:00:00Z',
                                     cerrado_at: '2026-09-05T17:00:00Z' }])

    expect(w.findAll('.trn__dia')).toHaveLength(1)
    expect(dia(w).find('.trn__dia-nombre').text()).toContain('septiembre')
    expect(dia(w).find('.trn__dia-resumen').text()).toContain('2 cierres')
  })

  // El encabezado trae el saldo: con un solo cierre —el caso normal— no hace falta abrir nada
  // para saber si pasó algo.
  it('el encabezado dice si falta plata, sin abrir el día', async () => {
    const w = await montar()
    expect(dia(w).find('.trn__dia-resumen').text()).toContain('27.636')
  })

  // Y LA PLATA. El saldo del día sumaba sólo el producto: con la mesa perfecta y $20.000 menos
  // en el cajón, el encabezado decía «no falta nada».
  it('el encabezado dice también lo que falta en la caja', async () => {
    const w = await montar([{ ...TURNO, motivos_revision: ['caja'],
      faltaron: { total: 0, ars: 0, items: [] }, sobraron: { total: 0, items: [] } }])

    const t = dia(w).find('.trn__dia-resumen').text()
    expect(t).toContain('en la caja')
    expect(t).toContain('20.000')
    expect(t).toContain('menos')
    expect(t).not.toContain('no falta nada')
  })

  it('y cuando no falta nada —ni producto ni plata— lo dice, con quién atendió', async () => {
    const w = await montar([{ ...TURNO, motivos_revision: [],
      faltaron: { total: 0, ars: 0, items: [] }, sobraron: { total: 0, items: [] },
      caja: { ...TURNO.caja, contado_ars: 150000, diferencia_ars: 0 } }])

    const t = dia(w).find('.trn__dia-resumen').text()
    expect(t).toContain('no falta nada')
    expect(t).toContain('Ana Gómez')
  })

  it('el día más reciente arranca abierto: es el que se viene a mirar', async () => {
    const w = await montar()
    expect(dia(w).findAll('.trn__cierre').length).toBeGreaterThan(0)
  })

  it('y se puede cerrar', async () => {
    const w = await montar()
    await dia(w).find('.trn__dia-hd').trigger('click')
    expect(dia(w).findAll('.trn__cierre')).toHaveLength(0)
  })
})

describe('La línea de cada cierre', () => {
  const cierre = (w, i = 0) => w.findAll('.trn__cierre')[i]

  it('dice el horario y quién atendió', async () => {
    const w = await montar()
    expect(cierre(w).find('.trn__cierre-hora').text()).toMatch(/\d{2}:\d{2}/)
    expect(cierre(w).find('.trn__cierre-quien').text()).toContain('Ana Gómez')
  })

  // EL BUG QUE APARECIÓ LEYENDO: «14:02–12:03» se leía como que cerró antes de abrir. Es una caja
  // que cruzó la medianoche. Una fila imposible te hace desconfiar de toda la tabla.
  //
  // Y el día que se nombra es el de APERTURA: la fila vive dentro del grupo del día en que cerró,
  // así que decir el del cierre repetía el encabezado y escondía el dato que falta.
  it('cuando la caja cruzó la medianoche, nombra el día en que abrió', async () => {
    const w = await montar([{ ...TURNO, abierto_at: '2026-09-05T17:02:00Z',
                                        cerrado_at: '2026-09-06T15:03:00Z' }])
    const txt = cierre(w).find('.trn__cierre-hora').text()
    expect(txt).toMatch(/^sábado /)   // abrió el sábado 5, cerró el domingo 6
    expect(txt).not.toMatch(/domingo/)
  })

  it('y cuando abrió uno y cerró otro, nombra a los dos', async () => {
    const w = await montar([{ ...TURNO, atendio: 'Admin Demo', cerrado_por: 'Dispensa Demo' }])
    const t = cierre(w).find('.trn__cierre-quien').text()
    expect(t).toContain('Abrió Admin Demo')
    expect(t).toContain('cerró Dispensa Demo')
  })

  it('el veredicto se lee sin abrir nada', async () => {
    const w = await montar()
    expect(cierre(w).find('.trn__pill').text()).toBe('Falta producto')
  })

  // La plata manda sobre el producto: es lo que un admin quiere que le griten primero.
  it('si faltó plata, el veredicto es ése aunque también falte producto', async () => {
    const w = await montar([{ ...TURNO, motivos_revision: ['caja', 'faltante'] }])
    expect(cierre(w).find('.trn__pill').text()).toBe('Falta plata')
  })

  it('y si sobró, lo dice así', async () => {
    const w = await montar([{ ...TURNO, motivos_revision: ['caja'],
      caja: { ...TURNO.caja, contado_ars: 160000, diferencia_ars: 10000 } }])
    expect(cierre(w).find('.trn__pill').text()).toBe('Sobra plata')
  })

  it('y uno sin novedad lo dice, en vez de no decir nada', async () => {
    const w = await montar([{ ...TURNO, motivos_revision: [],
      faltaron: { total: 0, ars: 0, items: [] }, sobraron: { total: 0, items: [] },
      caja: { ...TURNO.caja, contado_ars: 150000, diferencia_ars: 0 } }])
    expect(cierre(w).find('.trn__pill').text()).toBe('Sin novedad')
  })

  it('lo ya mirado se marca, para no volver a abrirlo', async () => {
    const w = await montar([{ ...TURNO, revisado: true }])
    expect(cierre(w).find('.trn__pill').text()).toBe('Visto')
  })

  // Un solo gesto: la ficha muestra qué pasó Y los números para corregirlo. Antes eran dos —abrir
  // la fila, abrir otro modal— y el de corregir no tenía contexto.
  it('tocarlo abre su ficha', async () => {
    const w = await montar()
    await cierre(w).trigger('click')
    expect(w.findComponent({ name: 'CorregirConteo' }).exists()).toBe(true)
  })
})

describe('El filtro de trabajo', () => {
  it('«Para mirar» filtra en el backend, no en la pantalla', async () => {
    const w = await montar()
    const btn = w.findAll('.trn__filtro').find(b => b.text().includes('Para mirar'))
    await btn.trigger('click')
    await flushPromises()

    expect(listTurnos).toHaveBeenLastCalledWith(10, { pagina: 1, sin_revisar: 1 })
  })
})
