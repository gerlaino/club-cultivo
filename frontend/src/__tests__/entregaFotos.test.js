import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { vModal } from '../directives/modal.js'

// DOS FOTOS DISTINTAS NO PUEDEN TENER EL MISMO BOTÓN.
//
// El modal de entrega tenía "📄 Subir / tomar foto" dos veces, con el mismo ícono y a quince
// renglones una de otra: el comprobante de PAGO y la foto de la ENTREGA. Germán, probando en el
// teléfono: "sigue duplicado lo de tomar foto".
//
// Son dos cosas distintas de verdad —el comprobante de pago cuelga del cobro y no se borra nunca;
// la foto de la entrega se purga a los 30 días— así que no se saca ninguna: se las nombra. Y la
// de la transferencia aparece SÓLO si hay transferencia: cobrando en efectivo no hay nada que
// fotografiar, y ése era el botón que sobraba nueve de cada diez veces.

const PAQUETE = {
  id: 1, estado_envio: 'en_viaje', codigo_paquete: 'PKG-1', orden_entrega: 1,
  paciente: { nombre: 'Rocío Medina' }, direccion_envio: 'Rivadavia 5066',
  saldo_pendiente: 212500, cobrar_en_entrega: true, aporte_socio_ars: 212500,
}

vi.mock('../lib/api.js', () => ({
  getMisPaquetes: vi.fn(() => Promise.resolve({ data: { dispensaciones: [PAQUETE] } })),
  iniciarViaje:   vi.fn(() => Promise.resolve({ data: {} })),
  ordenarRuta:    vi.fn(() => Promise.resolve({ data: {} })),
}))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('../composables/useEntregasOffline.js', () => ({
  useEntregasOffline: () => ({ pendientes: { value: [] }, entregarConReintento: vi.fn(), fallaConReintento: vi.fn() }),
}))

import { useAuthStore } from '../stores/auth.js'

async function abrirModal () {
  setActivePinia(createPinia())
  useAuthStore().user = { id: 9, role: 'delivery' }
  const Vista = (await import('../views/delivery/DeliveryDashboard.vue')).default
  const w = mount(Vista, { global: { stubs: { Teleport: true }, directives: { modal: vModal } } })
  await flushPromises()
  await w.find('.dlv__foco-btn--ok').trigger('click')
  await flushPromises()
  return w
}

const etiquetas = w => w.findAll('.dlv__foto-label').map(l => l.text())

beforeEach(() => { vi.clearAllMocks() })

describe('Las fotos de la entrega', () => {
  it('cobrando en efectivo hay UNA sola foto: la de la entrega', async () => {
    const w = await abrirModal()
    const ls = etiquetas(w)

    expect(ls.length).toBe(1)
    expect(ls[0]).toContain('Foto de la entrega')
    w.unmount()
  })

  it('con transferencia aparece la suya, y cada una dice de qué es', async () => {
    const w = await abrirModal()
    await w.findAll('.dlv__cobro-cell input')[1].setValue(12500)
    await flushPromises()

    const ls = etiquetas(w)
    expect(ls.length).toBe(2)
    expect(ls[0]).toContain('Foto de la transferencia')
    expect(ls[1]).toContain('Foto de la entrega')
    // Ninguna se llama igual que la otra: ése era todo el problema.
    expect(new Set(ls).size).toBe(2)

    // Y LOS BOTONES TAMPOCO. Dos botones verdes idénticos a quince renglones uno del otro se
    // leen como el mismo botón repetido, por más que el título de arriba diga otra cosa.
    const botones = w.findAll('.dlv__foto-btn').map(b => b.text())
    expect(botones[0]).toContain('Subir comprobante')
    expect(botones[1]).toContain('Subir / tomar foto')
    expect(new Set(botones).size).toBe(2)
    w.unmount()
  })

  it('si se borra la transferencia, la foto desaparece con ella', async () => {
    const w = await abrirModal()
    const transf = w.findAll('.dlv__cobro-cell input')[1]

    await transf.setValue(12500)
    await flushPromises()
    expect(etiquetas(w).length).toBe(2)

    await transf.setValue(0)
    await flushPromises()
    expect(etiquetas(w).length).toBe(1)
    w.unmount()
  })
})
