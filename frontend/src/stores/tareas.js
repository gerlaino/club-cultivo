// frontend/src/stores/tareas.js
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import {
  listTareas,
  getTareasDashboard,
  getTarea,
  createTarea,
  updateTarea,
  deleteTarea,
  iniciarTarea,
  completarTarea,
  completarTareasMasivo,
  cancelarTarea,
  getTareasSemana,
  cancelarSerieTarea
} from '../lib/api'

export const useTareasStore = defineStore('tareas', () => {
  // ── State ──────────────────────────────────────────────────────
  const tareas      = ref([])
  const dashboard   = ref({ hoy: [], pendientes: [], vencidas: [], proximas: [], stats: {} })
  const semana      = ref({ desde: null, hasta: null, dias: [] })
  const loading     = ref(false)
  const error       = ref(null)

  // ── Computed ───────────────────────────────────────────────────
  const tareasDeHoy = computed(() => dashboard.value.hoy)
  const stats       = computed(() => dashboard.value.stats)
  const hayVencidas = computed(() => dashboard.value.vencidas.length > 0)

  // Listado accionable de /tareas: vencidas + de hoy + sin fecha (nunca futuras).
  // Mismo scope que stats.pendientes; el backend lo acota a 100.
  const pendientes  = computed(() => dashboard.value.pendientes || [])

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
      dashboard.value  = { hoy: [], pendientes: [], vencidas: [], proximas: [], stats: {}, ...res.data }
    } catch (e) {
      error.value = e.response?.data?.error || 'Error al cargar el dashboard'
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
    // Refrescar dashboard si es de hoy
    if (nueva.fecha_programada === new Date().toISOString().split('T')[0]) {
      dashboard.value.hoy.unshift(nueva)
    }
    return nueva
  }

  async function update(id, data) {
    const res        = await updateTarea(id, data)
    const actualizada = res.data
    _reemplazarEnDashboard(id, actualizada)
    return actualizada
  }

  async function remove(id) {
    await deleteTarea(id)
    _eliminarDeDashboard(id)
  }

  async function iniciar(id) {
    const res        = await iniciarTarea(id)
    const actualizada = res.data
    _reemplazarEnDashboard(id, actualizada)
    return actualizada
  }

  async function completar(id, horas_reales, notas_completado = '', extra = {}) {
    const res  = await completarTarea(id, { horas_reales, notas_completado, ...extra })
    const { tarea: actualizada, tiene_horas_para_lote } = res.data
    const estabaPendiente = pendientes.value.some(t => t.id === id)
    _reemplazarEnDashboard(id, actualizada)
    // Actualizar stats
    if (estabaPendiente && dashboard.value.stats.pendientes > 0) dashboard.value.stats.pendientes--
    if (dashboard.value.stats.en_progreso > 0) dashboard.value.stats.en_progreso--
    dashboard.value.stats.completadas_hoy = (dashboard.value.stats.completadas_hoy || 0) + 1
    return { tarea: actualizada, tiene_horas_para_lote }
  }

  // Cierra varias de un saque (sin horas ni notas) — para el listado de pendientes.
  // El backend ignora las que ya no estén pendiente/en_progreso.
  async function completarMasivo(ids) {
    const res = await completarTareasMasivo(ids)
    ids.forEach(id => _eliminarDeDashboard(id))
    const n = res.data?.completadas || 0
    dashboard.value.stats.pendientes      = Math.max(0, (dashboard.value.stats.pendientes || 0) - n)
    dashboard.value.stats.completadas_hoy = (dashboard.value.stats.completadas_hoy || 0) + n
    return n
  }

  async function cancelar(id) {
    const res        = await cancelarTarea(id)
    const actualizada = res.data
    _eliminarDeDashboard(id)
    return actualizada
  }

  async function fetchSemana(desde) {
    loading.value = true
    error.value = null
    try {
      const res = await getTareasSemana(desde)
      semana.value = res.data
    } catch (e) {
      error.value = 'Error al cargar la semana'
    } finally {
      loading.value = false
    }
  }

  async function cancelarSerie(id) {
    const res = await cancelarSerieTarea(id)
    return res.data
  }

  // ── Helpers internos ───────────────────────────────────────────

  // Una misma tarea puede estar en varias listas (p. ej. de hoy y en pendientes):
  // se actualiza/elimina en TODAS, no solo en la primera que aparece.
  const _LISTAS = ['hoy', 'pendientes', 'vencidas', 'proximas']

  function _reemplazarEnDashboard(id, tarea) {
    for (const key of _LISTAS) {
      const idx = (dashboard.value[key] || []).findIndex(t => t.id === id)
      if (idx !== -1) dashboard.value[key][idx] = tarea
    }
  }

  function _eliminarDeDashboard(id) {
    for (const key of _LISTAS) {
      const idx = (dashboard.value[key] || []).findIndex(t => t.id === id)
      if (idx !== -1) dashboard.value[key].splice(idx, 1)
    }
  }

  return {
    tareas, dashboard, semana, loading, error,
    tareasDeHoy, stats, hayVencidas, pendientes,
    hoyPendientes, hoyEnProgreso, hoyCompletadas,
    fetchDashboard, fetchTareas,
    create, update, remove, iniciar, completar, completarMasivo, cancelar,
    fetchSemana, cancelarSerie
  }
})
