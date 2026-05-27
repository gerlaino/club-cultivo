<template>
  <aside class="aud-sidebar">
    <div class="aud-logo">
      <img src="/logo-ce-icono.png" class="aud-logo-img" alt="Cultivo Espacial" />
      <span>Auditoría</span>
    </div>
    <div class="aud-banner">Solo lectura</div>

    <nav class="aud-nav">
      <RouterLink to="/auditor" class="aud-link" exact-active-class="aud-link--active">
        <Home :size="18" :stroke-width="1.75" /><span>Inicio</span>
      </RouterLink>
      <RouterLink to="/auditor/reprocann" class="aud-link" active-class="aud-link--active">
        <FileCheck :size="18" :stroke-width="1.75" /><span>REPROCANN</span>
      </RouterLink>
      <RouterLink to="/auditor/produccion" class="aud-link" active-class="aud-link--active">
        <Sprout :size="18" :stroke-width="1.75" /><span>Producción</span>
      </RouterLink>
      <RouterLink to="/auditor/dispensaciones" class="aud-link" active-class="aud-link--active">
        <Package :size="18" :stroke-width="1.75" /><span>Dispensaciones</span>
      </RouterLink>
      <RouterLink to="/auditor/sedes" class="aud-link" active-class="aud-link--active">
        <Building2 :size="18" :stroke-width="1.75" /><span>Sedes</span>
      </RouterLink>
      <RouterLink to="/auditor/cumplimiento" class="aud-link" active-class="aud-link--active">
        <ShieldAlert :size="18" :stroke-width="1.75" /><span>Cumplimiento</span>
      </RouterLink>
      <RouterLink to="/auditor/plan-vs-real" class="aud-link" active-class="aud-link--active">
        <BarChart2 :size="18" :stroke-width="1.75" /><span>Plan vs Real</span>
      </RouterLink>
      <RouterLink to="/auditor/trazabilidad" class="aud-link" active-class="aud-link--active">
        <GitBranch :size="18" :stroke-width="1.75" /><span>Trazabilidad</span>
      </RouterLink>
    </nav>

    <div class="aud-footer">
      <button class="aud-logout" @click="$emit('logout')">
        <LogOut :size="16" :stroke-width="1.75" /> Salir
      </button>
    </div>
  </aside>
</template>

<script setup>
import { ShieldCheck, Home, FileCheck, Sprout, Package, Building2, ShieldAlert, LogOut, BarChart2, GitBranch } from 'lucide-vue-next'
defineEmits(['logout'])
</script>

<style scoped>
.aud-sidebar { width: 220px; min-width: 220px; background: var(--c-role-auditor); display: flex; flex-direction: column; padding: var(--sp-4) 0; flex-shrink: 0; }
.aud-logo { display: flex; align-items: center; gap: var(--sp-2); padding: var(--sp-3) var(--sp-5) var(--sp-3); color: #c8a06a; font-weight: 700; font-size: var(--fs-16); }
.aud-logo-img { width: 28px; height: 28px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
.aud-banner { margin: 0 var(--sp-3) var(--sp-3); background: rgba(200,160,106,.12); color: #c8a06a; font-size: var(--fs-11); font-weight: 600; text-align: center; padding: 3px 8px; border-radius: var(--r-sm); letter-spacing: .04em; }
.aud-nav { flex: 1; display: flex; flex-direction: column; gap: 2px; padding: 0 var(--sp-3); }
.aud-link { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-2) var(--sp-3); color: rgba(255,255,255,.55); border-radius: var(--r-md); text-decoration: none; font-size: var(--fs-14); font-weight: 500; transition: all .15s; }
.aud-link:hover { color: #fff; background: rgba(200,160,106,.1); }
.aud-link--active { color: #fff; background: rgba(200,160,106,.18); }
.aud-footer { padding: var(--sp-4) var(--sp-5); }
.aud-logout { display: flex; align-items: center; gap: var(--sp-2); background: none; border: none; color: rgba(255,255,255,.35); cursor: pointer; font-size: var(--fs-13); padding: 0; transition: color .15s; }
.aud-logout:hover { color: rgba(255,255,255,.7); }
</style>
