import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// AC (Germán, 12-oct-2026): el inicio del administrador como panel de conducción, en registro
// profesional. Arriba el veredicto («N asuntos requieren atención»); lo que requiere atención, en
// el orden del backend (por impacto); al tocar un cierre, la cuenta a la vista; lo demás lleva a
// su pantalla —en el teléfono, a la del teléfono—. La pantalla muestra lo que manda el backend.
const PANEL = {
  periodo: 'mes', sedes: [{ id: 1, nombre: 'Centro' }, { id: 2, nombre: 'Norte' }],
  atencion: [
    { tipo: 'caja', id: 'caja-7', turno_id: 7, sede_id: 1, severidad: 'alta', titulo: 'Faltante de caja · Centro',
      detalle: 'Cierre del 11/10, 21:10 · Responsable: Lucía M.', valor: -12400, unidad: 'ars', impacto_ars: 12400, accion: 'Analizar' },
    { tipo: 'rendicion', id: 'rend-3', severidad: 'media', titulo: 'Rendición pendiente · Delivery',
      detalle: 'Efectivo de 5 entregas sin rendir', valor: 38500, unidad: 'ars', impacto_ars: 38500, accion: 'Ver rendiciones',
      ruta: '/delivery/rendiciones' },
  ],
  seguimiento: [{ clave: 'pesajes', cantidad: 1, texto: 'pesajes de manicura pendientes de aprobación', ruta: '/admin/pesajes-manicura' }],
  en_orden: [{ clave: 'floracion', titulo: 'Plantas en floración', texto: '412 de 450 habilitadas por el plan' }],
  finanzas: { resultado_ars: 1284300, ingresos_ars: 2000000, egresos_ars: 715700, variacion_pct: 12,
              efectivo_en_cajas_ars: 5324070, cuentas_por_cobrar_ars: 186000, cuentas_por_cobrar: 14 },
  inventario: { flor_seca_disponible_g: 2865.4, dispensa_promedio_diaria_g: 124, cobertura_dias: 23, vencimientos_30d: 2 },
  pacientes: { activos: 312, atendidos: 214, reprocann_vigente_pct: 94, turnos_semana: 18 },
  cultivo: { en_floracion: 412, capacidad_floracion: 450, tareas_vencidas: 2,
             proxima_cosecha: { codigo: 'L-26-021', faltan_dias: 9, rendimiento_estimado_g: 1800 } },
  trazabilidad: { cosecha_g: 4120, ingreso_stock_g: 3980, a_mostrador_g: 3210, dispensado_g: 3150, pacientes: 214, diferencias_g: 6.2 },
  estado_sedes: [{ id: 1, nombre: 'Centro', caja: { abierta_at: new Date().toISOString(), responsable: 'Lucía M.' },
                   dispensado_hoy_ars: 412000, dispensado_hoy_g: 86, en_mostrador_g: 2822.6,
                   ultimo_cierre: { fecha: '2026-10-11T21:10:00Z', diferencia_ars: -12400 } }],
  equipo: [{ id: 9, nombre: 'Martín R.', rol: 'delivery', actividad: ['5 entregas'], alertas: ['rendición pendiente de $ 38.500'] }],
  serie_mes: [{ dia: 1, ingresos: 100, egresos: 20, ingresos_mes_anterior: 80 }, { dia: 2, ingresos: 50, egresos: 0, ingresos_mes_anterior: 60 }],
}
const DETALLE = {
  turno_id: 7, sede: { id: 1, nombre: 'Centro' }, responsable: 'Lucía M.', abierto_at: '2026-10-11T12:02:00Z',
  cerrado_at: '2026-10-12T00:10:00Z', revisado: false, observacion: 'Un pago por transferencia quedó como efectivo.',
  conciliacion: { lineas: [{ concepto: 'Fondo inicial declarado en la apertura', monto: 50000 },
                           { concepto: 'Cobros en efectivo (31 dispensas)', monto: 388900 },
                           { concepto: 'Retiro de administración (18:30)', monto: -36000 }],
                  esperado: 402900, declarado: 390500, diferencia: -12400 },
  inventario: [],
  causas: [{ tipo: 'mismo_importe', dispensacion_id: 55, texto: 'Se registró una dispensa en efectivo por $ 12.400 a las 17:42 (paciente A. P.), por el mismo importe que la diferencia.' }],
  jornada: [{ hora: '09:02', texto: 'Apertura con fondo de $ 50.000' }],
}

const getPanel = vi.fn(() => Promise.resolve({ data: PANEL }))
const getDetalle = vi.fn(() => Promise.resolve({ data: DETALLE }))
const revisar = vi.fn(() => Promise.resolve({ data: { revisado: true } }))
vi.mock('../lib/api.js', () => ({
  getPanelConduccion: (...a) => getPanel(...a),
  getDetalleCierrePanel: (...a) => getDetalle(...a),
  revisarTurnoMostrador: (...a) => revisar(...a),
}))
const push = vi.fn()
vi.mock('vue-router', () => ({ useRouter: () => ({ push }), RouterLink: { props: ['to'], template: '<a :href="to"><slot /></a>' } }))
vi.mock('../composables/useRecargaEnCambios.js', () => ({ useRecargaEnCambios: () => {} }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))

const RouterLink = { props: ['to'], template: '<a :href="to"><slot /></a>' }

async function montar (props = {}) {
  const { default: Panel } = await import('../components/panel/PanelConduccion.vue')
  const w = mount(Panel, { props, global: { stubs: { RouterLink, Teleport: true }, directives: { modal: {} } } })
  await flushPromises()
  return w
}

describe('Panel de conducción', () => {
  beforeEach(() => { push.mockClear(); getPanel.mockClear(); revisar.mockClear() })

  it('el veredicto dice cuántos asuntos requieren atención, en registro profesional', async () => {
    const w = await montar()
    expect(w.find('.pc__veredicto').text()).toContain('2 asuntos requieren atención')
    expect(w.find('.pc__veredicto').text()).toContain('dentro de parámetros')
    expect(w.text()).not.toMatch(/cosas para resolver|tenía que haber|\bciclo\b/i)
  })

  it('lo que requiere atención, en el orden del backend (por impacto) y con su valor', async () => {
    const w = await montar()
    const asuntos = w.findAll('.pc__asunto').map(a => a.text())
    expect(asuntos[0]).toContain('Faltante de caja · Centro')
    expect(asuntos[0]).toContain('− $ 12.400')
    expect(asuntos[1]).toContain('Rendición pendiente')
  })

  it('tocar un cierre abre la cuenta: conciliación, causa y la acción de revisar', async () => {
    const w = await montar()
    await w.findAll('.pc__asunto')[0].trigger('click')
    await flushPromises()
    expect(getDetalle).toHaveBeenCalledWith(7)
    const det = w.find('.dcp')
    expect(det.text()).toContain('Saldo esperado')
    expect(det.text()).toContain('$ 402.900')
    expect(det.text()).toContain('Posibles causas detectadas')
    await det.findAll('button').find(b => b.text() === 'Marcar como revisado').trigger('click')
    await flushPromises()
    expect(revisar).toHaveBeenCalledWith(1, 7)
    expect(getPanel).toHaveBeenCalledTimes(2) // se recarga: lo revisado deja de pedir atención
  })

  it('lo que no es un cierre lleva a su pantalla', async () => {
    const w = await montar()
    await w.findAll('.pc__asunto')[1].trigger('click')
    expect(push).toHaveBeenCalledWith('/delivery/rendiciones')
  })

  it('en el teléfono, los enlaces van a las pantallas del teléfono', async () => {
    const w = await montar({ compacto: true })
    await w.findAll('.pc__asunto')[1].trigger('click')
    expect(push).toHaveBeenCalledWith('/m/mostrador')
    expect(w.find('.pc__seg-item').attributes('href')).toBe('/m/admin/aprobar')
  })

  it('los filtros de sede y período piden el panel con ese filtro', async () => {
    const w = await montar()
    await w.findAll('.pc__seg-btn').find(b => b.text() === 'Norte').trigger('click')
    expect(getPanel).toHaveBeenLastCalledWith({ sede_id: 2, periodo: 'mes' })
    await w.findAll('.pc__seg-btn').find(b => b.text() === 'Hoy').trigger('click')
    expect(getPanel).toHaveBeenLastCalledWith({ sede_id: 2, periodo: 'hoy' })
  })

  it('los cuatro números y la trazabilidad muestran lo que manda el backend', async () => {
    const w = await montar()
    const t = w.text()
    expect(t).toContain('$ 1.284.300')
    expect(t).toContain('cobertura de 23 días')
    expect(t).toContain('Dispensado')
    expect(t).toContain('Diferencias de inventario')
    expect(t).toContain('Dentro de parámetros')
  })
})
