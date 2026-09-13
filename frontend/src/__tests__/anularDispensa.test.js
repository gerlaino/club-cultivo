import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import ModalAnularDispensa from '../components/dispensaciones/ModalAnularDispensa.vue'

// UNA DISPENSA SE ANULA DICIENDO POR QUÉ, y el modal cuenta qué va a pasar con el producto y
// con la plata antes de confirmar. Reemplazó a «Eliminar» (sep-2026).
const dispensa = (extra = {}) => ({
  id: 7, paciente_nombre: 'Ana Pérez', aporte_socio_ars: 10000, medio_pago: 'efectivo',
  items: [{ cantidad: 10, genetica_nombre: 'E2E Haze', stock: { unidad: 'g', forma_producto: 'flor_seca' } }],
  cobros: [{ medio: 'efectivo', monto_ars: 10000, pagado: true }],
  ...extra,
})

const montar = (d = dispensa()) => mount(ModalAnularDispensa, {
  props: { modelValue: true, dispensacion: d },
  attachTo: document.body,
  global: { directives: { modal: {} } },
})

describe('ModalAnularDispensa', () => {
  it('no deja anular sin motivo', () => {
    const w = montar()
    expect(document.body.querySelector('.ad__btn').disabled).toBe(true)
    expect(document.body.querySelector('.ad__oracion')).toBeNull()
    w.unmount()
  })

  it('error de carga: el ingreso se borra y el producto vuelve', async () => {
    const w = montar()
    await document.body.querySelector('#ad-motivo-error_carga').click()
    const o = document.body.querySelector('.ad__oracion').textContent
    expect(o).toContain('10 g de E2E Haze vuelve al stock')
    expect(o).toContain('se borra')
    expect(document.body.querySelector('#ad-descartar')).toBeNull()
    w.unmount()
  })

  it('devolución en efectivo: la venta queda y la plata sale de la caja; se puede descartar el producto', async () => {
    const w = montar()
    await document.body.querySelector('#ad-motivo-devolucion').click()
    let o = document.body.querySelector('.ad__oracion').textContent
    expect(o).toContain('La venta queda registrada')
    expect(o).toContain('en efectivo de la caja')
    const check = document.body.querySelector('#ad-descartar')
    expect(check).not.toBeNull()
    check.click(); await w.vm.$nextTick()
    o = document.body.querySelector('.ad__oracion').textContent
    expect(o).toContain('sale como merma')
    w.unmount()
  })

  it('devolución por transferencia queda pendiente hasta registrar el pago', async () => {
    const w = montar(dispensa({ medio_pago: 'transferencia', cobros: [{ medio: 'transferencia', monto_ars: 10000, pagado: true }] }))
    await document.body.querySelector('#ad-motivo-devolucion').click()
    expect(document.body.querySelector('.ad__oracion').textContent).toContain('devolución pendiente')
    w.unmount()
  })

  it('producto defectuoso: merma sin preguntar, y emite lo que el backend espera', async () => {
    const w = montar()
    await document.body.querySelector('#ad-motivo-producto_defectuoso').click()
    expect(document.body.querySelector('#ad-descartar')).toBeNull()
    expect(document.body.querySelector('.ad__oracion').textContent).toContain('sale como merma')
    const nota = document.body.querySelector('#ad-nota'); nota.value = 'preroll roto'; nota.dispatchEvent(new Event('input'))
    await w.vm.$nextTick()
    document.body.querySelector('.ad__btn').click()
    expect(w.emitted('anular')[0][0]).toEqual({ id: 7, motivo: 'producto_defectuoso', nota: 'preroll roto', descartar_producto: true })
    w.unmount()
  })
})
