import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { useAuthStore } from '../stores/auth'

// AC (Germán, 29-sep-2026): «¿qué recibió este lote?».
// - La ficha muestra los totales por producto y cada aplicación con sus cantidades;
// - lo que no salió del depósito se ve con su salvedad (no «0 ml»);
// - lo cargado como texto se dice «sin cantidades»;
// - la plata sólo si el backend dice que se ve (`con_costo`);
// - el riego y la fertilización tienen UNA puerta: el historial no los carga como texto, abre el
//   registro de riego.
const api = vi.hoisted(() => ({ getLoteNutricion: vi.fn() }))
vi.mock('../lib/api.js', () => ({ getLoteNutricion: (...a) => api.getLoteNutricion(...a) }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: vi.fn() }))

const DATA = {
  lote_id: 5, codigo: 'L-1', plantas: 4, con_costo: true,
  totales: { aplicaciones: 3, sin_cantidades: 1, litros: 15, litros_por_planta: 3.75, ec: 1.3, ph: 6.1, costo_ars: 400, costo_por_planta: 100,
    productos: [{ nombre: 'Bio-Grow', unidad: 'mililitro', cantidad: 30, por_planta: 7.5, veces: 2, sin_descontar: 0 },
                { nombre: 'Cal-Mag', unidad: 'mililitro', cantidad: 15, por_planta: 3.75, veces: 2, sin_descontar: 5 }] },
  por_fase: { vegetativo: { aplicaciones: 2, litros: 15, ec: 1.3, ph: 6.1, costo_ars: 400 } },
  aplicaciones: [
    { fuente: 'registro', id: 1, fecha: '2026-09-20T12:00:00Z', semana_label: 'V3', titulo: 'Vege', litros: 5, parte: 1, ec: 1.3, ph: 6.1,
      productos: [{ nombre: 'Bio-Grow', unidad: 'mililitro', cantidad: 10 }, { nombre: 'Cal-Mag', unidad: 'mililitro', cantidad: 5, motivo: 'sin_stock', motivo_label: 'no alcanzó el stock' }] },
    { fuente: 'actividad', id: 9, fecha: '2026-09-10T12:00:00Z', semana_label: 'V2', titulo: 'Fertilización', texto: 'bloom a ojo', productos: [], sin_cantidades: true },
  ],
}

async function montar(data = DATA, rol = 'admin') {
  setActivePinia(createPinia())
  useAuthStore().user = { role: rol }
  api.getLoteNutricion.mockResolvedValue({ data })
  const C = (await import('../components/lotes/LoteNutricionSection.vue')).default
  const w = mount(C, { props: { loteId: 5 }, global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } } })
  await flushPromises()
  return w
}

describe('Nutrición del lote en la ficha', () => {
  beforeEach(() => api.getLoteNutricion.mockReset())

  it('muestra el total por producto y lo que no se descontó', async () => {
    const w = await montar()
    const filas = w.findAll('.lns__tabla').at(0).findAll('tbody tr').map(r => r.text())
    expect(filas[0]).toContain('Bio-Grow')
    expect(filas[0]).toContain('30 ml')
    expect(filas[1]).toContain('5 ml sin descontar')
  })

  it('cada aplicación con cantidades y la salvedad; lo de texto dice «sin cantidades»', async () => {
    const w = await montar()
    await w.find('.lns__toggle').trigger('click')
    expect(w.text()).toContain('Cal-Mag 5 ml · sin descontar: no alcanzó el stock')
    expect(w.text()).toContain('bloom a ojo (sin cantidades)')
    expect(w.text()).toContain('1 fertilización quedó como texto, sin cantidades')
  })

  it('sin permiso de plata no muestra pesos', async () => {
    const { costo_ars, costo_por_planta, ...totales } = DATA.totales
    const w = await montar({ ...DATA, con_costo: false, totales, por_fase: {} })
    expect(w.text()).not.toContain('$')
    expect(w.text()).not.toContain('en nutrientes')
  })

  it('«Comparar con otros lotes» sólo para quien entra a Analítica', async () => {
    expect((await montar(DATA, 'admin')).text()).toContain('Comparar con otros lotes')
    expect((await montar(DATA, 'cultivador')).text()).not.toContain('Comparar con otros lotes')
  })

  it('el agua: total y por planta, y cuántos riegos tienen el volumen cargado', async () => {
    const w = await montar({ ...DATA, totales: { ...DATA.totales, agua_l: 120, agua_por_planta: 30, riegos: 8, riegos_con_volumen: 6 } })
    expect(w.text()).toContain('120 L')
    expect(w.text()).toContain('30 L/planta')
    expect(w.text()).toContain('6 de 8 riegos tienen el volumen cargado')
  })

  it('sin volumen cargado no inventa «0 L» de agua', async () => {
    const w = await montar()
    expect(w.text()).not.toContain('de agua')
  })

  it('sin aplicaciones dice cómo se carga', async () => {
    const w = await montar({ ...DATA, aplicaciones: [], totales: { ...DATA.totales, aplicaciones: 0 } })
    expect(w.text()).toContain('Todavía no se registró ningún riego con volumen ni fertilización')
  })

  it('regado con agua sola (sin fertilizaciones) muestra el agua, no «vacío»', async () => {
    const w = await montar({ ...DATA, aplicaciones: [], por_fase: {},
      totales: { aplicaciones: 0, litros: 0, productos: [], agua_l: 42, agua_por_planta: 14, riegos: 3, riegos_con_volumen: 3, costo_ars: 0 } })
    expect(w.text()).not.toContain('Todavía no se registró')
    expect(w.text()).toContain('42 L')
    expect(w.text()).toContain('14 L/planta')
    expect(w.text()).not.toContain('Ver las')
  })
})

describe('Una sola puerta para el riego', () => {
  it('el formulario del historial no ofrece riego ni fertilización como texto, y abre el registro de riego', async () => {
    const F = (await import('../components/lotes/RegistrarActividadForm.vue')).default
    const w = mount(F, { global: { stubs: { AppDatePicker: true } } })
    const opciones = w.find('select.raf__sel').findAll('option').map(o => o.attributes('value'))
    expect(opciones).not.toContain('riego')
    expect(opciones).not.toContain('fertilizacion')
    await w.find('.raf__riego').trigger('click')
    expect(w.emitted('riego')).toHaveLength(1)
  })
})
