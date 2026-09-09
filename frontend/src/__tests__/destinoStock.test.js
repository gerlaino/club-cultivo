import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'

// ¿DÓNDE QUEDA LO QUE COMPRASTE?
//
// Germán, cargando una compra de packaging: «es como que estoy ingresando por duplicado, pregunta
// si entra y en qué inventario, pero ya arriba al elegir la categoría me indicaba el depósito al
// que iba… lo siento confuso».
//
// Tenía razón: eran dos preguntas para una sola decisión, con dos respuestas que podían
// contradecirse —el eco decía «Dispensario» y la grilla ofrecía los diez depósitos del club, sin
// filtrar por la categoría—. Ahora el depósito se DEDUCE: la familia de la categoría por la sede.

vi.mock('../lib/api.js', () => ({ listBarProductos: vi.fn(() => Promise.resolve({ data: [] })) }))

import DestinoStock from '../components/contabilidad/DestinoStock.vue'
import { destinoVacio } from '../components/contabilidad/movimientoFlows.js'

const SEDES = [{ id: 10, nombre: 'Sede Central' }, { id: 20, nombre: 'Finca Norte' }]
const DEPS = [
  { id: 1, nombre: 'General', clave_sistema: 'general', familia: 'insumo_general', sede_id: 10, sede_nombre: 'Sede Central', activo: true },
  { id: 2, nombre: 'General', clave_sistema: 'general', familia: 'insumo_general', sede_id: 20, sede_nombre: 'Finca Norte', activo: true },
  { id: 3, nombre: 'Cultivo', clave_sistema: 'cultivo', familia: 'insumo', sede_id: 20, sede_nombre: 'Finca Norte', activo: true },
]
const INSUMOS = [
  { id: 90, nombre: 'Papel de cocina', unidad_medida: 'unidad', stock_actual: 12, deposito_id: 1 },
]

// Se monta con un PADRE que sostiene el estado, y no con handlers que llaman a `w`: el
// componente sincroniza el depósito al montarse —`watch` con `immediate`— y ahí `w` todavía no
// existe, así que ese primer emit se perdía. Además es cómo lo usa el modal de verdad.
function montar (props = {}) {
  const Padre = {
    components: { DestinoStock },
    data: () => ({
      destino: destinoVacio(),
      sedeId: 'sedeId' in props ? props.sedeId : 10,
      extra: { familia: 'insumo_general', depositos: DEPS, sedes: SEDES, insumos: INSUMOS,
               bares: [], descripcion: 'Bolsas', unidad: 'unidad', monto: 80000,
               cantidad: 1500, multiSede: true, ...props },
    }),
    template: `<DestinoStock v-model="destino" v-bind="extra"
                 :sede-id="sedeId" @update:sede-id="sedeId = $event" />`,
  }
  return mount(Padre)
}

beforeEach(() => vi.clearAllMocks())

describe('El depósito se deduce, no se elige', () => {
  it('lo afirma con su nombre y su sede, sin preguntarlo', async () => {
    const w = montar()
    await w.vm.$nextTick()

    expect(w.text()).toContain('Entra al depósito')
    expect(w.text()).toContain('General')
    // Y el que se guarda es ese, no uno que haya que elegir de una lista.
    expect(w.vm.destino.deposito_id).toBe(1)
  })

  it('cambiar de sede cambia el depósito, y no hay dos preguntas de sede', async () => {
    const w = montar()
    await w.vm.$nextTick()

    const sede = w.find('.dst__sede-inline')
    await sede.setValue('20')
    await w.vm.$nextTick()

    expect(w.vm.sedeId).toBe('20')
    // Una sola pregunta de «dónde»: la sede vive adentro de la afirmación.
    expect(w.findAll('.dst__sede-inline').length).toBe(1)
  })

  // La grilla de diez chips ofrecía depósitos que el backend después rechaza.
  it('no ofrece los de otra familia', async () => {
    const w = montar()
    await w.vm.$nextTick()
    expect(w.text()).not.toContain('Cultivo')
  })

  it('con la sede sin ese depósito, pregunta — pero sólo entre las que lo tienen', async () => {
    const w = montar({ familia: 'insumo', sedeId: 10 })
    await w.vm.$nextTick()

    expect(w.text()).toContain('¿En cuál lo guardás?')
    const opciones = w.find('.dst__sede-inline').findAll('option').map(o => o.text())
    expect(opciones).toContain('Finca Norte')
    expect(opciones).not.toContain('Sede Central')
  })

  // Si sólo una sede tiene ese depósito no hay nada que adivinar. Sin esto, una organización de
  // una sola sede tenía que elegirla para algo que ya estaba decidido.
  it('con una sola sede posible, la adopta sola', async () => {
    const w = montar({ familia: 'insumo', sedeId: null })
    await w.vm.$nextTick()
    expect(w.vm.sedeId).toBe(20)
  })
})

describe('Qué entró', () => {
  it('propone lo que ya escribiste arriba, en vez de pedir el nombre otra vez', async () => {
    const w = montar()
    await w.vm.$nextTick()

    // El de «qué entró», no el de la sede: ese vive adentro de la afirmación.
    expect(w.find('.dst__box select').findAll('option')[0].text()).toContain('Bolsas')
    expect(w.text()).toContain('Se crea como')
    // El campo «Nombre del insumo» sólo aparece si lo pedís.
    expect(w.text()).not.toContain('Nombre del insumo')
  })

  it('y la cantidad se muestra, no se vuelve a pedir', async () => {
    const w = montar()
    await w.vm.$nextTick()

    expect(w.find('.dst__ro').text()).toBe('1500')
    expect(w.findAll('input[type="number"]').length).toBe(0)
  })

  // La pregunta era «¿es algo que ya tenías?» y Germán tuvo que preguntar para qué servía.
  it('dice con todas las letras que la lista es para reposición', async () => {
    const w = montar()
    await w.vm.$nextTick()
    expect(w.text()).toContain('reposición')
  })

  it('si el depósito está vacío lo dice, en vez de una lista de una sola opción', async () => {
    const w = montar({ insumos: [] })
    await w.vm.$nextTick()
    expect(w.text()).toContain('todavía no hay nada cargado')
    expect(w.text()).not.toContain('reposición')
  })
})

describe('Que esta compra no entre', () => {
  it('sigue existiendo, pero como salida y no como una de dos opciones iguales', async () => {
    const w = montar()
    await w.vm.$nextTick()

    const salida = w.findAll('button').find(b => b.text().includes('sólo un gasto'))
    expect(salida).toBeDefined()

    await salida.trigger('click')
    await w.vm.$nextTick()

    expect(w.vm.destino.deposito_id).toBe('')
    expect(w.text()).toContain('No entra al depósito')
    // Y con el camino de vuelta al lado.
    expect(w.findAll('button').some(b => b.text().includes('Sí entra'))).toBe(true)
  })

  it('y ahí la sede sigue haciendo falta: el gasto es de algún lado', async () => {
    const w = montar()
    await w.vm.$nextTick()
    await w.findAll('button').find(b => b.text().includes('sólo un gasto')).trigger('click')
    await w.vm.$nextTick()

    expect(w.text()).toContain('De qué sede es')
  })
})

describe('Una categoría que no guarda nada', () => {
  it('sólo pregunta de qué sede es el gasto', async () => {
    const w = montar({ familia: null })
    await w.vm.$nextTick()

    expect(w.text()).toContain('De qué sede es')
    expect(w.text()).not.toContain('Entra al depósito')
    expect(w.vm.destino.deposito_id).toBe('')
  })

  it('y en una organización de una sola sede no pregunta nada', async () => {
    const w = montar({ familia: null, multiSede: false })
    await w.vm.$nextTick()
    expect(w.text().trim()).toBe('')
  })
})
