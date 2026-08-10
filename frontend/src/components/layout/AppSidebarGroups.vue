<template>
  <aside class="sbg" :class="{ 'sbg--collapsed': collapsed }" :style="{ background: bgColor }">

    <!-- Header: marca de plataforma (la organización va en el topbar) -->
    <div class="sbg__brand">
      <img src="/logo-ce-icono.png" class="sbg__brand-logo" alt="Cultivo Espacial" />
      <span class="sbg__brand-name">Cultivo Espacial</span>
    </div>

    <nav class="sbg__nav">
      <!-- Link raíz opcional (Dashboard / Inicio) -->
      <RouterLink
        v-if="home"
        :to="home.to"
        class="sbg__link"
        :class="{ 'sbg__link--active': isActive(home) }"
        :title="collapsed ? home.label : undefined"
      >
        <component :is="home.icon" :size="18" :stroke-width="1.75" class="sbg__link-ico" />
        <span class="sbg__label">{{ home.label }}</span>
      </RouterLink>

      <div v-for="grupo in groups" :key="grupo.label" class="sbg__group">
        <button
          class="sbg__group-hdr"
          :class="{ 'sbg__group-hdr--active': grupoTieneActivo(grupo) }"
          @click="!collapsed && toggleGrupo(grupo.label)"
          :title="collapsed ? grupo.label : undefined"
        >
          <component :is="grupo.icon" :size="15" :stroke-width="1.75" class="sbg__group-ico" />
          <span class="sbg__label sbg__group-label">{{ grupo.label }}</span>
          <ChevronDown v-if="!collapsed" :size="13" :stroke-width="2.5" class="sbg__chevron" :class="{ 'sbg__chevron--open': abiertos[grupo.label] }" />
        </button>

        <div v-show="!collapsed && abiertos[grupo.label]" class="sbg__group-items">
          <RouterLink
            v-for="link in grupo.items"
            :key="link.to"
            :to="link.to"
            class="sbg__sub"
            :class="{ 'sbg__sub--active': isActive(link) }"
            :title="link.hint || undefined"
          >
            <component :is="link.icon" :size="15" :stroke-width="1.75" class="sbg__sub-ico" />
            <span class="sbg__label">{{ link.label }}</span>
            <span v-if="badgeValue(link)" class="sbg__sub-badge">{{ badgeValue(link) }}</span>
          </RouterLink>
        </div>
      </div>
    </nav>

    <button class="sbg__collapse-btn" @click="toggleCollapse" :title="collapsed ? 'Expandir menú' : 'Contraer menú'">
      <PanelLeftClose v-if="!collapsed" :size="15" :stroke-width="1.75" />
      <PanelLeftOpen  v-else            :size="15" :stroke-width="1.75" />
    </button>

  </aside>
</template>

<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { ChevronDown, PanelLeftClose, PanelLeftOpen } from 'lucide-vue-next'

// Sidebar agrupado (estilo admin) reutilizable: header con club, grupos colapsables,
// link raíz opcional y botón de colapsar. Logout NO vive acá (va en el topbar).
const props = defineProps({
  groups: { type: Array, required: true },
  role:   { type: String, default: 'admin' },
  home:   { type: Object, default: null }, // { to, label, icon, exact? }
})

const route = useRoute()

const bgColor = computed(() => `var(--c-role-${props.role})`)

const collapsed = ref(localStorage.getItem('sb-collapsed') === '1')
function toggleCollapse() {
  collapsed.value = !collapsed.value
  localStorage.setItem('sb-collapsed', collapsed.value ? '1' : '0')
}

function isActive(link) {
  const to = link.to
  if (link.exact || to === '/') return route.path === to
  return route.path === to || route.path.startsWith(to + '/')
}
function grupoTieneActivo(grupo) { return grupo.items.some(l => isActive(l)) }

function badgeValue(link) {
  const b = link.badge
  if (b == null) return null
  const v = (typeof b === 'object' && 'value' in b) ? b.value : b
  return v && v > 0 ? v : null
}

const abiertos = reactive({})
function toggleGrupo(label) { abiertos[label] = !abiertos[label] }

onMounted(() => {
  props.groups.forEach(g => { abiertos[g.label] = g.defaultOpen || grupoTieneActivo(g) })
})
watch(() => route.path, () => {
  props.groups.forEach(g => { if (grupoTieneActivo(g)) abiertos[g.label] = true })
})
</script>

<style scoped>
.sbg {
  width: 220px; flex-shrink: 0;
  display: flex; flex-direction: column;
  height: 100vh; height: 100dvh; position: sticky; top: 0;
  padding-bottom: env(safe-area-inset-bottom, 0);
  overflow-x: hidden;
  transition: width .25s cubic-bezier(.4,0,.2,1);
}
.sbg--collapsed { width: 54px; }
.sbg--collapsed .sbg__brand-name,
.sbg--collapsed .sbg__label,
.sbg--collapsed .sbg__sub-badge { display: none; }
.sbg--collapsed .sbg__brand { justify-content: center; padding: 1.1rem .5rem; }
.sbg--collapsed .sbg__link  { justify-content: center; padding: 9px 0; }
.sbg--collapsed .sbg__group-hdr { justify-content: center; padding: 8px 0; }
.sbg--collapsed .sbg__sub   { justify-content: center; padding: 7px 0; }
.sbg--collapsed .sbg__nav   { padding: var(--sp-3) var(--sp-1); }

.sbg__brand {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-5) var(--sp-5) var(--sp-4);
  border-bottom: 1px solid rgba(168,201,181,0.18); flex-shrink: 0;
}
.sbg__brand-logo { width: 30px; height: 30px; border-radius: 50%; object-fit: cover; flex-shrink: 0; background: rgba(255,255,255,.1); }
.sbg__brand-name { font-family: var(--font-display); font-size: var(--fs-16); font-weight: 500; color: var(--c-paper); letter-spacing: -.01em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.sbg__nav { flex: 1; padding: var(--sp-3) var(--sp-2); display: flex; flex-direction: column; gap: 1px; overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgba(168,201,181,0.22) transparent; }
/* Scrollbar fundida con el verde del menú (sin barra gris del navegador). */
.sbg__nav::-webkit-scrollbar { width: 6px; }
.sbg__nav::-webkit-scrollbar-track { background: transparent; }
.sbg__nav::-webkit-scrollbar-thumb { background: rgba(168,201,181,0.22); border-radius: 6px; }
.sbg__nav::-webkit-scrollbar-thumb:hover { background: rgba(168,201,181,0.4); }

.sbg__link { display: flex; align-items: center; gap: 10px; padding: 9px 14px; border-radius: var(--r-md); font-size: var(--fs-13); color: var(--c-leaf-300); text-decoration: none; transition: background var(--t-fast), color var(--t-fast); border-left: 3px solid transparent; }
.sbg__link:hover { background: rgba(255,255,255,0.06); color: var(--c-paper); }
.sbg__link--active { background: rgba(255,255,255,0.14); color: var(--c-paper); font-weight: 600; border-left-color: var(--c-leaf-300); }
.sbg__link-ico { flex-shrink: 0; }

.sbg__group { margin-top: 2px; }
.sbg__group-hdr { width: 100%; display: flex; align-items: center; gap: 9px; padding: 8px 14px; border-radius: var(--r-md); background: none; border: none; border-left: 3px solid transparent; cursor: pointer; font-size: 11px; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: rgba(168,201,181,0.55); transition: background var(--t-fast), color var(--t-fast); text-align: left; }
.sbg__group-hdr:hover { background: rgba(255,255,255,0.04); color: rgba(168,201,181,0.85); }
.sbg__group-hdr--active { color: var(--c-leaf-200); }
.sbg__group-ico { flex-shrink: 0; }
.sbg__group-label { flex: 1; }
.sbg__chevron { flex-shrink: 0; transition: transform .2s ease; opacity: .6; }
.sbg__chevron--open { transform: rotate(180deg); }

.sbg__group-items { display: flex; flex-direction: column; gap: 1px; padding-left: var(--sp-2); margin-bottom: var(--sp-1); }
.sbg__sub { display: flex; align-items: center; gap: 9px; padding: 7px 12px 7px 16px; border-radius: var(--r-md); font-size: var(--fs-13); color: var(--c-leaf-300); text-decoration: none; transition: background var(--t-fast), color var(--t-fast); border-left: 2px solid transparent; }
.sbg__sub:hover { background: rgba(255,255,255,0.06); color: var(--c-paper); }
.sbg__sub--active { background: rgba(255,255,255,0.14); color: var(--c-paper); font-weight: 600; border-left-color: var(--c-leaf-300); }
.sbg__sub-ico { flex-shrink: 0; opacity: .8; }
.sbg__sub--active .sbg__sub-ico { opacity: 1; }
.sbg__sub-badge { margin-left: auto; background: #d97706; color: #fff; font-size: 10px; font-weight: 700; line-height: 1; padding: 2px 5px; border-radius: 10px; min-width: 16px; text-align: center; }

.sbg__collapse-btn { display: flex; align-items: center; justify-content: center; width: 100%; height: 38px; border: none; background: none; color: rgba(168,201,181,0.45); cursor: pointer; flex-shrink: 0; border-top: 1px solid rgba(168,201,181,0.12); transition: color .15s, background .15s; }
.sbg__collapse-btn:hover { color: rgba(168,201,181,0.9); background: rgba(255,255,255,0.05); }

@media (max-width: 1023px) { .sbg { display: none; } }
</style>
