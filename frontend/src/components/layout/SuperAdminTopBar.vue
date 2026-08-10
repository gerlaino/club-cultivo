<template>
  <header class="satb">
    <div class="satb__inner">

      <!-- Identidad: acá se administra LA PLATAFORMA, no un club -->
      <div class="satb__brand">
        <DsAvatar name="Cultivo Espacial" tone="role-superadmin" size="md" />
        <div class="satb__brand-txt">
          <span class="satb__brand-name">Cultivo Espacial</span>
          <span class="satb__brand-role">Plataforma</span>
        </div>
      </div>
      <span class="satb__sep" aria-hidden="true"></span>

      <nav class="satb__tabs" aria-label="Secciones">
        <RouterLink
          v-for="t in tabs" :key="t.name"
          :to="{ name: t.name }"
          class="satb__tab"
          :class="{ 'satb__tab--active': esActiva(t) }"
        >
          {{ t.label }}
        </RouterLink>
      </nav>

      <div class="satb__right">
        <DsDropdown v-model="avatarOpen" align="right">
          <template #anchor>
            <button class="satb__avatar-btn" aria-label="Menú de usuario" @click="avatarOpen = !avatarOpen">
              <DsAvatar :name="auth.displayName" tone="role-superadmin" size="sm" />
            </button>
          </template>
          <template #panel>
            <div class="satb__user-panel">
              <div class="satb__user-header">
                <DsAvatar :name="auth.displayName" tone="role-superadmin" size="md" />
                <div class="satb__user-info">
                  <div class="satb__user-name">{{ auth.displayName }}</div>
                  <div class="satb__user-meta">{{ auth.email }}</div>
                </div>
              </div>
              <nav class="satb__user-menu">
                <RouterLink :to="{ name: 'sa-perfil' }" class="satb__user-item" @click="avatarOpen = false">
                  <User :size="15" :stroke-width="1.75" /> Mi perfil
                </RouterLink>
                <div class="satb__user-divider"></div>
                <button class="satb__user-item satb__user-item--danger" @click="doLogout">
                  <LogOut :size="15" :stroke-width="1.75" /> Cerrar sesión
                </button>
              </nav>
            </div>
          </template>
        </DsDropdown>
      </div>

    </div>
  </header>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import DsDropdown from '../../design-system/components/Dropdown.vue'
import DsAvatar   from '../../design-system/components/Avatar.vue'
import { User, LogOut } from 'lucide-vue-next'

const auth   = useAuthStore()
const route  = useRoute()
const router = useRouter()

const avatarOpen = ref(false)

const tabs = [
  { name: 'sa-dashboard', label: 'Panel',    coincide: ['sa-dashboard'] },
  { name: 'sa-clubs',     label: 'Organizaciones',   coincide: ['sa-clubs', 'sa-club-nuevo', 'sa-club-detail'] },
  { name: 'sa-usuarios',  label: 'Usuarios', coincide: ['sa-usuarios'] },
  { name: 'sa-informes',  label: 'Informes', coincide: ['sa-informes'] },
]

// La ficha y el alta de un club son parte de "Clubes": si sólo se comparara la ruta exacta, la
// pestaña se apagaba al entrar a un club y no se sabía dónde estabas parado.
function esActiva(t) { return t.coincide.includes(route.name) }

async function doLogout() {
  avatarOpen.value = false
  await auth.logOut()
  router.replace('/login')
}
</script>

<style scoped>
.satb {
  position: sticky; top: 0; z-index: 50;
  background: var(--c-role-superadmin);
  border-bottom: 1px solid rgba(255, 255, 255, .1);
}
.satb__inner {
  display: flex; align-items: center; gap: .75rem;
  height: 58px; padding: 0 1.25rem;
}

.satb__brand { display: flex; align-items: center; gap: .625rem; min-width: 0; }
.satb__brand-txt { display: flex; flex-direction: column; line-height: 1.15; min-width: 0; }
.satb__brand-name { font-size: .85rem; font-weight: 700; color: #fff; white-space: nowrap; }
.satb__brand-role {
  font-size: .64rem; font-weight: 600; text-transform: uppercase; letter-spacing: .07em;
  color: rgba(255, 255, 255, .5);
}
.satb__sep { width: 1px; height: 26px; background: rgba(255, 255, 255, .15); flex-shrink: 0; }

.satb__tabs { display: flex; align-items: center; gap: .2rem; overflow-x: auto; }
.satb__tab {
  padding: .45rem .8rem; border-radius: 8px;
  font-size: .82rem; font-weight: 600; text-decoration: none; white-space: nowrap;
  color: rgba(255, 255, 255, .65); transition: background .15s, color .15s;
}
.satb__tab:hover { background: rgba(255, 255, 255, .1); color: #fff; }
.satb__tab--active { background: rgba(255, 255, 255, .16); color: #fff; font-weight: 700; }

.satb__right { margin-left: auto; display: flex; align-items: center; gap: .35rem; }
.satb__avatar-btn {
  background: transparent; border: none; padding: .15rem; border-radius: 50%;
  cursor: pointer; display: flex; transition: box-shadow .15s;
}
.satb__avatar-btn:hover { box-shadow: 0 0 0 2px rgba(255, 255, 255, .25); }

/* Menú de usuario — hasta ahora no había ninguno: el logout era un ícono suelto y no existía
   ninguna pantalla donde el super admin se administrara a sí mismo. */
.satb__user-panel { min-width: 232px; padding: .35rem; }
.satb__user-header {
  display: flex; align-items: center; gap: .6rem;
  padding: .6rem .65rem .7rem; border-bottom: 1px solid var(--c-slate-100); margin-bottom: .35rem;
}
.satb__user-info { min-width: 0; }
.satb__user-name { font-size: .82rem; font-weight: 700; color: var(--c-slate-900); }
.satb__user-meta {
  font-size: .7rem; color: var(--c-slate-500);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 160px;
}
.satb__user-menu { display: flex; flex-direction: column; gap: .1rem; }
.satb__user-item {
  display: flex; align-items: center; gap: .55rem; width: 100%;
  padding: .5rem .65rem; border: none; border-radius: 7px; background: transparent;
  font-size: .8rem; font-weight: 500; color: var(--c-slate-700);
  text-align: left; text-decoration: none; cursor: pointer; transition: background .12s;
}
.satb__user-item:hover { background: var(--c-slate-50); }
.satb__user-item--danger { color: #b91c1c; }
.satb__user-item--danger:hover { background: #fef2f2; }
.satb__user-divider { height: 1px; background: var(--c-slate-100); margin: .3rem .35rem; }

@media (max-width: 640px) {
  .satb__brand-txt { display: none; }
  .satb__inner { padding: 0 .75rem; }
}
</style>
