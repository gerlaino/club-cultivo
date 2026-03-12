import { createRouter, createWebHistory } from "vue-router";
import LoginView from "../views/LoginView.vue";
import DashboardView from "../views/DashboardView.vue";
import SalasView from "../views/SalasView.vue";
import LotesView from "../views/LotesView.vue";
import SalaDetailView from "../views/SalaDetailView.vue";
import LoteDetailView from "../views/LoteDetailView.vue";
import { useAuthStore } from "../stores/auth";
import PlantasView from "../views/PlantasView.vue";
import PlantaDetalleView from "../views/PlantaDetalleView.vue";
import PerfilView from "../views/PerfilView.vue";
import PreferenciasView from "../views/PreferenciasView.vue";
import SociosView from "../views/SociosView.vue";
import SocioDetailView from "../views/SocioDetailView.vue";
import UsuariosView from "../views/UsuariosView.vue";
import UsuarioDetail from "../views/UsuarioDetail.vue";

const routes = [
  { path: "/login", name: "login", component: LoginView, meta: { guestOnly: true, fullscreen: true } },

  { path: "/salas/:id", name: "sala-detail", component: SalaDetailView, props: (r) => ({ id: Number(r.params.id) }) },
  { path: "/plantas",     name: "plantas",       component: PlantasView,       meta: { requiresAuth: true } },
  { path: "/plantas/nueva", name: "planta-nueva", component: () => import("../views/PlantaNuevaView.vue"), meta: { requiresAuth: true } },
  { path: "/plantas/:id", name: "planta-detalle", component: () => import("../views/PlantaDetalleView.vue"), meta: { requiresAuth: true } },
  { path: "/lotes/:id", name: "lote-detail", component: LoteDetailView, props: true },
  { path: "/plantas/:id", name: "plant-detail", component: PlantaDetalleView, props: true },
  { path: "/socios/:id", name: "socio-detail", component: SocioDetailView, props: true },
  { path: "/usuarios/:id", name: "usuario-detail", component: UsuarioDetail },

  { path: "/",            name: "dashboard",     component: DashboardView,     meta: { requiresAuth: true } },
  { path: "/salas",       name: "salas",         component: SalasView,         meta: { requiresAuth: true } },
  { path: "/socios",      name: "socios",        component: SociosView,        meta: { requiresAuth: true } },
  { path: "/usuarios",    name: "usuarios",      component: UsuariosView,      meta: { requiresAuth: true } },
  { path: "/perfil",      name: "perfil",        component: PerfilView,        meta: { requiresAuth: true } },
  { path: "/preferencias",name: "preferencias",  component: PreferenciasView,  meta: { requiresAuth: true } },

  { path: "/:pathMatch(.*)*", redirect: "/" },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.afterEach((to) => {
  document.documentElement.classList.toggle("route-login", !!to.meta.fullscreen);
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();

  // 👇 Esperamos que /me se haya consultado una sola vez por carga
  await auth.ensureBootstrapped();

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: "login", query: { redirect: to.fullPath } };
  }

  if (to.meta.guestOnly && auth.isAuthenticated) {
    const redirect = to.query.redirect || "/";
    return typeof redirect === "string" ? redirect : "/";
  }

  return true;
});

export default router;


