import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'

const createSuperAdminClub = vi.fn(() => Promise.resolve({ data: {
  club: { id: 9, name: 'Nueva' }, usuarios: [], password_inicial: 'abcd-efgh-2345',
} }))

// El catálogo con la forma del 6-oct-2026: escalones con precio por cantidad de packs, lo
// terminado viene incluido (`incluido_en` es una lista), y los extras están en desarrollo.
const CATALOGO = {
  moneda: 'USD',
  pack_pacientes: { pacientes: 10, plantas: 90, precio_mensual: 80 },
  sede_extra:     { precio_mensual: 50 },
  planes: [
    {
      clave: 'basico', label: 'Hasta 50 pacientes', usuarios_por_rol: 2, por_sede: false,
      precios: { 1: 200, 2: 350 },
      limites: { sedes: 1, salas: 3, lotes: null, plantas: 450, pacientes: 50, usuarios: null },
      recursos: [
        { clave: 'sedes',     label: 'sedes',     valor: 1,   texto: '1 sedes',      suite: null },
        { clave: 'salas',     label: 'salas',     valor: 3,   texto: '3 salas',      suite: 'cultivo' },
        { clave: 'lotes',     label: 'lotes',     valor: null, texto: 'lotes sin límite', suite: 'cultivo' },
        { clave: 'plantas',   label: 'plantas en floración', valor: 450, texto: '450 plantas en floración', suite: 'cultivo' },
        { clave: 'pacientes', label: 'pacientes', valor: 50,  texto: '50 pacientes', suite: 'produccion_dispensa' },
      ],
      resumen: ['1 sedes', '3 salas'],
    },
    {
      clave: 'total', label: 'Hasta 100 pacientes', usuarios_por_rol: 2, por_sede: true,
      precios: { 1: 400, 2: 700 },
      limites: {}, recursos: [], resumen: ['3 sedes'],
    },
    {
      clave: 'personal', label: 'Autocultivo', usuarios_por_rol: null, equipo: false, personal: true,
      precios: { 0: 8 }, limites: { sedes: 1, salas: 2, plantas: 9 },
      recursos: [
        { clave: 'sedes',   label: 'sedes',   valor: 1, texto: '1 sede',      suite: null },
        { clave: 'salas',   label: 'salas',   valor: 2, texto: '2 espacios', suite: 'cultivo' },
        { clave: 'plantas', label: 'plantas en floración', valor: 9, texto: '9 plantas en floración', suite: 'cultivo' },
      ],
      resumen: ['1 sede', '2 espacios'],
    },
  ],
  suites: [
    { clave: 'cultivo', label: 'Cultivo', desc: 'Lotes y plantas.' },
    { clave: 'produccion_dispensa', label: 'Producción y dispensa', desc: 'Pacientes y stock.' },
  ],
  addons: [
    { clave: 'iot',      label: 'Ambiente / IoT',    desc: 'Sensores.',   pack: 'cultivo',             tipo: 'extra', sin_lanzar: true },
    { clave: 'bar',      label: 'Buffet y eventos',  desc: 'Salón.',      pack: 'produccion_dispensa', tipo: 'extra', sin_lanzar: true },
    { clave: 'chatbot',  label: 'Chatbot del admin', desc: 'Pregunta.',   pack: null,                  tipo: 'extra', sin_lanzar: true },
    { clave: 'whatsapp', label: 'WhatsApp',          desc: 'Avisos.',     pack: 'produccion_dispensa', tipo: 'incluido_proximo',
      bloqueado: true, motivo_bloqueo: 'Falta Twilio.' },
  ],
  incluidos: [
    { clave: 'medico',   label: 'Módulo médico', desc: 'Turnos.',  incluido_en: ['produccion_dispensa'], incluido_en_label: 'Producción y dispensa' },
    { clave: 'delivery', label: 'Delivery',      desc: 'Reparto.', incluido_en: ['produccion_dispensa'], incluido_en_label: 'Producción y dispensa' },
    { clave: 'ia',       label: 'Asistente IA',  desc: 'Por voz.', incluido_en: ['cultivo', 'produccion_dispensa'], incluido_en_label: 'Cultivo o Producción y dispensa' },
  ],
  en_construccion: [],
  features_por_defecto: { cultivo: true, produccion_dispensa: true },
  features_personal:    { cultivo: true },
  modulos_personal:     ['cultivo', 'iot', 'ia', 'chatbot'],
  roles_alta: [
    { clave: 'admin',       label: 'Admin',       desc: 'Todo',    requiere_modulo: null },
    { clave: 'cultivador',  label: 'Cultivador',  desc: 'Plantas', requiere_modulo: 'cultivo' },
    { clave: 'dispensador', label: 'Dispensador', desc: 'Entrega', requiere_modulo: 'produccion_dispensa' },
  ],
}

// La cuenta la hace el backend (`Precios.cotizar`). El mock devuelve un número reconocible para
// verificar que la pantalla muestra ESE y no uno propio.
const getSuperAdminCotizacion = vi.fn(() => Promise.resolve({ data: {
  total: 4321, moneda: 'USD', lineas: [{ tipo: 'plan', clave: 'basico', label: 'Hasta 50 pacientes · Cultivo', monto: 4321 }],
} }))

vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('../lib/api.js', () => ({
  createSuperAdminClub:  (...a) => createSuperAdminClub(...a),
  getSuperAdminCatalogo: vi.fn(() => Promise.resolve({ data: CATALOGO })),
  getSuperAdminCotizacion: (...a) => getSuperAdminCotizacion(...a),
}))

const SAClubNuevo = (await import('../views/superadmin/SAClubNuevo.vue')).default

const montar = async () => {
  const w = mount(SAClubNuevo, {
    global: { stubs: { DsSpinner: true, RouterLink: true, AppDatePicker: true } },
  })
  await new Promise(r => setTimeout(r, 0))
  await w.vm.$nextTick()
  return w
}

// La cotización se pide con un pequeño retardo (no una por tecla).
const esperarCotizacion = async (w) => { await new Promise(r => setTimeout(r, 260)); await w.vm.$nextTick() }

/** Avanza el wizard poniendo el paso a mano: la navegación se prueba aparte. */
const irAlPaso = async (w, n) => { w.vm.paso = n; await w.vm.$nextTick() }

// El alta de una organización la usa alguien que no escribió la app. Un build que pasa no
// prueba que la pantalla sirva: este test la MONTA y verifica el orden y lo que ofrece.
describe('SAClubNuevo — alta de organización', () => {

  // El plan es una CONSECUENCIA: recién sabiendo qué compró se puede mostrar contra qué topes
  // mide y qué roles tiene sentido darle. Con el orden viejo, el paso del plan le nombraba
  // salas y plantas a una organización que sólo compró dispensa.
  it('los módulos se eligen ANTES que el plan', async () => {
    const w = await montar()

    expect(w.vm.pasos.map(p => p.label)).toEqual(['Identidad', 'Módulos', 'Plan', 'Acceso', 'Resumen'])
  })

  it('cada extra va debajo del pack que extiende, no en una lista plana', async () => {
    const w = await montar()
    const grupos = w.vm.addonsAgrupados

    expect(grupos.find(g => g.clave === 'cultivo').items.map(a => a.clave)).toEqual(['iot'])
    expect(grupos.find(g => g.clave === 'produccion_dispensa').items.map(a => a.clave)).toEqual(['bar'])
    // Los que sirven a los dos van al final, no colgados de uno.
    expect(grupos.find(g => g.clave === 'transversal').items.map(a => a.clave)).toEqual(['chatbot'])
    // Lo que va a venir incluido (WhatsApp) no es un extra: no tiene interruptor.
    expect(grupos.flatMap(g => g.items).map(a => a.clave)).not.toContain('whatsapp')
  })

  // 6-oct-2026: lo terminado viene adentro de los packs. Se dice, no se tilda.
  it('lo terminado viene incluido, sin interruptor, y lo que viene después se anuncia', async () => {
    const w = await montar()
    await irAlPaso(w, 2)
    const txt = w.text()

    expect(txt).toContain('Viene incluido')
    expect(txt).toContain('Delivery')
    expect(txt).toContain('Asistente IA')
    expect(txt).toContain('Próximamente, incluido')
    expect(txt).toContain('en desarrollo · sin cargo')
    expect(w.vm.incluidoActivo(CATALOGO.incluidos.find(i => i.clave === 'ia'))).toBe(true)
  })

  it('la IA viene con cualquiera de los dos packs', async () => {
    const w = await montar()
    w.vm.form.features = { cultivo: false, produccion_dispensa: true }
    const ia = CATALOGO.incluidos.find(i => i.clave === 'ia')
    expect(w.vm.incluidoActivo(ia)).toBe(true)

    w.vm.form.features = { cultivo: false, produccion_dispensa: false }
    expect(w.vm.incluidoActivo(ia)).toBe(false)
  })

  // Se podía prender Delivery sin Producción y dispensa: quedaba un módulo contratado que no
  // hacía nada, y el aviso vivía en letra chica que nadie lee.
  it('un adicional sin su suite no se puede prender, y dice por qué', async () => {
    const w = await montar()
    w.vm.toggleSuite(CATALOGO.suites.find(s => s.clave === 'produccion_dispensa'))
    await w.vm.$nextTick()

    const bar = CATALOGO.addons.find(a => a.clave === 'bar')
    expect(w.vm.bloqueoDe(bar)).toContain('Producción y dispensa')

    // Y no se deja prender: el candado no puede ser sólo el texto de abajo.
    w.vm.toggleAddon(bar)
    expect(w.vm.form.features.bar).toBe(false)
  })

  it('apagar una suite apaga sus adicionales', async () => {
    const w = await montar()
    w.vm.form.features.produccion_dispensa = true
    w.vm.form.features.bar = true

    w.vm.toggleSuite(CATALOGO.suites.find(s => s.clave === 'produccion_dispensa'))

    expect(w.vm.form.features.bar).toBe(false)
  })

  it('sin ninguna suite no se puede avanzar: la organización entraría sin poder operar', async () => {
    const w = await montar()
    w.vm.form.features = {}
    await irAlPaso(w, 2)

    w.vm.siguiente()
    expect(w.vm.paso).toBe(2)
  })

  // La mitad de la tarjeta era ruido: no hay forma de saber desde ahí qué topes cuentan.
  it('el plan muestra sólo los topes que le importan a lo contratado', async () => {
    const w = await montar()
    w.vm.form.features = { produccion_dispensa: true, cultivo: false }
    await w.vm.$nextTick()

    const topes = w.vm.topesDe(CATALOGO.planes[0]).map(r => r.clave)
    expect(topes).toContain('pacientes')
    expect(topes).toContain('sedes')       // le importa a cualquiera
    expect(topes).not.toContain('plantas') // no compró Cultivo
  })

  // Un cultivador en una organización sin Cultivo loguea a una app sin una sola pantalla.
  it('sólo ofrece los roles que le sirven a lo contratado', async () => {
    const w = await montar()
    w.vm.form.features = { produccion_dispensa: true, cultivo: false }
    await w.vm.$nextTick()

    const roles = w.vm.rolesDisponibles.map(r => r.clave)
    expect(roles).toContain('admin')        // transversal
    expect(roles).toContain('dispensador')
    expect(roles).not.toContain('cultivador')
  })

  // Se creaba a ciegas: nunca se veía junto qué contrató, contra qué topes y con qué usuarios.
  // El wizard tenía su propia lista de qué viene prendido y el backend mergeaba la suya encima:
  // mostraba Delivery apagado y la organización nacía con Delivery. La pantalla decía una cosa
  // y pasaba otra, que es el peor error posible porque parece culpa del usuario.
  it('lo que viene prendido de fábrica lo dice el backend, no la pantalla', async () => {
    const w = await montar()

    expect(w.vm.form.features.cultivo).toBe(true)
    expect(w.vm.form.features.produccion_dispensa).toBe(true)
    expect(w.vm.form.features.bar).toBe(false)
    // Todas las claves viajan, también las apagadas: una ausente se completa con el default
    // del backend y aparecería prendida.
    expect(Object.keys(w.vm.form.features).sort())
      .toEqual(['bar', 'chatbot', 'cultivo', 'iot', 'produccion_dispensa', 'whatsapp'])
  })

  // El precio del escalón depende de cuántos packs lleva: 200 uno, 350 los dos.
  it('el escalón muestra su precio según cuántos packs lleva', async () => {
    const w = await montar()
    const basico = CATALOGO.planes[0]

    expect(w.vm.precioEscalon(basico)).toBe(350)
    w.vm.form.features.cultivo = false
    expect(w.vm.precioEscalon(basico)).toBe(200)
  })

  it('los packs de pacientes suben pacientes y plantas en floración, y viajan a la cotización', async () => {
    const w = await montar()
    w.vm.sumar('packs_pacientes_extra', 1)
    w.vm.sumar('sedes_extra', 2)
    await esperarCotizacion(w)

    const topes = Object.fromEntries(w.vm.topesEfectivos(CATALOGO.planes[0]).map(r => [r.clave, r.texto]))
    expect(topes.pacientes).toBe('60 pacientes')
    expect(topes.plantas).toBe('540 plantas en floración')
    expect(topes.sedes).toBe('3 sedes')

    const pedido = getSuperAdminCotizacion.mock.calls.at(-1)[0]
    expect(pedido).toMatchObject({ plan: 'basico', packs_pacientes: 1, sedes_extra: 2 })
    expect(pedido.suites).toEqual(['cultivo', 'produccion_dispensa'])
    // Lo que se muestra es la cuenta del backend.
    expect(w.vm.precioMensual).toBe(4321)
  })

  it('no deja bajar de cero', async () => {
    const w = await montar()
    w.vm.sumar('packs_pacientes_extra', -1)
    expect(w.vm.form.packs_pacientes_extra).toBe(0)
  })

  it('dice el cupo de usuarios con palabras: por sede en «Hasta 100 pacientes»', async () => {
    const w = await montar()
    expect(w.vm.textoUsuarios(CATALOGO.planes[0])).toBe('2 usuarios de cada rol')
    expect(w.vm.textoUsuarios(CATALOGO.planes[1])).toBe('2 usuarios de cada rol en cada sede')
  })

  // Se tilda Cultivador, se vuelve atrás y se saca Cultivo: el rol queda tildado en una tarjeta
  // que ya no se muestra. El backend lo descarta igual, así que el resumen prometería un usuario
  // que nunca se crea.
  it('no promete usuarios de un rol que quedó sin su módulo', async () => {
    const w = await montar()
    w.vm.rolesSeleccionados.push('cultivador')
    w.vm.form.features.cultivo = false
    await w.vm.$nextTick()

    expect(w.vm.rolesACrear).not.toContain('cultivador')
  })

  it('el último paso resume lo que se va a crear', async () => {
    const w = await montar()
    w.vm.form.name = 'Club del Sur'
    w.vm.form.features = { cultivo: true, produccion_dispensa: true, iot: true }
    await esperarCotizacion(w)
    await irAlPaso(w, 5)

    const txt = w.text()
    expect(txt).toContain('Club del Sur')
    expect(txt).toContain('Cultivo + Producción y dispensa')
    expect(txt).toContain('Ambiente / IoT')
    expect(txt).toContain('Módulo médico')
    expect(txt).toContain('Delivery')
    expect(txt).toContain('US$ 4.321')
    // La contraseña vacía significa "se genera una", no "sin contraseña".
    expect(txt).toContain('se genera una')
  })
})

// Uso personal (19-sep-2026): una persona y su cultivo. No hay organización que nombrar, y el
// ambiente, la IA y el chatbot se eligen uno por uno — antes nacían los tres prendidos y no
// había nada que decidir.
describe('SAClubNuevo — alta de uso personal', () => {
  const montarPersonal = async () => {
    const w = await montar()
    w.vm.elegirTipo('personal')
    await w.vm.$nextTick()
    return w
  }
  const completarPersona = (w) => {
    w.vm.adminPersona = { first_name: 'Juan', last_name: 'Pérez', email_personal: 'juan@gmail.com' }
  }

  it('tiene sus propios pasos: la persona primero y sin paso de plan', async () => {
    const w = await montarPersonal()

    expect(w.vm.pasos.map(p => p.label)).toEqual(['Quién cultiva', 'Qué tiene', 'Vigencia y acceso', 'Resumen'])
  })

  it('no pide nombre de organización: pide a la persona, y el cultivo se llama como ella', async () => {
    const w = await montarPersonal()
    const txt = w.text()

    expect(txt).not.toContain('Nombre de la organización')
    expect(txt).not.toContain('Razón social')
    expect(w.find('input[placeholder="Juan"]').exists()).toBe(true)
    expect(w.find('input[placeholder="Pérez"]').exists()).toBe(true)
    expect(w.find('input[placeholder="juan@gmail.com"]').exists()).toBe(true)

    completarPersona(w)
    await w.vm.$nextTick()
    expect(w.text()).toContain('Cultivo de Juan')
  })

  it('sin nombre, apellido y mail no avanza: es con lo que entra', async () => {
    const w = await montarPersonal()
    w.vm.siguiente()
    expect(w.vm.paso).toBe(1)

    w.vm.adminPersona = { first_name: 'Juan', last_name: 'Pérez', email_personal: 'no-es-un-mail' }
    w.vm.siguiente()
    expect(w.vm.paso).toBe(1)

    completarPersona(w)
    w.vm.siguiente()
    expect(w.vm.paso).toBe(2)
  })

  // 6-oct-2026: nace con el Asistente IA (registro por voz); se le suman ambiente y chatbot.
  it('viene con Cultivo y el Asistente IA, y ofrece ambiente y chatbot apagados', async () => {
    const w = await montarPersonal()

    expect(w.vm.incluidosPersonal.map(a => a.clave)).toEqual(['cultivo', 'ia'])
    expect(w.vm.addonsPersonal.map(a => a.clave)).toEqual(['iot', 'chatbot'])
    expect(w.vm.form.features.iot).toBe(false)
    expect(w.vm.form.features.chatbot).toBe(false)
    // Lo que una organización compra aparte no se ofrece.
    expect(w.vm.addonsPersonal.map(a => a.clave)).not.toContain('bar')
  })

  it('el chatbot se puede sumar solo: la IA ya viene', async () => {
    const w = await montarPersonal()
    w.vm.togglePersonal(CATALOGO.addons.find(a => a.clave === 'chatbot'))
    expect(w.vm.form.features.chatbot).toBe(true)
  })

  it('el precio lo cotiza el backend como autocultivo, sin extras de organización', async () => {
    const w = await montarPersonal()
    w.vm.form.features.iot = true
    await esperarCotizacion(w)

    const pedido = getSuperAdminCotizacion.mock.calls.at(-1)[0]
    expect(pedido).toMatchObject({ plan: 'personal', packs_pacientes: 0, sedes_extra: 0, suites: ['cultivo'] })
    expect(pedido.extras).toEqual(['iot'])
  })

  it('manda al backend el plan personal, el nombre del cultivo y el mail de la persona', async () => {
    const w = await montarPersonal()
    completarPersona(w)
    w.vm.form.features.iot = true
    await irAlPaso(w, 4)

    await w.vm.handleSubmit()

    const enviado = createSuperAdminClub.mock.calls.at(-1)[0]
    expect(enviado.club.plan).toBe('personal')
    expect(enviado.club.name).toBe('Cultivo de Juan')
    expect(enviado.club.email).toBe('juan@gmail.com')
    expect(enviado.club.features).toMatchObject({ cultivo: true, iot: true, chatbot: false })
    expect(enviado.club).toMatchObject({ packs_pacientes_extra: 0, sedes_extra: 0 })
    expect(enviado.admin).toEqual({ first_name: 'Juan', last_name: 'Pérez', email_personal: 'juan@gmail.com' })
    expect(enviado.roles_a_crear).toEqual(['admin'])
  })

  it('el resumen habla de la persona y de lo que le sumó', async () => {
    const w = await montarPersonal()
    completarPersona(w)
    w.vm.form.features.iot = true
    await irAlPaso(w, 4)

    const txt = w.text()
    expect(txt).toContain('Juan Pérez')
    expect(txt).toContain('juan@gmail.com')
    expect(txt).toContain('Cultivo de Juan')
    expect(txt).toContain('Ambiente / IoT')
    expect(txt).toContain('Crear autocultivo')
    expect(txt).toContain('Asistente IA')
    expect(txt).not.toContain('Delivery')
  })
})
