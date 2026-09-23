import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises, DOMWrapper } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// DEVOLVER LA PLATA QUE UN PACIENTE TIENE A FAVOR (Germán, 23-sep-2026).
//
// Lo que un paciente pagó por un paquete que no se le pudo entregar queda a favor suyo. Si lo
// pide, administración se lo devuelve: «en este caso el admin debería seleccionar si se devuelve
// o no la plata (admin/supervisor)». El dispensador no lo ve; el backend tampoco se lo permitiría.

const api = vi.hoisted(() => ({
  getCuentaCorriente: vi.fn(),
  devolverSaldoCC:    vi.fn(),
  listMostradores:    vi.fn(),
}))
vi.mock('../lib/api.js', () => ({
  getCuentaCorriente: (...a) => api.getCuentaCorriente(...a),
  devolverSaldoCC:    (...a) => api.devolverSaldoCC(...a),
  listMostradores:    (...a) => api.listMostradores(...a),
  setLimiteCC: vi.fn(), updatePaciente: vi.fn(), registrarPagoCC: vi.fn(),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))

let rol = 'admin'
vi.mock('../stores/auth.js', () => ({ useAuthStore: () => ({ user: { role: rol } }) }))
vi.mock('../stores/pacientes', () => ({ usePacientesStore: () => ({ current: { descuento_porcentaje: 0 }, fetchOne: vi.fn() }) }))

const CC = (saldo) => ({
  id: 1, paciente_id: 9, limite_credito: 0, saldo_disponible: saldo, movimientos: [],
  credito_gramos_activo: false, saldo_disponible_g: 0,
})

async function montar (saldo = 3000) {
  api.getCuentaCorriente.mockResolvedValue({ data: CC(saldo) })
  // Una caja abierta con $1.000 en el cajón.
  api.listMostradores.mockResolvedValue({ data: { mostradores: [
    { sede_id: 4, sede: 'Pagola', turno: { caja_turno_id: 77, efectivo_esperado: 1000, desde: null, quien: 'Dana' } },
  ] } })
  setActivePinia(createPinia())
  const C = (await import('../components/pacientes/SocioTabCuentaCorriente.vue')).default
  // Teleport de verdad, al body: con el stub de Teleport el hijo se remonta en cada render del
  // padre y el aviso de la caja entra en bucle — un efecto del stub, no de la pantalla.
  const w = mount(C, { props: { socioId: 9 }, attachTo: document.body, global: { directives: { modal: {} } } })
  await flushPromises()
  return w
}

// El modal vive en el body (Teleport): se busca ahí.
const body  = () => new DOMWrapper(document.body)
const boton = w => w.findAll('button').find(b => b.text().includes('Devolver plata'))
const confirmarBtn = () => body().findAll('button').find(b => b.text().startsWith('Devolver $'))

describe('Cuenta corriente › Devolver plata', () => {
  beforeEach(() => { vi.clearAllMocks(); rol = 'admin' })

  it('el admin lo ve cuando el paciente tiene plata a favor', async () => {
    const w = await montar(3000)
    expect(boton(w)).toBeTruthy()
    w.unmount()
  })

  it('el supervisor también', async () => {
    rol = 'supervisor'
    const w = await montar(3000)
    expect(boton(w)).toBeTruthy()
    w.unmount()
  })

  it('el dispensador no', async () => {
    rol = 'dispensador'
    const w = await montar(3000)
    expect(boton(w)).toBeFalsy()
    w.unmount()
  })

  it('sin plata a favor no hay nada que devolver', async () => {
    const w = await montar(0)
    expect(boton(w)).toBeFalsy()
    w.unmount()
  })

  it('por transferencia manda el monto y el medio, sin caja', async () => {
    const w = await montar(3000)
    await boton(w).trigger('click'); await flushPromises();
    await body().find('#scc-dev-monto').setValue(2000)
    await body().find('#cdev-transferencia').trigger('click')
    api.devolverSaldoCC.mockResolvedValue({ data: CC(1000) })
    await confirmarBtn().trigger('click')
    await flushPromises()

    expect(api.devolverSaldoCC).toHaveBeenCalledWith(9, { monto: 2000, medio: 'transferencia' })
    w.unmount()
  })

  // La caja tiene $1.000: devolver $3.000 en efectivo de ahí no se ofrece.
  it('en efectivo, si la caja elegida no alcanza, no deja confirmar y dice por qué', async () => {
    const w = await montar(3000)
    await boton(w).trigger('click'); await flushPromises()
    await body().find('#cdev-caja').setValue(77)
    await flushPromises()

    expect(confirmarBtn().attributes('disabled')).toBeDefined()
    expect(body().text()).toContain('En la caja de Pagola hay')
    w.unmount()
  })

  it('no deja devolver más de lo que tiene a favor', async () => {
    const w = await montar(3000)
    await boton(w).trigger('click'); await flushPromises()
    await body().find('#scc-dev-monto').setValue(5000)

    expect(confirmarBtn().attributes('disabled')).toBeDefined()
    expect(body().text()).toContain('más de lo que tiene a favor')
    w.unmount()
  })
})
