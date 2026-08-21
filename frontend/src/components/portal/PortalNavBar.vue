<template>
  <header class="pnb">
    <div class="pnb__inner">
      <RouterLink to="/portal" class="pnb__marca">
        <img v-if="club?.logo_url" :src="club.logo_url" :alt="club.name" class="pnb__logo" />
        <LeafSeal v-else :size="22" class="pnb__hoja" />
        <span class="pnb__nombre">{{ club?.name || 'Mi organización' }}</span>
      </RouterLink>

      <!-- Escritorio -->
      <nav class="pnb__nav" aria-label="Secciones">
        <RouterLink v-for="l in conCuenta" :key="l.to" :to="l.to" class="pnb__link">{{ l.txt }}</RouterLink>
        <span class="pnb__sep" aria-hidden="true"></span>
        <RouterLink v-for="l in DE_LA_ORG" :key="l.to" :to="l.to" class="pnb__link">{{ l.txt }}</RouterLink>
      </nav>

      <button class="pnb__ham" :aria-expanded="abierto" aria-label="Menú" @click="abierto = !abierto">
        <Menu v-if="!abierto" :size="20" :stroke-width="1.75" />
        <X v-else :size="20" :stroke-width="1.75" />
      </button>
    </div>

    <!-- Teléfono -->
    <nav v-if="abierto" class="pnb__movil" aria-label="Secciones">
      <RouterLink v-for="l in conCuenta" :key="l.to" :to="l.to" class="pnb__mlink" @click="abierto = false">{{ l.txt }}</RouterLink>
      <div class="pnb__msep"></div>
      <RouterLink v-for="l in DE_LA_ORG" :key="l.to" :to="l.to" class="pnb__mlink" @click="abierto = false">{{ l.txt }}</RouterLink>
      <RouterLink to="/portal/cuenta" class="pnb__mlink" @click="abierto = false">Mis datos</RouterLink>
      <button class="pnb__msalir" @click="salir">Cerrar sesión</button>
    </nav>
  </header>
</template>

<script setup>
// La barra separa dos cosas que no son lo mismo: lo que es DEL PACIENTE y lo que PUBLICA la
// organización. Sin esa línea en el medio, "Eventos" y "Mis retiros" parecen la misma clase de
// cosa.
//
// Eran ocho entradas —cinco de ellas del boletín— y ahora son cuatro o cinco: lo suyo suelto, y
// todo el boletín detrás de "Mi organización". Un portal de salud tiene pocas secciones; ocho links en la
// barra hacen que ninguno se lea.
//
// "Mi cuenta" aparece sólo si la organización le abrió cuenta corriente: a quien paga siempre al
// contado, una sección con saldo cero le hace creer que debe algo. Sus datos y su contraseña viven
// en /portal/cuenta, que llega desde el menú del teléfono y desde el pie: se entra una vez.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import { Menu, X } from 'lucide-vue-next'
import LeafSeal from '@/design-system/icons/LeafSeal.vue'
import { usePortalClubStore } from '@/stores/portalClub'
import { useAuthStore } from '@/stores/auth'
import { getPortalCuentaCorriente } from '@/lib/portalApi'

const router = useRouter()
const { club } = storeToRefs(usePortalClubStore())

const abierto = ref(false)
const tieneCC = ref(false)

// Lo suyo primero, y la organización al final: es el mismo orden que el inicio.
const MIAS = [
  { to: '/portal',           txt: 'Inicio' },
  { to: '/portal/mi-salud',  txt: 'Mi salud' },
  { to: '/portal/historial', txt: 'Mis retiros' },
]

const conCuenta = computed(() => [
  ...MIAS,
  ...(tieneCC.value ? [{ to: '/portal/cuenta-corriente', txt: 'Mi cuenta' }] : []),
])

const DE_LA_ORG = [{ to: '/portal/organizacion', txt: 'Mi organización' }]

onMounted(async () => {
  try {
    tieneCC.value = (await getPortalCuentaCorriente())?.tiene === true
  } catch { /* si falla, no se ofrece: mejor que un enlace que lleva a un error */ }
})

// Sin esto el paciente entra y no tiene cómo salir: el portal no comparte la barra de la
// organización, que es donde vive el botón del resto de la app.
async function salir() {
  await useAuthStore().logOut()
  router.push('/login')
}
</script>

<style scoped>
.pnb {
  background: var(--p-marca-fuerte);
  position: sticky;
  top: 0;
  z-index: 40;
}

.pnb__inner {
  max-width: 1100px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: var(--sp-4);
  padding: var(--sp-3) var(--sp-4);
}

.pnb__marca {
  display: flex; align-items: center; gap: var(--sp-2);
  text-decoration: none; color: #fff; min-width: 0;
}
.pnb__logo { width: 26px; height: 26px; border-radius: var(--r-pill); object-fit: cover; flex: 0 0 auto; }
.pnb__hoja { color: var(--p-marca-linea); flex: 0 0 auto; }
.pnb__nombre {
  font-family: var(--p-display);
  font-size: var(--fs-16); font-weight: 600; letter-spacing: -.01em;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}

.pnb__nav { display: none; align-items: center; gap: var(--sp-1); margin-left: auto; }
.pnb__link {
  color: rgb(255 255 255 / .72);
  text-decoration: none;
  font-size: var(--fs-13);
  padding: var(--sp-2) var(--sp-3);
  border-radius: var(--r-md);
  transition: color var(--t-fast), background var(--t-fast);
  white-space: nowrap;
}
.pnb__link:hover { color: #fff; }
.pnb__link.router-link-exact-active { color: #fff; background: rgb(255 255 255 / .12); }
.pnb__sep { width: 1px; height: 18px; background: rgb(255 255 255 / .18); margin: 0 var(--sp-2); }

.pnb__ham {
  margin-left: auto; background: none; border: 0; color: rgb(255 255 255 / .8);
  display: flex; align-items: center; cursor: pointer; padding: var(--sp-1);
}

.pnb__movil { padding: 0 var(--sp-4) var(--sp-4); }
.pnb__mlink {
  display: block; color: rgb(255 255 255 / .8); text-decoration: none;
  font-size: var(--fs-16); padding: var(--sp-3) 0;
}
.pnb__mlink.router-link-exact-active { color: #fff; font-weight: 600; }
.pnb__msep { height: 1px; background: rgb(255 255 255 / .15); margin: var(--sp-2) 0; }
.pnb__msalir {
  display: block; width: 100%; text-align: left; background: none; border: 0;
  color: rgb(255 255 255 / .55); font-size: var(--fs-14); padding: var(--sp-3) 0; cursor: pointer;
}

@media (min-width: 860px) {
  .pnb__nav { display: flex; }
  .pnb__ham { display: none; }
  .pnb__movil { display: none; }
}
</style>
