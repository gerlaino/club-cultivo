<template>
  <header class="abg-topbar">
    <button class="abg-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <span class="abg-breadcrumb">{{ pageTitle }}</span>
    <span class="abg-role-badge">Abogado</span>
  </header>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Menu } from 'lucide-vue-next'
defineEmits(['open-drawer'])
const route = useRoute()
const LABELS = { '/abogado': 'Inicio', '/abogado/documentos': 'Mis Documentos' }
const pageTitle = computed(() => LABELS[route.path] || 'Legal')
</script>

<style scoped>
.abg-topbar { height: 54px; display: flex; align-items: center; gap: var(--sp-3); padding: 0 var(--sp-5); background: var(--c-paper); border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0; }
.abg-hamburger { display: none; background: none; border: none; cursor: pointer; color: var(--c-ink-600); padding: var(--sp-1); border-radius: var(--r-sm); }
.abg-breadcrumb { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); flex: 1; }
.abg-role-badge { background: rgba(91,100,115,.1); color: #5B6473; font-size: var(--fs-12); font-weight: 600; padding: 2px 10px; border-radius: 999px; }
@media (max-width: 1023px) { .abg-hamburger { display: flex; } }
</style>
