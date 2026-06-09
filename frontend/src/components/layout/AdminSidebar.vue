<template>
  <aside class="asb">

    <!-- Brand -->
    <div class="asb__brand">
      <img src="/logo-ce-icono.png" class="asb__brand-logo" alt="Cultivo Espacial" />
      <span class="asb__brand-name">Cultivo Espacial</span>
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
            <span v-if="link.badge?.value" class="asb__sub-badge">{{ link.badge.value }}</span>
          </RouterLink>
        </div>

      </div>
    </nav>

  </aside>
</template>

<script setup>
import { reactive, ref, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  LayoutDashboard, Users, Building2, Wallet, CheckSquare,
  Sprout, FileCheck, FileText, UserCog, Globe,
  ShieldCheck, Truck, TrendingUp, History,
  GitBranch, Layers, ChevronDown, Dna, Archive, Leaf, Boxes, Scissors,
  ClipboardList, Package, Settings, ClipboardCheck, Scale, Webhook, BellRing,
} from 'lucide-vue-next'
import { listLotes } from '../../lib/api.js'

const aprobacionesPendientes = ref(0)

async function fetchAprobaciones() {
  try {
    const { data } = await listLotes({ estado: 'manicura_pendiente' })
    aprobacionesPendientes.value = (data || []).length
  } catch {}
}

const route = useRoute()

const GRUPOS = [
  {
    label: 'Cultivo',
    icon: Sprout,
    defaultOpen: true,
    items: [
      { to: '/salas',     icon: Layers,  label: 'Salas' },
      { to: '/lotes',     icon: Archive, label: 'Lotes' },
      { to: '/plantas',   icon: Leaf,    label: 'Plantas' },
      { to: '/geneticas', icon: Dna,     label: 'Genéticas' },
    ],
  },
  {
    label: 'Pacientes',
    icon: Users,
    defaultOpen: true,
    items: [
      { to: '/pacientes',         icon: Users,     label: 'Pacientes' },
      { to: '/historial',         icon: History,   label: 'Dispensaciones' },
      { to: '/informe-semestral', icon: FileCheck, label: 'REPROCANN' },
    ],
  },
  {
    label: 'Operaciones',
    icon: Package,
    defaultOpen: true,
    items: [
      { to: '/admin/stock',                 icon: Boxes,          label: 'Stock' },
      { to: '/admin/cosechado',             icon: Scissors,       label: 'Post-cosecha' },
      { to: '/aprobaciones',                icon: ClipboardCheck, label: 'Aprobaciones', badge: aprobacionesPendientes },
      { to: '/admin/pesajes-manicura',      icon: Scale,          label: 'Pesajes manicura' },
      { to: '/delivery/despachos', icon: Truck,          label: 'Despachos' },
      { to: '/contabilidad',       icon: Wallet,         label: 'Contabilidad' },
    ],
  },
  {
    label: 'Planificación',
    icon: ClipboardList,
    defaultOpen: true,
    items: [
      { to: '/tareas',       icon: CheckSquare, label: 'Tareas' },
      { to: '/plan-trabajo', icon: ClipboardList, label: 'Plan de trabajo' },
    ],
  },
  {
    label: 'Infraestructura',
    icon: Building2,
    defaultOpen: false,
    items: [
      { to: '/sedes', icon: Building2, label: 'Sedes' },
    ],
  },
  {
    label: 'Compliance',
    icon: ShieldCheck,
    defaultOpen: false,
    items: [
      { to: '/auditor',              icon: ShieldCheck, label: 'Auditoría' },
      { to: '/auditor/trazabilidad', icon: GitBranch,   label: 'Trazabilidad' },
      { to: '/ariccame',             icon: ShieldCheck, label: 'ARICCAME' },
      { to: '/documentos',           icon: FileText,    label: 'Documentos' },
    ],
  },
  {
    label: 'Analytics',
    icon: TrendingUp,
    defaultOpen: false,
    items: [
      { to: '/analitica', icon: TrendingUp, label: 'Analítica' },
    ],
  },
  {
    label: 'Configuración',
    icon: Settings,
    defaultOpen: false,
    items: [
      { to: '/configuracion',          icon: Settings, label: 'General' },
      { to: '/alertas-configuracion',  icon: BellRing, label: 'Alertas' },
      { to: '/web',                    icon: Globe,    label: 'Sitio web' },
      { to: '/integraciones',          icon: Webhook,  label: 'Integraciones' },
      { to: '/usuarios',               icon: UserCog,  label: 'Equipo' },
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
  fetchAprobaciones()
})

watch(() => route.path, (path, prev) => {
  sincronizarGrupos()
  if (prev === '/aprobaciones' || path === '/aprobaciones') fetchAprobaciones()
})
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
.asb__brand-logo { width: 30px; height: 30px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
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
  scrollbar-width: thin;
  scrollbar-color: var(--c-leaf-600) transparent;
}
.asb__nav::-webkit-scrollbar {
  width: 4px;
}
.asb__nav::-webkit-scrollbar-track {
  background: transparent;
}
.asb__nav::-webkit-scrollbar-thumb {
  background: var(--c-leaf-600);
  border-radius: 4px;
}
.asb__nav::-webkit-scrollbar-thumb:hover {
  background: var(--c-leaf-400);
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
.asb__sub-badge {
  margin-left: auto;
  background: #d97706;
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
  padding: 2px 5px;
  border-radius: 10px;
  min-width: 16px;
  text-align: center;
}


@media (max-width: 1023px) { .asb { display: none; } }
</style>
