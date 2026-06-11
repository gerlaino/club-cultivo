<template>
  <div class="shell">
    <div class="shell__content">
      <router-view v-slot="{ Component }">
        <Transition name="fade" mode="out-in">
          <component :is="Component" />
        </Transition>
      </router-view>
    </div>

    <nav class="shell__nav">
      <router-link to="/cultivador/sedes" class="shell__tab" :class="{ active: isSedes }">
        <span class="shell__tab-icon">🌿</span>
        <span class="shell__tab-label">Sedes</span>
      </router-link>
      <router-link to="/cultivador/tareas" class="shell__tab" :class="{ active: isTareas }">
        <span class="shell__tab-icon">✅</span>
        <span class="shell__tab-label">Tareas</span>
      </router-link>
    </nav>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route   = useRoute()
const isTareas = computed(() => route.path.includes('/tareas'))
const isSedes  = computed(() => route.path.includes('/sedes'))
</script>

<style scoped>
.shell {
  height: 100vh;
  height: 100dvh;
  display: flex;
  flex-direction: column;
}
.shell__content {
  flex: 1;
  min-height: 0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.shell__nav {
  display: flex;
  background: #fff;
  border-top: 1px solid var(--border);
  padding-bottom: env(safe-area-inset-bottom, 0);
  flex-shrink: 0;
}
.shell__tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: .2rem;
  padding: .55rem .5rem;
  text-decoration: none;
  color: var(--text-3);
  transition: color .15s;
  min-height: 56px;
  justify-content: center;
}
.shell__tab.active        { color: var(--green); }
.shell__tab-icon          { font-size: 1.3rem; line-height: 1; }
.shell__tab-label         { font-size: .65rem; font-weight: 600; text-transform: uppercase; letter-spacing: .06em; }

.fade-enter-active, .fade-leave-active { transition: opacity .12s; }
.fade-enter-from, .fade-leave-to       { opacity: 0; }
</style>
