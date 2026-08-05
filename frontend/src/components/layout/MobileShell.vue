<template>
  <div class="msh" :class="`msh--${role}`">

    <!-- Top bar -->
    <header class="msh__top">
      <div class="msh__brand">
        <button v-if="isDetalle" class="msh__icon-btn" @click="router.back()" aria-label="Volver">
          <i class="bi bi-chevron-left"></i>
        </button>
        <template v-else>
          <img v-if="club.data?.logo_url" :src="club.data.logo_url" class="msh__logo" alt="" />
          <span v-else class="msh__logo-text">{{ clubInitials }}</span>
          <div class="msh__brand-txt">
            <span class="msh__club-name">{{ club.data?.name || 'Cultivo' }}</span>
            <span class="msh__role">{{ roleLabel }}</span>
          </div>
        </template>
      </div>
      <button class="msh__icon-btn" aria-label="Cuenta" @click="menuOpen = !menuOpen">
        <i class="bi bi-person-circle"></i>
      </button>

      <!-- El ícono suelto de salir no se encontraba: ahora hay un menú con el nombre del usuario y
           la acción escrita. -->
      <Transition name="msh-menu">
        <div v-if="menuOpen" class="msh__menu" @click.self="menuOpen = false">
          <div class="msh__menu-card">
            <div class="msh__menu-user">
              <strong>{{ auth.displayName || auth.user?.email }}</strong>
              <span>{{ roleLabel }}</span>
            </div>
            <button class="msh__menu-item" @click="irPerfil">
              <i class="bi bi-person"></i> Mi perfil
            </button>
            <button class="msh__menu-item msh__menu-item--danger" @click="doLogout">
              <i class="bi bi-box-arrow-right"></i> Cerrar sesión
            </button>
          </div>
        </div>
      </Transition>
    </header>

    <!-- Contenido -->
    <main class="msh__main">
      <RouterView v-slot="{ Component }">
        <Transition name="msh-page" mode="out-in">
          <component :is="Component" />
        </Transition>
      </RouterView>
    </main>

    <!-- Bottom nav -->
    <nav class="msh__nav" :class="{ 'msh__nav--fab': showFab }">
      <template v-if="showFab">
        <RouterLink
          v-for="item in navLeft" :key="item.to"
          :to="item.to" class="msh__tab" :class="{ 'msh__tab--active': isActive(item) }"
        >
          <i class="bi msh__tab-icon" :class="item.icon"></i>
          <span class="msh__tab-label">{{ item.label }}</span>
        </RouterLink>

        <button class="msh__fab" @click="fabOpen = true" aria-label="Acciones rápidas">
          <i class="bi bi-plus-lg"></i>
        </button>

        <RouterLink
          v-for="item in navRight" :key="item.to"
          :to="item.to" class="msh__tab" :class="{ 'msh__tab--active': isActive(item) }"
        >
          <i class="bi msh__tab-icon" :class="item.icon"></i>
          <span class="msh__tab-label">{{ item.label }}</span>
        </RouterLink>
      </template>

      <template v-else>
        <RouterLink
          v-for="item in navVisibles" :key="item.to"
          :to="item.to" class="msh__tab" :class="{ 'msh__tab--active': isActive(item) }"
        >
          <i class="bi msh__tab-icon" :class="item.icon"></i>
          <span class="msh__tab-label">{{ item.label }}</span>
        </RouterLink>
      </template>

      <!-- Lo que no entra en la barra. No se pierde: se llega en dos toques. -->
      <button v-if="navOverflow.length" class="msh__tab" :class="{ 'msh__tab--active': masActivo }"
              @click="masOpen = true">
        <i class="bi msh__tab-icon bi-three-dots"></i>
        <span class="msh__tab-label">Más</span>
      </button>
    </nav>

    <MobileSheet v-model="masOpen" title="Más secciones">
      <div class="msh__mas">
        <button v-for="item in navOverflow" :key="item.to" class="msh__mas-item" @click="irA(item)">
          <i class="bi" :class="item.icon"></i>
          <span>{{ item.label }}</span>
          <i class="bi bi-chevron-right msh__mas-arr"></i>
        </button>
      </div>
    </MobileSheet>

    <!-- FAB → hoja de acciones rápidas -->
    <MobileSheet v-model="fabOpen" title="Crear">
      <MobileActionGrid :actions="fabActions" />
    </MobileSheet>

    <!-- Modales de creación reutilizados del desktop -->
    <NuevoLoteModal :show="showNuevoLote" :salas="salas" @close="showNuevoLote = false" @created="onCreado" />
    <ModalCrearSala v-if="showNuevaSala" @close="showNuevaSala = false" @created="onCreado" />
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'
import { useClubStore }  from '../../stores/club'
import { usePushNotifications } from '../../composables/usePushNotifications.js'
import { useToast } from '../../composables/useToast.js'
import { listSalas } from '../../lib/api.js'
import MobileSheet from '../mobile/MobileSheet.vue'
import MobileActionGrid from '../mobile/MobileActionGrid.vue'
import NuevoLoteModal from '../lotes/NuevoLoteModal.vue'
import ModalCrearSala from '../salas/ModalCrearSala.vue'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()
const toast  = useToast()

const role = computed(() => auth.user?.role || '')

const ROLE_LABELS = {
  admin: 'Administración', supervisor: 'Supervisión', cultivador: 'Cultivo',
  manicura: 'Manicura', delivery: 'Delivery', dispensador: 'Dispensa',
}
const roleLabel = computed(() => ROLE_LABELS[role.value] || '')

const isDetalle = computed(() =>
  /\/m\/(sede|sala-m|lote-m|planta|mnc\/lotes)\//.test(route.path)
)

const clubInitials = computed(() => {
  const n = club.data?.name || 'CE'
  return n.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase()
})

// ── Navegación por rol ──────────────────────────────────────────
const NAV = {
  // El cultivador es el que MÁS escanea —es lo primero que hace al entrar a una sala—, pero el
  // botón vivía solo en el FAB de admin y en el detalle de un lote: no tenía cómo llegar.
  cultivador: { fab: true, items: [
    { to: '/m/cultivador/sedes',  icon: 'bi-diagram-3',     label: 'Cultivo' },
    { to: '/m/scan',              icon: 'bi-qr-code-scan',  label: 'Escanear' },
    { to: '/m/cultivador/tareas', icon: 'bi-check2-square', label: 'Tareas' },
    // A la planta suelta se llega escaneando su QR o desde su lote, que es como se trabaja en la
    // sala; una lista de todas las plantas en el teléfono no se usa. Genéticas es material de
    // consulta de escritorio. Queda "Mis horas", que sí se marca de pie.
    { to: '/m/horas',             icon: 'bi-clock-history', label: 'Mis horas' },
  ] },
  // El admin en el celular NO administra: mira cómo va el día y desbloquea lo que traba a otros.
  // Lo de escritorio —contabilidad, informes, configuración— no se bloquea (si lo necesita abre
  // Chrome y tiene la app entera), simplemente no ocupa la barra.
  admin: { fab: true, items: [
    { to: '/m/admin/home',    icon: 'bi-grid-1x2',      label: 'Inicio'  },
    { to: '/m/admin/sedes',   icon: 'bi-diagram-3',     label: 'Cultivo' },
    { to: '/m/admin/aprobar', icon: 'bi-patch-check',   label: 'Aprobar' },
    { to: '/m/admin/tareas',  icon: 'bi-check2-square', label: 'Tareas'  },
    { to: '/m/historial',     icon: 'bi-clock-history', label: 'Dispensas' },
    { to: '/m/pacientes',     icon: 'bi-people',        label: 'Pacientes' },
    { to: '/m/plantas',       icon: 'bi-flower1',       label: 'Plantas' },
  ] },
  manicura: { items: [
    { to: '/m/manicura/pesar',      icon: 'bi-scissors',        label: 'Por pesar'  },
    { to: '/m/manicura/pesajes',    icon: 'bi-journal-check',   label: 'Pesajes'    },
    { to: '/m/manicura/aprobacion', icon: 'bi-hourglass-split', label: 'Aprobación' },
    { to: '/m/horas',               icon: 'bi-clock-history',   label: 'Horas'      },
    { to: '/m/manicura/tareas',     icon: 'bi-check2-square',   label: 'Tareas'     },
  ] },
  delivery: { items: [
    { to: '/m/delivery/despachos', icon: 'bi-truck',         label: 'Despachos' },
    { to: '/m/delivery/historial', icon: 'bi-clock-history', label: 'Historial' },
  ] },
  // El dispensador trabaja de pie con alguien enfrente: la primera pantalla es buscar y dispensar,
  // no un dashboard. El Salón aparece solo si el club tiene el módulo activo — es el mismo puesto
  // físico, así que no tiene sentido mandarlo al escritorio para cobrar un café.
  // NO hay tab "Pacientes": la lista completa ya está en Dispensar, con buscador y escaneo del
  // carnet. Tenerla dos veces obligaba a decidir por cuál entrar para hacer lo mismo.
  dispensador: { items: [
    { to: '/m/dispensar', icon: 'bi-bag-plus',       label: 'Dispensar' },
    { to: '/m/reservas',  icon: 'bi-bookmark-check', label: 'Reservas' },
    { to: '/m/stock',     icon: 'bi-boxes',          label: 'Stock' },
    { to: '/m/historial', icon: 'bi-clock-history',  label: 'Historial' },
    { to: '/m/horas',     icon: 'bi-stopwatch',      label: 'Mis horas' },
  ] },
}
NAV.supervisor = NAV.admin

const navItems = computed(() => {
  const base = NAV[role.value]?.items || []
  if (role.value === 'dispensador' && club.data?.features?.bar) {
    return [...base, { to: '/bar', icon: 'bi-cup-hot', label: 'Buffet' }]
  }
  return base
})

// La barra inferior aguanta 4 destinos legibles; con más, las etiquetas se cortan y se pierde el
// pulgar. Los primeros van a la barra y el resto a un sheet "Más" — accesible, fuera del camino.
// Es el mismo mecanismo para todos los roles: no hay una lista aparte que se desincronice.
const MAX_TABS = 4
const navVisibles = computed(() => {
  const items = navItems.value
  const tope  = showFab.value ? MAX_TABS : MAX_TABS + 1
  return items.length > tope ? items.slice(0, tope - 1) : items
})
const navOverflow = computed(() => {
  const items = navItems.value
  const tope  = showFab.value ? MAX_TABS : MAX_TABS + 1
  return items.length > tope ? items.slice(tope - 1) : []
})
const masOpen = ref(false)
const masActivo = computed(() => navOverflow.value.some(i => isActive(i)))
function irA(item) { masOpen.value = false; router.push(item.to) }
const showFab  = computed(() => !!NAV[role.value]?.fab)
// Con FAB, repartimos las tabs a cada lado del botón central.
const navLeft  = computed(() => navVisibles.value.slice(0, 2))
const navRight = computed(() => navVisibles.value.slice(2))

watch(() => route.path, () => { menuOpen.value = false })

function isActive(item) {
  return route.path === item.to || route.path.startsWith(item.to + '/')
}

// ── FAB: acciones de creación ───────────────────────────────────
const menuOpen = ref(false)
function irPerfil() { menuOpen.value = false; router.push('/perfil') }

const fabOpen      = ref(false)
const showNuevoLote = ref(false)
const showNuevaSala = ref(false)
const salas        = ref([])

// Crear una SALA es decisión de infraestructura, no del que está en el pasillo: el cultivador crea
// lotes, no cuartos.
// "Registrar" se leía como "anotar algo de un lote que ya existe", cuando en realidad ABRE EL ALTA.
// Y escanear no va acá para el cultivador: ya tiene su propia tab, repetirlo en el botón de crear
// mezcla dos cosas distintas (crear vs. buscar).
const fabActions = computed(() => {
  const esCultivador = role.value === 'cultivador'
  const acciones = [
    { key: 'lote', label: 'Crear lote', icon: 'bi-box-seam',
      tint: 'var(--c-leaf-100)', color: 'var(--c-leaf-700)', onClick: abrirNuevoLote },
  ]
  // Crear una SALA es decisión de infraestructura, no del que está en el pasillo.
  if (!esCultivador) {
    acciones.push({ key: 'sala', label: 'Crear sala', icon: 'bi-grid-3x3-gap',
                    tint: 'var(--c-sky-100)', color: 'var(--c-sky-600)', onClick: abrirNuevaSala })
    acciones.push({ key: 'scan', label: 'Escanear QR', icon: 'bi-qr-code-scan',
                    tint: '#ede9fe', color: '#7c3aed', onClick: irEscanear })
  }
  return acciones
})

function irEscanear() {
  fabOpen.value = false
  router.push('/m/scan')
}

async function abrirNuevoLote() {
  fabOpen.value = false
  try { const { data } = await listSalas(); salas.value = data || [] } catch { salas.value = [] }
  showNuevoLote.value = true
}
function abrirNuevaSala() {
  fabOpen.value = false
  showNuevaSala.value = true
}
function onCreado() {
  showNuevoLote.value = false
  showNuevaSala.value = false
  toast.success('Creado ✓')
}

async function doLogout() {
  await auth.logOut?.()
  router.replace('/login')
}

// ── Push (sin cambios de comportamiento) ────────────────────────
const { supported: pushSupported, subscribed: pushSubscribed, subscribe: pushSubscribe } = usePushNotifications()
onMounted(() => {
  const key = `push_asked_${auth.user?.id || 'u'}`
  if (!pushSupported || localStorage.getItem(key)) return
  setTimeout(async () => {
    if (pushSubscribed.value) return
    const granted = await pushSubscribe()
    if (granted !== false) localStorage.setItem(key, '1')
  }, 4000)
})
</script>

<style scoped>
/* Acento por rol */
.msh--cultivador  { --msh-accent: #16a34a; --msh-top-bg: #0F2A1E; }
.msh--admin       { --msh-accent: #2D7D46; --msh-top-bg: #0F2A1E; }
.msh--supervisor  { --msh-accent: #2D7D46; --msh-top-bg: #0F2A1E; }
.msh--manicura    { --msh-accent: #8b5cf6; --msh-top-bg: #1c1028; }
.msh--delivery    { --msh-accent: #ea580c; --msh-top-bg: #1c0a00; }
.msh--dispensador { --msh-accent: #0ea5e9; --msh-top-bg: #072a3d; }
/* Red de seguridad: un rol sin acento propio dejaba el header SIN FONDO, y el botón de cerrar
   sesión —blanco— quedaba invisible sobre claro. Le pasó al dispensador al sumarlo al shell. */
.msh { --msh-accent: #2D7D46; --msh-top-bg: #0F2A1E; }

.msh {
  display: flex; flex-direction: column;
  min-height: 100dvh;
  background: var(--c-paper, #f4f8f5);
  font-family: var(--font-ui, system-ui, sans-serif);
}

/* ── Top bar ── */
.msh__top {
  position: sticky; top: 0; z-index: 50;
  background: var(--msh-top-bg);
  display: flex; align-items: center; justify-content: space-between;
  gap: .5rem;
  padding: .65rem .9rem;
  padding-top: calc(.65rem + env(safe-area-inset-top));
  box-shadow: 0 1px 0 rgba(255,255,255,.04), 0 6px 20px rgba(15,42,30,.18);
}
.msh__brand { display: flex; align-items: center; gap: .6rem; min-width: 0; }
.msh__logo { width: 36px; height: 36px; border-radius: 10px; object-fit: cover; flex-shrink: 0; }
.msh__logo-text {
  width: 36px; height: 36px; border-radius: 10px;
  background: var(--msh-accent); color: #fff;
  font-size: .85rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.msh__brand-txt { display: flex; flex-direction: column; min-width: 0; line-height: 1.15; }
.msh__club-name {
  font-family: var(--font-display, sans-serif);
  font-size: .95rem; font-weight: 700; color: #fff;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.msh__role { font-size: .66rem; font-weight: 600; color: rgba(255,255,255,.55); letter-spacing: .03em; }
.msh__mas { display: flex; flex-direction: column; }
.msh__mas-item {
  display: flex; align-items: center; gap: .7rem; width: 100%;
  background: none; border: none; border-bottom: 1px solid #f1f5f9;
  padding: .85rem .25rem; cursor: pointer; font: inherit; font-size: .9rem;
  color: #334155; text-align: left;
}
.msh__mas-item:last-child { border-bottom: none; }
.msh__mas-item > span { flex: 1; }
.msh__mas-arr { color: #cbd5e1; }

.msh__menu {
  position: fixed; inset: 0; z-index: 60; background: rgba(15,23,42,.35);
  display: flex; justify-content: flex-end; align-items: flex-start;
  padding: calc(3.4rem + env(safe-area-inset-top)) .75rem 0;
}
.msh__menu-card {
  background: #fff; border-radius: 14px; min-width: 210px; overflow: hidden;
  box-shadow: 0 12px 32px rgba(15,23,42,.24);
}
.msh__menu-user {
  display: flex; flex-direction: column; gap: .1rem;
  padding: .75rem .9rem; border-bottom: 1px solid #f1f5f9;
}
.msh__menu-user strong { font-size: .88rem; color: #1e293b; }
.msh__menu-user span   { font-size: .72rem; color: #94a3b8; }
.msh__menu-item {
  display: flex; align-items: center; gap: .55rem; width: 100%;
  background: none; border: none; padding: .7rem .9rem; cursor: pointer;
  font: inherit; font-size: .85rem; color: #475569; text-align: left;
}
.msh__menu-item:active { background: #f8fafc; }
.msh__menu-item--danger { color: #dc2626; border-top: 1px solid #f1f5f9; }
.msh-menu-enter-active, .msh-menu-leave-active { transition: opacity .15s; }
.msh-menu-enter-from, .msh-menu-leave-to { opacity: 0; }

.msh__icon-btn {
  flex-shrink: 0;
  width: 38px; height: 38px; border-radius: 11px;
  background: rgba(255,255,255,.1); border: none; color: rgba(255,255,255,.85);
  display: flex; align-items: center; justify-content: center;
  font-size: 1.1rem; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
  transition: background .15s, color .15s;
}
.msh__icon-btn:hover { background: rgba(255,255,255,.2); color: #fff; }
.msh__icon-btn:active { transform: scale(.94); }

/* ── Main ── */
.msh__main {
  flex: 1;
  overflow-y: auto;
  padding-bottom: calc(72px + env(safe-area-inset-bottom));
}

/* Transición de página */
.msh-page-enter-active, .msh-page-leave-active { transition: opacity .18s ease, transform .18s ease; }
.msh-page-enter-from { opacity: 0; transform: translateY(6px); }
.msh-page-leave-to   { opacity: 0; transform: translateY(-4px); }

/* ── Bottom nav ── */
.msh__nav {
  position: fixed; bottom: 0; left: 0; right: 0; z-index: 50;
  background: rgba(255,255,255,.92);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-top: 1px solid var(--c-leaf-100, #e8eae8);
  display: flex; align-items: stretch;
  padding-bottom: env(safe-area-inset-bottom);
  box-shadow: 0 -2px 16px rgba(15,42,30,.08);
}
.msh__tab {
  flex: 1;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: .15rem; padding: .5rem .25rem .45rem;
  text-decoration: none; color: #9aa39c;
  transition: color .15s; position: relative;
  -webkit-tap-highlight-color: transparent;
}
.msh__tab-icon { font-size: 1.28rem; line-height: 1; }
.msh__tab-label { font-size: .62rem; font-weight: 600; letter-spacing: .01em; }
.msh__tab--active { color: var(--msh-accent); }
.msh__tab--active::before {
  content: ''; position: absolute; top: 0; left: 28%; right: 28%;
  height: 3px; background: var(--msh-accent); border-radius: 0 0 4px 4px;
}

/* ── FAB central ── */
.msh__fab {
  flex-shrink: 0;
  width: 60px; height: 60px;
  margin: -22px .55rem 0;
  align-self: flex-start;
  border-radius: 50%; border: 4px solid var(--c-paper, #f4f8f5);
  background: var(--msh-accent); color: #fff;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.5rem; cursor: pointer;
  box-shadow: 0 6px 18px rgba(45,125,70,.45);
  -webkit-tap-highlight-color: transparent;
  transition: transform .15s ease, box-shadow .15s ease;
}
.msh__fab:active { transform: scale(.92); }
.msh__fab:hover { box-shadow: 0 8px 22px rgba(45,125,70,.55); }
</style>
