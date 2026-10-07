<template>
  <!-- La barra de la plataforma (7-oct-2026). Antes eran pestañas arriba, como cualquier rol; la
       lateral fija deja ver dónde estás y suma lo que necesita atención (el punto de Estado) sin
       ocupar el ancho de las tablas. En pantallas angostas se vuelve una franja arriba. -->
  <aside class="sasb" aria-label="Super admin">
    <div class="sasb__brand">
      <DsAvatar name="Cultivo Espacial" tone="role-superadmin" size="md" />
      <div class="sasb__brand-txt">
        <span class="sasb__brand-name">Cultivo Espacial</span>
        <span class="sasb__brand-role">Plataforma</span>
      </div>
    </div>

    <nav class="sasb__nav" aria-label="Secciones">
      <RouterLink
        v-for="t in tabs" :key="t.name"
        :to="{ name: t.name }"
        class="sasb__link"
        :class="{ 'sasb__link--on': esActiva(t) }"
        :aria-current="esActiva(t) ? 'page' : undefined"
      >
        <component :is="t.icono" :size="17" :stroke-width="1.75" />
        <span class="sasb__link-txt">{{ t.label }}</span>
        <span v-if="t.name === 'sa-estado' && puntoEstado" class="sasb__punto" :class="`sasb__punto--${puntoEstado}`"
              :title="puntoEstado === 'mal' ? 'Algo no funciona' : 'Hay algo para mirar'"></span>
      </RouterLink>
    </nav>

    <div class="sasb__user">
      <RouterLink :to="{ name: 'sa-perfil' }" class="sasb__user-link">
        <DsAvatar :name="auth.displayName" tone="role-superadmin" size="sm" />
        <span class="sasb__user-txt">
          <span class="sasb__user-name">{{ auth.displayName }}</span>
          <span class="sasb__user-mail">{{ auth.email }}</span>
        </span>
      </RouterLink>
      <button class="sasb__salir" aria-label="Cerrar sesión" title="Cerrar sesión" @click="doLogout">
        <LogOut :size="16" :stroke-width="1.75" />
      </button>
    </div>
  </aside>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import DsAvatar from '../../design-system/components/Avatar.vue'
import { getSuperAdminEstado } from '../../lib/api.js'
import { LayoutDashboard, Building2, Users, Gauge, MessageSquare, FileBarChart, LogOut } from 'lucide-vue-next'

const auth   = useAuthStore()
const route  = useRoute()
const router = useRouter()

const tabs = [
  { name: 'sa-dashboard', label: 'Inicio',         icono: LayoutDashboard, coincide: ['sa-dashboard'] },
  { name: 'sa-clubs',     label: 'Organizaciones', icono: Building2,       coincide: ['sa-clubs', 'sa-club-nuevo', 'sa-club-detail'] },
  { name: 'sa-usuarios',  label: 'Usuarios',       icono: Users,           coincide: ['sa-usuarios'] },
  { name: 'sa-estado',    label: 'Estado',         icono: Gauge,           coincide: ['sa-estado'] },
  { name: 'sa-consultas', label: 'Consultas',      icono: MessageSquare,   coincide: ['sa-consultas'] },
  { name: 'sa-informes',  label: 'Informes',       icono: FileBarChart,    coincide: ['sa-informes'] },
]
// La ficha y el alta de una organización son parte de «Organizaciones».
function esActiva(t) { return t.coincide.includes(route.name) }

// El punto de Estado: se pide una vez al entrar. Si falla, no se muestra nada (no es una alarma).
const puntoEstado = ref(null)
onMounted(async () => {
  try {
    const { data } = await getSuperAdminEstado()
    puntoEstado.value = ['mal', 'atencion'].includes(data?.estado) ? data.estado : null
  } catch { /* sin punto */ }
})

async function doLogout() {
  await auth.logOut()
  router.replace('/login')
}
</script>

<style scoped>
.sasb {
  width: 240px; flex-shrink: 0; background: var(--c-role-superadmin); color: var(--c-leaf-100);
  display: flex; flex-direction: column; gap: 1rem; padding: 1.1rem .8rem;
  position: sticky; top: 0; height: 100vh; box-sizing: border-box;
}
.sasb__brand { display: flex; align-items: center; gap: .6rem; padding: 0 .4rem .4rem; }
.sasb__brand-txt { display: flex; flex-direction: column; line-height: 1.15; min-width: 0; }
.sasb__brand-name { font-size: .9rem; font-weight: 700; color: #fff; white-space: nowrap; }
.sasb__brand-role { font-size: .64rem; font-weight: 600; text-transform: uppercase; letter-spacing: .07em; color: var(--c-leaf-300); }
.sasb__nav { display: flex; flex-direction: column; gap: .15rem; }
.sasb__link {
  display: flex; align-items: center; gap: .65rem; padding: .6rem .75rem; border-radius: 10px;
  color: var(--c-leaf-100); text-decoration: none; font-size: .88rem; font-weight: 500;
  transition: background .15s;
}
.sasb__link:hover { background: rgba(255,255,255,.08); }
.sasb__link--on { background: var(--c-leaf-800); color: #fff; font-weight: 700; }
.sasb__link-txt { flex: 1; }
.sasb__punto { width: 9px; height: 9px; border-radius: 9px; }
.sasb__punto--atencion { background: var(--c-amber-500); }
.sasb__punto--mal { background: var(--c-rust-600); }
.sasb__user { margin-top: auto; display: flex; align-items: center; gap: .4rem; border-top: 1px solid rgba(255,255,255,.1); padding-top: .8rem; }
.sasb__user-link { flex: 1; min-width: 0; display: flex; align-items: center; gap: .55rem; color: #fff; text-decoration: none; padding: .3rem .35rem; border-radius: 8px; }
.sasb__user-link:hover { background: rgba(255,255,255,.08); }
.sasb__user-txt { display: flex; flex-direction: column; min-width: 0; }
.sasb__user-name { font-size: .8rem; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sasb__user-mail { font-size: .68rem; color: var(--c-leaf-300); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sasb__salir { width: 36px; height: 36px; border-radius: 9px; border: 0; background: transparent; color: var(--c-leaf-300); cursor: pointer; display: flex; align-items: center; justify-content: center; }
.sasb__salir:hover { background: rgba(255,255,255,.1); color: #fff; }

/* Angosto: franja arriba, con las secciones que se deslizan. */
@media (max-width: 900px) {
  .sasb { width: 100%; height: auto; position: sticky; top: 0; z-index: 50; flex-direction: row; align-items: center; padding: .5rem .75rem; gap: .5rem; }
  .sasb__brand { padding: 0; }
  .sasb__brand-txt { display: none; }
  .sasb__nav { flex-direction: row; overflow-x: auto; flex: 1; min-width: 0; }
  .sasb__link { padding: .5rem .65rem; white-space: nowrap; }
  .sasb__user { margin: 0; border: 0; padding: 0; }
  .sasb__user-txt { display: none; }
}
</style>
