import { createRouter, createWebHistory } from "vue-router"
import LoginView from "../views/LoginView.vue"
import DashboardView from "../views/DashboardView.vue"
import SalasView from "../views/SalasView.vue"
import LotesView from "../views/LotesView.vue"
import SalaDetailView from "../views/SalaDetailView.vue"
import LoteDetailView from "../views/LoteDetailView.vue"
import { useAuthStore } from "../stores/auth"
import PlantDetailView from "../views/PlantDetailView.vue";

const routes = [
  { path: "/login", name: "login", component: LoginView, meta: { public: true, fullscreen: true } },
  { path: "/", name: "dashboard", component: DashboardView },
  { path: "/salas", name: "salas", component: SalasView },
  { path: "/salas/:id", name: "sala-detail", component: SalaDetailView, props: (route) => ({ id: Number(route.params.id) }) },
  /*{ path: "/lotes", name: "lotes", component: LotesView },*/
  { path: "/lotes/:id", name: "lote-detail", component: LoteDetailView, props: true },
  { path: "/plantas/:id", name: "plant-detail", component: PlantDetailView, props: true },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.afterEach((to) => {
  // Clase para estilos especiales de login
  document.documentElement.classList.toggle('route-login', !!to.meta.fullscreen)
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  // si todavía no sabemos el estado, intentamos recuperar sesión
  if (auth.user === null && to.meta.requiresAuth) {
    await auth.fetchMe()
  }
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  if (to.path === '/login' && auth.isAuthenticated) {
    return { path: '/' }
  }
})

export default router

