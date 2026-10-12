import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { yaPaso } from '../utils/dates.js'

// AC (Germán, 12-oct-2026): al dar un turno avisa que no se puede en el pasado, pero al
// REPROGRAMAR dejaba elegir una fecha y hora que ya pasó. Ahora avisa y no lo manda.
const update = vi.fn(() => Promise.resolve({ data: {} }))
vi.mock('../lib/api.js', () => ({ updateMedicoTurno: (...a) => update(...a), updateAdminTurno: (...a) => update(...a) }))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))

const pad = n => String(n).padStart(2, '0')
const fechaDe = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
const horaDe  = d => `${pad(d.getHours())}:${pad(d.getMinutes())}`

describe('yaPaso', () => {
  it('una hora de hoy que ya pasó, sí; una que no llegó, no', () => {
    const ahora = new Date(2026, 9, 12, 15, 0)
    expect(yaPaso('2026-10-12', '14:45', ahora)).toBe(true)
    expect(yaPaso('2026-10-12', '15:15', ahora)).toBe(false)
    expect(yaPaso('2026-10-11', '18:00', ahora)).toBe(true)
  })
})

describe('Reprogramar desde el panel del turno', () => {
  let w
  beforeEach(async () => {
    update.mockClear()
    const { default: Panel } = await import('../components/TurnoDetallePanel.vue')
    w = mount(Panel, {
      props: { turno: { id: 1, estado: 'programado', fecha_hora: new Date(Date.now() + 86400000).toISOString(), duracion_minutos: 30, paciente_nombre: 'Ana' } },
      global: { stubs: { AppDatePicker: true, Teleport: true }, directives: { modal: {} } },
    })
    await w.find('.tdp__accion--reprog').trigger('click')
  })

  it('a una hora de hoy que ya pasó: avisa y no deja confirmar', async () => {
    const antes = new Date(Date.now() - 3600000)
    w.vm.$.setupState.reprogramForm = { fecha: fechaDe(antes), hora: horaDe(antes), duracion_minutos: 30 }
    await flushPromises()
    expect(w.find('.tdp__reprog-warn').exists()).toBe(true)
    const confirmar = w.findAll('.tdp__reprog-form button').find(b => b.text().includes('Confirmar'))
    expect(confirmar.attributes('disabled')).toBeDefined()
    await confirmar.trigger('click')
    expect(update).not.toHaveBeenCalled()
  })

  it('a un momento que todavía no llegó: sin aviso y se manda', async () => {
    const despues = new Date(Date.now() + 2 * 86400000)
    w.vm.$.setupState.reprogramForm = { fecha: fechaDe(despues), hora: horaDe(despues), duracion_minutos: 30 }
    await flushPromises()
    expect(w.find('.tdp__reprog-warn').exists()).toBe(false)
    await w.findAll('.tdp__reprog-form button').find(b => b.text().includes('Confirmar')).trigger('click')
    expect(update).toHaveBeenCalled()
  })
})
