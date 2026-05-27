<template>
  <header class="dlv-topbar">
    <button class="dlv-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <span class="dlv-breadcrumb">{{ pageTitle }}</span>
    <div class="dlv-right">
      <button class="dlv-icon-btn" @click="openHelp" aria-label="Ayuda" title="Ayuda">
        <HelpCircle :size="18" :stroke-width="1.75" />
        <span v-if="helpDot" class="dlv-help-dot" />
      </button>
      <span class="dlv-role-badge">Delivery</span>
    </div>
  </header>

  <HelpDrawer v-model="helpOpen" />
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Menu, HelpCircle } from 'lucide-vue-next'
import { useAuthStore } from '../../stores/auth.js'
import HelpDrawer from '../HelpDrawer.vue'

defineEmits(['open-drawer'])

const auth  = useAuthStore()
const route = useRoute()
const LABELS = { '/delivery': 'Inicio', '/delivery/despachos': 'Despachos' }
const pageTitle = computed(() => LABELS[route.path] || 'Delivery')

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
.dlv-topbar { height: 54px; display: flex; align-items: center; gap: var(--sp-3); padding: 0 var(--sp-5); background: var(--c-paper); border-bottom: 1px solid var(--c-ink-100); flex-shrink: 0; }
.dlv-hamburger { display: none; background: none; border: none; cursor: pointer; color: var(--c-ink-600); padding: var(--sp-1); border-radius: var(--r-sm); }
.dlv-breadcrumb { font-size: var(--fs-15); font-weight: 600; color: var(--c-ink-900); flex: 1; }
.dlv-right { display: flex; align-items: center; gap: var(--sp-2); }
.dlv-role-badge { background: rgba(26,61,46,.1); color: var(--c-role-delivery); font-size: var(--fs-12); font-weight: 600; padding: 2px 10px; border-radius: 999px; }
.dlv-icon-btn { position: relative; background: none; border: 1px solid var(--c-ink-200); border-radius: var(--r-md); width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: var(--c-ink-500); transition: all .15s; }
.dlv-icon-btn:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.dlv-help-dot { position: absolute; top: 4px; right: 4px; width: 7px; height: 7px; background: #3b82f6; border-radius: 50%; border: 1.5px solid var(--c-paper); }
@media (max-width: 1023px) { .dlv-hamburger { display: flex; } }
</style>
