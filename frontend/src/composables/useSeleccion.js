import { ref, computed, unref } from 'vue'

/**
 * Selección de filas por id sobre una lista FILTRADA, para acciones en tanda.
 *
 * Reglas (las mismas en Plantas y en Lotes):
 * - "Seleccionar todo" toma **todo lo filtrado**, no la página visible: si filtrás esqueje y tildás
 *   el header, entran los 47 esquejes aunque la tabla muestre 10.
 * - La selección **sobrevive** al cambio de filtro y de página. Así se puede armar una tanda mixta
 *   (20 esquejes + 5 vegetativos) en dos pasadas. Por eso los objetos se resuelven contra la lista
 *   completa, no contra la filtrada.
 *
 * @param {Ref<Array>} todos      lista completa (para resolver ids → objetos)
 * @param {Ref<Array>} filtrados  lista visible según los filtros activos
 */
export function useSeleccion(todos, filtrados, idKey = 'id') {
  const ids = ref(new Set())

  const idsFiltrados = computed(() => unref(filtrados).map(x => x[idKey]))
  const cantidad     = computed(() => ids.value.size)

  const seleccionados = computed(() => unref(todos).filter(x => ids.value.has(x[idKey])))

  const todoFiltradoElegido = computed(() =>
    idsFiltrados.value.length > 0 && idsFiltrados.value.every(id => ids.value.has(id)))

  const algoFiltradoElegido = computed(() =>
    !todoFiltradoElegido.value && idsFiltrados.value.some(id => ids.value.has(id)))

  // Cuántos de los seleccionados NO se ven con el filtro actual (para poder decirlo en la barra:
  // si no, "25 seleccionadas" con 12 filas a la vista parece un bug).
  const fueraDelFiltro = computed(() =>
    [...ids.value].filter(id => !idsFiltrados.value.includes(id)).length)

  function esta(id)   { return ids.value.has(id) }
  function alternar(id) {
    ids.value.has(id) ? ids.value.delete(id) : ids.value.add(id)
  }
  function alternarTodoFiltrado() {
    if (todoFiltradoElegido.value) idsFiltrados.value.forEach(id => ids.value.delete(id))
    else                           idsFiltrados.value.forEach(id => ids.value.add(id))
  }
  function limpiar() { ids.value.clear() }

  return {
    ids, cantidad, seleccionados, todoFiltradoElegido, algoFiltradoElegido, fueraDelFiltro,
    esta, alternar, alternarTodoFiltrado, limpiar,
  }
}
