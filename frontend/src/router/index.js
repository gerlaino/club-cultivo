import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore }   from "../stores/auth";
import { usePermissions } from "../composables/usePermissions";
import { useToast }       from "../composables/useToast";
import { usePWA }         from "../composables/usePWA";

const MOBILE_ROLES = ['admin', 'supervisor', 'cultivador', 'manicura', 'delivery', 'dispensador']
const MOBILE_HOME  = {
  // Inicio, que es la primera tab de su barra: entrar directo a Cultivo dejaba al admin en una
  // pantalla intermedia sin el pulso del día.
  admin:      '/m/admin/home',
  supervisor: '/m/admin/home',
  cultivador: '/m/cultivador/sedes',
  manicura:   '/m/manicura/pesar',
  delivery:   '/m/delivery/despachos',
  dispensador:'/m/dispensar',
}

const requiresPermission = (resource, action) => {
  return async (to, from, next) => {
    const auth = useAuthStore();
    // Esperar el bootstrap: en un refresh, el beforeEnter corre antes de que fetchMe
    // traiga el usuario, y can() devolvía false (rol vacío) → redirigía a dashboard.
    await auth.ensureBootstrapped();
    const { can } = usePermissions();
    if (!auth.isAuthenticated) {
      next({ name: "login", query: { redirect: to.fullPath } });
    } else if (!can(resource, action)) {
      useToast().warning(
        `No tenés acceso a esta sección con tu rol (${auth.user?.role || 'sin rol'}). ` +
        'Si creés que deberías tenerlo, pedíselo a un administrador del club.'
      );
      next(ROLE_HOME[auth.user?.role] || "/");
    } else {
      next();
    }
  };
};

const routes = [
  {
    path: "/login",
    name: "login",
    component: () => import("../views/LoginView.vue"),
    meta: { guestOnly: true, fullscreen: true },
  },

  // Landing pública de la plataforma. Es lo que ve quien entra al dominio sin sesión:
  // antes caía directo en el formulario de login, que no le cuenta a nadie qué es esto.
  // El dashboard sigue viviendo en "/" para los usuarios logueados (ver el guard global).
  {
    path: "/bienvenida",
    name: "landing",
    component: () => import("../views/LandingView.vue"),
    meta: { public: true, fullscreen: true },
  },

  // Dashboard
  {
    path: "/",
    name: "dashboard",
    component: () => import("../views/DashboardView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: () => {
      const auth = useAuthStore()
      if (auth.user?.role === 'super_admin') return '/super-admin'
      if (auth.user?.role === 'auditor')     return '/auditor'
      if (auth.user?.role === 'medico')      return '/medico'
      if (auth.user?.role === 'abogado')     return '/abogado'
      if (auth.user?.role === 'manicura')    return '/mnc/pendientes'
      if (auth.user?.role === 'delivery')    return '/delivery'
    },
  },

  // Sedes
  {
    path: "/sedes",
    name: "sedes",
    component: () => import("../views/SedesView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("sedes", "index"),
  },
  {
    path: "/sedes/:id",
    name: "sede-detail",
    component: () => import("../views/SedeDetailView.vue"),
    props: (r) => ({ id: Number(r.params.id) }),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("sedes", "show"),
  },

  // Después de sedes
  {
    path: "/contabilidad",
    name: "contabilidad",
    component: () => import("../views/ContabilidadView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("movimientos_contables", "index"),
  },
  {
    path: "/finanzas/catalogo",
    name: "finanzas-catalogo",
    component: () => import("../views/admin/FinanzasCatalogoView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role === "admin") next()
      else next("/")
    },
  },
  {
    path: "/insumos",
    name: "insumos",
    component: () => import("../views/admin/InsumosView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor", "cultivador"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/finanzas/reporte",
    name: "finanzas-reporte",
    component: () => import("../views/admin/ReporteFinanzasView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "auditor"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar",
    name: "bar-selector",
    component: () => import("../views/bar/BarSelectorView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor", "dispensador"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar/:barId/vender",
    name: "bar-pos",
    component: () => import("../views/bar/BarPosView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor", "dispensador"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar/:barId/panel",
    name: "bar-panel",
    component: () => import("../views/bar/BarPanelView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar/:barId/stock",
    name: "bar-stock",
    component: () => import("../views/bar/BarStockView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor", "dispensador"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar/:barId/eventos",
    name: "bar-eventos",
    component: () => import("../views/bar/EventosBarView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar/:barId/eventos/:eventoId",
    name: "bar-evento-detalle",
    component: () => import("../views/bar/EventoBarDetailView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar/:barId/eventos/:eventoId/entradas",
    name: "bar-evento-entradas",
    component: () => import("../views/bar/EntradasView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor"].includes(auth.user?.role)) next()
      else next("/")
    },
  },
  {
    path: "/bar/:barId/eventos/:eventoId/puerta",
    name: "bar-evento-puerta",
    component: () => import("../views/bar/PuertaView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (["admin", "supervisor", "dispensador"].includes(auth.user?.role)) next()
      else next("/")
    },
  },

  // Salas
  {
    path: "/salas",
    name: "salas",
    component: () => import("../views/SalasView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("salas", "index"),
  },
  {
    path: "/salas/nueva",
    redirect: "/salas",
  },
  {
    path: "/salas/:id",
    name: "sala-detail",
    component: () => import("../views/SalaDetailView.vue"),
    props: (r) => ({ id: Number(r.params.id) }),
    beforeEnter: requiresPermission("salas", "show"),
  },
  {
    path: "/salas/:id/ambiente",
    name: "sala-ambiente",
    component: () => import("../views/SalaAmbienteView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("ambiente", "index"),
  },

  // Módulo Ambiente — admin only
  {
    path: "/dispositivos",
    name: "dispositivos",
    component: () => import("../views/DispositivosView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role === "admin") next()
      else next("/")
    },
  },
  {
    path: "/reglas-ambientales",
    name: "reglas-ambientales",
    component: () => import("../views/ReglasAmbientalesView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role === "admin") next()
      else next("/")
    },
  },

  // Lotes
  {
    path: "/lotes",
    name: "lotes",
    component: () => import("../views/LotesView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("lotes", "index"),
  },
  {
    path: "/cosechado",
    name: "cosechado",
    component: () => import("../views/CosechadoView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("lotes", "index"),
  },
  {
    path: "/cosechado/:id",
    name: "cosechado-detalle",
    component: () => import("../views/LoteCosechadoDetalleView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("lotes", "index"),
  },
  {
    path: "/cosechado/:loteId/planta/:id",
    name: "planta-cosechada-detalle",
    component: () => import("../views/PlantaCosechadaDetalleView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("lotes", "index"),
  },
  {
    path: "/historial-cultivador",
    name: "historial-cultivador",
    component: () => import("../views/HistorialCultivadorView.vue"),
    meta: { requiresAuth: true },
  },
  {
    path: "/plan-trabajo",
    name: "plan-trabajo",
    component: () => import("../views/PlanTrabajoView.vue"),
    meta: { requiresAuth: true },
  },
  {
    path: "/rendimiento",
    name: "rendimiento",
    component: () => import("../views/RendimientoView.vue"),
    meta: { requiresAuth: true },
  },
  {
    path: "/analitica",
    name: "analitica",
    component: () => import("../views/AnaliticaView.vue"),
    meta: { requiresAuth: true },
  },
  {
    path: "/lotes/:id",
    name: "lote-detail",
    component: () => import("../views/LoteDetailView.vue"),
    props: true,
    beforeEnter: requiresPermission("lotes", "show"),
  },

  // Plantas
  {
    path: "/plantas",
    name: "plantas",
    component: () => import("../views/PlantasView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("plantas", "index"),
  },
  {
    path: "/plantas/nueva",
    name: "planta-nueva",
    component: () => import("../views/PlantaNuevaView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("plantas", "create"),
  },
  {
    path: "/plantas/:id",
    name: "planta-detalle",
    component: () => import("../views/PlantaDetailView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("plantas", "show"),
  },

  // Genéticas
  {
    path: "/geneticas",
    name: "geneticas",
    component: () => import("../views/GeneticasView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("geneticas", "index"),
  },
  {
    path: "/geneticas/:id",
    name: "genetica-detalle",
    component: () => import("../views/GeneticaDetalleView.vue"),
    props: (r) => ({ id: Number(r.params.id) }),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("geneticas", "show"),
  },

  // Pacientes
  {
    path: "/pacientes",
    alias: ["/socios"],
    name: "pacientes",
    component: () => import("../views/PacientesDispatch.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("socios", "index"),
  },
  {
    path: "/socios/criticos",
    name: "socios-criticos",
    component: () => import("../views/SociosCriticosView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (['admin', 'supervisor'].includes(auth.user?.role)) next();
      else next('/');
    },
  },
  {
    path: "/pacientes/nuevo",
    alias: ["/socios/nuevo"],
    name: "paciente-nuevo",
    component: () => import("../views/SocioNuevoView.vue"),
    beforeEnter: requiresPermission("socios", "create"),
  },
  {
    path: "/pacientes/:id",
    alias: ["/socios/:id"],
    name: "paciente-detail",
    component: () => import("../views/SocioDetailView.vue"),
    props: route => ({ backPath: '/pacientes' }),
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      const role = auth.user?.role
      // El dispensador entra a la ficha pero solo ve la tab Dispensaciones (ver SocioDetailView).
      if (['delivery', 'abogado', 'cultivador', 'manicura'].includes(role)) return next('/')
      const { can } = usePermissions()
      if (!can('socios', 'show')) return next('/')
      next()
    },
  },

  // Usuarios
  {
    path: "/usuarios",
    name: "usuarios",
    component: () => import("../views/UsuariosView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("usuarios", "index"),
  },
  {
    path: "/usuarios/:id",
    name: "usuario-detail",
    component: () => import("../views/UsuarioDetail.vue"),
    beforeEnter: requiresPermission("usuarios", "show"),
  },

  // Perfil y Preferencias
  {
    path: "/perfil",
    name: "perfil",
    component: () => import("../views/PerfilView.vue"),
    meta: { requiresAuth: true },
  },
  {
    path: "/preferencias",
    name: "preferencias",
    component: () => import("../views/PreferenciasView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (auth.user?.role === "admin") next();
      else next("/");
    },
  },
  {
    path: "/alertas-configuracion",
    name: "alertas-configuracion",
    component: () => import("../views/SetpointsConfigView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (auth.user?.role === "admin") next();
      else next("/");
    },
  },
  {
    path: "/configuracion",
    component: () => import("../views/ConfiguracionView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (auth.user?.role === "admin") next();
      else next("/");
    },
    children: [
      { path: '',           redirect: '/configuracion/club' },
      { path: 'club',       name: 'config-club',        component: () => import("../views/PreferenciasView.vue") },
      { path: 'sedes',      name: 'config-sedes',       component: () => import("../views/SedesView.vue") },
      { path: 'equipo',     name: 'config-equipo',      component: () => import("../views/UsuariosView.vue") },
      { path: 'suscripcion',name: 'config-suscripcion', component: () => import("../views/SuscripcionTabView.vue") },
      { path: 'papelera',   name: 'config-papelera',    component: () => import("../views/admin/PapeleraView.vue") },
    ],
  },
  {
    path: "/integraciones",
    name: "integraciones",
    component: () => import("../views/IntegracionesView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (auth.user?.role === "admin") next();
      else next("/");
    },
  },

  // ARICCAME
  {
    path: "/ariccame",
    name: "ariccame",
    component: () => import("../views/AriccameView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (["admin", "super_admin"].includes(auth.user?.role)) next();
      else next("/");
    },
  },

  // Templates de documentos (solo admin)
  {
    path: "/documentos/templates",
    name: "document-templates",
    component: () => import("../views/DocumentTemplatesView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (auth.user?.role === "admin") next();
      else next("/");
    },
  },

  // Web publica
  {
    path: '/web',
    name: 'web-publica-panel',
    component: () => import('../views/WebPublicaView.vue'),
    meta: { requiresAuth: true },
  },

  // Informe REPROCANN
  {
    path: "/informe-semestral",
    name: "informe-semestral",
    component: () => import("../views/InformeSemestralView.vue"),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("informe_semestral", "show"),
  },

  // Tareas
  {
    path: '/tareas',
    name: 'tareas',
    component: () => import('../views/TareasView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission('tareas', 'index'),
  },

  {
    path: '/documentos',
    name: 'documentos',
    component: () => import("../views/DocumentosView.vue"),
    meta: { requiresAuth: true }
  },

  // Rutas legacy: el home del manicura es /mnc/pendientes; la aprobación (admin/supervisor)
  // vive en /admin/pesajes-manicura. Se redirigen para no romper bookmarks viejos.
  {
    path: '/manicura',
    redirect: '/mnc/pendientes',
  },
  {
    path: '/aprobaciones',
    redirect: '/admin/pesajes-manicura',
  },

  {
    path: '/admin/cosechado',
    name: 'admin-cosechado',
    component: () => import('../views/admin/AdminCosechadoView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role !== 'admin') return next('/')
      next()
    },
  },

  {
    path: '/admin/papelera',
    name: 'admin-papelera',
    component: () => import('../views/admin/PapeleraView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'super_admin'].includes(auth.user?.role)) return next('/')
      next()
    },
  },
  {
    path: '/admin/stock',
    alias: '/admin/stocks/pendientes',
    name: 'admin-stock',
    component: () => import('../views/admin/AdminStocksPendientesView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role !== 'admin') return next('/')
      next()
    },
  },
  {
    path: '/admin/stock/:id',
    name: 'admin-stock-detail',
    component: () => import('../views/admin/AdminStockDetailView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role !== 'admin') return next('/')
      next()
    },
  },

  {
    path: '/admin/pesajes-manicura',
    name: 'admin-pesajes-manicura',
    component: () => import('../views/admin/AdminPesajesManicuraView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'supervisor'].includes(auth.user?.role)) return next('/')
      next()
    },
  },

  // Manicura role routes
  {
    path: '/mnc',
    redirect: '/mnc/pendientes',
    meta: { requiresAuth: true },
  },
  {
    path: '/mnc/pendientes',
    name: 'mnc-pendientes',
    component: () => import('../views/manicura/MncPendientesView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      const role = auth.user?.role
      if (!['admin', 'manicura'].includes(role)) return next('/')
      next()
    },
  },
  {
    path: '/mnc/en-espera',
    redirect: '/mnc/espera',
  },
  {
    path: '/mnc/espera',
    name: 'mnc-espera',
    component: () => import('../views/manicura/MncEsperaView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      const role = auth.user?.role
      if (!['admin', 'manicura'].includes(role)) return next('/')
      next()
    },
  },
  {
    path: '/mnc/lotes/:id',
    name: 'mnc-lote-detail',
    component: () => import('../views/manicura/MncLoteDetailView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'manicura'].includes(auth.user?.role)) return next('/')
      next()
    },
  },
  {
    // El workspace de pesajes se consolidó dentro del detalle del lote (/mnc/lotes/:id).
    // Se mantiene como redirect para no romper bookmarks. (La PWA sigue usando la vista
    // en /m/manicura/pesajes.)
    path: '/mnc/pesajes',
    redirect: '/mnc/pendientes',
  },

  {
    path: '/super-admin',
    component: () => import('../views/superadmin/SuperAdminLayout.vue'),
    meta: { requiresAuth: true },
    beforeEnter: () => {
      const auth = useAuthStore()
      if (auth.user?.role !== 'super_admin') return '/'
    },
    children: [
      { path: '', name: 'sa-dashboard', component: () => import('../views/superadmin/SADashboard.vue') },
      { path: 'clubs', name: 'sa-clubs', component: () => import('../views/superadmin/SAClubs.vue') },
      { path: 'clubs/nuevo', name: 'sa-club-nuevo', component: () => import('../views/superadmin/SAClubNuevo.vue') },
      { path: 'clubs/:id', name: 'sa-club-detail', component: () => import('../views/superadmin/SAClubDetail.vue') },
      { path: 'usuarios', name: 'sa-usuarios', component: () => import('../views/superadmin/SAUsuarios.vue') },
    ],
  },

  {
    path: '/g/:slug',
    name: 'genetica-publica',
    component: () => import('../views/GeneticaPublicaView.vue'),
    meta: { public: true, fullscreen: true },
  },

  {
    path: '/p/:codigo_qr',
    name: 'planta-qr',
    component: () => import('../views/PlantaQrView.vue'),
    meta: { fullscreen: true, requiresAuth: true },
  },
  {
    path: '/s/:codigo_qr',
    name: 'stock-qr',
    component: () => import('../views/StockQrView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/c/:token',
    name: 'carnet-publico',
    component: () => import('../views/CarnetPublicoView.vue'),
    meta: { fullscreen: true },
  },
  {
    path: '/d/:token',
    name: 'dispensa-publica',
    component: () => import('../views/DispensaQrView.vue'),
    meta: { fullscreen: true },
  },
  {
    path: '/mis-horas',
    name: 'mis-horas',
    component: () => import('../views/MisHorasView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/l/:codigo_qr',
    name: 'lote-qr',
    component: () => import('../views/LoteQrView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/stocks/:id/etiqueta',
    name: 'stock-etiqueta',
    component: () => import('../views/EtiquetaStockView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/despachos/:id/etiqueta',
    name: 'despacho-etiqueta',
    component: () => import('../views/delivery/EtiquetaDespachoView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/despachos/etiquetas',
    name: 'despacho-etiquetas-lote',
    component: () => import('../views/delivery/EtiquetasLoteView.vue'),
    meta: { requiresAuth: true },
  },

  // ── Dispensador routes ──
  // (Se eliminó /dispensar: el dispensado ahora vive en el modal de la ficha del socio
  //  y del historial — ver ModalNuevaDispensacion, con carrito multi-item.)
  {
    path: '/historial',
    name: 'historial-dispensaciones',
    component: () => import('../views/HistorialDispensacionesView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role === 'dispensador' || auth.user?.role === 'admin') next()
      else next('/')
    },
  },
  {
    path: '/dispensaciones/:id',
    name: 'dispensacion-detalle',
    component: () => import('../views/DispensacionDetalleView.vue'),
    props: (r) => ({ id: Number(r.params.id) }),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (['admin', 'supervisor', 'dispensador', 'super_admin'].includes(auth.user?.role)) next()
      else next('/')
    },
  },
  {
    path: '/reservas',
    name: 'reservas',
    component: () => import('../views/ReservasView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (['dispensador', 'admin', 'supervisor'].includes(auth.user?.role)) next()
      else next('/')
    },
  },
  {
    path: '/stock',
    name: 'stock-dispensador',
    component: () => import('../views/StockDispensadorView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role === 'dispensador' || auth.user?.role === 'admin') next()
      else next('/')
    },
  },

  // ── Médico routes ──
  {
    path: '/medico',
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'medico'].includes(auth.user?.role)) return next('/')
      next()
    },
    children: [
      { path: '', name: 'medico-dashboard', component: () => import('../views/medico/MedicoDashboard.vue') },
      { path: 'pacientes', name: 'medico-pacientes', component: () => import('../views/medico/MedicoPacientesView.vue') },
      { path: 'pacientes/:id', name: 'medico-paciente-detail', component: () => import('../views/SocioDetailView.vue'), props: () => ({ backPath: '/medico/pacientes' }) },
      { path: 'turnos', name: 'medico-turnos', component: () => import('../views/medico/MedicoTurnosView.vue') },
      { path: 'disponibilidad', name: 'medico-disponibilidad', component: () => import('../views/medico/MedicoDisponibilidadView.vue') },

      // La ficha del paciente es UNA: SocioDetailView. Antes había una segunda vista en
      // /ficha con timeline y notas repetidos, y las indicaciones y los documentos vivían en
      // pantallas propias que listaban los de TODOS los pacientes mezclados. Ahora son tabs de
      // su paciente. Los redirects quedan por los enlaces viejos (mails, bookmarks, QR).
      { path: 'pacientes/:id/ficha', redirect: to => `/medico/pacientes/${to.params.id}` },
      { path: 'indicaciones', redirect: '/medico/pacientes' },
      { path: 'documentos',   redirect: '/medico/pacientes' },
    ],
  },

  // ── Abogado routes ──
  {
    path: '/abogado',
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'abogado'].includes(auth.user?.role)) return next('/')
      next()
    },
    children: [
      { path: '', name: 'abogado-dashboard', component: () => import('../views/abogado/AbogadoDashboard.vue') },
      { path: 'documentos', name: 'abogado-documentos', component: () => import('../views/abogado/AbogadoMisDocumentosView.vue') },
    ],
  },

  // ── Auditor routes ──
  {
    path: '/auditor',
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'auditor'].includes(auth.user?.role)) return next('/')
      next()
    },
    children: [
      { path: '', name: 'auditor-dashboard', component: () => import('../views/auditor/AuditorDashboard.vue') },
      { path: 'reprocann', name: 'auditor-reprocann', component: () => import('../views/auditor/InformeReprocannView.vue') },
      { path: 'produccion', name: 'auditor-produccion', component: () => import('../views/auditor/InformeProduccionView.vue') },
      { path: 'dispensaciones', name: 'auditor-dispensaciones', component: () => import('../views/auditor/InformeDispensacionesView.vue') },
      { path: 'sedes', name: 'auditor-sedes', component: () => import('../views/auditor/InformeSedesView.vue') },
      { path: 'cumplimiento', name: 'auditor-cumplimiento', component: () => import('../views/auditor/InformeCumplimientoView.vue') },
      { path: 'plan-vs-real', name: 'auditor-plan-vs-real', component: () => import('../views/auditor/InformePlanVsRealView.vue') },
      { path: 'inase', name: 'auditor-inase', component: () => import('../views/auditor/InformeInaseView.vue') },
      { path: 'perdidas', name: 'auditor-perdidas', component: () => import('../views/auditor/InformePerdidasView.vue') },
      { path: 'trazabilidad', name: 'auditor-trazabilidad', component: () => import('../views/auditor/TrazabilidadView.vue') },
    ],
  },

  {
    path: '/delivery',
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'delivery'].includes(auth.user?.role)) return next('/')
      next()
    },
    children: [
      { path: '', name: 'delivery-dashboard', component: () => import('../views/delivery/DeliveryDashboard.vue') },
      {
        path: 'despachos',
        name: 'delivery-despachos',
        component: () => import('../views/delivery/DespachoListView.vue'),
        beforeEnter: (to, from, next) => {
          const auth = useAuthStore()
          if (!['admin', 'supervisor'].includes(auth.user?.role)) return next('/delivery')
          next()
        },
      },
    ],
  },

  // ── Mobile PWA shell ─────────────────────────────────────────────────
  {
    path: '/m',
    component: () => import('../components/layout/MobileShell.vue'),
    meta: { requiresAuth: true },
    children: [
      // Redirect /m → primera tab del rol.
      // Roles sin shell mobile (dispensador, medico, etc.) van a su home desktop.
      { path: '', redirect: () => {
          const role = useAuthStore().user?.role
          const homes = {
            admin:      '/m/admin/home',
            supervisor: '/m/admin/home', // supervisor comparte rutas mobile de admin
            cultivador: '/m/cultivador/sedes',
            manicura:   '/m/manicura/pesar',
            delivery:   '/m/delivery/despachos',
            dispensador:'/m/dispensar',
          }
          return homes[role] || '/'
        }
      },

      // ── Horas (manicura / cultivador) ──
      { path: 'horas', component: () => import('../views/MisHorasView.vue') },

      // ── Cultivador ──
      { path: 'cultivador/sedes',  component: () => import('../views/mobile/MSedesView.vue') },
      { path: 'cultivador/tareas', component: () => import('../views/mobile/MTareasView.vue') },

      // ── Dispensador ──
      { path: 'dispensar', component: () => import('../views/mobile/MDispensarView.vue') },
      { path: 'reservas',  component: () => import('../views/mobile/MReservasView.vue') },
      { path: 'stock',     component: () => import('../views/StockDispensadorView.vue') },

      // Las MISMAS vistas de la web, montadas dentro del shell. La PWA no recorta lo que el rol
      // puede hacer: cambia el envoltorio (bottom nav, tablas como tarjetas), no el contenido.
      // Van bajo /m porque el guard de PWA rebota cualquier ruta fuera de ese prefijo.
      { path: 'plantas',   component: () => import('../views/PlantasView.vue') },
      { path: 'geneticas', component: () => import('../views/GeneticasView.vue') },
      { path: 'historial', component: () => import('../views/HistorialDispensacionesView.vue') },
      { path: 'pacientes', component: () => import('../views/PacientesDispatch.vue') },

      // ── Escaneo QR (cualquier rol con shell mobile) ──
      { path: 'scan', component: () => import('../views/mobile/MScanView.vue') },

      // ── Admin / Supervisor ──
      { path: 'admin/home',    component: () => import('../views/mobile/MAdminHomeView.vue') },
      { path: 'admin/sedes',   component: () => import('../views/mobile/MSedesView.vue') },
      { path: 'admin/tareas',  component: () => import('../views/mobile/MTareasView.vue') },
      { path: 'admin/aprobar', component: () => import('../views/mobile/MAdminAprobacionView.vue') },

      // ── Detalle mobile propio ──
      { path: 'sede/:id',   component: () => import('../views/mobile/MSedeMobileDetail.vue') },
      { path: 'sala-m/:id', component: () => import('../views/mobile/MSalaMobileDetail.vue') },
      { path: 'lote-m/:id', component: () => import('../views/mobile/MLoteMobileDetail.vue') },
      { path: 'planta/:id', component: () => import('../views/mobile/MPlantaDetailView.vue') },

      // ── Manicura ──
      { path: 'manicura/pesar',     component: () => import('../views/mobile/MCosechasPorPesarView.vue') },
      { path: 'manicura/pesajes',   component: () => import('../views/manicura/MncPesajesView.vue') },
      { path: 'manicura/aprobacion',component: () => import('../views/mobile/MPendientesAprobacionView.vue') },
      { path: 'manicura/tareas',    component: () => import('../views/mobile/MTareasView.vue') },
      { path: 'mnc/lotes/:id',      component: () => import('../views/manicura/MncLoteDetailView.vue') },

      // ── Delivery ── (el repartidor ve SU dashboard, no la vista admin de despachos)
      { path: 'delivery/despachos', component: () => import('../views/delivery/DeliveryDashboard.vue') },
      { path: 'delivery/historial', component: () => import('../views/mobile/MDeliveryHistorialView.vue') },
    ],
  },

  { path: "/:pathMatch(.*)*", redirect: "/" },

];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.afterEach((to) => {
  document.documentElement.classList.toggle("route-login", !!to.meta.fullscreen);
});

const ROLE_HOME = {
  super_admin: '/super-admin',
  auditor:     '/auditor',
  medico:      '/medico',
  abogado:     '/abogado',
  delivery:    '/delivery',
}

// A dónde puede entrar cada rol ESCRIBIENDO LA URL. Sin esto, un cultivador que tipea
// /contabilidad o /usuarios llega a la pantalla: el backend le responde 403 y ve una vista
// rota o vacía, sin entender por qué. Cubría 5 de los 11 roles.
//
// Los que faltaban (cultivador, supervisor, manicura, dispensador, paciente) usan el shell
// de admin, así que no alcanzaba con mirar el prefijo del layout: hay que listar qué
// secciones son suyas.
// Todo rol que usa la PWA necesita `/m`: el guard de PWA lo empuja a su MOBILE_HOME (que
// vive bajo /m) y si la matriz no lo admite, lo rebota — y el guard lo vuelve a empujar. Es
// un loop infinito que se ve como "queda cargando y no entra". Le pasaba al delivery en cada
// login desde la app instalada.
const COMUNES = ['/perfil', '/login', '/bienvenida']

const ROLE_ALLOWED_PREFIX = {
  super_admin: ['/super-admin', ...COMUNES],
  auditor:     ['/auditor',  ...COMUNES],
  medico:      ['/medico',   ...COMUNES],
  abogado:     ['/abogado',  ...COMUNES],
  delivery:    ['/delivery', '/m', ...COMUNES],

  // Cultivo: salas, lotes, plantas y lo que rodea al trabajo diario del cuarto.
  cultivador: ['/', '/salas', '/lotes', '/plantas', '/geneticas', '/tareas', '/plan-trabajo',
               '/historial-cultivador', '/cosechado', '/dispositivos', '/reglas-ambientales',
               '/m', ...COMUNES],

  // Supervisa el cultivo de sus sedes y además dispensa.
  supervisor: ['/', '/salas', '/lotes', '/plantas', '/geneticas', '/tareas', '/plan-trabajo',
               '/historial-cultivador', '/cosechado', '/dispositivos', '/reglas-ambientales',
               '/pacientes', '/socios', '/historial', '/admin/stock', '/insumos', '/sedes',
               '/m', ...COMUNES],

  // Post-cosecha: pesa los lotes que le asignan.
  manicura:   ['/', '/cosechado', '/lotes', '/plantas', '/tareas', '/m', ...COMUNES],

  // Mostrador: dispensa, cobra y consulta stock.
  dispensador: ['/', '/pacientes', '/socios', '/historial', '/admin/stock', '/insumos',
                '/bar', '/entregas', '/m', ...COMUNES],

  // El paciente sólo ve lo suyo (todavía sin portal propio: ver tarea del login de paciente).
  paciente:   ['/', ...COMUNES],
}

// Decisión pura, exportada para poder verificarla sin montar el router: ¿este rol puede
// entrar a esta ruta escribiendo la URL?
export function puedeEntrar(role, path) {
  const permitidos = ROLE_ALLOWED_PREFIX[role]
  if (!permitidos) return true // rol sin matriz (admin): el permiso fino lo aplica cada ruta
  return permitidos.some(p => path === p || (p !== '/' && path.startsWith(p + '/')) || (p === '/' && path === '/'))
}

export { ROLE_ALLOWED_PREFIX, ROLE_HOME, MOBILE_ROLES, MOBILE_HOME }

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  // Esperamos el bootstrap en TODAS las rutas de la app (no solo las requiresAuth):
  // muchas tienen beforeEnter que chequean el rol, y en un refresh corrían antes de
  // que fetchMe trajera el usuario → can()/role daban vacío y redirigían a dashboard.
  // Las páginas públicas por token (carnet, dispensa, genética) NO se bloquean — así
  // renderizan al instante aunque el backend esté despertando (free tier).
  // El LOGIN nunca espera el bootstrap. Es la pantalla a la que caés cuando algo salió mal
  // (sesión vencida, logout, backend dormido): si para mostrarla hay que esperar un /me que
  // puede colgarse, el usuario se queda mirando una pantalla muerta sin poder hacer nada.
  // El formulario no necesita saber si había sesión previa — necesita dejarte entrar.
  // Las públicas por token (carnet, dispensa, genética) y la landing, por lo mismo: rendir ya.
  const noEsperaBootstrap =
    /^\/(c|d|g)\//.test(to.path) || to.path === '/bienvenida' || to.path === '/login';

  if (noEsperaBootstrap) {
    auth.ensureBootstrapped();
  } else {
    await auth.ensureBootstrapped();
  }

  // La raíz hace de puerta comercial: sin sesión muestra la landing en vez de mandar a
  // un formulario de login, que no le dice nada a quien llega por primera vez.
  // Con sesión, "/" sigue siendo el dashboard de siempre.
  //
  // EXCEPCIÓN: la PWA instalada arranca en "/" y ahí el usuario ya sabe qué es esto — viene a
  // trabajar, no a que le vendan la plataforma. Mandarlo a la landing le mete una pantalla de
  // más entre el ícono y su sesión.
  if (to.path === '/' && !auth.isAuthenticated) {
    return usePWA().isPWA() ? { name: 'login' } : { name: 'landing' };
  }

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: "login", query: { redirect: to.fullPath } };
  }
  if (to.meta.guestOnly && auth.isAuthenticated) {
    const redirect = to.query.redirect || "/";
    return typeof redirect === "string" ? redirect : "/";
  }

  const role = auth.user?.role
  const { isPWA } = usePWA()

  // En modo PWA instalada, mantener dentro del shell mobile
  if (
    auth.isAuthenticated &&
    isPWA() &&
    MOBILE_ROLES.includes(role) &&
    !to.path.startsWith('/m') &&
    !to.path.startsWith('/p/') &&
    !to.path.startsWith('/s/') &&
    !to.path.startsWith('/g/') &&
    !to.path.startsWith('/c/') &&
    !to.path.startsWith('/d/') &&
    !to.path.startsWith('/l/') &&
    // El Buffet es responsive y el dispensador lo abre desde su propia barra: sin esta
    // excepción el guard lo rebotaba a /m/dispensar y el botón parecía no hacer nada.
    !to.path.startsWith('/bar') &&
    !to.path.endsWith('/etiqueta') &&
    !to.path.startsWith('/login')
  ) {
    // Si es una página de detalle conocida, redirigir a su equivalente /m/
    // para que quede dentro del MobileShell con bottom nav
    const detalleMatch = to.path.match(/^\/(salas|lotes|plantas)\/(\d+)/)
    if (detalleMatch) {
      const map = { salas: 'sala-m', lotes: 'lote-m', plantas: 'planta' }
      return `/m/${map[detalleMatch[1]]}/${detalleMatch[2]}`
    }
    // Ruta de manicura → equivalente mobile
    const mncMatch = to.path.match(/^\/mnc\/lotes\/(\d+)/)
    if (mncMatch) return `/m/mnc/lotes/${mncMatch[1]}`

    return MOBILE_HOME[role]
  }

  // Las páginas públicas (landing, carnet, pasaporte de dispensa, genética) no entran en la
  // matriz de prefijos: cualquiera las ve sin sesión, así que bloquearlas a un rol logueado
  // solo produce un "Sin permisos" que no viene al caso.
  if (auth.isAuthenticated && !to.meta.public && ROLE_ALLOWED_PREFIX[role]) {
    if (!puedeEntrar(role, to.path)) {
      useToast().warning(
        `No tenés acceso a esa sección con tu rol (${role}). ` +
        'Si creés que deberías tenerlo, pedíselo a un administrador del club.'
      )
      return ROLE_HOME[role] || '/'
    }
  }

  return true;
});

export default router;
