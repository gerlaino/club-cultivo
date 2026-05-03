<template>
  <aside class="dlv-sidebar">
    <div class="dlv-logo">
      <Truck :size="22" :stroke-width="1.75" />
      <span>Delivery</span>
    </div>

    <nav class="dlv-nav">
      <RouterLink to="/delivery" class="dlv-link" exact-active-class="dlv-link--active">
        <Home :size="18" :stroke-width="1.75" /><span>Inicio</span>
      </RouterLink>
      <RouterLink to="/delivery/despachos" class="dlv-link" active-class="dlv-link--active">
        <PackageCheck :size="18" :stroke-width="1.75" /><span>Despachos</span>
      </RouterLink>
    </nav>

    <div class="dlv-footer">
      <button class="dlv-logout" @click="$emit('logout')">
        <LogOut :size="16" :stroke-width="1.75" /> Salir
      </button>
    </div>
  </aside>
</template>

<script setup>
import { Truck, Home, PackageCheck, LogOut } from 'lucide-vue-next'
defineEmits(['logout'])
</script>

<style scoped>
.dlv-sidebar {
  width: 200px; min-width: 200px;
  background: var(--c-role-delivery, #1A3A4A);
  display: flex; flex-direction: column;
  padding: var(--sp-4) 0; flex-shrink: 0;
}
.dlv-logo {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-5) var(--sp-5);
  color: rgba(255,255,255,.65); font-weight: 700; font-size: var(--fs-16);
}
.dlv-nav { flex: 1; display: flex; flex-direction: column; gap: 2px; padding: 0 var(--sp-3); }
.dlv-link {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  color: rgba(255,255,255,.55);
  border-radius: var(--r-md); text-decoration: none;
  font-size: var(--fs-14); font-weight: 500; transition: all .15s;
}
.dlv-link:hover { color: #fff; background: rgba(255,255,255,.1); }
.dlv-link--active { color: #fff; background: rgba(255,255,255,.18); }
.dlv-footer { padding: var(--sp-4) var(--sp-5); }
.dlv-logout { display: flex; align-items: center; gap: var(--sp-2); background: none; border: none; color: rgba(255,255,255,.35); cursor: pointer; font-size: var(--fs-13); padding: 0; transition: color .15s; }
.dlv-logout:hover { color: rgba(255,255,255,.7); }
</style>
