import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (socio de Germán, 16-sep-2026): el dispensador ve los envíos que despachó hoy y su estado,
// y la lista se actualiza sola cuando el repartidor los marca (ActionCable).
let envios = [
  { id: 1, estado_envio: 'en_viaje',  creada_at: '2026-09-16T12:00:00Z', paciente: { nombre: 'Augusto Test' }, direccion_envio: 'Directorio 1602, CABA', direccion_etiqueta: 'Trabajo', delivery: { nombre: 'Rapi Do' }, cobrar_en_entrega: true, saldo_pendiente: 5000 },
  { id: 2, estado_envio: 'entregado', creada_at: '2026-09-16T11:00:00Z', entregado_at: '2026-09-16T13:30:00Z', paciente: { nombre: 'Ana Gómez' }, direccion_envio: 'Lavalle 400, CABA', delivery: { nombre: 'Rapi Do' } },
]
const getEnviosDelDia = vi.fn(() => Promise.resolve({ data: envios }))
let recibir = null
vi.mock('../lib/api.js', () => ({ getEnviosDelDia: (...a) => getEnviosDelDia(...a) }))
// El canal del club: se captura el callback para simular el timbre del repartidor.
vi.mock('../composables/useStockChannel.js', () => ({
  useStockChannel: (_onStock, onEvento) => { recibir = onEvento },
}))

async function montar (props = {}, features = { delivery: true }) {
  setActivePinia(createPinia())
  const { useClubStore } = await import('../stores/club')
  useClubStore().data = { features }
  const { default: Comp } = await import('../components/dashboards/EnviosDeHoy.vue')
  const w = mount(Comp, { props })
  await flushPromises()
  return w
}

describe('Envíos de hoy', () => {
  beforeEach(() => { vi.clearAllMocks(); recibir = null })

  it('lista sus envíos con estado, repartidor, nombre de la dirección y lo que cobra', async () => {
    const w = await montar()
    const t = w.text()

    expect(getEnviosDelDia).toHaveBeenCalledWith({})
    expect(t).toContain('En viaje')
    expect(t).toContain('Entregado')
    expect(t).toContain('Augusto Test')
    expect(t).toContain('Trabajo')
    expect(t).toContain('Directorio 1602')
    expect(t).toContain('Rapi Do')
    expect(t).toContain('cobra')
    expect(t).toContain('5.000')
  })

  it('el resumen dice cuántos van en cada estado', async () => {
    const w = await montar()

    expect(w.find('.edh__resumen').text()).toContain('1 en viaje')
    expect(w.find('.edh__resumen').text()).toContain('1 entregado')
  })

  it('cuando el repartidor marca el paquete, vuelve a pedir la lista y cambia el estado', async () => {
    const w = await montar()
    expect(w.findAll('.edh__estado--viaje')).toHaveLength(1)

    envios = envios.map(e => e.id === 1 ? { ...e, estado_envio: 'entregado', entregado_at: '2026-09-16T14:00:00Z' } : e)
    recibir({ tipo: 'envio_actualizado', dispensacion_id: 1, estado_envio: 'entregado' })
    await flushPromises()

    expect(getEnviosDelDia).toHaveBeenCalledTimes(2)
    expect(w.findAll('.edh__estado--viaje')).toHaveLength(0)
    expect(w.findAll('.edh__estado--ok')).toHaveLength(2)
  })

  it('un timbre de stock no la hace recargar', async () => {
    await montar()
    recibir({ tipo: 'stock_actualizado', stock_id: 9 })
    await flushPromises()

    expect(getEnviosDelDia).toHaveBeenCalledTimes(1)
  })

  it('administración pide los de todos', async () => {
    await montar({ todos: true })

    expect(getEnviosDelDia).toHaveBeenCalledWith({ todos: 1 })
  })

  it('en el teléfono arranca plegada y se abre al tocar', async () => {
    const w = await montar({ compacto: true })

    expect(w.find('.edh__list').exists()).toBe(false)
    await w.find('.edh__hd').trigger('click')
    expect(w.find('.edh__list').exists()).toBe(true)
  })

  it('sin el add-on de Delivery no aparece ni pregunta', async () => {
    const w = await montar({}, { delivery: false })

    expect(getEnviosDelDia).not.toHaveBeenCalled()
    expect(w.text()).toBe('')
  })
})
