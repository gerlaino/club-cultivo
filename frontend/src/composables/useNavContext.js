/**
 * useNavContext — singleton compartido entre AdminTopBar y AdminSidebar.
 * El `collapsed` ref es module-level: ambos componentes comparten la misma instancia.
 */
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { listLotes, getTareasDashboard } from '../lib/api.js'

// ── Singleton state ───────────────────────────────────────────────────────────
const collapsed = ref(
  typeof localStorage !== 'undefined'
    ? localStorage.getItem('sidebar_collapsed') === 'true'
    : false
)
const aprobPendientes  = ref(0)
const tareasPendientes = ref(0)

// ── Mapeo ruta → tab ──────────────────────────────────────────────────────────
const TAB_ROUTES = {
  cultivo:     ['/salas', '/lotes', '/plantas', '/geneticas'],
  pacientes:   ['/pacientes', '/historial', '/informe-semestral', '/socios'],
  operaciones: [
    '/admin/stock', '/admin/cosechado', '/admin/curado', '/admin/pesajes-manicura',
    '/delivery/despachos', '/contabilidad',
  ],
  tareas: ['/tareas', '/plan-trabajo'],
}

export const TAB_FIRST = {
  cultivo:     '/salas',
  pacientes:   '/pacientes',
  operaciones: '/admin/stock',
  tareas:      '/tareas',
}

export function detectTab(path) {
  for (const [key, paths] of Object.entries(TAB_ROUTES)) {
    if (paths.some(p => path === p || path.startsWith(p + '/'))) return key
  }
  return null
}

// ── Composable ────────────────────────────────────────────────────────────────
export function useNavContext() {
  function toggleCollapse() {
    collapsed.value = !collapsed.value
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('sidebar_collapsed', String(collapsed.value))
    }
  }

  async function refreshBadges() {
    try {
      const [lotesRes, dashRes] = await Promise.allSettled([
        listLotes({ estado: 'manicura_pendiente' }),
        getTareasDashboard(),
      ])
      if (lotesRes.status === 'fulfilled') {
        aprobPendientes.value = (lotesRes.value.data || []).length
      }
      if (dashRes.status === 'fulfilled') {
        // Pendientes reales del día (vencidas + hoy), no futuras.
        tareasPendientes.value = dashRes.value.data?.stats?.pendientes || 0
      }
    } catch {}
  }

  // Atajo Ctrl/Cmd+B
  function setupKeyboard() {
    function onKey(e) {
      if ((e.ctrlKey || e.metaKey) && e.key === 'b') {
        e.preventDefault()
        toggleCollapse()
      }
    }
    onMounted(() => document.addEventListener('keydown', onKey))
    onBeforeUnmount(() => document.removeEventListener('keydown', onKey))
  }

  return {
    collapsed,
    toggleCollapse,
    setupKeyboard,
    aprobPendientes,
    tareasPendientes,
    refreshBadges,
  }
}
