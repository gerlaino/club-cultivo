<template>
  <header class="mdc-topbar">
    <button class="mdc-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <span class="mdc-breadcrumb">{{ pageTitle }}</span>
    <div class="mdc-right">
      <span class="mdc-role-badge">Médico</span>
    </div>
  </header>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Menu } from 'lucide-vue-next'

defineEmits(['open-drawer'])

const route = useRoute()
const LABELS = { '/medico': 'Inicio', '/medico/pacientes': 'Mis Pacientes', '/medico/indicaciones': 'Indicaciones', '/medico/documentos': 'Documentos' }
const pageTitle = computed(() => LABELS[route.path] || 'Médico')
</script>

<style scoped>
.mdc-topbar {
  height: 54px; display: flex; align-items: center; gap: var(--sp-3);
  padding: 0 var(--sp-5);
  background: var(--c-paper);
  border-bottom: 1px solid var(--c-ink-100);
  flex-shrink: 0;
}
.mdc-hamburger { display: none; background: none; border: none; cursor: pointer; color: var(--c-ink-600); padding: var(--sp-1); border-radius: var(--r-sm); }
.mdc-breadcrumb { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); flex: 1; }
.mdc-right { display: flex; align-items: center; gap: var(--sp-3); }
.mdc-role-badge { background: rgba(45,138,107,.12); color: #2D8A6B; font-size: var(--fs-12); font-weight: 600; padding: 2px 10px; border-radius: 999px; }
@media (max-width: 1023px) { .mdc-hamburger { display: flex; } }
</style>
