import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore }   from "../stores/auth";
import { usePermissions } from "../composables/usePermissions";
import { useToast }       from "../composables/useToast";
import { usePWA }         from "../composables/usePWA";

const MOBILE_ROLES = ['admin', 'supervisor', 'cultivador', 'manicura', 'delivery']
const MOBILE_HOME  = {
  admin:      '/m/admin/sedes',
  supervisor: '/m/admin/sedes',
  cultivador: '/m/cultivador/sedes',
  manicura:   '/m/manicura/pesar',
  delivery:   '/m/delivery/despachos',
}

const requiresPermission = (resource, action) => {
  return (to, from, next) => {
    const auth = useAuthStore();
    const { can } = usePermissions();
    if (!auth.isAuthenticated) {
      next("/login");
    } else if (!can(resource, action)) {
      next("/");
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
      if (role === 'dispensador') return next('/pacientes')
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

  {
    path: '/manicura',
    redirect: '/aprobaciones',
  },

  {
    path: '/aprobaciones',
    name: 'aprobaciones',
    component: () => import('../views/admin/AdminAprobacionesView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role !== 'admin') return next('/')
      next()
    },
  },

  {
    path: '/admin/curado',
    name: 'admin-curado',
    component: () => import('../views/admin/AdminCuradoView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role !== 'admin') return next('/')
      next()
    },
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
    path: '/mnc/pesajes',
    name: 'mnc-pesajes',
    component: () => import('../views/manicura/MncPesajesView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (!['admin', 'manicura'].includes(auth.user?.role)) return next('/')
      next()
    },
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

  // ── Dispensador routes ──
  {
    path: '/dispensar',
    name: 'dispensar',
    component: () => import('../views/DispensarView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      if (auth.user?.role === 'dispensador' || auth.user?.role === 'admin') next()
      else next('/')
    },
  },
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
      { path: 'pacientes/:id/ficha', name: 'medico-ficha-paciente', component: () => import('../views/medico/MedicoFichaPacienteView.vue') },
      { path: 'turnos', name: 'medico-turnos', component: () => import('../views/medico/MedicoTurnosView.vue') },
      { path: 'disponibilidad', name: 'medico-disponibilidad', component: () => import('../views/medico/MedicoDisponibilidadView.vue') },
      { path: 'indicaciones', name: 'medico-indicaciones', component: () => import('../views/medico/MedicoIndicacionesView.vue') },
      { path: 'documentos', name: 'medico-documentos', component: () => import('../views/medico/MedicoDocumentosView.vue') },
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
            admin:      '/m/admin/sedes',
            supervisor: '/m/admin/sedes', // supervisor comparte rutas mobile de admin
            cultivador: '/m/cultivador/sedes',
            manicura:   '/m/manicura/pesar',
            delivery:   '/m/delivery/despachos',
          }
          return homes[role] || '/'
        }
      },

      // ── Cultivador ──
      { path: 'cultivador/sedes',  component: () => import('../views/mobile/MSedesView.vue') },
      { path: 'cultivador/tareas', component: () => import('../views/mobile/MTareasView.vue') },

      // ── Admin / Supervisor ──
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

      // ── Delivery ──
      { path: 'delivery/despachos', component: () => import('../views/delivery/DespachoListView.vue') },
      { path: 'delivery/historial', component: () => import('../views/delivery/DespachoListView.vue') },
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

const ROLE_ALLOWED_PREFIX = {
  super_admin: ['/super-admin', '/login'],
  auditor:     ['/auditor',  '/perfil', '/login'],
  medico:      ['/medico',   '/perfil', '/login'],
  abogado:     ['/abogado',  '/perfil', '/login'],
  delivery:    ['/delivery', '/perfil', '/login'],
}

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  await auth.ensureBootstrapped();

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
    !to.path.startsWith('/l/') &&
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

  if (auth.isAuthenticated && ROLE_ALLOWED_PREFIX[role]) {
    const allowed = ROLE_ALLOWED_PREFIX[role].some(p => to.path === p || to.path.startsWith(p + '/'))
    if (!allowed) {
      useToast().warning('Sin permisos para acceder a esa sección')
      return ROLE_HOME[role]
    }
  }

  return true;
});

export default router;
