import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const LoginView        = () => import('@/views/LoginView.vue')
const CultivadorShell  = () => import('@/views/cultivador/CultivadorShell.vue')
const TareasCalendar   = () => import('@/views/cultivador/TareasCalendar.vue')
const SedesView        = () => import('@/views/cultivador/SedesView.vue')
const SedeDetail       = () => import('@/views/cultivador/SedeDetail.vue')
const SalaDetail       = () => import('@/views/cultivador/SalaDetail.vue')
const LoteDetail       = () => import('@/views/cultivador/LoteDetail.vue')
const PlantaDetail     = () => import('@/views/cultivador/PlantaDetail.vue')

const routes = [
  { path: '/', redirect: '/login' },
  { path: '/login', component: LoginView, name: 'login' },
  {
    path: '/cultivador',
    component: CultivadorShell,
    meta: { requiresAuth: true },
    children: [
      { path: '', redirect: 'tareas' },
      { path: 'tareas', component: TareasCalendar, name: 'tareas' },
      { path: 'sedes',  component: SedesView,      name: 'sedes'  },
    ],
  },
  { path: '/sedes/:id',  component: SedeDetail,  name: 'sede-detail',  meta: { requiresAuth: true } },
  { path: '/salas/:id',  component: SalaDetail,  name: 'sala-detail',  meta: { requiresAuth: true } },
  { path: '/lotes/:id',  component: LoteDetail,  name: 'lote-detail',  meta: { requiresAuth: true } },
  { path: '/plantas/:id',component: PlantaDetail,name: 'planta-detail',meta: { requiresAuth: true } },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.jwt) return '/login'
})

export default router
