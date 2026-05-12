<template>
  <aside class="asb">

    <!-- Brand -->
    <div class="asb__brand">
      <LeafSeal :size="24" class="asb__brand-leaf" />
      <span class="asb__brand-name">cultivoespacial</span>
    </div>

    <!-- Nav -->
    <nav class="asb__nav">

      <!-- Dashboard — siempre visible -->
      <RouterLink to="/" class="asb__link" :class="{ 'asb__link--active': route.path === '/' }">
        <LayoutDashboard :size="18" :stroke-width="1.75" class="asb__link-ico" />
        <span>Dashboard</span>
      </RouterLink>

      <!-- Grupos colapsables -->
      <div v-for="grupo in GRUPOS" :key="grupo.label" class="asb__group">

        <button
          class="asb__group-hdr"
          :class="{ 'asb__group-hdr--active': grupoTieneActivo(grupo) }"
          @click="toggleGrupo(grupo.label)"
        >
          <component :is="grupo.icon" :size="15" :stroke-width="1.75" class="asb__group-ico" />
          <span class="asb__group-label">{{ grupo.label }}</span>
          <ChevronDown
            :size="13"
            :stroke-width="2.5"
            class="asb__chevron"
            :class="{ 'asb__chevron--open': abiertos[grupo.label] }"
          />
        </button>

        <div v-show="abiertos[grupo.label]" class="asb__group-items">
          <RouterLink
            v-for="link in grupo.items"
            :key="link.to"
            :to="link.to"
            class="asb__sub"
            :class="{ 'asb__sub--active': isActive(link.to) }"
          >
            <component :is="link.icon" :size="15" :stroke-width="1.75" class="asb__sub-ico" />
            <span>{{ link.label }}</span>
          </RouterLink>
        </div>

      </div>
    </nav>

    <!-- User card -->
    <div class="asb__user">
      <DsAvatar :name="auth.displayName" tone="role-admin" size="sm" />
      <div class="asb__user-info">
        <div class="asb__user-name">{{ auth.displayName }}</div>
        <div class="asb__user-role">Admin · {{ club.name }}</div>
      </div>
      <button class="asb__logout" @click="handleLogout" title="Cerrar sesión">
        <i class="bi bi-box-arrow-right"></i>
      </button>
    </div>

  </aside>
</template>

<script setup>
import { reactive, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth.js'
import { useClubStore } from '../../stores/club.js'
import LeafSeal from '../../design-system/icons/LeafSeal.vue'
import DsAvatar from '../../design-system/components/Avatar.vue'
import {
  LayoutDashboard, Users, Building2, Wallet, CheckSquare,
  Sprout, FileCheck, FileText, UserCog, Globe, ClipboardCheck,
  Container, BarChart3, ShieldCheck, Truck, TrendingUp, History,
  GitBranch, Layers, ChevronDown, Dna, Archive, Leaf, Boxes, Scissors,
} from 'lucide-vue-next'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const club   = useClubStore()

const GRUPOS = [
  {
    label: 'Cultivo',
    icon: Sprout,
    defaultOpen: true,
    items: [
      { to: '/lotes',         icon: Archive,       label: 'Lotes' },
      { to: '/plantas',       icon: Leaf,          label: 'Plantas' },
      { to: '/salas',         icon: Layers,        label: 'Salas' },
      { to: '/geneticas',     icon: Dna,           label: 'Genéticas' },
      { to: '/admin/cosechado', icon: Scissors,      label: 'Cosechado' },
      { to: '/aprobaciones',   icon: ClipboardCheck, label: 'Aprobaciones' },
    ],
  },
  {
    label: 'Pacientes',
    icon: Users,
    defaultOpen: true,
    items: [
      { to: '/pacientes',         icon: Users,      label: 'Lista' },
      { to: '/historial',         icon: History,    label: 'Historial' },
      { to: '/informe-semestral', icon: FileCheck,  label: 'REPROCANN' },
    ],
  },
  {
    label: 'Gestión',
    icon: Building2,
    defaultOpen: false,
    items: [
      { to: '/sedes',              icon: Building2,  label: 'Sedes' },
      { to: '/stock',              icon: Boxes,      label: 'Stock' },
      { to: '/delivery/despachos', icon: Truck,      label: 'Despachos' },
      { to: '/tareas',             icon: CheckSquare, label: 'Tareas' },
      { to: '/contabilidad',       icon: Wallet,     label: 'Contabilidad' },
      { to: '/usuarios',           icon: UserCog,    label: 'Equipo' },
      { to: '/web',                icon: Globe,      label: 'Web' },
    ],
  },
  {
    label: 'Compliance',
    icon: ShieldCheck,
    defaultOpen: false,
    items: [
      { to: '/auditor/trazabilidad', icon: GitBranch, label: 'Trazabilidad' },
      { to: '/ariccame',             icon: ShieldCheck, label: 'ARICCAME' },
      { to: '/documentos',           icon: FileText,  label: 'Documentos' },
    ],
  },
  {
    label: 'Analytics',
    icon: TrendingUp,
    defaultOpen: false,
    items: [
      { to: '/analitica',  icon: TrendingUp, label: 'Analítica' },
      { to: '/benchmark',  icon: BarChart3,  label: 'Benchmark' },
    ],
  },
]

const abiertos = reactive({})

function isActive(to) {
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(to + '/')
}

function grupoTieneActivo(grupo) {
  return grupo.items.some(link => isActive(link.to))
}

function toggleGrupo(label) {
  abiertos[label] = !abiertos[label]
}

function sincronizarGrupos() {
  GRUPOS.forEach(g => {
    if (grupoTieneActivo(g)) abiertos[g.label] = true
  })
}

onMounted(() => {
  GRUPOS.forEach(g => {
    abiertos[g.label] = g.defaultOpen || grupoTieneActivo(g)
  })
})

watch(() => route.path, sincronizarGrupos)

async function handleLogout() {
  await auth.logOut()
  club.$reset()
  router.replace('/login')
}
</script>

<style scoped>
.asb {
  width: 220px;
  flex-shrink: 0;
  background: var(--c-role-admin);
  display: flex;
  flex-direction: column;
  height: 100vh;
  position: sticky;
  top: 0;
  overflow-y: auto;
  overflow-x: hidden;
}

/* Brand */
.asb__brand {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168,201,181,0.15);
  flex-shrink: 0;
}
.asb__brand-leaf { color: var(--c-leaf-300); flex-shrink: 0; }
.asb__brand-name {
  font-family: var(--font-display);
  font-size: var(--fs-16);
  font-weight: 500;
  color: var(--c-paper);
  letter-spacing: -.01em;
}

/* Nav */
.asb__nav {
  flex: 1;
  padding: var(--sp-3) var(--sp-2);
  display: flex;
  flex-direction: column;
  gap: 1px;
  overflow-y: auto;
}

/* Dashboard link — nivel raíz */
.asb__link {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 14px;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 400;
  color: var(--c-leaf-300);
  text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast);
  border-left: 3px solid transparent;
}
.asb__link:hover { background: rgba(255,255,255,0.06); color: var(--c-paper); }
.asb__link--active {
  background: var(--c-leaf-700);
  color: var(--c-paper);
  font-weight: 600;
  border-left-color: var(--c-leaf-300);
}
.asb__link-ico { flex-shrink: 0; }

/* Grupo */
.asb__group { margin-top: 2px; }

.asb__group-hdr {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 14px;
  border-radius: var(--r-md);
  background: none;
  border: none;
  border-left: 3px solid transparent;
  cursor: pointer;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: .06em;
  text-transform: uppercase;
  color: rgba(168,201,181,0.55);
  transition: background var(--t-fast), color var(--t-fast);
  text-align: left;
}
.asb__group-hdr:hover {
  background: rgba(255,255,255,0.04);
  color: rgba(168,201,181,0.85);
}
.asb__group-hdr--active {
  color: var(--c-leaf-200);
}
.asb__group-ico { flex-shrink: 0; }
.asb__group-label { flex: 1; }

.asb__chevron {
  flex-shrink: 0;
  transition: transform .2s ease;
  opacity: .6;
}
.asb__chevron--open { transform: rotate(180deg); }

/* Sub-items */
.asb__group-items {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding-left: var(--sp-2);
  margin-bottom: var(--sp-1);
}

.asb__sub {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 7px 12px 7px 16px;
  border-radius: var(--r-md);
  font-size: var(--fs-13);
  font-weight: 400;
  color: var(--c-leaf-300);
  text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast);
  border-left: 2px solid transparent;
}
.asb__sub:hover { background: rgba(255,255,255,0.06); color: var(--c-paper); }
.asb__sub--active {
  background: var(--c-leaf-700);
  color: var(--c-paper);
  font-weight: 600;
  border-left-color: var(--c-leaf-300);
}
.asb__sub-ico { flex-shrink: 0; opacity: .8; }
.asb__sub--active .asb__sub-ico { opacity: 1; }

/* User card */
.asb__user {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  padding: var(--sp-4) var(--sp-5);
  border-top: 1px solid rgba(168,201,181,0.15);
  flex-shrink: 0;
}
.asb__user-info { flex: 1; min-width: 0; }
.asb__user-name {
  font-size: var(--fs-13);
  font-weight: 600;
  color: var(--c-paper);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.asb__user-role {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--c-leaf-300);
  margin-top: 1px;
}
.asb__logout {
  background: none;
  border: none;
  color: var(--c-leaf-300);
  font-size: var(--fs-16);
  cursor: pointer;
  padding: var(--sp-1);
  border-radius: var(--r-sm);
  transition: color var(--t-fast), background var(--t-fast);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.asb__logout:hover { color: var(--c-paper); background: rgba(255,255,255,0.08); }

@media (max-width: 1023px) { .asb { display: none; } }
</style>
