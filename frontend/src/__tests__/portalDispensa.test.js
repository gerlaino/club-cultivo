import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'

// EL DETALLE DE UNA DISPENSA EN EL PORTAL (27-oct-2026).
//
// AC: abre una dispensa suya y ve qué se llevó, cómo pagó y, de cada producto, la trazabilidad
// del lote (etapas con fecha y sala, análisis, lo que recibió el cultivo). La genética se abre
// sólo si la organización se la muestra; si no, no hay enlace que lleve a un «no encontrado».

const api = vi.hoisted(() => ({ getPortalDispensa: vi.fn() }))
vi.mock('@/lib/portalApi', () => api)

const PortalDispensaView = (await import('../views/portal/PortalDispensaView.vue')).default

const DISPENSA = {
  id: 842, numero: '0842', fecha: '2026-10-21', hora: '2026-10-21T21:12:00Z', sede: 'Sede Centro',
  total: 5000, anulada: false, envio: null, descuento: null, token: 'tok-842',
  pagos: [{ medio: 'Efectivo', monto: 9500 }, { medio: 'De tu saldo a favor', monto: -4500 }],
  items: [{
    nombre: 'Northern Lights', forma: 'Flor seca', cantidad: 5, unidad: 'g', precio: 5000,
    frasco: { numero: 'F-0931', elaborado: '2026-10-18' },
    genetica: { id: 7, nombre: 'Northern Lights', tipo: 'indica' },
    lote: {
      codigo: 'L-26-031', origen: 'De esqueje', plantas: 24, sala: 'Sala Norte',
      etapas: [
        { etapa: 'Enraizado', fecha: '2026-06-12T10:00:00Z', detalle: '14 días' },
        { etapa: 'Floración', fecha: '2026-08-06T10:00:00Z', detalle: 'Sala Norte · 56 días' },
        { etapa: 'Envasado', fecha: '2026-10-18', detalle: 'Frasco F-0931' },
        { etapa: 'Te lo entregaron', fecha: '2026-10-21', detalle: 'Sede Centro · dispensa #0842', es_entrega: true },
      ],
      analisis: { laboratorio: 'Laboratorio Sur', fecha: '2026-10-09', thc: 18.2, cbd: 0.4, cbg: 0.9, terpenos: 'mirceno, pineno' },
      nutricion: ['Humus de lombriz', 'Té de compost'], suelo_vivo: false,
      fitosanitarios: [{ producto: 'Aceite de neem', motivo: 'preventivo', carencia_dias: 7 }],
    },
  }],
}

async function abrir() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/portal/dispensas/:id', name: 'portal-dispensa', component: { template: '<div/>' } },
      { path: '/portal/geneticas/:id', name: 'portal-genetica', component: { template: '<div/>' } },
      { path: '/:p(.*)*', component: { template: '<div/>' } },
    ],
  })
  await router.push('/portal/dispensas/842')
  const w = mount(PortalDispensaView, { global: { plugins: [router] } })
  await flushPromises()
  return w
}

beforeEach(() => api.getPortalDispensa.mockClear())
enableAutoUnmount(afterEach)

describe('El detalle de una dispensa', () => {
  it('pide la dispensa de la URL y muestra número, fecha y cómo se pagó', async () => {
    api.getPortalDispensa.mockResolvedValue(DISPENSA)
    const w = await abrir()

    expect(api.getPortalDispensa).toHaveBeenCalledWith('842')
    expect(w.text()).toContain('Dispensa Nº 0842')
    expect(w.text()).toContain('21 de octubre')
    expect(w.text()).toContain('Efectivo')
    expect(w.text()).toContain('De tu saldo a favor')
  })

  it('muestra la trazabilidad del lote: etapas con su detalle, análisis y aplicaciones', async () => {
    api.getPortalDispensa.mockResolvedValue(DISPENSA)
    const w = await abrir()
    const item = w.find('[data-testid="item-0"]')

    expect(item.text()).toContain('L-26-031')
    expect(item.findAll('.pdv__etapa').map((e) => e.find('b').text())).toEqual(['Enraizado', 'Floración', 'Envasado', 'Te lo entregaron'])
    expect(item.text()).toContain('Sala Norte · 56 días')
    expect(item.text()).toContain('THC 18,2%')
    expect(item.text()).toContain('Aceite de neem (preventivo) · carencia 7 días')
  })

  it('enlaza la genética cuando la organización se la muestra, y no cuando no', async () => {
    api.getPortalDispensa.mockResolvedValue(DISPENSA)
    let w = await abrir()
    expect(w.find('.pdv__link').attributes('href')).toBe('/portal/geneticas/7')

    api.getPortalDispensa.mockResolvedValue({ ...DISPENSA, items: [{ ...DISPENSA.items[0], genetica: { id: null, nombre: 'Northern Lights' } }] })
    w = await abrir()
    expect(w.find('.pdv__link').exists()).toBe(false)
  })

  it('sin análisis ni aplicaciones lo dice, en vez de dejar el hueco', async () => {
    const sinNada = { ...DISPENSA.items[0], lote: { ...DISPENSA.items[0].lote, analisis: null, fitosanitarios: [], nutricion: [] } }
    api.getPortalDispensa.mockResolvedValue({ ...DISPENSA, items: [sinNada] })
    const w = await abrir()

    expect(w.text()).toContain('todavía no tiene un análisis cargado')
    expect(w.text()).toContain('ninguna registrada')
  })

  it('una dispensa que no es suya: «No encontramos esa dispensa»', async () => {
    // El rechazo con un mock nuevo: reusar el del archivo (que ya resolvió en las pruebas de arriba)
    // hacía que vitest anotara este rechazo como error de la prueba aunque la pantalla lo atrapa.
    let rechazos = 0
    api.getPortalDispensa = vi.fn(async () => { rechazos++; throw Object.assign(new Error('404'), { response: { status: 404 } }) })
    const w = await abrir()
    expect(rechazos).toBe(1)
    expect(w.text()).toContain('No encontramos esa dispensa.')
  })
})
