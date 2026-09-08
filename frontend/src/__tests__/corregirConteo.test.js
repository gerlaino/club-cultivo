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
  id: 7, cerrado_at: '2026-09-05T22:00:00Z',
  caja: {},
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
  const w = mount(CorregirConteo, { props: { sedeId: 10, turno: { id: 7, cerrado_at: TURNO.cerrado_at } } })
  await flushPromises()
  return w
}

beforeEach(() => { getTurnoMostrador.mockClear(); corregirTurnoMostrador.mockClear() })

describe('Corregir el conteo de un cierre', () => {
  it('lista los productos: era lo que no pasaba nunca', async () => {
    const w = await abrir()
    expect(w.findAll('.cc__row:not(.cc__row--head)')).toHaveLength(2)
    expect(w.text()).toContain('Critical Kush L-26-017')
  })

  // Aunque el backend mandara sólo el nombre viejo, la pantalla tiene que andar: es la que
  // desbloquea la corrección, y romperla otra vez por un rename no vale la pena.
  it('funciona con cualquiera de los dos nombres del payload', async () => {
    const soloViejo = { ...TURNO, items: undefined }
    const w = await abrir(soloViejo)
    expect(w.findAll('.cc__row:not(.cc__row--head)')).toHaveLength(2)
  })

  it('muestra contra QUÉ está mal, no sólo lo que se contó', async () => {
    const w = await abrir()
    const fila = w.findAll('.cc__row:not(.cc__row--head)')[0]

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

    await w.findAll('.cc__input--cant')[0].setValue(46)
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
