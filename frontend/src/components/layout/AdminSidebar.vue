<template>
  <AppSidebarGroups :home="HOME" :groups="GRUPOS" role="admin" />
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import AppSidebarGroups from './AppSidebarGroups.vue'
import {
  LayoutDashboard, Users, Building2, Wallet, CheckSquare,
  Sprout, FileCheck, FileText, UserCog, Globe,
  ShieldCheck, Truck, TrendingUp, History,
  GitBranch, Layers, Dna, Archive, Leaf, Boxes, Scissors,
  ClipboardList, Package, Settings, Scale, Webhook, BellRing, BookmarkCheck,
} from 'lucide-vue-next'
import { listLotes, listPesajesManicuraAdmin } from '../../lib/api.js'

const route = useRoute()

const HOME = { to: '/', icon: LayoutDashboard, label: 'Dashboard' }

// Badge de Manicura: pesajes esperando confirmación + lotes del flujo anterior.
const aprobacionesPendientes = ref(0)
async function fetchAprobaciones() {
  try {
    const [lotes, pesajes] = await Promise.all([
      listLotes({ estado: 'manicura_pendiente' }),
      listPesajesManicuraAdmin().catch(() => ({ data: [] })),
    ])
    aprobacionesPendientes.value = (lotes.data || []).length + (pesajes.data || []).length
  } catch {}
}

const GRUPOS = computed(() => [
  {
    label: 'Cultivo', icon: Sprout, defaultOpen: true,
    items: [
      { to: '/salas',     icon: Layers,  label: 'Salas' },
      { to: '/lotes',     icon: Archive, label: 'Lotes' },
      { to: '/plantas',   icon: Leaf,    label: 'Plantas' },
      { to: '/geneticas', icon: Dna,     label: 'Genéticas' },
    ],
  },
  {
    label: 'Pacientes', icon: Users, defaultOpen: true,
    items: [
      { to: '/pacientes',         icon: Users,     label: 'Pacientes' },
      { to: '/historial',         icon: History,   label: 'Dispensaciones' },
      { to: '/informe-semestral', icon: FileCheck, label: 'REPROCANN' },
    ],
  },
  {
    label: 'Operaciones', icon: Package, defaultOpen: true,
    items: [
      { to: '/admin/stock',            icon: Boxes,         label: 'Stock' },
      { to: '/admin/cosechado',        icon: Scissors,      label: 'Cosecha', hint: 'Lotes cosechados, esperando manicura' },
      { to: '/admin/pesajes-manicura', icon: Scale,         label: 'Manicura', badge: aprobacionesPendientes.value },
      { to: '/reservas',               icon: BookmarkCheck, label: 'Reservas' },
      { to: '/delivery/despachos',     icon: Truck,         label: 'Despachos' },
      { to: '/contabilidad',           icon: Wallet,        label: 'Contabilidad' },
    ],
  },
  {
    label: 'Planificación', icon: ClipboardList, defaultOpen: true,
    items: [
      { to: '/tareas',       icon: CheckSquare,   label: 'Tareas' },
      { to: '/plan-trabajo', icon: ClipboardList, label: 'Plan de trabajo' },
    ],
  },
  {
    label: 'Infraestructura', icon: Building2, defaultOpen: false,
    items: [
      { to: '/sedes', icon: Building2, label: 'Sedes' },
    ],
  },
  {
    label: 'Compliance', icon: ShieldCheck, defaultOpen: false,
    items: [
      { to: '/auditor',              icon: ShieldCheck, label: 'Auditoría' },
      { to: '/auditor/trazabilidad', icon: GitBranch,   label: 'Trazabilidad' },
      { to: '/ariccame',             icon: ShieldCheck, label: 'ARICCAME' },
      { to: '/documentos',           icon: FileText,    label: 'Documentos' },
    ],
  },
  {
    label: 'Analytics', icon: TrendingUp, defaultOpen: false,
    items: [
      { to: '/analitica', icon: TrendingUp, label: 'Analítica' },
    ],
  },
  {
    label: 'Configuración', icon: Settings, defaultOpen: false,
    items: [
      { to: '/configuracion',         icon: Settings, label: 'General' },
      { to: '/alertas-configuracion', icon: BellRing, label: 'Alertas' },
      { to: '/web',                   icon: Globe,    label: 'Sitio web' },
      { to: '/integraciones',         icon: Webhook,  label: 'Integraciones' },
      { to: '/usuarios',              icon: UserCog,  label: 'Equipo' },
    ],
  },
])

onMounted(fetchAprobaciones)

watch(() => route.path, (path, prev) => {
  const rutasManicura = ['/aprobaciones', '/admin/pesajes-manicura']
  if (rutasManicura.includes(prev) || rutasManicura.includes(path)) fetchAprobaciones()
})
</script>
