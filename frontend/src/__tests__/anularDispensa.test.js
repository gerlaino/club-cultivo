import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// UNA DISPENSA SE ANULA DICIENDO POR QUÉ, y el modal cuenta qué va a pasar con el producto y
// con la plata antes de confirmar. Reemplazó a «Eliminar» (sep-2026). Con producto defectuoso
// hay dos salidas —devolver la plata o cambiar el producto—, y la plata vuelve por el medio que
// se elige, de una caja a la que le tiene que alcanzar (Germán, 14-sep).
const MOSTRADORES = { mostradores: [
  { sede_id: 1, sede: 'Sede E2E', turno: { caja_turno_id: 77, desde: '2026-09-14T12:00:00Z', quien: 'Dana', efectivo_esperado: 60000 } },
  { sede_id: 2, sede: 'Norte',    turno: { caja_turno_id: 78, desde: '2026-09-14T12:00:00Z', quien: null, efectivo_esperado: 2000 } },
] }
vi.mock('../lib/api.js', () => ({
  default: { get: vi.fn(), post: vi.fn() },
  listMostradores: vi.fn(() => Promise.resolve({ data: MOSTRADORES })),
}))
const ModalAnularDispensa = (await import('../components/dispensaciones/ModalAnularDispensa.vue')).default
const { useAuthStore } = await import('../stores/auth')

const dispensa = (extra = {}) => ({
  id: 7, paciente_nombre: 'Ana Pérez', aporte_socio_ars: 10000, medio_pago: 'efectivo', sede: { id: 1, nombre: 'Sede E2E' },
  items: [{ cantidad: 10, genetica_nombre: 'E2E Haze', stock: { unidad: 'g', forma_producto: 'flor_seca' } }],
  cobros: [{ medio: 'efectivo', monto_ars: 10000, pagado: true }],
  ...extra,
})

beforeEach(() => { setActivePinia(createPinia()); useAuthStore().user = { role: 'admin' }; document.body.innerHTML = '' })

const montar = async (d = dispensa()) => {
  const w = mount(ModalAnularDispensa, {
    props: { modelValue: true, dispensacion: d },
    attachTo: document.body,
    global: { directives: { modal: {} } },
  })
  await flushPromises()
  return w
}
const q = (sel) => document.body.querySelector(sel)
const texto = (sel) => (q(sel)?.textContent || '').replace(/\u00a0/g, ' ')

describe('ModalAnularDispensa', () => {
  it('no deja anular sin motivo', async () => {
    const w = await montar()
    expect(document.body.querySelector('.ad__btn').disabled).toBe(true)
    expect(document.body.querySelector('.ad__oracion')).toBeNull()
    w.unmount()
  })

  it('error de carga: el ingreso se borra y el producto vuelve', async () => {
    const w = await montar()
    await document.body.querySelector('#ad-motivo-error_carga').click()
    const o = document.body.querySelector('.ad__oracion').textContent
    expect(o).toContain('10 g de E2E Haze vuelve al stock')
    expect(o).toContain('se borra')
    expect(document.body.querySelector('#ad-descartar')).toBeNull()
    w.unmount()
  })

  it('devolución en efectivo: la venta queda y la plata sale de la caja; se puede descartar el producto', async () => {
    const w = await montar()
    await document.body.querySelector('#ad-motivo-devolucion').click()
    let o = document.body.querySelector('.ad__oracion').textContent
    expect(o).toContain('La venta queda registrada')
    expect(o.replace(/\u00a0/g, ' ')).toContain('en efectivo de la caja de Sede E2E')
    const check = document.body.querySelector('#ad-descartar')
    expect(check).not.toBeNull()
    check.click(); await w.vm.$nextTick()
    o = document.body.querySelector('.ad__oracion').textContent
    expect(o).toContain('sale como merma')
    w.unmount()
  })

  it('devolución por transferencia queda pendiente hasta registrar el pago', async () => {
    const w = await montar(dispensa({ medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto_ars: 10000, pagado: true }] }))
    await document.body.querySelector('#ad-motivo-devolucion').click()
    expect(document.body.querySelector('.ad__oracion').textContent).toContain('devolución pendiente')
    w.unmount()
  })

  it('la plata vuelve por el medio que se elige, y administración dice de qué caja', async () => {
    const w = await montar()
    await q('#ad-motivo-devolucion').click()
    expect(q('#ad-dev-efectivo').getAttribute('aria-checked')).toBe('true') // por donde pagó
    expect(q('#ad-caja').value).toBe('77')                                  // la de su sede
    await q('#ad-dev-transferencia').click()
    expect(texto('.ad__oracion')).toContain('devolución pendiente de $ 10.000 por transferencia')
    expect(q('#ad-caja')).toBeNull()
    await q('#ad-dev-efectivo').click()
    q('.ad__btn').click()
    expect(w.emitted('anular')[0][0]).toMatchObject({ motivo: 'devolucion', resolucion: 'devolver_plata', devolucion: { medio: 'efectivo', caja_turno_id: 77 } })
    w.unmount()
  })

  it('en efectivo tiene que alcanzar lo que hay en la caja', async () => {
    const w = await montar()
    await q('#ad-motivo-devolucion').click()
    q('#ad-caja').value = '78'; q('#ad-caja').dispatchEvent(new Event('change')); await w.vm.$nextTick()
    expect(texto('.ad__err')).toContain('hay $ 2.000 y hay que devolver $ 10.000')
    expect(q('.ad__btn').disabled).toBe(true)
    await q('#ad-dev-transferencia').click()
    expect(q('.ad__err')).toBeNull()
    expect(q('.ad__btn').disabled).toBe(false)
    w.unmount()
  })

  it('quien atiende devuelve de su caja y no elige; con la caja cerrada, sólo por transferencia', async () => {
    useAuthStore().user = { role: 'dispensador' }
    const w = await montar(dispensa({ sede: { id: 3, nombre: 'Sur' } }))
    await q('#ad-motivo-devolucion').click()
    expect(q('#ad-caja')).toBeNull()
    expect(texto('.ad__err')).toContain('Tu caja está cerrada')
    expect(q('.ad__btn').disabled).toBe(true)
    await q('#ad-dev-transferencia').click()
    expect(q('.ad__btn').disabled).toBe(false)
    w.unmount()
  })

  it('producto defectuoso: se puede cambiar el producto en vez de devolver la plata', async () => {
    const w = await montar()
    await q('#ad-motivo-producto_defectuoso').click()
    expect(q('#ad-res-plata').getAttribute('aria-checked')).toBe('true')
    expect(q('#ad-dev-efectivo')).not.toBeNull()
    await q('#ad-res-cambio').click()
    expect(q('#ad-dev-efectivo')).toBeNull()
    expect(texto('.ad__oracion')).toContain('cubre lo que se lleve en el cambio')
    expect(texto('.ad__oracion')).toContain('sale como merma')
    expect(q('.ad__btn').textContent).toContain('elegir el cambio')
    q('.ad__btn').click()
    expect(w.emitted('anular')[0][0]).toMatchObject({ motivo: 'producto_defectuoso', resolucion: 'cambio', descartar_producto: true })
    expect(w.emitted('anular')[0][0].devolucion).toBeUndefined()
    w.unmount()
  })

  it('producto defectuoso: merma sin preguntar, y emite lo que el backend espera', async () => {
    const w = await montar()
    await document.body.querySelector('#ad-motivo-producto_defectuoso').click()
    expect(document.body.querySelector('#ad-descartar')).toBeNull()
    expect(document.body.querySelector('.ad__oracion').textContent).toContain('sale como merma')
    const nota = document.body.querySelector('#ad-nota'); nota.value = 'preroll roto'; nota.dispatchEvent(new Event('input'))
    await w.vm.$nextTick()
    document.body.querySelector('.ad__btn').click()
    expect(w.emitted('anular')[0][0]).toEqual({ id: 7, motivo: 'producto_defectuoso', nota: 'preroll roto', descartar_producto: true, resolucion: 'devolver_plata', devolucion: { medio: 'efectivo', caja_turno_id: 77 } })
    w.unmount()
  })
})
