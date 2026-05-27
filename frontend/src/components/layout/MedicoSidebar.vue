<template>
  <aside class="mdc-sidebar">
    <div class="mdc-logo">
      <img src="/logo-ce-icono.png" class="mdc-logo-img" alt="Cultivo Espacial" />
      <span>Médico</span>
    </div>

    <nav class="mdc-nav">
      <RouterLink to="/medico" class="mdc-link" exact-active-class="mdc-link--active">
        <Home :size="18" :stroke-width="1.75" /><span>Inicio</span>
      </RouterLink>
      <RouterLink to="/medico/pacientes" class="mdc-link" active-class="mdc-link--active">
        <Users :size="18" :stroke-width="1.75" /><span>Mis Pacientes</span>
      </RouterLink>
      <RouterLink to="/medico/indicaciones" class="mdc-link" active-class="mdc-link--active">
        <FileHeart :size="18" :stroke-width="1.75" /><span>Indicaciones</span>
      </RouterLink>
      <RouterLink to="/medico/documentos" class="mdc-link" active-class="mdc-link--active">
        <FolderOpen :size="18" :stroke-width="1.75" /><span>Documentos</span>
      </RouterLink>
    </nav>

    <div class="mdc-footer">
      <RouterLink to="/perfil" class="mdc-link mdc-link--perfil" active-class="mdc-link--active">
        <UserCircle :size="16" :stroke-width="1.75" /><span>Mi perfil</span>
      </RouterLink>
      <button class="mdc-logout" @click="$emit('logout')">
        <LogOut :size="16" :stroke-width="1.75" /> Salir
      </button>
    </div>
  </aside>
</template>

<script setup>
import { Stethoscope, Home, Users, FileHeart, FolderOpen, LogOut, UserCircle } from 'lucide-vue-next'
defineEmits(['logout'])
</script>

<style scoped>
.mdc-sidebar {
  width: 220px; min-width: 220px;
  background: var(--c-role-medico);
  display: flex; flex-direction: column;
  padding: var(--sp-4) 0;
  flex-shrink: 0;
}
.mdc-logo {
  display: flex; align-items: center; gap: var(--sp-2);
  padding: var(--sp-3) var(--sp-5) var(--sp-5);
  color: #5ab36e;
  font-weight: 700; font-size: var(--fs-16);
}
.mdc-logo-img { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
.mdc-nav { flex: 1; display: flex; flex-direction: column; gap: 2px; padding: 0 var(--sp-3); }
.mdc-link {
  display: flex; align-items: center; gap: var(--sp-3);
  padding: var(--sp-2) var(--sp-3);
  color: rgba(255,255,255,.6);
  border-radius: var(--r-md);
  text-decoration: none;
  font-size: var(--fs-14); font-weight: 500;
  transition: all .15s;
}
.mdc-link:hover { color: #fff; background: rgba(90,179,110,.12); }
.mdc-link--active { color: #fff; background: rgba(90,179,110,.2); }
.mdc-footer { padding: var(--sp-3) var(--sp-3) var(--sp-4); display: flex; flex-direction: column; gap: var(--sp-1); }
.mdc-link--perfil { font-size: var(--fs-13); }
.mdc-logout {
  display: flex; align-items: center; gap: var(--sp-2);
  background: none; border: none;
  color: rgba(255,255,255,.4); cursor: pointer;
  font-size: var(--fs-13); padding: 0;
  transition: color .15s;
}
.mdc-logout:hover { color: rgba(255,255,255,.8); }
</style>
