/**
 * useNavContext — navegación de dos niveles del admin.
 * Fuente única: NAV_GROUPS define los grupos primarios (sidebar) y sus sub-pestañas
 * (topbar). El sidebar lleva a `to` de cada grupo; el topbar muestra los `tabs` del
 * grupo activo. Badges (manicura/tareas) compartidos como singleton.
 */
import { ref } from 'vue'
import { listLotes, listPesajesManicuraAdmin, getTareasDashboard } from '../lib/api.js'

// ── Grupos primarios + sub-pestañas ────────────────────────────────────────────
export const NAV_GROUPS = [
  { key: 'dashboard', label: 'Dashboard', to: '/', tabs: [] },
  {
    key: 'cultivo', label: 'Cultivo', to: '/salas',
    tabs: [
      { to: '/salas', label: 'Salas' },
      { to: '/lotes', label: 'Lotes' },
      { to: '/plantas', label: 'Plantas' },
      { to: '/geneticas', label: 'Genéticas' },
    ],
  },
  {
    key: 'pacientes', label: 'Pacientes', to: '/pacientes',
    tabs: [
      { to: '/pacientes', label: 'Pacientes' },
      { to: '/historial', label: 'Dispensaciones' },
      { to: '/informe-semestral', label: 'REPROCANN' },
    ],
  },
  {
    key: 'produccion', label: 'Producción', to: '/admin/stock',
    tabs: [
      { to: '/admin/stock', label: 'Stock' },
      { to: '/admin/cosechado', label: 'Cosecha' },
      { to: '/admin/pesajes-manicura', label: 'Manicura', badge: 'aprob' },
      { to: '/insumos', label: 'Insumos' },
    ],
  },
  {
    key: 'comercial', label: 'Comercial', to: '/contabilidad',
    tabs: [
      { to: '/reservas', label: 'Reservas' },
      { to: '/delivery/despachos', label: 'Despachos' },
      { to: '/contabilidad', label: 'Contabilidad' },
    ],
  },
  {
    // Salón (bar) — grupo propio, visible solo si el club tiene el feature activado.
    key: 'salon', label: 'Salón', to: '/bar', feature: 'bar',
    tabs: [],
  },
  {
    key: 'tareas', label: 'Tareas', to: '/tareas',
    tabs: [
      { to: '/tareas', label: 'Tareas', badge: 'tareas' },
      { to: '/plan-trabajo', label: 'Plan de trabajo' },
    ],
  },
  {
    key: 'reportes', label: 'Reportes', to: '/analitica',
    tabs: [
      { to: '/analitica', label: 'Analítica' },
      { to: '/auditor', label: 'Auditoría' },
      { to: '/auditor/trazabilidad', label: 'Trazabilidad' },
      { to: '/ariccame', label: 'ARICCAME' },
      { to: '/documentos', label: 'Documentos' },
    ],
  },
  {
    key: 'config', label: 'Configuración', to: '/configuracion',
    tabs: [
      { to: '/configuracion', label: 'General' },
      { to: '/configuracion/suscripcion', label: 'Suscripción' },
      { to: '/usuarios', label: 'Equipo' },
      { to: '/sedes', label: 'Sedes' },
      { to: '/alertas-configuracion', label: 'Configuración de alertas' },
      { to: '/web', label: 'Sitio web' },
      { to: '/integraciones', label: 'Integraciones' },
      { to: '/configuracion/papelera', label: 'Papelera' },
    ],
  },
]

// Grupo activo según la ruta: el tab cuyo `to` es el prefijo más largo del path gana
// (así /auditor/trazabilidad cae en Reportes y resalta Trazabilidad, no Auditoría).
export function detectGroup(path) {
  if (path === '/') return NAV_GROUPS[0]
  let best = null, bestLen = -1
  for (const g of NAV_GROUPS) {
    // Candidatos: el `to` del grupo (para grupos sin tabs, ej. Salón) + los `to` de sus tabs.
    const tos = [g.to, ...g.tabs.map(t => t.to)]
    for (const to of tos) {
      if (to && to !== '/' && (path === to || path.startsWith(to + '/')) && to.length > bestLen) {
        best = g; bestLen = to.length
      }
    }
  }
  return best || NAV_GROUPS[0]
}

// ── Singleton de estado (badges + colapso) ─────────────────────────────────────
const collapsed = ref(
  typeof localStorage !== 'undefined' && localStorage.getItem('sb-collapsed') === '1'
)
const aprobPendientes  = ref(0)
const tareasPendientes = ref(0)

export function useNavContext() {
  function toggleCollapse() {
    collapsed.value = !collapsed.value
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('sb-collapsed', collapsed.value ? '1' : '0')
    }
  }

  async function refreshBadges() {
    try {
      const [pesajesRes, dashRes] = await Promise.allSettled([
        listPesajesManicuraAdmin(),   // pesajes de manicura enviados, esperando confirmación
        getTareasDashboard(),
      ])
      if (pesajesRes.status === 'fulfilled') {
        aprobPendientes.value = (pesajesRes.value.data || []).length
      }
      if (dashRes.status === 'fulfilled') {
        tareasPendientes.value = dashRes.value.data?.stats?.pendientes || 0
      }
    } catch {}
  }

  function badgeFor(key) {
    if (key === 'aprob')  return aprobPendientes.value
    if (key === 'tareas') return tareasPendientes.value
    return 0
  }

  return { collapsed, toggleCollapse, aprobPendientes, tareasPendientes, refreshBadges, badgeFor }
}
