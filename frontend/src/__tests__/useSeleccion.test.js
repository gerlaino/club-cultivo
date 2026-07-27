import { describe, it, expect } from 'vitest'
import { ref, computed } from 'vue'
import { useSeleccion } from '../composables/useSeleccion.js'

// Plantas de dos estados, para probar el caso real: filtro por esqueje y quiero "todos" pero solo
// los esquejes.
const PLANTAS = [
  { id: 1, state: 'esqueje' },
  { id: 2, state: 'esqueje' },
  { id: 3, state: 'vegetativo' },
  { id: 4, state: 'esqueje' },
  { id: 5, state: 'vegetativo' },
]

function setup(estadoInicial = '') {
  const todos  = ref(PLANTAS)
  const estado = ref(estadoInicial)
  const filtrados = computed(() =>
    estado.value ? todos.value.filter(p => p.state === estado.value) : todos.value)
  return { sel: useSeleccion(todos, filtrados), estado, filtrados }
}

describe('useSeleccion', () => {
  it('arranca vacía', () => {
    const { sel } = setup()
    expect(sel.cantidad.value).toBe(0)
    expect(sel.todoFiltradoElegido.value).toBe(false)
    expect(sel.seleccionados.value).toEqual([])
  })

  it('seleccionar todo toma SOLO lo filtrado', () => {
    const { sel } = setup('esqueje')
    sel.alternarTodoFiltrado()
    expect(sel.cantidad.value).toBe(3)
    expect(sel.seleccionados.value.map(p => p.id)).toEqual([1, 2, 4])
    expect(sel.seleccionados.value.every(p => p.state === 'esqueje')).toBe(true)
  })

  it('vuelve a tildar el header y deselecciona lo filtrado', () => {
    const { sel } = setup('esqueje')
    sel.alternarTodoFiltrado()
    sel.alternarTodoFiltrado()
    expect(sel.cantidad.value).toBe(0)
  })

  it('marca estado intermedio cuando hay algunos', () => {
    const { sel } = setup('esqueje')
    sel.alternar(1)
    expect(sel.algoFiltradoElegido.value).toBe(true)
    expect(sel.todoFiltradoElegido.value).toBe(false)
    sel.alternar(2); sel.alternar(4)
    expect(sel.todoFiltradoElegido.value).toBe(true)
    expect(sel.algoFiltradoElegido.value).toBe(false)
  })

  it('la selección sobrevive al cambio de filtro y se puede acumular', () => {
    const { sel, estado } = setup('esqueje')
    sel.alternarTodoFiltrado()          // 3 esquejes
    estado.value = 'vegetativo'
    expect(sel.cantidad.value).toBe(3)  // no se perdieron
    expect(sel.todoFiltradoElegido.value).toBe(false)
    sel.alternarTodoFiltrado()          // + 2 vegetativos
    expect(sel.cantidad.value).toBe(5)
    expect(sel.seleccionados.value.map(p => p.id)).toEqual([1, 2, 3, 4, 5])
  })

  it('cuenta lo seleccionado que quedó fuera del filtro (para poder avisarlo)', () => {
    const { sel, estado } = setup()
    sel.alternarTodoFiltrado()      // las 5
    estado.value = 'esqueje'        // ahora se ven 3
    expect(sel.cantidad.value).toBe(5)
    expect(sel.fueraDelFiltro.value).toBe(2)
  })

  it('resuelve los objetos contra la lista completa, no contra la filtrada', () => {
    const { sel, estado } = setup()
    sel.alternar(3)                 // vegetativo
    estado.value = 'esqueje'        // el 3 ya no está visible
    expect(sel.seleccionados.value.map(p => p.id)).toEqual([3])
  })

  it('sin nada filtrado, el header no queda "todo elegido"', () => {
    const todos = ref(PLANTAS)
    const filtrados = computed(() => [])
    const sel = useSeleccion(todos, filtrados)
    expect(sel.todoFiltradoElegido.value).toBe(false)
    sel.alternarTodoFiltrado()
    expect(sel.cantidad.value).toBe(0)
  })

  it('limpiar borra todo', () => {
    const { sel } = setup()
    sel.alternarTodoFiltrado()
    sel.limpiar()
    expect(sel.cantidad.value).toBe(0)
  })
})
