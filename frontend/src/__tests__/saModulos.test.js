import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

const updateSuperAdminClub = vi.fn(() => Promise.resolve({ data: { bajas_programadas: [] } }))
const confirmar = vi.fn(() => Promise.resolve(true))

vi.mock('../lib/api.js', () => ({
  updateSuperAdminClub:   (...a) => updateSuperAdminClub(...a),
  provisionarPulse:       vi.fn(() => Promise.resolve({ data: {} })),
  provisionarWhatsappClub: vi.fn(() => Promise.resolve({ data: {} })),
  desconectarWhatsappClub: vi.fn(() => Promise.resolve({ data: {} })),
  recargarIa:              vi.fn(() => Promise.resolve({ data: {} })),
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
  // El tramo de IA sale del PLAN y el backend lo manda ya resuelto: era una perilla aparte
  // (`ia_tier`) que podía quedar en Básico con el plan en Total.
  ia_tramo: { clave: 'basico', label: 'Básico', limite_mes: 500 },
  ia_recargas: [{ id: 1, creditos: 300, nota: 'Campaña', fecha: '2026-08-20T10:00:00Z',
                  usuario: 'super@cultivoespacial.com' }],
  pulse_configurado: false,
  whatsapp_estado: 'sin_configurar',
  features: { cultivo: true, produccion_dispensa: true, chatbot: true, bar: true, iot: false },
  features_baja: { bar: '2026-08-31' },
  suites: [
    { clave: 'cultivo', label: 'Cultivo', desc: 'Salas, lotes y plantas' },
    { clave: 'produccion_dispensa', label: 'Producción y dispensa', desc: 'Pacientes y entregas' },
  ],
  addons: [
    { clave: 'chatbot',  label: 'Chatbot del admin', desc: 'Pregunta', estado: 'andando', pack: null,
      tipo: 'extra', sin_lanzar: true },
    { clave: 'iot',      label: 'Ambiente / IoT', desc: 'Sensores', estado: 'falta_config',
      pack: 'cultivo', pack_label: 'Cultivo', falta: 'Falta cargar la API key de Pulse' },
    { clave: 'bar',      label: 'Buffet y eventos', desc: 'Punto de venta', estado: 'andando',
      pack: 'produccion_dispensa', pack_label: 'Producción y dispensa', incompleto: true, tipo: 'extra' },
    { clave: 'whatsapp', label: 'WhatsApp', desc: 'Avisos por WhatsApp', estado: 'apagado',
      pack: 'produccion_dispensa', pack_label: 'Producción y dispensa', tipo: 'incluido_proximo',
      bloqueado: true, motivo_bloqueo: 'Falta dar de alta la cuenta de Twilio de la plataforma.' },
  ],
  // 6-oct-2026: lo terminado viene incluido (y `incluido_en` es una lista: la IA viene con los dos).
  incluidos: [
    { clave: 'medico',   label: 'Módulo médico', incluido_en: ['produccion_dispensa'], activo: true },
    { clave: 'delivery', label: 'Delivery',      incluido_en: ['produccion_dispensa'], activo: true },
    { clave: 'ia',       label: 'Asistente IA',  incluido_en: ['cultivo', 'produccion_dispensa'], activo: true },
  ],
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
  w.findAll('.sam__addon').find(f => f.find('.sam__name').exists() && f.find('.sam__name').text().startsWith(label))

describe('SAModulos', () => {
  const montar = montarModulos

  beforeEach(() => { updateSuperAdminClub.mockClear(); confirmar.mockClear() })

  it('renderiza los módulos con un interruptor cada uno', () => {
    const w = montar()

    expect(w.text()).toContain('Cultivo')
    expect(w.text()).toContain('Asistente IA')
    // 2 packs + 4 extras/próximos. Los incluidos NO llevan interruptor: no son una decisión.
    expect(w.findAll('.sam__switch')).toHaveLength(6)
  })

  it('lo que viene dentro de una suite se muestra como parte de ella, sin interruptor', () => {
    const txt = montar().text()
    expect(txt).toContain('Incluye: Módulo médico, Delivery, Asistente IA')
    expect(txt).toContain('Incluye: Asistente IA')   // también bajo Cultivo
  })

  it('cuenta los activos, que es lo que se factura', () => {
    // cultivo + produccion_dispensa + chatbot + bar
    expect(montar().text()).toContain('4 activos')
  })

  it('prender un módulo guarda solo, sin botón de Guardar', async () => {
    const w = montar()
    // Por NOMBRE y no por posición: agrupar los adicionales por pack los reordenó, y el test
    // empezó a tocar otro interruptor sin que nada lo dijera.
    await filaDe(w, 'Ambiente / IoT').find('.sam__switch').trigger('click')

    // El tercer argumento son las opciones del guardado (corte inmediato); prender no las usa.
    expect(updateSuperAdminClub).toHaveBeenCalledWith(3, { features: expect.objectContaining({ iot: true }) }, {})
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

  // El tramo dejó de elegirse: viene con el plan. Eran tres botones y la misma organización
  // podía tener plan Total con la IA en Básico — la misma decisión escrita en dos lugares.
  it('el tramo de IA se muestra, no se elige', async () => {
    const w = montar()
    await new Promise(r => setTimeout(r, 0))

    expect(w.text()).toContain('Viene con «Básico»')
    expect(w.text()).toContain('500 créditos por mes')
    expect(w.findAll('.sam__tier')).toHaveLength(0)
  })

  // Lo que sí se decide es venderle créditos por fuera: es una VENTA y hay que poder facturarla,
  // así que cada una queda con su fecha, su motivo y quién la cargó.
  it('las recargas de créditos se listan con quién las cargó', () => {
    const w = montar()

    expect(w.text()).toContain('+300')
    expect(w.text()).toContain('Campaña')
    expect(w.text()).toContain('super@cultivoespacial.com')
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

    expect(texto).toContain('Extras de Cultivo')
    expect(texto).toContain('Extras de Producción y dispensa')
    expect(texto).toContain('Sirven a los dos packs')
  })

  it('el Buffet dice que está en construcción, y se puede prender igual para probarlo', async () => {
    const w = montarModulos()
    const fila = filaDe(w, 'Buffet y eventos')

    expect(fila.text()).toContain('en construcción')
    expect(fila.find('button[role="switch"]').attributes('disabled')).toBeUndefined()
  })

  // Va a venir incluido cuando esté listo (6-oct-2026); hasta entonces no se prende.
  it('WhatsApp no se puede prender, dice por qué y que va a venir incluido', () => {
    const w = montarModulos()
    const fila = filaDe(w, 'WhatsApp')

    expect(fila.text()).toContain('viene incluido cuando esté listo')
    expect(fila.text()).toContain('Twilio')
    expect(fila.find('button[role="switch"]').attributes('disabled')).toBeDefined()
  })

  it('avisa cuando el pack del adicional no está contratado', () => {
    const w = montarModulos({ features: { produccion_dispensa: true } })

    expect(w.text()).toContain('Cultivo no está contratado')
  })
})

// AC: el super admin tiene que poder cortar un módulo AHORA, más allá de la fecha del período.
// La baja programada es lo correcto para una baja comercial y no sirve para lo demás: una
// organización que se va, una prueba, un módulo prendido por error.
describe('SAModulos — cortar un módulo ahora', () => {
  beforeEach(() => { updateSuperAdminClub.mockClear(); confirmar.mockClear() })

  it('apagar ofrece las dos: al fin del período, o cortar ahora', async () => {
    const w = montarModulos()
    await filaDe(w, 'Chatbot del admin').find('.sam__switch').trigger('click')

    expect(confirmar).toHaveBeenCalledWith(expect.objectContaining({ neutralText: 'Cortar ahora' }))
  })

  it('eligiendo "cortar ahora" lo manda como corte inmediato', async () => {
    confirmar.mockResolvedValueOnce('neutral')
    const w = montarModulos()

    await filaDe(w, 'Chatbot del admin').find('.sam__switch').trigger('click')
    await Promise.resolve(); await Promise.resolve()

    expect(updateSuperAdminClub).toHaveBeenCalledWith(
      3, { features: expect.objectContaining({ chatbot: false }) }, { corteInmediato: true }
    )
  })

  it('eligiendo la baja normal NO manda el corte inmediato', async () => {
    const w = montarModulos()

    await filaDe(w, 'Chatbot del admin').find('.sam__switch').trigger('click')
    await Promise.resolve(); await Promise.resolve()

    expect(updateSuperAdminClub).toHaveBeenCalledWith(
      3, { features: expect.objectContaining({ chatbot: false }) }, { corteInmediato: false }
    )
  })
})
