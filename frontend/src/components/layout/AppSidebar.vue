<template>
  <aside class="sb" :class="{ 'sb--collapsed': collapsed }" :style="{ background: bgColor }">

    <!-- Header: logo + nombre del club -->
    <div class="sb__brand">
      <img :src="logoSrc" class="sb__brand-logo" :alt="club.name" />
      <span class="sb__brand-name">{{ club.name }}</span>
    </div>

    <!-- Nav -->
    <nav class="sb__nav">
      <RouterLink
        v-for="link in links"
        :key="link.to"
        :to="link.to"
        class="sb__link"
        :class="{ 'sb__link--active': isActive(link.to) }"
        :title="collapsed ? link.label : (link.hint || undefined)"
      >
        <component :is="link.icon" :size="18" :stroke-width="1.75" class="sb__link-ico" />
        <span class="sb__label">{{ link.label }}</span>
        <span v-if="badgeValue(link)" class="sb__badge">{{ badgeValue(link) }}</span>
      </RouterLink>
    </nav>

    <!-- Collapse toggle -->
    <button class="sb__collapse-btn" @click="toggleCollapse" :title="collapsed ? 'Expandir menú' : 'Contraer menú'">
      <PanelLeftClose v-if="!collapsed" :size="15" :stroke-width="1.75" />
      <PanelLeftOpen  v-else            :size="15" :stroke-width="1.75" />
    </button>

  </aside>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { useClubStore } from '../../stores/club.js'
import { PanelLeftClose, PanelLeftOpen } from 'lucide-vue-next'

// Sidebar compartido por todos los roles (menos admin, que tiene grupos colapsables).
// Maneja: header con logo+nombre del club, colapsar/expandir, e ítems de navegación.
// El logout NO vive acá — está en el botón de perfil del topbar.
const props = defineProps({
  // [{ to, icon, label, badge?: number|Ref, hint? }]
  links: { type: Array, required: true },
  // 'manicura' | 'medico' | 'abogado' | ... → color de fondo --c-role-*
  role:  { type: String, default: 'admin' },
})

const route = useRoute()
const club  = useClubStore()

const bgColor = computed(() => `var(--c-role-${props.role})`)
const logoSrc = computed(() => club.logoUrl || '/logo-ce-icono.png')

const collapsed = ref(localStorage.getItem('sb-collapsed') === '1')
function toggleCollapse() {
  collapsed.value = !collapsed.value
  localStorage.setItem('sb-collapsed', collapsed.value ? '1' : '0')
}

function isActive(to) {
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(to + '/')
}

function badgeValue(link) {
  const b = link.badge
  if (b == null) return null
  const v = (typeof b === 'object' && 'value' in b) ? b.value : b
  return v && v > 0 ? v : null
}
</script>

<style scoped>
.sb {
  width: 240px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  height: 100vh;
  position: sticky;
  top: 0;
  overflow-x: hidden;
  transition: width .25s cubic-bezier(.4,0,.2,1);
}
.sb--collapsed { width: 54px; }
.sb--collapsed .sb__brand-name,
.sb--collapsed .sb__label,
.sb--collapsed .sb__badge { display: none; }
.sb--collapsed .sb__brand { justify-content: center; padding: 1.1rem .5rem; }
.sb--collapsed .sb__link  { justify-content: center; padding: 10px 0; }
.sb--collapsed .sb__nav   { padding: var(--sp-3) var(--sp-1); }

/* Header club */
.sb__brand {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168,201,181,0.18);
  flex-shrink: 0;
}
.sb__brand-logo { width: 30px; height: 30px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background: rgba(255,255,255,.1); }
.sb__brand-name {
  font-family: var(--font-display);
  font-size: var(--fs-16); font-weight: 500;
  color: var(--c-paper); letter-spacing: -.01em;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}

/* Nav */
.sb__nav {
  flex: 1;
  padding: var(--sp-3) var(--sp-2);
  display: flex; flex-direction: column; gap: 2px;
  overflow-y: auto; scrollbar-width: thin;
}
.sb__link {
  display: flex; align-items: center; gap: 12px;
  padding: 10px 16px; border-radius: var(--r-md);
  font-size: var(--fs-14); font-weight: 400;
  color: rgba(168,201,181,0.7); text-decoration: none;
  transition: background var(--t-fast), color var(--t-fast);
  border-left: 3px solid transparent;
}
.sb__link:hover { background: rgba(255,255,255,0.07); color: var(--c-paper); }
.sb__link--active {
  background: rgba(255,255,255,0.14);
  color: var(--c-paper); font-weight: 600;
  border-left-color: var(--c-leaf-300);
}
.sb__link-ico { flex-shrink: 0; display: flex; }
.sb__badge {
  margin-left: auto; background: #d97706; color: #fff;
  font-size: 10px; font-weight: 700; line-height: 1;
  padding: 2px 6px; border-radius: 10px; min-width: 18px; text-align: center;
}

/* Collapse */
.sb__collapse-btn {
  display: flex; align-items: center; justify-content: center;
  width: 100%; height: 38px; border: none; background: none;
  color: rgba(168,201,181,0.45); cursor: pointer; flex-shrink: 0;
  border-top: 1px solid rgba(168,201,181,0.12);
  transition: color .15s, background .15s;
}
.sb__collapse-btn:hover { color: rgba(168,201,181,0.9); background: rgba(255,255,255,0.05); }

@media (max-width: 1023px) { .sb { display: none; } }
</style>
