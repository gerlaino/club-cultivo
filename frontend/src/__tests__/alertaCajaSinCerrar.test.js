import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// LA CAJA QUE QUEDÓ ABIERTA: el admin elige a qué hora quiere que le avisen.
//
// Se cierra de noche, cuando administración no está. Si alguien se fue sin cerrar, nadie se
// entera hasta la mañana siguiente —cuando el que abre no puede arrancar— y para entonces el
// arqueo de esa jornada ya no lo puede hacer nadie.

let preferencias = {}
let sedes = []
const updatePreferences = vi.fn(() => Promise.resolve({ data: {} }))

vi.mock('../lib/api.js', () => ({
  listSetpointsFase: vi.fn(() => Promise.resolve({ data: [] })),
  createSetpointFase: vi.fn(), updateSetpointFase: vi.fn(), deleteSetpointFase: vi.fn(),
  getPreferences:    vi.fn(() => Promise.resolve({ data: preferencias })),
  updatePreferences: (...a) => updatePreferences(...a),
  listUsers:         vi.fn(() => Promise.resolve({ data: [] })),
  listSedes:         vi.fn(() => Promise.resolve({ data: sedes })),
}))

import SetpointsConfigView from '../views/SetpointsConfigView.vue'

const CENTRO = { id: 10, nombre: 'Centro', tipo: 'social' }
const NORTE  = { id: 11, nombre: 'Norte',  tipo: 'mixta' }
const VIVERO = { id: 12, nombre: 'Vivero', tipo: 'produccion' }

async function montar (opciones = {}) {
  preferencias = { alertas_config: opciones.config || {} }
  sedes = opciones.sedes ?? [CENTRO, VIVERO]
  const w = mount(SetpointsConfigView)
  await flushPromises()
  // La pantalla abre en "Umbrales ambientales"; lo nuestro vive en la otra solapa.
  const tab = w.findAll('.spc__tab').find(t => t.text().includes('alerta'))
  await tab.trigger('click')
  await flushPromises()
  return w
}

beforeEach(() => { updatePreferences.mockClear() })

describe('El aviso de caja sin cerrar', () => {
  it('se puede prender y elegir la hora', async () => {
    const w = await montar()

    const check = w.find('.spc__check input')
    expect(check.exists()).toBe(true)
    await check.setValue(true)

    const hora = w.find('input[type="time"]')
    await hora.setValue('22:30')
    await w.find('.spc__form').trigger('submit')
    await flushPromises()

    const enviado = updatePreferences.mock.calls[0][0].alertas_config.cierre_mostrador
    expect(enviado.activo).toBe(true)
    expect(enviado.hora).toBe('22:30')
  })

  it('carga lo que ya estaba configurado', async () => {
    const w = await montar({
      config: { cierre_mostrador: { activo: true, hora: '21:00', por_sede: { 10: '20:00' } } },
    })

    expect(w.find('.spc__check input').element.checked).toBe(true)
    expect(w.find('input[type="time"]').element.value).toBe('21:00')
  })

  // El mostrador vive en una sede que atiende: sin ninguna, configurar la alerta sería configurar
  // algo que no existe.
  it('no aparece si la organización no tiene ninguna sede que atienda', async () => {
    const w = await montar({ sedes: [VIVERO] })

    expect(w.find('.spc__check').exists()).toBe(false)
  })

  // Una organización con dos sedes puede cerrar a horas distintas, y es justo donde más sirve:
  // el admin no está en ninguna de las dos.
  describe('las excepciones por sede', () => {
    it('aparecen recién con más de una sede que atiende, y no listan las que no atienden', async () => {
      const una = await montar({ sedes: [CENTRO, VIVERO] })
      await una.find('.spc__check input').setValue(true)
      expect(una.find('.spc__excepciones').exists()).toBe(false)

      const dos = await montar({ sedes: [CENTRO, NORTE, VIVERO] })
      await dos.find('.spc__check input').setValue(true)
      const nombres = dos.findAll('.spc__excepcion-sede').map(e => e.text())
      expect(nombres).toEqual(['Centro', 'Norte'])
    })

    it('se guardan con su sede', async () => {
      const w = await montar({
        config: { cierre_mostrador: { activo: true, hora: '23:00', por_sede: {} } },
        sedes: [CENTRO, NORTE],
      })
      const horas = w.findAll('.spc__excepcion input[type="time"]')
      await horas[1].setValue('21:30')
      await w.find('.spc__form').trigger('submit')
      await flushPromises()

      const enviado = updatePreferences.mock.calls[0][0].alertas_config.cierre_mostrador
      expect(enviado.por_sede['11']).toBe('21:30')
    })

    // Vacío significa "usa la general", y tiene que poder volver a estarlo.
    it('y se pueden vaciar para volver a la general', async () => {
      const w = await montar({
        config: { cierre_mostrador: { activo: true, hora: '23:00', por_sede: { 11: '21:30' } } },
        sedes: [CENTRO, NORTE],
      })

      await w.find('.spc__excepcion-limpiar').trigger('click')
      await w.find('.spc__form').trigger('submit')
      await flushPromises()

      const enviado = updatePreferences.mock.calls[0][0].alertas_config.cierre_mostrador
      expect(enviado.por_sede['11']).toBe('')
    })
  })
})
