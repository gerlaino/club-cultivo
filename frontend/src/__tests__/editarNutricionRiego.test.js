import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 13-oct-2026): «en caso de querer cambiarlo después, se debería poder editar el
// registro de riego y sus parámetros». El backend deshace y vuelve a aplicar (`Nutricion::Editar`);
// la pantalla abre lo aplicado, deja corregirlo, y no ofrece lo que el backend va a rechazar.
const api = vi.hoisted(() => ({
  getNutricionRiego: vi.fn(), updateNutricionRiego: vi.fn(), listInsumos: vi.fn(), listRecetas: vi.fn(),
}))
vi.mock('../lib/api.js', () => ({
  getNutricionRiego: (...a) => api.getNutricionRiego(...a),
  updateNutricionRiego: (...a) => api.updateNutricionRiego(...a),
  listInsumos: (...a) => api.listInsumos(...a),
  listRecetas: (...a) => api.listRecetas(...a),
}))
const toast = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn() }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => toast }))

import EditarNutricionRiego from '../components/riegos/EditarNutricionRiego.vue'

const KAWSAY = { id: 9, nombre: 'Kawsay Vege', unidad_medida: 'mililitro', stock_actual: 300 }

async function abrir (respuesta) {
  setActivePinia(createPinia())
  api.getNutricionRiego.mockResolvedValue({ data: respuesta })
  api.listInsumos.mockResolvedValue({ data: [KAWSAY] })
  api.listRecetas.mockResolvedValue({ data: [] })
  const w = mount(EditarNutricionRiego, {
    props: { loteId: 3, registroId: 40 },
    global: { stubs: { teleport: true }, directives: { modal: {} } },
  })
  await flushPromises(); await flushPromises()
  return w
}

describe('Corregir los nutrientes de un riego', () => {
  beforeEach(() => { Object.values(api).forEach(f => f.mockReset()); toast.success.mockReset(); toast.error.mockReset() })

  it('abre con lo aplicado y guarda lo corregido', async () => {
    api.updateNutricionRiego.mockResolvedValue({ data: { faltantes: [] } })
    const w = await abrir({ sala_id: 2, lotes: ['L-1'], bloqueo: null,
      nutricion: { modo: 'sueltos', items: [{ insumo_id: 9, cantidad: 6, modo_faltante: 'descontar_disponible' }] } })

    expect(api.getNutricionRiego).toHaveBeenCalledWith(3, 40)
    const input = w.find('input[aria-label="Cantidad de Kawsay Vege"]')
    expect(input.element.value).toBe('6')

    await input.setValue('3')
    await w.find('.enr__btn--primary').trigger('click')
    await flushPromises()

    expect(api.updateNutricionRiego).toHaveBeenCalledWith(3, 40, expect.objectContaining({
      modo: 'sueltos', items: [expect.objectContaining({ insumo_id: 9, cantidad: 3 })],
    }))
    expect(w.emitted('guardado')).toBeTruthy()
  })

  it('si el backend dice que no se puede, lo explica y no ofrece guardar', async () => {
    const w = await abrir({ sala_id: 2, lotes: ['L-1'], nutricion: { modo: 'ninguno', items: [] },
      bloqueo: 'L-1 ya se cosechó: su costo pasó a la cosecha y no se mueve.' })

    expect(w.text()).toContain('ya se cosechó')
    expect(w.find('.enr__btn--primary').exists()).toBe(false)
  })

  it('si el backend rechaza al guardar, muestra el motivo y no cierra', async () => {
    api.updateNutricionRiego.mockRejectedValue({ response: { data: { error: 'Sólo quien lo registró o un administrador puede corregirlo.' } } })
    const w = await abrir({ sala_id: 2, lotes: ['L-1'], bloqueo: null,
      nutricion: { modo: 'sueltos', items: [{ insumo_id: 9, cantidad: 6 }] } })
    await w.find('.enr__btn--primary').trigger('click')
    await flushPromises()

    expect(toast.error).toHaveBeenCalledWith('Sólo quien lo registró o un administrador puede corregirlo.')
    expect(w.emitted('guardado')).toBeFalsy()
  })
})
