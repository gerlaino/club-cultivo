import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView
    },
    {
      path: '/geneticas',
      name: 'geneticas',
      component: () => import('../views/GeneticasView.vue')
    },
    {
      path: '/geneticas/:id',
      name: 'genetica-detail',
      component: () => import('../views/GeneticaDetailView.vue')
    },
    {
     path: '/noticias',
     name: 'noticias',
     component: () => import('../views/NoticiasView.vue')
    },
    {
     path: '/noticias/:id',
     name: 'noticia-detail',
     component: () => import('../views/NoticiasDetailView.vue')
    },
    {
      path: '/eventos',
      name: 'eventos',
      component: () => import('../views/EventosView.vue')
    },
    {
      path: '/eventos/:id',
      name: 'eventos-detail',
      component: () => import('../views/EventoDetailView.vue')
    },
    {
      path: '/galeria',
      name: 'galeria',
      component: () => import('../views/GaleriaView.vue')
    },
    {
      path: '/contacto',
      name: 'contacto',
      component: () => import('../views/ContactoView.vue')
    }
  ],
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  }
})

export default router
