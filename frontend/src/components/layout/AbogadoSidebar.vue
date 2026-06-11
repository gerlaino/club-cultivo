<template>
  <aside class="abg-sidebar">
    <div class="abg-logo">
      <img src="/logo-ce-icono.png" class="abg-logo-img" alt="Cultivo Espacial" />
      <span>Legal</span>
    </div>

    <nav class="abg-nav">
      <RouterLink to="/abogado" class="abg-link" exact-active-class="abg-link--active">
        <Home :size="18" :stroke-width="1.75" /><span>Inicio</span>
      </RouterLink>
      <RouterLink to="/abogado/documentos" class="abg-link" active-class="abg-link--active">
        <Files :size="18" :stroke-width="1.75" /><span>Mis Documentos</span>
      </RouterLink>
    </nav>

    <div class="abg-footer">
      <button class="abg-logout" @click="$emit('logout')">
        <LogOut :size="16" :stroke-width="1.75" /> Salir
      </button>
    </div>
  </aside>
</template>

<script setup>
import { Scale, Home, Files, LogOut } from 'lucide-vue-next'
defineEmits(['logout'])
</script>

<style scoped>
.abg-sidebar {
  width: 200px; min-width: 200px;
  background: #2a2f38;
  display: flex; flex-direction: column;
  padding: var(--sp-4) 0; flex-shrink: 0;
}
.abg-logo {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-5) var(--sp-5);
  color: #8fa3b1; font-weight: 700; font-size: var(--fs-16);
}
.abg-logo-img { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
.abg-nav { flex: 1; display: flex; flex-direction: column; gap: 2px; padding: 0 var(--sp-3); }
.abg-link {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  color: rgba(255,255,255,.55);
  border-radius: var(--r-md); text-decoration: none;
  font-size: var(--fs-14); font-weight: 500; transition: all .15s;
}
.abg-link:hover { color: #fff; background: rgba(143,163,177,.1); }
.abg-link--active { color: #fff; background: rgba(143,163,177,.18); }
.abg-footer { padding: var(--sp-4) var(--sp-5); }
.abg-logout { display: flex; align-items: center; gap: var(--sp-2); background: none; border: none; color: rgba(255,255,255,.35); cursor: pointer; font-size: var(--fs-13); padding: 0; transition: color .15s; }
.abg-logout:hover { color: rgba(255,255,255,.7); }
</style>
