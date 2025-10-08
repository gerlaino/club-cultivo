import { createRouter, createWebHistory } from "vue-router"
import LoginView from "../views/LoginView.vue"
import DashboardView from "../views/DashboardView.vue"
import SalasView from "../views/SalasView.vue"
import LotesView from "../views/LotesView.vue"
import { useAuthStore } from "../stores/auth"

const routes = [
  { path: "/login", name: "login", component: LoginView, meta: { public: true } },
  { path: "/", name: "dashboard", component: DashboardView },
  { path: "/salas", name: "salas", component: SalasView },
  { path: "/lotes", name: "lotes", component: LotesView },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (auth.user === null && to.meta.public !== true) {
    // Intentamos recuperar sesión por cookie
    await auth.fetchMe()
  }
  if (!auth.isAuthenticated && to.meta.public !== true) {
    return { name: "login" }
  }
  if (auth.isAuthenticated && to.name === "login") {
    return { name: "dashboard" }
  }
})

export default router

