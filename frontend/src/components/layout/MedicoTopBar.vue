<template>
  <header class="mdc-topbar">
    <button class="mdc-hamburger" @click="$emit('open-drawer')" aria-label="Menú">
      <Menu :size="20" :stroke-width="2" />
    </button>
    <span class="mdc-breadcrumb">{{ pageTitle }}</span>
    <div class="mdc-right">
      <button class="mdc-bell" :class="{ 'mdc-bell--active': count > 0 }" @click="bellOpen = !bellOpen" aria-label="Alertas">
        <Bell :size="18" :stroke-width="1.75" />
        <span v-if="count > 0" class="mdc-badge">{{ count > 9 ? '9+' : count }}</span>
      </button>
      <div v-if="bellOpen" class="mdc-bell-panel">
        <div class="mdc-bell-header">
          <span>Alertas</span>
          <button v-if="count" class="mdc-bell-clear" @click="marcarTodas">Leer todas</button>
          <button class="mdc-bell-close" @click="bellOpen = false">✕</button>
        </div>
        <div v-if="!count" class="mdc-bell-empty">Sin alertas pendientes</div>
        <div v-else>
          <div
            v-for="a in noLeidas.slice(0, 8)"
            :key="a.id"
            class="mdc-bell-item"
            :class="`mdc-bell-item--${a.severidad}`"
            @click="marcarLeida(a.id)"
          >
            <div class="mdc-bell-msg">{{ a.mensaje }}</div>
            <div class="mdc-bell-time">{{ formatTime(a.created_at) }}</div>
          </div>
        </div>
      </div>
      <span class="mdc-role-badge">Médico</span>
    </div>
  </header>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { Menu, Bell } from 'lucide-vue-next'
import { useAlertasInternas } from '../../composables/useAlertasInternas.js'

defineEmits(['open-drawer'])

const route = useRoute()
const LABELS = { '/medico': 'Inicio', '/medico/pacientes': 'Mis Pacientes', '/medico/indicaciones': 'Indicaciones', '/medico/documentos': 'Documentos' }
const pageTitle = computed(() => LABELS[route.path] || 'Médico')

const bellOpen = ref(false)
const { noLeidas, count, marcarLeida, marcarTodas } = useAlertasInternas()

function formatTime(ts) {
  if (!ts) return ''
  const diff = Date.now() - new Date(ts).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `hace ${mins}m`
  const hrs = Math.floor(mins / 60)
  return hrs < 24 ? `hace ${hrs}h` : `hace ${Math.floor(hrs / 24)}d`
}
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
.mdc-right { display: flex; align-items: center; gap: var(--sp-3); position: relative; }
.mdc-role-badge { background: rgba(45,138,107,.12); color: #2D8A6B; font-size: var(--fs-12); font-weight: 600; padding: 2px 10px; border-radius: 999px; }
@media (max-width: 1023px) { .mdc-hamburger { display: flex; } }
.mdc-bell { position: relative; background: none; border: 1px solid var(--c-ink-200); border-radius: var(--r-md); width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; cursor: pointer; color: var(--c-ink-500); transition: all .15s; }
.mdc-bell:hover { background: var(--c-ink-100); color: var(--c-ink-900); }
.mdc-bell--active { border-color: #fca5a5; background: #fff5f5; color: #dc2626; }
.mdc-badge { position: absolute; top: -4px; right: -4px; min-width: 16px; height: 16px; background: #dc2626; color: #fff; font-size: 9px; font-weight: 800; border-radius: 999px; display: flex; align-items: center; justify-content: center; padding: 0 2px; border: 2px solid #fff; }
.mdc-bell-panel { position: absolute; top: calc(100% + 8px); right: 0; width: 320px; background: #fff; border: 1px solid var(--c-ink-200); border-radius: var(--r-lg); box-shadow: 0 8px 24px rgba(0,0,0,.12); z-index: 200; max-height: 400px; overflow-y: auto; }
.mdc-bell-header { display: flex; align-items: center; justify-content: space-between; padding: .6rem .9rem; border-bottom: 1px solid var(--c-ink-100); font-size: var(--fs-13); font-weight: 700; color: var(--c-ink-900); }
.mdc-bell-clear { font-size: var(--fs-11); color: var(--c-ink-500); background: none; border: none; cursor: pointer; text-decoration: underline; }
.mdc-bell-close { background: none; border: none; cursor: pointer; color: var(--c-ink-400); font-size: var(--fs-13); }
.mdc-bell-empty { padding: .9rem; font-size: var(--fs-13); color: var(--c-ink-400); text-align: center; }
.mdc-bell-item { padding: .6rem .9rem; border-bottom: 1px solid var(--c-ink-50); cursor: pointer; }
.mdc-bell-item:last-child { border-bottom: none; }
.mdc-bell-item:hover { background: var(--c-ink-50); }
.mdc-bell-item--error { background: #fff5f5; }
.mdc-bell-item--warning { background: #fffbeb; }
.mdc-bell-msg { font-size: var(--fs-13); color: var(--c-ink-800); font-weight: 500; }
.mdc-bell-time { font-size: var(--fs-11); color: var(--c-ink-400); margin-top: 2px; }
</style>
