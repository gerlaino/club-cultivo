import { createRouter, createWebHistory } from "vue-router";
import LoginView from "../views/LoginView.vue";
import DashboardView from "../views/DashboardView.vue";
import SalasView from "../views/SalasView.vue";
import SalaDetailView from "../views/SalaDetailView.vue";
import LotesView from "../views/LotesView.vue";
import LoteDetailView from "../views/LoteDetailView.vue";
import PlantasView from "../views/PlantasView.vue";
import PlantaDetailView from "../views/PlantaDetailView.vue";
import PerfilView from "../views/PerfilView.vue";
import PreferenciasView from "../views/PreferenciasView.vue";
import PacientesDispatch from "../views/PacientesDispatch.vue";
import PacienteDetailView from "../views/SocioDetailView.vue";
import UsuariosView from "../views/UsuariosView.vue";
import UsuarioDetail from "../views/UsuarioDetail.vue";
import SedesView from "../views/SedesView.vue";
import SedeDetailView from "../views/SedeDetailView.vue";
import DocumentTemplatesView from "../views/DocumentTemplatesView.vue";
import { useAuthStore } from "../stores/auth";
import { usePermissions } from "../composables/usePermissions";
import { useToast } from "../composables/useToast";
import ContabilidadView from "../views/ContabilidadView.vue";
import InformeSemestralView from "../views/InformeSemestralView.vue";
import DocumentosView from "../views/DocumentosView.vue";

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
    component: LoginView,
    meta: { guestOnly: true, fullscreen: true },
  },

  // Dashboard
  {
    path: "/",
    name: "dashboard",
    component: DashboardView,
    meta: { requiresAuth: true },
    beforeEnter: () => {
      const auth = useAuthStore()
      if (auth.user?.role === 'super_admin') return '/super-admin'
      if (auth.user?.role === 'abogado')     return '/documentos'
    },
  },

  // Sedes
  {
    path: "/sedes",
    name: "sedes",
    component: SedesView,
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("sedes", "index"),
  },
  {
    path: "/sedes/:id",
    name: "sede-detail",
    component: SedeDetailView,
    props: (r) => ({ id: Number(r.params.id) }),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("sedes", "show"),
  },

  // Después de sedes
  {
    path: "/contabilidad",
    name: "contabilidad",
    component: ContabilidadView,
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("movimientos_contables", "index"),
  },

  // Salas
  {
    path: "/salas",
    name: "salas",
    component: SalasView,
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("salas", "index"),
  },
  {
    path: "/salas/:id",
    name: "sala-detail",
    component: SalaDetailView,
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
    component: LotesView,
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("lotes", "index"),
  },
  {
    path: "/lotes/:id",
    name: "lote-detail",
    component: LoteDetailView,
    props: true,
    beforeEnter: requiresPermission("lotes", "show"),
  },

  // Plantas
  {
    path: "/plantas",
    name: "plantas",
    component: PlantasView,
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
    component: PlantaDetailView,
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
    component: PacientesDispatch,
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("socios", "index"),
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
    component: PacienteDetailView,
    props: true,
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
    component: UsuariosView,
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission("usuarios", "index"),
  },
  {
    path: "/usuarios/:id",
    name: "usuario-detail",
    component: UsuarioDetail,
    beforeEnter: requiresPermission("usuarios", "show"),
  },

  // Perfil y Preferencias
  {
    path: "/perfil",
    name: "perfil",
    component: PerfilView,
    meta: { requiresAuth: true },
  },
  {
    path: "/preferencias",
    name: "preferencias",
    component: PreferenciasView,
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore();
      if (auth.user?.role === "admin") next();
      else next("/");
    },
  },

  // Templates de documentos (solo admin)
  {
    path: "/documentos/templates",
    name: "document-templates",
    component: DocumentTemplatesView,
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
    component: InformeSemestralView,
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
    component: DocumentosView,
    meta: { requiresAuth: true }
  },

  {
    path: '/manicura',
    name: 'manicura',
    component: () => import('../views/ManicuraView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: requiresPermission('manicura', 'access'),
  },

  // Manicura role routes
  {
    path: '/mnc',
    redirect: '/',
    meta: { requiresAuth: true },
  },
  {
    path: '/mnc/cosecha',
    name: 'mnc-cosecha',
    component: () => import('../views/manicura/LotesEnCosechaView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      const role = auth.user?.role
      if (!['admin', 'manicura'].includes(role)) return next('/')
      next()
    },
  },
  {
    path: '/mnc/secado',
    name: 'mnc-secado',
    component: () => import('../views/manicura/LotesEnSecadoView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      const role = auth.user?.role
      if (!['admin', 'manicura'].includes(role)) return next('/')
      next()
    },
  },
  {
    path: '/mnc/curado',
    name: 'mnc-curado',
    component: () => import('../views/manicura/LotesEnCuradoView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      const role = auth.user?.role
      if (!['admin', 'manicura'].includes(role)) return next('/')
      next()
    },
  },
  {
    path: '/mnc/stocks',
    name: 'mnc-stocks',
    component: () => import('../views/manicura/StocksManicuraView.vue'),
    meta: { requiresAuth: true },
    beforeEnter: (to, from, next) => {
      const auth = useAuthStore()
      const role = auth.user?.role
      if (!['admin', 'manicura'].includes(role)) return next('/')
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
    meta: { fullscreen: true },
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

  { path: "/:pathMatch(.*)*", redirect: "/" },

];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.afterEach((to) => {
  document.documentElement.classList.toggle("route-login", !!to.meta.fullscreen);
});

const ABOGADO_ALLOWED = ['/documentos', '/perfil', '/login']
const DELIVERY_BLOCKED = ['/pacientes']

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

  // Abogado: solo puede acceder a /documentos y /perfil
  if (auth.isAuthenticated && auth.user?.role === 'abogado') {
    const allowed = ABOGADO_ALLOWED.some(p => to.path === p || to.path.startsWith(p + '/'))
    if (!allowed) {
      useToast().warning('Sin permisos para acceder a esa sección')
      return '/documentos'
    }
  }

  // Delivery: bloqueado de /pacientes
  if (auth.isAuthenticated && auth.user?.role === 'delivery') {
    const blocked = DELIVERY_BLOCKED.some(p => to.path === p || to.path.startsWith(p + '/'))
    if (blocked) return '/'
  }

  return true;
});

export default router;
