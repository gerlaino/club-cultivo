import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { ref } from 'vue'

// AC (Germán, 12-oct-2026): «al detectar una acción repetida, deberíamos preguntar si se quieren
// hacer dos registros de la misma, quizás fue un error». El backend marca la tarjeta
// (`repetida` / `ya_registrado`); la pantalla lo muestra y no guarda sin preguntar.
const post = vi.fn()
vi.mock('../lib/api', () => ({ default: { post: (...a) => post(...a) }, consumoIA: vi.fn(() => Promise.resolve({ data: {} })) }))
const confirm = vi.fn()
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: (...a) => confirm(...a) }) }))
vi.mock('../composables/useReconocimientoVoz.js', () => ({
  useReconocimientoVoz: () => ({ escuchando: ref(false), soportado: ref(true), iniciar: vi.fn(), detener: vi.fn(), error: ref(null), interim: ref('') }),
}))

const RIEGO = { tipo: 'registro_ambiental', lote_codigo: 'L-1', datos: { tareas_realizadas: ['riego'], observaciones: 'Un pulso por planta' } }

async function revisar(acciones) {
  setActivePinia(createPinia())
  post.mockImplementation((url) => (url === '/asistente/parsear'
    ? Promise.resolve({ data: { resumen: 'Riego', acciones, correccion_id: 1 } })
    : Promise.resolve({ data: { resultados: [], errores_detalle: [] } })))
  const V = (await import('../components/AsistenteVoz.vue')).default
  const w = mount(V, { global: { stubs: { teleport: true, transition: false }, directives: { modal: {} } } })
  await w.find('.av__trigger').trigger('click')
  w.vm.transcripcion = 'regué con un pulso por planta'
  await flushPromises()
  await w.find('.av__btn-procesar').trigger('click')
  await flushPromises()
  return w
}

describe('Asistente: acciones repetidas', () => {
  beforeEach(() => { post.mockReset(); confirm.mockReset() })

  it('la tarjeta repetida dice por qué', async () => {
    const w = await revisar([RIEGO, { ...RIEGO, repetida: 'Está dos veces en lo que dictaste.' }])
    const avisos = w.findAll('[data-testid="accion-repetida"]')
    expect(avisos).toHaveLength(1)
    expect(avisos[0].text()).toContain('Está dos veces en lo que dictaste.')
  })

  it('con algo repetido, «Guardar todo» pregunta; si no confirma, no guarda', async () => {
    confirm.mockResolvedValue(false)
    const w = await revisar([{ ...RIEGO, ya_registrado: 'Hoy ya se registró un riego en el lote L-1 a las 10:32.' }])
    await w.find('.av__btn-ejecutar').trigger('click')
    await flushPromises()
    expect(confirm.mock.calls[0][0].message).toContain('10:32')
    expect(post).not.toHaveBeenCalledWith('/asistente/ejecutar', expect.anything())
  })

  it('si confirma, guarda', async () => {
    confirm.mockResolvedValue(true)
    const w = await revisar([{ ...RIEGO, ya_registrado: 'Hoy ya se registró un riego.' }])
    await w.find('.av__btn-ejecutar').trigger('click')
    await flushPromises()
    expect(post).toHaveBeenCalledWith('/asistente/ejecutar', expect.anything())
  })

  it('sin nada repetido no pregunta', async () => {
    const w = await revisar([RIEGO])
    await w.find('.av__btn-ejecutar').trigger('click')
    await flushPromises()
    expect(confirm).not.toHaveBeenCalled()
    expect(post).toHaveBeenCalledWith('/asistente/ejecutar', expect.anything())
  })
})
