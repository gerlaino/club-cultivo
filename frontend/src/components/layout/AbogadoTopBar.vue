<template>
  <header class="abg-topbar">
    <button class="abg-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <ClubBrand tone="role-abogado" />
    <span class="abg-breadcrumb">{{ pageTitle }}</span>
    <div class="abg-right">
      <button class="abg-icon-btn" @click="openHelp" aria-label="Ayuda" title="Ayuda">
        <HelpCircle :size="18" :stroke-width="1.75" />
        <span v-if="helpDot" class="abg-help-dot" />
      </button>
      <span class="abg-role-badge">Abogado</span>
    </div>
  </header>

  <HelpDrawer v-model="helpOpen" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Menu, HelpCircle } from 'lucide-vue-next'
import { useAuthStore } from '../../stores/auth.js'
import ClubBrand from './ClubBrand.vue'
import HelpDrawer from '../HelpDrawer.vue'

defineEmits(['open-drawer'])

const auth  = useAuthStore()
const route = useRoute()
const LABELS = { '/abogado': 'Inicio', '/abogado/documentos': 'Mis Documentos' }
const pageTitle = computed(() => LABELS[route.path] || 'Legal')

const helpOpen = ref(false)
const helpDot  = ref(false)
onMounted(() => {
  helpDot.value = !localStorage.getItem(`help_seen_${auth.user?.id || 'u'}`)
})
function openHelp() {
  helpOpen.value = true
  if (helpDot.value) {
    helpDot.value = false
    localStorage.setItem(`help_seen_${auth.user?.id || 'u'}`, '1')
  }
}
</script>

<style scoped>
.abg-topbar { height: 54px; display: flex; align-items: center; gap: var(--sp-3); padding: 0 var(--sp-5); background: var(--c-paper); border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0; }
.abg-hamburger { display: none; background: none; border: none; cursor: pointer; color: var(--c-ink-600); padding: var(--sp-1); border-radius: var(--r-sm); }
.abg-breadcrumb { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); flex: 1; }
.abg-right { display: flex; align-items: center; gap: var(--sp-2); }
.abg-role-badge { background: rgba(91,100,115,.1); color: #5B6473; font-size: var(--fs-12); font-weight: 600; padding: 2px 10px; border-radius: 999px; }
.abg-icon-btn { position: relative; background: none; border: 1px solid var(--c-ink-200); border-radius: var(--r-md); width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: var(--c-ink-500); transition: all .15s; }
.abg-icon-btn:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.abg-help-dot { position: absolute; top: 4px; right: 4px; width: 7px; height: 7px; background: #3b82f6; border-radius: 50%; border: 1.5px solid var(--c-paper); }
@media (max-width: 1023px) { .abg-hamburger { display: flex; } }
</style>
