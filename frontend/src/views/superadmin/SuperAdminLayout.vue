<script setup>
import { useAuthStore } from '../../stores/auth'
import { useRouter, useRoute } from 'vue-router'

const auth   = useAuthStore()
const router = useRouter()
const route  = useRoute()

async function doLogout() {
  await auth.logOut()
  router.replace('/login')
}

const navItems = [
  { name: 'sa-dashboard', label: 'Dashboard',  icon: 'bi-speedometer2' },
  { name: 'sa-clubs',     label: 'Clubs',       icon: 'bi-building' },
  { name: 'sa-usuarios',  label: 'Usuarios',    icon: 'bi-people' },
]
</script>

<template>
  <div class="sa-app">

    <!-- Sidebar -->
    <aside class="sa-sidebar">
      <div class="sa-sidebar__brand">
        <div class="sa-brand-icon">CC</div>
        <div>
          <div class="sa-brand-name">Club Cultivo</div>
          <div class="sa-brand-role">Super Admin</div>
        </div>
      </div>

      <nav class="sa-nav">
        <RouterLink
          v-for="item in navItems"
          :key="item.name"
          :to="{ name: item.name }"
          class="sa-nav__item"
          :class="{ 'sa-nav__item--active': route.name === item.name }"
        >
          <i :class="['bi', item.icon]"></i>
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>

      <div class="sa-sidebar__footer">
        <div class="sa-user">
          <div class="sa-user__avatar">{{ auth.user?.first_name?.[0] || 'S' }}</div>
          <div class="sa-user__info">
            <div class="sa-user__name">{{ auth.displayName }}</div>
            <div class="sa-user__email">{{ auth.email }}</div>
          </div>
        </div>
        <button class="sa-logout" @click="doLogout" title="Cerrar sesión">
          <i class="bi bi-box-arrow-right"></i>
        </button>
      </div>
    </aside>

    <!-- Main -->
    <main class="sa-main">
      <router-view />
    </main>

  </div>
</template>

<style scoped>
.sa-app {
  display: flex;
  min-height: 100vh;
  background: #f8fafc;
}

/* Sidebar */
.sa-sidebar {
  width: 240px;
  flex-shrink: 0;
  background: #1b5e20;
  display: flex;
  flex-direction: column;
  position: fixed;
  top: 0; left: 0; bottom: 0;
  z-index: 100;
}

.sa-sidebar__brand {
  display: flex;
  align-items: center;
  gap: .875rem;
  padding: 1.5rem 1.25rem 1.25rem;
  border-bottom: 1px solid rgba(255,255,255,.12);
}
.sa-brand-icon {
  width: 38px; height: 38px;
  border-radius: 10px;
  background: rgba(255,255,255,.15);
  color: #fff;
  font-size: .8rem;
  font-weight: 800;
  display: flex; align-items: center; justify-content: center;
  letter-spacing: .05em;
  flex-shrink: 0;
}
.sa-brand-name { font-size: .875rem; font-weight: 700; color: #fff; }
.sa-brand-role { font-size: .7rem; color: rgba(255,255,255,.55); text-transform: uppercase; letter-spacing: .06em; margin-top: .1rem; }

.sa-nav {
  flex: 1;
  padding: 1rem .75rem;
  display: flex;
  flex-direction: column;
  gap: .2rem;
}
.sa-nav__item {
  display: flex;
  align-items: center;
  gap: .75rem;
  padding: .65rem .875rem;
  border-radius: 9px;
  text-decoration: none;
  color: rgba(255,255,255,.65);
  font-size: .875rem;
  font-weight: 500;
  transition: all .15s;
}
.sa-nav__item i { font-size: 1rem; flex-shrink: 0; }
.sa-nav__item:hover { background: rgba(255,255,255,.1); color: #fff; }
.sa-nav__item--active { background: rgba(255,255,255,.15); color: #fff; font-weight: 700; }

.sa-sidebar__footer {
  padding: 1rem .75rem;
  border-top: 1px solid rgba(255,255,255,.12);
  display: flex;
  align-items: center;
  gap: .5rem;
}
.sa-user { flex: 1; display: flex; align-items: center; gap: .6rem; min-width: 0; }
.sa-user__avatar {
  width: 32px; height: 32px;
  border-radius: 50%;
  background: rgba(255,255,255,.2);
  color: #fff; font-size: .75rem; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.sa-user__name  { font-size: .78rem; font-weight: 600; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sa-user__email { font-size: .68rem; color: rgba(255,255,255,.5); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sa-logout {
  background: transparent; border: none; color: rgba(255,255,255,.5);
  cursor: pointer; padding: .4rem; border-radius: 7px;
  transition: all .15s; flex-shrink: 0; font-size: 1rem;
}
.sa-logout:hover { background: rgba(255,255,255,.1); color: #fff; }

/* Main */
.sa-main {
  margin-left: 240px;
  flex: 1;
  min-height: 100vh;
}
</style>

