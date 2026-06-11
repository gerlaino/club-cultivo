<template>
  <nav class="bnc" aria-label="Navegación principal">

    <!-- Inicio -->
    <RouterLink to="/" class="bnc__item" :class="{ 'bnc__item--active': isActive('/') }">
      <Home :size="22" :stroke-width="1.75" class="bnc__ico" />
      <span class="bnc__lbl">Inicio</span>
    </RouterLink>

    <!-- Salas -->
    <RouterLink to="/salas" class="bnc__item" :class="{ 'bnc__item--active': isActive('/salas') }">
      <LayoutGrid :size="22" :stroke-width="1.75" class="bnc__ico" />
      <span class="bnc__lbl">Salas</span>
    </RouterLink>

    <!-- FAB Asistente de voz (central elevado) -->
    <div class="bnc__fab-wrap">
      <button class="bnc__fab" @click="abrirAsistente" aria-label="Asistente de voz">
        <Mic :size="26" :stroke-width="1.75" />
      </button>
    </div>

    <!-- Cosechado -->
    <RouterLink to="/cosechado" class="bnc__item" :class="{ 'bnc__item--active': isActive('/cosechado') }">
      <PackageCheck :size="22" :stroke-width="1.75" class="bnc__ico" />
      <span class="bnc__lbl">Cosechado</span>
    </RouterLink>

    <!-- Más -->
    <button class="bnc__item" @click="masOpen = true">
      <MoreHorizontal :size="22" :stroke-width="1.75" class="bnc__ico" />
      <span class="bnc__lbl">Más</span>
    </button>

  </nav>

  <!-- Sheet: Registrar lectura -->
  <RegistrarLecturaSheet v-model="lecturaOpen" />

  <!-- Sheet: Más opciones -->
  <SheetBottom v-model="masOpen" title="Más opciones">
    <div class="bnc__mas">
      <button class="bnc__mas-item" @click="abrirLectura">
        <span class="bnc__mas-ico"><Plus :size="20" :stroke-width="1.75" /></span>
        <span class="bnc__mas-lbl">Registrar lectura</span>
        <ChevronRight :size="16" :stroke-width="1.75" class="bnc__mas-arr" />
      </button>
      <RouterLink to="/lotes" class="bnc__mas-item" @click="masOpen = false">
        <span class="bnc__mas-ico"><Sprout :size="20" :stroke-width="1.75" /></span>
        <span class="bnc__mas-lbl">Mis lotes</span>
        <ChevronRight :size="16" :stroke-width="1.75" class="bnc__mas-arr" />
      </RouterLink>
      <RouterLink to="/perfil" class="bnc__mas-item" @click="masOpen = false">
        <span class="bnc__mas-ico"><User :size="20" :stroke-width="1.75" /></span>
        <span class="bnc__mas-lbl">Mi perfil</span>
        <ChevronRight :size="16" :stroke-width="1.75" class="bnc__mas-arr" />
      </RouterLink>
    </div>
  </SheetBottom>
</template>

<script setup>
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import SheetBottom          from './SheetBottom.vue'
import RegistrarLecturaSheet from './RegistrarLecturaSheet.vue'
import {
  Home, LayoutGrid, Plus, Mic, MoreHorizontal, PackageCheck,
  Sprout, User, ChevronRight,
} from 'lucide-vue-next'

const route   = useRoute()

const lecturaOpen = ref(false)
const masOpen     = ref(false)

function abrirAsistente() {
  masOpen.value = false
  window.dispatchEvent(new CustomEvent('abrir-asistente-voz'))
}

function abrirLectura() {
  masOpen.value = false
  lecturaOpen.value = true
}

function isActive(to) {
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(to + '/')
}
</script>

<style scoped>
.bnc {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 64px;
  background: var(--c-paper);
  border-top: 1px solid var(--c-ink-300);
  box-shadow: 0 -1px 2px rgb(0 0 0 / 0.04);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 var(--sp-2);
  padding-bottom: env(safe-area-inset-bottom, 0px);
  z-index: 200;
  overflow: visible;
}

.bnc__item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  flex: 1;
  height: 100%;
  min-width: 0;
  padding: 6px 4px;
  text-decoration: none;
  color: var(--c-ink-500);
  background: none;
  border: none;
  cursor: pointer;
  transition: color var(--t-fast);
  -webkit-tap-highlight-color: transparent;
}
.bnc__item:active { background: rgba(45, 74, 62, 0.08); border-radius: var(--r-md); }
.bnc__item--active { color: var(--c-role-cultivador); }
.bnc__item--active .bnc__lbl { font-weight: 600; }

.bnc__ico { flex-shrink: 0; }
.bnc__lbl {
  font-size: 10px;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  white-space: nowrap;
}

/* FAB */
.bnc__fab-wrap {
  position: relative;
  flex: 1;
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.bnc__fab {
  position: absolute;
  bottom: 24px;  /* eleva ~16px sobre el borde superior del nav */
  left: 50%;
  transform: translateX(-50%);
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: var(--c-leaf-700);
  color: var(--c-paper);
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 16px rgba(45, 74, 62, 0.35), 0 2px 4px rgba(0, 0, 0, 0.15);
  transition: transform var(--t-fast), box-shadow var(--t-fast);
  -webkit-tap-highlight-color: transparent;
}
.bnc__fab:active {
  transform: translateX(-50%) scale(0.95);
  box-shadow: 0 2px 8px rgba(45, 74, 62, 0.25);
}

/* Sheet "Más" */
.bnc__mas { display: flex; flex-direction: column; gap: 2px; }
.bnc__mas-item {
  display: flex;
  align-items: center;
  gap: var(--sp-3);
  height: 56px;
  padding: 0 var(--sp-2);
  border-radius: var(--r-md);
  text-decoration: none;
  color: var(--c-ink-900);
  background: none;
  border: none;
  cursor: pointer;
  font-size: var(--fs-16);
  font-weight: 500;
  transition: background var(--t-fast);
  width: 100%;
  text-align: left;
}
.bnc__mas-item:hover { background: var(--c-leaf-50); }
.bnc__mas-ico { display: flex; flex-shrink: 0; color: var(--c-ink-500); }
.bnc__mas-lbl { flex: 1; }
.bnc__mas-arr { color: var(--c-ink-300); }

/* Only visible on mobile */
@media (min-width: 768px) { .bnc { display: none; } }
</style>
