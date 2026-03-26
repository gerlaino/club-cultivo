// frontend/src/stores/tareas.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import {
  listTareas,
  getTareasDashboard,
  getTareasKanban,
  getTarea,
  createTarea,
  updateTarea,
  deleteTarea,
  iniciarTarea,
  completarTarea,
  cancelarTarea
} from '../lib/api'

export const useTareasStore = defineStore('tareas', () => {
  // ── State ──────────────────────────────────────────────────────
  const tareas      = ref([])
  const dashboard   = ref({ hoy: [], vencidas: [], proximas: [], stats: {} })
  const kanban      = ref({ pendiente: [], en_progreso: [], completada: [] })
  const loading     = ref(false)
  const error       = ref(null)

  // ── Computed ───────────────────────────────────────────────────
  const tareasDeHoy = computed(() => dashboard.value.hoy)
  const stats       = computed(() => dashboard.value.stats)
  const hayVencidas = computed(() => dashboard.value.vencidas.length > 0)

  // Tareas de hoy por estado (para mini-kanban del dashboard)
  const hoyPendientes  = computed(() => tareasDeHoy.value.filter(t => t.estado === 'pendiente'))
  const hoyEnProgreso  = computed(() => tareasDeHoy.value.filter(t => t.estado === 'en_progreso'))
  const hoyCompletadas = computed(() => tareasDeHoy.value.filter(t => t.estado === 'completada'))

  // ── Actions ────────────────────────────────────────────────────

  async function fetchDashboard() {
    loading.value = true
    error.value   = null
    try {
      const res        = await getTareasDashboard()
      dashboard.value  = res.data
    } catch (e) {
      error.value = e.response?.data?.error || 'Error al cargar el dashboard'
    } finally {
      loading.value = false
    }
  }

  async function fetchKanban(params = {}) {
    loading.value = true
    error.value   = null
    try {
      const res    = await getTareasKanban(params)
      kanban.value = res.data
    } catch (e) {
      error.value = e.response?.data?.error || 'Error al cargar el kanban'
    } finally {
      loading.value = false
    }
  }

  async function fetchTareas(params = {}) {
    loading.value = true
    error.value   = null
    try {
      const res   = await listTareas(params)
      tareas.value = res.data
    } catch (e) {
      error.value = e.response?.data?.error || 'Error al cargar las tareas'
    } finally {
      loading.value = false
    }
  }

  async function create(data) {
    const res    = await createTarea(data)
    const nueva  = res.data
    // Insertar en la columna correcta del kanban
    kanban.value[nueva.estado]?.unshift(nueva)
    // Refrescar dashboard si es de hoy
    if (nueva.fecha_programada === new Date().toISOString().split('T')[0]) {
      dashboard.value.hoy.unshift(nueva)
    }
    return nueva
  }

  async function update(id, data) {
    const res        = await updateTarea(id, data)
    const actualizada = res.data
    _reemplazarEnKanban(id, actualizada)
    _reemplazarEnDashboard(id, actualizada)
    return actualizada
  }

  async function remove(id) {
    await deleteTarea(id)
    _eliminarDeKanban(id)
    _eliminarDeDashboard(id)
  }

  async function iniciar(id) {
    const res        = await iniciarTarea(id)
    const actualizada = res.data
    _moverEnKanban(id, 'pendiente', actualizada)
    _reemplazarEnDashboard(id, actualizada)
    return actualizada
  }

  async function completar(id, horas_reales, notas_completado = '') {
    const res  = await completarTarea(id, { horas_reales, notas_completado })
    const { tarea: actualizada, tiene_horas_para_lote } = res.data
    _moverEnKanban(id, 'en_progreso', actualizada)
    _reemplazarEnDashboard(id, actualizada)
    // Actualizar stats
    if (dashboard.value.stats.en_progreso > 0) dashboard.value.stats.en_progreso--
    dashboard.value.stats.completadas_hoy = (dashboard.value.stats.completadas_hoy || 0) + 1
    return { tarea: actualizada, tiene_horas_para_lote }
  }

  async function cancelar(id) {
    const res        = await cancelarTarea(id)
    const actualizada = res.data
    _eliminarDeKanban(id)
    _eliminarDeDashboard(id)
    return actualizada
  }

  // ── Helpers internos ───────────────────────────────────────────

  function _reemplazarEnKanban(id, tarea) {
    for (const col of Object.keys(kanban.value)) {
      const idx = kanban.value[col].findIndex(t => t.id === id)
      if (idx !== -1) {
        kanban.value[col][idx] = tarea
        return
      }
    }
  }

  function _moverEnKanban(id, estadoAnterior, tarea) {
    // Quitar del estado anterior
    const col = kanban.value[estadoAnterior]
    if (col) {
      const idx = col.findIndex(t => t.id === id)
      if (idx !== -1) col.splice(idx, 1)
    }
    // Agregar al nuevo estado
    kanban.value[tarea.estado]?.unshift(tarea)
  }

  function _eliminarDeKanban(id) {
    for (const col of Object.keys(kanban.value)) {
      const idx = kanban.value[col].findIndex(t => t.id === id)
      if (idx !== -1) { kanban.value[col].splice(idx, 1); return }
    }
  }

  function _reemplazarEnDashboard(id, tarea) {
    for (const key of ['hoy', 'vencidas', 'proximas']) {
      const idx = dashboard.value[key].findIndex(t => t.id === id)
      if (idx !== -1) { dashboard.value[key][idx] = tarea; return }
    }
  }

  function _eliminarDeDashboard(id) {
    for (const key of ['hoy', 'vencidas', 'proximas']) {
      const idx = dashboard.value[key].findIndex(t => t.id === id)
      if (idx !== -1) { dashboard.value[key].splice(idx, 1); return }
    }
  }

  return {
    tareas, dashboard, kanban, loading, error,
    tareasDeHoy, stats, hayVencidas,
    hoyPendientes, hoyEnProgreso, hoyCompletadas,
    fetchDashboard, fetchKanban, fetchTareas,
    create, update, remove, iniciar, completar, cancelar
  }
})
