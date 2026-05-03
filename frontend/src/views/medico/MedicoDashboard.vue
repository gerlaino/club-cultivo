<template>
  <div class="mdc-home">
    <h1 class="mdc-home__title">Panel Médico</h1>
    <p class="mdc-home__sub">Gestión de pacientes con seguimiento médico.</p>
    <div class="mdc-home__cards">
      <RouterLink to="/medico/pacientes" class="mdc-card">
        <Users :size="28" :stroke-width="1.5" />
        <span class="mdc-card__label">Mis pacientes</span>
        <span class="mdc-card__desc">Pacientes con seguimiento activo</span>
      </RouterLink>
      <RouterLink to="/medico/indicaciones" class="mdc-card">
        <FileHeart :size="28" :stroke-width="1.5" />
        <span class="mdc-card__label">Indicaciones</span>
        <span class="mdc-card__desc">Prescripciones y dosis</span>
      </RouterLink>
      <RouterLink to="/medico/documentos" class="mdc-card">
        <FolderOpen :size="28" :stroke-width="1.5" />
        <span class="mdc-card__label">Documentos</span>
        <span class="mdc-card__desc">REPROCANN y documentación clínica</span>
      </RouterLink>
    </div>
  </div>
</template>

<script setup>
import { Users, FileHeart, FolderOpen } from 'lucide-vue-next'
</script>

<style scoped>
.mdc-home { padding: var(--sp-6); max-width: 700px; }
.mdc-home__title { font-size: var(--fs-24); font-weight: 800; color: var(--c-ink-900); margin: 0 0 var(--sp-1); }
.mdc-home__sub { color: var(--c-ink-500); font-size: var(--fs-14); margin: 0 0 var(--sp-6); }
.mdc-home__cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: var(--sp-4); }
.mdc-card {
  display: flex; flex-direction: column; align-items: flex-start; gap: var(--sp-2);
  background: var(--c-paper); border: 1px solid var(--c-ink-100); border-radius: var(--r-lg);
  padding: var(--sp-5); text-decoration: none; color: var(--c-ink-700);
  transition: border-color .15s, box-shadow .15s;
}
.mdc-card:hover { border-color: #2D8A6B; box-shadow: 0 2px 8px rgba(45,138,107,.1); color: #2D8A6B; }
.mdc-card__label { font-size: var(--fs-15); font-weight: 700; color: var(--c-ink-900); }
.mdc-card__desc { font-size: var(--fs-12); color: var(--c-ink-500); }
</style>
