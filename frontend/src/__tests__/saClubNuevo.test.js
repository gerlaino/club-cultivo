import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'

const createSuperAdminClub = vi.fn(() => Promise.resolve({ data: {
  club: { id: 9, name: 'Nueva' }, usuarios: [], password_inicial: 'abcd-efgh-2345',
} }))

const CATALOGO = {
  planes: [
    {
      clave: 'basico', label: 'Básico', usuarios_por_rol: 1,
      limites: { sedes: 1, salas: 3, lotes: null, plantas: 450, pacientes: 50, usuarios: null },
      recursos: [
        { clave: 'sedes',     label: 'sedes',     valor: 1,   texto: '1 sedes',      suite: null },
        { clave: 'salas',     label: 'salas',     valor: 3,   texto: '3 salas',      suite: 'cultivo' },
        { clave: 'lotes',     label: 'lotes',     valor: null, texto: 'lotes sin límite', suite: 'cultivo' },
        { clave: 'plantas',   label: 'plantas',   valor: 450, texto: '450 plantas',  suite: 'cultivo' },
        { clave: 'pacientes', label: 'pacientes', valor: 50,  texto: '50 pacientes', suite: 'produccion_dispensa' },
      ],
      resumen: ['1 sedes', '3 salas'],
    },
    {
      clave: 'total', label: 'Total', usuarios_por_rol: null,
      limites: {}, recursos: [], resumen: ['sedes sin límite'],
    },
  ],
  suites: [
    { clave: 'cultivo', label: 'Cultivo', desc: 'Lotes y plantas.' },
    { clave: 'produccion_dispensa', label: 'Producción y dispensa', desc: 'Pacientes y stock.' },
  ],
  addons: [
    { clave: 'iot',      label: 'Ambiente / IoT', desc: 'Sensores.',  pack: 'cultivo' },
    { clave: 'delivery', label: 'Delivery',       desc: 'Reparto.',   pack: 'produccion_dispensa' },
    { clave: 'ia',       label: 'Asistente IA',   desc: 'Por voz.',   pack: null },
  ],
  incluidos: [
    { clave: 'medico', label: 'Módulo médico', desc: 'Turnos.',
      incluido_en: 'produccion_dispensa', incluido_en_label: 'Producción y dispensa' },
  ],
  en_construccion: [],
  features_por_defecto: { cultivo: true, produccion_dispensa: true, delivery: true },
  roles_alta: [
    { clave: 'admin',       label: 'Admin',       desc: 'Todo',    requiere_modulo: null },
    { clave: 'cultivador',  label: 'Cultivador',  desc: 'Plantas', requiere_modulo: 'cultivo' },
    { clave: 'dispensador', label: 'Dispensador', desc: 'Entrega', requiere_modulo: 'produccion_dispensa' },
  ],
}

vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('../lib/api.js', () => ({
  createSuperAdminClub:  (...a) => createSuperAdminClub(...a),
  getSuperAdminCatalogo: vi.fn(() => Promise.resolve({ data: CATALOGO })),
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

    expect(w.vm.PASOS).toEqual(['Identidad', 'Módulos', 'Plan', 'Acceso', 'Resumen'])
  })

  it('cada adicional va debajo de la suite que extiende, no en una lista plana', async () => {
    const w = await montar()
    const grupos = w.vm.addonsAgrupados

    expect(grupos.find(g => g.clave === 'cultivo').items.map(a => a.clave)).toEqual(['iot'])
    expect(grupos.find(g => g.clave === 'produccion_dispensa').items.map(a => a.clave)).toEqual(['delivery'])
    // Los que sirven a las dos van al final, no colgados de una.
    expect(grupos.find(g => g.clave === 'transversal').items.map(a => a.clave)).toEqual(['ia'])
    // El módulo incluido va DENTRO del grupo de su suite, no en una sección aparte.
    expect(grupos.find(g => g.clave === 'produccion_dispensa').incluidos.map(i => i.clave)).toEqual(['medico'])
  })

  // Se podía prender Delivery sin Producción y dispensa: quedaba un módulo contratado que no
  // hacía nada, y el aviso vivía en letra chica que nadie lee.
  it('un adicional sin su suite no se puede prender, y dice por qué', async () => {
    const w = await montar()
    w.vm.toggleSuite(CATALOGO.suites.find(s => s.clave === 'produccion_dispensa'))
    await w.vm.$nextTick()

    const delivery = CATALOGO.addons.find(a => a.clave === 'delivery')
    expect(w.vm.bloqueoDe(delivery)).toContain('Producción y dispensa')

    // Y no se deja prender: el candado no puede ser sólo el texto de abajo.
    w.vm.toggleAddon(delivery)
    expect(w.vm.form.features.delivery).toBe(false)
  })

  it('apagar una suite apaga sus adicionales', async () => {
    const w = await montar()
    w.vm.form.features.produccion_dispensa = true
    w.vm.form.features.delivery = true

    w.vm.toggleSuite(CATALOGO.suites.find(s => s.clave === 'produccion_dispensa'))

    expect(w.vm.form.features.delivery).toBe(false)
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

    expect(w.vm.form.features.delivery).toBe(true)
    expect(w.vm.form.features.iot).toBe(false)
    // Todas las claves viajan, también las apagadas: una ausente se completa con el default
    // del backend y aparecería prendida.
    expect(Object.keys(w.vm.form.features).sort())
      .toEqual(['cultivo', 'delivery', 'ia', 'iot', 'produccion_dispensa'])
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
    await irAlPaso(w, 5)

    const txt = w.text()
    expect(txt).toContain('Club del Sur')
    expect(txt).toContain('Cultivo + Producción y dispensa')
    expect(txt).toContain('Ambiente / IoT')
    expect(txt).toContain('Módulo médico')
    // La contraseña vacía significa "se genera una", no "sin contraseña".
    expect(txt).toContain('se genera una')
  })
})
