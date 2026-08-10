import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

// El modal pide datos al abrirse; nada de eso hace falta para el caso que interesa.
vi.mock('../lib/api.js', () => ({
  getLoteProximoCodigo: vi.fn(() => Promise.resolve({ data: { codigo: 'L-26-001' } })),
  listGeneticas:        vi.fn(() => Promise.resolve({ data: [] })),
  listPlants:           vi.fn(() => Promise.resolve({ data: [] })),
  createLoteHeredado:   vi.fn(),
  createLoteCosechadoEnSede: vi.fn(),
  listSedes:            vi.fn(() => Promise.resolve({ data: [] })),
}))

const NuevoLoteModal = (await import('../components/lotes/NuevoLoteModal.vue')).default

// Un `watch` que evalúa un computed declarado ANTES que los refs de los que depende explota
// con "Cannot access 'x' before initialization" — y como es un error de RUNTIME, el build pasa
// igual y el síntoma es "hago click en Nuevo lote y no pasa nada". Montar el componente lo
// detecta; compilarlo no.
describe('NuevoLoteModal', () => {
  it('monta sin errores de inicialización', () => {
    setActivePinia(createPinia())
    const errores = []
    const wrapper = mount(NuevoLoteModal, {
      props: { show: false, salas: [] },
      global: {
        stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true },
        config: { errorHandler: (e) => errores.push(e) },
      },
    })

    expect(errores).toEqual([])
    expect(wrapper.exists()).toBe(true)
  })

  it('se abre y renderiza el formulario', async () => {
    setActivePinia(createPinia())
    mount(NuevoLoteModal, {
      props: { show: true, salas: [{ id: 1, nombre: 'Vege 1', kind: 'vegetativo' }] },
      global: { stubs: { AppDatePicker: true, DsSpinner: true }, attachTo: document.body },
    })
    await new Promise((r) => setTimeout(r, 0))

    // El contenido va teleportado a body, no queda dentro del wrapper.
    expect(document.body.innerHTML).toContain('Crear lote')
  })
})

// Reportado: "cuando pones existente y el estado actual, no aparecen todos los inputs; clickeás
// en otro lado, volvés a elegir el estado y ahí sí aparecen". Y: se puede meter un lote en
// floración dentro de una sala de vegetativo.
describe('NuevoLoteModal — lote existente', () => {
  const SALAS = [
    { id: 1, nombre: 'Vege 1',  kind: 'vegetativo', sede: { id: 9 } },
    { id: 2, nombre: 'Flora 1', kind: 'floracion',  sede: { id: 9 } },
  ]

  const abrir = async (salas = SALAS) => {
    setActivePinia(createPinia())
    const w = mount(NuevoLoteModal, {
      props: { show: false, salas },
      global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true } },
      attachTo: document.body,
    })
    await w.setProps({ show: true })
    await new Promise(r => setTimeout(r, 0))
    return w
  }

  it('al elegir "Floración" aparecen los días de vegetativo y floración a la primera', async () => {
    const w = await abrir()
    w.vm.tipoCreacion = 'existente'
    await new Promise(r => setTimeout(r, 0))

    w.vm.heredadoEstado = 'floracion'
    await new Promise(r => setTimeout(r, 0))

    const labels = [...document.body.querySelectorAll('label')].map(l => l.textContent)
    expect(labels.join(' | ')).toMatch(/Días en vegetativo/)
    expect(labels.join(' | ')).toMatch(/Días en floración/)
    w.unmount()
  })

  it('una sala de vegetativo NO se ofrece para un lote en floración', async () => {
    const w = await abrir()
    w.vm.tipoCreacion = 'existente'
    w.vm.heredadoEstado = 'floracion'
    await new Promise(r => setTimeout(r, 0))

    expect(w.vm.salasOfrecidas.map(s => s.nombre)).toEqual(['Flora 1'])
    w.unmount()
  })

  // El filtro de la LISTA no alcanza: si ya había una sala elegida y después se cambia el
  // estado, la sala vieja se queda pegada en el form.
  it('cambiar el estado descarta una sala que ya no corresponde', async () => {
    const w = await abrir()
    w.vm.tipoCreacion = 'existente'
    w.vm.salaId = 1                    // sala de vegetativo
    await new Promise(r => setTimeout(r, 0))

    w.vm.heredadoEstado = 'floracion'  // ahora el lote va a floración
    await new Promise(r => setTimeout(r, 0))

    expect(w.vm.salaId, 'la sala de vege no puede quedar elegida').not.toBe(1)
    w.unmount()
  })
})

// La misma secuencia pero con CLICKS, que es como se usa: el bug reportado aparece al
// interactuar, no al setear el estado a mano.
describe('NuevoLoteModal — interacción real', () => {
  const SALAS = [
    { id: 1, nombre: 'Vege 1',  kind: 'vegetativo', sede: { id: 9 } },
    { id: 2, nombre: 'Flora 1', kind: 'floracion',  sede: { id: 9 } },
  ]

  it('clickear "existente" y elegir Floración muestra los días de cada fase', async () => {
    setActivePinia(createPinia())
    const w = mount(NuevoLoteModal, {
      props: { show: false, salas: SALAS },
      global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true } },
      attachTo: document.body,
    })
    await w.setProps({ show: true })
    await new Promise(r => setTimeout(r, 0))

    const tabExistente = w.findAll('button.nlm__tab').find(b => !b.text().includes('nuevo') || true)
    const tabs = w.findAll('button.nlm__tab')
    await tabs[tabs.length - 1].trigger('click')
    await new Promise(r => setTimeout(r, 0))

    const select = w.findAll('select').find(s =>
      s.findAll('option').some(o => o.text() === 'Floración'))
    expect(select, 'debería estar el selector de estado actual').toBeTruthy()

    await select.setValue('floracion')
    await new Promise(r => setTimeout(r, 0))

    const txt = w.html()
    expect(txt).toMatch(/Días enraizando/)
    expect(txt).toMatch(/Días en vegetativo/)
    expect(txt).toMatch(/Días en floración/)
    w.unmount()
  })
})

// ── La sala se elige dentro de una sede ──────────────────────────────────────────
// Un club con varias sedes ofrecía TODAS las salas juntas, así que había que saber de memoria
// cuál pertenece a dónde — y un lote creado en la sala equivocada después hay que moverlo a
// mano. La sede va primero. Los TIPOS de sala siguen la regla de siempre: un lote nuevo nace
// enraizando (vegetativo/mixta/clon) y uno existente va según el estado que le declares.
describe('Nuevo lote — la sala sale de la sede elegida', () => {
  const SALAS = [
    { id: 1, nombre: 'Veg Norte',  kind: 'vegetativo', sede: { id: 10, nombre: 'Finca Norte' } },
    { id: 2, nombre: 'Flor Norte', kind: 'floracion',  sede: { id: 10, nombre: 'Finca Norte' } },
    { id: 3, nombre: 'Veg Sur',    kind: 'vegetativo', sede: { id: 20, nombre: 'Finca Sur' } },
  ]

  async function abrir(salas = SALAS, sedes = [{ id: 10, nombre: 'Finca Norte' }, { id: 20, nombre: 'Finca Sur' }]) {
    setActivePinia(createPinia())
    const w = mount(NuevoLoteModal, {
      props: { show: false, salas },
      global: { stubs: { Teleport: true, AppDatePicker: true, DsSpinner: true } },
      attachTo: document.body,
    })
    await w.setProps({ show: true })
    await new Promise(r => setTimeout(r, 0))
    // Las sedes las carga el modal por API; en el test se fijan a mano.
    w.vm.sedes = sedes
    await w.vm.$nextTick()
    return w
  }

  it('con varias sedes, no ofrece ninguna sala hasta elegir una', async () => {
    const w = await abrir()

    expect(w.vm.faltaElegirSede).toBe(true)
    expect(w.vm.salasOfrecidas).toHaveLength(0)
  })

  it('elegida la sede, sólo ofrece las salas de esa sede', async () => {
    const w = await abrir()

    w.vm.sedeFiltro = 10
    await w.vm.$nextTick()

    expect(w.vm.salasOfrecidas.map((s) => s.id)).toEqual([1])   // Flor Norte no: el lote nace enraizando
  })

  it('un lote NUEVO nace enraizando: sólo salas donde eso puede estar', async () => {
    const w = await abrir()
    w.vm.sedeFiltro = 10
    await w.vm.$nextTick()

    expect(w.vm.estadoObjetivo).toBe('enraizado')
    expect(w.vm.salasOfrecidas.every((s) => ['vegetativo', 'mixta', 'clon'].includes(s.kind))).toBe(true)
  })

  it('un lote EXISTENTE en floración sí puede ir a una sala de floración', async () => {
    const w = await abrir()
    w.vm.sedeFiltro = 10
    w.vm.tipoCreacion = 'existente'
    w.vm.heredadoEstado = 'floracion'
    await w.vm.$nextTick()

    expect(w.vm.salasOfrecidas.map((s) => s.id)).toEqual([2])
  })

  it('cambiar de sede limpia la sala ya elegida', async () => {
    const w = await abrir()
    w.vm.sedeFiltro = 10
    await w.vm.$nextTick()
    w.vm.salaId = 1

    w.vm.sedeFiltro = 20
    await w.vm.$nextTick()

    expect(w.vm.salaId).toBe('')
    expect(w.vm.salasOfrecidas.map((s) => s.id)).toEqual([3])
  })

  // Con una sola sede el paso sobra: se ofrecen sus salas directamente.
  it('con una sola sede no pide elegirla', async () => {
    const w = await abrir([SALAS[0], SALAS[1]], [{ id: 10, nombre: 'Finca Norte' }])

    expect(w.vm.faltaElegirSede).toBe(false)
    expect(w.vm.salasOfrecidas.map((s) => s.id)).toEqual([1])
  })
})
