import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// AC (Germán, 12-oct-2026, lienzos aprobados):
//  · Contabilidad: «una sección con los últimos 20 movimientos para un pantallazo rápido»,
//    pudiendo ver el detalle desde ahí mismo, con Todos / Ingresos / Egresos.
//  · Stock: en vez de las tarjetas, un resumen por producto (nunca se suman gramos con
//    unidades) con «Alcanza para» y «Atención».
//  · Equipo: cupo del plan por rol y, por persona, qué hizo hoy, horas del mes, pendiente y
//    último acceso; el número del encabezado es el de la lista.
const listMovimientos = vi.fn(() => Promise.resolve({ data: { movimientos: [{ id: 99, tipo: 'ingreso', descripcion: 'Cuota', monto_ars: 10, fecha: '2026-10-12' }] } }))
const listMovimientosRecurrentes = vi.fn(() => Promise.resolve({ data: { fijos: [
  { tipo: 'egreso', ya_cargado: false }, { tipo: 'egreso', ya_cargado: true }, { tipo: 'ingreso', ya_cargado: false },
] } }))
const listUsers = vi.fn()
const getEquipoActividad = vi.fn()
const pedirUsuario = vi.fn()

// Un solo módulo (`src/lib/api.js`), importado con y sin extensión: una sola fábrica.
vi.mock('../lib/api.js', () => ({
  default: { get: vi.fn(), post: vi.fn() },
  listMovimientos: (...a) => listMovimientos(...a),
  listMovimientosRecurrentes: (...a) => listMovimientosRecurrentes(...a),
  listUsers: (...a) => listUsers(...a),
  listSalas: vi.fn(() => Promise.resolve({ data: [] })),
  listSedes: vi.fn(() => Promise.resolve({ data: [] })),
  asignarSedeAUsuario: vi.fn(),
  getEquipoActividad: (...a) => getEquipoActividad(...a),
  pedirUsuario: (...a) => pedirUsuario(...a),
}))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }), useRoute: () => ({ query: {} }) }))
vi.mock('../composables/useToast.js', () => ({ useToast: () => ({ success: vi.fn(), error: vi.fn() }) }))
vi.mock('../composables/useConfirm.js', () => ({ useConfirm: () => ({ confirm: vi.fn() }) }))

const movs = (n) => Array.from({ length: n }, (_, i) => ({
  id: i + 1, tipo: i % 2 ? 'egreso' : 'ingreso', descripcion: `Mov ${i + 1}`, monto_ars: 100 + i,
  fecha: '2026-10-12', created_at: '2026-10-12T19:58:00Z', medio_pago: 'efectivo', created_by: 'Lucía', sede: { id: 1, nombre: 'Centro' },
  categoria_madre: 'Dispensas', pagado: true,
}))
const DASH = {
  mes_actual: { ingresos: 2000, egresos: 700, balance: 1300, por_categoria: [
    { categoria: 'Dispensas', tipo: 'ingreso', total: 2000 }, { categoria: 'Alquiler', tipo: 'egreso', total: 700 },
  ] },
  mes_anterior_a_la_fecha: { balance: 1000 },
  posicion: { disponible_ars: 11500, efectivo_en_cajas_ars: 8000, cajas_abiertas: 1, delivery_sin_rendir_ars: 3500,
              por_cobrar_ars: 170, deudores: 2, antiguedad: { hasta_30: 30, de_30_a_60: 40, mas_de_60: 100 } },
  ultimos_12_meses: Array.from({ length: 12 }, (_, i) => ({ mes: `m${i}`, mes_label: 'oct', ingresos: 0, egresos: 0, balance: i - 3 })),
  ultimos_movimientos: movs(20),
  por_sede: [], por_unidad: [],
}

async function resumen (props = {}) {
  const { default: C } = await import('../components/contabilidad/ResumenContable.vue')
  const w = mount(C, { props: { dashboard: DASH, finMesAnterior: new Date(2026, 8, 30), ...props }, global: { stubs: { RouterLink: true } } })
  await flushPromises()
  return w
}

describe('Contabilidad — resumen', () => {
  beforeEach(() => vi.clearAllMocks())

  it('muestra los últimos 20 movimientos y tocar uno abre su detalle', async () => {
    const w = await resumen()
    const filas = w.findAll('.rc__mov')
    expect(filas).toHaveLength(20)
    await filas[3].trigger('click')
    expect(w.emitted('detalle')[0][0]).toMatchObject({ id: 4, descripcion: 'Mov 4' })
  })

  it('«Ingresos» pide al libro 20 ingresos (no filtra los 20 mezclados)', async () => {
    const w = await resumen({ sedeId: 3 })
    await w.findAll('.rc__seg-btn').find(b => b.text() === 'Ingresos').trigger('click')
    await flushPromises()
    expect(listMovimientos).toHaveBeenCalledWith({ per_page: 20, tipo: 'ingreso', sede_id: 3 })
    expect(w.findAll('.rc__mov').map(r => r.text())).toEqual([expect.stringContaining('Cuota')])
  })

  it('egresos con signo menos e ingresos con signo más', async () => {
    const w = await resumen()
    const [ing, egr] = w.findAll('.rc__mov')
    expect(ing.text()).toContain('+ $ 100')
    expect(egr.text()).toContain('− $ 101')
  })

  it('el resultado contra el mes pasado a la misma fecha, y la antigüedad de lo que se debe', async () => {
    const w = await resumen()
    expect(w.text()).toMatch(/\+30 % vs\. \w+ a la misma fecha/)
    const tramos = w.findAll('.rc__tramos li').map(li => li.text())
    expect(tramos).toEqual([expect.stringContaining('$ 30'), expect.stringContaining('$ 40'), expect.stringContaining('$ 100')])
  })

  it('avisa los gastos fijos del mes que faltan registrar (sólo egresos sin cargar)', async () => {
    const w = await resumen()
    expect(w.find('.rc__aviso').text()).toBe('1 gasto fijo del mes sin registrar')
  })
})

describe('Stock — resumen por producto', () => {
  const FILAS = [
    { forma: 'flor_seca', unidad: 'g', stocks: 26, en_deposito: 57.8, en_mostrador: 2822.6, comprometido: 15, disponible: 2865.4, dispensa_diaria: 124, alcanza_dias: 23, atencion: ['2 vencen en 30 días', 'Norte: debajo del umbral (20 g)'] },
    { forma: 'preroll', unidad: 'un', stocks: 1, en_deposito: 100, en_mostrador: 0, comprometido: 0, disponible: 100, dispensa_diaria: 0, alcanza_dias: null, atencion: [] },
  ]
  async function tabla (props = {}) {
    const { default: C } = await import('../components/stock/ResumenPorProducto.vue')
    return mount(C, { props: { filas: FILAS, ...props } })
  }

  it('una fila por producto, cada uno en su unidad', async () => {
    const filas = (await tabla()).findAll('tbody tr')
    expect(filas).toHaveLength(2)
    expect(filas[0].text()).toContain('Flor seca')
    expect(filas[0].text()).toContain('2.865,4 g')
    expect(filas[1].text()).toContain('100 un')
    expect(filas[1].text()).not.toMatch(/100 g/)
  })

  it('«Alcanza para» en días; sin salidas no inventa un número', async () => {
    const filas = (await tabla()).findAll('tbody tr')
    expect(filas[0].text()).toContain('23 días')
    expect(filas[1].text()).toContain('Sin salidas')
  })

  it('«Atención» dice qué mirar, y una raya si no hay nada', async () => {
    const filas = (await tabla()).findAll('tbody tr')
    expect(filas[0].text()).toContain('2 vencen en 30 días · Norte: debajo del umbral (20 g)')
    expect(filas[1].findAll('td').at(-1).text()).toBe('—')
  })

  it('en autocultivo no hay mostrador ni comprometido', async () => {
    const w = await tabla({ personal: true })
    expect(w.text()).not.toContain('En mostrador')
    expect(w.text()).not.toContain('Comprometido')
  })
})

describe('Equipo — actividad y cupo', () => {
  beforeEach(async () => {
    vi.clearAllMocks()
    setActivePinia(createPinia())
    const { useAuthStore } = await import('../stores/auth')
    useAuthStore().user = { id: 1, role: 'admin' }
    listUsers.mockResolvedValue({ data: { data: [
      { id: 1, first_name: 'Ada', last_name: 'Admin', role: 'admin', email: 'a@x' },
      { id: 2, first_name: 'Lucía', last_name: 'Mesa', role: 'dispensador', email: 'l@x' },
      { id: 3, first_name: 'Sofía', last_name: 'Paz', role: 'cultivador', email: 's@x' },
    ] } })
    getEquipoActividad.mockResolvedValue({ data: {
      personas: {
        1: { actividad: [], alertas: [], horas_mes: null, ultimo_acceso: null, sedes: [] },
        2: { actividad: ['23 dispensas', 'caja abierta desde las 16:44'], alertas: [], horas_mes: 86, ultimo_acceso: new Date().toISOString(), sedes: ['Centro'] },
        3: { actividad: [], alertas: ['2 tareas vencidas'], horas_mes: 72.5, ultimo_acceso: null, sedes: [] },
      },
      cupo: { plan: 'Hasta 50 pacientes', tope_por_rol: 2, por_rol: [
        { rol: 'dispensador', label: 'Dispensador', usados: 2, tope: 2 }, { rol: 'cultivador', label: 'Cultivador', usados: 1, tope: 2 },
      ] },
    } })
  })

  async function equipo () {
    const { default: V } = await import('../views/UsuariosView.vue')
    const w = mount(V, { global: { stubs: { RouterLink: true, DsSpinner: true, CredencialesNuevas: true, Teleport: true } } })
    await flushPromises()
    return w
  }
  const fila = (w, nombre) => w.findAll('tbody tr').find(r => r.text().includes(nombre))

  // AC (Germán, 12-oct-2026): el admin no da de alta, PIDE. Lo da de alta la plataforma.
  it('ofrece «Pedir un usuario» y no un alta', async () => {
    const w = await equipo()
    const textos = w.findAll('button').map(b => b.text())
    expect(textos.some(t => t.includes('Pedir un usuario'))).toBe(true)
    expect(textos.some(t => /Incorporar persona|Crear usuario|Nuevo usuario/.test(t))).toBe(false)
  })

  it('el pedido viaja con nombre y rol, y avisa si ese rol ya llenó el cupo', async () => {
    pedirUsuario.mockResolvedValue({ data: { ok: true, codigo: 'CE-000007' } })
    const w = await equipo()
    await w.findAll('button').find(b => b.text().includes('Pedir un usuario')).trigger('click')
    const modal = () => w.find('[data-testid="pedir-usuario"]')
    await modal().find('select').setValue('dispensador')
    expect(modal().find('.uv__pedido-cupo').text()).toContain('2 de 2')
    await modal().findAll('input')[0].setValue('Ana')
    await modal().findAll('button').find(b => b.text() === 'Enviar pedido').trigger('click')
    await flushPromises()
    expect(pedirUsuario).toHaveBeenCalledWith(expect.objectContaining({ nombre: 'Ana', rol: 'dispensador' }))
    expect(w.find('[data-testid="pedir-usuario"]').exists()).toBe(false)
  })

  it('el cupo por rol, con el rol lleno marcado', async () => {
    const w = await equipo()
    const items = w.findAll('.uv__cupo-item')
    expect(w.find('.uv__cupo-title').text()).toBe('Cupo por rol · plan Hasta 50 pacientes')
    expect(items[0].text()).toMatch(/Dispensador\s*2 \/ 2/)
    expect(items[0].classes()).toContain('is-lleno')
    expect(items[1].classes()).not.toContain('is-lleno')
  })

  it('por persona: qué hizo hoy, horas del mes, pendiente, sede y último acceso', async () => {
    const w = await equipo()
    const lucia = fila(w, 'Lucía')
    expect(lucia.text()).toContain('23 dispensas · caja abierta desde las 16:44')
    expect(lucia.text()).toContain('86 h')
    expect(lucia.text()).toContain('Centro')
    expect(lucia.text()).toContain('Ahora')
    const sofia = fila(w, 'Sofía')
    expect(sofia.text()).toContain('2 tareas vencidas')
    expect(sofia.text()).toContain('72,5 h')
    expect(sofia.text()).toContain('Toda la organización')
    expect(sofia.text()).toContain('Nunca')
  })

  it('el encabezado cuenta lo mismo que la lista', async () => {
    const w = await equipo()
    expect(w.find('.uv__sub').text()).toBe('3 personas · 1 en administración y 2 en operación')
    expect(w.findAll('tbody tr')).toHaveLength(3)
  })
})
