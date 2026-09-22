import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL DEPÓSITO Y LA PANTALLA DE STOCK MUESTRAN LA MISMA TABLA.
//
// Eran dos tablas del mismo stock con columnas distintas —el Depósito tenía «Vencimiento», que no
// se carga, y calculaba «En depósito» en el navegador—. Germán: «creo que esta tabla debería ser
// igual… el vencimiento es algo que no agregamos, así que esa columna no va».

const FILA = {
  id: 7, numero_lote_producto: 'ST-26-0007', forma_producto: 'flor_seca', unidad: 'g',
  origen: 'compra_externa', regulatorio: false, estado: 'asignado',
  cantidad: 64, cantidad_inicial: 100, precio_sugerido_ars: 3500,
  disponible_para_entregar: 60, en_mostrador_g: 42, en_deposito_g: 22, reservado: 4,
  sede: { id: 1, nombre: 'Pagola' }, lote: null, genetica: { id: 2, nombre: 'Fruti Punchi' },
  created_at: '2026-09-20T12:00:00Z', descripcion: null,
}

const listStockInventario = vi.fn(() => Promise.resolve({ data: {
  stocks: [FILA],
  meta: { total: 1, page: 1, per_page: 25 },
  totales: { en_deposito_g: 134, en_mesa_g: 130, reservado_g: 4, derivados_items: 2 },
} }))
vi.mock('../lib/api.js', () => ({ listStockInventario: (...a) => listStockInventario(...a) }))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('../composables/useUsoPersonal.js', () => ({ useUsoPersonal: () => ({ esPersonal: false }) }))

async function montar (props = {}) {
  setActivePinia(createPinia())
  const Vista = (await import('../views/admin/DepositoDispensacion.vue')).default
  const w = mount(Vista, { props })
  await flushPromises()
  return w
}

const encabezados = w => w.findAll('.stk__inv-th-btn').map(b => b.text().replace(/[▲▼]/g, '').trim())

describe('Depósito › Dispensación: la misma tabla que Stock', () => {
  it('mismas columnas, en el mismo orden, y sin Vencimiento', async () => {
    const w = await montar()
    expect(encabezados(w)).toEqual([
      'Código', 'Tipo', 'Origen', 'Genética', 'Lote', 'Sede', 'Ingresó', 'Observaciones',
      '$ sugerido', 'Depósito', 'Reserva', 'Mostrador', 'Actual',
    ])
    expect(w.text()).not.toMatch(/vencimiento/i)
    w.unmount()
  })

  // «Depósito» es el número del backend, no la cuenta del navegador (cantidad − mesa = 22 acá
  // también, pero se muestra lo que manda el servidor).
  it('las cantidades salen de la fila que manda el backend', async () => {
    const w = await montar()
    expect(w.find('.stk__inv-td-deposito').text()).toBe('22.0g')
    expect(w.find('.stk__inv-td-reserva').text()).toBe('4.0g')
    expect(w.find('.stk__inv-td-actual').text()).toBe('60.0g')
    w.unmount()
  })

  // Con la tabla paginada, sumar las filas daría sólo lo de la página: los KPIs vienen armados.
  it('los KPIs son los totales del backend, no la suma de la página', async () => {
    const w = await montar()
    const kpis = w.findAll('.dd__kpi-val').map(k => k.text())
    expect(kpis).toEqual(['134 g', '130 g', '4 g', '2 items'])
    w.unmount()
  })

  it('respeta la sede que eligió el Depósito', async () => {
    listStockInventario.mockClear()
    const w = await montar({ sedeId: 3 })
    expect(listStockInventario).toHaveBeenCalledWith(expect.objectContaining({ sede_id: 3 }))
    w.unmount()
  })
})
