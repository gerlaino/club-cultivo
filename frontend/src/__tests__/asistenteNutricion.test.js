import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { ref } from 'vue'

// AC (Germán, 13-oct-2026): «hice un registro por voz: le puse vege, un pulso a cada planta… no me
// tomó el vege del depósito, no hizo el cálculo para descontar lo usado». El backend hace la
// cuenta (`Nutricion::DesdeDictado`) y la pantalla la MUESTRA antes de guardar, se puede corregir,
// y lo que se guarda es lo confirmado.
const post = vi.fn()
const listInsumos = vi.fn()
const listRecetas = vi.fn()
vi.mock('../lib/api', () => ({
  default: { post: (...a) => post(...a) },
  consumoIA: vi.fn(() => Promise.resolve({ data: {} })),
  listInsumos: (...a) => listInsumos(...a),
  listRecetas: (...a) => listRecetas(...a),
}))
vi.mock('../lib/api.js', () => ({
  default: { post: (...a) => post(...a) },
  consumoIA: vi.fn(() => Promise.resolve({ data: {} })),
  listInsumos: (...a) => listInsumos(...a),
  listRecetas: (...a) => listRecetas(...a),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))
vi.mock('../composables/useReconocimientoVoz.js', () => ({
  useReconocimientoVoz: () => ({ escuchando: ref(false), soportado: ref(true), iniciar: vi.fn(), detener: vi.fn(), error: ref(null), interim: ref('') }),
}))

const VEGE = { id: 7, nombre: 'Vege', unidad_medida: 'mililitro', stock_actual: 500 }

function riego (nutricion) {
  return { tipo: 'registro_ambiental_sala', sala_nombre: 'Carpa', datos: {
    tareas_realizadas: ['riego', 'nutricion'], fertilizacion: true, notas_fertilizacion: 'vege, un pulso a cada planta', nutricion,
  } }
}

async function revisar (acciones) {
  setActivePinia(createPinia())
  listInsumos.mockResolvedValue({ data: [VEGE] })
  listRecetas.mockResolvedValue({ data: [] })
  post.mockImplementation((url) => (url === '/asistente/parsear'
    ? Promise.resolve({ data: { resumen: 'Riego con vege', acciones, correccion_id: 1 } })
    : Promise.resolve({ data: { resultados: [], errores_detalle: [] } })))
  const V = (await import('../components/AsistenteVoz.vue')).default
  const w = mount(V, { global: { stubs: { teleport: true, transition: false }, directives: { modal: {} } } })
  await w.find('.av__trigger').trigger('click')
  w.vm.transcripcion = 'le puse vege, un pulso a cada planta'
  await flushPromises()
  await w.find('.av__btn-procesar').trigger('click')
  await flushPromises(); await flushPromises()
  return w
}

const PROPUESTA = {
  modo: 'sueltos', receta_id: null, base: null, avisos: [],
  items: [{ insumo_id: 7, nombre: 'Vege', cantidad: 6, calculada: 6, unidad_insumo: 'mililitro',
            detalle: '1 pulso × 6 plantas', origen: 'dicho' }],
}

describe('Dictado: los nutrientes se descuentan', () => {
  beforeEach(() => { post.mockReset(); listInsumos.mockReset(); listRecetas.mockReset() })

  it('muestra qué se descuenta y de dónde sale la cuenta, antes de guardar', async () => {
    const w = await revisar([riego(PROPUESTA)])
    const bloque = w.find('[data-testid="accion-nutricion"]')

    expect(bloque.exists()).toBe(true)
    expect(bloque.text()).toContain('Vege: 1 pulso × 6 plantas')
    expect(bloque.find('input[aria-label="Cantidad de Vege"]').element.value).toBe('6')
  })

  it('lo que no se pudo calcular lo dice', async () => {
    const w = await revisar([riego({ ...PROPUESTA, items: [{ ...PROPUESTA.items[0], cantidad: null, calculada: null, detalle: null }],
      avisos: ['Vege: no dijiste cuánto y no tiene cargada la dosis de la etiqueta. Poné la cantidad.'] })])
    expect(w.find('[data-testid="accion-nutricion"]').text()).toContain('no tiene cargada la dosis de la etiqueta')
  })

  it('se guarda lo confirmado: si cambio la cantidad, viaja la nueva y la cuenta vieja deja de mostrarse', async () => {
    const w = await revisar([riego(PROPUESTA)])
    await w.find('input[aria-label="Cantidad de Vege"]').setValue('4')
    expect(w.find('[data-testid="accion-nutricion"]').text()).not.toContain('1 pulso × 6 plantas')

    await w.find('.av__btn-ejecutar').trigger('click')
    await flushPromises()

    const [, body] = post.mock.calls.find(([url]) => url === '/asistente/ejecutar')
    const item = body.acciones[0].datos.nutricion.items.find(i => i.insumo_id === 7)
    expect(item.cantidad).toBe(4)
  })

  it('un riego sin nutrientes no muestra nada que descontar', async () => {
    const w = await revisar([{ tipo: 'registro_ambiental', lote_codigo: 'L-1', datos: { tareas_realizadas: ['riego'] } }])
    expect(w.find('[data-testid="accion-nutricion"]').exists()).toBe(false)
  })
})
