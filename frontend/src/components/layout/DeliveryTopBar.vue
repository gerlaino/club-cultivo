<template>
  <header class="dlv-topbar">
    <button class="dlv-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <span class="dlv-breadcrumb">{{ pageTitle }}</span>
    <span class="dlv-role-badge">Delivery</span>
  </header>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Menu } from 'lucide-vue-next'
defineEmits(['open-drawer'])
const route = useRoute()
const LABELS = { '/delivery': 'Inicio', '/delivery/despachos': 'Despachos' }
const pageTitle = computed(() => LABELS[route.path] || 'Delivery')
</script>

<style scoped>
.dlv-topbar { height: 54px; display: flex; align-items: center; gap: var(--sp-3); padding: 0 var(--sp-5); background: var(--c-paper); border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0; }
.dlv-hamburger { display: none; background: none; border: none; cursor: pointer; color: var(--c-ink-600); padding: var(--sp-1); border-radius: var(--r-sm); }
.dlv-breadcrumb { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); flex: 1; }
.dlv-role-badge { background: rgba(26,58,74,.12); color: var(--c-role-delivery, #1A3A4A); font-size: var(--fs-12); font-weight: 600; padding: 2px 10px; border-radius: 999px; }
@media (max-width: 1023px) { .dlv-hamburger { display: flex; } }
</style>
