import { describe, it, expect, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// SUSPENDIDO POR POCO MOVIMIENTO (Germán, 23-sep-2026): «los que no dispensan más como
// suspendidos… con un tooltip que diga suspendido por poco movimiento o algo así, bien
// distintivo». Lo decide el backend (`suspendido`); la lista lo muestra, distinto de Inactivo.
const hace = (d) => { const f = new Date(); f.setDate(f.getDate() - d); return f.toISOString().slice(0, 10) }
// Desde el 19-oct-2026 el estado viaja en `situacion.paciente` (`Pacientes::Situacion`).
const sit = (paciente) => ({ paciente, reprocann: 'activo', vinculo: 'vinculado', acciones: [] })
const FILAS = [
  { id: 1, nombre: 'Ana',  apellido: 'Activa',     dni: '1', es_paciente: true,  aprobado_at: '2026-01-01', suspendido: false, ultima_dispensacion: hace(5),   situacion: sit('activo') },
  { id: 2, nombre: 'Beto', apellido: 'Suspendido', dni: '2', es_paciente: true,  aprobado_at: '2026-01-01', suspendido: true,  ultima_dispensacion: hace(120), situacion: sit('suspendido') },
  { id: 3, nombre: 'Caro', apellido: 'Inactiva',   dni: '3', es_paciente: false, aprobado_at: '2026-01-01', suspendido: false, ultima_dispensacion: hace(300), situacion: sit('inactivo') },
]
vi.mock('../lib/api.js', () => ({
  listPacientes: vi.fn(() => Promise.resolve({ data: { data: FILAS, meta: { total: 3, kpis: { total: 2, baja: 1, inactivos: 1, vencidos: 0, proximos: 0, pendientes: 0, sin_rep: 0, pendientes_aprobacion: 0 } } } })),
  exportPacientesCSV: vi.fn(),
}))
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {} }), useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  RouterLink: { template: '<a><slot /></a>' },
}))
vi.mock('../stores/auth', () => ({ useAuthStore: () => ({ user: { role: 'admin' } }) }))

describe('Pacientes › suspendido por poco movimiento', () => {
  it('la lista lo marca distinto de activo e inactivo, con el porqué en el tooltip', async () => {
    setActivePinia(createPinia())
    const V = (await import('../views/SociosView.vue')).default
    const w = mount(V, { global: { stubs: { RouterLink: true, SocioEditarModal: true, AppDatePicker: true, DsSpinner: true } } })
    await flushPromises()

    // La columna Estado de la tabla: una pastilla por fila.
    const estados = w.findAll('.sv-table tbody td:nth-child(3) .pf-pill')
    const susp = estados.find(e => e.text() === 'Suspendido')
    expect(susp).toBeTruthy()
    expect(susp.attributes('title')).toMatch(/poco movimiento/)
    // Bien distintivo: no tiene el color de Activo ni el de Inactivo.
    expect(susp.classes()).toContain('pf-pill--warn')
    expect(estados.filter(e => e.text() === 'Activo').map(e => e.classes())).toEqual([['pf-pill', 'pf-pill--ok']])
    expect(w.text()).toContain('Suspendidos')
  })
})
