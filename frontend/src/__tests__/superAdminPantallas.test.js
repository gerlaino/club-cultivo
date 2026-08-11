import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

// Un build que pasa no prueba que la pantalla funcione: compilaron perfecto un modal sin
// estilos, botones crudos y clases CSS inexistentes. Estos tests MONTAN las pantallas del super
// admin con la API respondiendo, y fallan si el template revienta al renderizar de verdad.

const pulso = {
  totales: { clubes_operando: 3 },
  suscripciones: {
    vencidos:  [{ id: 1, nombre: 'Vencido', plan: 'basico', trial: false, plan_activo_hasta: '2026-08-01' }],
    vencen_7:  [{ id: 2, nombre: 'Vence pronto', plan: 'total', trial: true, plan_activo_hasta: '2026-08-14' }],
    vencen_30: [],
    trials:    [{ id: 2, nombre: 'Vence pronto', plan: 'total', trial: true }],
    sin_vencimiento: 1,
    por_plan: { basico: 2, total: 1 },
  },
  atencion: {
    modulos_a_medias: [
      { id: 3, nombre: 'Sin Twilio', modulo: 'whatsapp', modulo_label: 'WhatsApp', falta: 'Falta cargar la cuenta de Twilio.' },
    ],
    sin_suites:  [{ id: 4, nombre: 'Sin suites' }],
    suspendidos: [],
  },
  sin_actividad: [{ id: 5, nombre: 'Callado', dias_en_silencio: 40 }],
  salud: {
    iot_mudo: [{ id: 6, nombre: 'Sin señal', ultima_lectura: null }],
    sidekiq:  { disponible: true, encolados: 0, fallidos: 2, muertos: 0, workers: 1 },
  },
  adopcion: [
    { clave: 'cultivo',  label: 'Cultivo',  suite: true,  tienen: 3, andando: 3 },
    { clave: 'whatsapp', label: 'WhatsApp', suite: false, tienen: 1, andando: 0 },
  ],
}

const informe = {
  reseña: 'Qué tamaño tiene la plataforma hoy.',
  clubes:  { total: 4, operando: 3, suspendidos: 1, eliminados: 0, demo: 1 },
  volumen: { usuarios: 12, pacientes: 80, sedes: 4, salas: 9, lotes: 20, plantas: 300 },
  dispensacion_mes:  { desde: '2026-08-01', cantidad: 40, gramos: 512.4 },
  por_plan:          { basico: 2, total: 1 },
  promedio_por_club: { pacientes: 26.7, lotes: 6.7, usuarios: 4 },
}

vi.mock('../lib/api.js', () => ({
  getSuperAdminPulso:   () => Promise.resolve({ data: pulso }),
  getInformePlataforma: () => Promise.resolve({ data: informe }),
}))

const push = vi.fn()
vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
  useRoute:  () => ({ name: 'sa-dashboard' }),
}))

const SADashboard = (await import('../views/superadmin/SADashboard.vue')).default
const SAInformes  = (await import('../views/superadmin/SAInformes.vue')).default

const stubs = { RouterLink: true, DsSpinner: true }

describe('Panel del super admin', () => {
  beforeEach(() => push.mockClear())

  it('monta y muestra cuántos clubes están operando', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    expect(w.text()).toContain('3 organizaciones operando')
  })

  // Lo único accionable va primero y junto: antes había que barrer la pantalla para saber si
  // había algo que hacer.
  it('junta en una sola lista todo lo que hay que resolver', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    const texto = w.text()
    expect(texto).toContain('El plan venció y sigue operando')
    expect(texto).toContain('Sin ninguna suite')
    expect(texto).toContain('Falta cargar la cuenta de Twilio.')
    expect(texto).toContain('nunca reportó una lectura')
  })

  // Cada fila tiene que decir QUÉ HACER, no sólo qué pasa: es la diferencia entre una lista de
  // avisos y una cola de trabajo que se puede bajar sin interpretar nada.
  it('cada pendiente lleva su acción', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    const texto = w.text()
    expect(texto).toContain('Cobrar y renovar')      // plan vencido
    expect(texto).toContain('Asignar suite')         // sin suites
    expect(texto).toContain('Completar configuración') // módulo prendido a medias
    expect(texto).toContain('Revisar sensores')      // IoT mudo
  })

  it('agrupa por urgencia, empezando por lo que cuesta plata', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    const texto = w.text()
    expect(texto).toContain('Se está perdiendo plata')
    expect(texto).toContain('Paga y no le funciona')
    // Lo que cuesta plata va ANTES de lo que sólo hay que avisar.
    expect(texto.indexOf('Se está perdiendo plata')).toBeLessThan(texto.indexOf('Paga y no le funciona'))
  })

  it('no repite el IoT mudo en Salud: ya está en la cola, con su acción', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    // "3 sin señal" era un número que no llevaba a ningún lado y parecía otro problema.
    expect(w.text()).not.toContain('sin señal')
  })

  it('nombra el módulo que está prendido y no funciona', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    expect(w.text()).toContain('WhatsApp')
    expect(w.text()).toContain('Sin Twilio')
  })

  it('entra al club desde cualquier fila pendiente', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    await w.find('.sad__pend').trigger('click')

    expect(push).toHaveBeenCalledWith({ name: 'sa-club-detail', params: { id: 1 } })
  })

  it('muestra los clubes en silencio con cuánto hace que no tocan nada', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    expect(w.text()).toContain('Callado')
    expect(w.text()).toContain('hace 40 días')
  })

  it('informa la salud de la cola de trabajos', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    expect(w.text()).toContain('1 worker')
  })

  // Los agregados se fueron a Informes: en el panel no le sirven a nadie.
  it('NO muestra el total de plantas ni de lotes', async () => {
    const w = mount(SADashboard, { global: { stubs } })
    await flushPromises()

    expect(w.text()).not.toContain('Plantas')
    expect(w.text()).not.toContain('Lotes totales')
  })
})

describe('Informes de plataforma', () => {
  it('monta y muestra el volumen agregado', async () => {
    const w = mount(SAInformes, { global: { stubs } })
    await flushPromises()

    const texto = w.text()
    expect(texto).toContain('300')       // plantas
    expect(texto).toContain('Pacientes')
    expect(texto).toContain('Salas')
  })

  // Sin esto, dos informes que cortan el mismo dato distinto parecen contradecirse.
  it('arranca diciendo qué pregunta contesta', async () => {
    const w = mount(SAInformes, { global: { stubs } })
    await flushPromises()

    expect(w.text()).toContain('Qué tamaño tiene la plataforma hoy.')
  })

  it('deja claro que los clubes demo no cuentan', async () => {
    const w = mount(SAInformes, { global: { stubs } })
    await flushPromises()

    expect(w.text()).toContain('demo (no cuentan)')
  })

  it('muestra el club promedio, que dice más que el total', async () => {
    const w = mount(SAInformes, { global: { stubs } })
    await flushPromises()

    expect(w.text()).toContain('26.7')
  })
})
