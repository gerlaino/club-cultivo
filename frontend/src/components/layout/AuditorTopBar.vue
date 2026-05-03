<template>
  <header class="aud-topbar">
    <button class="aud-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <span class="aud-breadcrumb">{{ pageTitle }}</span>
    <span class="aud-role-badge">
      <ShieldCheck :size="13" :stroke-width="2" /> Modo informe · Solo lectura
    </span>
  </header>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { Menu, ShieldCheck } from 'lucide-vue-next'
defineEmits(['open-drawer'])
const route = useRoute()
const LABELS = { '/auditor': 'Inicio', '/auditor/reprocann': 'Informe REPROCANN', '/auditor/produccion': 'Informe Producción', '/auditor/dispensaciones': 'Informe Dispensaciones', '/auditor/sedes': 'Informe Sedes', '/auditor/cumplimiento': 'Informe Cumplimiento' }
const pageTitle = computed(() => LABELS[route.path] || 'Auditoría')
</script>

<style scoped>
.aud-topbar { height: 54px; display: flex; align-items: center; gap: var(--sp-3); padding: 0 var(--sp-5); background: var(--c-paper); border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0; }
.aud-hamburger { display: none; background: none; border: none; cursor: pointer; color: var(--c-ink-600); padding: var(--sp-1); border-radius: var(--r-sm); }
.aud-breadcrumb { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); flex: 1; }
.aud-role-badge { display: flex; align-items: center; gap: 5px; background: rgba(139,90,43,.08); color: #8B5A2B; font-size: var(--fs-12); font-weight: 600; padding: 3px 10px; border-radius: 999px; white-space: nowrap; }
@media (max-width: 1023px) { .aud-hamburger { display: flex; } }
</style>
