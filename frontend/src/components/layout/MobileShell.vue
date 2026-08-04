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
      <button class="msh__icon-btn" @click="doLogout" aria-label="Cerrar sesión">
        <i class="bi bi-box-arrow-right"></i>
      </button>
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
          v-for="item in navItems" :key="item.to"
          :to="item.to" class="msh__tab" :class="{ 'msh__tab--active': isActive(item) }"
        >
          <i class="bi msh__tab-icon" :class="item.icon"></i>
          <span class="msh__tab-label">{{ item.label }}</span>
        </RouterLink>
      </template>
    </nav>

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
import { computed, onMounted, ref } from 'vue'
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
    { to: '/m/cultivador/tareas', icon: 'bi-check2-square', label: 'Tareas' },
    { to: '/m/scan',              icon: 'bi-qr-code-scan',  label: 'Escanear' },
    { to: '/m/horas',             icon: 'bi-clock-history', label: 'Mis horas' },
  ] },
  admin: { fab: true, items: [
    { to: '/m/admin/home',    icon: 'bi-grid-1x2',     label: 'Inicio'  },
    { to: '/m/admin/sedes',   icon: 'bi-diagram-3',    label: 'Cultivo' },
    { to: '/m/admin/tareas',  icon: 'bi-check2-square', label: 'Tareas' },
    { to: '/m/admin/aprobar', icon: 'bi-patch-check',  label: 'Aprobar' },
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
  dispensador: { items: [
    { to: '/m/dispensar',        icon: 'bi-bag-plus',      label: 'Dispensar' },
    { to: '/m/reservas',         icon: 'bi-bookmark-check', label: 'Reservas' },
    { to: '/m/stock',            icon: 'bi-boxes',         label: 'Stock' },
  ] },
}
NAV.supervisor = NAV.admin

const navItems = computed(() => {
  const base = NAV[role.value]?.items || []
  if (role.value === 'dispensador' && club.data?.features?.bar) {
    return [...base, { to: '/bar', icon: 'bi-cup-hot', label: 'Salón' }]
  }
  return base
})
const showFab  = computed(() => !!NAV[role.value]?.fab)
// Con FAB, repartimos las tabs a cada lado del botón central.
const navLeft  = computed(() => navItems.value.slice(0, 2))
const navRight = computed(() => navItems.value.slice(2))

function isActive(item) {
  return route.path === item.to || route.path.startsWith(item.to + '/')
}

// ── FAB: acciones de creación ───────────────────────────────────
const fabOpen      = ref(false)
const showNuevoLote = ref(false)
const showNuevaSala = ref(false)
const salas        = ref([])

// Crear una SALA es decisión de infraestructura, no del que está en el pasillo: el cultivador crea
// lotes, no cuartos.
const fabActions = computed(() => {
  const acciones = [
    { key: 'lote', label: 'Registrar lote', icon: 'bi-box-seam',
      tint: 'var(--c-leaf-100)', color: 'var(--c-leaf-700)', onClick: abrirNuevoLote },
  ]
  if (role.value !== 'cultivador') {
    acciones.push({ key: 'sala', label: 'Registrar sala', icon: 'bi-grid-3x3-gap',
                    tint: 'var(--c-sky-100)', color: 'var(--c-sky-600)', onClick: abrirNuevaSala })
  }
  acciones.push({ key: 'scan', label: 'Escanear QR', icon: 'bi-qr-code-scan',
                  tint: '#ede9fe', color: '#7c3aed', onClick: irEscanear })
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
