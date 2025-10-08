import { createRouter, createWebHistory } from "vue-router"
import { useAuthStore } from "../stores/auth"

const Login = () => import("../views/LoginView.vue")
const Dashboard = () => import("../views/DashboardView.vue")
const Salas = () => import("../views/SalasView.vue")
const Lotes = () => import("../views/LotesView.vue")

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", name: "login", component: Login },
    { path: "/", name: "dashboard", component: Dashboard, meta: { requiresAuth: true } },
    { path: "/salas", name: "salas", component: Salas, meta: { requiresAuth: true } },
    { path: "/lotes", name: "lotes", component: Lotes, meta: { requiresAuth: true } },
  ]
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (auth.user === null && to.meta.requiresAuth) {
    if (!auth.loading) await auth.fetchMe()
    if (!auth.user) return { name: "login" }
  }
})

export default router
