import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'


const ModalIngreso = (await import('../components/contabilidad/ModalIngreso.vue')).default

// AC (Germán): la plata que entra todos los días ya tiene su puerta —el pago de un paciente se
// registra en su cuenta corriente, el recupero en la dispensación, la venta del buffet en el
// mostrador— y volver a cargarla a mano la contaría DOS VECES. Lo que quedaba sin lugar era lo
// EXCEPCIONAL: una subvención, una donación, la venta de un bien. Esta es su puerta, y es chica.
describe('ModalIngreso', () => {
  beforeEach(() => { document.body.innerHTML = '' })

  const montar = async (props = {}) => {
    const w = mount(ModalIngreso, {
      props: { modelValue: false, sedes: [], unidades: [{ id: 1, nombre: 'General' }], ...props },
      global: { stubs: { Teleport: true, AppDatePicker: true } },
    })
    await w.setProps({ modelValue: true })
    await w.vm.$nextTick()
    return w
  }

  it('ofrece los orígenes excepcionales', async () => {
    const w = await montar()

    const texto = w.text()
    for (const origen of ['Subvención', 'Donación', 'Venta de un bien', 'Otro']) {
      expect(texto).toContain(origen)
    }
  })

  // Lo que hace corto a este formulario es lo que NO pregunta.
  it('no pregunta cantidad, unidad, cuotas ni depósito', async () => {
    const w = await montar()

    const texto = w.text().toLowerCase()
    expect(texto).not.toContain('cantidad')
    expect(texto).not.toContain('cuotas')
    expect(texto).not.toContain('inventario')
    expect(texto).not.toContain('depósito')
    expect(texto).not.toContain('comprobante')
  })

  // Y dice dónde va lo rutinario, para que nadie lo cargue acá y lo duplique.
  it('avisa que el pago de un paciente va por su cuenta corriente', async () => {
    const w = await montar()

    expect(w.text()).toMatch(/cuenta corriente/i)
  })

  it('no deja guardar sin monto ni detalle', async () => {
    const w = await montar()

    expect(w.vm.puedeGuardar).toBe(false)
  })

  it('emite un movimiento de INGRESO, ya pagado, con el origen en la descripción', async () => {
    const w = await montar()
    w.vm.form.monto_ars   = 500000
    w.vm.form.descripcion = 'Aporte municipal'
    w.vm.form.origen      = 'subvencion'
    await w.vm.$nextTick()

    w.vm.guardar()

    const [payload] = w.emitted('guardado')[0]
    expect(payload.tipo).toBe('ingreso')
    expect(payload.monto_ars).toBe(500000)
    expect(payload.pagado).toBe(true)
    expect(payload.categoria).toBe('subvencion')
    expect(payload.descripcion).toContain('Subvención')
    expect(payload.descripcion).toContain('Aporte municipal')
  })

  // La venta de un bien no es una subvención: no puede caer en la misma categoría contable.
  it('cada origen va a la categoría que le corresponde', async () => {
    const w = await montar()
    w.vm.form.monto_ars   = 100
    w.vm.form.descripcion = 'Deshumidificador viejo'
    w.vm.form.origen      = 'venta_bien'
    await w.vm.$nextTick()

    w.vm.guardar()

    expect(w.emitted('guardado')[0][0].categoria).toBe('otro')
  })

  // Con una sola sede no tiene sentido preguntar en cuál entró la plata.
  it('la sede se pregunta sólo si hay más de una', async () => {
    const una = await montar({ sedes: [{ id: 1, nombre: 'Única' }] })
    expect(una.text()).not.toContain('Sede')

    const dos = await montar({ sedes: [{ id: 1, nombre: 'A' }, { id: 2, nombre: 'B' }] })
    expect(dos.text()).toContain('Sede')
  })
})
