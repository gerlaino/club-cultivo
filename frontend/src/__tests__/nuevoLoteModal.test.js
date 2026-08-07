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
