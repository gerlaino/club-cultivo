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
    { clave: 'ia',       label: 'Asistente IA', desc: 'Registro por voz', estado: 'andando', pack: null },
    { clave: 'delivery', label: 'Delivery',     desc: 'Reparto a domicilio', estado: 'apagado',
      pack: 'produccion_dispensa', pack_label: 'Producción y dispensa' },
    { clave: 'iot',      label: 'Ambiente / IoT', desc: 'Sensores', estado: 'falta_config',
      pack: 'cultivo', pack_label: 'Cultivo', falta: 'Falta cargar la API key de Pulse' },
    { clave: 'bar',      label: 'Buffet', desc: 'Punto de venta', estado: 'apagado',
      pack: 'produccion_dispensa', pack_label: 'Producción y dispensa', incompleto: true },
    { clave: 'whatsapp', label: 'WhatsApp', desc: 'Avisos por WhatsApp', estado: 'apagado',
      pack: 'produccion_dispensa', pack_label: 'Producción y dispensa',
      bloqueado: true, motivo_bloqueo: 'Falta dar de alta la cuenta de Twilio de la plataforma.' },
  ],
  incluidos: [{ clave: 'medico', label: 'Módulo médico', incluido_en: 'produccion_dispensa' }],
  en_construccion: [{ clave: 'vista_paciente', label: 'Portal del paciente' }],
  // El tope se cuenta en CRÉDITOS; `llamadas` es informativo. Van distintos a propósito en el
  // fixture: si la pantalla mezclara las unidades, estos números lo delatan.
  ia_uso: { llamadas: 143, creditos: 210, restantes: 290, tope: 500, costo_usd: 4.21,
            cache_hit: 88.5,
            desglose: [
              { funcion: 'asistente_parsear', label: 'Registro por voz',   llamadas: 120, creditos: 150 },
              { funcion: 'chatbot',           label: 'Chatbot del admin',  llamadas: 23,  creditos: 60 },
            ] },
}

const montarModulos = (overrides = {}) => mount(SAModulos, {
  props: { club: { ...club, ...overrides } },
  global: { stubs: { DsSpinner: true } },
})

/** La tarjeta de un módulo, buscada por su nombre visible. */
const filaDe = (w, label) =>
  w.findAll('.sam__addon').find(f => f.find('.sam__name').text().startsWith(label))

describe('SAModulos', () => {
  const montar = montarModulos

  beforeEach(() => { updateSuperAdminClub.mockClear(); confirmar.mockClear() })

  it('renderiza los módulos con un interruptor cada uno', () => {
    const w = montar()

    expect(w.text()).toContain('Cultivo')
    expect(w.text()).toContain('Asistente IA')
    // 2 suites + 5 add-ons. Los incluidos NO llevan interruptor: no son una decisión.
    expect(w.findAll('.sam__switch')).toHaveLength(7)
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
    // Por NOMBRE y no por posición: agrupar los adicionales por pack los reordenó, y el test
    // empezó a tocar otro interruptor sin que nada lo dijera.
    await filaDe(w, 'Ambiente / IoT').find('.sam__switch').trigger('click')

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

  it('mide el consumo en CRÉDITOS, que es la unidad del tope', () => {
    // Mostraba `llamadas` contra un tope de créditos: dos unidades en la misma barra, y la
    // organización se podía quedar sin IA en un número distinto al que veía acá.
    const w = montar()

    expect(w.text()).toContain('210 de 500 créditos')
    expect(w.text()).not.toContain('143 de 500')
    expect(w.text()).toContain('US$ 4.21')
    expect(w.text()).toContain('Caché: 88.5%')
  })

  it('las llamadas a la API se ven, pero como dato aparte del tope', () => {
    // Una pregunta al chatbot son varios pedidos a la API: el número sirve para entender el
    // costo, pero no es contra lo que se mide el cupo.
    expect(montar().text()).toContain('143 llamadas a la API')
  })

  it('el desglose por función va en créditos: una puede usarse poco y costar mucho más', () => {
    const w = montar()

    expect(w.text()).toContain('Registro por voz: 150')
    expect(w.text()).toContain('Chatbot del admin: 60')
  })

  it('la barra de consumo refleja los créditos usados, no las llamadas', () => {
    const barra = montar().find('.sam__bar-fill')

    expect(barra.attributes('style')).toContain('width: 42%')   // 210/500, no 143/500
  })

  it('los tramos de IA salen del catálogo del backend, no de una copia local', async () => {
    const w = montar()
    await new Promise(r => setTimeout(r, 0))

    expect(w.text()).toContain('2.000 créditos por mes')        // el tramo Pro, tal como lo manda
    expect(w.findAll('.sam__tier')).toHaveLength(3)
  })

  it('la configuración de un módulo apagado no se muestra: no hay nada que configurar', () => {
    // IoT está apagado en este club, así que su API key no aparece todavía.
    expect(montar().text()).not.toContain('API key de Pulse Grow')
  })

  it('lo que está en construcción se lista, para que nadie lo prometa', () => {
    const w = montar()

    expect(w.text()).toContain('Portal del paciente')
    expect(w.text()).toContain('en construcción')
  })
})

// El panel lo usan dos personas y una de ellas no vive adentro de la app. Una lista plana de diez
// adicionales no dice para qué es cada uno ni qué hay que tener contratado para que sirva.
describe('SAModulos — los adicionales van con su pack', () => {
  it('cada adicional aparece bajo el pack al que le sirve', () => {
    const w = montarModulos()
    const texto = w.text()

    expect(texto).toContain('Adicionales de Cultivo')
    expect(texto).toContain('Adicionales de Producción y dispensa')
    expect(texto).toContain('Sirven a los dos packs')
  })

  it('el Buffet dice que está en construcción, y se puede prender igual para probarlo', async () => {
    const w = montarModulos()
    const fila = filaDe(w, 'Buffet')

    expect(fila.text()).toContain('en construcción')
    expect(fila.find('button[role="switch"]').attributes('disabled')).toBeUndefined()
  })

  it('WhatsApp no se puede prender, y dice por qué', () => {
    const w = montarModulos()
    const fila = filaDe(w, 'WhatsApp')

    expect(fila.text()).toContain('no disponible')
    expect(fila.text()).toContain('Twilio')
    expect(fila.find('button[role="switch"]').attributes('disabled')).toBeDefined()
  })

  it('avisa cuando el pack del adicional no está contratado', () => {
    const w = montarModulos({ features: { produccion_dispensa: true } })

    expect(w.text()).toContain('Cultivo no está contratado')
  })
})
