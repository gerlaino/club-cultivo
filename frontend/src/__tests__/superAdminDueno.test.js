import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// EL SUPER ADMIN VISTO POR EL DUEÑO DEL NEGOCIO (sep-2026).
//
// Lo que faltaba no era software sino lo que convierte un panel de quien mantiene la app en el
// panel de quien la vende: la plata, el último ingreso real, con quién hablo, y que la persona
// que se olvidó la contraseña la recupere sola. Estos casos fijan lo que cada pantalla DICE con
// los datos que el backend manda — no cómo se calculan (eso está en rspec).

vi.mock('../composables/useToast.js', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), warning: vi.fn(), info: vi.fn() }),
}))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn(() => Promise.resolve(true)) }) }))

const STUBS = {
  Teleport: true, DsSpinner: true, AppDatePicker: true, SAModulos: true,
  RouterLink: { template: '<a><slot/></a>' },
}

// ── «Olvidé mi contraseña» ────────────────────────────────────────────────
const solicitar = vi.fn()
const restablecer = vi.fn()
vi.mock('../lib/api.js', async () => ({
  solicitarRestablecimiento: (...a) => solicitar(...a),
  restablecerContrasena:     (...a) => restablecer(...a),
  getSuperAdminPulso:        () => Promise.resolve({ data: PULSO }),
  listSuperAdminClubs:       () => Promise.resolve({ data: CLUBS }),
  getPuestaEnMarcha:         () => Promise.resolve({ data: PUESTA }),
  getPlan:                   () => Promise.resolve({ data: {} }),
}))

let rutaActual = { path: '/olvide-contrasena', query: {} }
vi.mock('vue-router', () => ({
  useRoute:  () => rutaActual,
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}))

async function montarRecuperar (ruta) {
  rutaActual = ruta
  const { default: Vista } = await import('../views/RecuperarAccesoView.vue')
  return mount(Vista, { global: { stubs: STUBS } })
}

describe('Olvidé mi contraseña', () => {
  beforeEach(() => { solicitar.mockReset(); restablecer.mockReset() })

  it('pide el link por usuario o mail y dice que llegó', async () => {
    solicitar.mockResolvedValue({ data: { enviado: true, mensaje: 'Si la cuenta existe, te mandamos un mail.' } })
    const w = await montarRecuperar({ path: '/olvide-contrasena', query: {} })

    await w.find('input').setValue('juan@gmail.com')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(solicitar).toHaveBeenCalledWith('juan@gmail.com')
    expect(w.text()).toContain('te mandamos un mail')
  })

  // La única distinción que se hace: la cuenta existe pero no hay a dónde escribirle.
  it('sin mail cargado dice a quién pedirle la clave, y deja probar otro usuario', async () => {
    solicitar.mockResolvedValue({ data: { enviado: false, sin_mail: true, mensaje: 'Pedile una contraseña nueva al administrador de tu organización.' } })
    const w = await montarRecuperar({ path: '/olvide-contrasena', query: {} })

    await w.find('input').setValue('admin@club.com')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(w.text()).toContain('administrador de tu organización')
    expect(w.text()).toContain('Probar con otro usuario')
  })

  it('con el token del mail, elige la nueva y manda a ingresar', async () => {
    restablecer.mockResolvedValue({ data: { ok: true, email: 'admin@verde.com' } })
    const w = await montarRecuperar({ path: '/restablecer', query: { token: 'abc' } })

    const inputs = w.findAll('input[type="password"]')
    await inputs[0].setValue('ClaveNueva22')
    await inputs[1].setValue('ClaveNueva22')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(restablecer).toHaveBeenCalledWith('abc', 'ClaveNueva22', 'ClaveNueva22')
    expect(w.text()).toContain('admin@verde.com')
    expect(w.text()).toContain('Ir a ingresar')
  })

  it('si las dos no coinciden no llama al backend', async () => {
    const w = await montarRecuperar({ path: '/restablecer', query: { token: 'abc' } })

    const inputs = w.findAll('input[type="password"]')
    await inputs[0].setValue('ClaveNueva22')
    await inputs[1].setValue('Otra')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(restablecer).not.toHaveBeenCalled()
    expect(w.text()).toContain('no coinciden')
  })

  it('un link vencido ofrece pedir uno nuevo', async () => {
    restablecer.mockRejectedValue({ response: { status: 422, data: { error: 'El link ya no sirve: venció o ya se usó.', token_invalido: true } } })
    const w = await montarRecuperar({ path: '/restablecer', query: { token: 'viejo' } })

    const inputs = w.findAll('input[type="password"]')
    await inputs[0].setValue('ClaveNueva22')
    await inputs[1].setValue('ClaveNueva22')
    await w.find('form').trigger('submit')
    await flushPromises()

    expect(w.text()).toContain('ya no sirve')
    expect(w.text()).toContain('Pedir un link nuevo')
  })

  it('sin token en la URL no muestra el formulario', async () => {
    const w = await montarRecuperar({ path: '/restablecer', query: {} })

    expect(w.findAll('input[type="password"]')).toHaveLength(0)
    expect(w.text()).toContain('le falta el código')
  })
})

// ── El panel: la plata arriba, y cada pendiente con su número ────────────
const PULSO = {
  plata: { moneda: 'ARS', mrr: 1240000, facturables: 9, vencido_ars: 180000, vencidos: 1, vence_este_mes_ars: 320000, vencen_este_mes: 2, en_prueba_ars: 90000 },
  agenda: [{ id: 3, nombre: 'La Huerta', accion: 'Llamar', el: '2026-09-18', vencida: false, contacto: 'Juan', precio_mensual: 0 }],
  suscripciones: {
    vencidos: [{ id: 1, nombre: 'Cannabis del Sur', plan: 'basico', trial: false, plan_activo_hasta: '2026-09-07', precio_mensual: 120000 }],
    vencen_7: [], vencen_30: [], trials: [{ id: 5 }], sin_vencimiento: 2, por_plan: { basico: 3 },
  },
  atencion: {
    modulos_a_medias: [], sin_suites: [],
    suspendidos: [{ id: 2, nombre: 'Verde Norte', motivo: 'no_pago', precio_mensual: 80000 },
                  { id: 4, nombre: 'Prueba Vieja', motivo: 'prueba_terminada', precio_mensual: 40000 }],
  },
  sin_actividad: [],
  salud: {
    iot_mudo: [], sidekiq: { disponible: true, workers: 1, encolados: 0, muertos: 0 },
    backup: { disponible: true, ultimo: '2026-09-15T04:00:00Z', tamano_mb: 12.3, atrasado: false },
    cron: [{ nombre: 'reprocann_vencimiento', atrasado: false }, { nombre: 'stock_bajo', atrasado: true }],
  },
  adopcion: [{ clave: 'delivery', label: 'Delivery', suite: false, tienen: 4, andando: 4, usado: 0 }],
  totales: { clubes_operando: 9 },
}

describe('El panel del dueño', () => {
  async function montar () {
    const { default: Vista } = await import('../views/superadmin/SADashboard.vue')
    const w = mount(Vista, { global: { stubs: STUBS } })
    await flushPromises()
    return w
  }

  it('abre con la plata: MRR, vencido, vence este mes', async () => {
    const w = await montar()
    const t = w.text()

    expect(t).toContain('1.240.000')
    expect(t).toContain('180.000')
    expect(t).toContain('vencido y operando')
    expect(t).toContain('320.000')
  })

  it('cada pendiente lleva su número, y la suspendida dice la acción de su motivo', async () => {
    const w = await montar()
    const t = w.text()

    expect(t).toContain('El plan venció y sigue operando')
    expect(t).toContain('120.000')
    expect(t).toContain('Suspendida por falta de pago')
    expect(t).toContain('Cobrar')
    expect(t).toContain('Terminó la prueba y no siguió')
  })

  it('lo que uno mismo anotó con fecha aparece en la cola', async () => {
    const w = await montar()

    expect(w.text()).toContain('Quedaste en hacer')
    expect(w.text()).toContain('Llamar')
    expect(w.text()).toContain('Juan')
  })

  it('salud dice el último backup y qué cron no corrió', async () => {
    const w = await montar()
    const t = w.text()

    expect(t).toContain('Último backup')
    expect(t).toContain('12.3 MB')
    expect(t).toContain('stock_bajo')
  })

  it('adopción muestra contratado · andando · usado', async () => {
    const w = await montar()

    expect(w.text()).toContain('4 · 4 · 0')
  })
})

// ── La lista: último ingreso y «Para mirar» ──────────────────────────────
const CLUBS = [
  { id: 1, name: 'Activa', slug: 'activa', estado: 'activo', salud: 'ok', precio_mensual: 100000, features: { cultivo: true }, ultimo_ingreso: new Date().toISOString(), plan_activo_hasta: null },
  { id: 2, name: 'Vencida', slug: 'vencida', estado: 'activo', salud: 'vencida', precio_mensual: 50000, features: {}, ultimo_ingreso: null, plan_activo_hasta: '2026-09-01' },
]

describe('La lista de organizaciones', () => {
  async function montar () {
    const { default: Vista } = await import('../views/superadmin/SAClubs.vue')
    const w = mount(Vista, { global: { stubs: STUBS } })
    await flushPromises()
    return w
  }

  it('dice cuándo entró alguien por última vez, o que nunca', async () => {
    const w = await montar()

    expect(w.text()).toContain('hoy')
    expect(w.text()).toContain('nunca')
  })

  it('«Para mirar» deja sólo lo que pide atención', async () => {
    const w = await montar()
    const boton = w.findAll('button').find(b => b.text().startsWith('Para mirar'))
    await boton.trigger('click')

    expect(w.text()).toContain('Vencida')
    expect(w.text()).not.toContain('Activa')
  })
})

// ── Puesta en marcha en el inicio del admin ──────────────────────────────
const PUESTA = { completa: false, hechos: 1, total: 3, pasos: [
  { clave: 'sedes', label: 'Crear la primera sede', hecho: true, detalle: '', ruta: '/sedes' },
  { clave: 'pacientes', label: 'Cargar el padrón de pacientes', hecho: false, detalle: 'Sin pacientes no hay a quién dispensar.', ruta: '/pacientes' },
  { clave: 'equipo', label: 'Que entre alguien más que el admin', hecho: false, detalle: '', ruta: '/usuarios' },
] }

describe('Puesta en marcha', () => {
  it('muestra el progreso y lo que falta, con su detalle', async () => {
    const { default: Comp } = await import('../components/PuestaEnMarcha.vue')
    const w = mount(Comp, { global: { stubs: STUBS } })
    await flushPromises()

    expect(w.text()).toContain('1 de 3')
    expect(w.text()).toContain('Cargar el padrón de pacientes')
    expect(w.text()).toContain('Sin pacientes no hay a quién dispensar')
  })
})

// ── El aviso de vencimiento en la app del admin ──────────────────────────
describe('Aviso de vencimiento del plan', () => {
  async function montar (activoHasta, rol = 'admin') {
    setActivePinia(createPinia())
    const { useAuthStore } = await import('../stores/auth.js')
    useAuthStore().user = { id: 1, role: rol }
    const { usePlan } = await import('../composables/usePlan.js')
    usePlan().planData.value = { activo_hasta: activoHasta }
    const { default: Comp } = await import('../components/AvisoVencimientoPlan.vue')
    return mount(Comp)
  }

  function enDias (n) {
    const d = new Date(); d.setDate(d.getDate() + n)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }

  it('aparece siete días antes, con los días que faltan', async () => {
    const w = await montar(enDias(5))
    expect(w.text()).toContain('en 5 días')
  })

  it('cuando venció lo dice y aclara que la app sigue andando', async () => {
    const w = await montar(enDias(-3))
    expect(w.text()).toContain('venció')
    expect(w.text()).toContain('sigue andando')
  })

  it('lejos del vencimiento, o sin vencimiento, no molesta', async () => {
    expect((await montar(enDias(40))).text()).toBe('')
    expect((await montar(null)).text()).toBe('')
  })

  it('sólo al admin: es quien puede hacer algo', async () => {
    expect((await montar(enDias(2), 'cultivador')).text()).toBe('')
  })
})
