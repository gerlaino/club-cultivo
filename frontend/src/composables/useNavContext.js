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
    // Equipo — grupo primario. Vivía como pestaña de Configuración, y no es una: dar de alta a
    // alguien, cambiarle el rol o ver sus horas es gestión de personas, se hace seguido y se
    // busca por su nombre. Su ruta (/usuarios) ya era de primer nivel; la pestaña sólo la
    // escondía adentro de ocho.
    key: 'equipo', label: 'Equipo', to: '/usuarios', tabs: [],
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
    // El MOSTRADOR: la mercadería sobre la mesa hoy. De primer nivel por el mismo motivo que
    // Depósito — en una organización que dispensa se abre, se opera y se cierra todos los días.
    // Enterrada como sub-pestaña, la pantalla que más se usa sería la más difícil de encontrar.
    key: 'mostrador', label: 'Mostrador', to: '/mostrador', feature: 'produccion_dispensa',
    tabs: [],
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
    // Contabilidad es de PRIMER NIVEL y sin bandera: toda organización tiene gastos, contrate lo
    // que contrate. Vivía adentro del grupo Comercial, que sí está gateado por la suite de
    // dispensa, así que una organización de sólo Cultivo no la veía en el menú… pero llegaba
    // igual desde Depósito ("＋ Comprar"), que es transversal. El resultado era una sección que
    // existe, funciona y está escondida — y encima accesible por una puerta lateral.
    key: 'contabilidad', label: 'Contabilidad', to: '/contabilidad', tabs: [],
  },
  {
    // Reservas y cuenta corriente sí son de la suite de dispensa: una organización de sólo
    // Cultivo veía el grupo entero y entraba a pantallas que el backend le rechaza.
    key: 'comercial', label: 'Comercial', to: '/reservas', feature: 'produccion_dispensa',
    tabs: [
      { to: '/reservas', label: 'Reservas' },
      // Despachos es Delivery, que desde el 11-ago se contrata aparte.
      { to: '/delivery/despachos', label: 'Despachos', feature: 'delivery' },
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
      // Correo tiene su propio espacio: la casilla de la organización y las plantillas de mail.
      // Es un add-on, así que se cae del menú si la organización no lo tiene contratado.
      { to: '/configuracion/correo', label: 'Correo electrónico', feature: 'mailer' },
      // Sedes NO va acá: tiene su propia entrada en el menú lateral (es un cockpit operativo, no
      // una pantalla de ajustes). Duplicarla hacía que el mismo destino se viera en dos lugares.
      // Equipo TAMPOCO: gestionar personas no es configurar la app, ya tenía ruta propia
      // (/usuarios) y acá sólo se listaba. Ahora es un grupo primario del menú lateral.
      { to: '/configuracion/portal', label: 'Portal del paciente', feature: 'vista_paciente' },
      // "Configuración de alertas" dentro de Configuración: la palabra repetida no ayudaba a
      // encontrarla. Se llega desde General, igual que Correo.
      //
      // Integraciones quedó siendo la pantalla de WhatsApp —los webhooks salieron de la vista del
      // admin— así que se cae del menú si no está contratado, como cualquier add-on.
      { to: '/integraciones', label: 'Integraciones', feature: 'whatsapp' },
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
