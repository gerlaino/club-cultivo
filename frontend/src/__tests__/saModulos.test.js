import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

const updateSuperAdminClub = vi.fn(() => Promise.resolve({ data: { bajas_programadas: [] } }))
const confirmar = vi.fn(() => Promise.resolve(true))

vi.mock('../lib/api.js', () => ({
  updateSuperAdminClub:   (...a) => updateSuperAdminClub(...a),
  provisionarPulse:       vi.fn(() => Promise.resolve({ data: {} })),
  provisionarWhatsappClub: vi.fn(() => Promise.resolve({ data: {} })),
  desconectarWhatsappClub: vi.fn(() => Promise.resolve({ data: {} })),
  getSuperAdminCatalogo:  vi.fn(() => Promise.resolve({ data: {
    ia_tiers: [
      { clave: 'basico',     label: 'Básico',     limite_hora: 20,  limite_mes: 500 },
      { clave: 'pro',        label: 'Pro',        limite_hora: 60,  limite_mes: 2000 },
      { clave: 'enterprise', label: 'Enterprise', limite_hora: 200, limite_mes: 10000 },
    ],
  } })),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: confirmar }) }))
vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}))

const SAModulos = (await import('../views/superadmin/SAModulos.vue')).default

// La pantalla de módulos del super admin salió de la ficha (que tenía 1300 líneas) y cambió de
// mecánica: cada interruptor se guarda solo, sin botón de Guardar. Un build que pasa no prueba
// que la pantalla funcione — este test la MONTA con el payload que manda el backend.
describe('SAModulos', () => {
  const club = {
    id: 3,
    ia_tier: 'basico',
    pulse_configurado: false,
    whatsapp_estado: 'sin_configurar',
    features: { cultivo: true, produccion_dispensa: true, ia: true, delivery: false, iot: false },
    features_baja: { delivery: '2026-08-31' },
    suites: [
      { clave: 'cultivo', label: 'Cultivo', desc: 'Salas, lotes y plantas' },
      { clave: 'produccion_dispensa', label: 'Producción y dispensa', desc: 'Pacientes y entregas' },
    ],
    addons: [
      { clave: 'ia',       label: 'Asistente IA', desc: 'Registro por voz', estado: 'andando' },
      { clave: 'delivery', label: 'Delivery',     desc: 'Reparto a domicilio', estado: 'apagado' },
      { clave: 'iot',      label: 'Ambiente / IoT', desc: 'Sensores', estado: 'falta_config',
        falta: 'Falta cargar la API key de Pulse' },
    ],
    incluidos: [{ clave: 'medico', label: 'Módulo médico', incluido_en: 'produccion_dispensa' }],
    en_construccion: [{ clave: 'vista_paciente', label: 'Vista del paciente' }],
    ia_uso: { llamadas: 143, tope: 500, costo_usd: 4.21, cache_hit: 88.5,
              por_funcion: { asistente_parsear: 120, analisis_lote: 23 } },
  }

  const montar = () => mount(SAModulos, {
    props: { club },
    global: { stubs: { DsSpinner: true } },
  })

  beforeEach(() => { updateSuperAdminClub.mockClear(); confirmar.mockClear() })

  it('renderiza los módulos con un interruptor cada uno', () => {
    const w = montar()

    expect(w.text()).toContain('Cultivo')
    expect(w.text()).toContain('Asistente IA')
    // 2 suites + 3 add-ons. Los incluidos NO llevan interruptor: no son una decisión.
    expect(w.findAll('.sam__switch')).toHaveLength(5)
  })

  it('lo que viene dentro de una suite se muestra como parte de ella, sin interruptor', () => {
    expect(montar().text()).toContain('Incluye: Módulo médico')
  })

  it('cuenta los activos, que es lo que se factura', () => {
    // cultivo + produccion_dispensa + ia
    expect(montar().text()).toContain('3 activos')
  })

  it('prender un módulo guarda solo, sin botón de Guardar', async () => {
    const w = montar()
    // El de IoT: tercer add-on, quinto interruptor.
    await w.findAll('.sam__switch')[4].trigger('click')

    expect(updateSuperAdminClub).toHaveBeenCalledWith(3, { features: expect.objectContaining({ iot: true }) })
    expect(confirmar).not.toHaveBeenCalled()   // prender no pregunta: no tiene consecuencias
  })

  it('apagar SÍ pregunta antes: es una baja con fecha', async () => {
    const w = montar()
    await w.findAll('.sam__switch')[0].trigger('click')   // Cultivo, que está prendido

    expect(confirmar).toHaveBeenCalled()
  })

  it('dice hasta cuándo sigue andando lo dado de baja, para poder decírselo al cliente', () => {
    expect(montar().text()).toMatch(/Dado de baja — sigue andando hasta el 31 de agosto/)
  })

  it('el módulo prendido que todavía no funciona explica qué le falta', () => {
    const w = montar()

    expect(w.text()).toContain('Falta cargar la API key de Pulse')
  })

  it('muestra el consumo de IA del mes contra su tope', () => {
    const w = montar()

    expect(w.text()).toContain('143 de 500 consultas')
    expect(w.text()).toContain('US$ 4.21')
    expect(w.text()).toContain('Caché: 88.5%')
    expect(w.text()).toContain('Registro por voz: 120')
  })

  it('la barra de consumo refleja el porcentaje usado', () => {
    const barra = montar().find('.sam__bar-fill')

    expect(barra.attributes('style')).toContain('width: 29%')   // 143/500
  })

  it('los tramos de IA salen del catálogo del backend, no de una copia local', async () => {
    const w = montar()
    await new Promise(r => setTimeout(r, 0))

    expect(w.text()).toContain('2.000 consultas por mes')       // el tramo Pro, tal como lo manda
    expect(w.findAll('.sam__tier')).toHaveLength(3)
  })

  it('la configuración de un módulo apagado no se muestra: no hay nada que configurar', () => {
    // IoT está apagado en este club, así que su API key no aparece todavía.
    expect(montar().text()).not.toContain('API key de Pulse Grow')
  })

  it('lo que está en construcción se lista, para que nadie lo prometa', () => {
    const w = montar()

    expect(w.text()).toContain('Vista del paciente')
    expect(w.text()).toContain('en construcción')
  })
})
