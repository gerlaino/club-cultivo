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
    // Sedes — SIN bandera, a propósito. Todo club tiene al menos una (el onboarding la exige) y
    // todo lo demás cuelga de ella: salas, depósitos, stock, dispensaciones. Estuvo colgada de
    // `multi_sede` y después de la suite `cultivo`, y las dos veces la sección desapareció del
    // menú para clubes que sí la necesitaban. Un club con una sola sede igual quiere entrar a
    // verla; no hay nada que esconder acá.
    key: 'sedes', label: 'Sedes', to: '/sedes',
    tabs: [],
  },
  {
    key: 'cultivo', label: 'Cultivo', to: '/salas', feature: 'cultivo',
    tabs: [
      { to: '/salas', label: 'Salas' },
      { to: '/lotes', label: 'Lotes' },
      { to: '/plantas', label: 'Plantas' },
      { to: '/geneticas', label: 'Genéticas' },
    ],
  },
  {
    key: 'pacientes', label: 'Pacientes', to: '/pacientes', feature: 'produccion_dispensa',
    tabs: [
      { to: '/pacientes', label: 'Pacientes' },
      { to: '/historial', label: 'Dispensaciones' },
      // El informe REPROCANN vivía acá Y en Reportes: dos puertas al mismo asunto, con
      // contenidos distintos. Queda una sola, en Reportes, que es donde están los informes.
    ],
  },
  {
    key: 'produccion', label: 'Producción', to: '/admin/stock', feature: 'cultivo',
    tabs: [
      { to: '/admin/stock', label: 'Stock' },
      { to: '/admin/cosechado', label: 'Cosecha' },
      { to: '/admin/pesajes-manicura', label: 'Manicura', badge: 'aprob' },
    ],
  },
  {
    // Depósito — sección propia: es transversal (insumos de cultivo, generales y salón) y se
    // usa a diario, así que va de primer nivel en vez de enterrado como sub-pestaña.
    key: 'deposito', label: 'Depósito', to: '/insumos', tabs: [],
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
    // Buffet — grupo propio, visible solo si el club tiene el add-on activado.
    key: 'salon', label: 'Buffet', to: '/bar', feature: 'bar',
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
      // Una sola puerta a los informes. REPROCANN y Trazabilidad estaban acá como tabs
      // sueltos Y además adentro de "Auditoría", que es el índice que ya los lista: el mismo
      // informe se veía en dos lugares del mismo menú. Y "Auditoría" tampoco era el nombre:
      // el que entra es el admin del club, no un auditor.
      { to: '/auditor', label: 'Informes' },
      { to: '/ariccame', label: 'ARICCAME', feature: 'ariccame' },
      { to: '/documentos', label: 'Documentos' },
    ],
  },
  {
    key: 'config', label: 'Configuración', to: '/configuracion',
    tabs: [
      { to: '/configuracion', label: 'General' },
      { to: '/configuracion/suscripcion', label: 'Suscripción' },
      // Correo tiene su propio espacio: la casilla de la organización y las plantillas de mail.
      // Es un add-on, así que se cae del menú si la organización no lo tiene contratado.
      { to: '/configuracion/correo', label: 'Correo electrónico', feature: 'mailer' },
      { to: '/usuarios', label: 'Equipo' },
      // Sedes NO va acá: tiene su propia entrada en el menú lateral (es un cockpit operativo, no
      // una pantalla de ajustes). Duplicarla hacía que el mismo destino se viera en dos lugares.
      { to: '/alertas-configuracion', label: 'Configuración de alertas' },
      { to: '/web', label: 'Sitio web' },
      { to: '/integraciones', label: 'Integraciones' },
      { to: '/configuracion/papelera', label: 'Papelera' },
    ],
  },
]

// Grupo activo según la ruta: el tab cuyo `to` es el prefijo más largo del path gana
// (así /auditor/trazabilidad cae en Reportes y resalta Informes, que es su tab).
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
